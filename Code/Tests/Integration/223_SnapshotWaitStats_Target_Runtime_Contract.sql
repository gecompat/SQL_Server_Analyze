/*
Datei        : 223_SnapshotWaitStats_Target_Runtime_Contract.sql
Zweck        : Prüft ausschließlich das Target-Backend mit synthetischen Sourceobjekten.
Artefakt-UID : urn:uuid:01a1748d-9417-72b7-93c1-d99eb2883d2a
Registrierung: DEFERRED; keine finale lesbare Testkennung vergeben.
Grenze       : Keine native DMV-, Reset- oder öffentliche Collectorabnahme.
*/
GO
USE [SQLServerAnalyzeTest];
GO
IF (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CollectorCode]='WAIT_STATS')<>1
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
 WHERE [CollectorCode]='WAIT_STATS' AND [SourceDatabaseName]=N'ExampleWaitRetentionFramework')
 THROW 53770,N'Unexpected Wait history before owned backend fixture.',1;
DELETE [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
 WHERE [CollectorCode]='WAIT_STATS' AND [SourceDatabaseName]=N'ExampleWaitRetentionFramework';
DECLARE @WaitPrecisionRead datetime2(7)='2026-01-01T00:00:00.1236000',
        @WaitPrecisionCheck datetime2(7)='2026-01-01T00:00:00.1239000';
DECLARE @WaitPrecisionContract datetime2(3)=@WaitPrecisionRead;
IF @WaitPrecisionContract<=@WaitPrecisionCheck
   OR @WaitPrecisionContract>CONVERT(datetime2(3),@WaitPrecisionCheck)
    THROW 53770,N'Wait millisecond precision counterexample failed.',1;

DECLARE @WaitBackendSql nvarchar(max)=N'
DECLARE @DbId int=DB_ID(N''SQLServerAnalyzeSnapshotTest''),@Created datetime,
 @Status varchar(40),@Message nvarchar(2048),@Error int,@Partial bit,@Run bigint,@Collect bit,
 @Start datetime2(3),@Finish datetime2(3),@Source nvarchar(max),@Ctx nvarchar(4000);
SELECT @Created=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@DbId;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=N''ExampleWaitBackendFramework'',@SchedulerType=''MANUAL'',@RunEvenIfNotDue=1,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=''WAIT_STATS'',@ExpectedTargetDatabaseId=@DbId,
 @ExpectedTargetDatabaseName=N''SQLServerAnalyzeSnapshotTest'',@ExpectedTargetCreateDate=@Created;
IF COALESCE(@Collect,0)<>1 OR @Run IS NULL THROW 53770,N''Wait fixture could not prepare an owned run.'',1;
SELECT @Start=SYSUTCDATETIME();
WAITFOR DELAY ''00:00:00.020'';
SET @Finish=SYSUTCDATETIME();
IF @ForcePreviousTime=1
BEGIN
 SELECT TOP(1) @Start=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE([s].[StringValue],N''$.window.measurementEndUtc''),23),126)
 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [d].[MetricCode]=''WAIT_CAPTURE_CONTEXT'' AND [s].[CaptureRunId]<@Run ORDER BY [s].[CaptureRunId] DESC;
 SET @Finish=@Start;
 UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] SET [StartedAtUtc]=@Start WHERE [CaptureRunId]=@Run;
END;
SELECT @Source=(SELECT JSON_QUERY((SELECT 1 AS [schemaVersion],N''SnapshotWaitStats'' AS [resultName],
 CONVERT(nvarchar(19),@Start,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@Start)),3)+N''Z'' AS [measurementStartUtc],
 CONVERT(nvarchar(19),@Finish,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@Finish)),3)+N''Z'' AS [measurementEndUtc],
 CASE WHEN @Mutation=N''EMPTY'' THEN N''EMPTY_UNPROVEN'' WHEN @Mutation=N''SOURCE_DENIED'' THEN N''DENIED_PERMISSION'' ELSE N''AVAILABLE'' END AS [statusCode],
 CONVERT(bit,CASE WHEN @Mutation IN(N''EMPTY'',N''SOURCE_DENIED'') THEN 1 ELSE 0 END) AS [isPartial],
 CONVERT(int,CASE WHEN @Mutation=N''SOURCE_DENIED'' THEN 229 END) AS [errorNumber],
 CONVERT(nvarchar(2048),CASE WHEN @Mutation=N''SOURCE_DENIED'' THEN N''Example source permission failure.'' END) AS [errorMessage],
 CASE WHEN @Mutation=N''SOURCE_DENIED'' THEN NULL ELSE CONVERT(nvarchar(20),(SELECT COUNT_BIG(*) FROM OPENJSON(@Rows))) END AS [nativeRows],
 CONVERT(bit,CASE WHEN @Mutation=N''SOURCE_DENIED'' THEN 0 ELSE 1 END) AS [sourceComplete],JSON_QUERY(@Engine) AS [engineContext]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [meta],JSON_QUERY(@Rows) AS [waits]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
