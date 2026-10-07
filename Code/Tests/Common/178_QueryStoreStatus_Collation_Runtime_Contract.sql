USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft den vorhandenen gemeinsamen Query-Store-Statusvertrag mit 27 Feldern
und sieben Textcollations. Source und Ausgabemenge benötigen weder einen
zusätzlichen Export noch ein Zeilenlimit oder einen Problemfilter.
Allgemeine Fälle verwenden nachweislich fehlende Namen und ungültige Parameter.
Der optionale positive Block liest ausschließlich eine extern vorbereitete
Fixture mit drei eigenen leeren Unicode-CI-Datenbanken: READ_WRITE, OFF und
READ_ONLY. Fehlende oder ungeeignete Fixtures melden NOT_EXECUTED. Der Test
verändert keine Datenbankoptionen, erzeugt keine Objekte und führt keinen
synthetischen Workload aus. Native Optionen bestimmen das vollständige Soll einschließlich
NULLs, Speicherquote und Statushinweis. RAW und positive CONSOLE-Zeilenparität
benötigen einen zusätzlichen Clientcapture; direkte CONSOLE-Aufrufe prüfen hier
nur Status und begleitendes JSON. Ältere Engines, Berechtigungsfehler, Timeout,
ERROR-Zustand und positive Speicherwarnschwellen werden nicht behauptet.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 58000,N'STATUS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58001,N'STATUS_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@LoadSql nvarchar(max),@Db nvarchar(128),@DbId int;
DECLARE @UpperName nvarchar(128)=N'ExampleStatusÄ🔬',@LowerName nvarchar(128)=N'exampleStatusÄ🔬',@ReadOnlyName nvarchar(128)=N'ExampleStatusReadOnlyÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingStatusÄ🔬',@WrongName nvarchar(128)=N'EXAMPLEStatusÄ🔬';
DECLARE @MissingScope nvarchar(258)=QUOTENAME(@MissingName),@AllNames nvarchar(max),@FixtureStatus varchar(24)='NOT_EXECUTED';
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,@WrongName))
 THROW 58002,N'STATUS_MISSING_IDENTIFIER',1;
