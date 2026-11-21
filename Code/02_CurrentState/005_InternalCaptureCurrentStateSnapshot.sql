USE [DeineDatenbank];
GO

/*
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
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalCaptureCurrentStateSnapshot 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalCaptureCurrentStateSnapshot"
-- schema_name: "monitor"
-- object_name: "InternalCaptureCurrentStateSnapshot"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen."
-- source_path: "Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql"
-- ---
-- 
-- # monitor.InternalCaptureCurrentStateSnapshot
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht angefordert. SQL25-003 erweitert die Workload-Group-Erfassung versions- und capability-adaptiv.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalCaptureCurrentStateSnapshot]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[dm_exec_sessions]`, `sys.dm_exec_sessions`, `[sys].[dm_tran_version_store_space_usage]`, `sys.dm_tran_version_store_space_usage`, `[sys].[dm_tran_persistent_version_store_stats]`, `sys.dm_tran_persistent_version_store_stats`, `[sys].[dm_exec_requests]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SnapshotId | uniqueidentifier | ja | kein Default |
-- | @CaptureSessions | bit | nein | 0 |
-- | @CaptureRequests | bit | nein | 0 |
-- | @CaptureConnections | bit | nein | 0 |
-- | @CaptureWaitingTasks | bit | nein | 0 |
-- | @CaptureMemoryGrants | bit | nein | 0 |
-- | @CaptureResourceGovernor | bit | nein | 0 |
-- | @CaptureTasks | bit | nein | 0 |
-- | @CaptureSchedulers | bit | nein | 0 |
-- | @CaptureTransactions | bit | nein | 0 |
-- | @CaptureTempDbUsage | bit | nein | 0 |
-- | @CaptureVersionStore | bit | nein | 0 |
-- | @CaptureSqlText | bit | nein | 0 |
-- | @MaxSqlTextHandles | int | nein | 1000 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SnapshotId:** @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet gemäß Konvention eine frische ID. Eine im aktuellen Context bereits vorhandene ID wird als Duplikat abgelehnt.
-- 
-- **@CaptureSessions:** @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.
-- 
-- **@CaptureRequests:** @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.
-- 
-- **@CaptureConnections:** @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst Connections.
-- 
-- **@CaptureWaitingTasks:** @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende Tasks.
-- 
-- **@CaptureMemoryGrants:** @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores aus; 1 erfasst beide Quellen.
-- 
-- **@CaptureResourceGovernor:** @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst Workload Groups, Resource Pools und versions- und quellenabhängige TempDB-Governance-Daten.
-- 
-- **@CaptureTasks:** @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits erfassten Requests.
-- 
-- **@CaptureSchedulers:** @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu IDs bereits erfasster Requests oder Tasks.
-- 
-- **@CaptureTransactions:** @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.
-- 
-- **@CaptureTempDbUsage:** @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits erfassten Requests.
-- 
-- **@CaptureVersionStore:** @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst traditionellen und persistenten Version Store innerhalb des Sessions-Zweigs.
-- 
-- **@CaptureSqlText:** @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu Handles bereits erfasster Requests und Connections. Diese Quellen werden nicht automatisch aktiviert.
-- 
-- **@MaxSqlTextHandles:** @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar; Default: 1000; NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen Handles. Validierung auch bei @CaptureSqlText=0. Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt; TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus vorkommen.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein eigenes Fach-Resultset und keine OUTPUT-Parameter. Die Procedure schreibt Context-, SourceStatus- und die ausgewählten CurrentState-Gruppen in die bereits vom öffentlichen CurrentOverview vorbereiteten lokalen #Ziele, jeweils unter derselben SnapshotId. Quellenfehler werden gruppenweise als Status/Fehler in SourceStatus erfasst; die resultierenden Temp-Inhalte sind keine atomare Momentaufnahme aller DMVs.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalCaptureCurrentStateSnapshot';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalCaptureCurrentStateSnapshot] @SnapshotId=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- ===============================================================================
-- Objekt       : monitor.InternalCaptureCurrentStateSnapshot
-- Version      : 2.1.0
-- Stand        : 2026-07-23
-- Typ          : Interne Stored Procedure
-- Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten
--                DMV- und SQL-Textquellen einmalig in dessen lokalen
--                Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht
--                angefordert. SQL25-003 erweitert die Workload-Group-Erfassung
--                versions- und capability-adaptiv.
-- Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und
--                besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope
--                des aufrufenden Orchestrators.
-- Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden
--                mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert
--                keine globale Atomarität der Quellenerfassung.
-- Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat
--                keinen Default. Nur optionale Parameter können ausgelassen werden;
--                dann gilt ihr jeweiliger Default. Die 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalCaptureCurrentStateSnapshot
-- Version      : 2.1.0
-- Stand        : 2026-07-23
-- Typ          : Interne Stored Procedure
-- Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten
--                DMV- und SQL-Textquellen einmalig in dessen lokalen
--                Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht
--                angefordert. SQL25-003 erweitert die Workload-Group-Erfassung
--                versions- und capability-adaptiv.
-- Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und
--                besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope
--                des aufrufenden Orchestrators.
-- Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden
--                mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert
--                keine globale Atomarität der Quellenerfassung.
-- Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat
--                keinen Default. Nur optionale Parameter können ausgelassen werden;
--                dann gilt ihr jeweiliger Default. Die bit-Werte 0 und 1 gelten
--                nach der SQL-Typkonvertierung. Andere konvertierbare Quellwerte
--                sind nicht generell ausgeschlossen; ein numerischer Wert ungleich
--                null wird beispielsweise zu bit 1.
--                @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL
--                wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier
--                konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet
--                gemäß Konvention eine frische ID. Eine im aktuellen Context bereits
--                vorhandene ID wird als Duplikat abgelehnt.
--                @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.
--                @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.
--                @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst
--                Connections.
--                @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende
--                Tasks.
--                @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores
--                aus; 1 erfasst beide Quellen.
--                @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird
--                abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server
--                konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst
--                Workload Groups, Resource Pools und versions- und quellenabhängige
--                TempDB-Governance-Daten.
--                @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere
--                Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor
--                Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits
--                erfassten Requests.
--                @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu
--                IDs bereits erfasster Requests oder Tasks.
--                @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst
--                Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.
--                @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst
--                Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits
--                erfassten Requests.
--                @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst
--                traditionellen und persistenten Version Store innerhalb des
--                Sessions-Zweigs.
--                @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.
--                Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert
--                vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu
--                Handles bereits erfasster Requests und Connections. Diese Quellen werden
--                nicht automatisch aktiviert.
--                @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar;
--                Default: 1000;
--                NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind
--                keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt
--                in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt
--                deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen
--                Handles. Validierung auch bei @CaptureSqlText=0.
-- Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die
--                vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren
--                Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der
--                Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt;
--                TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus
--                vorkommen.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalCaptureCurrentStateSnapshot
CREATE OR ALTER PROCEDURE [monitor].[InternalCaptureCurrentStateSnapshot]
      @SnapshotId              uniqueidentifier
    , @CaptureSessions         bit = 0
    , @CaptureRequests         bit = 0
    , @CaptureConnections      bit = 0
    , @CaptureWaitingTasks     bit = 0
    , @CaptureMemoryGrants     bit = 0
    , @CaptureResourceGovernor bit = 0
    , @CaptureTasks            bit = 0
    , @CaptureSchedulers       bit = 0
    , @CaptureTransactions     bit = 0
    , @CaptureTempDbUsage      bit = 0
    , @CaptureVersionStore     bit = 0
    , @CaptureSqlText          bit = 0
    , @MaxSqlTextHandles       int = 1000
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalCaptureCurrentStateSnapshot
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalCaptureCurrentStateSnapshot') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalCaptureCurrentStateSnapshot"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalCaptureCurrentStateSnapshot"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen."'
            + NCHAR(10)
            + N'source_path: "Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalCaptureCurrentStateSnapshot'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure materialisiert die vom Orchestrator angeforderten DMV- und SQL-Textquellen einmalig in dessen lokalen Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht angefordert. SQL25-003 erweitert die Workload-Group-Erfassung versions- und capability-adaptiv.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalCaptureCurrentStateSnapshot]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[sys].[dm_exec_sessions]`, `sys.dm_exec_sessions`, `[sys].[dm_tran_version_store_space_usage]`, `sys.dm_tran_version_store_space_usage`, `[sys].[dm_tran_persistent_version_store_stats]`, `sys.dm_tran_persistent_version_store_stats`, `[sys].[dm_exec_requests]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @SnapshotId | uniqueidentifier | ja | kein Default |'
            + NCHAR(10)
            + N'| @CaptureSessions | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureRequests | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureConnections | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureWaitingTasks | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureMemoryGrants | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureResourceGovernor | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureTasks | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureSchedulers | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureTransactions | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureTempDbUsage | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureVersionStore | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @CaptureSqlText | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxSqlTextHandles | int | nein | 1000 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SnapshotId:** @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet gemäß Konvention eine frische ID. Eine im aktuellen Context bereits vorhandene ID wird als Duplikat abgelehnt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureSessions:** @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRequests:** @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureConnections:** @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst Connections.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureWaitingTasks:** @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende Tasks.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureMemoryGrants:** @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores aus; 1 erfasst beide Quellen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureResourceGovernor:** @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst Workload Groups, Resource Pools und versions- und quellenabhängige TempDB-Governance-Daten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureTasks:** @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits erfassten Requests.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureSchedulers:** @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu IDs bereits erfasster Requests oder Tasks.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureTransactions:** @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureTempDbUsage:** @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits erfassten Requests.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureVersionStore:** @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst traditionellen und persistenten Version Store innerhalb des Sessions-Zweigs.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureSqlText:** @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu Handles bereits erfasster Requests und Connections. Diese Quellen werden nicht automatisch aktiviert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxSqlTextHandles:** @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar; Default: 1000; NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen Handles. Validierung auch bei @CaptureSqlText=0. Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt; TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus vorkommen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein eigenes Fach-Resultset und keine OUTPUT-Parameter. Die Procedure schreibt Context-, SourceStatus- und die ausgewählten CurrentState-Gruppen in die bereits vom öffentlichen CurrentOverview vorbereiteten lokalen #Ziele, jeweils unter derselben SnapshotId. Quellenfehler werden gruppenweise als Status/Fehler in SourceStatus erfasst; die resultierenden Temp-Inhalte sind keine atomare Momentaufnahme aller DMVs.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalCaptureCurrentStateSnapshot'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalCaptureCurrentStateSnapshot] @SnapshotId=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + N'Objekt       : monitor.InternalCaptureCurrentStateSnapshot'
            + NCHAR(10)
            + N'Version      : 2.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-23'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten'
            + NCHAR(10)
            + N'               DMV- und SQL-Textquellen einmalig in dessen lokalen'
            + NCHAR(10)
            + N'               Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht'
            + NCHAR(10)
            + N'               angefordert. SQL25-003 erweitert die Workload-Group-Erfassung'
            + NCHAR(10)
            + N'               versions- und capability-adaptiv.'
            + NCHAR(10)
            + N'Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und'
            + NCHAR(10)
            + N'               besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope'
            + NCHAR(10)
            + N'               des aufrufenden Orchestrators.'
            + NCHAR(10)
            + N'Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden'
            + NCHAR(10)
            + N'               mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert'
            + NCHAR(10)
            + N'               keine globale Atomarität der Quellenerfassung.'
            + NCHAR(10)
            + N'Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat'
            + NCHAR(10)
            + N'               keinen Default. Nur optionale Parameter können ausgelassen werden;'
            + NCHAR(10)
            + N'               dann gilt ihr jeweiliger Default. Die '
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.InternalCaptureCurrentStateSnapshot'
            + NCHAR(10)
            + N'Version      : 2.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-23'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure materialisiert die vom Orchestrator angeforderten'
            + NCHAR(10)
            + N'               DMV- und SQL-Textquellen einmalig in dessen lokalen'
            + NCHAR(10)
            + N'               Snapshot-Tabellen. Nicht aktivierte Quellen werden nicht'
            + NCHAR(10)
            + N'               angefordert. SQL25-003 erweitert die Workload-Group-Erfassung'
            + NCHAR(10)
            + N'               versions- und capability-adaptiv.'
            + NCHAR(10)
            + N'Lebensdauer  : Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und'
            + NCHAR(10)
            + N'               besitzt dessen Lebensdauer; die Tabellen gelten nur im Scope'
            + NCHAR(10)
            + N'               des aufrufenden Orchestrators.'
            + NCHAR(10)
            + N'Sicherheit   : Read-only unter LOCK_TIMEOUT 0. Fehler einzelner Quellen werden'
            + NCHAR(10)
            + N'               mit Source-Status protokolliert; der TRY/CATCH-Aufbau garantiert'
            + NCHAR(10)
            + N'               keine globale Atomarität der Quellenerfassung.'
            + NCHAR(10)
            + N'Parameter    : Alle Parameter sind INPUT. @SnapshotId ist erforderlich und hat'
            + NCHAR(10)
            + N'               keinen Default. Nur optionale Parameter können ausgelassen werden;'
            + NCHAR(10)
            + N'               dann gilt ihr jeweiliger Default. Die bit-Werte 0 und 1 gelten'
            + NCHAR(10)
            + N'               nach der SQL-Typkonvertierung. Andere konvertierbare Quellwerte'
            + NCHAR(10)
            + N'               sind nicht generell ausgeschlossen; ein numerischer Wert ungleich'
            + NCHAR(10)
            + N'               null wird beispielsweise zu bit 1.'
            + NCHAR(10)
            + N'               @SnapshotId uniqueidentifier; einzelner GUID-Skalar; Default: keiner; NULL'
            + NCHAR(10)
            + N'               wird abgelehnt. Eine leere Zeichenfolge kann nicht in uniqueidentifier'
            + NCHAR(10)
            + N'               konvertiert werden. Auch der Null-GUID ist zulässig; der Aufrufer verwendet'
            + NCHAR(10)
            + N'               gemäß Konvention eine frische ID. Eine im aktuellen Context bereits'
            + NCHAR(10)
            + N'               vorhandene ID wird als Duplikat abgelehnt.'
            + NCHAR(10)
            + N'               @CaptureSessions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Sessions aus; 1 erfasst Sessions.'
            + NCHAR(10)
            + N'               @CaptureRequests bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Requests aus; 1 erfasst Requests.'
            + NCHAR(10)
            + N'               @CaptureConnections bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Connections aus; 1 erfasst'
            + NCHAR(10)
            + N'               Connections.'
            + NCHAR(10)
            + N'               @CaptureWaitingTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt wartende Tasks aus; 1 erfasst wartende'
            + NCHAR(10)
            + N'               Tasks.'
            + NCHAR(10)
            + N'               @CaptureMemoryGrants bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Memory Grants und Resource Semaphores'
            + NCHAR(10)
            + N'               aus; 1 erfasst beide Quellen.'
            + NCHAR(10)
            + N'               @CaptureResourceGovernor bit; Skalar 0 oder 1; Default: 0; NULL wird'
            + NCHAR(10)
            + N'               abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server'
            + NCHAR(10)
            + N'               konvertiert vor Prozedureintritt in bit. 0 lässt die Quellen aus; 1 erfasst'
            + NCHAR(10)
            + N'               Workload Groups, Resource Pools und versions- und quellenabhängige'
            + NCHAR(10)
            + N'               TempDB-Governance-Daten.'
            + NCHAR(10)
            + N'               @CaptureTasks bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt. Leere'
            + NCHAR(10)
            + N'               Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert vor'
            + NCHAR(10)
            + N'               Prozedureintritt in bit. 0 lässt Tasks aus; 1 erfasst Tasks zu bereits'
            + NCHAR(10)
            + N'               erfassten Requests.'
            + NCHAR(10)
            + N'               @CaptureSchedulers bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Schedulers aus; 1 erfasst Scheduler zu'
            + NCHAR(10)
            + N'               IDs bereits erfasster Requests oder Tasks.'
            + NCHAR(10)
            + N'               @CaptureTransactions bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt die Transaktionsquellen aus; 1 erfasst'
            + NCHAR(10)
            + N'               Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions.'
            + NCHAR(10)
            + N'               @CaptureTempDbUsage bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt TempDB-Nutzungsquellen aus; 1 erfasst'
            + NCHAR(10)
            + N'               Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits'
            + NCHAR(10)
            + N'               erfassten Requests.'
            + NCHAR(10)
            + N'               @CaptureVersionStore bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt Version-Store-Quellen aus; 1 erfasst'
            + NCHAR(10)
            + N'               traditionellen und persistenten Version Store innerhalb des'
            + NCHAR(10)
            + N'               Sessions-Zweigs.'
            + NCHAR(10)
            + N'               @CaptureSqlText bit; Skalar 0 oder 1; Default: 0; NULL wird abgelehnt.'
            + NCHAR(10)
            + N'               Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert'
            + NCHAR(10)
            + N'               vor Prozedureintritt in bit. 0 lässt SQL-Text aus; 1 ermittelt Text zu'
            + NCHAR(10)
            + N'               Handles bereits erfasster Requests und Connections. Diese Quellen werden'
            + NCHAR(10)
            + N'               nicht automatisch aktiviert.'
            + NCHAR(10)
            + N'               @MaxSqlTextHandles int; Ganzzahl von 0 bis 2147483647 als Skalar;'
            + NCHAR(10)
            + N'               Default: 1000;'
            + NCHAR(10)
            + N'               NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind'
            + NCHAR(10)
            + N'               keine vorgesehene Eingabeform; SQL Server konvertiert vor Prozedureintritt'
            + NCHAR(10)
            + N'               in int. 0 bedeutet unbegrenzte Handles; ein positiver Wert begrenzt'
            + NCHAR(10)
            + N'               deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen'
            + NCHAR(10)
            + N'               Handles. Validierung auch bei @CaptureSqlText=0.'
            + NCHAR(10)
            + N'Vertrag      : Die Procedure schreibt Context- und Source-Status-Daten in die'
            + NCHAR(10)
            + N'               vom Aufrufer angelegten Temp-Tabellen. Die Probe prüft deren'
            + NCHAR(10)
            + N'               Existenz, nicht das vollständige Spaltenschema. Der Status einer Quelle und der'
            + NCHAR(10)
            + N'               Evidenzstatus eines einzelnen SQL-Text-Handles sind getrennt;'
            + NCHAR(10)
            + N'               TEXT_UNAVAILABLE kann bei erfolgreichem SQL_TEXT-Quellstatus'
            + NCHAR(10)
            + N'               vorkommen.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalCaptureCurrentStateSnapshot
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    IF @SnapshotId IS NULL
        THROW 51020, N'@SnapshotId darf nicht NULL sein.', 1;

    IF @CaptureSessions IS NULL OR @CaptureSessions NOT IN (0,1)
       OR @CaptureRequests IS NULL OR @CaptureRequests NOT IN (0,1)
       OR @CaptureConnections IS NULL OR @CaptureConnections NOT IN (0,1)
       OR @CaptureWaitingTasks IS NULL OR @CaptureWaitingTasks NOT IN (0,1)
       OR @CaptureMemoryGrants IS NULL OR @CaptureMemoryGrants NOT IN (0,1)
       OR @CaptureResourceGovernor IS NULL OR @CaptureResourceGovernor NOT IN (0,1)
       OR @CaptureTasks IS NULL OR @CaptureTasks NOT IN (0,1)
       OR @CaptureSchedulers IS NULL OR @CaptureSchedulers NOT IN (0,1)
       OR @CaptureTransactions IS NULL OR @CaptureTransactions NOT IN (0,1)
       OR @CaptureTempDbUsage IS NULL OR @CaptureTempDbUsage NOT IN (0,1)
       OR @CaptureVersionStore IS NULL OR @CaptureVersionStore NOT IN (0,1)
       OR @CaptureSqlText IS NULL OR @CaptureSqlText NOT IN (0,1)
       OR @MaxSqlTextHandles IS NULL OR @MaxSqlTextHandles < 0
        THROW 51020, N'Ungültiger Current-State-Snapshot-Parameter.', 1;

    BEGIN TRY
        EXEC [sys].[sp_executesql] N'
            DECLARE @Probe int;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Context] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Sessions] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Requests] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Connections] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_WaitingTasks] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_MemoryGrants] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_ResourceSemaphores] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_ResourcePools] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Tasks] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Schedulers] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SessionTransactions] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_ActiveTransactions] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_DatabaseTransactions] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_TempDbSessionUsage] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_TempDbTaskUsage] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_VersionStoreSpaceUsage] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_PersistentVersionStore] WHERE 1=0;
            SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SqlText] WHERE 1=0;';
    END TRY
    BEGIN CATCH
        THROW 51020, N'Der aufrufende Snapshot-Owner hat den Temp-Table-Vertrag nicht vollständig angelegt.', 1;
    END CATCH;

    IF EXISTS
    (
        SELECT 1
        FROM [#CurrentOverview_CurrentStateSnapshot_Context]
        WHERE [SnapshotId] = @SnapshotId
    )
        THROW 51020, N'Diese Snapshot-ID wurde im aktuellen Aufruf bereits verwendet.', 1;

    INSERT [#CurrentOverview_CurrentStateSnapshot_Context]
    (
        [SnapshotId],[OwnerSessionId],[CreatedAtUtc],[ContractVersion]
    )
    VALUES
    (
        @SnapshotId,CONVERT(smallint,@@SPID),SYSUTCDATETIME(),2
    );

    DECLARE @HasFullView bit =
        CASE
            WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
            WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) >= 16
                THEN COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER PERFORMANCE STATE'),0)
            ELSE COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER STATE'),0)
        END;
    DECLARE @CapturedAtUtc datetime2(3);
    DECLARE @CompletedAtUtc datetime2(3);
    DECLARE @RowCount bigint;
    DECLARE @ErrorNumber int;
    DECLARE @ErrorMessage nvarchar(2048);
    DECLARE @StatusCode varchar(40);
    DECLARE @IsPartial bit;
    DECLARE @BaseStatusCode varchar(40)=CASE WHEN @HasFullView=1 THEN 'AVAILABLE' ELSE 'AVAILABLE_LIMITED' END;
    DECLARE @BaseIsPartial bit=CASE WHEN @HasFullView=1 THEN 0 ELSE 1 END;

    IF @CaptureSessions=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_Sessions]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[is_user_process],[status],
                [login_name],[original_login_name],[host_name],[program_name],
                [client_interface_name],[login_time],[last_request_start_time],
                [last_request_end_time],[open_transaction_count],
                [transaction_isolation_level],[cpu_time],[reads],[writes],
                [logical_reads],[memory_usage],[row_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[s].[session_id],[s].[is_user_process],[s].[status],
                [s].[login_name],[s].[original_login_name],[s].[host_name],[s].[program_name],
                [s].[client_interface_name],[s].[login_time],[s].[last_request_start_time],
                [s].[last_request_end_time],[s].[open_transaction_count],
                [s].[transaction_isolation_level],[s].[cpu_time],[s].[reads],[s].[writes],
                [s].[logical_reads],[s].[memory_usage],[s].[row_count]
            FROM [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK);

            SELECT @RowCount=COUNT_BIG(*)
            FROM [#CurrentOverview_CurrentStateSnapshot_Sessions]
            WHERE [SnapshotId]=@SnapshotId;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,10,'SESSIONS',N'sys.dm_exec_sessions',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,10,'SESSIONS',N'sys.dm_exec_sessions',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        IF @CaptureVersionStore=1
        BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_VersionStoreSpaceUsage]
            (
                [SnapshotId],[CapturedAtUtc],[database_id],[reserved_page_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[database_id],[reserved_page_count]
            FROM [sys].[dm_tran_version_store_space_usage] WITH (NOLOCK);

            SET @RowCount=
                (SELECT COUNT_BIG(*) FROM [#CurrentOverview_CurrentStateSnapshot_VersionStoreSpaceUsage]
                 WHERE [SnapshotId]=@SnapshotId);
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,160,'TRADITIONAL_VERSION_STORE',N'sys.dm_tran_version_store_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,160,'TRADITIONAL_VERSION_STORE',N'sys.dm_tran_version_store_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_PersistentVersionStore]
            (
                [SnapshotId],[CapturedAtUtc],[database_id],[pvs_filegroup_id],
                [persistent_version_store_size_kb],[online_index_version_store_size_kb]
            )
            SELECT
                  @SnapshotId,@CapturedAtUtc,[database_id],[pvs_filegroup_id]
                , [persistent_version_store_size_kb],[online_index_version_store_size_kb]
            FROM [sys].[dm_tran_persistent_version_store_stats] WITH (NOLOCK);

            SET @RowCount=
                (SELECT COUNT_BIG(*) FROM [#CurrentOverview_CurrentStateSnapshot_PersistentVersionStore]
                 WHERE [SnapshotId]=@SnapshotId);
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,170,'PERSISTENT_VERSION_STORE',N'sys.dm_tran_persistent_version_store_stats',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,170,'PERSISTENT_VERSION_STORE',N'sys.dm_tran_persistent_version_store_stats',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
        END;
    END;

    IF @CaptureRequests=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_Requests]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[request_id],[status],[command],
                [start_time],[sql_handle],[statement_start_offset],[statement_end_offset],
                [plan_handle],[database_id],[connection_id],[blocking_session_id],
                [wait_type],[wait_time],[last_wait_type],[wait_resource],
                [open_transaction_count],[open_resultset_count],[transaction_id],
                [context_info],[percent_complete],[estimated_completion_time],
                [cpu_time],[total_elapsed_time],[scheduler_id],[task_address],
                [reads],[writes],[logical_reads],[transaction_isolation_level],
                [row_count],[nest_level],[executing_managed_code],[group_id],
                [query_hash],[query_plan_hash],[statement_sql_handle],
                [statement_context_id],[dop],[parallel_worker_count],[is_resumable]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[r].[session_id],[r].[request_id],[r].[status],[r].[command],
                [r].[start_time],[r].[sql_handle],[r].[statement_start_offset],[r].[statement_end_offset],
                [r].[plan_handle],[r].[database_id],[r].[connection_id],[r].[blocking_session_id],
                [r].[wait_type],[r].[wait_time],[r].[last_wait_type],[r].[wait_resource],
                [r].[open_transaction_count],[r].[open_resultset_count],[r].[transaction_id],
                [r].[context_info],[r].[percent_complete],[r].[estimated_completion_time],
                [r].[cpu_time],[r].[total_elapsed_time],[r].[scheduler_id],[r].[task_address],
                [r].[reads],[r].[writes],[r].[logical_reads],[r].[transaction_isolation_level],
                [r].[row_count],[r].[nest_level],[r].[executing_managed_code],[r].[group_id],
                [r].[query_hash],[r].[query_plan_hash],[r].[statement_sql_handle],
                [r].[statement_context_id],[r].[dop],[r].[parallel_worker_count],[r].[is_resumable]
            FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,20,'REQUESTS',N'sys.dm_exec_requests',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,20,'REQUESTS',N'sys.dm_exec_requests',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureConnections=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_Connections]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[connection_id],
                [most_recent_sql_handle],[client_net_address],[net_transport],
                [protocol_type],[encrypt_option],[auth_scheme],[connect_time]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[c].[session_id],[c].[connection_id],
                [c].[most_recent_sql_handle],[c].[client_net_address],[c].[net_transport],
                [c].[protocol_type],[c].[encrypt_option],[c].[auth_scheme],[c].[connect_time]
            FROM [sys].[dm_exec_connections] AS [c] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,30,'CONNECTIONS',N'sys.dm_exec_connections',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,30,'CONNECTIONS',N'sys.dm_exec_connections',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureWaitingTasks=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_WaitingTasks]
            (
                [SnapshotId],[CapturedAtUtc],[waiting_task_address],[session_id],
                [exec_context_id],[wait_duration_ms],[wait_type],[resource_address],
                [blocking_task_address],[blocking_session_id],
                [blocking_exec_context_id],[resource_description]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[w].[waiting_task_address],[w].[session_id],
                [w].[exec_context_id],[w].[wait_duration_ms],[w].[wait_type],[w].[resource_address],
                [w].[blocking_task_address],[w].[blocking_session_id],
                [w].[blocking_exec_context_id],[w].[resource_description]
            FROM [sys].[dm_os_waiting_tasks] AS [w] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,40,'WAITING_TASKS',N'sys.dm_os_waiting_tasks',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,40,'WAITING_TASKS',N'sys.dm_os_waiting_tasks',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureMemoryGrants=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_MemoryGrants]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[request_id],
                [scheduler_id],[dop],[request_time],[grant_time],[wait_time_ms],
                [requested_memory_kb],[required_memory_kb],[granted_memory_kb],
                [used_memory_kb],[max_used_memory_kb],[ideal_memory_kb],
                [resource_semaphore_id],[queue_id],[wait_order],[is_next_candidate],
                [is_small],[plan_handle],[sql_handle],[group_id],[pool_id],
                [reserved_worker_count],[used_worker_count],[max_used_worker_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[g].[session_id],[g].[request_id],
                [g].[scheduler_id],[g].[dop],[g].[request_time],[g].[grant_time],[g].[wait_time_ms],
                [g].[requested_memory_kb],[g].[required_memory_kb],[g].[granted_memory_kb],
                [g].[used_memory_kb],[g].[max_used_memory_kb],[g].[ideal_memory_kb],
                [g].[resource_semaphore_id],[g].[queue_id],[g].[wait_order],[g].[is_next_candidate],
                [g].[is_small],[g].[plan_handle],[g].[sql_handle],[g].[group_id],[g].[pool_id],
                [g].[reserved_worker_count],[g].[used_worker_count],[g].[max_used_worker_count]
            FROM [sys].[dm_exec_query_memory_grants] AS [g] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,50,'MEMORY_GRANTS',N'sys.dm_exec_query_memory_grants',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,50,'MEMORY_GRANTS',N'sys.dm_exec_query_memory_grants',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_ResourceSemaphores]
            (
                [SnapshotId],[CapturedAtUtc],[pool_id],[resource_semaphore_id],
                [target_memory_kb],[max_target_memory_kb],[total_memory_kb],
                [available_memory_kb],[granted_memory_kb],[used_memory_kb],
                [grantee_count],[waiter_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[s].[pool_id],[s].[resource_semaphore_id],
                [s].[target_memory_kb],[s].[max_target_memory_kb],[s].[total_memory_kb],
                [s].[available_memory_kb],[s].[granted_memory_kb],[s].[used_memory_kb],
                [s].[grantee_count],[s].[waiter_count]
            FROM [sys].[dm_exec_query_resource_semaphores] AS [s] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,55,'RESOURCE_SEMAPHORES',N'sys.dm_exec_query_resource_semaphores',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,55,'RESOURCE_SEMAPHORES',N'sys.dm_exec_query_resource_semaphores',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureResourceGovernor=1
    BEGIN
        DECLARE @ProductMajorVersion int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
        DECLARE @CatalogTempdbColumnsValid bit=0;
        DECLARE @RuntimeTempdbColumnsValid bit=0;
        DECLARE @TempdbGovernanceStatus varchar(40)=
            CASE WHEN @ProductMajorVersion IS NULL OR @ProductMajorVersion<17
                 THEN 'UNAVAILABLE_VERSION' ELSE 'AVAILABLE' END;
        DECLARE @TempdbGovernanceErrorNumber int=NULL;
        DECLARE @TempdbGovernanceErrorMessage nvarchar(2048)=NULL;
        DECLARE @TempdbMaximumSizeMb decimal(19,2)=NULL;
        DECLARE @TempdbFileStatus varchar(40)='NOT_APPLICABLE';
        DECLARE @TempdbFileErrorNumber int=NULL;
        DECLARE @TempdbFileErrorMessage nvarchar(2048)=NULL;
        DECLARE @IsResourceGovernorEnabled bit=NULL;
        DECLARE @ReconfigurationPending bit=NULL;
        DECLARE @ResourceGovernorSql nvarchar(max);

        IF @ProductMajorVersion>=17
        BEGIN TRY
            SELECT
                  @CatalogTempdbColumnsValid=CONVERT
                  (
                      bit,
                      CASE WHEN SUM(CASE WHEN [o].[name]=N'resource_governor_workload_groups'
                                          AND [c].[name] IN
                                              (N'group_max_tempdb_data_mb',N'group_max_tempdb_data_percent')
                                        THEN 1 ELSE 0 END)=2
                           THEN 1 ELSE 0 END
                  )
                , @RuntimeTempdbColumnsValid=CONVERT
                  (
                      bit,
                      CASE WHEN SUM(CASE WHEN [o].[name]=N'dm_resource_governor_workload_groups'
                                          AND [c].[name] IN
                                              (N'tempdb_data_space_kb',N'peak_tempdb_data_space_kb',
                                               N'total_tempdb_data_limit_violation_count')
                                        THEN 1 ELSE 0 END)=3
                           THEN 1 ELSE 0 END
                  )
            FROM [sys].[all_columns] AS [c] WITH (NOLOCK)
            INNER JOIN [sys].[all_objects] AS [o] WITH (NOLOCK)
              ON [o].[object_id]=[c].[object_id]
            INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
              ON [s].[schema_id]=[o].[schema_id]
            WHERE [s].[name]=N'sys'
              AND [o].[name] IN
                  (N'resource_governor_workload_groups',N'dm_resource_governor_workload_groups');

            IF @CatalogTempdbColumnsValid=0 OR @RuntimeTempdbColumnsValid=0
                SET @TempdbGovernanceStatus='UNAVAILABLE_SOURCE_SCHEMA';
        END TRY
        BEGIN CATCH
            SELECT
                  @TempdbGovernanceErrorNumber=ERROR_NUMBER()
                , @TempdbGovernanceErrorMessage=ERROR_MESSAGE()
                , @TempdbGovernanceStatus=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                     WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                     ELSE 'ERROR_HANDLED' END;
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            DECLARE @RuntimeProjection nvarchar(max)=
                CASE WHEN @ProductMajorVersion>=17 AND @RuntimeTempdbColumnsValid=1
                     THEN N',CONVERT(decimal(19,2),[g].[tempdb_data_space_kb]/1024.0)
                             ,CONVERT(decimal(19,2),[g].[peak_tempdb_data_space_kb]/1024.0)
                             ,CONVERT(decimal(9,2),NULL)
                             ,CONVERT(bigint,[g].[total_tempdb_data_limit_violation_count])
                             ,CONVERT(bit,CASE WHEN [g].[total_tempdb_data_limit_violation_count]>0 THEN 1 ELSE 0 END)'
                     ELSE N',CONVERT(decimal(19,2),NULL),CONVERT(decimal(19,2),NULL)
                             ,CONVERT(decimal(9,2),NULL),CONVERT(bigint,NULL),CONVERT(bit,NULL)' END;

            SET @ResourceGovernorSql=N'
INSERT [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups]
(
      [SnapshotId],[CapturedAtUtc],[group_id],[name],[pool_id]
    , [request_max_memory_grant_percent_numeric],[max_request_grant_memory_kb]
    , [configured_group_max_tempdb_data_mb],[configured_group_max_tempdb_data_percent]
    , [tempdb_maximum_size_mb],[effective_group_max_tempdb_data_mb]
    , [effective_limit_source],[is_percent_limit_effective]
    , [tempdb_data_space_mb],[peak_tempdb_data_space_mb]
    , [effective_limit_utilization_percent]
    , [total_tempdb_data_limit_violation_count],[has_recorded_limit_violation]
    , [statistics_start_time],[is_resource_governor_enabled],[reconfiguration_pending]
    , [tempdb_governance_status_code],[tempdb_governance_is_partial]
    , [tempdb_governance_evidence_limit]
)
SELECT
      @SnapshotId,@CapturedAtUtc,[g].[group_id],[g].[name],[g].[pool_id]
    , CONVERT(decimal(9,4),[g].[request_max_memory_grant_percent_numeric])
    , [g].[max_request_grant_memory_kb]
    , CONVERT(decimal(19,2),NULL),CONVERT(decimal(9,4),NULL)
    , CONVERT(decimal(19,2),NULL),CONVERT(decimal(19,2),NULL)
    , CONVERT(varchar(40),''UNAVAILABLE''),CONVERT(bit,NULL)'
    +@RuntimeProjection+
N'
    , [g].[statistics_start_time],CONVERT(bit,NULL),CONVERT(bit,NULL)
    , @TempdbStatus
    , CONVERT(bit,CASE WHEN @TempdbStatus=''AVAILABLE'' THEN 0 ELSE 1 END)
    , CASE WHEN @TempdbStatus=''UNAVAILABLE_VERSION''
           THEN N''TempDB Resource Governance beginnt mit SQL Server 2025 (17.x).''
           WHEN @TempdbStatus<>''AVAILABLE''
           THEN N''Die SQL-Server-2025-Quelle ist nicht vollständig verfügbar.''
           ELSE N''Workload-Group-Zähler sind nicht direkt mit Sessionzählern addierbar; Version Store und TempDB-Log sind nicht umfasst.'' END
FROM [sys].[dm_resource_governor_workload_groups] AS [g] WITH (NOLOCK);';

            EXEC [sys].[sp_executesql]
                  @ResourceGovernorSql
                , N'@SnapshotId uniqueidentifier,@CapturedAtUtc datetime2(3),@TempdbStatus varchar(40)'
                , @SnapshotId=@SnapshotId
                , @CapturedAtUtc=@CapturedAtUtc
                , @TempdbStatus=@TempdbGovernanceStatus;

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (
                 @SnapshotId,60,'WORKLOAD_GROUPS',N'sys.dm_resource_governor_workload_groups'
                ,@CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL
            );
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (
                 @SnapshotId,60,'WORKLOAD_GROUPS',N'sys.dm_resource_governor_workload_groups'
                ,@CapturedAtUtc,@CompletedAtUtc
                ,CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT'
                      WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                      ELSE 'ERROR_HANDLED' END
                ,1,0,@ErrorNumber,@ErrorMessage
            );
            SELECT
                  @TempdbGovernanceStatus=CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT'
                       WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                       ELSE 'ERROR_HANDLED' END
                , @TempdbGovernanceErrorNumber=@ErrorNumber
                , @TempdbGovernanceErrorMessage=@ErrorMessage;
        END CATCH;

        IF @ProductMajorVersion>=17
           AND EXISTS
               (
                   SELECT 1
                   FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups]
                   WHERE [SnapshotId]=@SnapshotId
               )
        BEGIN
            IF @CatalogTempdbColumnsValid=1
            BEGIN TRY
                SET @ResourceGovernorSql=N'
UPDATE [target]
SET
      [configured_group_max_tempdb_data_mb]=
          CONVERT(decimal(19,2),[source].[group_max_tempdb_data_mb])
    , [configured_group_max_tempdb_data_percent]=
          CONVERT(decimal(9,4),[source].[group_max_tempdb_data_percent])
FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups] AS [target]
INNER JOIN [sys].[resource_governor_workload_groups] AS [source] WITH (NOLOCK)
  ON [source].[group_id]=[target].[group_id]
WHERE [target].[SnapshotId]=@SnapshotId;';

                EXEC [sys].[sp_executesql]
                      @ResourceGovernorSql
                    , N'@SnapshotId uniqueidentifier'
                    , @SnapshotId=@SnapshotId;
            END TRY
            BEGIN CATCH
                SELECT
                      @TempdbGovernanceErrorNumber=ERROR_NUMBER()
                    , @TempdbGovernanceErrorMessage=ERROR_MESSAGE()
                    , @TempdbGovernanceStatus=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                         WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                         ELSE 'ERROR_HANDLED' END;
            END CATCH;

            BEGIN TRY
                SELECT
                      @IsResourceGovernorEnabled=[stored].[is_enabled]
                    , @ReconfigurationPending=[effective].[is_reconfiguration_pending]
                FROM [sys].[resource_governor_configuration] AS [stored] WITH (NOLOCK)
                CROSS JOIN [sys].[dm_resource_governor_configuration] AS [effective] WITH (NOLOCK);
            END TRY
            BEGIN CATCH
                SELECT
                      @TempdbGovernanceErrorNumber=ERROR_NUMBER()
                    , @TempdbGovernanceErrorMessage=ERROR_MESSAGE()
                    , @TempdbGovernanceStatus=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                         WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                         ELSE 'ERROR_HANDLED' END;
            END CATCH;

            IF @TempdbGovernanceStatus='AVAILABLE'
               AND EXISTS
                   (
                       SELECT 1
                       FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups]
                       WHERE [SnapshotId]=@SnapshotId
                         AND [configured_group_max_tempdb_data_mb] IS NULL
                         AND [configured_group_max_tempdb_data_percent] IS NOT NULL
                   )
            BEGIN
                SET @TempdbFileStatus='AVAILABLE';
                BEGIN TRY
                    SELECT @TempdbMaximumSizeMb=
                        CASE
                            WHEN COUNT_BIG(*)>0
                             AND
                             (
                                 SUM(CASE WHEN [f].[max_size]<>-1 AND [f].[growth]>0 THEN 1 ELSE 0 END)=COUNT_BIG(*)
                                 OR
                                 SUM(CASE WHEN [f].[max_size]=-1 AND [f].[growth]=0 THEN 1 ELSE 0 END)=COUNT_BIG(*)
                             )
                            THEN CONVERT
                                 (
                                     decimal(19,2),
                                     SUM(CASE WHEN [f].[growth]=0 THEN CONVERT(bigint,[f].[size])
                                              ELSE CONVERT(bigint,[f].[max_size]) END)*8.0/1024.0
                                 )
                        END
                    FROM [master].[sys].[master_files] AS [f] WITH (NOLOCK)
                    WHERE [f].[database_id]=2 AND [f].[type]=0;
                END TRY
                BEGIN CATCH
                    SELECT
                          @TempdbFileErrorNumber=ERROR_NUMBER()
                        , @TempdbFileErrorMessage=ERROR_MESSAGE()
                        , @TempdbFileStatus=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                             WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                             ELSE 'ERROR_HANDLED' END;
                END CATCH;
            END;

            UPDATE [g]
            SET
                  [tempdb_maximum_size_mb]=@TempdbMaximumSizeMb
                , [effective_group_max_tempdb_data_mb]=CONVERT
                  (
                      decimal(19,2),
                      CASE
                          WHEN @TempdbGovernanceStatus<>'AVAILABLE' THEN NULL
                          WHEN [g].[configured_group_max_tempdb_data_mb] IS NULL
                           AND [g].[configured_group_max_tempdb_data_percent] IS NULL THEN NULL
                          WHEN @ReconfigurationPending=1 OR COALESCE(@IsResourceGovernorEnabled,0)=0 THEN NULL
                          WHEN [g].[configured_group_max_tempdb_data_mb] IS NOT NULL
                              THEN [g].[configured_group_max_tempdb_data_mb]
                          WHEN @TempdbFileStatus<>'AVAILABLE' THEN NULL
                          WHEN @TempdbMaximumSizeMb IS NOT NULL
                              THEN [g].[configured_group_max_tempdb_data_percent]*@TempdbMaximumSizeMb/100.0
                      END
                  )
                , [effective_limit_source]=CASE
                      WHEN @TempdbGovernanceStatus<>'AVAILABLE' THEN 'UNAVAILABLE'
                      WHEN [g].[configured_group_max_tempdb_data_mb] IS NULL
                       AND [g].[configured_group_max_tempdb_data_percent] IS NULL THEN 'NO_LIMIT_CONFIGURED'
                      WHEN @ReconfigurationPending=1 THEN 'RECONFIGURATION_PENDING'
                      WHEN COALESCE(@IsResourceGovernorEnabled,0)=0 THEN 'RESOURCE_GOVERNOR_DISABLED'
                      WHEN [g].[configured_group_max_tempdb_data_mb] IS NOT NULL THEN 'FIXED_MB_EFFECTIVE'
                      WHEN @TempdbFileStatus<>'AVAILABLE' THEN 'UNAVAILABLE'
                      WHEN @TempdbMaximumSizeMb IS NOT NULL THEN 'PERCENT_EFFECTIVE'
                      ELSE 'PERCENT_NOT_EFFECTIVE'
                  END
                , [is_percent_limit_effective]=CASE
                      WHEN [g].[configured_group_max_tempdb_data_percent] IS NULL THEN NULL
                      WHEN [g].[configured_group_max_tempdb_data_mb] IS NOT NULL THEN CONVERT(bit,0)
                      WHEN @ReconfigurationPending=1 OR COALESCE(@IsResourceGovernorEnabled,0)=0 THEN CONVERT(bit,0)
                      WHEN @TempdbFileStatus<>'AVAILABLE' THEN NULL
                      WHEN @TempdbMaximumSizeMb IS NOT NULL THEN CONVERT(bit,1)
                      ELSE CONVERT(bit,0)
                  END
                , [effective_limit_utilization_percent]=CONVERT
                  (
                      decimal(9,2),
                      100.0*[g].[tempdb_data_space_mb]
                      /NULLIF
                       (
                           CASE
                               WHEN @ReconfigurationPending=0 AND COALESCE(@IsResourceGovernorEnabled,0)=1
                                AND [g].[configured_group_max_tempdb_data_mb] IS NOT NULL
                                   THEN [g].[configured_group_max_tempdb_data_mb]
                               WHEN @ReconfigurationPending=0 AND COALESCE(@IsResourceGovernorEnabled,0)=1
                                AND [g].[configured_group_max_tempdb_data_mb] IS NULL
                                AND @TempdbMaximumSizeMb IS NOT NULL
                                   THEN [g].[configured_group_max_tempdb_data_percent]*@TempdbMaximumSizeMb/100.0
                           END
                       ,0)
                  )
                , [is_resource_governor_enabled]=@IsResourceGovernorEnabled
                , [reconfiguration_pending]=@ReconfigurationPending
                , [tempdb_governance_status_code]=CASE
                      WHEN @TempdbGovernanceStatus='AVAILABLE'
                       AND [g].[configured_group_max_tempdb_data_mb] IS NULL
                       AND [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                       AND @TempdbFileStatus<>'AVAILABLE'
                          THEN @TempdbFileStatus
                      WHEN @TempdbGovernanceStatus='AVAILABLE'
                       AND @ReconfigurationPending=1
                       AND
                         (
                             [g].[configured_group_max_tempdb_data_mb] IS NOT NULL
                             OR [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                         )
                          THEN 'AVAILABLE_LIMITED'
                      ELSE @TempdbGovernanceStatus
                  END
                , [tempdb_governance_is_partial]=CONVERT
                  (
                      bit,
                      CASE
                          WHEN @TempdbGovernanceStatus<>'AVAILABLE' THEN 1
                          WHEN [g].[configured_group_max_tempdb_data_mb] IS NULL
                           AND [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                           AND @TempdbFileStatus<>'AVAILABLE' THEN 1
                          WHEN @ReconfigurationPending=1
                           AND
                             (
                                 [g].[configured_group_max_tempdb_data_mb] IS NOT NULL
                                 OR [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                             )
                              THEN 1
                          ELSE 0
                      END
                  )
                , [tempdb_governance_evidence_limit]=CASE
                      WHEN @TempdbGovernanceStatus<>'AVAILABLE'
                          THEN COALESCE(@TempdbGovernanceErrorMessage,N'Die SQL-Server-2025-Quelle ist nicht vollständig verfügbar.')
                      WHEN [g].[configured_group_max_tempdb_data_mb] IS NULL
                       AND [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                       AND @TempdbFileStatus<>'AVAILABLE'
                          THEN COALESCE(@TempdbFileErrorMessage,N'Die TempDB-Dateikonfiguration ist im aktuellen Sicherheitskontext nicht auswertbar.')
                      WHEN @ReconfigurationPending=1
                          THEN N'Die gespeicherte Konfiguration kann von der aktiven Konfiguration abweichen, bis RECONFIGURE abgeschlossen ist.'
                      WHEN [g].[configured_group_max_tempdb_data_mb] IS NULL
                       AND [g].[configured_group_max_tempdb_data_percent] IS NOT NULL
                       AND @TempdbMaximumSizeMb IS NULL
                          THEN N'Das gespeicherte Prozentlimit ist wegen der TempDB-Dateikonfiguration nicht wirksam.'
                      ELSE N'Workload-Group-Zähler sind nicht direkt mit Sessionzählern addierbar; Version Store und TempDB-Log sind nicht umfasst.'
                  END
            FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups] AS [g]
            WHERE [g].[SnapshotId]=@SnapshotId;

            SET @CompletedAtUtc=SYSUTCDATETIME();
            SELECT @RowCount=COUNT_BIG(*)
            FROM [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups]
            WHERE [SnapshotId]=@SnapshotId;

            DECLARE @TempdbSnapshotStatus varchar(40)=CASE
                WHEN @TempdbGovernanceStatus<>'AVAILABLE' THEN @TempdbGovernanceStatus
                WHEN @TempdbFileStatus NOT IN ('AVAILABLE','NOT_APPLICABLE')
                    THEN 'AVAILABLE_LIMITED'
                ELSE 'AVAILABLE' END;

            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (
                 @SnapshotId,61,'TEMPDB_GOVERNANCE'
                ,N'sys.resource_governor_workload_groups | sys.dm_resource_governor_workload_groups | master.sys.master_files'
                ,@CapturedAtUtc,@CompletedAtUtc
                ,@TempdbSnapshotStatus
                ,CONVERT(bit,CASE WHEN @TempdbSnapshotStatus='AVAILABLE' THEN 0 ELSE 1 END)
                ,@RowCount
                ,COALESCE(@TempdbGovernanceErrorNumber,@TempdbFileErrorNumber)
                ,COALESCE(@TempdbGovernanceErrorMessage,@TempdbFileErrorMessage)
            );
        END;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_ResourcePools]
            (
                [SnapshotId],[CapturedAtUtc],[pool_id],[name],
                [max_memory_kb],[target_memory_kb],[used_memory_kb]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[p].[pool_id],[p].[name],
                [p].[max_memory_kb],[p].[target_memory_kb],[p].[used_memory_kb]
            FROM [sys].[dm_resource_governor_resource_pools] AS [p] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,70,'RESOURCE_POOLS',N'sys.dm_resource_governor_resource_pools',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,70,'RESOURCE_POOLS',N'sys.dm_resource_governor_resource_pools',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureTasks=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_Tasks]
            (
                [SnapshotId],[CapturedAtUtc],[task_address],[task_state],
                [session_id],[request_id],[exec_context_id],[scheduler_id],
                [worker_address],[parent_task_address]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[t].[task_address],[t].[task_state],
                [t].[session_id],[t].[request_id],[t].[exec_context_id],[t].[scheduler_id],
                [t].[worker_address],[t].[parent_task_address]
            FROM [sys].[dm_os_tasks] AS [t] WITH (NOLOCK)
            WHERE EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_Requests] AS [r]
                WHERE [r].[SnapshotId]=@SnapshotId
                  AND [r].[session_id]=[t].[session_id]
                  AND [r].[request_id]=[t].[request_id]
            );

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,90,'TASKS',N'sys.dm_os_tasks',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,90,'TASKS',N'sys.dm_os_tasks',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureSchedulers=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_Schedulers]
            (
                [SnapshotId],[CapturedAtUtc],[scheduler_address],[scheduler_id],
                [parent_node_id],[status],[is_online],[is_idle],
                [current_tasks_count],[runnable_tasks_count],[current_workers_count],
                [active_workers_count],[work_queue_count],[pending_disk_io_count],[load_factor]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[s].[scheduler_address],[s].[scheduler_id],
                [s].[parent_node_id],[s].[status],[s].[is_online],[s].[is_idle],
                [s].[current_tasks_count],[s].[runnable_tasks_count],[s].[current_workers_count],
                [s].[active_workers_count],[s].[work_queue_count],[s].[pending_disk_io_count],[s].[load_factor]
            FROM [sys].[dm_os_schedulers] AS [s] WITH (NOLOCK)
            WHERE [s].[scheduler_id] < 1048576
              AND
              (
                  EXISTS
                  (
                      SELECT 1
                      FROM [#CurrentOverview_CurrentStateSnapshot_Requests] AS [r]
                      WHERE [r].[SnapshotId]=@SnapshotId
                        AND [r].[scheduler_id]=[s].[scheduler_id]
                  )
                  OR EXISTS
                  (
                      SELECT 1
                      FROM [#CurrentOverview_CurrentStateSnapshot_Tasks] AS [t]
                      WHERE [t].[SnapshotId]=@SnapshotId
                        AND [t].[scheduler_id]=[s].[scheduler_id]
                  )
              );

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,100,'SCHEDULERS',N'sys.dm_os_schedulers',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,100,'SCHEDULERS',N'sys.dm_os_schedulers',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureTransactions=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_SessionTransactions]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[transaction_id],
                [transaction_descriptor],[enlist_count],[is_user_transaction],
                [is_local],[is_enlisted],[is_bound],[open_transaction_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[t].[session_id],[t].[transaction_id],
                [t].[transaction_descriptor],[t].[enlist_count],[t].[is_user_transaction],
                [t].[is_local],[t].[is_enlisted],[t].[is_bound],[t].[open_transaction_count]
            FROM [sys].[dm_tran_session_transactions] AS [t] WITH (NOLOCK)
            WHERE EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_Sessions] AS [s]
                WHERE [s].[SnapshotId]=@SnapshotId
                  AND [s].[session_id]=[t].[session_id]
            );

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,110,'SESSION_TRANSACTIONS',N'sys.dm_tran_session_transactions',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,110,'SESSION_TRANSACTIONS',N'sys.dm_tran_session_transactions',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_ActiveTransactions]
            (
                [SnapshotId],[CapturedAtUtc],[transaction_id],[name],
                [transaction_begin_time],[transaction_type],[transaction_uow],
                [transaction_state],[transaction_status]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[t].[transaction_id],[t].[name],
                [t].[transaction_begin_time],[t].[transaction_type],[t].[transaction_uow],
                [t].[transaction_state],[t].[transaction_status]
            FROM [sys].[dm_tran_active_transactions] AS [t] WITH (NOLOCK)
            WHERE EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_SessionTransactions] AS [st]
                WHERE [st].[SnapshotId]=@SnapshotId
                  AND [st].[transaction_id]=[t].[transaction_id]
            );

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,120,'ACTIVE_TRANSACTIONS',N'sys.dm_tran_active_transactions',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,120,'ACTIVE_TRANSACTIONS',N'sys.dm_tran_active_transactions',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentOverview_CurrentStateSnapshot_DatabaseTransactions]
            (
                [SnapshotId],[CapturedAtUtc],[transaction_id],[database_id],
                [database_transaction_begin_time],[database_transaction_type],
                [database_transaction_state],[database_transaction_log_record_count],
                [database_transaction_log_bytes_used],[database_transaction_log_bytes_reserved],
                [database_transaction_log_bytes_used_system],
                [database_transaction_log_bytes_reserved_system]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[t].[transaction_id],[t].[database_id],
                [t].[database_transaction_begin_time],[t].[database_transaction_type],
                [t].[database_transaction_state],[t].[database_transaction_log_record_count],
                [t].[database_transaction_log_bytes_used],[t].[database_transaction_log_bytes_reserved],
                [t].[database_transaction_log_bytes_used_system],
                [t].[database_transaction_log_bytes_reserved_system]
            FROM [sys].[dm_tran_database_transactions] AS [t] WITH (NOLOCK)
            WHERE EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_SessionTransactions] AS [st]
                WHERE [st].[SnapshotId]=@SnapshotId
                  AND [st].[transaction_id]=[t].[transaction_id]
            );

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,130,'DATABASE_TRANSACTIONS',N'sys.dm_tran_database_transactions',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,130,'DATABASE_TRANSACTIONS',N'sys.dm_tran_database_transactions',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureTempDbUsage=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            EXEC [sys].[sp_executesql] N'
                USE [tempdb];
                INSERT [#CurrentOverview_CurrentStateSnapshot_TempDbSessionUsage]
                (
                    [SnapshotId],[CapturedAtUtc],[session_id],
                    [user_objects_alloc_page_count],[user_objects_dealloc_page_count],
                    [internal_objects_alloc_page_count],[internal_objects_dealloc_page_count]
                )
                SELECT
                    @SnapshotId,@CapturedAtUtc,[u].[session_id],
                    [u].[user_objects_alloc_page_count],[u].[user_objects_dealloc_page_count],
                    [u].[internal_objects_alloc_page_count],[u].[internal_objects_dealloc_page_count]
                FROM [sys].[dm_db_session_space_usage] AS [u] WITH (NOLOCK)
                WHERE EXISTS
                (
                    SELECT 1
                    FROM [#CurrentOverview_CurrentStateSnapshot_Sessions] AS [s]
                    WHERE [s].[SnapshotId]=@SnapshotId
                      AND [s].[session_id]=[u].[session_id]
                );',
                N'@SnapshotId uniqueidentifier,@CapturedAtUtc datetime2(3)',
                @SnapshotId=@SnapshotId,@CapturedAtUtc=@CapturedAtUtc;

            SET @RowCount=
                (SELECT COUNT_BIG(*) FROM [#CurrentOverview_CurrentStateSnapshot_TempDbSessionUsage]
                 WHERE [SnapshotId]=@SnapshotId);
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,140,'TEMPDB_SESSION_USAGE',N'tempdb.sys.dm_db_session_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,140,'TEMPDB_SESSION_USAGE',N'tempdb.sys.dm_db_session_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            EXEC [sys].[sp_executesql] N'
                USE [tempdb];
                INSERT [#CurrentOverview_CurrentStateSnapshot_TempDbTaskUsage]
                (
                    [SnapshotId],[CapturedAtUtc],[session_id],[request_id],[exec_context_id],
                    [user_objects_alloc_page_count],[user_objects_dealloc_page_count],
                    [internal_objects_alloc_page_count],[internal_objects_dealloc_page_count]
                )
                SELECT
                    @SnapshotId,@CapturedAtUtc,[u].[session_id],[u].[request_id],[u].[exec_context_id],
                    [u].[user_objects_alloc_page_count],[u].[user_objects_dealloc_page_count],
                    [u].[internal_objects_alloc_page_count],[u].[internal_objects_dealloc_page_count]
                FROM [sys].[dm_db_task_space_usage] AS [u] WITH (NOLOCK)
                WHERE EXISTS
                (
                    SELECT 1
                    FROM [#CurrentOverview_CurrentStateSnapshot_Requests] AS [r]
                    WHERE [r].[SnapshotId]=@SnapshotId
                      AND [r].[session_id]=[u].[session_id]
                      AND [r].[request_id]=[u].[request_id]
                );',
                N'@SnapshotId uniqueidentifier,@CapturedAtUtc datetime2(3)',
                @SnapshotId=@SnapshotId,@CapturedAtUtc=@CapturedAtUtc;

            SET @RowCount=
                (SELECT COUNT_BIG(*) FROM [#CurrentOverview_CurrentStateSnapshot_TempDbTaskUsage]
                 WHERE [SnapshotId]=@SnapshotId);
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,150,'TEMPDB_TASK_USAGE',N'tempdb.sys.dm_db_task_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,@BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,150,'TEMPDB_TASK_USAGE',N'tempdb.sys.dm_db_task_space_usage',
             @CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureSqlText=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            CREATE TABLE [#InternalCaptureCurrentStateSnapshot_SqlHandleCandidate]
            (
                [SqlHandle] varbinary(64) NOT NULL PRIMARY KEY
            );

            INSERT [#InternalCaptureCurrentStateSnapshot_SqlHandleCandidate]([SqlHandle])
            SELECT [h].[SqlHandle]
            FROM
            (
                SELECT [r].[sql_handle] AS [SqlHandle]
                FROM [#CurrentOverview_CurrentStateSnapshot_Requests] AS [r]
                WHERE [r].[SnapshotId]=@SnapshotId
                  AND [r].[sql_handle] IS NOT NULL
                UNION
                SELECT [c].[most_recent_sql_handle]
                FROM [#CurrentOverview_CurrentStateSnapshot_Connections] AS [c]
                WHERE [c].[SnapshotId]=@SnapshotId
                  AND [c].[most_recent_sql_handle] IS NOT NULL
            ) AS [h];

            DECLARE @SqlTextCandidateCount bigint=
                (SELECT COUNT_BIG(*) FROM [#InternalCaptureCurrentStateSnapshot_SqlHandleCandidate]);

            IF @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles
            BEGIN
                ;WITH [Limited] AS
                (
                    SELECT
                        [SqlHandle],
                        [RowNumber]=ROW_NUMBER() OVER(ORDER BY [SqlHandle])
                    FROM [#InternalCaptureCurrentStateSnapshot_SqlHandleCandidate]
                )
                DELETE FROM [Limited]
                WHERE [RowNumber]>@MaxSqlTextHandles;
            END;

            INSERT [#CurrentOverview_CurrentStateSnapshot_SqlText]
            (
                [SnapshotId],[CapturedAtUtc],[SqlHandle],[Text],[DatabaseId],
                [ObjectId],[ObjectNumber],[IsEncrypted],[EvidenceStatus]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[h].[SqlHandle],[t].[text],[t].[dbid],
                [t].[objectid],[t].[number],[t].[encrypted],
                CONVERT(varchar(40),CASE WHEN [t].[text] IS NULL THEN 'TEXT_UNAVAILABLE' ELSE 'AVAILABLE' END)
            FROM [#InternalCaptureCurrentStateSnapshot_SqlHandleCandidate] AS [h]
            OUTER APPLY [sys].[dm_exec_sql_text]([h].[SqlHandle]) AS [t];

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            SET @IsPartial=CASE WHEN @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles THEN 1 ELSE @BaseIsPartial END;
            SET @StatusCode=CASE WHEN @IsPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END;
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,80,'SQL_TEXT',N'sys.dm_exec_sql_text',@CapturedAtUtc,@CompletedAtUtc,
             @StatusCode,@IsPartial,@RowCount,NULL,
             CASE WHEN @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles
                  THEN N'Die Zahl unterschiedlicher SQL-Handles überschritt @MaxSqlTextHandles.'
                  ELSE NULL END);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,80,'SQL_TEXT',N'sys.dm_exec_sql_text',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

END;
GO
