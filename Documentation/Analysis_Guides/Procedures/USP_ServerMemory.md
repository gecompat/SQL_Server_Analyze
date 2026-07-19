# [monitor].[USP_ServerMemory]

**Bereich:** Server Health  
**Zweck:** Verknüpft OS-, SQL-Prozess-, Target-/Total-Memory- und Clerk-Evidenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerMemory]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memory-Zusammenfassung, Prozess-/OS-Signal oder einen Memory Clerk.

## So lesen

OS Available Memory, SQL Process Memory, Target/Total Server Memory, Pressure-Signale und größte Clerks gemeinsam lesen.

## Warum kann das problematisch sein?

OS- und SQL-Druck gleichzeitig kann Paging, Cacheverdrängung und Grantknappheit verursachen.

## Wann ist es kein Problem?

Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen.

## Beispiel und Folgeschritt

Total≈Target allein ist gesund. Total≈Target plus kaum OS-Reserve, Physical Memory Low und Grantwaits ist problematisch. Grants, Buffer Pool und max server memory prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Hat SQL Server oder das Betriebssystem Memory Pressure, und welche Clerks/Komponenten verwenden Speicher?

### Technischer Hintergrund

SQL Server Memory Manager balanciert Buffer Pool, Plan Cache, Query Execution Memory und weitere Clerks unter Min/Max Server Memory. OS-/Process-DMVs zeigen physisches Memory, Commit/Pagefile und Process Working Set. Target versus Total Server Memory und Memory Notifications liefern Drucksignale.

### Datenkette

`sys.configurations`, `sys.dm_exec_query_memory_grants`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_info`, `sys.dm_os_sys_memory`.

### Zeit- und Scope-Modell

Aktueller Zustand; Clerk-/Processwerte verändern sich, einzelne Counter seit Start.

### Bewertung und Gegenprobe

OS Available/Commit, process physical/virtual low flags, Total/Target, Max Server Memory, locked pages, clerk distribution, pending grants und paging zusammen lesen. Hoher SQL-Memoryverbrauch allein ist erwartbar.

### Typische Fehlinterpretation

`Available MBytes` oder PLE besitzen keine universellen Einzelgrenzen. Buffer Pool und Query Grants sind unterschiedliche Verbraucher; VM Ballooning kann außerhalb SQL-Sicht liegen.

### Folgeanalyse

`USP_BufferPoolAnalysis`, Current Memory Grants, Performance Counters und OS/Hypervisor-Telemetrie.

[Technische Detailbeschreibung](../08_Server_Health.md#3-monitorusp_servermemory)
