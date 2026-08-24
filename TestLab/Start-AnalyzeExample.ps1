[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Z][A-Z0-9-]{2,39}$')]
    [string] $Example,

    [ValidateSet('2019', '2022', '2025')]
    [string] $Version = '2022',

    [ValidateSet('docker', 'podman')]
    [string] $Provider = 'docker',

    [ValidateSet('Interactive', 'Verify')]
    [string] $Mode = 'Interactive',

    [switch] $KeepOnFailure,

    [string] $StateRoot = 'C:\rep\tmp\SQL_Server_Analyze\lab-state',

    [string] $LabRepositoryRoot,

    [SecureString] $SaPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')

$repositoryRoot = Get-AnalyzeRepositoryRoot
$null = Assert-AnalyzePathUnderRoot -Path $repositoryRoot -AllowedRoot 'C:\rep\pu'
$StateRoot = Assert-AnalyzePathUnderRoot -Path $StateRoot -AllowedRoot 'C:\rep\tmp'
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$definition = Resolve-AnalyzeExample `
    -Example $Example `
    -Version $Version `
    -Provider $Provider

if (-not $SaPassword) {
    if ($Mode -eq 'Interactive') {
        $SaPassword = Read-Host `
            -Prompt 'Temporäres SA-Passwort für dieses lokale Lab' `
            -AsSecureString
    }
    else {
        $SaPassword = New-AnalyzeExampleSecret
    }
}

[IO.Directory]::CreateDirectory($StateRoot) | Out-Null
$originalTemp = $env:TEMP
$originalTmp = $env:TMP
$processTempRoot = Assert-AnalyzePathUnderRoot `
    -Path 'C:\rep\tmp\SQL_Server_Analyze\process-temp' `
    -AllowedRoot 'C:\rep\tmp'
[IO.Directory]::CreateDirectory($processTempRoot) | Out-Null
$env:TEMP = $processTempRoot
$env:TMP = $processTempRoot
$originalDockerConfig = $env:DOCKER_CONFIG
$originalDockerHost = $env:DOCKER_HOST
if ($Provider -eq 'docker') {
    $activeDockerContext = (& docker context show 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($activeDockerContext)) {
        throw 'Der aktive Docker-Kontext konnte nicht aufgelöst werden.'
    }
    $activeDockerEndpoint = (
        & docker context inspect `
            $activeDockerContext `
            --format '{{.Endpoints.docker.Host}}' 2>$null
    ).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($activeDockerEndpoint)) {
        throw "Docker-Endpunkt für Kontext $activeDockerContext konnte nicht aufgelöst werden."
    }
    $dockerConfigRoot = Assert-AnalyzePathUnderRoot `
        -Path 'C:\rep\cache\SQL_Server_Analyze\docker-config' `
        -AllowedRoot 'C:\rep\cache'
    [IO.Directory]::CreateDirectory($dockerConfigRoot) | Out-Null
    $dockerConfigPath = Join-Path $dockerConfigRoot 'config.json'
    if (-not (Test-Path -LiteralPath $dockerConfigPath -PathType Leaf)) {
        [IO.File]::WriteAllText(
            $dockerConfigPath,
            "{}`n",
            [Text.UTF8Encoding]::new($false)
        )
    }
    $env:DOCKER_CONFIG = $dockerConfigRoot
    $env:DOCKER_HOST = $activeDockerEndpoint
}
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force

