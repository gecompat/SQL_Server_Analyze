---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabaseSnapshotInventory"
schema_name: "monitor"
object_name: "USP_DatabaseSnapshotInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen."
source_path: "Code/08_ServerHealth/340_USP_DatabaseSnapshotInventory.sql"
---

# monitor.USP_DatabaseSnapshotInventory

## Zweck und Einsatz

Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseSnapshotInventory]. Die Quelle nennt insbesondere `master.sys.databases`, `master.sys.master_files`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SnapshotNames | nvarchar(max) | nein | NULL |
| @NurOnline | bit | nein | 1 |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @LockTimeoutMs | int | nein | 0 |
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

**@SnapshotNames:** @SnapshotNames nvarchar(max)=NULL: NULL, leer oder nur äußere U+0020-Leerzeichen wählen alle sichtbaren Snapshots. Sonst bracket-aware Pipe-Liste einteiliger exakter Snapshotnamen; | in [...] ist Namensinhalt, ]] maskiert ]. Rohsegment höchstens 4000 UTF-16-Einheiten, Name höchstens 128 Zeichen; ungültige, leere oder case-sensitive doppelte Elemente sind INVALID_PARAMETER. Kein Patternparameter.

**@NurOnline:** @NurOnline bit=1: 1 wählt nur ONLINE-Snapshots, 0 alle caller-sichtbaren Katalogzustände; NULL ist INVALID_PARAMETER. Numerisch ungleich 0 wird als bit 1 konvertiert.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0: 0 schließt Snapshots mit SourceDatabaseId bis 4 aus, 1 lässt zulässige Systemquellen zu. NULL ist INVALID_PARAMETER; numerisch ungleich 0 wird als bit 1 konvertiert.

**@MaxZeilen:** @MaxZeilen int=1000: positiv begrenzt Snapshot-Zeilen nach SnapshotDatabaseId; alle sichtbaren Dateizeilen jedes ausgegebenen Snapshots bleiben erhalten. NULL/0 unbegrenzt, negativ INVALID_PARAMETER. Die vorgelagerte Katalogarbeit wird nicht begrenzt.

**@LockTimeoutMs:** @LockTimeoutMs int=0: 0 bis 60000 Millisekunden je Katalogbatch, 0 bedeutet NOWAIT; NULL, negativ oder größer 60000 INVALID_PARAMETER. Kein Gesamtlaufzeitbudget; der vorherige Sessionwert wird wiederhergestellt.

**@ResultSetArt:** @ResultSetArt varchar(16)=CONSOLE: SQL Server bindet einen längeren Eingabewert vor Validierung auf höchstens 16 Zeichen. Nach Trim/Großschreibung nur CONSOLE, RAW, TABLE, NONE; NULL/leer INVALID_PARAMETER. RAW liefert moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings; TABLE schreibt benannte Ziele; CONSOLE eine formatierte Menge; NONE keine Resultsets.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL: nur TABLE nimmt ein JSON-Objekt mit mindestens einer Zuordnung an. Exakte Schlüssel: moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings. Werte: unterschiedliche rohe lokale #Temp-Namen, höchstens 116 Zeichen, weder ## noch reserviertes #Monitor-Praefix. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft. Ungültige, doppelte oder unbekannte Zuordnungen werden vor der Quellenlesung abgewiesen; ein späterer Writerfehler kann schon geschriebene Ziele hinterlassen. Außerhalb TABLE nur NULL/leer/U+0020-Leerzeichen.

**@JsonErzeugen:** @JsonErzeugen bit=0: 1 erzeugt unabhängig vom Ausgabemodus JSON mit meta und fünf Arrays; NULL/0 kein JSON. Numerisch ungleich 0 wird 1.

**@Json:** @Json nvarchar(max)=NULL OUTPUT: optional mit OUTPUT binden; Eingang wird auf NULL gesetzt, ohne @JsonErzeugen=1 entsteht kein Wert.

**@PrintMeldungen:** @PrintMeldungen bit=1: 1 meldet nur einen äußeren CATCH-Fehler zusätzlich als konstante Severity-10-Meldung WITH NOWAIT; NULL/0 unterdrückt diese Meldung, numerisch ungleich 0 wird 1. Hilfe, direkte Eingabefehler und behandelte Quellenfehler erzeugen dadurch keine zusätzliche Meldung.

**@Hilfe:** @Hilfe bit=0: 1 druckt Hilfe vor Temp-DDL/Katalogzugriff, auch in einer Caller-Transaktion; NULL/0 normaler Pfad.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT: optional; AVAILABLE nur Hilfe, AVAILABLE_LIMITED sichtbare Aufnahme, SKIPPED keine sichtbare Auswahl, INVALID_PARAMETER Eingabe, SOURCE_UNAVAILABLE fehlende Dateisicht/Quellenfehler, DENIED_PERMISSION nativer Rechtefehler, TIMEOUT SQL 1222, ERROR_HANDLED äußerer Fehler.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT: optional; normaler Pfad 1 wegen Caller-Sicht, Hilfe 0.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT: optional; nativer Fehler oder 51011 bei direktem Eingabefehler; sonst NULL.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT: optional; Fehlertext höchstens 2048 Zeichen, bei Erfolg NULL.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| snapshots | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceDatabaseId] int NOT NULL, [SourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CatalogCreateDate] datetime NOT NULL, [SnapshotStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsReadOnly] bit NULL, [VisibleSparseFileCount] bigint NULL, [FileMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| snapshotFiles | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [FileId] int NOT NULL, [LogicalFileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsSparse] bit NOT NULL, [FileStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MaximumSnapshotSizePages] int NOT NULL, [MaximumSnapshotSizeBytes] bigint NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabaseSnapshotInventory] @SnapshotNames=N'[ExampleSnapshot]',@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine physische Belegung, Gesundheit, Restore-Eignung oder globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot- Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DatabaseSnapshotInventory
Version      : 1.0.0
Stand        : 2026-11-15
Zweck        : Inventarisiert caller-sichtbare Datenbank-Snapshots und
               ihre caller-sichtbaren Dateikatalogzeilen.
Quellen      : master.sys.databases, master.sys.master_files.
Grenzen      : Keine physische Belegung, Gesundheit, Restore-Eignung oder
               globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot-
               Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabaseSnapshotInventory: caller-sichtbare Snapshot- und Dateikatalogmetadaten ohne persistente Datenbank- oder Snapshot-Aenderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
Es werden weder physische Sparse-Dateibelegung noch Snapshot-Gesundheit oder Restore-Eignung gemessen. create_date ist ein nativer lokaler Katalogwert und kann sich bei Umbenennung ändern; size ist nur maximale Snapshot-Dateikapazität in 8-KiB-Seiten. Die zwei Kataloglesungen sind nicht atomar.
```

