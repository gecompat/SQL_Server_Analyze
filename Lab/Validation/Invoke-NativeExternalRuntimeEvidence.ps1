#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LabRoot,
    [Parameter(Mandatory)][ValidateSet('Java','Python','R')][string]$Language
)

$ErrorActionPreference = 'Stop'
if (-not $IsLinux -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'The RUNTIME-001 fixture requires a disposable GitHub-hosted Linux runner.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$labModulePath = Join-Path (Resolve-Path -LiteralPath $LabRoot).Path 'SqlServerLab.psd1'
$runtimeId = 'sql-' + $Language.ToLowerInvariant()
$variant = "${runtimeId}-2025-shared-user-v2"
$profile = switch ($Language) {
    'Java'   { @{ ProbeId = 'java-data-roundtrip'; Fixture = 'Runtime001_JavaCatalog.sql'; Evidence = 'CATALOG_JSON_AND_FINDINGS_PARITY' } }
    'Python' { @{ ProbeId = 'python-data-roundtrip'; Fixture = 'Runtime001_MlCounters.sql'; Evidence = 'CUMULATIVE_COUNTERS_JSON' } }
    'R'      { @{ ProbeId = 'r-data-roundtrip'; Fixture = 'Runtime001_MlCounters.sql'; Evidence = 'CUMULATIVE_COUNTERS_JSON' } }
}
$markerPrefix = 'RUNTIME001_' + $Language.ToUpperInvariant()
$work = Join-Path $env:RUNNER_TEMP ('analyze-runtime-' + [guid]::NewGuid().ToString('N'))
$state = Join-Path $work 'state'
$previousState = $env:SQL_SERVER_LAB_STATE
$failure = $null
$cleanupFailure = $null
Import-Module $labModulePath
$null = New-Item -ItemType Directory -Path $work
$env:SQL_SERVER_LAB_STATE = $state

try {
    $manifest = @{
        name = 'analyze-external-runtime'
        automation = @{ mode = 'unattended' }
        instances = @(@{
            id = 'runtime'
            version = '2025'
            provider = 'docker'
            profile = 'standard'
            network = @{ intent = 'nat'; exposure = 'host' }
            databases = @(@{
                name = 'ExampleExternalRuntimeProbe'
                collation = $(if ($Language -eq 'Java') { 'Latin1_General_100_CI_AI_SC' } else { 'SQL_Latin1_General_CP1_CS_AS' })
                options = @{ compatibility = 170 }
            })
            software = @(@{
                id = $runtimeId
                variant = $variant
                scope = 'sqlExternalRuntime'
                optional = $false
            })
        })
    }
    $manifestPath = Join-Path $work 'manifest.json'
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath
    $credentialText = 'Example!' + [guid]::NewGuid().ToString('N') + 'Aa7'
    Write-Host "::add-mask::$credentialText"
    $sqlCredential = ConvertTo-SecureString $credentialText -AsPlainText -Force
    $credentialText = $null
    $lab = New-SqlServerLab -Manifest $manifestPath -SaPassword $sqlCredential -StateRoot $state -NonInteractive
    $instance = @($lab.Instances)[0]
    if ($lab.State -ne 'Running' -or $instance.Host -ne ([System.Net.IPAddress]::Loopback).ToString() -or
        $instance.ExternalRuntime.LaunchMode -ne 'sql2025-shared-user-v2' -or
        @($instance.ExternalRuntime.Receipts).Count -ne 1) {
        throw 'The owned Lab instance did not match the expected external runtime profile.'
    }

    $containerProfile = & docker inspect --format '{{.HostConfig.Privileged}}|{{.HostConfig.CgroupnsMode}}|{{range .Mounts}}{{.Destination}}|{{end}}' $instance.ContainerId
    if ($LASTEXITCODE -ne 0 -or $containerProfile -notlike 'false|private|*' -or
        $containerProfile -match '(?:^|\|)/sys/fs/cgroup(?:/|\|)' -or
        $containerProfile -match '(?:^|\|)/var/run/docker\.sock(?:/|\|)') {
        throw 'The owned CI container has an unexpected privileged mode or host mount.'
    }

    $installRoot = Join-Path $repoRoot 'Code/Install'
    $installer = Join-Path $work 'install.sql'
    $encoding = [Text.UTF8Encoding]::new($false)
    $writer = [IO.StreamWriter]::new($installer, $false, $encoding)
    try {
        $writer.WriteLine(@'
IF ISNULL(CONVERT(varchar(32),SERVERPROPERTY('ProductVersion')),'') <> '17.0.5005.3'
    THROW 56970,N'Unexpected SQL Server engine build.',1;
CREATE DATABASE [ExampleAnalyzeRuntime] COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
ALTER DATABASE [ExampleAnalyzeRuntime] SET COMPATIBILITY_LEVEL = 170;
GO
'@)
        $includes = 0
        foreach ($line in Get-Content -LiteralPath (Join-Path $installRoot 'Install_All.sql') -Encoding utf8) {
            if ($line -match '^:r[ \t]+(\.\./[A-Za-z0-9_]+/[A-Za-z0-9_]+\.sql)[ \t]*$') {
                $includes++
                $source = Get-Content -LiteralPath (Join-Path $installRoot $Matches[1]) -Raw -Encoding utf8
                $writer.WriteLine($source.Replace('[DeineDatenbank]', '[ExampleAnalyzeRuntime]'))
                $writer.WriteLine('GO')
            } elseif ($line -eq ':ON ERROR EXIT') {
                # Invoke-SqlServerLabScript stops on the first SQL error.
                continue
            } elseif ($line -match '^\s*:') {
                throw 'Unexpected SQLCMD directive in the canonical installer.'
            } else {
                $writer.WriteLine($line.Replace('[DeineDatenbank]', '[ExampleAnalyzeRuntime]'))
            }
        }
        if ($includes -eq 0) { throw 'The canonical installer contains no SQL includes.' }
    } finally {
        $writer.Dispose()
    }
    $install = Invoke-SqlServerLabScript -RunId $lab.RunId -InstanceId runtime -StateRoot $state `
        -SaPassword $sqlCredential -ScriptPath $installer -KeepConnection -Confirm:$false
    if (-not $install.Success) { throw 'The canonical Analyze installation failed.' }

    $receiptSummary = @($instance.ExternalRuntime.Receipts)[0]
    if ([string]$lab.RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid owned Lab run identifier.' }
    $receiptPath = Join-Path (Join-Path (Join-Path $state 'runs') $lab.RunId) 'software-installation-receipts.json'
    $document = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 50
    $receiptInstances = @($document.instances | Where-Object { $_.instanceId -eq 'runtime' })
    if ($document.contract.name -ne 'SqlServerLab.RunSoftwareInstallationReceipts' -or
        $document.contract.version -ne '1.0' -or $receiptInstances.Count -ne 1 -or
        @($receiptInstances[0].receipts).Count -ne 1) {
        throw 'The owned Lab installation receipt document did not match its contract.'
    }
    $receipt = @($receiptInstances[0].receipts)[0]
    if ($receipt.Contract.Name -ne 'SqlServerLab.SoftwareInstallationReceipt' -or
        $receipt.Contract.Version -ne '1.0' -or $receipt.SoftwareId -ne $runtimeId -or
        $receipt.Status -ne 'EXTENSIONS_READY_RUN' -or [string]::IsNullOrEmpty($receipt.PlanKey) -or
        $receipt.PlanKey -cne $receiptSummary.PlanKey -or $receipt.VariantId -cne $receiptSummary.VariantId) {
        throw 'The private installation receipt did not bind to the owned instance summary.'
    }
    $probes = @($receipt.Postconditions | Where-Object { $_.Id -eq $profile.ProbeId })
    if ($receipt.VariantId -ne $variant -or $probes.Count -ne 1 -or
        $probes[0].Status -ne 'PASS' -or $probes[0].Language -ne $Language -or
        $probes[0].InputValue -ne 42 -or $probes[0].OutputValue -ne 42 -or
        $probes[0].WorkerIdentity -ne 'mssql_launchpadd') {
        throw 'The native provisioning receipt did not establish the owned round-trip.'
    }
    if ($Language -eq 'Java' -and
        ($probes[0].Database -ne 'ExampleExternalRuntimeProbe' -or $probes[0].Registration -ne 'CREATED')) {
        throw 'The Java receipt did not establish a new registration in the owned database.'
    }
    Write-Output "${markerPrefix}_NATIVE_ROUNDTRIP=PASS"

    $fixturePath = Join-Path (Join-Path $PSScriptRoot 'Fixtures') $profile.Fixture
    if ($Language -in @('Python','R')) {
        $fixtureSource = [IO.File]::ReadAllText($fixturePath, $encoding)
        $fixturePath = Join-Path $work 'ml-counters.sql'
        # Language is restricted to the fixed SQL literals in the ValidateSet above.
        [IO.File]::WriteAllText($fixturePath, "DECLARE @FixtureLanguage nvarchar(128)=N'$Language';`n" + $fixtureSource, $encoding)
    }
    $result = Invoke-SqlServerLabScript -RunId $lab.RunId -InstanceId runtime -StateRoot $state `
        -SaPassword $sqlCredential -Database ExampleAnalyzeRuntime -ScriptPath $fixturePath `
        -KeepConnection -Confirm:$false
    if (-not $result.Success) { throw 'The Analyze external runtime evidence contract failed.' }
    Write-Output "${markerPrefix}_$($profile.Evidence)=PASS"
} catch {
    $failure = $_
} finally {
    if (Test-Path -LiteralPath (Join-Path $state 'runs')) {
        foreach ($run in Get-ChildItem -LiteralPath (Join-Path $state 'runs') -Directory) {
            try {
                $cleanup = Remove-SqlServerLab -RunId $run.Name -StateRoot $state -Force -Confirm:$false
                if ($cleanup.Status -ne 'REMOVED') { throw 'The owned Lab did not report removal.' }
            } catch {
                $cleanupFailure = $_
            }
        }
    }
    $env:SQL_SERVER_LAB_STATE = $previousState
    if (-not $cleanupFailure) { Remove-Item -LiteralPath $work -Recurse -Force }
}
if ($cleanupFailure) { throw "RUNTIME001_EXTERNAL_RUNTIME_CLEANUP_FAILED: $cleanupFailure. Primary failure: $failure" }
if ($failure) { throw $failure }
Write-Output "${markerPrefix}_OWNED_LAB_CLEANUP=PASS"
