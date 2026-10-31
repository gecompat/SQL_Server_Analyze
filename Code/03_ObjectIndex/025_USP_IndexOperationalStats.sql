USE [DeineDatenbank];
GO

SET QUOTED_IDENTIFIER ON;
GO

/*
===============================================================================
Objekt       : monitor.USP_IndexOperationalStats
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Analysiert aktuelle kumulative Zugriffs-, Lock-, Latch-, I/O-
               Latch-, Page-Split- und Lock-Eskalationszähler je Indexpartition.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_operational_stats sowie sys.objects, sys.schemas,
               sys.indexes und sys.tables der jeweiligen Zieldatenbank.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-Regeln, Grenzen und den vollständigen festen Optionen.
               GEZIELT verlangt FullObjectNames oder exakte SchemaNames und
               ObjectNames. Zusätzliche Pattern bleiben Patternfilter; sie
               ersetzen diese Anforderung nicht. VOLL prüft
               INDEX_OPERATIONAL_DEEP einschließlich Bestätigung und separater
               Gruppenberechtigung; PartitionNumber ist dann unzulässig.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Operational Stats.
               CONSOLE und TABLE liefern nur Operational Stats; JSON enthält
               meta, indexOperationalStats und databaseStatus. NONE
               unterdrückt direkte Resultsets. Hilfe folgt bereits erfolgter
               Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : GEZIELT: CONTROL auf dem Objekt oder ausreichender Database-State-
               Zugriff. VOLL: SQL 2019 VIEW DATABASE STATE, SQL 2022+
               VIEW DATABASE PERFORMANCE STATE. Keine Rechtevergabe.
Eigenlast    : GEZIELT ruft die DMF je Datenbank für eine zugewiesene ObjectId
               auf. Bei mehreren passenden Objekten ist die Auswahl nicht
               festgelegt; ohne Treffer wird keine NULL-Wildcard übergeben. VOLL kann alle Heap-/B-Tree-/Columnstore-Rowsets lesen und ist
               deshalb explizit gruppengeschützt. TOP reduziert nicht zwingend
               die DMF-Arbeit.
Locking      : Rein lesend, kann Metadaten-/Objektzugriffe auslösen; LOCK_TIMEOUT
               begrenzt Warten. Memory-optimized Indizes sind nicht enthalten und
               werden über USP_IndexUsage/XTP separat analysiert.
Partial      : Datenbankfehler werden isoliert. Ein nicht auflösbares Zielobjekt
               wird niemals als NULL-Wildcard an die DMF übergeben.
Beispiele    :
  EXEC monitor.USP_IndexOperationalStats @DatabaseNames=N'SampleDatabase',
       @SchemaNames=N'dbo', @ObjectNames=N'FactSales';
  EXEC monitor.USP_IndexOperationalStats @DatabaseNames=N'SampleDatabase',
       @AnalyseModus='VOLL', @HighImpactConfirmed=1, @ObjectNamePattern=N'Fact%', @MaxZeilen=10000;
  EXEC monitor.USP_IndexOperationalStats @Hilfe=1;
Änderungen   : 1.1.0 - Exakte Equality-Auflösung erlaubt Unterstriche und andere reguläre Namenszeichen.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_IndexOperationalStats]
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
    , @AnalyseModus                varchar(16)   = 'GEZIELT'
    , @PartitionNumber             int           = NULL
    , @NurMitAktivitaet            bit           = 1
    , @MinLeafPageAllocations      bigint        = 0
    , @MinLockWaitMs               bigint        = 0
    , @MaxZeilen                   int           = 5000
    , @LockTimeoutMs               int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen              bit           = 1
    , @Hilfe                       bit           = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @Json = NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'indexOperationalStats',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
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
    CREATE TABLE [#IndexOperationalStats_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#IndexOperationalStats_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=@IndexNames,@StatisticsNames=NULL,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#IndexOperationalStats_NameFilters';
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='OBJECT_ANALYSIS_CURRENT',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#IndexOperationalStats_DatabaseCandidates';
    IF @FilterStatus='AVAILABLE' AND UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,''))))='VOLL'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='INDEX_OPERATIONAL_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_IndexOperationalStats';
        PRINT N'Liefert kumulative Operational-Stats-Zähler je Indexpartition; darunter DML, Page-Allokationen, Locks, Latches, I/O-Latches, Scans und Lookups. Metadata-Cache-Eviction kann die Counter zurücksetzen.';
        PRINT N'GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Muster können zusätzlich filtern; sie ersetzen diese Auswahlvoraussetzung nicht. VOLL prüft INDEX_OPERATIONAL_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.';
        PRINT N'@Hilfe=1 gibt PRINT-Hilfe aus und kehrt vor der fachlichen DMF-Abfrage zurück. Filter-/Datenbankauswahl und ein angefordertes TABLE-Mapping laufen zuvor.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. bit-Bestätigung für den VOLL-Pfad INDEX_OPERATIONAL_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schema-Pattern gemäß TVF_ParsePattern: NULL = keines; äußere Leerzeichen trimmen, Präfix like:/regex:/regexi: ohne Beachtung der Großschreibung, sonst LIKE; leerer Inhalt oder leeres Präfix ungültig. LIKE-Schemavergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i. Schema-Regex wird am Schemaquellpfad ausgeführt; dieser Pfad prüft SQL Server 2025 und Compatibility Level 170. Exakte Liste und Pattern derselben Eigenschaft sind exklusiv. In GEZIELT ersetzt ein Muster nicht die Voraussetzung aus FullObjectNames oder beiden exakten Listen. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objekt-Pattern gemäß TVF_ParsePattern: NULL = keines; äußerer Trim; Präfix like:/regex:/regexi: wird ohne Beachtung der Großschreibung erkannt, sonst LIKE; leere Werte oder leeres Präfix sind ungültig. LIKE-Objektvergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i; Objekt-Regex wird im Objektquellpfad ausgeführt und prüft SQL Server 2025/Compatibility Level 170. Nicht gemeinsam mit @ObjectNames. Ein Muster allein erfüllt die GEZIELT-Auswahlvoraussetzung nicht. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'''' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.';
        PRINT N'@IndexNames nvarchar(max); Default: NULL. Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden.';
        PRINT N'@IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexnamen-Pattern gemäß TVF_ParsePattern: NULL = keines; äußerer Trim; Präfix like:, regex: oder regexi: ohne Beachtung der Großschreibung, sonst LIKE. Leerer Rest/Präfix ist ungültig. LIKE ist case-sensitive mit SQL-Wildcards; regex: verwendet Flag c und regexi: Flag i und benötigt SQL Server 2025/Compatibility Level 170, geprüft am Indexquellpfad. Nicht gemeinsam mit @IndexNames. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@AnalyseModus varchar(16); Default: ''GEZIELT''. Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Die Filter können mehrere Objekte bezeichnen; der Quellcode löst @ObjectIdFilter per SELECT-Variablenzuweisung auf passende Objekte auf und garantiert dabei keine bestimmte Auswahl, falls mehrere übereinstimmen. VOLL aktiviert INDEX_OPERATIONAL_DEEP und benötigt dessen Freigabe sowie @HighImpactConfirmed=1. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER.';
        PRINT N'@PartitionNumber int; Default: NULL. Optionale positive int-Partitionsnummer, Bereich 1 bis 2147483647. In GEZIELT wird sie für die zugewiesene ObjectId an die DMF übergeben; NULL umfasst dort alle Partitionen dieses Objekts. VOLL verlangt NULL und verwendet den breiten Rowset-Pfad; nur ein nicht-NULL-Wert ist auf GEZIELT beschränkt. Werte kleiner 1 sind INVALID_PARAMETER.';
        PRINT N'@NurMitAktivitaet bit; Default: 1. bit-Filter: 0 lässt auch Nullaktivitätszeilen zu; 1 verlangt mindestens einen der im Quellprädikat addierten DML-, Range-/Lookup-, Lock-, Page-Latch- oder I/O-Latch-Zähler größer Null. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte konvertieren beim Binden zu 1. Bei NULL wird die Bedingung @P=0 OR Aktivitätsausdruck>0 für Nullaktivität nicht TRUE, sodass solche Zeilen ausgeschlossen werden.';
        PRINT N'@MinLeafPageAllocations bigint; Default: 0. Nichtnegative bigint-Mindestzahl kumulativer Leaf-Page-Allokationen je Partition, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber leaf_allocation_count >= @P UNKNOWN und lässt keine Zeile passieren.';
        PRINT N'@MinLockWaitMs bigint; Default: 0. Nichtnegative bigint-Mindestzeit in Millisekunden für Row- plus Page-Lock-Wait-Zeit, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber den nachfolgenden Summenvergleich UNKNOWN und lässt keine Zeile passieren.';
        PRINT N'@MaxZeilen int; Default: 5000. Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. TOP gilt für die Operational-Stats-Quellabfrage je Datenbank. Die Auswahl sortiert vorab nach I/O-Latch-Wartezeit, Page-Latch-Wartezeit, Row-/Page-Lock-Wartezeit und Leaf-Page-Allokationen absteigend; die Endausgabe verwendet eine eigene Sortierung. Keine globale Zeilenobergrenze und kein Limit für die vorherige DMF-/Katalogarbeit.';
        PRINT N'@LockTimeoutMs int; Default: 0. int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; mit nichtnegativen übrigen Zahlen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N''SET LOCK_TIMEOUT '' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Operational-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexOperationalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N''{"indexOperationalStats":"#IndexHelpTarget"}''.';
        PRINT N'@JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexOperationalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexOperationalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.';
        PRINT N'@PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.';
        PRINT N'@Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.';
        PRINT N'CONSOLE: EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N''[ExampleDatabase]'', @SchemaNames=N''dbo'', @ObjectNames=N''ExampleTable'', @ResultSetArt=''CONSOLE'';';
        PRINT N'RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''dbo.ExampleTable'', @ResultSetArt=''RAW'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;';
        PRINT N'TABLE: CREATE TABLE #IndexOperationalStatsTarget([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''dbo.ExampleTable'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"indexOperationalStats":"#IndexOperationalStatsTarget"}''; END TRY BEGIN CATCH DROP TABLE #IndexOperationalStatsTarget; THROW; END CATCH; DROP TABLE #IndexOperationalStatsTarget;';
        PRINT N'Hilfe: EXEC [monitor].[USP_IndexOperationalStats] @Hilfe=1;';
        
                
        
        
        
        
        
        
        
        
        RETURN;
    END;

    DECLARE @ModuleName sysname=N'USP_IndexOperationalStats',
            @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),
            @OverallStatus varchar(40)='AVAILABLE',
            @IsPartial bit=0,
            @TotalRows bigint=0,
            @ErrorNumber int=NULL,
            @ErrorMessage nvarchar(2048)=NULL,
            @Detail nvarchar(2000)=NULL,
            @OperationalDeepAllowed bit=1;

    CREATE TABLE [#IndexOperationalStats_DatabaseStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
          [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL,
          [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ErrorNumber] int NULL,
          [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#IndexOperationalStats_Result]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
          [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ObjectId] int NOT NULL,
          [IsMemoryOptimized] bit NULL, [IndexId] int NOT NULL,
          [IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [IndexTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
          [PartitionNumber] int NOT NULL, [HobtId] bigint NULL,
          [LeafInsertCount] bigint NOT NULL, [LeafDeleteCount] bigint NOT NULL,
          [LeafUpdateCount] bigint NOT NULL, [LeafGhostCount] bigint NOT NULL,
          [LeafPageAllocationCount] bigint NOT NULL, [NonleafPageAllocationCount] bigint NOT NULL,
          [LeafPageMergeCount] bigint NOT NULL, [RangeScanCount] bigint NOT NULL,
          [SingletonLookupCount] bigint NOT NULL, [ForwardedFetchCount] bigint NOT NULL,
          [LobFetchPages] bigint NOT NULL, [RowOverflowFetchPages] bigint NOT NULL,
          [RowLockCount] bigint NOT NULL, [RowLockWaitCount] bigint NOT NULL,
          [RowLockWaitMs] bigint NOT NULL, [PageLockCount] bigint NOT NULL,
          [PageLockWaitCount] bigint NOT NULL, [PageLockWaitMs] bigint NOT NULL,
          [LockPromotionAttemptCount] bigint NOT NULL, [LockPromotionCount] bigint NOT NULL,
          [PageLatchWaitCount] bigint NOT NULL, [PageLatchWaitMs] bigint NOT NULL,
          [PageIoLatchWaitCount] bigint NOT NULL, [PageIoLatchWaitMs] bigint NOT NULL,
          [TreePageLatchWaitCount] bigint NOT NULL, [TreePageLatchWaitMs] bigint NOT NULL,
          [PageCompressionAttemptCount] bigint NOT NULL, [PageCompressionSuccessCount] bigint NOT NULL,
          [LeafAllocationsPerInsert] decimal(19,6) NULL,
          [LockWaitMsPerWait] decimal(19,4) NULL,
          [PageLatchWaitMsPerWait] decimal(19,4) NULL,
          [PageIoLatchWaitMsPerWait] decimal(19,4) NULL,
          [UsageClassification] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @AnalyseModus='VOLL'
        SELECT @OperationalDeepAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0)
        FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='INDEX_OPERATIONAL_DEEP';

    IF @FilterStatus<>'AVAILABLE' BEGIN SET @OverallStatus=@FilterStatus;SET @ErrorMessage=@FilterError;END;
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) OR (@IndexNames IS NOT NULL AND @IndexNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
    IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @MinLeafPageAllocations<0 OR @MinLockWaitMs<0 OR (@PartitionNumber IS NOT NULL AND @PartitionNumber<1)
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'Numerischer Parameter außerhalb des zulässigen Bereichs.'; END
    ELSE IF @AnalyseModus NOT IN ('GEZIELT','VOLL')
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@AnalyseModus muss GEZIELT oder VOLL sein.'; END
    ELSE IF @AnalyseModus='GEZIELT'
         AND NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]='FULL_OBJECT')
         AND (NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]='SCHEMA')
              OR NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_NameFilters] WHERE [FilterType]='OBJECT'))
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT benötigt @FullObjectNames oder exakte @SchemaNames und @ObjectNames.'; END
    ELSE IF @AnalyseModus='VOLL' AND @OperationalDeepAllowed=0
    BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'INDEX_OPERATIONAL_DEEP ist nicht freigegeben.'; END
    ELSE IF @AnalyseModus='VOLL' AND @PartitionNumber IS NOT NULL
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@PartitionNumber ist nur im GEZIELT-Modus zulässig.'; END;

    IF @OverallStatus<>'AVAILABLE'
    BEGIN
        INSERT [#IndexOperationalStats_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,N'Keine DMF-Abfrage ausgeführt.');
        SET @IsPartial=1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
        DECLARE @DbId int,@DbName sysname,@Sql nvarchar(max),@Rows bigint;
        DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName]
            FROM [#IndexOperationalStats_DatabaseCandidates];
        OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            BEGIN TRY
                SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
DECLARE @ObjectIdFilter int=NULL;
IF @pMode=''GEZIELT''
BEGIN
    SELECT @ObjectIdFilter=[o].[object_id]
    FROM sys.objects AS [o] WITH (NOLOCK)
    JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    WHERE [o].[type] IN (''U'',''V'')'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N';
    IF @ObjectIdFilter IS NULL THROW 50001,N''Zielobjekt nicht gefunden oder nicht sichtbar; die DMF wird nicht mit NULL-Wildcard aufgerufen.'',1;
END;
INSERT #IndexOperationalStats_Result
SELECT TOP (@pMaxRows)
       @pDbName,[s].[name],[o].[name],[os].[object_id],[t].[is_memory_optimized],[os].[index_id],[i].[name],[i].[type_desc],
       [os].[partition_number],[os].[hobt_id],
       [os].[leaf_insert_count],[os].[leaf_delete_count],[os].[leaf_update_count],[os].[leaf_ghost_count],
       [os].[leaf_allocation_count],[os].[nonleaf_allocation_count],[os].[leaf_page_merge_count],
       [os].[range_scan_count],[os].[singleton_lookup_count],[os].[forwarded_fetch_count],
       [os].[lob_fetch_in_pages],[os].[row_overflow_fetch_in_pages],
       [os].[row_lock_count],[os].[row_lock_wait_count],[os].[row_lock_wait_in_ms],
       [os].[page_lock_count],[os].[page_lock_wait_count],[os].[page_lock_wait_in_ms],
       [os].[index_lock_promotion_attempt_count],[os].[index_lock_promotion_count],
       [os].[page_latch_wait_count],[os].[page_latch_wait_in_ms],
       [os].[page_io_latch_wait_count],[os].[page_io_latch_wait_in_ms],
       [os].[tree_page_latch_wait_count],[os].[tree_page_latch_wait_in_ms],
       [os].[page_compression_attempt_count],[os].[page_compression_success_count],
       CONVERT(decimal(19,6),[os].[leaf_allocation_count]*1.0/NULLIF([os].[leaf_insert_count],0)),
       CONVERT(decimal(19,4),([os].[row_lock_wait_in_ms]+[os].[page_lock_wait_in_ms])*1.0/NULLIF([os].[row_lock_wait_count]+[os].[page_lock_wait_count],0)),
       CONVERT(decimal(19,4),[os].[page_latch_wait_in_ms]*1.0/NULLIF([os].[page_latch_wait_count],0)),
       CONVERT(decimal(19,4),[os].[page_io_latch_wait_in_ms]*1.0/NULLIF([os].[page_io_latch_wait_count],0)),
       CASE WHEN [os].[index_lock_promotion_count]>0 THEN ''LOCK_ESCALATIONS''
            WHEN [os].[page_io_latch_wait_in_ms]>0 THEN ''PAGE_IO_LATCH_WAITS''
            WHEN [os].[page_latch_wait_in_ms]>0 THEN ''PAGE_LATCH_WAITS''
            WHEN [os].[row_lock_wait_in_ms]+[os].[page_lock_wait_in_ms]>0 THEN ''LOCK_WAITS''
            WHEN [os].[leaf_allocation_count]>0 THEN ''LEAF_PAGE_ALLOCATIONS''
            ELSE ''ACTIVITY_WITHOUT_CLASSIFIED_WAIT'' END
FROM sys.dm_db_index_operational_stats(@pDbId,@ObjectIdFilter,NULL,@pPartition) AS [os]
LEFT JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[os].[object_id]
LEFT JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
LEFT JOIN sys.tables AS [t] WITH (NOLOCK) ON [t].[object_id]=[o].[object_id]
LEFT JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[os].[object_id] AND [i].[index_id]=[os].[index_id]
WHERE 1=1'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+@IndexPredicateI+N'
  AND [os].[leaf_allocation_count]>=@pMinLeafAlloc
  AND [os].[row_lock_wait_in_ms]+[os].[page_lock_wait_in_ms]>=@pMinLockWaitMs
  AND (@pOnlyActivity=0 OR
       [os].[leaf_insert_count]+[os].[leaf_delete_count]+[os].[leaf_update_count]+[os].[leaf_ghost_count]+
       [os].[range_scan_count]+[os].[singleton_lookup_count]+[os].[row_lock_count]+[os].[page_lock_count]+
       [os].[page_latch_wait_count]+[os].[page_io_latch_wait_count]>0)
ORDER BY [os].[page_io_latch_wait_in_ms] DESC,[os].[page_latch_wait_in_ms] DESC,
         [os].[row_lock_wait_in_ms]+[os].[page_lock_wait_in_ms] DESC,[os].[leaf_allocation_count] DESC
OPTION (MAXDOP 1,RECOMPILE);';
                EXEC [sys].[sp_executesql] @Sql,
                     N'@pDbName sysname,@pDbId int,@pMode varchar(16),@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pIndexLike nvarchar(256),@pPartition int,@pMaxRows bigint,@pOnlyActivity bit,@pMinLeafAlloc bigint,@pMinLockWaitMs bigint',
                     @pDbName=@DbName,@pDbId=@DbId,@pMode=@AnalyseModus,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,
                     @pIndexLike=@IndexNameLike,@pPartition=@PartitionNumber,@pMaxRows=@EffectiveMaxZeilen,@pOnlyActivity=@NurMitAktivitaet,
                     @pMinLeafAlloc=@MinLeafPageAllocations,@pMinLockWaitMs=@MinLockWaitMs;
                SELECT @Rows=COUNT_BIG(*) FROM [#IndexOperationalStats_Result] WHERE [DatabaseName]=@DbName;
                INSERT [#IndexOperationalStats_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,
                    CASE WHEN @AnalyseModus='GEZIELT' THEN N'CONTROL am Zielobjekt oder Database-State-Recht'
                         WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE'
                         ELSE N'VIEW DATABASE STATE' END,
                    NULL,NULL,N'Kumulative Operational Stats erfolgreich gelesen; Counter können bei Metadata-Cache-Eviction zurückgesetzt werden.');
            END TRY
            BEGIN CATCH
                INSERT [#IndexOperationalStats_DatabaseStatus] VALUES(@DbName,
                    CASE WHEN ERROR_NUMBER()=50001 THEN 'UNAVAILABLE_OBJECT'
                         WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                         WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                         WHEN ERROR_NUMBER() IN (207,208,4121) THEN 'UNAVAILABLE_OBJECT'
                         ELSE 'ERROR_HANDLED' END,
                    1,0,CASE WHEN @AnalyseModus='GEZIELT' THEN N'CONTROL am Zielobjekt oder Database-State-Recht'
                             WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE'
                             ELSE N'VIEW DATABASE STATE' END,
                    ERROR_NUMBER(),ERROR_MESSAGE(),N'Datenbank-/Objektfehler isoliert.');
            END CATCH;
            FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        END;
        CLOSE dbcur; DEALLOCATE dbcur;
        IF NOT EXISTS(SELECT 1 FROM [#IndexOperationalStats_DatabaseStatus])
            INSERT [#IndexOperationalStats_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
    END;


    SELECT @TotalRows=COUNT_BIG(*) FROM [#IndexOperationalStats_Result];
    IF @OverallStatus='AVAILABLE'
    BEGIN
        IF EXISTS(SELECT 1 FROM [#IndexOperationalStats_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN SET @OverallStatus=CASE WHEN @TotalRows>0 THEN 'PARTIAL' ELSE (SELECT TOP(1) [StatusCode] FROM [#IndexOperationalStats_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END; SET @IsPartial=1; END
        ELSE IF EXISTS(SELECT 1 FROM [#IndexOperationalStats_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN SET @OverallStatus=CASE WHEN @TotalRows>0 THEN 'AVAILABLE_LIMITED' ELSE 'SKIPPED' END; SET @IsPartial=1; END;
    END;
    IF @PrintMeldungen=1 AND @OverallStatus<>'AVAILABLE'
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG %s: %s', @OverallStatus, COALESCE(@ErrorMessage,@Detail,N'Teilergebnis oder eingeschränkte Sicht'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    IF @ResultSetArtNormalisiert<>'NONE' BEGIN
        SELECT @ModuleName [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@OverallStatus [StatusCode],@IsPartial [IsPartial],@TotalRows [RowCount],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage],@Detail [Detail];
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#IndexOperationalStats_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#IndexOperationalStats_Result] ORDER BY [LeafPageAllocationCount] DESC,[PageLockWaitMs] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber]; ELSE SELECT N'Index Operational Stats' [Ergebnis],[r].* FROM [#IndexOperationalStats_Result] [r] ORDER BY [LeafPageAllocationCount] DESC,[PageLockWaitMs] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber];
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#IndexOperationalStats_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#IndexOperationalStats_Result] ORDER BY [LeafPageAllocationCount] DESC,[PageLockWaitMs] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"indexOperationalStats":',COALESCE(@JsonData1,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#IndexOperationalStats_Result'
            , @ResultLabel=N'IndexOperationalStats'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#IndexOperationalStats_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
