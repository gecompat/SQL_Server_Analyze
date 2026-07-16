USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_Statistics
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Analysiert Statistikdefinitionen, letzte Aktualisierung, Stichprobe und Modification Counter; vollständige ungezielte Scans sind gruppengeschützt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.stats, sys.stats_columns, sys.columns, sys.objects, sys.tables, sys.schemas, sys.dm_db_stats_properties und optional sys.dm_db_incremental_stats_properties.
Parameter    :
  @DatabaseName                  sysname        = NULL  - Zieldatenbank; bei Einzelmodus Pflicht.
  @CrossDatabaseRequestedInternal               bit            = 0     - sichtbare Online-Datenbanken analysieren.
  @SystemdatenbankenEinbeziehen  bit            = 0     - master/model/msdb/tempdb einbeziehen.
  @DatenbankNameLike             nvarchar(256)  = NULL  - Filter im Cross-Database-Modus.
  @SchemaNamePattern                nvarchar(256)  = NULL  - LIKE-Filter auf Schema.
  @ObjectNamePattern                nvarchar(256)  = NULL  - LIKE-Filter auf Objekt.
  @MaxDatenbanken                int            = 16    - positive Werte begrenzen; NULL/0 = alle sichtbaren Datenbanken.
  @MaxZeilen                     int            = 5000  - positive Werte begrenzen; NULL/0 = unbegrenzt.
  @LockTimeoutMs                 int            = 0     - 0 = nicht auf Metadatenlocks warten.
  @PrintMeldungen                bit            = 1     - Warnungen via RAISERROR 10.
  @Hilfe                         bit            = 0     - Hilfe via PRINT, keine Analyse.
  @AnalyseModus varchar(16) = 'GEZIELT' - GEZIELT|VOLL; VOLL benötigt CATALOG_DEEP.
  @StatisticsNamePattern nvarchar(256)=NULL - Statistikfilter.
  @MinModificationPercent decimal(9,2)=0 - Mindeständerungsanteil.
  @MinAlterTage int=0 - Mindestalter der letzten Aktualisierung.
  @MitIncrementellenDetails bit=0 - Partitionsdetails für inkrementelle Statistiken.
Resultsets   : 1. Modulstatus. 2. Status je Datenbank. 3. Statistikübersicht. 4. optionale inkrementelle Partitionsdetails.
Berechtigung : Metadata Visibility und SELECT auf Statistikspalten bzw. Eigentum/db_owner/db_ddladmin/sysadmin für dm_db_stats_properties.
Eigenlast    : Gezielte Abfrage moderat; VOLL und inkrementelle Details durch CATALOG_DEEP/Cross-Database geschützt und begrenzt.
Locking      : READUNCOMMITTED-Kataloge, LOCK_TIMEOUT und je Datenbank isolierter dynamischer Batch.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @SchemaNamePattern=N'dbo', @ObjectNamePattern=N'FactSales';
  EXEC monitor.USP_Statistics @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @MinModificationPercent=10;
  EXEC monitor.USP_Statistics @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_Statistics]
      @DatabaseNames                  nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @StatisticsNames                nvarchar(max)  = NULL
    , @StatisticsNamePattern          nvarchar(4000) = NULL
    , @AnalyseModus                   varchar(16)   = 'GEZIELT'
    , @MinModificationPercent         decimal(9,2)  = 0
    , @MinAlterTage                   int           = 0
    , @MitIncrementellenDetails       bit           = 0
    , @MaxDatenbanken                 int           = 16
    , @MaxZeilen                      int           = 10000
    , @LockTimeoutMs                  int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit           = 1
    , @Hilfe                          bit           = 0
