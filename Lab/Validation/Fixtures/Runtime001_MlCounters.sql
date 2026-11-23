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
GO
