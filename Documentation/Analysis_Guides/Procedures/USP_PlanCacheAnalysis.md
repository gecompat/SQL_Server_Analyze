# [monitor].[USP_PlanCacheAnalysis]

**Bereich:** Plan Cache, Orchestrator<br>
**Zweck:** Orchestriert Query Stats, Query Hash, Cache Health und optional Showplan.<br>
**Beobachtungsart:** nicht atomarer Plan-Cache-Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Plan-Cache-Perspektiven sollen gemeinsam für Triage oder Deep Analysis ausgeführt werden?** Der dokumentierte Zweck ist: Orchestriert Query Stats, Query Hash, Cache Health und optional Showplan. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Query Stats, Query Hash und Showplan-Kandidatenauswahl verwenden im gemeinsamen Lauf denselben `dm_exec_query_stats`-Stand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats = 1,
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Showplan erst nach Kandidatenpriorisierung aktivieren.

Der hier gewählte unselektierte Query-Stats-Childpfad benötigt `PLAN_CACHE_DEEP`. Die Bestätigung ersetzt weder ein kleines Limit noch die getrennte Prüfung, ob nach der Triage überhaupt Showplan benötigt wird.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Cachezeile, Query-Hash-Gruppe, Cacheaggregation oder Planbestandteil.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Modulstatus und Reihenfolge beachten: Query Stats findet Kandidaten, Query Hash erklärt Varianten, Health bewertet Cache, Showplan erklärt Planinhalt.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Breite XML-Analyse kann selbst CPU erzeugen und sehr viele Findings ohne Priorisierung liefern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht aktivierte Children fehlen absichtlich; der Default ist bewusst leichtgewichtig.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Erst Top-CPU bestimmen, dann nur wenige relevante Pläne parsen. Historische Relevanz anschließend im Query Store prüfen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Children fehlen absichtlich; der Default ist bewusst leichtgewichtig. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_PlanCacheAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Query-Stats-Child, TOP 100 und CONSOLE. Ohne QueryHash ist bereits dieser unselektierte Parentpfad `PLAN_CACHE_DEEP`-geschützt; andere Children sind aus. |
| Teuerster Pfad | Alle vier Children, `@AnalyseModus = 'VOLL'`, `@MaxZeilen = 0`, unbegrenzte Analyseobjekte und hohe `@MaxDurationSeconds`: vollständige Cachegruppierung plus Showplan-XML für viele Kandidaten. Es gibt keine Datei-, `msdb`- oder Samplingquelle. |
| Haupttreiber | Zahl der Einträge in `sys.dm_exec_query_stats`/`sys.dm_exec_cached_plans`, Breite von SQL-Text und Planattributen sowie Zahl/Größe der für Showplan ausgewählten XML-Pläne. |
| Skalierung | Benötigen mehrere Children Query Stats, materialisiert der Parent diese DMV einmal laufgebunden und reicht den Snapshot weiter. Gruppierung, Sortierung und Showplan-Shredding bleiben childbezogen; Cache Health kann unabhängig den gesamten Cache aggregieren. |
| Ressourcen | Summe der Plan-Cache-Children: Cache-DMV-/Attribut-/Textzugriff, Gruppierung/Sortierung, TempDB/Arbeitsspeicher und optional Showplan-XML-CPU/Transfer. Kein msdb-, Datei- oder Benutzerdatenscan. |
| Begrenzungswirkung | `@MaxZeilen` gilt je Child, `@MaxAnalyseobjekte` nur für Showplan. `@MaxDurationSeconds` ist dessen kooperative Deadline und begrenzt weder Query Stats noch Cache Health. Text-/Hash-/Handlefilter können früh Kandidaten reduzieren; Top-N entsteht ansonsten erst nach Cachezugriff und Sortierung. |
| Locking und Nebenwirkungen | Der Parent ändert weder Nutzdaten noch Cachekonfiguration. Childaufrufe sind nacheinander und nicht atomar; Cacheeinträge können zwischen Query Stats, Hash, Health und Showplan evicted oder neu kompiliert werden. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | TOP 100, nur Query Stats, möglichst Datenbank-/Hashselektor und `@HighImpactConfirmed = 1` für den dokumentierten unselektierten Einstieg. Danach nur den auffälligen Childpfad separat vertiefen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „nicht atomarer Plan-Cache-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Plan-Cache-Perspektiven sollen gemeinsam für Triage oder Deep Analysis ausgeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Query Stats, Hashgruppen, Cache Health, Details und Showplanpfade. Wenn mindestens zwei der Consumer Query Stats, Query Hash und Showplan-Kandidatenauswahl aktiv sind, materialisiert er `sys.dm_exec_query_stats` einmal laufgebunden; die Children melden `REUSED_PARENT_SNAPSHOT`. Ein breiter gemeinsamer Read wird erst nach `PLAN_CACHE_DEEP`-Freigabe ausgeführt. Plan-XML und breite Cache-Scans erhöhen CPU, Memorytransfer und Resultsetgröße.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in den aufgerufenen Childmodulen.

### Source Select

Kein einzelnes Grundselect: Die Procedure liest `sys.dm_exec_query_stats` einmal in einen lauflokalen Snapshot und übergibt diesen an `USP_QueryStats`, `USP_QueryHashAnalysis`, `USP_PlanCacheHealth` und optional `USP_ShowplanAnalysis`.

**Wichtig für die Eigenlast:** Query Hash, Handle, Zeit und Analysemodus vor Showplan-XML eingrenzen. Die zentrale Einmalkopie verhindert wiederholte Query-Stats-Scans; breite XML-Analyse bleibt ein separater High-Impact-Pfad.

### Zeit- und Scope-Modell

Query Stats, Query Hash und Showplan-Kandidatenauswahl verwenden im gemeinsamen Lauf denselben `dm_exec_query_stats`-Stand. Cache Health besitzt mit `dm_exec_cached_plans` eine eigene Quelle; Plan-XML wird später planweise geladen und kann nach Eviction fehlen. Einzelaufrufe lesen immer frisch.

### Bewertung und Gegenprobe

Status/Partial zuerst, dann von Gesamtkosten zu Hash/Plan und erst danach XML-Deep-Dive. Scope und MaxRows eng halten.

### Typische Fehlinterpretation

Ein leerer Detailpfad kann durch Eviction nach dem gemeinsamen Kandidatensnapshot entstehen, nicht durch fehlende frühere Ausführung. Snapshot-Fallback und partielle Planstatus nicht als vollständige Cache-Evidenz lesen.

### Folgeanalyse

Historische Fragen mit Query Store; aktuelle Ressourcenauswirkung mit Current State.

## Primärquellen

- [Plan-Cache-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/execution-related-dynamic-management-views-and-functions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#6-monitorusp_plancacheanalysis)
