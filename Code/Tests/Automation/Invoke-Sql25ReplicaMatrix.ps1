[CmdletBinding()]
param(
    [string[]]$SqlVersions = @('2019', '2022', '2025'),
    [int]$StartupTimeoutSeconds = 240,
    [int]$CommandTimeoutSeconds = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sqlcmdCommand = Get-Command sqlcmd -ErrorAction Stop
$dockerCommand = Get-Command docker -ErrorAction Stop

$versionMap = @{
    '2019' = @{ Image = 'mcr.microsoft.com/mssql/server:2019-latest'; Port = 14331 }
    '2022' = @{ Image = 'mcr.microsoft.com/mssql/server:2022-latest'; Port = 14332 }
    '2025' = @{ Image = 'mcr.microsoft.com/mssql/server:2025-latest'; Port = 14333 }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [Parameter(Mandatory)] [string[]]$ArgumentList,
        [switch]$AllowFailure
    )

    & $FilePath @ArgumentList
    $exitCode = $LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "Native command failed with exit code $exitCode: $FilePath"
    }
    return $exitCode
}

function New-SyntheticSqlPassword {
    $randomPart = [Guid]::NewGuid().ToString('N')
    return "SqlA!${randomPart}x9"
}

function Wait-SqlReady {
    param(
        [Parameter(Mandatory)] [string]$Server,
        [Parameter(Mandatory)] [string]$Password,
        [Parameter(Mandatory)] [string]$ContainerName
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        & $sqlcmdCommand.Source -S $Server -U sa -P $Password -C -b -l 5 -Q 'SET NOCOUNT ON; SELECT 1;' *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }

        $state = (& $dockerCommand.Source inspect --format '{{.State.Status}}' $ContainerName 2>$null)
        if ($LASTEXITCODE -ne 0 -or $state -eq 'exited' -or $state -eq 'dead') {
            & $dockerCommand.Source logs --tail 200 $ContainerName
            throw "SQL Server container stopped before readiness: $ContainerName"
        }
        Start-Sleep -Seconds 3
    }

    & $dockerCommand.Source logs --tail 200 $ContainerName
    throw "SQL Server readiness timeout: $ContainerName"
}

function Invoke-SqlFile {
    param(
        [Parameter(Mandatory)] [string]$Server,
        [Parameter(Mandatory)] [string]$Password,
        [Parameter(Mandatory)] [string]$InputFile,
        [Parameter(Mandatory)] [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $arguments = @(
            '-S', $Server,
            '-U', 'sa',
            '-P', $Password,
            '-C',
            '-b',
            '-r', '1',
            '-l', '30',
            '-t', $CommandTimeoutSeconds.ToString(),
            '-i', $InputFile
        )
        Invoke-NativeCommand -FilePath $sqlcmdCommand.Source -ArgumentList $arguments | Out-Null
    }
    finally {
        Pop-Location
    }
}

foreach ($sqlVersion in $SqlVersions) {
    if (-not $versionMap.ContainsKey($sqlVersion)) {
        throw "Unsupported SQL version requested: $sqlVersion"
    }

    $definition = $versionMap[$sqlVersion]
    $image = [string]$definition.Image
    $port = [int]$definition.Port
    $containerName = "sqla-sql25-005-$sqlVersion"
    $databaseName = "SqlAnalyzeSql25_005_$sqlVersion"
    $server = "127.0.0.1,$port"
    $password = New-SyntheticSqlPassword
    Write-Host "::add-mask::$password"

    $workingRoot = Join-Path $env:RUNNER_TEMP "sql25-005-$sqlVersion"
    $workingCode = Join-Path $workingRoot 'Code'

    Write-Host "SQL25-005 MATRIX START SQL Server $sqlVersion"

    try {
        Invoke-NativeCommand -FilePath $dockerCommand.Source -ArgumentList @('rm', '-f', $containerName) -AllowFailure | Out-Null
        if (Test-Path -LiteralPath $workingRoot) {
            Remove-Item -LiteralPath $workingRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path $workingRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'Code') -Destination $workingCode -Recurse -Force

        Get-ChildItem -LiteralPath $workingCode -Recurse -Filter '*.sql' -File | ForEach-Object {
            $content = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
            $content = $content.Replace('[DeineDatenbank]', "[$databaseName]")
            [IO.File]::WriteAllText($_.FullName, $content, [Text.UTF8Encoding]::new($false))
        }

        Invoke-NativeCommand -FilePath $dockerCommand.Source -ArgumentList @('pull', $image) | Out-Null
        Invoke-NativeCommand -FilePath $dockerCommand.Source -ArgumentList @(
            'run', '-d',
            '--name', $containerName,
            '--hostname', $containerName,
            '--cpus', '2',
            '--memory', '4g',
            '--memory-swap', '4g',
            '--shm-size', '1g',
            '-e', 'ACCEPT_EULA=Y',
            '-e', 'MSSQL_PID=Developer',
            '-e', "MSSQL_SA_PASSWORD=$password",
            '-e', 'MSSQL_COLLATION=SQL_Latin1_General_CP1_CS_AS',
            '-p', "${port}:1433",
            $image
        ) | Out-Null

        Wait-SqlReady -Server $server -Password $password -ContainerName $containerName

        $createDatabaseSql = @"
SET NOCOUNT ON;
IF DB_ID(N'$databaseName') IS NOT NULL
BEGIN
    ALTER DATABASE [$databaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$databaseName];
END;
CREATE DATABASE [$databaseName] COLLATE SQL_Latin1_General_CP1_CS_AS;
ALTER DATABASE [$databaseName] SET RECOVERY SIMPLE;
ALTER DATABASE [$databaseName] SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = ALL,
    WAIT_STATS_CAPTURE_MODE = ON
);
"@
        & $sqlcmdCommand.Source -S $server -U sa -P $password -C -b -l 30 -t 60 -Q $createDatabaseSql
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create synthetic framework database for SQL Server $sqlVersion."
        }

        Invoke-SqlFile -Server $server -Password $password -InputFile 'Install_All.sql' -WorkingDirectory (Join-Path $workingCode 'Install')
        Invoke-SqlFile -Server $server -Password $password -InputFile 'Run_Release_Gate.sql' -WorkingDirectory (Join-Path $workingCode 'Tests')

        & $sqlcmdCommand.Source -S $server -U sa -P $password -C -b -l 30 -t 60 -d $databaseName -Q "SET NOCOUNT ON; SELECT CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) AS ProductMajorVersion, FrameworkVersion, ContractVersion FROM monitor.FrameworkVersion WHERE FrameworkName=N'SQLServerMonitoringFramework';"
        if ($LASTEXITCODE -ne 0) {
            throw "Final framework version verification failed for SQL Server $sqlVersion."
        }

        Write-Host "SQL25-005 MATRIX PASS SQL Server $sqlVersion"
    }
    catch {
        Write-Host "SQL25-005 MATRIX FAIL SQL Server $sqlVersion"
        & $dockerCommand.Source logs --tail 200 $containerName 2>$null
        throw
    }
    finally {
        Invoke-NativeCommand -FilePath $dockerCommand.Source -ArgumentList @('rm', '-f', $containerName) -AllowFailure | Out-Null
        if (Test-Path -LiteralPath $workingRoot) {
            Remove-Item -LiteralPath $workingRoot -Recurse -Force
        }
    }
}

Write-Host 'SQL25-005 DOCKER MATRIX PASS'
