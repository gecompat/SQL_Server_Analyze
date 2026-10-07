USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft 67 TABLE-Felder, 38 Textcollations, zehn NOT-NULL-Felder und keine
Identity sowie vollständige TABLE-/JSON-Parität einschließlich NULLs.
SessionId 0 ist der unabhängig bestätigte leere allgemeine Kettenscope.
Vier eigene synthetische Textfälle prüfen eine explizite Surrogate-Grenze;
sie belegen keine native Blockingsituation.
Der optionale Block liest Root|Middle|NormalLeaf|ToolLeaf aus SESSION_CONTEXT
(N'ExampleCurrentBlockingFixtureIds'). Er fordert eigene Example-Namen,
drei native Kanten und die eigene Toolregel. Er erzeugt weder Workload noch
Parent-Snapshottabellen und verändert keine Fixture. Fehlt dieser geeignete
Kontext, meldet ausschließlich der positive Block NOT_EXECUTED.
Identitäten, Topologie und native Statementquellen werden unabhängig geprüft.
Waitzeiten werden vor/nach dem Aufruf begrenzt; kein atomarer Cross-call-
Vollvergleich der 67 Livewerte wird behauptet. RAW und positive CONSOLE prüfen
hier nur Status/JSON; Vollzeilen benötigen getrennte Clientcaptures.
Locks, Sonderowner, Zyklen, Berechtigungen, Timeout und ältere Engines bleiben
offen. Inventarversion 4 und JSON-Version 3 bleiben getrennt erhalten.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 58800,N'BLOCKING_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58801,N'BLOCKING_FRAMEWORK_COLLATION',1;
IF EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=0) THROW 58802,N'BLOCKING_EMPTY_SCOPE',1;
IF OBJECT_ID(N'tempdb..#ExampleMissingTarget186') IS NOT NULL THROW 58802,N'BLOCKING_FOREIGN_PREFLIGHT_TARGET',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Sql nvarchar(max),@Json nvarchar(max),@TableJson nvarchar(max),
 @Case int,@Native bit,@Ids nvarchar(max),@Max int,@Text int,@WithText bit,@MinWait bigint,@Depth varchar(16),
 @ResolutionLimit int,@Tools bit,@ExpectedStatus varchar(40),@ExpectedRows bigint,@Total bigint,@HasMore bit,
 @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@TextCases int=0,
 @EmptyConsoleCases int=0,@DirectConsoleCases int=0,@NullMutationCases int=0,@FixtureStatus varchar(24)='NOT_EXECUTED';
CREATE TABLE #ExampleBlockingSchema
(
 [LeafSessionId] smallint NOT NULL,
 [BlockedSessionId] smallint NOT NULL,
 [BlockingSessionId] smallint NOT NULL,
 [RootBlockingSessionId] smallint NULL,
 [BlockingOwnerType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingOwnerDescription] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingChain] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ChainDepth] int NOT NULL,
 [IsCycle] bit NOT NULL,
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTimeMs] bigint NULL,
 [WaitResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceDatabaseId] int NULL,
 [BlockingResourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceObjectId] int NULL,
 [BlockingResourceObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceIndexId] int NULL,
 [BlockingResourceIndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourcePartitionId] bigint NULL,
 [BlockingResourcePartitionNumber] int NULL,
 [BlockingResourceFileId] int NULL,
 [BlockingResourcePageId] bigint NULL,
 [BlockingResourceRowId] int NULL,
 [BlockingResourceMetadataSubtype] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceMetadataName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourcePageTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceName] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockingResourceResolutionStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedIsToolBackgroundQuery] bit NOT NULL,
 [BlockedToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockerLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockerHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockerProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerSessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerRequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerOpenTransactionCount] int NULL,
 [RootBlockerLastRequestStartTime] datetime NULL,
 [RootBlockerLastRequestEndTime] datetime NULL,
 [RootIsToolBackgroundQuery] bit NOT NULL,
 [RootToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockedStatementCharacters] bigint NULL,
 [BlockedStatementBytes] bigint NULL,
 [BlockedStatementIsTruncated] bit NOT NULL DEFAULT(0),
 [BlockedStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BlockerStatementCharacters] bigint NULL,
 [BlockerStatementBytes] bigint NULL,
 [BlockerStatementIsTruncated] bit NOT NULL DEFAULT(0),
 [BlockerStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerStatementSource] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RootBlockerStatementCharacters] bigint NULL,
 [RootBlockerStatementBytes] bigint NULL,
 [RootBlockerStatementIsTruncated] bit NOT NULL DEFAULT(0),
 [RootBlockerStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleBlockingLockSchema
(
 [SessionId] smallint NULL,
 [ResourceType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceDatabaseId] int NULL,
 [ResourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceDescription] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceSubtype] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceAssociatedEntityId] bigint NULL,
 [ResourceLockPartition] int NULL,
 [RequestMode] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestStatus] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestOwnerType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestReferenceCount] smallint NULL,
 [LockOwnerAddress] varbinary(8) NULL,
 [ResolvedResourceType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResolvedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResolvedObjectId] int NULL,
 [ResolvedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResolvedIndexId] int NULL,
 [ResolvedIndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResolvedPartitionId] bigint NULL,
 [ResolvedPartitionNumber] int NULL,
 [ResolvedResourceName] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceResolutionStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE #ExampleBlockingWarningSchema
