# Analysehandbuch für SQL_Server_Analyze

**Stand:** 20. Juli 2026
**Geltungsbereich:** 93 Procedures
**Zielgruppe:** Analyseanfänger, Datenbankentwickler und SQL-Server-Administratoren

## Empfohlener Einstieg

1. Bei einem konkreten Symptom im [Runbook-Verzeichnis](Runbooks/README.md) beginnen.
2. Die betreffende [eigenständige Procedure-Seite](Procedures/README.md) lesen.
3. Unbekannte Begriffe im [Glossar](Glossary.md) nachschlagen.
4. Parameter anhand der [Parameter-Lesehilfe](Parameter_Reading_Guide.md) und `@Hilfe=1` prüfen.
5. Für vollständige Resultsets und Spalten in den verlinkten Familienguide wechseln.

Das gemeinsame [Execution-, Zeit- und Evidenzmodell](Technical_Foundations.md) gilt für alle Procedure-Seiten.

Alle 93 Seiten sind strukturell vollständig. Davon sind 88 nach dem [Qualitätsvertrag](Documentation_Quality_Contract.md) fachlich `DEEP_REVIEWED`; die fünf eigenständig installierbaren PLAN-001-/SC-023-Seiten stehen auf `BASELINE`. [USP_CurrentRequests](Procedures/USP_CurrentRequests.md), [USP_IndexPhysicalStats](Procedures/USP_IndexPhysicalStats.md) und [USP_ExtendedEventsReadEvents](Procedures/USP_ExtendedEventsReadEvents.md) bleiben Kalibrierungsfälle für Live-Snapshot, physischen Scan und Datei-/XML-Analyse.

Das [Forschungs- und Redaktionskonzept](Authoring/Deep_Research_Analysis_Guides_Concept.md) ist kein Anwenderhandbuch.

## Feste Leserichtung

1. Status und Vollständigkeit,
2. Scope und Zeilengranularität,
3. Zeitbezug, Reset oder Retention,
4. Nenner und Datenmenge,
5. Kombination zusammengehöriger Werte,
6. technische Ursachehypothese,
7. Auswirkung und Gegenbeispiel,
8. zweite unabhängige Evidenzquelle,
9. erst danach Änderung und Rollback planen.

## Dokumente

| Zweck | Dokument |
|---|---|
| Direkte Seite je Procedure | [Procedures/README.md](Procedures/README.md) |
| Symptomorientierte Abläufe | [Runbooks/README.md](Runbooks/README.md) |
| Begriffserklärungen | [Glossary.md](Glossary.md) |
| Parameter und sichere Aufrufe | [Parameter_Reading_Guide.md](Parameter_Reading_Guide.md) |
| Gemeinsame Verträge | [Common_Contracts.md](Common_Contracts.md) |
| Technische Grundlagen einschließlich Kostenmodell | [Technical_Foundations.md](Technical_Foundations.md) |
| Versions- und Primärquellennachweis | [Version_Primary_Source_Matrix.md](Version_Primary_Source_Matrix.md) |
| Vollständiger Objektindex | [Object_Index.md](Object_Index.md) |
| Redaktionsstandard | [Documentation_Quality_Contract.md](Documentation_Quality_Contract.md) |
| Reviewstatus je Procedure | [Analysis_Documentation_Review.csv](../../Metadata/Quality/Analysis_Documentation_Review.csv) |

## Familienguides

| Bereich | Dokument | Procedures |
|---|---|---:|
| Common | [01_Common.md](01_Common.md) | 4 |
| Current State | [02_Current_State.md](02_Current_State.md) | 11 |
| Object und Index | [03_Object_Index.md](03_Object_Index.md) | 11 |
| Plan Cache | [04_Plan_Cache.md](04_Plan_Cache.md) | 8 |
| Query Store | [05_Query_Store.md](05_Query_Store.md) | 9 |
| Extended Events | [06_Extended_Events.md](06_Extended_Events.md) | 6 |
| Infrastruktur | [07_Infrastructure.md](07_Infrastructure.md) | 13 |
| Server Health | [08_Server_Health.md](08_Server_Health.md) | 19 |
| Versionsadaptive Spezialanalysen | [09_Version_Adaptive.md](09_Version_Adaptive.md) | 9 |
| **Integriertes Framework gesamt** | | **90** |

Die zwei PLAN-001-Procedures sind zusätzlich eigenständig installierbar, gehören aber auch zum Gesamtinstaller. Die drei SC-023-Procedures bleiben vollständig optional und außerhalb von `Install_All.sql`; beide Pakete besitzen separate Architektur- und Betriebshandbücher.

## Schnellwahl nach Symptom

| Symptom | Erster Aufruf | Runbook |
|---|---|---|
| Hänger/Blocking | `USP_CurrentOverview` | [Blocking](Runbooks/01_User_Hangs_Blocking.md) |
| CPU hoch | `USP_CurrentRequests`, `USP_QueryStats` | [High CPU](Runbooks/02_High_CPU.md) |
| Query plötzlich langsamer | `USP_QueryStoreRegressions` | [Regression](Runbooks/03_Query_Regression.md) |
| TempDB wächst | `USP_CurrentTempDB` | [TempDB](Runbooks/04_TempDB_Growth.md) |
| Log läuft voll | `USP_CurrentLog` | [Transaction Log](Runbooks/05_Transaction_Log_Full.md) |
| Grants warten | `USP_CurrentMemoryGrants` | [Memory Grants](Runbooks/06_Memory_Grant_Queue.md) |
| I/O-Latenz | `USP_CurrentIO` | [I/O](Runbooks/07_IO_Latency.md) |
| Index ungenutzt | `USP_IndexUsage` | [Unused Index](Runbooks/08_Unused_Index.md) |
| Backup/Integrität | `USP_DatabaseIntegrityAnalysis` | [Backup/Integrity](Runbooks/09_Backup_Integrity_Risk.md) |
| AG-Lag | `USP_AvailabilityDeepAnalysis` | [AG Lag](Runbooks/10_Availability_Group_Lag.md) |

## Evidenzarten

- Live-Momentaufnahme: flüchtiger aktueller Zustand.
- Stichprobe/Delta: Veränderung innerhalb eines Intervalls.
- kumulative DMV: seit Reset oder Cachelebensdauer.
- persistierte Historie: abhängig von Capture und Retention.
- Ereignishistorie: nur konfigurierte und noch vorhandene XE-Daten.
- Katalog/Konfiguration: sichtbarer Berechtigungs- und Plattformscope.

## Grundsatz für Änderungen

Kein einzelnes Resultset rechtfertigt automatisch `KILL`, DDL, Rebuild, Plan Forcing, Konfigurationsänderung, Failover oder Repair. Zweite Evidenzquelle, Auswirkung, Risiko und Rollbackweg sind vorher zu bestimmen.

## Qualität prüfen

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Siehe [Validierungsanleitung](../Quality/Analysis_Documentation_Validation.md).
