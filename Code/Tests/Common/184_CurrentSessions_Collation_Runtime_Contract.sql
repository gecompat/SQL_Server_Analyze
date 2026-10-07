USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft 51 TABLE-Felder, 22 Textcollations und die vollständige gleichzeitige
TABLE-/JSON-Parität einschließlich NULLs; JSON ergänzt drei Wait-Felder.
Allgemeine positive Fälle lesen ausschließlich die eigene Session. Der optionale
Block liest drei extern vorbereitete Example-Session-IDs aus SESSION_CONTEXT
(N'ExampleCurrentSessionsFixtureIds'). Er erzeugt weder Workload noch Snapshot-
Tabellen und verändert keine Fixture. Ohne geeigneten Kontext: NOT_EXECUTED.
Native Identitäten und Verbindungsfelder werden vor und nach dem Aufruf geprüft.
Bewegliche Request-/Sessionzähler werden nicht zwischen Aufrufen als atomare
Vollparität behauptet. Die 51 Felder werden innerhalb desselben Aufrufs verglichen.
Die fünf Sortierungen werden akzeptiert; unterschiedliche native Rankinggewinner
sowie RAW- und positive CONSOLE-Vollzeilen benötigen einen separaten Clientcapture.
Berechtigungs-, MARS-, Timeout- und ältere native Enginepfade bleiben offen.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 58600,N'SESSIONS_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58601,N'SESSIONS_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Own smallint=@@SPID,@OwnIds nvarchar(max)=CONVERT(nvarchar(10),@@SPID),
 @OwnLoginTime datetime=(SELECT login_time FROM sys.dm_exec_sessions WHERE session_id=@@SPID),
 @Sql nvarchar(max),@Json nvarchar(max),@TableJson nvarchar(max),@Rows bigint,@Case int,@Native bit,
 @Ids nvarchar(max),@Max int,@Text int,@WithText bit,@Sort varchar(32),@IncludeSelf bit,@Inactive bit,@OwnMode varchar(16),
 @Programs nvarchar(max),@Hosts nvarchar(max),@Pattern nvarchar(4000),@Tools bit,@ExpectedStatus varchar(40),@ExpectedRows int,
 @HasMore bit,@CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,
 @EmptyConsoleCases int=0,@DirectConsoleCases int=0,@FixtureStatus varchar(24)='NOT_EXECUTED';
CREATE TABLE #ExampleSessionsSchema
([SessionId] smallint NOT NULL,
 [RequestId] int NULL,
 [IsUserProcess] bit NOT NULL,
 [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsToolBackgroundQuery] bit NOT NULL,
 [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ClientInterfaceName] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LoginTime] datetime NULL,
 [LastRequestStartTime] datetime NULL,
 [LastRequestEndTime] datetime NULL,
 [DatabaseId] smallint NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [OpenTransactionCount] int NULL,
 [TransactionIsolationLevel] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SessionCpuMs] int NULL,
 [SessionReads] bigint NULL,
 [SessionWrites] bigint NULL,
 [SessionLogicalReads] bigint NULL,
 [SessionMemoryMb] decimal(19,2) NULL,
 [SessionRowCount] bigint NULL,
 [RequestCpuMs] int NULL,
 [RequestElapsedMs] int NULL,
 [RequestLogicalReads] bigint NULL,
 [RequestReads] bigint NULL,
 [RequestWrites] bigint NULL,
 [BlockingSessionId] smallint NULL,
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTimeMs] int NULL,
 [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PercentComplete] real NULL,
 [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CurrentStatementCharacters] bigint NULL,
 [CurrentStatementBytes] bigint NULL,
 [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0),
 [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BatchTextCharacters] bigint NULL,
 [BatchTextBytes] bigint NULL,
 [BatchTextIsTruncated] bit NOT NULL DEFAULT(0),
 [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleSessionsNative
([SessionId] smallint NOT NULL PRIMARY KEY,[IsUserProcess] bit NOT NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ClientInterfaceName] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LoginTime] datetime NOT NULL,
 [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleSessionsAfter FROM #ExampleSessionsNative;
CREATE TABLE #ExampleSessionsFixtureIds([SessionId] smallint NOT NULL PRIMARY KEY);
CREATE TABLE #ExampleSessionsFixtureNames([ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
INSERT #ExampleSessionsFixtureNames VALUES(N'ExampleSessionFixtureÄ🔬'),(N'ExampleSessionFixtureä🔬'),(N'ExampleSessionFixtureActiveÄ🔬');
CREATE TABLE #ExampleSessionsEmptyConsole([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleSessionsPreflight([Dummy] int NULL);
CREATE TABLE #ExampleSessionsCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Ids] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MaxRows] int NULL,[MaxText] int NULL,[WithText] bit NOT NULL,[Sort] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IncludeSelf] bit NOT NULL,[Inactive] bit NOT NULL,[OwnMode] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Programs] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Hosts] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Tools] bit NULL,
 [ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedRows] int NOT NULL);
