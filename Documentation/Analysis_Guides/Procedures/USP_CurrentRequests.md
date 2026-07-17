# [monitor].[USP_CurrentRequests]

**Bereich:** Current State  
**Zweck:** Zeigt aktive Requests mit Laufzeit, CPU, I/O, Waits, Blocking, Grants, Parallelität und SQL-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentRequests]
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Spalten und exakte Vergleiche `RAW` verwenden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem aktuell sichtbaren Request innerhalb einer Session. Werte gelten bis zum Erfassungszeitpunkt und sind keine Rate.

## So lesen

Zuerst `ElapsedMs`, `CpuMs`, Reads und Writes vergleichen. Danach Wait, Blocker, Memory Grant, DOP und aktuellen Statementtext lesen.

## Warum kann das problematisch sein?

Hohe Laufzeit bei sehr niedriger CPU zeigt, dass die Zeit überwiegend mit Warten statt Rechnen verbracht wurde. Waittyp und Blocker erklären die nächste Untersuchungsrichtung.

## Wann ist es kein Problem?

Hohe CPU bei kurzer Laufzeit und hohem DOP kann eine produktive analytische Query sein, sofern sie erwartet ist und keine Konkurrenz verdrängt.

## Kommentiertes Beispiel

`ElapsedMs=180000`, `CpuMs=900`, `WaitType=LCK_M_X`, `WaitTimeMs≈176000`, `BlockingSessionId=74`: Fast die gesamte Laufzeit ist Lock-Wartezeit. Nicht zuerst CPU oder Index ändern, sondern mit `USP_CurrentBlocking` den Root Blocker und mit `USP_CurrentTransactions` dessen Transaktion prüfen.

## Leere oder partielle Ausgabe

Keine Zeile bedeutet nur, dass zum Snapshot kein passender Request sichtbar war. Filter, Rechte und das sehr kurze Beobachtungsfenster beachten.

[Technische Detailbeschreibung](../02_Current_State.md#2-monitorusp_currentrequests)
