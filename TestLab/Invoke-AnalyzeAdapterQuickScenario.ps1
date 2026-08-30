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
$labRoot = Resolve-SqlServerLabRepositoryRoot `
    -LabRepositoryRoot $LabRepositoryRoot
$adapterPath = Join-Path `
    $repositoryRoot `
    'TestLab/Adapters/EXECUTION-PLAN-001'
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path `
        $systemTempRoot `
        ("SQL_Server_Analyze/adp-004-{0}" -f $Provider)
}
$StateRoot = Assert-AnalyzePathUnderRoot `
    -Path $StateRoot `
    -AllowedRoot $systemTempRoot

if (-not $SaPassword) {
    $SaPassword = New-AnalyzeExampleSecret
}

[IO.Directory]::CreateDirectory($StateRoot) | Out-Null
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force

$adapterValidation = Test-SqlServerLabAdapter -Path $adapterPath
if (-not $adapterValidation.IsReady) {
    throw "Der Analyze-Adapter ist ungültig: $($adapterValidation.Errors -join '; ')"
}

$lab = $null
$result = $null
$failed = $false
$cleanupCompleted = $false

try {
    $lab = New-SqlServerLab `
        -Version $Version `
        -Provider $Provider `
        -Profile standard `
        -Collation 'SQL_Latin1_General_CP1_CS_AS' `
        -SaPassword $SaPassword `
        -StateRoot $StateRoot `
        -LabName 'analyze-adapter-execution-plan-001' `
        -NonInteractive

    Start-Sleep -Seconds 60

    $runtimeValidation = Test-SqlServerLabAdapter `
        -Path $adapterPath `
        -RunId $lab.RunId `
        -InstanceId primary `
        -StateRoot $StateRoot
    if (-not $runtimeValidation.IsReady) {
        throw "Der Analyze-Adapter ist mit dem Lab-Run inkompatibel: $($runtimeValidation.Errors -join '; ')"
    }

    foreach ($entrypoint in @('install', 'update', 'validate')) {
        $entrypointResult = Install-SqlServerLabAdapter `
            -Path $adapterPath `
            -RunId $lab.RunId `
            -InstanceId primary `
            -SaPassword $SaPassword `
            -Entrypoint $entrypoint `
            -StateRoot $StateRoot
        if (-not $entrypointResult.Success -or
            $entrypointResult.Status -ne 'ADAPTER_APPLIED') {
            throw "Adapter-Entrypoint '$entrypoint' fehlgeschlagen ($($entrypointResult.Status)): $($entrypointResult.Message)"
        }
    }

    $result = [PSCustomObject]@{
        Status = 'PASS'
        WorkItem = 'ADP-004'
        ScenarioId = 'EXECUTION-PLAN-001'
        Provider = $Provider
        SqlVersion = $Version
        AdapterProjectId = $adapterValidation.ProjectId
        AdapterContractVersion = $adapterValidation.Adapter.adapterContractVersion
        RunId = $lab.RunId
        Cleanup = 'PENDING'
    }
}
catch {
    $failed = $true
    throw
}
finally {
    $preserve = $failed -and $KeepOnFailure
    if ($lab -and -not $preserve) {
        try {
            $cleanupResult = Install-SqlServerLabAdapter `
                -Path $adapterPath `
                -RunId $lab.RunId `
                -InstanceId primary `
                -SaPassword $SaPassword `
                -Entrypoint cleanup `
                -StateRoot $StateRoot
            $cleanupCompleted = $cleanupResult.Success -and
                $cleanupResult.Status -eq 'ADAPTER_APPLIED'
            if (-not $cleanupCompleted) {
                Write-Warning "Adapter-Cleanup meldete $($cleanupResult.Status); der Infrastruktur-Cleanup wird dennoch ausgeführt."
            }
        }
        catch {
            Write-Warning "Adapter-Cleanup fehlgeschlagen; der Infrastruktur-Cleanup wird dennoch ausgeführt: $($_.Exception.Message)"
        }

        Remove-SqlServerLab `
            -RunId $lab.RunId `
            -StateRoot $StateRoot `
            -Force `
            -Confirm:$false | Out-Null
    }
    elseif ($preserve) {
        Write-Warning "Fehlgeschlagenes Adapter-Lab wurde absichtlich erhalten. RunId: $($lab.RunId)"
    }
}

if ($result) {
    $result.Cleanup = if ($cleanupCompleted) {
        'REMOVED'
    }
    else {
        'INFRASTRUCTURE_ONLY'
    }
    $result
}
