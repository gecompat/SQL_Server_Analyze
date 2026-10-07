USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft den gemeinsamen Runtimeexport mit 40 Feldern und zehn Textcollations.
Die allgemeinen Fälle wählen einen nachweislich fehlenden Datenbanknamen.
Der positive Block liest ausschließlich zwei extern vorbereitete eigene Unicode-
Datenbanken mit eingefrorenem READ_ONLY Query Store und zwei angrenzenden
Ein-Minuten-Intervallen. IDs, Zeitgrenzen, gewichtete Werte, Texte und Pläne werden
nativ abgeleitet; keine Fixture wird ausgeführt oder verändert. Ohne passende
Fixture bleibt der positive Block NOT_EXECUTED. Die Gegenprobe bewahrt alle neun
Sortierungen und ihre bestehenden Secondarykeys, ohne zusätzliche Tie-Sortkeys.
XML wird als Wert verglichen; eine SqlClient-/SQL-Serialisierungsbyteparität wird
nicht behauptet. Positive RAW-/CONSOLE-Vollzeilenparität benötigt zusätzlichen unabhängigen Clientcapture.
Exakte Cross-DB-Referenzlisten bleiben außerhalb dieser Fixture; Common193 prüft
ihren gemeinsamen Vertrag. Regex und fehlende Berechtigungen bleiben unbelegt.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 57900,N'RUNTIME_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 57901,N'RUNTIME_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0;
DECLARE @UpperName nvarchar(128)=N'ExampleRuntimeÄ🔬',@LowerName nvarchar(128)=N'exampleRuntimeÄ🔬',
 @MissingName nvarchar(128)=N'ExampleMissingRuntimeÄ🔬',@MissingScope nvarchar(258),@Both nvarchar(max),@ReferenceName nvarchar(258);
SET @MissingScope=QUOTENAME(@MissingName);SET @ReferenceName=QUOTENAME(@UpperName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,N'EXAMPLERuntimeÄ🔬'))
 THROW 57902,N'RUNTIME_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
SELECT @UpperId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END),
 @LowerId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END) FROM master.sys.databases;
CREATE TABLE #ExampleRuntimeSchema
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[PlanId] bigint NOT NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[ObjectId] bigint NULL,
 [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [FirstExecutionTimeUtc] datetimeoffset NULL,[LastExecutionTimeUtc] datetimeoffset NULL,[ExecutionCount] bigint NULL,
 [TotalDurationMs] decimal(38,3) NULL,[AverageDurationMs] decimal(38,3) NULL,[TotalCpuMs] decimal(38,3) NULL,[AverageCpuMs] decimal(38,3) NULL,
 [TotalLogicalReads] decimal(38,3) NULL,[AverageLogicalReads] decimal(38,3) NULL,[TotalLogicalWrites] decimal(38,3) NULL,[AverageLogicalWrites] decimal(38,3) NULL,
 [TotalPhysicalReads] decimal(38,3) NULL,[TotalMemoryGrantKb] decimal(38,3) NULL,[MaxMemoryGrantKb] decimal(38,3) NULL,[TotalRowCount] decimal(38,3) NULL,
 [TotalLogBytes] decimal(38,3) NULL,[TotalTempdbKb] decimal(38,3) NULL,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,
 [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleRuntimeExpected FROM #ExampleRuntimeSchema;
CREATE TABLE #ExampleRuntimeNative
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[PlanId] bigint NOT NULL,[QueryHash] binary(8) NULL,[PlanHash] binary(8) NULL,[ObjectId] int NOT NULL,
 [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsOne] bit NOT NULL,
 [ExecutionType] tinyint NOT NULL,[ExecutionDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IntervalId] bigint NOT NULL,[IntervalStart] datetimeoffset NOT NULL,[IntervalEnd] datetimeoffset NOT NULL,
 [FirstExecution] datetimeoffset NOT NULL,[LastExecution] datetimeoffset NOT NULL,[Executions] bigint NOT NULL,
 [Duration] float NULL,[Cpu] float NULL,[Reads] float NULL,[Writes] float NULL,[PhysicalReads] float NULL,
 [MemoryPages] float NULL,[MaxMemoryPages] float NULL,[Rows] float NULL,[LogBytes] float NULL,[TempdbPages] float NULL,
 [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ReferencesUpper] bit NULL);
CREATE TABLE #ExampleRuntimeOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,
 [SourceCollation] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Objects] int NOT NULL,[UserRows] bigint NULL,[Queries] int NOT NULL,[ModuleOptions] int NOT NULL);
