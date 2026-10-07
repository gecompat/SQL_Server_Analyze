USE [DeineDatenbank];
GO

/*
P3: Der allgemeine Vertrag prüft Schema, Filter, vollständige Summary und Consumer.
Die positive native Gegenprobe verwendet ausschließlich zwei bereits vorbereitete
synthetische Unicode-Datenbanken. Sie erzeugt oder verändert keine Fixture.
Ohne diese Fixture bleibt nur der positive Block NOT_EXECUTED.
Capability-Probes können zusätzliche leere Resultsets ausgeben. Positive CONSOLE-
Aufrufe werden deshalb direkt ausgeführt; ihre Zeilenparität benötigt Clientcapture.
*/
SET NOCOUNT ON;

DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @FrameworkLevel int=(SELECT [compatibility_level] FROM [master].[sys].[databases] WHERE [database_id]=DB_ID());
DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
DECLARE @Version nvarchar(128)=CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductVersion'));
DECLARE @FrameworkName nvarchar(128)=DB_NAME();
DECLARE @UpperName nvarchar(128)=N'ExampleCapabilityDbÄ''',@LowerName nvarchar(128)=N'exampleCapabilityDbÄ''';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingCapabilityDbÄ''';
DECLARE @UpperId int,@LowerId int,@FixtureStatus varchar(24)='NOT_EXECUTED';
DECLARE @UpperLevel int,@LowerLevel int;
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
IF @FrameworkLevel NOT IN (150,160,170) OR @FrameworkLevel IS NULL
    THROW 57000,N'Framework compatibility level is outside the portable contract.',1;
IF CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 57001,N'Framework collation is not the guaranteed contract.',1;
IF EXISTS(SELECT 1 FROM [master].[sys].[databases] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 57002,N'The synthetic missing database identifier already exists.',1;
SELECT @UpperId=MAX(CASE WHEN [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName COLLATE SQL_Latin1_General_CP1_CS_AS THEN [database_id] END),
       @LowerId=MAX(CASE WHEN [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@LowerName COLLATE SQL_Latin1_General_CP1_CS_AS THEN [database_id] END)
FROM [master].[sys].[databases];

/* Unabhängiger öffentlicher Vertrag: 27 Felder, 15 Texte, keine Identity. */
CREATE TABLE #ExampleCapabilitySchema
(
 [FeatureOrdinal] smallint NOT NULL,
 [FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [FeatureName] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ScopeType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsResourceIntensive] bit NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ServerMajorVersion] int NULL,[ServerProductVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MinimumMajorVersion] tinyint NOT NULL,[VersionSupported] bit NOT NULL,[GroupCheckApplied] bit NOT NULL,
 [GroupAccessAllowed] bit NULL,[AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequiredPermissionScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [PermissionCheckType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RequiredPermission] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PermissionDisplayText] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HasRequiredPermission] bit NULL,[IsQueryable] bit NOT NULL,[IsFeatureEnabled] bit NULL,[IsUsable] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL,
 [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Description] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
SELECT TOP(0) * INTO #ExampleCapabilityExpected FROM #ExampleCapabilitySchema;
CREATE TABLE #ExampleCapabilityNative
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ActualState] int NOT NULL,[WaitCapture] bit NOT NULL,[DatabasePermission] bit NULL,[ServerPermission] bit NULL);
CREATE TABLE #ExampleCapabilityEmptyConsole
([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleCapabilityPreflight([Dummy] int NULL);
CREATE TABLE #ExampleCapabilityCases
([CaseNumber] int NOT NULL,[IsNative] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Class] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Filter] bit NULL,[HighImpact] bit NULL,[IncludeSystem] bit NULL,[ExpectedInvalid] bit NOT NULL,[MissingWarning] bit NOT NULL);
INSERT #ExampleCapabilityCases VALUES
 (0,0,QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,0),
 (1,0,QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',1,0,0,0,0),
 (2,0,QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',NULL,0,0,0,0),
 (3,0,QUOTENAME(@MissingName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,1),
 (4,0,QUOTENAME(@FrameworkName)+N'|'+QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',0,0,0,1,0),
 (5,0,N'[ExampleInvalid',NULL,'QUERY_STORE_CURRENT',0,0,0,1,0),
 (6,0,QUOTENAME(@FrameworkName),NULL,'EXAMPLE_UNKNOWN_CLASS',0,0,0,1,0),
 (7,0,QUOTENAME(@FrameworkName),N'like:%','QUERY_STORE_CURRENT',0,0,0,1,0),
 (8,0,QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',0,NULL,0,1,0),
 (9,0,QUOTENAME(@FrameworkName),NULL,'QUERY_STORE_CURRENT',0,0,NULL,1,0),
 (10,0,QUOTENAME(@FrameworkName)+N'|'+QUOTENAME(@MissingName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,1);

BEGIN TRY
 IF @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId AND @Major>=16
 BEGIN
  IF (SELECT COUNT(*) FROM [master].[sys].[databases] WHERE [database_id] IN (@UpperId,@LowerId)
      AND [state]=0 AND [compatibility_level]=@FrameworkLevel AND [collation_name]=N'Latin1_General_100_CI_AS')<>2
      THROW 57003,N'Prepared fixture identities collation or separately measured source levels disagree.',1;
  SELECT @UpperLevel=MAX(CASE WHEN [database_id]=@UpperId THEN [compatibility_level] END),
         @LowerLevel=MAX(CASE WHEN [database_id]=@LowerId THEN [compatibility_level] END)
  FROM [master].[sys].[databases] WHERE [database_id] IN(@UpperId,@LowerId);
  DECLARE @FixtureSql nvarchar(max),@FixtureName nvarchar(128),@FixtureId int,@Actual int,@Wait bit,@DbPermission bit,@ServerPermission bit,@NativeDummy bigint;
  DECLARE @FixtureIndex int=0;
  WHILE @FixtureIndex<2
  BEGIN
   SELECT @FixtureName=CASE WHEN @FixtureIndex=0 THEN @UpperName ELSE @LowerName END,@FixtureId=CASE WHEN @FixtureIndex=0 THEN @UpperId ELSE @LowerId END;
   SET @FixtureSql=N'USE '+QUOTENAME(@FixtureName)+N';
SELECT @a=[actual_state],@w=CONVERT(bit,[wait_stats_capture_mode]) FROM sys.database_query_store_options;
SELECT @p=CONVERT(bit,HAS_PERMS_BY_NAME(DB_NAME(),N''DATABASE'',N''VIEW DATABASE PERFORMANCE STATE''));
SELECT @s=CONVERT(bit,HAS_PERMS_BY_NAME(NULL,NULL,N''VIEW SERVER PERFORMANCE STATE''));
SELECT @d=[plan_id] FROM sys.query_store_runtime_stats WHERE 1=0;
SELECT @d=[plan_id] FROM sys.query_store_wait_stats WHERE 1=0;
SELECT @d=[plan_id] FROM sys.query_store_plan WHERE 1=0;
SELECT @d=[query_hint_id] FROM sys.query_store_query_hints WHERE 1=0;';
   EXEC sys.sp_executesql @FixtureSql,N'@a int OUTPUT,@w bit OUTPUT,@p bit OUTPUT,@s bit OUTPUT,@d bigint OUTPUT',@a=@Actual OUTPUT,@w=@Wait OUTPUT,@p=@DbPermission OUTPUT,@s=@ServerPermission OUTPUT,@d=@NativeDummy OUTPUT;
   IF @Actual IS NULL OR @Wait IS NULL OR @DbPermission<>1 OR @DbPermission IS NULL OR @ServerPermission<>1 OR @ServerPermission IS NULL
       THROW 57004,N'Native fixture option or permission oracle is unavailable.',1;
   IF (@FixtureIndex=0 AND @Actual NOT IN(1,2,4)) OR (@FixtureIndex=1 AND @Actual<>0)
       THROW 57005,N'Prepared source Query Store ON/OFF states disagree.',1;
   INSERT #ExampleCapabilityNative VALUES(@FixtureId,@FixtureName,@Actual,@Wait,@DbPermission,@ServerPermission);
   SET @FixtureIndex+=1;
  END;
  SET @FixtureStatus='PASS';
  INSERT #ExampleCapabilityCases VALUES
   (20,1,QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,0),
   (21,1,QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName),NULL,'QUERY_STORE_CURRENT',1,0,0,0,0),
   (22,1,QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName),NULL,'QUERY_STORE_CURRENT',NULL,0,0,0,0),
   (23,1,QUOTENAME(@UpperName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,0),
   (24,1,QUOTENAME(@LowerName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,0),
   (25,1,QUOTENAME(@UpperName),NULL,'QUERY_STORE_CURRENT',1,0,0,0,0),
   (26,1,QUOTENAME(@LowerName),NULL,'QUERY_STORE_CURRENT',1,0,0,0,0),
   (27,1,NULL,N'like:'+@UpperName,'QUERY_STORE_CURRENT',0,0,0,0,0),
   (28,1,NULL,N'like:'+@LowerName,'QUERY_STORE_CURRENT',0,0,0,0,0),
   (29,1,QUOTENAME(@UpperName)+N'|'+QUOTENAME(@MissingName),NULL,'QUERY_STORE_CURRENT',1,0,0,0,1),
   (30,1,QUOTENAME(@LowerName)+N'|'+QUOTENAME(@UpperName),NULL,'QUERY_STORE_CURRENT',0,0,0,0,0);
 END;

 DECLARE @Case int=-1,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@Class varchar(64),@Filter bit,@High bit,@System bit,@Invalid bit,@Missing bit;
 DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@ExpectedSummary nvarchar(max),@ActualSummary nvarchar(max),@Sql nvarchar(max),@Before datetime2(3),@After datetime2(3),@ExpectedCount int;
 WHILE EXISTS(SELECT 1 FROM #ExampleCapabilityCases WHERE [CaseNumber]>@Case)
 BEGIN
  SELECT TOP(1) @Case=[CaseNumber],@Native=[IsNative],@Names=[Names],@Pattern=[Pattern],@Class=[Class],@Filter=[Filter],@High=[HighImpact],@System=[IncludeSystem],@Invalid=[ExpectedInvalid],@Missing=[MissingWarning]
  FROM #ExampleCapabilityCases WHERE [CaseNumber]>@Case ORDER BY [CaseNumber];
  IF @Native=1
  BEGIN
   SET @FixtureIndex=0;
   WHILE @FixtureIndex<2
   BEGIN
    SELECT @FixtureName=CASE WHEN @FixtureIndex=0 THEN @UpperName ELSE @LowerName END,@FixtureId=CASE WHEN @FixtureIndex=0 THEN @UpperId ELSE @LowerId END;
    IF NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WHERE [database_id]=@FixtureId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FixtureName COLLATE SQL_Latin1_General_CP1_CS_AS AND [state]=0 AND [compatibility_level]=@FrameworkLevel AND [collation_name]=N'Latin1_General_100_CI_AS')
        THROW 57003,N'Prepared fixture identity or source level changed.',1;
    SET @FixtureSql=N'USE '+QUOTENAME(@FixtureName)+N'; SELECT @a=[actual_state],@w=CONVERT(bit,[wait_stats_capture_mode]) FROM sys.database_query_store_options;';
    EXEC sys.sp_executesql @FixtureSql,N'@a int OUTPUT,@w bit OUTPUT',@a=@Actual OUTPUT,@w=@Wait OUTPUT;
    IF NOT EXISTS(SELECT 1 FROM #ExampleCapabilityNative WHERE [DatabaseId]=@FixtureId AND [ActualState]=@Actual AND [WaitCapture]=@Wait)
        THROW 57005,N'Independent native Query Store options changed before comparison.',1;
    SET @FixtureIndex+=1;
   END;
  END;
  CREATE TABLE #ExampleCapabilityExport([Dummy] int NULL);
  SET LOCK_TIMEOUT 731;
  SET @Before=SYSUTCDATETIME();
  EXEC monitor.USP_CheckFrameworkCapabilities @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@AnalyseKlasse=@Class,@NurNichtVerfuegbar=@Filter,@MitGruppenpruefung=0,@HighImpactConfirmed=@High,@SystemdatenbankenEinbeziehen=@System,
       @ResultSetArt='TABLE',@ResultTablesJson=N'{"capabilities":"#ExampleCapabilityExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>731 THROW 57006,N'Caller lock timeout changed.',1;
  IF ISJSON(@Json)<>1 OR @Json IS NULL THROW 57007,N'JSON is missing or invalid.',1;
  IF EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json)
            EXCEPT SELECT [KeyName],[KeyType] FROM (VALUES(N'meta',5),(N'capabilities',4),(N'summary',4),(N'warnings',4)) AS k([KeyName],[KeyType]))
     OR EXISTS(SELECT [KeyName],[KeyType] FROM (VALUES(N'meta',5),(N'capabilities',4),(N'summary',4),(N'warnings',4)) AS k([KeyName],[KeyType])
               EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
     OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>4
      THROW 57008,N'Top-level JSON keys or types disagree.',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>5 OR COALESCE(JSON_VALUE(@Json,N'$.meta.resultName'),N'')<>N'CheckFrameworkCapabilities'
     OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
     OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
     OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
     OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorMessage')
      THROW 57009,N'Metadata contract disagrees.',1;
  IF EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta') WHERE [key]<>N'errorMessage'
            EXCEPT SELECT [KeyName],[KeyType] FROM (VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1)) AS k([KeyName],[KeyType]))
     OR EXISTS(SELECT [KeyName],[KeyType] FROM (VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1)) AS k([KeyName],[KeyType])
               EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta') WHERE [key]<>N'errorMessage')
     OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorMessage' AND [type]<>CASE WHEN @Invalid=1 THEN 1 ELSE 0 END)
      THROW 57009,N'Metadata keys or original JSON types disagree.',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilityExport')
            EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilitySchema'))
     OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilitySchema')
               EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilityExport'))
      THROW 57010,N'Independent 27-field schema types relative ordinals nullability identity or collations disagree.',1;
  IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilityExport') AND [collation_name]=N'SQL_Latin1_General_CP1_CS_AS')<>15
      THROW 57011,N'Fifteen export text collations were not preserved.',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleCapabilityExport ORDER BY FeatureOrdinal,DatabaseName FOR JSON PATH,INCLUDE_NULL_VALUES);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
  IF COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.capabilities'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
      THROW 57012,N'Full TABLE JSON parity including NULL properties disagrees.',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.capabilities') AS a WHERE (SELECT COUNT(*) FROM OPENJSON(a.[value]))<>27)
      THROW 57013,N'A capability row does not contain all 27 properties.',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.summary') AS s WHERE
      (SELECT COUNT(*) FROM OPENJSON(s.[value]))<>4 OR EXISTS
      (SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(s.[value])
       EXCEPT SELECT [KeyName],[KeyType] FROM (VALUES(N'StatusCode',1),(N'FeatureCount',2),(N'QueryableCount',2),(N'UsableCount',2)) AS k([KeyName],[KeyType])))
      THROW 57013,N'Summary properties or original JSON types disagree.',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') AS w WHERE
      (SELECT COUNT(*) FROM OPENJSON(w.[value]))<>3 OR EXISTS
      (SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(w.[value])
       EXCEPT SELECT [KeyName],[KeyType] FROM (VALUES(N'RequestedName',1),(N'StatusCode',1),(N'ErrorMessage',1)) AS k([KeyName],[KeyType])))
      THROW 57013,N'Warning properties or original JSON types disagree.',1;
  IF (@Filter=1 OR @Filter IS NULL) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.capabilities') WITH([IsUsable] bit N'$.IsUsable') WHERE [IsUsable]<>0 OR [IsUsable] IS NULL)
      THROW 57014,N'Unavailable-only or NULL predicate was not preserved.',1;
  IF @Invalid=1 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.capabilities')<>N'[]' OR JSON_QUERY(@Json,N'$.summary')<>N'[]')
      THROW 57015,N'Invalid input did not retain empty schema and consumer status.',1;
  IF @Missing=1 AND ((SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH([RequestedName] nvarchar(128) N'$.RequestedName',[StatusCode] varchar(40) N'$.StatusCode') WHERE [RequestedName] COLLATE SQL_Latin1_General_CP1_CS_AS=@MissingName COLLATE SQL_Latin1_General_CP1_CS_AS AND [StatusCode]='DATABASE_UNAVAILABLE'))
      THROW 57016,N'Existing missing-selection warning was not preserved.',1;
  IF @Missing=0 AND JSON_QUERY(@Json,N'$.warnings')<>N'[]' THROW 57017,N'Unexpected selection warning.',1;
  IF @Case IN(0,1,2,10) AND ISNULL((SELECT SUM([FeatureCount]) FROM OPENJSON(@Json,N'$.summary') WITH([FeatureCount] bigint N'$.FeatureCount')),0)<>5
      THROW 57017,N'General full-scope summary was changed by the output filter or missing selection.',1;
  IF @Case=3 AND (JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR JSON_QUERY(@Json,N'$.capabilities')<>N'[]' OR JSON_QUERY(@Json,N'$.summary')<>N'[]')
      THROW 57018,N'Missing-only existing overall status changed.',1;
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleCapabilityExpected;
   INSERT #ExampleCapabilityExpected
   SELECT f.[FeatureOrdinal],f.[FeatureCode],f.[FeatureName],f.[ScopeType],f.[AnalysisClass],f.[AnalysisLevel],f.[IsResourceIntensive],n.[DatabaseName],@Major,@Version,f.[MinimumMajorVersion],CONVERT(bit,1),CONVERT(bit,0),CONVERT(bit,1),'OPEN',
          f.[PermissionScopeFromSql2022],f.[PermissionCheckTypeFromSql2022],f.[PermissionNameFromSql2022],f.[PermissionDisplayTextFromSql2022],
          CASE WHEN f.[FeatureCode]='QUERY_STORE_HINTS' THEN n.[ServerPermission] ELSE n.[DatabasePermission] END,CONVERT(bit,1),e.[Enabled],
          CONVERT(bit,CASE WHEN e.[Enabled]=0 THEN 0 ELSE 1 END),CASE WHEN e.[Enabled]=0 THEN 'AVAILABLE_DISABLED' ELSE 'AVAILABLE' END,NULL,NULL,f.[Description]
   FROM monitor.VW_FrameworkFeatureCatalog AS f CROSS JOIN #ExampleCapabilityNative AS n
   CROSS APPLY(SELECT CONVERT(bit,CASE WHEN f.[FeatureCode]='QUERY_STORE_HINTS' THEN NULL WHEN f.[FeatureCode]='QUERY_STORE_WAITS' THEN n.[WaitCapture] WHEN n.[ActualState] IN(1,2,4) THEN 1 ELSE 0 END) AS [Enabled]) AS e
   WHERE f.[FeatureCode] IN('QUERY_STORE_STATUS','QUERY_STORE_RUNTIME','QUERY_STORE_WAITS','QUERY_STORE_PLANS','QUERY_STORE_HINTS')
     AND ((@Case IN(20,21,22,30)) OR (@Case IN(23,25,27,29) AND n.[DatabaseId]=@UpperId) OR (@Case IN(24,26,28) AND n.[DatabaseId]=@LowerId));
   SET @ExpectedCount=CASE WHEN @Case IN(20,21,22,30) THEN 10 ELSE 5 END;
   IF (SELECT COUNT(*) FROM #ExampleCapabilityExpected)<>@ExpectedCount
      OR EXISTS(SELECT 1 FROM #ExampleCapabilityExpected WHERE [FeatureOrdinal]<>CASE [FeatureCode] WHEN 'QUERY_STORE_STATUS' THEN 200 WHEN 'QUERY_STORE_RUNTIME' THEN 201 WHEN 'QUERY_STORE_WAITS' THEN 202 WHEN 'QUERY_STORE_PLANS' THEN 203 WHEN 'QUERY_STORE_HINTS' THEN 204 END)
       THROW 57019,N'Independent five-feature identity oracle disagrees.',1;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleCapabilityExpected WHERE @Filter=0 OR [IsUsable]=0 ORDER BY [FeatureOrdinal],[DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
   SELECT @ExpectedSummary=(SELECT [StatusCode],COUNT_BIG(*) AS [FeatureCount],SUM(CONVERT(bigint,[IsQueryable])) AS [QueryableCount],SUM(CONVERT(bigint,[IsUsable])) AS [UsableCount] FROM #ExampleCapabilityExpected GROUP BY [StatusCode] ORDER BY [StatusCode] FOR JSON PATH,INCLUDE_NULL_VALUES);
   SET @ActualSummary=JSON_QUERY(@Json,N'$.summary');
   IF COALESCE(@ExpectedJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.capabilities') COLLATE SQL_Latin1_General_CP1_CS_AS
      OR @ExpectedSummary COLLATE SQL_Latin1_General_CP1_CS_AS<>@ActualSummary COLLATE SQL_Latin1_General_CP1_CS_AS
      OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN EXISTS(SELECT 1 FROM #ExampleCapabilityExpected WHERE [IsUsable]=0) THEN N'AVAILABLE_LIMITED' ELSE N'AVAILABLE' END
       THROW 57020,N'Native full 27-field parity full-scope summary or overall status disagrees.',1;
   SET @NativeCases+=1;
  END
  ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleCapabilityExport;
 END;

 /* Invalid class avoids capability and candidate probes, so SQL capture is safe. */
 DECLARE @EmptyIndex int=0;
 WHILE @EmptyIndex<3
 BEGIN
  TRUNCATE TABLE #ExampleCapabilityEmptyConsole;
  SET @Filter=CASE @EmptyIndex WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE NULL END;
  INSERT #ExampleCapabilityEmptyConsole
  EXEC monitor.USP_CheckFrameworkCapabilities @AnalyseKlasse='EXAMPLE_UNKNOWN_CLASS',@NurNichtVerfuegbar=@Filter,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleCapabilityEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleCapabilityEmptyConsole WHERE [Ergebnis]<>N'Keine fachlichen Ergebnisse' OR [Status] IS NOT NULL OR [Hinweis] IS NOT NULL)
     OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.capabilities')<>N'[]'
      THROW 57021,N'Empty CONSOLE contract disagrees.',1;
  SET @EmptyIndex+=1;SET @EmptyConsoleCases+=1;
 END;
 IF @FixtureStatus='PASS'
 BEGIN
  DECLARE @DirectIndex int=0;
  WHILE @DirectIndex<3
  BEGIN
   SET @Filter=CASE @DirectIndex WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE NULL END;
   SET @Names=QUOTENAME(@UpperName);
   EXEC monitor.USP_CheckFrameworkCapabilities @DatabaseNames=@Names,@AnalyseKlasse='QUERY_STORE_CURRENT',@MitGruppenpruefung=0,@NurNichtVerfuegbar=@Filter,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   SELECT @ExpectedJson=(SELECT * FROM #ExampleCapabilityExpected WHERE [DatabaseName]=@UpperName AND (@Filter=0 OR [IsUsable]=0) ORDER BY [FeatureOrdinal],[DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode') NOT IN(N'AVAILABLE',N'AVAILABLE_LIMITED')
      OR COALESCE(@ExpectedJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.capabilities'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
      THROW 57022,N'Direct CONSOLE consumer JSON is invalid.',1;
   SET @DirectIndex+=1;SET @DirectConsoleCases+=1;
  END;
 END;
 EXEC monitor.USP_CheckFrameworkCapabilities @AnalyseKlasse='EXAMPLE_UNKNOWN_CLASS',@ResultSetArt='UNSUPPORTED',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' THROW 57023,N'Unsupported output did not retain consumer status.',1;
 SET @ConsumerCases+=1;
 SET @Json=N'ExamplePreviousJson';
 EXEC monitor.USP_CheckFrameworkCapabilities @AnalyseKlasse='EXAMPLE_UNKNOWN_CLASS',@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF @Json IS NOT NULL THROW 57024,N'Disabled JSON did not clear previous output.',1;
 SET @ConsumerCases+=1;

 DECLARE @MapIndex int=0,@Map nvarchar(max),@Caught int,@Route varchar(16);
 WHILE @MapIndex<6
 BEGIN
  SET @Map=CASE @MapIndex WHEN 0 THEN N'{"unknown":"#ExampleCapabilityPreflight"}' WHEN 1 THEN N'{"capabilities":"#ExampleMissingCapabilityTarget"}' WHEN 2 THEN N'{"capabilities":"ExampleCapabilityPreflight"}' WHEN 3 THEN N'{"capabilities":"#ExampleCapabilityPreflight","capabilities":"#ExampleCapabilityPreflight"}' ELSE N'{"capabilities":"#ExampleCapabilityPreflight"}' END;
  SET @Route=CASE WHEN @MapIndex=5 THEN 'NONE' ELSE 'TABLE' END;SET @Caught=NULL;
  IF @MapIndex=4 INSERT #ExampleCapabilityPreflight VALUES(1);
  BEGIN TRY
   EXEC monitor.USP_CheckFrameworkCapabilities @AnalyseKlasse='EXAMPLE_UNKNOWN_CLASS',@ResultSetArt=@Route,@ResultTablesJson=@Map,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   SET @Caught=ERROR_NUMBER();
  END CATCH;
  IF @Caught<>51011 OR @Caught IS NULL THROW 57025,N'Invalid mapping did not fail before semantic work.',1;
  IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCapabilityPreflight') AND [name]=N'Dummy')<>1 THROW 57026,N'Preflight target schema changed.',1;
  TRUNCATE TABLE #ExampleCapabilityPreflight;
  SET @MapIndex+=1;SET @PreflightCases+=1;
 END;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT N'CheckFrameworkCapabilities collation contract' AS [Contract],@FrameworkLevel AS [FrameworkCompatibilityLevel],@UpperLevel AS [UpperSourceCompatibilityLevel],@LowerLevel AS [LowerSourceCompatibilityLevel],@CoreCases AS [CoreTableJsonCases],@ConsumerCases AS [ConsumerCases],@PreflightCases AS [PreflightCases],@FixtureStatus AS [PositiveFixtureStatus],@NativeCases AS [NativeTableJsonCases],@EmptyConsoleCases AS [EmptySqlConsoleCaptures],@DirectConsoleCases AS [DirectConsoleCalls];
END TRY
BEGIN CATCH
 DECLARE @RestoreSql nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @RestoreSql;
 THROW;
END CATCH;
GO
