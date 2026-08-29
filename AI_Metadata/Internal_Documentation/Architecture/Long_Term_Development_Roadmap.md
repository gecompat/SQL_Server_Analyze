# Langfristige Weiterentwicklungsroadmap

**Referenz:** `WI-0001`
**Status:** `ACTIVE`
**Stand:** 29. August 2026
**Geltungsbereich:** SQL Server 2019 und neuer auf On-Premises-, VM- und Containerplattformen

## Zweck und Maßgeblichkeit

Diese Roadmap ordnet die langfristige Weiterentwicklung von SQL Server Analyze. Sie beschreibt priorisierte Entwicklungsrichtungen, Abhängigkeiten und Exit-Kriterien. Sie ist kein öffentlicher Produktvertrag und stellt geplante Arbeit nicht als implementiert dar.

Der aktuelle ausführbare Schwerpunkt steht in [Nächste Arbeitsschritte](../Quality/Next_Steps.md). Produktstatus und Laufzeitevidenz bleiben in `Metadata/Quality/Implementation_Status.csv`, `Metadata/Inventory/Module_Maturity.csv` und den jeweils genannten Evidenzquellen maßgeblich. Neue technische Verträge entstehen erst in der Analyse- und Spezifikationsphase des jeweiligen Arbeitselements.

## Ausgangslage

Der Frameworkkern umfasst 104 dokumentierte Procedures. Alle 104 Procedure-Seiten besitzen den Status `DEEP_REVIEWED` nach Reviewvertrag 3. Die P0-, P1- und P2-Spezialfallmatrix ist umgesetzt. Die wesentlichen offenen Arbeiten bestehen aus:

- fehlender Runtime- und Reifegradevidenz für bereits nutzbare Teilfunktionen;
- der Collation-Härtung außerhalb der garantierten Testgrenze;
- gezielten SQL-Server-2025-Erweiterungen;
- zusätzlicher lokaler Zeitreihenevidenz;
- zwei neuen, klar abgegrenzten Diagnosebereichen;
- externen oder plattformspezifischen Nachweisen und Paketen.

Diese Ausgangslage begründet eine qualitäts- und evidenzorientierte Reihenfolge. Neue Procedures werden nur vorgesehen, wenn die Diagnosefrage nicht sinnvoll durch eine Erweiterung vorhandener Module beantwortet werden kann.

## Priorisierungsgrundsätze

1. Bereits implementierte Teilfunktionen erhalten vor zusätzlichen Spezialmodulen ihren vorgesehenen Reifegrad.
2. Eine Erweiterung bestehender Procedures hat Vorrang vor einer neuen öffentlichen Procedure, wenn Scope, Kostenklasse und Aussagegrenze zusammenpassen.
3. SQL-Server-2025-Funktionen werden versions- und capability-adaptiv ergänzt. Ein neuer Konfigurationswert ist allein kein Fehlerbefund.
4. Historische Evidenz wird ausschließlich im optionalen Snapshotpaket persistiert. Der Frameworkkern bleibt zustandslos.
5. Featureabhängige Spezialanalysen benötigen eine sichtbare Nutzung oder eine konkrete betriebliche Frage. Reine Katalogexistenz ist kein Gesundheitsurteil.
6. Jede Welle muss ihren eigenen Produkt-, Dokumentations- und Evidenzvertrag erfüllen, bevor abhängige Arbeit den Status wechselt.
7. Azure SQL Database und Azure SQL Managed Instance gehören nicht zu dieser Roadmap. Eine spätere Plattformausweitung benötigt ein eigenes registriertes Arbeitselement.

## Verbindlicher Dossierprozess

Jedes Arbeitselement durchläuft vier getrennte Schritte. Ein Schritt darf bestätigte Ergebnisse des vorherigen Schritts übernehmen, aber keine noch offene Entscheidung als umgesetzt behandeln.

### 1. Analyse

