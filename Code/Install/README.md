# Installation

Das versionierte Produkt-ZIP enthält bereits fünf Installer unter `generated`.
Für die Erstinstallation verwenden Sie `Install_All.generated.sql`;
für Migration und Vorzustandserhaltung `Deploy_All.generated.sql` nach der
[Deploymentanleitung](../../Documentation/Reference/Deployment.md). Die
Execution-Plan-Analyse und die beiden Snapshot-/Baseline-Kontexte bleiben
getrennte Installationswege. Ein lokaler Neubau ist bei Verwendung dieses
ZIP nicht erforderlich.

Für ein wiederholbares Gesamtdeployment einschließlich Migration und Vorzustandserhaltung erzeugt `Build-DeploymentInstaller.ps1` die Datei `generated/Deploy_All.generated.sql`. Mit `-IncludeSnapshotBaseline` werden beide expliziten Datenbankkontexte in denselben Lauf aufgenommen. Voraussetzungen, Datenbankwerte, Receipt und Fehlerbehandlung beschreibt die [Deploymentanleitung](../../Documentation/Reference/Deployment.md).

Für eine vollständige Schritt-für-Schritt-Installation in SSMS siehe
[`Documentation/Reference/Installation.md`](../../Documentation/Reference/Installation.md).

`Install_All.sql` ist ein schlanker SQLCMD-Installer und bindet die kanonischen Einzeldateien über `:r` ein.
Der vollständige SSMS-Ablauf einschließlich Arbeitskopie, Platzhalterersetzung,
Modusprüfung und Fehlerbehandlung ist in Abschnitt 12 der Installationsanleitung
beschrieben. `:ON ERROR EXIT` beendet den Include-Lauf beim ersten SQL-Fehler.

Ein eigenständiger, vollständig eingebetteter Installer wird mit folgendem Aufruf erzeugt:

```powershell
./Build-StandaloneInstaller.ps1
```

Die Quellen werden in exakt derselben, abhängigkeitssicheren Reihenfolge wie in
`Install_All.sql` eingebettet. Die erzeugte Datei `generated/Install_All.generated.sql` ist
ein Build-Artefakt und wird nicht versioniert. Für die SSMS-Erstinstallation ist
dies der empfohlene Weg: Der Datenbankplatzhalter muss nur einmal ersetzt werden,
und die generierte Datei benötigt keinen SQLCMD-Modus.

## Eigenständige Execution-Plan-Analyse

`Install_ExecutionPlanAnalysis.sql` installiert nur die für die direkte Plan- und Evidenzanalyse erforderlichen Objekte. Mit `Build-ExecutionPlanAnalysisInstaller.ps1` kann daraus das vollständig eingebettete SSMS-Artefakt `generated/Install_ExecutionPlanAnalysis.generated.sql` erzeugt werden. Der Teilinstaller installiert nicht die übrigen Analysebereiche und kann idempotent neben einer vollständigen Frameworkinstallation ausgeführt werden.

## Optionales Snapshot-/Baseline-Paket

SC-023 bleibt absichtlich außerhalb von `Install_All.sql`. Zuerst wird
`Install_SnapshotBaseline_Target.sql` im explizit gewählten Kontext einer
eigenen, beschreibbaren Nicht-Systemdatenbank ausgeführt. Danach installiert
`Install_SnapshotBaseline_Framework.sql` die Konfiguration und die drei Public
APIs in der Frameworkdatenbank. Das Paket erstellt keine Datenbank, Rechte oder
SQL-Agent-Objekte. Der vollständige Ablauf steht im
[Betriebsleitfaden](../../Documentation/Operations/Snapshot_Baseline_Operations.md).

Für eine Installation ohne SQLCMD-Modus erzeugt
`Build-SnapshotBaselineInstallers.ps1` zwei getrennte Artefakte:

- `generated/Install_SnapshotBaseline_Target.generated.sql` für die bereits
  ausdrücklich ausgewählte Snapshotdatenbank;
- `generated/Install_SnapshotBaseline_Framework.generated.sql` für die
  Frameworkdatenbank nach Anpassung von `[DeineDatenbank]`.

Die Trennung der Datenbankkontexte bleibt auch im Standalone-Weg erhalten.

## Releasepaket erzeugen

Maintainer erzeugen das Paket mit `Build-ReleasePackage.ps1`. Der Builder
exportiert ausschließlich den ausgewählten Git-Commit, führt die vorhandenen
vier Installerbuilder gegen diese Quellen aus und ergänzt `RELEASE.json`.
Versionierte Dokumentations- und Steuerungsunterlagen bleiben unter ihren
bisherigen Pfaden enthalten, damit Verweise auflösbar bleiben. Lokale,
unversionierte Dateien und Git-Verwaltungsdaten werden nicht übernommen.

```powershell
./Code/Install/Build-ReleasePackage.ps1 -RepositoryRoot . -Revision HEAD `
    -OutputDirectory 'C:/Temp/SQL_Server_Analyze_Release' -PythonExecutable python
```

Der Aufruf erfordert Git, PowerShell 7 und Python 3.10 oder neuer. Er verbindet
sich nicht mit SQL Server. Vorhandene gleichnamige Ausgabedateien werden
abgelehnt. Die ZIP-Prüfung vergleicht alle Quellen mit dem ausgewählten Commit
und die fertigen Installer bytegenau mit einer erneuten kanonischen Erzeugung
im festen Format UTF-8 ohne BOM mit LF-Zeilenenden. Die
[Releaseübersicht](../../Documentation/Quality/Release_Notes.md#release-110)
beschreibt Paket, Nachweis und Veröffentlichungsstatus.
