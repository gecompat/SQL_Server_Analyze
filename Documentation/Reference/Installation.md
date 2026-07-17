# Installation und Inbetriebnahme

## Voraussetzungen

- SQL Server 2019 oder neuer.
- Eine frei gewählte Installationsdatenbank ist vorhanden.
- Server, `tempdb` und Installationsdatenbank verwenden `SQL_Latin1_General_CP1_CS_AS`.
- Der ausführende Login besitzt die für die Installation erforderlichen DDL-Rechte.
- Das Framework vergibt keine Analyseberechtigungen und ändert keine Serverkonfiguration.

## Installation mit SQLCMD-Includes

1. Repository klonen oder herunterladen.
2. Den Platzhalter `[DeineDatenbank]` in den auszuführenden SQL-Dateien durch die Installationsdatenbank ersetzen.
3. In SSMS, Azure Data Studio oder `sqlcmd` mit der Zielinstanz verbinden.
4. `Code/Install/Install_All.sql` im SQLCMD-Modus vollständig ausführen.
5. Versionszeile prüfen:

```sql
SELECT *
FROM [monitor].[FrameworkVersion];
```

6. Analysebereitschaft prüfen:

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities];
EXEC [monitor].[USP_CheckAnalyseAccess];
```

7. Smoke Test ausführen:

```text
Code/Tests/Integration/110_Smoke_Test.sql
```

8. Öffentlichen Parametervertrag prüfen:

```text
Code/Tests/Integration/163_Parameter_API_Vertrag.sql
```

## Eigenständigen Installer erzeugen

```powershell
Set-Location ./Code/Install
./Build-StandaloneInstaller.ps1
```

Das Skript erzeugt `Code/Install/Install_All.generated.sql` aus den kanonischen Einzeldateien und übernimmt deren abhängigkeitssichere Reihenfolge direkt aus `Install_All.sql`. Im generierten Installer steht der Datenbankplatzhalter nur am Anfang. Das Build-Artefakt wird nicht versioniert.

## Upgrade

Den aktuellen Installer erneut ausführen. Frameworkobjekte verwenden `CREATE OR ALTER` beziehungsweise idempotente DDL-/DML-Logik. Frameworkeigene Standardzeilen im Wait-Katalog werden aktualisiert; eigene Katalogzeilen bleiben erhalten.

## Mengenbegrenzung

- positiver Wert: Ausgabe wird begrenzt;
- `NULL` oder `0`: unbegrenzte Ausgabe beziehungsweise alle sichtbaren Datenbanken;
- negativer Wert: `INVALID_PARAMETER`.

Breite Plan-Cache-, Showplan-, Query-Store-, Katalog- und Cross-Database-Auswertungen können wegen ihrer Eigenlast eine freigegebene Deep-Analyseklasse erfordern.

## Erste Ad-hoc-Analyse

```sql
EXEC [monitor].[USP_CurrentOverview]
     @MitSqlText = 0,
     @SampleSeconds = 0,
     @MaxZeilen = 100;
```

Für ein aktuelles Wait-Delta:

```sql
EXEC [monitor].[USP_CurrentWaits]
     @SampleSeconds = 15,
     @TopWaitPercentage = 95,
     @MaxZeilen = 100;
```

## Abgrenzung

Es gibt bewusst keine persistente Installationshistorie, keine automatische Rechtevergabe und keine implizite Datenspeicherung. Git ist die maßgebliche Versions- und Integritätsquelle; ein zusätzliches, bei jeder Änderung nachzuführendes Dateihash-Manifest wird nicht verwendet.

Ein realer Compile- und Laufzeittest auf der konkreten Zielversion, Edition, Plattform und Berechtigungsstufe bleibt erforderlich.
