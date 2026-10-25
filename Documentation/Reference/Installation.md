# Installation in SQL Server Management Studio (SSMS)

Diese Anleitung beschreibt die Erstinstallation und das Upgrade aus der
Produkt-ZIP v1.1.2 einschließlich des optionalen Snapshot-/Baseline-Pakets. Die ZIP
enthält sechs vorbereitete Installer unter `Code/Install/generated`. Für diese
Wege werden weder ein lokaler Build noch PowerShell, Python oder der
SQLCMD-Modus benötigt. Bei einer Repositorykopie gelten die gesonderten
Build- beziehungsweise SQLCMD-Abschnitte.

| Ausgangslage | Ablauf |
|---|---|
| Noch keine Frameworkinstallation | Schritte 1 bis 10 mit `Install_All.generated.sql`; danach bei Bedarf das [Snapshot-/Baseline-Paket ergänzen](#optional-persistentes-snapshot-baseline-paket-sc-023). |
| Bestehender Frameworkkern | [Upgrade aus der Produkt-ZIP](#upgrade-aus-der-produkt-zip) mit `Deploy_All.generated.sql`. |
| Bestehender Kern und bestehendes Snapshot-/Baseline-Paket | [Kombiniertes Upgrade](#upgrade-mit-bestehendem-snapshot-baseline-paket) mit `Deploy_All_WithSnapshotBaseline.generated.sql` in einer gemeinsamen Transaktion. |

Der mitgelieferte `Deploy_All.generated.sql` enthält nur den Kern. Das Setzen
von `@SnapshotDatabase` erweitert diesen Installer nicht; der Wert muss dort
`NULL` bleiben. Der zusätzliche `Deploy_All_WithSnapshotBaseline.generated.sql`
enthält beide Kontexte bereits. Der [Deploymentleitfaden](Deployment.md)
erläutert den Receipt- und Vorzustandsvertrag. Die Snapshot-Einzelinstaller
besitzen diesen gemeinsamen Vertrag nicht. In der älteren v1.1.0-ZIP fehlt
der kombinierte Installer; für den hier beschriebenen Weg v1.1.2 verwenden.

## 1. Voraussetzungen prüfen

Benötigt werden:

- SQL Server 2019 oder neuer;
- SQL Server Management Studio (SSMS);
- eine entpackte Kopie des Produkt-ZIP oder dieses Repositorys;
- PowerShell nur für einen lokalen Neubau des Installers; das Produkt-ZIP
  benötigt für die normale Erstinstallation keinen Build;
- für die einmalige Installation ausreichende DDL-Rechte in der Installationsdatenbank. Für die Erstinstallation ist die Datenbankrolle `db_owner` der einfachste verlässliche Weg;
- Für die garantierte Kombination verwenden Server, `tempdb` und
  Installationsdatenbank `SQL_Latin1_General_CP1_CS_AS`. Abweichende
  Kombinationen benötigen eine Prüfung der verwendeten Pfade; fokussierte
  Nachweise stehen in der [Testmatrix](../Quality/Test_Matrix.md).

Das Framework vergibt keine Benutzer-, Datenbank- oder Serverberechtigungen und ändert keine Serverkonfiguration.

## 2. Repository herunterladen

1. Im Bereich [Releases](https://github.com/gecompat/SQL_Server_Analyze/releases)
   die Produktdatei `SQL_Server_Analyze-1.1.2.zip` und deren `.sha256`-Datei
   herunterladen. Die zusätzlichen automatisch erzeugten Quellarchive
   enthalten keine vorbereiteten Installer.
2. Vor dem Entpacken die SHA-256-Prüfsumme des ZIP mit dem Wert aus der
   `.sha256`-Datei vergleichen. Beispielsweise liefert
   `Get-FileHash -Algorithm SHA256 -LiteralPath ./SQL_Server_Analyze-1.1.2.zip`
   den lokalen Wert. Bei einer Abweichung das Paket nicht ausführen und erneut
   von der Release-Seite beziehen.
3. Die ZIP-Datei vollständig entpacken, beispielsweise nach `C:\Tools\SQL_Server_Analyze`.
4. Die Verzeichnisstruktur unverändert lassen. Der Build und der alternative SQLCMD-Installer verwenden relative Pfade.
5. Lesen Sie vor der Verwendung die Datei `LICENSE.md`.

Alternativ kann das Repository geklont oder über **Code > Download ZIP**
bezogen werden. In diesem Fall ist Schritt 5 zur Erzeugung des Installers
erforderlich. `RELEASE.json` im Produktpaket nennt Frameworkversion, Commit
und Objektumfang. Die Release-Seite ordnet diesem unveränderten ZIP den
Abnahmenachweis zu. Die dort genannten Testbuilds sind keine Voraussetzung
für die Installation auf anderen Builds derselben unterstützten Hauptversion.

## 3. Zielinstanz und Collation kontrollieren

1. Starten Sie SSMS.
2. Mit der SQL-Server-Instanz verbinden, auf der das Framework installiert werden soll.
3. **Neue Abfrage** öffnen und folgende Vorprüfung ausführen:

```sql
SELECT
      TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) AS [ProductMajorVersion]
    , CONVERT(sysname, SERVERPROPERTY(N'ProductVersion'))     AS [ProductVersion]
    , CONVERT(sysname, SERVERPROPERTY(N'Edition'))            AS [Edition]
    , CONVERT(sysname, SERVERPROPERTY(N'Collation'))          AS [ServerCollation]
    , (SELECT [collation_name]
       FROM [master].[sys].[databases] WITH (NOLOCK)
       WHERE [name] = N'tempdb')                              AS [TempDbCollation];
```

`ProductMajorVersion` muss mindestens `15` sein. Eine passende Majorversion
allein belegt keine geprüfte Plattform-, Feature- oder Collationkombination.
Die [Nachweisübersicht](../Quality/Test_Matrix.md) trennt garantierte Grenzen,
historische Kernnachweise und neuere fokussierte Prüfungen.

Die Collation-Prüfung ist informativ: Der Installer gibt bei abweichender
Server-, `tempdb`- oder Installationsdatenbank-Collation eine **Warnung** aus,
blockiert die Installation jedoch nicht.

### Collation-Architektur

Das Framework verwendet explizite
`COLLATE SQL_Latin1_General_CP1_CS_AS`-Angaben für Vergleiche,
Gruppierung und lokale Textspalten. Die explizite Frameworkcollation
soll Vergleiche, Filter und lokale Materialisierung von abweichenden Quell- und
`tempdb`-Collations entkoppeln. Diese Architekturabsicht ist keine
uneingeschränkte Konfliktfreiheit aller Pfade. Neuere fokussierte Laufzeitberichte
beschreiben sowohl behobene Grenzen als auch den tatsächlich geprüften Umfang.

**Einschränkung:** Garantiert wird ausschließlich
`SQL_Latin1_General_CP1_CS_AS`. Zusätzliche Tests mit abweichenden Server-,
`tempdb`- und Quelldatenbank-Collations erweitern diese Garantie nicht.
Prüfen Sie bei einer abweichenden Zielkombination kontrolliert Installation,
Smoke-Test und die benötigten Procedures einschließlich ihrer Filter- und
Exportpfade. Stellen Sie eine bestehende Servercollation nicht allein
aufgrund dieser Anleitung um.

## 4. Installationsdatenbank anlegen oder prüfen

Das Framework legt die Datenbank nicht selbst an. `[DeineDatenbank]` ist im
gesamten folgenden Ablauf durch den lokal gewählten Datenbanknamen zu ersetzen.

### Neue Datenbank

```sql
USE [master];
GO

CREATE DATABASE [DeineDatenbank]
COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
```

### Vorhandene Datenbank

```sql
SELECT
      [name]
    , [state_desc]
    , [user_access_desc]
    , [is_read_only]
    , [collation_name]
FROM [master].[sys].[databases] WITH (NOLOCK)
WHERE [name] = N'DeineDatenbank';
```

Erwartet werden `ONLINE`, `MULTI_USER`, `is_read_only = 0` und die Collation `SQL_Latin1_General_CP1_CS_AS`.

## 5. Eigenständigen Installer erzeugen

Bei Verwendung des Produkt-ZIP liegt
`Code/Install/generated/Install_All.generated.sql` bereits vor. Fahren Sie
direkt mit Schritt 6 fort. Die folgenden Schritte gelten für Repositorykopien
und bewusst gewählte lokale Neubauten.

Dieser Schritt benötigt keine SQL-Server-Verbindung und verändert den Server nicht.

1. Öffnen Sie PowerShell.
2. In das Installationsverzeichnis der entpackten Repositorykopie wechseln:

```powershell
Set-Location 'C:\Tools\SQL_Server_Analyze\Code\Install'
```

3. Den Build ausführen:

```powershell
.\Build-StandaloneInstaller.ps1
```

4. Die Erfolgsmeldung kontrollieren. Im Unterverzeichnis `generated` muss nun die Datei `Install_All.generated.sql` liegen.

Das Buildskript übernimmt die kanonischen SQL-Dateien in ihrer abhängigkeitssicheren Reihenfolge. `generated/Install_All.generated.sql` ist ein lokales Build-Artefakt und wird nicht in Git versioniert. Falls die lokale PowerShell-Richtlinie das Skript blockiert, dürfen Sie die Richtlinie nicht unkontrolliert umgehen. Klären Sie die Ausführung stattdessen mit der zuständigen Administration oder verwenden Sie den alternativen SQLCMD-Weg.

## 6. Installer in SSMS vorbereiten

1. Wählen Sie in SSMS **Datei > Öffnen > Datei**.
2. Öffnen Sie `Code\Install\generated\Install_All.generated.sql`.
3. Nur die erste Zeile anpassen:

```sql
USE [DeineDatenbank];
```

4. Kontrollieren, dass das Abfragefenster mit der richtigen Serverinstanz verbunden ist.
5. Die gesamte Datei ausführen, nicht nur einen markierten Ausschnitt.

Der generierte Installer enthält keine `:r`-Anweisungen. Für ihn muss der SQLCMD-Modus in SSMS daher nicht aktiviert werden.

## 7. Installation ausführen

1. Im Installerfenster **Ausführen** wählen oder `F5` drücken.
2. Warten Sie bis zum Ende und kontrollieren Sie insbesondere die Registerkarte **Meldungen**.
3. Gehen Sie bei einem Fehler nicht von einer vollständigen Installation aus. Beheben Sie die Ursache und führen Sie anschließend den gesamten Installer erneut aus.

Die Frameworkobjekte liegen danach in der gewählten Datenbank im Schema
`[monitor]`. Der Erstinstaller verwendet `CREATE OR ALTER` und idempotente
DDL-/DML-Logik, besitzt aber keinen gemeinsamen Receipt- und Vorzustandsvertrag.
Für eine bestehende Installation gilt deshalb der
[Upgradeweg](#upgrade-aus-der-produkt-zip).

## 8. Version und Kernobjekte prüfen

Ein neues Abfragefenster öffnen und ausführen:

```sql
USE [DeineDatenbank];
GO

SELECT
      [FrameworkName]
    , [FrameworkVersion]
FROM [monitor].[FrameworkVersion] WITH (NOLOCK);

SELECT COUNT_BIG(*) AS [MonitorProcedureCount]
FROM [sys].[procedures] AS [p] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [p].[schema_id]
WHERE [s].[name] = N'monitor';
```

Die Versionsabfrage muss genau eine Frameworkzeile mit `FrameworkVersion=1.1.2`
liefern. Die Prozedurzahl muss größer als `0` sein. Der anschließende Smoke-Test
prüft den katalogisierten Kernbestand genauer.

## 9. Smoke-Test ausführen

1. Öffnen Sie in SSMS die Datei `Code\Tests\Integration\110_Smoke_Test.sql`.
2. Beide Vorkommen von `[DeineDatenbank]` durch den lokal gewählten, korrekt
   geklammerten Datenbanknamen ersetzen.
3. Führen Sie die gesamte Datei mit `F5` aus.

Der letzte Ergebnisdatensatz muss unter anderem enthalten:

- `StatusCode = AVAILABLE`;
- `IsPartial = 0`;
- `Detail = Kompakter Smoke Test erfolgreich.`

Ein Fehler im Smoke-Test ist kein Grund, einzelne Prüfungen zu löschen oder auszukommentieren. Prüfen Sie zuerst die Meldung und den vorherigen Installationslauf.

## 10. Analysebereitschaft und Berechtigungen prüfen

```sql
USE [DeineDatenbank];
GO

EXEC [monitor].[USP_CheckFrameworkCapabilities]
     @ResultSetArt = 'CONSOLE';

EXEC [monitor].[USP_CheckAnalyseAccess]
     @ResultSetArt = 'CONSOLE';
```

Diese Prüfungen trennen technische SQL-Server-Berechtigungen von der internen Ressourcenschutz-Policy. `DENIED_PERMISSION`, `AVAILABLE_LIMITED` oder partielle Resultsets können auf fehlende Laufzeitrechte oder nicht verfügbare Features hinweisen; sie bedeuten nicht automatisch, dass die Frameworkobjekte fehlerhaft installiert wurden.

Typische Laufzeitrechte sind:

- SQL Server 2019: je nach Analyse `VIEW SERVER STATE` und `VIEW DATABASE STATE`;
- SQL Server 2022 oder neuer: je nach Quelle `VIEW SERVER PERFORMANCE STATE` und `VIEW DATABASE PERFORMANCE STATE`;
- einzelne Sicherheits-, SQL-Agent-, `msdb`-, Query-Store-, Extended-Events- oder featurebezogene Quellen können zusätzliche Rechte verlangen.

Die tatsächlich erforderlichen Rechte hängen vom aufgerufenen Modul ab. Das Framework erteilt sie bewusst nicht automatisch. Nach dem Ersttest das Laufzeitkonto und die interne Policy anhand der [Administrationsanleitung](../Operations/Authorization_Administration.md) einrichten.

### Optional: persistentes Snapshot-/Baseline-Paket SC-023

Der aktuelle Repositorystand enthält eine zusätzliche Schema-2-Migration.
Für einen lokalen Neubau gelten dessen
[Targetversion, Installationsrechte und Transaktionsvoraussetzungen](../Architecture/Snapshot_Baseline_Package_Contract.md#installation).
Die bereits veröffentlichte Produkt-ZIP bleibt an ihren ursprünglichen
Commit und Paketstand gebunden.

Der Kerninstaller installiert keine Snapshot-/Baseline-Persistenz. Nach erfolgreicher
Kerninstallation ergänzen Sie das optionale Paket aus derselben ZIP:

1. Eine eigene, beschreibbare Snapshotdatenbank auf derselben Instanz anlegen
   und die erforderlichen Installationsrechte bereitstellen. Verwenden Sie
   eine andere Benutzerdatenbank als die Frameworkdatenbank. Die
   [Betriebsanleitung](../Operations/Snapshot_Baseline_Operations.md#installation)
   enthält ein generisches Anlagebeispiel und die Rechtebeschreibung.
2. `Code/Install/generated/Install_SnapshotBaseline_Target.generated.sql` in
   SSMS öffnen. Im Datenbankfeld dieses Abfragefensters ausdrücklich die
   Snapshotdatenbank auswählen und die gesamte Datei ausführen. Der Installer
   verwendet den aktuellen Verbindungskontext und enthält keine eigene
   Datenbankauswahl. Er lehnt Systemdatenbanken ab, erkennt aber keine
   versehentlich gewählte andere Benutzerdatenbank als beabsichtigtes Ziel.
3. Nach fehlerfreiem Targetlauf
   `Code/Install/generated/Install_SnapshotBaseline_Framework.generated.sql`
   öffnen. Die enthaltene `USE [DeineDatenbank];`-Zeile auf die
   Frameworkdatenbank setzen und die gesamte Datei ausführen.
4. Erst nach beiden erfolgreichen Installern das Ziel gemäß
   [Betriebsanleitung](../Operations/Snapshot_Baseline_Operations.md#installation)
   mit `monitor.USP_ConfigureSnapshotTarget` ausdrücklich konfigurieren.
   Bei einer Erstinstallation bleibt die Zielbindung bis dahin deaktiviert.
5. In der Snapshotdatenbank muss `snapshot.PackageVersion` für `SC-023` die
   Paketversion `1.0.0` mit `SchemaVersion=1` enthalten. In der Frameworkdatenbank
   muss `monitor.SnapshotTargetConfiguration` den gewählten Zielnamen und die
   ausdrücklich gesetzte Aktivierung und Schedulerart zeigen. Diese
   Paketversion ist von der Frameworkversion `1.1.2` getrennt.

Beide Dateien liegen im Produkt-ZIP fertig vor und benötigen keinen
SQLCMD-Modus. Sie erstellen keine Datenbank, Rechte oder Schedulerobjekte.
Die Konfiguration startet keine Sammlung; ein Scheduler ist separat
einzurichten. Die Schritte laufen getrennt und besitzen keinen gemeinsamen
Rollback. Für ein bereits vorhandenes Paket gilt stattdessen das
[Upgrade mit bestehendem Snapshot/Baseline](#upgrade-mit-bestehendem-snapshot-baseline-paket).

## 11. Erste Analyse starten

Ermitteln Sie zuerst einen passenden Einstieg anhand des Symptoms oder Analyseziels:

```sql
USE [DeineDatenbank];
GO

EXEC [monitor].[USP_AnalysisNavigator]
     @Suchbegriff = N'Etwas ist jetzt langsam',
     @NurInstallierte = 1,
     @ResultSetArt = 'CONSOLE';
```

Der Navigator führt keine vorgeschlagene Analyse aus.

Eine leichte, begrenzte Übersicht:

```sql
USE [DeineDatenbank];
GO

EXEC [monitor].[USP_CurrentOverview]
     @MitSqlText    = 0,
     @SampleSeconds = 0,
     @MaxZeilen     = 100,
     @ResultSetArt  = 'CONSOLE';
```

Ein aktuelles Wait-Delta:

```sql
EXEC [monitor].[USP_CurrentWaits]
     @SampleSeconds     = 15,
     @TopWaitPercentage = 95,
     @MaxZeilen         = 100,
     @ResultSetArt      = 'CONSOLE';
```

Weitere ausführbare Beispiele stehen in `Code\Examples\040_Schnellreferenz_Aufrufe.sql`.

## 12. Alternative: Installation im SQLCMD-Modus von SSMS

Der Include-Installer `Code\Install\Install_All.sql` bindet die kanonischen
Einzeldateien mit `:r` in ihrer abhängigkeitssicheren Reihenfolge ein. Dieser Weg
installiert unmittelbar aus den Quelldateien und benötigt keinen vorher
generierten Gesamtinstaller. Er eignet sich besonders für Entwicklung und für
Administratoren, die den einbezogenen Quellbestand einzeln kontrollieren wollen.

Der SQLCMD-Modus ersetzt den Datenbankplatzhalter nicht automatisch. Weil jede
kanonische SQL-Datei auch einzeln ausführbar bleibt, muss `[DeineDatenbank]` vor
der Installation in allen eingebundenen Dateien ersetzt werden.

### 12.1 Separate Arbeitskopie anlegen

1. Das Repository vollständig herunterladen oder klonen.
2. Für die Installation eine separate lokale Arbeitskopie verwenden. Dadurch
   bleiben die heruntergeladenen Originaldateien unverändert und können später
   mit Git beziehungsweise dem Download verglichen werden.
3. Die Verzeichnisse unter `Code` nicht verschieben oder einzeln kopieren. Die
   `:r`-Anweisungen in `Install_All.sql` benötigen die vorhandene relative
   Verzeichnisstruktur.

Beispielstruktur:

```text
SQL_Server_Analyze-SqlCmd\
└── Code\
    ├── 00_Setup\
    ├── 01_Common\
    ├── ...
    ├── 09_VersionAdaptive\
    └── Install\
        └── Install_All.sql
```

### 12.2 Datenbankplatzhalter in der Arbeitskopie ersetzen

Vor dem Ersetzen muss die Installationsdatenbank gemäß den Schritten 3 und 4
dieser Anleitung geprüft beziehungsweise angelegt worden sein.

Mit einem Editor, der **Suchen und Ersetzen in Dateien** unterstützt:

1. Wählen Sie als Suchbereich ausschließlich den Ordner `Code` der Arbeitskopie.
2. Nach dem exakten Text `[DeineDatenbank]` suchen.
3. Ersetzen Sie den Platzhalter durch den korrekt geklammerten lokalen Datenbanknamen.
4. Nur Dateien mit der Endung `.sql` ändern.
5. Anschließend repositoryweit prüfen, dass unter `Code` kein
   `[DeineDatenbank]` mehr vorkommt.

Alternativ kann die Ersetzung reproduzierbar mit PowerShell erfolgen. Das
folgende Skript fragt den Namen ab, klammert auch eine schließende eckige Klammer
im Namen korrekt und bearbeitet ausschließlich `.sql`-Dateien unter `Code`:

```powershell
$RepositoryRoot = 'C:\Tools\SQL_Server_Analyze-SqlCmd'
$DatabaseName = Read-Host 'Name der Installationsdatenbank'

if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
    throw 'Der Datenbankname darf nicht leer sein.'
}

$QuotedDatabaseName = '[' + $DatabaseName.Replace(']', ']]') + ']'
$Utf8WithoutBom = [Text.UTF8Encoding]::new($false)

Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Code') `
              -Filter '*.sql' -File -Recurse |
    ForEach-Object {
        $Content = [IO.File]::ReadAllText($_.FullName)
        $UpdatedContent = $Content.Replace(
            '[DeineDatenbank]',
            $QuotedDatabaseName
        )
        if ($UpdatedContent -ne $Content) {
            [IO.File]::WriteAllText(
                $_.FullName,
                $UpdatedContent,
                $Utf8WithoutBom
            )
        }
    }

$Remaining = Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'Code') `
                           -Filter '*.sql' -File -Recurse |
    Select-String -SimpleMatch '[DeineDatenbank]'

if ($Remaining) {
    throw 'Der Datenbankplatzhalter ist noch in SQL-Dateien vorhanden.'
}
```

Dieser Schritt verändert nur die lokale Arbeitskopie und führt noch kein SQL
aus.

### 12.3 Include-Installer in SSMS öffnen

1. SSMS starten und mit der vorgesehenen SQL-Server-Instanz verbinden.
2. Über **Datei > Öffnen > Datei** genau die vorbereitete Datei
   `Code\Install\Install_All.sql` öffnen. Kein neues leeres Abfragefenster
   verwenden und den Inhalt nicht in ein solches kopieren.
3. Kontrollieren, dass die erste `USE`-Anweisung den gewählten Datenbanknamen
   enthält.
4. Prüfen, dass darunter `:r`-Zeilen für `00_Setup` bis
   `09_VersionAdaptive` vorhanden sind.
5. Führen Sie das Abfragefenster noch nicht aus.

### 12.4 SQLCMD-Modus aktivieren und kontrollieren

1. Im aktiven Installerfenster **Abfrage > SQLCMD-Modus** auswählen.
2. Kontrollieren, dass der Menüeintrag aktiviert ist. Der SQLCMD-Modus gilt nur
   für das jeweilige Abfragefenster.
3. Die `:ON ERROR EXIT`- und `:r`-Zeilen müssen nun als SQLCMD-Befehle mit
   schattiertem Hintergrund dargestellt werden. Bleiben sie gewöhnlicher
   SQL-Text, ist der Modus nicht aktiv.

SQLCMD-Modus ist in SSMS standardmäßig nicht aktiv. Microsoft dokumentiert die
Aktivierung, die farbliche Kennzeichnung und die Unterstützung von `:r` unter
[Microsoft Learn: SQLCMD-Skripts mit dem Abfrage-Editor bearbeiten](https://learn.microsoft.com/de-de/ssms/scripting/sqlcmd-scripts-query-editor).

### 12.5 Verbindung und Ausführung prüfen

Vor `F5` kontrollieren:

- Das Abfragefenster ist mit der richtigen Serverinstanz verbunden.
- Die Installationsdatenbank existiert und ist `ONLINE` sowie beschreibbar.
- Die Collationprüfungen aus Schritt 3 waren erfolgreich.
- Der Datenbankplatzhalter ist vollständig ersetzt.
- Die Arbeitskopie enthält weiterhin alle von `:r` referenzierten Dateien.
- Der ausführende Login besitzt die erforderlichen DDL-Rechte.

Danach:

1. Sicherstellen, dass kein Text im Abfragefenster markiert ist. Andernfalls
   würde SSMS nur den markierten Ausschnitt ausführen.
2. **Ausführen** wählen oder `F5` drücken.
3. Die Verarbeitung bis zum Ende abwarten.
4. Die Registerkarte **Meldungen** kontrollieren. `:ON ERROR EXIT` beendet den
   Include-Installer beim ersten SQL-Fehler; nach einem Fehler ist die
   Installation als unvollständig zu behandeln.

### 12.6 SQLCMD-Installation verifizieren

Nach einem fehlerfreien Installerlauf dieselben Prüfungen wie beim empfohlenen
Weg durchführen:

1. Kontrollieren Sie Version und Kernobjekte gemäß Schritt 8.
2. `Code\Tests\Integration\110_Smoke_Test.sql` aus derselben vorbereiteten
   Arbeitskopie öffnen und vollständig ausführen. Der Datenbankplatzhalter ist
   dort durch die repositoryweite Ersetzung bereits gesetzt.
3. Führen Sie die Capability- und Berechtigungsprüfung aus Schritt 10 aus.
4. Erst danach mit den begrenzten Beispielaufrufen aus Schritt 11 beginnen.

### 12.7 Typische SQLCMD-Fehler

| Meldung oder Beobachtung | Ursache | Maßnahme |
|---|---|---|
| Syntaxfehler bei `:` oder `:r` | SQLCMD-Modus war nicht aktiv | Im betroffenen Abfragefenster **Abfrage > SQLCMD-Modus** aktivieren und Darstellung kontrollieren |
| `A fatal scripting error occurred. File ... could not be opened` | Include-Datei fehlt oder relative Verzeichnisstruktur wurde verändert | Vollständige Arbeitskopie wiederherstellen und `Install_All.sql` direkt aus `Code\Install` öffnen |
| Datenbank `DeineDatenbank` nicht gefunden | Platzhalter wurde nicht vollständig ersetzt | Ersetzung und abschließende Suche unter `Code` wiederholen |
| Installation endet nach dem ersten SQL-Fehler | `:ON ERROR EXIT` arbeitet wie vorgesehen | Erste SQL-Fehlermeldung beheben und anschließend den vollständigen Installer erneut ausführen |
| `:r`-Zeilen bleiben unmarkiert | Falsches Fenster oder Modus nicht aktiv | Installerfenster aktivieren und SQLCMD-Modus erneut einschalten |
| Installer funktioniert, Analyse ist partiell | Laufzeitberechtigung oder Feature fehlt | Schritt 10 und die Berechtigungsdokumentation verwenden |

Der eigenständige Installer bleibt die einfachere SSMS-Variante. Der
SQLCMD-Modus ist fachlich gleichwertig, verlangt aber eine vollständige,
konsistent vorbereitete Arbeitskopie der Einzeldateien.

## Upgrade

### Upgrade aus der Produkt-ZIP

1. Das vollständige Produkt-ZIP der gewünschten Version separat herunterladen,
   Prüfsumme gemäß Schritt 2 kontrollieren und vollständig entpacken.
   Keine Dateien unterschiedlicher Releases mischen.
2. Vorhandene Frameworkdatenbank sichern und den betrieblichen Rückfallweg
   festlegen. Soll auch ein vorhandenes Snapshotpaket aktualisiert werden,
   stattdessen den vollständigen
   [kombinierten Ablauf](#upgrade-mit-bestehendem-snapshot-baseline-paket) verwenden.
   Während des gesamten Ablaufs Frameworkaufrufe, Snapshot-Sammlung und Purge
   unterbrechen. Die Installer richten diese Unterbrechung nicht selbst ein.
3. Voraussetzungen des [Gesamtdeployments](Deployment.md) prüfen: eine
   vorhandene, erreichbare, online und beschreibbare Benutzerdatenbank,
   `CONTROL` auf dieser Datenbank und `VIEW ANY DEFINITION` auf dem Server.
   Availability Groups und Mirroring sind für diesen Deploymentweg
   ausgeschlossen. Ein eigenes SSMS-Abfragefenster ohne offene Transaktion
   und mit `IMPLICIT_TRANSACTIONS OFF` verwenden. Für DDL können exklusive
   Sperren und zusätzlicher Transaktionslogbedarf entstehen.
4. `Code/Install/generated/Deploy_All.generated.sql` aus diesem Paket öffnen.
   In der vorhandenen Deklaration ausschließlich den Datenwert der
   Frameworkdatenbank anpassen, beispielsweise:

   ```sql
   DECLARE @FrameworkDatabase nvarchar(max)=N'ExampleFrameworkDatabase',
           @SnapshotDatabase nvarchar(max)=NULL;
   ```

   `ExampleFrameworkDatabase` durch den tatsächlichen Namen ersetzen.
   `@SnapshotDatabase` muss `NULL` bleiben: Die ZIP enthält hier den
   Core-Installer. Eine vorhandene Snapshotdatenbank oder deren Konfiguration
   wird durch dieses Skript nicht aktualisiert.
5. Serververbindung kontrollieren, jeden markierten Ausschnitt aufheben und
   die gesamte Datei ausführen. Der SQLCMD-Modus ist nicht erforderlich.
   Die ausgegebene `DeploymentRunId` für die Abschlusskontrolle aufbewahren.
6. Meldungen und das persistente Receipt `monitor_deployment.Run_<RunId>` in
   der Frameworkdatenbank gemäß [Deploymentvertrag](Deployment.md#receipt-und-unklarer-abschluss)
   kontrollieren. Die Versionsabfrage aus Schritt 8 muss genau eine
   Frameworkzeile mit `FrameworkVersion=1.1.2` ergeben.
7. Die Smoke-, Capability- und Berechtigungsprüfungen aus den Schritten 9
   und 10 durchführen und danach die unterbrochenen Frameworkaufrufe wieder
   zulassen. Der hier beschriebene Core-Lauf bestätigt kein Snapshot-Upgrade.

Das Produkt-ZIP enthält bereits den aus seinem Quellcommit erzeugten und
abgenommenen Deploymentinstaller. Für diesen Downloadweg ist kein erneuter
Build erforderlich. Die Buildanweisung im Deploymentleitfaden gilt für einen
Quellcheckout oder einen bewusst gewählten Neubau.
Der Erstinstaller `Install_All.generated.sql` besitzt keinen gemeinsamen
Receipt- und Vorzustandsvertrag und ist deshalb nicht der Upgradeweg.
Vor produktiven Upgrades gelten die Sicherungs-, Change- und Rückfallprozesse
der Umgebung. Ein unklarer Abschluss muss vor einer Wiederholung anhand des
Receipts geklärt werden.

### Upgrade mit bestehendem Snapshot-/Baseline-Paket

Ab v1.1.1 enthält das Produkt-ZIP
`Code/Install/generated/Deploy_All_WithSnapshotBaseline.generated.sql`.
Dieses vorbereitete Skript aktualisiert Kern und Snapshot/Baseline gemeinsam;
ein Neubau ist nicht erforderlich. Der Ablauf verwendet den
[Erhaltungsvertrag des Gesamtdeployments](Deployment.md#prüfung-und-erhaltung)
mit einer Transaktion für beide Datenbanken, typgetreuen Vorzustandskopien
und je einem Receipt mit derselben Run-ID. Die unterstützten Strukturgrenzen
und Customkonflikte werden vor Produktänderungen geprüft.

1. Die Produkt-ZIP v1.1.2 und ihre Prüfsumme gemäß Schritt 2 herunterladen,
   vergleichen und vollständig entpacken. Der kombinierte Installer ist in
   v1.1.0 noch nicht enthalten. Keine Dateien unterschiedlicher Releases mischen.
2. Bestehende Framework- und Snapshotdatenbank sichern und den betrieblichen
   Rückfallweg festlegen. Zielbindung, lokale Policies und Historie für die
   Abschlusskontrolle festhalten. Während des gesamten Upgrades
   Frameworkaufrufe, Collection und Purge unterbrechen. Die vorhandene
   Snapshotdatenbank weiterverwenden; für ein Upgrade keine neue anlegen.
3. Die [Deploymentvoraussetzungen](Deployment.md#voraussetzungen-für-das-deployment)
   prüfen: zwei verschiedene vorhandene, online und beschreibbare
   Benutzerdatenbanken derselben Instanz, `CONTROL` auf beiden Datenbanken
   und `VIEW ANY DEFINITION` auf dem Server. Availability Groups und Mirroring
   sind für diese Route ausgeschlossen. Der Lauf benötigt exklusive Sperren
   und Platz für Vorzustände und Transaktionslog; Sperrwartezeiten sind auf
   zehn Sekunden begrenzt. Abgelehnte Struktur- oder Customkonflikte werden
   geklärt, ohne die Schutzprüfungen zu entfernen.
4. `Deploy_All_WithSnapshotBaseline.generated.sql` in einem eigenen
   SSMS-Abfragefenster auf der richtigen Instanz öffnen. Es darf keine
   Caller-Transaktion offen sein; `IMPLICIT_TRANSACTIONS` muss ausgeschaltet
   sein. In der vorhandenen Deklaration ausschließlich die beiden Datenwerte
   anpassen, beispielsweise:

   ```sql
   DECLARE @FrameworkDatabase nvarchar(max)=N'ExampleFrameworkDatabase',
           @SnapshotDatabase nvarchar(max)=N'ExampleSnapshotDatabase';
   ```

   Beide Beispielnamen durch die tatsächlich gewählten bestehenden
   Datenbanken ersetzen. Die Zielnamen werden ausdrücklich als Datenwerte
   angegeben; das Datenbankfeld des Abfragefensters bestimmt nicht die Ziele.
   Die eingebettete Produktlogik wird nicht geändert. Der Core-Installer
   `Deploy_All.generated.sql` ist für diesen Umfang die falsche Datei.
5. Die gesamte kombinierte Datei ohne markierten Ausschnitt ausführen. Der
   SQLCMD-Modus ist nicht erforderlich. Die ausgegebene `DeploymentRunId`
   aufbewahren, alle Meldungen kontrollieren und das Abschlussresultset
   `DeploymentStatus=COMMITTED` prüfen. Für diesen Ablauf sind die Core-
   und Snapshot-Einzelinstaller nicht zusätzlich auszuführen.
6. In beiden Datenbanken `monitor_deployment.Run_<RunId>` gemäß
   [Receiptkontrolle](Deployment.md#receipt-und-unklarer-abschluss) prüfen:
   gleiche Run-ID und gleicher Quellendigest, passende explizite Datenbanknamen,
   `FormatVersion=1` und die Rollen `FRAMEWORK` beziehungsweise `SNAPSHOT`.
   Eine Frameworkversionszeile allein belegt keinen vollständigen Abschluss.
7. In der Frameworkdatenbank Versionsprüfung, Smoke-Test sowie Capability-
   und Berechtigungsprüfung aus den Schritten 8 bis 10 durchführen. Erwartet
   wird Frameworkversion `1.1.2` und der dort beschriebene erfolgreiche
   Smoke-Test. In der Snapshotdatenbank muss `snapshot.PackageVersion` für
   `PackageCode='SC-023'` weiterhin `PackageVersion='1.0.0'` und `SchemaVersion=1`
   zeigen; die Versionen bezeichnen unterschiedliche Verträge.
8. Zielname, Aktivierung und Schedulerart in
   `monitor.SnapshotTargetConfiguration` sowie lokale Policies und Historie
   mit dem festgehaltenen Vorzustand abgleichen. Vorhandene kompatible
   Customdaten und die Zielbindung bleiben erhalten. Bei unverändertem Ziel
   `monitor.USP_ConfigureSnapshotTarget` nicht erneut aufrufen. Der Installer
   startet keine Collection und keinen Purge. Erst nach erfolgreicher
   Abschlusskontrolle die unterbrochenen Aufrufe und den vorhandenen
   Scheduler wieder zulassen.

Bei einem abgefangenen SQL-Fehler rollt die eigene Transaktion Produktänderungen
und neue Hilfstabellen beider Kontexte gemeinsam zurück. Nach Verbindungsabbruch,
Cancellation oder verlorener Commitantwort bleibt der Abschluss zunächst
unklar. Keine Sammlung und keinen erneuten Installerlauf starten, bevor
Receipts, die zugehörigen Sessions und der Objektzustand in beiden Datenbanken
gemäß Deploymentvertrag abgeglichen wurden. Fehlende Receipts bei noch laufender
oder zurückrollender Session sind kein abgeschlossener Rollbacknachweis.

Der kombinierte Installer kann auch beide Paketteile in zwei ausdrücklich
vorher angelegte leere Datenbanken installieren. Bei dieser Erstinstallation
bleibt die Snapshot-Zielbindung zunächst deaktiviert; sie wird danach gemäß
[Betriebsanleitung](../Operations/Snapshot_Baseline_Operations.md#installation)
ausdrücklich konfiguriert. Die weiterhin mitgelieferten Snapshot-Einzelinstaller
besitzen keine gemeinsame Transaktion, Receipt- oder Vorzustandserhaltung mit
einem separat ausgeführten Core-Lauf.

## Häufige Fehler

| Meldung oder Symptom | Wahrscheinliche Ursache | Maßnahme |
|---|---|---|
| Datenbank `DeineDatenbank` nicht gefunden | Platzhalter wurde nicht ersetzt | Erste `USE`-Zeile beziehungsweise Testdatei korrigieren |
| Der Installer warnt vor einer abweichenden Server-, `tempdb`- oder Datenbank-Collation | Eine der drei Collations weicht von der ausschließlich garantierten `SQL_Latin1_General_CP1_CS_AS` ab | Die Warnung blockiert die Installation nicht. Prüfen Sie die Zielkombination kontrolliert gemäß [Collation-Architektur](#collation-architektur), einschließlich Installation, Smoke-Test und benötigter Filter- und Exportpfade. Die Garantie wird dadurch nicht erweitert. |
| Syntaxfehler bei `:r` | Include-Installer ohne SQLCMD-Modus ausgeführt | SQLCMD-Modus aktivieren oder generierten Installer verwenden |
| Include-Datei nicht gefunden | Repository unvollständig, verschoben oder falscher Ausführungskontext | Repository vollständig entpacken oder generierten Installer verwenden |
| `CREATE`/`ALTER`/`CREATE SCHEMA` verweigert | DDL-Rechte fehlen | Installation mit einem dafür freigegebenen Konto ausführen |
| Frameworkobjekte fehlen oder Smoke-Test meldet falsche Version | Installer wurde nicht vollständig oder aus einem gemischten Stand ausgeführt | Meldungen prüfen, konsistenten Repositorystand verwenden und vollständig erneut installieren |
| Analyse liefert `DENIED_PERMISSION` oder `AVAILABLE_LIMITED` | Laufzeitrecht oder optionale Quelle fehlt | Capability-Ausgabe und Berechtigungsdokumentation prüfen |

## Abgrenzung

Die Installer vergeben keine Rechte und richten keinen Scheduler ein. Der
Deploymentweg speichert ausdrücklich Receipts und Vorzustände; das optionale
Snapshotpaket speichert bei autorisierten Betriebsaufrufen Laufzeitwerte.
Die Erst- und Snapshot-Einzelinstaller besitzen keinen gemeinsamen
Deployment-Receiptvertrag. Git und die Releaseartefakte bleiben die
Quellen- und Integritätsreferenz; ein zusätzliches, bei jeder Änderung
nachzuführendes Dateihash-Manifest wird nicht verwendet.

Ein realer Compile- und Laufzeittest auf der konkreten Zielversion, Edition, Plattform und Berechtigungsstufe bleibt erforderlich.

## Teilinstallation der Execution-Plan-Analyse

Für eine eigenständig nutzbare Plananalyse enthält das Produkt-ZIP bereits
`Code/Install/generated/Install_ExecutionPlanAnalysis.generated.sql`. Die
einleitende `USE`-Zeile auf die gewählte Installationsdatenbank setzen und die
gesamte Datei in SSMS ohne SQLCMD-Modus ausführen. Neben einer vollständigen
Kerninstallation ist dieser zusätzliche Teilinstaller nicht erforderlich.
Bei einem Quellcheckout stehen der Include-Installer
`Code/Install/Install_ExecutionPlanAnalysis.sql` im SQLCMD-Modus und der Builder
`Code/Install/Build-ExecutionPlanAnalysisInstaller.ps1` zur Verfügung.
Verfügbar sind danach mindestens `monitor.USP_ExecutionPlanAnalysis` und
`monitor.USP_CreateExecutionEvidenceJson`; Query Store, Current State,
Extended Events und Server Health werden nicht mitinstalliert.
