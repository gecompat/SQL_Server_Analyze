# [monitor].[USP_ServiceBrokerAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet sichtbare Service-Broker-Queues, Aktivierung, Transmission und Conversation-Zustände ohne Nachrichteninhalt oder Zustandsänderung.<br>
**Beobachtungsart:** flüchtiger Runtime-Snapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Warum werden Service-Broker-Nachrichten nicht verarbeitet oder übertragen, und welche Queue-/Conversationzustände existieren?** Der dokumentierte Zweck ist: Bewertet sichtbare Service-Broker-Queues, Aktivierung, Transmission und Conversation-Zustände ohne Nachrichteninhalt oder Zustandsänderung. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Queue-/Conversation-/Transmissionzustand; Rows können bei Verarbeitung rasch verschwinden, alte Dialoge persistieren. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServiceBrokerAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Die Procedure verwendet für jeden fachlichen Lauf `CATALOG_DEEP`. Die Bestätigung ist deshalb auch beim Problemscope einer einzelnen Datenbank nötig; Queue-Inhalte werden dadurch weder freigegeben noch gelesen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, einer Queue, einer gruppierten Transmission-Konstellation oder einem aggregierten Conversation-Zustand.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach Queue-Schalter und approximativen Rückstand mit Queue-Monitor, aktivierten Tasks, Transmission-Alter/-Status und Conversation-Zuständen korrelieren.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Deaktiviertes RECEIVE oder Enqueue, fehlender Aktivierungsfortschritt, alte Transmission-Einträge und Conversation-Errorzustände können Verarbeitung oder Zustellung verhindern. Ein einzelner Wert beweist die Ursache jedoch nicht.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Queue-Monitor und Tasks sind Momentaufnahmen. Retention kann Queue-Zeilen nach erfolgreicher Verarbeitung erhalten, kurz laufende Reader können zwischen Messungen fehlen und langlebige Dialoge können fachlich beabsichtigt sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine nichtleere Queue mit aktivierter interner Prozedur, ohne sichtbaren Task und ohne laufende Receives ist ein Reviewfall, wenn alle drei Quellen vollständig sind. Zeitverlauf, Fehlerlog beziehungsweise freigegebene Events und Anwendungstransaktionen prüfen. RECEIVE OFF allein beweist keine Poison Message.

**Ähnlich aussehender Gegenfall:** Queue-Monitor und Tasks sind Momentaufnahmen. Retention kann Queue-Zeilen nach erfolgreicher Verarbeitung erhalten, kurz laufende Reader können zwischen Messungen fehlen und langlebige Dialoge können fachlich beabsichtigt sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_ServiceBrokerAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Ein Leerzustand beweist bei eingeschränkter Metadatensichtbarkeit keine Abwesenheit. Fehlende Rechte auf Aktivierungs-DMVs lassen andere Katalog-, Transmission- und Conversation-Evidenz gültig; die Procedure kennzeichnet diese Lücke über `IsPartial` und `SourceStatus`.

## Eigenlast und Grenzen

MEDIUM: sichtbare Kataloge, aggregierte Broker-Laufzeitmetadaten und approximative Partitionsstatistik. Es werden keine Queue-Nutzdaten gelesen und kein `RECEIVE`, `ALTER QUEUE` oder `END CONVERSATION` ausgeführt.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und möglichst Queue-/Objektfilter; Konfiguration, approximative Queuegröße, Aktivierung, Transmission und aggregierte Conversation-Zustände werden gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter und unbegrenzte Ausgabe bei vielen Queues, Transmissionzeilen und Conversation Endpoints. Nachrichtenkörper und Queue-Nutzdaten bleiben ausgeschlossen. |
| Haupttreiber | Zahl gewählter Datenbanken, Broker-Queues/-Services, Queue-Monitore, aktivierter Tasks, Transmissionzeilen und Conversation Endpoints. Nachrichteninhalte werden nicht gelesen; große offene Conversationbestände dominieren den Deep-Pfad. |
| Skalierung | Katalog-/Queuepfad wächst mit Brokerobjekten und Partitionen; Aggregationen über `sys.transmission_queue` und `sys.conversation_endpoints` wachsen mit Rückstand und Endpointbestand und können den Lauf dominieren. |
| Ressourcen | CPU und Datenbank-I/O für Brokerkataloge, Queue-Partitionsmetadaten und aggregierte Transmission-/Conversation-Systemtabellen; dynamisches SQL und TempDB/Arbeitsspeicher für Gruppen/Findings. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen Queuekatalogarbeit. `@MaxZeilen` und `@NurProblematisch` werden erst auf fertige Resultsets angewandt und begrenzen insbesondere die vorgelagerte Aggregation von Transmission und Conversations nicht. |
| Locking und Nebenwirkungen | Read-only ohne `RECEIVE`, `END CONVERSATION` oder Queueänderung. Runtime-/Systemtabellen verändern sich während des Laufs; kurze Katalogzugriffe und Aggregations-I/O können mit Brokeraktivität konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und konkrete Queuefilter. Bei großem Transmission-/Endpointbestand außerhalb der Lastspitze ausführen und zuerst Quellenstatus/Vollständigkeit prüfen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „flüchtiger Runtime-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

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

## Primärquellen

- [Service Broker catalog views](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/service-broker-catalog-views-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#5-monitorusp_servicebrokeranalysis)
