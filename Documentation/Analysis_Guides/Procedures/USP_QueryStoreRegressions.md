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

[Technische Detailbeschreibung](../05_Query_Store.md#5-monitorusp_querystoreregressions)
