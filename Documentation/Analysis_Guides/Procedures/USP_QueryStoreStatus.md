# [monitor].[USP_QueryStoreStatus]

**Bereich:** Query Store<br>
**Zweck:** Zeigt Zustand, Capture, Retention, Speicher, Cleanup und Wait-Capture je Datenbank.<br>
**Beobachtungsart:** Konfigurationssnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Ist Query Store aktiviert, schreibfähig, ausreichend dimensioniert und für den gewünschten Evidenztyp konfiguriert?** Der dokumentierte Zweck ist: Zeigt Zustand, Capture, Retention, Speicher, Cleanup und Wait-Capture je Datenbank. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Zustand je ausgewählter Datenbank. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreStatus]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `queryStoreStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Store-Datenbank. Status- und Warnresultsets besitzen separate Zeilen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`ActualStateDesc`, Readonly Reason, Storage Used, Capture Mode, Cleanup, Interval Length und Wait Capture prüfen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Read-only, voller Speicher oder Capture-Regeln können Historienlücken erzeugen. Fehlende Queries sind dann keine Entwarnung.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Capture Mode AUTO lässt billige oder seltene Queries absichtlich aus.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Leeres Waitresultset plus Wait Capture OFF ist erwartbar. Erst bei geeignetem Status Runtime-, Wait- oder Plananalyse starten.

**Ähnlich aussehender Gegenfall:** Capture Mode AUTO lässt billige oder seltene Queries absichtlich aus. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Sehr gering; eine Statuszeile je Datenbank.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Eine explizit benannte `ExampleDatabase`; genau eine Zeile aus `sys.database_query_store_options` wird dynamisch gelesen. Es gibt weder Zeitfenster noch Query-/Plan- oder XML-Zugriff. |
| Teuerster Pfad | Keine Datenbankeinschränkung, sodass alle sichtbaren Online-Userdatenbanken nacheinander geprüft werden. Die Quellmenge bleibt eine Statuszeile je Datenbank. |
| Haupttreiber | Zahl ausgewählter Datenbanken; je Datenbank wird im Wesentlichen eine Query-Store-Optionszeile plus Feature-/Statuskontext gelesen. Query-, Plan-, Text- und Runtime-Tabellen liegen ausdrücklich außerhalb dieses Statuspfads. |
| Skalierung | Laufzeit und dynamischer Compileaufwand wachsen annähernd linear mit der Zahl ausgewählter Datenbanken, nicht mit Query-Store-Retention oder Capturevolumen. |
| Ressourcen | Sehr geringe CPU- und Katalog-I/O-Last; ein kurzer dynamischer Kontextwechsel und eine Optionszeile je Datenbank. Keine TempDB-Fensteraggregation, Texte oder Pläne. |
| Begrenzungswirkung | Datenbankliste/-pattern sind die einzigen Mengengrenzen und wirken vor dem Cursor. Einen `@MaxZeilen`-Parameter gibt es absichtlich nicht, weil pro Datenbank genau eine Statuszeile entsteht. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | `QUERY_STORE_CURRENT` muss im Framework freigegeben sein, verlangt laut Klassenkatalog aber keine High-Impact-Bestätigung. `@HighImpactConfirmed` aktiviert in dieser Procedure keinen Deep-Pfad. |
| Sicherer Einsatz | Eine `ExampleDatabase` und CONSOLE; danach nur bei Bedarf weitere Datenbanken ergänzen. Statuszeile und Warnungen vor fachlicher Interpretation sichern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist Query Store aktiviert, schreibfähig, ausreichend dimensioniert und für den gewünschten Evidenztyp konfiguriert?

### Technischer Hintergrund

`sys.database_query_store_options` trennt gewünschten und tatsächlichen Zustand, Operation Mode, Capture Mode, Interval Length, Retention, Current/Max Size, Cleanup und Wait Stats Capture. READ_ONLY kann aus administrativer Konfiguration oder internen Gründen wie Größenlimit entstehen.

### Datenkette

`sys.database_query_store_options`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Zustand je ausgewählter Datenbank. Status sagt nichts über bereits gelöschte oder nie erfasste Historie.

### Bewertung und Gegenprobe

Actual vs Desired State, Readonly Reason, Current/Max Size, Stale Query Threshold, Cleanup und Capture Mode zusammen lesen. Waitanalyse benötigt aktiviertes Wait Capture.

### Typische Fehlinterpretation

`READ_WRITE` beweist weder Vollständigkeit noch repräsentative Capture-Auswahl. `OFF` zum Analysezeitpunkt erklärt nicht immer, ob frühere Daten noch vorhanden sind.

### Folgeanalyse

Vor allen Query-Store-Fachanalysen; bei Problemen Konfiguration/Storage und Capturepolicy prüfen.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#1-monitorusp_querystorestatus)
