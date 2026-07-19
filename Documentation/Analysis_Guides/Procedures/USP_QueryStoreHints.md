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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query Store Hints greifen auf Queries ein, und schlagen sie fehl oder überdecken sie inzwischen bessere Optimizerentscheidungen?

### Technischer Hintergrund

Query Store Hints hängen an QueryId und injizieren unterstützte Queryoptionen ohne Textänderung. Source, Hinttext, Failure Reason/Count und Replica Group liefern Governance-/Fehlerkontext. Verfügbarkeit ist versionsabhängig.

### Datenkette

`sys.query_store_query`, `sys.query_store_query_hints`, `sys.query_store_query_text`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller persistierter Hintbestand; QueryId ist datenbanklokal.

### Bewertung und Gegenprobe

Hint, Zielquery, Failure Count, letzte Runtime, Planveränderung, Version/Compatibility und Begründung korrelieren. Jede Intervention benötigt Owner, Reviewdatum und Rücknahmepfad.

### Typische Fehlinterpretation

Fehlerfrei bedeutet nicht sinnvoll. Nach Upgrade kann ein alter Hint Adaptive/IQP-Verbesserungen verhindern.

### Folgeanalyse

RuntimeStats, Regressions, PlanChanges und Change-Dokumentation.

[Technische Detailbeschreibung](../05_Query_Store.md#7-monitorusp_querystorehints)
