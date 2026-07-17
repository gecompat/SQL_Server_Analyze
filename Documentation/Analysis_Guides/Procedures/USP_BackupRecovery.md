# [monitor].[USP_BackupRecovery]

**Bereich:** Infrastruktur  
**Zweck:** Bewertet Backupalter, Recovery Model, Logbackupbedarf und Restorehistorie.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupRecovery]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Hauptzeile beschreibt den Backup-/Recoveryzustand einer Datenbank; Historienresultsets enthalten einzelne Backup- oder Restoreereignisse.

## So lesen

Recovery Model, Alter von Full/Diff/Log, letzte erfolgreiche Sicherung, Copy-only und Restorehistorie gemeinsam lesen.

## Warum kann das problematisch sein?

Alte oder fehlende Logbackups vergrößern möglichen Datenverlust und können bei FULL/BULK_LOGGED die Log-Wiederverwendung verhindern.

## Wann ist es kein Problem?

In SIMPLE Recovery sind Logbackups nicht vorgesehen. Eine fehlende Differential-Sicherung kann durch die Backupstrategie abgedeckt sein.

## Beispiel und Folgeschritt

FULL Recovery, letztes Logbackup vor sechs Stunden, RPO 30 Minuten: kritisch. SIMPLE plus kein Logbackup: erwartbar. Backupkette und echten Restore-Test prüfen.

[Technische Detailbeschreibung](../07_Infrastructure.md#5-monitorusp_backuprecovery)
