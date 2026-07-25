[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$admin = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = @(Get-CimInstance Win32_Processor | Select-Object -First 1)[0]
$systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"

Write-Output "CAP_RUNNER=$env:RUNNER_NAME"
Write-Output "CAP_ADMIN=$admin"
Write-Output "CAP_OS=$($os.Caption)|$($os.Version)|$($os.BuildNumber)|$($os.OSArchitecture)"
Write-Output "CAP_CPU=$($cs.NumberOfLogicalProcessors)|VirtFirmware=$($cpu.VirtualizationFirmwareEnabled)|SLAT=$($cpu.SecondLevelAddressTranslationExtensions)|Hypervisor=$($cs.HypervisorPresent)"
Write-Output "CAP_MEMORY_GIB=$([math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 2))"
Write-Output "CAP_SYSTEM_DISK_GIB=$([math]::Round([double]$systemDrive.Size / 1GB, 2))|Free=$([math]::Round([double]$systemDrive.FreeSpace / 1GB, 2))"

foreach ($featureName in @(
        'Microsoft-Hyper-V-All',
        'Containers',
        'VirtualMachinePlatform',
        'Microsoft-Windows-Subsystem-Linux'
    )) {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName
        Write-Output "CAP_FEATURE_$($featureName.Replace('-', '_'))=$($feature.State)|Restart=$($feature.RestartNeeded)"
    }
    catch {
        Write-Output "CAP_FEATURE_$($featureName.Replace('-', '_'))=UNAVAILABLE"
    }
}

foreach ($tool in @(
        'pwsh', 'git', 'python', 'python3', 'winget', 'choco',
        'docker', 'podman', 'wsl', 'sqlcmd', 'dotnet'
    )) {
    $command = Get-Command -Name $tool -ErrorAction SilentlyContinue
    Write-Output "CAP_TOOL_$($tool.ToUpperInvariant())=$($null -ne $command)"
}

$dockerReachable = $false
$dockerOsType = ''
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        $dockerOsType = [string] (& docker info --format '{{.OSType}}' 2>$null)
        $dockerReachable = $LASTEXITCODE -eq 0 -and
            -not [string]::IsNullOrWhiteSpace($dockerOsType)
    }
    catch {}
}
Write-Output "CAP_DOCKER_SERVER=$dockerReachable|OSType=$dockerOsType"

$hyperVModule = [bool] (Get-Module -ListAvailable -Name Hyper-V)
$hyperVHost = $false
if ($hyperVModule) {
    try {
        $null = Get-VMHost -ErrorAction Stop
        $hyperVHost = $true
    }
    catch {}
}
Write-Output "CAP_HYPERV=Module=$hyperVModule|Host=$hyperVHost"

$sqlServices = @(
    Get-Service -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^(MSSQL|SQLAgent|SQLBrowser)' -or
            $_.DisplayName -match '^SQL Server'
        }
)
Write-Output "CAP_SQL_SERVICE_COUNT=$($sqlServices.Count)"

$wslReady = $false
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    try {
        $null = & wsl --status 2>$null
        $wslReady = $LASTEXITCODE -eq 0
    }
    catch {}
}
Write-Output "CAP_WSL_READY=$wslReady"
