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

[Technische Detailbeschreibung](../09_Version_Adaptive.md#5-monitorusp_servicebrokeranalysis)
