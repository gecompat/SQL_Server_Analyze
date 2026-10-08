USE [DeineDatenbank];
GO

/* Die eigene Mailqueue erzeugt einen tatsächlichen lokalen Fehlerfall ohne Historieninjektion. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
   OR NOT EXISTS (SELECT 1 FROM [sys].[extended_properties]
       WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1)
    THROW 55281, N'Die eigene Wegwerf-Lab-Bindung oder Callerbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55291, N'Der ursprüngliche Standardlocktimeout fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_event_log])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_profile])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_account])
   OR EXISTS (SELECT 1 FROM [sys].[configurations]
       WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
   OR NOT EXISTS (SELECT 1 FROM [sys].[databases] WHERE [name] = N'msdb' AND [is_broker_enabled] = 1)
    THROW 55282, N'Die leeren eigenen Mailquellen, deaktivierten XPs oder Brokerbasis fehlen.', 1;
DECLARE @PreviousAdvanced int;
SELECT @PreviousAdvanced = CONVERT(int, [value]) FROM [sys].[configurations]
    WHERE [name] = N'show advanced options' AND [value] = [value_in_use];
IF @PreviousAdvanced IS NULL THROW 55283, N'Der stabile Advanced-Options-Eintrittswert fehlt.', 1;
DECLARE @QueueState TABLE ([Status] nvarchar(7) COLLATE SQL_Latin1_General_CP1_CS_AS);
DECLARE @PreviousQueueStatus nvarchar(7);
DECLARE @Account TABLE
(
    [account_id] int, [name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [description] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [email_address] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [display_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [replyto_address] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [servertype] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [servername] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [port] int, [username] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [use_default_credentials] bit, [enable_ssl] bit
);
DECLARE @ProfileId int, @AccountId int, @MailId int, @ReturnCode int, @Attempts int = 0;
DECLARE @NativeErrorRows bigint;
DECLARE @Before nvarchar(max), @After nvarchar(max);
DECLARE @Consumer int = 1, @Calls int = 0, @Mode varchar(16), @Mapping nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @PreviousXactAbort int = @@OPTIONS & 16384;
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    SET XACT_ABORT ON;
    EXEC [master].[sys].[sp_configure] N'show advanced options', 1;
    RECONFIGURE;
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 1;
    RECONFIGURE;
    INSERT @QueueState EXEC [msdb].[dbo].[sysmail_help_status_sp];
    SELECT @PreviousQueueStatus = [Status] FROM @QueueState;
    IF (SELECT COUNT(*) FROM @QueueState) <> 1 OR COALESCE(@PreviousQueueStatus, N'') NOT IN (N'STARTED', N'STOPPED')
        THROW 55284, N'Der native Mailqueue-Eintrittsstatus fehlt.', 1;
    EXEC [msdb].[dbo].[sysmail_add_profile_sp] @profile_name = N'ExampleOps008FailureProfile',
        @description = N'Synthetic local failure contract.', @profile_id = @ProfileId OUTPUT;
    EXEC [msdb].[dbo].[sysmail_add_account_sp] @account_name = N'ExampleOps008FailureAccount',
        @email_address = N'ExampleSender@example.invalid', @display_name = N'ExampleSender',
        @mailserver_name = N'localhost', @port = 1, @username = NULL,
        @use_default_credentials = 0, @enable_ssl = 0, @account_id = @AccountId OUTPUT;
    INSERT @Account EXEC [msdb].[dbo].[sysmail_help_account_sp] @account_id = @AccountId;
    IF @ProfileId IS NULL OR @AccountId IS NULL OR (SELECT COUNT(*) FROM @Account) <> 1
       OR NOT EXISTS (SELECT 1 FROM @Account WHERE [account_id] = @AccountId
           AND [name] = N'ExampleOps008FailureAccount' AND [servertype] = N'SMTP'
           AND [servername] = N'localhost' AND [port] = 1 AND [username] IS NULL
           AND [use_default_credentials] = 0 AND [enable_ssl] = 0
           AND [email_address] = N'ExampleSender@example.invalid')
        THROW 55285, N'Die eigene lokale SMTP-Kontobindung ohne Credentials fehlt.', 1;
    EXEC [msdb].[dbo].[sysmail_add_profileaccount_sp] @profile_id = @ProfileId,
        @account_id = @AccountId, @sequence_number = 1;
    EXEC [msdb].[dbo].[sysmail_start_sp];
    EXEC @ReturnCode = [msdb].[dbo].[sp_send_dbmail] @profile_name = N'ExampleOps008FailureProfile',
        @recipients = 'ExampleRecipient@example.invalid', @subject = N'Example synthetic failure',
        @body = N'Example synthetic body', @mailitem_id = @MailId OUTPUT;
    IF @ReturnCode <> 0 OR @MailId IS NULL THROW 55286, N'Der eigene native Queueauftrag fehlt.', 1;
    WHILE @Attempts < 120 AND NOT EXISTS
        (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems] WHERE [mailitem_id] = @MailId
            AND [profile_id] = @ProfileId AND [sent_status] = 'failed'
            AND EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_event_log]
                WHERE [mailitem_id] = @MailId AND [account_id] IS NULL AND [event_type] = 'error'
                  AND [process_id] > 0 AND NULLIF([description], N'') IS NOT NULL))
    BEGIN
        WAITFOR DELAY '00:00:01';
        SET @Attempts += 1;
    END;
    SELECT @NativeErrorRows = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_event_log]
        WHERE [mailitem_id] = @MailId AND [account_id] IS NULL AND [event_type] = 'error'
            AND [process_id] > 0
            AND NULLIF([description], N'') IS NOT NULL;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems]) <> 1
       OR NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
           WHERE [mailitem_id] = @MailId AND [profile_id] = @ProfileId AND [sent_status] = 'failed'
             AND [send_request_date] IS NOT NULL AND [sent_date] IS NOT NULL)
       OR @NativeErrorRows = 0
        THROW 55287, N'Der tatsächliche eigene Mailfehler mit gebundener nativer Logevidenz fehlt.', 1;
    EXEC [msdb].[dbo].[sysmail_stop_sp];
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 0;
    RECONFIGURE;
    BEGIN TRANSACTION;
    SET LOCK_TIMEOUT 137;
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
            THROW 55307, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
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
            THROW 55308, N'Die nativen Mailaggregate oder Evidenzgrenzen sind verletzt.', 1;
        IF @Consumer = 2
        BEGIN
            EXEC [sys].[sp_executesql]
                N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
            IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55309, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                THROW 55310, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
        END;
        SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
            ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
           OR EXISTS (SELECT 1 FROM [sys].[configurations]
               WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
            THROW 55311, N'Der Analyzer hat Mailquellen, Callerzustand oder die Mail-XP-Grenze verändert.', 1;
        SET @Calls += 1;
        SET @Consumer += 1;
    END;
    ROLLBACK TRANSACTION;
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 1;
    RECONFIGURE;
    EXEC @ReturnCode = [msdb].[dbo].[sysmail_delete_mailitems_sp] @sent_status = 'failed';
    IF @ReturnCode <> 0 OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
        THROW 55288, N'Das eigene native Mailitemcleanup ist unvollständig.', 1;
    EXEC [msdb].[dbo].[sysmail_delete_profile_sp] @profile_id = @ProfileId;
    EXEC [msdb].[dbo].[sysmail_delete_account_sp] @account_id = @AccountId;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_profile])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_account])
        THROW 55289, N'Das eigene Profil- und Kontocleanup ist unvollständig.', 1;
    IF @PreviousQueueStatus = N'STARTED' EXEC [msdb].[dbo].[sysmail_start_sp];
    DELETE @QueueState;
    INSERT @QueueState EXEC [msdb].[dbo].[sysmail_help_status_sp];
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 0;
    RECONFIGURE;
    EXEC [master].[sys].[sp_configure] N'show advanced options', @PreviousAdvanced;
    RECONFIGURE;
    IF @@TRANCOUNT <> 0 OR (SELECT COUNT(*) FROM @QueueState) <> 1 OR NOT EXISTS
        (SELECT 1 FROM @QueueState WHERE [Status] = @PreviousQueueStatus)
       OR EXISTS (SELECT 1 FROM [sys].[configurations]
           WHERE ([name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
              OR ([name] = N'show advanced options'
                  AND ([value] <> @PreviousAdvanced OR [value_in_use] <> @PreviousAdvanced)))
        THROW 55290, N'Der Queue- oder Konfigurationseintrittswert wurde nicht wiederhergestellt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET LOCK_TIMEOUT -1;
    IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
    /* Der Fehlerpfad benötigt das äußere identitygebundene Labcleanup für sämtliche eigenen Mailressourcen. */
    THROW;
END CATCH;
SET LOCK_TIMEOUT -1;
IF @PreviousXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
IF @Calls <> 3 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout OR (@@OPTIONS & 16384) <> @PreviousXactAbort
    THROW 55292, N'Die Consumeranzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_MAIL_EXECUTION_FAILURE' AS [ContractName], 1 AS [NativeFailedRows],
    @NativeErrorRows AS [BoundErrorRows], @Calls AS [ConsumerCalls], N'PASS' AS [Status],
    N'OWN_MAIL_PROFILE_ACCOUNT_REMOVED' AS [FixtureCleanup], N'LAB_REMOVAL_REQUIRED' AS [LogCleanup];
GO
