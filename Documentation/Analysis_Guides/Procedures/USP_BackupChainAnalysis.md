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

[Technische Detailbeschreibung](../07_Infrastructure.md#9-monitorusp_backupchainanalysis)
