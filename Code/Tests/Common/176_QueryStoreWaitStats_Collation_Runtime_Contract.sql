USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft den gemeinsamen 25-Feld-Waitexport mit acht Textcollations.
Allgemeine Fälle verwenden einen nachweislich fehlenden Datenbanknamen.
Der positive Block liest ausschließlich zwei extern vorbereitete eigene
Unicode-Datenbanken mit READ_ONLY Query Store, Wait Capture ON und vier nativen
Lock-Aggregaten aus einem Intervall. Ohne passende Fixture bleibt dieser Block
NOT_EXECUTED. Der Test führt keine Fixture-Procedures aus und verändert weder
Objekte noch Query Store oder Datenbankoptionen. Die native Collation der Kategorienbeschreibung und der explizit collatierte numerische Kategorienarm werden getrennt
geprüft. Ein Record je Gruppe belegt keine unterschiedliche Gewichtungswirkung
des AVG; Rangties werden nicht als Fixtureevidenz vorausgesetzt. Positive RAW-
und CONSOLE-Vollzeilenparität benötigen zusätzlichen unabhängigen Clientcapture.
Exakte Cross-DB-Referenzlisten mit dem bestehenden Helper bleiben außerhalb
des positiven Blocks.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 57800,N'WAITS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 57801,N'WAITS_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0;
DECLARE @UpperName nvarchar(128)=N'ExampleWaitÄ🔬',@LowerName nvarchar(128)=N'exampleWaitÄ🔬',
 @MissingName nvarchar(128)=N'ExampleMissingWaitÄ🔬',@MissingScope nvarchar(258),@Both nvarchar(max),@ReferenceName nvarchar(258);
SET @MissingScope=QUOTENAME(@MissingName);SET @ReferenceName=QUOTENAME(@UpperName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,N'EXAMPLEWaitÄ🔬'))
 THROW 57802,N'WAITS_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
SELECT @UpperId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END),
 @LowerId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END) FROM master.sys.databases;
CREATE TABLE #ExampleWaitsSchema
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[PlanId] bigint NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[WaitCategory] tinyint NULL,
 [WaitCategoryDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionTypeDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [FirstIntervalStartUtc] datetimeoffset NULL,[LastIntervalEndUtc] datetimeoffset NULL,[RecordedRows] bigint NULL,[TotalQueryWaitTimeMs] bigint NULL,
 [AverageRecordedQueryWaitTimeMs] decimal(38,3) NULL,[MaxQueryWaitTimeMs] bigint NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleWaitsExpected FROM #ExampleWaitsSchema;
CREATE TABLE #ExampleWaitsNative
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[PlanId] bigint NOT NULL,[QueryHash] binary(8) NULL,[PlanHash] binary(8) NULL,[ObjectId] int NOT NULL,
 [WaitCategory] tinyint NOT NULL,[WaitDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ExecutionDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IntervalStart] datetimeoffset NOT NULL,[IntervalEnd] datetimeoffset NOT NULL,[TotalWait] bigint NOT NULL,[AverageWait] float NOT NULL,
 [MaxWait] bigint NOT NULL,[ReferencesUpper] bit NOT NULL);
CREATE TABLE #ExampleWaitsOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,
 [WaitCapture] int NOT NULL,[Objects] int NOT NULL,[UserRows] bigint NULL,[WaitRows] bigint NOT NULL,
 [SourceCollation] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ModuleQueries] int NOT NULL,[ModuleOptions] int NOT NULL,
 [DescriptorCollation] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleWaitsEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleWaitsPreflight([Dummy] int NULL);
