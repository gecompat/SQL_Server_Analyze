USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Literalvertrag für 33 Taskfelder/22 Texte und 23 Instanzfelder/elf Texte.
TABLE/JSON werden im selben Aufruf vollständig einschließlich NULLs, Typen
und Häufigkeiten verglichen. RAW/positive CONSOLE belegen hier Status/JSON;
ihre vollständigen Zeilen benötigen getrennte Clientcaptures.
Der optionale Context ExampleCurrentWaitsFixtureIds enthält Root|Middle|
NormalLeaf|ToolLeaf. Nur eigene identitätsgeprüfte Verbindungen, drei LCK_M_X-
Tasks und die eigene Toolregel werden gelesen. Keine Fixturemutation,
kein Workload und kein zusätzlicher Parent-Snapshotowner.
Fehlt die geeignete Fixture, bleibt nur der positive Block NOT_EXECUTED.
Native Taskidentitäten/Statementtexte werden exakt geprüft, Waitdauer bei
unverändertem Task vor/nach begrenzt. Kumulative Instanzzähler werden
unabhängig vor/nach begrenzt; Resourcezeit und Durchschnitte folgen den
Werten desselben Aufrufs. Der einzelne Lock-Waittyp erlaubt 100 Prozent;
kein atomarer Cross-call-Prozentvergleich mehrerer Waittypen wird behauptet.
Reset, echte Sampledeltas, denied/timeout und ältere Engines bleiben offen.
Vier Literaltextfälle belegen eine synthetische SC-Grenze, keinen Workload.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 58900,N'WAITS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS' THROW 58901,N'WAITS_FRAMEWORK_COLLATION',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=32767) THROW 58902,N'WAITS_EMPTY_SESSION_GUARD',1;
IF OBJECT_ID(N'tempdb..#ExampleMissingTarget187') IS NOT NULL THROW 58902,N'WAITS_FOREIGN_PREFLIGHT_TARGET',1;
DECLARE @OriginalTimeout int=@@LOCK_TIMEOUT,@Json nvarchar(max),@TableJson nvarchar(max),@Sql nvarchar(max),
 @Case int,@Native bit,@Ids nvarchar(max),@Max int,@Text int,@WithText bit,@Tools bit,@Min bigint,@Sample tinyint,
 @Percentage decimal(5,2),@Waits nvarchar(max),@WaitPattern nvarchar(4000),@Groups nvarchar(max),@GroupPattern nvarchar(4000),
 @Status varchar(40),@ExpectedRows int,@Core int=0,@NativeCount int=0,@Consumer int=0,@Preflight int=0,
 @EmptyConsole int=0,@DirectConsole int=0,@Unicode int=0,@NullMutations int=0,@FixtureStatus varchar(24)='NOT_EXECUTED';
CREATE TABLE #ExampleCurrentWaitsSchema
(
 [SessionId] smallint NULL,
 [ExecContextId] int NULL,
 [WaitDurationMs] bigint NULL,
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingSessionId] smallint NULL,
 [ResourceDescription] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsToolBackgroundQuery] bit NOT NULL,
 [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DatabaseId] smallint NULL,
 [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CurrentStatementCharacters] bigint NULL,
 [CurrentStatementBytes] bigint NULL,
 [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0),
 [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitSeverity] tinyint NULL,
 [IsGenerallyBenign] bit NULL,
 [WaitMeaning] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTypicalOccurrence] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HighWaitImpact] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RecommendedChecks] nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitHelpUrl] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DescriptionSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DescriptionQuality] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CatalogMatchType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleCurrentWaitsInstanceSchema
