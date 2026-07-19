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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Existieren im sichtbaren Fenster die erwarteten Full-, Differential- und Logbackups für das Recoverymodell?

### Technischer Hintergrund

`msdb` speichert Backup Sets, Medien-/Dateiinformation, Type, LSNs, Start/Finish, Size/Compression/Checksum und Damageindikatoren. Recovery Model bestimmt, ob eine kontinuierliche Logkette erwartet wird.

### Datenkette

`msdb.dbo.backupmediafamily`, `msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Zeit- und Scope-Modell

Historie innerhalb `msdb`-Retention; Datenträger/Dateien werden nicht geöffnet.

### Bewertung und Gegenprobe

Letzte Backupzeiten gegen RPO/Policy, Recovery Model, CopyOnly, Checksum, Damage, Größe/Dauer und Logbackupkontinuität prüfen. SIMPLE benötigt keine Logbackups, FULL ohne regelmäßige Logbackups verhindert Logtruncation.

### Typische Fehlinterpretation

Eine erfolgreiche Backup-Historyzeile beweist weder Dateiexistenz noch erfolgreichen Restore. `RESTORE VERIFYONLY` ist ebenfalls kein vollständiger Restoretest.

### Folgeanalyse

`USP_BackupChainAnalysis`, Database Integrity und regelmäßiger echter Restoretest.

[Technische Detailbeschreibung](../07_Infrastructure.md#5-monitorusp_backuprecovery)
