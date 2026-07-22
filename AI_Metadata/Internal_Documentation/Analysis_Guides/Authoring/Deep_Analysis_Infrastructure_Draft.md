# Draft: technische Vertiefung – Infrastructure

**Stand:** 19. Juli 2026
**Status:** integriertes Authoring-Archiv; nicht kanonisch
**Abdeckung:** 13 Procedures aus `07_Infrastructure`

> Infrastrukturdiagnose verbindet lokale Runtime-DMVs, `msdb`-Historie und verteilte Komponenten. Die lokale Instanz kann bei AG, Log Shipping und Replication nur einen Teil der Topologie sehen. History Cleanup, Monitorlatenz und fehlender Remotezugriff müssen als Evidenzgrenzen dokumentiert werden.

## 1. Gemeinsame Zeit- und Topologiemodelle

- Agent-/Backup-/Restore-/Log-Shipping-Historie ist nur so vollständig wie `msdb`-Retention und Cleanup.
- HADR-DMVs sind Momentaufnahmen; Queuegröße ohne Änderungsrate zeigt Bestand, nicht Trend.
- Replication besitzt Publisher, Distributor und Subscriber mit unterschiedlichen lokalen Sichten.
- CDC/Change Tracking besitzen Retentiongrenzen; Consumer können hinter den noch verfügbaren Bereich zurückfallen.
- Ein erfolgreicher Metadatensatz beweist nicht, dass Medium, Netzwerkpfad oder Remoteziel aktuell verwendbar ist.

## 2. Procedures

### `[monitor].[USP_AgentStatus]`

**Leitfrage:** Ist SQL Server Agent auf dieser Plattform vorhanden und läuft der Dienst?

**Technischer Hintergrund:** Agent führt Jobs über einen separaten Dienst und `msdb`-Metadaten aus. Dienstzustand, Startmodus und Plattformverfügbarkeit sind Voraussetzungen, aber noch keine Aussage über Scheduler, Jobowner, Proxies oder einzelne Jobs.

**Datenkette:** `msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.dm_server_services`.

**Zeit-/Scope-Modell:** Aktueller Servicezustand; bei Restart/Failover kann der Status wechseln.

**Bewertung und Gegenprobe:** Dienst vorhanden/läuft, Edition/Plattform, Startmodus und Agent-XPs/Erreichbarkeit gemeinsam lesen. Ein bewusst deaktivierter Agent kann in containerisierten oder extern orchestrierten Umgebungen normal sein.

**Typische Fehlinterpretation:** `Running` beweist weder aktive Schedules noch erfolgreiche Jobs. Ein gestoppter Agent erklärt fehlende Ausführungen, aber nicht deren ursprüngliche Ursache.

**Folgeanalyse:** `USP_AgentJobs` und `USP_AgentMonitoringAnalysis`.

### `[monitor].[USP_AgentJobs]`

**Leitfrage:** Welche Jobs sind aktiviert, geplant, aktuell laufend oder zuletzt fehlgeschlagen beziehungsweise ungewöhnlich langsam?

**Technischer Hintergrund:** `msdb.dbo.sysjobs`, Steps, Schedules, Job Activity und History bilden Definition, aktuelle Instanzaktivität und vergangene Outcomes. `sysjobhistory` speichert Job-/Stepzeilen mit integercodierten Datum-/Zeit-/Dauerwerten; laufende Aktivität liegt in `sysjobactivity`.

**Datenkette:** `master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysjobsteps`, `msdb.dbo.sysschedules`, `sys.sp_executesql`.

**Zeit-/Scope-Modell:** Konfigurationssnapshot plus aufbewahrte History. Agentrestart erzeugt neue Sessionkontexte; Cleanup begrenzt Historie.

**Bewertung und Gegenprobe:** Jobstatus, aktueller Step, Run Requested/Start/Stop, Retry, letzte Outcomes, Schedule und typische Laufzeit zusammen lesen. Jobgesamtzeile und Stepfehler unterscheiden.

**Typische Fehlinterpretation:** `LastRunOutcome=Succeeded` kann einen später aktuell laufenden/steckenden Lauf überdecken. History kann abgeschnitten sein; lange Dauer muss mit Workloadfenster verglichen werden.

