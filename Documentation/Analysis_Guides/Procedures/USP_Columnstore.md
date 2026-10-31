# [monitor].[USP_Columnstore]

**Bereich:** Object und Index<br>
**Zweck:** Analysiert Columnstore-Rowgroups, geordnete Indexmetadaten und optional Segmente sowie Dictionaries.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welchen Lebenszyklus und Qualitätszustand besitzen Columnstore-Rowgroups?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Columnstore]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPhysicalStats = 0,
      @MitSegmenten = 0,
      @MitDictionaries = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste solcher Namen. &#124; trennt außerhalb von [...]; ]] maskiert ]. Elemente werden außen getrimmt; case-sensitive Duplikate und ungültige/leere Elemente sind INVALID_PARAMETER. NULL, N'' und nur Leerzeichen bedeuten keine exakte Einschränkung und wählen alle zulässigen sichtbaren ONLINE-Datenbanken. Nichtleere Liste und nicht-NULL @DatabaseNamePattern sind gegenseitig exklusiv. PARSENAME-Prüfung: Teil 1 vorhanden, Teil 2 NULL, LEN höchstens 128; keine vollständige SQL-Namensgrammatik. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in der Auswahl zu. NULL wird vom Datenbankhelfer als INVALID_PARAMETER abgewiesen. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 zu 1. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern; NULL kein Filter, leer/Whitespace oder leeres Präfix-Ergebnis ungültig. Außen trimmen; Präfixe like:, regex:, regexi: werden ohne Beachtung der Großschreibung erkannt; Rest nicht nochmals trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] sind case-sensitiv. regex: übergibt c, regexi: i; Syntax wird nicht vorgeprüft. Der Datenbankpattern-Helfer prüft Regexverfügbarkeit im Installationsdatenbankkontext (SQL Server 2025 und Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Feldregex für Schema/Objekt hat diese Vorprüfung nicht. Mit wirksamer Datenbankliste exklusiv. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 (Default) bestätigt kein Gate; 1 bestätigt nur die Anforderung eines tatsächlich aktivierten Analysepfads. NULL ungültig. Datenbankauswahl prüft COLUMNSTORE_CURRENT; Physical-/Segment-/Dictionaryoptionen sowie Segmentüberlappung zusätzlich COLUMNSTORE_DEEP; VOLL prüft CATALOG_DEEP. Ob ein aktivierter Pfad eine Gruppengate-Bestätigung verlangt, bestimmt dessen Policy. Bestätigung ersetzt weder Freigabe noch Scopegrenzen. Bit-Bindung mappt konvertierbare numerische Nichtnullwerte auf 1. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitiv verglichen. NULL bedeutet kein Filter; nicht-NULL leere/Whitespace-Liste, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind ungültig. LEN höchstens 128. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern; NULL kein Filter, Leerwert/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Restinhalt nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: Flag c, regexi: Flag i. Regex wird in der jeweiligen Zieldatenbank ausgeführt, ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; &#124; trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitiv. NULL bedeutet kein Filter; nicht-NULL leer/Whitespace, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. LEN höchstens 128. Mit nicht-NULL @ObjectNamePattern oder @FullObjectNames exklusiv. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektpattern; NULL deaktiviert, leeres/Whitespace-Muster oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann je Datenbank als ERROR_HANDLED erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Optionale bracket-aware Pipe-Liste ein-, zwei- oder dreiteiliger Bezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. &#124; trennt außerhalb von [...], ]] maskiert ]; PARSENAME/sysname-Grenzen, Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Datenbankteil verlangt Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Vergleiche case-sensitive; nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | GEZIELT oder VOLL; bei deaktivierter Segmentüberlappung wird NULL zu GEZIELT normalisiert, Außenleerzeichen werden entfernt und die Großschreibung vereinheitlicht. Andere Werte einschließlich leerer Eingabe führen zu INVALID_PARAMETER. Bei @MitSegmentUeberlappung=1 prüft die normale Vorbedingung vor dieser Normalisierung auf ausdrücklich übergebenes GEZIELT; NULL wird in diesem Pfad als INVALID_PARAMETER abgewiesen. VOLL prüft CATALOG_DEEP samt aktueller Aktivierung/Freigabe und ggf. High-Impact-Gate. |
