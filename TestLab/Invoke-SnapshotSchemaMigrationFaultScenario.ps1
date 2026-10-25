[CmdletBinding()]
param([ValidateSet('2019','2022','2025')][string]$Version='2025',[string]$LabRepositoryRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$analysisRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$labRoot=Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$resolved=& (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
if (-not $resolved.Available) { throw 'OWNED_SNAPSHOT_DOCKER_NOT_RESOLVED' }
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot=Assert-AnalyzePathUnderRoot -Path (Join-Path $tempRoot ('SQL_Server_Analyze/snapshot-lock-'+[guid]::NewGuid().ToString('N'))) -AllowedRoot $tempRoot
[IO.Directory]::CreateDirectory($stateRoot)|Out-Null
$saPassword=New-AnalyzeExampleSecret
$lab=$null; $main=$null; $holder=$null; $credentialPassword=$null; $workerCleanupError=$null; $result=$null
$script:SnapshotFaultMessages=[Collections.Generic.List[string]]::new()
try {
    $lab=New-SqlServerLab -Version $Version -Provider docker -Profile standard -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword -StateRoot $stateRoot -LabName 'analyze-snapshot-lock' -NonInteractive
    $endpoint=Get-AnalyzeLabConnection -RunId $lab.RunId -StateRoot $stateRoot
    $csb=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $csb['Data Source']="tcp:$($endpoint.host),$($endpoint.port)"
    $csb['Initial Catalog']='master'; $csb['Encrypt']=$true; $csb['TrustServerCertificate']=$true; $csb['Connect Timeout']=30
    $credentialPassword=$saPassword.Copy(); $credentialPassword.MakeReadOnly()
    $main=[System.Data.SqlClient.SqlConnection]::new($csb.ConnectionString,[System.Data.SqlClient.SqlCredential]::new('sa',$credentialPassword))
    $main.Open()
    $main.add_InfoMessage({ param($sender,$eventArgs) $script:SnapshotFaultMessages.Add($eventArgs.Message) })
    function Invoke-ProbeSql([string]$Sql) {
        $c=$main.CreateCommand(); $c.CommandText=$Sql; $c.CommandTimeout=30
        try { return $c.ExecuteScalar() } finally { $c.Dispose() }
    }
    $null=Invoke-ProbeSql @'
IF DB_ID(N'ExampleSnapshotSchemaFault') IS NOT NULL THROW 57400,N'Own probe name already occupied.',1;
CREATE DATABASE [ExampleSnapshotSchemaFault];
'@
    $main.ChangeDatabase('ExampleSnapshotSchemaFault')
    $source=[IO.File]::ReadAllText((Join-Path $analysisRoot 'Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql'),[Text.Encoding]::UTF8) -replace '\r\n',[string][char]10
    $separators=[regex]::Matches($source,'(?m)^GO\s*$')
    if ($separators.Count -ne 1 -or $source.Substring($separators[0].Index+$separators[0].Length).Trim().Length -ne 0) { throw 'SNAPSHOT_FAULT_EXPECTS_ONE_CANONICAL_BATCH' }
    $source=$source.Substring(0,$separators[0].Index)
    $sourceHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($source))).ToLowerInvariant()
    $null=Invoke-ProbeSql $source
    # Reconstruct the exact V1 domains only in this new owned lab.
    $null=Invoke-ProbeSql "ALTER TABLE snapshot.CollectorPolicy DROP CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode; ALTER TABLE snapshot.CollectorPolicy WITH CHECK ADD CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode CHECK(CollectorCode='PERFORMANCE_COUNTERS'); ALTER TABLE snapshot.Scope DROP CONSTRAINT CK_snapshot_Scope_ScopeType; ALTER TABLE snapshot.Scope WITH CHECK ADD CONSTRAINT CK_snapshot_Scope_ScopeType CHECK(ScopeType IN('SERVER','PERFORMANCE_COUNTER')); UPDATE snapshot.PackageVersion SET PackageVersion='1.0.0',SchemaVersion=1;"
    $fixture=[IO.File]::ReadAllText((Join-Path $analysisRoot 'Code/Tests/Integration/Deployment_Filled_Target.sql'),[Text.Encoding]::UTF8).Replace('USE [DeineDatenbank];','USE [ExampleSnapshotSchemaFault];')
    foreach ($batch in [regex]::Split($fixture,'(?m)^GO\s*$')) { if ($batch.Trim()) { $null=Invoke-ProbeSql $batch } }
    $tables=@('PackageVersion','RetentionPolicy','CollectorPolicy','CaptureRun','ModuleStatus','Scope','MetricDefinition','MetricSample','PayloadSnapshot','PurgeRun')
    $parts=foreach ($table in $tables) { "JSON_QUERY((SELECT * FROM snapshot.[$table] ORDER BY 1 FOR JSON PATH,INCLUDE_NULL_VALUES)) AS [$table]" }
    $stateSql='SELECT '+[string]::Join(',',$parts)+",JSON_QUERY((SELECT object_id,name,definition,is_disabled,is_not_trusted,is_not_for_replication FROM sys.check_constraints WHERE schema_id=SCHEMA_ID(N'snapshot') ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS checks FOR JSON PATH,WITHOUT_ARRAY_WRAPPER;"
    $before=[string](Invoke-ProbeSql $stateSql)
    $null=Invoke-ProbeSql @'
CREATE FUNCTION dbo.ExampleHoldSchema() RETURNS int AS
BEGIN
    DECLARE @Until datetime2(7)=DATEADD(second,20,SYSUTCDATETIME()),@N bigint=0;
    WHILE SYSUTCDATETIME()<@Until SET @N=@N+1;
    RETURN 1;
END;
'@
    $holderPath=Join-Path $stateRoot 'holder.sql'
    [IO.File]::WriteAllText($holderPath,@'
USE [ExampleSnapshotSchemaFault];
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT ScopeId,dbo.ExampleHoldSchema() FROM snapshot.Scope WITH(NOLOCK)
OPTION(MAXDOP 1,USE HINT('DISABLE_TSQL_SCALAR_UDF_INLINING'));
'@,[Text.UTF8Encoding]::new($false))
    $holder=Start-AnalyzeSqlWorkerTask -ScriptPath $holderPath -HostName ([string]$endpoint.host) -Port ([int]$endpoint.port) -SaPassword $saPassword -ScenarioId 'snapshot-sch-s-probe' -LabRunId $lab.RunId
    $holderId=[int](Invoke-ProbeSql "SELECT session_id FROM sys.dm_exec_sessions WHERE context_info=CONVERT(binary(128),HASHBYTES('SHA2_256',CONCAT('$($lab.RunId)','|','snapshot-sch-s-probe')));")
    if ($holderId -le 50) { throw 'SCH_S_OWNED_SESSION_BINDING_MISSING' }
    $until=[DateTime]::UtcNow.AddSeconds(8); $observed=0
    do {
        $observed=[int](Invoke-ProbeSql "SELECT COUNT(*) FROM sys.dm_tran_locks WHERE request_session_id=$holderId AND resource_type='OBJECT' AND resource_database_id=DB_ID() AND resource_associated_entity_id=OBJECT_ID(N'snapshot.Scope') AND request_mode='Sch-S' AND request_status='GRANT';")
        if ($observed -eq 0) { Start-Sleep -Milliseconds 100 }
    } while ($observed -eq 0 -and [DateTime]::UtcNow -lt $until -and -not $holder.Task.IsCompleted)
    if ($observed -lt 1) { throw 'SCH_S_PROBE_NOT_OBSERVED' }
    $dataLocks=[int](Invoke-ProbeSql "SELECT COUNT(*) FROM sys.dm_tran_locks WHERE request_session_id=$holderId AND resource_database_id=DB_ID() AND resource_type IN('KEY','PAGE','RID','HOBT') AND request_status='GRANT';")
    if ($dataLocks -ne 0) { throw 'SCH_S_PROBE_DATA_LOCKS_PRESENT' }
    $script:SnapshotFaultMessages.Clear()
    $command=$main.CreateCommand(); $command.CommandTimeout=30
    $command.CommandText="BEGIN TRY EXEC sys.sp_executesql @Source; THROW 57421,N'Expected native Scope DDL timeout.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>1222 THROW; END CATCH; IF @@TRANCOUNT<>0 THROW 57422,N'Fault left an active transaction.',1;"
    $null=$command.Parameters.Add('@Source',[System.Data.SqlDbType]::NVarChar,-1)
    $command.Parameters['@Source'].Value=$source
    try { $null=$command.ExecuteNonQuery() } finally { $command.Dispose() }
    if (@($script:SnapshotFaultMessages | Where-Object { $_ -match 'SNAPSHOT_SCHEMA_MIGRATION_FAILED CompletedStage=1 NativeError=1222' }).Count -ne 1) { throw 'SNAPSHOT_FAULT_FIRST_DDL_STAGE_NOT_PROVEN' }
    $after=[string](Invoke-ProbeSql $stateSql)
    if ($before -cne $after) { throw 'SNAPSHOT_FAULT_ROLLBACK_CHANGED_DATA_OR_CHECKS' }
    $holder.Task.GetAwaiter().GetResult()|Out-Null
    $null=Invoke-ProbeSql $source
    if ([int](Invoke-ProbeSql "SELECT COUNT(*) FROM snapshot.PackageVersion WHERE PackageVersion='1.1.0' AND SchemaVersion=2;") -ne 1) { throw 'SNAPSHOT_FAULT_RECOVERY_FAILED' }
    $result=[ordered]@{result='PASS';scope='Canonical migration fault after first CHECK replacement, all10 data/check rollback, recovery';target=$Version;product_version=[string](Invoke-ProbeSql "SELECT CONVERT(varchar(128),SERVERPROPERTY('ProductVersion'));");canonical_batch_sha256=$sourceHash;completed_stage=1;native_error=1222;cleanup='PENDING'}
}
finally {
    if ($holder) {
        try { if (-not $holder.Task.IsCompleted) { $holder.Task.GetAwaiter().GetResult()|Out-Null } } catch { $workerCleanupError=$_ } finally { $holder.Command.Dispose(); $holder.Connection.Dispose() }
    }
    if ($main) { $main.Dispose() }
    if ($credentialPassword) { $credentialPassword.Dispose() }
    if ($lab) {
        $cleanup=Remove-SqlServerLab -RunId $lab.RunId -StateRoot $stateRoot -Force -Confirm:$false
        if ($cleanup.Status -ne 'REMOVED') { throw 'OWNED_SNAPSHOT_LAB_RECOVERY_REQUIRED' }
        if ($result) { $result.cleanup='PASS' }
        $verifiedRoot=Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $tempRoot
        Remove-Item -LiteralPath $verifiedRoot -Recurse -Force -ErrorAction Stop
    }
    if ($workerCleanupError) { throw $workerCleanupError }
}

if ($result) { $result | ConvertTo-Json -Compress }
