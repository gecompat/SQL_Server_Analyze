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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche groben Waitkategorien dominierten historisch je Query-Store-Plan?

### Technischer Hintergrund

Query Store ordnet konkrete Waittypen Kategorien zu und speichert Total/Avg/Min/Max je Plan, Intervall und Execution Type. Es erfasst Waits während Queryausführung, nicht Compile-Waits. Der Frameworkcode mittelt gespeicherte Intervallmittelwerte ungewichtet und summiert vollständig einbezogene Überlappungsintervalle.

### Datenkette

`sys.database_query_store_options`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats_interval`, `sys.query_store_wait_stats`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierte Waitkategorien innerhalb Retention und aktivem Wait Capture; datenbank-/planbezogen.

### Bewertung und Gegenprobe

Total, Max, Recorded Rows, Execution Type und Runtime-Ausführungen korrelieren. Kategorien priorisieren den Troubleshootingpfad, liefern aber keinen konkreten Blocker oder Wait Resource.

### Typische Fehlinterpretation

`RecordedRows` sind Messzeilen, keine Waitanzahl. Die Average-Spalte ist kein execution-weighted Gesamtdurchschnitt.

### Folgeanalyse

Die kanonischen [Query-Store-Wait-Details](../05_Query_Store.md#3-monitorusp_querystorewaitstats) und das [Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) verwenden; historische Kategorien bei Bedarf mit Current Waits und Requests validieren.

[Technische Detailbeschreibung](../05_Query_Store.md#3-monitorusp_querystorewaitstats)
