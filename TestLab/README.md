# Spielbare SQL Server Analyze-Beispiele

`TestLab` stellt lokale, synthetische Beispiele bereit. Die allgemeine
Provisionierung und der Container-Lifecycle bleiben vollständig in
`SQL_Server_Lab`; dieses Repository liefert nur den Beispielkatalog, die
Analyze-Installation und fachliche Szenarioausführung.

## Katalog prüfen

```powershell
pwsh -File ./TestLab/Test-AnalyzeExample.ps1
```

## Blocking automatisch verifizieren

```powershell
pwsh -File ./TestLab/Start-AnalyzeExample.ps1 `
  -Example BLOCKING-001 `
  -Version 2022 `
  -Provider docker `
  -Mode Verify
```

Der Verify-Modus erzeugt sein zufälliges Passwort ausschließlich im laufenden
Prozess. Er installiert das Framework, baut den synthetischen Blocking-Zustand
auf, prüft die stabile Finding-Invariante und entfernt das Lab anschließend.
Die vollständige Frameworkinstallation benötigt das Lab-Ressourcenprofil
`standard` (4 GB); das frühere 2-GB-Compact-Ziel erwies sich im nativen Lauf als
nicht stabil.
Vor der Installation wartet der Runner zusätzlich ein begrenztes
60-Sekunden-Fenster ab, weil die Containerimages Logins bereits während der
ersten Wiederherstellung interner Systemdatenbank-Indizes annehmen können.

## Blocking interaktiv untersuchen

```powershell
$password = Read-Host 'Temporäres SA-Passwort' -AsSecureString
$example = & ./TestLab/Start-AnalyzeExample.ps1 `
  -Example BLOCKING-001 `
  -Version 2022 `
  -Provider podman `
  -Mode Interactive `
  -SaPassword $password
$example
```

Der Rückgabewert nennt die beiden Session-Skripte, das Analyse- und das
Cleanup-Skript im ignorierten Laufzeitordner unter
`C:\rep\tmp\SQL_Server_Analyze`. Die Skripte werden in dieser Reihenfolge mit
den öffentlichen `SQL_Server_Lab`-Cmdlets oder in getrennten SQL-Sitzungen
ausgeführt. Abschließend wird das Lab mit dem ausgegebenen Removal-Befehl
entfernt.

`-KeepOnFailure` erhält ausschließlich ein fehlgeschlagenes Verify-Lab zur
lokalen Diagnose. Der normale Erfolgs- und Fehlerpfad bereinigt den exakten
Lab-Run; globale Docker- oder Podman-Bereinigungen werden nicht ausgeführt.
