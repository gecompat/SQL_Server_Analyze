# [monitor].[USP_ExtendedEventsTargetRuntime]

**Bereich:** Extended Events  
**Zweck:** Zeigt Runtimezustand und optional Daten laufender XE-Targets.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsTargetRuntime]
      @MitTargetData = 0,
      @ResultSetArt = 'CONSOLE';
```

Targetdaten und Flush nur bewusst bestätigen.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Target einer laufenden Session. Optionales Targetdata-Resultset besitzt targetabhängige Struktur.

## So lesen

Targettyp, Laufzeitstatus, Pfad, Speicher, Event-/Bufferzähler und Dropped Events prüfen.

## Warum kann das problematisch sein?

Dropped Events oder zu kleine Targets bedeuten Evidenzverlust. Das Lesen bestimmter Runtime-Targets kann einen Flush auslösen.

## Wann ist es kein Problem?

Ein kleiner Ringbuffer kann für kurzfristige Ad-hoc-Diagnose passend sein, aber nicht für lange Historie.

## Beispiel und Folgeschritt

Session läuft, aber viele Events wurden verworfen: ein leeres Spezialresultset ist keine Entwarnung. Targetgröße, Eventrate und Event-File-Strategie prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Verliert, begrenzt oder rotiert das Target Ereignisse, und ist es für die gewünschte Historie geeignet?

### Technischer Hintergrund

Runtime-DMVs liefern Targettyp/-daten, Buffer-/Memory-/Eventcounter und je Version Drop-/Dispatchinformationen. Event File Konfiguration bestimmt Dateigröße/Rollover; Ring Buffer hat XML-/Memorygrenzen.

### Datenkette

`master.sys.databases`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Runtimezustand und Targetinhalt seit Sessionstart beziehungsweise Rollover.

### Bewertung und Gegenprobe

Dropped Events/Buffers, Memory, File/Ring-Buffer-Auslastung, Dispatch Latency, Retention Mode und Eventrate zusammen lesen. Target muss zur Ereignisrate passen.

### Typische Fehlinterpretation

`0 Drops` beweist keine ausreichende historische Retention; sauberes Rollover kann alte Ereignisse ohne Dropindikator entfernen.

### Folgeanalyse

Sessionkonfiguration anpassen, externe Dateiretention/Monitoring und Eventreader validieren.

[Technische Detailbeschreibung](../06_Extended_Events.md#5-monitorusp_extendedeventstargetruntime)
