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

    return [pscustomobject] @{
        Status = 'READY'
        Runtime = $Runtime
        ContainerId = $ContainerId
        FrameworkDatabase = 'LabAnalyze'
    }
}
