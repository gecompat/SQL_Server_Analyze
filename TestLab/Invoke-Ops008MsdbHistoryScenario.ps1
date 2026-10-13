[CmdletBinding()]
param(
    [string] $LabRepositoryRoot,
    [ValidateSet('HistoryRestore', 'AgentHistory', 'MailMaintenance', 'AgentExecution', 'AgentRetention', 'AgentCallerOptions', 'BackupRestoreRetention', 'MailRetention', 'MaintenanceRetention', 'MaintenanceDetailRetention', 'MaintenancePlanRetention', 'MaintenanceSubplanRetention', 'MaintenanceFilterBoundary', 'MaintenanceCallerOptions', 'MailCallerOptions', 'MailStatusRetention', 'MailExecutionFailure', 'MailExecutionSuccess', 'MailLogRetention', 'MailAttachmentRetention')]
    [string] $Scenario = 'HistoryRestore'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
if ($Scenario -eq 'MailExecutionSuccess') {
    $publicLabHead = (& git -C $labRoot rev-parse --verify 'refs/remotes/origin/main^{commit}' 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'OPS-008: Die öffentliche Lab-Revision fehlt; SMTP bleibt NOT_EXECUTED.' }
    $selectedLabHead = (& git -C $labRoot rev-parse --verify 'HEAD^{commit}' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $selectedLabHead -cne $publicLabHead) {
        throw 'OPS-008: SMTP erfordert den öffentlichen origin/main-Stand; kein Draft- oder Worktree-Fallback.'
    }
    $selectedLabChanges = @(& git -C $labRoot status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0 -or $selectedLabChanges.Count -ne 0) {
        throw 'OPS-008: Der ausgewählte öffentliche Lab-Arbeitsbaum ist nicht unverändert.'
    }
}
$null = & (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
$labModule = Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force -PassThru
. (Join-Path $labRoot 'Tests/Common/OwnedHostTestScope.ps1')
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot = Assert-AnalyzePathUnderRoot `
    -Path (Join-Path $systemTempRoot ('SQL_Server_Analyze/ops008-history-' + [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
$saPassword = New-AnalyzeExampleSecret
$lab = $null
$runtimeMetadata = $null
$smtpProfileName = $null
$cleanupCompleted = $false
$mutex = [Threading.Mutex]::new($false, 'Global\SQL_Server_Lab_Runtime_Smoke')
$mutexHeld = $false
try {
    try { $mutexHeld = $mutex.WaitOne([TimeSpan]::FromSeconds(45)) }
    catch [Threading.AbandonedMutexException] {
        $mutexHeld = $true
        throw 'OPS-008: Vorheriger Runtime-Test endete ohne Freigabe der Hostlane.'
    }
    if (-not $mutexHeld) { throw 'OPS-008: Eigene Runtime-Testlane ist belegt.' }
    $null = Initialize-OwnedHostTestRoot -Module $labModule -StateRoot $stateRoot `
        -Providers @('docker') -ParentOperationId ([guid]::NewGuid().ToString('N'))
    if ($Scenario -eq 'MailExecutionSuccess') {
        $manifestPath = Join-Path $stateRoot 'smtp-lab-manifest.json'
        $manifest = [ordered]@{
            name = 'analyze-ops008-smtp'
            instances = @([ordered]@{
                id = 'primary'; version = '2025'; provider = 'docker'; os = 'linux'
                profile = 'standard'; collation = 'Latin1_General_100_CS_AS'
            })
            smtpTestService = [ordered]@{ imageProvisioning = 'require-existing' }
        }
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $lab = New-SqlServerLab -Manifest $manifestPath -SaPassword $saPassword `
            -StateRoot $stateRoot -NonInteractive
        $smtpConnectionPath = Join-Path $stateRoot "runs/$($lab.RunId)/connection-info.json"
        if (-not (Test-Path -LiteralPath $smtpConnectionPath -PathType Leaf)) {
            throw 'OPS-008: Der öffentliche SMTP-Verbindungsvertrag fehlt im eigenen Run.'
        }
        $smtpConnection = Get-Content -LiteralPath $smtpConnectionPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
        if ($smtpConnection.runId -cne $lab.RunId -or $smtpConnection.scopeId -cne $lab.ScopeId -or
            -not $smtpConnection.PSObject.Properties['smtpTestService'] -or $null -eq $smtpConnection.smtpTestService -or
            @($smtpConnection.smtpTestService.SenderInstanceIds).Count -ne 1 -or
            [string]$smtpConnection.smtpTestService.SenderInstanceIds[0] -cne 'primary' -or
            [string]::IsNullOrWhiteSpace([string]$smtpConnection.smtpTestService.ProfileName)) {
            throw 'OPS-008: Der öffentliche SMTP-Testdienst lieferte kein Database-Mail-Profil.'
        }
        $smtpProfileName = [string]$smtpConnection.smtpTestService.ProfileName
    }
    else {
        $lab = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
            -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword `
            -StateRoot $stateRoot -LabName 'analyze-ops008-history' -NonInteractive
    }
    Start-Sleep -Seconds 60
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $stateRoot
    foreach ($script in @($framework.Prepare, $framework.Installer)) {
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    }
    $markerFile = Join-Path $stateRoot 'disposable-marker.sql'
    $markerSql = @'
USE [DeineDatenbank];
EXEC sys.sp_addextendedproperty @name=N'SQLANALYZE.Ops008Disposable', @value=1;
'@
    [IO.File]::WriteAllText($markerFile, $markerSql.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
    $null = Invoke-AnalyzeLabScript -ScriptPath $markerFile -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    $scripts = @('Code/Tests/Integration/110_Smoke_Test.sql',
        'Code/Tests/ServerHealth/122_OPS008_Msdb_Health_Runtime_Contract.sql')
    if ($Scenario -eq 'AgentHistory') {
        $scripts += 'TestLab/Scenarios/OPS-008/agent-history.sql'
    }
    elseif ($Scenario -eq 'MailMaintenance') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-maintenance.sql'
    }
    elseif ($Scenario -eq 'AgentExecution') {
        $scripts += 'TestLab/Scenarios/OPS-008/agent-execution.sql'
    }
    elseif ($Scenario -eq 'AgentCallerOptions') {
        $scripts += @('TestLab/Scenarios/OPS-008/agent-execution.sql',
            'TestLab/Scenarios/OPS-008/agent-retention.sql')
    }
    elseif ($Scenario -eq 'AgentRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/agent-retention.sql'
    }
    elseif ($Scenario -eq 'BackupRestoreRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/backup-restore-retention.sql'
    }
    elseif ($Scenario -eq 'MailRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-retention.sql'
    }
    elseif ($Scenario -eq 'MailAttachmentRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-attachment-retention.sql'
    }
    elseif ($Scenario -eq 'MailExecutionFailure') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-execution-failure.sql'
    }
    elseif ($Scenario -eq 'MailExecutionSuccess') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-execution-success.sql'
    }
    elseif ($Scenario -eq 'MailLogRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-log-retention.sql'
    }
    elseif ($Scenario -eq 'MailStatusRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/mail-status-retention.sql'
    }
    elseif ($Scenario -eq 'MailCallerOptions') {
        $scripts += @('TestLab/Scenarios/OPS-008/mail-maintenance.sql',
            'TestLab/Scenarios/OPS-008/mail-retention.sql',
            'TestLab/Scenarios/OPS-008/mail-status-retention.sql',
            'TestLab/Scenarios/OPS-008/mail-attachment-retention.sql')
    }
    elseif ($Scenario -eq 'MaintenanceCallerOptions') {
        $scripts += @('TestLab/Scenarios/OPS-008/maintenance-retention.sql',
            'TestLab/Scenarios/OPS-008/maintenance-detail-retention.sql',
            'TestLab/Scenarios/OPS-008/maintenance-plan-retention.sql',
            'TestLab/Scenarios/OPS-008/maintenance-subplan-retention.sql')
    }
    elseif ($Scenario -eq 'MaintenanceFilterBoundary') {
        $scripts += 'TestLab/Scenarios/OPS-008/maintenance-filter-boundary.sql'
    }
    elseif ($Scenario -eq 'MaintenanceSubplanRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/maintenance-subplan-retention.sql'
    }
    elseif ($Scenario -eq 'MaintenancePlanRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/maintenance-plan-retention.sql'
    }
    elseif ($Scenario -eq 'MaintenanceDetailRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/maintenance-detail-retention.sql'
    }
    elseif ($Scenario -eq 'MaintenanceRetention') {
        $scripts += 'TestLab/Scenarios/OPS-008/maintenance-retention.sql'
    }
    else {
        $scripts += @('TestLab/Scenarios/OPS-008/history-window.sql',
            'TestLab/Scenarios/OPS-008/restore-window.sql')
    }
    foreach ($relative in $scripts) {
        $rendered = Join-Path $stateRoot ([IO.Path]::GetFileName($relative))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relative), [Text.Encoding]::UTF8)
        $content = $content.Replace('[DeineDatenbank]', '[LabAnalyze]')
        if ($Scenario -eq 'MailExecutionSuccess' -and $relative -eq 'TestLab/Scenarios/OPS-008/mail-execution-success.sql') {
            $profileName = $smtpProfileName
            if ($profileName -notmatch '^[A-Za-z0-9_.-]{1,128}$') {
                throw 'OPS-008: Das SMTP-Testprofil enthält keine zulässige technische Kennung.'
            }
            $content = $content.Replace('__SMTP_PROFILE_NAME__', $profileName)
        }
        [IO.File]::WriteAllText($rendered, $content, [Text.UTF8Encoding]::new($false))
        $null = Invoke-AnalyzeLabScript -ScriptPath $rendered -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    }
    $endpoint = Get-AnalyzeLabConnection -RunId $lab.RunId -StateRoot $stateRoot
    $credentialPassword = $saPassword.Copy()
    $credentialPassword.MakeReadOnly()
    $connection = $null
    try {
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
        $builder['Data Source'] = "tcp:$($endpoint.host),$($endpoint.port)"
        $builder['Initial Catalog'] = 'LabAnalyze'
        $builder['Encrypt'] = $true
        $builder['TrustServerCertificate'] = $true
        $builder['Connect Timeout'] = 30
        $credential = [System.Data.SqlClient.SqlCredential]::new('sa', $credentialPassword)
        $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString, $credential)
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 30
        $command.CommandText = @'
