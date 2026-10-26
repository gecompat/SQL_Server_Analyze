/*
Datei        : 227_SnapshotFileIO_Target_Runtime_Contract.sql
Zweck        : Prüft das interne Target mit synthetischen Quellen und unabhängigen Rohwertorakeln.
Artefakt-UID : urn:uuid:01a1771a-b230-7ca4-a076-35e23b07f85f
Registrierung: DEFERRED; keine finale lesbare Testkennung vergeben.
Grenze       : Dieser Test qualifiziert keinen nativen VFS-Collector.
*/
GO
USE [SQLServerAnalyzeTest];
GO
IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CollectorCode]='FILE_IO')
 THROW 53790,N'Unexpected file-I/O history before the owned synthetic fixture.',1;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy]
 WHERE [CollectorCode]='FILE_IO' AND [IsEnabled]=0 AND [CollectionIntervalSeconds]=30 AND [MaxRows]=1000 AND [PayloadEnabled]=0)
 THROW 53790,N'File-I/O defaults must be installed disabled.',1;
DECLARE @FileIOProbeRun bigint,@FileIOProbeStatus varchar(40),@FileIOProbeBudget bit,@FileIOProbeError int,@FileIOProbeMessage nvarchar(2048),@FileIOProbeVersion int,
 @FileIOPurgeBefore bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun]),@FileIOProbeFailure bit=0;
SET IMPLICIT_TRANSACTIONS ON;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData] @MaxBatches=1,@Force=0,@ContractOnly=1,
 @PurgeRunIdOut=@FileIOProbeRun OUTPUT,@StatusCodeOut=@FileIOProbeStatus OUTPUT,@BudgetExceededOut=@FileIOProbeBudget OUTPUT,
 @ErrorNumberOut=@FileIOProbeError OUTPUT,@ErrorMessageOut=@FileIOProbeMessage OUTPUT,@RetentionContractVersionOut=@FileIOProbeVersion OUTPUT;
IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=0 OR COALESCE(@FileIOProbeStatus,'')<>'INVALID_PARAMETER' OR COALESCE(@FileIOProbeError,0)<>51011
 SET @FileIOProbeFailure=1;
IF @@TRANCOUNT<>0 ROLLBACK TRANSACTION;
SET IMPLICIT_TRANSACTIONS OFF;
IF @FileIOProbeFailure=1 OR @FileIOProbeRun IS NOT NULL OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun])<>@FileIOPurgeBefore
 THROW 53790,N'Unsafe retention probe must preserve caller options, transaction count and package data.',1;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [IsEnabled]=1 WHERE [CollectorCode]='FILE_IO';
DECLARE @FileIOCaseSql nvarchar(max)=N'
DECLARE @Db int=DB_ID(N''SQLServerAnalyzeSnapshotTest''),@Created datetime,@Status varchar(40),@Message nvarchar(2048),@Error int,@Partial bit,
 @Run bigint,@Collect bit,@Start datetime2(3),@End datetime2(3),@Source nvarchar(max),@Framework nvarchar(max),@Engine nvarchar(max),
 @Databases nvarchar(max),@Files nvarchar(max),@Issues nvarchar(max)=N''[]'',@Metadata nvarchar(max),@Selection nvarchar(max),@Ctx nvarchar(max),
 @SourceDb int=DB_ID(N''SQLServerAnalyzeSnapshotTest''),@SourceCreated datetime,@Name sysname=N''SQLServerAnalyzeSnapshotTest'',@Rows bigint,
 @FrameworkName sysname=N''SQLServerAnalyzeTest'',@FrameworkDb int=DB_ID(N''SQLServerAnalyzeTest''),@FrameworkCreated datetime;
SELECT @Created=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@Db;
SELECT @SourceCreated=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@SourceDb;
SELECT @FrameworkCreated=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@FrameworkDb;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@FrameworkName,@SchedulerType=''MANUAL'',@RunEvenIfNotDue=1,@CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,@CollectorCode=''FILE_IO'',@ExpectedTargetDatabaseId=@Db,
 @ExpectedTargetDatabaseName=N''SQLServerAnalyzeSnapshotTest'',@ExpectedTargetCreateDate=@Created;
IF COALESCE(@Collect,0)<>1 OR @Run IS NULL THROW 53790,N''File-I/O fixture cannot prepare a run.'',1;
SELECT @Framework=(SELECT @FrameworkDb AS [databaseId],@FrameworkName AS [databaseName],
 CONVERT(nvarchar(19),@FrameworkCreated,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@FrameworkCreated)),3) AS [databaseCreateDateNative]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
