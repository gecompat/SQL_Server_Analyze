USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Literalvertrag fuer Sessions12/4Texte und Governance21/5Texte;
Dateien10/3Texte bleiben RAW/JSON/CONSOLE, ohne neuen TABLE-Namen.
Alle TABLE-/JSON-Felder werden gleichaufrufbezogen inklusive NULL,
JSON-Typen, doppelten Schluesseln und BIN2-Haeufigkeiten verglichen.
Optionaler Context ExampleCurrentTempDBFixtureIds: drei eigene resting
Verbindungen mit abgeschlossenen TempDB-Allokationen. Kein Workload,
keine Konfigurationsaenderung und kein Parent-Snapshotowner im Test.
Ohne geeigneten Context ist der positive Zusatz NOT_EXECUTED.
Native Sessionwerte und eindeutige gerundete Rangwerte muessen im kontrollierten Fixturefenster stabil bleiben.
Governance-Konfiguration wird nativ gegengeprueft; aktuelle/Peak-Nutzung
und davon abhaengige Prozentwerte sind keine atomare Cross-call-Evidenz.
Governance: elf native stabile Felder; Dateien: sieben native stabile Felder,
drei wechselnde Spacewerte nur voller JSON-/Typvertrag. Root prueft sie separat.
RAW/positive CONSOLE pruefen hier JSON; Clientzeilen sind Rootnachweis.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 59200,N'TEMPDB_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS' THROW 59201,N'TEMPDB_FRAMEWORK_COLLATION',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=32767) THROW 59202,N'TEMPDB_EMPTY_SCOPE_GUARD',1;
IF OBJECT_ID(N'tempdb..#ExampleMissingTarget189') IS NOT NULL THROW 59202,N'TEMPDB_FOREIGN_TARGET',1;
DECLARE @OriginalTimeout int=@@LOCK_TIMEOUT,@Json nvarchar(max),@TableJson nvarchar(max),@Sql nvarchar(max),@Case int,
 @Ids nvarchar(max),@Max int,@Min decimal(19,2),@Own bit,@System bit,@Files bit,@Native bit,@Map nvarchar(max),@Mask int,
 @Core int=0,@NativeCount int=0,@Consumer int=0,@Preflight int=0,@Rejected int=0,@EmptyConsole int=0,@DirectConsole int=0,@NullMutations int=0,
 @FixtureStatus varchar(24)='NOT_EXECUTED',@GovernanceFieldsChecked int=0,@Rows int,@Total int,@Limit bigint,@Expected nvarchar(max),@Before nvarchar(max),@After nvarchar(max);
CREATE TABLE #ExampleCurrentTempDBSessionSchema
(
          [SessionId] smallint NOT NULL
        , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserObjectsAllocatedMb] decimal(19,2) NOT NULL
        , [UserObjectsDeallocatedMb] decimal(19,2) NOT NULL
        , [UserObjectsNetMb] decimal(19,2) NOT NULL
        , [InternalObjectsAllocatedMb] decimal(19,2) NOT NULL
        , [InternalObjectsDeallocatedMb] decimal(19,2) NOT NULL
        , [InternalObjectsNetMb] decimal(19,2) NOT NULL
        , [TotalNetMb] decimal(19,2) NOT NULL
    );
CREATE TABLE #ExampleCurrentTempDBGovernanceSchema
(
          [GroupId] int NULL
        , [GroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PoolId] int NULL
        , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ConfiguredGroupMaxTempdbDataMb] decimal(19,2) NULL
        , [ConfiguredGroupMaxTempdbDataPercent] decimal(9,4) NULL
        , [TempdbMaximumSizeMb] decimal(19,2) NULL
        , [EffectiveGroupMaxTempdbDataMb] decimal(19,2) NULL
        , [EffectiveLimitSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPercentLimitEffective] bit NULL
        , [TempdbDataSpaceMb] decimal(19,2) NULL
        , [PeakTempdbDataSpaceMb] decimal(19,2) NULL
        , [EffectiveLimitUtilizationPercent] decimal(9,2) NULL
        , [TotalTempdbDataLimitViolationCount] bigint NULL
        , [HasRecordedLimitViolation] bit NULL
        , [StatisticsStartTime] datetime NULL
        , [IsResourceGovernorEnabled] bit NULL
        , [ReconfigurationPending] bit NULL
        , [SourceStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
CREATE TABLE #ExampleCurrentTempDBFilesSchema
(
          [FileId] int NOT NULL
        , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SizeMb] decimal(19,2) NOT NULL
        , [UsedMb] decimal(19,2) NULL
        , [FreeMb] decimal(19,2) NULL
        , [UsedPercent] decimal(9,2) NULL
        , [GrowthMb] decimal(19,2) NULL
        , [IsPercentGrowth] bit NOT NULL
    );

