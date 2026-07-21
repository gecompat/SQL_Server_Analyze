# Execution-Plan-Analyse – Teilinstaller- und Integrationsvertrag

**Stand:** 2026-07-21  
**Status:** `IMPLEMENTED_PENDING_RELEASE_GATE`  
**Zugehörige Architektur:** [`Execution_Plan_Analysis_Design.md`](Execution_Plan_Analysis_Design.md)

> Dieser Vertrag beschreibt, wie die geplante Execution-Plan-Analyse eigenständig installiert und zugleich vollständig in das Gesamtframework integriert wird. Er legt noch keinen lauffähigen Installer an, bevor die referenzierten Objekte implementiert sind. Ein absichtlich fehlschlagender oder unvollständiger Installer-Stub ist nicht zulässig.

## 1. Ziel

Die Implementierung erhält einen eigenständigen Installer:

```text
Code/Install/Install_ExecutionPlanAnalysis.sql
```

Der Teilinstaller installiert ausschließlich:

- die eigenständige Execution-Plan-Analyse;
- den Evidenz-JSON-Erzeuger;
- die XML- und Meldungsparser;
- die Metadaten- und Regelobjekte dieses Analysebereichs;
- die tatsächlich benötigten gemeinsamen Frameworkobjekte aus der transitiven Abhängigkeitsschließung.

Er installiert nicht das vollständige Monitoringframework.

Der Gesamtinstaller:

```text
Code/Install/Install_All.sql
```

installiert dieselben Objekte in derselben Reihenfolge und anschließend die übrigen Frameworkmodule sowie die Plan-Cache-, Query-Store- und Current-State-Integrationen.

## 2. Installationsszenarien

### 2.1 Nur Standalone-Execution-Plan-Analyse

```text
Install_ExecutionPlanAnalysis.sql
```

Nach erfolgreicher Installation müssen mindestens verfügbar sein:

```text
monitor.USP_ExecutionPlanAnalysis
monitor.USP_CreateExecutionEvidenceJson
```

Der direkte Aufruf mit `@PlanXml` und optionalem `@EvidenzJson` funktioniert ohne Plan-Cache-, Query-Store-, Agent-, Extended-Events-, Infrastructure- oder Server-Health-Module.

### 2.2 Vollständiges Framework

```text
Install_All.sql
```

Der Gesamtinstaller installiert zunächst die gemeinsam benötigte Infrastruktur und die Execution-Plan-Kernobjekte. Danach folgen unter anderem:

```text
monitor.USP_ShowplanAnalysis
monitor.USP_PlanCacheAnalysis
monitor.USP_PlanDetails
monitor.USP_IntelligentQueryProcessingAnalysis
```

Diese Integrationsobjekte verwenden den bereits installierten Kern und implementieren keine zweite abweichende Planinterpretation.

### 2.3 Teilinstaller nach vollständiger Installation

Der Teilinstaller muss idempotent sein. Eine erneute Ausführung:

- verwendet `CREATE OR ALTER` für Procedures und Functions;
- verwendet `IF NOT EXISTS` und kontrollierte Schemaerweiterungen für Tabellen;
- entfernt keine Daten;
- setzt keine lokalen Profilzuordnungen zurück;
- überschreibt keine kundenspezifischen beziehungsweise umgebungsspezifischen Regelwerte;
- führt kein Downgrade gemeinsamer Frameworkobjekte durch.

## 3. Scopegrenze des Teilinstallers

### 3.1 Enthalten

#### Gemeinsame Mindestinfrastruktur

Die konkrete Dateiliste wird in Welle 0 aus echten SQL-Abhängigkeiten erzeugt. Inhaltlich sind mindestens folgende Fähigkeiten notwendig:

```text
Schema [monitor]
Ausgabevalidierung für RAW, CONSOLE, TABLE, NONE und JSON
benannte TABLE-Ziele
kontrollierte Console-Ausgabe
Status- und Fehlervertrag
High-Impact- und interne Berechtigungsprüfung für aktive Deep-Pfade
zentrale Pattern- und Listenparser, soweit öffentliche Parameter sie verwenden
kontrollierte Datenbankkandidatenbildung für bestätigte CURRENT_SERVER-Anreicherung
```

Gemeinsame Objekte werden nicht dupliziert oder mit einem zweiten plananalysespezifischen Output- oder Berechtigungssystem nachgebaut.

#### Neue Standalone-Kernobjekte