**Folgeanalyse:** `USP_AgentMonitoringAnalysis`, Current Requests/Blocking und Jobstep-/Logoutput.

### `[monitor].[USP_ResourceGovernorAnalysis]`

**Leitfrage:** Wie klassifiziert und begrenzt Resource Governor Sessions und welche Pools/Groups zeigen Druck oder Abweichungen?

**Technischer Hintergrund:** Classifier Function ordnet neue Sessions Workload Groups zu; Groups verweisen auf Resource Pools. Katalogsichten enthalten konfigurierte Werte, Runtime-DMVs `value_in_use` und Counter. CPU Caps, Min/Max Memory, Grant Percentage, Request Limits und External Pools wirken auf unterschiedliche Ressourcen.

**Datenkette:** `master.sys.objects`, `master.sys.schemas`, `sys.dm_exec_sessions`, `sys.dm_resource_governor_configuration`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`, `sys.resource_governor_configuration`, `sys.resource_governor_resource_pools`, `sys.resource_governor_workload_groups`.

**Zeit-/Scope-Modell:** Aktueller Config-/Runtimezustand; Counter meist kumulativ seit Aktivierung/Start. Bereits verbundene Sessions werden durch Classifieränderung nicht automatisch neu klassifiziert.

**Bewertung und Gegenprobe:** Configured vs runtime, Pool/Group-Zuordnung, aktive Requests, Queues, CPU/Memory/Grantlimits und Default/Internal-Kontext lesen. Throttling kann absichtlich sein.

**Typische Fehlinterpretation:** Eine Query in einer Group beweist nicht, dass der Classifier aktuell dieselbe Entscheidung für neue Logins treffen würde. Limits sind nicht alle harte Reservierungen.

**Folgeanalyse:** Current Requests/Memory Grants, Configuration und reproduzierbarer Login-/Classifiertest.

### `[monitor].[USP_AvailabilityGroups]`

**Leitfrage:** Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?

**Technischer Hintergrund:** Primär erzeugt Log Records, sendet Logblöcke an Secondaries, diese harden und redoen. Synchroner Commit wartet je Konfiguration auf Bestätigung. Replica-/Database-DMVs liefern Role, Connection, Synchronization State/Health, Send/Redo Queue, Rate und Last Hardened/Redone.

**Datenkette:** `sys.availability_group_listener_ip_addresses`, `sys.availability_group_listeners`, `sys.availability_groups`, `sys.availability_read_only_routing_lists`, `sys.availability_replicas`, `sys.dm_hadr_`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_database_replica_states`, `sys.fn_hadr_is_primary_replica`.

**Zeit-/Scope-Modell:** Aktueller lokaler Snapshot; Ratewerte können intern über begrenzte Intervalle berechnet werden und schwanken.

**Bewertung und Gegenprobe:** Role, Availability Mode, Failover Mode, Connected State, Sync State, Queue MB, Rate und Zeitmarken kombinieren. Queue/Rate liefert eine grobe Abarbeitungszeit nur bei stabiler Rate.

**Typische Fehlinterpretation:** `SYNCHRONIZED` bedeutet nicht null Latenz oder lesbare Secondary. Queuegröße allein ohne Trend und Workloadrate ist keine Prognose.

**Folgeanalyse:** `USP_AvailabilityDeepAnalysis`, Current Log/I/O und externe Cluster-/Netzwerktelemetrie.

### `[monitor].[USP_BackupRecovery]`

**Leitfrage:** Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?

**Technischer Hintergrund:** `msdb` speichert Backup Sets, Medien-/Dateiinformation, Type, LSNs, Start/Finish, Size/Compression/Checksum und Damageindikatoren. Recovery Model bestimmt, ob eine kontinuierliche Logkette erwartet wird.