IF @Mutation=N''COUNTER_STRING'' SET @Source=JSON_MODIFY(@Source,N''$.waits[0].WaitingTasksCount'',N''1'');
IF @Mutation=N''COUNTER_NEGATIVE'' SET @Source=JSON_MODIFY(@Source,N''$.waits[0].WaitTimeMs'',-1);
IF @Mutation=N''COUNTER_FRACTION'' SET @Source=JSON_MODIFY(@Source,N''$.waits[0].WaitTimeMs'',CONVERT(decimal(10,1),1.5));
IF @Mutation=N''COUNT_MISMATCH'' SET @Source=JSON_MODIFY(@Source,N''$.meta.nativeRows'',N''999'');
IF @Mutation=N''COUNT_LEADING_ZERO'' SET @Source=JSON_MODIFY(@Source,N''$.meta.nativeRows'',N''01'');
IF @Mutation=N''EXTRA_MEMBER'' SET @Source=JSON_MODIFY(@Source,N''$.meta.unexpected'',1);
IF @Mutation=N''DUPLICATE_MEMBER'' SET @Source=REPLACE(@Source,N''"schemaVersion":1'',N''"schemaVersion":1,"schemaVersion":1'');
IF @Mutation=N''CASE_MEMBER'' SET @Source=REPLACE(@Source,N''"WaitType":'',N''"waitType":'');
IF @Mutation=N''ENGINE_NULL'' SET @Source=JSON_MODIFY(@Source,N''$.meta.engineContext'',NULL);
IF @Mutation=N''BAD_TIME'' SET @Source=JSON_MODIFY(@Source,N''$.meta.measurementEndUtc'',N''2026-01-01T00:00:00Z'');
IF @Mutation=N''BIGINT_OVERFLOW'' SET @Source=REPLACE(@Source,N''"WaitingTasksCount":1'',N''"WaitingTasksCount":9223372036854775808'');
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalCompleteWaitStatsCycle]
 @CaptureRunId=@Run,@CollectorJson=@Source,@ExpectedTargetDatabaseId=@DbId,
 @ExpectedTargetDatabaseName=N''SQLServerAnalyzeSnapshotTest'',@ExpectedTargetCreateDate=@Created,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF COALESCE(@Status,'''')<>@WantOuter OR COALESCE(@Partial,0)<>1
BEGIN
 DECLARE @Failure nvarchar(2048)=CONCAT(N''Wait case '',@Case,N'': '',@Status,N''/'',@Error,N''/'',@Message);
 THROW 53770,@Failure,1;
END;
SELECT @Ctx=[s].[StringValue] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@Run AND [d].[MetricCode]=''WAIT_CAPTURE_CONTEXT'';
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
 WHERE [CaptureRunId]=@Run AND [MetricSampleCount]=@WantSamples AND [EndedAtUtc] IS NOT NULL AND [SqlServerStartTimeUtc] IS NULL)
 THROW 53770,N''Wait fixture final counts or time label failed.'',1;
IF @WantOuter=''PARTIAL''
BEGIN
 IF @Error IS NOT NULL OR @Ctx IS NULL OR COALESCE(JSON_VALUE(@Ctx,N''$.comparison.status''),N'''')<>@WantCompare
    OR COALESCE(JSON_VALUE(@Ctx,N''$.epochDecision''),N'''')<>@WantEpoch OR DATALENGTH(@Ctx)>8000
 BEGIN
  DECLARE @DecisionFailure nvarchar(2048)=CONCAT(N''Wait case '',@Case,N'': context '',JSON_VALUE(@Ctx,N''$.comparison.status''),N''/'',JSON_VALUE(@Ctx,N''$.epochDecision''),N'' expected '',@WantCompare,N''/'',@WantEpoch);
  THROW 53770,@DecisionFailure,1;
 END;
 IF @Mutation=N''EMPTY'' AND COALESCE(JSON_VALUE(@Ctx,N''$.capture.rawProjectionSha256''),N'''')<>LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),N''[]'')),2))
  THROW 53770,N''Empty raw projection must hash the canonical UTF16 array.'',1;
 IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@Run AND [d].[MetricCode] LIKE ''%_DELTA_CANDIDATE''
   AND ([s].[BigintValue] IS NULL OR [s].[BigintValue]<0 OR [s].[QualityCode]<>''MONOTONIC_CONTINUITY_UNPROVEN'' OR [s].[IsPartial]<>1))
  THROW 53770,N''Wait fixture candidate quality failed.'',1;
END
ELSE IF @Ctx IS NOT NULL OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run)
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND [ResetEpochId] IS NULL)
 THROW 53770,N''Wait source failure invented a sample or epoch.'',1;
