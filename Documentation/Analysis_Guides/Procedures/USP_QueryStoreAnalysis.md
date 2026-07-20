# [monitor].[USP_QueryStoreAnalysis]

**Bereich:** Query Store, Orchestrator<br>
**Zweck:** Orchestriert Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints und IQP.<br>
**Beobachtungsart:** nicht atomare Folge persistierter Query-Store-Historien<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Query-Store-Perspektiven sollen kontrolliert in einem Lauf ausgeführt werden?** Der dokumentierte Zweck ist: Orchestriert Status, Runtime, Waits, Planwechsel, Regressionen, Forced Plans, Hints und IQP. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Nicht atomare Folge persistierter Queries; Childstatus je Datenbank. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @MitStatus = 1,
      @MitRuntimeStats = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Ohne `@VonUtc`/`@BisUtc` aggregiert das Runtime-Child die gesamte noch
aufbewahrte Query-Store-Historie. Das kurze Fenster ist deshalb ein
Quellkosten- und zugleich ein Aussage-Scope, nicht nur ein Ausgabefilter.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Datenbank, Query/Plan-Aggregat, Waitkategorie, Plan, Hint oder IQP-Signal.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Statuschild zuerst, dann nur aktivierte Children. Zeitfenster und Wrappersemantik der Regressionen beachten.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein historisches Ergebnis kann durch Capture, Retention oder Wrapperfenster falsch eingeordnet werden. Der Wrapper übergibt das Fenster als Vergleichsfenster; die Baseline liegt davor.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Deaktivierte Children fehlen absichtlich.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Letzte Stunde als Eingabefenster bedeutet: Vergleich letzte Stunde, Baseline die Stunde davor. Auffälliges Child mit QueryId/Hash und engem Zeitraum wiederholen.

**Ähnlich aussehender Gegenfall:** Deaktivierte Children fehlen absichtlich. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Status plus Runtime Stats. Bei `@VonUtc = NULL` und `@BisUtc = NULL` ist der Runtimepfad zeitlich nicht klein, sondern aggregiert die gesamte aufbewahrte Historie jeder gewählten Query-Store-Datenbank. |
| Teuerster Pfad | Alle acht Children über mehrere große Query Stores ohne Zeit- oder Zeilenlimit und mit Referenzdatenbankfilter: dieselben Query-/Plan-/Runtimebereiche werden mehrfach aggregiert; mehrere Children müssen Plan-XML zur Referenzauflösung parsen. |
| Haupttreiber | Zahl der Query-Store-Datenbanken, Queries, Pläne, Runtime-/Wait-Intervalle und Breite des Zeitfensters. Referenzdatenbankfilter verlagern Arbeit in Plan-XML-Auswertung; IQP ergänzt datenbankweite Konfigurations-/Feedbackaggregation. |
| Skalierung | Children laufen nacheinander ohne gemeinsamen Query-Store-Snapshot. Status ist klein, Runtime/Wait/Regressionen skalieren mit Intervallen, und PlanChanges/ForcedPlans mit Plananzahl. Dasselbe Zeitfenster wird je aktiviertem Historienchild separat verarbeitet. |
| Ressourcen | I/O und CPU in den persistenten `sys.query_store_*`-Views, Sortierung/Aggregation, dynamisches Cross-Database-SQL, optional Plan-XML und JSON/Transfer. Kein `msdb`, XEL oder WAITFOR. |
| Begrenzungswirkung | `@VonUtc`/`@BisUtc` reduzieren nur zeitfähige Children; Status, Forced Plans und Hints haben andere beziehungsweise keine Zeitsemantik. `@MaxZeilen` gilt je Child nach dessen eigener Aggregations-/Kandidatenlogik und verhindert nicht automatisch das Lesen aller passenden Intervalle. |
| Locking und Nebenwirkungen | Read-only; es werden weder Pläne erzwungen noch Hints gesetzt. Query Store erfasst während des sequenziellen Laufs weiter, daher können Childnenner und „letzte“ Zeitpunkte voneinander abweichen. |
| Schutzmechanismus | Datenbankscope und IQP-/Cross-Database-Pfade werden über Childanalyseklassen und `@HighImpactConfirmed` geprüft; sechs teurere Perspektiven sind standardmäßig aus. Der Gate-Schalter ist kein Zeitfenster und kein Max-Rows-Ersatz. |
| Sicherer Einsatz | Eine Query-Store-Datenbank, ein enges UTC-Fenster, Status + Runtime und `@MaxZeilen = 100`. Referenzdatenbankfilter sowie weitere Children erst nach einem konkreten Query-/Planbefund aktivieren. |
| Aussagegrenze | Zeitfilter und Retention bestimmen gemeinsam, was historisch sichtbar ist. Ein Top-N je Child kann unterschiedliche Queries zeigen; Planwechsel, Regression und Waits dürfen nur über Query-/Plan-ID plus Fenster korreliert werden, nicht über Zeilenposition. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-Store-Perspektiven sollen kontrolliert in einem Lauf ausgeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Status, Runtime, Waits, PlanChanges, Regressions, Forced Plans, Hints und IQP. Er übergibt gemeinsame Datenbankscope-/Zeitparameter, aber einzelne Children interpretieren Fenster unterschiedlich.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomare Folge persistierter Queries; Childstatus je Datenbank.

### Bewertung und Gegenprobe

Status zuerst; dann Runtime priorisieren und nur bei Bedarf Wait/Plan/Regression/Intervention vertiefen. Deep-Optionen, Plan XML und viele Datenbanken erhöhen Kosten.

### Typische Fehlinterpretation

Ein Wrapperfenster kann für Regression als Comparison Window verwendet werden, während Baseline davor abgeleitet wird. Resultsets nicht ohne Childnamen/-status zusammenführen.

### Folgeanalyse

Betroffenes Child gezielt erneut ausführen.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#9-monitorusp_querystoreanalysis)
