# [monitor].[USP_QueryStoreAnalysis]

**Bereich:** Query Store, Orchestrator  
**Zweck:** Orchestriert Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints und IQP.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @MitStatus = 1,
      @MitRuntimeStats = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Datenbank, Query/Plan-Aggregat, Waitkategorie, Plan, Hint oder IQP-Signal.

## So lesen

Statuschild zuerst, dann nur aktivierte Children. Zeitfenster und Wrappersemantik der Regressionen beachten.

## Warum kann das problematisch sein?

Ein historisches Ergebnis kann durch Capture, Retention oder Wrapperfenster falsch eingeordnet werden. Der Wrapper übergibt das Fenster als Vergleichsfenster; die Baseline liegt davor.

## Wann ist es kein Problem?

Deaktivierte Children fehlen absichtlich.

## Beispiel und Folgeschritt

Letzte Stunde als Eingabefenster bedeutet: Vergleich letzte Stunde, Baseline die Stunde davor. Auffälliges Child mit QueryId/Hash und engem Zeitraum wiederholen.

[Technische Detailbeschreibung](../05_Query_Store.md#9-monitorusp_querystoreanalysis)
