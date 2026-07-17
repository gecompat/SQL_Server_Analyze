# Versionsadaptive und spezialisierte Analysepfade

**Procedures:** 6
**Evidenz:** Version, Plattform, sichtbare Kataloge, Spezialfeature-Metadaten und isolierte Runtime-DMVs  
**Kosten:** LOW bis HIGH_OPT_IN

## Grundregeln

- SQL-Server-Hauptversion allein beweist nicht, dass ein Feature auf Edition, Plattform, Build, CU, Compatibility Level oder in einer konkreten Datenbank verfügbar ist.
- Katalogobjekterkennung ist belastbarer als hart codierte Versionsannahmen, bleibt aber berechtigungsabhängig.
- `NOT_DETECTED_VISIBLE_SCOPE` bedeutet nur „im sichtbaren Metadatenscope nicht gefunden“.
- Feature-Inventar ist kein Healthcheck.
- In-Memory-, Temporal-, Service-Broker- und Full-Text-Findings verwenden konfigurierbare Repository-Heuristiken und führen keine DDL aus.

---

## 1. [monitor].[USP_ServerFeatureCapabilities]

### Zweck

Ermittelt versions- und plattformabhängige Diagnosefähigkeiten auf Server- und Datenbankebene. Zusätzlich können Spezialindizes und Query-Store-Replica-Funktionen inventarisiert werden.

### Auswahlhinweis

Der Kopfkommentar bezeichnet `N''` als ungültig, die Hilfezeile als aktuelle Datenbank. Da der zentrale Kandidatenvertrag `N''` normalerweise als aktuelle Datenbank behandelt, muss bei produktiver Automatisierung der tatsächliche Status geprüft oder eine explizite Datenbankliste verwendet werden.

### Aufrufe

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'RAW';
```

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames = NULL,
      @MitSpezialindizes = 1,
      @MitQueryStoreReplicas = 1,
      @MitPlattformdetails = 1,
      @ResultSetArt = 'RAW';
```

### Capabilities

| Spalte | Bedeutung |
|---|---|
| `ScopeName` | `SERVER` oder anderer Scope |
| `FeatureName` | stabiler Featurecode |
| `AvailabilityStatus` | `AVAILABLE`, `UNAVAILABLE_VERSION`, `UNAVAILABLE_PLATFORM` oder weitere Statuswerte |
| `LogicPath` | verwendete oder empfohlene Erkennungs-/Fallbacklogik |
| `MinimumKnownMajorVersion` | bekannte Mindesthauptversion |
| `SourceObject` | Katalog-/Metadatenquelle |
| `Detail` | fachliche Einordnung |
| `RequiredPermission` | benötigte Berechtigung |

### DatabaseFeatures

`DatabaseName`, `CompatibilityLevel`, `StateDesc`, `FeatureName`, `AvailabilityStatus`, `FeatureValue`, `LogicPath`, `Detail`.

Beispielhafte Features:

- `OPTIMIZED_LOCKING`
- `QUERY_STORE_READABLE_SECONDARY`
- weitere im Build erkannte datenbankbezogene Fähigkeiten.

### SpecialIndexes

`DatabaseName`, `SchemaName`, `ObjectName`, `IndexName`, `IndexFamily`, `IndexDetails`, `AvailabilityStatus`.

Die genaue Familie ist versionsabhängig. Das Resultset ist ein Inventar, kein Performanceurteil.

### Errors

`DatabaseName`, `ModuleName`, `ErrorNumber`, `ErrorMessage`.

### Serverfeatures im aktuellen Code

| Feature | Interpretation |
|---|---|
| `PERFORMANCE_STATE_PERMISSION` | ab SQL Server 2022 wird für viele Performance-DMVs `VIEW SERVER PERFORMANCE STATE` ausgewiesen, davor `VIEW SERVER STATE` |
| `ZSTD_BACKUP_COMPRESSION` | SQL Server 2025 unterstützt ZSTD als Backupkompressionsalgorithmus; CPU-/Durchsatzwirkung trotzdem testen |
| `RESOURCE_GOVERNOR_STANDARD_EDITION` | SQL Server 2025 erweitert Editionsverfügbarkeit; reale Katalog- und Editionsprüfung bleibt nötig |
| Linux Host Stats | Linux-spezifische DMVs werden nur bei Linux und vorhandenem Systemobjekt als verfügbar markiert |
| Optimized Locking | Datenbankeigenschaft; mit ADR, RCSI und Workload interpretieren |
| Query Store Readable Secondary | SQL Server 2025-/Plattformfunktion; Katalogsicht `sys.query_store_replicas` ist maßgeblich |

