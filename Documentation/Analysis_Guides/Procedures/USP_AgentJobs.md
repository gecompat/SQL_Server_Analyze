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

[Technische Detailbeschreibung](../07_Infrastructure.md#2-monitorusp_agentjobs)