| `@MitPhysicalStats` | `bit` | `0` | Opt-in: 0 lässt zusätzliche Physical-Rowgroup-Stats aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht ausdrücklich abgewiesen und aktiviert den =1-Zweig nicht. Detailwerte und Berechtigungen hängen von Quelle und Version ab. |
| `@MitSegmenten` | `bit` | `0` | Opt-in: 0 lässt Segmentmetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens validiert und aktiviert den =1-Zweig nicht. Die Segmentzahl wächst ungefähr mit Rowgroups × Spalten; TOP begrenzt die je Datenbank materialisierten Zeilen, nicht zuverlässig die vorgelagerte Rowgroupermittlung. |
| `@MitDictionaries` | `bit` | `0` | Opt-in: 0 lässt Dictionarymetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens abgewiesen und aktiviert den =1-Zweig nicht. Ergebnisverfügbarkeit und erforderliche Rechte hängen vom Quellpfad ab. |
| `@MinDeletedPercent` | `decimal(9,2)` | `0` | Rowgroup-Schwelle in Prozentpunkten, einschließlich 0 bis 100; außerhalb INVALID_PARAMETER. NULL passiert den &lt;0/&gt;100-Test aufgrund SQL-Dreiwertlogik, macht aber den nachfolgenden &gt;=-Vergleich UNKNOWN, sodass keine Zeile den Vergleich erfüllt. Kein Rebuildurteil. |
| `@NurProblematisch` | `bit` | `0` | 0 lässt die Rowgroup-Auswahl ungefiltert; 1 filtert auf Zustand ungleich COMPRESSED oder vorhandene gelöschte Zeilen. NULL wird nicht separat validiert, sondern an SQL-Prädikate weitergereicht; deren Dreiwertlogik gilt. |
| `@MaxZeilen` | `int` | `10000` | Positive int begrenzt TOP je relevanter Ergebnismenge und Ziel-Datenbank; 0 oder NULL bedeutet unbegrenzt; negative Werte INVALID_PARAMETER. Die Grenze begrenzt nicht zuverlässig vorgelagerte Katalog-/DMV-Arbeit. Segmentüberlappung hat die separate Grenze @MaxSegmenteAnalyse. |
| `@LockTimeoutMs` | `int` | `0` | Lockwartezeit in Millisekunden von 0 bis 60000; außerhalb INVALID_PARAMETER. 0 bedeutet NOWAIT. Der Parameter wird in dynamischen Datenbankzugriffs-Batches als SET LOCK_TIMEOUT gesetzt; der Modulablauf setzt außerhalb dieser Batches außerdem stellenweise LOCK_TIMEOUT 0. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach TRIM/UPPER einer der endlichen Werte CONSOLE, RAW, TABLE, NONE; NULL/leer wird ungültig. CONSOLE zeigt Statuskontext und menschenlesbare Fachansicht; RAW gibt getrennte Status- und Fachmengen; TABLE schreibt nur gemappte Mengen; NONE unterdrückt reguläre Resultsets. JSON ist unabhängig über @JsonErzeugen steuerbar. TABLE-Mapping wird vor dem Hilfezweig vorgeprüft. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur mit TABLE: JSON-Objekt Resultsetname zu lokaler #Temp-Zieltabelle. Für TABLE ist NULL/leeres oder ungültiges Objekt ungültig; außerhalb TABLE führt nichtleerer Inhalt zu THROW 51011. Erlaubte exakte Namen: rowgroups, ordering; segmentOverlap zusätzlich nur bei aktivierter Segmentüberlappung. Ziele müssen eindeutig, lokal, leer und mit genau einer Seed-Spalte angelegt sein; der Helper prüft und wirft bei Fehler. |
| `@JsonErzeugen` | `bit` | `0` | 0 unterdrückt JSON; 1 erzeugt es in @Json. NULL wird nicht eigens als ungültig geprüft und führt nicht in den IF-Zweig. JSON-Schema 1 ohne Segmentüberlappung, Schema 2 mit ihr; Schlüssel meta, rowgroups, ordering, physicalStats, segments, dictionaries, databaseStatus und beim Opt-in segmentOverlap. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Optionaler nvarchar(max)-OUTPUT-Empfänger; zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 enthält er das erzeugte JSON, sonst NULL. Zum Empfangen Variable passenden Typs mit OUTPUT binden; ohne OUTPUT wird die Zuweisung nicht zurückgegeben. Im Hilfezweig ist die Variable NULL. |
| `@PrintMeldungen` | `bit` | `1` | 0 unterdrückt die ergänzende Severity-10-Warnmeldung; 1 (Default) gibt sie bei Status ungleich AVAILABLE aus. NULL wird nicht separat validiert und die Meldungsbedingung greift nicht. Keine zusätzliche Fachmenge. |
| `@Hilfe` | `bit` | `0` | 0 normaler Ablauf; 1 druckt Hilfe und beendet vor der Analyse. Der Return liegt nach Filter-, TABLE-Mapping-, Kandidaten- und Gateprüfungen, diese können also vorher stattfinden. NULL wird nicht als 1 behandelt. |
| `@MitSegmentUeberlappung` | `bit` | `0` | 0 (auch NULL, durch COALESCE zu 0 normalisiert) lässt segmentOverlap aus; 1 fordert die Diagnose und COLUMNSTORE_DEEP-Prüfung. Normaler Aufruf verlangt außerdem GEZIELT, genau eine explizite Datenbank, genau ein zweigliedriges FullObjectNames-Objekt, keine konkurrierenden Schema-/Objektfilter und @MaxSegmenteAnalyse 1..10000; sonst INVALID_PARAMETER. Opt-in ergänzt RAW/TABLE/JSON/CONSOLE; JSON wechselt zu Schema 2. |
| `@MaxSegmenteAnalyse` | `int` | `2000` | Nur im aktivierten Segmentüberlappungspfad gültige Grenze 1..10000 einschließlich; NULL/außerhalb ungültig. Höchstens N+1 Segmentzeilen als Sentinel werden materialisiert; bei Überschreitung entfällt die gesamte Paarberechnung. Kein globales TOP-/Zeitlimit; bei ausgeschaltetem Pfad ungeprüft. |

