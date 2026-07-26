# Lab – Diagnose-Szenarien und Orchestrierung

Dieses Verzeichnis enthaelt die analyserspezifischen Szenarien, Contracts und Orchestrierungslogik des SQL_Server_Analyze Frameworks.

## SQL-Server-Testumgebung bereitstellen

Die allgemeine Erzeugung und Verwaltung von SQL-Server-Laborumgebungen (Docker, Hyper-V, Podman) liegt im zentralen Repository:

**https://github.com/gecompat/SQL_Server_Lab**

Dort befinden sich:

- Ad-hoc-Erstellung von SQL-Server-Instanzen (Docker, Hyper-V)
- Lifecycle-Management (Start, Stop, Status, Remove)
- Ressourcenprofile und Host-Assessment
- Netzwerk- und I/O-Simulation
- Scope-sichere Deinstallation

## Verzeichnisstruktur

| Pfad | Inhalt |
| --- | --- |
| `Contracts/` | JSON-Schemas fuer Szenarien, Findings, Evidenz und Runbooks |
| `Orchestration/` | DiagnosticLab PowerShell-Modul (Szenario-Ausfuehrung) |
| `Scenarios/` | Analyse-Szenarien (Core, Performance, Infrastructure) |
| `Validation/` | Wave-Tests und Fixture-Dateien |
| `Update-Framework.ps1` | Framework-Update in bestehender Instanz |
| `Run-LogShipping-Lab.ps1` | LogShipping-Szenario-Starter |

## Workflow

1. SQL-Server-Umgebung mit `SQL_Server_Lab` bereitstellen
2. Framework installieren (via Adapter oder `Update-Framework.ps1`)
3. Szenarien ausfuehren (`Orchestration/Invoke-DiagnosticLab.ps1`)
4. Ergebnisse validieren (`Validation/Invoke-LabWave*`)
5. Umgebung ueber `SQL_Server_Lab` entfernen
