---
skill_format_version: "1.0.0"
name: "monitor.USP_LoadedModuleInventory"
schema_name: "monitor"
object_name: "USP_LoadedModuleInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert native Metadaten der in den SQL-Server-Prozess geladenen Module zum Aufnahmezeitpunkt."
source_path: "Code/08_ServerHealth/330_USP_LoadedModuleInventory.sql"
---

# monitor.USP_LoadedModuleInventory

## Zweck und Einsatz

Inventarisiert native Metadaten der in den SQL-Server-Prozess geladenen Module zum Aufnahmezeitpunkt.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_LoadedModuleInventory]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[sys].[dm_os_loaded_modules]`, `[monitor].[InternalWriteResultTable]`, `sys.dm_os_loaded_modules`, `[monitor].[InternalEmitConsoleResult]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @NurBuildFlags | bit | nein | 0 |
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

**@NurBuildFlags:** @NurBuildFlags bit; Default: 0. 0 gibt alle projizierbaren DMV-Zeilen aus, 1 nur Zeilen mit mindestens einem nativen Flag debug, patched, prerelease, private_build oder special_build = 1. NULL ist im normalen Pfad INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Die Flag-Auswahl folgt erst auf den vollständigen DMV-Read und bezeichnet kein Risiko.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL oder 0 bedeuten unbegrenzte Ausgabe; negative Werte sind INVALID_PARAMETER. Positive Werte 1 bis 2147483647 begrenzen nur die nach allen öffentlich ausgegebenen Fachfeldern sortierte loadedModules-Ausgabe nach vollständigem Quellenread und Flag-Auswahl. Leertext ist keine eigene int-Eingabeform; SQL Server konvertiert ihn vor dem Aufruf.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. SQL Server bindet oder kuerzt auf varchar(16) vor der Validierung. Nach aeusserem U+0020-Trimmen und UPPER sind CONSOLE, RAW, TABLE und NONE zulaessig; NULL und leer sind INVALID_PARAMETER. RAW gibt moduleStatus, loadedModules, sourceStatus und warnings in dieser Reihenfolge aus; TABLE schreibt benannte Gruppen in Caller-Temp-Tabellen; CONSOLE liefert eine formatierte Fachmenge; NONE liefert keine Fachresultsets. Optionales JSON ist unabhaengig davon.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE: nichtleeres JSON-Objekt mit mindestens einem exakt geschriebenen Schluessel moduleStatus, loadedModules, sourceStatus oder warnings. Werte sind unqualifizierte lokale #Temp-Namen, weder ## noch #Monitor; Konvertierung zu sysname erfolgt vor der Pruefung, Laenge danach hoechstens 116 Zeichen. Gruppen sind binaer verschieden, Ziele case-insensitiv verschieden. Jedes Ziel existiert leer mit genau einer beliebigen Seed-Spalte. Teilmapping ist erlaubt. NULL, leer oder nur U+0020 sind ausserhalb TABLE ohne Wirkung; andere Werte INVALID_PARAMETER. Preflightfehler vor DMV-Read sind INVALID_PARAMETER; spaetere Writerfehler sind technisch und koennen fruehere Zielschreibungen belassen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit meta und vier benannten Arrays, 0 keines; NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden; der Eingangswert wird auf NULL zurückgesetzt. Normale Läufe mit JsonErzeugen=1 liefern JSON; Hilfe, direkte Parameterfehler und technische Ausgabefehler liefern NULL. Eine behandelte DMV-Störung kann ein JSON mit Quellenstatus und leeren Fachzeilen liefern.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt zusaetzliche Severity-10-Meldungen mit dem nativen beziehungsweise Framework-Fehlertext aus, 0 keine; NULL ist im normalen Pfad INVALID_PARAMETER. Numerische 0 wird 0, andere bitkonvertierbare Nichtnullwerte werden 1. Hilfe-PRINT bleibt unabhaengig.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt Hilfe vor Parametervalidierung, TABLE-Preflight und DMV-Read aus und kehrt mit 0, Status AVAILABLE und IsPartial 0 zurueck; auch in einer Callertransaktion. 0 fuehrt die Analyse aus, NULL ist INVALID_PARAMETER. Normale Aufnahme verlangt @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; bei Verletzung INVALID_PARAMETER 51011 ohne Quellenread. Andere bitkonvertierbare Nichtnullwerte werden 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional an varchar(40) mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE nur Hilfe; AVAILABLE_LIMITED erfolgreiche nichtleere Momentaufnahme; EMPTY_UNPROVEN erfolgreicher leerer DMV-Read; DENIED_PERMISSION tatsächlicher Rechtefehler; UNAVAILABLE_OBJECT fehlende DMV; ERROR_HANDLED sonstiger Quellen-/Technikfehler; INVALID_PARAMETER ungültige Eingabe.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optional an bit mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe 0; jeder normale Lauf und Fehlerpfad 1. Partialität bezeichnet die Momentaufnahme und die Aussagegrenze zum Host.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optional an int mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe und erfolgreicher Read NULL; ungültige Eingabe 51011; behandelte Quellenfehler ihre native SQL-Fehlernummer; technische Fehler deren tatsächliche oder Writer-Fehlernummer.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional an nvarchar(2048) mit OUTPUT binden; Eingang wird zurueckgesetzt. Erfolg NULL; native Quellen- und Technikfehler liefern den auf 2048 Zeichen begrenzten ERROR_MESSAGE-Text, TABLE-Helfer ihren begrenzten Fehlertext. Laufzeittexte koennen Pfade enthalten und gehoeren nicht ungeprueft in Repository-Artefakte.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| loadedModules | 1 | 1 | [ModuleName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ModuleBasename] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Debug] bit NULL, [Patched] bit NULL, [Prerelease] bit NULL, [PrivateBuild] bit NULL, [SpecialBuild] bit NULL, [Language] int NULL |
| sourceStatus | 1 | 1 | [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [NativeReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [MatchedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_LoadedModuleInventory] @NurBuildFlags=0,@MaxZeilen=100,@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Nur lesender DMV-Zugriff im Caller-Kontext; keine Modulaktion.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_LoadedModuleInventory
Version      : 1.0.0
Stand        : 2026-11-14
Zweck        : Inventarisiert native Metadaten der in den SQL-Server-Prozess
               geladenen Module zum Aufnahmezeitpunkt.
Quelle       : sys.dm_os_loaded_modules.
Datenschutz  : ModuleName enthaelt den unveraenderten nativen DMV-Namen
               einschliesslich moeglichem Pfad; Laufzeitwerte werden nicht als
               Repository-Artefakte gespeichert. BaseAddress, Company und
               Description werden fachlich nicht gelesen.
Grenze       : Kein Host-, Filtertreiber-, Signatur-, Malware- oder Gesundheitsurteil.
Nebenwirkung : Nur lesender DMV-Zugriff im Caller-Kontext; keine Modulaktion.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_LoadedModuleInventory
Ein SQL-Prozess-Snapshot aus sys.dm_os_loaded_modules. ModuleName ist der unveraenderte native DMV-Name einschliesslich moeglichem Pfad; ModuleBasename ist eine zusaetzliche Komfortprojektion. Keine Host- oder Filtertreiberinventur und keine Signatur-, Vertrauens-, Malware- oder Gesundheitsbewertung.
SQL Server 2019 benötigt für die DMV VIEW SERVER STATE; SQL Server 2022 und neuer VIEW SERVER PERFORMANCE STATE. Die Procedure erteilt keine Rechte und führt als Caller aus.
DECLARE @j nvarchar(max); EXEC [monitor].[USP_LoadedModuleInventory] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@j OUTPUT; SELECT @j AS [Json];
CREATE TABLE #LoadedModuleExample([Seed] int NULL); EXEC [monitor].[USP_LoadedModuleInventory] @ResultSetArt='TABLE',@ResultTablesJson=N'{"loadedModules":"#LoadedModuleExample"}'; SELECT * FROM #LoadedModuleExample;
```

