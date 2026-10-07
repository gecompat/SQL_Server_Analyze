# Laufzeitnachweise und historische Plattformmatrix

**Stand der historischen Kernmatrix:** 21. Juli 2026
**Kanonischer nachgewiesener Frameworkstand der Kernmatrix:** `1.1.0-special.13`
**Damals dokumentierter RUNTIME-001-Vertragsstand:** `1.1.0-special.14`
**Maschinenlesbare Detailmatrix:** `Metadata/Quality/Test_Matrix.csv`

**Einordnung:** Die maschinenlesbare Detailmatrix enthält historische,
commitbezogene Kernnachweise. Die ergänzende Übersicht beschreibt neuere
fokussierte Berichte mit deren eigener Nachweisgrenze. Sie aktualisiert keine
Matrixzeile und macht lokale Berichte nicht zu unabhängiger Release-Evidenz.
Die verbindliche aktive Policy steht in [Verbindliche CI-Teststrategie](CI_Test_Strategy.md)
und in `Metadata/Quality/CI_Test_Policy.csv`.

## Unterstützung und geprüfter Umfang

Die projektspezifisch garantierte Collation ist
`SQL_Latin1_General_CP1_CS_AS`. Die historische Kernmatrix weist Linuxläufe
auf SQL Server 2019, 2022 und 2025 nach. Neuere Tests mit abweichender Server-,
`tempdb`-, Quell- oder Snapshotdatenbank-Collation belegen ausschließlich die
angeführten Verfahren und Kombinationen. Sie sind keine allgemeine Freigabe
aller Collations oder eine automatische Aussage über den aktuellen PR-Head.

| Einordnung | Bedeutung für die Verwendung |
|---|---|
| Garantierte Collationgrenze | Der Projektvertrag nennt `SQL_Latin1_General_CP1_CS_AS`; die tatsächlich nachgewiesenen Releasekombinationen stehen in der historischen Matrix. |
| Fokussiert geprüft | Ein Bericht beschreibt einen begrenzten Testumfang, seine Umgebung und verbleibende Grenzen. Andere Procedures, Plattformen und Filterpfade sind daraus nicht ableitbar. |
| Nicht nachgewiesen | Windows-SQL, Azure MI, allgemeine Last- und Failoverfähigkeit sowie weitere Collationkombinationen bleiben ohne passenden individuellen Nachweis offen. |

## Neuere fokussierte Berichte

Die folgenden Einträge sind ein Einstieg in zusätzliche Nachweise. Die
Einzelabschnitte der zusammengefassten Berichte bleiben für Werte, Fehler und
Aussagegrenzen maßgeblich. Ein Berichtscommit bezeichnet die Dokumentrevision,
nicht automatisch den tatsächlich ausgeführten SQL-Quellstand. Wo kein
Laufcommit oder Build aufgezeichnet ist, bleibt dieser Bezug unbekannt.

