USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft 17 bedingte TABLE-Verträge mit 540 aktiven Literal-Feldern.
Parentstatus TABLE 8/JSON 7; Snapshot 11; Warnungen 3. Requests 93 TABLE-Felder
werden im Legacy-JSON als 50 Werte plus 2 Waitfelder dargestellt; Sessions 51
ergänzt 3 Waitfelder. Kein vollständiger 93-Feld-JSON-Wertanspruch.
Volle Parität gilt innerhalb eines Aufrufs mit NULL-/Typ-/BIN2-/Multisetprüfung.
Deaktivierte Childziele behalten den bestehenden bedingten Seed-Vertrag.
Optionaler Kontext ExampleCurrentOverviewFixtureIds enthält vier eigene IDs.
Der Test liest nur; kein Workload, keine Fixturemutation, keine Parent-Snapshot-
DDL und kein neuer Owner. Ohne geeigneten Kontext: NOT_EXECUTED.
Mutable Zähler/Dauern sind nicht über Aufrufe atomar vergleichbar. Positive
Memory-Grant-Werte, heterogene CONSOLE-Detailgrids und Berechtigungs-/Timeout-
pfade brauchen getrennte native Nachweise. Alle Metadatenversionen bleiben erhalten.
*/
SET NOCOUNT ON;
DECLARE @Level int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @Level IS NULL OR @Level NOT IN(150,160,170) THROW 59500,N'OVERVIEW_LEVEL',1;
IF ISNULL(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS' THROW 59501,N'OVERVIEW_COLLATION',1;
DECLARE @OriginalLock int=@@LOCK_TIMEOUT,@Case int,@Mask int,@MapMask int,@Max int,@Text int,@Sample tinyint,
 @Detail varchar(16),@Help bit,@JsonBit bit,@Bad int,@Native bit,@Tools bit,@Ids nvarchar(max),
 @Json nvarchar(max),@Sql nvarchar(max),@Map nvarchar(max),@TableJson nvarchar(max),@Array nvarchar(max),
 @Before datetime2(3),@After datetime2(3),@Core int=0,@NativeCases int=0,@Preflight int=0,@Consumers int=0,
 @IdentityRow nvarchar(max),@FixtureStatus varchar(24)='NOT_EXECUTED',@FixtureIds nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleCurrentOverviewFixtureIds')),
 @S bit,@R bit,@B bit,@W bit,@T bit,@G bit,@D bit,@I bit,@L bit,@Result sysname,@Target sysname,@Schema sysname,@Path nvarchar(128),
 @Keys nvarchar(max),@Fields int,@Extra nvarchar(128),@ModuleBit int,@Bit int,@Object int,@Template int,@Materialized bit;
CREATE TABLE #ExampleOverviewOracle_sessions
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

CREATE TABLE #ExampleOverviewOracle_requests
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

CREATE TABLE #ExampleOverviewOracle_requestContext
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

CREATE TABLE #ExampleOverviewOracle_statements
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

CREATE TABLE #ExampleOverviewOracle_batches
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

CREATE TABLE #ExampleOverviewOracle_inputBuffers
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

CREATE TABLE #ExampleOverviewOracle_blocking
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

CREATE TABLE #ExampleOverviewOracle_waits
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

CREATE TABLE #ExampleOverviewOracle_transactions
(
          [SessionId]                smallint       NOT NULL
        , [TransactionId]            bigint         NOT NULL
        , [TransactionBeginTimeUtc]  datetime       NULL
        , [TransactionAgeSeconds]    bigint         NULL
        , [TransactionType]          int            NULL
        , [TransactionState]         int            NULL
        , [OpenTransactionCount]     int            NULL
        , [LoginName]                nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName]                 nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProgramName]              nvarchar(128)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SessionStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequestStatus]            nvarchar(30)   COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseId]               int            NULL
        , [DatabaseName]             sysname        COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LogBytesUsed]             bigint         NULL
        , [LogBytesReserved]         bigint         NULL
        , [StatementTextCharacters]  bigint         NULL
        , [StatementTextBytes]       bigint         NULL
        , [StatementTextIsTruncated] bit            NOT NULL DEFAULT(0)
        , [StatementText]            nvarchar(max)  COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

