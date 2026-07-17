# [monitor].[USP_ExtendedEventsAnalysis]

**Bereich:** Extended Events, Orchestrator  
**Zweck:** Orchestriert Inventar, Targetruntime, generische Events, Deadlocks und Blocked Processes.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsAnalysis]
      @MitSessionInventar = 1,
      @MitTargetRuntime = 0,
      @MitEvents = 0,
      @MitDeadlocks = 0,
      @MitBlockedProcesses = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Session, Target, Event, Deadlock, Prozess, Ressource oder Blocked-Process-Report.

## So lesen

Inventar und Source-/Targetstatus vor Ereignisparsern lesen. Childstatus bestimmt, ob leere Fachdaten interpretierbar sind.

## Warum kann das problematisch sein?

Deadlock- oder Blockinganalyse ohne verlässliche Quelle kann falsche Entwarnung erzeugen.

## Wann ist es kein Problem?

Nicht aktivierte Event-Children fehlen absichtlich.

## Beispiel und Folgeschritt

Session gestoppt und Deadlockresultset leer bedeutet „keine Evidenz erfasst“, nicht „keine Deadlocks“. Vorhandene XEL-Dateien oder Konfiguration prüfen.

[Technische Detailbeschreibung](../06_Extended_Events.md#6-monitorusp_extendedeventsanalysis)
