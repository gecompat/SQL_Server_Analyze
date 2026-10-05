USE [DeineDatenbank];
GO
/*
Prüft im neu erzeugten lokalen Testcontainer zwei eigene synthetische
Datenbanken und drei native Backupsets. Das erste Full verwendet bewusst
NO_CHECKSUM; ein zweites Full und sein Differential verwenden CHECKSUM.
Backupgeräte bleiben nur im Speicher. Eigene Datenbanken und deren Historie
werden entfernt; die Dateien verbleiben bis zum eigenen Containercleanup.
Der Vertrag führt keinen Restore aus und belegt keine Wiederherstellbarkeit.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Good sysname=N'ExampleBackupChainÄ',@Empty sysname=N'ExampleBackupChainÜ',
        @GoodCreated bit=0,@EmptyCreated bit=0,@GoodId int,@EmptyId int,@Sql nvarchar(max),
        @Folder nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath')),
        @Device nvarchar(4000),@Token nvarchar(36)=CONVERT(nvarchar(36),NEWID()),@Names nvarchar(max),
        @Case tinyint=0,@Limit int,@Restore bit,@Rows bigint,@BackupRows bigint,@Json nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
IF DB_ID(@Good) IS NOT NULL OR DB_ID(@Empty) IS NOT NULL OR @Folder IS NULL
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[backupset] WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[restorehistory] WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Good,@Empty))
    THROW 55920,N'Die eigenen Backupketten-Fixtures oder ihr Backupverzeichnis sind nicht frei.',1;
SET @Names=QUOTENAME(@Good)+N'|'+QUOTENAME(@Empty);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Good)+N' COLLATE Latin1_General_100_CS_AS;'; EXEC(@Sql);
    SELECT @GoodCreated=1,@GoodId=DB_ID(@Good);
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Good)+N' SET RECOVERY SIMPLE WITH NO_WAIT;'; EXEC(@Sql);
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Empty)+N' COLLATE Latin1_General_100_CS_AS;'; EXEC(@Sql);
    SELECT @EmptyCreated=1,@EmptyId=DB_ID(@Empty);
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Empty)+N' SET RECOVERY SIMPLE WITH NO_WAIT;'; EXEC(@Sql);
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleBackupChain_'+@Token+N'_first.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH INIT,NO_CHECKSUM;
    SET @Sql=N'CREATE TABLE '+QUOTENAME(@Good)+N'.[dbo].[ExampleBackupRows]([Id] int NOT NULL); INSERT '+QUOTENAME(@Good)+N'.[dbo].[ExampleBackupRows] VALUES(1);'; EXEC(@Sql);
    WAITFOR DELAY '00:00:00.250';
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleBackupChain_'+@Token+N'_second.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH INIT,CHECKSUM;
    SET @Sql=N'INSERT '+QUOTENAME(@Good)+N'.[dbo].[ExampleBackupRows] VALUES(2);'; EXEC(@Sql);
    WAITFOR DELAY '00:00:00.250';
    SET @Device=@Folder+CASE WHEN RIGHT(@Folder,1) IN(N'/',N'\') THEN N'' ELSE N'/' END+N'ExampleBackupChain_'+@Token+N'_diff.bak';
    BACKUP DATABASE @Good TO DISK=@Device WITH DIFFERENTIAL,INIT,CHECKSUM;
    SELECT [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [DatabaseName],[backup_set_id] AS [BackupSetId],
      [type] COLLATE SQL_Latin1_General_CP1_CS_AS AS [BackupType],
      CONVERT(nvarchar(40),CASE [type] WHEN 'D' THEN N'FULL' ELSE N'DIFFERENTIAL' END) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BackupTypeDesc],
      [backup_start_date] AS [BackupStartDate],[backup_finish_date] AS [BackupFinishDate],
      [first_lsn] AS [FirstLsn],[last_lsn] AS [LastLsn],[checkpoint_lsn] AS [CheckpointLsn],
      [database_backup_lsn] AS [DatabaseBackupLsn],[differential_base_lsn] AS [DifferentialBaseLsn],
      [first_recovery_fork_guid] AS [FirstRecoveryForkGuid],[last_recovery_fork_guid] AS [LastRecoveryForkGuid],
      [is_copy_only] AS [IsCopyOnly],[has_backup_checksums] AS [HasBackupChecksums],[is_damaged] AS [IsDamaged],
      CONVERT(bit,CASE WHEN [key_algorithm] IS NULL THEN 0 ELSE 1 END) AS [IsEncrypted],
      CONVERT(numeric(25,0),NULL) AS [PreviousLogLastLsn],CONVERT(bit,0) AS [LogGapDetected]
    INTO [#ExampleBackupChainNative] FROM [msdb].[dbo].[backupset]
    WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Good;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleBackupChainNative])<>3
       OR (SELECT COUNT_BIG(*) FROM [#ExampleBackupChainNative] WHERE [BackupType]='D')<>2
       OR (SELECT COUNT_BIG(*) FROM [#ExampleBackupChainNative] WHERE [HasBackupChecksums]=0)<>1
       OR EXISTS(SELECT 1 FROM [#ExampleBackupChainNative] WHERE COALESCE([IsCopyOnly],1)<>0 OR COALESCE([IsDamaged],1)<>0 OR [IsEncrypted]<>0 OR [HasBackupChecksums] IS NULL)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleBackupChainNative] AS [d]
           CROSS APPLY(SELECT TOP(1) [CheckpointLsn] FROM [#ExampleBackupChainNative] WHERE [BackupType]='D'
             ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC) AS [f]
           WHERE [d].[BackupType]='I' AND [d].[DifferentialBaseLsn]=[f].[CheckpointLsn])
        THROW 55920,N'Die drei eigenen nativen Backupsets oder ihre Differentialbasis stimmen nicht.',1;
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
          @Restore=CASE WHEN @Case<2 THEN 1 ELSE 0 END,@Rows=CASE WHEN @Case=1 THEN 1 ELSE 2 END,
          @BackupRows=CASE WHEN @Case=1 THEN 1 ELSE 3 END;
        CREATE TABLE [#ExampleBackupChainSummary]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
        EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=@Names,@HistoryDays=1,@MitRestoreEvidence=@Restore,
          @MaxZeilen=@Limit,@ResultSetArt='TABLE',@ResultTablesJson=N'{"summary":"#ExampleBackupChainSummary"}',
          @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
          @IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBackupChainSummary') AND [collation_name] IS NOT NULL)<>5
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBackupChainSummary')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55921,N'Der Backupkettenexport übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR @Error IS NOT NULL OR @Message IS NOT NULL OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleBackupChainSummary])<>@Rows
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.backups'))<>@BackupRows
            THROW 55922,N'Der native Backupkettenstatus- oder Limitvertrag ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          ((SELECT * FROM [#ExampleBackupChainSummary] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.summary')),
          ((SELECT TOP(@Rows) [d].[database_id] AS [DatabaseId],[d].[name] AS [DatabaseName],[d].[recovery_model_desc] AS [RecoveryModelDesc],
              [f].[BackupFinishDate] AS [LatestFullFinish],[i].[BackupFinishDate] AS [LatestMatchingDifferentialFinish],
              CONVERT(datetime,NULL) AS [LatestLogFinish],CONVERT(bigint,0) AS [LogBackupCountInWindow],
              CONVERT(bigint,0) AS [LogGapCountInWindow],CONVERT(bigint,0) AS [RecoveryForkTransitionCount],
              CONVERT(bigint,0) AS [DamagedBackupCount],
              (SELECT COUNT_BIG(*) FROM [#ExampleBackupChainNative] AS [b] WHERE [b].[DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [HasBackupChecksums]=0) AS [BackupWithoutChecksumCount],
              CONVERT(datetime,NULL) AS [LatestRestoreDate],
              CASE WHEN [f].[BackupFinishDate] IS NULL THEN 'FULL_BACKUP_EVIDENCE_MISSING' ELSE 'BACKUP_WITHOUT_CHECKSUM_IN_VISIBLE_HISTORY' END AS [FindingCode],
              CASE WHEN [f].[BackupFinishDate] IS NULL THEN 'HIGH' ELSE 'MEDIUM' END AS [FindingSeverity],
              N'msdb-Sichtfenster 1 Tage; bereinigte Historie kann scheinbare Lücken erzeugen. Test-Restore bleibt erforderlich.' AS [EvidenceLimit]
            FROM [sys].[databases] AS [d]
            OUTER APPLY(SELECT TOP(1) * FROM [#ExampleBackupChainNative] AS [b] WHERE [b].[DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [BackupType]='D'
              ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC) AS [f]
            OUTER APPLY(SELECT TOP(1) * FROM [#ExampleBackupChainNative] AS [b] WHERE [b].[DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [BackupType]='I'
              AND [DifferentialBaseLsn]=[f].[CheckpointLsn] ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC) AS [i]
            WHERE [d].[database_id] IN(@GoodId,@EmptyId) ORDER BY [d].[database_id] FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT * FROM [#ExampleBackupChainSummary] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT TOP(@BackupRows) * FROM [#ExampleBackupChainNative] ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.backups'));
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
            THROW 55923,N'Die native Backupketten- oder TABLE-/JSON-Multimengenparität fehlt.',1;
        DROP TABLE [#ExampleBackupChainSummary];
        SET @Case+=1;
    END;
    DROP TABLE [#ExampleBackupChainNative];
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
    THROW 55924,N'Die eigenen Backupketten-Fixtures oder ihre Historie wurden nicht entfernt.',1;
GO
