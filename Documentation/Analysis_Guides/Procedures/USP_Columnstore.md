# [monitor].[USP_Columnstore]

**Bereich:** Object und Index<br>
**Zweck:** Analysiert Columnstore-Rowgroups und optional Segmente sowie Dictionaries.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welchen Lebenszyklus und Qualitätszustand besitzen Columnstore-Rowgroups?** Der dokumentierte Zweck ist: Analysiert Columnstore-Rowgroups und optional Segmente sowie Dictionaries. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Rowgroupzustand; verändert sich durch Loads, Deletes, Tuple Mover und Wartung. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Columnstore]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPhysicalStats = 0,
      @MitSegmenten = 0,
      @MitDictionaries = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `rowgroups` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Im Basisresultset entspricht eine Zeile einer Rowgroup. Segment- und Dictionaryresultsets besitzen jeweils ihre eigene Spalten-/Dictionarygranularität.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Rowgroupzustand, Total/Deleted/Active Rows, Fullness, Trim Reason, Alter und Nutzungskontext vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele kleine komprimierte Rowgroups oder hohe Deleted-Rows-Anteile können Kompression, Segment Elimination und Scaneffizienz verschlechtern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Offene Delta Stores während Last und Deleted Rows in selten gelesenen Archivpartitionen können akzeptabel sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 40 % Deleted Rows in einer großen, häufig gescannten Rowgroup ist relevanter als 40 % in einer kleinen Archivpartition. Ladebatch, Tuple Mover, Partitionierung und Pläne prüfen.

**Ähnlich aussehender Gegenfall:** Offene Delta Stores während Last und Deleted Rows in selten gelesenen Archivpartitionen können akzeptabel sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Columnstore` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Basis moderat; Segmentanzahl entspricht Rowgroups × Spalten und ist daher nur opt-in, gruppengeschützt und TOP-begrenzt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine Datenbank und ein Columnstore-Objekt, nur Rowgroup-Katalogsicht; Physical Stats, Segmente und Dictionaries bleiben ausgeschaltet. |
| Teuerster Pfad | VOLL mit Physical Stats, Segmenten und Dictionaries; Segmentzeilen wachsen ungefähr mit Rowgroups × Spalten. |
| Haupttreiber | Zahl gewählter Columnstore-Indizes/Partitionen und Rowgroups; optionale Physical-Stats-, Segment- und Dictionaryzeilen vervielfachen die Detailmenge. Objektfilter wirken früh, während Limits typischerweise erst nach der Katalog-/DMV-Erhebung greifen. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_Columnstore ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Columnstore-Katalog-/DMV-I/O; optionale Physical-Stats-, Segment- und Dictionarypfade können große interne Metadatenmengen materialisieren. Kein Histogramm- oder XML-Pfad. |
| Begrenzungswirkung | Datenbank-/Objektfilter sind echte Schutzgrenzen. `@MaxZeilen`/TOP begrenzen die Ausgabe, nicht zuverlässig die vorgelagerte Rowgroup-, Segment- oder Dictionaryermittlung; Segmentzahl wächst ungefähr mit Rowgroups × Spalten. |
| Locking und Nebenwirkungen | Read-only mit Katalog-/Strukturzugriffen; parallele DDL-, Load- oder Wartungsaktivität kann kurz kollidieren und inkonsistente Momentbilder erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`, `COLUMNSTORE_CURRENT`, `COLUMNSTORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Nur einen synthetisch identifizierten Kandidaten vertiefen; breite VOLL-/Deep-Pfade mit High-Impact-Freigabe und außerhalb der Lastspitze. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime- und Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welchen Lebenszyklus und Qualitätszustand besitzen Columnstore-Rowgroups?

### Technischer Hintergrund

Rows gelangen zunächst in Delta Stores oder direkt in komprimierte Rowgroups. Tuple Mover komprimiert geschlossene Delta Stores. Deletes markieren Rows logisch; Reorganization/Rebuild kann bereinigen. Trim Reasons und State erklären, warum Rowgroups kleiner als das Ziel sein können.

### Datenkette

`sys.column_store_dictionaries`, `sys.column_store_row_groups`, `sys.column_store_segments`, `sys.columns`, `sys.dm_db_column_store_row_group_physical_stats`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Das Basismodell verbindet Rowgroups mit Objekt-, Schema- und Indexkatalog:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [o].[name] AS [ObjectName]
    , [i].[name] AS [IndexName]
    , [rg].[partition_number]
    , [rg].[state_desc]
    , [rg].[total_rows]
    , [rg].[deleted_rows]
FROM [sys].[column_store_row_groups] AS [rg] WITH (NOLOCK)
JOIN [sys].[objects] AS [o] WITH (NOLOCK)
  ON [o].[object_id] = [rg].[object_id]
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [o].[schema_id]
JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [rg].[object_id]
 AND [i].[index_id] = [rg].[index_id]
WHERE [s].[name] = N'ExampleSchema'
  AND [o].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Objektfilter vor Physical-Stats-, Segment- und Dictionary-Pfaden setzen. Diese optionalen Vertiefungen lesen deutlich mehr Metadaten als der Rowgroup-Katalog.

### Zeit- und Scope-Modell

Aktueller Rowgroupzustand; verändert sich durch Loads, Deletes, Tuple Mover und Wartung.

### Bewertung und Gegenprobe

Total/Deleted Rows, Deleted-Prozent, State, Alter, Größe, Trim Reason, offene/geschlossene Delta Stores und Workloadmuster kombinieren. Viele kleine Rowgroups verschlechtern Segmentelimination/Kompression eher als ein isolierter Prozentwert.

### Typische Fehlinterpretation

20 Prozent Deleted Rows in einer kleinen kalten Rowgroup ist nicht automatisch relevant. Direkte DML- und Bulkloadmuster sowie Partitionstrategie entscheiden.

### Folgeanalyse

Querypläne/Segmentelimination, Ladebatchgröße, Tuple-Mover-/Wartungskontext.

## Primärquellen

- [sys.dm_db_column_store_row_group_physical_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-column-store-row-group-physical-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#8-monitorusp_columnstore)