Die Analyse dokumentiert die konkrete Diagnosefrage, den Anwendernutzen, bestehende Frameworkabdeckung, offizielle Primärquellen, Versionen, Plattformen, Berechtigungen, Datenquellen, Scope, Zeitbezug, Eigenlast, Locking, Datenschutz, False-Positive-Grenzen und Gegenprüfungen. Sie entscheidet außerdem, ob eine Erweiterung eines bestehenden Moduls genügt.

### 2. Spezifikation

Die Spezifikation legt öffentliche Procedurezuordnung, Parameter, benannte Resultsets, native Schemas, JSON-Version, Statuscodes, Capabilityprobes, Kostenklasse, High-Impact-Gate, Filter, Limits, Partialitätsmodell und Abnahmeszenarien fest. Eine neue öffentliche Procedure ist ausdrücklich zu begründen.

### 3. Vertikale Implementierung

Die Implementierung ändert kanonische Einzelobjekte, Installer, Objekt-, Parameter-, Resultset-, Systemquellen- und Capabilityinventare sowie Navigator, Hilfe und Dokumentation gemeinsam. Jede optionale Quelle wird isoliert und fehlertolerant gelesen. Teure Pfade werden vor dem ersten Zugriff begrenzt und gegebenenfalls freigegeben.

### 4. Evidenz und Statuswechsel

Die Validierung folgt der verbindlichen CI-Teststrategie. Ein Statuswechsel setzt die tatsächlich erforderliche statische, funktionale, versions-, berechtigungs- und featurebezogene Evidenz voraus. `NOT_EXECUTED` und geplante manuelle Prüfungen sind kein Laufzeitnachweis.

## Registrierte Roadmap-Arbeitselemente

| Referenz | Priorität | Status | Dossierabschnitt |
|---|---|---|---|
| `WI-0001` | `P1` | `ACTIVE` | diese kanonische Roadmap |
| `WI-0002` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | TempDB-ADR- und PVS-Diagnostik |
| `WI-0003` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | Backup-Kompressionsalgorithmus- und ZSTD-Evidenz |
| `WI-0004` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | geordnete Columnstore-Diagnostik |
| `WI-0005` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | zeitbegrenzte Extended-Events-Sessions |
| `WI-0006` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | `OPTIMIZED_SP_EXECUTESQL` und Compile-Kontext |
| `WI-0007` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | External-Model-Inventur |
| `WI-0008` | `P1` | `RESEARCHED_NOT_IMPLEMENTED` | SQL-Audit-Konfigurationsanalyse |
| `WI-0009` | `P2` | `RESEARCHED_NOT_IMPLEMENTED` | External-Data-Analyse |
| `WI-0010` | `P1` | `RESEARCHED_NOT_IMPLEMENTED` | kontinuierliche Diagnoseabdeckung und Gap-Intake |

## Wellenübersicht

| Welle | Ergebnis | Enthaltene Referenzen | Eintrittsbedingung | Exit-Kriterium |
|---|---|---|---|---|
| 1 | Vorhandene Funktionen produktreif | `OPS-005` bis `OPS-009`, `COLL-001`, `ANALYZE-LAB-001` | aktueller `main` und vorhandene Teilfunktionen unverändert validierbar | vorgesehene Runtime-, Dokumentations- und Collationnachweise sind abgeschlossen oder als externe Evidenz präzise getrennt |
| 2 | SQL-Server-2025-Diagnostik vervollständigt | `WI-0002` bis `WI-0007` | Welle 1 besitzt keine ungeklärte frameworkweite Vertragsabweichung | alle neuen Quellen sind versionsadaptiv, schemafest und auf 2025 positiv sowie auf älteren Versionen mit dem vorgesehenen Fallback geprüft |
| 3 | Historische lokale Diagnose erweitert | `SC-023-EXPANSION` | aktuelle Collector- und Retentionverträge sind stabil | Wait-, I/O- und Kapazitätsverläufe sind reset-sicher erfassbar; Rollups und Scheduler bleiben getrennt aktivierbar |
| 4 | Neue Diagnosebereiche verfügbar | `WI-0008`, `WI-0009` | Wellen 1 und 2 sind abgeschlossen; Snapshotarbeit blockiert keine gemeinsame Infrastruktur | Audit und externe Datenobjekte besitzen jeweils einen abgegrenzten read-only Vertrag und kontrollierte Positiv-/Negativfälle |
| 5 | Strategische Pakete und externe Evidenz | `SSIS-001`, `RUNTIME-001`, `SC-024`, `SC-025` | erforderliche Plattformen, Zuständigkeiten und Sicherheitsgrenzen sind freigegeben | der jeweils abgegrenzte Produkt- oder externe Evidence-Vertrag ist nachweislich erfüllt |
| kontinuierlicher Intake | Abdeckungslücken sichtbar und priorisierbar | `WI-0010` | aktuelle Inventare und offizielle Primärquellen sind verfügbar | Kandidaten sind als bestehend, partiell, geplant, extern oder ausgeschlossen klassifiziert und werden erst nach eigener Registrierung in eine Entwicklungswelle übernommen |

