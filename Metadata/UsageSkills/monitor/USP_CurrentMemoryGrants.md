---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentMemoryGrants"
schema_name: "monitor"
object_name: "USP_CurrentMemoryGrants"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert aktuell wartende und gewährte Query Memory Grants sowie Resource-Governor-, Pool- und Semaphore-Grenzen."
source_path: "Code/02_CurrentState/060_USP_CurrentMemoryGrants.sql"
---

# monitor.USP_CurrentMemoryGrants

## Zweck und Einsatz

Liefert aktuell wartende und gewährte Query Memory Grants sowie Resource-Governor-, Pool- und Semaphore-Grenzen.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_exec_query_memory_grants, sys.dm_exec_sessions, sys.dm_exec_requests, sys.dm_exec_sql_text, sys.databases, sys.dm_resource_governor_workload_groups, sys.dm_resource_governor_resource_pools, sys.dm_exec_query_resource_semaphores.

VIEW SERVER STATE (2019) bzw. VIEW SERVER PERFORMANCE STATE.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @AktuelleSessionEinbeziehen | bit | nein | 0 |
| @NurWartende | bit | nein | 0 |
| @MinRequestedMb | decimal(19,2) | nein | NULL |
| @MinGrantedMb | decimal(19,2) | nein | NULL |
| @MitSqlText | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 3000 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: Typ nvarchar(max); Default=NULL. NULL oder ausgelassen deaktiviert den Sessionfilter. Nicht-NULL wird durch TVF_ParseBigintList verarbeitet: Komma und Semikolon werden zuerst global in Pipe umgewandelt; Pipe trennt danach außerhalb eckiger Klammern, innerhalb maskiert ]] eine schließende Klammer. Außenleerzeichen je Segment werden getrimmt. Leerer String ergibt EMPTY_LIST; nur Leerzeichen oder leere Segmente EMPTY_ITEM; fehlerhafte Klammern INVALID_BRACKET_SYNTAX; Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Klammerquotierung wird nicht entfernt: IDs in [...] sind keine gültige Zahl. TRY_CONVERT(bigint) muss erfolgreich sein und jede ID muss 1 bis 32767 sein; andernfalls Status INVALID_PARAMETER. Gültige doppelte IDs werden gruppiert. Pipe, Komma und Semikolon sind einzeln oder gemischt zulässig.

**@AktuelleSessionEinbeziehen:** @AktuelleSessionEinbeziehen: Typ bit; Default=0. Ausgelassen entspricht 0. 0 schließt @@SPID aus; 1 erlaubt die aufrufende Session. NULL ist nicht als ungültig markiert und schließt die eigene Session durch das SQL-Prädikat ebenfalls aus; andere Session-IDs bleiben davon unberührt. Eingaben werden vor Eintritt nach bit konvertiert (numerisch 0→0, jeder numerische Nichtnullwert→1).

**@NurWartende:** @NurWartende: Typ bit; Default=0. Ausgelassen entspricht 0. 0 lässt gewährte und wartende Grants passieren; 1 filtert auf grant_time IS NULL. NULL ist nicht als ungültig markiert; das Prädikat lässt dadurch wartende Zeilen passieren, während gewährte Zeilen ausgeschlossen werden. Numerische Eingaben werden nach bit konvertiert (0→0, Nichtnull→1).

**@MinRequestedMb:** @MinRequestedMb: Typ decimal(19,2), Einheit MB; Default=NULL. NULL oder ausgelassen deaktiviert diese Untergrenze. Ein nichtnegativer Wert n filtert mit requested_memory_kb >= n * 1024.0, also einschließlich Gleichheit. Negative Werte führen zu INVALID_PARAMETER. Der Eingabebereich ist der SQL-Datentyp decimal(19,2); die Konvertierung in diesen Typ erfolgt vor Ausführung.

**@MinGrantedMb:** @MinGrantedMb: Typ decimal(19,2), Einheit MB; Default=NULL. NULL oder ausgelassen deaktiviert diese Untergrenze. Ein nichtnegativer Wert n filtert mit granted_memory_kb >= n * 1024.0, also einschließlich Gleichheit. Die Bedingung wird auch auf wartende Grants angewendet; deren gewährte Speichergröße kann NULL sein, sodass sie bei gesetztem Grenzwert nicht passieren. Negative Werte führen zu INVALID_PARAMETER. Der Eingabebereich ist decimal(19,2).

