# [monitor].[USP_Columnstore]

**Bereich:** Object und Index  
**Zweck:** Analysiert Columnstore-Rowgroups und optional Segmente sowie Dictionaries.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Columnstore]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitPhysicalStats = 0,
      @MitSegmenten = 0,
      @MitDictionaries = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Im Basisresultset entspricht eine Zeile einer Rowgroup. Segment- und Dictionaryresultsets besitzen jeweils ihre eigene Spalten-/Dictionarygranularität.

## So lesen

Rowgroupzustand, Total/Deleted/Active Rows, Fullness, Trim Reason, Alter und Nutzungskontext vergleichen.

## Warum kann das problematisch sein?

Viele kleine komprimierte Rowgroups oder hohe Deleted-Rows-Anteile können Kompression, Segment Elimination und Scaneffizienz verschlechtern.

## Wann ist es kein Problem?

Offene Delta Stores während Last und Deleted Rows in selten gelesenen Archivpartitionen können akzeptabel sein.

## Kommentiertes Beispiel

40 % Deleted Rows in einer großen, häufig gescannten Rowgroup ist relevanter als 40 % in einer kleinen Archivpartition. Ladebatch, Tuple Mover, Partitionierung und Pläne prüfen.

[Technische Detailbeschreibung](../03_Object_Index.md#8-monitorusp_columnstore)
