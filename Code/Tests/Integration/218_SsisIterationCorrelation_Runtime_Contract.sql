USE [DeineDatenbank];
GO
SET NOCOUNT ON;

-- Die gemeinsame kanonische Fixture wird vom bestehenden Schemagenerator eingebettet.
-- BEGIN GENERATED SSIS MODEL FIXTURE
DECLARE @Model nvarchar(max)=N'{"contract":"ssis-package-model","version":"1.0.0","identityProfile":"document-order-v1","producer":{"id":"toolbelt.ssis-model","version":"1.0.0","sourceCommit":"0000000000000000000000000000000000000000","buildSha256":"0000000000000000000000000000000000000000000000000000000000000000"},"source":{"kind":"DTSX_BYTES","packageSha256":"1111111111111111111111111111111111111111111111111111111111111111","byteLength":4096,"packageFormatVersion":8,"xmlProfile":"2014/01"},"profiles":{"format":"1.0.0","components":"1.0.0","lineage":"1.0.0"},"coverage":[{"feature":"inventory","status":"COMPLETE","reasonCode":null},{"feature":"controlFlow","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"pipelineGraph","status":"COMPLETE","reasonCode":null},{"feature":"columnMetadata","status":"PARTIAL","reasonCode":"PROFILE_LIMIT"},{"feature":"directColumnMapping","status":"COMPLETE","reasonCode":null},{"feature":"valueLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"rowLineage","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"},{"feature":"expressionReferences","status":"NOT_REQUESTED","reasonCode":"SCOPE_NOT_REQUESTED"}],"nodes":[{"id":"pkg1","kind":"PACKAGE","parentId":null,"name":"SyntheticPackage","attributes":{"protectionLevel":null}},{"id":"exe1","kind":"EXECUTABLE","parentId":"pkg1","name":"SyntheticFlow","attributes":{"executableType":"Microsoft.Pipeline","isDisabled":false,"isEventHandler":false}},{"id":"cmp1","kind":"COMPONENT","parentId":"exe1","name":"SyntheticSource","attributes":{"componentClassId":"Microsoft.OLEDBSource"}},{"id":"cmp2","kind":"COMPONENT","parentId":"exe1","name":"SyntheticTarget","attributes":{"componentClassId":"Microsoft.OLEDBDestination"}},{"id":"port1","kind":"PORT","parentId":"cmp1","name":"SyntheticOutput","attributes":{"direction":"OUTPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"port2","kind":"PORT","parentId":"cmp2","name":"SyntheticInput","attributes":{"direction":"INPUT","portRole":"REGULAR","synchronousInputPortId":null}},{"id":"col1","kind":"COLUMN","parentId":"port1","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}},{"id":"col2","kind":"COLUMN","parentId":"port2","name":"SyntheticValue","attributes":{"columnRole":"DATA","typeCode":"i4","length":null,"precision":null,"scale":null,"codePage":null,"isNullable":null}}],"edges":[{"id":"edge1","kind":"PIPELINE_PATH","scopeId":"exe1","fromId":"port1","toId":"port2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":null},{"id":"edge2","kind":"COLUMN_MAP","scopeId":"exe1","fromId":"col1","toId":"col2","resolution":"RESOLVED","evidence":"DECLARED","ruleId":null,"mappingRole":"DATA_TRANSFER"}],"diagnostics":[{"code":"PROFILE_LIMIT","objectId":"exe1"}]}';
-- END GENERATED SSIS MODEL FIXTURE
-- Empfängervertrag mit synthetischem Capture und eigener Attestor-Autorität;
-- dies ist keine SSISDB-Liveabnahme oder Parserableitungsqualifikation.
DECLARE @Bytes varbinary(max)=CONVERT(varbinary(max),N'SyntheticRuntimeDefinitionBytes');
SET @Model=JSON_MODIFY(JSON_MODIFY(@Model,'$.source.packageSha256',LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@Bytes),2))),'$.source.byteLength',DATALENGTH(@Bytes));
DECLARE @Id uniqueidentifier=NEWID(),@RunId uniqueidentifier=NEWID(),@ModelName sysname,@RunName sysname,@ModelReceipt nvarchar(3000),@RunReceipt nvarchar(3000),@ChangedReceipt nvarchar(3000),@Snapshot nvarchar(max),@Changed nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Issued datetime2(3)=SYSUTCDATETIME(),@Execution bigint=9007199254740993,@ModelCreated bit=0,@RunCreated bit=0;
SET @ModelName=N'SSIS_HANDOVER_'+LOWER(CONVERT(nvarchar(36),@Id));SET @RunName=N'SSIS_RUNTIME_'+LOWER(CONVERT(nvarchar(36),@RunId));
SET @ModelReceipt=(SELECT 'ssis-local-handover' AS [contract],'1.0.0' AS [version],'QUALIFIED_HOST_SNAPSHOT' AS [method],CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2) AS [modelSha256],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],DATALENGTH(@Bytes) AS [byteLength],JSON_VALUE(@Model,'$.producer.buildSha256') AS [buildSha256],JSON_VALUE(@Model,'$.producer.sourceCommit') AS [sourceCommit],CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,1,@Issued),127)+'Z' AS [expiresUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
SET @Snapshot=(SELECT 'ssis-execution-snapshot' AS [contract],'1.0.0' AS [version],'SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1' AS [method],CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2) AS [modelSha256],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],'document-order-v1' AS [identityProfile],
    JSON_QUERY((SELECT CONVERT(varchar(20),@Execution) AS [executionId],'17' AS [projectId],'91' AS [projectLsn],'33333333-3333-3333-3333-333333333333' AS [catalogDatabaseGuid],REPLICATE('4',64) AS [sourceBindingSha256],'SyntheticRoot.dtsx' AS [packageFileName],'2026-01-01T00:00:00+00:00' AS [executionCreatedUtc],7 AS [executionStatus],'2026-01-01T00:00:00+00:00' AS [startTime],'2026-01-01T00:00:01+00:00' AS [endTime],CONVERT(varchar(24),@Issued,127)+'Z' AS [snapshotStartedUtc],CONVERT(varchar(24),@Issued,127)+'Z' AS [snapshotCompletedUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS [execution],
    JSON_QUERY((SELECT 'ssis-object-identities' AS [contract],'1.0.0' AS [version],'document-order-v1' AS [identityProfile],JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],JSON_QUERY(N'[{"nodeId":"pkg1","nodeKind":"PACKAGE","dtsId":"11111111-1111-1111-1111-111111111111","packagePath":"\\Package"},{"nodeId":"exe1","nodeKind":"EXECUTABLE","dtsId":"22222222-2222-2222-2222-222222222222","packagePath":"\\Package\\SyntheticFlow"}]') AS [objects] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS [identities],
    JSON_QUERY(N'[{"statisticsId":"1","executionId":"9007199254740993","executableId":"51","executableGuid":"11111111-1111-1111-1111-111111111111","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package","executionPath":"\\SyntheticObservedRuntimeRoot","startTime":"2026-01-01T00:00:00+00:00","endTime":"2026-01-01T00:00:01+00:00","durationMs":1000,"executionResult":0},{"statisticsId":"2","executionId":"9007199254740993","executableId":"52","executableGuid":"22222222-2222-2222-2222-222222222222","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package\\SyntheticFlow","executionPath":"\\SyntheticObservedRuntimeRoot\\SyntheticFlow","startTime":"2026-01-01T00:00:00+00:00","endTime":"2026-01-01T00:00:01+00:00","durationMs":1000,"executionResult":0}]') AS [observations] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
SET @RunReceipt=(SELECT 'ssis-local-runtime-handover' AS [contract],'1.0.0' AS [version],CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Snapshot)),2) AS [snapshotSha256],CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,1,@Issued),127)+'Z' AS [expiresUtc] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);

