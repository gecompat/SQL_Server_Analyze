[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [string]$InstanceId='primary',
    [Parameter(Mandatory)][string]$LabModulePath,
    [Parameter(Mandatory)][string]$FixtureBuilderPath,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$ExpectedBuildSha256,
    [ValidateSet('Success','Error','Abort','ErrorOutput','NoMatch')][string]$Scenario='Success',
    [ValidateSet(1,2,3)][int]$LoggingLevel=3,
    [switch]$IncludePipelineDiagnostics
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Manueller Windows-Vertrag auf einem ausdrücklich gebundenen vorhandenen Lab-Run.
# Lab stellt SSISDB bereit. Dieser Consumer besitzt nur seine eigenen Objekte;
# der Aufrufer bestimmt unabhängig die Aufbewahrung des Lab-Runs.
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Import-Module $LabModulePath -Force
$capability=Get-SqlServerLabSsisCatalogCapability -RunId $RunId -InstanceId $InstanceId
if($capability.Status -cne 'READY_FOR_FIXTURE_IMPLEMENTATION' -or $capability.Target.BindingStatus -cne 'BOUND'){throw 'SSIS_NATIVE_SOURCE_NOT_READY'}
$access=Get-SqlServerLabGeneratedSqlAccess -RunId $RunId
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new($access.ConnectionString)
if(-not $builder['Encrypt']){throw 'SSIS_NATIVE_ENCRYPT_REQUIRED'}
$builder['Initial Catalog']='master'
$connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$directory=Join-Path ([IO.Path]::GetTempPath()) ('ssis-native-correlation-'+[guid]::NewGuid().ToString('N'))
$security=[Security.AccessControl.DirectorySecurity]::new();$security.SetAccessRuleProtection($true,$false)
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().User
$security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))
[IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($directory),$security)
$scriptFile=Join-Path $directory 'own.sql';$receipt=Join-Path $directory 'ownership.private.json'
$record=[ordered]@{RunId=$RunId.ToString();InstanceId=$InstanceId;OperationId=[guid]::NewGuid().ToString();FolderName='SyntheticCorrelation_'+[guid]::NewGuid().ToString('N');FolderId=0L;ProjectName='SyntheticProject_'+[guid]::NewGuid().ToString('N');ProjectId=0L;ProjectLsn=0L;ExecutionId=0L;DatabaseAttempted=$false;FolderAttempted=$false;ProjectAttempted=$false;Phase='PLANNED';Cleanup='PENDING';Operations=@()}
$entryName=switch($Scenario){'Success'{'SyntheticRoot.dtsx'};'Error'{'SyntheticError.dtsx'};'Abort'{'SyntheticAbort.dtsx'};'ErrorOutput'{'SyntheticErrorOutput.dtsx'};'NoMatch'{'SyntheticNoMatch.dtsx'}}
$record.SourceBindings=[ordered]@{ProducerCommit=$ExpectedSourceCommit;ProducerSha256=$ExpectedBuildSha256;FixtureBuilderSha256=(Get-FileHash -LiteralPath $FixtureBuilderPath -Algorithm SHA256).Hash}
foreach($relative in @('Code/10_SSIS/034_InternalSsisScopePathMatch.sql','Code/10_SSIS/036_InternalSsisPipelineCorrelation.sql','Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql','Code/10_SSIS/035_InternalSsisExecutionScopes.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql','Code/Tools/Invoke-SsisCatalogHandover.ps1','Code/Tools/Invoke-SsisQualifiedHandover.ps1','Code/Tools/SsisHandoverSupport.psm1','Code/Tools/Invoke-SsisProjectScopeHandover.ps1','Code/Tests/Integration/221_SsisPipelineCorrelation_Native_Contract.ps1','Code/Tests/Fixtures/SSIS_Execution_Correlation/CreatePipelineProject.cs')){$record.SourceBindings[$relative]=(Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash}
$database='SyntheticSsisNative_'+[guid]::NewGuid().ToString('N');$databaseCreated=$false;$counter=[pscustomobject]@{Value=0}
$target=@{RunId=$RunId;InstanceId=$InstanceId;WindowsAuthentication=$true;Database='SSISDB';KeepConnection=$true;TimeoutSeconds=60}
function Save-Record {[IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))}
function Assert([bool]$Condition,[string]$Label){if(-not $Condition){throw ('SSIS_NATIVE_ASSERT_'+$Label)};$counter.Value++}
function Windows-Query([string]$Sql,[hashtable]$Parameters) {
    Save-Record;[IO.File]::WriteAllText($scriptFile,$Sql,[Text.UTF8Encoding]::new($false))
    $response=Invoke-SqlServerLabScript @target -ScriptPath $scriptFile -Parameters $Parameters
    $record.Operations+=@([ordered]@{Phase=$record.Phase;OperationId=$response.OperationId;Outcome=$response.Outcome;ErrorCode=$response.ErrorCode;SqlErrorNumber=$response.SqlErrorNumber});Save-Record
    if(-not $response.Success -or $response.Outcome -cne 'SUCCEEDED' -or $response.Authentication -cne 'Windows' -or $response.AuthScheme -notin @('NTLM','KERBEROS')){throw ('SSIS_NATIVE_WINDOWS_OPERATION_UNCONFIRMED_'+$record.Phase+'_'+$response.SqlErrorNumber)}
    return $response
}
function Query([string]$Sql,[hashtable]$Parameters=@{}) {
    $command=$connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=90
    foreach($key in $Parameters.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Parameters[$key])}
    try {$data=[Data.DataSet]::new();$adapter=[Data.SqlClient.SqlDataAdapter]::new($command);[void]$adapter.Fill($data);return ,$data} finally {$command.Dispose()}
}
function Convert-SourceTable($Set) {
    $table=[Data.DataTable]::new();foreach($column in $Set.Columns){[void]$table.Columns.Add([string]$column,[object])}
    foreach($row in $Set.Rows){$values=[object[]]::new($Set.Columns.Count);for($i=0;$i -lt $values.Length;$i++){$values[$i]=if($null -eq $row[$i]){[DBNull]::Value}else{$row[$i]}};[void]$table.Rows.Add($values)}
    return ,$table
}
$outputGroups=@('scopeBinding','packageScopes','packageInvocations','scopeObservations','handlerActivity','scopeObjectSummary','scopeCoverage','pipelineInstances','componentPhases','pathTransfers','pipelineCoverage')
$outputOrders=@('ExecutionId','PackageKey','InvocationId','SourceKind,SourceId','SourceKind,SourceId','PackageKey,ModelNodeId','ExecutionId','FlowStatisticsId','PhaseStatsId','DataStatsId','SourceName')
if($IncludePipelineDiagnostics){
    $outputGroups+=@('componentPhaseSummary','pathTransferSummary','pipelineFindings','pipelineDiagnosticCoverage')
    $outputOrders+=@('FlowStatisticsId,ComponentNodeId,PhaseName','FlowStatisticsId,ModelEdgeId','RuleId,FlowStatisticsId,ComponentNodeId,ModelEdgeId,SourceName,SourceId','SourceName')
}
function Test-OwnConversionFailure($Messages) {
    return @($Messages|Where-Object {$_.Code -eq -1071636471 -and ([string]$_.Message).Contains('SyntheticInvalid') -and ([string]$_.Message).Contains('Conversion failed when converting')}).Count -gt 0
}
function Read-Analysis($Handover,[string]$Mode='NONE',[switch]$Detailed) {
    $prefix='';$suffix='';$mapping=[ordered]@{}
    if($Mode -ceq 'TABLE') {
        for($i=0;$i -lt $outputGroups.Count;$i++){$table='#SyntheticPipeline'+$i;$mapping[$outputGroups[$i]]=$table;$prefix+="CREATE TABLE $table ([Seed] int);";$suffix+="SELECT * FROM $table ORDER BY $($outputOrders[$i]);DROP TABLE $table;"}
    }
    $data=Query ($prefix+"DECLARE @j nvarchar(max);EXEC monitor.USP_SsisPackageModelAnalysis @IncludeExecutionScopes=1,@IncludePipelineCorrelation=1,@IncludePipelineDiagnostics=@Diagnostics,@PipelinePhaseThresholdMs=@Threshold,@ProjectModelsJson=@Models,@ScopeSnapshotJson=@Capture,@ScopeHandoverId=@Id,@ExecutionId=@Execution,@ResultSetArt=@Mode,@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@j OUTPUT;"+$suffix+'SELECT @j;') @{Diagnostics=[bool]$IncludePipelineDiagnostics;Threshold=$(if($IncludePipelineDiagnostics){0L}else{[DBNull]::Value});Models=$Handover.ProjectModelsJson;Capture=$Handover.ScopeSnapshotJson;Id=$Handover.ScopeHandoverId;Execution=$record.ExecutionId;Mode=$Mode;Mapping=$(if($Mode -ceq 'TABLE'){$mapping|ConvertTo-Json -Compress}else{[DBNull]::Value})}
    $json=$data.Tables[$data.Tables.Count-1].Rows[0][0]|ConvertFrom-Json -Depth 40
    if($Detailed){return [pscustomobject]@{Data=$data;Json=$json}}
    return $json
}

