USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_IndexPhysicalStats
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Führt eine bewusst aktivierte und gruppengeschützte Physical-Stats-Analyse für Rowstore-Indizes/Heaps durch; LIMITED ist Default, SAMPLED/DETAILED sind explizit.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_physical_stats sowie je Datenbank sys.objects, sys.schemas und sys.indexes.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe erklärt jeden Parameter mit Eingabeform,
               NULL-/Leerwertregeln, Grenzen und allen festen Optionen.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Fachdaten.
               CONSOLE und TABLE liefern ausschließlich die Fachdaten;
               JSON enthält meta, indexPhysicalStats und databaseStatus.
               NONE unterdrückt direkte Resultsets. Hilfe folgt bereits
               erfolgter Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : Immer PHYSICAL_STATS_DEEP mit @HighImpactConfirmed=1 und separater Gruppenfreigabe. SQL 2019 VIEW DATABASE STATE bzw. CONTROL am Objekt; SQL 2022+ VIEW DATABASE PERFORMANCE STATE.
Eigenlast    : GEZIELT weist je Datenbank eine ObjectId zu; mehrere Treffer garantieren keine bestimmte Auswahl. Ohne Treffer wird keine NULL-Wildcard übergeben. VOLL kann breit lesen. LIMITED kann bereits relevant sein; SAMPLED/DETAILED können hohe I/O-/CPU-Kosten erzeugen. TOP filtert erst nach DMF-Ausführung.
Locking      : DMF kann IS-Locks auf Metadaten/Objekten anfordern; LOCK_TIMEOUT begrenzt Warten. Keine automatische Wartung.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_IndexPhysicalStats @DatabaseNames=N'SampleDatabase', @FullObjectNames=N'ExampleSchema.ExampleTable', @HighImpactConfirmed=1;
  EXEC monitor.USP_IndexPhysicalStats @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @ObjectNamePattern=N'like:Fact%', @ScanMode='SAMPLED', @MinPageCount=10000;
  EXEC monitor.USP_IndexPhysicalStats @Hilfe=1;
Änderungen   : 1.1.0 - GEZIELT als sicherer Default; fehlende exakte Objektauflösung löst keinen Datenbank-Wildcardscan aus.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_IndexPhysicalStats]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @IndexNames                     nvarchar(max)  = NULL
    , @IndexNamePattern               nvarchar(4000) = NULL
    , @AnalyseModus                   varchar(16)   = 'GEZIELT'
    , @ScanMode                       varchar(16)   = 'LIMITED'
    , @IndexId                        int           = NULL
    , @PartitionNumber                int           = NULL
    , @MinPageCount                   bigint        = 1000
    , @MinFragmentationPercent        decimal(9,2)  = 0
    , @MaxZeilen                      int           = 10000
    , @LockTimeoutMs                  int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit           = 1
    , @Hilfe                          bit           = 0
