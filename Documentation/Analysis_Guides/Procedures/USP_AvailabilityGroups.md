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

[Technische Detailbeschreibung](../07_Infrastructure.md#4-monitorusp_availabilitygroups)
