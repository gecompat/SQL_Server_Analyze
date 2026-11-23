#Requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$LabRoot)

$ErrorActionPreference = 'Stop'
if (-not $IsLinux -or $env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'The RUNTIME-001 Java fixture requires a disposable GitHub-hosted Linux runner.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$labModulePath = Join-Path (Resolve-Path -LiteralPath $LabRoot).Path 'SqlServerLab.psd1'
$work = Join-Path $env:RUNNER_TEMP ('analyze-java-' + [guid]::NewGuid().ToString('N'))
$state = Join-Path $work 'state'
$previousState = $env:SQL_SERVER_LAB_STATE
$failure = $null
$cleanupFailure = $null
Import-Module $labModulePath
$null = New-Item -ItemType Directory -Path $work
$env:SQL_SERVER_LAB_STATE = $state

try {
    $manifest = @{
        name = 'analyze-java-catalog'
        automation = @{ mode = 'unattended' }
        instances = @(@{
            id = 'java'
            version = '2025'
            provider = 'docker'
            profile = 'performance'
            network = @{ intent = 'nat'; exposure = 'host' }
            databases = @(@{
                name = 'ExampleExternalRuntimeProbe'
                collation = 'SQL_Latin1_General_CP1_CS_AS'
                options = @{ compatibility = 170 }
            })
            software = @(@{
                id = 'sql-java'
                variant = 'sql-java-2025-shared-user-v2'
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
        throw 'The owned Java Lab instance did not match the expected profile.'
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
CREATE DATABASE [ExampleAnalyzeJava] COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
ALTER DATABASE [ExampleAnalyzeJava] SET COMPATIBILITY_LEVEL = 170;
GO
'@)
        $includes = 0
        foreach ($line in Get-Content -LiteralPath (Join-Path $installRoot 'Install_All.sql') -Encoding utf8) {
            if ($line -match '^:r[ \t]+(\.\./[A-Za-z0-9_]+/[A-Za-z0-9_]+\.sql)[ \t]*$') {
                $includes++
                $source = Get-Content -LiteralPath (Join-Path $installRoot $Matches[1]) -Raw -Encoding utf8
                $writer.WriteLine($source.Replace('[DeineDatenbank]', '[ExampleAnalyzeJava]'))
                $writer.WriteLine('GO')
            } elseif ($line -eq ':ON ERROR EXIT') {
                # Invoke-SqlServerLabScript stops on the first SQL error.
                continue
            } elseif ($line -match '^\s*:') {
                throw 'Unexpected SQLCMD directive in the canonical installer.'
            } else {
                $writer.WriteLine($line.Replace('[DeineDatenbank]', '[ExampleAnalyzeJava]'))
            }
        }
        if ($includes -eq 0) { throw 'The canonical installer contains no SQL includes.' }
    } finally {
        $writer.Dispose()
    }
    $install = Invoke-SqlServerLabScript -RunId $lab.RunId -InstanceId java -StateRoot $state `
        -SaPassword $sqlCredential -ScriptPath $installer -KeepConnection -Confirm:$false
    if (-not $install.Success) { throw 'The canonical Analyze installation failed.' }

    $receiptSummary = @($instance.ExternalRuntime.Receipts)[0]
    if ([string]$lab.RunId -notmatch '^[A-Za-z0-9_-]+$') { throw 'Invalid owned Lab run identifier.' }
    $receiptPath = Join-Path (Join-Path (Join-Path $state 'runs') $lab.RunId) 'software-installation-receipts.json'
    $document = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 50
    $receiptInstances = @($document.instances | Where-Object { $_.instanceId -eq 'java' })
    if ($document.contract.name -ne 'SqlServerLab.RunSoftwareInstallationReceipts' -or
        $document.contract.version -ne '1.0' -or $receiptInstances.Count -ne 1 -or
        @($receiptInstances[0].receipts).Count -ne 1) {
        throw 'The owned Lab installation receipt document did not match its contract.'
    }
    $receipt = @($receiptInstances[0].receipts)[0]
    if ($receipt.Contract.Name -ne 'SqlServerLab.SoftwareInstallationReceipt' -or
        $receipt.Contract.Version -ne '1.0' -or $receipt.SoftwareId -ne 'sql-java' -or
        $receipt.Status -ne 'EXTENSIONS_READY_RUN' -or [string]::IsNullOrEmpty($receipt.PlanKey) -or
        $receipt.PlanKey -cne $receiptSummary.PlanKey -or $receipt.VariantId -cne $receiptSummary.VariantId) {
        throw 'The private installation receipt did not bind to the owned instance summary.'
    }
    $javaProbe = @($receipt.Postconditions | Where-Object { $_.Id -eq 'java-data-roundtrip' })
    if ($receipt.VariantId -ne 'sql-java-2025-shared-user-v2' -or $javaProbe.Count -ne 1 -or
        $javaProbe[0].Status -ne 'PASS' -or $javaProbe[0].Language -ne 'Java' -or
        $javaProbe[0].Database -ne 'ExampleExternalRuntimeProbe' -or $javaProbe[0].Registration -ne 'CREATED' -or
        $javaProbe[0].InputValue -ne 42 -or $javaProbe[0].OutputValue -ne 42 -or
        $javaProbe[0].WorkerIdentity -ne 'mssql_launchpadd') {
        throw 'The native provisioning receipt did not establish the owned Java round-trip.'
    }
    Write-Output 'RUNTIME001_JAVA_NATIVE_ROUNDTRIP=PASS'

    $result = Invoke-SqlServerLabScript -RunId $lab.RunId -InstanceId java -StateRoot $state `
        -SaPassword $sqlCredential -Database ExampleAnalyzeJava -ScriptPath (Join-Path $PSScriptRoot 'Fixtures/Runtime001_JavaCatalog.sql') `
        -KeepConnection -Confirm:$false
    if (-not $result.Success) { throw 'The Analyze Java catalog contract failed.' }
    Write-Output 'RUNTIME001_JAVA_CATALOG_JSON_AND_FINDINGS_PARITY=PASS'
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
if ($cleanupFailure) { throw "RUNTIME001_JAVA_CLEANUP_FAILED: $cleanupFailure. Primary failure: $failure" }
if ($failure) { throw $failure }
Write-Output 'RUNTIME001_JAVA_OWNED_LAB_CLEANUP=PASS'
