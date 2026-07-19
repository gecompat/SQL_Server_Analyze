# [monitor].[USP_AgentStatus]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Plattformunterstützung, Dienststatus und SQL-Agent-Konfiguration.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentStatus]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen Dienst-, Plattform- oder Konfigurationsaspekt des SQL Agents.

## So lesen

Plattformunterstützung, Dienststatus, Startmodus und Agentkonfiguration unterscheiden.

## Warum kann das problematisch sein?

Ein gestoppter Agent verhindert geplante Backups, Wartung, ETL und Alerts.

## Wann ist es kein Problem?

Auf Plattformen ohne klassischen SQL Agent oder bei bewusst externem Scheduling ist Nichtverfügbarkeit erwartbar.

## Beispiel und Folgeschritt

Agent gestoppt auf einer Instanz mit geplanten Logbackups: kritisch. Auf einer agentlosen Plattform: alternativen Scheduler dokumentieren. Danach Jobs und Monitoringpfad prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist SQL Server Agent auf dieser Plattform vorhanden und läuft der Dienst?

### Technischer Hintergrund

Agent führt Jobs über einen separaten Dienst und `msdb`-Metadaten aus. Dienstzustand, Startmodus und Plattformverfügbarkeit sind Voraussetzungen, aber noch keine Aussage über Scheduler, Jobowner, Proxies oder einzelne Jobs.

### Datenkette

`msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Aktueller Servicezustand; bei Restart/Failover kann der Status wechseln.

### Bewertung und Gegenprobe

Dienst vorhanden/läuft, Edition/Plattform, Startmodus und Agent-XPs/Erreichbarkeit gemeinsam lesen. Ein bewusst deaktivierter Agent kann in containerisierten oder extern orchestrierten Umgebungen normal sein.

### Typische Fehlinterpretation

`Running` beweist weder aktive Schedules noch erfolgreiche Jobs. Ein gestoppter Agent erklärt fehlende Ausführungen, aber nicht deren ursprüngliche Ursache.

### Folgeanalyse

`USP_AgentJobs` und `USP_AgentMonitoringAnalysis`.

[Technische Detailbeschreibung](../07_Infrastructure.md#1-monitorusp_agentstatus)
