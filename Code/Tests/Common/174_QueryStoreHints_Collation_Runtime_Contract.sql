USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
P3: Prüft den gemeinsamen 22-Feld-Hintexport mit neun Textcollations.
Allgemeine Fälle wählen einen nachweislich fehlenden Namen; N'' ist kein
Leerscope. Der positive Block liest zwei extern vorbereitete eigene Unicode-
Datenbanken mit unverändertem READ_ONLY Query Store und gesunden Hints.
Ohne passende Fixture bleibt dieser Block NOT_EXECUTED. Der Test erstellt
keine Objekte, führt keine Fixture-Procedures aus und verändert keine Hints
oder Datenbankoptionen. Datenbankübergreifende Sortties bleiben zulässig;
getrennte Aufrufe müssen keine identische Auswahl liefern. Positive RAW- und
CONSOLE-Zeilenparität benötigen zusätzlichen unabhängigen Clientcapture.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 57600,N'HINTS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 57601,N'HINTS_FRAMEWORK_COLLATION',1;
DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0;
DECLARE @UpperName nvarchar(128)=N'ExampleHintÄ🔬',@LowerName nvarchar(128)=N'exampleHintÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingHintÄ🔬',@MissingScope nvarchar(258);
SET @MissingScope=QUOTENAME(@MissingName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
 THROW 57602,N'HINTS_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@Both nvarchar(max),@FixtureStatus varchar(24)='NOT_EXECUTED';
SELECT @UpperId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END),
 @LowerId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END) FROM master.sys.databases;
CREATE TABLE #ExampleHintsSchema
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryHintId] bigint NULL,[QueryId] bigint NULL,[ReplicaGroupId] bigint NULL,[QueryHash] binary(8) NULL,
 [QueryHintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LastQueryHintFailureReason] int NULL,
 [LastQueryHintFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryHintFailureCount] bigint NULL,
 [Source] int NULL,[SourceDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,
 [EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsCurrent] bit NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleHintsExpected FROM #ExampleHintsSchema;
CREATE TABLE #ExampleHintsNative
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [HintId] bigint NOT NULL,[QueryId] bigint NOT NULL,[ReplicaGroupId] bigint NULL,[QueryHash] binary(8) NULL,
 [HintText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FailureReason] int NULL,
 [FailureDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FailureCount] bigint NULL,
 [Source] int NULL,[SourceDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleHintsOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,[Objects] int NOT NULL);
CREATE TABLE #ExampleHintsEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleHintsPreflight([Dummy] int NULL);
CREATE TABLE #ExampleHintsCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,
 [OnlyErrors] bit NULL,[QueryId] bigint NULL,[Mode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Invalid] bit NOT NULL);
INSERT #ExampleHintsCases VALUES
 (0,0,@MissingScope,NULL,NULL,4000,0,NULL,'TABLE',0),(1,0,@MissingScope,NULL,0,4000,0,NULL,'TABLE',0),
 (2,0,@MissingScope,NULL,1,4000,0,NULL,'TABLE',0),(3,0,@MissingScope,NULL,2,4000,0,NULL,'TABLE',0),
 (4,0,@MissingScope,NULL,-1,4000,0,NULL,'TABLE',1),(5,0,@MissingScope,NULL,1,-1,0,NULL,'TABLE',1),
 (6,0,@MissingScope,NULL,1,5,0,NULL,'TABLE',0),(7,0,N'[ExampleInvalid',NULL,1,4000,0,NULL,'TABLE',1),
 (8,0,@MissingScope,NULL,1,NULL,NULL,NULL,'TABLE',0),(9,0,@MissingScope,NULL,1,0,1,NULL,'TABLE',0),
 (10,0,@MissingScope,NULL,2147483647,5,0,NULL,'TABLE',0);
