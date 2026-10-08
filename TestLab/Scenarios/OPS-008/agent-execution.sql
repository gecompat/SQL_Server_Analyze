USE [DeineDatenbank];
GO

/* OPS-008: Tatsächlicher eigener Agent-Job; keine direkte Historieninjektion. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int, [value]) = 1
)
    THROW 54961, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 54973, N'Der ursprüngliche Standardlocktimeout fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs]
              WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008ExecutionJob')
    THROW 54962, N'Die leere Agent-Historie oder der freie eigene Jobname fehlt.', 1;

DECLARE @JobId uniqueidentifier, @Attempts int = 0, @Completed bit = 0;
DECLARE @SessionId int, @SummaryId int, @StepHistoryId int, @NativeCount bigint;
DECLARE @StepUid uniqueidentifier;
DECLARE @Before nvarchar(max), @After nvarchar(max), @Stable nvarchar(max);
DECLARE @Consumer int = 1, @Calls int = 0, @Mode varchar(20), @Mapping nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(4000);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT;
DECLARE @PreviousXactAbort bit = CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END;
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(256), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    SET XACT_ABORT ON;
    EXEC [msdb].[dbo].[sp_add_job] @job_name = N'ExampleOps008ExecutionJob',
        @enabled = 1, @description = N'Synthetic local execution contract.',
        @notify_level_eventlog = 0, @notify_level_email = 0,
        @notify_level_netsend = 0, @notify_level_page = 0,
        @delete_level = 0, @job_id = @JobId OUTPUT;
    EXEC [msdb].[dbo].[sp_add_jobstep] @job_id = @JobId, @step_id = 1,
        @step_name = N'ExampleExecutionStep', @subsystem = N'TSQL',
        @command = N'SET NOCOUNT ON; SELECT 1 AS ExampleValue;',
        @database_name = N'master', @on_success_action = 1, @on_fail_action = 2,
        @retry_attempts = 0;
    EXEC [msdb].[dbo].[sp_add_jobserver] @job_id = @JobId, @server_name = N'(LOCAL)';
    SELECT @StepUid = [step_uid] FROM [msdb].[dbo].[sysjobsteps]
        WHERE [job_id] = @JobId AND [step_id] = 1;
    IF @StepUid IS NULL OR @StepUid = @JobId
       OR NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs]
            WHERE [job_id] = @JobId AND [enabled] = 1 AND [delete_level] = 0
              AND [notify_level_eventlog] = 0 AND [notify_level_email] = 0
              AND [notify_level_netsend] = 0 AND [notify_level_page] = 0)
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId) <> 1
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId AND [server_id] = 0) <> 1
        THROW 54972, N'Die eigene lokale Job-/Schrittbindung ohne Benachrichtigungen fehlt.', 1;
    EXEC [msdb].[dbo].[sp_start_job] @job_id = @JobId;
    WHILE @Attempts < 120 AND @Completed = 0
    BEGIN
        SELECT @SessionId = MAX([session_id]) FROM [msdb].[dbo].[syssessions];
        SELECT @SummaryId = [instance_id] FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId AND [step_id] = 0 AND [run_status] = 1;
        SELECT @StepHistoryId = [instance_id] FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId AND [step_id] = 1 AND [run_status] = 1
              AND [step_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleExecutionStep';
        IF @SummaryId IS NOT NULL AND @StepHistoryId IS NOT NULL AND EXISTS
        (
            SELECT 1 FROM [msdb].[dbo].[sysjobactivity]
            WHERE [session_id] = @SessionId AND [job_id] = @JobId
              AND [start_execution_date] IS NOT NULL AND [stop_execution_date] IS NOT NULL
              AND [job_history_id] = @SummaryId
        ) SET @Completed = 1;
        ELSE
        BEGIN
            WAITFOR DELAY '00:00:01';
            SET @Attempts += 1;
        END;
    END;
    IF @Completed = 0
        THROW 54963, N'Der eigene Agent-Job hat innerhalb von 120 Polls keinen bestätigten erfolgreichen Abschluss.', 1;
    EXEC [msdb].[dbo].[sp_update_job] @job_id = @JobId, @enabled = 0;
    IF @SummaryId = @StepHistoryId
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 2
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory] WHERE [job_id] = @JobId) <> 2
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
                  WHERE [job_id] = @JobId AND ([step_id] NOT IN (0,1) OR [run_status] <> 1))
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId AND [step_id] = 1) <> 1
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
        THROW 54964, N'Die unabhängigen Job-/Schrittidentitäten oder die native Historienanzahl sind verletzt.', 1;
    SELECT @Stable = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
        ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WAITFOR DELAY '00:00:02';
    SELECT @After = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
        ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    IF EXISTS (SELECT @Stable COLLATE SQL_Latin1_General_CP1_CS_AS
               EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
        THROW 54965, N'Die abgeschlossene Agent-Historie ist nicht stabil.', 1;

    BEGIN TRANSACTION;
    SET LOCK_TIMEOUT 137;
    WHILE @Consumer <= 3
    BEGIN
        SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SELECT @NativeCount = COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory];
        SET @Mode = CASE @Consumer WHEN 1 THEN 'NONE' WHEN 2 THEN 'TABLE' ELSE 'CONSOLE' END;
        SET @Mapping = CASE WHEN @Consumer = 2 THEN N'{"msdbHealth":"#Ops008Table"}' ELSE NULL END;
        SELECT @Json = NULL, @Status = NULL, @Partial = NULL, @Error = -1, @Message = N'Example sentinel';
        IF @Consumer = 2 CREATE TABLE [#Ops008Table] ([Dummy] int);
        IF @Consumer = 3
        BEGIN
            INSERT [#Ops008Console]
            EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                @ResultSetArt = @Mode, @JsonErzeugen = 1, @Json = @Json OUTPUT,
                @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                @ErrorMessageOut = @Message OUTPUT;
        END
        ELSE
            EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                @ResultSetArt = @Mode, @ResultTablesJson = @Mapping,
                @JsonErzeugen = 1, @Json = @Json OUTPUT,
                @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                @ErrorMessageOut = @Message OUTPUT;
        IF COALESCE(ISJSON(@Json), 0) <> 1 OR COALESCE(@Status, '') <> 'AVAILABLE'
           OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 6
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
               WITH ([Area] varchar(40)) WHERE [Area] = 'AGENT_HISTORY') <> 1
            THROW 54966, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
        IF EXISTS
        (
            SELECT 'AGENT_HISTORY' [Area], N'msdb.dbo.sysjobhistory' [SourceObject], @NativeCount [RowCount],
                CONVERT(datetime2(3), NULL) [OldestUtc], CONVERT(datetime2(3), NULL) [NewestUtc],
                CONVERT(decimal(19,2), NULL) [SizeMb], CONVERT(varchar(40), 'AVAILABLE') [StatusCode]
            EXCEPT
            SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
            FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                [OldestUtc] datetime2(3), [NewestUtc] datetime2(3), [SizeMb] decimal(19,2), [StatusCode] varchar(40))
        ) OR @NativeCount <> 2 OR EXISTS
        (
            SELECT 1 FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
            WHERE [Area] = 'AGENT_HISTORY' AND NULLIF([EvidenceLimit], N'') IS NULL
        )
            THROW 54967, N'Der native Agent-Count oder die unveränderten NULL-Zeitgrenzen sind verletzt.', 1;
        IF @Consumer = 2
        BEGIN
            EXEC [sys].[sp_executesql]
                N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
            IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                       EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 54968, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
            DROP TABLE [#Ops008Table];
        END;
        IF @Consumer = 3
        BEGIN
            SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc],
                [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
                FROM [#Ops008Console] ORDER BY [Area] FOR JSON PATH);
            IF EXISTS (SELECT @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS
                       EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT 1 FROM [#Ops008Console] WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
                THROW 54969, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
        END;
        SELECT @After = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
           OR (@@OPTIONS & 16384) <> 16384
            THROW 54970, N'Der Analyzer hat Quellwerte oder den Callerzustand verändert.', 1;
        SET @Calls += 1;
        SET @Consumer += 1;
    END;
    ROLLBACK TRANSACTION;
    EXEC [msdb].[dbo].[sp_delete_job] @job_id = @JobId, @delete_unused_schedule = 0;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]) OR @@TRANCOUNT <> 0
        THROW 54971, N'Der eigene Agent-Job oder seine Historie wurde nicht vollständig entfernt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF @JobId IS NOT NULL AND EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId)
    BEGIN
        BEGIN TRY
            IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity]
                WHERE [session_id] = (SELECT MAX([session_id]) FROM [msdb].[dbo].[syssessions])
                  AND [job_id] = @JobId AND [start_execution_date] IS NOT NULL AND [stop_execution_date] IS NULL)
                EXEC [msdb].[dbo].[sp_stop_job] @job_id = @JobId;
            SET @Attempts = 0;
            WHILE @Attempts < 30 AND EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity]
                WHERE [session_id] = (SELECT MAX([session_id]) FROM [msdb].[dbo].[syssessions])
                  AND [job_id] = @JobId AND [start_execution_date] IS NOT NULL AND [stop_execution_date] IS NULL)
            BEGIN
                WAITFOR DELAY '00:00:01';
                SET @Attempts += 1;
            END;
            EXEC [msdb].[dbo].[sp_delete_job] @job_id = @JobId, @delete_unused_schedule = 0;
        END TRY
        BEGIN CATCH
            PRINT N'OPS-008: Eigenes Jobcleanup fehlgeschlagen; das äußere Labcleanup bleibt erforderlich.';
        END CATCH;
    END;
    SET LOCK_TIMEOUT -1;
    IF @PreviousXactAbort = 1 SET XACT_ABORT ON;
    ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
SET LOCK_TIMEOUT -1;
IF @PreviousXactAbort = 1 SET XACT_ABORT ON;
ELSE SET XACT_ABORT OFF;
IF @Calls <> 3 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
   OR CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END <> @PreviousXactAbort
    THROW 54974, N'Die Consumerzahl oder die ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_AGENT_EXECUTION' AS [ContractName], 1 AS [ExecutedJobs], 1 AS [ExecutedSteps],
    @NativeCount AS [NativeHistoryRows], @Calls AS [ConsumerCalls],
    N'PASS' AS [Status], N'JOB_REMOVED' AS [FixtureCleanup];
GO
