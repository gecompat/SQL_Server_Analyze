# [monitor].[USP_PlanDetails]

**Bereich:** Plan Cache  
**Zweck:** Löst gezielte Plan-Kandidaten auf und liefert Attribute sowie Compile-, Last-Actual- oder Live-Plan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanDetails]
      @SessionIds = N'57',
      @MitCompilePlan = 1,
      @MitLastActualPlan = 0,
      @MitLivePlan = 0,
      @ResultSetArt = 'CONSOLE';
```

Die Session-ID ist vollständig synthetisch. Alternativ gezielt mit vorhandenem Plan Handle oder Query Hash arbeiten; breite Läufe vermeiden.

## Eine Zeile bedeutet

Kandidaten-, Attribut- und Planresultsets besitzen unterschiedliche Granularität: Kandidat, Attribut je Kandidat beziehungsweise Planquelle je Kandidat.

## So lesen

Kandidatenidentität zuerst, danach Cache-Key-Attribute und schließlich Planquelle unterscheiden: Compile, Last Actual oder Live.

## Warum kann das problematisch sein?

Abweichende Cache-Key-Attribute können mehrere Handles erzeugen. Actual-Pläne können große Schätzfehler, Spills und reale Zeilenmengen sichtbar machen.

## Wann ist es kein Problem?

Compile-Pläne enthalten nur Schätzungen. Fehlende Actualwerte sind daher kein Queryfehler.

## Beispiel und Folgeschritt

Identischer Text mit unterschiedlichen `set_options` erklärt getrennte Cacheeinträge. Danach `USP_ShowplanAnalysis` oder manuellen Planvergleich verwenden.

[Technische Detailbeschreibung](../04_Plan_Cache.md#4-monitorusp_plandetails)
