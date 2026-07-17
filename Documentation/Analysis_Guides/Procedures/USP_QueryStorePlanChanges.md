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

[Technische Detailbeschreibung](../05_Query_Store.md#4-monitorusp_querystoreplanchanges)