**@MitSqlText:** @MitSqlText: Typ bit; Default=1. Ausgelassen entspricht 1. 1 löst Statementtext über den vorhandenen SQL-Text-/Snapshotkontext auf und projiziert ihn; 0 lässt die SQL-Textquelle aus und CurrentStatement bleibt NULL. NULL ist nicht ungültig, aber IF-Wirkungen wie bei 0 (Text wird nicht eingelesen). Numerische Eingaben werden nach bit konvertiert: 0→0, Nichtnull→1.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: Typ int; Default=3000 Zeichen. Ein positiver Wert begrenzt jeden ausgegebenen Statementtext auf höchstens diese Zahl Unicode-Zeichen (SC-Zeichen zählen gemäß SC-Collation); der Helper liefert zusätzlich Originalzeichen, Originalbytes und Kürzungskennzeichen. NULL oder 0 bedeutet unbegrenzte Textlänge; negativ ergibt INVALID_PARAMETER. Ausgelassen verwendet 3000. int-Grenzen gelten nach SQL-Konvertierung; bei @MitSqlText=0 ist keine Textprojektion betroffen.

**@MaxZeilen:** @MaxZeilen: Typ int; Default=1000 Datenzeilen. Positives n wählt höchstens n Zeilen und materialisiert regulär bis zu n+1 Kandidaten, um HasMoreRows/ResultLimited vor dem Zuschnitt zu bestimmen. Bei int-Maximum 2147483647 wird n+1 nicht berechnet; die Kandidatenobergrenze bleibt dann n. NULL oder 0 bedeutet unbegrenzt und setzt die effektive Obergrenze auf bigint-Maximum; negativ ergibt INVALID_PARAMETER. Die ausgewählte Fachmenge gilt für RAW, CONSOLE, TABLE-Export und JSON; NONE unterdrückt Resultsets.

**@ResultSetArt:** @ResultSetArt: Typ varchar(16); Default='CONSOLE'. Eingabe wird mit LTRIM/RTRIM außen getrimmt, COALESCE(NULL, leer) und UPPER normalisiert. Exakt CONSOLE (lesbare Ansicht, einschließlich Leerfallansicht), RAW (Modulstatus- und Datenresultset), TABLE (benanntes Resultset memoryGrants in das konfigurierte Ziel) und NONE (keine fachlichen Resultsets) sind zulässig. Die Schreibweise ist dadurch case-insensitiv; leere oder andere Werte liefern INVALID_PARAMETER. Bei NULL entsteht leer und somit INVALID_PARAMETER. Ein nichtleeres @ResultTablesJson außerhalb TABLE löst davor Fehler 51011 aus.

**@ResultTablesJson:** @ResultTablesJson: Typ nvarchar(max); Default=NULL. Bei @ResultSetArt=TABLE muss das JSON ein Objekt mit genau dem erlaubten Schlüssel memoryGrants und einem JSON-String als Ziel enthalten; JSON-Schlüssel und erlaubter Ergebnisname werden nach Konvertierung zu sysname byte-/case-sensitiv verglichen. Exakte doppelte Schlüssel sind ungültig; doppelte Zielnamen werden unter Latin1_General_100_CI_AS erkannt. NULL/ausgelassen, ein leeres Objekt, unbekannte oder anders geschriebene Schlüssel, Nicht-Stringwerte sowie nach LTRIM/RTRIM leere Schlüssel/Zielwerte führen zum TABLE-Preflightfehler. LTRIM/RTRIM entfernt hier gewöhnliche U+0020-Leerzeichen; Tabs und andere Whitespacezeichen werden dadurch nicht als leer behandelt. Das Ziel muss mit # beginnen, darf nicht ## beginnen, höchstens 116 nach LEN gemessene Zeichen lang sein und darf nicht mit #Monitor beginnen (case-insensitive). Es muss im aktuellen Sessionkontext existieren, leer sein und genau eine Seed-Platzhalterspalte besitzen; der Preflight prüft dies durch temporäres Hinzufügen/Entfernen einer Spalte. Außerhalb TABLE sind NULL, ausgelassen, leerer String und nur U+0020-Leerzeichen erlaubt; ein nach LTRIM/RTRIM nichtleerer Wert (auch Tabs) löst vor Hilfe/Analyse Fehler 51011 aus. Die TABLE-Zuordnungswache und der Preflight laufen vor Hilfe und vor fachlichen Quellenzugriffen.

