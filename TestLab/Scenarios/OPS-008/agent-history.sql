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
    IF @DateCase <> 4 OR @Calls <> 12
        THROW 55199, N'Die drei Datumsfälle oder zwölf Consumeraufrufe fehlen.', 1;
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
    IF @StepCase <> 4 OR @Calls <> 21
        THROW 55199, N'Die drei Stepfälle oder 21 Consumeraufrufe fehlen.', 1;
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

    DECLARE @CalendarCase int = 1, @CalendarConsumer int, @CalendarDate int,
        @CalendarRunTime int, @CalendarReturn int,
        @CalendarBadStep bit, @CalendarCalls int = 0, @CalendarRollbacks int = 0,
        @CalendarBaseline nvarchar(max), @CalendarBefore nvarchar(max),
        @CalendarAfter nvarchar(max), @CalendarState int;
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
    WHILE @CalendarCase <= 8
    BEGIN
        SELECT @CalendarDate = CASE WHEN @CalendarCase <= 2 THEN 20230229
                WHEN @CalendarCase <= 4 THEN 20240230 ELSE 20240229 END,
            @CalendarRunTime = CASE WHEN @CalendarCase <= 4 THEN 0
                WHEN @CalendarCase <= 6 THEN 236060 ELSE 240000 END,
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
                OR (@@OPTIONS & 16384) <> 16384 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
                THROW 56215, N'Der Kalenderaufruf benötigt eine schreibfähige ON-Transaktion.', 1;
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
                IF COALESCE(JSON_VALUE(@Json, '$.meta.statusCode'), '') <> 'ERROR_HANDLED'
                    OR COALESCE(JSON_VALUE(@Json, '$.meta.isPartial'), '') <> 'true'
                    OR COALESCE(TRY_CONVERT(int, JSON_VALUE(@Json, '$.meta.errorNumber')), 0) <> 242
                    OR NULLIF(JSON_VALUE(@Json, '$.meta.errorMessage'), N'') IS NULL
                    OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.jobs')) <> CONVERT(int, @CalendarBadStep)
                    OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json, '$.steps')) <> 0
                    THROW 56216, N'Der abgefangene AgentJobs-Kalenderfehler ist verletzt.', 1;
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
                OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
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
            IF @@TRANCOUNT <> 0 OR @CalendarState <> 0 OR @CalendarBaseline IS NULL
                OR @CalendarAfter IS NULL OR @CalendarBaseline COLLATE SQL_Latin1_General_CP1_CS_AS
                   <> @CalendarAfter COLLATE SQL_Latin1_General_CP1_CS_AS
                THROW 56218, N'Der Kalenderrollback hat die ursprünglichen Agentquellen nicht wiederhergestellt.', 1;
            SET @CalendarConsumer += 1;
        END;
        SET @CalendarCase += 1;
    END;
    IF @CalendarCalls <> 24 OR @CalendarRollbacks <> 24
        THROW 56218, N'Die 24 Kalender-/Uhrzeitaufrufe oder Rollbacks fehlen.', 1;
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
