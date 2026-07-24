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
    'Private/ContainerRuntime.ps1'
    'Private/Installer.ps1'
    'Private/ResourceMeasurement.ps1'
    'Private/ScenarioRuntime.ps1'
)

$publicFiles = @(
    'Public/Invoke-LabPreflight.ps1'
    'Public/Get-LabStatus.ps1'
    'Public/Invoke-LabCleanup.ps1'
    'Public/Invoke-LabUp.ps1'
    'Public/Invoke-LabScenario.ps1'
    'Public/Test-LabScenario.ps1'
    'Public/Invoke-LabVersionMatrix.ps1'
)

foreach ($relativePath in @($privateFiles + $publicFiles)) {
    . (Join-Path $PSScriptRoot $relativePath)
}

Export-ModuleMember -Function @(
    'Get-LabStatus'
    'Invoke-LabCleanup'
    'Invoke-LabPreflight'
    'Invoke-LabScenario'
    'Invoke-LabUp'
    'Invoke-LabVersionMatrix'
    'Test-LabScenario'
)
