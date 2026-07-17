# [monitor].[USP_QueryHashAnalysis]

**Bereich:** Plan Cache  
**Zweck:** Aggregiert Cachezeilen je Query Hash und zeigt Planvarianten, Handles und Ressourcen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryHashAnalysis]
      @AnalyseModus = 'TOP',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Hash-Gruppe über die aktuell sichtbaren Cachezeilen. Historisch evictete Varianten fehlen.

## So lesen

`PlanVariantCount`, `PlanHandleCount`, Ausführungen, Cachefenster und Ressourcen der dominanten Varianten vergleichen.

## Warum kann das problematisch sein?

Viele Planvarianten können Parameter Sensitivity oder unterschiedliche Compilekontexte anzeigen. Viele Handles bei gleichem Plan Hash können Cachebloat bedeuten.

## Wann ist es kein Problem?

SET-Optionen, Datenbankkontexte oder bewusstes Recompile können legitime Varianten erzeugen.

## Beispiel und Folgeschritt

Acht Varianten, aber eine verursacht 99 % der CPU: Nicht die Anzahl, sondern die dominante Variante priorisieren. Einzelne Handles mit `USP_PlanDetails`, Historie mit Query Store prüfen.

[Technische Detailbeschreibung](../04_Plan_Cache.md#2-monitorusp_queryhashanalysis)
