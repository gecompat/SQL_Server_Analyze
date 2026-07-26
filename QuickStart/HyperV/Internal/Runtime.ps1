function Start-Environment {
    Write-Section 'VMs starten'
    $config = Read-EnvFile -Path $script:EnvPath
    if ($config.Count -eq 0) {
        throw 'Keine Konfiguration gefunden. Bitte zuerst Setup ausführen.'
    }

    $versions = $config['SQL_VERSIONS'] -split ','
    foreach ($version in $versions) {
        $vmName = $script:VmNames[$version]
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($null -eq $vm) {
            Write-Warning "VM '$vmName' nicht gefunden. Übersprungen."
            continue
        }
        if ($vm.State -eq 'Running') {
            Write-Host "VM '$vmName' läuft bereits."
            continue
        }
        Write-Host "Starte VM '$vmName'..."
        Start-VM -Name $vmName
    }

    # Auf SQL-Bereitschaft warten
    Write-Host ''
    foreach ($version in $versions) {
        $vmName = $script:VmNames[$version]
        $ip = $script:VmIpAddresses[$version]
        Write-Host "Warte auf SQL Server $version ($ip)..."
        $ready = $false
        for ($i = 0; $i -lt 60; $i++) {
            if (Test-SqlConnection -ServerInstance "$ip,1433" -Password $config['SA_PASSWORD'] -TimeoutSeconds 3) {
                $ready = $true
                break
            }
            Start-Sleep -Seconds 5
        }
        if ($ready) {
            Write-Host "  SQL Server $version bereit."
        }
        else {
            Write-Warning "  SQL Server $version nicht erreichbar nach 5 Minuten."
        }
    }
}

function Show-Status {
    Write-Section 'Hyper-V QuickStart Status'
    $config = Read-EnvFile -Path $script:EnvPath
    if ($config.Count -eq 0) {
        Write-Host 'Keine Konfiguration gefunden.'
        return
    }

    Write-Host "Scope-ID: $($config['SCOPE_ID'])"
    Write-Host "Profil:   $($config['RESOURCE_PROFILE'])"
    Write-Host "Lab-Root: $($config['LAB_ROOT'])"
    Write-Host ''

    $versions = $config['SQL_VERSIONS'] -split ','
    foreach ($version in $versions) {
        $vmName = $script:VmNames[$version]
        $ip = $script:VmIpAddresses[$version]
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue

        $state = if ($null -eq $vm) { 'NICHT VORHANDEN' } else { $vm.State.ToString() }
        $sqlStatus = 'unbekannt'
        if ($null -ne $vm -and $vm.State -eq 'Running') {
            $sqlStatus = if (Test-SqlConnection -ServerInstance "$ip,1433" -Password $config['SA_PASSWORD'] -TimeoutSeconds 3) {
                'erreichbar'
            }
            else {
                'nicht erreichbar'
            }
        }

        Write-Host "SQL Server $version ($vmName):"
        Write-Host "  VM:  $state"
        Write-Host "  SQL: $sqlStatus"
        Write-Host "  IP:  $ip,1433"
        Write-Host ''
    }
}

function Stop-Environment {
    Write-Section 'VMs herunterfahren'
    $config = Read-EnvFile -Path $script:EnvPath
    if ($config.Count -eq 0) {
        throw 'Keine Konfiguration gefunden.'
    }

    $versions = $config['SQL_VERSIONS'] -split ','
    foreach ($version in $versions) {
        $vmName = $script:VmNames[$version]
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($null -eq $vm) {
            Write-Warning "VM '$vmName' nicht gefunden."
            continue
        }
        if ($vm.State -ne 'Running') {
            Write-Host "VM '$vmName' ist nicht aktiv ($($vm.State))."
            continue
        }
        Write-Host "Fahre VM '$vmName' herunter..."
        Stop-VM -Name $vmName -Force
    }
    Write-Host 'Alle VMs gestoppt.'
}