CREATE TABLE #ExampleStatusSchema
([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [DesiredState] smallint NULL,[DesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ActualState] smallint NULL,[ActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ReadonlyReason] int NULL,[CurrentStorageSizeMb] bigint NULL,[MaxStorageSizeMb] bigint NULL,[StorageUsedPercent] decimal(9,2) NULL,
 [FlushIntervalSeconds] bigint NULL,[IntervalLengthMinutes] bigint NULL,[StaleQueryThresholdDays] bigint NULL,[MaxPlansPerQuery] bigint NULL,
 [QueryCaptureMode] smallint NULL,[QueryCaptureModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SizeBasedCleanupMode] smallint NULL,[SizeBasedCleanupModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitStatsCaptureMode] smallint NULL,[WaitStatsCaptureModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CapturePolicyExecutionCount] int NULL,[CapturePolicyTotalCompileCpuTimeMs] bigint NULL,[CapturePolicyTotalExecutionCpuTimeMs] bigint NULL,
 [CapturePolicyStaleThresholdHours] int NULL,[IsEnabled] bit NULL,[IsWritable] bit NULL,[StatusHint] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleStatusNative FROM #ExampleStatusSchema;
SELECT TOP(0) * INTO #ExampleStatusExpected FROM #ExampleStatusSchema;
CREATE TABLE #ExampleStatusOptions
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Level] int NOT NULL,
 [CollationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[Queries] bigint NOT NULL,[UserTables] int NOT NULL);
CREATE TABLE #ExampleStatusFixtureNames([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL);
INSERT #ExampleStatusFixtureNames VALUES(@UpperName,2,2),(@LowerName,0,0),(@ReadOnlyName,1,1);
CREATE TABLE #ExampleStatusEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleStatusPreflight([Dummy] int NULL);
CREATE TABLE #ExampleStatusCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IncludeSystem] bit NULL,[HighImpact] bit NULL,
 [Mode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ExpectedPartial] bit NOT NULL,[MissingWarningName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
INSERT #ExampleStatusCases VALUES
 (0,0,@MissingScope,NULL,0,0,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (1,0,@MissingName,NULL,0,0,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (2,0,@MissingScope,NULL,0,0,'UNSUPPORTED','INVALID_PARAMETER',0,NULL),
 (3,0,N'[ExampleInvalid',NULL,0,0,'TABLE','INVALID_PARAMETER',0,NULL),
 (4,0,@MissingScope+N'|'+@MissingScope,NULL,0,0,'TABLE','INVALID_PARAMETER',0,NULL),
 (5,0,@MissingScope,N'like:Example%',0,0,'TABLE','INVALID_PARAMETER',0,NULL),
 (6,0,NULL,N'like:',0,0,'TABLE','INVALID_PARAMETER',0,NULL),
 (7,0,@MissingScope,NULL,NULL,0,'TABLE','INVALID_PARAMETER',0,NULL),
 (8,0,@MissingScope,NULL,0,NULL,'TABLE','INVALID_PARAMETER',0,NULL),
 (9,0,@MissingScope,NULL,1,0,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (10,0,@MissingScope,NULL,0,1,' table ','DATABASE_UNAVAILABLE',1,@MissingName);
-- The fixture block never creates databases or changes Query Store options.
IF @FrameworkLevel=170 AND (SELECT COUNT(*) FROM master.sys.databases d JOIN #ExampleStatusFixtureNames n
 ON d.name COLLATE SQL_Latin1_General_CP1_CS_AS=n.DatabaseName WHERE d.state=0 AND HAS_DBACCESS(d.name)=1)=3
BEGIN
 DECLARE [Fixture178] CURSOR LOCAL FAST_FORWARD FOR SELECT DatabaseName FROM #ExampleStatusFixtureNames;
 OPEN [Fixture178];FETCH NEXT FROM [Fixture178] INTO @Db;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@Db)+N'; INSERT #ExampleStatusOptions
   SELECT DB_ID(),DB_NAME(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
    CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N''Collation'')),actual_state,desired_state,
    (SELECT COUNT_BIG(*) FROM sys.query_store_query),(SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)
   FROM sys.database_query_store_options;';
  EXEC sys.sp_executesql @Sql;
  FETCH NEXT FROM [Fixture178] INTO @Db;
 END;
 CLOSE [Fixture178];DEALLOCATE [Fixture178];
 IF (SELECT COUNT(*) FROM #ExampleStatusOptions)=3 AND (SELECT COUNT(DISTINCT DatabaseId) FROM #ExampleStatusOptions)=3
  AND NOT EXISTS(SELECT 1 FROM #ExampleStatusOptions o JOIN #ExampleStatusFixtureNames n ON n.DatabaseName=o.DatabaseName
   WHERE o.[Level]<>170 OR o.CollationName<>N'Latin1_General_100_CI_AS' OR o.ActualState<>n.ActualState OR o.DesiredState<>n.DesiredState OR o.Queries<>0 OR o.UserTables<>0)
  AND (SELECT COUNT(*) FROM master.sys.databases WHERE database_id>4 AND state=0 AND HAS_DBACCESS(name)=1)=4
 BEGIN
  SET @AllNames=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName)+N'|'+QUOTENAME(@ReadOnlyName);
  SET @FixtureStatus='PENDING';
  INSERT #ExampleStatusCases VALUES
   (20,1,@AllNames,NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (21,1,QUOTENAME(@UpperName),NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (22,1,QUOTENAME(@LowerName),NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (23,1,QUOTENAME(@ReadOnlyName),NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (24,1,NULL,N'like:ExampleStatus%',0,0,'TABLE','AVAILABLE',0,NULL),
   (25,1,NULL,N'like:%Status%Ä🔬',0,0,'TABLE','AVAILABLE',0,NULL),
   (26,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,0,0,'TABLE','AVAILABLE_LIMITED',1,@MissingName),
   (27,1,QUOTENAME(@WrongName),NULL,0,0,'TABLE','DATABASE_UNAVAILABLE',1,@WrongName),
   (28,1,NULL,NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (29,1,N'',NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (30,1,N'   ',NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (31,1,QUOTENAME(@ReadOnlyName)+N'|'+QUOTENAME(@LowerName)+N'|'+QUOTENAME(@UpperName),NULL,0,0,'TABLE','AVAILABLE',0,NULL),
   (32,1,@AllNames,NULL,0,1,'TABLE','AVAILABLE',0,NULL);
 END;
END;
-- An independently typed native projection uses only the documented options catalog.
SET @LoadSql=N'INSERT #ExampleStatusNative
 SELECT DB_ID(),DB_NAME(),o.desired_state,o.desired_state_desc,o.actual_state,o.actual_state_desc,o.readonly_reason,
  o.current_storage_size_mb,o.max_storage_size_mb,CAST(100.0*o.current_storage_size_mb/NULLIF(o.max_storage_size_mb,0) AS decimal(9,2)),
  o.flush_interval_seconds,o.interval_length_minutes,o.stale_query_threshold_days,o.max_plans_per_query,
  o.query_capture_mode,o.query_capture_mode_desc,o.size_based_cleanup_mode,o.size_based_cleanup_mode_desc,
  o.wait_stats_capture_mode,o.wait_stats_capture_mode_desc,o.capture_policy_execution_count,
  o.capture_policy_total_compile_cpu_time_ms,o.capture_policy_total_execution_cpu_time_ms,o.capture_policy_stale_threshold_hours,
  CAST(CASE WHEN o.actual_state=0 OR o.actual_state=3 THEN 0 WHEN o.actual_state IN(1,2,4) THEN 1 ELSE 0 END AS bit),
  CAST(CASE WHEN o.actual_state=2 THEN 1 ELSE 0 END AS bit),
  CASE WHEN o.actual_state=0 THEN N''Query Store ist OFF.'' WHEN o.actual_state=3 THEN N''Query Store meldet ERROR.''
   WHEN o.desired_state=2 AND o.actual_state=1 THEN N''Query Store ist trotz gewünschtem READ_WRITE nur READ_ONLY; readonly_reason prüfen.''
   WHEN o.max_storage_size_mb>0 AND CAST(o.current_storage_size_mb AS decimal(28,4))/o.max_storage_size_mb>=0.9
    THEN N''Speichernutzung liegt bei mindestens 90 Prozent.'' ELSE N''Query Store ist lesbar.'' END
 FROM sys.database_query_store_options o;';
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@IncludeSystem bit,@High bit,@Mode varchar(16),@Status varchar(40),@Partial bit,@Missing nvarchar(128);
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@ExpectedRows bigint;
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases178] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleStatusCases ORDER BY CaseNumber;
 OPEN [Cases178];FETCH NEXT FROM [Cases178] INTO @Case,@Native,@Names,@Pattern,@IncludeSystem,@High,@Mode,@Status,@Partial,@Missing;
 WHILE @@FETCH_STATUS=0
 BEGIN
  TRUNCATE TABLE #ExampleStatusNative;TRUNCATE TABLE #ExampleStatusExpected;
  IF @Native=1
  BEGIN
   DECLARE [Native178] CURSOR LOCAL FAST_FORWARD FOR SELECT database_id,name FROM master.sys.databases
    WHERE database_id>4 AND state=0 AND HAS_DBACCESS(name)=1 ORDER BY database_id;
   OPEN [Native178];FETCH NEXT FROM [Native178] INTO @DbId,@Db;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @Sql=N'USE '+QUOTENAME(@Db)+N';'+@LoadSql;EXEC sys.sp_executesql @Sql;
    FETCH NEXT FROM [Native178] INTO @DbId,@Db;
   END;
   CLOSE [Native178];DEALLOCATE [Native178];
   IF (SELECT COUNT(*) FROM #ExampleStatusNative n JOIN #ExampleStatusOptions o ON o.DatabaseId=n.DatabaseId AND o.DatabaseName=n.DatabaseName)=3
    AND NOT EXISTS(SELECT 1 FROM #ExampleStatusNative n JOIN #ExampleStatusOptions o ON o.DatabaseId=n.DatabaseId
     WHERE n.DatabaseName<>o.DatabaseName OR n.ActualState<>o.ActualState OR n.DesiredState<>o.DesiredState)
   BEGIN
    INSERT #ExampleStatusExpected SELECT * FROM #ExampleStatusNative n
    WHERE (@Names IS NULL OR NULLIF(LTRIM(RTRIM(@Names)),N'') IS NULL
     OR ((@Names=@AllNames OR @Case=31) AND EXISTS(SELECT 1 FROM #ExampleStatusFixtureNames f WHERE f.DatabaseName=n.DatabaseName))
     OR @Names=QUOTENAME(n.DatabaseName) OR (@Case=26 AND n.DatabaseName=@UpperName))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
   END
   ELSE THROW 58018,N'STATUS_FIXTURE_IDENTITY_STATE',1;
  END;
  SELECT @ExpectedRows=COUNT_BIG(*) FROM #ExampleStatusExpected;
  CREATE TABLE #ExampleStatusExport([Dummy] int NULL);
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  IF @Case=2
   EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@Names,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  ELSE
   EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,
    @SystemdatenbankenEinbeziehen=@IncludeSystem,@HighImpactConfirmed=@High,@ResultSetArt=@Mode,
    @ResultTablesJson=N'{"queryStoreStatus":"#ExampleStatusExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 58003,N'STATUS_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 58004,N'STATUS_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json)
   EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'queryStoreStatus',4),(N'warnings',4)) t(k,v))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>8
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),(N'returnedRows'),(N'errorNumber'),(N'errorMessage')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE
    ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1)
    OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'isPartial' AND [type]<>3)
    OR ([key]=N'errorNumber' AND [type]<>0) OR ([key]=N'errorMessage' AND [type] NOT IN(0,1)))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreStatus'
   OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status
   OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Partial=1 THEN N'true' ELSE N'false' END
    THROW 58005,N'STATUS_META',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 58006,N'STATUS_CAPTURE_TIME',1;
  IF @Case<>2
  BEGIN
   IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatusExport')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatusSchema'))
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatusSchema')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatusExport')) THROW 58007,N'STATUS_SCHEMA',1;
   SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleStatusExport ORDER BY DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleStatusExport);';
   EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  END
  ELSE BEGIN SET @TableJson=N'[]';SET @Rows=0;END;
  IF @Rows<>@ExpectedRows OR @Rows<>COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queryStoreStatus') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>27)
    THROW 58008,N'STATUS_ROWS_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryStoreStatus') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryStoreStatus') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58009,N'STATUS_TABLE_JSON',1;
  SELECT @ExpectedJson=(SELECT * FROM #ExampleStatusExpected ORDER BY DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@TableJson,N'[]') COLLATE Latin1_General_100_BIN2<>COALESCE(@ExpectedJson,N'[]') COLLATE Latin1_General_100_BIN2
   THROW 58010,N'STATUS_NATIVE_FULL_FIELDS_ORDER',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>CASE WHEN @Missing IS NULL THEN 0 ELSE 1 END
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>4
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'databaseName'),(N'code'),(N'errorNumber'),(N'message')) t(k))
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE ([key] IN(N'databaseName',N'code',N'message') AND [type]<>1) OR ([key]=N'errorNumber' AND [type]<>0)))
   OR (@Missing IS NOT NULL AND (JSON_VALUE(@Json,N'$.warnings[0].databaseName') COLLATE Latin1_General_100_BIN2<>@Missing COLLATE Latin1_General_100_BIN2
    OR JSON_VALUE(@Json,N'$.warnings[0].code')<>N'DATABASE_NOT_FOUND'
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings[0]') WHERE [key]=N'errorNumber' AND [type]=0)
    OR JSON_VALUE(@Json,N'$.warnings[0].message')<>N'Die explizit angeforderte Datenbank ist nicht online, nicht sichtbar oder nicht zugreifbar.'))
    THROW 58011,N'STATUS_WARNINGS',1;
  IF @Native=0 SET @CoreCases+=1;ELSE SET @NativeCases+=1;
  DROP TABLE #ExampleStatusExport;
  FETCH NEXT FROM [Cases178] INTO @Case,@Native,@Names,@Pattern,@IncludeSystem,@High,@Mode,@Status,@Partial,@Missing;
 END;
 CLOSE [Cases178];DEALLOCATE [Cases178];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>13 THROW 58012,N'STATUS_NATIVE_CASES',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Names=CASE @Direct WHEN 0 THEN @AllNames WHEN 1 THEN QUOTENAME(@LowerName) ELSE QUOTENAME(@UpperName)+N'|'+@MissingScope END;
   EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@Names,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queryStoreStatus'))<>CASE WHEN @Direct=0 THEN 3 ELSE 1 END
    OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Direct=2 THEN N'AVAILABLE_LIMITED' ELSE N'AVAILABLE' END
    OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Direct=2 THEN N'true' ELSE N'false' END OR @@LOCK_TIMEOUT<>137
     THROW 58013,N'STATUS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @Direct+=1;SET @DirectConsoleCases+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleStatusEmptyConsole;
  SET @Names=CASE @Empty WHEN 0 THEN @MissingScope WHEN 1 THEN N'[ExampleInvalid' ELSE @MissingScope END;
  SET @Pattern=CASE WHEN @Empty=2 THEN N'like:Example%' ELSE NULL END;
  INSERT #ExampleStatusEmptyConsole EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleStatusEmptyConsole)<>1
   OR EXISTS(SELECT 1 FROM #ExampleStatusEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.queryStoreStatus')<>N'[]' OR @@LOCK_TIMEOUT<>137
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Empty=0 THEN N'DATABASE_UNAVAILABLE' ELSE N'INVALID_PARAMETER' END
    THROW 58014,N'STATUS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<2
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' ELSE 'RAW' END;SET @Json=N'ExamplePreviousJson';
  EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@MissingScope,@QueryStoreDatabaseNamePattern=N'like:Example%',
   @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER'
   OR JSON_QUERY(@Json,N'$.queryStoreStatus')<>N'[]' OR JSON_QUERY(@Json,N'$.warnings')<>N'[]' OR @@LOCK_TIMEOUT<>137
    THROW 58015,N'STATUS_INVALID_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleStatusPreflight"}'
   WHEN 2 THEN N'{"queryStoreStatus":"#ExampleMissingTarget178"}' WHEN 3 THEN N'{"queryStoreStatus":"ExamplePermanent"}'
   WHEN 4 THEN N'{"queryStoreStatus":"#ExampleStatusPreflight","unknown":"#ExampleStatusPreflight"}' ELSE N'{"queryStoreStatus":"#ExampleStatusPreflight"}' END;
  SET @Caught=0;SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
  BEGIN TRY
   EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatusPreflight'))<>1
   THROW 58016,N'STATUS_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>11 OR @ConsumerCases<>2 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3 THROW 58017,N'STATUS_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,
  (SELECT [Level] FROM #ExampleStatusOptions WHERE DatabaseName=@UpperName) AS UpperSourceCompatibilityLevel,
  (SELECT [Level] FROM #ExampleStatusOptions WHERE DatabaseName=@LowerName) AS LowerSourceCompatibilityLevel,
  (SELECT [Level] FROM #ExampleStatusOptions WHERE DatabaseName=@ReadOnlyName) AS ReadOnlySourceCompatibilityLevel,
  @CoreCases AS CoreCases,@ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,
  @EmptyConsoleCases AS EmptySqlConsoleCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
