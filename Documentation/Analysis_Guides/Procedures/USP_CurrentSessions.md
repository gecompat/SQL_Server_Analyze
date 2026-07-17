# [monitor].[USP_CurrentSessions]

**Bereich:** Current State  
**Zweck:** Inventarisiert aktuelle Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentSessions]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt eine aktuell sichtbare Session; ein Request kann fehlen, wenn die Session gerade inaktiv ist.

## So lesen

Zuerst `SessionStatus`, `RequestStatus` und `OpenTransactionCount`, danach letzte Aktivität, kumulative CPU/I/O-Werte und Verbindungsinformationen.

## Warum kann das problematisch sein?

`sleeping` plus offene Transaktion bedeutet: Der Client führt nichts aus, hält aber möglicherweise Locks und verhindert Log-Wiederverwendung.

## Wann ist es kein Problem?

Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund.

## Beispiel und Folgeschritt

Acht Stunden verbunden, letzte Aktivität vor zehn Sekunden, keine offene Transaktion: unauffällig. Dieselbe Session mit zwei Stunden alter Transaktion: `USP_CurrentTransactions` und Blocking prüfen.

## Leere oder partielle Ausgabe

Ein eingeschränkter Berechtigungsscope kann fremde Sessions ausblenden. Vor einer Entwarnung Status, eigene Sessionfilter und Systemsessionfilter prüfen.

[Technische Detailbeschreibung](../02_Current_State.md#1-monitorusp_currentsessions)
