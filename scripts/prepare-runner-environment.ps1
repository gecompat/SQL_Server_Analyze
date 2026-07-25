<#
Prepare runner host for Docker and Hyper-V based tests.
Run as Administrator.
#>
param(
    [string]$DockerDataPath = "D:\DockerData",
    [string]$HyperVVMPath = "E:\HyperV",
    [string]$VMSwitchName = "SQLServerAnalyzeSwitch",
    [switch]$CreateVMSwitch = $true,
    [string]$ServiceAccount = $null
)

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run elevated (Run as Administrator)."
    exit 1
}

Write-Host "=== Preparing directories ==="
foreach ($p in @($DockerDataPath, $HyperVVMPath)) {
    if (-not (Test-Path $p)) {
        New-Item -Path $p -ItemType Directory -Force | Out-Null
        Write-Host "Created: $p"
    } else {
        Write-Host "Exists: $p"
    }
}

Write-Host "=== Ensure Hyper-V feature ==="
$hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
if ($hv -and $hv.State -eq 'Enabled') {
    Write-Host "Hyper-V is already enabled."
} else {
    Write-Host "Enabling Hyper-V feature (requires reboot)..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    Write-Host "Hyper-V enabled. Reboot required to complete activation."
}

Write-Host "=== Docker runtime detection ==="
$dockerExe = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerExe) {
    Write-Host "Docker CLI found: $($dockerExe.Source)"
    # If Docker Engine (service) is installed, configure data-root
    $svc = Get-Service -Name docker -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "Docker service detected. Configuring data-root to: $DockerDataPath"
        $configPath = 'C:\ProgramData\Docker\config'
        if (-not (Test-Path $configPath)) { New-Item -Path $configPath -ItemType Directory -Force | Out-Null }
        $daemonFile = Join-Path $configPath 'daemon.json'
        $daemon = @{}
        if (Test-Path $daemonFile) {
            try { $daemon = Get-Content $daemonFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $daemon = @{} }
        }
        $daemon["data-root"] = $DockerDataPath
        $daemon | ConvertTo-Json -Depth 5 | Set-Content -Path $daemonFile -Encoding UTF8
        Write-Host "Wrote $daemonFile (restart Docker service required)"
        Write-Host "Restarting Docker service..."
        try { Restart-Service -Name docker -Force -ErrorAction Stop; Write-Host "Docker service restarted." } catch { Write-Warning "Restart failed - please restart Docker Desktop/Service manually." }
    } else {
        Write-Host "No Docker service found (likely Docker Desktop). Manual configuration of Docker Desktop data-root may be required. See README." 
    }
} else {
    Write-Warning "Docker CLI not found. Install Docker Desktop or Docker Engine before running tests."
}

if ($CreateVMSwitch) {
    Write-Host "=== Ensure Hyper-V virtual switch: $VMSwitchName ==="
    $exists = Get-VMSwitch -Name $VMSwitchName -ErrorAction SilentlyContinue
    if ($exists) {
        Write-Host "VMSwitch '$VMSwitchName' already exists."
    } else {
        Write-Host "Creating internal VMSwitch named '$VMSwitchName'..."
        New-VMSwitch -Name $VMSwitchName -SwitchType Internal | Out-Null
        Write-Host "Created internal VMSwitch."
        # Create NAT network for the switch
        $natName = "NAT_$VMSwitchName"
        $natSubnet = "172.20.0.0/16"
        try {
            New-NetIPAddress -IPAddress 172.20.0.1 -PrefixLength 16 -InterfaceAlias "vEthernet ($VMSwitchName)" -ErrorAction Stop | Out-Null
            New-NetNat -Name $natName -InternalIPInterfaceAddressPrefix $natSubnet -ErrorAction Stop | Out-Null
            Write-Host "Created NAT $natName on $natSubnet"
        } catch {
            Write-Warning "NAT creation failed or already exists: $_"
        }
    }
}

Write-Host "=== Service account and group membership ==="
if ($ServiceAccount) {
    Write-Host "Adding $ServiceAccount to required groups (docker-users, 'Hyper-V Administrators') if present..."
    try { Add-LocalGroupMember -Group 'docker-users' -Member $ServiceAccount -ErrorAction Stop; Write-Host "Added to docker-users" } catch { Write-Warning "docker-users group or adding failed: $_" }
    try { Add-LocalGroupMember -Group 'Hyper-V Administrators' -Member $ServiceAccount -ErrorAction Stop; Write-Host "Added to Hyper-V Administrators" } catch { Write-Warning "Hyper-V group or adding failed: $_" }
} else {
    Write-Host "No service account supplied. Remember to grant the runner service account: 'Log on as a service', membership in 'docker-users' and 'Hyper-V Administrators' as needed."
}

Write-Host "=== Cleanup helpers (examples) ==="
Write-Host "To clean Docker after tests: docker system prune -af && docker volume prune -f"
Write-Host "To remove test Hyper-V VMs (matching prefix): Get-VM | Where-Object Name -Like 'sqltest-*' | Remove-VM -Force"

Write-Host "=== Done ==="
Write-Host "Review README: Documentation/Lab/Runner_Environment_Prepare.md for manual steps and notes."
