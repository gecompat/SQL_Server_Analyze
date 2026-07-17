# Objektindex der umfassenden Analysebeschreibungen

**Stand:** 17. Juli 2026  
**Abdeckung:** alle 79 öffentlichen Procedures des Frameworks  
**Ziel:** direkter Einstieg pro Objekt statt Navigation über ein reines Konzeptdokument

## Für Analyseanfänger: zuerst die Leserichtung verstehen

Der [Einsteigerleitfaden zum Lesen der Resultsets](Beginner_Reading_Guide.md) erklärt für **jedes der 79 Objekte** zusätzlich:

- welche Spalten zuerst gelesen werden,
- welche Werte nur gemeinsam sinnvoll sind,
- warum eine Kombination technisch problematisch sein kann,
- warum dieselben Einzelwerte in einem anderen Kontext normal sein können,
- wie aus dem Resultset eine überprüfbare Ursachehypothese entsteht,
- welche Folgeanalyse die Vermutung bestätigt oder widerlegt.

Die nachstehenden Links führen zur technischen Detailbeschreibung. Für Anfänger empfiehlt sich diese Reihenfolge:

1. Procedure im [Einsteigerleitfaden](Beginner_Reading_Guide.md) lesen.
2. Danach über diesen Index in die Resultset- und Spaltendetails wechseln.
3. Status, Zeitbezug, Nenner und Aussagegrenze vor einer Bewertung prüfen.

## Was hinter jedem Link beschrieben wird

Jeder verlinkte Objektabschnitt ist die eigentliche fachliche Dokumentation und behandelt – soweit für das jeweilige Objekt anwendbar – mindestens:

- Zweck und konkrete Einsatzfragen,
- geeignete und ungeeignete Einsatzsituationen,
- praxisnahe Aufrufvarianten,
- Anzahl, Reihenfolge und Bedeutung der Resultsets,
- Spalten beziehungsweise zusammengehörige Spaltengruppen,
- Interpretation normaler, auffälliger, kritischer und irreführender Werte,
- plakative sowie grenzwertige synthetische Beispiele,
- sinnvolle Folgeanalysen innerhalb des Frameworks,
- Eigenlast, Locking-, Blocking-, I/O- und CPU-Auswirkungen der Analyse,
- Aussagegrenzen durch Momentaufnahme, Reset, Retention, Berechtigungen, Featurestatus oder Sampling,
- weiterführende Microsoft- und Fachquellen.

> `Deep_Research_Analysis_Guides_Concept.md` ist nur das Forschungs- und Strukturkonzept. Für die praktische Nutzung beginnen Sie im [Einsteigerleitfaden](Beginner_Reading_Guide.md), in diesem Objektindex oder im [Analysehandbuch](README.md).

