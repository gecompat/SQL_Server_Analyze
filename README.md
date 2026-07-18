# SQL-Server Analyze Tool

# ⚠️ READ BEFORE USE

**NOTICE: This software is NOT Open Source. Use is governed by a custom Community & Attribution License.**

1. **NO RESALE:** Selling or charging for access to this software is strictly prohibited.
2. **ATTRIBUTION REQUIRED:** You must preserve the copyright notice for **gecompat - Gerhard Pisch**.
3. **NO LIABILITY:** Use this software at your own risk. The author is **NOT liable** for any damages, data loss, or business interruptions.

Full legal terms can be found in the [LICENSE.md](./LICENSE.md) file.


---

## Überblick

SQL Server Analyze ist ein T-SQL-basiertes Diagnoseframework für SQL Server ab Version 2019. Es unterstützt Ad-hoc-Analysen laufender Prozesse ebenso wie tiefergehende Untersuchungen von Objekten, Indizes, Ausführungsplänen, Query Store, Extended Events, Serverkonfiguration und Infrastrukturkomponenten.

Das Framework wird in einer frei wählbaren Datenbank im Schema `[monitor]` installiert. 

## Schwerpunkte

- aktuelle Sessions, Requests, Blocking, Waits und Transaktionen
- Memory Grants einschließlich Resource Governor und Resource Semaphores
- exaktes aktuell ausgeführtes Statement anhand der SQL-Server-Offsets
- vollständiger Batch-, Modul- und Input-Buffer-Kontext bei Bedarf
- TempDB-, I/O- und Transaktionslog-Diagnose
- Objekt-, Index-, Statistik-, Partitionierungs- und Columnstore-Analyse
- Plan Cache, Query Hash, Showplan und Plan-Detailanalyse
- Query Store: Laufzeitwerte, Waits, Planwechsel, Regressionen, Forced Plans und Hints
- Extended Events: Sessions, Targets, Deadlocks und Blocked-Process-Ereignisse
- SQL Agent, Resource Governor, Hochverfügbarkeit, Backup, Log Shipping und Replikation
- CPU-, NUMA-, Memory-, TempDB-, Betriebssystem-, Trace-Flag- und Sicherheitskonfiguration
- Spezialfallmodule für Integrität, Datei-/Volumekapazität, typisierte Performance Counter und kritische Engine-Ereignisse
- IQP-, Contention-, Buffer-Pool-, Backupketten-, Schema-, Statistikverteilungs-, Availability- und Agent-/Alert-Evidenz
- normalisierte diagnostische Findings mit Priorität, Konfidenz und expliziter Aussagegrenze
- versionsabhängige Capability-Erkennung, leichtgewichtige Spezialfeature-Inventur sowie isolierte In-Memory-OLTP-, Temporal-Tables-, Service-Broker-, Full-Text- und Data-Capture-/Replikations-Tiefenanalysen

## Voraussetzungen

- SQL Server 2019 oder neuer
- Installationsdatenbank, Server und `tempdb` mit der Collation `SQL_Latin1_General_CP1_CS_AS`
- ausreichende Leseberechtigungen für die verwendeten DMVs und Systemkataloge
- DDL-Rechte für die einmalige Installation der Frameworkobjekte
- SQLCMD-Modus oder PowerShell, abhängig vom gewählten Installationsweg

Das Framework vergibt selbst keine Benutzer- oder Serverberechtigungen.

## Schnellstart

### Variante 1: SQLCMD-Installer

1. Repository herunterladen oder klonen.
2. Den Platzhalter `[DeineDatenbank]` in `Code/Install/Install_All.sql` und den eingebundenen SQL-Dateien durch die vorgesehene Installationsdatenbank ersetzen.
3. `Code/Install/Install_All.sql` in SSMS oder Azure Data Studio im SQLCMD-Modus ausführen.
4. Anschließend den Smoke-Test ausführen:

```sql
USE [DeineDatenbank];
GO

:r Code/Tests/Integration/110_Smoke_Test.sql
```

### Variante 2: eigenständigen Installer erzeugen

```powershell
Set-Location ./Code/Install
./Build-StandaloneInstaller.ps1
```

Dadurch entsteht `Code/Install/Install_All.generated.sql`. In dieser Datei muss der Platzhalter `[DeineDatenbank]` nur einmal am Anfang ersetzt werden. Das generierte Build-Artefakt wird nicht versioniert.

## Erste Aufrufe

Die Beispielaufrufe verwenden absichtlich keine Datenbankqualifizierung:

