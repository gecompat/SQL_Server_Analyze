/*
===============================================================================
Datei        : 078_CompleteFileIOInstallation.sql
Version      : 1.3.1
Stand        : 2026-10-26
Zweck        : Die Quelle prüft die gesamte Collectorclosure und markiert erst
               nach kompatiblen Seeds und tatsächlichem Retentionsvertrag den Abschluss.
===============================================================================
*/
SET NOCOUNT ON;
SET LOCK_TIMEOUT 0;
-- SNAPSHOT_FILE_IO_METRIC_CONTRACT_BEGIN
DECLARE @SnapshotFileIOExpectedMetrics TABLE
([MetricCode] varchar(96) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
 [ValueType] varchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
 [Unit] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL);
INSERT @SnapshotFileIOExpectedMetrics VALUES
 ('IO_READ_COUNT','BIGINT','count'),
 ('IO_READ_BYTES','BIGINT','bytes'),
 ('IO_READ_STALL_MS','BIGINT','ms'),
 ('IO_WRITE_COUNT','BIGINT','count'),
 ('IO_WRITE_BYTES','BIGINT','bytes'),
 ('IO_WRITE_STALL_MS','BIGINT','ms'),
 ('IO_SIZE_ON_DISK_BYTES','BIGINT','bytes'),
 ('IO_READ_COUNT_DELTA_CANDIDATE','BIGINT','count'),
 ('IO_READ_BYTES_DELTA_CANDIDATE','BIGINT','bytes'),
 ('IO_READ_STALL_MS_DELTA_CANDIDATE','BIGINT','ms'),
 ('IO_WRITE_COUNT_DELTA_CANDIDATE','BIGINT','count'),
 ('IO_WRITE_BYTES_DELTA_CANDIDATE','BIGINT','bytes'),
 ('IO_WRITE_STALL_MS_DELTA_CANDIDATE','BIGINT','ms'),
 ('IO_DELTA_STATUS','STRING','status'),
 ('IO_FILE_CONTEXT','STRING','json'),
 ('IO_CAPTURE_CONTEXT','STRING','json');
-- SNAPSHOT_FILE_IO_METRIC_CONTRACT_END
-- SNAPSHOT_FILE_IO_SEED_CHECK_BEGIN
IF EXISTS(SELECT 1 FROM [snapshot].[MetricDefinition] AS [d]
 JOIN @SnapshotFileIOExpectedMetrics AS [e] ON [d].[MetricCode]=[e].[MetricCode]
 WHERE CONVERT(varbinary(max),[d].[MetricCode])<>CONVERT(varbinary(max),[e].[MetricCode])
 OR CONVERT(varbinary(max),[d].[ValueType])<>CONVERT(varbinary(max),[e].[ValueType])
 OR CONVERT(varbinary(max),[d].[Unit])<>CONVERT(varbinary(max),[e].[Unit]) OR [d].[ContractVersion]<>1)
 THROW 53780,N'Eine vorhandene Datei-I/O-Metrik widerspricht dem Vertrag.',1;
-- SNAPSHOT_FILE_IO_SEED_CHECK_END
IF DB_ID()<=4 OR (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1
 OR NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion]
 WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
 AND [PackageVersion]='1.2.2' AND [SchemaVersion]=3)
 THROW 53781,N'Die gemeinsame Collectorclosure benötigt das geprüfte Schema-3-Stadium.',1;
DECLARE @FileIOHelpers TABLE([Name] sysname COLLATE DATABASE_DEFAULT PRIMARY KEY,[Id] int NULL);
INSERT @FileIOHelpers([Name],[Id])
SELECT [e].[Name],[p].[object_id]
FROM (VALUES(N'InternalConfigureSnapshotPolicy'),(N'InternalPrepareCollectionCycle'),
 (N'InternalCompletePerformanceCounterCycle'),(N'InternalCompleteWaitStatsCycle'),
 (N'InternalCompleteFileIOCycle'),(N'InternalFinalizeCollectionCycle'),(N'InternalPurgeExpiredData')) [e]([Name])
LEFT JOIN [sys].[procedures] [p] WITH (NOLOCK)
 ON CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[Name])
 AND [p].[schema_id] IN(SELECT [schema_id] FROM [sys].[schemas] WITH (NOLOCK)
 WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N'snapshot'));
IF EXISTS(SELECT 1 FROM @FileIOHelpers AS [h] WHERE NOT EXISTS
 (SELECT 1 FROM [sys].[procedures] AS [p] WITH (NOLOCK) JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
 JOIN [sys].[sql_modules] AS [m] WITH (NOLOCK) ON [m].[object_id]=[p].[object_id]
 WHERE CONVERT(varbinary(max),[s].[name])=CONVERT(varbinary(max),N'snapshot')
 AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[h].[Name])
 AND [m].[uses_ansi_nulls]=1 AND [m].[uses_quoted_identifier]=1))
 THROW 53781,N'Die vollständige gemeinsame Helperclosure fehlt.',1;
