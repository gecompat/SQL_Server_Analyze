USE [DeineDatenbank];
GO
/* Prüft eigene leere Unicode-Datenbanken und die bestehenden Maintenance-Ausgaben.
   TABLE bleibt auf resumableOperations begrenzt. Dessen leere Menge belegt Schema
   und Collation, keine positive Resumable-Filter-/Limitwirkung. Nichtleere PVS-
   Metadaten werden unabhängig nativ gegengeprüft. Zwei eigene leere Quellen
   aktivieren ADR ohne DML; Schwellwert 0 erzeugt vorhandene MEDIUM-Hinweise
   ohne Hochlastbehauptung. Interne ADR-Metadaten können auch ohne Nutzdaten
   eine nichtnegative PVS-Größe erzeugen. Native Messungen vor und unmittelbar
   nach dem TABLE-Aufruf begrenzen diesen variablen Wert; die übrigen acht PVS-
   Felder werden exakt verglichen. Operative Wartung bleibt aus.
   RAW/CONSOLE werden nur auf Status und begleitende JSON-Mengen geprüft.
   Die Sourcelevels folgen dem Frameworklevel 150/160/170. SQL Server 2019
   meldet vor der Fixture ausdrücklich UNAVAILABLE_VERSION/NOT_EXECUTED. */
SET NOCOUNT ON;
DECLARE @OwnedA int=NULL,@OwnedO int=NULL,@OwnedU int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @LevelA int,@LevelO int,@LevelU int,@Sql nvarchar(max),@Case int=0,@Route int=0,
        @Names nvarchar(max),@Pattern nvarchar(4000),@Jobs nvarchar(max),@JobPattern nvarchar(4000),
        @Limit int,@SafeLimit bigint,@Problems bit,@LowThreshold bit,@Timeout int,@Paused int,
        @Blocked bigint,@Pvs decimal(19,2),@Aborted bigint,@Invalid bit,@Unavailable bit,
        @WarningName nvarchar(128),@Json nvarchar(max),@Status varchar(40),@Partial bit,@Mode varchar(16),
        @ExpectedCount bigint,@ExpectedStatus varchar(40),@DatabaseName nvarchar(128);
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 56504,N'Maintenance framework level is outside the contract.',1;
IF @Major IS NULL OR @Major<15 THROW 56505,N'Maintenance contract requires SQL Server 2019 or newer.',1;
/* Der vorhandene Produktvertrag liefert vor SQL Server 2022 keinen PVS-Detailpfad.
   Dieser Harness überspringt die Fixture vollständig und meldet keinen positiven Fall. */
IF @Major<16
BEGIN
    SELECT CAST('UNAVAILABLE_VERSION' AS varchar(40)) AS [StatusCode],CAST(1 AS bit) AS [IsPartial],
           CAST('NOT_EXECUTED' AS varchar(40)) AS [ExecutionState],@Major AS [ProductMajorVersion],
           @FrameworkLevel AS [FrameworkCompatibilityLevel],0 AS [TableJsonCases],0 AS [RawConsoleStatusCases],
           N'Der PVS-Detailvertrag beginnt mit SQL Server 2022; keine Fixture oder positive Runtimeprüfung ausgeführt.' AS [Detail];
    RETURN;