**Datenkette:** `msdb.dbo.backupmediafamily`, `msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

**Zeit-/Scope-Modell:** Historie innerhalb `msdb`-Retention; Datenträger/Dateien werden nicht geöffnet.

**Bewertung und Gegenprobe:** Letzte Backupzeiten gegen RPO/Policy, Recovery Model, CopyOnly, Checksum, Damage, Größe/Dauer und Logbackupkontinuität prüfen. SIMPLE benötigt keine Logbackups, FULL ohne regelmäßige Logbackups verhindert Logtruncation.

**Typische Fehlinterpretation:** Eine erfolgreiche Backup-Historyzeile beweist weder Dateiexistenz noch erfolgreichen Restore. `RESTORE VERIFYONLY` ist ebenfalls kein vollständiger Restoretest.

**Folgeanalyse:** `USP_BackupChainAnalysis`, Database Integrity und regelmäßiger echter Restoretest.

### `[monitor].[USP_LogShippingStatus]`

**Leitfrage:** Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?

**Technischer Hintergrund:** Log Shipping besteht aus Backupjob auf Primary, Copy-/Restorejobs auf Secondary und optional Monitorserver. Monitor-/Primary-/Secondarytabellen halten letzte Datei-/Zeit-/Schwellenwerte. Jede Stufe kann unabhängig zurückliegen.

**Datenkette:** `msdb.dbo.log_shipping_monitor_primary`, `msdb.dbo.log_shipping_monitor_secondary`, `msdb.dbo.log_shipping_primary_databases`, `msdb.dbo.log_shipping_secondary_databases`.

**Zeit-/Scope-Modell:** Monitor-Metadaten mit eigener Aktualisierungszeit plus Jobhistory. Clock Skew und stale Monitor beeinflussen Interpretation.

**Bewertung und Gegenprobe:** Backup-, Copy- und Restorelatenz getrennt lesen; letzte Dateinamen/Zeiten, Threshold, Alertstatus, Jobzustand und Monitoraktualität korrelieren. Restore Mode/Delay kann absichtlich verzögern.

**Typische Fehlinterpretation:** Ein grüner Monitor kann stale sein. Eine alte Restorezeit ist bei konfiguriertem Delay nicht automatisch Fehler. Dateinamen allein beweisen keine lückenlose LSN-Kette.

**Folgeanalyse:** Agent Jobs, Backup Chain und Secondary-/Shareprüfung.

### `[monitor].[USP_ReplicationStatus]`

**Leitfrage:** Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?

**Technischer Hintergrund:** Transactional Replication nutzt Log Reader und Distribution Agents; Merge Replication eigene Agents/Sessions. Publisher-, Distributor- und Subscriber-Metadaten liegen auf verschiedenen Servern/Datenbanken. History und Commands bilden begrenzte Zustände/Latenz.

**Datenkette:** `sys.databases`, `sys.sp_executesql`.

**Zeit-/Scope-Modell:** Verteilte Momentaufnahme plus Distributor-/Agenthistory innerhalb Retention.

**Bewertung und Gegenprobe:** Topologierolle, Agentstatus, letzte Aktion/Fehler, undistributed commands, geschätzte Latenz und Zeitmarken zusammen lesen. Remote-/Distributorzugriff als Partialstatus ausgeben.

**Typische Fehlinterpretation:** `Running` bedeutet nur aktiver Agent, nicht geringe Latenz. Lokale Leere kann fehlende Rolle oder fehlenden Remotezugriff bedeuten.

**Folgeanalyse:** `USP_DataCaptureDeepAnalysis`, Agent Jobs, Log/Distributor-DB-Kapazität und Replication Monitor.

### `[monitor].[USP_DataCaptureStatus]`

**Leitfrage:** Welche Change-Capture-Technologien sind aktiviert und grundsätzlich betriebsbereit?

**Technischer Hintergrund:** CDC liest Transaction Log asynchron in Change Tables und räumt per Cleanupjob auf. Change Tracking speichert kompakte Änderungsinformationen mit Retention/Auto Cleanup, keine vollständigen historischen Werte. Replication besitzt eigenen Logreader-/Distributionspfad.

**Datenkette:** `master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

**Zeit-/Scope-Modell:** Aktueller Enablement-/Konfigurationszustand mit begrenzten Job-/LSN-/Versionmarken.

**Bewertung und Gegenprobe:** Technologie, Captureinstanzen, Jobs, Retention, Min/Max LSN oder Change Tracking Versions und Tabellenabdeckung lesen. Consumerposition gegen Mindestversion/MinLSN prüfen.

