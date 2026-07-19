# [monitor].[USP_Partitions]

**Bereich:** Object und Index  
**Zweck:** Zeigt partitionsgenaue Größe, Grenzen, Ablage und Kompression.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Partitions]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Partition eines Indexes oder Heaps. Ein Objekt mit mehreren Indizes besitzt entsprechend mehrere Zeilen je Partitionsnummer.

## So lesen

RowCount und Größe je Partition, Grenzintervalle, Filegroup, Kompression und Indexausrichtung vergleichen.

## Warum kann das problematisch sein?

Ungünstige Grenzen oder nicht ausgerichtete Indizes können Partition Elimination, Switching und Wartung verhindern. Extreme Schieflage kann Hotspots bilden.

## Wann ist es kein Problem?

Leere Randpartitionen und ungleiche Größen sind bei Sliding-Window- oder Hot-/Cold-Design häufig beabsichtigt.

## Beispiel und Folgeschritt

Eine leere zukünftige Monatspartition ist normal. Eine aktuelle Partition mit 95 % aller Zeilen und fehlender Elimination verlangt Plan-, Statistik- und Designprüfung.

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

[Technische Detailbeschreibung](../03_Object_Index.md#7-monitorusp_partitions)
