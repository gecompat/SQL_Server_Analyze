## Self-hosted Windows Runner Einrichtung für SQL_Server_Analyze

## Zweck

Dieses Dokument beschreibt die Vorbereitung eines dedizierten Windows‑Systems als repository‑lokalen GitHub Actions Self‑Hosted Runner für SQL_Server_Analyze‑Tests.

Der Runner dient dem kontrollierten Laborbetrieb für:

- SQL Server Tests in Docker‑Containern
- Tests in Hyper‑V‑basierten Umgebungen
- Validierung von SQL Server Versionen
- Framework‑Installation und Validierungs‑Workflows

Der Runner ist ausschließlich für das Repository `gecompat/SQL_Server_Analyze` zu registrieren.

---

## Sicherheitsmodell

Ein Self‑Hosted Runner führt Repository‑Workflows mit den Rechten des Runner‑Servicekontos aus.

Empfohlene Regeln:

- Dedizierte Testhardware verwenden.
- Dediziertes Windows‑Servicekonto anlegen.
- Keine Zugangsdaten im Repository speichern.
- Unvertrauenswürdige Pull Requests nicht mit Administratorrechten ausführen.
- Zugriff auf den Runner auf das vorgesehene Repository beschränken.

---

## Empfohlene Windows‑Voraussetzungen

Mindestanforderungen:

- Windows 11 Pro oder Windows Server
- 64‑Bit Betriebssystem
- Hardware‑Virtualisierung im BIOS/UEFI aktiviert
- PowerShell 7 empfohlen
- Git installiert
- Python installiert
- Docker Desktop oder Docker Engine verfügbar
- Optional: Hyper‑V aktiviert

Empfohlene Ressourcen für SQL‑Server‑Tests:

- 8+ CPU‑Kerne
- 64 GB RAM oder mehr
- SSD‑Speicher

---

## Preflight‑Prüfungen

Vor der Installation sind die folgenden Prüfungen durchzuführen.

### Windows‑Version

Verwenden Sie die aktuellen Registry‑Werte statt der veralteten `WindowsVersion`‑Property:

```powershell
Get-ItemProperty `
"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" |
Select-Object ProductName, DisplayVersion, CurrentBuild, UBR
```

Die Build‑Nummer muss mit Windows 11 oder einer unterstützten Windows Server Version kompatibel sein.

### CPU und Virtualisierung

```powershell
Get-CimInstance Win32_Processor |
Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, VirtualizationFirmwareEnabled
```

### Arbeitsspeicher

```powershell
"{0:N1} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
```

### Hyper‑V Feature

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

### WSL2

```powershell
wsl --version
```

### Docker

```powershell
docker --version
docker info
docker compose version
```

Funktionaler Test:

```powershell
docker run --rm hello-world
```

### Git

```powershell
git --version
```

### Python

```powershell
python --version
```

---

## Speicherempfehlungen

Betriebssystem, Containerdaten und virtuelle Maschinen sollten getrennt abgelegt werden.

Beispiel:

```
C:
  Windows
  GitHub Runner
  Development tools

D:
  Docker data
  Container images
  SQL Server container data

E:
  Hyper-V virtual machines
  VM test data
```

---

## GitHub Actions Runner installieren

Im Repository unter:

```
Settings
  -> Actions
  -> Runners
  -> New self-hosted runner
```

Auswahl:

```
Windows
x64
```

Erstellen Sie ein dediziertes Verzeichnis, z. B.:

```
C:\GitHubRunner\SQL_Server_Analyze
```

Laden Sie den Runner herunter und konfigurieren Sie ihn mittels der von GitHub bereitgestellten Befehle.

Beispiel Registrierungsbefehl:

```powershell
config.cmd `
  --url https://github.com/gecompat/SQL_Server_Analyze `
  --token <registration-token>
```

Repository‑Level Registrierung wird empfohlen.

Empfohlene Labels:

```
self-hosted
windows
sql-test
docker
hyperv
```

---

## Runner als Windows‑Dienst betreiben

Installation:

```powershell
svc install
```

Start:

```powershell
svc start
```

Der Dienst sollte unter einem dedizierten Servicekonto laufen.

Benötigte Berechtigungen hängen von den aktivierten Testprofilen ab:

Docker:

- Mitgliedschaft in `docker-users`

Hyper‑V:

- Mitgliedschaft in `Hyper-V Administrators`

Für erweiterte SQL Server Lifecycle‑Tests sind lokale Administratorrechte möglich erforderlich.

---

## Docker Testprofil

Empfohlenes Default‑Profil:

```
Windows
 |
 Docker Desktop
 |
 WSL2 backend
 |
 SQL Server containers
```

Beispiel‑Validierung:

```powershell
docker run --rm hello-world
```

Bei versionsspezifischen SQL‑Tests separate Ports und isolierte Containernamen verwenden.

---

## Hyper‑V Testprofil

Hyper‑V kann zusammen mit Docker Desktop verwendet werden.

Typische Architektur:

```
Windows Host
 |
 Hyper-V
 |
 Linux VM
 |
 Docker Engine
 |
 SQL Server containers
