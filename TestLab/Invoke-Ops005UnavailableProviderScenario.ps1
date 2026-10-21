#Requires -Version 7.2
<#
.SYNOPSIS
    Führt die begrenzte OPS-005-Abnahme auf genau einem eigenen Windows-Run aus.
.DESCRIPTION
    Benötigt geprüfte private Eingaben und einen erhöhten Windows-Prozess.
    Ein vorhandenes Prepared-Image und ein bestehender interner Switch werden
    verwendet. Allgemeine Provisionierung und Entfernung bleiben bei Lab.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabRepositoryRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string]$ExpectedLabHead,
    [Parameter(Mandatory)][string]$ExpectedUserSid,
    [Parameter(Mandatory)][string]$PreparedDirectory,
    [Parameter(Mandatory)][string]$StateRoot,
    [Parameter(Mandatory)][ValidatePattern('^hyperv-sql-prepared-sealed-[a-f0-9]{64}$')][string]$ArtifactId,
    [Parameter(Mandatory)][string]$ParentVhdxPath,
    [Parameter(Mandatory)][string]$ExistingSwitchName,
    [Parameter(Mandatory)][string]$ReservationPath,
    [Parameter(Mandatory)][switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not $Execute) { throw 'OPS005_EXPLICIT_EXECUTION_REQUIRED' }
$principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'OPS005_ELEVATED_RUNNER_REQUIRED' }
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -cne $ExpectedUserSid) { throw 'OPS005_HOST_USER_CHANGED' }
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$work=[IO.Path]::GetFullPath($PreparedDirectory)
$labRoot=[IO.Path]::GetFullPath($LabRepositoryRoot)
$stateRoot=[IO.Path]::GetFullPath($StateRoot)
$reservation=[IO.Path]::GetFullPath($ReservationPath)
foreach ($privatePath in @($work,$reservation)) {
    if ($privatePath.StartsWith($repositoryRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'OPS005_PRIVATE_EVIDENCE_REQUIRED'
    }
}
if (Test-Path -LiteralPath $reservation) { throw 'OPS005_WAVE_ATTEMPT_ALREADY_RESERVED' }
$binding=Get-Content -LiteralPath (Join-Path $work 'preparation.json') -Raw | ConvertFrom-Json -Depth 12
$operation=[guid]$binding.OperationId
if ($operation -eq [guid]::Empty -or $binding.Scope -cne 'OPS005_WINDOWS_PROVIDER_PREPARATION' -or $binding.Outcome -cne 'NOT_EXECUTED') {
    throw 'OPS005_PREPARATION_INVALID'
}
$head=(& git -C $repositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -cne $binding.SourceHead -or @(& git -C $repositoryRoot status --porcelain).Count) {
    throw 'OPS005_CLEAN_SOURCE_BINDING_REQUIRED'
}
$labHead=(& git -C $labRoot rev-parse HEAD).Trim()
$labMain=(& git -C $labRoot ls-remote origin refs/heads/main).Split("`t")[0]
if ($LASTEXITCODE -ne 0 -or $labHead -cne $ExpectedLabHead -or $labHead -cne $labMain -or (& git -C $labRoot branch --show-current).Trim() -cne 'main' -or
    @(& git -C $labRoot status --porcelain).Count) { throw 'OPS005_CLEAN_INTEGRATED_LAB_REQUIRED' }
foreach ($inputFile in @($binding.Inputs)) {
    if ($inputFile.Name -cnotmatch '^[a-z0-9-]+\.sql$') { throw 'OPS005_INPUT_NAME_INVALID' }
    $path=Join-Path $work $inputFile.Name
    if ((Get-Item -LiteralPath $path).Length -ne $inputFile.Bytes -or
        (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $inputFile.Sha256) { throw 'OPS005_INPUT_CHANGED' }
}
foreach ($source in @($binding.CanonicalSources)) {
    if ($source.Path -cnotmatch '^Code/[A-Za-z0-9_/-]+\.sql$' -or $source.Path.Contains('..')) { throw 'OPS005_CANONICAL_SOURCE_PATH_INVALID' }
    if ((Get-FileHash -LiteralPath (Join-Path $repositoryRoot $source.Path) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $source.Sha256) {
        throw 'OPS005_CANONICAL_SOURCE_CHANGED'
    }
}
$verification=Join-Path $work ('dispatch-verification-'+[guid]::NewGuid().ToString('N'))
$null=& (Join-Path $PSScriptRoot 'Prepare-Ops005UnavailableProvider.ps1') -OutputDirectory $verification -OperationId $operation
$fresh=Get-Content -LiteralPath (Join-Path $verification 'preparation.json') -Raw | ConvertFrom-Json -Depth 12
if (@($binding.Inputs).Count -ne @($fresh.Inputs).Count -or $binding.ExpectedDefinitionSha256 -cne $fresh.ExpectedDefinitionSha256 -or
    $binding.CanonicalSourceCount -ne $fresh.CanonicalSourceCount) { throw 'OPS005_PREPARATION_NOT_CANONICAL' }
for($i=0;$i -lt @($fresh.Inputs).Count;$i++) {
    if ($binding.Inputs[$i].Name -cne $fresh.Inputs[$i].Name -or $binding.Inputs[$i].Sha256 -cne $fresh.Inputs[$i].Sha256 -or
        $binding.Inputs[$i].Bytes -ne $fresh.Inputs[$i].Bytes) { throw 'OPS005_PREPARATION_NOT_CANONICAL' }
}
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1')
$mutex=[Threading.Mutex]::new($false,'Global\SQL_Server_Lab_Runtime_Smoke')
$locked=$false; $started=$false; $runBinding=$null; $databaseBinding=$null; $childPath=$null; $primaryFailure=$null
$report=[ordered]@{Scope='OPS005_WINDOWS_PROVIDER_ACCEPTANCE';Outcome='NOT_EXECUTED';SourceHead=$head;LabHead=$labHead;
    NewRuns=0;NativeBlocks=0;SutCalls=0;Preprobes=0;DatabaseCleanup='NOT_CREATED';RunCleanup='NOT_CREATED';NetworkLeaseCleanup='NOT_CREATED';ParentIntegrity='NOT_CHECKED'}
$resultPath=Join-Path $work 'result.json'
function Save-PrivateReport { $report | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $resultPath -Encoding utf8NoBOM }
function Assert-DispatchSources {
    $current=(& git -C $repositoryRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $current -cne $head -or @(& git -C $repositoryRoot status --porcelain).Count) { throw 'OPS005_ANALYZE_SOURCE_DRIFT' }
    $current=(& git -C $labRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $current -cne $labHead -or @(& git -C $labRoot status --porcelain).Count) { throw 'OPS005_LAB_SOURCE_DRIFT' }
}
function Read-OwnRun {
    param([string]$RunId)
    $path=Join-Path (Join-Path $stateRoot 'runs') (Join-Path $RunId 'run-state.json')
    $state=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 25
    if ($state.runId -cne $RunId -or $state.metadata.name -cne $labName -or $state.metadata.imageArtifactId -cne $ArtifactId -or
        $state.metadata.workflowKind -cne 'hyperv-lab' -or $state.metadata.networkIntent -cne 'hostOnly' -or
        [guid]$state.scopeId -eq [guid]::Empty -or [datetime]$state.createdAt -lt $attemptStart -or $RunId -cin $baselineIds) {
        throw 'OPS005_RUN_OWNERSHIP_LOST'
    }
    if ($runBinding -and ($runBinding.RunId -cne $state.runId -or $runBinding.ScopeId -cne $state.scopeId)) { throw 'OPS005_RUN_BINDING_CHANGED' }
    if ($runBinding -and $runBinding.ContainsKey('VmId')) {
        $boundVm=Get-VM -Id ([guid]$runBinding.VmId)
        if (-not ([string]$boundVm.Notes).StartsWith('SQL_SERVER_LAB:',[StringComparison]::Ordinal)) { throw 'OPS005_VM_IDENTITY_MISSING' }
        $boundNotes=([string]$boundVm.Notes).Substring('SQL_SERVER_LAB:'.Length)|ConvertFrom-Json -Depth 12
        if ($boundNotes.runId -cne $state.runId -or $boundNotes.scopeId -cne $state.scopeId -or
            $boundNotes.instanceId -cne 'primary' -or $boundNotes.childVhdxPath -ine $childPath) { throw 'OPS005_VM_BINDING_CHANGED' }
    }
    return $state
}
function Invoke-OwnSql {
    param([string]$Name,[string]$Database,[hashtable]$Parameters,[int]$TimeoutSeconds)
    $null=Read-OwnRun $runBinding.RunId
    if ($Name -cne 'cleanup-database.sql') { Assert-DispatchSources }
    $expected=@($binding.Inputs|Where-Object Name -ceq $Name)
    if ($expected.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $work $Name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected[0].Sha256) {
        throw 'OPS005_DISPATCH_INPUT_CHANGED'
    }
    $result=Invoke-SqlServerLabScript -RunId $runBinding.RunId -InstanceId primary -StateRoot $stateRoot -WindowsAuthentication `
        -KeepConnection -ScriptPath (Join-Path $work $Name) -Database $Database -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds
    $result | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $work ($Name+'.result.json')) -Encoding utf8NoBOM
    if ($result.Success -isnot [bool] -or -not $result.Success -or $result.Outcome -cne 'SUCCEEDED' -or
        $result.RunId -cne $runBinding.RunId -or $result.InstanceId -cne 'primary' -or $result.Authentication -cne 'Windows') {
        throw ('OPS005_SQL_NOT_QUALIFIED: '+$Name)
    }
    return $result
}
function Get-OneRow {
    param($Result)
    if (@($Result.ResultSets).Count -ne 1 -or @($Result.ResultSets[0].Rows).Count -ne 1) { throw 'OPS005_RESULT_SHAPE_INVALID' }
    $row=@($Result.ResultSets[0].Rows)[0];$values=@{}
    if (@($row).Count -ne @($Result.ResultSets[0].Columns).Count) { throw 'OPS005_RESULT_SHAPE_INVALID' }
    for($i=0;$i -lt @($row).Count;$i++) { $values[[string]$Result.ResultSets[0].Columns[$i]]=$row[$i] }
    return $values
}
try {
    try { $locked=$mutex.WaitOne([TimeSpan]::FromSeconds(60)) } catch [Threading.AbandonedMutexException] { $locked=$true }
    if (-not $locked) { throw 'OPS005_HOST_RUNTIME_BUSY' }
    $inventory=@(Get-SqlServerLabHyperVImageArtifact -ArtifactId $ArtifactId -StateRoot $stateRoot)
    if ($inventory.Count -ne 1 -or $inventory[0].ArtifactState -cne 'SQL_PREPARED_SEALED' -or $inventory[0].Sql.Version -cne '2025' -or
        $inventory[0].Sql.LicenseType -cne 'developer' -or -not $inventory[0].ManifestFallback.Eligible -or
        $inventory[0].Evaluation.Status -cne 'EVALUATION_VALID') { throw 'OPS005_PREPARED_IMAGE_NOT_ADMITTED' }
    $parent=Get-Item -LiteralPath $ParentVhdxPath -Force
    $parentHash=(Get-FileHash -LiteralPath $parent.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not $parent.IsReadOnly -or -not $ArtifactId.EndsWith($parentHash,[StringComparison]::Ordinal)) { throw 'OPS005_PARENT_INTEGRITY_FAILED' }
    $parentVhd=Get-VHD -Path $parent.FullName
    $preview=Get-SqlServerLabHyperVResourcePreview -ResourceClass Run
    $runRoot=[IO.Path]::GetFullPath([string]@($preview.Targets | Where-Object ResourceClass -eq 'Run')[0].ClassRoot)
    $free=[long](Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory*1KB
    if ($free -lt 16GB -or $preview.ObservedFreeBytes -lt ([long]$parentVhd.Size+16GB)) { throw 'OPS005_HOST_CAPACITY_INSUFFICIENT' }
    $switch=Get-VMSwitch -Name $ExistingSwitchName
    if ([string]$switch.SwitchType -cne 'Internal' -or @($switch).Count -ne 1) { throw 'OPS005_EXISTING_INTERNAL_SWITCH_REQUIRED' }
    $labName='ops005-provider-'+$operation.ToString('N')
    $manifest=@{name=$labName;automation=@{mode='unattended'};instances=@(@{
        id='primary';version='2025';provider='hyperv';os='windows';profile='standard';autostart='off'
        collation='SQL_Latin1_General_CP1_CS_AS';network=@{intent='hostOnly';exposure='host'}
        windowsActivation=@{ContractVersion='SqlServerLab.WindowsActivationIntent/1.0';Strategy='NotRequested';EgressPolicy='Denied'}
        windowsLocale=@{ContractVersion='SqlServerLab.WindowsLocaleIntent/1.0';Region='US';SystemLocale='en-US';UiLanguage='en-US';InputLocale='0409:00000409';TimeZone='W. Europe Standard Time'}
        hyperv=@{preparedImageId=$ArtifactId;switchName=$ExistingSwitchName;memoryStartupMB=8192;dynamicMemoryEnabled=$false;processorCount=4;sqlPort=1433;guestPasswordMode='prompt'}
    })}
    $manifestPath=Join-Path $work 'manifest.json'
    $manifest|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $manifestPath -Encoding utf8NoBOM
    if (-not (Test-SqlServerLabManifest -Path $manifestPath).IsValid) { throw 'OPS005_MANIFEST_INVALID' }
    $baselineIds=@(Get-ChildItem -LiteralPath (Join-Path $stateRoot 'runs') -Directory | Select-Object -ExpandProperty Name)
    $attemptStart=[datetime]::UtcNow
    Assert-DispatchSources
    $stream=[IO.File]::Open($reservation,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $bytes=[Text.Encoding]::UTF8.GetBytes((@{OperationId=$operation.ToString('D');SourceHead=$head;LabHead=$labHead;StartedAt=$attemptStart.ToString('o')}|ConvertTo-Json));$stream.Write($bytes,0,$bytes.Length) } finally {$stream.Dispose()}
    $started=$true; $report.NewRuns=1; $report.NativeBlocks=1; $report.Outcome='IN_PROGRESS'; Save-PrivateReport
    $guest=New-AnalyzeExampleSecret; $sa=New-AnalyzeExampleSecret
    try { $created=New-SqlServerLab -Manifest $manifestPath -GuestPassword $guest -SqlSaPassword $sa -StateRoot $stateRoot -NonInteractive -RequireExistingHyperVNetwork }
    finally { $guest=$null; $sa=$null }
    $state=Read-OwnRun ([string]$created.RunId)
    $runBinding=@{RunId=[string]$state.runId;ScopeId=[string]$state.scopeId}
    $report.RunBinding=$runBinding
    $connection=Get-Content -LiteralPath (Join-Path $stateRoot ('runs/'+$runBinding.RunId+'/connection-info.json')) -Raw | ConvertFrom-Json -Depth 30
    if (@($connection.instances).Count -ne 1) { throw 'OPS005_INSTANCE_BINDING_INVALID' }
    $instance=$connection.instances[0]
    if ($instance.id -cne 'primary' -or $instance.imageArtifactId -cne $ArtifactId -or $instance.sqlCollationIntent -cne 'SQL_Latin1_General_CP1_CS_AS' -or
        $instance.sqlCompletion.collation.Status -cne 'VERIFIED' -or $instance.sqlCompletion.state -cne 'COMPLETE' -or
        $instance.sqlCompletion.sqlReadiness.status -cne 'SQL_READY_RUN') { throw 'OPS005_SQL_READY_COLLATION_REQUIRED' }
    if ($instance.sqlCompletion.collation.RunId -cne $runBinding.RunId -or $instance.sqlCompletion.collation.ScopeId -cne $runBinding.ScopeId -or
        $instance.sqlCompletion.collation.InstanceId -cne 'primary' -or -not $instance.sqlCompletion.collation.CatalogAvailable -or
        $instance.sqlCompletion.sqlReadiness.majorVersion -ne 17 -or $instance.sqlCompletion.sqlReadiness.instanceName -cne 'MSSQLSERVER' -or
        $instance.labNetwork.intent -cne 'hostOnly' -or -not [string]::IsNullOrWhiteSpace([string]$instance.labNetwork.gateway)) { throw 'OPS005_NATIVE_EVIDENCE_BINDING_MISMATCH' }
    foreach($field in @('ExpectedCollation','ActualCollation','MasterCollation','TempdbCollation')) {
        if ($instance.sqlCompletion.collation.$field -cne 'SQL_Latin1_General_CP1_CS_AS') { throw 'OPS005_COLLATION_EVIDENCE_MISMATCH' }
    }
    $vm=Get-VM -Id ([guid]$instance.vmId)
    if (-not ([string]$vm.Notes).StartsWith('SQL_SERVER_LAB:',[StringComparison]::Ordinal)) { throw 'OPS005_VM_IDENTITY_MISSING' }
    $notes=([string]$vm.Notes).Substring('SQL_SERVER_LAB:'.Length)|ConvertFrom-Json -Depth 12
    $childPath=[IO.Path]::GetFullPath([string]$notes.childVhdxPath)
    if ($notes.runId -cne $runBinding.RunId -or $notes.scopeId -cne $runBinding.ScopeId -or $notes.instanceId -cne 'primary' -or
        -not $childPath.StartsWith($runRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or @($notes.additionalVhdxPaths).Count) { throw 'OPS005_VM_SCOPE_CHANGED' }
    $runBinding.VmId=[string]$vm.Id
    $memory=Get-VMMemory -VM $vm; $processor=Get-VMProcessor -VM $vm
    $disks=@(Get-VMHardDiskDrive -VM $vm);$adapters=@(Get-VMNetworkAdapter -VM $vm)
    if ($memory.DynamicMemoryEnabled -or $memory.Startup -ne 8GB -or $processor.Count -ne 4 -or $disks.Count -ne 1 -or
        $disks[0].Path -ine $childPath -or (Get-VHD -Path $childPath).ParentPath -ine $parent.FullName -or
        $adapters.Count -ne 1 -or $adapters[0].SwitchId -ne $switch.Id) { throw 'OPS005_VM_RESOURCE_BINDING_MISMATCH' }
    $ipamPath=Join-Path $stateRoot 'network/hyperv-ipam.json'
    $leases=Get-Content -LiteralPath $ipamPath -Raw|ConvertFrom-Json -Depth 12
    if (@($leases.leases|Where-Object {$_.runId -ceq $runBinding.RunId -and $_.scopeId -ceq $runBinding.ScopeId -and $_.state -ceq 'ACTIVE'}).Count -ne 1) {
        throw 'OPS005_NETWORK_LEASE_BINDING_REQUIRED'
    }
    $report.NetworkLeaseCleanup='PENDING';$report.DatabaseCleanup='CREATION_UNCONFIRMED'; Save-PrivateReport
    $prepared=Get-OneRow (Invoke-OwnSql 'prepare-database.sql' 'master' @{OperationId=$operation.ToString('D')} 300)
    $databaseBinding=@{OwnDatabaseId=[int]$prepared.OwnDatabaseId;OwnDatabaseCreated=[string]$prepared.OwnDatabaseCreated;OperationId=$operation.ToString('D')}
    $report.DatabaseCleanup='PENDING';$report.ProductVersion=$prepared.ProductVersion;$report.Edition=$prepared.Edition
    $watch=[Diagnostics.Stopwatch]::StartNew()
    foreach($part in @($binding.Inputs | Where-Object Name -match '^install-\d+\.sql$' | Sort-Object Name)) {
        $remaining=300-[int][math]::Ceiling($watch.Elapsed.TotalSeconds)
        if ($remaining -lt 5) { throw 'OPS005_INSTALLATION_DEADLINE' }
        $null=Invoke-OwnSql $part.Name 'LabAnalyze' @{} $remaining
    }
    $report.SutCalls='UNKNOWN_0_TO_5';$report.Preprobes='UNKNOWN_0_TO_1';Save-PrivateReport
    $accepted=Get-OneRow (Invoke-OwnSql 'provider-unavailable.sql' 'LabAnalyze' @{
        OperationId=$operation.ToString('D');ExpectedDefinitionHash=[Convert]::FromHexString($binding.ExpectedDefinitionSha256)} 120)
    if ($accepted.Scope -cne 'OPS005_PROVIDER_ACCEPTANCE' -or $accepted.Outcome -cne 'PASSED' -or $accepted.SutCalls -ne 5 -or
        $accepted.Preprobes -ne 1 -or $accepted.NativeError -notin @(7302,7403) -or $accepted.FixtureCleanup -cne 'REMOVED') { throw 'OPS005_ACCEPTANCE_INCOMPLETE' }
    $report.SutCalls=5;$report.Preprobes=1;$report.Acceptance=$accepted;$report.Outcome='ACCEPTANCE_PASSED_CLEANUP_PENDING'
}
catch { $primaryFailure=$_; $report.Outcome=if($started){'FAILED'}else{'BLOCKED'};$report.Error=$_.Exception.Message }
finally {
    if ($started -and -not $runBinding) {
        try {
            $candidates=@(Get-ChildItem -LiteralPath (Join-Path $stateRoot 'runs') -Directory | Where-Object {$_.Name -cnotin $baselineIds} | ForEach-Object {
                $s=Get-Content -LiteralPath (Join-Path $_.FullName 'run-state.json') -Raw | ConvertFrom-Json -Depth 25
                if ($s.metadata.name -ceq $labName -and $s.metadata.imageArtifactId -ceq $ArtifactId -and [datetime]$s.createdAt -ge $attemptStart) { $s }
            })
            if ($candidates.Count -eq 1) { $state=Read-OwnRun $candidates[0].runId;$runBinding=@{RunId=[string]$state.runId;ScopeId=[string]$state.scopeId} }
            else { $report.RunCleanup='RECOVERY_REQUIRED' }
        } catch { $report.RunCleanup='RECOVERY_REQUIRED';$report.RecoveryError=$_.Exception.Message }
    }
    if ($databaseBinding -and $runBinding) {
        try { $null=Invoke-OwnSql 'cleanup-database.sql' 'master' $databaseBinding 60;$report.DatabaseCleanup='REMOVED' }
        catch { $report.DatabaseCleanup='RECOVERY_REQUIRED';$report.DatabaseCleanupError=$_.Exception.Message }
    }
    if ($runBinding) {
        try {
            $null=Read-OwnRun $runBinding.RunId
            $removed=Remove-SqlServerLab -RunId $runBinding.RunId -StateRoot $stateRoot -Force -Confirm:$false
            if ($removed.Status -cne 'REMOVED' -or $removed.Errors -ne 0 -or ($childPath -and (Test-Path -LiteralPath $childPath)) -or
                ($runBinding.ContainsKey('VmId') -and (Get-VM -Id ([guid]$runBinding.VmId) -ErrorAction SilentlyContinue))) { throw 'OPS005_RUN_CLEANUP_NOT_PROVEN' }
            $ipamPath=Join-Path $stateRoot 'network/hyperv-ipam.json'
            if (Test-Path -LiteralPath $ipamPath) {
                $leases=Get-Content -LiteralPath $ipamPath -Raw|ConvertFrom-Json -Depth 12
                if (@($leases.leases|Where-Object {$_.runId -ceq $runBinding.RunId -and $_.state -ceq 'ACTIVE'}).Count) { throw 'OPS005_NETWORK_LEASE_NOT_RELEASED' }
            }
            $report.NetworkLeaseCleanup='NO_ACTIVE_OWN_LEASE'
            $report.RunCleanup='REMOVED'
        } catch { $report.RunCleanup='RECOVERY_REQUIRED';$report.RunCleanupError=$_.Exception.Message }
    }
    if ($started) {
        try {
            if (-not (Get-Item -LiteralPath $ParentVhdxPath -Force).IsReadOnly -or
                (Get-FileHash -LiteralPath $ParentVhdxPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $parentHash) { throw 'OPS005_PARENT_CHANGED' }
            $report.ParentIntegrity='UNCHANGED'
        } catch { $report.ParentIntegrity='NOT_PROVEN';$report.ParentError=$_.Exception.Message }
    }
    if ($report.Outcome -ceq 'ACCEPTANCE_PASSED_CLEANUP_PENDING' -and $report.DatabaseCleanup -ceq 'REMOVED' -and
        $report.RunCleanup -ceq 'REMOVED' -and $report.NetworkLeaseCleanup -ceq 'NO_ACTIVE_OWN_LEASE' -and $report.ParentIntegrity -ceq 'UNCHANGED') { $report.Outcome='PASSED' }
    elseif ($started -and $report.Outcome -cne 'FAILED') { $report.Outcome='FAILED' }
    Save-PrivateReport
    if ($locked) { $mutex.ReleaseMutex() };$mutex.Dispose()
}
if ($primaryFailure) { throw $primaryFailure }
if ($report.Outcome -cne 'PASSED') { throw 'OPS005_ACCEPTANCE_NOT_QUALIFIED' }
[pscustomobject]@{Scope=$report.Scope;Outcome=$report.Outcome;SutCalls=$report.SutCalls;Preprobes=$report.Preprobes;EvidencePath=$resultPath}
