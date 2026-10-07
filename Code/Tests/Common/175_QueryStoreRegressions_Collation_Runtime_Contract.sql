USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
P3: Prüft den gemeinsamen 25-Feld-Regressionsexport mit sieben Textcollations.
Allgemeine Fälle verwenden einen nachweislich fehlenden Datenbanknamen.
Der positive Block liest zwei extern vorbereitete eigene Unicode-Datenbanken
mit READ_ONLY Query Store und zwei getrennten Ein-Minuten-Intervallen. Fenster,
Queryidentitäten und EXECUTIONS-Sollwerte stammen aus den nativen Katalogen. Ohne passende
Fixture bleibt dieser Block NOT_EXECUTED; allgemeine Verträge laufen weiter.
Der Test erstellt oder verändert keine Fixture, führt keine Fixture-Procedures
aus und verändert keine Datenbankoptionen. Gleiche Rangwerte dürfen zwischen
Aufrufen unterschiedliche Auswahlen ergeben. Positive RAW-/CONSOLE-Vollzeilen
benötigen zusätzlichen Clientcapture. Exakte Cross-DB-Referenzlisten sind nicht Bestandteil
dieses positiven Blocks; Common193 prüft ihren gemeinsamen Vertrag.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 57700,N'REGRESSIONS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 57701,N'REGRESSIONS_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0;
DECLARE @UpperName nvarchar(128)=N'ExampleRegressionÄ🔬',@LowerName nvarchar(128)=N'exampleRegressionÄ🔬',
 @MissingName nvarchar(128)=N'ExampleMissingRegressionÄ🔬',@MissingScope nvarchar(258),@Both nvarchar(max);
SET @MissingScope=QUOTENAME(@MissingName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,N'EXAMPLERegressionÄ🔬'))
 THROW 57702,N'REGRESSIONS_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
SELECT @UpperId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END),
 @LowerId=MAX(CASE WHEN name COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN database_id END) FROM master.sys.databases;
CREATE TABLE #ExampleRegressionsSchema
([QueryStoreDatabaseId] int NULL,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NULL,[QueryHash] binary(8) NULL,[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BaselineExecutions] bigint NULL,[ComparisonExecutions] bigint NULL,[BaselinePlanCount] bigint NULL,[ComparisonPlanCount] bigint NULL,
 [BaselineValue] decimal(38,3) NULL,[ComparisonValue] decimal(38,3) NULL,[AbsoluteChange] decimal(38,3) NULL,[RegressionPercent] decimal(38,3) NULL,
 [LastExecutionTimeUtc] datetimeoffset NULL,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,
 [QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleRegressionsExpected FROM #ExampleRegressionsSchema;
CREATE TABLE #ExampleRegressionsNative
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[QueryHash] binary(8) NULL,[ObjectId] bigint NOT NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PlanId] bigint NOT NULL,
 [IntervalStart] datetimeoffset NOT NULL,[IntervalEnd] datetimeoffset NOT NULL,[LastExecution] datetimeoffset NOT NULL,
 [Executions] bigint NOT NULL,[ReferencesUpper] bit NOT NULL);
CREATE TABLE #ExampleRegressionsOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,
 [IntervalMinutes] int NOT NULL,[Objects] int NOT NULL,[UserRows] bigint NULL);
