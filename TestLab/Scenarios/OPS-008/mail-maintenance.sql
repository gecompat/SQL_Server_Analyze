USE [DeineDatenbank];
GO

/* OPS-008: Injizierte Tabellenfixture; führt weder Mailversand noch Maintenance aus. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int, [value]) = 1
)
    THROW 54951, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 54961, N'Die Fixture benötigt den ursprünglichen Standard-Locktimeout -1.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log])
   OR EXISTS (SELECT 1 FROM [sys].[configurations]
              WHERE [name] = N'Database Mail XPs' AND [value_in_use] <> 0)
    THROW 54952, N'Die leeren eigenen Quellen oder deaktivierten Mail-XPs fehlen.', 1;

DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT;
DECLARE @PreviousXactAbort bit = CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END;
DECLARE @Stage int = 1, @Consumer int, @Date datetime, @Oldest datetime2(3), @Newest datetime2(3);
DECLARE @BeforeMail nvarchar(max), @AfterMail nvarchar(max);
DECLARE @BeforeMaintenance nvarchar(max), @AfterMaintenance nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @Mode varchar(16), @Mapping nvarchar(max), @Calls int = 0;
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    BEGIN TRANSACTION;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 137;
    WHILE @Stage <= 3
    BEGIN
        /* Die Einfügereihenfolge entspricht absichtlich nicht der Zeitreihenfolge. */
        SET @Date = CASE @Stage WHEN 1 THEN CONVERT(datetime, '2025-01-02T12:00:00', 126)
            WHEN 2 THEN CONVERT(datetime, '2000-01-01T08:00:00', 126)
            ELSE CONVERT(datetime, '2030-01-03T16:00:00', 126) END;
        INSERT [msdb].[dbo].[sysmail_mailitems]
            ([profile_id], [recipients], [subject], [body], [send_request_date],
             [send_request_user], [sent_status], [last_mod_user])
        VALUES (0, N'ExampleRecipient', N'Example synthetic subject', N'Example synthetic body',
            @Date, N'ExampleUser', 2, N'ExampleUser');
        INSERT [msdb].[dbo].[sysmaintplan_log]
            ([task_detail_id], [start_time], [end_time], [succeeded], [plan_name], [subplan_name])
        VALUES (NEWID(), @Date, DATEADD(second, 5, @Date), 1, N'ExamplePlan', N'ExampleSubplan');
        SET @Oldest = CASE WHEN @Stage = 1 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126)
            ELSE CONVERT(datetime2(3), '2000-01-01T08:00:00', 126) END;
        SET @Newest = CASE WHEN @Stage < 3 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126)
            ELSE CONVERT(datetime2(3), '2030-01-03T16:00:00', 126) END;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @BeforeMail = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @BeforeMaintenance = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SET @Mode = CASE @Consumer WHEN 1 THEN 'NONE' WHEN 2 THEN 'TABLE' ELSE 'CONSOLE' END;
            SET @Mapping = CASE WHEN @Consumer = 2 THEN N'{"msdbHealth":"#Ops008Table"}' ELSE NULL END;
            SELECT @Json = NULL, @Status = NULL, @Partial = NULL, @Error = -1, @Message = N'Example sentinel';
            IF @Consumer = 2 CREATE TABLE [#Ops008Table] ([Dummy] int);
            IF @Consumer = 3
            BEGIN
                TRUNCATE TABLE [#Ops008Console];
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
                THROW 54953, N'Der positive Modulstatus oder das JSON ist verletzt.', 1;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 6
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
                   WITH ([Area] varchar(40)) WHERE [Area] IN ('DATABASE_MAIL','MAINTENANCE_PLAN')) <> 2
                THROW 54954, N'Die erwarteten Quellenzeilen fehlen oder sind mehrfach vorhanden.', 1;
            IF EXISTS
            (
                SELECT [Area], [SourceObject], CONVERT(bigint, @Stage) [RowCount],
                    @Oldest [OldestUtc], @Newest [NewestUtc], CONVERT(decimal(19,2), NULL) [SizeMb],
                    CONVERT(varchar(40), 'AVAILABLE') [StatusCode]
                FROM (VALUES ('DATABASE_MAIL', N'msdb.dbo.sysmail_allitems'),
                    ('MAINTENANCE_PLAN', N'msdb.dbo.sysmaintplan_log')) [e]([Area], [SourceObject])
                EXCEPT
                SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
                FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                    [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
                    [SizeMb] decimal(19,2), [StatusCode] varchar(40))
            ) OR EXISTS
            (
                SELECT 1 FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
                WHERE [Area] IN ('DATABASE_MAIL','MAINTENANCE_PLAN')
                  AND NULLIF([EvidenceLimit], N'') IS NULL
            )
                THROW 54955, N'Die kontrollierten Counts, Zeitgrenzen oder Evidenzgrenzen sind verletzt.', 1;
            /* Die nativen Zeitwerte werden unverändert übernommen, ohne UTC-Konvertierungsbehauptung. */
            IF EXISTS
            (
                SELECT 'DATABASE_MAIL' [Area], COUNT_BIG(*) [RowCount],
                    CONVERT(datetime2(3), MIN([send_request_date])) [OldestUtc],
                    CONVERT(datetime2(3), MAX([send_request_date])) [NewestUtc]
                FROM [msdb].[dbo].[sysmail_allitems]
                UNION ALL
                SELECT 'MAINTENANCE_PLAN', COUNT_BIG(*),
                    CONVERT(datetime2(3), MIN([start_time])), CONVERT(datetime2(3), MAX([start_time]))
                FROM [msdb].[dbo].[sysmaintplan_log]
                EXCEPT
                SELECT [Area], [RowCount], [OldestUtc], [NewestUtc]
                FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [RowCount] bigint,
                    [OldestUtc] datetime2(3), [NewestUtc] datetime2(3))
            )
                THROW 54956, N'Die native Gegenprobe der Historienaggregate ist verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 54957, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#Ops008Table];
            END;
            IF @Consumer = 3
            BEGIN
                SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc],
                    [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
                    FROM [#Ops008Console] ORDER BY [Area] FOR JSON PATH);
                IF EXISTS (SELECT @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                   OR EXISTS (SELECT 1 FROM [#Ops008Console]
                       WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
                    THROW 54958, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @AfterMail = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @AfterMaintenance = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF EXISTS (SELECT @BeforeMail COLLATE SQL_Latin1_General_CP1_CS_AS
                       EXCEPT SELECT @AfterMail COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT @BeforeMaintenance COLLATE SQL_Latin1_General_CP1_CS_AS
                          EXCEPT SELECT @AfterMaintenance COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
                THROW 54959, N'Der Analyzer hat Quellwerte oder den Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @Stage += 1;
    END;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log])
        THROW 54960, N'Die Mail-/Maintenance-Fixture wurde nicht vollständig zurückgerollt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET LOCK_TIMEOUT -1;
    IF @PreviousXactAbort = 1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
SET LOCK_TIMEOUT -1;
IF @PreviousXactAbort = 1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
IF @Calls <> 9 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
   OR CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END <> @PreviousXactAbort
    THROW 54962, N'Die Consumerzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_MAIL_MAINTENANCE_AGGREGATE' AS [ContractName], 3 AS [PositiveStages],
    @Calls AS [ConsumerCalls], N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup],
    CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')) AS [ProductVersion],
    [compatibility_level] AS [CompatibilityLevel]
FROM [sys].[databases] WHERE [database_id] = DB_ID();
GO
