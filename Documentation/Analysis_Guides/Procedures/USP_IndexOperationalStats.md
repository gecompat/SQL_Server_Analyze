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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche internen Zugriffsmuster, Allocations, Locks und Latches erzeugt ein Index?

### Technischer Hintergrund

`sys.dm_db_index_operational_stats` liefert Blatt-/Nichtblattoperationen, Range-/Singleton-Lookups, Page Allocations, Lock-/Latch-Waits und weitere Low-Level-Zähler. Diese Zähler spiegeln physische Arbeitsweise wider und ergänzen die gröbere Usage-Sicht.

### Datenkette

`sys.dm_db_index_operational_stats`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Kumulativ im Lebenszyklus der internen Struktur/Instanz. Werte können bei Neustart oder Strukturänderung zurückgesetzt werden.

### Bewertung und Gegenprobe

Zähler durch passende Aktivität normieren: Page Allocations pro Insert, Lockwaitzeit pro Lockwait, Latchwaitzeit pro Zugriff. Hohe absolute Werte sind bei stark genutzten Indizes erwartbar.

### Typische Fehlinterpretation

`leaf_allocation_count` ist nicht identisch mit dokumentiertem Page Split jeder Art. Eine Korrelation mit Fragmentierung/Fillfactor und DML-Muster ist nötig.

### Folgeanalyse

`USP_IndexPhysicalStats`, Current Blocking/Waits und konkrete DML-Pläne.

[Technische Detailbeschreibung](../03_Object_Index.md#3-monitorusp_indexoperationalstats)
