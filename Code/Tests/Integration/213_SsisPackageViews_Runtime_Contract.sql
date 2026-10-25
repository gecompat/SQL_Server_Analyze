USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Die gemeinsame kanonische Fixture wird vom bestehenden Schemagenerator eingebettet.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
DECLARE @Status varchar(40),@Json nvarchar(max),@Bad nvarchar(max),@BeforeLock int=@@LOCK_TIMEOUT,@BeforeTransaction int=@@TRANCOUNT;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_QUERY(@Json,'$.packageOverview') IS NOT NULL
    THROW 57200,N'SSIS_VIEWS_DEFAULT_CHANGED',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@IncludePackageViews=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.meta.packageViewsSchemaVersion')<>'1'
    OR JSON_VALUE(@Json,'$.packageOverview[0].SourceNodeCount')<>'8'
    OR JSON_VALUE(@Json,'$.packageOverview[0].ComponentCount')<>'2'
    OR JSON_VALUE(@Json,'$.packageOverview[0].ObservedDataFlowScopeCount')<>'1'
    OR JSON_VALUE(@Json,'$.packageOverview[0].ProducerTrust')<>'UNVERIFIED'
    THROW 57201,N'SSIS_VIEWS_OVERVIEW_FAILED',1;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.executables'))<>1
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.components'))<>2
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.columnRelations'))<>1
    OR JSON_VALUE(@Json,'$.executables[0].OwnerDepth')<>'2'
    OR JSON_VALUE(@Json,'$.dataFlows[0].DeclaredPathCount')<>'1'
    OR JSON_VALUE(@Json,'$.columnRelations[0].FromComponentNodeId')<>'cmp1'
    OR JSON_VALUE(@Json,'$.columnRelations[0].ToComponentNodeId')<>'cmp2'
    OR JSON_VALUE(@Json,'$.columnRelations[0].FromTypeCode')<>'i4'
    THROW 57202,N'SSIS_VIEWS_PROJECTION_FAILED',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@IncludePackageViews=1,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.executables'))<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.components'))<>1
    OR JSON_VALUE(@Json,'$.packageOverview[0].ComponentCount')<>'2' OR JSON_VALUE(@Json,'$.dataFlows[0].DataColumnCount')<>'2'
    THROW 57203,N'SSIS_VIEWS_LIMIT_APPLIED_BEFORE_PROJECTION',1;
SET @Bad=JSON_MODIFY(JSON_MODIFY(@Model,'$.edges[1].fromId',NULL),'$.edges[1].resolution','UNRESOLVED');
-- JSON null bleibt als erforderliches Feld erhalten.
SET @Bad=REPLACE(@Bad,N'"kind":"COLUMN_MAP"',N'"fromId":null,"kind":"COLUMN_MAP"');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@IncludePackageViews=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.packageOverview[0].UnresolvedEdgeCount')<>'1'
    OR JSON_VALUE(@Json,'$.columnRelations[0].FromColumnNodeId') IS NOT NULL
    THROW 57204,N'SSIS_VIEWS_UNRESOLVED_WAS_INVENTED',1;
SET @Bad=JSON_MODIFY(@Model,'$.nodes[1].parentId','exe1');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@IncludePackageViews=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'EXCHANGE_REFERENCE_INVALID' OR JSON_QUERY(@Json,'$.packageOverview')<>N'[]' OR JSON_QUERY(@Json,'$.components')<>N'[]'
    THROW 57205,N'SSIS_VIEWS_INVALID_IMPORT_NOT_ATOMIC',1;
SET @Bad=REPLACE(@Model,N'"length":null',N'"length":1e2');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@IncludePackageViews=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.columnRelations[0].FromLength')<>'100' OR JSON_VALUE(@Json,'$.columnRelations[0].ToLength')<>'100'
    THROW 57207,N'SSIS_VIEWS_EXPONENT_LENGTH_LOST',1;
SET @Bad=REPLACE(@Model,N'"length":null',N'"length":100.0');
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Bad,@IncludePackageViews=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.columnRelations[0].FromLength')<>'100'
    THROW 57208,N'SSIS_VIEWS_DECIMAL_LENGTH_LOST',1;
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@IncludePackageViews=NULL,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
IF @Status<>'INVALID_PARAMETER' OR @@TRANCOUNT<>@BeforeTransaction OR @@LOCK_TIMEOUT<>@BeforeLock
    THROW 57206,N'SSIS_VIEWS_PARAMETER_OR_CALLER_CHANGED',1;
PRINT N'SSIS_PACKAGE_VIEWS_PASS: opt-in, complete-source projection, direct relations, missing endpoints, limits and atomic rejection.';
GO
