# [monitor].[USP_CurrentMemoryGrants]

**Bereich:** Current State  
**Zweck:** Zeigt angeforderte, gewährte und genutzte Query Execution Memory Grants.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentMemoryGrants]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem sichtbaren Memory-Grant-Vorgang einer Query beziehungsweise eines Requests.

## So lesen

`RequestedMemoryMb`, `GrantedMemoryMb`, `UsedMemoryMb`, Wartezeit, Queryzustand und konkurrierende Grants vergleichen.

## Warum kann das problematisch sein?

Ein großer angeforderter Grant mit `GrantedMemoryMb=0` wartet auf verfügbaren Execution Memory. Viele wartende Requests können einen Stau bilden.

## Wann ist es kein Problem?

Ein großer gewährter und tatsächlich genutzter Grant kann für einen großen Sort oder Hash Join angemessen sein.

## Kommentiertes Beispiel

32 GB angefordert, 0 gewährt, 60 Sekunden `RESOURCE_SEMAPHORE`: Die Query rechnet nicht langsam, sie durfte noch nicht beginnen. Dagegen sind 32 GB gewährt und 28 GB genutzt bei einem geplanten großen Report plausibel.

## Folgeschritt

Plan, Kardinalität, DOP, Konkurrenz und `USP_ServerMemory` prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen oder erwarten Workspace Memory für Sorts, Hashes und ähnliche Operatoren?

### Technischer Hintergrund

Der Optimizer schätzt den benötigten Query Execution Memory Grant aus Plan, Kardinalität, Row Size und DOP. Ein Request kann erst starten beziehungsweise bestimmte Operatoren ausführen, wenn der Grant verfügbar ist. `sys.dm_exec_query_memory_grants` zeigt angefordert, gewährt, genutzt und ideal sowie wartende Grants.

### Datenkette

`sys.databases`, `sys.dm_exec_query_memory_grants`, `sys.dm_exec_query_resource_semaphores`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`.

### Zeit- und Scope-Modell

Flüchtiger Zustand. Wartende Grants verschwinden bei Zuteilung/Abbruch; Nutzung verändert sich während der Ausführung.

### Bewertung und Gegenprobe

Wartedauer, Requested/Granted/Used/Ideal, DOP, Konkurrenz und Planoperatoren zusammen lesen. Große tatsächlich genutzte Grants können korrekt sein; großer ungenutzter Anteil spricht eher für Übergrant oder Schätzfehler.

### Typische Fehlinterpretation

`GrantedMemory=0` kann vor Start normal kurz sichtbar sein; ein einzelner großer Grant beweist keinen Servermemorymangel. Server Memory und Query Execution Memory sind verwandte, aber nicht identische Ebenen.

### Folgeanalyse

`USP_CurrentRequests`, `USP_ServerMemory`, Showplan/Statistics und Query Store Runtime.

[Technische Detailbeschreibung](../02_Current_State.md#6-monitorusp_currentmemorygrants)
