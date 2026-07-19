# [monitor].[USP_Statistics]

**Bereich:** Object und Index  
**Zweck:** Inventarisiert Statistikdefinition, Materialisierung, Sample, Änderungen und inkrementelle Details.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Statistics]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Im Hauptresultset beschreibt eine Zeile eine Statistik. Inkrementelle Details besitzen eine zusätzliche Partitionsgranularität.

## So lesen

Rows, Rows Sampled, Modification Counter, führende Spalte, Filter und letzten Updatezeitpunkt gemeinsam lesen.

## Warum kann das problematisch sein?

Unpassendes Sample oder relevante Datenänderungen können Kardinalitätsschätzungen und dadurch Joinart, Grant und Zugriffspfad verschlechtern.

## Wann ist es kein Problem?

Eine alte Statistik kann korrekt bleiben, wenn sich relevante Daten kaum ändern. Niedriger Sample-Prozentsatz kann bei sehr großen Tabellen ausreichend sein.

## Beispiel und Folgeschritt

Zehn Jahre alt plus Modification Counter 0 ist nicht automatisch schlecht. Eine gestern aktualisierte Statistik kann einen neu entstandenen Tail dennoch schlecht abbilden. Histogramm und betroffene Pläne prüfen.

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

[Technische Detailbeschreibung](../03_Object_Index.md#5-monitorusp_statistics)
