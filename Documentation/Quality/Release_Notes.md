# Releaseübersicht

## Aktueller Stand

| Merkmal | Stand |
|---|---|
| Frameworkversion | `1.1.0-special.15` |
| Dokumentationsstand | 23. Juli 2026 |
| Mindestversion | SQL Server 2019 |

Der aktuelle Bestand umfasst 164 inventarisierte Objekte:

- 96 öffentliche Procedures;
- acht Views;
- 27 Table-Valued Functions;
- 16 interne Procedures;
- 17 Tabellen.

Alle öffentlichen Procedures besitzen eine eigenständige Procedure-Seite. Alle unterstützenden Objekte besitzen einen Detailabschnitt in der Objektreferenz.


## Abschlusswelle 0/1 – Statusmodell und Current-State-Evidenzbasis

Die fünf kanonischen Abschlussstatus sind in einem gemeinsamen,
maschinenlesbaren Modell festgelegt. Das Special-Feature-Routing für
Verschlüsselung verweist konsistent auf die bereits implementierte
`USP_EncryptionAnalysis`. DIAG-003 bis DIAG-005 sind inzwischen
`IMPLEMENTED_ACTIONS_GATE`.

Der erste Slice der gemeinsamen laufinternen Evidenzbasis ergänzt einen aufruflokalen Snapshot-Owner für Sessions, Requests, Connections, Waiting Tasks, Memory Grants, Resource Governor sowie begrenzte SQL-Text-Evidenz. `USP_CurrentOverview` liest jede aktivierte Primärquelle einmal und reicht denselben Snapshot an `USP_CurrentSessions` und `USP_CurrentRequests` weiter. Einzelaufrufe bleiben frisch und lehnen fremde oder abgelaufene Parent-IDs ab. Input Buffer bleibt bis zur späteren Konsolidierung eine begrenzte Post-Candidate-Quelle von `USP_CurrentRequests`. Das neue Resultset `snapshotStatus` weist Snapshot-ID, Quellzeit, Abschlusszeit, Zeilenzahl, Partialität und isolierte Quellenfehler aus.

## Welle 2 – DIAG-003 Parameter-Evidenz

`USP_ExecutionPlanAnalysis` liefert zusätzlich zum unveränderten
`parametersAndVariants` das kanonische Resultset `parameters`.
Attributpräsenz, erfasstes SQL-`NULL`, fehlende Evidenz, Cache-Eviction,
beendete Requests und nicht allgemein zugängliche lokale Variablen bleiben
unterscheidbar. Quelle, Quellzeit, Session-/Request-/Statement-/Query- und
Planbezug sowie Current-/Last-known- und Vollständigkeitskennzeichen sind in
RAW, JSON und benanntem TABLE enthalten.

`USP_ShowplanAnalysis` aggregiert denselben Vertrag mit äußerer Candidate-ID
und Planhandle. Parameter-XML wird weiterhin nur in der zentralen Child-Engine
zerlegt. Der Runtimevertrag `120` schützt den eigenständig installierbaren
Einplanpfad; Vertrag `121` schützt die Frameworkaggregation im
SQL-Server-2019-/2022-/2025-Release-Gate.

## Welle 3 – DIAG-004 Statement- und Requestkontext

`USP_CurrentRequests` ergänzt das kompatible Resultset `requests` um die
kanonischen Resultsets `requestContext`, `snapshotStatus`, `statements`,
`batches`, `inputBuffers` und `warnings`. Source-, Capture-, Trunkierungs- und
Auslassungsstatus trennen nicht angeforderte, verschlüsselte, ungültig
adressierte, nicht mehr verfügbare und gekürzte Texte. Connection-, Wait-,
Task-, Scheduler-, Transaktions-, Memory-Grant-, TempDB-,
Resource-Governor- und Query-Identität stehen pro Request in
`requestContext`.

Der laufinterne Snapshot-Owner verwendet Vertragsversion 2. Sessions,
Requests, Blocking, Waits, Transactions, Memory Grants, TempDB und I/O
konsumieren im Overview dieselbe Snapshot-ID und lesen überlappende
Primärquellen nicht erneut. Quellzeitpunkte bleiben einzeln ausgewiesen und
werden nicht als transaktional atomar dargestellt. Input Buffer bleibt eine
begrenzte Post-Candidate-Quelle; Locks, Instanz-Wait-Stats, Datei-I/O und
weitere nicht überlappende Childquellen behalten ihre eigenen Messpunkte.

Der öffentliche Vertrag steht in
`Metadata/Quality/CurrentRequestContext_Public_Contract.json`. Die
Runtimeverträge `122` und `199` schützen kanonische JSON-/TABLE-Ausgabe,
Statussemantik, Parent-Grenzen sowie die gemeinsame Snapshot-ID auf SQL Server
2019, 2022 und 2025. DIAG-004 steht damit auf
`IMPLEMENTED_ACTIONS_GATE`.

## Welle 4 – DIAG-005 Plan-, Query-Store- und Optimizerkontext

`USP_ExecutionPlanAnalysis` liefert die fünf kanonischen Resultsets
`planWarnings`, `optimizerContext`, `runtimeFeedback`, `queryStoreContext`
und `feedbackAndVariants` in RAW, JSON und benanntem TABLE. Explizite
Planwarnungen, Optimizer-/Cacheattribute, Runtimeabweichungen sowie PSP-,
Adaptive-Join-, Batch-Mode- und Memory-Grant-Feedback-Merkmale werden aus
dem einmal materialisierten Plan abgeleitet.

Bei einer ausdrücklich angeforderten Query-Store-Planquelle werden
Plan-/Querymetadaten und Runtimeaggregate gezielt erfasst. Feedback, Hints und
Varianten verwenden auf SQL Server 2022 und neuer versionsadaptives Dynamic
SQL. Querytexte werden nicht gelesen. Potenziell sensitive Feedback- und
Hintpayloads sind standardmäßig ausgelassen, im TOKENIZED-Modus gehasht und
nur im bestätigten RAW-Modus sichtbar.

`USP_ShowplanAnalysis` aggregiert die fünf Resultsets kandidatengenau und
reicht den bereits während der Kandidatenauswahl materialisierten
Cachekontext an die Einplanengine weiter. Current-/Last-known-Semantik,
Messung gegenüber Ableitung, Quellstatus und False-Positive-Grenzen bleiben
in jeder Zeile erhalten. DIAG-005 steht damit auf
`IMPLEMENTED_ACTIONS_GATE`.

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
