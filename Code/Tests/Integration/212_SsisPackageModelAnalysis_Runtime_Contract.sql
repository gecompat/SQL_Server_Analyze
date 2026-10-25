USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Synthetische CI-Probe ohne CLR, Dateizugriff oder Änderung fremder Datenbanken.
-- Das Eingabedokument wird aus der unveränderten kanonischen Beispieldatei generiert.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
DECLARE @Status varchar(40),@Json nvarchar(max),@Bad nvarchar(max),@BeforeLock int=@@LOCK_TIMEOUT,@BeforeTransaction int=@@TRANCOUNT;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.sourceBinding[0].ProducerTrust')<>'UNVERIFIED'
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.nodes'))<>8 OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.edges'))<>2
    THROW 50000,N'SSIS_MODEL_CI_VALID_IMPORT_FAILED',1;
SET @Bad=REPLACE(@Model,N'"contract":',N'"contract":"ssis-package-model","contract":');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_INVALID' OR JSON_QUERY(@Json,'$.nodes')<>N'[]' THROW 50000,N'SSIS_MODEL_CI_DUPLICATE_KEY_FAILED',1;
SET @Bad=REPLACE(@Model,N'"kind":"PACKAGE"',N'"kind":"PACKAGE "');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_INVALID' THROW 50000,N'SSIS_MODEL_CI_PADDED_ENUM_FAILED',1;
SET @Bad=JSON_MODIFY(@Model,'$.nodes[4].attributes.direction',NULL);
-- JSON_MODIFY entfernt den Key; sowohl fehlende als auch unbekannte Richtung ist ungültig.
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_INVALID' THROW 50000,N'SSIS_MODEL_CI_REQUIRED_ATTRIBUTE_FAILED',1;
SET @Bad=JSON_MODIFY(@Model,'$.diagnostics',JSON_QUERY(N'[null]'));
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_INVALID' THROW 50000,N'SSIS_MODEL_CI_ARRAY_ELEMENT_FAILED',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=0x0102,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_SOURCE_MISMATCH' OR JSON_QUERY(@Json,'$.sourceBinding')<>N'[]' THROW 50000,N'SSIS_MODEL_CI_SOURCE_BINDING_FAILED',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.nodes'))<>1 OR JSON_VALUE(@Json,'$.moduleStatus[0].NodeCount')<>'8'
    OR @@LOCK_TIMEOUT<>@BeforeLock OR @@TRANCOUNT<>@BeforeTransaction THROW 50000,N'SSIS_MODEL_CI_LIMIT_OR_CALLER_FAILED',1;
PRINT N'SSIS_MODEL_CI_PASS: synthetic model, strict validation, atomic rejection, output limit and caller state.';
GO