DECLARE @FileIOParameters TABLE([Procedure] sysname COLLATE DATABASE_DEFAULT,[Ordinal] int,[Name] sysname COLLATE DATABASE_DEFAULT,[TypeId] int,[Length] int,[Output] bit);
INSERT @FileIOParameters VALUES
 (N'InternalConfigureSnapshotPolicy',1,N'@CollectionIntervalSeconds',52,2,0),
 (N'InternalConfigureSnapshotPolicy',2,N'@MaxRows',56,4,0),
 (N'InternalConfigureSnapshotPolicy',3,N'@PayloadEnabled',104,1,0),
 (N'InternalConfigureSnapshotPolicy',4,N'@RawRetentionDays',52,2,0),
 (N'InternalConfigureSnapshotPolicy',5,N'@PayloadRetentionDays',52,2,0),
 (N'InternalConfigureSnapshotPolicy',6,N'@RollupRetentionDays',52,2,0),
 (N'InternalConfigureSnapshotPolicy',7,N'@SoftBudgetMB',56,4,0),
 (N'InternalConfigureSnapshotPolicy',8,N'@PurgeIntervalMinutes',52,2,0),
 (N'InternalConfigureSnapshotPolicy',9,N'@PurgeBatchRows',56,4,0),
 (N'InternalConfigureSnapshotPolicy',10,N'@BudgetAction',167,32,0),
 (N'InternalConfigureSnapshotPolicy',11,N'@StatusCodeOut',167,40,1),
 (N'InternalConfigureSnapshotPolicy',12,N'@ErrorNumberOut',56,4,1),
 (N'InternalConfigureSnapshotPolicy',13,N'@ErrorMessageOut',231,4096,1),
 (N'InternalConfigureSnapshotPolicy',14,N'@CollectorCode',167,64,0),
 (N'InternalConfigureSnapshotPolicy',15,N'@CollectorEnabled',104,1,0),
 (N'InternalConfigureSnapshotPolicy',16,N'@UpdateSharedPolicy',104,1,0),
 (N'InternalConfigureSnapshotPolicy',17,N'@ExpectedTargetDatabaseId',56,4,0),
 (N'InternalConfigureSnapshotPolicy',18,N'@ExpectedTargetDatabaseName',231,256,0),
 (N'InternalConfigureSnapshotPolicy',19,N'@ExpectedTargetCreateDate',61,8,0),
 (N'InternalConfigureSnapshotPolicy',20,N'@JoinFrameworkTransaction',104,1,0),
 (N'InternalPrepareCollectionCycle',1,N'@SourceDatabaseName',231,256,0),
 (N'InternalPrepareCollectionCycle',2,N'@SchedulerType',167,16,0),
 (N'InternalPrepareCollectionCycle',3,N'@RunEvenIfNotDue',104,1,0),
 (N'InternalPrepareCollectionCycle',4,N'@CaptureRunIdOut',127,8,1),
 (N'InternalPrepareCollectionCycle',5,N'@ShouldCollectOut',104,1,1),
 (N'InternalPrepareCollectionCycle',6,N'@StatusCodeOut',167,40,1),
 (N'InternalPrepareCollectionCycle',7,N'@ErrorMessageOut',231,4096,1),
 (N'InternalPrepareCollectionCycle',8,N'@CollectorCode',167,64,0),
 (N'InternalPrepareCollectionCycle',9,N'@ExpectedTargetDatabaseId',56,4,0),
 (N'InternalPrepareCollectionCycle',10,N'@ExpectedTargetDatabaseName',231,256,0),
 (N'InternalPrepareCollectionCycle',11,N'@ExpectedTargetCreateDate',61,8,0),
 (N'InternalPrepareCollectionCycle',12,N'@PolicyOnly',104,1,0),
 (N'InternalCompletePerformanceCounterCycle',1,N'@CaptureRunId',127,8,0),
 (N'InternalCompletePerformanceCounterCycle',2,N'@CollectorJson',231,-1,0),
 (N'InternalCompletePerformanceCounterCycle',3,N'@SourceStatusCode',167,40,0),
 (N'InternalCompletePerformanceCounterCycle',4,N'@SourceIsPartial',104,1,0),
 (N'InternalCompletePerformanceCounterCycle',5,N'@SourceErrorNumber',56,4,0),
 (N'InternalCompletePerformanceCounterCycle',6,N'@SourceErrorMessage',231,4096,0),
 (N'InternalCompletePerformanceCounterCycle',7,N'@StatusCodeOut',167,40,1),
 (N'InternalCompletePerformanceCounterCycle',8,N'@IsPartialOut',104,1,1),
 (N'InternalCompletePerformanceCounterCycle',9,N'@ErrorNumberOut',56,4,1),
 (N'InternalCompletePerformanceCounterCycle',10,N'@ErrorMessageOut',231,4096,1),
 (N'InternalCompleteWaitStatsCycle',1,N'@CaptureRunId',127,8,0),
 (N'InternalCompleteWaitStatsCycle',2,N'@CollectorJson',231,-1,0),
 (N'InternalCompleteWaitStatsCycle',3,N'@ExpectedTargetDatabaseId',56,4,0),
 (N'InternalCompleteWaitStatsCycle',4,N'@ExpectedTargetDatabaseName',231,256,0),
 (N'InternalCompleteWaitStatsCycle',5,N'@ExpectedTargetCreateDate',61,8,0),
 (N'InternalCompleteWaitStatsCycle',6,N'@StatusCodeOut',167,40,1),
 (N'InternalCompleteWaitStatsCycle',7,N'@IsPartialOut',104,1,1),
 (N'InternalCompleteWaitStatsCycle',8,N'@ErrorNumberOut',56,4,1),
 (N'InternalCompleteWaitStatsCycle',9,N'@ErrorMessageOut',231,4096,1),
 (N'InternalCompleteFileIOCycle',1,N'@CaptureRunId',127,8,0),
 (N'InternalCompleteFileIOCycle',2,N'@CollectorJson',231,-1,0),
 (N'InternalCompleteFileIOCycle',3,N'@ExpectedTargetDatabaseId',56,4,0),
 (N'InternalCompleteFileIOCycle',4,N'@ExpectedTargetDatabaseName',231,256,0),
 (N'InternalCompleteFileIOCycle',5,N'@ExpectedTargetCreateDate',61,8,0),
 (N'InternalCompleteFileIOCycle',6,N'@StatusCodeOut',167,40,1),
 (N'InternalCompleteFileIOCycle',7,N'@IsPartialOut',104,1,1),
 (N'InternalCompleteFileIOCycle',8,N'@ErrorNumberOut',56,4,1),
 (N'InternalCompleteFileIOCycle',9,N'@ErrorMessageOut',231,4096,1),
 (N'InternalFinalizeCollectionCycle',1,N'@CaptureRunId',127,8,0),
 (N'InternalFinalizeCollectionCycle',2,N'@StatusCode',167,40,0),
 (N'InternalFinalizeCollectionCycle',3,N'@IsPartial',104,1,0),
 (N'InternalFinalizeCollectionCycle',4,N'@ErrorNumber',56,4,0),
 (N'InternalFinalizeCollectionCycle',5,N'@ErrorMessage',231,4096,0),
 (N'InternalPurgeExpiredData',1,N'@MaxBatches',56,4,0),
 (N'InternalPurgeExpiredData',2,N'@Force',104,1,0),
 (N'InternalPurgeExpiredData',3,N'@PurgeRunIdOut',127,8,1),
 (N'InternalPurgeExpiredData',4,N'@StatusCodeOut',167,40,1),
 (N'InternalPurgeExpiredData',5,N'@BudgetExceededOut',104,1,1),
 (N'InternalPurgeExpiredData',6,N'@ErrorNumberOut',56,4,1),
 (N'InternalPurgeExpiredData',7,N'@ErrorMessageOut',231,4096,1),
 (N'InternalPurgeExpiredData',8,N'@ContractOnly',104,1,0),
 (N'InternalPurgeExpiredData',9,N'@RetentionContractVersionOut',56,4,1),
 (N'InternalPurgeExpiredData',10,N'@ExpectedTargetDatabaseId',56,4,0),
 (N'InternalPurgeExpiredData',11,N'@ExpectedTargetDatabaseName',231,256,0),
 (N'InternalPurgeExpiredData',12,N'@ExpectedTargetCreateDate',61,8,0);
