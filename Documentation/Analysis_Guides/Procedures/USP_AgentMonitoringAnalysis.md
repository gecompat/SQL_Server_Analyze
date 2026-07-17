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

[Technische Detailbeschreibung](../07_Infrastructure.md#12-monitorusp_agentmonitoringanalysis)