### Interpretation

- `AVAILABLE` heißt: Diagnosepfad/Katalog ist nach Erkennung verfügbar. Es heißt nicht, dass das Feature aktiviert, genutzt oder gesund ist.
- `UNAVAILABLE_VERSION` kann auch bedeuten, dass das erwartete Systemobjekt auf diesem Build nicht existiert.
- `FeatureValue` muss featurebezogen interpretiert werden; Textwerte sind nicht global vergleichbar.
- Optimized Locking kann Lockmemory und bestimmte Blockierungen reduzieren, beseitigt aber nicht jeden Lockkonflikt.
- Query Store für lesbare Secondaries schreibt Ausführungsinformationen zum primären Query Store zurück; Replica-Dimensionen müssen in Auswertungen berücksichtigt werden.
- ZSTD kann schnellere und bessere Kompression bieten, erhöht aber wie andere Kompression CPU-Verbrauch und muss gegen Concurrent Workload getestet werden.

### Folgeanalyse

- In-Memory gefunden → `USP_InMemoryOltpAnalysis`
- Temporal gefunden → `USP_TemporalAnalysis`
- Service Broker gefunden → `USP_ServiceBrokerAnalysis`
- Full-Text gefunden → `USP_FullTextAnalysis`
- Query-Store-Replica verfügbar → Query-Store-Guides mit Replica Group beachten
- Spezialindex → passende Objekt-/Plananalyse

### Kosten

LOW bis MEDIUM. Cross-Database-Katalogzugriffe und optionales Spezialindexinventar; keine Benutzerdatenscans.

---

## 2. [monitor].[USP_SpecialFeatureInventory]

### Zweck

Leichtgewichtige aggregierte Nutzungsinventur sichtbarer Spezialfeatures. Es werden keine externen Locations, Credentials, Broker-Payloads, CLR-Binaries, Moduldefinitionen oder Benutzerdaten gelesen.

### Erkannte Familien

- In-Memory OLTP
- System-versioned Temporal Tables
- Service Broker
- Full-Text
- Change Tracking
- Change Data Capture
- Verschlüsselung/Always Encrypted/TDE-Metadaten
- CLR
- External Tables/Data Sources
- External Languages/Libraries
- FILESTREAM/FileTable
- Graph
- Spatial
- XML
- native JSON-/Vector-Typen, soweit versionsseitig sichtbar
- benutzerdefinierte Typen

### Aufrufe

```sql
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'RAW';
```

```sql
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames = NULL,
      @NurErkannteFeatures = 1,
      @ResultSetArt = 'RAW';
```

### DatabaseStatus

| Spalte | Bedeutung |
|---|---|
| `DatabaseName` | Scope |
| `StatusCode`, `IsPartial` | Auswertbarkeit |
| `FeatureRows` | erzeugte Featureinventarzeilen |
| `DetectedFeatureRows` | Zeilen mit erkannter Nutzung/Konfiguration |
| `ErrorNumber`, `ErrorMessage` | behandelter Fehler |
| `Detail` | Aussagegrenze |

### FeatureInventory

| Spalte | Bedeutung |
|---|---|
| `DatabaseName` | Datenbank |
| `FeatureCode` | stabiler technischer Code |
| `FeatureFamily` | lesbare Familie |
| `DetectionStatus` | etwa erkannt, nicht im sichtbaren Scope erkannt oder versionell nicht verfügbar |
| `DetectedItemCount` | aggregierte Anzahl von Metadatenobjekten/-signalen |
| `ConfigurationState` | Featurekonfiguration, sofern sinnvoll |
| `SourceObjects` | verwendete Systemkataloge |
| `RecommendedModule` | passendes Deep-Dive-Modul |
| `RecommendedModuleStatus` | verfügbar, nicht implementiert oder nicht anwendbar |
| `EvidenceLimit` | explizite Grenze |

### Interpretation

- Zähler verschiedener Features sind nicht untereinander vergleichbar. Bei Service Broker können Queue, Service und Enablement in eine Zahl einfließen; bei Temporal primär aktuelle Tabellen.
- `DetectedItemCount=0` kann fehlende Sichtbarkeit bedeuten.
- Konfiguriert, aber ohne Objekt ist ein anderer Zustand als aktiv genutzt.
- External Scripts enabled ohne externe Bibliothek kann Vorbereitungs- oder Altzustand sein.
- Database Encryption Flag, Always-Encrypted-Schlüsselmetadaten und verschlüsselte Spalten sind unterschiedliche Technologien, die in einer Familie zusammengefasst werden können.
- `@NurErkannteFeatures=1` verbessert Lesbarkeit, entfernt aber die explizite Information über nicht erkennbare oder nicht verfügbare Familien.

