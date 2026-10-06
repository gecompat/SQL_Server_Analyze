USE [DeineDatenbank];
GO
/* Prüft den databases-Export mit drei eigenen unverschlüsselten Datenbanken.
Die Fixture erzeugt weder Schlüssel noch Zertifikate, Backups oder Schutzfeatures.
Die explizite Backupverschlüsselungserwartung erzeugt vorhandene MEDIUM-Hinweise
auf fehlende Backupmetadaten. Positive TDE-, Zertifikat-, AE-/Ledger- und Restore-
Nachweise bleiben außerhalb dieses Vertrags. Der Runner verwendet Framework-Level
150, 160 und 170; alle drei Quellen werden explizit daran angepasst. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleEncryptionSourceÄ') IS NOT NULL THROW 56400,N'Encryption first fixture already exists.',1;
IF DB_ID(N'ExampleEncryptionSourceÖ') IS NOT NULL THROW 56401,N'Encryption second fixture already exists.',1;
IF DB_ID(N'ExampleEncryptionSourceÜ') IS NOT NULL THROW 56402,N'Encryption third fixture already exists.',1;
IF DB_ID(N'ExampleEncryptionMissingß') IS NOT NULL THROW 56403,N'Encryption missing selection fixture already exists.',1;
DECLARE @OwnedA int=NULL,@OwnedO int=NULL,@OwnedU int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @LevelA int,@LevelO int,@LevelU int,@Sql nvarchar(max),@DatabaseName nvarchar(128),
        @Case int=0,@Route int=0,@Mode varchar(16),@Limit int,@SafeLimit bigint,@Problems bit,@ExpectBackup bit,
        @Timeout int,@Transition int,@Expiry int,@Lookback int,@Invalid bit,@WarningName nvarchar(128),
        @Names nvarchar(max),@Pattern nvarchar(4000),@Json nvarchar(max),@Status varchar(40),@Partial bit,
        @ExpectedCount bigint;
IF @FrameworkLevel NOT IN(150,160,170) THROW 56404,N'Encryption framework compatibility level is outside the contract.',1;
IF @Major IS NULL OR @Major<15 THROW 56408,N'Encryption contract requires a visible SQL Server 2019 or newer version.',1;
BEGIN TRY
    CREATE DATABASE [ExampleEncryptionSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedA=DB_ID(N'ExampleEncryptionSourceÄ');
    CREATE DATABASE [ExampleEncryptionSourceÖ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedO=DB_ID(N'ExampleEncryptionSourceÖ');
    CREATE DATABASE [ExampleEncryptionSourceÜ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedU=DB_ID(N'ExampleEncryptionSourceÜ');
    SET @Sql=N'ALTER DATABASE [ExampleEncryptionSourceÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';
ALTER DATABASE [ExampleEncryptionSourceÖ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';
ALTER DATABASE [ExampleEncryptionSourceÜ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';';
    EXEC(@Sql);
    SELECT @LevelA=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedA;
    SELECT @LevelO=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedO;
    SELECT @LevelU=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedU;
    IF @LevelA<>@FrameworkLevel OR @LevelO<>@FrameworkLevel OR @LevelU<>@FrameworkLevel
       OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
       OR EXISTS(SELECT 1 FROM [sys].[databases] WHERE [database_id] IN(@OwnedA,@OwnedO,@OwnedU)
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS')
        THROW 56405,N'Encryption framework/source levels or source collations failed.',1;
    CREATE TABLE [#ExampleEncryptionNative]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEncrypted] bit NULL
        , [EncryptionState] int NULL
        , [EncryptionStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PercentComplete] real NULL
        , [EncryptionScanState] int NULL
        , [EncryptionScanStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EncryptionScanModifyDate] datetime NULL
        , [KeyAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KeyLength] int NULL
        , [EncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorExpiryDate] datetime NULL
        , [ProtectorPrivateKeyLastBackupDate] datetime NULL
        , [LatestFullBackupFinishDate] datetime NULL
        , [LatestFullBackupExplicitlyEncrypted] bit NULL
        , [LatestFullBackupAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LatestFullBackupEncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ColumnMasterKeyCount] bigint NULL
        , [ColumnEncryptionKeyCount] bigint NULL
        , [EncryptedColumnCount] bigint NULL
        , [LedgerTableCount] bigint NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    INSERT [#ExampleEncryptionNative]([DatabaseId],[DatabaseName],[IsEncrypted])
    SELECT [database_id],[name],[is_encrypted] FROM [sys].[databases] WHERE [database_id] IN(@OwnedA,@OwnedO,@OwnedU);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleEncryptionNative])<>3
       OR EXISTS(SELECT 1 FROM [#ExampleEncryptionNative] WHERE [IsEncrypted] IS NULL OR [IsEncrypted]<>0)
       OR EXISTS(SELECT 1 FROM [sys].[dm_database_encryption_keys] [k] JOIN [#ExampleEncryptionNative] [n] ON [n].[DatabaseId]=[k].[database_id])
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[backupset] [b] JOIN [#ExampleEncryptionNative] [n]
                  ON [n].[DatabaseName]=[b].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                  WHERE [b].[type]='D' AND [b].[is_copy_only]=0 AND [b].[backup_finish_date]>=DATEADD(DAY,-35,GETDATE()))
        THROW 56406,N'Encryption own native identities, unencrypted state, absent DEK or absent full-backup scope failed.',1;
    DECLARE [ExampleEncryptionNativeCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#ExampleEncryptionNative];
    OPEN [ExampleEncryptionNativeCursor]; FETCH NEXT FROM [ExampleEncryptionNativeCursor] INTO @DatabaseName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'UPDATE [n] SET
[ColumnMasterKeyCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[column_master_keys]),
[ColumnEncryptionKeyCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[column_encryption_keys]),
[EncryptedColumnCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[columns] WHERE [encryption_type] IS NOT NULL)'
        +CASE WHEN @Major>=16 THEN N', [LedgerTableCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[tables] WHERE [ledger_type]<>0)'
              ELSE N', [LedgerTableCount]=NULL' END+N'
FROM [#ExampleEncryptionNative] [n] WHERE [DatabaseName]=@pName;';
        EXEC [sys].[sp_executesql] @Sql,N'@pName nvarchar(128)',@pName=@DatabaseName;
        FETCH NEXT FROM [ExampleEncryptionNativeCursor] INTO @DatabaseName;
    END;
    CLOSE [ExampleEncryptionNativeCursor]; DEALLOCATE [ExampleEncryptionNativeCursor];
    IF EXISTS(SELECT 1 FROM [#ExampleEncryptionNative] WHERE [ColumnMasterKeyCount] IS NULL OR [ColumnMasterKeyCount]<>0
                  OR [ColumnEncryptionKeyCount] IS NULL OR [ColumnEncryptionKeyCount]<>0
                  OR [EncryptedColumnCount] IS NULL OR [EncryptedColumnCount]<>0
                  OR (@Major>=16 AND ([LedgerTableCount] IS NULL OR [LedgerTableCount]<>0))
                  OR (@Major<16 AND [LedgerTableCount] IS NOT NULL))
        THROW 56407,N'Encryption own native AE or Ledger scope is not empty.',1;
    SELECT TOP(0) * INTO [#ExampleEncryptionExpected] FROM [#ExampleEncryptionNative];
    CREATE TABLE [#ExampleEncryptionSources]
      ([SourceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
    INSERT [#ExampleEncryptionSources] VALUES
      (N'sys.dm_database_encryption_keys + master.sys.certificates','AVAILABLE',0),
      (N'msdb.dbo.backupset','AVAILABLE',0),
      (N'sys.column_master_keys + sys.column_encryption_keys + sys.columns + sys.tables','AVAILABLE',0);
    DECLARE @Parity TABLE([CheckName] nvarchar(32),[ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
    WHILE @Case<22
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN NULL WHEN @Case IN(2,19,21) THEN 1 WHEN @Case=11 THEN -1 ELSE 0 END,
               @SafeLimit=CASE WHEN @Case IN(2,19,21) THEN 1 WHEN @Case=11 THEN 0 ELSE CONVERT(bigint,9223372036854775807) END,
               @Problems=CASE WHEN @Case IN(3,5,20,21) THEN 1 ELSE 0 END,
               @ExpectBackup=CASE WHEN @Case IN(4,5,20) THEN 0 ELSE 1 END,
               @Names=CASE WHEN @Case=6 THEN N'[ExampleEncryptionSourceÖ]'
                           WHEN @Case IN(7,21) THEN N'[ExampleEncryptionSourceÄ]|[ExampleEncryptionSourceÖ]|[ExampleEncryptionSourceÜ]|[ExampleEncryptionMissingß]'
                           WHEN @Case=8 THEN N'[ExampleEncryptionMissingß]'
                           WHEN @Case=9 THEN N'[exampleEncryptionSourceÄ]'
                           WHEN @Case=10 THEN N'[ExampleEncryptionSourceÄ]|[exampleEncryptionSourceÖ]'
                           WHEN @Case=16 THEN N'[ExampleEncryptionSourceÄ]|[ExampleEncryptionSourceÄ]'
                           WHEN @Case=18 THEN N'['
                           WHEN @Case=19 THEN N'[ExampleEncryptionSourceÜ]|[ExampleEncryptionSourceÖ]|[ExampleEncryptionSourceÄ]'
                           WHEN @Case=20 THEN N'[ExampleEncryptionSourceÄ]|[ExampleEncryptionMissingß]'
                           ELSE N'[ExampleEncryptionSourceÄ]|[ExampleEncryptionSourceÖ]|[ExampleEncryptionSourceÜ]' END,
               @Pattern=CASE WHEN @Case=17 THEN N'like:ExampleEncryption%' ELSE NULL END,
               @Timeout=CASE WHEN @Case=12 THEN -1 ELSE 0 END,
               @Transition=CASE WHEN @Case=13 THEN 0 ELSE 60 END,
               @Expiry=CASE WHEN @Case=14 THEN 0 ELSE 90 END,
               @Lookback=CASE WHEN @Case=15 THEN 0 ELSE 35 END,
               @Invalid=CASE WHEN @Case BETWEEN 11 AND 18 THEN 1 ELSE 0 END,
               @WarningName=CASE WHEN @Case IN(7,8,20,21) THEN N'ExampleEncryptionMissingß'
                                 WHEN @Case=9 THEN N'exampleEncryptionSourceÄ' WHEN @Case=10 THEN N'exampleEncryptionSourceÖ' ELSE NULL END,
               @Json=NULL,@Status=NULL,@Partial=NULL;
        UPDATE [#ExampleEncryptionNative]
        SET [FindingCode]=CASE WHEN @ExpectBackup=1 THEN 'FULL_BACKUP_EVIDENCE_MISSING' ELSE 'DATABASE_NOT_TDE_ENCRYPTED' END,
            [FindingSeverity]=CASE WHEN @ExpectBackup=1 THEN 'MEDIUM' ELSE 'INFO' END,
            [EvidenceLimit]=CASE WHEN @ExpectBackup=1 THEN N'TDE und explizite Backupverschluesselung sind getrennte Schutzmechanismen; ein Test-Restore bleibt erforderlich.'
                                 ELSE N'Read-only Metadaten; Schluesselbesitz und Wiederherstellbarkeit werden nicht bewiesen.' END;
        TRUNCATE TABLE [#ExampleEncryptionExpected];
        INSERT [#ExampleEncryptionExpected]
        SELECT TOP(@SafeLimit) * FROM [#ExampleEncryptionNative]
        WHERE @Invalid=0 AND @Case NOT IN(8,9) AND (@Problems=0 OR @ExpectBackup=1)
          AND (@Case<>6 OR [DatabaseName]=N'ExampleEncryptionSourceÖ')
          AND (@Case NOT IN(10,20) OR [DatabaseName]=N'ExampleEncryptionSourceÄ')
        ORDER BY [DatabaseId];
        SELECT @ExpectedCount=COUNT_BIG(*) FROM [#ExampleEncryptionExpected];
        CREATE TABLE [#ExampleEncryptionExport]([Dummy] int NULL);
        EXEC [monitor].[USP_EncryptionAnalysis]
             @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@ExpliziteBackupverschluesselungErwartet=@ExpectBackup,
             @NurProblematisch=@Problems,@MaxZeilen=@Limit,@LockTimeoutMs=@Timeout,@TdeTransitionWarnMinutes=@Transition,
             @CertificateExpiryWarnDays=@Expiry,@BackupLookbackDays=@Lookback,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"databases":"#ExampleEncryptionExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(@Status,'')<>CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' WHEN @WarningName IS NOT NULL THEN 'AVAILABLE_LIMITED'
                                       WHEN @ExpectBackup=1 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Invalid=1 OR @WarningName IS NOT NULL THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Invalid=1 OR @WarningName IS NOT NULL THEN N'true' ELSE N'false' END
            THROW 56410,N'Encryption module or selection partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleEncryptionExport])<>@ExpectedCount
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databases'))<>@ExpectedCount
            THROW 56411,N'Encryption exact positive output/filter/limit count failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleEncryptionExport'))<>26
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleEncryptionExport') AND [collation_name] IS NOT NULL)<>11
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleEncryptionExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleEncryptionExport')
                     EXCEPT SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleEncryptionNative'))
            THROW 56412,N'Encryption 26-field export schema or eleven text collations failed.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          (N'NATIVE_EXPECTATIONS',(SELECT * FROM [#ExampleEncryptionExpected] FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [#ExampleEncryptionExport] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          (N'TABLE_JSON',(SELECT * FROM [#ExampleEncryptionExport] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.databases'));
        IF EXISTS
           (SELECT [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ExpectedJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ActualJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS
           (SELECT [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ActualJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ExpectedJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [p].[CheckName],[n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56413,N'Encryption native expectations or full 26-field TABLE/JSON multiset parity failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sources'))<>CASE WHEN @Invalid=1 THEN 0 ELSE 3 END
           OR (@Invalid=0 AND EXISTS(SELECT * FROM [#ExampleEncryptionSources] EXCEPT SELECT * FROM OPENJSON(@Json,N'$.sources') WITH
                ([SourceName] nvarchar(128) '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial')))
           OR (@Invalid=0 AND EXISTS(SELECT * FROM OPENJSON(@Json,N'$.sources') WITH
                ([SourceName] nvarchar(128) '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial') EXCEPT SELECT * FROM [#ExampleEncryptionSources]))
            THROW 56414,N'Encryption independent source identities or successful-source partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings'))<>CASE WHEN @WarningName IS NOT NULL THEN 1 ELSE 0 END
           OR (@WarningName IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH
                ([RequestedName] nvarchar(128) '$.RequestedName',[StatusCode] varchar(40) '$.StatusCode',[ErrorMessage] nvarchar(2048) '$.ErrorMessage')
                WHERE [RequestedName] COLLATE SQL_Latin1_General_CP1_CS_AS=@WarningName COLLATE SQL_Latin1_General_CP1_CS_AS
                  AND [StatusCode]='DATABASE_UNAVAILABLE' AND NULLIF([ErrorMessage],N'') IS NOT NULL))
            THROW 56415,N'Encryption Unicode/case selection warning failed.',1;
        DROP TABLE [#ExampleEncryptionExport];
        SET @Case+=1;
    END;
    /* RAW/CONSOLE werden positiv und mit negativem Limit aufgerufen. Deren native
       Zeilen werden hier nicht abgefangen; Status und JSON-Zeilenanzahl werden geprüft. */
    WHILE @Route<4
    BEGIN
        SELECT @Mode=CASE WHEN @Route IN(0,2) THEN 'RAW' ELSE 'CONSOLE' END,
               @Limit=CASE WHEN @Route<2 THEN 1 ELSE -1 END,@Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_EncryptionAnalysis] @DatabaseNames=N'[ExampleEncryptionSourceÄ]|[ExampleEncryptionSourceÖ]|[ExampleEncryptionSourceÜ]',
             @ExpliziteBackupverschluesselungErwartet=1,@NurProblematisch=1,@MaxZeilen=@Limit,@ResultSetArt=@Mode,
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>CASE WHEN @Route<2 THEN 'AVAILABLE_WITH_FINDING' ELSE 'INVALID_PARAMETER' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Route<2 THEN 0 ELSE 1 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databases'))<>CASE WHEN @Route<2 THEN 1 ELSE 0 END
            THROW 56416,N'Encryption RAW/CONSOLE status or JSON count failed.',1;
        SET @Route+=1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleEncryptionSourceÄ')=@OwnedA
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÄ];
    END;
    IF DB_ID(N'ExampleEncryptionSourceÖ')=@OwnedO
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÖ];
    END;
    IF DB_ID(N'ExampleEncryptionSourceÜ')=@OwnedU
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÜ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÜ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@LevelA AS [FirstSourceCompatibilityLevel],@LevelO AS [SecondSourceCompatibilityLevel],
           @LevelU AS [ThirdSourceCompatibilityLevel],@Case AS [TableJsonCases],@Route AS [RawConsoleStatusCases],
           N'Unverschlüsselte eigene Metadaten und Backup-Erwartung geprüft; positive Schutzfeatures und Restore bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','ExampleEncryptionNativeCursor')>=0 CLOSE [ExampleEncryptionNativeCursor];
    IF CURSOR_STATUS('local','ExampleEncryptionNativeCursor')>-3 DEALLOCATE [ExampleEncryptionNativeCursor];
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedA IS NOT NULL AND DB_ID(N'ExampleEncryptionSourceÄ')=@OwnedA
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÄ];
    END;
    IF @OwnedO IS NOT NULL AND DB_ID(N'ExampleEncryptionSourceÖ')=@OwnedO
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÖ];
    END;
    IF @OwnedU IS NOT NULL AND DB_ID(N'ExampleEncryptionSourceÜ')=@OwnedU
    BEGIN
        ALTER DATABASE [ExampleEncryptionSourceÜ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleEncryptionSourceÜ];
    END;
    THROW;
END CATCH;
GO
