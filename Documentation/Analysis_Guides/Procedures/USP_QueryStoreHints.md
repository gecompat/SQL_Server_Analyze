# [monitor].[USP_QueryStoreHints]

**Bereich:** Query Store  
**Zweck:** Inventarisiert Query Store Hints, Herkunft und Anwendungsfehler.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query Store Hint für eine Query und gegebenenfalls Replica-Gruppe.

## So lesen

Hinttext, Quelle, Failure Count/Reason, Queryidentität und letzte Relevanz gemeinsam lesen.

## Warum kann das problematisch sein?

Ein Hint begrenzt Optimizerfreiheit und kann nach Daten-, Schema- oder Versionsänderungen schädlich werden.

## Wann ist es kein Problem?

Ein dokumentierter, getesteter Hint kann eine bewusste Maßnahme sein.

## Beispiel und Folgeschritt

Fehlerfrei angewendet bedeutet nur „wirksam“, nicht „weiterhin nützlich“. Runtime, Regression, Plan Changes, Owner und Reviewdatum prüfen.

[Technische Detailbeschreibung](../05_Query_Store.md#7-monitorusp_querystorehints)
