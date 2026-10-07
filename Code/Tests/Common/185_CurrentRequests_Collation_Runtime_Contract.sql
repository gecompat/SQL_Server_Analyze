USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft sieben Literal-Schemata mit 230 Feldern und 66 expliziten Textcollations.
TABLE-/JSON-Parität gilt innerhalb desselben Aufrufs: Legacy52, Kontext73,
Quellstatus11 und Text19/15/13; Warnungs-JSON lässt WarningId aus.
Die universellen positiven Fälle lesen die eigene Session. Optionale drei eigene
WAITFOR-Requests werden ausschließlich über SESSION_CONTEXT
(N'ExampleCurrentRequestsFixtureIds') optiert und anhand nativer Identitäten geprüft.
Kein Workload, keine Fixturemutation, keine Parent-Snapshot-DDL oder neuer Owner.
Stabile Request-/Sessionidentitäten werden vor/nach verglichen; bewegliche Zähler,
Waits, Scheduler, Grants, TempDB und Transaktionsalter erhalten keine atomare
Cross-call-Vollparität. Alle Exportwerte werden gleichaufrufbezogen verglichen.
Positive RAW-/CONSOLE-Facetten und unveränderliche Snapshot-Vollwerte brauchen
separate Root-Clientnachweise. MARS, Berechtigungen, Timeout und ältere Engines offen.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 58700,N'REQUESTS_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58701,N'REQUESTS_FRAMEWORK_COLLATION',1;
DECLARE @OriginalLock int=@@LOCK_TIMEOUT,@Own smallint=@@SPID,@OwnIds nvarchar(max)=CONVERT(nvarchar(10),@@SPID),
 @Sql nvarchar(max),@Json nvarchar(max),@TableJson nvarchar(max),@Rows bigint,@Case int,@Native bit,
 @Ids nvarchar(max),@Max int,@Text int,@WithText bit,@Batch bit,@Input bit,@Module bit,@Sort varchar(32),
 @IncludeSelf bit,@Duration int,@Programs nvarchar(max),@Hosts nvarchar(max),@Pattern nvarchar(4000),@MinCpu bigint,
 @ExpectedStatus varchar(40),@ExpectedRows int,@HasMore bit,@Before nvarchar(max),@After nvarchar(max),
 @Core int=0,@MappingCases int=0,@NativeCases int=0,@Consumers int=0,@Preflights int=0,@EmptyConsole int=0,@DirectConsole int=0,
 @FixtureStatus varchar(24)='NOT_EXECUTED';
