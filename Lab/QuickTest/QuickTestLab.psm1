Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QuickTestLabRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$script:QuickTestRepositoryRoot = [IO.Path]::GetFullPath(
    (Join-Path $script:QuickTestLabRoot '..')
)

$privateFiles = @(
    'Private/Common.ps1'
    'Private/Runtime.ps1'
    'Private/Interactive.ps1'
)
$publicFiles = @(
    'Public/Invoke-QuickTestPreflight.ps1'
    'Public/Install-QuickTestLab.ps1'
    'Public/Get-QuickTestLabStatus.ps1'
    'Public/Remove-QuickTestLab.ps1'
    'Public/Invoke-QuickTestEntryPoint.ps1'
)

foreach ($relativePath in @($privateFiles + $publicFiles)) {
    . (Join-Path $PSScriptRoot $relativePath)
}

Export-ModuleMember -Function @(
    'Get-QuickTestDefaultPorts'
    'Get-QuickTestLabStatus'
    'Get-QuickTestResourceProfile'
    'Install-QuickTestLab'
    'Invoke-QuickTestEntryPoint'
    'Invoke-QuickTestPreflight'
    'New-QuickTestPassword'
    'Remove-QuickTestLab'
    'Resolve-QuickTestPorts'
    'Test-QuickTestPassword'
    'Test-QuickTestPathWithinRoot'
)
