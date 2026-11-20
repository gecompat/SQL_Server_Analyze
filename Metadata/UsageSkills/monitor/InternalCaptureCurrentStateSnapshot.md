---
skill_format_version: "1.0.0"
name: "monitor.InternalCaptureCurrentStateSnapshot"
schema_name: "monitor"
object_name: "InternalCaptureCurrentStateSnapshot"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen."
source_path: "Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql"
---

# monitor.InternalCaptureCurrentStateSnapshot

## Zweck und Einsatz

Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht angefordert. SQL25-003 erweitert die Workload-Group-Erfassung versions- und capability-adaptiv.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalCaptureCurrentStateSnapshot]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[dm_exec_sessions]`, `sys.dm_exec_sessions`, `[sys].[dm_tran_version_store_space_usage]`, `sys.dm_tran_version_store_space_usage`, `[sys].[dm_tran_persistent_version_store_stats]`, `sys.dm_tran_persistent_version_store_stats`, `[sys].[dm_exec_requests]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SnapshotId | uniqueidentifier | ja | kein Default |
| @CaptureSessions | bit | nein | 0 |
| @CaptureRequests | bit | nein | 0 |
| @CaptureConnections | bit | nein | 0 |
| @CaptureWaitingTasks | bit | nein | 0 |
| @CaptureMemoryGrants | bit | nein | 0 |
| @CaptureResourceGovernor | bit | nein | 0 |
| @CaptureTasks | bit | nein | 0 |
| @CaptureSchedulers | bit | nein | 0 |
| @CaptureTransactions | bit | nein | 0 |
| @CaptureTempDbUsage | bit | nein | 0 |
| @CaptureVersionStore | bit | nein | 0 |
| @CaptureSqlText | bit | nein | 0 |
| @MaxSqlTextHandles | int | nein | 1000 |
| @Hilfe | bit | nein | 0 |

**@SnapshotId:** @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet gemäß Konvention eine frische ID. Eine im aktuellen Context bereits vorhandene ID wird als Duplikat abgelehnt.

**@CaptureSessions:** @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.

**@CaptureRequests:** @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.

**@CaptureConnections:** @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst Connections.

**@CaptureWaitingTasks:** @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende Tasks.

**@CaptureMemoryGrants:** @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores aus; 1 erfasst beide Quellen.

**@CaptureResourceGovernor:** @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst Workload Groups, Resource Pools und versions- und quellenabhängige TempDB-Governance-Daten.

**@CaptureTasks:** @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits erfassten Requests.

**@CaptureSchedulers:** @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu IDs bereits erfasster Requests oder Tasks.

**@CaptureTransactions:** @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.

**@CaptureTempDbUsage:** @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits erfassten Requests.

**@CaptureVersionStore:** @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst traditionellen und persistenten Version Store innerhalb des Sessions-Zweigs.

**@CaptureSqlText:** @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu Handles bereits erfasster Requests und Connections. Diese Quellen werden nicht automatisch aktiviert.

**@MaxSqlTextHandles:** @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar; Default: 1000; NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen Handles. Validierung auch bei @CaptureSqlText=0. Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt; TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus vorkommen.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein eigenes Fach-Resultset und keine OUTPUT-Parameter. Die Procedure schreibt Context-, SourceStatus- und die ausgewählten CurrentState-Gruppen in die bereits vom öffentlichen CurrentOverview vorbereiteten lokalen #Ziele, jeweils unter derselben SnapshotId. Quellenfehler werden gruppenweise als Status/Fehler in SourceStatus erfasst; die resultierenden Temp-Inhalte sind keine atomare Momentaufnahme aller DMVs.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalCaptureCurrentStateSnapshot';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalCaptureCurrentStateSnapshot] @SnapshotId=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalCaptureCurrentStateSnapshot
Version      : 2.1.0
Stand        : 2026-07-23
Typ          : Interne Stored Procedure
Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten
               DMV- und SQL-Textquellen einmalig in dessen lokalen
               Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht
               angefordert. SQL25-003 erweitert die Workload-Group-Erfassung
               versions- und capability-adaptiv.
Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und
               besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope
               des aufrufenden Orchestrators.
Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden
               mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert
               keine globale Atomarität der Quellenerfassung.
Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat
               keinen Default. Nur optionale Parameter können ausgelassen werden;
               dann gilt ihr jeweiliger Default. Die 

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalCaptureCurrentStateSnapshot
Version      : 2.1.0
Stand        : 2026-07-23
Typ          : Interne Stored Procedure
Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten
               DMV- und SQL-Textquellen einmalig in dessen lokalen
               Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht
               angefordert. SQL25-003 erweitert die Workload-Group-Erfassung
               versions- und capability-adaptiv.
Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und
               besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope
               des aufrufenden Orchestrators.
Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden
               mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert
               keine globale Atomarität der Quellenerfassung.
Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat
               keinen Default. Nur optionale Parameter können ausgelassen werden;
               dann gilt ihr jeweiliger Default. Die bit-Werte 0 und 1 gelten
               nach der SQL-Typkonvertierung. Andere konvertierbare Quellwerte
               sind nicht generell ausgeschlossen; ein numerischer Wert ungleich
               null wird beispielsweise zu bit 1.
               @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL
               wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier
               konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet
               gemäß Konvention eine frische ID. Eine im aktuellen Context bereits
               vorhandene ID wird als Duplikat abgelehnt.
               @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.
               @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.
               @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst
               Connections.
               @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende
               Tasks.
               @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores
               aus; 1 erfasst beide Quellen.
               @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird
               abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server
               konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst
               Workload Groups, Resource Pools und versions- und quellenabhängige
               TempDB-Governance-Daten.
               @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere
               Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor
               Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits
               erfassten Requests.
               @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu
               IDs bereits erfasster Requests oder Tasks.
               @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst
               Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.
               @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst
               Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits
               erfassten Requests.
               @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst
               traditionellen und persistenten Version Store innerhalb des
               Sessions-Zweigs.
               @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
               vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu
               Handles bereits erfasster Requests und Connections. Diese Quellen werden
               nicht automatisch aktiviert.
               @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar;
               Default: 1000;
               NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind
               keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt
               in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt
               deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen
               Handles. Validierung auch bei @CaptureSqlText=0.
Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die
               vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren
               Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der
               Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt;
               TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus
               vorkommen.
```

