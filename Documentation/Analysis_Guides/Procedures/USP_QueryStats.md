# [monitor].[USP_QueryStats]

**Bereich:** Plan Cache<br>
**Zweck:** Rangiert aktuell gecachte Statements nach CPU, Dauer, I/O, Ausführungen, Grants, Spills oder Zeilen.<br>
**Beobachtungsart:** kumulativ je aktuellem Cacheeintrag<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche aktuell gecachten Statements verursachten kumulativ oder durchschnittlich CPU, Dauer, Reads und Writes?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStats]
      @Sortierung = 'CPU_TOTAL',
      @MaxZeilen = 50,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter Datenbanknamen; NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. &#124; trennt außerhalb von [...]; ]] maskiert ] innerhalb; äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen; ungültige Liste INVALID_PARAMETER. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL führt zur Parameterablehnung; ausgelassen = 0. SQL-bit-Konvertierung kann numerische Nichtnullwerte als 1 abbilden. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung; äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern; leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 lässt den hohen Aufwand unbestätigt. 1 bestätigt einen geschützten Pfad. Die Berechtigung wird zusätzlich geprüft. NULL ist für die Pfadprüfung ungültig. |
| `@QueryHash` | `binary(8)` | `NULL` | Optionaler exakter 8-Byte Query Hash; NULL = kein Hashfilter. Andere Längen/Typkonvertierungen richten sich nach T-SQL-Bindung; keine zusätzliche Hexstring-Validierung im Procedurecode. |
| `@QueryPlanHash` | `binary(8)` | `NULL` | Optionaler exakter 8-Byte Planhash; NULL = kein Planhashfilter. |
| `@SqlHandle` | `varbinary(64)` | `NULL` | Optionaler SQL-Handle bis 64 Byte; NULL = kein Handlefilter. |
| `@PlanHandle` | `varbinary(64)` | `NULL` | Optionaler Plan-Handle bis 64 Byte; NULL = kein Handlefilter. |
| `@TextPattern` | `nvarchar(4000)` | `NULL` | SQL-Textpattern. NULL = kein Filter; Parser erkennt case-insensitive like:, regex:, regexi:, sonst LIKE. Außenleerzeichen getrimmt, Patternrest nicht. Leerer effektiver Inhalt INVALID_PARAMETER. Nicht als Pipe-Liste zerlegt. LIKE nutzt %/_/SQL LIKE-Syntax; Regex braucht SQL Server 2025 und Installations-DB-Kompatibilität 170, Syntaxfehler werden von Regex-Ausführung gemeldet. |
| `@Sortierung` | `varchar(32)` | `'CPU_TOTAL'` | Case-insensitive nach LTRIM/RTRIM; geschlossene Menge: CPU_TOTAL = kumulative CPU; CPU_AVG = CPU je Ausführung; ELAPSED_TOTAL = kumulative Laufzeit; ELAPSED_AVG = Laufzeit je Ausführung; READS_TOTAL = kumulative logische Reads; READS_AVG = logische Reads je Ausführung; WRITES_TOTAL = kumulative logische Writes; WRITES_AVG = logische Writes je Ausführung; EXECUTIONS = Ausführungszahl; GRANT_MAX = maximaler Grant; SPILLS_TOTAL = kumulative Spills; ROWS_TOTAL = kumulative Zeilen; LAST_EXECUTION = letzte Ausführungszeit. NULL normalisiert auf Default. Ungültiger Wert INVALID_PARAMETER. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | TOP verwendet bei einem positiven Limit bis 1000 den aktuellen Plan-Cache-Pfad. VOLL prüft PLAN_CACHE_DEEP und behält das Zeilenlimit bei. NULL entspricht TOP. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER. |
| `@MinExecutionCount` | `bigint` | `1` | Ganzzahliges Minimum für execution_count. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Zeile. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Inklusiver Grenzwert für last_execution_time als datetime2-Wert, z. B. 2026-01-01T00:00:00. Die Procedure vergleicht direkt mit dem Cachewert und rechnet keine Zeitzone um. NULL lässt den Zeitfilter aus. |
| `@MaxZeilen` | `int` | `100` | Positiv begrenzt Ausgabe; NULL oder 0 bedeutet unbegrenzt; negativ INVALID_PARAMETER. Ausgelassen = 100. Unbegrenzt oder >1000 sowie VOLL erfordern PLAN_CACHE_DEEP. Positive Auswahl sammelt bis Limit+1 zur HasMoreRows-Ermittlung. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Positiv kürzt Statement- und Batchtext auf Zeichenlimit; NULL oder 0 bedeutet ungekürzt; negativ INVALID_PARAMETER. Zeichenprojektion zählt unter SC-Collation, nicht Grapheme. |
| `@ParentQueryStatsSnapshot` | `bit` | `0` | 0 = DMV frisch lesen; 1 = ausschließlich laufinterne Wiederverwendung durch USP_PlanCacheAnalysis. NULL INVALID_PARAMETER. Schalter ist kein öffentlicher externer Snapshotvertrag. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | CONSOLE zeigt die beschriftete Abfrageauswahl. RAW liefert Modulstatus, Abfragezeilen und Auswahlwarnungen. TABLE schreibt das benannte Resultset queries. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel queries und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 deaktiviert JSON. NULL ergibt INVALID_PARAMETER. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit meta, queries und warnings. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen. |
| `@Hilfe` | `bit` | `0` | 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort. |

