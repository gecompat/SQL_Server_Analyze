# Installation in SQL Server Management Studio (SSMS)

Diese Anleitung beschreibt die vollständige Erstinstallation und die anschließende Funktionsprüfung. Der empfohlene Weg erzeugt zunächst einen eigenständigen Installer und führt danach nur eine SQL-Datei in SSMS aus.

## 1. Voraussetzungen prüfen

Benötigt werden:

- SQL Server 2019 oder neuer;
- SQL Server Management Studio (SSMS);
- Windows PowerShell oder PowerShell 7 zum Erzeugen des eigenständigen Installers;
- eine lokale Kopie dieses Repositorys;
- für die einmalige Installation ausreichende DDL-Rechte in der Installationsdatenbank. Für die Erstinstallation ist die Datenbankrolle `db_owner` der einfachste verlässliche Weg;
- Server, `tempdb` und Installationsdatenbank mit der Collation `SQL_Latin1_General_CP1_CS_AS`.

Das Framework vergibt keine Benutzer-, Datenbank- oder Serverberechtigungen und ändert keine Serverkonfiguration.

## 2. Repository herunterladen

1. Auf der GitHub-Seite des Repositorys **Code** und danach **Download ZIP** wählen. Alternativ das Repository mit Git klonen.
2. Die ZIP-Datei vollständig in ein lokales Verzeichnis entpacken, beispielsweise `C:\Tools\SQL_Server_Analyze`.
3. Die Verzeichnisstruktur unverändert lassen. Der Build und der alternative SQLCMD-Installer verwenden relative Pfade.
4. Vor Verwendung die Datei `LICENSE.md` lesen.

## 3. Zielinstanz und Collation kontrollieren

1. SSMS starten.
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

Die Installation ist nur freigegeben, wenn:

- `ProductMajorVersion` mindestens `15` ist;
- `ServerCollation` exakt `SQL_Latin1_General_CP1_CS_AS` lautet;
- `TempDbCollation` exakt `SQL_Latin1_General_CP1_CS_AS` lautet.

Eine abweichende Server- oder `tempdb`-Collation lässt sich nicht durch eine anders collatierte Frameworkdatenbank kompensieren. In diesem Fall die Installation abbrechen und die Zielinstanz prüfen.

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

Dieser Schritt benötigt keine SQL-Server-Verbindung und verändert den Server nicht.

1. PowerShell öffnen.
2. In das Installationsverzeichnis der entpackten Repositorykopie wechseln:

```powershell
Set-Location 'C:\Tools\SQL_Server_Analyze\Code\Install'
```

3. Den Build ausführen:

```powershell
.\Build-StandaloneInstaller.ps1
```

4. Die Erfolgsmeldung kontrollieren. Im selben Verzeichnis muss nun die Datei `Install_All.generated.sql` liegen.

Das Buildskript übernimmt die kanonischen SQL-Dateien in ihrer abhängigkeitssicheren Reihenfolge. `Install_All.generated.sql` ist ein lokales Build-Artefakt und wird nicht in Git versioniert. Falls die lokale PowerShell-Richtlinie das Skript blockiert, die Richtlinie nicht unkontrolliert umgehen, sondern die Ausführung mit der zuständigen Administration klären oder den alternativen SQLCMD-Weg verwenden.

## 6. Installer in SSMS vorbereiten

1. In SSMS **Datei > Öffnen > Datei** wählen.
2. `Code\Install\Install_All.generated.sql` öffnen.
3. Nur die erste Zeile anpassen:

```sql
USE [DeineDatenbank];
```

4. Kontrollieren, dass das Abfragefenster mit der richtigen Serverinstanz verbunden ist.
5. Die gesamte Datei ausführen, nicht nur einen markierten Ausschnitt.

Der generierte Installer enthält keine `:r`-Anweisungen. Für ihn muss der SQLCMD-Modus in SSMS daher nicht aktiviert werden.

## 7. Installation ausführen

1. Im Installerfenster **Ausführen** wählen oder `F5` drücken.
2. Bis zum Ende warten und insbesondere die Registerkarte **Meldungen** kontrollieren.
3. Bei einem Fehler nicht von einer vollständigen Installation ausgehen. Ursache beheben und anschließend den gesamten Installer erneut ausführen.

Die Frameworkobjekte liegen danach in der gewählten Datenbank im Schema `[monitor]`. Der Installer verwendet `CREATE OR ALTER` sowie idempotente DDL-/DML-Logik und kann deshalb auch für Upgrades erneut vollständig ausgeführt werden.

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

Die Versionsabfrage muss genau eine Frameworkzeile liefern. Die Prozedurzahl muss größer als `0` sein.

## 9. Smoke-Test ausführen

