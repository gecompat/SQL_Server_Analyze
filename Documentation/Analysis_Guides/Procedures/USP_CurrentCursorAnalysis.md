# [monitor].[USP_CurrentCursorAnalysis]

Inventarisiert aktive Cursor; Details werden nur für eine ausdrücklich angegebene Session aktiviert.

```sql
EXEC [monitor].[USP_CurrentCursorAnalysis] @SessionIds = N'57', @IncludeCursorDetails = 1, @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt einen sichtbaren Cursor mit Session, Status, Typ und kumulativen Arbeitswerten.

## So lesen

Prüfen Sie zuerst `StatusCode` und `IsPartial`. Offenstatus, Worker Time, Reads, Writes und Dormanz liefern Kontext, aber keinen Ursachenbeweis.

## Warum kann das problematisch sein?

Langlebige Cursor können lange Transaktionen oder wiederholte zeilenweise Arbeit begleiten.

## Wann ist es kein Problem?

Kurze lokale Cursor und kleine administrative Schleifen können erwartetes Verhalten sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Cursor benötigen eine gezielte Gegenprobe?

### Technischer Hintergrund

`sys.dm_exec_cursors(0)` liefert die Übersicht; der Detailpfad schränkt sie auf eine Session ein. Es wird kein Cursor verändert.

### Datenkette

`sys.dm_exec_cursors(0)` → begrenztes Resultset → optionale Sessiondetails.

### Source Select

```sql
SELECT TOP (200) [session_id], [cursor_id], [name], [properties], [is_open], [worker_time], [reads], [writes]
FROM [sys].[dm_exec_cursors](0)
WHERE [session_id] > 0
ORDER BY [worker_time] DESC;
```

**Wichtig für die Eigenlast:** `@SessionIds` akzeptiert in diesem bewusst begrenzten Analysepfad genau eine bekannte Session-ID. Begrenzen Sie zusätzlich die Ausgabe mit `@MaxZeilen`.

### Zeit- und Scope-Modell

Die Ausgabe ist ein flüchtiger Instanzsnapshot; Cursor können während der Analyse verschwinden.

### Bewertung und Gegenprobe

Korrelieren Sie auffällige Sessions mit Requests, Blocking, Transaktionen und Anwendungskontext.

### Typische Fehlinterpretation

Ein hoher kumulativer Wert beweist keine aktuell hohe Last.

### Folgeanalyse

Prüfen Sie `USP_CurrentRequests`, `USP_CurrentBlocking` und den zugehörigen Plan im gleichen Zeitfenster.

[Technische Detailbeschreibung](../../../Code/02_CurrentState/110_USP_CurrentCursorAnalysis.sql)
