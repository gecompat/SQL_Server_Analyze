# [monitor].[USP_CurrentIO]

**Bereich:** Current State  
**Zweck:** Bewertet Datei-I/O kumulativ oder als kurzes Delta-Sample.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentIO]
      @SampleSeconds = 10
    , @ResultSetArt = 'CONSOLE';
```

Ohne `@DatabaseNames` oder `@DatabaseNamePattern` werden alle sichtbaren,
online befindlichen Benutzerdatenbanken ausgewertet. Systemdatenbanken bleiben
mit `@SystemdatenbankenEinbeziehen = 0` ausgeschlossen. Das Modul ist
leichtgewichtig und verlangt keine High-Impact-Bestätigung.

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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viele I/O-Operationen und Bytes wurden pro Datei verarbeitet, und wie lange dauerten sie?

### Technischer Hintergrund

`sys.dm_io_virtual_file_stats` liefert kumulative Read-/Writeanzahl, Bytes und Stalls pro Daten-/Logdatei. Aus Differenzen zweier Messungen entstehen aktuelle IOPS, Durchsatz und Latenz. Die Procedure liest die DMV serverweit mit `(NULL, NULL)` genau einmal je Messzeitpunkt und schränkt die materialisierte Menge danach relational auf die Datenbankkandidaten ein. Dateimetadaten lösen Database/File/Type auf.

### Ausgabe

CONSOLE liefert ohne separates technisches Meta-Grid genau die lesbare
Dateiansicht. Bei leerem Ergebnis erscheint eine einzelne verständliche Zeile.
TABLE verwendet `@ResultTablesJson` mit den stabilen Namen `moduleStatus`,
`files` und `warnings`; alle Ziele stammen aus derselben Messung.

### Datenkette

`master.sys.master_files`, `sys.dm_io_virtual_file_stats`.

### Zeit- und Scope-Modell

Kumulativ seit Start/Dateizustand oder Sampledelta. Reset, Restart, Dateiwechsel und sehr kleine Nenner begrenzen Vergleichbarkeit.

### Bewertung und Gegenprobe

Reads und Writes getrennt bewerten; Latenz immer mit Operationszahl, Bytes und Sampledauer lesen. Datenfiles und Logfiles besitzen unterschiedliche I/O-Muster. Parallel sichtbare PAGEIOLATCH/WRITELOG- und Requestwerte erhöhen die Evidenz.

### Typische Fehlinterpretation

Eine einzelne Operation mit 500 ms erzeugt 500 ms Durchschnitt, aber keine anhaltende Last. DMV-Stall enthält Queueing aus SQL-Sicht, nicht automatisch reine Geräte-Servicezeit.

### Folgeanalyse

`USP_CurrentRequests`, `USP_CurrentWaits`, `USP_CurrentLog`; externe OS-/Storage-Telemetrie.

[Technische Detailbeschreibung](../02_Current_State.md#8-monitorusp_currentio)