```sql
EXEC [monitor].[USP_CurrentOverview];

EXEC [monitor].[USP_CurrentRequests]
      @ResultSetArt = 'CONSOLE';

EXEC [monitor].[USP_CurrentRequests]
      @GesamtenSqlTextEinbeziehen = 1
    , @InputBufferEinbeziehen     = 1
    , @MaxSqlTextZeichen          = 0;

EXEC [monitor].[USP_CurrentBlocking];

EXEC [monitor].[USP_CurrentMemoryGrants];

EXEC [monitor].[USP_ObjectAnalysis]
      @SchemaNames = N'dbo'
    , @ObjectNames = N'[BeispielObjekt]';
```

Für die vollständige Aufrufsammlung siehe:

- [`Code/Examples/040_Schnellreferenz_Aufrufe.sql`](./Code/Examples/040_Schnellreferenz_Aufrufe.sql)
- [`Code/Examples/041_Beispielaufrufe_Alle_Funktionalitaeten.sql`](./Code/Examples/041_Beispielaufrufe_Alle_Funktionalitaeten.sql)
- [`Documentation/Reference/Call_Catalog.md`](./Documentation/Reference/Call_Catalog.md)

## Ausgabearten

Öffentliche Analyse-Procedures verwenden standardmäßig:

```sql
@ResultSetArt = 'CONSOLE'
```

| Ausgabeart | Zweck |
|---|---|
| `CONSOLE` | lesbare, formatierte Ad-hoc-Ausgabe |
| `RAW` | stabiler technischer Resultset-Vertrag |
| `NONE` | keine fachlichen Resultsets, beispielsweise bei reiner JSON-Nutzung |

Viele Procedures können zusätzlich JSON über `@Json nvarchar(max) OUTPUT` zurückgeben. RAW-, CONSOLE- und JSON-Ausgabe werden aus derselben kanonischen Datenbasis erzeugt.

## Filter- und Limitvertrag

- Exakte Mehrfachfilter verwenden Pipe-Listen, beispielsweise `N'[Objekt A]|[Objekt B]'`.
- Pipe und Punkt werden nur außerhalb korrekt geklammerter SQL-Identifier als Trennzeichen interpretiert.
- Patternfilter sind von exakten Listen getrennt und unterstützen `like:`, versionsabhängig auch `regex:` und `regexi:`.
- `@MaxZeilen > 0` begrenzt die Ergebnismenge.
- `@MaxZeilen = 0` oder `NULL` bedeutet keine Ergebnisbegrenzung.
- Negative Grenzwerte sind ungültig.
- Ergebnisumfang, Zahl der Analyseobjekte und Zahl der Datenbanken werden durch getrennte Parameter gesteuert.

## SQL-Statement-Kontext

Bei laufenden Requests wird nicht nur der gesamte Batch angezeigt. Das Framework berücksichtigt `statement_start_offset` und `statement_end_offset`, um das aktuell ausgeführte Statement innerhalb eines Batches oder einer Stored Procedure exakt zu bestimmen.

Zusätzlich stehen – abhängig vom Aufruf – folgende Informationen zur Verfügung:

- qualifizierter Modulname und Modultyp
- Statement-Start- und Endposition
- Statement-Zeilenbereich
- vollständiger Batchtext
- vollständiger Modultext
- Input Buffer
- SQL-, Plan- und Statement-Handles
- Query Hash und Query Plan Hash
- Verschachtelungs-, Scheduler-, Task- und Transaktionskontext

## Repositorystruktur

```text
Code/
├── 00_Setup/
├── 01_Common/
├── 02_CurrentState/
├── 03_ObjectIndex/
├── 04_PlanCache/
├── 05_QueryStore/
├── 06_ExtendedEvents/
├── 07_Infrastructure/
├── 08_ServerHealth/
├── 09_VersionAdaptive/
├── Examples/
├── Install/
└── Tests/

Documentation/
├── Architecture/
├── Operations/
├── Quality/
├── Reference/
├── Requirements/
└── Research/

Metadata/
├── Inventory/
└── Quality/

AI_Metadata/
```

### Bedeutung

- `Code/` enthält die kanonischen, ausführbaren SQL-Objekte, Installer, Tests und Beispiele.
- `Documentation/` beschreibt Zielbild, Architektur, Funktionsumfang, Verträge, Rechercheergebnisse und Betrieb.
- `Metadata/` enthält maschinenlesbare Objekt-, Parameter-, Systemquellen-, Abhängigkeits- und Capability-Inventare sowie Prüfergebnisse.
- `AI_Metadata/` enthält den kompakten Projektkontext für eine konsistente KI-gestützte Weiterentwicklung.

## Performance- und Sicherheitsprinzipien