IF @Major>=16 AND @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleHintsOptions SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,query_capture_mode,
    (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleHintOneÄ🔬'',N''ExampleHintTwoÄ🔬'')) FROM sys.database_query_store_options;
   INSERT #ExampleHintsNative SELECT DB_ID(),DB_NAME(),h.query_hint_id,h.query_id,h.replica_group_id,q.query_hash,h.query_hint_text,
    h.last_query_hint_failure_reason,h.last_query_hint_failure_reason_desc,h.query_hint_failure_count,h.source,h.source_desc,qt.query_sql_text
   FROM sys.query_store_query_hints h LEFT JOIN sys.query_store_query q ON q.query_id=h.query_id LEFT JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id;';
  EXEC sys.sp_executesql @Sql;SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleHintsOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleHintsOptions WHERE ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR Objects<>2)
  AND (SELECT COUNT(*) FROM #ExampleHintsNative)=4
  AND NOT EXISTS(SELECT DatabaseId FROM #ExampleHintsNative GROUP BY DatabaseId HAVING COUNT(*)<>2 OR COUNT(DISTINCT QueryId)<>2)
  AND NOT EXISTS(SELECT 1 FROM #ExampleHintsNative WHERE FailureReason IS NULL OR FailureReason<>0 OR FailureCount IS NULL OR FailureCount<>0 OR SqlText IS NULL OR HintText IS NULL)
  AND (SELECT COUNT(*) FROM (SELECT HintId FROM #ExampleHintsNative GROUP BY HintId HAVING COUNT(DISTINCT DatabaseId)=2) t)=2
 BEGIN
  SELECT @UpperLevel=[Level] FROM #ExampleHintsOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleHintsOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel THROW 57603,N'HINTS_SOURCE_LEVELS',1;
  SET @Both=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);SET @FixtureStatus='PENDING';
  DECLARE @OneQuery bigint=(SELECT MIN(QueryId) FROM #ExampleHintsNative WHERE DatabaseId=@UpperId);
  INSERT #ExampleHintsCases VALUES
   (20,1,@Both,NULL,NULL,4000,0,NULL,'TABLE',0),(21,1,@Both,NULL,0,4000,0,NULL,'TABLE',0),
   (22,1,@Both,NULL,1,4000,0,NULL,'TABLE',0),(23,1,@Both,NULL,2,4000,0,NULL,'TABLE',0),
   (24,1,@Both,NULL,2,5,0,NULL,'TABLE',0),(25,1,QUOTENAME(@UpperName),NULL,0,0,0,NULL,'TABLE',0),
   (26,1,QUOTENAME(@LowerName),NULL,0,NULL,0,NULL,'TABLE',0),(27,1,NULL,N'like:'+@UpperName,0,4000,0,NULL,'TABLE',0),
   (28,1,@Both,NULL,1,4000,1,NULL,'TABLE',0),(29,1,@Both,NULL,1,4000,NULL,NULL,'TABLE',0),
   (30,1,QUOTENAME(@UpperName),NULL,0,4000,0,@OneQuery,'TABLE',0),(31,1,@Both,NULL,0,4000,0,@OneQuery,'TABLE',0),
   (32,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,1,4000,0,NULL,'TABLE',0),
   (33,1,N'[EXAMPLEHintÄ🔬]',NULL,1,4000,0,NULL,'TABLE',0),
   (34,1,@Both,NULL,1,1,0,NULL,'TABLE',0);
 END;
END;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@OnlyErrors bit,@QueryId bigint,@Mode varchar(16),@Invalid bit;
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@Count bigint,@ExpectedRows bigint,@BadRank bigint;
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases174] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleHintsCases ORDER BY CaseNumber;
 OPEN [Cases174];FETCH NEXT FROM [Cases174] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@OnlyErrors,@QueryId,@Mode,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleHintsExport([Dummy] int NULL);
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
   @QueryId=@QueryId,@NurMitFehler=@OnlyErrors,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,@ResultSetArt=@Mode,
   @ResultTablesJson=N'{"queryHints":"#ExampleHintsExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57604,N'HINTS_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 57605,N'HINTS_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'queryHints',4),(N'warnings',4)) t(k,v))
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>7 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) t(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1) OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'hasMoreRows' AND [type]<>3))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreHints' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
    THROW 57606,N'HINTS_META',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 57607,N'HINTS_CAPTURE_TIME',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHintsExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHintsSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHintsSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHintsExport'))
    THROW 57608,N'HINTS_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleHintsExport FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleHintsExport);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  IF @Rows<>TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queryHints') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>22)
    THROW 57609,N'HINTS_JSON_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryHints') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryHints') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 57610,N'HINTS_TABLE_JSON',1;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 AND NOT(@Case=7 AND @Major<16) THEN N'INVALID_PARAMETER' WHEN @Major<16 THEN N'UNAVAILABLE_VERSION' ELSE N'AVAILABLE' END OR JSON_QUERY(@Json,N'$.warnings')<>N'[]'
    THROW 57611,N'HINTS_STATUS_WARNINGS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false' THROW 57612,N'HINTS_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleHintsExpected;
   INSERT #ExampleHintsExpected SELECT n.DatabaseId,n.DatabaseName,n.HintId,n.QueryId,n.ReplicaGroupId,n.QueryHash,n.HintText,n.FailureReason,n.FailureDescription,n.FailureCount,n.Source,n.SourceDescription,
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN n.SqlText ELSE LEFT(n.SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    'QUERY_STORE',N'sys.query_store_query_hints|sys.query_store_query_text',@At,'DATABASE_QUERY_HINT',1,
    CASE WHEN n.SqlText IS NULL THEN NULL ELSE CONVERT(bigint,LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,CONVERT(bigint,DATALENGTH(n.SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    N'Aktueller gespeicherter Query-Store-Hintstatus; keine Aussage über die Wirksamkeit jeder zukünftigen Ausführung.'
   FROM #ExampleHintsNative n WHERE (@Names IS NULL OR @Names=@Both OR @Names=QUOTENAME(n.DatabaseName) OR (@Case=32 AND n.DatabaseId=@UpperId))
    AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
    AND (@QueryId IS NULL OR n.QueryId=@QueryId) AND (@OnlyErrors=0 OR n.FailureCount>0 OR n.FailureReason<>0);
   SELECT @Count=COUNT_BIG(*) FROM #ExampleHintsExpected;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @Count>@Max THEN @Max ELSE @Count END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max>0 AND @Count>@Max THEN N'true' ELSE N'false' END THROW 57613,N'HINTS_NATIVE_COUNTS',1;
   SET @Sql=N'IF EXISTS(SELECT 1 FROM #ExampleHintsExport a WHERE NOT EXISTS(SELECT 1 FROM #ExampleHintsExpected e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.QueryHintId=a.QueryHintId))
    OR EXISTS(SELECT QueryStoreDatabaseId,QueryHintId FROM #ExampleHintsExport GROUP BY QueryStoreDatabaseId,QueryHintId HAVING COUNT(*)<>1) THROW 57614,N''HINTS_NATIVE_KEYS'',1;
    ;WITH r AS(SELECT *,DENSE_RANK() OVER(ORDER BY CASE WHEN LastQueryHintFailureReason<>0 THEN 0 ELSE 1 END,QueryHintFailureCount DESC,QueryHintId) AS NativeRank FROM #ExampleHintsExpected)
    SELECT @bad=COUNT_BIG(*) FROM r e JOIN r a ON e.NativeRank<a.NativeRank
     WHERE EXISTS(SELECT 1 FROM #ExampleHintsExport x WHERE x.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND x.QueryHintId=a.QueryHintId)
      AND NOT EXISTS(SELECT 1 FROM #ExampleHintsExport x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.QueryHintId=e.QueryHintId);
    DELETE e FROM #ExampleHintsExpected e WHERE NOT EXISTS(SELECT 1 FROM #ExampleHintsExport a WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.QueryHintId=e.QueryHintId);';
   SET @BadRank=0;EXEC sys.sp_executesql @Sql,N'@bad bigint OUTPUT',@BadRank OUTPUT;
   IF @BadRank<>0 THROW 57615,N'HINTS_GLOBAL_RANK',1;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleHintsExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryHints') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queryHints') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
     THROW 57616,N'HINTS_NATIVE_FULL_FIELDS',1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleHintsExport;
  FETCH NEXT FROM [Cases174] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@OnlyErrors,@QueryId,@Mode,@Invalid;
 END;
 CLOSE [Cases174];DEALLOCATE [Cases174];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>15 THROW 57617,N'HINTS_NATIVE_CASES',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queryHints'))<>CASE WHEN @Max=0 THEN 4 ELSE @Max END
    OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max=0 THEN N'false' ELSE N'true' END
     THROW 57618,N'HINTS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @DirectConsoleCases+=1;SET @Direct+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleHintsEmptyConsole;SET @Max=CASE @Empty WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleHintsEmptyConsole EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=@MissingScope,@HighImpactConfirmed=1,@MaxZeilen=@Max,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleHintsEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleHintsEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.queryHints')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 57619,N'HINTS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'UNSUPPORTED' END;SET @Max=CASE WHEN @Consumer<2 THEN -1 ELSE 1 END;SET @Json=N'ExamplePreviousJson';
  EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@Max,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.queryHints')<>N'[]'
   THROW 57620,N'HINTS_INVALID_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleHintsPreflight"}' WHEN 2 THEN N'{"queryHints":"#ExampleMissingTarget174"}'
   WHEN 3 THEN N'{"queryHints":"ExamplePermanent"}' WHEN 4 THEN N'{"queryHints":"#ExampleHintsPreflight","unknown":"#ExampleHintsPreflight"}' ELSE N'{"queryHints":"#ExampleHintsPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC [monitor].[USP_QueryStoreHints] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleHintsPreflight'))<>1 THROW 57621,N'HINTS_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>11 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3 THROW 57622,N'HINTS_CASE_COUNTS',1;
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
