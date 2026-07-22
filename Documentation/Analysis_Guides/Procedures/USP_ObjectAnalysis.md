# [monitor].[USP_ObjectAnalysis]

**Bereich:** Object und Index, Orchestrator<br>
**Zweck:** Orchestriert Inventar, Usage, Missing Indexes und optionale Tiefenmodule mit gemeinsamem Filtervertrag.<br>
**Beobachtungsart:** nicht atomarer Mix aus Katalog, kumulativen Zählern und optionalem physischem Scan<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche objektbezogenen Evidenzpfade sollen für einen Scope gemeinsam ausgeführt werden?** Der dokumentierte Zweck ist: Orchestriert Inventar, Usage, Missing Indexes und optionale Tiefenmodule mit gemeinsamem Filtervertrag. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Nicht atomarer Mix aus Metadaten, kumulativen Zählern und aufrufbezogenen physischen Scans. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @MitObjectInventory = 1,
      @MitIndexUsage = 0,
      @MitMissingIndexes = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Zuerst wird nur das Objektinventar erhoben. Usage, Missing Indexes und die
physischen Tiefenmodule anschließend einzeln aktivieren, weil sie dieselben
Filter mit jeweils anderer Quellen- und Zeitsemantik verwenden.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Objekt/Index, Indexpartition, Statistik, Rowgroup, Partition oder Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Childstatus zuerst, dann Inventar → Nutzung → konkrete Tiefenanalyse. Befunde verschiedener Children gemeinsam, aber nicht als identische Zeilen interpretieren.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Missing-Index-Vorschlag ohne Inventar kann Redundanz erzeugen; Fragmentierung ohne Page Count kann unnötige Wartung auslösen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht aktivierte Deep-Module fehlen absichtlich. Sie bedeuten keine partielle Ausführung.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Inventar zeigt ähnlichen Index, Missing Index schlägt einen neuen vor, Usage zeigt geringe Nutzung: eher Konsolidierung prüfen als blind erstellen. Relevantes Child mit engem Scope wiederholen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Deep-Module fehlen absichtlich. Sie bedeuten keine partielle Ausführung. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_ObjectAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `GEZIELT` mit Objektinventar, Index Usage und Missing Indexes. Ohne Objektfilter kann auch dieser Default viele Datenbanken/Katalogobjekte berühren; „gezielt“ bezeichnet den Childmodus, nicht automatisch einen engen Eingabescope. |
| Teuerster Pfad | `@Vollanalyse = 1`, alle zehn Children und unbegrenzte Zeilen: Kataloge und Index-DMVs werden wiederholt gelesen, Histogramme zerlegt und `sys.dm_db_index_physical_stats` über den freigegebenen Scope ausgeführt. |
| Haupttreiber | Zahl der ausgewählten Datenbanken, Objekte, Indizes, Statistiken und Partitionen; bei Physical Stats zusätzlich Seitenzahl/Scanmodus, bei Statistikverteilung Kandidatenzahl und bis zu 200 Histogrammschritte je Statistik. |
| Skalierung | Children laufen sequenziell und teilen keinen Katalogsnapshot. Dieselben Objekte werden für Inventar, Usage, Operational Stats, Statistics, Partitionen, Columnstore und Design jeweils neu aufgelöst; VOLL vergrößert Scope und Detailarbeit. |
| Ressourcen | Datenbankkatalog- und DMV-CPU, Metadaten-I/O, Arbeitsspeicher/TempDB für Gruppierung sowie optional physischer Indexscan und Histogrammabruf. Kein `msdb`, XEL- oder Samplingpfad. |
| Begrenzungswirkung | `@MaxZeilen` wird an jedes Child übergeben, ist aber kein Gesamtlimit. Je Child kann es früh Kandidaten, erst eine sortierte Ausgabe oder nur den Transfer begrenzen; besonders SchemaDesign scannt den Katalog vor dem Limit. `@LockTimeoutMs` begrenzt Wartezeit, nicht CPU, I/O oder Gesamtdauer. |
| Locking und Nebenwirkungen | Read-only, aber Katalog- und Physical-Stats-Zugriffe können mit DDL konkurrieren. Die Children laufen nicht atomar; Objekt- oder Indexdefinitionen können sich zwischen Resultsets ändern. |
| Schutzmechanismus | VOLL und ressourcenintensive Children besitzen getrennte Modulschalter und Analyseklassen; `@HighImpactConfirmed` wird an alle weitergereicht. Freigabe erlaubt den Pfad, begrenzt ihn aber nicht. Ein enger `@DatabaseNames`-/`@FullObjectNames`-Scope bleibt erforderlich. |
| Sicherer Einsatz | Eine Datenbank, ein vollständiger Objektname, nur ein Child und `@MaxZeilen = 100`. Erst nach dessen Status gezielt Operational Stats, Histogramm oder Physical Stats mit eigenem Kostenvertrag aktivieren. |
| Aussagegrenze | Die Resultsets kombinieren aktuelle Katalogstruktur, seit Restart kumulative DMVs und optionale physische Momentaufnahmen. Gemeinsame Namen bedeuten nicht gemeinsamen Messzeitpunkt; Limits können pro Child andere Objekte sichtbar machen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche objektbezogenen Evidenzpfade sollen für einen Scope gemeinsam ausgeführt werden?

### Technischer Hintergrund

Der Orchestrator kombiniert Definition, Usage, Operations, Missing Indexes, Statistics, Partitions, Columnstore und optional Physical Stats. Jedes Child behält eigene Quelle, Kosten und Resetsemantik.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in den aufgerufenen Childmodulen.

### Source Select

Kein einzelnes Grundselect: Die Procedure orchestriert je nach Schalter `USP_ObjectInventory`, `USP_IndexUsage`, `USP_MissingIndexes`, `USP_IndexOperationalStats`, `USP_Statistics`, `USP_StatisticsDistributionAnalysis`, `USP_Partitions`, `USP_Columnstore`, `USP_IndexPhysicalStats` und `USP_SchemaDesignAnalysis`.

**Wichtig für die Eigenlast:** Datenbank und vollständigen Objektnamen an alle Childmodule weiterreichen und nur benötigte Tiefenpfade aktivieren. Das abschließende Zeilenlimit ersetzt weder den DMF-Objektparameter noch den frühen Katalogscope.

### Zeit- und Scope-Modell

Nicht atomarer Mix aus Metadaten, kumulativen Zählern und aufrufbezogenen physischen Scans.

### Bewertung und Gegenprobe

Zuerst Childstatus und Kostenoptionen, danach Befunde nach Objekt/Index korrelieren. Widersprüche sind möglich, etwa Missing-Index-Evidenz neben einem ähnlichen ungenutzten Index.

### Typische Fehlinterpretation

Die Zusammenfassung ist keine DDL-Liste. Ein Childfehler darf nicht als unauffälliges Objekt gelten.

### Folgeanalyse

Je Befund das spezialisierte Child mit engem Scope erneut ausführen.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../03_Object_Index.md#11-monitorusp_objectanalysis)
