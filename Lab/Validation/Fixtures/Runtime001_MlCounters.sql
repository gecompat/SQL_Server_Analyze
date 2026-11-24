SET NOCOUNT ON;
IF @FixtureLanguage IS NULL OR @FixtureLanguage NOT IN (N'Python',N'R')
    THROW 56983,N'Unexpected machine-learning runtime fixture language.',1;

DECLARE @Json nvarchar(max),@Return int,@ObservedLanguage nvarchar(128),
        @ExpectedRows bigint,@LockTimeoutBefore int=@@LOCK_TIMEOUT;

IF NOT EXISTS(SELECT 1 FROM sys.configurations
              WHERE [name]=N'external scripts enabled' AND CONVERT(int,[value_in_use])=1)
    THROW 56977,N'The owned runtime fixture did not enable external scripts.',1;

IF @FixtureLanguage=N'R'
BEGIN
    EXEC sys.sp_execute_external_script
        @language=N'R',
        @script=N'
result <- RevoScaleR::rxSummary(~ProbeValue, data=InputDataSet, summaryStats=c("Mean","ValidObs"), reportProgress=0)
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$Mean), 42)))
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$ValidObs), 2)))
OutputDataSet <- data.frame(MeanValue=as.integer(result$sDataFrame$Mean))',
        @input_data_1=N'SELECT CAST(41 AS int) AS ProbeValue UNION ALL SELECT CAST(43 AS int)'
        WITH RESULT SETS ((MeanValue int NOT NULL));
END;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExampleMlNativeBefore]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=@FixtureLanguage;

