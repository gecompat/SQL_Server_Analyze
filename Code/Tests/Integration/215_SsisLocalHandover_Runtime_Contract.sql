USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Die gemeinsame kanonische Fixture wird vom bestehenden Schemagenerator eingebettet.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
DECLARE @Bytes varbinary(max)=CONVERT(varbinary(max),N'SyntheticPackageByteSnapshot');
SET @Model=JSON_MODIFY(JSON_MODIFY(@Model,'$.source.packageSha256',LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@Bytes),2))),'$.source.byteLength',DATALENGTH(@Bytes));
SET @Model=JSON_MODIFY(@Model,'$.nodes[1].attributes.isDisabled',CAST(1 AS bit));
DECLARE @Id uniqueidentifier=NEWID(),@Name sysname,@Receipt nvarchar(3000),@Json nvarchar(max),@Status varchar(40),@Changed nvarchar(max),@ReceiptChanged nvarchar(3000),@Issued datetime2(3)=SYSUTCDATETIME(),@Caught bit=0,@UserCreated bit=0,@ReceiptCreated bit=0,@Impersonated bit=0;
SET @Name=N'SSIS_HANDOVER_'+LOWER(CONVERT(nvarchar(36),@Id));
SET @Receipt=(SELECT 'ssis-local-handover' AS [contract],'1.0.0' AS [version],'QUALIFIED_HOST_SNAPSHOT' AS [method],
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2) AS [modelSha256],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],DATALENGTH(@Bytes) AS [byteLength],
    JSON_VALUE(@Model,'$.producer.buildSha256') AS [buildSha256],JSON_VALUE(@Model,'$.producer.sourceCommit') AS [sourceCommit],
    CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,1,@Issued),127)+'Z' AS [expiresUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
BEGIN TRY
    EXEC [sys].[sp_addextendedproperty] @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    SET @ReceiptCreated=1;
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludePackageViews=1,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.sourceBinding[0].ProducerTrust')<>'VERIFIED_LOCAL' OR JSON_VALUE(@Json,'$.packageOverview[0].ProducerTrust')<>'VERIFIED_LOCAL'
        OR JSON_VALUE(@Json,'$.objectFindings[0].ProducerTrust')<>'VERIFIED_LOCAL'
        OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.findings') WITH([RuleId] varchar(64)) WHERE [RuleId]='SSIS_MODEL_UNVERIFIED_PRODUCER')
        THROW 57401,N'SSIS_HANDOVER_VERIFIED_BINDING_FAILED',1;
    -- Eine semantisch identische Neuserialisierung besitzt eine andere Übergabeidentität.
    SET @Changed=@Model+N' ';
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Changed,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludeObjectRules=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'EXCHANGE_HANDOVER_INVALID' OR JSON_QUERY(@Json,'$.nodes')<>N'[]' OR JSON_QUERY(@Json,'$.objectFindings')<>N'[]' THROW 57402,N'SSIS_HANDOVER_EXACT_RESULT_NOT_BOUND',1;
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@LocalHandoverId=@Id,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'EXCHANGE_HANDOVER_INVALID' THROW 57403,N'SSIS_HANDOVER_BYTES_NOT_REQUIRED',1;
    SET @ReceiptChanged=JSON_MODIFY(@Receipt,'$.expiresUtc',CONVERT(varchar(24),DATEADD(second,-1,@Issued),127)+'Z');
    EXEC [sys].[sp_updateextendedproperty] @name=@Name,@value=@ReceiptChanged,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'EXCHANGE_HANDOVER_INVALID' THROW 57404,N'SSIS_HANDOVER_EXPIRED_ACCEPTED',1;
    SET @ReceiptChanged=JSON_MODIFY(@Receipt,'$.method','QUALIFIED_HOST_SNAPSHOT ');
    EXEC [sys].[sp_updateextendedproperty] @name=@Name,@value=@ReceiptChanged,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'EXCHANGE_HANDOVER_INVALID' THROW 57405,N'SSIS_HANDOVER_PADDED_METHOD_ACCEPTED',1;
    EXEC [sys].[sp_updateextendedproperty] @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    IF USER_ID(N'SyntheticSsisHandoverReader') IS NOT NULL THROW 57406,N'SSIS_HANDOVER_TEST_USER_COLLISION',1;
    CREATE USER [SyntheticSsisHandoverReader] WITHOUT LOGIN;
    SET @UserCreated=1;
    GRANT EXECUTE ON [monitor].[USP_SsisPackageModelAnalysis] TO [SyntheticSsisHandoverReader];
    EXECUTE AS USER=N'SyntheticSsisHandoverReader';
    SET @Impersonated=1;
    BEGIN TRY
        EXEC [sys].[sp_updateextendedproperty] @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    END TRY BEGIN CATCH SET @Caught=1; END CATCH;
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    REVERT;
    SET @Impersonated=0;
    DROP USER [SyntheticSsisHandoverReader];
    SET @UserCreated=0;
    IF @Caught<>1 OR @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.sourceBinding[0].ProducerTrust')<>'VERIFIED_LOCAL' THROW 57407,N'SSIS_HANDOVER_PRIVILEGE_BOUNDARY_FAILED',1;
    EXEC [sys].[sp_dropextendedproperty] @name=@Name,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'EXCHANGE_HANDOVER_INVALID' THROW 57408,N'SSIS_HANDOVER_REVOCATION_IGNORED',1;
    EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.sourceBinding[0].ProducerTrust')<>'UNVERIFIED' THROW 57409,N'SSIS_HANDOVER_OPTIONAL_DEFAULT_LOST',1;
END TRY
BEGIN CATCH
    IF @Impersonated=1 REVERT;
    IF @UserCreated=1 AND USER_ID(N'SyntheticSsisHandoverReader') IS NOT NULL DROP USER [SyntheticSsisHandoverReader];
    IF @ReceiptCreated=1 AND EXISTS(SELECT 1 FROM sys.extended_properties WHERE [class]=1 AND [major_id]=OBJECT_ID(N'monitor.USP_SsisPackageModelAnalysis') AND [name]=@Name)
        EXEC [sys].[sp_dropextendedproperty] @name=@Name,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    THROW;
END CATCH;
PRINT N'SSIS_LOCAL_HANDOVER_PASS: protected local handover, exact model and bytes, lifetime, padding, atomic rejection and execute-only caller.';
GO
