USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
Prüft die drei PlanDetails-Exporte mit 37 unabhängigen Literal-Schemafeldern
und neun Frameworktextcollations. Allgemeine Fälle prüfen Parameter, frühe
TABLE-Vorprüfung und vollständige gleichaufrufbezogene TABLE-/JSON-Parität.
Acht synthetische Handlevarianten prüfen echte native Quellenfehler und
leere native Quellen. Ihre Länge entscheidet nicht über die Gültigkeit.
Gemischte Fälle bewahren gültige Nachbarkandidaten und ihre Detailquellen.
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
(14,5,0,1,0,0,0,0,0,0,'AVAILABLE'),(15,1,0,21,0,0,0,0,0,0,'AVAILABLE'),
(16,1,7,1,0,1,1,1,0,0,'AVAILABLE');
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
CREATE TABLE #ExamplePlanDetailsHandles
(HandleIndex int NOT NULL PRIMARY KEY,HandleValue varbinary(64) NOT NULL);
INSERT #ExamplePlanDetailsHandles VALUES(0,0x),(1,0x00),(2,0x01),(3,0x0100),
(4,CONVERT(varbinary(64),REPLICATE(CHAR(255),44))),(5,CONVERT(varbinary(64),REPLICATE(CHAR(255),64))),
(6,CONVERT(varbinary(64),REPLICATE(CHAR(0),44))),(7,CONVERT(varbinary(64),REPLICATE(CHAR(0),64)));
CREATE TABLE #ExamplePlanDetailsHandleSources
(HandleIndex int NOT NULL,SourceName varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 ErrorNumber int NULL,ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,NativeRowCount int NULL,
 PRIMARY KEY(HandleIndex,SourceName));
DECLARE @ProbeHandle varbinary(64),@ProbeIndex int=0,@ProbeSource int,@ProbeCount int,@ProbeNumber int,@ProbeMessage nvarchar(2048);
WHILE @ProbeIndex<8
BEGIN
 SELECT @ProbeHandle=HandleValue FROM #ExamplePlanDetailsHandles WHERE HandleIndex=@ProbeIndex;
 SET @ProbeSource=0;
 WHILE @ProbeSource<5
 BEGIN
  SELECT @ProbeCount=NULL,@ProbeNumber=NULL,@ProbeMessage=NULL;
  BEGIN TRY
   IF @ProbeSource=0 SELECT @ProbeCount=COUNT(*) FROM sys.dm_exec_plan_attributes(@ProbeHandle);
   IF @ProbeSource=1 SELECT @ProbeCount=COUNT(*) FROM sys.dm_exec_query_plan(@ProbeHandle);
   IF @ProbeSource=2 SELECT @ProbeCount=COUNT(*) FROM sys.dm_exec_text_query_plan(@ProbeHandle,0,-1);
   IF @ProbeSource=3 SELECT @ProbeCount=COUNT(*) FROM sys.dm_exec_query_plan_stats(@ProbeHandle);
   IF @ProbeSource=4 SELECT @ProbeCount=COUNT(*) FROM sys.dm_exec_sql_text(@ProbeHandle);
  END TRY BEGIN CATCH SELECT @ProbeNumber=ERROR_NUMBER(),@ProbeMessage=ERROR_MESSAGE();END CATCH;
  INSERT #ExamplePlanDetailsHandleSources VALUES(@ProbeIndex,CASE @ProbeSource WHEN 0 THEN 'ATTRIBUTES' WHEN 1 THEN 'COMPILE_XML'
   WHEN 2 THEN 'COMPILE_TEXT' WHEN 3 THEN 'LAST_ACTUAL_XML' ELSE 'SQL_TEXT' END,@ProbeNumber,@ProbeMessage,@ProbeCount);
  SET @ProbeSource+=1;
 END;
 SET @ProbeIndex+=1;
END;
IF EXISTS(SELECT 1 FROM #ExamplePlanDetailsHandleSources WHERE
 (HandleIndex<6 AND (ISNULL(ErrorNumber,0)<>569 OR ErrorMessage IS NULL OR NativeRowCount IS NOT NULL))
 OR (HandleIndex>=6 AND (ErrorNumber IS NOT NULL OR ErrorMessage IS NOT NULL OR ISNULL(NativeRowCount,-1)<>0)))
 THROW 59722,N'PLAN_DETAILS_NATIVE_HANDLE_PROBES',1;
