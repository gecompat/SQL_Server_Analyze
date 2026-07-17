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

[Technische Detailbeschreibung](../03_Object_Index.md#6-monitorusp_statisticsdistributionanalysis)
