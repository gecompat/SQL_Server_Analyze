USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_Columnstore
Version      : 1.2.0
Stand        : 2026-10-14
Typ          : Stored Procedure
Zweck        : Analysiert Columnstore-Indizes, Rowgroups und Deleted Rows; Physical Stats, Segmente und Dictionaries sind explizite gruppengeschützte Vertiefungen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.column_store_row_groups, sys.index_columns (geordnete Metadaten), optional sys.dm_db_column_store_row_group_physical_stats, sys.column_store_segments, sys.column_store_dictionaries sowie Systemkataloge.
Parameter    : Die vollständige Eingabeschnittstelle ist in der Procedure-Signatur aufgeführt. Sie umfasst Datenbank-, Schema-, Objekt- und Vollobjektfilter, GEZIELT/VOLL, optionale Physical-Stats-, Segment- und Dictionarypfade, Deleted-Row-Filter, ResultSetArt/TABLE-Mapping, JSON- und Meldungsschalter sowie Segmentüberlappung. @MaxZeilen begrenzt je Datenbank die jeweilige Ergebnismenge; @MaxSegmenteAnalyse begrenzt separat die Segmentaufnahme mit N+1-Sentinel. @Json ist OUTPUT und wird nur bei @JsonErzeugen=1 mit JSON befüllt.
Resultsets   : RAW gibt Status und getrennte Fachmengen aus; CONSOLE Statusmengen und eine menschenlesbare Fachansicht; TABLE schreibt benannte Mengen; NONE unterdrückt reguläre Resultsets. JSON enthält meta, rowgroups, ordering, physicalStats, segments, dictionaries und databaseStatus; bei Segmentüberlappung Schema 2 mit zusätzlichem segmentOverlap.
Berechtigung : Basis gemäß Metadata Visibility/VIEW DEFINITION; Physical Stats SQL 2019 VIEW DATABASE STATE plus CONTROL, SQL 2022+ VIEW DATABASE PERFORMANCE STATE; Detailwerte können SELECT erfordern. Datenbankauswahl prüft COLUMNSTORE_CURRENT. Physical-/Segment-/Dictionaryoptionen und Segmentüberlappung prüfen COLUMNSTORE_DEEP; VOLL prüft zusätzlich CATALOG_DEEP. Aktuelle Freigabe und ein ggf. erforderliches High-Impact-Gate werden separat geprüft.
Eigenlast    : Der Basispfad ist moderat. Optionale Detailmengen können umfangreich sein; Segmentzeilen wachsen ungefähr mit Rowgroups × Spalten. @MaxZeilen begrenzt Ergebnismengen und Materialisierung, nicht zuverlässig vorgelagerte Quellermittlung. Segmentüberlappung übernimmt höchstens @MaxSegmenteAnalyse + 1 Segmentzeilen in die Zwischenmenge; beim Sentinel entfällt die Paarberechnung.
Locking      : READUNCOMMITTED-Kataloge, LOCK_TIMEOUT; keine Wartungs-DDL.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Columnstore @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_Columnstore @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%', @MinDeletedPercent=10, @NurProblematisch=1;
  EXEC monitor.USP_Columnstore @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @MitPhysicalStats=1, @MitSegmenten=1;
  EXEC monitor.USP_Columnstore @Hilfe=1;
Änderungen   : 1.2.0 - Freigegebene begrenzte opt-in Segmentüberlappung mit getrennten Paar- und Berührungszahlen.
               1.1.0 - Additive, versionsadaptive geordnete Columnstore-Metadaten.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_Columnstore]
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
    , @MitPhysicalStats               bit           = 0
    , @MitSegmenten                   bit           = 0
    , @MitDictionaries                bit           = 0
    , @MinDeletedPercent              decimal(9,2)  = 0
    , @NurProblematisch               bit           = 0
    , @MaxZeilen                      int           = 10000
    , @LockTimeoutMs                  int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit           = 1
    , @Hilfe                          bit           = 0
    , @MitSegmentUeberlappung          bit           = 0
    , @MaxSegmenteAnalyse             int           = 2000
