[CmdletBinding()]
param(
    [ValidateSet('2019', '2022', '2025')]
    [string] $Version = '2025',
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
    -Path (Join-Path $systemTempRoot ("SQL_Server_Analyze/ops-006-{0}" -f [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$saPassword = New-AnalyzeExampleSecret
$lab = $null
$cleanupCompleted = $false
try {
    $lab = New-SqlServerLab -Version $Version -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword `
        -StateRoot $stateRoot -LabName 'analyze-ops-006-portability' -NonInteractive
    # Der bestehende Analyze-Installationspfad benötigt die abgeschlossene
    # initiale Wiederherstellung der Systemdatenbanken.
    Start-Sleep -Seconds 60
    $runDirectory = Join-Path $stateRoot 'ops-006'
    [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $runDirectory
    foreach ($script in @($framework.Prepare, $framework.Installer)) {
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $lab.RunId `
            -StateRoot $stateRoot -SaPassword $saPassword
    }
    foreach ($relativePath in @(
            'Code/Tests/Integration/110_Smoke_Test.sql',
            'Code/Tests/ServerHealth/121_OPS006_Database_Portability_Runtime_Contract.sql'
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
        $cleanup = Remove-SqlServerLab -RunId $lab.RunId -StateRoot $stateRoot -Force -Confirm:$false
        $cleanupCompleted = $cleanup.Status -eq 'REMOVED'
        if (-not $cleanupCompleted) {
            throw 'Der scopegebundene OPS-006-Lab-Cleanup ist nicht abgeschlossen; der temporäre State bleibt für Recovery erhalten.'
        }
    }
    # Ein fehlgeschlagenes Provisioning kann Recovery-State hinterlassen.
    if ($cleanupCompleted) {
        $verifiedRoot = Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $systemTempRoot
        Remove-Item -LiteralPath $verifiedRoot -Recurse -Force -ErrorAction Stop
    }
}

[PSCustomObject]@{
    Status = 'PASS'
    WorkItem = 'OPS-006'
    SqlVersion = $Version
    Provider = 'docker'
    ServerCollation = 'Latin1_General_100_CS_AS'
    FrameworkCollation = 'SQL_Latin1_General_CP1_CS_AS'
    Scope = 'Framework smoke; portable, Compression, uncontained, missing and restricted contracts'
    Cleanup = 'REMOVED'
}
