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
        SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);

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
        SELECT @After = (SELECT * FROM [msdb].[dbo].[sysjobhistory]
            ORDER BY [instance_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF @Before COLLATE SQL_Latin1_General_CP1_CS_AS <> @After COLLATE SQL_Latin1_General_CP1_CS_AS
           OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory]) <> @Stage
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1
           OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> 16384
            THROW 54946, N'Der Analyzer hat Quellwerte oder die Callertransaktion verändert.', 1;
        SET @Stage += 1;
    END;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] = @JobId)
        THROW 54947, N'Die reine Tabellenfixture darf keine Agent-Ausführungsbindung besitzen.', 1;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId)
        THROW 54948, N'Die synthetische Agent-Fixture wurde nicht vollständig zurückgerollt.', 1;
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
    N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup];
GO
