USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseSnapshotInventory
Version      : 1.0.0
Stand        : 2026-11-15
Zweck        : Inventarisiert caller-sichtbare Datenbank-Snapshots und
               ihre caller-sichtbaren Dateikatalogzeilen.
Quellen      : master.sys.databases, master.sys.master_files.
Grenzen      : Keine physische Belegung, Gesundheit, Restore-Eignung oder
               globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot-
               Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_DatabaseSnapshotInventory 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_DatabaseSnapshotInventory"
-- schema_name: "monitor"
-- object_name: "USP_DatabaseSnapshotInventory"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen."
-- source_path: "Code/08_ServerHealth/340_USP_DatabaseSnapshotInventory.sql"
-- ---
-- 
-- # monitor.USP_DatabaseSnapshotInventory
-- 
-- ## Zweck und Einsatz
-- 
-- Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseSnapshotInventory]. Die Quelle nennt insbesondere `master.sys.databases`, `master.sys.master_files`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SnapshotNames | nvarchar(max) | nein | NULL |
-- | @NurOnline | bit | nein | 1 |
-- | @SystemdatenbankenEinbeziehen | bit | nein | 0 |
-- | @MaxZeilen | int | nein | 1000 |
-- | @LockTimeoutMs | int | nein | 0 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- 
-- **@SnapshotNames:** @SnapshotNames nvarchar(max)=NULL: NULL, leer oder nur äußere U+0020-Leerzeichen wählen alle sichtbaren Snapshots. Sonst bracket-aware Pipe-Liste einteiliger exakter Snapshotnamen; | in [...] ist Namensinhalt, ]] maskiert ]. Rohsegment höchstens 4000 UTF-16-Einheiten, Name höchstens 128 Zeichen; ungültige, leere oder case-sensitive doppelte Elemente sind INVALID_PARAMETER. Kein Patternparameter.
-- 
-- **@NurOnline:** @NurOnline bit=1: 1 wählt nur ONLINE-Snapshots, 0 alle caller-sichtbaren Katalogzustände; NULL ist INVALID_PARAMETER. Numerisch ungleich 0 wird als bit 1 konvertiert.
-- 
-- **@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0: 0 schließt Snapshots mit SourceDatabaseId bis 4 aus, 1 lässt zulässige Systemquellen zu. NULL ist INVALID_PARAMETER; numerisch ungleich 0 wird als bit 1 konvertiert.
-- 
-- **@MaxZeilen:** @MaxZeilen int=1000: positiv begrenzt Snapshot-Zeilen nach SnapshotDatabaseId; alle sichtbaren Dateizeilen jedes ausgegebenen Snapshots bleiben erhalten. NULL/0 unbegrenzt, negativ INVALID_PARAMETER. Die vorgelagerte Katalogarbeit wird nicht begrenzt.
-- 
-- **@LockTimeoutMs:** @LockTimeoutMs int=0: 0 bis 60000 Millisekunden je Katalogbatch, 0 bedeutet NOWAIT; NULL, negativ oder größer 60000 INVALID_PARAMETER. Kein Gesamtlaufzeitbudget; der vorherige Sessionwert wird wiederhergestellt.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16)=CONSOLE: SQL Server bindet einen längeren Eingabewert vor Validierung auf höchstens 16 Zeichen. Nach Trim/Großschreibung nur CONSOLE, RAW, TABLE, NONE; NULL/leer INVALID_PARAMETER. RAW liefert moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings; TABLE schreibt benannte Ziele; CONSOLE eine formatierte Menge; NONE keine Resultsets.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL: nur TABLE nimmt ein JSON-Objekt mit mindestens einer Zuordnung an. Exakte Schlüssel: moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings. Werte: unterschiedliche rohe lokale #Temp-Namen, höchstens 116 Zeichen, weder ## noch reserviertes #Monitor-Praefix. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft. Ungültige, doppelte oder unbekannte Zuordnungen werden vor der Quellenlesung abgewiesen; ein späterer Writerfehler kann schon geschriebene Ziele hinterlassen. Außerhalb TABLE nur NULL/leer/U+0020-Leerzeichen.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit=0: 1 erzeugt unabhängig vom Ausgabemodus JSON mit meta und fünf Arrays; NULL/0 kein JSON. Numerisch ungleich 0 wird 1.
-- 
-- **@Json:** @Json nvarchar(max)=NULL OUTPUT: optional mit OUTPUT binden; Eingang wird auf NULL gesetzt, ohne @JsonErzeugen=1 entsteht kein Wert.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit=1: 1 meldet nur einen äußeren CATCH-Fehler zusätzlich als konstante Severity-10-Meldung WITH NOWAIT; NULL/0 unterdrückt diese Meldung, numerisch ungleich 0 wird 1. Hilfe, direkte Eingabefehler und behandelte Quellenfehler erzeugen dadurch keine zusätzliche Meldung.
-- 
-- **@Hilfe:** @Hilfe bit=0: 1 druckt Hilfe vor Temp-DDL/Katalogzugriff, auch in einer Caller-Transaktion; NULL/0 normaler Pfad.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT: optional; AVAILABLE nur Hilfe, AVAILABLE_LIMITED sichtbare Aufnahme, SKIPPED keine sichtbare Auswahl, INVALID_PARAMETER Eingabe, SOURCE_UNAVAILABLE fehlende Dateisicht/Quellenfehler, DENIED_PERMISSION nativer Rechtefehler, TIMEOUT SQL 1222, ERROR_HANDLED äußerer Fehler.
-- 
-- **@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT: optional; normaler Pfad 1 wegen Caller-Sicht, Hilfe 0.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT: optional; nativer Fehler oder 51011 bei direktem Eingabefehler; sonst NULL.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT: optional; Fehlertext höchstens 2048 Zeichen, bei Erfolg NULL.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
-- | snapshots | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceDatabaseId] int NOT NULL, [SourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CatalogCreateDate] datetime NOT NULL, [SnapshotStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsReadOnly] bit NULL, [VisibleSparseFileCount] bigint NULL, [FileMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
-- | snapshotFiles | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [FileId] int NOT NULL, [LogicalFileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsSparse] bit NOT NULL, [FileStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MaximumSnapshotSizePages] int NOT NULL, [MaximumSnapshotSizeBytes] bigint NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
-- | sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
-- | warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_DatabaseSnapshotInventory] @SnapshotNames=N'[ExampleSnapshot]',@ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Keine physische Belegung, Gesundheit, Restore-Eignung oder globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot- Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_DatabaseSnapshotInventory
-- Version      : 1.0.0
-- Stand        : 2026-11-15
-- Zweck        : Inventarisiert caller-sichtbare Datenbank-Snapshots und
--                ihre caller-sichtbaren Dateikatalogzeilen.
-- Quellen      : master.sys.databases, master.sys.master_files.
-- Grenzen      : Keine physische Belegung, Gesundheit, Restore-Eignung oder
--                globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot-
--                Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_DatabaseSnapshotInventory: caller-sichtbare Snapshot- und Dateikatalogmetadaten ohne persistente Datenbank- oder Snapshot-Aenderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.
-- Es werden weder physische Sparse-Dateibelegung noch Snapshot-Gesundheit oder Restore-Eignung gemessen. create_date ist ein nativer lokaler Katalogwert und kann sich bei Umbenennung ändern; size ist nur maximale Snapshot-Dateikapazität in 8-KiB-Seiten. Die zwei Kataloglesungen sind nicht atomar.
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_DatabaseSnapshotInventory
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseSnapshotInventory]
      @SnapshotNames nvarchar(max) = NULL
    , @NurOnline bit = 1
    , @SystemdatenbankenEinbeziehen bit = 0
    , @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe=1
    BEGIN
        SET @Json=NULL;
        SET @StatusCodeOut=NULL;
        SET @IsPartialOut=NULL;
        SET @ErrorNumberOut=NULL;
        SET @ErrorMessageOut=NULL;
        PRINT N'monitor.USP_DatabaseSnapshotInventory: caller-sichtbare Snapshot- und Dateikatalogmetadaten ohne persistente Datenbank- oder Snapshot-Aenderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.';
        PRINT N'@SnapshotNames nvarchar(max)=NULL: NULL, leer oder nur äußere U+0020-Leerzeichen wählen alle sichtbaren Snapshots. Sonst bracket-aware Pipe-Liste einteiliger exakter Snapshotnamen; | in [...] ist Namensinhalt, ]] maskiert ]. Rohsegment höchstens 4000 UTF-16-Einheiten, Name höchstens 128 Zeichen; ungültige, leere oder case-sensitive doppelte Elemente sind INVALID_PARAMETER. Kein Patternparameter.';
        PRINT N'@NurOnline bit=1: 1 wählt nur ONLINE-Snapshots, 0 alle caller-sichtbaren Katalogzustände; NULL ist INVALID_PARAMETER. Numerisch ungleich 0 wird als bit 1 konvertiert.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0: 0 schließt Snapshots mit SourceDatabaseId bis 4 aus, 1 lässt zulässige Systemquellen zu. NULL ist INVALID_PARAMETER; numerisch ungleich 0 wird als bit 1 konvertiert.';
        PRINT N'@MaxZeilen int=1000: positiv begrenzt Snapshot-Zeilen nach SnapshotDatabaseId; alle sichtbaren Dateizeilen jedes ausgegebenen Snapshots bleiben erhalten. NULL/0 unbegrenzt, negativ INVALID_PARAMETER. Die vorgelagerte Katalogarbeit wird nicht begrenzt.';
        PRINT N'@LockTimeoutMs int=0: 0 bis 60000 Millisekunden je Katalogbatch, 0 bedeutet NOWAIT; NULL, negativ oder größer 60000 INVALID_PARAMETER. Kein Gesamtlaufzeitbudget; der vorherige Sessionwert wird wiederhergestellt.';
        PRINT N'@ResultSetArt varchar(16)=CONSOLE: SQL Server bindet einen längeren Eingabewert vor Validierung auf höchstens 16 Zeichen. Nach Trim/Großschreibung nur CONSOLE, RAW, TABLE, NONE; NULL/leer INVALID_PARAMETER. RAW liefert moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings; TABLE schreibt benannte Ziele; CONSOLE eine formatierte Menge; NONE keine Resultsets.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL: nur TABLE nimmt ein JSON-Objekt mit mindestens einer Zuordnung an. Exakte Schlüssel: moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings. Werte: unterschiedliche rohe lokale #Temp-Namen, höchstens 116 Zeichen, weder ## noch reserviertes #Monitor-Praefix. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft. Ungültige, doppelte oder unbekannte Zuordnungen werden vor der Quellenlesung abgewiesen; ein späterer Writerfehler kann schon geschriebene Ziele hinterlassen. Außerhalb TABLE nur NULL/leer/U+0020-Leerzeichen.';
        PRINT N'@JsonErzeugen bit=0: 1 erzeugt unabhängig vom Ausgabemodus JSON mit meta und fünf Arrays; NULL/0 kein JSON. Numerisch ungleich 0 wird 1.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT: optional mit OUTPUT binden; Eingang wird auf NULL gesetzt, ohne @JsonErzeugen=1 entsteht kein Wert.';
        PRINT N'@PrintMeldungen bit=1: 1 meldet nur einen äußeren CATCH-Fehler zusätzlich als konstante Severity-10-Meldung WITH NOWAIT; NULL/0 unterdrückt diese Meldung, numerisch ungleich 0 wird 1. Hilfe, direkte Eingabefehler und behandelte Quellenfehler erzeugen dadurch keine zusätzliche Meldung.';
        PRINT N'@Hilfe bit=0: 1 druckt Hilfe vor Temp-DDL/Katalogzugriff, auch in einer Caller-Transaktion; NULL/0 normaler Pfad.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT: optional; AVAILABLE nur Hilfe, AVAILABLE_LIMITED sichtbare Aufnahme, SKIPPED keine sichtbare Auswahl, INVALID_PARAMETER Eingabe, SOURCE_UNAVAILABLE fehlende Dateisicht/Quellenfehler, DENIED_PERMISSION nativer Rechtefehler, TIMEOUT SQL 1222, ERROR_HANDLED äußerer Fehler.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT: optional; normaler Pfad 1 wegen Caller-Sicht, Hilfe 0.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT: optional; nativer Fehler oder 51011 bei direktem Eingabefehler; sonst NULL.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT: optional; Fehlertext höchstens 2048 Zeichen, bei Erfolg NULL.';
        PRINT N'Es werden weder physische Sparse-Dateibelegung noch Snapshot-Gesundheit oder Restore-Eignung gemessen. create_date ist ein nativer lokaler Katalogwert und kann sich bei Umbenennung ändern; size ist nur maximale Snapshot-Dateikapazität in 8-KiB-Seiten. Die zwei Kataloglesungen sind nicht atomar.';
        PRINT N'EXEC [monitor].[USP_DatabaseSnapshotInventory] @SnapshotNames=N''[ExampleSnapshot]'',@ResultSetArt=''RAW'';';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_DatabaseSnapshotInventory
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_DatabaseSnapshotInventory') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_DatabaseSnapshotInventory"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_DatabaseSnapshotInventory"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/340_USP_DatabaseSnapshotInventory.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_DatabaseSnapshotInventory'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Inventarisiert caller-sichtbare Datenbank-Snapshots und ihre caller-sichtbaren Dateikatalogzeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseSnapshotInventory]. Die Quelle nennt insbesondere `master.sys.databases`, `master.sys.master_files`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @SnapshotNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @NurOnline | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @SystemdatenbankenEinbeziehen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 1000 |'
            + NCHAR(10)
            + N'| @LockTimeoutMs | int | nein | 0 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SnapshotNames:** @SnapshotNames nvarchar(max)=NULL: NULL, leer oder nur äußere U+0020-Leerzeichen wählen alle sichtbaren Snapshots. Sonst bracket-aware Pipe-Liste einteiliger exakter Snapshotnamen; | in [...] ist Namensinhalt, ]] maskiert ]. Rohsegment höchstens 4000 UTF-16-Einheiten, Name höchstens 128 Zeichen; ungültige, leere oder case-sensitive doppelte Elemente sind INVALID_PARAMETER. Kein Patternparameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@NurOnline:** @NurOnline bit=1: 1 wählt nur ONLINE-Snapshots, 0 alle caller-sichtbaren Katalogzustände; NULL ist INVALID_PARAMETER. Numerisch ungleich 0 wird als bit 1 konvertiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0: 0 schließt Snapshots mit SourceDatabaseId bis 4 aus, 1 lässt zulässige Systemquellen zu. NULL ist INVALID_PARAMETER; numerisch ungleich 0 wird als bit 1 konvertiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int=1000: positiv begrenzt Snapshot-Zeilen nach SnapshotDatabaseId; alle sichtbaren Dateizeilen jedes ausgegebenen Snapshots bleiben erhalten. NULL/0 unbegrenzt, negativ INVALID_PARAMETER. Die vorgelagerte Katalogarbeit wird nicht begrenzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LockTimeoutMs:** @LockTimeoutMs int=0: 0 bis 60000 Millisekunden je Katalogbatch, 0 bedeutet NOWAIT; NULL, negativ oder größer 60000 INVALID_PARAMETER. Kein Gesamtlaufzeitbudget; der vorherige Sessionwert wird wiederhergestellt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16)=CONSOLE: SQL Server bindet einen längeren Eingabewert vor Validierung auf höchstens 16 Zeichen. Nach Trim/Großschreibung nur CONSOLE, RAW, TABLE, NONE; NULL/leer INVALID_PARAMETER. RAW liefert moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings; TABLE schreibt benannte Ziele; CONSOLE eine formatierte Menge; NONE keine Resultsets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL: nur TABLE nimmt ein JSON-Objekt mit mindestens einer Zuordnung an. Exakte Schlüssel: moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings. Werte: unterschiedliche rohe lokale #Temp-Namen, höchstens 116 Zeichen, weder ## noch reserviertes #Monitor-Praefix. Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Ziele case-insensitiv geprüft. Ungültige, doppelte oder unbekannte Zuordnungen werden vor der Quellenlesung abgewiesen; ein späterer Writerfehler kann schon geschriebene Ziele hinterlassen. Außerhalb TABLE nur NULL/leer/U+0020-Leerzeichen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit=0: 1 erzeugt unabhängig vom Ausgabemodus JSON mit meta und fünf Arrays; NULL/0 kein JSON. Numerisch ungleich 0 wird 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max)=NULL OUTPUT: optional mit OUTPUT binden; Eingang wird auf NULL gesetzt, ohne @JsonErzeugen=1 entsteht kein Wert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit=1: 1 meldet nur einen äußeren CATCH-Fehler zusätzlich als konstante Severity-10-Meldung WITH NOWAIT; NULL/0 unterdrückt diese Meldung, numerisch ungleich 0 wird 1. Hilfe, direkte Eingabefehler und behandelte Quellenfehler erzeugen dadurch keine zusätzliche Meldung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit=0: 1 druckt Hilfe vor Temp-DDL/Katalogzugriff, auch in einer Caller-Transaktion; NULL/0 normaler Pfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT: optional; AVAILABLE nur Hilfe, AVAILABLE_LIMITED sichtbare Aufnahme, SKIPPED keine sichtbare Auswahl, INVALID_PARAMETER Eingabe, SOURCE_UNAVAILABLE fehlende Dateisicht/Quellenfehler, DENIED_PERMISSION nativer Rechtefehler, TIMEOUT SQL 1222, ERROR_HANDLED äußerer Fehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT: optional; normaler Pfad 1 wegen Caller-Sicht, Hilfe 0.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT: optional; nativer Fehler oder 51011 bei direktem Eingabefehler; sonst NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT: optional; Fehlertext höchstens 2048 Zeichen, bei Erfolg NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |'
            + NCHAR(10)
            + N'| snapshots | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceDatabaseId] int NOT NULL, [SourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CatalogCreateDate] datetime NOT NULL, [SnapshotStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsReadOnly] bit NULL, [VisibleSparseFileCount] bigint NULL, [FileMetadataStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |'
            + NCHAR(10)
            + N'| snapshotFiles | 1 | 1 | [SnapshotDatabaseId] int NOT NULL, [SnapshotName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [FileId] int NOT NULL, [LogicalFileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsSparse] bit NOT NULL, [FileStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MaximumSnapshotSizePages] int NOT NULL, [MaximumSnapshotSizeBytes] bigint NOT NULL, [MetadataVisibility] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |'
            + NCHAR(10)
            + N'| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |'
            + NCHAR(10)
            + N'| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_DatabaseSnapshotInventory] @SnapshotNames=N''[ExampleSnapshot]'',@ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine physische Belegung, Gesundheit, Restore-Eignung oder globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot- Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.'
            + NCHAR(10)
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
            + N'Objekt       : monitor.USP_DatabaseSnapshotInventory'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-11-15'
            + NCHAR(10)
            + N'Zweck        : Inventarisiert caller-sichtbare Datenbank-Snapshots und'
            + NCHAR(10)
            + N'               ihre caller-sichtbaren Dateikatalogzeilen.'
            + NCHAR(10)
            + N'Quellen      : master.sys.databases, master.sys.master_files.'
            + NCHAR(10)
            + N'Grenzen      : Keine physische Belegung, Gesundheit, Restore-Eignung oder'
            + NCHAR(10)
            + N'               globale Vollständigkeit. Keine persistente Datenbank- oder Snapshot-'
            + NCHAR(10)
            + N'               Änderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_DatabaseSnapshotInventory: caller-sichtbare Snapshot- und Dateikatalogmetadaten ohne persistente Datenbank- oder Snapshot-Aenderung; lokale Temp-DDL dient Aufbereitung und TABLE-Ausgabe.'
            + NCHAR(10)
            + N'Es werden weder physische Sparse-Dateibelegung noch Snapshot-Gesundheit oder Restore-Eignung gemessen. create_date ist ein nativer lokaler Katalogwert und kann sich bei Umbenennung ändern; size ist nur maximale Snapshot-Dateikapazität in 8-KiB-Seiten. Die zwei Kataloglesungen sind nicht atomar.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_DatabaseSnapshotInventory
        RETURN;
    END

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,
            @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
            @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
            @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
            @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen) END,
            @Status varchar(40)='SKIPPED',@Error int=NULL,@Message nvarchar(2048)=NULL,
            @TableStatus varchar(40),@TableMessage nvarchar(2048),@TableError int,
            @TableFailureError int=NULL,@TableFailureMessage nvarchar(2048)=NULL,
            @Sql nvarchar(max),@Started datetime2(3),@Observed bigint,
            @ResultName sysname,@TargetTable sysname,@SourceTable sysname,
            @LockTimeoutSql nvarchar(80),
            @ConsoleResultRequested bit=CASE WHEN UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))))='CONSOLE' THEN 1 ELSE 0 END,
            @NamesActive bit=CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(@SnapshotNames,N''))),N'') IS NULL THEN 0 ELSE 1 END;
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    ;

    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Normale Ausführung verlangt keine aktive Caller-Transaktion und IMPLICIT_TRANSACTIONS OFF.';
        RETURN 51011;
    END;
    IF @Mode NOT IN ('RAW','TABLE','CONSOLE','NONE')
       OR @NurOnline IS NULL OR @SystemdatenbankenEinbeziehen IS NULL
       OR @MaxZeilen<0 OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Snapshotfilter, Ausgabemodus, Limit, Lock-Timeout oder TABLE-Parameter.';
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        CREATE TABLE #DatabaseSnapshotInventory_Requested (NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY);
        CREATE TABLE #DatabaseSnapshotInventory_Candidates
        (
            SnapshotDatabaseId int NOT NULL PRIMARY KEY,
            SnapshotName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            SourceDatabaseId int NOT NULL,
            SourceDatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            CatalogCreateDate datetime NOT NULL,
            SnapshotStateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            IsReadOnly bit NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_moduleStatus
        (
            ModuleName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            CapturedAtUtc datetime2(3) NOT NULL,
            StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            IsPartial bit NOT NULL, [RowCount] bigint NOT NULL,
            Detail nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_snapshots
        (
            SnapshotDatabaseId int NOT NULL, SnapshotName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            SourceDatabaseId int NOT NULL, SourceDatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            CatalogCreateDate datetime NOT NULL, SnapshotStateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            IsReadOnly bit NULL, VisibleSparseFileCount bigint NULL,
            FileMetadataStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            MetadataVisibility varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_snapshotFiles
        (
            SnapshotDatabaseId int NOT NULL, SnapshotName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            FileId int NOT NULL, LogicalFileName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            PhysicalName nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            IsSparse bit NOT NULL, FileStateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            MaximumSnapshotSizePages int NOT NULL, MaximumSnapshotSizeBytes bigint NOT NULL,
            MetadataVisibility varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_sourceStatus
        (
            DatabaseId int NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            SourceKey varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            SourceKind varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            StartedAtUtc datetime2(3) NOT NULL, CompletedAtUtc datetime2(3) NOT NULL,
            StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            VisibilityScope varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            ObservedRows bigint NULL, ReturnedRows bigint NULL, IsLimited bit NOT NULL,
            ErrorNumber int NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_warnings
        (
            DatabaseId int NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            WarningCode varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            SourceKey varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            Detail nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE #DatabaseSnapshotInventory_Map
        (ResultName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         TargetTable sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE #DatabaseSnapshotInventory_Console
        (Bereich nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         Objekt nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
         Detail nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);

        IF @NamesActive=1
        BEGIN
            IF EXISTS
            (
                SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@SnapshotNames)
                WHERE IsValid<>1 OR NameValue IS NULL
            )
               OR EXISTS
            (
                SELECT NameValue COLLATE SQL_Latin1_General_CP1_CS_AS
                FROM [monitor].[TVF_ParseSqlNameList](@SnapshotNames)
                WHERE IsValid=1
                GROUP BY NameValue COLLATE SQL_Latin1_General_CP1_CS_AS HAVING COUNT_BIG(*)>1
            )
            BEGIN
                SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
                       @ErrorMessageOut=N'@SnapshotNames enthaelt ungueltige oder doppelte Namen.';
                EXEC [sys].[sp_executesql] @LockTimeoutSql;
                IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
                RETURN 51011;
            END;
            INSERT #DatabaseSnapshotInventory_Requested(NameValue)
            SELECT NameValue FROM [monitor].[TVF_ParseSqlNameList](@SnapshotNames) WHERE IsValid=1;
        END;
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables]
                @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|snapshots|snapshotFiles|sourceStatus|warnings',
                @MappingTable=N'#DatabaseSnapshotInventory_Map',
                @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
                       @ErrorNumberOut=51011,
                       @ErrorMessageOut=COALESCE(@TableMessage,N'Ungueltige TABLE-Zuordnung oder Zieltabelle.');
                EXEC [sys].[sp_executesql] @LockTimeoutSql;
                IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
                RETURN 51011;
            END;
        END;

        SET @Started=SYSUTCDATETIME();
        SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';
            INSERT #DatabaseSnapshotInventory_Candidates
            SELECT d.database_id,d.name,d.source_database_id,src.name,d.create_date,d.state_desc,d.is_read_only
            FROM master.sys.databases AS d WITH (NOLOCK)
            LEFT JOIN master.sys.databases AS src WITH (NOLOCK) ON src.database_id=d.source_database_id
            WHERE d.source_database_id IS NOT NULL
              AND (@Online=0 OR d.state=0)
              AND (@System=1 OR d.source_database_id>4)
              AND (@Filter=0 OR EXISTS
                  (SELECT 1 FROM #DatabaseSnapshotInventory_Requested AS r WHERE r.NameValue=d.name COLLATE SQL_Latin1_General_CP1_CS_AS));';
        BEGIN TRY
            EXEC [sys].[sp_executesql] @Sql,N'@Online bit,@System bit,@Filter bit',
                 @Online=@NurOnline,@System=@SystemdatenbankenEinbeziehen,@Filter=@NamesActive;
        END TRY
        BEGIN CATCH
            SELECT @Error=ERROR_NUMBER(),@Message=LEFT(ERROR_MESSAGE(),2048),
                   @Status=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION'
                                ELSE 'SOURCE_UNAVAILABLE' END;
            INSERT #DatabaseSnapshotInventory_sourceStatus
            VALUES(NULL,NULL,'SNAPSHOT_CATALOG','CATALOG',@Started,SYSUTCDATETIME(),
                   @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
        END CATCH;
        IF @Error IS NULL
        BEGIN
        SET @Observed=(SELECT COUNT_BIG(*) FROM #DatabaseSnapshotInventory_Candidates);
        INSERT #DatabaseSnapshotInventory_sourceStatus
        VALUES(NULL,NULL,'SNAPSHOT_CATALOG','CATALOG',@Started,SYSUTCDATETIME(),
               CASE WHEN @Observed=0 THEN 'SKIPPED' ELSE 'AVAILABLE_LIMITED' END,
               'CALLER_VISIBLE',@Observed,@Observed,0,NULL,NULL);
        INSERT #DatabaseSnapshotInventory_snapshots
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,CatalogCreateDate,
               SnapshotStateDesc,IsReadOnly,NULL,'SOURCE_UNAVAILABLE','VISIBLE_ONLY'
        FROM #DatabaseSnapshotInventory_Candidates;

        SET @Started=SYSUTCDATETIME();
        SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';
            INSERT #DatabaseSnapshotInventory_snapshotFiles
            SELECT c.SnapshotDatabaseId,c.SnapshotName,f.file_id,f.name,f.physical_name,
                   f.is_sparse,f.state_desc,f.size,CONVERT(bigint,f.size)*CONVERT(bigint,8192),
                   ''VISIBLE_ONLY''
            FROM #DatabaseSnapshotInventory_Candidates AS c
            INNER JOIN master.sys.master_files AS f WITH (NOLOCK)
              ON f.database_id=c.SnapshotDatabaseId
            WHERE f.is_sparse=1;';
        BEGIN TRY
            EXEC [sys].[sp_executesql] @Sql;
        END TRY
        BEGIN CATCH
            SELECT @Error=ERROR_NUMBER(),@Message=LEFT(ERROR_MESSAGE(),2048),
                   @Status=CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION'
                                ELSE 'SOURCE_UNAVAILABLE' END;
            DELETE FROM #DatabaseSnapshotInventory_snapshotFiles;
        END CATCH;
        UPDATE s SET VisibleSparseFileCount=f.FileCount,
                     FileMetadataStatus=CASE WHEN f.FileCount>0 THEN 'AVAILABLE_LIMITED' ELSE 'SOURCE_UNAVAILABLE' END
        FROM #DatabaseSnapshotInventory_snapshots AS s
        CROSS APPLY
        (SELECT COUNT_BIG(*) AS FileCount FROM #DatabaseSnapshotInventory_snapshotFiles AS f
         WHERE f.SnapshotDatabaseId=s.SnapshotDatabaseId) AS f;
        UPDATE #DatabaseSnapshotInventory_snapshots SET VisibleSparseFileCount=NULL
        WHERE FileMetadataStatus='SOURCE_UNAVAILABLE';
        INSERT #DatabaseSnapshotInventory_sourceStatus
        SELECT s.SnapshotDatabaseId,s.SnapshotName,'SNAPSHOT_FILES','CATALOG',@Started,SYSUTCDATETIME(),
               CASE WHEN @Error IS NOT NULL THEN @Status ELSE s.FileMetadataStatus END,
               CASE WHEN @Error IS NOT NULL THEN 'UNPROVEN' ELSE 'VISIBLE_ONLY' END,
               s.VisibleSparseFileCount,s.VisibleSparseFileCount,0,
               @Error,
               CASE WHEN @Error IS NOT NULL THEN @Message
                    WHEN s.FileMetadataStatus='SOURCE_UNAVAILABLE'
                    THEN N'Keine sichtbare Sparse-Dateizeile; fehlende Berechtigung, Katalogwechsel oder leere Quelle nicht unterscheidbar.'
                    ELSE NULL END
        FROM #DatabaseSnapshotInventory_snapshots AS s;
        INSERT #DatabaseSnapshotInventory_warnings
        SELECT SnapshotDatabaseId,SnapshotName,'FILE_METADATA_UNPROVEN','SNAPSHOT_FILES',
               N'Keine sichtbare Sparse-Dateizeile; die Dateimenge ist unbekannt und kein Nullbestand.'
        FROM #DatabaseSnapshotInventory_snapshots WHERE FileMetadataStatus='SOURCE_UNAVAILABLE';

        IF @NamesActive=1
            INSERT #DatabaseSnapshotInventory_warnings
            SELECT NULL,r.NameValue,'SNAPSHOT_UNAVAILABLE','SNAPSHOT_CATALOG',
                   N'Der angeforderte Snapshot ist im ausgewählten Caller-Scope nicht sichtbar.'
            FROM #DatabaseSnapshotInventory_Requested AS r
            WHERE NOT EXISTS
            (SELECT 1 FROM #DatabaseSnapshotInventory_Candidates AS c WHERE c.SnapshotName=r.NameValue);
        ;WITH Bounded AS
        (SELECT SnapshotDatabaseId,ROW_NUMBER() OVER(ORDER BY SnapshotDatabaseId) AS rn
         FROM #DatabaseSnapshotInventory_snapshots)
        DELETE s FROM #DatabaseSnapshotInventory_snapshots AS s
        INNER JOIN Bounded AS b ON b.SnapshotDatabaseId=s.SnapshotDatabaseId
        WHERE b.rn>@Limit;
        DELETE f FROM #DatabaseSnapshotInventory_snapshotFiles AS f
        WHERE NOT EXISTS
        (SELECT 1 FROM #DatabaseSnapshotInventory_snapshots AS s
         WHERE s.SnapshotDatabaseId=f.SnapshotDatabaseId);
        UPDATE st SET ReturnedRows=CASE WHEN st.SourceKey='SNAPSHOT_CATALOG'
             THEN (SELECT COUNT_BIG(*) FROM #DatabaseSnapshotInventory_snapshots)
             ELSE CASE WHEN st.ObservedRows IS NULL THEN NULL
                       WHEN s.SnapshotDatabaseId IS NULL THEN 0
                       ELSE (SELECT COUNT_BIG(*) FROM #DatabaseSnapshotInventory_snapshotFiles AS f
                             WHERE f.SnapshotDatabaseId=st.DatabaseId) END END,
               IsLimited=CASE WHEN st.SourceKey='SNAPSHOT_CATALOG'
                    AND @Observed>(SELECT COUNT_BIG(*) FROM #DatabaseSnapshotInventory_snapshots)
                    THEN 1 WHEN st.SourceKey='SNAPSHOT_FILES' AND s.SnapshotDatabaseId IS NULL THEN 1 ELSE 0 END
        FROM #DatabaseSnapshotInventory_sourceStatus AS st
        LEFT JOIN #DatabaseSnapshotInventory_snapshots AS s ON s.SnapshotDatabaseId=st.DatabaseId;
        IF EXISTS(SELECT 1 FROM #DatabaseSnapshotInventory_sourceStatus WHERE IsLimited=1)
            INSERT #DatabaseSnapshotInventory_warnings
            VALUES(NULL,NULL,'OUTPUT_LIMIT','SNAPSHOT_CATALOG',
                   N'@MaxZeilen begrenzt nur ausgegebene Snapshots; die Katalogarbeit lief zuvor vollständig.');
        INSERT #DatabaseSnapshotInventory_warnings
        VALUES(NULL,NULL,'CATALOG_CAPTURE_NOT_ATOMIC','SNAPSHOT_CATALOG',
               N'Snapshot- und Dateikatalog wurden nacheinander gelesen; Metadaten koennen sich dazwischen aendern.');
        INSERT #DatabaseSnapshotInventory_warnings
        VALUES(NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN','SNAPSHOT_CATALOG',
               N'Nur caller-sichtbare Katalogzeilen; Dateisicht, Quellname und globale Vollstaendigkeit sind nicht zugesichert.');
        IF @Error IS NULL
            SET @Status=CASE WHEN @Observed=0 THEN 'SKIPPED' ELSE 'AVAILABLE_LIMITED' END;
        IF @Error IS NULL AND EXISTS
           (SELECT 1 FROM #DatabaseSnapshotInventory_snapshots WHERE FileMetadataStatus='SOURCE_UNAVAILABLE')
            SET @Status='SOURCE_UNAVAILABLE';
        END;
        INSERT #DatabaseSnapshotInventory_moduleStatus
        VALUES(N'USP_DatabaseSnapshotInventory',@CapturedAtUtc,@Status,1,
               (SELECT COUNT_BIG(*) FROM #DatabaseSnapshotInventory_snapshots),
               N'Caller-sichtbare Snapshot- und Sparse-Dateikatalogmetadaten; keine physische Belegung oder globale Vollstaendigkeit.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'DatabaseSnapshotInventory' AS resultName,1 AS schemaVersion,
                @CapturedAtUtc AS generatedAtUtc,@Status AS statusCode,CONVERT(bit,1) AS isPartial,
                @Error AS errorNumber,@Message AS errorMessage
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @J1 nvarchar(max)=(SELECT * FROM #DatabaseSnapshotInventory_moduleStatus FOR JSON PATH,INCLUDE_NULL_VALUES),
                    @J2 nvarchar(max)=(SELECT * FROM #DatabaseSnapshotInventory_snapshots ORDER BY SnapshotDatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES),
                    @J3 nvarchar(max)=(SELECT * FROM #DatabaseSnapshotInventory_snapshotFiles ORDER BY SnapshotDatabaseId,FileId FOR JSON PATH,INCLUDE_NULL_VALUES),
                    @J4 nvarchar(max)=(SELECT * FROM #DatabaseSnapshotInventory_sourceStatus ORDER BY SourceKey,DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES),
                    @J5 nvarchar(max)=(SELECT * FROM #DatabaseSnapshotInventory_warnings ORDER BY WarningCode,DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@J1,N'[]'),
                N',"snapshots":',COALESCE(@J2,N'[]'),N',"snapshotFiles":',COALESCE(@J3,N'[]'),
                N',"sourceStatus":',COALESCE(@J4,N'[]'),N',"warnings":',COALESCE(@J5,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM #DatabaseSnapshotInventory_moduleStatus;
            SELECT * FROM #DatabaseSnapshotInventory_snapshots ORDER BY SnapshotDatabaseId;
            SELECT * FROM #DatabaseSnapshotInventory_snapshotFiles ORDER BY SnapshotDatabaseId,FileId;
            SELECT * FROM #DatabaseSnapshotInventory_sourceStatus ORDER BY SourceKey,DatabaseId;
            SELECT * FROM #DatabaseSnapshotInventory_warnings ORDER BY WarningCode,DatabaseId;
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE ResultTargets CURSOR LOCAL FAST_FORWARD FOR
                SELECT ResultName,TargetTable FROM #DatabaseSnapshotInventory_Map ORDER BY ResultName;
            OPEN ResultTargets;
            FETCH NEXT FROM ResultTargets INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DatabaseSnapshotInventory_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable]
                    @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SELECT @TableFailureError=COALESCE(@TableError,51010),
                           @TableFailureMessage=COALESCE(@TableMessage,N'TABLE result writing failed.');
                    RAISERROR(N'%s',16,1,@TableFailureMessage);
                END;
                FETCH NEXT FROM ResultTargets INTO @ResultName,@TargetTable;
            END;
            CLOSE ResultTargets; DEALLOCATE ResultTargets;
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT #DatabaseSnapshotInventory_Console
            SELECT N'Snapshot',SnapshotName,
                   CONCAT(N'SourceId=',SourceDatabaseId,N'; SourceName=',COALESCE(SourceDatabaseName,N'NULL'),
                          N'; Zustand=',SnapshotStateDesc,N'; Sparse-Dateien=',
                          COALESCE(CONVERT(nvarchar(30),VisibleSparseFileCount),N'NULL'))
            FROM #DatabaseSnapshotInventory_snapshots;
            INSERT #DatabaseSnapshotInventory_Console
            SELECT N'Datei',PhysicalName,
                   CONCAT(N'SnapshotId=',SnapshotDatabaseId,N'; FileId=',FileId,
                          N'; max. Seiten=',MaximumSnapshotSizePages)
            FROM #DatabaseSnapshotInventory_snapshotFiles;
            INSERT #DatabaseSnapshotInventory_Console
            SELECT N'Quelle',SourceKey,
                   CONCAT(StatusCode,N'; beobachtet=',COALESCE(CONVERT(nvarchar(30),ObservedRows),N'NULL'))
            FROM #DatabaseSnapshotInventory_sourceStatus;
            INSERT #DatabaseSnapshotInventory_Console
            SELECT N'Aussagegrenze',WarningCode,Detail FROM #DatabaseSnapshotInventory_warnings;
            EXEC [monitor].[InternalEmitConsoleResult]
                @SourceTable=N'#DatabaseSnapshotInventory_Console',
                @ResultLabel=N'Sichtbare Datenbank-Snapshots',
                @EmptyMessage=N'Keine sichtbaren Snapshot-Zeilen; Quellenstatus und Auswahl pruefen.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),
               @Message=COALESCE(@TableFailureMessage,LEFT(ERROR_MESSAGE(),2048)),@Json=NULL,
               @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1;
        SELECT @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'USP_DatabaseSnapshotInventory: Fehler; siehe OUTPUT-Status.',10,1) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
