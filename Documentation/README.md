# SQL Server Analyze – Projektübersicht

Dieses Repository enthält ein T-SQL-basiertes Diagnoseframework für SQL Server ab Version 2019.

## Verzeichnisse

- `Code/`: installierbarer T-SQL-Code, Installer, Tests und Beispielaufrufe
- `Documentation/`: Anforderungen, Architektur, Betrieb, Referenz, Analysehandbuch und Recherche
- `Metadata/`: maschinenlesbare Inventare und Qualitätsergebnisse
- `AI_Metadata/`: kompakter Kontext zur Fortsetzung der Entwicklung

## Analysehandbuch

Für praktische Analysen nicht im Forschungsdokument beginnen:

1. [`Analysis_Guides/Runbooks/README.md`](Analysis_Guides/Runbooks/README.md) – Einstieg nach Symptom
2. [`Analysis_Guides/Procedures/README.md`](Analysis_Guides/Procedures/README.md) – eigenständige Seiten für alle 84 Procedures
3. [`Analysis_Guides/Glossary.md`](Analysis_Guides/Glossary.md) – technische Begriffe
4. [`Analysis_Guides/Parameter_Reading_Guide.md`](Analysis_Guides/Parameter_Reading_Guide.md) – Parameter und sichere Aufrufe
5. [`Analysis_Guides/README.md`](Analysis_Guides/README.md) – Gesamtübersicht und Familienguides

Jede Procedure-Seite erklärt Zeilengranularität, Leserichtung, Problembegründung, Gegenbeispiel, Folgeanalyse und Grenzen leerer/partieller Resultsets.

## Installation

1. In allen SQL-Skripten den Platzhalter `[DeineDatenbank]` durch die vorgesehene Installationsdatenbank ersetzen.
2. Sicherstellen, dass Server, `tempdb` und Installationsdatenbank die Collation `SQL_Latin1_General_CP1_CS_AS` verwenden.
3. `Code/Install/Install_All.sql` im SQLCMD-Modus ausführen oder mit `Code/Install/Build-StandaloneInstaller.ps1` einen eigenständigen Installer erzeugen.
4. Danach das Release-Gate gemäß `Documentation/Quality/Release_Gate_Runbook.md` ausführen.

Beispielaufrufe verwenden ausschließlich `[monitor].[Objektname]` und sind nicht mit einer Datenbank qualifiziert.

## Dokumentationsprüfung

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Die Strukturprüfung ersetzt keine manuelle fachliche und Datenschutzprüfung.

Die Version `1.1.0-special.9` ergänzt Verschlüsselungslebenszyklus und Wartungsoperationen. GitHub Actions installiert und testet denselben 13-Suite-Vertrag auf SQL Server 2019, 2022 und 2025; manuelle Feature-Positiv-, Grenzwert- und Lastfälle bleiben separat zu dokumentieren.

## Forschungs- und Inventareinstieg

- `Documentation/Architecture/Runtime_Data_and_Repository_Privacy.md`
- `Documentation/Architecture/Special_Case_Modules.md`
- `Documentation/Research/Special_Case_Gap_Analysis.md`
- `Documentation/Analysis_Guides/Authoring/Deep_Research_Analysis_Guides_Concept.md`
- `Documentation/Research/System_Source_Catalog.md`
- `Documentation/Quality/Performance_and_Risk_Assessment.md`
- `Metadata/Inventory/SystemSources.csv`
- `Metadata/Inventory/NonSystemDependencies.csv`
- `Metadata/Inventory/PermissionsAndFeatures.csv`