~~~sql
EXEC [monitor].[USP_Columnstore]
      @DatabaseNames=N'[ExampleDatabase]'
    , @FullObjectNames=N'[ExampleSchema].[ExampleTable]'
    , @ResultSetArt='RAW';
~~~

~~~sql
DECLARE @Columnstore_JsonExample nvarchar(max);
EXEC [monitor].[USP_Columnstore]
      @DatabaseNames=N'[ExampleDatabase]'
    , @FullObjectNames=N'[ExampleSchema].[ExampleTable]'
    , @JsonErzeugen=1
    , @Json=@Columnstore_JsonExample OUTPUT;
SELECT @Columnstore_JsonExample AS [JsonDocument];
~~~

~~~sql
CREATE TABLE #Columnstore_RowgroupsExample ([Seed] bit NULL);
BEGIN TRY
    EXEC [monitor].[USP_Columnstore]
          @DatabaseNames=N'[ExampleDatabase]'
        , @FullObjectNames=N'[ExampleSchema].[ExampleTable]'
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=N'{"rowgroups":"#Columnstore_RowgroupsExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #Columnstore_RowgroupsExample;
    THROW;
END CATCH;
DROP TABLE #Columnstore_RowgroupsExample;
~~~

~~~sql
EXEC [monitor].[USP_Columnstore] @Hilfe=1;
~~~

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `rowgroups` und `ordering`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Im Basisresultset entspricht eine Zeile einer Rowgroup. Eine `ordering`-Zeile beschreibt eine deklarierte Order-Spalte eines Columnstore-Index; sie ist keine Messung von Sortierqualität oder Abfragewirkung. Segment- und Dictionaryresultsets besitzen jeweils ihre eigene Spalten-/Dictionarygranularität.

## So lesen

Vergleichen Sie Rowgroupzustand, Total/Deleted/Active Rows, Fullness, Trim Reason, Alter und Nutzungskontext.

## Warum kann das problematisch sein?

Viele kleine komprimierte Rowgroups oder hohe Deleted-Rows-Anteile können Kompression, Segment Elimination und Scaneffizienz verschlechtern.

## Wann ist es kein Problem?

Offene Delta Stores während Last und Deleted Rows in selten gelesenen Archivpartitionen können akzeptabel sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 40 % Deleted Rows in einer großen, häufig gescannten Rowgroup ist relevanter als 40 % in einer kleinen Archivpartition. Prüfen Sie Ladebatch, Tuple Mover, Partitionierung und Pläne.

**Ähnlich aussehender Gegenfall:** Offene Delta Stores während Last und Deleted Rows in selten gelesenen Archivpartitionen können akzeptabel sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Columnstore` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Der Basispfad besitzt eine moderate Eigenlast. Die Segmentanzahl entspricht Rowgroups × Spalten; der Segmentpfad ist daher ein gruppengeschütztes und TOP-begrenztes Opt-in.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine Datenbank und ein Columnstore-Objekt, nur Rowgroup-Katalogsicht; Physical Stats, Segmente und Dictionaries bleiben ausgeschaltet. |
| Teuerster Pfad | VOLL mit Physical Stats, Segmenten und Dictionaries; Segmentzeilen wachsen ungefähr mit Rowgroups × Spalten. |
| Haupttreiber | Zahl gewählter Columnstore-Indizes/Partitionen und Rowgroups; optionale Physical-Stats-, Segment- und Dictionaryzeilen vervielfachen die Detailmenge. Objektfilter wirken früh, während Limits typischerweise erst nach der Katalog-/DMV-Erhebung greifen. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_Columnstore ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Columnstore-Katalog-/DMV-I/O; optionale Physical-Stats-, Segment- und Dictionarypfade können große interne Metadatenmengen materialisieren. Kein Histogramm- oder XML-Pfad. |
| Begrenzungswirkung | Datenbank-/Objektfilter sind echte Schutzgrenzen. `@MaxZeilen` begrenzt die je Datenbank materialisierten Zeilen der jeweiligen Ergebnismenge, nicht zuverlässig die vorgelagerte Ermittlung. Segmentzeilen wachsen ungefähr mit Rowgroups × Spalten. Der separate Segmentüberlappungspfad materialisiert höchstens `@MaxSegmenteAnalyse + 1` Segmentzeilen; bei Erreichen des Sentinels entfällt die gesamte Paarberechnung. |
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

`sys.column_store_dictionaries`, `sys.column_store_row_groups`, `sys.column_store_segments`, `sys.columns`, `sys.dm_db_column_store_row_group_physical_stats`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`.

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

