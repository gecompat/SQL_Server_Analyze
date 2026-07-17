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

[Technische Detailbeschreibung](../04_Plan_Cache.md#5-monitorusp_showplananalysis)
