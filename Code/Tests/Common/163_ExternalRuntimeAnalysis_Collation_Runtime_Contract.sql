USE [DeineDatenbank];
GO
/* Prüft eigene leere Unicode-Datenbanken ohne Language-/Libraryregistrierung oder
   externe Ausführung. Vorhandene Standardregistrierungen werden nativ erfasst;
   ihre bestehenden WARN-/INFO-Findings können positive Filter-/Limitfälle tragen.
   Leere Languagefilter belegen nur Leerakzeptanz. Pool- und Counterquellen werden auch bei
   nichtleeren Ergebnissen nativ gegengeprüft. RAW/CONSOLE werden nur über Status und begleitendes JSON geprüft.
   Framework und beide Quellen verwenden ausdrücklich denselben Level 150/160/170. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleExternalRuntimeÄ') IS NOT NULL OR DB_ID(N'exampleExternalRuntimeÄ') IS NOT NULL
   OR DB_ID(N'ExampleExternalRuntimeMissingß') IS NOT NULL
    THROW 56700,N'ExternalRuntime fixture or missing-selection name already exists.',1;
DECLARE @OwnedUpper int=NULL,@OwnedLower int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @Host nvarchar(60)=TRY_CONVERT(nvarchar(60),SERVERPROPERTY(N'HostPlatform')),
        @LevelUpper int,@LevelLower int,@Sql nvarchar(max),@Query nvarchar(max),@NativeRows bigint,@NativeError int,
        @SourceCode varchar(80),@Db nvarchar(128),@Case int=0,@Route int=0,@Mode varchar(16),
        @Names nvarchar(max),@DbPattern nvarchar(4000),@LanguageNames nvarchar(max),@LanguagePattern nvarchar(4000),
        @Limit int,@SafeLimit bigint,@Problems bit,@Sample tinyint,@Timeout int,@FileMetadata bit,@Invalid bit,
        @MissingName nvarchar(128),@EmptyLanguage bit,@ExpectedStatus varchar(40),@ExpectedPartial bit,
        @ExpectedFindingCount bigint,@ExpectedWarnCount bigint,@OutputCount bigint,@Json nvarchar(max),
        @Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048),@TableJson nvarchar(max),
        @Before datetime2(3),@After datetime2(3),@ConfigValue int,@ValueInUse int,@Analytics int,
        @Services int,@Running int,@LaunchStatus varchar(40),@Truncated bit,
        @BaselineStatus varchar(40),@BaselinePartial bit,@BaselineWarnCount bigint,@PositiveFindingCases int=0;
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 56701,N'ExternalRuntime framework level is outside the contract.',1;
IF @Major IS NULL OR @Major<15 THROW 56702,N'ExternalRuntime needs a visible SQL Server 2019 or newer version.',1;
CREATE TABLE [#ExampleExternalRuntimeSchema]
(
      [FindingOrdinal] bigint NOT NULL PRIMARY KEY
    , [DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [MetricValue] decimal(38,4) NULL
    , [ThresholdValue] decimal(38,4) NULL
    , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE [#ExampleExternalRuntimeSelected]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
CREATE TABLE [#ExampleExternalRuntimeNativeLanguages]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [LanguageId] int NOT NULL,[LanguageName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#ExampleExternalRuntimeNativeLibraries]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [LibraryId] int NOT NULL,[LibraryName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#ExampleExternalRuntimeNativePools]
  ([ExternalPoolId] int NOT NULL,[PoolName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [MaxCpuPercent] int NULL,[MaxProcesses] int NULL,[MaxMemoryPercent] int NULL,[StatisticsStartTime] datetime NULL,
   [PeakMemoryKb] bigint NULL,[ActiveProcessesCount] int NULL);
CREATE TABLE [#ExampleExternalRuntimeNativeStats]
  ([LanguageName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [CounterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterValue] bigint NOT NULL);
CREATE TABLE [#ExampleExternalRuntimeNativeCounters]
  ([CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterType] int NOT NULL,[CounterValue] bigint NOT NULL);
CREATE TABLE [#ExampleExternalRuntimeExpectedSources]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[ErrorNumber] int NULL);
CREATE TABLE [#ExampleExternalRuntimeNativeQueries]
  ([SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT [#ExampleExternalRuntimeNativeQueries] VALUES
('LAUNCHPAD_SERVICE',N'SELECT @pServices=COUNT(*),@pRunning=COALESCE(SUM(CASE WHEN [status]=4 THEN 1 ELSE 0 END),0) FROM [sys].[dm_server_services] WHERE [servicename] LIKE N''%Launchpad%''; SET @pRows=@pServices;'),
('ACTIVE_EXTERNAL_REQUESTS',N'SELECT @pRows=COUNT_BIG(*) FROM [sys].[dm_external_script_requests] [e] LEFT JOIN [sys].[dm_exec_requests] [r] ON [r].[external_script_request_id]=[e].[external_script_request_id] LEFT JOIN [sys].[dm_exec_sessions] [s] ON [s].[session_id]=[r].[session_id] WHERE (@pEmpty=0 OR [e].[language] COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleUnusedLanguageÄ'') AND (COALESCE([r].[database_id],[s].[database_id]) IS NULL OR EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeSelected] [d] JOIN [sys].[databases] [n] ON [n].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[d].[DatabaseName] WHERE [n].[database_id]=COALESCE([r].[database_id],[s].[database_id])));'),
('EXTERNAL_POOLS_T1',N'INSERT [#ExampleExternalRuntimeNativePools] SELECT [external_pool_id],[name],[max_cpu_percent],[max_processes],[max_memory_percent],[statistics_start_time],[peak_memory_kb],[active_processes_count] FROM [sys].[dm_resource_governor_external_resource_pools]; SET @pRows=@@ROWCOUNT;'),
('EXECUTION_STATS_T1',N'INSERT [#ExampleExternalRuntimeNativeStats] SELECT [language],[counter_name],CONVERT(bigint,[counter_value]) FROM [sys].[dm_external_script_execution_stats] WHERE @pEmpty=0 OR [language] COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleUnusedLanguageÄ''; SET @pRows=@@ROWCOUNT;'),
('EXTERNAL_COUNTERS_T1',N'INSERT [#ExampleExternalRuntimeNativeCounters] SELECT [counter_name],[instance_name],[cntr_type],[cntr_value] FROM [sys].[dm_os_performance_counters] WHERE [object_name] LIKE N''%External Scripts%''; SET @pRows=@@ROWCOUNT;');
CREATE TABLE [#ExampleExternalRuntimeExpectedFindings]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricValue] decimal(38,4) NULL,[ThresholdValue] decimal(38,4) NULL);
CREATE TABLE [#ExampleExternalRuntimeKeys]
 ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[JsonType] int NOT NULL);
INSERT [#ExampleExternalRuntimeKeys] VALUES
 (N'meta',5),(N'configuration',4),(N'databaseStatus',4),(N'sourceStatus',4),(N'findings',4),(N'languages',4),
 (N'libraries',4),(N'activeRequests',4),(N'externalPools',4),(N'executionStats',4),(N'performanceCounters',4),(N'warnings',4);
BEGIN TRY
    DECLARE @DataPath nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultDataPath')),
            @LogPath nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultLogPath')),
            @FixtureSuffix nvarchar(36)=CONVERT(nvarchar(36),NEWID());
    IF NULLIF(@DataPath,N'') IS NULL OR NULLIF(@LogPath,N'') IS NULL
        THROW 56721,N'ExternalRuntime fixture default data or log directory unavailable.',1;
    IF RIGHT(@DataPath,1) NOT IN(N'/',NCHAR(92))
        SET @DataPath+=CASE WHEN CHARINDEX(N'/',@DataPath)>0 THEN N'/' ELSE NCHAR(92) END;
    IF RIGHT(@LogPath,1) NOT IN(N'/',NCHAR(92))
        SET @LogPath+=CASE WHEN CHARINDEX(N'/',@LogPath)>0 THEN N'/' ELSE NCHAR(92) END;
    SET @Sql=N'CREATE DATABASE [ExampleExternalRuntimeÄ] ON PRIMARY
(NAME=N''ExampleExternalRuntimeUpperData'',FILENAME=N'''+REPLACE(@DataPath+N'ExampleExternalRuntimeUpper-'+@FixtureSuffix+N'.mdf',N'''',N'''''')+N''')
LOG ON (NAME=N''ExampleExternalRuntimeUpperLog'',FILENAME=N'''+REPLACE(@LogPath+N'ExampleExternalRuntimeUpper-'+@FixtureSuffix+N'.ldf',N'''',N'''''')+N''') COLLATE Latin1_General_100_CI_AS;';
    EXEC(@Sql);
    SET @OwnedUpper=DB_ID(N'ExampleExternalRuntimeÄ');
    SET @Sql=N'CREATE DATABASE [exampleExternalRuntimeÄ] ON PRIMARY
(NAME=N''ExampleExternalRuntimeLowerData'',FILENAME=N'''+REPLACE(@DataPath+N'ExampleExternalRuntimeLower-'+@FixtureSuffix+N'.mdf',N'''',N'''''')+N''')
LOG ON (NAME=N''ExampleExternalRuntimeLowerLog'',FILENAME=N'''+REPLACE(@LogPath+N'ExampleExternalRuntimeLower-'+@FixtureSuffix+N'.ldf',N'''',N'''''')+N''') COLLATE Latin1_General_100_CI_AS;';
    EXEC(@Sql);
    SET @OwnedLower=DB_ID(N'exampleExternalRuntimeÄ');
    SET @Sql=N'ALTER DATABASE [ExampleExternalRuntimeÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N'; ALTER DATABASE [exampleExternalRuntimeÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';'; EXEC(@Sql);
    SELECT @LevelUpper=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedUpper;
    SELECT @LevelLower=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedLower;
    IF @OwnedUpper IS NULL OR @OwnedLower IS NULL OR @OwnedUpper=@OwnedLower
       OR @LevelUpper<>@FrameworkLevel OR @LevelLower<>@FrameworkLevel
       OR EXISTS(SELECT 1 FROM [sys].[databases] WHERE [database_id] IN(@OwnedUpper,@OwnedLower)
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS')
        THROW 56703,N'ExternalRuntime own identities, explicit source levels or CI_AS collations failed.',1;
    WHILE @Case<22
    BEGIN
        SELECT @Limit=CASE WHEN @Case=0 THEN NULL WHEN @Case IN(2,3,5) THEN 1 WHEN @Case=11 THEN -1 ELSE 0 END,
               @SafeLimit=CASE WHEN @Case IN(2,3,5) THEN 1 WHEN @Case=11 THEN 0 ELSE CONVERT(bigint,9223372036854775807) END,
               @Problems=CASE WHEN @Case IN(3,4,5) THEN 1 WHEN @Case=16 THEN NULL ELSE 0 END,
               @Sample=CASE WHEN @Case=12 THEN NULL WHEN @Case=13 THEN 61 ELSE 0 END,
               @Timeout=CASE WHEN @Case=14 THEN NULL WHEN @Case=15 THEN -1 ELSE 4321 END,
               @FileMetadata=CASE WHEN @Case=20 THEN NULL ELSE 0 END,
               @LanguageNames=CASE WHEN @Case IN(6,18) THEN N'[ExampleUnusedLanguageÄ]' WHEN @Case=17 THEN N'[ExampleUnclosed' ELSE NULL END,
               @LanguagePattern=CASE WHEN @Case IN(7,18) THEN N'like:ExampleUnusedLanguageÄ' ELSE NULL END,
               @EmptyLanguage=CASE WHEN @Case IN(6,7) THEN 1 ELSE 0 END,
               @Names=CASE WHEN @Case=8 THEN N'[ExampleExternalRuntimeÄ]' WHEN @Case=9 THEN N'[exampleExternalRuntimeÄ]'
                           WHEN @Case=10 THEN N'[ExampleExternalRuntimeÄ]|[ExampleExternalRuntimeMissingß]'
                           WHEN @Case=21 THEN N'[EXAMPLEExternalRuntimeÄ]' ELSE N'[ExampleExternalRuntimeÄ]|[exampleExternalRuntimeÄ]' END,
               @MissingName=CASE WHEN @Case=10 THEN N'ExampleExternalRuntimeMissingß' WHEN @Case=21 THEN N'EXAMPLEExternalRuntimeÄ' ELSE NULL END,
               @DbPattern=CASE WHEN @Case=19 THEN N'like:ExampleExternalRuntime%' ELSE NULL END,
               @Invalid=CASE WHEN @Case BETWEEN 11 AND 20 THEN 1 ELSE 0 END;
        DELETE [#ExampleExternalRuntimeSelected]; DELETE [#ExampleExternalRuntimeNativeLanguages]; DELETE [#ExampleExternalRuntimeNativeLibraries];
        DELETE [#ExampleExternalRuntimeNativePools]; DELETE [#ExampleExternalRuntimeNativeStats]; DELETE [#ExampleExternalRuntimeNativeCounters];
        DELETE [#ExampleExternalRuntimeExpectedSources]; DELETE [#ExampleExternalRuntimeExpectedFindings];
        SELECT @Services=NULL,@Running=NULL,@LaunchStatus=NULL,@ConfigValue=NULL,@ValueInUse=NULL,@Analytics=NULL;
        IF @Invalid=0
        BEGIN
            IF @Case NOT IN(9,21) INSERT [#ExampleExternalRuntimeSelected] VALUES(N'ExampleExternalRuntimeÄ');
            IF @Case NOT IN(8,10,21) INSERT [#ExampleExternalRuntimeSelected] VALUES(N'exampleExternalRuntimeÄ');
            SELECT @ConfigValue=MAX(TRY_CONVERT(int,[value])),@ValueInUse=MAX(TRY_CONVERT(int,[value_in_use]))
            FROM [sys].[configurations] WHERE [name]=N'external scripts enabled';
            SET @Analytics=TRY_CONVERT(int,SERVERPROPERTY(N'IsAdvancedAnalyticsInstalled'));
            INSERT [#ExampleExternalRuntimeExpectedSources] VALUES(NULL,'SERVER_CONFIGURATION','AVAILABLE',0,1,NULL);
            DECLARE [ExampleExternalRuntimeNativeCursor] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [SourceCode],[QueryText] FROM [#ExampleExternalRuntimeNativeQueries];
            OPEN [ExampleExternalRuntimeNativeCursor]; FETCH NEXT FROM [ExampleExternalRuntimeNativeCursor] INTO @SourceCode,@Query;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @NativeRows=0;
                BEGIN TRY
                    EXEC [sys].[sp_executesql] @Query,N'@pRows bigint OUTPUT,@pServices int OUTPUT,@pRunning int OUTPUT,@pEmpty bit',
                         @pRows=@NativeRows OUTPUT,@pServices=@Services OUTPUT,@pRunning=@Running OUTPUT,@pEmpty=@EmptyLanguage;
                    INSERT [#ExampleExternalRuntimeExpectedSources] VALUES(NULL,@SourceCode,'AVAILABLE',0,@NativeRows,NULL);
                END TRY
                BEGIN CATCH
                    SET @NativeError=ERROR_NUMBER();
                    INSERT [#ExampleExternalRuntimeExpectedSources]
                    VALUES(NULL,@SourceCode,CASE WHEN @NativeError IN(229,297,300,371,916) THEN 'DENIED_PERMISSION'
                        WHEN @NativeError IN(207,208) AND @SourceCode IN('ACTIVE_EXTERNAL_REQUESTS','EXTERNAL_POOLS_T1','EXECUTION_STATS_T1') THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,1,0,@NativeError);
                END CATCH;
                FETCH NEXT FROM [ExampleExternalRuntimeNativeCursor] INTO @SourceCode,@Query;
            END;
            CLOSE [ExampleExternalRuntimeNativeCursor]; DEALLOCATE [ExampleExternalRuntimeNativeCursor];
            SET @LaunchStatus=CASE WHEN @Services IS NULL THEN 'SOURCE_UNAVAILABLE' WHEN @Services=0 THEN 'NOT_VISIBLE'
                                  WHEN @Services=@Running THEN 'RUNNING' WHEN @Running=0 THEN 'STOPPED' ELSE 'PARTIALLY_RUNNING' END;
            DECLARE [ExampleExternalRuntimeDatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#ExampleExternalRuntimeSelected];
            OPEN [ExampleExternalRuntimeDatabaseCursor]; FETCH NEXT FROM [ExampleExternalRuntimeDatabaseCursor] INTO @Db;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @Sql=N'INSERT [#ExampleExternalRuntimeNativeLanguages] SELECT @pDb,[external_language_id],[language] FROM '+QUOTENAME(@Db)+N'.[sys].[external_languages] WHERE @pEmpty=0 OR [language] COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleUnusedLanguageÄ''; SET @pRows=@@ROWCOUNT;';
                EXEC [sys].[sp_executesql] @Sql,N'@pDb nvarchar(128),@pEmpty bit,@pRows bigint OUTPUT',@pDb=@Db,@pEmpty=@EmptyLanguage,@pRows=@NativeRows OUTPUT;
                INSERT [#ExampleExternalRuntimeExpectedSources] VALUES(@Db,'EXTERNAL_LANGUAGES','AVAILABLE',0,@NativeRows,NULL);
                SET @Sql=N'INSERT [#ExampleExternalRuntimeNativeLibraries] SELECT @pDb,[external_library_id],[name] FROM '+QUOTENAME(@Db)+N'.[sys].[external_libraries] WHERE @pEmpty=0 OR [language] COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleUnusedLanguageÄ''; SET @pRows=@@ROWCOUNT;';
                EXEC [sys].[sp_executesql] @Sql,N'@pDb nvarchar(128),@pEmpty bit,@pRows bigint OUTPUT',@pDb=@Db,@pEmpty=@EmptyLanguage,@pRows=@NativeRows OUTPUT;
                INSERT [#ExampleExternalRuntimeExpectedSources] VALUES(@Db,'EXTERNAL_LIBRARIES','AVAILABLE',0,@NativeRows,NULL);
                FETCH NEXT FROM [ExampleExternalRuntimeDatabaseCursor] INTO @Db;
            END;
            CLOSE [ExampleExternalRuntimeDatabaseCursor]; DEALLOCATE [ExampleExternalRuntimeDatabaseCursor];
            /* Der begrenzte Fixtureumfang hat keine Library- oder Requestaktivität.
               Vorhandene Standardsprachen sind zulässig und werden exakt zugeordnet. */
            IF EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeNativeLibraries])
               OR EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeExpectedSources] WHERE [SourceCode]='ACTIVE_EXTERNAL_REQUESTS' AND [RowCount]<>0)
               OR EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeNativePools] WHERE COALESCE([MaxProcesses],0)>0 AND [ActiveProcessesCount]>=[MaxProcesses])
               OR COALESCE(@ValueInUse,0)<>0
                THROW 56704,N'ExternalRuntime native scope exceeds this no-execution fixture contract.',1;
            INSERT [#ExampleExternalRuntimeExpectedFindings]
            SELECT [DatabaseName],'DATABASE_REGISTRATION',NULL,'WARN','REGISTERED_RUNTIME_WHILE_EXTERNAL_SCRIPTS_DISABLED',
                   'RegisteredObjectCount',COUNT_BIG(*),1 FROM [#ExampleExternalRuntimeNativeLanguages] GROUP BY [DatabaseName];
            INSERT [#ExampleExternalRuntimeExpectedFindings]
            SELECT [DatabaseName],'EXTERNAL_LANGUAGE',[LanguageName],'INFO','REGISTERED_RUNTIME_STARTABILITY_UNVERIFIED',NULL,NULL,NULL
            FROM [#ExampleExternalRuntimeNativeLanguages];
        END;
        SELECT @ExpectedFindingCount=COUNT_BIG(*),@ExpectedWarnCount=COALESCE(SUM(CONVERT(bigint,CASE WHEN [Severity]='WARN' THEN 1 ELSE 0 END)),0)
        FROM [#ExampleExternalRuntimeExpectedFindings];
        SET @ExpectedPartial=CONVERT(bit,CASE WHEN @Invalid=1 OR @MissingName IS NOT NULL OR EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeExpectedSources] WHERE [IsPartial]=1) THEN 1 ELSE 0 END);
        SET @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' WHEN @ExpectedPartial=1 THEN 'AVAILABLE_LIMITED'
             WHEN @ExpectedWarnCount>0 THEN 'AVAILABLE_WITH_FINDING'
             WHEN EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeNativeStats]) THEN 'FEATURE_DISABLED' ELSE 'NOT_APPLICABLE' END;
        SET @OutputCount=CASE WHEN @Problems=1 THEN @ExpectedWarnCount ELSE @ExpectedFindingCount END;
        IF @Case=1 SELECT @BaselineStatus=@ExpectedStatus,@BaselinePartial=@ExpectedPartial,@BaselineWarnCount=@ExpectedWarnCount;
        SET @Truncated=CONVERT(bit,CASE WHEN @Limit>0 AND
            (CASE WHEN @Problems=1 THEN @ExpectedWarnCount ELSE @ExpectedFindingCount END>@SafeLimit
             OR (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeLanguages])>@SafeLimit
             OR (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeStats])>@SafeLimit
             OR (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeCounters])>@SafeLimit) THEN 1 ELSE 0 END);
        IF @OutputCount>@SafeLimit SET @OutputCount=@SafeLimit;
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,@Before=SYSUTCDATETIME();
        CREATE TABLE [#ExampleExternalRuntimeExport]([Dummy] int NULL);
        EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=@Names,@DatabaseNamePattern=@DbPattern,
             @LanguageNames=@LanguageNames,@LanguageNamePattern=@LanguagePattern,@SampleSeconds=@Sample,
             @MitDateimetadaten=@FileMetadata,@NurProblematisch=@Problems,@MaxZeilen=@Limit,@LockTimeoutMs=@Timeout,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleExternalRuntimeExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
             @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        SET @After=SYSUTCDATETIME();
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus OR COALESCE(CONVERT(int,@Partial),-1)<>CONVERT(int,@ExpectedPartial)
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),'')<>CASE WHEN @ExpectedPartial=1 THEN 'true' ELSE 'false' END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.module'),'')<>'USP_ExternalRuntimeAnalysis'
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.collectedAtUtc')) IS NULL
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.collectedAtUtc')) NOT BETWEEN @Before AND @After
           OR @@LOCK_TIMEOUT<>@OriginalLockTimeout
           OR COALESCE(@ErrorNumber,-1)<>COALESCE((SELECT MIN([ErrorNumber]) FROM [#ExampleExternalRuntimeExpectedSources] WHERE [IsPartial]=1),-1)
            THROW 56705,N'ExternalRuntime exact independently derived consumer status, errors, time or lock restoration failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>12
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleExternalRuntimeKeys] EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json) EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleExternalRuntimeKeys])
            THROW 56706,N'ExternalRuntime twelve named JSON properties or native types failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>(SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeExpectedSources])
           OR EXISTS(SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM [#ExampleExternalRuntimeExpectedSources]
                EXCEPT SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM OPENJSON(@Json,N'$.sourceStatus')
                WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(80) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount',[ErrorNumber] int '$.ErrorNumber'))
           OR EXISTS(SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM OPENJSON(@Json,N'$.sourceStatus')
                WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(80) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount',[ErrorNumber] int '$.ErrorNumber')
                EXCEPT SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM [#ExampleExternalRuntimeExpectedSources])
            THROW 56707,N'ExternalRuntime complete independent native source-code/count/status/error multiset failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>@OutputCount
           OR (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeExport])<>@OutputCount
            THROW 56708,N'ExternalRuntime independently expected finding filter or limit count failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeExport'))<>13
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeExport')
                     AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeExport')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeSchema'))
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeSchema')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleExternalRuntimeExport'))
            THROW 56709,N'ExternalRuntime independent thirteen-field TABLE schema or ten text collations failed.',1;
        EXEC [sys].[sp_executesql]
             N'SELECT @pJson=(SELECT * FROM [#ExampleExternalRuntimeExport] ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);',
             N'@pJson nvarchar(max) OUTPUT',@pJson=@TableJson OUTPUT;
        IF COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.findings'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56710,N'ExternalRuntime complete thirteen-field TABLE/JSON parity including existing NULL-property omission failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.findings') WITH([FindingOrdinal] bigint '$.FindingOrdinal',[Severity] varchar(16) '$.Severity',[Confidence] varchar(16) '$.Confidence',[Evidence] nvarchar(1000) '$.Evidence',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit',[RecommendedNextCheck] nvarchar(1000) '$.RecommendedNextCheck')
                  WHERE [FindingOrdinal] IS NULL OR [FindingOrdinal]<1 OR [Severity] IS NULL
                     OR [Confidence]<>CASE WHEN [Severity]='WARN' THEN 'HIGH' ELSE 'MEDIUM' END
                     OR NULLIF([Evidence],N'') IS NULL OR NULLIF([EvidenceLimit],N'') IS NULL OR NULLIF([RecommendedNextCheck],N'') IS NULL
                     OR (@Problems=1 AND [Severity]<>'WARN') OR (@SafeLimit=1 AND @ExpectedWarnCount>0 AND [Severity]<>'WARN'))
           OR (SELECT COUNT_BIG(DISTINCT [FindingOrdinal]) FROM OPENJSON(@Json,N'$.findings') WITH([FindingOrdinal] bigint '$.FindingOrdinal'))<>@OutputCount
            THROW 56711,N'ExternalRuntime preserved ordinals, severity/confidence, evidence or WARN priority failed.',1;
        IF EXISTS(SELECT [DatabaseName],[ObjectType],[ObjectName],[Severity],[FindingCode],[MetricName],[MetricValue],[ThresholdValue] FROM OPENJSON(@Json,N'$.findings')
                  WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[ObjectType] varchar(40) '$.ObjectType',[ObjectName] nvarchar(512) '$.ObjectName',[Severity] varchar(16) '$.Severity',[FindingCode] varchar(120) '$.FindingCode',[MetricName] varchar(80) '$.MetricName',[MetricValue] decimal(38,4) '$.MetricValue',[ThresholdValue] decimal(38,4) '$.ThresholdValue')
                  EXCEPT SELECT [DatabaseName],[ObjectType],[ObjectName],[Severity],[FindingCode],[MetricName],[MetricValue],[ThresholdValue] FROM [#ExampleExternalRuntimeExpectedFindings] WHERE @Problems=0 OR [Severity]='WARN')
           OR (@OutputCount=CASE WHEN @Problems=1 THEN @ExpectedWarnCount ELSE @ExpectedFindingCount END
               AND EXISTS(SELECT [DatabaseName],[ObjectType],[ObjectName],[Severity],[FindingCode],[MetricName],[MetricValue],[ThresholdValue] FROM [#ExampleExternalRuntimeExpectedFindings] WHERE @Problems=0 OR [Severity]='WARN'
                  EXCEPT SELECT [DatabaseName],[ObjectType],[ObjectName],[Severity],[FindingCode],[MetricName],[MetricValue],[ThresholdValue] FROM OPENJSON(@Json,N'$.findings') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[ObjectType] varchar(40) '$.ObjectType',[ObjectName] nvarchar(512) '$.ObjectName',[Severity] varchar(16) '$.Severity',[FindingCode] varchar(120) '$.FindingCode',[MetricName] varchar(80) '$.MetricName',[MetricValue] decimal(38,4) '$.MetricValue',[ThresholdValue] decimal(38,4) '$.ThresholdValue')))
            THROW 56712,N'ExternalRuntime independent native finding identities or metrics failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>(SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeSelected])+CASE WHEN @MissingName IS NULL THEN 0 ELSE 1 END
           OR EXISTS(SELECT [DatabaseName] FROM [#ExampleExternalRuntimeSelected]
                 EXCEPT SELECT [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName') WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@MissingName,N''))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[LanguageCount] bigint '$.LanguageCount',[LibraryCount] bigint '$.LibraryCount',[SourceFailureCount] int '$.SourceFailureCount') [d]
               WHERE [DatabaseName] IS NULL OR [StatusCode] IS NULL OR [IsPartial] IS NULL OR [LanguageCount] IS NULL OR [LibraryCount] IS NULL OR [SourceFailureCount] IS NULL
                  OR ([DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName AND ([StatusCode]<>'DATABASE_UNAVAILABLE' OR [IsPartial]<>1 OR [LanguageCount]<>0 OR [LibraryCount]<>0 OR [SourceFailureCount]<>1))
                  OR ([DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@MissingName,N'') AND
                     ([IsPartial]<>0 OR [SourceFailureCount]<>0 OR [LibraryCount]<>0
                      OR [LanguageCount]<>(SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeLanguages] [l] WHERE [l].[DatabaseName]=[d].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS)
                      OR [StatusCode]<>CASE WHEN EXISTS(SELECT 1 FROM [#ExampleExternalRuntimeNativeLanguages] [l] WHERE [l].[DatabaseName]=[d].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS) THEN 'AVAILABLE' ELSE 'NOT_APPLICABLE_VISIBLE_SCOPE' END)))
            THROW 56713,N'ExternalRuntime full native database counters, exact case selection or retained missing-selection status failed.',1;
        IF @MissingName IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial') WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1)
            THROW 56714,N'ExternalRuntime missing-selection row is absent.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.configuration'))<>CASE WHEN @Invalid=1 THEN 0 ELSE 1 END
           OR EXISTS(SELECT @Major,@Host,@Analytics,@ConfigValue,@ValueInUse,@Services,@Running,@LaunchStatus WHERE @Invalid=0
                EXCEPT SELECT [Major],[Host],[Analytics],[Configured],[InUse],[Services],[Running],[LaunchStatus] FROM OPENJSON(@Json,N'$.configuration')
                WITH([Major] int '$.ProductMajorVersion',[Host] nvarchar(60) '$.HostPlatform',[Analytics] int '$.IsAdvancedAnalyticsInstalled',[Configured] int '$.ExternalScriptsConfiguredValue',[InUse] int '$.ExternalScriptsValueInUse',[Services] int '$.LaunchpadServiceCount',[Running] int '$.LaunchpadRunningCount',[LaunchStatus] varchar(40) '$.LaunchpadStatus'))
            THROW 56715,N'ExternalRuntime independent native configuration and service parity failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.languages'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeLanguages])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeLanguages]) END
           OR EXISTS(SELECT [DatabaseName],[ExternalLanguageId],[LanguageName] FROM OPENJSON(@Json,N'$.languages') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[ExternalLanguageId] int '$.ExternalLanguageId',[LanguageName] nvarchar(128) '$.LanguageName')
                EXCEPT SELECT [DatabaseName],[LanguageId],[LanguageName] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleExternalRuntimeNativeLanguages] ORDER BY [DatabaseName],[LanguageName]) [n])
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.libraries')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.activeRequests'))
            THROW 56716,N'ExternalRuntime independent native language identities or no-library/no-request scope failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.externalPools'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativePools])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativePools]) END
           OR EXISTS(SELECT [Id],[Name],[Cpu],[Processes],[Memory],[Started] FROM OPENJSON(@Json,N'$.externalPools') WITH([Id] int '$.ExternalPoolId',[Name] nvarchar(128) '$.PoolName',[Cpu] int '$.MaxCpuPercent',[Processes] int '$.MaxProcesses',[Memory] int '$.MaxMemoryPercent',[Started] datetime '$.StatisticsStartTime')
                  EXCEPT SELECT [ExternalPoolId],[PoolName],[MaxCpuPercent],[MaxProcesses],[MaxMemoryPercent],[StatisticsStartTime] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleExternalRuntimeNativePools] ORDER BY [ActiveProcessesCount] DESC,[PoolName]) [n])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.executionStats'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeStats])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeStats]) END
           OR EXISTS(SELECT [Language],[Counter] FROM OPENJSON(@Json,N'$.executionStats') WITH([Language] nvarchar(128) '$.LanguageName',[Counter] nvarchar(256) '$.CounterName') EXCEPT SELECT [LanguageName],[CounterName] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleExternalRuntimeNativeStats] ORDER BY [LanguageName],[CounterName]) [n])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.performanceCounters'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeCounters])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleExternalRuntimeNativeCounters]) END
           OR EXISTS(SELECT [Counter],[Instance],[CounterType] FROM OPENJSON(@Json,N'$.performanceCounters') WITH([Counter] nvarchar(128) '$.CounterName',[Instance] nvarchar(128) '$.InstanceName',[CounterType] int '$.CounterType') EXCEPT SELECT [CounterName],[InstanceName],[CounterType] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleExternalRuntimeNativeCounters] ORDER BY [CounterName],[InstanceName]) [n])
            THROW 56717,N'ExternalRuntime native pool configuration or counter identities/counts failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.externalPools') WITH([DeltaStatus] varchar(40) '$.DeltaStatus',[SampleSeconds] decimal(19,6) '$.SampleSeconds',[CpuKernelDelta] bigint '$.CpuKernelDelta',[CpuUserDelta] bigint '$.CpuUserDelta',[ReadIoDelta] bigint '$.ReadIoDelta',[WriteIoDelta] bigint '$.WriteIoDelta')
                  WHERE [DeltaStatus]<>'NOT_SAMPLED' OR [SampleSeconds] IS NOT NULL OR [CpuKernelDelta] IS NOT NULL OR [CpuUserDelta] IS NOT NULL OR [ReadIoDelta] IS NOT NULL OR [WriteIoDelta] IS NOT NULL)
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.executionStats') WITH([DeltaStatus] varchar(40) '$.DeltaStatus',[CounterDelta] bigint '$.CounterDelta') WHERE [DeltaStatus]<>'NOT_SAMPLED' OR [CounterDelta] IS NOT NULL)
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.performanceCounters') WITH([DeltaStatus] varchar(40) '$.DeltaStatus',[CounterDelta] bigint '$.CounterDelta') WHERE [DeltaStatus]<>'NOT_SAMPLED' OR [CounterDelta] IS NOT NULL)
            THROW 56718,N'ExternalRuntime snapshot-only delta contract failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings'))<>1+CONVERT(int,@Truncated)+CASE WHEN UPPER(COALESCE(@Host,N''))=N'LINUX' THEN 1 ELSE 0 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode]='RESULTSET_TRUNCATED')<>CONVERT(int,@Truncated)
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode]='EXECUTION_STATS_SCOPE')
           OR (UPPER(COALESCE(@Host,N''))=N'LINUX' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode]='LINUX_EXTERNAL_POOL_UNIT_CONTRACT'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode] NOT IN('EXECUTION_STATS_SCOPE','LINUX_EXTERNAL_POOL_UNIT_CONTRACT','RESULTSET_TRUNCATED'))
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedUpper)<>@FrameworkLevel
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedLower)<>@FrameworkLevel
            THROW 56719,N'ExternalRuntime existing warning boundary or separately measured framework/source levels failed.',1;
        IF @ExpectedFindingCount>0 SET @PositiveFindingCases+=1;
        DROP TABLE [#ExampleExternalRuntimeExport];
        SET @Case+=1;
    END;
    /* Native RAW/CONSOLE-Zeilen werden nicht separat abgefangen. Diese vier Aufrufe
       prüfen ihren Consumerstatus und die begleitende JSON-Findinganzahl. */
    WHILE @Route<4
    BEGIN
        SELECT @Mode=CASE WHEN @Route IN(0,2) THEN 'RAW' ELSE 'CONSOLE' END,
               @Limit=CASE WHEN @Route<2 THEN 1 ELSE -1 END,@Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_ExternalRuntimeAnalysis] @DatabaseNames=N'[ExampleExternalRuntimeÄ]|[exampleExternalRuntimeÄ]',@NurProblematisch=1,@MaxZeilen=@Limit,
             @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>CASE WHEN @Route<2 THEN @BaselineStatus ELSE 'INVALID_PARAMETER' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Route<2 THEN CONVERT(int,@BaselinePartial) ELSE 1 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>CASE WHEN @Route<2 AND @BaselineWarnCount>0 THEN 1 ELSE 0 END
            THROW 56720,N'ExternalRuntime RAW/CONSOLE status or accompanying JSON finding count failed.',1;
        SET @Route+=1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleExternalRuntimeÄ')=@OwnedUpper
    BEGIN
        ALTER DATABASE [ExampleExternalRuntimeÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleExternalRuntimeÄ];
    END;
    IF DB_ID(N'exampleExternalRuntimeÄ')=@OwnedLower
    BEGIN
        ALTER DATABASE [exampleExternalRuntimeÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [exampleExternalRuntimeÄ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@LevelUpper AS [FirstSourceCompatibilityLevel],
           @LevelLower AS [SecondSourceCompatibilityLevel],@Case AS [TableJsonCases],@Route AS [RawConsoleStatusCases],
           @PositiveFindingCases AS [NonemptyNativeFindingCases],
           CASE WHEN @PositiveFindingCases>0 THEN N'Eigene native Katalogidentitäten und vorhandene Findings geprüft; externe Ausführung und Startfähigkeit bleiben unbelegt.'
                ELSE N'Eigener nativer Leerscope geprüft; positive Findingsfilter-/Limitwirkung und externe Ausführung bleiben unbelegt.' END AS [Detail];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','ExampleExternalRuntimeNativeCursor')>=0 CLOSE [ExampleExternalRuntimeNativeCursor];
    IF CURSOR_STATUS('local','ExampleExternalRuntimeNativeCursor')>-3 DEALLOCATE [ExampleExternalRuntimeNativeCursor];
    IF CURSOR_STATUS('local','ExampleExternalRuntimeDatabaseCursor')>=0 CLOSE [ExampleExternalRuntimeDatabaseCursor];
    IF CURSOR_STATUS('local','ExampleExternalRuntimeDatabaseCursor')>-3 DEALLOCATE [ExampleExternalRuntimeDatabaseCursor];
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedUpper IS NOT NULL AND DB_ID(N'ExampleExternalRuntimeÄ')=@OwnedUpper
    BEGIN
        ALTER DATABASE [ExampleExternalRuntimeÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleExternalRuntimeÄ];
    END;
    IF @OwnedLower IS NOT NULL AND DB_ID(N'exampleExternalRuntimeÄ')=@OwnedLower
    BEGIN
        ALTER DATABASE [exampleExternalRuntimeÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [exampleExternalRuntimeÄ];
    END;
    THROW;
END CATCH;
GO
