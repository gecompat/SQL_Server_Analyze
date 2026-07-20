# [monitor].[USP_QueryStoreRuntimeStats]

**Bereich:** Query Store<br>
**Zweck:** Aggregiert historische Laufzeit- und Ressourcenwerte je Query und Plan über Query-Store-Intervalle.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Query-/Plan-Kombinationen verursachten im gewählten historischen Fenster Ausführungen, Dauer, CPU, I/O, Memory, TempDB oder Loglast?** Der dokumentierte Zweck ist: Aggregiert historische Laufzeit- und Ressourcenwerte je Query und Plan über Query-Store-Intervalle. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Persistierte, intervalaggregierte Historie innerhalb Retention. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `runtimeStats` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Aggregation je Query, Plan und Ausführungstyp über alle berücksichtigten Runtime-Intervalle. Sie ist keine einzelne Ausführung.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zeitfenster und Intervalllänge, `ExecutionCount`, Total- und Averagewerte sowie `PlanId` vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Mehrere Pläne derselben Query mit stark unterschiedlichen Werten können Regression oder Parameter Sensitivity anzeigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Hohe Total-CPU bei sehr vielen Ausführungen kann pro Aufruf klein sein. Hohe Average-Dauer bei einer Ausführung ist schwache Evidenz.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Plan A: 10 ms × 100.000; Plan B: 500 ms × 20. B ist pro Aufruf schlechter, A kann aber mehr Gesamtlast erzeugen. Waits, Plan Changes und Showplan prüfen.

**Ähnlich aussehender Gegenfall:** Hohe Total-CPU bei sehr vielen Ausführungen kann pro Aufruf klein sein. Hohe Average-Dauer bei einer Ausführung ist schwache Evidenz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreRuntimeStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Randintervalle können Messanteile außerhalb des exakten Fensters enthalten.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, kurzes UTC-Fenster, TOP 100, kein Plan XML und keine Referenzdatenbankauflösung. Lokal werden höchstens N+1 gerankte Kandidaten übernommen. |
| Teuerster Pfad | Viele Datenbanken, `VOLL` beziehungsweise unbegrenztes/hohes Limit, langer Zeitraum, Plan XML und Referenzdatenbank-/Regexfilter. Aggregation und XML-Prüfung können große Retentionsbestände berühren. |
| Haupttreiber | Zahl der gewählten Query Stores, überlappenden Runtimeintervalle, Query-/Plan-Kombinationen und Ausführungsstatistikzeilen. Ohne enges UTC-Fenster wächst die Aggregation mit der gesamten aufbewahrten Historie; Referenzfilter können Plan-XML ergänzen. |
| Skalierung | Quellarbeit wächst mit überlappenden Runtimeintervallen, Queries/Plänen und Datenbanken. Plan-XML-/Referenzfilter erhöhen CPU und Speicher; Text-/Planbreite erhöht Transfer. |
| Ressourcen | CPU und I/O auf Query-Store-internen Tabellen, TempDB für Fensteraggregation und Transfer für Texte/Pläne; Umfang folgt Retention und Capturevolumen. |
| Begrenzungswirkung | Datenbank, UTC-Fenster, QueryId/-Hash und Textfilter begrenzen die Quelle. N+1 wird jedoch erst nach Intervallaggregation und Sortierung je Datenbank angewandt; es begrenzt nicht die dafür gelesenen Historyzeilen. Das globale TOP wird anschließend über lokale Kandidaten gebildet. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, einstündiges UTC-Fenster, TOP 100 und kein XML. `VOLL`, >1000/unbegrenzt, Regex-/Referenzfilter oder breite Zeitfenster erst nach `QUERY_STORE_DEEP`-Bestätigung. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-/Plan-Kombinationen verursachten im gewählten historischen Fenster Ausführungen, Dauer, CPU, I/O, Memory, TempDB oder Loglast?

### Technischer Hintergrund

Runtime Stats speichern aggregierte Messwerte je Plan, Intervall und Execution Type. Totalwerte entstehen aus Intervallsummen; globale Averagewerte müssen nach Ausführungszahl gewichtet werden, wenn der Code nicht bereits gewichtete Totals verwendet. Query, Plan und Text werden über IDs verbunden, die nur innerhalb der Query-Store-Datenbank eindeutig sind.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats`, `sys.query_store_runtime_stats_interval`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierte, intervalaggregierte Historie innerhalb Retention. Überlappende Randintervalle können vollständig einbezogen sein.

### Bewertung und Gegenprobe

Total und Average stets mit Execution Count, PlanId, Execution Type und Zeitspanne lesen. Hohe Total-CPU bei niedriger Average-CPU ist eine kumulative Optimierungschance; hohe Average-Duration bei niedriger CPU verlangt Wait-/Blocking-/I/O-Kontext.

### Typische Fehlinterpretation

Durchschnittswerte verdecken P95/P99, multimodale Parametergruppen und Ausreißer. Query Store Runtime ist keine Storage-Latenzmessung.

### Folgeanalyse

`USP_QueryStoreWaitStats`, PlanChanges, Regressions und Showplan.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#2-monitorusp_querystoreruntimestats)
