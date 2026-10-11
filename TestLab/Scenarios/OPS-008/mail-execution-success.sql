USE [DeineDatenbank];
GO

/* Entwurf: Die SMTP-Runtime bleibt bis zur öffentlichen Lab-Abnahme NOT_EXECUTED. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
   OR NOT EXISTS (SELECT 1 FROM [sys].[extended_properties]
       WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1)
    THROW 55321, N'Die eigene Wegwerf-Lab-Bindung oder Callerbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55322, N'Der ursprüngliche Standardlocktimeout fehlt.', 1;

DECLARE @ProfileName sysname = N'__SMTP_PROFILE_NAME__';
DECLARE @ProfileId int;
DECLARE @MailId int, @ReturnCode int, @Attempts int = 0, @Calls int = 0;
DECLARE @Before nvarchar(max), @After nvarchar(max), @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @Mode varchar(16), @Mapping nvarchar(max);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @PreviousXactAbort int = @@OPTIONS & 16384;
CREATE TABLE [#Ops008SuccessConsole]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);

BEGIN TRY
    SELECT @ProfileId = [profile_id] FROM [msdb].[dbo].[sysmail_profile]
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS = @ProfileName COLLATE SQL_Latin1_General_CP1_CS_AS;
    IF @ProfileId IS NULL
        THROW 55323, N'Das run-gebundene öffentliche Database-Mail-Profil fehlt.', 1;
    EXEC @ReturnCode = [msdb].[dbo].[sp_send_dbmail] @profile_name = @ProfileName,
        @recipients = 'ExampleRecipient@example.invalid', @subject = N'Example SMTP delivery',
        @body = N'Example SMTP delivery body', @mailitem_id = @MailId OUTPUT;
    IF COALESCE(@ReturnCode, -1) <> 0 OR @MailId IS NULL
        THROW 55324, N'Der eigene native Mailauftrag wurde nicht in die Queue aufgenommen.', 1;
    WHILE @Attempts < 120 AND NOT EXISTS
    (
        SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
        WHERE [mailitem_id] = @MailId AND [profile_id] = @ProfileId
          AND [sent_status] = 'sent' AND [send_request_date] IS NOT NULL AND [sent_date] IS NOT NULL
    )
    BEGIN
        WAITFOR DELAY '00:00:01';
        SET @Attempts += 1;
    END;
    IF NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
        WHERE [mailitem_id] = @MailId AND [profile_id] = @ProfileId AND [sent_status] = 'sent'
          AND [send_request_date] IS NOT NULL AND [sent_date] IS NOT NULL
          AND [recipients] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleRecipient@example.invalid'
          AND [subject] COLLATE SQL_Latin1_General_CP1_CS_AS = N'Example SMTP delivery'
          AND [body] COLLATE SQL_Latin1_General_CP1_CS_AS = N'Example SMTP delivery body')
        THROW 55325, N'Der öffentliche SMTP-Pfad bestätigte den eigenen Mailauftrag nicht als gesendet.', 1;

    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    SET LOCK_TIMEOUT 137;
    WHILE @Calls < 3
    BEGIN
        SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems] ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Mode = CASE @Calls WHEN 0 THEN 'NONE' WHEN 1 THEN 'TABLE' ELSE 'CONSOLE' END;
        SET @Mapping = CASE WHEN @Calls = 1 THEN N'{"msdbHealth":"#Ops008SuccessTable"}' ELSE NULL END;
        SELECT @Json = NULL, @Status = NULL, @Partial = NULL, @Error = -1, @Message = N'Example sentinel';
        IF @Calls = 1 CREATE TABLE [#Ops008SuccessTable] ([Dummy] int);
        IF @Calls = 2
        BEGIN
            TRUNCATE TABLE [#Ops008SuccessConsole];
            INSERT [#Ops008SuccessConsole]
            EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0, @ResultSetArt = @Mode, @JsonErzeugen = 1, @Json = @Json OUTPUT,
                @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT,
                @ErrorNumberOut = @Error OUTPUT, @ErrorMessageOut = @Message OUTPUT;
        END
        ELSE
            EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0, @ResultSetArt = @Mode, @ResultTablesJson = @Mapping,
                @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT, @ErrorMessageOut = @Message OUTPUT;
        IF COALESCE(ISJSON(@Json), 0) <> 1 OR COALESCE(@Status, '') <> 'AVAILABLE'
           OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 6
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json) WITH ([Area] varchar(40)) WHERE [Area] = 'DATABASE_MAIL') <> 1
            THROW 55326, N'Der Analyzer bestätigt die gesendete eigene Mail nicht mit dem erwarteten Quellenstatus.', 1;
        IF EXISTS
        (
            SELECT 'DATABASE_MAIL' [Area], N'msdb.dbo.sysmail_allitems' [SourceObject], COUNT_BIG(*) [RowCount],
                CONVERT(datetime2(3), MIN([send_request_date])) [OldestUtc],
                CONVERT(datetime2(3), MAX([send_request_date])) [NewestUtc],
                CONVERT(decimal(19,2), NULL) [SizeMb], CONVERT(varchar(40), 'AVAILABLE') [StatusCode]
            FROM [msdb].[dbo].[sysmail_allitems]
            EXCEPT
            SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
            FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                [OldestUtc] datetime2(3), [NewestUtc] datetime2(3), [SizeMb] decimal(19,2), [StatusCode] varchar(40))
        ) OR EXISTS (SELECT 1 FROM OPENJSON(@Json) WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
            WHERE [Area] = 'DATABASE_MAIL' AND NULLIF([EvidenceLimit], N'') IS NULL)
            THROW 55331, N'Die nativen Mailaggregate oder Evidenzgrenzen sind verletzt.', 1;
        IF @Calls = 1
        BEGIN
            EXEC [sys].[sp_executesql] N'SELECT @RowsJson = (SELECT * FROM [#Ops008SuccessTable] ORDER BY [Area] FOR JSON PATH);',
                N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
            IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55327, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
            DROP TABLE [#Ops008SuccessTable];
        END;
        IF @Calls = 2
        BEGIN
            SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
                FROM [#Ops008SuccessConsole] ORDER BY [Area] FOR JSON PATH);
            IF EXISTS (SELECT @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT 1 FROM [#Ops008SuccessConsole] WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
                THROW 55328, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
        END;
        SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems] ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
            THROW 55329, N'Der Analyzer hat Mailquellen oder Callerzustand verändert.', 1;
        SET @Calls += 1;
    END;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET LOCK_TIMEOUT @PreviousLockTimeout;
    IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
    THROW;
END CATCH;
SET LOCK_TIMEOUT @PreviousLockTimeout;
IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
IF @Calls <> 3 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> @PreviousXactAbort
    THROW 55330, N'Die Consumeranzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008SuccessConsole];
SELECT N'OPS008_MAIL_EXECUTION_SUCCESS' AS [ContractName], @MailId AS [MailItemId], @Calls AS [ConsumerCalls],
    N'PASS' AS [Status], N'LAB_OWNED_SMTP_CLEANUP_REQUIRED' AS [FixtureCleanup];
GO
