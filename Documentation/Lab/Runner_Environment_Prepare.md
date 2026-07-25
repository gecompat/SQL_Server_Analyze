**Runner environment preparation**

This document explains the intent and usage of `scripts/prepare-runner-environment.ps1`.

Purpose
- Create host directories for Docker and Hyper-V VM storage
- Enable Hyper-V feature when missing (requires reboot)
- Configure Docker data-root for Docker Engine (if present)
- Create a Hyper-V internal switch and NAT for VM networking
- Add a dedicated service account to `docker-users` and `Hyper-V Administrators` (if a service account is supplied)
- Provide cleanup commands for test artifacts

Usage
Run the script as Administrator on the runner host:

```powershell
# example: set Docker data and VM paths, create switch and configure service account
.
\scripts\prepare-runner-environment.ps1 -DockerDataPath D:\DockerData -HyperVVMPath E:\HyperV -VMSwitchName SQLServerAnalyzeSwitch -ServiceAccount ".\\RunnerSvc"
```

Notes and caveats
- Docker Desktop: the script configures `C:\ProgramData\Docker\config\daemon.json` only when a Windows Docker service named `docker` exists (Docker Engine). Docker Desktop on Windows uses WSL2 and its data-root is configured differently; you may need to adjust Docker Desktop settings manually.
- Hyper-V enablement requires a reboot. The script will enable the feature but will not reboot the host.
- Creating an external VMSwitch requires selecting a network adapter; the script creates an internal switch by default and a NAT mapping for basic network access.
- Granting 'Log on as a service' and secure password management must be done according to your organisation policies; the script demonstrates group membership changes but does not manage Log on as a service rights.
- Review and adapt the script to match your storage layout and security requirements.

Recommended follow-up tasks
- Create a documented service account with `Log on as a service` and add to the appropriate groups.
- Configure Docker Desktop data-root if using Docker Desktop and WSL2.
- Validate Hyper-V networking by creating a small test VM and verifying it gets network access through the NAT.

Files
- `scripts/prepare-runner-environment.ps1` — automated preparation script (requires Administrator)
- `Documentation/Lab/Self_Hosted_Windows_Runner_Setup.md` — main runner setup how-to (updated with service troubleshooting)
- `Documentation/Lab/Runner_Environment_Prepare.md` — this document
**Vorbereitung der Runner-Umgebung**

Dieses Dokument erläutert Zweck und Verwendung von `scripts/prepare-runner-environment.ps1`.

Ziel
- Anlegen von Host-Verzeichnissen für Docker- und Hyper‑V-VM‑Daten
- Aktivieren der Hyper‑V‑Funktion (falls erforderlich; Neustart nötig)
- Konfiguration des Docker `data-root` für Docker Engine (falls vorhanden)
- Erstellen eines internen Hyper‑V‑Switches und NAT für VM‑Netzwerke
- Optionales Hinzufügen eines dedizierten Service‑Kontos zu `docker-users` und `Hyper-V Administrators`
- Bereitstellen von Befehlen zur Bereinigung von Testartefakten

Verwendung
Das Skript muss als Administrator auf dem Runner‑Host ausgeführt werden:

```powershell
# Beispiel: Docker‑Daten- und VM‑Pfad setzen, Switch erstellen und Service‑Account angeben
.\scripts\prepare-runner-environment.ps1 -DockerDataPath D:\DockerData -HyperVVMPath E:\HyperV -VMSwitchName SQLServerAnalyzeSwitch -ServiceAccount ".\\RunnerSvc"
```

Hinweise und Einschränkungen
- Docker Desktop: Das Skript passt `C:\ProgramData\Docker\config\daemon.json` nur an, wenn auf dem System ein Windows‑Docker‑Service namens `docker` vorhanden ist (Docker Engine). Docker Desktop unter Windows verwendet WSL2; dessen Datenpfade müssen ggf. separat konfiguriert werden.
- Die Aktivierung von Hyper‑V erfordert einen Neustart. Das Skript aktiviert die Funktion, führt aber keinen automatischen Neustart durch.
- Für einen externen VMSwitch ist die Auswahl eines Netzwerkadapters erforderlich; das Skript legt standardmäßig einen internen Switch an und richtet ein NAT für grundlegenden Netzverkehr ein.
- Rechte wie „Anmelden als Dienst“ (`Log on as a service`) und sichere Passwortverwaltung sind organisatorisch zu regeln; das Skript demonstriert nur Gruppenmitgliedschaften, übernimmt aber keine Rechtevergabe per Sicherheitsrichtlinie.
- Passen Sie das Skript an Ihre Speicherstruktur und Sicherheitsvorgaben an.

Empfohlene Folgeaufgaben
- Ein dokumentiertes Service‑Konto mit `Log on as a service` anlegen und in die benötigten Gruppen aufnehmen.
- Falls Docker Desktop mit WSL2 verwendet wird: `data-root` ggf. in Docker Desktop konfigurieren.
- Hyper‑V‑Netzwerk prüfen, indem eine kleine Test‑VM erstellt und die NAT‑Konnektivität verifiziert wird.

Dateien
- `scripts/prepare-runner-environment.ps1` — Vorbereitungsskript (erfordert Administratorrechte)
- `Documentation/Lab/Self_Hosted_Windows_Runner_Setup.md` — Haupt‑HowTo für Runner (mit Troubleshooting ergänzt)
- `Documentation/Lab/Runner_Environment_Prepare.md` — dieses Dokument
