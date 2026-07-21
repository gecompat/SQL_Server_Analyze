# SQL Server Analyze – Projektübersicht

Dieses Repository enthält ein T-SQL-basiertes Diagnoseframework für SQL Server ab Version 2019.

## Verzeichnisse

- `Code/`: installierbarer T-SQL-Code, Installer, Tests und Beispielaufrufe
- `Documentation/`: Anforderungen, Architektur, Betrieb, Referenz, Analysehandbuch und Recherche
- `Metadata/`: maschinenlesbare Inventare und Qualitätsergebnisse
- `AI_Metadata/`: kompakter Kontext zur Fortsetzung der Entwicklung

## Analysehandbuch

Für praktische Analysen nicht im Forschungsdokument beginnen:

1. [`Analysis_Guides/Beginner_Reading_Guide.md`](Analysis_Guides/Beginner_Reading_Guide.md) – Einstieg und feste Leserichtung
2. [`Analysis_Guides/Runbooks/README.md`](Analysis_Guides/Runbooks/README.md) – Einstieg nach Symptom
3. [`Analysis_Guides/Procedures/README.md`](Analysis_Guides/Procedures/README.md) – eigenständige Seiten für alle 93 Procedures
4. [`Analysis_Guides/Glossary.md`](Analysis_Guides/Glossary.md) – technische Begriffe
5. [`Analysis_Guides/Parameter_Reading_Guide.md`](Analysis_Guides/Parameter_Reading_Guide.md) – Parameter und sichere Aufrufe
6. [`Analysis_Guides/README.md`](Analysis_Guides/README.md) – Gesamtübersicht und Familienguides
7. [`Reference/Object_Reference.md`](Reference/Object_Reference.md) – Direktnavigation und Detailabschnitte mit Aufgabe, Schnittstelle, Verwendung, Last-/Sperrverhalten und Stabilitätsgrenze für jede installierte View, TVF, interne Procedure und Tabelle; derzeit sind keine SVFs installiert

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

Die vollständige [Schritt-für-Schritt-Anleitung für SSMS](Reference/Installation.md)
führt durch Download, Versions- und Collationprüfung, Datenbankanlage,
Installerzeugung, Installation, Smoke-Test, Berechtigungsprüfung und ersten
Analyseaufruf. Für SSMS wird der eigenständige Installer empfohlen; der
SQLCMD-Include-Weg bleibt als Alternative dokumentiert.

Beispielaufrufe verwenden ausschließlich `[monitor].[Objektname]` und sind nicht mit einer Datenbank qualifiziert.

## Dokumentationsprüfung

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Die Strukturprüfung ersetzt keine manuelle fachliche und Datenschutzprüfung.

Der Ausgabe-Vertrag 2.0 verarbeitet standardmäßig alle sichtbaren Online-
Benutzerdatenbanken, trennt die menschliche CONSOLE-Darstellung von RAW und
verwendet für TABLE ausschließlich semantisch benannte Ziele in
`@ResultTablesJson`. Die vollständigen nativen Schemas stehen im
Resultsetinventar.

Die [Tool-Hintergrundabfragen- und Blocking-Ketten-Architektur](Architecture/Tool_Background_Query_Filtering.md)
beschreibt den standardmäßigen Filter für Object Explorer, Copilot und SQL
Prompt, seine metadatengetriebenen `LIKE`-Regeln sowie die Grenzen der
clientseitigen `program_name`-Erkennung.

## Vollständiger Bereichsindex

Die folgenden Einstiege ergänzen das Analysehandbuch. Procedure-Einzelseiten und
Runbooks sind über ihre jeweiligen `README.md`-Dateien verlinkt.

### Anforderungen und Architektur

- [`Requirements/Requirements_and_Decisions.md`](Requirements/Requirements_and_Decisions.md)
- [`Architecture/Authorization_Architecture.md`](Architecture/Authorization_Architecture.md)
- [`Architecture/Database_Console_Table_Contract.md`](Architecture/Database_Console_Table_Contract.md)
- [`Architecture/Diagnostic_Information_Enrichment_Backlog.md`](Architecture/Diagnostic_Information_Enrichment_Backlog.md)
- [`Architecture/Execution_Plan_Analysis_Design.md`](Architecture/Execution_Plan_Analysis_Design.md) – Standalone-, Evidenz-, Statistik-, Histogramm-, Regel- und Versionsvertrag für `PLAN-001`
- [`Architecture/Execution_Plan_Analysis_Installation_Contract.md`](Architecture/Execution_Plan_Analysis_Installation_Contract.md) – minimaler Teilinstaller und Einbindung in `Install_All.sql`
- [`Architecture/Filter_Lists_and_Patterns.md`](Architecture/Filter_Lists_and_Patterns.md)
- [`Architecture/Fleet_Correlation_Contract.md`](Architecture/Fleet_Correlation_Contract.md)
- [`Architecture/Memory_Grants_and_Resource_Governor.md`](Architecture/Memory_Grants_and_Resource_Governor.md)
- [`Architecture/Operational_Diagnostic_Gap_Backlog.md`](Architecture/Operational_Diagnostic_Gap_Backlog.md)
- [`Architecture/Output_RAW_CONSOLE_JSON.md`](Architecture/Output_RAW_CONSOLE_JSON.md)
- [`Architecture/Parameter_API.md`](Architecture/Parameter_API.md)
- [`Architecture/Row_Limits.md`](Architecture/Row_Limits.md)
- [`Architecture/Runtime_Data_and_Repository_Privacy.md`](Architecture/Runtime_Data_and_Repository_Privacy.md)
- [`Architecture/SQL_Text_Statement_Batch_Module.md`](Architecture/SQL_Text_Statement_Batch_Module.md)
- [`Architecture/Snapshot_Baseline_Package_Contract.md`](Architecture/Snapshot_Baseline_Package_Contract.md)
- [`Architecture/Special_Case_Modules.md`](Architecture/Special_Case_Modules.md)
- [`Architecture/Tool_Background_Query_Filtering.md`](Architecture/Tool_Background_Query_Filtering.md)

