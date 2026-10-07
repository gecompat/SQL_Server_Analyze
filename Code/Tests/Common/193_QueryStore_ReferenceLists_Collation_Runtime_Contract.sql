USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft die exakten Cross-DB-Referenzlisten von fünf Query-Store-Modulen.
Sechs unabhängige Literalvorlagen enthalten 172 Felder und 53 Textcollations.
TABLE und JSON werden im selben Aufruf einschließlich NULL, JSON-Typen und
Multisethäufigkeiten verglichen. Der optionale positive Block liest nur zwei
extern vorbereitete eigene CI-Datenbanken mit READ_ONLY Query Store. Er leitet
Fenster und Queryidentitäten aus nativen Katalogen ab und verändert keine Fixture.
Ohne passende Fixture bleibt nur dieser Block NOT_EXECUTED. Weitere Katalogqueries
werden nicht als Fixturefehler behandelt. Die positiven Fälle wählen die eigene
SUM-Query über ihre native ID. Gleiche globale Rangwerte erlauben verschiedene
Auswahlen zwischen Aufrufen. PlanChanges behält alle Details ausgewählter Keys.
Positive RAW-/CONSOLE-Vollzeilen benötigen zusätzlichen Clientcapture. Parentfälle
prüfen das tatsächliche Child-JSON; EXECUTED allein ist kein Reparaturnachweis.
Der Parent verwendet seine unveränderten DURATION_AVG-Defaults; positive
EXECUTIONS-Regressionen der direkten Fälle werden ihm nicht zugeschrieben.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 59600,N'REFERENCES_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 59601,N'REFERENCES_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Db sysname,@DbIndex int=0;
DECLARE @Upper sysname=N'ExampleQSRefÄ🔬|O''Case]',@Lower sysname=N'exampleQSRefÄ🔬|O''Case]',
 @Missing sysname=N'ExampleMissingReferencesÄ🔬',@FixtureStatus varchar(24)='NOT_EXECUTED';
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@Missing COLLATE SQL_Latin1_General_CP1_CS_AS)
 THROW 59602,N'REFERENCES_MISSING_NAME',1;
