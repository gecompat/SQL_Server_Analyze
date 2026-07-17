# [monitor].[USP_CurrentIO]

**Bereich:** Current State  
**Zweck:** Bewertet Datei-I/O kumulativ oder als kurzes Delta-Sample.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentIO]
      @SampleSeconds = 10,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Datenbankdatei im gewählten Scope. Im Samplemodus beschreiben Raten und Latenzen die Differenz zwischen zwei Messpunkten.

## So lesen

Kumulative Durchschnittswerte und Sample-Delta trennen. Operationen, Bytes und Latenz für Reads und Writes je Datei vergleichen.

## Warum kann das problematisch sein?

Hohe aktuelle Latenz bei vielen I/O-Operationen kann Requests direkt bremsen. Ein alter kumulativer Durchschnitt kann hingegen durch ein historisches Ereignis verzerrt sein.

## Wann ist es kein Problem?

Eine einzige seltene langsame Operation kann einen extremen Durchschnitt erzeugen, ohne aktuelle Relevanz.

## Beispiel und Folgeschritt

500 ms Durchschnitt bei einer Operation seit Start: schwach. 25 ms im 10-Sekunden-Sample bei zehntausenden Reads plus `PAGEIOLATCH`: starke I/O-Spur. Betroffene Queries und externes Storage-Monitoring korrelieren.

[Technische Detailbeschreibung](../02_Current_State.md#8-monitorusp_currentio)
