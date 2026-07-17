# [monitor].[USP_ServerNuma]

**Bereich:** Server Health  
**Zweck:** Zeigt NUMA-Nodes, Schedulerverteilung und Memory-Node-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerNuma]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem NUMA-/Memory-Node oder einem Scheduler.

## So lesen

Schedulerzahl, Online-/Idle-Zustand, Memory Node, Foreign Memory und Last je Node vergleichen.

## Warum kann das problematisch sein?

Persistente Asymmetrie kann lokale CPU-Engpässe und Remote-Memory-Zugriffe begünstigen.

## Wann ist es kein Problem?

Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar.

## Beispiel und Folgeschritt

Ein Node dauerhaft voll, anderer nahezu idle und Sessions konzentriert: Affinity, Verbindungslast, Soft-NUMA und Schedulerwaits prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#2-monitorusp_servernuma)
