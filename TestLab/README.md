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
müssen exakt ausgegeben werden. Die getrennten injizierten Agent-, Mail- und
Maintenance-Aggregate sowie der getrennte tatsächliche Agent-Joblauf sind
nachfolgend beschrieben. Mail-/Maintenance-Ausführung, Retention und fehlende
optionale Quellen bleiben separat offen.

Mit `-Scenario AgentHistory` wird ausschließlich der Agent-Aggregatvertrag
zusätzlich zu Installation, Smoke-Test und Runtimevertrag `122` geprüft.
Der Standard `HistoryRestore` behält die Backup-, Restore- und Größenfälle.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario AgentHistory `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die Agent-Fixture [TEST-0001](Scenarios/OPS-008/agent-history.sql) legt in einer
eigenen Transaktion einen deaktivierten Job an und injiziert nacheinander
eine, zwei und drei synthetische Job- und Stepzeilen in `sysjobhistory`.
Der Analyzer muss die vollständige Zeilenanzahl mit `AVAILABLE` und leeren
Zeitgrenzen liefern und alle Quellwerte erhalten. Die Fixture wird vollständig
zurückgerollt. Sie führt keinen Agent-Job aus und belegt keine Datums-, Dauer-
oder Retentionsinterpretation. Der Runner initialisiert für seinen
frischen State die testgebundene Ownership-Lane von `SQL_Server_Lab` und
serialisiert eigene Runtime-Tests über die gemeinsame Host-Testlane.

Die drei älteren Fenster- und Agent-Aggregatfixtures erfassen XACT_ABORT
vor einer Änderung und aktivieren es erst innerhalb des Try-Pfads. Erfolg
und Catch stellen den ursprünglichen Wert direkt im Callerbatch wieder her;
Catch wirft den ursprünglichen Fehler erneut. Die Fensterfixtures verlangen
vor ihren Änderungen einen Caller ohne offene Transaktion. Alle elf
NONE-Aufrufe prüfen den unveränderten ursprünglichen Locktimeout und
XACT_ABORT ON; der Agent behält seine committable eigene Transaktion.
Der Locktimeout wird von diesen drei Fixtures nicht gesetzt oder auf `-1`
eingeschränkt. Das Agentrollback entfernt eigene injizierte Quellen.
Die Fenster-Catchpfade erhalten Datenbanken, Dateien und Historien bis zum
äußeren identitygebundenen Labcleanup.

Eine getrennte private Gegenprobe bestand neun Fälle in fünf neuen eigenen
SQL-Server-2025-Labs mit `ProductVersion=17.0.4075.5` und Framework-CL 170.
Je Fixture erhielt eine frühe TX1-Ablehnung ursprüngliches XACT_ABORT OFF,
Locktimeout 31, die committable Callertransaktion und alle vorhandenen
Quellwerte. Je zwei injizierte Fehler mit ursprünglichem OFF oder ON
bestätigten auf derselben Verbindung Locktimeout 31, ursprüngliches
XACT_ABORT und null offene Transaktionen. Die Fensterfehler erhielten
vollständige Werte von acht Historienquellen, acht Datenbankkatalogfeldern
und exakte eigene Datenbankbindungen; das Agentrollback erhielt die
ursprünglichen sechs Agentquellen. Die Fehlerpunkte liegen ausschließlich
nach dem ersten Backup beziehungsweise Restore und nach der ersten
injizierten Agentzeile, jeweils vor dem folgenden Consumer.
Erfolgreicher Eintritt mit ursprünglichem ON, spätere Fehlerpunkte, NOCOUNT,
Datenbankkontext und allgemeines Temp-Tabellen-Cleanup bleiben unbelegt.

Mit `-Scenario MailMaintenance` prüft der Runner nach Installation, Smoke-Test
und Runtimevertrag `122` die [Mail-/Maintenance-Fixture](Scenarios/OPS-008/mail-maintenance.sql).
Sie verlangt leere Quellen und deaktivierte Database-Mail-XPs. Eine eigene
Transaktion injiziert nacheinander eine, zwei und drei synthetische Zeilen in
`sysmail_mailitems` und `sysmaintplan_log`. Der Empfängerwert ist ein generischer
Text ohne Mailadresse. Es werden keine Profile, Accounts, Queueeinträge,
Maintenance-Pläne oder Jobbindungen angelegt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailMaintenance `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die neun Analyzeraufrufe prüfen die kontrollierten Counts und MIN-/MAX-Werte
gegen feste Erwartungen und die nativen Quellen. TABLE und CONSOLE müssen alle
acht Fachfelder desselben JSON-Aufrufs erhalten. Die vollständigen Tabellenwerte
werden vor und nach jedem Aufruf NULL-sicher verglichen; Callertransaktion und
`LOCK_TIMEOUT` bleiben erhalten. Die injizierten Zeilen werden zurückgerollt;
der eigene Lab-Run wird anschließend entfernt. Der Runner erfasst zusätzlich
die tatsächliche `ProductVersion` und das Compatibility Level der
Frameworkdatenbank. Die Zeitfelder übernehmen native `send_request_date`- und
`start_time`-Werte ohne UTC-Konvertierung. Die Fixture belegt keine tatsächliche
Mail- oder Maintenance-Ausführung, keine Queueverarbeitung und keine Retention.
Die vorhandene Agent-Fixture und deren Referenz TEST-0001 bleiben unverändert.

