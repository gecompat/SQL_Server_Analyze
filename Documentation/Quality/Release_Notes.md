# Releaseübersicht

## Aktueller Stand

| Merkmal | Stand |
|---|---|
| Frameworkversion | `1.1.0-special.14` |
| Dokumentationsstand | 22. Juli 2026 |
| Mindestversion | SQL Server 2019 |

Der aktuelle Bestand umfasst 164 inventarisierte Objekte:

- 96 öffentliche Procedures;
- acht Views;
- 27 Table-Valued Functions;
- 16 interne Procedures;
- 17 Tabellen.

Alle öffentlichen Procedures besitzen eine eigenständige Procedure-Seite. Alle unterstützenden Objekte besitzen einen Detailabschnitt in der Objektreferenz.


## Abschlusswelle 0/1 – Statusmodell und Current-State-Evidenzbasis

Die fünf kanonischen Abschlussstatus sind in einem gemeinsamen, maschinenlesbaren Modell festgelegt. DIAG-003 bis DIAG-005 werden als `PARTIAL_PRODUCT_FUNCTION`, RUNTIME-001 als `IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING`, der ausgelieferte SC-023-Slice als `IMPLEMENTED_ACTIONS_GATE` und optionale Ausbaupunkte separat als `OPTIONAL_FUTURE` geführt. Das Special-Feature-Routing für Verschlüsselung verweist nun konsistent auf die bereits implementierte `USP_EncryptionAnalysis`.

Der erste Slice der gemeinsamen laufinternen Evidenzbasis ergänzt einen aufruflokalen Snapshot-Owner für Sessions, Requests, Connections, Waiting Tasks, Memory Grants, Resource Governor sowie begrenzte SQL-Text-Evidenz. `USP_CurrentOverview` liest jede aktivierte Primärquelle einmal und reicht denselben Snapshot an `USP_CurrentSessions` und `USP_CurrentRequests` weiter. Einzelaufrufe bleiben frisch und lehnen fremde oder abgelaufene Parent-IDs ab. Input Buffer bleibt bis zur späteren Konsolidierung eine begrenzte Post-Candidate-Quelle von `USP_CurrentRequests`. Das neue Resultset `snapshotStatus` weist Snapshot-ID, Quellzeit, Abschlusszeit, Zeilenzahl, Partialität und isolierte Quellenfehler aus.

Dieser Slice schließt die gemeinsame Current-State-Evidenzbasis noch nicht ab. Blocking, Waits, Transaktionen, Memory Grants, TempDB, I/O und Log verwenden bis zu ihrer gezielten Migration weiterhin ihre bestehenden eigenständigen Lesewege.


## RUNTIME-001 – External Runtime und SQL CLR

Der Frameworkkern enthält zwei getrennte, rein lesende Tiefenanalysen:

- `USP_ExternalRuntimeAnalysis` trennt External-Scripts-Konfiguration, Language- und Libraryregistrierungen, Launchpad-Evidenz, aktive Requests, External Resource Pools, Execution Stats und Performance Counter.
- `USP_ClrAnalysis` trennt SQL-CLR-Konfiguration, sichtbare Assemblies und Module, AppDomains, geladene Assemblies, CLR Tasks, Managed-Code-Requests, Memory Clerks und Performance Counter.

Beide Verfahren isolieren Quelle und Berechtigungsfehler, stellen `LOCK_TIMEOUT` wieder her und unterstützen `CONSOLE`, `RAW`, `TABLE`, `NONE` sowie JSON. Sie führen weder externen Code noch Assemblies aus, aktivieren keine Features und lesen standardmäßig keine Identitäten, Binärinhalte, Script- oder SQL-Texte. Das maschinenlesbare Routing erfolgt über neue Capability-, Analyseklassen-, Navigator- und Spezialfeature-Verträge. Windows-Laufzeitnachweise mit aktivierten Features, konkrete Runtime-Nachweise und synthetische SAFE-Assembly-Nachweise bleiben ausdrücklich außerhalb der Linux-Kernprüfung des portablen Vertrags.

## Dokumentationsstil

Der dokumentierte Bestand wurde gegen die verbindliche Schreibstilrichtlinie geprüft. Die Überarbeitung entfernt wiederholte Standardabsätze, vervollständigt fragmentarische Leseanleitungen und vereinheitlicht die sachliche Darstellung in öffentlichen und maßgeblichen internen Dokumenten sowie in SQL-Dateiköpfen und Hilfeausgaben.

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
- [96 Procedure-Seiten](../Analysis_Guides/Procedures/README.md)
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