SELECT @RunOut=@Run,@ContextOut=@Ctx;
SELECT @EpochOut=[ResetEpochId] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run;
',
 @WaitBackendParams nvarchar(max)=N'@Rows nvarchar(max),@Engine nvarchar(max),@Mutation nvarchar(40),@ForcePreviousTime bit,@WantOuter varchar(40),@WantCompare varchar(40),@WantEpoch varchar(40),@WantSamples bigint,@Case nvarchar(80),@RunOut bigint OUTPUT,@ContextOut nvarchar(4000) OUTPUT,@EpochOut uniqueidentifier OUTPUT',
 @WaitBackendEngine nvarchar(max)=N'{"serverName":"ExampleSqlServer","sqlServerStartTimeLocal":"2000-01-01T00:00:00.000","sqlServerStartTimeMsTicks":"1"}',
 @WaitBackendRun bigint,@WaitBackendContext nvarchar(4000),@WaitBackendEpoch uniqueidentifier,@WaitBackendPreviousEpoch uniqueidentifier,
 @WaitBackendDb int=DB_ID(N'SQLServerAnalyzeSnapshotTest'),@WaitBackendCreated datetime,@WaitBackendStatus varchar(40),@WaitBackendError int,@WaitBackendMessage nvarchar(2048);
SELECT @WaitBackendCreated=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@WaitBackendDb;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy]
 WHERE [CollectorCode]='WAIT_STATS' AND [IsEnabled]=0 AND [PayloadEnabled]=0 AND [IsFrameworkDefault]=0)
 THROW 53770,N'Fresh Wait policy unexpectedly enabled.',1;
DECLARE @WaitSharedBefore nvarchar(max),@WaitSharedAfter nvarchar(max),@WaitPcBefore nvarchar(max),@WaitPcAfter nvarchar(max),
 @WaitCallerRun bigint,@WaitCallerCollect bit,@WaitCallerPartial bit,@WaitProbeRun bigint,@WaitProbeBudget bit,@WaitProbeVersion int,
 @WaitBeforeRuns bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]),
 @WaitBeforePurges bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun]);
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
 ([RetentionPolicyCode],[RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays],[SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows],[BudgetAction],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
 SELECT 'EXAMPLE_WAIT_CUSTOM',[RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays],[SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows],[BudgetAction],0,1,SYSUTCDATETIME()
 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy] WHERE [RetentionPolicyCode]='DEFAULT';
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [RetentionPolicyCode]='EXAMPLE_WAIT_CUSTOM' WHERE [CollectorCode]='WAIT_STATS';
SELECT @WaitSharedBefore=(SELECT * FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy] ORDER BY [RetentionPolicyCode] FOR JSON PATH,INCLUDE_NULL_VALUES),
 @WaitPcBefore=(SELECT * FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='PERFORMANCE_COUNTERS' FOR JSON PATH,INCLUDE_NULL_VALUES);
-- The read-only version handshake creates no purge receipt or run.
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData]
 @MaxBatches=1,@Force=0,@PurgeRunIdOut=@WaitProbeRun OUTPUT,@StatusCodeOut=@WaitBackendStatus OUTPUT,
 @BudgetExceededOut=@WaitProbeBudget OUTPUT,@ErrorNumberOut=@WaitBackendError OUTPUT,@ErrorMessageOut=@WaitBackendMessage OUTPUT,
 @ContractOnly=1,@RetentionContractVersionOut=@WaitProbeVersion OUTPUT,@ExpectedTargetDatabaseId=@WaitBackendDb,
 @ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@WaitBackendCreated;
IF @WaitProbeVersion<>1 OR @WaitProbeRun IS NOT NULL OR COALESCE(@WaitBackendStatus,'')<>'AVAILABLE'
 THROW 53770,N'Read-only retention handshake failed.',1;
