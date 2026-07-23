Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:DiagnosticLabModuleRoot = $PSScriptRoot
$script:DiagnosticLabRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '../../..')
)

$privateFiles = @(
    'Private/Configuration.ps1'
    'Private/State.ps1'
    'Private/HostCapability.ps1'
    'Private/SecretProvider.ps1'
    'Private/HostAdapters/LinuxNative.ps1'
    'Private/HostAdapters/WindowsHyperV.ps1'
    'Private/HostAdapters/RemoteHost.ps1'
)

$publicFiles = @(
    'Public/Invoke-LabPreflight.ps1'
    'Public/Get-LabStatus.ps1'
    'Public/Invoke-LabCleanup.ps1'
)

foreach ($relativePath in @($privateFiles + $publicFiles)) {
    . (Join-Path $PSScriptRoot $relativePath)
}

Export-ModuleMember -Function @(
    'Get-LabStatus'
    'Invoke-LabCleanup'
    'Invoke-LabPreflight'
)