CREATE TABLE #ExamplePlanDetailsHandleCases
(CaseNumber int NOT NULL PRIMARY KEY,HandleIndex int NOT NULL,Mixed bit NOT NULL,Details bit NULL);
INSERT #ExamplePlanDetailsHandleCases SELECT 200+h.HandleIndex*2+d.n,h.HandleIndex,0,d.n
 FROM #ExamplePlanDetailsHandles h CROSS JOIN(VALUES(0),(1))d(n);
IF @FixtureStatus='PENDING'
 INSERT #ExamplePlanDetailsHandleCases SELECT 300+h.HandleIndex*10+d.n*5+m.n,h.HandleIndex,1,d.n
 FROM #ExamplePlanDetailsHandles h CROSS JOIN(VALUES(0),(1))d(n) CROSS JOIN(VALUES(0),(1),(2),(3),(4))m(n);
INSERT #ExamplePlanDetailsHandleCases VALUES(216,4,0,NULL),(217,4,0,1),(218,4,0,1),(219,4,0,1),(220,4,0,1);
INSERT #ExamplePlanDetailsCases
 SELECT c.CaseNumber,0,CASE WHEN c.Mixed=1 THEN 6 ELSE 5 END,
 CASE WHEN c.Mixed=0 THEN 3 ELSE CASE (c.CaseNumber-300)%5 WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 WHEN 3 THEN 0 ELSE NULL END END,
 0,c.Details,c.Details,c.Details,c.Details,0,CASE WHEN c.HandleIndex<6 THEN 'PARTIAL' ELSE 'AVAILABLE' END
 FROM #ExamplePlanDetailsHandleCases c;
UPDATE #ExamplePlanDetailsCases SET AttributesFlag=CASE WHEN CaseNumber=217 THEN 1 ELSE 0 END,
 CompileFlag=CASE WHEN CaseNumber=218 THEN 1 ELSE 0 END,TextFlag=CASE WHEN CaseNumber=219 THEN 1 ELSE 0 END,
 ActualFlag=CASE WHEN CaseNumber=220 THEN 1 ELSE 0 END WHERE CaseNumber BETWEEN 217 AND 220;
CREATE TABLE #ExamplePlanDetailsHandleContracts
(HandleIndex int NOT NULL,Details bit NOT NULL,ExpectedJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PRIMARY KEY(HandleIndex,Details));
DECLARE @HandleCases int=0,@MixedHandleCases int=0,@HandleConsumerCases int=0,
 @HandleIndex int,@HandleDetails bit,@HandleError int,@HandleMessage nvarchar(2048),@ExpectedBadCandidates nvarchar(max),
 @ExpectedNativeJson nvarchar(max),@ExpectedAttributes nvarchar(max),@ExpectedPlans nvarchar(max),
 @ExpectedBadPlans nvarchar(max),@HandleActual nvarchar(max),@HandleExpected nvarchar(max);
