USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/* P3: Unabhängiger 20-Feld-Vertrag für Query-Hash-Aggregation und Auswahl.
   Ein ausschließlich eigener synthetischer Parent-Snapshot prüft alle sieben
   Ränge, Mindestfilter, NULL-Metriken und Mengenparameter. Der optionale native
   Block liest nur die vorbereitete eigene ExampleHash-Fixture; er erzeugt
   keinen Workload und ändert weder Objekte noch Cache oder Konfiguration.
   Native Cachewerte werden einmal übernommen. Das belegt keine atomare
   Vorher-/Nachher-Messung, Cache-Eviction oder historische Planvielfalt. */
SET NOCOUNT ON;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 58300,N'QUERY_HASH_FRAMEWORK_COLLATION',1;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
 @CallerLockTimeout int=@@LOCK_TIMEOUT;
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 58300,N'QUERY_HASH_FRAMEWORK_LEVEL',1;
IF OBJECT_ID(N'tempdb..#PlanCacheAnalysis_QueryStatsSnapshot') IS NOT NULL
    THROW 58301,N'QUERY_HASH_FOREIGN_SNAPSHOT',1;

CREATE TABLE #PlanCacheAnalysis_QueryStatsSnapshot
(
 [query_hash] binary(8) NULL,[query_plan_hash] binary(8) NULL,[plan_handle] varbinary(64) NULL,
 [sql_handle] varbinary(64) NULL,[statement_start_offset] int NULL,[statement_end_offset] int NULL,
 [execution_count] bigint NULL,[total_worker_time] bigint NULL,[total_elapsed_time] bigint NULL,
 [total_logical_reads] bigint NULL,[total_logical_writes] bigint NULL,[total_spills] bigint NULL,
 [max_grant_kb] bigint NULL,[creation_time] datetime NULL,[last_execution_time] datetime NULL
);
CREATE TABLE #ExampleHashSchema
(
 [QueryHash] binary(8) NOT NULL,[PlanVariantCount] int NOT NULL,[PlanHandleCount] int NOT NULL,
 [CompilationCount] bigint NOT NULL,[ExecutionCount] bigint NOT NULL,[TotalCpuMs] decimal(38,3) NULL,
 [AvgCpuMs] decimal(38,3) NULL,[TotalElapsedMs] decimal(38,3) NULL,[AvgElapsedMs] decimal(38,3) NULL,
 [TotalReads] bigint NOT NULL,[AvgReads] decimal(38,3) NULL,[TotalWrites] bigint NOT NULL,
 [TotalSpills] bigint NOT NULL,[MaxGrantKb] bigint NOT NULL,[FirstCreationTime] datetime NULL,
 [LastExecutionTime] datetime NULL,[SampleStatementTextCharacters] bigint NULL,
 [SampleStatementTextBytes] bigint NULL,[SampleStatementTextIsTruncated] bit NOT NULL,
 [SampleStatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
SELECT * INTO #ExampleHashExpectedBase FROM #ExampleHashSchema;
SELECT * INTO #ExampleHashExpected FROM #ExampleHashSchema;
CREATE TABLE #ExampleHashEligibleRows([JsonValue] nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,[SortRank] bigint NOT NULL);
CREATE TABLE #ExampleHashNative
(
 [query_hash] binary(8),[query_plan_hash] binary(8),[plan_handle] varbinary(64),[sql_handle] varbinary(64),
 [statement_start_offset] int,[statement_end_offset] int,[execution_count] bigint,
 [total_worker_time] bigint,[total_elapsed_time] bigint,[total_logical_reads] bigint,
 [total_logical_writes] bigint,[total_spills] bigint,[max_grant_kb] bigint,
 [creation_time] datetime,[last_execution_time] datetime,
 [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectId] int
);
CREATE TABLE #ExampleHashCases
(
 [CaseNumber] int PRIMARY KEY,[IsNative] bit NOT NULL,[SortOrder] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RowLimit] int NULL,[TextLimit] int NULL,[MinExecutions] bigint NULL,[MinVariants] int NULL,
 [ExactHash] binary(8) NULL,[AnalysisMode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ParentSnapshot] bit NULL,[ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
INSERT #ExampleHashCases VALUES
 (0,0,'CPU_TOTAL',NULL,100,0,1,NULL,'TOP',1,'AVAILABLE'),
 (1,0,'CPU_TOTAL',0,100,0,1,NULL,'TOP',1,'AVAILABLE'),
 (2,0,'CPU_TOTAL',1,100,0,1,NULL,'TOP',1,'AVAILABLE'),
 (3,0,'CPU_TOTAL',2,100,0,1,NULL,'TOP',1,'AVAILABLE'),
 (4,0,'CPU_TOTAL',0,100,6,1,NULL,'TOP',1,'AVAILABLE'),
 (5,0,'CPU_TOTAL',0,100,0,2,NULL,'TOP',1,'AVAILABLE'),
 (6,0,'CPU_TOTAL',0,100,0,1,0x0000000000000004,'TOP',1,'AVAILABLE'),
 (7,0,'CPU_TOTAL',0,100,0,1,0x0000000000000099,'TOP',1,'AVAILABLE'),
 (8,0,'CPU_TOTAL',0,100,NULL,1,NULL,'TOP',1,'AVAILABLE'),
 (9,0,'CPU_TOTAL',0,100,0,NULL,NULL,'TOP',1,'AVAILABLE'),
 (10,0,'CPU_TOTAL',-1,100,0,1,NULL,'TOP',1,'INVALID_PARAMETER'),
 (11,0,'CPU_TOTAL',1,-1,0,1,NULL,'TOP',1,'INVALID_PARAMETER'),
 (12,0,'CPU_TOTAL',1,100,0,1,NULL,'BAD',1,'INVALID_PARAMETER'),
 (13,0,'BAD',1,100,0,1,NULL,'TOP',1,'INVALID_PARAMETER'),
 (14,0,'CPU_TOTAL',1,100,0,1,NULL,'TOP',NULL,'INVALID_PARAMETER'),
 (15,0,'CPU_TOTAL',0,100,0,1,NULL,NULL,1,'AVAILABLE'),
 (16,0,NULL,0,100,0,1,NULL,'TOP',1,'AVAILABLE'),
 (17,0,'CPU_TOTAL',0,0,0,1,NULL,'VOLL',1,'AVAILABLE'),
 (18,0,'CPU_TOTAL',0,NULL,0,1,NULL,'TOP',1,'AVAILABLE');
INSERT #ExampleHashCases
SELECT 19+v.n,0,v.s,1,100,0,1,NULL,'TOP',1,'AVAILABLE'
FROM (VALUES(0,'CPU_TOTAL'),(1,'ELAPSED_TOTAL'),(2,'READS_TOTAL'),(3,'WRITES_TOTAL'),
 (4,'EXECUTIONS'),(5,'PLAN_VARIANTS'),(6,'SPILLS_TOTAL'))v(n,s);

DECLARE @NativeFixtureStatus varchar(20)='NOT_EXECUTED',@NativeDatabase sysname=N'ExampleHashÄ🔬',
 @NativeDatabaseId int=DB_ID(N'ExampleHashÄ🔬'),@NativeLevel int=NULL,@NativeObjects int=0,
 @NativeTableRows bigint=NULL,@NativeOptions int=0,@Sql nvarchar(max);
IF @FrameworkLevel=170 AND @NativeDatabaseId IS NOT NULL
 AND EXISTS(SELECT 1 FROM sys.databases WHERE database_id=@NativeDatabaseId
     AND name COLLATE SQL_Latin1_General_CP1_CS_AS=@NativeDatabase COLLATE SQL_Latin1_General_CP1_CS_AS
     AND collation_name=N'SQL_Latin1_General_CP1_CI_AS' AND compatibility_level=170
     AND is_query_store_on=0 AND is_read_only=0)
BEGIN
 SET @Sql=N'USE '+QUOTENAME(@NativeDatabase)+N';
 SELECT @l=compatibility_level FROM sys.databases WHERE database_id=DB_ID();
 SELECT @o=COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID(N''dbo'')
 AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleSumÄ🔬'',N''ExampleCountÄ🔬'',N''ExampleRowsÄ🔬'');
 SELECT @m=COUNT(*) FROM sys.sql_modules WHERE object_id IN
 (OBJECT_ID(N''dbo.[ExampleSumÄ🔬]''),OBJECT_ID(N''dbo.[ExampleCountÄ🔬]''),OBJECT_ID(N''dbo.[ExampleRowsÄ🔬]''))
 AND uses_quoted_identifier=1 AND uses_ansi_nulls=1;
 IF OBJECT_ID(N''dbo.ExampleValues'',N''U'') IS NOT NULL SELECT @r=COUNT_BIG(*) FROM dbo.ExampleValues;';
 EXEC sys.sp_executesql @Sql,N'@l int OUTPUT,@o int OUTPUT,@m int OUTPUT,@r bigint OUTPUT',
  @l=@NativeLevel OUTPUT,@o=@NativeObjects OUTPUT,@m=@NativeOptions OUTPUT,@r=@NativeTableRows OUTPUT;
 IF @NativeLevel=170 AND @NativeObjects=3 AND @NativeOptions=3 AND @NativeTableRows=4
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@NativeDatabase)+N';
  INSERT #ExampleHashNative SELECT q.query_hash,q.query_plan_hash,q.plan_handle,q.sql_handle,
  q.statement_start_offset,q.statement_end_offset,q.execution_count,q.total_worker_time,q.total_elapsed_time,
  q.total_logical_reads,q.total_logical_writes,q.total_spills,q.max_grant_kb,q.creation_time,q.last_execution_time,
  t.text,t.objectid FROM sys.dm_exec_query_stats q CROSS APPLY sys.dm_exec_sql_text(q.sql_handle)t
  WHERE t.dbid=DB_ID() AND t.objectid IN(OBJECT_ID(N''dbo.[ExampleSumÄ🔬]''),
    OBJECT_ID(N''dbo.[ExampleCountÄ🔬]''),OBJECT_ID(N''dbo.[ExampleRowsÄ🔬]''));';
  EXEC sys.sp_executesql @Sql;
  IF (SELECT COUNT(*) FROM #ExampleHashNative)=3
   AND (SELECT COUNT(DISTINCT query_hash) FROM #ExampleHashNative)=3
   AND (SELECT COUNT(DISTINCT ObjectId) FROM #ExampleHashNative)=3
   AND NOT EXISTS(SELECT 1 FROM #ExampleHashNative WHERE query_hash IS NULL OR BatchText IS NULL
    OR execution_count<=0 OR statement_start_offset<0 OR statement_start_offset%2<>0
    OR statement_end_offset IS NULL OR statement_end_offset NOT IN(-1) AND
       (statement_end_offset<statement_start_offset OR statement_end_offset%2<>0))
  BEGIN
   SET @NativeFixtureStatus='PASS';
   INSERT #ExampleHashCases VALUES
   (100,1,'CPU_TOTAL',NULL,100,0,1,NULL,'TOP',1,'AVAILABLE'),
   (101,1,'CPU_TOTAL',0,100,0,1,NULL,'TOP',1,'AVAILABLE'),
   (102,1,'CPU_TOTAL',1,100,0,1,NULL,'TOP',1,'AVAILABLE'),
   (103,1,'CPU_TOTAL',2,100,0,1,NULL,'TOP',1,'AVAILABLE'),
   (104,1,'CPU_TOTAL',0,100,3,1,NULL,'TOP',1,'AVAILABLE'),
   (105,1,'CPU_TOTAL',0,100,0,2,NULL,'TOP',1,'AVAILABLE'),
   (106,1,'CPU_TOTAL',0,5,0,1,NULL,'TOP',1,'AVAILABLE'),
   (107,1,'CPU_TOTAL',0,NULL,0,1,NULL,'TOP',1,'AVAILABLE');
   INSERT #ExampleHashCases SELECT 108+v.n,1,v.s,1,100,0,1,NULL,'TOP',1,'AVAILABLE'
   FROM (VALUES(0,'CPU_TOTAL'),(1,'ELAPSED_TOTAL'),(2,'READS_TOTAL'),(3,'WRITES_TOTAL'),
    (4,'EXECUTIONS'),(5,'PLAN_VARIANTS'),(6,'SPILLS_TOTAL'))v(n,s);
   INSERT #ExampleHashCases SELECT 115+ROW_NUMBER() OVER(ORDER BY query_hash)-1,1,
    'CPU_TOTAL',0,100,0,1,query_hash,'TOP',1,'AVAILABLE' FROM #ExampleHashNative;
   INSERT #ExampleHashCases VALUES
    (118,1,'CPU_TOTAL',0,30,0,1,NULL,'TOP',1,'AVAILABLE'),
    (119,1,'CPU_TOTAL',0,31,0,1,NULL,'TOP',1,'AVAILABLE');
  END;
 END;
END;

DECLARE @Case int,@Native bit,@Sort varchar(32),@Limit int,@TextLimit int,@MinExec bigint,
 @MinPlans int,@Hash binary(8),@Mode varchar(16),@Parent bit,@Status varchar(40),
 @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@DataJson nvarchar(max),
 @Rows bigint,@SafeLimit bigint,@CoreCases int=0,@NativeCases int=0,@Before datetime2(3),@After datetime2(3);
DECLARE cases CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleHashCases ORDER BY CaseNumber;
BEGIN TRY
 OPEN cases;
 FETCH NEXT FROM cases INTO @Case,@Native,@Sort,@Limit,@TextLimit,@MinExec,@MinPlans,@Hash,@Mode,@Parent,@Status;
 WHILE @@FETCH_STATUS=0
 BEGIN
  TRUNCATE TABLE #PlanCacheAnalysis_QueryStatsSnapshot;
  TRUNCATE TABLE #ExampleHashExpectedBase;
  TRUNCATE TABLE #ExampleHashExpected;
  IF @Native=0
  BEGIN
   INSERT #PlanCacheAnalysis_QueryStatsSnapshot VALUES
    (0x0000000000000001,0x0000000000000011,0x01,NULL,0,-1,2,10000,1000,10,2,1,10,'20200101','20200105'),
    (0x0000000000000001,0x0000000000000012,0x02,NULL,0,-1,3,20000,2000,23,3,2,20,'20200102','20200106'),
    (0x0000000000000002,0x0000000000000021,0x03,NULL,0,-1,8,12000,80000,88,8,4,30,'20200102','20200105'),
    (0x0000000000000003,0x0000000000000031,0x04,NULL,0,-1,3,3000,3000,3,1,3,20,'20200103','20200103'),
    (0x0000000000000003,0x0000000000000032,0x04,NULL,0,-1,4,4000,4000,4,1,3,30,'20200103','20200104'),
    (0x0000000000000003,0x0000000000000033,0x05,NULL,0,-1,5,5000,5000,5,1,3,40,'20200104','20200104'),
    (0x0000000000000004,0x0000000000000041,0x06,NULL,0,-1,0,0,0,0,0,0,0,'20200104','20200103'),
    (NULL,0x0000000000000091,0x07,NULL,0,-1,999,999999,999999,999,999,999,999,'20200101','20200107');
   INSERT #ExampleHashExpectedBase VALUES
    (0x0000000000000001,2,2,2,5,30,6,3,0.600,33,6.600,5,3,20,'20200101','20200106',NULL,NULL,0,NULL),
    (0x0000000000000002,1,1,1,8,12,1.500,80,10,88,11,8,4,30,'20200102','20200105',NULL,NULL,0,NULL),
    (0x0000000000000003,3,2,3,12,12,1,12,1,12,1,3,9,40,'20200103','20200104',NULL,NULL,0,NULL),
    (0x0000000000000004,1,1,1,0,0,NULL,0,NULL,0,NULL,0,0,0,'20200104','20200103',NULL,NULL,0,NULL);
  END
  ELSE
  BEGIN
   INSERT #PlanCacheAnalysis_QueryStatsSnapshot SELECT query_hash,query_plan_hash,plan_handle,sql_handle,
    statement_start_offset,statement_end_offset,execution_count,total_worker_time,total_elapsed_time,
    total_logical_reads,total_logical_writes,total_spills,max_grant_kb,creation_time,last_execution_time
    FROM #ExampleHashNative;
   INSERT #ExampleHashExpectedBase
   SELECT n.query_hash,1,1,1,n.execution_count,
    CONVERT(decimal(38,3),n.total_worker_time/1000.0),CONVERT(decimal(38,3),(n.total_worker_time/n.execution_count)/1000.0),
    CONVERT(decimal(38,3),n.total_elapsed_time/1000.0),CONVERT(decimal(38,3),(n.total_elapsed_time/n.execution_count)/1000.0),
    n.total_logical_reads,CONVERT(decimal(38,3),n.total_logical_reads*1.0/n.execution_count),
    n.total_logical_writes,n.total_spills,n.max_grant_kb,n.creation_time,n.last_execution_time,
    CONVERT(bigint,LEN(x.t COLLATE Latin1_General_100_CI_AS_SC+N'.')-1),DATALENGTH(x.t),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN(x.t COLLATE Latin1_General_100_CI_AS_SC+N'.')-1>@TextLimit THEN 1 ELSE 0 END),
    CASE WHEN @TextLimit>0 THEN LEFT(x.t COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) ELSE x.t END
   FROM #ExampleHashNative n CROSS APPLY
    (SELECT SUBSTRING(n.BatchText,n.statement_start_offset/2+1,
     ((CASE WHEN n.statement_end_offset=-1 THEN DATALENGTH(n.BatchText) ELSE n.statement_end_offset END
       -n.statement_start_offset)/2)+1))x(t);
  END;
  IF @Native=1 AND @TextLimit IS NULL AND NOT EXISTS
   (SELECT 1 FROM #ExampleHashExpectedBase WHERE
    SampleStatementText COLLATE Latin1_General_100_BIN2=
      N'SELECT SUM(Value) AS [ExampleÄ🔬] FROM dbo.ExampleValues WHERE Id>0' COLLATE Latin1_General_100_BIN2
    AND SampleStatementTextCharacters=66 AND SampleStatementTextBytes=134 AND SampleStatementTextIsTruncated=0)
   THROW 58306,N'QUERY_HASH_NATIVE_UNICODE_OFFSETS',1;
  SET @SafeLimit=CASE WHEN @Limit IS NULL OR @Limit=0 THEN 9223372036854775807 WHEN @Limit<0 THEN 0 ELSE @Limit END;
  IF @Status='AVAILABLE'
   INSERT #ExampleHashExpected SELECT TOP(@SafeLimit) * FROM #ExampleHashExpectedBase
    WHERE ExecutionCount>=@MinExec AND PlanVariantCount>=@MinPlans AND (@Hash IS NULL OR QueryHash=@Hash)
    ORDER BY CASE COALESCE(@Sort,'CPU_TOTAL') WHEN 'CPU_TOTAL' THEN TotalCpuMs WHEN 'ELAPSED_TOTAL' THEN TotalElapsedMs
     WHEN 'READS_TOTAL' THEN TotalReads WHEN 'WRITES_TOTAL' THEN TotalWrites WHEN 'EXECUTIONS' THEN ExecutionCount
     WHEN 'PLAN_VARIANTS' THEN PlanVariantCount WHEN 'SPILLS_TOTAL' THEN TotalSpills END DESC,LastExecutionTime DESC;
  CREATE TABLE #ExampleHashTarget([Dummy] int NULL);
  SET @Before=SYSUTCDATETIME();
  EXEC monitor.USP_QueryHashAnalysis @QueryHash=@Hash,@Sortierung=@Sort,@AnalyseModus=@Mode,
   @MinExecutionCount=@MinExec,@MinPlanVarianten=@MinPlans,@MaxZeilen=@Limit,@MaxSqlTextZeichen=@TextLimit,
   @ParentQueryStatsSnapshot=@Parent,@HighImpactConfirmed=1,@ResultSetArt='TABLE',
   @ResultTablesJson=N'{"queryHashes":"#ExampleHashTarget"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>@CallerLockTimeout THROW 58302,N'QUERY_HASH_CALLER_LOCK_TIMEOUT',1;
  IF EXISTS
  (SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,
    collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHashSchema')
   EXCEPT SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,
    collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHashTarget'))
   OR EXISTS
  (SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,
    collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHashTarget')
   EXCEPT SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,
    collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHashSchema'))
   THROW 58303,N'QUERY_HASH_SCHEMA',1;
  IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>3
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) EXCEPT SELECT v.k FROM(VALUES(N'meta'),(N'queryHashes'),(N'warnings'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE [key] WHEN N'meta' THEN 5 ELSE 4 END)
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>9
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT
    SELECT v.k FROM(VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),
      (N'returnedRows'),(N'sortOrder'),(N'errorNumber'),(N'errorMessage'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [type]<>CASE [key]
    WHEN N'schemaVersion' THEN 2 WHEN N'returnedRows' THEN 2 WHEN N'isPartial' THEN 3
    WHEN N'errorNumber' THEN 0 WHEN N'errorMessage' THEN CASE WHEN @Status='AVAILABLE' THEN 0 ELSE 1 END ELSE 1 END)
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryHashAnalysis'
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status
   OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
   OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL
   OR (@Status='AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL)
   OR (@Status<>'AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NULL)
   OR JSON_VALUE(@Json,N'$.meta.sortOrder')<>COALESCE(@Sort,'CPU_TOTAL')
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings'))
   THROW 58304,N'QUERY_HASH_JSON_META',1;
  SET @Rows=(SELECT COUNT_BIG(*) FROM #ExampleHashExpected);
  IF ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@Rows
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryHashes'))<>@Rows
   THROW 58305,N'QUERY_HASH_COUNTS',1;
  EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleHashTarget FOR JSON PATH,INCLUDE_NULL_VALUES);',
   N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
  SET @DataJson=JSON_QUERY(@Json,N'$.queryHashes');
  TRUNCATE TABLE #ExampleHashEligibleRows;
  INSERT #ExampleHashEligibleRows
  SELECT (SELECT e.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
   RANK()OVER(ORDER BY CASE COALESCE(@Sort,'CPU_TOTAL') WHEN 'CPU_TOTAL' THEN TotalCpuMs WHEN 'ELAPSED_TOTAL' THEN TotalElapsedMs
    WHEN 'READS_TOTAL' THEN TotalReads WHEN 'WRITES_TOTAL' THEN TotalWrites WHEN 'EXECUTIONS' THEN ExecutionCount
    WHEN 'PLAN_VARIANTS' THEN PlanVariantCount WHEN 'SPILLS_TOTAL' THEN TotalSpills END DESC,LastExecutionTime DESC)
  FROM #ExampleHashExpectedBase e
  WHERE @Status='AVAILABLE' AND ExecutionCount>=@MinExec AND PlanVariantCount>=@MinPlans AND (@Hash IS NULL OR QueryHash=@Hash);
  IF @Native=1
  BEGIN
   -- Bei vollständig gleichen bestehenden Sortschlüsseln bleibt die Auswahl flexibel.
   -- Erst native Vollwerte, Häufigkeiten und die gesamte Ranggrenze prüfen.
   DECLARE @BoundaryRank bigint=(SELECT MAX(SortRank) FROM #ExampleHashEligibleRows WHERE SortRank<=@SafeLimit);
   IF EXISTS(SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]')) a WHERE NOT EXISTS
     (SELECT 1 FROM #ExampleHashEligibleRows e WHERE e.JsonValue=a.value COLLATE Latin1_General_100_BIN2 AND e.SortRank<=@BoundaryRank))
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(COALESCE(@TableJson,N'[]'))
       GROUP BY value COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
    OR EXISTS(SELECT 1 FROM #ExampleHashEligibleRows e WHERE e.SortRank<@BoundaryRank AND NOT EXISTS
       (SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]')) a WHERE e.JsonValue=a.value COLLATE Latin1_General_100_BIN2))
    OR (SELECT COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')))<>@Rows
    THROW 58306,N'QUERY_HASH_NATIVE_RANK_VALUES',1;
   DELETE #ExampleHashExpected;
   INSERT #ExampleHashExpected SELECT e.* FROM #ExampleHashExpectedBase e
   CROSS APPLY(SELECT (SELECT e.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES))j(v)
   WHERE EXISTS(SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]'))a WHERE a.value COLLATE Latin1_General_100_BIN2=j.v COLLATE Latin1_General_100_BIN2);
  END;
  IF EXISTS(SELECT 1 FROM
   (SELECT e.SortRank,LAG(e.SortRank)OVER(ORDER BY CONVERT(int,a.[key])) AS PreviousRank
    FROM OPENJSON(@DataJson)a JOIN #ExampleHashEligibleRows e ON e.JsonValue=a.value COLLATE Latin1_General_100_BIN2)r
   WHERE r.SortRank<r.PreviousRank)
   THROW 58306,N'QUERY_HASH_JSON_ORDER',1;
  SET @ExpectedJson=(SELECT * FROM #ExampleHashExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF EXISTS(SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2 EXCEPT
   SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2 EXCEPT
   SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@DataJson)
    GROUP BY [value] COLLATE Latin1_General_100_BIN2 EXCEPT
   SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]'))
    GROUP BY [value] COLLATE Latin1_General_100_BIN2 EXCEPT
   SELECT [value] COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@DataJson)
    GROUP BY [value] COLLATE Latin1_General_100_BIN2)
   THROW 58306,N'QUERY_HASH_FULL_VALUES',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@DataJson)a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>20
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT
     SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns
      WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHashSchema')))
   THROW 58307,N'QUERY_HASH_ROW_PROPERTIES',1;
  DROP TABLE #ExampleHashTarget;
  IF @Native=0 SET @CoreCases+=1; ELSE SET @NativeCases+=1;
  FETCH NEXT FROM cases INTO @Case,@Native,@Sort,@Limit,@TextLimit,@MinExec,@MinPlans,@Hash,@Mode,@Parent,@Status;
 END;
 CLOSE cases; DEALLOCATE cases;

 CREATE TABLE #ExampleHashEmptyConsole([Ergebnis] nvarchar(200),[Status] varchar(40),[Hinweis] nvarchar(2048));
 DECLARE @EmptyCase int=0;
 WHILE @EmptyCase<3
 BEGIN
  TRUNCATE TABLE #ExampleHashEmptyConsole;
  SET @Limit=CASE WHEN @EmptyCase=0 THEN -1 ELSE 1 END;
  SET @MinExec=CASE WHEN @EmptyCase=1 THEN NULL ELSE 0 END;
  INSERT #ExampleHashEmptyConsole EXEC monitor.USP_QueryHashAnalysis @QueryHash=0x0000000000000099,
   @MaxZeilen=@Limit,@MinExecutionCount=@MinExec,@ParentQueryStatsSnapshot=1,@HighImpactConfirmed=1,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleHashEmptyConsole)<>1
   OR EXISTS(SELECT 1 FROM #ExampleHashEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse'
    OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queryHashes'))
   THROW 58308,N'QUERY_HASH_EMPTY_CONSOLE',1;
  SET @EmptyCase+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN ' rAw ' ELSE 'NONE' END;
  SET @Limit=CASE WHEN @Consumer=1 THEN 1 ELSE -1 END;
  SET @TextLimit=CASE WHEN @Consumer=1 THEN -1 ELSE 4000 END;
  DECLARE @JsonBit bit=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;
  EXEC monitor.USP_QueryHashAnalysis @QueryHash=0x0000000000000099,@MaxZeilen=@Limit,@MaxSqlTextZeichen=@TextLimit,
   @ParentQueryStatsSnapshot=1,@ResultSetArt=@Mode,@JsonErzeugen=@JsonBit,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @JsonBit=0 AND @Json IS NOT NULL OR @JsonBit=1 AND
   (JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER' OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queryHashes')))
   THROW 58309,N'QUERY_HASH_CONSUMER',1;
  SET @Consumer+=1;
 END;
 CREATE TABLE #ExampleHashPreflight([Dummy] int NULL);
 DECLARE @Preflight int=0,@Map nvarchar(max),@OutputMode varchar(16),@Caught int;
 WHILE @Preflight<6
 BEGIN
  SET @Map=CASE @Preflight WHEN 0 THEN NULL WHEN 1 THEN N'{}' WHEN 2 THEN N'{"wrong":"#ExampleHashPreflight"}'
   WHEN 3 THEN N'{"queryHashes":"dbo.ExampleHashPermanent"}' WHEN 4 THEN N'{"queryHashes":"#ExampleHashAbsent"}'
   ELSE N'{"queryHashes":"#ExampleHashPreflight"}' END;
  SET @OutputMode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
  SET @Caught=0;
  BEGIN TRY
   EXEC monitor.USP_QueryHashAnalysis @MaxZeilen=-1,@ResultSetArt=@OutputMode,@ResultTablesJson=@Map,
    @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   IF ERROR_NUMBER()<>51011 THROW;
   SET @Caught=1;
  END CATCH;
  IF @Caught<>1 THROW 58310,N'QUERY_HASH_PREFLIGHT',1;
  SET @Preflight+=1;
 END;
 DROP TABLE #PlanCacheAnalysis_QueryStatsSnapshot;
 EXEC monitor.USP_QueryHashAnalysis @QueryHash=0x0000000000000099,@ParentQueryStatsSnapshot=1,
  @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF JSON_VALUE(@Json,N'$.meta.statusCode')<>'ERROR_HANDLED'
  OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true'
  OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.errorNumber'))<>208
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queryHashes'))
  THROW 58311,N'QUERY_HASH_MISSING_SNAPSHOT',1;
 SET @CoreCases+=1;
 SELECT N'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,
  @CoreCases AS CoreCases,@NativeFixtureStatus AS NativeFixtureStatus,@NativeLevel AS SourceCompatibilityLevel,
  @NativeCases AS NativeCases,20 AS PublicFields,1 AS TextCollations,3 AS Consumers,6 AS Preflights,3 AS EmptySqlConsole;
END TRY
BEGIN CATCH
 IF CURSOR_STATUS('local','cases')>=0 CLOSE cases;
 IF CURSOR_STATUS('local','cases')>-3 DEALLOCATE cases;
 IF OBJECT_ID(N'tempdb..#PlanCacheAnalysis_QueryStatsSnapshot') IS NOT NULL DROP TABLE #PlanCacheAnalysis_QueryStatsSnapshot;
 THROW;
END CATCH;
GO
