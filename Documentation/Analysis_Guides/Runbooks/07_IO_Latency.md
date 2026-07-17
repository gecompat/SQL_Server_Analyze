# Runbook: I/O-Latenz ist hoch

## Erstaufrufe

```sql
EXEC [monitor].[USP_CurrentIO] @SampleSeconds=10, @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_CurrentWaits] @SampleSeconds=5, @ResultSetArt='CONSOLE';
```

## Lesen

Sample- statt nur kumulative Latenz, Operationen, Bytes, Dateiart, PAGEIOLATCH-/WRITELOG-Waits und betroffene Requests.

## Warum

Hohe Latenz bei vielen aktuellen Operationen plus passende Waits zeigt unmittelbare Workloadauswirkung.

## Gegenprobe

`USP_DatabaseCapacityAnalysis`, Query Reads, Backup-/Logaktivität und externes Storage-Monitoring.

## Nicht tun

Eine einzelne langsame Operation oder alten kumulativen Durchschnitt nicht als Storageausfall bewerten.