END;
IF DB_ID(N'ExampleMaintenanceSourceÄ') IS NOT NULL THROW 56500,N'Maintenance first fixture already exists.',1;
IF DB_ID(N'ExampleMaintenanceSourceÖ') IS NOT NULL THROW 56501,N'Maintenance second fixture already exists.',1;
IF DB_ID(N'ExampleMaintenanceSourceÜ') IS NOT NULL THROW 56502,N'Maintenance third fixture already exists.',1;
IF DB_ID(N'ExampleMaintenanceMissingß') IS NOT NULL THROW 56503,N'Maintenance missing fixture already exists.',1;
BEGIN TRY
    /* Die erste Identität bleibt ADR-OFF, damit Limit 1 vor den MEDIUM-Zeilen INFO wählt. */
    CREATE DATABASE [ExampleMaintenanceSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedA=DB_ID(N'ExampleMaintenanceSourceÄ');
    CREATE DATABASE [ExampleMaintenanceSourceÖ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedO=DB_ID(N'ExampleMaintenanceSourceÖ');
    CREATE DATABASE [ExampleMaintenanceSourceÜ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedU=DB_ID(N'ExampleMaintenanceSourceÜ');
    ALTER DATABASE [ExampleMaintenanceSourceÄ] SET ACCELERATED_DATABASE_RECOVERY=OFF;
    ALTER DATABASE [ExampleMaintenanceSourceÖ] SET ACCELERATED_DATABASE_RECOVERY=ON;
    ALTER DATABASE [ExampleMaintenanceSourceÜ] SET ACCELERATED_DATABASE_RECOVERY=ON;
    SET @Sql=N'ALTER DATABASE [ExampleMaintenanceSourceÄ] SET COMPATIBILITY_LEVEL='+CONVERT(nvarchar(3),@FrameworkLevel)+N';
ALTER DATABASE [ExampleMaintenanceSourceÖ] SET COMPATIBILITY_LEVEL='+CONVERT(nvarchar(3),@FrameworkLevel)+N';
ALTER DATABASE [ExampleMaintenanceSourceÜ] SET COMPATIBILITY_LEVEL='+CONVERT(nvarchar(3),@FrameworkLevel)+N';';
    EXEC(@Sql);
    SELECT @LevelA=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedA;
    SELECT @LevelO=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedO;
    SELECT @LevelU=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedU;
    IF @LevelA<>@FrameworkLevel OR @LevelO<>@FrameworkLevel OR @LevelU<>@FrameworkLevel
       OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
       OR EXISTS(SELECT 1 FROM [sys].[databases] WHERE [database_id] IN(@OwnedA,@OwnedO,@OwnedU)
                 AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS')
        THROW 56506,N'Maintenance separately checked framework/source levels or source collations failed.',1;
    CREATE TABLE [#ExampleMaintenanceNativePvs]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AdrEnabled] bit NOT NULL
        , [PvsSizeMb] decimal(19,2) NULL
        , [OnlineIndexPvsSizeMb] decimal(19,2) NULL
        , [CurrentAbortedTransactionCount] bigint NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    INSERT [#ExampleMaintenanceNativePvs]
    SELECT [d].[database_id],[d].[name],[d].[is_accelerated_database_recovery_on],
           CONVERT(decimal(19,2),[s].[persistent_version_store_size_kb]/1024.0),
           CONVERT(decimal(19,2),[s].[online_index_version_store_size_kb]/1024.0),[s].[current_aborted_transaction_count],
           'ADR_NOT_ENABLED','INFO',N'ADR/PVS-Zaehler sind Zeitpunktwerte und beweisen allein keine Bereinigungsstoerung.'
    FROM [sys].[databases] [d] LEFT JOIN [sys].[dm_tran_persistent_version_store_stats] [s]
      ON [s].[database_id]=[d].[database_id] WHERE [d].[database_id] IN(@OwnedA,@OwnedO,@OwnedU);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleMaintenanceNativePvs])<>3 OR NOT(@OwnedA<@OwnedO AND @OwnedO<@OwnedU)
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs]
                 WHERE ([DatabaseId]=@OwnedA AND [AdrEnabled]<>0) OR ([DatabaseId] IN(@OwnedO,@OwnedU) AND [AdrEnabled]<>1))
       OR (SELECT COUNT_BIG(*) FROM [sys].[dm_tran_persistent_version_store_stats] WHERE [database_id] IN(@OwnedO,@OwnedU))<>2
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs] WHERE [DatabaseId] IN(@OwnedO,@OwnedU)
                 AND ([PvsSizeMb] IS NULL OR [PvsSizeMb]<0 OR [PvsSizeMb]>=1024 OR [OnlineIndexPvsSizeMb] IS NULL OR [OnlineIndexPvsSizeMb]<>0
                      OR [CurrentAbortedTransactionCount] IS NULL OR [CurrentAbortedTransactionCount]<>0))
        THROW 56507,N'Maintenance native identities, ADR flags or actual PVS counters failed.',1;
    /* Eigene leere Kataloge liefern bewusst keine positive resumierbare Operation. */
    DECLARE [ExampleMaintenanceNativeCursor] CURSOR LOCAL FAST_FORWARD FOR
      SELECT [DatabaseName] FROM [#ExampleMaintenanceNativePvs];
    OPEN [ExampleMaintenanceNativeCursor]; FETCH NEXT FROM [ExampleMaintenanceNativeCursor] INTO @DatabaseName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[index_resumable_operations])
