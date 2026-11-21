---
skill_format_version: "1.0.0"
name: "monitor.USP_ResourceGovernorAnalysis"
schema_name: "monitor"
object_name: "USP_ResourceGovernorAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Trennt Resource-Governor-Konfiguration, Laufzeitkennzahlen und die SQL-Server-2025-TempDB-Governance je Workload Group."
source_path: "Code/07_Infrastructure/030_USP_ResourceGovernorAnalysis.sql"
---

# monitor.USP_ResourceGovernorAnalysis

## Zweck und Einsatz

Trennt Resource-Governor-Konfiguration, Laufzeitkennzahlen und die SQL-Server-2025-TempDB-Governance je Workload Group.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer; TempDB-Governance ab 2025 (17.x).

sys.resource_governor_configuration, sys.dm_resource_governor_configuration, sys.resource_governor_resource_pools, sys.dm_resource_governor_resource_pools, sys.resource_governor_workload_groups, sys.dm_resource_governor_workload_groups, sys.dm_exec_sessions, master.sys.master_files.

Nur lesender Zugriff. Das Framework vergibt keine Rechte und ändert weder Resource Governor noch TempDB.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitSessions | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitSessions:** @MitSessions bit. Default ist 1. 1 erfasst sichtbare Benutzerprozesse aus sys.dm_exec_sessions und ordnet sie nach GroupId zu. 0 überspringt die Quelle und die Sessionausgabe in RAW und CONSOLE. JSON enthält dann ein leeres sessions-Array. NULL ergibt INVALID_PARAMETER.

**@MaxZeilen:** @MaxZeilen int. Default ist 5000. Eine positive ganze Zahl begrenzt Pools, Workload Groups, tempdbGovernance und Sessions jeweils separat. NULL oder 0 hebt die Grenze auf. Negative Werte ergeben INVALID_PARAMETER. Die Konfigurationszeile bleibt unberührt. Sessions werden vor der Gruppenzuordnung nach CPU-Zeit absteigend und SessionId begrenzt.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt beschriftete Fachergebnisse. RAW gibt zuerst Status und Metadaten, dann die Daten und Warnungen aus. TABLE schreibt nur zugeordnete Fachergebnisse in lokale Temp-Tabellen. NONE unterdrückt diese Ausgaben. Leerzeichen am Rand werden entfernt und Groß-/Kleinschreibung wird normalisiert. NULL, leere Eingaben und alle anderen Werte ergeben INVALID_PARAMETER. JSON und Statusmeldungen werden separat gesteuert.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt erforderlich. Die exakten Schlüssel sind configuration für Konfiguration, resourcePools für Pools, workloadGroups für Gruppen, sessions für Sessions und tempdbGovernance für TempDB-Limits und Laufzeitevidenz. Wählen Sie mindestens einen Schlüssel. Jeder Wert ist der Name einer vorhandenen leeren lokalen #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. ## und #Monitor als Präfix sind unzulässig. Doppelte Schlüssel und Ziele sind unzulässig. Die Vorprüfung erfolgt vor dem Lesen der fachlichen Quellen. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt das JSON-Dokument unabhängig von @ResultSetArt. 0 lässt @Json auf NULL. NULL ergibt INVALID_PARAMETER.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Die Procedure setzt den Wert vor Hilfe und Validierung auf NULL. Bei @JsonErzeugen=1 erhält die Variable das Dokument der SchemaVersion 2 mit Metadaten, Konfiguration, Pools, Gruppen, TempDB-Governance, Sessions und Warnungen einschließlich NULL-Feldern.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei einem Status ungleich AVAILABLE eine informative Meldung mit Schweregrad 10 aus. 0 oder NULL unterdrückt diese Meldung.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt diese Hilfe und beendet den Aufruf vor Validierung, TABLE-Vorprüfung, fachlichen Quellzugriffen und JSON-Erzeugung. 0 oder NULL führt die Analyse aus.

## Resultate und Ausgabe