CREATE TABLE #ExampleRuntimeEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRuntimePreflight([Dummy] int NULL);
DECLARE @To datetime2(7)=SYSUTCDATETIME(),@From datetime2(7),@FirstEnd datetime2(7);
SET @From=DATEADD(HOUR,-1,@To);
IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleRuntimeOptions SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,query_capture_mode,
    CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N''Collation'')),
    (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleRuntimeOneÄ🔬'',N''ExampleRuntimeTwoÄ🔬'')),
    (SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE object_id=OBJECT_ID(N''dbo.ExampleRuntimeRowsÄ🔬'') AND index_id IN(0,1)),
    (SELECT COUNT(*) FROM sys.query_store_query),
    (SELECT COUNT(*) FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id WHERE o.type=''P'' AND o.schema_id=SCHEMA_ID(N''dbo'')
      AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleRuntimeOneÄ🔬'',N''ExampleRuntimeTwoÄ🔬'') AND m.uses_quoted_identifier=1 AND m.uses_ansi_nulls=1)
    FROM sys.database_query_store_options;
   INSERT #ExampleRuntimeNative SELECT DB_ID(),DB_NAME(),q.query_id,p.plan_id,q.query_hash,p.query_plan_hash,o.object_id,QUOTENAME(s.name)+N''.''+QUOTENAME(o.name),
    CONVERT(bit,CASE WHEN o.name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleRuntimeOneÄ🔬'' THEN 1 ELSE 0 END),
    r.execution_type,r.execution_type_desc,i.runtime_stats_interval_id,i.start_time,i.end_time,r.first_execution_time,r.last_execution_time,r.count_executions,
    CONVERT(float,r.avg_duration),CONVERT(float,r.avg_cpu_time),CONVERT(float,r.avg_logical_io_reads),CONVERT(float,r.avg_logical_io_writes),
    CONVERT(float,r.avg_physical_io_reads),CONVERT(float,r.avg_query_max_used_memory),CONVERT(float,r.max_query_max_used_memory),
    CONVERT(float,r.avg_rowcount),CONVERT(float,r.avg_log_bytes_used),CONVERT(float,r.avg_tempdb_space_used),qt.query_sql_text,p.query_plan,
    CONVERT(bit,px.PlanXml.exist(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database=sql:variable("@ReferenceName")]''))
   FROM sys.query_store_runtime_stats r JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=r.runtime_stats_interval_id
    JOIN sys.query_store_plan p ON p.plan_id=r.plan_id JOIN sys.query_store_query q ON q.query_id=p.query_id
    JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id JOIN sys.objects o ON o.object_id=q.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id
    CROSS APPLY(SELECT TRY_CONVERT(xml,p.query_plan) PlanXml) px
   WHERE s.name=N''dbo'' AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleRuntimeOneÄ🔬'',N''ExampleRuntimeTwoÄ🔬'');';
  EXEC sys.sp_executesql @Sql,N'@ReferenceName nvarchar(258)',@ReferenceName=@ReferenceName;SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleRuntimeOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleRuntimeOptions WHERE ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR SourceCollation IS NULL OR SourceCollation<>N'Latin1_General_100_CI_AS' OR Objects<>2 OR UserRows IS NULL OR UserRows<>4 OR Queries<>2 OR ModuleOptions<>2)
  AND (SELECT COUNT(DISTINCT DatabaseId) FROM #ExampleRuntimeNative)=2
  AND NOT EXISTS(SELECT DatabaseId FROM #ExampleRuntimeNative GROUP BY DatabaseId HAVING COUNT(DISTINCT QueryId)<>2 OR COUNT(DISTINCT PlanId)<>2 OR COUNT(DISTINCT ObjectId)<>2)
  AND (SELECT COUNT(DISTINCT IntervalStart) FROM #ExampleRuntimeNative)=2 AND (SELECT COUNT(DISTINCT IntervalEnd) FROM #ExampleRuntimeNative)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleRuntimeNative WHERE Executions<=0 OR ExecutionType<>0 OR ExecutionDescription<>N'Regular' OR DATEDIFF_BIG(SECOND,IntervalStart,IntervalEnd)<>60
   OR DATEPART(TZOFFSET,IntervalStart)<>0 OR DATEPART(TZOFFSET,IntervalEnd)<>0 OR PlanText IS NULL OR TRY_CONVERT(xml,PlanText) IS NULL)
 BEGIN
  SELECT @From=CONVERT(datetime2(7),MIN(IntervalStart)),@FirstEnd=CONVERT(datetime2(7),MIN(IntervalEnd)),@To=CONVERT(datetime2(7),MAX(IntervalEnd)) FROM #ExampleRuntimeNative;
  IF DATEDIFF_BIG(SECOND,@From,@To)<>120 OR @FirstEnd<>DATEADD(MINUTE,1,@From)
   OR EXISTS(SELECT DatabaseId,QueryId,PlanId,IntervalStart,IsOne FROM #ExampleRuntimeNative GROUP BY DatabaseId,QueryId,PlanId,IntervalStart,IsOne
      HAVING SUM(Executions)<>CASE WHEN IntervalStart=@From THEN 2 WHEN IsOne=1 THEN 8 ELSE 4 END)
   OR (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId,PlanId,IntervalStart FROM #ExampleRuntimeNative GROUP BY DatabaseId,QueryId,PlanId,IntervalStart) x)<>8
   OR EXISTS(SELECT 1 FROM #ExampleRuntimeNative WHERE ReferencesUpper IS NULL OR ReferencesUpper<>CASE WHEN DatabaseId=@UpperId THEN 1 ELSE 0 END)
   THROW 57903,N'RUNTIME_NATIVE_INTERVALS',1;
  SELECT @UpperLevel=[Level] FROM #ExampleRuntimeOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleRuntimeOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel THROW 57904,N'RUNTIME_SOURCE_LEVELS',1;
  SET @Both=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);SET @FixtureStatus='PENDING';
 END;
END;
CREATE TABLE #ExampleRuntimeCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,[PlanXml] bit NOT NULL,
 [Sort] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryId] bigint NULL,[QueryHash] binary(8) NULL,
 [TextPattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RefPattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Invalid] bit NOT NULL);
INSERT #ExampleRuntimeCases VALUES
 (0,0,@MissingScope,NULL,NULL,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(1,0,@MissingScope,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (2,0,@MissingScope,NULL,1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(3,0,@MissingScope,NULL,2,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (4,0,@MissingScope,NULL,-1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,1),(5,0,@MissingScope,NULL,1,-1,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,1),
 (6,0,N'[ExampleInvalid',NULL,1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,1),(7,0,@MissingScope,NULL,1,4000,0,'UNSUPPORTED',NULL,NULL,NULL,NULL,1),
 (8,0,@MissingScope,NULL,1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,1),(9,0,@MissingScope,NULL,1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,N'like:Example%',1),
 (10,0,@MissingScope,NULL,1,NULL,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(11,0,@MissingScope,NULL,1,0,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (12,0,@MissingScope,NULL,1,5,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(13,0,@MissingScope,NULL,2147483647,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0);
IF @FixtureStatus='PENDING'
BEGIN
 DECLARE @OneQuery bigint,@OneHash binary(8);
 SELECT TOP(1) @OneQuery=QueryId,@OneHash=QueryHash FROM #ExampleRuntimeNative WHERE DatabaseId=@UpperId AND IsOne=1 ORDER BY QueryId;
 INSERT #ExampleRuntimeCases SELECT 20+v.Ordinal,1,@Both,NULL,1,4000,0,v.Sort,NULL,NULL,NULL,NULL,0 FROM
  (VALUES(0,'CPU_TOTAL'),(1,'DURATION_TOTAL'),(2,'READS_TOTAL'),(3,'WRITES_TOTAL'),(4,'EXECUTIONS'),(5,'MEMORY_MAX'),(6,'TEMPDB_TOTAL'),(7,'LOG_BYTES_TOTAL'),(8,'LAST_EXECUTION')) v(Ordinal,Sort);
 INSERT #ExampleRuntimeCases VALUES
 (29,1,@Both,NULL,NULL,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(30,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (31,1,@Both,NULL,2,12,1,'EXECUTIONS',NULL,NULL,NULL,NULL,0),(32,1,@Both,NULL,0,4000,1,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (33,1,QUOTENAME(@UpperName),NULL,0,0,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(34,1,QUOTENAME(@LowerName),NULL,0,NULL,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (35,1,NULL,N'like:'+@UpperName,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(36,1,QUOTENAME(@UpperName),NULL,0,4000,0,'CPU_TOTAL',@OneQuery,NULL,NULL,NULL,0),
 (37,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,@OneHash,NULL,NULL,0),(38,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,N'like:%SUM%',NULL,0),
 (39,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,N'like:%ExampleMissingText%',NULL,0),(40,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),
 (41,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0),(42,1,@Both,NULL,0,4000,0,'CPU_TOTAL',NULL,NULL,NULL,N'like:'+@UpperName,0),
 (43,1,N'[EXAMPLERuntimeÄ🔬]',NULL,1,4000,0,'CPU_TOTAL',NULL,NULL,NULL,NULL,0);
END;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@IncludePlan bit,@Sort varchar(32),
 @QueryId bigint,@QueryHash binary(8),@TextPattern nvarchar(4000),@RefPattern nvarchar(4000),@Invalid bit;
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@Count bigint,@ExpectedRows bigint,@BadRank bigint;
DECLARE @CaseFrom datetime2(7),@CaseTo datetime2(7),@RefNames nvarchar(max);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases177] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleRuntimeCases ORDER BY CaseNumber;
 OPEN [Cases177];FETCH NEXT FROM [Cases177] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@IncludePlan,@Sort,@QueryId,@QueryHash,@TextPattern,@RefPattern,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleRuntimeExport([Dummy] int NULL);
  SET @CaseFrom=CASE WHEN @Case=40 THEN DATEADD(SECOND,20,@From) WHEN @Case=41 THEN @To ELSE @From END;
  SET @CaseTo=CASE WHEN @Case=8 THEN @From WHEN @Case=40 THEN DATEADD(SECOND,40,@From) WHEN @Case=41 THEN DATEADD(SECOND,1,@To) ELSE @To END;
  SET @RefNames=CASE WHEN @Case=9 THEN @MissingScope ELSE NULL END;
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
   @QueryId=@QueryId,@QueryHash=@QueryHash,@TextPattern=@TextPattern,@VonUtc=@CaseFrom,@BisUtc=@CaseTo,@Sortierung=@Sort,
   @ReferencedDatabaseNames=@RefNames,@ReferencedDatabaseNamePattern=@RefPattern,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,@MitPlanXml=@IncludePlan,
   @ResultSetArt='TABLE',@ResultTablesJson=N'{"runtimeStats":"#ExampleRuntimeExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57905,N'RUNTIME_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 57906,N'RUNTIME_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'runtimeStats',4),(N'warnings',4)) t(k,v))
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>14 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),(N'requestedMaxRows'),(N'returnedRows'),(N'resultLimited'),(N'hasMoreRows'),(N'fromUtc'),(N'toUtc'),(N'sort'),(N'errorNumber'),(N'errorMessage')) t(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode',N'fromUtc',N'toUtc',N'sort') AND [type]<>1)
    OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key] IN(N'isPartial',N'resultLimited',N'hasMoreRows') AND [type]<>3))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreRuntimeStats' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.sort')<>@Sort OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.fromUtc')) IS NULL OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.toUtc')) IS NULL OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.fromUtc'))<>@CaseFrom OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.toUtc'))<>@CaseTo THROW 57907,N'RUNTIME_META',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 57908,N'RUNTIME_CAPTURE_TIME',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRuntimeExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRuntimeSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRuntimeSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRuntimeExport')) THROW 57909,N'RUNTIME_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleRuntimeExport FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleRuntimeExport);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  IF @Rows<>COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.runtimeStats') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>40) THROW 57910,N'RUNTIME_JSON_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.runtimeStats') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.runtimeStats') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 57911,N'RUNTIME_TABLE_JSON',1;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END OR JSON_QUERY(@Json,N'$.warnings')<>N'[]'
   OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorNumber' AND [type]=0)
   OR (@Invalid=0 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorMessage' AND [type]=0))
   OR (@Invalid=1 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorMessage' AND [type]=1))
   OR (@Invalid=1 AND JSON_VALUE(@Json,N'$.meta.errorMessage')<>N'Ungültiger Parameter oder Zeitraum.' AND @Case<>6) THROW 57912,N'RUNTIME_STATUS_WARNINGS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false' OR JSON_VALUE(@Json,N'$.meta.resultLimited')<>N'false' THROW 57913,N'RUNTIME_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleRuntimeExpected;
   ;WITH Records AS
   (SELECT n.* FROM #ExampleRuntimeNative n WHERE IntervalEnd>@CaseFrom AND IntervalStart<@CaseTo
     AND (@Names IS NULL OR @Names=@Both OR @Names=QUOTENAME(n.DatabaseName))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@QueryId IS NULL OR n.QueryId=@QueryId) AND (@QueryHash IS NULL OR n.QueryHash=@QueryHash)
     AND (@TextPattern IS NULL OR n.SqlText COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@TextPattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@RefPattern IS NULL OR n.ReferencesUpper=1)),
   PerInterval AS
   (SELECT DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,ObjectId,ObjectName,ExecutionType,ExecutionDescription,IntervalId,SqlText,PlanText,
     MIN(FirstExecution) FirstExecution,MAX(LastExecution) LastExecution,SUM(Executions) Executions,
     SUM(Duration*Executions) Duration,SUM(Cpu*Executions) Cpu,SUM(Reads*Executions) Reads,SUM(Writes*Executions) Writes,SUM(PhysicalReads*Executions) PhysicalReads,
     SUM(MemoryPages*Executions) MemoryPages,MAX(MaxMemoryPages) MaxMemoryPages,SUM([Rows]*Executions) [Rows],SUM(LogBytes*Executions) LogBytes,SUM(TempdbPages*Executions) TempdbPages
    FROM Records GROUP BY DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,ObjectId,ObjectName,ExecutionType,ExecutionDescription,IntervalId,SqlText,PlanText),
   Totals AS
   (SELECT DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,ObjectId,ObjectName,ExecutionDescription,SqlText,PlanText,
     MIN(FirstExecution) FirstExecution,MAX(LastExecution) LastExecution,SUM(Executions) Executions,
     SUM(Duration) Duration,SUM(Cpu) Cpu,SUM(Reads) Reads,SUM(Writes) Writes,SUM(PhysicalReads) PhysicalReads,
     SUM(MemoryPages) MemoryPages,MAX(MaxMemoryPages) MaxMemoryPages,SUM([Rows]) [Rows],SUM(LogBytes) LogBytes,SUM(TempdbPages) TempdbPages
    FROM PerInterval GROUP BY DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,ObjectId,ObjectName,ExecutionDescription,SqlText,PlanText)
   INSERT #ExampleRuntimeExpected SELECT DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,ObjectId,ObjectName,ExecutionDescription,FirstExecution,LastExecution,Executions,
    CONVERT(decimal(38,3),Duration/1000.0),CONVERT(decimal(38,3),Duration/NULLIF(Executions,0)/1000.0),CONVERT(decimal(38,3),Cpu/1000.0),CONVERT(decimal(38,3),Cpu/NULLIF(Executions,0)/1000.0),
    CONVERT(decimal(38,3),Reads),CONVERT(decimal(38,3),Reads/NULLIF(Executions,0)),CONVERT(decimal(38,3),Writes),CONVERT(decimal(38,3),Writes/NULLIF(Executions,0)),
    CONVERT(decimal(38,3),PhysicalReads),CONVERT(decimal(38,3),MemoryPages*8.0),CONVERT(decimal(38,3),MaxMemoryPages*8.0),CONVERT(decimal(38,3),[Rows]),CONVERT(decimal(38,3),LogBytes),CONVERT(decimal(38,3),TempdbPages*8.0),
    'QUERY_STORE',N'sys.query_store_runtime_stats|sys.query_store_plan|sys.query_store_query_text',@At,'DATABASE_QUERY_PLAN_INTERVAL',
    CONVERT(bigint,LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1),CONVERT(bigint,DATALENGTH(SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN SqlText ELSE LEFT(SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    CASE WHEN @IncludePlan=1 THEN 'AVAILABLE' ELSE 'NOT_REQUESTED' END,
    CASE WHEN @IncludePlan=1 THEN CONVERT(bigint,LEN((PlanText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
    CASE WHEN @IncludePlan=1 THEN CONVERT(bigint,DATALENGTH(PlanText)) END,
    CASE WHEN @IncludePlan=1 THEN CONVERT(xml,PlanText) END,NULL,
    N'Query Store liefert aggregierte Intervallwerte und den gespeicherten Plan; keine aktuelle Einzelausführung und keine vollständigen Runtimeparameter.' FROM Totals;
   SELECT @Count=COUNT_BIG(*) FROM #ExampleRuntimeExpected;
   IF (@Case IN(29,30,32,40) AND @Count<>4) OR (@Case IN(39,41,43) AND @Count<>0) THROW 57914,N'RUNTIME_NATIVE_FILTER_COUNTS',1;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @Count>@Max THEN @Max ELSE @Count END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max>0 AND @Count>@Max THEN N'true' ELSE N'false' END
    OR JSON_VALUE(@Json,N'$.meta.resultLimited')<>JSON_VALUE(@Json,N'$.meta.hasMoreRows') THROW 57915,N'RUNTIME_NATIVE_COUNTS',1;
   SET @Sql=N'IF EXISTS(SELECT 1 FROM #ExampleRuntimeExport a WHERE NOT EXISTS(SELECT 1 FROM #ExampleRuntimeExpected e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.QueryId=a.QueryId AND e.PlanId=a.PlanId AND e.ExecutionTypeDesc=a.ExecutionTypeDesc))
    OR EXISTS(SELECT QueryStoreDatabaseId,QueryId,PlanId,ExecutionTypeDesc FROM #ExampleRuntimeExport GROUP BY QueryStoreDatabaseId,QueryId,PlanId,ExecutionTypeDesc HAVING COUNT(*)<>1) THROW 57916,N''RUNTIME_NATIVE_KEYS'',1;
    ;WITH r AS(SELECT *,DENSE_RANK() OVER(ORDER BY CASE WHEN @sort=''LAST_EXECUTION'' THEN LastExecutionTimeUtc END DESC,
     CASE @sort WHEN ''CPU_TOTAL'' THEN TotalCpuMs WHEN ''DURATION_TOTAL'' THEN TotalDurationMs WHEN ''READS_TOTAL'' THEN TotalLogicalReads WHEN ''WRITES_TOTAL'' THEN TotalLogicalWrites
      WHEN ''EXECUTIONS'' THEN ExecutionCount WHEN ''MEMORY_MAX'' THEN MaxMemoryGrantKb WHEN ''TEMPDB_TOTAL'' THEN TotalTempdbKb WHEN ''LOG_BYTES_TOTAL'' THEN TotalLogBytes END DESC,
      LastExecutionTimeUtc DESC,QueryStoreDatabaseName,QueryId,PlanId) NativeRank FROM #ExampleRuntimeExpected)
    SELECT @bad=COUNT_BIG(*) FROM r e JOIN r a ON e.NativeRank<a.NativeRank
     WHERE EXISTS(SELECT 1 FROM #ExampleRuntimeExport x WHERE x.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND x.QueryId=a.QueryId AND x.PlanId=a.PlanId AND x.ExecutionTypeDesc=a.ExecutionTypeDesc)
      AND NOT EXISTS(SELECT 1 FROM #ExampleRuntimeExport x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.QueryId=e.QueryId AND x.PlanId=e.PlanId AND x.ExecutionTypeDesc=e.ExecutionTypeDesc);
    DELETE e FROM #ExampleRuntimeExpected e WHERE NOT EXISTS(SELECT 1 FROM #ExampleRuntimeExport a WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.QueryId=e.QueryId AND a.PlanId=e.PlanId AND a.ExecutionTypeDesc=e.ExecutionTypeDesc);';
   SET @BadRank=0;EXEC sys.sp_executesql @Sql,N'@sort varchar(32),@bad bigint OUTPUT',@Sort,@BadRank OUTPUT;
   IF @BadRank<>0 THROW 57917,N'RUNTIME_GLOBAL_RANK',1;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleRuntimeExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.runtimeStats') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.runtimeStats') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 57918,N'RUNTIME_NATIVE_FULL_FIELDS',1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleRuntimeExport;
  FETCH NEXT FROM [Cases177] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@IncludePlan,@Sort,@QueryId,@QueryHash,@TextPattern,@RefPattern,@Invalid;
 END;
 CLOSE [Cases177];DEALLOCATE [Cases177];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>24 THROW 57919,N'RUNTIME_NATIVE_CASES',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@VonUtc=@From,@BisUtc=@To,
    @MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.runtimeStats'))<>CASE WHEN @Max=0 THEN 4 ELSE @Max END OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE'
    OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max=0 THEN N'false' ELSE N'true' END OR @@LOCK_TIMEOUT<>137 THROW 57920,N'RUNTIME_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @DirectConsoleCases+=1;SET @Direct+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleRuntimeEmptyConsole;SET @Max=CASE @Empty WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleRuntimeEmptyConsole EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=@MissingScope,@HighImpactConfirmed=1,@MaxZeilen=@Max,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleRuntimeEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleRuntimeEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.runtimeStats')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 57921,N'RUNTIME_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0,@Mode varchar(16);
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'UNSUPPORTED' END;
  SET @Max=CASE WHEN @Consumer=1 THEN -1 ELSE 1 END;SET @TextLimit=CASE WHEN @Consumer=0 THEN -1 ELSE 4000 END;
  EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,
   @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.runtimeStats')<>N'[]'
   OR @@LOCK_TIMEOUT<>137 THROW 57922,N'RUNTIME_INVALID_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleRuntimePreflight"}' WHEN 2 THEN N'{"runtimeStats":"#ExampleMissingTarget177"}'
   WHEN 3 THEN N'{"runtimeStats":"ExamplePermanent"}' WHEN 4 THEN N'{"runtimeStats":"#ExampleRuntimePreflight","unknown":"#ExampleRuntimePreflight"}' ELSE N'{"runtimeStats":"#ExampleRuntimePreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC [monitor].[USP_QueryStoreRuntimeStats] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRuntimePreflight'))<>1 THROW 57923,N'RUNTIME_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>14 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3 THROW 57924,N'RUNTIME_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,@UpperLevel AS UpperSourceCompatibilityLevel,@LowerLevel AS LowerSourceCompatibilityLevel,
  @CoreCases AS CoreCases,@ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,
  @EmptyConsoleCases AS EmptySqlConsoleCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