SELECT @Databases=(SELECT @SourceDb AS [DatabaseId],@Name AS [DatabaseName],
 CONVERT(nvarchar(19),@SourceCreated,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@SourceCreated)),3) AS [DatabaseCreateDateNative]
 FOR JSON PATH,INCLUDE_NULL_VALUES);
SELECT @Selection=(SELECT CONVERT(nvarchar(max),NULL) AS [requestedDatabaseNames],CONVERT(nvarchar(4000),NULL) AS [requestedDatabaseNamePattern],
 CONVERT(bit,0) AS [systemDatabasesIncluded],N''1'' AS [selectedDatabaseCount],
 LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@Databases)),2)) AS [selectionSha256]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
SET @Databases=JSON_MODIFY(@Databases,N''$[0].MetadataStatusCode'',N''AVAILABLE'');
SELECT @Engine=(SELECT N''ExampleFileIOEngine'' AS [serverName],N''2026-01-01T00:00:00.000'' AS [sqlServerStartTimeLocal],N''1'' AS [sqlServerStartTimeMsTicks]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
SELECT @Metadata=(SELECT @SourceDb AS [DatabaseId],7 AS [FileId],@Guid AS [FileGuid],N''0'' AS [CreateLsn],0 AS [FileType],0 AS [FileState],
 @LogicalName AS [LogicalName] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
SELECT @Files=(SELECT @SourceDb AS [DatabaseId],7 AS [FileId],@SampleMs AS [SampleMs],@Counter AS [Reads],@Counter+1 AS [ReadBytes],@Counter+2 AS [ReadStallMs],
 @Counter+3 AS [Writes],@Counter+4 AS [WriteBytes],@Counter+5 AS [WriteStallMs],@Gauge AS [SizeOnDiskBytes],@Handle AS [FileHandle],
 JSON_QUERY(@Metadata) AS [MetadataBefore],JSON_QUERY(@Metadata) AS [MetadataAfter] FOR JSON PATH,INCLUDE_NULL_VALUES);
IF @Mutation=N''TWO''
BEGIN
 DECLARE @SecondFile nvarchar(max)=JSON_QUERY(@Files,N''$[0]'');
 SET @SecondFile=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@SecondFile,N''$.FileId'',8),N''$.MetadataBefore.FileId'',8),N''$.MetadataAfter.FileId'',8);
 SET @Files=N''[''+JSON_QUERY(@Files,N''$[0]'')+N'',''+@SecondFile+N'']'';
END;
IF @Mutation=N''OFFLINE'' SET @Files=JSON_MODIFY(JSON_MODIFY(@Files,N''$[0].MetadataBefore.FileState'',4),N''$[0].MetadataAfter.FileState'',4);
IF @Mutation=N''UNSUPPORTED'' SET @Files=JSON_MODIFY(JSON_MODIFY(@Files,N''$[0].MetadataBefore.FileType'',2),N''$[0].MetadataAfter.FileType'',2);
IF @Mutation IN(N''EMPTY'',N''DENIED'') SET @Files=N''[]'';
IF @Mutation=N''EMPTY''
BEGIN
 SET @Databases=N''[]'';
 SET @Selection=JSON_MODIFY(JSON_MODIFY(@Selection,N''$.selectedDatabaseCount'',N''0''),N''$.selectionSha256'',
  LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),N''[]'')),2)));
END;
IF @Mutation IN(N''OFFLINE'',N''UNSUPPORTED'')
 SELECT @Issues=(SELECT N''FILE'' AS [ScopeType],N''sys.database_files'' AS [SourceName],@SourceDb AS [DatabaseId],7 AS [FileId],
  @Name AS [DatabaseName],CASE WHEN @Mutation=N''OFFLINE'' THEN N''FILE_NOT_ONLINE'' ELSE N''UNSUPPORTED_FILE_TYPE'' END AS [StatusCode],
  CONVERT(int,NULL) AS [ErrorNumber],N''Example file excluded by scope.'' AS [ErrorMessage],REPLICATE(N''E'',1000) AS [EvidenceLimit]
  FOR JSON PATH,INCLUDE_NULL_VALUES);
IF @Mutation=N''DENIED''
 SELECT @Issues=(SELECT N''SOURCE'' AS [ScopeType],N''sys.dm_io_virtual_file_stats'' AS [SourceName],CONVERT(int,NULL) AS [DatabaseId],
  CONVERT(int,NULL) AS [FileId],CONVERT(nvarchar(128),NULL) AS [DatabaseName],N''DENIED_PERMISSION'' AS [StatusCode],229 AS [ErrorNumber],
  N''Example native read denied.'' AS [ErrorMessage],REPLICATE(N''E'',1000) AS [EvidenceLimit] FOR JSON PATH,INCLUDE_NULL_VALUES);