**@JsonErzeugen:** @JsonErzeugen: Typ bit; Default=0. Ausgelassen entspricht 0. 0 unterdrückt die JSON-Erzeugung; 1 erzeugt unabhängig von ResultSetArt ein JSON-Envelope in @Json. NULL ist nicht ungültig und wirkt wegen IF (@JsonErzeugen=1) wie deaktiviert. Numerische Eingaben werden vor Eintritt nach bit konvertiert (0→0, Nichtnull→1).

**@Json:** @Json: Typ nvarchar(max), OUTPUT; Default=NULL. Als OUTPUT-Variable zu binden; beim Eintritt setzt die Procedure den Ausgabewert zunächst auf NULL. Bei @JsonErzeugen=1 erhält die Variable das JSON-Envelope mit meta, memoryGrants und warnings, einschließlich NULL-Properties; bei 0 oder NULL in @JsonErzeugen bleibt sie NULL. Der Eingabewert ist kein Filter und wird überschrieben.

**@PrintMeldungen:** @PrintMeldungen: Typ bit; Default=1. Ausgelassen entspricht 1. 1 lässt Statusmeldungen bei Status ungleich AVAILABLE und Textkürzungswarnungen ausgeben; beide Wege verwenden RAISERROR mit Severity 10 und WITH NOWAIT (der Textkürzungshelper übernimmt denselben Schalter), keine PRINT-Ausgabe. 0 und NULL unterdrücken diese Meldungen, nicht Resultsets oder strukturierte Status-/Warningdaten. Numerische Eingaben werden vor Eintritt nach bit konvertiert (0→0, Nichtnull→1).

**@Hilfe:** @Hilfe: Typ bit; Default=0. Ausgelassen entspricht 0. 1 druckt die Hilfe und kehrt vor Analyse und Datenquellenzugriff zurück; zuvor ausgeführte TABLE-Zuordnungswache und TABLE-Preflight bleiben wirksam, ebenso die Wache für nichtleeres Mapping außerhalb TABLE. 0 führt die Analyse aus. NULL wirkt wie 0. Numerische Eingaben werden nach bit konvertiert (0→0, Nichtnull→1).

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: Typ uniqueidentifier; Default=NULL. NULL oder ausgelassen liest die Live-DMVs eigenständig und erzeugt eine eigene Snapshot-ID. Eine UUID bindet an den materialisierten Snapshot des aktuellen USP_CurrentOverview-Aufrufs: erforderliche lokale Snapshot-Temp-Tabellen müssen mit kompatiblem Schema vorhanden sein; Context muss die UUID, @@SPID als OwnerSessionId und ContractVersion=2 enthalten. Daten werden aus MemoryGrants, ResourceSemaphores, Sessions, Requests, WorkloadGroups und ResourcePools geladen; SqlText-Daten werden nur bei @MitSqlText=1 geladen. Für Zeitbezug und Partialität werden die SourceStatus von MEMORY_GRANTS, RESOURCE_SEMAPHORES, SESSIONS, REQUESTS, WORKLOAD_GROUPS, RESOURCE_POOLS und SQL_TEXT stets berücksichtigt. Der SQL_TEXT-Status kann daher auch bei @MitSqlText=0 Zeitbezug und Partialität beeinflussen, obwohl die Textdaten nicht geladen werden. Eine fehlende, fremde oder inkompatible Bindung führt zu INVALID_PARENT_SNAPSHOT beziehungsweise strukturiertem Fehler. Es gibt in diesem Pfad keine Ablaufprüfung oder garantierte Frischegrenze. Erfordert die Berechtigung der Parent-Materialisierung sowie die erforderliche DMV-Berechtigung; Sichtbarkeit und Vollständigkeit richten sich nach Quellstatus und Berechtigungen. Parent-Zeitbezug ist die früheste CapturedAtUtc-Quellzeit, daher kann er älter sein als der Child-Aufruf.