**Typische Fehlinterpretation:** `Enabled=1` beweist keinen aktuellen Durchsatz, keine lückenlose Retention und keine funktionierenden Consumer.

**Folgeanalyse:** `USP_DataCaptureDeepAnalysis`, Agent Jobs und Consumercheckpoint.

### `[monitor].[USP_InfrastructureAnalysis]`

**Leitfrage:** Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?

**Technischer Hintergrund:** Der Wrapper orchestriert Agent, Resource Governor, AG, Backup, Log Shipping, Replication und Capture. Nicht konfigurierte Features sollen als Status statt Fehler behandelt werden; Deep Children bleiben opt-in.

**Datenkette:** Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

**Zeit-/Scope-Modell:** Nicht atomare Mischung aus Snapshots und `msdb`-Historien.

**Bewertung und Gegenprobe:** Modulstatus zuerst, dann nur konfigurierte/auffällige Komponenten vertiefen. Ein nicht vorhandenes Feature ist normal, sofern der Scope es nicht erwartet.

**Typische Fehlinterpretation:** Leere Resultsets dürfen nicht familienübergreifend als gesund zusammengefasst werden; jede Quelle besitzt eigene Retention und Berechtigung.

**Folgeanalyse:** Betroffenes Childmodul mit engem Scope.

### `[monitor].[USP_BackupChainAnalysis]`

**Leitfrage:** Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?

**Technischer Hintergrund:** Fullbackups definieren Database Backup LSN/Checkpoint; Differentials basieren auf Differential Base; Logbackups decken First/Last LSN und Recovery Forks ab. CopyOnly beeinflusst Differential Base beziehungsweise Logkette unterschiedlich. Restorefolge muss LSN- und Forkkonsistenz wahren.

**Datenkette:** `msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

**Zeit-/Scope-Modell:** `msdb`-Metadaten im gewählten Fenster; ein zu kurzes Fenster kann die notwendige Basis ausblenden.

**Bewertung und Gegenprobe:** Recovery Fork, Fullbasis, Differential Base, Log First/Last LSN, Gap-/Overlapindikatoren, CopyOnly und Backupzeiten prüfen. Kette je gewünschtem Restorezeitpunkt bewerten.

**Typische Fehlinterpretation:** Metadatenkonsistenz beweist nicht, dass Medien vorhanden, unbeschädigt, entschlüsselbar oder zugreifbar sind. Ein vermeintliches Gap kann durch außerhalb des Fensters liegende Sets entstehen.

**Folgeanalyse:** Echter Restoretest, `USP_BackupRecovery`, Encryption-/Certificate-Governance.

### `[monitor].[USP_AvailabilityDeepAnalysis]`

**Leitfrage:** Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?

**Technischer Hintergrund:** Vertiefung kombiniert Cluster-/Replica-/Databasezustand, Send/Redo, Flow Control, Suspend Reason, Seeding, Page Repair und gegebenenfalls Read-only Routing. Logproduktion, Capture, Send, Harden und Redo sind getrennte Pipelineabschnitte.

**Datenkette:** `sys.availability_groups`, `sys.availability_replicas`, `sys.dm_hadr_auto_page_repair`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_cluster`, `sys.dm_hadr_cluster_members`, `sys.dm_hadr_cluster_networks`, `sys.dm_hadr_database_replica_states`, `sys.dm_hadr_physical_seeding_stats`.

**Zeit-/Scope-Modell:** Aktueller verteilungsabhängiger Snapshot; einige Daten nur auf Primary oder lokalem Replica verfügbar.

**Bewertung und Gegenprobe:** Pipeline lokalisieren: Log Send Queue vs Redo Queue, Rate/Trend, Connected/Suspended, Last Hardened/Redone, Sync Commit Waits, Disk-/Networkkontext. Partialvisibility explizit halten.

**Typische Fehlinterpretation:** Estimated catch-up time aus Queue/aktueller Rate ist bei Rateänderung instabil. `NOT_HEALTHY` ist Folge, nicht Root Cause.

**Folgeanalyse:** Current Log/I/O/Waits, Clusterlog, OS-/Netzwerktelemetrie.

### `[monitor].[USP_AgentMonitoringAnalysis]`

**Leitfrage:** Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?

