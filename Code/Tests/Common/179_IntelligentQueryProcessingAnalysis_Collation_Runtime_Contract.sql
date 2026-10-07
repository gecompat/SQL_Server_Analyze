USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft den gemeinsamen sechsfeldrigen IQP-Signalexport und alle vier
JSON-Facharrays mit insgesamt 28 Feldern. Allgemeine Fälle laufen auch ohne
Fixture. Der optionale native Block liest zwei extern vorbereitete eigene
leere Unicode-CI-Datenbanken (READ_WRITE mit Capture NONE und OFF), ohne DDL,
Optionsänderung oder synthetischen Workload. Fehlende Voraussetzungen melden
NOT_EXECUTED. Varianten-, Feedback- und Empfehlungszähler werden nativ gemessen,
auch im Frameworkscope; Nullmengen beweisen keine aktive IQP-Nutzung.
RAW und positive CONSOLE-Fachzeilen benötigen einen separaten Clientcapture;
direkte Aufrufe prüfen hier nur Status und begleitendes JSON. Berechtigungsfehler,
Timeout, aktive PSP/OPPO-/Feedbackwirkung und ältere native Engines bleiben offen.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 58100,N'IQP_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58101,N'IQP_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@LoadSql nvarchar(max),@Db nvarchar(128);
DECLARE @UpperName nvarchar(128)=N'ExampleIqpÄ🔬',@LowerName nvarchar(128)=N'exampleIqpÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingIqpÄ🔬',@WrongName nvarchar(128)=N'EXAMPLEIqpÄ🔬';
DECLARE @MissingScope nvarchar(258)=QUOTENAME(@MissingName),@AllNames nvarchar(max),@FixtureStatus varchar(24)='NOT_EXECUTED';
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,@WrongName))
 THROW 58102,N'IQP_MISSING_IDENTIFIER',1;
