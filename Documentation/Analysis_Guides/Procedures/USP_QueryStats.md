# [monitor].[USP_QueryStats]

**Bereich:** Plan Cache  
**Zweck:** Rangiert aktuell gecachte Statements nach CPU, Dauer, I/O, Ausführungen, Grants, Spills oder Zeilen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStats]
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 50,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer aktuell gecachten Statementinstanz. Derselbe logische Querytext kann durch unterschiedliche Handles, SET-Optionen oder Pläne mehrfach erscheinen.

## So lesen

Zuerst Cachefenster (`CreationTime`, `LastExecutionTime`) und `ExecutionCount`, danach Total-, Average-, Max- und Lastwerte getrennt betrachten.

## Warum kann das problematisch sein?

Totalwerte zeigen Gesamtauswirkung, Maxwerte Ausreißer und Averagewerte systematische Kosten. Hohe Reads bei wenigen Ergebniszeilen können ineffizienten Zugriff anzeigen.

## Wann ist es kein Problem?

Eine einmalige administrative Query darf hohe Maxwerte besitzen, ohne die normale Workload wesentlich zu belasten.

## Beispiel und Folgeschritt

Eine Million Ausführungen zu je 2 ms verursachen mehr Gesamtlast als eine einmalige 10-Minuten-Query. Query Hash, Plan Details, Showplan und Query Store prüfen.

## Leere Ausgabe

Der Plan Cache ist flüchtig. Recompile, Eviction oder Restart können relevante Queries entfernen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche aktuell gecachten Statements verursachten kumulativ oder durchschnittlich CPU, Dauer, Reads und Writes?

### Technischer Hintergrund

`sys.dm_exec_query_stats` liefert pro gecachtem Statement Ausführungszahl und Total-/Last-/Min-/Maxwerte. SQL Text und Statementoffsets identifizieren den Ausschnitt; Planhandle/Plan XML beschreiben die gecachte Planform.

### Datenkette

`master.sys.databases`, `sys.dm_exec_cached_plans`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Kumulativ seit Cacheeintrag. Erstellung/letzte Ausführung und Engine-Start begrenzen das Fenster.

### Bewertung und Gegenprobe

Totalwerte finden Gesamtkosten, Durchschnittswerte teure Einzelausführungen. Execution Count, Cachealter, Rowcount und Last Execution immer mitlesen.

### Typische Fehlinterpretation

Ein kleiner Totalwert kann nur kurzen Cachelebenszyklus bedeuten. Durchschnitt verdeckt Ausreißer und Parameter Sensitivity.

### Folgeanalyse

Query Hash, Showplan und Query Store für persistierte Historie.

[Technische Detailbeschreibung](../04_Plan_Cache.md#1-monitorusp_querystats)
