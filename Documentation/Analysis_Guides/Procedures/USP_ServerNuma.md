# [monitor].[USP_ServerNuma]

**Bereich:** Server Health  
**Zweck:** Zeigt NUMA-Nodes, Schedulerverteilung und Memory-Node-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerNuma]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem NUMA-/Memory-Node oder einem Scheduler.

## So lesen

Schedulerzahl, Online-/Idle-Zustand, Memory Node, Foreign Memory und Last je Node vergleichen.

## Warum kann das problematisch sein?

Persistente Asymmetrie kann lokale CPU-Engpässe und Remote-Memory-Zugriffe begünstigen.

## Wann ist es kein Problem?

Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar.

## Beispiel und Folgeschritt

Ein Node dauerhaft voll, anderer nahezu idle und Sessions konzentriert: Affinity, Verbindungslast, Soft-NUMA und Schedulerwaits prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Scheduler und Memory auf SQLOS-/Hardware-NUMA-Nodes verteilt und gibt es sichtbare Ungleichgewichte?

### Technischer Hintergrund

NUMA hält CPU und lokal angebundenes Memory zusammen. SQLOS-Nodes/Scheduler verteilen Workers; Memory Nodes verwalten Locality. Soft-NUMA kann zusätzliche logische Gruppen erzeugen. Remote Memory Access kann teurer sein.

### Datenkette

`sys.dm_os_memory_nodes`, `sys.dm_os_nodes`, `sys.dm_os_schedulers`.

### Zeit- und Scope-Modell

Aktueller Node-/Schedulerzustand; Loadcounter sind Momentaufnahme oder kumulativ je Quelle.

### Bewertung und Gegenprobe

Online/Idle Schedulers, Runnable Tasks, Active Workers, Load Factor, Memory Nodezuordnung und wiederholte Samples vergleichen. Ein persistentes einseitiges Muster ist relevanter als ein Snapshot.

### Typische Fehlinterpretation

Ungleiche Momentaufnahme ist bei zufälliger Workload normal. Node ID ist kein direkter physischer Socketbeweis bei Soft-NUMA/VM.

### Folgeanalyse

`USP_ServerCpuTopology`, Current Requests und Server Memory.

[Technische Detailbeschreibung](../08_Server_Health.md#2-monitorusp_servernuma)
