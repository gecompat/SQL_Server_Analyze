# Runbook: Availability Group hat Lag

## Erstaufrufe

```sql
EXEC [monitor].[USP_AvailabilityGroups] @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_AvailabilityDeepAnalysis] @ResultSetArt='CONSOLE';
```

## Lesen

Rolle, Availability Mode, Synchronization State, Send Queue, Redo Queue, Lagtrend und Connected State.

## Warum

Wachsende Send Queue weist eher auf Primär-/Transportpfad hin; wachsende Redo Queue eher auf Secondary-I/O/CPU/Redo.

## Gegenprobe

Performance Counter, Storage, Netzwerk, Cluster und Logerzeugungsrate.

## Nicht tun

Kein Failover nur anhand eines einzelnen Queue-Snapshots. RPO, Trend, Datenverlust- und Rollbackrisiko prüfen.