INSERT #ExampleSessionsCases VALUES
 (0,0,@OwnIds,NULL,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (1,0,@OwnIds,0,NULL,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (2,0,@OwnIds,1,17,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (3,0,@OwnIds,2,18,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (4,0,@OwnIds,0,0,0,'CPU',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (5,0,@OwnIds,0,0,0,'READS',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (6,0,@OwnIds,0,0,0,'WRITES',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (7,0,@OwnIds,0,0,0,'LOGIN',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
 (8,0,@OwnIds+N'|'+@OwnIds,0,0,0,'SESSION',1,1,'NUR',NULL,NULL,NULL,1,'AVAILABLE',1),
 (9,0,@OwnIds,0,0,0,'SESSION',0,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',0),
 (10,0,@OwnIds,-1,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (11,0,@OwnIds,0,-1,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (12,0,N'0',0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (13,0,N'32768',0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (14,0,N'ExampleInvalid',0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (15,0,@OwnIds,0,0,0,'ExampleInvalid',1,1,'ALLE',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (16,0,@OwnIds,0,0,0,'SESSION',1,1,'ExampleInvalid',NULL,NULL,NULL,1,'INVALID_PARAMETER',0),
 (17,0,@OwnIds,0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
 (18,0,@OwnIds,0,0,0,'SESSION',1,1,'ALLE',N'Example',NULL,N'like:Example%',1,'INVALID_PARAMETER',0),
 (19,0,@OwnIds,0,0,0,'SESSION',1,1,'ALLE',N'[ExampleInvalid',NULL,NULL,1,'INVALID_PARAMETER',0);
DECLARE @ContextIds nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentSessionsFixtureIds')),@FixtureIds nvarchar(max),@ActiveIds nvarchar(max),@UpperIds nvarchar(max),@LowerIds nvarchar(max);
IF @ContextIds IS NOT NULL AND
 (SELECT COUNT(*) FROM STRING_SPLIT(@ContextIds,N'|'))=3 AND
 NOT EXISTS(SELECT 1 FROM STRING_SPLIT(@ContextIds,N'|') WHERE TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767) AND
 (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM STRING_SPLIT(@ContextIds,N'|'))=3
BEGIN
 INSERT #ExampleSessionsFixtureIds SELECT CONVERT(smallint,value) FROM STRING_SPLIT(@ContextIds,N'|');
 IF (SELECT COUNT(*) FROM sys.dm_exec_sessions s JOIN #ExampleSessionsFixtureIds f ON s.session_id=f.SessionId
  JOIN #ExampleSessionsFixtureNames n ON s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=n.ProgramName
  WHERE s.is_user_process=1 AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
   AND s.original_login_name COLLATE SQL_Latin1_General_CP1_CS_AS=ORIGINAL_LOGIN() COLLATE SQL_Latin1_General_CP1_CS_AS)=3
  AND (SELECT COUNT(DISTINCT s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS) FROM sys.dm_exec_sessions s JOIN #ExampleSessionsFixtureIds f ON s.session_id=f.SessionId)=3
  AND (SELECT COUNT(*) FROM sys.dm_exec_connections c JOIN #ExampleSessionsFixtureIds f ON c.session_id=f.SessionId)=3
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions s JOIN #ExampleSessionsFixtureIds f ON s.session_id=f.SessionId
   WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureÄ🔬' AND s.status=N'sleeping' AND s.open_transaction_count=0
    AND NOT EXISTS(SELECT 1 FROM sys.dm_exec_requests r WHERE r.session_id=s.session_id))
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions s JOIN #ExampleSessionsFixtureIds f ON s.session_id=f.SessionId WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureä🔬' AND s.status=N'sleeping' AND s.open_transaction_count>0)
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id JOIN #ExampleSessionsFixtureIds f ON r.session_id=f.SessionId WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureActiveÄ🔬' AND r.wait_type=N'WAITFOR')
 BEGIN
  SELECT @FixtureIds=STRING_AGG(CONVERT(nvarchar(max),SessionId),N'|') FROM #ExampleSessionsFixtureIds;
  SELECT @UpperIds=CONVERT(nvarchar(10),session_id) FROM sys.dm_exec_sessions WHERE program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureÄ🔬' AND session_id IN(SELECT SessionId FROM #ExampleSessionsFixtureIds);
  SELECT @LowerIds=CONVERT(nvarchar(10),session_id) FROM sys.dm_exec_sessions WHERE program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureä🔬' AND session_id IN(SELECT SessionId FROM #ExampleSessionsFixtureIds);
  SELECT @ActiveIds=CONVERT(nvarchar(10),session_id) FROM sys.dm_exec_sessions WHERE program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSessionFixtureActiveÄ🔬' AND session_id IN(SELECT SessionId FROM #ExampleSessionsFixtureIds);
  INSERT #ExampleSessionsCases VALUES
   (20,1,@FixtureIds,NULL,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (21,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (22,1,@FixtureIds,1,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
   (23,1,@FixtureIds,2,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',2),
   (24,1,@FixtureIds,0,0,0,'CPU',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (25,1,@FixtureIds,0,0,0,'READS',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (26,1,@FixtureIds,0,0,0,'WRITES',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (27,1,@FixtureIds,0,0,0,'LOGIN',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (28,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',QUOTENAME(N'ExampleSessionFixtureÄ🔬'),NULL,NULL,1,'AVAILABLE',1),
   (29,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',QUOTENAME(N'ExampleSessionFixtureä🔬'),NULL,NULL,1,'AVAILABLE',1),
   (30,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',NULL,QUOTENAME(N'ExampleSessionFixtureä🔬'),NULL,1,'AVAILABLE',1),
   (31,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',N'EXAMPLESessionFixtureÄ🔬',NULL,NULL,1,'AVAILABLE',0),
   (32,1,@FixtureIds,0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,N'like:ExampleSessionFixture%',1,'AVAILABLE',3),
   (33,1,@FixtureIds+N'|'+@UpperIds,0,0,0,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',3),
   (34,1,@FixtureIds,0,0,0,'SESSION',1,0,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',2),
   (35,1,@FixtureIds,0,0,0,'SESSION',1,1,'NUR',NULL,NULL,NULL,1,'AVAILABLE',3),
   (36,1,@FixtureIds,0,0,0,'SESSION',1,1,'AUSSCHLIESSEN',NULL,NULL,NULL,1,'AVAILABLE',0),
   (37,1,@ActiveIds,0,NULL,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
   (38,1,@ActiveIds,0,0,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
   (39,1,@ActiveIds,0,17,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1),
   (40,1,@ActiveIds,0,18,1,'SESSION',1,1,'ALLE',NULL,NULL,NULL,1,'AVAILABLE',1);
  SET @FixtureStatus='PENDING';
 END;
END;

DECLARE @LoadSql nvarchar(max)=N'
INSERT #ExampleSessionsNative
SELECT s.session_id,s.is_user_process,s.login_name,s.original_login_name,s.host_name,s.program_name,s.client_interface_name,s.login_time,
 c.client_net_address,c.net_transport,c.protocol_type,c.encrypt_option,c.auth_scheme
FROM sys.dm_exec_sessions s LEFT JOIN sys.dm_exec_connections c ON c.session_id=s.session_id
WHERE s.session_id IN(SELECT SessionId FROM #ExampleSessionsFixtureIds);';
DECLARE @BeforeJson nvarchar(max),@AfterJson nvarchar(max),@NativeTextJson nvarchar(max),@NativeBatch nvarchar(max),@NativeStatement nvarchar(max);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases184] CURSOR LOCAL FAST_FORWARD FOR SELECT CaseNumber,Native,Ids,MaxRows,MaxText,WithText,Sort,IncludeSelf,Inactive,OwnMode,Programs,Hosts,Pattern,Tools,ExpectedStatus,ExpectedRows FROM #ExampleSessionsCases ORDER BY CaseNumber;
 OPEN [Cases184];
 FETCH NEXT FROM [Cases184] INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Sort,@IncludeSelf,@Inactive,@OwnMode,@Programs,@Hosts,@Pattern,@Tools,@ExpectedStatus,@ExpectedRows;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleSessionsNative;
   EXEC sys.sp_executesql @LoadSql;
   IF (SELECT COUNT(*) FROM #ExampleSessionsNative)<>3 THROW 58602,N'SESSIONS_NATIVE_IDENTITIES',1;
   SELECT @BeforeJson=(SELECT * FROM #ExampleSessionsNative ORDER BY SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @Case BETWEEN 37 AND 40
   BEGIN
    SET @NativeBatch=NULL;SET @NativeStatement=NULL;
    SELECT @NativeBatch=t.text COLLATE SQL_Latin1_General_CP1_CS_AS,
     @NativeStatement=SUBSTRING(t.text COLLATE SQL_Latin1_General_CP1_CS_AS,r.statement_start_offset/2+1,
      (CASE WHEN r.statement_end_offset=-1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END-r.statement_start_offset)/2+1)
    FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.session_id=TRY_CONVERT(smallint,@ActiveIds) AND r.wait_type=N'WAITFOR'
     AND r.statement_start_offset>=0 AND r.statement_start_offset%2=0;
    IF @NativeBatch IS NULL OR @NativeStatement IS NULL THROW 58627,N'SESSIONS_NATIVE_ACTIVE_TEXT',1;
    SELECT @NativeTextJson=(SELECT
     CONVERT(bigint,LEN(@NativeStatement COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1) AS CurrentStatementCharacters,
     DATALENGTH(@NativeStatement) AS CurrentStatementBytes,
     CONVERT(bit,CASE WHEN @Text>0 AND LEN(@NativeStatement COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1>@Text THEN 1 ELSE 0 END) AS CurrentStatementIsTruncated,
     CASE WHEN @Text>0 THEN LEFT(@NativeStatement COLLATE Latin1_General_100_CI_AS_SC,@Text) COLLATE SQL_Latin1_General_CP1_CS_AS ELSE @NativeStatement COLLATE SQL_Latin1_General_CP1_CS_AS END AS CurrentStatement,
     CONVERT(bigint,LEN(@NativeBatch COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1) AS BatchTextCharacters,
     DATALENGTH(@NativeBatch) AS BatchTextBytes,
     CONVERT(bit,CASE WHEN @Text>0 AND LEN(@NativeBatch COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1>@Text THEN 1 ELSE 0 END) AS BatchTextIsTruncated,
     CASE WHEN @Text>0 THEN LEFT(@NativeBatch COLLATE Latin1_General_100_CI_AS_SC,@Text) COLLATE SQL_Latin1_General_CP1_CS_AS ELSE @NativeBatch COLLATE SQL_Latin1_General_CP1_CS_AS END AS BatchText
     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
   END;
  END;

  CREATE TABLE #ExampleSessionsExport([Dummy] int NULL);
  SET @Json=N'ExamplePreviousJson';
  EXEC [monitor].[USP_CurrentSessions] @SessionIds=@Ids,@AktuelleSessionEinbeziehen=@IncludeSelf,
   @ToolHintergrundabfragenEinbeziehen=@Tools,@InaktiveSessionsEinbeziehen=@Inactive,@EigeneSessionsModus=@OwnMode,
   @ProgramNames=@Programs,@HostNames=@Hosts,@ProgramNamePattern=@Pattern,@MitSqlText=@WithText,@MaxSqlTextZeichen=@Text,
   @MaxZeilen=@Max,@Sortierung=@Sort,@ResultSetArt='TABLE',@ResultTablesJson=N'{"sessions":"#ExampleSessionsExport"}',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>137 OR @@SPID<>@Own OR ISJSON(@Json)<>1 THROW 58603,N'SESSIONS_CALLER_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM (VALUES(N'meta'),(N'sessions'),(N'warnings')) v(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE ([key]=N'meta' AND [type]<>5) OR ([key] IN(N'sessions',N'warnings') AND [type]<>4))
    THROW 58604,N'SESSIONS_TOP_KEYS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>12
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'evidenceSnapshotStartedAtUtc'),(N'evidenceSnapshotId'),(N'statusCode'),(N'isPartial'),(N'errorNumber'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows'),(N'toolBackgroundQueriesIncluded')) v(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') p WHERE
    (p.[key] IN(N'resultName',N'generatedAtUtc',N'evidenceSnapshotStartedAtUtc',N'statusCode') AND p.[type]<>1)
    OR (p.[key] IN(N'schemaVersion',N'returnedRows') AND p.[type]<>2)
    OR (p.[key] IN(N'isPartial',N'hasMoreRows') AND p.[type]<>3)
    OR (p.[key] IN(N'evidenceSnapshotId',N'errorNumber') AND p.[type]<>0)
    OR (p.[key]=N'requestedMaxRows' AND p.[type]<>CASE WHEN @Max IS NULL THEN 0 ELSE 2 END)
    OR (p.[key]=N'toolBackgroundQueriesIncluded' AND p.[type]<>CASE WHEN @Tools IS NULL THEN 0 ELSE 3 END))
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>3
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'USP_CurrentSessions'
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@ExpectedStatus
   OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'evidenceSnapshotId' AND [type]=0)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'errorNumber' AND [type]=0)
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   OR (@Max IS NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key]=N'requestedMaxRows' AND [type]=0))
   OR (@Max IS NOT NULL AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),-2147483648)<>@Max)
    THROW 58605,N'SESSIONS_META',1;
  IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsExport')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsSchema'))
   OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsSchema')
   EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsExport'))
    THROW 58606,N'SESSIONS_SCHEMA',1;
  SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleSessionsExport ORDER BY SessionId,RequestId FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleSessionsExport);';
  EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
  SET @TableJson=COALESCE(@TableJson,N'[]');
  SET @HasMore=CASE WHEN @Case IN(22,23) THEN 1 ELSE 0 END;
  IF @Rows<>@ExpectedRows OR @Rows<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sessions'))
   OR @Rows<>ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)
   OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @HasMore=1 THEN N'true' ELSE N'false' END
    THROW 58607,N'SESSIONS_COUNTS_LIMITS',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>54
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT
    SELECT k COLLATE Latin1_General_100_BIN2 FROM
     (SELECT name AS k FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsSchema')
      UNION ALL SELECT k COLLATE SQL_Latin1_General_CP1_CS_AS FROM (VALUES(N'waitGroup'),(N'waitSeverity'),(N'waitMeaning')) v(k)) expectedKeys))
    THROW 58608,N'SESSIONS_JSON_FIELDS',1;
  -- Compare decoded field values and JSON types; property order is not a contract.
  IF EXISTS(SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@TableJson) a CROSS APPLY OPENJSON(a.value) p
   EXCEPT SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p WHERE p.[key] NOT IN(N'waitGroup',N'waitSeverity',N'waitMeaning'))
   OR EXISTS(SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p WHERE p.[key] NOT IN(N'waitGroup',N'waitSeverity',N'waitMeaning')
   EXCEPT SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@TableJson) a CROSS APPLY OPENJSON(a.value) p)
    THROW 58609,N'SESSIONS_TABLE_JSON_FULL_VALUES',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>2
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM (VALUES(N'code'),(N'message')) v(k))
    OR EXISTS(SELECT 1 FROM OPENJSON(a.value) WHERE [type]<>1)
    OR JSON_VALUE(a.value,N'$.code')<>@ExpectedStatus OR JSON_VALUE(a.value,N'$.message') IS NULL)
    THROW 58610,N'SESSIONS_WARNINGS',1;
  IF @WithText=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p
   WHERE (p.[key] IN(N'CurrentStatement',N'BatchText',N'CurrentStatementCharacters',N'BatchTextCharacters',N'CurrentStatementBytes',N'BatchTextBytes') AND p.[type]<>0)
    OR (p.[key] IN(N'CurrentStatementIsTruncated',N'BatchTextIsTruncated') AND (p.[type]<>3 OR p.value<>N'false')))
    THROW 58628,N'SESSIONS_TEXT_DISABLED_NULLS',1;
  IF @Case BETWEEN 37 AND 40 AND
   (EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@NativeTextJson)
    EXCEPT SELECT p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p
     WHERE p.[key] IN(N'CurrentStatement',N'BatchText',N'CurrentStatementCharacters',N'BatchTextCharacters',N'CurrentStatementBytes',N'BatchTextBytes',N'CurrentStatementIsTruncated',N'BatchTextIsTruncated'))
    OR EXISTS(SELECT p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p
     WHERE p.[key] IN(N'CurrentStatement',N'BatchText',N'CurrentStatementCharacters',N'BatchTextCharacters',N'CurrentStatementBytes',N'BatchTextBytes',N'CurrentStatementIsTruncated',N'BatchTextIsTruncated')
     EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,value COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@NativeTextJson)))
    THROW 58629,N'SESSIONS_NATIVE_TEXT_VALUES',1;
  IF @OwnLoginTime IS NULL OR NOT EXISTS(SELECT 1 FROM sys.dm_exec_sessions WHERE session_id=@Own AND login_time=@OwnLoginTime)
   OR (@Native=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE
    ISNULL(TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId')),-1)<>@Own
    OR JSON_VALUE(a.value,N'$.IsUserProcess')<>N'true'
    OR JSON_VALUE(a.value,N'$.OriginalLoginName') COLLATE Latin1_General_100_BIN2<>ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2))
    THROW 58626,N'SESSIONS_OWN_IDENTITY',1;
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleSessionsAfter;
   SET @Sql=REPLACE(@LoadSql,N'INSERT #ExampleSessionsNative',N'INSERT #ExampleSessionsAfter');EXEC sys.sp_executesql @Sql;
   SELECT @AfterJson=(SELECT * FROM #ExampleSessionsAfter ORDER BY SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @BeforeJson COLLATE Latin1_General_100_BIN2<>COALESCE(@AfterJson,N'[]') COLLATE Latin1_General_100_BIN2 THROW 58611,N'SESSIONS_NATIVE_IDENTITY_CHANGED',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE NOT EXISTS(SELECT 1 FROM #ExampleSessionsNative n WHERE n.SessionId=TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId'))))
    THROW 58612,N'SESSIONS_FOREIGN_ROW',1;
   -- Nullable client identity fields are compared by decoded JSON type and value.
   SELECT @BeforeJson=(SELECT * FROM #ExampleSessionsNative ORDER BY SessionId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a CROSS APPLY OPENJSON(a.value) p
    JOIN OPENJSON(@BeforeJson) b ON JSON_VALUE(a.value,N'$.SessionId')=JSON_VALUE(b.value,N'$.SessionId')
    CROSS APPLY OPENJSON(b.value) q WHERE p.[key] COLLATE Latin1_General_100_BIN2=q.[key] COLLATE Latin1_General_100_BIN2
     AND (p.[type]<>q.[type] OR ISNULL(p.value,N'') COLLATE Latin1_General_100_BIN2<>ISNULL(q.value,N'') COLLATE Latin1_General_100_BIN2))
    THROW 58613,N'SESSIONS_NATIVE_IDENTITY_VALUES',1;
   IF @Case IN(22,23) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE
    TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId')) NOT IN(SELECT TOP(@Max) SessionId FROM #ExampleSessionsFixtureIds ORDER BY SessionId))
    THROW 58614,N'SESSIONS_NATIVE_SESSION_RANK',1;
   IF @Case IN(28,29,30) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE
    TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId'))<>TRY_CONVERT(smallint,CASE WHEN @Case=28 THEN @UpperIds ELSE @LowerIds END))
    THROW 58615,N'SESSIONS_EXACT_CASE_FILTER',1;
   IF @Case=34 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a WHERE TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId'))=TRY_CONVERT(smallint,@UpperIds))
    THROW 58616,N'SESSIONS_INACTIVE_FILTER',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sessions') a
    LEFT JOIN monitor.WaitTypeCatalog c ON c.WaitType=JSON_VALUE(a.value,N'$.WaitType') COLLATE SQL_Latin1_General_CP1_CS_AS
    WHERE (JSON_VALUE(a.value,N'$.WaitType') IS NULL AND
     (JSON_VALUE(a.value,N'$.waitGroup')<>N'KEIN_WAIT' OR JSON_VALUE(a.value,N'$.waitSeverity')<>N'2' OR JSON_VALUE(a.value,N'$.waitMeaning')<>N'Der Request wartet aktuell nicht.'))
     OR (JSON_VALUE(a.value,N'$.WaitType')=N'WAITFOR' AND (c.WaitType IS NULL
      OR JSON_VALUE(a.value,N'$.waitGroup') COLLATE Latin1_General_100_BIN2<>c.WaitGroup COLLATE Latin1_General_100_BIN2
      OR ISNULL(TRY_CONVERT(int,JSON_VALUE(a.value,N'$.waitSeverity')),-1)<>c.Severity
      OR JSON_VALUE(a.value,N'$.waitMeaning') COLLATE Latin1_General_100_BIN2<>c.Meaning COLLATE Latin1_General_100_BIN2)))
     THROW 58617,N'SESSIONS_NATIVE_WAIT_CATALOG',1;
   SET @NativeCases+=1;
  END
  ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleSessionsExport;
  FETCH NEXT FROM [Cases184] INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Sort,@IncludeSelf,@Inactive,@OwnMode,@Programs,@Hosts,@Pattern,@Tools,@ExpectedStatus,@ExpectedRows;
 END;
 CLOSE [Cases184];DEALLOCATE [Cases184];
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>21 THROW 58618,N'SESSIONS_NATIVE_CASE_COUNT',1;
  DECLARE @Direct int=0;
  WHILE @Direct<3
  BEGIN
   SET @Max=CASE @Direct WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END;
   EXEC monitor.USP_CurrentSessions @SessionIds=@FixtureIds,@AktuelleSessionEinbeziehen=1,@ToolHintergrundabfragenEinbeziehen=1,
    @MaxZeilen=@Max,@Sortierung='SESSION',@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sessions'))<>CASE @Direct WHEN 0 THEN 3 WHEN 1 THEN 1 ELSE 2 END
    OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR @@LOCK_TIMEOUT<>137 THROW 58619,N'SESSIONS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @Direct+=1;SET @DirectConsoleCases+=1;
  END;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Empty int=0;
 WHILE @Empty<3
 BEGIN
  TRUNCATE TABLE #ExampleSessionsEmptyConsole;
  SET @Max=CASE WHEN @Empty=1 THEN -1 ELSE 0 END;SET @Text=CASE WHEN @Empty=2 THEN -1 ELSE 0 END;
  INSERT #ExampleSessionsEmptyConsole EXEC monitor.USP_CurrentSessions @SessionIds=@OwnIds,@AktuelleSessionEinbeziehen=0,
   @ToolHintergrundabfragenEinbeziehen=1,@MaxZeilen=@Max,@MaxSqlTextZeichen=@Text,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleSessionsEmptyConsole)<>1
   OR EXISTS(SELECT 1 FROM #ExampleSessionsEmptyConsole WHERE Ergebnis<>N'Keine aktiven Sessions' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.sessions')<>N'[]' OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Empty=0 THEN N'AVAILABLE' ELSE N'INVALID_PARAMETER' END
   OR @@LOCK_TIMEOUT<>137 THROW 58620,N'SESSIONS_EMPTY_CONSOLE',1;
  SET @Empty+=1;SET @EmptyConsoleCases+=1;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<3
 BEGIN
  SET @Json=N'ExamplePreviousJson';
  IF @Consumer=0
  BEGIN
   EXEC monitor.USP_CurrentSessions @SessionIds=@OwnIds,@AktuelleSessionEinbeziehen=0,@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF @Json IS NOT NULL THROW 58621,N'SESSIONS_JSON_DISABLED',1;
  END
  ELSE
  BEGIN
   DECLARE @Mode varchar(16)=CASE WHEN @Consumer=1 THEN 'NONE' ELSE 'RAW' END;
   EXEC monitor.USP_CurrentSessions @SessionIds=@OwnIds,@MaxZeilen=-1,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.sessions')<>N'[]' THROW 58622,N'SESSIONS_INVALID_CONSUMER',1;
  END;
  IF @@LOCK_TIMEOUT<>137 THROW 58623,N'SESSIONS_CONSUMER_CALLER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @Preflight int=0,@BadMap nvarchar(max),@Caught int;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleSessionsPreflight"}'
   WHEN 2 THEN N'{"sessions":"#ExampleMissingTarget184"}' WHEN 3 THEN N'{"sessions":"ExamplePermanent"}'
   WHEN 4 THEN N'{"sessions":"#ExampleSessionsPreflight","unknown":"#ExampleSessionsPreflight"}' ELSE N'{"sessions":"#ExampleSessionsPreflight"}' END;
  SET @Caught=0;
  BEGIN TRY
   SET @Mode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
   EXEC monitor.USP_CurrentSessions @SessionIds=@OwnIds,@AktuelleSessionEinbeziehen=0,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleSessionsPreflight'))<>1 THROW 58624,N'SESSIONS_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>20 OR @ConsumerCases<>3 OR @EmptyConsoleCases<>3 OR @PreflightCases<>6 THROW 58625,N'SESSIONS_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,51 AS TableFields,22 AS TextCollations,54 AS JsonSessionFields,
  13 AS CrossCallNativeIdentityFields,@CoreCases AS CoreCases,@FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,
  @ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@EmptyConsoleCases AS EmptySqlConsoleCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 IF OBJECT_ID(N'tempdb..#ExampleSessionsExport') IS NOT NULL DROP TABLE #ExampleSessionsExport;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