### Plakative und grenzwertige Beispiele

| Befund | Bewertung |
|---|---|
| Temporal erkannt, 500 Tabellen | Deep-Dive und Retention-/Kapazitätsstrategie priorisieren |
| Broker enabled, keine benutzerdefinierten Queues | möglicherweise nur Konfiguration, nicht aktive Nutzung |
| CLR Assembly Count 1 | Sicherheits-/Supportreview, nicht automatisch Risiko |
| Native Vector `UNAVAILABLE_VERSION` | erwartbar vor unterstützter Version |
| 0 Full-Text-Objekte bei eingeschränkter Metadatensicht | keine belastbare Abwesenheitsaussage |

### Folgeanalyse

Das angegebene `RecommendedModule` verwenden. Fehlt ein Deep-Dive-Modul, Quelle und Betriebsanforderung manuell prüfen.

### Kosten

LOW. Aggregierte Systemkatalogabfragen, kein Daten- oder Definitionsscan.

---

## 3. [monitor].[USP_InMemoryOltpAnalysis]

### Zweck

Best-Effort-Tiefenanalyse sichtbarer In-Memory-OLTP-Konfiguration und Runtimeevidenz zu Tabellen-/Indexmemory, Hashindizes, Memory Consumers, Checkpoint Files, aktiven Transaktionen und Resource Pools.

### Repository-Schwellen

| Parameter | Default | Bedeutung |
|---|---:|---|
| `@MinTableMemoryMb` | 1024 | große Tabelle/Indexmemory zur Sichtung |
| `@HashAvgChainWarn` | 10 | durchschnittliche Hashchain |
| `@HashMaxChainWarn` | 100 | maximale Hashchain |
| `@HashMinEmptyBucketPercent` | 10 | sehr geringe Leerbucketquote |
| `@WaitingCheckpointWarnMb` | 1024 | Checkpointfiles in wartendem Zustand |
| `@ActiveTransactionWarnCount` | 100 | aktive XTP-Transaktionen |
| `@PoolUsedWarnPercent` | 80 | Resource-Pool-Auslastung relativ zum Target |

Diese Schwellen sind heuristische Prüfgrenzen, keine automatische Bucket-, Memory- oder Poolbemessung.

### Statusresultsets

#### DatabaseStatus

`DatabaseName`, `StatusCode`, `IsPartial`, `MemoryOptimizedTableCount`, `MemoryOptimizedTableTypeCount`, `MemoryOptimizedFilegroupCount`, `SourceFailureCount`, `FindingCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

#### SourceStatus

`DatabaseName`, `SourceCode`, `StatusCode`, `IsPartial`, `RowCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

Jede Runtime-DMV wird separat behandelt. Ein partieller Hashindexstatus darf Table-Memory- oder Checkpointevidenz nicht entwerten.

### TableMemory

`DatabaseName`, `SchemaName`, `TableName`, `ObjectId`, `DurabilityDesc`, `TableAllocatedMb`, `TableUsedMb`, `IndexAllocatedMb`, `IndexUsedMb`, `TotalAllocatedMb`, `TotalUsedMb`, `UsedPercent`, `Severity`, `FindingCode`, `EvidenceLimit`.

### HashIndex

`DatabaseName`, `SchemaName`, `TableName`, `IndexName`, `ObjectId`, `IndexId`, `ConfiguredBucketCount`, `TotalBucketCount`, `EmptyBucketCount`, `EmptyBucketPercent`, `AverageChainLength`, `MaxChainLength`, `RuntimeStatsStatus`, `Severity`, `FindingCode`, `EvidenceLimit`.

`@MitHashIndexStats=1` ist HIGH_OPT_IN und benötigt `CATALOG_DEEP`, weil `sys.dm_db_xtp_hash_index_stats` laut Hersteller vollständige Tabellenarbeit verursachen kann.

### MemoryConsumer

`DatabaseName`, `MemoryConsumerType`, `MemoryConsumerDesc`, `ConsumerCount`, `AllocationCount`, `AllocatedMb`, `UsedMb`, `UsedPercent`, `EvidenceLimit`.

### Checkpoint

`DatabaseName`, `FileType`, `FileTypeDesc`, `State`, `StateDesc`, `FileCount`, `FileSizeMb`, `FileUsedMb`, `LogicalRowCount`, `Severity`, `FindingCode`, `EvidenceLimit`.

