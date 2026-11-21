---
skill_format_version: "1.0.0"
name: "monitor.USP_WorkerPressureAnalysis"
schema_name: "monitor"
object_name: "USP_WorkerPressureAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure korreliert Scheduler- und Worker-Verfügbarkeit, THREADPOOL- und CPU-Runnable-Queues, Blocking und begrenzte laufende Requests in einem kurzen Sample."
source_path: "Code/08_ServerHealth/180_USP_WorkerPressureAnalysis.sql"
---

# monitor.USP_WorkerPressureAnalysis

## Zweck und Einsatz

Die Procedure korreliert Scheduler- und Worker-Verfügbarkeit, THREADPOOL- und CPU-Runnable-Queues, Blocking und begrenzte laufende Requests in einem kurzen Sample.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_WorkerPressureAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[sys].[dm_os_sys_info]`, `[sys].[configurations]`, `[sys].[dm_os_schedulers]`, `[sys].[dm_os_workers]`, `[sys].[dm_os_waiting_tasks]`, `[sys].[dm_exec_requests]`, `sys.dm_os_schedulers` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SampleSeconds | tinyint | nein | 1 |
| @MinRequestElapsedMs | int | nein | 5000 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@SampleSeconds:** @SampleSeconds tinyint; Default: 1. Legt das Scheduler-Sample in Sekunden fest. Zulässig sind 0 bis 60. 0 verwendet eine Scheduleraufnahme und liefert keine Deltas; 1 bis 60 warten für die angegebene Dauer zwischen zwei Scheduleraufnahmen und berechnen daraus Deltas. Worker-, Wait- und Requestdaten bleiben Snapshots am Sampleende. NULL ist ungültig.

**@MinRequestElapsedMs:** @MinRequestElapsedMs int; Default: 5000. Schließt aktuelle Requests ab dieser Laufzeit in Millisekunden in den Requestkontext ein. Zulässig sind 0 bis 2.147.483.647; 0 nimmt alle aktuellen Requests auf, sofern sie nicht bereits wegen THREADPOOL oder Blocking erfasst werden. THREADPOOL- und blockierte Requests werden unabhängig von diesem Mindestwert berücksichtigt. Der Wert begrenzt weder die Sampledauer noch die Gesamtzahl der Serverrequests. NULL ist ungültig.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Begrenzt nur die ausgegebenen Requestzeilen, nicht Scheduler, Waits oder andere Gruppen. Ein positiver Wert ist die Höchstzahl; 0 oder NULL bedeutet unbegrenzt. Negative Werte sind ungültig. Für Werte von 1 bis 2.147.483.646 werden höchstens eine zusätzliche Requestzeile als Kürzungssentinel materialisiert und danach entfernt; die Ausgabe priorisiert THREADPOOL, danach blockierte Requests, danach lange Requests und sortiert innerhalb der Gruppen nach Laufzeit absteigend. Bei 2.147.483.647 gilt die Integer-Obergrenze; es wird keine zusätzliche Sentinelzeile angefordert. Der Statusdatensatz weist eine erkannte Kürzung über HasMoreRequestRows aus.

**@ResultSetArt:** @ResultSetArt unterstützt CONSOLE, RAW, TABLE und NONE. JSON wird unabhängig über @JsonErzeugen und @Json angefordert.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Enthält eine TABLE-Zuordnung als JSON-Objekt, etwa {"summary":"#WorkerSummary"}. Erlaubte Namen: moduleStatus, summary, schedulers, waits, requests, sourceStatus, warnings. Ziele müssen vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein; globale Tabellen, reservierte #Monitor-Namen, unbekannte Namen sowie doppelte Zuordnungen oder Ziele werden abgewiesen. Außerhalb von TABLE akzeptiert die Validierung NULL, leeren Text oder nur U+0020-Leerzeichen; jeder andere nichtleere Wert ist ungültig. In TABLE muss der gemeinsame Preflight ein gültiges nichtleeres Mapping und passende Seed-Tabellen validieren. Zielnamen sind höchstens 116 Zeichen lang. Der Preflight prüft die Zuordnung und Ziele; der spätere Writer ersetzt die Seed-Spalte durch das Ergebnisschema. Die Gruppen bedeuten: moduleStatus Modulstatus, summary Zusammenfassung, schedulers Schedulerwerte, waits Wartegruppen, requests Requestkontext, sourceStatus Quellenstatus, warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt das JSON-Dokument unabhängig von @ResultSetArt. NULL ist ungültig. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. Das Dokument enthält meta, summary, schedulers, waits, requests, sourceStatus und warnings; requests folgt dem Zeilenlimit.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für das optionale JSON-Dokument. Wird am Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Ein gebundener Variablenwert kann mit OUTPUT empfangen werden; das Argument darf ausgelassen werden, wenn kein JSON benötigt wird.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Steuert nur die Zusatzmeldung mit RAISERROR-Schweregrad 10 und NOWAIT bei einem Status ungleich AVAILABLE. 0 unterdrückt die Meldung, 1 gibt sie aus; Resultsets und OUTPUT-Werte bleiben unabhängig. NULL ist ungültig. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. Bei 1 wird die PRINT-Hilfe ausgegeben und vor Validierung sowie Fachabfragen zurückgekehrt. @Json ist zu diesem Zeitpunkt NULL; Status-OUTPUT-Parameter werden nicht zugewiesen. Bei 0 oder NULL läuft die normale Analyse. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Status im normalen Analysepfad: AVAILABLE bedeutet keine Teilquellenwarnung; AVAILABLE_LIMITED kennzeichnet mindestens eine eingeschränkte Quelle; INVALID_PARAMETER bezeichnet ungültige Parameter; DENIED_PERMISSION meldet verweigerte Schedulerquelle; TIMEOUT meldet ein Scheduler-Timeout; ERROR_HANDLED meldet einen sonstigen abgefangenen Schedulerfehler. Fehler der Worker-, Wait- und Requestquellen werden als Teilstatus/Warnungen aggregiert und ergeben typischerweise AVAILABLE_LIMITED. Im Hilfe-Pfad erfolgt keine Zuweisung. Das OUTPUT-Argument kann ausgelassen werden, wenn der Status nicht empfangen werden soll.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bit: 0 für AVAILABLE, 1 bei AVAILABLE_LIMITED oder Fehlerstatus. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener NULL-Eingang bleibt NULL, ein anderer Anfangswert unverändert. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Fehlernummer, sofern für eine maßgebliche Warnung oder einen Schedulerfehler verfügbar, sonst NULL. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener Anfangswert bleibt erhalten. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Fehler- oder Hinweismeldung, sofern vorhanden, sonst NULL. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener Anfangswert bleibt erhalten. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [SampleSeconds] tinyint NOT NULL , [ReturnedSchedulerRows] bigint NOT NULL , [ReturnedRequestRows] bigint NOT NULL , [HasMoreRequestRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |
| summary | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [SampleStartUtc] datetime2(3) NOT NULL , [SampleEndUtc] datetime2(3) NOT NULL , [SampleSeconds] decimal(19,6) NOT NULL , [VisibleOnlineSchedulers] int NULL , [ConfiguredMaxWorkerThreads] int NULL , [EffectiveMaxWorkers] int NULL , [CurrentWorkerCount] int NULL , [AvailableWorkerCapacity] int NULL , [WorkerOccupancyPercent] decimal(9,2) NULL , [TotalWorkQueueCount] bigint NULL , [TotalRunnableTasks] bigint NULL , [MaxWorkQueuePerScheduler] bigint NULL , [MaxRunnablePerScheduler] int NULL , [ThreadpoolWaitingTaskCount] bigint NULL , [BlockingRequestCount] bigint NULL , [LongRequestCount] bigint NULL , [FailedToCreateWorkerSchedulers] int NULL , [FindingCode] varchar(80) NOT NULL , [Interpretation] nvarchar(1000) NOT NULL |
| schedulers | 1 | 1 | [SchedulerId] int NOT NULL , [ParentNodeId] int NOT NULL , [CpuId] smallint NOT NULL , [Status] nvarchar(60) NOT NULL , [SampleSeconds] decimal(19,6) NOT NULL , [CurrentTasks] int NOT NULL , [RunnableTasks] int NOT NULL , [CurrentWorkers] int NOT NULL , [ActiveWorkers] int NOT NULL , [WorkQueueCount] bigint NOT NULL , [PendingDiskIoCount] int NOT NULL , [WorkerCountFromWorkerDmv] int NULL , [RunningWorkers] int NULL , [RunnableWorkers] int NULL , [SuspendedWorkers] int NULL , [PreemptiveWorkers] int NULL , [SickWorkers] int NULL , [WorkQueueDelta] bigint NULL , [RunnableTasksDelta] int NULL , [CurrentWorkersDelta] int NULL , [ActiveWorkersDelta] int NULL , [ContextSwitchDelta] bigint NULL , [YieldDelta] bigint NULL , [CpuUsageDeltaMs] bigint NULL , [SchedulerDelayDeltaMs] bigint NULL , [CounterResetDetected] bit NOT NULL , [FailedToCreateWorker] bit NULL , [IdealWorkersLimit] int NULL , [FindingCode] varchar(80) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| waits | 1 | 1 | [WaitType] nvarchar(60) NOT NULL , [WaitingTaskCount] bigint NOT NULL , [MaxWaitDurationMs] bigint NOT NULL , [BlockedTaskCount] bigint NOT NULL , [FindingCode] varchar(80) NOT NULL |
| requests | 1 | 1 | [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [SchedulerId] int NULL , [RequestStatus] nvarchar(30) NOT NULL , [Command] nvarchar(32) NOT NULL , [ElapsedMs] int NOT NULL , [CpuMs] int NOT NULL , [LogicalReads] bigint NOT NULL , [Reads] bigint NOT NULL , [Writes] bigint NOT NULL , [Dop] smallint NULL , [BlockingSessionId] smallint NULL , [WaitType] nvarchar(60) NULL , [WaitTimeMs] int NOT NULL , [ContextReason] varchar(80) NOT NULL , PRIMARY KEY([SessionId],[RequestId]) |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL PRIMARY KEY , [SourceName] sysname NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int IDENTITY(1,1) NOT NULL , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_WorkerPressureAnalysis] @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_WorkerPressureAnalysis

Analysiert Workerbedarf, Scheduler-Queues, THREADPOOL-Waits, Blocking und ausgewählte aktuelle Requests.

Bei positivem Sample entstehen Deltas aus zwei Scheduleraufnahmen; Worker, Waits und Requests sind Momentaufnahmen am Sampleende.

work_queue_count zeigt Schedulerarbeit ohne verfügbaren Worker; runnable_tasks_count zeigt Tasks in der CPU-Schedulerwarteschlange. Die Befunde sind Momentaufnahmen und belegen weder Ursache noch Dauer.

SQL-, Plan-, Login-, Host- und Programmnamen werden nicht gelesen. Ein einzelner Befund empfiehlt keine automatische Änderung von max worker threads.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_WorkerPressureAnalysis
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Die Procedure korreliert Scheduler- und Worker-Verfügbarkeit,
               THREADPOOL- und CPU-Runnable-Queues, Blocking und begrenzte
               laufende Requests in einem kurzen Sample.
Zeitvertrag  : Zwei Schedulerbeobachtungen bei @SampleSeconds>0; Worker, Waits
               und Requests sind flüchtige Snapshots am Sampleende.
Abgrenzung   : work_queue_count bedeutet fehlenden Worker; runnable_tasks_count
               bedeutet CPU-Warteschlange. Kein Befund empfiehlt automatisch
               eine Änderung von max worker threads.
Eigenlast    : Ein aggregierter Scan von dm_os_workers sowie kleine Scheduler-,
               Wait- und Request-Snapshots; keine SQL- oder Plantexte.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_WorkerPressureAnalysis
Analysiert Workerbedarf, Scheduler-Queues, THREADPOOL-Waits, Blocking und ausgewählte aktuelle Requests.
Bei positivem Sample entstehen Deltas aus zwei Scheduleraufnahmen; Worker, Waits und Requests sind Momentaufnahmen am Sampleende.
work_queue_count zeigt Schedulerarbeit ohne verfügbaren Worker; runnable_tasks_count zeigt Tasks in der CPU-Schedulerwarteschlange. Die Befunde sind Momentaufnahmen und belegen weder Ursache noch Dauer.
SQL-, Plan-, Login-, Host- und Programmnamen werden nicht gelesen. Ein einzelner Befund empfiehlt keine automatische Änderung von max worker threads.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_WorkerPressureAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE #WorkerPressureAnalysis_HelpExample (Seed int NULL);
DECLARE @TableMap nvarchar(max)=N'{"summary":"#WorkerPressureAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_WorkerPressureAnalysis] @SampleSeconds=0, @ResultSetArt='TABLE', @ResultTablesJson=@TableMap;
    SELECT * FROM #WorkerPressureAnalysis_HelpExample;
    DROP TABLE IF EXISTS #WorkerPressureAnalysis_HelpExample;
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #WorkerPressureAnalysis_HelpExample;
    THROW;
END CATCH;
```