IF @Mutation=N''PARTIAL''
 SELECT @Issues=(SELECT N''SELECTION'' AS [ScopeType],N''DATABASE_SELECTION'' AS [SourceName],CONVERT(int,NULL) AS [DatabaseId],
  CONVERT(int,NULL) AS [FileId],REPLICATE(N''"'',128) AS [DatabaseName],N''SELECTION_UNRESOLVED'' AS [StatusCode],CONVERT(int,NULL) AS [ErrorNumber],
  N''Example selection unresolved.'' AS [ErrorMessage],REPLICATE(N''E'',1000) AS [EvidenceLimit] FOR JSON PATH,INCLUDE_NULL_VALUES);
SELECT @Start=SYSUTCDATETIME();
WAITFOR DELAY ''00:00:00.020'';
SET @End=SYSUTCDATETIME();
IF @Mutation=N''NONPOSITIVE''
BEGIN
 SELECT TOP(1) @Start=CONVERT(datetime2(3),LEFT(JSON_VALUE([s].[StringValue],N''$.measurementEndUtc''),23),126)
 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m]
 ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [m].[MetricCode]=''IO_FILE_CONTEXT'' AND [CaptureRunId]<@Run ORDER BY [CaptureRunId] DESC;
 UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] SET [StartedAtUtc]=@Start WHERE [CaptureRunId]=@Run;