Checkpointfiles sind append-only Data-/Delta-Strukturen und durchlaufen mehrere legitime Zustände. `WAITING FOR LOG TRUNCATION` ist nicht automatisch ein Fehler; Logtrunkierung, Merge-/Recoverybedarf und Dauer prüfen.

### Transaction

`DatabaseName`, `TransactionState`, `TransactionStateDesc`, `ResultDesc`, `TransactionCount`, `Severity`, `FindingCode`, `EvidenceLimit`.

Es werden bewusst keine realen Transaktions-IDs ausgegeben.

### ResourcePool

`DatabaseName`, `ResourcePoolId`, `ResourcePoolName`, `IsDefaultOrUnbound`, `DatabasesUsingPool`, `MinMemoryPercent`, `MaxMemoryPercent`, `MaxMemoryMb`, `TargetMemoryMb`, `UsedMemoryMb`, `UsedPercentOfTarget`, `OutOfMemoryCount`, `Severity`, `FindingCode`, `EvidenceLimit`.

### Findings

`FindingOrdinal`, Scope, `Severity`, `Confidence`, `FindingCode`, `MetricName`, `MetricValue`, `ThresholdValue`, `Evidence`, `EvidenceLimit`, `RecommendedNextCheck`.

### Interpretation

| Konstellation | Bewertung |
|---|---|
| hohe TableMemory, stabiler Pool, keine OOMs | groß, aber nicht automatisch problematisch |
| durchschnittliche Chain 15, Max 20, workload hauptsächlich point lookup | Bucketreview sinnvoll |
| Max Chain 1000 durch einzelnen Extremwert, Avg 1.2 | Skew-/Schlüsseldistribution prüfen, nicht nur Maxwert |
| EmptyBucketPercent 1 % | Bucketzahl möglicherweise zu klein oder Verteilung ungleich |
| EmptyBucketPercent 99 % | stark überdimensioniert möglich; Memorykosten prüfen |
| viele Checkpointfiles WAITING FOR LOG TRUNCATION | Log-/Backup-/AG-Kontext prüfen |
| PoolUsed 90 %, keine Pressureflags | Watchlist, Verlauf und Growthplan |
| `OutOfMemoryCount>0` | historisch relevante Pressureevidenz; Reset-/Zeitkontext ergänzen |

### Aussagegrenzen

- Runtimewerte sind Momentaufnahmen oder kumulativ seit Restart/Objekterstellung.
- Hashchainqualität hängt von Schlüsselverteilung und Zugriffsmuster ab.
- Resource-Pool-Auslastung allein ist keine Max-Memory-Empfehlung.
- Checkpointfiles werden aggregiert; Dateipfade werden absichtlich nicht gelesen.
- Memory-optimized Table Types können Nutzung erzeugen, ohne dauerhafte Tabelle.

### Folgeanalyse

Query-/XTP-Indexnutzung, aktuelle Grants/Memory, Resource Governor, Log-/Backupstatus und Wiederholungsmessung.

---

## 4. [monitor].[USP_TemporalAnalysis]

### Zweck

Analysiert sichtbare system-versioned Temporal Tables, Current-/History-Zuordnung, Periodenspalten, Retentionkonfiguration, approximative Größe/Zeilenzahl und die Indexreihenfolge der History-Tabelle.

Es werden keine aktuellen oder historischen Benutzertabellenzeilen gelesen.

### Repository-Schwellen

| Parameter | Default |
|---|---:|
| `@HistorySizeWarnMb` | 10.240 MB |
| `@HistoryRowsWarn` | 10.000.000 |
| `@HistoryToCurrentRatioWarn` | 10 |
| `@MinHistoryMbForRatioWarn` | 100 MB |

### Statusresultsets

#### DatabaseStatus

`DatabaseName`, `StatusCode`, `IsPartial`, `TemporalTableCount`, `HistoryTableCount`, `SourceFailureCount`, `FindingCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

#### SourceStatus

`DatabaseName`, `SourceCode`, `StatusCode`, `IsPartial`, `RowCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

### TemporalTable

| Gruppe | Spalten |
|---|---|
| Current | `DatabaseName`, `CurrentSchemaName`, `CurrentTableName`, `CurrentObjectId`, `CurrentIsMemoryOptimized`, `CurrentDurabilityDesc` |
| History | `HistorySchemaName`, `HistoryTableName`, `HistoryObjectId` |
| Period | `PeriodStartColumnName`, `PeriodEndColumnName`, `PeriodStartIsHidden`, `PeriodEndIsHidden` |
| Retention | `DatabaseRetentionEnabled`, `HistoryRetentionPeriod`, `HistoryRetentionUnitDesc`, `RetentionMode` |
| Kapazität | `CurrentRowsApprox`, `HistoryRowsApprox`, `CurrentReservedMb`, `CurrentUsedMb`, `HistoryReservedMb`, `HistoryUsedMb`, `HistoryToCurrentRowRatio` |
| Index | `HistoryIndexCount`, `HasPeriodLeadingHistoryIndex` |
| Bewertung | `AssessmentStatus`, `EvidenceLimit` |

