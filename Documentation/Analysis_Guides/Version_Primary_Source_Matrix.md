# Versions- und Primärquellenmatrix

**Stand:** 20. Juli 2026
**Status:** kanonische Nachweismatrix für versionsabhängige Aussagen
**Zielplattformen:** SQL Server 2019, 2022 und 2025; Azure SQL Managed Instance nur bei ausdrücklich genanntem Plattformbezug

## Zweck

Diese Matrix verbindet versionsabhängige Aussagen der Analysis Guides mit offiziellen Microsoft-Primärquellen und den betroffenen Frameworkbereichen. Sie ersetzt weder Capability Detection noch Laufzeittests: Build, Edition, Compatibility Level, Datenbankzustand, Replica-Rolle, Featurekonfiguration und effektive Berechtigung werden weiterhin am Zielsystem geprüft.

## Engine- und Compatibility-Basis

| Ziel | Engine | typischer Default für neue Datenbanken | Frameworkgrenze | Primärquelle |
|---|---:|---:|---|---|
| SQL Server 2019 | 15.x | 150 | minimale unterstützte Version; 2019-spezifische Capabilitypfade | [ALTER DATABASE Compatibility Level](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level?view=sql-server-ver17) |
| SQL Server 2022 | 16.x | 160 | neue 2022-Funktionen nur nach Capability- und Compatibility-Prüfung | [ALTER DATABASE Compatibility Level](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level?view=sql-server-ver17) |
| SQL Server 2025 | 17.x | 170 | 2025-Syntax und -Kataloge werden nicht allein aus der Engineversion abgeleitet | [ALTER DATABASE Compatibility Level](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-compatibility-level?view=sql-server-ver17) |

## Nachweismatrix

| Aussageklasse | Versionsgrenze | Betroffene Guides/Procedures | Offizielle Primärquelle | Noch benötigte Evidenz |
|---|---|---|---|---|
| Serverweite Performance-DMVs verwenden bis 2019 typischerweise `VIEW SERVER STATE`, ab 2022 je Quelle `VIEW SERVER PERFORMANCE STATE` | 2019 gegenüber 2022+ | Current State, Plan Cache, Server Health; Capability-Prüfung | [`sys.dm_os_performance_counters`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17) | Restricted-Login-Verträge auf allen drei Zielversionen |
| Query-Store-Kataloge verwenden bis 2019 `VIEW DATABASE STATE`, ab 2022 je Quelle `VIEW DATABASE PERFORMANCE STATE` oder ein höheres Recht | 2019 gegenüber 2022+ | Query Store und IQP | [`sys.database_query_store_options`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-query-store-options-transact-sql?view=sql-server-ver17) | Datenbankbezogene Restricted-User-Verträge |
| Intelligent Query Processing ist feature-, engine- und compatibilityabhängig | ab 2019, erweitert in 2022/2025 | `USP_IntelligentQueryProcessingAnalysis`, Query Store | [Intelligent Query Processing](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver17) | Feature-positive Pläne je Zielversion |
| Parameter Sensitive Plan Optimization benötigt den passenden 2022+-Pfad und Compatibility Level | 2022+, typischerweise 160 | IQP, Query Store, Plan Cache | [Parameter Sensitive Plan Optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization?view=sql-server-ver17) | vorhandener Drei-Versionen-Vertrag plus feature-positive Workload |
| Optional Parameter Plan Optimization ist ein 2025-Pfad und bleibt capability-first | 2025, Compatibility 170 | IQP, Query Store, Plan Cache | [Optional Parameter Plan Optimization](https://learn.microsoft.com/en-us/sql/relational-databases/performance/optional-parameter-optimization?view=sql-server-ver17) | feature-positive 2025-Workload |
| Native reguläre Ausdrücke dürfen nur im 2025-/Compatibility-170-Pfad verwendet werden | 2025, Compatibility 170 | Filter- und Prädikatverträge | [Regular expressions](https://learn.microsoft.com/en-us/sql/relational-databases/regular-expressions/overview?view=sql-server-ver17) | vorhandener statischer Regex-Vertrag plus 2025-Laufzeitgate |
| Query Store auf lesbaren Secondary Replicas und zugehörige Replica-Kataloge sind versions-/plattformabhängig | produktiv unterstützt ab SQL Server 2025; SQL Server 2022 nur dokumentierte Limited Preview mit Trace Flag; dokumentierte Azure-Plattformen separat | Query Store, Availability | [Query Store for secondary replicas](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-for-secondary-replicas?view=sql-server-ver17) | feature-positive Windows-/AG- oder Azure-MI-Evidenz |
| Optimized Locking ist kein universeller Zustand und muss aus Datenbank-/Plattformkontext abgeleitet werden | 2025 beziehungsweise dokumentierte Azure-Plattformen | Blocking, Transactions, Server Feature Capabilities | [Optimized locking](https://learn.microsoft.com/en-us/sql/relational-databases/performance/optimized-locking?view=sql-server-ver17) | kontrollierte feature-positive Blocking-Evidenz |
| ADR/Persistent Version Store ist seit 2019 verfügbar, Zustand und Kosten bleiben datenbankbezogen | 2019+ | Maintenance, TempDB, Current Transactions | [Accelerated Database Recovery](https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-concepts?view=sql-server-ver17) | kontrollierte PVS-/Cleanup-Evidenz |
| Der native `vector`-Datentyp ist ein 2025-Pfad | 2025 | Special Feature Inventory | [`vector` data type](https://learn.microsoft.com/en-us/sql/t-sql/data-types/vector-data-type?view=sql-server-ver17) | feature-positive 2025-Fixture |
| ZSTD-Backupkompression ist editions-, versions- und algorithmusabhängig | 2025 | Backup/Recovery und Feature Inventory | [Backup compression](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/backup-compression-sql-server?view=sql-server-ver17) | kontrolliertes Backup auf geeignetem Ziel |

## Pflegevertrag

1. Eine neue versionsabhängige Aussage erhält hier eine Zeile oder verweist auf eine bereits passende Aussageklasse.
2. Als Produktsemantik gelten Microsoft Learn und der kanonische Frameworkcode. Communityquellen dürfen nur Praxiskontext ergänzen.
3. Ein erreichbarer Link beweist keine fachliche Richtigkeit. Die Aussage wird zusätzlich gegen die im Dokument genannte Version und den tatsächlichen Codepfad geprüft.
4. Ein transient nicht erreichbarer Link blockiert das Gate nicht. Ein dauerhaftes HTTP `404` oder `410` im Analysis-Guide-/Quellenscope blockiert die Dokumentationsprüfung.
5. Plattformabhängige Aussagen bleiben als Evidenzlücke markiert, bis ein autorisiertes feature-positives Ziel den Pfad bestätigt.

## Ergebnis des Reviews vom 20. Juli 2026

Die 84 Procedure-Seiten und neun Familienguides bleiben fachlich abgedeckt. Die noch offenen Punkte sind keine fehlenden Draftfamilien, sondern die in der letzten Spalte genannten feature-positiven Laufzeitnachweise. Änderungen an SQL-Server-Versionen, Compatibility-Logik, Berechtigungen oder Quellobjekten lösen einen erneuten gezielten Primärquellenabgleich aus.
