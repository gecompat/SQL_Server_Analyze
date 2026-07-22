# [monitor].[USP_QueryStats]

**Bereich:** Plan Cache<br>
**Zweck:** Rangiert aktuell gecachte Statements nach CPU, Dauer, I/O, Ausführungen, Grants, Spills oder Zeilen.<br>
**Beobachtungsart:** kumulativ je aktuellem Cacheeintrag<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche aktuell gecachten Statements verursachten kumulativ oder durchschnittlich CPU, Dauer, Reads und Writes?** Der dokumentierte Zweck ist: Rangiert aktuell gecachte Statements nach CPU, Dauer, I/O, Ausführungen, Grants, Spills oder Zeilen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Kumulativ seit Cacheeintrag. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStats]
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 50,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `queries` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer aktuell gecachten Statementinstanz. Derselbe logische Querytext kann durch unterschiedliche Handles, SET-Optionen oder Pläne mehrfach erscheinen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Cachefenster (`CreationTime`, `LastExecutionTime`) und `ExecutionCount`, danach Total-, Average-, Max- und Lastwerte getrennt betrachten.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Totalwerte zeigen Gesamtauswirkung, Maxwerte Ausreißer und Averagewerte systematische Kosten. Hohe Reads bei wenigen Ergebniszeilen können ineffizienten Zugriff anzeigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine einmalige administrative Query darf hohe Maxwerte besitzen, ohne die normale Workload wesentlich zu belasten.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Million Ausführungen zu je 2 ms verursachen mehr Gesamtlast als eine einmalige 10-Minuten-Query. Query Hash, Plan Details, Showplan und Query Store prüfen.

**Ähnlich aussehender Gegenfall:** Eine einmalige administrative Query darf hohe Maxwerte besitzen, ohne die normale Workload wesentlich zu belasten. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_QueryStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Der Plan Cache ist flüchtig. Recompile, Eviction oder Restart können relevante Queries entfernen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | TOP 50 aus `sys.dm_exec_query_stats`, nach CPU sortiert und mit auf 4000 Zeichen gekürztem SQL-Text; optionaler Datenbank-/Hashfilter kann den Kandidatenscope weiter eingrenzen. |
| Teuerster Pfad | `VOLL` beziehungsweise >1000/unbegrenzt, kein Query-/Datenbankfilter, ungekürzte Texte und Regex über einen sehr großen Plan Cache. Dieser Pfad prüft `PLAN_CACHE_DEEP`. |
| Haupttreiber | Zahl aktueller Cache-Statementzeilen, gewählte Rangiermetrik sowie Planattribut- und SQL-Textauflösung. Datenbank-/Hashfilter können Kandidaten verkleinern; Regex, Volltext und unbegrenztes Ranking verlagern Arbeit auf den breiten Cachepfad. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_QueryStats ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für Cache-DMV-Scan, Textauflösung, Gruppierung und Sortierung; Ergebnistransfer bei langen Texten. |
| Begrenzungswirkung | TOP begrenzt die Rückgabe, doch Ranking, Hashaggregation oder Cachekategorie kann zuvor viele Cachezeilen lesen. Früh wirkende Datenbank-/Hashfilter sind wertvoller. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks. Cacheeinträge können während des Lesens evicted oder neu kompiliert werden; Text-/Attributauflösung ist daher nicht atomar. |
| Schutzmechanismus | TOP bis 1000 nutzt `PLAN_CACHE_CURRENT` ohne High-Impact-Pflicht. `VOLL`, >1000 oder unbegrenzt prüft `PLAN_CACHE_DEEP` und verlangt `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Kleines Limit, gekürzte Texte und eine Datenbank beziehungsweise ein QueryHash; VOLL/unbegrenzt nur nach Cachegrößenprüfung. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „kumulativ je aktuellem Cacheeintrag“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche aktuell gecachten Statements verursachten kumulativ oder durchschnittlich CPU, Dauer, Reads und Writes?

### Technischer Hintergrund

`sys.dm_exec_query_stats` liefert pro gecachtem Statement Ausführungszahl und Total-/Last-/Min-/Maxwerte. SQL Text und Statementoffsets identifizieren den Ausschnitt; Planhandle/Plan XML beschreiben die gecachte Planform.

### Datenkette

`master.sys.databases`, `sys.dm_exec_cached_plans`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Source Select

Der Grundpfad liest kumulative Statementzähler und löst Text sowie Datenbank-ID aus Handlemetadaten auf:

```sql
SELECT
      [qs].[query_hash]
    , [qs].[query_plan_hash]
    , [qs].[execution_count]
    , [qs].[total_worker_time]
    , [qs].[total_logical_reads]
    , [st].[text]
    , TRY_CONVERT(int, [dbid].[value]) AS [DatabaseId]
FROM [sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)
OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st]
OUTER APPLY
(
    SELECT TOP (1) [pa].[value]
    FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = N'dbid'
) AS [dbid]
WHERE [qs].[execution_count] >= @MinExecutionCount
  AND (@VonUtc IS NULL OR [qs].[last_execution_time] >= @VonUtc)
  AND (@QueryHash IS NULL OR [qs].[query_hash] = @QueryHash);
```

**Wichtig für die Eigenlast:** Hash, Handle, Ausführungsanzahl und Zeit wirken vor Sortierung. Datenbank- und Textfilter benötigen erst Handle-/Textauflösung; Regex wirkt nach Materialisierung. `@MaxZeilen` begrenzt nicht automatisch den Cache-Scan.

### Zeit- und Scope-Modell

Kumulativ seit Cacheeintrag. Erstellung/letzte Ausführung und Engine-Start begrenzen das Fenster.

### Bewertung und Gegenprobe

Totalwerte finden Gesamtkosten, Durchschnittswerte teure Einzelausführungen. Execution Count, Cachealter, Rowcount und Last Execution immer mitlesen.

### Typische Fehlinterpretation

Ein kleiner Totalwert kann nur kurzen Cachelebenszyklus bedeuten. Durchschnitt verdeckt Ausreißer und Parameter Sensitivity.

### Folgeanalyse

Query Hash, Showplan und Query Store für persistierte Historie.

## Primärquellen

- [sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#1-monitorusp_querystats)
