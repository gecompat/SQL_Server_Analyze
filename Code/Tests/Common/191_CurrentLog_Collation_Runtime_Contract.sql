USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Literalvertrag logs19/acht Frameworktexte/sechs NOT NULL/keine Identity.
TABLE-/JSON-Paritaet gilt fuer denselben Aufruf, inklusive NULL und JSON-Typen.
Die optionalen Contexts CurrentLogFixtureUpper/CurrentLogFixtureLower benennen
zwei eigene CI_AS-Quellen auf CL170, ADR aus/an; der Test fuehrt keinen Workload
und keine Datenbank-/Konfigurationsmutation aus. Ohne geeignete Fixture bleibt
der positive Zusatz NOT_EXECUTED. Native Log-/PVS-Zahlen werden vor/nach gemessen;
Text-/Datumswerte muessen einer der beobachteten Grenzen entsprechen. Das ist
keine atomare Cross-call-Vollparitaet. Die Rangmenge muss vor/nach stabil bleiben.
VLF- und PVS-Nativfaelle werden getrennt ausgewiesen; fehlende Detailfreigabe
ist NOT_EXECUTED, kein positiver Detailnachweis. RAW und positive CONSOLE pruefen
hier Status/JSON; die tatsaechlichen Clientgrids sind ein separater Nachweis.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 59400,N'LOG_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS' THROW 59400,N'LOG_FRAMEWORK_COLLATION',1;
DECLARE @Missing sysname=N'ExampleMissingLogDb191Ä🔬',@MissingScope nvarchar(258);
SET @MissingScope=QUOTENAME(@Missing);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@Missing COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 59400,N'LOG_MISSING_SCOPE_GUARD',1;
DECLARE @OriginalTimeout int=@@LOCK_TIMEOUT,@Json nvarchar(max),@TableJson nvarchar(max),@Sql nvarchar(max),@Case int=-1,
 @Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@Min decimal(5,2),@Vlf bit,@Pvs bit,@System bit,@High bit,@Help bit,@Generate bit,
 @Mode varchar(16),@Mask int,@Native bit,@ExpectedStatus varchar(40),@ExpectedPartial bit,@Warnings int,
 @Rows int,@Total int,@Limit bigint,@BeforeUtc datetime2(3),@AfterUtc datetime2(3),@ExpectedJson nvarchar(max),@AfterJson nvarchar(max),
 @Core int=0,@NativeCases int=0,@Consumer int=0,@Preflight int=0,@EmptyConsole int=0,@DirectConsole int=0,@NullMutations int=0,
 @FixtureStatus varchar(24)='NOT_EXECUTED',@VlfStatus varchar(24)='NOT_EXECUTED',@PvsStatus varchar(24)='NOT_EXECUTED',
 @Upper sysname=TRY_CONVERT(sysname,SESSION_CONTEXT(N'CurrentLogFixtureUpper')),
 @Lower sysname=TRY_CONVERT(sysname,SESSION_CONTEXT(N'CurrentLogFixtureLower')),
 @UpperId int,@LowerId int,@AllNames nvarchar(max),@VlfAllowed bit=0,@DefaultAllowed bit=0;
