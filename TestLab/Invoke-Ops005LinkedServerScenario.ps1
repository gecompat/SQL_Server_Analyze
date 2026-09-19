[CmdletBinding()]
param(
    [ValidateSet('docker', 'podman')]
    [string] $Provider = 'docker',

    [ValidateSet('2019', '2022', '2025')]
    [string] $Version = '2025',

    [SecureString] $SaPassword,
    [string] $StateRoot,
    [string] $LabRepositoryRoot,
    [switch] $KeepOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')

$repositoryRoot = Get-AnalyzeRepositoryRoot
if ([string]::IsNullOrWhiteSpace($LabRepositoryRoot)) {
    $labRoot = Resolve-SqlServerLabRepositoryRoot
}
else {
    $labRoot = (Resolve-Path -LiteralPath $LabRepositoryRoot -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath (Join-Path $labRoot 'SqlServerLab.psd1') -PathType Leaf)) {
        throw "SQL_Server_Lab-Modul nicht gefunden: $labRoot"
    }
}
if (-not $SaPassword) { $SaPassword = New-AnalyzeExampleSecret }
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path ([IO.Path]::GetTempPath()) ("SQL_Server_Analyze/ops-005-{0}" -f $Provider)
}
$StateRoot = Assert-AnalyzePathUnderRoot -Path $StateRoot -AllowedRoot ([IO.Path]::GetTempPath())
[IO.Directory]::CreateDirectory($StateRoot) | Out-Null
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force

$lab = $null
$failed = $false
$cleanupCompleted = $false
try {
    $lab = New-SqlServerLab -Version $Version -Provider $Provider -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $SaPassword `
        -StateRoot $StateRoot -LabName 'analyze-ops-005-linked-server' -NonInteractive
    Start-Sleep -Seconds 60

    $runDirectory = Join-Path $StateRoot ("runs/{0}/ops-005" -f $lab.RunId)
    [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $runDirectory
    Invoke-AnalyzeLabScript -ScriptPath $framework.Prepare -RunId $lab.RunId -StateRoot $StateRoot -SaPassword $SaPassword | Out-Null
    Invoke-AnalyzeLabScript -ScriptPath $framework.Installer -RunId $lab.RunId -StateRoot $StateRoot -SaPassword $SaPassword | Out-Null

    $contractSource = Join-Path $repositoryRoot 'Code/Tests/ServerHealth/120_OPS005_Linked_Server_Runtime_Contract.sql'
    $contractPath = Join-Path $runDirectory '120_OPS005_Linked_Server_Runtime_Contract.sql'
    $contract = [IO.File]::ReadAllText($contractSource, [Text.Encoding]::UTF8).Replace('[DeineDatenbank]', '[LabAnalyze]')
    [IO.File]::WriteAllText($contractPath, $contract, [Text.UTF8Encoding]::new($false))
    Invoke-AnalyzeLabScript -ScriptPath $contractPath -RunId $lab.RunId -StateRoot $StateRoot -SaPassword $SaPassword | Out-Null
    $cleanupCompleted = $true
}
catch {
    $failed = $true
    throw
}
finally {
    if ($lab -and -not ($failed -and $KeepOnFailure)) {
        Remove-SqlServerLab -RunId $lab.RunId -StateRoot $StateRoot -Force -Confirm:$false | Out-Null
    }
}

if ($cleanupCompleted) {
    [PSCustomObject]@{ Status = 'PASS'; WorkItem = 'OPS-005'; Provider = $Provider; SqlVersion = $Version; RunId = $lab.RunId; Cleanup = 'REMOVED' }
}
