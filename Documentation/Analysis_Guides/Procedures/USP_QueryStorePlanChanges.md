# [monitor].[USP_QueryStorePlanChanges]

**Bereich:** Query Store  
**Zweck:** Findet Queries mit mehreren Query-Store-Plänen und zeigt Compile- sowie Nutzungsmetadaten.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMehrerePlaene = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Summary-Zeilen entsprechen Queries; Planzeilen entsprechen jeweils einer Query-Store-Plan-ID.

## So lesen

PlanCount, Distinct Plan Hashes, Compile-/Executionzeiten, Engine-/Compatibility-Kontext und Forced-Status vergleichen.

## Warum kann das problematisch sein?

Ein neuer Plan kann andere Kosten, Parallelität oder Zugriffspfade besitzen und zeitlich mit einer Regression zusammenfallen.

## Wann ist es kein Problem?

Mehrere Planzeilen mit demselben Hash oder alte, nicht mehr ausgeführte Pläne sind nicht automatisch relevant.

## Beispiel und Folgeschritt

Vier PlanIds, aber nur zwei Hashes; einer seit Monaten inaktiv. Aktive Varianten mit Runtime Stats, Regressionen und Planvergleich untersuchen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen mehrere gespeicherte Pläne, und wodurch unterscheiden sich deren Lebenszyklus und Compilekontext?

### Technischer Hintergrund

`sys.query_store_plan` speichert PlanId, Plan Hash, Engine Version, Compatibility, Compilezeiten, IsParallel, Forced-Status und Plan XML. Mehrere PlanIds können strukturell gleichen Plan Hash besitzen; Recompile oder Kontextänderung kann neue Zeilen erzeugen.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierter Planbestand innerhalb Query-Store-Retention; Last Execution zeigt Aktivität, nicht dauerhafte Gültigkeit.

### Bewertung und Gegenprobe

PlanCount, DistinctPlanHashCount, Compile-/Executionzeit, Engine/Compatibility, Forced-Status und Runtimewerte je Plan vergleichen. Ein neuer Plan ist erst bei abweichender Wirkung relevant.

### Typische Fehlinterpretation

Mehrere Pläne bedeuten nicht automatisch Parameter Sensitivity oder Regression. Ein alter nie mehr ausgeführter Plan kann historisch, aber aktuell irrelevant sein.

### Folgeanalyse

Runtime Stats je Plan, Regressions, Forced Plans und Showplanvergleich.

[Technische Detailbeschreibung](../05_Query_Store.md#4-monitorusp_querystoreplanchanges)
