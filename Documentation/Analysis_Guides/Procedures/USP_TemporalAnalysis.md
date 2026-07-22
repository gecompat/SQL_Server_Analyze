# [monitor].[USP_TemporalAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert Temporal-Current-/History-Beziehungen, Retention, Größe, Indizes und Konsistenz.<br>
**Beobachtungsart:** Katalogsnapshot + aktueller Kapazitätszustand<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche system-versioned Tabellen besitzen welche History-, Period-, Retention-, Größen- und Indexkonfiguration?** Der dokumentierte Zweck ist: Analysiert Temporal-Current-/History-Beziehungen, Retention, Größe, Indizes und Konsistenz. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Schemastand plus angesammelte Historydaten innerhalb fachlicher/technischer Retention. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TemporalAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der Katalog- und Größenpfad ist durchgängig als `CATALOG_DEEP` klassifiziert. Die Bestätigung ist auch für eine einzelne Datenbank erforderlich; sie ist keine Freigabe für einen ungefilterten Cross-Database-Lauf.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Temporal-Tabelle, History-Beziehung, Retention-/Cleanup-Evidenz, Index-/Kapazitätsinformation oder einem Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Current-/History-Zuordnung, Historygröße, Retention, Konsistenzstatus, Indexierung und Wachstum vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Unbegrenzte oder wirkungslose Retention kann History stark wachsen lassen; ungeeignete Indizes verteuern Zeitabfragen und Cleanup.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Große History kann fachlich erforderlich und durch Partitionierung oder Archivierung kontrolliert sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** History wächst monatlich stark, Retention ist konfiguriert, Cleanup zeigt aber keine Wirkung: konkreter Betriebsbefund. Kapazität, Partitionierung, Cleanup und Pläne prüfen.

**Ähnlich aussehender Gegenfall:** Große History kann fachlich erforderlich und durch Partitionierung oder Archivierung kontrolliert sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_TemporalAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und möglichst ein Temporal-Objektfilter; Katalogbeziehungen, approximative Partitionsgröße und History-Indexabdeckung werden gelesen. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter und unbegrenzte Ausgabe bei sehr vielen Temporal-/Historytabellen, Partitionen und History-Indizes. Benutzertabellenzeilen werden auch dann nicht gelesen. |
| Haupttreiber | Zahl ausgewählter Datenbanken und Temporal-/Historytabellen, deren Partitionen und History-Indizes. Objektfilter reduzieren diese Katalogmenge früh; Zeilen aus Current- oder Historytabellen werden nicht gelesen. |
| Skalierung | Aufwand wächst mit Temporal-Paaren, ihren Partitionen und History-Indizes. `sys.dm_db_partition_stats` liefert approximative Größen ohne History-Datenscan; dynamisches SQL und Findingregeln laufen je Datenbank. |
| Ressourcen | CPU und Katalog-/Partitionsmetadaten-I/O, dynamischer Compileaufwand und kleine TempDB-/Arbeitstabellen für Temporalpaare, Indizes und Findings. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen Katalog- und Partitionsmetadatenarbeit. `@NurProblematisch` und `@MaxZeilen` wirken erst auf fertige Findings/Detailtabellen und begrenzen die vorgelagerte Inventur nicht. |
| Locking und Nebenwirkungen | Read-only ohne DDL oder Historydatenzugriff; gleichzeitiges `SYSTEM_VERSIONING`-/Index-DDL kann zwischen Katalog- und Größenprobe einen Mischstand erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und ein konkretes Temporalobjekt. Trotz `CATALOG_DEEP`-Bestätigung erst Datenbankstatus und Quellenfehler lesen, dann Größe/Indexbefund bewerten. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot + aktueller Kapazitätszustand“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche system-versioned Tabellen besitzen welche History-, Period-, Retention-, Größen- und Indexkonfiguration?

### Technischer Hintergrund

Temporal Tables schreiben bei Update/Delete frühere Rowversionen in eine History Table; Period Columns definieren Gültigkeit. System Versioning, Data Consistency Check und Retention steuern Lebenszyklus. Historyzugriffe über `FOR SYSTEM_TIME` benötigen passende Indizes/Partitionierung.

### Datenkette

`sys.columns`, `sys.databases`, `sys.dm_db_partition_stats`, `sys.index_columns`, `sys.indexes`, `sys.periods`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

System-versionierte Tabelle, History-Tabelle, Schema und Periodendefinition werden über Katalog-IDs verbunden:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [t].[temporal_type_desc]
    , [hs].[name] AS [HistorySchemaName]
    , [ht].[name] AS [HistoryTableName]
    , [p].[start_column_id]
    , [p].[end_column_id]
FROM [sys].[tables] AS [t] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
LEFT JOIN [sys].[tables] AS [ht] WITH (NOLOCK)
  ON [ht].[object_id] = [t].[history_table_id]
LEFT JOIN [sys].[schemas] AS [hs] WITH (NOLOCK)
  ON [hs].[schema_id] = [ht].[schema_id]
LEFT JOIN [sys].[periods] AS [p] WITH (NOLOCK)
  ON [p].[object_id] = [t].[object_id]
WHERE [t].[temporal_type] <> 0
  AND [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Datenbank und Objekt vor History-Größen-, Partition- und Indexanalyse festlegen. `dm_db_partition_stats` erst für die aufgelösten Current-/History-Objekt-IDs lesen.

### Zeit- und Scope-Modell

Aktueller Schemastand plus angesammelte Historydaten innerhalb fachlicher/technischer Retention.

### Bewertung und Gegenprobe

Current/History Table, Period Columns, Retention, Historygröße/Rows, Index-/Partitionierung und Cleanupstatus lesen. Schreibrate und typische Zeitprädikate bestimmen Design.

### Typische Fehlinterpretation

Große History ist nicht automatisch Problem; sie kann Complianceanforderung sein. Temporal ON beweist keine erfolgreiche Retentionbereinigung.

### Folgeanalyse

Object/Index/Partition/Capacity, konkrete Temporal Querypläne und Retentionpolicy.

## Primärquellen

- [Temporal Tables](https://learn.microsoft.com/en-us/sql/relational-databases/tables/temporal-tables?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#4-monitorusp_temporalanalysis)
