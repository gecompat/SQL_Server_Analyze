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

[Technische Detailbeschreibung](../02_Current_State.md#6-monitorusp_currentmemorygrants)
