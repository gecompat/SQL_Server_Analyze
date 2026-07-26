#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Menu', 'Setup', 'Start', 'Status', 'Stop', 'Remove')]
    [string] $Action = 'Menu'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QuickStartRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:EnvPath = Join-Path $PSScriptRoot '.env'
$script:MarkerFileName = '.sql-server-analyze-hyperv-quickstart.json'
$script:MarkerOwner = 'SQL_SERVER_ANALYZE_HYPERV_QUICKSTART'
$script:SwitchName = 'SQL_Server_Analyze_Lab'
$script:NatName = 'SQL_Server_Analyze_Lab_NAT'
$script:NatSubnet = '172.30.0.0/24'
$script:GatewayAddress = '172.30.0.1'
$script:PrefixLength = 24
$script:VmIpAddresses = @{
    '2019' = '172.30.0.19'
    '2022' = '172.30.0.22'
    '2025' = '172.30.0.25'
}
$script:VmNames = @{
    '2019' = 'SQL_Analyze_2019'
    '2022' = 'SQL_Analyze_2022'
    '2025' = 'SQL_Analyze_2025'
}
$script:ResourceProfiles = @{
    'Compact' = @{ StartupBytes = 4GB; MinimumBytes = 2GB; MaximumBytes = 6GB; ProcessorCount = 2; VhdMaxSizeBytes = 60GB }
    'Standard' = @{ StartupBytes = 8GB; MinimumBytes = 4GB; MaximumBytes = 12GB; ProcessorCount = 4; VhdMaxSizeBytes = 80GB }
    'Performance' = @{ StartupBytes = 16GB; MinimumBytes = 8GB; MaximumBytes = 24GB; ProcessorCount = 8; VhdMaxSizeBytes = 120GB }
}

# Verify Hyper-V availability
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    throw @"
Hyper-V PowerShell-Module nicht gefunden.
Voraussetzungen:
- Windows 10/11 Pro oder Windows Server mit aktivierter Hyper-V-Rolle
- PowerShell 7+ als Administrator
- Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
"@
}

$internalRoot = Join-Path $PSScriptRoot 'Internal'
foreach ($internalScript in @(
        'Common.ps1',
        'PathSafety.ps1',
        'Configuration.ps1',
        'VmProvisioning.ps1',
        'SqlInstall.ps1',
        'Runtime.ps1',
        'Lifecycle.ps1'
    )) {
    $scriptPath = Join-Path $internalRoot $internalScript
    if (Test-Path -LiteralPath $scriptPath) {
        . $scriptPath
    }
    else {
        Write-Warning "Internes Modul nicht gefunden: $internalScript"
    }
}

Write-Host 'SQL_Server_Analyze Hyper-V QuickStart'
Write-Host "Quelle: $script:QuickStartRoot"

switch ($Action) {
    'Menu' { Invoke-Menu }
    'Setup' { Invoke-Setup }
    'Start' { Start-Environment }
    'Status' { Show-Status }
    'Stop' { Stop-Environment }
    'Remove' { Remove-Environment }
}