SELECT CONVERT(varchar(30), SERVERPROPERTY('ProductVersion')) AS [ProductVersion],
    [compatibility_level] AS [CompatibilityLevel]
FROM [sys].[databases] WHERE [database_id] = DB_ID()
FOR JSON PATH, WITHOUT_ARRAY_WRAPPER;
'@
        try { $runtimeMetadata = [string]$command.ExecuteScalar() | ConvertFrom-Json }
        finally { $command.Dispose() }
        if ($runtimeMetadata.ProductVersion -notmatch '^17\.\d+\.\d+\.\d+$' -or
            $runtimeMetadata.CompatibilityLevel -ne 170) {
            throw 'OPS-008: Die tatsächliche SQL-2025-/CL170-Kombination ist nicht bestätigt.'
        }
    }
    finally {
        try { if ($connection) { $connection.Dispose() } }
        finally { $credentialPassword.Dispose() }
    }
}
finally {
    try {
        if ($lab) {
            try {
                $cleanup = Remove-SqlServerLab -RunId $lab.RunId -StateRoot $stateRoot -Force -Confirm:$false
                $cleanupCompleted = $cleanup.Status -eq 'REMOVED'
            }
            catch { Write-Warning "OPS-008-Cleanup fehlgeschlagen ($($_.Exception.GetType().Name))." }
            if (-not $cleanupCompleted) {
                Write-Warning "Recovery: Remove-SqlServerLab -RunId '$($lab.RunId)' -StateRoot '$stateRoot' -Force -Confirm:`$false"
            }
        }
        else { Write-Warning "Provisionierung unvollständig. Eigener Recovery-State: '$stateRoot'. Get-SqlServerLab -StateRoot '$stateRoot' prüfen." }
        if ($cleanupCompleted) {
            $verifiedRoot = Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $systemTempRoot
            Remove-Item -LiteralPath $verifiedRoot -Recurse -Force
        }
    }
    finally {
        try { if ($mutexHeld) { $mutex.ReleaseMutex() } }
        finally { $mutex.Dispose() }
    }
}
if (-not $cleanupCompleted) { throw 'OPS-008-Cleanup nicht vollständig; eigenen Recovery-State erhalten.' }
[PSCustomObject]@{
    WorkItem = 'OPS-008'; Scenario = $Scenario; Status = 'PASS'; SqlVersion = '2025'
    ProductVersion = $runtimeMetadata.ProductVersion
    CompatibilityLevel = $runtimeMetadata.CompatibilityLevel
    Provider = 'docker'; Cleanup = 'REMOVED'
}