END;
SELECT @Rows=COUNT_BIG(*) FROM OPENJSON(@Files);
SELECT @Source=(SELECT JSON_QUERY((SELECT 1 AS [schemaVersion],N''SnapshotFileIO'' AS [resultName],
 CASE WHEN @Mutation IN(N''EMPTY'',N''OFFLINE'',N''UNSUPPORTED'') THEN N''EMPTY_UNPROVEN'' WHEN @Mutation=N''DENIED'' THEN N''DENIED_PERMISSION'' WHEN @Mutation=N''PARTIAL'' THEN N''PARTIAL'' ELSE N''AVAILABLE'' END AS [statusCode],
 CONVERT(bit,CASE WHEN @Mutation IN(N''EMPTY'',N''OFFLINE'',N''UNSUPPORTED'',N''DENIED'',N''PARTIAL'') THEN 1 ELSE 0 END) AS [isPartial],
 CONVERT(bit,CASE WHEN @Mutation IN(N''DENIED'',N''PARTIAL'') THEN 0 ELSE 1 END) AS [sourceComplete],
 CONVERT(int,CASE WHEN @Mutation=N''DENIED'' THEN 229 END) AS [errorNumber],
 CONVERT(nvarchar(2048),CASE WHEN @Mutation=N''DENIED'' THEN N''Example native read denied.'' WHEN @Mutation=N''PARTIAL'' THEN N''Example selection unresolved.'' WHEN @Mutation IN(N''OFFLINE'',N''UNSUPPORTED'') THEN N''Example file excluded by scope.'' END) AS [errorMessage],
 CONVERT(nvarchar(19),@Start,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@Start)),3)+N''Z'' AS [measurementStartUtc],
 CONVERT(nvarchar(19),@End,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@End)),3)+N''Z'' AS [measurementEndUtc],
 CASE WHEN @Mutation NOT IN(N''EMPTY'',N''DENIED'') THEN CONVERT(nvarchar(19),@Start,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@Start)),3)+N''Z'' END AS [nativeReadStartUtc],
 CASE WHEN @Mutation NOT IN(N''EMPTY'',N''DENIED'') THEN CONVERT(nvarchar(19),@End,126)+N''.''+RIGHT(N''00''+CONVERT(nvarchar(3),DATEPART(millisecond,@End)),3)+N''Z'' END AS [nativeReadEndUtc],
 CASE WHEN @Mutation=N''EMPTY'' THEN N''NOT_STARTED'' WHEN @Mutation=N''DENIED'' THEN N''FAILED'' ELSE N''SUCCEEDED'' END AS [nativeReadState],
 CASE WHEN @Mutation=N''DENIED'' THEN NULL ELSE CONVERT(varchar(20),@Rows) END AS [selectedNativeRows],
 JSON_QUERY(@Framework) AS [framework],JSON_QUERY(CASE WHEN @Mutation=N''DENIED'' THEN NULL ELSE @Engine END) AS [engine],JSON_QUERY(@Selection) AS [selection]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [meta],JSON_QUERY(@Databases) AS [databases],JSON_QUERY(@Files) AS [files],JSON_QUERY(@Issues) AS [issues]
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
IF @Mutation=N''COUNTER_STRING'' SET @Source=JSON_MODIFY(@Source,N''$.files[0].Reads'',N''1'');
IF @Mutation=N''COUNTER_NEGATIVE'' SET @Source=JSON_MODIFY(@Source,N''$.files[0].Reads'',-1);
IF @Mutation=N''COUNTER_FRACTION'' SET @Source=JSON_MODIFY(@Source,N''$.files[0].Reads'',CONVERT(decimal(10,1),1.5));
IF @Mutation=N''COUNT_MISMATCH'' SET @Source=JSON_MODIFY(@Source,N''$.meta.selectedNativeRows'',N''999'');
IF @Mutation=N''COUNT_LEADING_ZERO'' SET @Source=JSON_MODIFY(@Source,N''$.meta.selectedNativeRows'',N''01'');
IF @Mutation=N''EXTRA_MEMBER'' SET @Source=JSON_MODIFY(@Source,N''$.meta.extra'',1);
IF @Mutation=N''DUPLICATE_MEMBER'' SET @Source=STUFF(@Source,2,0,N''"meta":{},'');
IF @Mutation=N''CASE_MEMBER'' SET @Source=REPLACE(@Source,N''"Reads":'',N''"reads":'');
IF @Mutation=N''ENGINE_NULL'' SET @Source=JSON_MODIFY(@Source,N''$.meta.engine'',NULL);
IF @Mutation=N''BAD_TIME'' SET @Source=JSON_MODIFY(@Source,N''$.meta.measurementEndUtc'',N''2026-01-01T00:00:00Z'');
IF @Mutation=N''BIGINT_OVERFLOW'' SET @Source=REPLACE(@Source,N''"Reads":10'',N''"Reads":9223372036854775808'');
IF @Mutation=N''SELECTION_HASH'' SET @Source=JSON_MODIFY(@Source,N''$.meta.selection.selectionSha256'',REPLICATE(N''0'',64));
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalCompleteFileIOCycle]
 @CaptureRunId=@Run,@CollectorJson=@Source,@ExpectedTargetDatabaseId=@Db,@ExpectedTargetDatabaseName=N''SQLServerAnalyzeSnapshotTest'',
 @ExpectedTargetCreateDate=@Created,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF COALESCE(@Status,'''')<>@WantStatus OR COALESCE(@Partial,0)<>1
BEGIN
 DECLARE @Failure nvarchar(2048)=CONCAT(N''File-I/O case '',@Mutation,N'': '',@Status,N''/'',@Error,N''/'',@Message);
 THROW 53790,@Failure,1;
END;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND [EndedAtUtc] IS NOT NULL
 AND [StatusCode]=@WantStatus AND [MetricSampleCount]=@WantSamples AND [ResetEpochId] IS NULL AND [SqlServerStartTimeUtc] IS NULL)
BEGIN
 DECLARE @RunFailure nvarchar(2048)=(SELECT CONCAT(N''File-I/O run '',@Mutation,N'' counter '',@Counter,N'': samples '',[MetricSampleCount],N'' expected '',@WantSamples,N'' status '',[StatusCode],N'' epoch '',CONVERT(nvarchar(36),[ResetEpochId]),N'' ended '',[EndedAtUtc],N'' comparison '',
  (SELECT [s].[StringValue] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@Run AND [m].[MetricCode]=''IO_DELTA_STATUS''))
  FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run);
 THROW 53790,@RunFailure,1;
END;
SELECT @Ctx=[s].[StringValue] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [CaptureRunId]=@Run AND [m].[MetricCode]=''IO_FILE_CONTEXT'' AND JSON_VALUE([s].[StringValue],N''$.scopeId'') IN
 (SELECT CONVERT(varchar(20),[ScopeId]) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope] WHERE JSON_VALUE([ScopeIdentityJson],N''$.file.FileId'')=N''7'');
IF @WantCompare IS NOT NULL AND (COALESCE(JSON_VALUE(@Ctx,N''$.comparisonStatus''),N'''')<>@WantCompare
 OR COALESCE(JSON_VALUE(@Ctx,N''$.epochDecision''),N'''')<>@WantEpoch)
BEGIN
 DECLARE @ContextFailure nvarchar(2048)=CONCAT(N''File-I/O comparison '',@Mutation,N'': '',JSON_VALUE(@Ctx,N''$.comparisonStatus''),N''/'',JSON_VALUE(@Ctx,N''$.epochDecision''),N'' expected '',@WantCompare,N''/'',@WantEpoch);
 THROW 53790,@ContextFailure,1;
END;
IF @WantStatus=''PARTIAL'' AND @WantSamples>1
BEGIN
 IF (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
 CROSS APPLY(VALUES(''IO_READ_COUNT'',@Counter),(''IO_READ_BYTES'',@Counter+1),(''IO_READ_STALL_MS'',@Counter+2),
  (''IO_WRITE_COUNT'',@Counter+3),(''IO_WRITE_BYTES'',@Counter+4),(''IO_WRITE_STALL_MS'',@Counter+5),(''IO_SIZE_ON_DISK_BYTES'',@Gauge)) [v]([Code],[Value])
 WHERE [s].[CaptureRunId]=@Run AND [m].[MetricCode]=[v].[Code] AND [s].[BigintValue]=[v].[Value]
 AND [s].[ScopeId] IN(SELECT [ScopeId] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope] WHERE JSON_VALUE([ScopeIdentityJson],N''$.file.FileId'')=N''7''))<>7
 THROW 53790,N''File-I/O independent seven-value raw oracle failed.'',1;
 IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@Run AND [m].[MetricCode] LIKE ''%[_]DELTA[_]CANDIDATE''
  AND ([s].[BigintValue] IS NULL OR [s].[BigintValue]<0 OR [s].[QualityCode]<>''MONOTONIC_CONTINUITY_UNPROVEN'' OR [s].[IsPartial]<>1))
 THROW 53790,N''File-I/O candidates must retain their evidence limit.'',1;
END;
IF @Mutation IN(N''DENIED'',N''PARTIAL'',N''OFFLINE'',N''UNSUPPORTED'') AND
 ((SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run)<>3
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run AND DATALENGTH([EvidenceLimit])=2000)
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] [ctx] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] [src]
 ON TRY_CONVERT(bigint,JSON_VALUE(CASE WHEN ISJSON([ctx].[ErrorMessage])=1 THEN [ctx].[ErrorMessage] ELSE N''{}'' END,N''$.sourceModuleStatusId''))=[src].[ModuleStatusId]
 AND [ctx].[CaptureRunId]=[src].[CaptureRunId] WHERE [ctx].[CaptureRunId]=@Run AND [ctx].[ModuleName]=N''FileIOSourceIssueContext'' AND [ctx].[ErrorNumber] IS NULL))
 THROW 53790,N''Source issues must persist losslessly without payload.'',1;
SELECT @RunOut=@Run,@ContextOut=@Ctx,@EpochOut=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Ctx,N''$.resetEpochId''));';
DECLARE @FileIOParams nvarchar(max)=N'@Counter bigint,@Gauge bigint,@SampleMs bigint,@Guid nvarchar(36),@Handle varchar(18),@LogicalName nvarchar(128),@Mutation nvarchar(40),
 @WantStatus varchar(40),@WantCompare varchar(40),@WantEpoch varchar(40),@WantSamples bigint,@RunOut bigint OUTPUT,@ContextOut nvarchar(max) OUTPUT,@EpochOut uniqueidentifier OUTPUT';
DECLARE @FileIORun bigint,@FileIOContext nvarchar(max),@FileIOEpoch uniqueidentifier,@FileIOPreviousEpoch uniqueidentifier,
 @FileIOGuid nvarchar(36)=N'12345678-1234-1234-1234-123456789abc',@FileIOHandle varchar(18)='0x0000000000000000',@FileIOLongName nvarchar(128)=REPLICATE(N'"',128);
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='NO_PREVIOUS_CAPTURE',@WantEpoch='NEW_BASELINE',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
SET @FileIOPreviousEpoch=@FileIOEpoch;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=20,@Gauge=100,@SampleMs=200,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
IF @FileIOEpoch<>@FileIOPreviousEpoch THROW 53790,N'Comparable file must retain its observed epoch.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=30,@Gauge=0,@SampleMs=300,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=@FileIOLongName,@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=30,@Gauge=0,@SampleMs=300,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode] LIKE '%[_]DELTA[_]CANDIDATE' AND [s].[BigintValue]<>0) THROW 53790,N'Hidden-reset counterexample remains an unproven zero candidate.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=400,@Guid=@FileIOGuid,@Handle='0x0000000000000001',@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='FILE_HANDLE_CHANGED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=500,@Guid=N'12345678-1234-1234-1234-123456789abd',@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='OBSERVED_IDENTITY_CHANGED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=60,@Gauge=100,@SampleMs=600,@Guid=NULL,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='CURRENT_IDENTITY_INCOMPLETE',@WantEpoch='NEW_UNBOUND_OBSERVATION',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=70,@Gauge=100,@SampleMs=700,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=80,@Gauge=100,@SampleMs=650,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='UPTIME_DECREASED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=1,@Gauge=100,@SampleMs=800,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='COUNTER_DECREASED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=900,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'NONPOSITIVE',@WantStatus='PARTIAL',@WantCompare='NONPOSITIVE_INTERVAL',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=20,@Gauge=100,@SampleMs=1000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'PARTIAL',@WantStatus='PARTIAL',@WantCompare='SOURCE_PARTIAL',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=30,@Gauge=100,@SampleMs=1100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_SOURCE_PARTIAL',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=1200,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'DENIED',@WantStatus='DENIED_PERMISSION',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=1300,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=60,@Gauge=100,@SampleMs=1400,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'EMPTY',@WantStatus='PARTIAL',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=1,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=70,@Gauge=100,@SampleMs=1500,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='SELECTION_CHANGED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'COUNTER_STRING',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'COUNTER_NEGATIVE',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'COUNTER_FRACTION',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'COUNT_MISMATCH',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'COUNT_LEADING_ZERO',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'EXTRA_MEMBER',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'DUPLICATE_MEMBER',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'CASE_MEMBER',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'ENGINE_NULL',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'BAD_TIME',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'BIGINT_OVERFLOW',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=100,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'SELECTION_HASH',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=10,@Gauge=100,@SampleMs=1600,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [BigintValue]=[BigintValue]+1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_READ_COUNT';
IF @@ROWCOUNT<>1 THROW 53790,N'Raw mutation must affect exactly one owned sample.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=20,@Gauge=100,@SampleMs=1700,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_RAW_INCOMPLETE',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;

DECLARE @FileIOFuzz TABLE([Ordinal] int PRIMARY KEY,[Label] nvarchar(80),[Mutation] nvarchar(max));
INSERT @FileIOFuzz VALUES
 (1,N'native partition',N'JSON_MODIFY(@Ctx,N''$.capture.selectedNativeFileCount'',N''0'')'),
 (2,N'eligible partition',N'JSON_MODIFY(@Ctx,N''$.capture.eligibleFileCount'',N''0'')'),
 (3,N'invalid cap',N'JSON_MODIFY(@Ctx,N''$.capture.effectiveMaxRows'',N''0'')'),
 (4,N'wrong write limit',N'JSON_MODIFY(@Ctx,N''$.capture.writeLimited'',CONVERT(bit,1))'),
 (5,N'framework hash',N'JSON_MODIFY(@Ctx,N''$.framework.tupleSha256'',REPLICATE(N''0'',64))'),
 (6,N'engine hash',N'JSON_MODIFY(@Ctx,N''$.engine.tupleSha256'',REPLICATE(N''0'',64))'),
 (7,N'manifest hash',N'JSON_MODIFY(@Ctx,N''$.fileRawContextManifestSha256'',REPLICATE(N''0'',64))'),
 (8,N'raw count',N'JSON_MODIFY(@Ctx,N''$.samples.rawSampleCount'',N''0'')'),
 (9,N'native time missing',N'JSON_MODIFY(@Ctx,N''$.window.nativeReadEndUtc'',NULL)'),
 (10,N'extra member',N'JSON_MODIFY(@Ctx,N''$.unexpected'',1)'),
 (11,N'duplicate member',N'STUFF(@Ctx,2,0,N''"schemaVersion":1,'')'),
 (12,N'wrong case',N'REPLACE(@Ctx,N''"schemaVersion"'',N''"SchemaVersion"'')'),
 (13,N'invalid JSON',N'N''{''');
DECLARE @FileIOFuzzOrdinal int=1,@FileIOFuzzExpression nvarchar(max),@FileIOFuzzSql nvarchar(max),@FileIOBadContext nvarchar(max),@FileIOGlobalContext nvarchar(max);
WHILE @FileIOFuzzOrdinal<=13
BEGIN
 SELECT @FileIOFuzzExpression=[Mutation] FROM @FileIOFuzz WHERE [Ordinal]=@FileIOFuzzOrdinal;
 SELECT @FileIOGlobalContext=[s].[StringValue] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_CAPTURE_CONTEXT';
 SET @FileIOFuzzSql=N'SET @Bad='+@FileIOFuzzExpression+N';';
 EXEC sys.sp_executesql @FileIOFuzzSql,N'@Ctx nvarchar(max),@Bad nvarchar(max) OUTPUT',@Ctx=@FileIOGlobalContext,@Bad=@FileIOBadContext OUTPUT;
 UPDATE [s] SET [StringValue]=@FileIOBadContext FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_CAPTURE_CONTEXT';
 IF @@ROWCOUNT<>1 THROW 53790,N'Global context mutation must affect exactly one owned sample.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
 SET @FileIOFuzzOrdinal+=1;
END;
UPDATE [s] SET [StringValue]=N'UNKNOWN' FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_DELTA_STATUS';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [QualityCode]='UNKNOWN' FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_DELTA_STATUS';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [IsPartial]=0 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_DELTA_STATUS';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [CollectedAtUtc]=DATEADD(millisecond,-1,[s].[CollectedAtUtc]) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_DELTA_STATUS';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [QualityCode]='UNKNOWN' FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_FILE_CONTEXT';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [IsPartial]=0 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_FILE_CONTEXT';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [CollectedAtUtc]=DATEADD(millisecond,-1,[s].[CollectedAtUtc]) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_FILE_CONTEXT';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_CONTEXT_INVALID',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [s] SET [QualityCode]='UNKNOWN' FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s] JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_READ_COUNT';
IF @@ROWCOUNT<>1 THROW 53790,N'Metadata mutation must affect one owned row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_RAW_INCOMPLETE',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
SELECT @FileIOGlobalContext=[s].[StringValue] FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_CAPTURE_CONTEXT';
DECLARE @FileIOOldFramework nvarchar(max),@FileIOOldFrameworkHash varchar(64);
SELECT @FileIOOldFramework=(SELECT CONVERT(int,JSON_VALUE(@FileIOGlobalContext,'$.framework.databaseId')) AS [databaseId],N'SQLServerAnalyzeTest' AS [databaseName],
 N'2026-01-01T00:00:00.000' AS [databaseCreateDateNative] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
SET @FileIOOldFrameworkHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@FileIOOldFramework)),2));
SET @FileIOGlobalContext=JSON_MODIFY(JSON_MODIFY(@FileIOGlobalContext,'$.framework.databaseCreateDateNative',N'2026-01-01T00:00:00.000'),'$.framework.tupleSha256',@FileIOOldFrameworkHash);
UPDATE [s] SET [StringValue]=@FileIOGlobalContext FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [s]
JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] [m] ON [m].[MetricDefinitionId]=[s].[MetricDefinitionId]
WHERE [s].[CaptureRunId]=@FileIORun AND [m].[MetricCode]='IO_CAPTURE_CONTEXT';
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=40,@Gauge=100,@SampleMs=2000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='OBSERVED_IDENTITY_CHANGED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1 WHERE [CollectorCode]='FILE_IO';
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'TWO',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=2 WHERE [CollectorCode]='FILE_IO';
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'TWO',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=25,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [MaxRows]=1000 WHERE [CollectorCode]='FILE_IO';
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='MONOTONIC_CONTINUITY_UNPROVEN',@WantEpoch='RETAIN_OBSERVED_EPOCH',@WantSamples=16,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'OFFLINE',@WantStatus='PARTIAL',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=1,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_UNAVAILABLE',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'UNSUPPORTED',@WantStatus='PARTIAL',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=1,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_FILE_UNAVAILABLE',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
DECLARE @FileIOTriggerId int,@FileIOTriggerSql nvarchar(max)=N'CREATE TRIGGER [snapshot].[ExampleFileIORawWriteFault]
ON [snapshot].[MetricSample] AFTER INSERT AS
BEGIN
 SET NOCOUNT ON;
 UPDATE [s] SET [BigintValue]=[s].[BigintValue]+1 FROM [snapshot].[MetricSample] [s]
 JOIN [inserted] [i] ON [i].[MetricSampleId]=[s].[MetricSampleId]
 JOIN [snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [d].[MetricCode]=''IO_READ_COUNT'';
END;';
IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[sys].[triggers] WHERE [name]=N'ExampleFileIORawWriteFault')
 THROW 53790,N'Unexpected raw-write fault trigger before owned fixture.',1;
