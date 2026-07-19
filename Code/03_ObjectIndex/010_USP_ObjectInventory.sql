USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ObjectInventory
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Liefert ein fehlertolerantes Objekt- und Indexinventar einschließlich Größe, Zeilen, Kompression, Partitionierung und optionalen Spaltenlisten.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : master.sys.databases sowie je Zieldatenbank sys.objects, sys.tables, sys.schemas, sys.indexes, sys.index_columns, sys.columns, sys.partitions, sys.allocation_units und sys.data_spaces.
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
  @ObjectType varchar(16) = 'TABLE' - TABLE|VIEW|ALLE.
  @AnalyseModus varchar(16) = 'GEZIELT' - GEZIELT benötigt Filter; VOLL prüft CATALOG_DEEP.
  @MitIndizes bit = 1 - Indexdetails; 0 liefert je Objekt eine Summenzeile.
  @MitSpaltenlisten bit = 1 - Key-/Include-Spaltenlisten erzeugen.
Resultsets   : 1. Modulstatus. 2. Status je Datenbank. 3. Objekt-/Indexinventar.
Berechtigung : Katalogsicht gemäß Metadata Visibility; Cross-Database zusätzlich Gruppenpolicy. Keine Rechtevergabe.
Eigenlast    : Gezielte Einzel-Datenbank-Abfrage gering bis moderat; Cross-Database und Spaltenlisten begrenzt durch TOP.
Locking      : READUNCOMMITTED/NOLOCK auf Systemkatalogen und konfigurierbares LOCK_TIMEOUT; unvollständige Metadaten sind zulässig.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_ObjectInventory @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_ObjectInventory @DatabaseNames=N'[SampleDatabase]', @SchemaNames=N'[dbo]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_ObjectInventory @CrossDatabaseRequestedInternal=0, @AnalyseModus='VOLL', @MaxZeilen=20000;
  EXEC monitor.USP_ObjectInventory @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ObjectInventory]
      @DatabaseNames                  nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @SchemaNames                    nvarchar(max)  = NULL
    , @SchemaNamePattern              nvarchar(4000) = NULL
    , @ObjectNames                    nvarchar(max)  = NULL
    , @ObjectNamePattern              nvarchar(4000) = NULL
    , @FullObjectNames                nvarchar(max)  = NULL
    , @ObjectType                     varchar(16)   = 'TABLE'
    , @AnalyseModus                   varchar(16)   = 'GEZIELT'
    , @MitIndizes                     bit           = 1
    , @MitSpaltenlisten               bit           = 1
    , @MaxDatenbanken                 int           = 16
    , @MaxZeilen                      int           = 5000
    , @LockTimeoutMs                  int           = 0
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
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
    IF @TableResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
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
    CREATE TABLE [#ObjectInventory_NameFilters]([FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ItemOrdinal] int NOT NULL,[NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ObjectInventory_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
    DECLARE @FilterStatus varchar(40)='AVAILABLE',@FilterError nvarchar(2048)=NULL,@CrossDatabaseRequested bit=0;
    EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=@SchemaNames,@ObjectNames=@ObjectNames,@FullObjectNames=@FullObjectNames,@IndexNames=NULL,@StatisticsNames=NULL,@ColumnNames=NULL,@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@FilterTable=N'#ObjectInventory_NameFilters';
    IF @FilterStatus='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='CROSS_DATABASE_DEEP',@StatusCode=@FilterStatus OUTPUT,@ErrorMessage=@FilterError OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#ObjectInventory_DatabaseCandidates';
    DECLARE @SchemaPredicateS nvarchar(max),@SchemaPredicateSch nvarchar(max),@ObjectPredicateO nvarchar(max),@FullObjectPredicateSO nvarchar(max),@IndexPredicateI nvarchar(max),@StatisticsPredicateSt nvarchar(max);
    SET @SchemaPredicateS=N' AND (NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] WHERE [FilterType]=''SCHEMA'') OR EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] [f] WHERE [f].[FilterType]=''SCHEMA'' AND [f].[NameValue]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @SchemaPredicateSch=REPLACE(@SchemaPredicateS,N'[s].[name]',N'[sch].[name]');
    SET @ObjectPredicateO=N' AND (NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] WHERE [FilterType]=''OBJECT'') OR EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] [f] WHERE [f].[FilterType]=''OBJECT'' AND [f].[NameValue]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @FullObjectPredicateSO=N' AND (NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] WHERE [FilterType]=''FULL_OBJECT'') OR EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] [f] WHERE [f].[FilterType]=''FULL_OBJECT'' AND ([f].[DatabaseName] IS NULL OR [f].[DatabaseName]=@pDatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS) AND ([f].[SchemaName] IS NULL OR [f].[SchemaName]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AND [f].[ObjectName]=[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @IndexPredicateI=N' AND (NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] WHERE [FilterType]=''INDEX'') OR EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] [f] WHERE [f].[FilterType]=''INDEX'' AND [f].[NameValue]=[i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    SET @StatisticsPredicateSt=N' AND (NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] WHERE [FilterType]=''STATISTICS'') OR EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters] [f] WHERE [f].[FilterType]=''STATISTICS'' AND [f].[NameValue]=[st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
    IF @SchemaPatternMode='LIKE' BEGIN SET @SchemaPredicateS+=N' AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';SET @SchemaPredicateSch+=N' AND [sch].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';END;
    IF @SchemaPatternMode IN('REGEX','REGEXI') BEGIN SET @SchemaPredicateS+=N' AND REGEXP_LIKE([s].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';SET @SchemaPredicateSch+=N' AND REGEXP_LIKE([sch].[name],N'''+REPLACE(@SchemaPatternValue,N'''',N'''''')+N''','''+@SchemaRegexFlags+N''')';END;
    IF @ObjectPatternMode='LIKE' SET @ObjectPredicateO+=N' AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @ObjectPatternMode IN('REGEX','REGEXI') SET @ObjectPredicateO+=N' AND REGEXP_LIKE([o].[name],N'''+REPLACE(@ObjectPatternValue,N'''',N'''''')+N''','''+@ObjectRegexFlags+N''')';
    IF @IndexPatternMode='LIKE' SET @IndexPredicateI+=N' AND [i].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @IndexPatternMode IN('REGEX','REGEXI') SET @IndexPredicateI+=N' AND REGEXP_LIKE([i].[name],N'''+REPLACE(@IndexPatternValue,N'''',N'''''')+N''','''+@IndexRegexFlags+N''')';
    IF @StatisticsPatternMode='LIKE' SET @StatisticsPredicateSt+=N' AND [st].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''' COLLATE SQL_Latin1_General_CP1_CS_AS';
    IF @StatisticsPatternMode IN('REGEX','REGEXI') SET @StatisticsPredicateSt+=N' AND REGEXP_LIKE([st].[name],N'''+REPLACE(@StatisticsPatternValue,N'''',N'''''')+N''','''+@StatisticsRegexFlags+N''')';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @EffectiveMaxDatenbanken bigint = CASE WHEN @MaxDatenbanken IS NULL OR @MaxDatenbanken=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxDatenbanken) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    SET @ObjectType = UPPER(LTRIM(RTRIM(COALESCE(@ObjectType,'TABLE'))));
    SET @AnalyseModus = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ObjectInventory';        PRINT N'@DatabaseNames: exakter Name oder bracket-aware Pipe-Liste; NULL = alle zulässigen Datenbanken; N'''' = ungültiger sicherer Default.';        PRINT N'@SystemdatenbankenEinbeziehen bit = 0: Systemdatenbanken einbeziehen.';        PRINT N'Exakte Listen und ...NamePattern sind gegenseitig exklusiv. Pattern: LIKE (Default/like:), regex: oder regexi:.';
        PRINT N'@MaxDatenbanken int = 16; @MaxZeilen int: harte Ergebnismengenbegrenzung.';
        PRINT N'@LockTimeoutMs int = 0: Metadatenzugriff wartet standardmäßig nicht auf Locks.';
        PRINT N'@PrintMeldungen bit = 1: strukturierte Warnungen zusätzlich in der Console.';
        PRINT N'Zweck: Objekt-, Größen-, Partitions-, Kompressions- und Indexinventar.';
        PRINT N'@ObjectType varchar(16) = TABLE: TABLE, VIEW oder ALLE.';
        PRINT N'@AnalyseModus varchar(16) = GEZIELT: GEZIELT benötigt Schema-/Objektfilter; VOLL prüft CATALOG_DEEP.';
        PRINT N'@MitIndizes bit = 1: 0 liefert nur Objektsummen.';
        PRINT N'@MitSpaltenlisten bit = 1: Key- und Include-Spaltenlisten ergänzen.';
        PRINT N'Beispiel: EXEC monitor.USP_ObjectInventory @DatabaseNames=N''[DWH]'', @ObjectNamePattern=N''like:Fact%'';';
        PRINT N'@Hilfe bit = 0: 1 zeigt diese Hilfe und führt keine Analyse aus.';
        RETURN;
    END;

    DECLARE @ModuleName sysname = N'USP_ObjectInventory';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @TotalRows bigint = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;

    CREATE TABLE [#ObjectInventory_DatabaseStatus]
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
    IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';END;
    IF @SchemaPatternValid=0 OR @ObjectPatternValid=0 OR @IndexPatternValid=0 OR @StatisticsPatternValid=0 OR (@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL) OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL) BEGIN SET @OverallStatus='INVALID_PARAMETER';SET @ErrorMessage=N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';END;
IF @MaxDatenbanken<0 OR @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter: @MaxDatenbanken, @MaxZeilen oder @LockTimeoutMs außerhalb des zulässigen Bereichs.';
    END


    IF @OverallStatus <> 'AVAILABLE'
    BEGIN
        INSERT [#ObjectInventory_DatabaseStatus]([DatabaseName], [StatusCode], [IsPartial], [RowCount], [RequiredPermission], [ErrorNumber], [ErrorMessage], [Detail])
        VALUES(@DatabaseName, @OverallStatus, 1, 0, NULL, NULL, @ErrorMessage, N'Keine Datenbankanalyse ausgeführt.');
        SET @IsPartial = 1;
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
    END;

    DECLARE @CatalogAllowed bit = 1;
    IF @AnalyseModus = 'VOLL'
        SELECT @CatalogAllowed = COALESCE(MAX(CONVERT(tinyint, [IsAllowed])), 0)
        FROM [monitor].[VW_AnalyseAccessCurrent]
        WHERE [AnalysisClass] = 'CATALOG_DEEP';

    CREATE TABLE [#ObjectInventory_Result]
    (
          [DatabaseName]                sysname         NOT NULL
        , [SchemaName]                  sysname         NOT NULL
        , [ObjectName]                  sysname         NOT NULL
        , [ObjectType]                  varchar(20)     NOT NULL
        , [ObjectId]                    int             NOT NULL
        , [IsMsShipped]                 bit             NOT NULL
        , [IsMemoryOptimized]           bit             NULL
        , [TemporalTypeDesc]            nvarchar(60)    NULL
        , [DurabilityDesc]              nvarchar(60)    NULL
        , [CreateDate]                  datetime        NULL
        , [ModifyDate]                  datetime        NULL
        , [ObjectRowCount]              bigint          NULL
        , [ObjectReservedMb]            decimal(19,2)   NULL
        , [ObjectUsedMb]                decimal(19,2)   NULL
        , [IndexId]                     int             NULL
        , [IndexName]                   sysname         NULL
        , [IndexTypeDesc]               nvarchar(60)    NULL
        , [IsUnique]                    bit             NULL
        , [IsPrimaryKey]                bit             NULL
        , [IsUniqueConstraint]          bit             NULL
        , [IsDisabled]                  bit             NULL
        , [IsHypothetical]              bit             NULL
        , [HasFilter]                   bit             NULL
        , [FilterDefinition]            nvarchar(max)   NULL
        , [FillFactor]                  tinyint         NULL
        , [AllowRowLocks]               bit             NULL
        , [AllowPageLocks]              bit             NULL
        , [OptimizeForSequentialKey]    bit             NULL
        , [DataSpaceName]               sysname         NULL
        , [PartitionCount]              int             NULL
        , [IndexRowCount]               bigint          NULL
        , [IndexReservedMb]             decimal(19,2)   NULL
        , [IndexUsedMb]                 decimal(19,2)   NULL
        , [MinCompressionDesc]          nvarchar(60)    NULL
        , [MaxCompressionDesc]          nvarchar(60)    NULL
        , [HasMixedCompression]         bit             NULL
        , [KeyColumns]                  nvarchar(max)   NULL
        , [IncludedColumns]             nvarchar(max)   NULL
    );

    IF @OverallStatus = 'AVAILABLE' AND @ObjectType NOT IN ('TABLE','VIEW','ALLE')
    BEGIN
        SET @OverallStatus='INVALID_PARAMETER';
        SET @ErrorMessage=N'@ObjectType muss TABLE, VIEW oder ALLE sein.';
        INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL);
    END
    ELSE IF @OverallStatus = 'AVAILABLE' AND @AnalyseModus NOT IN ('GEZIELT','VOLL')
    BEGIN
        SET @OverallStatus='INVALID_PARAMETER';
        SET @ErrorMessage=N'@AnalyseModus muss GEZIELT oder VOLL sein.';
        INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL);
    END
    ELSE IF @OverallStatus = 'AVAILABLE' AND @AnalyseModus='GEZIELT' AND NOT EXISTS(SELECT 1 FROM [#ObjectInventory_NameFilters]) AND @SchemaNamePattern IS NULL AND @ObjectNamePattern IS NULL
    BEGIN
        SET @OverallStatus='INVALID_PARAMETER';
        SET @ErrorMessage=N'GEZIELT erfordert eine exakte Namensliste, @FullObjectNames oder ein Schema-/Objekt-Pattern. Für einen vollständigen Kataloglauf @AnalyseModus=''VOLL'' verwenden.';
        INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL);
    END
    ELSE IF @OverallStatus = 'AVAILABLE' AND @AnalyseModus='VOLL' AND @CatalogAllowed=0
    BEGIN
        SET @OverallStatus='DENIED_GROUP';
        SET @ErrorMessage=N'CATALOG_DEEP ist für die vollständige Objektinventur nicht freigegeben.';
        INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DatabaseName,@OverallStatus,1,0,NULL,NULL,@ErrorMessage,NULL);
    END
    ELSE IF @OverallStatus = 'AVAILABLE'
    BEGIN
        DECLARE @DbId int, @DbName sysname, @Sql nvarchar(max), @Rows bigint;
        DECLARE dbcur CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId], [DatabaseName]
            FROM [#ObjectInventory_DatabaseCandidates];
        OPEN dbcur;
        FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            BEGIN TRY
                SET @Sql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + N'; USE ' + QUOTENAME(@DbName) + N';
;WITH PartitionBase AS
(
    SELECT [p].[object_id],[p].[index_id],COUNT_BIG(*) AS [PartitionCount],SUM([p].[rows]) AS [IndexRowCount],
           MIN([p].[data_compression_desc]) AS [MinCompressionDesc],
           MAX([p].[data_compression_desc]) AS [MaxCompressionDesc]
    FROM sys.partitions AS [p] WITH (NOLOCK)
    GROUP BY [p].[object_id],[p].[index_id]
),
AllocationAgg AS
(
    SELECT [p].[object_id],[p].[index_id],
           SUM(CONVERT(bigint,[au].[total_pages])) AS [ReservedPages],
           SUM(CONVERT(bigint,[au].[used_pages])) AS [UsedPages]
    FROM sys.partitions AS [p] WITH (NOLOCK)
    LEFT JOIN sys.allocation_units AS [au] WITH (NOLOCK)
      ON [au].[container_id] = CASE WHEN [au].[type] = 2 THEN [p].[partition_id] ELSE [p].[hobt_id] END
    GROUP BY [p].[object_id],[p].[index_id]
),
IndexAgg AS
(
    SELECT [pb].[object_id],[pb].[index_id],[pb].[PartitionCount],[pb].[IndexRowCount],
           [aa].[ReservedPages],[aa].[UsedPages],[pb].[MinCompressionDesc],[pb].[MaxCompressionDesc]
    FROM PartitionBase AS [pb]
    LEFT JOIN AllocationAgg AS [aa] ON [aa].[object_id]=[pb].[object_id] AND [aa].[index_id]=[pb].[index_id]
),
ObjectAgg AS
(
    SELECT [ia].[object_id],
           SUM(CASE WHEN [ia].[index_id] IN (0,1) THEN [ia].[IndexRowCount] ELSE 0 END) AS [ObjectRowCount],
           SUM([ia].[ReservedPages]) AS [ReservedPages],
           SUM([ia].[UsedPages]) AS [UsedPages]
    FROM IndexAgg AS [ia]
    GROUP BY [ia].[object_id]
)
INSERT #ObjectInventory_Result
SELECT TOP (@pMaxRows)
       @pDatabaseName, [s].[name], [o].[name],
       CASE [o].[type] WHEN ''U'' THEN ''TABLE'' WHEN ''V'' THEN ''VIEW'' ELSE [o].[type_desc] END,
       [o].[object_id],[o].[is_ms_shipped],[t].[is_memory_optimized],[t].[temporal_type_desc],[t].[durability_desc],
       [o].[create_date],[o].[modify_date],
       [oa].[ObjectRowCount],CONVERT(decimal(19,2),[oa].[ReservedPages]/128.0),CONVERT(decimal(19,2),[oa].[UsedPages]/128.0),
       CASE WHEN @pMitIndizes=1 THEN [i].[index_id] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[name] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[type_desc] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[is_unique] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[is_primary_key] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[is_unique_constraint] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[is_disabled] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[is_hypothetical] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[has_filter] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[filter_definition] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[fill_factor] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[allow_row_locks] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[allow_page_locks] END,
       CASE WHEN @pMitIndizes=1 THEN [i].[optimize_for_sequential_key] END,
       CASE WHEN @pMitIndizes=1 THEN [ds].[name] END,
       CASE WHEN @pMitIndizes=1 THEN CONVERT(int,[ia].[PartitionCount]) END,
       CASE WHEN @pMitIndizes=1 THEN [ia].[IndexRowCount] END,
       CASE WHEN @pMitIndizes=1 THEN CONVERT(decimal(19,2),[ia].[ReservedPages]/128.0) END,
       CASE WHEN @pMitIndizes=1 THEN CONVERT(decimal(19,2),[ia].[UsedPages]/128.0) END,
       CASE WHEN @pMitIndizes=1 THEN [ia].[MinCompressionDesc] END,
       CASE WHEN @pMitIndizes=1 THEN [ia].[MaxCompressionDesc] END,
       CASE WHEN @pMitIndizes=1 THEN CONVERT(bit,CASE WHEN [ia].[MinCompressionDesc]<>[ia].[MaxCompressionDesc] THEN 1 ELSE 0 END) END,
       CASE WHEN @pMitIndizes=1 AND @pMitSpaltenlisten=1 THEN [kc].[KeyColumns] END,
       CASE WHEN @pMitIndizes=1 AND @pMitSpaltenlisten=1 THEN [ic].[IncludedColumns] END
FROM sys.objects AS [o] WITH (NOLOCK)
JOIN sys.schemas AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
LEFT JOIN sys.tables AS [t] WITH (NOLOCK) ON [t].[object_id]=[o].[object_id]
LEFT JOIN ObjectAgg AS [oa] ON [oa].[object_id]=[o].[object_id]
LEFT JOIN sys.indexes AS [i] WITH (NOLOCK) ON [i].[object_id]=[o].[object_id] AND @pMitIndizes=1
LEFT JOIN IndexAgg AS [ia] ON [ia].[object_id]=[i].[object_id] AND [ia].[index_id]=[i].[index_id]
LEFT JOIN sys.data_spaces AS [ds] WITH (NOLOCK) ON [ds].[data_space_id]=[i].[data_space_id]
OUTER APPLY
(
    SELECT STUFF((SELECT N'', ''+QUOTENAME([c].[name])+CASE WHEN [ic2].[is_descending_key]=1 THEN N'' DESC'' ELSE N'''' END
                  FROM sys.index_columns AS [ic2] WITH (NOLOCK)
                  JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[ic2].[object_id] AND [c].[column_id]=[ic2].[column_id]
                  WHERE @pMitIndizes=1 AND @pMitSpaltenlisten=1 AND [ic2].[object_id]=[i].[object_id] AND [ic2].[index_id]=[i].[index_id] AND [ic2].[key_ordinal]>0
                  ORDER BY [ic2].[key_ordinal] FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,N'''') AS [KeyColumns]
) AS [kc]
OUTER APPLY
(
    SELECT STUFF((SELECT N'', ''+QUOTENAME([c].[name])
                  FROM sys.index_columns AS [ic2] WITH (NOLOCK)
                  JOIN sys.columns AS [c] WITH (NOLOCK) ON [c].[object_id]=[ic2].[object_id] AND [c].[column_id]=[ic2].[column_id]
                  WHERE @pMitIndizes=1 AND @pMitSpaltenlisten=1 AND [ic2].[object_id]=[i].[object_id] AND [ic2].[index_id]=[i].[index_id] AND [ic2].[is_included_column]=1
                  ORDER BY [ic2].[index_column_id] FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,N'''') AS [IncludedColumns]
) AS [ic]
WHERE [o].[type] IN (''U'',''V'')
  AND (@pObjectType=''ALLE'' OR (@pObjectType=''TABLE'' AND [o].[type]=''U'') OR (@pObjectType=''VIEW'' AND [o].[type]=''V''))
