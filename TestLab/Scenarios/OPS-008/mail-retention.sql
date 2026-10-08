USE [DeineDatenbank];
GO

/* Die injizierte Mailhistorie prüft native Retention ohne Mailversand oder Queueverarbeitung. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1
)
    THROW 55181, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55193, N'Die Fixture benötigt den ursprünglichen Standard-Locktimeout -1.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
   OR EXISTS (SELECT 1 FROM [sys].[configurations]
       WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
    THROW 55182, N'Die leeren eigenen Mailquellen oder deaktivierten Mail-XPs fehlen.', 1;
DECLARE @Stage int = 1, @Phase int = 1, @Consumer int, @Calls int = 0, @KeepMail int;
DECLARE @Date datetime, @Cutoff datetime, @ExpectedCount bigint, @Low datetime2(3), @High datetime2(3);
DECLARE @Before nvarchar(max), @After nvarchar(max), @Retained nvarchar(max), @AfterPurge nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @Mode varchar(16), @Mapping nvarchar(max), @ReturnCode int;
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT;
DECLARE @PreviousXactAbort bit = CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END;
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
        SET @Date = CONVERT(datetime, CASE @Stage WHEN 1 THEN '2025-01-01T12:00:00'
            WHEN 2 THEN '2025-01-02T12:00:00' ELSE '2000-01-01T12:00:00' END, 126);
        INSERT [msdb].[dbo].[sysmail_mailitems]
            ([profile_id], [recipients], [subject], [body], [send_request_date],
             [send_request_user], [sent_status], [sent_date], [last_mod_user])
        VALUES (0, N'ExampleRecipient', N'Example synthetic subject', N'Example synthetic body',
            @Date, N'ExampleUser', 2, @Date, N'ExampleUser');
        IF @Stage = 2 SET @KeepMail = CONVERT(int, SCOPE_IDENTITY());
        SET @Stage += 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailitems]) <> 3
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems]) <> 3
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
           WHERE [sent_status] COLLATE SQL_Latin1_General_CP1_CS_AS <> 'failed')
        THROW 55183, N'Die drei injizierten eigenen Failed-Mailzeilen fehlen.', 1;
    SELECT @Retained = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
        WHERE [mailitem_id] = @KeepMail ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedCount = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        SET @Low = CASE @Phase WHEN 1 THEN CONVERT(datetime2(3), '2000-01-01T12:00:00', 126)
            WHEN 2 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        SET @High = CASE WHEN @Phase < 3 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00'
                ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sysmail_delete_mailitems_sp]
                @sent_before = @Cutoff, @sent_status = 'failed';
            IF @ReturnCode <> 0 THROW 55184, N'Die native eigene Mailbereinigung ist fehlgeschlagen.', 1;
            SELECT @AfterPurge = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @Retained COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55185, N'Die vollständigen jüngeren Mailwerte sind nach Retention verändert.', 1;
        END;
        IF EXISTS
        (
            SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([send_request_date])),
                CONVERT(datetime2(3), MAX([send_request_date])) FROM [msdb].[dbo].[sysmail_allitems]
            EXCEPT SELECT @ExpectedCount, @Low, @High
        ) OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailitems]) <> @ExpectedCount
          OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
            THROW 55186, N'Die unabhängigen Retentioncounts, Zeitgrenzen oder Callerbasis sind verletzt.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
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
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 6
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
                   WITH ([Area] varchar(40)) WHERE [Area] = 'DATABASE_MAIL') <> 1
                THROW 55187, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
            IF EXISTS
            (
                SELECT 'DATABASE_MAIL' [Area], N'msdb.dbo.sysmail_allitems' [SourceObject],
                    COUNT_BIG(*) [RowCount], CONVERT(datetime2(3), MIN([send_request_date])) [OldestUtc],
                    CONVERT(datetime2(3), MAX([send_request_date])) [NewestUtc],
                    CONVERT(decimal(19,2), NULL) [SizeMb], CONVERT(varchar(40), 'AVAILABLE') [StatusCode]
                FROM [msdb].[dbo].[sysmail_allitems]
                EXCEPT
                SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
                FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                    [OldestUtc] datetime2(3), [NewestUtc] datetime2(3), [SizeMb] decimal(19,2), [StatusCode] varchar(40))
            ) OR EXISTS (SELECT 1 FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
                WHERE [Area] = 'DATABASE_MAIL' AND NULLIF([EvidenceLimit], N'') IS NULL)
                THROW 55188, N'Die nativen Mailaggregate oder Evidenzgrenzen sind verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 55189, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                    THROW 55190, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
               OR EXISTS (SELECT 1 FROM [sys].[configurations]
                   WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
                THROW 55191, N'Der Analyzer hat Mailquellen, Callerzustand oder die Mail-XP-Grenze verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @Phase += 1;
    END;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0 OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
        THROW 55192, N'Die eigene injizierte Mailfixture wurde nicht vollständig zurückgerollt.', 1;
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
    THROW 55194, N'Die Consumerzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_MAIL_RETENTION' AS [ContractName], 3 AS [InitialRows], 1 AS [RetainedRows],
    0 AS [FinalRows], @Calls AS [ConsumerCalls], N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup];
GO
