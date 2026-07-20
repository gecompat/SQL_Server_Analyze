# [monitor].[USP_Partitions]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt partitionsgenaue Größe, Grenzen, Ablage und Kompression.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie verteilen Partition Function und Scheme Daten über Partitionen und Storage, und sind Grenzen/Lebenszyklus plausibel?** Der dokumentierte Zweck ist: Zeigt partitionsgenaue Größe, Grenzen, Ablage und Kompression. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Katalog- und Rowcount-/Spacezustand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Partitions]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `partitions` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Partition eines Indexes oder Heaps. Ein Objekt mit mehreren Indizes besitzt entsprechend mehrere Zeilen je Partitionsnummer.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

RowCount und Größe je Partition, Grenzintervalle, Filegroup, Kompression und Indexausrichtung vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ungünstige Grenzen oder nicht ausgerichtete Indizes können Partition Elimination, Switching und Wartung verhindern. Extreme Schieflage kann Hotspots bilden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Leere Randpartitionen und ungleiche Größen sind bei Sliding-Window- oder Hot-/Cold-Design häufig beabsichtigt.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine leere zukünftige Monatspartition ist normal. Eine aktuelle Partition mit 95 % aller Zeilen und fehlender Elimination verlangt Plan-, Statistik- und Designprüfung.

**Ähnlich aussehender Gegenfall:** Leere Randpartitionen und ungleiche Größen sind bei Sliding-Window- oder Hot-/Cold-Design häufig beabsichtigt. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Partitions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Katalog- und Allocation-Unit-Aggregation; VOLL ist gruppengeschützt und begrenzt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt in `GEZIELT`; Partitions-, Allocation-Unit- und Data-Space-Kataloge werden aggregiert. |
| Teuerster Pfad | Cross-Database-`VOLL`, unbegrenzte Ausgabe und keine Objektfilter bei sehr vielen Partitionen/Allocation Units. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte sowie Partitionen, Allocation Units, Partition-Scheme-Ziele und Data Spaces. Objektfilter verkleinern die Katalogarbeit; das spätere TOP spart die vorgelagerte Aggregation nicht zuverlässig. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_Partitions ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | `GEZIELT` nutzt `OBJECT_ANALYSIS_CURRENT` ohne High-Impact-Pflicht. `VOLL` prüft zusätzlich `CATALOG_DEEP` und erfordert `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie verteilen Partition Function und Scheme Daten über Partitionen und Storage, und sind Grenzen/Lebenszyklus plausibel?

### Technischer Hintergrund

Partition Functions übersetzen Boundary Values in Partitionsnummern; RANGE LEFT/RIGHT bestimmt Grenzwertzuordnung. Schemes ordnen Partitionen Filegroups zu. Indizes müssen für Alignment dieselbe Partitionierungslogik passend verwenden.

### Datenkette

`sys.allocation_units`, `sys.data_spaces`, `sys.destination_data_spaces`, `sys.dm_db_partition_stats`, `sys.indexes`, `sys.objects`, `sys.partition_functions`, `sys.partition_range_values`, `sys.partition_schemes`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Katalog- und Rowcount-/Spacezustand.

### Bewertung und Gegenprobe

Boundary-Reihenfolge, leere Randpartitionen, Größenverteilung, Kompression, Filegroups, aligned/non-aligned Indizes und Sliding-Window-Prozess prüfen. Skew kann fachlich erwartbar sein.

### Typische Fehlinterpretation

Viele oder ungleiche Partitionen sind nicht automatisch schlecht. Partitionierung garantiert weder schnellere Queries noch Partition Elimination; Prädikat und Plan entscheiden.

### Folgeanalyse

Showplan Partition Elimination, Wartungs-/Switchprozess und Capacityanalyse.

## Primärquellen

- [sys.dm_db_partition_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-partition-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#7-monitorusp_partitions)
