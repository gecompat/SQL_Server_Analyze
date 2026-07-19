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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie klassifiziert und begrenzt Resource Governor Sessions und welche Pools/Groups zeigen Druck oder Abweichungen?

### Technischer Hintergrund

Classifier Function ordnet neue Sessions Workload Groups zu; Groups verweisen auf Resource Pools. Katalogsichten enthalten konfigurierte Werte, Runtime-DMVs `value_in_use` und Counter. CPU Caps, Min/Max Memory, Grant Percentage, Request Limits und External Pools wirken auf unterschiedliche Ressourcen.

### Datenkette

`master.sys.objects`, `master.sys.schemas`, `sys.dm_exec_sessions`, `sys.dm_resource_governor_configuration`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`, `sys.resource_governor_configuration`, `sys.resource_governor_resource_pools`, `sys.resource_governor_workload_groups`.

### Zeit- und Scope-Modell

Aktueller Config-/Runtimezustand; Counter meist kumulativ seit Aktivierung/Start. Bereits verbundene Sessions werden durch Classifieränderung nicht automatisch neu klassifiziert.

### Bewertung und Gegenprobe

Configured vs runtime, Pool/Group-Zuordnung, aktive Requests, Queues, CPU/Memory/Grantlimits und Default/Internal-Kontext lesen. Throttling kann absichtlich sein.

### Typische Fehlinterpretation

Eine Query in einer Group beweist nicht, dass der Classifier aktuell dieselbe Entscheidung für neue Logins treffen würde. Limits sind nicht alle harte Reservierungen.

### Folgeanalyse

Current Requests/Memory Grants, Configuration und reproduzierbarer Login-/Classifiertest.

[Technische Detailbeschreibung](../07_Infrastructure.md#3-monitorusp_resourcegovernoranalysis)