AS
BEGIN
 SET NOCOUNT ON;

    SET @Json = NULL;
    SET @MitSegmentUeberlappung=COALESCE(@MitSegmentUeberlappung,0);
    DECLARE @OverlapRows bigint=0,@OverlapSentinel int=NULL,@OverlapTableTarget sysname=NULL;
    DECLARE @AllowedColumnstoreResults nvarchar(max)=CASE WHEN @MitSegmentUeberlappung=1 THEN N'rowgroups|ordering|segmentOverlap' ELSE N'rowgroups|ordering' END;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL,@OrderingTableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
    BEGIN
        CREATE TABLE [#Columnstore_ResultTableMap]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE);
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=@AllowedColumnstoreResults,@MappingTable=N'#Columnstore_ResultTableMap',@ThrowOnError=1;
        SELECT @TableTarget=[TargetTable] FROM [#Columnstore_ResultTableMap] WHERE [ResultName]=N'rowgroups';
        SELECT @OrderingTableTarget=[TargetTable] FROM [#Columnstore_ResultTableMap] WHERE [ResultName]=N'ordering';
        SELECT @OverlapTableTarget=[TargetTable] FROM [#Columnstore_ResultTableMap] WHERE [ResultName]=N'segmentOverlap';
    END;
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
    CREATE TABLE [#Columnstore_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#Columnstore_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=NULL,@StatisticsNames=NULL,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#Columnstore_NameFilters';
    IF @FilterStatus='AVAILABLE' AND COALESCE(@Hilfe,0)=0 AND @MitSegmentUeberlappung=1
    BEGIN
        IF @MaxSegmenteAnalyse IS NULL OR @MaxSegmenteAnalyse NOT BETWEEN 1 AND 10000
           OR UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,''))))<>'GEZIELT'
           OR @DatabaseNames IS NULL OR @DatabaseListCount<>1 OR @DatabaseNamePattern IS NOT NULL
           OR @SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL OR @SchemaNamePattern IS NOT NULL OR @ObjectNamePattern IS NOT NULL
           OR (SELECT COUNT_BIG(*) FROM [#Columnstore_NameFilters] WHERE [FilterType]='FULL_OBJECT')<>1
           OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]='FULL_OBJECT' AND ([SchemaName] IS NULL OR [DatabaseName] IS NOT NULL))
        BEGIN SET @FilterStatus='INVALID_PARAMETER'; SET @FilterError=N'Segmentüberlappung benötigt GEZIELT, genau eine exakte Datenbank, ein zweigliedriges FullObjectNames-Objekt und MaxSegmenteAnalyse von 1 bis 10000.'; END;
        ELSE SET @OverlapSentinel=@MaxSegmenteAnalyse+1;
    END;
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='COLUMNSTORE_CURRENT',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#Columnstore_DatabaseCandidates';
    IF @FilterStatus='AVAILABLE' AND (@MitPhysicalStats=1 OR @MitSegmenten=1 OR @MitDictionaries=1 OR @MitSegmentUeberlappung=1)
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='COLUMNSTORE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    IF @FilterStatus='AVAILABLE' AND UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,''))))='VOLL'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='CATALOG_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#Columnstore_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048); SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
 IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_Columnstore';
        PRINT N'Analysiert sichtbare Columnstore-Rowgroups und geordnete Indexmetadaten; Physical Stats, Segmente, Dictionaries und Segmentüberlappung sind optionale Vertiefungen.';
        PRINT N'Segmentüberlappung ist ein gezielter Snapshot für genau eine Datenbank und ein Objekt. Bei Überschreitung entfällt ihre gesamte Paarberechnung; sie ersetzt keine Workload- oder Qualitätsbewertung.';
        PRINT N'Der HELP-Zweig liegt nach frühen Filter-, TABLE-Mapping-, Kandidaten- und Gate-Prüfungen.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste solcher Namen. | trennt außerhalb von [...]; ]] maskiert ]. Elemente werden außen getrimmt; case-sensitive Duplikate und ungültige/leere Elemente sind INVALID_PARAMETER. NULL, N'''' und nur Leerzeichen bedeuten keine exakte Einschränkung und wählen alle zulässigen sichtbaren ONLINE-Datenbanken. Nichtleere Liste und nicht-NULL @DatabaseNamePattern sind gegenseitig exklusiv. PARSENAME-Prüfung: Teil 1 vorhanden, Teil 2 NULL, LEN höchstens 128; keine vollständige SQL-Namensgrammatik. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in der Auswahl zu. NULL wird vom Datenbankhelfer als INVALID_PARAMETER abgewiesen. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 zu 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern; NULL kein Filter, leer/Whitespace oder leeres Präfix-Ergebnis ungültig. Außen trimmen; Präfixe like:, regex:, regexi: werden ohne Beachtung der Großschreibung erkannt; Rest nicht nochmals trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] sind case-sensitiv. regex: übergibt c, regexi: i; Syntax wird nicht vorgeprüft. Der Datenbankpattern-Helfer prüft Regexverfügbarkeit im Installationsdatenbankkontext (SQL Server 2025 und Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Feldregex für Schema/Objekt hat diese Vorprüfung nicht. Mit wirksamer Datenbankliste exklusiv.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 (Default) bestätigt kein Gate; 1 bestätigt nur die Anforderung eines tatsächlich aktivierten Analysepfads. NULL ungültig. Datenbankauswahl prüft COLUMNSTORE_CURRENT; Physical-/Segment-/Dictionaryoptionen sowie Segmentüberlappung zusätzlich COLUMNSTORE_DEEP; VOLL prüft CATALOG_DEEP. Ob ein aktivierter Pfad eine Gruppengate-Bestätigung verlangt, bestimmt dessen Policy. Bestätigung ersetzt weder Freigabe noch Scopegrenzen. Bit-Bindung mappt konvertierbare numerische Nichtnullwerte auf 1.';
        PRINT N'@SchemaNames nvarchar(max); Default: NULL. Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitiv verglichen. NULL bedeutet kein Filter; nicht-NULL leere/Whitespace-Liste, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind ungültig. LEN höchstens 128. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren.';
        PRINT N'@SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Pattern; NULL kein Filter, Leerwert/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Restinhalt nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: Flag c, regexi: Flag i. Regex wird in der jeweiligen Zieldatenbank ausgeführt, ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitiv. NULL bedeutet kein Filter; nicht-NULL leer/Whitespace, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. LEN höchstens 128. Mit nicht-NULL @ObjectNamePattern oder @FullObjectNames exklusiv.';
        PRINT N'@ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektpattern; NULL deaktiviert, leeres/Whitespace-Muster oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann je Datenbank als ERROR_HANDLED erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren.';
        PRINT N'@FullObjectNames nvarchar(max); Default: NULL. Optionale bracket-aware Pipe-Liste ein-, zwei- oder dreiteiliger Bezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. | trennt außerhalb von [...], ]] maskiert ]; PARSENAME/sysname-Grenzen, Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Datenbankteil verlangt Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Vergleiche case-sensitive; nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv.';
        PRINT N'@AnalyseModus varchar(16); Default: ''GEZIELT''. GEZIELT oder VOLL; bei deaktivierter Segmentüberlappung wird NULL zu GEZIELT normalisiert, Außenleerzeichen werden entfernt und die Großschreibung vereinheitlicht. Andere Werte einschließlich leerer Eingabe führen zu INVALID_PARAMETER. Bei @MitSegmentUeberlappung=1 prüft die normale Vorbedingung vor dieser Normalisierung auf ausdrücklich übergebenes GEZIELT; NULL wird in diesem Pfad als INVALID_PARAMETER abgewiesen. VOLL prüft CATALOG_DEEP samt aktueller Aktivierung/Freigabe und ggf. High-Impact-Gate.';
        PRINT N'@MitPhysicalStats bit; Default: 0. Opt-in: 0 lässt zusätzliche Physical-Rowgroup-Stats aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht ausdrücklich abgewiesen und aktiviert den =1-Zweig nicht. Detailwerte und Berechtigungen hängen von Quelle und Version ab.';
        PRINT N'@MitSegmenten bit; Default: 0. Opt-in: 0 lässt Segmentmetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens validiert und aktiviert den =1-Zweig nicht. Die Segmentzahl wächst ungefähr mit Rowgroups × Spalten; TOP begrenzt die je Datenbank materialisierten Zeilen, nicht zuverlässig die vorgelagerte Rowgroupermittlung.';
        PRINT N'@MitDictionaries bit; Default: 0. Opt-in: 0 lässt Dictionarymetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens abgewiesen und aktiviert den =1-Zweig nicht. Ergebnisverfügbarkeit und erforderliche Rechte hängen vom Quellpfad ab.';
        PRINT N'@MinDeletedPercent decimal(9,2); Default: 0. Rowgroup-Schwelle in Prozentpunkten, einschließlich 0 bis 100; außerhalb INVALID_PARAMETER. NULL passiert den <0/>100-Test aufgrund SQL-Dreiwertlogik, macht aber den nachfolgenden >=-Vergleich UNKNOWN, sodass keine Zeile den Vergleich erfüllt. Kein Rebuildurteil.';
        PRINT N'@NurProblematisch bit; Default: 0. 0 lässt die Rowgroup-Auswahl ungefiltert; 1 filtert auf Zustand ungleich COMPRESSED oder vorhandene gelöschte Zeilen. NULL wird nicht separat validiert, sondern an SQL-Prädikate weitergereicht; deren Dreiwertlogik gilt.';
        PRINT N'@MaxZeilen int; Default: 10000. Positive int begrenzt TOP je relevanter Ergebnismenge und Ziel-Datenbank; 0 oder NULL bedeutet unbegrenzt; negative Werte INVALID_PARAMETER. Die Grenze begrenzt nicht zuverlässig vorgelagerte Katalog-/DMV-Arbeit. Segmentüberlappung hat die separate Grenze @MaxSegmenteAnalyse.';
        PRINT N'@LockTimeoutMs int; Default: 0. Lockwartezeit in Millisekunden von 0 bis 60000; außerhalb INVALID_PARAMETER. 0 bedeutet NOWAIT. Der Parameter wird in dynamischen Datenbankzugriffs-Batches als SET LOCK_TIMEOUT gesetzt; der Modulablauf setzt außerhalb dieser Batches außerdem stellenweise LOCK_TIMEOUT 0. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach TRIM/UPPER einer der endlichen Werte CONSOLE, RAW, TABLE, NONE; NULL/leer wird ungültig. CONSOLE zeigt Statuskontext und menschenlesbare Fachansicht; RAW gibt getrennte Status- und Fachmengen; TABLE schreibt nur gemappte Mengen; NONE unterdrückt reguläre Resultsets. JSON ist unabhängig über @JsonErzeugen steuerbar. TABLE-Mapping wird vor dem Hilfezweig vorgeprüft.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur mit TABLE: JSON-Objekt Resultsetname zu lokaler #Temp-Zieltabelle. Für TABLE ist NULL/leeres oder ungültiges Objekt ungültig; außerhalb TABLE führt nichtleerer Inhalt zu THROW 51011. Erlaubte exakte Namen: rowgroups, ordering; segmentOverlap zusätzlich nur bei aktivierter Segmentüberlappung. Ziele müssen eindeutig, lokal, leer und mit genau einer Seed-Spalte angelegt sein; der Helper prüft und wirft bei Fehler.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 unterdrückt JSON; 1 erzeugt es in @Json. NULL wird nicht eigens als ungültig geprüft und führt nicht in den IF-Zweig. JSON-Schema 1 ohne Segmentüberlappung, Schema 2 mit ihr; Schlüssel meta, rowgroups, ordering, physicalStats, segments, dictionaries, databaseStatus und beim Opt-in segmentOverlap.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler nvarchar(max)-OUTPUT-Empfänger; zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 enthält er das erzeugte JSON, sonst NULL. Zum Empfangen Variable passenden Typs mit OUTPUT binden; ohne OUTPUT wird die Zuweisung nicht zurückgegeben. Im Hilfezweig ist die Variable NULL.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die ergänzende Severity-10-Warnmeldung; 1 (Default) gibt sie bei Status ungleich AVAILABLE aus. NULL wird nicht separat validiert und die Meldungsbedingung greift nicht. Keine zusätzliche Fachmenge.';
        PRINT N'@Hilfe bit; Default: 0. 0 normaler Ablauf; 1 druckt Hilfe und beendet vor der Analyse. Der Return liegt nach Filter-, TABLE-Mapping-, Kandidaten- und Gateprüfungen, diese können also vorher stattfinden. NULL wird nicht als 1 behandelt.';
        PRINT N'@MitSegmentUeberlappung bit; Default: 0. 0 (auch NULL, durch COALESCE zu 0 normalisiert) lässt segmentOverlap aus; 1 fordert die Diagnose und COLUMNSTORE_DEEP-Prüfung. Normaler Aufruf verlangt außerdem GEZIELT, genau eine explizite Datenbank, genau ein zweigliedriges FullObjectNames-Objekt, keine konkurrierenden Schema-/Objektfilter und @MaxSegmenteAnalyse 1..10000; sonst INVALID_PARAMETER. Opt-in ergänzt RAW/TABLE/JSON/CONSOLE; JSON wechselt zu Schema 2.';
        PRINT N'@MaxSegmenteAnalyse int; Default: 2000. Nur im aktivierten Segmentüberlappungspfad gültige Grenze 1..10000 einschließlich; NULL/außerhalb ungültig. Höchstens N+1 Segmentzeilen als Sentinel werden materialisiert; bei Überschreitung entfällt die gesamte Paarberechnung. Kein globales TOP-/Zeitlimit; bei ausgeschaltetem Pfad ungeprüft.';
        PRINT N'EXEC [monitor].[USP_Columnstore] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @Columnstore_JsonExample nvarchar(max); EXEC [monitor].[USP_Columnstore] @DatabaseNames=N''[ExampleDatabase]'', @FullObjectNames=N''[ExampleSchema].[ExampleTable]'', @JsonErzeugen=1, @Json=@Columnstore_JsonExample OUTPUT; SELECT @Columnstore_JsonExample AS [JsonDocument];';
        PRINT N'EXEC [monitor].[USP_Columnstore] @Hilfe=1;';












        RETURN;
 END;

    DECLARE @ModuleName sysname = N'USP_Columnstore';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#Columnstore_DatabaseStatus]
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
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#Columnstore_DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
    END;

 DECLARE @CatalogAllowed bit=1;
 IF @AnalyseModus='VOLL' SELECT @CatalogAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='CATALOG_DEEP';
 DECLARE @ColumnstoreDeepAllowed bit=1;
 IF @MitPhysicalStats=1 OR @MitSegmenten=1 OR @MitDictionaries=1 OR @MitSegmentUeberlappung=1 SELECT @ColumnstoreDeepAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='COLUMNSTORE_DEEP';
 CREATE TABLE [#Columnstore_Result]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [PartitionNumber] int NOT NULL,[RowGroupId] int NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TotalRows] bigint NULL,[DeletedRows] bigint NULL,[ActiveRows] bigint NULL,
  [DeletedPercent] decimal(9,4) NULL,[FullnessPercent] decimal(9,4) NULL,[SizeMb] decimal(19,2) NULL,[DeltaStoreHobtId] bigint NULL,
  [TrimReasonDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TransitionToCompressedStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HasVertipaqOptimization] bit NULL,[Generation] bigint NULL,[CreatedTime] datetime2 NULL,[ClosedTime] datetime2 NULL,
  [Assessment] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#Columnstore_Physical]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [PartitionNumber] int NOT NULL,[RowGroupId] int NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TotalRows] bigint NULL,[DeletedRows] bigint NULL,[ActiveRows] bigint NULL,
  [DeletedPercent] decimal(9,4) NULL,[SizeMb] decimal(19,2) NULL,[DeltaStoreHobtId] bigint NULL,[TrimReasonDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [TransitionToCompressedStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HasVertipaqOptimization] bit NULL,[Generation] bigint NULL,[CreatedTime] datetime2 NULL,[ClosedTime] datetime2 NULL,[Assessment] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#Columnstore_Segments]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IndexId] int NOT NULL,[PartitionNumber] int NOT NULL,[ColumnId] int NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [RowGroupId] int NOT NULL,[EncodingType] int NULL,[EncodingTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RowCount] int NULL,[HasNulls] int NULL,[PrimaryDictionaryId] int NULL,[SecondaryDictionaryId] int NULL,[OnDiskSizeMb] decimal(19,4) NULL
 );
 CREATE TABLE [#Columnstore_Dictionaries]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IndexId] int NOT NULL,[PartitionNumber] int NOT NULL,[ColumnId] int NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [DictionaryId] int NOT NULL,[DictionaryType] int NULL,[DictionaryTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EntryCount] bigint NULL,[OnDiskSizeMb] decimal(19,4) NULL
 );
 CREATE TABLE [#Columnstore_Ordering]
 (
  [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectId] int NULL,[IndexId] int NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnId] int NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnStoreOrderOrdinal] tinyint NULL,[DataClusteringOrdinal] tinyint NULL,[SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CollectionTimeUtc] datetime2(3) NOT NULL
 );
 IF @MitSegmentUeberlappung=1
 BEGIN
  BEGIN TRY
   SET LOCK_TIMEOUT 100;
   CREATE TABLE [#Columnstore_OverlapSource]
   (
    [ObjectId] int NULL,[IndexId] int NULL,[PartitionNumber] int NULL,[PartitionId] bigint NULL,[HobtId] bigint NULL,[ExpectedPartitionId] bigint NULL,[ExpectedHobtId] bigint NULL,[ColumnId] int NULL,[SegmentId] int NULL,
    [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SystemTypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxLength] smallint NULL,
    [EncodingType] int NULL,[NativeRowCount] int NULL,[CollationId] int NULL,[MinNumber] bigint NULL,[MaxNumber] bigint NULL,[MinBinary] varbinary(18) NULL,[MaxBinary] varbinary(18) NULL,[RangeClass] tinyint NULL
   );
   SET LOCK_TIMEOUT 0;
   SET LOCK_TIMEOUT 100;
   CREATE TABLE [#Columnstore_OverlapRanks]
   (
    [ObjectId] int NOT NULL,[IndexId] int NOT NULL,[PartitionNumber] int NOT NULL,[ColumnId] int NOT NULL,[RangeClass] tinyint NOT NULL,
    [NumberBoundary] bigint NULL,[BinaryBoundary] varbinary(18) NULL,[Starts] bigint NOT NULL,[Ends] bigint NOT NULL,[Points] bigint NOT NULL,[StartLess] bigint NOT NULL,[EndLessEqual] bigint NOT NULL,
    INDEX [IX_Columnstore_OverlapRanks_Number] NONCLUSTERED ([ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass],[NumberBoundary]),
    INDEX [IX_Columnstore_OverlapRanks_Binary] NONCLUSTERED ([ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass],[BinaryBoundary])
   );
   SET LOCK_TIMEOUT 0;
   SET LOCK_TIMEOUT 100;
   CREATE TABLE [#Columnstore_SegmentOverlap]
   (
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PartitionNumber] int NOT NULL,[ColumnId] int NOT NULL,
    [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SystemTypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ObservedSegmentCount] bigint NOT NULL,[ComparableSegmentCount] bigint NOT NULL,[UncomparableSegmentCount] bigint NOT NULL,[StrictOverlapPairCount] bigint NULL,[BoundaryTouchPairCount] bigint NULL,
    [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ReasonCode] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CollectionTimeUtc] datetime2(3) NOT NULL
   );
   SET LOCK_TIMEOUT 0;
  END TRY
  BEGIN CATCH
   SET LOCK_TIMEOUT 0;
   THROW;
  END CATCH;
 END;

 IF @OverallStatus='AVAILABLE' AND (@MinDeletedPercent<0 OR @MinDeletedPercent>100)
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@MinDeletedPercent muss zwischen 0 und 100 liegen.'; INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus NOT IN ('GEZIELT','VOLL')
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'@AnalyseModus muss GEZIELT oder VOLL sein.'; INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#Columnstore_NameFilters]) AND @SchemaNamePattern IS NULL AND @ObjectNamePattern IS NULL
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT erfordert eine exakte Namensliste, @FullObjectNames oder ein Schema-/Objekt-Pattern. Für den vollständigen Lauf @AnalyseModus=''VOLL'' verwenden.'; INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='VOLL' AND @CatalogAllowed=0
 BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'CATALOG_DEEP ist für die vollständige Columnstore-Basisanalyse nicht freigegeben.'; INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND (@MitPhysicalStats=1 OR @MitSegmenten=1 OR @MitDictionaries=1 OR @MitSegmentUeberlappung=1) AND @ColumnstoreDeepAllowed=0
 BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'COLUMNSTORE_DEEP ist für die angeforderte Vertiefung nicht freigegeben.'; INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE'
 BEGIN
  DECLARE @DbId int,@DbName sysname,@Sql nvarchar(max),@Rows bigint;
  DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR
   SELECT [DatabaseId],[DatabaseName]
   FROM [#Columnstore_DatabaseCandidates];
  OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  WHILE @@FETCH_STATUS=0
  BEGIN
   BEGIN TRY
    SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Columnstore_Result
SELECT TOP (@pMaxRows) @pDbName,[s].[name],[o].[name],[o].[object_id],[i].[index_id],[i].[name],[i].[type_desc],[rg].[partition_number],[rg].[row_group_id],[rg].[state_description],
 [rg].[total_rows],[rg].[deleted_rows],[rg].[total_rows]-COALESCE([rg].[deleted_rows],0),CONVERT(decimal(9,4),[rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0)),
 CONVERT(decimal(9,4),([rg].[total_rows]-COALESCE([rg].[deleted_rows],0))*100.0/1048576.0),CONVERT(decimal(19,2),[rg].[size_in_bytes]/1048576.0),[rg].[delta_store_hobt_id],
 NULL,NULL,NULL,NULL,NULL,NULL,
 CASE WHEN [rg].[state_description]=''TOMBSTONE'' THEN ''TOMBSTONE'' WHEN [rg].[state_description]=''CLOSED'' THEN ''CLOSED_WAITING_FOR_TUPLE_MOVER'' WHEN [rg].[state_description]=''OPEN'' THEN ''OPEN_DELTA_STORE''
      WHEN [rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0)>=20 THEN ''HIGH_DELETED_ROWS'' WHEN [rg].[total_rows]<102400 AND [rg].[state_description]=''COMPRESSED'' THEN ''SMALL_COMPRESSED_ROWGROUP'' ELSE ''NORMAL'' END
FROM sys.column_store_row_groups AS [rg] WITH (NOLOCK)
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[rg].[object_id]
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[rg].[object_id] AND [i].[index_id]=[rg].[index_id]
WHERE 1=1'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
 AND COALESCE([rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0),0)>=@pMinDeleted
 AND (@pOnlyProblems=0 OR [rg].[state_description]<>''COMPRESSED'' OR COALESCE([rg].[deleted_rows],0)>0)
ORDER BY COALESCE([rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0),0) DESC,[rg].[total_rows] ASC
OPTION (MAXDOP 1,RECOMPILE);';
    EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pMinDeleted decimal(9,2),@pOnlyProblems bit',
      @pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pMinDeleted=@MinDeletedPercent,@pOnlyProblems=@NurProblematisch;
    SELECT @Rows=COUNT_BIG(*) FROM [#Columnstore_Result] WHERE [DatabaseName]=@DbName;
    INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,N'VIEW DEFINITION / Metadata Visibility',NULL,NULL,N'Quelle COLUMNSTORE_CATALOG erfolgreich gelesen.');
   END TRY
   BEGIN CATCH
    INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,N'VIEW DEFINITION / Metadata Visibility',ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle COLUMNSTORE_CATALOG fehlgeschlagen; optionale Teilquellen werden dennoch versucht.');
   END CATCH;

   IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<16
       INSERT [#Columnstore_Ordering]
       VALUES(@DbName,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'UNAVAILABLE_VERSION',NULL,N'Geordnete Columnstore-Metadaten sind ab SQL Server 2022 verfügbar.',@CollectionTimeUtc);
   ELSE
   BEGIN TRY
     SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT #Columnstore_Ordering
SELECT TOP (@pMaxRows) @pDbName,[s].[name],[o].[name],[o].[object_id],[i].[index_id],[i].[name],[i].[type_desc],[c].[column_id],[c].[name],[ic].[column_store_order_ordinal],'+
CASE WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17 THEN N'[ic].[data_clustering_ordinal]' ELSE N'CONVERT(tinyint,NULL)' END+N',
 ''AVAILABLE'',NULL,NULL,@pCollectionTimeUtc
FROM sys.index_columns AS [ic] WITH (NOLOCK)
JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[ic].[object_id] AND [c].[column_id]=[ic].[column_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[ic].[object_id] AND [i].[index_id]=[ic].[index_id]
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[i].[object_id]
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
WHERE [i].[type] IN (5,6) AND [ic].[column_store_order_ordinal]>0'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
ORDER BY [s].[name],[o].[name],[i].[index_id],[ic].[column_store_order_ordinal]
OPTION (MAXDOP 1,RECOMPILE);';
     EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pCollectionTimeUtc datetime2(3)',@pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pCollectionTimeUtc=@CollectionTimeUtc;
   END TRY
   BEGIN CATCH
       INSERT [#Columnstore_Ordering]
       VALUES(@DbName,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE(),@CollectionTimeUtc);
   END CATCH;

   IF @MitPhysicalStats=1
   BEGIN
    BEGIN TRY
     SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Columnstore_Physical
SELECT TOP (@pMaxRows) @pDbName,[s].[name],[o].[name],[o].[object_id],[i].[index_id],[i].[name],[i].[type_desc],[rg].[partition_number],[rg].[row_group_id],[rg].[state_desc],
 [rg].[total_rows],[rg].[deleted_rows],[rg].[total_rows]-COALESCE([rg].[deleted_rows],0),CONVERT(decimal(9,4),[rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0)),
 CONVERT(decimal(19,2),[rg].[size_in_bytes]/1048576.0),[rg].[delta_store_hobt_id],[rg].[trim_reason_desc],[rg].[transition_to_compressed_state_desc],
 [rg].[has_vertipaq_optimization],[rg].[generation],[rg].[created_time],[rg].[closed_time],
 CASE WHEN [rg].[state_desc]=''TOMBSTONE'' THEN ''TOMBSTONE'' WHEN [rg].[state_desc]=''CLOSED'' THEN ''CLOSED_WAITING_FOR_TUPLE_MOVER'' WHEN [rg].[state_desc]=''OPEN'' THEN ''OPEN_DELTA_STORE''
      WHEN [rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0)>=20 THEN ''HIGH_DELETED_ROWS'' WHEN [rg].[total_rows]<102400 AND [rg].[state_desc]=''COMPRESSED'' THEN ''SMALL_COMPRESSED_ROWGROUP'' ELSE ''NORMAL'' END
FROM sys.dm_db_column_store_row_group_physical_stats AS [rg] WITH (NOLOCK)
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[rg].[object_id]
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[rg].[object_id] AND [i].[index_id]=[rg].[index_id]
WHERE 1=1'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
 AND COALESCE([rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0),0)>=@pMinDeleted
 AND (@pOnlyProblems=0 OR [rg].[state_desc]<>''COMPRESSED'' OR COALESCE([rg].[deleted_rows],0)>0)
ORDER BY COALESCE([rg].[deleted_rows]*100.0/NULLIF([rg].[total_rows],0),0) DESC,[rg].[total_rows] ASC
OPTION (MAXDOP 1,RECOMPILE);';
     EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pMinDeleted decimal(9,2),@pOnlyProblems bit',
      @pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pMinDeleted=@MinDeletedPercent,@pOnlyProblems=@NurProblematisch;
     SELECT @Rows=COUNT_BIG(*) FROM [#Columnstore_Physical] WHERE [DatabaseName]=@DbName;
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE' ELSE N'VIEW DATABASE STATE plus CONTROL/geeignete Objektrechte' END,NULL,NULL,N'Quelle COLUMNSTORE_PHYSICAL erfolgreich gelesen.');
    END TRY
    BEGIN CATCH
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW DATABASE PERFORMANCE STATE' ELSE N'VIEW DATABASE STATE plus CONTROL/geeignete Objektrechte' END,ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle COLUMNSTORE_PHYSICAL fehlgeschlagen; Katalogergebnis bleibt erhalten.');
    END CATCH;
   END;

   IF @MitSegmenten=1
   BEGIN
    BEGIN TRY
     SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Columnstore_Segments
SELECT TOP (@pMaxRows) @pDbName,[sch].[name],[o].[name],[i].[index_id],[p].[partition_number],[sg].[column_id],[c].[name],[sg].[segment_id],[sg].[encoding_type],
 CASE [sg].[encoding_type] WHEN 1 THEN ''VALUE_BASED'' WHEN 2 THEN ''VALUE_HASH_BASED'' WHEN 3 THEN ''STRING_HASH_BASED'' WHEN 4 THEN ''STORE_BY_VALUE_BASED'' WHEN 5 THEN ''STRING_STORE_BY_VALUE_BASED'' ELSE ''UNKNOWN'' END,
 [sg].[row_count],[sg].[has_nulls],[sg].[primary_dictionary_id],[sg].[secondary_dictionary_id],CONVERT(decimal(19,4),[sg].[on_disk_size]/1048576.0)
FROM sys.column_store_segments AS [sg] WITH (NOLOCK)
JOIN sys.partitions AS [p] WITH (NOLOCK) ON [p].[hobt_id]=[sg].[hobt_id] AND [p].[partition_id]=[sg].[partition_id]
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[p].[object_id]
JOIN sys.schemas AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[p].[object_id] AND [i].[index_id]=[p].[index_id]
LEFT JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[p].[object_id] AND [c].[column_id]=[sg].[column_id]
WHERE 1=1'+@SchemaPredicateSch+@ObjectPredicateO+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
ORDER BY [sg].[on_disk_size] DESC OPTION (MAXDOP 1,RECOMPILE);';
     EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256)',@pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike;
     SELECT @Rows=COUNT_BIG(*) FROM [#Columnstore_Segments] WHERE [DatabaseName]=@DbName;
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,N'VIEW DEFINITION; Detailspalten teilweise SELECT-abhängig',NULL,NULL,N'Quelle COLUMNSTORE_SEGMENTS erfolgreich gelesen.');
    END TRY
    BEGIN CATCH
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,N'VIEW DEFINITION',ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle COLUMNSTORE_SEGMENTS fehlgeschlagen; andere Teilquellen bleiben verwendbar.');
    END CATCH;
   END;

   IF @MitDictionaries=1
   BEGIN
    BEGIN TRY
     SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Columnstore_Dictionaries
SELECT TOP (@pMaxRows) @pDbName,[sch].[name],[o].[name],[i].[index_id],[p].[partition_number],[d].[column_id],[c].[name],[d].[dictionary_id],[d].[type],
 CASE [d].[type] WHEN 1 THEN ''INT_HASH'' WHEN 3 THEN ''STRING_HASH'' WHEN 4 THEN ''FLOAT_HASH'' ELSE ''UNKNOWN'' END,
 [d].[entry_count],CONVERT(decimal(19,4),[d].[on_disk_size]/1048576.0)
FROM sys.column_store_dictionaries AS [d] WITH (NOLOCK)
JOIN sys.partitions AS [p] WITH (NOLOCK) ON [p].[hobt_id]=[d].[hobt_id] AND [p].[partition_id]=[d].[partition_id]
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[p].[object_id]
JOIN sys.schemas AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[p].[object_id] AND [i].[index_id]=[p].[index_id]
LEFT JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[p].[object_id] AND [c].[column_id]=[d].[column_id]
WHERE 1=1'+@SchemaPredicateSch+@ObjectPredicateO+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
ORDER BY [d].[on_disk_size] DESC OPTION (MAXDOP 1,RECOMPILE);';
     EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256)',@pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike;
     SELECT @Rows=COUNT_BIG(*) FROM [#Columnstore_Dictionaries] WHERE [DatabaseName]=@DbName;
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,N'VIEW DEFINITION; EntryCount zusätzlich SELECT-abhängig',NULL,NULL,N'Quelle COLUMNSTORE_DICTIONARIES erfolgreich gelesen.');
    END TRY
    BEGIN CATCH
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,N'VIEW DEFINITION',ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle COLUMNSTORE_DICTIONARIES fehlgeschlagen; andere Teilquellen bleiben verwendbar.');
    END CATCH;
   END;

   IF @MitSegmentUeberlappung=1
   BEGIN
    IF COALESCE(TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),0)<16
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'UNAVAILABLE_VERSION',1,0,NULL,NULL,NULL,N'Quelle COLUMNSTORE_OVERLAP benötigt SQL Server 2022 oder neuer.');
    ELSE
    BEGIN TRY
     SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; USE '+QUOTENAME(@DbName)+N';
INSERT [#Columnstore_OverlapSource]
([ObjectId],[IndexId],[PartitionNumber],[PartitionId],[HobtId],[ExpectedPartitionId],[ExpectedHobtId],[ColumnId],[SegmentId],[SchemaName],[ObjectName],[IndexName],[ColumnName],[SystemTypeName],[MaxLength],[EncodingType],[NativeRowCount],[CollationId],[MinNumber],[MaxNumber],[MinBinary],[MaxBinary])
SELECT TOP (@pSegmentLimit) [p].[object_id],[p].[index_id],[p].[partition_number],[sg].[partition_id],[sg].[hobt_id],[p].[partition_id],[p].[hobt_id],[sg].[column_id],[sg].[segment_id],
 [sch].[name],[o].[name],[i].[name],[c].[name],[t].[name],[c].[max_length],[sg].[encoding_type],[sg].[row_count],[sg].[collation_id],
 [sg].[min_data_id],[sg].[max_data_id],[sg].[min_deep_data],[sg].[max_deep_data]
FROM [sys].[column_store_segments] AS [sg] WITH (NOLOCK)
JOIN [sys].[partitions] AS [p] WITH (NOLOCK) ON ([p].[partition_id]>0 AND [p].[partition_id]=[sg].[partition_id]) OR ([p].[hobt_id]>0 AND [p].[hobt_id]=[sg].[hobt_id])
JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[object_id]=[p].[object_id]
JOIN [sys].[schemas] AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
JOIN [sys].[indexes] AS [i] WITH (NOLOCK) ON [i].[object_id]=[p].[object_id] AND [i].[index_id]=[p].[index_id]
LEFT JOIN [sys].[columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[p].[object_id] AND [c].[column_id]=[sg].[column_id]
LEFT JOIN [sys].[types] AS [t] WITH (NOLOCK) ON [t].[system_type_id]=[c].[system_type_id] AND [t].[user_type_id]=[t].[system_type_id]
WHERE [i].[type] IN (5,6)'+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
ORDER BY [p].[object_id],[p].[index_id],[p].[partition_number],[sg].[column_id],[sg].[segment_id]
OPTION (MAXDOP 1,RECOMPILE);';
     EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pSegmentLimit int',@pDbName=@DbName,@pSegmentLimit=@OverlapSentinel;
     IF EXISTS(SELECT 1 FROM [#Columnstore_OverlapSource] WHERE [ObjectId] IS NULL OR [IndexId] IS NULL OR [PartitionNumber] IS NULL OR [PartitionId] IS NULL OR [HobtId] IS NULL OR [ExpectedPartitionId] IS NULL OR [ExpectedHobtId] IS NULL OR [PartitionId]<>[ExpectedPartitionId] OR [HobtId]<>[ExpectedHobtId] OR [ColumnId] IS NULL OR [SegmentId] IS NULL OR [SchemaName] IS NULL OR [ObjectName] IS NULL)
        OR EXISTS(SELECT 1 FROM [#Columnstore_OverlapSource] GROUP BY [PartitionId],[HobtId],[ColumnId],[SegmentId] HAVING COUNT_BIG(*)>1)
        OR EXISTS(SELECT 1 FROM [#Columnstore_OverlapSource] GROUP BY [ObjectId],[IndexId],[PartitionNumber] HAVING COUNT(DISTINCT [PartitionId])<>1 OR COUNT(DISTINCT [HobtId])<>1)
     BEGIN
      INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE_LIMITED',1,0,NULL,NULL,NULL,N'Quelle COLUMNSTORE_OVERLAP: INCONSISTENT_SEGMENT_IDENTITY; gesamte Aufnahme ohne Gruppenwerte verworfen.');
     END
     ELSE IF (SELECT COUNT_BIG(*) FROM [#Columnstore_OverlapSource])>@MaxSegmenteAnalyse
      INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,'AVAILABLE_LIMITED',1,0,NULL,NULL,NULL,CONCAT(N'Quelle COLUMNSTORE_OVERLAP: SEGMENT_LIMIT_EXCEEDED; beobachtete Mindestmenge ',@OverlapSentinel,N', kein vollständiger Count.'));
     ELSE
     BEGIN
      UPDATE [#Columnstore_OverlapSource]
      SET [RangeClass]=CASE
       WHEN [NativeRowCount]>0 AND [SystemTypeName] IN(N'bit',N'tinyint',N'smallint',N'bigint',N'money') AND [EncodingType] IN(1,2) AND [MinNumber] IS NOT NULL AND [MaxNumber] IS NOT NULL AND [MinNumber]<=[MaxNumber] THEN 1
       WHEN [NativeRowCount]>0 AND [SystemTypeName] IN(N'binary',N'varbinary',N'char',N'nchar',N'varchar',N'nvarchar') AND [MaxLength]<>-1 AND [EncodingType] IN(3,5) AND [MinBinary] IS NOT NULL AND [MaxBinary] IS NOT NULL AND [MinBinary]<=[MaxBinary]
        AND ([SystemTypeName] IN(N'binary',N'varbinary') OR [CollationId] IS NOT NULL) THEN 2
       ELSE NULL END;
      ;WITH [Groups] AS
      (
       SELECT [ObjectId],[IndexId],[PartitionNumber],[ColumnId],MIN([SchemaName]) AS [SchemaName],MIN([ObjectName]) AS [ObjectName],MIN([IndexName]) AS [IndexName],MIN([ColumnName]) AS [ColumnName],
        CASE WHEN COUNT(DISTINCT [SystemTypeName])=1 THEN MIN([SystemTypeName]) END AS [SystemTypeName],COUNT_BIG(*) AS [Observed],
        CASE WHEN COUNT(DISTINCT [SystemTypeName])>1 OR COUNT(DISTINCT [RangeClass])>1
          OR (MAX(CASE WHEN [SystemTypeName] IN(N'char',N'nchar',N'varchar',N'nvarchar') THEN 1 ELSE 0 END)=1 AND COUNT(DISTINCT [CollationId])>1)
         THEN CONVERT(bigint,0) ELSE SUM(CONVERT(bigint,CASE WHEN [RangeClass] IS NOT NULL THEN 1 ELSE 0 END)) END AS [Comparable]
       FROM [#Columnstore_OverlapSource] GROUP BY [ObjectId],[IndexId],[PartitionNumber],[ColumnId]
      )
      INSERT [#Columnstore_SegmentOverlap]
      SELECT @DbName,[SchemaName],[ObjectName],[ObjectId],[IndexId],[IndexName],[PartitionNumber],[ColumnId],[ColumnName],[SystemTypeName],[Observed],[Comparable],[Observed]-[Comparable],NULL,NULL,
       CASE WHEN [Comparable]=[Observed] THEN 'AVAILABLE' ELSE 'AVAILABLE_LIMITED' END,
       CONVERT(bit,CASE WHEN [Comparable]=[Observed] THEN 0 ELSE 1 END),CASE WHEN [Comparable]<>[Observed] THEN 'INCOMPLETE_RANGE_METADATA' END,@CollectionTimeUtc
      FROM [Groups];
      ;WITH [Endpoints] AS
      (
       SELECT [s].[ObjectId],[s].[IndexId],[s].[PartitionNumber],[s].[ColumnId],[s].[RangeClass],
        CASE WHEN [s].[RangeClass]=1 THEN [s].[MinNumber] END AS [NumberBoundary],CASE WHEN [s].[RangeClass]=2 THEN [s].[MinBinary] END AS [BinaryBoundary],
        CONVERT(bigint,1) AS [Starts],CONVERT(bigint,0) AS [Ends],CONVERT(bigint,CASE WHEN ([s].[RangeClass]=1 AND [s].[MinNumber]=[s].[MaxNumber]) OR ([s].[RangeClass]=2 AND [s].[MinBinary]=[s].[MaxBinary]) THEN 1 ELSE 0 END) AS [Points]
       FROM [#Columnstore_OverlapSource] AS [s] JOIN [#Columnstore_SegmentOverlap] AS [g] ON [g].[ObjectId]=[s].[ObjectId] AND [g].[IndexId]=[s].[IndexId] AND [g].[PartitionNumber]=[s].[PartitionNumber] AND [g].[ColumnId]=[s].[ColumnId] WHERE [g].[IsPartial]=0
       UNION ALL
       SELECT [s].[ObjectId],[s].[IndexId],[s].[PartitionNumber],[s].[ColumnId],[s].[RangeClass],CASE WHEN [s].[RangeClass]=1 THEN [s].[MaxNumber] END,CASE WHEN [s].[RangeClass]=2 THEN [s].[MaxBinary] END,0,1,0
       FROM [#Columnstore_OverlapSource] AS [s] JOIN [#Columnstore_SegmentOverlap] AS [g] ON [g].[ObjectId]=[s].[ObjectId] AND [g].[IndexId]=[s].[IndexId] AND [g].[PartitionNumber]=[s].[PartitionNumber] AND [g].[ColumnId]=[s].[ColumnId] WHERE [g].[IsPartial]=0
      ),[BoundaryCounts] AS
      (
       SELECT [ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass],[NumberBoundary],[BinaryBoundary],SUM([Starts]) AS [Starts],SUM([Ends]) AS [Ends],SUM([Points]) AS [Points]
       FROM [Endpoints] GROUP BY [ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass],[NumberBoundary],[BinaryBoundary]
      )
      INSERT [#Columnstore_OverlapRanks]
      SELECT *,SUM([Starts]) OVER(PARTITION BY [ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass] ORDER BY [NumberBoundary],[BinaryBoundary] ROWS UNBOUNDED PRECEDING)-[Starts],
       SUM([Ends]) OVER(PARTITION BY [ObjectId],[IndexId],[PartitionNumber],[ColumnId],[RangeClass] ORDER BY [NumberBoundary],[BinaryBoundary] ROWS UNBOUNDED PRECEDING)
      FROM [BoundaryCounts];
      ;WITH [SegmentCounts] AS
      (
       SELECT [s].[ObjectId],[s].[IndexId],[s].[PartitionNumber],[s].[ColumnId],
        [mx].[StartLess]-[mn].[EndLessEqual]+CASE WHEN [s].[MinNumber]=[s].[MaxNumber] THEN [mn].[Points] ELSE CONVERT(bigint,-1) END AS [Strict],
        [mx].[Starts]+[mn].[Ends]-CASE WHEN [s].[MinNumber]=[s].[MaxNumber] THEN [mn].[Points]+1 ELSE CONVERT(bigint,0) END AS [Touch]
       FROM [#Columnstore_OverlapSource] AS [s]
       JOIN [#Columnstore_OverlapRanks] AS [mn] ON [mn].[ObjectId]=[s].[ObjectId] AND [mn].[IndexId]=[s].[IndexId] AND [mn].[PartitionNumber]=[s].[PartitionNumber] AND [mn].[ColumnId]=[s].[ColumnId] AND [mn].[RangeClass]=1 AND [mn].[NumberBoundary]=[s].[MinNumber]
       JOIN [#Columnstore_OverlapRanks] AS [mx] ON [mx].[ObjectId]=[s].[ObjectId] AND [mx].[IndexId]=[s].[IndexId] AND [mx].[PartitionNumber]=[s].[PartitionNumber] AND [mx].[ColumnId]=[s].[ColumnId] AND [mx].[RangeClass]=1 AND [mx].[NumberBoundary]=[s].[MaxNumber]
       WHERE [s].[RangeClass]=1
       UNION ALL
       SELECT [s].[ObjectId],[s].[IndexId],[s].[PartitionNumber],[s].[ColumnId],
        [mx].[StartLess]-[mn].[EndLessEqual]+CASE WHEN [s].[MinBinary]=[s].[MaxBinary] THEN [mn].[Points] ELSE CONVERT(bigint,-1) END,
        [mx].[Starts]+[mn].[Ends]-CASE WHEN [s].[MinBinary]=[s].[MaxBinary] THEN [mn].[Points]+1 ELSE CONVERT(bigint,0) END
       FROM [#Columnstore_OverlapSource] AS [s]
       JOIN [#Columnstore_OverlapRanks] AS [mn] ON [mn].[ObjectId]=[s].[ObjectId] AND [mn].[IndexId]=[s].[IndexId] AND [mn].[PartitionNumber]=[s].[PartitionNumber] AND [mn].[ColumnId]=[s].[ColumnId] AND [mn].[RangeClass]=2 AND [mn].[BinaryBoundary]=[s].[MinBinary]
       JOIN [#Columnstore_OverlapRanks] AS [mx] ON [mx].[ObjectId]=[s].[ObjectId] AND [mx].[IndexId]=[s].[IndexId] AND [mx].[PartitionNumber]=[s].[PartitionNumber] AND [mx].[ColumnId]=[s].[ColumnId] AND [mx].[RangeClass]=2 AND [mx].[BinaryBoundary]=[s].[MaxBinary]
       WHERE [s].[RangeClass]=2
      ),[PairCounts] AS
      (
       SELECT [ObjectId],[IndexId],[PartitionNumber],[ColumnId],SUM([Strict])/2 AS [StrictPairs],SUM([Touch])/2 AS [TouchPairs]
       FROM [SegmentCounts] GROUP BY [ObjectId],[IndexId],[PartitionNumber],[ColumnId]
      )
      UPDATE [g] SET [StrictOverlapPairCount]=[p].[StrictPairs],[BoundaryTouchPairCount]=[p].[TouchPairs]
      FROM [#Columnstore_SegmentOverlap] AS [g] JOIN [PairCounts] AS [p] ON [p].[ObjectId]=[g].[ObjectId] AND [p].[IndexId]=[g].[IndexId] AND [p].[PartitionNumber]=[g].[PartitionNumber] AND [p].[ColumnId]=[g].[ColumnId];
      DECLARE @OverlapIncomplete bit=CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [#Columnstore_SegmentOverlap] WHERE [IsPartial]=1) THEN 1 ELSE 0 END);
      ;WITH [Limited] AS (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId]) AS [OutputOrdinal] FROM [#Columnstore_SegmentOverlap])
      DELETE FROM [Limited] WHERE [OutputOrdinal]>@EffectiveMaxZeilen;
      SELECT @OverlapRows=COUNT_BIG(*) FROM [#Columnstore_SegmentOverlap];
      INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN @OverlapIncomplete=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,@OverlapIncomplete,@OverlapRows,N'VIEW DEFINITION; Grenzen teilweise SELECT-abhängig',NULL,NULL,N'Quelle COLUMNSTORE_OVERLAP; Paarwerte sind Metadatenvergleiche, kein Qualitäts- oder Performanceurteil.');
     END;
    END TRY
    BEGIN CATCH
     DELETE FROM [#Columnstore_SegmentOverlap]; SET @OverlapRows=0;
     INSERT [#Columnstore_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,N'VIEW DEFINITION',ERROR_NUMBER(),ERROR_MESSAGE(),N'Quelle COLUMNSTORE_OVERLAP fehlgeschlagen; andere Teilquellen bleiben erhalten.');
    END CATCH;
   END;

   FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  END;
  CLOSE dbcur; DEALLOCATE dbcur;
  IF NOT EXISTS(SELECT 1 FROM [#Columnstore_DatabaseStatus])
   INSERT [#Columnstore_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
 END;



    SELECT @TotalRows=@OverlapRows+(SELECT COUNT_BIG(*) FROM [#Columnstore_Result])+(SELECT COUNT_BIG(*) FROM [#Columnstore_Ordering])+(SELECT COUNT_BIG(*) FROM [#Columnstore_Physical])+(SELECT COUNT_BIG(*) FROM [#Columnstore_Segments])+(SELECT COUNT_BIG(*) FROM [#Columnstore_Dictionaries]);

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#Columnstore_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#Columnstore_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#Columnstore_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
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
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#Columnstore_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Columnstore_Result] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId]; ELSE SELECT N'Columnstore Rowgroup' [Ergebnis],[r].* FROM [#Columnstore_Result] [r] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Columnstore_Ordering] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexId],[ColumnStoreOrderOrdinal];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Columnstore_Physical] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId]; ELSE SELECT N'Columnstore Rowgroup' [Ergebnis],[r].* FROM [#Columnstore_Physical] [r] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Columnstore_Segments] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId],[ColumnId]; ELSE SELECT N'Columnstore Rowgroup' [Ergebnis],[r].* FROM [#Columnstore_Segments] [r] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId],[ColumnId];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Columnstore_Dictionaries] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId],[DictionaryId]; ELSE SELECT N'Columnstore Rowgroup' [Ergebnis],[r].* FROM [#Columnstore_Dictionaries] [r] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId],[DictionaryId];
    END;
    IF @MitSegmentUeberlappung=1 AND @ResultSetArtNormalisiert='RAW'
        SELECT * FROM [#Columnstore_SegmentOverlap] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId];
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],CASE WHEN @MitSegmentUeberlappung=1 THEN 2 ELSE 1 END [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#Columnstore_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#Columnstore_Result] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonOrdering nvarchar(max)=(SELECT * FROM [#Columnstore_Ordering] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexId],[ColumnStoreOrderOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData2 nvarchar(max)=(SELECT * FROM [#Columnstore_Physical] ORDER BY [DeletedPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData3 nvarchar(max)=(SELECT * FROM [#Columnstore_Segments] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[RowGroupId],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData4 nvarchar(max)=(SELECT * FROM [#Columnstore_Dictionaries] ORDER BY [OnDiskSizeMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId],[DictionaryId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonOverlap nvarchar(max)=NULL;
        IF @MitSegmentUeberlappung=1 SET @JsonOverlap=(SELECT * FROM [#Columnstore_SegmentOverlap] ORDER BY [DatabaseName],[SchemaName],[ObjectName],[IndexId],[PartitionNumber],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"rowgroups":',COALESCE(@JsonData1,N'[]'),N',"ordering":',COALESCE(@JsonOrdering,N'[]'),N',"physicalStats":',COALESCE(@JsonData2,N'[]'),N',"segments":',COALESCE(@JsonData3,N'[]'),N',"dictionaries":',COALESCE(@JsonData4,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),CASE WHEN @MitSegmentUeberlappung=1 THEN CONCAT(N',"segmentOverlap":',COALESCE(@JsonOverlap,N'[]')) ELSE N'' END,N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        DECLARE @ColumnstoreConsoleSource sysname=CASE WHEN @MitSegmentUeberlappung=1 THEN N'#Columnstore_SegmentOverlap' ELSE N'#Columnstore_Result' END;
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=@ColumnstoreConsoleSource
            , @ResultLabel=N'Columnstore'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        IF @TableTarget IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#Columnstore_Result',@TargetTable=@TableTarget,@ThrowOnError=1;
        IF @OrderingTableTarget IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#Columnstore_Ordering',@TargetTable=@OrderingTableTarget,@ThrowOnError=1;
        IF @OverlapTableTarget IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#Columnstore_SegmentOverlap',@TargetTable=@OverlapTableTarget,@ThrowOnError=1;
    END;
END;
GO
