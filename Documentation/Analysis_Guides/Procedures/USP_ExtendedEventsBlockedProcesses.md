# [monitor].[USP_ExtendedEventsBlockedProcesses]

**Bereich:** Extended Events  
**Zweck:** Liest historische Blocked-Process-Reports und zerlegt blockierte sowie blockierende Prozesse.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses]
      @Quelle = 'AUTO',
      @VonUtc = DATEADD(HOUR, -1, SYSUTCDATETIME()),
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Summary-Zeile = ein Report; Process-Zeile = blockierte oder blockierende Prozessdarstellung innerhalb dieses Reports.

## So lesen

Konfigurierten Threshold, Waitdauer, Blocker/Blocked, Ressource, Statements und Wiederholungen über Zeit vergleichen.

## Warum kann das problematisch sein?

Wiederholte Reports derselben Kette zeigen persistierendes Blocking statt eines kurzen Snapshots.

## Wann ist es kein Problem?

Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein.

## Beispiel und Folgeschritt

Alle fünf Sekunden derselbe Root Blocker über zwei Minuten: starke Evidenz. Live mit `USP_CurrentBlocking` und `USP_CurrentTransactions` korrelieren.

## Leere Ausgabe

Threshold 0, fehlende XE-Konfiguration oder abgelaufene Retention erlauben keine Entwarnung.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Blockings überschritten den konfigurierten Threshold und wurden als Reports erfasst?

### Technischer Hintergrund

`blocked_process_report` entsteht nur bei positivem Blocked Process Threshold und passender XE-Erfassung. XML enthält Blocked/Blocking Process, Waitresource, Lockmode und SQL-/Inputbufferkontext zum Reportzeitpunkt. Lange Blockings können mehrere Reports erzeugen.

### Datenkette

`sys.configurations`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_events`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`.

### Zeit- und Scope-Modell

Historische Thresholdereignisse während aktiver Capture; keine lückenlose Lockhistorie.

### Bewertung und Gegenprobe

Dauer/Anzahl, Rootblocker, offene Transaktion, Ressourcenmuster und wiederholte Reports derselben Kette korrelieren. Mehrere Reports nicht ungeprüft als verschiedene Vorfälle zählen.

### Typische Fehlinterpretation

Blocking unter Threshold, vor Sessionstart oder nach Rollover fehlt. Reportzeit ist nicht zwingend Beginn/Ende der Blockierung.

### Folgeanalyse

Current Blocking/Transactions bei Reproduktion; Deadlockanalyse bei Zyklen.

[Technische Detailbeschreibung](../06_Extended_Events.md#4-monitorusp_extendedeventsblockedprocesses)
