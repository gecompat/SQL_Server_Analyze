# [monitor].[USP_InMemoryOltpAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert XTP-Tabellen, Hashindizes, Checkpoints, Transaktionen und Resource Pools.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie sind Memory-Optimized-Objekte, Indizes, Memoryverbrauch und Persistenz-/Checkpointpfade konfiguriert und belastet?** Der dokumentierte Zweck ist: Analysiert XTP-Tabellen, Hashindizes, Checkpoints, Transaktionen und Resource Pools. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Katalog-/Runtimezustand; Memory-/Transaction-/Checkpointwerte teils seit Start, Objektbestand aktuell. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitHashIndexStats = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer XTP-Tabelle, einem Index, Hashstatistik, Checkpointzustand, Transaktionssignal, Pool oder Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Tabellenmemory, Bucket Count, Chainlängen, leere Buckets, Checkpointfiles, aktive Transaktionen und Poolauslastung gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Lange Hashketten verursachen mehr Vergleiche; wartende Checkpointdaten oder hohe Poolauslastung können Persistenz-/Memorydruck anzeigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Große Memorynutzung ist bei bewusst großen XTP-Tabellen normal. Absolute Größe allein genügt nicht.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Average Chain 20, Max 500, kaum leere Buckets und viele Equality Lookups: Bucketzahl wahrscheinlich zu klein. Workload, Indexart, Pool und Checkpoints prüfen.

**Ähnlich aussehender Gegenfall:** Große Memorynutzung ist bei bewusst großen XTP-Tabellen normal. Absolute Größe allein genügt nicht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_InMemoryOltpAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope, Objektfilter und `@MitHashIndexStats = 0`; gelesen werden Kataloge und die übrigen XTP-Snapshot-DMVs. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter, unbegrenzte Ausgabe und `@MitHashIndexStats = 1`. Die Hashindex-DMV kann nach Produktdokumentation vollständige In-Memory-Tabellen scannen. |
| Haupttreiber | Zahl gewählter Datenbanken, speicheroptimierter Tabellen/Indizes, XTP-Memory-Consumer, Checkpointdateien und aktueller XTP-Transaktionszeilen. Nutzdatenzeilen werden nicht gelesen, doch große Checkpoint-/Consumerinventare verbreitern den Runtimepfad. |
| Skalierung | Basispfad wächst mit In-Memory-Tabellen, Speicherconsumern, Checkpointdateien und aktiven XTP-Transaktionen. Der opt-in Hashpfad wächst zusätzlich mit den zu scannenden Tabellen-/Indexstrukturen und kann dominant werden. |
| Ressourcen | CPU und Speicher für XTP-DMVs, Katalog-/Checkpointmetadaten, dynamisches SQL und temporäre Resultate; der Hashpfad kann erhebliche CPU-/Speicherzugriffe in In-Memory-Tabellen verursachen. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen viele Katalog- und Basispfade. `@MaxZeilen` wird erst je fertigem Resultset angewandt. Insbesondere begrenzt es den Tabellenvollscan von `sys.dm_db_xtp_hash_index_stats` nicht. |
| Locking und Nebenwirkungen | Rein lesend; keine XTP-DDL oder Datenänderung. Runtime-DMVs sind flüchtig und nicht atomar. Der Hashindexscan kann trotz fehlender Benutzerlocks spürbare Konkurrenz um CPU/Speicher erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`, `OBJECT_ANALYSIS_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, enger Objektfilter und Hashstatistik aus. Den Hashpfad erst nach Baseline, außerhalb der Lastspitze und mit `@HighImpactConfirmed = 1` aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime- und Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Memory-Optimized-Objekte, Indizes, Memoryverbrauch und Persistenz-/Checkpointpfade konfiguriert und belastet?

### Technischer Hintergrund

In-Memory OLTP speichert Rows in Memory und nutzt MVCC statt klassischer Page Locks/Latches. Hashindizes verteilen Schlüssel auf Buckets; Rangeindizes verwenden Bw-Trees. Durable Tabellen schreiben Log und Checkpoint File Pairs; SCHEMA_ONLY nicht. Garbage Collection entfernt nicht mehr sichtbare Versionen.

### Datenkette

`sys.databases`, `sys.dm_db_xtp_checkpoint_files`, `sys.dm_db_xtp_hash_index_stats`, `sys.dm_db_xtp_memory_consumers`, `sys.dm_db_xtp_table_memory_stats`, `sys.dm_db_xtp_transactions`, `sys.dm_resource_governor_resource_pools`, `sys.filegroups`, `sys.hash_indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.table_types`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Katalog-/Runtimezustand; Memory-/Transaction-/Checkpointwerte teils seit Start, Objektbestand aktuell.

### Bewertung und Gegenprobe

Table Durability, Rows/Memory, Hash Bucket Count, Empty/Chainverteilung, Indexart, GC/Transactionalter, Checkpointstorage und Database Memoryquota zusammen lesen. Hashketten benötigen Datenverteilungs-/Lookupkontext.

### Typische Fehlinterpretation

Viele Empty Buckets allein sind nicht automatisch schlecht; lange Chains sind besonders bei häufigen Equality Lookups relevant. Memory-Optimized heißt nicht logfrei oder ohne Capacitygrenze.

### Folgeanalyse

Current Transactions/Memory, Querypläne, XTP DMVs und Checkpoint-/Logstorage.

## Primärquellen

- [In-Memory OLTP](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/overview-and-usage-scenarios?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#3-monitorusp_inmemoryoltpanalysis)