## Resultate und Ausgabe

RAW = stabile technische Resultsets; CONSOLE = formatierte, menschenlesbare Darstellung; NONE = keine Resultsets. @JsonErzeugen=1 erzeugt unabhängig davon ein JSON-Envelope.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| memoryGrants | 1 | 1 | [SessionId] smallint NULL , [RequestId] int NULL , [SchedulerId] int NULL , [Dop] smallint NULL , [RequestTime] datetime NULL , [GrantTime] datetime NULL , [WaitTimeMs] bigint NULL , [IsWaiting] bit NOT NULL , [IsSmall] bit NULL , [RequestedMemoryMb] decimal(19,2) NULL , [RequiredMemoryMb] decimal(19,2) NULL , [GrantedMemoryMb] decimal(19,2) NULL , [UsedMemoryMb] decimal(19,2) NULL , [MaxUsedMemoryMb] decimal(19,2) NULL , [IdealMemoryMb] decimal(19,2) NULL , [GroupId] int NULL , [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PoolId] int NULL , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ResourceSemaphoreId] smallint NULL , [RequestMaxMemoryGrantPercent] decimal(9,4) NULL , [PoolMaxWorkspaceMemoryMb] decimal(19,2) NULL , [PoolTargetWorkspaceMemoryMb] decimal(19,2) NULL , [PoolUsedWorkspaceMemoryMb] decimal(19,2) NULL , [ConfiguredRequestMaxGrantMemoryMb] decimal(19,2) NULL , [TargetRequestMaxGrantMemoryMb] decimal(19,2) NULL , [HistoricalMaxRequestGrantMemoryMb] decimal(19,2) NULL , [RequestedOfRequestMaxPercent] decimal(9,2) NULL , [GrantedOfRequestMaxPercent] decimal(9,2) NULL , [UsedOfRequestMaxPercent] decimal(9,2) NULL , [MaxUsedOfRequestMaxPercent] decimal(9,2) NULL , [IdealOfRequestMaxPercent] decimal(9,2) NULL , [RequestedOfTargetMaxPercent] decimal(9,2) NULL , [GrantedOfTargetMaxPercent] decimal(9,2) NULL , [UsedOfGrantedPercent] decimal(9,2) NULL , [MaxUsedOfGrantedPercent] decimal(9,2) NULL , [SemaphoreTargetMemoryMb] decimal(19,2) NULL , [SemaphoreMaxTargetMemoryMb] decimal(19,2) NULL , [SemaphoreTotalMemoryMb] decimal(19,2) NULL , [SemaphoreAvailableMemoryMb] decimal(19,2) NULL , [SemaphoreGrantedMemoryMb] decimal(19,2) NULL , [SemaphoreUsedMemoryMb] decimal(19,2) NULL , [SemaphoreGranteeCount] int NULL , [SemaphoreWaiterCount] int NULL , [ReservedWorkerCount] bigint NULL , [UsedWorkerCount] bigint NULL , [MaxUsedWorkerCount] bigint NULL , [QueueId] smallint NULL , [WaitOrder] int NULL , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DatabaseId] smallint NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ElapsedMs] int NULL , [CpuMs] int NULL , [LogicalReads] bigint NULL , [CurrentStatementCharacters] bigint NULL , [CurrentStatementBytes] bigint NULL , [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0) , [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentMemoryGrants] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentMemoryGrants

Erfasst aktuell sichtbare gewährte und wartende Query-Memory-Grants samt Request-, Workload-Group-, Resource-Pool- und Semaphore-Kontext aus SQL-Server-DMVs. Die Ausgabe ist eine Momentaufnahme; NULL-Kontext bedeutet, dass ein Zusatzwert nicht aufgelöst wurde, und ist kein Beleg für einen Nullzustand der Quelle.

Beide MB-Untergrenzen wirken gemeinsam, wenn sie gesetzt sind. Negative Werte sind ungültig; NULL wird bei der Prüfung wie keine Untergrenze behandelt.