EXEC [SQLServerAnalyzeSnapshotTest].[sys].[sp_executesql] @FileIOTriggerSql;
SELECT @FileIOTriggerId=[object_id] FROM [SQLServerAnalyzeSnapshotTest].[sys].[triggers] WHERE [name]=N'ExampleFileIORawWriteFault';
BEGIN TRY
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
 IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[sys].[triggers] WHERE [object_id]=@FileIOTriggerId AND [name]=N'ExampleFileIORawWriteFault')
  THROW 53790,N'Owned raw-write fault identity changed.',1;
 EXEC [SQLServerAnalyzeSnapshotTest].[sys].[sp_executesql] N'DROP TRIGGER [snapshot].[ExampleFileIORawWriteFault];';
END TRY
BEGIN CATCH
 IF EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[sys].[triggers] WHERE [object_id]=@FileIOTriggerId AND [name]=N'ExampleFileIORawWriteFault')
  EXEC [SQLServerAnalyzeSnapshotTest].[sys].[sp_executesql] N'DROP TRIGGER [snapshot].[ExampleFileIORawWriteFault];';
 THROW;
END CATCH;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',@Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
DECLARE @FileIOBoundDb int=DB_ID(N'SQLServerAnalyzeSnapshotTest'),@FileIOBoundCreated datetime,@FileIOShouldCollect bit,
 @FileIORunCount bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]);
