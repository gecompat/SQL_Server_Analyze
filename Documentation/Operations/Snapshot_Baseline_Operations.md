# Betrieb des optionalen Snapshot-/Baseline-Pakets SC-023

Stand: 2026-10-25
Status: `IMPLEMENTED_ACTIONS_GATE`

## Paketgrenze

SC-023 ist absichtlich kein Bestandteil von `Install_All.sql`. Ohne die beiden separaten Installer bleibt der Frameworkkern zustandslos. Der Defaultcollector bleibt `monitor.USP_PerformanceCounters` mit `@SampleSeconds=0`. `@CollectorCode='WAIT_STATS'` aktiviert ausdrücklich den öffentlichen Waitpfad; seine neue Targetpolicy bleibt zunächst deaktiviert. Ein internes Datei-I/O-Target ist vorbereitet; ein öffentlicher nativer Datei-I/O-Collector sowie Datenbank-, Query-, Plan-, Rollup-, Export- und Agentjob-Pakete gehören nicht zu diesem Stand.

Die Snapshot-Datenbank darf im autorisierten Betrieb reale Laufzeitwerte speichern. Exporte, Berichte und weitergegebene Auszüge benötigen einen eigenen Datenschutz-, Empfänger- und Aufbewahrungsvertrag.

## Installation