CREATE TABLE #ExampleRequestsSchema1
([SessionId] smallint NOT NULL,
 [RequestId] int NOT NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DatabaseId] smallint NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsToolBackgroundQuery] bit NOT NULL,
 [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StartTime] datetime NULL,
 [ElapsedMs] int NULL,
 [CpuMs] int NULL,
 [LogicalReads] bigint NULL,
 [Reads] bigint NULL,
 [Writes] bigint NULL,
 [RowCount] bigint NULL,
 [PercentComplete] real NULL,
 [EstimatedCompletionTimeMs] bigint NULL,
 [BlockingSessionId] smallint NULL,
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTimeMs] int NULL,
 [LastWaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitingTaskCount] int NULL,
 [MaxTaskWaitMs] bigint NULL,
 [TaskWaitTypes] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestedMemoryMb] decimal(19,2) NULL,
 [GrantedMemoryMb] decimal(19,2) NULL,
 [UsedMemoryMb] decimal(19,2) NULL,
 [IdealMemoryMb] decimal(19,2) NULL,
 [Dop] smallint NULL,
 [ParallelWorkerCount] int NULL,
 [TransactionIsolationLevel] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [OpenTransactionCount] int NULL,
 [OpenResultsetCount] int NULL,
 [TransactionId] bigint NULL,
 [ConnectionId] uniqueidentifier NULL,
 [SchedulerId] int NULL,
 [TaskAddress] varbinary(8) NULL,
 [NestLevel] int NULL,
 [WorkloadGroupId] int NULL,
 [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourcePoolId] int NULL,
 [ResourcePoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StatementSqlHandle] varbinary(64) NULL,
 [StatementContextId] bigint NULL,
 [IsResumable] bit NULL,
 [ExecutingManagedCode] bit NULL,
 [ContextInfo] varbinary(128) NULL,
 [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryHash] binary(8) NULL,
 [QueryPlanHash] binary(8) NULL,
 [SqlHandle] varbinary(64) NULL,
 [PlanHandle] varbinary(64) NULL,
 [SqlTextDatabaseId] int NULL,
 [SqlTextObjectId] int NULL,
 [SqlTextObjectNumber] smallint NULL,
 [SqlTextIsEncrypted] bit NULL,
 [ExecutionContextType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ModuleFullName] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HasStatementOffsets] bit NULL,
 [IsStatementOffsetValid] bit NULL,
 [StatementStartOffsetBytes] int NULL,
 [StatementEndOffsetBytes] int NULL,
 [StatementStartCharacter] int NULL,
 [StatementEndCharacter] int NULL,
 [StatementStartLine] int NULL,
 [StatementEndLine] int NULL,
 [CurrentStatementCharacterCount] bigint NULL,
 [CurrentStatementBytes] bigint NULL,
 [CurrentStatementIsTruncated] bit NULL,
 [BatchTextCharacterCount] bigint NULL,
 [BatchTextBytes] bigint NULL,
 [BatchTextIsTruncated] bit NULL,
 [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [InputBufferEventType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [InputBufferParameterCount] smallint NULL,
 [InputBufferCharacterCount] bigint NULL,
 [InputBufferBytes] bigint NULL,
 [InputBufferIsTruncated] bit NULL,
 [InputBufferText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema2
([SnapshotId] uniqueidentifier NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [SessionId] smallint NOT NULL,
 [RequestId] int NOT NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DatabaseId] smallint NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [StartTime] datetime NULL,
 [ElapsedMs] int NULL,
 [CpuMs] int NULL,
 [LogicalReads] bigint NULL,
 [Reads] bigint NULL,
 [Writes] bigint NULL,
 [RowCount] bigint NULL,
 [PercentComplete] real NULL,
 [EstimatedCompletionTimeMs] bigint NULL,
 [BlockingSessionId] smallint NULL,
 [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitTimeMs] bigint NULL,
 [WaitResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ConnectionId] uniqueidentifier NULL,
 [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [TaskCount] int NULL,
 [WorkerCount] int NULL,
 [ExecutionContextCount] int NULL,
 [RunnableTaskCount] int NULL,
 [SuspendedTaskCount] int NULL,
 [SchedulerId] int NULL,
 [SchedulerStatus] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SchedulerParentNodeId] int NULL,
 [SchedulerRunnableTaskCount] int NULL,
 [SchedulerWorkQueueCount] bigint NULL,
 [SchedulerPendingDiskIoCount] int NULL,
 [SchedulerLoadFactor] int NULL,
 [TransactionId] bigint NULL,
 [TransactionBeginTime] datetime NULL,
 [TransactionAgeSeconds] bigint NULL,
 [TransactionType] int NULL,
 [TransactionState] int NULL,
 [IsUserTransaction] bit NULL,
 [IsLocalTransaction] bit NULL,
 [IsEnlistedTransaction] bit NULL,
 [IsBoundTransaction] bit NULL,
 [TransactionLogBytesUsed] bigint NULL,
 [TransactionLogBytesReserved] bigint NULL,
 [RequestedMemoryMb] decimal(19,2) NULL,
 [GrantedMemoryMb] decimal(19,2) NULL,
 [UsedMemoryMb] decimal(19,2) NULL,
 [IdealMemoryMb] decimal(19,2) NULL,
 [TempDbSessionNetMb] decimal(19,2) NULL,
 [TempDbRequestNetMb] decimal(19,2) NULL,
 [Dop] smallint NULL,
 [ParallelWorkerCount] int NULL,
 [WorkloadGroupId] int NULL,
 [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourcePoolId] int NULL,
 [ResourcePoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [QueryHash] binary(8) NULL,
 [QueryPlanHash] binary(8) NULL,
 [SqlHandle] varbinary(64) NULL,
 [PlanHandle] varbinary(64) NULL,
 [StatementSqlHandle] varbinary(64) NULL,
 [StatementContextId] bigint NULL,
 [ModuleFullName] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsCurrent] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsPartial] bit NOT NULL,
 [EvidenceBoundary] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema3
([SourceOrdinal] int NOT NULL,
 [SnapshotId] uniqueidentifier NOT NULL,
 [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [CompletedAtUtc] datetime2(3) NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsPartial] bit NOT NULL,
 [CapturedRowCount] bigint NOT NULL,
 [ErrorNumber] int NULL,
 [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema4
([SnapshotId] uniqueidentifier NOT NULL,
 [SessionId] smallint NOT NULL,
 [RequestId] int NOT NULL,
 [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [HasStatementOffsets] bit NULL,
 [IsStatementOffsetValid] bit NULL,
 [StartOffsetBytes] int NULL,
 [EndOffsetBytes] int NULL,
 [StartCharacter] int NULL,
 [EndCharacter] int NULL,
 [StartLine] int NULL,
 [EndLine] int NULL,
 [CharacterCount] bigint NULL,
 [Bytes] bigint NULL,
 [IsTruncated] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema5
([SnapshotId] uniqueidentifier NOT NULL,
 [SessionId] smallint NOT NULL,
 [RequestId] int NOT NULL,
 [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [SqlTextDatabaseId] int NULL,
 [SqlTextObjectId] int NULL,
 [SqlTextObjectNumber] smallint NULL,
 [IsEncrypted] bit NULL,
 [CharacterCount] bigint NULL,
 [Bytes] bigint NULL,
 [IsTruncated] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema6
([SnapshotId] uniqueidentifier NOT NULL,
 [SessionId] smallint NOT NULL,
 [RequestId] int NOT NULL,
 [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [EventType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ParameterCount] smallint NULL,
 [CharacterCount] bigint NULL,
 [Bytes] bigint NULL,
 [IsTruncated] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsSchema7
([WarningId] int NOT NULL,
 [SessionId] smallint NULL,
 [RequestId] int NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Code] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleRequestsMaps
(ResultName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,SchemaTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 TargetTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,MaskValue int NOT NULL,FieldCount int NOT NULL,OrderExpression nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExampleRequestsMaps VALUES
(N'requests',N'#ExampleRequestsSchema1',N'#ExampleRequestsExport1',1,93,N'SessionId,RequestId'),
(N'requestContext',N'#ExampleRequestsSchema2',N'#ExampleRequestsExport2',2,73,N'SessionId,RequestId'),
(N'snapshotStatus',N'#ExampleRequestsSchema3',N'#ExampleRequestsExport3',4,11,N'SourceOrdinal'),
(N'statements',N'#ExampleRequestsSchema4',N'#ExampleRequestsExport4',8,19,N'SessionId,RequestId'),
(N'batches',N'#ExampleRequestsSchema5',N'#ExampleRequestsExport5',16,15,N'SessionId,RequestId'),
(N'inputBuffers',N'#ExampleRequestsSchema6',N'#ExampleRequestsExport6',32,13,N'SessionId,RequestId'),
(N'warnings',N'#ExampleRequestsSchema7',N'#ExampleRequestsExport7',64,6,N'WarningId');
DECLARE @CallMap nvarchar(max),@Mask int,@Requested bit, @AllMap nvarchar(max)=N'{"requests":"#ExampleRequestsExport1","requestContext":"#ExampleRequestsExport2","snapshotStatus":"#ExampleRequestsExport3","statements":"#ExampleRequestsExport4","batches":"#ExampleRequestsExport5","inputBuffers":"#ExampleRequestsExport6","warnings":"#ExampleRequestsExport7"}';
CREATE TABLE #ExampleRequestsEmptyConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE #ExampleRequestsPreflight(Dummy int NULL);
CREATE TABLE #ExampleRequestsFixtureIds(SessionId smallint NOT NULL PRIMARY KEY);
CREATE TABLE #ExampleRequestsFixtureNames(ProgramName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
INSERT #ExampleRequestsFixtureNames VALUES(N'ExampleRequestFixtureÄ🔬'),(N'ExampleRequestFixtureä🔬'),(N'ExampleRequestFixtureModuleÄ🔬');
CREATE TABLE #ExampleRequestsNative
(SessionId smallint NOT NULL,RequestId int NOT NULL,StartTime datetime NOT NULL,DatabaseId smallint NOT NULL,
 LoginName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,OriginalLoginName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 HostName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,ProgramName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 SqlHandle varbinary(64) NULL,PlanHandle varbinary(64) NULL,ConnectionId uniqueidentifier NULL);
SELECT TOP(0) * INTO #ExampleRequestsAfter FROM #ExampleRequestsNative;
CREATE TABLE #ExampleRequestsTextNative(SessionId smallint NOT NULL,RequestId int NOT NULL,Kind sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 CharacterCount bigint NULL,Bytes bigint NULL,IsTruncated bit NOT NULL,Text nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
DECLARE @NativeTextSql nvarchar(max)=N'
 INSERT #ExampleRequestsTextNative SELECT r.session_id,r.request_id,v.Kind,
 CONVERT(bigint,LEN(v.FullText COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1),CONVERT(bigint,DATALENGTH(v.FullText)),
 CONVERT(bit,CASE WHEN @max>0 AND LEN(v.FullText COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1>@max THEN 1 ELSE 0 END),
 CASE WHEN @max>0 THEN LEFT(v.FullText COLLATE Latin1_General_100_CI_AS_SC,@max) COLLATE SQL_Latin1_General_CP1_CS_AS ELSE v.FullText COLLATE SQL_Latin1_General_CP1_CS_AS END
 FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle)t
 CROSS APPLY(VALUES(N''statements'',SUBSTRING(t.text COLLATE SQL_Latin1_General_CP1_CS_AS,r.statement_start_offset/2+1,
 (CASE WHEN r.statement_end_offset=-1 THEN DATALENGTH(t.text) ELSE r.statement_end_offset END-r.statement_start_offset)/2+1)),(N''batches'',t.text COLLATE SQL_Latin1_General_CP1_CS_AS))v(Kind,FullText)
 WHERE r.session_id=@id AND r.wait_type=N''WAITFOR'' AND t.text IS NOT NULL AND r.statement_start_offset>=0 AND r.statement_start_offset%2=0
 AND (r.statement_end_offset=-1 OR (r.statement_end_offset>=r.statement_start_offset AND r.statement_end_offset%2=0 AND r.statement_end_offset<=DATALENGTH(t.text)));';
DECLARE @Load nvarchar(max)=N'INSERT #ExampleRequestsNative SELECT r.session_id,r.request_id,r.start_time,r.database_id,s.login_name,s.original_login_name,s.host_name,s.program_name,r.sql_handle,r.plan_handle,c.connection_id
 FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id LEFT JOIN sys.dm_exec_connections c ON c.session_id=r.session_id
 WHERE r.session_id IN(SELECT SessionId FROM #ExampleRequestsFixtureIds);';
CREATE TABLE #ExampleRequestsCases
(CaseNumber int NOT NULL,Native bit NOT NULL,Ids nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,MaxRows int NULL,MaxText int NULL,
 WithText bit NOT NULL,Batch bit NOT NULL,InputBuffer bit NOT NULL,Module bit NOT NULL,Sort varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 IncludeSelf bit NOT NULL,DurationSeconds int NULL,Programs nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hosts nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Pattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,MinCpu bigint NULL,ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,ExpectedRows int NOT NULL);
INSERT #ExampleRequestsCases VALUES
(0,0,@OwnIds,NULL,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(1,0,@OwnIds,0,NULL,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(2,0,@OwnIds,1,20,1,1,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(3,0,@OwnIds,2,21,1,1,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(4,0,@OwnIds,0,0,0,0,0,0,'CPU',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(5,0,@OwnIds,0,0,0,0,0,0,'READS',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(6,0,@OwnIds,0,0,0,0,0,0,'DAUER',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(7,0,@OwnIds,0,0,0,0,0,0,'RELEVANZ',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(8,0,@OwnIds+N'|'+@OwnIds,0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(9,0,@OwnIds,0,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',0),
(10,0,@OwnIds,-1,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(11,0,@OwnIds,0,-1,1,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(12,0,@OwnIds,0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,-1,'INVALID_PARAMETER',0),
(13,0,N'ExampleInvalid',0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(14,0,N'0',0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(15,0,N'32768',0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(16,0,@OwnIds,0,0,0,0,0,0,'ExampleInvalid',1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER',0),
(17,0,@OwnIds,0,0,0,0,0,0,'SESSION',1,NULL,N'Example',NULL,N'like:Example%',NULL,'INVALID_PARAMETER',0),
(18,0,@OwnIds,0,0,0,0,0,0,'SESSION',1,NULL,N'[ExampleInvalid',NULL,NULL,NULL,'INVALID_PARAMETER',0),
(19,0,@OwnIds,0,0,1,1,1,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
(40,0,@OwnIds,0,0,0,0,0,0,'SESSION',1,2147483647,NULL,NULL,NULL,NULL,'AVAILABLE',0);
DECLARE @M int=100;
WHILE @M<109
BEGIN
 INSERT #ExampleRequestsCases VALUES(@M,0,@OwnIds,0,0,0,0,0,0,'SESSION',1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1);
 SET @M+=1;
END;
DECLARE @ContextIds nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentRequestsFixtureIds')),@FixtureIds nvarchar(max),@Upper nvarchar(max),@Lower nvarchar(max),@ModuleIds nvarchar(max);
IF @ContextIds IS NOT NULL AND (SELECT COUNT(*) FROM STRING_SPLIT(@ContextIds,N'|'))=3
 AND NOT EXISTS(SELECT 1 FROM STRING_SPLIT(@ContextIds,N'|') WHERE TRY_CONVERT(int,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
 AND (SELECT COUNT(DISTINCT TRY_CONVERT(int,value)) FROM STRING_SPLIT(@ContextIds,N'|'))=3
BEGIN
 INSERT #ExampleRequestsFixtureIds SELECT CONVERT(smallint,value) FROM STRING_SPLIT(@ContextIds,N'|');
 IF (SELECT COUNT(*) FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id JOIN #ExampleRequestsFixtureIds f ON f.SessionId=r.session_id
  JOIN #ExampleRequestsFixtureNames n ON n.ProgramName=s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS
  WHERE r.command=N'WAITFOR' AND r.wait_type=N'WAITFOR' AND s.is_user_process=1
   AND s.host_name COLLATE Latin1_General_100_BIN2=s.program_name COLLATE Latin1_General_100_BIN2
   AND s.original_login_name COLLATE Latin1_General_100_BIN2=ORIGINAL_LOGIN() COLLATE Latin1_General_100_BIN2)=3
  AND (SELECT COUNT(DISTINCT s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS) FROM sys.dm_exec_sessions s JOIN #ExampleRequestsFixtureIds f ON f.SessionId=s.session_id)=3
  AND (SELECT COUNT(*) FROM sys.dm_exec_connections c JOIN #ExampleRequestsFixtureIds f ON f.SessionId=c.session_id)=3
  AND EXISTS(SELECT 1 FROM sys.dm_exec_sessions s JOIN #ExampleRequestsFixtureIds f ON f.SessionId=s.session_id WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRequestFixtureä🔬' AND s.open_transaction_count>0)
  AND EXISTS(SELECT 1 FROM sys.dm_exec_requests r JOIN sys.dm_exec_sessions s ON s.session_id=r.session_id JOIN #ExampleRequestsFixtureIds f ON f.SessionId=r.session_id CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
   WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRequestFixtureModuleÄ🔬' AND t.objectid>0 AND t.dbid IS NOT NULL)
 BEGIN
  SELECT @FixtureIds=STRING_AGG(CONVERT(nvarchar(max),SessionId),N'|') FROM #ExampleRequestsFixtureIds;
  SELECT @Upper=CONVERT(nvarchar(10),s.session_id) FROM sys.dm_exec_sessions s JOIN #ExampleRequestsFixtureIds f ON f.SessionId=s.session_id WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRequestFixtureÄ🔬';
  SELECT @Lower=CONVERT(nvarchar(10),s.session_id) FROM sys.dm_exec_sessions s JOIN #ExampleRequestsFixtureIds f ON f.SessionId=s.session_id WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRequestFixtureä🔬';
  SELECT @ModuleIds=CONVERT(nvarchar(10),s.session_id) FROM sys.dm_exec_sessions s JOIN #ExampleRequestsFixtureIds f ON f.SessionId=s.session_id WHERE s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRequestFixtureModuleÄ🔬';
  INSERT #ExampleRequestsCases VALUES
  (20,1,@FixtureIds,NULL,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (21,1,@FixtureIds,0,NULL,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (22,1,@FixtureIds,1,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (23,1,@FixtureIds,2,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',2),
  (24,1,@FixtureIds,0,0,0,0,0,0,'CPU',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (25,1,@FixtureIds,0,0,0,0,0,0,'READS',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (26,1,@FixtureIds,0,0,0,0,0,0,'DAUER',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (27,1,@FixtureIds,0,0,0,0,0,0,'RELEVANZ',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (28,1,@FixtureIds,0,0,0,0,0,0,'SESSION',0,NULL,QUOTENAME(N'ExampleRequestFixtureÄ🔬'),NULL,NULL,NULL,'AVAILABLE',1),
  (29,1,@FixtureIds,0,0,0,0,0,0,'SESSION',0,NULL,QUOTENAME(N'ExampleRequestFixtureä🔬'),NULL,NULL,NULL,'AVAILABLE',1),
  (30,1,@FixtureIds,0,0,0,0,0,0,'SESSION',0,NULL,NULL,QUOTENAME(N'ExampleRequestFixtureä🔬'),NULL,NULL,'AVAILABLE',1),
  (31,1,@FixtureIds,0,0,0,0,0,0,'SESSION',0,NULL,N'EXAMPLERequestFixtureÄ🔬',NULL,NULL,NULL,'AVAILABLE',0),
  (32,1,@FixtureIds,0,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,N'like:ExampleRequestFixture%',NULL,'AVAILABLE',3),
  (33,1,@FixtureIds+N'|'+@Upper,0,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',3),
  (34,1,@Upper,0,NULL,1,1,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (35,1,@Upper,0,0,1,1,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (36,1,@Upper,0,20,1,1,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (37,1,@Upper,0,21,1,1,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (38,1,@Lower,0,0,0,0,0,0,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1),
  (39,1,@ModuleIds,0,0,1,1,1,1,'SESSION',0,NULL,NULL,NULL,NULL,NULL,'AVAILABLE',1);
  SET @FixtureStatus='PENDING';
 END;
END;
DECLARE @Result sysname,@Schema sysname,@Target sysname,@Fields int,@Order nvarchar(128),@Object int,@Template int,@Path nvarchar(128);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE Cases185 CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleRequestsCases ORDER BY CaseNumber;
 OPEN Cases185;
 FETCH NEXT FROM Cases185 INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Batch,@Input,@Module,@Sort,@IncludeSelf,@Duration,@Programs,@Hosts,@Pattern,@MinCpu,@ExpectedStatus,@ExpectedRows;
 WHILE @@FETCH_STATUS=0
 BEGIN
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleRequestsNative;EXEC sys.sp_executesql @Load;
   IF (SELECT COUNT(*) FROM #ExampleRequestsNative)<>3 THROW 58702,N'REQUESTS_NATIVE_IDENTITIES',1;
   SELECT @Before=(SELECT * FROM #ExampleRequestsNative ORDER BY SessionId,RequestId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @Case BETWEEN 34 AND 39 AND @WithText=1
   BEGIN
    TRUNCATE TABLE #ExampleRequestsTextNative;
    DECLARE @SelectedId smallint=TRY_CONVERT(smallint,@Ids);
    EXEC sys.sp_executesql @NativeTextSql,N'@id smallint,@max int',@SelectedId,@Text;
    IF (SELECT COUNT(*) FROM #ExampleRequestsTextNative)<>2 THROW 58730,N'REQUESTS_NATIVE_TEXT_PRECONDITION',1;
   END;
  END;
  CREATE TABLE #ExampleRequestsExport1(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport2(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport3(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport4(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport5(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport6(Dummy int NULL);
  CREATE TABLE #ExampleRequestsExport7(Dummy int NULL);
  SET @Mask=CASE WHEN @Case BETWEEN 100 AND 106 THEN CONVERT(int,POWER(2,@Case-100)) WHEN @Case=107 THEN 5 WHEN @Case=108 THEN 65 ELSE 127 END;
  SELECT @CallMap=N'{'+STRING_AGG(CONVERT(nvarchar(max),N'"'+ResultName+N'":"'+TargetTable+N'"'),N',')+N'}' FROM #ExampleRequestsMaps WHERE (MaskValue & @Mask)<>0;
  SET @Sql=N'';SELECT @Sql+=N'INSERT '+QUOTENAME(TargetTable)+N' VALUES(4242);' FROM #ExampleRequestsMaps WHERE (MaskValue & @Mask)=0;IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
  SET @Json=N'ExamplePrevious';
  EXEC monitor.USP_CurrentRequests @SessionIds=@Ids,@AktuelleSessionEinbeziehen=@IncludeSelf,@ToolHintergrundabfragenEinbeziehen=1,
   @ProgramNames=@Programs,@HostNames=@Hosts,@ProgramNamePattern=@Pattern,@MinCpuMs=@MinCpu,@MinLaufzeitSekunden=@Duration,@MitSqlText=@WithText,
   @GesamtenSqlTextEinbeziehen=@Batch,@InputBufferEinbeziehen=@Input,@ModulInfoEinbeziehen=@Module,
   @MaxSqlTextZeichen=@Text,@MaxZeilen=@Max,@Sortierung=@Sort,@ResultSetArt='TABLE',@ResultTablesJson=@CallMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>137 OR @@SPID<>@Own OR ISJSON(@Json)<>1 THROW 58703,N'REQUESTS_CALLER_JSON',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>8
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM (VALUES(N'meta'),(N'requests'),(N'requestContext'),(N'snapshotStatus'),(N'statements'),(N'batches'),(N'inputBuffers'),(N'warnings'))v(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE WHEN [key]=N'meta' THEN 5 ELSE 4 END) THROW 58704,N'REQUESTS_TOP',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>16
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k COLLATE Latin1_General_100_BIN2 FROM
    (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'evidenceSnapshotStartedAtUtc'),(N'evidenceSnapshotId'),(N'statusCode'),(N'isPartial'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows'),(N'statementTextIncluded'),(N'batchTextIncluded'),(N'inputBufferIncluded'),(N'moduleInfoIncluded'),(N'maxSqlTextCharacters'),(N'toolBackgroundQueriesIncluded'))v(k))
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'USP_CurrentRequests' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>4
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@ExpectedStatus OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL THROW 58705,N'REQUESTS_META',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta')p WHERE
   (p.[key] IN(N'resultName',N'generatedAtUtc',N'evidenceSnapshotStartedAtUtc',N'evidenceSnapshotId',N'statusCode') AND p.[type]<>1)
   OR (p.[key] IN(N'schemaVersion',N'returnedRows') AND p.[type]<>2)
   OR (p.[key] IN(N'isPartial',N'hasMoreRows',N'statementTextIncluded',N'batchTextIncluded',N'inputBufferIncluded',N'moduleInfoIncluded',N'toolBackgroundQueriesIncluded') AND p.[type]<>3)
   OR (p.[key]=N'requestedMaxRows' AND p.[type]<>CASE WHEN @Max IS NULL THEN 0 ELSE 2 END)
   OR (p.[key]=N'maxSqlTextCharacters' AND p.[type]<>CASE WHEN @Text IS NULL THEN 0 ELSE 2 END))
   OR JSON_VALUE(@Json,N'$.meta.statementTextIncluded')<>CASE WHEN @WithText=1 THEN N'true' ELSE N'false' END
   OR JSON_VALUE(@Json,N'$.meta.batchTextIncluded')<>CASE WHEN @Batch=1 THEN N'true' ELSE N'false' END
   OR JSON_VALUE(@Json,N'$.meta.inputBufferIncluded')<>CASE WHEN @Input=1 THEN N'true' ELSE N'false' END
   OR JSON_VALUE(@Json,N'$.meta.moduleInfoIncluded')<>CASE WHEN @Module=1 THEN N'true' ELSE N'false' END
   OR (@Max IS NOT NULL AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),-2147483648)<>@Max)
   OR (@Text IS NOT NULL AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.maxSqlTextCharacters')),-2147483648)<>@Text) THROW 58732,N'REQUESTS_META_TYPES_VALUES',1;
  SET @HasMore=CASE WHEN @Case IN(22,23) THEN 1 ELSE 0 END;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.requests'))<>@ExpectedRows
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@ExpectedRows
   OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @HasMore=1 THEN N'true' ELSE N'false' END THROW 58706,N'REQUESTS_COUNTS',1;
  DECLARE Maps185 CURSOR LOCAL FAST_FORWARD FOR SELECT ResultName,SchemaTable,TargetTable,FieldCount,OrderExpression FROM #ExampleRequestsMaps WHERE (MaskValue & @Mask)<>0;
  OPEN Maps185;FETCH NEXT FROM Maps185 INTO @Result,@Schema,@Target,@Fields,@Order;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @Object=OBJECT_ID(N'tempdb..'+@Target);SET @Template=OBJECT_ID(N'tempdb..'+@Schema);
   IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Object
    EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Template)
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Template
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Object) THROW 58707,N'REQUESTS_SCHEMA',1;
   SET @Path=N'$.'+@Result;
   SET @Sql=N'SELECT @j=(SELECT '+CASE WHEN @Result=N'warnings' THEN N'SessionId AS sessionId,RequestId AS requestId,DatabaseName AS databaseName,Code AS code,Message AS message' ELSE N'*' END+N' FROM '+QUOTENAME(@Target)+N' ORDER BY '+@Order+N' FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@Target)+N');';
   IF @Result=N'requests' SET @Sql=N'SELECT @j=(SELECT [r].[SessionId] AS [sessionId] , [r].[RequestId] AS [requestId] , [r].[RequestStatus] AS [requestStatus] , [r].[Command] AS [command] , [r].[DatabaseId] AS [databaseId] , [r].[DatabaseName] AS [databaseName] , [r].[LoginName] AS [loginName] , [r].[HostName] AS [hostName] , [r].[ProgramName] AS [programName] , [r].[IsToolBackgroundQuery] AS [isToolBackgroundQuery] , [r].[ToolBackgroundRuleCode] AS [toolBackgroundRuleCode] , [r].[ToolBackgroundCategory] AS [toolBackgroundCategory] , [r].[ToolBackgroundDetection] AS [toolBackgroundDetection] , [r].[ToolBackgroundConfidence] AS [toolBackgroundConfidence] , [r].[StartTime] AS [startTime] , [r].[ElapsedMs] AS [elapsedMs] , [r].[CpuMs] AS [cpuMs] , [r].[LogicalReads] AS [logicalReads] , [r].[Writes] AS [writes] , [r].[BlockingSessionId] AS [blockingSessionId] , [r].[WaitType] AS [waitType] , [wi].[WaitGroup] AS [waitGroup] , [wi].[Severity] AS [waitSeverity] , [r].[WaitTimeMs] AS [waitTimeMs] , [r].[RequestedMemoryMb] AS [requestedMemoryMb] , [r].[GrantedMemoryMb] AS [grantedMemoryMb] , [r].[UsedMemoryMb] AS [usedMemoryMb] , [r].[Dop] AS [dop] , [r].[ParallelWorkerCount] AS [parallelWorkerCount] , [r].[SchedulerId] AS [schedulerId] , [r].[TaskAddress] AS [taskAddress] , [r].[NestLevel] AS [nestLevel] , [r].[OpenTransactionCount] AS [openTransactionCount] , [r].[OpenResultsetCount] AS [openResultsetCount] , [r].[TransactionId] AS [transactionId] , [r].[ConnectionId] AS [connectionId] , [r].[WorkloadGroupId] AS [workloadGroupId] , [r].[WorkloadGroupName] AS [workloadGroupName] , [r].[ResourcePoolId] AS [resourcePoolId] , [r].[ResourcePoolName] AS [resourcePoolName] , [r].[StatementSqlHandle] AS [statementSqlHandle] , [r].[StatementContextId] AS [statementContextId] , [r].[IsResumable] AS [isResumable] , [r].[ExecutingManagedCode] AS [executingManagedCode] , [r].[ContextInfo] AS [contextInfo] , [r].[ModuleFullName] AS [moduleFullName] , [r].[ModuleTypeDescription] AS [moduleTypeDescription] , [r].[ExecutionContextType] AS [executionContextType] , [r].[QueryHash] AS [queryHash] , [r].[QueryPlanHash] AS [queryPlanHash] , [r].[SqlHandle] AS [sqlHandle] , [r].[PlanHandle] AS [planHandle] FROM #ExampleRequestsExport1 r CROSS APPLY monitor.TVF_WaitTypeInfo(r.WaitType) wi ORDER BY r.SessionId,r.RequestId FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM #ExampleRequestsExport1);';
   EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;SET @TableJson=COALESCE(@TableJson,N'[]');
   IF @Rows<>(SELECT COUNT(*) FROM OPENJSON(@Json,@Path)) OR (@Result IN(N'requests',N'requestContext',N'statements',N'batches',N'inputBuffers') AND @Rows<>@ExpectedRows) THROW 58708,N'REQUESTS_ARRAY_COUNTS',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path) a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>CASE WHEN @Result=N'requests' THEN 52 WHEN @Result=N'warnings' THEN 5 ELSE @Fields END
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)) THROW 58709,N'REQUESTS_ARRAY_FIELDS',1;
   IF EXISTS(SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@TableJson) a CROSS APPLY OPENJSON(a.value)p
    EXCEPT SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,@Path)a CROSS APPLY OPENJSON(a.value)p)
    OR EXISTS(SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@Json,@Path)a CROSS APPLY OPENJSON(a.value)p
     EXCEPT SELECT a.[key],p.[key] COLLATE Latin1_General_100_BIN2,p.value COLLATE Latin1_General_100_BIN2,p.[type] FROM OPENJSON(@TableJson)a CROSS APPLY OPENJSON(a.value)p) THROW 58710,N'REQUESTS_FULL_TABLE_JSON_VALUES',1;
   IF @Result IN(N'requestContext',N'snapshotStatus',N'statements',N'batches',N'inputBuffers') AND EXISTS(SELECT 1 FROM OPENJSON(@Json,@Path)a
    WHERE JSON_VALUE(a.value,N'$.SnapshotId')<>JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId') OR TRY_CONVERT(datetime2(3),JSON_VALUE(a.value,N'$.CapturedAtUtc')) IS NULL) THROW 58711,N'REQUESTS_PROVENANCE',1;
   FETCH NEXT FROM Maps185 INTO @Result,@Schema,@Target,@Fields,@Order;
  END;
  CLOSE Maps185;DEALLOCATE Maps185;
  DECLARE Unmapped185 CURSOR LOCAL FAST_FORWARD FOR SELECT TargetTable FROM #ExampleRequestsMaps WHERE (MaskValue & @Mask)=0;
  OPEN Unmapped185;FETCH NEXT FROM Unmapped185 INTO @Target;
  WHILE @@FETCH_STATUS=0
  BEGIN
   IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target))<>1 OR NOT EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target) AND name=N'Dummy') THROW 58728,N'REQUESTS_UNMAPPED_SCHEMA',1;
   SET @Sql=N'SELECT @r=COUNT_BIG(*) FROM '+QUOTENAME(@Target)+N' WHERE Dummy=4242;';EXEC sys.sp_executesql @Sql,N'@r bigint OUTPUT',@Rows OUTPUT;
   IF @Rows<>1 THROW 58729,N'REQUESTS_UNMAPPED_SENTINEL',1;
   FETCH NEXT FROM Unmapped185 INTO @Target;
  END;
  CLOSE Unmapped185;DEALLOCATE Unmapped185;
  IF @ExpectedStatus=N'AVAILABLE'
  BEGIN
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.snapshotStatus'))<>17
    OR EXISTS(SELECT JSON_VALUE(value,N'$.SourceCode') FROM OPENJSON(@Json,N'$.snapshotStatus') GROUP BY JSON_VALUE(value,N'$.SourceCode') HAVING COUNT(*)<>1)
    OR EXISTS(SELECT JSON_VALUE(value,N'$.SourceCode') COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,N'$.snapshotStatus') EXCEPT
     SELECT k COLLATE Latin1_General_100_BIN2 FROM(VALUES(N'SESSIONS'),(N'REQUESTS'),(N'CONNECTIONS'),(N'WAITING_TASKS'),(N'MEMORY_GRANTS'),(N'WORKLOAD_GROUPS'),(N'RESOURCE_POOLS'),(N'TASKS'),(N'SCHEDULERS'),(N'SESSION_TRANSACTIONS'),(N'ACTIVE_TRANSACTIONS'),(N'DATABASE_TRANSACTIONS'),(N'TEMPDB_SESSION_USAGE'),(N'TEMPDB_TASK_USAGE'),(N'SQL_TEXT'),(N'INPUT_BUFFER'),(N'MODULE_CATALOG'))v(k)) THROW 58712,N'REQUESTS_SOURCE_SET',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.statements') WHERE JSON_VALUE(value,N'$.StatusCode')<>CASE WHEN @WithText=0 THEN N'NOT_COLLECTED' ELSE CASE WHEN JSON_VALUE(value,N'$.IsTruncated')=N'true' THEN N'TEXT_TRUNCATED' ELSE N'AVAILABLE' END END)
    OR (@WithText=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.statements') WHERE JSON_VALUE(value,N'$.Text') IS NOT NULL))
    OR (@Batch=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.batches') WHERE JSON_VALUE(value,N'$.StatusCode')<>N'NOT_COLLECTED' OR JSON_VALUE(value,N'$.Text') IS NOT NULL))
    OR (@Input=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inputBuffers') WHERE JSON_VALUE(value,N'$.StatusCode')<>N'NOT_COLLECTED' OR JSON_VALUE(value,N'$.Text') IS NOT NULL)) THROW 58713,N'REQUESTS_TEXT_OMISSIONS',1;
  END;
  IF @Native=1
  BEGIN
   TRUNCATE TABLE #ExampleRequestsAfter;SET @Sql=REPLACE(@Load,N'INSERT #ExampleRequestsNative',N'INSERT #ExampleRequestsAfter');EXEC sys.sp_executesql @Sql;
   SELECT @After=(SELECT * FROM #ExampleRequestsAfter ORDER BY SessionId,RequestId FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @Before COLLATE Latin1_General_100_BIN2<>COALESCE(@After,N'[]') COLLATE Latin1_General_100_BIN2 THROW 58714,N'REQUESTS_NATIVE_IDENTITY_DRIFT',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requestContext')a WHERE NOT EXISTS(SELECT 1 FROM #ExampleRequestsNative n WHERE n.SessionId=TRY_CONVERT(int,JSON_VALUE(a.value,N'$.SessionId')) AND n.RequestId=TRY_CONVERT(int,JSON_VALUE(a.value,N'$.RequestId')))) THROW 58715,N'REQUESTS_FOREIGN_ROW',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requests')a CROSS APPLY OPENJSON(a.value)p JOIN OPENJSON(@Before)b ON JSON_VALUE(a.value,N'$.sessionId')=JSON_VALUE(b.value,N'$.SessionId') CROSS APPLY OPENJSON(b.value)q
    WHERE p.[key] COLLATE Latin1_General_100_BIN2=LOWER(LEFT(q.[key],1))+SUBSTRING(q.[key],2,128) COLLATE Latin1_General_100_BIN2
     AND (p.[type]<>q.[type] OR ISNULL(p.value,N'') COLLATE Latin1_General_100_BIN2<>ISNULL(q.value,N'') COLLATE Latin1_General_100_BIN2)) THROW 58716,N'REQUESTS_NATIVE_IDENTITY_VALUES',1;
   IF @Case IN(22,23) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requestContext')a WHERE TRY_CONVERT(int,JSON_VALUE(a.value,N'$.SessionId')) NOT IN(SELECT TOP(@Max) SessionId FROM #ExampleRequestsFixtureIds ORDER BY SessionId)) THROW 58717,N'REQUESTS_SESSION_RANK',1;
   IF @Case IN(28,29,30) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requests') WHERE TRY_CONVERT(int,JSON_VALUE(value,N'$.sessionId'))<>TRY_CONVERT(int,CASE WHEN @Case=28 THEN @Upper ELSE @Lower END)) THROW 58718,N'REQUESTS_CASE_FILTER',1;
   IF @Case BETWEEN 34 AND 39 AND @WithText=1 AND EXISTS
   (SELECT 1 FROM #ExampleRequestsTextNative n CROSS APPLY(SELECT n.CharacterCount,n.Bytes,n.IsTruncated,n.Text FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) expected(j)
    CROSS APPLY OPENJSON(expected.j)p CROSS APPLY OPENJSON(@Json,N'$.'+n.Kind)a CROSS APPLY OPENJSON(a.value)q
    WHERE p.[key] COLLATE Latin1_General_100_BIN2=q.[key] COLLATE Latin1_General_100_BIN2
     AND (p.[type]<>q.[type] OR ISNULL(p.value,N'') COLLATE Latin1_General_100_BIN2<>ISNULL(q.value,N'') COLLATE Latin1_General_100_BIN2)) THROW 58731,N'REQUESTS_NATIVE_UNICODE_TEXT',1;
   IF @Case=39 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requestContext') WHERE JSON_VALUE(value,N'$.ModuleFullName') IS NULL) THROW 58719,N'REQUESTS_MODULE',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.requests')a LEFT JOIN monitor.WaitTypeCatalog c ON c.WaitType=JSON_VALUE(a.value,N'$.waitType') COLLATE SQL_Latin1_General_CP1_CS_AS
    WHERE JSON_VALUE(a.value,N'$.waitType')<>N'WAITFOR' OR c.WaitType IS NULL
     OR JSON_VALUE(a.value,N'$.waitGroup') COLLATE Latin1_General_100_BIN2<>c.WaitGroup COLLATE Latin1_General_100_BIN2
     OR ISNULL(TRY_CONVERT(int,JSON_VALUE(a.value,N'$.waitSeverity')),-1)<>c.Severity) THROW 58733,N'REQUESTS_NATIVE_WAIT_CATALOG',1;
   SET @NativeCases+=1;
  END
  ELSE IF @Case>=100 SET @MappingCases+=1; ELSE SET @Core+=1;
  SET @Sql=N'';SELECT @Sql+=N'DROP TABLE '+QUOTENAME(TargetTable)+N';' FROM #ExampleRequestsMaps;EXEC sys.sp_executesql @Sql;
  FETCH NEXT FROM Cases185 INTO @Case,@Native,@Ids,@Max,@Text,@WithText,@Batch,@Input,@Module,@Sort,@IncludeSelf,@Duration,@Programs,@Hosts,@Pattern,@MinCpu,@ExpectedStatus,@ExpectedRows;
 END;
 CLOSE Cases185;DEALLOCATE Cases185;
 IF @FixtureStatus='PENDING'
 BEGIN
  IF @NativeCases<>20 THROW 58720,N'REQUESTS_NATIVE_COUNT',1;
  DECLARE @D int=0;
  WHILE @D<3
  BEGIN
   SET @Max=CASE @D WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END;
   EXEC monitor.USP_CurrentRequests @SessionIds=@FixtureIds,@ToolHintergrundabfragenEinbeziehen=1,@MitSqlText=0,@ModulInfoEinbeziehen=0,@MaxZeilen=@Max,@Sortierung='SESSION',@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.requests'))<>CASE @D WHEN 0 THEN 3 ELSE @D END OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR @@LOCK_TIMEOUT<>137 THROW 58721,N'REQUESTS_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @D+=1;SET @DirectConsole+=1;
  END;SET @FixtureStatus='PASS';
 END;
 DECLARE @E int=0;
 WHILE @E<3
 BEGIN
  TRUNCATE TABLE #ExampleRequestsEmptyConsole;
  SET @Max=CASE WHEN @E=1 THEN -1 ELSE 0 END;SET @Text=CASE WHEN @E=2 THEN -1 ELSE 0 END;
  INSERT #ExampleRequestsEmptyConsole EXEC monitor.USP_CurrentRequests @SessionIds=@OwnIds,@AktuelleSessionEinbeziehen=0,@MitSqlText=0,@ModulInfoEinbeziehen=0,@MaxZeilen=@Max,@MaxSqlTextZeichen=@Text,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleRequestsEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleRequestsEmptyConsole WHERE Ergebnis<>N'Keine aktiven Requests' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
   OR JSON_QUERY(@Json,N'$.requests')<>N'[]' OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @E=0 THEN N'AVAILABLE' ELSE N'INVALID_PARAMETER' END OR @@LOCK_TIMEOUT<>137 THROW 58722,N'REQUESTS_EMPTY_CONSOLE',1;
  SET @E+=1;SET @EmptyConsole+=1;
 END;
 DECLARE @C int=0,@Mode varchar(16);
 WHILE @C<3
 BEGIN
  SET @Json=N'ExamplePrevious';
  IF @C=0
  BEGIN
   EXEC monitor.USP_CurrentRequests @SessionIds=@OwnIds,@AktuelleSessionEinbeziehen=0,@ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF @Json IS NOT NULL THROW 58723,N'REQUESTS_JSON_DISABLED',1;
  END
  ELSE
  BEGIN
   SET @Mode=CASE WHEN @C=1 THEN 'NONE' ELSE 'RAW' END;
   EXEC monitor.USP_CurrentRequests @MaxZeilen=-1,@ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
   IF JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,N'$.requests')<>N'[]' THROW 58724,N'REQUESTS_INVALID_CONSUMER',1;
  END;
  IF @@LOCK_TIMEOUT<>137 THROW 58725,N'REQUESTS_CONSUMER_CALLER',1;
  SET @C+=1;SET @Consumers+=1;
 END;
 DECLARE @P int=0,@Bad nvarchar(max),@Caught int;
 WHILE @P<6
 BEGIN
  SET @Bad=CASE @P WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleRequestsPreflight"}' WHEN 2 THEN N'{"requests":"#ExampleMissingTarget185"}'
   WHEN 3 THEN N'{"requests":"ExamplePermanent"}' WHEN 4 THEN N'{"requests":"#ExampleRequestsPreflight","statements":"#ExampleRequestsPreflight"}' ELSE N'{"requests":"#ExampleRequestsPreflight"}' END;
  SET @Caught=0;SET @Mode=CASE WHEN @P=5 THEN 'NONE' ELSE 'TABLE' END;
  BEGIN TRY EXEC monitor.USP_CurrentRequests @SessionIds=@OwnIds,@ResultSetArt=@Mode,@ResultTablesJson=@Bad,@PrintMeldungen=0;END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleRequestsPreflight'))<>1 THROW 58726,N'REQUESTS_PREFLIGHT',1;
  SET @P+=1;SET @Preflights+=1;
 END;
 IF @Core<>21 OR @MappingCases<>9 OR @Consumers<>3 OR @Preflights<>6 OR @EmptyConsole<>3 THROW 58727,N'REQUESTS_CASE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLock)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' ContractStatus,@Level FrameworkCompatibilityLevel,230 TableFields,66 TextCollations,52 JsonLegacyFields,73 JsonContextFields,
  @Core CoreCases,@MappingCases SelectiveMappingCases,@FixtureStatus PositiveFixtureStatus,@NativeCases NativeCases,@Consumers ConsumerCases,@Preflights PreflightCases,@EmptyConsole EmptySqlConsoleCases,@DirectConsole DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'';SELECT @Sql+=CASE WHEN OBJECT_ID(N'tempdb..'+TargetTable) IS NOT NULL THEN N'DROP TABLE '+QUOTENAME(TargetTable)+N';' ELSE N'' END FROM #ExampleRequestsMaps;IF @Sql<>N'' EXEC sys.sp_executesql @Sql;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLock)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