1. In SSMS die Datei `Code\Tests\Integration\110_Smoke_Test.sql` öffnen.
2. Beide Vorkommen von `[DeineDatenbank]` durch den lokal gewählten, korrekt
   geklammerten Datenbanknamen ersetzen.
3. Die gesamte Datei mit `F5` ausführen.

Der letzte Ergebnisdatensatz muss unter anderem enthalten:

- `StatusCode = AVAILABLE`;
- `IsPartial = 0`;
- `Detail = Kompakter Smoke Test erfolgreich.`

Ein Fehler im Smoke-Test ist kein Grund, einzelne Prüfungen zu löschen oder auszukommentieren. Zuerst die Meldung und den vorherigen Installationslauf prüfen.

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

## 11. Erste Analyse starten

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

## Alternative: SQLCMD-Installer mit Einzeldateien

Der Include-Installer `Code\Install\Install_All.sql` bindet die kanonischen Dateien mit `:r` ein. Dieser Weg ist vor allem für Entwicklungs- und Automatisierungsabläufe gedacht.

1. In einer lokalen Repositorykopie `[DeineDatenbank]` in `Install_All.sql` und allen eingebundenen SQL-Dateien durch den Zielnamen ersetzen.
2. `Code\Install\Install_All.sql` in SSMS öffnen.
3. Für genau dieses Abfragefenster **Abfrage > SQLCMD-Modus** aktivieren. SQLCMD-Modus ist in SSMS standardmäßig nicht aktiv.
4. Kontrollieren, dass die Repositorystruktur und alle relativen `:r`-Pfade unverändert vorhanden sind.
5. Die gesamte Datei ausführen.

Die Aktivierung und die in SSMS unterstützten SQLCMD-Befehle beschreibt
[Microsoft Learn: Edit SQLCMD scripts with Query Editor](https://learn.microsoft.com/en-us/ssms/scripting/sqlcmd-scripts-query-editor).

Erscheint ein Syntaxfehler direkt bei `:r`, war der SQLCMD-Modus nicht aktiv. Meldet SSMS eine nicht gefundene Include-Datei, sind Pfad oder Repositorystruktur falsch; in diesem Fall ist der eigenständige Installer der robustere Weg.

## Upgrade

1. Die gewünschte neue Repositoryversion separat herunterladen oder auschecken.
2. Den eigenständigen Installer aus genau diesem Stand neu erzeugen.
3. Den Datenbanknamen in der ersten Zeile setzen.
4. Den gesamten Installer erneut ausführen.
5. Versionsprüfung und Smoke-Test wiederholen.

Frameworkeigene Standardzeilen im Wait-Katalog werden aktualisiert; eigene Katalogzeilen bleiben erhalten. Vor produktiven Upgrades gelten die üblichen Sicherungs-, Change- und Rückfallprozesse der Umgebung.

## Häufige Fehler

| Meldung oder Symptom | Wahrscheinliche Ursache | Maßnahme |
|---|---|---|
| Datenbank `DeineDatenbank` nicht gefunden | Platzhalter wurde nicht ersetzt | Erste `USE`-Zeile beziehungsweise Testdatei korrigieren |
| Nicht unterstützte Server-, `tempdb`- oder Datenbank-Collation | Eine der drei Collations weicht ab | Installation auf dieser Instanz abbrechen und Plattformvoraussetzung klären |
| Syntaxfehler bei `:r` | Include-Installer ohne SQLCMD-Modus ausgeführt | SQLCMD-Modus aktivieren oder generierten Installer verwenden |
| Include-Datei nicht gefunden | Repository unvollständig, verschoben oder falscher Ausführungskontext | Repository vollständig entpacken oder generierten Installer verwenden |
| `CREATE`/`ALTER`/`CREATE SCHEMA` verweigert | DDL-Rechte fehlen | Installation mit einem dafür freigegebenen Konto ausführen |
| Frameworkobjekte fehlen oder Smoke-Test meldet falsche Version | Installer wurde nicht vollständig oder aus einem gemischten Stand ausgeführt | Meldungen prüfen, konsistenten Repositorystand verwenden und vollständig erneut installieren |
| Analyse liefert `DENIED_PERMISSION` oder `AVAILABLE_LIMITED` | Laufzeitrecht oder optionale Quelle fehlt | Capability-Ausgabe und Berechtigungsdokumentation prüfen |

## Abgrenzung

Es gibt bewusst keine persistente Installationshistorie, keine automatische Rechtevergabe und keine implizite Datenspeicherung. Git ist die maßgebliche Versions- und Integritätsquelle; ein zusätzliches, bei jeder Änderung nachzuführendes Dateihash-Manifest wird nicht verwendet.

Ein realer Compile- und Laufzeittest auf der konkreten Zielversion, Edition, Plattform und Berechtigungsstufe bleibt erforderlich.