**Technischer Hintergrund:** Die Procedure verbindet Job-/Step-/Schedule-/Historyanalyse mit Alerts, Operators und Database Mail-/Notificationkontext. Laufzeitanomalien benötigen historische Vergleichswerte; Notifications benötigen korrekt verknüpfte Operator-/Mailkonfiguration.

**Datenkette:** `msdb.dbo.agent_datetime`, `msdb.dbo.sysalerts`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysmail_allitems`, `msdb.dbo.sysnotifications`, `msdb.dbo.sysoperators`, `msdb.dbo.sysschedules`, `sys.dm_server_services`.

**Zeit-/Scope-Modell:** Konfigurationssnapshot plus begrenzte Ausführungshistorie.

**Bewertung und Gegenprobe:** Fehlerhäufigkeit, letzter/aktueller Lauf, typische Dauer, Schedulemiss, Retry, Alertbedingungen, Operatorzeiten und Mailstatus korrelieren. Kritische Jobs nach Funktion priorisieren.

**Typische Fehlinterpretation:** Keine Mail bedeutet nicht kein Fehler und ein erfolgreicher Mailtest nicht funktionierende Jobnotification. P95-/Baselinewerte sind bei wenigen Läufen schwach.

**Folgeanalyse:** Agent Jobs, Jobstepoutput, Database Mail Logs und Current State.

### `[monitor].[USP_MaintenanceOperations]`

**Leitfrage:** Welche Wartungsoperationen laufen, sind pausiert/resumable oder blockiert, und wie belastbar ist ihre Fortschrittsanzeige?

**Technischer Hintergrund:** Aktive BACKUP/RESTORE/DBCC/INDEX-Commands erscheinen in Requests; resumable Indexoperationen besitzen persistierte Katalogzeilen mit State, Start/Pause, Prozent und Ressourcenoptionen. Locks, Log, TempDB und I/O können die Laufzeit dominieren.

**Datenkette:** `msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.databases`, `sys.dm_exec_requests`, `sys.dm_tran_persistent_version_store_stats`, `sys.index_resumable_operations`.

**Zeit-/Scope-Modell:** Aktueller Requestsnapshot plus persistierter resumable Zustand.

**Bewertung und Gegenprobe:** Command, Status, Percent Complete, Estimated Completion, DOP, Wait/Blocker, Log-/TempDB-/I/O-Kontext und Resume/Pauseoptionen lesen. Pausierte Operation kann weiterhin Speicher/Strukturzustand belegen.

**Typische Fehlinterpretation:** Percent Complete ist nur für unterstützte Commands und nicht linear. Abbruch kann Rollback-/Cleanupkosten verursachen; `PAUSED` ist nicht erfolgreich abgeschlossen.

**Folgeanalyse:** Current Requests/Blocking/IO/Log und operationsspezifischer Runbook.

## 3. Offizielle Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/sql/ssms/agent/sql-server-agent)
- [Resource Governor](https://learn.microsoft.com/sql/relational-databases/resource-governor/resource-governor)
- [Always On availability groups overview](https://learn.microsoft.com/sql/database-engine/availability-groups/windows/overview-of-always-on-availability-groups-sql-server)
- [Monitor availability groups](https://learn.microsoft.com/sql/database-engine/availability-groups/windows/monitor-availability-groups-transact-sql)
- [Backup and restore](https://learn.microsoft.com/sql/relational-databases/backup-restore/back-up-and-restore-of-sql-server-databases)
- [Transaction log backups](https://learn.microsoft.com/sql/relational-databases/backup-restore/transaction-log-backups-sql-server)
- [About log shipping](https://learn.microsoft.com/sql/database-engine/log-shipping/about-log-shipping-sql-server)
- [Replication](https://learn.microsoft.com/sql/relational-databases/replication/sql-server-replication)
- [Change Data Capture](https://learn.microsoft.com/sql/relational-databases/track-changes/about-change-data-capture-sql-server)
- [Change Tracking](https://learn.microsoft.com/sql/relational-databases/track-changes/about-change-tracking-sql-server)
- [Resumable index operations](https://learn.microsoft.com/sql/relational-databases/indexes/perform-index-operations-online)