AS
BEGIN
 SET NOCOUNT ON;

    SET @Json = NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @DatabaseName sysname=NULL,@CrossDatabaseRequestedInternal bit=0,@DatenbankNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaNameLike nvarchar(4000)=NULL,@ObjectNameLike nvarchar(4000)=NULL;
    DECLARE @StatisticsNameLike nvarchar(4000)=NULL;
    DECLARE @SchemaPatternMode varchar(8),@SchemaPatternValue nvarchar(4000),@SchemaRegexFlags varchar(8),@SchemaPatternValid bit;
    DECLARE @ObjectPatternMode varchar(8),@ObjectPatternValue nvarchar(4000),@ObjectRegexFlags varchar(8),@ObjectPatternValid bit;
    SELECT @SchemaPatternMode=[PatternMode],@SchemaPatternValue=[PatternValue],@SchemaRegexFlags=[RegexFlags],@SchemaPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@SchemaNamePattern);
    SELECT @ObjectPatternMode=[PatternMode],@ObjectPatternValue=[PatternValue],@ObjectRegexFlags=[RegexFlags],@ObjectPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ObjectNamePattern);
    IF @SchemaPatternMode='LIKE' SET @SchemaNameLike=@SchemaPatternValue;
    IF @ObjectPatternMode='LIKE' SET @ObjectNameLike=@ObjectPatternValue;
    DECLARE @IndexPatternMode varchar(8)='NONE',@IndexPatternValue nvarchar(4000)=NULL,@IndexRegexFlags varchar(8)=NULL,@IndexPatternValid bit=1;
    DECLARE @StatisticsPatternMode varchar(8),@StatisticsPatternValue nvarchar(4000),@StatisticsRegexFlags varchar(8),@StatisticsPatternValid bit;
    SELECT @StatisticsPatternMode=[PatternMode],@StatisticsPatternValue=[PatternValue],@StatisticsRegexFlags=[RegexFlags],@StatisticsPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@StatisticsNamePattern);
    IF @StatisticsPatternMode='LIKE' SET @StatisticsNameLike=@StatisticsPatternValue;
    DECLARE @DatabaseListCount int=0;
    IF @DatabaseNames IS NOT NULL AND NULLIF(LTRIM(RTRIM(@DatabaseNames)),N'') IS NOT NULL
        SELECT @DatabaseListCount=COUNT(*),@DatabaseName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid]=1;
    SET @CrossDatabaseRequestedInternal=CONVERT(bit,CASE WHEN @DatabaseNames IS NULL OR @DatabaseNamePattern IS NOT NULL OR @DatabaseListCount>1 THEN 1 ELSE 0 END);
    SELECT @DatenbankNameLike=CASE WHEN [PatternMode]='LIKE' THEN [PatternValue] END FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);
    CREATE TABLE [#NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=NULL,@StatisticsNames=@StatisticsNames,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT;
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='CROSS_DATABASE_DEEP',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDbName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')=1';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')=1';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')=1';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')=1';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')=1';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @EffectiveMaxDatenbanken bigint = CASE WHEN @MaxDatenbanken IS NULL OR @MaxDatenbanken=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxDatenbanken) END;
    DECLARE @MonitorPrintMessage nvarchar(2048); SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
 IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_Statistics';        PRINT N'@DatabaseNames: exakter Name oder bracket-aware Pipe-Liste; NULL = alle zulässigen Datenbanken; N'''' = ungültiger sicherer Default.';        PRINT N'@SystemdatenbankenEinbeziehen bit = 0: Systemdatenbanken einbeziehen.';        PRINT N'Exakte Listen und ...NamePattern sind gegenseitig exklusiv. Pattern: LIKE (Default/like:), regex: oder regexi:.';
        PRINT N'@MaxDatenbanken int = 16; @MaxZeilen int: harte Ergebnismengenbegrenzung.';
        PRINT N'@LockTimeoutMs int = 0: Metadatenzugriff wartet standardmäßig nicht auf Locks.';
        PRINT N'@PrintMeldungen bit = 1: strukturierte Warnungen zusätzlich in der Console.';
        PRINT N'Zweck: Statistikalter, Sample, Rows und Modification Counter.';
        PRINT N'@AnalyseModus = GEZIELT: Schema- oder Objektfilter ist erforderlich; VOLL prüft CATALOG_DEEP.';
        PRINT N'@StatisticsNamePattern: optionaler Statistikname-Filter.';
        PRINT N'@MinModificationPercent: 0 bis 100; nur entsprechende Statistiken.';
        PRINT N'@MinAlterTage: Mindestalter seit last_updated; 0 deaktiviert.';
        PRINT N'@MitIncrementellenDetails: zusätzliche Partitionswerte inkrementeller Statistiken.';
        PRINT N'@Hilfe bit = 0: 1 zeigt diese Hilfe und führt keine Analyse aus.';
        RETURN;
 END;

    DECLARE @ModuleName sysname = N'USP_Statistics';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#DatabaseStatus]
    (
          [DatabaseName]       sysname        NULL
        , [StatusCode]         varchar(40)    NOT NULL
        , [IsPartial]          bit            NOT NULL
        , [RowCount]           bigint         NOT NULL
        , [RequiredPermission] nvarchar(256)  NULL
        , [ErrorNumber]        int            NULL
        , [ErrorMessage]       nvarchar(2048) NULL
        , [Detail]             nvarchar(2000) NULL
    );

    IF @FilterStatus<>'AVAILABLE' BEGIN SET @OverallStatus=@FilterStatus;SET @ErrorMessage=@FilterError;END;
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) OR (@StatisticsNames IS NOT NULL AND @StatisticsNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxDatenbanken<0 OR @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxDatenbanken, @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
    END;

 DECLARE @CatalogAllowed bit=1;
 IF @AnalyseModus='VOLL' OR @MitIncrementellenDetails=1 SELECT @CatalogAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='CATALOG_DEEP';
 CREATE TABLE [#Result]
 (
  [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL,
  [StatisticsId] int NOT NULL,[StatisticsName] sysname NOT NULL,[IsIndexStatistics] bit NOT NULL,[IsAutoCreated] bit NULL,[IsUserCreated] bit NULL,
  [IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) NULL,[NoRecompute] bit NULL,[IsIncremental] bit NULL,[HasPersistedSample] bit NULL,
  [StatisticsColumns] nvarchar(max) NULL,[LastUpdated] datetime2 NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[SamplePercent] decimal(9,4) NULL,
  [Steps] int NULL,[UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,4) NULL,
  [PersistedSamplePercent] float NULL,[DaysSinceLastUpdate] int NULL,[VisibilityOrState] varchar(40) NOT NULL
 );
 CREATE TABLE [#Incremental]
 (
  [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[StatisticsId] int NOT NULL,[StatisticsName] sysname NOT NULL,
  [PartitionNumber] int NOT NULL,[LastUpdated] datetime2 NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL,[Steps] int NULL,
  [UnfilteredRows] bigint NULL,[ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,4) NULL
 );
 IF @OverallStatus='AVAILABLE' AND (@AnalyseModus NOT IN ('GEZIELT','VOLL') OR @MinModificationPercent<0 OR @MinModificationPercent>100 OR @MinAlterTage<0)
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'Ungültige Statistikparameter.'; INSERT [#DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#NameFilters]) AND @SchemaNamePattern IS NULL AND @ObjectNamePattern IS NULL
 BEGIN SET @OverallStatus='INVALID_PARAMETER'; SET @ErrorMessage=N'GEZIELT erfordert eine exakte Namensliste, @FullObjectNames oder ein Schema-/Objekt-Pattern.'; INSERT [#DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE' AND (@AnalyseModus='VOLL' OR @MitIncrementellenDetails=1) AND @CatalogAllowed=0
 BEGIN SET @OverallStatus='DENIED_GROUP'; SET @ErrorMessage=N'CATALOG_DEEP ist für VOLL bzw. inkrementelle Details nicht freigegeben.'; INSERT [#DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL); END
 ELSE IF @OverallStatus='AVAILABLE'
 BEGIN
  DECLARE @DbId int,@DbName sysname,@Sql nvarchar(max),@Rows bigint;
  DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName] FROM [#DatabaseCandidates];
  OPEN dbcur; FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  WHILE @@FETCH_STATUS=0
  BEGIN
   BEGIN TRY
    SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
INSERT #Result
SELECT TOP (@pMaxRows)
 @pDbName,[sch].[name],[o].[name],[o].[object_id],[st].[stats_id],[st].[name],CONVERT(bit,CASE WHEN [ix].[index_id] IS NULL THEN 0 ELSE 1 END),
 [st].[auto_created],[st].[user_created],[st].[has_filter],[st].[filter_definition],[st].[no_recompute],[st].[is_incremental],[st].[has_persisted_sample],
 [cols].[StatisticsColumns],[sp].[last_updated],[sp].[rows],[sp].[rows_sampled],
 CONVERT(decimal(9,4),[sp].[rows_sampled]*100.0/NULLIF([sp].[rows],0)),[sp].[steps],[sp].[unfiltered_rows],[sp].[modification_counter],
 CONVERT(decimal(19,4),[sp].[modification_counter]*100.0/NULLIF([sp].[rows],0)),[sp].[persisted_sample_percent],
 CASE WHEN [sp].[last_updated] IS NULL THEN NULL ELSE DATEDIFF(DAY,[sp].[last_updated],SYSDATETIME()) END,
 CASE WHEN [sp].[last_updated] IS NULL AND [sp].[rows] IS NULL THEN ''NOT_VISIBLE_OR_NOT_MATERIALIZED''
      WHEN [sp].[rows]=0 THEN ''EMPTY_OR_FILTER_NO_ROWS''
      ELSE ''VISIBLE'' END
FROM sys.stats AS [st] WITH (NOLOCK)
JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[st].[object_id]
JOIN sys.schemas AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
LEFT JOIN sys.indexes AS [ix] WITH (NOLOCK) ON [ix].[object_id]=[st].[object_id] AND [ix].[index_id]=[st].[stats_id]
OUTER APPLY sys.dm_db_stats_properties([st].[object_id],[st].[stats_id]) AS [sp]
OUTER APPLY
(
 SELECT STUFF((SELECT N'', ''+QUOTENAME([c].[name])
               FROM sys.stats_columns AS [sc] WITH (NOLOCK)
               JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[sc].[object_id] AND [c].[column_id]=[sc].[column_id]
               WHERE [sc].[object_id]=[st].[object_id] AND [sc].[stats_id]=[st].[stats_id]
               ORDER BY [sc].[stats_column_id] FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,N'''') AS [StatisticsColumns]
) AS [cols]
WHERE [o].[type] IN (''U'',''V'') AND [o].[is_ms_shipped]=0
'+@SchemaPredicateSch+@ObjectPredicateO+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
'+@StatisticsPredicateSt+N'
 AND (COALESCE([sp].[modification_counter]*100.0/NULLIF([sp].[rows],0),0)>=@pMinModPct)
 AND (@pMinAge=0 OR [sp].[last_updated] IS NULL OR DATEDIFF(DAY,[sp].[last_updated],SYSDATETIME())>=@pMinAge)