Mit `-Scenario AgentExecution` prüft der Runner nach Installation, Smoke-Test
und Runtimevertrag `122` die [Agent-Ausführungsfixture](Scenarios/OPS-008/agent-execution.sql).
Sie verlangt eine leere Agent-Historie und erstellt einen eigenen lokalen Job
mit genau einem T-SQL-Schritt `SELECT 1`, ohne Zeitplan, Wiederholung oder
Benachrichtigung. Sie startet diesen Job über `sp_start_job` und wartet
höchstens 120 Polls mit jeweils einer Sekunde Abstand auf den erfolgreichen
Job- und Schrittabschluss sowie den beendeten nativen Aktivitätsrecord.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario AgentExecution `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Getrennte Job-, Schritt- und Historyidentitäten sowie genau zwei erfolgreiche
native Historyzeilen belegen die Ausführung. Nach einem zusätzlichen
Stabilitätsvergleich prüfen NONE, TABLE und CONSOLE den nativen Count und
die unveränderten NULL-Zeitgrenzen des Agent-Vertrags. TABLE und CONSOLE
besitzen vollständige Parität mit JSON. Vollständige Historienwerte,
Callertransaktion und `LOCK_TIMEOUT` bleiben bei jedem Analyzeraufruf erhalten.
Die Fixture entfernt ausschließlich den eigenen Job anhand seiner Job-ID
einschließlich seiner Historie; bei Fehlern versucht sie denselben Cleanup
nach einem begrenzten Stop-Wartepfad. Das äußere Labcleanup erfolgt unabhängig
vom Szenarioergebnis. Es werden keine Historyzeilen direkt injiziert.
Der Nachweis betrifft einen erfolgreichen minimalen lokalen Job auf
SQL Server 2025 mit Docker. Retention, Jobdatums- oder Dauerinterpretation,
Mail-/Maintenance-Ausführung und andere Provider bleiben separat offen.

Mit `-Scenario AgentRetention` prüft eine getrennte Fixture die gezielte
native Historienbereinigung eines eigenen Jobs nach zwei erfolgreichen
Ausführungen desselben `SELECT 1`-Schritts. Die Startfelder der vier nativen
Historyzeilen bestimmen eine Grenze zwischen beiden Ausführungen.
`sp_purge_jobhistory` erhält ausschließlich die eigene Job-ID und eine
explizite Datumsgrenze. Nach der ersten Bereinigung müssen beide älteren
Zeilen fehlen und sämtliche Werte der beiden jüngeren Zeilen erhalten sein.
Eine zweite gezielte Bereinigung entfernt die verbleibenden eigenen
Historyzeilen, während Job und Schritt bestehen bleiben.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario AgentRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Je Phase mit vier, zwei und null Historyzeilen prüfen NONE, TABLE und
CONSOLE den nativen Count, Status und die unveränderten NULL-Zeitgrenzen.
TABLE und CONSOLE müssen innerhalb desselben Aufrufs alle acht Fachfelder
mit JSON teilen. Sämtliche Quellwerte, Callertransaktion und `LOCK_TIMEOUT`
werden vor und nach jedem Analyzeraufruf verglichen. Die abschließende
Joblöschung und das äußere Labcleanup bleiben identitätsgebunden.
Der Analyzer führt keine Bereinigung aus. Diese Gegenprobe prüft einen
manuellen datumsgebundenen Eingriff; automatische Agent-Aufbewahrung,
Mail-/Maintenance-Retention und Dauerinterpretation bleiben separat offen.

Mit `-Scenario BackupRestoreRetention` erzeugt eine weitere getrennte Fixture
drei tatsächliche Backups einer eigenen leeren Datenbank in getrennten
Medien und stellt jedes Backup in dieselbe eigene Restore-Datenbank wieder
her. Nur die eigenen Backup- und Restorezeitstempel werden auf kontrollierte
Werte gesetzt. Alle acht von `sp_delete_backuphistory` betroffenen
Historientabellen müssen zu Beginn leer sein. Der Test verwendet ausschließlich
einen neuen Wegwerf-Run, weil diese native Prozedur einen globalen Datumsfilter
und keinen Datenbankfilter besitzt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario BackupRestoreRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Zwei explizite Datumsgrenzen müssen zuerst die zwei älteren Paare und danach
das verbleibende Paar entfernen. Sämtliche Werte der jüngeren Zeilen in den
acht Historientabellen werden nach dem ersten Eingriff NULL-sicher verglichen.
NONE, TABLE und CONSOLE prüfen je Phase native Counts und MIN-/MAX-Zeitwerte,
JSON-Parität, Quellerhaltung und Callerzustand. Datenbankidentitäten und
geprüfte Optionen müssen bis zur eigenen Datenbankbereinigung erhalten bleiben.
Das äußere Labcleanup entfernt zusätzlich die eigenen Backupdateien und den
Run. Der Analyzer führt keine Bereinigung aus. Automatische Aufbewahrung,
physische Backupaufbewahrung und die Retention weiterer Historien bleiben
eigenständige Nachweise.

Die Backup-/Restore-Fixture verlangt vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfasst XACT_ABORT vor einer Änderung.
XACT_ABORT wird im Try-Pfad vor der eigenen Datenbankerzeugung aktiviert.
Consumer prüfen eine committable eigene Transaktion mit Locktimeout 137
und XACT_ABORT ON. Nach jeder Consumerphase wird der Locktimeout direkt
auf `-1` gesetzt; XACT_ABORT bleibt bis zum eigenen Erfolgscleanup aktiviert.
Erfolg und Catch restaurieren beide ursprünglichen Optionen direkt im
Callerbatch. Der Erfolg prüft zusätzlich neun Consumeraufrufe; Catch wirft
den ursprünglichen Fehler nach eigenem Rollback und Optionswiederherstellung
erneut.

Backups, Restores und ihre Historien entstehen außerhalb der
Consumertransaktion. Der Catch entfernt diese Ressourcen nicht innerhalb
der SQL-Verbindung; das äußere identitygebundene Labcleanup ist dafür
verantwortlich. Der Optionsvertrag verspricht keine Wiederherstellung von
NOCOUNT oder Datenbankkontext und kein allgemeines Cleanup temporärer Tabellen.

Eine zusätzliche private Gegenprobe bestand auf SQL Server `17.0.4075.5`
mit Framework-Compatibility-Level 170 drei Fälle in zwei weiteren neuen Labs.
Zwei Fehler mit ursprünglichem XACT_ABORT OFF beziehungsweise ON nach drei
tatsächlichen Backup-/Restore-Paaren und vor dem ersten Consumer in Phase 1
bestätigten auf derselben offenen Verbindung die ursprünglichen Optionen,
Transaktionscount und zuvor erfassten Transaktionszustand null sowie beide
genau gebundenen eigenen Datenbanken. Vollständige Werte aller acht
Historienquellen und acht Datenbankkatalogfelder blieben gegenüber dem vor
der Consumertransaktion erfassten Snapshot erhalten. Eine frühe Locktimeout-
31-Ablehnung bei OFF bestätigte unveränderte Optionen, keine eigene Datenbank
und acht leere Quellen. Beide Labs wurden anschließend einzeln vollständig
entfernt. Spätere Backup-/Restore- oder Purgefehler und erfolgreiche Retention
mit ursprünglichem ON sind damit nicht belegt.

Mit `-Scenario MailRetention` prüft eine getrennte Fixture zwei eigene
Mailretentionsfälle in jeweils einer eigenen Transaktion. Der erste Fall
injiziert drei `failed`-Mailzeilen mit kontrollierten Zeitstempeln; der zweite
ergänzt drei ältere Statusgegenproben. Die Mailquellen müssen vor jedem Fall
leer sein. Konfigurierte und effektive Mail-XPs bleiben deaktiviert; die
Fixture richtet weder Profil noch Versand oder Queueverarbeitung ein.
Die Statusmarkierungen belegen keine tatsächliche Mailausführung.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Im ersten Fall müssen zwei Datumsgrenzen der nativen
`sysmail_delete_mailitems_sp` zuerst die beiden älteren Zeilen und danach
die jüngere Zeile entfernen. Sämtliche Spalten der jüngeren Zeile bleiben
nach dem ersten Eingriff NULL-sicher gleich. Der zweite Fall verwendet
explizit `@sent_before=NULL` und `@sent_status='failed'`. Nach dem
[nativen Parametervertrag](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sysmail-delete-mailitems-sp-transact-sql?view=sql-server-ver17)
entfällt damit die Datumsgrenze. Drei eigene `failed`-Zeilen aus 2000, 2025
und 2030 müssen verschwinden; je eine ältere `unsent`-, `sent`- und
`retrying`-Zeile aus 1999 muss mit sämtlichen ursprünglichen Werten erhalten
bleiben. Die Gesamtmenge fällt von sechs auf drei, die Failed-Menge von drei
auf null. Unabhängige Statuscounts und MIN-/MAX-Zeitwerte prüfen die Auswahl.

NONE, TABLE und CONSOLE prüfen in beiden Fällen native Counts und Zeitgrenzen,
JSON-Parität, Quellerhaltung und Callerzustand. Insgesamt bestehen 15
Consumeraufrufe und zwei getrennte Rollbacks. Die sieben Summaryfelder bleiben
erhalten; `InitialRows`, `RetainedRows` und `FinalRows` beschreiben weiterhin
den ersten datumsgebundenen Fall mit drei, einer und null Zeilen.
`ConsumerCalls` beträgt nun 15. Jedes Rollback entfernt die eigenen injizierten
Zeilen; das äußere Labcleanup bleibt erforderlich. Der Analyzer führt keine
Bereinigung aus.

Der normale Szenariolauf bestand in einem neuen eigenen SQL-Server-2025-
Lab mit `ProductVersion=17.0.4075.5` und Framework-CL 170; das eigene Lab
wurde vollständig entfernt. Zwei vorbereitete private Mutationen prüfen
ein endliches Datum beziehungsweise einen fehlenden Statusfilter im zweiten
Fall. Eine weitere private Probe soll den unveränderten Erfolg mit
ursprünglichem XACT_ABORT ON und die tatsächlich gelesenen Summaryfelder
prüfen. Diese drei Fälle sind wegen der belegten gemeinsamen Host-Testlane
noch nicht ausgeführt und liefern keinen Laufzeitnachweis.
Tatsächliche Mailausführung, automatische Aufbewahrung, weitere Filter-
und Retentiongrenzen bleiben eigenständige Nachweise.

Mit `-Scenario MaintenanceRetention` injiziert eine weitere getrennte Fixture
drei eigene Zeilen in `sysmaintplan_log` mit kontrollierten Start- und Endzeiten.
Logdetail-, Plan- und Subplanquellen müssen leer sein und bleiben leer.
Die gesetzte Erfolgsmarkierung belegt keine tatsächliche Maintenance-Ausführung.
Die Fixture prüft zuerst die native Parametersignatur von
`sp_maintplan_delete_log` und verwendet danach zwei explizite Datumsgrenzen
mit NULL als Plan- und Subplanfilter. Dieser Datumsfilter darf ausschließlich
auf die eigene zunächst leere Historie im neuen Wegwerf-Run wirken.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenanceRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die native Bereinigung muss drei, eine und null Historienzeilen erzeugen und
alle Spalten der jüngeren Zeile nach dem ersten Eingriff NULL-sicher erhalten.
NONE, TABLE und CONSOLE prüfen je Phase native Counts und Zeitgrenzen,
JSON-Parität, Quellerhaltung und Callerzustand. Das abschließende Rollback
entfernt die injizierte Fixture; das äußere Labcleanup bleibt erforderlich.
Der Analyzer bereinigt keine Historie. Tatsächliche Maintenance-/SSIS- und
Jobausführung, automatische Aufbewahrung, positive Detailhistorie und
planselektive Retention bleiben eigenständige Nachweise.

Mit `-Scenario MailStatusRetention` prüft eine getrennte Fixture die vier
injizierten Status `unsent`, `sent`, `failed` und `retrying`. Jeder Fall
verwendet drei eigene Zielzeilen und je eine ältere eigene Gegenprobe mit
einem der drei anderen Status. Zwei explizite Datums-/Statusfilter müssen
die Zielmenge von drei auf eine und null Zeilen reduzieren; die gesamte
Mailmenge besitzt dabei sechs, vier und drei Zeilen. Alle Spalten der
jüngeren Zielzeile nach dem ersten Purge und der drei Gegenproben nach
beiden Purges müssen NULL-sicher erhalten bleiben.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailStatusRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die native View prüft die Statusmengen; NONE, TABLE und CONSOLE bestätigen
je Phase native Mailaggregate, JSON-Parität, Quellerhaltung und Callerzustand.
Vier getrennte Callertransaktionen werden jeweils zurückgerollt. Die
Fixture verlangt leere Mail- und Anlagenquellen sowie deaktivierte Mail-XPs.
Die Statusmarkierungen belegen weder Versand noch Queue- oder Retryverhalten;
Mailprofil und SMTP-Verbindung werden nicht eingerichtet. Automatische
Aufbewahrung, Anlagen- und Logretention bleiben eigenständige Nachweise.

Mit `-Scenario MailExecutionFailure` erzeugt eine getrennte Fixture einen
eigenen nativen Queueauftrag mit synthetischen Adressen unter der reservierten
Domain `.invalid`. Sie verwendet ausschließlich das neue eigene Docker-Lab,
ein eigenes Mailprofil und ein anonymes SMTP-Konto für `localhost` auf Port 1.
Der native Kontocapture muss diese Bindung vor dem Queueauftrag bestätigen.
Mail-, Anlagen-, Log-, Profil- und Kontoquellen müssen vorher leer sein;
Mail-XPs müssen deaktiviert und Service Broker in `msdb` aktiviert sein.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailExecutionFailure `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Die Fixture aktiviert Mail-XPs vorübergehend und wartet höchstens 120
Einsekundenpolls auf einen nativ fehlgeschlagenen eigenen Mailitem und einen
zugehörigen Fehlerlogeintrag des externen Mailprozesses. Sie verwendet
ausschließlich nativ erzeugte Mailhistorie. Vor den drei Analyzeraufrufen werden Queue und
Mail-XPs deaktiviert. NONE, TABLE und CONSOLE prüfen native Aggregate,
JSON-Parität, Quellerhaltung und Callerzustand. Für das native Cleanup und
die Queueprüfung werden Mail-XPs erneut kurz aktiviert. Danach sind eigener
Mailitem, Profil und Konto entfernt; Queue- und Konfigurationseintrittswerte
werden wiederhergestellt. Native Logs und Ressourcen eines
fehlgeschlagenen Szenarios benötigen das äußere identitygebundene Labcleanup.
Der Nachweis betrifft einen lokalen Fehlerfall; erfolgreiche SMTP-Annahme,
Zustellung, ein bestimmter SMTP-Fehlergrund, Retryverhalten und automatische
Retention bleiben getrennte Nachweise.

