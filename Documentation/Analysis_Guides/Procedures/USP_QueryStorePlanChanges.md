# [monitor].[USP_QueryStorePlanChanges]

**Bereich:** Query Store<br>
**Zweck:** Findet Queries mit mehreren Query-Store-Plänen und zeigt Compile- sowie Nutzungsmetadaten.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Queries besitzen mehrere gespeicherte Pläne, und wodurch unterscheiden sich deren Lebenszyklus und Compilekontext?** Der dokumentierte Zweck ist: Findet Queries mit mehreren Query-Store-Plänen und zeigt Compile- sowie Nutzungsmetadaten. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Persistierter Planbestand innerhalb Query-Store-Retention; Last Execution zeigt Aktivität, nicht dauerhafte Gültigkeit. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMehrerePlaene = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `queries` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Summary-Zeilen entsprechen Queries; Planzeilen entsprechen jeweils einer Query-Store-Plan-ID.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

PlanCount, Distinct Plan Hashes, Compile-/Executionzeiten, Engine-/Compatibility-Kontext und Forced-Status vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein neuer Plan kann andere Kosten, Parallelität oder Zugriffspfade besitzen und zeitlich mit einer Regression zusammenfallen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Mehrere Planzeilen mit demselben Hash oder alte, nicht mehr ausgeführte Pläne sind nicht automatisch relevant.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Vier PlanIds, aber nur zwei Hashes; einer seit Monaten inaktiv. Aktive Varianten mit Runtime Stats, Regressionen und Planvergleich untersuchen.

**Ähnlich aussehender Gegenfall:** Mehrere Planzeilen mit demselben Hash oder alte, nicht mehr ausgeführte Pläne sind nicht automatisch relevant. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStorePlanChanges` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, jüngerer Startzeitpunkt, nur Queries mit mehreren Plänen, TOP 100 und `@MitPlanXml = 0`. |
| Teuerster Pfad | Viele Datenbanken, `VOLL`/unbegrenztes Limit, weit zurückliegendes `@VonUtc`, Plan XML und Referenzdatenbank-/Regexfilter mit XML-Shredding. |
| Haupttreiber | Zahl gewählter Query Stores, Queries und zugehöriger Pläne, die für Mehrplanerkennung gruppiert werden. Querytext-, Regex- und Referenzdatenbankfilter können zusätzliche Text- beziehungsweise Showplanarbeit verursachen; ein Zeitfenster gibt es nicht. |
| Skalierung | Aufwand wächst mit Queries, Planvarianten und überlappenden Runtimezeilen seit `@VonUtc`. Plan-XML-Ausgabe oder Referenzfilter erhöhen XML-CPU, Speicher und Transfer. |
| Ressourcen | CPU/I/O auf Query-Store-Query-, Plan- und Runtimestatistiken, TempDB/Arbeitsspeicher für Gruppierung/Ranking; optional Plan-XML-Materialisierung. |
| Begrenzungswirkung | Datenbank, `@VonUtc`, QueryId/-Hash begrenzen die Quelle. Lokales N+1 wirkt erst nach Plan-/Runtimekorrelation und Ranking; globales TOP begrenzt danach die Rückgabe. Referenzfilter müssen Plan XML bereits vor dem TOP prüfen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Queryselektor oder jüngerer Start, TOP 100 und kein XML. `VOLL`, Plan XML, Referenzfilter oder >1000/unbegrenzt nur nach Deep-Gate. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen mehrere gespeicherte Pläne, und wodurch unterscheiden sich deren Lebenszyklus und Compilekontext?

### Technischer Hintergrund

`sys.query_store_plan` speichert PlanId, Plan Hash, Engine Version, Compatibility, Compilezeiten, IsParallel, Forced-Status und Plan XML. Mehrere PlanIds können strukturell gleichen Plan Hash besitzen; Recompile oder Kontextänderung kann neue Zeilen erzeugen.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierter Planbestand innerhalb Query-Store-Retention; Last Execution zeigt Aktivität, nicht dauerhafte Gültigkeit.

### Bewertung und Gegenprobe

PlanCount, DistinctPlanHashCount, Compile-/Executionzeit, Engine/Compatibility, Forced-Status und Runtimewerte je Plan vergleichen. Ein neuer Plan ist erst bei abweichender Wirkung relevant.

### Typische Fehlinterpretation

Mehrere Pläne bedeuten nicht automatisch Parameter Sensitivity oder Regression. Ein alter nie mehr ausgeführter Plan kann historisch, aber aktuell irrelevant sein.

### Folgeanalyse

Runtime Stats je Plan, Regressions, Forced Plans und Showplanvergleich.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#4-monitorusp_querystoreplanchanges)