### HistoryIndex

`DatabaseName`, Current-/History-Scope, `IndexName`, `IndexId`, `IndexTypeDesc`, `IsUnique`, `IsDisabled`, `FirstKeyColumnName`, `SecondKeyColumnName`, `IsPeriodLeadingIndex`, `EvidenceLimit`.

Ein Period-leading History-Index wird anhand der erwarteten Reihenfolge **Period End, Period Start** bewertet. Andere Zugriffsmuster können zusätzliche Indizes benötigen.

### Findings

`FindingOrdinal`, Current-/History-Scope, `Severity`, `Confidence`, `FindingCode`, `MetricName`, `MetricValue`, `ThresholdValue`, `Evidence`, `EvidenceLimit`, `RecommendedNextCheck`.

### Interpretation

| Konstellation | Bewertung |
|---|---|
| History 20× Current, aber nur 50 MB | Ratio über Schwelle, durch Mindestgröße eventuell absichtlich nicht gewarnt |
| History 2 TB, Ratio 2 | absolute Kapazität relevant trotz moderatem Verhältnis |
| Retention OFF und update-/delete-intensive Tabelle | unbegrenztes Wachstum möglich; fachliche Aufbewahrung klären |
| Retention ON | beweist keinen erfolgreichen Cleanup |
| kein Period-leading Index | Temporal-Abfragen/Cleanup können leiden; bestehende alternative Indizes und Workload prüfen |
| HistoryIndex disabled | klarer Reviewfall |
| Hidden Period Columns | normal und oft erwünscht |
| Current memory-optimized | spezielle Kombination; Feature-/Versiongrenzen beachten |

### Aussagegrenzen

- Größen/Zeilen stammen approximativ aus Partitionsstatistiken.
- Kein Datenscan: Periodenüberlappungen, ungültige Fachzeiten oder Cleanupfortschritt werden nicht bewiesen.
- Nach `SYSTEM_VERSIONING=OFF` kann die frühere Paarbeziehung verloren sein und wird nicht zuverlässig rekonstruiert.
- Retention Policy muss fachliche und rechtliche Anforderungen erfüllen; Größe allein bestimmt sie nicht.
- Eine große History-Tabelle kann sowohl Storagekosten als auch Temporal-Querykosten erhöhen.

### Folgeanalyse

Kapazität, Index Usage/Physical Stats, Query Store für Temporal Queries, Partitionierungs-/Retentionstrategie und Cleanupmonitoring.

---

## 5. [monitor].[USP_ServiceBrokerAnalysis]

### Zweck

Analysiert sichtbare Service-Broker-Konfiguration und gruppierte Betriebsevidenz zu Queues, interner Aktivierung, Transmission Queue und Conversation Endpoints. Queue-Nutzdaten, Nachrichtenkörper und Conversation-Handles werden nicht gelesen.

### Repository-Schwellen

| Parameter | Default | Bedeutung |
|---|---:|---|
| `@TransmissionAgeWarnMinutes` | 60 | Alter des ältesten gruppierten Transmission-Eintrags |
| `@TransmissionRowsWarn` | 1.000 | gruppierte Nachrichtenanzahl als Reviewkontext |
| `@QueueRowsWarn` | 10.000 | approximative Queue-Zeilen als Kapazitätskontext |
| `@ActivationSilenceWarnMinutes` | 60 | Zeit seit letzter Aktivierung bei sichtbarem Rückstand |
| `@ConversationRowsWarn` | 100.000 | sichtbare Conversation Endpoints als Wachstumskontext |

Die Schwellen priorisieren eine manuelle Prüfung. Sie beweisen weder Zustellfehler noch fehlerhafte Kapazität oder eine Poison Message.

### Statusresultsets

#### DatabaseStatus

`DatabaseName`, `StatusCode`, `IsPartial`, `IsBrokerEnabled`, `UserQueueCount`, `UserServiceCount`, `TransmissionMessageCount`, `ConversationEndpointCount`, `SourceFailureCount`, `FindingCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

#### SourceStatus

`DatabaseName`, `SourceCode`, `StatusCode`, `IsPartial`, `RowCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

