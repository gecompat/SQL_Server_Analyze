# Spielbare SQL Server Analyze-Beispiele

`TestLab` stellt lokale, synthetische Beispiele bereit. Die allgemeine
Provisionierung und der Container-Lifecycle bleiben vollständig in
`SQL_Server_Lab`; dieses Repository liefert nur den Beispielkatalog, die
Analyze-Installation und fachliche Szenarioausführung.

## Katalog prüfen

```powershell
pwsh -File ./TestLab/Test-AnalyzeExample.ps1
```

## Beispiel automatisch verifizieren

```powershell
pwsh -File ./TestLab/Start-AnalyzeExample.ps1 `
  -Example QUERY-STORE-001 `
  -Version 2025 `
  -Provider docker `
  -Mode Verify
```

Der Verify-Modus erzeugt sein zufälliges Passwort ausschließlich im laufenden
Prozess. Er installiert das Framework, baut den katalogisierten synthetischen
Zustand auf, prüft die stabile Szenario- und Analyzer-Invariante und entfernt
das Lab anschließend.
Die vollständige Frameworkinstallation benötigt das Lab-Ressourcenprofil
`standard` (4 GB); das frühere 2-GB-Compact-Ziel erwies sich im nativen Lauf als
nicht stabil.
Vor der Installation wartet der Runner zusätzlich ein begrenztes
60-Sekunden-Fenster ab, weil die Containerimages Logins bereits während der
ersten Wiederherstellung interner Systemdatenbank-Indizes annehmen können.

## Beispiel interaktiv untersuchen

```powershell
$saCredential = Read-Host 'Temporäres SA-Passwort' -AsSecureString
$example = & ./TestLab/Start-AnalyzeExample.ps1 `
  -Example BLOCKING-001 `
  -Version 2022 `
  -Provider podman `
  -Mode Interactive `
  -SaPassword $saCredential
$example
```

Der Rückgabewert nennt vorhandene Session-Skripte, das Analyse- und das
Cleanup-Skript im lokalen temporären Laufzeitordner. Die Skripte werden in dieser Reihenfolge mit
den öffentlichen `SQL_Server_Lab`-Cmdlets oder in getrennten SQL-Sitzungen
ausgeführt. Abschließend wird das Lab mit dem ausgegebenen Removal-Befehl
entfernt.

`-KeepOnFailure` erhält ausschließlich ein fehlgeschlagenes Verify-Lab zur
lokalen Diagnose. Der normale Erfolgs- und Fehlerpfad bereinigt den exakten
Lab-Run; globale Docker- oder Podman-Bereinigungen werden nicht ausgeführt.

## Katalogisierte Beispiele

| Beispiel | Primärer Analyzer | Bedienseite |
|---|---|---|
| `BLOCKING-001` | `USP_CurrentBlocking` | [Blocking](Examples/Blocking/README.md) |
| `QUERY-STORE-001` | `USP_QueryStoreAnalysis` | [Query Store](Examples/QUERY-STORE-001/README.md) |
| `TEMPDB-001` | `USP_CurrentTempDB` | [TempDB](Examples/TEMPDB-001/README.md) |
| `STATISTICS-001` | `USP_Statistics` | [Statistiken](Examples/STATISTICS-001/README.md) |
| `MEMORY-GRANTS-001` | `USP_CurrentMemoryGrants` | [Memory Grants](Examples/MEMORY-GRANTS-001/README.md) |
| `EXECUTION-PLAN-001` | `USP_ExecutionPlanAnalysis` | [Execution Plan](Examples/EXECUTION-PLAN-001/README.md) |
| `INDEX-USAGE-001` | `USP_MissingIndexes` | [Indexnutzung](Examples/INDEX-USAGE-001/README.md) |
