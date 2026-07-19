# [monitor].[USP_IndexPhysicalStats]

**Bereich:** Object und Index  
**Zweck:** Liest physische Index-/Heap-Eigenschaften mit begrenzbarem Scanmodus.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexPhysicalStats]
      @DatabaseNames = N'[ExampleDatabase]',
      @ScanMode = 'LIMITED',
      @MinPageCount = 1000,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Kombination aus Index, Partition, Indexlevel und Allocation-Unit-Typ. Fragmentierung kann daher mehrfach je Index erscheinen.

## So lesen

Immer `PageCount` vor `AvgFragmentationPercent`; danach Seitendichte, Scanmodus, Ghosts und Forwarded Records.

## Warum kann das problematisch sein?

Große fragmentierte Strukturen können Range Scans und Read-Ahead beeinträchtigen. Niedrige Seitendichte erhöht Speicher- und I/O-Bedarf.

## Wann ist es kein Problem?

99 % Fragmentierung bei acht Seiten ist praktisch irrelevant. Bei punktuellen Seeks kann hohe Fragmentierung weniger wichtig sein.

## Kommentiertes Beispiel

Fünf Millionen Seiten, 45 % Fragmentierung und 55 % Dichte: viele zusätzliche Seiten müssen gelesen und gecacht werden. Acht Seiten mit denselben Prozentwerten: kaum Auswirkung.

## Eigenlast

`DETAILED` auf großen Datenbanken kann erhebliche I/O-Last verursachen. Standardmäßig `LIMITED` und engen Scope verwenden.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sehen Page Count, Fragmentierung, Seitendichte und Strukturebenen eines Rowstore-Indexes beim Aufruf aus?

### Technischer Hintergrund

`sys.dm_db_index_physical_stats` traversiert je Modus Allocation/Pages unterschiedlich tief. LIMITED liest weniger, SAMPLED schätzt bei größeren Strukturen, DETAILED untersucht alle Ebenen/Pages und ist teurer. Fragmentierung beschreibt logische Seitenreihenfolge; Page Space Used die Dichte.

### Datenkette

`sys.dm_db_index_physical_stats`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aufrufbezogene Messung. Währenddessen können DML und Wartung den Zustand verändern; Modus bestimmt Genauigkeit/Kosten.

### Bewertung und Gegenprobe

Page Count zuerst, dann Dichte, Fragmentierung, Scanlast, Storageart und Wartungsfolgen bewerten. Niedrige Dichte kann mehr I/O/Memory verursachen; Fragmentierung ist bei kleinen Indizes oft bedeutungslos.

### Typische Fehlinterpretation

Pauschale 5/30-Prozent-Regeln sind keine universelle Produktgrenze. Rebuild erzeugt Log, Locks, TempDB-/I/O-Last und kann Statistiken beeinflussen.

### Folgeanalyse

`USP_IndexUsage`, Operational Stats, Querypläne und geplantes Wartungsfenster.

[Technische Detailbeschreibung](../03_Object_Index.md#9-monitorusp_indexphysicalstats)
