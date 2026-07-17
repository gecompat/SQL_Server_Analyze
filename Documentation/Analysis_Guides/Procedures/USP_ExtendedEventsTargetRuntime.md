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

[Technische Detailbeschreibung](../06_Extended_Events.md#5-monitorusp_extendedeventstargetruntime)
