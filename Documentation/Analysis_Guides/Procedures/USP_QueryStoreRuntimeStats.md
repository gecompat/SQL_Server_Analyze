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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-/Plan-Kombinationen verursachten im gewählten historischen Fenster Ausführungen, Dauer, CPU, I/O, Memory, TempDB oder Loglast?

### Technischer Hintergrund

Runtime Stats speichern aggregierte Messwerte je Plan, Intervall und Execution Type. Totalwerte entstehen aus Intervallsummen; globale Averagewerte müssen nach Ausführungszahl gewichtet werden, wenn der Code nicht bereits gewichtete Totals verwendet. Query, Plan und Text werden über IDs verbunden, die nur innerhalb der Query-Store-Datenbank eindeutig sind.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats`, `sys.query_store_runtime_stats_interval`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierte, intervalaggregierte Historie innerhalb Retention. Überlappende Randintervalle können vollständig einbezogen sein.

### Bewertung und Gegenprobe

Total und Average stets mit Execution Count, PlanId, Execution Type und Zeitspanne lesen. Hohe Total-CPU bei niedriger Average-CPU ist eine kumulative Optimierungschance; hohe Average-Duration bei niedriger CPU verlangt Wait-/Blocking-/I/O-Kontext.

### Typische Fehlinterpretation

Durchschnittswerte verdecken P95/P99, multimodale Parametergruppen und Ausreißer. Query Store Runtime ist keine Storage-Latenzmessung.

### Folgeanalyse

`USP_QueryStoreWaitStats`, PlanChanges, Regressions und Showplan.

[Technische Detailbeschreibung](../05_Query_Store.md#2-monitorusp_querystoreruntimestats)
