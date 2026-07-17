# [monitor].[USP_QueryStoreWaitStats]

**Bereich:** Query Store  
**Zweck:** Aggregiert historische Query-Store-Waitkategorien je Query und Plan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = DATEADD(HOUR, -1, SYSUTCDATETIME()),
      @BisUtc = SYSUTCDATETIME(),
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-/Plan-/Waitkategorie-Aggregation über gespeicherte Intervalle. `RecordedRows` ist nicht die Zahl einzelner Waits oder Ausführungen.

## So lesen

Waitkategorie, Totalzeit, Maxwert, Recorded Rows, Query-/Planidentität und Zeitintervalle gemeinsam lesen.

## Warum kann das problematisch sein?

Hohe Totalzeit zeigt kumulative Auswirkung; hoher Maxwert kann einzelne Ausreißer anzeigen. Kategorien sind gröber als Live-Waittypen.

## Wann ist es kein Problem?

Viele Recorded Rows bedeuten viele gespeicherte Messpunkte, nicht automatisch viele Ausführungen.

## Beispiel und Folgeschritt

Lock-Wait dominiert nur ein Intervall: möglicher Burst. Täglich stundenlang dominant: systematisches Problem. Runtime, Planwechsel und bei Reproduktion Live-Blocking prüfen.

[Technische Detailbeschreibung](../05_Query_Store.md#3-monitorusp_querystorewaitstats)