Mit `-Scenario MailLogRetention` erzeugt eine weitere Fixture drei eigene
native lokale Mailfehler unter denselben Lab-, Konto- und Adressgrenzen.
Sie wählt pro Mail einen gebundenen Fehlerlogeintrag aus und verlangt mindestens
eine nativ erzeugte Informationszeile. Jeder der drei Aufträge wird getrennt
mit höchstens 120 Einsekundenpolls geprüft. Das begrenzt die Polls insgesamt
auf 360, jedoch nicht die gesamte Fixturelaufzeit. Historienzeilen werden nicht injiziert;
die Logdatumswerte der drei ausgewählten Fehler und einer Informationsgegenprobe werden
innerhalb einer Callertransaktion kontrolliert gesetzt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailLogRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Zwei native Logpurges mit explizitem Typ `error` und Datumsgrenzen müssen die
ausgewählte eigene Fehlerlogmenge von drei auf eine und null Zeilen reduzieren. Der
jüngere Fehlerlogeintrag bleibt beim ersten Purge mit sämtlichen Werten
erhalten. Die ältere Informationsgegenprobe und die zu Beginn erfassten
anderen Log-IDs bleiben mit sämtlichen Werten erhalten; später hinzukommende
Logs gehören nicht zu diesem eingefrorenen Vergleichsscope. Alle drei
Mailitems und ihre Werte bleiben während der Purges und neun Consumeraufrufe
unverändert. NONE, TABLE und CONSOLE prüfen native Mailaggregate, JSON-Parität
und Callerzustand bei deaktivierten Mail-XPs.

