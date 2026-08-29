# [monitor].[USP_CurrentCursorAnalysis]

Inventarisiert aktive Cursor; Details werden nur für eine ausdrücklich angegebene Session aktiviert.

**Bereich:** Current State
**Zweck:** Liefert begrenzte Cursor-Ressourcen- und Dormanzevidenz für genau eine bekannte Session.
**Beobachtungsart:** flüchtiger instanzweiten DMV-Snapshot
**Kostenklasse:** MEDIUM_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist für eine bereits identifizierte Session vorgesehen. Sie zeigt, ob dort zum Lesezeitpunkt Cursor sichtbar sind und welche kumulativen Worker-, Read-, Write- und Dormanzwerte eine gezielte Gegenprüfung begründen. Der Detailpfad bleibt standardmäßig deaktiviert und akzeptiert höchstens eine Session-ID. Dadurch wird verhindert, dass eine allgemeine Current-State-Abfrage unbeabsichtigt alle Cursor der Instanz inventarisiert.

## Nicht beantwortete Fragen

Eine Cursorzeile beweist keine fehlerhafte Programmierung und keine aktuelle Lastursache. Kumulative Reads, Writes und Worker Time können aus früheren Fetches stammen. `dormant_duration` misst die Zeit seit dem Beginn der letzten Cursorabfrage und ist kein Beweis für eine offene Transaktion oder einen Ressourcenblocker. Die Procedure liest weder Clientcode noch Parameterwerte und leitet keine automatische Cursorersetzung ab.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentCursorAnalysis] @SessionIds = N'57', @IncludeCursorDetails = 1, @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

Ersetzen Sie `57` nur durch eine zuvor mit den Current-State-Modulen bestimmte Session-ID. Ohne `@IncludeCursorDetails = 1` liefert der Aufruf kontrolliert `NOT_EXECUTED`. Pipe-Listen mit mehreren IDs und Werte außerhalb des Sessionbereichs werden als `INVALID_PARAMETER` abgelehnt.

## Resultsets und Leserichtung

CONSOLE zeigt das benannte Resultset `cursors`; RAW trennt den Modulstatus von den Cursorzeilen. TABLE und JSON verwenden dieselbe begrenzte lokale Materialisierung. Lesen Sie zunächst `StatusCode`, `IsPartial` und Zielsession. Danach ordnen Sie `IsOpen`, `FetchStatus`, `WorkerTime`, `Reads`, `Writes`, `DormantDuration` und `FindingContext` ein. `RESOURCE_CONTEXT`, `DORMANT_CONTEXT` und `INVENTORY_ONLY` sind Kontextklassen, keine Severitywerte.

## Beispiele und Gegenbeispiele

Ein synthetischer `ExampleCursor` mit einem erfolgten Fetch kann als sichtbarer Positivfall dienen. Ein offener Cursor mit Reads oder Worker Time erhält `RESOURCE_CONTEXT`; eine ausreichend lange Dormanz kann `DORMANT_CONTEXT` ergeben. Ein Gegenbeispiel ist die Behauptung, ein hoher kumulativer Wert belege aktuelle CPU-Last. Ebenso ist ein lokaler administrativer Cursor nicht allein aufgrund seiner Existenz ein Defekt.

## Leere oder partielle Ausgabe

`AVAILABLE_EMPTY` bedeutet, dass für die ausgewählte Session beim Lesezeitpunkt kein Cursor sichtbar war. Der Cursor kann kurz zuvor geschlossen worden sein. `SOURCE_UNAVAILABLE` trennt einen Berechtigungs- oder DMV-Fehler vom fachlichen Leerfall. Wenn die Session zwischen Auswahl und DMV-Zugriff endet, ist eine leere Momentaufnahme zulässig und muss mit Requests und Sessionstatus gegengeprüft werden.

Bei einem Berechtigungsvergleich ist zu beachten, dass SQL Server 2019 `VIEW SERVER STATE` und SQL Server 2022 oder neuer `VIEW SERVER PERFORMANCE STATE` für die serverweite DMV vorsieht. Der tatsächliche Teststatus muss deshalb zusammen mit Product Major Version und Berechtigungsprofil dokumentiert werden.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM_OPT_IN` |
| Standardpfad | Keine DMV-Detailabfrage; Status `NOT_EXECUTED` |
| Teuerster Pfad | `sys.dm_exec_cursors` für eine aktive ressourcenreiche Session |
| Haupttreiber | Cursorzahl und interne Cursorstatistik der Zielsession |
| Skalierung | Auf genau eine Session und `@MaxZeilen` begrenzt |
| Ressourcen | Server-DMV-Zugriff und lokale Sortierung |
| Begrenzungswirkung | Session-ID begrenzt Quelle; `@MaxZeilen` begrenzt Materialisierung |
| Locking und Nebenwirkungen | Read-only; kein Fetch, Close oder Deallocate fremder Cursor |
| Schutzmechanismus | Explizites Opt-in und Einzelsessionvalidierung |
| Sicherer Einsatz | Nach vorheriger Identifikation einer konkreten Session |
| Aussagegrenze | Momentaufnahme und kumulative Werte beweisen keine Ursache |

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

## Primärquellen

- [sys.dm_exec_cursors](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-cursors-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../../Code/02_CurrentState/110_USP_CurrentCursorAnalysis.sql)
