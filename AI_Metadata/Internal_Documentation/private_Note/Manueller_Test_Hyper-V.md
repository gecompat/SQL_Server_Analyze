## Manueller Test: Hyper-V QuickStart

### Voraussetzungen prüfen

**Auf dem Windows-System (Key18):**

1. PowerShell 7 als Administrator öffnen
2. Prüfen:

```powershell
# Hyper-V aktiv?
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select State

# PowerShell-Version?
$PSVersionTable.PSVersion

# Freier RAM?
[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
```

Falls Hyper-V nicht aktiv: `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All` (Neustart nötig).

---

### Test-Durchlauf

**Schritt 1:** Repository aktuell ziehen

```powershell
cd <Pfad-zum-Repo>\SQL_Server_Analyze
git pull origin main
```

**Schritt 2:** Setup starten

```powershell
./QuickStart/HyperV/Setup.ps1
```

**Schritt 3:** Bei den interaktiven Fragen empfehle ich für den ersten Test:

| Frage | Antwort |
| --- | --- |
| Betriebsmodus | **2** (Linux) — schnellster Test, kleinstes Image |
| SQL-Version | nur **2022** (eine reicht) |
| Ressourcenprofil | **1** (Compact — 4 GB RAM) |
| Speicherpfad | Standard akzeptieren oder z.B. `D:\Lab\HyperV` |
| Linux Base-Image | **2** (Auto-Download, ~600 MB) |
| Netzwerkprofil | **1** (LAN — keine Simulation initial) |
| I/O-Profil | **1** (SSD — keine Drosselung initial) |
| SA-Passwort | z.B. `Test#Lab2026!` |
| Framework installieren | **Ja** |
| Jetzt erstellen? | **Ja** |

---

### Was dabei passieren sollte (Erwartung)

1. SSH-Key wird generiert (`.ssh/lab_ed25519`)
2. Interner Switch + NAT wird erstellt
3. Ubuntu Cloud-Image wird heruntergeladen (~600 MB)
4. cloud-init ISO wird erzeugt (**hier braucht es `oscdimg.exe` aus Windows ADK!**)
5. VM wird erstellt (Gen2, Differencing Disk + Data + Log)
6. VM startet, cloud-init konfiguriert User + Netzwerk
7. SSH-Verbindung wird aufgebaut
8. SQL Server wird via APT installiert
9. Framework wird deployed
10. Status-Ausgabe mit IP

---

### Wahrscheinliche Stolpersteine

| Problem | Lösung |
| --- | --- |
| `oscdimg.exe nicht gefunden` | Windows ADK installieren oder ich baue eine PowerShell-Alternative |
| `Nested Virtualization` Fehler | Runner ist selbst eine VM → `Set-VMProcessor -ExposeVirtualizationExtensions $true` auf dem Host |
| Download-Timeout | Netzwerk/Proxy auf Key18 prüfen |
| SSH-Verbindung schlägt fehl | Firewall-Regel für Port 22 auf dem internen Switch |

---

### Ergebnis melden

Wenn es durchläuft oder abbricht — den **letzten Output** (Fehler oder Erfolg) hier reinkopieren. Dann kann ich gezielt fixen.

**Tipp:** Falls Sie zuerst nur die **Module-Ladephase** testen wollen (ohne tatsächlich VMs zu erstellen), können Sie mit Ctrl+C nach der Konfigurationsphase abbrechen — dann sehen Sie ob alle `.ps1`-Dateien fehlerfrei laden.