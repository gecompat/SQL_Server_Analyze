# [monitor].[USP_ObjectInventory]

**Bereich:** Object und Index<br>
**Zweck:** Liefert Objekt- und Indexinventar mit Größe, Zeilen, Partitionierung, Kompression und Definition.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Objekte und physischen Zugriffsstrukturen existieren, wie groß sind sie und welche Eigenschaften besitzen sie?** Der dokumentierte Zweck ist: Liefert Objekt- und Indexinventar mit Größe, Zeilen, Partitionierung, Kompression und Definition. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Metadaten- und Größenstand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @SchemaNames = N'[ExampleSchema]',
      @ObjectNames = N'[ExampleTable]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `objects` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Inventarzeile beschreibt typischerweise eine Objekt-/Index-Kombination. Objektgesamtwerte können deshalb je Index wiederholt erscheinen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Objektgröße und Zeilen zuerst, dann Indexart, Schlüssel/Includes, Partitionierung, Kompression und Sonderzustände.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Große deaktivierte, hypothetische oder redundante Indizes können Speicher- und Wartungskosten erzeugen. Die Definition allein beweist aber keine Entbehrlichkeit.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Gemischte Kompression oder ähnliche Indizes können Teil einer Hot-/Cold-, Constraint- oder Coverage-Strategie sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zwei Indizes besitzen gleiche Schlüssel, aber einer sichert eine Unique Constraint. Er darf nicht wie ein normaler Duplikatindex behandelt werden. Usage, Operational Stats und Pläne prüfen.

**Ähnlich aussehender Gegenfall:** Gemischte Kompression oder ähnliche Indizes können Teil einer Hot-/Cold-, Constraint- oder Coverage-Strategie sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_ObjectInventory` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gezielte Einzel-Datenbank-Abfrage gering bis moderat; Cross-Database und Spaltenlisten begrenzt durch TOP.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt im Modus `GEZIELT`; Indizes und Spaltenlisten bleiben auf diesen Kandidatenscope begrenzt. |
| Teuerster Pfad | Cross-Database-`VOLL`, `@MaxZeilen = 0`, alle Objekttypen sowie Index-/Spaltenlisten bei sehr vielen Objekten und Indexspalten. |
| Haupttreiber | Zahl gewählter Datenbanken, Objekte, Indizes, Indexspalten, Partitionen und Allocation Units. Objektfilter reduzieren den dynamischen Katalogpfad früh; Definitionstexte und breite Cross-Database-Inventare erhöhen TempDB- und Transferbedarf. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_ObjectInventory ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | `OBJECT_ANALYSIS_CURRENT` schützt den gezielten Pfad ohne High-Impact-Pflicht. Nur `VOLL` prüft zusätzlich `CATALOG_DEEP` und benötigt `@HighImpactConfirmed = 1`; das Gate ersetzt keine Objekt-/Datenbankgrenze. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Objekte und physischen Zugriffsstrukturen existieren, wie groß sind sie und welche Eigenschaften besitzen sie?

### Technischer Hintergrund

Tabellen, Views, Indizes, Spalten, Partitionen, Kompression und Allocation Units bilden mehrere Katalogebenen. Rowcount und reservierte/benutzte Seiten kommen typischerweise aus Partition Stats; Definition und Schutzmerkmale aus Objekt-/Indexkatalogen. Ein Unique Constraint oder Primary Key ist fachlich/relational geschützt, auch wenn ein Index technisch ähnlich zu einem anderen wirkt.

### Datenkette

`master.sys.databases`, `sys.allocation_units`, `sys.columns`, `sys.data_spaces`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Metadaten- und Größenstand. Rowcounts aus DMVs sind für Diagnosezwecke geeignet, aber keine transaktional exakte `COUNT_BIG(*)`-Messung.

### Bewertung und Gegenprobe

Größe, Zeilen, Indexart, Schlüssel/Includes, Filter, Partitionierung, Kompression und Schutzmerkmale zusammen lesen. Ähnliche Schlüsselreihenfolgen können unterschiedliche Coverage, Sortierung oder Constraints bedienen.

### Typische Fehlinterpretation

Inventar zeigt Existenz, nicht Nutzen, Nutzung oder Redundanz. Eine kleine Tabelle mit vielen Indizes kann andere Trade-offs haben als eine große schreibintensive Tabelle.

### Folgeanalyse

`USP_IndexUsage`, `USP_IndexOperationalStats`, Query Store/Plan Cache und Abhängigkeitsprüfung.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#1-monitorusp_objectinventory)
