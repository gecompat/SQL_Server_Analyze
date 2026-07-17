# Runbook: Backup- oder Integritätsrisiko

## Erstaufrufe

```sql
EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
      @DatabaseNames=N'[ExampleDatabase]',
      @MitPageDetails=0,
      @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_BackupChainAnalysis]
      @DatabaseNames=N'[ExampleDatabase]',
      @ResultSetArt='CONSOLE';
```

## Lesen

Datenbankstatus, PAGE_VERIFY, CHECKDB-Alter, suspect pages, Backupchecksums, LSN-Gaps, Restoreevidenz und HADR-Reparaturen.

## Warum

Negative Evidenz kann auf Schaden oder nicht wiederherstellbare Ketten hinweisen. Fehlende negative Evidenz ist kein Integritätsbeweis.

## Gegenprobe

Vollständige CHECKDB-Strategie, Backupmedien und realer Restore-Test.

## Nicht tun

Kein Repair oder Datenverlust akzeptierendes Vorgehen allein aus dem Analysefinding ableiten.
