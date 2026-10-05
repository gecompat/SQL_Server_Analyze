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

## Project Adapter prüfen und ausführen

Der Adapter `EXECUTION-PLAN-001` liefert einen eigenständigen, synthetischen
Quick-Slice für den Project-Adapter-Vertrag von `SQL_Server_Lab`. Er installiert
den für die Execution-Plan-Analyse benötigten Frameworkteil, erzeugt einen
synthetischen Plan, prüft `USP_ExecutionPlanAnalysis` und entfernt anschließend
nur seine markergebundenen Datenbanken und den zugehörigen Lab-Run.

```powershell
pwsh -File ./TestLab/Test-AnalyzeProjectAdapter.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab

pwsh -File ./TestLab/Invoke-AnalyzeAdapterQuickScenario.ps1 `
  -Provider podman `
  -Version 2025 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Der identische Quick-Slice wurde am 30. August 2026 mit SQL Server 2025 unter
Docker und Podman erfolgreich ausgeführt. Beide Läufe endeten nach erfolgreicher
Installation, Aktualisierung, Validierung und Adapterbereinigung mit dem
scopegebundenen Entfernen ihrer Container- und Volume-Ressourcen.

## OPS-005 Linked Server

Der Runner `Invoke-Ops005LinkedServerScenario.ps1` erzeugt einen frischen,
wegwerfbaren Lab-Run, installiert das Framework und führt den bestehenden
Linked-Server-Runtime-Vertrag aus. Er verwendet keine vorhandenen Container und
entfernt den gesamten Run nach dem Test.

```powershell
pwsh -File ./TestLab/Invoke-Ops005LinkedServerScenario.ps1 -Provider docker -Version 2022
```

Der Adapter `OPS-005` führt den vorhandenen Linked-Server-Runtimevertrag auf
einem pro Zielversion neu erzeugten Docker-Lab aus. Er installiert den
kanonischen Frameworkbestand in die markergebundene Datenbank
`LabAnalyze`, verwendet ausschließlich die synthetischen Fixtures des
Runtimevertrags und entfernt danach zuerst die Adapterobjekte und anschließend
den exakten Lab-Run. Der Runner verwendet die vom Labkatalog freigegebene
Collation `Latin1_General_100_CS_AS`. Das zufällige SA-Passwort bleibt im
Arbeitsspeicher; weder Passwort, Containername, Port noch Run-State werden als
Repositoryevidenz gespeichert.

```powershell
pwsh -File ./TestLab/Test-AnalyzeOps005LinkedServerAdapter.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab

pwsh -File ./TestLab/Invoke-AnalyzeOps005LinkedServerMatrix.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die Matrix verarbeitet SQL Server 2019, 2022 und 2025 sequenziell. Sie bindet
keine bestehenden Container, Volumes oder Remoteziele ein. Ein fehlgeschlagener
Adapter- oder Infrastruktur-Cleanup behält ausschließlich den zugehörigen
temporären State für die Recovery; ein erfolgreicher Lauf entfernt auch diesen
State-Root.

Der zusätzliche Runner `Invoke-Ops005LinkedServerSuccessScenario.ps1` prüft
einen tatsächlichen Verbindungsaufbau zwischen zwei ausschließlich für diesen
Test neu erzeugten SQL-Server-2025-Containern unter Docker Desktop. Er richtet
einen synthetischen Linked Server mit `MSOLEDBSQL` und einem eigenen Remote-Login
ein. Der Test verlangt `NOT_EXECUTED` im Standardpfad,
`AUTHORIZATION_REQUIRED` ohne zweite Bestätigung und `SUCCEEDED` mit beiden
Schaltern. Die verschlüsselte Testverbindung vertraut dem Containerzertifikat.
Dieser Lauf erfordert die ausdrückliche Freigabe für Verbindungen zwischen den
neuen lokalen Testcontainern und gehört nicht zum synthetischen Standardadapter.

