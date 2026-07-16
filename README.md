# SQL-Server Analyze Tool

# ⚠️ READ BEFORE USE

**NOTICE: This software is NOT Open Source. Use is governed by a custom Community & Attribution License.**

1. **NO RESALE:** Selling or charging for access to this software is strictly prohibited.
2. **ATTRIBUTION REQUIRED:** You must preserve the copyright notice for **gecompat - Gerhard Pisch**.
3. **NO LIABILITY:** Use this software at your own risk. The author is **NOT liable** for any damages, data loss, or business interruptions.

Full legal terms can be found in the [LICENSE.md](./LICENSE.md) file.

> Hinweis zur Dateibenennung: Die im Repository vorhandene Lizenzdatei ist [`LICENCE.md`](./LICENCE.md).

---

## Überblick

SQL Server Analyze ist ein T-SQL-basiertes Diagnoseframework für SQL Server ab Version 2019. Es unterstützt Ad-hoc-Analysen laufender Prozesse ebenso wie tiefergehende Untersuchungen von Objekten, Indizes, Ausführungsplänen, Query Store, Extended Events, Serverkonfiguration und Infrastrukturkomponenten.

Das Framework wird in einer frei wählbaren Datenbank im Schema `[monitor]` installiert. Konkrete Datenbank-, Server-, Benutzer-, Kunden- oder Unternehmensbezeichnungen sind nicht Bestandteil des Projektcodes.

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
- versionsabhängige Featureerkennung mit strukturierten Fallback- und Statusinformationen

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
├── Quality/
└── MANIFEST.csv

AI_Metadata/
```

### Bedeutung

- `Code/` enthält die kanonischen, ausführbaren SQL-Objekte, Installer, Tests und Beispiele.
- `Documentation/` beschreibt Zielbild, Architektur, Funktionsumfang, Verträge, Rechercheergebnisse und Betrieb.
- `Metadata/` enthält maschinenlesbare Objekt- und Parameterinventare sowie Prüfergebnisse und Dateihashes.
- `AI_Metadata/` enthält den kompakten Projektkontext für eine konsistente KI-gestützte Weiterentwicklung.

## Performance- und Sicherheitsprinzipien

- lesende Diagnosepfade sind der Standard
- ressourcenintensive Katalog-, Plan- und Cross-Database-Analysen sind begrenzt und gesondert steuerbar
- Systemkataloge werden möglichst direkt und mit minimalem Blocking-Risiko gelesen
- fehlende optionale Quellen führen nach Möglichkeit zu strukturierten Teil- oder Verfügbarkeitsstatus statt zum Gesamtabbruch
- versionsabhängige Syntax wird erst nach Featureprüfung verwendet
- dynamisches SQL verwendet validierte Identifier und `QUOTENAME`
- konkrete umgebungs- oder personenbezogene Daten gehören weder in Code noch in Dokumentation oder Beispiele

## Dokumentation

Empfohlene Einstiegspunkte:

- [Projektübersicht](./Documentation/README.md)
- [Anforderungen und Entscheidungen](./Documentation/Requirements/Requirements_and_Decisions.md)
- [Installation](./Documentation/Reference/Installation.md)
- [Procedure-Referenz](./Documentation/Reference/Procedure_Reference.md)
- [Resultset-Konventionen](./Documentation/Reference/Resultset_Conventions.md)
- [RAW-, CONSOLE- und JSON-Architektur](./Documentation/Architecture/Output_RAW_CONSOLE_JSON.md)
- [SQL-Text-, Statement-, Batch- und Modulkontext](./Documentation/Architecture/SQL_Text_Statement_Batch_Module.md)
- [Recherchequellen](./Documentation/Research/Sources.md)

## Qualität und Projektstatus

Der Repositorybestand enthält statische API-, Installer-, Datenschutz- und Manifestprüfungen. Der aktuelle Audit ist unter [`Metadata/Quality/Migration_Audit.json`](./Metadata/Quality/Migration_Audit.json) dokumentiert.

Vor einem produktiven Einsatz sind weiterhin reale Compile- und Smoke-Tests auf den vorgesehenen SQL-Server-Versionen und Editionsvarianten erforderlich.

Die kanonischen Einzeldateien sind die maßgebliche Quelle. Generierte Installer dürfen nicht manuell gepflegt werden.