| Bericht und Bezug | Engine, Plattform und Compatibility Level | Collations | Umfang, Ergebnis und Grenze |
|---|---|---|---|
| Neue fokussierte Probe am 7. Oktober; ausgeführter SQL-Quellcommit `531a7ecb2cc5`; Frameworkquelle `1.1.0-special.20`, Vertrag `1.24` | SQL Server 2025 `17.0.4075.5`, Linux, CL170; Edition nicht gesondert erhoben | Server/`tempdb` `Latin1_General_100_CS_AS`; eigene Frameworkziele `SQL_Latin1_General_CP1_CS_AS` und `Latin1_General_100_CI_AS_SC` | Lokal tatsächlich bestanden: Coreinstallation, Smoke und ObjectInventory-Identität in TABLE/JSON, TABLE-Textcollation sowie exakter Case-Filter in beiden Varianten. Keine unabhängige Release-Evidenz, kein frameworkweiter Collationnachweis. |
| COLL-B002, 20. September; Berichtscommit `85a9c692e4e0`; Laufcommit und Frameworkversion unbekannt | SQL Server 2019 Linux; ProductVersion und Compatibility Level unbekannt | Server/`tempdb` case-insensitiv, genaue Namen unbekannt; Framework `SQL_Latin1_General_CP1_CS_AS` | Berichteter bestandener ObjectInventory-JSON-Test mit eigenem synthetischem Objekt; kein vollständiger Katalog- oder Cross-Database-Nachweis. |
| COLL-B006, ursprünglicher TABLE-Lauf; Berichtsstand 19. September; Laufcommit und Frameworkversion unbekannt | SQL Server 2019 Linux; ProductVersion und Compatibility Level unbekannt | Server/`tempdb` `SQL_Latin1_General_CP1_CI_AS`; Framework `SQL_Latin1_General_CP1_CS_AS` | `LOCAL_WORKTREE_EVIDENCE`: Strukturadaption, Collationübernahme und typisierte Inserts bestanden; keine abweichend kollatierte permanente Zieldatenbank. |
| COLL-B006, Performance Counters am 5. Oktober; Laufcommit und Frameworkversion unbekannt | Majorversion 17, SQL Server 2025 Linux; ProductVersion und Compatibility Level nicht erhoben beziehungsweise unbekannt | Server/`tempdb` `Latin1_General_100_CS_AS`; Framework `SQL_Latin1_General_CP1_CS_AS` | Berichteter bestandener TABLE-/JSON- und nativer Countervergleich; keine Rate-, Fraction-, Reset- oder Hochlastabdeckung. |
| COLL-B006, Current Overview am 7. Oktober; Objektversion `4.1.0`; Laufcommit nicht eindeutig angegeben | SQL Server 2025 `17.0.4075.5`, Linux; CL170 | Server/`tempdb` `Latin1_General_100_CS_AS`; Framework `SQL_Latin1_General_CP1_CS_AS` | Lokaler Bericht zu 105 charakterisierten Original-/Abschlussfällen und Common192; positive Memory Grants und atomare Snapshot-Werte bleiben unbelegt. |
| COLL-B006, PlanCacheHealth am 7. Oktober; Berichtsrevision `3a6506e460aa`; Laufcommit unbekannt | SQL Server 2025 Linux, CL170; konkreter Build in diesem Abschnitt nicht genannt | Unterschiedliche Framework-/`tempdb`-Collation; genaue Namen in diesem Abschnitt nicht genannt | Berichtete native Ausgabe-/Mengenprüfung und gesondert gekennzeichnete synthetische Clonefälle bestanden; Cloneformeln sind kein atomarer DMV-Nachweis. |
| EXP-0001, Gesamtdeployment am 7. Oktober; Berichtsrevision `a1ba87efdfb4`; Laufquellen über Paketdigests dokumentiert | SQL Server 2025 `17.0.5005.3`, Enterprise Developer, Linux; Full Gate CL170 und gezielte Verträge CL150/160 | Server/`tempdb` und Snapshotziel `Latin1_General_100_CS_AS`; Framework `SQL_Latin1_General_CP1_CS_AS` | Lokaler, laut Bericht unabhängig geprüfter Deploymentumfang mit 58 Regressions- und 130 Core-Batches; keine ältere native Engine, Windows-SQL oder Produktionsvolumen. |

COLL-B006 enthält weitere modulbezogene Prüfungen. Deren Versions-,
Fixture-, Berechtigungs-, Quellen- und Lastgrenzen dürfen nicht durch die
hier ausgewählten Beispiele ersetzt werden. Die historischen CSV-Nachweise
und ihre bestehenden `EvidenceStatus`-Werte bleiben unverändert.

## Neue fokussierte ObjectInventory-Probe

Die neue Probe vom 7. Oktober prüfte zwei frisch angelegte synthetische
Frameworkdatenbanken auf derselben isolierten Linux-SQL2025-Engine.
Coreinstaller und [Smoke-Test](../../Code/Tests/Integration/110_Smoke_Test.sql)
bestanden jeweils. Anschließend wurde eine eigene Tabelle mit einem
case-sensitiven Namen erzeugt. Ein Aufruf von `USP_ObjectInventory` mit
`@MitIndizes=0`, `@MaxZeilen=5`, `@ResultSetArt='TABLE'`, einer lokalen
TABLE-Zuordnung und gleichzeitigem JSON-Output musste in beiden Ausgaben
genau die native Objektidentität und den Datenbank-/Schemanamen enthalten.
Die adaptierten TABLE-Textspalten mussten die explizite Frameworkcollation
verwenden. Ein zweiter Aufruf mit ausschließlich kleingeschriebenem
exaktem Objektnamen musste ohne Treffer enden. Alle Aussagen bestanden
in beiden Collationvarianten der Tabelle oben.