CREATE TABLE #ExampleLogSchema
(
 [DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RecoveryModel] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LogReuseWaitDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [TotalLogSizeMb] decimal(19,2) NULL,
 [UsedLogSizeMb] decimal(19,2) NULL,
 [UsedLogPercent] decimal(19,4) NULL,
 [LogSinceLastBackupMb] decimal(19,2) NULL,
 [ActiveVlfCount] bigint NULL,
 [TotalVlfCount] bigint NULL,
 [LogTruncationHoldupReason] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LogBackupTime] datetime NULL,
 [LogRecoverySizeMb] decimal(19,2) NULL,
 [IsAdrEnabled] bit NULL,
 [PersistentVersionStoreMb] decimal(19,2) NULL,
 [SpaceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [StatsStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [VlfStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [PvsStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

SELECT TOP(0) * INTO #ExampleLogBefore FROM #ExampleLogSchema;
SELECT TOP(0) * INTO #ExampleLogAfter FROM #ExampleLogSchema;
CREATE TABLE #ExampleLogFixture(RoleOrdinal int NOT NULL PRIMARY KEY,DatabaseId int NOT NULL UNIQUE,DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleLogCases(CaseNumber int NOT NULL PRIMARY KEY,Native bit NOT NULL,Names nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Pattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,MaxRows int NULL,MinPercent decimal(5,2) NULL,Vlf bit NULL,Pvs bit NULL,SystemDb bit NULL,High bit NULL,
 Mode varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,Help bit NOT NULL,Generate bit NULL,Mask int NOT NULL,
 ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,ExpectedPartial bit NULL,Warnings int NOT NULL);
CREATE TABLE #ExampleLogNativeFields(DatabaseId int NOT NULL,Measurement int NOT NULL,FieldName nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,FieldValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,JsonType int NOT NULL);
CREATE TABLE #ExampleLogActualFields(DatabaseId int NOT NULL,FieldName nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,FieldValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,JsonType int NOT NULL);
CREATE TABLE #ExampleLogEmpty(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleLogPreflight(Dummy int NULL);
-- Core uses an independently absent exact identifier, never N'' as an empty scope.
INSERT #ExampleLogCases
 SELECT r.n*4+m.n,0,QUOTENAME(@Missing),NULL,r.cap,NULL,0,0,0,0,m.mode,0,1,0,
 CASE WHEN r.cap<0 THEN 'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,CASE WHEN r.cap<0 THEN 0 ELSE 1 END,CASE WHEN r.cap<0 THEN 0 ELSE 1 END
 FROM(VALUES(0,CONVERT(int,NULL)),(1,0),(2,1),(3,2),(4,2147483647),(5,-1))r(n,cap)
 CROSS JOIN(VALUES(0,'TABLE'),(1,'NONE'),(2,'RAW'),(3,'CONSOLE'))m(n,mode);
INSERT #ExampleLogCases VALUES
 (24,0,QUOTENAME(@Missing),NULL,1,-.01,0,0,0,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (25,0,QUOTENAME(@Missing),NULL,1,100.01,0,0,0,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (26,0,QUOTENAME(@Missing),NULL,1,NULL,0,0,0,0,'UNSUPPORTED',0,1,0,'INVALID_PARAMETER',0,0),
 (27,0,N'[ExampleUnclosed',NULL,1,NULL,0,0,0,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (28,0,CONCAT(QUOTENAME(@Missing),N'|',QUOTENAME(@Missing)),NULL,1,NULL,0,0,0,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (29,0,QUOTENAME(@Missing),N'like:Example%',1,NULL,0,0,0,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (30,0,QUOTENAME(@Missing),NULL,1,NULL,0,0,NULL,0,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (31,0,QUOTENAME(@Missing),NULL,1,NULL,0,0,0,NULL,'TABLE',0,1,0,'INVALID_PARAMETER',0,0),
 (32,0,QUOTENAME(@Missing),NULL,1,NULL,NULL,0,0,0,'TABLE',0,1,0,'ERROR_HANDLED',1,1),
 (33,0,QUOTENAME(@Missing),NULL,1,NULL,0,NULL,0,0,'TABLE',0,1,0,'ERROR_HANDLED',1,1),
 (34,0,QUOTENAME(@Missing),NULL,1,NULL,0,0,0,0,'TABLE',0,NULL,0,NULL,NULL,1),
 (35,0,QUOTENAME(@Missing),NULL,1,NULL,0,0,0,0,'TABLE',1,1,0,NULL,NULL,0);
IF @Upper COLLATE Latin1_General_100_BIN2=N'ExampleLogÄ''🔬' COLLATE Latin1_General_100_BIN2
 AND @Lower COLLATE Latin1_General_100_BIN2=N'ExampleLogä''🔬' COLLATE Latin1_General_100_BIN2
 AND TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17 AND @Level=170
 AND NOT EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=REPLACE(@Upper,N'Example',N'example') COLLATE SQL_Latin1_General_CP1_CS_AS)
BEGIN
 INSERT #ExampleLogFixture SELECT x.RoleOrdinal,d.database_id,d.name FROM(VALUES(1,@Upper),(2,@Lower))x(RoleOrdinal,Name)
 JOIN master.sys.databases d ON d.name COLLATE SQL_Latin1_General_CP1_CS_AS=x.Name COLLATE SQL_Latin1_General_CP1_CS_AS
 WHERE d.database_id>4 AND d.state=0 AND d.source_database_id IS NULL AND HAS_DBACCESS(d.name)=1 AND d.compatibility_level=170
  AND d.collation_name COLLATE Latin1_General_100_BIN2=N'Latin1_General_100_CI_AS' COLLATE Latin1_General_100_BIN2
  AND d.is_accelerated_database_recovery_on=CASE x.RoleOrdinal WHEN 1 THEN 0 ELSE 1 END;
 IF (SELECT COUNT(*) FROM #ExampleLogFixture)=2 AND HAS_PERMS_BY_NAME(NULL,NULL,N'VIEW SERVER PERFORMANCE STATE')=1
 BEGIN
  SELECT @UpperId=MAX(CASE RoleOrdinal WHEN 1 THEN DatabaseId END),@LowerId=MAX(CASE RoleOrdinal WHEN 2 THEN DatabaseId END) FROM #ExampleLogFixture;
  SET @AllNames=CONCAT(QUOTENAME(@Upper),N'|',QUOTENAME(@Lower));SET @FixtureStatus='READY';
  SELECT @VlfAllowed=CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM monitor.VW_AnalyseAccessCurrent WHERE AnalysisClass='LOG_VLF_DEEP' AND IsAllowed=1) THEN 1 ELSE 0 END);
  SET @DefaultAllowed=CONVERT(bit,CASE WHEN (SELECT COUNT(*) FROM master.sys.databases WHERE database_id>4 AND state=0 AND source_database_id IS NULL AND HAS_DBACCESS(name)=1)=3 THEN 1 ELSE 0 END);
  IF @DefaultAllowed=1 INSERT #ExampleLogFixture SELECT 3,DB_ID(),DB_NAME();
  INSERT #ExampleLogCases
   SELECT 100+r.n*4+m.n,1,@AllNames,NULL,r.cap,NULL,0,0,0,1,m.mode,0,1,3,'AVAILABLE',0,0
   FROM(VALUES(0,CONVERT(int,NULL)),(1,0),(2,1),(3,2),(4,2147483647))r(n,cap)
   CROSS JOIN(VALUES(0,'TABLE'),(1,'NONE'),(2,'RAW'),(3,'CONSOLE'))m(n,mode);
  INSERT #ExampleLogCases VALUES
   (120,1,QUOTENAME(@Upper),NULL,0,NULL,0,0,0,1,'TABLE',0,1,1,'AVAILABLE',0,0),
   (121,1,QUOTENAME(@Lower),NULL,0,NULL,0,0,0,1,'TABLE',0,1,2,'AVAILABLE',0,0),
   (122,1,CONCAT(QUOTENAME(@Lower),N'|',QUOTENAME(@Upper)),NULL,1,NULL,0,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (123,1,NULL,N'like:'+@Upper,0,NULL,0,0,0,1,'TABLE',0,1,1,'AVAILABLE',0,0),
   (124,1,NULL,N'regex:^'+@Upper+N'$',0,NULL,0,0,0,1,'TABLE',0,1,1,'AVAILABLE',0,0),
   (125,1,NULL,N'regexi:^'+@Upper+N'$',0,NULL,0,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (126,1,QUOTENAME(REPLACE(@Upper,N'Example',N'example')),NULL,0,NULL,0,0,0,1,'TABLE',0,1,0,'ERROR_HANDLED',1,1),
   (127,1,CONCAT(QUOTENAME(@Upper),N'|',QUOTENAME(@Missing)),NULL,1,NULL,0,0,0,1,'TABLE',0,1,1,'PARTIAL_RESULT',1,1),
   (128,1,@AllNames,NULL,0,0,0,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (129,1,@AllNames,NULL,0,100,0,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (130,1,@AllNames,NULL,0,NULL,NULL,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (131,1,@AllNames,NULL,0,NULL,0,NULL,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (132,1,@AllNames,NULL,0,NULL,0,1,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (133,1,@AllNames,NULL,0,NULL,1,0,0,0,'TABLE',0,1,3,'HIGH_IMPACT_CONFIRMATION_REQUIRED',1,0),
   (138,1,@AllNames,NULL,1,10,0,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0),
   (139,1,CONCAT(@AllNames,N'|',QUOTENAME(@Missing)),NULL,1,NULL,0,0,0,1,'TABLE',0,1,3,'PARTIAL_RESULT',1,1),
   (140,1,CONCAT(QUOTENAME(@Upper),N'|',QUOTENAME(@Upper)),NULL,1,NULL,0,0,0,1,'TABLE',0,1,0,'INVALID_PARAMETER',0,0);
  IF @VlfAllowed=1 INSERT #ExampleLogCases VALUES(134,1,@AllNames,NULL,1,NULL,1,0,0,1,'TABLE',0,1,3,'AVAILABLE',0,0);
  IF @DefaultAllowed=1 INSERT #ExampleLogCases VALUES
   (135,1,NULL,NULL,0,NULL,0,0,0,1,'TABLE',0,1,7,'AVAILABLE',0,0),
   (136,1,N'',NULL,0,NULL,0,0,0,1,'TABLE',0,1,7,'AVAILABLE',0,0),
   (137,1,N'   ',NULL,0,NULL,0,0,0,1,'TABLE',0,1,7,'AVAILABLE',0,0);
 END;
END;
DECLARE @NativeSelect nvarchar(max)=N'USE '+N'__EXAMPLE_LOG_DATABASE_191__'+N';
 DECLARE @NativePvs decimal(19,2)=NULL,@NativeVlf bigint=NULL;
 IF @pvs=1 AND EXISTS(SELECT 1 FROM master.sys.databases WHERE database_id=DB_ID() AND is_accelerated_database_recovery_on=1)
  SELECT @NativePvs=CONVERT(decimal(19,2),COALESCE(SUM(persistent_version_store_size_kb),0)/1024.0) FROM sys.dm_tran_persistent_version_store_stats WHERE database_id=DB_ID();
 IF @vlf=1 SELECT @NativeVlf=COUNT_BIG(*) FROM sys.dm_db_log_info(DB_ID());
 INSERT '+N'__EXAMPLE_LOG_TARGET_191__'+N'
 SELECT d.database_id,d.name,d.recovery_model_desc,d.log_reuse_wait_desc,
  CONVERT(decimal(19,2),x.total_log_size_in_bytes/1048576.0),CONVERT(decimal(19,2),x.used_log_space_in_bytes/1048576.0),
  CONVERT(decimal(19,4),x.used_log_space_in_percent),CONVERT(decimal(19,2),x.log_space_in_bytes_since_last_backup/1048576.0),
  y.active_vlf_count,COALESCE(y.total_vlf_count,@NativeVlf),y.log_truncation_holdup_reason,y.log_backup_time,CONVERT(decimal(19,2),y.log_recovery_size_mb),
  d.is_accelerated_database_recovery_on,@NativePvs,''AVAILABLE'',''AVAILABLE'',CASE WHEN @vlf=1 THEN ''AVAILABLE'' ELSE ''SKIPPED'' END,
  CASE WHEN @pvs IS NULL THEN ''PENDING'' WHEN @pvs=0 THEN ''SKIPPED'' WHEN d.is_accelerated_database_recovery_on=0 THEN ''NOT_APPLICABLE'' ELSE ''AVAILABLE'' END
 FROM master.sys.databases d CROSS JOIN sys.dm_db_log_space_usage x CROSS APPLY sys.dm_db_log_stats(DB_ID())y WHERE d.database_id=DB_ID();';
DECLARE @NativePredicate nvarchar(max)=N'SELECT @bad=CONVERT(bit,CASE WHEN EXISTS
 (SELECT 1 FROM #ExampleLogActualFields a
 LEFT JOIN #ExampleLogNativeFields b ON b.DatabaseId=a.DatabaseId AND b.FieldName=a.FieldName AND b.Measurement=0
 LEFT JOIN #ExampleLogNativeFields c ON c.DatabaseId=a.DatabaseId AND c.FieldName=a.FieldName AND c.Measurement=1
 WHERE b.FieldName IS NULL OR c.FieldName IS NULL
 OR (a.JsonType<>b.JsonType AND a.JsonType<>c.JsonType)
 OR (a.JsonType=0 AND b.JsonType<>0 AND c.JsonType<>0)
 OR (a.JsonType<>0 AND b.JsonType=0 AND c.JsonType=0)
 OR (a.JsonType=2 AND b.JsonType=2 AND c.JsonType=2 AND
  (TRY_CONVERT(decimal(38,6),a.FieldValue) IS NULL OR TRY_CONVERT(decimal(38,6),b.FieldValue) IS NULL OR TRY_CONVERT(decimal(38,6),c.FieldValue) IS NULL
   OR TRY_CONVERT(decimal(38,6),a.FieldValue)<CASE WHEN TRY_CONVERT(decimal(38,6),b.FieldValue)<TRY_CONVERT(decimal(38,6),c.FieldValue) THEN TRY_CONVERT(decimal(38,6),b.FieldValue) ELSE TRY_CONVERT(decimal(38,6),c.FieldValue) END
   OR TRY_CONVERT(decimal(38,6),a.FieldValue)>CASE WHEN TRY_CONVERT(decimal(38,6),b.FieldValue)>TRY_CONVERT(decimal(38,6),c.FieldValue) THEN TRY_CONVERT(decimal(38,6),b.FieldValue) ELSE TRY_CONVERT(decimal(38,6),c.FieldValue) END))
 OR (a.JsonType<>0 AND NOT(a.JsonType=2 AND b.JsonType=2 AND c.JsonType=2)
  AND NOT((a.JsonType=b.JsonType AND a.FieldValue=b.FieldValue) OR (a.JsonType=c.JsonType AND a.FieldValue=c.FieldValue)))
 ) THEN 1 ELSE 0 END);';
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 WHILE 1=1
 BEGIN
  SELECT @Case=MIN(CaseNumber) FROM #ExampleLogCases WHERE CaseNumber>@Case;IF @Case IS NULL BREAK;
  SELECT @Native=Native,@Names=Names,@Pattern=Pattern,@Max=MaxRows,@Min=MinPercent,@Vlf=Vlf,@Pvs=Pvs,@System=SystemDb,@High=High,@Mode=Mode,@Help=Help,@Generate=Generate,@Mask=Mask,@ExpectedStatus=ExpectedStatus,@ExpectedPartial=ExpectedPartial,@Warnings=Warnings FROM #ExampleLogCases WHERE CaseNumber=@Case;
  DELETE #ExampleLogBefore;DELETE #ExampleLogAfter;DELETE #ExampleLogNativeFields;DELETE #ExampleLogActualFields;DELETE #ExampleLogEmpty;
  SET @Limit=CASE WHEN @Max IS NULL OR @Max=0 THEN 9223372036854775807 WHEN @Max<0 THEN 0 ELSE @Max END;
  DECLARE @Measurement int=0,@Role int,@Db sysname,@Target sysname,@MeasureVlf bit;
  SET @MeasureVlf=CASE WHEN @High=1 THEN @Vlf ELSE 0 END;
  SET @BeforeUtc=SYSUTCDATETIME();
  IF @Native=1
  BEGIN
   SET @Role=0;
   WHILE 1=1
   BEGIN
    SELECT @Role=MIN(RoleOrdinal) FROM #ExampleLogFixture WHERE RoleOrdinal>@Role AND (@Mask & CASE RoleOrdinal WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 4 END)>0;
    IF @Role IS NULL BREAK;SELECT @Db=DatabaseName FROM #ExampleLogFixture WHERE RoleOrdinal=@Role;
    SET @Sql=REPLACE(REPLACE(@NativeSelect,N'__EXAMPLE_LOG_DATABASE_191__',QUOTENAME(@Db)),N'__EXAMPLE_LOG_TARGET_191__',N'#ExampleLogBefore');
    EXEC sys.sp_executesql @Sql,N'@vlf bit,@pvs bit',@vlf=@MeasureVlf,@pvs=@Pvs;
   END;
   IF (SELECT COUNT(*) FROM #ExampleLogBefore)<>(SELECT COUNT(*) FROM #ExampleLogFixture WHERE (@Mask & CASE RoleOrdinal WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 4 END)>0) THROW 59401,N'LOG_FIXTURE_NATIVE_ROWS',1;
   IF EXISTS(SELECT 1 FROM #ExampleLogBefore WHERE UsedLogPercent IS NULL OR UsedLogPercent<0 OR UsedLogPercent>=100 OR TotalLogSizeMb IS NULL OR UsedLogSizeMb IS NULL) THROW 59401,N'LOG_FIXTURE_NATIVE_PERCENT',1;
  END;
  CREATE TABLE #ExampleLogTarget(Dummy int NULL);
  SET @Json=N'ExampleSentinel';
  IF @Mode='CONSOLE' AND @Native=0
   INSERT #ExampleLogEmpty EXEC monitor.USP_CurrentLog @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@SystemdatenbankenEinbeziehen=@System,@HighImpactConfirmed=@High,@MinUsedPercent=@Min,@MitVlfInformationen=@Vlf,@MitPersistentVersionStore=@Pvs,@MaxZeilen=@Max,@ResultSetArt=@Mode,@JsonErzeugen=@Generate,@Json=@Json OUTPUT,@Hilfe=@Help,@PrintMeldungen=0;
  ELSE
  BEGIN
   DECLARE @Map nvarchar(max)=CASE WHEN @Mode='TABLE' THEN N'{"logs":"#ExampleLogTarget"}' ELSE NULL END;
   EXEC monitor.USP_CurrentLog @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@SystemdatenbankenEinbeziehen=@System,@HighImpactConfirmed=@High,@MinUsedPercent=@Min,@MitVlfInformationen=@Vlf,@MitPersistentVersionStore=@Pvs,@MaxZeilen=@Max,@ResultSetArt=@Mode,@ResultTablesJson=@Map,@JsonErzeugen=@Generate,@Json=@Json OUTPUT,@Hilfe=@Help,@PrintMeldungen=0;
  END;
  SET @AfterUtc=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 59402,N'LOG_CALLER_TIMEOUT',1;
  IF @Help=1 OR @Generate IS NULL
  BEGIN
   IF @Json IS NOT NULL THROW 59403,N'LOG_JSON_RESET',1;
   IF @Help=1 AND ((SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogTarget'))<>1 OR EXISTS(SELECT 1 FROM #ExampleLogTarget)) THROW 59403,N'LOG_HELP_TARGET',1;
   IF @Generate IS NULL
   BEGIN
    IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogTarget'))<>19 THROW 59403,N'LOG_JSON_NULL_SCHEMA',1;
   END;
   SET @Core+=1;DROP TABLE #ExampleLogTarget;CONTINUE;
  END;
  IF ISNULL(ISJSON(@Json),0)<>1 THROW 59404,N'LOG_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>4 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,type FROM OPENJSON(@Json) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2,t FROM(VALUES(N'meta',5),(N'logs',4),(N'databaseStatus',4),(N'warnings',4))v(k,t)) THROW 59405,N'LOG_TOP_KEYS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>13 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.meta') GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.meta') EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),(N'requestedMaxRows'),(N'returnedRows'),(N'resultLimited'),(N'hasMoreRows'),(N'requiredPermission'),(N'errorNumber'),(N'errorMessage'),(N'detail'))v(k))
   OR ISNULL(JSON_VALUE(@Json,'$.meta.resultName'),'')<>N'CurrentLog' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>1
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) NOT BETWEEN @BeforeUtc AND @AfterUtc
   OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@ExpectedStatus OR ISNULL(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>CASE WHEN @ExpectedPartial=1 THEN 'true' ELSE 'false' END
   OR ISNULL(JSON_VALUE(@Json,'$.meta.resultLimited'),'')<>ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'?') THROW 59406,N'LOG_META',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE type<>CASE WHEN [key] IN('resultName','generatedAtUtc','statusCode','requiredPermission') THEN 1 WHEN [key]='schemaVersion' OR [key]='returnedRows' THEN 2 WHEN [key] IN('isPartial','resultLimited','hasMoreRows') THEN 3 WHEN [key]='requestedMaxRows' THEN CASE WHEN @Max IS NULL THEN 0 ELSE 2 END WHEN value IS NULL THEN 0 ELSE CASE WHEN [key]='errorNumber' THEN 2 ELSE 1 END END)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE [key]='requestedMaxRows' AND ((type=0 AND @Max IS NULL) OR (type=2 AND TRY_CONVERT(int,value)=@Max))) THROW 59406,N'LOG_META_TYPES',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.warnings'))<>@Warnings OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>3
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,type FROM OPENJSON(a.value) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2,1 FROM(VALUES(N'databaseName'),(N'code'),(N'message'))v(k))) THROW 59407,N'LOG_WARNINGS',1;
  IF @Warnings=1
  BEGIN
   DECLARE @WarningName sysname=CASE WHEN @Case=126 THEN REPLACE(@Upper,N'Example',N'example') ELSE @Missing END;
   IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')a WHERE JSON_VALUE(a.value,'$.databaseName') COLLATE Latin1_General_100_BIN2=@WarningName COLLATE Latin1_General_100_BIN2
    AND JSON_VALUE(a.value,'$.code')=N'DATABASE_UNAVAILABLE' AND JSON_VALUE(a.value,'$.message')=N'Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.') THROW 59407,N'LOG_WARNING_VALUE',1;
  END;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseStatus')a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>5
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'DatabaseName'),(N'SubModule'),(N'StatusCode'),(N'ErrorNumber'),(N'ErrorMessage'))v(k))) THROW 59408,N'LOG_DATABASE_STATUS',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseStatus')) THROW 59408,N'LOG_UNEXPECTED_SOURCE_ERROR',1;
  SELECT @Rows=COUNT(*) FROM OPENJSON(@Json,'$.logs');
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.logs')a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>19
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogSchema'))
   OR EXISTS(SELECT 1 FROM OPENJSON(a.value)f JOIN tempdb.sys.columns c ON c.object_id=OBJECT_ID(N'tempdb..#ExampleLogSchema') AND c.name COLLATE Latin1_General_100_BIN2=f.[key] COLLATE Latin1_General_100_BIN2
    WHERE (f.type=0 AND c.is_nullable=0) OR (f.type<>0 AND f.type<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(48,52,56,127,106) THEN 2 ELSE 1 END))) THROW 59409,N'LOG_FIELDS',1;
  IF ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.meta.returnedRows')),-1)<>@Rows THROW 59409,N'LOG_RETURNED_COUNT',1;
  IF @Mode='TABLE'
  BEGIN
   IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogTarget')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogSchema'))
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogSchema')
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogTarget')) THROW 59410,N'LOG_TABLE_FACETS',1;
   SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleLogTarget FOR JSON PATH,INCLUDE_NULL_VALUES);';EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.logs') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,'$.logs') GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 59411,N'LOG_TABLE_JSON_PARITY',1;
  END;
  IF @Native=0
  BEGIN
   IF @Rows<>0 OR JSON_VALUE(@Json,'$.meta.hasMoreRows')<>N'false' THROW 59412,N'LOG_EMPTY_SCOPE',1;
   SET @Core+=1;
   IF @Mode='CONSOLE'
   BEGIN
    IF (SELECT COUNT(*) FROM #ExampleLogEmpty)<>1 OR NOT EXISTS(SELECT 1 FROM #ExampleLogEmpty WHERE Ergebnis=N'Keine Protokollergebnisse' AND Status IS NULL AND Hinweis IS NULL) THROW 59412,N'LOG_EMPTY_CONSOLE',1;
    SET @EmptyConsole+=1;
   END;
  END
  ELSE
  BEGIN
   SET @Role=0;
   WHILE 1=1
   BEGIN
    SELECT @Role=MIN(RoleOrdinal) FROM #ExampleLogFixture WHERE RoleOrdinal>@Role AND (@Mask & CASE RoleOrdinal WHEN 1 THEN 1 WHEN 2 THEN 2 ELSE 4 END)>0;
    IF @Role IS NULL BREAK;SELECT @Db=DatabaseName FROM #ExampleLogFixture WHERE RoleOrdinal=@Role;
    SET @Sql=REPLACE(REPLACE(@NativeSelect,N'__EXAMPLE_LOG_DATABASE_191__',QUOTENAME(@Db)),N'__EXAMPLE_LOG_TARGET_191__',N'#ExampleLogAfter');
    EXEC sys.sp_executesql @Sql,N'@vlf bit,@pvs bit',@vlf=@MeasureVlf,@pvs=@Pvs;
   END;
   SELECT @Total=COUNT(*) FROM #ExampleLogBefore WHERE @Min IS NULL OR UsedLogPercent>=@Min;
   IF @ExpectedStatus='HIGH_IMPACT_CONFIRMATION_REQUIRED' SET @Total=0;
   IF @Rows<>CASE WHEN @Total>@Limit THEN @Limit ELSE @Total END OR ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'?')<>CASE WHEN @Total>@Limit THEN 'true' ELSE 'false' END THROW 59413,N'LOG_NATIVE_COUNT_LIMIT',1;
   IF @ExpectedStatus IN('AVAILABLE','PARTIAL_RESULT')
   BEGIN
    DECLARE @ExpectedDetail nvarchar(2000)=CONCAT(N'Datenbanken=',(SELECT COUNT(*) FROM #ExampleLogBefore),N'; Ergebniszeilen=',@Rows,N'; Fehler=0; nicht verfügbare explizite Datenbanken=',@Warnings,N'; VLF=',CASE WHEN @Vlf=0 THEN N'aus' WHEN @Vlf IS NULL THEN N'SKIPPED' ELSE N'AVAILABLE' END,N'.');
    IF ISNULL(JSON_VALUE(@Json,'$.meta.detail'),N'') COLLATE Latin1_General_100_BIN2<>@ExpectedDetail COLLATE Latin1_General_100_BIN2 THROW 59413,N'LOG_FULL_DETAIL_AFTER_LIMIT',1;
   END;
   SELECT @ExpectedJson=(SELECT TOP(@Limit) * FROM #ExampleLogBefore WHERE (@Min IS NULL OR UsedLogPercent>=@Min) AND @ExpectedStatus<>'HIGH_IMPACT_CONFIRMATION_REQUIRED' ORDER BY UsedLogPercent DESC,DatabaseName FOR JSON PATH,INCLUDE_NULL_VALUES);
   SELECT @AfterJson=(SELECT TOP(@Limit) * FROM #ExampleLogAfter WHERE (@Min IS NULL OR UsedLogPercent>=@Min) AND @ExpectedStatus<>'HIGH_IMPACT_CONFIRMATION_REQUIRED' ORDER BY UsedLogPercent DESC,DatabaseName FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) EXCEPT SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) FROM OPENJSON(COALESCE(@AfterJson,N'[]')))
    OR EXISTS(SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) FROM OPENJSON(COALESCE(@AfterJson,N'[]')) EXCEPT SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]'))) THROW 59414,N'LOG_NATIVE_RANK_DRIFT',1;
   IF EXISTS(SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')),COUNT(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) EXCEPT SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')),COUNT(*) FROM OPENJSON(@Json,'$.logs') GROUP BY TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')))
    OR EXISTS(SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')),COUNT(*) FROM OPENJSON(@Json,'$.logs') GROUP BY TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')) EXCEPT SELECT TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId')),COUNT(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY TRY_CONVERT(int,JSON_VALUE(value,'$.DatabaseId'))) THROW 59415,N'LOG_NATIVE_KEYS',1;
   INSERT #ExampleLogNativeFields SELECT TRY_CONVERT(int,JSON_VALUE(a.value,'$.DatabaseId')),0,f.[key],f.value,f.type FROM OPENJSON(COALESCE(@ExpectedJson,N'[]'))a CROSS APPLY OPENJSON(a.value)f;
   INSERT #ExampleLogNativeFields SELECT TRY_CONVERT(int,JSON_VALUE(a.value,'$.DatabaseId')),1,f.[key],f.value,f.type FROM OPENJSON(COALESCE(@AfterJson,N'[]'))a CROSS APPLY OPENJSON(a.value)f;
   INSERT #ExampleLogActualFields SELECT TRY_CONVERT(int,JSON_VALUE(a.value,'$.DatabaseId')),f.[key],f.value,f.type FROM OPENJSON(@Json,'$.logs')a CROSS APPLY OPENJSON(a.value)f;
   DECLARE @Bad bit;EXEC sys.sp_executesql @NativePredicate,N'@bad bit OUTPUT',@bad=@Bad OUTPUT;
   IF @Bad=1 THROW 59416,N'LOG_NATIVE_FIELD_BOUNDS',1;
   IF @Rows>0 AND @NullMutations=0
   BEGIN
    DECLARE @MutationField sysname,@MutationJson nvarchar(max),@MutationRow nvarchar(max)=(SELECT TOP(1)value FROM OPENJSON(@Json,'$.logs')),@MutationId int;
    SET @MutationId=TRY_CONVERT(int,JSON_VALUE(@MutationRow,'$.DatabaseId'));
    DECLARE MutationCursor CURSOR LOCAL FAST_FORWARD FOR SELECT n FROM(VALUES(N'DatabaseName'),(N'RecoveryModel'),(N'LogReuseWaitDesc'),(N'TotalLogSizeMb'),(N'UsedLogSizeMb'),(N'UsedLogPercent'))v(n);
    OPEN MutationCursor;FETCH NEXT FROM MutationCursor INTO @MutationField;
    WHILE @@FETCH_STATUS=0
    BEGIN
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@MutationRow) WHERE [key]=@MutationField COLLATE Latin1_General_100_BIN2 AND type<>0) THROW 59417,N'LOG_NULL_PROBE_EVIDENCE',1;
     SET @MutationJson=JSON_MODIFY(@MutationRow,N'strict $.'+@MutationField,NULL);
     DELETE #ExampleLogActualFields;INSERT #ExampleLogActualFields SELECT @MutationId,[key],value,type FROM OPENJSON(@MutationJson);
     EXEC sys.sp_executesql @NativePredicate,N'@bad bit OUTPUT',@bad=@Bad OUTPUT;
     IF @Bad<>1 THROW 59417,N'LOG_NULL_MUTATION_ACCEPTED',1;
     SET @NullMutations+=1;FETCH NEXT FROM MutationCursor INTO @MutationField;
    END;
    CLOSE MutationCursor;DEALLOCATE MutationCursor;
   END;
   IF @Case=132 SET @PvsStatus='PASS';IF @Case=134 SET @VlfStatus='PASS';
   IF @Mode='CONSOLE' SET @DirectConsole+=1;
   SET @NativeCases+=1;
  END;
  DROP TABLE #ExampleLogTarget;
 END;
 -- JSON bit0 and help reset independently, without assuming a data scope is empty.
 DECLARE @C int=0;
 WHILE @C<4
 BEGIN
  SET @Json=N'ExampleSentinel';
  DECLARE @ConsumerMode varchar(16)=CASE WHEN @C=3 THEN ' rAw ' WHEN @C=2 THEN ' nOnE ' ELSE 'NONE' END,
   @ConsumerGenerate bit=CASE @C WHEN 0 THEN 0 WHEN 1 THEN NULL ELSE 1 END;
  EXEC monitor.USP_CurrentLog @DatabaseNames=@MissingScope,@ResultSetArt=@ConsumerMode,@JsonErzeugen=@ConsumerGenerate,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>137 OR (@C<2 AND @Json IS NOT NULL) OR (@C>=2 AND (ISNULL(ISJSON(@Json),0)<>1 OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'ERROR_HANDLED' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.returnedRows')),-1)<>0)) THROW 59418,N'LOG_CONSUMER_RESET',1;
  SET @Consumer+=1;SET @C+=1;
 END;
 -- Early mapping validation preserves supplied seed schema/data and caller OUTPUT on THROW.
 DECLARE @MapCase int=0,@BadMap nvarchar(max),@Caught int;
 INSERT #ExampleLogPreflight VALUES(4242);
 WHILE @MapCase<6
 BEGIN
  SET @BadMap=CASE @MapCase WHEN 0 THEN N'{' WHEN 1 THEN N'{"unknown":"#ExampleLogPreflight"}' WHEN 2 THEN N'{"logs":"##ExampleForeign"}' WHEN 3 THEN N'{"logs":"#ExampleMissingLogTarget191"}' WHEN 4 THEN N'{"logs":"#ExampleLogPreflight","logs":"#ExampleLogPreflight"}' ELSE N'{}' END;
  SET @Caught=0;SET @Json=N'ExampleSentinel';
  BEGIN TRY
   EXEC monitor.USP_CurrentLog @DatabaseNames=@MissingScope,@MaxZeilen=-1,@ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR @Json<>N'ExampleSentinel' OR @@LOCK_TIMEOUT<>137 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleLogPreflight'))<>1 OR (SELECT COUNT(*) FROM #ExampleLogPreflight)<>1 OR NOT EXISTS(SELECT 1 FROM #ExampleLogPreflight WHERE Dummy=4242) THROW 59419,N'LOG_PREFLIGHT_PRIORITY_SEED',1;
  SET @Preflight+=1;SET @MapCase+=1;
 END;
 IF @FixtureStatus='READY' SET @FixtureStatus='PASS';
 DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @RestoreSql;
 SELECT ContractStatus='PASS',FrameworkCompatibilityLevel=@Level,CoreCases=@Core,PositiveFixtureStatus=@FixtureStatus,NativeCases=@NativeCases,NativeVlfStatus=@VlfStatus,NativePvsStatus=@PvsStatus,NativeFields=19,TextCollations=8,NotNullFields=6,NullMutations=@NullMutations,ConsumerCalls=@Consumer,PreflightCases=@Preflight,EmptySqlConsoleCalls=@EmptyConsole,DirectPositiveConsoleStatusCalls=@DirectConsole;
END TRY
BEGIN CATCH
 IF OBJECT_ID(N'tempdb..#ExampleLogTarget') IS NOT NULL DROP TABLE #ExampleLogTarget;
 DECLARE @CatchRestore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @CatchRestore;
 THROW;
END CATCH;
GO
