# [monitor].[USP_QueryStoreRuntimeStats]

**Bereich:** Query Store  
**Zweck:** Aggregiert historische Laufzeit- und Ressourcenwerte je Query und Plan über Query-Store-Intervalle.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = DATEADD(HOUR, -1, SYSUTCDATETIME()),
      @BisUtc = SYSUTCDATETIME(),
      @Sortierung = 'CPU_TOTAL',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Aggregation je Query, Plan und Ausführungstyp über alle berücksichtigten Runtime-Intervalle. Sie ist keine einzelne Ausführung.

## So lesen

Zeitfenster und Intervalllänge, `ExecutionCount`, Total- und Averagewerte sowie `PlanId` vergleichen.

## Warum kann das problematisch sein?

Mehrere Pläne derselben Query mit stark unterschiedlichen Werten können Regression oder Parameter Sensitivity anzeigen.

## Wann ist es kein Problem?

Hohe Total-CPU bei sehr vielen Ausführungen kann pro Aufruf klein sein. Hohe Average-Dauer bei einer Ausführung ist schwache Evidenz.

## Beispiel und Folgeschritt

Plan A: 10 ms × 100.000; Plan B: 500 ms × 20. B ist pro Aufruf schlechter, A kann aber mehr Gesamtlast erzeugen. Waits, Plan Changes und Showplan prüfen.

## Zeitgrenze

Randintervalle können Messanteile außerhalb des exakten Fensters enthalten.

[Technische Detailbeschreibung](../05_Query_Store.md#2-monitorusp_querystoreruntimestats)