CREATE TABLE #ExampleRegressionsEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRegressionsPreflight([Dummy] int NULL);
DECLARE @Clock datetime2(7)=SYSUTCDATETIME(),@BFrom datetime2(7),@BTo datetime2(7),@CFrom datetime2(7),@CTo datetime2(7);
DECLARE @ReferenceName nvarchar(258)=QUOTENAME(@UpperName);
SET @BFrom=DATEADD(HOUR,-2,@Clock);SET @BTo=DATEADD(HOUR,-1,@Clock);SET @CFrom=@BTo;SET @CTo=@Clock;
IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleRegressionsOptions SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,query_capture_mode,interval_length_minutes,
    (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleRegressionOneÄ🔬'',N''ExampleRegressionTwoÄ🔬'')),
    (SELECT SUM(row_count) FROM sys.dm_db_partition_stats WHERE object_id=OBJECT_ID(N''dbo.ExampleRegressionRowsÄ🔬'') AND index_id IN(0,1)) FROM sys.database_query_store_options;
   INSERT #ExampleRegressionsNative SELECT DB_ID(),DB_NAME(),q.query_id,q.query_hash,o.object_id,QUOTENAME(s.name)+N''.''+QUOTENAME(o.name),qt.query_sql_text,p.plan_id,
    i.start_time,i.end_time,rs.last_execution_time,rs.count_executions,CONVERT(bit,px.PlanXml.exist(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database=sql:variable("@ReferenceName")]''))
   FROM sys.query_store_runtime_stats rs JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=rs.runtime_stats_interval_id
    JOIN sys.query_store_plan p ON p.plan_id=rs.plan_id JOIN sys.query_store_query q ON q.query_id=p.query_id
    JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id JOIN sys.objects o ON o.object_id=q.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id
    CROSS APPLY(SELECT TRY_CONVERT(xml,p.query_plan) PlanXml) px
   WHERE s.name=N''dbo'' AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleRegressionOneÄ🔬'',N''ExampleRegressionTwoÄ🔬'') AND rs.count_executions>0;';
  EXEC sys.sp_executesql @Sql,N'@ReferenceName nvarchar(258)',@ReferenceName=@ReferenceName;
  SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleRegressionsOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleRegressionsOptions WHERE ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR IntervalMinutes<>1 OR Objects<>2 OR UserRows IS NULL OR UserRows<>4)
  AND (SELECT COUNT(*) FROM (SELECT DatabaseId,QueryId FROM #ExampleRegressionsNative GROUP BY DatabaseId,QueryId) q)=4
  AND NOT EXISTS(SELECT DatabaseId FROM #ExampleRegressionsNative GROUP BY DatabaseId HAVING COUNT(DISTINCT QueryId)<>2 OR COUNT(DISTINCT ObjectId)<>2)
  AND (SELECT COUNT(*) FROM (SELECT IntervalStart,IntervalEnd FROM #ExampleRegressionsNative GROUP BY IntervalStart,IntervalEnd) i)=2
 BEGIN
  SELECT @BFrom=CONVERT(datetime2(7),MIN(IntervalStart)),@CTo=CONVERT(datetime2(7),MAX(IntervalEnd)) FROM #ExampleRegressionsNative;
  SELECT @BTo=CONVERT(datetime2(7),IntervalEnd) FROM #ExampleRegressionsNative WHERE CONVERT(datetime2(7),IntervalStart)=@BFrom;
  SELECT @CFrom=CONVERT(datetime2(7),IntervalStart) FROM #ExampleRegressionsNative WHERE CONVERT(datetime2(7),IntervalEnd)=@CTo;
  IF @BTo<>@CFrom OR DATEDIFF_BIG(SECOND,@BFrom,@BTo)<>60 OR DATEDIFF_BIG(SECOND,@CFrom,@CTo)<>60
   OR EXISTS(SELECT DatabaseId,QueryId FROM #ExampleRegressionsNative GROUP BY DatabaseId,QueryId HAVING COUNT(DISTINCT IntervalStart)<>2 OR COUNT(DISTINCT PlanId)<>1)
   OR EXISTS(SELECT 1 FROM #ExampleRegressionsNative WHERE DATEPART(TZOFFSET,IntervalStart)<>0 OR DATEPART(TZOFFSET,IntervalEnd)<>0)
   THROW 57703,N'REGRESSIONS_NATIVE_INTERVALS',1;
  IF EXISTS(SELECT DatabaseId,QueryId,ObjectName,IntervalStart FROM #ExampleRegressionsNative GROUP BY DatabaseId,QueryId,ObjectName,IntervalStart
   HAVING SUM(Executions)<>CASE WHEN CONVERT(datetime2(7),IntervalStart)=@BFrom THEN 2 WHEN ObjectName=N'[dbo].[ExampleRegressionOneÄ🔬]' THEN 8 ELSE 4 END)
   OR EXISTS(SELECT 1 FROM #ExampleRegressionsNative WHERE ReferencesUpper<>CASE WHEN DatabaseId=@UpperId THEN 1 ELSE 0 END)
   THROW 57704,N'REGRESSIONS_NATIVE_FIXTURE_COUNTS',1;
  SELECT @UpperLevel=[Level] FROM #ExampleRegressionsOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleRegressionsOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel THROW 57705,N'REGRESSIONS_SOURCE_LEVELS',1;
  SET @Both=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);SET @FixtureStatus='PENDING';
 END;
END;
CREATE TABLE #ExampleRegressionsCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,
 [MinExec] bigint NULL,[MinPct] decimal(9,2) NULL,[QueryId] bigint NULL,[QueryHash] binary(8) NULL,
 [RefPattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Invalid] bit NOT NULL);
INSERT #ExampleRegressionsCases VALUES
 (0,0,@MissingScope,NULL,NULL,4000,1,20,NULL,NULL,NULL,0),(1,0,@MissingScope,NULL,0,4000,1,20,NULL,NULL,NULL,0),
 (2,0,@MissingScope,NULL,1,4000,1,20,NULL,NULL,NULL,0),(3,0,@MissingScope,NULL,2,4000,1,20,NULL,NULL,NULL,0),
 (4,0,@MissingScope,NULL,-1,4000,1,20,NULL,NULL,NULL,1),(5,0,@MissingScope,NULL,1,-1,1,20,NULL,NULL,NULL,1),
 (6,0,N'[ExampleInvalid',NULL,1,4000,1,20,NULL,NULL,NULL,1),(7,0,@MissingScope,NULL,1,4000,0,20,NULL,NULL,NULL,1),
 (8,0,@MissingScope,NULL,1,4000,1,-1,NULL,NULL,NULL,1),(9,0,@MissingScope,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,0),
 (10,0,@MissingScope,NULL,2147483647,0,1,20,NULL,NULL,NULL,0),(11,0,@MissingScope,NULL,1,5,1,20,NULL,NULL,NULL,1),
 (12,0,@MissingScope,NULL,1,4000,1,20,NULL,NULL,NULL,1),(13,0,@MissingScope,NULL,1,4000,1,20,NULL,NULL,NULL,1);
IF @FixtureStatus='PENDING'
BEGIN
 DECLARE @OneQuery bigint,@OneHash binary(8);
 SELECT @OneQuery=QueryId,@OneHash=QueryHash FROM #ExampleRegressionsNative WHERE DatabaseId=@UpperId AND ObjectName=N'[dbo].[ExampleRegressionOneÄ🔬]';
 INSERT #ExampleRegressionsCases VALUES
 (20,1,@Both,NULL,NULL,4000,1,20,NULL,NULL,NULL,0),(21,1,@Both,NULL,0,4000,1,20,NULL,NULL,NULL,0),
 (22,1,@Both,NULL,1,4000,1,20,NULL,NULL,NULL,0),(23,1,@Both,NULL,2,4000,1,20,NULL,NULL,NULL,0),
 (24,1,@Both,NULL,2,5,1,20,NULL,NULL,NULL,0),(25,1,QUOTENAME(@UpperName),NULL,0,0,1,20,NULL,NULL,NULL,0),
 (26,1,QUOTENAME(@LowerName),NULL,0,NULL,1,20,NULL,NULL,NULL,0),(27,1,NULL,N'like:'+@UpperName,0,4000,1,20,NULL,NULL,NULL,0),
 (28,1,@Both,NULL,0,4000,3,20,NULL,NULL,NULL,0),(29,1,@Both,NULL,0,4000,NULL,20,NULL,NULL,NULL,0),
 (30,1,@Both,NULL,0,4000,1,100,NULL,NULL,NULL,0),(31,1,@Both,NULL,0,4000,1,100.01,NULL,NULL,NULL,0),
 (32,1,@Both,NULL,0,4000,1,300,NULL,NULL,NULL,0),(33,1,@Both,NULL,0,4000,1,300.01,NULL,NULL,NULL,0),
 (34,1,@Both,NULL,0,4000,1,NULL,NULL,NULL,NULL,0),(35,1,QUOTENAME(@UpperName),NULL,0,4000,1,20,@OneQuery,NULL,NULL,0),
 (36,1,@Both,NULL,0,4000,1,20,NULL,@OneHash,NULL,0),(37,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,1,4000,1,20,NULL,NULL,NULL,0),
 (38,1,N'[EXAMPLERegressionÄ🔬]',NULL,1,4000,1,20,NULL,NULL,NULL,0),(39,1,@Both,NULL,0,4000,1,20,NULL,NULL,N'like:'+@UpperName,0);
END;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@MinExec bigint,@MinPct decimal(9,2),@QueryId bigint,@QueryHash binary(8),@RefPattern nvarchar(4000),@Invalid bit;
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@Count bigint,@ExpectedRows bigint,@BadRank bigint;
DECLARE @Metric varchar(32),@Analyse varchar(16),@CaseBTo datetime2(7);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases175] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleRegressionsCases ORDER BY CaseNumber;
 OPEN [Cases175];FETCH NEXT FROM [Cases175] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@MinExec,@MinPct,@QueryId,@QueryHash,@RefPattern,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleRegressionsExport([Dummy] int NULL);
  SET @Metric=CASE WHEN @Case=11 THEN 'UNSUPPORTED' ELSE 'EXECUTIONS' END;
  SET @Analyse=CASE WHEN @Case=12 THEN 'UNSUPPORTED' ELSE 'TOP' END;
  SET @CaseBTo=CASE WHEN @Case=13 THEN @BFrom ELSE @BTo END;
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
   @QueryId=@QueryId,@QueryHash=@QueryHash,@BaselineVonUtc=@BFrom,@BaselineBisUtc=@CaseBTo,@VergleichVonUtc=@CFrom,@VergleichBisUtc=@CTo,
   @Metrik=@Metric,@AnalyseModus=@Analyse,@MinAusfuehrungenJeFenster=@MinExec,@MinRegressionProzent=@MinPct,@ReferencedDatabaseNamePattern=@RefPattern,
   @MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,@ResultSetArt='TABLE',@ResultTablesJson=N'{"regressions":"#ExampleRegressionsExport"}',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57706,N'REGRESSIONS_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 57707,N'REGRESSIONS_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3 OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'regressions',4),(N'warnings',4)) t(k,v))
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>8 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'metric'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) t(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode',N'metric') AND [type]<>1) OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'hasMoreRows' AND [type]<>3))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreRegressions' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.metric')<>@Metric THROW 57708,N'REGRESSIONS_META',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 57709,N'REGRESSIONS_CAPTURE_TIME',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRegressionsExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRegressionsSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRegressionsSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRegressionsExport'))
    THROW 57710,N'REGRESSIONS_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleRegressionsExport FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleRegressionsExport);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  IF @Rows<>TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.regressions') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>25)
   THROW 57711,N'REGRESSIONS_JSON_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.regressions') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.regressions') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 57712,N'REGRESSIONS_TABLE_JSON',1;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END OR JSON_QUERY(@Json,N'$.warnings')<>N'[]'
   THROW 57713,N'REGRESSIONS_STATUS_WARNINGS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false' THROW 57714,N'REGRESSIONS_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleRegressionsExpected;
   ;WITH Windows AS
   (SELECT n.*,w.WindowCode FROM #ExampleRegressionsNative n CROSS APPLY(VALUES('B',@BFrom,@BTo),('C',@CFrom,@CTo)) w(WindowCode,WindowFrom,WindowTo)
    WHERE n.IntervalEnd>w.WindowFrom AND n.IntervalStart<w.WindowTo
     AND (@Names IS NULL OR @Names=@Both OR @Names=QUOTENAME(n.DatabaseName) OR (@Case=37 AND n.DatabaseId=@UpperId))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@QueryId IS NULL OR n.QueryId=@QueryId) AND (@QueryHash IS NULL OR n.QueryHash=@QueryHash) AND (@RefPattern IS NULL OR n.ReferencesUpper=1)),
   Totals AS
   (SELECT DatabaseId,DatabaseName,QueryId,QueryHash,ObjectId,ObjectName,SqlText,WindowCode,SUM(Executions) Executions,COUNT(DISTINCT PlanId) Plans,MAX(LastExecution) LastExecution
    FROM Windows GROUP BY DatabaseId,DatabaseName,QueryId,QueryHash,ObjectId,ObjectName,SqlText,WindowCode),
   ValuesCompared AS
   (SELECT b.*,c.Executions ComparisonExecutions,c.Plans ComparisonPlans,c.LastExecution ComparisonLastExecution,
     CONVERT(decimal(38,3),CONVERT(float,c.Executions)-CONVERT(float,b.Executions)) AbsoluteChange,
     CONVERT(decimal(38,3),100.0*(CONVERT(float,c.Executions)-CONVERT(float,b.Executions))/NULLIF(ABS(CONVERT(float,b.Executions)),0)) RegressionPercent
    FROM Totals b JOIN Totals c ON c.DatabaseId=b.DatabaseId AND c.QueryId=b.QueryId AND c.WindowCode='C'
    WHERE b.WindowCode='B' AND b.Executions>=@MinExec AND c.Executions>=@MinExec)
   INSERT #ExampleRegressionsExpected SELECT DatabaseId,DatabaseName,QueryId,QueryHash,ObjectId,ObjectName,Executions,ComparisonExecutions,Plans,ComparisonPlans,
    CONVERT(decimal(38,3),Executions),CONVERT(decimal(38,3),ComparisonExecutions),AbsoluteChange,RegressionPercent,ComparisonLastExecution,
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN SqlText ELSE LEFT(SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    'QUERY_STORE',N'sys.query_store_runtime_stats|sys.query_store_plan|sys.query_store_query_text',@At,'DATABASE_QUERY_WINDOW_COMPARISON',1,
    CONVERT(bigint,LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1),CONVERT(bigint,DATALENGTH(SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    N'Zwei Query-Store-Zeitfenster mit aggregierten Messwerten; keine Kausalitäts- oder aktuelle Einzelausführungsaussage.'
    FROM ValuesCompared WHERE RegressionPercent>=@MinPct;
   SELECT @Count=COUNT_BIG(*) FROM #ExampleRegressionsExpected;
   IF (@Case IN(20,21,30) AND @Count<>4) OR (@Case IN(31,32) AND @Count<>2) OR (@Case IN(28,29,33,34,38) AND @Count<>0)
    THROW 57715,N'REGRESSIONS_NATIVE_FILTER_COUNTS',1;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @Count>@Max THEN @Max ELSE @Count END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max>0 AND @Count>@Max THEN N'true' ELSE N'false' END
    THROW 57716,N'REGRESSIONS_NATIVE_COUNTS',1;
   SET @Sql=N'IF EXISTS(SELECT 1 FROM #ExampleRegressionsExport a WHERE NOT EXISTS(SELECT 1 FROM #ExampleRegressionsExpected e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.QueryId=a.QueryId))
    OR EXISTS(SELECT QueryStoreDatabaseId,QueryId FROM #ExampleRegressionsExport GROUP BY QueryStoreDatabaseId,QueryId HAVING COUNT(*)<>1) THROW 57717,N''REGRESSIONS_NATIVE_KEYS'',1;
    ;WITH r AS(SELECT *,DENSE_RANK() OVER(ORDER BY RegressionPercent DESC,AbsoluteChange DESC) NativeRank FROM #ExampleRegressionsExpected)
    SELECT @bad=COUNT_BIG(*) FROM r e JOIN r a ON e.NativeRank<a.NativeRank
     WHERE EXISTS(SELECT 1 FROM #ExampleRegressionsExport x WHERE x.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND x.QueryId=a.QueryId)
      AND NOT EXISTS(SELECT 1 FROM #ExampleRegressionsExport x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.QueryId=e.QueryId);
    DELETE e FROM #ExampleRegressionsExpected e WHERE NOT EXISTS(SELECT 1 FROM #ExampleRegressionsExport a WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.QueryId=e.QueryId);';
   SET @BadRank=0;EXEC sys.sp_executesql @Sql,N'@bad bigint OUTPUT',@BadRank OUTPUT;
   IF @BadRank<>0 THROW 57718,N'REGRESSIONS_GLOBAL_RANK',1;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleRegressionsExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.regressions') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.regressions') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
     THROW 57719,N'REGRESSIONS_NATIVE_FULL_FIELDS',1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleRegressionsExport;
  FETCH NEXT FROM [Cases175] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@MinExec,@MinPct,@QueryId,@QueryHash,@RefPattern,@Invalid;
 END;
 CLOSE [Cases175];DEALLOCATE [Cases175];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>20 THROW 57720,N'REGRESSIONS_NATIVE_CASES',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@BaselineVonUtc=@BFrom,@BaselineBisUtc=@BTo,
    @VergleichVonUtc=@CFrom,@VergleichBisUtc=@CTo,@Metrik='EXECUTIONS',@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.regressions'))<>CASE WHEN @Max=0 THEN 4 ELSE @Max END OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE'
    OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @Max=0 THEN N'false' ELSE N'true' END OR @@LOCK_TIMEOUT<>137
     THROW 57721,N'REGRESSIONS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @DirectConsoleCases+=1;SET @Direct+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleRegressionsEmptyConsole;SET @Max=CASE @Empty WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleRegressionsEmptyConsole EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=@MissingScope,@HighImpactConfirmed=1,@MaxZeilen=@Max,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleRegressionsEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleRegressionsEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.regressions')<>N'[]' OR @@LOCK_TIMEOUT<>137 THROW 57722,N'REGRESSIONS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0,@Mode varchar(16);
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' ELSE 'UNSUPPORTED' END;
  SET @Max=CASE WHEN @Consumer=1 THEN -1 ELSE 1 END;SET @TextLimit=CASE WHEN @Consumer=0 THEN -1 ELSE 4000 END;
  EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,
   @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.regressions')<>N'[]'
   OR @@LOCK_TIMEOUT<>137 THROW 57723,N'REGRESSIONS_INVALID_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleRegressionsPreflight"}' WHEN 2 THEN N'{"regressions":"#ExampleMissingTarget175"}'
   WHEN 3 THEN N'{"regressions":"ExamplePermanent"}' WHEN 4 THEN N'{"regressions":"#ExampleRegressionsPreflight","unknown":"#ExampleRegressionsPreflight"}' ELSE N'{"regressions":"#ExampleRegressionsPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC [monitor].[USP_QueryStoreRegressions] @QueryStoreDatabaseNames=@MissingScope,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRegressionsPreflight'))<>1 THROW 57724,N'REGRESSIONS_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>14 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>3 THROW 57725,N'REGRESSIONS_CASE_COUNTS',1;
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
