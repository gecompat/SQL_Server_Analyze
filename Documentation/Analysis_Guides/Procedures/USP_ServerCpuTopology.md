# [monitor].[USP_ServerCpuTopology]

**Bereich:** Server Health  
**Zweck:** Zeigt CPU-, Socket-, Core-, Scheduler- und NUMA-Topologie.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerCpuTopology]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Topologiezusammenfassung, einen Scheduler oder einen NUMA-Knoten.

## So lesen

Logische CPUs, Sockets, Cores, sichtbare/online Scheduler, Soft-NUMA und aktuelle Last vergleichen.

## Warum kann das problematisch sein?

Unerwartet offline oder hidden Scheduler und ungewöhnliche Topologie können Parallelität, Lizenzierung und Lastverteilung beeinflussen.

## Wann ist es kein Problem?

Soft-NUMA und bestimmte Schedulerzustände können absichtlich von SQL Server erzeugt werden.

## Beispiel und Folgeschritt

64 OS-CPUs, aber 32 online sichtbar: Lizenz-, Affinity-, Edition- und VM-Kontext prüfen, nicht sofort Hardwarefehler annehmen. NUMA und OS korrelieren.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche CPU-, Socket-, Core-, Hyperthread-, Scheduler- und Affinitystruktur sieht SQL Server?

### Technischer Hintergrund

SQL Server erstellt SQLOS-Scheduler für sichtbare logische CPUs unter Berücksichtigung von Edition, Lizenz-/Affinitykonfiguration und Onlinezustand. Sockets, NUMA Nodes, Cores und Hyperthreading beeinflussen Parallelität, Lizenzierung und Memorylocality.

### Datenkette

`sys.dm_os_nodes`, `sys.dm_os_schedulers`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Aktueller Instanz-/Startzustand; Hardwarezuweisung in VM/Container kann sich erst nach Neustart vollständig widerspiegeln.

### Bewertung und Gegenprobe

Visible/Online Schedulers, Physical/Logical CPU, Socket/Core-Verhältnis, Hyperthread Ratio, Affinity und Edition gemeinsam lesen. Ungleiche Schedulerverfügbarkeit oder unerwartete CPUzahl ist ein Konfigurationshinweis.

### Typische Fehlinterpretation

Viele CPUs bedeuten nicht automatisch mehr Queryleistung. MAXDOP, Cost Threshold, NUMA, Lizenzgrenze und Workloadparallelität bestimmen Nutzung.

### Folgeanalyse

`USP_ServerNuma`, Performance Counters, Current Requests/Waits.

[Technische Detailbeschreibung](../08_Server_Health.md#1-monitorusp_servercputopology)
