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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Was führt SQL Server jetzt aus und wodurch erklärt sich die bisherige Laufzeit?

### Technischer Hintergrund

`sys.dm_exec_requests` liefert Status, Command, Laufzeit, CPU, Reads/Writes, Blocking, Wait und Plan-/Statementhandles. Sessions/Connections geben Herkunft, Waiting Tasks zeigen parallele Task-Waits, Memory Grants den Workspace-Memory-Zustand. Statementoffsets schneiden aus dem Batchtext das aktuell ausgeführte Statement.

### Datenkette

`master.sys.databases`, `sys.databases`, `sys.dm_exec_connections`, `sys.dm_exec_input_buffer`, `sys.dm_exec_query_memory_grants`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_waiting_tasks`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Flüchtiger Snapshot; Requestzähler gelten seit Requeststart. Ein Request kann zwischen den einzelnen DMV-Lesungen Status oder Taskbild ändern.

### Bewertung und Gegenprobe

Elapsed, CPU, Reads, Writes, Row Count, Waits, Blocking und Grant zusammen lesen. Hohe Elapsed bei niedriger CPU legt Warten nahe; hohe CPU plus hohe Reads legt datenintensive Arbeit nahe. Bei mehreren Tasks ist der Request-Hauptwait nicht das vollständige Waitbild.

### Typische Fehlinterpretation

Ein angezeigter SQL-Text kann Batch statt Ursache sein; der aktive Statementausschnitt ist relevanter. `PercentComplete` existiert nur für unterstützte Commands und ist keine universelle Fortschrittsmessung.

### Folgeanalyse

Blocking → `USP_CurrentBlocking`; Grants → `USP_CurrentMemoryGrants`; I/O → `USP_CurrentIO`; Plan → `USP_ShowplanAnalysis`.

[Technische Detailbeschreibung](../02_Current_State.md#2-monitorusp_currentrequests)