Der Coreinstaller wurde aus den kanonischen Dateien des genannten
SQL-Quellcommits erzeugt; sein SHA-256 war
`EB55CF56D398624582285ECDA55DC033AFFB57C567D3CA53789FC54679D3A13D`.
Die Framework- und Vertragsversion in der Tabelle bezeichnet die
Versionsquelle dieses Commits. Der eigene Container wurde nach dem
Lauf erfolgreich entfernt. Dieser lokale Nachweis erweitert weder die
historische Release-Matrix noch die allgemeine Collationgarantie.

## Abgrenzung zur aktiven CI

Eine historische Matrixzeile verpflichtet nicht dazu, dieselbe Kombination bei jeder Änderung erneut auszuführen. Automatische funktionale Tests folgen dem 1+0+N-Modell. Native SQL-Server-Versionen werden gezielt bei Versionsrisiko oder manuell für einen Release Candidate geprüft.

## Nachweisregel

Nur eine tatsächlich ausgeführte Kombination mit dokumentiertem Ergebnis ist ein Laufzeitnachweis. `NOT_EXECUTED` bedeutet ausdrücklich nicht getestet. `PASS_WITH_LIMITATIONS` bedeutet, dass der geprüfte Vertragsumfang bestanden ist, aber die in dieser Seite genannten Plattform- oder Featuregrenzen fortbestehen.

## Nachgewiesene Kernziele

| SQL Server | ProductVersion | Compatibility Level | Plattform | Ergebnis |
|---|---|---:|---|---|
| 2019 | `15.0.4480.2` | 150 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS` |
| 2022 | `16.0.4265.3` | 160 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS` |
| 2025 | `17.0.4065.4` | 170 | Linux, synthetisches Ziel | `PASS_WITH_LIMITATIONS`; zusätzlicher Regexvertrag bestanden |

Die Zielcollation dieser historischen Kernmatrix ist
`SQL_Latin1_General_CP1_CS_AS` für Server, `tempdb` und Installationsdatenbank.
Die neueren fokussierten Berichte erweitern keine allgemeine Collationfreigabe.

## Windows-Repository-Portabilität

Der isolierte Self-hosted-Windows-Lauf hat PowerShell-Parsing, Repository- und
ZIP-Datenschutz, die drei eigenständigen Installerverträge sowie die statischen
LAB-Verträge bestanden. Der commitbezogene maschinenlesbare Nachweis steht als Suite
`WINDOWS_REPOSITORY_PORTABILITY` in `Metadata/Quality/Release_Gate_Evidence.csv`.

Dieser Lauf prüft Windows-Dateipfade, CRLF-Verarbeitung, Toolauflösung und
Installererzeugung. Er führt keine Frameworkprocedure gegen eine native
Windows-SQL-Server-Instanz aus. Die Ziele `SQL2019-WINDOWS`,
`SQL2022-WINDOWS` und `SQL2025-WINDOWS` bleiben deshalb `NOT_EXECUTED`.

## Abgedeckte Vertragsbereiche

Die Kernziele prüfen:

- vollständige Installation und Objektbestand;
- Parameter-, Filter-, Listen-, Pattern- und Limitverträge;
- Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastruktur und Server Health;
- Capability-, Berechtigungs-, Leer-, Teil- und Fehlerstatus;
- RAW, CONSOLE, TABLE, NONE und JSON;
- typisierte TABLE-Schemas und lokale Zieltabellen;
- Unicode-, Textkürzungs-, XML- und JSON-Verträge;
- P0-/P1-/P2-Spezialfälle mit synthetischen, rücksetzbaren Zuständen;
- eigenständige Execution-Plan-Analyse und deren Teilinstaller;
- versionsabhängige Regexunterstützung auf SQL Server 2025.

Für den Analysis Navigator definiert das Release-Gate zusätzlich einen Metadaten- und Suchvertrag: Vollständigkeit aller öffentlichen Procedures, DE/EN-Begriffe, gültige Beziehungen, case-/accent-insensitive Suche, Paketstatus und RAW/CONSOLE/TABLE/JSON-Ausgabe. Eine Matrixzeile weist diesen Zusatzvertrag nur nach, wenn ihr `CommitSha` einen Frameworkstand mit dem Navigator bezeichnet; die oben aufgeführten Nachweise stammen aus dem vorherigen Frameworkstand.

## Feature- und Aussagegrenzen