(
 [ScopeName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ErrorNumber] int NULL,
 [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE #ExampleBlockingEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleBlockingPreflight([Dummy] int NULL);
CREATE TABLE #ExampleBlockingFixtureIds([RoleOrdinal] int NOT NULL PRIMARY KEY,[SessionId] smallint NOT NULL UNIQUE);
CREATE TABLE #ExampleBlockingNative
([RoleOrdinal] int NOT NULL,[SessionId] smallint NOT NULL PRIMARY KEY,[LoginTime] datetime NOT NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[OpenTransactionCount] int NOT NULL,
 [LastRequestStartTime] datetime NOT NULL,[LastRequestEndTime] datetime NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BlockingSessionId] smallint NULL,
 [WaitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WaitTimeMs] bigint NULL,
 [WaitResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StatementSource] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
SELECT TOP(0) * INTO #ExampleBlockingAfter FROM #ExampleBlockingNative;
CREATE TABLE #ExampleBlockingExpected
([LeafSessionId] smallint NOT NULL PRIMARY KEY,[BlockingSessionId] smallint NOT NULL,[ChainDepth] int NOT NULL,
 [BlockingChain] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WaitTimeMs] bigint NOT NULL,[RowOrdinal] int NOT NULL);
CREATE TABLE #ExampleBlockingExpectedFields
([LeafSessionId] smallint NOT NULL,[FieldName] nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 [FieldValue] nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,[JsonType] int NOT NULL);
CREATE TABLE #ExampleBlockingCases
([CaseNumber] int NOT NULL PRIMARY KEY,[Native] bit NOT NULL,[Ids] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MaxRows] int NULL,[MaxText] int NULL,[WithText] bit NULL,[MinWait] bigint NULL,
 [Depth] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ResolutionLimit] int NULL,[Tools] bit NULL,
 [ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExampleBlockingCases VALUES
 (0,0,N'0',NULL,0,0,0,'NONE',1,1,'AVAILABLE'),(1,0,N'0',0,NULL,1,0,'NONE',1,1,'AVAILABLE'),
 (2,0,N'0',1,17,1,0,'NONE',1,1,'AVAILABLE'),(3,0,N'0',2,18,1,0,'NONE',1,1,'AVAILABLE'),
 (4,0,N'0',-1,0,0,0,'NONE',1,1,'INVALID_PARAMETER'),(5,0,N'0',0,-1,1,0,'NONE',1,1,'INVALID_PARAMETER'),
 (6,0,N'0',0,0,0,-1,'NONE',1,1,'INVALID_PARAMETER'),(7,0,N'0',0,0,0,NULL,'NONE',1,1,'INVALID_PARAMETER'),
 (8,0,N'ExampleInvalid',0,0,0,0,'NONE',1,1,'INVALID_PARAMETER'),(9,0,N'32768',0,0,0,0,'NONE',1,1,'INVALID_PARAMETER'),
 (10,0,N'0|0',0,0,0,0,'NONE',1,1,'INVALID_PARAMETER'),(11,0,N'-1',0,0,0,0,'NONE',1,1,'INVALID_PARAMETER'),
 (12,0,N'0',0,0,0,0,'ExampleInvalid',1,1,'INVALID_PARAMETER'),(13,0,N'0',0,0,0,0,'NONE',0,1,'INVALID_PARAMETER'),
 (14,0,N'0',0,0,0,0,'NONE',1001,1,'INVALID_PARAMETER'),(15,0,N'0',0,0,0,0,'NONE',NULL,1,'INVALID_PARAMETER'),
 (16,0,N'0',0,0,0,0,'NONE',1,NULL,'INVALID_PARAMETER'),(17,0,N'0',0,0,NULL,0,'NONE',1,1,'INVALID_PARAMETER');
DECLARE @ContextIds nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentBlockingFixtureIds')),
 @Root smallint,@Middle smallint,@NormalLeaf smallint,@ToolLeaf smallint,@FixtureIds nvarchar(max);
-- Pipe order is part of this private opt-in fixture contract; no product parser is used.
DECLARE @ContextJson nvarchar(max)=N'['+REPLACE(@ContextIds,N'|',N',')+N']';
IF @ContextIds IS NOT NULL AND ISJSON(@ContextJson)=1 AND (SELECT COUNT(*) FROM OPENJSON(@ContextJson))=4
 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@ContextJson) WHERE [type]<>2 OR TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
 AND (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM OPENJSON(@ContextJson))=4