ORDER BY COALESCE([sp].[modification_counter]*100.0/NULLIF([sp].[rows],0),0) DESC,[sp].[last_updated]
OPTION (MAXDOP 1, RECOMPILE);
IF @pWithIncremental=1
BEGIN
 BEGIN TRY
  INSERT #Incremental
  SELECT TOP (@pMaxRows) @pDbName,[sch].[name],[o].[name],[st].[stats_id],[st].[name],[ip].[partition_number],[ip].[last_updated],[ip].[rows],[ip].[rows_sampled],[ip].[steps],[ip].[unfiltered_rows],[ip].[modification_counter],
         CONVERT(decimal(19,4),[ip].[modification_counter]*100.0/NULLIF([ip].[rows],0))
  FROM sys.stats AS [st] WITH (NOLOCK)
  JOIN sys.objects AS [o] WITH (NOLOCK) ON [o].[object_id]=[st].[object_id]
  JOIN sys.schemas AS [sch] WITH (NOLOCK) ON [sch].[schema_id]=[o].[schema_id]
  CROSS APPLY sys.dm_db_incremental_stats_properties([st].[object_id],[st].[stats_id]) AS [ip]
  WHERE [st].[is_incremental]=1 AND [o].[is_ms_shipped]=0
'+@SchemaPredicateSch+@ObjectPredicateO+REPLACE(@FullObjectPredicateSO,N'[s].[name]',N'[sch].[name]')+N'
  '+@StatisticsPredicateSt+N'
  ORDER BY [ip].[modification_counter]*100.0/NULLIF([ip].[rows],0) DESC;
 END TRY
 BEGIN CATCH
  INSERT #DatabaseStatus VALUES(@pDbName,
   CASE WHEN ERROR_NUMBER() IN (229,262,297,300,916) THEN ''DENIED_PERMISSION'' WHEN ERROR_NUMBER()=1222 THEN ''TIMEOUT'' WHEN ERROR_NUMBER() IN (207,208,4121) THEN ''UNAVAILABLE_OBJECT'' ELSE ''ERROR_HANDLED'' END,
   1,0,N''SELECT auf Statistikspalten oder geeignete Rolle/Eigentum'',ERROR_NUMBER(),ERROR_MESSAGE(),N''Quelle STATS_INCREMENTAL fehlgeschlagen; Basisstatistiken bleiben erhalten.'');
 END CATCH;