SELECT @ExpectedRows=COUNT_BIG(*),@ObservedLanguage=MIN([LanguageName]) FROM [#ExampleMlNativeBefore];
IF @ExpectedRows=0
   OR (SELECT COUNT(DISTINCT [LanguageName]) FROM [#ExampleMlNativeBefore])<>1
   OR NOT EXISTS(SELECT 1 FROM [#ExampleMlNativeBefore] WHERE [CounterValue]>0)
    THROW 56978,N'No positive native cumulative language counter was visible after the owned probe.',1;

EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=N'[ExampleExternalRuntimeProbe]',@LanguageNames=@ObservedLanguage,
     @SampleSeconds=0,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @JsonErzeugen=1,@Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
    THROW 56979,N'Analyze did not return valid machine-learning evidence and preserve the caller lock timeout.',1;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExampleMlNativeAfter]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=@FixtureLanguage;

IF (SELECT COUNT_BIG(*) FROM [#ExampleMlNativeAfter])<>@ExpectedRows
   OR EXISTS(SELECT * FROM [#ExampleMlNativeAfter] EXCEPT SELECT * FROM [#ExampleMlNativeBefore])
   OR EXISTS(SELECT * FROM [#ExampleMlNativeBefore] EXCEPT SELECT * FROM [#ExampleMlNativeAfter])
    THROW 56980,N'Native machine-learning counters changed while the read-only comparison was running.',1;

SELECT [LanguageName] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [CounterName] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       [CounterValue],[CounterDelta],[DeltaStatus]
INTO [#ExampleMlJsonCounters]
FROM OPENJSON(@Json,N'$.executionStats') WITH
(
    [LanguageName] nvarchar(128),[CounterName] nvarchar(256),[CounterValue] bigint,
    [CounterDelta] bigint,[DeltaStatus] varchar(40)
);

IF (SELECT COUNT_BIG(*) FROM [#ExampleMlJsonCounters])<>@ExpectedRows
   OR EXISTS(SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExampleMlJsonCounters]
             EXCEPT SELECT * FROM [#ExampleMlNativeBefore])
   OR EXISTS(SELECT * FROM [#ExampleMlNativeBefore] EXCEPT
             SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExampleMlJsonCounters])
   OR EXISTS(SELECT 1 FROM [#ExampleMlJsonCounters]
             WHERE [CounterDelta] IS NOT NULL OR ISNULL([DeltaStatus],'')<>'NOT_SAMPLED')
    THROW 56981,N'Analyze cumulative machine-learning counters differ from the stable native snapshot.',1;

IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH
    ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint)
    WHERE [SourceCode]='EXECUTION_STATS_T1' AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]=@ExpectedRows)<>1
    THROW 56982,N'Analyze did not report successful reading of the positive machine-learning counter source.',1;

-- Die eigene Instanz hat zwischen den beiden Messpunkten keine weitere Script-Ausführung.
SET @Json=NULL;
EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=N'[ExampleExternalRuntimeProbe]',@LanguageNames=@ObservedLanguage,
     @SampleSeconds=1,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @JsonErzeugen=1,@Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
    THROW 57020,N'The sampled runtime call did not preserve its output and caller state.',1;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExampleMlNativeAfterSample]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=@FixtureLanguage;

IF (SELECT COUNT_BIG(*) FROM [#ExampleMlNativeAfterSample])<>@ExpectedRows
   OR EXISTS(SELECT * FROM [#ExampleMlNativeAfterSample] EXCEPT SELECT * FROM [#ExampleMlNativeAfter])
   OR EXISTS(SELECT * FROM [#ExampleMlNativeAfter] EXCEPT SELECT * FROM [#ExampleMlNativeAfterSample])
    THROW 57021,N'The native counters changed across the owned sample window.',1;

TRUNCATE TABLE [#ExampleMlJsonCounters];
INSERT [#ExampleMlJsonCounters]([LanguageName],[CounterName],[CounterValue],[CounterDelta],[DeltaStatus])
SELECT [LanguageName],[CounterName],[CounterValue],[CounterDelta],[DeltaStatus]
FROM OPENJSON(@Json,N'$.executionStats') WITH
(
    [LanguageName] nvarchar(128),[CounterName] nvarchar(256),[CounterValue] bigint,
    [CounterDelta] bigint,[DeltaStatus] varchar(40)
);

IF (SELECT COUNT_BIG(*) FROM [#ExampleMlJsonCounters])<>@ExpectedRows
   OR EXISTS(SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExampleMlJsonCounters]
             EXCEPT SELECT * FROM [#ExampleMlNativeAfterSample])
   OR EXISTS(SELECT * FROM [#ExampleMlNativeAfterSample] EXCEPT
             SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExampleMlJsonCounters])
   OR EXISTS(SELECT 1 FROM [#ExampleMlJsonCounters]
             WHERE ISNULL([CounterDelta],-1)<>0 OR ISNULL([DeltaStatus],'')<>'DELTA_AVAILABLE')
    THROW 57022,N'Stable native counters did not yield the expected zero deltas.',1;

DECLARE @SampleT1 datetime2(3),@SampleT2 datetime2(3),@SampleSourceCount int,@DistinctSampleSources int;
SELECT @SampleT1=MAX(CASE WHEN [SourceCode]='EXECUTION_STATS_T1' THEN [ReadAtUtc] END),
       @SampleT2=MAX(CASE WHEN [SourceCode]='EXECUTION_STATS_T2' THEN [ReadAtUtc] END),
       @SampleSourceCount=COUNT(*),@DistinctSampleSources=COUNT(DISTINCT [SourceCode])
FROM OPENJSON(@Json,N'$.sourceStatus') WITH
    ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint,[ReadAtUtc] datetime2(3))
WHERE [SourceCode] IN ('EXECUTION_STATS_T1','EXECUTION_STATS_T2')
  AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]=@ExpectedRows;

IF @SampleSourceCount<>2 OR @DistinctSampleSources<>2 OR @SampleT1 IS NULL OR @SampleT2 IS NULL OR @SampleT2<=@SampleT1
    THROW 57023,N'The two successful runtime measurement points were not reported in order.',1;

-- Only the R lab starts a separate owned worker for the positive-delta case.
IF @FixtureLanguage=N'R'
BEGIN
    -- Publish the actual sampler session to the separate connection in this owned lab.
    CREATE TABLE [##ExampleRuntime001RCounterSampler]([SamplerSessionId] smallint NOT NULL);
    INSERT [##ExampleRuntime001RCounterSampler]([SamplerSessionId]) VALUES (@@SPID);
    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
         @DatabaseNames=N'[ExampleExternalRuntimeProbe]',@LanguageNames=@ObservedLanguage,
         @SampleSeconds=15,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
         @JsonErzeugen=1,@Json=@Json OUTPUT;

    IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
        THROW 57024,N'The positive sample did not preserve its output and caller lock timeout.',1;

    SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
           [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
           CONVERT(bigint,[counter_value]) AS [CounterValue]
    INTO [#ExampleMlNativePositiveAfter]
    FROM sys.dm_external_script_execution_stats
    WHERE [language] COLLATE Latin1_General_100_CI_AS=@FixtureLanguage;

    SELECT [a].[LanguageName],[a].[CounterName],[a].[CounterValue],
           [a].[CounterValue]-[b].[CounterValue] AS [CounterDelta]
    INTO [#ExampleMlExpectedPositiveDeltas]
    FROM [#ExampleMlNativePositiveAfter] AS [a]
    INNER JOIN [#ExampleMlNativeAfterSample] AS [b]
      ON [a].[LanguageName]=[b].[LanguageName] AND [a].[CounterName]=[b].[CounterName];

    DECLARE @AfterRows bigint=(SELECT COUNT_BIG(*) FROM [#ExampleMlNativePositiveAfter]),
            @JoinedRows bigint=(SELECT COUNT_BIG(*) FROM [#ExampleMlExpectedPositiveDeltas]),
            @NegativeRows bigint=(SELECT COUNT_BIG(*) FROM [#ExampleMlExpectedPositiveDeltas] WHERE [CounterDelta]<0),
            @PositiveRows bigint=(SELECT COUNT_BIG(*) FROM [#ExampleMlExpectedPositiveDeltas] WHERE [CounterDelta]>0);
    IF @AfterRows<>@ExpectedRows OR @JoinedRows<>@ExpectedRows OR @NegativeRows>0 OR @PositiveRows=0
    BEGIN
        DECLARE @SampleError nvarchar(2048)=CONCAT(N'Native R sample: before=',@ExpectedRows,N'; after=',@AfterRows,
            N'; matched=',@JoinedRows,N'; negative=',@NegativeRows,N'; positive=',@PositiveRows,N'.');
        THROW 57025,@SampleError,1;
    END;

    TRUNCATE TABLE [#ExampleMlJsonCounters];
    INSERT [#ExampleMlJsonCounters]([LanguageName],[CounterName],[CounterValue],[CounterDelta],[DeltaStatus])
    SELECT [LanguageName],[CounterName],[CounterValue],[CounterDelta],[DeltaStatus]
    FROM OPENJSON(@Json,N'$.executionStats') WITH
    (
        [LanguageName] nvarchar(128),[CounterName] nvarchar(256),[CounterValue] bigint,
        [CounterDelta] bigint,[DeltaStatus] varchar(40)
    );

    IF (SELECT COUNT_BIG(*) FROM [#ExampleMlJsonCounters])<>@ExpectedRows
       OR EXISTS(SELECT [LanguageName],[CounterName],[CounterValue],[CounterDelta] FROM [#ExampleMlJsonCounters]
                 EXCEPT SELECT * FROM [#ExampleMlExpectedPositiveDeltas])
       OR EXISTS(SELECT * FROM [#ExampleMlExpectedPositiveDeltas]
                 EXCEPT SELECT [LanguageName],[CounterName],[CounterValue],[CounterDelta] FROM [#ExampleMlJsonCounters])
       OR EXISTS(SELECT 1 FROM [#ExampleMlJsonCounters] WHERE ISNULL([DeltaStatus],'')<>'DELTA_AVAILABLE')
        THROW 57026,N'The positive sample did not match the independently read native R counters and deltas.',1;

    SELECT @SampleT1=MAX(CASE WHEN [SourceCode]='EXECUTION_STATS_T1' THEN [ReadAtUtc] END),
           @SampleT2=MAX(CASE WHEN [SourceCode]='EXECUTION_STATS_T2' THEN [ReadAtUtc] END),
           @SampleSourceCount=COUNT(*),@DistinctSampleSources=COUNT(DISTINCT [SourceCode])
    FROM OPENJSON(@Json,N'$.sourceStatus') WITH
        ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint,[ReadAtUtc] datetime2(3))
    WHERE [SourceCode] IN ('EXECUTION_STATS_T1','EXECUTION_STATS_T2')
      AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]=@ExpectedRows;

    IF @SampleSourceCount<>2 OR @DistinctSampleSources<>2 OR @SampleT1 IS NULL OR @SampleT2 IS NULL OR @SampleT2<=@SampleT1
        THROW 57027,N'The positive sample did not report two successful ordered measurement points.',1;

    DROP TABLE [##ExampleRuntime001RCounterSampler];

    -- Change only an owned pool on this disposable instance during a separate sample.
    DECLARE @GovernorWasEnabled bit=(SELECT [is_enabled] FROM sys.resource_governor_configuration),
            @PoolId int,@PoolVersion bigint,@PoolEpoch datetime,@CurrentPoolEpoch datetime;
    IF @GovernorWasEnabled IS NULL
       OR EXISTS(SELECT 1 FROM sys.resource_governor_external_resource_pools WHERE [name]=N'ExampleRuntime001Epoch')
        THROW 57030,N'The external-pool epoch fixture requires an unused pool on the owned instance.',1;

    CREATE EXTERNAL RESOURCE POOL [ExampleRuntime001Epoch] WITH (MAX_PROCESSES=2);
    ALTER RESOURCE GOVERNOR RECONFIGURE;

    SELECT @PoolId=[external_pool_id],@PoolVersion=[pool_version],@PoolEpoch=[statistics_start_time]
    FROM sys.dm_resource_governor_external_resource_pools
    WHERE [name]=N'ExampleRuntime001Epoch' AND [max_processes]=2;
    IF @PoolId IS NULL OR @PoolVersion IS NULL OR @PoolEpoch IS NULL
        THROW 57031,N'The owned external pool was not visible with its initial native configuration.',1;

    CREATE TABLE [##ExampleRuntime001RPoolEpochSampler]([SamplerSessionId] smallint NOT NULL);
    INSERT [##ExampleRuntime001RPoolEpochSampler]([SamplerSessionId]) VALUES (@@SPID);
    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
         @DatabaseNames=N'[ExampleExternalRuntimeProbe]',@LanguageNames=@ObservedLanguage,
         @SampleSeconds=15,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
         @JsonErzeugen=1,@Json=@Json OUTPUT;

    IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
        THROW 57032,N'The external-pool sample did not preserve its output and caller lock timeout.',1;

    SELECT @CurrentPoolEpoch=[statistics_start_time]
    FROM sys.dm_resource_governor_external_resource_pools
    WHERE [external_pool_id]=@PoolId AND [name]=N'ExampleRuntime001Epoch' AND [max_processes]=1
      AND ([pool_version]<>@PoolVersion OR [statistics_start_time]<>@PoolEpoch);
    IF @CurrentPoolEpoch IS NULL
        THROW 57033,N'The owned external pool did not report a native version or statistics-epoch transition.',1;

    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.externalPools') WITH ([ExternalPoolId] int)
        WHERE [ExternalPoolId]=@PoolId)<>1
       OR NOT EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json,N'$.externalPools') WITH
           (
               [ExternalPoolId] int,[PoolName] nvarchar(128),[MaxProcesses] int,[StatisticsStartTime] datetime,
               [SampleSeconds] decimal(19,6),[DeltaStatus] varchar(40),
               [CpuKernelDelta] bigint,[CpuUserDelta] bigint,[ReadIoDelta] bigint,[WriteIoDelta] bigint
           )
           WHERE [ExternalPoolId]=@PoolId AND [PoolName]=N'ExampleRuntime001Epoch' AND [MaxProcesses]=1
             AND [StatisticsStartTime]=@CurrentPoolEpoch AND [SampleSeconds]>0 AND [DeltaStatus]='RESET_BOUNDARY'
             AND [CpuKernelDelta] IS NULL AND [CpuUserDelta] IS NULL AND [ReadIoDelta] IS NULL AND [WriteIoDelta] IS NULL
       )
        THROW 57034,N'The native epoch transition did not bind to a RESET_BOUNDARY with four suppressed deltas.',1;

    SELECT @SampleT1=MAX(CASE WHEN [SourceCode]='EXTERNAL_POOLS_T1' THEN [ReadAtUtc] END),
           @SampleT2=MAX(CASE WHEN [SourceCode]='EXTERNAL_POOLS_T2' THEN [ReadAtUtc] END),
           @SampleSourceCount=COUNT(*),@DistinctSampleSources=COUNT(DISTINCT [SourceCode])
    FROM OPENJSON(@Json,N'$.sourceStatus') WITH
        ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint,[ReadAtUtc] datetime2(3))
    WHERE [SourceCode] IN ('EXTERNAL_POOLS_T1','EXTERNAL_POOLS_T2')
      AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]>=1;
    IF @SampleSourceCount<>2 OR @DistinctSampleSources<>2 OR @SampleT1 IS NULL OR @SampleT2 IS NULL OR @SampleT2<=@SampleT1
        THROW 57035,N'The external-pool transition did not have two successful ordered native reads.',1;

    -- Use a nonmatching language and choose the boundary from the unbounded control.
    DECLARE @FixtureOnlyPoolLimit int,@FixturePoolCount int,@AddedPoolCount int=0,
            @PoolFixtureName sysname,@PoolFixtureDdl nvarchar(300),
            @NoFixtureLanguage nvarchar(128)=N'[ExampleRuntime001NoSuchLanguage]';
    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
         @DatabaseNames=N'[ExampleAnalyzeRuntime]',@LanguageNames=@NoFixtureLanguage,
         @NurProblematisch=1,@SampleSeconds=0,@MaxZeilen=0,@ResultSetArt='NONE',
         @PrintMeldungen=0,@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
        THROW 57037,N'The unbounded pool-only control could not be read.',1;

    SELECT @FixtureOnlyPoolLimit=MAX([Counts].[RowCount])
    FROM (VALUES (1),( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.findings')) ),
                   ( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.languages')) ),
                   ( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.libraries')) ),
                   ( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.activeRequests')) ),
                   ( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.executionStats')) ),
                   ( (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.performanceCounters')) )) AS [Counts]([RowCount]);
    SELECT @FixturePoolCount=COUNT(*) FROM sys.dm_resource_governor_external_resource_pools;
    IF @FixturePoolCount<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.externalPools'))
       OR @FixtureOnlyPoolLimit>=64 OR @FixtureOnlyPoolLimit-@FixturePoolCount>=12
        THROW 57038,N'The pool-only control did not provide a bounded native threshold.',1;

    WHILE @FixturePoolCount+@AddedPoolCount<=@FixtureOnlyPoolLimit
    BEGIN
        SET @AddedPoolCount+=1;
        SET @PoolFixtureName=CONCAT(N'ExampleRuntime001Limit',@AddedPoolCount);
        IF EXISTS(SELECT 1 FROM sys.resource_governor_external_resource_pools WHERE [name]=@PoolFixtureName)
            THROW 57039,N'The pool-only control encountered an existing fixture name.',1;
        SET @PoolFixtureDdl=N'CREATE EXTERNAL RESOURCE POOL '+QUOTENAME(@PoolFixtureName)+N';';
        EXEC sys.sp_executesql @PoolFixtureDdl;
    END;
    IF @AddedPoolCount>0 ALTER RESOURCE GOVERNOR RECONFIGURE;

    -- Re-read all resultsets after provisioning so an unrelated resultset cannot explain the warning.
    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
         @DatabaseNames=N'[ExampleAnalyzeRuntime]',@LanguageNames=@NoFixtureLanguage,
         @NurProblematisch=1,@SampleSeconds=0,@MaxZeilen=0,@ResultSetArt='NONE',
         @PrintMeldungen=0,@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.externalPools'))<>@FixturePoolCount+@AddedPoolCount
       OR @FixturePoolCount+@AddedPoolCount<=@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.findings'))>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.languages'))>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.libraries'))>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.activeRequests'))>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.executionStats'))>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.performanceCounters'))>@FixtureOnlyPoolLimit
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH ([WarningCode] varchar(64))
                 WHERE [WarningCode]='RESULTSET_TRUNCATED')
        THROW 57040,N'The unbounded control did not isolate truncation to the external-pool resultset.',1;

    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
         @DatabaseNames=N'[ExampleAnalyzeRuntime]',@LanguageNames=@NoFixtureLanguage,
         @NurProblematisch=1,@SampleSeconds=0,@MaxZeilen=@FixtureOnlyPoolLimit,@ResultSetArt='NONE',
         @PrintMeldungen=0,@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.externalPools'))<>@FixtureOnlyPoolLimit
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings') WITH ([WarningCode] varchar(64))
           WHERE [WarningCode]='RESULTSET_TRUNCATED')<>1
        THROW 57041,N'A pool-only truncation did not return exactly one warning.',1;

    WHILE @AddedPoolCount>0
    BEGIN
        SET @PoolFixtureName=CONCAT(N'ExampleRuntime001Limit',@AddedPoolCount);
        SET @PoolFixtureDdl=N'DROP EXTERNAL RESOURCE POOL '+QUOTENAME(@PoolFixtureName)+N';';
        EXEC sys.sp_executesql @PoolFixtureDdl;
        SET @AddedPoolCount-=1;
    END;

    DROP TABLE [##ExampleRuntime001RPoolEpochSampler];
    DROP EXTERNAL RESOURCE POOL [ExampleRuntime001Epoch];
    ALTER RESOURCE GOVERNOR RECONFIGURE;
    IF @GovernorWasEnabled=0 ALTER RESOURCE GOVERNOR DISABLE;
    IF EXISTS(SELECT 1 FROM sys.resource_governor_external_resource_pools WHERE [name]=N'ExampleRuntime001Epoch')
       OR EXISTS(SELECT 1 FROM sys.dm_resource_governor_external_resource_pools WHERE [name]=N'ExampleRuntime001Epoch')
       OR EXISTS(SELECT 1 FROM sys.resource_governor_external_resource_pools WHERE [name] LIKE N'ExampleRuntime001Limit%')
       OR EXISTS(SELECT 1 FROM sys.dm_resource_governor_external_resource_pools WHERE [name] LIKE N'ExampleRuntime001Limit%')
       OR NOT EXISTS(SELECT 1 FROM sys.resource_governor_configuration WHERE [is_enabled]=@GovernorWasEnabled)
        THROW 57036,N'The owned pools or the original governor enabled state were not restored.',1;
END;
GO
