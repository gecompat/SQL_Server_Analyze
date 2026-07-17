# [monitor].[USP_CurrentTransactions]

**Bereich:** Current State  
**Zweck:** Zeigt offene Transaktionen, Alter, Sessionzustand, Logverbrauch und SQL-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTransactions]
      @MinAlterSekunden = 60,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt die Zuordnung einer sichtbaren Transaktion zu Session- und Datenbankkontext. Mehrere technische Transaktionszeilen können zu einer Session gehören.

## So lesen

Transaktionsalter, Sessionstatus, `OpenTransactionCount`, Logbytes, Blocking und SQL-Kontext gemeinsam lesen.

## Warum kann das problematisch sein?

Eine alte Transaktion kann Locks halten, Log-Wiederverwendung verhindern und bei Rollback lange benötigen. `sleeping` erhöht den Verdacht auf fehlendes Commit/Rollback.

## Wann ist es kein Problem?

Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind.

## Beispiel und Folgeschritt

Sleeping seit 30 Minuten, offene Transaktion, wachsender Logverbrauch und mehrere Blockierte: starke Evidenz für einen nicht abgeschlossenen Anwendungspfad. Blocking, Log und Anwendungstransaktion prüfen.

[Technische Detailbeschreibung](../02_Current_State.md#5-monitorusp_currenttransactions)