```

Damit lässt sich vergleichen:

- Ausführung via Docker Desktop
- Ausführung in nativen VMs

Beide Profile separat prüfen, um reproduzierbare Ergebnisse zu gewährleisten.

---

## Validierungs‑Workflow

Nach Installation einen Repository‑Workflow ausführen, der prüft:

- Runner‑Verfügbarkeit
- Docker‑Verfügbarkeit
- Start von SQL‑Server‑Containern
- Framework‑Installation
- Bereinigungsverhalten

Ein funktionierender Runner ist gekennzeichnet durch:

```
Runner: Online
Docker: Ready
Hyper-V: Ready (if enabled)
SQL Test Environment: Ready
```

---

## Fehlerbehebung

### Docker Befehl nicht vorhanden

Prüfen:

```powershell
Get-Command docker
```

Stellen Sie sicher, dass das Runner‑Servicekonto Docker‑Rechte besitzt.

### Hyper‑V nicht verfügbar

Prüfen:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V
```

BIOS Virtualisierung prüfen.

### Unterschiede bei Windows‑Versionserkennung

Moderne Windows‑Versionen liefern teilweise inkonsistente Legacy‑Felder. Bevorzugen Sie die Build‑Nummer und `DisplayVersion` gegenüber `WindowsVersion`.

### Dienst startet nicht (Win32Exception 1068)

Symptom: Der Runner‑Dienst ist installiert, kann jedoch nicht starten und meldet beispielsweise:

```
System.ComponentModel.Win32Exception (0x80004005): Der Abhängigkeitsdienst oder die Abhängigkeitsgruppe konnte nicht gestartet werden.
```

Ursache: In unserem Labor wurde der Dienst standardmäßig mit dem Konto `NetworkService` installiert und konnte aufgrund von Rechten/Logon‑Einschränkungen nicht gestartet werden (z. B. Zugriff auf Docker/Hyper‑V oder fehlende Startrechte). Läuft der Runner interaktiv per `run.cmd`, ist die Laufzeitgesundheit gegeben — die Ursache liegt in der Dienstkonfiguration oder im Service‑Konto.

Kurze Prüf‑ und Behebungs‑Schritte (als Administrator ausführen):

```powershell
# Dienstkonfiguration und Abhängigkeiten prüfen
sc.exe qc actions.runner.<YOUR_INSTANCE_NAME>
reg query "HKLM\SYSTEM\CurrentControlSet\Services\actions.runner.<YOUR_INSTANCE_NAME>" /v DependOnService

# Dienst starten (kann wegen fehlender Rechte fehlschlagen)
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"

# Falls Start mit Zugriffsfehlern fehlschlägt: Testweise auf LocalSystem stellen
sc.exe config "actions.runner.<YOUR_INSTANCE_NAME>" obj= LocalSystem
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"
```

Startet der Dienst als `LocalSystem`, legen Sie ein dediziertes Service‑Konto an und gewähren Sie dieses Rechte:

- `Log on as a service`
- Mitgliedschaft in `docker-users` (falls Docker benötigt wird)
- Mitgliedschaft in `Hyper-V Administrators` (falls Hyper‑V verwaltet werden soll)

Beispiel (elevated PowerShell):

```powershell
# Lokales Servicekonto anlegen (Name/Passwort anpassen)
# New-LocalUser -Name RunnerSvc -Password (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -Description "GitHub Actions runner service account"

# 'Log on as a service' per LSA‑Policy/GPO vergeben (z. B. ntrights)
# ntrights.exe +r SeServiceLogonRight -u RunnerSvc

# In Gruppen aufnehmen
# Add-LocalGroupMember -Group "docker-users" -Member RunnerSvc
# Add-LocalGroupMember -Group "Hyper-V Administrators" -Member RunnerSvc

# Dienst auf das Konto konfigurieren
sc.exe config "actions.runner.<YOUR_INSTANCE_NAME>" obj= ".\\RunnerSvc" password= "<secure-password>"
sc.exe start "actions.runner.<YOUR_INSTANCE_NAME>"
```

Hinweise:
- Verwenden Sie sichere Passwörter und folgen Sie den organisatorischen Richtlinien zur Kontenverwaltung und Auditierung.
- Kann das Servicekonto nicht angepasst werden, ist der interaktive Betrieb via `run.cmd` ein zulässiger Fallback für ad‑hoc Tests.
- Dokumentieren Sie das verwendete Servicekonto und die erforderlichen Gruppenmitgliedschaften zusammen mit den Installationsartefakten, damit eine spätere Neuinstallation reproduzierbar ist.

---

## Referenzen

- GitHub Actions self-hosted runners: https://docs.github.com/actions/hosting-your-own-runners
- Docker Desktop documentation: https://docs.docker.com/desktop/
- Microsoft Hyper-V documentation: https://learn.microsoft.com/windows-server/virtualization/hyper-v/
