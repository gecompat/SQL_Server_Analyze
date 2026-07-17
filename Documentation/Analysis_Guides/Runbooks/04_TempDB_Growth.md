# Runbook: TempDB wächst oder ist fast voll

## Erstaufrufe

```sql
EXEC [monitor].[USP_CurrentTempDB] @MitDateien=1, @ResultSetArt='CONSOLE';
EXEC [monitor].[USP_TempDBConfiguration] @ResultSetArt='CONSOLE';
```

## Lesen

Gesamtauslastung und Dateien, dann User Objects, Internal Objects und Version Store unterscheiden.

## Warum

- Internal Objects einer Session → Sort/Hash/Spill oder Worktable,
- Version Store → lange Snapshot-/RCSI-Transaktion,
- häufiges Wachstum → unzureichende Vorallokation/Growthsetting.

## Gegenprobe

Verursachende Session mit `USP_CurrentRequests`; Version Store mit `USP_CurrentTransactions`; Contention mit `USP_InternalContentionAnalysis`.

## Nicht tun

Nicht nur Dateien vergrößern, ohne Verbrauchsart und verursachenden Vorgang zu bestimmen.