Der folgende Ablauf ergänzt das Paket erstmals. Für eine vorhandene
Installation gilt stattdessen das
[Upgrade aus der ZIP](#upgrade-einer-bestehenden-installation-aus-der-zip).
Das Produkt-ZIP enthält die beiden Snapshot-Installer bereits; ein Neubau ist
für diesen Weg nicht erforderlich.

1. Den Frameworkkern gemäß
   [Installationsanleitung](../Reference/Installation.md) erstmals installieren
   oder gemäß [Upgradeanleitung](../Reference/Installation.md#upgrade-aus-der-produkt-zip)
   auf den gewünschten Release-Stand bringen.
2. Für die erstmalige Paketeinrichtung eine eigene Ziel-Datenbank ausdrücklich
   anlegen. Bei einem Upgrade wird die vorhandene Snapshotdatenbank
   weiterverwendet. Beispielname ausschließlich für Dokumentation:

```sql
USE [master];
GO
CREATE DATABASE [ExampleSnapshotDatabase]
COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
ALTER DATABASE [ExampleSnapshotDatabase] SET RECOVERY SIMPLE;
ALTER DATABASE [ExampleSnapshotDatabase] SET READ_COMMITTED_SNAPSHOT ON;
GO
```

3. Im entpackten Produkt-ZIP die beiden Dateien unter `Code/Install/generated`
   verwenden. PowerShell, Python und SQLCMD-Modus werden dafür nicht benötigt.
4. `Install_SnapshotBaseline_Target.generated.sql` in SSMS öffnen. Im
   Datenbankfeld dieses Fensters ausdrücklich die vorgesehene Snapshotdatenbank
   auswählen und die gesamte Datei ausführen. Der Target-Installer enthält
   keine eigene `USE`-Auswahl. Er bricht in Systemdatenbanken sowie einer
   offline oder read-only Datenbank ab; eine versehentlich gewählte andere
   Benutzerdatenbank darf deshalb nicht als Ziel stehenbleiben.
5. Nach fehlerfreiem Targetlauf
   `Install_SnapshotBaseline_Framework.generated.sql` öffnen. In der
   enthaltenen `USE [DeineDatenbank];`-Zeile die Frameworkdatenbank einsetzen
   und die gesamte Datei ausführen. Der lokale Frameworkdatenbankname gehört
   nicht in den Target-Installer.
6. Bei einer Erstinstallation erst nach beiden erfolgreichen Installern das
   Ziel explizit konfigurieren. Der folgende Beispielaufruf setzt die
   genannten Policywerte; bei einem Upgrade mit unverändertem Ziel wird er
   nicht erneut ausgeführt:

```sql
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName = N'ExampleSnapshotDatabase',
     @IsEnabled = 1,
     @SchedulerType = 'EXTERNAL',
     @CollectionIntervalSeconds = 30,
     @MaxRows = 1000,
     @PayloadEnabled = 0,
     @RawRetentionDays = 14,
     @PayloadRetentionDays = 7,
     @RollupRetentionDays = 180,
     @SoftBudgetMB = 10240,
     @PurgeIntervalMinutes = 60,
     @PurgeBatchRows = 10000,
     @StatusCodeOut = @Status OUTPUT,
     @IsPartialOut = @Partial OUTPUT,
     @ErrorNumberOut = @Error OUTPUT,
     @ErrorMessageOut = @Message OUTPUT;
```

Beide Installer sind idempotent. Frameworkdefaults werden nur angelegt, wenn sie fehlen; lokale Nicht-Default-Policies und vorhandene Historie bleiben erhalten.

### Upgrade einer bestehenden Installation aus der ZIP

Die [zentrale Upgradeanleitung](../Reference/Installation.md#upgrade-mit-bestehendem-snapshot-baseline-paket)
beschreibt `Deploy_All_WithSnapshotBaseline.generated.sql`, die explizite
Auswahl beider Datenbanken, die Unterbrechung von Collection und Purge sowie
die Abschlusskontrollen. Der kombinierte Installer liegt ab v1.1.1 fertig
in der ZIP vor. Er besitzt eine gemeinsame Transaktion, Receipts und
Vorzustandserhaltung in beiden Kontexten. Vorhandene Datenbanken und Zielbindung werden
weiterverwendet. Die bereits veröffentlichte v1.1.2-ZIP enthält
Target-Paketversion `1.0.0` mit `SchemaVersion=1`. Der aktuelle Quellstand
installiert das Target `1.3.1` mit `SchemaVersion=3`; die Targetversion ist von der
Frameworkversion getrennt. Der
[Architekturvertrag](../Architecture/Snapshot_Baseline_Package_Contract.md#installation)
beschreibt die erkannten Upgradezustände und Installationsrechte. Bestehende
ZIP-Dateien werden durch einen neueren Quellstand nicht nachträglich geändert.

Der Gesamtdeploymentweg prüft unterstützte Strukturformen und Customkonflikte
vor Produktänderungen. Die Snapshot-Einzelinstaller bleiben für getrennte
Installationskontexte verfügbar, besitzen aber keinen allgemeinen
Strukturmigrations- oder gemeinsamen Transaktions-, Receipt- oder
Vorzustandsvertrag mit einem separat ausgeführten Kern. Ein Framework-Receipt
allein bestätigt keinen vollständigen kombinierten Snapshotabschluss; dieselbe
Run-ID mit den passenden Rollen muss in beiden Datenbanken vorhanden sein.

Beim getrennten Upgrade wird zuerst das aktualisierte Framework installiert.
Es unterstützt vollständige alte Waittargets 1.2.1 / Schema 2 mit
Retentionsvertrag 1, Targets 1.3.0 / Schema 3 mit Retentionsvertrag 2 und
Targets 1.3.1 / Schema 3 mit Retentionsvertrag 3.
Das Stadium 1.2.2 ist unvollständig und nimmt keine neue Sammlung an.
Die FILE_IO-Policy bleibt nach Installation deaktiviert. Die öffentliche native
Aufnahme verlangt ausdrücklich Target 1.3.1 / Schema 3 und ihre Aktivierung.

### Installation aus einem Quellcheckout

Bei einer vollständigen Repositorykopie stehen weiterhin die beiden
`Code/Install/Install_SnapshotBaseline_*.sql` im SQLCMD-Modus zur Verfügung.
Alternativ erzeugt `Code/Install/Build-SnapshotBaselineInstallers.ps1` die
beiden eingebetteten Dateien unter `Code/Install/generated`. Nur dieser
Neubau benötigt PowerShell. Der
[Deploymentleitfaden](../Reference/Deployment.md) trennt die fertigen
ZIP-Artefakte vom kombinierten Neubau aus einem Quellcheckout.

## Rechte

Das Paket erstellt keine Logins, Benutzer, Rollenmitgliedschaften oder `GRANT`-Anweisungen. Die Betriebsstelle muss getrennt entscheiden und vergeben:

- `EXECUTE` auf den drei Public APIs im Framework;
- Quellrecht für Performance Counters: typischerweise SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE`;
- Zugriff auf die Frameworkdatenbank und explizite Schreib-/EXECUTE-Rechte in der Snapshot-Datenbank;
- bei SQL Agent die notwendigen Jobbesitz- und Verbindungsrechte außerhalb dieses Pakets.

Es gibt kein `EXECUTE AS OWNER`, kein `TRUSTWORTHY`-Erfordernis und keine Abhängigkeit von Cross-Database Ownership Chaining. Fehlende Rechte werden als `DENIED_PERMISSION` oder partieller Lauf gespeichert, nicht automatisch erweitert.

## Schedulerneutraler Aufruf

MANUAL, EXTERNAL und SQL_AGENT sind ausschließlich Herkunftsmetadaten. Alle verwenden denselben fachlichen Einstieg:

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType = 'EXTERNAL',
     @RunEvenIfNotDue = 0,
     @ResultSetArt = 'CONSOLE';
```

Ein Agentjob oder externer Scheduler ruft nur diese Procedure auf; Sammellogik gehört nicht in den Job. Eine benannte Session-Applock mit Wartezeit null verhindert parallele Cycles und Purges. `SKIPPED_CONCURRENT` und `SKIPPED_NOT_DUE` lesen keine Quell-DMV.

## Persistenz- und Resetvertrag

- `CaptureRun` und `ModuleStatus` bewahren Laufstatus, Partialität und Fehlergrenze.
- `Scope`, `MetricDefinition` und `MetricSample` bilden typisierte Raw- und abgeleitete Werte ab.
- Performance Counter verwenden ihren bestehenden `SqlServerStartTimeUtc`-/Epochenvertrag. Waits erhalten den nativen lokalen Engine-Start und die Startticks im Kontext; ihr `SqlServerStartTimeUtc` bleibt NULL. Ein gleicher Enginekontext beweist keine durchgehende Resetkontinuität.
- `PayloadSnapshot` wird nur mit `@PayloadEnabled=1` geschrieben. Der JSON-Vertrag bleibt verlustfrei, wird GZIP-komprimiert und per SHA-256 gebunden.
- Fehlende Evidenz erzeugt kein Sample mit erfundenem Nullwert.

## Öffentlicher Waitpfad

Nach Installation des Targets `1.3.1` wird zunächst die gemeinsame Zielbeziehung
konfiguriert. Anschließend aktiviert `USP_ConfigureSnapshotTarget` mit
`@CollectorCode='WAIT_STATS'`, `@CollectorEnabled=1` und
`@UpdateSharedPolicy=0` nur die Waitpolicy. Der Default für gemeinsame Änderungen
ist bei Waits `0`, bei Performance Countern `1`. Ein ausdrücklich gewähltes `1`
aktualisiert beide Datenbanken atomar; neue Optionen benötigen einen Caller
außerhalb eigener oder impliziter Transaktionen.

Der Waitlauf hält denselben Sessionlock wie Performance Counter und Purge.
Enabled und Due werden vor allen mutierenden Schritten geprüft. Danach folgen
Purge, Größenprüfung und ein vollständiger Read von `sys.dm_os_wait_stats`.
`MaxRows` begrenzt ausschließlich die anschließende Schreibauswahl. Der
Enginekontext wird vorher und nachher gelesen; es gibt keinen regulären
Cache-Reset. Fehlende Quellrechte erzeugen einen finalisierten Fehlerlauf ohne
erfundene Samples oder Epoche. Monotone Differenzkandidaten bleiben ausdrücklich
unbewiesen, der Gesamtstatus eines erfolgreichen Waitcaptures ist `PARTIAL`.

Die Waitquelle und `sys.dm_os_sys_info` benötigen auf SQL Server 2019
`VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE`.
Die Installer erteilen diese Rechte nicht. `CONSOLE`, `RAW`, `TABLE` und `NONE`
sind zulässig; JSON wird optional über `@JsonErzeugen=1` ausgegeben. Die
[Procedure-Seite](../Analysis_Guides/Procedures/USP_RunSnapshotCollectionCycle.md)
erläutert frühe OUTPUT-Fehler und Ausgabefehler nach bestätigter Speicherung.

## Retention und Budget

Die letzte finalisierte WAIT_STATS-Laufzeile ist als Vorbereitung des späteren
Wait-Vergleichs von der Runlöschung ausgenommen, bis ein neuerer Wait-Lauf
finalisiert ist. Dies erhält höchstens eine zusätzliche Laufzeile einschließlich
eines möglichen Fehlerstatus. Ihre Rohsamples, Payloads und Modulstatus
verfallen regulär; ihre bloße Existenz beweist deshalb keine vollständige
Vergleichsbasis. Die Performance-Counter-Retention bleibt unverändert. Die neue WAIT_STATS-Policy ist bei Neuanlage deaktiviert und wird über die ausdrückliche Collectorwahl aktiviert.

```sql
EXEC [monitor].[USP_PurgeSnapshotData]
     @MaxBatches = 10,
     @Force = 0,
     @ResultSetArt = 'CONSOLE';
```

Der Purge arbeitet child-first und begrenzt jede Löschschleife durch `PurgeBatchRows` sowie den Aufruf durch `@MaxBatches`. `PURGE_EXPIRED_THEN_STOP` ist im ersten Slice der einzige Budgetmodus. Bleibt das Budget nach dem Entfernen abgelaufener Evidenz überschritten, endet der nächste Collector als `STOPPED_SIZE_BUDGET`; frische Daten werden nicht gelöscht.

`UsedDataMbBefore`/`After` basieren im ersten Slice konservativ auf der allokierten ROWS-Dateigröße. Ein Delete verkleinert deshalb weder automatisch Dateien noch diesen Wert. Das Paket führt kein Shrink aus.

## Deaktivierung und Deinstallation

`@IsEnabled=0` verhindert neue Cycles, bewahrt aber Zielkonfiguration und Historie. Reinstallation löscht nichts. Es existiert bewusst kein automatischer Drop- oder Uninstallpfad. Das Entfernen der Snapshot-Datenbank ist ein eigener ausdrücklicher, extern autorisierter Betriebsakt mit Backup-, Retention- und Recoveryentscheidung.

## Abnahmegrenze

Der ursprüngliche Performance-Counter-Paketvertrag besitzt Nachweise für Installertrennung, Idempotenz, Collection, Reset-Epoche, Payloadverlustfreiheit, Retention, Größenstopp und Zwei-Session-Concurrency auf SQL Server 2019, 2022 und 2025. Die öffentliche Waiterweiterung erhält ihre eigene SQL2025-Abnahme und gezielte native SQL2019-Snapshot-Risikoqualifizierung; daraus folgt kein neuer separater SQL2022-Lauf. Historische Nachweise und Plattformgrenzen stehen in der [Testmatrix](../Quality/Test_Matrix.md).

## Datei-I/O ausdrücklich aktivieren

Das Framework wird beim getrennten Upgrade zuerst aktualisiert. Nach bestehender
gemeinsamer Zielkonfiguration aktiviert dieser Aufruf ausschließlich die
Datei-I/O-Policy im vollständigen Target 1.3.1 / Schema 3:

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName = N'ExampleSnapshotDatabase',
     @CollectorCode = 'FILE_IO',
     @CollectorEnabled = 1,
     @UpdateSharedPolicy = 0,
     @MaxRows = 1000;

EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @CollectorCode = 'FILE_IO',
     @DatabaseNames = N'[ExampleDatabase]',
     @SchedulerType = 'MANUAL',
     @ResultSetArt = 'CONSOLE';
```

Die Datenbankauswahl entspricht CurrentIO: Namen sind eine bracketfähige
Pipe-Liste; alternativ gilt @DatabaseNamePattern. Standardmäßig werden sichtbare
Online-Benutzerdatenbanken ausgewählt. @SystemdatenbankenEinbeziehen=1 nimmt
Systemdatenbanken ausdrücklich hinzu. Die drei Filter gelten ausschließlich
für FILE_IO. Der vollständige native Read erfolgt vor Zuordnung der ausgewählten
Datenbanken und vor dem Schreiblimit. Ein kleines MaxRows reduziert deshalb
keine native Enumeration und keine erforderlichen Katalogbeobachtungen.

SQL Server 2019 benötigt VIEW SERVER STATE, SQL Server 2022 und neuer benötigen
VIEW SERVER PERFORMANCE STATE. Hinzu kommen die tatsächlich erforderlichen
Datenbank-, Metadaten- und Targetrechte. Das Produkt vergibt keine Rechte.
Die [Microsoft-Referenz zur nativen Datei-I/O-Quelle](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17)
beschreibt diese versionsabhängige Berechtigung.

Prüfen Sie zuerst Status und Ende des Laufs, dann Source-Issues und Vergleichsstatus.
Erfolgreiche Datei-I/O-Aufnahmen bleiben PARTIAL; Kandidaten beweisen keine
Resetkontinuität. FINALIZATION_UNCONFIRMED mit bekannter Capture-ID bedeutet,
dass kein Abschluss bestätigt wird. Eine offene Vorgänger-ID bleibt eine
Vergleichsunterbrechung und wird von Retentionsvertrag 3 als neueste Datei-I/O-Grenze
erhalten. Bei zusätzlichem Ausgabefehler bleibt der Runbericht leer; ein lokaler
ModuleStatusId=NULL bezeichnet eine nicht bestätigte Persistenz. Die
[Vertragsbeschreibung](../Architecture/Snapshot_Baseline_Package_Contract.md#öffentliche-datei-io-aufnahme)
erläutert diese Fehlergrenzen.