'+@SchemaPredicateS+@ObjectPredicateO+@FullObjectPredicateSO+N'
  AND (@pMitIndizes=0 OR [o].[type]=''V'' OR [i].[index_id] IS NOT NULL)
ORDER BY [oa].[ReservedPages] DESC,[o].[object_id],[i].[index_id]
OPTION (MAXDOP 1, RECOMPILE);';
                EXEC [sys].[sp_executesql] @Sql,
                    N'@pDatabaseName sysname,@pMaxRows bigint,@pObjectType varchar(16),@pSchemaLike nvarchar(256),@pObjectLike nvarchar(256),@pMitIndizes bit,@pMitSpaltenlisten bit',
                    @pDatabaseName=@DbName,@pMaxRows=@EffectiveMaxZeilen,@pObjectType=@ObjectType,@pSchemaLike=@SchemaNameLike,@pObjectLike=@ObjectNameLike,@pMitIndizes=@MitIndizes,@pMitSpaltenlisten=@MitSpaltenlisten;
                SELECT @Rows=COUNT_BIG(*) FROM [#ObjectInventory_Result] WHERE [DatabaseName]=@DbName;
                INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DbName,'AVAILABLE',0,@Rows,N'Metadata Visibility / VIEW DEFINITION für vollständige Metadaten',NULL,NULL,N'Systemkatalog erfolgreich gelesen; unsichtbare Objekte werden nicht als Fehler gewertet.');
            END TRY
            BEGIN CATCH
                INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DbName,CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN (207,208,4121) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,1,0,N'Metadata Visibility / VIEW DEFINITION',ERROR_NUMBER(),ERROR_MESSAGE(),N'Datenbankfehler isoliert.');
            END CATCH;
            FETCH NEXT FROM dbcur INTO @DbId,@DbName;
        END;
        CLOSE dbcur; DEALLOCATE dbcur;
        IF NOT EXISTS(SELECT 1 FROM [#ObjectInventory_DatabaseStatus])
            INSERT [#ObjectInventory_DatabaseStatus] VALUES(@DatabaseName,'DATABASE_UNAVAILABLE',1,0,NULL,NULL,N'Keine sichtbare Online-Zieldatenbank gefunden.',NULL);
    END;

    

    SELECT @TotalRows = COUNT_BIG(*) FROM [#ObjectInventory_Result];

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        IF EXISTS (SELECT 1 FROM [#ObjectInventory_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
        BEGIN
            SET @OverallStatus = CASE WHEN @TotalRows > 0 THEN 'PARTIAL' ELSE (SELECT TOP (1) [StatusCode] FROM [#ObjectInventory_DatabaseStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE') ORDER BY [DatabaseName]) END;
            SET @IsPartial = 1;
        END
        ELSE IF EXISTS (SELECT 1 FROM [#ObjectInventory_DatabaseStatus] WHERE [StatusCode] IN ('AVAILABLE_LIMITED','SKIPPED','NOT_APPLICABLE'))
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
        SELECT [DatabaseName],[StatusCode],[IsPartial],[RowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[Detail] FROM [#ObjectInventory_DatabaseStatus] ORDER BY [DatabaseName];
        IF @ResultSetArtNormalisiert='RAW' SELECT * FROM [#ObjectInventory_Result] ORDER BY [ObjectReservedMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId]; ELSE SELECT N'Objekt-/Indexinventar' [Ergebnis],[r].* FROM [#ObjectInventory_Result] [r] ORDER BY [ObjectReservedMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId];
    END;
    IF @JsonErzeugen=1 BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT @ModuleName [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@OverallStatus [statusCode],@IsPartial [isPartial],@TotalRows [rowCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonDatabaseStatus nvarchar(max)=(SELECT * FROM [#ObjectInventory_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @JsonData1 nvarchar(max)=(SELECT * FROM [#ObjectInventory_Result] ORDER BY [ObjectReservedMb] DESC,[DatabaseName],[SchemaName],[ObjectName],[IndexId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@JsonMeta,N'{}'),N',"objects":',COALESCE(@JsonData1,N'[]'),N',"databaseStatus":',COALESCE(@JsonDatabaseStatus,N'[]'),N'}');
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ObjectInventory_Result'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