SELECT @FileIOBoundCreated=[create_date] FROM [master].[sys].[databases] WHERE [database_id]=@FileIOBoundDb;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle] @SourceDatabaseName=N'SQLServerAnalyzeTest',@SchedulerType='MANUAL',@RunEvenIfNotDue=0,
 @CaptureRunIdOut=@FileIOProbeRun OUTPUT,@ShouldCollectOut=@FileIOShouldCollect OUTPUT,@StatusCodeOut=@FileIOProbeStatus OUTPUT,@ErrorMessageOut=@FileIOProbeMessage OUTPUT,
 @CollectorCode='FILE_IO',@ExpectedTargetDatabaseId=@FileIOBoundDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@FileIOBoundCreated;
IF COALESCE(@FileIOProbeStatus,'')<>'SKIPPED_NOT_DUE' OR @FileIOProbeRun IS NOT NULL OR COALESCE(@FileIOShouldCollect,1)<>0
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun])<>@FileIORunCount
 THROW 53790,N'Not-due file-I/O must create no capture row.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',
 @Mutation=N'EXTRA_MEMBER',@WantStatus='ERROR_HANDLED',@WantCompare=NULL,@WantEpoch=NULL,@WantSamples=0,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
DECLARE @FileIOLatestFailure bigint=@FileIORun;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] SET [StartedAtUtc]=DATEADD(day,-31,SYSUTCDATETIME()),[EndedAtUtc]=DATEADD(day,-31,SYSUTCDATETIME())
 WHERE [CollectorCode]='FILE_IO' AND [EndedAtUtc] IS NOT NULL;
