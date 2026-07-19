# [monitor].[USP_CriticalEngineEvents]

**Bereich:** Server Health  
**Zweck:** Liest schwere Engine-Ereignisse aus system_health und optionalen Diagnosequellen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CriticalEngineEvents]
      @VonUtc = DATEADD(HOUR, -24, SYSUTCDATETIME()),
      @MitEventXml = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem erfassten Engine-Ereignis; SourceStatus beschreibt die Verfügbarkeit der Quelle.

## So lesen

Eventtyp, Severity, Zeit, Quelle, Wiederholung und Begleitsymptome vergleichen.

## Warum kann das problematisch sein?

Schwere Fehler, Schedulerprobleme oder Dumps können Engine-, Hardware- oder I/O-Risiken anzeigen.

## Wann ist es kein Problem?

Ein einzelnes altes Ereignis kann bereits behoben sein; aktuelle Wiederholung entscheidet über Dringlichkeit.

## Beispiel und Folgeschritt

Mehrere Severity-20+-Fehler in kurzer Zeit plus suspect pages sind deutlich kritischer als ein einzelnes altes Ereignis. Error Log, Integrität und Infrastruktur prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche kritischen Engineereignisse sind in system_health, Ring Buffers oder Diagnostikquellen erhalten?

### Technischer Hintergrund

`system_health` erfasst ausgewählte Errors, Scheduler-/Memory-/Connectivity-/Deadlock- und Diagnoseereignisse. Ring Buffers/`sp_server_diagnostics` liefern Component States und begrenzte Historie. Event XML/Datafelder sind versionsabhängig.

### Datenkette

`sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_server_diagnostics`.

### Zeit- und Scope-Modell

Nur erhaltene Ereignisse seit Session-/Engine-/Rollovergrenze; aktueller Diagnostikstatus.

### Bewertung und Gegenprobe

Eventtyp, Severity/State, Timestamp, Component, Wiederholung und gleichzeitige Errorlog/OS/Clusterereignisse korrelieren. Scheduler non-yielding, Memory Error oder I/O Stall unterschiedlich behandeln.

### Typische Fehlinterpretation

Keine Zeile ist keine Entwarnung. system_health ist bewusst begrenzt und kann Rollover/Targets verlieren.

### Folgeanalyse

XE Target Runtime/Read Events, Errorlog, OS/Cluster/Storagediagnostik.

[Technische Detailbeschreibung](../08_Server_Health.md#14-monitorusp_criticalengineevents)
