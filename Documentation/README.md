# SQL Server Analyze – Projektübersicht

Dieses Repository enthält ein T-SQL-basiertes Diagnoseframework für SQL Server ab Version 2019.

## Verzeichnisse

- `Code/`: installierbarer T-SQL-Code, Installer, Tests und Beispielaufrufe
- `Documentation/`: Anforderungen, Architektur, Betrieb, Referenz und Recherche
- `Metadata/`: maschinenlesbare Objekt-, Parameter-, Systemquellen-, Abhängigkeits- und Capability-Inventare sowie Qualitätsergebnisse
- `AI_Metadata/`: kompakter Kontext zur Fortsetzung der KI-gestützten Entwicklung

## Installation

1. In allen SQL-Skripten den Platzhalter `[DeineDatenbank]` durch die gewünschte Installationsdatenbank ersetzen.
2. Sicherstellen, dass Server, `tempdb` und Installationsdatenbank die Collation `SQL_Latin1_General_CP1_CS_AS` verwenden.
3. `Code/Install/Install_All.sql` im SQLCMD-Modus ausführen oder zuvor mit `Code/Install/Build-StandaloneInstaller.ps1` einen eigenständigen Installer erzeugen.
4. Nach `Documentation/Quality/Release_Gate_Runbook.md` aus `Code/Tests` den SQLCMD-Runner `Run_Release_Gate.sql` ausführen; er prüft vier Integrationsverträge und acht Bereichs-Smoke-Tests.

Beispielaufrufe verwenden ausschließlich `[monitor].[Objektname]` und sind nicht mit einer Datenbank qualifiziert.

Der Basisstand vor der Spezialfallwelle wurde nach Angabe des Projektverantwortlichen real getestet. Die neue Version `1.1.0-special.5` einschließlich Spezialfeature-Nutzungsinventur sowie In-Memory-OLTP- und Temporal-Tables-Tiefenanalyse besitzt statische Verträge; reale Zielmatrixläufe sind noch zu dokumentieren.

## Forschungs- und Inventareinstieg

- `Documentation/Architecture/Runtime_Data_and_Repository_Privacy.md`
- `Documentation/Architecture/Special_Case_Modules.md`
- `Documentation/Research/Special_Case_Gap_Analysis.md`
- `Metadata/Quality/Special_Case_Gap_Backlog.csv`
- `Metadata/Quality/Special_Case_Release_Audit.json`
- `Documentation/Research/System_Source_Catalog.md`
- `Documentation/Quality/Performance_and_Risk_Assessment.md`
- `Metadata/Inventory/SystemSources.csv`
- `Metadata/Inventory/NonSystemDependencies.csv`
- `Metadata/Inventory/PermissionsAndFeatures.csv`
