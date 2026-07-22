# Spezialfallmodule – Evidenz, Kosten und Grenzen

## Zweck

Die Spezialfallmodule schließen Diagnosefragen, die weder durch einen einzelnen Live-Snapshot noch durch allgemeine Server- oder Objektübersichten ausreichend beantwortet werden. Sie bleiben lesend, begrenzt und statusorientiert. Kein Modul führt Repair, Rebuild, Plan Forcing, Failover, Statistikupdate, Konfigurationsänderung oder automatische Bereinigung aus.

## Modulübersicht

| Bereich | Procedure | Primäre Evidenz | Sichere Aussagegrenze |
|---|---|---|---|
| Integrität | `USP_DatabaseIntegrityAnalysis` | DBCC-/Katalog- und Wartungsevidenz | kein eigener vollständiger CHECKDB- oder Repairlauf |
| Kapazität | `USP_DatabaseCapacityAnalysis` | Dateien, Volumes, Wachstum und Trendkontext | freier Platz ist kein Forecast ohne Verlauf |
| Performance Counter | `USP_PerformanceCounters` | typisierte Counter mit optionalem Delta | Countertyp und Reset müssen zur Interpretation passen |
| Engine-Ereignisse | `USP_CriticalEngineEvents` | Ringbuffer, System Health und optionale XE-Quellen | nur sichtbare und noch vorhandene Ereignisse |
| IQP | `USP_IntelligentQueryProcessingAnalysis` | Version, Compatibility, Query Store und Plankontext | Capability oder Kandidat ist kein Wirkungsnachweis |
| interne Contention | `USP_InternalContentionAnalysis` | Latch-/Spinlock-Deltas und optionale Hot Pages | kumulative Zähler und kurzes Sample, keine Root Cause allein |
| Buffer Pool | `USP_BufferPoolAnalysis` | Memory Clerks und optional Buffer-Descriptor-Verteilung | breite Datenbankverteilung bleibt opt-in |
| Findings | `USP_DiagnosticFindings` | normalisierte Child-Evidenz | priorisierte Triage, kein autonomes Urteil |
| Backupkette | `USP_BackupChainAnalysis` | msdb-LSN- und Restorehistorie | Historie beweist keinen erfolgreichen externen Restore |
| Schemadesign | `USP_SchemaDesignAnalysis` | Constraints, FKs, Indizes und Identity | Designhinweis benötigt Workload- und Änderungsrisiko |
| Statistikverteilung | `USP_StatisticsDistributionAnalysis` | Histogramme und Eigenschaften | Werte können sensibel sein; Histogramm ist keine Vollverteilung |
| Availability | `USP_AvailabilityDeepAnalysis` | Replica-, Queue-, Lag- und Seedingstatus | asynchroner Zustand muss gegen SLA gelesen werden |
| Agentbetrieb | `USP_AgentMonitoringAnalysis` | Jobs, Alerts, Operatoren und Database Mail | Plattform- und Konfigurationsscope begrenzen Sicht |
| Worker | `USP_WorkerPressureAnalysis` | Scheduler-, Worker- und Requestdelta | THREADPOOL und CPU-Runnable sind getrennte Hypothesen |
| Datenbankkonfiguration | `USP_DatabaseConfigurationAnalysis` | Datenbankoptionen und explizite Profile | lokale Mehrheit ist kein Sollwert |
| Fehlerprotokolle | `USP_ErrorLogAnalysis` | begrenzte SQL-/Agent-Errorlogmuster | Keyword- und Zeitfilter sind kein Volltextbeweis |
| Wartungsoperationen | `USP_MaintenanceOperations` | laufende/resumable Operationen und Zustände | sichtbarer Zustand ist flüchtig |
| Serverversion | `USP_ServerVersionInformation` | Offline-Build- und Lifecyclekatalog | neuer Build kann jünger als der lokale Katalog sein |
| Featureinventur | `USP_SpecialFeatureInventory` | leichtgewichtige Katalogerkennung | erkannte Nutzung ist kein Healthurteil |
| In-Memory OLTP | `USP_InMemoryOltpAnalysis` | XTP-Objekte, Hashindizes, Checkpoints und Pools | Hashketten und breite Laufzeitsichten bleiben opt-in |
| Temporal | `USP_TemporalAnalysis` | Current-/History-Beziehungen, Retention und Größe | keine zeilenweise Konsistenzprüfung |
| Service Broker | `USP_ServiceBrokerAnalysis` | Queues, Activation, Transmission und Conversations | keine Nachrichteninhalte |
| Full-Text | `USP_FullTextAnalysis` | Kataloge, Populationen, Batches und Fragmente | keine indizierten Dokumentinhalte |
| Data Capture | `USP_DataCaptureDeepAnalysis` | Change Tracking, CDC und lokale Replikation | CT-Verlust benötigt Consumer-Wasserstand |
| Verschlüsselung | `USP_EncryptionAnalysis` | TDE-, Backup-, AE- und Ledger-Metadaten | keine Schlüssel, Secrets oder Restoreprüfung |

## Geplantes nächstes SubProject

[RUNTIME-001 – External Runtime und SQL CLR Analysis](External_Runtime_CLR_Analysis_Plan.md) ist das nächste geplante SubProject. Es entwirft zwei getrennte öffentliche Verfahren: `USP_ExternalRuntimeAnalysis` für R, Python, Java, C# und Custom Language Extensions sowie `USP_ClrAnalysis` für SQL CLR.