CREATE TABLE #ExampleOverviewOracle_memoryGrants
(
 [SessionId] smallint NULL,
 [RequestId] int NULL,
 [SchedulerId] int NULL,
 [Dop] smallint NULL,
 [RequestTime] datetime NULL,
 [GrantTime] datetime NULL,
 [WaitTimeMs] bigint NULL,
 [IsWaiting] bit NOT NULL,
 [IsSmall] bit NULL,
 [RequestedMemoryMb] decimal(19,2) NULL,
 [RequiredMemoryMb] decimal(19,2) NULL,
 [GrantedMemoryMb] decimal(19,2) NULL,
 [UsedMemoryMb] decimal(19,2) NULL,
 [MaxUsedMemoryMb] decimal(19,2) NULL,
 [IdealMemoryMb] decimal(19,2) NULL,
 [GroupId] int NULL,
 [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PoolId] int NULL,
 [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceSemaphoreId] smallint NULL,
 [RequestMaxMemoryGrantPercent] decimal(9,4) NULL,
 [PoolMaxWorkspaceMemoryMb] decimal(19,2) NULL,
 [PoolTargetWorkspaceMemoryMb] decimal(19,2) NULL,
 [PoolUsedWorkspaceMemoryMb] decimal(19,2) NULL,
 [ConfiguredRequestMaxGrantMemoryMb] decimal(19,2) NULL,
 [TargetRequestMaxGrantMemoryMb] decimal(19,2) NULL,
 [HistoricalMaxRequestGrantMemoryMb] decimal(19,2) NULL,
 [RequestedOfRequestMaxPercent] decimal(9,2) NULL,
 [GrantedOfRequestMaxPercent] decimal(9,2) NULL,
 [UsedOfRequestMaxPercent] decimal(9,2) NULL,
 [MaxUsedOfRequestMaxPercent] decimal(9,2) NULL,
 [IdealOfRequestMaxPercent] decimal(9,2) NULL,
 [RequestedOfTargetMaxPercent] decimal(9,2) NULL,
 [GrantedOfTargetMaxPercent] decimal(9,2) NULL,
 [UsedOfGrantedPercent] decimal(9,2) NULL,
 [MaxUsedOfGrantedPercent] decimal(9,2) NULL,
 [SemaphoreTargetMemoryMb] decimal(19,2) NULL,
 [SemaphoreMaxTargetMemoryMb] decimal(19,2) NULL,
 [SemaphoreTotalMemoryMb] decimal(19,2) NULL,
 [SemaphoreAvailableMemoryMb] decimal(19,2) NULL,
 [SemaphoreGrantedMemoryMb] decimal(19,2) NULL,
 [SemaphoreUsedMemoryMb] decimal(19,2) NULL,
 [SemaphoreGranteeCount] int NULL,
 [SemaphoreWaiterCount] int NULL,
 [ReservedWorkerCount] bigint NULL,
 [UsedWorkerCount] bigint NULL,
 [MaxUsedWorkerCount] bigint NULL,
 [QueueId] smallint NULL,
 [WaitOrder] int NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DatabaseId] smallint NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ElapsedMs] int NULL,
 [CpuMs] int NULL,
 [LogicalReads] bigint NULL,
 [CurrentStatementCharacters] bigint NULL,
 [CurrentStatementBytes] bigint NULL,
 [CurrentStatementIsTruncated] bit NOT NULL,
 [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE #ExampleOverviewOracle_tempdbSessions
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

CREATE TABLE #ExampleOverviewOracle_tempdbGovernance
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

CREATE TABLE [#ExampleOverviewOracle_io]
(
    [DatabaseId] int NOT NULL
  , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [FileId] int NOT NULL
  , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [SampleSeconds] int NOT NULL
  , [Reads] bigint NOT NULL
  , [ReadBytes] bigint NOT NULL
  , [ReadStallMs] bigint NOT NULL
  , [Writes] bigint NOT NULL
  , [WriteBytes] bigint NOT NULL
  , [WriteStallMs] bigint NOT NULL
  , [ReadLatencyMs] decimal(19,3) NULL
  , [WriteLatencyMs] decimal(19,3) NULL
  , [OverallLatencyMs] decimal(19,3) NULL
  , [ReadThroughputMbPerSecond] decimal(19,3) NULL
  , [WriteThroughputMbPerSecond] decimal(19,3) NULL
  , [SizeOnDiskMb] decimal(19,2) NULL
);

CREATE TABLE #ExampleOverviewOracle_logs
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

CREATE TABLE [#ExampleOverviewOracle_moduleStatus]
    (
          [ModuleOrdinal] int NOT NULL
        , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [DurationMs] bigint NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([ModuleOrdinal])
    );

CREATE TABLE [#ExampleOverviewOracle_snapshotStatus]
    (
          [SourceOrdinal] int NOT NULL
        , [SnapshotId] uniqueidentifier NOT NULL
        , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [CompletedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [CapturedRowCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([SourceOrdinal])
    );

CREATE TABLE [#ExampleOverviewOracle_warnings]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

CREATE TABLE #ExampleOverviewMaps(BitValue int NOT NULL,ResultName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 TargetTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,SchemaTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 JsonPath nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,FieldCount int NOT NULL,
 ExpectedKeys nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,ExtraKeys nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,ModuleBit int NOT NULL);
INSERT #ExampleOverviewMaps VALUES
(1,N'sessions',N'#ExampleOverviewOut_sessions',N'#ExampleOverviewOracle_sessions',N'$.sessions.sessions',51,N'SessionId|RequestId|IsUserProcess|SessionStatus|RequestStatus|LoginName|OriginalLoginName|HostName|ProgramName|IsToolBackgroundQuery|ToolBackgroundRuleCode|ToolBackgroundCategory|ToolBackgroundDetection|ToolBackgroundConfidence|ClientInterfaceName|LoginTime|LastRequestStartTime|LastRequestEndTime|DatabaseId|DatabaseName|OpenTransactionCount|TransactionIsolationLevel|SessionCpuMs|SessionReads|SessionWrites|SessionLogicalReads|SessionMemoryMb|SessionRowCount|RequestCpuMs|RequestElapsedMs|RequestLogicalReads|RequestReads|RequestWrites|BlockingSessionId|WaitType|WaitTimeMs|WaitResource|PercentComplete|ClientNetAddress|NetTransport|ProtocolType|EncryptOption|AuthScheme|CurrentStatementCharacters|CurrentStatementBytes|CurrentStatementIsTruncated|CurrentStatement|BatchTextCharacters|BatchTextBytes|BatchTextIsTruncated|BatchText',N'waitGroup|waitSeverity|waitMeaning',1),
(2,N'requests',N'#ExampleOverviewOut_requests',N'#ExampleOverviewOracle_requests',N'$.requests.requests',93,N'sessionId|requestId|requestStatus|command|databaseId|databaseName|loginName|hostName|programName|isToolBackgroundQuery|toolBackgroundRuleCode|toolBackgroundCategory|toolBackgroundDetection|toolBackgroundConfidence|startTime|elapsedMs|cpuMs|logicalReads|writes|blockingSessionId|waitType|waitGroup|waitSeverity|waitTimeMs|requestedMemoryMb|grantedMemoryMb|usedMemoryMb|dop|parallelWorkerCount|schedulerId|taskAddress|nestLevel|openTransactionCount|openResultsetCount|transactionId|connectionId|workloadGroupId|workloadGroupName|resourcePoolId|resourcePoolName|statementSqlHandle|statementContextId|isResumable|executingManagedCode|contextInfo|moduleFullName|moduleTypeDescription|executionContextType|queryHash|queryPlanHash|sqlHandle|planHandle',NULL,2),
(4,N'requestContext',N'#ExampleOverviewOut_requestContext',N'#ExampleOverviewOracle_requestContext',N'$.requests.requestContext',73,N'SnapshotId|CapturedAtUtc|SessionId|RequestId|RequestStatus|Command|DatabaseId|DatabaseName|StartTime|ElapsedMs|CpuMs|LogicalReads|Reads|Writes|RowCount|PercentComplete|EstimatedCompletionTimeMs|BlockingSessionId|WaitType|WaitTimeMs|WaitResource|ConnectionId|ClientNetAddress|NetTransport|ProtocolType|EncryptOption|AuthScheme|TaskCount|WorkerCount|ExecutionContextCount|RunnableTaskCount|SuspendedTaskCount|SchedulerId|SchedulerStatus|SchedulerParentNodeId|SchedulerRunnableTaskCount|SchedulerWorkQueueCount|SchedulerPendingDiskIoCount|SchedulerLoadFactor|TransactionId|TransactionBeginTime|TransactionAgeSeconds|TransactionType|TransactionState|IsUserTransaction|IsLocalTransaction|IsEnlistedTransaction|IsBoundTransaction|TransactionLogBytesUsed|TransactionLogBytesReserved|RequestedMemoryMb|GrantedMemoryMb|UsedMemoryMb|IdealMemoryMb|TempDbSessionNetMb|TempDbRequestNetMb|Dop|ParallelWorkerCount|WorkloadGroupId|WorkloadGroupName|ResourcePoolId|ResourcePoolName|QueryHash|QueryPlanHash|SqlHandle|PlanHandle|StatementSqlHandle|StatementContextId|ModuleFullName|IsCurrent|StatusCode|IsPartial|EvidenceBoundary',NULL,2),
(8,N'statements',N'#ExampleOverviewOut_statements',N'#ExampleOverviewOracle_statements',N'$.requests.statements',19,N'SnapshotId|SessionId|RequestId|SourceCode|CapturedAtUtc|HasStatementOffsets|IsStatementOffsetValid|StartOffsetBytes|EndOffsetBytes|StartCharacter|EndCharacter|StartLine|EndLine|CharacterCount|Bytes|IsTruncated|StatusCode|OmissionReason|Text',NULL,2),
(16,N'batches',N'#ExampleOverviewOut_batches',N'#ExampleOverviewOracle_batches',N'$.requests.batches',15,N'SnapshotId|SessionId|RequestId|SourceCode|CapturedAtUtc|SqlTextDatabaseId|SqlTextObjectId|SqlTextObjectNumber|IsEncrypted|CharacterCount|Bytes|IsTruncated|StatusCode|OmissionReason|Text',NULL,2),
(32,N'inputBuffers',N'#ExampleOverviewOut_inputBuffers',N'#ExampleOverviewOracle_inputBuffers',N'$.requests.inputBuffers',13,N'SnapshotId|SessionId|RequestId|SourceCode|CapturedAtUtc|EventType|ParameterCount|CharacterCount|Bytes|IsTruncated|StatusCode|OmissionReason|Text',NULL,2),
(64,N'blocking',N'#ExampleOverviewOut_blocking',N'#ExampleOverviewOracle_blocking',N'$.blocking.blockingChains',67,N'LeafSessionId|BlockedSessionId|BlockingSessionId|RootBlockingSessionId|BlockingOwnerType|BlockingOwnerDescription|BlockingChain|ChainDepth|IsCycle|WaitType|WaitTimeMs|WaitResource|BlockingResourceType|BlockingResourceDatabaseId|BlockingResourceDatabaseName|BlockingResourceSchemaName|BlockingResourceObjectId|BlockingResourceObjectName|BlockingResourceIndexId|BlockingResourceIndexName|BlockingResourcePartitionId|BlockingResourcePartitionNumber|BlockingResourceFileId|BlockingResourcePageId|BlockingResourceRowId|BlockingResourceMetadataSubtype|BlockingResourceMetadataName|BlockingResourcePageTypeDesc|BlockingResourceName|BlockingResourceResolutionStatus|BlockedLoginName|BlockedHostName|BlockedProgramName|BlockedIsToolBackgroundQuery|BlockedToolBackgroundRuleCode|BlockedToolBackgroundCategory|BlockedToolBackgroundDetection|BlockedToolBackgroundConfidence|BlockerLoginName|BlockerHostName|BlockerProgramName|RootBlockerLoginName|RootBlockerHostName|RootBlockerProgramName|RootBlockerSessionStatus|RootBlockerRequestStatus|RootBlockerOpenTransactionCount|RootBlockerLastRequestStartTime|RootBlockerLastRequestEndTime|RootIsToolBackgroundQuery|RootToolBackgroundRuleCode|RootToolBackgroundCategory|RootToolBackgroundDetection|RootToolBackgroundConfidence|BlockedStatementCharacters|BlockedStatementBytes|BlockedStatementIsTruncated|BlockedStatement|BlockerStatementCharacters|BlockerStatementBytes|BlockerStatementIsTruncated|BlockerStatement|RootBlockerStatementSource|RootBlockerStatementCharacters|RootBlockerStatementBytes|RootBlockerStatementIsTruncated|RootBlockerStatement',NULL,4),
(128,N'waits',N'#ExampleOverviewOut_waits',N'#ExampleOverviewOracle_waits',N'$.waits.currentTasks',33,N'SessionId|ExecContextId|WaitDurationMs|WaitType|BlockingSessionId|ResourceDescription|SessionStatus|RequestStatus|LoginName|HostName|ProgramName|IsToolBackgroundQuery|ToolBackgroundRuleCode|ToolBackgroundCategory|ToolBackgroundDetection|ToolBackgroundConfidence|DatabaseId|Command|CurrentStatementCharacters|CurrentStatementBytes|CurrentStatementIsTruncated|CurrentStatement|WaitGroup|WaitSeverity|IsGenerallyBenign|WaitMeaning|WaitTypicalOccurrence|HighWaitImpact|RecommendedChecks|WaitHelpUrl|DescriptionSource|DescriptionQuality|CatalogMatchType',NULL,8),
(256,N'transactions',N'#ExampleOverviewOut_transactions',N'#ExampleOverviewOracle_transactions',N'$.transactions.transactions',20,N'SessionId|TransactionId|TransactionBeginTimeUtc|TransactionAgeSeconds|TransactionType|TransactionState|OpenTransactionCount|LoginName|HostName|ProgramName|SessionStatus|RequestStatus|DatabaseId|DatabaseName|LogBytesUsed|LogBytesReserved|StatementTextCharacters|StatementTextBytes|StatementTextIsTruncated|StatementText',NULL,16),
(512,N'memoryGrants',N'#ExampleOverviewOut_memoryGrants',N'#ExampleOverviewOracle_memoryGrants',N'$.memoryGrants.memoryGrants',63,N'SessionId|RequestId|SchedulerId|Dop|RequestTime|GrantTime|WaitTimeMs|IsWaiting|IsSmall|RequestedMemoryMb|RequiredMemoryMb|GrantedMemoryMb|UsedMemoryMb|MaxUsedMemoryMb|IdealMemoryMb|GroupId|WorkloadGroupName|PoolId|PoolName|ResourceSemaphoreId|RequestMaxMemoryGrantPercent|PoolMaxWorkspaceMemoryMb|PoolTargetWorkspaceMemoryMb|PoolUsedWorkspaceMemoryMb|ConfiguredRequestMaxGrantMemoryMb|TargetRequestMaxGrantMemoryMb|HistoricalMaxRequestGrantMemoryMb|RequestedOfRequestMaxPercent|GrantedOfRequestMaxPercent|UsedOfRequestMaxPercent|MaxUsedOfRequestMaxPercent|IdealOfRequestMaxPercent|RequestedOfTargetMaxPercent|GrantedOfTargetMaxPercent|UsedOfGrantedPercent|MaxUsedOfGrantedPercent|SemaphoreTargetMemoryMb|SemaphoreMaxTargetMemoryMb|SemaphoreTotalMemoryMb|SemaphoreAvailableMemoryMb|SemaphoreGrantedMemoryMb|SemaphoreUsedMemoryMb|SemaphoreGranteeCount|SemaphoreWaiterCount|ReservedWorkerCount|UsedWorkerCount|MaxUsedWorkerCount|QueueId|WaitOrder|LoginName|HostName|ProgramName|DatabaseId|DatabaseName|RequestStatus|Command|ElapsedMs|CpuMs|LogicalReads|CurrentStatementCharacters|CurrentStatementBytes|CurrentStatementIsTruncated|CurrentStatement',NULL,32),
(1024,N'tempdbSessions',N'#ExampleOverviewOut_tempdbSessions',N'#ExampleOverviewOracle_tempdbSessions',N'$.tempdbSessions.sessions',12,N'SessionId|LoginName|HostName|ProgramName|SessionStatus|UserObjectsAllocatedMb|UserObjectsDeallocatedMb|UserObjectsNetMb|InternalObjectsAllocatedMb|InternalObjectsDeallocatedMb|InternalObjectsNetMb|TotalNetMb',NULL,64),
(2048,N'tempdbGovernance',N'#ExampleOverviewOut_tempdbGovernance',N'#ExampleOverviewOracle_tempdbGovernance',N'$.tempdbSessions.tempdbGovernance',21,N'GroupId|GroupName|PoolId|PoolName|ConfiguredGroupMaxTempdbDataMb|ConfiguredGroupMaxTempdbDataPercent|TempdbMaximumSizeMb|EffectiveGroupMaxTempdbDataMb|EffectiveLimitSource|IsPercentLimitEffective|TempdbDataSpaceMb|PeakTempdbDataSpaceMb|EffectiveLimitUtilizationPercent|TotalTempdbDataLimitViolationCount|HasRecordedLimitViolation|StatisticsStartTime|IsResourceGovernorEnabled|ReconfigurationPending|SourceStatusCode|IsPartial|EvidenceLimit',NULL,64),
(4096,N'io',N'#ExampleOverviewOut_io',N'#ExampleOverviewOracle_io',N'$.io.files',19,N'DatabaseId|DatabaseName|FileId|LogicalName|PhysicalName|FileTypeDesc|SampleSeconds|Reads|ReadBytes|ReadStallMs|Writes|WriteBytes|WriteStallMs|ReadLatencyMs|WriteLatencyMs|OverallLatencyMs|ReadThroughputMbPerSecond|WriteThroughputMbPerSecond|SizeOnDiskMb',NULL,128),
(8192,N'logs',N'#ExampleOverviewOut_logs',N'#ExampleOverviewOracle_logs',N'$.logs.logs',19,N'DatabaseId|DatabaseName|RecoveryModel|LogReuseWaitDesc|TotalLogSizeMb|UsedLogSizeMb|UsedLogPercent|LogSinceLastBackupMb|ActiveVlfCount|TotalVlfCount|LogTruncationHoldupReason|LogBackupTime|LogRecoverySizeMb|IsAdrEnabled|PersistentVersionStoreMb|SpaceStatus|StatsStatus|VlfStatus|PvsStatus',NULL,256),
(16384,N'moduleStatus',N'#ExampleOverviewOut_moduleStatus',N'#ExampleOverviewOracle_moduleStatus',N'$.moduleStatus',8,N'ResultName|ModuleName|StatusCode|IsPartial|ReturnedRowCount|DurationMs|ErrorMessage',NULL,0),
(32768,N'snapshotStatus',N'#ExampleOverviewOut_snapshotStatus',N'#ExampleOverviewOracle_snapshotStatus',N'$.snapshotStatus',11,N'SourceOrdinal|SnapshotId|SourceCode|SourceObject|CapturedAtUtc|CompletedAtUtc|StatusCode|IsPartial|CapturedRowCount|ErrorNumber|ErrorMessage',NULL,0),
(65536,N'warnings',N'#ExampleOverviewOut_warnings',N'#ExampleOverviewOracle_warnings',N'$.warnings',3,N'ModuleName|StatusCode|Message',NULL,0);
CREATE TABLE #ExampleOverviewCases(CaseNumber int NOT NULL,NativeCase bit NOT NULL,ModuleMask int NOT NULL,
 MapMask int NOT NULL,MaximumRows int NULL,TextLimit int NULL,Sample tinyint NULL,Detail varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Help bit NOT NULL,JsonBit bit NULL,BadParameter int NOT NULL,Tools bit NOT NULL,Ids nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
INSERT #ExampleOverviewCases VALUES
 (0,0,0,131071,NULL,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (1,0,0,131071,0,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (2,0,0,131071,1,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (3,0,0,131071,2,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (4,0,0,131071,2147483647,NULL,NULL,'ALL',0,1,0,1,N'32767'),
 (5,0,0,131071,-1,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (6,0,0,131071,0,-1,0,'SUMMARY',0,1,0,1,N'32767'),
 (7,0,0,131071,0,0,61,'SUMMARY',0,1,0,1,N'32767'),
 (8,0,0,131071,0,0,0,'INVALID',0,1,0,1,N'32767'),
 (9,0,0,131071,0,0,0,'SUMMARY',0,1,1,1,N'32767'),
 (10,0,0,131071,0,0,0,'SUMMARY',0,NULL,0,1,N'32767'),
 (11,0,0,131071,0,0,0,'SUMMARY',0,1,2,1,N'32767'),
 (12,0,0,131071,0,0,0,'SUMMARY',1,1,0,1,N'32767'),
 (13,0,0,131071,0,0,0,'SUMMARY',0,0,0,1,N'32767'),
 (14,0,511,131071,1,0,0,'SUMMARY',0,1,0,1,N'32767|32767');
DECLARE @N int=0;
WHILE @N<9
BEGIN
 INSERT #ExampleOverviewCases VALUES(20+@N,0,CONVERT(int,POWER(2,@N)),131071,1,0,0,'SUMMARY',0,1,0,1,N'32767');
 SET @N+=1;
END;
SET @N=0;
WHILE @N<17
BEGIN
 INSERT #ExampleOverviewCases VALUES(40+@N,0,0,CONVERT(int,POWER(2,@N)),0,0,0,'SUMMARY',0,1,0,1,N'32767');
 SET @N+=1;
END;
INSERT #ExampleOverviewCases VALUES
 (60,0,0,16384+32768,0,0,0,'SUMMARY',0,1,0,1,N'32767'),
 (61,0,0,16384+65536,0,0,0,'SUMMARY',0,1,0,1,N'32767');
CREATE TABLE #ExampleOverviewFixture(Ordinal int NOT NULL,SessionId smallint NOT NULL,ExpectedApp nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL);
IF @FixtureIds IS NOT NULL
BEGIN
 INSERT #ExampleOverviewFixture
 SELECT ItemOrdinal,TRY_CONVERT(smallint,NumberValue),CASE ItemOrdinal
 WHEN 1 THEN N'ExampleOverviewToolRootÄ🔬' WHEN 2 THEN N'ExampleOverviewToolMiddleÄ🔬'
 WHEN 3 THEN N'ExampleOverviewLeafÄ🔬' WHEN 4 THEN N'ExampleOverviewToolLeafä🔬' ELSE N'ExampleInvalid' END
 FROM monitor.TVF_ParseBigintList(@FixtureIds) WHERE IsValid=1 AND NumberValue BETWEEN 1 AND 32767;
 IF (SELECT COUNT(*) FROM #ExampleOverviewFixture)=4 AND (SELECT COUNT(DISTINCT SessionId) FROM #ExampleOverviewFixture)=4
 AND NOT EXISTS(SELECT 1 FROM #ExampleOverviewFixture f LEFT JOIN sys.dm_exec_sessions s ON s.session_id=f.SessionId
 WHERE s.session_id IS NULL OR s.session_id=@@SPID OR s.is_user_process<>1 OR ISNULL(s.program_name,N'') COLLATE Latin1_General_100_BIN2<>f.ExpectedApp)
 AND EXISTS(SELECT 1 FROM #ExampleOverviewFixture f JOIN sys.dm_exec_sessions s ON s.session_id=f.SessionId WHERE f.Ordinal=1 AND s.status=N'sleeping' AND s.open_transaction_count>0)
 AND (SELECT COUNT(*) FROM #ExampleOverviewFixture f JOIN sys.dm_exec_requests r ON r.session_id=f.SessionId
 JOIN #ExampleOverviewFixture b ON b.SessionId=r.blocking_session_id WHERE (f.Ordinal=2 AND b.Ordinal=1) OR(f.Ordinal IN(3,4) AND b.Ordinal=2))=3
 AND EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE RuleCode='EXAMPLE_OVERVIEW_FIXTURE_192' AND IsEnabled=1 AND IsFrameworkDefault=0)
 BEGIN
  SET @FixtureStatus='PENDING';
  INSERT #ExampleOverviewCases VALUES
   (100,1,511,131071,NULL,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (101,1,511,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (102,1,511,131071,1,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (103,1,511,131071,2,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (104,1,511,131071,1,NULL,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (105,1,511,131071,1,21,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (106,1,511,131071,2,22,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (107,1,511,131071,1,0,0,'SUMMARY',0,1,0,0,@FixtureIds),
   (108,1,1,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (109,1,2,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (110,1,4,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (111,1,8,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (112,1,16,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds),
   (113,1,64,131071,0,0,0,'SUMMARY',0,1,0,1,@FixtureIds);
 END;
END;
CREATE TABLE #ExampleOverviewCanonical(Side bit NOT NULL,CanonicalRow nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL);
CREATE TABLE #ExampleOverviewExpectedWarnings(ModuleName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,Message nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE Cases192 CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleOverviewCases ORDER BY CaseNumber;
 OPEN Cases192;
 FETCH NEXT FROM Cases192 INTO @Case,@Native,@Mask,@MapMask,@Max,@Text,@Sample,@Detail,@Help,@JsonBit,@Bad,@Tools,@Ids;
 WHILE @@FETCH_STATUS=0
 BEGIN
  CREATE TABLE #ExampleOverviewOut_sessions([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_requests([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_requestContext([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_statements([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_batches([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_inputBuffers([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_blocking([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_waits([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_transactions([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_memoryGrants([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_tempdbSessions([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_tempdbGovernance([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_io([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_logs([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_moduleStatus([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_snapshotStatus([Seed] bit NULL);
  CREATE TABLE #ExampleOverviewOut_warnings([Seed] bit NULL);
  DECLARE Seeds192 CURSOR LOCAL FAST_FORWARD FOR SELECT TargetTable FROM #ExampleOverviewMaps WHERE (BitValue&@MapMask)=0;
  OPEN Seeds192;FETCH NEXT FROM Seeds192 INTO @Target;
  WHILE @@FETCH_STATUS=0 BEGIN SET @Sql=N'INSERT '+QUOTENAME(@Target)+N' VALUES(1);';EXEC sys.sp_executesql @Sql;FETCH NEXT FROM Seeds192 INTO @Target;END;CLOSE Seeds192;DEALLOCATE Seeds192;
  SET @Map=(SELECT STRING_AGG(CONVERT(nvarchar(max),N'"'+ResultName+N'":"'+TargetTable+N'"'),N',') WITHIN GROUP(ORDER BY BitValue) FROM #ExampleOverviewMaps WHERE (BitValue & @MapMask)<>0);
  SET @Map=N'{'+@Map+N'}';
  SELECT @S=CONVERT(bit,@Mask&1),@R=CONVERT(bit,@Mask&2),@B=CONVERT(bit,@Mask&4),@W=CONVERT(bit,@Mask&8),@T=CONVERT(bit,@Mask&16),
   @G=CONVERT(bit,@Mask&32),@D=CONVERT(bit,@Mask&64),@I=CONVERT(bit,@Mask&128),@L=CONVERT(bit,@Mask&256);
  IF @Bad=1 SET @S=NULL;
  DECLARE @ObjectLimit int=CASE WHEN @Bad=2 THEN 0 ELSE 100 END;
  DECLARE @WithText bit=CASE WHEN @Native=1 AND ISNULL(@Text,0)<>0 THEN 1 ELSE 0 END;
  DECLARE @DatabaseScope nvarchar(max)=CASE WHEN @Native=1 THEN QUOTENAME(DB_NAME()) ELSE N'[ExampleMissingOverviewDatabaseÄ🔬]' END;
  SET @Json=N'ExampleSentinel';SET @Before=SYSUTCDATETIME();
  EXEC monitor.USP_CurrentOverview @SessionIds=@Ids,@DatabaseNames=@DatabaseScope,@ToolHintergrundabfragenEinbeziehen=@Tools,
   @Detailgrad=@Detail,@MitSessions=@S,@MitRequests=@R,@MitBlocking=@B,@MitWaits=@W,@MitTransactions=@T,@MitMemoryGrants=@G,
   @MitTempDB=@D,@MitIO=@I,@MitLog=@L,@MitSqlText=@WithText,@GesamtenSqlTextEinbeziehen=@WithText,
   @InputBufferEinbeziehen=0,@ModulInfoEinbeziehen=0,@MaxSqlTextZeichen=@Text,@SampleSeconds=@Sample,
   @MaxObjektAufloesungen=@ObjectLimit,@MaxZeilen=@Max,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
   @JsonErzeugen=@JsonBit,@Json=@Json OUTPUT,@PrintMeldungen=0,@Hilfe=@Help;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 THROW 59502,N'OVERVIEW_CALLER_LOCK',1;
  DECLARE @Invalid bit=CASE WHEN @Bad<>0 OR @Max<0 OR @Text<0 OR @Sample>60 OR @Detail NOT IN('SUMMARY','RELEVANT','ALL') OR @JsonBit IS NULL THEN 1 ELSE 0 END;
  IF @Help=1 OR ISNULL(@JsonBit,0)=0
  BEGIN
   IF @Json IS NOT NULL THROW 59503,N'OVERVIEW_JSON_DISABLED',1;
  END
  ELSE
  BEGIN
   IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>4+CASE WHEN @Invalid=1 THEN 0 ELSE (SELECT COUNT(*) FROM #ExampleOverviewMaps WHERE ModuleBit<>0 AND ResultName NOT IN(N'requestContext',N'statements',N'batches',N'inputBuffers',N'tempdbGovernance') AND (ModuleBit & @Mask)<>0) END
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json)p WHERE p.[key] COLLATE Latin1_General_100_BIN2 NOT IN(N'meta',N'moduleStatus',N'snapshotStatus',N'warnings') AND NOT EXISTS(SELECT 1 FROM #ExampleOverviewMaps m WHERE @Invalid=0 AND m.ModuleBit<>0 AND m.ResultName NOT IN(N'requestContext',N'statements',N'batches',N'inputBuffers',N'tempdbGovernance') AND(m.ModuleBit&@Mask)<>0 AND m.ResultName COLLATE Latin1_General_100_BIN2=p.[key] COLLATE Latin1_General_100_BIN2))
    THROW 59504,N'OVERVIEW_TOP_KEYS',1;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>10 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
    OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'CurrentOverview' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>4
    OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
    OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
    OR (@Invalid=1 AND(JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true'))
    THROW 59505,N'OVERVIEW_META',1;
   IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type] FROM OPENJSON(@Json,N'$.meta')
    EXCEPT SELECT k COLLATE Latin1_General_100_BIN2,t FROM(VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),
    (N'evidenceSnapshotId',CASE WHEN @Invalid=0 AND @Mask NOT IN(0,256) THEN 1 ELSE 0 END),(N'isPartial',3),(N'executedModules',2),(N'failedModules',2),(N'partialModules',2),(N'toolBackgroundQueriesIncluded',3))v(k,t))
    THROW 59505,N'OVERVIEW_META_KEYS_TYPES',1;
   IF JSON_VALUE(@Json,N'$.meta.toolBackgroundQueriesIncluded')<>CASE WHEN @Tools=1 THEN N'true' ELSE N'false' END THROW 59505,N'OVERVIEW_TOOL_META',1;
   IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.moduleStatus'))<>CASE WHEN @Invalid=1 THEN 1 ELSE 9 END THROW 59506,N'OVERVIEW_MODULE_COUNT',1;
   IF @Case=0 SET @IdentityRow=JSON_QUERY(@Json,N'$.moduleStatus[0]');
  END;
  DECLARE Maps192 CURSOR LOCAL FAST_FORWARD FOR SELECT BitValue,ResultName,TargetTable,SchemaTable,JsonPath,FieldCount,ExpectedKeys,ExtraKeys,ModuleBit FROM #ExampleOverviewMaps ORDER BY BitValue;
  OPEN Maps192;FETCH NEXT FROM Maps192 INTO @Bit,@Result,@Target,@Schema,@Path,@Fields,@Keys,@Extra,@ModuleBit;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @Object=OBJECT_ID(N'tempdb..'+@Target);SET @Template=OBJECT_ID(N'tempdb..'+@Schema);
   SET @Materialized=CASE WHEN (@Bit & @MapMask)=0 OR @Help=1 THEN 0
     WHEN @ModuleBit=0 THEN 1
     WHEN @Invalid=1 THEN 0
     WHEN @Result IN(N'requestContext',N'statements',N'batches',N'inputBuffers') AND (@Mask&2)=0 THEN 0
     WHEN @Result=N'tempdbGovernance' AND (@Mask&64)=0 THEN 0
     WHEN (@ModuleBit&@Mask)=0 THEN 0
     WHEN @JsonBit=1 AND @Invalid=0 AND @Result NOT IN(N'requestContext',N'statements',N'batches',N'inputBuffers')
       AND JSON_QUERY(@Json,N'$.'+CASE WHEN @Result=N'tempdbGovernance' THEN N'tempdbSessions' ELSE @Result END) IS NULL THEN 0
     ELSE 1 END;
   IF @Materialized=0
   BEGIN
    IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=@Object)<>1 OR NOT EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=@Object AND name=N'Seed' AND system_type_id=104 AND is_nullable=1 AND is_identity=0)
     THROW 59507,N'OVERVIEW_DISABLED_SEED_SCHEMA',1;
    DECLARE @SeedRows int;
    SET @Sql=N'SELECT @n=COUNT(*) FROM '+QUOTENAME(@Target)+N';';EXEC sys.sp_executesql @Sql,N'@n int OUTPUT',@SeedRows OUTPUT;
    IF @SeedRows<>CASE WHEN (@Bit&@MapMask)=0 THEN 1 ELSE 0 END THROW 59508,N'OVERVIEW_UNMAPPED_SENTINEL',1;
   END
   ELSE
   BEGIN
    IF EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Object
     EXCEPT SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Template)
     OR EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Template
      EXCEPT SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity FROM tempdb.sys.columns WHERE object_id=@Object)
      THROW 59509,N'OVERVIEW_LITERAL_SCHEMA',1;
    IF @Result=N'moduleStatus'
    BEGIN
     DECLARE @BadOrdinal int;
     SET @Sql=N'SELECT @n=COUNT(*) FROM '+QUOTENAME(@Target)+N' WHERE ModuleOrdinal<>CASE WHEN @invalid=1 THEN 0 ELSE CASE ResultName WHEN N''sessions'' THEN 10 WHEN N''requests'' THEN 20 WHEN N''blocking'' THEN 30 WHEN N''waits'' THEN 40 WHEN N''transactions'' THEN 50 WHEN N''memoryGrants'' THEN 60 WHEN N''tempdbSessions'' THEN 70 WHEN N''io'' THEN 80 WHEN N''logs'' THEN 90 ELSE -1 END END;';
     EXEC sys.sp_executesql @Sql,N'@n int OUTPUT,@invalid bit',@BadOrdinal OUTPUT,@Invalid;
     IF @BadOrdinal<>0 THROW 59509,N'OVERVIEW_MODULE_ORDINAL',1;
    END;
    IF @JsonBit=1 AND @Help=0
    BEGIN
     SET @Array=JSON_QUERY(@Json,@Path);
     SET @Sql=N'SELECT @j=(SELECT '+CASE WHEN @Result=N'moduleStatus' THEN N'ResultName,ModuleName,StatusCode,IsPartial,ReturnedRowCount,DurationMs,ErrorMessage' ELSE N'*' END+N' FROM '+QUOTENAME(@Target)+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
     IF @Result=N'requests' SET @Sql=N'SELECT @j=(SELECT [r].[SessionId] AS [sessionId] , [r].[RequestId] AS [requestId] , [r].[RequestStatus] AS [requestStatus] , [r].[Command] AS [command] , [r].[DatabaseId] AS [databaseId] , [r].[DatabaseName] AS [databaseName] , [r].[LoginName] AS [loginName] , [r].[HostName] AS [hostName] , [r].[ProgramName] AS [programName] , [r].[IsToolBackgroundQuery] AS [isToolBackgroundQuery] , [r].[ToolBackgroundRuleCode] AS [toolBackgroundRuleCode] , [r].[ToolBackgroundCategory] AS [toolBackgroundCategory] , [r].[ToolBackgroundDetection] AS [toolBackgroundDetection] , [r].[ToolBackgroundConfidence] AS [toolBackgroundConfidence] , [r].[StartTime] AS [startTime] , [r].[ElapsedMs] AS [elapsedMs] , [r].[CpuMs] AS [cpuMs] , [r].[LogicalReads] AS [logicalReads] , [r].[Writes] AS [writes] , [r].[BlockingSessionId] AS [blockingSessionId] , [r].[WaitType] AS [waitType] , [wi].[WaitGroup] AS [waitGroup] , [wi].[Severity] AS [waitSeverity] , [r].[WaitTimeMs] AS [waitTimeMs] , [r].[RequestedMemoryMb] AS [requestedMemoryMb] , [r].[GrantedMemoryMb] AS [grantedMemoryMb] , [r].[UsedMemoryMb] AS [usedMemoryMb] , [r].[Dop] AS [dop] , [r].[ParallelWorkerCount] AS [parallelWorkerCount] , [r].[SchedulerId] AS [schedulerId] , [r].[TaskAddress] AS [taskAddress] , [r].[NestLevel] AS [nestLevel] , [r].[OpenTransactionCount] AS [openTransactionCount] , [r].[OpenResultsetCount] AS [openResultsetCount] , [r].[TransactionId] AS [transactionId] , [r].[ConnectionId] AS [connectionId] , [r].[WorkloadGroupId] AS [workloadGroupId] , [r].[WorkloadGroupName] AS [workloadGroupName] , [r].[ResourcePoolId] AS [resourcePoolId] , [r].[ResourcePoolName] AS [resourcePoolName] , [r].[StatementSqlHandle] AS [statementSqlHandle] , [r].[StatementContextId] AS [statementContextId] , [r].[IsResumable] AS [isResumable] , [r].[ExecutingManagedCode] AS [executingManagedCode] , [r].[ContextInfo] AS [contextInfo] , [r].[ModuleFullName] AS [moduleFullName] , [r].[ModuleTypeDescription] AS [moduleTypeDescription] , [r].[ExecutionContextType] AS [executionContextType] , [r].[QueryHash] AS [queryHash] , [r].[QueryPlanHash] AS [queryPlanHash] , [r].[SqlHandle] AS [sqlHandle] , [r].[PlanHandle] AS [planHandle] FROM '+QUOTENAME(@Target)+N' r CROSS APPLY monitor.TVF_WaitTypeInfo(r.WaitType) wi FOR JSON PATH,INCLUDE_NULL_VALUES);';
     SET @TableJson=NULL;EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@TableJson OUTPUT;SET @TableJson=COALESCE(@TableJson,N'[]');
     IF @Array IS NULL OR (SELECT COUNT(*) FROM OPENJSON(@TableJson))<>(SELECT COUNT(*) FROM OPENJSON(@Array)) THROW 59510,N'OVERVIEW_ARRAY_COUNTS',1;
     IF EXISTS(SELECT 1 FROM OPENJSON(@Array)a WHERE (SELECT COUNT(*) FROM OPENJSON(a.value))<>(SELECT COUNT(*) FROM STRING_SPLIT(@Keys,N'|'))+CASE WHEN @Extra IS NULL THEN 0 ELSE(SELECT COUNT(*) FROM STRING_SPLIT(@Extra,N'|')) END
       OR EXISTS(SELECT 1 FROM OPENJSON(a.value)GROUP BY [key] HAVING COUNT(*)<>1)
       OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM STRING_SPLIT(@Keys+CASE WHEN @Extra IS NULL THEN N'' ELSE N'|'+@Extra END,N'|')))
      THROW 59511,N'OVERVIEW_ARRAY_FIELD_KEYS',1;
     DELETE #ExampleOverviewCanonical;
     INSERT #ExampleOverviewCanonical SELECT 0,x.CanonicalRow FROM OPENJSON(@TableJson)a CROSS APPLY
      (SELECT STRING_AGG(CONVERT(nvarchar(max),CONCAT(DATALENGTH(p.[key]),N':',p.[key] COLLATE Latin1_General_100_BIN2,N':',p.[type],N':',COALESCE(CONVERT(nvarchar(20),DATALENGTH(p.value)),N'NULL'),N':',p.value COLLATE Latin1_General_100_BIN2)),N'|')WITHIN GROUP(ORDER BY p.[key] COLLATE Latin1_General_100_BIN2) CanonicalRow FROM OPENJSON(a.value)p)x;
     INSERT #ExampleOverviewCanonical SELECT 1,x.CanonicalRow FROM OPENJSON(@Array)a CROSS APPLY
      (SELECT STRING_AGG(CONVERT(nvarchar(max),CONCAT(DATALENGTH(p.[key]),N':',p.[key] COLLATE Latin1_General_100_BIN2,N':',p.[type],N':',COALESCE(CONVERT(nvarchar(20),DATALENGTH(p.value)),N'NULL'),N':',p.value COLLATE Latin1_General_100_BIN2)),N'|')WITHIN GROUP(ORDER BY p.[key] COLLATE Latin1_General_100_BIN2) CanonicalRow
       FROM OPENJSON(a.value)p WHERE EXISTS(SELECT 1 FROM STRING_SPLIT(@Keys,N'|') k WHERE k.value COLLATE Latin1_General_100_BIN2=p.[key] COLLATE Latin1_General_100_BIN2))x;
     IF EXISTS(SELECT CanonicalRow,COUNT(*) FROM #ExampleOverviewCanonical WHERE Side=0 GROUP BY CanonicalRow EXCEPT SELECT CanonicalRow,COUNT(*) FROM #ExampleOverviewCanonical WHERE Side=1 GROUP BY CanonicalRow)
      OR EXISTS(SELECT CanonicalRow,COUNT(*) FROM #ExampleOverviewCanonical WHERE Side=1 GROUP BY CanonicalRow EXCEPT SELECT CanonicalRow,COUNT(*) FROM #ExampleOverviewCanonical WHERE Side=0 GROUP BY CanonicalRow) THROW 59512,N'OVERVIEW_FULL_SAMECALL_VALUES',1;
    END;
   END;
   FETCH NEXT FROM Maps192 INTO @Bit,@Result,@Target,@Schema,@Path,@Fields,@Keys,@Extra,@ModuleBit;
  END;
  CLOSE Maps192;DEALLOCATE Maps192;
  IF @Help=0 AND @JsonBit=1
  BEGIN
   IF @Invalid=1
   BEGIN
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.snapshotStatus'))<>0 OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>0
     OR ISNULL(JSON_VALUE(@Json,N'$.moduleStatus[0].IsPartial'),N'')<>N'true' THROW 59513,N'OVERVIEW_INVALID_STATUS',1;
   END
   ELSE
   BEGIN
    DECLARE @ExecCount int=(SELECT COUNT(*) FROM #ExampleOverviewMaps WHERE ModuleBit<>0 AND ResultName NOT IN(N'requestContext',N'statements',N'batches',N'inputBuffers',N'tempdbGovernance') AND (ModuleBit&@Mask)<>0);
    DECLARE @Failed int=(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.moduleStatus')WITH(StatusCode varchar(40) '$.StatusCode')x WHERE StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED','SKIPPED'));
    DECLARE @Partial int=(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.moduleStatus')WITH(IsPartial bit '$.IsPartial')x WHERE IsPartial=1);
    DECLARE @SnapPartial bit=CASE WHEN EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.snapshotStatus')WITH(StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial')x WHERE IsPartial=1 OR StatusCode NOT IN('AVAILABLE','NOT_COLLECTED'))THEN 1 ELSE 0 END;
    DECLARE @ExpectedParent varchar(40)=CASE WHEN @ExecCount=0 THEN 'AVAILABLE' WHEN @Failed=0 AND @Partial=0 AND @SnapPartial=0 THEN 'AVAILABLE' WHEN @Failed<@ExecCount OR @SnapPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'ERROR_HANDLED' END;
    IF ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.executedModules')),-1)<>@ExecCount OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.failedModules')),-1)<>@Failed
     OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.partialModules')),-1)<>@Partial OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@ExpectedParent
     OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Failed>0 OR @Partial>0 OR @SnapPartial=1 THEN N'true' ELSE N'false' END THROW 59514,N'OVERVIEW_STATUS_COUNTS',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.moduleStatus')a JOIN(VALUES(0,N'sessions',N'USP_CurrentSessions'),(1,N'requests',N'USP_CurrentRequests'),(2,N'blocking',N'USP_CurrentBlocking'),(3,N'waits',N'USP_CurrentWaits'),(4,N'transactions',N'USP_CurrentTransactions'),(5,N'memoryGrants',N'USP_CurrentMemoryGrants'),(6,N'tempdbSessions',N'USP_CurrentTempDB'),(7,N'io',N'USP_CurrentIO'),(8,N'logs',N'USP_CurrentLog'))e(n,r,m)ON TRY_CONVERT(int,a.[key])=e.n
     WHERE ISNULL(JSON_VALUE(a.value,N'$.ResultName'),N'') COLLATE Latin1_General_100_BIN2<>e.r COLLATE Latin1_General_100_BIN2 OR ISNULL(JSON_VALUE(a.value,N'$.ModuleName'),N'') COLLATE Latin1_General_100_BIN2<>e.m COLLATE Latin1_General_100_BIN2) THROW 59515,N'OVERVIEW_MODULE_IDENTITIES_ORDER',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.moduleStatus')a WHERE JSON_VALUE(a.value,N'$.StatusCode')=N'SKIPPED'
      AND(JSON_VALUE(a.value,N'$.IsPartial')<>N'false' OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.ReturnedRowCount')),-1)<>0)) THROW 59515,N'OVERVIEW_SKIPPED',1;
    DELETE #ExampleOverviewExpectedWarnings;
    INSERT #ExampleOverviewExpectedWarnings SELECT ModuleName,StatusCode,ErrorMessage FROM OPENJSON(@Json,N'$.moduleStatus')WITH
     (ModuleName sysname '$.ModuleName',StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial',ErrorMessage nvarchar(2048) '$.ErrorMessage')m WHERE IsPartial=1 OR StatusCode NOT IN('AVAILABLE','SKIPPED');
    INSERT #ExampleOverviewExpectedWarnings SELECT N'CurrentStateSnapshot',StatusCode,COALESCE(ErrorMessage,CONCAT(N'Quelle ',SourceCode,N' wurde nur teilweise materialisiert.'))
     FROM OPENJSON(@Json,N'$.snapshotStatus')WITH(SourceCode varchar(40) '$.SourceCode',StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial',ErrorMessage nvarchar(2048) '$.ErrorMessage')x WHERE IsPartial=1 OR StatusCode NOT IN('AVAILABLE','NOT_COLLECTED');
    IF (SELECT COUNT(*) FROM #ExampleOverviewExpectedWarnings)<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))
     OR EXISTS(SELECT ModuleName,StatusCode,Message,COUNT(*) FROM #ExampleOverviewExpectedWarnings GROUP BY ModuleName,StatusCode,Message
      EXCEPT SELECT ModuleName,StatusCode,Message,COUNT(*) FROM OPENJSON(@Json,N'$.warnings')WITH(ModuleName sysname '$.ModuleName',StatusCode varchar(40) '$.StatusCode',Message nvarchar(2048) '$.Message')w GROUP BY ModuleName,StatusCode,Message)
     THROW 59514,N'OVERVIEW_WARNING_COUNTS_VALUES',1;
    IF @Case=14 AND (NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'tempdbSessions' AND [type]=0)
      OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.moduleStatus')WITH(ResultName sysname '$.ResultName',StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial',ReturnedRowCount bigint '$.ReturnedRowCount')x
       WHERE ResultName=N'tempdbSessions' AND StatusCode='ERROR_HANDLED' AND IsPartial=1 AND ReturnedRowCount=0))
      THROW 59524,N'OVERVIEW_CAUGHT_CHILD_NULL',1;
    IF @Mask<>0 AND @Mask<>256 AND(TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
      OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.snapshotStatus')a WHERE TRY_CONVERT(uniqueidentifier,JSON_VALUE(a.value,N'$.SnapshotId')) IS NULL
       OR JSON_VALUE(a.value,N'$.SnapshotId')<>JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId') OR TRY_CONVERT(datetime2(3),JSON_VALUE(a.value,N'$.CapturedAtUtc')) IS NULL
       OR TRY_CONVERT(datetime2(3),JSON_VALUE(a.value,N'$.CompletedAtUtc')) IS NULL OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(a.value,N'$.CapturedRowCount')),-1)<0)) THROW 59516,N'OVERVIEW_SNAPSHOT_IDENTITY',1;
   END;
  END;
  IF @Native=1
  BEGIN
   IF EXISTS(SELECT 1 FROM #ExampleOverviewFixture f LEFT JOIN sys.dm_exec_sessions s ON s.session_id=f.SessionId WHERE s.session_id IS NULL OR ISNULL(s.program_name,N'') COLLATE Latin1_General_100_BIN2<>f.ExpectedApp) THROW 59517,N'OVERVIEW_FIXTURE_AFTER',1;
   IF @G=1 AND(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.memoryGrants.memoryGrants'))<>0 THROW 59518,N'OVERVIEW_EMPTY_GRANT_SCOPE',1;
   SET @NativeCases+=1;
  END ELSE SET @Core+=1;
  DROP TABLE #ExampleOverviewOut_sessions;
  DROP TABLE #ExampleOverviewOut_requests;
  DROP TABLE #ExampleOverviewOut_requestContext;
  DROP TABLE #ExampleOverviewOut_statements;
  DROP TABLE #ExampleOverviewOut_batches;
  DROP TABLE #ExampleOverviewOut_inputBuffers;
  DROP TABLE #ExampleOverviewOut_blocking;
  DROP TABLE #ExampleOverviewOut_waits;
  DROP TABLE #ExampleOverviewOut_transactions;
  DROP TABLE #ExampleOverviewOut_memoryGrants;
  DROP TABLE #ExampleOverviewOut_tempdbSessions;
  DROP TABLE #ExampleOverviewOut_tempdbGovernance;
  DROP TABLE #ExampleOverviewOut_io;
  DROP TABLE #ExampleOverviewOut_logs;
  DROP TABLE #ExampleOverviewOut_moduleStatus;
  DROP TABLE #ExampleOverviewOut_snapshotStatus;
  DROP TABLE #ExampleOverviewOut_warnings;
  FETCH NEXT FROM Cases192 INTO @Case,@Native,@Mask,@MapMask,@Max,@Text,@Sample,@Detail,@Help,@JsonBit,@Bad,@Tools,@Ids;
 END;
 CLOSE Cases192;DEALLOCATE Cases192;
 IF @NativeCases>0 SET @FixtureStatus='PASS';
END TRY
BEGIN CATCH
 DECLARE @CatchSql nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';EXEC sys.sp_executesql @CatchSql;
 THROW;
END CATCH;
CREATE TABLE #ExampleOverviewSummary(ModuleName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,IsPartial bit NOT NULL,
 ReturnedRowCount bigint NOT NULL,DurationMs bigint NOT NULL,ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SET @N=0;
WHILE @N<3
BEGIN
 TRUNCATE TABLE #ExampleOverviewSummary;SET @Detail=CASE @N WHEN 0 THEN 'SUMMARY' WHEN 1 THEN 'RELEVANT' ELSE 'ALL' END;
 INSERT #ExampleOverviewSummary EXEC monitor.USP_CurrentOverview
 @MitSessions=0,@MitRequests=0,@MitBlocking=0,@MitWaits=0,@MitTransactions=0,@MitMemoryGrants=0,@MitTempDB=0,@MitIO=0,@MitLog=0,
 @MitSqlText=0,@MaxZeilen=1,@Detailgrad=@Detail,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT(*) FROM #ExampleOverviewSummary)<>9 OR EXISTS(SELECT 1 FROM #ExampleOverviewSummary WHERE StatusCode<>'SKIPPED' OR IsPartial<>0 OR ReturnedRowCount<>0 OR DurationMs<>0 OR ErrorMessage IS NOT NULL)
  THROW 59519,N'OVERVIEW_SUMMARY_CONSOLE',1;
 IF EXISTS(SELECT ModuleName,StatusCode,IsPartial,ReturnedRowCount,DurationMs,ErrorMessage FROM #ExampleOverviewSummary
  EXCEPT SELECT ModuleName,StatusCode,IsPartial,ReturnedRowCount,DurationMs,ErrorMessage FROM OPENJSON(@Json,N'$.moduleStatus')WITH
  (ModuleName sysname '$.ModuleName',StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial',ReturnedRowCount bigint '$.ReturnedRowCount',DurationMs bigint '$.DurationMs',ErrorMessage nvarchar(2048) '$.ErrorMessage'))
  THROW 59519,N'OVERVIEW_CONSOLE_JSON',1;
 IF @@LOCK_TIMEOUT<>137 THROW 59502,N'OVERVIEW_CONSOLE_LOCK',1;
 SET @Consumers+=1;SET @N+=1;
END;
SET @N=0;
WHILE @N<2
BEGIN
 DECLARE @ConsumerMode varchar(16)=CASE WHEN @N=0 THEN 'RAW' ELSE 'NONE' END;
 EXEC monitor.USP_CurrentOverview @MitSessions=0,@MitRequests=0,@MitBlocking=0,@MitWaits=0,@MitTransactions=0,@MitMemoryGrants=0,@MitTempDB=0,@MitIO=0,@MitLog=0,
 @ResultSetArt=@ConsumerMode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'AVAILABLE' OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
  OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.moduleStatus'))<>9 THROW 59520,N'OVERVIEW_OTHER_CONSUMER',1;
 SET @Consumers+=1;SET @N+=1;
END;
CREATE TABLE #ExampleOverviewBadTarget(Seed int NULL);
CREATE TABLE #ExampleOverviewOtherTarget(Seed int NULL);
DECLARE @P int=0,@Combination int,@Caught int,@Mode varchar(16),@BadMap nvarchar(max),@BadMax int,@BadHelp bit,@BadDetail varchar(16);
WHILE @P<8
BEGIN
 SET @BadMap=CASE @P
 WHEN 0 THEN N'{' WHEN 1 THEN N'{"unknown":"#ExampleOverviewBadTarget"}'
 WHEN 2 THEN N'{"moduleStatus":"#ExampleOverviewBadTarget","moduleStatus":"#ExampleOverviewOtherTarget"}'
 WHEN 3 THEN N'{}' WHEN 4 THEN N'{"ModuleStatus":"#ExampleOverviewBadTarget"}'
 WHEN 5 THEN N'{"moduleStatus":"#ExampleOverviewMissingTarget"}'
 WHEN 6 THEN N'{"moduleStatus":1}' ELSE N'{"moduleStatus":"#ExampleOverviewBadTarget"}' END;
 TRUNCATE TABLE #ExampleOverviewBadTarget;
 IF @P=7 INSERT #ExampleOverviewBadTarget VALUES(7);
 SET @Combination=0;
 WHILE @Combination<5
 BEGIN
  SET @Caught=NULL;SET @Json=N'ExampleSentinel';
  SELECT @BadMax=CASE WHEN @Combination=1 THEN -1 ELSE 1 END,@BadHelp=CASE WHEN @Combination=2 THEN 1 ELSE 0 END,
   @BadDetail=CASE WHEN @Combination=3 THEN 'INVALID' ELSE 'SUMMARY' END,@Mode=CASE WHEN @Combination=4 THEN 'UNSUPPORTED' ELSE 'TABLE' END;
  BEGIN TRY
   EXEC monitor.USP_CurrentOverview @MitSessions=0,@MitRequests=0,@MitBlocking=0,@MitWaits=0,@MitTransactions=0,@MitMemoryGrants=0,@MitTempDB=0,@MitIO=0,@MitLog=0,
    @MaxZeilen=@BadMax,@Hilfe=@BadHelp,@Detailgrad=@BadDetail,@ResultSetArt=@Mode,@ResultTablesJson=@BadMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF ISNULL(@Caught,0)<>51011 OR @Json<>N'ExampleSentinel'
   OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleOverviewBadTarget'))<>1
   OR (SELECT COUNT(*) FROM #ExampleOverviewBadTarget)<>CASE WHEN @P=7 THEN 1 ELSE 0 END
   OR (@P=7 AND NOT EXISTS(SELECT 1 FROM #ExampleOverviewBadTarget WHERE Seed=7)) OR @@LOCK_TIMEOUT<>137
   THROW 59521,N'OVERVIEW_MAPPING_PRIORITY_SEED',1;
  SET @Preflight+=1;SET @Combination+=1;
 END;
 SET @P+=1;
END;
-- Apply the same independent identity/type/value test to a real captured module row
-- and to three copies whose required text evidence was replaced by JSON NULL.
DECLARE @NullMutations int=0,@Mutated nvarchar(max),@ExpectedIdentity nvarchar(max)=
 N'{"ResultName":"sessions","ModuleName":"USP_CurrentSessions","StatusCode":"SKIPPED","IsPartial":false,"ReturnedRowCount":0,"DurationMs":0,"ErrorMessage":null}',
 @MutationField sysname,@Reject bit,@MutationNumber int=0;
IF @IdentityRow IS NULL THROW 59522,N'OVERVIEW_IDENTITY_ROW_MISSING',1;
WHILE @MutationNumber<4
BEGIN
 SET @MutationField=CASE @MutationNumber WHEN 1 THEN N'ResultName' WHEN 2 THEN N'ModuleName' ELSE N'StatusCode' END;
 SET @Mutated=CASE WHEN @MutationNumber=0 THEN @IdentityRow ELSE JSON_MODIFY(@IdentityRow,N'strict $.'+@MutationField,NULL) END;
 SET @Reject=CASE WHEN (SELECT COUNT(*) FROM OPENJSON(@Mutated))<>7
  OR EXISTS(SELECT 1 FROM OPENJSON(@Mutated)GROUP BY [key] HAVING COUNT(*)<>1)
  OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Mutated)
   EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@ExpectedIdentity))
  OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@ExpectedIdentity)
   EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Mutated)) THEN 1 ELSE 0 END;
 IF (@MutationNumber=0 AND @Reject<>0) OR (@MutationNumber>0 AND @Reject<>1) THROW 59522,N'OVERVIEW_NULL_MUTATION_REJECTION',1;
 IF @MutationNumber>0 SET @NullMutations+=1;
 SET @MutationNumber+=1;
END;
IF @FixtureStatus='PASS'
BEGIN
 EXEC monitor.USP_CurrentOverview @SessionIds=@FixtureIds,@ToolHintergrundabfragenEinbeziehen=1,@MitSessions=1,@MitRequests=0,@MitBlocking=0,@MitWaits=0,
 @MitTransactions=0,@MitMemoryGrants=0,@MitTempDB=0,@MitIO=0,@MitLog=0,@MitSqlText=0,@ResultSetArt='CONSOLE',@Detailgrad='SUMMARY',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sessions.sessions'))<>4 THROW 59523,N'OVERVIEW_NATIVE_CONSOLE_STATUS_JSON',1;
 SET @Consumers+=1;
END;
DECLARE @RestoreSql nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';EXEC sys.sp_executesql @RestoreSql;
SELECT 'PASS' ContractStatus,@Level FrameworkLevel,@Core CoreCases,@NativeCases NativeCases,@FixtureStatus PositiveFixtureStatus,@Consumers ConsumerCases,@Preflight PreflightCases,@NullMutations NullMutationRejections,17 ConditionalExports,540 ActiveLiteralFields;
GO