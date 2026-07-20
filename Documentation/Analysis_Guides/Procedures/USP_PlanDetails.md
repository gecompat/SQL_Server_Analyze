# [monitor].[USP_PlanDetails]

**Bereich:** Plan Cache<br>
**Zweck:** Löst gezielte Plan-Kandidaten auf und liefert Attribute sowie Compile-, Last-Actual- oder Live-Plan.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Attribute, Texte, Statements und Planinformationen gehören zu einem konkreten Handle?** Der dokumentierte Zweck ist: Löst gezielte Plan-Kandidaten auf und liefert Attribute sowie Compile-, Last-Actual- oder Live-Plan. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Momentaufnahme eines Cacheeintrags. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanDetails]
      @SessionIds = N'57',
      @MitCompilePlan = 1,
      @MitLastActualPlan = 0,
      @MitLivePlan = 0,
      @MaxAnalyseobjekte = 5,
      @ResultSetArt = 'CONSOLE';
```

Die Session-ID ist vollständig synthetisch. Alternativ gezielt mit vorhandenem Plan Handle oder Query Hash arbeiten; breite Läufe vermeiden.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `candidates` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Kandidaten-, Attribut- und Planresultsets besitzen unterschiedliche Granularität: Kandidat, Attribut je Kandidat beziehungsweise Planquelle je Kandidat.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Kandidatenidentität zuerst, danach Cache-Key-Attribute und schließlich Planquelle unterscheiden: Compile, Last Actual oder Live.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Abweichende Cache-Key-Attribute können mehrere Handles erzeugen. Actual-Pläne können große Schätzfehler, Spills und reale Zeilenmengen sichtbar machen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Compile-Pläne enthalten nur Schätzungen. Fehlende Actualwerte sind daher kein Queryfehler.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Identischer Text mit unterschiedlichen `set_options` erklärt getrennte Cacheeinträge. Danach `USP_ShowplanAnalysis` oder manuellen Planvergleich verwenden.

**Ähnlich aussehender Gegenfall:** Compile-Pläne enthalten nur Schätzungen. Fehlende Actualwerte sind daher kein Queryfehler. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_PlanDetails` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Zielgerichtet und auf @MaxAnalyseobjekte begrenzt. Mehr als 20 Pläne prüft PLAN_CACHE_DEEP. Das Framework aktiviert keine Profilingoption.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Ohne Session/Handle/Hash entsteht keine Candidate-Zeile. Mit einem Selektor werden höchstens 20 Kandidaten ermittelt und standardmäßig Attribute, Compile-XML und auf 8000 Zeichen gekürzter SQL-Text je Kandidat geladen. |
| Teuerster Pfad | `@MaxAnalyseobjekte = 0` mit vollständigen Compile-, Text-, Last-Actual- oder Live-Plänen und ungekürztem SQL-Text. |
| Haupttreiber | Kandidatenzahl und Größe der angeforderten Planrepräsentationen. Sessionfilter liest aktive Requests, PlanHandle ist direkt, SQL-/QueryHash filtern `sys.dm_exec_query_stats`; danach entstehen planweise Attribute, Text und XML. |
| Skalierung | Detailaufrufe wachsen ungefähr mit Kandidaten × aktivierten Planquellen. Planattribute und SQL-Text werden je Candidate separat aufgelöst; große XML-Pläne erhöhen Speicher und Netzwerk, werden hier aber nicht in Operatorzeilen geschreddert. |
| Ressourcen | CPU und Speicher für Kandidaten-/Handleauflösung, Planattribute und optionale Compile-, Text-, Last-Actual- oder Live-Plan-XML; großer Transfer bei breiten Plänen. Die Procedure führt kein fachliches XML-Shredding in Operatorresultsets aus. |
| Begrenzungswirkung | `@MaxAnalyseobjekte` begrenzt Kandidaten vor der planweisen Detailauflösung; 0 bedeutet unbegrenzt. Das SQL-Textzeichenlimit begrenzt nur Textbreite. Einen separaten Ergebniszeilen- oder Deadlineparameter besitzt diese Procedure nicht. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung; Live-Plan-Zugriff beobachtet aktive Requests und Cachehandles können verschwinden. XML-Auswertung kann Schedulerzeit verbrauchen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Genau einen `ExampleQueryHash`/PlanHandle oder eine synthetische Session, maximal fünf Candidates und zunächst nur Compile-Plan. Last-Actual/Live separat und bewusst anfordern; einen `VOLL`-Modus gibt es nicht. |
| Aussagegrenze | Ein Planhandle kann zwischen Candidate- und Detailauflösung verschwinden. Last Actual existiert nur bei bereits aktivierter Engineerfassung; Live zeigt den laufenden Zeitpunkt. Fehlendes XML bedeutet deshalb nicht „kein Plan“ und Candidate-TOP keine repräsentative Planmenge. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Attribute, Texte, Statements und Planinformationen gehören zu einem konkreten Handle?

### Technischer Hintergrund

SQL-/Planhandles referenzieren flüchtige Cacheobjekte. Plan Attributes enthalten DBID, Set Options, User-/Languagekontext und weitere Cachekeyeinflüsse. Unterschiedliche SET Options können separate Pläne derselben Textform erzeugen.

### Datenkette

`sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml`, `sys.dm_exec_query_stats`, `sys.dm_exec_requests`, `sys.dm_exec_sql_text`, `sys.dm_exec_text_query_plan`.

### Zeit- und Scope-Modell

Momentaufnahme eines Cacheeintrags. Handle kann zwischen Auswahl und Detailabruf evicted werden.

### Bewertung und Gegenprobe

Plan Attributes, Statementoffset, Creation/Last Execution, Use Count und XML gemeinsam lesen. Set-Option-Unterschiede können scheinbare Planverdoppelung erklären.

### Typische Fehlinterpretation

Ein Handle ist keine persistente Referenz und darf nicht langfristig gespeichert werden, ohne Gültigkeitsprüfung.

### Folgeanalyse

`USP_ShowplanAnalysis`; Query Store IDs für dauerhaftere Korrelation.

## Primärquellen

- [sys.dm_exec_query_plan](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-plan-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#4-monitorusp_plandetails)
