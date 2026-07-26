# Hyper-V QuickStart

Dieser Bereich stellt eine eigenständige Hyper-V-Testumgebung für
`SQL_Server_Analyze` bereit. Er ermöglicht native Windows-SQL-Server-Instanzen
in vollständigen VMs ohne Docker-Abhängigkeit.

Der QuickStart ist vom Docker-QuickStart und vom erweiterten Lab getrennt:

- keine Docker-, Container- oder Linux-Abhängigkeit;
- native Windows Authentication und Agent-Funktionalität;
- keine LAB-Run-IDs oder Evidence-Gates;
- nur der kanonische Frameworkinstaller unter `Code/Install` wird wiederverwendet.

## Voraussetzungen

- Windows 10/11 Pro oder Windows Server mit aktivierter Hyper-V-Rolle;
- PowerShell 7+ (als Administrator);
- mindestens 20 GB freier Speicher pro SQL-Server-Version;
- ein generalisiertes (sysprep) Windows Server VHDX oder Internetzugang für Download.

## Ein Einstiegspunkt

PowerShell 7 als Administrator im Repository-Root öffnen und ausführen:

```powershell
./QuickStart/HyperV/Setup.ps1
```

`Setup.ps1` führt beim ersten Aufruf durch die Einrichtung. Bei späteren
Aufrufen zeigt es ein Menü für Start, Status, Stop und Remove.

Direkte Aktionen:

```powershell
./QuickStart/HyperV/Setup.ps1 -Action Start
./QuickStart/HyperV/Setup.ps1 -Action Status
./QuickStart/HyperV/Setup.ps1 -Action Stop
./QuickStart/HyperV/Setup.ps1 -Action Remove
```

Für die vollständige Deinstallation:

```powershell
./QuickStart/HyperV/Uninstall.ps1
```

## Was Setup abfragt

Das Setup fragt interaktiv nach:

- SQL-Server-Versionen: 2019, 2022 und/oder 2025;
- Ressourcenprofil: Compact, Standard oder Performance;
- Speicherpfad für VMs und VHDs;
- Base-Image-Quelle: lokales VHDX oder Evaluation-Download;
- SQL-Server-Installationsmedien: lokales ISO oder Developer-Edition-Download;
- SA-Passwort für die synthetischen Testinstanzen;
- automatische Frameworkinstallation in `LabAnalyze`.

Danach erzeugt es lokal `QuickStart/HyperV/.env`, erstellt die VMs und
installiert SQL Server unattended.

## Architektur

```text
<LabRoot>/
  base/windows-server-base.vhdx    (generalisiertes Base-Image, ReadOnly)
  vm-2019/sql2019-diff.vhdx        (Differencing Disk)
  vm-2022/sql2022-diff.vhdx
  vm-2025/sql2025-diff.vhdx
  control/                          (Scope-Marker)
```

Jede SQL-Server-Version erhält eine eigene VM mit Differencing Disk. Das
Base-Image wird dabei nicht verändert. Die VMs kommunizieren über einen
dedizierten internen Hyper-V Switch mit NAT.

## Netzwerk

| VM | IP-Adresse | Port |
|---|---|---:|
| SQL Server 2019 | 172.30.0.19 | 1433 |
| SQL Server 2022 | 172.30.0.22 | 1433 |
| SQL Server 2025 | 172.30.0.25 | 1433 |

Verbindung via SSMS/ADS:

```text
Server: 172.30.0.22,1433
Login: sa
Passwort: <bei Setup gewählt>
```

## Ressourcenprofile

| Profil | RAM (Start/Max) | vCPUs | VHD Max |
|---|---:|---:|---:|
| Compact | 4/6 GiB | 2 | 60 GB |
| Standard | 8/12 GiB | 4 | 80 GB |
| Performance | 16/24 GiB | 8 | 120 GB |

## Schutz vor Überschreiben

Identisch zum Docker-QuickStart:

- Pfade müssen absolut, lokal und leer sein;
- Betriebssystem-, Programm- und Repositorypfade sind gesperrt;
- Scope-Marker schützen vor versehentlicher Mutation fremder Daten;
- Remove und Uninstall erfordern Bestätigung und Marker-Prüfung.

## Lokale `.env`

Die erzeugte `.env` enthält das SA-Passwort und VM-Konfiguration. Die Datei ist
durch die Repository-`.gitignore` ausgeschlossen. `.env.example` enthält nur
synthetische Platzhalter.

## Unterschiede zum Docker-QuickStart

| Aspekt | Docker | Hyper-V |
|---|---|---|
| Plattform | Linux-Container | Windows-VMs |
| Auth | SA only | SA + Windows |
| Agent | begrenzt | vollständig |
| Dateisystem | Linux ext4 | Windows NTFS |
| Startzeit | Sekunden | Minuten |
| Speicher | GB (Container) | 20+ GB (VHD) |
| Isolation | Container | Vollständige VM |
