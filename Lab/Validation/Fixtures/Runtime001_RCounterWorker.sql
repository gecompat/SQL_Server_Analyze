SET NOCOUNT ON;

-- Both samplers publish their exact session IDs on this owned instance.
-- Each WAITFOR starts after T1 was read.
DECLARE @Phase int=1,@Deadline datetime2(7),@SamplerDatabaseId int=DB_ID(N'ExampleAnalyzeRuntime'),
        @SamplerSessionId smallint,@SeenSession int,@SeenRequest int,@SeenDatabase int,@SeenWait int,
        @SamplerTable sysname,@ReadSampler nvarchar(300),@WindowError nvarchar(2048);

WHILE @Phase<=2
BEGIN
    SET @Deadline=DATEADD(SECOND,60,SYSUTCDATETIME());
    SET @SamplerSessionId=NULL;
    SET @SeenSession=0;
    SET @SeenRequest=0;
    SET @SeenDatabase=0;
    SET @SeenWait=0;
    SET @SamplerTable=CASE @Phase WHEN 1 THEN N'##ExampleRuntime001RCounterSampler'
                                 WHEN 2 THEN N'##ExampleRuntime001RPoolEpochSampler' END;
    SET @ReadSampler=N'SELECT @SessionId=[SamplerSessionId] FROM '+QUOTENAME(@SamplerTable)+N';';
    WHILE @SeenWait=0
    BEGIN
        IF @SamplerSessionId IS NULL AND OBJECT_ID(N'tempdb..'+@SamplerTable,N'U') IS NOT NULL
        BEGIN
            BEGIN TRY
                EXEC sys.sp_executesql
                    @ReadSampler,
                    N'@SessionId smallint OUTPUT',@SessionId=@SamplerSessionId OUTPUT;
            END TRY
            BEGIN CATCH
                IF ERROR_NUMBER()<>208 THROW;
            END CATCH;
        END;

        SELECT @SeenSession=CASE WHEN COUNT(*)>0 THEN 1 ELSE @SeenSession END,
               @SeenRequest=CASE WHEN MAX(CASE WHEN [r].[session_id] IS NOT NULL THEN 1 ELSE 0 END)=1
                                 THEN 1 ELSE @SeenRequest END,
               @SeenDatabase=CASE WHEN MAX(CASE WHEN [r].[database_id]=@SamplerDatabaseId THEN 1 ELSE 0 END)=1
                                  THEN 1 ELSE @SeenDatabase END,
               @SeenWait=CASE WHEN MAX(CASE WHEN [r].[database_id]=@SamplerDatabaseId AND [r].[wait_type]=N'WAITFOR'
                                            THEN 1 ELSE 0 END)=1 THEN 1 ELSE @SeenWait END
        FROM sys.dm_exec_sessions AS [s]
        LEFT JOIN sys.dm_exec_requests AS [r] ON [s].[session_id]=[r].[session_id]
        WHERE [s].[session_id]=@SamplerSessionId;

        IF @SeenWait=1 BREAK;
        IF SYSUTCDATETIME()>=@Deadline
        BEGIN
            SET @WindowError=CONCAT(N'R sample window: phase=',@Phase,N'; published=',IIF(@SamplerSessionId IS NULL,0,1),N'; session=',@SeenSession,
                N'; request=',@SeenRequest,N'; database=',@SeenDatabase,N'; wait=',@SeenWait,N'.');
            THROW 57028,@WindowError,1;
        END;
        WAITFOR DELAY '00:00:00.100';
    END;

    IF @Phase=1
    BEGIN
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
    END
    ELSE
    BEGIN
        ALTER EXTERNAL RESOURCE POOL [ExampleRuntime001Epoch] WITH (MAX_PROCESSES=1);
        ALTER RESOURCE GOVERNOR RECONFIGURE;
    END;
    SET @Phase+=1;
END;
GO