Der Plan umfasst Evidenz- und Quellenmodell, Resultsets, Parameter, Capability- und Berechtigungspfade, Performance- und Lockingschutz, Datenschutz, Snapshot-Grenze, Frameworkintegration, Umsetzungsphasen und Abnahmematrix. Es ist noch keine Laufzeitimplementierung vorhanden. `USP_SpecialFeatureInventory` darf deshalb bis zum Abschluss weiterhin `NOT_PLANNED` für `CLR`, `EXTERNAL_RUNTIME` und `EXTERNAL_SCRIPTS` melden.

## Gemeinsamer Laufzeitvertrag

Spezialmodule verwenden dieselben Grundprinzipien:

- `CONSOLE` für einen lesbaren ersten Überblick;
- `RAW` für Status und vollständige technische Resultsets;
- `TABLE` für explizit benannte lokale Temp-Tabellen;
- JSON aus derselben Aufrufmaterialisierung;
- endliche Standardlimits;
- `LOCK_TIMEOUT 0` und isolierte Fehlerbehandlung;
- Status für nicht verfügbare Version, Plattform, Berechtigung oder Quelle;
- High-Impact-Bestätigung nur für tatsächlich aktivierte teure Pfade;
- keine automatische Änderung aus einem Finding.

## Kostenmodell

| Kostenband | Typische Quellen | Betriebsregel |
|---|---|---|
| `LOW` | konstante Kataloge, kleine Konfiguration, begrenzte Statusviews | sicherer Einstieg, dennoch Ergebnisbreite beachten |
| `LOW_MEDIUM` | Live-DMVs, kurze Samples, begrenzte msdb-/Katalogsichten | mit Defaults und kleinen Zeilenlimits beginnen |
| `MEDIUM` | mehrere Datenbanken, JSON-Konsolidierung, Event-/Loglesung | Scope und Zeitfenster explizit wählen |
| `LOW_HIGH_OPT_IN` / `MEDIUM_HIGH_OPT_IN` | leichter Basisweg plus optional breiter Katalog-, XML-, Histogramm- oder Descriptorpfad | nur benötigten Detailpfad aktivieren |
| `HIGH_OPT_IN` | physische oder breite Deep-Quelle | bekanntes Ziel, enge Limits, Gruppen- und High-Impact-Vertrag prüfen |

Die Kostenklasse beschreibt Frameworkarbeit, nicht die Dringlichkeit des Befunds.

## Findings richtig lesen

Ein normalisiertes Finding verbindet:

- stabilen Code und Kategorie;
- Severity;
- Confidence;
- SourceModule und SourceResult;
- konkrete Evidenz;
- Evidenzgrenze;
- nächste Prüfung.

`CRITICAL` ist keine automatische Handlungsfreigabe. `HIGH` Confidence kann sich auf die technische Beobachtung beziehen, während Ursache, Geschäftsauswirkung oder Änderungsrisiko weiterhin unklar sind. Eine unabhängige zweite Quelle bleibt erforderlich.

## Leere und partielle Ergebnisse

Eine leere Spezialanalyse kann bedeuten:

- Feature nicht verwendet oder nicht sichtbar;
- Filter oder Datenbankscope zu eng;
- Ereignis außerhalb Retention oder Zeitfenster;
- Query Store oder XE nicht aktiviert;
- Berechtigung unzureichend;
- Plattformquelle nicht verfügbar;
- Zeilenlimit oder Problemfilter entfernt unauffällige Zeilen;
- Zustand war beim Snapshot bereits beendet.

Darum zuerst Modulstatus, `IsPartial`, Berechtigung, SourceStatus, Zeitbezug, Reset und Limits lesen.

## Auswahl über den Analysis Navigator

```sql
EXEC [monitor].[USP_AnalysisNavigator]
      @Suchbegriff = N'welche Spezialfeatures werden verwendet';
```

`USP_SpecialFeatureInventory` ist der sichere Einstieg, wenn das vorhandene Feature unbekannt ist. Anschließend nur die erkannten und fachlich relevanten Tiefenmodule verwenden. Der Navigator zeigt Scope, Kostenband, Targetanforderung und High-Impact-Verfügbarkeit, führt aber kein Modul aus.

## Datenschutz

Errorlogs, XE-Ereignisse, Pläne, Histogramme, SQL-Text, Namen und Infrastrukturattribute können schutzbedürftige Laufzeitinformationen enthalten. Optionale Detail-, Payload- und Textpfade nur mit fachlichem Bedarf aktivieren. Siehe [Datenschutz und Laufzeitausgaben](Runtime_Data_Privacy.md).

## Weiterführende Dokumentation

- [Hier beginnen](../Analysis_Guides/Start_Here.md)
- [Analysis Navigator](../Reference/Analysis_Navigator.md)
- [Server-Health-Familie](../Analysis_Guides/08_Server_Health.md)
- [Infrastruktur-Familie](../Analysis_Guides/07_Infrastructure.md)
- [Versionsadaptive Spezialanalysen](../Analysis_Guides/09_Version_Adaptive.md)
- [Procedure-Seiten](../Analysis_Guides/Procedures/README.md)