THROW 56508,N''Maintenance own resumable scope is not empty.'',1;'; EXEC(@Sql);
        FETCH NEXT FROM [ExampleMaintenanceNativeCursor] INTO @DatabaseName;
    END;
    CLOSE [ExampleMaintenanceNativeCursor]; DEALLOCATE [ExampleMaintenanceNativeCursor];
    IF EXISTS(SELECT 1 FROM [sys].[dm_exec_requests] WHERE [session_id]<>@@SPID
              AND ([database_id] IN(@OwnedA,@OwnedO,@OwnedU) OR [database_id] IS NULL)
              AND ([command] LIKE N'ALTER INDEX%' OR [command] LIKE N'DBCC%' OR [command] LIKE N'BACKUP%'
                   OR [command] LIKE N'RESTORE%' OR [command] LIKE N'ROLLBACK%'))
        THROW 56509,N'Maintenance technical request scope is not empty.',1;
    CREATE TABLE [#ExampleMaintenanceResumableSchema]
    (
          [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PartitionNumber] int NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StartTime] datetime NULL,[LastPauseTime] datetime NULL
        , [TotalExecutionTimeMinutes] bigint NULL,[PercentComplete] real NULL,[PageCount] bigint NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    SELECT TOP(0) * INTO [#ExampleMaintenanceExpectedPvs] FROM [#ExampleMaintenanceNativePvs];
    SELECT TOP(0) [DatabaseId],[DatabaseName],[AdrEnabled],[PvsSizeMb],[OnlineIndexPvsSizeMb],[CurrentAbortedTransactionCount]
    INTO [#ExampleMaintenanceAfterPvs] FROM [#ExampleMaintenanceNativePvs];
    CREATE TABLE [#ExampleMaintenanceSources]
      ([SourceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
    INSERT [#ExampleMaintenanceSources] VALUES
      (N'sys.index_resumable_operations','AVAILABLE',0),(N'sys.dm_exec_requests','AVAILABLE',0),
      (N'sys.dm_tran_persistent_version_store_stats','AVAILABLE',0),
      (N'msdb.dbo.sysjobs + msdb.dbo.sysjobactivity','NOT_REQUESTED',0);
    DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
    WHILE @Case<24
    BEGIN
        SELECT @Limit=CASE WHEN @Case=0 THEN NULL WHEN @Case IN(2,5,20) THEN 1 WHEN @Case=11 THEN -1 ELSE 0 END,
               @SafeLimit=CASE WHEN @Case IN(2,5,20) THEN 1 WHEN @Case=11 THEN 0 ELSE CONVERT(bigint,9223372036854775807) END,
               @Problems=CASE WHEN @Case IN(3,4,5,21) THEN 1 ELSE 0 END,
               @LowThreshold=CASE WHEN @Case IN(4,5,6,7,8,9,10,20,21) THEN 1 ELSE 0 END,
               @Names=CASE WHEN @Case=7 THEN N'[ExampleMaintenanceSourceÖ]'
                           WHEN @Case=8 THEN N'[exampleMaintenanceSourceÖ]'
                           WHEN @Case IN(9,21) THEN N'[ExampleMaintenanceSourceÄ]|[ExampleMaintenanceSourceÖ]|[ExampleMaintenanceSourceÜ]|[ExampleMaintenanceMissingß]'
                           WHEN @Case=10 THEN N'[ExampleMaintenanceMissingß]'
                           WHEN @Case=17 THEN N'[ExampleMaintenanceSourceÄ]|[ExampleMaintenanceSourceÄ]'
                           WHEN @Case=19 THEN N'['
                           WHEN @Case=20 THEN N'[ExampleMaintenanceSourceÜ]|[ExampleMaintenanceSourceÖ]|[ExampleMaintenanceSourceÄ]'
                           ELSE N'[ExampleMaintenanceSourceÄ]|[ExampleMaintenanceSourceÖ]|[ExampleMaintenanceSourceÜ]' END,
               @Pattern=CASE WHEN @Case=18 THEN N'like:ExampleMaintenance%' ELSE NULL END,
               @Jobs=CASE WHEN @Case=23 THEN N'ExampleMaintenanceUncreatedJob' ELSE NULL END,
               @JobPattern=CASE WHEN @Case=22 THEN N'regex:ExampleMaintenance' WHEN @Case=23 THEN N'like:ExampleMaintenance%' ELSE NULL END,
               @Timeout=CASE WHEN @Case=12 THEN -1 ELSE 0 END,@Paused=CASE WHEN @Case=13 THEN 0 ELSE 60 END,
               @Blocked=CASE WHEN @Case=14 THEN -1 ELSE 5000 END,
               @Pvs=CASE WHEN @Case=15 THEN -1 WHEN @Case IN(4,5,6,7,8,9,10,20,21) THEN 0 ELSE 1024 END,
               @Aborted=CASE WHEN @Case=16 THEN -1 ELSE 1 END,
               @Invalid=CASE WHEN @Case BETWEEN 11 AND 19 OR @Case=23 THEN 1 ELSE 0 END,
               @Unavailable=CASE WHEN @Case=22 THEN 1 ELSE 0 END,
               @WarningName=CASE WHEN @Case=8 THEN N'exampleMaintenanceSourceÖ' WHEN @Case IN(9,10,21) THEN N'ExampleMaintenanceMissingß' ELSE NULL END,
               @Json=NULL,@Status=NULL,@Partial=NULL;
        DELETE [#ExampleMaintenanceNativePvs];
    INSERT [#ExampleMaintenanceNativePvs]
    SELECT [d].[database_id],[d].[name],[d].[is_accelerated_database_recovery_on],
           CONVERT(decimal(19,2),[s].[persistent_version_store_size_kb]/1024.0),
           CONVERT(decimal(19,2),[s].[online_index_version_store_size_kb]/1024.0),[s].[current_aborted_transaction_count],
           'ADR_NOT_ENABLED','INFO',N'ADR/PVS-Zaehler sind Zeitpunktwerte und beweisen allein keine Bereinigungsstoerung.'
    FROM [sys].[databases] [d] LEFT JOIN [sys].[dm_tran_persistent_version_store_stats] [s]
      ON [s].[database_id]=[d].[database_id] WHERE [d].[database_id] IN(@OwnedA,@OwnedO,@OwnedU);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleMaintenanceNativePvs])<>3 OR NOT(@OwnedA<@OwnedO AND @OwnedO<@OwnedU)
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs]
                 WHERE ([DatabaseId]=@OwnedA AND [AdrEnabled]<>0) OR ([DatabaseId] IN(@OwnedO,@OwnedU) AND [AdrEnabled]<>1))
       OR (SELECT COUNT_BIG(*) FROM [sys].[dm_tran_persistent_version_store_stats] WHERE [database_id] IN(@OwnedO,@OwnedU))<>2
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs] WHERE [DatabaseId] IN(@OwnedO,@OwnedU)
                 AND ([PvsSizeMb] IS NULL OR [PvsSizeMb]<0 OR [PvsSizeMb]>=1024 OR [OnlineIndexPvsSizeMb] IS NULL OR [OnlineIndexPvsSizeMb]<>0
                      OR [CurrentAbortedTransactionCount] IS NULL OR [CurrentAbortedTransactionCount]<>0))
        THROW 56507,N'Maintenance native identities, ADR flags or actual PVS counters failed.',1;
        /* Unabhängige Erwartungen aus tatsächlich gemessenen ADR-Metadaten eigener Datenbanken ohne Nutzdaten. */
        UPDATE [#ExampleMaintenanceNativePvs]
        SET [FindingCode]=CASE WHEN [AdrEnabled]=0 THEN 'ADR_NOT_ENABLED'
                               WHEN @LowThreshold=1 THEN 'PVS_SIZE_THRESHOLD_REACHED' ELSE 'PVS_WITHIN_THRESHOLDS' END,
            [FindingSeverity]=CASE WHEN [AdrEnabled]=1 AND @LowThreshold=1 THEN 'MEDIUM' ELSE 'INFO' END;
        TRUNCATE TABLE [#ExampleMaintenanceExpectedPvs];
        INSERT [#ExampleMaintenanceExpectedPvs]
        SELECT TOP(@SafeLimit) * FROM [#ExampleMaintenanceNativePvs]
        WHERE @Invalid=0 AND @Unavailable=0 AND @Case NOT IN(8,10)
          AND (@Case<>7 OR [DatabaseName]=N'ExampleMaintenanceSourceÖ')
          AND (@Problems=0 OR [FindingSeverity]='MEDIUM') ORDER BY [DatabaseId];
        SELECT @ExpectedCount=COUNT_BIG(*) FROM [#ExampleMaintenanceExpectedPvs];
        IF @ExpectedCount<>CASE WHEN @Case IN(0,1,6,9) THEN 3 WHEN @Case IN(4,21) THEN 2
                                WHEN @Case IN(2,5,7,20) THEN 1 ELSE 0 END
            THROW 56517,N'Maintenance independently specified mixed INFO/MEDIUM candidate counts failed.',1;
        SET @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' WHEN @Unavailable=1 THEN 'UNAVAILABLE_FEATURE'
                                 WHEN @WarningName IS NOT NULL THEN 'AVAILABLE_LIMITED'
                                 WHEN @LowThreshold=1 AND EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs] WHERE [AdrEnabled]=1) THEN 'AVAILABLE_WITH_FINDING'
                                 ELSE 'AVAILABLE' END;
        CREATE TABLE [#ExampleMaintenanceExport]([Dummy] int NULL);
        EXEC [monitor].[USP_MaintenanceOperations]
             @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@JobNames=@Jobs,@JobNamePattern=@JobPattern,
             @NurProblematisch=@Problems,@MaxZeilen=@Limit,@LockTimeoutMs=@Timeout,@ResumablePausedWarnMinutes=@Paused,
             @BlockedWarnMs=@Blocked,@PvsWarnMb=@Pvs,@AbortedTransactionsWarnCount=@Aborted,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"resumableOperations":"#ExampleMaintenanceExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        /* Unmittelbarer zweiter nativer Snapshot; keine erneute Produktabfrage. */
        TRUNCATE TABLE [#ExampleMaintenanceAfterPvs];
        INSERT [#ExampleMaintenanceAfterPvs]
        SELECT [d].[database_id],[d].[name],[d].[is_accelerated_database_recovery_on],
               CONVERT(decimal(19,2),[n].[persistent_version_store_size_kb]/1024.0),
               CONVERT(decimal(19,2),[n].[online_index_version_store_size_kb]/1024.0),[n].[current_aborted_transaction_count]
        FROM [sys].[databases] [d] LEFT JOIN [sys].[dm_tran_persistent_version_store_stats] [n]
          ON [n].[database_id]=[d].[database_id] WHERE [d].[database_id] IN(@OwnedA,@OwnedO,@OwnedU);
        IF (SELECT COUNT_BIG(*) FROM [#ExampleMaintenanceAfterPvs])<>3
           OR EXISTS(SELECT [DatabaseId],[DatabaseName],[AdrEnabled] FROM [#ExampleMaintenanceAfterPvs]
                     EXCEPT SELECT [DatabaseId],[DatabaseName],[AdrEnabled] FROM [#ExampleMaintenanceNativePvs])
           OR EXISTS(SELECT [DatabaseId],[DatabaseName],[AdrEnabled] FROM [#ExampleMaintenanceNativePvs]
                     EXCEPT SELECT [DatabaseId],[DatabaseName],[AdrEnabled] FROM [#ExampleMaintenanceAfterPvs])
           OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceAfterPvs] WHERE [DatabaseId] IN(@OwnedO,@OwnedU)
                     AND ([PvsSizeMb] IS NULL OR [PvsSizeMb]<0 OR [PvsSizeMb]>=1024
                          OR [OnlineIndexPvsSizeMb] IS NULL OR [OnlineIndexPvsSizeMb]<>0
                          OR [CurrentAbortedTransactionCount] IS NULL OR [CurrentAbortedTransactionCount]<>0))
            THROW 56518,N'Maintenance after-snapshot identity or independent PVS threshold domain failed.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Invalid=1 OR @Unavailable=1 OR @WarningName IS NOT NULL THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Invalid=1 OR @Unavailable=1 OR @WarningName IS NOT NULL THEN N'true' ELSE N'false' END
            THROW 56510,N'Maintenance complete-scope status or selection partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleMaintenanceExport])<>0
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.resumableOperations'))<>0
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.requests'))<>0
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.jobs'))<>0
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.pvs'))<>@ExpectedCount
            THROW 56511,N'Maintenance exact PVS filter/limit or empty companion-scope count failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>6
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json)
                     EXCEPT SELECT [ExpectedKey] FROM (VALUES(N'meta'),(N'resumableOperations'),(N'requests'),(N'pvs'),(N'jobs'),(N'sources')) [k]([ExpectedKey]))
            THROW 56512,N'Maintenance existing JSON envelope changed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceExport'))<>15
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceExport') AND [collation_name] IS NOT NULL)<>8
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],
                            [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable]
                     FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceExport')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],
                            [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable]
                     FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceResumableSchema'))
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],
                            [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable]
                     FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceResumableSchema')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],
                            [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable]
                     FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMaintenanceExport'))
            THROW 56513,N'Maintenance full 15-field TABLE schema or eight text collations failed.',1;
        /* PVS ist ein nicht atomarer Snapshot. Nur dieser Zahlenwert darf innerhalb
           der beiden unabhängig gemessenen Grenzen derselben Identität driften. */
        IF EXISTS
           (SELECT 1 FROM OPENJSON(@Json,N'$.pvs') [r]
            OUTER APPLY OPENJSON([r].[value]) WITH([DatabaseId] int '$.DatabaseId') [j]
            OUTER APPLY(SELECT COUNT_BIG(*) AS [NodeCount],MAX([type]) AS [NodeType],MAX([value]) AS [NodeValue]
                        FROM OPENJSON([r].[value]) WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N'PvsSizeMb') [v]
            LEFT JOIN [#ExampleMaintenanceExpectedPvs] [e] ON [e].[DatabaseId]=[j].[DatabaseId]
            LEFT JOIN [#ExampleMaintenanceNativePvs] [b] ON [b].[DatabaseId]=[j].[DatabaseId]
            LEFT JOIN [#ExampleMaintenanceAfterPvs] [a] ON [a].[DatabaseId]=[j].[DatabaseId]
            WHERE [e].[DatabaseId] IS NULL OR [b].[DatabaseId] IS NULL OR [a].[DatabaseId] IS NULL OR [v].[NodeCount]<>1
               OR ([b].[PvsSizeMb] IS NULL AND [a].[PvsSizeMb] IS NOT NULL)
               OR ([b].[PvsSizeMb] IS NOT NULL AND [a].[PvsSizeMb] IS NULL)
               OR ([b].[PvsSizeMb] IS NULL AND [a].[PvsSizeMb] IS NULL AND [v].[NodeType]<>0)
               OR ([b].[PvsSizeMb] IS NOT NULL AND [a].[PvsSizeMb] IS NOT NULL
                   AND ([v].[NodeType]<>2 OR TRY_CONVERT(decimal(19,2),[v].[NodeValue]) IS NULL
                        OR TRY_CONVERT(decimal(19,2),[v].[NodeValue])<0
                        OR TRY_CONVERT(decimal(19,2),[v].[NodeValue])<CASE WHEN [b].[PvsSizeMb]<[a].[PvsSizeMb] THEN [b].[PvsSizeMb] ELSE [a].[PvsSizeMb] END
                        OR TRY_CONVERT(decimal(19,2),[v].[NodeValue])>CASE WHEN [b].[PvsSizeMb]>[a].[PvsSizeMb] THEN [b].[PvsSizeMb] ELSE [a].[PvsSizeMb] END)))
            THROW 56519,N'Maintenance PVS JSON node type, identity or native before/after numeric bound failed.',1;
        /* Erst nach der unabhängigen Zahlenprüfung wird ausschließlich PvsSizeMb
           für den vollständigen Feld-/Property-/Typ-/Häufigkeitsvergleich normiert. */
        UPDATE [e] SET [PvsSizeMb]=[j].[PvsSizeMb]
        FROM [#ExampleMaintenanceExpectedPvs] [e]
        JOIN OPENJSON(@Json,N'$.pvs') WITH([DatabaseId] int '$.DatabaseId',[PvsSizeMb] decimal(19,2) '$.PvsSizeMb') [j]
          ON [j].[DatabaseId]=[e].[DatabaseId];
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleMaintenanceExpectedPvs] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.pvs'));
        IF EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ExpectedJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ActualJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ActualJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ExpectedJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56514,N'Maintenance nine-field PVS/JSON parity with independently bounded snapshot size failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sources'))<>CASE WHEN @Invalid=1 OR @Unavailable=1 THEN 0 ELSE 4 END
           OR (@Invalid=0 AND @Unavailable=0 AND EXISTS(SELECT * FROM [#ExampleMaintenanceSources] EXCEPT SELECT * FROM OPENJSON(@Json,N'$.sources') WITH
                ([SourceName] nvarchar(128) '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial')))
           OR (@Invalid=0 AND @Unavailable=0 AND EXISTS(SELECT * FROM OPENJSON(@Json,N'$.sources') WITH
                ([SourceName] nvarchar(128) '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial') EXCEPT SELECT * FROM [#ExampleMaintenanceSources]))
            THROW 56515,N'Maintenance four independent source identities or source partiality failed.',1;
        DROP TABLE [#ExampleMaintenanceExport];
        SET @Case+=1;
    END;
    /* Keine separate Capture der RAW-Warnings oder fachlichen Console-Zeilen. */
    WHILE @Route<6
    BEGIN
        SELECT @Mode=CASE WHEN @Route IN(0,2,4) THEN 'RAW' ELSE 'CONSOLE' END,
               @Limit=CASE WHEN @Route IN(2,3) THEN -1 ELSE 1 END,
               @Names=CASE WHEN @Route>=4 THEN N'[ExampleMaintenanceSourceÄ]|[ExampleMaintenanceSourceÖ]|[ExampleMaintenanceSourceÜ]|[ExampleMaintenanceMissingß]'
                           ELSE N'[ExampleMaintenanceSourceÄ]|[ExampleMaintenanceSourceÖ]|[ExampleMaintenanceSourceÜ]' END,
               @Json=NULL,@Status=NULL,@Partial=NULL;
        DELETE [#ExampleMaintenanceNativePvs];
    INSERT [#ExampleMaintenanceNativePvs]
    SELECT [d].[database_id],[d].[name],[d].[is_accelerated_database_recovery_on],
           CONVERT(decimal(19,2),[s].[persistent_version_store_size_kb]/1024.0),
           CONVERT(decimal(19,2),[s].[online_index_version_store_size_kb]/1024.0),[s].[current_aborted_transaction_count],
           'ADR_NOT_ENABLED','INFO',N'ADR/PVS-Zaehler sind Zeitpunktwerte und beweisen allein keine Bereinigungsstoerung.'
    FROM [sys].[databases] [d] LEFT JOIN [sys].[dm_tran_persistent_version_store_stats] [s]
      ON [s].[database_id]=[d].[database_id] WHERE [d].[database_id] IN(@OwnedA,@OwnedO,@OwnedU);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleMaintenanceNativePvs])<>3 OR NOT(@OwnedA<@OwnedO AND @OwnedO<@OwnedU)
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs]
                 WHERE ([DatabaseId]=@OwnedA AND [AdrEnabled]<>0) OR ([DatabaseId] IN(@OwnedO,@OwnedU) AND [AdrEnabled]<>1))
       OR (SELECT COUNT_BIG(*) FROM [sys].[dm_tran_persistent_version_store_stats] WHERE [database_id] IN(@OwnedO,@OwnedU))<>2
       OR EXISTS(SELECT 1 FROM [#ExampleMaintenanceNativePvs] WHERE [DatabaseId] IN(@OwnedO,@OwnedU)
                 AND ([PvsSizeMb] IS NULL OR [PvsSizeMb]<0 OR [PvsSizeMb]>=1024 OR [OnlineIndexPvsSizeMb] IS NULL OR [OnlineIndexPvsSizeMb]<>0
                      OR [CurrentAbortedTransactionCount] IS NULL OR [CurrentAbortedTransactionCount]<>0))
        THROW 56507,N'Maintenance native identities, ADR flags or actual PVS counters failed.',1;
        EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=@Names,@PvsWarnMb=0,@NurProblematisch=1,
             @MaxZeilen=@Limit,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>CASE WHEN @Route IN(2,3) THEN 'INVALID_PARAMETER'
                                                                          WHEN @Route>=4 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE_WITH_FINDING' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Route>=2 THEN 1 ELSE 0 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.pvs'))<>CASE WHEN @Route IN(2,3) THEN 0 ELSE 1 END
            THROW 56516,N'Maintenance RAW/CONSOLE status or accompanying JSON count failed.',1;
        SET @Route+=1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedA IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÄ')=@OwnedA
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÄ];
    END;
    IF @OwnedO IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÖ')=@OwnedO
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÖ];
    END;
    IF @OwnedU IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÜ')=@OwnedU
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÜ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÜ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@LevelA AS [FirstSourceCompatibilityLevel],
           @LevelO AS [SecondSourceCompatibilityLevel],@LevelU AS [ThirdSourceCompatibilityLevel],
           @Case AS [TableJsonCases],@Route AS [RawConsoleStatusCases],
           N'Eigene PVS-Metadaten und leerer Resumable-Export geprüft; positive Operationen, Jobs und Hochlast bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','ExampleMaintenanceNativeCursor')>=0 CLOSE [ExampleMaintenanceNativeCursor];
    IF CURSOR_STATUS('local','ExampleMaintenanceNativeCursor')>-3 DEALLOCATE [ExampleMaintenanceNativeCursor];
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedA IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÄ')=@OwnedA
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÄ];
    END;
    IF @OwnedO IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÖ')=@OwnedO
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÖ];
    END;
    IF @OwnedU IS NOT NULL AND DB_ID(N'ExampleMaintenanceSourceÜ')=@OwnedU
    BEGIN
        ALTER DATABASE [ExampleMaintenanceSourceÜ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleMaintenanceSourceÜ];
    END;
    THROW;
END CATCH;
GO
