# [monitor].[USP_QueryHashAnalysis]

**Bereich:** Plan Cache<br>
**Zweck:** Aggregiert Cachezeilen je Query Hash und zeigt Planvarianten, Handles und Ressourcen.<br>
**Beobachtungsart:** kumulativ je aktuellem Cacheeintrag<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Varianten derselben normalisierten Queryform und welche Planformen liegen aktuell im Cache?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryHashAnalysis]
      @AnalyseModus = 'TOP',
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Ohne konkreten `@QueryHash` ist auch der begrenzte TOP-Einstieg als `PLAN_CACHE_DEEP` geschützt. Die Bestätigung schaltet nur das Gate frei; `@MaxZeilen` begrenzt vor allem die Ausgabe und ist kein Beweis für nur 100 gelesene Cachezeilen.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@QueryHash` | `binary(8)` | `NULL` | Optionaler Filter auf genau diesen 8-Byte-query_hash. NULL aggregiert alle Hashes und aktiviert PLAN_CACHE_DEEP; für einen einzelnen Hash wird dieser breite Pfad vermieden. Ein angegebener Hash kann im aktuellen Cache fehlen. |
| `@Sortierung` | `varchar(32)` | `'CPU_TOTAL'` | CPU_TOTAL ordnet nach kumulierter CPU, ELAPSED_TOTAL nach kumulierter Laufzeit, READS_TOTAL nach logischen Reads, WRITES_TOTAL nach logischen Writes, EXECUTIONS nach Ausführungszahl, PLAN_VARIANTS nach Anzahl verschiedener Plan-Hashes und SPILLS_TOTAL nach kumulierten Spills. Auswahl absteigend und bei Gleichstand nach letzter Ausführung absteigend. NULL entspricht CPU_TOTAL. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER. |
| `@AnalyseModus` | `varchar(16)` | `'TOP'` | TOP prüft bei angegebenem Query Hash und positivem Limit bis 1000 keinen tiefen Pfad. VOLL prüft PLAN_CACHE_DEEP. Das Zeilenlimit gilt in beiden Modi. NULL entspricht TOP. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER. |
| `@MinExecutionCount` | `bigint` | `1` | Ganzzahliges Minimum der Summe der Ausführungen je Hash. 0 lässt auch Gruppen mit Summe 0 zu. Bei NULL trifft der Vergleich auf keine Gruppe. Negative Werte ergeben INVALID_PARAMETER. |
| `@MinPlanVarianten` | `int` | `1` | Mindestens 1 verschiedener query_plan_hash je Query Hash. Bei NULL trifft der Vergleich auf keine Gruppe. Werte unter 1 ergeben INVALID_PARAMETER. |
| `@MaxZeilen` | `int` | `100` | Maximale Zahl der Hash-Gruppen. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt und aktiviert damit PLAN_CACHE_DEEP. Negative Werte sind ungültig; mehr als 1000 Zeilen aktiviert ebenfalls den geschützten Pfad. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Maximale Unicode-Zeichenlänge des Beispielstatements. Positiv kürzt und kennzeichnet den Text; NULL oder 0 lässt ihn vollständig. Negative Werte sind ungültig. |
| `@ParentQueryStatsSnapshot` | `bit` | `0` | 0 liest die DMV frisch. 1 liest ausschließlich den lokalen Snapshot des laufenden Aufrufs von USP_PlanCacheAnalysis. Fehlt er, meldet die Analyse ERROR_HANDLED. NULL ergibt INVALID_PARAMETER. |
| `@HighImpactConfirmed` | `bit` | `0` | Muss für einen aktivierten PLAN_CACHE_DEEP-Pfad 1 sein und bestätigt den Hochaufwandspfad; zusätzlich gelten dessen aktuelle Freigabe und Berechtigungen. 0 oder NULL lässt den geschützten Pfad nicht zu. Bei einem einzelnen Hash im TOP-Modus mit höchstens 1000 Zeilen wird dieser Gate nicht aktiviert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | CONSOLE zeigt die beschrifteten Hashgruppen. RAW liefert Modulstatus und Hashgruppen. TABLE schreibt das benannte Resultset queryHashes. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel queryHashes und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 oder NULL deaktiviert JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit meta, queryHashes und warnings. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen. |
| `@Hilfe` | `bit` | `0` | 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort. |

## Aufrufbeispiele

Hilfe anzeigen.

```sql
EXEC [monitor].[USP_QueryHashAnalysis] @Hilfe=1;
```

Technische Resultsets lesen.

```sql
EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';
```

Nur JSON ausgeben.

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

Benanntes Resultset in eine lokale Temp-Tabelle schreiben.

```sql
CREATE TABLE #QueryHashAnalysis_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHashes":"#QueryHashAnalysis_HelpExample"}';
SELECT * FROM #QueryHashAnalysis_HelpExample;
DROP TABLE #QueryHashAnalysis_HelpExample;
END TRY BEGIN CATCH DROP TABLE #QueryHashAnalysis_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `queryHashes`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW liefert den neunfeldrigen Modulstatus und die 20 Hashfelder. TABLE schreibt ausschließlich `queryHashes`; die aktive CONSOLE ergänzt diese 20 Felder um `Ergebnis` und liefert bei leerer Menge die bestehende dreifeldrige Leeranzeige. JSON besitzt `meta` mit neun Feldern, `queryHashes` und das vorhandene leere `warnings`-Array. Alle vier Fachausgaben verwenden dieselbe materialisierte Menge. `SampleStatementText` ist explizit `SQL_Latin1_General_CP1_CS_AS` collatiert; der Export besitzt keine Identity.