SELECT TOP(0) * INTO #ExampleCurrentTempDBNative FROM #ExampleCurrentTempDBSessionSchema;
SELECT TOP(0) * INTO #ExampleCurrentTempDBAfter FROM #ExampleCurrentTempDBSessionSchema;
CREATE TABLE #ExampleCurrentTempDBIds(RoleOrdinal int NOT NULL PRIMARY KEY,SessionId smallint NOT NULL UNIQUE);
CREATE TABLE #ExampleCurrentTempDBCases(CaseNumber int NOT NULL PRIMARY KEY,Native bit NOT NULL,Ids nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 MaxRows int NULL,MinMb decimal(19,2) NULL,Own bit NULL,SystemSessions bit NULL,Files bit NULL,Mask int NOT NULL);
CREATE TABLE #ExampleCurrentTempDBExpectedFields(RowOrdinal int NOT NULL,FieldName nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 FieldValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,JsonType int NOT NULL);
CREATE TABLE #ExampleCurrentTempDBEmptyConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleCurrentTempDBPreflight(Dummy int NULL);
INSERT #ExampleCurrentTempDBCases VALUES
 (0,0,N'32767',NULL,0,0,0,0,3),(1,0,N'32767',0,0,0,0,0,3),(2,0,N'32767',1,0,0,0,0,3),(3,0,N'32767',2,0,0,0,0,3),
 (4,0,N'32767',2147483647,0,0,0,0,3),(5,0,N'32767',0,NULL,0,0,0,3),(6,0,N'32767',0,1000000,0,0,0,3),
 (7,0,N'32767',1,0,1,1,0,3),(8,0,N'32767',0,0,0,0,1,3),(9,0,N'32767',1,0,0,0,1,3),
 (10,0,N'32767',1,0,0,0,0,1),(11,0,N'32767',1,0,0,0,0,2);
DECLARE @Context nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentTempDBFixtureIds')),
 @ContextJson nvarchar(max)=NULL,@FixtureIds nvarchar(max),@Upper smallint,@Middle smallint,@Leaf smallint;
SET @ContextJson=N'['+REPLACE(@Context,N'|',N',')+N']';
IF @Context IS NOT NULL AND ISJSON(@ContextJson)=1 AND (SELECT COUNT(*) FROM OPENJSON(@ContextJson))=3
 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@ContextJson) WHERE type<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
 AND (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM OPENJSON(@ContextJson))=3
BEGIN
 INSERT #ExampleCurrentTempDBIds SELECT CONVERT(int,[key])+1,CONVERT(smallint,value) FROM OPENJSON(@ContextJson);
 SELECT @Upper=MAX(CASE RoleOrdinal WHEN 1 THEN SessionId END),@Middle=MAX(CASE RoleOrdinal WHEN 2 THEN SessionId END),@Leaf=MAX(CASE RoleOrdinal WHEN 3 THEN SessionId END) FROM #ExampleCurrentTempDBIds;
 IF (SELECT COUNT(*) FROM sys.dm_exec_sessions s JOIN #ExampleCurrentTempDBIds i ON i.SessionId=s.session_id
  WHERE s.is_user_process=1 AND s.status=N'sleeping' AND s.original_login_name COLLATE Latin1_General_100_BIN2=ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2
   AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
   AND s.program_name COLLATE Latin1_General_100_BIN2=CASE i.RoleOrdinal WHEN 1 THEN N'ExampleTempDBRootÄ🔬' WHEN 2 THEN N'ExampleTempDBMiddleä🔬' ELSE N'ExampleTempDBLeafÖ🔬' END COLLATE Latin1_General_100_BIN2)=3
  AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests r JOIN #ExampleCurrentTempDBIds i ON i.SessionId=r.session_id)
 BEGIN
  SET @Sql=N'USE tempdb;SELECT @good=COUNT(*) FROM sys.dm_db_session_space_usage u JOIN #ExampleCurrentTempDBIds i ON i.SessionId=u.session_id
   WHERE u.user_objects_alloc_page_count-u.user_objects_dealloc_page_count+u.internal_objects_alloc_page_count-u.internal_objects_dealloc_page_count>0;
   SELECT @distinct=COUNT(DISTINCT CONVERT(decimal(19,2),(u.user_objects_alloc_page_count-u.user_objects_dealloc_page_count+u.internal_objects_alloc_page_count-u.internal_objects_dealloc_page_count)*8.0/1024.0)) FROM sys.dm_db_session_space_usage u JOIN #ExampleCurrentTempDBIds i ON i.SessionId=u.session_id;';
  DECLARE @Good int=0,@Distinct int=0;EXEC sys.sp_executesql @Sql,N'@good int OUTPUT,@distinct int OUTPUT',@good=@Good OUTPUT,@distinct=@Distinct OUTPUT;
  IF @Good=3 AND @Distinct=3 AND TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17
  BEGIN
   SET @FixtureStatus='PASS';SET @FixtureIds=@Context;
   INSERT #ExampleCurrentTempDBCases VALUES
    (20,1,@FixtureIds,NULL,0,0,0,0,3),(21,1,@FixtureIds,0,0,0,0,0,3),(22,1,@FixtureIds,1,0,0,0,0,3),(23,1,@FixtureIds,2,0,0,0,0,3),
    (24,1,CONVERT(nvarchar(10),@Upper),1,0,0,0,0,3),(25,1,CONVERT(nvarchar(10),@Middle),1,0,0,0,0,3),(26,1,CONVERT(nvarchar(10),@Leaf),1,0,0,0,0,3),
    (27,1,@FixtureIds,0,1000000,0,0,0,3),(28,1,@FixtureIds,0,NULL,0,0,0,3),(29,1,@FixtureIds,0,0,1,1,0,3),
    (30,1,CONCAT(@Leaf,N'|',@Middle,N'|',@Upper),2,0,0,0,0,3),(31,1,@FixtureIds,2,0,0,0,1,3),
    (32,1,@FixtureIds,1,0,0,0,0,1),(33,1,@FixtureIds,1,0,0,0,0,2);
  END;
 END;
