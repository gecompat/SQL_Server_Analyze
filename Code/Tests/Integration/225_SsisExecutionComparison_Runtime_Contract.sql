USE [DeineDatenbank];
GO
SET NOCOUNT ON;
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
-- Synthetischer Empfängervertrag; die native SSISDB-Abnahme bleibt eigenständig.
DECLARE @Root nvarchar(max)=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@Model,'$.nodes',JSON_QUERY(N'[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticRoot","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticLoop","attributes":{"executableType":"STOCK:FORLOOP","isDisabled":false,"isEventHandler":false}},{"id":"exe2","kind":"EXECUTABLE","parentId":"exe1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe2","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe2","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}]')),'$.edges',JSON_QUERY(N'[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe2","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe2","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}]')),'$.diagnostics',JSON_QUERY(N'[]'));
DECLARE @Objects nvarchar(max)=(SELECT 'ssis-object-identities' contract,'1.2.0' version,'document-order-v1' identityProfile,JSON_VALUE(@Root,'$.source.packageSha256') packageSha256,JSON_QUERY(N'[{"nodeId":"pkg1","nodeKind":"PACKAGE","parentId":null,"dtsId":"11111111-1111-1111-1111-111111111111","packagePath":"\\Package","scopeKind":"PACKAGE","eventName":null,"callTarget":null,"steps":[],"profileStatus":"SUPPORTED"},{"nodeId":"exe1","nodeKind":"EXECUTABLE","parentId":"pkg1","dtsId":"22222222-2222-2222-2222-222222222222","packagePath":"\\Package\\SyntheticLoop","scopeKind":"LOOP","eventName":null,"callTarget":null,"steps":[{"text":"\\SyntheticLoop","counter":false}],"profileStatus":"SUPPORTED"},{"nodeId":"exe2","nodeKind":"EXECUTABLE","parentId":"exe1","dtsId":"33333333-3333-3333-3333-333333333333","packagePath":"\\Package\\SyntheticLoop\\SyntheticFlow","scopeKind":"EXECUTABLE","eventName":null,"callTarget":null,"steps":[{"text":"\\SyntheticLoop","counter":true},{"text":"\\SyntheticFlow","counter":false}],"profileStatus":"SUPPORTED"}]') objects FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
DECLARE @Pipeline nvarchar(max)=N'{"contract":"ssis-pipeline-identities","version":"1.0.0","identityProfile":"document-order-v1","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","pipelines":[{"nodeId":"exe2","profileStatus":"SUPPORTED","components":[{"nodeId":"cmp1","name":"SyntheticSource","nativeRefId":"Package\\SyntheticLoop\\SyntheticFlow\\SyntheticSource","profileStatus":"SUPPORTED"},{"nodeId":"cmp2","name":"SyntheticTarget","nativeRefId":"Package\\SyntheticLoop\\SyntheticFlow\\SyntheticTarget","profileStatus":"SUPPORTED"}],"paths":[{"edgeId":"edge1","fromPortId":"port1","toPortId":"port2","sourceComponentId":"cmp1","destinationComponentId":"cmp2","nativeRefId":"Package\\SyntheticLoop\\SyntheticFlow.Paths[SyntheticTransfer]","name":"SyntheticTransfer","identificationString":"Paths[SyntheticSource.SyntheticOutput]","profileStatus":"SUPPORTED"}]}]}',@Models nvarchar(max),@Capture nvarchar(max)=N'{"contract":"ssis-execution-scopes","version":"1.1.0","method":"SSISDB_CURRENT_PROJECT_PIPELINES_V1","modelSetSha256":"0000000000000000000000000000000000000000000000000000000000000000","archiveSha256":"8888888888888888888888888888888888888888888888888888888888888888","execution":{"executionId":"9007199254740993","projectId":"17","projectLsn":"91","catalogDatabaseGuid":"33333333-3333-3333-3333-333333333333","sourceBindingSha256":"4444444444444444444444444444444444444444444444444444444444444444","packageFileName":"SyntheticRoot.dtsx","loggingLevel":3,"executionStatus":7,"snapshotStartedUtc":"2026-01-01T00:00:00Z","snapshotCompletedUtc":"2026-01-01T00:00:01Z"},"observations":[{"statisticsId":"1","executionId":"9007199254740993","executableId":"51","executableGuid":"11111111-1111-1111-1111-111111111111","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package","executionPath":"\\SyntheticRoot","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z","durationMs":1000,"executionResult":0},{"statisticsId":"2","executionId":"9007199254740993","executableId":"52","executableGuid":"22222222-2222-2222-2222-222222222222","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package\\SyntheticLoop","executionPath":"\\SyntheticRoot\\SyntheticLoop","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z","durationMs":1000,"executionResult":0},{"statisticsId":"3","executionId":"9007199254740993","executableId":"53","executableGuid":"33333333-3333-3333-3333-333333333333","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package\\SyntheticLoop\\SyntheticFlow","executionPath":"\\SyntheticRoot\\SyntheticLoop[1]\\SyntheticFlow","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z","durationMs":1000,"executionResult":0},{"statisticsId":"4","executionId":"9007199254740993","executableId":"53","executableGuid":"33333333-3333-3333-3333-333333333333","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package\\SyntheticLoop\\SyntheticFlow","executionPath":"\\SyntheticRoot\\SyntheticLoop[2]\\SyntheticFlow","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z","durationMs":1000,"executionResult":0}],"events":[],"componentPhases":[{"phaseStatsId":"1","packageName":"SyntheticRoot.dtsx","taskName":"SyntheticFlow","componentName":"SyntheticSource","phaseName":"PrimeOutput","executionPath":"\\SyntheticRoot\\SyntheticLoop[1]\\SyntheticFlow","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z"},{"phaseStatsId":"2","packageName":"SyntheticRoot.dtsx","taskName":"SyntheticFlow","componentName":"SyntheticSource","phaseName":"PrimeOutput","executionPath":"\\SyntheticRoot\\SyntheticLoop[2]\\SyntheticFlow","startTime":"2026-01-01T00:00:00Z","endTime":"2026-01-01T00:00:01Z"}],"pathTransfers":[{"dataStatsId":"1","packageName":"SyntheticRoot.dtsx","taskName":"SyntheticFlow","pathIdentificationString":"Paths[SyntheticSource.SyntheticOutput]","pathName":"SyntheticTransfer","sourceComponentName":"SyntheticSource","destinationComponentName":"SyntheticTarget","executionPath":"\\SyntheticRoot\\SyntheticLoop[1]\\SyntheticFlow","rowsSent":3,"createdTime":"2026-01-01T00:00:00Z"},{"dataStatsId":"2","packageName":"SyntheticRoot.dtsx","taskName":"SyntheticFlow","pathIdentificationString":"Paths[SyntheticSource.SyntheticOutput]","pathName":"SyntheticTransfer","sourceComponentName":"SyntheticSource","destinationComponentName":"SyntheticTarget","executionPath":"\\SyntheticRoot\\SyntheticLoop[2]\\SyntheticFlow","rowsSent":7,"createdTime":"2026-01-01T00:00:00Z"}],"pipelineSources":[{"source":"componentPhases","status":"AVAILABLE","errorNumber":null},{"source":"pathTransfers","status":"AVAILABLE","errorNumber":null}]}';
SET @Models=(SELECT 'ssis-project-model-set' contract,'1.0.0' version,'p1' rootPackageKey,JSON_QUERY((SELECT 'p1' packageKey,'SyntheticRoot.dtsx' entryName,JSON_QUERY(@Root) model,JSON_QUERY(@Objects) identities,JSON_QUERY(@Pipeline) pipelineIdentities FOR JSON PATH)) packages FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);

-- Zwei unabhängig attestierte synthetische Captures mit verschiedenen nativen
-- IDs. Der gemeinsame Modellfixtureblock stammt weiterhin aus Toolbelt.
DECLARE @BId uniqueidentifier=NEWID(),@CId uniqueidentifier=NEWID(),@BName sysname,@CName sysname,
 @B nvarchar(max),@C nvarchar(max),@CM nvarchar(max),@Now datetime2(3)=SYSUTCDATETIME(),@Receipt nvarchar(3000),
 @CreatedB bit=0,@CreatedC bit=0,@Case int=0,@Json nvarchar(max),@Status varchar(40),@Reason nvarchar(2048),
 @Abs bigint,@Pct decimal(9,4),@Limit int,@Duration int,@RequestedCandidate bigint,@RequestedHandover uniqueidentifier,
 @Failure nvarchar(2048),@i int,@Path nvarchar(128),@Extra nvarchar(max),@OriginalLock int=@@LOCK_TIMEOUT,
 @MetricsCloneCreated bit=0,
 @OriginalX bit=CASE WHEN @@OPTIONS&16384=16384 THEN 1 ELSE 0 END;
SET @BName=N'SSIS_SCOPE_'+LOWER(CONVERT(nvarchar(36),@BId));SET @CName=N'SSIS_SCOPE_'+LOWER(CONVERT(nvarchar(36),@CId));
BEGIN TRY

 -- Der Regressionstest bindet die Kopie an das Rohmodul und ersetzt nur die bekannte Call-Stelle.
 DECLARE @MetricsCloneName sysname=N'InternalSsisExecutionMetrics_NullStatusRegression',
  @MetricsModule nvarchar(max),@MetricsModuleAfter nvarchar(max),@MetricsClone nvarchar(max),@MetricsReconstructed nvarchar(max),
  @MetricsOriginalPrefix nvarchar(max),@MetricsCloneDeclarationPrefix nvarchar(max),
  @MetricsSignature nvarchar(max)=N'@RunOrdinal int,',
  @MetricsInjectedSignature nvarchar(max)=N'@InjectedChildStatus varchar(40),@InjectedAnalysisJson nvarchar(max),',
  @MetricsExpandedSignature nvarchar(max),
  @MetricsChildCall nvarchar(max)=N'EXEC monitor.USP_SsisPackageModelAnalysis @IncludeExecutionScopes=1,@IncludePipelineCorrelation=1,@IncludePipelineDiagnostics=1,@ProjectModelsJson=@Models,@ScopeSnapshotJson=@Capture,@ScopeHandoverId=@handover,@ExecutionId=@execution,@MaxZeilen=0,@MaxDurationSeconds=@remaining,@LockTimeoutMs=@LockTimeoutMs,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@analysis OUTPUT,@StatusCodeOut=@childStatus OUTPUT;',
  @MetricsChildStub nvarchar(max)=N'SET @analysis=@InjectedAnalysisJson;SET @childStatus=@InjectedChildStatus;',
  @MetricsModuleLength int,@MetricsModuleHash varbinary(32),
  @MetricsInjectedStatus varchar(40),@MetricsInjectedAnalysis nvarchar(max),
  @MetricsAnalysisOut nvarchar(max),@MetricsStatusOut varchar(40),@MetricsBitnessOut bit,
  @MetricsBoundOut bit,@MetricsJsonOut nvarchar(max),@MetricsErrorOut int,@MetricsReasonOut varchar(64),
  @MetricsDeadline datetime2(3),@MetricsLockTimeout int=1000,@MetricsOuterLock int,
  @MetricsSignatureAt int,@MetricsCallAt int,@MetricsStubAt int,@MetricsExpandedAt int;
 IF OBJECT_ID(N'monitor.'+QUOTENAME(@MetricsCloneName),N'P') IS NOT NULL
  THROW 57931,N'METRICS_NULL_CLONE_ALREADY_EXISTS',1;
 SELECT @MetricsModule=OBJECT_DEFINITION(OBJECT_ID(N'monitor.InternalSsisExecutionMetrics'));
 IF @MetricsModule IS NULL THROW 57931,N'METRICS_NULL_SOURCE_UNAVAILABLE',1;
 SELECT @MetricsModuleLength=DATALENGTH(@MetricsModule),@MetricsModuleHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@MetricsModule));
 SET @MetricsSignatureAt=CHARINDEX(@MetricsSignature,@MetricsModule);
 IF @MetricsSignatureAt=0 OR CHARINDEX(@MetricsSignature,@MetricsModule,@MetricsSignatureAt+1)>0
  THROW 57931,N'METRICS_NULL_SIGNATURE_ANCHOR',1;
 SET @MetricsOriginalPrefix=SUBSTRING(@MetricsModule,1,@MetricsSignatureAt-1);
 SET @MetricsCloneDeclarationPrefix=N'CREATE PROCEDURE [monitor].'+QUOTENAME(@MetricsCloneName)+N' ';
 SET @MetricsClone=@MetricsCloneDeclarationPrefix
  +SUBSTRING(@MetricsModule,@MetricsSignatureAt,DATALENGTH(@MetricsModule)/2);
 IF CHARINDEX(@MetricsCloneDeclarationPrefix,@MetricsClone)<>1
  OR CHARINDEX(@MetricsCloneDeclarationPrefix,@MetricsClone,2)>0
  THROW 57931,N'METRICS_NULL_CLONE_DECLARATION_ANCHOR',1;
 SET @MetricsExpandedSignature=@MetricsSignature+@MetricsInjectedSignature;
 SET @MetricsExpandedAt=CHARINDEX(@MetricsSignature,@MetricsClone);
 IF @MetricsExpandedAt=0 OR CHARINDEX(@MetricsSignature,@MetricsClone,@MetricsExpandedAt+1)>0
  THROW 57931,N'METRICS_NULL_CLONE_SIGNATURE_ANCHOR',1;
 SET @MetricsClone=STUFF(@MetricsClone,@MetricsExpandedAt,LEN(@MetricsSignature),@MetricsExpandedSignature);
 SET @MetricsCallAt=CHARINDEX(@MetricsChildCall,@MetricsClone);
 IF @MetricsCallAt=0 OR CHARINDEX(@MetricsChildCall,@MetricsClone,@MetricsCallAt+1)>0
  THROW 57931,N'METRICS_NULL_CHILD_CALL_ANCHOR',1;
 SET @MetricsClone=STUFF(@MetricsClone,@MetricsCallAt,LEN(@MetricsChildCall),@MetricsChildStub);

 -- Vor der Ausführung werden Call-Stelle, Parameterergänzung und Deklarationspräfix rückgängig gemacht.
 SET @MetricsStubAt=CHARINDEX(@MetricsChildStub,@MetricsClone);
 IF @MetricsStubAt=0 OR CHARINDEX(@MetricsChildStub,@MetricsClone,@MetricsStubAt+1)>0
  THROW 57931,N'METRICS_NULL_CLONE_STUB_ANCHOR',1;
 SET @MetricsReconstructed=STUFF(@MetricsClone,@MetricsStubAt,LEN(@MetricsChildStub),@MetricsChildCall);
 SET @MetricsExpandedAt=CHARINDEX(@MetricsExpandedSignature,@MetricsReconstructed);
 IF @MetricsExpandedAt=0 OR CHARINDEX(@MetricsExpandedSignature,@MetricsReconstructed,@MetricsExpandedAt+1)>0
  THROW 57931,N'METRICS_NULL_CLONE_PARAMETER_ANCHOR',1;
 SET @MetricsReconstructed=STUFF(@MetricsReconstructed,@MetricsExpandedAt,LEN(@MetricsExpandedSignature),@MetricsSignature);
 IF CONVERT(varbinary(max),LEFT(@MetricsReconstructed,DATALENGTH(@MetricsCloneDeclarationPrefix)/2))
   <>CONVERT(varbinary(max),@MetricsCloneDeclarationPrefix)
  THROW 57931,N'METRICS_NULL_CLONE_DECLARATION_ANCHOR',1;
 SET @MetricsReconstructed=@MetricsOriginalPrefix
  +SUBSTRING(@MetricsReconstructed,DATALENGTH(@MetricsCloneDeclarationPrefix)/2+1,
   DATALENGTH(@MetricsReconstructed)/2);
 IF DATALENGTH(@MetricsReconstructed)<>@MetricsModuleLength
  OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@MetricsReconstructed))<>@MetricsModuleHash
  THROW 57931,N'METRICS_NULL_CLONE_REVERSAL_MISMATCH',1;
 EXEC sys.sp_executesql @MetricsClone;
 SET @MetricsCloneCreated=1;
 SET @MetricsOuterLock=@@LOCK_TIMEOUT;

 -- NULL-Status mit leerem Analyseobjekt muss geschlossen zurückkehren.
 SET @MetricsInjectedAnalysis=N'{}';SET @MetricsInjectedStatus=NULL;
 SET @MetricsAnalysisOut=N'PROBE_STALE';SET @MetricsStatusOut='PROBE_STALE';SET @MetricsBitnessOut=1;
 SET @MetricsBoundOut=1;SET @MetricsJsonOut=N'PROBE_STALE';SET @MetricsErrorOut=-2147483647;SET @MetricsReasonOut='PROBE_STALE';
 SET @MetricsDeadline=DATEADD(minute,1,SYSUTCDATETIME());
 EXEC monitor.InternalSsisExecutionMetrics_NullStatusRegression
  @RunOrdinal=0,@Models=@Models,@Capture=@Capture,@HandoverId=NULL,@ExecutionId=9007199254740993,
  @Deadline=@MetricsDeadline,@LockTimeoutMs=@MetricsLockTimeout,
  @InjectedChildStatus=@MetricsInjectedStatus,@InjectedAnalysisJson=@MetricsInjectedAnalysis,
  @AnalysisJson=@MetricsAnalysisOut OUTPUT,@StatusCodeOut=@MetricsStatusOut OUTPUT,
  @Use32BitRuntimeOut=@MetricsBitnessOut OUTPUT,@BoundOut=@MetricsBoundOut OUTPUT,
  @MetricsJson=@MetricsJsonOut OUTPUT,@ErrorNumberOut=@MetricsErrorOut OUTPUT,@ReasonCodeOut=@MetricsReasonOut OUTPUT;
 IF @MetricsBoundOut IS NULL OR @MetricsBoundOut<>0 OR @MetricsJsonOut IS NULL OR @MetricsJsonOut<>N'[]'
  OR @MetricsAnalysisOut IS NULL OR @MetricsAnalysisOut<>@MetricsInjectedAnalysis OR @MetricsStatusOut IS NOT NULL
  OR @MetricsBitnessOut IS NOT NULL OR @MetricsErrorOut IS NOT NULL OR @MetricsReasonOut IS NOT NULL
  OR @@LOCK_TIMEOUT<>@MetricsOuterLock THROW 57931,N'METRICS_NULL_STATUS_EMPTY_ANALYSIS',1;

 -- NULL-Status mit SQL-NULL-Analyse muss den NULL-Ausgang erhalten.
 SET @MetricsInjectedAnalysis=NULL;SET @MetricsInjectedStatus=NULL;
 SET @MetricsAnalysisOut=N'PROBE_STALE';SET @MetricsStatusOut='PROBE_STALE';SET @MetricsBitnessOut=1;
 SET @MetricsBoundOut=1;SET @MetricsJsonOut=N'PROBE_STALE';SET @MetricsErrorOut=-2147483647;SET @MetricsReasonOut='PROBE_STALE';
 SET @MetricsDeadline=DATEADD(minute,1,SYSUTCDATETIME());
 EXEC monitor.InternalSsisExecutionMetrics_NullStatusRegression
  @RunOrdinal=0,@Models=@Models,@Capture=@Capture,@HandoverId=NULL,@ExecutionId=9007199254740993,
  @Deadline=@MetricsDeadline,@LockTimeoutMs=@MetricsLockTimeout,
  @InjectedChildStatus=@MetricsInjectedStatus,@InjectedAnalysisJson=@MetricsInjectedAnalysis,
  @AnalysisJson=@MetricsAnalysisOut OUTPUT,@StatusCodeOut=@MetricsStatusOut OUTPUT,
  @Use32BitRuntimeOut=@MetricsBitnessOut OUTPUT,@BoundOut=@MetricsBoundOut OUTPUT,
  @MetricsJson=@MetricsJsonOut OUTPUT,@ErrorNumberOut=@MetricsErrorOut OUTPUT,@ReasonCodeOut=@MetricsReasonOut OUTPUT;
 IF @MetricsBoundOut IS NULL OR @MetricsBoundOut<>0 OR @MetricsJsonOut IS NULL OR @MetricsJsonOut<>N'[]'
  OR @MetricsAnalysisOut IS NOT NULL OR @MetricsStatusOut IS NOT NULL OR @MetricsBitnessOut IS NOT NULL
  OR @MetricsErrorOut IS NOT NULL OR @MetricsReasonOut IS NOT NULL OR @@LOCK_TIMEOUT<>@MetricsOuterLock
  THROW 57931,N'METRICS_NULL_STATUS_NULL_ANALYSIS',1;

 -- Ein nicht unterstützter Status muss erhalten, aber abgewiesen werden.
 SET @MetricsInjectedAnalysis=N'{}';SET @MetricsInjectedStatus='UNSUPPORTED_STATUS';
 SET @MetricsAnalysisOut=N'PROBE_STALE';SET @MetricsStatusOut='PROBE_STALE';SET @MetricsBitnessOut=1;
 SET @MetricsBoundOut=1;SET @MetricsJsonOut=N'PROBE_STALE';SET @MetricsErrorOut=-2147483647;SET @MetricsReasonOut='PROBE_STALE';
 SET @MetricsDeadline=DATEADD(minute,1,SYSUTCDATETIME());
 EXEC monitor.InternalSsisExecutionMetrics_NullStatusRegression
  @RunOrdinal=0,@Models=@Models,@Capture=@Capture,@HandoverId=NULL,@ExecutionId=9007199254740993,
  @Deadline=@MetricsDeadline,@LockTimeoutMs=@MetricsLockTimeout,
  @InjectedChildStatus=@MetricsInjectedStatus,@InjectedAnalysisJson=@MetricsInjectedAnalysis,
  @AnalysisJson=@MetricsAnalysisOut OUTPUT,@StatusCodeOut=@MetricsStatusOut OUTPUT,
  @Use32BitRuntimeOut=@MetricsBitnessOut OUTPUT,@BoundOut=@MetricsBoundOut OUTPUT,
  @MetricsJson=@MetricsJsonOut OUTPUT,@ErrorNumberOut=@MetricsErrorOut OUTPUT,@ReasonCodeOut=@MetricsReasonOut OUTPUT;
 IF @MetricsBoundOut IS NULL OR @MetricsBoundOut<>0 OR @MetricsJsonOut IS NULL OR @MetricsJsonOut<>N'[]'
  OR @MetricsAnalysisOut IS NULL OR @MetricsAnalysisOut<>@MetricsInjectedAnalysis
  OR @MetricsStatusOut IS NULL OR @MetricsStatusOut<>@MetricsInjectedStatus OR @MetricsBitnessOut IS NOT NULL
  OR @MetricsErrorOut IS NOT NULL OR @MetricsReasonOut IS NOT NULL OR @@LOCK_TIMEOUT<>@MetricsOuterLock
  THROW 57931,N'METRICS_UNSUPPORTED_STATUS_REJECTED',1;

 -- Gebundener Status mit unbewiesener Pipelineabdeckung muss abgewiesen werden.
 SET @MetricsInjectedStatus='SCOPE_CAPTURE_BOUND';
 SET @MetricsInjectedAnalysis=N'{"pipelineCoverage":[{"StatusCode":"PIPELINE_BINDING_UNPROVEN"}]}';
 SET @MetricsAnalysisOut=N'PROBE_STALE';SET @MetricsStatusOut='PROBE_STALE';SET @MetricsBitnessOut=1;
 SET @MetricsBoundOut=1;SET @MetricsJsonOut=N'PROBE_STALE';SET @MetricsErrorOut=-2147483647;SET @MetricsReasonOut='PROBE_STALE';
 SET @MetricsDeadline=DATEADD(minute,1,SYSUTCDATETIME());
 EXEC monitor.InternalSsisExecutionMetrics_NullStatusRegression
  @RunOrdinal=0,@Models=@Models,@Capture=@Capture,@HandoverId=NULL,@ExecutionId=9007199254740993,
  @Deadline=@MetricsDeadline,@LockTimeoutMs=@MetricsLockTimeout,
  @InjectedChildStatus=@MetricsInjectedStatus,@InjectedAnalysisJson=@MetricsInjectedAnalysis,
  @AnalysisJson=@MetricsAnalysisOut OUTPUT,@StatusCodeOut=@MetricsStatusOut OUTPUT,
  @Use32BitRuntimeOut=@MetricsBitnessOut OUTPUT,@BoundOut=@MetricsBoundOut OUTPUT,
  @MetricsJson=@MetricsJsonOut OUTPUT,@ErrorNumberOut=@MetricsErrorOut OUTPUT,@ReasonCodeOut=@MetricsReasonOut OUTPUT;
 IF @MetricsBoundOut IS NULL OR @MetricsBoundOut<>0 OR @MetricsJsonOut IS NULL OR @MetricsJsonOut<>N'[]'
  OR @MetricsAnalysisOut IS NULL OR @MetricsAnalysisOut<>@MetricsInjectedAnalysis
  OR @MetricsStatusOut IS NULL OR @MetricsStatusOut<>@MetricsInjectedStatus OR @MetricsBitnessOut IS NOT NULL
  OR @MetricsErrorOut IS NOT NULL OR @MetricsReasonOut IS NOT NULL OR @@LOCK_TIMEOUT<>@MetricsOuterLock
  THROW 57931,N'METRICS_PIPELINE_BINDING_REJECTED',1;

 -- Gebundener Status ohne unbewiesene Pipelineabdeckung erzeugt Kennzahlen.
 SET @MetricsInjectedAnalysis=N'{}';
 SET @MetricsAnalysisOut=N'PROBE_STALE';SET @MetricsStatusOut='PROBE_STALE';SET @MetricsBitnessOut=1;
 SET @MetricsBoundOut=0;SET @MetricsJsonOut=N'PROBE_STALE';SET @MetricsErrorOut=-2147483647;SET @MetricsReasonOut='PROBE_STALE';
 SET @MetricsDeadline=DATEADD(minute,1,SYSUTCDATETIME());
 EXEC monitor.InternalSsisExecutionMetrics_NullStatusRegression
  @RunOrdinal=0,@Models=@Models,@Capture=@Capture,@HandoverId=NULL,@ExecutionId=9007199254740993,
  @Deadline=@MetricsDeadline,@LockTimeoutMs=@MetricsLockTimeout,
  @InjectedChildStatus=@MetricsInjectedStatus,@InjectedAnalysisJson=@MetricsInjectedAnalysis,
  @AnalysisJson=@MetricsAnalysisOut OUTPUT,@StatusCodeOut=@MetricsStatusOut OUTPUT,
  @Use32BitRuntimeOut=@MetricsBitnessOut OUTPUT,@BoundOut=@MetricsBoundOut OUTPUT,
  @MetricsJson=@MetricsJsonOut OUTPUT,@ErrorNumberOut=@MetricsErrorOut OUTPUT,@ReasonCodeOut=@MetricsReasonOut OUTPUT;
 IF @MetricsBoundOut IS NULL OR @MetricsBoundOut<>1 OR @MetricsJsonOut IS NULL OR @MetricsJsonOut=N'[]'
  OR COALESCE(ISJSON(@MetricsJsonOut),0)<>1 OR NOT EXISTS
   (SELECT 1 FROM OPENJSON(@MetricsJsonOut) WHERE JSON_VALUE([value],'$.MetricName')='EXECUTION_STATUS')
  OR @MetricsAnalysisOut IS NULL OR @MetricsAnalysisOut<>@MetricsInjectedAnalysis
  OR @MetricsStatusOut IS NULL OR @MetricsStatusOut<>@MetricsInjectedStatus OR @MetricsBitnessOut IS NOT NULL
  OR @MetricsErrorOut IS NOT NULL OR @MetricsReasonOut IS NOT NULL OR @@LOCK_TIMEOUT<>@MetricsOuterLock
  THROW 57931,N'METRICS_VALID_BINDING_REJECTED',1;

 -- Die Definition des Produktionsobjekts muss während der Probe unverändert bleiben.
 SELECT @MetricsModuleAfter=OBJECT_DEFINITION(OBJECT_ID(N'monitor.InternalSsisExecutionMetrics'));
 IF @MetricsModuleAfter IS NULL OR DATALENGTH(@MetricsModuleAfter)<>@MetricsModuleLength
  OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@MetricsModuleAfter))<>@MetricsModuleHash
  THROW 57931,N'METRICS_NULL_SOURCE_MODULE_CHANGED',1;

 IF @MetricsCloneCreated=1
 BEGIN
  DROP PROCEDURE monitor.InternalSsisExecutionMetrics_NullStatusRegression;
  SET @MetricsCloneCreated=0;
 END;
 PRINT N'SSIS_EXECUTION_METRICS_NULL_GUARD_PASS cases=5';
 WHILE @Case<36
 BEGIN
  SELECT @B=@Capture,@C=@Capture,@CM=@Models,@Abs=NULL,@Pct=NULL,@Limit=1000,@Duration=30,
   @RequestedCandidate=9007199254740994,@RequestedHandover=@CId;
  SET @B=JSON_MODIFY(@B,'$.comparisonContext',JSON_QUERY(N'{"contract":"ssis-comparison-context","version":"1.0.0","use32BitRuntime":false}'));
  SET @C=JSON_MODIFY(@B,'$.execution.executionId','9007199254740994');
  SET @i=0;
  WHILE @i<4
  BEGIN
   SET @Path=CONCAT('$.observations[',@i,'].executionId');SET @C=JSON_MODIFY(@C,@Path,'9007199254740994');
   SET @Path=CONCAT('$.observations[',@i,'].statisticsId');SET @C=JSON_MODIFY(@C,@Path,CONVERT(varchar(20),@i+101));SET @i+=1;
  END;
  SET @i=0;WHILE @i<2
  BEGIN
   SET @Path=CONCAT('$.componentPhases[',@i,'].phaseStatsId');SET @C=JSON_MODIFY(@C,@Path,CONVERT(varchar(20),@i+101));
   SET @Path=CONCAT('$.pathTransfers[',@i,'].dataStatsId');SET @C=JSON_MODIFY(@C,@Path,CONVERT(varchar(20),@i+101));SET @i+=1;
  END;
  IF @Case IN(1,2)
  BEGIN
   SET @C=JSON_MODIFY(JSON_MODIFY(@C,'$.componentPhases[0].endTime','2026-01-01T00:00:02Z'),'$.componentPhases[1].endTime','2026-01-01T00:00:02Z');
   SELECT @Abs=CASE WHEN @Case=1 THEN 500 ELSE 1000 END,@Pct=CASE WHEN @Case=1 THEN 50 ELSE 100 END;
  END;
  IF @Case IN(3,4)
  BEGIN
   SET @B=JSON_MODIFY(@B,'$.componentPhases[0].endTime','2026-01-01T00:00:00Z');
   IF @Case=3 SET @Abs=1;ELSE SET @Pct=1;
  END;
  IF @Case=5 SET @C=JSON_MODIFY(@C,'$.componentPhases[0].startTime','2026-02-01T00:00:00Z');
  IF @Case=6 SET @C=JSON_MODIFY(@C,'strict $.pathTransfers[0].rowsSent',NULL);
  IF @Case=7 SET @C=JSON_MODIFY(@C,'$.componentPhases[0].componentName','SyntheticUnknown');
  IF @Case=8 SET @C=JSON_MODIFY(@C,'$.pathTransfers[0].pathName','SyntheticUnknown');
  IF @Case=9
  BEGIN
   SET @Extra=JSON_MODIFY(JSON_QUERY(@C,'$.observations[2]'),'$.statisticsId','105');
   SET @C=JSON_MODIFY(@C,'append $.observations',JSON_QUERY(@Extra));
  END;
  IF @Case=10 SET @C=JSON_MODIFY(@C,'$.execution.projectLsn','92');
  IF @Case=11 SET @C=JSON_MODIFY(@C,'$.archiveSha256',REPLICATE('9',64));
  IF @Case=12 SET @C=JSON_MODIFY(@C,'$.execution.sourceBindingSha256',REPLICATE('5',64));
  IF @Case=13 SET @CM+=N' ';
  IF @Case=14 SET @RequestedHandover=NEWID();
  IF @Case=16 BEGIN SET @C=JSON_MODIFY(JSON_MODIFY(@C,'$.execution.executionStatus',3),'$.observations',JSON_QUERY(N'[]'));END;
  IF @Case=17 SET @C=JSON_MODIFY(@C,'$.execution.executionStatus',4);
  IF @Case=18
  BEGIN
   SET @C=JSON_MODIFY(JSON_MODIFY(@C,'$.componentPhases',JSON_QUERY(N'[]')),'$.pipelineSources[0].status','DENIED_PERMISSION');
   SET @C=JSON_MODIFY(@C,'$.pipelineSources[0].errorNumber',229);
  END;
  IF @Case=20 SET @Duration=0;
  IF @Case=21 SET @Limit=1;
  IF @Case=22 SET @C=JSON_MODIFY(@C,'$.execution.loggingLevel',2);
  IF @Case=23 SET @C=JSON_MODIFY(@C,'$.comparisonContext.use32BitRuntime',N'false');
  IF @Case=24 SET @RequestedCandidate=9007199254740993;
  IF @Case=25 SET @Abs=-1;
  IF @Case=26 SET @C=JSON_MODIFY(@C,'$.comparisonContext.use32BitRuntime',CONVERT(bit,1));
  IF @Case=27 SET @C=JSON_MODIFY(@C,'$.comparisonContext.extra',1);
  IF @Case=28 SET @C=JSON_MODIFY(@C,'$.execution.executionStatus',2);
  IF @Case=29 SET @C=JSON_MODIFY(@C,'$.componentPhases[0].phaseName',N'PrimeOutput ');
  IF @Case=30
  BEGIN
   SET @Extra=JSON_MODIFY(JSON_MODIFY(JSON_QUERY(@C,'$.observations[2]'),'$.statisticsId','105'),'$.executionPath',N'\SyntheticRoot\SyntheticLoop[3]\SyntheticFlow');
   SET @C=JSON_MODIFY(@C,'append $.observations',JSON_QUERY(@Extra));
   SET @Extra=JSON_MODIFY(JSON_MODIFY(JSON_QUERY(@C,'$.componentPhases[0]'),'$.phaseStatsId','103'),'$.executionPath',N'\SyntheticRoot\SyntheticLoop[3]\SyntheticFlow');
   SET @C=JSON_MODIFY(@C,'append $.componentPhases',JSON_QUERY(@Extra));
   SET @Extra=JSON_MODIFY(JSON_MODIFY(JSON_QUERY(@C,'$.pathTransfers[0]'),'$.dataStatsId','103'),'$.executionPath',N'\SyntheticRoot\SyntheticLoop[3]\SyntheticFlow');
   SET @C=JSON_MODIFY(@C,'append $.pathTransfers',JSON_QUERY(@Extra));
  END;
  IF @Case=31 BEGIN SET @B=JSON_MODIFY(@B,'$.pathTransfers[0].rowsSent',CONVERT(bigint,9223372036854775807));SET @C=JSON_MODIFY(@C,'$.pathTransfers[0].rowsSent',0);END;
  IF @Case=32 BEGIN SET @B=JSON_MODIFY(@B,'$.componentPhases[0].endTime','2026-01-12T13:46:40.000Z');SET @C=JSON_MODIFY(@C,'$.componentPhases[0].endTime','2026-01-12T13:46:40.001Z');SET @Pct=0;END;
  IF @Case=33 BEGIN SET @B=JSON_MODIFY(@B,'$.componentPhases[0].endTime','2026-01-01T00:00:00.102Z');SET @C=JSON_MODIFY(@C,'$.componentPhases[0].endTime','2026-01-01T00:00:00.171Z');END;
  IF @Case=34 BEGIN SET @B=JSON_MODIFY(@B,'$.componentPhases[0].endTime','2026-01-01T00:00:03Z');SET @C=JSON_MODIFY(@C,'$.componentPhases[0].endTime','2026-01-01T00:00:02Z');END;
  IF @Case=35 BEGIN SET @Models=JSON_MODIFY(@Models,'$.packages[0].model',JSON_QUERY(REPLACE(JSON_QUERY(@Models,'$.packages[0].model'),'"pkg1"','"pkg9"')));SET @Models=JSON_MODIFY(@Models,'$.packages[0].identities',JSON_QUERY(REPLACE(JSON_QUERY(@Models,'$.packages[0].identities'),'"pkg1"','"pkg9"')));SET @CM=@Models;END;
  SET @B=JSON_MODIFY(@B,'$.modelSetSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Models)),2));
  SET @C=JSON_MODIFY(@C,'$.modelSetSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CM)),2));
  SET @Receipt=(SELECT 'ssis-local-scope-handover' contract,'1.0.0' version,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Models)),2) modelSetSha256,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@B)),2) captureSha256,CONVERT(varchar(24),@Now,127)+'Z' issuedUtc,CONVERT(varchar(24),DATEADD(hour,1,@Now),127)+'Z' expiresUtc FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  IF @CreatedB=0 BEGIN EXEC sys.sp_addextendedproperty @name=@BName,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @CreatedB=1;END;
  ELSE EXEC sys.sp_updateextendedproperty @name=@BName,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
  SET @Receipt=(SELECT 'ssis-local-scope-handover' contract,'1.0.0' version,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CM)),2) modelSetSha256,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@C)),2) captureSha256,CONVERT(varchar(24),@Now,127)+'Z' issuedUtc,CONVERT(varchar(24),DATEADD(hour,1,@Now),127)+'Z' expiresUtc FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  IF @CreatedC=0 BEGIN EXEC sys.sp_addextendedproperty @name=@CName,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @CreatedC=1;END;
  ELSE EXEC sys.sp_updateextendedproperty @name=@CName,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
  IF @Case=15 SET @C=JSON_MODIFY(@C,'$.pathTransfers[0].rowsSent',99);
  IF @Case=19 SET @C=N'kein JSON';
  SET LOCK_TIMEOUT 1234;SET XACT_ABORT ON;
  EXEC monitor.USP_SsisExecutionComparison @BaselineProjectModelsJson=@Models,@BaselineScopeSnapshotJson=@B,@BaselineScopeHandoverId=@BId,@BaselineExecutionId=9007199254740993,@CandidateProjectModelsJson=@CM,@CandidateScopeSnapshotJson=@C,@CandidateScopeHandoverId=@RequestedHandover,@CandidateExecutionId=@RequestedCandidate,@MinDurationDeltaMs=@Abs,@MinDurationDeltaPercent=@Pct,@MaxZeilen=@Limit,@MaxDurationSeconds=@Duration,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Reason OUTPUT;
  IF @@LOCK_TIMEOUT<>1234 OR @@OPTIONS&16384<>16384 THROW 57931,N'COMPARISON_CALLER_STATE_CHANGED',1;
  IF @OriginalX=0 SET XACT_ABORT OFF;
  SET @Failure=CONCAT(N'COMPARISON_CASE_',@Case,N'_',@Status,N'_',@Reason);
  IF @Case IN(10,11,12,13,14,15,19,20,24,25,35)
  BEGIN
   IF @Status<>CASE WHEN @Case IN(20,24,25) THEN 'INVALID_PARAMETER' ELSE 'COMPARISON_BINDING_UNPROVEN' END OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison')) THROW 57931,@Failure,1;
  END
  ELSE
  BEGIN
   IF @Status<>'COMPARISON_CAPTURE_BOUND' THROW 57931,@Failure,1;
   IF @Case=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WITH([Unit] varchar(16),[DeltaValue] decimal(38,0),[ComparisonStatus] varchar(40)) WHERE ([Unit]<>'STATUS' AND (DeltaValue IS NULL OR DeltaValue<>0)) OR ComparisonStatus NOT IN('COMPARABLE_OBSERVATION','STATUS_ONLY')) THROW 57931,N'COMPARISON_EQUAL_RUNS',1;
   IF @Case=1 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectComparison') WITH([MetricName] varchar(32),[DeltaValue] decimal(38,0),[DeltaPercent] decimal(38,6)) WHERE MetricName='PHASE_LONGEST_MS' AND DeltaValue=1000 AND DeltaPercent=100)<>2 THROW 57931,N'COMPARISON_EXACT_DELTA',1;
   IF @Case=1 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED')<>6 THROW 57931,N'COMPARISON_DURATION_RULE',1;
   IF @Case=2 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED') THROW 57931,N'COMPARISON_THRESHOLD_EQUALITY',1;
   IF @Case IN(3,4) AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WITH([BaselineValue] decimal(38,0),[DeltaPercent] decimal(38,6)) WHERE BaselineValue=0 AND DeltaPercent IS NOT NULL) THROW 57931,N'COMPARISON_ZERO_BASE_PERCENT',1;
   IF @Case=4 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED') THROW 57931,N'COMPARISON_ZERO_BASE_RELATIVE_RULE',1;
   IF @Case IN(5,6,7,8,18) AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.ComparisonStatus') IN('NOT_COMPARABLE','BASELINE_ONLY','VOLUME_CONTEXT_LIMITED')) THROW 57931,N'COMPARISON_PARTIALITY_LOST',1;
   IF @Case=9 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.ComparisonStatus')='AMBIGUOUS' AND JSON_VALUE([value],'$.CandidateValue') IS NULL AND JSON_VALUE([value],'$.CandidateSourceId') IS NULL) THROW 57931,N'COMPARISON_AMBIGUITY_REPAIRED',1;
   IF @Case IN(16,17,28) AND (NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_STATUS_CHANGED') OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED')) THROW 57931,N'COMPARISON_STATUS_ONLY',1;
   IF @Case=16 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.ComparisonStatus')='BASELINE_ONLY' AND JSON_VALUE([value],'$.CandidateValue') IS NOT NULL) THROW 57931,N'COMPARISON_ABSENCE_BECAME_ZERO',1;
   IF @Case=21 AND (JSON_VALUE(@Json,'$.comparisonCoverage[0].OutputTruncated')<>'true' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectComparison'))<>1) THROW 57931,N'COMPARISON_OUTPUT_CAP',1;
   IF @Case IN(22,23,26,27) AND (EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.DeltaValue') IS NOT NULL) OR JSON_VALUE(@Json,'$.comparisonBinding[0].ContextStatus')='MATCHED_OBSERVATION_CONTEXT') THROW 57931,N'COMPARISON_CONTEXT_MISMATCH',1;
   IF @Case=29 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.ObjectKind')='PHASE' AND JSON_VALUE([value],'$.ComparisonStatus') IN('BASELINE_ONLY','CANDIDATE_ONLY'))<>8 THROW 57931,N'COMPARISON_PHASE_ORDINAL_IDENTITY',1;
   IF @Case=30 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectComparison') WHERE JSON_VALUE([value],'$.ComparisonStatus')='CANDIDATE_ONLY')<>8 THROW 57931,N'COMPARISON_ITERATION_PAIRING',1;
   IF @Case=31 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WITH([MetricName] varchar(32),[DeltaValue] decimal(38,0),[DeltaPercent] decimal(38,6)) WHERE MetricName='PATH_ROWS_SENT' AND DeltaValue=-9223372036854775807 AND DeltaPercent=-100) THROW 57931,N'COMPARISON_LARGE_EXACT_DELTA',1;
  END;
  IF @Case=15 AND COALESCE(JSON_VALUE(@Json,'$.comparisonBinding[0].CandidateStatusCode'),'')<>'SCOPE_BINDING_UNPROVEN' THROW 57931,N'COMPARISON_REJECTED_CHILD_STATUS_LOST',1;
  IF @Case=32 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.comparisonFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED' AND JSON_VALUE([value],'$.ObservedDelta')='1') THROW 57931,N'COMPARISON_UNROUNDED_PERCENT_THRESHOLD',1;
  IF @Case IN(33,34) AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectComparison') WITH([MetricName] varchar(32),[DeltaPercent] decimal(38,6)) WHERE MetricName='PHASE_LONGEST_MS' AND DeltaPercent=CASE WHEN @Case=33 THEN 67.647059 ELSE -33.333333 END) THROW 57931,N'COMPARISON_PERCENT_ROUNDING',1;
  SET @Case+=1;
 END;
 CREATE TABLE #SyntheticComparisonError([Seed] int);
 EXEC monitor.USP_SsisExecutionComparison @MaxDurationSeconds=0,@ResultSetArt='TABLE',@ResultTablesJson=N'{"comparisonBinding":"#SyntheticComparisonError"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
 IF COL_LENGTH('tempdb..#SyntheticComparisonError','StatusCode') IS NULL OR JSON_VALUE(@Json,'$.comparisonBinding[0].StatusCode')<>'INVALID_PARAMETER' THROW 57931,N'COMPARISON_INVALID_PARAMETER_TABLE_EXPORT',1;
 DECLARE @MappingError bit=0;
 BEGIN TRY EXEC monitor.USP_SsisExecutionComparison @ResultSetArt='NONE',@ResultTablesJson=N'{}';END TRY BEGIN CATCH IF ERROR_NUMBER()=51011 SET @MappingError=1;ELSE THROW;END CATCH;
 IF @MappingError=0 THROW 57931,N'COMPARISON_NON_TABLE_MAPPING',1;
 DROP TABLE #SyntheticComparisonError;
 EXEC sys.sp_dropextendedproperty @name=@BName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @CreatedB=0;
 EXEC sys.sp_dropextendedproperty @name=@CName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @CreatedC=0;
 SET @Failure=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';EXEC sys.sp_executesql @Failure;
 PRINT N'SSIS_EXECUTION_COMPARISON_PASS cases=38';
END TRY
BEGIN CATCH
 IF @MetricsCloneCreated=1 DROP PROCEDURE monitor.InternalSsisExecutionMetrics_NullStatusRegression;
 IF @CreatedB=1 EXEC sys.sp_dropextendedproperty @name=@BName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
 IF @CreatedC=1 EXEC sys.sp_dropextendedproperty @name=@CName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
 THROW;
END CATCH;
GO
