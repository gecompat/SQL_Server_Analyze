[CmdletBinding()]
param(
    [ValidateSet('2019', '2022', '2025')]
    [string[]] $Version = @('2019', '2022', '2025'),

    [string] $LabRepositoryRoot,

    [string] $StateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')

$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$adapterPath = Join-Path $repositoryRoot 'TestLab/Adapters/OPS-005'
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path `
        $systemTempRoot `
        ("SQL_Server_Analyze/ops-005-{0}" -f [guid]::NewGuid().ToString('N'))
}
$StateRoot = Assert-AnalyzePathUnderRoot -Path $StateRoot -AllowedRoot $systemTempRoot

foreach ($requiredPath in @(
        (Join-Path $adapterPath 'adapter.json'),
        (Join-Path $adapterPath 'sql/install.sql'),
        (Join-Path $adapterPath 'sql/update.sql'),
        (Join-Path $labRoot 'SqlServerLab.psd1'),
        (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1')
    )) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Der OPS-005-Matrixlauf benötigt eine fehlende Datei: $requiredPath"
    }
}

[IO.Directory]::CreateDirectory($StateRoot) | Out-Null

# Die Host-Auflösung ist pro Runnerprozess verpflichtend. Der Adapter führt
# keine Docker-Kommandos direkt aus; die Labplattform besitzt den Provider.
$hostTools = @(& (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker)
$dockerTool = @($hostTools | Where-Object { $_.Name -eq 'docker' })
if ($dockerTool.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$dockerTool[0].Invocation)) {
    throw 'SQL_Server_Lab konnte Docker im aktuellen Runnerprozess nicht sicher auflösen.'
}

Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force
$adapterValidation = Test-SqlServerLabAdapter -Path $adapterPath
if (-not $adapterValidation.IsReady) {
    throw "Der OPS-005-Adapter ist ungültig: $($adapterValidation.Errors -join '; ')"
}

$results = [Collections.Generic.List[object]]::new()
$stateRootRemovable = $true
try {
    foreach ($sqlVersion in $Version) {
        $saPassword = New-AnalyzeExampleSecret
        $lab = $null
        $adapterCleanupCompleted = $false
        $labCleanupCompleted = $false
        try {
            $lab = New-SqlServerLab `
                -Version $sqlVersion `
                -Provider docker `
                -Profile standard `
                -Collation 'Latin1_General_100_CS_AS' `
                -SaPassword $saPassword `
                -StateRoot $StateRoot `
                -LabName ("analyze-ops005-linked-server-{0}" -f $sqlVersion) `
                -NonInteractive

            $runtimeValidation = Test-SqlServerLabAdapter `
                -Path $adapterPath `
                -RunId $lab.RunId `
                -InstanceId primary `
                -StateRoot $StateRoot
            if (-not $runtimeValidation.IsReady) {
                throw "Der OPS-005-Adapter ist mit SQL Server $sqlVersion nicht kompatibel: $($runtimeValidation.Errors -join '; ')"
            }

            foreach ($entrypoint in @('install', 'update', 'validate')) {
                $entrypointResult = Install-SqlServerLabAdapter `
                    -Path $adapterPath `
                    -RunId $lab.RunId `
                    -InstanceId primary `
                    -SaPassword $saPassword `
                    -Entrypoint $entrypoint `
                    -StateRoot $StateRoot
                if (-not $entrypointResult.Success -or $entrypointResult.Status -ne 'ADAPTER_APPLIED') {
                    throw "OPS-005-Entrypoint '$entrypoint' für SQL Server $sqlVersion fehlgeschlagen ($($entrypointResult.Status)): $($entrypointResult.Message)"
                }
            }
        }
        finally {
            if ($lab) {
                try {
                    $adapterCleanup = Install-SqlServerLabAdapter `
                        -Path $adapterPath `
                        -RunId $lab.RunId `
                        -InstanceId primary `
                        -SaPassword $saPassword `
                        -Entrypoint cleanup `
                        -StateRoot $StateRoot
                    $adapterCleanupCompleted = $adapterCleanup.Success -and
                        $adapterCleanup.Status -eq 'ADAPTER_APPLIED'
                    if (-not $adapterCleanupCompleted) {
                        throw "OPS-005-Adapter-Cleanup meldete $($adapterCleanup.Status): $($adapterCleanup.Message)"
                    }
                }
                catch {
                    $stateRootRemovable = $false
                    Write-Warning "Der Adapter-Cleanup für SQL Server $sqlVersion ist fehlgeschlagen: $($_.Exception.Message)"
                }

                try {
                    $labCleanup = Remove-SqlServerLab `
                        -RunId $lab.RunId `
                        -StateRoot $StateRoot `
                        -Force `
                        -Confirm:$false
                    $labCleanupCompleted = $labCleanup.Status -eq 'REMOVED'
                    if (-not $labCleanupCompleted) {
                        throw "SQL_Server_Lab-Cleanup meldete $($labCleanup.Status)."
                    }
                }
                catch {
                    $stateRootRemovable = $false
                    throw "Der scopegebundene Lab-Cleanup für SQL Server $sqlVersion ist fehlgeschlagen: $($_.Exception.Message)"
                }
            }
        }

        if (-not $adapterCleanupCompleted -or -not $labCleanupCompleted) {
            $stateRootRemovable = $false
            throw "Der OPS-005-Matrixlauf für SQL Server $sqlVersion beendete den Cleanup nicht vollständig."
        }
        $results.Add([PSCustomObject]@{
                Status = 'PASS'
                WorkItem = 'OPS-005'
                SqlVersion = $sqlVersion
                Provider = 'docker'
                AdapterProjectId = $adapterValidation.ProjectId
                Cleanup = 'REMOVED'
            })
    }
}
finally {
    if ($stateRootRemovable -and (Test-Path -LiteralPath $StateRoot -PathType Container)) {
        Remove-Item -LiteralPath $StateRoot -Recurse -Force -ErrorAction Stop
    }
    elseif (-not $stateRootRemovable) {
        Write-Warning 'Der Matrix-State bleibt für den recoverygebundenen Cleanup erhalten.'
    }
}

$results.ToArray()