## Welle 1: Reifeabschluss vorhandener Funktionen

Jeder nachfolgende Abschnitt der Wellen 1 bis 5 ist ein eigenes Dossier. Er muss die vier Schritte Analyse, Spezifikation, vertikale Implementierung sowie Evidenz und Statuswechsel getrennt durchlaufen. Auch gemeinsam priorisierte Themen dürfen diese Schritte nicht als Sammeländerung überspringen.

### `OPS-005`: Linked-Server-Inventar

Der implementierte read-only Kern erhält die noch fehlenden Drei-Versionen-, Berechtigungs-, Timeout- und kontrollierten Remote-Testnachweise. Der Remotezugriff bleibt standardmäßig deaktiviert und darf nur in einem ausdrücklich aktivierten, begrenzten Pfad erfolgen. Vorhandene öffentliche Resultsets werden nicht beiläufig verändert.

### `OPS-006`: Datenbankportabilität

Die persistierten Edition Features und uncontained dependencies erhalten portable, featuregebundene, nicht unterstützte, unberechtigte und versionsübergreifende Evidenz. Aussagegrenzen trennen sichtbare Hindernisse von einer vollständigen Migrationsfreigabe.

### `OPS-007`: Cursor-Diagnostik

Der vorhandene begrenzte opt-in Pfad erhält Kosten-, Sichtbarkeits-, Berechtigungs- und Leerfallnachweise. Eine Momentaufnahme darf weder die Ursache noch die erforderliche Codeänderung automatisch festlegen.

### `OPS-008`: `msdb`-Gesundheit und Retention

Die Analyse sichtbarer Backup-, Restore-, Job-, Mail- und Wartungshistorien erhält Leer-, Retention-, Wachstum-, Berechtigungs- und Begrenzungsfälle. Das Modul führt keine Bereinigung aus und leitet aus der Größe allein keine Retentionentscheidung ab.

### `OPS-009`: Benutzerobjekte in Systemdatenbanken

Das sichtbare Inventar erhält positive, leere, unberechtigte und versionsübergreifende Fälle. Es löscht, verschiebt oder verändert keine Objekte und stellt die bloße Existenz nicht automatisch als Defekt dar.

### `COLL-001`

Die vorhandene Boundary-Inventur wird in eine per-Datei-Härtung und eine gemischte Server-, `tempdb`-, Framework- und TABLE-Zielmatrix überführt. Bis zum vollständigen Nachweis bleibt `SQL_Latin1_General_CP1_CS_AS` die einzige garantierte Collation. Eine erfolgreiche Teilmatrix erweitert den öffentlichen Vertrag nicht vorzeitig.

### `ANALYZE-LAB-001`

Der definierte Sieben-Beispiele-Umfang ist umgesetzt. `BLOCKING-001` besitzt die bestehende Mehrversions- und Provider-Evidenz; die sechs weiteren Beispiele besitzen getrennte SQL-Server-2025-Runtime-Slices über den primären Docker-Provider. SQL Server Analyze verantwortet Beispielkatalog, synthetische Fixtures, Workloads, Analyzer-Aufrufe, Assertions und projektspezifisches Cleanup. Provider-, Ressourcen-, Lifecycle- und allgemeine Laufzeitverantwortung verbleiben in `SQL_Server_Lab`.