```text
monitor.PlanAnalysisProfile
monitor.PlanAnalysisRuleThreshold
monitor.PlanAnalysisProfileAssignment
monitor.TVF_ParseStatisticsIoText
monitor.TVF_ParseStatisticsTimeText
monitor.TVF_ExecutionPlanObjectReferences
monitor.TVF_ExecutionPlanStatisticsUsage
monitor.TVF_ExecutionPlanColumnReferences
monitor.InternalCollectExecutionPlanMetadata
monitor.InternalAnalyzeExecutionPlan
monitor.USP_CreateExecutionEvidenceJson
monitor.USP_ExecutionPlanAnalysis
```

#### Frameworkmetadaten

Der Teilinstaller installiert beziehungsweise aktualisiert die für seine Objekte erforderlichen Framework-Metadaten nur dann als Datenbankobjekte, wenn die spätere Implementierung solche Laufzeitmetadaten tatsächlich verwendet. Repositoryinventare wie CSV-Dateien sind kein SQL-Installationsbestandteil.

### 3.2 Nicht enthalten

```text
monitor.USP_ShowplanAnalysis
monitor.USP_PlanCacheAnalysis
monitor.USP_PlanDetails
monitor.USP_QueryStats
monitor.USP_QueryHashAnalysis
monitor.USP_PlanCacheHealth
Query-Store-Analysefamilie
Current-State-Analysefamilie
Extended-Events-Analysefamilie
Infrastructure- und Server-Health-Module
GitHub-Actions- oder Client-Collector-Komponenten
```

Begründung: Diese Objekte sind Integrations- oder Beschaffungspfade. Der Standalone-Kern benötigt sie für die direkte Analyse eines übergebenen Plan-XML nicht.

## 4. Optionale Anreicherungen im Teilinstaller

`USP_ExecutionPlanAnalysis` und `USP_CreateExecutionEvidenceJson` dürfen optionale CURRENT_SERVER-Anreicherung anbieten, ohne weitere öffentliche Analysefamilien zu installieren. Dafür sind nur die direkt benötigten gemeinsamen Helper und Systemkatalogzugriffe zulässig.

Optional bleiben:

```text
aktuelle Objekt- und Indexmetadaten
aktuelle Statistics Properties
Histogramm SUMMARY oder STEPS
Planhandle COMPILE beziehungsweise LAST_ACTUAL
Live-Plan einer expliziten Session
```

Query-Store-Planbeschaffung oder detailliertes Query-Store-Feedback gehört standardmäßig nicht zum Teilinstaller, sofern die Abhängigkeitsschließung dadurch die gesamte Query-Store-Familie installieren müsste. Der Standalone-Pfad kann Query-Store-Evidenz stattdessen über `@EvidenzJson` übernehmen.

## 5. Installationsreihenfolge

Die verbindliche logische Reihenfolge lautet:

```text
01  Schema und grundlegende gemeinsame Datentyp-/Outputvoraussetzungen
02  gemeinsame Parser- und Validierungshelper
03  gemeinsame Berechtigungs- und High-Impact-Helper
04  gemeinsame TABLE-/CONSOLE-/JSON-Helper
05  PlanAnalysisProfile
06  PlanAnalysisRuleThreshold
07  PlanAnalysisProfileAssignment
08  TVF_ParseStatisticsIoText
09  TVF_ParseStatisticsTimeText
10  TVF_ExecutionPlanObjectReferences
11  TVF_ExecutionPlanStatisticsUsage
12  TVF_ExecutionPlanColumnReferences
13  InternalCollectExecutionPlanMetadata
14  InternalAnalyzeExecutionPlan
15  USP_CreateExecutionEvidenceJson
16  USP_ExecutionPlanAnalysis
17  Teilinstaller-Smoke-Test beziehungsweise post-install validation
```

Der spätere `Install_All.sql` setzt danach fort mit:

```text
18  USP_ShowplanAnalysis
19  USP_PlanCacheAnalysis und weitere Plan-Cache-Integrationen
20  Query-Store-/IQP-Integrationen
21  übrige Frameworkmodule
```

Die konkreten Dateinummern dürfen sich an die tatsächliche Repositoryordnung anpassen. Die fachliche Abhängigkeitsreihenfolge bleibt verbindlich.

## 6. Geplante Repositorydateien

### 6.1 Kerncode

Die genaue Nummerierung wird in Welle 0 gegen die dann aktuelle Verzeichnisbelegung geprüft. Der aktuelle Arbeitsvorschlag lautet:

