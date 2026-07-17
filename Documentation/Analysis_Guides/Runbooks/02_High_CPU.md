# Runbook: CPU ist dauerhaft hoch

## Erstaufrufe

```sql
EXEC [monitor].[USP_CurrentRequests] @Sortierung='CPU', @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_QueryStats] @Sortierung='CPU_TOTAL', @MaxZeilen=50, @ResultSetArt='CONSOLE';
```

## Lesen

Aktuelle CPU, Elapsed Time, Reads, DOP, Ausführungszahl, Total-/Average-CPU und Query-/Plan-Hash vergleichen.

## Warum

- hohe CPU + hohe Reads + wenige Ergebniszeilen → möglicher ineffizienter Zugriff,
- niedrige Average-CPU + sehr viele Ausführungen → kumulative Kleinstquerylast,
- hohe CPU nur in einem kurzen geplanten Report → möglicherweise normal.

## Gegenprobe

`USP_QueryHashAnalysis`, `USP_ShowplanAnalysis`, Query Store Runtime Stats und Server-CPU-/NUMA-Kontext.

## Nicht tun

MAXDOP, Cost Threshold oder Indizes nicht allein anhand eines einzelnen Parallelitätswaits ändern.
