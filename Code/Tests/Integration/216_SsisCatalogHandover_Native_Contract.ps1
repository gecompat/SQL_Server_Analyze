[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [string]$InstanceId='primary',
    [Parameter(Mandatory)][string]$LabModulePath,
    [Parameter(Mandatory)][string]$FixtureBuilderPath,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$ExpectedBuildSha256
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Manueller Windows-Vertrag auf einem ausdrücklich eigenen frischen Lab-Run.
# Lab stellt SSISDB bereit. Dieser Consumer besitzt nur seine eigenen Objekte;
# der Aufrufer entfernt den gesamten eigenen Run nach bestätigtem Abschluss.
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
$record.SourceBindings=[ordered]@{ProducerCommit=$ExpectedSourceCommit;ProducerSha256=$ExpectedBuildSha256;FixtureBuilderSha256=(Get-FileHash -LiteralPath $FixtureBuilderPath -Algorithm SHA256).Hash}
foreach($relative in @('Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql','Code/Tools/Invoke-SsisCatalogHandover.ps1','Code/Tools/Invoke-SsisQualifiedHandover.ps1','Code/Tools/SsisHandoverSupport.psm1','Code/Tests/Integration/216_SsisCatalogHandover_Native_Contract.ps1')){$record.SourceBindings[$relative]=(Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash}
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
function Read-Analysis($Handover) {
    $data=Query "DECLARE @Json nvarchar(max);EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludeExecutionCorrelation=1,@ExecutionId=@Execution,@ExecutionSnapshotJson=@Snapshot,@RuntimeHandoverId=@Run,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;SELECT @Json;" @{Model=$Handover.PackageModelJson;Bytes=[byte[]]$Handover.PackageBytes;Id=$Handover.LocalHandoverId;Execution=$record.ExecutionId;Snapshot=$Handover.ExecutionSnapshotJson;Run=$Handover.RuntimeHandoverId}
    return ($data.Tables[0].Rows[0][0]|ConvertFrom-Json -Depth 32)
}
try {
    Save-Record;$connection.Open()
    $record.DatabaseAttempted=$true;Save-Record
    [void](Query "CREATE DATABASE [$database] COLLATE SQL_Latin1_General_CP1_CS_AS;");$databaseCreated=$true;$connection.ChangeDatabase($database);[void](Query 'CREATE SCHEMA monitor AUTHORIZATION dbo;')
    foreach($relative in @('Code/01_Common/095_USP_InternalWriteResultTable.sql','Code/01_Common/096_USP_InternalPrepareResultTables.sql','Code/01_Common/098_USP_InternalEmitConsoleResult.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql')) {
        $sql=[IO.File]::ReadAllText((Join-Path $root $relative)).Replace('USE [DeineDatenbank];',"USE [$database];")
        foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*$')){if($batch.Trim()){[void](Query $batch)}}
    }
    $oracle=& $FixtureBuilderPath $record.ProjectName 'SQLServer2025' --oracle|ConvertFrom-Json
    if($LASTEXITCODE -ne 0){throw 'SSIS_NATIVE_SDK_AUTHOR_FAILED'}
    $ispac=[Convert]::FromBase64String($oracle.ispacBase64)
    $stream=[IO.MemoryStream]::new($ispac,$false);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
    try {$entry=$zip.GetEntry('SyntheticRoot.dtsx');$input=$entry.Open();$memory=[IO.MemoryStream]::new();try {$input.CopyTo($memory);$expectedBytes=$memory.ToArray()} finally {$input.Dispose();$memory.Dispose()}} finally {$zip.Dispose();$stream.Dispose()}
    $expectedDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedBytes)).ToLowerInvariant()
    $record.Phase='CREATE_OWN_FOLDER';$record.FolderAttempted=$true;Save-Record
    $created=Windows-Query "IF EXISTS(SELECT 1 FROM catalog.folders WHERE name=@folder) THROW 57500,'SYNTHETIC_FOLDER_COLLISION',1;DECLARE @id bigint;EXEC catalog.create_folder @folder_name=@folder,@folder_id=@id OUTPUT;SELECT @id;" @{folder=$record.FolderName}
    $record.FolderId=[long]$created.ResultSets[0].Rows[0][0];Save-Record
    $record.Phase='DEPLOY_OWN_PROJECT';$record.ProjectAttempted=$true;Save-Record
    $deployed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId AND name=@folder) THROW 57500,'SYNTHETIC_FOLDER_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.projects WHERE folder_id=@folderId AND name=@project) THROW 57500,'SYNTHETIC_PROJECT_COLLISION',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT project_id,object_version_lsn FROM catalog.projects WHERE folder_id=@folderId AND name=@project;" @{folder=$record.FolderName;folderId=$record.FolderId;project=$record.ProjectName;bytes=[byte[]]$ispac}
    $record.ProjectId=[long]$deployed.ResultSets[0].Rows[0][0];$record.ProjectLsn=[long]$deployed.ResultSets[0].Rows[0][1];Save-Record
    $record.Phase='CREATE_OWN_EXECUTION'
    $execution=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @id bigint;EXEC catalog.create_execution @folder_name=@folder,@project_name=@project,@package_name=N'SyntheticRoot.dtsx',@execution_id=@id OUTPUT;SELECT @id;" @{projectId=$record.ProjectId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName}
    $record.ExecutionId=[long]$execution.ResultSets[0].Rows[0][0];Save-Record
    $record.Phase='START_OWN_EXECUTION'
    [void](Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status=1) THROW 57500,'SYNTHETIC_EXECUTION_CHANGED',1;DECLARE @level smallint=3;EXEC catalog.set_execution_parameter_value @execution_id=@id,@object_type=50,@parameter_name=N'LOGGING_LEVEL',@parameter_value=@level;EXEC catalog.start_execution @execution_id=@id;" @{id=$record.ExecutionId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName})
    $deadline=[datetime]::UtcNow.AddSeconds(60)
    do {$status=[int](Query 'SELECT status FROM SSISDB.catalog.executions WHERE execution_id=@id AND project_lsn=@version;' @{id=$record.ExecutionId;version=$record.ProjectLsn}).Tables[0].Rows[0][0];if($status -in 3,4,6,7,9){break};Start-Sleep -Milliseconds 500}while([datetime]::UtcNow -lt $deadline)
    Assert ($status -eq 7) 'REAL_PACKAGE_SUCCEEDED'
    $catalog=Query 'SELECT s.statistics_id,e.executable_guid,e.package_path,s.execution_path FROM SSISDB.catalog.executables e JOIN SSISDB.catalog.executable_statistics s ON s.execution_id=e.execution_id AND s.executable_id=e.executable_id WHERE e.execution_id=@id ORDER BY s.statistics_id;' @{id=$record.ExecutionId}
    $packageRows=@($catalog.Tables[0].Rows|Where-Object {([guid]$_.executable_guid).ToString('D') -ceq $oracle.packageDtsId})
    $sequenceRows=@($catalog.Tables[0].Rows|Where-Object {([guid]$_.executable_guid).ToString('D') -ceq $oracle.sequenceDtsId})
    Assert ($packageRows.Count -eq 1 -and $sequenceRows.Count -eq 1) 'SDK_GUIDS_IN_REAL_STATISTICS'
    Assert ([string]$packageRows[0].package_path -ceq $oracle.packagePath -and [string]$sequenceRows[0].package_path -ceq $oracle.sequencePath) 'SDK_CATALOG_PATH_ORACLE'
    $readerAdapter={param($Sql,$Parameters)
        $record.Phase='CAPTURE_FIXED_SOURCE_BATCH';$Parameters.ArchiveAsBase64=$true
        $response=Windows-Query $Sql $Parameters
        if($response.ResultSets.Count -eq 1){return [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[byte[]]@();Observations=$null;After=$null}}
        if($response.ResultSets.Count -ne 4){throw 'SSIS_NATIVE_CAPTURE_RESULT_SHAPE'}
        [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[Convert]::FromBase64String([string]$response.ResultSets[1].Rows[0][0]);Observations=(Convert-SourceTable $response.ResultSets[2]);After=(Convert-SourceTable $response.ResultSets[3])}
    }
    $arguments=@{ExecutionId=$record.ExecutionId;Connection=$connection;SourceReader=$readerAdapter;SourceBindingId=('LAB:'+ $RunId.ToString()+':'+$InstanceId);ProducerAssemblyPath=$ProducerAssemblyPath;ExpectedBuildSha256=$ExpectedBuildSha256;ExpectedSourceCommit=$ExpectedSourceCommit}
    $handover=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    Assert ($handover.Status -ceq 'CAPTURED') 'REAL_SOURCE_CAPTURED'
    $result=Read-Analysis $handover
    $record.CaptureEvidence=[ordered]@{RuntimeBinding=$result.runtimeBinding;Correlations=$result.executionCorrelation;SnapshotJson=$handover.ExecutionSnapshotJson;ModelJson=$handover.PackageModelJson;SdkOracle=[ordered]@{PackageGuid=$oracle.packageDtsId;SequenceGuid=$oracle.sequenceDtsId;PackagePath=$oracle.packagePath;SequencePath=$oracle.sequencePath;PackageSha256=$expectedDigest}};Save-Record
    Assert ($result.sourceBinding[0].ProducerTrust -ceq 'VERIFIED_LOCAL' -and $result.sourceBinding[0].PackageSha256 -ceq $expectedDigest) 'SDK_BYTES_TO_VERIFIED_MODEL'
    Assert ($result.runtimeBinding[0].StatusCode -ceq 'RUNTIME_BOUND_CAPTURE' -and $result.runtimeBinding[0].RootObservationQualified -and $result.runtimeBinding[0].MappedRowCount -eq 2) 'REAL_MODEL_EXECUTION_CORRELATION'
    foreach($item in @(@{Guid=$oracle.packageDtsId;Node='pkg1'},@{Guid=$oracle.sequenceDtsId;Node='exe1'})) {
        $row=@($result.executionCorrelation|Where-Object {([guid]$_.ExecutableGuid).ToString('D') -ceq $item.Guid})
        Assert ($row.Count -eq 1 -and $row[0].ModelNodeId -ceq $item.Node -and $row[0].CorrelationStatus -ceq 'EXACT_GUID_AND_PATH') ('NATIVE_NODE_'+$item.Node)
    }
    $record.Phase='REDEPLOY_OWN_PROJECT'
    $changedOracle=& $FixtureBuilderPath $record.ProjectName 'SQLServer2025' --oracle|ConvertFrom-Json
    if($LASTEXITCODE -ne 0){throw 'SSIS_NATIVE_SECOND_SDK_AUTHOR_FAILED'}
    $previousLsn=$record.ProjectLsn
    $changed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT object_version_lsn FROM catalog.projects WHERE project_id=@projectId;" @{projectId=$record.ProjectId;folderId=$record.FolderId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;bytes=[Convert]::FromBase64String($changedOracle.ispacBase64)}
    $record.ProjectLsn=[long]$changed.ResultSets[0].Rows[0][0];Save-Record
    Assert ($record.ProjectLsn -ne $previousLsn) 'REAL_PROJECT_VERSION_CHANGED'
    $unproven=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    Assert ($unproven.Status -ceq 'RUNTIME_BINDING_UNPROVEN' -and $unproven.ReasonCode -ceq 'EXECUTION_PROJECT_VERSION_UNAVAILABLE') 'NO_CURRENT_BYTES_FOR_HISTORICAL_EXECUTION'
    Assert ((Read-Analysis $handover).runtimeBinding[0].StatusCode -ceq 'RUNTIME_BOUND_CAPTURE') 'PRIOR_CAPTURE_REMAINS_AS_OF_EVIDENCE'
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
    if($cleanupErrors.Count -gt 0){throw 'SSIS_NATIVE_CLEANUP_UNCONFIRMED_ENTIRE_OWN_RUN_RECOVERY_REQUIRED'}
}
Write-Output "SSIS_CATALOG_NATIVE_PASS cases=$($counter.Value); SDK-authored GUID/path/bytes oracle, real execution and redeployment, own object cleanup confirmed. Entire lab cleanup remains with caller."
