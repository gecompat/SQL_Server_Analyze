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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welchen Lebenszyklus und Qualitätszustand besitzen Columnstore-Rowgroups?

### Technischer Hintergrund

Rows gelangen zunächst in Delta Stores oder direkt in komprimierte Rowgroups. Tuple Mover komprimiert geschlossene Delta Stores. Deletes markieren Rows logisch; Reorganization/Rebuild kann bereinigen. Trim Reasons und State erklären, warum Rowgroups kleiner als das Ziel sein können.

### Datenkette

`sys.column_store_dictionaries`, `sys.column_store_row_groups`, `sys.column_store_segments`, `sys.columns`, `sys.dm_db_column_store_row_group_physical_stats`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Rowgroupzustand; verändert sich durch Loads, Deletes, Tuple Mover und Wartung.

### Bewertung und Gegenprobe

Total/Deleted Rows, Deleted-Prozent, State, Alter, Größe, Trim Reason, offene/geschlossene Delta Stores und Workloadmuster kombinieren. Viele kleine Rowgroups verschlechtern Segmentelimination/Kompression eher als ein isolierter Prozentwert.

### Typische Fehlinterpretation

20 Prozent Deleted Rows in einer kleinen kalten Rowgroup ist nicht automatisch relevant. Direkte DML- und Bulkloadmuster sowie Partitionstrategie entscheiden.

### Folgeanalyse

Querypläne/Segmentelimination, Ladebatchgröße, Tuple-Mover-/Wartungskontext.

[Technische Detailbeschreibung](../03_Object_Index.md#8-monitorusp_columnstore)
