function New-LabSwitch {
    $existing = Get-VMSwitch -Name $script:SwitchName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Hyper-V Switch '$($script:SwitchName)' existiert bereits."
        return
    }

    Write-Host "Erstelle internen Hyper-V Switch '$($script:SwitchName)'..."
    New-VMSwitch -Name $script:SwitchName -SwitchType Internal | Out-Null

    # Adapter und Gateway konfigurieren
    $adapter = Get-NetAdapter | Where-Object { $_.Name -like "*$($script:SwitchName)*" } | Select-Object -First 1
    if ($null -eq $adapter) {
        throw "Netzwerkadapter für Switch '$($script:SwitchName)' nicht gefunden."
    }
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex `
        -IPAddress $script:GatewayAddress `
        -PrefixLength $script:PrefixLength `
        -ErrorAction SilentlyContinue | Out-Null

    # NAT erstellen
    $existingNat = Get-NetNat -Name $script:NatName -ErrorAction SilentlyContinue
    if (-not $existingNat) {
        Write-Host "Erstelle NAT '$($script:NatName)' ($($script:NatSubnet))..."
        New-NetNat -Name $script:NatName -InternalIPInterfaceAddressPrefix $script:NatSubnet | Out-Null
    }
}

function Remove-LabSwitch {
    $existingNat = Get-NetNat -Name $script:NatName -ErrorAction SilentlyContinue
    if ($existingNat) {
        Write-Host "Entferne NAT '$($script:NatName)'..."
        Remove-NetNat -Name $script:NatName -Confirm:$false
    }

    $existing = Get-VMSwitch -Name $script:SwitchName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Entferne Hyper-V Switch '$($script:SwitchName)'..."
        Remove-VMSwitch -Name $script:SwitchName -Force
    }
}

function New-DifferencingDisk {
    param(
        [Parameter(Mandatory)][string] $ParentPath,
        [Parameter(Mandatory)][string] $DiffPath
    )

    if (Test-Path -LiteralPath $DiffPath) {
        Write-Host "Differencing Disk existiert bereits: $DiffPath"
        return
    }

    $diffDir = [IO.Path]::GetDirectoryName($DiffPath)
    if (-not (Test-Path -LiteralPath $diffDir)) {
        New-Item -Path $diffDir -ItemType Directory -Force | Out-Null
    }

    Write-Host "Erstelle Differencing Disk: $DiffPath"
    Write-Host "  Parent: $ParentPath"
    New-VHD -Path $DiffPath -ParentPath $ParentPath -Differencing | Out-Null
}

function New-LabVm {
    param(
        [Parameter(Mandatory)][string] $Version,
        [Parameter(Mandatory)][string] $VhdPath,
        [Parameter(Mandatory)][hashtable] $Profile
    )

    $vmName = $script:VmNames[$Version]
    $existing = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "VM '$vmName' existiert bereits."
        return
    }

    Write-Section "Erstelle VM: $vmName"

    $vm = New-VM -Name $vmName `
        -Generation 2 `
        -MemoryStartupBytes $Profile.StartupBytes `
        -VHDPath $VhdPath `
        -SwitchName $script:SwitchName

    # Konfiguration
    Set-VMMemory -VM $vm -DynamicMemoryEnabled $true `
        -MinimumBytes $Profile.MinimumBytes `
        -MaximumBytes $Profile.MaximumBytes

    Set-VMProcessor -VM $vm -Count $Profile.ProcessorCount

    # Secure Boot deaktivieren (Flexibilität)
    Set-VMFirmware -VM $vm -EnableSecureBoot Off

    # Checkpoints deaktivieren
    Set-VM -VM $vm -CheckpointType Disabled

    # Integration Services
    Enable-VMIntegrationService -VM $vm -Name 'Guest Service Interface' -ErrorAction SilentlyContinue

    Write-Host "VM '$vmName' erstellt ($(($Profile.StartupBytes / 1GB))GB RAM, $($Profile.ProcessorCount) vCPUs)."
}

function Wait-VmReady {
    param(
        [Parameter(Mandatory)][string] $VmName,
        [int] $TimeoutSeconds = 600
    )

    Write-Host "Warte auf VM '$VmName' Bereitschaft..."
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    # Warte auf Heartbeat
    while ((Get-Date) -lt $deadline) {
        $vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
        if ($null -ne $vm -and $vm.Heartbeat -eq 'OkApplicationsHealthy') {
            break
        }
        if ($null -ne $vm -and $vm.State -ne 'Running') {
            throw "VM '$VmName' ist nicht im Zustand 'Running' (Zustand: $($vm.State))."
        }
        Start-Sleep -Seconds 5
    }

    if ((Get-Date) -ge $deadline) {
        throw "Timeout: VM '$VmName' wurde nicht innerhalb von $TimeoutSeconds Sekunden bereit."
    }
    Write-Host "VM '$VmName' ist bereit (Heartbeat OK)."
}

function Invoke-VmPowerShell {
    param(
        [Parameter(Mandatory)][string] $VmName,
        [Parameter(Mandatory)][scriptblock] $ScriptBlock,
        [pscredential] $Credential,
        [int] $TimeoutSeconds = 300
    )

    $params = @{
        VMName = $VmName
        ScriptBlock = $ScriptBlock
    }
    if ($null -ne $Credential) {
        $params['Credential'] = $Credential
    }

    Invoke-Command @params -ErrorAction Stop
}

function Set-VmStaticIp {
    param(
        [Parameter(Mandatory)][string] $VmName,
        [Parameter(Mandatory)][string] $IpAddress,
        [Parameter(Mandatory)][pscredential] $Credential
    )

    Write-Host "Konfiguriere statische IP $IpAddress für '$VmName'..."
    Invoke-VmPowerShell -VmName $VmName -Credential $Credential -ScriptBlock {
        param($Ip, $Gateway, $Prefix)
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($null -eq $adapter) { throw 'Kein aktiver Netzwerkadapter in der VM.' }
        Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceIndex $adapter.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $Ip -PrefixLength $Prefix -DefaultGateway $Gateway | Out-Null
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @('8.8.8.8', '1.1.1.1')
    } -ArgumentList @($IpAddress, $script:GatewayAddress, $script:PrefixLength)
}