configuration, resourcePools, workloadGroups, sessions, tempdbGovernance und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| configuration | 1 | 1 | [ClassifierFunctionId] int NULL , [IsEnabled] bit NULL , [ReconfigurationPending] bit NULL , [ClassifierFunctionName] nvarchar(517) NULL |
| resourcePools | 1 | 1 | [PoolId] int NOT NULL , [PoolName] sysname NOT NULL , [MinCpuPercent] int NULL , [MaxCpuPercent] int NULL , [MinMemoryPercent] int NULL , [MaxMemoryPercent] int NULL , [CapCpuPercent] int NULL , [MinIopsPerVolume] int NULL , [MaxIopsPerVolume] int NULL , [StatisticsStartTime] datetime NULL , [TotalCpuUsageMs] bigint NULL , [CacheMemoryMb] decimal(19,2) NULL , [UsedWorkspaceMemoryMb] decimal(19,2) NULL , [TargetWorkspaceMemoryMb] decimal(19,2) NULL , [MaxWorkspaceMemoryMb] decimal(19,2) NULL , [OutOfMemoryCount] bigint NULL , [ActiveMemgrantCount] int NULL , [PendingMemgrantCount] int NULL , [UsedOfTargetMemoryPercent] decimal(9,2) NULL , [UsedOfMaxMemoryPercent] decimal(9,2) NULL |
| workloadGroups | 1 | 1 | [GroupId] int NOT NULL , [GroupName] sysname NOT NULL , [PoolId] int NULL , [PoolName] sysname NULL , [Importance] nvarchar(60) NULL , [RequestMaxMemoryGrantPercent] decimal(9,4) NULL , [ConfiguredRequestMaxGrantMemoryMb] decimal(19,2) NULL , [TargetRequestMaxGrantMemoryMb] decimal(19,2) NULL , [HistoricalMaxRequestGrantMemoryMb] decimal(19,2) NULL , [RequestMaxCpuTimeSec] int NULL , [RequestMemoryGrantTimeoutSec] int NULL , [MaxDop] int NULL , [EffectiveMaxDop] int NULL , [GroupMaxRequests] int NULL , [TotalRequestCount] bigint NULL , [TotalQueuedRequestCount] bigint NULL , [ActiveRequestCount] int NULL , [QueuedRequestCount] int NULL , [TotalReducedMemgrantCount] bigint NULL , [TotalCpuUsageMs] bigint NULL , [TotalLockWaitCount] bigint NULL , [TotalLockWaitTimeMs] bigint NULL |
| sessions | 1 | 1 | [SessionId] int NOT NULL , [LoginName] sysname NULL , [HostName] nvarchar(128) NULL , [ProgramName] nvarchar(128) NULL , [GroupId] int NULL , [GroupName] sysname NULL , [PoolName] sysname NULL , [Status] nvarchar(60) NULL , [CpuTimeMs] int NULL , [MemoryUsagePages] int NULL , [MemoryUsageMb] decimal(19,2) NULL , [Reads] bigint NULL , [Writes] bigint NULL , [LogicalReads] bigint NULL |
| tempdbGovernance | 1 | 1 | [GroupId] int NULL , [GroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PoolId] int NULL , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ConfiguredGroupMaxTempdbDataMb] decimal(19,2) NULL , [ConfiguredGroupMaxTempdbDataPercent] decimal(9,4) NULL , [TempdbMaximumSizeMb] decimal(19,2) NULL , [EffectiveGroupMaxTempdbDataMb] decimal(19,2) NULL , [EffectiveLimitSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPercentLimitEffective] bit NULL , [TempdbDataSpaceMb] decimal(19,2) NULL , [PeakTempdbDataSpaceMb] decimal(19,2) NULL , [EffectiveLimitUtilizationPercent] decimal(9,2) NULL , [TotalTempdbDataLimitViolationCount] bigint NULL , [HasRecordedLimitViolation] bit NULL , [StatisticsStartTime] datetime NULL , [IsResourceGovernorEnabled] bit NULL , [ReconfigurationPending] bit NULL , [SourceStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ResourceGovernorAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ResourceGovernorAnalysis

Die Procedure zeigt die Resource-Governor-Konfiguration, Pools, Workload Groups und optional zugeordnete Benutzersessions. Die TempDB-Ausgabe trennt konfigurierte Limits, Wirksamkeit, Nutzung, Peak und Verletzungen. Die Procedure führt weder ALTER RESOURCE GOVERNOR noch RECONFIGURE oder RESET STATISTICS aus.

Hilfe anzeigen. EXEC [monitor].[USP_ResourceGovernorAnalysis] @Hilfe=1;

RAW ohne Sessionabfrage. EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=0, @MaxZeilen=100, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @GovernorJson nvarchar(max); EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=0, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@GovernorJson OUTPUT; SELECT @GovernorJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ResourceGovernorAnalysis
Version      : 3.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Trennt Resource-Governor-Konfiguration, Laufzeitkennzahlen und
               die SQL-Server-2025-TempDB-Governance je Workload Group.
SQL-Version  : SQL Server 2019 oder neuer; TempDB-Governance ab 2025 (17.x).
Datenquellen : sys.resource_governor_configuration,
               sys.dm_resource_governor_configuration,
               sys.resource_governor_resource_pools,
               sys.dm_resource_governor_resource_pools,
               sys.resource_governor_workload_groups,
               sys.dm_resource_governor_workload_groups,
               sys.dm_exec_sessions, master.sys.master_files.
Parameter    : @MitSessions, @MaxZeilen, @ResultSetArt, @ResultTablesJson,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Resultsets   : configuration, resourcePools, workloadGroups, sessions,
               tempdbGovernance und warnings.
Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte und
               ändert weder Resource Governor noch TempDB.
Eigenlast    : Gering bis mittel; jede fachliche Quelle höchstens einmal.
Locking      : LOCK_TIMEOUT 0 für Quellen; vorheriger Sessionwert wird
               auch nach TABLE- und CONSOLE-Ausgabe wiederhergestellt.
Änderungen   : 3.0.0 - SQL25-003: gespeicherte Limits, wirksames Limit,
                         aktuelle/Peak-Nutzung, Verletzungen und Resetgrenze.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ResourceGovernorAnalysis
Die Procedure zeigt die Resource-Governor-Konfiguration, Pools, Workload Groups und optional zugeordnete Benutzersessions. Die TempDB-Ausgabe trennt konfigurierte Limits, Wirksamkeit, Nutzung, Peak und Verletzungen. Die Procedure führt weder ALTER RESOURCE GOVERNOR noch RECONFIGURE oder RESET STATISTICS aus.
Hilfe anzeigen. EXEC [monitor].[USP_ResourceGovernorAnalysis] @Hilfe=1;
RAW ohne Sessionabfrage. EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=0, @MaxZeilen=100, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @GovernorJson nvarchar(max); EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=0, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@GovernorJson OUTPUT; SELECT @GovernorJson AS [Json];
Konfigurationszeile in eine lokale Temp-Tabelle schreiben. CREATE TABLE #ResourceGovernorAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=0, @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"configuration":"#ResourceGovernorAnalysis_HelpExample"}'; SELECT * FROM #ResourceGovernorAnalysis_HelpExample; DROP TABLE #ResourceGovernorAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ResourceGovernorAnalysis_HelpExample; THROW; END CATCH;
```