| Bereich | Nachweisgrenze |
|---|---|
| Memory Pressure | kein künstlich erzwungener realer Speicherdruck oder Resource-Semaphore-Waiter; bedingte Interpretation aktueller Evidenz |
| interne Contention | kein erzwungener produktionsähnlicher PAGELATCH-Hotspot; opt-in- und Deltavertrag |
| Backup/Restore | synthetische Backupkette; kein externer Restore auf unabhängigem Host |
| Availability | HADR-Abwesenheit real; Queue-/Suspend-/Seedingklassifikation ohne operatives Failover oder Seeding |
| SQL Agent | Leer- und Klassifikationszustände ohne Änderung realer Jobs, Alerts, Operatoren oder Mail |
| In-Memory OLTP | kein erzwungener realer Speicherdruck; breiter Hashkettenpfad bleibt opt-in |
| Temporal | keine Prüfung realer History-Nutzzeilen oder Periodenüberlappungen |
| Service Broker | keine Nachrichtenkörper, Queue-Payloads oder Conversation-Mutationen |
| Full-Text | Linux kann Tests mit aktivierten Full-Text-Komponenten begrenzen; keine indizierten Inhalte |
| External Runtime | portabler Vertrag ohne Featureaktivierung oder Scriptausführung; keine R-, Python-, Java-, C#- oder Custom-Language-Läufe mit aktiviertem Feature und kein End-to-End-Launchpad-Nachweis |
| SQL CLR | portabler Vertrag ohne Assemblyerzeugung oder Ausführung; keine synthetische SAFE-Assembly und keine Windows-Fälle für `EXTERNAL_ACCESS` oder `UNSAFE` |
| Data Capture | lokale Metadaten und Klassifikation; keine Remote-Subscriber-/Distributor-Netzpfade |
| Verschlüsselung | keine Schlüssel- oder Medieninhalte und kein externer Restorebeweis |
| Wartung | keine operative Wartungsänderung |
| Last | keine allgemeine Produktionslast-, Skalierungs- oder Langzeitzusage |

## Nicht durch die Kernmatrix abgedeckt

- Windows-spezifische Feature-Positivpfade;
- konkrete External-Runtime-Installationen und eine tatsächlich ausgeführte synthetische External-Language-Workload;
- synthetische SQL-CLR-SAFE-Assembly sowie Windows-Securityfälle für höhere Permission Sets;
- Azure SQL Managed Instance;
- abweichende Server-/`tempdb`-Collations;
- reale Unternehmens-, Kunden- oder Produktionsdaten;
- vollständige Last-, Soak-, Chaos- oder Failovertests;
- jede mögliche Edition, Patchstufe, Topologie und Permissionkombination;
- externe Restore-, Schlüssel-, Netzwerk- oder Storage-Nachweise.

Diese Fälle dürfen nicht aus dem Kernnachweis abgeleitet werden. Vor Verwendung in einer abweichenden Zielkombination sind Installation, Smoke-Test, Capabilities und die benötigten Procedures kontrolliert zu prüfen.

## Berechtigungsprofile

Die Matrix trennt technische Profile ohne konkrete Principalnamen:

- Installationskontext mit DDL-Rechten;
- Laufzeitkontext mit den für die gewählte Quelle erforderlichen Server-/Datenbankrechten;
- absichtlich eingeschränkter Kontext für `PERMISSION_DENIED`, `AVAILABLE_LIMITED` und `DENIED_GROUP`;
- sysadmin nur für ausdrücklich notwendige technische Vergleichspfade.

Die interne Gruppenpolicy und SQL-Server-Rechte werden getrennt geprüft. Keine erfolgreiche Matrixzeile bedeutet, dass jeder Login automatisch alle Resultsets sehen kann.

## Priorisierte nächste Prüfungen

Neue Läufe folgen ausschließlich dem Risiko und dem Umfang der
[CI-Teststrategie](CI_Test_Strategy.md). Diese Übersicht fordert weder eine
zusätzliche native Engine bei jeder Änderung noch einen pauschalen
Volltest aller Collations. Bereits bestandene unveränderte Umfänge werden
nur bei neuer fachlicher Unsicherheit wiederholt.

### Nativer Windows-SQL-Teilumfang: nicht ausgeführter Testplan

Der Plan ist `NOT_EXECUTED`. Er prüft Installation, Smoke, native
OSInformation und den portablen External-Runtime-/CLR-Vertrag auf einer
eigenen isolierten SQL-Server-2025-Windows-Instanz mit CL170. Ein Host mit
PowerShell oder ein Linuxcontainer auf Windows erfüllt diese Voraussetzung
nicht. Die Instanz muss ausdrücklich als neue Testressource freigegeben sein;
ein vorhandener gemeinsam verwendeter SQL-Dienst wird nicht herangezogen.

