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

[Technische Detailbeschreibung](../08_Server_Health.md#1-monitorusp_servercputopology)