try {
    Save-Record;$connection.Open()
    $record.DatabaseAttempted=$true;Save-Record
    [void](Query "CREATE DATABASE [$database] COLLATE SQL_Latin1_General_CP1_CS_AS;");$databaseCreated=$true;$connection.ChangeDatabase($database);[void](Query 'CREATE SCHEMA monitor AUTHORIZATION dbo;')
    foreach($relative in @('Code/01_Common/095_USP_InternalWriteResultTable.sql','Code/01_Common/096_USP_InternalPrepareResultTables.sql','Code/01_Common/098_USP_InternalEmitConsoleResult.sql','Code/10_SSIS/034_InternalSsisScopePathMatch.sql','Code/10_SSIS/036_InternalSsisPipelineCorrelation.sql','Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql','Code/10_SSIS/035_InternalSsisExecutionScopes.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql')) {
        $sql=[IO.File]::ReadAllText((Join-Path $root $relative)).Replace('USE [DeineDatenbank];',"USE [$database];")
        foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*$')){if($batch.Trim()){[void](Query $batch)}}
    }
    $instance=Windows-Query "SELECT CONVERT(nvarchar(128),SERVERPROPERTY(N'InstanceName'));" @{}
    $runtimeTarget='localhost';if($null -ne $instance.ResultSets[0].Rows[0][0]){$runtimeTarget+='\'+[string]$instance.ResultSets[0].Rows[0][0]}
    $authorArguments=@($record.ProjectName,'SQLServer2025',$runtimeTarget);if($IncludePipelineDiagnostics){$authorArguments+='--diagnostics'}
    $oracle=& $FixtureBuilderPath @authorArguments|ConvertFrom-Json
    if($LASTEXITCODE -ne 0){throw 'SSIS_NATIVE_SDK_AUTHOR_FAILED'}
    $record.FixtureEvidence=$oracle;Save-Record
    $ispac=[Convert]::FromBase64String($oracle.ispacBase64)
    $stream=[IO.MemoryStream]::new($ispac,$false);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
    try {$entry=$zip.GetEntry($entryName);$input=$entry.Open();$memory=[IO.MemoryStream]::new();try {$input.CopyTo($memory);$expectedBytes=$memory.ToArray()} finally {$input.Dispose();$memory.Dispose()}} finally {$zip.Dispose();$stream.Dispose()}
    $expectedDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedBytes)).ToLowerInvariant()
    $record.Phase='CREATE_OWN_FOLDER';$record.FolderAttempted=$true;Save-Record
    $created=Windows-Query "IF EXISTS(SELECT 1 FROM catalog.folders WHERE name=@folder) THROW 57500,'SYNTHETIC_FOLDER_COLLISION',1;DECLARE @id bigint;EXEC catalog.create_folder @folder_name=@folder,@folder_id=@id OUTPUT;SELECT @id;" @{folder=$record.FolderName}
    $record.FolderId=[long]$created.ResultSets[0].Rows[0][0];Save-Record
    $record.Phase='DEPLOY_OWN_PROJECT';$record.ProjectAttempted=$true;Save-Record
    $deployed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId AND name=@folder) THROW 57500,'SYNTHETIC_FOLDER_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.projects WHERE folder_id=@folderId AND name=@project) THROW 57500,'SYNTHETIC_PROJECT_COLLISION',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT project_id,object_version_lsn FROM catalog.projects WHERE folder_id=@folderId AND name=@project;" @{folder=$record.FolderName;folderId=$record.FolderId;project=$record.ProjectName;bytes=[byte[]]$ispac}
    $record.ProjectId=[long]$deployed.ResultSets[0].Rows[0][0];$record.ProjectLsn=[long]$deployed.ResultSets[0].Rows[0][1];Save-Record
    $roundtrip=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;CREATE TABLE #SyntheticArchive([ProjectStream] varbinary(max));INSERT #SyntheticArchive EXEC catalog.get_project @folder_name=@folder,@project_name=@project;SELECT (SELECT ProjectStream AS [*] FOR XML PATH(''),BINARY BASE64) FROM #SyntheticArchive;" @{projectId=$record.ProjectId;folderId=$record.FolderId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName}
    $returnedArchive=[Convert]::FromBase64String([string]$roundtrip.ResultSets[0].Rows[0][0]);$archiveDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($ispac));$returnedDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($returnedArchive))
    $record.ArchiveRoundtrip=[ordered]@{OriginalSha256=$archiveDigest;ReturnedSha256=$returnedDigest};Save-Record
    Assert ($archiveDigest -ceq $returnedDigest) 'CATALOG_ARCHIVE_ROUNDTRIP'
    $record.Phase='CREATE_OWN_EXECUTION'
    $execution=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @id bigint;EXEC catalog.create_execution @folder_name=@folder,@project_name=@project,@package_name=@entry,@execution_id=@id OUTPUT;SELECT @id;" @{projectId=$record.ProjectId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;entry=$entryName}
    $record.ExecutionId=[long]$execution.ResultSets[0].Rows[0][0];Save-Record
    $record.Phase='START_OWN_EXECUTION'
    # Die Windows-Gastsitzung bleibt während der eigenen asynchronen Ausführung offen.
    $abortBatch=if($Scenario -ceq 'Abort'){
        "WAITFOR DELAY '00:00:03';IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status=2) THROW 57500,'SYNTHETIC_ABORT_TARGET_CHANGED',1;EXEC catalog.stop_operation @operation_id=@id;"
    }else{''}
    $startBatch="IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status=1) THROW 57500,'SYNTHETIC_EXECUTION_CHANGED',1;DECLARE @level smallint=@logging;EXEC catalog.set_execution_parameter_value @execution_id=@id,@object_type=50,@parameter_name=N'LOGGING_LEVEL',@parameter_value=@level;EXEC catalog.start_execution @execution_id=@id;"+$abortBatch+"DECLARE @waitUntil datetime2=DATEADD(second,45,SYSUTCDATETIME());WHILE EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND status IN(1,2,5,8)) AND SYSUTCDATETIME()<@waitUntil BEGIN WAITFOR DELAY '00:00:00.250';END;IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND status IN(3,4,6,7,9)) THROW 57500,'SYNTHETIC_EXECUTION_TERMINAL_STATE_UNCONFIRMED',1;"
    [void](Windows-Query $startBatch @{id=$record.ExecutionId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;logging=$LoggingLevel})
    $deadline=[datetime]::UtcNow.AddSeconds(60)
    do {$status=[int](Query 'SELECT status FROM SSISDB.catalog.executions WHERE execution_id=@id AND project_lsn=@version;' @{id=$record.ExecutionId;version=$record.ProjectLsn}).Tables[0].Rows[0][0];if($status -in 3,4,6,7,9){break};Start-Sleep -Milliseconds 500}while([datetime]::UtcNow -lt $deadline)
    $record.NativeExecutionStatus=$status;Save-Record
    $nativeMessages=Query 'SELECT message_code,message FROM SSISDB.catalog.event_messages WHERE operation_id=@id AND message_type=120;' @{id=$record.ExecutionId}
    $record.NativeMessages=@($nativeMessages.Tables[0].Rows|ForEach-Object {[ordered]@{Code=[int]$_.message_code;Message=[string]$_.message}})
    $record.NativeExecutionStatus=$status;Save-Record
    Assert ($status -eq $(switch($Scenario){'Success'{7};'Error'{4};'Abort'{3};'ErrorOutput'{7};'NoMatch'{7}})) 'EXPECTED_NATIVE_PACKAGE_OUTCOME'
    Assert (@($record.NativeMessages|Where-Object {$_.Code -in -1073614806,-1073676264,-1073659899}).Count -eq 0) 'NO_TASK_ACTIVATION_FAILURE'
    if($Scenario -ceq 'Error'){Assert (Test-OwnConversionFailure $record.NativeMessages) 'OWN_SQL_CONVERSION_FAILURE_PROVEN'}
    $catalog=Query 'SELECT s.statistics_id,e.executable_guid,e.package_path,s.execution_path FROM SSISDB.catalog.executables e JOIN SSISDB.catalog.executable_statistics s ON s.execution_id=e.execution_id AND s.executable_id=e.executable_id WHERE e.execution_id=@id ORDER BY s.statistics_id;' @{id=$record.ExecutionId}
    $readerAdapter={param($Sql,$Parameters)
        $record.Phase='CAPTURE_FIXED_SOURCE_BATCH';$Parameters.ArchiveAsBase64=$true
        $response=Windows-Query $Sql $Parameters
        if($response.ResultSets.Count -eq 1){return [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[byte[]]@();Observations=$null;After=$null}}
        if($response.ResultSets.Count -ne 7){throw 'SSIS_NATIVE_CAPTURE_RESULT_SHAPE'}
        [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[Convert]::FromBase64String([string]$response.ResultSets[1].Rows[0][0]);Observations=(Convert-SourceTable $response.ResultSets[2]);Events=(Convert-SourceTable $response.ResultSets[3]);ComponentPhases=(Convert-SourceTable $response.ResultSets[4]);PathTransfers=(Convert-SourceTable $response.ResultSets[5]);After=(Convert-SourceTable $response.ResultSets[6])}
    }
    $arguments=@{ExecutionId=$record.ExecutionId;Connection=$connection;SourceReader=$readerAdapter;SourceBindingId=('LAB:'+ $RunId.ToString()+':'+$InstanceId);ProducerAssemblyPath=$ProducerAssemblyPath;ExpectedBuildSha256=$ExpectedBuildSha256;ExpectedSourceCommit=$ExpectedSourceCommit;IncludeExecutionScopes=$true;IncludePipelineCorrelation=$true}
    $handover=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    Assert ($handover.Status -ceq 'CAPTURED') 'REAL_SOURCE_CAPTURED'
    $result=Read-Analysis $handover
    $record.CaptureEvidence=[ordered]@{Result=$result;Models=$handover.ProjectModelsJson;Capture=$handover.ScopeSnapshotJson;Oracle=$oracle.objects;PipelineOracle=$oracle.pipelines};Save-Record
    $abortWithoutStatistics=$Scenario -ceq 'Abort' -and $status -eq 3 -and -not $result.scopeBinding[0].RootQualified -and $result.scopeCoverage[0].StatisticsCount -eq 0
    Assert ($result.scopeBinding[0].StatusCode -ceq 'SCOPE_CAPTURE_BOUND') 'SCOPE_CAPTURE_BOUND'
    if($abortWithoutStatistics) {
        Assert (@($result.packageInvocations).Count -eq 0 -and @($result.pipelineInstances).Count -eq 0 -and $result.scopeCoverage[0].IsPartial) 'ABORT_WITHOUT_STATISTICS_HAS_NO_INVENTED_SCOPE'
        Assert (@($result.componentPhases).Count -gt 0 -and @($result.pathTransfers).Count -eq 0) 'ABORT_BEFORE_SYNTHETIC_SOURCE_ROWS'
        foreach($phase in $result.componentPhases) {
            $flow=@($oracle.pipelines|Where-Object {$_.entry -ceq $entryName -and $_.flowName -ceq $phase.TaskName})
            Assert ($phase.PackageName -ceq $entryName -and $flow.Count -eq 1 -and $flow[0].components.name -ccontains $phase.ComponentName) 'ABORT_RAW_PHASE_SDK_ORACLE'
            Assert ($null -eq $phase.FlowStatisticsId -and $null -eq $phase.InvocationId -and $null -eq $phase.PackageKey -and $null -eq $phase.FlowNodeId -and $null -eq $phase.ComponentNodeId) 'ABORT_PHASE_HAS_NO_INVENTED_IDENTITY'
        }
        foreach($coverage in $result.pipelineCoverage){Assert ($coverage.IsPartial -and $coverage.MappedRowCount -eq 0) 'ABORT_COMPLETENESS_REMAINS_UNKNOWN'}
    }else{Assert ($result.scopeBinding[0].RootQualified) 'SDK_ROOT_QUALIFIED'}
    Assert ($result.packageScopes[0].PackageSha256 -ceq $expectedDigest) 'INDEPENDENT_SDK_ENTRY_BYTE_HASH'
    $expectedArchive=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($ispac)).ToLowerInvariant()
    Assert ($result.scopeBinding[0].ArchiveSha256 -ceq $expectedArchive) 'INDEPENDENT_SDK_ARCHIVE_BYTE_HASH'

    Assert (@($result.packageScopes).Count -eq $(if($Scenario -ceq 'Success'){2}else{1})) 'EXACT_REACHABLE_PACKAGE_MODELS'
    Assert (@($result.packageInvocations).Count -eq $(if($Scenario -ceq 'Success'){5}elseif($abortWithoutStatistics){0}else{1})) 'SDK_INVOCATION_COUNT'
    Assert (@($result.pipelineInstances).Count -eq $(if($Scenario -ceq 'Success'){6}elseif($abortWithoutStatistics){0}else{1})) 'SDK_FLOW_INSTANCE_COUNT'
    Assert (@($result.pipelineInstances|Where-Object {-not $_.IsPathUnique}).Count -eq 0) 'UNIQUE_FLOW_INSTANCE_PATHS'
    Assert (@($result.scopeObservations|Where-Object {$_.SourceKind -ceq 'STATISTIC' -and $_.CorrelationStatus -cne 'EXACT_SCOPED_IDENTITY'}).Count -eq 0) 'ALL_SDK_STATISTICS_SCOPED'
    $phaseCount=@($result.componentPhases).Count;$transferCount=@($result.pathTransfers).Count
    if($LoggingLevel -eq 1){Assert ($phaseCount -eq 0 -and $transferCount -eq 0) 'BASIC_LOGGING_GAP'}
    elseif($Scenario -ceq 'Success') {Assert ($phaseCount -gt 0) 'PHASE_LOGGING_AVAILABLE'}
    if($LoggingLevel -eq 2){Assert ($transferCount -eq 0) 'PERFORMANCE_TRANSFER_GAP'}
    if($LoggingLevel -eq 3 -and $Scenario -ceq 'Success'){Assert ($transferCount -gt 0) 'VERBOSE_TRANSFERS_AVAILABLE'}
    $expectedPhaseStatus=if($abortWithoutStatistics){'UNASSIGNED'}else{'SCOPED_EXACT_COMPONENT_NAME'}
    Assert (@($result.componentPhases|Where-Object CorrelationStatus -CNE $expectedPhaseStatus).Count -eq 0) 'ALL_PHASES_HAVE_PROVEN_SCOPE_STATUS'
    Assert (@($result.pathTransfers|Where-Object CorrelationStatus -CNE 'SCOPED_EXACT_PATH_REFERENCE').Count -eq 0) 'ALL_TRANSFERS_SCOPED'
    foreach($transfer in $result.pathTransfers) {
        $instance=@($result.pipelineInstances|Where-Object FlowStatisticsId -EQ $transfer.FlowStatisticsId)
        Assert ($instance.Count -eq 1 -and $instance[0].InvocationId -eq $transfer.InvocationId -and $instance[0].ExecutionPath -ceq $transfer.ExecutionPath) 'TRANSFER_INSTANCE_BINDING'
        $package=@($result.packageScopes|Where-Object PackageKey -CEQ $transfer.PackageKey)[0]
        $flow=@($oracle.pipelines|Where-Object {$_.entry -ceq $package.EntryName -and $_.flowName -ceq $transfer.TaskName})
        Assert ($flow.Count -eq 1) 'INDEPENDENT_SDK_FLOW_ORACLE'
        $path=@($flow[0].paths|Where-Object {$_.reference -ceq $transfer.PathIdentificationString -and $_.name -ceq $transfer.PathName -and $_.source -ceq $transfer.SourceComponentName -and $_.destination -ceq $transfer.DestinationComponentName})
        Assert ($path.Count -eq 1 -and $transfer.RowsSent -ge 0 -and $transfer.RowsSent -le $path[0].rows) 'INDEPENDENT_SDK_PATH_ROW_ORACLE'
    }
    if($LoggingLevel -eq 3 -and $Scenario -ceq 'Success') {
        foreach($flowInstance in $result.pipelineInstances) {
            $package=@($result.packageScopes|Where-Object PackageKey -CEQ $flowInstance.PackageKey)[0]
            $sdkFlow=@($oracle.pipelines|Where-Object {$_.entry -ceq $package.EntryName -and $_.flowName -ceq $flowInstance.FlowName})[0]
            foreach($sdkPath in $sdkFlow.paths) {
                $records=@($result.pathTransfers|Where-Object {$_.FlowStatisticsId -eq $flowInstance.FlowStatisticsId -and $_.PathIdentificationString -ceq $sdkPath.reference -and $_.PathName -ceq $sdkPath.name})
                Assert ($records.Count -gt 0 -and ($records|Measure-Object RowsSent -Sum).Sum -eq $sdkPath.rows) 'SDK_ROWS_PER_PATH_AND_INVOCATION'
            }
        }
    }
    foreach($phase in $result.componentPhases) {
        $expected=if($null -ne $phase.StartTime -and $null -ne $phase.EndTime -and [datetimeoffset]$phase.EndTime -ge [datetimeoffset]$phase.StartTime){[long]([decimal]::Truncate([decimal]([datetimeoffset]$phase.EndTime).UtcDateTime.Ticks/10000)-[decimal]::Truncate([decimal]([datetimeoffset]$phase.StartTime).UtcDateTime.Ticks/10000))}else{$null}
        Assert ($expected -eq $phase.ObservedDurationMs) 'RAW_PHASE_INTERVAL'
    }
    foreach($observation in $result.scopeObservations|Where-Object SourceKind -CEQ 'STATISTIC') {
        $pkg=@($result.packageScopes|Where-Object PackageKey -CEQ $observation.PackageKey)[0]
        $reference=@($oracle.objects|Where-Object {$_.entry -ceq $pkg.EntryName -and ([guid]$_.guid) -eq ([guid]$observation.ExecutableGuid)})
        Assert ($reference.Count -eq 1 -and $reference[0].path -ceq $observation.PackagePath) 'INDEPENDENT_SDK_GUID_PATH_ORACLE'
    }
    if($IncludePipelineDiagnostics) {
        Assert ($result.meta.pipelineDiagnosticsSchemaVersion -eq 1) 'DIAGNOSTIC_VERSION'
        Assert (@($result.pipelineDiagnosticCoverage).Count -eq 2) 'DIAGNOSTIC_SOURCE_COVERAGE'
        foreach($summary in $result.pathTransferSummary) {
            $sources=@($result.pathTransfers|Where-Object {$_.FlowStatisticsId -eq $summary.FlowStatisticsId -and $_.ModelEdgeId -ceq $summary.ModelEdgeId})
            Assert ($sources.Count -eq $summary.ObservedTransferCount -and ($sources|Measure-Object RowsSent -Sum).Sum -eq $summary.ObservedRowsSent) 'DIAGNOSTIC_PATH_AGGREGATION'
        }
        foreach($summary in $result.componentPhaseSummary) {
            $sources=@($result.componentPhases|Where-Object {$_.FlowStatisticsId -eq $summary.FlowStatisticsId -and $_.ComponentNodeId -ceq $summary.ComponentNodeId -and $_.PhaseName -ceq $summary.PhaseName})
            Assert ($sources.Count -eq $summary.ObservedIntervalCount -and ($sources|Measure-Object ObservedDurationMs -Maximum).Maximum -eq $summary.LongestIntervalMs) 'DIAGNOSTIC_PHASE_AGGREGATION'
        }
        if($Scenario -cin @('ErrorOutput','NoMatch')) {
            $rule=if($Scenario -ceq 'ErrorOutput'){'SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED'}else{'SSIS_PIPELINE_NO_MATCH_OBSERVED'}
            Assert (@($result.pipelineFindings|Where-Object RuleId -CEQ $rule).Count -eq 1) 'POSITIVE_ROUTED_FINDING'
            $finding=@($result.pipelineFindings|Where-Object RuleId -CEQ $rule)[0]
            Assert ($finding.ObservedValue -eq 3 -and $finding.SourceId -gt 0 -and $finding.PackageSha256 -ceq $expectedDigest) 'ROUTED_FINDING_EVIDENCE'
        }
    }
    $raw=Read-Analysis $handover 'RAW' -Detailed
    Assert ($raw.Data.Tables.Count -eq ($outputGroups.Count+1)) 'RAW11_PLUS_OUTPUT_JSON'
    $tableResult=Read-Analysis $handover 'TABLE' -Detailed
    Assert ($tableResult.Data.Tables.Count -eq ($outputGroups.Count+1)) 'TABLE11_PLUS_OUTPUT_JSON'
    for($i=0;$i -lt $outputGroups.Count;$i++) {
        $left=$raw.Data.Tables[$i];$right=$tableResult.Data.Tables[$i];$jsonRows=@($raw.Json.($outputGroups[$i]))
        Assert ($left.Columns.Count -eq $right.Columns.Count -and $left.Rows.Count -eq $right.Rows.Count -and $left.Rows.Count -eq $jsonRows.Count) 'OUTPUT_SHAPE_PARITY'
        for($column=0;$column -lt $left.Columns.Count;$column++) {
            $definition=$left.Columns[$column];Assert ($definition.ColumnName -ceq $right.Columns[$column].ColumnName -and $definition.DataType -eq $right.Columns[$column].DataType) 'OUTPUT_NATIVE_SCHEMA_PARITY'
            for($row=0;$row -lt $left.Rows.Count;$row++) {
                $value=$left.Rows[$row][$column];$other=$right.Rows[$row][$column];$jsonValue=$jsonRows[$row].($definition.ColumnName)
                if($value -is [DBNull]){Assert ($other -is [DBNull] -and $null -eq $jsonValue) 'OUTPUT_NULL_PARITY';continue}
                Assert ($value.Equals($other)) 'RAW_TABLE_VALUE_PARITY'
                if($value -is [datetimeoffset]){Assert ($value -eq [datetimeoffset]$jsonValue) 'JSON_DATETIME_PARITY'}
                elseif($value -is [guid]){Assert ($value -eq [guid]$jsonValue) 'JSON_GUID_PARITY'}
                elseif($value -is [string]){Assert ($value -ceq [string]$jsonValue) 'JSON_ORDINAL_TEXT_PARITY'}
                else {Assert ($value -eq $jsonValue) 'JSON_TYPED_VALUE_PARITY'}
            }
        }
    }

    Assert ((Read-Analysis $handover 'CONSOLE' -Detailed).Data.Tables.Count -eq 2 -and (Read-Analysis $handover 'NONE' -Detailed).Data.Tables.Count -eq 1) 'CONSOLE_NONE_CONTRACT'
    $record.Phase='REDEPLOY_OWN_PROJECT'
    $changedOracle=& $FixtureBuilderPath @authorArguments|ConvertFrom-Json
    if($LASTEXITCODE -ne 0){throw 'SSIS_NATIVE_SECOND_SDK_AUTHOR_FAILED'}
    $previousLsn=$record.ProjectLsn
    $changed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT object_version_lsn FROM catalog.projects WHERE project_id=@projectId;" @{projectId=$record.ProjectId;folderId=$record.FolderId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;bytes=[Convert]::FromBase64String($changedOracle.ispacBase64)}
    $record.ProjectLsn=[long]$changed.ResultSets[0].Rows[0][0];Save-Record
    Assert ($record.ProjectLsn -ne $previousLsn) 'REAL_PROJECT_VERSION_CHANGED'
    $unproven=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    Assert ($unproven.Status -ceq 'RUNTIME_BINDING_UNPROVEN' -and $unproven.ReasonCode -ceq 'EXECUTION_PROJECT_VERSION_UNAVAILABLE') 'NO_CURRENT_BYTES_FOR_HISTORICAL_EXECUTION'
    Assert ((Read-Analysis $handover).scopeBinding[0].StatusCode -ceq 'SCOPE_CAPTURE_BOUND') 'PRIOR_CAPTURE_REMAINS_AS_OF_EVIDENCE'
    $record.Phase='PASSED';$record.Cases=$counter.Value;Save-Record
} catch {
    $record.PrimaryFailure=[ordered]@{Phase=$record.Phase;Type=$_.Exception.GetType().Name;Message=$_.Exception.Message};Save-Record
    throw
} finally {
    $primaryPhase=$record.Phase;$record.Phase='CLEANUP_OWN_OBJECTS';Save-Record
    $cleanupErrors=[Collections.Generic.List[string]]::new()
    try {
        if($record.FolderAttempted){
            if($record.FolderId -lt 1 -or $record.ProjectAttempted -and $record.ProjectId -lt 1){$cleanupErrors.Add('CATALOG_MUTATION_OWNERSHIP_UNCONFIRMED')}
            else {
                try {
                    [void](Windows-Query "SET XACT_ABORT ON;SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;BEGIN TRANSACTION;IF NOT EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId AND name=@folder) THROW 57500,'SYNTHETIC_FOLDER_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.environments WHERE folder_id=@folderId) OR EXISTS(SELECT 1 FROM catalog.projects WHERE folder_id=@folderId AND project_id<>@projectId) THROW 57500,'SYNTHETIC_FOREIGN_OBJECT_RETAINED',1;IF @projectId>0 BEGIN IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND name=@project AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.executions WHERE folder_name=@folder AND project_name=@project AND status IN(2,5,8)) THROW 57500,'SYNTHETIC_ACTIVE_EXECUTION_RETAINED',1;EXEC catalog.delete_project @folder_name=@folder,@project_name=@project;END;EXEC catalog.delete_folder @folder_name=@folder;COMMIT;IF EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId OR name=@folder) THROW 57500,'SYNTHETIC_FOLDER_REMOVAL_UNCONFIRMED',1;" @{folderId=$record.FolderId;folder=$record.FolderName;projectId=$record.ProjectId;project=$record.ProjectName;version=$record.ProjectLsn})
                } catch {$cleanupErrors.Add('CATALOG_CLEANUP_UNCONFIRMED')}
            }
        }
        # Die DB-Bereinigung bleibt unabhängig von einer Quellbereinigung.
        if($record.DatabaseAttempted){
            if(-not $databaseCreated -or $connection.State -ne 'Open'){$cleanupErrors.Add('DATABASE_MUTATION_OR_CHANNEL_UNCONFIRMED')}
            else {
                try {
                    [void](Query 'IF @@TRANCOUNT>0 ROLLBACK;');$connection.ChangeDatabase('master');[void](Query "ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [$database];")
                    if((Query 'SELECT DB_ID(@DatabaseName);' @{DatabaseName=$database}).Tables[0].Rows[0][0] -isnot [DBNull]){throw 'SSIS_NATIVE_DATABASE_REMOVAL_UNCONFIRMED'}
                    $databaseCreated=$false
                } catch {$cleanupErrors.Add('DATABASE_CLEANUP_UNCONFIRMED')}
            }
        }
        $record.Cleanup=if($cleanupErrors.Count -eq 0){'CONFIRMED_OWN_OBJECTS_REMOVED'}else{'UNCONFIRMED_RECOVERY_REQUIRED'}
        $record.CleanupErrors=@($cleanupErrors);$record.Phase=$primaryPhase;Save-Record
    } finally {$connection.Dispose();$builder.Clear()}
    if($cleanupErrors.Count -gt 0){throw 'SSIS_NATIVE_CLEANUP_UNCONFIRMED_OWN_OBJECT_RECOVERY_REQUIRED'}
}
Write-Output "SSIS_PIPELINE_NATIVE_PASS cases=$($counter.Value); SDK-authored GUID/path/bytes oracle, real execution and redeployment, own object cleanup confirmed. The existing Lab remains retained."
