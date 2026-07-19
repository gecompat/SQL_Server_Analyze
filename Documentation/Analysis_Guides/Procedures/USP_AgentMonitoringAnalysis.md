# [monitor].[USP_AgentMonitoringAnalysis]

**Bereich:** Infrastruktur  
**Zweck:** Verknüpft Jobprobleme mit Alerts, Operatoren und Database Mail.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis]
      @HistoryHours = 24,
      @MitJobStatus = 1,
      @MitDatabaseMail = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Jobproblem, Alert, Operator, Mailstatus oder normalisierten Finding.

## So lesen

Jobfehler, Alertkonfiguration, Operatorerreichbarkeit und Mailpfad getrennt prüfen und anschließend verbinden.

## Warum kann das problematisch sein?

Ein Fehler kann unbemerkt bleiben, wenn Alert, Operator oder Mailpfad fehlt.

## Wann ist es kein Problem?

Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert.

## Beispiel und Folgeschritt

Kritischer Job schlägt wiederholt fehl, aber kein aktiver Operator ist erreichbar: höheres Betriebsrisiko als der Jobfehler allein. Jobdetails und Monitoringprozess prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?

### Technischer Hintergrund

Die Procedure verbindet Job-/Step-/Schedule-/Historyanalyse mit Alerts, Operators und Database Mail-/Notificationkontext. Laufzeitanomalien benötigen historische Vergleichswerte; Notifications benötigen korrekt verknüpfte Operator-/Mailkonfiguration.

### Datenkette

`msdb.dbo.agent_datetime`, `msdb.dbo.sysalerts`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysmail_allitems`, `msdb.dbo.sysnotifications`, `msdb.dbo.sysoperators`, `msdb.dbo.sysschedules`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Konfigurationssnapshot plus begrenzte Ausführungshistorie.

### Bewertung und Gegenprobe

Fehlerhäufigkeit, letzter/aktueller Lauf, typische Dauer, Schedulemiss, Retry, Alertbedingungen, Operatorzeiten und Mailstatus korrelieren. Kritische Jobs nach Funktion priorisieren.

### Typische Fehlinterpretation

Keine Mail bedeutet nicht kein Fehler und ein erfolgreicher Mailtest nicht funktionierende Jobnotification. P95-/Baselinewerte sind bei wenigen Läufen schwach.

### Folgeanalyse

Agent Jobs, Jobstepoutput, Database Mail Logs und Current State.

[Technische Detailbeschreibung](../07_Infrastructure.md#11-monitorusp_agentmonitoringanalysis)
