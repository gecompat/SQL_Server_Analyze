USE [DeineDatenbank];
GO

/* OPS-008: Eigene native Agent-Historienretention; der Analyzer bleibt read-only. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int, [value]) = 1
)
    THROW 55061, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs]
              WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008RetentionJob')
    THROW 55062, N'Die leere Agent-Historie oder der freie eigene Jobname fehlt.', 1;

DECLARE @JobId uniqueidentifier, @Attempts int = 0, @Completed bit = 0;
DECLARE @SessionId int, @SummaryId int, @StepHistoryId int, @NativeCount bigint;
DECLARE @StepUid uniqueidentifier;
DECLARE @Execution int = 1, @Phase int = 1, @ExpectedCount bigint;
DECLARE @FirstSummary int, @FirstStep int, @SecondSummary int, @SecondStep int;
DECLARE @Cutoff datetime, @FinalCutoff datetime, @RecentBefore nvarchar(max), @RecentAfter nvarchar(max);
CREATE TABLE [#Ops008RunStarts] ([instance_id] int PRIMARY KEY, [Started] datetime NOT NULL);
DECLARE @Before nvarchar(max), @After nvarchar(max), @Stable nvarchar(max);
DECLARE @Consumer int = 1, @Calls int = 0, @Mode varchar(20), @Mapping nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(4000);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(256), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    EXEC [msdb].[dbo].[sp_add_job] @job_name = N'ExampleOps008RetentionJob',
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
        THROW 55072, N'Die eigene lokale Job-/Schrittbindung ohne Benachrichtigungen fehlt.', 1;
    WHILE @Execution <= 2
    BEGIN
    SELECT @Attempts = 0, @Completed = 0, @SummaryId = NULL, @StepHistoryId = NULL;
    EXEC [msdb].[dbo].[sp_start_job] @job_id = @JobId;
    WHILE @Attempts < 120 AND @Completed = 0
    BEGIN
        SELECT @SessionId = MAX([session_id]) FROM [msdb].[dbo].[syssessions];
        SELECT @SummaryId = [instance_id] FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId AND [step_id] = 0 AND [run_status] = 1
              AND (@Execution = 1 OR [instance_id] > @FirstSummary);
        SELECT @StepHistoryId = [instance_id] FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId AND [step_id] = 1 AND [run_status] = 1
              AND [step_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleExecutionStep'
              AND (@Execution = 1 OR [instance_id] > @FirstSummary);
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
        THROW 55063, N'Der eigene Agent-Job hat innerhalb von 120 Polls keinen bestätigten erfolgreichen Abschluss.', 1;
    INSERT [#Ops008RunStarts]
    SELECT [instance_id], DATEADD(second, ([run_time] / 10000) * 3600 +
        (([run_time] / 100) % 100) * 60 + [run_time] % 100,
        CONVERT(datetime, DATEFROMPARTS([run_date] / 10000, ([run_date] / 100) % 100, [run_date] % 100)))
    FROM [msdb].[dbo].[sysjobhistory]
    WHERE [job_id] = @JobId AND [instance_id] IN (@SummaryId, @StepHistoryId);
    IF (SELECT COUNT_BIG(*) FROM [#Ops008RunStarts]) <> @Execution * 2
        THROW 55073, N'Die unabhängigen nativen Startzeitwerte fehlen.', 1;
    IF @Execution = 1
    BEGIN
        SELECT @FirstSummary = @SummaryId, @FirstStep = @StepHistoryId;
        SELECT @Cutoff = DATEADD(second, 2, MAX([Started])) FROM [#Ops008RunStarts];
        WAITFOR DELAY '00:00:04';
    END
    ELSE
    BEGIN
        SELECT @SecondSummary = @SummaryId, @SecondStep = @StepHistoryId;
        IF EXISTS (SELECT 1 FROM [#Ops008RunStarts]
            WHERE [instance_id] IN (@SecondSummary, @SecondStep) AND [Started] <= @Cutoff)
            THROW 55074, N'Die beiden nativen Ausführungen überlappen die Retentiongrenze.', 1;
    END;
    SET @Execution += 1;
    END;
    EXEC [msdb].[dbo].[sp_update_job] @job_id = @JobId, @enabled = 0;
    IF @SummaryId = @StepHistoryId
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 4
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory] WHERE [job_id] = @JobId) <> 4
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
                  WHERE [job_id] = @JobId AND ([step_id] NOT IN (0,1) OR [run_status] <> 1))
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId AND [step_id] = 1) <> 1
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
        THROW 55064, N'Die unabhängigen Job-/Schrittidentitäten oder die native Historienanzahl sind verletzt.', 1;
    SELECT @Stable = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
        ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WAITFOR DELAY '00:00:02';
    SELECT @After = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
        ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    IF EXISTS (SELECT @Stable COLLATE SQL_Latin1_General_CP1_CS_AS
               EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
        THROW 55065, N'Die abgeschlossene Agent-Historie ist nicht stabil.', 1;

    WHILE @Phase <= 3
    BEGIN
    SET @ExpectedCount = CASE @Phase WHEN 1 THEN 4 WHEN 2 THEN 2 ELSE 0 END;
    IF @Phase = 2
    BEGIN
        SELECT @RecentBefore = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId AND [instance_id] IN (@SecondSummary, @SecondStep)
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        EXEC [msdb].[dbo].[sp_purge_jobhistory] @job_id = @JobId, @oldest_date = @Cutoff;
        SELECT @RecentAfter = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            WHERE [job_id] = @JobId ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @RecentBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @RecentAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
               WHERE [instance_id] IN (@FirstSummary, @FirstStep))
           OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 2
            THROW 55075, N'Die gezielte Retention hat ältere Zeilen erhalten oder neuere Quellwerte verändert.', 1;
    END;
    IF @Phase = 3
    BEGIN
        SELECT @FinalCutoff = DATEADD(second, 2, MAX([Started])) FROM [#Ops008RunStarts];
        EXEC [msdb].[dbo].[sp_purge_jobhistory] @job_id = @JobId, @oldest_date = @FinalCutoff;
        IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
            THROW 55076, N'Der eigene vollständige Retentionscope ist nicht leer.', 1;
    END;
    IF NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId AND [enabled] = 0)
       OR NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId AND [step_uid] = @StepUid)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity]
           WHERE [job_id] = @JobId AND [start_execution_date] IS NOT NULL AND [stop_execution_date] IS NULL)
       OR @@TRANCOUNT <> 0
        THROW 55077, N'Die Retention hat die eigene Jobbindung oder Callerbasis verletzt.', 1;
    SET @Consumer = 1;
    TRUNCATE TABLE [#Ops008Console];
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
            THROW 55066, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
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
        ) OR @NativeCount <> @ExpectedCount OR EXISTS
        (
            SELECT 1 FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
            WHERE [Area] = 'AGENT_HISTORY' AND NULLIF([EvidenceLimit], N'') IS NULL
        )
            THROW 55067, N'Der native Agent-Count oder die unveränderten NULL-Zeitgrenzen sind verletzt.', 1;
        IF @Consumer = 2
        BEGIN
            EXEC [sys].[sp_executesql]
                N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
            IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                       EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55068, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                THROW 55069, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
        END;
        SELECT @After = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
            THROW 55070, N'Der Analyzer hat Quellwerte oder den Callerzustand verändert.', 1;
        SET @Calls += 1;
        SET @Consumer += 1;
    END;
    ROLLBACK TRANSACTION;
    SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
    SET @Phase += 1;
    END;
    EXEC [msdb].[dbo].[sp_delete_job] @job_id = @JobId, @delete_unused_schedule = 0;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]) OR @@TRANCOUNT <> 0
        THROW 55071, N'Der eigene Agent-Job oder seine Historie wurde nicht vollständig entfernt.', 1;
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
    SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
    THROW;
END CATCH;
SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
DROP TABLE [#Ops008Console];
DROP TABLE [#Ops008RunStarts];
SELECT N'OPS008_AGENT_RETENTION' AS [ContractName], 1 AS [ExecutedJobs], 2 AS [ExecutedSteps],
    4 AS [InitialHistoryRows], 2 AS [RetainedHistoryRows], @NativeCount AS [FinalHistoryRows], @Calls AS [ConsumerCalls],
    N'PASS' AS [Status], N'JOB_REMOVED' AS [FixtureCleanup];
GO
