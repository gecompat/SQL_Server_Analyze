function Remove-Environment {
    Write-Section 'Hyper-V QuickStart entfernen'
    $config = Read-EnvFile -Path $script:EnvPath
    if ($config.Count -eq 0) {
        Write-Host 'Keine Konfiguration gefunden. Nichts zu entfernen.'
        return
    }

    $labRoot = $config['LAB_ROOT']
    $scopeId = $config['SCOPE_ID']
    $versions = $config['SQL_VERSIONS'] -split ','

    # Scope-Marker prüfen
    if (-not [string]::IsNullOrWhiteSpace($labRoot) -and (Test-Path -LiteralPath $labRoot)) {
        if (-not (Test-ScopeMarker -Path $labRoot -ScopeId $scopeId)) {
            throw "Scope-Marker in '$labRoot' stimmt nicht mit der aktuellen Konfiguration überein. Entfernung abgebrochen."
        }
    }

    Write-Host 'Folgende Ressourcen werden entfernt:'
    foreach ($version in $versions) {
        Write-Host "  - VM: $($script:VmNames[$version])"
    }
    Write-Host "  - Switch: $($script:SwitchName)"
    Write-Host "  - NAT: $($script:NatName)"
    Write-Host "  - Pfad: $labRoot"
    Write-Host ''

    if (-not (Read-YesNo -Prompt 'VMs und Konfiguration entfernen?')) {
        Write-Host 'Abgebrochen.'
        return
    }

    # VMs stoppen und entfernen
    foreach ($version in $versions) {
        $vmName = $script:VmNames[$version]
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($null -eq $vm) { continue }

        if ($vm.State -eq 'Running') {
            Write-Host "Stoppe VM '$vmName'..."
            Stop-VM -Name $vmName -TurnOff -Force
        }

        Write-Host "Entferne VM '$vmName'..."
        Remove-VM -Name $vmName -Force
    }

    # Netzwerk entfernen
    Remove-LabSwitch

    # Daten entfernen (zweite Bestätigung für destruktive Aktion)
    if (Test-Path -LiteralPath $labRoot) {
        Write-Host ''
        if (Read-YesNo -Prompt "Datenpfad '$labRoot' vollständig löschen? (UNWIDERRUFLICH)") {
            # Nochmals Scope-Marker prüfen vor Löschung
            if (Test-ScopeMarker -Path $labRoot -ScopeId $scopeId) {
                # ReadOnly-Flag vom Base-VHD entfernen
                $baseVhd = Join-Path $labRoot 'base\windows-server-base.vhdx'
                if (Test-Path -LiteralPath $baseVhd) {
                    Set-ItemProperty -LiteralPath $baseVhd -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                }
                Remove-Item -LiteralPath $labRoot -Recurse -Force
                Write-Host "Pfad '$labRoot' entfernt."
            }
            else {
                Write-Warning 'Scope-Marker nicht mehr gültig. Manuelle Bereinigung erforderlich.'
            }
        }
    }

    # .env entfernen
    if (Test-Path -LiteralPath $script:EnvPath) {
        Remove-Item -LiteralPath $script:EnvPath -Force
        Write-Host 'Konfiguration entfernt.'
    }

    Write-Host ''
    Write-Host 'Hyper-V QuickStart vollständig entfernt.'
}
