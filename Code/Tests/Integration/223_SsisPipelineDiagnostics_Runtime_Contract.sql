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
DECLARE @Id uniqueidentifier=NEWID(),@Name sysname,@Now datetime2(3)=SYSUTCDATETIME(),@Receipt nvarchar(3000),@Created bit=0,@Json nvarchar(max),@Status varchar(40);SET @Name=N'SSIS_SCOPE_'+LOWER(CONVERT(nvarchar(36),@Id));
BEGIN TRY
 DECLARE @Case int=0,@M nvarchar(max),@C nvarchar(max),@Threshold bigint,@Extra nvarchar(max),@ExpectedRows int,@Failure nvarchar(2048),@Limit int,@Duration int;
 WHILE @Case<26
 BEGIN
  SELECT @M=@Models,@C=@Capture,@Threshold=NULL,@ExpectedRows=2,@Limit=1000,@Duration=30;
  IF @Case=1 SET @M=JSON_MODIFY(@M,'$.packages[0].model.nodes[5].attributes.portRole','ERROR');
  IF @Case=2 SET @M=JSON_MODIFY(@M,'$.packages[0].model.nodes[5].attributes.portRole','NO_MATCH');
  IF @Case=3 SET @C=JSON_MODIFY(@C,'$.pathTransfers[0].rowsSent',0);
  IF @Case=4 SET @C=JSON_MODIFY(@C,'strict $.pathTransfers[0].rowsSent',NULL);
  IF @Case=5 SET @Threshold=999;
  IF @Case=6 SET @Threshold=1000;
  IF @Case IN(7,8)
  BEGIN
   SET @Extra=JSON_MODIFY(JSON_MODIFY(JSON_QUERY(@C,'$.componentPhases[0]'),'$.phaseStatsId','3'),'$.startTime','2026-01-01T00:00:00.500Z');
   IF @Case=8 SET @Extra=JSON_MODIFY(JSON_MODIFY(@Extra,'$.startTime','2026-01-01T00:00:01Z'),'$.endTime','2026-01-01T00:00:02Z');
   SET @C=JSON_MODIFY(@C,'append $.componentPhases',JSON_QUERY(@Extra));
  END;
  IF @Case=9 SET @C=JSON_MODIFY(@C,'$.componentPhases[0].startTime','2026-02-01T00:00:00Z');
  IF @Case=10 SET @C=JSON_MODIFY(@C,'$.componentPhases[0].componentName','SyntheticUnknown');
  IF @Case=11 SET @C=JSON_MODIFY(@C,'$.pathTransfers[0].pathName','SyntheticUnknown');
  IF @Case=12 SET @C=JSON_MODIFY(@C,'$.pathTransfers[1].dataStatsId','1');
  IF @Case=13 SET @C=JSON_MODIFY(@C,'$.componentPhases[1].phaseStatsId','1');
  IF @Case=14
  BEGIN
   SET @C=JSON_MODIFY(JSON_MODIFY(@C,'$.componentPhases',JSON_QUERY(N'[]')),'$.pipelineSources[0].status','DENIED_PERMISSION');
   SET @C=JSON_MODIFY(@C,'$.pipelineSources[0].errorNumber',229);
  END;
  IF @Case=15 SET @M=JSON_MODIFY(@M,'$.packages[0].pipelineIdentities.packageSha256',REPLICATE('0',64));
  IF @Case=16
  BEGIN
   SET @Extra=JSON_MODIFY(JSON_QUERY(@C,'$.pathTransfers[0]'),'$.dataStatsId','3');
   SET @C=JSON_MODIFY(@C,'append $.pathTransfers',JSON_QUERY(@Extra));
  END;
  IF @Case=17 SET @C=JSON_MODIFY(JSON_MODIFY(@C,'$.pathTransfers[0].rowsSent',CONVERT(bigint,9223372036854775807)),'$.pathTransfers[1].rowsSent',CONVERT(bigint,9223372036854775807));
  IF @Case=18 SET @M=JSON_MODIFY(@M,'$.packages[0].model.nodes[5].attributes.portRole','UNKNOWN');
  IF @Case=19
  BEGIN
   SET @C=JSON_MODIFY(@C,'$.observations',JSON_QUERY(N'[]'));
   SET @C=JSON_MODIFY(@C,'$.execution.executionStatus',3);
  END;
  IF @Case=20
  BEGIN
   SET @Extra=JSON_MODIFY(JSON_MODIFY(JSON_QUERY(@C,'$.componentPhases[0]'),'$.phaseStatsId','3'),'$.endTime','2026-01-01T00:00:03Z');
   SET @C=JSON_MODIFY(@C,'append $.componentPhases',JSON_QUERY(@Extra));SET @Limit=2;SET @Threshold=1500;
  END;
  IF @Case=21 SET @M=N'kein JSON';
  IF @Case=22 SET @Threshold=-1;
  IF @Case=23 SET @M=NULL;
  IF @Case=24 SET @Duration=0;
  IF @Case=25 SET @Threshold=-9223372036854775807;
  SET @C=JSON_MODIFY(@C,'$.modelSetSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@M)),2));
  SET @Receipt=(SELECT 'ssis-local-scope-handover' contract,'1.0.0' version,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@M)),2) modelSetSha256,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@C)),2) captureSha256,CONVERT(varchar(24),@Now,127)+'Z' issuedUtc,CONVERT(varchar(24),DATEADD(hour,1,@Now),127)+'Z' expiresUtc FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  IF @Created=0 BEGIN EXEC sys.sp_addextendedproperty @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @Created=1;END;
  ELSE EXEC sys.sp_updateextendedproperty @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
  EXEC monitor.USP_SsisPackageModelAnalysis @IncludeExecutionScopes=1,@IncludePipelineCorrelation=1,@IncludePipelineDiagnostics=1,@PipelinePhaseThresholdMs=@Threshold,@ProjectModelsJson=@M,@ScopeSnapshotJson=@C,@ScopeHandoverId=@Id,@ExecutionId=9007199254740993,@MaxZeilen=@Limit,@MaxDurationSeconds=@Duration,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
  SET @Failure=CONCAT(N'PIPELINE_DIAGNOSTIC_CASE_',@Case,N'_',@Status,N'_',JSON_VALUE(@Json,'$.scopeBinding[0].ReasonCode'));
  IF @Case IN(21,22,23,24,25)
  BEGIN
   IF @Status<>CASE WHEN @Case IN(22,24,25) THEN 'INVALID_PARAMETER' ELSE 'SCOPE_BINDING_UNPROVEN' END THROW 57921,N'DIAGNOSTIC_CONTROLLED_REJECTION_LOST',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.componentPhaseSummary')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pathTransferSummary')) THROW 57921,N'DIAGNOSTIC_INVALID_INPUT_LEAKED',1;
   SET @Case+=1;CONTINUE;
  END;
  IF @Status<>'SCOPE_CAPTURE_BOUND' OR JSON_VALUE(@Json,'$.meta.pipelineDiagnosticsSchemaVersion')<>'1' THROW 57921,@Failure,1;
  IF @Case IN(12,13,15)
  BEGIN
   IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.componentPhaseSummary')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pathTransferSummary')) THROW 57921,N'DIAGNOSTIC_REJECTED_INPUT_LEAKED',1;
  END
  ELSE
  BEGIN
   IF @Case=0 AND ((SELECT COUNT(*) FROM OPENJSON(@Json,'$.componentPhaseSummary'))<>2 OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pathTransferSummary'))<>2 OR JSON_VALUE(@Json,'$.pathTransferSummary[0].ObservedRowsSent')<>'3' OR JSON_VALUE(@Json,'$.pathTransferSummary[1].ObservedRowsSent')<>'7') THROW 57921,N'DIAGNOSTIC_ITERATION_MERGED',1;
   IF @Case IN(1,2) AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId')=CASE WHEN @Case=1 THEN 'SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED' ELSE 'SSIS_PIPELINE_NO_MATCH_OBSERVED' END)<>2 THROW 57921,N'DIAGNOSTIC_ROLE_RULE_MISSING',1;
   IF @Case=3 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER')<>1 THROW 57921,N'DIAGNOSTIC_EXPLICIT_ZERO_MISSING',1;
   IF @Case=4 AND (JSON_VALUE(@Json,'$.pathTransferSummary[0].UnknownRowCount')<>'1' OR JSON_VALUE(@Json,'$.pathTransferSummary[0].ObservedRowsSent') IS NOT NULL OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER')) THROW 57921,N'DIAGNOSTIC_UNKNOWN_BECAME_ZERO',1;
   IF @Case=5 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED')<>2 THROW 57921,N'DIAGNOSTIC_THRESHOLD_MISSING',1;
   IF @Case=6 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId')='SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED') THROW 57921,N'DIAGNOSTIC_THRESHOLD_EQUALITY',1;
   IF @Case=7 AND (JSON_VALUE(@Json,'$.componentPhaseSummary[0].ObservedIntervalSumMs')<>'1500' OR JSON_VALUE(@Json,'$.componentPhaseSummary[0].SpanMs')<>'1000' OR JSON_VALUE(@Json,'$.componentPhaseSummary[0].OverlapObserved')<>'true') THROW 57921,N'DIAGNOSTIC_OVERLAP',1;
   IF @Case=8 AND (JSON_VALUE(@Json,'$.componentPhaseSummary[0].ObservedIntervalSumMs')<>'2000' OR JSON_VALUE(@Json,'$.componentPhaseSummary[0].SpanMs')<>'2000' OR JSON_VALUE(@Json,'$.componentPhaseSummary[0].OverlapObserved')<>'false') THROW 57921,N'DIAGNOSTIC_TOUCHING_INTERVALS',1;
   IF @Case=9 AND (JSON_VALUE(@Json,'$.componentPhaseSummary[0].UnknownIntervalCount')<>'1' OR JSON_VALUE(@Json,'$.componentPhaseSummary[0].LongestIntervalMs') IS NOT NULL) THROW 57921,N'DIAGNOSTIC_REVERSED_INTERVAL',1;
   IF @Case=10 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.componentPhaseSummary'))<>1 THROW 57921,N'DIAGNOSTIC_UNASSIGNED_PHASE',1;
   IF @Case=11 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pathTransferSummary'))<>1 THROW 57921,N'DIAGNOSTIC_UNASSIGNED_TRANSFER',1;
   IF @Case=14 AND ((SELECT COUNT(*) FROM OPENJSON(@Json,'$.componentPhaseSummary'))<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.pathTransferSummary'))<>2) THROW 57921,N'DIAGNOSTIC_SOURCE_ISOLATION',1;
   IF @Case=16 AND (JSON_VALUE(@Json,'$.pathTransferSummary[0].ObservedTransferCount')<>'2' OR JSON_VALUE(@Json,'$.pathTransferSummary[0].ObservedRowsSent')<>'6') THROW 57921,N'DIAGNOSTIC_TRANSFER_SUM',1;
   IF @Case=17 AND JSON_VALUE(@Json,'$.pathTransferSummary[0].ObservedRowsSent')<>'9223372036854775807' THROW 57921,N'DIAGNOSTIC_LARGE_ROWS',1;
   IF @Case=18 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pipelineFindings') WHERE JSON_VALUE([value],'$.RuleId') IN('SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED','SSIS_PIPELINE_NO_MATCH_OBSERVED')) THROW 57921,N'DIAGNOSTIC_UNKNOWN_ROLE',1;
   IF @Case=20 AND (JSON_VALUE(@Json,'$.componentPhaseSummary[0].EvidencePhaseStatsId')<>'3' OR JSON_VALUE(@Json,'$.pipelineDiagnosticCoverage[0].OutputTruncated')<>'true' OR JSON_VALUE(@Json,'$.pipelineDiagnosticCoverage[0].ReasonCode')<>'SOURCE_OUTPUT_TRUNCATED') THROW 57921,N'DIAGNOSTIC_SOURCE_CAP_HIDDEN',1;
   IF @Case=19 AND (EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.componentPhaseSummary')) OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.pathTransferSummary'))) THROW 57921,N'DIAGNOSTIC_ABORT_IDENTITY_INVENTED',1;
  END;
  SET @Case+=1;
 END;
 EXEC sys.sp_dropextendedproperty @name=@Name,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @Created=0;
 PRINT N'SSIS_PIPELINE_DIAGNOSTICS_PASS cases=26';
END TRY
BEGIN CATCH
 IF @Created=1 EXEC sys.sp_dropextendedproperty @name=@Name,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
 THROW;
END CATCH;
GO