DECLARE @WaitBadBinding int=1,@WaitBadId int,@WaitBadName sysname,@WaitBadCreated datetime;
WHILE @WaitBadBinding<=3
BEGIN
 SELECT @WaitBadId=CASE WHEN @WaitBadBinding=1 THEN 1 ELSE @WaitBackendDb END,
 @WaitBadName=CASE WHEN @WaitBadBinding=2 THEN N'ExampleWrongTarget' ELSE N'SQLServerAnalyzeSnapshotTest' END,
 @WaitBadCreated=CASE WHEN @WaitBadBinding=3 THEN DATEADD(SECOND,1,@WaitBackendCreated) ELSE @WaitBackendCreated END;
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalConfigureSnapshotPolicy]
 @CollectionIntervalSeconds=1,@MaxRows=10,@PayloadEnabled=0,@RawRetentionDays=14,@PayloadRetentionDays=7,
 @RollupRetentionDays=180,@SoftBudgetMB=10240,@PurgeIntervalMinutes=60,@PurgeBatchRows=1000,
 @BudgetAction='PURGE_EXPIRED_THEN_STOP',@StatusCodeOut=@WaitBackendStatus OUTPUT,@ErrorNumberOut=@WaitBackendError OUTPUT,
 @ErrorMessageOut=@WaitBackendMessage OUTPUT,@CollectorCode='WAIT_STATS',@CollectorEnabled=1,@UpdateSharedPolicy=0,
 @ExpectedTargetDatabaseId=@WaitBadId,@ExpectedTargetDatabaseName=@WaitBadName,@ExpectedTargetCreateDate=@WaitBadCreated;
 IF COALESCE(@WaitBackendStatus,'')<>'TARGET_UNAVAILABLE' OR @WaitBackendError<>53764 THROW 53770,N'Configure accepted foreign target binding.',1;
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=N'ExampleWaitBinding',@SchedulerType='MANUAL',@RunEvenIfNotDue=1,@CaptureRunIdOut=@WaitCallerRun OUTPUT,
 @ShouldCollectOut=@WaitCallerCollect OUTPUT,@StatusCodeOut=@WaitBackendStatus OUTPUT,@ErrorMessageOut=@WaitBackendMessage OUTPUT,
 @CollectorCode='WAIT_STATS',@ExpectedTargetDatabaseId=@WaitBadId,@ExpectedTargetDatabaseName=@WaitBadName,@ExpectedTargetCreateDate=@WaitBadCreated;
 IF COALESCE(@WaitBackendStatus,'')<>'TARGET_UNAVAILABLE' OR @WaitCallerRun IS NOT NULL OR @WaitCallerCollect<>0 THROW 53770,N'Prepare accepted foreign target binding.',1;
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalCompleteWaitStatsCycle]
 @CaptureRunId=1,@CollectorJson=N'{}',@ExpectedTargetDatabaseId=@WaitBadId,@ExpectedTargetDatabaseName=@WaitBadName,
 @ExpectedTargetCreateDate=@WaitBadCreated,@StatusCodeOut=@WaitBackendStatus OUTPUT,@IsPartialOut=@WaitCallerPartial OUTPUT,
 @ErrorNumberOut=@WaitBackendError OUTPUT,@ErrorMessageOut=@WaitBackendMessage OUTPUT;
 IF COALESCE(@WaitBackendStatus,'')<>'TARGET_UNAVAILABLE' OR @WaitBackendError<>53764 THROW 53770,N'Complete accepted foreign target binding.',1;
 SET @WaitBadBinding+=1;
END;
CREATE TABLE #WaitCallerSentinel([Value] int NOT NULL);
DECLARE @WaitCallerMode int=0,@WaitCallerOptions int,@WaitCallerXactState int,@WaitCallerAfterXactState int,@WaitCallerPolicy nvarchar(max);
WHILE @WaitCallerMode<=1
BEGIN
 SET XACT_ABORT ON;
 IF @WaitCallerMode=0 BEGIN TRANSACTION;
 ELSE SET IMPLICIT_TRANSACTIONS ON;
 IF @WaitCallerMode=0 INSERT #WaitCallerSentinel VALUES(1);
 SET @WaitCallerOptions=@@OPTIONS;
 SET @WaitCallerXactState=XACT_STATE();
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalConfigureSnapshotPolicy]
 @CollectionIntervalSeconds=1,@MaxRows=10,@PayloadEnabled=0,@RawRetentionDays=14,@PayloadRetentionDays=7,
 @RollupRetentionDays=180,@SoftBudgetMB=10240,@PurgeIntervalMinutes=60,@PurgeBatchRows=1000,
 @BudgetAction='PURGE_EXPIRED_THEN_STOP',@StatusCodeOut=@WaitBackendStatus OUTPUT,@ErrorNumberOut=@WaitBackendError OUTPUT,
 @ErrorMessageOut=@WaitBackendMessage OUTPUT,@CollectorCode='WAIT_STATS',@CollectorEnabled=1,@UpdateSharedPolicy=0,
 @ExpectedTargetDatabaseId=@WaitBackendDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@WaitBackendCreated;
 IF COALESCE(@WaitBackendStatus,'')<>'INVALID_PARAMETER' OR @WaitBackendError<>51011 THROW 53770,N'Configure accepted Wait caller state.',1;
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=N'ExampleWaitCaller',@SchedulerType='MANUAL',@RunEvenIfNotDue=1,@CaptureRunIdOut=@WaitCallerRun OUTPUT,
 @ShouldCollectOut=@WaitCallerCollect OUTPUT,@StatusCodeOut=@WaitBackendStatus OUTPUT,@ErrorMessageOut=@WaitBackendMessage OUTPUT,
 @CollectorCode='WAIT_STATS',@ExpectedTargetDatabaseId=@WaitBackendDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@WaitBackendCreated;
 IF COALESCE(@WaitBackendStatus,'')<>'INVALID_PARAMETER' OR @WaitCallerRun IS NOT NULL THROW 53770,N'Prepare accepted Wait caller state.',1;
 EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalCompleteWaitStatsCycle]
 @CaptureRunId=1,@CollectorJson=N'{}',@ExpectedTargetDatabaseId=@WaitBackendDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',
 @ExpectedTargetCreateDate=@WaitBackendCreated,@StatusCodeOut=@WaitBackendStatus OUTPUT,@IsPartialOut=@WaitCallerPartial OUTPUT,
 @ErrorNumberOut=@WaitBackendError OUTPUT,@ErrorMessageOut=@WaitBackendMessage OUTPUT;
 IF COALESCE(@WaitBackendStatus,'')<>'INVALID_PARAMETER' OR @WaitBackendError<>51011 THROW 53770,N'Complete accepted Wait caller state.',1;
 SET @WaitCallerAfterXactState=XACT_STATE();
 IF @@OPTIONS<>@WaitCallerOptions OR @@TRANCOUNT<>CASE WHEN @WaitCallerMode=0 THEN 1 ELSE 0 END
  OR @WaitCallerAfterXactState<>@WaitCallerXactState
 BEGIN
  DECLARE @WaitCallerFailure nvarchar(2048)=CONCAT(N'Wait caller mode=',@WaitCallerMode,N' options=',@@OPTIONS,N' expected=',@WaitCallerOptions,N' tran=',@@TRANCOUNT,N' state=',@WaitCallerAfterXactState,N' before=',@WaitCallerXactState);
  THROW 53770,@WaitCallerFailure,1;
 END;
 IF @WaitCallerMode=0
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM #WaitCallerSentinel WHERE [Value]=1) THROW 53770,N'Wait helper erased caller sentinel.',1;
  ROLLBACK TRANSACTION;
 END
 ELSE SET IMPLICIT_TRANSACTIONS OFF;
 SET @WaitCallerMode+=1;
