USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
P3: Prüft den bestehenden 32-Feld-Vertrag und die gemeinsame globale Ausgabe.
Der allgemeine Block benötigt keine Fixture. Absichtlich leere Fälle wählen
einen nachweislich fehlenden Namen; N'' bedeutet keine Einschränkung. Der positive Block liest nur zwei
extern vorbereitete eigene Unicode-Datenbanken mit eingefrorenem Query Store.
Ohne diese Fixture meldet nur dieser Block NOT_EXECUTED. Keine DDL, Ausführung,
Planbindung oder Query-Store-Konfigurationsänderung erfolgt durch diesen Test.
RAW- und positive CONSOLE-Zeilen benötigen zusätzlich unabhängigen Clientcapture.
Fehlerfreies Forcing belegt keine positiven Forcingfehler oder Berechtigungsfälle.
Fehlende Auswahl bleibt im vorhandenen Vertrag ohne zusätzliche Warning; die
entsprechenden Fälle prüfen diese Grenze und führen keinen neuen Status ein.
Der positive Referenzfall nutzt ein LIKE-Pattern ohne Platzhalter. Eine positive
datenbankübergreifende exakte Referenzliste wird hier nicht nachgewiesen
(bestehender Quellhelper-Aufruf kann Error 208 liefern).
*/
SET NOCOUNT ON;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 57400,N'FORCED_PLANS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 57401,N'FORCED_PLANS_FRAMEWORK_COLLATION',1;
DECLARE @UpperName nvarchar(128)=N'ExampleForcedPlanÄ🔬',@LowerName nvarchar(128)=N'exampleForcedPlanÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingForcedPlanÄ🔬';
DECLARE @EmptyNames nvarchar(258)=QUOTENAME(@MissingName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 57423,N'FORCED_PLANS_MISSING_IDENTIFIER',1;
DECLARE @UpperId int,@LowerId int,@UpperLevel int,@LowerLevel int,@FixtureStatus varchar(24)='NOT_EXECUTED';
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
SELECT @UpperId=MAX(CASE WHEN [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN [database_id] END),
       @LowerId=MAX(CASE WHEN [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN [database_id] END)
FROM [master].[sys].[databases];

/* Unabhängige öffentliche Felddefinition, relative Ordinale und Nullability. */
CREATE TABLE #ExampleForcedPlansSchema
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
SELECT TOP(0) * INTO #ExampleForcedPlansExpected FROM #ExampleForcedPlansSchema;
CREATE TABLE #ExampleForcedPlansNative
(
 [DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [QueryId] bigint NOT NULL,[PlanId] bigint NOT NULL,[QueryHash] binary(8) NULL,[PlanHash] binary(8) NULL,
 [ObjectId] int NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Forced] bit NULL,[ForcingType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [FailureCount] bigint NULL,[FailureReason] int NULL,[FailureDescription] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Compiles] bigint NULL,[CompileTime] datetimeoffset(7) NULL,[ExecutionTime] datetimeoffset(7) NULL,
 [EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CompatibilityLevel] smallint NULL,
 [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleForcedPlansOptions
([DatabaseId] int NOT NULL,[Level] int NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL,
 [FixtureObjectCount] int NOT NULL,[UserTableCount] int NOT NULL);
CREATE TABLE #ExampleForcedPlansEmptyConsole
([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleForcedPlansPreflight([Dummy] int NULL);
CREATE TABLE #ExampleForcedPlansCases
([CaseNumber] int NOT NULL,[IsNative] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[TextLimit] int NULL,
 [OnlyErrors] bit NULL,[PlanXml] bit NULL,[QueryId] bigint NULL,[ReferenceNames] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ReferencePattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExpectedInvalid] bit NOT NULL);
INSERT #ExampleForcedPlansCases VALUES
 (0,0,@EmptyNames,NULL,NULL,4000,0,0,NULL,NULL,NULL,0),
 (1,0,@EmptyNames,NULL,0,4000,0,0,NULL,NULL,NULL,0),
 (2,0,@EmptyNames,NULL,1,4000,0,0,NULL,NULL,NULL,0),
 (3,0,@EmptyNames,NULL,-1,4000,0,0,NULL,NULL,NULL,1),
 (4,0,@EmptyNames,NULL,1,-1,0,0,NULL,NULL,NULL,1),
 (5,0,N'[ExampleInvalid',NULL,1,4000,0,0,NULL,NULL,NULL,1),
 (6,0,@EmptyNames,NULL,1,4000,0,0,NULL,N'[ExampleInvalid',NULL,1),
 (7,0,@EmptyNames,NULL,1,NULL,0,0,NULL,NULL,NULL,0),
 (8,0,@EmptyNames,NULL,1,0,NULL,0,NULL,NULL,NULL,0),
 (9,0,@EmptyNames,NULL,1,4000,1,0,NULL,NULL,NULL,0),
 (10,0,@EmptyNames,NULL,1,4000,0,1,NULL,NULL,NULL,0),
 (11,0,QUOTENAME(@MissingName),NULL,1,4000,0,0,NULL,NULL,NULL,0);

DECLARE @Sql nvarchar(max),@Db nvarchar(128),@DbIndex int=0;
IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId
BEGIN
 WHILE @DbIndex<2
 BEGIN
  SET @Db=CASE @DbIndex WHEN 0 THEN @UpperName ELSE @LowerName END;
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';
   INSERT #ExampleForcedPlansOptions
   SELECT DB_ID(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),actual_state,desired_state,
     (SELECT COUNT(*) FROM sys.objects WHERE type=''P'' AND schema_id=SCHEMA_ID(N''dbo'') AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleForcedPlanOneÄ🔬'',N''ExampleForcedPlanTwoÄ🔬'')),
     (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)
   FROM sys.database_query_store_options;
   INSERT #ExampleForcedPlansNative
   SELECT DB_ID(),DB_NAME(),q.query_id,p.plan_id,q.query_hash,p.query_plan_hash,q.object_id,
    CASE WHEN q.object_id>0 THEN QUOTENAME(s.name)+N''.''+QUOTENAME(o.name) END,p.is_forced_plan,p.plan_forcing_type_desc,
    p.force_failure_count,p.last_force_failure_reason,p.last_force_failure_reason_desc,p.count_compiles,
    p.last_compile_start_time,p.last_execution_time,p.engine_version,p.compatibility_level,qt.query_sql_text,p.query_plan
   FROM sys.query_store_plan p JOIN sys.query_store_query q ON q.query_id=p.query_id
   JOIN sys.query_store_query_text qt ON qt.query_text_id=q.query_text_id
   LEFT JOIN sys.objects o ON o.object_id=q.object_id LEFT JOIN sys.schemas s ON s.schema_id=o.schema_id
   WHERE p.is_forced_plan=1;';
  EXEC [sys].[sp_executesql] @Sql;
  SET @DbIndex+=1;
 END;
 IF (SELECT COUNT(*) FROM #ExampleForcedPlansOptions)=2
    AND NOT EXISTS(SELECT 1 FROM #ExampleForcedPlansOptions WHERE ActualState<>1 OR DesiredState<>1 OR FixtureObjectCount<>2 OR UserTableCount<>1)
    AND (SELECT COUNT(*) FROM #ExampleForcedPlansNative)=4
    AND NOT EXISTS(SELECT 1 FROM #ExampleForcedPlansNative WHERE Forced IS NULL OR Forced<>1 OR FailureCount IS NULL OR FailureCount<>0 OR FailureReason IS NULL OR FailureReason<>0 OR ObjectId IS NULL OR ObjectId=0 OR PlanText IS NULL)
 BEGIN
  SELECT @UpperLevel=[Level] FROM #ExampleForcedPlansOptions WHERE DatabaseId=@UpperId;
  SELECT @LowerLevel=[Level] FROM #ExampleForcedPlansOptions WHERE DatabaseId=@LowerId;
  IF @UpperLevel<>@FrameworkLevel OR @LowerLevel<>@FrameworkLevel
      THROW 57402,N'FORCED_PLANS_SOURCE_LEVELS',1;
  SET @FixtureStatus='PENDING';
  DECLARE @Both nvarchar(max)=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);
  DECLARE @OneQuery bigint=(SELECT MIN(QueryId) FROM #ExampleForcedPlansNative WHERE DatabaseId=@UpperId);
  INSERT #ExampleForcedPlansCases VALUES
   (20,1,@Both,NULL,NULL,4000,0,0,NULL,NULL,NULL,0),
   (21,1,@Both,NULL,0,4000,0,0,NULL,NULL,NULL,0),
   (22,1,@Both,NULL,1,4000,0,0,NULL,NULL,NULL,0),
   (23,1,@Both,NULL,2,4000,0,0,NULL,NULL,NULL,0),
   (24,1,@Both,NULL,2,5,0,1,NULL,NULL,NULL,0),
   (25,1,QUOTENAME(@UpperName),NULL,0,0,0,0,NULL,NULL,NULL,0),
   (26,1,QUOTENAME(@LowerName),NULL,0,NULL,0,0,NULL,NULL,NULL,0),
   (27,1,NULL,N'like:'+@UpperName,0,4000,0,0,NULL,NULL,NULL,0),
   (28,1,@Both,NULL,1,4000,1,0,NULL,NULL,NULL,0),
   (29,1,@Both,NULL,1,4000,NULL,0,NULL,NULL,NULL,0),
   (30,1,QUOTENAME(@UpperName),NULL,0,4000,0,0,@OneQuery,NULL,NULL,0),
   (31,1,@Both,NULL,2,4000,0,1,NULL,NULL,N'like:'+@UpperName,0),
   (32,1,QUOTENAME(@UpperName)+N'|'+QUOTENAME(@MissingName),NULL,1,4000,0,0,NULL,NULL,NULL,0),
   (33,1,N'[EXAMPLEForcedPlanÄ🔬]',NULL,1,4000,0,0,NULL,NULL,NULL,0);
 END;
END;

DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@TextLimit int,@OnlyErrors bit,@Plan bit,@QueryId bigint,@References nvarchar(max),@ReferencePattern nvarchar(4000),@Invalid bit;
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@Generated datetime2(3),@Before datetime2(3),@After datetime2(3),@Rows bigint,@NativeCount bigint,@ExpectedRows bigint,@HasMore bit;
DECLARE @Columns nvarchar(max)=N'[QueryStoreDatabaseId],[QueryStoreDatabaseName],[QueryId],[PlanId],[QueryHash],[QueryPlanHash],[ObjectId],[ObjectName],[IsForcedPlan],[PlanForcingTypeDesc],[ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc],[CountCompiles],[LastCompileStartTimeUtc],[LastExecutionTimeUtc],[EngineVersion],[CompatibilityLevel],[QuerySqlText],[QueryPlanTextFallback],[SourceType],[SourceObject],[CapturedAtUtc],[EvidenceScope],[QuerySqlTextCharacters],[QuerySqlTextBytes],[QuerySqlTextIsTruncated],[QueryPlanStatus],[QueryPlanCharacters],[QueryPlanBytes],CONVERT(nvarchar(max),[QueryPlan]) AS [QueryPlan],[EvidenceLimit]';
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases172] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleForcedPlansCases ORDER BY CaseNumber;
 OPEN [Cases172];
 FETCH NEXT FROM [Cases172] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@OnlyErrors,@Plan,@QueryId,@References,@ReferencePattern,@Invalid;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleForcedPlansExport([Dummy] int NULL);
  SET @Json=NULL;SET @Before=SYSUTCDATETIME();
  EXEC [monitor].[USP_QueryStoreForcedPlans]
       @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@HighImpactConfirmed=1,
       @ReferencedDatabaseNames=@References,@ReferencedDatabaseNamePattern=@ReferencePattern,@QueryId=@QueryId,@NurMitFehler=@OnlyErrors,@MitPlanXml=@Plan,
       @MaxZeilen=@Max,@MaxSqlTextZeichen=@TextLimit,@ResultSetArt='TABLE',
       @ResultTablesJson=N'{"forcedPlans":"#ExampleForcedPlansExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 57403,N'FORCED_PLANS_CALLER_LOCK_TIMEOUT',1;
  IF ISJSON(@Json)<>1 OR @Json IS NULL THROW 57404,N'FORCED_PLANS_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3
     OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'forcedPlans',4),(N'warnings',4)) e(k,t))
     OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>7
     OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) e(k))
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1) OR ([key] IN(N'schemaVersion',N'returnedRows') AND [type]<>2) OR ([key]=N'hasMoreRows' AND [type]<>3))
     OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND ((@Max IS NULL AND [type]=0) OR (@Max IS NOT NULL AND [type]=2 AND TRY_CONVERT(int,value)=@Max)))
     OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreForcedPlans'
     OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>2
      THROW 57405,N'FORCED_PLANS_JSON_META',1;
  SET @Generated=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @Generated IS NULL OR @Generated<@Before OR @Generated>@After THROW 57406,N'FORCED_PLANS_CAPTURE_TIME',1;
  IF EXISTS
  (
   SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleForcedPlansExport')
   EXCEPT
   SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleForcedPlansSchema')
  ) OR EXISTS
  (
   SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleForcedPlansSchema')
   EXCEPT
   SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleForcedPlansExport')
  ) THROW 57407,N'FORCED_PLANS_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT '+@Columns+N' FROM #ExampleForcedPlansExport ORDER BY CASE WHEN LastForceFailureReason<>0 THEN 0 ELSE 1 END,LastExecutionTimeUtc DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@r=COUNT_BIG(*) FROM #ExampleForcedPlansExport;';
  EXEC [sys].[sp_executesql] @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
       EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.forcedPlans') GROUP BY value COLLATE Latin1_General_100_BIN2)
     OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.forcedPlans') GROUP BY value COLLATE Latin1_General_100_BIN2
       EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
     OR @Rows<>TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows'))
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.forcedPlans') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>32)
      THROW 57408,N'FORCED_PLANS_TABLE_JSON',1;
  IF @Invalid=1 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER' OR @Rows<>0)
      THROW 57409,N'FORCED_PLANS_INVALID_PARAMETER',1;
  IF @Invalid=0 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>'AVAILABLE' OR JSON_QUERY(@Json,N'$.warnings')<>N'[]')
      THROW 57410,N'FORCED_PLANS_AVAILABLE_STATUS',1;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'false' THROW 57411,N'FORCED_PLANS_EMPTY_SCOPE',1;
   SET @CoreCases+=1;
  END;
  ELSE
  BEGIN
   TRUNCATE TABLE #ExampleForcedPlansExpected;
   INSERT #ExampleForcedPlansExpected
   SELECT n.DatabaseId,n.DatabaseName,n.QueryId,n.PlanId,n.QueryHash,n.PlanHash,n.ObjectId,n.ObjectName,n.Forced,n.ForcingType,
    n.FailureCount,n.FailureReason,n.FailureDescription,n.Compiles,n.CompileTime,n.ExecutionTime,n.EngineVersion,n.CompatibilityLevel,
    CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN n.SqlText ELSE LEFT(n.SqlText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) END,
    NULL,'QUERY_STORE',N'sys.query_store_plan|sys.query_store_query_text',@Generated,'DATABASE_QUERY_PLAN',
    CASE WHEN n.SqlText IS NULL THEN NULL ELSE CONVERT(bigint,LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
    CONVERT(bigint,DATALENGTH(n.SqlText)),
    CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN((n.SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@TextLimit THEN 1 ELSE 0 END),
    CASE WHEN @Plan=1 THEN 'AVAILABLE' ELSE 'NOT_REQUESTED' END,
    CASE WHEN @Plan=1 THEN CONVERT(bigint,LEN((n.PlanText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1) END,
    CASE WHEN @Plan=1 THEN CONVERT(bigint,DATALENGTH(n.PlanText)) END,
    CASE WHEN @Plan=1 THEN CONVERT(xml,n.PlanText) END,
    N'Gespeicherter Query-Store-Plan und aggregierte Metadaten; kein aktueller Ausführungsplan.'
   FROM #ExampleForcedPlansNative n
   CROSS APPLY(SELECT CONVERT(xml,n.PlanText) AS PlanXml) px
   WHERE (@Names IS NULL OR EXISTS(SELECT 1 FROM (VALUES(QUOTENAME(@UpperName),@UpperId),(QUOTENAME(@LowerName),@LowerId)) d(Name,Id)
           WHERE d.Id=n.DatabaseId AND (@Names=d.Name OR @Names=@Both OR (@Case=32 AND d.Id=@UpperId))))
     AND (@Pattern IS NULL OR n.DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS)
     AND (@QueryId IS NULL OR n.QueryId=@QueryId)
     AND (@OnlyErrors=0 OR n.FailureCount>0 OR n.FailureReason<>0)
     AND ((@References IS NULL AND @ReferencePattern IS NULL) OR EXISTS
       (SELECT 1 FROM px.PlanXml.nodes('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]') x(n)
        WHERE PARSENAME(x.n.value('@Database','nvarchar(776)'),1) COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS));
   SELECT @NativeCount=COUNT_BIG(*) FROM #ExampleForcedPlansExpected;
   SET @ExpectedRows=CASE WHEN @Max>0 AND @NativeCount>@Max THEN @Max ELSE @NativeCount END;
   SET @HasMore=CASE WHEN @Max>0 AND @NativeCount>@Max THEN 1 ELSE 0 END;
   IF @Rows<>@ExpectedRows OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @HasMore=1 THEN N'true' ELSE N'false' END
       THROW 57412,N'FORCED_PLANS_NATIVE_COUNT',1;
   /* Bei Sortties ist die vorhandene Auswahl nicht eindeutig. Jede ausgegebene
      Identität muss nativ existieren; kein strenger höherer Rang darf fehlen. */
   SET @Sql=N'
    IF EXISTS(SELECT 1 FROM #ExampleForcedPlansExport a WHERE NOT EXISTS
      (SELECT 1 FROM #ExampleForcedPlansExpected e WHERE e.QueryStoreDatabaseId=a.QueryStoreDatabaseId AND e.QueryId=a.QueryId AND e.PlanId=a.PlanId))
      OR EXISTS(SELECT QueryStoreDatabaseId,QueryId,PlanId FROM #ExampleForcedPlansExport GROUP BY QueryStoreDatabaseId,QueryId,PlanId HAVING COUNT(*)<>1)
      THROW 57413,N''FORCED_PLANS_NATIVE_IDENTITIES'',1;
    IF EXISTS(SELECT 1 FROM #ExampleForcedPlansExpected e CROSS JOIN #ExampleForcedPlansExport a
       WHERE NOT EXISTS(SELECT 1 FROM #ExampleForcedPlansExport x WHERE x.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND x.QueryId=e.QueryId AND x.PlanId=e.PlanId)
         AND (CASE WHEN e.LastForceFailureReason<>0 THEN 0 ELSE 1 END<CASE WHEN a.LastForceFailureReason<>0 THEN 0 ELSE 1 END
           OR (CASE WHEN e.LastForceFailureReason<>0 THEN 0 ELSE 1 END=CASE WHEN a.LastForceFailureReason<>0 THEN 0 ELSE 1 END
             AND (e.LastExecutionTimeUtc>a.LastExecutionTimeUtc OR (e.LastExecutionTimeUtc IS NOT NULL AND a.LastExecutionTimeUtc IS NULL)))))
      THROW 57414,N''FORCED_PLANS_GLOBAL_RANK'',1;
    DELETE e FROM #ExampleForcedPlansExpected e WHERE NOT EXISTS(SELECT 1 FROM #ExampleForcedPlansExport a
      WHERE a.QueryStoreDatabaseId=e.QueryStoreDatabaseId AND a.QueryId=e.QueryId AND a.PlanId=e.PlanId);';
   EXEC [sys].[sp_executesql] @Sql;
   DECLARE @ExpectedJson nvarchar(max);
   SET @Sql=N'SELECT @j=(SELECT '+@Columns+N' FROM #ExampleForcedPlansExpected ORDER BY CASE WHEN LastForceFailureReason<>0 THEN 0 ELSE 1 END,LastExecutionTimeUtc DESC FOR JSON PATH,INCLUDE_NULL_VALUES);';
   EXEC [sys].[sp_executesql] @Sql,N'@j nvarchar(max) OUTPUT',@ExpectedJson OUTPUT;
   IF (SELECT COUNT(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')))<>@Rows
      OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
                EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(JSON_QUERY(@Json,N'$.forcedPlans')) GROUP BY value COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(JSON_QUERY(@Json,N'$.forcedPlans')) GROUP BY value COLLATE Latin1_General_100_BIN2
                EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
       THROW 57415,N'FORCED_PLANS_NATIVE_FULL_FIELDS',1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleForcedPlansExport;
  FETCH NEXT FROM [Cases172] INTO @Case,@Native,@Names,@Pattern,@Max,@TextLimit,@OnlyErrors,@Plan,@QueryId,@References,@ReferencePattern,@Invalid;
 END;
 CLOSE [Cases172];DEALLOCATE [Cases172];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>14 THROW 57416,N'FORCED_PLANS_NATIVE_CASES',1;
  /* Ohne INSERT EXEC: Kandidatenprobes können eigene leere Grids liefern. */
  EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@Both,@HighImpactConfirmed=1,@MaxZeilen=1,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.forcedPlans'))<>1 OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>N'true'
      THROW 57417,N'FORCED_PLANS_DIRECT_CONSOLE_JSON',1;
  SET @DirectConsoleCases+=1;
  SET @Names=QUOTENAME(@UpperName);
  EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@Names,@HighImpactConfirmed=1,@MaxZeilen=0,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.forcedPlans'))<>2 THROW 57418,N'FORCED_PLANS_DIRECT_CONSOLE_ONE_DB',1;
  SET @DirectConsoleCases+=1;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @EmptyCase int=0;
 WHILE @EmptyCase<3
 BEGIN
  TRUNCATE TABLE #ExampleForcedPlansEmptyConsole;
  SET @Max=CASE @EmptyCase WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleForcedPlansEmptyConsole
  EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@HighImpactConfirmed=1,@MaxZeilen=@Max,
       @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleForcedPlansEmptyConsole)<>1
     OR EXISTS(SELECT 1 FROM #ExampleForcedPlansEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
     OR JSON_QUERY(@Json,N'$.forcedPlans')<>N'[]' OR @@LOCK_TIMEOUT<>137
      THROW 57419,N'FORCED_PLANS_EMPTY_CONSOLE',1;
  SET @EmptyConsoleCases+=1;SET @EmptyCase+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<3
 BEGIN
  SET @Json=N'ExamplePreviousJson';
  IF @Consumer=0
   EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  ELSE IF @Consumer=1
   EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@MaxZeilen=-1,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  ELSE
   EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@MaxZeilen=1,@ResultSetArt='UNSUPPORTED',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.forcedPlans')<>N'[]'
      THROW 57420,N'FORCED_PLANS_INVALID_CONSUMER',1;
  SET @ConsumerCases+=1;SET @Consumer+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<5
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleForcedPlansPreflight"}'
      WHEN 2 THEN N'{"forcedPlans":"#ExampleMissingTarget172"}' WHEN 3 THEN N'{"forcedPlans":"ExamplePermanent"}'
      ELSE N'{"forcedPlans":"#ExampleForcedPlansPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   IF @Preflight=4
    EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@ResultSetArt='NONE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
   ELSE
    EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=@EmptyNames,@ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleForcedPlansPreflight'))<>1
      THROW 57421,N'FORCED_PLANS_MAPPING_PREFLIGHT',1;
  SET @PreflightCases+=1;SET @Preflight+=1;
 END;
 IF @CoreCases<>12 OR @ConsumerCases<>3 OR @PreflightCases<>5 OR @EmptyConsoleCases<>3
     THROW 57422,N'FORCED_PLANS_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC [sys].[sp_executesql] @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,@UpperLevel AS UpperSourceCompatibilityLevel,
        @LowerLevel AS LowerSourceCompatibilityLevel,@CoreCases AS CoreCases,@ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,
        @FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,@EmptyConsoleCases AS EmptySqlConsoleCases,
        @DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC [sys].[sp_executesql] @Sql;
 THROW;
END CATCH;
GO
