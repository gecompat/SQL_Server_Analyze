# [monitor].[USP_PerformanceCounters]

**Bereich:** Server Health  
**Zweck:** Liest typisierte SQL-Server-Performance-Counter und berechnet bei Bedarf Sample-/Delta-Werte.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PerformanceCounters]
      @SampleSeconds = 5,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Counter beziehungsweise einer normalisierten Countermessung für eine Instanzbezeichnung.

## So lesen

`UNAVAILABLE_OBJECT` mit `IsPartial=1` bedeutet, dass die Instanz keine aktivierten oder nach Ausschluss alleinstehender Basiscounter keine auswertbaren Zeilen aus `sys.dm_os_performance_counters` bereitstellt. In diesem Zustand werden weder Snapshotwerte noch Raten synthetisiert.

Countertyp, Raw Value, Base, Delta, Samplezeit und normalisierten Wert unterscheiden.

## Warum kann das problematisch sein?

Rate- und Fraction-Counter werden ohne Typ/Base schnell falsch interpretiert. Kumulative Rohwerte spiegeln oft nur Uptime wider.

## Wann ist es kein Problem?

Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose.

## Beispiel und Folgeschritt

Page Life Expectancy besitzt keine universelle feste Grenze. Ein abrupter Einbruch plus Memory Pressure und I/O ist relevanter als ein einzelner Wert. Memory, I/O und Workload prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#13-monitorusp_performancecounters)
