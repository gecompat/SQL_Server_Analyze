USE [DeineDatenbank];
GO

/* Injizierte Mailitems und Binäranlagen prüfen native Retention ohne Versand oder Queueverarbeitung. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1
)
    THROW 55501, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55516, N'Die Fixture benötigt den ursprünglichen Standard-Locktimeout -1.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
   OR EXISTS (SELECT 1 FROM [sys].[configurations]
       WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
    THROW 55502, N'Die leeren eigenen Mailquellen oder deaktivierten Mail-XPs fehlen.', 1;
IF (SELECT COUNT_BIG(*) FROM [msdb].[sys].[columns]
    WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmail_mailattachments')) <> 7
   OR EXISTS
   (
       SELECT [Name], [TypeId] FROM (VALUES
           (N'attachment_id', 56), (N'mailitem_id', 56), (N'filename', 231),
           (N'filesize', 56), (N'attachment', 165), (N'last_mod_date', 61),
           (N'last_mod_user', 231)) [e]([Name], [TypeId])
       EXCEPT SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS, [system_type_id]
           FROM [msdb].[sys].[columns]
           WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmail_mailattachments')
   ) OR EXISTS (SELECT 1 FROM [msdb].[sys].[columns]
       WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmail_mailattachments') AND [max_length] <> -1
         AND (([name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'filename' AND [max_length] < 48)
           OR ([name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'attachment' AND [max_length] < 9)
           OR ([name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'last_mod_user' AND [max_length] < 22)))
BEGIN
    DECLARE @SchemaMessage nvarchar(2048);
    SELECT @SchemaMessage = N'Der native Anlagenvertrag fehlt: ' +
        (SELECT [name], [system_type_id], [max_length] FROM [msdb].[sys].[columns]
            WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmail_mailattachments')
            ORDER BY [column_id] FOR JSON PATH);
    THROW 55513, @SchemaMessage, 1;
END;
DECLARE @Stage int = 1, @Phase int = 1, @Consumer int, @Calls int = 0, @KeepMail int;
DECLARE @CurrentMail int, @AttachmentNo int, @Payload varbinary(32), @FileNames nvarchar(max);
DECLARE @AttachmentBefore nvarchar(max), @AttachmentAfter nvarchar(max), @RetainedAttachment nvarchar(max);
DECLARE @AttachmentAfterPurge nvarchar(max), @ExpectedAttachmentCount bigint;
CREATE TABLE [#Ops008OwnMail] ([Ordinal] int NOT NULL PRIMARY KEY, [MailId] int NOT NULL UNIQUE);
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
        SET @FileNames = N'ExampleAttachment' + CONVERT(nvarchar(1), @Stage) + N'-1.bin;ExampleAttachment'
            + CONVERT(nvarchar(1), @Stage) + N'-2.bin';
        INSERT [msdb].[dbo].[sysmail_mailitems]
            ([profile_id], [recipients], [subject], [body], [file_attachments], [send_request_date],
             [send_request_user], [sent_status], [sent_date], [last_mod_user])
        VALUES (0, N'ExampleRecipient', N'Example synthetic subject', N'Example synthetic body',
            @FileNames, @Date, N'ExampleUser', 2, @Date, N'ExampleUser');
        SET @CurrentMail = CONVERT(int, SCOPE_IDENTITY());
        INSERT [#Ops008OwnMail] VALUES (@Stage, @CurrentMail);
        IF @Stage = 2 SET @KeepMail = @CurrentMail;
        SET @AttachmentNo = 1;
        WHILE @AttachmentNo <= 2
        BEGIN
            SET @Payload = 0x4578616D706C65 + CONVERT(binary(1), @Stage) + CONVERT(binary(1), @AttachmentNo);
            INSERT [msdb].[dbo].[sysmail_mailattachments]
                ([mailitem_id], [filename], [filesize], [attachment], [last_mod_date], [last_mod_user])
            VALUES (@CurrentMail, N'ExampleAttachment' + CONVERT(nvarchar(1), @Stage) + N'-'
                + CONVERT(nvarchar(1), @AttachmentNo) + N'.bin', DATALENGTH(@Payload), @Payload,
                @Date, N'ExampleUser');
            SET @AttachmentNo += 1;
        END;
        SET @Stage += 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailitems]) <> 3
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_allitems]) <> 3
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems]
           WHERE [sent_status] COLLATE SQL_Latin1_General_CP1_CS_AS <> 'failed')
        THROW 55503, N'Die drei injizierten eigenen Failed-Mailzeilen fehlen.', 1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailattachments]) <> 6
       OR (SELECT SUM(CONVERT(bigint, [filesize])) FROM [msdb].[dbo].[sysmail_mailattachments]) <> 54
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments]
           WHERE [attachment] IS NULL OR [filesize] <> 9 OR DATALENGTH([attachment]) <> [filesize])
       OR EXISTS (SELECT 1 FROM [#Ops008OwnMail] [o] WHERE
           (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailattachments] [a]
            WHERE [a].[mailitem_id] = [o].[MailId]) <> 2)
        THROW 55514, N'Die sechs eigenen Binäranlagen oder Mailbindungen fehlen.', 1;
    SELECT @RetainedAttachment = (SELECT * FROM [msdb].[dbo].[sysmail_mailattachments]
        WHERE [mailitem_id] = @KeepMail ORDER BY [attachment_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @Retained = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
        WHERE [mailitem_id] = @KeepMail ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedCount = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        SET @ExpectedAttachmentCount = @ExpectedCount * 2;
        SET @Low = CASE @Phase WHEN 1 THEN CONVERT(datetime2(3), '2000-01-01T12:00:00', 126)
            WHEN 2 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        SET @High = CASE WHEN @Phase < 3 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00'
                ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sysmail_delete_mailitems_sp]
                @sent_before = @Cutoff, @sent_status = 'failed';
            IF @ReturnCode <> 0 THROW 55504, N'Die native eigene Mailbereinigung ist fehlgeschlagen.', 1;
            SELECT @AfterPurge = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @Retained COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55505, N'Die vollständigen jüngeren Mailwerte sind nach Retention verändert.', 1;
            SELECT @AttachmentAfterPurge = (SELECT * FROM [msdb].[dbo].[sysmail_mailattachments]
                ORDER BY [attachment_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @RetainedAttachment COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AttachmentAfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55515, N'Die vollständigen jüngeren Anlagenwerte sind nach Retention verändert.', 1;
        END;
        IF EXISTS
        (
            SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([send_request_date])),
                CONVERT(datetime2(3), MAX([send_request_date])) FROM [msdb].[dbo].[sysmail_allitems]
            EXCEPT SELECT @ExpectedCount, @Low, @High
        ) OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailitems]) <> @ExpectedCount
          OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailattachments]) <> @ExpectedAttachmentCount
          OR COALESCE((SELECT SUM(CONVERT(bigint, [filesize])) FROM [msdb].[dbo].[sysmail_mailattachments]), 0)
                <> @ExpectedAttachmentCount * 9
          OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments] [a] WHERE NOT EXISTS
                (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems] [m] WHERE [m].[mailitem_id] = [a].[mailitem_id]))
          OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
            THROW 55506, N'Die unabhängigen Retentioncounts, Zeitgrenzen oder Callerbasis sind verletzt.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @AttachmentBefore = (SELECT * FROM [msdb].[dbo].[sysmail_mailattachments]
                ORDER BY [attachment_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
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
                THROW 55507, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
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
                THROW 55508, N'Die nativen Mailaggregate oder Evidenzgrenzen sind verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 55509, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                    THROW 55510, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmail_mailitems]
                ORDER BY [mailitem_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @AttachmentAfter = (SELECT * FROM [msdb].[dbo].[sysmail_mailattachments]
                ORDER BY [attachment_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmail_mailattachments]) <> @ExpectedAttachmentCount
               OR COALESCE((SELECT SUM(CONVERT(bigint, [filesize])) FROM [msdb].[dbo].[sysmail_mailattachments]), 0)
                   <> @ExpectedAttachmentCount * 9
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments] [a] WHERE NOT EXISTS
                   (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems] [m] WHERE [m].[mailitem_id] = [a].[mailitem_id]))
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
               OR EXISTS (SELECT @AttachmentBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @AttachmentAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT 1 FROM [sys].[configurations]
                   WHERE [name] = N'Database Mail XPs' AND ([value] <> 0 OR [value_in_use] <> 0))
                THROW 55511, N'Der Analyzer hat Mail-/Anlagenquellen, Callerzustand oder die Mail-XP-Grenze verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @Phase += 1;
    END;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0 OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmail_mailattachments])
        THROW 55512, N'Die eigene injizierte Mailfixture wurde nicht vollständig zurückgerollt.', 1;
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
    THROW 55517, N'Die Consumerzahl oder ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console], [#Ops008OwnMail];
SELECT N'OPS008_MAIL_ATTACHMENT_RETENTION' AS [ContractName],
    3 AS [InitialMailRows], 1 AS [RetainedMailRows], 0 AS [FinalMailRows],
    6 AS [InitialAttachmentRows], 2 AS [RetainedAttachmentRows], 0 AS [FinalAttachmentRows], @Calls AS [ConsumerCalls], N'PASS' AS [Status],
    N'ROLLED_BACK' AS [FixtureCleanup];
GO
