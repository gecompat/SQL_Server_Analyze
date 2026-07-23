function New-LabStandaloneInstaller {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RunDirectory
    )

    $installerDirectory = Join-Path $RunDirectory 'runtime/installer'
    [IO.Directory]::CreateDirectory($installerDirectory) | Out-Null
    $outputPath = Join-Path $installerDirectory 'Install_All.generated.sql'
    $builderPath = [IO.Path]::GetFullPath(
        (Join-Path $script:DiagnosticLabRoot '../Code/Install/Build-StandaloneInstaller.ps1')
    )
    & $builderPath `
        -RepositoryRoot ([IO.Path]::GetFullPath(
            (Join-Path $script:DiagnosticLabRoot '..')
        )) `
        -OutputPath $outputPath
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw 'The standalone framework installer was not generated.'
    }

    $content = [IO.File]::ReadAllText($outputPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('[DeineDatenbank]', '[LabAnalyze]')
    [IO.File]::WriteAllText(
        $outputPath,
        $content,
        [Text.UTF8Encoding]::new($false)
    )
    return $outputPath
}

function Invoke-LabSqlFile {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $DockerCommand,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter(Mandatory)]
        [ValidatePattern('^/lab/runtime/[A-Za-z0-9_./-]+\.sql$')]
        [string] $ContainerSqlPath
    )

    $command = (
        'SQLCMDPASSWORD="$MSSQL_SA_PASSWORD" ' +
        '/opt/mssql-tools18/bin/sqlcmd -C -b -S localhost -U sa ' +
        '-h -1 -W -i "' + $ContainerSqlPath + '"'
    )
    return Invoke-LabExternalCommand `
        -FilePath $DockerCommand `
        -Arguments @('exec', $ContainerId, '/bin/bash', '-c', $command)
}

function Install-LabFramework {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DockerCommand,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter(Mandatory)]
        [string] $RunDirectory
    )

    $installerPath = New-LabStandaloneInstaller -RunDirectory $RunDirectory
    $preparePath = Join-Path (
        Split-Path -Parent $installerPath
    ) 'Prepare_Framework_Database.sql'
    $prepareSql = @'
SET NOCOUNT ON;
IF DB_ID(N'LabAnalyze') IS NULL
BEGIN
    CREATE DATABASE [LabAnalyze]
    COLLATE SQL_Latin1_General_CP1_CS_AS;
END;
'@
    [IO.File]::WriteAllText(
        $preparePath,
        $prepareSql,
        [Text.UTF8Encoding]::new($false)
    )

    Invoke-LabSqlFile `
        -DockerCommand $DockerCommand `
        -ContainerId $ContainerId `
        -ContainerSqlPath '/lab/runtime/installer/Prepare_Framework_Database.sql' |
        Out-Null
    Invoke-LabSqlFile `
        -DockerCommand $DockerCommand `
        -ContainerId $ContainerId `
        -ContainerSqlPath '/lab/runtime/installer/Install_All.generated.sql' |
        Out-Null
}