## Aufrufbeispiele

Hilfe anzeigen.

```sql
EXEC [monitor].[USP_QueryStats] @Hilfe=1;
```

Technische Resultsets lesen.

```sql
EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';
```

Nur JSON ausgeben.

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

Benanntes Resultset in eine lokale Temp-Tabelle schreiben.

```sql
CREATE TABLE #QueryStats_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"queries":"#QueryStats_HelpExample"}';
SELECT * FROM #QueryStats_HelpExample;
DROP TABLE #QueryStats_HelpExample;
END TRY BEGIN CATCH DROP TABLE #QueryStats_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `queries` mit 60 Feldern, fünf expliziten Frameworktextcollations und ohne Identity. RAW und JSON projizieren 59 Felder ohne `SortValue`; die aktive CONSOLE ergänzt die 60 Felder um `Ergebnis` und liefert damit 61 Felder. Eine leere CONSOLE verwendet den bestehenden Dreifeldvertrag `Ergebnis`, `Status`, `Hinweis`. RAW liefert außerdem den neunfeldrigen Modulstatus und die dreifeldrigen Auswahlwarnings; JSON enthält `meta`, `queries` und `warnings` mit zehn Metafeldern einschließlich NULL-Werten. Zusätzliche Helperproben können davor leere Resultsets liefern.

Alle vier Fachausgaben verwenden dieselbe begrenzte Resultmenge. Die Auswahl erfolgt nach `SortValue DESC, LastExecutionTime DESC`; RAW und JSON sortieren diese Menge ausdrücklich. TABLE und der aktive CONSOLE-Helper versprechen keine Ausgabeordnung. Vollständig gleiche Sortschlüssel erhalten keinen zusätzlichen Tie-Breaker und können zwischen Aufrufen verschieden ausgewählt werden. `NULL` oder 0 als Zeilenlimit bleibt unbegrenzt und prüft den bestehenden `PLAN_CACHE_DEEP`-Pfad.

Der begrenzte Pfad sammelt bis zu Limit plus eins, projektiert Statement- und Batchtext und bewertet anschließend `HasMoreRows`, bevor er den zusätzlichen Kandidaten aus der gemeinsamen Ausgabe entfernt. Metadaten und Trunkierungswarnings behalten diese vorangehende Bewertung; sie behaupten keine vollständige Zählung des gesamten Plan Cache. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen.

## Eine Zeile bedeutet

Eine Zeile entspricht einer aktuell gecachten Statementinstanz. Derselbe logische Querytext kann durch unterschiedliche Handles, SET-Optionen oder Pläne mehrfach erscheinen.

## So lesen

Betrachten Sie zuerst Cachefenster (`CreationTime`, `LastExecutionTime`) und `ExecutionCount`, danach Total-, Average-, Max- und Lastwerte getrennt.

## Warum kann das problematisch sein?

Totalwerte zeigen Gesamtauswirkung, Maxwerte Ausreißer und Averagewerte systematische Kosten. Hohe Reads bei wenigen Ergebniszeilen können ineffizienten Zugriff anzeigen.

## Wann ist es kein Problem?

Eine einmalige administrative Query darf hohe Maxwerte besitzen, ohne die normale Workload wesentlich zu belasten.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Million Ausführungen zu je 2 ms verursachen mehr Gesamtlast als eine einmalige 10-Minuten-Query. Prüfen Sie Query Hash, Plan Details, Showplan und Query Store.

**Ähnlich aussehender Gegenfall:** Eine einmalige administrative Query darf hohe Maxwerte besitzen, ohne die normale Workload wesentlich zu belasten. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_QueryStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Der Plan Cache ist flüchtig. Recompile, Eviction oder Restart können relevante Queries entfernen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | TOP 100 aus `sys.dm_exec_query_stats`, nach CPU sortiert und mit auf 4000 Zeichen gekürztem SQL-Text; optionaler Datenbank-/Hashfilter kann den Kandidatenscope weiter eingrenzen. |
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

**Wichtig für die Eigenlast:** Hash, Handle, Ausführungsanzahl und Zeit wirken vor Sortierung. Datenbank- und Textfilter benötigen erst Handle-/Textauflösung; Regex wirkt im dynamischen Quellselect vor Materialisierung und TOP-Auswahl. `@MaxZeilen` begrenzt nicht automatisch den Cache-Scan.

### Zeit- und Scope-Modell

Die Zähler sind seit der Erstellung des Cacheeintrags kumulativ. Erstellungszeit, letzte Ausführung und Engine-Start begrenzen das Fenster.

### Bewertung und Gegenprobe

Totalwerte zeigen die Gesamtkosten, während Durchschnittswerte teure Einzelausführungen sichtbar machen. Berücksichtigen Sie immer auch Execution Count, Cachealter, Rowcount und Last Execution.

### Typische Fehlinterpretation

Ein kleiner Totalwert kann nur kurzen Cachelebenszyklus bedeuten. Durchschnitt verdeckt Ausreißer und Parameter Sensitivity.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Query Hash, Showplan und Query Store für persistierte Historie.

## Primärquellen

- [sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#1-monitorusp_querystats)