Das Callerrollback stellt die kontrollierten Logwerte und gelöschten eigenen
Fehlerlogs wieder her; anschließend entfernt die Fixture ihre Mailitems,
ihr Profil und Konto und stellt Queue- und Konfigurationswerte wieder her.
Native Logs benötigen das äußere identitygebundene Labcleanup. Kontrollierte
Logdatumswerte belegen kein authentisches Alter oder UTC-Verhalten. Andere
Ereignistypfilter, NULL- oder ungültige Filter, automatische Logretention,
erfolgreicher Versand, Anlagenretention und inneres Fehlercleanup bleiben
getrennte Nachweise.

Die beiden tatsächlichen Mailfixtures verlangen vor Quelländerungen den
ursprünglichen Standardlocktimeout `-1` und erfassen XACT_ABORT vor einer
Änderung. Im Try-Pfad wird XACT_ABORT vor der ersten Konfigurationsänderung
aktiviert. Consumer prüfen eine committable eigene Transaktion mit
Locktimeout 137 und XACT_ABORT ON. Erfolg und Catch restaurieren beide
ursprünglichen Optionen direkt im Callerbatch. Der Erfolg prüft zusätzlich
drei beziehungsweise neun Consumeraufrufe; Catch wirft den ursprünglichen
Fehler nach eigenem Rollback und Optionswiederherstellung erneut.

