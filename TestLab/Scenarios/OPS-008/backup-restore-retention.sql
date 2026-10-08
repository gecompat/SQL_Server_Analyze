USE [DeineDatenbank];
GO

/* Die Fixture prüft ausschließlich Backup-/Restore-Retention im neuen eigenen Lab. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int,[value]) = 1
) OR DB_ID(N'ExampleOps008Retention') IS NOT NULL OR DB_ID(N'ExampleOps008RetentionRestore') IS NOT NULL
    THROW 55161, N'Die eigene Wegwerf-Lab-Bindung, Transaktionsbasis oder freie Datenbanknamen fehlen.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55181, N'Der ursprüngliche Standardlocktimeout fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[backupset]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupfile]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupfilegroup]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupmediaset]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupmediafamily]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorehistory]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorefile]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorefilegroup])
    THROW 55162, N'Die acht nativen Backup-/Restore-Historien sind nicht leer; keine Bereinigung ist erlaubt.', 1;
DECLARE @CreatedSource bit = 0, @CreatedRestore bit = 0, @SourceId int, @RestoreDbId int;
DECLARE @Stage int = 1, @Phase int = 1, @Consumer int, @Calls int = 0, @ExpectedCount bigint;
DECLARE @BackupId int, @RestoreId int, @KeepBackup int, @KeepRestore int, @KeepMedia int;
DECLARE @ExpectedDate datetime, @Cutoff datetime, @BackupPath nvarchar(260);
DECLARE @Low datetime2(3), @High datetime2(3), @DbBefore nvarchar(max), @DbAfter nvarchar(max);
DECLARE @Before nvarchar(max), @After nvarchar(max), @Retained nvarchar(max), @AfterPurge nvarchar(max);
DECLARE @Mode varchar(20), @Mapping nvarchar(max), @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(4000);
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @ReturnCode int;
DECLARE @PreviousXactAbort bit = CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END;
CREATE TABLE [#Ops008Native]
(
    [Area] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3)
);
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(256), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    SET XACT_ABORT ON;
    CREATE DATABASE [ExampleOps008Retention] COLLATE SQL_Latin1_General_CP1_CS_AS;
    SELECT @CreatedSource = 1, @SourceId = DB_ID(N'ExampleOps008Retention');
    WHILE @Stage <= 3
    BEGIN
        SET @BackupPath = N'/var/opt/mssql/data/ExampleOps008Retention' + CONVERT(nvarchar(10), @Stage) + N'.bak';
        BACKUP DATABASE [ExampleOps008Retention] TO DISK = @BackupPath WITH INIT, COPY_ONLY;
        SELECT @BackupId = MAX([backup_set_id]) FROM [msdb].[dbo].[backupset]
            WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008Retention';
        SET @ExpectedDate = CONVERT(datetime, CASE @Stage WHEN 1 THEN '2025-01-01T12:00:00'
            WHEN 2 THEN '2025-01-02T12:00:00' ELSE '2000-01-01T12:00:00' END, 126);
        UPDATE [msdb].[dbo].[backupset] SET [backup_start_date] = @ExpectedDate, [backup_finish_date] = @ExpectedDate
            WHERE [backup_set_id] = @BackupId AND [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008Retention';
        IF @@ROWCOUNT <> 1 THROW 55163, N'Der neue eigene Backupdatensatz fehlt.', 1;
        RESTORE DATABASE [ExampleOps008RetentionRestore] FROM DISK = @BackupPath
            WITH MOVE N'ExampleOps008Retention' TO N'/var/opt/mssql/data/ExampleOps008RetentionRestore.mdf',
                 MOVE N'ExampleOps008Retention_log' TO N'/var/opt/mssql/data/ExampleOps008RetentionRestore_log.ldf', REPLACE;
        SELECT @CreatedRestore = 1, @RestoreDbId = DB_ID(N'ExampleOps008RetentionRestore');
        SELECT @RestoreId = MAX([restore_history_id]) FROM [msdb].[dbo].[restorehistory]
            WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008RetentionRestore';
        UPDATE [msdb].[dbo].[restorehistory] SET [restore_date] = @ExpectedDate
            WHERE [restore_history_id] = @RestoreId AND [backup_set_id] = @BackupId
              AND [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008RetentionRestore';
        IF @@ROWCOUNT <> 1 THROW 55164, N'Das neue eigene Backup-/Restore-Paar fehlt.', 1;
        IF @Stage = 2
        BEGIN
            SELECT @KeepBackup = @BackupId, @KeepRestore = @RestoreId;
            SELECT @KeepMedia = [media_set_id] FROM [msdb].[dbo].[backupset] WHERE [backup_set_id] = @BackupId;
        END;
        SET @Stage += 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[backupset]) <> 3
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[restorehistory]) <> 3
       OR (SELECT COUNT_BIG(DISTINCT [media_set_id]) FROM [msdb].[dbo].[backupset]) <> 3
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[backupset]
            WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS <> N'ExampleOps008Retention')
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[restorehistory]
            WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS <> N'ExampleOps008RetentionRestore')
        THROW 55165, N'Die drei unabhängigen eigenen Backup-/Restore-Paare fehlen.', 1;
    SELECT @DbBefore = (SELECT [database_id], [name], [create_date], [collation_name], [state], [user_access],
        [recovery_model], [is_read_only] FROM [sys].[databases] WHERE [database_id] IN (@SourceId, @RestoreDbId)
        ORDER BY [database_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @Retained = (SELECT (SELECT * FROM [msdb].[dbo].[backupset] WHERE [backup_set_id] = @KeepBackup ORDER BY [backup_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupset],
        (SELECT * FROM [msdb].[dbo].[backupfile] WHERE [backup_set_id] = @KeepBackup ORDER BY [backup_set_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfile],
        (SELECT * FROM [msdb].[dbo].[backupfilegroup] WHERE [backup_set_id] = @KeepBackup ORDER BY [backup_set_id], [filegroup_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfilegroup],
        (SELECT * FROM [msdb].[dbo].[backupmediaset] WHERE [media_set_id] = @KeepMedia ORDER BY [media_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediaset],
        (SELECT * FROM [msdb].[dbo].[backupmediafamily] WHERE [media_set_id] = @KeepMedia ORDER BY [media_set_id], [family_sequence_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediafamily],
        (SELECT * FROM [msdb].[dbo].[restorehistory] WHERE [restore_history_id] = @KeepRestore ORDER BY [restore_history_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorehistory],
        (SELECT * FROM [msdb].[dbo].[restorefile] WHERE [restore_history_id] = @KeepRestore ORDER BY [restore_history_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefile],
        (SELECT * FROM [msdb].[dbo].[restorefilegroup] WHERE [restore_history_id] = @KeepRestore ORDER BY [restore_history_id], [filegroup_name] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefilegroup] FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER);
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedCount = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00' ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sp_delete_backuphistory] @oldest_date = @Cutoff;
            IF @ReturnCode <> 0 THROW 55174, N'Die native Historienbereinigung ist fehlgeschlagen.', 1;
            SELECT @AfterPurge = (SELECT (SELECT * FROM [msdb].[dbo].[backupset] ORDER BY [backup_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupset],
        (SELECT * FROM [msdb].[dbo].[backupfile] ORDER BY [backup_set_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfile],
        (SELECT * FROM [msdb].[dbo].[backupfilegroup] ORDER BY [backup_set_id], [filegroup_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfilegroup],
        (SELECT * FROM [msdb].[dbo].[backupmediaset] ORDER BY [media_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediaset],
        (SELECT * FROM [msdb].[dbo].[backupmediafamily] ORDER BY [media_set_id], [family_sequence_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediafamily],
        (SELECT * FROM [msdb].[dbo].[restorehistory] ORDER BY [restore_history_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorehistory],
        (SELECT * FROM [msdb].[dbo].[restorefile] ORDER BY [restore_history_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefile],
        (SELECT * FROM [msdb].[dbo].[restorefilegroup] ORDER BY [restore_history_id], [filegroup_name] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefilegroup] FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER);
            IF @Phase = 2 AND EXISTS (SELECT @Retained COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55175, N'Die jüngeren vollständigen Historienwerte sind nach Retention verändert.', 1;
            IF @Phase = 3 AND (EXISTS (SELECT 1 FROM [msdb].[dbo].[backupset]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupfile]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupfilegroup]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupmediaset]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[backupmediafamily]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorehistory]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorefile]) OR
   EXISTS (SELECT 1 FROM [msdb].[dbo].[restorefilegroup]))
                THROW 55176, N'Die acht eigenen Historienquellen sind nach der zweiten Bereinigung nicht leer.', 1;
        END;
        TRUNCATE TABLE [#Ops008Native];
        INSERT [#Ops008Native]
        SELECT 'BACKUP_HISTORY', N'msdb.dbo.backupset', COUNT_BIG(*), MIN([backup_finish_date]), MAX([backup_finish_date]) FROM [msdb].[dbo].[backupset]
        UNION ALL
        SELECT 'RESTORE_HISTORY', N'msdb.dbo.restorehistory', COUNT_BIG(*), MIN([restore_date]), MAX([restore_date]) FROM [msdb].[dbo].[restorehistory];
        SET @Low = CASE @Phase WHEN 1 THEN CONVERT(datetime2(3), '2000-01-01T12:00:00',126)
            WHEN 2 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00',126) ELSE NULL END;
        SET @High = CASE WHEN @Phase < 3 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00',126) ELSE NULL END;
        IF EXISTS (SELECT [RowCount], [OldestUtc], [NewestUtc] FROM [#Ops008Native]
                   EXCEPT SELECT @ExpectedCount, @Low, @High)
            THROW 55177, N'Die unabhängigen nativen Retentioncounts oder Zeitgrenzen sind verletzt.', 1;
        SELECT @Consumer = 1;
        TRUNCATE TABLE [#Ops008Console];
        BEGIN TRANSACTION;
        SET LOCK_TIMEOUT 137;
    WHILE @Consumer <= 3
    BEGIN
        SELECT @Before = (SELECT (SELECT * FROM [msdb].[dbo].[backupset] ORDER BY [backup_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupset],
        (SELECT * FROM [msdb].[dbo].[backupfile] ORDER BY [backup_set_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfile],
        (SELECT * FROM [msdb].[dbo].[backupfilegroup] ORDER BY [backup_set_id], [filegroup_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfilegroup],
        (SELECT * FROM [msdb].[dbo].[backupmediaset] ORDER BY [media_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediaset],
        (SELECT * FROM [msdb].[dbo].[backupmediafamily] ORDER BY [media_set_id], [family_sequence_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediafamily],
        (SELECT * FROM [msdb].[dbo].[restorehistory] ORDER BY [restore_history_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorehistory],
        (SELECT * FROM [msdb].[dbo].[restorefile] ORDER BY [restore_history_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefile],
        (SELECT * FROM [msdb].[dbo].[restorefilegroup] ORDER BY [restore_history_id], [filegroup_name] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefilegroup] FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER);

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
               WITH ([Area] varchar(40)) WHERE [Area] IN ('BACKUP_HISTORY','RESTORE_HISTORY')) <> 2
            THROW 55166, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
        IF EXISTS
        (
            SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc],
                CONVERT(decimal(19,2), NULL) AS [SizeMb], CONVERT(varchar(40), 'AVAILABLE') AS [StatusCode]
            FROM [#Ops008Native]
            EXCEPT
            SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
            FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                [OldestUtc] datetime2(3), [NewestUtc] datetime2(3), [SizeMb] decimal(19,2), [StatusCode] varchar(40))
        ) OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
            WITH ([Area] varchar(40)) WHERE [Area] IN ('BACKUP_HISTORY','RESTORE_HISTORY')) <> 2
          OR EXISTS (SELECT 1 FROM OPENJSON(@Json)
            WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
            WHERE [Area] IN ('BACKUP_HISTORY','RESTORE_HISTORY') AND NULLIF([EvidenceLimit], N'') IS NULL)
            THROW 55167, N'Die nativen Counts, Zeitgrenzen oder Evidenzgrenzen sind verletzt.', 1;
        IF @Consumer = 2
        BEGIN
            EXEC [sys].[sp_executesql]
                N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
            IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                       EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55168, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                THROW 55169, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
        END;
        SELECT @After = (SELECT (SELECT * FROM [msdb].[dbo].[backupset] ORDER BY [backup_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupset],
        (SELECT * FROM [msdb].[dbo].[backupfile] ORDER BY [backup_set_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfile],
        (SELECT * FROM [msdb].[dbo].[backupfilegroup] ORDER BY [backup_set_id], [filegroup_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupfilegroup],
        (SELECT * FROM [msdb].[dbo].[backupmediaset] ORDER BY [media_set_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediaset],
        (SELECT * FROM [msdb].[dbo].[backupmediafamily] ORDER BY [media_set_id], [family_sequence_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [backupmediafamily],
        (SELECT * FROM [msdb].[dbo].[restorehistory] ORDER BY [restore_history_id] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorehistory],
        (SELECT * FROM [msdb].[dbo].[restorefile] ORDER BY [restore_history_id], [file_number] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefile],
        (SELECT * FROM [msdb].[dbo].[restorefilegroup] ORDER BY [restore_history_id], [filegroup_name] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [restorefilegroup] FOR JSON PATH, INCLUDE_NULL_VALUES, WITHOUT_ARRAY_WRAPPER);
        IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
           OR (@@OPTIONS & 16384) <> 16384
            THROW 55170, N'Der Analyzer hat Quellwerte oder den Callerzustand verändert.', 1;
        SET @Calls += 1;
        SET @Consumer += 1;
    END;
        ROLLBACK TRANSACTION;
        SET LOCK_TIMEOUT -1;
        SELECT @DbAfter = (SELECT [database_id], [name], [create_date], [collation_name], [state], [user_access],
            [recovery_model], [is_read_only] FROM [sys].[databases] WHERE [database_id] IN (@SourceId, @RestoreDbId)
            ORDER BY [database_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @DbBefore COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @DbAfter COLLATE SQL_Latin1_General_CP1_CS_AS) OR @@TRANCOUNT <> 0
            THROW 55178, N'Die eigenen Datenbankidentitäten, Optionen oder Callerbasis sind verändert.', 1;
        SET @Phase += 1;
    END;
    IF DB_ID(N'ExampleOps008Retention') <> @SourceId OR DB_ID(N'ExampleOps008RetentionRestore') <> @RestoreDbId
        THROW 55179, N'Die eigene Datenbankbindung für Cleanup fehlt.', 1;
    DROP DATABASE [ExampleOps008RetentionRestore];
    DROP DATABASE [ExampleOps008Retention];
    IF DB_ID(N'ExampleOps008Retention') IS NOT NULL OR DB_ID(N'ExampleOps008RetentionRestore') IS NOT NULL
        THROW 55180, N'Der eigene Datenbankcleanup ist unvollständig.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET LOCK_TIMEOUT -1;
    IF @PreviousXactAbort = 1 SET XACT_ABORT ON;
    ELSE SET XACT_ABORT OFF;
    /* Das äußere identitätsgebundene Labcleanup entfernt auch fehlgeschlagene eigene Fixtures. */
    THROW;
END CATCH;
SET LOCK_TIMEOUT -1;
IF @PreviousXactAbort = 1 SET XACT_ABORT ON;
ELSE SET XACT_ABORT OFF;
IF @Calls <> 9 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
   OR CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END <> @PreviousXactAbort
    THROW 55182, N'Die Consumerzahl oder die ursprünglichen Calleroptionen sind verletzt.', 1;
DROP TABLE [#Ops008Console];
DROP TABLE [#Ops008Native];
SELECT N'OPS008_BACKUP_RESTORE_RETENTION' AS [ContractName], 3 AS [ExecutedBackups], 3 AS [ExecutedRestores],
    3 AS [InitialPairs], 1 AS [RetainedPairs], 0 AS [FinalPairs], @Calls AS [ConsumerCalls],
    N'PASS' AS [Status], N'DATABASES_REMOVED' AS [FixtureCleanup];
GO