Feature-Gate, Queue-Katalog, Kapazität, Queue-Monitor, aktivierte Tasks, Transmission und Conversations werden isoliert bewertet. Eine fehlende DMV-Berechtigung entwertet zugängliche Kataloge nicht.

### Queues

`DatabaseName`, Queue-Scope, Serviceanzahl, Broker-/Queue-Schalter, Aktivierungsprozedur, Ausführungskontext, approximative Zeilen-/Seitenevidenz, Monitorzustand, Aktivierungszeitpunkte, wartende Receiver, aktive Tasks, `AssessmentStatus`, `EvidenceLimit`.

`QueueRowsApprox` stammt aus Partitionsstatistiken. Der Wert enthält keine Aussage zu Alter, Durchsatz, Priorität oder fachlich zulässigem Rückstand.

### TransmissionGroups

Gruppiert werden nicht-payloadhaltige Service-, Ziel-, Contract-, Message-Type-, Status-, Mengen- und Zeiteigenschaften. Eine Zeile in `sys.transmission_queue` ist nicht automatisch ein Fehler: Zustellung, Bestätigung und Retention können Einträge vorübergehend erhalten.

### ConversationStates

Conversation Endpoints werden nach Zustand, Initiator-/Systemflag und Lifetime aggregiert. Handles, Gruppen-IDs, Schlüsselkennungen und Nachrichteninhalt bleiben ausgeschlossen.

### Findings

Wichtige Reviewcodes sind deaktivierte Queue-Schalter, Aktivierungsstillstand bei sichtbarem Rückstand, Transmission-Status oder -Alter, Conversation-Errorzustand, abgelaufene Lifetime und isolierte Evidenzlücken.

### Interpretation

| Konstellation | Bewertung |
|---|---|
| `is_receive_enabled=0` | kann nach wiederholten Rollbacks automatisch oder manuell entstehen; Ursache separat belegen |
| Queue-Zeilen hoch, Monitor `RECEIVES_OCCURRING` | Rückstand vorhanden, aber Verarbeitung sichtbar; Trend und Durchsatz prüfen |
| Queue-Zeilen hoch, keine aktiven Tasks | nur bei vollständiger Monitor-/Taskevidenz ein belastbarer Aktivierungs-Reviewfall |
| Transmission-Status gefüllt | konkrete Transport-/Routingevidenz; Ziel, Route, Endpunkt, Zertifikate und Fehlerlog korrelieren |
| Transmission ohne Status | nicht automatisch gesund oder fehlerhaft; Alter und Verlauf ergänzen |
| viele Endpoints | kann legitime langlebige Dialoge oder unvollständigen Dialogabschluss bedeuten |
| Retention aktiviert | erklärt erhaltene Queue-Zeilen und ist kein Fehlerbefund |

### Aussagegrenzen

- Queue-Monitor und aktivierte Tasks sind Momentaufnahmen.
- Eingeschränkte Metadatensichtbarkeit kann einen scheinbaren Leerzustand erzeugen.
- Ein deaktiviertes RECEIVE beweist keine Poison Message.
- Das Modul liest keine Queue-Nutzdaten und führt kein `RECEIVE`, `ALTER QUEUE` oder `END CONVERSATION` aus.
- Kapazitäts-, Routing- und Bereinigungsmaßnahmen benötigen Zeitverlauf, Anwendungs- und Betriebskontext.

### Folgeanalyse

SQL-Fehlerlog beziehungsweise freigegebene Extended Events, Routing-/Endpunktkonfiguration, Zertifikate, Readerdurchsatz, Anwendungstransaktionen und wiederholte Messungen korrelieren. Laufzeitevidenz mit realen Namen oder Inhalten niemals in Repositoryartefakte übernehmen.

---

## 6. [monitor].[USP_FullTextAnalysis]

### Zweck

Analysiert sichtbare Full-Text-Kataloge und -Indizes sowie aktuelle Populationen, ausstehende Batches, querybare Fragmente, semantische Ähnlichkeitspopulationen und serverweiten Gatherer-/FDHost-Kontext. Tabelleninhalte, Keywords, Stopwords, Parser-Eingaben, Schlüsselwerte, Crawl-Logs und Pfade bleiben ausgeschlossen.

### Repository-Schwellen