DECLARE @Both nvarchar(max)=QUOTENAME(@Upper)+N'|'+QUOTENAME(@Lower),@MissingScope nvarchar(258)=QUOTENAME(@Missing);
DECLARE @BFrom datetime2(7)=DATEADD(HOUR,-2,SYSUTCDATETIME()),@BTo datetime2(7),@CFrom datetime2(7),@CTo datetime2(7)=SYSUTCDATETIME();
SET @BTo=DATEADD(HOUR,1,@BFrom);SET @CFrom=@BTo;
CREATE TABLE #ExampleReferencesSchema1
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
CREATE TABLE #ExampleReferencesSchema2
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[PlanId] bigint NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[WaitCategory] tinyint NULL,
 [WaitCategoryDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionTypeDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [FirstIntervalStartUtc] datetimeoffset NULL,[LastIntervalEndUtc] datetimeoffset NULL,[RecordedRows] bigint NULL,[TotalQueryWaitTimeMs] bigint NULL,
 [AverageRecordedQueryWaitTimeMs] decimal(38,3) NULL,[MaxQueryWaitTimeMs] bigint NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleReferencesSchema3
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
CREATE TABLE #ExampleReferencesSchema4
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
CREATE TABLE #ExampleReferencesSchema5
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[QueryHash] binary(8) NULL,[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BaselineExecutions] bigint NULL,[ComparisonExecutions] bigint NULL,[BaselinePlanCount] bigint NULL,[ComparisonPlanCount] bigint NULL,
 [BaselineValue] decimal(38,3) NULL,[ComparisonValue] decimal(38,3) NULL,[AbsoluteChange] decimal(38,3) NULL,[RegressionPercent] decimal(38,3) NULL,
 [LastExecutionTimeUtc] datetimeoffset NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleReferencesSchema6
(
 [QueryStoreDatabaseId] int NULL,
 [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[PlanId] bigint NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,
 [ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsForcedPlan] bit NULL,[PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ForceFailureCount] bigint NULL,[LastForceFailureReason] int NULL,
 [LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CountCompiles] bigint NULL,[LastCompileStartTimeUtc] datetimeoffset(7) NULL,[LastExecutionTimeUtc] datetimeoffset(7) NULL,
 [EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CompatibilityLevel] smallint NULL,
 [QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,
 [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,
 [QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE #ExampleReferencesOptions(DatabaseId int NOT NULL,DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 Level int,CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS,ActualState int,DesiredState int,CaptureMode int,WaitMode int,
 IntervalMinutes int,UserRows bigint,ModuleOptions int,SourceParser int NULL);
CREATE TABLE #ExampleReferencesNative(DatabaseId int NOT NULL,DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 QueryId bigint NOT NULL,PlanId bigint NOT NULL,ObjectId int NOT NULL,IsOne bit NOT NULL,IsForced bit,
 IntervalStart datetimeoffset NOT NULL,IntervalEnd datetimeoffset NOT NULL,Executions bigint,
 RawReference nvarchar(776) COLLATE Latin1_General_100_BIN2 NULL);
CREATE TABLE #ExampleReferencesWaits(DatabaseId int,QueryId bigint,PlanId bigint,WaitCategory int,TotalWait float);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@Upper COLLATE SQL_Latin1_General_CP1_CS_AS)
 AND EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@Lower COLLATE SQL_Latin1_General_CP1_CS_AS)
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @Upper ELSE @Lower END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleReferencesOptions SELECT DB_ID(),DB_NAME(),d.compatibility_level,d.collation_name,o.actual_state,o.desired_state,o.query_capture_mode,o.wait_stats_capture_mode,o.interval_length_minutes,
    (SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE object_id=OBJECT_ID(N''dbo.ExampleQSRefValuesÄ🔬'') AND index_id IN(0,1)),
    (SELECT COUNT(*) FROM sys.sql_modules m WHERE m.object_id IN(OBJECT_ID(N''dbo.ExampleQSRefOneÄ🔬''),OBJECT_ID(N''dbo.ExampleQSRefTwoÄ🔬'')) AND uses_quoted_identifier=1 AND uses_ansi_nulls=1),
    OBJECT_ID(N''monitor.TVF_ParseSqlNameList'')
   FROM master.sys.databases d CROSS JOIN sys.database_query_store_options o WHERE d.database_id=DB_ID();
   INSERT #ExampleReferencesNative SELECT DB_ID(),DB_NAME(),q.query_id,p.plan_id,q.object_id,CONVERT(bit,CASE WHEN q.object_id=OBJECT_ID(N''dbo.ExampleQSRefOneÄ🔬'') THEN 1 ELSE 0 END),p.is_forced_plan,
    i.start_time,i.end_time,SUM(rs.count_executions),ref.RawReference
   FROM sys.query_store_query q JOIN sys.query_store_plan p ON p.query_id=q.query_id
    JOIN sys.query_store_runtime_stats rs ON rs.plan_id=p.plan_id AND rs.execution_type=0
    JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=rs.runtime_stats_interval_id
    CROSS APPLY(SELECT TRY_CONVERT(xml,p.query_plan) PlanXml) px
    CROSS APPLY px.PlanXml.nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') n(x)
    CROSS APPLY(SELECT n.x.value(''@Database'',''nvarchar(776)'') RawReference) ref
   WHERE q.object_id IN(OBJECT_ID(N''dbo.ExampleQSRefOneÄ🔬''),OBJECT_ID(N''dbo.ExampleQSRefTwoÄ🔬''))
   GROUP BY q.query_id,p.plan_id,q.object_id,p.is_forced_plan,i.start_time,i.end_time,ref.RawReference;
   INSERT #ExampleReferencesWaits SELECT DB_ID(),q.query_id,p.plan_id,ws.wait_category,SUM(ws.total_query_wait_time_ms)
   FROM sys.query_store_query q JOIN sys.query_store_plan p ON p.query_id=q.query_id JOIN sys.query_store_wait_stats ws ON ws.plan_id=p.plan_id AND ws.execution_type=0
   WHERE q.object_id=OBJECT_ID(N''dbo.ExampleQSRefOneÄ🔬'') GROUP BY q.query_id,p.plan_id,ws.wait_category;';
  EXEC sys.sp_executesql @Sql;
  SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleReferencesOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleReferencesOptions WHERE Level<>@FrameworkLevel OR CollationName<>N'Latin1_General_100_CI_AS' OR ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR WaitMode<>1 OR IntervalMinutes<>1 OR UserRows IS NULL OR UserRows<>4 OR ModuleOptions<>2 OR SourceParser IS NOT NULL)
  AND (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId FROM #ExampleReferencesNative GROUP BY DatabaseId,QueryId) q)=4
  AND (SELECT COUNT(*) FROM (SELECT IntervalStart,IntervalEnd FROM #ExampleReferencesNative GROUP BY IntervalStart,IntervalEnd) i)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleReferencesNative WHERE IsForced<>1 OR RawReference IS NULL OR RawReference<>QUOTENAME(DatabaseName) COLLATE Latin1_General_100_BIN2)
  AND (SELECT COUNT(*) FROM #ExampleReferencesWaits WHERE WaitCategory=3 AND TotalWait>0)=2
 BEGIN
  SELECT @BFrom=CONVERT(datetime2(7),MIN(IntervalStart)),@CTo=CONVERT(datetime2(7),MAX(IntervalEnd)) FROM #ExampleReferencesNative;
  SELECT @BTo=CONVERT(datetime2(7),IntervalEnd) FROM #ExampleReferencesNative WHERE CONVERT(datetime2(7),IntervalStart)=@BFrom;
  SELECT @CFrom=CONVERT(datetime2(7),IntervalStart) FROM #ExampleReferencesNative WHERE CONVERT(datetime2(7),IntervalEnd)=@CTo;
  IF @BTo=@CFrom AND DATEDIFF_BIG(SECOND,@BFrom,@BTo)=60 AND DATEDIFF_BIG(SECOND,@CFrom,@CTo)=60
   AND NOT EXISTS(SELECT DatabaseId,QueryId,IsOne,IntervalStart FROM #ExampleReferencesNative GROUP BY DatabaseId,QueryId,IsOne,IntervalStart
    HAVING COUNT(DISTINCT PlanId)<>1 OR SUM(Executions)<>CASE WHEN CONVERT(datetime2(7),IntervalStart)=@BFrom THEN 2 WHEN IsOne=1 THEN 8 ELSE 4 END)
   AND (SELECT COUNT(DISTINCT QueryId) FROM #ExampleReferencesNative WHERE IsOne=1)=1
   SET @FixtureStatus='PENDING';
 END;
END;
DECLARE @OwnQuery bigint=(SELECT MIN(QueryId) FROM #ExampleReferencesNative WHERE IsOne=1);
CREATE TABLE #ExampleReferencesCases(CaseNumber int PRIMARY KEY,IsNative bit,RefNames nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 RefPattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,HighImpact bit,MaxRows int NULL,ExpectedMask int,IsInvalid bit);
INSERT #ExampleReferencesCases VALUES(0,0,NULL,NULL,1,0,0,0),(1,0,N'',NULL,1,0,0,1),(2,0,N'   ',NULL,1,0,0,1),
 (3,0,N'[ExampleInvalid',NULL,1,0,0,1),(4,0,N'dbo.ExampleInvalid',NULL,1,0,0,1),
 (5,0,@MissingScope,N'like:Example%',1,0,0,1),(6,0,@MissingScope+N'|'+@MissingScope,NULL,1,0,0,0),(7,0,@MissingScope,NULL,1,-1,0,1),(8,0,@MissingScope,NULL,0,0,0,0);
IF @FixtureStatus='PENDING'
 INSERT #ExampleReferencesCases VALUES(20,1,NULL,NULL,1,0,3,0),(21,1,QUOTENAME(@Upper),NULL,1,0,1,0),(22,1,QUOTENAME(@Lower),NULL,1,0,2,0),
 (23,1,@Both,NULL,1,0,3,0),(24,1,QUOTENAME(@Lower)+N'|'+QUOTENAME(@Upper),NULL,1,0,3,0),
 (25,1,QUOTENAME(@Upper)+N'|'+QUOTENAME(@Upper),NULL,1,0,1,0),
 (26,1,N' '+QUOTENAME(@Upper)+N' | '+QUOTENAME(@Upper)+N' ',NULL,1,0,1,0),
 (27,1,@MissingScope,NULL,1,0,0,0),(28,1,QUOTENAME(REPLACE(@Upper,N'Case',N'case')),NULL,1,0,0,0),
 (29,1,@Both,NULL,1,NULL,3,0),(30,1,@Both,NULL,1,1,3,0),(31,1,@Both,NULL,1,2,3,0),
 (32,1,NULL,N'like:'+@Upper,1,0,1,0);
CREATE TABLE #ExampleReferencesExports(ExportId int PRIMARY KEY,ModuleId int,ArrayName sysname COLLATE SQL_Latin1_General_CP1_CS_AS,FieldCount int,SchemaTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS,TargetTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS);
INSERT #ExampleReferencesExports VALUES
 (1,1,N'runtimeStats',40,N'#ExampleReferencesSchema1',N'#ExampleReferencesExport1'),(2,2,N'waitStats',25,N'#ExampleReferencesSchema2',N'#ExampleReferencesExport2'),
 (3,3,N'queries',22,N'#ExampleReferencesSchema3',N'#ExampleReferencesExport3'),(4,3,N'plans',28,N'#ExampleReferencesSchema4',N'#ExampleReferencesExport4'),
 (5,4,N'regressions',25,N'#ExampleReferencesSchema5',N'#ExampleReferencesExport5'),(6,5,N'forcedPlans',32,N'#ExampleReferencesSchema6',N'#ExampleReferencesExport6');
DECLARE @Module int=1,@Case int,@Native bit,@Ref nvarchar(max),@RefPattern nvarchar(4000),@High bit,@Max int,@Mask int,@Invalid bit,
 @Json nvarchar(max),@TableJson nvarchar(max),@Names nvarchar(max),@Query bigint,@Mode varchar(16),@Map nvarchar(max),@Proc sysname,
 @Before datetime2(3),@After datetime2(3),@Rows bigint,@Export int,@Array sysname,@ExpectedTable sysname,@Target sysname,@Fields int,@Projection nvarchar(max),@Path nvarchar(128);
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@ParentCases int=0,@NullMutations int=0;
DECLARE @Call nvarchar(max),@Extras nvarchar(max),@Caught int;
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 WHILE @Module<=5
 BEGIN
  SET @Proc=CASE @Module WHEN 1 THEN N'USP_QueryStoreRuntimeStats' WHEN 2 THEN N'USP_QueryStoreWaitStats' WHEN 3 THEN N'USP_QueryStorePlanChanges' WHEN 4 THEN N'USP_QueryStoreRegressions' ELSE N'USP_QueryStoreForcedPlans' END;
  SET @Extras=CASE @Module WHEN 1 THEN N',@VonUtc=@bFrom,@BisUtc=@cTo,@Sortierung=''EXECUTIONS'',@MitPlanXml=1'
   WHEN 2 THEN N',@VonUtc=@bFrom,@BisUtc=@cTo,@WaitCategory=N''Lock'''
   WHEN 3 THEN N',@VonUtc=@bFrom,@NurMehrerePlaene=0,@MitPlanXml=1'
   WHEN 4 THEN N',@BaselineVonUtc=@bFrom,@BaselineBisUtc=@bTo,@VergleichVonUtc=@cFrom,@VergleichBisUtc=@cTo,@Metrik=''EXECUTIONS'',@MinRegressionProzent=0'
   ELSE N',@MitPlanXml=1' END;
  SET @Call=N'EXEC monitor.'+QUOTENAME(@Proc)+N' @QueryStoreDatabaseNames=@names,@ReferencedDatabaseNames=@refs,@ReferencedDatabaseNamePattern=@pattern,@HighImpactConfirmed=@high,
   @QueryId=@query,@MaxZeilen=@max,@MaxSqlTextZeichen=0,@ResultSetArt=@mode,@ResultTablesJson=@map,@JsonErzeugen=1,@Json=@json OUTPUT,@PrintMeldungen=0'+@Extras+N';';
  DECLARE [Cases193] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleReferencesCases ORDER BY CaseNumber;
  OPEN [Cases193];FETCH NEXT FROM [Cases193] INTO @Case,@Native,@Ref,@RefPattern,@High,@Max,@Mask,@Invalid;
  WHILE @@FETCH_STATUS=0
  BEGIN
   CREATE TABLE #ExampleReferencesExport1(Dummy int);CREATE TABLE #ExampleReferencesExport2(Dummy int);
   CREATE TABLE #ExampleReferencesExport3(Dummy int);CREATE TABLE #ExampleReferencesExport4(Dummy int);
   CREATE TABLE #ExampleReferencesExport5(Dummy int);CREATE TABLE #ExampleReferencesExport6(Dummy int);
   SELECT @Map=N'{'+STRING_AGG(CONVERT(nvarchar(max),N'"'+ArrayName+N'":"'+TargetTable+N'"'),N',')+N'}' FROM #ExampleReferencesExports WHERE ModuleId=@Module;
   SET @Names=CASE @Native WHEN 1 THEN @Both ELSE @MissingScope END;SET @Query=CASE @Native WHEN 1 THEN @OwnQuery ELSE NULL END;
   SET @Mode='TABLE';SET @Json=NULL;SET @Before=SYSUTCDATETIME();
   EXEC sys.sp_executesql @Call,N'@names nvarchar(max),@refs nvarchar(max),@pattern nvarchar(4000),@high bit,@query bigint,@max int,@mode varchar(16),@map nvarchar(max),@json nvarchar(max) OUTPUT,@bFrom datetime2(7),@bTo datetime2(7),@cFrom datetime2(7),@cTo datetime2(7)',
    @names=@Names,@refs=@Ref,@pattern=@RefPattern,@high=@High,@query=@Query,@max=@Max,@mode=@Mode,@map=@Map,@json=@Json OUTPUT,@bFrom=@BFrom,@bTo=@BTo,@cFrom=@CFrom,@cTo=@CTo;
   SET @After=SYSUTCDATETIME();
   IF @@LOCK_TIMEOUT<>137 OR @Json IS NULL OR ISJSON(@Json)<>1 THROW 59603,N'REFERENCES_OUTPUT',1;
   IF EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>CASE @Module WHEN 3 THEN 4 ELSE 3 END
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'meta' AND type=5)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'warnings' AND type=4)
    OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
    OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>CASE @Module WHEN 3 THEN 2 WHEN 5 THEN 2 ELSE 1 END
    OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
    OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After THROW 59604,N'REFERENCES_META',1;
   IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json)
    EXCEPT SELECT k COLLATE Latin1_General_100_BIN2,t FROM (SELECT N'meta' k,5 t UNION ALL SELECT N'warnings',4 UNION ALL SELECT ArrayName,4 FROM #ExampleReferencesExports WHERE ModuleId=@Module) expected)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>CASE @Module WHEN 1 THEN 14 WHEN 4 THEN 8 ELSE 7 END
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,N'$.meta')
     EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM (SELECT k FROM (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) m(k)
      UNION ALL SELECT k FROM (VALUES(N'isPartial'),(N'resultLimited'),(N'fromUtc'),(N'toUtc'),(N'sort'),(N'errorNumber'),(N'errorMessage')) m(k) WHERE @Module=1
      UNION ALL SELECT N'metric' WHERE @Module=4) expected)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'returnedRows' AND type=2 AND TRY_CONVERT(bigint,value)>=0)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'statusCode' AND type=1)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'hasMoreRows' AND type=3)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND type=0) OR (@Max IS NOT NULL AND type=2 AND TRY_CONVERT(int,value)=@Max)))
    THROW 59619,N'REFERENCES_META_KEYS',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') w WHERE (SELECT COUNT(*) FROM OPENJSON(w.value))<>4
    OR EXISTS(SELECT [key] FROM OPENJSON(w.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(w.value) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM (VALUES(CASE WHEN @Module=1 THEN N'databaseName' ELSE N'DatabaseName' END),(CASE WHEN @Module=1 THEN N'code' ELSE N'StatusCode' END),(CASE WHEN @Module=1 THEN N'errorNumber' ELSE N'ErrorNumber' END),(CASE WHEN @Module=1 THEN N'message' ELSE N'ErrorMessage' END)) f(k)))
    OR (@Native=1 AND JSON_QUERY(@Json,N'$.warnings')<>N'[]') THROW 59620,N'REFERENCES_WARNINGS',1;
   IF @Invalid=1 AND COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER' THROW 59605,N'REFERENCES_INVALID_STATUS',1;
   IF @Case=8 AND COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'HIGH_IMPACT_CONFIRMATION_REQUIRED' THROW 59621,N'REFERENCES_HIGH_IMPACT_GATE',1;
   IF @Native=1 AND COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE' THROW 59606,N'REFERENCES_NATIVE_STATUS',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WHERE COALESCE(TRY_CONVERT(int,JSON_VALUE(value,CASE WHEN @Module=1 THEN N'$.errorNumber' ELSE N'$.ErrorNumber' END)),0)=208) THROW 59607,N'REFERENCES_SOURCE_RESOLUTION',1;
   SET @Export=1;
   WHILE @Export<=6
   BEGIN
    SELECT @Array=ArrayName,@ExpectedTable=SchemaTable,@Target=TargetTable,@Fields=FieldCount FROM #ExampleReferencesExports WHERE ExportId=@Export AND ModuleId=@Module;
    IF @@ROWCOUNT=1
    BEGIN
     IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)
      EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@ExpectedTable))
      OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@ExpectedTable)
      EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)) THROW 59608,N'REFERENCES_LITERAL_SCHEMA',1;
     SELECT @Projection=STRING_AGG(CONVERT(nvarchar(max),CASE WHEN system_type_id=241 THEN N'CONVERT(nvarchar(max),'+QUOTENAME(name)+N') '+QUOTENAME(name) ELSE QUOTENAME(name) END),N',') WITHIN GROUP(ORDER BY column_id)
      FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@ExpectedTable);
     SET @Sql=N'SELECT @j=(SELECT '+@Projection+N' FROM '+QUOTENAME(@Target)+N' FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@Target)+N');';
     EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@j=@TableJson OUTPUT,@r=@Rows OUTPUT;
     SET @Path=N'$.'+@Array;
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=@Array COLLATE Latin1_General_100_BIN2 AND type=4)
      OR EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>@Fields OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
       OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@ExpectedTable))) THROW 59609,N'REFERENCES_JSON_FIELDS',1;
     IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,@Path) GROUP BY value COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,@Path) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 59610,N'REFERENCES_TABLE_JSON',1;
     IF @Native=0 AND @Rows<>0 THROW 59611,N'REFERENCES_CORE_EMPTY',1;
     IF @Native=1
     BEGIN
      DECLARE @ExpectedRows bigint=CASE @Mask WHEN 0 THEN 0 WHEN 3 THEN 2 ELSE 1 END;
      IF @Max>0 AND @Max<@ExpectedRows SET @ExpectedRows=@Max;
      IF @Export<>4 AND (COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@ExpectedRows
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.hasMoreRows'),N'')<>CASE WHEN @Max>0 AND @Max<CASE @Mask WHEN 0 THEN 0 WHEN 3 THEN 2 ELSE 1 END THEN N'true' ELSE N'false' END) THROW 59622,N'REFERENCES_NATIVE_COUNTS_META',1;
      IF @Rows<>@ExpectedRows THROW 59612,N'REFERENCES_NATIVE_COUNT',1;
      IF EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a WHERE NOT EXISTS(SELECT 1 FROM #ExampleReferencesNative n WHERE n.IsOne=1
       AND (@Mask=3 OR (@Mask=1 AND n.DatabaseName=@Upper COLLATE SQL_Latin1_General_CP1_CS_AS) OR (@Mask=2 AND n.DatabaseName=@Lower COLLATE SQL_Latin1_General_CP1_CS_AS))
       AND n.DatabaseId=TRY_CONVERT(int,JSON_VALUE(a.value,N'$.QueryStoreDatabaseId')) AND n.QueryId=TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.QueryId'))
       AND n.DatabaseName COLLATE Latin1_General_100_BIN2=JSON_VALUE(a.value,N'$.QueryStoreDatabaseName') COLLATE Latin1_General_100_BIN2
       AND (JSON_VALUE(a.value,N'$.PlanId') IS NULL OR n.PlanId=TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.PlanId'))))
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE [key]=N'QueryStoreDatabaseName' AND type=1)) THROW 59613,N'REFERENCES_NATIVE_IDENTITIES',1;
      IF @Case=21 AND @Export<>4
      BEGIN
       -- The complete identity/type guard above already accepted this real row.
       DECLARE @ActualRow nvarchar(max)=(SELECT TOP(1) value FROM OPENJSON(@Json,@Path)),@Mutated nvarchar(max),@MutationArray nvarchar(max),@MutationCaught int;
       SET @Mutated=JSON_MODIFY(@ActualRow,N'strict $.QueryStoreDatabaseName',NULL);
       SET @MutationArray=N'['+@Mutated+N']';SET @MutationCaught=0;
       BEGIN TRY
      IF EXISTS(SELECT 1 FROM OPENJSON(@MutationArray) a WHERE NOT EXISTS(SELECT 1 FROM #ExampleReferencesNative n WHERE n.IsOne=1
       AND (@Mask=3 OR (@Mask=1 AND n.DatabaseName=@Upper COLLATE SQL_Latin1_General_CP1_CS_AS) OR (@Mask=2 AND n.DatabaseName=@Lower COLLATE SQL_Latin1_General_CP1_CS_AS))
       AND n.DatabaseId=TRY_CONVERT(int,JSON_VALUE(a.value,N'$.QueryStoreDatabaseId')) AND n.QueryId=TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.QueryId'))
       AND n.DatabaseName COLLATE Latin1_General_100_BIN2=JSON_VALUE(a.value,N'$.QueryStoreDatabaseName') COLLATE Latin1_General_100_BIN2
       AND (JSON_VALUE(a.value,N'$.PlanId') IS NULL OR n.PlanId=TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.PlanId'))))
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE [key]=N'QueryStoreDatabaseName' AND type=1)) THROW 59613,N'REFERENCES_NATIVE_IDENTITIES',1;
       END TRY
       BEGIN CATCH
        SET @MutationCaught=ERROR_NUMBER();
        IF @MutationCaught<>59613 THROW;
       END CATCH;
       IF @MutationCaught<>59613 THROW 59614,N'REFERENCES_NULL_MUTATION_ACCEPTED',1;
       SET @NullMutations+=1;
      END;
     END;
    END;
    SET @Export+=1;
   END;
   IF @Native=1 SET @NativeCases+=1;ELSE SET @CoreCases+=1;
   DROP TABLE #ExampleReferencesExport1;DROP TABLE #ExampleReferencesExport2;DROP TABLE #ExampleReferencesExport3;
   DROP TABLE #ExampleReferencesExport4;DROP TABLE #ExampleReferencesExport5;DROP TABLE #ExampleReferencesExport6;
   FETCH NEXT FROM [Cases193] INTO @Case,@Native,@Ref,@RefPattern,@High,@Max,@Mask,@Invalid;
  END;
  CLOSE [Cases193];DEALLOCATE [Cases193];
  -- RAW and NONE are executed directly because helper probe grids may precede data.
  SET @Names=@MissingScope;SET @Ref=@MissingScope;SET @RefPattern=NULL;SET @High=1;SET @Query=NULL;SET @Max=0;SET @Map=NULL;
  DECLARE @Consumer int=0;
  WHILE @Consumer<3
  BEGIN
   SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'CONSOLE' END;SET @Json=NULL;
   EXEC sys.sp_executesql @Call,N'@names nvarchar(max),@refs nvarchar(max),@pattern nvarchar(4000),@high bit,@query bigint,@max int,@mode varchar(16),@map nvarchar(max),@json nvarchar(max) OUTPUT,@bFrom datetime2(7),@bTo datetime2(7),@cFrom datetime2(7),@cTo datetime2(7)',
    @names=@Names,@refs=@Ref,@pattern=@RefPattern,@high=@High,@query=@Query,@max=@Max,@mode=@Mode,@map=@Map,@json=@Json OUTPUT,@bFrom=@BFrom,@bTo=@BTo,@cFrom=@CFrom,@cTo=@CTo;
   IF @Json IS NULL OR ISJSON(@Json)<>1 OR @@LOCK_TIMEOUT<>137 THROW 59615,N'REFERENCES_CONSUMER',1;
   SET @Consumer+=1;SET @ConsumerCases+=1;
  END;
  IF @FixtureStatus='PENDING'
  BEGIN
   SET @Names=@Both;SET @Ref=QUOTENAME(@Upper);SET @Query=@OwnQuery;SET @Max=1;SET @Consumer=0;
   WHILE @Consumer<3
   BEGIN
    SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'CONSOLE' END;SET @Json=NULL;
    EXEC sys.sp_executesql @Call,N'@names nvarchar(max),@refs nvarchar(max),@pattern nvarchar(4000),@high bit,@query bigint,@max int,@mode varchar(16),@map nvarchar(max),@json nvarchar(max) OUTPUT,@bFrom datetime2(7),@bTo datetime2(7),@cFrom datetime2(7),@cTo datetime2(7)',
     @names=@Names,@refs=@Ref,@pattern=@RefPattern,@high=@High,@query=@Query,@max=@Max,@mode=@Mode,@map=@Map,@json=@Json OUTPUT,@bFrom=@BFrom,@bTo=@BTo,@cFrom=@CFrom,@cTo=@CTo;
    IF @Json IS NULL OR ISJSON(@Json)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
     OR JSON_QUERY(@Json,N'$.warnings')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 59623,N'REFERENCES_POSITIVE_CONSUMER',1;
    SELECT @Path=N'$.'+ArrayName FROM #ExampleReferencesExports WHERE ModuleId=@Module AND ArrayName<>N'plans';
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,@Path))<>1 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a
     WHERE NOT EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE [key]=N'QueryStoreDatabaseName' AND type=1 AND value COLLATE Latin1_General_100_BIN2=@Upper COLLATE Latin1_General_100_BIN2))
      THROW 59624,N'REFERENCES_POSITIVE_CONSUMER_IDENTITY',1;
    SET @Consumer+=1;SET @ConsumerCases+=1;
   END;
  END;
  SET @Names=@MissingScope;SET @Ref=@MissingScope;SET @Query=NULL;
  CREATE TABLE #ExampleReferencesPreflight(Dummy int);INSERT #ExampleReferencesPreflight VALUES(4242);
  DECLARE @P int=0,@BadMap nvarchar(max);
  WHILE @P<6
  BEGIN
   SET @BadMap=CASE @P WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleReferencesPreflight"}'
    WHEN 2 THEN N'{"runtimeStats":"#ExampleReferenceAbsentTarget"}' WHEN 3 THEN N'{"runtimeStats":"ExamplePermanentTarget"}'
    WHEN 4 THEN N'{"runtimeStats":"#ExampleReferencesPreflight","runtimeStats":"#ExampleReferencesPreflight"}' ELSE N'{"runtimeStats":"#ExampleReferencesPreflight"}' END;
   -- Use each module's actual primary public export name.
   SELECT @Array=ArrayName FROM #ExampleReferencesExports WHERE ModuleId=@Module AND ArrayName<>N'plans';
   SET @BadMap=REPLACE(@BadMap,N'runtimeStats',@Array);SET @Map=@BadMap;SET @Mode=CASE @P WHEN 5 THEN 'NONE' ELSE 'TABLE' END;SET @Max=-1;
   SET @Caught=0;
   BEGIN TRY
    EXEC sys.sp_executesql @Call,N'@names nvarchar(max),@refs nvarchar(max),@pattern nvarchar(4000),@high bit,@query bigint,@max int,@mode varchar(16),@map nvarchar(max),@json nvarchar(max) OUTPUT,@bFrom datetime2(7),@bTo datetime2(7),@cFrom datetime2(7),@cTo datetime2(7)',
     @names=@Names,@refs=@Ref,@pattern=@RefPattern,@high=@High,@query=@Query,@max=@Max,@mode=@Mode,@map=@Map,@json=@Json OUTPUT,@bFrom=@BFrom,@bTo=@BTo,@cFrom=@CFrom,@cTo=@CTo;
   END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
   IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleReferencesPreflight'))<>1
    OR NOT EXISTS(SELECT 1 FROM #ExampleReferencesPreflight WHERE Dummy=4242) THROW 59616,N'REFERENCES_PREFLIGHT',1;
   SET @P+=1;SET @PreflightCases+=1;
  END;
  DROP TABLE #ExampleReferencesPreflight;
  SET @Module+=1;
 END;

 IF @FixtureStatus='PENDING'
 BEGIN
  DECLARE @ParentModule int=1,@ParentJson nvarchar(max),@Child nvarchar(max),@ChildPath nvarchar(128);
  WHILE @ParentModule<=5
  BEGIN
   DECLARE @Runtime bit=CASE WHEN @ParentModule=1 THEN 1 ELSE 0 END,@Wait bit=CASE WHEN @ParentModule=2 THEN 1 ELSE 0 END,
    @Changes bit=CASE WHEN @ParentModule=3 THEN 1 ELSE 0 END,@Regression bit=CASE WHEN @ParentModule=4 THEN 1 ELSE 0 END,@Forced bit=CASE WHEN @ParentModule=5 THEN 1 ELSE 0 END;
   EXEC monitor.USP_QueryStoreAnalysis @QueryStoreDatabaseNames=@Both,@ReferencedDatabaseNames=@Both,@HighImpactConfirmed=1,@VonUtc=@BFrom,@BisUtc=@CTo,
    @MitStatus=0,@MitRuntimeStats=@Runtime,@MitWaitStats=@Wait,@MitPlanChanges=@Changes,@MitRegressionen=@Regression,@MitForcedPlans=@Forced,@MitHints=0,@MitReplicaKontext=0,@MitIQP=0,
    @MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@ParentJson OUTPUT,@PrintMeldungen=0;
   SET @ChildPath=CASE @ParentModule WHEN 1 THEN N'$.runtimeStats' WHEN 2 THEN N'$.waitStats' WHEN 3 THEN N'$.planChanges' WHEN 4 THEN N'$.regressions' ELSE N'$.forcedPlans' END;
   SET @Child=JSON_QUERY(@ParentJson,@ChildPath);
   IF @Child IS NULL OR ISJSON(@Child)<>1 OR COALESCE(JSON_VALUE(@Child,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
    OR JSON_QUERY(@Child,N'$.warnings')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 59617,N'REFERENCES_PARENT_CHILD',1;
   IF @ParentModule IN(1,2,5)
   BEGIN
    SET @Path=CASE @ParentModule WHEN 1 THEN N'$.runtimeStats' WHEN 2 THEN N'$.waitStats' ELSE N'$.forcedPlans' END;
    IF (SELECT COUNT(*) FROM OPENJSON(@Child,@Path))<>1 THROW 59618,N'REFERENCES_PARENT_POSITIVE',1;
   END;
   SET @ParentCases+=1;SET @ParentModule+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC(@Sql);
 SELECT N'PASS' ContractStatus,@FrameworkLevel FrameworkCompatibilityLevel,172 LiteralFields,53 LiteralTextCollations,
  @CoreCases CoreCases,@NativeCases NativeCases,@ConsumerCases ConsumerStatusJsonCases,@PreflightCases PreflightCases,
  @ParentCases ParentChildJsonCases,@NullMutations NullMutationsRejected,@FixtureStatus PositiveFixtureStatus;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC(@Sql);
 THROW;
END CATCH;
