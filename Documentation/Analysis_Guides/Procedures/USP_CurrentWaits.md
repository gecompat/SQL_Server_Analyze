# [monitor].[USP_CurrentWaits]

**Bereich:** Current State  
**Zweck:** Zeigt aktuelle oder kurz gesampelte Waits und ordnet sie Waitgruppen zu.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentWaits]
      @SampleSeconds = 5,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen sichtbaren Wait beziehungsweise eine Aggregation nach Session, Request, Waittyp oder Gruppe. Im Samplemodus ist das Delta maßgeblich.

## So lesen

Waittyp und Waitgruppe mit Dauer, Anzahl, Session, Request und Samplemodus lesen. Gesamtzeit und Wiederholung vor Einzelspitzen priorisieren.

## Warum kann das problematisch sein?

Ein dominanter Wait zeigt, wo Zeit verloren geht. Relevant wird er durch hohe Gesamtdauer, Wiederholung und konkrete Workloadauswirkung.

## Wann ist es kein Problem?

Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration.

## Beispiel und Folgeschritt

Ein einzelner `PAGEIOLATCH_SH` über 20 ms beweist kein Storageproblem. Viele solche Waits plus hohe Datei-Latenz und langsame Requests bilden dagegen eine belastbare I/O-Spur. Danach `USP_CurrentIO` verwenden.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Auf welche Ressourcen oder Ereignisse warten Tasks aktuell, und welche Waits dominierten Instanz oder Sample?

### Technischer Hintergrund

Die Procedure kombiniert aktuelle Waiting Tasks mit instanzweiten abgeschlossenen Waits und optionalem Delta. Ressource, Signalzeit, Taskparallelität und Waitfamilie gehören zum technischen Modell.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_sys_info`, `sys.dm_os_wait_stats`, `sys.dm_os_waiting_tasks`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Tasksnapshot plus kumulativer Kontext oder gültiges Sampledelta. Current Tasks werden vor der optionalen Samplingpause erfasst.

### Bewertung und Gegenprobe

Waittyp, Dauer, Anzahl, Resource/Signalanteil, Workloadwirkung und zweite Evidenzquelle kombinieren.

### Typische Fehlinterpretation

Ein Wait ist keine Root Cause und ein hoher kumulativer Wert kein aktuelles Problem.

### Folgeanalyse

Vollständige Vertiefung in `Deep_Analysis_Documentation_Draft.md`; je Familie Blocking, I/O, Grants, CPU oder HADR weiterverfolgen.

[Technische Detailbeschreibung](../02_Current_State.md#4-monitorusp_currentwaits)
