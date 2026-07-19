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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Varianten derselben normalisierten Queryform und welche Planformen liegen aktuell im Cache?

### Technischer Hintergrund

Grouping nach Query Hash konsolidiert ähnliche Statementtexte; Plan Hash trennt physische Planformen. Aggregationen zeigen Planvielfalt, Lastverteilung und mögliche Ad-hoc-/Parameterisierungsvarianten.

### Datenkette

`sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`.

### Zeit- und Scope-Modell

Nur aktuell gecachte Einträge; verschiedene Creation Times und Evictions.

### Bewertung und Gegenprobe

Plananzahl, Execution Count, Total/Avg-Kosten, Text-/Parameterkontext und Creation Time vergleichen. Mehrere Plan Hashes können legitime Recompile-/SET-/Compatibilitykontexte oder Parameter Sensitivity zeigen.

### Typische Fehlinterpretation

Gleicher Hash garantiert keine fachliche Gleichheit; Hashkollisionen sind theoretisch möglich. Ein fehlender alter Plan ist keine Stabilitätsevidenz.

### Folgeanalyse

Query Store PlanChanges/RuntimeStats und Showplanvergleich.

[Technische Detailbeschreibung](../04_Plan_Cache.md#2-monitorusp_queryhashanalysis)
