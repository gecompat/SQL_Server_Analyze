# [monitor].[USP_AgentJobs]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Jobs, Schritte, Laufstatus, Historie, Dauer und Fehler.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentJobs]
      @NurProblematisch = 1,
      @LongRunningMinutes = 60,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Job, einem Jobschritt, einer Historienzeile oder einem aktuellen Laufzustand.

## So lesen

Enabled, aktueller Laufstatus, letzter Outcome, Dauer, nächste Ausführung und Schrittfehler gemeinsam lesen.

## Warum kann das problematisch sein?

Wiederholte Fehler oder stark verlängerte Laufzeiten können Backups, Ladeprozesse und Wartungsfenster gefährden.

## Wann ist es kein Problem?

Ein Full Backup oder eine große Wartung darf lange laufen, wenn dies dem historischen Normalwert und Wartungsfenster entspricht.

## Beispiel und Folgeschritt

90 Minuten aktuelle Dauer bei 20 Minuten Normalwert und blockierten Folgeschritten: echte Abweichung. Schrittoutput, Blocking, I/O und Historie prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Jobs sind aktiviert, geplant, aktuell laufend oder zuletzt fehlgeschlagen beziehungsweise ungewöhnlich langsam?

### Technischer Hintergrund

`msdb.dbo.sysjobs`, Steps, Schedules, Job Activity und History bilden Definition, aktuelle Instanzaktivität und vergangene Outcomes. `sysjobhistory` speichert Job-/Stepzeilen mit integercodierten Datum-/Zeit-/Dauerwerten; laufende Aktivität liegt in `sysjobactivity`.

### Datenkette

`master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysjobsteps`, `msdb.dbo.sysschedules`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Konfigurationssnapshot plus aufbewahrte History. Agentrestart erzeugt neue Sessionkontexte; Cleanup begrenzt Historie.

### Bewertung und Gegenprobe

Jobstatus, aktueller Step, Run Requested/Start/Stop, Retry, letzte Outcomes, Schedule und typische Laufzeit zusammen lesen. Jobgesamtzeile und Stepfehler unterscheiden.

### Typische Fehlinterpretation

`LastRunOutcome=Succeeded` kann einen später aktuell laufenden/steckenden Lauf überdecken. History kann abgeschnitten sein; lange Dauer muss mit Workloadfenster verglichen werden.

### Folgeanalyse

`USP_AgentMonitoringAnalysis`, Current Requests/Blocking und Jobstep-/Logoutput.

[Technische Detailbeschreibung](../07_Infrastructure.md#2-monitorusp_agentjobs)
