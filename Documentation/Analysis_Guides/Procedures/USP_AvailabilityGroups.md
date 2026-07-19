# [monitor].[USP_AvailabilityGroups]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Availability-Group-, Replica-, Datenbank- und Routingzustand.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityGroups]
      @MitRouting = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine AG, Replica, Availability Database oder Routingkonfiguration.

## So lesen

Replica-Rolle, Connected State, Synchronization State, Health, Availability Mode, Failover Mode und Routing gemeinsam lesen.

## Warum kann das problematisch sein?

Disconnected oder not synchronizing kann RPO-/Failoverrisiko erhöhen; fehlerhaftes Routing kann Read-Only-Workload falsch lenken.

## Wann ist es kein Problem?

Asynchrone Replicas dürfen Lag besitzen. Entscheidend sind vereinbartes RPO, Trend und geplanter Einsatzzweck.

## Beispiel und Folgeschritt

30 Sekunden Lag bei asynchroner DR-Replica kann policykonform sein; vor synchronem Failover ist derselbe Zustand kritisch. Danach `USP_AvailabilityDeepAnalysis` verwenden.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?

### Technischer Hintergrund

Primär erzeugt Log Records, sendet Logblöcke an Secondaries, diese harden und redoen. Synchroner Commit wartet je Konfiguration auf Bestätigung. Replica-/Database-DMVs liefern Role, Connection, Synchronization State/Health, Send/Redo Queue, Rate und Last Hardened/Redone.

### Datenkette

`sys.availability_group_listener_ip_addresses`, `sys.availability_group_listeners`, `sys.availability_groups`, `sys.availability_read_only_routing_lists`, `sys.availability_replicas`, `sys.dm_hadr_`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_database_replica_states`, `sys.fn_hadr_is_primary_replica`.

### Zeit- und Scope-Modell

Aktueller lokaler Snapshot; Ratewerte können intern über begrenzte Intervalle berechnet werden und schwanken.

### Bewertung und Gegenprobe

Role, Availability Mode, Failover Mode, Connected State, Sync State, Queue MB, Rate und Zeitmarken kombinieren. Queue/Rate liefert eine grobe Abarbeitungszeit nur bei stabiler Rate.

### Typische Fehlinterpretation

`SYNCHRONIZED` bedeutet nicht null Latenz oder lesbare Secondary. Queuegröße allein ohne Trend und Workloadrate ist keine Prognose.

### Folgeanalyse

`USP_AvailabilityDeepAnalysis`, Current Log/I/O und externe Cluster-/Netzwerktelemetrie.

[Technische Detailbeschreibung](../07_Infrastructure.md#4-monitorusp_availabilitygroups)
