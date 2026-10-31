USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_IndexUsage
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Liefert kumulative Indexnutzung seit dem letzten DMV-Reset und klassifiziert gelesene, schreiblastige sowie seit Reset ungenutzte Indizes.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_usage_stats, sys.dm_db_xtp_index_stats,
               sys.dm_os_sys_info sowie je Datenbank sys.objects, sys.tables,
               sys.schemas, sys.indexes, sys.hash_indexes und sys.partitions.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-Regeln, Grenzen und den vollständigen festen Optionen.
               GEZIELT benötigt einen Objektfilter; VOLL prüft CATALOG_DEEP
               einschließlich Bestätigung und separater Gruppenberechtigung.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus, klassische Indexnutzung
               und XTP-Nutzung. CONSOLE und TABLE liefern nur klassische
               Indexnutzung; JSON enthält meta, rowstoreIndexes,
               memoryOptimizedIndexes und databaseStatus. NONE unterdrückt
               direkte Resultsets. Hilfe kann vorherige Filtervorbereitung
               und TABLE-Preflight nicht rückgängig machen.
Berechtigung : SQL Server 2019 VIEW SERVER STATE; SQL Server 2022+ VIEW SERVER PERFORMANCE STATE. Metadaten zusätzlich gemäß Sichtbarkeit.
Eigenlast    : Moderate DMV-/Katalogabfrage; keine Physical-Stats-Scans.
Locking      : DMV plus READUNCOMMITTED-Kataloge; LOCK_TIMEOUT konfigurierbar.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_IndexUsage @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_IndexUsage @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @NurUngenutzt=1, @MinUserUpdates=1000;
  EXEC monitor.USP_IndexUsage @Hilfe=1;
