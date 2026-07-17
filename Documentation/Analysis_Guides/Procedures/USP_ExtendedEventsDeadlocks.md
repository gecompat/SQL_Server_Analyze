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

[Technische Detailbeschreibung](../06_Extended_Events.md#3-monitorusp_extendedeventsdeadlocks)
