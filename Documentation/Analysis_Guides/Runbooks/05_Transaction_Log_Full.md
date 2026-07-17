# Runbook: Transaktionslog läuft voll

## Erstaufrufe

```sql
EXEC [monitor].[USP_CurrentLog] @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_CurrentTransactions] @MinAlterSekunden=60, @ResultSetArt='CONSOLE';
```

## Lesen

Used Percent und absolute Größe, `log_reuse_wait_desc`, offene Transaktionen, Logbackupalter, AG-/Replikations-/CDC-Kontext.

## Warum

Hohe Nutzung ist Symptom. Der Wiederverwendungswartegrund zeigt, warum Platz nicht freigegeben wird.

## Gegenprobe

`USP_BackupRecovery`, `USP_AvailabilityGroups`, `USP_ReplicationStatus` oder `USP_DataCaptureStatus` abhängig vom Wartegrund.

## Nicht tun

Nicht nur wachsen lassen oder Recovery Model ändern. RPO, Backupkette und Ursache prüfen.
