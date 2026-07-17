# [monitor].[USP_ExtendedEventsReadEvents]

**Bereich:** Extended Events  
**Zweck:** Liest generische Events aus Event Files oder Ring Buffer.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsReadEvents]
      @SourceExtendedEventSessionName = N'system_health',
      @Quelle = 'EVENT_FILE',
      @VonUtc = DATEADD(HOUR, -1, SYSUTCDATETIME()),
      @MitEventXml = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Eventzeile entspricht einem erfassten XE-Ereignis. SourceStatus-Zeilen beschreiben dagegen die Lesbarkeit der Quelle.

## So lesen

SourceStatus zuerst, dann Quelle, Zeitfenster, Eventname, Datei/Offset und Payloadverfügbarkeit.

## Warum kann das problematisch sein?

Fehlende Events können durch Rollover, Retention, falschen Pfad, gestoppte Session oder fehlende Eventkonfiguration entstehen.

## Wann ist es kein Problem?

Ein leeres, korrekt erfasstes enges Fenster kann tatsächlich bedeuten, dass kein passendes Event auftrat.

## Beispiel und Folgeschritt

Keine Events im Ringbuffer nach Restart sagt nichts über die Zeit davor. Event Files und deren Retention prüfen.

## Eigenlast

`TOP` begrenzt Ergebniszeilen, nicht zwingend den physischen XEL-Scan. Zeitraum und Eventfilter eng setzen.

[Technische Detailbeschreibung](../06_Extended_Events.md#2-monitorusp_extendedeventsreadevents)
