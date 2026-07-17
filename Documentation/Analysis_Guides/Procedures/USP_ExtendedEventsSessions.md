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

[Technische Detailbeschreibung](../06_Extended_Events.md#1-monitorusp_extendedeventssessions)