-- Synthetische Empfängerorakel, keine native Parser- oder SSISDB-Qualifikation.
SET @Model=JSON_MODIFY(@Model,'append $.nodes',JSON_QUERY(N'{"id":"exe2","kind":"EXECUTABLE","parentId":"exe1","name":"SyntheticLeaf[9]","attributes":{"executableType":"STOCK:SEQUENCE","isDisabled":false,"isEventHandler":false}}'));
SET @ModelReceipt=JSON_MODIFY(@ModelReceipt,'$.modelSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2));
SET @Snapshot=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@Snapshot,'$.version','1.1.0'),'$.method','SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1'),'$.modelSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2)),'$.execution.loggingLevel',1);
SET @Snapshot=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@Snapshot,'$.identities.version','1.1.0'),'$.identities.objects[0].iterationContainer',CAST(0 AS bit)),'$.identities.objects[1].iterationContainer',CAST(1 AS bit));
SET @Snapshot=JSON_MODIFY(@Snapshot,'append $.identities.objects',JSON_QUERY(N'{"nodeId":"exe2","nodeKind":"EXECUTABLE","dtsId":"55555555-5555-5555-5555-555555555555","packagePath":"\\Package\\SyntheticFlow\\SyntheticLeaf[9]","iterationContainer":false}'));
DECLARE @Leaf nvarchar(max)=N'{"statisticsId":"3","executionId":"9007199254740993","executableId":"53","executableGuid":"55555555-5555-5555-5555-555555555555","packageName":"SyntheticRoot.dtsx","packagePath":"\\Package\\SyntheticFlow\\SyntheticLeaf[9]","executionPath":"\\SyntheticObservedRuntimeRoot\\SyntheticFlow[1]\\SyntheticLeaf[9]","startTime":"2026-01-01T00:00:00+00:00","endTime":"2026-01-01T00:00:01+00:00","durationMs":100,"executionResult":0}';
SET @Snapshot=JSON_MODIFY(@Snapshot,'append $.observations',JSON_QUERY(@Leaf));
SET @Leaf=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@Leaf,'$.statisticsId','4'),'$.executionPath',N'\SyntheticObservedRuntimeRoot\SyntheticFlow[3]\SyntheticLeaf[9]'),'$.durationMs',300);
SET @Snapshot=JSON_MODIFY(@Snapshot,'append $.observations',JSON_QUERY(@Leaf));
SET @RunReceipt=JSON_MODIFY(@RunReceipt,'$.snapshotSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Snapshot)),2));
BEGIN TRY
    EXEC sys.sp_addextendedproperty @name=@ModelName,@value=@ModelReceipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @ModelCreated=1;
    EXEC sys.sp_addextendedproperty @name=@RunName,@value=@RunReceipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @RunCreated=1;
    DECLARE @Case int=0,@CaseCount int=28,@Limit int,@ExpectedMapped int,@ExpectedLeaf int,@ExpectedSummaryDuration bigint,@ExpectedCoverage varchar(32);
    WHILE @Case<@CaseCount
    BEGIN
        SELECT @Changed=@Snapshot,@Limit=1000,@ExpectedMapped=4,@ExpectedLeaf=2,@ExpectedSummaryDuration=400,@ExpectedCoverage='CONFIGURATION_OBSERVED';
        IF @Case BETWEEN 1 AND 12
        BEGIN
            DECLARE @BadPath nvarchar(4000)=CASE @Case
                WHEN 1 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[0]\SyntheticLeaf[9]'
                WHEN 2 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[01]\SyntheticLeaf[9]'
                WHEN 3 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[+1]\SyntheticLeaf[9]'
                WHEN 4 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[ 1]\SyntheticLeaf[9]'
                WHEN 5 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[9223372036854775808]\SyntheticLeaf[9]'
                WHEN 6 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[1][2]\SyntheticLeaf[9]'
                WHEN 7 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[1]\SyntheticLeaf[9][1]'
                WHEN 8 THEN N'\SyntheticObservedRuntimeRootSuffix\SyntheticFlow[1]\SyntheticLeaf[9]'
                WHEN 9 THEN N'\Ancestor\SyntheticObservedRuntimeRoot\SyntheticFlow[1]\SyntheticLeaf[9]'
                WHEN 10 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow[1]\SyntheticLeaf[9] '
                WHEN 11 THEN N'\SyntheticObservedRuntimeRoot\SyntheticFlow['+NCHAR(1633)+N']\SyntheticLeaf[9]'
                ELSE N'\SyntheticObservedRuntimeRoot\SyntheticFlow[1\SyntheticLeaf[9]' END;
            SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].executionPath',@BadPath);
            SELECT @ExpectedMapped=3,@ExpectedLeaf=1,@ExpectedSummaryDuration=300;
        END;
        IF @Case=13 BEGIN SET @Changed=JSON_MODIFY(@Changed,'$.identities.objects[1].iterationContainer',CAST(0 AS bit));SELECT @ExpectedMapped=2,@ExpectedLeaf=0,@ExpectedSummaryDuration=NULL;END;
        IF @Case=14 BEGIN SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].packageName','SyntheticChild.dtsx');SELECT @ExpectedMapped=3,@ExpectedLeaf=1,@ExpectedSummaryDuration=300;END;
        IF @Case=15 BEGIN SET @Changed=JSON_MODIFY(@Changed,'$.identities.objects[1].dtsId','55555555-5555-5555-5555-555555555555');SELECT @ExpectedMapped=1,@ExpectedLeaf=0,@ExpectedSummaryDuration=NULL;END;
        IF @Case=16 BEGIN SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].durationMs',NULL);SET @ExpectedSummaryDuration=NULL;END;
        IF @Case=17 BEGIN SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].durationMs',-1);SET @ExpectedSummaryDuration=NULL;END;
        IF @Case=18 SET @Limit=1;
        IF @Case=19 BEGIN SET @Changed=JSON_MODIFY(@Changed,'strict $.execution.loggingLevel',NULL);SET @ExpectedCoverage='UNKNOWN';END;
        IF @Case=20 SET @Changed=JSON_MODIFY(@Changed,'$.execution.executionStatus',2);
        IF @Case=21 SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].executionResult',1);
        IF @Case=22 SET @Changed=JSON_MODIFY(@Changed,'$.observations[2].executionResult',3);
        IF @Case=23 SET @Changed=JSON_MODIFY(JSON_MODIFY(@Changed,'$.identities.objects[1].iterationContainer',1),'$.identities.objects[1]."iterationContainer "',CAST(1 AS bit));
        IF @Case=24 SET @Changed=JSON_MODIFY(JSON_MODIFY(@Changed,'$.identities.objects[1].iterationContainer',NULL),'$.identities.objects[1]."iterationContainer "',CAST(1 AS bit));
        IF @Case=25 SET @Changed=JSON_MODIFY(JSON_MODIFY(@Changed,'$.execution.loggingLevel',JSON_QUERY(N'{}')),'$.execution."loggingLevel "',0);
        IF @Case=26 SET @Changed=JSON_MODIFY(JSON_MODIFY(@Changed,'$.execution.loggingLevel',NULL),'$.execution."loggingLevel "',0);
        IF @Case=27 SET @Changed=JSON_MODIFY(JSON_MODIFY(@Changed,'$.identities.objects[1].iterationContainer','true'),'$.identities.objects[1]."iterationContainer "',CAST(1 AS bit));
        SET @ChangedReceipt=JSON_MODIFY(@RunReceipt,'$.snapshotSha256',CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Changed)),2));
        EXEC sys.sp_updateextendedproperty @name=@RunName,@value=@ChangedReceipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
        EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludeExecutionCorrelation=1,@IncludeIterationCorrelation=1,@ExecutionId=@Execution,@ExecutionSnapshotJson=@Changed,@RuntimeHandoverId=@RunId,@MaxZeilen=@Limit,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
        IF @Case>=23
        BEGIN
            IF COALESCE(JSON_VALUE(@Json,'$.runtimeBinding[0].ReasonCode'),'')<>'RUNTIME_ITERATION_PROFILE_INVALID' OR COALESCE(JSON_QUERY(@Json,'$.executionCorrelation'),'')<>N'[]' OR COALESCE(JSON_QUERY(@Json,'$.executionObjectSummary'),'')<>N'[]' OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.nodes'))<>9
                THROW 57807,N'SSIS_ITERATION_KEY_ALIAS_OR_WRONG_TYPE_ACCEPTED',1;
            SET @Case+=1;CONTINUE;
        END;
        IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(JSON_VALUE(@Json,'$.runtimeBinding[0].StatusCode'),'')<>'RUNTIME_BOUND_CAPTURE' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.runtimeBinding[0].MappedRowCount')),-1)<>@ExpectedMapped OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.executionCoverage[0].ObservedRowCount')),-1)<>4
        BEGIN
            DECLARE @Failure nvarchar(2048)=CONCAT(N'SSIS_ITERATION_MAPPING_OR_FULL_COUNTS_FAILED case=',@Case,N' status=',@Status,N' reason=',JSON_VALUE(@Json,'$.runtimeBinding[0].ReasonCode'),N' error=',JSON_VALUE(@Json,'$.runtimeBinding[0].ErrorNumber'),N' mapped=',JSON_VALUE(@Json,'$.runtimeBinding[0].MappedRowCount'));
            THROW 57800,@Failure,1;
        END;
        IF @Case<>18 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.executionObjectSummary') WITH([NodeId] varchar(128) '$.ModelNodeId',[Instances] int '$.ObservedInstanceCount',[Duration] bigint '$.InclusiveObservedDurationMs',[State] varchar(40) '$.ObservationStatus') WHERE [NodeId]='exe2' AND [Instances]=@ExpectedLeaf AND ([Duration]=@ExpectedSummaryDuration OR [Duration] IS NULL AND @ExpectedSummaryDuration IS NULL) AND [State]=CASE WHEN @ExpectedLeaf=0 THEN 'UNASSIGNED_OR_NOT_OBSERVED' ELSE 'OBSERVED_PARTIAL' END)
            THROW 57801,N'SSIS_ITERATION_SUMMARY_OR_LITERAL_BRACKET_NAME_FAILED',1;
        IF JSON_VALUE(@Json,'$.executionCoverage[0].LoggingCoverage')<>@ExpectedCoverage OR JSON_VALUE(@Json,'$.executionCoverage[0].IsPartial')<>'true' OR JSON_VALUE(@Json,'$.executionCoverage[0].CaptureState')<>CASE WHEN @Case=20 THEN 'IN_PROGRESS_CAPTURE' ELSE 'TERMINAL_CAPTURE' END
            THROW 57802,N'SSIS_ITERATION_COVERAGE_OVERCLAIMED',1;
        IF @Case=18 AND ((SELECT COUNT(*) FROM OPENJSON(@Json,'$.executionCorrelation'))<>1 OR JSON_VALUE(@Json,'$.executionCoverage[0].MappedRowCount')<>'4') THROW 57803,N'SSIS_ITERATION_OUTPUT_CAP_CHANGED_EVIDENCE',1;
        IF @Case IN(21,22) AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.executionObjectSummary') WITH([NodeId] varchar(128) '$.ModelNodeId',[Failed] int '$.FailedCount',[Cancelled] int '$.CancelledCount') WHERE [NodeId]='exe2' AND (@Case=21 AND [Failed]=1 OR @Case=22 AND [Cancelled]=1)) THROW 57804,N'SSIS_ITERATION_RESULT_COUNTS_FAILED',1;
        SET @Case+=1;
    END;
    EXEC sys.sp_updateextendedproperty @name=@RunName,@value=@RunReceipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    CREATE TABLE #SsisIterationContract_Summary([seed] int NULL);CREATE TABLE #SsisIterationContract_Coverage([seed] int NULL);
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludeExecutionCorrelation=1,@IncludeIterationCorrelation=1,@ExecutionId=@Execution,@ExecutionSnapshotJson=@Snapshot,@RuntimeHandoverId=@RunId,@ResultSetArt='TABLE',@ResultTablesJson=N'{"executionObjectSummary":"#SsisIterationContract_Summary","executionCoverage":"#SsisIterationContract_Coverage"}';
    IF (SELECT COUNT(*) FROM #SsisIterationContract_Summary)<>3 OR (SELECT COUNT(*) FROM #SsisIterationContract_Coverage)<>1 THROW 57805,N'SSIS_ITERATION_TABLE_OUTPUT_FAILED',1;
    EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@IncludeIterationCorrelation=1,@ResultSetArt='NONE',@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'INVALID_PARAMETER' THROW 57806,N'SSIS_ITERATION_OPT_IN_REQUIRES_CAPTURE',1;
    EXEC sys.sp_dropextendedproperty @name=@RunName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @RunCreated=0;
    EXEC sys.sp_dropextendedproperty @name=@ModelName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';SET @ModelCreated=0;
END TRY
BEGIN CATCH
    IF @RunCreated=1 EXEC sys.sp_dropextendedproperty @name=@RunName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    IF @ModelCreated=1 EXEC sys.sp_dropextendedproperty @name=@ModelName,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
    THROW;
END CATCH;
PRINT N'SSIS_ITERATION_RECEIVER_PASS cases=30; synthetic role, ordinal segments, separate statistics, object-only durations, partial coverage and TABLE parity. Native SSISDB qualification is separate.';
GO
