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

[Technische Detailbeschreibung](../05_Query_Store.md#1-monitorusp_querystorestatus)