(
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [WaitingTasksCount] bigint NULL,
 [WaitTimeMs] bigint NULL,
 [SignalWaitTimeMs] bigint NULL,
 [ResourceWaitTimeMs] bigint NULL,
 [SampleSeconds] int NULL,
 [MeasurementType] varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [WaitGroup] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitSeverity] tinyint NULL,
 [IsGenerallyBenign] bit NULL,
 [WaitMeaning] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTypicalOccurrence] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HighWaitImpact] nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RecommendedChecks] nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitHelpUrl] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DescriptionSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DescriptionQuality] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CatalogMatchType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitPercentage] decimal(9,4) NULL,
 [CumulativePercentage] decimal(9,4) NULL,
 [AverageWaitMs] decimal(19,4) NULL,
 [AverageResourceWaitMs] decimal(19,4) NULL,
 [AverageSignalWaitMs] decimal(19,4) NULL
);
CREATE TABLE #ExampleCurrentWaitsEmptyConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleCurrentWaitsPreflight(Dummy int NULL);
CREATE TABLE #ExampleCurrentWaitsIds(RoleOrdinal int NOT NULL PRIMARY KEY,SessionId smallint NOT NULL UNIQUE);
CREATE TABLE #ExampleCurrentWaitsNative
(RoleOrdinal int NOT NULL,WaitingAddress varbinary(8) NOT NULL,LoginTime datetime NOT NULL,
 SessionId smallint NOT NULL,ExecContextId int NULL,WaitDurationMs bigint NOT NULL,
 WaitType nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,BlockingSessionId smallint NULL,
 ResourceDescription nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 SessionStatus nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,RequestStatus nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 LoginName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,HostName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 ProgramName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,DatabaseId smallint NULL,Command nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 StatementText nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleCurrentWaitsAfter FROM #ExampleCurrentWaitsNative;
CREATE TABLE #ExampleCurrentWaitsCounters(Phase int NOT NULL,WaitingTasksCount bigint NOT NULL,WaitTimeMs bigint NOT NULL,SignalWaitTimeMs bigint NOT NULL,StartTime datetime2 NOT NULL);
CREATE TABLE #ExampleCurrentWaitsExpectedFields(SessionId smallint NOT NULL,FieldName nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,FieldValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,JsonType int NOT NULL);
CREATE TABLE #ExampleCurrentWaitsCases(CaseNumber int NOT NULL PRIMARY KEY,Native bit NOT NULL,Ids nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 MaxRows int NULL,MaxText int NULL,WithText bit NULL,Tools bit NULL,MinWait bigint NULL,SampleSeconds tinyint NULL,Percentage decimal(5,2) NULL,
 Waits nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,WaitPattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Groups nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,GroupPattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExampleCurrentWaitsCases VALUES
 (0,0,N'32767',NULL,NULL,1,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE'),
 (1,0,N'32767',0,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE'),
 (2,0,N'32767',1,2,1,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE'),
 (3,0,N'32767',2,3,1,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE'),
 (4,0,N'32767',-1,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (5,0,N'32767',0,-1,1,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (6,0,N'32767',0,0,0,1,-1,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (7,0,N'32767',0,0,0,1,0,61,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (8,0,N'32767',0,0,0,1,0,0,0,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (9,0,N'32767',0,0,0,1,0,0,100.01,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (10,0,N'ExampleInvalid',0,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (11,0,N'32768',0,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (12,0,N'32767',0,0,0,1,0,0,100,N'ExampleMissingWait187',N'like:Example%',NULL,NULL,'INVALID_PARAMETER'),
 (13,0,N'32767',0,0,0,1,0,0,100,NULL,N'like:',NULL,NULL,'INVALID_PARAMETER'),
 (14,0,N'32767',0,0,0,NULL,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'INVALID_PARAMETER'),
 (15,0,N'32767',0,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,N'LOCKING',N'like:LOCK%','INVALID_PARAMETER'),
 (16,0,N'32767|32767',0,0,0,1,0,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE'),
 (17,0,N'32767',0,0,0,1,NULL,0,100,N'ExampleMissingWait187',NULL,NULL,NULL,'AVAILABLE');
CREATE TABLE #ExampleCurrentWaitsFixtureProbe(OwnObjects int NOT NULL);
DECLARE @FixtureDatabase sysname,@FixtureProbeSql nvarchar(max);
DECLARE @Context nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentWaitsFixtureIds')),
 @ContextJson nvarchar(max),@Root smallint,@Middle smallint,@Normal smallint,@Tool smallint,@FixtureIds nvarchar(max);
SET @ContextJson=N'['+REPLACE(@Context,N'|',N',')+N']';
IF @Context IS NOT NULL AND ISJSON(@ContextJson)=1 AND (SELECT COUNT(*) FROM OPENJSON(@ContextJson))=4
 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@ContextJson) WHERE [type]<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
 AND (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM OPENJSON(@ContextJson))=4
BEGIN
 INSERT #ExampleCurrentWaitsIds SELECT CONVERT(int,[key])+1,CONVERT(smallint,value) FROM OPENJSON(@ContextJson);
 SELECT @Root=MAX(CASE RoleOrdinal WHEN 1 THEN SessionId END),@Middle=MAX(CASE RoleOrdinal WHEN 2 THEN SessionId END),
  @Normal=MAX(CASE RoleOrdinal WHEN 3 THEN SessionId END),@Tool=MAX(CASE RoleOrdinal WHEN 4 THEN SessionId END) FROM #ExampleCurrentWaitsIds;
 IF (SELECT COUNT(DISTINCT database_id) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Normal,@Tool))=1
  SELECT @FixtureDatabase=DB_NAME(MAX(database_id)) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Normal,@Tool);
 IF @FixtureDatabase IS NOT NULL
 BEGIN
  SET @FixtureProbeSql=N'USE '+QUOTENAME(@FixtureDatabase)+N';INSERT #ExampleCurrentWaitsFixtureProbe SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
   WHERE s.name COLLATE Latin1_General_100_BIN2=N''dbo'' AND t.name COLLATE Latin1_General_100_BIN2 IN(N''ExampleWaitsSourceÄ🔬A'',N''ExampleWaitsSourceä🔬B'',N''ExampleWaitsSourceÖ🔬C'');';
  EXEC sys.sp_executesql @FixtureProbeSql;
 END;

 IF EXISTS(SELECT 1 FROM #ExampleCurrentWaitsFixtureProbe WHERE OwnObjects=3) AND (SELECT COUNT(*) FROM sys.dm_exec_sessions s JOIN #ExampleCurrentWaitsIds i ON s.session_id=i.SessionId
  WHERE s.is_user_process=1 AND s.original_login_name COLLATE Latin1_General_100_BIN2=ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2
   AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
   AND s.program_name COLLATE Latin1_General_100_BIN2=CASE i.RoleOrdinal WHEN 1 THEN N'ExampleWaitsToolRootÄ🔬' WHEN 2 THEN N'ExampleWaitsToolMiddleÄ🔬'
    WHEN 3 THEN N'ExampleWaitsLeafÄ🔬' ELSE N'ExampleWaitsToolLeafä🔬' END COLLATE Latin1_General_100_BIN2)=4
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=@Root AND status=N'sleeping' AND open_transaction_count>0)
  AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Root)
  AND (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@Normal,@Tool))=3
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Middle AND blocking_session_id=@Root AND wait_type=N'LCK_M_X')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Normal AND blocking_session_id=@Middle AND wait_type=N'LCK_M_X')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Tool AND blocking_session_id=@Middle AND wait_type=N'LCK_M_X')
  AND (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE session_id IN(@Middle,@Normal,@Tool))=3
  AND EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE RuleCode='EXAMPLE_WAITS_FIXTURE_187' AND Priority=32767 AND IsEnabled=1
   AND ProgramNameLikePattern=N'ExampleWaitsTool%' AND ToolBackgroundCategory='EXAMPLE_WAITS_TOOL'
   AND ToolBackgroundDetection='LOCAL_PROGRAM_NAME_PATTERN' AND ToolBackgroundConfidence='HIGH' AND IsFrameworkDefault=0)
  AND NOT EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE IsEnabled=1
   AND N'ExampleWaitsLeafÄ🔬' COLLATE Latin1_General_100_CI_AS LIKE ProgramNameLikePattern COLLATE Latin1_General_100_CI_AS)
  AND NOT EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE IsEnabled=1 AND Priority=32767 AND RuleCode<>'EXAMPLE_WAITS_FIXTURE_187'
   AND (N'ExampleWaitsToolMiddleÄ🔬' COLLATE Latin1_General_100_CI_AS LIKE ProgramNameLikePattern COLLATE Latin1_General_100_CI_AS
    OR N'ExampleWaitsToolLeafä🔬' COLLATE Latin1_General_100_CI_AS LIKE ProgramNameLikePattern COLLATE Latin1_General_100_CI_AS))
  AND EXISTS(SELECT 1 FROM sys.dm_os_wait_stats WHERE wait_type=N'LCK_M_X' AND waiting_tasks_count>0 AND wait_time_ms>0)
  AND EXISTS(SELECT 1 FROM monitor.WaitTypeCatalog WHERE WaitType=N'LCK_M_X' AND WaitGroup=N'LOCKING' AND HelpUrl IS NOT NULL AND DescriptionSource IS NOT NULL AND DescriptionQuality IS NOT NULL)
 BEGIN
  SET @FixtureStatus='PENDING';SET @FixtureIds=CONCAT(@Root,N'|',@Middle,N'|',@Normal,N'|',@Tool);
  INSERT #ExampleCurrentWaitsCases VALUES
   (20,1,@FixtureIds,NULL,NULL,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (21,1,@FixtureIds,0,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (22,1,@FixtureIds,1,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (23,1,@FixtureIds,2,33,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (24,1,@FixtureIds,0,34,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (25,1,@FixtureIds,2,34,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (26,1,@FixtureIds,0,0,0,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (27,1,@FixtureIds,0,0,0,0,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (28,1,CONVERT(nvarchar(20),@Normal),0,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (29,1,CONVERT(nvarchar(20),@Tool),0,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (30,1,CONCAT(@Normal,N'|',@Normal),0,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (31,1,@FixtureIds,0,0,0,1,0,0,100,N'lck_m_x',NULL,NULL,NULL,'AVAILABLE'),
   (32,1,@FixtureIds,0,0,1,1,0,0,100,N'LCK_M_X',NULL,N'[LOCKING]|[LOCKING]',NULL,'AVAILABLE'),
   (33,1,@FixtureIds,0,0,0,1,0,0,100,N'LCK_M_X',NULL,N'locking',NULL,'AVAILABLE'),
   (34,1,@FixtureIds,0,0,1,1,0,0,100,NULL,N'like:LCK[_]M[_]X',NULL,NULL,'AVAILABLE'),
   (35,1,@FixtureIds,0,0,0,1,0,0,100,NULL,N'like:lck[_]m[_]x',NULL,NULL,'AVAILABLE'),
   (36,1,@FixtureIds,0,0,0,1,9223372036854775807,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE'),
   (37,1,CONVERT(nvarchar(20),@Root),0,0,1,1,0,0,100,N'LCK_M_X',NULL,NULL,NULL,'AVAILABLE');
 END;
END;
DECLARE @LoadSql nvarchar(max)=N'INSERT #ExampleCurrentWaitsNative
 SELECT i.RoleOrdinal,w.waiting_task_address,s.login_time,w.session_id,w.exec_context_id,w.wait_duration_ms,w.wait_type,NULLIF(w.blocking_session_id,0),w.resource_description,
 s.status,r.status,s.login_name,s.host_name,s.program_name,r.database_id,r.command,
 CASE WHEN t.[text] IS NULL OR r.statement_start_offset IS NULL OR r.statement_start_offset<0 THEN NULL
 ELSE SUBSTRING(t.[text],r.statement_start_offset/2+1,(CASE WHEN r.statement_end_offset IS NULL OR r.statement_end_offset=-1 THEN DATALENGTH(t.[text]) ELSE r.statement_end_offset END-r.statement_start_offset)/2+1) END
 FROM #ExampleCurrentWaitsIds i JOIN sys.dm_os_waiting_tasks w ON w.session_id=i.SessionId
 JOIN sys.dm_exec_sessions s ON s.session_id=i.SessionId LEFT JOIN sys.dm_exec_requests r ON r.session_id=i.SessionId
 OUTER APPLY sys.dm_exec_sql_text(r.sql_handle)t WHERE i.RoleOrdinal>1;';
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE Cases187 CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleCurrentWaitsCases ORDER BY CaseNumber;
 OPEN Cases187;FETCH NEXT FROM Cases187 INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Tools,@Min,@Sample,@Percentage,@Waits,@WaitPattern,@Groups,@GroupPattern,@Status;
 WHILE @@FETCH_STATUS=0
 BEGIN
  TRUNCATE TABLE #ExampleCurrentWaitsNative;TRUNCATE TABLE #ExampleCurrentWaitsAfter;TRUNCATE TABLE #ExampleCurrentWaitsCounters;TRUNCATE TABLE #ExampleCurrentWaitsExpectedFields;
  IF @Native=1
  BEGIN
   EXEC sys.sp_executesql @LoadSql;
   IF (SELECT COUNT(*) FROM #ExampleCurrentWaitsNative)<>3 OR EXISTS(SELECT 1 FROM #ExampleCurrentWaitsNative WHERE WaitType<>N'LCK_M_X' OR WaitDurationMs<0
    OR BlockingSessionId<>CASE RoleOrdinal WHEN 2 THEN @Root ELSE @Middle END) THROW 58903,N'WAITS_NATIVE_TOPOLOGY',1;
   INSERT #ExampleCurrentWaitsCounters SELECT 0,waiting_tasks_count,wait_time_ms,signal_wait_time_ms,(SELECT sqlserver_start_time FROM sys.dm_os_sys_info) FROM sys.dm_os_wait_stats WHERE wait_type=N'LCK_M_X';
  END;
  CREATE TABLE #ExampleCurrentWaitsExport(Dummy int NULL);
  EXEC monitor.USP_CurrentWaits @SessionIds=@Ids,@MinWaitMs=@Min,@WaitTypes=@Waits,@WaitTypePattern=@WaitPattern,
   @WaitGroups=@Groups,@WaitGroupPattern=@GroupPattern,@ToolHintergrundabfragenEinbeziehen=@Tools,@MitSqlText=@WithText,
   @MaxSqlTextZeichen=@Text,@SampleSeconds=@Sample,@TopWaitPercentage=@Percentage,@MaxZeilen=@Max,
   @ResultSetArt='TABLE',@ResultTablesJson=N'{"currentTasks":"#ExampleCurrentWaitsExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>137 THROW 58904,N'WAITS_CALLER_TIMEOUT',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsSchema') EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsExport')) OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsExport') EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsSchema')) THROW 58905,N'WAITS_TABLE_SCHEMA',1;
  SET @TableJson=NULL;EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleCurrentWaitsExport FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;SET @TableJson=COALESCE(@TableJson,N'[]');
  IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>4 OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'meta'),(N'currentTasks'),(N'instanceWaits'),(N'warnings'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE [key] WHEN N'meta' THEN 5 ELSE 4 END) THROW 58906,N'WAITS_JSON_TOP',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>13 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta')m LEFT JOIN(VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'evidenceSnapshotStartedAtUtc',1),(N'evidenceSnapshotId',1),
    (N'measurementStartUtc',CASE WHEN @Status='AVAILABLE' THEN 1 ELSE 0 END),(N'measurementEndUtc',CASE WHEN @Status='AVAILABLE' THEN 1 ELSE 0 END),
    (N'statusCode',1),(N'isPartial',3),(N'measurementStatusCode',CASE WHEN @Sample IS NULL THEN 0 ELSE 1 END),(N'currentTaskRows',2),(N'instanceWaitRows',2),(N'toolBackgroundQueriesIncluded',CASE WHEN @Tools IS NULL THEN 0 ELSE 3 END))v(k,t)
    ON m.[key] COLLATE Latin1_General_100_BIN2=v.k COLLATE Latin1_General_100_BIN2 WHERE v.k IS NULL OR m.[type]<>v.t)
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'USP_CurrentWaits' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>3
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
   OR JSON_VALUE(@Json,N'$.meta.measurementStatusCode')<>CASE WHEN @Sample=0 THEN N'CUMULATIVE_CONTEXT' ELSE N'SKIPPED' END
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.currentTaskRows')),-1)<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.currentTasks'))
   OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.instanceWaitRows')),-1)<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.instanceWaits')) THROW 58907,N'WAITS_META',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.currentTasks') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.currentTasks') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 58908,N'WAITS_TABLE_JSON',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.currentTasks')a WHERE [type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>33
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsSchema')))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.currentTasks')a CROSS APPLY OPENJSON(a.value)p JOIN tempdb.sys.columns c
    ON c.object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsSchema') AND c.name COLLATE Latin1_General_100_BIN2=p.[key] COLLATE Latin1_General_100_BIN2
    WHERE (p.[type]=0 AND c.is_nullable=0) OR (p.[type]<>0 AND p.[type]<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(48,52,56,127,106) THEN 2 ELSE 1 END)) THROW 58909,N'WAITS_JSON_FIELDS',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.instanceWaits')a WHERE [type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>23
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsInstanceSchema')))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.instanceWaits')a CROSS APPLY OPENJSON(a.value)p JOIN tempdb.sys.columns c
    ON c.object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsInstanceSchema') AND c.name COLLATE Latin1_General_100_BIN2=p.[key] COLLATE Latin1_General_100_BIN2
    WHERE (p.[type]=0 AND c.is_nullable=0) OR (p.[type]<>0 AND p.[type]<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(48,52,56,127,106) THEN 2 ELSE 1 END)) THROW 58909,N'WAITS_JSON_FIELDS',1;
  IF JSON_QUERY(@Json,N'$.warnings')<>N'[]' THROW 58910,N'WAITS_UNEXPECTED_WARNINGS',1;
  IF @Native=0
  BEGIN
   IF JSON_QUERY(@Json,N'$.currentTasks')<>N'[]' OR JSON_QUERY(@Json,N'$.instanceWaits')<>N'[]' THROW 58911,N'WAITS_CORE_EMPTY',1;
   SET @Core+=1;
  END
  ELSE
  BEGIN
   SET @Sql=REPLACE(@LoadSql,N'INSERT #ExampleCurrentWaitsNative',N'INSERT #ExampleCurrentWaitsAfter');EXEC sys.sp_executesql @Sql;
   INSERT #ExampleCurrentWaitsCounters SELECT 1,waiting_tasks_count,wait_time_ms,signal_wait_time_ms,(SELECT sqlserver_start_time FROM sys.dm_os_sys_info) FROM sys.dm_os_wait_stats WHERE wait_type=N'LCK_M_X';
   IF (SELECT COUNT(*) FROM #ExampleCurrentWaitsAfter)<>3
    OR EXISTS(SELECT RoleOrdinal,WaitingAddress,LoginTime,SessionId,ExecContextId,WaitType,BlockingSessionId,ResourceDescription,SessionStatus,RequestStatus,LoginName,HostName,ProgramName,DatabaseId,Command,StatementText FROM #ExampleCurrentWaitsNative
     EXCEPT SELECT RoleOrdinal,WaitingAddress,LoginTime,SessionId,ExecContextId,WaitType,BlockingSessionId,ResourceDescription,SessionStatus,RequestStatus,LoginName,HostName,ProgramName,DatabaseId,Command,StatementText FROM #ExampleCurrentWaitsAfter)
    OR EXISTS(SELECT 1 FROM #ExampleCurrentWaitsNative b JOIN #ExampleCurrentWaitsAfter a ON b.WaitingAddress=a.WaitingAddress WHERE a.WaitDurationMs<b.WaitDurationMs)
    OR (SELECT COUNT(*) FROM #ExampleCurrentWaitsCounters)<>2
    OR EXISTS(SELECT 1 FROM #ExampleCurrentWaitsCounters b JOIN #ExampleCurrentWaitsCounters a ON b.Phase=0 AND a.Phase=1
     WHERE a.StartTime<>b.StartTime OR a.WaitingTasksCount<b.WaitingTasksCount OR a.WaitTimeMs<b.WaitTimeMs OR a.SignalWaitTimeMs<b.SignalWaitTimeMs) THROW 58912,N'WAITS_NATIVE_CHANGED',1;
   IF EXISTS(SELECT SessionId,ROW_NUMBER() OVER(ORDER BY WaitDurationMs DESC,SessionId) FROM #ExampleCurrentWaitsNative
    EXCEPT SELECT SessionId,ROW_NUMBER() OVER(ORDER BY WaitDurationMs DESC,SessionId) FROM #ExampleCurrentWaitsAfter) THROW 58912,N'WAITS_NATIVE_RANK_CHANGED',1;
   DECLARE @ExpectedJson nvarchar(max);
   ;WITH E AS
   (SELECT n.*,ROW_NUMBER() OVER(ORDER BY n.WaitDurationMs DESC,n.SessionId)rn FROM #ExampleCurrentWaitsNative n
    WHERE (@Tools=1 OR n.RoleOrdinal=3) AND n.WaitDurationMs>=@Min
     AND (@Ids=@FixtureIds OR TRY_CONVERT(smallint,@Ids)=n.SessionId OR @Case=30 AND n.SessionId=@Normal)
     AND @Case NOT IN(31,33,35))
   SELECT @ExpectedJson=(SELECT e.SessionId,e.ExecContextId,TRY_CONVERT(bigint,JSON_VALUE(actual.value,N'$.WaitDurationMs')) AS WaitDurationMs,
    e.WaitType,e.BlockingSessionId,e.ResourceDescription,e.SessionStatus,e.RequestStatus,e.LoginName,e.HostName,e.ProgramName,
    CONVERT(bit,CASE WHEN e.RoleOrdinal=3 THEN 0 ELSE 1 END)IsToolBackgroundQuery,
    CONVERT(varchar(64),CASE WHEN e.RoleOrdinal<>3 THEN 'EXAMPLE_WAITS_FIXTURE_187' END)ToolBackgroundRuleCode,
    CONVERT(varchar(40),CASE WHEN e.RoleOrdinal<>3 THEN 'EXAMPLE_WAITS_TOOL' END)ToolBackgroundCategory,
    CONVERT(varchar(40),CASE WHEN e.RoleOrdinal<>3 THEN 'LOCAL_PROGRAM_NAME_PATTERN' END)ToolBackgroundDetection,
    CONVERT(varchar(16),CASE WHEN e.RoleOrdinal<>3 THEN 'HIGH' END)ToolBackgroundConfidence,e.DatabaseId,e.Command,
    CONVERT(bigint,CASE WHEN @WithText=1 AND e.StatementText IS NOT NULL THEN LEN((e.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1 END)CurrentStatementCharacters,
    CONVERT(bigint,CASE WHEN @WithText=1 THEN DATALENGTH(e.StatementText) END)CurrentStatementBytes,
    CONVERT(bit,CASE WHEN @WithText=1 AND @Text>0 AND LEN((e.StatementText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@Text THEN 1 ELSE 0 END)CurrentStatementIsTruncated,
    CASE WHEN @WithText=0 THEN CONVERT(nvarchar(max),NULL) WHEN @Text IS NULL OR @Text=0 THEN e.StatementText COLLATE SQL_Latin1_General_CP1_CS_AS ELSE LEFT(e.StatementText COLLATE Latin1_General_100_CI_AS_SC,@Text) COLLATE SQL_Latin1_General_CP1_CS_AS END CurrentStatement,
    c.WaitGroup,c.Severity WaitSeverity,c.IsGenerallyBenign,c.Meaning WaitMeaning,c.TypicalOccurrence WaitTypicalOccurrence,c.HighWaitImpact,c.RecommendedChecks,c.HelpUrl WaitHelpUrl,
    c.DescriptionSource,c.DescriptionQuality,CONVERT(varchar(20),'EXACT')CatalogMatchType
    FROM E e JOIN monitor.WaitTypeCatalog c ON c.WaitType=e.WaitType
    LEFT JOIN OPENJSON(@Json,N'$.currentTasks')actual ON TRY_CONVERT(smallint,JSON_VALUE(actual.value,N'$.SessionId'))=e.SessionId
    WHERE @Max IS NULL OR @Max=0 OR e.rn<=@Max ORDER BY e.rn FOR JSON PATH,INCLUDE_NULL_VALUES);
   SET @ExpectedJson=COALESCE(@ExpectedJson,N'[]');
   IF EXISTS(SELECT TRY_CONVERT(int,[key]),TRY_CONVERT(smallint,JSON_VALUE(value,N'$.SessionId')) FROM OPENJSON(@ExpectedJson)
    EXCEPT SELECT TRY_CONVERT(int,[key]),TRY_CONVERT(smallint,JSON_VALUE(value,N'$.SessionId')) FROM OPENJSON(@Json,N'$.currentTasks')) THROW 58913,N'WAITS_JSON_ORDER',1;
   SELECT @ExpectedRows=COUNT(*) FROM OPENJSON(@ExpectedJson);
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.currentTasks'))<>@ExpectedRows
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.currentTasks')a LEFT JOIN #ExampleCurrentWaitsNative b ON b.SessionId=TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId'))
     LEFT JOIN #ExampleCurrentWaitsAfter z ON z.WaitingAddress=b.WaitingAddress WHERE b.SessionId IS NULL
      OR TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.WaitDurationMs')) IS NULL
      OR TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.WaitDurationMs')) NOT BETWEEN b.WaitDurationMs AND z.WaitDurationMs) THROW 58913,N'WAITS_NATIVE_DURATION',1;
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@ExpectedJson) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.currentTasks') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.currentTasks') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@ExpectedJson) GROUP BY value COLLATE Latin1_General_100_BIN2) THROW 58914,N'WAITS_NATIVE_FULL33',1;
   INSERT #ExampleCurrentWaitsExpectedFields SELECT TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId')),p.[key],p.value,p.[type] FROM OPENJSON(@ExpectedJson)a CROSS APPLY OPENJSON(a.value)p;
   IF @NullMutations=0 AND @ExpectedRows>0
   BEGIN
    DECLARE @MutationField nvarchar(128),@OriginalRow nvarchar(max),@MutatedRow nvarchar(max),@MutationSession smallint;
    SELECT TOP(1) @OriginalRow=value,@MutationSession=TRY_CONVERT(smallint,JSON_VALUE(value,N'$.SessionId')) FROM OPENJSON(@ExpectedJson) ORDER BY TRY_CONVERT(int,[key]);
    DECLARE Nulls187 CURSOR LOCAL FAST_FORWARD FOR SELECT FieldName FROM #ExampleCurrentWaitsExpectedFields WHERE SessionId=@MutationSession AND JsonType=1 AND FieldName IN(N'WaitType',N'LoginName',N'HostName',N'ProgramName',N'WaitGroup',N'WaitMeaning');
    OPEN Nulls187;FETCH NEXT FROM Nulls187 INTO @MutationField;
    WHILE @@FETCH_STATUS=0
    BEGIN
     SET @MutatedRow=JSON_MODIFY(@OriginalRow,N'strict $.'+@MutationField,NULL);
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@MutatedRow)p JOIN #ExampleCurrentWaitsExpectedFields e ON e.SessionId=@MutationSession AND e.FieldName=p.[key] COLLATE Latin1_General_100_BIN2
      WHERE p.[type]<>e.JsonType OR (p.value IS NULL AND e.FieldValue IS NOT NULL) OR (p.value IS NOT NULL AND e.FieldValue IS NULL)
       OR p.value COLLATE Latin1_General_100_BIN2<>e.FieldValue COLLATE Latin1_General_100_BIN2) THROW 58915,N'WAITS_NULL_MUTATION',1;
     SET @NullMutations+=1;FETCH NEXT FROM Nulls187 INTO @MutationField;
    END;
    CLOSE Nulls187;DEALLOCATE Nulls187;
    IF @NullMutations<>6 THROW 58915,N'WAITS_NULL_MUTATION_COUNT',1;
   END;
   IF @Case IN(31,33,35)
   BEGIN
    IF JSON_QUERY(@Json,N'$.instanceWaits')<>N'[]' THROW 58916,N'WAITS_INSTANCE_CASE_FILTER',1;
   END
   ELSE
   BEGIN
    DECLARE @InstanceRow nvarchar(max),@Count bigint,@Time bigint,@Signal bigint,@Resource bigint,@InstanceExpected nvarchar(max);
    SELECT @InstanceRow=value FROM OPENJSON(@Json,N'$.instanceWaits');
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.instanceWaits'))<>1 THROW 58916,N'WAITS_INSTANCE_SINGLE',1;
    SELECT @Count=TRY_CONVERT(bigint,JSON_VALUE(@InstanceRow,N'$.WaitingTasksCount')),@Time=TRY_CONVERT(bigint,JSON_VALUE(@InstanceRow,N'$.WaitTimeMs')),
     @Signal=TRY_CONVERT(bigint,JSON_VALUE(@InstanceRow,N'$.SignalWaitTimeMs')),@Resource=TRY_CONVERT(bigint,JSON_VALUE(@InstanceRow,N'$.ResourceWaitTimeMs'));
    IF @Count IS NULL OR @Time IS NULL OR @Signal IS NULL OR @Resource IS NULL
     OR EXISTS(SELECT 1 FROM #ExampleCurrentWaitsCounters b JOIN #ExampleCurrentWaitsCounters a ON b.Phase=0 AND a.Phase=1
      WHERE @Count NOT BETWEEN b.WaitingTasksCount AND a.WaitingTasksCount OR @Time NOT BETWEEN b.WaitTimeMs AND a.WaitTimeMs OR @Signal NOT BETWEEN b.SignalWaitTimeMs AND a.SignalWaitTimeMs)
     OR @Resource<>@Time-@Signal OR @Count<=0 OR @Time<=0 THROW 58917,N'WAITS_INSTANCE_COUNTER_BRACKET',1;
    SELECT @InstanceExpected=(SELECT c.WaitType,@Count WaitingTasksCount,@Time WaitTimeMs,@Signal SignalWaitTimeMs,@Resource ResourceWaitTimeMs,CONVERT(int,NULL)SampleSeconds,
     CONVERT(varchar(30),'INSTANCE_CUMULATIVE')MeasurementType,c.WaitGroup,c.Severity WaitSeverity,c.IsGenerallyBenign,c.Meaning WaitMeaning,c.TypicalOccurrence WaitTypicalOccurrence,
     c.HighWaitImpact,c.RecommendedChecks,c.HelpUrl WaitHelpUrl,c.DescriptionSource,c.DescriptionQuality,CONVERT(varchar(20),'EXACT')CatalogMatchType,
     CONVERT(decimal(9,4),100)WaitPercentage,CONVERT(decimal(9,4),100)CumulativePercentage,
     CONVERT(decimal(19,4),1.0*@Time/NULLIF(@Count,0))AverageWaitMs,CONVERT(decimal(19,4),1.0*@Resource/NULLIF(@Count,0))AverageResourceWaitMs,
     CONVERT(decimal(19,4),1.0*@Signal/NULLIF(@Count,0))AverageSignalWaitMs FROM monitor.WaitTypeCatalog c WHERE c.WaitType=N'LCK_M_X' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
    IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@InstanceExpected)
     EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@InstanceRow))
     OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@InstanceRow)
     EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@InstanceExpected)) THROW 58918,N'WAITS_INSTANCE_FULL23',1;
   END;
   SET @NativeCount+=1;
  END;
  DROP TABLE #ExampleCurrentWaitsExport;
  FETCH NEXT FROM Cases187 INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Tools,@Min,@Sample,@Percentage,@Waits,@WaitPattern,@Groups,@GroupPattern,@Status;
 END;
 CLOSE Cases187;DEALLOCATE Cases187;
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCount<>18 OR @NullMutations<>6 THROW 58919,N'WAITS_NATIVE_CASE_COUNT',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END;
   EXEC monitor.USP_CurrentWaits @SessionIds=@FixtureIds,@WaitTypes=N'LCK_M_X',@ToolHintergrundabfragenEinbeziehen=1,
    @MitSqlText=0,@SampleSeconds=0,@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.currentTasks'))<>CASE @Direct WHEN 0 THEN 3 WHEN 1 THEN 1 ELSE 2 END
    OR @@LOCK_TIMEOUT<>137 THROW 58920,N'WAITS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @Direct+=1;SET @DirectConsole+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleCurrentWaitsEmptyConsole;SET @Max=CASE @Empty WHEN 1 THEN -1 ELSE 0 END;SET @Text=CASE @Empty WHEN 2 THEN -1 ELSE 0 END;
  INSERT #ExampleCurrentWaitsEmptyConsole EXEC monitor.USP_CurrentWaits @SessionIds=N'32767',@WaitTypes=N'ExampleMissingWait187',
   @MaxZeilen=@Max,@MaxSqlTextZeichen=@Text,@SampleSeconds=0,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleCurrentWaitsEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleCurrentWaitsEmptyConsole WHERE Ergebnis<>N'Keine aktiven Waits' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.currentTasks')<>N'[]' OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE @Empty WHEN 0 THEN N'AVAILABLE' ELSE N'INVALID_PARAMETER' END
   OR @@LOCK_TIMEOUT<>137 THROW 58921,N'WAITS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsole+=1;
 END;
 DECLARE @ConsumerCase int=0,@Mode varchar(16);
 WHILE @ConsumerCase<4
 BEGIN
  SET @Json=N'ExamplePreviousJson';SET @Mode=CASE @ConsumerCase WHEN 2 THEN 'RAW' ELSE 'NONE' END;
  IF @ConsumerCase=3
  BEGIN
   DECLARE @MissingParent uniqueidentifier=NEWID();
   EXEC monitor.USP_CurrentWaits @SessionIds=N'32767',@WaitTypes=N'ExampleMissingWait187',@MitSqlText=0,@SampleSeconds=0,
    @ParentCurrentStateSnapshotId=@MissingParent,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARENT_SNAPSHOT' OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true'
    OR JSON_QUERY(@Json,N'$.currentTasks')<>N'[]' OR JSON_QUERY(@Json,N'$.instanceWaits')<>N'[]'
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings')a WHERE a.[type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>2
     OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
     OR EXISTS(SELECT 1 FROM OPENJSON(a.value)p WHERE p.[key] COLLATE Latin1_General_100_BIN2 NOT IN(N'code',N'message') OR p.[type]<>1 OR p.value IS NULL))
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings')a CROSS APPLY OPENJSON(a.value)p WHERE p.[key]=N'code' AND p.value=N'INVALID_PARENT_SNAPSHOT') THROW 58922,N'WAITS_MISSING_PARENT',1;
  END
  ELSE
  BEGIN
   DECLARE @MakeJson bit=CASE WHEN @ConsumerCase=0 THEN 0 ELSE 1 END;
   EXEC monitor.USP_CurrentWaits @SessionIds=N'32767',@WaitTypes=N'ExampleMissingWait187',@MaxZeilen=-1,@SampleSeconds=0,
    @ResultSetArt=@Mode,@JsonErzeugen=@MakeJson,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (@ConsumerCase=0 AND @Json IS NOT NULL) OR (@ConsumerCase>0 AND (ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER'
    OR JSON_QUERY(@Json,N'$.currentTasks')<>N'[]' OR JSON_QUERY(@Json,N'$.instanceWaits')<>N'[]')) THROW 58922,N'WAITS_CONSUMER',1;
  END;
  IF @@LOCK_TIMEOUT<>137 THROW 58922,N'WAITS_CONSUMER_TIMEOUT',1;
  SET @ConsumerCase+=1;SET @Consumer+=1;
 END;
 INSERT #ExampleCurrentWaitsPreflight VALUES(4242);
 DECLARE @P int=0,@Map nvarchar(max),@Caught int;
 WHILE @P<6
 BEGIN
  SET @Map=CASE @P WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleCurrentWaitsPreflight"}' WHEN 2 THEN N'{"currentTasks":"#ExampleMissingTarget187"}'
   WHEN 3 THEN N'{"currentTasks":"ExamplePermanent"}' WHEN 4 THEN N'{"currentTasks":"#ExampleCurrentWaitsPreflight","unknown":"#ExampleCurrentWaitsPreflight"}' ELSE N'{"currentTasks":"#ExampleCurrentWaitsPreflight"}' END;
  SET @Caught=0;SET @Mode=CASE WHEN @P=5 THEN 'NONE' ELSE 'TABLE' END;
  BEGIN TRY
   EXEC monitor.USP_CurrentWaits @SessionIds=N'ExampleInvalid',@MaxZeilen=-1,@ResultSetArt=@Mode,@ResultTablesJson=@Map,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleCurrentWaitsPreflight'))<>1
   OR (SELECT COUNT(*) FROM #ExampleCurrentWaitsPreflight WHERE Dummy=4242)<>1 THROW 58923,N'WAITS_PREFLIGHT',1;
  SET @P+=1;SET @Preflight+=1;
 END;
 CREATE TABLE #ExampleCurrentWaitsUnicode(Value nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Characters bigint NULL,Bytes bigint NULL,Truncated bit NOT NULL DEFAULT(0));
 DECLARE @U int=0,@ExpectedText nvarchar(max),@Truncated bigint,@Largest bigint;
 WHILE @U<4
 BEGIN
  TRUNCATE TABLE #ExampleCurrentWaitsUnicode;INSERT #ExampleCurrentWaitsUnicode(Value) VALUES(N'AÄ🔬B ');
  SET @Text=CASE @U WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 2 THEN 2 ELSE 3 END;
  SET @ExpectedText=CASE @U WHEN 0 THEN N'AÄ🔬B ' WHEN 1 THEN N'AÄ🔬B ' WHEN 2 THEN N'AÄ' ELSE N'AÄ🔬' END;
  EXEC monitor.InternalProjectUnicodeTextColumn @SourceTable=N'#ExampleCurrentWaitsUnicode',@TextColumn=N'Value',@CharactersColumn=N'Characters',@BytesColumn=N'Bytes',
   @IsTruncatedColumn=N'Truncated',@MaxCharacters=@Text,@TruncatedValueCount=@Truncated OUTPUT,@LargestRequiredCharacters=@Largest OUTPUT;
  IF EXISTS(SELECT 1 FROM #ExampleCurrentWaitsUnicode WHERE Value COLLATE Latin1_General_100_BIN2<>@ExpectedText COLLATE Latin1_General_100_BIN2
   OR Characters<>5 OR Bytes<>12 OR Truncated<>CASE WHEN @U>1 THEN 1 ELSE 0 END)
   OR @Truncated<>CASE WHEN @U>1 THEN 1 ELSE 0 END OR (@U>1 AND ISNULL(@Largest,-1)<>5) OR (@U<2 AND @Largest IS NOT NULL) THROW 58924,N'WAITS_LITERAL_UNICODE',1;
  SET @U+=1;SET @Unicode+=1;
 END;
 DECLARE @Restore nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @Restore;
 SELECT N'PASS'ContractStatus,@Level FrameworkCompatibilityLevel,33 TaskFields,22 TaskTextCollations,23 InstanceFields,11 InstanceTextCollations,
  @Core CoreCases,@FixtureStatus PositiveFixtureStatus,@NativeCount NativeCases,@NullMutations NullMutationRejections,
  @Consumer ConsumerCases,@Preflight PreflightCases,@Unicode UnicodeCases,@EmptyConsole EmptySqlConsoleCases,@DirectConsole DirectConsoleStatusJsonCases;
 DROP TABLE #ExampleCurrentWaitsSchema;DROP TABLE #ExampleCurrentWaitsInstanceSchema;DROP TABLE #ExampleCurrentWaitsEmptyConsole;DROP TABLE #ExampleCurrentWaitsPreflight;
 DROP TABLE #ExampleCurrentWaitsIds;DROP TABLE #ExampleCurrentWaitsNative;DROP TABLE #ExampleCurrentWaitsAfter;DROP TABLE #ExampleCurrentWaitsCounters;DROP TABLE #ExampleCurrentWaitsExpectedFields;
 DROP TABLE #ExampleCurrentWaitsCases;DROP TABLE #ExampleCurrentWaitsUnicode;DROP TABLE #ExampleCurrentWaitsFixtureProbe;
END TRY
BEGIN CATCH
 DECLARE @RestoreCatch nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalTimeout)+N';';EXEC sys.sp_executesql @RestoreCatch;
 DROP TABLE IF EXISTS #ExampleCurrentWaitsExport;DROP TABLE IF EXISTS #ExampleCurrentWaitsSchema;DROP TABLE IF EXISTS #ExampleCurrentWaitsInstanceSchema;DROP TABLE IF EXISTS #ExampleCurrentWaitsEmptyConsole;
 DROP TABLE IF EXISTS #ExampleCurrentWaitsPreflight;DROP TABLE IF EXISTS #ExampleCurrentWaitsIds;DROP TABLE IF EXISTS #ExampleCurrentWaitsNative;DROP TABLE IF EXISTS #ExampleCurrentWaitsAfter;
 DROP TABLE IF EXISTS #ExampleCurrentWaitsCounters;DROP TABLE IF EXISTS #ExampleCurrentWaitsExpectedFields;DROP TABLE IF EXISTS #ExampleCurrentWaitsCases;DROP TABLE IF EXISTS #ExampleCurrentWaitsUnicode;DROP TABLE IF EXISTS #ExampleCurrentWaitsFixtureProbe;
 THROW;
END CATCH;
GO