$lab = $null
$runDirectory = $null
$scripts = $null
$workerTasks = @()
$failed = $false
try {
    $lab = New-SqlServerLab `
        -Version $Version `
        -Provider $Provider `
        -Profile ([string]$definition.resourceProfile) `
        -Collation 'SQL_Latin1_General_CP1_CS_AS' `
        -SaPassword $SaPassword `
        -StateRoot $StateRoot `
        -LabName "analyze-$($Example.ToLowerInvariant())" `
        -NonInteractive

    $runDirectory = Assert-AnalyzePathUnderRoot `
        -Path (Join-Path 'C:\rep\tmp\SQL_Server_Analyze\example-runs' $lab.RunId) `
        -AllowedRoot 'C:\rep\tmp'
    [IO.Directory]::CreateDirectory($runDirectory) | Out-Null

    # SQL Server container images can accept logins while first-start system
    # database index restoration is still active. Installing the full Analyze
    # framework during that window caused transient tempdb metadata errors on
    # the native Docker host. Keep this bounded and outside SQL_Server_Lab's
    # general readiness contract until the upstream interface exposes a more
    # specific post-start stabilization signal.
    Start-Sleep -Seconds 60

    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $runDirectory
    $scripts = New-AnalyzeExampleRuntimeScripts `
        -Definition $definition `
        -RunDirectory $runDirectory `
        -LabRunId $lab.RunId

    Invoke-AnalyzeLabScript `
        -ScriptPath $framework.Prepare `
        -RunId $lab.RunId `
        -StateRoot $StateRoot `
        -SaPassword $SaPassword | Out-Null
    Invoke-AnalyzeLabScript `
        -ScriptPath $framework.Installer `
        -RunId $lab.RunId `
        -StateRoot $StateRoot `
        -SaPassword $SaPassword | Out-Null
    Invoke-AnalyzeLabScript `
        -ScriptPath $scripts.Setup `
        -RunId $lab.RunId `
        -StateRoot $StateRoot `
        -SaPassword $SaPassword | Out-Null

    if ($Mode -eq 'Interactive') {
        [PSCustomObject]@{
            Status = 'READY_FOR_INTERACTIVE_USE'
            Example = $Example
            Version = $Version
            Provider = $Provider
            RunId = $lab.RunId
            StateRoot = $StateRoot
            RunDirectory = $runDirectory
            SessionScripts = $scripts.Workers
            AnalyzeScript = $scripts.Analyze
            CleanupScript = $scripts.Cleanup
            Removal = "Import-Module '$($labRoot)\SqlServerLab.psd1'; Remove-SqlServerLab -RunId '$($lab.RunId)' -StateRoot '$StateRoot' -Force -Confirm:`$false"
        }
        return
    }

    $connection = Get-AnalyzeLabConnection -RunId $lab.RunId -StateRoot $StateRoot
    $workerIndex = 0
    foreach ($workerScript in $scripts.Workers) {
        $workerIndex++
        $workerTasks += Start-AnalyzeSqlWorkerTask `
            -ScriptPath $workerScript `
            -HostName ([string]$connection.host) `
            -Port ([int]$connection.port) `
            -SaPassword $SaPassword `
            -ScenarioId ([string]$definition.scenarioId) `
            -LabRunId $lab.RunId
        if ($workerIndex -lt $scripts.Workers.Count) {
            Start-Sleep -Seconds 5
        }
    }

    Start-Sleep -Seconds ([int]$definition.workerStartLeadSeconds)
    foreach ($worker in $workerTasks) {
        if ($worker.Task.IsCompleted) {
            if ($worker.Task.IsFaulted) {
                throw "Worker endete vor der Assertion: $($worker.Task.Exception.GetBaseException().Message)"
            }
            throw "Worker endete unerwartet vor der Assertion: $($worker.ScriptPath)"
        }
    }
    if ($scripts.Probe) {
        Invoke-AnalyzeLabScript `
            -ScriptPath $scripts.Probe `
            -RunId $lab.RunId `
            -StateRoot $StateRoot `
            -SaPassword $SaPassword | Out-Null
    }
    Invoke-AnalyzeLabScript `
        -ScriptPath $scripts.Analyze `
        -RunId $lab.RunId `
        -StateRoot $StateRoot `
        -SaPassword $SaPassword | Out-Null

    foreach ($worker in $workerTasks) {
        if (-not $worker.Task.Wait([int]$definition.timeoutSeconds * 1000)) {
            throw "Worker-Timeout für Beispiel $Example."
        }
        if ($worker.Task.IsFaulted) {
            throw "Worker fehlgeschlagen: $($worker.Task.Exception.GetBaseException().Message)"
        }
    }

    [PSCustomObject]@{
        Status = 'PASS'
        Example = $Example
        Version = $Version
        Provider = $Provider
        ScenarioId = [string]$definition.scenarioId
        Analyzer = [string]$definition.primaryAnalyzer
        FindingCode = [string]$definition.findingCode
        Cleanup = 'PENDING'
    }
}
catch {
    $failed = $true
    throw
}
finally {
    foreach ($worker in $workerTasks) {
        if (-not $worker.Task.IsCompleted) {
            try {
                $worker.Command.Cancel()
            }
            catch {
                Write-Verbose "Workerabbruch meldete: $($_.Exception.Message)"
            }
        }
        $worker.Command.Dispose()
        $worker.Connection.Dispose()
    }

    $preserve = $failed -and $KeepOnFailure
    if ($lab -and $Mode -eq 'Verify' -and -not $preserve) {
        if ($scripts -and (Test-Path -LiteralPath $scripts.Cleanup -PathType Leaf)) {
            try {
                Invoke-AnalyzeLabScript `
                    -ScriptPath $scripts.Cleanup `
                    -RunId $lab.RunId `
                    -StateRoot $StateRoot `
                    -SaPassword $SaPassword | Out-Null
            }
            catch {
                Write-Warning "SQL-Cleanup meldete einen Fehler; der Lab-Lifecycle wird dennoch ausgeführt: $($_.Exception.Message)"
            }
        }
        Remove-SqlServerLab `
            -RunId $lab.RunId `
            -StateRoot $StateRoot `
            -Force `
            -Confirm:$false | Out-Null
    }
    elseif ($preserve) {
        Write-Warning "Fehlgeschlagenes Lab wurde absichtlich erhalten. RunId: $($lab.RunId)"
    }

    if ($null -eq $originalDockerConfig) {
        Remove-Item Env:DOCKER_CONFIG -ErrorAction SilentlyContinue
    }
    else {
        $env:DOCKER_CONFIG = $originalDockerConfig
    }
    if ($null -eq $originalDockerHost) {
        Remove-Item Env:DOCKER_HOST -ErrorAction SilentlyContinue
    }
    else {
        $env:DOCKER_HOST = $originalDockerHost
    }
    if ($null -eq $originalTemp) {
        Remove-Item Env:TEMP -ErrorAction SilentlyContinue
    }
    else {
        $env:TEMP = $originalTemp
    }
    if ($null -eq $originalTmp) {
        Remove-Item Env:TMP -ErrorAction SilentlyContinue
    }
    else {
        $env:TMP = $originalTmp
    }
}