Mailitems, Profil und Konto entstehen außerhalb der Consumertransaktion.
Der SQL-Catch entfernt diese Ressourcen nicht und stellt Queue- oder
Konfigurationseintrittswerte nicht wieder her; das äußere identitygebundene
Labcleanup bleibt dafür erforderlich. Beide Szenarien verwenden getrennte
neue Labs, weil verbleibende native Logs der Ausführungs-Fixture die
Leerquellen-Vorprüfung der Retentions-Fixture verletzen würden. Der
Optionsvertrag umfasst weder NOCOUNT noch Datenbankkontext oder allgemeines
Cleanup temporärer Tabellen.

Eine getrennte private Gegenprobe bestätigt vier Fehlerfälle mit
ursprünglichem XACT_ABORT OFF oder ON vor dem ersten Consumer und zwei
frühe Locktimeout-31-Ablehnungen auf vier neuen Labs. Optionen, native
Mail-/Profil-/Konto-/Bindungswerte und bei Logretention die vier ausgewählten
Logwerte bleiben auf derselben Verbindung erhalten. Die Logfehlerprobe
betrifft ausschließlich Phase 1; spätere Purgephasen bleiben ungeprüft.
Das eigene äußere Cleanup entfernt die verbliebenen Ressourcen.

Mit `-Scenario MailAttachmentRetention` erzeugt eine getrennte Fixture drei
injizierte eigene Failed-Mailitems und je zwei synthetische Binäranlagen von
neun Bytes. Der native siebenfeldrige Anlagenviewvertrag wird vor dem Aufbau
geprüft. Es werden keine Betriebssystemdateien gelesen oder erzeugt; Mail-XPs
bleiben deaktiviert. Mailversand und Queueverarbeitung finden nicht statt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailAttachmentRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Zwei native Datums-/Failed-Statuspurges müssen drei, eine und null Mailzeilen
sowie sechs, zwei und null Anlagen hinterlassen. Zugeordnete Binärgrößen
betragen 54, 18 und null Bytes; verwaiste Anlagen dürfen nicht verbleiben.
Nach dem ersten Purge müssen sämtliche jüngeren Mail- und Anlagenwerte
NULL-sicher identisch bleiben. Neun NONE-, TABLE- und CONSOLE-Aufrufe prüfen
native Mailaggregate, Parität aller acht Fachfelder sowie unveränderte
Mail- und Anlagenquellen bei committable Callertransaktion und erhaltenem
Locktimeout. Das Rollback muss sämtliche injizierten Mailitems und Anlagen
entfernen; das äußere identitygebundene Labcleanup bleibt erforderlich.

Der Nachweis betrifft die native Bereinigung kontrollierter injizierter
Anlagen. Er belegt weder native Anlagenproduktion noch Versand, Dateizugriff,
Zustellung, authentisches Alter oder automatische Aufbewahrung. Weitere
Status-/Datumsfilterkombinationen und inneres Fehlercleanup bleiben getrennte
Nachweise. Der Analyzer erhält keinen neuen Anlagenquellenvertrag.

Mit `-Scenario MaintenanceDetailRetention` erzeugt eine getrennte Fixture
drei injizierte eigene Maintenance-Elternzeilen mit je zwei verknüpften
Detailzeilen. Vor dem Aufbau werden die 13 nativen Detailfelder und die
Fremdschlüsselbindung über `task_detail_id` geprüft. Sämtliche Inhalte sind
synthetisch; Plans und Subplans bleiben leer. Maintenance, SSIS und Jobs
werden nicht ausgeführt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenanceDetailRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Zwei native `sp_maintplan_delete_log`-Aufrufe mit Datumsgrenzen und
NULL-Planfiltern müssen drei, eine und null Elternzeilen sowie sechs, zwei
und null Details hinterlassen. Jüngere vollständige Eltern- und Detailwerte
müssen NULL-sicher erhalten bleiben; verwaiste Details dürfen nicht verbleiben.
Neun NONE-, TABLE- und CONSOLE-Aufrufe prüfen native Elternaggregate,
Parität aller acht Fachfelder sowie unveränderte Eltern- und Detailquellen
bei committable Callertransaktion und erhaltenem Locktimeout. Das Rollback
muss alle injizierten Eltern und Details entfernen; das äußere
identitygebundene Labcleanup bleibt erforderlich.

Eltern und Details verwenden übereinstimmende kontrollierte Zeiten. Der
Nachweis trennt deshalb keine unabhängige Detaildatumssemantik und belegt
weder selektive Planfilter noch authentisches Alter, automatische Aufbewahrung
oder tatsächliche Maintenance-Ausführung. Der Analyzer erhält keinen neuen
Detailquellenvertrag.

