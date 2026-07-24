function Install-LabContainerFramework {
    [CmdletBinding()]
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

    if ($RuntimeCommand -notmatch '(?i)(docker|podman)(?:\.exe)?$') {
        throw 'The container runtime command is outside the supported contract.'
    }
    if (-not (Test-Path -LiteralPath $RunDirectory -PathType Container)) {
        throw 'The local ignored run directory does not exist.'
    }

    Install-LabFramework `
        -DockerCommand $RuntimeCommand `
        -ContainerId $ContainerId `
        -RunDirectory $RunDirectory

    return [pscustomobject] @{
        Runtime = $Runtime
        ContainerId = $ContainerId
        FrameworkDatabase = 'LabAnalyze'
        Status = 'READY'
    }
}