```text
Code/04_PlanCache/041_TVF_ParseStatisticsIoText.sql
Code/04_PlanCache/042_TVF_ParseStatisticsTimeText.sql
Code/04_PlanCache/043_PlanAnalysisProfile.sql
Code/04_PlanCache/044_PlanAnalysisRuleThreshold.sql
Code/04_PlanCache/045_PlanAnalysisProfileAssignment.sql
Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql
Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql
Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql
Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql
Code/04_PlanCache/050_InternalAnalyzeExecutionPlan.sql
Code/04_PlanCache/051_USP_CreateExecutionEvidenceJson.sql
Code/04_PlanCache/052_USP_ExecutionPlanAnalysis.sql
```

Da `050_USP_ShowplanAnalysis.sql` bereits existiert, muss die finale Nummerierung vor Implementierungsbeginn konfliktfrei neu festgelegt werden. Die Nummern in diesem Abschnitt sind keine Freigabe zum Überschreiben bestehender Dateien.

### 6.2 Installer

```text
Code/Install/Install_ExecutionPlanAnalysis.sql
Code/Install/Install_All.sql
```

### 6.3 Tests

```text
Code/Tests/PlanCache/ExecutionPlanAnalysis_Standalone.sql
Code/Tests/PlanCache/ExecutionEvidence_Contract.sql
Code/Tests/PlanCache/ExecutionPlanAnalysis_Privacy.sql
Code/Tests/Integration/ExecutionPlanAnalysis_FrameworkIntegration.sql
```

Die finale Nummerierung wird mit dem vorhandenen Release-Gate-Schema abgestimmt.

## 7. Generierung statt manueller Doppelpflege

Der Teilinstaller und der Gesamtinstaller dürfen dieselben Objekttexte nicht manuell in zwei voneinander unabhängigen Fassungen pflegen.

Zulässige Modelle:

1. SQLCMD-Includes aus derselben kanonischen Dateiliste;
2. ein vorhandener Installer-Generator erzeugt beide Installer aus getrennten Manifesten;
3. der eigenständige, auslieferbare Installer wird deterministisch aus dem Teilmanifest gebaut, während `Install_All.sql` das Gesamtmanifest verwendet.

Nicht zulässig:

- Kopieren und getrenntes manuelles Nachpflegen vollständiger Objektdefinitionen;
- abweichende Objektversionen in Teil- und Gesamtinstaller;
- ein Teilinstaller, der intern ungeprüft `Install_All.sql` ausführt;
- ein Gesamtinstaller, der einen veralteten eingebetteten Teilinstaller enthält.

## 8. Dependency-Manifest

Vor Welle 1 wird ein maschinenlesbares Manifest angelegt. Vorgesehene Felder:

```text
InstallOrdinal
ObjectType
ObjectName
SourcePath
DependencyClass
StandaloneRequired
FrameworkIntegrationRequired
OptionalFeature
MinimumSqlServerMajorVersion
MinimumCompatibilityLevel
Notes
```

`DependencyClass`:

```text
COMMON_REQUIRED
PLAN_ANALYSIS_CORE
PLAN_ANALYSIS_OPTIONAL
FRAMEWORK_INTEGRATION_ONLY
TEST_ONLY
```

Das Manifest ist die Quelle für:

- Teilinstaller;
- Einbindung in den Gesamtinstaller;
- Installationsreihenfolgetests;
- Prüfung, dass der Teilinstaller keine unzulässigen Analysefamilien installiert.

## 9. Steuertabellen und Seedverhalten

### 9.1 Frameworkdefaults

Repository-Seeds dürfen ausschließlich generische Defaultprofile und Regelschwellen enthalten:

```text
LATENCY_SENSITIVE
BALANCED
THROUGHPUT
MAINTENANCE
UNKNOWN
```

Alle Werte müssen als Frameworkheuristiken dokumentiert werden.

### 9.2 Lokale Anpassungen

Eine erneute Installation:

- ergänzt fehlende Frameworkdefaults;
- aktualisiert Frameworkdefaults nur über eine explizit dokumentierte Seedversion;
- löscht keine lokalen Zeilen;
- überschreibt keine Zeilen mit `IsFrameworkDefault = 0`;
- speichert keine realen Datenbank-, Objekt-, Benutzer- oder Unternehmensbezeichner im Repositoryseed.

## 10. Datenschutz im Installer

Der Installer enthält keine:

