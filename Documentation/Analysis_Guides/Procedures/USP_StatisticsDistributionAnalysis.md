# [monitor].[USP_StatisticsDistributionAnalysis]

**Bereich:** Object und Index  
**Zweck:** Analysiert ausgewählte Histogramme auf Skew, dominante Schritte, Tail und Partitionsabweichungen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StatisticsDistributionAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @SchemaNames = N'[ExampleSchema]',
      @AnalyseModus = 'GEZIELT',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Statistik, eine Verteilungszusammenfassung, eine Partitionsvariation oder ein normalisiertes Finding.

## So lesen

Zuerst Sample und Modification, danach Dominant Step, Skew, Tail und Partitionsspread. Findings erst mit der zugrunde liegenden Verteilung bewerten.

## Warum kann das problematisch sein?

Starke Spitzen oder neue Tailwerte können dazu führen, dass ein Plan für häufige Parameter bei seltenen Parametern ungeeignet ist – oder umgekehrt.

## Wann ist es kein Problem?

Skew kann die reale Datenverteilung korrekt beschreiben und bei geeigneten Plänen völlig unkritisch sein.

## Beispiel und Folgeschritt

Ein Wert umfasst 70 % der Zeilen. Problematisch wird das erst, wenn seltene und häufige Parameter denselben Plan verwenden und stark unterschiedliche Zeilenmengen erzeugen. Query Store und Showplan vergleichen.

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

[Technische Detailbeschreibung](../03_Object_Index.md#6-monitorusp_statisticsdistributionanalysis)
