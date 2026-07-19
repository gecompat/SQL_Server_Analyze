# [monitor].[USP_QueryStoreRegressions]

**Bereich:** Query Store  
**Zweck:** Vergleicht zwei Zeitfenster nach Dauer, CPU, Reads, Writes oder Ausführungen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @MinAusfuehrungenJeFenster = 10,
      @MinRegressionProzent = 20,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query mit aggregierter Baseline und aggregiertem Vergleichsfenster. Sie ist kein Vergleich zweier Einzelaufrufe.

## So lesen

Fenstergrenzen, Ausführungsanzahl, absolute Werte, Plananzahl und Prozentänderung gemeinsam lesen.

## Warum kann das problematisch sein?

Eine belastbare Regression bedeutet, dass vergleichbarer Workload im neuen Fenster deutlich mehr Zeit oder Ressourcen benötigt.

## Wann ist es kein Problem?

Große Prozentwerte bei sehr kleiner Stichprobe können durch Parameter, Datenmenge oder Zufall entstehen.

## Kommentiertes Beispiel

100 ms → 150 ms bei je 100.000 Ausführungen: belastbare 50-%-Regression. 1 ms → 10 ms bei je einer Ausführung: 900 %, aber schwache Evidenz.

## Folgeschritt

Plan Changes, Wait Stats und konkrete Parameter-/Plananalyse verwenden. Keine automatische Plan-Forcing-Entscheidung.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Hat sich eine gewählte Metrik zwischen Baseline- und Vergleichsfenster belastbar verschlechtert?

### Technischer Hintergrund

Die Procedure aggregiert zwei nicht überlappende Zeiträume und vergleicht Duration, CPU, Reads, Writes oder Executions. Prozentänderung teilt die absolute Änderung durch den Baselinewert; Baseline nahe null macht Prozent instabil. Intervalle können Fenstergrenzen überlappen.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats`, `sys.query_store_runtime_stats_interval`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Zwei persistierte Query-Store-Fenster innerhalb Retention; Defaultvergleich und abgeleitete Baseline müssen im Wrapperkontext dokumentiert sein.

### Bewertung und Gegenprobe

Baseline/Comparison Executions, PlanCount, absolute Änderung, Prozent, Datenvolumen und Workloadmix gemeinsam lesen. Mindestexecutionzahl passend zur Workload erhöhen.

### Typische Fehlinterpretation

900 Prozent bei je einer Ausführung ist schwache Evidenz. Geänderte Parameter-/Datenmengen können Effizienz- statt Planregression vortäuschen.

### Folgeanalyse

PlanChanges, WaitStats, RuntimeStats und Showplan; kein reflexartiges Planforcing.

[Technische Detailbeschreibung](../05_Query_Store.md#5-monitorusp_querystoreregressions)
