# Hyper-V QuickStart: Architektur- und Sicherheitsentscheidungen

**Status:** verbindlich
**Geltungsbereich:** `QuickStart/HyperV/`

## Ziel

Der Hyper-V QuickStart stellt eine eigenständige Windows-basierte SQL-Server-Testumgebung mit nativen Hyper-V-VMs bereit. Er ermöglicht das Testen des Frameworks gegen eine produktionsnahe Windows-SQL-Server-Installation ohne Docker-Abhängigkeit.

Der primäre Einstiegspunkt ist:

```powershell
./QuickStart/HyperV/Setup.ps1
```

Für die vollständige Entfernung der verwalteten Umgebung steht bereit:

```powershell
./QuickStart/HyperV/Uninstall.ps1
```

Das Setup kann SQL Server 2019, 2022 und 2025 einzeln oder kombiniert in getrennten VMs bereitstellen und das Framework anschließend automatisch in der synthetischen Datenbank `LabAnalyze` installieren.

## Abgrenzung

### Zum Docker-QuickStart

Der Hyper-V QuickStart liefert **native Windows-SQL-Server-Instanzen** in vollständigen VMs. Das ermöglicht:

- Windows Authentication;
- Windows-native Dateisystemverhaltung;
- vollständige SQL Server Agent Funktionalität;
- productionsnahe Speicherkonfiguration;
- Tests gegen Windows-spezifische DMVs und OS-Metriken.

Docker liefert hingegen leichtgewichtige Linux-Container. Beide QuickStarts nutzen denselben kanonischen Frameworkinstaller.

### Zum erweiterten Lab

Keine LAB-Run-IDs, Evidence-Gates, Lab-State-Dateien oder Szenariokataloge aus `Lab/`. Gemeinsam genutzt wird ausschließlich der Frameworkinstaller.

## Base-Image-Strategie

### Option 1: Bereitgestelltes VHD/VHDX (bevorzugt)

Der Benutzer stellt ein vorbereitetes Windows Server VHDX bereit. Anforderungen:

- Windows Server 2019, 2022 oder 2025 (Core oder Desktop Experience);
- Sysprep-generalisiert (OOBE-Phase beim ersten Start);
- Generation-2-kompatibel (UEFI, GPT-Partitionierung);
- Mindestens 40 GB Basegröße.

### Option 2: Automatischer Download (Fallback)

Setup kann eine Windows Server Evaluation ISO von Microsoft herunterladen und daraus automatisch ein Base-VHDX erzeugen:

- ISO-Download von offiziellen Microsoft Evaluation Center URLs;
- Automatische VHD-Erstellung via `Convert-WindowsImage` oder `DISM`;
- ISO- und Base-VHD-Cache im konfigurierten Speicherpfad;
- 180-Tage-Evaluationslizenz (ausreichend für Testumgebungen).

### Differencing Disks

Pro SQL-Server-Version wird ein Differencing Disk vom Base-VHDX erzeugt:

```text
<VmRoot>/
  base/windows-server-base.vhdx         (nur lesen)
  vm-2019/sql2019-diff.vhdx             (Differencing → base)
  vm-2022/sql2022-diff.vhdx             (Differencing → base)
  vm-2025/sql2025-diff.vhdx             (Differencing → base)
```

Vorteil: Schnelle Bereitstellung, minimaler Speicherverbrauch, unabhängige VM-Zustände.

## VM-Architektur

- **Generation:** 2 (UEFI, Secure Boot deaktiviert für Flexibilität)
- **Dynamischer Speicher:** Ja, mit konfigurierbarem Minimum/Maximum
- **Prozessoren:** Konfigurierbar pro Ressourcenprofil
- **Netzwerk:** Interner Switch mit NAT für Internet (während Setup), danach optional isoliert
- **Checkpoints:** Deaktiviert (kein automatisches Checkpointing)
- **Integrationsdienste:** Aktiviert (Guest Services für Dateikopie)

## Netzwerk

Setup erstellt einen dedizierten internen Hyper-V Switch:

- Name: `SQL_Server_Analyze_Lab`
- Typ: Internal
- NAT-Netzwerk für Internet-Zugang (SQL Server Setup, Windows Update)
- Statische IP-Adressierung der VMs (kein DHCP):
  - Host-Gateway: `172.30.0.1/24`
  - VM SQL 2019: `172.30.0.19`
  - VM SQL 2022: `172.30.0.22`
  - VM SQL 2025: `172.30.0.25`
- SQL-Port: Standard 1433 (in jeder VM)
- Host-Verbindung via IP-Adresse oder konfigurierbarem Hostnamen in `hosts`-Datei

