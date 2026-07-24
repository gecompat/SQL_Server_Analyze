Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QuickTestLabRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..')
)

foreach ($relativePath in @(
        'Private/Common.ps1'
        'Public/Invoke-QuickTestPreflight.ps1'
    )) {
    . (Join-Path $PSScriptRoot $relativePath)
}

Export-ModuleMember -Function @(
    'Get-QuickTestDefaultPorts'
    'Get-QuickTestResourceProfile'
    'Invoke-QuickTestPreflight'
    'New-QuickTestPassword'
    'Resolve-QuickTestPorts'
    'Test-QuickTestPassword'
)