END;
IF (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun])<>@WaitBeforeRuns
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun])<>@WaitBeforePurges
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='WAIT_STATS' AND [IsEnabled]=0)
 THROW 53770,N'Rejected Wait calls changed target data.',1;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalConfigureSnapshotPolicy]
 @CollectionIntervalSeconds=1,@MaxRows=10,@PayloadEnabled=0,@RawRetentionDays=14,@PayloadRetentionDays=7,
 @RollupRetentionDays=180,@SoftBudgetMB=10240,@PurgeIntervalMinutes=60,@PurgeBatchRows=1000,
 @BudgetAction='PURGE_EXPIRED_THEN_STOP',@StatusCodeOut=@WaitBackendStatus OUTPUT,@ErrorNumberOut=@WaitBackendError OUTPUT,
 @ErrorMessageOut=@WaitBackendMessage OUTPUT,@CollectorCode='WAIT_STATS',@CollectorEnabled=1,@UpdateSharedPolicy=0,
 @ExpectedTargetDatabaseId=@WaitBackendDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@WaitBackendCreated;
IF COALESCE(@WaitBackendStatus,'')<>'AVAILABLE' THROW 53770,N'Owned Wait fixture configuration failed.',1;
SELECT @WaitSharedAfter=(SELECT * FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy] ORDER BY [RetentionPolicyCode] FOR JSON PATH,INCLUDE_NULL_VALUES),
 @WaitPcAfter=(SELECT * FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='PERFORMANCE_COUNTERS' FOR JSON PATH,INCLUDE_NULL_VALUES);
IF CONVERT(varbinary(max),@WaitSharedBefore)<>CONVERT(varbinary(max),@WaitSharedAfter) OR CONVERT(varbinary(max),@WaitPcBefore)<>CONVERT(varbinary(max),@WaitPcAfter) THROW 53770,N'Collector-only configuration changed shared policies.',1;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='WAIT_STATS' AND [RetentionPolicyCode]='EXAMPLE_WAIT_CUSTOM') THROW 53770,N'Collector-only configuration lost its custom retention binding.',1;

EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":10,"WaitTimeMs":100,"MaxWaitTimeMs":50,"SignalWaitTimeMs":10}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'FIRST_OBSERVATION',@WantEpoch=N'NEW_FIRST',@WantSamples=6,@Case=N'first',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
SET @WaitBackendPreviousEpoch=@WaitBackendEpoch;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":20,"WaitTimeMs":200,"MaxWaitTimeMs":50,"SignalWaitTimeMs":20}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=9,@Case=N'monotonic',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
IF @WaitBackendEpoch<>@WaitBackendPreviousEpoch THROW 53770,N'Monotonic epoch changed.',1;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":30,"WaitTimeMs":300,"MaxWaitTimeMs":25,"SignalWaitTimeMs":30}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'COUNTER_DECREASE',@WantEpoch=N'NEW_COUNTER_DECREASE',@WantSamples=6,@Case=N'max decrease',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
IF @WaitBackendEpoch=@WaitBackendPreviousEpoch THROW 53770,N'Counter decrease retained the old epoch.',1;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":40,"WaitTimeMs":400,"MaxWaitTimeMs":25,"SignalWaitTimeMs":40}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=9,@Case=N'post decrease',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":50,"WaitTimeMs":500,"MaxWaitTimeMs":25,"SignalWaitTimeMs":50},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=14,@Case=N'new type',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":2,"WaitTimeMs":20,"MaxWaitTimeMs":10,"SignalWaitTimeMs":2}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'WAIT_TYPE_MISSING',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=6,@Case=N'missing type',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":3,"WaitTimeMs":30,"MaxWaitTimeMs":10,"SignalWaitTimeMs":3}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=9,@Case=N'resume after missing',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1 WHERE [CollectorCode]='WAIT_STATS';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":4,"WaitTimeMs":40,"MaxWaitTimeMs":10,"SignalWaitTimeMs":4}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'WRITE_LIMITED',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=6,@Case=N'write cap',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=10 WHERE [CollectorCode]='WAIT_STATS';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":2,"WaitTimeMs":20,"MaxWaitTimeMs":50,"SignalWaitTimeMs":2},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":5,"WaitTimeMs":50,"MaxWaitTimeMs":10,"SignalWaitTimeMs":5}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_CAPTURE_PARTIAL',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'after capped predecessor',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":3,"WaitTimeMs":30,"MaxWaitTimeMs":50,"SignalWaitTimeMs":3},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":6,"WaitTimeMs":60,"MaxWaitTimeMs":10,"SignalWaitTimeMs":6}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'full resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[]',@Engine=@WaitBackendEngine,@Mutation=N'EMPTY',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'SOURCE_EMPTY_UNPROVEN',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=1,@Case=N'empty complete',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":4,"WaitTimeMs":40,"MaxWaitTimeMs":50,"SignalWaitTimeMs":4},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":7,"WaitTimeMs":70,"MaxWaitTimeMs":10,"SignalWaitTimeMs":7}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_CAPTURE_PARTIAL',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'after empty',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":5,"WaitTimeMs":50,"MaxWaitTimeMs":50,"SignalWaitTimeMs":5},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":8,"WaitTimeMs":80,"MaxWaitTimeMs":10,"SignalWaitTimeMs":8}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'after empty resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [s] SET [StringValue]=JSON_MODIFY([s].[StringValue],N'$.schemaVersion',2) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@WaitBackendRun AND [d].[MetricCode]='WAIT_CAPTURE_CONTEXT';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":6,"WaitTimeMs":60,"MaxWaitTimeMs":50,"SignalWaitTimeMs":6},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":9,"WaitTimeMs":90,"MaxWaitTimeMs":10,"SignalWaitTimeMs":9}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_CONTEXT_INVALID',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'unknown context',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
IF COALESCE(JSON_VALUE(@WaitBackendContext,N'$.comparison.previousContextVersion'),N'')<>N'2' THROW 53770,N'Unknown context version was hidden.',1;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":7,"WaitTimeMs":70,"MaxWaitTimeMs":50,"SignalWaitTimeMs":7},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":10,"WaitTimeMs":100,"MaxWaitTimeMs":10,"SignalWaitTimeMs":10}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'context resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
DELETE [s] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope] AS [p] ON [p].[ScopeId]=[s].[ScopeId] WHERE [s].[CaptureRunId]=@WaitBackendRun AND [d].[MetricCode]='WAIT_TIME_MS' AND JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType')=N'EXAMPLE_WAIT_A';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":8,"WaitTimeMs":80,"MaxWaitTimeMs":50,"SignalWaitTimeMs":8},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":11,"WaitTimeMs":110,"MaxWaitTimeMs":10,"SignalWaitTimeMs":11}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_RAW_INCOMPLETE',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'missing raw',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":9,"WaitTimeMs":90,"MaxWaitTimeMs":50,"SignalWaitTimeMs":9},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":12,"WaitTimeMs":120,"MaxWaitTimeMs":10,"SignalWaitTimeMs":12}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'raw resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[]',@Engine=@WaitBackendEngine,@Mutation=N'SOURCE_DENIED',@ForcePreviousTime=0,@WantOuter=N'DENIED_PERMISSION',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'source denied',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":10,"WaitTimeMs":100,"MaxWaitTimeMs":50,"SignalWaitTimeMs":10},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":13,"WaitTimeMs":130,"MaxWaitTimeMs":10,"SignalWaitTimeMs":13}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_CAPTURE_PARTIAL',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'after denied',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":11,"WaitTimeMs":110,"MaxWaitTimeMs":50,"SignalWaitTimeMs":11},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":14,"WaitTimeMs":140,"MaxWaitTimeMs":10,"SignalWaitTimeMs":14}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'denied resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'COUNTER_STRING',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad COUNTER_STRING',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'COUNTER_NEGATIVE',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad COUNTER_NEGATIVE',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'COUNTER_FRACTION',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad COUNTER_FRACTION',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'COUNT_MISMATCH',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad COUNT_MISMATCH',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'COUNT_LEADING_ZERO',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad COUNT_LEADING_ZERO',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'EXTRA_MEMBER',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad EXTRA_MEMBER',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'DUPLICATE_MEMBER',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad DUPLICATE_MEMBER',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'CASE_MEMBER',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad CASE_MEMBER',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'ENGINE_NULL',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad ENGINE_NULL',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'BAD_TIME',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad BAD_TIME',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'BIGINT_OVERFLOW',@ForcePreviousTime=0,@WantOuter=N'ERROR_HANDLED',@WantCompare=N'',@WantEpoch=N'',@WantSamples=0,@Case=N'bad BIGINT_OVERFLOW',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":12,"WaitTimeMs":120,"MaxWaitTimeMs":50,"SignalWaitTimeMs":12},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":15,"WaitTimeMs":150,"MaxWaitTimeMs":10,"SignalWaitTimeMs":15}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'PREVIOUS_CAPTURE_PARTIAL',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'after malformed source',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":13,"WaitTimeMs":130,"MaxWaitTimeMs":50,"SignalWaitTimeMs":13},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":16,"WaitTimeMs":160,"MaxWaitTimeMs":10,"SignalWaitTimeMs":16}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'malformed resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":14,"WaitTimeMs":140,"MaxWaitTimeMs":50,"SignalWaitTimeMs":14},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":17,"WaitTimeMs":170,"MaxWaitTimeMs":10,"SignalWaitTimeMs":17}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=1,@WantOuter=N'PARTIAL',@WantCompare=N'INTERVAL_NOT_POSITIVE',@WantEpoch=N'NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'same interval',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":15,"WaitTimeMs":150,"MaxWaitTimeMs":50,"SignalWaitTimeMs":15},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":18,"WaitTimeMs":180,"MaxWaitTimeMs":10,"SignalWaitTimeMs":18}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'interval resume',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
SET @WaitBackendEngine=N'{"serverName":"ExampleOtherSqlServer","sqlServerStartTimeLocal":"2000-01-01T00:00:00.000","sqlServerStartTimeMsTicks":"1"}';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":50,"SignalWaitTimeMs":1},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'ENGINE_CONTEXT_CHANGED',@WantEpoch=N'NEW_ENGINE_CONTEXT',@WantSamples=11,@Case=N'engine change',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":2,"WaitTimeMs":20,"MaxWaitTimeMs":50,"SignalWaitTimeMs":2},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":2,"WaitTimeMs":20,"MaxWaitTimeMs":10,"SignalWaitTimeMs":2}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch=N'RETAIN_CONTEXT',@WantSamples=17,@Case=N'other engine monotonic',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1 WHERE [CollectorCode]='WAIT_STATS';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":3,"WaitTimeMs":30,"MaxWaitTimeMs":50,"SignalWaitTimeMs":3},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1,"WaitTimeMs":10,"MaxWaitTimeMs":10,"SignalWaitTimeMs":1}]',@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter=N'PARTIAL',@WantCompare=N'WRITE_LIMITED',@WantEpoch=N'NEW_COUNTER_DECREASE',@WantSamples=6,@Case=N'cap and global decrease',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1000 WHERE [CollectorCode]='WAIT_STATS';
DECLARE @WaitFuzzRows nvarchar(max)=N'[{"WaitType":"EXAMPLE_WAIT_A","WaitingTasksCount":1000,"WaitTimeMs":1000,"MaxWaitTimeMs":500,"SignalWaitTimeMs":1000},{"WaitType":"EXAMPLE_WAIT_B","WaitingTasksCount":1000,"WaitTimeMs":1000,"MaxWaitTimeMs":500,"SignalWaitTimeMs":1000}]';
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=@WaitFuzzRows,@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_PARTIAL',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'fuzz baseline after cap',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
DECLARE @WaitContextFuzz TABLE([CaseId] int PRIMARY KEY,[Label] nvarchar(80),[Mutation] nvarchar(max));
INSERT @WaitContextFuzz VALUES
 (1,N'string version',N'JSON_MODIFY(@Ctx,N''$.schemaVersion'',N''1'')'),
 (2,N'zero run',N'JSON_MODIFY(@Ctx,N''$.captureRunId'',N''0'')'),
 (3,N'leading zero count',N'JSON_MODIFY(@Ctx,N''$.capture.nativeWaitTypeCount'',N''02'')'),
 (4,N'overflow count',N'JSON_MODIFY(@Ctx,N''$.capture.rawMetricSampleCount'',N''9223372036854775808'')'),
 (5,N'number count',N'JSON_MODIFY(@Ctx,N''$.capture.writtenTypeCount'',2)'),
 (6,N'unknown epoch',N'JSON_MODIFY(@Ctx,N''$.epochDecision'',N''UNKNOWN'')'),
 (7,N'bad guid',N'JSON_MODIFY(@Ctx,N''$.resetEpochId'',N''not-a-guid'')'),
 (8,N'null guid',N'JSON_MODIFY(@Ctx,N''strict $.resetEpochId'',NULL)'),
 (9,N'wrong scope',N'JSON_MODIFY(@Ctx,N''$.serverScopeId'',N''9223372036854775807'')'),
 (10,N'boolean type',N'JSON_MODIFY(@Ctx,N''$.capture.sourceComplete'',N''true'')'),
 (11,N'engine ticks type',N'JSON_MODIFY(@Ctx,N''$.engine.sqlServerStartTimeMsTicks'',1)'),
 (12,N'missing window',N'JSON_MODIFY(@Ctx,N''$.window'',NULL)'),
 (13,N'extra member',N'JSON_MODIFY(@Ctx,N''$.extra'',1)'),
 (14,N'duplicate member',N'STUFF(@Ctx,2,0,N''"schemaVersion":1,'')'),
 (15,N'case member',N'REPLACE(@Ctx,N''"schemaVersion"'',N''"SchemaVersion"'')'),
 (16,N'raw hash type',N'JSON_MODIFY(@Ctx,N''$.capture.rawProjectionSha256'',1)'),
 (17,N'bad sample count',N'JSON_MODIFY(@Ctx,N''$.capture.rawMetricSampleCount'',N''0'')'),
 (18,N'bad interval',N'JSON_MODIFY(@Ctx,N''$.window.measurementEndUtc'',N''1900-01-01T00:00:00.000Z'')'),
 (19,N'unknown comparison',N'JSON_MODIFY(@Ctx,N''$.comparison.status'',N''UNKNOWN'')');
