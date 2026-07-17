# [monitor].[USP_ResourceGovernorAnalysis]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Resource Pools, Workload Groups, Limits und optional zugeordnete Sessions.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ResourceGovernorAnalysis]
      @MitSessions = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen Resource Pool, eine Workload Group oder eine aktuell zugeordnete Session.

## So lesen

Poollimits, Group-Limits, aktuelle Nutzung, Cap-/Min-Werte und Sessionzuordnung gemeinsam betrachten.

## Warum kann das problematisch sein?

CPU-, Memory- oder Parallelitätslimits können Requests absichtlich drosseln oder Grants begrenzen.

## Wann ist es kein Problem?

Drosselung kann genau das gewünschte Schutzverhalten für andere Workloads sein.

## Beispiel und Folgeschritt

Eine Query ist langsam, ihrer Gruppe stehen aber nur 20 % CPU zu: zunächst Policywirkung statt schlechten Plan vermuten. Classifier, Zuordnung und SLA prüfen.

[Technische Detailbeschreibung](../07_Infrastructure.md#3-monitorusp_resourcegovernoranalysis)
