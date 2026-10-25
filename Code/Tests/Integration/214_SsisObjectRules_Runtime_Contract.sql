USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Die gemeinsame kanonische Fixture wird vom bestehenden Schemagenerator eingebettet.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
DECLARE @Json nvarchar(max),@Status varchar(40),@Changed nvarchar(max),@Lock int=@@LOCK_TIMEOUT,@Tran int=@@TRANCOUNT;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF JSON_QUERY(@Json,'$.objectFindings') IS NOT NULL THROW 57300,N'SSIS_RULES_DEFAULT_CHANGED',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF JSON_QUERY(@Json,'$.objectFindings')<>N'[]' OR JSON_VALUE(@Json,'$.meta.objectRulesSchemaVersion')<>'1'
    THROW 57301,N'SSIS_RULES_INVENTED_FINDING',1;
SET @Changed=JSON_MODIFY(@Model,'$.nodes[1].attributes.isDisabled',CAST(1 AS bit));
SET @Changed=JSON_MODIFY(@Changed,'$.diagnostics',JSON_QUERY(N'[{"code":"UNKNOWN_COMPONENT","objectId":"cmp1"}]'));
SET @Changed=JSON_MODIFY(@Changed,'$.edges',JSON_QUERY(N'[]'));
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectFindings'))<>4
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.objectFindings') WITH([RuleId] varchar(64),[NodeId] varchar(128),[ProducerTrust] varchar(24),[PackageSha256] varchar(64),[EvidenceLevel] varchar(24))
        WHERE [RuleId]='SSIS_EXECUTABLE_DISABLED' AND [NodeId]='exe1' AND [ProducerTrust]='UNVERIFIED' AND [EvidenceLevel]='IMPORTED_STATIC' AND [PackageSha256]=REPLICATE('1',64))
    THROW 57302,N'SSIS_RULES_EVIDENCE_FAILED',1;
DECLARE @Unsupported nvarchar(max)=JSON_MODIFY(@Changed,'$.profiles.components','2.0.0');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Unsupported,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectFindings'))<>2 THROW 57309,N'SSIS_RULES_UNSUPPORTED_PROFILE_ABSENCE_CLAIM',1;
SET @Changed=JSON_MODIFY(@Changed,'$.coverage[2].status','PARTIAL');
SET @Changed=JSON_MODIFY(@Changed,'$.coverage[2].reasonCode','PROFILE_LIMIT');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectFindings'))<>2 THROW 57303,N'SSIS_RULES_PARTIAL_COVERAGE_ABSENCE_CLAIM',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@IncludePackageViews=1,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectFindings'))<>1 OR JSON_QUERY(@Json,'$.packageOverview') IS NULL
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH([WarningCode] varchar(64)) WHERE [WarningCode]='RESULT_TRUNCATED')
    THROW 57304,N'SSIS_RULES_LIMIT_OR_COMPOSITION_FAILED',1;
SET @Changed=REPLACE(JSON_MODIFY(@Model,'$.edges[0].resolution','UNRESOLVED'),N'"toId":"port2"',N'"toId":null');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.objectFindings'))<>1
    OR JSON_VALUE(@Json,'$.objectFindings[0].RuleId')<>'SSIS_EDGE_UNRESOLVED' THROW 57310,N'SSIS_RULES_UNRESOLVED_PATH_ABSENCE_CLAIM',1;
-- Eine zweite direkte Quelle ist ein geliefert belegter Sachverhalt, keine abgeleitete Lineage.
SET @Changed=JSON_MODIFY(@Model,'append $.nodes',JSON_QUERY(N'{"id":"col3","kind":"COLUMN","parentId":"port1","name":"SyntheticOther","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}'));
SET @Changed=JSON_MODIFY(@Changed,'append $.edges',JSON_QUERY(N'{"id":"edge3","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col3","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}'));
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.objectFindings[0].RuleId')<>'SSIS_COLUMN_MULTIPLE_DIRECT_SOURCES'
    OR JSON_VALUE(@Json,'$.objectFindings[0].NodeId')<>'col2' THROW 57305,N'SSIS_RULES_DIRECT_SOURCES_FAILED',1;
SET @Changed=JSON_MODIFY(@Model,'$.edges[1].resolution','UNRESOLVED');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF JSON_VALUE(@Json,'$.objectFindings[0].EdgeId')<>'edge2' OR JSON_VALUE(@Json,'$.objectFindings[0].RuleId')<>'SSIS_EDGE_UNRESOLVED'
    THROW 57306,N'SSIS_RULES_EDGE_ID_LOST',1;
SET @Changed=JSON_MODIFY(@Model,'$.nodes[1].parentId','exe1');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_REFERENCE_INVALID' OR JSON_QUERY(@Json,'$.objectFindings')<>N'[]' THROW 57307,N'SSIS_RULES_NOT_ATOMIC',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@IncludeObjectRules=NULL,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'INVALID_PARAMETER' OR @@LOCK_TIMEOUT<>@Lock OR @@TRANCOUNT<>@Tran THROW 57308,N'SSIS_RULES_PARAMETER_OR_CALLER_CHANGED',1;
PRINT N'SSIS_OBJECT_RULES_PASS: concrete static evidence, coverage guard, limits, optional composition and atomic rejection.';
GO