**Wichtig für die Eigenlast:** Setzen Sie Objektfilter vor Physical-Stats-, Segment- und Dictionary-Pfaden. Diese optionalen Vertiefungen lesen deutlich mehr Metadaten als der Rowgroup-Katalog.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Rowgroupzustand. Dieser Zustand verändert sich durch Loads, Deletes, Tuple Mover und Wartung.

### Bewertung und Gegenprobe

Berücksichtigen Sie Total und Deleted Rows, den Deleted-Prozentwert, State, Alter, Größe, Trim Reason, offene und geschlossene Delta Stores sowie das Workloadmuster gemeinsam. Viele kleine Rowgroups beeinträchtigen Segmentelimination und Kompression eher als ein isolierter Prozentwert.

### Typische Fehlinterpretation

20 Prozent Deleted Rows in einer kleinen kalten Rowgroup ist nicht automatisch relevant. Direkte DML- und Bulkloadmuster sowie Partitionstrategie entscheiden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Querypläne/Segmentelimination, Ladebatchgröße, Tuple-Mover-/Wartungskontext.

## Primärquellen

- [sys.dm_db_column_store_row_group_physical_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-column-store-row-group-physical-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#8-monitorusp_columnstore)

## Begrenzte Segmentüberlappung

Der vom Benutzer freigegebene
[Segmentvertrag](../../Architecture/WI0004_Segment_Overlap_Public_Specification.md)
ergänzt `@MitSegmentUeberlappung=0` und `@MaxSegmenteAnalyse=2000`. Der neue
Pfad bleibt standardmäßig ausgeschaltet. Aktiviert verlangt er GEZIELT,
genau eine exakte Datenbank und ein zweigliedriges FullObjectNames-Objekt
sowie die bestehenden COLUMNSTORE_DEEP-/High-Impact-Gates. SQL Server 2019
meldet für diese Quelle UNAVAILABLE_VERSION; die Unterstützung beginnt mit
SQL Server 2022.

Die neue Menge segmentOverlap beschreibt je Index, Partition und Spalte
beobachtete, vergleichbare und nicht vergleichbare Segmentcounts. Nur
vollständig vergleichbare Gruppen erhalten strikte Überlappungs- und
Grenzberührungspaarzahlen. Interne numerische beziehungsweise binäre Grenzen
werden nicht ausgegeben. Nicht unterstützte Typen, NULL-Grenzen oder
inkompatible String-Collationwerte ergeben NULL-Metriken mit
AVAILABLE_LIMITED. Daraus wird kein Rechtefehler, Qualitätsurteil oder
Rebuildbedarf abgeleitet.

Es werden höchstens N+1 Segmentzeilen materialisiert. Die zusätzliche Zeile
weist eine Überschreitung nach; dann entfällt die gesamte Paarberechnung
und die neue Menge bleibt leer. Doppelte oder unvollständige Identitäten
verwerfen ebenfalls die gesamte neue Aufnahme. Die Grenze schützt die
Materialisierung, garantiert aber weder begrenzte Katalogseiten noch eine
Echtzeitdeadline. Andere Teilquellen bleiben erhalten.

Im aktivierten Pfad ergänzt RAW eine Menge, TABLE erlaubt segmentOverlap,
JSON verwendet Schema 2 und CONSOLE zeigt diese Menge in genau einem
Resultset. Ohne Opt-in bleiben die bisherigen Ausgaben und JSON-Schema 1
erhalten. Die gezielten nativen Export-, Bereichs-, Fallback- und
Callerproben sind auf SQL Server 2025 und 2022 sowie für den
SQL-2019-Fallback abgeschlossen. Die positiven Metadatenfälle belegen
beobachtete Encodings 2 und 3; synthetische Grenzfälle sind davon getrennt.
Daraus folgt keine allgemeine Berechtigungs- oder Performancegarantie.