IF EXISTS(SELECT 1 FROM @FileIOHelpers [h] WHERE
 (SELECT COUNT_BIG(*) FROM [sys].[parameters] [p] WITH (NOLOCK) WHERE [p].[object_id]=[h].[Id])<>
 (SELECT COUNT_BIG(*) FROM @FileIOParameters [e] WHERE [e].[Procedure]=[h].[Name]))
 OR EXISTS(SELECT 1 FROM @FileIOParameters [e] JOIN @FileIOHelpers [h] ON [h].[Name]=[e].[Procedure] WHERE NOT EXISTS
 (SELECT 1 FROM [sys].[parameters] [p] WITH (NOLOCK) WHERE [p].[object_id]=[h].[Id] AND [p].[parameter_id]=[e].[Ordinal]
 AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[Name])
 AND [p].[system_type_id]=[e].[TypeId] AND [p].[max_length]=[e].[Length] AND [p].[is_output]=[e].[Output]))
 THROW 53781,N'Die tatsächlichen typisierten Helpersignaturen fehlen.',1;
DECLARE @FinalWaitMetrics TABLE([Code] varchar(96) COLLATE DATABASE_DEFAULT,[Type] varchar(24) COLLATE DATABASE_DEFAULT,[Unit] varchar(40) COLLATE DATABASE_DEFAULT);
INSERT @FinalWaitMetrics VALUES
 ('WAIT_TASK_COUNT','BIGINT','count'),
 ('WAIT_TIME_MS','BIGINT','ms'),
 ('WAIT_SIGNAL_TIME_MS','BIGINT','ms'),
 ('WAIT_MAX_TIME_MS','BIGINT','ms'),
 ('WAIT_TASK_COUNT_DELTA_CANDIDATE','BIGINT','count'),
 ('WAIT_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
 ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
 ('WAIT_DELTA_STATUS','STRING','status'),
 ('WAIT_CAPTURE_CONTEXT','STRING','json');
IF EXISTS(SELECT 1 FROM @FinalWaitMetrics [e] WHERE NOT EXISTS
 (SELECT 1 FROM [snapshot].[MetricDefinition] [d] WHERE CONVERT(varbinary(max),[d].[MetricCode])=CONVERT(varbinary(max),[e].[Code])
 AND CONVERT(varbinary(max),[d].[ValueType])=CONVERT(varbinary(max),[e].[Type])
 AND CONVERT(varbinary(max),[d].[Unit])=CONVERT(varbinary(max),[e].[Unit]) AND [d].[ContractVersion]=1))
 OR NOT EXISTS(SELECT 1 FROM [snapshot].[CollectorPolicy] WHERE CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'WAIT_STATS'))
 THROW 53781,N'Der letzte Targetabschluss benötigt die tatsächlichen Waitseeds und ihre Policy.',1;