## Common

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_CheckAnalyseAccess]` | [Zugriffspolicy, Resultsets, Grenzfälle und Folgeprüfung](01_Common.md#1-monitorusp_checkanalyseaccess) |
| `[monitor].[USP_CheckFrameworkCapabilities]` | [Version, Berechtigungen, Featurestatus und technische Nutzbarkeit](01_Common.md#2-monitorusp_checkframeworkcapabilities) |
| `[monitor].[USP_PrepareDatabaseCandidates]` | [Interner Datenbank-Auswahlvertrag, Temp-Tabellen und Fehlersemantik](01_Common.md#3-monitorusp_preparedatabasecandidates) |
| `[monitor].[USP_PrepareNameFilters]` | [Interner Namensfiltervertrag, Case-Sensitivity und Grenzfälle](01_Common.md#4-monitorusp_preparenamefilters) |

## Current State

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_CurrentSessions]` | [Sessions, Identität, Verbindung, Transaktionen und kumulative Last](02_Current_State.md#1-monitorusp_currentsessions) |
| `[monitor].[USP_CurrentRequests]` | [Aktive Requests, CPU, I/O, Blocking, Waits, Grants und SQL-Kontext](02_Current_State.md#2-monitorusp_currentrequests) |
| `[monitor].[USP_CurrentBlocking]` | [Blockingketten, Root Blocker, Lockdetails und Eingriffsgrenzen](02_Current_State.md#3-monitorusp_currentblocking) |
| `[monitor].[USP_CurrentWaits]` | [Live-Waits, Stichproben, Waitgruppen und Fehlinterpretationen](02_Current_State.md#4-monitorusp_currentwaits) |
| `[monitor].[USP_CurrentTransactions]` | [Offene Transaktionen, Alter, Sleeping Sessions und Logfolgen](02_Current_State.md#5-monitorusp_currenttransactions) |
| `[monitor].[USP_CurrentMemoryGrants]` | [Grant-Anforderung, Gewährung, Nutzung, Warteschlangen und Semaphoren](02_Current_State.md#6-monitorusp_currentmemorygrants) |
| `[monitor].[USP_CurrentTempDB]` | [Sessionverbrauch, Dateien, Version Store und TempDB-Kontext](02_Current_State.md#7-monitorusp_currenttempdb) |
| `[monitor].[USP_CurrentIO]` | [Kumulative und gesampelte Datei-I/O-Latenz sowie Aussagegrenzen](02_Current_State.md#8-monitorusp_currentio) |
| `[monitor].[USP_CurrentLog]` | [Logauslastung, Wiederverwendungswartegrund, VLF und PVS](02_Current_State.md#9-monitorusp_currentlog) |
| `[monitor].[USP_CurrentOverview]` | [Orchestrierter Live-Überblick, Childresultsets und Anfängerworkflow](02_Current_State.md#10-monitorusp_currentoverview) |

## Object und Index

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_ObjectInventory]` | [Objekt-, Index-, Größen-, Kompressions- und Definitionsinventar](03_Object_Index.md#1-monitorusp_objectinventory) |
| `[monitor].[USP_IndexUsage]` | [Nutzungszähler, Resetgrenzen, XTP und Löschungsfehlschlüsse](03_Object_Index.md#2-monitorusp_indexusage) |
| `[monitor].[USP_IndexOperationalStats]` | [DML, Page Allocations, Locks, Latches, Forwarded Fetches und Splits](03_Object_Index.md#3-monitorusp_indexoperationalstats) |
| `[monitor].[USP_MissingIndexes]` | [Optimizer-Evidenz, Improvement Measure, Entwurfs-DDL und Grenzen](03_Object_Index.md#4-monitorusp_missingindexes) |
| `[monitor].[USP_Statistics]` | [Statistikzustand, Sample, Modification Counter und inkrementelle Details](03_Object_Index.md#5-monitorusp_statistics) |
| `[monitor].[USP_StatisticsDistributionAnalysis]` | [Histogramm, Skew, Tail, Partitionvariation und Findings](03_Object_Index.md#6-monitorusp_statisticsdistributionanalysis) |
| `[monitor].[USP_Partitions]` | [Partitionsgrenzen, RowCounts, Filegroups und Kompressionsstrategie](03_Object_Index.md#7-monitorusp_partitions) |
| `[monitor].[USP_Columnstore]` | [Rowgroups, Deleted Rows, Segmente, Dictionaries und Tuple-Mover-Kontext](03_Object_Index.md#8-monitorusp_columnstore) |
| `[monitor].[USP_IndexPhysicalStats]` | [Fragmentierung, Seitendichte, Page Count, Ghosts und Scanmodi](03_Object_Index.md#9-monitorusp_indexphysicalstats) |
| `[monitor].[USP_SchemaDesignAnalysis]` | [Constraints, Foreign Keys, Duplikatindizes, Identity und Designfindings](03_Object_Index.md#10-monitorusp_schemadesignanalysis) |
| `[monitor].[USP_ObjectAnalysis]` | [Orchestrierung sämtlicher Objekt- und Indextiefenanalysen](03_Object_Index.md#11-monitorusp_objectanalysis) |

## Plan Cache und Showplan

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_QueryStats]` | [Cachebasierte CPU-, Laufzeit-, I/O-, Grant-, Spill- und Ausführungsanalyse](04_Plan_Cache.md#1-monitorusp_querystats) |
| `[monitor].[USP_QueryHashAnalysis]` | [Query-Hash-Aggregation, Planvarianten, Handles und Cachefenster](04_Plan_Cache.md#2-monitorusp_queryhashanalysis) |
| `[monitor].[USP_PlanCacheHealth]` | [Cachegröße, Single-Use-Anteil, Ad-hoc-Bloat und Memory-Kontext](04_Plan_Cache.md#3-monitorusp_plancachehealth) |
| `[monitor].[USP_PlanDetails]` | [Planattribute, Compile-, Last-Actual- und Live-Planquellen](04_Plan_Cache.md#4-monitorusp_plandetails) |
| `[monitor].[USP_ShowplanAnalysis]` | [Statements, Operatoren, Warnungen, Kardinalität, Memory und Parameter](04_Plan_Cache.md#5-monitorusp_showplananalysis) |
| `[monitor].[USP_PlanCacheAnalysis]` | [Orchestrierung, Childreihenfolge, Tiefenbudgets und Grenzen](04_Plan_Cache.md#6-monitorusp_plancacheanalysis) |

## Query Store

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_QueryStoreStatus]` | [Zustand, Read-only-Gründe, Capture, Retention und Speicher](05_Query_Store.md#1-monitorusp_querystorestatus) |
| `[monitor].[USP_QueryStoreRuntimeStats]` | [Historische CPU-, Dauer-, I/O-, Memory-, TempDB- und Logmetriken](05_Query_Store.md#2-monitorusp_querystoreruntimestats) |
| `[monitor].[USP_QueryStoreWaitStats]` | [Historische Waitkategorien, Intervalle und Aggregationsgrenzen](05_Query_Store.md#3-monitorusp_querystorewaitstats) |
| `[monitor].[USP_QueryStorePlanChanges]` | [Planwechsel, Compileumgebung, Planvielfalt und Relevanzprüfung](05_Query_Store.md#4-monitorusp_querystoreplanchanges) |
| `[monitor].[USP_QueryStoreRegressions]` | [Baseline-/Vergleichsfenster, Metriken, Stichprobe und Regression](05_Query_Store.md#5-monitorusp_querystoreregressions) |
| `[monitor].[USP_QueryStoreForcedPlans]` | [Forced Plans, Fehlergründe, Lebenszyklus und Änderungsrisiko](05_Query_Store.md#6-monitorusp_querystoreforcedplans) |
| `[monitor].[USP_QueryStoreHints]` | [Query Store Hints, Fehler, Herkunft und betriebliche Governance](05_Query_Store.md#7-monitorusp_querystorehints) |
| `[monitor].[USP_IntelligentQueryProcessingAnalysis]` | [IQP-Eignung, Konfiguration, Feedbacksignale und Aussagegrenzen](05_Query_Store.md#8-monitorusp_intelligentqueryprocessinganalysis) |
| `[monitor].[USP_QueryStoreAnalysis]` | [Orchestrierung aller Query-Store-Module und Kosten](05_Query_Store.md#9-monitorusp_querystoreanalysis) |

## Extended Events

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_ExtendedEventsSessions]` | [Sessioninventar, Events, Actions, Targets, Felder und Laufzeitstatus](06_Extended_Events.md#1-monitorusp_extendedeventssessions) |
| `[monitor].[USP_ExtendedEventsReadEvents]` | [Eventdatei-/Ringbuffer-Lesen, Zeitfilter, XML und Retention](06_Extended_Events.md#2-monitorusp_extendedeventsreadevents) |
| `[monitor].[USP_ExtendedEventsDeadlocks]` | [Deadlockgraph, Prozesse, Ressourcen, Opfer und Interpretationsgrenzen](06_Extended_Events.md#3-monitorusp_extendedeventsdeadlocks) |
| `[monitor].[USP_ExtendedEventsBlockedProcesses]` | [Blocked-Process-Reports, Schwellen, XML und historische Blockinganalyse](06_Extended_Events.md#4-monitorusp_extendedeventsblockedprocesses) |
| `[monitor].[USP_ExtendedEventsTargetRuntime]` | [Targetzustand, Dateipfade, Ringbuffer, Flush und Targetdaten](06_Extended_Events.md#5-monitorusp_extendedeventstargetruntime) |
| `[monitor].[USP_ExtendedEventsAnalysis]` | [Orchestrierung von Inventar, Runtime, Events, Deadlocks und Blocking](06_Extended_Events.md#6-monitorusp_extendedeventsanalysis) |

## Infrastruktur

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_AgentStatus]` | [SQL-Agent-Dienstzustand, Konfiguration und Plattformgrenzen](07_Infrastructure.md#1-monitorusp_agentstatus) |
| `[monitor].[USP_AgentJobs]` | [Jobs, Schritte, Historie, Laufzeit, Fehler und Long-Running-Bewertung](07_Infrastructure.md#2-monitorusp_agentjobs) |
| `[monitor].[USP_ResourceGovernorAnalysis]` | [Pools, Workload Groups, Sessions, Limits und Drosselung](07_Infrastructure.md#3-monitorusp_resourcegovernoranalysis) |
| `[monitor].[USP_AvailabilityGroups]` | [AG-Konfiguration, Replica- und Datenbankstatus sowie Routing](07_Infrastructure.md#4-monitorusp_availabilitygroups) |
| `[monitor].[USP_BackupRecovery]` | [Backupalter, Recovery Model, Logkette und Restorehistorie](07_Infrastructure.md#5-monitorusp_backuprecovery) |
| `[monitor].[USP_LogShippingStatus]` | [Primär-/Sekundärstatus, Kopier-/Restoreverzug und Metadatenlücken](07_Infrastructure.md#6-monitorusp_logshippingstatus) |
| `[monitor].[USP_ReplicationStatus]` | [Publikationen, Subscriptions, Agents, Latenz und Detailgrenzen](07_Infrastructure.md#7-monitorusp_replicationstatus) |
| `[monitor].[USP_DataCaptureStatus]` | [CDC, Change Tracking und weitere Erfassungszustände](07_Infrastructure.md#8-monitorusp_datacapturestatus) |
| `[monitor].[USP_InfrastructureAnalysis]` | [Orchestrierter Infrastrukturüberblick und Childmodule](07_Infrastructure.md#9-monitorusp_infrastructureanalysis) |
| `[monitor].[USP_BackupChainAnalysis]` | [Backupketten, LSN-Zusammenhang, Restoreevidenz und Findings](07_Infrastructure.md#10-monitorusp_backupchainanalysis) |
| `[monitor].[USP_AvailabilityDeepAnalysis]` | [Queues, Lag, Synchronisierung, Cluster und vertiefte AG-Evidenz](07_Infrastructure.md#11-monitorusp_availabilitydeepanalysis) |
| `[monitor].[USP_AgentMonitoringAnalysis]` | [Agent-, Job-, Alert-, Operator- und Database-Mail-Evidenz](07_Infrastructure.md#12-monitorusp_agentmonitoringanalysis) |

## Server Health

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_ServerCpuTopology]` | [CPU-, Scheduler-, Socket-, Core- und Lizenzierungskontext](08_Server_Health.md#1-monitorusp_servercputopology) |
| `[monitor].[USP_ServerNuma]` | [NUMA-Nodes, Schedulerverteilung, Memory Nodes und Soft-NUMA](08_Server_Health.md#2-monitorusp_servernuma) |
| `[monitor].[USP_ServerMemory]` | [OS-/SQL-Memory, Clerks, Prozessdruck und Ziel-/Gesamtspeicher](08_Server_Health.md#3-monitorusp_servermemory) |
| `[monitor].[USP_TempDBConfiguration]` | [Dateien, Größen, Wachstum, Gleichheit, Version Store und Konfiguration](08_Server_Health.md#4-monitorusp_tempdbconfiguration) |
| `[monitor].[USP_ServerConfiguration]` | [Kernkonfiguration, konfigurierte/aktive Werte und Reviewregeln](08_Server_Health.md#5-monitorusp_serverconfiguration) |
| `[monitor].[USP_TraceFlags]` | [Aktive Trace Flags, Scope und versionsabhängige Bewertung](08_Server_Health.md#6-monitorusp_traceflags) |
| `[monitor].[USP_StartupParameters]` | [Startparameter, Pfade, Flags und Dienstkontext](08_Server_Health.md#7-monitorusp_startupparameters) |
| `[monitor].[USP_OSInformation]` | [Betriebssystem, Virtualisierung, Speicher, Zeit und Plattform](08_Server_Health.md#8-monitorusp_osinformation) |
| `[monitor].[USP_ServerSecurityConfiguration]` | [Sicherheitsrelevante Konfiguration und explizite Aussagegrenzen](08_Server_Health.md#9-monitorusp_serversecurityconfiguration) |
| `[monitor].[USP_ServerHealthAnalysis]` | [Orchestrierung der Server-Health- und Spezialfallmodule](08_Server_Health.md#10-monitorusp_serverhealthanalysis) |
| `[monitor].[USP_DatabaseIntegrityAnalysis]` | [CHECKDB-Evidenz, suspect pages, Backupchecksums und HADR-Reparatur](08_Server_Health.md#11-monitorusp_databaseintegrityanalysis) |
| `[monitor].[USP_DatabaseCapacityAnalysis]` | [Dateien, Volumes, Wachstum, Autogrowth und Kapazitätsrisiko](08_Server_Health.md#12-monitorusp_databasecapacityanalysis) |
| `[monitor].[USP_PerformanceCounters]` | [Typisierte Performance Counter, Samples, Delta und Normalisierung](08_Server_Health.md#13-monitorusp_performancecounters) |
| `[monitor].[USP_CriticalEngineEvents]` | [Schwere Engine-Ereignisse aus system_health und Diagnostics](08_Server_Health.md#14-monitorusp_criticalengineevents) |
| `[monitor].[USP_InternalContentionAnalysis]` | [Spinlocks, Hot Pages, Latches, Stichprobe und Page Details](08_Server_Health.md#15-monitorusp_internalcontentionanalysis) |
| `[monitor].[USP_BufferPoolAnalysis]` | [Buffer Pool, Memory Clerks, Datenbankverteilung und Pressure](08_Server_Health.md#16-monitorusp_bufferpoolanalysis) |
| `[monitor].[USP_DiagnosticFindings]` | [Normalisierte Findings, Severity, Confidence und Modulstatus](08_Server_Health.md#17-monitorusp_diagnosticfindings) |

## Versionsadaptive Spezialanalysen

| Objekt | Umfassende Beschreibung |
|---|---|
| `[monitor].[USP_ServerFeatureCapabilities]` | [Versions-, Plattform- und datenbankbezogene Featurefähigkeiten](09_Version_Adaptive.md#1-monitorusp_serverfeaturecapabilities) |
| `[monitor].[USP_SpecialFeatureInventory]` | [Leichtgewichtige Inventur erkannter Spezialfeatures](09_Version_Adaptive.md#2-monitorusp_specialfeatureinventory) |
| `[monitor].[USP_InMemoryOltpAnalysis]` | [XTP-Tabellen, Hashindizes, Checkpoints, Transaktionen und Pools](09_Version_Adaptive.md#3-monitorusp_inmemoryoltpanalysis) |
| `[monitor].[USP_TemporalAnalysis]` | [Temporal Tables, Historie, Retention, Indizes und Kapazität](09_Version_Adaptive.md#4-monitorusp_temporalanalysis) |

## Vollständigkeitsprüfung

| Bereich | Anzahl |
|---|---:|
| Common | 4 |
| Current State | 10 |
| Object und Index | 11 |
| Plan Cache und Showplan | 6 |
| Query Store | 9 |
| Extended Events | 6 |
| Infrastruktur | 12 |
| Server Health | 17 |
| Versionsadaptive Spezialanalysen | 4 |
| **Gesamt** | **79** |

## Weitere Einstiege

- [Einsteigerleitfaden: Wie jedes Resultset gelesen wird](Beginner_Reading_Guide.md)
- [Analysehandbuch und Symptomnavigation](README.md)
- [Gemeinsame Resultset-, Status-, Filter-, Kosten- und Evidenzverträge](Common_Contracts.md)
- [Technische Procedure-Signaturen](../Reference/Procedure_Reference.md)
- [Aufrufkatalog](../Reference/Call_Catalog.md)
- [Forschungs- und Strukturkonzept](Deep_Research_Analysis_Guides_Concept.md)