AS
BEGIN
 SET NOCOUNT ON;

    SET @Json = NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'indexPhysicalStats',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @DatabaseName sysname=NULL,@CrossDatabaseRequestedInternal bit=0,@DatenbankNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaNameLike nvarchar(4000)=NULL,@ObjectNameLike nvarchar(4000)=NULL;
    DECLARE @IndexNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit;
    DECLARE @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);
    IF @SchemaPatternMode='LIKE' SET @SchemaNameLike=@SchemaPatternValue;
    IF @ObjectPatternMode='LIKE' SET @ObjectNameLike=@ObjectPatternValue;
    DECLARE @IndexPatternMode varchar(8),@IndexPatternValue nvarchar(4000),@IndexRegexFlags varchar(8),@IndexPatternValid bit;
    SELECT @IndexPatternMode=[PatternMode],@IndexPatternValue=[PatternValue],@IndexRegexFlags=[RegexFlags],@IndexPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@IndexNamePattern);
    IF @IndexPatternMode='LIKE' SET @IndexNameLike=@IndexPatternValue;
    DECLARE @StatisticsPatternMode varchar(8)='NONE',@StatisticsPatternValue nvarchar(4000)=NULL,@StatisticsRegexFlags varchar(8)=NULL,@StatisticsPatternValid bit=1;
    DECLARE @DatabaseListCount int=0;
    IF @DatabaseNames IS NOT NULL AND NULLIF(LTRIM(RTRIM(@DatabaseNames)),N'') IS NOT NULL
        SELECT @DatabaseListCount=COUNT(*),@DatabaseName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1;
    SET @CrossDatabaseRequestedInternal=CONVERT(bit,CASE WHEN @DatabaseNames IS NULL OR @DatabaseNamePattern IS NOT NULL OR @DatabaseListCount>1 THEN 1 ELSE 0 END);
    SELECT @DatenbankNameLike=CASE WHEN [PatternMode]='LIKE' THEN [PatternValue] END FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    CREATE TABLE [#IndexPhysicalStats_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#IndexPhysicalStats_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=@IndexNames,@StatisticsNames=NULL,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#IndexPhysicalStats_NameFilters';
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='PHYSICAL_STATS_DEEP',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#IndexPhysicalStats_DatabaseCandidates';
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048); SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT')))); SET @ScanMode=UPPER(LTRIM(RTRIM(COALESCE(@ScanMode,'LIMITED'))));
 IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_IndexPhysicalStats';
        PRINT N'Liest physische Strukturstatistiken über sys.dm_db_index_physical_stats; eine Wartungsaktion wird nicht ausgeführt.';
        PRINT N'PHYSICAL_STATS_DEEP ist in jedem Modus aktiv und verlangt @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe. GEZIELT benötigt FullObjectNames oder exakte SchemaNames und ObjectNames.';
        PRINT N'Die PRINT-Hilfe folgt Namens-/Datenbankvorbereitung und gegebenenfalls TABLE-Preflight. Normale Analyseparameter werden danach geprüft.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. SQL-bit-Bestätigung mit 0 oder 1; von 0 verschiedene konvertierbare Zahlen werden beim Binden 1. PHYSICAL_STATS_DEEP ist stets aktiv, auch für GEZIELT, eine Datenbank und LIMITED. 0 bestätigt den Pfad nicht und führt im Auswahlpfad zu HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 erfüllt die Bestätigung, benötigt aber weiterhin die separate Gruppenfreigabe. NULL wird im normalen Auswahlpfad als INVALID_PARAMETER abgewiesen. Der Schalter vergibt keine SQL-Rechte.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N''like:App%''. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N''like:App%''. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'''' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.';
        PRINT N'@IndexNames nvarchar(max); Default: NULL. Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden. Ein aktiver Indexnamensfilter trifft keinen NULL-Indexnamen eines Heaps.';
        PRINT N'@IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @IndexNames kombinieren. Übergabe zum Beispiel N''like:App%''. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. Ein aktiver Filter trifft keinen NULL-Indexnamen eines Heaps.';
        PRINT N'@AnalyseModus varchar(16); Default: ''GEZIELT''. Nach LTRIM/RTRIM und UPPER sind ausschließlich GEZIELT und VOLL zulässig; NULL wird GEZIELT, leer oder ein anderer Wert ist INVALID_PARAMETER. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames; Pattern allein genügt nicht. Je Datenbank weist SELECT eine passende ObjectId einer Variablen zu; mehrere Treffer ergeben eine nicht zugesicherte Auswahl, nicht mehrere Objektaufrufe. Ohne auflösbares Objekt wird keine NULL-Wildcard an die DMF übergeben. VOLL lässt ObjectId NULL und wendet Namensfilter erst auf die DMF-Zeilen an. Beide Modi bleiben PHYSICAL_STATS_DEEP und benötigen @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe.';
        PRINT N'@ScanMode varchar(16); Default: ''LIMITED''. Nach LTRIM/RTRIM und UPPER sind ausschließlich LIMITED, SAMPLED und DETAILED zulässig; NULL wird LIMITED, leer oder andere Werte sind INVALID_PARAMETER. LIMITED liest bei B-Bäumen obere Ebenen. SAMPLED schätzt mit etwa 1 % der Seiten, unter 10.000 Seiten als DETAILED. DETAILED liest alle Seiten; Heaps können schon in LIMITED Datenzugriffe erfordern. Die Wahl beeinflusst die Diagnosearbeit, ersetzt aber keine Analysefreigabe.';
        PRINT N'@IndexId int; Default: NULL. Optionale numerische Index-ID, kein Indexname. Die Procedure akzeptiert NULL oder ganze Zahlen von 0 bis 2147483647; 0 bezeichnet den Heap, positive Werte eine Index-ID. Negative Werte sind INVALID_PARAMETER. Die IDs werden unverändert an die DMF weitergereicht; die Procedure prüft ihre Existenz und native Argumentkombination nicht vorab. VOLL erfordert nativ NULL; bei NULL muss auch @PartitionNumber NULL sein. Native Fehler werden je Datenbank protokolliert.';
        PRINT N'@PartitionNumber int; Default: NULL. Optionale ganze Partitionsnummer von 1 bis 2147483647; NULL wählt alle Partitionen des wirksamen DMF-Scopes. Kleinere nicht-NULL-Werte sind INVALID_PARAMETER. Die Procedure prüft Existenz und native Argumentkombination nicht vorab. Ein gesetzter Wert benötigt nativ konkrete Objekt- und Index-IDs. Fehler werden je Datenbank protokolliert; ein kleiner Zahlenwert garantiert keine vorhandene Partition.';
        PRINT N'@MinPageCount bigint; Default: 1000. Nichtnegative ganze Zahl von 0 bis 9223372036854775807 in Seiten. Der Default 1000 filtert kleine Ergebniszeilen; 0 setzt keine positive Mindestgröße. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck, macht den Vergleich page_count >= @MinPageCount aber UNKNOWN und liefert keine Treffer. Das WHERE-Prädikat folgt dem DMF-Aufruf und begrenzt dessen vorherige Arbeit nicht.';
        PRINT N'@MinFragmentationPercent decimal(9,2); Default: 0. Dezimaler Mindestwert von 0.00 bis 100.00 Prozent einschließlich; decimal(9,2) rundet beim Binden auf zwei Nachkommastellen. Außerhalb: INVALID_PARAMETER. NULL passiert die Bereichsprüfung als UNKNOWN, liefert aber keine Treffer. Auch NULL im nativen avg_fragmentation_in_percent erfüllt den Vergleich nicht, selbst bei Mindestwert 0. Der Filter wirkt auf DMF-Ergebnisse und begrenzt keine vorherige Scanarbeit.';
        PRINT N'@MaxZeilen int; Default: 10000. Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. Der Default ist 10000. TOP gilt je Datenbank nach DMF-Aufruf und Filtern, geordnet nach page_count und avg_fragmentation_in_percent absteigend; Gleichstände haben keinen zugesicherten Tie-Breaker. Die Endausgabe ergänzt Identitätsfelder zur Sortierung. Kein globales Zeilenlimit und keine Begrenzung der vorherigen DMF-Arbeit.';
        PRINT N'@LockTimeoutMs int; Default: 0. Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Physical-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexPhysicalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N''{"indexPhysicalStats":"#IndexHelpTarget"}''.';
        PRINT N'@JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexPhysicalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexPhysicalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.';
        PRINT N'@PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.';
        PRINT N'@Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.';
        PRINT N'Beispiel RAW: EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @HighImpactConfirmed=1, @ScanMode=''LIMITED'', @ResultSetArt=''RAW'';';
        PRINT N'Hilfe: EXEC [monitor].[USP_IndexPhysicalStats] @Hilfe=1;';














        RETURN;
 END;

    DECLARE @ModuleName sysname = N'USP_IndexPhysicalStats';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#IndexPhysicalStats_DatabaseStatus]
    (
          [DatabaseName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NULL
        , [StatusCode]         varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [IsPartial]          bit            NOT NULL
        , [RowCount]           bigint         NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [ErrorNumber]        int            NULL
        , [ErrorMessage]       nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail]             nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @FilterStatus<>'AVAILABLE' BEGIN SET @OverallStatus=@FilterStatus;SET @ErrorMessage=@FilterError;END;
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) OR (@IndexNames IS NOT NULL AND @IndexNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#IndexPhysicalStats_DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
    END;

 DECLARE @PhysicalAllowed bit=0; SELECT @PhysicalAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='PHYSICAL_STATS_DEEP';
 CREATE TABLE [#IndexPhysicalStats_Result]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [PartitionNumber] int NULL,[IndexLevel] tinyint NULL,[AllocationUnitTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexDepth] tinyint NULL,[IndexTypeDescPhysical] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [AvgFragmentationPercent] float NULL,[FragmentCount] bigint NULL,[AvgFragmentSizePages] float NULL,[PageCount] bigint NULL,[AvgPageSpaceUsedPercent] float NULL,
  [RecordCount] bigint NULL,[GhostRecordCount] bigint NULL,[VersionGhostRecordCount] bigint NULL,[MinRecordSizeBytes] int NULL,[MaxRecordSizeBytes] int NULL,[AvgRecordSizeBytes] float NULL,
  [ForwardedRecordCount] bigint NULL,[CompressedPageCount] bigint NULL,[ScanMode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 IF @OverallStatus='AVAILABLE' AND (@AnalyseModus NOT IN ('GEZIELT','VOLL') OR @ScanMode NOT IN ('LIMITED','SAMPLED','DETAILED') OR @MinPageCount<0 OR @MinFragmentationPercent<0 OR @MinFragmentationPercent>100 OR (@IndexId IS NOT NULL AND @IndexId<0) OR (@PartitionNumber IS NOT NULL AND @PartitionNumber<1))
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'Ungültige Physical-Stats-Parameter.'; INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]='FULL_OBJECT') AND (NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]='SCHEMA') OR NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_NameFilters] WHERE [FilterType]='OBJECT'))
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT benötigt exakte @SchemaNameLike- und @ObjectNameLike-Werte.'; INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @PhysicalAllowed=0
 BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'PHYSICAL_STATS_DEEP ist nicht freigegeben.'; INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE'
 BEGIN
  DECLARE @DbId int,@DbName sysname,@Sql nvarchar(max),@Rows bigint;
  DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName] FROM [#IndexPhysicalStats_DatabaseCandidates];
  OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  WHILE @@FETCH_STATUS=0
  BEGIN
   BEGIN TRY
    SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
DECLARE @ObjectIdFilter int=NULL;
IF @pMode COLLATE SQL_Latin1_General_CP1_CS_AS=''GEZIELT''
BEGIN
 SELECT @ObjectIdFilter=[o].[object_id]
 FROM sys.objects AS [o] WITH (NOLOCK)
 JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
 WHERE [o].[type] IN (''U'',''V'')'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N';
 IF @ObjectIdFilter IS NULL THROW 50001,N''Zielobjekt nicht gefunden oder nicht sichtbar; Physical Stats werden nicht mit NULL-Wildcard aufgerufen.'',1;
END;
INSERT #IndexPhysicalStats_Result
SELECT TOP (@pMaxRows) @pDbName,[s].[name],[o].[name],[ps].[object_id],[ps].[index_id],[i].[name],[i].[type_desc],[ps].[partition_number],[ps].[index_level],[ps].[alloc_unit_type_desc],[ps].[index_depth],[ps].[index_type_desc],
 [ps].[avg_fragmentation_in_percent],[ps].[fragment_count],[ps].[avg_fragment_size_in_pages],[ps].[page_count],[ps].[avg_page_space_used_in_percent],[ps].[record_count],[ps].[ghost_record_count],[ps].[version_ghost_record_count],
 [ps].[min_record_size_in_bytes],[ps].[max_record_size_in_bytes],[ps].[avg_record_size_in_bytes],[ps].[forwarded_record_count],[ps].[compressed_page_count],@pScanMode
FROM sys.dm_db_index_physical_stats(@pDbId,@ObjectIdFilter,@pIndexId,@pPartition,@pScanMode) AS [ps]
LEFT JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[ps].[object_id]
LEFT JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
LEFT JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[ps].[object_id] AND [i].[index_id]=[ps].[index_id]
WHERE [ps].[page_count]>=@pMinPages AND [ps].[avg_fragmentation_in_percent]>=@pMinFrag'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+@IndexPredicateI+N'
ORDER BY [ps].[page_count] DESC,[ps].[avg_fragmentation_in_percent] DESC
OPTION (MAXDOP 1,RECOMPILE);';
    EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pDbId int,@pMode varchar(16),@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pIndexLike nvarchar(256),@pScanMode varchar(16),@pIndexId int,@pPartition int,@pMinPages bigint,@pMinFrag decimal(9,2)',@pDbName=@DbName,@pDbId=@DbId,@pMode=@AnalyseModus,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pIndexLike=@IndexNameLike,@pScanMode=@ScanMode,@pIndexId=@IndexId,@pPartition=@PartitionNumber,@pMinPages=@MinPageCount,@pMinFrag=@MinFragmentationPercent;
    SELECT @Rows=COUNT_BIG(*) FROM [#IndexPhysicalStats_Result] WHERE [DatabaseName]=@DbName; INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE oder CONTROL am Objekt' ELSE N'VIEW DATABASE STATE oder CONTROL am Objekt' END,NULL,NULL,N'Physical Stats erfolgreich; ScanMode='+@ScanMode+N'.');
   END TRY
   BEGIN CATCH
    INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER()=50001 THEN 'UNAVAILABLE_OBJECT' WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,1,0,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE oder CONTROL' ELSE N'VIEW DATABASE STATE oder CONTROL' END,ERROR_NUMBER(),ERROR_MESSAGE(),N'Physical-Stats-Fehler isoliert; übrige Datenbanken laufen weiter.');
   END CATCH;
   FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  END; CLOSE dbcur; DEALLOCATE dbcur;
  IF NOT EXISTS(SELECT 1 FROM [#IndexPhysicalStats_DatabaseStatus]) INSERT [#IndexPhysicalStats_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
 END;



    SELECT @TotalRows = COUNT_BIG(*) FROM [#IndexPhysicalStats_Result];

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#IndexPhysicalStats_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#IndexPhysicalStats_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#IndexPhysicalStats_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'AVAILABLE_LIMITED' ELSE 'SKIPPED' END;
            SET @IsPartial = 1;
        END;
    END;

    IF @PrintMeldungen = 1 AND @OverallStatus <> 'AVAILABLE'
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG %s: %s', @OverallStatus, COALESCE(@ErrorMessage, @Detail, N'Teilergebnis oder eingeschränkte Sicht'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    IF @ResultSetArtNormalisiert<>'NONE' BEGIN
        SELECT @ModuleName [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@OverallStatus [StatusCode],@IsPartial [IsPartial],@TotalRows [RowCount],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage],@Detail [Detail];
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#IndexPhysicalStats_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#IndexPhysicalStats_Result] ORDER BY [PageCount] DESC,[AvgFragmentationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber]; ELSE SELECT N'Index Physical Stats' [Ergebnis],[r].* FROM [#IndexPhysicalStats_Result] [r] ORDER BY [PageCount] DESC,[AvgFragmentationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber];
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#IndexPhysicalStats_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#IndexPhysicalStats_Result] ORDER BY [PageCount] DESC,[AvgFragmentationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"indexPhysicalStats":',COALESCE(@JsonData1,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#IndexPhysicalStats_Result'
            , @ResultLabel=N'IndexPhysicalStats'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#IndexPhysicalStats_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
