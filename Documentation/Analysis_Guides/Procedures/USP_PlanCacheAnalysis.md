# [monitor].[USP_PlanCacheAnalysis]

**Bereich:** Plan Cache, Orchestrator  
**Zweck:** Orchestriert Query Stats, Query Hash, Cache Health und optional Showplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats = 1,
      @ResultSetArt = 'CONSOLE';
```

Showplan erst nach Kandidatenpriorisierung aktivieren.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Cachezeile, Query-Hash-Gruppe, Cacheaggregation oder Planbestandteil.

## So lesen

Modulstatus und Reihenfolge beachten: Query Stats findet Kandidaten, Query Hash erklärt Varianten, Health bewertet Cache, Showplan erklärt Planinhalt.

## Warum kann das problematisch sein?

Breite XML-Analyse kann selbst CPU erzeugen und sehr viele Findings ohne Priorisierung liefern.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich; der Default ist bewusst leichtgewichtig.

## Beispiel und Folgeschritt

Erst Top-CPU bestimmen, dann nur wenige relevante Pläne parsen. Historische Relevanz anschließend im Query Store prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Plan-Cache-Perspektiven sollen gemeinsam für Triage oder Deep Analysis ausgeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Query Stats, Hashgruppen, Cache Health, Details und Showplanpfade. Plan-XML und breite Cache-Scans erhöhen CPU, Memorytransfer und Resultsetgröße.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in den aufgerufenen Childmodulen.

### Zeit- und Scope-Modell

Nicht atomarer Snapshot des flüchtigen Cache; Children können unterschiedliche Kandidatenmengen sehen.

### Bewertung und Gegenprobe

Status/Partial zuerst, dann von Gesamtkosten zu Hash/Plan und erst danach XML-Deep-Dive. Scope und MaxRows eng halten.

### Typische Fehlinterpretation

Ein leerer Detailpfad kann durch Eviction zwischen Childaufrufen entstehen, nicht durch fehlende frühere Ausführung.

### Folgeanalyse

Historische Fragen mit Query Store; aktuelle Ressourcenauswirkung mit Current State.

[Technische Detailbeschreibung](../04_Plan_Cache.md#6-monitorusp_plancacheanalysis)