CREATE TABLE #ExampleIqpDatabaseStateSchema
([DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CompatibilityLevel] tinyint NULL,
 [QueryStoreActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryStoreDesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryStoreReadonlyReason] bigint NULL,
 [PspEligible] bit NOT NULL,
 [OppoEligible] bit NOT NULL,
 [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
SELECT TOP(0) * INTO #ExampleIqpDatabaseStateNative FROM #ExampleIqpDatabaseStateSchema;
SELECT TOP(0) * INTO #ExampleIqpDatabaseStateExpected FROM #ExampleIqpDatabaseStateSchema;
CREATE TABLE #ExampleIqpConfigurationSchema
([DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ConfigurationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ConfigurationValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsValueDefault] bit NULL);
SELECT TOP(0) * INTO #ExampleIqpConfigurationNative FROM #ExampleIqpConfigurationSchema;
SELECT TOP(0) * INTO #ExampleIqpConfigurationExpected FROM #ExampleIqpConfigurationSchema;
CREATE TABLE #ExampleIqpAutomaticTuningSchema
([DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [OptionName] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [DesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ReasonDesc] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleIqpAutomaticTuningNative FROM #ExampleIqpAutomaticTuningSchema;
SELECT TOP(0) * INTO #ExampleIqpAutomaticTuningExpected FROM #ExampleIqpAutomaticTuningSchema;
CREATE TABLE #ExampleIqpSignalsSchema
([DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [SignalCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsSourceAvailable] bit NOT NULL,
 [EvidenceCount] bigint NULL,
 [Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
SELECT TOP(0) * INTO #ExampleIqpSignalsNative FROM #ExampleIqpSignalsSchema;
SELECT TOP(0) * INTO #ExampleIqpSignalsExpected FROM #ExampleIqpSignalsSchema;
CREATE TABLE #ExampleIqpOptions
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Level] int NOT NULL,[CollationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ActualState] int NOT NULL,[DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,[Queries] bigint NOT NULL,[UserTables] int NOT NULL);
CREATE TABLE #ExampleIqpFixtureNames([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualState] int NOT NULL,[DesiredState] int NOT NULL);
INSERT #ExampleIqpFixtureNames VALUES(@UpperName,2,2),(@LowerName,0,0);
CREATE TABLE #ExampleIqpSelected([DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleIqpEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleIqpPreflight([Dummy] int NULL);
CREATE TABLE #ExampleIqpCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[IncludeSystem] bit NULL,[HighImpact] bit NULL,
 [Mode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ExpectedPartial] bit NOT NULL,[MissingWarningName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
INSERT #ExampleIqpCases VALUES
 (0,0,@MissingScope,NULL,NULL,0,1,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (1,0,@MissingScope,NULL,0,0,1,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (2,0,@MissingScope,NULL,1,0,1,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (3,0,@MissingScope,NULL,2,0,1,'TABLE','DATABASE_UNAVAILABLE',1,@MissingName),
 (4,0,@MissingScope,NULL,-1,0,1,'TABLE','INVALID_PARAMETER',1,NULL),
 (5,0,N'[ExampleInvalid',NULL,0,0,1,'TABLE','INVALID_PARAMETER',0,NULL),
 (6,0,@MissingScope+N'|'+@MissingScope,NULL,0,0,1,'TABLE','INVALID_PARAMETER',0,NULL),
 (7,0,NULL,N'like:',0,0,1,'TABLE','INVALID_PARAMETER',0,NULL),
 (8,0,@MissingScope,N'like:Example%',0,0,1,'TABLE','INVALID_PARAMETER',0,NULL),
 (9,0,@MissingScope,NULL,0,NULL,1,'TABLE','INVALID_PARAMETER',0,NULL),
 (10,0,@MissingScope,NULL,0,0,NULL,'TABLE','INVALID_PARAMETER',0,NULL),
 (11,0,@MissingScope,NULL,0,0,0,'TABLE','HIGH_IMPACT_CONFIRMATION_REQUIRED',0,NULL),
 (12,0,@MissingScope,NULL,0,0,1,'UNSUPPORTED','INVALID_PARAMETER',1,NULL),
 (13,0,@MissingScope,NULL,0,0,1,' table ','DATABASE_UNAVAILABLE',1,@MissingName);
IF @Major=17 AND @FrameworkLevel=170 AND (SELECT COUNT(*) FROM master.sys.databases d JOIN #ExampleIqpFixtureNames n
 ON d.name COLLATE SQL_Latin1_General_CP1_CS_AS=n.DatabaseName WHERE d.state=0 AND HAS_DBACCESS(d.name)=1)=2
BEGIN
 DECLARE [Fixture179] CURSOR LOCAL FAST_FORWARD FOR SELECT DatabaseName FROM #ExampleIqpFixtureNames;
 OPEN [Fixture179];FETCH NEXT FROM [Fixture179] INTO @Db;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@Db)+N';INSERT #ExampleIqpOptions
   SELECT DB_ID(),(SELECT name FROM master.sys.databases WHERE database_id=DB_ID()),
    (SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
    CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N''Collation'')),actual_state,desired_state,query_capture_mode,
    (SELECT COUNT_BIG(*) FROM sys.query_store_query),(SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)
   FROM sys.database_query_store_options;';
  EXEC sys.sp_executesql @Sql;
  FETCH NEXT FROM [Fixture179] INTO @Db;
 END;
 CLOSE [Fixture179];DEALLOCATE [Fixture179];
 IF (SELECT COUNT(*) FROM #ExampleIqpOptions)=2 AND (SELECT COUNT(DISTINCT DatabaseId) FROM #ExampleIqpOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleIqpOptions o JOIN #ExampleIqpFixtureNames n ON n.DatabaseName=o.DatabaseName
   WHERE o.[Level]<>170 OR o.CollationName<>N'Latin1_General_100_CI_AS' OR o.ActualState<>n.ActualState OR o.DesiredState<>n.DesiredState
    OR (o.DatabaseName=@UpperName AND o.CaptureMode<>3) OR o.Queries<>0 OR o.UserTables<>0)
 BEGIN
  SET @AllNames=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);SET @FixtureStatus='PENDING';
  INSERT #ExampleIqpCases VALUES
   (20,1,@AllNames,NULL,NULL,0,1,'TABLE',NULL,0,NULL),
   (21,1,@AllNames,NULL,0,0,1,'TABLE',NULL,0,NULL),
   (22,1,@AllNames,NULL,1,0,1,'TABLE',NULL,0,NULL),
   (23,1,@AllNames,NULL,2,0,1,'TABLE',NULL,0,NULL),
   (24,1,QUOTENAME(@UpperName),NULL,0,0,1,'TABLE',NULL,0,NULL),
   (25,1,QUOTENAME(@LowerName),NULL,0,0,1,'TABLE',NULL,0,NULL),
   (26,1,QUOTENAME(@LowerName)+N'|'+QUOTENAME(@UpperName),NULL,1,0,1,'TABLE',NULL,0,NULL),
   (27,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,1,0,1,'TABLE',NULL,1,@MissingName),
   (28,1,QUOTENAME(@WrongName),NULL,0,0,1,'TABLE',NULL,1,@WrongName),
   (29,1,NULL,N'like:ExampleIqp%',0,0,1,'TABLE',NULL,0,NULL),
   (30,1,NULL,N'like:%Iqp%Ä🔬',0,0,1,'TABLE',NULL,0,NULL),
   (31,1,NULL,NULL,0,0,1,'TABLE',NULL,0,NULL),
   (32,1,N'',NULL,0,0,1,'TABLE',NULL,0,NULL),
   (33,1,N'   ',NULL,0,0,1,'TABLE',NULL,0,NULL),
   (34,1,QUOTENAME(@UpperName),NULL,1,0,1,'TABLE',NULL,0,NULL),
   (35,1,QUOTENAME(@LowerName),NULL,2,0,1,'TABLE',NULL,0,NULL),
   (36,1,@AllNames,NULL,1000,0,1,'TABLE',NULL,0,NULL),
   (37,1,QUOTENAME(DB_NAME()),NULL,0,0,1,'TABLE',NULL,0,NULL);
 END;
END;
-- Native identities and raw options determine findings independently of product JSON.
SET @LoadSql=N'DECLARE @id int=DB_ID(),@name nvarchar(128)=(SELECT name FROM master.sys.databases WHERE database_id=DB_ID());
 DECLARE @cl tinyint=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),@actual int,@desired int,
  @actualDesc nvarchar(60),@desiredDesc nvarchar(60),@readonly bigint,@code varchar(80)=''IQP_EVIDENCE_AVAILABLE'',@severity varchar(16)=''INFO'';
 SELECT @actual=actual_state,@desired=desired_state,@actualDesc=actual_state_desc,@desiredDesc=desired_state_desc,@readonly=readonly_reason FROM sys.database_query_store_options;
 IF @actual IS NULL OR @actual=0 SELECT @code=''QUERY_STORE_OFF'',@severity=''HIGH'';
 ELSE IF @actual=1 AND @desired=2 SELECT @code=''QUERY_STORE_READ_ONLY'',@severity=''MEDIUM'';
 ELSE IF @cl<150 SET @code=''IQP_COMPATIBILITY_BELOW_150'';
 INSERT #ExampleIqpDatabaseStateNative VALUES(@id,@name,@cl,@actualDesc,@desiredDesc,@readonly,
  CONVERT(bit,IIF(@major>=16 AND @cl>=160,1,0)),CONVERT(bit,IIF(@major>=17 AND @cl>=170,1,0)),@code,@severity,
  N''Feature-Eignung folgt Version und Compatibility Level; Evidenzmengen allein bewerten keine Wirksamkeit.'');
 INSERT #ExampleIqpConfigurationNative SELECT @id,@name,name,CONVERT(nvarchar(4000),value),is_value_default FROM sys.database_scoped_configurations
 WHERE name IN(N''PARAMETER_SENSITIVE_PLAN_OPTIMIZATION'',N''OPTIONAL_PARAMETER_OPTIMIZATION'',N''MEMORY_GRANT_FEEDBACK_PERSISTENCE'',
 N''MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT'',N''DOP_FEEDBACK'',N''CE_FEEDBACK'',N''BATCH_MODE_MEMORY_GRANT_FEEDBACK'',
 N''ROW_MODE_MEMORY_GRANT_FEEDBACK'',N''BATCH_MODE_ADAPTIVE_JOINS'',N''INTERLEAVED_EXECUTION_TVF'',N''DEFERRED_COMPILATION_TV'');
 INSERT #ExampleIqpAutomaticTuningNative SELECT @id,@name,name,desired_state_desc,actual_state_desc,reason_desc FROM sys.database_automatic_tuning_options;
 INSERT #ExampleIqpSignalsNative SELECT @id,@name,''TUNING_RECOMMENDATIONS'',CONVERT(bit,1),COUNT_BIG(*),
 N''Anzahl aktueller Automatic-Tuning-Empfehlungen; Details und SQL-Texte werden nicht gelesen.'' FROM sys.dm_db_tuning_recommendations;';
IF @Major>=16 SET @LoadSql+=N'
 INSERT #ExampleIqpSignalsNative SELECT @id,@name,''QUERY_VARIANTS'',CONVERT(bit,1),COUNT_BIG(*),N''Aggregierte PSP-/OPPO-Varianten; null Zeilen sind kein Fehlerbeweis.'' FROM sys.query_store_query_variant;
 INSERT #ExampleIqpSignalsNative SELECT @id,@name,''PLAN_FEEDBACK'',CONVERT(bit,1),COUNT_BIG(*),N''Aggregierte CE-, Memory-Grant-, DOP- oder LAQ-Feedbackevidenz; keine Query-Texte.'' FROM sys.query_store_plan_feedback;';
ELSE SET @LoadSql+=N'
 INSERT #ExampleIqpSignalsNative VALUES(@id,@name,''QUERY_VARIANTS'',0,NULL,N''Katalogsicht ist vor SQL Server 2022 nicht verfügbar.''),
 (@id,@name,''PLAN_FEEDBACK'',0,NULL,N''Katalogsicht ist vor SQL Server 2022 nicht verfügbar.'');';
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@EmptyConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@MaxRows int,@IncludeSystem bit,@High bit,@Mode varchar(16),
 @Status varchar(40),@Partial bit,@Missing nvarchar(128),@OutStatus varchar(40),@OutPartial bit,@OutError int,@OutMessage nvarchar(2048);
DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Rows bigint,@Limit bigint;
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases179] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleIqpCases ORDER BY CaseNumber;
 OPEN [Cases179];FETCH NEXT FROM [Cases179] INTO @Case,@Native,@Names,@Pattern,@MaxRows,@IncludeSystem,@High,@Mode,@Status,@Partial,@Missing;
 WHILE @@FETCH_STATUS=0
 BEGIN
  TRUNCATE TABLE #ExampleIqpSelected;
  TRUNCATE TABLE #ExampleIqpDatabaseStateNative;TRUNCATE TABLE #ExampleIqpDatabaseStateExpected;
  TRUNCATE TABLE #ExampleIqpConfigurationNative;TRUNCATE TABLE #ExampleIqpConfigurationExpected;
  TRUNCATE TABLE #ExampleIqpAutomaticTuningNative;TRUNCATE TABLE #ExampleIqpAutomaticTuningExpected;
  TRUNCATE TABLE #ExampleIqpSignalsNative;TRUNCATE TABLE #ExampleIqpSignalsExpected;
  SET @Limit=CASE WHEN @MaxRows<0 THEN 0 WHEN @MaxRows IS NULL OR @MaxRows=0 THEN 9223372036854775807 ELSE @MaxRows END;
  IF @Native=1
  BEGIN
   INSERT #ExampleIqpSelected SELECT database_id,name FROM master.sys.databases d
    WHERE database_id>4 AND state=0 AND HAS_DBACCESS(name)=1
     AND ((@Names IS NULL OR NULLIF(LTRIM(RTRIM(@Names)),N'') IS NULL)
      OR ((@Names=@AllNames OR @Case=26) AND EXISTS(SELECT 1 FROM #ExampleIqpFixtureNames f WHERE f.DatabaseName=d.name COLLATE SQL_Latin1_General_CP1_CS_AS))
      OR @Names=QUOTENAME(d.name COLLATE SQL_Latin1_General_CP1_CS_AS)
      OR (@Case=27 AND d.name COLLATE SQL_Latin1_General_CP1_CS_AS=@UpperName))
     AND (@Pattern IS NULL OR d.name COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
   DECLARE [Native179] CURSOR LOCAL FAST_FORWARD FOR SELECT DatabaseName FROM #ExampleIqpSelected ORDER BY DatabaseId;
   OPEN [Native179];FETCH NEXT FROM [Native179] INTO @Db;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @Sql=N'USE '+QUOTENAME(@Db)+N';'+@LoadSql;
    EXEC sys.sp_executesql @Sql,N'@major int',@major=@Major;
    FETCH NEXT FROM [Native179] INTO @Db;
   END;
   CLOSE [Native179];DEALLOCATE [Native179];
   IF (SELECT COUNT(*) FROM #ExampleIqpDatabaseStateNative)<>(SELECT COUNT(*) FROM #ExampleIqpSelected)
    OR (SELECT COUNT(*) FROM #ExampleIqpSignalsNative)<>3*(SELECT COUNT(*) FROM #ExampleIqpSelected)
    THROW 58103,N'IQP_NATIVE_SOURCE_IDENTITIES',1;
   SET @Status=CASE WHEN NOT EXISTS(SELECT 1 FROM #ExampleIqpDatabaseStateNative) THEN 'DATABASE_UNAVAILABLE'
    WHEN @Partial=1 THEN 'AVAILABLE_LIMITED'
    WHEN EXISTS(SELECT 1 FROM #ExampleIqpDatabaseStateNative WHERE FindingCode<>'IQP_EVIDENCE_AVAILABLE') THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END;
  END;
  INSERT #ExampleIqpDatabaseStateExpected SELECT TOP(@Limit) * FROM #ExampleIqpDatabaseStateNative ORDER BY DatabaseId;
  INSERT #ExampleIqpConfigurationExpected SELECT TOP(@Limit) * FROM #ExampleIqpConfigurationNative ORDER BY DatabaseId,ConfigurationName;
  INSERT #ExampleIqpAutomaticTuningExpected SELECT TOP(@Limit) * FROM #ExampleIqpAutomaticTuningNative ORDER BY DatabaseId,OptionName;
  INSERT #ExampleIqpSignalsExpected SELECT TOP(@Limit) * FROM #ExampleIqpSignalsNative ORDER BY DatabaseId,SignalCode;
  CREATE TABLE #ExampleIqpExport([Dummy] int NULL);
  SELECT @Json=NULL,@OutStatus=NULL,@OutPartial=NULL,@OutError=NULL,@OutMessage=NULL,@Before=SYSUTCDATETIME();
  IF @Case=12 EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@Names,@MaxZeilen=@MaxRows,@ResultSetArt=@Mode,
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT,@ErrorNumberOut=@OutError OUTPUT,@ErrorMessageOut=@OutMessage OUTPUT;
  ELSE EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@MaxZeilen=@MaxRows,
   @SystemdatenbankenEinbeziehen=@IncludeSystem,@HighImpactConfirmed=@High,@ResultSetArt=@Mode,
   @ResultTablesJson=N'{"signals":"#ExampleIqpExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
   @StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT,@ErrorNumberOut=@OutError OUTPUT,@ErrorMessageOut=@OutMessage OUTPUT;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 58104,N'IQP_CALLER_LOCK_TIMEOUT',1;
  IF @Json IS NULL OR ISJSON(@Json)<>1 THROW 58105,N'IQP_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>6
   OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM
    (VALUES(N'meta',5),(N'databaseState',4),(N'configuration',4),(N'automaticTuning',4),(N'signals',4),(N'warnings',4)) t(k,v))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>5
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode') AND [type]<>1)
    OR ([key]=N'schemaVersion' AND [type]<>2) OR ([key]=N'isPartial' AND [type]<>3))
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'IntelligentQueryProcessingAnalysis'
   OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status OR @OutStatus IS NULL OR @OutStatus<>@Status
   OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Partial=1 THEN N'true' ELSE N'false' END
   OR @OutPartial IS NULL OR @OutPartial<>@Partial OR @OutError IS NOT NULL
   OR ((@Status IN('INVALID_PARAMETER','HIGH_IMPACT_CONFIRMATION_REQUIRED') AND @OutMessage IS NULL)
    OR (@Status NOT IN('INVALID_PARAMETER','HIGH_IMPACT_CONFIRMATION_REQUIRED') AND @OutMessage IS NOT NULL))
    THROW 58106,N'IQP_META_OUTPUT',1;
  SET @At=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 58107,N'IQP_CAPTURE_TIME',1;
  IF @Case<>12
  BEGIN
   IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleIqpExport')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleIqpSignalsSchema'))
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleIqpSignalsSchema')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
    FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleIqpExport')) THROW 58108,N'IQP_SIGNALS_SCHEMA',1;
   SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleIqpExport ORDER BY DatabaseId,SignalCode FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleIqpExport);';
   EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  END ELSE BEGIN SET @TableJson=N'[]';SET @Rows=0;END;
  IF @Rows<>(SELECT COUNT(*) FROM #ExampleIqpSignalsExpected) OR @Rows<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.signals'))
   OR COALESCE(@TableJson,N'[]') COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.signals') COLLATE Latin1_General_100_BIN2
    THROW 58109,N'IQP_TABLE_JSON',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseState') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>11
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'DatabaseId'),(N'DatabaseName'),(N'CompatibilityLevel'),(N'QueryStoreActualStateDesc'),(N'QueryStoreDesiredStateDesc'),(N'QueryStoreReadonlyReason'),(N'PspEligible'),(N'OppoEligible'),(N'FindingCode'),(N'FindingSeverity'),(N'EvidenceLimit')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)) THROW 58110,N'IQP_DATABASESTATE_FIELDS',1;
  SELECT @ExpectedJson=(SELECT * FROM #ExampleIqpDatabaseStateExpected ORDER BY DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@ExpectedJson,N'[]') COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.databaseState') COLLATE Latin1_General_100_BIN2
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseState') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseState') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58111,N'IQP_DATABASESTATE_NATIVE_VALUES_ORDER',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.configuration') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>5
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'DatabaseId'),(N'DatabaseName'),(N'ConfigurationName'),(N'ConfigurationValue'),(N'IsValueDefault')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)) THROW 58110,N'IQP_CONFIGURATION_FIELDS',1;
  SELECT @ExpectedJson=(SELECT * FROM #ExampleIqpConfigurationExpected ORDER BY DatabaseId,ConfigurationName FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@ExpectedJson,N'[]') COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.configuration') COLLATE Latin1_General_100_BIN2
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.configuration') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.configuration') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58111,N'IQP_CONFIGURATION_NATIVE_VALUES_ORDER',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.automaticTuning') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>6
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'DatabaseId'),(N'DatabaseName'),(N'OptionName'),(N'DesiredStateDesc'),(N'ActualStateDesc'),(N'ReasonDesc')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)) THROW 58110,N'IQP_AUTOMATICTUNING_FIELDS',1;
  SELECT @ExpectedJson=(SELECT * FROM #ExampleIqpAutomaticTuningExpected ORDER BY DatabaseId,OptionName FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@ExpectedJson,N'[]') COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.automaticTuning') COLLATE Latin1_General_100_BIN2
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.automaticTuning') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.automaticTuning') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58111,N'IQP_AUTOMATICTUNING_NATIVE_VALUES_ORDER',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.signals') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>6
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'DatabaseId'),(N'DatabaseName'),(N'SignalCode'),(N'IsSourceAvailable'),(N'EvidenceCount'),(N'Interpretation')) t(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)) THROW 58110,N'IQP_SIGNALS_FIELDS',1;
  SELECT @ExpectedJson=(SELECT * FROM #ExampleIqpSignalsExpected ORDER BY DatabaseId,SignalCode FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@ExpectedJson,N'[]') COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.signals') COLLATE Latin1_General_100_BIN2
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.signals') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.signals') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58111,N'IQP_SIGNALS_NATIVE_VALUES_ORDER',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>CASE WHEN @Missing IS NULL THEN 0 ELSE 1 END
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>4
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) EXCEPT SELECT k FROM (VALUES(N'DatabaseName'),(N'StatusCode'),(N'ErrorNumber'),(N'ErrorMessage')) t(k))
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE ([key] IN(N'DatabaseName',N'StatusCode',N'ErrorMessage') AND [type]<>1) OR ([key]=N'ErrorNumber' AND [type]<>0)))
   OR (@Missing IS NOT NULL AND (JSON_VALUE(@Json,N'$.warnings[0].DatabaseName') COLLATE Latin1_General_100_BIN2<>@Missing COLLATE Latin1_General_100_BIN2
    OR JSON_VALUE(@Json,N'$.warnings[0].StatusCode')<>N'DATABASE_UNAVAILABLE'
    OR JSON_VALUE(@Json,N'$.warnings[0].ErrorMessage') IS NULL)) THROW 58112,N'IQP_SELECTION_WARNINGS',1;
  IF @Native=1 SET @NativeCases+=1;ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleIqpExport;
  FETCH NEXT FROM [Cases179] INTO @Case,@Native,@Names,@Pattern,@MaxRows,@IncludeSystem,@High,@Mode,@Status,@Partial,@Missing;
 END;
 CLOSE [Cases179];DEALLOCATE [Cases179];
 IF @FixtureStatus='PENDING'
 BEGIN
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @MaxRows=CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@AllNames,@MaxZeilen=@MaxRows,@HighImpactConfirmed=1,
    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
   IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE_WITH_FINDING' OR @OutStatus<>'AVAILABLE_WITH_FINDING' OR @OutPartial<>0
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.signals'))<>CASE @Direct WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 6 END OR @@LOCK_TIMEOUT<>137
     THROW 58113,N'IQP_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @Direct+=1;SET @DirectConsoleCases+=1;
  END;
  IF @NativeCases<>18 THROW 58114,N'IQP_NATIVE_CASE_COUNT',1;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<4
 BEGIN
  TRUNCATE TABLE #ExampleIqpEmptyConsole;
  SET @MaxRows=CASE WHEN @Empty=1 THEN -1 ELSE 0 END;
  SET @Names=CASE WHEN @Empty=2 THEN N'[ExampleInvalid' ELSE @MissingScope END;
  SET @High=CASE WHEN @Empty=3 THEN 0 ELSE 1 END;
  INSERT #ExampleIqpEmptyConsole EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@Names,@MaxZeilen=@MaxRows,@HighImpactConfirmed=@High,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleIqpEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleIqpEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.signals')<>N'[]' OR @@LOCK_TIMEOUT<>137
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE @Empty WHEN 0 THEN N'DATABASE_UNAVAILABLE' WHEN 3 THEN N'HIGH_IMPACT_CONFIRMATION_REQUIRED' ELSE N'INVALID_PARAMETER' END
    THROW 58115,N'IQP_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0,@GenerateJson bit;
 WHILE @Consumer<3
 BEGIN
  SET @Mode=CASE @Consumer WHEN 0 THEN 'NONE' ELSE 'RAW' END;
  SET @MaxRows=CASE WHEN @Consumer<2 THEN -1 ELSE 0 END;SET @GenerateJson=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;SET @Json=N'ExamplePreviousJson';
  EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@MissingScope,@MaxZeilen=@MaxRows,@HighImpactConfirmed=1,
   @ResultSetArt=@Mode,@JsonErzeugen=@GenerateJson,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
  IF (@Consumer<2 AND (@Json IS NULL OR ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.signals')<>N'[]'
    OR @OutStatus<>'INVALID_PARAMETER' OR @OutPartial<>1)) OR (@Consumer=2 AND (@Json IS NOT NULL OR @OutStatus<>'DATABASE_UNAVAILABLE' OR @OutPartial<>1)) OR @@LOCK_TIMEOUT<>137
    THROW 58116,N'IQP_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleIqpPreflight"}'
   WHEN 2 THEN N'{"signals":"#ExampleMissingTarget179"}' WHEN 3 THEN N'{"signals":"ExamplePermanent"}'
   WHEN 4 THEN N'{"signals":"#ExampleIqpPreflight","unknown":"#ExampleIqpPreflight"}' ELSE N'{"signals":"#ExampleIqpPreflight"}' END;
  SET @Caught=0;SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
  BEGIN TRY EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=@MissingScope,@HighImpactConfirmed=1,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleIqpPreflight'))<>1 THROW 58117,N'IQP_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>14 OR @ConsumerCases<>3 OR @PreflightCases<>6 OR @EmptyConsoleCases<>4 THROW 58118,N'IQP_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,
  (SELECT [Level] FROM #ExampleIqpOptions WHERE DatabaseName=@UpperName) AS UpperSourceCompatibilityLevel,
  (SELECT [Level] FROM #ExampleIqpOptions WHERE DatabaseName=@LowerName) AS LowerSourceCompatibilityLevel,
  @CoreCases AS CoreCases,@ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@FixtureStatus AS PositiveFixtureStatus,
  @NativeCases AS NativeCases,@EmptyConsoleCases AS EmptySqlConsoleCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
