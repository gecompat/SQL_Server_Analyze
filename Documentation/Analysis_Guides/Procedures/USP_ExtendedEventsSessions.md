# [monitor].[USP_ExtendedEventsSessions]

**Bereich:** Extended Events  
**Zweck:** Inventarisiert XE-Sessions, Laufzeitstatus, Events, Actions, Targets und Felder.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsSessions]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Session, einem Event, einer Action, einem Target oder einem konfigurierten Feld.

## So lesen

Sessiondefinition, Laufzeitstatus, Events, Actions, Targets, Predicates und Verlustzähler getrennt prüfen.

## Warum kann das problematisch sein?

Eine definierte, aber gestoppte Session sammelt nichts. Fehlende Actions begrenzen spätere Korrelation; Dropped Events machen Historie unvollständig.

## Wann ist es kein Problem?

Eine bewusst nur bei Bedarf gestartete Session darf gestoppt sein.

## Beispiel und Folgeschritt

Deadlockevent vorhanden, aber nur kleiner Ringbuffer: historische Tiefe kann fehlen. Danach Target Runtime und Events prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche XE-Sessions existieren, laufen sie, welche Events/Actions/Predicates und Targets besitzen sie?

### Technischer Hintergrund

Katalogsichten für Sessions, Events, Actions, Fields und Targets bilden Definitionen; Runtime-DMVs liefern gestartete Sessions und Targetdaten. Eventname allein reicht nicht, wenn für Analyse notwendige Actions wie SQL Text, DatabaseId oder SessionId fehlen.

### Datenkette

`master.sys.databases`, `sys.dm_xe_sessions`, `sys.server_event_session_actions`, `sys.server_event_session_events`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktuelle Konfiguration plus Runtimezustand; Serverstart und Sessionstart beeinflussen Targetinhalt.

### Bewertung und Gegenprobe

Definition und Runtime verbinden: Session vorhanden/läuft, Event enthalten, Predicate nicht zu eng, Actions ausreichend, Target erreichbar. Startup State ist nur Startverhalten.

### Typische Fehlinterpretation

Eine laufende Session beweist keine vollständige Erfassung. Eine konfigurierte, aber gestoppte Session besitzt möglicherweise alte Targetdaten.

### Folgeanalyse

`USP_ExtendedEventsTargetRuntime` und anschließend Eventreader.

[Technische Detailbeschreibung](../06_Extended_Events.md#1-monitorusp_extendedeventssessions)
