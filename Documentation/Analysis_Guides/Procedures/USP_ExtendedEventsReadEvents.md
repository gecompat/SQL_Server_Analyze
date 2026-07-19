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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche einzelnen XE-Ereignisse sind im Ring Buffer oder Event File erhalten und erfüllen die Filter?

### Technischer Hintergrund

`sys.fn_xe_file_target_read_file` liest Event-File-Fragmente; Ring-Buffer-XML stammt aus Runtime-Targetdaten. Event XML enthält Timestamp, Datafelder und Actions mit eventabhängiger Struktur. Parser müssen fehlende Felder tolerieren.

### Datenkette

`master.sys.databases`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Einzelereignisse innerhalb erhaltener Targetretention. Event-File-Wildcards, Rollover und UTC-Zeit sind relevant.

### Bewertung und Gegenprobe

Eventname, Timestamp, Session/Target, Sequence/Datei, Data/Actions und Parsewarnungen lesen. Filter erst nach sicherem Scope anwenden, um falsche Leere zu erkennen.

### Typische Fehlinterpretation

Keine Zeile bedeutet nicht kein Ereignis: Session/Event/Action, Predicate, Startzeit, Rollover, Drop und Dateizugriff prüfen.

### Folgeanalyse

Spezialisierte Deadlock-/Blocked-Process-Procedure oder manuelle XML-Vertiefung.

[Technische Detailbeschreibung](../06_Extended_Events.md#2-monitorusp_extendedeventsreadevents)