DECLARE @HealthyOracleSql nvarchar(max)=N'
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
   FROM #ExamplePlanDetailsCandidates c CROSS APPLY sys.dm_exec_plan_attributes(@ph)pa
   WHERE @attrs=1 AND c.PlanHandle=@ph FOR JSON PATH,INCLUDE_NULL_VALUES);
  SELECT @p=(SELECT * FROM (SELECT c.CandidateId,N''COMPILE_XML'' AS SourceType,
   CASE WHEN qp.query_plan IS NULL THEN N''UNAVAILABLE_OBJECT'' ELSE N''AVAILABLE'' END AS StatusCode,
   qp.dbid AS DatabaseId,qp.objectid AS ObjectId,qp.encrypted AS IsEncrypted,
   CONVERT(nvarchar(max),qp.query_plan) AS QueryPlanXml,CONVERT(nvarchar(max),NULL) AS QueryPlanText,CONVERT(int,NULL) AS ErrorNumber,
   CASE WHEN qp.query_plan IS NULL THEN N''Plan nicht mehr im Cache oder XML-Tiefenlimit erreicht.'' END AS ErrorMessage
   FROM #ExamplePlanDetailsCandidates c OUTER APPLY sys.dm_exec_query_plan(@ph)qp WHERE @compile=1 AND c.PlanHandle=@ph
   UNION ALL
   SELECT c.CandidateId,N''COMPILE_TEXT'',CASE WHEN tp.query_plan IS NULL THEN N''UNAVAILABLE_OBJECT'' ELSE N''AVAILABLE'' END,
   tp.dbid,tp.objectid,tp.encrypted,CONVERT(nvarchar(max),NULL),tp.query_plan,CONVERT(int,NULL),
   CASE WHEN tp.query_plan IS NULL THEN N''Textplan nicht verfügbar.'' END
   FROM #ExamplePlanDetailsCandidates c OUTER APPLY sys.dm_exec_text_query_plan(@ph,COALESCE(c.StatementStartOffset,0),COALESCE(c.StatementEndOffset,-1))tp WHERE @text=1 AND c.PlanHandle=@ph
   UNION ALL
   SELECT c.CandidateId,N''LAST_ACTUAL_XML'',CASE WHEN qp.query_plan IS NULL THEN N''AVAILABLE_DISABLED'' ELSE N''AVAILABLE'' END,
   qp.dbid,qp.objectid,qp.encrypted,CONVERT(nvarchar(max),qp.query_plan),CONVERT(nvarchar(max),NULL),CONVERT(int,NULL),
   CASE WHEN qp.query_plan IS NULL THEN N''LAST_QUERY_PLAN_STATS nicht aktiviert, Plan nicht geeignet, nicht cachebar oder bereits evictet.'' END
   FROM #ExamplePlanDetailsCandidates c OUTER APPLY sys.dm_exec_query_plan_stats(@ph)qp WHERE @actual=1 AND c.PlanHandle=@ph) AS NativePlans
   FOR JSON PATH,INCLUDE_NULL_VALUES);';
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
 SET @Plan=CASE WHEN @SelectorKind IN(1,4) THEN @FixtureHandle WHEN @SelectorKind=7 THEN 0x END;
 SET @SqlHandle=CASE WHEN @SelectorKind IN(2,4) THEN (SELECT MIN(SqlHandle) FROM #ExamplePlanDetailsNative) END;
 SET @Hash=CASE WHEN @SelectorKind=3 THEN (SELECT MIN(QueryHash) FROM #ExamplePlanDetailsNative) END;
 IF @SelectorKind IN(5,6)
 BEGIN
  SELECT @HandleIndex=HandleIndex,@HandleDetails=Details FROM #ExamplePlanDetailsHandleCases WHERE CaseNumber=@Case;
  SELECT @Plan=HandleValue FROM #ExamplePlanDetailsHandles WHERE HandleIndex=@HandleIndex;
  SET @SqlHandle=CASE WHEN @SelectorKind=6 THEN (SELECT MIN(SqlHandle) FROM #ExamplePlanDetailsNative) END;
  SELECT @HandleError=ErrorNumber,@HandleMessage=ErrorMessage FROM #ExamplePlanDetailsHandleSources
   WHERE HandleIndex=@HandleIndex AND SourceName=CASE WHEN @Attrs=1 THEN 'ATTRIBUTES' WHEN @Compile=1 THEN 'COMPILE_XML' WHEN @Text=1 THEN 'COMPILE_TEXT' WHEN @Actual=1 THEN 'LAST_ACTUAL_XML' ELSE 'SQL_TEXT' END;
 END;

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
 OR ISNULL(JSON_VALUE(@Json,'$.meta.isPartial'),N'')<>CASE WHEN @Expected='PARTIAL' THEN N'true' ELSE N'false' END THROW 59702,N'PLAN_DETAILS_STATUS',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>5 OR EXISTS(SELECT 1 FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json)
 EXCEPT SELECT n,t FROM (VALUES(N'meta',5),(N'candidates',4),(N'attributes',4),(N'plans',4),(N'warnings',4))v(n,t))
 OR JSON_QUERY(@Json,'$.warnings')<>N'[]' THROW 59703,N'PLAN_DETAILS_JSON_TOP',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>8 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json,'$.meta') EXCEPT
 SELECT n,t FROM (VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),(N'isPartial',3),
 (N'candidateCount',2),(N'errorNumber',CASE WHEN @Expected='PARTIAL' THEN 2 ELSE 0 END),(N'errorMessage',CASE WHEN @Expected IN('INVALID_PARAMETER','PARTIAL') THEN 1 ELSE 0 END))v(n,t))
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

 IF @Case BETWEEN 100 AND 111
 BEGIN
  DECLARE @ExpectedCandidateCount int=CASE WHEN @SelectorKind IN(1,3) THEN 1 WHEN @Max=1 THEN 1 ELSE 2 END;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.candidates'))<>@ExpectedCandidateCount THROW 59711,N'PLAN_DETAILS_NATIVE_SELECTION',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.candidates')a WHERE
   NOT EXISTS(SELECT 1 FROM #ExamplePlanDetailsNative n WHERE JSON_VALUE(a.value,'$.PlanHandle') COLLATE Latin1_General_100_BIN2=JSON_VALUE((SELECT n.PlanHandle AS PlanHandle FOR JSON PATH,WITHOUT_ARRAY_WRAPPER),'$.PlanHandle') COLLATE Latin1_General_100_BIN2)) THROW 59711,N'PLAN_DETAILS_NATIVE_HANDLE',1;

  -- Candidate ordinals are local identifiers; selector fields are compared to
  -- independent native inputs, not inferred from the other JSON consumer.
  SET @Sql=@HealthyOracleSql;
  EXEC sys.sp_executesql @Sql,N'@lim int,@db sysname,@attrs bit,@compile bit,@text bit,@actual bit,@sel int,@qh binary(8),@mx int,@ph varbinary(64),@j nvarchar(max) OUTPUT,@a nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT',
   @lim=@Limit,@db=@FixtureDatabase,@attrs=@Attrs,@compile=@Compile,@text=@Text,@actual=@Actual,@sel=@SelectorKind,@qh=@Hash,@mx=@Max,@ph=@FixtureHandle,@j=@ExpectedNativeJson OUTPUT,@a=@ExpectedAttributes OUTPUT,@p=@ExpectedPlans OUTPUT;
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
 END
 ELSE IF @SelectorKind IN(5,6)
 BEGIN
  IF ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.errorNumber')),-1)<>ISNULL(@HandleError,-1)
   OR (@HandleMessage IS NOT NULL AND (JSON_VALUE(@Json,'$.meta.errorMessage') IS NULL
     OR JSON_VALUE(@Json,'$.meta.errorMessage') COLLATE Latin1_General_100_BIN2<>@HandleMessage COLLATE Latin1_General_100_BIN2))
   OR (@HandleMessage IS NULL AND JSON_VALUE(@Json,'$.meta.errorMessage') IS NOT NULL)
   THROW 59723,N'PLAN_DETAILS_HANDLE_FIRST_ERROR',1;
  DECLARE @HandleWanted int=CASE WHEN @SelectorKind=5 OR @Max=1 THEN 1 WHEN @Max=2 THEN 2 ELSE 3 END;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.candidates'))<>@HandleWanted
   OR NOT EXISTS(SELECT 1 FROM #ExamplePlanDetailsCandidates WHERE CandidateId=1 AND PlanHandle=@Plan AND SqlHandle IS NULL)
   THROW 59724,N'PLAN_DETAILS_HANDLE_SELECTION',1;
  SET @ExpectedBadCandidates=(SELECT
   CONVERT(int,1) AS [CandidateId],
   CONVERT(smallint,NULL) AS [SessionId],
   CONVERT(int,NULL) AS [RequestId],
   @Plan AS [PlanHandle],
   CONVERT(varbinary(64),NULL) AS [SqlHandle],
   CONVERT(binary(8),NULL) AS [QueryHash],
   CONVERT(binary(8),NULL) AS [QueryPlanHash],
   CONVERT(int,NULL) AS [StatementStartOffset],
   CONVERT(int,NULL) AS [StatementEndOffset],
   CONVERT(datetime,NULL) AS [CreationTime],
   CONVERT(datetime,NULL) AS [LastExecutionTime],
   CONVERT(bigint,NULL) AS [ExecutionCount],
   CONVERT(bigint,NULL) AS [StatementTextCharacters],
   CONVERT(bigint,NULL) AS [StatementTextBytes],
   CONVERT(bit,0) AS [StatementTextIsTruncated],
   CONVERT(nvarchar(max),NULL) AS [StatementText],
   CONVERT(bigint,NULL) AS [BatchTextCharacters],
   CONVERT(bigint,NULL) AS [BatchTextBytes],
   CONVERT(bit,0) AS [BatchTextIsTruncated],
   CONVERT(nvarchar(max),NULL) AS [BatchText],
   CONVERT(int,NULL) AS [SqlTextDatabaseId],
   CONVERT(sysname,NULL) AS [SqlTextDatabaseName],
   CONVERT(int,NULL) AS [SqlTextObjectId]
   FOR JSON PATH,INCLUDE_NULL_VALUES);
  SET @ExpectedBadPlans=(SELECT CONVERT(int,1) AS CandidateId,CONVERT(varchar(24),e.SourceName) AS SourceType,
   CONVERT(varchar(40),CASE WHEN e.ErrorNumber IS NOT NULL THEN 'ERROR_HANDLED' WHEN e.SourceName='LAST_ACTUAL_XML' THEN 'AVAILABLE_DISABLED' ELSE 'UNAVAILABLE_OBJECT' END) AS StatusCode,
   CONVERT(int,NULL) AS DatabaseId,CONVERT(int,NULL) AS ObjectId,CONVERT(bit,NULL) AS IsEncrypted,
   CONVERT(nvarchar(max),NULL) AS QueryPlanXml,CONVERT(nvarchar(max),NULL) AS QueryPlanText,e.ErrorNumber,
   CONVERT(nvarchar(2048),CASE WHEN e.ErrorNumber IS NOT NULL THEN e.ErrorMessage WHEN e.SourceName='COMPILE_XML' THEN N'Plan nicht mehr im Cache oder XML-Tiefenlimit erreicht.'
    WHEN e.SourceName='COMPILE_TEXT' THEN N'Textplan nicht verfügbar.' ELSE N'LAST_QUERY_PLAN_STATS nicht aktiviert, Plan nicht geeignet, nicht cachebar oder bereits evictet.' END) AS ErrorMessage
   FROM #ExamplePlanDetailsHandleSources e WHERE e.HandleIndex=@HandleIndex AND e.SourceName IN('COMPILE_XML','COMPILE_TEXT','LAST_ACTUAL_XML')
   AND ((e.SourceName='COMPILE_XML' AND @Compile=1) OR (e.SourceName='COMPILE_TEXT' AND @Text=1) OR (e.SourceName='LAST_ACTUAL_XML' AND @Actual=1)) ORDER BY e.SourceName FOR JSON PATH,INCLUDE_NULL_VALUES);
  SELECT @ExpectedNativeJson=N'[]',@ExpectedAttributes=N'[]',@ExpectedPlans=N'[]';
  IF @SelectorKind=6
  BEGIN
   EXEC sys.sp_executesql @HealthyOracleSql,N'@lim int,@db sysname,@attrs bit,@compile bit,@text bit,@actual bit,@sel int,@qh binary(8),@mx int,@ph varbinary(64),@j nvarchar(max) OUTPUT,@a nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT',
    @lim=@Limit,@db=@FixtureDatabase,@attrs=@Attrs,@compile=@Compile,@text=@Text,@actual=@Actual,@sel=4,@qh=NULL,@mx=@Max,@ph=@FixtureHandle,
    @j=@ExpectedNativeJson OUTPUT,@a=@ExpectedAttributes OUTPUT,@p=@ExpectedPlans OUTPUT;
  END;
  SET @HandleExpected=N'['+SUBSTRING(@ExpectedBadCandidates,2,LEN(@ExpectedBadCandidates)-2)
   +CASE WHEN COALESCE(@ExpectedNativeJson,N'[]')<>N'[]' THEN N','+SUBSTRING(@ExpectedNativeJson,2,LEN(@ExpectedNativeJson)-2) ELSE N'' END+N']';
  SET @HandleActual=JSON_QUERY(@Json,'$.candidates');
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleExpected) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleActual) GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleActual) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleExpected) GROUP BY value COLLATE Latin1_General_100_BIN2)
   THROW 59725,N'PLAN_DETAILS_HANDLE_FULL_CANDIDATES',1;
  SET @HandleExpected=CASE WHEN COALESCE(@ExpectedBadPlans,N'[]')=N'[]' THEN COALESCE(@ExpectedPlans,N'[]')
   WHEN COALESCE(@ExpectedPlans,N'[]')=N'[]' THEN @ExpectedBadPlans
   ELSE LEFT(@ExpectedBadPlans,LEN(@ExpectedBadPlans)-1)+N','+SUBSTRING(@ExpectedPlans,2,LEN(@ExpectedPlans)-1) END;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleExpected) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.plans') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.plans') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@HandleExpected) GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedAttributes,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.attributes') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.attributes') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedAttributes,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
   THROW 59726,N'PLAN_DETAILS_HANDLE_FULL_DETAILS',1;
  IF @SelectorKind=5
  BEGIN
   IF @Case BETWEEN 200 AND 215 INSERT #ExamplePlanDetailsHandleContracts VALUES(@HandleIndex,@HandleDetails,@Json);
   SET @HandleCases+=1;
  END ELSE SET @MixedHandleCases+=1;
 END ELSE SET @CoreCases+=1;

 DROP TABLE #ExamplePlanDetailsCandidates;
 DROP TABLE #ExamplePlanDetailsAttributes;
 DROP TABLE #ExamplePlanDetailsPlans;