Mit `-Scenario MaintenancePlanRetention` erzeugt eine getrennte Fixture
fünf injizierte eigene Maintenance-Elternzeilen mit je zwei Details. Drei
Zeilen tragen denselben synthetischen Zielplan-GUID und kontrollierte Zeiten.
Zwei ältere Gegenproben tragen einen anderen Plan-GUID beziehungsweise NULL.
Plans und Subplans bleiben leer; sämtliche Subplan-IDs sind NULL. Die GUIDs
bezeichnen ausschließlich Historienwerte und keine ausgeführten Pläne.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenancePlanRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Ein nativer `sp_maintplan_delete_log`-Aufruf mit einem nicht passenden
Plan-GUID muss sämtliche Eltern- und Detailwerte erhalten. Zwei weitere
Aufrufe mit Zielplan-GUID und expliziten Datumsgrenzen müssen Zielcounts
drei, eins und null bei Gesamtcounts fünf, drei und zwei sowie Detailcounts
zehn, sechs und vier hinterlassen. Sämtliche jüngeren Zielwerte und sämtliche
älteren Gegenprobenwerte müssen NULL-sicher erhalten bleiben. Neun NONE-,
TABLE- und CONSOLE-Aufrufe prüfen native Elternaggregate, Parität aller acht
Fachfelder sowie unveränderte Eltern- und Detailquellen, Callertransaktion
und Locktimeout. Das Rollback muss alle injizierten Zeilen entfernen;
das äußere identitygebundene Labcleanup bleibt erforderlich.

Der Nachweis betrifft selektive Plan-ID-Filter bei NULL-Subplanfilter und
kontrollierter Historie. Er belegt weder Subplanfilter noch echte
Plandefinitionen, Maintenance-/SSIS-Ausführung, unabhängige Detaildatumssemantik,
authentisches Alter oder automatische Aufbewahrung. Weitere Kombinationen
bleiben getrennte Nachweise; die Calleroptionen- und Fehlerprüfung ist im
folgenden gemeinsamen Umfang beschrieben. Produkt-SQL und
der öffentliche Analyzervertrag bleiben unverändert.

Mit `-Scenario MaintenanceSubplanRetention` erzeugt eine getrennte Fixture
einen deaktivierten eigenen Job ohne Steps, Serverzuordnung oder
Benachrichtigungen innerhalb der Callertransaktion. Drei injizierte
Subplanmetadatensätze werden an diesen Job gebunden. Sechs eigene
Maintenance-Elternzeilen erhalten je zwei Details. Drei Elternzeilen tragen
denselben Zielsubplan-GUID und kontrollierte Zeiten. Drei ältere Gegenproben
tragen einen anderen Subplan desselben Plans, einen Subplan eines anderen
Plans beziehungsweise NULL für Plan und Subplan. Plans bleiben leer;
Maintenance, SSIS und Jobs werden nicht ausgeführt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenanceSubplanRetention `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Ein nativer `sp_maintplan_delete_log`-Aufruf mit nicht passendem Subplan-GUID
muss sämtliche Eltern- und Detailwerte erhalten. Zwei weitere Aufrufe mit
Zielsubplan-GUID, NULL-Planfilter und Datumsgrenzen müssen Zielcounts drei,
eins und null bei Gesamtcounts sechs, vier und drei sowie Detailcounts zwölf,
acht und sechs hinterlassen. Vollständige jüngere Zielwerte, ältere
Gegenprobenwerte, Subplanmetadaten und die gesamte Jobquelle müssen erhalten
bleiben. Neun NONE-, TABLE- und CONSOLE-Aufrufe prüfen native Elternaggregate,
Parität aller acht Fachfelder, unveränderte Quellen, Callertransaktion und
Locktimeout. Das Rollback muss alle injizierten Maintenancezeilen sowie den
eigenen Job entfernen; das äußere identitygebundene Labcleanup bleibt erforderlich.

Der Nachweis betrifft selektive Subplan-ID-Filter bei NULL-Planfilter und
kontrollierter Historie. Kombinierte Plan-/Subplanfilter, echte SSIS-Pläne,
Maintenance-Ausführung, unabhängige Detaildatumssemantik, authentisches Alter,
automatische Aufbewahrung bleiben getrennte Nachweise. Die Calleroptionen-
und Fehlerprüfung ist im folgenden gemeinsamen Umfang beschrieben. Produkt-SQL
und der öffentliche Analyzervertrag bleiben unverändert.

Mit `-Scenario MaintenanceFilterBoundary` prüft eine getrennte Fixture die
native Ablehnung gleichzeitiger Plan- und Subplanparameter. Sie verlangt beim
neuen eigenen Labcaller den Standardlocktimeout `-1` und stellt diesen nach
dem Rollback direkt im Callerbatch wieder her. Sie erzeugt
innerhalb einer Callertransaktion denselben kontrollierten Sechs-Eltern-/
Zwölf-Detail-Umfang mit drei injizierten Subplanmetadaten und einem
deaktivierten eigenen Job ohne Steps, Serverzuordnung oder Historie.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenanceFilterBoundary `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Je ein `sp_maintplan_delete_log`-Aufruf mit passenden beziehungsweise
widersprüchlichen Plan-/Subplan-IDs und Datumsgrenze muss den nativen Fehler
`2732` aus der Systemprozedur auslösen. Deren Ablehnungszweig fordert zwar
Meldung `12980` an; der Caller erhält auf der charakterisierten SQL-Server-2025-
Linux-Engine `2732`. Die Herkunft muss beim datenbankübergreifenden Aufruf
exakt `msdb.dbo.sp_maintplan_delete_log` entsprechen. Bei `XACT_ABORT OFF`
muss die kontrollierte Fehlerbehandlung sämtliche Eltern-, Detail-, Subplan-
und Jobwerte sowie die committable Callertransaktion und den Locktimeout
erhalten. Neun NONE-, TABLE- und CONSOLE-Aufrufe prüfen
native Aggregate aus sechs unveränderten Elternzeilen, zwölf Details und
Parität aller acht Fachfelder bei erhaltenem `XACT_ABORT OFF`. Ein zusätzlicher nativer
Aufruf bei `XACT_ABORT ON` muss denselben Fehler und den erwarteten
Callerzustand `XACT_STATE()=-1` bei weiterhin unveränderten Quellwerten
bestätigen. Danach muss das eigene Rollback alle injizierten Zeilen und den
eigenen Job entfernen und die ursprünglichen Locktimeout und die XACT_ABORT-Einstellung wiederherstellen; das äußere identitygebundene Labcleanup bleibt erforderlich.

