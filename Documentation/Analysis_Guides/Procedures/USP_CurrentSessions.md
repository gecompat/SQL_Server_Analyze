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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?

### Technischer Hintergrund

`sys.dm_exec_sessions` hält den Sitzungskontext, während `sys.dm_exec_connections` Transport-/Verbindungsdaten und `sys.dm_exec_requests` aktuelle Arbeit ergänzt. Sessionzähler wie CPU oder Reads akkumulieren über die Session; Connection Pools können Sessions lange offen und `sleeping` halten.

### Datenkette

`master.sys.databases`, `sys.databases`, `sys.dm_exec_connections`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Sessionmomentaufnahme mit kumulativen Zählern seit Sessionbeginn. Session-IDs können nach Ende wiederverwendet werden; Uhrzeit und Login-/Connectionkontext gehören zur Identität.

### Bewertung und Gegenprobe

`sleeping` ohne offene Transaktion ist häufig normal. `sleeping` mit offener Transaktion, Locks oder wachsendem Logverbrauch ist wesentlich kritischer. Hohe kumulative CPU einer alten Poolsession beweist keine aktuelle Last.

### Typische Fehlinterpretation

`LastRequestEndTime` ist nicht automatisch Transaktionsende. Clientangaben wie Host/Program sind nicht manipulationssicher.

### Folgeanalyse

`USP_CurrentTransactions`; bei aktiver Arbeit `USP_CurrentRequests`; bei Auswirkungen `USP_CurrentBlocking`.

[Technische Detailbeschreibung](../02_Current_State.md#1-monitorusp_currentsessions)