Benötigt werden eine Repositorykopie am zu prüfenden Commit, PowerShell 7,
`sqlcmd`, integrierte Testauthentifizierung und Rechte für die Anlage einer
eigenen synthetischen Datenbank sowie für die verwendeten Quellen. Die Instanz
soll die garantierte Server-/`tempdb`-Collation verwenden. Den ausschließlich
lokalen Verbindungswert stellt der Ausführende über
`EXAMPLE_SQL_SERVER` bereit; Zugangsdaten und vollständige Ausgaben bleiben
außerhalb des Repositorys.

Die folgenden Befehle werden im Repositoryroot ausgeführt. Sie brechen bei
einem vorhandenen gleichnamigen Datenbankziel ab. Nur das von diesem Plan
tatsächlich erzeugte Ziel wird abschließend entfernt.

```powershell
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($env:EXAMPLE_SQL_SERVER)) {
    throw 'Eine freigegebene isolierte Windows-SQL-Testinstanz ist erforderlich.'
}
$planRoot = Join-Path ([IO.Path]::GetTempPath()) ('ExampleSqlValidation-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($planRoot) | Out-Null
$createdByPlan = $false
try {
    $setup = @'
IF DB_ID(N'DeineDatenbank') IS NOT NULL
    THROW 59910, 'Das synthetische Testziel existiert bereits.', 1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 59911, 'Der Plan verlangt eine native SQL2025-Engine.', 1;
IF NOT EXISTS(SELECT 1 FROM sys.dm_os_host_info WHERE host_platform=N'Windows')
    THROW 59912, 'Der Plan verlangt eine native Windows-Engine.', 1;
IF CONVERT(nvarchar(128),SERVERPROPERTY(N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
   OR (SELECT collation_name FROM sys.databases WHERE name=N'tempdb')<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 59913, 'Die garantierte Server- und tempdb-Collation ist erforderlich.', 1;
CREATE DATABASE [DeineDatenbank] COLLATE SQL_Latin1_General_CP1_CS_AS;
'@
    & sqlcmd -S $env:EXAMPLE_SQL_SERVER -E -C -b -l 30 -t 180 -Q $setup
    if ($LASTEXITCODE -ne 0) { throw 'Die Zielvorprüfung oder Datenbankanlage ist fehlgeschlagen.' }
    $createdByPlan = $true
    & sqlcmd -S $env:EXAMPLE_SQL_SERVER -E -C -b -l 30 -t 180 -Q 'ALTER DATABASE [DeineDatenbank] SET COMPATIBILITY_LEVEL=170;'
    if ($LASTEXITCODE -ne 0) { throw 'Das Compatibility Level konnte nicht gesetzt werden.' }
    & pwsh -NoLogo -NoProfile -File ./Code/Install/Build-StandaloneInstaller.ps1 -OutputPath (Join-Path $planRoot 'Core.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Der Installerbuild ist fehlgeschlagen.' }
    $inputs = @(
        (Join-Path $planRoot 'Core.sql'),
        './Code/Tests/Integration/110_Smoke_Test.sql',
        './Code/Tests/ServerHealth/133_OSInformation_Collation_Runtime_Contract.sql',
        './Code/Tests/Integration/198_Runtime001_External_Runtime_CLR_Runtime_Contract.sql'
    )
    for ($index = 0; $index -lt $inputs.Count; $index++) {
        $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $inputs[$index]).Path)
        $target = Join-Path $planRoot ('Step-' + $index + '.sql')
        [IO.File]::WriteAllText($target, $text.Replace('[DeineDatenbank]', '[DeineDatenbank]'), [Text.UTF8Encoding]::new($false))
        & sqlcmd -S $env:EXAMPLE_SQL_SERVER -E -C -b -l 30 -t 180 -i $target -o (Join-Path $planRoot ('Step-' + $index + '.log'))
        if ($LASTEXITCODE -ne 0) { throw ('Die SQL-Prüfung ist fehlgeschlagen: ' + $inputs[$index]) }
    }
    $metadata = @'
USE [DeineDatenbank];
SELECT SERVERPROPERTY(N'ProductVersion') AS ProductVersion,
       SERVERPROPERTY(N'Edition') AS Edition,
       SERVERPROPERTY(N'Collation') AS ServerCollation,
       (SELECT collation_name FROM sys.databases WHERE name=N'tempdb') AS TempDbCollation,
       DATABASEPROPERTYEX(DB_NAME(),N'Collation') AS FrameworkCollation,
       (SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()) AS CompatibilityLevel,
       (SELECT host_platform FROM sys.dm_os_host_info) AS Platform;
SELECT FrameworkVersion,ContractVersion FROM monitor.FrameworkVersion;
'@
    & sqlcmd -S $env:EXAMPLE_SQL_SERVER -E -C -b -Q $metadata -o (Join-Path $planRoot 'Metadata.log')
    if ($LASTEXITCODE -ne 0) { throw 'Die Umgebungsmetadaten konnten nicht erfasst werden.' }
    & git rev-parse HEAD | Set-Content -LiteralPath (Join-Path $planRoot 'Commit.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Der Commitbezug konnte nicht erfasst werden.' }
}
finally {
    if ($createdByPlan) {
        & sqlcmd -S $env:EXAMPLE_SQL_SERVER -E -C -b -l 30 -t 180 -Q 'ALTER DATABASE [DeineDatenbank] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [DeineDatenbank];'
        if ($LASTEXITCODE -ne 0) { throw 'Das eigene Testziel muss vor weiteren Läufen kontrolliert bereinigt werden.' }
    }
}
```