Der Nachweis betrifft die Parameterablehnung auf der tatsächlich geprüften
nativen Engine. Die beiden Fehleraufrufe liefern keinen positiven kombinierten
Retentionfilter. Die drei erwarteten Fehler werden innerhalb der Fixture behandelt. Der
ON-Fall belegt eine uncommittable eigene Transaktion vor ihrem Rollback;
ein ungeplanter äußerer Fixturefehler wird dadurch nicht simuliert.
Echte Maintenance-/SSIS-Ausführung, automatische Aufbewahrung und zusätzliche
native Versionen bleiben getrennte Nachweise. Produkt-SQL und der öffentliche
Analyzervertrag bleiben unverändert.

Mit `-Scenario MaintenanceCallerOptions` führt der Runner die vier bestehenden
Maintenance-Retentionfixtures für Eltern, Details, Plan-ID und Subplan-ID
nacheinander in einem neuen eigenen Lab aus. Jede Fixture verlangt vor
Quelländerungen den ursprünglichen Standardlocktimeout `-1`. Ein abweichender
Wert wird vor Beginn der eigenen Transaktion und vor einer XACT_ABORT-Änderung
abgelehnt. Die Fixtures erfassen die ursprüngliche XACT_ABORT-Einstellung,
prüfen während ihrer neun Consumeraufrufe `XACT_ABORT ON`, `LOCK_TIMEOUT=137`
und eine committable eigene Transaktion und stellen beide Optionen nach dem
Rollback direkt im Callerbatch wieder her. Der Erfolgspfad prüft anschließend
neun Consumeraufrufe und die ursprünglichen beiden Werte. Der Catch-Pfad
rollt die eigene Transaktion zurück, restauriert die beiden Optionen und
wirft den ursprünglichen Fehler erneut.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MaintenanceCallerOptions `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Eine zusätzliche private Fehlerprobe auf SQL Server 2025 bestätigt je Fixture
zwei Abbrüche nach dem Quellaufbau vor der ersten Consumerphase mit
ursprünglichem XACT_ABORT OFF beziehungsweise ON. Sie prüft nach dem erneut
geworfenen Fehler auf derselben Verbindung die beiden ursprünglichen Optionen,
Transaktionscount und vor den Quellabfragen erfassten Transaktionszustand null
sowie acht leere Maintenance-/Jobquellen. Je eine weitere frühe Ablehnung mit
Locktimeout `31` erhält beide Optionen und leere Quellen. Der begrenzte
Zwölf-Fälle-Nachweis wurde auf SQL Server `17.0.4075.5` mit Framework-
Compatibility-Level 170 erbracht.
Die Probe liefert keine erfolgreiche Retention mit ursprünglich XACT_ABORT ON,
keine späteren Fehlerpunkte und keinen zusätzlichen nativen Engine-Nachweis.

Die Gruppe wiederholt ausschließlich die vier betroffenen Retentionsverträge
mit insgesamt 36 Consumeraufrufen. Sie erweitert keinen Diagnosevertrag und
keine allgemeine Lab-Provisionierung. Der Wiederherstellungsvertrag gilt für
Locktimeout und XACT_ABORT. Die Fixtures versprechen keine Wiederherstellung
von NOCOUNT oder Datenbankkontext und kein allgemeines Cleanup temporärer
Tabellen. Äußeres identitygebundenes Labcleanup bleibt erforderlich.

Mit `-Scenario MailCallerOptions` führt der Runner die vier bestehenden
injizierten Mailfixtures für gemischte Mail-/Maintenance-Aggregate,
Failed-Mailretention, Statusretention und Anlagenretention nacheinander in
einem neuen eigenen Lab aus. Die Gruppe umfasst nach Erweiterung der
Failed-Mailfixture insgesamt 69 Consumeraufrufe: neun je gemischter und
Anlagenfixture, 15 für beide Failed-Mailfälle sowie 36 für die vier
Mailstatus. Die ursprünglichen 63 Aufrufe sind als gemeinsamer Lauf belegt;
die sechs zusätzlichen NULL-Datumsaufrufe wurden im getrennten Szenario
`MailRetention` geprüft. Die vorhandenen Aggregate, Retentionsmengen, vollständigen
Quellwertvergleiche und NONE-/TABLE-/CONSOLE-Paritäten bleiben maßgeblich.
Mailversand und Queueverarbeitung werden durch diese Fixtures nicht ausgeführt.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario MailCallerOptions `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Jede Fixture verlangt vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfasst XACT_ABORT vor einer Änderung. Während
der Consumeraufrufe werden `XACT_ABORT ON`, `LOCK_TIMEOUT=137` und eine
committable eigene Transaktion geprüft. Nach dem eigenen Rollback stellen
Erfolg und Catch beide Optionen direkt im Callerbatch wieder her; Catch
wirft den ursprünglichen Fehler erneut. Der Erfolgspfad prüft zusätzlich
die erwartete Consumerzahl und die beiden ursprünglichen Werte. Die
Statusfixture verwendet vier getrennte Transaktionen und restauriert die
Optionen abschließend nach allen vier Statusfällen. Die Failed-Mailfixture
verwendet zwei getrennte Transaktionen und restauriert beide Optionen
abschließend nach beiden Retentionsfällen.

