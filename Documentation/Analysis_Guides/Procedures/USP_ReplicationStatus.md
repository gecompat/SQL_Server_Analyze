# [monitor].[USP_ReplicationStatus]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Publikationen, Subscriptions, Agents, Latenz, Backlog und Fehler.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ReplicationStatus]
      @MitDistributionDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Publikation, Subscription, einen Agent oder eine Distributor-/Backlogmetrik.

## So lesen

Agentstatus, letzte Aktion, Latenz, Pending Commands, Fehler und Trend über mehrere Messungen lesen.

## Warum kann das problematisch sein?

Wachsender Backlog bedeutet, dass Änderungen schneller entstehen als verteilt werden oder ein Agent/Distributor blockiert ist.

## Wann ist es kein Problem?

Kurzzeitiger Backlog während Lastspitzen ist akzeptabel, wenn er anschließend sichtbar abgebaut wird.

## Beispiel und Folgeschritt

Pending Commands steigen in drei Messungen kontinuierlich und Latenz wächst: systematischer Rückstand. Agentjob, Distributor, Blocking und Netzwerk prüfen.

[Technische Detailbeschreibung](../07_Infrastructure.md#7-monitorusp_replicationstatus)