END;
IF @FixtureStatus='PENDING' SET @FixtureStatus='PASS';
DECLARE @HandleContract nvarchar(max),@HandleMode varchar(16),@HandleModeIndex int;
SET @HandleIndex=0;
WHILE @HandleIndex<8
BEGIN
 SET @ProbeSource=0;
 WHILE @ProbeSource<2
 BEGIN
  SET @HandleDetails=CONVERT(bit,@ProbeSource);
  SELECT @Plan=HandleValue FROM #ExamplePlanDetailsHandles WHERE HandleIndex=@HandleIndex;
  SELECT @HandleContract=ExpectedJson FROM #ExamplePlanDetailsHandleContracts WHERE HandleIndex=@HandleIndex AND Details=@HandleDetails;
  SET @HandleModeIndex=0;
  WHILE @HandleModeIndex<3
  BEGIN
   SET @HandleMode=CASE @HandleModeIndex WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'CONSOLE' END;
   SET @Before=SYSUTCDATETIME();
   EXEC monitor.USP_PlanDetails @PlanHandle=@Plan,@MitPlanAttributes=@HandleDetails,@MitCompilePlan=@HandleDetails,
    @MitTextPlan=@HandleDetails,@MitLastActualPlan=@HandleDetails,@MaxSqlTextZeichen=0,@ResultSetArt=@HandleMode,
    @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   SET @After=SYSUTCDATETIME();
   IF ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>137
    OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5 OR EXISTS(SELECT 1 FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>8 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
    OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL
    OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
    OR JSON_VALUE(@Json,'$.meta.statusCode')<>JSON_VALUE(@HandleContract,'$.meta.statusCode')
    OR JSON_VALUE(@Json,'$.meta.isPartial')<>JSON_VALUE(@HandleContract,'$.meta.isPartial')
    OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.errorNumber')),-1)<>ISNULL(TRY_CONVERT(int,JSON_VALUE(@HandleContract,'$.meta.errorNumber')),-1)
    THROW 59727,N'PLAN_DETAILS_HANDLE_CONSUMER_STATUS',1;
   IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json,'$.meta') WHERE [key]<>N'generatedAtUtc'
    EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@HandleContract,'$.meta') WHERE [key]<>N'generatedAtUtc')
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@HandleContract,'$.meta') WHERE [key]<>N'generatedAtUtc'
    EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json,'$.meta') WHERE [key]<>N'generatedAtUtc')
    THROW 59727,N'PLAN_DETAILS_HANDLE_CONSUMER_META',1;

   IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json)
    WHERE [key]<>N'meta' EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@HandleContract) WHERE [key]<>N'meta')
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@HandleContract)
    WHERE [key]<>N'meta' EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json) WHERE [key]<>N'meta')
    THROW 59728,N'PLAN_DETAILS_HANDLE_CONSUMER_FULL_PARITY',1;
   SET @HandleConsumerCases+=1;SET @HandleModeIndex+=1;
  END;
  SET @ProbeSource+=1;
 END;
 SET @HandleIndex+=1;
END;

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
 @HandleCases AS HandleTableCases,@MixedHandleCases AS MixedHandleTableCases,@HandleConsumerCases AS HandleConsumerCases,
 @Consumers AS ConsumerCases,@Preflights AS PreflightCases,@EmptyConsole AS EmptySqlConsoleCases;
END TRY
BEGIN CATCH
 DECLARE @CatchRestore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @CatchRestore;THROW;
END CATCH;
GO
