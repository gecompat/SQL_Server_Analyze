[CmdletBinding()]
param(
    [string] $LabRepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')

$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$null = & (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force

$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot = Assert-AnalyzePathUnderRoot `
    -Path (Join-Path $systemTempRoot ("SQL_Server_Analyze/ops-009-{0}" -f [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$saPassword = New-AnalyzeExampleSecret
$lab = $null
$cleanupCompleted = $false
try {
    $lab = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword `
        -StateRoot $stateRoot -LabName 'analyze-ops-009-inventory' -NonInteractive
    # Der bestehende Analyze-Installationspfad benötigt die abgeschlossene
    # initiale Wiederherstellung der Systemdatenbanken.
    Start-Sleep -Seconds 60
    $runDirectory = Join-Path $stateRoot 'ops-009'
    [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $runDirectory
    foreach ($script in @($framework.Prepare, $framework.Installer)) {
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $lab.RunId `
            -StateRoot $stateRoot -SaPassword $saPassword
    }
    foreach ($relativePath in @(
            'Code/Tests/Integration/110_Smoke_Test.sql',
            'Code/Tests/ServerHealth/123_OPS009_System_Database_Objects_Runtime_Contract.sql'
        )) {
        $scriptPath = Join-Path $runDirectory ([IO.Path]::GetFileName($relativePath))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relativePath), [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($scriptPath, $content.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
        $null = Invoke-AnalyzeLabScript -ScriptPath $scriptPath -RunId $lab.RunId `
            -StateRoot $stateRoot -SaPassword $saPassword
    }
}
finally {
    if ($lab) {
        try {
            $cleanup = Remove-SqlServerLab -RunId $lab.RunId -StateRoot $stateRoot -Force -Confirm:$false
            $cleanupCompleted = $cleanup.Status -eq 'REMOVED'
        } catch { Write-Warning "OPS-009-Cleanup fehlgeschlagen ($($_.Exception.GetType().Name))." }
        if (-not $cleanupCompleted) {
            Write-Warning "Recovery: Remove-SqlServerLab -RunId '$($lab.RunId)' -StateRoot '$stateRoot' -Force -Confirm:`$false"
        }
    } else { Write-Warning "Eigener Provisionierungs-Recovery-State: '$stateRoot'. Get-SqlServerLab -StateRoot '$stateRoot' prüfen." }
    # Ein fehlgeschlagenes Provisioning kann Recovery-State hinterlassen.
    if ($cleanupCompleted) {
        $verifiedRoot = Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $systemTempRoot
        Remove-Item -LiteralPath $verifiedRoot -Recurse -Force -ErrorAction Stop
    }
}
if (-not $cleanupCompleted) { throw 'OPS-009-Cleanup nicht vollständig; eigenen Recovery-State erhalten.' }

[PSCustomObject]@{
    Status = 'PASS'
    WorkItem = 'OPS-009'
    SqlVersion = '2025'
    Provider = 'docker'
    ServerCollation = 'Latin1_General_100_CS_AS'
    FrameworkCollation = 'SQL_Latin1_General_CP1_CS_AS'
    Scope = 'Framework smoke; three-system-database inventory, exact bound, restricted and selective master-only visibility, empty contracts'
    Cleanup = 'REMOVED'
}
