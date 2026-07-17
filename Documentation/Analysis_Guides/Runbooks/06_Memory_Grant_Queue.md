# Runbook: Memory Grants warten

## Erstaufrufe

```sql
EXEC [monitor].[USP_CurrentMemoryGrants] @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_ServerMemory] @ResultSetArt='CONSOLE';
```

## Lesen

Requested, Granted, Used, Waitzeit, Warteschlangenlänge, DOP, aktuelle Konkurrenz und OS-/SQL-Memory-Pressure.

## Warum

`Granted=0` plus lange `RESOURCE_SEMAPHORE`-Wartezeit bedeutet, dass die Query noch nicht mit ihrer Hauptarbeit beginnen konnte.

## Gegenprobe

Request/Plan über `USP_CurrentRequests` und `USP_ShowplanAnalysis`; Estimate/Actual und Memory Grant Feedback prüfen.

## Nicht tun

Nicht automatisch max server memory erhöhen. Konkurrenz, Schätzfehler, DOP und übergroße Grants prüfen.
