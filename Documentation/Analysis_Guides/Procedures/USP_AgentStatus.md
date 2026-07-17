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

[Technische Detailbeschreibung](../07_Infrastructure.md#1-monitorusp_agentstatus)