- lesende Diagnosepfade sind der Standard
- ressourcenintensive Katalog-, Plan- und Cross-Database-Analysen sind begrenzt und gesondert steuerbar
- Systemkataloge werden möglichst direkt und mit minimalem Blocking-Risiko gelesen
- fehlende optionale Quellen führen nach Möglichkeit zu strukturierten Teil- oder Verfügbarkeitsstatus statt zum Gesamtabbruch
- versionsabhängige Syntax wird erst nach Featureprüfung verwendet
- dynamisches SQL verwendet validierte Identifier und `QUOTENAME`
- das Datenschutz-Liefergate gilt ausschließlich für Repository-, GitHub- und Downloadartefakte; es verändert oder anonymisiert keine Resultsets oder OUTPUT-Parameter
- reale personen-, firmen-, kunden-, organisations-, betriebs- oder umgebungsbezogene Informationen und proprietäre interne Strukturen dürfen niemals in Code, Kommentare, Dokumentation, Tests, Audits oder Downloads übernommen werden; im Zweifel wird vor dem Schreiben nachgefragt

## Dokumentation

Empfohlene Einstiegspunkte:

- [Projektübersicht](./Documentation/README.md)
- [Anforderungen und Entscheidungen](./Documentation/Requirements/Requirements_and_Decisions.md)
- [Installation](./Documentation/Reference/Installation.md)
- [Procedure-Referenz](./Documentation/Reference/Procedure_Reference.md)
- [Spezialfallmodule: Evidenz, Kosten und Grenzen](./Documentation/Architecture/Special_Case_Modules.md)
- [Resultset-Konventionen](./Documentation/Reference/Resultset_Conventions.md)
- [RAW-, CONSOLE- und JSON-Architektur](./Documentation/Architecture/Output_RAW_CONSOLE_JSON.md)
- [SQL-Text-, Statement-, Batch- und Modulkontext](./Documentation/Architecture/SQL_Text_Statement_Batch_Module.md)
- [Datenschutz- und Sicherheitsvertrag für Repositoryartefakte](./Documentation/Architecture/Runtime_Data_and_Repository_Privacy.md)
- [Vertrag für ein späteres Snapshot-/Baseline-Paket](./Documentation/Architecture/Snapshot_Baseline_Package_Contract.md)
- [Schnittstellenvertrag für eine spätere Fleet-Korrelation](./Documentation/Architecture/Fleet_Correlation_Contract.md)
- [Externer Restore- und Hostnachweis](./Documentation/Quality/External_Restore_Host_Proof_Runbook.md)
- [Gate für einzeilige Commit Messages](./Documentation/Quality/Commit_Message_Validation.md)
- [Nächste Arbeitsschritte](./Documentation/Quality/Next_Steps.md)
- [Bekannte Restpunkte](./Documentation/Quality/Known_Issues.md)
- [Tiefenanalyse fehlender Auswertungen und Spezialfälle](./Documentation/Research/Special_Case_Gap_Analysis.md)
- [Systemquellenkatalog](./Documentation/Research/System_Source_Catalog.md)
- [Recherchequellen](./Documentation/Research/Sources.md)

## Qualität und Projektstatus

Der Repositorybestand enthält reproduzierbare statische API-, Installer- und Dokumentationsprüfungen sowie dokumentierte Datenschutz- und Migrationsaudits. Der historische Migrationsaudit steht unter [`Metadata/Quality/Migration_Audit.json`](./Metadata/Quality/Migration_Audit.json); der Audit der Spezialfallwelle unter [`Metadata/Quality/Special_Case_Release_Audit.json`](./Metadata/Quality/Special_Case_Release_Audit.json). Das unter [`Documentation/Quality/Repository_Privacy_Validation.md`](./Documentation/Quality/Repository_Privacy_Validation.md) beschriebene Repository- und ZIP-Datenschutzgate prüft versionierte Dateien und den vollständigen ZIP-Lieferumfang automatisiert, ohne Laufzeit-Resultsets zu verändern.

Die Version `1.1.0-special.9` ergänzt die P2-Module für Verschlüsselungslebenszyklus und Wartungsoperationen. Der Release-Gate-Vertrag umfasst nun 23 Suiten; alle 17 P0- und alle 40 P1-Fälle besitzen commitbezogene Drei-Versionen-Evidenz. Als nächste Testgruppe folgt die P2-Spezialfeature-Inventur. Weitere Feature-Positiv-, Grenzwert-, Last- und externe Restorefälle bleiben separate Nachweise.

Die geplanten SQL-Server-, Editions-, Plattform- und Berechtigungskombinationen stehen in [`Metadata/Quality/Test_Matrix.csv`](./Metadata/Quality/Test_Matrix.csv). `NOT_EXECUTED` ist ausdrücklich kein Testnachweis.

Die kanonischen Einzeldateien sind die maßgebliche Quelle. Generierte Installer dürfen nicht manuell gepflegt werden.
