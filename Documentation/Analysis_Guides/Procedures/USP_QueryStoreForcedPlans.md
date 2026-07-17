# [monitor].[USP_QueryStoreForcedPlans]

**Bereich:** Query Store  
**Zweck:** Inventarisiert erzwungene Pläne und Plan-Forcing-Fehler.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMitFehler = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query-Store-Plan mit Forcingmetadaten.

## So lesen

`IsForcedPlan`, Forcing Type, Failure Count/Reason, letzte Ausführung, Engineversion und Compatibility gemeinsam lesen.

## Warum kann das problematisch sein?

Force-Fehler bedeuten, dass die gewünschte Bindung nicht zuverlässig angewendet wird. Ein alter Forced Plan kann neue Optimizerverbesserungen verhindern.

## Wann ist es kein Problem?

Ein fehlerfrei erzwungener Plan mit stabiler Performance kann bewusste Risikokontrolle sein.

## Beispiel und Folgeschritt

50 Force-Fehler plus aktuelle Regression ist dringender als ein stabiler alter Forced Plan ohne Fehler. Runtimevergleich, Plan Changes und Rücknahmepfad prüfen.

[Technische Detailbeschreibung](../05_Query_Store.md#6-monitorusp_querystoreforcedplans)
