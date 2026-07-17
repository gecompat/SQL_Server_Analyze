# [monitor].[USP_IndexOperationalStats]

**Bereich:** Object und Index  
**Zweck:** Zeigt partitionsgenaue DML-, Allocation-, Lock-, Latch- und Zugriffsaktivität.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexOperationalStats]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurMitAktivitaet = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index oder Heap **und einer Partition**. Werte verschiedener Partitionen dürfen nur bewusst aggregiert werden.

## So lesen

DML, Allocations, Locks, Latches und Scans vergleichen; absolute Zähler pro Aktivität, Wait oder Beobachtungszeit normalisieren.

## Warum kann das problematisch sein?

Viele Page Allocations pro Insert können Split-/Wachstumsdruck anzeigen. Hohe Lock-/Latchzeit kann Parallelität und Durchsatz begrenzen.

## Wann ist es kein Problem?

Hohe absolute Zähler sind bei stark genutzten Indizes normal. Verhältnis, Delta und aktuelle Auswirkung sind entscheidend.

## Beispiel und Folgeschritt

Eine Million Latch-Waits über ein Jahr kann weniger kritisch sein als 50.000 in fünf Minuten auf derselben Hot Page. Live-Waits, Keyverteilung, Plan und Contention prüfen.

[Technische Detailbeschreibung](../03_Object_Index.md#3-monitorusp_indexoperationalstats)
