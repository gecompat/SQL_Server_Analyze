[CmdletBinding()]
param(
    [string] $LabRepositoryRoot,
    [ValidateSet('HistoryRestore', 'AgentHistory', 'MailMaintenance')]
    [string] $Scenario = 'HistoryRestore'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
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
    $lab = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword `
        -StateRoot $stateRoot -LabName 'analyze-ops008-history' -NonInteractive
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
    else {
        $scripts += @('TestLab/Scenarios/OPS-008/history-window.sql',
            'TestLab/Scenarios/OPS-008/restore-window.sql')
    }
    foreach ($relative in $scripts) {
        $rendered = Join-Path $stateRoot ([IO.Path]::GetFileName($relative))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relative), [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($rendered, $content.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
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
