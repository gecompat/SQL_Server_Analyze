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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?

### Technischer Hintergrund

Transactional Replication nutzt Log Reader und Distribution Agents; Merge Replication eigene Agents/Sessions. Publisher-, Distributor- und Subscriber-Metadaten liegen auf verschiedenen Servern/Datenbanken. History und Commands bilden begrenzte Zustände/Latenz.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Verteilte Momentaufnahme plus Distributor-/Agenthistory innerhalb Retention.

### Bewertung und Gegenprobe

Topologierolle, Agentstatus, letzte Aktion/Fehler, undistributed commands, geschätzte Latenz und Zeitmarken zusammen lesen. Remote-/Distributorzugriff als Partialstatus ausgeben.

### Typische Fehlinterpretation

`Running` bedeutet nur aktiver Agent, nicht geringe Latenz. Lokale Leere kann fehlende Rolle oder fehlenden Remotezugriff bedeuten.

### Folgeanalyse

`USP_DataCaptureDeepAnalysis`, Agent Jobs, Log/Distributor-DB-Kapazität und Replication Monitor.

[Technische Detailbeschreibung](../07_Infrastructure.md#7-monitorusp_replicationstatus)