DECLARE @WaitFuzzCase int=1,@WaitFuzzLabel nvarchar(80),@WaitFuzzMutation nvarchar(max),@WaitFuzzSql nvarchar(max),@WaitFuzzBadContext nvarchar(4000);
WHILE @WaitFuzzCase<=19
BEGIN
 SELECT @WaitFuzzLabel=[Label],@WaitFuzzMutation=[Mutation] FROM @WaitContextFuzz WHERE [CaseId]=@WaitFuzzCase;
 SET @WaitFuzzSql=N'SET @Bad='+@WaitFuzzMutation+N';';
 EXEC sys.sp_executesql @WaitFuzzSql,N'@Ctx nvarchar(4000),@Bad nvarchar(4000) OUTPUT',@Ctx=@WaitBackendContext,@Bad=@WaitFuzzBadContext OUTPUT;
 UPDATE [s] SET [StringValue]=@WaitFuzzBadContext FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@WaitBackendRun AND [d].[MetricCode]='WAIT_CAPTURE_CONTEXT';
 IF @@ROWCOUNT<>1 THROW 53770,N'Context mutation did not affect exactly one owned context.',1;
 EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=@WaitFuzzRows,@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter='PARTIAL',@WantCompare='PREVIOUS_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=11,@Case=@WaitFuzzLabel,@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
 EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=@WaitFuzzRows,@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_CONTEXT',@WantSamples=17,@Case=N'valid successor after context fuzz',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
 SET @WaitFuzzCase+=1;
END;
-- A changed numeric sample with unchanged row counts still breaks its raw hash.
UPDATE [s] SET [BigintValue]=[BigintValue]+1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@WaitBackendRun AND [d].[MetricCode]='WAIT_TIME_MS';
IF @@ROWCOUNT<>2 THROW 53770,N'Raw hash mutation did not affect the owned pair.',1;
EXEC sys.sp_executesql @WaitBackendSql,@WaitBackendParams,@Rows=@WaitFuzzRows,@Engine=@WaitBackendEngine,@Mutation=N'',@ForcePreviousTime=0,@WantOuter='PARTIAL',@WantCompare='PREVIOUS_RAW_INCOMPLETE',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=11,@Case=N'raw value tamper',@RunOut=@WaitBackendRun OUTPUT,@ContextOut=@WaitBackendContext OUTPUT,@EpochOut=@WaitBackendEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1000,[IsEnabled]=0,[RetentionPolicyCode]='DEFAULT' WHERE [CollectorCode]='WAIT_STATS';
DELETE [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy] WHERE [RetentionPolicyCode]='EXAMPLE_WAIT_CUSTOM';
PRINT N'SC023_WAIT_TARGET_SYNTHETIC_CONTRACT PASS';
GO