Änderungen   : 1.1.0 - Indexed Views, Spatial-Kennzeichnung und isolierter
               In-Memory-OLTP-Resultset ergänzt.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_IndexUsage]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @AnalyseModus                  varchar(16)   = 'GEZIELT'
    , @NurUngenutzt                   bit           = 0
    , @MinUserUpdates                 bigint        = 0
    , @PrimaryUndUniqueEinbeziehen    bit           = 1
    , @MitMemoryOptimized              bit           = 1
    , @MaxZeilen                      int           = 5000
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'rowstoreIndexes',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @DatabaseName sysname=NULL,@CrossDatabaseRequestedInternal bit=0,@DatenbankNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaNameLike nvarchar(4000)=NULL,@ObjectNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit;
    DECLARE @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);
    IF @SchemaPatternMode='LIKE' SET @SchemaNameLike=@SchemaPatternValue;
    IF @ObjectPatternMode='LIKE' SET @ObjectNameLike=@ObjectPatternValue;
    DECLARE @IndexPatternMode varchar(8)='NONE',@IndexPatternValue nvarchar(4000)=NULL,@IndexRegexFlags varchar(8)=NULL,@IndexPatternValid bit=1;
    DECLARE @StatisticsPatternMode varchar(8)='NONE',@StatisticsPatternValue nvarchar(4000)=NULL,@StatisticsRegexFlags varchar(8)=NULL,@StatisticsPatternValid bit=1;
    DECLARE @DatabaseListCount int=0;
    IF @DatabaseNames IS NOT NULL AND NULLIF(LTRIM(RTRIM(@DatabaseNames)),N'') IS NOT NULL
        SELECT @DatabaseListCount=COUNT(*),@DatabaseName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1;
    SET @CrossDatabaseRequestedInternal=CONVERT(bit,CASE WHEN @DatabaseNames IS NULL OR @DatabaseNamePattern IS NOT NULL OR @DatabaseListCount>1 THEN 1 ELSE 0 END);
    SELECT @DatenbankNameLike=CASE WHEN [PatternMode]='LIKE' THEN [PatternValue] END FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    CREATE TABLE [#IndexUsage_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#IndexUsage_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=NULL,@StatisticsNames=NULL,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#IndexUsage_NameFilters';
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='OBJECT_ANALYSIS_CURRENT',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#IndexUsage_DatabaseCandidates';
    IF @FilterStatus='AVAILABLE' AND UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,''))))='VOLL'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='CATALOG_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
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
        PRINT N'monitor.USP_IndexUsage';
        PRINT N'Liefert kumulative Indexnutzungszähler seit dem DMV-Reset für klassische Indizes einschließlich sichtbarer Columnstore- und Spatial-Indizes; XTP-Zähler werden optional getrennt erhoben.';
        PRINT N'GEZIELT braucht einen Objekt-/Namensfilter; eine Datenbankauswahl allein genügt nicht. VOLL prüft CATALOG_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.';
        PRINT N'@Hilfe=1 gibt PRINT-Hilfe aus und kehrt vor der fachlichen Abfrage zurück. Filter-/Datenbankauswahl und ein angefordertes TABLE-Mapping laufen zuvor.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. bit-Bestätigung für den VOLL-Pfad CATALOG_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schema-Pattern gemäß TVF_ParsePattern: NULL = keines; äußere Leerzeichen trimmen, Präfix like:/regex:/regexi: ohne Beachtung der Großschreibung, sonst LIKE; leerer Inhalt oder leeres Präfix ungültig. LIKE-Schemavergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i. Schema-Regex wird am Schemaquellpfad ausgeführt; dieser Pfad prüft SQL Server 2025 und Compatibility Level 170. Exakte Liste und Pattern derselben Eigenschaft sind exklusiv. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Für GEZIELT genügt eine nichtleere exakte Namensliste als Objektfilter; zusätzliche Schemafilter können den Scope weiter einschränken.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objekt-Pattern gemäß TVF_ParsePattern: NULL = keines; äußerer Trim; Präfix like:/regex:/regexi: wird ohne Beachtung der Großschreibung erkannt, sonst LIKE; leere Werte oder leeres Präfix sind ungültig. LIKE-Objektvergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i; Objekt-Regex wird im Objektquellpfad ausgeführt und prüft SQL Server 2025/Compatibility Level 170. Nicht gemeinsam mit @ObjectNames. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N''like:App%''; nach Präfixentfernung wird nicht erneut getrimmt.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'''' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.';
        PRINT N'@AnalyseModus varchar(16); Default: ''GEZIELT''. Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt eine exakte Namenliste, FullObjectNames oder mindestens ein Schema-/Objekt-Pattern; nur DatabaseNames genügt nicht. VOLL erweitert auf die breite Indexkataloganalyse und aktiviert CATALOG_DEEP. Dieser Pfad benötigt die Freigabe für CATALOG_DEEP sowie @HighImpactConfirmed=1; GEZIELT verlangt keine High-Impact-Bestätigung. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER.';
        PRINT N'@NurUngenutzt bit; Default: 0. bit-Filter auf beide Resultsets: 0 lässt Rowstore- und XTP-Zeilen unabhängig von Nutzung zu; 1 lässt Rowstore-Indizes ohne User-Seeks, Scans und Lookups seit sichtbarem Reset zu und XTP-Indizes mit ScansStarted=0. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. Bei NULL macht die jeweilige Gleich-Null-ODER-Ungenutzt-Bedingung reguläre genutzte Zeilen nicht wahr; nur Zeilen, deren Ungenutzt-Prüfung wahr ist, können passieren.';
        PRINT N'@MinUserUpdates bigint; Default: 0. Nichtnegative bigint-Mindestzahl kumulativer User-Update-Operationen im klassischen Rowstore-Resultset; zulässiger Bereich 0 bis 9223372036854775807, Default 0 schränkt nicht ein. Negative Werte führen bei fachlicher Validierung zu INVALID_PARAMETER. NULL besteht den Kleiner-Null-Prüftest in SQL-Dreifachlogik, macht danach aber COALESCE(user_updates,0) >= @MinUserUpdates UNKNOWN und lässt dadurch keine Rowstore-Zeile passieren. Für XTP wird dieser Filter nicht angewandt.';
        PRINT N'@PrimaryUndUniqueEinbeziehen bit; Default: 1. bit-Schalter für Primary-Key- und Unique-Constraint-Indizes in Rowstore und XTP: 0 schließt diese beiden Schutzarten aus; 1 lässt sie zu. Bei NULL lautet die Filterbedingung @P=1 OR (is_primary_key=0 AND is_unique_constraint=0): normale Indizes können passieren, PK-/Unique-Constraint-Indizes nicht. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters werden beim Binden zu 1 konvertiert.';
        PRINT N'@MitMemoryOptimized bit; Default: 1. bit-Schalter für die separate XTP-Abfrage: 0 überspringt sie; 1 versucht sys.dm_db_xtp_index_stats und befüllt bei Erfolg den XTP-Datenbestand; das vierte RAW-Resultset und der JSON-Schlüssel memoryOptimizedIndexes existieren auch bei übersprungenem Zweig mit leerer Datenmenge. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. NULL erfüllt IF @MitMemoryOptimized=1 nicht und überspringt den Zweig. Der klassische Rowstore-Zweig bleibt separat.';
        PRINT N'@MaxZeilen int; Default: 5000. Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. Die Grenze gilt je Datenbank und getrennt für die Rowstore- und XTP-Quellabfragen. Rowstore-TOP sortiert vorab nach UserUpdates absteigend, dann RowCount absteigend; XTP-TOP nach ScansStarted absteigend, dann RowsTouched absteigend. Keine globale Zeilenobergrenze; die Endausgabe hat eigene Sortierung und Katalog-/DMV-Vorarbeit ist nicht dadurch begrenzt.';
        PRINT N'@LockTimeoutMs int; Default: 0. int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; zusammen mit nichtnegativem MaxZeilen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N''SET LOCK_TIMEOUT '' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Rowstore-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus, Rowstore und stets als viertes Resultset den XTP-Datensatz, bei übersprungenem XTP-Zweig leer als Resultsets aus; TABLE schreibt das Rowstore-Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitive Resultnamen und Stringziel erwartet: rowstoreIndexes als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N''{"rowstoreIndexes":"#IndexHelpTarget"}''.';
        PRINT N'@JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.';
        PRINT N'@PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.';
        PRINT N'@Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.';
        PRINT N'CONSOLE: EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N''[ExampleDatabase]'', @SchemaNames=N''dbo'', @ObjectNames=N''ExampleTable'', @ResultSetArt=''CONSOLE'';';
        PRINT N'RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N''[ExampleDatabase]'', @SchemaNames=N''dbo'', @ObjectNames=N''ExampleTable'', @ResultSetArt=''RAW'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;';
        PRINT N'TABLE: CREATE TABLE #IndexUsageTarget([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N''[ExampleDatabase]'', @SchemaNames=N''dbo'', @ObjectNames=N''ExampleTable'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"rowstoreIndexes":"#IndexUsageTarget"}''; END TRY BEGIN CATCH DROP TABLE #IndexUsageTarget; THROW; END CATCH; DROP TABLE #IndexUsageTarget;';
        PRINT N'Hilfe: EXEC [monitor].[USP_IndexUsage] @Hilfe=1;';                        
        
        
        
        
        
        
        
        
        
        
        
        
        RETURN;
    END;

    DECLARE @ModuleName sysname = N'USP_IndexUsage';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#IndexUsage_DatabaseStatus]
    (
          [DatabaseName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode]         varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial]          bit            NOT NULL
        , [RowCount]           bigint         NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ErrorNumber]        int            NULL
        , [ErrorMessage]       nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail]             nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @FilterStatus<>'AVAILABLE' BEGIN SET @OverallStatus=@FilterStatus;SET @ErrorMessage=@FilterError;END;
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#IndexUsage_DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
    END;

    DECLARE @CatalogAllowed bit=1;
    IF @AnalyseModus='VOLL'
        SELECT @CatalogAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0)
        FROM [monitor].[VW_AnalyseAccessCurrent]
        WHERE [AnalysisClass]='CATALOG_DEEP';

    CREATE TABLE [#IndexUsage_Result]
    (
          [DatabaseName]           sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName]             sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName]             sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectId]               int            NOT NULL
        , [IndexId]                int            NOT NULL
        , [IndexName]              sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IndexTypeDesc]          nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsMemoryOptimized]      bit            NOT NULL
        , [IsSpatialIndex]         bit            NOT NULL
        , [IsPrimaryKey]           bit            NULL
        , [IsUniqueConstraint]     bit            NULL
        , [IsDisabled]             bit            NULL
        , [RowCount]               bigint         NULL
        , [UserSeeks]              bigint         NOT NULL
        , [UserScans]              bigint         NOT NULL
        , [UserLookups]            bigint         NOT NULL
        , [UserUpdates]            bigint         NOT NULL
        , [TotalUserReads]         bigint         NOT NULL
        , [ReadWriteRatio]         decimal(19,4)  NULL
        , [LastUserSeek]           datetime       NULL
        , [LastUserScan]           datetime       NULL
        , [LastUserLookup]         datetime       NULL
        , [LastUserUpdate]         datetime       NULL
        , [SystemSeeks]            bigint         NOT NULL
        , [SystemScans]            bigint         NOT NULL
        , [SystemLookups]          bigint         NOT NULL
        , [SystemUpdates]          bigint         NOT NULL
        , [DmvResetTimeServerLocal]  datetime2(3)   NULL
        , [UsageClassification]    varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#IndexUsage_XtpResult]
    (
          [DatabaseName]           sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName]             sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName]             sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectId]               int            NOT NULL
        , [IndexId]                int            NOT NULL
        , [IndexName]              sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IndexTypeDesc]          nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsPrimaryKey]           bit            NULL
        , [IsUniqueConstraint]     bit            NULL
        , [BucketCount]            bigint         NULL
        , [ScansStarted]           bigint         NOT NULL
        , [ScansRetries]           bigint         NOT NULL
        , [RowsReturned]           bigint         NOT NULL
        , [RowsTouched]            bigint         NOT NULL
        , [RowsReturnedPerScan]    decimal(28,4)  NULL
        , [RowsTouchedPerReturned] decimal(28,4)  NULL
        , [RetryPercent]           decimal(19,4)  NULL
        , [CounterScope]           nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [UsageClassification]    varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @OverallStatus='AVAILABLE' AND @MinUserUpdates < 0
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@MinUserUpdates darf nicht negativ sein.'; INSERT [#IndexUsage_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
    ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus NOT IN ('GEZIELT','VOLL')
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@AnalyseModus muss GEZIELT oder VOLL sein.'; INSERT [#IndexUsage_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
    ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#IndexUsage_NameFilters]) AND @SchemaNamePattern IS NULL AND @ObjectNamePattern IS NULL
    BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT erfordert eine exakte Namensliste, @FullObjectNames oder ein Schema-/Objekt-Pattern. Für den vollständigen Lauf @AnalyseModus=''VOLL'' verwenden.'; INSERT [#IndexUsage_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
    ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='VOLL' AND @CatalogAllowed=0
    BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'CATALOG_DEEP ist für die vollständige Index-Usage-Analyse nicht freigegeben.'; INSERT [#IndexUsage_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
    ELSE IF @OverallStatus='AVAILABLE'
    BEGIN
        DECLARE @DbId int,@DbName sysname,@Sql nvarchar(max),@Rows bigint;
        DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName] FROM [#IndexUsage_DatabaseCandidates];
        OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            BEGIN TRY
                SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
;WITH BaseRows AS
(
 SELECT [p].[object_id],[p].[index_id],SUM([p].[rows]) AS [RowCount]
 FROM sys.partitions AS [p] WITH (NOLOCK)
 GROUP BY [p].[object_id],[p].[index_id]
)
INSERT #IndexUsage_Result
SELECT TOP (@pMaxRows)
 @pDbName,[s].[name],[o].[name],[o].[object_id],[i].[index_id],[i].[name],[i].[type_desc],
 CONVERT(bit,COALESCE([t].[is_memory_optimized],0)),CONVERT(bit,CASE WHEN [i].[type]=4 THEN 1 ELSE 0 END),
 [i].[is_primary_key],[i].[is_unique_constraint],[i].[is_disabled],[br].[RowCount],
 COALESCE([u].[user_seeks],0),COALESCE([u].[user_scans],0),COALESCE([u].[user_lookups],0),COALESCE([u].[user_updates],0),
 COALESCE([u].[user_seeks],0)+COALESCE([u].[user_scans],0)+COALESCE([u].[user_lookups],0),
 CONVERT(decimal(19,4),(COALESCE([u].[user_seeks],0)+COALESCE([u].[user_scans],0)+COALESCE([u].[user_lookups],0))*1.0/NULLIF(COALESCE([u].[user_updates],0),0)),
 [u].[last_user_seek],[u].[last_user_scan],[u].[last_user_lookup],[u].[last_user_update],
 COALESCE([u].[system_seeks],0),COALESCE([u].[system_scans],0),COALESCE([u].[system_lookups],0),COALESCE([u].[system_updates],0),
 [osi].[sqlserver_start_time],
 CASE WHEN [i].[is_disabled]=1 THEN ''DISABLED''
      WHEN [i].[type]=4 THEN ''SPATIAL_NOT_IN_USAGE_DMV''
      WHEN [u].[index_id] IS NULL THEN ''NO_DMV_ROW''
      WHEN COALESCE([u].[user_seeks],0)+COALESCE([u].[user_scans],0)+COALESCE([u].[user_lookups],0)=0 AND COALESCE([u].[user_updates],0)>0 THEN ''WRITE_ONLY_SINCE_RESET''
      WHEN COALESCE([u].[user_seeks],0)+COALESCE([u].[user_scans],0)+COALESCE([u].[user_lookups],0)=0 THEN ''UNUSED_SINCE_RESET''
      WHEN COALESCE([u].[user_updates],0)=0 THEN ''READ_ONLY_SINCE_RESET'' ELSE ''READ_AND_WRITE'' END
FROM sys.objects AS [o] WITH (NOLOCK)
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
LEFT JOIN sys.tables AS [t] WITH (NOLOCK) ON [t].[object_id]=[o].[object_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[o].[object_id]
LEFT JOIN BaseRows AS [br] ON [br].[object_id]=[i].[object_id] AND [br].[index_id]=[i].[index_id]
LEFT JOIN sys.dm_db_index_usage_stats AS [u] WITH (NOLOCK) ON [u].[database_id]=@pDbId AND [u].[object_id]=[i].[object_id] AND [u].[index_id]=[i].[index_id]
CROSS JOIN sys.dm_os_sys_info AS [osi] WITH (NOLOCK)
WHERE [o].[type] IN (''U'',''V'') AND [o].[is_ms_shipped]=0 AND [i].[index_id]>0 AND [i].[is_hypothetical]=0
  AND COALESCE([t].[is_memory_optimized],0)=0
'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
  AND (@pIncludeConstraints=1 OR ([i].[is_primary_key]=0 AND [i].[is_unique_constraint]=0))
  AND COALESCE([u].[user_updates],0)>=@pMinUpdates
  AND (@pOnlyUnused=0 OR COALESCE([u].[user_seeks],0)+COALESCE([u].[user_scans],0)+COALESCE([u].[user_lookups],0)=0)
ORDER BY COALESCE([u].[user_updates],0) DESC,[br].[RowCount] DESC
OPTION (MAXDOP 1, RECOMPILE);';
                EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pDbId int,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pIncludeConstraints bit,@pMinUpdates bigint,@pOnlyUnused bit',@pDbName=@DbName,@pDbId=@DbId,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pIncludeConstraints=@PrimaryUndUniqueEinbeziehen,@pMinUpdates=@MinUserUpdates,@pOnlyUnused=@NurUngenutzt;
                SELECT @Rows=COUNT_BIG(*) FROM [#IndexUsage_Result] WHERE [DatabaseName]=@DbName; INSERT [#IndexUsage_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END,NULL,NULL,N'Kumulative Werte; Resetzeit näherungsweise SQL-Server-Start.');
            END TRY
            BEGIN CATCH
                INSERT [#IndexUsage_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,1,0,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END,ERROR_NUMBER(),ERROR_MESSAGE(),N'DMV-/Katalogfehler isoliert.');
            END CATCH;

            IF @MitMemoryOptimized = 1
            BEGIN
                BEGIN TRY
                    SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #IndexUsage_XtpResult
SELECT TOP (@pMaxRows)
       @pDbName,[s].[name],[o].[name],[o].[object_id],[i].[index_id],[i].[name],[i].[type_desc],
       [i].[is_primary_key],[i].[is_unique_constraint],[hi].[bucket_count],
       [xs].[scans_started],[xs].[scans_retries],[xs].[rows_returned],[xs].[rows_touched],
       CONVERT(decimal(28,4),[xs].[rows_returned]*1.0/NULLIF([xs].[scans_started],0)),
       CONVERT(decimal(28,4),[xs].[rows_touched]*1.0/NULLIF([xs].[rows_returned],0)),
       CONVERT(decimal(19,4),[xs].[scans_retries]*100.0/NULLIF([xs].[scans_started],0)),
       N''Seit Datenbankneustart beziehungsweise seit Erzeugung der Tabelle; nicht persistent.'',
       CASE WHEN [xs].[scans_started]=0 THEN ''NO_SCANS_SINCE_DB_RESTART''
            WHEN [xs].[scans_retries]>0 THEN ''SCAN_RETRIES_OCCURRED''
            WHEN [xs].[rows_touched]>[xs].[rows_returned]*10 AND [xs].[rows_returned]>0 THEN ''HIGH_ROWS_TOUCHED_RATIO''
            ELSE ''ACTIVE'' END
FROM sys.dm_db_xtp_index_stats AS [xs] WITH (NOLOCK)
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=CONVERT(int,[xs].[object_id])
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
JOIN sys.tables AS [tb] WITH (NOLOCK) ON [tb].[object_id]=[o].[object_id] AND [tb].[is_memory_optimized]=1
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[o].[object_id] AND [i].[index_id]=CONVERT(int,[xs].[index_id])
LEFT JOIN sys.hash_indexes AS [hi] WITH (NOLOCK) ON [hi].[object_id]=[i].[object_id] AND [hi].[index_id]=[i].[index_id]
WHERE 1=1'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
  AND (@pIncludeConstraints=1 OR ([i].[is_primary_key]=0 AND [i].[is_unique_constraint]=0))
  AND (@pOnlyUnused=0 OR [xs].[scans_started]=0)
ORDER BY [xs].[scans_started] DESC,[xs].[rows_touched] DESC
OPTION (MAXDOP 1,RECOMPILE);';
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pIncludeConstraints bit,@pOnlyUnused bit',
                         @pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,
                         @pIncludeConstraints=@PrimaryUndUniqueEinbeziehen,@pOnlyUnused=@NurUngenutzt;
                    SELECT @Rows=COUNT_BIG(*) FROM [#IndexUsage_XtpResult] WHERE [DatabaseName]=@DbName;
                    INSERT [#IndexUsage_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,
                         CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE' ELSE N'VIEW DATABASE STATE' END,
                         NULL,NULL,N'Quelle XTP_INDEX_USAGE erfolgreich gelesen.');
                END TRY
                BEGIN CATCH
                    INSERT [#IndexUsage_DatabaseStatus] VALUES(@DbName,
                         CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208,4121) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                         1,0,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE' ELSE N'VIEW DATABASE STATE' END,
                         ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle XTP_INDEX_USAGE fehlgeschlagen; Rowstore-Ergebnis bleibt erhalten.');
                END CATCH;
            END;

            FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        END; CLOSE dbcur; DEALLOCATE dbcur;
        IF NOT EXISTS(SELECT 1 FROM [#IndexUsage_DatabaseStatus]) INSERT [#IndexUsage_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
    END;



    SELECT @TotalRows=(SELECT COUNT_BIG(*) FROM [#IndexUsage_Result])+(SELECT COUNT_BIG(*) FROM [#IndexUsage_XtpResult]);

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#IndexUsage_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#IndexUsage_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#IndexUsage_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
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
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#IndexUsage_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#IndexUsage_Result] ORDER BY [UserUpdates] DESC,[TotalUserReads] ASC,[DatabaseName],[SchemaName],[ObjectName],[IndexId]; ELSE SELECT N'Indexnutzung' [Ergebnis],[r].* FROM [#IndexUsage_Result] [r] ORDER BY [UserUpdates] DESC,[TotalUserReads] ASC,[DatabaseName],[SchemaName],[ObjectName],[IndexId];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#IndexUsage_XtpResult] ORDER BY [ScansStarted] DESC,[RowsTouched] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId]; ELSE SELECT N'Indexnutzung' [Ergebnis],[r].* FROM [#IndexUsage_XtpResult] [r] ORDER BY [ScansStarted] DESC,[RowsTouched] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId];
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#IndexUsage_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#IndexUsage_Result] ORDER BY [UserUpdates] DESC,[TotalUserReads] ASC,[DatabaseName],[SchemaName],[ObjectName],[IndexId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData2 nvarchar(max)=(SELECT * FROM [#IndexUsage_XtpResult] ORDER BY [ScansStarted] DESC,[RowsTouched] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"rowstoreIndexes":',COALESCE(@JsonData1,N'[]'),N',"memoryOptimizedIndexes":',COALESCE(@JsonData2,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#IndexUsage_Result'
            , @ResultLabel=N'IndexUsage'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#IndexUsage_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