END;
DECLARE @NativeSql nvarchar(max)=N'USE tempdb;
 INSERT #ExampleCurrentTempDBNative SELECT u.session_id,s.login_name,s.host_name,s.program_name,s.status,
  CONVERT(decimal(19,2),u.user_objects_alloc_page_count*8.0/1024.0),CONVERT(decimal(19,2),u.user_objects_dealloc_page_count*8.0/1024.0),
  CONVERT(decimal(19,2),(u.user_objects_alloc_page_count-u.user_objects_dealloc_page_count)*8.0/1024.0),
  CONVERT(decimal(19,2),u.internal_objects_alloc_page_count*8.0/1024.0),CONVERT(decimal(19,2),u.internal_objects_dealloc_page_count*8.0/1024.0),
  CONVERT(decimal(19,2),(u.internal_objects_alloc_page_count-u.internal_objects_dealloc_page_count)*8.0/1024.0),
  CONVERT(decimal(19,2),(u.user_objects_alloc_page_count-u.user_objects_dealloc_page_count+u.internal_objects_alloc_page_count-u.internal_objects_dealloc_page_count)*8.0/1024.0)
 FROM sys.dm_db_session_space_usage u LEFT JOIN sys.dm_exec_sessions s ON s.session_id=u.session_id
 WHERE u.session_id IN(SELECT TRY_CONVERT(smallint,value) FROM OPENJSON(@ids)) AND (@own=1 OR u.session_id<>@@SPID)
  AND (@system=1 OR COALESCE(s.is_user_process,1)=1)
  AND (u.user_objects_alloc_page_count-u.user_objects_dealloc_page_count+u.internal_objects_alloc_page_count-u.internal_objects_dealloc_page_count)*8.0/1024.0>=@min;';