BEGIN
 INSERT #ExampleBlockingFixtureIds SELECT CONVERT(int,[key])+1,CONVERT(smallint,value) FROM OPENJSON(@ContextJson);
 SELECT @Root=MAX(CASE WHEN RoleOrdinal=1 THEN SessionId END),@Middle=MAX(CASE WHEN RoleOrdinal=2 THEN SessionId END),
  @NormalLeaf=MAX(CASE WHEN RoleOrdinal=3 THEN SessionId END),@ToolLeaf=MAX(CASE WHEN RoleOrdinal=4 THEN SessionId END) FROM #ExampleBlockingFixtureIds;
 IF (SELECT COUNT(*) FROM sys.dm_exec_sessions s JOIN #ExampleBlockingFixtureIds f ON s.session_id=f.SessionId
  WHERE s.is_user_process=1 AND s.original_login_name COLLATE Latin1_General_100_BIN2=ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2
   AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
   AND s.program_name COLLATE Latin1_General_100_BIN2=CASE f.RoleOrdinal
    WHEN 1 THEN N'ExampleBlockingToolRootÄ🔬' WHEN 2 THEN N'ExampleBlockingToolMiddleÄ🔬'
    WHEN 3 THEN N'ExampleBlockingLeafÄ🔬' ELSE N'ExampleBlockingToolLeafä🔬' END COLLATE Latin1_General_100_BIN2)=4
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=@Root AND status=N'sleeping' AND open_transaction_count>0)
  AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Root)
  AND (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE session_id IN(@Middle,@NormalLeaf,@ToolLeaf))=3
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@Middle AND blocking_session_id=@Root AND wait_type LIKE N'LCK[_]%')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@NormalLeaf AND blocking_session_id=@Middle AND wait_type LIKE N'LCK[_]%')
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests WHERE session_id=@ToolLeaf AND blocking_session_id=@Middle AND wait_type LIKE N'LCK[_]%')
  AND EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE RuleCode='EXAMPLE_BLOCKING_FIXTURE_186' AND Priority=32767
   AND IsEnabled=1 AND ProgramNameLikePattern=N'ExampleBlockingTool%' AND ToolBackgroundCategory='EXAMPLE_BLOCKING_TOOL'
   AND ToolBackgroundDetection='LOCAL_PROGRAM_NAME_PATTERN' AND ToolBackgroundConfidence='HIGH' AND IsFrameworkDefault=0)
 BEGIN
  SET @FixtureIds=@ContextIds;
  INSERT #ExampleBlockingCases VALUES
   (20,1,@FixtureIds,NULL,0,0,0,'NONE',1,1,'AVAILABLE'),(21,1,@FixtureIds,0,0,0,0,'NONE',1,1,'AVAILABLE'),
   (22,1,@FixtureIds,1,0,0,0,'NONE',1,1,'AVAILABLE'),(23,1,@FixtureIds,2,0,0,0,'NONE',1,1,'AVAILABLE'),
   (24,1,CONVERT(nvarchar(10),@Root),0,0,0,0,'NONE',1,0,'AVAILABLE'),
   (25,1,CONVERT(nvarchar(10),@Middle),0,0,0,0,'NONE',1,1,'AVAILABLE'),
   (26,1,CONVERT(nvarchar(10),@NormalLeaf),0,0,0,0,'NONE',1,0,'AVAILABLE'),
   (27,1,CONVERT(nvarchar(10),@ToolLeaf),0,0,0,0,'NONE',1,0,'AVAILABLE'),
   (28,1,CONVERT(nvarchar(10),@ToolLeaf),0,0,0,0,'NONE',1,1,'AVAILABLE'),
   (29,1,@FixtureIds,0,NULL,1,0,'NONE',1,1,'AVAILABLE'),(30,1,@FixtureIds,0,0,1,0,'NONE',1,1,'AVAILABLE'),
   (31,1,@FixtureIds,0,17,1,0,'NONE',1,1,'AVAILABLE'),(32,1,@FixtureIds,0,18,1,0,'NONE',1,1,'AVAILABLE'),
   (33,1,@FixtureIds,0,36,1,0,'NONE',1,1,'AVAILABLE'),(34,1,@FixtureIds,0,37,1,0,'NONE',1,1,'AVAILABLE'),
   (35,1,@FixtureIds,0,68,1,0,'NONE',1,1,'AVAILABLE'),(36,1,@FixtureIds,0,69,1,0,'NONE',1,1,'AVAILABLE'),
   (37,1,@FixtureIds,0,0,0,9223372036854775807,'NONE',1,1,'AVAILABLE');
  SET @FixtureStatus='PENDING';
 END;
END;
DECLARE @LoadSql nvarchar(max)=N'
INSERT #ExampleBlockingNative
SELECT f.RoleOrdinal,s.session_id,s.login_time,s.login_name,s.host_name,s.program_name,s.status,s.open_transaction_count,
 s.last_request_start_time,s.last_request_end_time,r.status,r.blocking_session_id,r.wait_type,CONVERT(bigint,r.wait_time),r.wait_resource,
 CASE WHEN t.text IS NULL THEN NULL ELSE SUBSTRING(t.text COLLATE Latin1_General_100_BIN2,
  COALESCE(r.statement_start_offset,0)/2+1,
  (CASE WHEN r.statement_end_offset IS NULL OR r.statement_end_offset=-1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END-COALESCE(r.statement_start_offset,0))/2+1) END COLLATE SQL_Latin1_General_CP1_CS_AS,
 CASE WHEN r.sql_handle IS NOT NULL THEN ''ACTIVE_REQUEST'' WHEN c.most_recent_sql_handle IS NOT NULL THEN ''MOST_RECENT_CONNECTION'' ELSE ''UNAVAILABLE'' END
