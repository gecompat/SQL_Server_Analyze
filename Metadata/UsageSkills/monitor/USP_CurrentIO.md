---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentIO"
schema_name: "monitor"
object_name: "USP_CurrentIO"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Führt eine leichtgewichtige serverweite Datei-I/O-Analyse mit optionalem Delta-Sampling und expliziter Datenbankeinschränkung durch."
source_path: "Code/02_CurrentState/080_USP_CurrentIO.sql"
---

# monitor.USP_CurrentIO

## Zweck und Einsatz

Führt eine leichtgewichtige serverweite Datei-I/O-Analyse mit optionalem Delta-Sampling und expliziter Datenbankeinschränkung durch.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentIO]. Die Quelle nennt insbesondere `sys.dm_io_virtual_file_stats`, `master.sys.databases`, `[monitor].[InternalPrepareResultTables]`, `[sys].[sp_executesql]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[dm_io_virtual_file_stats]`, `[sys].[dm_io_pending_io_requests]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MinLatencyMs | decimal(19,3) | nein | 0 |
| @SampleSeconds | tinyint | nein | 0 |
| @PendingIoEinbeziehen | bit | nein | 1 |
| @NurWiederholtPending | bit | nein | 0 |
| @MinPendingIoMs | bigint | nein | 0 |
| @PhysischePfadeEinbeziehen | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@DatabaseNames:** @DatabaseNames nvarchar(max), Default=NULL; Eingabe: bracket-aware Pipe-Liste exakter, einteiliger Datenbanknamen, z. B. N'[DbA]|[DbB]'; Namen werden case-sensitive verglichen. Ausgelassen/NULL/leer/nur Leerzeichen wählt alle sichtbaren, zugreifbaren, ONLINE befindlichen Benutzerdatenbanken; doppelte oder ungültige Namen erzeugen Auswahlfehler/Warnings, Systemdatenbanken benötigen das Opt-in. Exklusiv mit @DatabaseNamePattern. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit, Default=0; Schalter: 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren, zugreifbaren ONLINE Datenbanken zusätzlich. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000), Default=NULL; Eingabe: genau ein nichtleeres Pattern, exklusiv mit @DatabaseNames. Kein Präfix oder like: bedeutet case-sensitive SQL-LIKE mit %, _, [...]; regex: case-sensitive regulärer Ausdruck; regexi: case-insensitive regulärer Ausdruck. Präfixerkennung ist case-insensitive, äußere Leerzeichen werden entfernt, Patterninhalt bleibt erhalten. NULL/ausgelassen deaktiviert, leer/Whitespace/Präfix ohne Pattern ist ungültig. regex/regexi benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.

**@HighImpactConfirmed:** @HighImpactConfirmed bit, Default=0; numerischer Schalter: 0/ausgelassen bestätigt nicht, jeder numerische Wert ungleich 0 wird vor Eintritt zu 1 und bestätigt dann. NULL wird wegen ungenutztem Parameter nicht geprüft. Dieser Parameter wird von dieser Procedure nicht gelesen/weitergereicht; tatsächlicher Zugriff bleibt STANDARD_CURRENT ohne High-Impact-Bestätigungsprüfung.

**@MinLatencyMs:** @MinLatencyMs decimal(19,3), Default=0 ms; nichtnegative Mindest-Durchschnittslatenz je Datei aus kumulativen Zählern oder Sample-Deltas. Ausgelassen verwendet 0; NULL oder negativer Wert ist INVALID_PARAMETER. Bei null Lese- und Schreiboperationen ist OverallLatencyMs NULL und besteht den Filter nicht.

**@SampleSeconds:** @SampleSeconds tinyint, Default=0 Sekunden; ganze Zahl 0..60. 0 nutzt kumulative Counter und einen Pending-Punkt; 1..60 wartet per WAITFOR DELAY zwischen zwei Dateimessungen und bildet Deltas sowie zwei Pending-Beobachtungen. Ausgelassen nutzt 0; NULL ist INVALID_PARAMETER. Laufzeit/Scheduling können Abstand verlängern; Counterreset erhält keinen eigenen Resetstatus.

**@PendingIoEinbeziehen:** @PendingIoEinbeziehen bit, Default=1; 1 liest Pending-I/O und Schedulerkontext, 0 überspringt beide Quellen und liefert leere Pending-Menge. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Quellfehler lassen Dateiwerte bestehen und können Status/IsPartial setzen.

**@NurWiederholtPending:** @NurWiederholtPending bit, Default=0; 1 verlangt dieselbe Requestadresse in beiden Beobachtungen und setzt @SampleSeconds=1..60 voraus; 0 genügt Sichtbarkeit am letzten Messpunkt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Bei 0-Sample ist Wiederholung nicht nachgewiesen.

**@MinPendingIoMs:** @MinPendingIoMs bigint, Default=0 ms; nichtnegative Untergrenze für dm_io_pending_io_requests.PendingDurationMs, informational/internal Enginewert. Ausgelassen ergibt 0; NULL oder negativ ist INVALID_PARAMETER. Einzelwert beweist weder Fehler noch Ursache.

**@PhysischePfadeEinbeziehen:** @PhysischePfadeEinbeziehen bit, Default=0; 1 gibt pendingIo.PhysicalPath aus, wenn auflösbar; 0 unterdrückt dieses optionale Pfadfeld, während files.PhysicalName bleibt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER.

**@MaxZeilen:** @MaxZeilen int, Default=1000 Zeilen; ganze Zahl 0..2147483647. NULL oder 0 ist unbegrenzt; positiv begrenzt Datei- und Pending-Kandidaten getrennt nach ihrer Sortierung (N+1-Prüfung), CONSOLE zusätzlich mit gemeinsamem TOP, Pending zuerst. Negativ ist INVALID_PARAMETER. Ausgelassen ergibt 1000; beschränkt nicht die instanzweite DMV-Erhebung.

**@ResultSetArt:** @ResultSetArt varchar(16), Default='CONSOLE'; nach Trim/UPPER taxativ CONSOLE (gemeinsames 10-Spalten-Evidenzgrid), RAW (moduleStatus 13, sourceStatus 10, files 19, pendingIo 20, warnings 3 Spalten), TABLE (nur angeforderte benannte Temp-Tabellenexporte), NONE (keine Resultsets). Ausgelassen ergibt CONSOLE; NULL/leer normalisiert zu '' und ist ungültig. Andere Werte INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default=NULL; nur TABLE: JSON-Objekt mit einer nichtleeren Teilmenge der exakten Keys moduleStatus (Modulstatus), sourceStatus (Quellstatus), files (Dateimessungen), pendingIo (offene E/A-Anforderungen), warnings (Warnungen); jeder Wert ist ein lokaler #Temp-Zielname als JSON-String. Ziel muss vorhanden und leer sein und genau eine Seed-Platzhalterspalte besitzen; Zuordnung wird vor semantischer Parameterprüfung validiert, ungültig wirft 51011. Bei anderem Modus nur NULL/leer, sonst 51011. Ausgelassen/NULL oder leer ist nur außerhalb TABLE zulässig; TABLE benötigt die nichtleere Zuordnung.

**@JsonErzeugen:** @JsonErzeugen bit, Default=0; 1 erzeugt zusätzlich JSON unabhängig von @ResultSetArt; 0 deaktiviert es. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. JSON enthält meta, sourceStatus, files, pendingIo, warnings, aber kein moduleStatus-Array.

**@Json:** @Json nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable gleichen Typs, beim Aufruf mit OUTPUT zu binden. Procedure setzt sie beim Eintritt auf NULL; bei @JsonErzeugen=1 empfängt sie das Dokument, bei 0 bleibt sie NULL. Ausgelassen ist zulässig, wenn JSON-Ausgabe nicht benötigt wird.

**@PrintMeldungen:** @PrintMeldungen bit, Default=1; 1 sendet Severity-10-Status-/Quellmeldungen, 0 unterdrückt nur Meldungen. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Status, Resultsets, Warnings und JSON bleiben davon unberührt.

**@Hilfe:** @Hilfe bit, Default=0; 1 druckt Hilfe und kehrt vor Parameter-, Snapshot- und Fachquellenprüfung zurück; @Json wird zuvor auf NULL gesetzt. 0 führt Normalpfad aus. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Numerische Eingaben werden vor Eintritt in bit konvertiert, jeder Wert ungleich 0 wird 1.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId uniqueidentifier, Default=NULL; NULL/ausgelassen erhebt Kontext direkt. GUID muss zur laufenden USP_CurrentOverview-Ausführung derselben Session (OwnerSessionId=@@SPID, ContractVersion=2) gehören; sonst INVALID_PARENT_SNAPSHOT. Bei gültiger ID und aktiviertem Pending stammen Kontext und Startzeit vom Parent, Datei-/Pending-DMVs bleiben live.

## Resultate und Ausgabe

CONSOLE ein gemeinsames Evidenz-Grid; RAW und TABLE verwenden moduleStatus, sourceStatus, files, pendingIo und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CollectionTimeUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [HasMoreRows] bit NOT NULL , [CrossDatabaseRequested] bit NOT NULL , [SampleSeconds] tinyint NOT NULL , [PendingIoRequested] bit NOT NULL , [PendingIoRowCount] bigint NOT NULL , [PendingIoHasMoreRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL PRIMARY KEY , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| files | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FileId] int NOT NULL , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SampleSeconds] int NOT NULL , [Reads] bigint NOT NULL , [ReadBytes] bigint NOT NULL , [ReadStallMs] bigint NOT NULL , [Writes] bigint NOT NULL , [WriteBytes] bigint NOT NULL , [WriteStallMs] bigint NOT NULL , [ReadLatencyMs] decimal(19,3) NULL , [WriteLatencyMs] decimal(19,3) NULL , [OverallLatencyMs] decimal(19,3) NULL , [ReadThroughputMbPerSecond] decimal(19,3) NULL , [WriteThroughputMbPerSecond] decimal(19,3) NULL , [SizeOnDiskMb] decimal(19,2) NULL |
| pendingIo | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [RequestAddress] varbinary(8) NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [FileId] int NULL , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhysicalPath] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IoType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PendingLayer] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PendingDurationMs] bigint NOT NULL , [SchedulerId] int NULL , [RequestCountOnScheduler] int NULL , [IoWaitTaskCountOnScheduler] int NULL , [WasPresentInFirstSample] bit NOT NULL , [ObservationCount] tinyint NOT NULL , [FirstSamplePendingMs] bigint NULL , [IoOffset] bigint NOT NULL , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CorrelationScope] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| warnings | 1 | 1 | [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentIO] @SampleSeconds=5, @MaxZeilen=100, @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentIO — Datei-I/O-Sicht für sichtbare Online-Datenbanken.

Quellen: master.sys.databases/master_files, sys.dm_io_virtual_file_stats (ein Aufruf je Messpunkt), optional dm_io_pending_io_requests sowie Scheduler-/Request-/Task-/Wait-Kontext. Der Datenbankfilter beschränkt behaltene Zeilen, nicht den instanzweiten DMV-Aufruf.

Für den Aufruf gelten EXECUTE-Recht und die installierte STANDARD_CURRENT-Zugriffsrichtlinie; erforderliche DMV-Rechte hängen von SQL Server-Version und Konfiguration ab. Rechte werden nicht vergeben. Abgefangene Fehler stehen in Status/Quellstatus und können die Ausgabe partiell machen.

Bit-Parameter werden vor Eintritt in die Procedure in bit konvertiert; numerische Werte ungleich 0 werden dabei zu 1. Die beschriebenen NULL-Prüfungen gelten für den bereits konvertierten Wert.

Modulstatus AVAILABLE bedeutet verfügbare Quellen ohne Auswahlwarnungen; AVAILABLE_LIMITED kennzeichnet Auswahl- oder Pending-Kontextlücken. INVALID_PARAMETER und INVALID_PARENT_SNAPSHOT lehnen die Fachauswertung ab; Quellfehler werden als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED ausgewiesen. Regex auf älteren Engines/Kompatibilitätsstufen liefert UNAVAILABLE_FEATURE.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentIO
Version      : 4.0.0
Stand        : 2026-07-23
Zweck        : Führt eine leichtgewichtige serverweite Datei-I/O-Analyse mit
               optionalem Delta-Sampling und expliziter
               Datenbankeinschränkung durch.
Datenbanken  : Standardmäßig alle sichtbaren, online befindlichen
               Benutzerdatenbanken; kein CURRENT-Scope und keine Vorabgrenze.
DMV-Zugriff  : sys.dm_io_virtual_file_stats(NULL,NULL) genau einmal je
               Messzeitpunkt; keine Wiederholung pro Datenbank.
Pending I/O  : Optional zwei Beobachtungen derselben aktuell ausstehenden
               Requestadresse. Scheduler-/Taskbezug ist Kontext, keine kausale
               1:1-Zuordnung. io_pending_ms_ticks ist informational/internal.
Ausgabe      : CONSOLE ein gemeinsames Evidenz-Grid; RAW und TABLE verwenden
               moduleStatus, sourceStatus, files, pendingIo und warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentIO — Datei-I/O-Sicht für sichtbare Online-Datenbanken.
Quellen: master.sys.databases/master_files, sys.dm_io_virtual_file_stats (ein Aufruf je Messpunkt), optional dm_io_pending_io_requests sowie Scheduler-/Request-/Task-/Wait-Kontext. Der Datenbankfilter beschränkt behaltene Zeilen, nicht den instanzweiten DMV-Aufruf.
Für den Aufruf gelten EXECUTE-Recht und die installierte STANDARD_CURRENT-Zugriffsrichtlinie; erforderliche DMV-Rechte hängen von SQL Server-Version und Konfiguration ab. Rechte werden nicht vergeben. Abgefangene Fehler stehen in Status/Quellstatus und können die Ausgabe partiell machen.
Bit-Parameter werden vor Eintritt in die Procedure in bit konvertiert; numerische Werte ungleich 0 werden dabei zu 1. Die beschriebenen NULL-Prüfungen gelten für den bereits konvertierten Wert.
Modulstatus AVAILABLE bedeutet verfügbare Quellen ohne Auswahlwarnungen; AVAILABLE_LIMITED kennzeichnet Auswahl- oder Pending-Kontextlücken. INVALID_PARAMETER und INVALID_PARENT_SNAPSHOT lehnen die Fachauswertung ab; Quellfehler werden als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED ausgewiesen. Regex auf älteren Engines/Kompatibilitätsstufen liefert UNAVAILABLE_FEATURE.
NULL-Werte in Parametern, die explizit validiert werden, führen zu INVALID_PARAMETER; @HighImpactConfirmed ist die Ausnahme, weil es ungenutzt bleibt. Fehlerhafte Datenbankauswahl liefert Status/Warnings; partielle Quellfehler sind in sourceStatus und IsPartial erkennbar. Ein leeres Resultset beweist nicht, dass keine I/O-Aktivität stattfand.
Beispiel — CONSOLE im Standard-Datenbankscope:
Beispiel — TABLE, nur files; Ziel vorab frisch anlegen, danach lesen und entfernen:
CREATE TABLE #CurrentIO_HelpExample (Placeholder int NULL);
DROP TABLE #CurrentIO_HelpExample;
Beispiel — JSON ohne Resultsets; @Json bleibt als OUTPUT verfügbar:
DECLARE @CurrentIO_HelpJson nvarchar(max);
```

