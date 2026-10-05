USE [DeineDatenbank];
GO
/*
Dieser Vertrag erzeugt ausschließlich im neuen eigenen lokalen Testcontainer
zwei synthetische Datenbanken und drei Backupsets: Full, Differential und
Copy-only Full. Er entfernt eigene Datenbanken und msdb-Historie; die eigenen
Backupdateien werden beim Containercleanup entfernt. Ein Restore findet nicht statt.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Good sysname=N'ExampleRecoveryÄ',@Empty sysname=N'ExampleRecoveryÜ',
        @GoodCreated bit=0,@EmptyCreated bit=0,@GoodId int,@EmptyId int,@Sql nvarchar(max),
        @Folder nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath')),
        @Device nvarchar(4000),@Token nvarchar(36)=CONVERT(nvarchar(36),NEWID()),@Names nvarchar(max),
        @Case tinyint=0,@Limit int,@Restore bit,@Rows bigint,@BackupRows bigint,@Json nvarchar(max),
        @Before datetime,@After datetime;
IF DB_ID(@Good) IS NOT NULL OR DB_ID(@Empty) IS NOT NULL OR @Folder IS NULL
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[backupset] WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[restorehistory] WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
    THROW 55950,N'Die eigenen Backup-Recovery-Fixtures oder ihr Backupverzeichnis sind nicht frei.',1;
SET @Names=QUOTENAME(@Good)+N'|'+QUOTENAME(@Empty);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Good)+N' COLLATE Latin1_General_100_CS_AS;'; EXEC(@Sql);
    SELECT @GoodCreated=1,@GoodId=DB_ID(@Good);
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Good)+N' SET RECOVERY SIMPLE WITH NO_WAIT;'; EXEC(@Sql);
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Empty)+N' COLLATE Latin1_General_100_CS_AS;'; EXEC(@Sql);
    SELECT @EmptyCreated=1,@EmptyId=DB_ID(@Empty);
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Empty)+N' SET RECOVERY SIMPLE WITH NO_WAIT;'; EXEC(@Sql);
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleRecovery_'+@Token+N'_full.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH INIT,CHECKSUM;
    SET @Sql=N'CREATE TABLE '+QUOTENAME(@Good)+N'.[dbo].[ExampleRecoveryRows]([Id] int NOT NULL); INSERT '+QUOTENAME(@Good)+N'.[dbo].[ExampleRecoveryRows] VALUES(1);'; EXEC(@Sql);
    WAITFOR DELAY '00:00:01.000';
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleRecovery_'+@Token+N'_diff.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH DIFFERENTIAL,INIT,CHECKSUM;
    WAITFOR DELAY '00:00:01.000';
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleRecovery_'+@Token+N'_copy.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH COPY_ONLY,INIT,CHECKSUM;
    SELECT [bs].[backup_set_id] AS [BackupSetId],[bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [DatabaseName],
       [bs].[type] COLLATE SQL_Latin1_General_CP1_CS_AS AS [BackupType],
       CONVERT(nvarchar(60),CASE [bs].[type] WHEN 'D' THEN N'DATABASE' ELSE N'DIFFERENTIAL' END)
           COLLATE SQL_Latin1_General_CP1_CS_AS AS [BackupTypeDesc],
       [bs].[backup_start_date] AS [BackupStartDate],[bs].[backup_finish_date] AS [BackupFinishDate],
       DATEDIFF(SECOND,[bs].[backup_start_date],[bs].[backup_finish_date]) AS [DurationSeconds],
       CONVERT(decimal(19,2),[bs].[backup_size]/1048576.0) AS [BackupSizeMb],
       CONVERT(decimal(19,2),[bs].[compressed_backup_size]/1048576.0) AS [CompressedSizeMb],
       [bs].[is_copy_only] AS [IsCopyOnly],CONVERT(bit,NULL) AS [IsSnapshot],
       [bs].[has_backup_checksums] AS [HasBackupChecksums],[bs].[is_damaged] AS [IsDamaged],
       CONVERT(nvarchar(4000),[m].[physical_device_name]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [MediaPath]
    INTO [#ExampleRecoveryNativeBackups] FROM [msdb].[dbo].[backupset] AS [bs]
    LEFT JOIN [msdb].[dbo].[backupmediafamily] AS [m] ON [m].[media_set_id]=[bs].[media_set_id]
    WHERE [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Good;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryNativeBackups])<>3
       OR (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryNativeBackups] WHERE [BackupType]='D' AND [IsCopyOnly]=0)<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryNativeBackups] WHERE [BackupType]='D' AND [IsCopyOnly]=1)<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryNativeBackups] WHERE [BackupType]='I')<>1
       OR EXISTS(SELECT 1 FROM [#ExampleRecoveryNativeBackups]
          WHERE COALESCE([HasBackupChecksums],0)<>1 OR COALESCE([IsDamaged],1)<>0 OR [MediaPath] IS NULL)
        THROW 55950,N'Die drei eigenen nativen Backupsets sind nicht vorhanden.',1;
    SELECT [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [DatabaseName],
       [d].[state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [StateDesc],
       [d].[recovery_model_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [RecoveryModelDesc],
       (SELECT MAX([BackupFinishDate]) FROM [#ExampleRecoveryNativeBackups] WHERE [IsCopyOnly]=0 AND [BackupType]='D'
          AND [DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AS [LastFullFinish],
       (SELECT MAX([BackupFinishDate]) FROM [#ExampleRecoveryNativeBackups] WHERE [BackupType]='I'
          AND [DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AS [LastDiffFinish],
       CONVERT(datetime,NULL) AS [LastLogFinish],
       (SELECT MAX([BackupFinishDate]) FROM [#ExampleRecoveryNativeBackups] WHERE [IsCopyOnly]=1 AND [BackupType]='D'
          AND [DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS) AS [LastCopyOnlyFullFinish],
       CONVERT(varchar(100),CASE WHEN [d].[database_id]=@GoodId THEN 'OK' ELSE 'NO_FULL_BACKUP' END)
          COLLATE SQL_Latin1_General_CP1_CS_AS AS [BackupStatus]
    INTO [#ExampleRecoveryNativeFresh] FROM [sys].[databases] AS [d] WHERE [d].[database_id] IN(@GoodId,@EmptyId);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryNativeFresh])<>2
       OR NOT EXISTS(SELECT 1 FROM [#ExampleRecoveryNativeFresh] WHERE [DatabaseName]=@Good
          AND [LastFullFinish] IS NOT NULL AND [LastDiffFinish] IS NOT NULL
          AND [LastCopyOnlyFullFinish]>[LastFullFinish] AND [RecoveryModelDesc]=N'SIMPLE' AND [StateDesc]=N'ONLINE')
        THROW 55950,N'Die native Full-/Copy-only-Trennung fehlt.',1;
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
          @Restore=CASE WHEN @Case<2 THEN 1 ELSE 0 END,@Rows=CASE WHEN @Case=1 THEN 1 ELSE 2 END,
          @BackupRows=CASE WHEN @Case=1 THEN 1 ELSE 3 END,@Json=NULL,@Before=GETDATE();
        CREATE TABLE [#ExampleRecoveryFresh]([Dummy] int NULL);
        EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=@Names,@MitRestoreHistory=@Restore,@MaxZeilen=@Limit,
          @ResultSetArt='TABLE',@ResultTablesJson=N'{"freshness":"#ExampleRecoveryFresh"}',
          @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SET @After=GETDATE();
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleRecoveryFresh') AND [collation_name] IS NOT NULL)<>4
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleRecoveryFresh')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55951,N'Der Backup-Recovery-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL OR JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]' OR COALESCE(JSON_QUERY(@Json,N'$.restores'),N'')<>N'[]'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleRecoveryFresh])<>@Rows
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.backups'))<>@BackupRows
           OR (@Limit=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleRecoveryFresh] WHERE [DatabaseName]=@Empty AND [BackupStatus]='NO_FULL_BACKUP'))
            THROW 55952,N'Der native Backup-Recovery-Status- oder Limitvertrag ist verletzt.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleRecoveryFresh]
           WHERE ([LastFullFinish] IS NULL AND [FullAgeMinutes] IS NOT NULL)
              OR ([LastFullFinish] IS NOT NULL AND ([FullAgeMinutes] IS NULL OR [FullAgeMinutes] NOT BETWEEN DATEDIFF(MINUTE,[LastFullFinish],@Before) AND DATEDIFF(MINUTE,[LastFullFinish],@After)))
              OR ([LastDiffFinish] IS NULL AND [DiffAgeMinutes] IS NOT NULL)
              OR ([LastDiffFinish] IS NOT NULL AND ([DiffAgeMinutes] IS NULL OR [DiffAgeMinutes] NOT BETWEEN DATEDIFF(MINUTE,[LastDiffFinish],@Before) AND DATEDIFF(MINUTE,[LastDiffFinish],@After)))
              OR [LastLogFinish] IS NOT NULL OR [LogAgeMinutes] IS NOT NULL)
            THROW 55953,N'Das native Backupalter oder die SIMPLE-Loggrenze ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          ((SELECT * FROM [#ExampleRecoveryFresh] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.freshness')),
          ((SELECT TOP(@Rows) * FROM [#ExampleRecoveryNativeFresh]
              ORDER BY CASE WHEN [BackupStatus]='OK' THEN 1 ELSE 0 END,[DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT [DatabaseName],[StateDesc],[RecoveryModelDesc],[LastFullFinish],[LastDiffFinish],
              [LastLogFinish],[LastCopyOnlyFullFinish],[BackupStatus] FROM [#ExampleRecoveryFresh] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT TOP(@BackupRows) [DatabaseName],[BackupType],[BackupTypeDesc],[BackupStartDate],[BackupFinishDate],
              [DurationSeconds],[BackupSizeMb],[CompressedSizeMb],[IsCopyOnly],[IsSnapshot],[HasBackupChecksums],[IsDamaged],[MediaPath]
            FROM [#ExampleRecoveryNativeBackups] ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),
           JSON_QUERY(@Json,N'$.backups'));
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE LEFT(COALESCE([p].[ActualJson],N''),1)<>N'['
           OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]))
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
            THROW 55954,N'Die native Backup-Recovery- oder TABLE-/JSON-Multimengenparität fehlt.',1;
        DROP TABLE [#ExampleRecoveryFresh];
        SET @Case+=1;
    END;
    DROP TABLE [#ExampleRecoveryNativeFresh]; DROP TABLE [#ExampleRecoveryNativeBackups];
END TRY
BEGIN CATCH
    IF @EmptyCreated=1 AND DB_ID(@Empty)=@EmptyId BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@Empty)+N';'; EXEC(@Sql);
        EXEC [msdb].[dbo].[sp_delete_database_backuphistory] @database_name=@Empty;
    END;
    IF @GoodCreated=1 AND DB_ID(@Good)=@GoodId BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@Good)+N';'; EXEC(@Sql);
        EXEC [msdb].[dbo].[sp_delete_database_backuphistory] @database_name=@Good;
    END;
    THROW;
END CATCH;
IF @EmptyCreated=1 AND DB_ID(@Empty)=@EmptyId BEGIN
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@Empty)+N';'; EXEC(@Sql);
    EXEC [msdb].[dbo].[sp_delete_database_backuphistory] @database_name=@Empty;
END;
IF @GoodCreated=1 AND DB_ID(@Good)=@GoodId BEGIN
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@Good)+N';'; EXEC(@Sql);
    EXEC [msdb].[dbo].[sp_delete_database_backuphistory] @database_name=@Good;
END;
IF DB_ID(@Good) IS NOT NULL OR DB_ID(@Empty) IS NOT NULL
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[backupset] WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[restorehistory] WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
    THROW 55955,N'Die eigenen Backup-Recovery-Fixtures oder ihre Historie wurden nicht entfernt.',1;
GO
