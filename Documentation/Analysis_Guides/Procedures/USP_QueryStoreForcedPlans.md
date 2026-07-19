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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Pläne werden erzwungen, funktionieren sie technisch und sind sie noch betrieblich begründet?

### Technischer Hintergrund

Query Store Plan Forcing beeinflusst die Planwahl über gespeicherte Planrepräsentation. Metadaten enthalten Forcing Type, Failure Count/Reason, Compile-/Executionzeit und Version. Schema-/Index-/Engineänderungen können Forcing verhindern oder seine Qualität verändern.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Forcingstatus plus persistierter Planlebenszyklus.

### Bewertung und Gegenprobe

Fehler, letzte Nutzung, Runtime im Vergleich zu Alternativen, Engine-/Compatibilitywechsel und Owner/Reviewdatum prüfen. Stabilität kann wichtiger als minimaler Durchschnitt sein.

### Typische Fehlinterpretation

`IsForcedPlan=1` beweist nicht, dass der Plan aktuell benutzt oder optimal ist. `0` Fehler beweist nur technischen Erfolg, nicht fachlichen Nutzen.

### Folgeanalyse

Runtime/Regressions/PlanChanges; Änderung nur mit Rollback- und Monitoringplan.

[Technische Detailbeschreibung](../05_Query_Store.md#6-monitorusp_querystoreforcedplans)
