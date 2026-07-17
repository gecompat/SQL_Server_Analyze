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

[Technische Detailbeschreibung](../03_Object_Index.md#9-monitorusp_indexphysicalstats)