| Parameter | Default | Bedeutung |
|---|---:|---|
| `@PopulationAgeWarnMinutes` | 60 | Alter einer aktuell sichtbaren normalen oder semantischen Population |
| `@QueryableFragmentWarn` | 30 | Zahl querybarer Fragmente mit Status 4 oder 6 |
| `@OutstandingBatchWarn` | 100 | aktuell ausstehende Batches pro Tabelle |
| `@FailedDocumentWarn` | 1 | aggregierte aktuell gemeldete Dokumentfehler |
| `@CatalogSizeWarnMb` | 10.240 MB | aggregierte logische Größe querybarer Fragmente |

Alle fünf Werte sind Priorisierungs- oder Kapazitätsheuristiken. Microsoft dokumentiert keinen universellen Fragment-, Batch-, Laufzeit- oder Speichergrenzwert.

### Statusresultsets

#### DatabaseStatus

`DatabaseName`, `StatusCode`, `IsPartial`, `IsFullTextInstalled`, `CatalogCount`, `FullTextIndexCount`, `ActivePopulationCount`, `OutstandingBatchCount`, `FindingCount`, `SourceFailureCount`, `RequiredPermission`, `ErrorNumber`, `ErrorMessage`, `Detail`.

#### SourceStatus

Feature-Gate, Katalog-/Indexmapping, Fragmente, normale Population, Batches und semantische Population werden je Datenbank isoliert. Memory Pools und FDHosts werden einmal serverweit gelesen. SQL Server 2019 benötigt für die Laufzeit-DMVs `VIEW SERVER STATE`, SQL Server 2022 oder neuer `VIEW SERVER PERFORMANCE STATE`.

### Kataloge und FullTextIndexes

Kataloge liefern Namen, Default-/Accent-Sensitivity-Kontext, sichtbare Indexanzahl sowie aggregierte Fragmentgröße. Indizes liefern Tabelle, Katalog, Enablement, Status des eindeutigen Schlüsselindex, Change-Tracking- und Crawl-Kontext, Spalten-/Semantikanzahl sowie zugeordnete Fragment-, Population- und Batchzahlen.

Der Katalogname und Tabellen-Scope sind normale Runtime-Diagnosewerte. Sie werden nicht in gespeicherte Testevidenz übernommen. Katalogpfade und Schlüsselwerte werden weder gelesen noch ausgegeben.

### Populationen, Batches und Semantik

- `sys.dm_fts_index_population` enthält nur aktuell laufende Full-Text- und semantische Extraktionen. Nullzeilen sind keine Historie und kein Abschlussnachweis.
- Status 7 kann während eines automatischen Merge auftreten; Status 11 meldet eine abgebrochene Population.
- `sys.dm_fts_outstanding_batches` wird ohne Batch-ID, Speicheradressen oder Inhalte nach Tabelle, Fehlercode und Retryzustand aggregiert.
- Dokumentfehler werden nur als Anzahl gelesen. Einzelne Fehler können Inhalte von der Suche ausschließen, ohne die gesamte Population zu stoppen.
- Die semantische Ähnlichkeitspopulation ist die zweite Phase nach der Extraktion und wird nur bei sichtbaren `STATISTICAL_SEMANTICS`-Spalten abgefragt.

### Fragmente, Memory Pools und FDHosts

Nur querybare Fragmente mit Status 4 oder 6 fließen in Fragmentanzahl, logische Größe und Zeilenzahl ein. Viele Fragmente können Full-Text-Abfragen verlangsamen; ein `REORGANIZE` wird jedoch nie automatisch ausgeführt.

Memory Pools sind serverweit gemeinsam genutzter Gatherer-Kontext. FDHosts werden ausschließlich nach Typ aggregiert; Prozess-IDs und Hostnamen bleiben ausgeschlossen. Eine nicht atomare Abweichung zwischen Population- und FDHost-Momentaufnahme besitzt nur geringe Konfidenz.

### Interpretation

| Konstellation | Bewertung |
|---|---|
| Change Tracking `MANUAL` oder `OFF` | zulässige Konfiguration; erwartete Populationsteuerung prüfen |
| `has_crawl_completed=0`, keine aktive Population | kann durch `NO POPULATION` beabsichtigt sein; kein Fehlerbeweis |
| lange Population, Fortschritt steigt | Kapazitäts-/Durchsatzkontext, nicht Stillstand |
| Status 11 | belastbare aktuelle Abbruchmeldung; Ursache in geschützter Laufzeitumgebung prüfen |
| Retry oder `hr_batch<>0` | aktueller Batchreview; Fehlercode und Zeitverlauf korrelieren |
| viele querybare Fragmente | Suchlatenz und Trend prüfen, erst danach Wartung planen |
| Memory Pool groß | gemeinsamer Ressourcenverbrauch, kein datenbankspezifischer Druckbefund |

### Aussagegrenzen