Eine zusätzliche private Gegenprobe bestand auf SQL Server `17.0.4075.5`
mit Framework-Compatibility-Level 170 zwölf Fälle. Je Fixture wurden zwei
Fehler mit ursprünglich XACT_ABORT OFF beziehungsweise ON nach geprüftem
Quellaufbau und vor dem ersten Consumer sowie eine frühe Ablehnung mit
Locktimeout `31` geprüft. Nach dem erneut geworfenen Fehler bestätigte
dieselbe offene Verbindung die ursprünglichen beiden Optionen,
Transaktionscount und vor Quellabfragen erfassten Transaktionszustand null,
sieben leere Mail-/Maintenancequellen und deaktivierte Mail-XPs.
Der gemischte Fehlerpunkt liegt nach dem ersten Aufbau mit je einer Mail-
und Maintenancezeile; der Statusfehlerpunkt betrifft ausschließlich den
ersten unsent-Fall. Die Gegenprobe belegt keine späteren Fehlerpunkte und
keine erfolgreiche Retention mit ursprünglich XACT_ABORT ON.

Der Wiederherstellungsvertrag betrifft Locktimeout und XACT_ABORT. Er
verspricht keine Wiederherstellung von NOCOUNT oder Datenbankkontext und
kein allgemeines Cleanup temporärer Tabellen. Das äußere identitygebundene
Labcleanup bleibt erforderlich.

Mit `-Scenario AgentCallerOptions` führt der Runner die beiden bestehenden
Fixtures für tatsächliche lokale Agent-Ausführung und native eigene
Agent-Historienretention nacheinander in einem neuen eigenen Lab aus.
Die Gruppe prüft zwölf Consumeraufrufe: drei nach einer tatsächlichen
Jobausführung und neun während der vier-, zwei- und nullzeiligen
Retentionsphasen nach zwei tatsächlichen Ausführungen. Die vollständigen
Historienvergleiche, NONE-/TABLE-/CONSOLE-Paritäten und das eigene Jobcleanup
bleiben maßgeblich. Die Fixtures injizieren keine Jobhistorie.

```powershell
pwsh -File ./TestLab/Invoke-Ops008MsdbHistoryScenario.ps1 `
  -Scenario AgentCallerOptions `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Beide Fixtures verlangen vor Quelländerungen den ursprünglichen
Standardlocktimeout `-1` und erfassen XACT_ABORT vor einer Änderung.
XACT_ABORT wird innerhalb des Try-Pfads vor der eigenen Joberzeugung aktiviert.
Die Consumer prüfen eine committable eigene Transaktion mit Locktimeout 137
und XACT_ABORT ON. Nach eigenem Rollback und Jobcleanup stellen Erfolg und
Catch beide Optionen direkt im Callerbatch wieder her; Catch wirft den
ursprünglichen Fehler erneut. Der Erfolg prüft zusätzlich drei beziehungsweise
neun Consumeraufrufe und beide ursprünglichen Optionen. Die Retentionfixture
setzt den Locktimeout nach jeder Consumerphase auf `-1`; XACT_ABORT bleibt
bis zum abschließenden Jobcleanup aktiviert.

Eine zusätzliche private Gegenprobe bestand auf SQL Server `17.0.4075.5`
mit Framework-Compatibility-Level 170 sechs Fälle. Je Fixture wurden zwei
Fehler mit ursprünglich XACT_ABORT OFF beziehungsweise ON nach tatsächlichem
Jobabschluss und vor dem ersten Consumer sowie eine frühe Locktimeout-31-
Ablehnung geprüft. Nach dem erneut geworfenen Fehler bestätigte dieselbe
offene Verbindung die ursprünglichen Optionen, Transaktionscount und vor
Quellabfragen erfassten Transaktionszustand null sowie sechs leere
Agentquellen. Der Retentionfehler betrifft ausschließlich Phase 1 mit vier
Historienzeilen. Laufende Jobs, Stop-/Pollfehler, spätere Fehlerpunkte und
erfolgreiche Retention mit ursprünglichem ON sind damit nicht belegt.

Der Wiederherstellungsvertrag betrifft Locktimeout und XACT_ABORT. Er
verspricht keine Wiederherstellung von NOCOUNT oder Datenbankkontext und
kein allgemeines Cleanup temporärer Tabellen. Das äußere identitygebundene
Labcleanup bleibt erforderlich.

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

## OPS-009 Systemdatenbankinventar

`Invoke-Ops009SystemInventoryScenario.ps1` installiert das Framework in einem
neuen SQL-Server-2025-Docker-Lab und führt Smoke-Test sowie Inventarvertrag
aus. Der Vertrag prüft eigene synthetische Objekte in `master`, `model` und
`msdb`, exakt eine begrenzte Ergebniszeile, den eingeschränkten Loginpfad und
das leere Inventar nach Fixturebereinigung.
Ein zusätzliches selektives Berechtigungsprofil zeigt genau die eigene
Masterfixture, keine Fixture aus `model` oder `msdb` und den verweigerten
Zugriff auf `model`. Die Vorprüfung erfasst auch
Namenskollisionen mit anderen Objektarten. Getrennte Erzeugungsmarker
schützen bereits vorhandene Login-, Benutzer- und Objektfixtures im Fehlerpfad.

```powershell
pwsh -File ./TestLab/Invoke-Ops009SystemInventoryScenario.ps1 `
  -LabRepositoryRoot ../SQL_Server_Lab
```

Der Runner akzeptiert keinen bestehenden Run. Passwörter bleiben im
Arbeitsspeicher. Er entfernt den eigenen Container samt Volume und temporärem
State; bei fehlgeschlagener Provisionierung oder Bereinigung bleiben eigene
Recoverydaten erhalten. Ein erfolgreicher Lauf belegt ausschließlich die
ausgeführte SQL-Server-2025-Kombination und die beschriebenen
Berechtigungsprofile.

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
