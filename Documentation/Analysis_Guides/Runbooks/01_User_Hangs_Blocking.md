# Runbook: Benutzer melden Hänger oder Blocking

## 1. Sicherer Erstaufruf

```sql
EXEC [monitor].[USP_CurrentOverview]
      @MitIO = 0,
      @SampleSeconds = 0,
      @ResultSetArt = 'CONSOLE';
```

## 2. Zuerst lesen

- Childstatus,
- aktive Requests mit hoher Elapsed Time,
- `BlockingSessionId`, Waittyp und Waitzeit,
- offene Transaktionen,
- Log-Wiederverwendungsgrund.

## 3. Entscheidung

- Lockwait vorhanden → `USP_CurrentBlocking`.
- Root Blocker sleeping/offene Transaktion → `USP_CurrentTransactions`.
- kein Lockwait → Waittyp bestimmt I/O-, Grant-, CPU- oder Netzwerkanalyse.

## 4. Warum

Hohe Laufzeit allein erklärt keinen Hänger. Hohe Laufzeit plus niedrige CPU plus dominierende Lockwartezeit zeigt, dass der Request nicht arbeiten kann.

## 5. Nicht tun

Nicht zuerst Opfer-Sessions beenden. Root Blocker, Geschäftsvorgang, Rollbackkosten und Fortschritt prüfen.

## 6. Historische Gegenprobe

`USP_ExtendedEventsBlockedProcesses` und gegebenenfalls Deadlocks/Query Store verwenden.
