USE [DeineDatenbank];
GO

/* Native Mailfehler und kontrollierte Logzeitstempel prüfen Datums- und Ereignistypretention. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
   OR NOT EXISTS (SELECT 1 FROM [sys].[extended_properties]
       WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1)
    THROW 55411, N'Die eigene Wegwerf-Lab-Bindung oder Callerbasis fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_event_log])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_profile])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_account])
   OR EXISTS (SELECT 1 FROM [sys].[configurations]
       WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
   OR NOT EXISTS (SELECT 1 FROM [sys].[databases] WHERE [name] = N'msdb' AND [is_broker_enabled] = 1)
    THROW 55412, N'Die leeren eigenen Mailquellen, deaktivierten XPs oder Brokerbasis fehlen.', 1;
DECLARE @PreviousAdvanced int;
SELECT @PreviousAdvanced = CONVERT(int, [value]) FROM [sys].[configurations]
    WHERE [name] = N'show advanced options' AND [value] = [value_in_use];
IF @PreviousAdvanced IS NULL THROW 55413, N'Der stabile Advanced-Options-Eintrittswert fehlt.', 1;
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
DECLARE @NativeErrorRows bigint, @ExpectedLogCount bigint, @ActualLogCount bigint, @Phase int = 1, @Ordinal int = 1;
DECLARE @Cutoff datetime, @InfoLogId int, @LogIdColumn sysname, @LogSql nvarchar(max);
DECLARE @MailBaseline nvarchar(max), @ProtectedBaseline nvarchar(max), @ProtectedAfter nvarchar(max);
DECLARE @TargetBefore nvarchar(max), @TargetAfter nvarchar(max), @RetainedLog nvarchar(max);
DECLARE @KeepMail int, @InfoType varchar(15);
DECLARE @OriginalLogRows nvarchar(max), @OriginalLogAfter nvarchar(max), @OwnLogSnapshotSql nvarchar(max);
DECLARE @TargetSnapshotSql nvarchar(max), @RetainedSnapshotSql nvarchar(max);
SELECT @LogIdColumn = [name] FROM [msdb].[sys].[columns]
WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmail_event_log') AND [column_id] = 1
    AND LOWER([name] COLLATE SQL_Latin1_General_CP1_CS_AS) = N'log_id' AND [system_type_id] = 56;
IF @LogIdColumn IS NULL THROW 55401, N'Der native führende Log-ID-Vertrag fehlt.', 1;
CREATE TABLE [#Ops008OwnMail] ([Ordinal] int PRIMARY KEY, [MailId] int UNIQUE);
CREATE TABLE [#Ops008OwnLog] ([LogId] int PRIMARY KEY);
CREATE TABLE [#Ops008ProtectedLog] ([LogId] int PRIMARY KEY);

DECLARE @Before nvarchar(max), @After nvarchar(max);
DECLARE @Consumer int = 1, @Calls int = 0, @Mode varchar(16), @Mapping nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    EXEC [master].[sys].[sp_configure] N'show advanced options', 1;
    RECONFIGURE;
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 1;
    RECONFIGURE;
    INSERT @QueueState EXEC [msdb].[dbo].[sysmail_help_status_sp];
    SELECT @PreviousQueueStatus = [Status] FROM @QueueState;
    IF (SELECT COUNT(*) FROM @QueueState) <> 1 OR COALESCE(@PreviousQueueStatus, N'') NOT IN (N'STARTED', N'STOPPED')
        THROW 55414, N'Der native Mailqueue-Eintrittsstatus fehlt.', 1;
    EXEC [msdb].[dbo].[sysmail_add_profile_sp] @profile_name = N'ExampleOps008LogProfile',
        @description = N'Synthetic local log retention contract.', @profile_id = @ProfileId OUTPUT;
    EXEC [msdb].[dbo].[sysmail_add_account_sp] @account_name = N'ExampleOps008LogAccount',
        @email_address = N'ExampleSender@example.invalid', @display_name = N'ExampleSender',
        @mailserver_name = N'localhost', @port = 1, @username = NULL,
        @use_default_credentials = 0, @enable_ssl = 0, @account_id = @AccountId OUTPUT;
    INSERT @Account EXEC [msdb].[dbo].[sysmail_help_account_sp] @account_id = @AccountId;
    IF @ProfileId IS NULL OR @AccountId IS NULL OR (SELECT COUNT(*) FROM @Account) <> 1
       OR NOT EXISTS (SELECT 1 FROM @Account WHERE [account_id] = @AccountId
           AND [name] = N'ExampleOps008LogAccount' AND [servertype] = N'SMTP'
           AND [servername] = N'localhost' AND [port] = 1 AND [username] IS NULL
           AND [use_default_credentials] = 0 AND [enable_ssl] = 0
           AND [email_address] = N'ExampleSender@example.invalid')
        THROW 55415, N'Die eigene lokale SMTP-Kontobindung ohne Credentials fehlt.', 1;
    EXEC [msdb].[dbo].[sysmail_add_profileaccount_sp] @profile_id = @ProfileId,
        @account_id = @AccountId, @sequence_number = 1;
    EXEC [msdb].[dbo].[sysmail_start_sp];
    WHILE @Ordinal <= 3
    BEGIN
        SET @MailId = NULL;
        EXEC @ReturnCode = [msdb].[dbo].[sp_send_dbmail] @profile_name = N'ExampleOps008LogProfile',
            @recipients = 'ExampleRecipient@example.invalid', @subject = N'Example synthetic failure',
            @body = N'Example synthetic body', @mailitem_id = @MailId OUTPUT;
        IF @ReturnCode <> 0 OR @MailId IS NULL THROW 55402, N'Der eigene native Queueauftrag fehlt.', 1;
        INSERT [#Ops008OwnMail] VALUES (@Ordinal, @MailId);
        SET @Attempts = 0;
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
        IF NOT EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
                WHERE [mailitem_id] = @MailId AND [profile_id] = @ProfileId AND [sent_status] = 'failed'
                  AND EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_event_log]
                      WHERE [mailitem_id] = @MailId AND [account_id] IS NULL AND [event_type] = 'error'
                        AND [process_id] > 0 AND NULLIF([description], N'') IS NOT NULL))
        BEGIN
            DECLARE @WaitMessage nvarchar(2048), @FailedCount bigint, @BoundCount bigint;
            SELECT @FailedCount = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems] [m]
                WHERE [sent_status] = 'failed' AND EXISTS
                  (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE [o].[MailId] = [m].[mailitem_id]);
            SELECT @BoundCount = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_event_log] [l]
                WHERE [account_id] IS NULL AND [event_type] = 'error' AND [process_id] > 0
                  AND NULLIF([description], N'') IS NOT NULL AND EXISTS
                  (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE [o].[MailId] = [l].[mailitem_id]);
            SET @WaitMessage = N'Der native eigene Mailfehler fehlt nach begrenztem Einzelpoll: Ordinal='
                + CONVERT(nvarchar(10), @Ordinal) + N'; FailedCount=' + CONVERT(nvarchar(20), @FailedCount)
                + N'; BoundErrorCount=' + CONVERT(nvarchar(20), @BoundCount) + N'.';
            THROW 55410, @WaitMessage, 1;
        END;
        SET @Ordinal += 1;
    END;
    SELECT @NativeErrorRows = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_event_log] [l]
        WHERE [account_id] IS NULL AND [event_type] = 'error' AND [process_id] > 0
          AND NULLIF([description], N'') IS NOT NULL
          AND EXISTS (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE [o].[MailId] = [l].[mailitem_id]);
    DECLARE @OwnMailRows bigint, @RequestedFailedRows bigint, @PreconditionMessage nvarchar(2048);
    SELECT @OwnMailRows = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems];
    SELECT @RequestedFailedRows = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems] [m]
        WHERE [profile_id] = @ProfileId AND [sent_status] = 'failed'
          AND [send_request_date] IS NOT NULL
          AND EXISTS (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE [o].[MailId] = [m].[mailitem_id]);
    IF @OwnMailRows <> 3 OR @NativeErrorRows < 3 OR @RequestedFailedRows <> 3
    BEGIN
        SET @PreconditionMessage = N'Die eigene native Mailbasis fehlt: MailRows='
            + CONVERT(nvarchar(20), @OwnMailRows) + N'; RequestedFailedRows='
            + CONVERT(nvarchar(20), @RequestedFailedRows) + N'; BoundErrorRows='
            + CONVERT(nvarchar(20), @NativeErrorRows) + N'.';
        THROW 55403, @PreconditionMessage, 1;
    END;
    EXEC [msdb].[dbo].[sysmail_stop_sp];
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 0;
    RECONFIGURE;
    SET @LogSql = N'INSERT [#Ops008OwnLog] SELECT MIN(' + QUOTENAME(@LogIdColumn) + N')
        FROM [msdb].[dbo].[sysmail_event_log] [l] WHERE [event_type] = ''error'' AND [account_id] IS NULL
          AND [process_id] > 0 AND NULLIF([description], N'''') IS NOT NULL
          AND EXISTS (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE [o].[MailId] = [l].[mailitem_id])
        GROUP BY [mailitem_id];
        SELECT TOP (1) @InfoId = ' + QUOTENAME(@LogIdColumn) + N', @NativeInfoType = [event_type]
        FROM [msdb].[dbo].[sysmail_event_log] WHERE [event_type] IN (''information'', ''informational'')
        ORDER BY ' + QUOTENAME(@LogIdColumn) + N';';
    EXEC [sys].[sp_executesql] @LogSql, N'@InfoId int OUTPUT, @NativeInfoType varchar(15) OUTPUT',
        @InfoId = @InfoLogId OUTPUT, @NativeInfoType = @InfoType OUTPUT;
    IF (SELECT COUNT_BIG(*) FROM [#Ops008OwnLog]) <> 3 OR @InfoLogId IS NULL
        THROW 55404, N'Die eindeutigen eigenen Fehlerlogs oder native Informationsgegenprobe fehlen.', 1;
    SELECT @KeepMail = [MailId] FROM [#Ops008OwnMail] WHERE [Ordinal] = 2;
    SET @OwnLogSnapshotSql = N'SELECT @Rows = (SELECT * FROM [msdb].[dbo].[sysmail_event_log] [l]
        WHERE [l].' + QUOTENAME(@LogIdColumn) + N' = @InfoId OR EXISTS
          (SELECT 1 FROM [#Ops008OwnLog] [o] WHERE [o].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N')
        ORDER BY 1 FOR JSON PATH, INCLUDE_NULL_VALUES);';
    EXEC [sys].[sp_executesql] @OwnLogSnapshotSql, N'@InfoId int, @Rows nvarchar(max) OUTPUT',
        @InfoId = @InfoLogId, @Rows = @OriginalLogRows OUTPUT;
    BEGIN TRANSACTION;
    SET LOCK_TIMEOUT 137;
    SELECT @MailBaseline = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
        ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SET @LogSql = N'UPDATE [l] SET [log_date] = CONVERT(datetime, CASE [o].[Ordinal]
        WHEN 1 THEN ''2025-01-01T12:00:00'' WHEN 2 THEN ''2025-01-02T12:00:00''
        ELSE ''2000-01-01T12:00:00'' END, 126)
        FROM [msdb].[dbo].[sysmail_event_log] [l]
        JOIN [#Ops008OwnMail] [o] ON [o].[MailId] = [l].[mailitem_id]
        JOIN [#Ops008OwnLog] [k] ON [k].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N';
        IF @@ROWCOUNT <> 3 THROW 55405, N''Die kontrollierten eigenen Fehlerlogzeiten fehlen.'', 1;';
    EXEC [sys].[sp_executesql] @LogSql;
    SET @LogSql = N'UPDATE [msdb].[dbo].[sysmail_event_log]
        SET [log_date] = CONVERT(datetime, ''2000-01-01T12:00:00'', 126)
        WHERE ' + QUOTENAME(@LogIdColumn) + N' = @InfoId AND [event_type] = @NativeInfoType;
        IF @@ROWCOUNT <> 1 THROW 55406, N''Die ältere Informationsgegenprobe fehlt.'', 1;
        INSERT [#Ops008ProtectedLog] SELECT ' + QUOTENAME(@LogIdColumn) + N'
        FROM [msdb].[dbo].[sysmail_event_log] [l] WHERE NOT EXISTS
          (SELECT 1 FROM [#Ops008OwnLog] [o] WHERE [o].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N');
        SELECT @Rows = (SELECT * FROM [msdb].[dbo].[sysmail_event_log] [l] WHERE EXISTS
          (SELECT 1 FROM [#Ops008ProtectedLog] [p] WHERE [p].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N')
          ORDER BY 1 FOR JSON PATH, INCLUDE_NULL_VALUES);';
    EXEC [sys].[sp_executesql] @LogSql, N'@InfoId int, @NativeInfoType varchar(15), @Rows nvarchar(max) OUTPUT',
        @InfoId = @InfoLogId, @NativeInfoType = @InfoType, @Rows = @ProtectedBaseline OUTPUT;
    SET @RetainedSnapshotSql = N'SELECT @Rows = (SELECT * FROM [msdb].[dbo].[sysmail_event_log] [l]
        WHERE [mailitem_id] = @KeepId AND EXISTS
          (SELECT 1 FROM [#Ops008OwnLog] [o] WHERE [o].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N')
        ORDER BY 1 FOR JSON PATH, INCLUDE_NULL_VALUES);';
    SET @TargetSnapshotSql = N'SELECT @Rows = (SELECT * FROM [msdb].[dbo].[sysmail_event_log] [l]
        WHERE EXISTS (SELECT 1 FROM [#Ops008OwnLog] [o] WHERE [o].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N')
        ORDER BY 1 FOR JSON PATH, INCLUDE_NULL_VALUES);
        SELECT @Count = COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_event_log] [l]
        WHERE EXISTS (SELECT 1 FROM [#Ops008OwnLog] [o] WHERE [o].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N');';
    EXEC [sys].[sp_executesql] @RetainedSnapshotSql, N'@KeepId int, @Rows nvarchar(max) OUTPUT',
        @KeepId = @KeepMail, @Rows = @RetainedLog OUTPUT;
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedLogCount = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00'
                ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sysmail_delete_log_sp]
                @logged_before = @Cutoff, @event_type = 'error';
            IF @ReturnCode <> 0 THROW 55407, N'Die native Logbereinigung ist fehlgeschlagen.', 1;
        END;
        SET @LogSql = N'SELECT @Rows = (SELECT * FROM [msdb].[dbo].[sysmail_event_log] [l] WHERE EXISTS
          (SELECT 1 FROM [#Ops008ProtectedLog] [p] WHERE [p].[LogId] = [l].' + QUOTENAME(@LogIdColumn) + N')
          ORDER BY 1 FOR JSON PATH, INCLUDE_NULL_VALUES);';
        EXEC [sys].[sp_executesql] @LogSql, N'@Rows nvarchar(max) OUTPUT', @Rows = @ProtectedAfter OUTPUT;
        EXEC [sys].[sp_executesql] @RetainedSnapshotSql, N'@KeepId int, @Rows nvarchar(max) OUTPUT',
            @KeepId = @KeepMail, @Rows = @TargetAfter OUTPUT;
        EXEC [sys].[sp_executesql] @TargetSnapshotSql, N'@Rows nvarchar(max) OUTPUT, @Count bigint OUTPUT',
            @Rows = @TargetBefore OUTPUT, @Count = @ActualLogCount OUTPUT;
        IF EXISTS (SELECT @ProtectedBaseline COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @ProtectedAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR (@Phase = 2 AND EXISTS (SELECT @RetainedLog COLLATE SQL_Latin1_General_CP1_CS_AS
               EXCEPT SELECT @TargetAfter COLLATE SQL_Latin1_General_CP1_CS_AS))
           OR @ActualLogCount <> @ExpectedLogCount
           OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems]) <> 3
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
            THROW 55408, N'Die Logcounts, erhaltenen Logwerte, Mailmenge oder Callerbasis sind verletzt.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            EXEC [sys].[sp_executesql] @TargetSnapshotSql, N'@Rows nvarchar(max) OUTPUT, @Count bigint OUTPUT',
                @Rows = @TargetBefore OUTPUT, @Count = @ActualLogCount OUTPUT;
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
                THROW 55421, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
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
                THROW 55422, N'Die nativen Mailaggregate oder Evidenzgrenzen sind verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 55423, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                    THROW 55424, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            EXEC [sys].[sp_executesql] @LogSql, N'@Rows nvarchar(max) OUTPUT', @Rows = @ProtectedAfter OUTPUT;
            EXEC [sys].[sp_executesql] @TargetSnapshotSql, N'@Rows nvarchar(max) OUTPUT, @Count bigint OUTPUT',
                @Rows = @TargetAfter OUTPUT, @Count = @ActualLogCount OUTPUT;
            IF EXISTS (SELECT @ProtectedBaseline COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @ProtectedAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT @TargetBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @TargetAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT @MailBaseline COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
               OR EXISTS (SELECT 1 FROM [sys].[configurations]
                   WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
                THROW 55425, N'Der Analyzer hat Mailquellen, Callerzustand oder die Mail-XP-Grenze verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @Phase += 1;
    END;
    ROLLBACK TRANSACTION;
    EXEC [sys].[sp_executesql] @OwnLogSnapshotSql, N'@InfoId int, @Rows nvarchar(max) OUTPUT',
        @InfoId = @InfoLogId, @Rows = @OriginalLogAfter OUTPUT;
    IF EXISTS (SELECT @OriginalLogRows COLLATE SQL_Latin1_General_CP1_CS_AS
        EXCEPT SELECT @OriginalLogAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@OriginalLogAfter)) <> 4
        THROW 55409, N'Die eigene kontrollierte Logfixture wurde nicht zurückgerollt.', 1;
    EXEC [master].[sys].[sp_configure] N'Database Mail XPs', 1;
    RECONFIGURE;
    EXEC @ReturnCode = [msdb].[dbo].[sysmail_delete_mailitems_sp] @sent_status = 'failed';
    IF @ReturnCode <> 0 OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
        THROW 55418, N'Das eigene native Mailitemcleanup ist unvollständig.', 1;
    EXEC [msdb].[dbo].[sysmail_delete_profile_sp] @profile_id = @ProfileId;
    EXEC [msdb].[dbo].[sysmail_delete_account_sp] @account_id = @AccountId;
    IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_profile])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_account])
        THROW 55419, N'Das eigene Profil- und Kontocleanup ist unvollständig.', 1;
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
        THROW 55420, N'Der Queue- oder Konfigurationseintrittswert wurde nicht wiederhergestellt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
    /* Der Fehlerpfad benötigt das äußere identitygebundene Labcleanup für sämtliche eigenen Mailressourcen. */
    THROW;
END CATCH;
SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
DROP TABLE [#Ops008Console];
DROP TABLE [#Ops008ProtectedLog], [#Ops008OwnLog], [#Ops008OwnMail];
SELECT N'OPS008_MAIL_LOG_RETENTION' AS [ContractName], 3 AS [NativeFailedRows],
    3 AS [SelectedInitialErrorRows], 1 AS [SelectedRetainedErrorRows], 0 AS [SelectedFinalErrorRows],
    @NativeErrorRows AS [BoundErrorRows], @Calls AS [ConsumerCalls], N'PASS' AS [Status],
    N'OWN_MAIL_PROFILE_ACCOUNT_REMOVED' AS [FixtureCleanup], N'LAB_REMOVAL_REQUIRED' AS [LogCleanup];
GO