### Dokumentationsreife

Die zwölf zuvor als `BASELINE` geführten Procedure-Seiten wurden am 28. August 2026 nach dem aktuellen Deep-Review-Vertrag geprüft. Entscheidungsfrage, sicherer Einstieg, Leserichtung, Eigenlast, Quellen, Aussagegrenzen und Folgeanalyse sind in den Seiten sowie im Reviewinventar nachgeführt. Die Dokumentationsreife dieses Wellenanteils ist damit abgeschlossen; die noch offene Laufzeitevidenz der betreffenden Funktionen bleibt davon getrennt.

## Welle 2: SQL-Server-2025-Erweiterungen

### `WI-0002`: TempDB-ADR- und PVS-Diagnostik

Die spätere Analyse prüft eine Erweiterung von `USP_CurrentTempDB` um ein eigenes Resultset für traditionellen Version Store und Persistent Version Store in `tempdb`. Größe, Cleanupindikatoren, Reset- und Quellstatus müssen getrennt bleiben. Die Funktion darf weder ADR empfehlen noch aus einem Einzelwert eine Kapazitätsursache ableiten.

Primärquellen: [tempdb Database](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database?view=sql-server-ver17) und [`sys.dm_tran_persistent_version_store_stats`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-persistent-version-store-stats?view=sql-server-ver17).

### `WI-0003`: Backup-Kompressionsalgorithmus- und ZSTD-Evidenz

Die spätere Analyse prüft die getrennte Darstellung von Serverdefault, tatsächlich in `msdb.dbo.backupset` dokumentiertem Algorithmus und versionsabhängiger Capability. ZSTD, MS_XPRESS und QAT dürfen nicht aus dem allgemeinen Kompressionsstatus abgeleitet werden. Restorefähigkeit und CPU-/Durchsatzwirkung bleiben eigene Evidenzfragen.

Primärquellen: [Backup compression algorithm](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/view-or-configure-the-backup-compression-algorithm-server-configuration-option?view=sql-server-ver17) und [`backupset`](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backupset-transact-sql?view=sql-server-ver17).

### `WI-0004`: Geordnete Columnstore-Diagnostik

Die spätere Analyse prüft eine Erweiterung von `USP_Columnstore` um geordnete gruppierte und nicht gruppierte Columnstore-Indizes, Order-Spalten und versionsabhängige Clusteringmetadaten. Eine optionale Segmentüberlappungsanalyse muss vor dem breiten Segmentzugriff begrenzt werden. Unvollständige Ordnung ist kein automatischer Defekt.