UPDATE [m] SET [CollectedAtUtc]=DATEADD(day,-31,SYSUTCDATETIME()) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] [m]
 JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] [r] ON [r].[CaptureRunId]=[m].[CaptureRunId] WHERE [r].[CollectorCode]='FILE_IO';
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData] @MaxBatches=1000,@Force=1,@PurgeRunIdOut=@FileIOProbeRun OUTPUT,
 @StatusCodeOut=@FileIOProbeStatus OUTPUT,@BudgetExceededOut=@FileIOProbeBudget OUTPUT,@ErrorNumberOut=@FileIOProbeError OUTPUT,@ErrorMessageOut=@FileIOProbeMessage OUTPUT,
 @ExpectedTargetDatabaseId=@FileIOBoundDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@FileIOBoundCreated;
IF COALESCE(@FileIOProbeStatus,'')<>'AVAILABLE' OR @FileIOProbeError IS NOT NULL
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CollectorCode]='FILE_IO')<>1
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@FileIOLatestFailure AND [StatusCode]='ERROR_HANDLED')
 OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@FileIOLatestFailure)
 OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@FileIOLatestFailure)
 THROW 53790,N'File-I/O retention must expire children and preserve the actual latest failure fence.',1;
EXEC sys.sp_executesql @FileIOCaseSql,@FileIOParams,@Counter=50,@Gauge=100,@SampleMs=3000,@Guid=@FileIOGuid,@Handle=@FileIOHandle,@LogicalName=N'ExampleLogicalFile',
 @Mutation=N'',@WantStatus='PARTIAL',@WantCompare='PREVIOUS_CAPTURE_FAILED',@WantEpoch='NEW_COMPARISON_BREAK',@WantSamples=10,@RunOut=@FileIORun OUTPUT,@ContextOut=@FileIOContext OUTPUT,@EpochOut=@FileIOEpoch OUTPUT;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] SET [IsEnabled]=0 WHERE [CollectorCode]='FILE_IO';
SET @FileIORunCount=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]);
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPrepareCollectionCycle] @SourceDatabaseName=N'SQLServerAnalyzeTest',@SchedulerType='MANUAL',@RunEvenIfNotDue=1,
 @CaptureRunIdOut=@FileIOProbeRun OUTPUT,@ShouldCollectOut=@FileIOShouldCollect OUTPUT,@StatusCodeOut=@FileIOProbeStatus OUTPUT,@ErrorMessageOut=@FileIOProbeMessage OUTPUT,
 @CollectorCode='FILE_IO',@ExpectedTargetDatabaseId=@FileIOBoundDb,@ExpectedTargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@ExpectedTargetCreateDate=@FileIOBoundCreated;
IF COALESCE(@FileIOProbeStatus,'')<>'DISABLED' OR @FileIOProbeRun IS NOT NULL OR COALESCE(@FileIOShouldCollect,1)<>0
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun])<>@FileIORunCount
 THROW 53790,N'Disabled file-I/O must create no capture row.',1;

PRINT N'SC023_FILE_IO_TARGET_SYNTHETIC_CONTRACT PASS';
GO
