# Releaseübersicht

## Aktueller Stand

| Merkmal | Stand |
|---|---|
| Frameworkversion | `1.1.0-special.13` |
| Dokumentationsstand | 22. Juli 2026 |
| Mindestversion | SQL Server 2019 |

Der aktuelle Bestand umfasst 161 inventarisierte Objekte:

- 94 öffentliche Procedures;
- acht Views;
- 27 Table-Valued Functions;
- 15 interne Procedures;
- 17 Tabellen.

Alle öffentlichen Procedures besitzen eine eigenständige Procedure-Seite. Alle unterstützenden Objekte besitzen einen Detailabschnitt in der Objektreferenz.

## Dokumentationsstil

Der dokumentierte Bestand wurde gegen die verbindliche Schreibstilrichtlinie geprüft. Die Überarbeitung entfernt wiederholte Standardabsätze, vervollständigt fragmentarische Leserichtungen und vereinheitlicht die sachliche Darstellung in öffentlichen und maßgeblichen internen Dokumenten sowie in SQL-Dateiköpfen und Hilfeausgaben.

Eine zusätzliche statische Prüfung blockiert die konkret entfernten Rückfallmuster. Sie ergänzt das weiterhin erforderliche fachliche und sprachliche Review, bewertet jedoch weder technische Richtigkeit noch die Angemessenheit einer Aussage im jeweiligen Betriebskontext.

## Analysis Navigator

Der Gesamtinstaller enthält folgenden Discovery-Pfad:

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

Die Live-Triage erfasst Sessions, Requests, Blocking, Waits, Transaktionen, Memory Grants, TempDB, I/O und das Transaktionslog. `USP_CurrentOverview` orchestriert diese Perspektiven; Statementoffsets trennen das aktuell ausgeführte Statement vom Batch- und Modultext.

### Objekte und Datenbanken

Die Objekt- und Datenbankanalyse umfasst Inventar, Indexnutzung, Operational Stats, Missing Indexes, Statistiken und Histogramme, Partitionen, Columnstore, Physical Stats und Schemadesign. `USP_ObjectAnalysis` orchestriert die zugehörigen Einzelmodule.

### Query und Plan

Die Query- und Plananalyse umfasst Query Stats, Query Hash, Plan Cache Health, Plan Details, Showplan und die Plan-Cache-Orchestrierung. Die Execution-Plan-Analyse mit Evidence JSON kann zusätzlich eigenständig installiert werden.

### Query Store

Die Query-Store-Module analysieren Status, Runtime- und Wait-Stats, Planwechsel, Regressionen, Forced Plans, Hints und Intelligent Query Processing. `USP_QueryStoreAnalysis` orchestriert die Einzelmodule.

### Extended Events

Die Extended-Events-Module liefern ein Session- und Targetinventar, begrenztes Ereignislesen, Deadlock- und Blocked-Process-Auswertung sowie Targetruntime. `USP_ExtendedEventsAnalysis` orchestriert diese Pfade.

### Infrastruktur und Betrieb

Die Infrastrukturanalyse umfasst SQL Server Agent, Jobs, Alerts, Database Mail, Resource Governor, Availability Groups, Backup und Recovery, Log Shipping, Replikation, Data Capture, Backupketten, Wartungsoperationen und Errorlogs.

### Server Health

Die Server-Health-Module untersuchen CPU, NUMA, Memory, TempDB-Konfiguration, Server- und Datenbankkonfiguration, Trace Flags, Startup-Parameter, Betriebssystem, Security, Integrity, Capacity, Performance Counter, Engine-Ereignisse, Contention, Buffer Pool und Worker Pressure. Mehrere Module liefern zusätzlich normalisierte Findings.

### Versionen und Spezialfeatures

Die versionsadaptiven Module untersuchen Featurecapabilities, Build und Lifecycle, Spezialfeatureinventur, In-Memory OLTP, Temporal Tables, Service Broker, Full-Text, Data Capture und Verschlüsselung.

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
