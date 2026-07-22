# Releaseübersicht

## Aktueller Stand

**Frameworkversion:** `1.1.0-special.13`
**Dokumentationsstand:** 21. Juli 2026
**Mindestversion:** SQL Server 2019

Der aktuelle Bestand umfasst 161 inventarisierte Objekte:

- 94 öffentliche Procedures;
- acht Views;
- 27 Table-Valued Functions;
- 15 interne Procedures;
- 17 Tabellen.

Alle öffentlichen Procedures besitzen eine eigenständige Procedure-Seite. Alle unterstützenden Objekte besitzen einen Detailabschnitt in der Objektreferenz.

## Analysis Navigator

Der vollständige Frameworkinstaller enthält den neuen sicheren Discovery-Pfad:

- `VW_AnalysisCatalog`: eine fachliche Hauptzeile je öffentlicher Procedure;
- `VW_AnalysisSearchTerm`: deutsche und englische Symptome, Synonyme und Ziele;
- `VW_AnalysisRelation`: Vertiefungs-, Gegenproben-, Alternativ- und Vorbereitungspfade;
- `USP_AnalysisNavigator`: priorisierte Suche mit Bereich, Scope, Rolle, Kosten-, Paket- und Installationskontext.

Der Navigator führt keine gefundene Analyse aus und liest keine fachlichen DMVs oder Benutzerdaten. Er unterstützt CONSOLE, RAW, TABLE, NONE und JSON. Die Suche ist unabhängig von der Datenbankcollation case- und accent-insensitiv.

## Öffentliche Dokumentation

Der Einstieg beginnt bei Symptom und Ziel:

- [Hier beginnen](../Analysis_Guides/Start_Here.md)
- [Analysis-Navigator-Vertrag](../Reference/Analysis_Navigator.md)
- [Runbooks](../Analysis_Guides/Runbooks/README.md)
- [94 Procedure-Seiten](../Analysis_Guides/Procedures/README.md)
- [vollständige Objektreferenz](../Reference/Object_Reference.md)

Anwenderdokumentation beschreibt ausschließlich Nutzung, Architektur, Laufzeitverträge, Betrieb, Qualität und Komponenten.

## Kernfunktionen

### Live-Triage

Sessions, Requests, Blocking, Waits, Transaktionen, Memory Grants, TempDB, I/O, Log und orchestrierter Current Overview. Statementoffsets trennen das aktuell ausgeführte Statement vom Batch- und Modultext.

### Objekte und Datenbanken

Inventar, Indexnutzung, Operational Stats, Missing Indexes, Statistiken und Histogramme, Partitionen, Columnstore, Physical Stats, Schemadesign und orchestrierte Objektanalyse.

### Query und Plan

Query Stats, Query Hash, Plan Cache Health, Plan Details, Showplan, Plan-Cache-Orchestrierung sowie eigenständig installierbare Execution-Plan-Analyse mit Evidence JSON.

### Query Store

Status, Runtime- und Wait-Stats, Planwechsel, Regressionen, Forced Plans, Hints, IQP und orchestrierte Query-Store-Analyse.

### Extended Events

Session- und Targetinventar, begrenztes Ereignislesen, Deadlock- und Blocked-Process-Auswertung, Targetruntime und orchestrierte XE-Analyse.

### Infrastruktur und Betrieb

Agent, Jobs, Alerts, Database Mail, Resource Governor, Availability Groups, Backup/Recovery, Log Shipping, Replikation, Data Capture, Backupketten, Wartungsoperationen und Errorlogs.

### Server Health

CPU, NUMA, Memory, TempDB-Konfiguration, Server- und Datenbankkonfiguration, Trace Flags, Startup-Parameter, Betriebssystem, Security, Integrity, Capacity, Performance Counter, Engine-Ereignisse, Contention, Buffer Pool, Worker Pressure und normalisierte Findings.

### Versionen und Spezialfeatures

Featurecapabilities, Build/Lifecycle, Spezialfeatureinventur, In-Memory OLTP, Temporal, Service Broker, Full-Text, Data Capture und Verschlüsselung.

## Ausgabe- und Schutzvertrag

- `CONSOLE` ist der lesbare Default.
- `RAW` ist der vollständige technische Vertrag.
- `TABLE` schreibt benannte Ergebnisse ausschließlich in lokale Temp-Tabellen.
- `NONE` unterdrückt Resultsets, beispielsweise für JSON-only.
- JSON und Resultsets stammen aus derselben Materialisierung.
- High-Impact-Bestätigung gilt nur für aktivierte teure Pfade.
- Die interne Gruppenpolicy erteilt keine SQL-Server-Rechte.
- Laufzeitausgaben werden nicht automatisch anonymisiert.

## Pakete

| Paket | Bestandteil des Gesamtinstallers | Eigenständig |
|---|---:|---:|
| Frameworkkern | ja | vollständiger Installer |
| PLAN-001 Execution-Plan-Analyse | ja | ja |
| SC-023 Snapshot-/Baseline | nein | ja, separate Framework- und Zielinstallation |

Der Analysis Navigator gehört zum vollständigen Framework. PLAN-001 bleibt ohne Navigator funktionsfähig. Das Snapshotpaket richtet keinen Scheduler ein und persistiert nur nach expliziter Ziel- und Policykonfiguration.

## Kompatibilität und Nachweise

Der dokumentierte Kernvertrag ist auf SQL Server 2019, 2022 und 2025 unter der freigegebenen case-sensitive Collation nachgewiesen. Plattform-, Feature- und Lastgrenzen stehen in der [Testmatrix](Test_Matrix.md) und unter [Bekannte Einschränkungen](Known_Issues.md).

`NOT_EXECUTED` ist kein Testnachweis. Feature-Abwesenheit oder eingeschränkte Berechtigung führen nach Möglichkeit zu strukturiertem Status statt zu einem Gesamtabbruch.
