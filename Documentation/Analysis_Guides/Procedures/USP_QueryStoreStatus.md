# [monitor].[USP_QueryStoreStatus]

**Bereich:** Query Store  
**Zweck:** Zeigt Zustand, Capture, Retention, Speicher, Cleanup und Wait-Capture je Datenbank.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreStatus]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Store-Datenbank. Status- und Warnresultsets besitzen separate Zeilen.

## So lesen

`ActualStateDesc`, Readonly Reason, Storage Used, Capture Mode, Cleanup, Interval Length und Wait Capture prüfen.

## Warum kann das problematisch sein?

Read-only, voller Speicher oder Capture-Regeln können Historienlücken erzeugen. Fehlende Queries sind dann keine Entwarnung.

## Wann ist es kein Problem?

Capture Mode AUTO lässt billige oder seltene Queries absichtlich aus.

## Beispiel und Folgeschritt

Leeres Waitresultset plus Wait Capture OFF ist erwartbar. Erst bei geeignetem Status Runtime-, Wait- oder Plananalyse starten.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist Query Store aktiviert, schreibfähig, ausreichend dimensioniert und für den gewünschten Evidenztyp konfiguriert?

### Technischer Hintergrund

`sys.database_query_store_options` trennt gewünschten und tatsächlichen Zustand, Operation Mode, Capture Mode, Interval Length, Retention, Current/Max Size, Cleanup und Wait Stats Capture. READ_ONLY kann aus administrativer Konfiguration oder internen Gründen wie Größenlimit entstehen.

### Datenkette

`sys.database_query_store_options`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Zustand je ausgewählter Datenbank. Status sagt nichts über bereits gelöschte oder nie erfasste Historie.

### Bewertung und Gegenprobe

Actual vs Desired State, Readonly Reason, Current/Max Size, Stale Query Threshold, Cleanup und Capture Mode zusammen lesen. Waitanalyse benötigt aktiviertes Wait Capture.

### Typische Fehlinterpretation

`READ_WRITE` beweist weder Vollständigkeit noch repräsentative Capture-Auswahl. `OFF` zum Analysezeitpunkt erklärt nicht immer, ob frühere Daten noch vorhanden sind.

### Folgeanalyse

Vor allen Query-Store-Fachanalysen; bei Problemen Konfiguration/Storage und Capturepolicy prüfen.

[Technische Detailbeschreibung](../05_Query_Store.md#1-monitorusp_querystorestatus)
