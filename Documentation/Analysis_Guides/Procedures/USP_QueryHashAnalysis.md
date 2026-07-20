# [monitor].[USP_QueryHashAnalysis]

**Bereich:** Plan Cache<br>
**Zweck:** Aggregiert Cachezeilen je Query Hash und zeigt Planvarianten, Handles und Ressourcen.<br>
**Beobachtungsart:** kumulativ je aktuellem Cacheeintrag<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Varianten derselben normalisierten Queryform und welche Planformen liegen aktuell im Cache?** Der dokumentierte Zweck ist: Aggregiert Cachezeilen je Query Hash und zeigt Planvarianten, Handles und Ressourcen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Nur aktuell gecachte Einträge; verschiedene Creation Times und Evictions. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryHashAnalysis]
      @AnalyseModus = 'TOP',
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Ohne konkreten `@QueryHash` ist auch der begrenzte TOP-Einstieg als `PLAN_CACHE_DEEP` geschützt. Die Bestätigung schaltet nur das Gate frei; `@MaxZeilen` begrenzt vor allem die Ausgabe und ist kein Beweis für nur 100 gelesene Cachezeilen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `queryHashes` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Hash-Gruppe über die aktuell sichtbaren Cachezeilen. Historisch evictete Varianten fehlen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`PlanVariantCount`, `PlanHandleCount`, Ausführungen, Cachefenster und Ressourcen der dominanten Varianten vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele Planvarianten können Parameter Sensitivity oder unterschiedliche Compilekontexte anzeigen. Viele Handles bei gleichem Plan Hash können Cachebloat bedeuten.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

SET-Optionen, Datenbankkontexte oder bewusstes Recompile können legitime Varianten erzeugen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Acht Varianten, aber eine verursacht 99 % der CPU: Nicht die Anzahl, sondern die dominante Variante priorisieren. Einzelne Handles mit `USP_PlanDetails`, Historie mit Query Store prüfen.

**Ähnlich aussehender Gegenfall:** SET-Optionen, Datenbankkontexte oder bewusstes Recompile können legitime Varianten erzeugen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_QueryHashAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gruppiert sys.dm_exec_query_stats. Ohne konkreten @QueryHash sowie im Modus VOLL wird PLAN_CACHE_DEEP geprüft. Text wird nur für gewählte Hashes geladen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ein konkreter `@QueryHash`, TOP 100 und auf 4000 Zeichen gekürzter SQL-Text; Text wird erst für die ausgewählten Hashgruppen geladen. |
| Teuerster Pfad | Kein QueryHash, `VOLL` beziehungsweise unbegrenzte/hohe Ausgabe und ungekürzte Texte: der gesamte `sys.dm_exec_query_stats`-Bestand wird nach Hash gruppiert und gerankt. |
| Haupttreiber | Zahl aktueller `dm_exec_query_stats`-Einträge, ihre Gruppierung je Query Hash und optional aufgelöster SQL-Text. Ohne Hash-/Datenbankfilter muss der aktuelle Cache vor Ranking und Limit breit aggregiert werden. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_QueryHashAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für Cache-DMV-Scan, Textauflösung, Gruppierung und Sortierung; Ergebnistransfer bei langen Texten. |
| Begrenzungswirkung | TOP begrenzt die Rückgabe, doch Ranking, Hashaggregation oder Cachekategorie kann zuvor viele Cachezeilen lesen. Früh wirkende Datenbank-/Hashfilter sind wertvoller. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks. Cacheeinträge können während des Lesens evicted oder neu kompiliert werden; Text-/Attributauflösung ist daher nicht atomar. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Einen konkreten synthetisch dargestellten QueryHash und kleines Limit verwenden. Der dokumentierte unselektierte TOP-Einstieg benötigt bereits `PLAN_CACHE_DEEP`; `VOLL`/unbegrenzt erst nach Cachegrößenprüfung. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „kumulativ je aktuellem Cacheeintrag“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Varianten derselben normalisierten Queryform und welche Planformen liegen aktuell im Cache?

### Technischer Hintergrund

Grouping nach Query Hash konsolidiert ähnliche Statementtexte; Plan Hash trennt physische Planformen. Aggregationen zeigen Planvielfalt, Lastverteilung und mögliche Ad-hoc-/Parameterisierungsvarianten.

### Datenkette

`sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`.

### Zeit- und Scope-Modell

Nur aktuell gecachte Einträge; verschiedene Creation Times und Evictions.

### Bewertung und Gegenprobe

Plananzahl, Execution Count, Total/Avg-Kosten, Text-/Parameterkontext und Creation Time vergleichen. Mehrere Plan Hashes können legitime Recompile-/SET-/Compatibilitykontexte oder Parameter Sensitivity zeigen.

### Typische Fehlinterpretation

Gleicher Hash garantiert keine fachliche Gleichheit; Hashkollisionen sind theoretisch möglich. Ein fehlender alter Plan ist keine Stabilitätsevidenz.

### Folgeanalyse

Query Store PlanChanges/RuntimeStats und Showplanvergleich.

## Primärquellen

- [sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#2-monitorusp_queryhashanalysis)
