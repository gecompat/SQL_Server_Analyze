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

## Ressourcenschutz und interne Berechtigungsschiene

Die interne Policy dient primär dazu, Benutzergruppen von ressourcenintensiven Analysepfaden ein- oder auszuschließen. Sie vergibt keine SQL-Server-Berechtigungen.

Empfohlene Leserichtung:

1. [`Architecture/Authorization_Architecture.md`](Architecture/Authorization_Architecture.md) – Zweck, Whitelistmodell, Kostenklassen und Entscheidungsfluss
2. [`Operations/Authorization_Administration.md`](Operations/Authorization_Administration.md) – Policy aktivieren, pflegen, prüfen und zurücksetzen
3. [`Reference/Authorization_Policy_Examples.md`](Reference/Authorization_Policy_Examples.md) – synthetische Policyvarianten
4. [`Reference/Authorization_Status_and_Access_Reasons.md`](Reference/Authorization_Status_and_Access_Reasons.md) – `DENIED_GROUP`, `DENIED_PERMISSION` und `AccessReason`
5. [`Operations/Authorization_Troubleshooting.md`](Operations/Authorization_Troubleshooting.md) – Fehlersuche
6. [`Development/Integrating_New_Module_Authorization.md`](Development/Integrating_New_Module_Authorization.md) – neue ressourcenintensive Pfade integrieren
7. [`../Code/Examples/050_Authorization_Examples.sql`](../Code/Examples/050_Authorization_Examples.sql) – ausführbare Diagnose- und Policybeispiele

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

Die Version `1.1.0-special.9` ergänzt Verschlüsselungslebenszyklus und Wartungsoperationen. Der Release-Gate-Vertrag umfasst nun 19 Suiten; P0, P1-IQP, P1-Contention, P1-Speicher und P1-Backupketten besitzen commitbezogene Drei-Versionen-Evidenz. Der neue vollständig rücksetzbare P1-Schemavertrag wartet auf commitbezogene Actions.

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
