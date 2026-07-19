# [monitor].[USP_ServiceBrokerAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen
**Zweck:** Bewertet sichtbare Service-Broker-Queues, Aktivierung, Transmission und Conversation-Zustände ohne Nachrichteninhalt oder Zustandsänderung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServiceBrokerAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, einer Queue, einer gruppierten Transmission-Konstellation oder einem aggregierten Conversation-Zustand.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach Queue-Schalter und approximativen Rückstand mit Queue-Monitor, aktivierten Tasks, Transmission-Alter/-Status und Conversation-Zuständen korrelieren.

## Warum kann das problematisch sein?

Deaktiviertes RECEIVE oder Enqueue, fehlender Aktivierungsfortschritt, alte Transmission-Einträge und Conversation-Errorzustände können Verarbeitung oder Zustellung verhindern. Ein einzelner Wert beweist die Ursache jedoch nicht.

## Wann ist es kein Problem?

Queue-Monitor und Tasks sind Momentaufnahmen. Retention kann Queue-Zeilen nach erfolgreicher Verarbeitung erhalten, kurz laufende Reader können zwischen Messungen fehlen und langlebige Dialoge können fachlich beabsichtigt sein.

## Beispiel und Folgeschritt

Eine nichtleere Queue mit aktivierter interner Prozedur, ohne sichtbaren Task und ohne laufende Receives ist ein Reviewfall, wenn alle drei Quellen vollständig sind. Zeitverlauf, Fehlerlog beziehungsweise freigegebene Events und Anwendungstransaktionen prüfen. RECEIVE OFF allein beweist keine Poison Message.

## Leere oder partielle Ausgabe

Ein Leerzustand beweist bei eingeschränkter Metadatensichtbarkeit keine Abwesenheit. Fehlende Rechte auf Aktivierungs-DMVs lassen andere Katalog-, Transmission- und Conversation-Evidenz gültig; die Procedure kennzeichnet diese Lücke über `IsPartial` und `SourceStatus`.

## Eigenlast

MEDIUM: sichtbare Kataloge, aggregierte Broker-Laufzeitmetadaten und approximative Partitionsstatistik. Es werden keine Queue-Nutzdaten gelesen und kein `RECEIVE`, `ALTER QUEUE` oder `END CONVERSATION` ausgeführt.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Warum werden Service-Broker-Nachrichten nicht verarbeitet oder übertragen, und welche Queue-/Conversationzustände existieren?

### Technischer Hintergrund

Service Broker routet typisierte Dialognachrichten über Services/Contracts/Queues. Internal Activation startet Procedures nach Queuezustand. Remoteübertragung nutzt Routes/Endpoints; `sys.transmission_queue` hält nicht zustellbare Nachrichten mit Fehlertext. Conversation Endpoints besitzen Zustandsmaschine und Lifetime.

### Datenkette

`sys.conversation_endpoints`, `sys.databases`, `sys.dm_broker_activated_tasks`, `sys.dm_broker_queue_monitors`, `sys.dm_db_partition_stats`, `sys.schemas`, `sys.service_queues`, `sys.services`, `sys.sp_executesql`, `sys.transmission_queue`.

### Zeit- und Scope-Modell

Aktueller Queue-/Conversation-/Transmissionzustand; Rows können bei Verarbeitung rasch verschwinden, alte Dialoge persistieren.

### Bewertung und Gegenprobe

Broker Enabled, Queue IsReceiveEnabled/Activation, Queue Rows, Transmission Errors/Age, Endpoint States, Routes/Remote Binding und Poison-Message-Deaktivierung korrelieren. Wachstum über Zeit messen.

### Typische Fehlinterpretation

Queue Rows > 0 können normaler Backlog sein; `NOTIFIED`/Activationstatus allein beweist keinen erfolgreichen Consumer. `NEW_BROKER` wäre destruktiv für Dialogidentitäten und ist keine Diagnosemaßnahme.

### Folgeanalyse

Queueprocedure/Errorlog/XE, Network/Endpoint und wiederholtes Backlogsample.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#5-monitorusp_servicebrokeranalysis)
