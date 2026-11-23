SET NOCOUNT ON;

-- This connection is in the same owned CI instance as the marked sampler.
-- WAITFOR in the sampled call starts after the T1 counters were read.
DECLARE @Deadline datetime2(7)=DATEADD(SECOND,60,SYSUTCDATETIME()),
        @SamplerDatabaseId int=DB_ID(N'ExampleAnalyzeRuntime'),
        @SeenSession int=0,@SeenRequest int=0,@SeenDatabase int=0,@SeenWait int=0;
WHILE @SeenWait=0
BEGIN
    SELECT @SeenSession=CASE WHEN COUNT(*)>0 THEN 1 ELSE @SeenSession END,
           @SeenRequest=CASE WHEN MAX(CASE WHEN [r].[session_id] IS NOT NULL THEN 1 ELSE 0 END)=1
                             THEN 1 ELSE @SeenRequest END,
           @SeenDatabase=CASE WHEN MAX(CASE WHEN [r].[database_id]=@SamplerDatabaseId THEN 1 ELSE 0 END)=1
                              THEN 1 ELSE @SeenDatabase END,
           @SeenWait=CASE WHEN MAX(CASE WHEN [r].[database_id]=@SamplerDatabaseId AND [r].[wait_type]=N'WAITFOR'
                                        THEN 1 ELSE 0 END)=1 THEN 1 ELSE @SeenWait END
    FROM sys.dm_exec_sessions AS [s]
    LEFT JOIN sys.dm_exec_requests AS [r] ON [s].[session_id]=[r].[session_id]
    WHERE SUBSTRING([s].[context_info],1,16)=0xA30F38DB7D7147CFB6E5813B2A5110FA;

    IF @SeenWait=1 BREAK;
    IF SYSUTCDATETIME()>=@Deadline
    BEGIN
        DECLARE @WindowError nvarchar(2048)=CONCAT(N'R sample window: session=',@SeenSession,
            N'; request=',@SeenRequest,N'; database=',@SeenDatabase,N'; wait=',@SeenWait,N'.');
        THROW 57028,@WindowError,1;
    END;
    WAITFOR DELAY '00:00:00.100';
END;

SELECT [language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [counter_name] COLLATE Latin1_General_100_BIN2 AS [CounterName],
       CONVERT(bigint,[counter_value]) AS [CounterValue]
INTO [#ExampleRCounterWorkerBefore]
FROM sys.dm_external_script_execution_stats
WHERE [language] COLLATE Latin1_General_100_CI_AS=N'R';

EXEC sys.sp_execute_external_script
    @language=N'R',
    @script=N'
result <- RevoScaleR::rxSummary(~ProbeValue, data=InputDataSet, summaryStats=c("Mean","ValidObs"), reportProgress=0)
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$Mean), 42)))
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$ValidObs), 2)))
OutputDataSet <- data.frame(MeanValue=as.integer(result$sDataFrame$Mean))',
    @input_data_1=N'SELECT CAST(41 AS int) AS ProbeValue UNION ALL SELECT CAST(43 AS int)'
    WITH RESULT SETS ((MeanValue int NOT NULL));

IF NOT EXISTS
(
    SELECT 1
    FROM sys.dm_external_script_execution_stats AS [a]
    INNER JOIN [#ExampleRCounterWorkerBefore] AS [b]
      ON [a].[language] COLLATE Latin1_General_100_BIN2=[b].[LanguageName]
     AND [a].[counter_name] COLLATE Latin1_General_100_BIN2=[b].[CounterName]
    WHERE CONVERT(bigint,[a].[counter_value])>[b].[CounterValue]
)
    THROW 57029,N'The R worker completed after observing the sampling window without a positive change in any existing native counter.',1;
GO
