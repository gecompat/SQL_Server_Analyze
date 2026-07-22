# [monitor].[USP_FullTextAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet sichtbare Full-Text-Kataloge, -Indizes und aggregierte Laufzeitmetadaten ohne indizierte Inhalte, Suchbegriffe, Crawl-Logs, Pfade oder Zustandsänderung.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie sind Full-Text Catalogs/Indexes konfiguriert, und laufen Population/Change Tracking ohne sichtbare Fehler oder Rückstand?** Der dokumentierte Zweck ist: Bewertet sichtbare Full-Text-Kataloge, -Indizes und aggregierte Laufzeitmetadaten ohne indizierte Inhalte, Suchbegriffe, Crawl-Logs, Pfade oder Zustandsänderung. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Metadaten-/Populationzustand plus begrenzte Crawl-/Errorhistorie. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_FullTextAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der Full-Text-Katalogpfad ist vollständig als `CATALOG_DEEP` geschützt. Die Bestätigung ist für den engen Aufruf erforderlich; sie erweitert den Scope nicht und erlaubt keinen Zugriff auf indizierte Inhalte.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, Katalog, Full-Text-Index, einer aktuell laufenden Population, einer aggregierten Batchgruppe, einer semantischen Population, einem Speicherpool oder einer FDHost-Typgruppe.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach Index-/Schlüsselindexschalter, Crawl-Kontext, aktuelle Populationen und Batches gemeinsam lesen. Fragmentanzahl und logische Größe sind Heuristik- beziehungsweise Kapazitätskontext; Memory Pools und FDHosts sind serverweit und keiner einzelnen Datenbank exklusiv zurechenbar.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Deaktivierte Indizes, abgebrochene Populationen, Batchfehler oder fehlgeschlagene Dokumente können Suchaktualität und Auffindbarkeit begrenzen. Viele querybare Fragmente können die Abfrageleistung verschlechtern. Ein langer Lauf oder eine große Batchzahl beweist jedoch keinen Stillstand.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

`MANUAL` oder `OFF` beim Change Tracking kann bewusst gewählt sein. Ein initialer Full Crawl kann durch `NO POPULATION` absichtlich ausstehen. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Status 7 kann während eines automatischen Merge auftreten. Es existiert kein universeller Fragment- oder Laufzeitgrenzwert.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Population über dem Altersgrenzwert mit weiter steigendem Fortschritt ist eher ein Kapazitäts- als ein Stillstandsfall. Erst bei wiederholt fehlendem Fortschritt zusätzlich Batches, I/O, Log und geschützte Full-Text-/Crawl-Logs in der Laufzeitumgebung korrelieren. Reale Logdaten oder interne Strukturen nur kontrolliert speichern und weitergeben.

**Ähnlich aussehender Gegenfall:** `MANUAL` oder `OFF` beim Change Tracking kann bewusst gewählt sein. Ein initialer Full Crawl kann durch `NO POPULATION` absichtlich ausstehen. Population-, Batch- und FDHost-DMVs sind Momentaufnahmen; Status 7 kann während eines automatischen Merge auftreten. Es existiert kein universeller Fragment- oder Laufzeitgrenzwert. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_FullTextAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Eine leere Population-DMV ist weder Abschlussnachweis noch Historie. Fehlende DMV-Rechte lassen zugängliche Katalog- und Fragmentevidenz gültig; die Procedure kennzeichnet die Lücke über `IsPartial` und `SourceStatus`. `NOT_APPLICABLE_VISIBLE_SCOPE` beweist bei eingeschränkter Metadatensichtbarkeit keine vollständige Abwesenheit.

## Eigenlast und Grenzen

