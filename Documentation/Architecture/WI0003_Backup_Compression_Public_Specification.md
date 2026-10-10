# WI-0003: Backup-Kompressionsalgorithmus- und ZSTD-Evidenz – öffentliche Spezifikation

**Status:** `IMPLEMENTED_ACTIONS_GATE`.
**Geltungsbereich:** Erweiterung von `[monitor].[USP_BackupRecovery]` und
seiner JSON-Weitergabe durch `[monitor].[USP_InfrastructureAnalysis]` für SQL
Server 2019 und neuer.

## Ziel und Abgrenzung

Der Produkt-Slice ergänzt die vorhandene Backup-Recovery-Ausgabe um eine
separate Kompressionsmenge. Sie zeigt den sichtbaren Serverdefault, die
versionsabhängige Capability und den pro erfolgreichem Backupset dokumentierten
Algorithmus. Konfiguration, Capability und Historie bleiben getrennte
Evidenzarten. Weder `MS_XPRESS`, Intel QAT noch ZSTD werden aus
`backup compression default`, der Kompressionsgröße oder der Produktversion
abgeleitet.

Die Erweiterung erzeugt keinen Gesundheitsbefund und keine Konfigurations-
empfehlung. Ein Restoretest, Medienintegrität sowie CPU- und Durchsatzwirkung
bleiben außerhalb des Vertrags.

## Öffentlicher Vertrag

Die vorhandenen Parameter und die `freshness`-TABLE-Menge bleiben unverändert.
`TABLE` akzeptiert zusätzlich die Zuordnung `compression`; beide Zuordnungen
können gemeinsam oder einzeln angefordert werden. RAW enthält die
Kompressionsmenge als eigenes Resultset; JSON enthält sie unter dem Schlüssel
`compression`. CONSOLE behält seine bestehende Freshness-Ansicht und verweist
für die technische Kompressionsevidenz auf RAW, TABLE oder JSON.
`USP_InfrastructureAnalysis` übernimmt den erweiterten JSON-Wert unverändert
innerhalb seines bestehenden Backup-Recovery-Teilobjekts.

| Feld | Bedeutung |
|---|---|
| `EvidenceScope` | `SERVER_CONFIGURATION`, `CAPABILITY` oder `BACKUP_HISTORY`. |
| `DatabaseName` | Sichtbarer Datenbankname einer `BACKUP_HISTORY`-Zeile; bei serverweiten Zeilen `NULL`. |
| `BackupSetId` | Kennung des sichtbaren Backupsets; bei serverweiten Zeilen `NULL`. |
| `BackupFinishDate` | Abschlusszeitpunkt des sichtbaren Backupsets; bei serverweiten Zeilen `NULL`. |
| `ConfigurationName` | Name der serverweiten Konfiguration, wenn die Zeile eine Konfiguration beschreibt. |
| `ConfiguredValue` | Gelesener Konfigurationswert; bei Historienzeilen `NULL`. |
| `AlgorithmName` | Für `backup compression default`: `ENABLED` oder `DISABLED`; für `backup compression algorithm`: `MS_XPRESS`, `QAT`, `ZSTD` oder `USE_BACKUP_COMPRESSION_DEFAULT`; für die Capability `ZSTD`; für die Historie `MS_XPRESS`, `QAT`, `ZSTD` oder `UNKNOWN`. Der Wert wird ausschließlich aus der passenden Quelle übersetzt. |
| `SourceStatus` | Teilquellenstatus, beispielsweise `AVAILABLE`, `UNAVAILABLE_VERSION`, `DENIED_PERMISSION`, `TIMEOUT` oder `ERROR_HANDLED`. |
| `ErrorNumber`, `ErrorMessage` | Begrenzte technische Fehlerbeschreibung der betroffenen Teilquelle. |
| `CollectionTimeUtc` | UTC-Zeitpunkt der jeweiligen Teilquellenaufnahme. |

Jede `BACKUP_HISTORY`-Zeile beschreibt ein sichtbares, erfolgreiches
Backupset, nicht ein Backupmedium oder eine Wiederherstellungszusage. Die
Historienmenge folgt dem bestehenden Datenbankscope und `@MaxZeilen`-Limit von
`USP_BackupRecovery`; die kleinen serverweiten Konfigurations- und
Capabilityzeilen bleiben davon unabhängig.

## Quellen, Versionen und Fehlerisolation

`backup compression default` wird als bestehende allgemeine
Kompressionsvoreinstellung aus `sys.configurations` gelesen. Die Option
`backup compression algorithm` und `backupset.compression_algorithm` werden
erst ab SQL Server 2022 in einem getrennten, dynamischen Quellpfad gelesen.
SQL Server 2019 meldet hierfür `UNAVAILABLE_VERSION`, ohne dass der
Backup-Recovery-Aufruf oder dessen bestehende Mengen fehlschlagen. Auf SQL
Server 2022 ist QAT capabilityfähig; ZSTD ist ab SQL Server 2025
capabilityfähig. Ein unbekannter Quellwert bleibt `UNKNOWN` und wird nicht
einem bekannten Algorithmus zugeordnet.

Konfigurations- und Historienlesungen sind unabhängig begrenzt. Fehlende
Rechte, Lock-Timeouts, ein fehlendes optionales Schema oder andere Quellfehler
werden ausschließlich in der betroffenen Kompressionszeile ausgedrückt. Sie
unterdrücken weder Freshness-, Backup- noch Restoreausgaben. Ein erfolgreicher
Capabilitypfad ersetzt keine Konfigurations- oder Historienevidenz.

## Nachweisplan vor Implementierung

Der Impactlauf umfasst die betroffenen Backup-Recovery-, Infrastructure-,
Feature-Capability-, Installer-, Inventar- und JSON-Verträge auf SQL Server
2025 mit Compatibility Level 170. Wegen des nativ versionsabhängigen Katalog-
schemas sind zusätzlich gezielte native Läufe auf SQL Server 2019 und 2022
erforderlich. Die Matrix prüft mindestens den 2019-Fallback, eine sichtbare
historische MS_XPRESS-Zeile, die getrennten Konfigurationswerte, unbekannte
Werte, begrenzte oder verweigerte Quellen, TABLE-/RAW-/CONSOLE-/JSON-Parität,
den Infrastructure-Parentpfad sowie eigenen Fixture- und Mediencleanup.

Eine positive ZSTD-Zeile wird nur dann als ausgeführt dokumentiert, wenn ein
tatsächlich ausgeführtes SQL-Server-2025-Backup diese Historienmetadaten
liefert. Sie wird nicht aus einer gesetzten Konfiguration oder einer
Feature-Capability behauptet.

## Primärquellen

- [Server configuration: backup compression algorithm](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/view-or-configure-the-backup-compression-algorithm-server-configuration-option?view=sql-server-ver17)
- [backupset (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql?view=sql-server-ver17)
