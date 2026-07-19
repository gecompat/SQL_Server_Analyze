# [monitor].[USP_AvailabilityDeepAnalysis]

**Bereich:** Infrastruktur  
**Zweck:** Vertieft Availability Groups mit Send-/Redo-Queues, Lag, Cluster- und Replica-Evidenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis]
      @MitClusterNetzwerken = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Replica-/Datenbank-Beziehung, Queue-/Lagmetrik, Clusterkomponente oder ein Finding.

## So lesen

Send Queue, Redo Queue, geschätzte Lagzeit, Synchronisierungszustand, Rolle und Trend gemeinsam lesen.

## Warum kann das problematisch sein?

Wachsende Send Queue weist eher auf Transport/Primary hin; wachsende Redo Queue auf Secondary-Redo, I/O oder CPU.

## Wann ist es kein Problem?

Ein kurzer Peak nach großer Transaktion kann sich normal abbauen.

## Beispiel und Folgeschritt

Send Queue stabil klein, Redo Queue wächst über mehrere Messungen: Fokus auf Secondary-I/O/CPU/Redo statt Netzwerk. Counter, Storage und Cluster prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?

### Technischer Hintergrund

Vertiefung kombiniert Cluster-/Replica-/Databasezustand, Send/Redo, Flow Control, Suspend Reason, Seeding, Page Repair und gegebenenfalls Read-only Routing. Logproduktion, Capture, Send, Harden und Redo sind getrennte Pipelineabschnitte.

### Datenkette

`sys.availability_groups`, `sys.availability_replicas`, `sys.dm_hadr_auto_page_repair`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_cluster`, `sys.dm_hadr_cluster_members`, `sys.dm_hadr_cluster_networks`, `sys.dm_hadr_database_replica_states`, `sys.dm_hadr_physical_seeding_stats`.

### Zeit- und Scope-Modell

Aktueller verteilungsabhängiger Snapshot; einige Daten nur auf Primary oder lokalem Replica verfügbar.

### Bewertung und Gegenprobe

Pipeline lokalisieren: Log Send Queue vs Redo Queue, Rate/Trend, Connected/Suspended, Last Hardened/Redone, Sync Commit Waits, Disk-/Networkkontext. Partialvisibility explizit halten.

### Typische Fehlinterpretation

Estimated catch-up time aus Queue/aktueller Rate ist bei Rateänderung instabil. `NOT_HEALTHY` ist Folge, nicht Root Cause.

### Folgeanalyse

Current Log/I/O/Waits, Clusterlog, OS-/Netzwerktelemetrie.

[Technische Detailbeschreibung](../07_Infrastructure.md#10-monitorusp_availabilitydeepanalysis)