### Betrieb

- [`Operations/Authorization_Administration.md`](Operations/Authorization_Administration.md)
- [`Operations/Authorization_Troubleshooting.md`](Operations/Authorization_Troubleshooting.md)
- [`Operations/Snapshot_Baseline_Operations.md`](Operations/Snapshot_Baseline_Operations.md)
- [`Operations/Version_Adaptive_Features.md`](Operations/Version_Adaptive_Features.md)
- [`Operations/Wait_Stats_Methodology.md`](Operations/Wait_Stats_Methodology.md)
- [`Operations/Wait_Type_Catalog.md`](Operations/Wait_Type_Catalog.md)

### Referenz

- [`Reference/Authorization_Policy_Examples.md`](Reference/Authorization_Policy_Examples.md)
- [`Reference/Authorization_Status_and_Access_Reasons.md`](Reference/Authorization_Status_and_Access_Reasons.md)
- [`Reference/Call_Catalog.md`](Reference/Call_Catalog.md)
- [`Reference/Installation.md`](Reference/Installation.md)
- [`Reference/Object_Reference.md`](Reference/Object_Reference.md)
- [`Reference/Procedure_Reference.md`](Reference/Procedure_Reference.md)
- [`Reference/Resultset_Conventions.md`](Reference/Resultset_Conventions.md)
- [`Reference/Scenarios.md`](Reference/Scenarios.md)

### Qualität und Release

- [`Quality/Analysis_Documentation_Validation.md`](Quality/Analysis_Documentation_Validation.md)
- [`Quality/Commit_Message_Validation.md`](Quality/Commit_Message_Validation.md)
- [`Quality/External_Restore_Host_Proof_Runbook.md`](Quality/External_Restore_Host_Proof_Runbook.md)
- [`Quality/Known_Issues.md`](Quality/Known_Issues.md)
- [`Quality/Next_Steps.md`](Quality/Next_Steps.md)
- [`Quality/Performance_and_Risk_Assessment.md`](Quality/Performance_and_Risk_Assessment.md)
- [`Quality/Release_Gate_Runbook.md`](Quality/Release_Gate_Runbook.md)
- [`Quality/Release_Notes.md`](Quality/Release_Notes.md)
- [`Quality/Repository_Privacy_Validation.md`](Quality/Repository_Privacy_Validation.md)
- [`Quality/SQL_Server_2025_Regex_Gate.md`](Quality/SQL_Server_2025_Regex_Gate.md)
- [`Quality/Test_Matrix.md`](Quality/Test_Matrix.md)
- [`Quality/Wait_Type_Curation.md`](Quality/Wait_Type_Curation.md)

### Forschung

- [`Research/Extended_Events.md`](Research/Extended_Events.md)
- [`Research/Legacy_Analysis_Results.md`](Research/Legacy_Analysis_Results.md)
- [`Research/Plan_Cache_and_Showplan.md`](Research/Plan_Cache_and_Showplan.md)
- [`Research/Query_Store.md`](Research/Query_Store.md)
- [`Research/Sources.md`](Research/Sources.md)
- [`Research/Special_Case_Gap_Analysis.md`](Research/Special_Case_Gap_Analysis.md)
- [`Research/System_Source_Catalog.md`](Research/System_Source_Catalog.md)

### Entwicklung und Redaktion

- [`Development/Integrating_New_Module_Authorization.md`](Development/Integrating_New_Module_Authorization.md)
- [`Analysis_Guides/Deep_Research_Analysis_Guides_Concept.md`](Analysis_Guides/Deep_Research_Analysis_Guides_Concept.md)
- [`Analysis_Guides/Authoring/Deep_Research_Analysis_Guides_Concept.md`](Analysis_Guides/Authoring/Deep_Research_Analysis_Guides_Concept.md)
- [`Analysis_Guides/Authoring/Deep_Analysis_Draft_Index.md`](Analysis_Guides/Authoring/Deep_Analysis_Draft_Index.md)
- [`Analysis_Guides/Authoring/Procedure_Page_Template.md`](Analysis_Guides/Authoring/Procedure_Page_Template.md)

### Maschinenlesbare Inventare und Verträge

- [`Metadata/Quality/ExecutionPlanAnalysis_Public_Contract.json`](../Metadata/Quality/ExecutionPlanAnalysis_Public_Contract.json) – eingefrorener V1-Vertrag für `PLAN-001`
- [`Metadata/Inventory/SystemSources.csv`](../Metadata/Inventory/SystemSources.csv)
- [`Metadata/Inventory/NonSystemDependencies.csv`](../Metadata/Inventory/NonSystemDependencies.csv)
- [`Metadata/Inventory/PermissionsAndFeatures.csv`](../Metadata/Inventory/PermissionsAndFeatures.csv)
- [`Metadata/Inventory/ResultSets.csv`](../Metadata/Inventory/ResultSets.csv)
- [`Metadata/Quality/Future_Enhancement_Backlog.csv`](../Metadata/Quality/Future_Enhancement_Backlog.csv)