Die Auswahl verwendet den angeforderten Ressourcenrang absteigend und danach `LastExecutionTime` absteigend. Vollständig gleiche Sortschlüssel erhalten keinen zusätzlichen Tiebreaker. RAW und JSON sortieren die gewählte Menge ausdrücklich; TABLE und die aktive CONSOLE garantieren keine Anzeigeordnung. `@MaxZeilen` NULL oder 0 ist unbegrenzt. Negative Zeilen- oder Textlimits liefern `INVALID_PARAMETER`; der Unicode-Projektionshelper wird bei negativem Textlimit nicht aufgerufen.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-Hash-Gruppe über die aktuell sichtbaren Cachezeilen. Historisch evictete Varianten fehlen.

## So lesen

Vergleichen Sie `PlanVariantCount`, `PlanHandleCount`, Ausführungen, Cachefenster und Ressourcen der dominanten Varianten.

## Warum kann das problematisch sein?

Viele Planvarianten können Parameter Sensitivity oder unterschiedliche Compilekontexte anzeigen. Viele Handles bei gleichem Plan Hash können Cachebloat bedeuten.

## Wann ist es kein Problem?

SET-Optionen, Datenbankkontexte oder bewusstes Recompile können legitime Varianten erzeugen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Acht Varianten, aber eine verursacht 99 % der CPU: Nicht die Anzahl, sondern die dominante Variante priorisieren. Prüfen Sie Einzelne Handles mit `USP_PlanDetails`, Historie mit Query Store.

**Ähnlich aussehender Gegenfall:** SET-Optionen, Datenbankkontexte oder bewusstes Recompile können legitime Varianten erzeugen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_QueryHashAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Procedure gruppiert `sys.dm_exec_query_stats`. Ohne konkreten `@QueryHash` sowie im Modus VOLL wird `PLAN_CACHE_DEEP` geprüft. Text wird nur für gewählte Hashes geladen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne expliziten Hashfilter wird der sichtbare Cache im Modus TOP mit Limit 100 und höchstens 4000 Textzeichen ausgewertet; dieser Defaultscope prüft `PLAN_CACHE_DEEP`. Ein konkreter Hash ist eine gezielte Einstiegswahl, kein Parameterdefault. |
| Teuerster Pfad | Kein QueryHash, `VOLL` beziehungsweise unbegrenzte/hohe Ausgabe und ungekürzte Texte: der gesamte `sys.dm_exec_query_stats`-Bestand wird nach Hash gruppiert und gerankt. |
| Haupttreiber | Zahl aktueller `dm_exec_query_stats`-Einträge, ihre Gruppierung je Query Hash und optional aufgelöster SQL-Text. Ohne Hashfilter wird der aktuelle Cache vor Ranking und Limit breit aggregiert. Die Procedure besitzt keinen Datenbankfilter. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_QueryHashAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für Cache-DMV-Scan, Textauflösung, Gruppierung und Sortierung; Ergebnistransfer bei langen Texten. |
| Begrenzungswirkung | TOP begrenzt die gewählten Hashgruppen nach Ranking, nicht den vorherigen Snapshotread. Der exakte Hashfilter wirkt bereits vor der Aggregation. |
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

### Source Select

Ein exakter Query Hash begrenzt die Query-Stats-Kandidaten vor Textprojektion und Variantenaggregation:

```sql
SELECT
      [qs].[query_hash]
    , COUNT(DISTINCT [qs].[query_plan_hash]) AS [PlanVariantCount]
    , COUNT(DISTINCT [qs].[plan_handle]) AS [PlanHandleCount]
    , COUNT_BIG(*) AS [CompilationCount]
    , SUM([qs].[execution_count]) AS [ExecutionCount]
    , SUM([qs].[total_worker_time]) AS [TotalWorkerTime]
    , SUM([qs].[total_logical_reads]) AS [TotalLogicalReads]
FROM [sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)
WHERE [qs].[query_hash] = @QueryHash
GROUP BY [qs].[query_hash];
```

**Wichtig für die Eigenlast:** Setzen Sie den öffentlichen `@QueryHash`, um die Erhebung zu begrenzen. `@SqlHandle` und `@PlanHandle` sind keine Parameter dieser Procedure. Ohne Hashfilter wird der breite Plan-Cache-Snapshot gruppiert; ein finales `TOP` spart diesen Scan nicht. `CompilationCount` zählt sichtbare Cachezeilen, keine historisch vollständig erfassten Recompiles.

### Zeit- und Scope-Modell

Die Auswertung berücksichtigt nur aktuell gecachte Einträge; deren Creation Times und Evictions können voneinander abweichen.

`@ParentQueryStatsSnapshot=1` ist der laufinterne Wiederverwendungspfad des Plan-Cache-Orchestrators. Er liest dessen lokale `#PlanCacheAnalysis_QueryStatsSnapshot` statt die DMV erneut abzufragen. Der Parent verwendet den Snapshot bei mindestens zwei geeigneten Consumern; ein einzelner Consumer liest frisch. Ein fehlender Parent-Snapshot liefert den bestehenden `ERROR_HANDLED`-Status. Die Datenbankauswahl des Parents ist kein zusätzlicher Datenbankfilter für diesen Hashchild.

### Bewertung und Gegenprobe

Vergleichen Sie Plananzahl, Execution Count, Total/Avg-Kosten, Text-/Parameterkontext und Creation Time. Mehrere Plan Hashes können legitime Recompile-/SET-/Compatibilitykontexte oder Parameter Sensitivity zeigen.

### Typische Fehlinterpretation

Gleicher Hash garantiert keine fachliche Gleichheit; Hashkollisionen sind theoretisch möglich. Ein fehlender alter Plan ist keine Stabilitätsevidenz.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Query Store PlanChanges/RuntimeStats und Showplanvergleich.

## Primärquellen

- [sys.dm_exec_query_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#2-monitorusp_queryhashanalysis)
