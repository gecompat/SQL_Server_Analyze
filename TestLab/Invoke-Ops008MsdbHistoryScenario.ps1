[CmdletBinding()]
param([string] $LabRepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$null = & (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot = Assert-AnalyzePathUnderRoot `
    -Path (Join-Path $systemTempRoot ('SQL_Server_Analyze/ops008-history-' + [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$saPassword = New-AnalyzeExampleSecret
$lab = $null
$cleanupCompleted = $false
try {
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
    foreach ($relative in @('Code/Tests/Integration/110_Smoke_Test.sql',
            'Code/Tests/ServerHealth/122_OPS008_Msdb_Health_Runtime_Contract.sql',
            'TestLab/Scenarios/OPS-008/history-window.sql',
            'TestLab/Scenarios/OPS-008/restore-window.sql')) {
        $rendered = Join-Path $stateRoot ([IO.Path]::GetFileName($relative))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relative), [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($rendered, $content.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
        $null = Invoke-AnalyzeLabScript -ScriptPath $rendered -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    }
}
finally {
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
if (-not $cleanupCompleted) { throw 'OPS-008-Cleanup nicht vollständig; eigenen Recovery-State erhalten.' }
[PSCustomObject]@{ WorkItem = 'OPS-008'; Status = 'PASS'; SqlVersion = '2025'; Provider = 'docker'; Cleanup = 'REMOVED' }