FROM #ExampleBlockingFixtureIds f JOIN sys.dm_exec_sessions s ON s.session_id=f.SessionId
OUTER APPLY(SELECT TOP(1) * FROM sys.dm_exec_requests x WHERE x.session_id=s.session_id ORDER BY request_id) r
OUTER APPLY(SELECT TOP(1) most_recent_sql_handle FROM sys.dm_exec_connections x WHERE x.session_id=s.session_id ORDER BY connect_time DESC) c
OUTER APPLY sys.dm_exec_sql_text(COALESCE(r.sql_handle,c.most_recent_sql_handle)) t;';
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases186] CURSOR LOCAL FAST_FORWARD FOR SELECT CaseNumber,Native,Ids,MaxRows,MaxText,WithText,MinWait,Depth,ResolutionLimit,Tools,ExpectedStatus FROM #ExampleBlockingCases ORDER BY CaseNumber;
 OPEN [Cases186];FETCH NEXT FROM [Cases186] INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@MinWait,@Depth,@ResolutionLimit,@Tools,@ExpectedStatus;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ExpectedRows=0;SET @Total=0;SET @HasMore=0;
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleBlockingNative;TRUNCATE TABLE #ExampleBlockingAfter;TRUNCATE TABLE #ExampleBlockingExpected;TRUNCATE TABLE #ExampleBlockingExpectedFields;
   EXEC sys.sp_executesql @LoadSql;
   IF (SELECT COUNT(*) FROM #ExampleBlockingNative)<>4
    OR NOT EXISTS(SELECT 1 FROM #ExampleBlockingNative WHERE SessionId=@Middle AND BlockingSessionId=@Root)
    OR NOT EXISTS(SELECT 1 FROM #ExampleBlockingNative WHERE SessionId=@NormalLeaf AND BlockingSessionId=@Middle)
    OR NOT EXISTS(SELECT 1 FROM #ExampleBlockingNative WHERE SessionId=@ToolLeaf AND BlockingSessionId=@Middle)
    OR EXISTS(SELECT 1 FROM #ExampleBlockingNative WHERE RoleOrdinal>1 AND (WaitTimeMs IS NULL OR WaitTimeMs<0))
     THROW 58803,N'BLOCKING_NATIVE_TOPOLOGY',1;
   INSERT #ExampleBlockingExpected
   SELECT n.SessionId,n.BlockingSessionId,CASE n.RoleOrdinal WHEN 2 THEN 1 ELSE 2 END,
    CASE n.RoleOrdinal WHEN 2 THEN CONCAT(n.SessionId,N' <- ',@Root) ELSE CONCAT(n.SessionId,N' <- ',@Middle,N' <- ',@Root) END,
    n.WaitTimeMs,CONVERT(int,ROW_NUMBER() OVER(ORDER BY n.WaitTimeMs DESC,n.SessionId))
   FROM #ExampleBlockingNative n WHERE n.RoleOrdinal>1 AND n.WaitTimeMs>=@MinWait AND (@Tools=1 OR n.RoleOrdinal=3)
    AND (@Ids=@FixtureIds OR TRY_CONVERT(smallint,@Ids)=@Root OR TRY_CONVERT(smallint,@Ids)=@Middle OR TRY_CONVERT(smallint,@Ids)=n.SessionId);
   SELECT @Total=COUNT_BIG(*) FROM #ExampleBlockingExpected;
   SET @ExpectedRows=CASE WHEN @Max IS NOT NULL AND @Max>0 AND @Total>@Max THEN @Max ELSE @Total END;
   SET @HasMore=CASE WHEN @Max IS NOT NULL AND @Max>0 AND @Total>@Max THEN 1 ELSE 0 END;
  END;
  CREATE TABLE #ExampleBlockingExport([Dummy] int NULL);
  EXEC monitor.USP_CurrentBlocking @SessionIds=@Ids,@MinWaitMs=@MinWait,@ToolHintergrundabfragenEinbeziehen=@Tools,
   @MitSqlText=@WithText,@MaxSqlTextZeichen=@Text,@BlockingObjektTiefe=@Depth,@MaxObjektAufloesungen=@ResolutionLimit,
   @MitLockDetails=0,@MaxZeilen=@Max,@ResultSetArt='TABLE',@ResultTablesJson=N'{"blockingChains":"#ExampleBlockingExport"}',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>137 THROW 58804,N'BLOCKING_CALLER_LOCK_TIMEOUT',1;

  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,
    collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,
    collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingExport'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,
    collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,max_length,precision,scale,
    collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingSchema'))
    THROW 58805,N'BLOCKING_TABLE_SCHEMA',1;
  SET @TableJson=NULL;
  EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleBlockingExport ORDER BY WaitTimeMs DESC,BlockedSessionId FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
  SET @TableJson=COALESCE(@TableJson,N'[]');
  IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>4
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'meta'),(N'blockingChains'),(N'locks'),(N'warnings'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE [key] WHEN N'meta' THEN 5 ELSE 4 END)
    THROW 58806,N'BLOCKING_JSON_TOP',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>24
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') m LEFT JOIN(VALUES
    (N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'evidenceSnapshotStartedAtUtc',1),(N'evidenceSnapshotId',1),
    (N'isPartial',3),(N'statusCode',1),(N'requestedMaxRows',CASE WHEN @Max IS NULL THEN 0 ELSE 2 END),
    (N'returnedRows',2),(N'hasMoreRows',3),(N'lockStatusCode',1),(N'blockingObjectDepth',1),(N'objectResolutionStatusCode',1),
    (N'objectResolutionCandidateCount',2),(N'objectResolutionTotalCount',2),(N'objectResolutionHasMoreRows',3),
    (N'objectResolutionResolvedCount',2),(N'objectResolutionPartialCount',2),(N'objectResolutionRawOnlyCount',2),
    (N'objectResolutionTimeoutCount',2),(N'objectResolutionDeniedCount',2),(N'objectResolutionErrorCount',2),
    (N'objectResolutionSkippedLimitCount',2),(N'toolBackgroundQueriesIncluded',CASE WHEN @Tools IS NULL THEN 0 ELSE 3 END))v(k,t)
    ON m.[key] COLLATE Latin1_General_100_BIN2=v.k COLLATE Latin1_General_100_BIN2 WHERE v.k IS NULL OR m.[type]<>v.t)
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'CurrentBlocking' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>3
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@ExpectedStatus OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
   OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@ExpectedRows
   OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE @HasMore WHEN 1 THEN N'true' ELSE N'false' END
   OR JSON_VALUE(@Json,N'$.meta.lockStatusCode')<>N'SKIPPED'
   OR JSON_VALUE(@Json,N'$.meta.blockingObjectDepth')<>UPPER(@Depth)
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') m WHERE m.[key] LIKE N'objectResolution%Count' AND ISNULL(TRY_CONVERT(bigint,m.value),-1)<>0)
   OR JSON_VALUE(@Json,N'$.meta.objectResolutionHasMoreRows')<>N'false'
    THROW 58807,N'BLOCKING_META',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@TableJson))<>@ExpectedRows OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.blockingChains'))<>@ExpectedRows
   OR JSON_QUERY(@Json,N'$.locks')<>N'[]' OR JSON_QUERY(@Json,N'$.warnings')<>N'[]' THROW 58808,N'BLOCKING_ROW_COUNTS',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.blockingChains') a WHERE [type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>67
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingSchema')))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.blockingChains') a CROSS APPLY OPENJSON(a.value)p
    JOIN tempdb.sys.columns c ON c.object_id=OBJECT_ID(N'tempdb..#ExampleBlockingSchema') AND c.name COLLATE Latin1_General_100_BIN2=p.[key] COLLATE Latin1_General_100_BIN2
    WHERE (p.[type]=0 AND c.is_nullable=0) OR (p.[type]<>0 AND p.[type]<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(52,56,127) THEN 2 ELSE 1 END))
    THROW 58809,N'BLOCKING_JSON_FIELDS',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.blockingChains') GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,N'$.blockingChains') GROUP BY value COLLATE Latin1_General_100_BIN2
   EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 58810,N'BLOCKING_TABLE_JSON_ALL_FIELDS',1;
  IF @Native=1
  BEGIN
   SET @Sql=REPLACE(@LoadSql,N'INSERT #ExampleBlockingNative',N'INSERT #ExampleBlockingAfter');EXEC sys.sp_executesql @Sql;
   IF (SELECT COUNT(*) FROM #ExampleBlockingAfter)<>4
    OR EXISTS(SELECT RoleOrdinal,SessionId,LoginTime,LoginName,HostName,ProgramName,SessionStatus,OpenTransactionCount,LastRequestStartTime,LastRequestEndTime,RequestStatus,BlockingSessionId,WaitType,WaitResource,StatementText,StatementSource FROM #ExampleBlockingNative
     EXCEPT SELECT RoleOrdinal,SessionId,LoginTime,LoginName,HostName,ProgramName,SessionStatus,OpenTransactionCount,LastRequestStartTime,LastRequestEndTime,RequestStatus,BlockingSessionId,WaitType,WaitResource,StatementText,StatementSource FROM #ExampleBlockingAfter)
    OR EXISTS(SELECT 1 FROM #ExampleBlockingAfter a JOIN #ExampleBlockingNative b ON a.SessionId=b.SessionId WHERE a.WaitTimeMs<b.WaitTimeMs)
     THROW 58811,N'BLOCKING_NATIVE_CHANGED',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.blockingChains') a
    LEFT JOIN #ExampleBlockingExpected e ON e.LeafSessionId=TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.LeafSessionId'))
    LEFT JOIN #ExampleBlockingNative n ON n.SessionId=e.LeafSessionId LEFT JOIN #ExampleBlockingAfter z ON z.SessionId=e.LeafSessionId
    WHERE e.LeafSessionId IS NULL OR (@Max IS NOT NULL AND @Max>0 AND e.RowOrdinal>@Max)
     OR ISNULL(TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.BlockedSessionId')),-1)<>e.LeafSessionId
     OR ISNULL(TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.BlockingSessionId')),-1)<>e.BlockingSessionId
     OR ISNULL(TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.RootBlockingSessionId')),-1)<>@Root
     OR ISNULL(TRY_CONVERT(int,JSON_VALUE(a.value,N'$.ChainDepth')),-1)<>e.ChainDepth
     OR TRY_CONVERT(int,a.[key])<>e.RowOrdinal-1
     OR JSON_VALUE(a.value,N'$.IsCycle')<>N'false'
     OR TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.WaitTimeMs')) IS NULL
     OR TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.WaitTimeMs')) NOT BETWEEN n.WaitTimeMs AND z.WaitTimeMs
     OR JSON_VALUE(a.value,N'$.RootIsToolBackgroundQuery')<>N'true'
     OR JSON_VALUE(a.value,N'$.BlockedIsToolBackgroundQuery')<>CASE n.RoleOrdinal WHEN 3 THEN N'false' ELSE N'true' END)
     THROW 58812,N'BLOCKING_NATIVE_CHAIN_VALUES',1;
   INSERT #ExampleBlockingExpectedFields
   SELECT e.LeafSessionId,p.[key],p.value,p.[type]
   FROM #ExampleBlockingExpected e JOIN #ExampleBlockingNative blocked ON blocked.SessionId=e.LeafSessionId
   JOIN #ExampleBlockingNative blocker ON blocker.SessionId=e.BlockingSessionId JOIN #ExampleBlockingNative root ON root.SessionId=@Root
   CROSS APPLY(SELECT e.BlockingChain AS BlockingChain,blocked.WaitType AS WaitType,blocked.WaitResource AS WaitResource,
    CONVERT(varchar(40),'SESSION') AS BlockingOwnerType,
    CONVERT(nvarchar(512),N'Blockierende SQL-Server-Session.') AS BlockingOwnerDescription,
    CONVERT(varchar(40),'SKIPPED') AS BlockingResourceResolutionStatus,
    blocked.LoginName AS BlockedLoginName,blocked.HostName AS BlockedHostName,blocked.ProgramName AS BlockedProgramName,
    blocker.LoginName AS BlockerLoginName,blocker.HostName AS BlockerHostName,blocker.ProgramName AS BlockerProgramName,
    root.LoginName AS RootBlockerLoginName,root.HostName AS RootBlockerHostName,root.ProgramName AS RootBlockerProgramName,
    root.SessionStatus AS RootBlockerSessionStatus,root.RequestStatus AS RootBlockerRequestStatus,root.OpenTransactionCount AS RootBlockerOpenTransactionCount,
    root.LastRequestStartTime AS RootBlockerLastRequestStartTime,root.LastRequestEndTime AS RootBlockerLastRequestEndTime
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) j(value) CROSS APPLY OPENJSON(j.value)p;
   INSERT #ExampleBlockingExpectedFields
   SELECT e.LeafSessionId,p.[key],p.value,p.[type]
   FROM #ExampleBlockingExpected e JOIN #ExampleBlockingNative blocked ON blocked.SessionId=e.LeafSessionId
   JOIN #ExampleBlockingNative blocker ON blocker.SessionId=e.BlockingSessionId JOIN #ExampleBlockingNative root ON root.SessionId=@Root
   CROSS APPLY(VALUES(N'BlockedStatement',CASE WHEN @WithText=1 THEN blocked.StatementText END),
    (N'BlockerStatement',CASE WHEN @WithText=1 AND blocker.StatementSource='ACTIVE_REQUEST' THEN blocker.StatementText END),
    (N'RootBlockerStatement',CASE WHEN @WithText=1 THEN root.StatementText END)) texts(FieldName,FullText)
   CROSS APPLY(SELECT CONVERT(bigint,CASE WHEN texts.FullText IS NOT NULL THEN LEN((texts.FullText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1 END) AS Characters,
    CONVERT(bigint,DATALENGTH(texts.FullText)) AS Bytes,
    CONVERT(bit,CASE WHEN texts.FullText IS NOT NULL AND @Text>0 AND LEN((texts.FullText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@Text THEN 1 ELSE 0 END) AS IsTruncated,
    CASE WHEN texts.FullText IS NULL THEN CONVERT(nvarchar(max),NULL) WHEN @Text IS NULL OR @Text=0 THEN texts.FullText COLLATE SQL_Latin1_General_CP1_CS_AS
     ELSE LEFT(texts.FullText COLLATE Latin1_General_100_CI_AS_SC,@Text) COLLATE SQL_Latin1_General_CP1_CS_AS END AS ProjectedText
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) j(value) CROSS APPLY OPENJSON(j.value) p0
   CROSS APPLY(SELECT CASE p0.[key] WHEN N'ProjectedText' THEN texts.FieldName ELSE texts.FieldName+p0.[key] END,p0.value,p0.[type])p([key],value,[type]);
   INSERT #ExampleBlockingExpectedFields
   SELECT e.LeafSessionId,p.[key],p.value,p.[type]
   FROM #ExampleBlockingExpected e JOIN #ExampleBlockingNative n ON n.SessionId=e.LeafSessionId
   CROSS APPLY(SELECT CONVERT(varchar(64),CASE WHEN n.RoleOrdinal<>3 THEN 'EXAMPLE_BLOCKING_FIXTURE_186' END) AS BlockedToolBackgroundRuleCode,
    CONVERT(varchar(40),CASE WHEN n.RoleOrdinal<>3 THEN 'EXAMPLE_BLOCKING_TOOL' END) AS BlockedToolBackgroundCategory,
    CONVERT(varchar(40),CASE WHEN n.RoleOrdinal<>3 THEN 'LOCAL_PROGRAM_NAME_PATTERN' END) AS BlockedToolBackgroundDetection,
    CONVERT(varchar(16),CASE WHEN n.RoleOrdinal<>3 THEN 'HIGH' END) AS BlockedToolBackgroundConfidence,
    CONVERT(varchar(64),'EXAMPLE_BLOCKING_FIXTURE_186') AS RootToolBackgroundRuleCode,
    CONVERT(varchar(40),'EXAMPLE_BLOCKING_TOOL') AS RootToolBackgroundCategory,
    CONVERT(varchar(40),'LOCAL_PROGRAM_NAME_PATTERN') AS RootToolBackgroundDetection,
    CONVERT(varchar(16),'HIGH') AS RootToolBackgroundConfidence
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) j(value) CROSS APPLY OPENJSON(j.value)p;
   INSERT #ExampleBlockingExpectedFields SELECT LeafSessionId,N'RootBlockerStatementSource',CASE WHEN @WithText=0 THEN N'NOT_REQUESTED' ELSE r.StatementSource END,1
    FROM #ExampleBlockingExpected CROSS JOIN #ExampleBlockingNative r WHERE r.SessionId=@Root;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.blockingChains') a CROSS APPLY OPENJSON(a.value)p
    JOIN #ExampleBlockingExpectedFields e ON e.LeafSessionId=TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.LeafSessionId')) AND e.FieldName=p.[key] COLLATE Latin1_General_100_BIN2
    WHERE p.[type]<>e.JsonType OR (p.value IS NULL AND e.FieldValue IS NOT NULL)
     OR (p.value IS NOT NULL AND e.FieldValue IS NULL)
     OR p.value COLLATE Latin1_General_100_BIN2<>e.FieldValue COLLATE Latin1_General_100_BIN2)
     THROW 58813,N'BLOCKING_NATIVE_IDENTITY_TEXT_VALUES',1;
   -- Real NULL mutations must fail the same independent type/value predicate.
   IF @NullMutationCases=0 AND @ExpectedRows>0
   BEGIN
    DECLARE @MutationField nvarchar(128),@MutationOriginal nvarchar(max),@MutationJson nvarchar(max),@MutationLeaf smallint;
    SELECT TOP(1) @MutationOriginal=value,@MutationLeaf=TRY_CONVERT(smallint,JSON_VALUE(value,N'$.LeafSessionId'))
     FROM OPENJSON(@Json,N'$.blockingChains') ORDER BY TRY_CONVERT(int,[key]);
    DECLARE [NullFields186] CURSOR LOCAL FAST_FORWARD FOR
     SELECT FieldName FROM #ExampleBlockingExpectedFields WHERE LeafSessionId=@MutationLeaf
      AND FieldName IN(N'BlockingChain',N'WaitType',N'WaitResource',N'BlockingOwnerType',N'BlockingOwnerDescription',N'BlockingResourceResolutionStatus');
    OPEN [NullFields186];FETCH NEXT FROM [NullFields186] INTO @MutationField;
    WHILE @@FETCH_STATUS=0
    BEGIN
     IF NOT EXISTS(SELECT 1 FROM #ExampleBlockingExpectedFields WHERE LeafSessionId=@MutationLeaf AND FieldName=@MutationField AND JsonType=1 AND FieldValue IS NOT NULL)
      THROW 58824,N'BLOCKING_NULL_MUTATION_EXPECTED_TEXT',1;
     SET @MutationJson=JSON_MODIFY(@MutationOriginal,N'strict $.'+@MutationField,NULL);
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@MutationJson)p JOIN #ExampleBlockingExpectedFields e
      ON e.LeafSessionId=@MutationLeaf AND e.FieldName=p.[key] COLLATE Latin1_General_100_BIN2
      WHERE p.[type]<>e.JsonType OR (p.value IS NULL AND e.FieldValue IS NOT NULL)
       OR (p.value IS NOT NULL AND e.FieldValue IS NULL)
       OR p.value COLLATE Latin1_General_100_BIN2<>e.FieldValue COLLATE Latin1_General_100_BIN2)
      THROW 58825,N'BLOCKING_NULL_MUTATION_NOT_REJECTED',1;
     SET @NullMutationCases+=1;FETCH NEXT FROM [NullFields186] INTO @MutationField;
    END;
    CLOSE [NullFields186];DEALLOCATE [NullFields186];
    IF @NullMutationCases<>6 THROW 58826,N'BLOCKING_NULL_MUTATION_COUNT',1;
   END;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.blockingChains') a CROSS APPLY OPENJSON(a.value)p
    WHERE p.[key] LIKE N'BlockingResource%' AND p.[key]<>N'BlockingResourceResolutionStatus' AND p.[type]<>0)
     THROW 58814,N'BLOCKING_NONE_RESOURCE_NULLS',1;
   SET @NativeCases+=1;
  END
  ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleBlockingExport;
  FETCH NEXT FROM [Cases186] INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@MinWait,@Depth,@ResolutionLimit,@Tools,@ExpectedStatus;
 END;
 CLOSE [Cases186];DEALLOCATE [Cases186];

 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>18 OR @NullMutationCases<>6 THROW 58815,N'BLOCKING_NATIVE_CASE_COUNTS',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END;
   EXEC monitor.USP_CurrentBlocking @SessionIds=@FixtureIds,@ToolHintergrundabfragenEinbeziehen=1,
    @BlockingObjektTiefe='NONE',@MitSqlText=0,@MaxZeilen=@Max,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.blockingChains'))<>CASE @Direct WHEN 0 THEN 3 WHEN 1 THEN 1 ELSE 2 END
    OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR @@LOCK_TIMEOUT<>137 THROW 58816,N'BLOCKING_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @Direct+=1;SET @DirectConsoleCases+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleBlockingEmptyConsole;
  SET @Max=CASE WHEN @Empty=1 THEN -1 ELSE 0 END;SET @Text=CASE WHEN @Empty=2 THEN -1 ELSE 0 END;
  INSERT #ExampleBlockingEmptyConsole EXEC monitor.USP_CurrentBlocking @SessionIds=N'0',@BlockingObjektTiefe='NONE',
   @ToolHintergrundabfragenEinbeziehen=1,@MaxZeilen=@Max,@MaxSqlTextZeichen=@Text,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleBlockingEmptyConsole)<>1
   OR EXISTS(SELECT 1 FROM #ExampleBlockingEmptyConsole WHERE Ergebnis<>N'Keine Blocking-Ketten' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.blockingChains')<>N'[]' OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Empty=0 THEN N'AVAILABLE' ELSE N'INVALID_PARAMETER' END
   OR @@LOCK_TIMEOUT<>137 THROW 58817,N'BLOCKING_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0,@Mode varchar(16);
 WHILE @Consumer<4
 BEGIN
  SET @Json=N'ExamplePreviousJson';
  IF @Consumer=0
  BEGIN
   EXEC monitor.USP_CurrentBlocking @SessionIds=N'0',@BlockingObjektTiefe='NONE',@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF @Json IS NOT NULL THROW 58818,N'BLOCKING_JSON_DISABLED',1;
  END
  ELSE IF @Consumer<3
  BEGIN
   SET @Mode=CASE WHEN @Consumer=1 THEN 'NONE' ELSE 'RAW' END;
   EXEC monitor.USP_CurrentBlocking @SessionIds=N'0',@MaxZeilen=-1,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER'
    OR JSON_QUERY(@Json,N'$.blockingChains')<>N'[]' THROW 58819,N'BLOCKING_INVALID_CONSUMER',1;
  END;
  ELSE
  BEGIN
   DECLARE @MissingParent uniqueidentifier=NEWID();
   EXEC monitor.USP_CurrentBlocking @SessionIds=N'0',@BlockingObjektTiefe='NONE',@ParentCurrentStateSnapshotId=@MissingParent,
    @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARENT_SNAPSHOT'
    OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true' OR JSON_QUERY(@Json,N'$.blockingChains')<>N'[]'
     THROW 58819,N'BLOCKING_MISSING_PARENT_ISOLATION',1;
  END;
  IF @@LOCK_TIMEOUT<>137 THROW 58820,N'BLOCKING_CONSUMER_CALLER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 INSERT #ExampleBlockingPreflight VALUES(4242);
 DECLARE @Preflight int=0,@BadMap nvarchar(max),@Caught int;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleBlockingPreflight"}'
   WHEN 2 THEN N'{"blockingChains":"#ExampleMissingTarget186"}' WHEN 3 THEN N'{"blockingChains":"ExamplePermanent"}'
   WHEN 4 THEN N'{"blockingChains":"#ExampleBlockingPreflight","unknown":"#ExampleBlockingPreflight"}' ELSE N'{"blockingChains":"#ExampleBlockingPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC monitor.USP_CurrentBlocking @SessionIds=N'0',@MinWaitMs=NULL,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleBlockingPreflight'))<>1
   OR (SELECT COUNT(*) FROM #ExampleBlockingPreflight WHERE Dummy=4242)<>1 THROW 58821,N'BLOCKING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 CREATE TABLE #ExampleBlockingText
 ([TextValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Characters] bigint NULL,[Bytes] bigint NULL,[IsTruncated] bit NOT NULL DEFAULT(0));
 DECLARE @TextCase int=0,@Truncated bigint,@Largest bigint,@ExpectedText nvarchar(max);
 WHILE @TextCase<4
 BEGIN
  TRUNCATE TABLE #ExampleBlockingText;
  INSERT #ExampleBlockingText(TextValue) VALUES(N'AÄ🔬B ');
  SET @Text=CASE @TextCase WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 2 THEN 2 ELSE 3 END;
  SET @ExpectedText=CASE @TextCase WHEN 0 THEN N'AÄ🔬B ' WHEN 1 THEN N'AÄ🔬B ' WHEN 2 THEN N'AÄ' ELSE N'AÄ🔬' END;
  EXEC monitor.InternalProjectUnicodeTextColumn @SourceTable=N'#ExampleBlockingText',@TextColumn=N'TextValue',
   @CharactersColumn=N'Characters',@BytesColumn=N'Bytes',@IsTruncatedColumn=N'IsTruncated',@MaxCharacters=@Text,
   @TruncatedValueCount=@Truncated OUTPUT,@LargestRequiredCharacters=@Largest OUTPUT;
  IF (SELECT COUNT(*) FROM #ExampleBlockingText)<>1
   OR EXISTS(SELECT 1 FROM #ExampleBlockingText WHERE TextValue COLLATE Latin1_General_100_BIN2<>@ExpectedText COLLATE Latin1_General_100_BIN2
    OR Characters<>5 OR Bytes<>12 OR IsTruncated<>CASE WHEN @TextCase<2 THEN 0 ELSE 1 END)
   OR @Truncated<>CASE WHEN @TextCase<2 THEN 0 ELSE 1 END
   OR (@TextCase<2 AND @Largest IS NOT NULL) OR (@TextCase>=2 AND ISNULL(@Largest,-1)<>5)
    THROW 58822,N'BLOCKING_SYNTHETIC_UNICODE_BOUNDARY',1;
  SET @TextCase+=1;SET @TextCases+=1;
 END;
 IF @CoreCases<>18 OR @ConsumerCases<>4 OR @EmptyConsoleCases<>3 OR @PreflightCases<>6 OR @TextCases<>4
  THROW 58823,N'BLOCKING_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,67 AS TableFields,38 AS TextCollations,
  10 AS NotNullFields,@CoreCases AS CoreCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,
  @ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@TextCases AS SyntheticUnicodeCases,@NullMutationCases AS NativeNullMutationCases,
  @EmptyConsoleCases AS EmptySqlConsoleCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 IF OBJECT_ID(N'tempdb..#ExampleBlockingExport') IS NOT NULL DROP TABLE #ExampleBlockingExport;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
