# [monitor].[USP_CurrentLog]

**Bereich:** Current State  
**Zweck:** Zeigt Logauslastung, Wiederverwendungswartegrund, VLF- und optional PVS-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentLog]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, eine Logdatei, einen VLF- oder PVS-Aspekt. Den jeweiligen Scope vor Summenbildung prüfen.

## So lesen

Used Percent, absolute Loggröße, `log_reuse_wait_desc`, Growth, VLF und offene Transaktionen gemeinsam lesen.

## Warum kann das problematisch sein?

Hohe Nutzung ist besonders kritisch, wenn Wiederverwendung durch eine alte Transaktion, fehlende Logbackups oder HA-/Replikations-Lag blockiert wird. Reines Vergrößern behebt die Ursache nicht.

## Wann ist es kein Problem?

Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind.

## Beispiel und Folgeschritt

95 % genutzt plus `ACTIVE_TRANSACTION` plus zwei Stunden alte Transaktion: Primärursache ist die offene Transaktion. `USP_CurrentTransactions`, Backupstatus und Kapazität prüfen.

[Technische Detailbeschreibung](../02_Current_State.md#9-monitorusp_currentlog)