- echten Pläne;
- Histogrammgrenzwerte;
- Parameter- oder Literalwerte;
- `STATISTICS IO`-/`TIME`-Ausgaben aus realen Umgebungen;
- realen Datenbank-, Schema-, Tabellen-, Index-, Statistik-, Benutzer-, Server- oder Programmnamen;
- Logs, Ausführungspläne oder Screenshots mit internen Informationen.

Tests verwenden synthetische `Example*`-Bezeichner und selbst erzeugte rücksetzbare Datenverteilungen.

## 11. Berechtigungen

Der Teilinstaller vergibt keine Analyseberechtigungen an Benutzer oder Gruppen. Er installiert nur die Frameworkobjekte.

Die Laufzeitobjekte:

- prüfen die tatsächlich benötigte Server- beziehungsweise Datenbankberechtigung;
- nennen die erforderliche Berechtigung im Status;
- verwenden die vorhandene interne Ressourcenfreigabe für Deep-Pfade;
- ändern keine Server- oder Datenbankkonfiguration;
- aktivieren keine Profiling- oder Query-Store-Funktion.

## 12. Idempotenz und Upgradefähigkeit

### 12.1 Procedures und Functions

```text
CREATE OR ALTER
```

### 12.2 Tabellen

- `IF NOT EXISTS` für Ersterstellung;
- additive Migrationen nur kontrolliert und versioniert;
- keine destruktive Rekonstruktion bei vorhandenen lokalen Daten;
- Constraints und Indizes einzeln prüfen;
- Seedversion ausweisen.

### 12.3 Resultset- und JSON-Schema

- Resultset-Schemaversionen im Repositoryinventar;
- Evidenz-JSON mit eigener `schemaVersion`;
- unbekannte zusätzliche JSON-Properties tolerieren;
- nicht unterstützte ältere oder neuere Schemaversionen kontrolliert melden;
- kein stillschweigendes Umdeuten.

## 13. Post-Install-Validierung

Der Teilinstaller endet mit einer leichten Validierung, die keine realen Pläne oder Benutzerdaten benötigt.

Mindestens zu prüfen:

```text
alle erforderlichen Objekte vorhanden
keine verbotenen Integrationsfamilien durch Teilinstaller installiert
öffentliche Signaturen verfügbar
@Hilfe=1 erfolgreich
synthetischer Minimalplan analysierbar
Evidenz-JSON mit leerer beziehungsweise synthetischer Evidenz validierbar
TABLE-Zielpreflight funktionsfähig
kein High-Impact-Zugriff im Smoke-Test
```

Der Teilinstaller führt keine vollständigen Deep-Tests aus.

## 14. Release-Gate

Die vollständige Implementierung muss bestehen:

```text
SQL Server 2019
SQL Server 2022
SQL Server 2025
```

Zusätzlich:

- Teilinstaller aus leerer Datenbank;
- Teilinstaller nach vollständigem Framework;
- Teilinstaller zweimal hintereinander;
- Gesamtinstaller aus leerer Datenbank;
- Vergleich der Kernobjektdefinitionen aus Teil- und Gesamtinstallation;
- Privacy-Tests für Histogramm-, Parameter- und Predicatewerte;
- Prüfung der installierten Objektmenge gegen das Dependency-Manifest.

## 15. Abnahmekriterien

Der Teilinstaller ist fertig, wenn:

1. `USP_ExecutionPlanAnalysis` einen synthetischen Plan direkt analysiert;
2. `USP_CreateExecutionEvidenceJson` synthetische Evidenz erzeugt und normalisiert;
3. kein Plan-Cache-, Query-Store- oder anderes Analysefamilienobjekt für den direkten Standalone-Aufruf benötigt wird;
4. aktive CURRENT_SERVER-Deep-Pfade kontrolliert gegated sind;
5. Teil- und Gesamtinstaller dieselben Kernobjektversionen installieren;
6. eine Wiederholung keine lokalen Regeln oder Zuordnungen zerstört;
7. SQL Server 2019, 2022 und 2025 nicht verfügbare Features kontrolliert als Capability-Status ausgeben;
8. keine realen oder potenziell sensiblen Werte in Repositoryartefakten enthalten sind.

## 16. Implementierungsentscheidung

Der Teilinstaller wird erst angelegt, wenn mindestens Welle 0 abgeschlossen und die erste vollständige transitive Abhängigkeitsschließung bestimmt ist. Bis dahin ist dieser Vertrag die verbindliche Spezifikation. Dadurch entsteht kein scheinbar installierbares, tatsächlich aber unvollständiges Script.
