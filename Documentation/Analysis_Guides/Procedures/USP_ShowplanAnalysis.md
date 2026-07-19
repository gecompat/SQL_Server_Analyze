# [monitor].[USP_ShowplanAnalysis]

**Bereich:** Plan Cache und Showplan  
**Zweck:** Extrahiert Statements, Warnungen, Objekte, Statistiken, Operatoren, Kardinalität, Memory und Parameter aus Plan-XML.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ShowplanAnalysis]
      @QueryHash = 0x0102030405060708,
      @AnalyseModus = 'GEZIELT',
      @MaxAnalyseobjekte = 5,
      @ResultSetArt = 'CONSOLE';
```

Nur synthetischer Beispielhash; echten Hash ausschließlich zur Laufzeitanalyse verwenden, nicht in Repositorydokumentation übernehmen.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Statement, Finding, Missing-Index-Element, Objekt, Statistik, Operator, Kardinalitätsvergleich, Grant oder Parameter.

## So lesen

Statement → Warnungen → Operatoren → absolute Estimate/Actual-Werte → Memory → Parameter. Absolute Zeilenmengen vor Ratios lesen.

## Warum kann das problematisch sein?

Große Estimate-/Actual-Abweichungen können ungeeignete Joinarten, Grants und Zugriffspfade verursachen. Spills zeigen Auslagerung nach TempDB.

## Wann ist es kein Problem?

Ratio 10 bei 1 zu 10 Zeilen ist meist weniger relevant als Ratio 10 bei 10 Mio. zu 100 Mio. Zeilen.

## Beispiel und Folgeschritt

Estimate 1, Actual 10 Mio. kann Nested Loops oder einen kleinen Grant kollabieren lassen. Statistik, Parameter, Query Store, Index und Memory prüfen.

## Eigenlast

XML-XQuery ist CPU-intensiv. Scope, Zeit- und Objektbudget klein halten.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Operatoren, Schätzungen, Warnungen, Objekte, Statistiken und Optimizerhinweise enthält ein Showplan?

### Technischer Hintergrund

Showplan XML modelliert RelOp-Baum, Estimated Rows/Cost, Predicate, Object/Index, Statistics, Memory Grant, Parallelism und Warnings. Cached/Query-Store-Pläne sind typischerweise Estimated-/Compilepläne; Actual Rows existieren nur in tatsächlichen Ausführungsplänen beziehungsweise entsprechenden Runtimefeatures.

### Datenkette

`master.sys.databases`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Planstand zum Compile-/Capturezeitpunkt; zugrunde liegende Daten/Statistiken können inzwischen geändert sein.

### Bewertung und Gegenprobe

Operatorfluss von unten nach oben, Estimated vs Actual sofern vorhanden, Join-/Accessmethode, Predicate, Spills, Conversions, Missing Index und Memory/Parallelism zusammen lesen. Warnung plus Runtimewirkung priorisieren.

### Typische Fehlinterpretation

Estimated Cost ist keine gemessene Zeit und zwischen unabhängigen Servern/CE-Kontexten nicht absolut vergleichbar. Missing-Index-XML ist keine fertige DDL.

### Folgeanalyse

Statistics Distribution, Query Store Runtime/Regression und reale Laufzeitmessung.

[Technische Detailbeschreibung](../04_Plan_Cache.md#5-monitorusp_showplananalysis)