Primärquelle: [What's new in columnstore indexes](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-what-s-new?view=sql-server-ver17).

### `WI-0005`: Zeitbegrenzte Extended-Events-Sessions

Die spätere Analyse prüft die Erweiterung von `USP_ExtendedEventsSessions` um `MAX_DURATION`, Runtimezustand und Restlaufzeitgrenze. Das Framework erstellt, startet, stoppt oder verändert keine Session. Ein unbegrenzter Wert ist ohne Capturezweck und Lastkontext kein Fehler.

Primärquelle: [Extended Events sessions](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/sql-server-extended-events-sessions?view=sql-server-ver17).

### `WI-0006`: `OPTIMIZED_SP_EXECUTESQL` und Compile-Kontext

Die spätere Analyse ergänzt Capability- und Konfigurationssicht und bewertet, ob vorhandene Performance-Counter-, Plan-Cache- und Wait-Evidenz für eine belastbare Compile-Storm-Korrelation ausreicht. Der Konfigurationszustand allein erzeugt kein Finding. Ein erforderliches Sampling bleibt begrenzt und explizit.

Primärquelle: [`ALTER DATABASE SCOPED CONFIGURATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql?view=sql-server-ver17).

### `WI-0007`: External-Model-Inventur

Die spätere Analyse ergänzt `USP_SpecialFeatureInventory` um eine aggregierte, versionsadaptive Erkennung von External Models. Locations, Parameter, Modellnamen und Credentialbezüge bleiben in der leichten Inventur ausgeschlossen. Eine eigene Gesundheitsanalyse wird dadurch nicht vorweggenommen.

Primärquelle: [`sys.external_models`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-external-models-transact-sql?view=sql-server-ver17).

## Welle 3: `SC-023-EXPANSION`

Der erste Ausbau-Slice erfasst Wait-Stats- und Datei-I/O-Deltas mit UTC, Reset-Epoche, Scope, Einheit und Quellenstatus. Der zweite Slice ergänzt Datenbank-, Datei-, Log- und TempDB-Kapazität sowie begrenzte Worker-, Scheduler- und Resource-Semaphore-Metriken. Erst danach werden stündliche und tägliche Rollups sowie ein getrenntes idempotentes SQL-Agent-DDL-Paket spezifiziert.

Payloads, Export und Fleet-Transport bleiben standardmäßig deaktiviert. Collector, Rollups und Scheduler erhalten getrennte Status- und Aktivierungsverträge. Ein Baselinevergleich ist nur bei kompatibler Metrikdefinition, Einheit, Scope, Vertragsversion und Reset-Epoche zulässig.

## Welle 4: Neue Diagnosebereiche

### `WI-0008`: SQL-Audit-Konfigurationsanalyse

Vorgesehen ist eine neue `USP_AuditConfigurationAnalysis`. Die spätere Spezifikation prüft getrennte Resultsets für Audits, Server- und Datenbankspezifikationen, Quellenstatus und Warnungen. Gelesen werden ausschließlich Konfigurations- und Runtimezustände. Auditlog-Payloads, Dateiinhalte und Änderungen an Auditobjekten bleiben ausgeschlossen.

Primärquelle: [SQL Server Audit](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine?view=sql-server-ver17).

### `WI-0009`: External-Data-Analyse

Vorgesehen ist eine neue `USP_ExternalDataAnalysis` für lokale Kataloge externer Datenquellen, Dateiformate, Tabellen und Modelle. Remotezugriff und Connectivitytests sind nicht Bestandteil des Standardvertrags. Verbindungsorte, Credentialnamen und weitere sensible Metadaten benötigen vor einer möglichen Ausgabe eine ausdrückliche Detail- und Datenschutzentscheidung; Secrets und externe Payloads werden niemals gelesen.

Primärquelle: [External operations catalog views](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/external-operations-catalog-views-transact-sql?view=sql-server-ver17).

Graph, Spatial, XML, FILESTREAM und benutzerdefinierte Typen bleiben zunächst in Inventar-, Objekt- und Indexpfaden. Ein eigenes Deep-Modul wird nur nach einem konkreten Nutzungsszenario und einem neuen registrierten Arbeitselement bewertet. Die vollständige Einordnung steht in der [Diagnoseabdeckung und Gap-Intake](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md).

## Welle 5: Strategische und externe Arbeiten

### `SSIS-001`

Nach dem abgeschlossenen Phase-0-Vertrag folgt zunächst der statische DTSX-v2-Parser. Inventar, Control-Flow- und Data-Flow-Graphen werden vor Regelengine, SQL-Metadatenprüfung und Laufzeitadaptern stabilisiert. Dateisystem- und ISPAC-Zugriffe bleiben ein getrenntes Paket.

### `RUNTIME-001`

Der portable read-only Kern bleibt implementiert. Offen sind kontrollierte Positivnachweise für aktivierte External Runtimes und eine synthetische `SAFE`-Assembly. Fehlende externe Evidenz darf den vorhandenen Produktkern weder als unimplementiert noch als vollständig featurevalidiert darstellen.

### `SC-024`: Fleet-Korrelation

Fleet-Korrelation bleibt eine externe Komponente mit eigenem Mandanten-, Transport-, Retention- und Löschvertrag. Das Dossier beginnt erst, wenn Zuständigkeit, Hostinggrenze, Datenschutz und Betriebsmodell freigegeben sind. Diese Arbeit erweitert den T-SQL-Kern nicht stillschweigend.

### `SC-025`: Restore- und Hostevidenz

Restore-, Storage- und Hostnachweise werden nur in einer ausdrücklich autorisierten isolierten Umgebung ausgeführt. Das Dossier trennt Runbook, Testdaten, Berechtigungen, Cleanup, Ergebnisartefakte und Aussagegrenzen von der portablen Frameworkvalidierung.

## Kontinuierlicher Intake: `WI-0010`

Die [SQL-Server-Diagnoseabdeckung](../Research/SQL_Server_Diagnostic_Coverage_Landscape.md) führt 106 fachliche Bereiche mit stabilen Matrixschlüsseln. Sie unterscheidet vertiefte und grundlegende Implementierung, partielle Produktfunktion, registrierte Planung, neue Dossierkandidaten, externe Evidenz und bewussten Produktausschluss.

Bestätigte neue P1-Kandidaten betreffen insbesondere Principals und Berechtigungen, Authentisierungs- und Login-Lifecycle, TLS und Endpoints, Upgrade- und Deprecation-Evidenz, Legacy-Datenbankspiegelung, MSDTC, Linux-/Container-Ressourcengrenzen sowie Row-Level Security und Dynamic Data Masking. P2- und P3-Kandidaten umfassen unter anderem Database Snapshots, Policy-Based Management, Sensitivity Classification, Ledger-Verifikation, FILESTREAM, Plan Guides, Agent-Proxies, Change Event Streaming, Fabric Mirroring, External REST, Hybrid Buffer Pool sowie bedingte Graph-, Spatial-, XML- und JSON-Vertiefungen.

`WI-0010` ändert weder die Reihenfolge laufender Wellen noch öffentliche Schnittstellen. Ein Matrixschlüssel wird erst nach Priorisierungsentscheidung, Überschneidungsprüfung und finaler Registryvergabe zu einem eigenen Arbeitselement. So bleibt die Themenbreite dauerhaft sichtbar, ohne ungeprüfte API- oder Lieferzusagen zu erzeugen.

## Abhängigkeiten

- Welle 2 hängt vom Reifeabschluss der gemeinsam verwendeten Ausgabe-, Capability-, Dokumentations- und Versionsverträge aus Welle 1 ab.
- `WI-0007` liefert nur eine Inventur. `WI-0009` darf deren Erkennung später vertiefen, ohne die Featureidentität umzudeuten.
- `SC-023-EXPANSION` verwendet ausschließlich bereits definierte Metrik-, Scope-, Retention-, Budget- und Resetverträge des Snapshotpakets.
- `WI-0008` und `WI-0009` dürfen neue öffentliche Procedures erst nach abgeschlossenem API- und Kostenreview einführen.
- `SSIS-001`, `RUNTIME-001`, `SC-024` und `SC-025` benötigen ihre dokumentierten Plattform- beziehungsweise externen Voraussetzungen; sie blockieren den portablen Kern nicht.
- `WI-0010` läuft als Intake parallel, darf aber kein bereits registriertes Dossier und kein Wellengate überspringen.

## Ausschlüsse

Diese Roadmap autorisiert keine Konfigurationsänderung, automatische Optimierung, Wartungsaktion, Auditänderung, XE-Session-Erstellung, Remoteverbindung, externe API-Nutzung, DDL an untersuchten Objekten oder Übernahme allgemeiner Lab-Provisionierung. Sie erweitert den Plattformvertrag nicht auf Azure SQL Database oder Azure SQL Managed Instance und erzeugt keine Vollständigkeitsgarantie für Feature-, Runtime- oder Historienevidenz.

## Pflege und Abschluss

Neue Erkenntnisse aktualisieren das betroffene Arbeitselement und seine Relationen; sie erzeugen keine neue Identität für denselben logischen Umfang. Priorität, Welle, Status und Pfad sind veränderbare Metadaten. Eine Initiative gilt erst als abgeschlossen, wenn Code, Installer, Inventare, Dokumentation, statische Verträge und die gemäß CI-Strategie erforderliche Runtimeevidenz übereinstimmen.