DECLARE @Run bigint,@Status varchar(40),@Budget bit,@Error int,@Message nvarchar(2048),@Contract int,
 @TargetId int=DB_ID(),@TargetName sysname,@Created datetime;
SELECT @Created=[create_date],@TargetName=[name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=@TargetId;
EXEC [snapshot].[InternalPurgeExpiredData] @MaxBatches=1,@Force=0,@PurgeRunIdOut=@Run OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@BudgetExceededOut=@Budget OUTPUT,@ErrorNumberOut=@Error OUTPUT,
 @ErrorMessageOut=@Message OUTPUT,@ContractOnly=1,@RetentionContractVersionOut=@Contract OUTPUT,
 @ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetDatabaseName=@TargetName,@ExpectedTargetCreateDate=@Created;
IF COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(@Contract,0)<>3 OR @Run IS NOT NULL OR COALESCE(@Budget,1)<>0 OR @Error IS NOT NULL
 THROW 53781,N'Der tatsächliche schreibfreie Retentionsvertrag 3 fehlt.',1;
INSERT [snapshot].[MetricDefinition]
([MetricCode],[ValueType],[Unit],[ContractVersion],[Description],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
SELECT [e].[MetricCode],[e].[ValueType],[e].[Unit],1,
 CASE WHEN [e].[MetricCode] LIKE '%_DELTA_CANDIDATE' THEN N'Monotoner Datei-I/O-Differenzkandidat mit unbewiesener Kontinuität.'
 ELSE N'Versionierter nativer Datei-I/O-Rohwert oder gebundener Aufnahmekontext.' END,1,1,SYSUTCDATETIME()
FROM @SnapshotFileIOExpectedMetrics AS [e]
WHERE NOT EXISTS(SELECT 1 FROM [snapshot].[MetricDefinition] AS [d] WHERE [d].[MetricCode]=[e].[MetricCode]);
IF NOT EXISTS(SELECT 1 FROM [snapshot].[CollectorPolicy] WHERE [CollectorCode]='FILE_IO')
 INSERT [snapshot].[CollectorPolicy]
 ([CollectorCode],[IsEnabled],[CollectionIntervalSeconds],[MaxRows],[PayloadEnabled],[RetentionPolicyCode],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
 VALUES('FILE_IO',0,30,1000,0,'DEFAULT',0,1,SYSUTCDATETIME());
UPDATE [snapshot].[PackageVersion] SET [PackageVersion]='1.3.1',[LastInstallerRunUtc]=SYSUTCDATETIME()
 WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023') AND [PackageVersion]='1.2.2' AND [SchemaVersion]=3;
IF @@ROWCOUNT<>1 THROW 53781,N'Der gemeinsame Targetabschluss konnte nicht markiert werden.',1;
GO