MEDIUM: sichtbare Kataloge, Fragmente und aggregierte Full-Text-DMVs. Es werden keine Tabellenzeilen, Keywords, Stopwords, Parser-Eingaben, Schlüsselwerte, Crawl-Logs oder Pfade gelesen und kein `ALTER FULLTEXT` ausgeführt.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und endliches Limit; Kataloge, Indizes und aktuelle aggregierte Full-Text-Runtimequellen werden einmal gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter und unbegrenzte Ausgabe bei vielen Katalogen, Indizes, Fragmenten, Populationen, Outstanding Batches und semantischen Populationen. |
| Haupttreiber | Zahl gewählter Datenbanken, Full-Text-Kataloge/-Indizes und aktueller Population-, FDHost- und Memory-Pool-Zeilen. Indizierte Dokumente, Suchbegriffe und Crawl-Logs liegen außerhalb des Pfads und skalieren die Abfrage nicht direkt. |
| Skalierung | Quellarbeit wächst mit Full-Text-Objekten, Fragmenten und aktuellen Population-/Batchzeilen. Serverweite Memory-Pool-/FDHost-Quellen bleiben meist klein; Ausgabe und Sortierung wachsen mit allen materialisierten Detailtabellen. |
| Ressourcen | CPU, Katalog-/Full-Text-DMV-I/O, dynamisches SQL je Datenbank und TempDB/Arbeitsspeicher für isolierte Detailtabellen und Findings. Keine indizierten Inhalte oder Crawl-Logs. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen Katalog- und datenbankbezogene DMV-Arbeit. `@NurProblematisch` und `@MaxZeilen` werden erst bei der Ausgabe jedes Resultsets angewandt; sie verhindern das vorherige Lesen/Aggregieren der Full-Text-Quellen nicht. |
| Locking und Nebenwirkungen | Read-only ohne `ALTER FULLTEXT`; Kataloge und flüchtige Runtime-DMVs werden nicht atomar gelesen. Eine laufende Population kann ihren Status zwischen Teilquellen ändern. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und möglichst Objektfilter. Erst Quellenstatus, dann Katalog/Index, Populationen und Batches lesen; serverweite Kapazität zuletzt korrelieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime- und Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Full-Text Catalogs/Indexes konfiguriert, und laufen Population/Change Tracking ohne sichtbare Fehler oder Rückstand?

### Technischer Hintergrund

Full-Text Engine tokenisiert sprachabhängig, speichert invertierte Indizes in Catalogs und aktualisiert sie über Full/Incremental/Auto Population. Stoplists, Search Properties und Change Tracking beeinflussen Inhalt. Population DMVs zeigen aktive Crawls/Phasen.

### Datenkette

`sys.dm_fts_fdhosts`, `sys.dm_fts_index_population`, `sys.dm_fts_memory_pools`, `sys.dm_fts_outstanding_batches`, `sys.dm_fts_semantic_similarity_population`, `sys.fulltext_catalogs`, `sys.fulltext_index_columns`, `sys.fulltext_index_fragments`, `sys.fulltext_indexes`, `sys.indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Der Katalogkern verbindet Full-Text-Index, Basistabelle, Schema, Katalog und Key-Index:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [fc].[name] AS [FullTextCatalogName]
    , [i].[name] AS [KeyIndexName]
    , [fi].[change_tracking_state_desc]
FROM [sys].[fulltext_indexes] AS [fi] WITH (NOLOCK)
JOIN [sys].[tables] AS [t] WITH (NOLOCK)
  ON [t].[object_id] = [fi].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
LEFT JOIN [sys].[fulltext_catalogs] AS [fc] WITH (NOLOCK)
  ON [fc].[fulltext_catalog_id] = [fi].[fulltext_catalog_id]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [fi].[object_id]
 AND [i].[index_id] = [fi].[unique_index_id]
WHERE [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Objektfilter vor Fragment- und Population-DMVs setzen. `sys.fulltext_index_fragments` und Outstanding-/Population-Details erst für verbleibende Full-Text-Indizes lesen.

### Zeit- und Scope-Modell

Aktueller Metadaten-/Populationzustand plus begrenzte Crawl-/Errorhistorie.

### Bewertung und Gegenprobe

Catalog/Index, Change Tracking State, Population Type/Status, Start/End, Items processed/failed, Fragmentcount, Language/Stoplist und Base-Table-Änderung korrelieren. Querybedarf bestimmt Dringlichkeit.

### Typische Fehlinterpretation

`IDLE` kann erfolgreich fertig oder nie gestartet bedeuten. Ein vorhandener Full-Text-Index garantiert keine aktuelle Vollständigkeit oder semantisch passende Wordbreaker.

### Folgeanalyse

Full-Text Crawl Logs/Errorlog, Job/Populationstart und konkrete CONTAINS-Query.

## Primärquellen

- [Full-Text Search](https://learn.microsoft.com/en-us/sql/relational-databases/search/full-text-search?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#6-monitorusp_fulltextanalysis)
