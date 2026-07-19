# [monitor].[USP_BackupChainAnalysis]

**Bereich:** Infrastruktur  
**Zweck:** Prüft Full-/Diff-/Log-Beziehungen, LSN-Folgen und optionale Restoreevidenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BackupChainAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HistoryDays = 35,
      @MitRestoreEvidence = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile ein Backup, eine Kettenbeziehung, ein LSN-Segment, Restoreevidenz oder ein Finding.

## So lesen

Full-Basis, Differential Base, Log-LSN-Folge und Gaps in zeitlicher Reihenfolge lesen.

## Warum kann das problematisch sein?

Eine unterbrochene LSN-Kette kann Point-in-Time-Restore verhindern. Vorhandene Dateien garantieren keine wiederherstellbare Folge.

## Wann ist es kein Problem?

Copy-only Full verändert die Differential Base nicht und darf nicht als Kettenbruch bewertet werden.

## Beispiel und Folgeschritt

Full und viele Logbackups vorhanden, aber ein LSN-Segment fehlt: Restore bis zum Ende nicht möglich. Medien und echten Restore testen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist aus sichtbaren Backupsets eine technisch konsistente Restorekette mit passender Full-/Diff-/Log-LSN-Folge rekonstruierbar?

### Technischer Hintergrund

Fullbackups definieren Database Backup LSN/Checkpoint; Differentials basieren auf Differential Base; Logbackups decken First/Last LSN und Recovery Forks ab. CopyOnly beeinflusst Differential Base beziehungsweise Logkette unterschiedlich. Restorefolge muss LSN- und Forkkonsistenz wahren.

### Datenkette

`msdb.dbo.backupset`, `msdb.dbo.restorehistory`.

### Zeit- und Scope-Modell

`msdb`-Metadaten im gewählten Fenster; ein zu kurzes Fenster kann die notwendige Basis ausblenden.

### Bewertung und Gegenprobe

Recovery Fork, Fullbasis, Differential Base, Log First/Last LSN, Gap-/Overlapindikatoren, CopyOnly und Backupzeiten prüfen. Kette je gewünschtem Restorezeitpunkt bewerten.

### Typische Fehlinterpretation

Metadatenkonsistenz beweist nicht, dass Medien vorhanden, unbeschädigt, entschlüsselbar oder zugreifbar sind. Ein vermeintliches Gap kann durch außerhalb des Fensters liegende Sets entstehen.

### Folgeanalyse

Echter Restoretest, `USP_BackupRecovery`, Encryption-/Certificate-Governance.

[Technische Detailbeschreibung](../07_Infrastructure.md#9-monitorusp_backupchainanalysis)
