# [monitor].[USP_ShowplanAnalysis]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Extrahiert Statements, Warnungen, Objekte, Statistiken, Operatoren, Kardinalität, Memory und Parameter aus Plan-XML.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Operatoren, Schätzungen, Warnungen, Objekte, Statistiken und Optimizerhinweise enthält ein Showplan?** Der dokumentierte Zweck ist: Extrahiert Statements, Warnungen, Objekte, Statistiken, Operatoren, Kardinalität, Memory und Parameter aus Plan-XML. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Planstand zum Compile-/Capturezeitpunkt; zugrunde liegende Daten/Statistiken können inzwischen geändert sein. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ShowplanAnalysis]
      @QueryHash = 0x0102030405060708,
      @AnalyseModus = 'GEZIELT',
      @MaxAnalyseobjekte = 5,
      @MaxDurationSeconds = 10,
      @MaxZeilen = 1000,
      @ResultSetArt = 'CONSOLE';
```

Nur synthetischer Beispielhash; echte Hashes ausschließlich zur kontrollierten Laufzeitanalyse verwenden und nicht ungeprüft weitergeben.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Statement, Finding, Missing-Index-Element, Objekt, Statistik, Operator, Kardinalitätsvergleich, Grant oder Parameter.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Statement → Warnungen → Operatoren → absolute Estimate/Actual-Werte → Memory → Parameter. Absolute Zeilenmengen vor Ratios lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Große Estimate-/Actual-Abweichungen können ungeeignete Joinarten, Grants und Zugriffspfade verursachen. Spills zeigen Auslagerung nach TempDB.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ratio 10 bei 1 zu 10 Zeilen ist meist weniger relevant als Ratio 10 bei 10 Mio. zu 100 Mio. Zeilen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Estimate 1, Actual 10 Mio. kann Nested Loops oder einen kleinen Grant kollabieren lassen. Statistik, Parameter, Query Store, Index und Memory prüfen.

**Ähnlich aussehender Gegenfall:** Ratio 10 bei 1 zu 10 Zeilen ist meist weniger relevant als Ratio 10 bei 10 Mio. zu 100 Mio. Zeilen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_ShowplanAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

XML-XQuery ist CPU-intensiv. Scope, Zeit- und Objektbudget klein halten.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** XML wird erst nach Kandidatenselektion planweise geladen und geschreddert. VOLL oder mehr als 20 Pläne prüft PLAN_CACHE_DEEP und SHOWPLAN_XML_DEEP; dies gilt ebenfalls ab mehr als 20 Plänen. Zeit- und Mengenlimits sind hart vorgesehen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | `GEZIELT`, maximal 20 Candidates, 30-Sekunden-Deadline und 50.000 Ergebniszeilen. Ohne Handle/Hash/Text-/Datenbankfilter rangiert der Code trotzdem den sichtbaren Query-Stats-Snapshot und nimmt die Top-Candidates nach `@Sortierung`. |
| Teuerster Pfad | `VOLL` oder unbegrenzte Candidates, große Plan-XMLs, 3.600-Sekunden-Deadline und unbegrenztes Zeilenbudget. Jeder Plan wird in bis zu neun fachliche Granularitäten geschreddert. |
| Haupttreiber | Zahl/Größe der ausgewählten Compile- oder Last-Actual-Pläne und Operator-/Statementknoten je XML. Candidate-Ranking liest frisch `sys.dm_exec_query_stats` oder verwendet den Parent-Snapshot. |
| Skalierung | Candidateauswahl scannt/rangiert den Cache einmal; anschließend wächst XQuery-Arbeit planweise mit XML-Komplexität. Objekt-, Statistik-, Operator-, Kardinalitäts-, Memory- und Parameterresultsets können aus einem einzigen Plan viele Zeilen erzeugen. |
| Ressourcen | CPU, Speicher und TempDB für XML-Laden und -Shredding; Cachezugriff sowie großer Transfer bei vollständigem Plan XML. |
| Begrenzungswirkung | Candidate-Limit wirkt vor dem Planladen. Deadline und Finding-/Zeilenbudget werden zwischen Candidates geprüft, können aber das bereits begonnene XML-Shredding eines großen Plans nicht abbrechen. Die Ausgabe erhält zusätzlich pro Resultset TOP; Filter vor dem Ranking sind wirksamer. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung. Cachehandles können verschwinden; `LAST_ACTUAL` liefert nur vorhandene Last-Actual-Evidenz und aktiviert kein Profiling. XML-Auswertung kann erhebliche Schedulerzeit verbrauchen. |
| Schutzmechanismus | Bei `VOLL` oder mehr als 20/unbegrenzten Candidates prüft der Code nacheinander `PLAN_CACHE_DEEP` und `SHOWPLAN_XML_DEEP`. Einen separaten `SHOWPLAN_TARGETED`-Check gibt es in dieser Implementierung nicht. Bestätigung ersetzt Filter, Deadline und Mengenbudget nicht. |
| Sicherer Einsatz | Genau einen `ExampleQueryHash`/PlanHandle untersuchen, höchstens wenige Kandidaten und kurze Deadline. `LAST_ACTUAL` sowie `VOLL` nur bewusst und mit beiden Deep-Gates. |
| Aussagegrenze | Cacheeviction kann zwischen Ranking und XML-Laden auftreten. Compile-Pläne enthalten keine Ist-Zeilen; LAST_ACTUAL nur bereits vorhandene Profilingevidenz. Deadline/Top-N priorisiert, kann aber gerade den ursächlichen späteren Plan auslassen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Operatoren, Schätzungen, Warnungen, Objekte, Statistiken und Optimizerhinweise enthält ein Showplan?

### Technischer Hintergrund

Showplan XML modelliert RelOp-Baum, Estimated Rows/Cost, Predicate, Object/Index, Statistics, Memory Grant, Parallelism und Warnings. Cached/Query-Store-Pläne sind typischerweise Estimated-/Compilepläne; Actual Rows existieren nur in tatsächlichen Ausführungsplänen beziehungsweise entsprechenden Runtimefeatures.

### Datenkette

`master.sys.databases`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Planstand zum Compile-/Capturezeitpunkt; zugrunde liegende Daten/Statistiken können inzwischen geändert sein.

### Bewertung und Gegenprobe

Operatorfluss von unten nach oben, Estimated vs Actual sofern vorhanden, Join-/Accessmethode, Predicate, Spills, Conversions, Missing Index und Memory/Parallelism zusammen lesen. Warnung plus Runtimewirkung priorisieren.

### Typische Fehlinterpretation

Estimated Cost ist keine gemessene Zeit und zwischen unabhängigen Servern/CE-Kontexten nicht absolut vergleichbar. Missing-Index-XML ist keine fertige DDL.

### Folgeanalyse

Statistics Distribution, Query Store Runtime/Regression und reale Laufzeitmessung.

## Primärquellen

- [Showplan XML](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#5-monitorusp_showplananalysis)
