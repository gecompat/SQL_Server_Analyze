USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
Prüft die drei PlanDetails-Exporte mit 37 unabhängigen Literal-Schemafeldern
und neun Frameworktextcollations. Allgemeine Fälle prüfen Parameter, frühe
TABLE-Vorprüfung und vollständige gleichaufrufbezogene TABLE-/JSON-Parität.
Der optionale native Block liest ausschließlich den über SESSION_CONTEXT
übergebenen eigenen Example*-Cacheplan. Er erzeugt keinen Workload und ändert
keine Profiling-, Last-Actual-, Live- oder Datenbankoptionen. Ohne geeigneten
Kontext lautet dessen Status NOT_EXECUTED. Mutable Cachewerte besitzen keinen
atomaren Cross-call-Vertrag. XML wird innerhalb des Aufrufs als SQL-Textwert
verglichen; Byteparität verschiedener Clientdarstellungen wird nicht behauptet.
*/
SET NOCOUNT ON;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 59700,N'PLAN_DETAILS_FRAMEWORK_COLLATION',1;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 59700,N'PLAN_DETAILS_FRAMEWORK_LEVEL',1;
DECLARE @OriginalTimeout int=@@LOCK_TIMEOUT;
SET LOCK_TIMEOUT 137;
CREATE TABLE [#ExamplePlanDetailsSchema_candidates]
(
    [CandidateId] int NULL,
    [SessionId] smallint NULL,
    [RequestId] int NULL,
    [PlanHandle] varbinary(64) NULL,
    [SqlHandle] varbinary(64) NULL,
    [QueryHash] binary(8) NULL,
    [QueryPlanHash] binary(8) NULL,
    [StatementStartOffset] int NULL,
    [StatementEndOffset] int NULL,
    [CreationTime] datetime NULL,
    [LastExecutionTime] datetime NULL,
    [ExecutionCount] bigint NULL,
    [StatementTextCharacters] bigint NULL,
    [StatementTextBytes] bigint NULL,
    [StatementTextIsTruncated] bit NOT NULL,
    [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [BatchTextCharacters] bigint NULL,
    [BatchTextBytes] bigint NULL,
    [BatchTextIsTruncated] bit NOT NULL,
    [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SqlTextDatabaseId] int NULL,
    [SqlTextDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SqlTextObjectId] int NULL
);

CREATE TABLE [#ExamplePlanDetailsSchema_attributes]
(
    [CandidateId] int NULL,
    [AttributeName] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [AttributeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsCacheKey] bit NULL
);

CREATE TABLE [#ExamplePlanDetailsSchema_plans]
(
    [CandidateId] int NULL,
    [SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [DatabaseId] int NULL,
    [ObjectId] int NULL,
    [IsEncrypted] bit NULL,
    [QueryPlanXml] xml NULL,
    [QueryPlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE #ExamplePlanDetailsCases
(CaseNumber int NOT NULL PRIMARY KEY, SessionKind int NOT NULL, SelectorKind int NOT NULL,
 MaxObjects int NULL, TextLimit int NULL, AttributesFlag bit NULL, CompileFlag bit NULL,
 TextFlag bit NULL, ActualFlag bit NULL, LiveFlag bit NULL, ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExamplePlanDetailsCases VALUES
(0,1,0,1,0,0,0,0,0,0,'AVAILABLE'),(1,1,0,2,1,0,0,0,0,0,'AVAILABLE'),
(2,1,0,20,NULL,0,0,0,0,0,'AVAILABLE'),(3,1,0,0,0,0,0,0,0,0,'AVAILABLE'),
(4,1,0,NULL,0,0,0,0,0,0,'AVAILABLE'),(5,1,0,1,8000,1,1,1,0,0,'AVAILABLE'),
(6,0,0,20,8000,0,0,0,0,0,'INVALID_PARAMETER'),(7,2,0,20,8000,0,0,0,0,0,'INVALID_PARAMETER'),
(8,3,0,20,8000,0,0,0,0,0,'INVALID_PARAMETER'),(9,1,0,-1,0,0,0,0,0,0,'INVALID_PARAMETER'),
(10,1,0,1,-1,0,0,0,0,0,'INVALID_PARAMETER'),(11,1,0,1,-5,0,0,0,0,0,'INVALID_PARAMETER'),
(12,4,0,1,0,0,0,0,0,0,'AVAILABLE'),(13,1,0,1,0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
(14,5,0,1,0,0,0,0,0,0,'AVAILABLE'),(15,1,0,21,0,0,0,0,0,0,'AVAILABLE');
DECLARE @FixtureHandle varbinary(64)=TRY_CONVERT(varbinary(64),SESSION_CONTEXT(N'ExamplePlanDetailsFixturePlanHandle')),
 @FixtureDatabase sysname=TRY_CONVERT(sysname,SESSION_CONTEXT(N'ExamplePlanDetailsFixtureDatabase')),
 @FixtureStatus varchar(40)='NOT_EXECUTED',@FixtureDbId int,@NativeCases int=0,@CoreCases int=0,@NullMutations int=0;
CREATE TABLE #ExamplePlanDetailsNative
(PlanHandle varbinary(64),SqlHandle varbinary(64),QueryHash binary(8),QueryPlanHash binary(8),StartOffset int,EndOffset int,
 CreationTime datetime,LastExecutionTime datetime,ExecutionCount bigint,BatchText nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,
 DatabaseId int,ObjectId int,TotalWorkerTime bigint);
IF @FixtureHandle IS NOT NULL AND @FixtureDatabase IS NOT NULL AND @FixtureDatabase LIKE N'Example%'
BEGIN
 SELECT @FixtureDbId=database_id FROM master.sys.databases WITH(NOLOCK)
 WHERE name COLLATE Latin1_General_100_BIN2=@FixtureDatabase COLLATE Latin1_General_100_BIN2 AND database_id>4 AND state=0;
 IF @FixtureDbId IS NOT NULL
 INSERT #ExamplePlanDetailsNative
 SELECT q.plan_handle,q.sql_handle,q.query_hash,q.query_plan_hash,q.statement_start_offset,q.statement_end_offset,
 q.creation_time,q.last_execution_time,q.execution_count,t.text,t.dbid,t.objectid,q.total_worker_time
 FROM sys.dm_exec_query_stats q WITH(NOLOCK) CROSS APPLY sys.dm_exec_sql_text(q.sql_handle)t
 WHERE q.plan_handle=@FixtureHandle AND t.dbid=@FixtureDbId AND t.objectid>0;
 IF (SELECT COUNT(*) FROM #ExamplePlanDetailsNative)=2
 AND (SELECT COUNT(DISTINCT SqlHandle) FROM #ExamplePlanDetailsNative)=1
 AND (SELECT COUNT(DISTINCT QueryHash) FROM #ExamplePlanDetailsNative)=2
 BEGIN
  SET @FixtureStatus='PENDING';
  INSERT #ExamplePlanDetailsCases VALUES
  (100,0,1,1,0,1,1,1,0,0,'AVAILABLE'),(101,0,1,2,1,1,1,1,0,0,'AVAILABLE'),
  (102,0,1,0,NULL,1,1,1,0,0,'AVAILABLE'),(103,0,1,NULL,8000,1,1,1,0,0,'AVAILABLE'),
  (104,0,2,1,0,1,1,1,0,0,'AVAILABLE'),(105,0,2,2,1,1,1,1,0,0,'AVAILABLE'),
  (106,0,2,0,NULL,1,1,1,0,0,'AVAILABLE'),(107,0,2,NULL,0,1,1,1,0,0,'AVAILABLE'),
  (108,0,3,1,0,1,1,1,0,0,'AVAILABLE'),(109,0,3,2,1,1,1,1,0,0,'AVAILABLE'),
  (110,0,1,1,0,0,0,0,0,1,'AVAILABLE'),(111,0,4,2,0,1,1,1,0,0,'AVAILABLE');
 END;
END;
DECLARE @OwnSessions nvarchar(max)=CONVERT(nvarchar(12),@@SPID),@MissingSession smallint;
SELECT TOP(1) @MissingSession=CONVERT(smallint,v.n) FROM (VALUES(32767),(32766),(32765))v(n)
 WHERE NOT EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=v.n);
IF @MissingSession IS NULL THROW 59700,N'PLAN_DETAILS_EMPTY_SESSION_GUARD',1;
DECLARE @Case int=-1,@SessionKind int,@SelectorKind int,@Max int,@Limit int,@Attrs bit,@Compile bit,@Text bit,@Actual bit,@Live bit,
 @Expected varchar(40),@Sessions nvarchar(max),@Plan varbinary(64),@SqlHandle varbinary(64),@Hash binary(8),@Json nvarchar(max),
 @Before datetime2(3),@After datetime2(3),@Map nvarchar(max)=N'{"candidates":"#ExamplePlanDetailsCandidates","attributes":"#ExamplePlanDetailsAttributes","plans":"#ExamplePlanDetailsPlans"}',
 @Arrays nvarchar(max),@Sql nvarchar(max),@ObjectId int,@ExpectedObjectId int,@ArrayName sysname,@Target sysname,@Template sysname,@Count int;
CREATE TABLE #ExamplePlanDetailsArrayCheck (ArrayName sysname COLLATE SQL_Latin1_General_CP1_CS_AS,TableJson nvarchar(max) COLLATE Latin1_General_100_BIN2,JsonArray nvarchar(max) COLLATE Latin1_General_100_BIN2);
BEGIN TRY
WHILE EXISTS(SELECT 1 FROM #ExamplePlanDetailsCases WHERE CaseNumber>@Case)
BEGIN
 SELECT TOP(1) @Case=CaseNumber,@SessionKind=SessionKind,@SelectorKind=SelectorKind,@Max=MaxObjects,@Limit=TextLimit,
 @Attrs=AttributesFlag,@Compile=CompileFlag,@Text=TextFlag,@Actual=ActualFlag,@Live=LiveFlag,@Expected=ExpectedStatus
 FROM #ExamplePlanDetailsCases WHERE CaseNumber>@Case ORDER BY CaseNumber;
 SET @Sessions=CASE @SessionKind WHEN 1 THEN @OwnSessions WHEN 2 THEN N'not-a-number' WHEN 3 THEN N'32768'
 WHEN 4 THEN @OwnSessions+N'|'+@OwnSessions WHEN 5 THEN CONVERT(nvarchar(12),@MissingSession) END;
 SET @Plan=CASE WHEN @SelectorKind IN(1,4) THEN @FixtureHandle END;
 SET @SqlHandle=CASE WHEN @SelectorKind IN(2,4) THEN (SELECT MIN(SqlHandle) FROM #ExamplePlanDetailsNative) END;
 SET @Hash=CASE WHEN @SelectorKind=3 THEN (SELECT MIN(QueryHash) FROM #ExamplePlanDetailsNative) END;
 CREATE TABLE #ExamplePlanDetailsCandidates(Seed int NULL);
 CREATE TABLE #ExamplePlanDetailsAttributes(Seed int NULL);
 CREATE TABLE #ExamplePlanDetailsPlans(Seed int NULL);
 SET @Before=SYSUTCDATETIME();
 EXEC monitor.USP_PlanDetails @SessionIds=@Sessions,@PlanHandle=@Plan,@SqlHandle=@SqlHandle,@QueryHash=@Hash,
 @MaxAnalyseobjekte=@Max,@HighImpactConfirmed=1,@MaxSqlTextZeichen=@Limit,@MitPlanAttributes=@Attrs,@MitCompilePlan=@Compile,
 @MitTextPlan=@Text,@MitLastActualPlan=@Actual,@MitLivePlan=@Live,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
 @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 SET @After=SYSUTCDATETIME();
 IF @@LOCK_TIMEOUT<>137 THROW 59701,N'PLAN_DETAILS_CALLER_TIMEOUT',1;
 IF ISNULL(ISJSON(@Json),0)<>1 OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),N'')<>@Expected
 OR JSON_VALUE(@Json,'$.meta.isPartial')<>N'false' THROW 59702,N'PLAN_DETAILS_STATUS',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>5 OR EXISTS(SELECT 1 FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json)
 EXCEPT SELECT n,t FROM (VALUES(N'meta',5),(N'candidates',4),(N'attributes',4),(N'plans',4),(N'warnings',4))v(n,t))
 OR JSON_QUERY(@Json,'$.warnings')<>N'[]' THROW 59703,N'PLAN_DETAILS_JSON_TOP',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>8 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json,'$.meta') EXCEPT
 SELECT n,t FROM (VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),(N'isPartial',3),
 (N'candidateCount',2),(N'errorNumber',0),(N'errorMessage',CASE WHEN @Expected='INVALID_PARAMETER' THEN 1 ELSE 0 END))v(n,t))
 OR JSON_VALUE(@Json,'$.meta.resultName')<>N'PlanDetails' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),0)<>1
 OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL
 OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After THROW 59704,N'PLAN_DETAILS_JSON_META',1;
 DELETE #ExamplePlanDetailsArrayCheck;
 DECLARE ArrayCursor CURSOR LOCAL FAST_FORWARD FOR SELECT n,t,s FROM (VALUES
 (N'candidates',N'#ExamplePlanDetailsCandidates',N'#ExamplePlanDetailsSchema_candidates'),
 (N'attributes',N'#ExamplePlanDetailsAttributes',N'#ExamplePlanDetailsSchema_attributes'),
 (N'plans',N'#ExamplePlanDetailsPlans',N'#ExamplePlanDetailsSchema_plans'))v(n,t,s);
 OPEN ArrayCursor;FETCH NEXT FROM ArrayCursor INTO @ArrayName,@Target,@Template;
 WHILE @@FETCH_STATUS=0
 BEGIN
 SET @ObjectId=OBJECT_ID(N'tempdb..'+@Target);SET @ExpectedObjectId=OBJECT_ID(N'tempdb..'+@Template);
 IF EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
 FROM tempdb.sys.columns WHERE object_id=@ObjectId EXCEPT
 SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
 FROM tempdb.sys.columns WHERE object_id=@ExpectedObjectId)
 OR EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
 FROM tempdb.sys.columns WHERE object_id=@ExpectedObjectId EXCEPT
 SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
 FROM tempdb.sys.columns WHERE object_id=@ObjectId) THROW 59705,N'PLAN_DETAILS_SCHEMA',1;
 DECLARE @TableJson nvarchar(max),@Projection nvarchar(max)=CASE WHEN @ArrayName=N'plans' THEN
 N'[CandidateId],[SourceType],[StatusCode],[DatabaseId],[ObjectId],[IsEncrypted],CONVERT(nvarchar(max),[QueryPlanXml]) AS [QueryPlanXml],[QueryPlanText],[ErrorNumber],[ErrorMessage]' ELSE N'*' END;
 SET @Sql=N'SELECT @j=(SELECT '+@Projection+N' FROM '+QUOTENAME(@Target)+N' FOR JSON PATH,INCLUDE_NULL_VALUES),@c=COUNT(*) FROM '+QUOTENAME(@Target)+N';';
 EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@c int OUTPUT',@j=@TableJson OUTPUT,@c=@Count OUTPUT;
 INSERT #ExamplePlanDetailsArrayCheck VALUES(@ArrayName,COALESCE(@TableJson,N'[]'),JSON_QUERY(@Json,N'$.'+@ArrayName));
 IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.'+@ArrayName)a WHERE
 (SELECT COUNT(*) FROM OPENJSON(a.value))<>(SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=@ExpectedObjectId)
 OR EXISTS(SELECT 1 FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=@ExpectedObjectId)) THROW 59706,N'PLAN_DETAILS_FIELDS',1;
 IF @ArrayName=N'candidates' AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.candidateCount')),-1)<>@Count THROW 59707,N'PLAN_DETAILS_COUNT',1;
 FETCH NEXT FROM ArrayCursor INTO @ArrayName,@Target,@Template;
 END;
 CLOSE ArrayCursor;DEALLOCATE ArrayCursor;
 IF EXISTS(SELECT 1 FROM #ExamplePlanDetailsArrayCheck q WHERE
 EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(q.TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2
 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(q.JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(q.JsonArray) GROUP BY value COLLATE Latin1_General_100_BIN2
 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(q.TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)) THROW 59708,N'PLAN_DETAILS_FULL_PARITY',1;
 IF @Expected='INVALID_PARAMETER' AND EXISTS(SELECT 1 FROM #ExamplePlanDetailsArrayCheck WHERE TableJson<>N'[]') THROW 59709,N'PLAN_DETAILS_INVALID_EMPTY',1;
 IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.candidates')a WHERE ISNULL(TRY_CONVERT(int,JSON_VALUE(a.value,'$.CandidateId')),-1)<>CONVERT(int,a.[key])+1) THROW 59710,N'PLAN_DETAILS_CANDIDATE_ORDINALS',1;
 IF @Case<100 AND @SessionKind IN(1,4) AND @Expected='AVAILABLE'
 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.candidates'))<>1 THROW 59710,N'PLAN_DETAILS_OWN_REQUEST',1;
 IF @Case=5 AND (NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.attributes')) OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.plans'))<>2) THROW 59710,N'PLAN_DETAILS_OWN_DETAILS',1;

 IF @Case>=100
 BEGIN
  DECLARE @ExpectedCandidateCount int=CASE WHEN @SelectorKind IN(1,3) THEN 1 WHEN @Max=1 THEN 1 ELSE 2 END;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.candidates'))<>@ExpectedCandidateCount THROW 59711,N'PLAN_DETAILS_NATIVE_SELECTION',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.candidates')a WHERE
   NOT EXISTS(SELECT 1 FROM #ExamplePlanDetailsNative n WHERE JSON_VALUE(a.value,'$.PlanHandle') COLLATE Latin1_General_100_BIN2=JSON_VALUE((SELECT n.PlanHandle AS PlanHandle FOR JSON PATH,WITHOUT_ARRAY_WRAPPER),'$.PlanHandle') COLLATE Latin1_General_100_BIN2)) THROW 59711,N'PLAN_DETAILS_NATIVE_HANDLE',1;
  DECLARE @ExpectedNativeJson nvarchar(max),@ExpectedAttributes nvarchar(max),@ExpectedPlans nvarchar(max);
  -- Candidate ordinals are local identifiers; selector fields are compared to
  -- independent native inputs, not inferred from the other JSON consumer.
  SET @Sql=N'
  DECLARE @cap bigint=CASE WHEN @mx IS NULL OR @mx=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@mx) END;
  DECLARE @sqlCap bigint=CASE WHEN @sel=4 THEN @cap-1 ELSE @cap END;
  IF EXISTS(SELECT 1 FROM #ExamplePlanDetailsCandidates c WHERE c.SqlHandle IS NOT NULL
   AND NOT EXISTS(SELECT 1 FROM #ExamplePlanDetailsNative n WHERE n.PlanHandle=c.PlanHandle AND n.SqlHandle=c.SqlHandle
    AND n.StartOffset=c.StatementStartOffset AND n.EndOffset=c.StatementEndOffset
    AND n.QueryHash=c.QueryHash AND n.QueryPlanHash=c.QueryPlanHash AND (@sel<>3 OR n.QueryHash=@qh)))
  OR EXISTS(SELECT 1 FROM #ExamplePlanDetailsCandidates WHERE SqlHandle IS NOT NULL
   GROUP BY PlanHandle,SqlHandle,StatementStartOffset HAVING COUNT(*)<>1)
   THROW 59711,N''PLAN_DETAILS_NATIVE_ELIGIBILITY_OR_DUPLICATE'',1;
  IF @sel IN(2,3,4)
  BEGIN
   DECLARE @eligible int=(SELECT COUNT(*) FROM #ExamplePlanDetailsNative WHERE @sel<>3 OR QueryHash=@qh);
   DECLARE @wanted bigint=CASE WHEN @eligible<@sqlCap THEN @eligible ELSE @sqlCap END;
   IF (SELECT COUNT(*) FROM #ExamplePlanDetailsCandidates WHERE SqlHandle IS NOT NULL)<>@wanted
    THROW 59711,N''PLAN_DETAILS_NATIVE_ELIGIBLE_COUNT'',1;
   IF @sqlCap>=@eligible AND EXISTS
   (SELECT PlanHandle,SqlHandle,StartOffset FROM #ExamplePlanDetailsNative WHERE @sel<>3 OR QueryHash=@qh
    EXCEPT SELECT PlanHandle,SqlHandle,StatementStartOffset FROM #ExamplePlanDetailsCandidates WHERE SqlHandle IS NOT NULL)
    THROW 59711,N''PLAN_DETAILS_NATIVE_ALL_RETAINED_KEYS'',1;
   DECLARE @cutoff bigint=(SELECT MIN(TotalWorkerTime) FROM
    (SELECT TOP(@sqlCap) TotalWorkerTime FROM #ExamplePlanDetailsNative WHERE @sel<>3 OR QueryHash=@qh ORDER BY TotalWorkerTime DESC)r);
   IF EXISTS(SELECT 1 FROM #ExamplePlanDetailsCandidates c JOIN #ExamplePlanDetailsNative n
    ON n.PlanHandle=c.PlanHandle AND n.SqlHandle=c.SqlHandle AND n.StartOffset=c.StatementStartOffset
    WHERE n.TotalWorkerTime<@cutoff) THROW 59711,N''PLAN_DETAILS_NATIVE_WORKER_RANK'',1;
  END;
  SELECT @j=(SELECT c.CandidateId,
   CONVERT(smallint,NULL) AS SessionId,CONVERT(int,NULL) AS RequestId,n.PlanHandle,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.SqlHandle END AS SqlHandle,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.QueryHash END AS QueryHash,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.QueryPlanHash END AS QueryPlanHash,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.StartOffset END AS StatementStartOffset,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.EndOffset END AS StatementEndOffset,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.CreationTime END AS CreationTime,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.LastExecutionTime END AS LastExecutionTime,
   CASE WHEN c.SqlHandle IS NOT NULL THEN n.ExecutionCount END AS ExecutionCount,
   CONVERT(bigint,LEN((st.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) AS StatementTextCharacters,
   CONVERT(bigint,DATALENGTH(st.StatementText)) AS StatementTextBytes,
   CONVERT(bit,CASE WHEN @lim>0 AND LEN((st.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@lim THEN 1 ELSE 0 END) AS StatementTextIsTruncated,
   CASE WHEN @lim>0 THEN LEFT(st.StatementText COLLATE Latin1_General_100_CI_AS_SC,@lim) ELSE st.StatementText COLLATE Latin1_General_100_CI_AS_SC END AS StatementText,
   CONVERT(bigint,LEN((n.BatchText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) AS BatchTextCharacters,
   CONVERT(bigint,DATALENGTH(n.BatchText)) AS BatchTextBytes,
   CONVERT(bit,CASE WHEN @lim>0 AND LEN((n.BatchText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@lim THEN 1 ELSE 0 END) AS BatchTextIsTruncated,
   CASE WHEN @lim>0 THEN LEFT(n.BatchText COLLATE Latin1_General_100_CI_AS_SC,@lim) ELSE n.BatchText COLLATE Latin1_General_100_CI_AS_SC END AS BatchText,
   n.DatabaseId AS SqlTextDatabaseId,@db AS SqlTextDatabaseName,n.ObjectId AS SqlTextObjectId
  FROM #ExamplePlanDetailsCandidates c
  CROSS APPLY(SELECT TOP(1)* FROM #ExamplePlanDetailsNative n WHERE n.PlanHandle=c.PlanHandle
   AND (c.SqlHandle IS NULL OR (n.StartOffset=c.StatementStartOffset AND n.SqlHandle=c.SqlHandle)) ORDER BY n.StartOffset)n
  CROSS APPLY(SELECT CASE WHEN c.SqlHandle IS NULL THEN n.BatchText COLLATE Latin1_General_100_BIN2 ELSE
   SUBSTRING(n.BatchText COLLATE Latin1_General_100_BIN2,n.StartOffset/2+1,
    ((CASE WHEN n.EndOffset=-1 THEN DATALENGTH(n.BatchText) ELSE n.EndOffset END)-n.StartOffset)/2+1) END AS StatementText)st
  FOR JSON PATH,INCLUDE_NULL_VALUES);
  SELECT @a=(SELECT c.CandidateId,CONVERT(varchar(128),pa.attribute) AS AttributeName,CONVERT(nvarchar(4000),pa.value) AS AttributeValue,pa.is_cache_key AS IsCacheKey
   FROM #ExamplePlanDetailsCandidates c CROSS APPLY sys.dm_exec_plan_attributes(c.PlanHandle)pa
   WHERE @attrs=1 FOR JSON PATH,INCLUDE_NULL_VALUES);
  SELECT @p=(SELECT * FROM (SELECT c.CandidateId,N''COMPILE_XML'' AS SourceType,
   CASE WHEN qp.query_plan IS NULL THEN N''UNAVAILABLE_OBJECT'' ELSE N''AVAILABLE'' END AS StatusCode,
   qp.dbid AS DatabaseId,qp.objectid AS ObjectId,qp.encrypted AS IsEncrypted,
   CONVERT(nvarchar(max),qp.query_plan) AS QueryPlanXml,CONVERT(nvarchar(max),NULL) AS QueryPlanText,CONVERT(int,NULL) AS ErrorNumber,
   CASE WHEN qp.query_plan IS NULL THEN N''Plan nicht mehr im Cache oder XML-Tiefenlimit erreicht.'' END AS ErrorMessage
   FROM #ExamplePlanDetailsCandidates c OUTER APPLY sys.dm_exec_query_plan(c.PlanHandle)qp WHERE @compile=1
   UNION ALL
   SELECT c.CandidateId,N''COMPILE_TEXT'',CASE WHEN tp.query_plan IS NULL THEN N''UNAVAILABLE_OBJECT'' ELSE N''AVAILABLE'' END,
   tp.dbid,tp.objectid,tp.encrypted,CONVERT(nvarchar(max),NULL),tp.query_plan,CONVERT(int,NULL),
   CASE WHEN tp.query_plan IS NULL THEN N''Textplan nicht verfügbar.'' END
   FROM #ExamplePlanDetailsCandidates c OUTER APPLY sys.dm_exec_text_query_plan(c.PlanHandle,COALESCE(c.StatementStartOffset,0),COALESCE(c.StatementEndOffset,-1))tp WHERE @text=1) AS NativePlans
   FOR JSON PATH,INCLUDE_NULL_VALUES);';
  EXEC sys.sp_executesql @Sql,N'@lim int,@db sysname,@attrs bit,@compile bit,@text bit,@sel int,@qh binary(8),@mx int,@j nvarchar(max) OUTPUT,@a nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT',
   @lim=@Limit,@db=@FixtureDatabase,@attrs=@Attrs,@compile=@Compile,@text=@Text,@sel=@SelectorKind,@qh=@Hash,@mx=@Max,@j=@ExpectedNativeJson OUTPUT,@a=@ExpectedAttributes OUTPUT,@p=@ExpectedPlans OUTPUT;
  DECLARE @NativeActual nvarchar(max)=JSON_QUERY(@Json,'$.candidates');
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedNativeJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@NativeActual) GROUP BY value COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@NativeActual) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedNativeJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 59712,N'PLAN_DETAILS_NATIVE_CANDIDATES',1;
  IF @Attrs=1 AND (EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@ExpectedAttributes) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.attributes') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.attributes') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@ExpectedAttributes) GROUP BY value COLLATE Latin1_General_100_BIN2)) THROW 59713,N'PLAN_DETAILS_NATIVE_ATTRIBUTES',1;
  IF @Live=0 AND (EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedPlans,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.plans') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.plans') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedPlans,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)) THROW 59714,N'PLAN_DETAILS_NATIVE_PLANS',1;
  IF @Case=110 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.plans') WHERE JSON_VALUE(value,'$.SourceType')=N'LIVE_XML'
   AND JSON_VALUE(value,'$.StatusCode')=N'INVALID_PARAMETER' AND EXISTS(SELECT 1 FROM OPENJSON(value) WHERE [key]=N'CandidateId' AND [type]=0)) THROW 59714,N'PLAN_DETAILS_LIVE_SELECTOR_REJECTION',1;
  IF @Case=100
  BEGIN
   DECLARE @MutationField sysname,@Mutation nvarchar(max),@ActualRow nvarchar(max)=JSON_QUERY(@Json,'$.candidates[0]'),@MutationError int;
   DECLARE MutationCursor CURSOR LOCAL FAST_FORWARD FOR SELECT n FROM (VALUES(N'PlanHandle'),(N'BatchText'),(N'SqlTextDatabaseName'))f(n);
   OPEN MutationCursor;FETCH NEXT FROM MutationCursor INTO @MutationField;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @MutationError=0;SET @Mutation=JSON_MODIFY(@ActualRow,N'strict $.'+@MutationField,NULL);
    SET @NativeActual=N'['+@Mutation+N']';
    BEGIN TRY
     IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedNativeJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@NativeActual) GROUP BY value COLLATE Latin1_General_100_BIN2)
     OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@NativeActual) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedNativeJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 59712,N'PLAN_DETAILS_NATIVE_CANDIDATES',1;
    END TRY BEGIN CATCH IF ERROR_NUMBER()<>59712 THROW;SET @MutationError=ERROR_NUMBER();END CATCH;
    IF @MutationError<>59712 THROW 59716,N'PLAN_DETAILS_NULL_MUTATION_NOT_REJECTED',1;
    SET @NullMutations+=1;FETCH NEXT FROM MutationCursor INTO @MutationField;
   END;
   CLOSE MutationCursor;DEALLOCATE MutationCursor;
  END;
  SET @NativeCases+=1;
 END ELSE SET @CoreCases+=1;
 DROP TABLE #ExamplePlanDetailsCandidates;
 DROP TABLE #ExamplePlanDetailsAttributes;
 DROP TABLE #ExamplePlanDetailsPlans;
END;
IF @FixtureStatus='PENDING' SET @FixtureStatus='PASS';
-- All four public consumer modes must preserve controlled negative rejection.
DECLARE @Consumer int=0,@Mode varchar(16),@Consumers int=0;
WHILE @Consumer<4
BEGIN
 SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' WHEN 2 THEN 'CONSOLE' ELSE 'unsupported' END;
 EXEC monitor.USP_PlanDetails @SessionIds=@OwnSessions,@MaxSqlTextZeichen=-1,@MitPlanAttributes=0,@MitCompilePlan=0,
 @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF JSON_VALUE(@Json,'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,'$.candidates')<>N'[]'
 OR JSON_QUERY(@Json,'$.attributes')<>N'[]' OR JSON_QUERY(@Json,'$.plans')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 59717,N'PLAN_DETAILS_NEGATIVE_CONSUMER',1;
 SET @Consumers+=1;SET @Consumer+=1;
END;
CREATE TABLE #ExamplePlanDetailsSeed(Seed int NULL);
INSERT #ExamplePlanDetailsSeed VALUES(4242);
DECLARE @Preflight int=0,@BadMap nvarchar(max),@Thrown int,@Preflights int=0;
WHILE @Preflight<6
BEGIN
 SET @BadMap=CASE @Preflight WHEN 0 THEN N'not-json' WHEN 1 THEN N'{}' WHEN 2 THEN N'{"unknown":"#ExamplePlanDetailsSeed"}'
 WHEN 3 THEN N'{"candidates":"#ExamplePlanDetailsAbsent"}' WHEN 4 THEN N'{"candidates":"#ExamplePlanDetailsSeed","plans":"#ExamplePlanDetailsSeed"}' ELSE N'{"candidates":"#ExamplePlanDetailsSeed"}' END;
 SET @Json=N'ExampleSentinel';SET @Thrown=0;
 BEGIN TRY
  EXEC monitor.USP_PlanDetails @MaxSqlTextZeichen=-1,@Hilfe=1,@ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 END TRY BEGIN CATCH IF ERROR_NUMBER()<>51011 THROW;SET @Thrown=ERROR_NUMBER();END CATCH;
 IF @Thrown<>51011 OR @Json<>N'ExampleSentinel' OR (SELECT COUNT(*) FROM #ExamplePlanDetailsSeed WHERE Seed=4242)<>1
 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExamplePlanDetailsSeed'))<>1 THROW 59718,N'PLAN_DETAILS_PREFLIGHT_PRESERVATION',1;
 SET @Preflights+=1;SET @Preflight+=1;
END;
CREATE TABLE #ExamplePlanDetailsHelp(Seed int NULL);
EXEC monitor.USP_PlanDetails @Hilfe=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"candidates":"#ExamplePlanDetailsHelp"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF @Json IS NOT NULL OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExamplePlanDetailsHelp'))<>1 THROW 59719,N'PLAN_DETAILS_HELP',1;
CREATE TABLE #ExamplePlanDetailsConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
DECLARE @EmptyConsole int=0;
WHILE @EmptyConsole<3
BEGIN
 DELETE #ExamplePlanDetailsConsole;
 SET @Sessions=CASE WHEN @EmptyConsole=0 THEN CONVERT(nvarchar(12),@MissingSession) ELSE NULL END;
 SET @Limit=CASE WHEN @EmptyConsole=2 THEN -1 ELSE 0 END;
 INSERT #ExamplePlanDetailsConsole EXEC monitor.USP_PlanDetails @SessionIds=@Sessions,@MaxSqlTextZeichen=@Limit,@MitCompilePlan=0,@MitPlanAttributes=0,
 @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT(*) FROM #ExamplePlanDetailsConsole)<>1 OR NOT EXISTS(SELECT 1 FROM #ExamplePlanDetailsConsole WHERE Ergebnis=N'Keine fachlichen Ergebnisse' AND Status IS NULL AND Hinweis IS NULL)
 OR JSON_QUERY(@Json,'$.candidates')<>N'[]' THROW 59720,N'PLAN_DETAILS_EMPTY_CONSOLE',1;
 SET @EmptyConsole+=1;
END;
EXEC monitor.USP_PlanDetails @SessionIds=@OwnSessions,@MitCompilePlan=0,@MitPlanAttributes=0,@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF @Json IS NOT NULL THROW 59721,N'PLAN_DETAILS_JSON_DISABLED',1;
DECLARE @Restore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';
EXEC sys.sp_executesql @Restore;
SELECT N'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,37 AS SchemaFields,9 AS TextCollations,
 @CoreCases AS CoreCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,@NullMutations AS NativeNullMutations,
 @Consumers AS ConsumerCases,@Preflights AS PreflightCases,@EmptyConsole AS EmptySqlConsoleCases;
END TRY
BEGIN CATCH
 DECLARE @CatchRestore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @CatchRestore;THROW;
END CATCH;
GO
