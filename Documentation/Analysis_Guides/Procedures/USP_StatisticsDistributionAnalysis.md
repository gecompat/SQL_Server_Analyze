# [monitor].[USP_StatisticsDistributionAnalysis]

**Bereich:** Object und Index<br>
**Zweck:** Analysiert ausgewählte Histogramme auf Skew, dominante Schritte, Tail und Partitionsabweichungen.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Datenverteilung bildet das Histogramm ab, und wo können Skew, dominante Werte oder grobe Rangeannahmen Schätzungen erschweren?** Der dokumentierte Zweck ist: Analysiert ausgewählte Histogramme auf Skew, dominante Schritte, Tail und Partitionsabweichungen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktuelles Histogramm der letzten Statistikaktualisierung; maximal 200 Steps und gegebenenfalls Sample statt Vollscan. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StatisticsDistributionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleObject]',
      @AnalyseModus = 'GEZIELT',
      @MaxVerteilungsStatistiken = 10,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Auch der gezielte Pfad ist als `CATALOG_DEEP` klassifiziert. Die Bestätigung ist deshalb technisch erforderlich; Objektfilter und Kandidatengrenze bleiben die eigentlichen Schutzgrenzen für die Quellarbeit.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Statistik, eine Verteilungszusammenfassung, eine Partitionsvariation oder ein normalisiertes Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Sample und Modification, danach Dominant Step, Skew, Tail und Partitionsspread. Findings erst mit der zugrunde liegenden Verteilung bewerten.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Starke Spitzen oder neue Tailwerte können dazu führen, dass ein Plan für häufige Parameter bei seltenen Parametern ungeeignet ist – oder umgekehrt.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Skew kann die reale Datenverteilung korrekt beschreiben und bei geeigneten Plänen völlig unkritisch sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein Wert umfasst 70 % der Zeilen. Problematisch wird das erst, wenn seltene und häufige Parameter denselben Plan verwenden und stark unterschiedliche Zeilenmengen erzeugen. Query Store und Showplan vergleichen.

**Ähnlich aussehender Gegenfall:** Skew kann die reale Datenverteilung korrekt beschreiben und bei geeigneten Plänen völlig unkritisch sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_StatisticsDistributionAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | HIGH_OPT_IN |
| Standardpfad | Eine Datenbank, ein Objekt und höchstens zehn ausgewählte Statistiken; pro Kandidat wird das vorhandene Histogramm numerisch zusammengefasst. |
| Teuerster Pfad | Viele ausgewählte Statistiken/Partitionen; pro Histogramm können bis zu 200 Steps gelesen, aggregiert und bewertet werden. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte, ausgewählter Statistiken und Partitionen. Für jede Kandidatenstatistik werden die vorhandenen Histogramm-Steps – höchstens 200 je Histogramm – gelesen und numerisch verdichtet. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_StatisticsDistributionAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Statistik-/Histogramm-Metadaten-I/O sowie Arbeitsspeicher für höchstens 200 Steps je ausgewähltem Histogramm; keine Segment-, Dictionary-, Benutzerdaten- oder XML-Ausgabe. |
| Begrenzungswirkung | Objekt-/Statistikfilter und `@MaxVerteilungsStatistiken` begrenzen Kandidaten vor dem Histogrammzugriff. `@MaxZeilen` wirkt erst auf fertige Findings und begrenzt nicht die Histogrammschritte. |
| Locking und Nebenwirkungen | Read-only mit Katalog-/Strukturzugriffen; parallele DDL-, Load- oder Wartungsaktivität kann kurz kollidieren und inkonsistente Momentbilder erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine ExampleDb, ein ExampleObject und wenige Statistiken; erst danach weitere Histogramme oder Partitionen aufnehmen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Datenverteilung bildet das Histogramm ab, und wo können Skew, dominante Werte oder grobe Rangeannahmen Schätzungen erschweren?

### Technischer Hintergrund

Histogrammsteps speichern `RANGE_HI_KEY`, `EQ_ROWS`, `RANGE_ROWS`, `DISTINCT_RANGE_ROWS` und `AVG_RANGE_ROWS`. Gleichheitsprädikate auf Stepgrenzen und Werte innerhalb einer Range werden unterschiedlich geschätzt. Skew- und Konzentrationskennzahlen des Frameworks sind abgeleitete Prüfwerte.

### Datenkette

`sys.columns`, `sys.databases`, `sys.dm_db_stats_histogram`, `sys.sp_executesql`, `sys.stats_columns`, `sys.types`.

### Zeit- und Scope-Modell

Aktuelles Histogramm der letzten Statistikaktualisierung; maximal 200 Steps und gegebenenfalls Sample statt Vollscan.

### Bewertung und Gegenprobe

Dominante EQ-Werte, große Ranges, geringe Distinctanzahl, Samplequote, Modification Counter und konkrete Parameterwerte verbinden. Verteilung ist besonders relevant bei Parameter Sensitivity und stark unterschiedlichen Selectivities.

### Typische Fehlinterpretation

Ein Skew-Score ist kein Produktfehler und kein universeller Threshold. Gute Pläne können trotz Skew entstehen; schlechte Schätzungen können ohne sichtbaren starken Skew vorkommen.

### Folgeanalyse

Showplan, Query Store PlanChanges/Regressions, gezieltes Statistikupdate nur nach Test.

## Primärquellen

- [sys.dm_db_stats_histogram](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-stats-histogram-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#6-monitorusp_statisticsdistributionanalysis)
