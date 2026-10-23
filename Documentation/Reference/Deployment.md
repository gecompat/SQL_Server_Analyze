# Wiederholbares Gesamtdeployment

## Produkt-ZIP ohne Neubau

Das Produkt-ZIP v1.1.2 enthält bereits zwei fertige Deploymentumfänge unter
`Code/Install/generated`: `Deploy_All.generated.sql` für den Frameworkkern und
`Deploy_All_WithSnapshotBaseline.generated.sql` für Kern und Snapshot/Baseline.
Die [Upgradeanleitung](Installation.md#upgrade-aus-der-produkt-zip) beschreibt
Vorbereitung, Datenbankauswahl, Ausführung und Abschlusskontrolle in SSMS.
Für diesen Weg sind weder PowerShell noch Python oder der SQLCMD-Modus
erforderlich.

Im Core-Installer wird ausschließlich `@FrameworkDatabase` auf
die vorhandene Frameworkdatenbank gesetzt; `@SnapshotDatabase` muss `NULL`
bleiben. Der Quellumfang ist beim Build festgelegt. Ein anderer Datenwert
fügt dem Core-Artefakt keine Snapshotquellen hinzu und wird dort abgelehnt.

Für ein bestehendes Snapshot-/Baseline-Paket gilt das
[kombinierte Upgrade aus der ZIP](Installation.md#upgrade-mit-bestehendem-snapshot-baseline-paket).
Im zusätzlichen `Deploy_All_WithSnapshotBaseline.generated.sql` werden
`@FrameworkDatabase` und `@SnapshotDatabase` auf zwei verschiedene vorhandene
Benutzerdatenbanken derselben Instanz gesetzt. Der nachstehende gemeinsame
Transaktions-, Receipt- und Vorzustandsvertrag gilt dann für beide Kontexte.
Eine vorhandene Zielbindung wird erhalten, nicht automatisch neu gesetzt.
Die ältere v1.1.0-ZIP enthält diesen kombinierten Installer noch nicht.

## Lokaler Neubau aus Quellen

Dieser Abschnitt gilt für Quellcheckouts und für einen bewusst gewählten
Neubau. Für beide vorbereiteten ZIP-Installer ist er nicht erforderlich.

`Code/Install/Build-DeploymentInstaller.ps1` erzeugt den Gesamtdeploymentweg aus den kanonischen SQLCMD-Includes und den darin enthaltenen SQL-Quellen. Der Build benötigt PowerShell und Python 3.10 oder neuer. Der Python-Renderer verwendet ausschließlich die Standardbibliothek und verbindet sich nicht mit SQL Server. Unbekannte Quellformen führen zu einem Buildfehler; ein vorhandenes Ausgabe-Artefakt wird bei einem Fehler nicht ersetzt.

```powershell
./Code/Install/Build-DeploymentInstaller.ps1
# Core mit dem optionalen Snapshot-/Baseline-Paket:
./Code/Install/Build-DeploymentInstaller.ps1 -IncludeSnapshotBaseline
# Ein bestimmter vorhandener Python-Interpreter kann gewählt werden:
./Code/Install/Build-DeploymentInstaller.ps1 -PythonExecutable 'C:/Tools/Python/python.exe'
```

Das Ergebnis liegt unter `Code/Install/generated/Deploy_All.generated.sql`. In dieser Datei sind ausschließlich die Datenwerte der Deklaration `@FrameworkDatabase` und, beim optionalen Paket, `@SnapshotDatabase` anzupassen. Die Snapshotdatenbank muss eine andere vorhandene Benutzerdatenbank auf derselben Instanz sein. Anschließend wird die gesamte Datei in SSMS oder mit `sqlcmd -b` ausgeführt. Die Datei benötigt keinen SQLCMD-Modus. Ein zufällig gewählter Abfragekontext wird nicht als Installationsziel verwendet.

## Voraussetzungen für das Deployment

Die ausgewählten Datenbanken müssen online, beschreibbar und erreichbar sein. Der ausführende Benutzer benötigt `CONTROL` auf allen ausgewählten Datenbanken und `VIEW ANY DEFINITION` auf dem Server. Availability Groups und Database Mirroring sind für diesen Deploymentweg derzeit ausgeschlossen. Die Datei erzeugt weder Datenbanken noch Berechtigungen, Jobs oder Serverkonfigurationen. Offene Caller-Transaktionen und `IMPLICIT_TRANSACTIONS ON` werden vor der eigenen Transaktion abgelehnt. Die Fehlermeldung wird mit lokalem `XACT_ABORT OFF` in einem untergeordneten Ausführungsscope ausgelöst, damit die Caller-Transaktion und deren Optionen erhalten bleiben.

## Prüfung und Erhaltung

Das Deployment prüft die ausgewählten Kontexte vor Produktänderungen und hält seine Änderungen in einer gemeinsamen Transaktion. Zuerst erwirbt es in `tempdb` eine gemeinsame exklusive Anwendungssperre für den gesamten Lauf. Damit werden auch Deployments auf unterschiedlichen Datenbankpaaren derselben Instanz serialisiert, weil die nativen Referenztabellen gemeinsame tempdb-Metadaten verwenden. Anschließend werden die Anwendungssperren der ausgewählten Datenbanken nach Datenbankname geordnet erworben. Bestehende aktive Tabellen werden mit `TABLOCKX` und `HOLDLOCK` gesperrt; Sperrwartezeiten sind auf zehn Sekunden begrenzt. Eine fehlgeschlagene Sperre bricht den Lauf ab. Der Lauf kann dadurch produktive Zugriffe blockieren. Für große bestehende Kataloge entsteht zusätzlich Speicher- und Transaktionslogbedarf durch die Vorzustandskopien.

Der Rechtecheck erfolgt vor dem Erwerb der Anwendungssperren. Alle Ausführenden verwenden dabei den gemeinsamen Datenbankprincipal `public`. Damit setzt die Sperre keine zusätzliche Mitgliedschaft in `db_owner` voraus; `sp_getapplock` verlangt die Mitgliedschaft im gewählten Principal. Der Installer vergibt dabei keine zusätzlichen Rechte. Die Principalbindung beschreibt die [Microsoft-Dokumentation zu `sp_getapplock`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-getapplock-transact-sql?view=sql-server-ver17).

Die Metadatenprüfung leitet Typen, Nullbarkeit, Collations, Identity, Constraints, Indizes und Fremdschlüssel aus den aktuellen Quellen ab. Zulässig sind die zwölf bekannten additiven Wait-Spalten. Abweichende Tabellengestalten, unbekannte Abhängigkeiten, Trigger und weitere nicht unterstützte Datenzugriffsmechanismen werden vor Änderungen abgelehnt. Die konkreten Grenzen und Fehlerfälle beschreibt der [Deploymentvertrag](../Architecture/Lossless_Deployment_Contract.md).

Customzeilen und Snapshotdaten bleiben in ihren Tabellen erhalten. Lokal gesetztes `IsEnabled` bei Toolregeln, Planprofilen und Schwellen bleibt erhalten. Eine vorhandene kompatible `VW_AnalyseAccessPolicy` behält ihre Definition. Legacyobjekte werden in dieser Route nicht entfernt. Markerlose Build- und Lifecyclekataloge werden bei widersprechenden bekannten Schlüsseln vor Änderungen abgelehnt; unbekannte vorhandene Schlüssel bleiben erhalten.

Vor installierenden Updates oder Deletes werden die betroffenen Tabellen in `monitor_deployment.State_<RunId>_<Ordinal>` erhalten. Die Kopien speichern die ursprünglichen Werte typgetreu; Identitywerte werden als gewöhnliche Werte ihres Typs und rowversion-Werte als `binary(8)` gespeichert. Die aktive Identity und deren Zähler bleiben erhalten. Erst nach der Erhaltung können Frameworkdefaults und Versionswerte aktualisiert oder retirierte Framework-Waits samt ihren Frameworkquellen entfernt werden. Customquellen, die diesen retirierenden Waits zugeordnet sind oder mit erforderlichen Defaultschlüsseln kollidieren, führen vor Änderungen zum Abbruch.

## Receipt und unklarer Abschluss

Jeder erfolgreiche Lauf erstellt auch bei einer Erstinstallation pro ausgewählter Datenbank `monitor_deployment.Run_<RunId>`. Der Datensatz enthält die ausgegebene Run-ID, Formatversion 1, den SHA256 der eingebetteten Quellen samt Renderer, die expliziten Datenbanknamen und Rollen sowie ein JSON-Manifest der erhaltenen Tabellen. Das Manifest beschreibt ursprüngliche Spaltenfacetten, Identityzähler, Constraints, Indizes, Fremdschlüssel und Zeilenzahlen. `ReceiptAtUtc` bezeichnet den Zeitpunkt der Receipt-Erstellung innerhalb der Transaktion, nicht den Commitzeitpunkt. Das Schema gehört `dbo` und trägt den Formatmarker `SQL_Server_Analyze.DeploymentFormat=1`; ein unbekanntes gleichnamiges Schema wird abgelehnt.

Bei einem SQL-Fehler rollt die eigene Transaktion Produktänderungen und neue Hilfstabellen gemeinsam zurück. Nach Verbindungsabbruch oder Cancellation kann der Abschluss beim Client unbekannt sein. In einer neuen Verbindung sind deshalb die zuvor ausgegebene Run-ID, die Receipts in allen gewählten Datenbanken, deren Rollen und SHA256 sowie die aktuelle Objektgestalt abzugleichen. Ein fehlendes Receipt bei noch laufender oder zurückrollender Session belegt keinen abgeschlossenen Rollback. Vor einer erneuten Ausführung muss dieser Zustand geklärt werden. Das Deployment entfernt ältere Receipts und Vorzustände nicht automatisch.

Für Kernupgrades wird `Deploy_All.generated.sql` aus dem passenden Produkt-ZIP
oder aus einem aktuellen kanonischen Neubau verwendet. Ein erneuter Build
des unveränderten ZIP-Installers ist nicht erforderlich. Die bisherigen
Einzelinstaller bleiben für ihre jeweiligen Installationsumfänge verfügbar;
ihre Idempotenz ersetzt keinen allgemeinen Migrationsnachweis. Für ein
Snapshot-Upgrade wird der fertig mitgelieferte kombinierte Installer gemäß
[Abschlusskontrolle](Installation.md#upgrade-mit-bestehendem-snapshot-baseline-paket)
verwendet. Die weiterhin verfügbaren Snapshot-Einzelinstaller besitzen keinen
gemeinsamen Receipt-, Vorzustands- oder Rollbackvertrag mit einem separat
ausgeführten Core-Lauf.
