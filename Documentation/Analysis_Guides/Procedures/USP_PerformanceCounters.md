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

Objektname, Countername und Instanzname allein sind nicht die vollständige technische Identität: `cntr_type` gehört zum Schlüssel. Gleich benannte Zeilen unterschiedlicher Typen werden deshalb getrennt gesampelt und nicht miteinander verrechnet.

Die reine Funktion `monitor.TVF_InterpretPerformanceCounter` kapselt denselben Rechenpfad. Sie ermöglicht einen deterministischen Resetnachweis mit fallendem Vorher-/Nachher-Wert, ohne einen Serverneustart während einer laufenden Procedure zu simulieren.

Countertyp, Raw Value, Base, Delta, Samplezeit und normalisierten Wert unterscheiden.

## Warum kann das problematisch sein?

Rate- und Fraction-Counter werden ohne Typ/Base schnell falsch interpretiert. Kumulative Rohwerte spiegeln oft nur Uptime wider.

## Wann ist es kein Problem?

Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose.

## Beispiel und Folgeschritt

Page Life Expectancy besitzt keine universelle feste Grenze. Ein abrupter Einbruch plus Memory Pressure und I/O ist relevanter als ein einzelner Wert. Memory, I/O und Workload prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie werden SQL-Server-Performance-Counter korrekt als Raw, Ratio, Rate oder Delta interpretiert?

### Technischer Hintergrund

`sys.dm_os_performance_counters` enthält Counter mit `cntr_type`. Manche sind Momentwerte, manche kumulative Zähler, manche benötigen Basecounter und manche Differenz/Zeit. Instanznamen trennen Total, DB, Buffer Node oder Objektinstanzen.

### Datenkette

`sys.dm_os_performance_counters`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Aktueller Rawstand oder Frameworksample; Reset typischerweise Engine-Start.

### Bewertung und Gegenprobe

Countertyp zuerst; Ratio mit passender Base, Rate als Delta pro Zeit, kumulative Counter mit Uptime. Instance Name und Units dokumentieren. Mehrere Counter als Kausalkette verwenden.

### Typische Fehlinterpretation

Raw `cntr_value` ist nicht allgemein Prozent oder pro Sekunde. Basecounter aus anderer Instanz/Probe erzeugt falsche Ratio.

### Folgeanalyse

Server Memory/CPU/IO, Current State und OS-Counter.

[Technische Detailbeschreibung](../08_Server_Health.md#13-monitorusp_performancecounters)