END;';
    EXEC [sys].[sp_executesql] @Sql,N'@pDbName sysname,@pMaxRows bigint,@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pStatsLike nvarchar(256),@pMinModPct decimal(9,2),@pMinAge int,@pWithIncremental bit',@pDbName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pStatsLike=@StatisticsNameLike,@pMinModPct=@MinModificationPercent,@pMinAge=@MinAlterTage,@pWithIncremental=@MitIncrementellenDetails;
    SET @Rows=(SELECT COUNT_BIG(*) FROM [#Result] WHERE [DatabaseName]=@DbName); INSERT [#DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,N'SELECT [auf] [Statistikspalten] oder [Eigentum]/[db_owner]/[db_ddladmin]/[sysadmin]',NULL,NULL,N'NULL-Werte können fehlende Sichtbarkeit oder noch nicht materialisierte Statistiken bedeuten.');
   END TRY
   BEGIN CATCH
    INSERT [#DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,1,0,N'SELECT [auf] [Statistikspalten] oder [geeignete] [Rolle]/[Eigentum]',ERROR_NUMBER(),ERROR_MESSAGE(),N'Statistikfehler isoliert.');
   END CATCH;
   FETCH NEXT FROM dbcur INTO @DbId,@DbName;
  END; CLOSE dbcur; DEALLOCATE dbcur;
  IF NOT EXISTS(SELECT 1 FROM [#DatabaseStatus]) INSERT [#DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
 END;

    

    SELECT @TotalRows=(SELECT COUNT_BIG(*) FROM [#Result])+(SELECT COUNT_BIG(*) FROM [#Incremental]);

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
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
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#Result] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName]; ELSE SELECT N'Statistik' [Ergebnis],[r].* FROM [#Result] [r] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName];
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#Result] ORDER BY [ModificationPercent] DESC,[DatabaseName],[SchemaName],[ObjectName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"statistics":',COALESCE(@JsonData1,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
END;
GO