DECLARE @To datetime2(7)=SYSUTCDATETIME(),@From datetime2(7),@LockDescription nvarchar(128),@LockNumber nvarchar(10);
SET @From=DATEADD(HOUR,-1,@To);
IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleWaitsOptions SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,query_capture_mode,wait_stats_capture_mode,
    (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleWaitOneÄ🔬'',N''ExampleWaitTwoÄ🔬'')),
    (SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE object_id=OBJECT_ID(N''dbo.ExampleWaitRowsÄ🔬'') AND index_id IN(0,1)),
    (SELECT COUNT_BIG(*) FROM sys.query_store_wait_stats),
     CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N''Collation'')),
     (SELECT COUNT(*) FROM sys.query_store_query),
     (SELECT COUNT(*) FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id WHERE o.type=''P'' AND o.schema_id=SCHEMA_ID(N''dbo'')
       AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleWaitOneÄ🔬'',N''ExampleWaitTwoÄ🔬'') AND m.uses_quoted_identifier=1 AND m.uses_ansi_nulls=1),
    (SELECT collation_name FROM sys.dm_exec_describe_first_result_set(N''SELECT wait_category_desc FROM sys.query_store_wait_stats'',NULL,0) WHERE name=N''wait_category_desc'')
    FROM sys.database_query_store_options;
   INSERT #ExampleWaitsNative SELECT DB_ID(),DB_NAME(),q.query_id,p.plan_id,q.query_hash,p.query_plan_hash,o.object_id,
    w.wait_category,w.wait_category_desc,w.execution_type_desc,qt.query_sql_text,i.start_time,i.end_time,w.total_query_wait_time_ms,w.avg_query_wait_time_ms,w.max_query_wait_time_ms,
    CONVERT(bit,px.PlanXml.exist(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database=sql:variable("@ReferenceName")]''))
   FROM sys.query_store_wait_stats w JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=w.runtime_stats_interval_id
    JOIN sys.query_store_plan p ON p.plan_id=w.plan_id JOIN sys.query_store_query q ON q.query_id=p.query_id
    JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id JOIN sys.objects o ON o.object_id=q.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id
    CROSS APPLY(SELECT TRY_CONVERT(xml,p.query_plan) PlanXml) px
   WHERE s.name=N''dbo'' AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleWaitOneÄ🔬'',N''ExampleWaitTwoÄ🔬'');';
  EXEC sys.sp_executesql @Sql,N'@ReferenceName nvarchar(258)',@ReferenceName=@ReferenceName;SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleWaitsOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleWaitsOptions WHERE ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR WaitCapture<>1 OR Objects<>2 OR UserRows IS NULL OR UserRows<>4 OR WaitRows<>2
   OR SourceCollation IS NULL OR SourceCollation<>N'Latin1_General_100_CI_AS' OR ModuleQueries<>2 OR ModuleOptions<>2
    OR DescriptorCollation IS NULL OR DescriptorCollation<>N'Latin1_General_CI_AS_KS_WS')
  AND (SELECT COUNT(*) FROM #ExampleWaitsNative)=4
  AND NOT EXISTS(SELECT DatabaseId FROM #ExampleWaitsNative GROUP BY DatabaseId HAVING COUNT(DISTINCT QueryId)<>2 OR COUNT(DISTINCT PlanId)<>2 OR COUNT(DISTINCT ObjectId)<>2)
  AND NOT EXISTS(SELECT 1 FROM #ExampleWaitsNative WHERE TotalWait<=0 OR AverageWait<0 OR MaxWait<=0 OR IntervalStart>=IntervalEnd)
  AND (SELECT COUNT(DISTINCT IntervalStart) FROM #ExampleWaitsNative)=1 AND (SELECT COUNT(DISTINCT IntervalEnd) FROM #ExampleWaitsNative)=1
  AND (SELECT COUNT(DISTINCT WaitCategory) FROM #ExampleWaitsNative)=1 AND NOT EXISTS(SELECT 1 FROM #ExampleWaitsNative WHERE WaitCategory<>3 OR WaitDescription<>N'Lock' OR ExecutionDescription<>N'Regular')
 BEGIN
  SELECT @From=CONVERT(datetime2(7),MIN(IntervalStart)),@To=CONVERT(datetime2(7),MAX(IntervalEnd)),@LockDescription=MIN(WaitDescription),@LockNumber=CONVERT(nvarchar(10),MIN(WaitCategory)) FROM #ExampleWaitsNative;
  IF DATEDIFF_BIG(SECOND,@From,@To)<60 OR EXISTS(SELECT 1 FROM #ExampleWaitsNative WHERE DATEPART(TZOFFSET,IntervalStart)<>0 OR DATEPART(TZOFFSET,IntervalEnd)<>0)
   OR EXISTS(SELECT 1 FROM #ExampleWaitsNative WHERE ReferencesUpper<>CASE WHEN DatabaseId=@UpperId THEN 1 ELSE 0 END)
   THROW 57803,N'WAITS_NATIVE_INTERVAL',1;
  SELECT @UpperLevel=[Level] FROM #ExampleWaitsOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleWaitsOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel THROW 57804,N'WAITS_SOURCE_LEVELS',1;
  SET @Both=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);SET @FixtureStatus='PENDING';
 END;
END;
CREATE TABLE #ExampleWaitsCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,
 [Category] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryId] bigint NULL,[QueryHash] binary(8) NULL,
 [RefPattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Invalid] bit NOT NULL);
INSERT #ExampleWaitsCases VALUES
 (0,0,@MissingScope,NULL,NULL,4000,NULL,NULL,NULL,NULL,0),(1,0,@MissingScope,NULL,0,4000,NULL,NULL,NULL,NULL,0),
 (2,0,@MissingScope,NULL,1,4000,NULL,NULL,NULL,NULL,0),(3,0,@MissingScope,NULL,2,4000,NULL,NULL,NULL,NULL,0),
 (4,0,@MissingScope,NULL,-1,4000,NULL,NULL,NULL,NULL,1),(5,0,@MissingScope,NULL,1,-1,NULL,NULL,NULL,NULL,1),
 (6,0,N'[ExampleInvalid',NULL,1,4000,NULL,NULL,NULL,NULL,1),(7,0,@MissingScope,NULL,1,4000,NULL,NULL,NULL,NULL,1),
 (8,0,@MissingScope,NULL,1,4000,NULL,NULL,NULL,NULL,1),(9,0,@MissingScope,NULL,1,4000,NULL,NULL,NULL,N'like:Example%',1),
 (10,0,@MissingScope,NULL,1,NULL,NULL,NULL,NULL,NULL,0),(11,0,@MissingScope,NULL,1,0,NULL,NULL,NULL,NULL,0),
 (12,0,@MissingScope,NULL,1,5,NULL,NULL,NULL,NULL,0),(13,0,@MissingScope,NULL,2147483647,4000,NULL,NULL,NULL,NULL,0);
IF @FixtureStatus='PENDING'
BEGIN
 DECLARE @OneQuery bigint,@OneHash binary(8);
 SELECT TOP(1) @OneQuery=QueryId,@OneHash=QueryHash FROM #ExampleWaitsNative WHERE DatabaseId=@UpperId ORDER BY QueryId;
 INSERT #ExampleWaitsCases VALUES
 (20,1,@Both,NULL,NULL,4000,NULL,NULL,NULL,NULL,0),(21,1,@Both,NULL,0,4000,NULL,NULL,NULL,NULL,0),
 (22,1,@Both,NULL,1,4000,NULL,NULL,NULL,NULL,0),(23,1,@Both,NULL,2,4000,NULL,NULL,NULL,NULL,0),
 (24,1,@Both,NULL,2,12,NULL,NULL,NULL,NULL,0),(25,1,QUOTENAME(@UpperName),NULL,0,0,NULL,NULL,NULL,NULL,0),
 (26,1,QUOTENAME(@LowerName),NULL,0,NULL,NULL,NULL,NULL,NULL,0),(27,1,NULL,N'like:'+@UpperName,0,4000,NULL,NULL,NULL,NULL,0),
 (28,1,QUOTENAME(@UpperName),NULL,0,4000,NULL,@OneQuery,NULL,NULL,0),(29,1,@Both,NULL,0,4000,NULL,NULL,@OneHash,NULL,0),
 (30,1,@Both,NULL,0,4000,@LockDescription,NULL,NULL,NULL,0),(31,1,@Both,NULL,0,4000,LOWER(@LockDescription),NULL,NULL,NULL,0),
 (32,1,@Both,NULL,0,4000,@LockNumber,NULL,NULL,NULL,0),(33,1,@Both,NULL,0,4000,N'0'+@LockNumber,NULL,NULL,NULL,0),
 (34,1,@Both,NULL,0,4000,N'',NULL,NULL,NULL,0),(35,1,@Both,NULL,0,4000,N'ExampleMissingWaitCategory',NULL,NULL,NULL,0),
 (36,1,@Both,NULL,0,4000,NULL,NULL,NULL,NULL,0),(37,1,@Both,NULL,0,4000,NULL,NULL,NULL,NULL,0),
 (38,1,N'[EXAMPLEWaitÄ🔬]',NULL,1,4000,NULL,NULL,NULL,NULL,0),(39,1,@Both,NULL,0,4000,NULL,NULL,NULL,N'like:'+@UpperName,0),
 (40,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,1,4000,NULL,NULL,NULL,NULL,0);
END;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@Category nvarchar(128),@QueryId bigint,@QueryHash binary(8),@RefPattern nvarchar(4000),@Invalid bit;
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@Count bigint,@ExpectedRows bigint,@BadRank bigint;
DECLARE @Analyse varchar(16),@CaseFrom datetime2(7),@CaseTo datetime2(7),@RefNames nvarchar(max);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases176] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleWaitsCases ORDER BY CaseNumber;
 OPEN [Cases176];FETCH NEXT FROM [Cases176] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@Category,@QueryId,@QueryHash,@RefPattern,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleWaitsExport([Dummy] int NULL);
  SET @Analyse=CASE WHEN @Case=7 THEN 'UNSUPPORTED' ELSE 'TOP' END;
  SET @CaseFrom=CASE WHEN @Case=36 THEN DATEADD(SECOND,20,@From) WHEN @Case=37 THEN @To ELSE @From END;
  SET @CaseTo=CASE WHEN @Case=8 THEN @From WHEN @Case=36 THEN DATEADD(SECOND,40,@From) WHEN @Case=37 THEN DATEADD(SECOND,1,@To) ELSE @To END;
  SET @RefNames=CASE WHEN @Case=9 THEN @MissingScope ELSE NULL END;
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStoreWaitStats] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
   @QueryId=@QueryId,@QueryHash=@QueryHash,@WaitCategory=@Category,@VonUtc=@CaseFrom,@BisUtc=@CaseTo,@AnalyseModus=@Analyse,
   @ReferencedDatabaseNames=@RefNames,@ReferencedDatabaseNamePattern=@RefPattern,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,
   @ResultSetArt='TABLE',@ResultTablesJson=N'{"waitStats":"#ExampleWaitsExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57805,N'WAITS_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 57806,N'WAITS_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'waitStats',4),(N'warnings',4)) t(k,v))
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>7 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) t(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1) OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'hasMoreRows' AND [type]<>3))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreWaitStats' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1 THROW 57807,N'WAITS_META',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 57808,N'WAITS_CAPTURE_TIME',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWaitsExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWaitsSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWaitsSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWaitsExport')) THROW 57809,N'WAITS_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleWaitsExport FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleWaitsExport);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  IF @Rows<>TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.waitStats') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>25) THROW 57810,N'WAITS_JSON_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.waitStats') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.waitStats') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 57811,N'WAITS_TABLE_JSON',1;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END OR JSON_QUERY(@Json,N'$.warnings')<>N'[]' THROW 57812,N'WAITS_STATUS_WARNINGS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false' THROW 57813,N'WAITS_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleWaitsExpected;
   ;WITH Totals AS
   (SELECT DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,WaitCategory,WaitDescription,ExecutionDescription,SqlText,
     MIN(IntervalStart) FirstStart,MAX(IntervalEnd) LastEnd,COUNT_BIG(*) RecordedRows,SUM(TotalWait) TotalWait,AVG(AverageWait) AverageWait,MAX(MaxWait) MaxWait
    FROM #ExampleWaitsNative n WHERE IntervalEnd>@CaseFrom AND IntervalStart<@CaseTo
     AND (@Names IS NULL OR @Names=@Both OR @Names=QUOTENAME(n.DatabaseName) OR (@Case=40 AND n.DatabaseId=@UpperId))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@QueryId IS NULL OR n.QueryId=@QueryId) AND (@QueryHash IS NULL OR n.QueryHash=@QueryHash) AND (@RefPattern IS NULL OR n.ReferencesUpper=1)
     AND (@Category IS NULL OR n.WaitDescription COLLATE Latin1_General_CI_AS_KS_WS=@Category COLLATE Latin1_General_CI_AS_KS_WS
      OR CONVERT(nvarchar(10),n.WaitCategory) COLLATE SQL_Latin1_General_CP1_CS_AS=@Category COLLATE SQL_Latin1_General_CP1_CS_AS)
    GROUP BY DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,WaitCategory,WaitDescription,ExecutionDescription,SqlText)
   INSERT #ExampleWaitsExpected SELECT DatabaseId,DatabaseName,QueryId,PlanId,QueryHash,PlanHash,WaitCategory,WaitDescription,ExecutionDescription,
    FirstStart,LastEnd,RecordedRows,TotalWait,CONVERT(decimal(38,3),AverageWait),MaxWait,
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN SqlText ELSE LEFT(SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    'QUERY_STORE',N'sys.query_store_wait_stats|sys.query_store_plan|sys.query_store_query_text',@At,'DATABASE_QUERY_PLAN_INTERVAL',1,
    CONVERT(bigint,LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1),CONVERT(bigint,DATALENGTH(SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    N'Query-Store-Intervalaggregate; keine aktuelle Einzelausführung und keine vollständige Wait-Timeline.' FROM Totals;
   SELECT @Count=COUNT_BIG(*) FROM #ExampleWaitsExpected;
   IF (@Case IN(20,21,30,31,32,36) AND @Count<>4) OR (@Case IN(33,34,35,37,38) AND @Count<>0) THROW 57814,N'WAITS_NATIVE_FILTER_COUNTS',1;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @Count>@Max THEN @Max ELSE @Count END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max>0 AND @Count>@Max THEN N'true' ELSE N'false' END THROW 57815,N'WAITS_NATIVE_COUNTS',1;
   SET @Sql=N'IF EXISTS(SELECT 1 FROM #ExampleWaitsExport a WHERE NOT EXISTS(SELECT 1 FROM #ExampleWaitsExpected e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.PlanId=a.PlanId AND e.WaitCategory=a.WaitCategory AND e.ExecutionTypeDesc=a.ExecutionTypeDesc))
    OR EXISTS(SELECT QueryStoreDatabaseId,PlanId,WaitCategory,ExecutionTypeDesc FROM #ExampleWaitsExport GROUP BY QueryStoreDatabaseId,PlanId,WaitCategory,ExecutionTypeDesc HAVING COUNT(*)<>1) THROW 57816,N''WAITS_NATIVE_KEYS'',1;
    ;WITH r AS(SELECT *,DENSE_RANK() OVER(ORDER BY TotalQueryWaitTimeMs DESC,LastIntervalEndUtc DESC) NativeRank FROM #ExampleWaitsExpected)
    SELECT @bad=COUNT_BIG(*) FROM r e JOIN r a ON e.NativeRank<a.NativeRank
     WHERE EXISTS(SELECT 1 FROM #ExampleWaitsExport x WHERE x.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND x.PlanId=a.PlanId AND x.WaitCategory=a.WaitCategory AND x.ExecutionTypeDesc=a.ExecutionTypeDesc)
      AND NOT EXISTS(SELECT 1 FROM #ExampleWaitsExport x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.PlanId=e.PlanId AND x.WaitCategory=e.WaitCategory AND x.ExecutionTypeDesc=e.ExecutionTypeDesc);
    DELETE e FROM #ExampleWaitsExpected e WHERE NOT EXISTS(SELECT 1 FROM #ExampleWaitsExport a WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.PlanId=e.PlanId AND a.WaitCategory=e.WaitCategory AND a.ExecutionTypeDesc=e.ExecutionTypeDesc);';
   SET @BadRank=0;EXEC sys.sp_executesql @Sql,N'@bad bigint OUTPUT',@BadRank OUTPUT;
   IF @BadRank<>0 THROW 57817,N'WAITS_GLOBAL_RANK',1;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleWaitsExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.waitStats') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.waitStats') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 57818,N'WAITS_NATIVE_FULL_FIELDS',1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleWaitsExport;
  FETCH NEXT FROM [Cases176] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@Category,@QueryId,@QueryHash,@RefPattern,@Invalid;
 END;
 CLOSE [Cases176];DEALLOCATE [Cases176];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>21 THROW 57819,N'WAITS_NATIVE_CASES',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC [monitor].[USP_QueryStoreWaitStats] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@VonUtc=@From,@BisUtc=@To,
    @MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.waitStats'))<>CASE WHEN @Max=0 THEN 4 ELSE @Max END OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE'
    OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max=0 THEN N'false' ELSE N'true' END OR @@LOCK_TIMEOUT<>137 THROW 57820,N'WAITS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @DirectConsoleCases+=1;SET @Direct+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleWaitsEmptyConsole;SET @Max=CASE @Empty WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleWaitsEmptyConsole EXEC [monitor].[USP_QueryStoreWaitStats] @QueryStoreDatabaseNames=@MissingScope,@HighImpactConfirmed=1,@MaxZeilen=@Max,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleWaitsEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleWaitsEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.waitStats')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 57821,N'WAITS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0,@Mode varchar(16);
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'UNSUPPORTED' END;
  SET @Max=CASE WHEN @Consumer=1 THEN -1 ELSE 1 END;SET @TextLimit=CASE WHEN @Consumer=0 THEN -1 ELSE 4000 END;
  EXEC [monitor].[USP_QueryStoreWaitStats] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,
   @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.waitStats')<>N'[]'
   OR @@LOCK_TIMEOUT<>137 THROW 57822,N'WAITS_INVALID_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleWaitsPreflight"}' WHEN 2 THEN N'{"waitStats":"#ExampleMissingTarget176"}'
   WHEN 3 THEN N'{"waitStats":"ExamplePermanent"}' WHEN 4 THEN N'{"waitStats":"#ExampleWaitsPreflight","unknown":"#ExampleWaitsPreflight"}' ELSE N'{"waitStats":"#ExampleWaitsPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC [monitor].[USP_QueryStoreWaitStats] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWaitsPreflight'))<>1 THROW 57823,N'WAITS_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>14 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3 THROW 57824,N'WAITS_CASE_COUNTS',1;
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
