USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Die gemeinsame kanonische Fixture wird vom bestehenden Schemagenerator eingebettet.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
-- Der Test erzeugt ausschließlich eigene synthetische Katalogobjekte.
SET @Model=JSON_MODIFY(JSON_MODIFY(@Model,'$.nodes[6].attributes.isNullable',CONVERT(bit,0)),'$.nodes[7].attributes.isNullable',CONVERT(bit,0));
DECLARE @TableCreated bit=0,@UserCreated bit=0,@Bindings nvarchar(max),@Changed nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Db sysname=DB_NAME(),@Options int=@@OPTIONS,@Lock int=@@LOCK_TIMEOUT,@Tran int=@@TRANCOUNT;
IF OBJECT_ID(N'monitor.SyntheticSsisSqlTarget') IS NOT NULL OR USER_ID(N'SyntheticSsisSqlReader') IS NOT NULL THROW 57700,N'SSIS_METADATA_TEST_RESOURCE_COLLISION',1;
BEGIN TRY
    CREATE TABLE monitor.SyntheticSsisSqlTarget(SyntheticA int NOT NULL,SyntheticB nvarchar(20) NULL);SET @TableCreated=1;
    CREATE UNIQUE INDEX SyntheticCompositeKey ON monitor.SyntheticSsisSqlTarget(SyntheticA,SyntheticB);
    CREATE UNIQUE INDEX SyntheticFilteredKey ON monitor.SyntheticSsisSqlTarget(SyntheticA) WHERE SyntheticB IS NOT NULL;
    SET @Bindings=(SELECT 'ssis-sql-metadata-bindings' AS [contract],'1.0.0' AS [version],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],
        JSON_QUERY((SELECT [b].[bindingId],[b].[nodeId],@Db AS [databaseName],'monitor' AS [schemaName],'SyntheticSsisSqlTarget' AS [objectName],[b].[columnName],'keyAB' AS [keySetId]
        FROM(VALUES('bindingA','col1','SyntheticA'),('bindingB','col2','SyntheticB')) AS [b]([bindingId],[nodeId],[columnName]) FOR JSON PATH,INCLUDE_NULL_VALUES)) AS [bindings] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Bindings,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,'$.meta.sqlMetadataSchemaVersion')<>'1' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.sqlMetadata'))<>2
        OR JSON_VALUE(@Json,'$.sqlMetadata[0].StatusCode')<>'SQL_COLUMN_OBSERVED' OR JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')<>'UNIQUE_INDEX_OBSERVED'
        OR JSON_VALUE(@Json,'$.sqlMetadata[1].MaxLengthBytes')<>'40' OR JSON_VALUE(@Json,'$.sqlMetadata[1].NullableAgreement')<>'DIFFERS'
        OR JSON_VALUE(@Json,'$.sqlMetadata[0].TypeCompatibilityStatus')<>'NOT_QUALIFIED' OR JSON_VALUE(@Json,'$.sqlMetadata[0].BindingStatus')<>'CALLER_EXPLICIT' THROW 57701,N'SSIS_METADATA_CATALOG_FACTS_FAILED',1;
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Bindings,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.sqlMetadata'))<>1 OR JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')<>'UNIQUE_INDEX_OBSERVED' OR JSON_VALUE(@Json,'$.moduleStatus[0].NodeCount')<>'8' THROW 57702,N'SSIS_METADATA_LIMIT_PRECEDES_KEYSET',1;
    CREATE TABLE #SsisSqlMetadataContract_Output([seed] int NULL);
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Bindings,@ResultSetArt='TABLE',@ResultTablesJson=N'{"sqlMetadata":"#SsisSqlMetadataContract_Output"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF (SELECT COUNT(*) FROM #SsisSqlMetadataContract_Output)<>2 OR (SELECT COUNT(*) FROM tempdb.sys.columns WITH(NOLOCK) WHERE [object_id]=OBJECT_ID(N'tempdb..#SsisSqlMetadataContract_Output'))<>(SELECT COUNT(*) FROM OPENJSON(@Json,'$.sqlMetadata[0]')) THROW 57703,N'SSIS_METADATA_TABLE_JSON_PARITY_FAILED',1;
    SET @Changed=JSON_MODIFY(@Bindings,'$.bindings[1].columnName','SyntheticA ');
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_VALUE(@Json,'$.sqlMetadata[1].StatusCode')<>'SQL_COLUMN_NOT_VISIBLE' OR JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')<>'KEYSET_INCOMPLETE' THROW 57704,N'SSIS_METADATA_NAME_OR_INCOMPLETE_KEY_WIDENED',1;
    SET @Changed=JSON_MODIFY(@Bindings,'$.bindings',JSON_QUERY(N'['+JSON_QUERY(@Bindings,'$.bindings[0]')+N']'));
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')<>'NO_VISIBLE_UNFILTERED_UNIQUE_INDEX' THROW 57713,N'SSIS_METADATA_COMPOSITE_KEY_INFERRED_SINGLE_COLUMN',1;
    DROP INDEX SyntheticCompositeKey ON monitor.SyntheticSsisSqlTarget;
    CREATE UNIQUE INDEX SyntheticDisabledKey ON monitor.SyntheticSsisSqlTarget(SyntheticA);ALTER INDEX SyntheticDisabledKey ON monitor.SyntheticSsisSqlTarget DISABLE;
    SET @Changed=JSON_MODIFY(@Bindings,'$.bindings',JSON_QUERY(N'['+JSON_QUERY(@Bindings,'$.bindings[0]')+N']'));
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')<>'NO_VISIBLE_UNFILTERED_UNIQUE_INDEX' THROW 57705,N'SSIS_METADATA_FILTERED_DISABLED_KEY_QUALIFIED',1;
    SET @Changed=JSON_MODIFY(@Bindings,'$.packageSha256',REPLICATE('0',64));
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'AVAILABLE_LIMITED' OR JSON_QUERY(@Json,'$.sqlMetadata')<>N'[]' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.nodes'))<>8 THROW 57706,N'SSIS_METADATA_FOREIGN_PACKAGE_ACCEPTED_OR_STATIC_LOST',1;
    SET @Changed=JSON_MODIFY(@Bindings,'$.bindings[0].nodeId','cmp1');
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_QUERY(@Json,'$.sqlMetadata')<>N'[]' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.nodes'))<>8 THROW 57707,N'SSIS_METADATA_NONCOLUMN_BINDING_ACCEPTED',1;
    SET @Changed=REPLACE(@Bindings,N'"bindingId":',N'"bindingId":"duplicate","bindingId":');
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_QUERY(@Json,'$.sqlMetadata')<>N'[]' THROW 57708,N'SSIS_METADATA_DUPLICATE_KEY_ACCEPTED',1;
    SET @Changed=JSON_MODIFY(@Bindings,'$.bindings[1].columnName','SyntheticA');
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Changed,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF JSON_QUERY(@Json,'$.sqlMetadata')<>N'[]' THROW 57709,N'SSIS_METADATA_DUPLICATE_KEY_COLUMN_ACCEPTED',1;
    CREATE USER [SyntheticSsisSqlReader] WITHOUT LOGIN;SET @UserCreated=1;GRANT EXECUTE ON monitor.USP_SsisPackageModelAnalysis TO [SyntheticSsisSqlReader];
    EXECUTE AS USER=N'SyntheticSsisSqlReader';
    BEGIN TRY
        EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeSqlMetadata=1,@SqlMetadataBindingsJson=@Bindings,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;
        REVERT;
    END TRY BEGIN CATCH REVERT;THROW;END CATCH;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.sqlMetadata'))<>2 OR JSON_VALUE(@Json,'$.sqlMetadata[0].StatusCode')='SQL_COLUMN_OBSERVED' OR JSON_VALUE(@Json,'$.sqlMetadata[0].UniqueKeyStatus')='UNIQUE_INDEX_OBSERVED' OR JSON_VALUE(@Json,'$.sqlMetadata[0].ObjectId') IS NOT NULL THROW 57710,N'SSIS_METADATA_EXECUTE_ESCALATED_VISIBILITY',1;
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@SqlMetadataBindingsJson=@Bindings,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'INVALID_PARAMETER' OR JSON_QUERY(@Json,'$.sqlMetadata') IS NOT NULL THROW 57711,N'SSIS_METADATA_OPT_OUT_ACCESSED',1;
    IF @@OPTIONS<>@Options OR @@LOCK_TIMEOUT<>@Lock OR @@TRANCOUNT<>@Tran THROW 57712,N'SSIS_METADATA_CALLER_STATE_CHANGED',1;
    DROP USER [SyntheticSsisSqlReader];SET @UserCreated=0;DROP TABLE monitor.SyntheticSsisSqlTarget;SET @TableCreated=0;
END TRY
BEGIN CATCH
    IF @UserCreated=1 DROP USER [SyntheticSsisSqlReader];
    IF @TableCreated=1 DROP TABLE monitor.SyntheticSsisSqlTarget;
    THROW;
END CATCH;
PRINT N'SSIS_SQL_METADATA_PASS: explicit package/column scope, visible catalog facts, keyset limits, filtered/disabled negatives, permissions, optional isolation and caller state.';
GO