## SQL Server Installation

### Unattended Setup

SQL Server wird via `setup.exe /ConfigurationFile=...` installiert:

- **Edition:** Developer (kostenfrei, voller Funktionsumfang)
- **Authentifizierung:** Mixed Mode (SA + Windows Auth)
- **SA-Passwort:** Aus `.env` (identisch zum Docker-QuickStart-Pattern)
- **Features:** SQLENGINE, FULLTEXT, CONN
- **Collation:** `SQL_Latin1_General_CP1_CS_AS`
- **Instanzname:** MSSQLSERVER (Default)
- **Query Store:** Aktiviert nach Installation
- **SQL Agent:** Aktiviert und gestartet

### SQL Server Media

Setup unterstützt:

1. Lokales ISO-Image (vom Benutzer bereitgestellt)
2. Automatischer Download der Developer Edition von Microsoft
3. Cache der Installationsmedien im konfigurierten Speicherpfad

Pro SQL-Server-Version wird ein eigenes Installationsmedium erwartet.

## Speicherlayouts

### Single Root

```text
<LabRoot>/
  base/                          (Base-VHDX, ISO-Cache)
  vm-2019/                       (Differencing Disk, VM-Konfiguration)
  vm-2022/
  vm-2025/
  control/                       (Scope-Marker, Installer-Kopie)
```

### Separate Roots

Für Systeme mit mehreren Datenträgern:

- Control Root: Marker, Installer, Base-Image
- VM Root: VHDs und VM-Konfigurationsdateien

## Ressourcenprofile

| Profil | RAM (Start/Max) | vCPUs | VHD Max |
|---|---:|---:|---:|
| Compact | 4/6 GiB | 2 | 60 GB |
| Standard | 8/12 GiB | 4 | 80 GB |
| Performance | 16/24 GiB | 8 | 120 GB |

Bei mehreren VMs wird die Hostbelastung geprüft und eine Bestätigung verlangt wenn die Summe 70% des Hostspeichers überschreitet.

## Pfadsicherheit

Identisch zum Docker-QuickStart:

- Zielpfade müssen absolut und lokal sein;
- Laufwerks- und Dateisystemwurzeln sind unzulässig;
- Betriebssystem-, Programm- und Repositorypfade sind unzulässig;
- Benutzerprofilwurzel ist unzulässig;
- Netzwerkpfade, Junctions und symbolische Links sind unzulässig;
- getrennte Speicherwurzeln dürfen sich nicht überlappen.

Scope-Marker werden in jeder verwalteten Wurzel angelegt. Start, Stop und Remove akzeptieren nur Pfade mit passendem Marker.

## Lokale Secrets

```text
QuickStart/HyperV/.env
```

Enthält SA-Passwort, VM-Konfiguration, Pfade. Durch `.gitignore` ausgeschlossen. `.env.example` enthält nur synthetische Platzhalter.

## Lifecycle

| Aktion | Wirkung |
|---|---|
| Setup | Konfiguration abfragen, VMs erstellen, OS vorbereiten, SQL installieren, Framework deployen |
| Start | Gespeicherte VMs starten, Netzwerk prüfen, SQL-Verfügbarkeit bestätigen |
| Status | VM-Zustand, SQL-Konnektivität, Framework-Version anzeigen |
| Stop | VMs herunterfahren (Guest Shutdown) |
| Remove | VMs löschen, Differencing Disks entfernen, Base optional behalten |
| Uninstall | Vollständige Entfernung inkl. Base, Switch, NAT, Marker |

## Voraussetzungen auf dem Host

- Windows 10/11 Pro oder Windows Server mit Hyper-V-Rolle;
- PowerShell 7+;
- Administrationsberechtigung (Hyper-V-Cmdlets erfordern Elevation);
- Mindestens 20 GB freier Speicher pro VM;
- Optional: Internet für ISO/SQL-Media-Download.

## Unterstützte Laufzeitvarianten

- Windows 10/11 Pro mit Hyper-V;
- Windows Server 2019/2022/2025 mit Hyper-V-Rolle;
- Nested Virtualization in einer Azure/Hyper-V VM (mit aktivierter ExposeVirtualizationExtensions).

## Frameworkinstallation

Nach SQL-Server-Bereitschaft erzeugt der QuickStart den Standalone-Installer und installiert pro VM:

1. `LabAnalyze` mit `SQL_Latin1_General_CP1_CS_AS` erstellen;
2. Framework installieren oder aktualisieren;
3. Schema `monitor` als `FRAMEWORK_READY` verifizieren.

Das SA-Passwort wird dabei ausschließlich via SecureString/Credential übergeben.
