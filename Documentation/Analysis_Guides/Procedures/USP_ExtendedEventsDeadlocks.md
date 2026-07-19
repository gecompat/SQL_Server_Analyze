# [monitor].[USP_ExtendedEventsDeadlocks]

**Bereich:** Extended Events  
**Zweck:** Zerlegt Deadlockgraphs in Summary, Victims, Processes und Resources.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsDeadlocks]
      @SourceExtendedEventSessionName = N'system_health',
      @VonUtc = DATEADD(HOUR, -24, SYSUTCDATETIME()),
      @MitDeadlockXml = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Summary-Zeile = Deadlock; Victim-Zeile = Opferprozess; Process-Zeile = Graphprozess; Resource-Zeile = beteiligte Lockressource.

## So lesen

Opfer, alle Prozesse, Ressourcen und Zugriffsreihenfolge gemeinsam lesen. Das Opfer ist nicht automatisch der Verursacher.

## Warum kann das problematisch sein?

Deadlock ist zyklisches Warten; SQL Server muss mindestens eine Transaktion abbrechen. Wiederholung erzeugt Fehler, Rollbacks und Durchsatzverlust.

## Wann ist es kein Problem?

Ein einmaliges Ereignis nach seltenem Deployment kann geringere Priorität besitzen als ein minütlich wiederkehrendes Muster.

## Beispiel und Folgeschritt

Zwei Sessions sperren Objekte in umgekehrter Reihenfolge: konsistente Zugriffsreihenfolge, Isolation, Indizes und Transaktionsumfang prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Sessions/Prozesse bildeten einen Deadlockzyklus, welches Opfer wurde gewählt und welche Ressourcen/Kanten waren beteiligt?

### Technischer Hintergrund

Der Lock Monitor erkennt einen Zyklus, wählt anhand Deadlock Priority und Rollbackkosten ein Opfer und erzeugt einen Deadlockgraph. XML enthält Victim List, Process List und Resource List mit Owner-/Waiter-Kanten.

### Datenkette

`sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`.

### Zeit- und Scope-Modell

Einzelne historische Deadlockereignisse soweit im Target erhalten.

### Bewertung und Gegenprobe

Zyklus vollständig lesen: Opfer ist nicht automatisch Verursacher. Zugriffsreihenfolge, Lockmodi, Isolation, Indexzugriff, Transaktionsscope und wiederkehrende Query-/Objektmuster bewerten.

### Typische Fehlinterpretation

Nur SQL-Text des Opfers zu optimieren kann den Zyklus unverändert lassen. Blocking ohne Zyklus erscheint nicht als Deadlock.

### Folgeanalyse

Showplan/Indexanalyse, Anwendungstransaktionsreihenfolge, wiederholte Graphen gruppieren.

[Technische Detailbeschreibung](../06_Extended_Events.md#3-monitorusp_extendedeventsdeadlocks)
