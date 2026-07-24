function Install-LabContainerFramework {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [string] $RuntimeCommand,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter(Mandatory)]
        [string] $RunDirectory
    )

    if (-not (Test-Path -LiteralPath $RunDirectory -PathType Container)) {
        throw 'The quick-test run directory does not exist.'
    }
    if (-not (Get-Command -Name $RuntimeCommand -ErrorAction SilentlyContinue)) {
        throw 'The selected container runtime command is unavailable.'
    }

    Install-LabFramework `
        -DockerCommand $RuntimeCommand `
        -ContainerId $ContainerId `
        -RunDirectory $RunDirectory

    $verificationDirectory = Join-Path $RunDirectory 'runtime/installer'
    $verificationPath = Join-Path $verificationDirectory 'Verify_Framework.sql'
    $verificationSql = @'
SET NOCOUNT ON;
IF DB_ID(N'LabAnalyze') IS NULL
    THROW 51000, 'Framework database is missing.', 1;
IF NOT EXISTS
(
    SELECT 1
    FROM [LabAnalyze].[sys].[schemas] AS s
    WHERE s.[name] = N'monitor'
)
    THROW 51000, 'Framework schema is missing.', 1;
SELECT N'FRAMEWORK_READY';
'@
    [IO.File]::WriteAllText(
        $verificationPath,
        $verificationSql,
        [Text.UTF8Encoding]::new($false)
    )

    $verification = Invoke-LabSqlFile `
        -DockerCommand $RuntimeCommand `
        -ContainerId $ContainerId `
        -ContainerSqlPath '/lab/runtime/installer/Verify_Framework.sql'
    if ('FRAMEWORK_READY' -notin @($verification)) {
        throw 'Framework installation verification did not return the expected marker.'
    }

    return [pscustomobject] @{
        Status = 'INSTALLED'
        Runtime = $Runtime
        ContainerId = $ContainerId
        FrameworkDatabase = 'LabAnalyze'
    }
}
