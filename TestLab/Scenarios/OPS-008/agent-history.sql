USE [DeineDatenbank];
GO

/* TEST-0001: Synthetische Tabellenfixture; führt keinen Agent-Job aus. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int, [value]) = 1
)
    THROW 54943, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs]
              WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008HistoryJob')
    THROW 54944, N'Die leere Agent-Historie oder der freie eigene Jobname fehlt.', 1;

DECLARE @PreviousXactAbort int = @@OPTIONS & 16384, @PreviousLockTimeout int = @@LOCK_TIMEOUT;
DECLARE @JobId uniqueidentifier, @Stage int = 1;
DECLARE @Before nvarchar(max), @After nvarchar(max), @Json nvarchar(max);
DECLARE @Status varchar(40), @Partial bit;
DECLARE @DateCase int = 1, @Consumer int, @Calls int = 0;
DECLARE @RunDate int, @RunTime int, @RunDuration int, @ExpectedSeconds int;
DECLARE @ExpectedStart datetime, @Error int, @Message nvarchar(2048);
DECLARE @PositiveTableCalls int = 0, @PositiveTableRows bigint;
DECLARE @PositiveTableJobId uniqueidentifier, @PositiveTableStart datetime;
DECLARE @PositiveTableSeconds int, @PositiveTableJson nvarchar(max);
DECLARE @PositiveNoneJobsJson nvarchar(max);
DECLARE @PositiveTableActualSchema TABLE
([LogicalOrdinal] int, [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [SystemTypeId] tinyint);
DECLARE @PositiveTableExpectedSchema TABLE
([LogicalOrdinal] int, [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [SystemTypeId] tinyint);
INSERT @PositiveTableExpectedSchema VALUES
(1, N'JobId', 36), (2, N'JobName', 231), (3, N'Enabled', 104),
(4, N'OwnerName', 231), (5, N'CategoryName', 231), (6, N'IsRunning', 104),
(7, N'RunStart', 61), (8, N'RunningMinutes', 56),
(9, N'LastRunDateTime', 61), (10, N'LastRunStatus', 56),
(11, N'LastRunStatusDesc', 231), (12, N'LastRunDurationSeconds', 56),
(13, N'LastMessage', 231), (14, N'ScheduleCount', 56),
(15, N'EnabledScheduleCount', 56), (16, N'StepCount', 56),
(17, N'ProblemCode', 167);
DECLARE @DateCases TABLE
([CaseId] int PRIMARY KEY, [RunDate] int, [RunTime] int, [RunDuration] int,
 [ExpectedStart] datetime, [ExpectedSeconds] int);
INSERT @DateCases VALUES
(1, 20240229, 0, 0, CONVERT(datetime, '2024-02-29T00:00:00', 126), 0),
(2, 20240229, 10203, 125, CONVERT(datetime, '2024-02-29T01:02:03', 126), 85),
(3, 20250102, 235959, 1000000, CONVERT(datetime, '2025-01-02T23:59:59', 126), 360000);
DECLARE @StepCase int = 1, @StepReturn int;
DECLARE @StepOneHistoryId int, @StepTwoHistoryId int;
DECLARE @ExpectedSteps TABLE
([JobName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [StepId] int, [StepName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [Subsystem] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [LastRunOutcome] int, [LastRunOutcomeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [LastRunDateTime] datetime, [LastRunDurationSeconds] int, [LastRunRetries] int,
 [LastRunMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
DECLARE @ActualSteps TABLE
([JobName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [StepId] int, [StepName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [Subsystem] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [LastRunOutcome] int, [LastRunOutcomeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [LastRunDateTime] datetime, [LastRunDurationSeconds] int, [LastRunRetries] int,
 [LastRunMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
BEGIN TRY
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    EXEC [msdb].[dbo].[sp_add_job] @job_name = N'ExampleOps008HistoryJob',
        @enabled = 0, @description = N'Synthetic aggregate fixture; never executed.',
        @job_id = @JobId OUTPUT;
    WHILE @Stage <= 3
    BEGIN
        INSERT [msdb].[dbo].[sysjobhistory]
        ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
         [message], [run_status], [run_date], [run_time], [run_duration],
         [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
         [retries_attempted], [server])
        VALUES
        (@JobId, CASE WHEN @Stage = 2 THEN 1 ELSE 0 END, N'ExampleHistoryStep', 0, 0,
         N'Example controlled history row', CASE WHEN @Stage = 1 THEN 1 ELSE 0 END,
         CASE WHEN @Stage = 3 THEN 20000101 ELSE 20250102 END, 120000, 125,
         0, 0, 0, 0, N'ExampleHistoryServer');
        SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);

        EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
            @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
            @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
            @IsPartialOut = @Partial OUTPUT;
        IF @Status <> 'AVAILABLE' OR @Partial <> 0 OR NOT EXISTS
        (
            SELECT 1 FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                  [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
                  [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000))
            WHERE [Area] = 'AGENT_HISTORY' AND [SourceObject] = N'msdb.dbo.sysjobhistory'
              AND [RowCount] = @Stage AND [StatusCode] = 'AVAILABLE'
              AND [OldestUtc] IS NULL AND [NewestUtc] IS NULL
              AND NULLIF([EvidenceLimit], N'') IS NOT NULL
        )
            THROW 54945, N'Die positive Agent-Aggregatparität ist verletzt.', 1;
        SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before COLLATE SQL_Latin1_General_CP1_CS_AS <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
           OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> @Stage
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 54946, N'Der Analyzer hat Quellwerte oder die Callertransaktion verändert.', 1;
        SET @Calls += 1;
        SET @Stage += 1;
    END;
    -- Die Literale prüfen Joboutcomes; es wird kein Jobstep ausgeführt.
    WHILE @DateCase <= 3
    BEGIN
        SELECT @RunDate = [RunDate], @RunTime = [RunTime],
            @RunDuration = [RunDuration], @ExpectedStart = [ExpectedStart],
            @ExpectedSeconds = [ExpectedSeconds]
        FROM @DateCases WHERE [CaseId] = @DateCase;
        INSERT [msdb].[dbo].[sysjobhistory]
        ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
         [message], [run_status], [run_date], [run_time], [run_duration],
         [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
         [retries_attempted], [server])
        VALUES (@JobId, 0, N'ExampleHistoryOutcome', 0, 0,
            N'Example controlled date and duration', 1, @RunDate, @RunTime,
            @RunDuration, 0, 0, 0, 0, N'ExampleHistoryServer');
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            SELECT @Json = NULL, @Status = NULL, @Partial = NULL,
                @Error = NULL, @Message = NULL;
            IF @Consumer = 1
            BEGIN
                EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT;
                IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 1) <> 0
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json)
                    WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                          [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
                          [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000))
                    WHERE [Area] = 'AGENT_HISTORY' AND [SourceObject] = N'msdb.dbo.sysjobhistory'
                      AND [RowCount] = 3 + @DateCase AND [StatusCode] = 'AVAILABLE'
                      AND [OldestUtc] IS NULL AND [NewestUtc] IS NULL
                      AND NULLIF([EvidenceLimit], N'') IS NOT NULL
                ) THROW 55197, N'Die erweiterten Agent-Aggregate sind verletzt.', 1;
            END
            ELSE IF @Consumer = 2
            BEGIN
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
                IF COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '') <> 'AVAILABLE'
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), '') <> 'false'
                   OR COALESCE(JSON_QUERY(@Json, '$.steps'), '') <> '[]'
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                    WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                          [LastRunDateTime] datetime, [LastRunDurationSeconds] int,
                          [LastRunStatus] int, [Enabled] bit, [StepCount] int)
                    WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                      AND [LastRunDateTime] = @ExpectedStart
                      AND [LastRunDurationSeconds] = @ExpectedSeconds
                      AND [LastRunStatus] = 1 AND [Enabled] = 0 AND [StepCount] = 0
                ) THROW 55198, N'Die AgentJobs-Datums- oder Sekundeninterpretation ist verletzt.', 1;
                SET @PositiveNoneJobsJson = JSON_QUERY(@Json, '$.jobs');
                SELECT @After = (SELECT
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                        ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                        ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                        ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                        ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                        ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
                    JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                        ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
                IF @Before IS NULL OR @After IS NULL
                   OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 3 + @DateCase
                   OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
                   OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                    THROW 55199, N'Der AgentJobs-NONE-Aufruf hat Agentquellen oder Callerzustand verändert.', 1;
                CREATE TABLE [#AgentJobsPositiveTable] ([Placeholder] int NULL);
                SELECT @Json = NULL, @PositiveTableRows = NULL, @PositiveTableJobId = NULL,
                    @PositiveTableStart = NULL, @PositiveTableSeconds = NULL, @PositiveTableJson = NULL;
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @ResultSetArt = 'TABLE',
                    @ResultTablesJson = N'{"jobs":"#AgentJobsPositiveTable"}',
                    @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                SET @PositiveTableCalls += 1;
                SET @Calls += 1;
                EXEC [sys].[sp_executesql]
                    N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsPositiveTable]),
                             @jobId = (SELECT TOP (1) [JobId] FROM [#AgentJobsPositiveTable]),
                             @runStart = (SELECT TOP (1) [LastRunDateTime] FROM [#AgentJobsPositiveTable]),
                             @seconds = (SELECT TOP (1) [LastRunDurationSeconds] FROM [#AgentJobsPositiveTable]),
                             @jobsJson = (SELECT * FROM [#AgentJobsPositiveTable]
                                 ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                    N'@rows bigint OUTPUT, @jobId uniqueidentifier OUTPUT,
                      @runStart datetime OUTPUT, @seconds int OUTPUT,
                      @jobsJson nvarchar(max) OUTPUT',
                    @rows = @PositiveTableRows OUTPUT, @jobId = @PositiveTableJobId OUTPUT,
                    @runStart = @PositiveTableStart OUTPUT,
                    @seconds = @PositiveTableSeconds OUTPUT,
                    @jobsJson = @PositiveTableJson OUTPUT;
                DELETE FROM @PositiveTableActualSchema;
                INSERT @PositiveTableActualSchema
                    ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                    [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    [c].[system_type_id]
                FROM [tempdb].[sys].[columns] AS [c]
                WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsPositiveTable');
                IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                   )
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                   )
                    THROW 55198, N'Das positive AgentJobs-TABLE-Schema ist verletzt.', 1;
                IF @PositiveTableRows IS NULL OR @PositiveTableRows <> 1 OR @PositiveTableJobId IS NULL
                   OR @PositiveTableJobId <> @JobId OR @PositiveTableStart IS NULL
                   OR @PositiveTableStart <> @ExpectedStart OR @PositiveTableSeconds IS NULL
                   OR @PositiveTableSeconds <> @ExpectedSeconds
                    THROW 55198, N'Die positive AgentJobs-TABLE-Datums- oder Sekundeninterpretation ist verletzt.', 1;
                IF COALESCE(ISJSON(@Json), 0) <> 1
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '') <> 'AVAILABLE'
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), '') <> 'false'
                   OR JSON_VALUE(@Json, '$.meta.errorNumber') IS NOT NULL
                   OR JSON_VALUE(@Json, '$.meta.errorMessage') IS NOT NULL
                   OR COALESCE(JSON_QUERY(@Json, '$.steps'), '') <> '[]'
                   OR JSON_QUERY(@Json, '$.jobs') IS NULL
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
                   OR @PositiveNoneJobsJson IS NULL OR @PositiveTableJson IS NULL
                   OR @PositiveTableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @PositiveTableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @PositiveNoneJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 55198, N'Die positive AgentJobs-TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#AgentJobsPositiveTable];
            END
            ELSE
            BEGIN
                EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours = 24,
                    @MitJobStatus = 1, @MitDatabaseMail = 0, @MaxZeilen = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                    @ErrorMessageOut = @Message OUTPUT;
                IF COALESCE(@Status, '') NOT IN ('AVAILABLE', 'AVAILABLE_WITH_FINDING')
                   OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')
                       WITH ([JobId] uniqueidentifier) WHERE [JobId] = @JobId) <> 1
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                    WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                          [LatestRunDateTime] datetime, [LatestRunDuration] int,
                          [LatestRunStatus] int, [IsEnabled] bit,
                          [FindingCode] varchar(100), [FindingSeverity] varchar(16))
                    WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                      AND [LatestRunDateTime] = @ExpectedStart
                      AND [LatestRunDuration] = @RunDuration AND [LatestRunStatus] = 1
                      AND [IsEnabled] = 0 AND [FindingCode] = 'JOB_STATE_INFORMATIONAL'
                      AND [FindingSeverity] = 'INFO'
                ) THROW 55198, N'Die Monitoring-Datums- oder Rohdauerinterpretation ist verletzt.', 1;
            END;
            SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @Before IS NULL OR @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 3 + @DateCase
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Die erweiterten Consumer haben Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @DateCase += 1;
    END;
    IF @DateCase <> 4 OR @Calls <> 15 OR @PositiveTableCalls <> 3
        THROW 55199, N'Die drei Datumsfälle, 15 Consumeraufrufe oder drei AgentJobs-TABLE-Aufrufe fehlen.', 1;
    -- Eigene Stepdefinitionen und injizierte History werden niemals ausgeführt.
    EXEC @StepReturn = [msdb].[dbo].[sp_add_jobstep] @job_id = @JobId, @step_id = 1,
        @step_name = N'ExampleHistoryStepOne', @subsystem = N'TSQL',
        @command = N'SET NOCOUNT ON; SELECT 1 AS ExampleValue;',
        @database_name = N'master', @on_success_action = 1, @on_fail_action = 2,
        @retry_attempts = 0;
    IF @StepReturn <> 0 THROW 55199, N'Die erste eigene Stepdefinition fehlt.', 1;
    EXEC @StepReturn = [msdb].[dbo].[sp_add_jobstep] @job_id = @JobId, @step_id = 2,
        @step_name = N'ExampleHistoryStepTwo', @subsystem = N'TSQL',
        @command = N'SET NOCOUNT ON; SELECT 1 AS ExampleValue;',
        @database_name = N'master', @on_success_action = 1, @on_fail_action = 2,
        @retry_attempts = 0;
    IF @StepReturn <> 0 OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobsteps]
        WHERE [job_id] = @JobId) <> 2
        THROW 55199, N'Die beiden eigenen Stepdefinitionen fehlen.', 1;
    WHILE @StepCase <= 3
    BEGIN
        SELECT @RunDate = [RunDate], @RunTime = [RunTime],
            @RunDuration = [RunDuration], @ExpectedStart = [ExpectedStart],
            @ExpectedSeconds = [ExpectedSeconds]
        FROM @DateCases WHERE [CaseId] = @StepCase;
        INSERT [msdb].[dbo].[sysjobhistory]
        ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
         [message], [run_status], [run_date], [run_time], [run_duration],
         [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
         [retries_attempted], [server])
        VALUES (@JobId, 1, N'ExampleHistoryStepOne', 0, 0,
            N'Example controlled step outcome', 1, @RunDate, @RunTime,
            @RunDuration, 0, 0, 0, @StepCase - 1, N'ExampleHistoryServer');
        SET @StepOneHistoryId = CONVERT(int, SCOPE_IDENTITY());
        INSERT [msdb].[dbo].[sysjobhistory]
        ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
         [message], [run_status], [run_date], [run_time], [run_duration],
         [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
         [retries_attempted], [server])
        VALUES (@JobId, 2, N'ExampleHistoryStepTwo', 0, 0,
            N'Example step counterexample', 1, 20001231, 112233,
            253001, 0, 0, 0, 0, N'ExampleHistoryServer');
        SET @StepTwoHistoryId = CONVERT(int, SCOPE_IDENTITY());
        IF @StepOneHistoryId IS NULL OR @StepTwoHistoryId IS NULL
           OR @StepTwoHistoryId <= @StepOneHistoryId
            THROW 55199, N'Die unabhängige Historyreihenfolge der Steps fehlt.', 1;
        DELETE FROM @ExpectedSteps;
        INSERT @ExpectedSteps VALUES
        (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
         1, N'SUCCEEDED', @ExpectedStart, @ExpectedSeconds, @StepCase - 1,
         N'Example controlled step outcome'),
        (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
         1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126), 91801, 0,
         N'Example step counterexample');
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            SELECT @Json = NULL, @Status = NULL, @Partial = NULL,
                @Error = NULL, @Message = NULL;
            IF @Consumer = 1
            BEGIN
                EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT;
                IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 1) <> 0
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json)
                    WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                          [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
                          [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000))
                    WHERE [Area] = 'AGENT_HISTORY' AND [SourceObject] = N'msdb.dbo.sysjobhistory'
                      AND [RowCount] = 6 + 2 * @StepCase AND [StatusCode] = 'AVAILABLE'
                      AND [OldestUtc] IS NULL AND [NewestUtc] IS NULL
                      AND NULLIF([EvidenceLimit], N'') IS NOT NULL
                ) THROW 55197, N'Die erweiterten Agent-Aggregate sind verletzt.', 1;
            END
            ELSE IF @Consumer = 2
            BEGIN
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
                IF COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '') <> 'AVAILABLE'
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), '') <> 'false'
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                    WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                          [LastRunDateTime] datetime, [LastRunDurationSeconds] int,
                          [LastRunStatus] int, [Enabled] bit, [StepCount] int)
                    WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                      AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                      AND [LastRunDurationSeconds] = 360000
                      AND [LastRunStatus] = 1 AND [Enabled] = 0 AND [StepCount] = 2
                ) THROW 55198, N'Die AgentJobs-Datums- oder Sekundeninterpretation ist verletzt.', 1;
                DELETE FROM @ActualSteps;
                INSERT @ActualSteps
                SELECT * FROM OPENJSON(@Json, '$.steps')
                WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                      [Subsystem] nvarchar(40), [LastRunOutcome] int,
                      [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                      [LastRunDurationSeconds] int, [LastRunRetries] int,
                      [LastRunMessage] nvarchar(4000));
                IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> 2
                   OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
                   OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                    THROW 55198, N'Die zehn Stepwerte oder schrittbezogene Auswahl sind verletzt.', 1;
            END
            ELSE
            BEGIN
                EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours = 24,
                    @MitJobStatus = 1, @MitDatabaseMail = 0, @MaxZeilen = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                    @ErrorMessageOut = @Message OUTPUT;
                IF COALESCE(@Status, '') NOT IN ('AVAILABLE', 'AVAILABLE_WITH_FINDING')
                   OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')
                       WITH ([JobId] uniqueidentifier) WHERE [JobId] = @JobId) <> 1
                   OR NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                    WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                          [LatestRunDateTime] datetime, [LatestRunDuration] int,
                          [LatestRunStatus] int, [IsEnabled] bit,
                          [FindingCode] varchar(100), [FindingSeverity] varchar(16))
                    WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                      AND [LatestRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                      AND [LatestRunDuration] = 1000000 AND [LatestRunStatus] = 1
                      AND [IsEnabled] = 0 AND [FindingCode] = 'JOB_STATE_INFORMATIONAL'
                      AND [FindingSeverity] = 'INFO'
                ) THROW 55198, N'Die Monitoring-Datums- oder Rohdauerinterpretation ist verletzt.', 1;
            END;
            SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @Before IS NULL OR @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 6 + 2 * @StepCase
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Die erweiterten Consumer haben Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @StepCase += 1;
    END;
    IF @StepCase <> 4 OR @Calls <> 24
        THROW 55199, N'Die drei Stepfälle oder 24 Consumeraufrufe fehlen.', 1;
    -- Der zuletzt injizierte Step bleibt derselbe; nur sein jüngster Status wechselt.
    DECLARE @StepStatus int = 0, @StepProblemFlag int,
        @StepProblemValue bit, @StepStatusDesc nvarchar(60),
        @StepStatusCalls int = 0, @StepNullProblemCalls int = 0,
        @StepJobsJson nvarchar(max), @StepActualJobsJson nvarchar(max);
    WHILE @StepStatus <= 4
    BEGIN
        SET @StepStatusDesc = CASE @StepStatus
            WHEN 0 THEN N'FAILED' WHEN 1 THEN N'SUCCEEDED'
            WHEN 2 THEN N'RETRY' WHEN 3 THEN N'CANCELED'
            WHEN 4 THEN N'IN_PROGRESS' END;
        UPDATE [msdb].[dbo].[sysjobhistory]
        SET [run_status] = @StepStatus
        WHERE [instance_id] = @StepOneHistoryId
          AND [job_id] = @JobId AND [step_id] = 1;
        IF @@ROWCOUNT <> 1
            THROW 55199, N'Der jüngste eigene Stepstatus wurde nicht eindeutig gesetzt.', 1;
        SELECT @Before = (SELECT
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
            ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
            ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
            ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
            ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
            ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before IS NULL OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 55199, N'Die Stepstatus-Fixture benötigt unveränderte Quellen und Calleroptionen.', 1;
        SET @StepProblemFlag = 0;
        WHILE @StepProblemFlag <= 2
        BEGIN
            SET @StepProblemValue = CASE WHEN @StepProblemFlag = 2
                                         THEN NULL ELSE @StepProblemFlag END;
            SELECT @Json = NULL, @StepActualJobsJson = NULL;
            EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                @MaxZeilen = 0, @NurProblematisch = @StepProblemValue,
                @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                @Json = @Json OUTPUT, @PrintMeldungen = 0;
            IF XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Stepstatus-Aufruf hat Calleroptionen oder den Transaktionszustand verändert.', 1;
            IF COALESCE(ISJSON(@Json), 0) <> 1
                THROW 55198, N'Der Stepstatus-Aufruf lieferte kein gültiges JSON.', 1;
            IF COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
               OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
               OR JSON_VALUE(@Json, '$.meta.errorNumber') IS NOT NULL
               OR JSON_VALUE(@Json, '$.meta.errorMessage') IS NOT NULL
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1)
                    <> CASE WHEN @StepProblemFlag = 0 THEN 2
                            WHEN @StepStatus IN (0, 2, 3) THEN 1 ELSE 0 END
                THROW 55198, N'Die Stepstatus-Metadaten oder erforderlichen Arrays sind verletzt.', 1;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
               OR NOT EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                      [LastRunDateTime] datetime, [LastRunDurationSeconds] int,
                      [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                      [Enabled] bit, [StepCount] int, [ProblemCode] varchar(40))
                WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                  AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                  AND [LastRunDurationSeconds] = 360000
                  AND [LastRunStatus] = 1 AND [LastRunStatusDesc] = N'SUCCEEDED'
                  AND [Enabled] = 0 AND [StepCount] = 2 AND [ProblemCode] = 'DISABLED'
            ) THROW 55198, N'Der eigene deaktivierte Job wurde nicht unverändert ausgegeben.', 1;
            SET @StepActualJobsJson = JSON_QUERY(@Json, '$.jobs');
            IF @StepJobsJson IS NULL
                SET @StepJobsJson = @StepActualJobsJson;
            ELSE IF @StepJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    <> @StepActualJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                THROW 55198, N'Die Jobausgabe hängt unzulässig vom Stepstatusschalter ab.', 1;
            DELETE FROM @ExpectedSteps;
            IF @StepProblemFlag = 0 OR @StepStatus IN (0, 2, 3)
                INSERT @ExpectedSteps VALUES
                (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
                 @StepStatus, @StepStatusDesc,
                 CONVERT(datetime, '2025-01-02T23:59:59', 126), 360000, 2,
                 N'Example controlled step outcome');
            IF @StepProblemFlag = 0
                INSERT @ExpectedSteps VALUES
                (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
                 1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
                 91801, 0, N'Example step counterexample');
            DELETE FROM @ActualSteps;
            INSERT @ActualSteps
            SELECT * FROM OPENJSON(@Json, '$.steps')
            WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                  [Subsystem] nvarchar(40), [LastRunOutcome] int,
                  [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                  [LastRunDurationSeconds] int, [LastRunRetries] int,
                  [LastRunMessage] nvarchar(4000));
            IF (SELECT COUNT_BIG(*) FROM @ActualSteps)
                   <> CASE WHEN @StepProblemFlag = 0 THEN 2
                           WHEN @StepStatus IN (0, 2, 3) THEN 1 ELSE 0 END
               OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
               OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                THROW 55198, N'Die zehn Stepwerte oder die statusabhängige Auswahl sind verletzt.', 1;
            SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                    <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Stepstatus-Aufruf hat Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @StepStatusCalls += 1;
            IF @StepProblemValue IS NULL SET @StepNullProblemCalls += 1;
            SET @StepProblemFlag += 1;
        END;
        SET @StepStatus += 1;
    END;
    IF @StepStatus <> 5 OR @StepStatusCalls <> 15 OR @StepNullProblemCalls <> 5
       OR @Calls <> 39
        THROW 55199, N'Die 15 Stepstatus-Aufrufe, fünf NULL-Aufrufe oder 39 positiven Consumeraufrufe fehlen.', 1;
    -- Ein Null-Datum wird mit fünf Uhrzeiten getrennt für Job und Step geprüft.
    DECLARE @ZeroClockCase int = 1, @ZeroClock int, @ZeroDateCase int,
        @ZeroDateCases int = 0, @ZeroDateCalls int = 0,
        @ZeroDateTableCalls int = 0, @ZeroNonzeroCalls int = 0,
        @ZeroJobHistoryId int, @ZeroJobRunDate int, @ZeroJobRunTime int,
        @ZeroStepRunDate int, @ZeroStepRunTime int,
        @ZeroExpectedJobStart datetime,
        @ZeroNoneJobsJson nvarchar(max), @ZeroNoneStepsJson nvarchar(max),
        @ZeroTableJobsJson nvarchar(max), @ZeroTableRows bigint,
        @ZeroTableJobId uniqueidentifier, @ZeroTableStart datetime,
        @ZeroTableSeconds int;
    SELECT TOP (1) @ZeroJobHistoryId = [instance_id],
        @ZeroJobRunDate = [run_date], @ZeroJobRunTime = [run_time]
    FROM [msdb].[dbo].[sysjobhistory]
    WHERE [job_id] = @JobId AND [step_id] = 0
    ORDER BY [instance_id] DESC;
    SELECT @ZeroStepRunDate = [run_date], @ZeroStepRunTime = [run_time]
    FROM [msdb].[dbo].[sysjobhistory]
    WHERE [instance_id] = @StepOneHistoryId
      AND [job_id] = @JobId AND [step_id] = 1;
    IF @ZeroJobHistoryId IS NULL OR @StepOneHistoryId IS NULL
       OR @ZeroJobRunDate <> 20250102 OR @ZeroJobRunTime <> 235959
       OR @ZeroStepRunDate <> 20250102 OR @ZeroStepRunTime <> 235959
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
        THROW 55199, N'Die jüngste eigene Job- oder Step-History für Null-Datumsfälle fehlt.', 1;
    WHILE @ZeroClockCase <= 5
    BEGIN
        SET @ZeroClock = CASE @ZeroClockCase
            WHEN 1 THEN 0 WHEN 2 THEN 236060 WHEN 3 THEN 240000
            WHEN 4 THEN 6000 ELSE 60 END;
        SET @ZeroDateCase = 1;
        WHILE @ZeroDateCase <= 2
        BEGIN
            UPDATE [msdb].[dbo].[sysjobhistory]
            SET [run_date] = CASE WHEN [instance_id] = @ZeroJobHistoryId
                    THEN CASE WHEN @ZeroDateCase = 1 THEN 0 ELSE @ZeroJobRunDate END
                    ELSE CASE WHEN @ZeroDateCase = 2 THEN 0 ELSE @ZeroStepRunDate END END,
                [run_time] = CASE WHEN [instance_id] = @ZeroJobHistoryId
                    THEN CASE WHEN @ZeroDateCase = 1 THEN @ZeroClock ELSE @ZeroJobRunTime END
                    ELSE CASE WHEN @ZeroDateCase = 2 THEN @ZeroClock ELSE @ZeroStepRunTime END END
            WHERE [job_id] = @JobId
              AND (([instance_id] = @ZeroJobHistoryId AND [step_id] = 0)
                OR ([instance_id] = @StepOneHistoryId AND [step_id] = 1));
            IF @@ROWCOUNT <> 2
                THROW 55199, N'Die eigenen Job- und Step-History-Daten wurden nicht eindeutig gesetzt.', 1;
        SET @ZeroExpectedJobStart = CASE WHEN @ZeroDateCase = 1 THEN NULL
            ELSE CONVERT(datetime, '2025-01-02T23:59:59', 126) END;
        DELETE FROM @ExpectedSteps;
        INSERT @ExpectedSteps VALUES
        (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
         4, N'IN_PROGRESS',
         CASE WHEN @ZeroDateCase = 2 THEN NULL
              ELSE CONVERT(datetime, '2025-01-02T23:59:59', 126) END,
         360000, 2, N'Example controlled step outcome'),
        (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
         1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
         91801, 0, N'Example step counterexample');
        SET @Consumer = 1;
        WHILE @Consumer <= 2
        BEGIN
            SELECT @Before = (SELECT
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
            ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
            ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
            ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
            ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
        JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
            ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @Before IS NULL OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Die Null-Datums-Fixture benötigt unveränderte Quellen und Calleroptionen.', 1;
            SELECT @Json = NULL, @ZeroTableJobsJson = NULL,
                @ZeroTableRows = NULL, @ZeroTableJobId = NULL,
                @ZeroTableStart = NULL, @ZeroTableSeconds = NULL;
            IF @Consumer = 1
            BEGIN
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
            END
            ELSE
            BEGIN
                CREATE TABLE [#AgentJobsZeroDateTable] ([Placeholder] int NULL);
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'TABLE',
                    @ResultTablesJson = N'{"jobs":"#AgentJobsZeroDateTable"}',
                    @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                SET @ZeroDateTableCalls += 1;
            END;
            IF XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Null-Datums-Aufruf hat Calleroptionen oder den Transaktionszustand verändert.', 1;
            IF COALESCE(ISJSON(@Json), 0) <> 1
               OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
               OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorNumber' AND [type] = 0) <> 1
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorMessage' AND [type] = 0) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1) <> 2
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps')) <> 2
                THROW 55198, N'Die Null-Datums-Metadaten oder Ergebnismengen sind verletzt.', 1;
            IF NOT EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                      [LastRunDateTime] datetime, [LastRunDurationSeconds] int,
                      [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                      [Enabled] bit, [StepCount] int, [ProblemCode] varchar(40))
                WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                  AND ((@ZeroDateCase = 1 AND [LastRunDateTime] IS NULL)
                    OR (@ZeroDateCase = 2 AND [LastRunDateTime] = @ZeroExpectedJobStart))
                  AND [LastRunDurationSeconds] = 360000
                  AND [LastRunStatus] = 1 AND [LastRunStatusDesc] = N'SUCCEEDED'
                  AND [Enabled] = 0 AND [StepCount] = 2 AND [ProblemCode] = 'DISABLED'
            )
                THROW 55198, N'Der eigene Job mit Null-Datum wurde nicht vertragsgemäß ausgegeben.', 1;
            IF @ZeroDateCase = 1
               AND (SELECT COUNT(*) FROM OPENJSON(@Json, '$.jobs') AS [j]
                    CROSS APPLY OPENJSON([j].[value]) AS [p]
                    WHERE [p].[key] = N'LastRunDateTime' AND [p].[type] = 0) <> 1
                THROW 55198, N'Das Job-Null-Datum fehlt als ausdrückliche JSON-Null.', 1;
            DELETE FROM @ActualSteps;
            INSERT @ActualSteps
            SELECT * FROM OPENJSON(@Json, '$.steps')
            WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                  [Subsystem] nvarchar(40), [LastRunOutcome] int,
                  [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                  [LastRunDurationSeconds] int, [LastRunRetries] int,
                  [LastRunMessage] nvarchar(4000));
            IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> 2
               OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
               OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                THROW 55198, N'Die zehn Stepwerte der Null-Datums-Fälle sind verletzt.', 1;
            IF @ZeroDateCase = 2
               AND (SELECT COUNT(*) FROM OPENJSON(@Json, '$.steps') AS [s]
                    CROSS APPLY OPENJSON([s].[value]) AS [p]
                    WHERE TRY_CONVERT(int, JSON_VALUE([s].[value], '$.StepId')) = 1
                      AND [p].[key] = N'LastRunDateTime' AND [p].[type] = 0) <> 1
                THROW 55198, N'Das Step-Null-Datum fehlt als ausdrückliche JSON-Null.', 1;
            IF @Consumer = 1
            BEGIN
                SET @ZeroNoneJobsJson = JSON_QUERY(@Json, '$.jobs');
                SET @ZeroNoneStepsJson = JSON_QUERY(@Json, '$.steps');
            END
            ELSE
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsZeroDateTable]),
                             @jobId = (SELECT TOP (1) [JobId] FROM [#AgentJobsZeroDateTable]),
                             @runStart = (SELECT TOP (1) [LastRunDateTime] FROM [#AgentJobsZeroDateTable]),
                             @seconds = (SELECT TOP (1) [LastRunDurationSeconds] FROM [#AgentJobsZeroDateTable]),
                             @jobsJson = (SELECT * FROM [#AgentJobsZeroDateTable]
                                 ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                    N'@rows bigint OUTPUT, @jobId uniqueidentifier OUTPUT,
                      @runStart datetime OUTPUT, @seconds int OUTPUT,
                      @jobsJson nvarchar(max) OUTPUT',
                    @rows = @ZeroTableRows OUTPUT, @jobId = @ZeroTableJobId OUTPUT,
                    @runStart = @ZeroTableStart OUTPUT, @seconds = @ZeroTableSeconds OUTPUT,
                    @jobsJson = @ZeroTableJobsJson OUTPUT;
                DELETE FROM @PositiveTableActualSchema;
                INSERT @PositiveTableActualSchema
                    ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                    [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    [c].[system_type_id]
                FROM [tempdb].[sys].[columns] AS [c]
                WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsZeroDateTable');
                IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                   )
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                   )
                    THROW 55198, N'Das AgentJobs-Null-Datums-TABLE-Schema ist verletzt.', 1;
                IF @ZeroTableRows IS NULL OR @ZeroTableRows <> 1
                   OR @ZeroTableJobId IS NULL OR @ZeroTableJobId <> @JobId
                   OR @ZeroTableSeconds IS NULL OR @ZeroTableSeconds <> 360000
                   OR (@ZeroDateCase = 1 AND @ZeroTableStart IS NOT NULL)
                   OR (@ZeroDateCase = 2 AND
                       (@ZeroTableStart IS NULL OR @ZeroTableStart <> @ZeroExpectedJobStart))
                    THROW 55198, N'Die nativen AgentJobs-TABLE-Null-Datumswerte sind verletzt.', 1;
                IF @ZeroTableJobsJson IS NULL OR @ZeroNoneJobsJson IS NULL
                   OR @ZeroNoneStepsJson IS NULL
                   OR @ZeroTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @ZeroTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @ZeroNoneJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @ZeroNoneStepsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.steps') COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 55198, N'Die Null-Datums-TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#AgentJobsZeroDateTable];
            END;
            SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                    <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Null-Datums-Aufruf hat Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @ZeroDateCalls += 1;
            IF @ZeroClock <> 0 SET @ZeroNonzeroCalls += 1;
            SET @Consumer += 1;
        END;
        SET @ZeroDateCases += 1;
        SET @ZeroDateCase += 1;
        END;
        SET @ZeroClockCase += 1;
    END;
    IF @ZeroClockCase <> 6 OR @ZeroDateCase <> 3 OR @ZeroDateCases <> 10
       OR @ZeroDateCalls <> 20 OR @ZeroDateTableCalls <> 10
       OR @ZeroNonzeroCalls <> 16 OR @Calls <> 59
        THROW 55199, N'Die zehn Null-Datumsfälle, 20 Aufrufe oder 59 positiven Consumeraufrufe fehlen.', 1;
    -- Sieben codierte Dauergrenzen werden getrennt von Datum und Status geprüft.
    DECLARE @DurationCases TABLE
    ([CaseId] int PRIMARY KEY, [RunDuration] int, [ExpectedSeconds] int);
    INSERT @DurationCases VALUES
    (1, 59, 59), (2, 100, 60), (3, 5959, 3599),
    (4, 10000, 3600), (5, 235959, 86399), (6, 240000, 86400),
    (7, 2147483647, 773095007);
    DECLARE @DurationCase int = 1, @DurationRaw int, @DurationSeconds int,
        @DurationCasesSeen int = 0, @DurationCalls int = 0,
        @DurationTableCalls int = 0, @DurationNoneCalls int = 0,
        @DurationNoneJobsJson nvarchar(max), @DurationNoneStepsJson nvarchar(max),
        @DurationTableJobsJson nvarchar(max), @DurationTableRows bigint,
        @DurationTableJobId uniqueidentifier, @DurationTableStart datetime,
        @DurationTableSeconds int;
    UPDATE [msdb].[dbo].[sysjobhistory]
    SET [run_date] = CASE WHEN [instance_id] = @ZeroJobHistoryId
            THEN @ZeroJobRunDate ELSE @ZeroStepRunDate END,
        [run_time] = CASE WHEN [instance_id] = @ZeroJobHistoryId
            THEN @ZeroJobRunTime ELSE @ZeroStepRunTime END
    WHERE [job_id] = @JobId
      AND (([instance_id] = @ZeroJobHistoryId AND [step_id] = 0)
        OR ([instance_id] = @StepOneHistoryId AND [step_id] = 1));
    IF @@ROWCOUNT <> 2
        THROW 55199, N'Die eigenen Job- und Step-Datumwerte wurden nicht eindeutig wiederhergestellt.', 1;
    WHILE @DurationCase <= 7
    BEGIN
        SELECT @DurationRaw = [RunDuration],
            @DurationSeconds = [ExpectedSeconds]
        FROM @DurationCases WHERE [CaseId] = @DurationCase;
        IF @DurationRaw IS NULL OR @DurationSeconds IS NULL
            THROW 55199, N'Der codierte Dauergrenzfall fehlt.', 1;
        UPDATE [msdb].[dbo].[sysjobhistory]
        SET [run_duration] = @DurationRaw
        WHERE [job_id] = @JobId
          AND (([instance_id] = @ZeroJobHistoryId AND [step_id] = 0)
            OR ([instance_id] = @StepOneHistoryId AND [step_id] = 1));
        IF @@ROWCOUNT <> 2
            THROW 55199, N'Die eigenen Job- und Step-Dauern wurden nicht eindeutig gesetzt.', 1;
        DELETE FROM @ExpectedSteps;
        INSERT @ExpectedSteps VALUES
        (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
         4, N'IN_PROGRESS', CONVERT(datetime, '2025-01-02T23:59:59', 126),
         @DurationSeconds, 2, N'Example controlled step outcome'),
        (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
         1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
         91801, 0, N'Example step counterexample');
        SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before IS NULL OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 55199, N'Die Dauergrenzfälle benötigen unveränderte Quellen und Calleroptionen.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 2
        BEGIN
            SELECT @Json = NULL, @DurationTableJobsJson = NULL,
                @DurationTableRows = NULL, @DurationTableJobId = NULL,
                @DurationTableStart = NULL, @DurationTableSeconds = NULL;
            IF @Consumer = 1
            BEGIN
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
                SET @DurationNoneCalls += 1;
            END
            ELSE
            BEGIN
                CREATE TABLE [#AgentJobsDurationBoundaryTable] ([Placeholder] int NULL);
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'TABLE',
                    @ResultTablesJson = N'{"jobs":"#AgentJobsDurationBoundaryTable"}',
                    @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                SET @DurationTableCalls += 1;
            END;
            IF XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Dauergrenzfall hat Calleroptionen oder den Transaktionszustand verändert.', 1;
            IF COALESCE(ISJSON(@Json), 0) <> 1
               OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
               OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorNumber' AND [type] = 0) <> 1
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorMessage' AND [type] = 0) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1) <> 2
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps')) <> 2
                THROW 55198, N'Die Dauergrenzfall-Metadaten oder Ergebnismengen sind verletzt.', 1;
            IF NOT EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                      [Enabled] bit, [IsRunning] bit, [RunStart] datetime,
                      [RunningMinutes] int, [LastRunDateTime] datetime,
                      [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                      [LastRunDurationSeconds] int, [LastMessage] nvarchar(4000),
                      [ScheduleCount] int, [EnabledScheduleCount] int,
                      [StepCount] int, [ProblemCode] varchar(40))
                WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                  AND [Enabled] = 0 AND [IsRunning] = 0
                  AND [RunStart] IS NULL AND [RunningMinutes] IS NULL
                  AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                  AND [LastRunStatus] = 1 AND [LastRunStatusDesc] = N'SUCCEEDED'
                  AND [LastRunDurationSeconds] = @DurationSeconds
                  AND [LastMessage] = N'Example controlled date and duration'
                  AND [ScheduleCount] = 0 AND [EnabledScheduleCount] = 0
                  AND [StepCount] = 2 AND [ProblemCode] = 'DISABLED'
            )
                THROW 55198, N'Der eigene Job mit codierter Dauer wurde nicht vertragsgemäß ausgegeben.', 1;
            DELETE FROM @ActualSteps;
            INSERT @ActualSteps
            SELECT * FROM OPENJSON(@Json, '$.steps')
            WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                  [Subsystem] nvarchar(40), [LastRunOutcome] int,
                  [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                  [LastRunDurationSeconds] int, [LastRunRetries] int,
                  [LastRunMessage] nvarchar(4000));
            IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> 2
               OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
               OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                THROW 55198, N'Die zehn Stepwerte der Dauergrenzfälle sind verletzt.', 1;
            IF @Consumer = 1
            BEGIN
                SET @DurationNoneJobsJson = JSON_QUERY(@Json, '$.jobs');
                SET @DurationNoneStepsJson = JSON_QUERY(@Json, '$.steps');
            END
            ELSE
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsDurationBoundaryTable]),
                             @jobId = (SELECT TOP (1) [JobId] FROM [#AgentJobsDurationBoundaryTable]),
                             @runStart = (SELECT TOP (1) [LastRunDateTime] FROM [#AgentJobsDurationBoundaryTable]),
                             @seconds = (SELECT TOP (1) [LastRunDurationSeconds] FROM [#AgentJobsDurationBoundaryTable]),
                             @jobsJson = (SELECT * FROM [#AgentJobsDurationBoundaryTable]
                                 ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                    N'@rows bigint OUTPUT, @jobId uniqueidentifier OUTPUT,
                      @runStart datetime OUTPUT, @seconds int OUTPUT,
                      @jobsJson nvarchar(max) OUTPUT',
                    @rows = @DurationTableRows OUTPUT, @jobId = @DurationTableJobId OUTPUT,
                    @runStart = @DurationTableStart OUTPUT,
                    @seconds = @DurationTableSeconds OUTPUT,
                    @jobsJson = @DurationTableJobsJson OUTPUT;
                DELETE FROM @PositiveTableActualSchema;
                INSERT @PositiveTableActualSchema
                    ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                    [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    [c].[system_type_id]
                FROM [tempdb].[sys].[columns] AS [c]
                WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsDurationBoundaryTable');
                IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                   )
                   OR EXISTS
                   (
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableExpectedSchema
                       EXCEPT
                       SELECT [LogicalOrdinal], [ColumnName], [SystemTypeId]
                       FROM @PositiveTableActualSchema
                   )
                    THROW 55198, N'Das AgentJobs-Dauergrenzfall-TABLE-Schema ist verletzt.', 1;
                IF @DurationTableRows IS NULL OR @DurationTableRows <> 1
                   OR @DurationTableJobId IS NULL OR @DurationTableJobId <> @JobId
                   OR @DurationTableStart IS NULL
                   OR @DurationTableStart <> CONVERT(datetime, '2025-01-02T23:59:59', 126)
                   OR @DurationTableSeconds IS NULL OR @DurationTableSeconds <> @DurationSeconds
                    THROW 55198, N'Die nativen AgentJobs-TABLE-Dauerwerte sind verletzt.', 1;
                IF @DurationTableJobsJson IS NULL OR @DurationNoneJobsJson IS NULL
                   OR @DurationNoneStepsJson IS NULL
                   OR @DurationTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @DurationTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @DurationNoneJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @DurationNoneStepsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.steps') COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 55198, N'Die Dauergrenzfall-TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#AgentJobsDurationBoundaryTable];
            END;
            SELECT @After = (SELECT
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                    ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                    ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                    ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                    ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                    ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                    ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                    <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Dauergrenzfall hat Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @DurationCalls += 1;
            SET @Consumer += 1;
        END;
        SET @DurationCasesSeen += 1;
        SET @DurationCase += 1;
    END;
    IF @DurationCase <> 8 OR @DurationCasesSeen <> 7
       OR @DurationCalls <> 14 OR @DurationNoneCalls <> 7
       OR @DurationTableCalls <> 7 OR @Calls <> 73
        THROW 55199, N'Die sieben Dauergrenzfälle, 14 Aufrufe oder 73 positiven Consumeraufrufe fehlen.', 1;
    -- Die jüngste Job-History prüft ihre Statusabbildung unabhängig von Step One.
    DECLARE @JobStatusCases TABLE
    ([RunStatus] int PRIMARY KEY,
     [StatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS);
    INSERT @JobStatusCases VALUES
    (0, N'FAILED'), (1, N'SUCCEEDED'), (2, N'RETRY'),
    (3, N'CANCELED'), (4, N'IN_PROGRESS');
    DECLARE @JobStatusCase int = 0, @JobStatusDesc nvarchar(60),
        @JobStatusCasesSeen int = 0, @JobStatusCalls int = 0,
        @JobStatusTableCalls int = 0, @JobStatusNoneJobsJson nvarchar(max),
        @JobStatusTableJobsJson nvarchar(max), @JobStatusTableRows bigint;
    UPDATE [msdb].[dbo].[sysjobhistory]
    SET [run_date] = 20250102, [run_time] = 235959,
        [run_duration] = 1000000
    WHERE [job_id] = @JobId
      AND (([instance_id] = @ZeroJobHistoryId AND [step_id] = 0)
        OR ([instance_id] = @StepOneHistoryId AND [step_id] = 1));
    IF @@ROWCOUNT <> 2
        THROW 55199, N'Die eigenen Job- und Step-Historywerte wurden nicht eindeutig wiederhergestellt.', 1;
    IF NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
        WHERE [instance_id] = @StepOneHistoryId AND [job_id] = @JobId
          AND [step_id] = 1 AND [run_status] = 4
          AND [run_date] = 20250102 AND [run_time] = 235959
          AND [run_duration] = 1000000
          AND [message] = N'Example controlled step outcome'
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
        WHERE [instance_id] = @ZeroJobHistoryId AND [job_id] = @JobId
          AND [step_id] = 0 AND [run_status] = 1
          AND [run_date] = 20250102 AND [run_time] = 235959
          AND [run_duration] = 1000000
          AND [message] = N'Example controlled date and duration'
    )
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
        THROW 55199, N'Die festen jüngsten Historyzeilen für die Jobstatusfälle fehlen.', 1;
        SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
    IF @Before IS NULL OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
       OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
        THROW 55199, N'Die Wiederherstellung der Jobstatusquellen oder Calleroptionen ist verletzt.', 1;
    WHILE @JobStatusCase <= 4
    BEGIN
        SELECT @JobStatusDesc = [StatusDesc]
        FROM @JobStatusCases WHERE [RunStatus] = @JobStatusCase;
        IF @JobStatusDesc IS NULL
            THROW 55199, N'Der feste Jobstatusfall fehlt.', 1;
        UPDATE [msdb].[dbo].[sysjobhistory]
        SET [run_status] = @JobStatusCase
        WHERE [instance_id] = @ZeroJobHistoryId
          AND [job_id] = @JobId AND [step_id] = 0;
        IF @@ROWCOUNT <> 1
            THROW 55199, N'Der jüngste eigene Jobstatus wurde nicht eindeutig gesetzt.', 1;
        SELECT @Before = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before IS NULL OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 55199, N'Der Jobstatusfall benötigt unveränderte Quellen und Calleroptionen.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 2
        BEGIN
            SELECT @Json = NULL, @JobStatusTableJobsJson = NULL,
                @JobStatusTableRows = NULL;
            IF @Consumer = 1
            BEGIN
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
                SET @JobStatusNoneJobsJson = NULL;
            END
            ELSE
            BEGIN
                CREATE TABLE [#AgentJobsJobStatusTable] ([Placeholder] int NULL);
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = 0, @NurProblematisch = 0,
                    @ResultSetArt = 'TABLE',
                    @ResultTablesJson = N'{"jobs":"#AgentJobsJobStatusTable"}',
                    @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                EXEC [sys].[sp_executesql]
                    N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsJobStatusTable]),
                             @jobsJson = (SELECT * FROM [#AgentJobsJobStatusTable]
                                 ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                    N'@rows bigint OUTPUT, @jobsJson nvarchar(max) OUTPUT',
                    @rows = @JobStatusTableRows OUTPUT,
                    @jobsJson = @JobStatusTableJobsJson OUTPUT;
                DELETE FROM @PositiveTableActualSchema;
                INSERT @PositiveTableActualSchema
                    ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                    [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                    [c].[system_type_id]
                FROM [tempdb].[sys].[columns] AS [c]
                WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsJobStatusTable');
                IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                   OR EXISTS
                   (
                       SELECT * FROM @PositiveTableActualSchema
                       EXCEPT SELECT * FROM @PositiveTableExpectedSchema
                   )
                   OR EXISTS
                   (
                       SELECT * FROM @PositiveTableExpectedSchema
                       EXCEPT SELECT * FROM @PositiveTableActualSchema
                   )
                    THROW 55198, N'Das native Jobstatus-TABLE-Schema ist verletzt.', 1;
            END;
            IF XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Jobstatusaufruf hat Calleroptionen oder den Transaktionszustand verändert.', 1;
            IF COALESCE(ISJSON(@Json), 0) <> 1
               OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
               OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorNumber' AND [type] = 0) <> 1
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorMessage' AND [type] = 0) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1) <> 2
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps')) <> 2
                THROW 55198, N'Die Jobstatus-Metadaten oder Ergebnismengen sind verletzt.', 1;
            IF NOT EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                      [Enabled] bit, [IsRunning] bit, [RunStart] datetime,
                      [RunningMinutes] int, [LastRunDateTime] datetime,
                      [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                      [LastRunDurationSeconds] int, [LastMessage] nvarchar(4000),
                      [ScheduleCount] int, [EnabledScheduleCount] int,
                      [StepCount] int, [ProblemCode] varchar(40))
                WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                  AND [Enabled] = 0 AND [IsRunning] = 0
                  AND [RunStart] IS NULL AND [RunningMinutes] IS NULL
                  AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                  AND [LastRunStatus] = @JobStatusCase
                  AND [LastRunStatusDesc] = @JobStatusDesc
                  AND [LastRunDurationSeconds] = 360000
                  AND [LastMessage] = N'Example controlled date and duration'
                  AND [ScheduleCount] = 0 AND [EnabledScheduleCount] = 0
                  AND [StepCount] = 2 AND [ProblemCode] = 'DISABLED'
            )
                THROW 55198, N'Die fünf festen Jobstatuswerte sind verletzt.', 1;
            DELETE FROM @ExpectedSteps;
            INSERT @ExpectedSteps VALUES
            (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
             4, N'IN_PROGRESS', CONVERT(datetime, '2025-01-02T23:59:59', 126),
             360000, 2, N'Example controlled step outcome'),
            (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
             1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
             91801, 0, N'Example step counterexample');
            DELETE FROM @ActualSteps;
            INSERT @ActualSteps
            SELECT * FROM OPENJSON(@Json, '$.steps')
            WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                  [Subsystem] nvarchar(40), [LastRunOutcome] int,
                  [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                  [LastRunDurationSeconds] int, [LastRunRetries] int,
                  [LastRunMessage] nvarchar(4000));
            IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> 2
               OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
               OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                THROW 55198, N'Die zehn Stepwerte der Jobstatusfälle sind verletzt.', 1;
            IF @Consumer = 1
                SET @JobStatusNoneJobsJson = JSON_QUERY(@Json, '$.jobs');
            IF @Consumer = 2
            BEGIN
                IF @JobStatusTableRows IS NULL OR @JobStatusTableRows <> 1
                   OR @JobStatusTableJobsJson IS NULL OR @JobStatusNoneJobsJson IS NULL
                   OR @JobStatusTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @JobStatusTableJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @JobStatusNoneJobsJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 55198, N'Die native Jobstatus-TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#AgentJobsJobStatusTable];
                SET @JobStatusTableCalls += 1;
            END;
        SELECT @After = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                    <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                THROW 55199, N'Der Jobstatusaufruf hat Agentquellen oder Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @JobStatusCalls += 1;
            SET @Consumer += 1;
        END;
        SET @JobStatusCasesSeen += 1;
        SET @JobStatusCase += 1;
    END;
    IF @JobStatusCase <> 5 OR @JobStatusCasesSeen <> 5
       OR @JobStatusCalls <> 10 OR @JobStatusTableCalls <> 5 OR @Calls <> 83
        THROW 55199, N'Die fünf Jobstatusfälle, zehn Aufrufe oder 83 positiven Consumeraufrufe fehlen.', 1;
    -- Der eigene aktivierte Job bleibt ohne Ausführungsbindung und Schedule.
    DECLARE @ProblemStatus int = 0, @ProblemFlagCase int, @ProblemConsumer int,
        @ProblemFlag bit, @ProblemCode varchar(40), @ProblemDesc nvarchar(60),
        @ProblemCases int = 0, @ProblemCalls int = 0, @ProblemTableCalls int = 0,
        @ProblemNullCalls int = 0, @ProblemRows bigint,
        @ProblemNoneJobs nvarchar(max), @ProblemTableJobs nvarchar(max);
    UPDATE [msdb].[dbo].[sysjobs] SET [enabled] = 1
    WHERE [job_id] = @JobId AND [name] = N'ExampleOps008HistoryJob' AND [enabled] = 0;
    IF @@ROWCOUNT <> 1 THROW 55199, N'Der eigene Job wurde nicht eindeutig aktiviert.', 1;
    UPDATE [msdb].[dbo].[sysjobhistory]
    SET [run_date] = 20250102, [run_time] = 235959, [run_duration] = 1000000
    WHERE [job_id] = @JobId
      AND (([instance_id] = @ZeroJobHistoryId AND [step_id] = 0)
        OR ([instance_id] = @StepOneHistoryId AND [step_id] = 1));
    IF @@ROWCOUNT <> 2 THROW 55199, N'Die festen Historywerte fehlen.', 1;
    UPDATE [msdb].[dbo].[sysjobhistory] SET [run_status] = 0
    WHERE [instance_id] = @ZeroJobHistoryId AND [job_id] = @JobId AND [step_id] = 0;
    IF @@ROWCOUNT <> 1 THROW 55199, N'Der feste anfängliche Jobproblemstatus fehlt.', 1;
    IF NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
                   WHERE [instance_id] = @StepOneHistoryId AND [job_id] = @JobId
                     AND [step_id] = 1 AND [run_status] = 4
                     AND [run_date] = 20250102 AND [run_time] = 235959
                     AND [run_duration] = 1000000
                     AND [message] = N'Example controlled step outcome')
       OR NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
                      WHERE [instance_id] = @ZeroJobHistoryId AND [job_id] = @JobId
                        AND [step_id] = 0 AND [run_status] = 0
                        AND [run_date] = 20250102 AND [run_time] = 235959
                        AND [run_duration] = 1000000
                        AND [message] = N'Example controlled date and duration')
       OR NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
                      WHERE [job_id] = @JobId AND [step_id] = 2
                        AND [run_status] = 1 AND [run_date] = 20001231
                        AND [run_time] = 112233 AND [run_duration] = 253001
                        AND [message] = N'Example step counterexample')
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
        THROW 55199, N'Der Jobproblem-Setup ist verletzt.', 1;
    SELECT @Before = (SELECT
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs] ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps] ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory] ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity] ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers] ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules] ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
    IF @Before IS NULL OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
       OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
        THROW 55199, N'Der Jobproblem-Setupguard ist verletzt.', 1;
    WHILE @ProblemStatus <= 1
    BEGIN
        SELECT @ProblemCode = CASE @ProblemStatus WHEN 0 THEN 'LAST_FAILED' ELSE 'NO_SCHEDULE' END,
               @ProblemDesc = CASE @ProblemStatus WHEN 0 THEN N'FAILED' ELSE N'SUCCEEDED' END;
        UPDATE [msdb].[dbo].[sysjobhistory] SET [run_status] = @ProblemStatus
        WHERE [instance_id] = @ZeroJobHistoryId AND [job_id] = @JobId AND [step_id] = 0;
        IF @@ROWCOUNT <> 1 THROW 55199, N'Der eigene Jobproblemstatus wurde nicht eindeutig gesetzt.', 1;
        SELECT @Before = (SELECT
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs] ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps] ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory] ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity] ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers] ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules] ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before IS NULL OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
            THROW 55199, N'Der Jobproblemfall benötigt unveränderte Quellen und Calleroptionen.', 1;
        SET @ProblemFlagCase = 0;
        WHILE @ProblemFlagCase <= 2
        BEGIN
            SET @ProblemFlag = CASE @ProblemFlagCase WHEN 0 THEN CONVERT(bit, 0)
                WHEN 1 THEN CONVERT(bit, 1) ELSE CONVERT(bit, NULL) END;
            SET @ProblemConsumer = 1;
            SET @ProblemNoneJobs = NULL;
            WHILE @ProblemConsumer <= 2
            BEGIN
                SELECT @Json = NULL, @ProblemTableJobs = NULL, @ProblemRows = NULL;
                IF @ProblemConsumer = 1
                    EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                        @MaxZeilen = 0, @NurProblematisch = @ProblemFlag,
                        @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                        @Json = @Json OUTPUT, @PrintMeldungen = 0;
                ELSE
                BEGIN
                    CREATE TABLE [#AgentJobsProblemTable] ([Placeholder] int NULL);
                    EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                        @MaxZeilen = 0, @NurProblematisch = @ProblemFlag,
                        @ResultSetArt = 'TABLE',
                        @ResultTablesJson = N'{"jobs":"#AgentJobsProblemTable"}',
                        @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                END;
                SELECT @After = (SELECT
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs] ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps] ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory] ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity] ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers] ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
 JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules] ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
                IF @Before IS NULL OR @After IS NULL
                   OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
                   OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
                   OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
                   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
                   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
                   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
                    THROW 55199, N'Der Jobproblemaufruf hat Quellen oder Callerzustand verändert.', 1;
                IF COALESCE(ISJSON(@Json), 0) <> 1
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
                   OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
                   OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                       WHERE [key] = N'errorNumber' AND [type] = 0) <> 1
                   OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                       WHERE [key] = N'errorMessage' AND [type] = 0) <> 1
                   OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
                   OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1)
                      <> CASE WHEN @ProblemFlagCase = 0 THEN 2 ELSE 0 END
                   OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
                   OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
                   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps'))
                      <> CASE WHEN @ProblemFlagCase = 0 THEN 2 ELSE 0 END
                    THROW 55198, N'Die Jobproblem-Metadaten oder Ergebnismengen sind verletzt.', 1;
                IF @ProblemFlagCase <> 0 AND COALESCE(JSON_QUERY(@Json, '$.steps'), N'') <> N'[]'
                    THROW 55198, N'Das gefilterte Jobproblem-Step-Array ist nicht ausdrücklich leer.', 1;
                IF NOT EXISTS
                (
                    SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                    WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                          [Enabled] bit, [IsRunning] bit, [RunStart] datetime,
                          [RunningMinutes] int, [LastRunDateTime] datetime,
                          [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                          [LastRunDurationSeconds] int, [LastMessage] nvarchar(4000),
                          [ScheduleCount] int, [EnabledScheduleCount] int,
                          [StepCount] int, [ProblemCode] varchar(40))
                    WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                      AND [Enabled] = 1 AND [IsRunning] = 0
                      AND [RunStart] IS NULL AND [RunningMinutes] IS NULL
                      AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                      AND [LastRunStatus] = @ProblemStatus AND [LastRunStatusDesc] = @ProblemDesc
                      AND [LastRunDurationSeconds] = 360000
                      AND [LastMessage] = N'Example controlled date and duration'
                      AND [ScheduleCount] = 0 AND [EnabledScheduleCount] = 0
                      AND [StepCount] = 2 AND [ProblemCode] = @ProblemCode
                ) THROW 55198, N'Die festen Jobproblemwerte sind verletzt.', 1;
                IF @ProblemFlagCase = 0
                BEGIN
                    DELETE FROM @ExpectedSteps;
                    INSERT @ExpectedSteps VALUES
                    (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
                     4, N'IN_PROGRESS', CONVERT(datetime, '2025-01-02T23:59:59', 126),
                     360000, 2, N'Example controlled step outcome'),
                    (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
                     1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
                     91801, 0, N'Example step counterexample');
                    DELETE FROM @ActualSteps;
                    INSERT @ActualSteps SELECT * FROM OPENJSON(@Json, '$.steps')
                    WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                          [Subsystem] nvarchar(40), [LastRunOutcome] int,
                          [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                          [LastRunDurationSeconds] int, [LastRunRetries] int,
                          [LastRunMessage] nvarchar(4000));
                    IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> 2
                       OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
                       OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                        THROW 55198, N'Die zehn Stepwerte des ungefilterten Jobproblemfalls sind verletzt.', 1;
                END;
                IF @ProblemConsumer = 1 SET @ProblemNoneJobs = JSON_QUERY(@Json, '$.jobs');
                ELSE
                BEGIN
                    EXEC [sys].[sp_executesql]
                        N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsProblemTable]),
                                 @jobsJson = (SELECT * FROM [#AgentJobsProblemTable]
                                     ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                        N'@rows bigint OUTPUT, @jobsJson nvarchar(max) OUTPUT',
                        @rows = @ProblemRows OUTPUT, @jobsJson = @ProblemTableJobs OUTPUT;
                    DELETE FROM @PositiveTableActualSchema;
                    INSERT @PositiveTableActualSchema
                        ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                    SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                        [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS, [c].[system_type_id]
                    FROM [tempdb].[sys].[columns] AS [c]
                    WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsProblemTable');
                    IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                       OR EXISTS (SELECT * FROM @PositiveTableActualSchema
                                  EXCEPT SELECT * FROM @PositiveTableExpectedSchema)
                       OR EXISTS (SELECT * FROM @PositiveTableExpectedSchema
                                  EXCEPT SELECT * FROM @PositiveTableActualSchema)
                       OR @ProblemRows IS NULL OR @ProblemRows <> 1
                       OR @ProblemTableJobs IS NULL OR @ProblemNoneJobs IS NULL
                       OR @ProblemTableJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                          <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                       OR @ProblemTableJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                          <> @ProblemNoneJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                        THROW 55198, N'Die native Jobproblem-TABLE-/JSON-Parität ist verletzt.', 1;
                    DROP TABLE [#AgentJobsProblemTable];
                    SET @ProblemTableCalls += 1;
                END;
                SET @Calls += 1;
                SET @ProblemCalls += 1;
                IF @ProblemFlag IS NULL SET @ProblemNullCalls += 1;
                SET @ProblemConsumer += 1;
            END;
            SET @ProblemCases += 1;
            SET @ProblemFlagCase += 1;
        END;
        SET @ProblemStatus += 1;
    END;
    IF @ProblemStatus <> 2 OR @ProblemCases <> 6 OR @ProblemCalls <> 12
       OR @ProblemTableCalls <> 6 OR @ProblemNullCalls <> 4 OR @Calls <> 95
        THROW 55199, N'Die sechs Jobproblemfälle, zwölf Aufrufe oder 95 positiven Consumeraufrufe fehlen.', 1;

    -- Die bestehende positive Fixture prüft hier erstmals tatsächliche History-Zeilen unter einer Grenze.
    DECLARE @HistoryLimitCase int = 1, @HistoryLimitConsumer int,
        @HistoryMaxZeilen int, @HistoryExpectedStepCount int,
        @HistoryLimitCases int = 0, @HistoryLimitCalls int = 0,
        @HistoryLimitTableCalls int = 0, @HistoryLimitNullCalls int = 0,
        @HistoryLimitTableRows bigint, @HistoryLimitTableJobs nvarchar(max),
        @HistoryLimitNoneJobs nvarchar(max), @HistoryLimitNoneSteps nvarchar(max);
    IF NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobs]
        WHERE [job_id] = @JobId AND [name] = N'ExampleOps008HistoryJob' AND [enabled] = 1
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
        WHERE [instance_id] = @ZeroJobHistoryId AND [job_id] = @JobId
          AND [step_id] = 0 AND [run_status] = 1
          AND [run_date] = 20250102 AND [run_time] = 235959
          AND [run_duration] = 1000000
          AND [message] = N'Example controlled date and duration'
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
        WHERE [instance_id] = @StepOneHistoryId AND [job_id] = @JobId
          AND [step_id] = 1 AND [run_status] = 4
          AND [run_date] = 20250102 AND [run_time] = 235959
          AND [run_duration] = 1000000
          AND [retries_attempted] = 2
          AND [message] = N'Example controlled step outcome'
    )
       OR NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysjobhistory]
        WHERE [job_id] = @JobId AND [step_id] = 2 AND [run_status] = 1
          AND [run_date] = 20001231 AND [run_time] = 112233
          AND [run_duration] = 253001 AND [retries_attempted] = 0
          AND [message] = N'Example step counterexample'
    )
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
       OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
       OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
        THROW 55199, N'Die feste Ausgangslage der History-Grenzfälle ist verletzt.', 1;
    WHILE @HistoryLimitCase <= 4
    BEGIN
        SET @HistoryMaxZeilen = CASE @HistoryLimitCase
            WHEN 1 THEN NULL WHEN 2 THEN 0 WHEN 3 THEN 1 ELSE 2 END;
        SET @HistoryExpectedStepCount = CASE WHEN @HistoryLimitCase = 3 THEN 1 ELSE 2 END;
        SET @HistoryLimitNoneJobs = NULL;
        SET @HistoryLimitNoneSteps = NULL;
        SELECT @Before = (SELECT
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs] ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps] ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory] ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity] ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers] ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules] ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        IF @Before IS NULL OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 55199, N'Der History-Grenzfall benötigt einen vollständigen Quell- und Callerguard.', 1;
        SET @HistoryLimitConsumer = 1;
        WHILE @HistoryLimitConsumer <= 2
        BEGIN
            SELECT @Json = NULL, @HistoryLimitTableRows = NULL, @HistoryLimitTableJobs = NULL;
            IF @HistoryLimitConsumer = 1
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = @HistoryMaxZeilen, @NurProblematisch = 0,
                    @ResultSetArt = 'NONE', @JsonErzeugen = 1,
                    @Json = @Json OUTPUT, @PrintMeldungen = 0;
            ELSE
            BEGIN
                CREATE TABLE [#AgentJobsHistoryLimitTable] ([Placeholder] int NULL);
                EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                    @MaxZeilen = @HistoryMaxZeilen, @NurProblematisch = 0,
                    @ResultSetArt = 'TABLE',
                    @ResultTablesJson = N'{"jobs":"#AgentJobsHistoryLimitTable"}',
                    @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
            END;
            SELECT @After = (SELECT
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs] ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps] ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory] ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity] ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers] ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
  JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules] ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
            IF @After IS NULL
               OR @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                  <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> 12
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
               OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
                THROW 55199, N'Der History-Grenzaufruf hat Quellen oder Callerzustand verändert.', 1;
            IF COALESCE(ISJSON(@Json), 0) <> 1
               OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'AVAILABLE'
               OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'false'
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorNumber' AND [type] = 0) <> 1
               OR (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                   WHERE [key] = N'errorMessage' AND [type] = 0) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.jobCount')), -1) <> 1
               OR COALESCE(TRY_CONVERT(bigint, JSON_VALUE(@Json, '$.meta.stepCount')), -1)
                  <> @HistoryExpectedStepCount
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.jobs')), 1), N'') <> N'['
               OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Json, '$.steps')), 1), N'') <> N'['
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> 1
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps'))
                  <> @HistoryExpectedStepCount
               OR (@HistoryMaxZeilen IS NULL AND
                   (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                    WHERE [key] = N'requestedMaxRows' AND [type] = 0) <> 1)
               OR (@HistoryMaxZeilen IS NOT NULL AND
                   (SELECT COUNT(*) FROM OPENJSON(@Json, '$.meta')
                    WHERE [key] = N'requestedMaxRows' AND [type] = 2
                      AND TRY_CONVERT(int, [value]) = @HistoryMaxZeilen) <> 1)
                THROW 55198, N'Die History-Grenzmetadaten oder Ergebnismengen sind verletzt.', 1;
            IF NOT EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json, '$.jobs')
                WITH ([JobId] uniqueidentifier, [JobName] nvarchar(128),
                      [Enabled] bit, [IsRunning] bit, [RunStart] datetime,
                      [RunningMinutes] int, [LastRunDateTime] datetime,
                      [LastRunStatus] int, [LastRunStatusDesc] nvarchar(60),
                      [LastRunDurationSeconds] int, [LastMessage] nvarchar(4000),
                      [ScheduleCount] int, [EnabledScheduleCount] int,
                      [StepCount] int, [ProblemCode] varchar(40))
                WHERE [JobId] = @JobId AND [JobName] = N'ExampleOps008HistoryJob'
                  AND [Enabled] = 1 AND [IsRunning] = 0
                  AND [RunStart] IS NULL AND [RunningMinutes] IS NULL
                  AND [LastRunDateTime] = CONVERT(datetime, '2025-01-02T23:59:59', 126)
                  AND [LastRunStatus] = 1 AND [LastRunStatusDesc] = N'SUCCEEDED'
                  AND [LastRunDurationSeconds] = 360000
                  AND [LastMessage] = N'Example controlled date and duration'
                  AND [ScheduleCount] = 0 AND [EnabledScheduleCount] = 0
                  AND [StepCount] = 2 AND [ProblemCode] = 'NO_SCHEDULE'
            )
                THROW 55198, N'Die festen Jobwerte der History-Grenzfälle sind verletzt.', 1;
            DELETE FROM @ExpectedSteps;
            INSERT @ExpectedSteps VALUES
                (N'ExampleOps008HistoryJob', 1, N'ExampleHistoryStepOne', N'TSQL',
                 4, N'IN_PROGRESS', CONVERT(datetime, '2025-01-02T23:59:59', 126),
                 360000, 2, N'Example controlled step outcome');
            IF @HistoryExpectedStepCount = 2
                INSERT @ExpectedSteps VALUES
                    (N'ExampleOps008HistoryJob', 2, N'ExampleHistoryStepTwo', N'TSQL',
                     1, N'SUCCEEDED', CONVERT(datetime, '2000-12-31T11:22:33', 126),
                     91801, 0, N'Example step counterexample');
            DELETE FROM @ActualSteps;
            INSERT @ActualSteps SELECT * FROM OPENJSON(@Json, '$.steps')
            WITH ([JobName] nvarchar(128), [StepId] int, [StepName] nvarchar(128),
                  [Subsystem] nvarchar(40), [LastRunOutcome] int,
                  [LastRunOutcomeDesc] nvarchar(60), [LastRunDateTime] datetime,
                  [LastRunDurationSeconds] int, [LastRunRetries] int,
                  [LastRunMessage] nvarchar(4000));
            IF (SELECT COUNT_BIG(*) FROM @ActualSteps) <> @HistoryExpectedStepCount
               OR EXISTS (SELECT * FROM @ExpectedSteps EXCEPT SELECT * FROM @ActualSteps)
               OR EXISTS (SELECT * FROM @ActualSteps EXCEPT SELECT * FROM @ExpectedSteps)
                THROW 55198, N'Die zehn Stepwerte der History-Grenzfälle sind verletzt.', 1;
            IF @HistoryLimitConsumer = 1
            BEGIN
                SET @HistoryLimitNoneJobs = JSON_QUERY(@Json, '$.jobs');
                SET @HistoryLimitNoneSteps = JSON_QUERY(@Json, '$.steps');
            END
            ELSE
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsHistoryLimitTable]),
                             @jobsJson = (SELECT * FROM [#AgentJobsHistoryLimitTable]
                                 ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                    N'@rows bigint OUTPUT, @jobsJson nvarchar(max) OUTPUT',
                    @rows = @HistoryLimitTableRows OUTPUT,
                    @jobsJson = @HistoryLimitTableJobs OUTPUT;
                DELETE FROM @PositiveTableActualSchema;
                INSERT @PositiveTableActualSchema
                    ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                    [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS, [c].[system_type_id]
                FROM [tempdb].[sys].[columns] AS [c]
                WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsHistoryLimitTable');
                IF (SELECT COUNT(*) FROM @PositiveTableActualSchema) <> 17
                   OR EXISTS (SELECT * FROM @PositiveTableActualSchema
                              EXCEPT SELECT * FROM @PositiveTableExpectedSchema)
                   OR EXISTS (SELECT * FROM @PositiveTableExpectedSchema
                              EXCEPT SELECT * FROM @PositiveTableActualSchema)
                   OR @HistoryLimitTableRows IS NULL OR @HistoryLimitTableRows <> 1
                   OR @HistoryLimitTableJobs IS NULL
                   OR @HistoryLimitNoneJobs IS NULL OR @HistoryLimitNoneSteps IS NULL
                   OR @HistoryLimitTableJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> JSON_QUERY(@Json, '$.jobs') COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR @HistoryLimitTableJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @HistoryLimitNoneJobs COLLATE SQL_Latin1_General_CP1_CS_AS
                   OR JSON_QUERY(@Json, '$.steps') COLLATE SQL_Latin1_General_CP1_CS_AS
                      <> @HistoryLimitNoneSteps COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 55198, N'Die History-Grenzparität von TABLE und JSON ist verletzt.', 1;
                DROP TABLE [#AgentJobsHistoryLimitTable];
                SET @HistoryLimitTableCalls += 1;
            END;
            SET @Calls += 1;
            SET @HistoryLimitCalls += 1;
            IF @HistoryMaxZeilen IS NULL SET @HistoryLimitNullCalls += 1;
            SET @HistoryLimitConsumer += 1;
        END;
        SET @HistoryLimitCases += 1;
        SET @HistoryLimitCase += 1;
    END;
    IF @HistoryLimitCase <> 5 OR @HistoryLimitCases <> 4
       OR @HistoryLimitCalls <> 8 OR @HistoryLimitTableCalls <> 4
       OR @HistoryLimitNullCalls <> 2 OR @Calls <> 103
        THROW 55199, N'Die vier History-Grenzfälle, acht Aufrufe oder 103 positiven Consumeraufrufe fehlen.', 1;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
        THROW 54947, N'Die reine Tabellenfixture darf keine Agent-Ausführungsbindung besitzen.', 1;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
        THROW 54948, N'Die synthetische Agent-Fixture wurde nicht vollständig zurückgerollt.', 1;

    DECLARE @CalendarOption int = 0, @CalendarExpectedMask int,
        @CalendarOptionCallsStart int, @CalendarOptionRollbacksStart int;
    DECLARE @CalendarCase int = 1, @CalendarConsumer int, @CalendarDate int,
        @CalendarRunTime int, @CalendarReturn int,
        @CalendarBadStep bit, @CalendarCalls int = 0, @CalendarRollbacks int = 0,
        @CalendarBaseline nvarchar(max), @CalendarBefore nvarchar(max),
        @CalendarAfter nvarchar(max), @CalendarState int;
    DECLARE @CalendarTableRows bigint, @CalendarTableJobId uniqueidentifier,
        @CalendarTableRunDate datetime, @CalendarTableDuration int, @CalendarTableJson nvarchar(max);
    DECLARE @CalendarTableSchema TABLE
    (
        [LogicalOrdinal] int NOT NULL,
        [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SystemTypeId] int NOT NULL
    );
            SELECT @CalendarBaseline = (SELECT
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
            JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
    WHILE @CalendarOption < 2
    BEGIN
        SET @CalendarExpectedMask = CASE WHEN @CalendarOption = 0 THEN 16384 ELSE 0 END;
        IF @CalendarExpectedMask = 16384 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        SET @CalendarCase = 1;
        SET @CalendarOptionCallsStart = @CalendarCalls;
        SET @CalendarOptionRollbacksStart = @CalendarRollbacks;
        WHILE @CalendarCase <= 12
        BEGIN
            SELECT @CalendarDate = CASE WHEN @CalendarCase <= 2 THEN 20230229
                    WHEN @CalendarCase <= 4 THEN 20240230 ELSE 20240229 END,
                @CalendarRunTime = CASE WHEN @CalendarCase <= 4 THEN 0
                    WHEN @CalendarCase <= 6 THEN 236060
                    WHEN @CalendarCase <= 8 THEN 240000
                    WHEN @CalendarCase <= 10 THEN 6000 ELSE 60 END,
                @CalendarBadStep = CASE WHEN @CalendarCase % 2 = 0 THEN 1 ELSE 0 END,
                @CalendarConsumer = 1;
            WHILE @CalendarConsumer <= 3
            BEGIN
                SET @JobId = NULL;
                BEGIN TRANSACTION;
                EXEC @CalendarReturn = [msdb].[dbo].[sp_add_job]
                    @job_name = N'ExampleOps008HistoryJob', @enabled = 0,
                    @notify_level_eventlog = 0, @notify_level_email = 0,
                    @notify_level_netsend = 0, @notify_level_page = 0,
                    @delete_level = 0, @job_id = @JobId OUTPUT;
                IF @CalendarReturn <> 0 OR @JobId IS NULL
                    THROW 56214, N'Die eigene Kalenderfixture fehlt.', 1;
                EXEC @CalendarReturn = [msdb].[dbo].[sp_add_jobstep]
                    @job_id = @JobId, @step_id = 1, @step_name = N'ExampleCalendarStep',
                    @subsystem = N'TSQL', @command = N'SELECT 1 AS ExampleValue;',
                    @database_name = N'master', @on_success_action = 1,
                    @on_fail_action = 2, @retry_attempts = 0;
                IF @CalendarReturn <> 0
                    THROW 56214, N'Die eigene Kalenderschrittdefinition fehlt.', 1;
                INSERT [msdb].[dbo].[sysjobhistory]
                    ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
                     [message], [run_status], [run_date], [run_time], [run_duration],
                     [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
                     [retries_attempted], [server])
                VALUES (@JobId, 0, N'ExampleJobOutcome', 0, 0, N'ExampleCalendarOutcome', 1,
                    CASE WHEN @CalendarBadStep = 1 THEN 20240229 ELSE @CalendarDate END,
                    CASE WHEN @CalendarBadStep = 1 THEN 0 ELSE @CalendarRunTime END,
                    125, 0, 0, 0, 0, N'ExampleHistoryServer');
                IF @CalendarBadStep = 1
                    INSERT [msdb].[dbo].[sysjobhistory]
                        ([job_id], [step_id], [step_name], [sql_message_id], [sql_severity],
                         [message], [run_status], [run_date], [run_time], [run_duration],
                         [operator_id_emailed], [operator_id_netsent], [operator_id_paged],
                         [retries_attempted], [server])
                    VALUES (@JobId, 1, N'ExampleCalendarStep', 0, 0, N'ExampleCalendarStep',
                        1, @CalendarDate, @CalendarRunTime, 125, 0, 0, 0, 0, N'ExampleHistoryServer');
                SELECT @CalendarBefore = (SELECT
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                    ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                    ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                    ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                    ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                    ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                    ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
                SET @CalendarState = XACT_STATE();
                IF @CalendarState <> 1 OR @@TRANCOUNT <> 1
                    OR (@@OPTIONS & 16384) <> @CalendarExpectedMask OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
                    THROW 56215, N'Der Kalenderaufruf benötigt die schreibfähige Transaktion mit der gewählten XACT_ABORT-Einstellung.', 1;
                SELECT @Json = NULL, @Status = NULL, @Partial = NULL,
                    @Error = NULL, @Message = NULL;
                IF @CalendarConsumer = 1
                BEGIN
                    EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                        @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                        @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                        @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                        @ErrorMessageOut = @Message OUTPUT;
                    IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 1) <> 0
                        OR @Error IS NOT NULL OR @Message IS NOT NULL
                        OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json)
                            WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint)
                            WHERE [Area] = 'AGENT_HISTORY'
                              AND [SourceObject] = N'msdb.dbo.sysjobhistory'
                              AND [RowCount] = CASE WHEN @CalendarBadStep = 1 THEN 2 ELSE 1 END)
                        THROW 56216, N'Das kalenderunabhängige Msdb-Aggregat ist verletzt.', 1;
                END
                ELSE IF @CalendarConsumer = 2
                BEGIN
                    EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                        @MaxZeilen = 0, @NurProblematisch = 0, @ResultSetArt = 'NONE',
                        @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                    IF XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
                        OR (@@OPTIONS & 16384) <> @CalendarExpectedMask
                        OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
                        THROW 56217, N'Der AgentJobs-NONE-Aufruf hat Calleroptionen oder den Transaktionszustand verändert.', 1;
                    IF COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '') <> 'ERROR_HANDLED'
                        OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), '') <> 'true'
                        OR COALESCE(TRY_CONVERT(int, JSON_VALUE(@Json, '$.meta.errorNumber')), 0) <> 242
                        OR NULLIF(JSON_VALUE(@Json, '$.meta.errorMessage'), N'') IS NULL
                        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> CONVERT(int, @CalendarBadStep)
                        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps')) <> 0
                        THROW 56216, N'Der abgefangene AgentJobs-Kalenderfehler ist verletzt.', 1;

                    IF @CalendarCase <= 12
                    BEGIN
                        CREATE TABLE [#AgentJobsCalendarTable] ([Placeholder] int NULL);
                        EXEC [monitor].[USP_AgentJobs] @JobNames = N'[ExampleOps008HistoryJob]',
                            @MaxZeilen = 0, @NurProblematisch = 0, @ResultSetArt = 'TABLE',
                            @ResultTablesJson = N'{"jobs":"#AgentJobsCalendarTable"}',
                            @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
                        EXEC [sys].[sp_executesql]
                            N'SELECT @rows = (SELECT COUNT_BIG(*) FROM [#AgentJobsCalendarTable]),
                                     @jobId = (SELECT TOP (1) [JobId] FROM [#AgentJobsCalendarTable]),
                                     @runDate = (SELECT TOP (1) [LastRunDateTime] FROM [#AgentJobsCalendarTable]),
                                     @duration = (SELECT TOP (1) [LastRunDurationSeconds] FROM [#AgentJobsCalendarTable]),
                                     @rowsJson = (SELECT * FROM [#AgentJobsCalendarTable]
                                         ORDER BY [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);',
                            N'@rows bigint OUTPUT, @jobId uniqueidentifier OUTPUT,
                              @runDate datetime OUTPUT, @duration int OUTPUT,
                              @rowsJson nvarchar(max) OUTPUT',
                            @rows = @CalendarTableRows OUTPUT, @jobId = @CalendarTableJobId OUTPUT,
                            @runDate = @CalendarTableRunDate OUTPUT,
                            @duration = @CalendarTableDuration OUTPUT,
                            @rowsJson = @CalendarTableJson OUTPUT;
                        SET @CalendarCalls += 1;
                        DELETE FROM @CalendarTableSchema;
                        INSERT @CalendarTableSchema ([LogicalOrdinal], [ColumnName], [SystemTypeId])
                        SELECT CONVERT(int, ROW_NUMBER() OVER (ORDER BY [c].[column_id])),
                               [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS, [c].[system_type_id]
                        FROM [tempdb].[sys].[columns] AS [c]
                        WHERE [c].[object_id] = OBJECT_ID(N'tempdb..#AgentJobsCalendarTable');
                        IF (SELECT COUNT(*) FROM @CalendarTableSchema) <> 17
                            OR NOT EXISTS (SELECT 1 FROM @CalendarTableSchema
                                WHERE [LogicalOrdinal] = 1 AND [ColumnName] = N'JobId' AND [SystemTypeId] = 36)
                            OR NOT EXISTS (SELECT 1 FROM @CalendarTableSchema
                                WHERE [LogicalOrdinal] = 9 AND [ColumnName] = N'LastRunDateTime' AND [SystemTypeId] = 61)
                            OR NOT EXISTS (SELECT 1 FROM @CalendarTableSchema
                                WHERE [LogicalOrdinal] = 12 AND [ColumnName] = N'LastRunDurationSeconds' AND [SystemTypeId] = 56)
                        BEGIN
                            PRINT CONCAT(N'OPS-008 AgentJobs-TABLE schema case ordinal: ', @CalendarCase);
                            THROW 56219, N'Das AgentJobs-TABLE-Schema hat nicht die erwarteten Spalten und Felder.', 1;
                        END;
                        IF COALESCE(ISJSON(@Json), 0) <> 1
                            OR COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), N'') <> N'ERROR_HANDLED'
                            OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), N'') <> N'true'
                            OR COALESCE(TRY_CONVERT(int, JSON_VALUE(@Json, '$.meta.errorNumber')), 0) <> 242
                        BEGIN
                            PRINT CONCAT(N'OPS-008 AgentJobs-TABLE metadata case ordinal: ', @CalendarCase);
                            THROW 56220, N'Die AgentJobs-TABLE-Metadaten weichen vom Kalenderfehlervertrag ab.', 1;
                        END;
                        IF @CalendarTableRows <> CONVERT(bigint, @CalendarBadStep)
                        BEGIN
                            PRINT CONCAT(N'OPS-008 AgentJobs-TABLE row-count case ordinal: ', @CalendarCase,
                                N' TABLE_ROWS=', CASE WHEN @CalendarTableRows = 0 THEN N'ZERO'
                                    WHEN @CalendarTableRows = 1 THEN N'ONE' ELSE N'OTHER' END);
                            THROW 56221, N'Die AgentJobs-TABLE-Zeilenmenge entspricht nicht der erwarteten Job-/Step-Fallzahl.', 1;
                        END;
                        IF @CalendarTableRows = 0 AND @CalendarTableJson IS NULL
                            SET @CalendarTableJson = N'[]';
                        IF COALESCE(@CalendarTableJson, N'<missing>') COLLATE SQL_Latin1_General_CP1_CS_AS
                           <> COALESCE(JSON_QUERY(@Json, '$.jobs'), N'<missing>') COLLATE SQL_Latin1_General_CP1_CS_AS
                        BEGIN
                            DECLARE @CalendarTableJsonRow nvarchar(max), @CalendarExpectedJsonRow nvarchar(max);
                            DECLARE @CalendarTableJsonRowCount int, @CalendarExpectedJsonRowCount int;
                            DECLARE @CalendarJsonKeySetMatch bit, @CalendarJsonValueDifferenceMask int;
                            DECLARE @CalendarTableJsonFields TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [JsonType] int NOT NULL,
                                [JsonValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
                            );
                            DECLARE @CalendarExpectedJsonFields TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [JsonType] int NOT NULL,
                                [JsonValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
                            );
                            DECLARE @CalendarTableJsonPropertyCountByColumn TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [PropertyCount] int NOT NULL
                            );
                            DECLARE @CalendarExpectedJsonPropertyCountByColumn TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [PropertyCount] int NOT NULL
                            );
                            DECLARE @CalendarTableJsonComparison TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [JsonType] int NOT NULL,
                                [JsonValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
                            );
                            DECLARE @CalendarExpectedJsonComparison TABLE
                            (
                                [LogicalOrdinal] int NOT NULL,
                                [JsonType] int NOT NULL,
                                [JsonValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
                            );

                            SELECT @CalendarTableJsonRowCount = COUNT(*) FROM OPENJSON(@CalendarTableJson);
                            SELECT @CalendarExpectedJsonRowCount = COUNT(*)
                            FROM OPENJSON(JSON_QUERY(@Json, '$.jobs'));
                            SELECT @CalendarTableJsonRow = [value]
                            FROM OPENJSON(@CalendarTableJson) WHERE [key] = N'0';
                            SELECT @CalendarExpectedJsonRow = [value]
                            FROM OPENJSON(JSON_QUERY(@Json, '$.jobs')) WHERE [key] = N'0';
                            SELECT @CalendarJsonKeySetMatch = CASE WHEN EXISTS
                            (
                                SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                                FROM OPENJSON(@CalendarTableJsonRow)
                                EXCEPT
                                SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                                FROM OPENJSON(@CalendarExpectedJsonRow)
                            ) OR EXISTS
                            (
                                SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                                FROM OPENJSON(@CalendarExpectedJsonRow)
                                EXCEPT
                                SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                                FROM OPENJSON(@CalendarTableJsonRow)
                            ) THEN 0 ELSE 1 END;

                            INSERT @CalendarTableJsonFields ([LogicalOrdinal], [JsonType], [JsonValue])
                            SELECT [schema].[LogicalOrdinal], [property].[type], [property].[value]
                            FROM OPENJSON(@CalendarTableJsonRow) AS [property]
                            JOIN @CalendarTableSchema AS [schema]
                              ON [property].[key] COLLATE SQL_Latin1_General_CP1_CS_AS = [schema].[ColumnName];
                            INSERT @CalendarExpectedJsonFields ([LogicalOrdinal], [JsonType], [JsonValue])
                            SELECT [schema].[LogicalOrdinal], [property].[type], [property].[value]
                            FROM OPENJSON(@CalendarExpectedJsonRow) AS [property]
                            JOIN @CalendarTableSchema AS [schema]
                              ON [property].[key] COLLATE SQL_Latin1_General_CP1_CS_AS = [schema].[ColumnName];
                            INSERT @CalendarTableJsonPropertyCountByColumn ([LogicalOrdinal], [PropertyCount])
                            SELECT [schema].[LogicalOrdinal], COUNT([property].[key])
                            FROM @CalendarTableSchema AS [schema]
                            LEFT JOIN OPENJSON(@CalendarTableJsonRow) AS [property]
                              ON [property].[key] COLLATE SQL_Latin1_General_CP1_CS_AS = [schema].[ColumnName]
                            GROUP BY [schema].[LogicalOrdinal];
                            INSERT @CalendarExpectedJsonPropertyCountByColumn ([LogicalOrdinal], [PropertyCount])
                            SELECT [schema].[LogicalOrdinal], COUNT([property].[key])
                            FROM @CalendarTableSchema AS [schema]
                            LEFT JOIN OPENJSON(@CalendarExpectedJsonRow) AS [property]
                              ON [property].[key] COLLATE SQL_Latin1_General_CP1_CS_AS = [schema].[ColumnName]
                            GROUP BY [schema].[LogicalOrdinal];
                            INSERT @CalendarTableJsonComparison ([LogicalOrdinal], [JsonType], [JsonValue])
                            SELECT [field].[LogicalOrdinal], [field].[JsonType], [field].[JsonValue]
                            FROM @CalendarTableJsonFields AS [field]
                            WHERE NOT EXISTS
                            (
                                SELECT 1 FROM @CalendarTableJsonPropertyCountByColumn AS [count]
                                WHERE [count].[LogicalOrdinal] = [field].[LogicalOrdinal]
                                  AND [count].[PropertyCount] > 1
                            );
                            INSERT @CalendarExpectedJsonComparison ([LogicalOrdinal], [JsonType], [JsonValue])
                            SELECT [field].[LogicalOrdinal], [field].[JsonType], [field].[JsonValue]
                            FROM @CalendarExpectedJsonFields AS [field]
                            WHERE NOT EXISTS
                            (
                                SELECT 1 FROM @CalendarExpectedJsonPropertyCountByColumn AS [count]
                                WHERE [count].[LogicalOrdinal] = [field].[LogicalOrdinal]
                                  AND [count].[PropertyCount] > 1
                            );
                            SELECT @CalendarJsonValueDifferenceMask = COALESCE(SUM(CONVERT(int,
                                CASE WHEN [tableCount].[PropertyCount] <> 1 OR [expectedCount].[PropertyCount] <> 1
                                       OR [tableField].[JsonType] <> [expectedField].[JsonType]
                                       OR ([tableField].[JsonValue] IS NULL AND [expectedField].[JsonValue] IS NOT NULL)
                                       OR ([tableField].[JsonValue] IS NOT NULL AND [expectedField].[JsonValue] IS NULL)
                                       OR ([tableField].[JsonValue] IS NOT NULL AND [expectedField].[JsonValue] IS NOT NULL
                                           AND [tableField].[JsonValue] COLLATE SQL_Latin1_General_CP1_CS_AS
                                               <> [expectedField].[JsonValue] COLLATE SQL_Latin1_General_CP1_CS_AS)
                                     THEN POWER(CONVERT(float, 2), [schema].[LogicalOrdinal] - 1)
                                     ELSE 0 END)), 0)
                            FROM @CalendarTableSchema AS [schema]
                            JOIN @CalendarTableJsonPropertyCountByColumn AS [tableCount]
                              ON [tableCount].[LogicalOrdinal] = [schema].[LogicalOrdinal]
                            JOIN @CalendarExpectedJsonPropertyCountByColumn AS [expectedCount]
                              ON [expectedCount].[LogicalOrdinal] = [schema].[LogicalOrdinal]
                            LEFT JOIN @CalendarTableJsonComparison AS [tableField]
                              ON [tableField].[LogicalOrdinal] = [schema].[LogicalOrdinal]
                            LEFT JOIN @CalendarExpectedJsonComparison AS [expectedField]
                              ON [expectedField].[LogicalOrdinal] = [schema].[LogicalOrdinal];
                            PRINT CONCAT(N'OPS-008 AgentJobs-TABLE JSON-parity case ordinal: ', @CalendarCase,
                                N' TABLE_ROWS=', CASE WHEN @CalendarTableJsonRowCount = 0 THEN N'ZERO'
                                    WHEN @CalendarTableJsonRowCount = 1 THEN N'ONE' ELSE N'OTHER' END,
                                N' JSON_ROWS=', CASE WHEN @CalendarExpectedJsonRowCount = 0 THEN N'ZERO'
                                    WHEN @CalendarExpectedJsonRowCount = 1 THEN N'ONE' ELSE N'OTHER' END,
                                N' JSON_KEYSET=', CASE WHEN @CalendarJsonKeySetMatch = 1 THEN N'MATCH' ELSE N'MISMATCH' END,
                                N' JSON_VALUE_MASK=', @CalendarJsonValueDifferenceMask);
                            THROW 56223, N'Die AgentJobs-TABLE-Zeilen stimmen nicht mit der gleichzeitigen JSON-Ausgabe überein.', 1;
                        END;
                        IF (@CalendarBadStep = 1 AND
                            (@CalendarTableJobId IS NULL OR @CalendarTableJobId <> @JobId
                             OR @CalendarTableRunDate IS NULL
                             OR @CalendarTableRunDate <> CONVERT(datetime, '2024-02-29T00:00:00', 126)
                             OR @CalendarTableDuration IS NULL OR @CalendarTableDuration <> 85))
                            OR (@CalendarBadStep = 0 AND
                            (@CalendarTableJobId IS NOT NULL OR @CalendarTableRunDate IS NOT NULL
                             OR @CalendarTableDuration IS NOT NULL))
                        BEGIN
                            PRINT CONCAT(N'OPS-008 AgentJobs-TABLE known-row case ordinal: ', @CalendarCase);
                            THROW 56222, N'Das erhaltene AgentJobs-TABLE-Teilergebnis ist verletzt.', 1;
                        END;
                        DROP TABLE [#AgentJobsCalendarTable];
                    END;
                END
                ELSE
                BEGIN
                    EXEC [monitor].[USP_AgentMonitoringAnalysis] @HistoryHours = 24,
                        @MitJobStatus = 1, @MitDatabaseMail = 0, @MaxZeilen = 0,
                        @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
                        @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                        @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                        @ErrorMessageOut = @Message OUTPUT;
                    IF (@CalendarBadStep = 0 AND (COALESCE(@Status, '') <> 'AVAILABLE_LIMITED'
                        OR COALESCE(@Partial, 0) <> 1 OR COALESCE(@Error, 0) <> 242
                        OR NULLIF(@Message, N'') IS NULL))
                        OR (@CalendarBadStep = 1 AND (COALESCE(@Status, '') NOT IN ('AVAILABLE', 'AVAILABLE_WITH_FINDING')
                        OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL))
                        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> CONVERT(int, @CalendarBadStep)
                        THROW 56216, N'Der Monitoring-Kalenderstatus ist verletzt.', 1;
                END;
                SET @CalendarState = XACT_STATE();
                SELECT @CalendarAfter = (SELECT
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                    ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                    ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                    ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                    ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                    ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                    ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
                IF COALESCE(ISJSON(@Json), 0) <> 1 OR @CalendarState <> 1 OR @@TRANCOUNT <> 1
                    OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> @CalendarExpectedMask
                    OR @CalendarBefore IS NULL OR @CalendarAfter IS NULL
                    OR @CalendarBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                       <> @CalendarAfter COLLATE SQL_Latin1_General_CP1_CS_AS
                    OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
                    OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
                    OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
                    THROW 56217, N'Der Kalenderconsumer hat Quellen oder die schreibfähige Transaktion verändert.', 1;
                SET @CalendarCalls += 1;
                ROLLBACK TRANSACTION;
                SET @CalendarState = XACT_STATE();
                SET @CalendarRollbacks += 1;
                SELECT @CalendarAfter = (SELECT
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobs]
                    ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Jobs],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobsteps]
                    ORDER BY [job_id], [step_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Steps],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobhistory]
                    ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [History],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobactivity]
                    ORDER BY [session_id], [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Activity],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobservers]
                    ORDER BY [job_id], [server_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Servers],
                JSON_QUERY((SELECT * FROM [msdb].[dbo].[sysjobschedules]
                    ORDER BY [job_id], [schedule_id] FOR JSON PATH, INCLUDE_NULL_VALUES)) AS [Schedules]
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
                IF @@TRANCOUNT <> 0 OR @CalendarState <> 0
                    OR (@@OPTIONS & 16384) <> @CalendarExpectedMask
                    OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR @CalendarBaseline IS NULL
                    OR @CalendarAfter IS NULL OR @CalendarBaseline COLLATE SQL_Latin1_General_CP1_CS_AS
                       <> @CalendarAfter COLLATE SQL_Latin1_General_CP1_CS_AS
                    THROW 56218, N'Der Kalenderrollback hat die ursprünglichen Agentquellen nicht wiederhergestellt.', 1;
                SET @CalendarConsumer += 1;
            END;
            SET @CalendarCase += 1;
        END;
        IF @CalendarCalls - @CalendarOptionCallsStart <> 48
            OR @CalendarRollbacks - @CalendarOptionRollbacksStart <> 36
            THROW 56218, N'Die 48 Kalender-/Uhrzeitaufrufe oder 36 Rollbacks je XACT_ABORT-Einstellung fehlen.', 1;
        SET @CalendarOption += 1;
    END;
    IF @CalendarOption <> 2 OR @CalendarCalls <> 96 OR @CalendarRollbacks <> 72
        THROW 56218, N'Die 96 Kalender-/Uhrzeitaufrufe, 72 Rollbacks oder beide XACT_ABORT-Einstellungen fehlen.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
    THROW;
END CATCH;
IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
IF @Stage <> 4 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> @PreviousXactAbort
    THROW 55155, N'Die Stufenanzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
SELECT N'OPS008_AGENT_AGGREGATE' AS [ContractName], 3 AS [PositiveStages],
    @Calls AS [PositiveConsumerCalls], @CalendarCalls AS [CalendarConsumerCalls],
    @CalendarRollbacks AS [CalendarRollbacks],
    N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup];
GO