```powershell
pwsh -File ./TestLab/Invoke-Ops005LinkedServerSuccessScenario.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Der Runner hält erzeugte Passwörter ausschließlich im Arbeitsspeicher und
entfernt beide eigenen Lab-Runs samt Volumes. Bei einem Cleanupfehler bleiben
die temporären Recoverydaten erhalten; eine Warnung nennt den gezielten
Recoveryaufruf. Der Lauf vom 5. Oktober 2026 bestand auf SQL Server
`17.0.4075.5` einschließlich Cleanup. Er belegt ausschließlich diese
MSOLEDBSQL-Kombination und keinen weiteren Provider oder Remote-Workload.

## OPS-006 Datenbankportabilität

Der Runner `Invoke-Ops006DatabasePortabilityScenario.ps1` installiert den
Frameworkbestand in einem neuen, wegwerfbaren Docker-Lab und führt den
Framework-Smoke-Test sowie den Portabilitätsvertrag aus. Der Vertrag prüft
eine leere Datenbank, ein tatsächlich persistiertes `Compression`-Feature,
eine synthetische uncontained dependency, eine fehlende Datenbank und den
eingeschränkten Zugriff. Die Featureprüfung verlangt
`PERSISTED_SKU_FEATURE` im Analyzer-JSON.

```powershell
pwsh -File ./TestLab/Invoke-Ops006DatabasePortabilityScenario.ps1 `
  -Version 2025 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Der Standardlauf verwendet ausschließlich SQL Server 2025. Die optionalen
Versionen 2019 und 2022 werden nur bei einem konkreten Versionsrisiko oder
für den erforderlichen Release-Nachweis ausgewählt. Der aktuelle Labkatalog
gibt `Latin1_General_100_CS_AS` für die Instanz frei; die Framework- und
Fixture-Datenbanken verwenden `SQL_Latin1_General_CP1_CS_AS`. Ein erfolgreicher
Lauf belegt genau diese Kombination und keine vollständige Collationmatrix.
Das zufällige SA-Passwort bleibt im Arbeitsspeicher. Der Runner entfernt
abschließend ausschließlich den eigenen Lab-Run und dessen temporären State.
Bei fehlgeschlagener Provisionierung oder Bereinigung bleibt der State für
Recovery erhalten. Der Test erzeugt keinen Nachweis für eine auf dieser
Engine tatsächlich nicht verfügbare Systemquelle und keine allgemeine
Migrationsfreigabe.

## OPS-008 Kontrollierte Historien und Dateiwachstum

Der Runner `Invoke-Ops008MsdbHistoryScenario.ps1` erzeugt einen neuen
SQL-Server-2025-Docker-Container und verlangt fünf leere Historienquellen
vor Fixtureänderungen. Er führt Smoke-Test und bestehenden `msdb`-Vertrag
aus. Anschließend erzeugt er drei Backups einer eigenen synthetischen
Datenbank und setzt ausschließlich deren Historienzeitstempel auf
kontrollierte Werte. Der Analyzer muss die Zeilenanzahl sowie kurze und
lange Backupzeitfenster exakt ausgeben. Eine zusätzliche Dateierweiterung
von mindestens 8 MB prüft die aktuelle Größenangabe; die Fixture begrenzt
die betroffene Datendatei auf höchstens 128 MB.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Der Runner akzeptiert keinen bestehenden Run. Passwörter bleiben im
Arbeitsspeicher; die Bereinigung entfernt den eigenen Container samt
Volume, Backupdatei, Historienfixtures und temporärem State. Bei unvollständiger
Provisionierung oder fehlgeschlagenem Cleanup bleibt ausschließlich der
eigene Recovery-State erhalten. Der Test belegt
sichtbare Zeitfenster und Größenänderungen, keine Aufbewahrungsregel,
Wachstumsrate oder Restorefähigkeit. Die vier weiteren Historienquellen
werden zunächst als kontrollierte Leerfälle geprüft. Der zusätzliche
Restorevertrag stellt die eigene Backupdatei dreimal in eine zunächst
nicht vorhandene Fixture-Datenbank wieder her. Weitere Restores ersetzen
ausschließlich diese eigene Datenbank. Nur die zugehörigen Historienzeitstempel
werden angepasst; Anzahl und kurze beziehungsweise lange Restorezeitfenster
müssen exakt ausgegeben werden. Nicht leere Agent-, Mail- und Maintenance-
Historien sowie tatsächlich fehlende optionale Quellen bleiben separat offen.

## OPS-007 Zweite Session und verweigerter DMV-Zugriff

`Invoke-Ops007ForeignCursorScenario.ps1` erzeugt ein neues SQL-Server-2025-
Docker-Lab, installiert das Framework und führt Smoke-Test sowie Cursorvertrag
aus. Eine eigene zweite Verbindung hält einen statischen Cursor über 10.000
synthetische Zeilen offen. Der Analyzer muss diesen Cursor bei einer Begrenzung
auf eine Ergebniszeile als `RESOURCE_CONTEXT` ausgeben und dessen Öffnungs- und
Fetchzustand erhalten. Positive Ressourcenzähler belegen keine Hochlast.

```powershell
pwsh -File ./TestLab/Invoke-Ops007ForeignCursorScenario.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Eine ausschließlich eigene Login- und Benutzerfixture erhält Ausführungsrecht
auf den Analyzer. Gezielte Verweigerungen im `master`-Kontext müssen
`DENIED_PERMISSION`, einen Partialstatus, eine Berechtigungsfehlernummer und
leeres JSON ergeben. Erzeugte Passwörter bleiben im Arbeitsspeicher. Der Runner
akzeptiert keinen bestehenden Run und entfernt ausschließlich den eigenen
Container, dessen Volume und temporären State. Bei fehlgeschlagener
Provisionierung oder Bereinigung bleiben die eigenen Recoverydaten erhalten.

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