Für DMV-Zugriffe gilt laut Modulvertrag VIEW SERVER STATE oder VIEW SERVER PERFORMANCE STATE, wie die Procedure es im Metadatenfeld requiredPermission ausweist. Die tatsächliche Sichtbarkeit kann von Umgebung und ergänzenden Metadatenzugriffen abhängen; fehlende Werte bleiben strukturiert oder NULL.

CONSOLE-Beispiel:


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentMemoryGrants
Version      : 3.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Liefert aktuell wartende und gewährte Query Memory Grants sowie
               Resource-Governor-, Pool- und Semaphore-Grenzen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_query_memory_grants, sys.dm_exec_sessions,
               sys.dm_exec_requests, sys.dm_exec_sql_text, sys.databases,
               sys.dm_resource_governor_workload_groups,
               sys.dm_resource_governor_resource_pools,
               sys.dm_exec_query_resource_semaphores.
Parameter    : @SessionIds, @AktuelleSessionEinbeziehen, @NurWartende,
               @MinRequestedMb, @MinGrantedMb, @MitSqlText,
               @MaxSqlTextZeichen, @MaxZeilen, @ResultSetArt,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Ausgabe      : RAW = stabile technische Resultsets; CONSOLE = formatierte,
               menschenlesbare Darstellung; NONE = keine Resultsets.
               @JsonErzeugen=1 erzeugt unabhängig davon ein JSON-Envelope.
Berechtigung : VIEW SERVER STATE (2019) bzw. VIEW SERVER PERFORMANCE STATE.
Eigenlast    : Gering; die DMV enthält nur aktuelle Grants/Anforderungen.
Locking      : Keine Benutzerobjekte.
Partial      : Fehlender SQL-Text oder nicht auflösbare Zusatzmetadaten bleiben
               NULL; Fehler werden strukturiert ausgegeben.
Beispiele    : EXEC monitor.USP_CurrentMemoryGrants;
               EXEC monitor.USP_CurrentMemoryGrants
                    @NurWartende=1,@ResultSetArt='console';
               DECLARE @J nvarchar(max);
               EXEC monitor.USP_CurrentMemoryGrants
                    @ResultSetArt='none',@JsonErzeugen=1,@Json=@J OUTPUT;
               SELECT @J AS [Json];
Änderungen   : 2.0.0 - Resource-Governor-Grenzen und Prozentkennzahlen ergänzt;
                         RAW/CONSOLE/NONE sowie JSON-Envelope eingeführt.
               1.0.0 - Erstfassung Phase 1B.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentMemoryGrants
Erfasst aktuell sichtbare gewährte und wartende Query-Memory-Grants samt Request-, Workload-Group-, Resource-Pool- und Semaphore-Kontext aus SQL-Server-DMVs. Die Ausgabe ist eine Momentaufnahme; NULL-Kontext bedeutet, dass ein Zusatzwert nicht aufgelöst wurde, und ist kein Beleg für einen Nullzustand der Quelle.
Beide MB-Untergrenzen wirken gemeinsam, wenn sie gesetzt sind. Negative Werte sind ungültig; NULL wird bei der Prüfung wie keine Untergrenze behandelt.
Für DMV-Zugriffe gilt laut Modulvertrag VIEW SERVER STATE oder VIEW SERVER PERFORMANCE STATE, wie die Procedure es im Metadatenfeld requiredPermission ausweist. Die tatsächliche Sichtbarkeit kann von Umgebung und ergänzenden Metadatenzugriffen abhängen; fehlende Werte bleiben strukturiert oder NULL.
CONSOLE-Beispiel:
TABLE-Beispiel:
DECLARE @Tables nvarchar(max)=N'{"memoryGrants":"#CurrentMemoryGrants_HelpExample"}'; CREATE TABLE #CurrentMemoryGrants_HelpExample([Placeholder] int); EXEC [monitor].[USP_CurrentMemoryGrants] @ResultSetArt='TABLE',@ResultTablesJson=@Tables; SELECT * FROM [#CurrentMemoryGrants_HelpExample]; DROP TABLE [#CurrentMemoryGrants_HelpExample];
JSON-Beispiel:
DECLARE @J nvarchar(max); EXEC [monitor].[USP_CurrentMemoryGrants] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT; SELECT @J AS [Json];
Das Envelope enthält meta, memoryGrants und warnings.
```

