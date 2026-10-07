USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
P3: Prüft die vorhandenen 22 Query- und 28 Planfelder sowie den gemeinsamen
globalen Queryexport. Allgemeine Fälle wählen einen nachweislich fehlenden
Datenbanknamen; N'' bedeutet keine Einschränkung. Der positive Block liest nur
zwei extern vorbereitete eigene Unicode-Datenbanken mit READ_ONLY Query Store.
Ohne passende Fixture bleibt ausschließlich dieser Block NOT_EXECUTED.
Der Test erzeugt keine Quellenobjekte, führt keine Fixture-Procedures aus und
ändert weder Planbindungen noch Query-Store-Optionen.
Summaryfilter gelten vor der Aggregation; zu exportierten Querykeys gehören
weiterhin alle gespeicherten Pläne. Exakte Cross-DB-Referenzlisten bleiben
außerhalb dieser Fixture; Common193 prüft ihren gemeinsamen Vertrag.
Positive CONSOLE-Zeilen und RAW-Parität benötigen unabhängigen Clientcapture.
*/
SET NOCOUNT ON;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 57500,N'PLAN_CHANGES_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 57501,N'PLAN_CHANGES_FRAMEWORK_COLLATION',1;
DECLARE @UpperName nvarchar(128)=N'ExamplePlanChangeÄ🔬',@LowerName nvarchar(128)=N'examplePlanChangeÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingPlanChangeÄ🔬',@MissingScope nvarchar(258);
SET @MissingScope=QUOTENAME(@MissingName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 57502,N'PLAN_CHANGES_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
SELECT @UpperId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END),
       @LowerId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END)
FROM master.sys.databases;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;