Bestanden ist ausschließlich der genannte Teilumfang, wenn jede SQL-Datei mit
Exitcode 0 endet, die jeweiligen Vertragsmeldungen vorliegen, Smoke keine
fehlenden Objekte meldet, die Metadaten die angeforderte Umgebung bestätigen
und die Entfernung des eigenen Testziels bestätigt ist. Für die Lieferung
sind nur Commit, Engine/Build/Edition, Plattform, Compatibility Level,
Collations, ausgewählte Dateien, Status und verbliebene Grenzen zu übernehmen.
Die privaten Logs sind vor jeder Weitergabe zu prüfen und nach der lokal
festgelegten Aufbewahrung zu entfernen. Bei Abbruch zwischen Datenbankanlage
und Cleanup bleibt der Status unbekannt; das exakt benannte eigene Ziel muss
in derselben isolierten Instanz geprüft werden.

Aktivierte External-Language-Workloads, SAFE-Assemblies, eingeschränkte Rollen,
Last, Failover und ein vollständiger Windows-Releaseumfang sind mit diesem
Plan nicht nachgewiesen. Native 2019-/2022-Läufe folgen nur aus konkretem
Versionsrisiko oder einem erforderlichen Release-Nachweis.

### Weitere Collationgrenzen

Priorität besitzen eine abweichende permanente Frameworkdatenbank, positive
Unicode-/Case-Filter und die tatsächlich benötigten TABLE-/JSON-Verträge.
Ein einzelner Test soll Server/`tempdb`, Framework- und Quelldatenbank-Collation
getrennt erfassen und Fachidentitäten gegen native Katalogwerte prüfen.
Tests, die ausdrücklich die garantierte Frameworkcollation voraussetzen,
dürfen nicht durch Entfernung ihrer Vorprüfung zu einem vermeintlichen
allgemeinen Collationnachweis umgedeutet werden. Verbleibende modulbezogene
Risiken betreffen weitere modulbezogene Filter-, Ausgabe- und Reifeverträge; die erfolgreichen Teilumfänge oben schließen diese Risiken nicht aus.

## Bewertungsstatus

| Status | Bedeutung |
|---|---|
| `PASS` | der definierte Ziel- und Vertragsumfang ist ohne bekannte Einschränkung bestanden |
| `PASS_WITH_LIMITATIONS` | der definierte Umfang ist bestanden; dokumentierte Feature-, Plattform- oder Evidenzgrenzen bleiben |
| `FAIL` | mindestens ein verbindlicher Vertrag ist nicht bestanden |
| `NOT_EXECUTED` | kein Laufzeitnachweis |

## Verwandte Dokumente

- [Verbindliche CI-Teststrategie](CI_Test_Strategy.md)
- [CI-Impact-Auswahl](CI_Impact_Selection.md)

- [Bekannte Einschränkungen](Known_Issues.md)
- [Performance- und Risikobewertung](Performance_and_Risk_Assessment.md)
- [Installation](../Reference/Installation.md)
- [Versionsadaptive Features](../Operations/Version_Adaptive_Features.md)
- [Execution-Plan-Analyse](../Architecture/Execution_Plan_Analysis_Design.md)
