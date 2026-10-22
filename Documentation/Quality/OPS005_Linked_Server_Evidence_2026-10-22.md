# Historische Linked-Server-Nachweise bis 22. Oktober 2026

Diese datierte Abschrift erhält den bisherigen OPS-005-Abschnitt aus
`TestLab/README.md` am Repositorystand `0d40d4c1`. Sie dokumentiert damalige
Anleitungen, Fehlversuche, Korrekturen und die abschließende begrenzte Abnahme.
Zwischenstände wie `NOT_EXECUTED` oder „unqualifiziert“ behalten ihren
chronologischen Bezug. Die Abschrift aktualisiert keine Laufzeitmatrix,
erneuert kein verbrauchtes Budget und erteilt keine neue Ausführungsfreigabe.

Die aktuelle [Bedienanleitung](../../TestLab/README.md#ops-005-linked-server)
erklärt Fallauswahl, Voraussetzungen, Ergebnisinterpretation und Cleanup.
Die folgenden früheren Aufrufe sind historische Inhalte und keine zusätzliche
Testauswahl. Die [CI-Teststrategie](CI_Test_Strategy.md) bleibt für den
erforderlichen Umfang maßgeblich. Private Rohberichte und Laufidentitäten
werden hier nicht veröffentlicht; Aussagen reichen nur bis zum jeweils
benannten damaligen Testumfang.

<!-- OPS005_HISTORICAL_EXCERPT_BEGIN -->
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

Der separate manuelle Windows-Providerfall verwendet
`Prepare-Ops005UnavailableProvider.ps1` und
`Invoke-Ops005UnavailableProviderScenario.ps1`. Der Vorbereiter erzeugt private
SQL-Eingaben aus den kanonischen Quellen und führt kein SQL aus. Der Runner
benötigt eine ausdrückliche Ausführung, einen sauberen gebundenen Quellstand,
einen erhöhten Prozess desselben Hostbenutzers, ein vorhandenes SQL-2025-
Prepared-Image und einen bestehenden internen Switch. Der eigene Run erhält
vier vCPUs und acht GiB festen RAM. Der vorbereitete Aktivierungsintent
`NotRequested` mit `Denied`-Egress entspricht dem lokalen SQL-Workload:
Die Providerprüfung fordert keine Windows-Aktivierung an und attestiert
keinen aktiven Windows-Lizenzzustand. Die Zulassung verlangt weiterhin ein
gültiges vorhandenes Prepared-Image gemäß Lab-Inventar.
Es werden keine Images gebaut oder heruntergeladen und keine externen
Netzverbindungen eingerichtet.

Die Abnahme bindet Provideranlage, Katalogidentität, fünf Analyzer-Aufrufe und
eine native Provider-Vorprobe an dieselbe Operation. Native Fehler 7302 oder
7403 müssen mit dem Analyzeroutput übereinstimmen. Eine Reservierungsdatei
sperrt die erneute Runanlage; ein verlorener Reply erzeugt keinen Replay.
SQL-Fixture, eigene markierte Datenbank, Run, aktive IPAM-Lease und unveränderter
Parent werden getrennt geprüft. Der Fall gehört zum vorhandenen OPS-005-Umfang;
er erweitert weder Vertrag 120 noch dessen Linux-Adapter. Seine native
Providerabnahme war zunächst `NOT_EXECUTED`. Der erste Windows-Run scheitert
vor SQL Setup mit dem zuvor gewählten `VerifyOnly`-Intent am tatsächlichen
Gaststatus `ACTIVATION_REQUIRED`. Sein eigener Ressourcencleanup und die
unveränderte Parentintegrität sind bestätigt. Der vorbereitete korrigierte
Intent ist zusätzlich unabhängig geprüft. Der danach freigegebene Zusatzrun
erreicht SQL CompleteImage und scheitert anschließend mit
`HYPERV_SQL_COLLATION_QUERY_FAILED`: Die Lab-Gastprobe übergibt einen von der
Transportsignatur nicht unterstützten `StateRoot`-Parameter. Auch dieser eigene
Run ist bereinigt; die Providerabnahme bleibt `NOT_EXECUTED`.

Nach Integration der gesondert geprüften Lab-Korrektur besteht der erneut
freigegebene Windows-Run die tatsächliche Collationprüfung für Server,
`master` und `tempdb`. Die reservierte Gastadresse bleibt im Netzplan und
Verbindungsziel erhalten. Der erste Consumerbatch bricht jedoch mit
SQL-Fehler 206 ab: Der als `nvarchar(max)` gebundene externe Operationswert
wird direkt an den `sql_variant`-Parameter von `sp_addextendedproperty`
übergeben. Der korrigierte Vorbereiter verwendet dafür eine lokale
`nvarchar(36)`-Variable. Der unabhängige Review verlangt außerdem dieselbe
SQL-GUID-Kanonisierung im Cleanupvergleich. Der entsprechend ergänzte Stand
besteht zweiundzwanzig Offlineprüfungen; seine native Nachprüfung steht aus.
Der eigene fehlgeschlagene Run ist bereinigt, das Parent-Image unverändert.
Der Abschlussreview besteht. Der danach freigegebene Run bestätigt die
Markerkorrektur auf SQL Server `17.0.1000.7` mit CL170, scheitert jedoch im
ersten Installationsteil nach zehn Batches mit SQL-Fehler 113. Der
Windows-Transport trennt eine GO-Zeile innerhalb eines Blockkommentars und
erzeugt dadurch einen nicht geschlossenen Kommentar. Datenbank, eigener Run
und aktive Lease sind entfernt; das Parent-Image ist unverändert. Eine
vorbereitete Korrektur entschärft ausschließlich die bekannte Kommentarzeile
in privaten Installationseingaben. Quellhash und genau ein erwarteter Treffer
schützen vor einer ungeprüften Übernahme veränderter Quellen. Unabhängiger
Review und native Nachabnahme dieses neuen Standes sind anschließend
gesondert freigegeben und ausgeführt. Die Installation besteht mit allen
194 Batches; der Providerbatch scheitert danach mit Guardfehler 54890.
Der genaue Guard bleibt unbekannt, weil der Transport den Fehlerstate nicht
zurückgibt. Ein statischer Implementierungsfehler ist nicht belegt.
Eigene Datenbank, VM, Child-Disk und aktive Lease sind entfernt; das
Parent-Image ist unverändert. Ein weiterer Diagnose- oder Abnahmerun benötigt
eine neue begrenzte Freigabe. Die Providerabnahme bleibt unqualifiziert.

Der anschließend freigegebene Modus `-DiagnosePrerequisites` verwendet einen
eigenen Run mit derselben Installation und demselben Cleanup. Er führt die
sieben unverändert übernommenen Guards innerhalb `TRY/CATCH` aus und erfasst
deren Fehlernummer und State in einer begrenzten Zeile. Nur bei 54890 mit
State 1 bis 7 folgt eine zweite lesende Abfrage der zugehörigen Werte.
Provideranlage, Analyzer und Provider-Vorprobe werden in diesem Modus nicht
ausgeführt. `DIAGNOSIS_CAPTURED` erfordert auch den vollständigen Cleanup;
ein nicht reproduzierter Fehler bleibt `DIAGNOSIS_INCONCLUSIVE` und beendet
den Worker ohne Qualifikation. Der reguläre Providerpfad bleibt unverändert.
Der Modus benötigt eine eigene ausdrückliche Freigabe für die begrenzten
nativen Leseaufrufe.

Die nachfolgende Diagnose erfasst Guardstate 5: Das Modul existiert, aber das
erwartete Deklarationsliteral fehlt im gespeicherten Text. Die gezielte
Korrektur normalisiert zusätzlich ausschließlich `CREATE   PROCEDURE` für
das exakt benannte Modul. Der ursprüngliche vollständige Definitionshash
und die 13-Parameter-ABI bleiben zwingend. Die abschließende Windows-Abnahme
vom 22. Oktober 2026 besteht auf SQL Server `17.0.1000.7` mit CL170 und den
vorgeschriebenen Collations: 194 Installationsbatches, fünf Analyzerfälle,
eine Provider-Vorprobe mit nativem Fehler 7403 sowie sämtliche Output- und
Callerzustandsprüfungen bestehen. Fixture, eigene Datenbank, VM, Child-Disk
und aktive Lease sind entfernt; das Parent-Image ist unverändert. Der
Workerbericht meldet `PASSED`. Andere Provider- oder Berechtigungsprofile
werden damit nicht qualifiziert.

<!-- OPS005_HISTORICAL_EXCERPT_END -->

<!-- artifact_uid: urn:uuid:01a162c7-a0ea-74d8-abca-91962a0cfdbc; registration_state: DEFERRED -->
