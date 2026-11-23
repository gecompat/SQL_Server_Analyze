SET NOCOUNT ON;

DECLARE @Json nvarchar(max),@Return int,@PythonLanguage nvarchar(128),
        @ExpectedRows bigint,@LockTimeoutBefore int=@@LOCK_TIMEOUT;

IF NOT EXISTS(SELECT 1 FROM sys.configurations
              WHERE [name]=N'external scripts enabled' AND CONVERT(int,[value_in_use])=1)
    THROW 56977,N'The owned Python fixture did not enable external scripts.',1;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExamplePythonNativeBefore]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=N'Python';

SELECT @ExpectedRows=COUNT_BIG(*),@PythonLanguage=MIN([LanguageName]) FROM [#ExamplePythonNativeBefore];
IF @ExpectedRows=0
   OR (SELECT COUNT(DISTINCT [LanguageName]) FROM [#ExamplePythonNativeBefore])<>1
   OR NOT EXISTS(SELECT 1 FROM [#ExamplePythonNativeBefore] WHERE [CounterValue]>0)
    THROW 56978,N'No positive native cumulative Python counter was visible after the owned probe.',1;

EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=N'[ExampleExternalRuntimeProbe]',@LanguageNames=@PythonLanguage,
     @SampleSeconds=0,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @JsonErzeugen=1,@Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
    THROW 56979,N'Analyze did not return valid Python evidence and preserve the caller lock timeout.',1;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExamplePythonNativeAfter]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=N'Python';

IF (SELECT COUNT_BIG(*) FROM [#ExamplePythonNativeAfter])<>@ExpectedRows
   OR EXISTS(SELECT * FROM [#ExamplePythonNativeAfter] EXCEPT SELECT * FROM [#ExamplePythonNativeBefore])
   OR EXISTS(SELECT * FROM [#ExamplePythonNativeBefore] EXCEPT SELECT * FROM [#ExamplePythonNativeAfter])
    THROW 56980,N'Native Python counters changed while the read-only comparison was running.',1;

SELECT [LanguageName] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [CounterName] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       [CounterValue],[CounterDelta],[DeltaStatus]
INTO [#ExamplePythonJsonCounters]
FROM OPENJSON(@Json,N'$.executionStats') WITH
(
    [LanguageName] nvarchar(128),[CounterName] nvarchar(256),[CounterValue] bigint,
    [CounterDelta] bigint,[DeltaStatus] varchar(40)
);

IF (SELECT COUNT_BIG(*) FROM [#ExamplePythonJsonCounters])<>@ExpectedRows
   OR EXISTS(SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExamplePythonJsonCounters]
             EXCEPT SELECT * FROM [#ExamplePythonNativeBefore])
   OR EXISTS(SELECT * FROM [#ExamplePythonNativeBefore] EXCEPT
             SELECT [LanguageName],[CounterName],[CounterValue] FROM [#ExamplePythonJsonCounters])
   OR EXISTS(SELECT 1 FROM [#ExamplePythonJsonCounters]
             WHERE [CounterDelta] IS NOT NULL OR ISNULL([DeltaStatus],'')<>'NOT_SAMPLED')
    THROW 56981,N'Analyze cumulative Python counters differ from the stable native snapshot.',1;

IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH
    ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint)
    WHERE [SourceCode]='EXECUTION_STATS_T1' AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]=@ExpectedRows)<>1
    THROW 56982,N'Analyze did not report successful reading of the positive Python counter source.',1;
GO