/* Unabhängige Schemas, native relative Ordinale, Typen und Nullability. */
CREATE TABLE #ExampleChangesQuerySchema
(
 [QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[QueryHash] binary(8) NULL,[ObjectId] bigint NULL,
 [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PlanCount] bigint NULL,[ForcedPlanCount] bigint NULL,[DistinctPlanHashCount] bigint NULL,
 [FirstCompileTimeUtc] datetimeoffset(7) NULL,[LastCompileTimeUtc] datetimeoffset(7) NULL,[LastExecutionTimeUtc] datetimeoffset(7) NULL,
 [TotalCompiles] bigint NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,
 [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleChangesPlanSchema
(
 [QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[PlanId] bigint NULL,[QueryPlanHash] binary(8) NULL,
 [EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CompatibilityLevel] smallint NULL,
 [IsParallelPlan] bit NULL,[IsForcedPlan] bit NULL,
 [PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ForceFailureCount] bigint NULL,[LastForceFailureReason] int NULL,
 [LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CountCompiles] bigint NULL,
 [InitialCompileStartTimeUtc] datetimeoffset(7) NULL,[LastCompileStartTimeUtc] datetimeoffset(7) NULL,[LastExecutionTimeUtc] datetimeoffset(7) NULL,
 [AverageCompileDurationMs] decimal(38,3) NULL,[LastCompileDurationMs] decimal(38,3) NULL,
 [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PlanSourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PlanSourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCapturedAtUtc] datetime2(3) NULL,
 [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
SELECT TOP(0) * INTO #ExampleChangesExpectedQueries FROM #ExampleChangesQuerySchema;
SELECT TOP(0) * INTO #ExampleChangesExpectedPlans FROM #ExampleChangesPlanSchema;
CREATE TABLE #ExampleChangesNative
(
 [DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[QueryHash] binary(8) NULL,[ObjectId] int NULL,
 [ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanId] bigint NOT NULL,[PlanHash] binary(8) NULL,
 [EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CompatibilityLevel] smallint NULL,
 [Parallel] bit NULL,[Forced] bit NULL,[ForcingType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [FailureCount] bigint NULL,[FailureReason] int NULL,[FailureDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Compiles] bigint NULL,[InitialCompile] datetimeoffset(7) NULL,[LastCompile] datetimeoffset(7) NULL,[ExecutionTime] datetimeoffset(7) NULL,
 [AverageCompileMs] decimal(38,3) NULL,[LastCompileMs] decimal(38,3) NULL,
 [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleChangesOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[FixtureObjectCount] int NOT NULL);
CREATE TABLE #ExampleChangesEmptyConsole
([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleChangesPreflight([Dummy] int NULL);
CREATE TABLE #ExampleChangesCases
([CaseNumber] int NOT NULL,[IsNative] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,
 [OnlyMultiple] bit NULL,[PlanXml] bit NULL,[Mode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryId] bigint NULL,[QueryHash] binary(8) NULL,[SinceUtc] datetime2(7) NULL,
 [ReferenceNames] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ReferencePattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExpectedInvalid] bit NOT NULL);
INSERT #ExampleChangesCases VALUES
 (0,0,@MissingScope,NULL,NULL,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
 (1,0,@MissingScope,NULL,0,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
 (2,0,@MissingScope,NULL,1,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
 (3,0,@MissingScope,NULL,2,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
 (4,0,@MissingScope,NULL,-1,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,1),
 (5,0,@MissingScope,NULL,1,-1,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,1),
 (6,0,@MissingScope,NULL,1,4000,1,0,'INVALID',NULL,NULL,NULL,NULL,NULL,1),
 (7,0,N'[ExampleInvalid',NULL,1,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,1),
 (8,0,@MissingScope,NULL,1,4000,1,0,'TOP',NULL,NULL,NULL,N'[ExampleInvalid',NULL,1),
 (9,0,@MissingScope,NULL,1,NULL,NULL,0,NULL,NULL,NULL,NULL,NULL,NULL,0),
 (10,0,@MissingScope,NULL,1,0,0,1,'VOLL',NULL,NULL,NULL,NULL,NULL,0);
DECLARE @Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0,@Both nvarchar(max);
IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleChangesOptions SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,
    (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExamplePlanChangeOneÄ🔬'',N''ExamplePlanChangeTwoÄ🔬'',N''ExamplePlanChangeSingleÄ🔬''))
   FROM sys.database_query_store_options;
   INSERT #ExampleChangesNative
   SELECT DB_ID(),DB_NAME(),q.query_id,q.query_hash,q.object_id,
    CASE WHEN q.object_id>0 THEN QUOTENAME(s.name)+N''.''+QUOTENAME(o.name) END,p.plan_id,p.query_plan_hash,p.engine_version,p.compatibility_level,
    p.is_parallel_plan,p.is_forced_plan,p.plan_forcing_type_desc,p.force_failure_count,p.last_force_failure_reason,p.last_force_failure_reason_desc,
    p.count_compiles,p.initial_compile_start_time,p.last_compile_start_time,p.last_execution_time,
    CONVERT(decimal(38,3),p.avg_compile_duration/1000.0),CONVERT(decimal(38,3),p.last_compile_duration/1000.0),qt.query_sql_text,p.query_plan
   FROM sys.query_store_plan p JOIN sys.query_store_query q ON q.query_id=p.query_id
   JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id
   LEFT JOIN sys.objects o ON o.object_id=q.object_id LEFT JOIN sys.schemas s ON s.schema_id=o.schema_id;';
  EXEC sys.sp_executesql @Sql;SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleChangesOptions)=2
    AND NOT EXISTS(SELECT 1 FROM #ExampleChangesOptions WHERE ActualState<>1 OR DesiredState<>1 OR FixtureObjectCount<>3)
    AND NOT EXISTS(SELECT DatabaseId FROM #ExampleChangesNative GROUP BY DatabaseId HAVING COUNT(*)<>5 OR COUNT(DISTINCT QueryId)<>3)
    AND (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId FROM #ExampleChangesNative GROUP BY DatabaseId,QueryId HAVING COUNT(*)=2) q)=4
    AND (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId FROM #ExampleChangesNative GROUP BY DatabaseId,QueryId HAVING COUNT(*)=1) q)=2
    AND (SELECT COUNT(*) FROM #ExampleChangesNative)=10
    AND (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId FROM #ExampleChangesNative GROUP BY DatabaseId,QueryId) q)=6
    AND NOT EXISTS(SELECT 1 FROM #ExampleChangesNative WHERE ObjectName IS NULL OR ObjectName COLLATE SQL_Latin1_General_CP1_CS_AS NOT IN
       (N'[dbo].[ExamplePlanChangeOneÄ🔬]',N'[dbo].[ExamplePlanChangeTwoÄ🔬]',N'[dbo].[ExamplePlanChangeSingleÄ🔬]') OR PlanText IS NULL)
 BEGIN
  SELECT @UpperLevel=[Level] FROM #ExampleChangesOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleChangesOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel THROW 57503,N'PLAN_CHANGES_SOURCE_LEVELS',1;
  SET @FixtureStatus='PENDING';SET @Both=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);
  DECLARE @OneQuery bigint=(SELECT MIN(QueryId) FROM #ExampleChangesNative WHERE DatabaseId=@UpperId);
  DECLARE @OneHash binary(8)=(SELECT TOP(1) QueryHash FROM #ExampleChangesNative WHERE DatabaseId=@UpperId ORDER BY QueryId,PlanId);
  DECLARE @Since datetime2(7)=(SELECT CONVERT(datetime2(7),MAX(LastCompile)) FROM #ExampleChangesNative n
   WHERE EXISTS(SELECT 1 FROM #ExampleChangesNative x WHERE x.DatabaseId=n.DatabaseId AND x.QueryId=n.QueryId
                GROUP BY x.DatabaseId,x.QueryId HAVING COUNT(*)=2));
  INSERT #ExampleChangesCases VALUES
   (20,1,@Both,NULL,NULL,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (21,1,@Both,NULL,0,4000,0,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (22,1,@Both,NULL,1,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (23,1,@Both,NULL,2,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (24,1,@Both,NULL,2,5,1,1,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (25,1,QUOTENAME(@UpperName),NULL,0,0,0,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (26,1,QUOTENAME(@LowerName),NULL,0,NULL,0,0,'VOLL',NULL,NULL,NULL,NULL,NULL,0),
   (27,1,NULL,N'like:'+@UpperName,0,4000,0,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (28,1,@Both,NULL,0,4000,NULL,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (29,1,QUOTENAME(@UpperName),NULL,0,4000,0,0,'TOP',@OneQuery,NULL,NULL,NULL,NULL,0),
   (30,1,@Both,NULL,0,4000,0,0,'TOP',NULL,@OneHash,NULL,NULL,NULL,0),
   (31,1,@Both,NULL,0,4000,0,1,'TOP',NULL,NULL,@Since,NULL,NULL,0),
   (32,1,@Both,NULL,2,4000,0,1,'TOP',NULL,NULL,NULL,NULL,N'like:'+@UpperName,0),
   (33,1,@Both,NULL,1,4000,0,0,'TOP',NULL,NULL,CONVERT(datetime2(7),'9999-01-01'),NULL,NULL,0),
   (34,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,1,4000,1,0,'TOP',NULL,NULL,NULL,NULL,NULL,0),
   (35,1,N'[EXAMPLEPlanChangeÄ🔬]',NULL,1,4000,0,0,'TOP',NULL,NULL,NULL,NULL,NULL,0);
 END;
END;
DECLARE @QueryColumns nvarchar(max)=N'[QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[QueryHash],[ObjectId],[ObjectName],[PlanCount],[ForcedPlanCount],[DistinctPlanHashCount],[FirstCompileTimeUtc],[LastCompileTimeUtc],[LastExecutionTimeUtc],[TotalCompiles],[QuerySqlText],[SourceType],[SourceObject],[CapturedAtUtc],[EvidenceScope],[QuerySqlTextCharacters],[QuerySqlTextBytes],[QuerySqlTextIsTruncated],[EvidenceLimit]';
DECLARE @PlanColumns nvarchar(max)=N'[QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[PlanId],[QueryPlanHash],[EngineVersion],[CompatibilityLevel],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc],[ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc],[CountCompiles],[InitialCompileStartTimeUtc],[LastCompileStartTimeUtc],[LastExecutionTimeUtc],[AverageCompileDurationMs],[LastCompileDurationMs],[QueryPlanTextFallback],[PlanSourceType],[PlanSourceObject],[PlanCapturedAtUtc],[QueryPlanStatus],[QueryPlanCharacters],[QueryPlanBytes],CONVERT(nvarchar(max),[QueryPlan]) AS [QueryPlan],[EvidenceLimit]';
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@Multiple bit,@Plan bit,@Mode varchar(16),@QueryId bigint,@QueryHash binary(8),@SinceUtc datetime2(7),@References nvarchar(max),@ReferencePattern nvarchar(4000),@Invalid bit;
DECLARE @Json nvarchar(max),@QueryJson nvarchar(max),@PlanJson nvarchar(max),@ExpectedQueryJson nvarchar(max),@ExpectedPlanJson nvarchar(max),@Generated datetime2(3),@Before datetime2(3),@After datetime2(3),@Rows bigint,@NativeCount bigint,@ExpectedRows bigint,@HasMore bit;
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases173] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleChangesCases ORDER BY CaseNumber;
 OPEN [Cases173];
 FETCH NEXT FROM [Cases173] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@Multiple,@Plan,@Mode,@QueryId,@QueryHash,@SinceUtc,@References,@ReferencePattern,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleChangesQueries([Dummy] int NULL);
  CREATE TABLE #ExampleChangesPlans([Dummy] int NULL);
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStorePlanChanges]
    @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
    @ReferencedDatabaseNames=@References,@ReferencedDatabaseNamePattern=@ReferencePattern,@QueryId=@QueryId,@QueryHash=@QueryHash,
    @VonUtc=@SinceUtc,@NurMehrerePlaene=@Multiple,@MitPlanXml=@Plan,@AnalyseModus=@Mode,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,
    @ResultSetArt='TABLE',@ResultTablesJson=N'{"queries":"#ExampleChangesQueries","plans":"#ExampleChangesPlans"}',
    @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57504,N'PLAN_CHANGES_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 57505,N'PLAN_CHANGES_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>4
     OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'queries',4),(N'plans',4),(N'warnings',4)) e(k,t))
     OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>7
     OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) e(k))
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1) OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'hasMoreRows' AND [type]<>3))
     OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
     OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStorePlanChanges'
     OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>2
      THROW 57506,N'PLAN_CHANGES_META',1;
  SET @Generated=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @Generated IS NULL OR @Generated<@Before OR @Generated>@After THROW 57507,N'PLAN_CHANGES_CAPTURE_TIME',1;
  IF EXISTS
  (
   SELECT t.Kind,ROW_NUMBER() OVER(PARTITION BY t.Kind ORDER BY c.column_id),c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.collation_name,c.is_nullable,c.is_identity
   FROM (VALUES(N'queries',OBJECT_ID(N'tempdb..#ExampleChangesQueries')),(N'plans',OBJECT_ID(N'tempdb..#ExampleChangesPlans'))) t(Kind,Id)
   JOIN tempdb.sys.columns c ON c.object_id=t.Id
   EXCEPT
   SELECT t.Kind,ROW_NUMBER() OVER(PARTITION BY t.Kind ORDER BY c.column_id),c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.collation_name,c.is_nullable,c.is_identity
   FROM (VALUES(N'queries',OBJECT_ID(N'tempdb..#ExampleChangesQuerySchema')),(N'plans',OBJECT_ID(N'tempdb..#ExampleChangesPlanSchema'))) t(Kind,Id)
   JOIN tempdb.sys.columns c ON c.object_id=t.Id
  ) OR EXISTS
  (
   SELECT t.Kind,ROW_NUMBER() OVER(PARTITION BY t.Kind ORDER BY c.column_id),c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.collation_name,c.is_nullable,c.is_identity
   FROM (VALUES(N'queries',OBJECT_ID(N'tempdb..#ExampleChangesQuerySchema')),(N'plans',OBJECT_ID(N'tempdb..#ExampleChangesPlanSchema'))) t(Kind,Id)
   JOIN tempdb.sys.columns c ON c.object_id=t.Id
   EXCEPT
   SELECT t.Kind,ROW_NUMBER() OVER(PARTITION BY t.Kind ORDER BY c.column_id),c.name,c.system_type_id,c.max_length,c.precision,c.scale,c.collation_name,c.is_nullable,c.is_identity
   FROM (VALUES(N'queries',OBJECT_ID(N'tempdb..#ExampleChangesQueries')),(N'plans',OBJECT_ID(N'tempdb..#ExampleChangesPlans'))) t(Kind,Id)
   JOIN tempdb.sys.columns c ON c.object_id=t.Id
  ) THROW 57508,N'PLAN_CHANGES_SCHEMA',1;
  SET @Sql=N'SELECT @q=(SELECT '+@QueryColumns+N' FROM #ExampleChangesQueries FOR JSON PATH,INCLUDE_NULL_VALUES),
   @p=(SELECT '+@PlanColumns+N' FROM #ExampleChangesPlans FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleChangesQueries);
   IF EXISTS(SELECT 1 FROM #ExampleChangesPlans p WHERE NOT EXISTS(SELECT 1 FROM #ExampleChangesQueries q WHERE q.QueryStoreDatabaseId=p.QueryStoreDatabaseId AND q.QueryId=p.QueryId))
      THROW 57509,N''PLAN_CHANGES_EXPORT_KEYS'',1;';
  EXEC sys.sp_executesql @Sql,N'@q nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT,@r bigint OUTPUT',@QueryJson OUTPUT,@PlanJson OUTPUT,@Rows OUTPUT;
  IF @Rows<>TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows'))
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queries') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>22)
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.plans') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>28)
      THROW 57510,N'PLAN_CHANGES_JSON_FIELDS',1;
  DECLARE @Array int=0,@ActualArray nvarchar(max),@JsonArray nvarchar(max);
  WHILE @Array<2
  BEGIN
   SET @ActualArray=CASE @Array WHEN 0 THEN @QueryJson ELSE @PlanJson END;
   SET @JsonArray=JSON_QUERY(@Json,CASE @Array WHEN 0 THEN N'$.queries' ELSE N'$.plans' END);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ActualArray,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
       EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2
       EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ActualArray,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
       THROW 57511,N'PLAN_CHANGES_TABLE_JSON',1;
   SET @Array+=1;
  END;
  IF @Invalid=1 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER' OR @Rows<>0)
      THROW 57512,N'PLAN_CHANGES_INVALID_PARAMETER',1;
  IF @Invalid=0 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>'AVAILABLE' OR JSON_QUERY(@Json,N'$.warnings')<>N'[]')
      THROW 57513,N'PLAN_CHANGES_AVAILABLE_STATUS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_QUERY(@Json,N'$.plans')<>N'[]' OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false'
       THROW 57514,N'PLAN_CHANGES_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleChangesExpectedQueries;TRUNCATE TABLE #ExampleChangesExpectedPlans;
   /* Sourceplanfilter und HAVING wirken nur auf diese Aggregation. */
   INSERT #ExampleChangesExpectedQueries
   SELECT n.DatabaseId,n.DatabaseName,n.QueryId,n.QueryHash,n.ObjectId,n.ObjectName,
    COUNT_BIG(*),SUM(CONVERT(bigint,n.Forced)),COUNT(DISTINCT CONVERT(varchar(18),n.PlanHash,1)),
    MIN(n.InitialCompile),MAX(n.LastCompile),MAX(n.ExecutionTime),SUM(n.Compiles),
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN n.SqlText ELSE LEFT(n.SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    'QUERY_STORE',N'sys.query_store_query|sys.query_store_plan|sys.query_store_query_text',@Generated,'DATABASE_QUERY',
    CASE WHEN n.SqlText IS NULL THEN NULL ELSE CONVERT(bigint,LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
    CONVERT(bigint,DATALENGTH(n.SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    N'Query-Store-Kompilierungs- und Ausführungsmetadaten; keine aktuelle Einzelausführung.'
   FROM #ExampleChangesNative n CROSS APPLY(SELECT CONVERT(xml,n.PlanText) PlanXml) px
   WHERE (@Names IS NULL OR @Names=@Both OR @Names=QUOTENAME(n.DatabaseName) OR (@Case=34 AND n.DatabaseId=@UpperId))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@QueryId IS NULL OR n.QueryId=@QueryId) AND (@QueryHash IS NULL OR n.QueryHash=@QueryHash)
     AND (@SinceUtc IS NULL OR n.LastCompile>=@SinceUtc OR n.ExecutionTime>=@SinceUtc)
     AND (@ReferencePattern IS NULL OR EXISTS
       (SELECT 1 FROM px.PlanXml.nodes('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]') x(n)
        WHERE PARSENAME(x.n.value('@Database','nvarchar(776)'),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@ReferencePattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS))
   GROUP BY n.DatabaseId,n.DatabaseName,n.QueryId,n.QueryHash,n.ObjectId,n.ObjectName,n.SqlText
   HAVING @Multiple=0 OR COUNT_BIG(*)>1;
   SELECT @NativeCount=COUNT_BIG(*) FROM #ExampleChangesExpectedQueries;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @NativeCount>@Max THEN @Max ELSE @NativeCount END;
   SET @HasMore=CASE WHEN @Max>0 AND @NativeCount>@Max THEN 1 ELSE 0 END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @HasMore=1 THEN N'true' ELSE N'false' END
       THROW 57515,N'PLAN_CHANGES_NATIVE_COUNT',1;
   /* Bestehende Sortties bleiben zulässig; kein strenger höherer Rang fehlt. */
   SET @Sql=N'
    IF EXISTS(SELECT 1 FROM #ExampleChangesQueries a WHERE NOT EXISTS(SELECT 1 FROM #ExampleChangesExpectedQueries e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.QueryId=a.QueryId))
      OR EXISTS(SELECT QueryStoreDatabaseId,QueryId FROM #ExampleChangesQueries GROUP BY QueryStoreDatabaseId,QueryId HAVING COUNT(*)<>1)
      THROW 57516,N''PLAN_CHANGES_NATIVE_IDENTITIES'',1;
    ;WITH r AS(SELECT *,DENSE_RANK() OVER(ORDER BY LastExecutionTimeUtc DESC,LastCompileTimeUtc DESC) AS NativeRank FROM #ExampleChangesExpectedQueries)
    SELECT @bad=COUNT_BIG(*) FROM r e JOIN r a ON e.NativeRank<a.NativeRank
     WHERE EXISTS(SELECT 1 FROM #ExampleChangesQueries x WHERE x.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND x.QueryId=a.QueryId)
       AND NOT EXISTS(SELECT 1 FROM #ExampleChangesQueries x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.QueryId=e.QueryId);
    DELETE e FROM #ExampleChangesExpectedQueries e WHERE NOT EXISTS(SELECT 1 FROM #ExampleChangesQueries a WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.QueryId=e.QueryId);
    INSERT #ExampleChangesExpectedPlans
    SELECT n.DatabaseId,n.DatabaseName,n.QueryId,n.PlanId,n.PlanHash,n.EngineVersion,n.CompatibilityLevel,n.Parallel,n.Forced,n.ForcingType,
     n.FailureCount,n.FailureReason,n.FailureDescription,n.Compiles,n.InitialCompile,n.LastCompile,n.ExecutionTime,n.AverageCompileMs,n.LastCompileMs,
     NULL,''QUERY_STORE'',N''sys.query_store_plan'',@At,CASE WHEN @xml=1 THEN ''AVAILABLE'' ELSE ''NOT_REQUESTED'' END,
     CASE WHEN @xml=1 THEN CONVERT(bigint,LEN((n.PlanText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
     CASE WHEN @xml=1 THEN CONVERT(bigint,DATALENGTH(n.PlanText)) END,CASE WHEN @xml=1 THEN CONVERT(xml,n.PlanText) END,
     N''Gespeicherter Query-Store-Plan; kein aktueller Laufzeitplan.''
    FROM #ExampleChangesNative n WHERE EXISTS(SELECT 1 FROM #ExampleChangesQueries q WHERE q.QueryStoreDatabaseId=n.DatabaseId AND q.QueryId=n.QueryId);';
   DECLARE @BadRank bigint=0;
   EXEC sys.sp_executesql @Sql,N'@bad bigint OUTPUT,@At datetime2(3),@xml bit',@BadRank OUTPUT,@Generated,@Plan;
   IF @BadRank<>0 THROW 57517,N'PLAN_CHANGES_GLOBAL_RANK',1;
   IF @Case=31 AND NOT EXISTS
      (SELECT 1 FROM #ExampleChangesExpectedQueries q
       WHERE q.PlanCount=1 AND (SELECT COUNT_BIG(*) FROM #ExampleChangesExpectedPlans p
             WHERE p.QueryStoreDatabaseId=q.QueryStoreDatabaseId AND p.QueryId=q.QueryId)=2)
       THROW 57527,N'PLAN_CHANGES_FILTERED_SUMMARY_FULL_PLAN_DETAILS',1;
   SET @Sql=N'SELECT @q=(SELECT '+@QueryColumns+N' FROM #ExampleChangesExpectedQueries FOR JSON PATH,INCLUDE_NULL_VALUES),
       @p=(SELECT '+@PlanColumns+N' FROM #ExampleChangesExpectedPlans FOR JSON PATH,INCLUDE_NULL_VALUES);';
   EXEC sys.sp_executesql @Sql,N'@q nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT',@ExpectedQueryJson OUTPUT,@ExpectedPlanJson OUTPUT;
   SET @Array=0;
   WHILE @Array<2
   BEGIN
    SET @ActualArray=CASE @Array WHEN 0 THEN @ExpectedQueryJson ELSE @ExpectedPlanJson END;
    SET @JsonArray=JSON_QUERY(@Json,CASE @Array WHEN 0 THEN N'$.queries' ELSE N'$.plans' END);
    IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ActualArray,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
        EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2)
       OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2
        EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ActualArray,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
        THROW 57518,N'PLAN_CHANGES_NATIVE_FULL_FIELDS',1;
    SET @Array+=1;
   END;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleChangesQueries;DROP TABLE #ExampleChangesPlans;
  FETCH NEXT FROM [Cases173] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@Multiple,@Plan,@Mode,@QueryId,@QueryHash,@SinceUtc,@References,@ReferencePattern,@Invalid;
 END;
 CLOSE [Cases173];DEALLOCATE [Cases173];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>16 THROW 57519,N'PLAN_CHANGES_NATIVE_CASES',1;
  EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@MaxZeilen=1,
       @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queries'))<>1 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'true'
      THROW 57520,N'PLAN_CHANGES_DIRECT_CONSOLE_ONE',1;
  SET @DirectConsoleCases+=1;
  EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@MaxZeilen=2,
       @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queries'))<>2 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'true'
      THROW 57521,N'PLAN_CHANGES_DIRECT_CONSOLE_TWO',1;
  SET @DirectConsoleCases+=1;SET @Names=QUOTENAME(@UpperName);
  EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@Names,@HighImpactConfirmed=1,@NurMehrerePlaene=0,@MaxZeilen=0,
       @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queries'))<>3 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.plans'))<>5
      THROW 57522,N'PLAN_CHANGES_DIRECT_CONSOLE_ALL',1;
  SET @DirectConsoleCases+=1;SET @FixtureStatus='PASS';
 END;
 DECLARE @EmptyCase int=0;
 WHILE @EmptyCase<3
 BEGIN
  TRUNCATE TABLE #ExampleChangesEmptyConsole;
  SET @Max=CASE @EmptyCase WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleChangesEmptyConsole
  EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@HighImpactConfirmed=1,@MaxZeilen=@Max,
       @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleChangesEmptyConsole)<>1
     OR EXISTS(SELECT 1 FROM #ExampleChangesEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
     OR JSON_QUERY(@Json,N'$.queries')<>N'[]' OR JSON_QUERY(@Json,N'$.plans')<>N'[]' OR @@LOCK_TIMEOUT<>137
      THROW 57523,N'PLAN_CHANGES_EMPTY_CONSOLE',1;
  SET @EmptyConsoleCases+=1;SET @EmptyCase+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<3
 BEGIN
  SET @Json=N'ExamplePreviousJson';
  IF @Consumer=0
   EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  ELSE IF @Consumer=1
   EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=-1,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  ELSE
   EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=1,@ResultSetArt='UNSUPPORTED',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER'
     OR JSON_QUERY(@Json,N'$.queries')<>N'[]' OR JSON_QUERY(@Json,N'$.plans')<>N'[]'
      THROW 57524,N'PLAN_CHANGES_INVALID_CONSUMER',1;
  SET @ConsumerCases+=1;SET @Consumer+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleChangesPreflight"}'
      WHEN 2 THEN N'{"queries":"#ExampleMissingTarget173"}' WHEN 3 THEN N'{"queries":"ExamplePermanent"}'
      WHEN 4 THEN N'{"queries":"#ExampleChangesPreflight","plans":"#ExampleChangesPreflight"}'
      ELSE N'{"queries":"#ExampleChangesPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   IF @Preflight=5
    EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt='NONE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
   ELSE
    EXEC [monitor].[USP_QueryStorePlanChanges] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleChangesPreflight'))<>1
      THROW 57525,N'PLAN_CHANGES_MAPPING_PREFLIGHT',1;
  SET @PreflightCases+=1;SET @Preflight+=1;
 END;
 IF @CoreCases<>11 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3
     THROW 57526,N'PLAN_CHANGES_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,@UpperLevel AS UpperSourceCompatibilityLevel,
        @LowerLevel AS LowerSourceCompatibilityLevel,@CoreCases AS CoreCases,@ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,
        @FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,@EmptyConsoleCases AS EmptySqlConsoleCases,
        @DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
