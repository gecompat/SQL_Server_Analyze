SET NOCOUNT ON;

-- This connection is in the same owned CI instance as the marked sampler.
-- WAITFOR in the sampled call starts after the T1 counters were read.
DECLARE @Deadline datetime2(7)=DATEADD(SECOND,60,SYSUTCDATETIME());
WHILE NOT EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS [s]
    INNER JOIN sys.dm_exec_requests AS [r] ON [s].[session_id]=[r].[session_id]
    WHERE SUBSTRING([s].[context_info],1,16)=0xA30F38DB7D7147CFB6E5813B2A5110FA
      AND [r].[database_id]=DB_ID(N'ExampleAnalyzeRuntime')
      AND [r].[wait_type]=N'WAITFOR'
)
BEGIN
    IF SYSUTCDATETIME()>=@Deadline
        THROW 57028,N'The owned R worker did not observe the marked sampling window.',1;
    WAITFOR DELAY '00:00:00.100';
END;

EXEC sys.sp_execute_external_script
    @language=N'R',
    @script=N'
result <- RevoScaleR::rxSummary(~ProbeValue, data=InputDataSet, summaryStats=c("Mean","ValidObs"), reportProgress=0)
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$Mean), 42)))
stopifnot(isTRUE(all.equal(as.numeric(result$sDataFrame$ValidObs), 2)))
OutputDataSet <- data.frame(MeanValue=as.integer(result$sDataFrame$Mean))',
    @input_data_1=N'SELECT CAST(41 AS int) AS ProbeValue UNION ALL SELECT CAST(43 AS int)'
    WITH RESULT SETS ((MeanValue int NOT NULL));
GO
