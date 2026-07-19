# [monitor].[USP_CurrentBlocking]

**Bereich:** Current State  
**Zweck:** Rekonstruiert aktuelle Blockingkanten und -ketten bis zum Root Blocker.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentBlocking]
      @MinWaitMs = 1000,
      @ResultSetArt = 'CONSOLE';
```

Lockdetails nur gezielt aktivieren.

## Eine Zeile bedeutet

Im Kettenresultset beschreibt eine Zeile eine Blockingkante. Eine vollständige Kette besteht häufig aus mehreren Zeilen; Lockdetails besitzen eine eigene Granularität.

## So lesen

Vom `LeafSessionId` über jede Kante bis `RootBlockingSessionId` gehen. Waitzeit, Ressource, Aktivität und Transaktionszustand des Root Blockers vergleichen.

## Warum kann das problematisch sein?

Viele Opfer können von einer einzelnen Root-Session abhängen. Das Beenden eines Opfers beseitigt die gehaltene Ressource nicht.

## Wann ist es kein Problem?

Kurze Lockwartezeiten gehören zur transaktionalen Konsistenz. Kritischer sind wachsende, wiederkehrende Ketten und SLA-Auswirkungen.

## Beispiel und Folgeschritt

Zehn Sessions warten zwei Minuten auf eine sleeping Session mit offener Transaktion: starke Root-Blocker-Evidenz. Mit `USP_CurrentTransactions` und `USP_CurrentRequests` prüfen; erst danach betriebliche Eingriffe erwägen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Session blockiert welche andere Session, und wo liegt der Root Blocker der Kette?

### Technischer Hintergrund

Blocking entsteht, wenn ein Task einen Lock oder eine andere blockierende Ressource benötigt, die inkompatibel gehalten wird. Die Procedure korreliert Request-/Taskblocker, Sessions, SQL-Kontext und Locks und rekonstruiert Kanten beziehungsweise Ketten. Ein Root Blocker ist die oberste sichtbare Session ohne weiteren sichtbaren Blocker.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_waiting_tasks`, `sys.dm_tran_locks`.

### Zeit- und Scope-Modell

Momentaufnahme. Ketten können während der Rekonstruktion wachsen, verschwinden oder ihre Root-Session wechseln.

### Bewertung und Gegenprobe

Anzahl Opfer, längste Wartezeit, Lock-/Ressourcentyp, offene Transaktion und Zustand des Root Blockers gemeinsam bewerten. Ein aktiv arbeitender Root Blocker kann Fortschritt machen; ein sleeping Root Blocker mit alter Transaktion ist verdächtiger.

### Typische Fehlinterpretation

Die am längsten wartende Session ist nicht automatisch Ursache. `KILL` eines Opfers entfernt den Root Lock nicht; `KILL` des Root Blockers kann langen Rollback und weitere Last auslösen.

### Folgeanalyse

`USP_CurrentTransactions`, `USP_CurrentRequests`; für Historie Blocked-Process-/Deadlock-XE.

[Technische Detailbeschreibung](../02_Current_State.md#3-monitorusp_currentblocking)
