USE [DeineDatenbank];
GO
/* Prüft zwei eigene leere case-unterschiedliche Unicode-CI_AS-Datenbanken ohne
   Assemblyregistrierung, CLR-Ausführung oder Konfigurations-/Truständerung.
   Native Konfiguration, Hostproperties und Quellenanzahlen sind unabhängig
   gegengeprüft. Memory-Clerk-Identitäten und Anzahlen sowie Counteridentitäten,
   Typen und Sample-0-Interpretation werden auch bei nichtleeren Mengen geprüft;
   veränderliche Speicher- und Counterwerte sind kein atomarer Punktvergleich.
   Leere Findings prüfen Schema, Ausgabeparität und Filter-/Limitakzeptanz,
   keine positive Filter-/Limitwirkung. RAW/CONSOLE prüfen nur Status und JSON.
   Framework und beide Quellen bestätigen getrennt den Level 150/160/170. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleClrÄ') IS NOT NULL OR DB_ID(N'exampleClrÄ') IS NOT NULL
   OR DB_ID(N'ExampleClrMissingß') IS NOT NULL
    THROW 56800,N'CLR fixture or missing-selection name already exists.',1;
DECLARE @OwnedUpper int=NULL,@OwnedLower int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @Host nvarchar(60)=TRY_CONVERT(nvarchar(60),SERVERPROPERTY(N'HostPlatform')),
        @LevelUpper int,@LevelLower int,@Sql nvarchar(max),@Query nvarchar(max),@NativeRows bigint,@NativeError int,
        @SourceCode varchar(80),@Db nvarchar(128),@Case int=0,@Route int=0,@Mode varchar(16),
        @Names nvarchar(max),@DbPattern nvarchar(4000),@AssemblyNames nvarchar(max),@AssemblyPattern nvarchar(4000),
        @Limit int,@SafeLimit bigint,@Problems bit,@Sample tinyint,@Timeout int,@Modules bit,@Invalid bit,
        @MissingName nvarchar(128),@ExpectedStatus varchar(40),@ExpectedPartial bit,
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048),
        @TableJson nvarchar(max),@Before datetime2(3),@After datetime2(3),
        @ClrConfigured int,@ClrInUse int,@StrictConfigured int,@StrictInUse int,@PoolingConfigured int,@PoolingInUse int,
        @BaselineStatus varchar(40),@BaselinePartial bit;
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 56801,N'CLR framework level is outside the contract.',1;
IF @Major IS NULL OR @Major<15 THROW 56802,N'CLR needs a visible SQL Server 2019 or newer version.',1;
CREATE TABLE [#ExampleClrSchema]
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
CREATE TABLE [#ExampleClrSelected]
  ([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[IsTrustworthyOn] bit NOT NULL);
CREATE TABLE [#ExampleClrNativeProperties]
  ([PropertyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PropertyValue] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE [#ExampleClrNativeMemory]
  ([MemoryClerkType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ClerkCount] bigint NOT NULL);
CREATE TABLE [#ExampleClrNativeCounters]
  ([CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterType] int NOT NULL);
CREATE TABLE [#ExampleClrExpectedSources]
  ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[ErrorNumber] int NULL);
CREATE TABLE [#ExampleClrNativeQueries]
  ([SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT [#ExampleClrNativeQueries] VALUES
('CLR_PROPERTIES',N'INSERT [#ExampleClrNativeProperties] SELECT [name],[value] FROM [sys].[dm_clr_properties] WHERE [name] IN(N''state'',N''version''); SET @pRows=@@ROWCOUNT;'),
('CLR_APPDOMAINS',N'SELECT @pRows=COUNT_BIG(*) FROM [sys].[dm_clr_appdomains] [a] JOIN [#ExampleClrSelected] [d] ON [d].[DatabaseId]=[a].[db_id];'),
('CLR_LOADED_ASSEMBLIES',N'SELECT @pRows=COUNT_BIG(*) FROM [sys].[dm_clr_loaded_assemblies] [l] JOIN [sys].[dm_clr_appdomains] [a] ON [a].[appdomain_address]=[l].[appdomain_address] JOIN [#ExampleClrSelected] [d] ON [d].[DatabaseId]=[a].[db_id];'),
('CLR_TASKS',N'SELECT @pRows=COUNT_BIG(*) FROM [sys].[dm_clr_tasks] [t] JOIN [sys].[dm_clr_appdomains] [a] ON [a].[appdomain_address]=[t].[appdomain_address] JOIN [#ExampleClrSelected] [d] ON [d].[DatabaseId]=[a].[db_id];'),
('MANAGED_CODE_REQUESTS',N'SELECT @pRows=COUNT_BIG(*) FROM [sys].[dm_exec_requests] [r] JOIN [#ExampleClrSelected] [d] ON [d].[DatabaseId]=[r].[database_id] WHERE [r].[executing_managed_code]=1;'),
('CLR_MEMORY_CLERKS',N'INSERT [#ExampleClrNativeMemory] SELECT [type],COUNT_BIG(*) FROM [sys].[dm_os_memory_clerks] WHERE [type] IN(N''MEMORYCLERK_SQLCLR'',N''MEMORYCLERK_SQLCLRASSEMBLY'') GROUP BY [type]; SET @pRows=@@ROWCOUNT;'),
('CLR_COUNTERS_T1',N'INSERT [#ExampleClrNativeCounters] SELECT [counter_name],[instance_name],[cntr_type] FROM [sys].[dm_os_performance_counters] WHERE [object_name] LIKE N''%:CLR%''; SET @pRows=@@ROWCOUNT;');
CREATE TABLE [#ExampleClrKeys]
 ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[JsonType] int NOT NULL);
INSERT [#ExampleClrKeys] VALUES
 (N'meta',5),(N'configuration',4),(N'databaseStatus',4),(N'sourceStatus',4),(N'findings',4),(N'assemblies',4),
 (N'assemblyModules',4),(N'assemblyDependencies',4),(N'clrProperties',4),(N'appDomains',4),(N'loadedAssemblies',4),
 (N'clrTasks',4),(N'activeRequests',4),(N'memory',4),(N'performanceCounters',4),(N'warnings',4);
CREATE TABLE [#ExampleClrMetaKeys]
 ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[JsonType] int NOT NULL);
INSERT [#ExampleClrMetaKeys] VALUES (N'module',1),(N'collectedAtUtc',1),(N'measurementStartUtc',1),
 (N'measurementEndUtc',1),(N'statusCode',1),(N'isPartial',3),(N'errorNumber',2),(N'errorMessage',1);
BEGIN TRY
    DECLARE @DataPath nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultDataPath')),
            @LogPath nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultLogPath')),
            @FixtureSuffix nvarchar(36)=CONVERT(nvarchar(36),NEWID());
    IF NULLIF(@DataPath,N'') IS NULL OR NULLIF(@LogPath,N'') IS NULL
        THROW 56821,N'Clr fixture default data or log directory unavailable.',1;
    IF RIGHT(@DataPath,1) NOT IN(N'/',NCHAR(92))
        SET @DataPath+=CASE WHEN CHARINDEX(N'/',@DataPath)>0 THEN N'/' ELSE NCHAR(92) END;
    IF RIGHT(@LogPath,1) NOT IN(N'/',NCHAR(92))
        SET @LogPath+=CASE WHEN CHARINDEX(N'/',@LogPath)>0 THEN N'/' ELSE NCHAR(92) END;
    SET @Sql=N'CREATE DATABASE [ExampleClrÄ] ON PRIMARY
(NAME=N''ExampleClrUpperData'',FILENAME=N'''+REPLACE(@DataPath+N'ExampleClrUpper-'+@FixtureSuffix+N'.mdf',N'''',N'''''')+N''')
LOG ON (NAME=N''ExampleClrUpperLog'',FILENAME=N'''+REPLACE(@LogPath+N'ExampleClrUpper-'+@FixtureSuffix+N'.ldf',N'''',N'''''')+N''') COLLATE Latin1_General_100_CI_AS;';
    EXEC(@Sql);
    SET @OwnedUpper=DB_ID(N'ExampleClrÄ');
    SET @Sql=N'CREATE DATABASE [exampleClrÄ] ON PRIMARY
(NAME=N''ExampleClrLowerData'',FILENAME=N'''+REPLACE(@DataPath+N'ExampleClrLower-'+@FixtureSuffix+N'.mdf',N'''',N'''''')+N''')
LOG ON (NAME=N''ExampleClrLowerLog'',FILENAME=N'''+REPLACE(@LogPath+N'ExampleClrLower-'+@FixtureSuffix+N'.ldf',N'''',N'''''')+N''') COLLATE Latin1_General_100_CI_AS;';
    EXEC(@Sql);
    SET @OwnedLower=DB_ID(N'exampleClrÄ');
    SET @Sql=N'ALTER DATABASE [ExampleClrÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N'; ALTER DATABASE [exampleClrÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';'; EXEC(@Sql);
    SELECT @LevelUpper=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedUpper;
    SELECT @LevelLower=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedLower;
    IF @OwnedUpper IS NULL OR @OwnedLower IS NULL OR @OwnedUpper=@OwnedLower
       OR @LevelUpper<>@FrameworkLevel OR @LevelLower<>@FrameworkLevel
       OR EXISTS(SELECT 1 FROM [sys].[databases] WHERE [database_id] IN(@OwnedUpper,@OwnedLower)
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS')
        THROW 56803,N'Clr own identities, explicit source levels or CI_AS collations failed.',1;
    WHILE @Case<24
    BEGIN
        SELECT @Limit=CASE WHEN @Case=0 THEN NULL WHEN @Case IN(2,3) THEN 1 WHEN @Case=5 THEN 100 WHEN @Case=13 THEN -1 ELSE 0 END,
               @SafeLimit=CASE WHEN @Case IN(2,3) THEN 1 WHEN @Case=5 THEN 100 WHEN @Case=13 THEN 0 ELSE CONVERT(bigint,9223372036854775807) END,
               @Problems=CASE WHEN @Case IN(3,4) THEN 1 WHEN @Case=18 THEN NULL ELSE 0 END,
               @Sample=CASE WHEN @Case=14 THEN NULL WHEN @Case=15 THEN 61 ELSE 0 END,
               @Timeout=CASE WHEN @Case=16 THEN NULL WHEN @Case=17 THEN -1 ELSE 4321 END,
               @Modules=CASE WHEN @Case=22 THEN 0 WHEN @Case=23 THEN NULL ELSE 1 END,
               @AssemblyNames=CASE WHEN @Case IN(6,20) THEN N'[ExampleUnusedAssemblyÄ]' WHEN @Case=19 THEN N'[ExampleUnclosed' ELSE NULL END,
               @AssemblyPattern=CASE WHEN @Case IN(7,20) THEN N'like:ExampleUnusedAssemblyÄ' ELSE NULL END,
               @Names=CASE WHEN @Case=8 THEN N'[ExampleClrÄ]' WHEN @Case=9 THEN N'[exampleClrÄ]'
                           WHEN @Case=10 THEN N'[ExampleClrÄ]|[ExampleClrMissingß]' WHEN @Case=11 THEN N'[ExampleClrMissingß]'
                           WHEN @Case=12 THEN N'[EXAMPLEClrÄ]' ELSE N'[ExampleClrÄ]|[exampleClrÄ]' END,
               @MissingName=CASE WHEN @Case IN(10,11) THEN N'ExampleClrMissingß' WHEN @Case=12 THEN N'EXAMPLEClrÄ' ELSE NULL END,
               @DbPattern=CASE WHEN @Case=21 THEN N'like:ExampleClr%' ELSE NULL END,
               @Invalid=CASE WHEN @Case BETWEEN 13 AND 21 OR @Case=23 THEN 1 ELSE 0 END;
        DELETE [#ExampleClrSelected]; DELETE [#ExampleClrNativeProperties]; DELETE [#ExampleClrNativeMemory];
        DELETE [#ExampleClrNativeCounters]; DELETE [#ExampleClrExpectedSources];
        SELECT @ClrConfigured=NULL,@ClrInUse=NULL,@StrictConfigured=NULL,@StrictInUse=NULL,@PoolingConfigured=NULL,@PoolingInUse=NULL;
        IF @Invalid=0
        BEGIN
            INSERT [#ExampleClrSelected]
            SELECT [database_id],[name],[is_trustworthy_on] FROM [sys].[databases]
            WHERE ([database_id]=@OwnedUpper AND @Case NOT IN(9,11,12))
               OR ([database_id]=@OwnedLower AND @Case NOT IN(8,10,11,12));
            SELECT @ClrConfigured=MAX(CASE WHEN [name]=N'clr enabled' THEN TRY_CONVERT(int,[value]) END),
                   @ClrInUse=MAX(CASE WHEN [name]=N'clr enabled' THEN TRY_CONVERT(int,[value_in_use]) END),
                   @StrictConfigured=MAX(CASE WHEN [name]=N'clr strict security' THEN TRY_CONVERT(int,[value]) END),
                   @StrictInUse=MAX(CASE WHEN [name]=N'clr strict security' THEN TRY_CONVERT(int,[value_in_use]) END),
                   @PoolingConfigured=MAX(CASE WHEN [name]=N'lightweight pooling' THEN TRY_CONVERT(int,[value]) END),
                   @PoolingInUse=MAX(CASE WHEN [name]=N'lightweight pooling' THEN TRY_CONVERT(int,[value_in_use]) END)
            FROM [sys].[configurations] WHERE [name] IN(N'clr enabled',N'clr strict security',N'lightweight pooling');
            IF @ClrInUse IS NULL OR @ClrInUse<>0 OR @StrictInUse IS NULL OR @StrictInUse<>1
                THROW 56804,N'CLR native configuration exceeds this disabled-CLR no-finding fixture contract.',1;
            INSERT [#ExampleClrExpectedSources] VALUES(NULL,'CLR_CONFIGURATION','AVAILABLE',0,1,NULL);
            DECLARE [ExampleClrNativeCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [SourceCode],[QueryText] FROM [#ExampleClrNativeQueries];
            OPEN [ExampleClrNativeCursor]; FETCH NEXT FROM [ExampleClrNativeCursor] INTO @SourceCode,@Query;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @NativeRows=0;
                BEGIN TRY
                    EXEC [sys].[sp_executesql] @Query,N'@pRows bigint OUTPUT',@pRows=@NativeRows OUTPUT;
                    INSERT [#ExampleClrExpectedSources] VALUES(NULL,@SourceCode,'AVAILABLE',0,@NativeRows,NULL);
                END TRY
                BEGIN CATCH
                    SET @NativeError=ERROR_NUMBER();
                    INSERT [#ExampleClrExpectedSources] VALUES(NULL,@SourceCode,
                        CASE WHEN @NativeError IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@NativeError);
                END CATCH;
                FETCH NEXT FROM [ExampleClrNativeCursor] INTO @SourceCode,@Query;
            END;
            CLOSE [ExampleClrNativeCursor]; DEALLOCATE [ExampleClrNativeCursor];
            DECLARE [ExampleClrDatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#ExampleClrSelected];
            OPEN [ExampleClrDatabaseCursor]; FETCH NEXT FROM [ExampleClrDatabaseCursor] INTO @Db;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @Sql=N'SELECT @pRows=COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[assemblies] WHERE [is_user_defined]=1;';
                EXEC [sys].[sp_executesql] @Sql,N'@pRows bigint OUTPUT',@pRows=@NativeRows OUTPUT;
                IF @NativeRows<>0 THROW 56804,N'CLR own fixture contains unexpected user assemblies.',1;
                INSERT [#ExampleClrExpectedSources] VALUES(@Db,'CLR_ASSEMBLIES','AVAILABLE',0,@NativeRows,NULL);
                /* Die Gegenprobe prüft beide Kataloge auch beim ausgeschalteten Modulpfad. */
                SET @Sql=N'SELECT @pRows=COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[assembly_modules] [m] JOIN '+QUOTENAME(@Db)+N'.[sys].[assemblies] [a] ON [a].[assembly_id]=[m].[assembly_id] WHERE [a].[is_user_defined]=1;';
                EXEC [sys].[sp_executesql] @Sql,N'@pRows bigint OUTPUT',@pRows=@NativeRows OUTPUT;
                IF @NativeRows<>0 THROW 56804,N'CLR own fixture contains unexpected assembly modules.',1;
                IF @Modules=1 INSERT [#ExampleClrExpectedSources] VALUES(@Db,'CLR_ASSEMBLY_MODULES','AVAILABLE',0,@NativeRows,NULL);
                SET @Sql=N'SELECT @pRows=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[assembly_references] [r] JOIN '+QUOTENAME(@Db)+N'.[sys].[assemblies] [a] ON [a].[assembly_id]=[r].[assembly_id] WHERE [a].[is_user_defined]=1)+(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@Db)+N'.[sys].[assembly_types] [t] JOIN '+QUOTENAME(@Db)+N'.[sys].[assemblies] [a] ON [a].[assembly_id]=[t].[assembly_id] WHERE [a].[is_user_defined]=1);';
                EXEC [sys].[sp_executesql] @Sql,N'@pRows bigint OUTPUT',@pRows=@NativeRows OUTPUT;
                IF @NativeRows<>0 THROW 56804,N'CLR own fixture contains unexpected assembly dependencies.',1;
                IF @Modules=1 INSERT [#ExampleClrExpectedSources] VALUES(@Db,'CLR_ASSEMBLY_DEPENDENCIES','AVAILABLE',0,@NativeRows,NULL);
                FETCH NEXT FROM [ExampleClrDatabaseCursor] INTO @Db;
            END;
            CLOSE [ExampleClrDatabaseCursor]; DEALLOCATE [ExampleClrDatabaseCursor];
            IF EXISTS(SELECT 1 FROM [#ExampleClrExpectedSources] WHERE [SourceCode] IN('CLR_APPDOMAINS','CLR_LOADED_ASSEMBLIES','CLR_TASKS','MANAGED_CODE_REQUESTS') AND [RowCount]<>0)
               OR EXISTS(SELECT 1 FROM [#ExampleClrNativeProperties] WHERE [PropertyName]=N'state' AND [PropertyValue] LIKE N'%permanently failed%')
                THROW 56804,N'CLR native runtime scope exceeds the no-execution no-finding fixture contract.',1;
        END;
        SELECT @ExpectedPartial=CONVERT(bit,CASE WHEN @Invalid=1 OR @MissingName IS NOT NULL OR EXISTS(SELECT 1 FROM [#ExampleClrExpectedSources] WHERE [IsPartial]=1) THEN 1 ELSE 0 END),
               @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER'
                   WHEN @MissingName IS NOT NULL OR EXISTS(SELECT 1 FROM [#ExampleClrExpectedSources] WHERE [IsPartial]=1) THEN 'AVAILABLE_LIMITED' ELSE 'NOT_APPLICABLE' END,
               @Json=NULL,@Status=NULL,@Partial=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,@TableJson=NULL,@Before=SYSUTCDATETIME();
        IF @Case=1 SELECT @BaselineStatus=@ExpectedStatus,@BaselinePartial=@ExpectedPartial;
        CREATE TABLE [#ExampleClrExport]([Dummy] int NULL);
        EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=@Names,@DatabaseNamePattern=@DbPattern,
             @AssemblyNames=@AssemblyNames,@AssemblyNamePattern=@AssemblyPattern,@SampleSeconds=@Sample,
             @MitModulzuordnung=@Modules,@NurProblematisch=@Problems,@MaxZeilen=@Limit,@LockTimeoutMs=@Timeout,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleClrExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
             @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        SET @After=SYSUTCDATETIME();
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus OR COALESCE(CONVERT(int,@Partial),-1)<>CONVERT(int,@ExpectedPartial)
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),'')<>CASE WHEN @ExpectedPartial=1 THEN 'true' ELSE 'false' END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.module'),'')<>'USP_ClrAnalysis'
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.collectedAtUtc')) IS NULL
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.collectedAtUtc')) NOT BETWEEN @Before AND @After
           OR @@LOCK_TIMEOUT<>@OriginalLockTimeout
           OR COALESCE(@ErrorNumber,-1)<>COALESCE((SELECT MIN([ErrorNumber]) FROM [#ExampleClrExpectedSources] WHERE [IsPartial]=1),-1)
            THROW 56805,N'CLR exact independently derived consumer status, errors, time or lock restoration failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>16
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleClrKeys] EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json) EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleClrKeys])
            THROW 56806,N'CLR sixteen named JSON properties or native types failed.',1;
        IF EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleClrMetaKeys])
           OR (SELECT COUNT_BIG(DISTINCT [key]) FROM OPENJSON(@Json,N'$.meta'))<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.meta'))
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.meta'))<>4+CASE WHEN @Invalid=0 THEN 2 ELSE 0 END+CASE WHEN @ErrorNumber IS NULL THEN 0 ELSE 1 END+CASE WHEN @ErrorMessage IS NULL THEN 0 ELSE 1 END
           OR (@Invalid=0 AND (TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.measurementStartUtc')) IS NULL
                OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.measurementEndUtc')) IS NULL
                OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.measurementStartUtc')) NOT BETWEEN @Before AND @After
                OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.measurementEndUtc')) NOT BETWEEN TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.measurementStartUtc')) AND @After))
           OR (@Invalid=1 AND (JSON_VALUE(@Json,N'$.meta.measurementStartUtc') IS NOT NULL OR JSON_VALUE(@Json,N'$.meta.measurementEndUtc') IS NOT NULL))
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.errorNumber')),-1)<>COALESCE(@ErrorNumber,-1)
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.errorMessage'),N'')<>COALESCE(@ErrorMessage,N'')
           OR (@Invalid=1 AND NULLIF(@ErrorMessage,N'') IS NULL)
            THROW 56807,N'CLR eight-field meta contract, native JSON types, NULL omission or measurement interval failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>(SELECT COUNT_BIG(*) FROM [#ExampleClrExpectedSources])
           OR EXISTS(SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM [#ExampleClrExpectedSources]
                EXCEPT SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM OPENJSON(@Json,N'$.sourceStatus')
                WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(80) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount',[ErrorNumber] int '$.ErrorNumber'))
           OR EXISTS(SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM OPENJSON(@Json,N'$.sourceStatus')
                WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(80) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount',[ErrorNumber] int '$.ErrorNumber')
                EXCEPT SELECT [DatabaseName],[SourceCode],[StatusCode],[IsPartial],[RowCount],[ErrorNumber] FROM [#ExampleClrExpectedSources])
            THROW 56808,N'Clr complete independent native source-code/count/status/error multiset failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.findings')) OR EXISTS(SELECT 1 FROM [#ExampleClrExport])
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblies')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblyModules'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblyDependencies')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.appDomains'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.loadedAssemblies')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.clrTasks'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.activeRequests'))
            THROW 56809,N'CLR native no-assembly/no-runtime finding scope or empty filter/limit acceptance failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrExport'))<>13
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrExport')
                     AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrExport')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrSchema'))
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrSchema')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleClrExport'))
            THROW 56810,N'Clr independent thirteen-field TABLE schema or ten text collations failed.',1;
        EXEC [sys].[sp_executesql]
             N'SELECT @pJson=(SELECT * FROM [#ExampleClrExport] ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);',
             N'@pJson nvarchar(max) OUTPUT',@pJson=@TableJson OUTPUT;
        IF COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.findings'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56811,N'Clr complete thirteen-field TABLE/JSON parity including existing NULL-property omission failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>(SELECT COUNT_BIG(*) FROM [#ExampleClrSelected])+CASE WHEN @MissingName IS NULL THEN 0 ELSE 1 END
           OR EXISTS(SELECT [DatabaseName] FROM [#ExampleClrSelected]
                EXCEPT SELECT [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName') WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@MissingName,N''))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus')
                WITH([DatabaseId] int '$.DatabaseId',[DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[IsTrustworthyOn] bit '$.IsTrustworthyOn',[AssemblyCount] bigint '$.AssemblyCount',[HighPermissionAssemblyCount] bigint '$.HighPermissionAssemblyCount',[ModuleCount] bigint '$.ModuleCount',[SourceFailureCount] int '$.SourceFailureCount') [d]
                WHERE [DatabaseName] IS NULL OR [StatusCode] IS NULL OR [IsPartial] IS NULL OR [AssemblyCount] IS NULL OR [HighPermissionAssemblyCount] IS NULL OR [ModuleCount] IS NULL OR [SourceFailureCount] IS NULL
                   OR [AssemblyCount]<>0 OR [HighPermissionAssemblyCount]<>0 OR [ModuleCount]<>0
                   OR ([DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName AND ([DatabaseId] IS NOT NULL OR [IsTrustworthyOn] IS NOT NULL OR [StatusCode]<>'DATABASE_UNAVAILABLE' OR [IsPartial]<>1 OR [SourceFailureCount]<>1))
                   OR ([DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@MissingName,N'') AND
                       ([StatusCode]<>'NOT_APPLICABLE_VISIBLE_SCOPE' OR [IsPartial]<>0 OR [SourceFailureCount]<>0 OR [DatabaseId] IS NULL OR [IsTrustworthyOn] IS NULL
                        OR NOT EXISTS(SELECT 1 FROM [#ExampleClrSelected] [s] WHERE [s].[DatabaseName]=[d].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS AND [s].[DatabaseId]=[d].[DatabaseId] AND [s].[IsTrustworthyOn]=[d].[IsTrustworthyOn]))))
           OR (@MissingName IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial') WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1))
            THROW 56812,N'CLR native database identities/counters or retained case/missing-selection partial status failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.configuration'))<>CASE WHEN @Invalid=1 THEN 0 ELSE 1 END
           OR EXISTS(SELECT @Major,@Host,@ClrConfigured,@ClrInUse,@StrictConfigured,@StrictInUse,@PoolingConfigured,@PoolingInUse,
                          CONVERT(bigint,NULL),CONVERT(varchar(40),'NOT_REQUESTED'),
                          CONVERT(nvarchar(128),CASE WHEN @Major>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END) WHERE @Invalid=0
                EXCEPT SELECT [Major],[Host],[ClrConfigured],[ClrInUse],[StrictConfigured],[StrictInUse],[PoolingConfigured],[PoolingInUse],[TrustedCount],[TrustedStatus],[Permission]
                FROM OPENJSON(@Json,N'$.configuration')
                WITH([Major] int '$.ProductMajorVersion',[Host] nvarchar(60) '$.HostPlatform',[ClrConfigured] int '$.ClrEnabledConfiguredValue',[ClrInUse] int '$.ClrEnabledValueInUse',[StrictConfigured] int '$.ClrStrictSecurityConfiguredValue',[StrictInUse] int '$.ClrStrictSecurityValueInUse',[PoolingConfigured] int '$.LightweightPoolingConfiguredValue',[PoolingInUse] int '$.LightweightPoolingValueInUse',[TrustedCount] bigint '$.TrustedAssemblyCount',[TrustedStatus] varchar(40) '$.TrustedAssemblyStatus',[Permission] nvarchar(128) '$.RequiredPerformancePermission'))
            THROW 56813,N'CLR independently observed native configuration or excluded Trust opt-in failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.clrProperties'))<>(SELECT COUNT_BIG(*) FROM [#ExampleClrNativeProperties])
           OR EXISTS(SELECT [PropertyName],[PropertyValue] FROM [#ExampleClrNativeProperties]
                EXCEPT SELECT [PropertyName],[PropertyValue] FROM OPENJSON(@Json,N'$.clrProperties') WITH([PropertyName] nvarchar(128) '$.PropertyName',[PropertyValue] nvarchar(128) '$.PropertyValue'))
           OR EXISTS(SELECT [PropertyName],[PropertyValue] FROM OPENJSON(@Json,N'$.clrProperties') WITH([PropertyName] nvarchar(128) '$.PropertyName',[PropertyValue] nvarchar(128) '$.PropertyValue')
                EXCEPT SELECT [PropertyName],[PropertyValue] FROM [#ExampleClrNativeProperties])
            THROW 56814,N'CLR independent native state/version property names and values failed.',1;
        /* Variable Speicherwerte werden nicht auf einen früheren Messpunkt gesetzt. */
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.memory'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleClrNativeMemory])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleClrNativeMemory]) END
           OR EXISTS(SELECT [Type],[Count] FROM OPENJSON(@Json,N'$.memory') WITH([Type] nvarchar(60) '$.MemoryClerkType',[Count] bigint '$.ClerkCount')
                EXCEPT SELECT [MemoryClerkType],[ClerkCount] FROM [#ExampleClrNativeMemory])
           OR (@SafeLimit>=(SELECT COUNT_BIG(*) FROM [#ExampleClrNativeMemory]) AND EXISTS(SELECT [MemoryClerkType],[ClerkCount] FROM [#ExampleClrNativeMemory]
                EXCEPT SELECT [Type],[Count] FROM OPENJSON(@Json,N'$.memory') WITH([Type] nvarchar(60) '$.MemoryClerkType',[Count] bigint '$.ClerkCount')))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.memory')
                WITH([Pages] bigint '$.PagesKb',[Reserved] bigint '$.VirtualMemoryReservedKb',[Committed] bigint '$.VirtualMemoryCommittedKb',[SharedReserved] bigint '$.SharedMemoryReservedKb',[SharedCommitted] bigint '$.SharedMemoryCommittedKb')
                WHERE [Pages] IS NULL OR [Pages]<0 OR [Reserved] IS NULL OR [Reserved]<0 OR [Committed] IS NULL OR [Committed]<0 OR [SharedReserved] IS NULL OR [SharedReserved]<0 OR [SharedCommitted] IS NULL OR [SharedCommitted]<0)
            THROW 56815,N'CLR native memory identities/counts or nonnegative numeric snapshot values failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.performanceCounters'))<>CASE WHEN (SELECT COUNT_BIG(*) FROM [#ExampleClrNativeCounters])>@SafeLimit THEN @SafeLimit ELSE (SELECT COUNT_BIG(*) FROM [#ExampleClrNativeCounters]) END
           OR EXISTS(SELECT [Counter],[Instance],[CounterType] FROM OPENJSON(@Json,N'$.performanceCounters') WITH([Counter] nvarchar(128) '$.CounterName',[Instance] nvarchar(128) '$.InstanceName',[CounterType] int '$.CounterType')
                EXCEPT SELECT [CounterName],[InstanceName],[CounterType] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleClrNativeCounters] ORDER BY [CounterName],[InstanceName]) [n])
           OR EXISTS(SELECT [CounterName],[InstanceName],[CounterType] FROM (SELECT TOP(@SafeLimit) * FROM [#ExampleClrNativeCounters] ORDER BY [CounterName],[InstanceName]) [n]
                EXCEPT SELECT [Counter],[Instance],[CounterType] FROM OPENJSON(@Json,N'$.performanceCounters') WITH([Counter] nvarchar(128) '$.CounterName',[Instance] nvarchar(128) '$.InstanceName',[CounterType] int '$.CounterType'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.performanceCounters')
                WITH([CounterType] int '$.CounterType',[CounterValue] bigint '$.CounterValue',[Interpretation] varchar(40) '$.Interpretation',[MetricValue] decimal(38,6) '$.MetricValue',[MetricUnit] varchar(40) '$.MetricUnit',[FindingCode] varchar(80) '$.FindingCode') [p]
                WHERE [CounterType] IS NULL OR [CounterValue] IS NULL OR [Interpretation] IS NULL OR [MetricUnit] IS NULL OR [FindingCode] IS NULL
                   OR [Interpretation]<>CASE WHEN [CounterType]=65792 THEN 'RAW_SNAPSHOT' WHEN [CounterType] IN(272696320,272696576) THEN 'RATE_PER_SECOND' WHEN [CounterType]=537003264 THEN 'FRACTION_DELTA_PERCENT' WHEN [CounterType]=1073874176 THEN 'AVERAGE_DELTA_RATIO' ELSE 'RAW_UNINTERPRETED' END
                   OR [MetricUnit]<>CASE WHEN [CounterType] IN(272696320,272696576) THEN 'PER_SECOND' WHEN [CounterType]=537003264 THEN 'PERCENT' WHEN [CounterType]=1073874176 THEN 'AVERAGE' WHEN [CounterType]=65792 THEN 'RAW_VALUE' ELSE 'RAW_UNINTERPRETED' END
                   OR ([CounterType] IN(272696320,272696576,537003264,1073874176) AND ([MetricValue] IS NOT NULL OR [FindingCode]<>'SAMPLE_REQUIRED_FOR_DELTA_METRIC'))
                   OR ([CounterType] NOT IN(272696320,272696576,537003264,1073874176) AND ([MetricValue] IS NULL OR [MetricValue]<>CONVERT(decimal(38,6),[CounterValue]) OR [FindingCode]<>CASE WHEN [CounterType]=65792 THEN 'VALUE_AVAILABLE' ELSE 'COUNTER_TYPE_NOT_AUTOMATICALLY_INTERPRETED' END)))
            THROW 56816,N'CLR native counter identities/types/counts or independently expected Sample-0 interpretation failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings'))<>1+CASE WHEN UPPER(COALESCE(@Host,N''))=N'LINUX' THEN 1 ELSE 0 END
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode]='ASSEMBLY_TRUST_HASH_EXCLUDED')
           OR (UPPER(COALESCE(@Host,N''))=N'LINUX' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode]='LINUX_CLR_PLATFORM_LIMIT'))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([WarningCode] varchar(120) '$.WarningCode') WHERE [WarningCode] NOT IN('ASSEMBLY_TRUST_HASH_EXCLUDED','LINUX_CLR_PLATFORM_LIMIT'))
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedUpper)<>@FrameworkLevel
           OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedLower)<>@FrameworkLevel
            THROW 56817,N'CLR existing warning boundary or separately measured framework/source levels failed.',1;
        DROP TABLE [#ExampleClrExport];
        SET @Case+=1;
    END;
    /* RAW-/CONSOLE-Zeilen werden nicht separat abgefangen. */
    WHILE @Route<4
    BEGIN
        SELECT @Mode=CASE WHEN @Route IN(0,2) THEN 'RAW' ELSE 'CONSOLE' END,
               @Limit=CASE WHEN @Route<2 THEN 1 ELSE -1 END,@Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N'[ExampleClrÄ]|[exampleClrÄ]',@NurProblematisch=1,@MaxZeilen=@Limit,
             @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>CASE WHEN @Route<2 THEN @BaselineStatus ELSE 'INVALID_PARAMETER' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Route<2 THEN CONVERT(int,@BaselinePartial) ELSE 1 END
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.findings'))
            THROW 56818,N'CLR RAW/CONSOLE status or accompanying empty JSON findings failed.',1;
        SET @Route+=1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleClrÄ')=@OwnedUpper
    BEGIN
        ALTER DATABASE [ExampleClrÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleClrÄ];
    END;
    IF DB_ID(N'exampleClrÄ')=@OwnedLower
    BEGIN
        ALTER DATABASE [exampleClrÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [exampleClrÄ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@LevelUpper AS [FirstSourceCompatibilityLevel],
           @LevelLower AS [SecondSourceCompatibilityLevel],@Case AS [TableJsonCases],@Route AS [RawConsoleStatusCases],
           CAST(0 AS int) AS [NonemptyNativeFindingCases],
           N'Eigener nativer CLR-Leerscope geprüft; positive Findingsfilter-/Limitwirkung, Assemblies, Ausführung, Trust und Sampling bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','ExampleClrNativeCursor')>=0 CLOSE [ExampleClrNativeCursor];
    IF CURSOR_STATUS('local','ExampleClrNativeCursor')>-3 DEALLOCATE [ExampleClrNativeCursor];
    IF CURSOR_STATUS('local','ExampleClrDatabaseCursor')>=0 CLOSE [ExampleClrDatabaseCursor];
    IF CURSOR_STATUS('local','ExampleClrDatabaseCursor')>-3 DEALLOCATE [ExampleClrDatabaseCursor];
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedUpper IS NOT NULL AND DB_ID(N'ExampleClrÄ')=@OwnedUpper
    BEGIN
        ALTER DATABASE [ExampleClrÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleClrÄ];
    END;
    IF @OwnedLower IS NOT NULL AND DB_ID(N'exampleClrÄ')=@OwnedLower
    BEGIN
        ALTER DATABASE [exampleClrÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [exampleClrÄ];
    END;
    THROW;
END CATCH;
GO