BEGIN TRY
 SET LOCK_TIMEOUT 731;SET @Case=-1;
 WHILE 1=1
 BEGIN
  SELECT @Case=MIN(CaseNumber) FROM #ExampleCurrentTempDBCases WHERE CaseNumber>@Case;IF @Case IS NULL BREAK;
  SELECT @Native=Native,@Ids=Ids,@Max=MaxRows,@Min=MinMb,@Own=Own,@System=SystemSessions,@Files=Files,@Mask=Mask FROM #ExampleCurrentTempDBCases WHERE CaseNumber=@Case;
  DELETE #ExampleCurrentTempDBNative;DELETE #ExampleCurrentTempDBAfter;DELETE #ExampleCurrentTempDBExpectedFields;
  DECLARE @NativeIds nvarchar(max)=N'['+REPLACE(@Ids,N'|',N',')+N']';
  IF @Native=1
  BEGIN
   EXEC sys.sp_executesql @NativeSql,N'@ids nvarchar(max),@own bit,@system bit,@min decimal(19,2)',@ids=@NativeIds,@own=@Own,@system=@System,@min=@Min;
   SELECT @Total=COUNT(*) FROM #ExampleCurrentTempDBNative;
   IF @Min=0 AND @Total<1 THROW 59203,N'TEMPDB_FIXTURE_DISAPPEARED',1;
  END;
  CREATE TABLE #ExampleCurrentTempDBSessionTarget(Dummy int NULL);
  CREATE TABLE #ExampleCurrentTempDBGovernanceTarget(Dummy int NULL);
  SET @Map=CASE @Mask WHEN 1 THEN N'{"sessions":"#ExampleCurrentTempDBSessionTarget"}' WHEN 2 THEN N'{"tempdbGovernance":"#ExampleCurrentTempDBGovernanceTarget"}'
   ELSE N'{"sessions":"#ExampleCurrentTempDBSessionTarget","tempdbGovernance":"#ExampleCurrentTempDBGovernanceTarget"}' END;
  IF @Mask=1 INSERT #ExampleCurrentTempDBGovernanceTarget VALUES(4242);
  IF @Mask=2 INSERT #ExampleCurrentTempDBSessionTarget VALUES(4242);
  EXEC monitor.USP_CurrentTempDB @SessionIds=@Ids,@AktuelleSessionEinbeziehen=@Own,@MinNettoMb=@Min,@SystemSessionsEinbeziehen=@System,@MitDateien=@Files,
   @MaxZeilen=@Max,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>731 THROW 59204,N'TEMPDB_CALLER_TIMEOUT',1;
  IF @Native=1
  BEGIN
   INSERT #ExampleCurrentTempDBAfter SELECT * FROM #ExampleCurrentTempDBNative;DELETE #ExampleCurrentTempDBNative;
   EXEC sys.sp_executesql @NativeSql,N'@ids nvarchar(max),@own bit,@system bit,@min decimal(19,2)',@ids=@NativeIds,@own=@Own,@system=@System,@min=@Min;
   SELECT @Before=(SELECT * FROM #ExampleCurrentTempDBAfter ORDER BY SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   SELECT @After=(SELECT * FROM #ExampleCurrentTempDBNative ORDER BY SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF COALESCE(@Before,N'[]') COLLATE Latin1_General_100_BIN2<>COALESCE(@After,N'[]') COLLATE Latin1_General_100_BIN2 THROW 59205,N'TEMPDB_NATIVE_SESSION_DRIFT',1;
  END;
  IF ISNULL(ISJSON(@Json),0)<>1 OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'AVAILABLE' THROW 59206,N'TEMPDB_STATUS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>5 OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,type FROM OPENJSON(@Json) EXCEPT SELECT k,type FROM(VALUES(N'meta',5),(N'sessions',4),(N'tempdbFiles',4),(N'tempdbGovernance',4),(N'warnings',4)) v(k,type)) THROW 59207,N'TEMPDB_TOP_KEYS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>11 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.meta') EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'evidenceSnapshotStartedAtUtc'),(N'evidenceSnapshotId'),(N'statusCode'),(N'isPartial'),(N'productMajorVersion'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows')) v(k))
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>3 OR ISNULL(JSON_VALUE(@Json,'$.meta.resultName'),'')<>N'CurrentTempDB'
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2,JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL OR TRY_CONVERT(datetime2,JSON_VALUE(@Json,'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   THROW 59208,N'TEMPDB_META',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE type<>CASE WHEN [key] IN('schemaVersion','productMajorVersion','returnedRows') THEN 2 WHEN [key] IN('isPartial','hasMoreRows') THEN 3 WHEN [key]='requestedMaxRows' THEN CASE WHEN @Max IS NULL THEN 0 ELSE 2 END ELSE 1 END)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE [key]='requestedMaxRows' AND ((type=0 AND @Max IS NULL) OR (type=2 AND TRY_CONVERT(int,value)=@Max)))
   OR ISNULL(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>'false' THROW 59208,N'TEMPDB_META_TYPES',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>3
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'StatusCode'),(N'ErrorNumber'),(N'ErrorMessage')) v(k))) THROW 59209,N'TEMPDB_WARNINGS',1;
  DECLARE @K int=0,@Target sysname,@Template sysname,@Path nvarchar(40);
  WHILE @K<2
  BEGIN
   SET @Target=CASE @K WHEN 0 THEN N'#ExampleCurrentTempDBSessionTarget' ELSE N'#ExampleCurrentTempDBGovernanceTarget' END;
   SET @Template=CASE @K WHEN 0 THEN N'#ExampleCurrentTempDBSessionSchema' ELSE N'#ExampleCurrentTempDBGovernanceSchema' END;
   SET @Path=CASE @K WHEN 0 THEN N'$.sessions' ELSE N'$.tempdbGovernance' END;
   IF (@K=0 AND @Mask IN(1,3)) OR (@K=1 AND @Mask IN(2,3))
   BEGIN
    IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Template))
     OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Template)
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)) THROW 59210,N'TEMPDB_TABLE_SCHEMA',1;
    SET @Sql=N'SELECT @j=(SELECT * FROM '+QUOTENAME(@Target)+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
    IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,@Path) GROUP BY value COLLATE Latin1_General_100_BIN2)
     OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,@Path) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 59211,N'TEMPDB_SAME_CALL_PARITY',1;
   END
   ELSE
   BEGIN
    IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target))<>1 THROW 59212,N'TEMPDB_UNMAPPED_SCHEMA',1;
    SET @Sql=N'IF NOT EXISTS(SELECT 1 FROM '+QUOTENAME(@Target)+N' WHERE Dummy=4242) THROW 59212,N''TEMPDB_UNMAPPED_SENTINEL'',1;';EXEC sys.sp_executesql @Sql;
   END;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>CASE @K WHEN 0 THEN 12 ELSE 21 END
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Template))) THROW 59213,N'TEMPDB_FULL_FIELDS',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a CROSS APPLY OPENJSON(a.value) b JOIN tempdb.sys.columns c
    ON c.object_id=OBJECT_ID(N'tempdb..'+@Template) AND c.name COLLATE Latin1_General_100_BIN2=b.[key] COLLATE Latin1_General_100_BIN2
    WHERE (b.type=0 AND c.is_nullable=0) OR (b.type<>0 AND b.type<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(167,231) OR c.system_type_id=61 THEN 1 ELSE 2 END)) THROW 59213,N'TEMPDB_JSON_TYPES',1;
   SET @K+=1;
  END;
  SET @Rows=(SELECT COUNT(*) FROM OPENJSON(@Json,'$.sessions'));SET @Limit=CASE WHEN @Max IS NULL OR @Max=0 THEN 9223372036854775807 ELSE @Max END;
  IF @Rows>@Limit OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.tempdbGovernance'))>@Limit OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.returnedRows')),-1)<>@Rows THROW 59214,N'TEMPDB_CAP_AND_COUNT',1;
  IF @Native=0 AND (@Rows<>0 OR ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'')<>'false') THROW 59214,N'TEMPDB_EMPTY_SCOPE',1;
  IF @Native=1
  BEGIN
   IF @Rows<>CASE WHEN @Total>@Limit THEN @Limit ELSE @Total END OR ISNULL(JSON_VALUE(@Json,'$.meta.hasMoreRows'),'')<>CASE WHEN @Total>@Limit THEN 'true' ELSE 'false' END THROW 59215,N'TEMPDB_NATIVE_COUNT',1;
   SELECT @Expected=(SELECT TOP(@Limit) * FROM #ExampleCurrentTempDBNative ORDER BY TotalNetMb DESC,SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF COALESCE(@Expected,N'[]') COLLATE Latin1_General_100_BIN2<>COALESCE(JSON_QUERY(@Json,'$.sessions'),N'[]') COLLATE Latin1_General_100_BIN2 THROW 59216,N'TEMPDB_NATIVE_FULL_SESSION',1;
   DECLARE @GovExpected nvarchar(max);
   SET @Sql=N'SELECT @e=(SELECT TOP(@limit)
    g.group_id AS GroupId,g.name AS GroupName,g.pool_id AS PoolId,p.name AS PoolName,
    CONVERT(decimal(19,2),g.group_max_tempdb_data_mb) AS ConfiguredGroupMaxTempdbDataMb,
    CONVERT(decimal(9,4),g.group_max_tempdb_data_percent) AS ConfiguredGroupMaxTempdbDataPercent,
    d.statistics_start_time AS StatisticsStartTime,c.is_enabled AS IsResourceGovernorEnabled,CONVERT(bit,e.reconfiguration_pending) AS ReconfigurationPending,
    CONVERT(bigint,d.total_tempdb_data_limit_violation_count) AS TotalTempdbDataLimitViolationCount,
    CONVERT(bit,CASE WHEN d.total_tempdb_data_limit_violation_count IS NULL THEN NULL WHEN d.total_tempdb_data_limit_violation_count>0 THEN 1 ELSE 0 END) AS HasRecordedLimitViolation
    FROM sys.resource_governor_workload_groups g JOIN sys.dm_resource_governor_workload_groups d ON d.group_id=g.group_id
    LEFT JOIN sys.dm_resource_governor_resource_pools p ON p.pool_id=g.pool_id
    CROSS JOIN sys.resource_governor_configuration c CROSS JOIN
     (SELECT is_reconfiguration_pending AS reconfiguration_pending FROM sys.dm_resource_governor_configuration) e
    ORDER BY g.group_id FOR JSON PATH,INCLUDE_NULL_VALUES);';
   EXEC sys.sp_executesql @Sql,N'@e nvarchar(max) OUTPUT,@limit bigint',@e=@GovExpected OUTPUT,@limit=@Limit;
   IF (SELECT COUNT(*) FROM OPENJSON(COALESCE(@GovExpected,N'[]')))<>(SELECT COUNT(*) FROM OPENJSON(@Json,'$.tempdbGovernance')) THROW 59216,N'TEMPDB_NATIVE_GOVERNANCE_COUNT',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@GovExpected) e CROSS APPLY OPENJSON(e.value) ef
    LEFT JOIN OPENJSON(@Json,'$.tempdbGovernance') a ON TRY_CONVERT(int,JSON_VALUE(a.value,'$.GroupId'))=TRY_CONVERT(int,JSON_VALUE(e.value,'$.GroupId'))
    OUTER APPLY(SELECT value,type FROM OPENJSON(a.value) WHERE [key] COLLATE Latin1_General_100_BIN2=ef.[key] COLLATE Latin1_General_100_BIN2) af
    WHERE a.value IS NULL OR af.type IS NULL OR af.type<>ef.type OR (af.value IS NULL AND ef.value IS NOT NULL) OR (af.value IS NOT NULL AND ef.value IS NULL)
     OR af.value COLLATE Latin1_General_100_BIN2<>ef.value COLLATE Latin1_General_100_BIN2) THROW 59216,N'TEMPDB_NATIVE_GOVERNANCE_FIELDS',1;
   SET @GovernanceFieldsChecked=11;
   IF @Case=20
   BEGIN
    INSERT #ExampleCurrentTempDBExpectedFields SELECT CONVERT(int,a.[key]),b.[key],b.value,b.type FROM OPENJSON(@Expected) a CROSS APPLY OPENJSON(a.value) b;
    DECLARE @F sysname,@Bad nvarchar(max);
    DECLARE fields CURSOR LOCAL FAST_FORWARD FOR SELECT FieldName FROM #ExampleCurrentTempDBExpectedFields WHERE RowOrdinal=0 AND JsonType<>0;
    OPEN fields;FETCH NEXT FROM fields INTO @F;
    WHILE @@FETCH_STATUS=0
    BEGIN
     SET @Bad=JSON_MODIFY(@Expected,N'strict $[0].'+@F,NULL);
     IF NOT EXISTS(SELECT 1 FROM #ExampleCurrentTempDBExpectedFields e JOIN OPENJSON(@Bad) a ON CONVERT(int,a.[key])=e.RowOrdinal CROSS APPLY OPENJSON(a.value) b
      WHERE b.[key] COLLATE Latin1_General_100_BIN2=e.FieldName AND (b.type<>e.JsonType OR (b.value IS NULL AND e.FieldValue IS NOT NULL) OR (b.value IS NOT NULL AND e.FieldValue IS NULL) OR b.value COLLATE Latin1_General_100_BIN2<>e.FieldValue)) THROW 59217,N'TEMPDB_NULL_MUTATION_ACCEPTED',1;
     SET @NullMutations+=1;FETCH NEXT FROM fields INTO @F;
    END;
    CLOSE fields;DEALLOCATE fields;
   END;
   SET @NativeCount+=1;
  END ELSE SET @Core+=1;
  IF @Files=0 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.tempdbFiles'))<>0 THROW 59218,N'TEMPDB_FILES_DISABLED',1;
  IF @Files=1
  BEGIN
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.tempdbFiles') a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>10 OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTempDBFilesSchema'))) THROW 59218,N'TEMPDB_FILES_FIELDS',1;
   DECLARE @FileExpected nvarchar(max);
   SET @Sql=N'USE tempdb;SELECT @e=(SELECT file_id AS FileId,name AS LogicalName,physical_name AS PhysicalName,type_desc AS FileTypeDesc,
    CONVERT(decimal(19,2),CONVERT(bigint,size)*8.0/1024.0) AS SizeMb,
    CONVERT(decimal(19,2),CASE WHEN is_percent_growth=0 THEN CONVERT(bigint,growth)*8.0/1024.0 END) AS GrowthMb,is_percent_growth AS IsPercentGrowth
    FROM sys.database_files ORDER BY file_id FOR JSON PATH,INCLUDE_NULL_VALUES);';
   EXEC sys.sp_executesql @Sql,N'@e nvarchar(max) OUTPUT',@e=@FileExpected OUTPUT;
   IF (SELECT COUNT(*) FROM OPENJSON(@FileExpected))<>(SELECT COUNT(*) FROM OPENJSON(@Json,'$.tempdbFiles')) THROW 59218,N'TEMPDB_FILES_NATIVE_COUNT',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@FileExpected) e CROSS APPLY OPENJSON(e.value) ef LEFT JOIN OPENJSON(@Json,'$.tempdbFiles') a
    ON TRY_CONVERT(int,JSON_VALUE(a.value,'$.FileId'))=TRY_CONVERT(int,JSON_VALUE(e.value,'$.FileId'))
    OUTER APPLY(SELECT value,type FROM OPENJSON(a.value) WHERE [key] COLLATE Latin1_General_100_BIN2=ef.[key] COLLATE Latin1_General_100_BIN2) af
    WHERE a.value IS NULL OR af.type IS NULL OR af.type<>ef.type OR (af.value IS NULL AND ef.value IS NOT NULL) OR (af.value IS NOT NULL AND ef.value IS NULL)
     OR af.value COLLATE Latin1_General_100_BIN2<>ef.value COLLATE Latin1_General_100_BIN2) THROW 59218,N'TEMPDB_FILES_NATIVE_FIELDS',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.tempdbFiles') a CROSS APPLY OPENJSON(a.value) b JOIN tempdb.sys.columns c
    ON c.object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTempDBFilesSchema') AND c.name COLLATE Latin1_General_100_BIN2=b.[key] COLLATE Latin1_General_100_BIN2
    WHERE (b.type=0 AND c.is_nullable=0) OR (b.type<>0 AND b.type<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(167,231) THEN 1 ELSE 2 END)) THROW 59218,N'TEMPDB_FILES_TYPES',1;
  END;
  DROP TABLE #ExampleCurrentTempDBSessionTarget;DROP TABLE #ExampleCurrentTempDBGovernanceTarget;
 END;

 DECLARE @C int=0,@Mode varchar(16),@Parent uniqueidentifier=NULL,@Caught bit;
 WHILE @C<4
 BEGIN
  SET @Mode=CASE @C WHEN 0 THEN 'RAW' ELSE 'NONE' END;SET @Parent=CASE @C WHEN 2 THEN NEWID() ELSE NULL END;SET @Json=N'ExampleOldValue';
  EXEC monitor.USP_CurrentTempDB @SessionIds=N'32767',@MitDateien=0,@MaxZeilen=1,@ResultSetArt=@Mode,
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ParentCurrentStateSnapshotId=@Parent;
  IF @@LOCK_TIMEOUT<>731 OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>CASE @C WHEN 2 THEN 'INVALID_PARENT_SNAPSHOT' ELSE 'AVAILABLE' END
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.sessions'))<>0 THROW 59219,N'TEMPDB_CONSUMER',1;
  IF @C=2 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') WHERE JSON_VALUE(value,'$.StatusCode')='INVALID_PARENT_SNAPSHOT' AND JSON_VALUE(value,'$.ErrorNumber')='208') THROW 59219,N'TEMPDB_MISSING_PARENT',1;
  IF @C=3
  BEGIN
   EXEC monitor.USP_CurrentTempDB @SessionIds=N'32767',@MitDateien=0,@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF @Json IS NOT NULL THROW 59219,N'TEMPDB_JSON_RESET',1;
  END;
  SET @Consumer+=1;SET @C+=1;
 END;
 SET @C=0;
 WHILE @C<6
 BEGIN
  SET @Map=CASE @C WHEN 0 THEN N'[]' WHEN 1 THEN N'{}' WHEN 2 THEN N'{"ExampleUnknown":"#ExampleCurrentTempDBPreflight"}'
   WHEN 3 THEN N'{"sessions":"##ExampleForbidden189"}' WHEN 4 THEN N'{"sessions":"#ExampleMissingTarget189"}'
   ELSE N'{"sessions":"#ExampleCurrentTempDBPreflight"}' END;SET @Caught=0;
  IF @C=5 INSERT #ExampleCurrentTempDBPreflight VALUES(4242);
  BEGIN TRY
   EXEC monitor.USP_CurrentTempDB @SessionIds=N'32767',@MitDateien=0,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   IF ERROR_NUMBER()<>51011 THROW;
   SET @Caught=1;
  END CATCH;
  IF @Caught=0 OR @@LOCK_TIMEOUT<>731 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentTempDBPreflight'))<>1
   OR (@C=5 AND NOT EXISTS(SELECT 1 FROM #ExampleCurrentTempDBPreflight WHERE Dummy=4242)) THROW 59220,N'TEMPDB_PREFLIGHT',1;
  DELETE #ExampleCurrentTempDBPreflight;SET @Preflight+=1;SET @C+=1;
 END;
 SET @C=0;
 WHILE @C<10
 BEGIN
  SET @Caught=0;SET @Json=N'ExampleOldValue';SET @Ids=CASE @C WHEN 0 THEN N'ExampleInvalid' WHEN 1 THEN N'32768' WHEN 2 THEN N'-1' WHEN 3 THEN N'32767|32767' ELSE N'32767' END;
  SET @Min=CASE WHEN @C=4 THEN -1 ELSE 0 END;SET @Max=CASE WHEN @C=5 THEN -1 ELSE 1 END;
  SET @Own=CASE WHEN @C=6 THEN NULL ELSE 0 END;SET @System=CASE WHEN @C=7 THEN NULL ELSE 0 END;SET @Files=CASE WHEN @C=8 THEN NULL ELSE 0 END;
  SET @Mode=CASE WHEN @C=9 THEN 'ExampleInvalid' ELSE 'NONE' END;
  BEGIN TRY
   EXEC monitor.USP_CurrentTempDB @SessionIds=@Ids,@MinNettoMb=@Min,@MaxZeilen=@Max,@AktuelleSessionEinbeziehen=@Own,@SystemSessionsEinbeziehen=@System,@MitDateien=@Files,
    @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   IF ERROR_NUMBER()<>51011 THROW;
   SET @Caught=1;
  END CATCH;
  IF @Caught=0 OR @@LOCK_TIMEOUT<>731 OR @Json<>N'ExampleOldValue' OR @Json IS NULL THROW 59221,N'TEMPDB_EXISTING_REJECTION',1;
  SET @Rejected+=1;SET @C+=1;
 END;
 SET @C=0;
 WHILE @C<3
 BEGIN
  DELETE #ExampleCurrentTempDBEmptyConsole;SET @Parent=NEWID();
  INSERT #ExampleCurrentTempDBEmptyConsole EXEC monitor.USP_CurrentTempDB @SessionIds=N'32767',@MitDateien=0,@MaxZeilen=@C,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ParentCurrentStateSnapshotId=@Parent;
  IF (SELECT COUNT(*) FROM #ExampleCurrentTempDBEmptyConsole)<>2
   OR NOT EXISTS(SELECT 1 FROM #ExampleCurrentTempDBEmptyConsole WHERE Ergebnis=N'Keine aktive TempDB-Nutzung' AND Status IS NULL AND Hinweis IS NULL)
   OR NOT EXISTS(SELECT 1 FROM #ExampleCurrentTempDBEmptyConsole WHERE Ergebnis=N'Keine TempDB-Governance-Evidenz' AND Status IS NULL AND Hinweis IS NULL)
   OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'INVALID_PARENT_SNAPSHOT' OR @@LOCK_TIMEOUT<>731 THROW 59222,N'TEMPDB_EMPTY_CONSOLE',1;
  SET @EmptyConsole+=1;SET @C+=1;
 END;
 IF @FixtureStatus='PASS'
 BEGIN
  SET @C=0;
  WHILE @C<3
  BEGIN
   SET @Max=CASE @C WHEN 0 THEN 0 ELSE @C END;
   EXEC monitor.USP_CurrentTempDB @SessionIds=@FixtureIds,@MitDateien=0,@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'AVAILABLE' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.sessions'))<>CASE @Max WHEN 0 THEN 3 ELSE @Max END
    OR @Max>0 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.tempdbGovernance'))>@Max OR @@LOCK_TIMEOUT<>731 THROW 59223,N'TEMPDB_DIRECT_CONSOLE',1;
   SET @DirectConsole+=1;SET @C+=1;
  END;
 END;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @Sql;
 DROP TABLE #ExampleCurrentTempDBSessionSchema;DROP TABLE #ExampleCurrentTempDBGovernanceSchema;DROP TABLE #ExampleCurrentTempDBFilesSchema;
 DROP TABLE #ExampleCurrentTempDBNative;DROP TABLE #ExampleCurrentTempDBAfter;DROP TABLE #ExampleCurrentTempDBIds;
 DROP TABLE #ExampleCurrentTempDBCases;DROP TABLE #ExampleCurrentTempDBExpectedFields;DROP TABLE #ExampleCurrentTempDBEmptyConsole;DROP TABLE #ExampleCurrentTempDBPreflight;
 SELECT N'PASS' AS ContractStatus,@Level AS FrameworkLevel,@Core AS CoreCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCount AS NativeCases,
  @Consumer AS ConsumerCases,@Preflight AS PreflightCases,@Rejected AS RejectionCases,@EmptyConsole AS EmptyConsoleCases,@DirectConsole AS DirectConsoleCases,
  @NullMutations AS NullMutationRejections,12 AS SessionFields,21 AS GovernanceFields,9 AS TableTextCollations,10 AS FileFields,@GovernanceFieldsChecked AS IndependentNativeGovernanceFields;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @Sql;
 DROP TABLE IF EXISTS #ExampleCurrentTempDBSessionTarget;DROP TABLE IF EXISTS #ExampleCurrentTempDBGovernanceTarget;
 DROP TABLE IF EXISTS #ExampleCurrentTempDBSessionSchema;DROP TABLE IF EXISTS #ExampleCurrentTempDBGovernanceSchema;DROP TABLE IF EXISTS #ExampleCurrentTempDBFilesSchema;
 DROP TABLE IF EXISTS #ExampleCurrentTempDBNative;DROP TABLE IF EXISTS #ExampleCurrentTempDBAfter;DROP TABLE IF EXISTS #ExampleCurrentTempDBIds;
 DROP TABLE IF EXISTS #ExampleCurrentTempDBCases;DROP TABLE IF EXISTS #ExampleCurrentTempDBExpectedFields;DROP TABLE IF EXISTS #ExampleCurrentTempDBEmptyConsole;DROP TABLE IF EXISTS #ExampleCurrentTempDBPreflight;
 THROW;
END CATCH;
GO
