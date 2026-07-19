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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Attribute, Texte, Statements und Planinformationen gehören zu einem konkreten Handle?

### Technischer Hintergrund

SQL-/Planhandles referenzieren flüchtige Cacheobjekte. Plan Attributes enthalten DBID, Set Options, User-/Languagekontext und weitere Cachekeyeinflüsse. Unterschiedliche SET Options können separate Pläne derselben Textform erzeugen.

### Datenkette

`sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml`, `sys.dm_exec_query_stats`, `sys.dm_exec_requests`, `sys.dm_exec_sql_text`, `sys.dm_exec_text_query_plan`.

### Zeit- und Scope-Modell

Momentaufnahme eines Cacheeintrags. Handle kann zwischen Auswahl und Detailabruf evicted werden.

### Bewertung und Gegenprobe

Plan Attributes, Statementoffset, Creation/Last Execution, Use Count und XML gemeinsam lesen. Set-Option-Unterschiede können scheinbare Planverdoppelung erklären.

### Typische Fehlinterpretation

Ein Handle ist keine persistente Referenz und darf nicht langfristig gespeichert werden, ohne Gültigkeitsprüfung.

### Folgeanalyse

`USP_ShowplanAnalysis`; Query Store IDs für dauerhaftere Korrelation.

[Technische Detailbeschreibung](../04_Plan_Cache.md#4-monitorusp_plandetails)