- Katalogmetadaten beweisen keine Vollständigkeit indizierter Inhalte.
- Crawl-Logs liegen außerhalb des Repositorys und dürfen keine realen Namen, Inhalte oder interne Strukturen in Artefakte übertragen.
- Eine leere Laufzeit-DMV ist keine Historie.
- Alter, Batchzahl und Fragmentzahl sind ohne Zeitreihe und Workload kein Ursachenbeweis.
- Das Modul führt kein `ALTER FULLTEXT`, keine Population und keine Reorganisation aus.

### Folgeanalyse

Folgemessung von Fortschritt und Batches, Suchlatenz, I/O-/Logkontext sowie geschützte Full-Text- und Crawl-Logs in der Laufzeitumgebung korrelieren. Nur abstrahierte, synthetische Testergebnisse dokumentieren.

## Anfänger-Entscheidungsbaum

```mermaid
flowchart TD
    A[Unbekannte Spezialfeatures] --> B[SpecialFeatureInventory]
    B --> C{Feature erkannt?}
    C -->|Nein| D[Sichtbarkeit und Version prüfen]
    C -->|Ja| E{Deep-Dive vorhanden?}
    E -->|In-Memory| F[InMemoryOltpAnalysis]
    E -->|Temporal| G[TemporalAnalysis]
    E -->|Service Broker| H[ServiceBrokerAnalysis]
    E -->|Full-Text| N[FullTextAnalysis]
    E -->|nur Capability| L[ServerFeatureCapabilities]
    F --> I[SourceStatus und Findings gemeinsam lesen]
    G --> J[Retention, Größe und History-Index gemeinsam lesen]
    H --> K[Queue, Aktivierung, Transmission und Conversations]
    N --> O[Population, Batches und Fragmente]
    L --> M[Version + Katalog + Plattform + DB-Kontext]
```

## Quellen

- [What's new in SQL Server 2025](https://learn.microsoft.com/sql/sql-server/what-s-new-in-sql-server-2025)
- [Editions and supported features of SQL Server 2025](https://learn.microsoft.com/sql/sql-server/editions-and-components-of-sql-server-2025)
- [Optimized locking](https://learn.microsoft.com/sql/relational-databases/performance/optimized-locking)
- [Query Store for readable secondary replicas](https://learn.microsoft.com/sql/relational-databases/performance/query-store-for-secondary-replicas)
- [sys.query_store_replicas](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-query-store-replicas-transact-sql)
- [Backup compression and ZSTD](https://learn.microsoft.com/sql/relational-databases/backup-restore/backup-compression-sql-server)
- [In-Memory OLTP overview](https://learn.microsoft.com/sql/relational-databases/in-memory-oltp/overview-and-usage-scenarios)
- [sys.dm_db_xtp_hash_index_stats](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-xtp-hash-index-stats-transact-sql)
- [sys.dm_db_xtp_checkpoint_files](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-views/sys-dm-db-xtp-checkpoint-files-transact-sql)
- [Temporal tables](https://learn.microsoft.com/sql/relational-databases/tables/temporal-tables)
- [Manage temporal history retention](https://learn.microsoft.com/sql/relational-databases/tables/manage-retention-of-historical-data-in-system-versioned-temporal-tables)
- [Temporal table considerations and limitations](https://learn.microsoft.com/sql/relational-databases/tables/temporal-table-considerations-and-limitations)
- [sys.service_queues](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-service-queues-transact-sql)
- [sys.transmission_queue](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-transmission-queue-transact-sql)
- [sys.dm_broker_queue_monitors](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-broker-queue-monitors-transact-sql)
- [sys.dm_broker_activated_tasks](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-broker-activated-tasks-transact-sql)
- [sys.conversation_endpoints](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-conversation-endpoints-transact-sql)
- [sys.fulltext_indexes](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-fulltext-indexes-transact-sql)
- [sys.fulltext_index_fragments](https://learn.microsoft.com/sql/relational-databases/system-catalog-views/sys-fulltext-index-fragments-transact-sql)
- [sys.dm_fts_index_population](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-fts-index-population-transact-sql)
- [sys.dm_fts_outstanding_batches](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-fts-outstanding-batches-transact-sql)
- [sys.dm_fts_semantic_similarity_population](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-fts-semantic-similarity-population-transact-sql)
- [sys.dm_fts_memory_pools](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-fts-memory-pools-transact-sql)
- [sys.dm_fts_fdhosts](https://learn.microsoft.com/sql/relational-databases/system-dynamic-management-objects/sys-dm-fts-fdhosts-transact-sql)
