# [monitor].[USP_Statistics]

**Bereich:** Object und Index<br>
**Zweck:** Inventarisiert Statistikdefinition, Materialisierung, Sample, Änderungen und inkrementelle Details.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie aktuell und repräsentativ sind die Statistiken, die der Cardinality Estimator für Schätzungen verwendet?** Der dokumentierte Zweck ist: Inventarisiert Statistikdefinition, Materialisierung, Sample, Änderungen und inkrementelle Details. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Aktueller gespeicherter Statistikstand seit letztem Update. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Statistics]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @MitIncrementellenDetails = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

`GEZIELT` verlangt einen Schema-/Objektfilter; nur eine Datenbank anzugeben ist
kein gültiger gezielter Lauf. Inkrementelle Partitionsdetails werden erst nach
der Hauptsicht und mit zusätzlichem Deep-Gate aktiviert.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `statistics` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Im Hauptresultset beschreibt eine Zeile eine Statistik. Inkrementelle Details besitzen eine zusätzliche Partitionsgranularität.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Rows, Rows Sampled, Modification Counter, führende Spalte, Filter und letzten Updatezeitpunkt gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Unpassendes Sample oder relevante Datenänderungen können Kardinalitätsschätzungen und dadurch Joinart, Grant und Zugriffspfad verschlechtern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine alte Statistik kann korrekt bleiben, wenn sich relevante Daten kaum ändern. Niedriger Sample-Prozentsatz kann bei sehr großen Tabellen ausreichend sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zehn Jahre alt plus Modification Counter 0 ist nicht automatisch schlecht. Eine gestern aktualisierte Statistik kann einen neu entstandenen Tail dennoch schlecht abbilden. Histogramm und betroffene Pläne prüfen.

**Ähnlich aussehender Gegenfall:** Eine alte Statistik kann korrekt bleiben, wenn sich relevante Daten kaum ändern. Niedriger Sample-Prozentsatz kann bei sehr großen Tabellen ausreichend sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Statistics` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gezielte Abfrage moderat; VOLL und inkrementelle Details durch CATALOG_DEEP/Cross-Database geschützt und begrenzt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `GEZIELT` erfordert Schema-/Objektfilter, liest Definition/Spalten und `sys.dm_db_stats_properties` für passende Statistiken; inkrementelle Partitionsdetails sind aus. |
| Teuerster Pfad | `VOLL` und `@MitIncrementellenDetails = 1` über alle sichtbaren Datenbanken, ohne Schwellen und mit `@MaxZeilen = 0`: jede Statistik plus jede inkrementelle Partition wird materialisiert. |
| Haupttreiber | Zahl passender Statistiken und Statistikspalten; für inkrementelle Statistiken zusätzlich Partitionen. Tabellenzeilenzahl wirkt nur auf zurückgegebene Properties, nicht als gescannte Nutzdatenmenge. |
| Skalierung | Pro Kandidatendatenbank wird dynamisches Katalog-SQL kompiliert. Haupt- und inkrementelles Detailresultset werden separat aufgebaut; Cross-Database-Kosten addieren sich pro Datenbank. |
| Ressourcen | Katalogseiten, `dm_db_stats_properties`/`dm_db_incremental_stats_properties`, CPU für Filter/Joins und TempDB/Transfer. Histogramme selbst werden hier nicht gelesen. |
| Begrenzungswirkung | Objekt-/Statistikfilter und Modification-/Altersschwellen reduzieren fachliche Zeilen. `@MaxZeilen` ist TOP je Datenbank und je Haupt-/Detailquery, kein globales Parentlimit; Gesamtzeilen können bei mehreren Datenbanken darüber liegen. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`, `STATISTICS_TARGETED`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, ein `ExampleSchema.ExampleTable`, 100 Zeilen und keine inkrementellen Details. Danach eine konkrete Statistik oder Partition vertiefen. |
| Aussagegrenze | Properties sind Metadaten zum letzten Update, nicht Histogrammqualität oder aktuelle Kardinalitätsgenauigkeit. Modification Counter und Alter müssen mit Zeilenzahl, Filterstatistik, Partition und Planverhalten interpretiert werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie aktuell und repräsentativ sind die Statistiken, die der Cardinality Estimator für Schätzungen verwendet?

### Technischer Hintergrund

Statistiken enthalten Header, Dichteinformationen und ein Histogramm für die führende Statistikspalte mit maximal 200 Steps. Auto-/User-Created, Filter, Persisted Sample und `dm_db_stats_properties` liefern Aktualisierungs-, Row-, Sample- und Modification-Kontext.

### Datenkette

`sys.columns`, `sys.dm_db_incremental_stats_properties`, `sys.dm_db_stats_properties`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.stats`, `sys.stats_columns`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller gespeicherter Statistikstand seit letztem Update. Modification Counter beschreibt Änderungen seitdem, nicht deren genaue Verteilungswirkung.

### Bewertung und Gegenprobe

Rows, Rows Sampled, Samplingrate, Last Updated, Modifications, führende Spalte, Filter und betroffene Queryprädikate zusammen lesen. Eine alte unveränderte Statistik kann korrekt sein; eine junge stark gesampelte Statistik bei Skew kann problematisch sein.

### Typische Fehlinterpretation

Alter oder Modification Counter allein beweist keinen Schätzfehler. Auto-Update-Schwellen und asynchrones Update sind kontextabhängig.

### Folgeanalyse

`USP_StatisticsDistributionAnalysis`, Showplan Estimated/Actual Rows und Query Store Regression.

## Primärquellen

- [sys.dm_db_stats_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-stats-properties-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#5-monitorusp_statistics)
