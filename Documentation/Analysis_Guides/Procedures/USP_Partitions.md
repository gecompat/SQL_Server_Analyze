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

[Technische Detailbeschreibung](../03_Object_Index.md#7-monitorusp_partitions)
