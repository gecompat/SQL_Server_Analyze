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

[Technische Detailbeschreibung](../03_Object_Index.md#5-monitorusp_statistics)
