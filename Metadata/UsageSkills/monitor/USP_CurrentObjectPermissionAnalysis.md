---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentObjectPermissionAnalysis"
schema_name: "monitor"
object_name: "USP_CurrentObjectPermissionAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zeigt native OBJECT-Rechte eines ausdruecklich benannten Schema-/Objektpaars je ausgewaehlter Datenbank im aktuellen Ausfuehrungskontext."
source_path: "Code/08_ServerHealth/281_USP_CurrentObjectPermissionAnalysis.sql"
---

# monitor.USP_CurrentObjectPermissionAnalysis

## Zweck und Einsatz

Die Procedure zeigt native OBJECT-Rechte eines ausdruecklich benannten Schema-/Objektpaars je ausgewaehlter Datenbank im aktuellen Ausfuehrungskontext.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentObjectPermissionAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[databases]`, `[master].[sys].[databases]`, `[sys].[sp_executesql]`, `[sys].[fn_my_permissions]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @SchemaName | nvarchar(max) | nein | NULL |
| @ObjectName | nvarchar(max) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default NULL. NULL, leer oder nur aeussere U+0020-Leerzeichen bedeuten keinen Listenfilter. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen; exakte case-sensitive Namen, doppelte Namen ungueltig. Mit aktiver Liste muss @DatabaseNamePattern NULL sein. Nicht verfuegbare gueltige Namen erzeugen Auswahlwarnungen, keinen Abwesenheitsbeweis.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default 0. 0 schliesst Datenbank-IDs bis 4 aus, 1 erlaubt sie unter Sichtbarkeits-, ONLINE- und HAS_DBACCESS-Grenzen; NULL ist INVALID_PARAMETER. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default NULL. NULL bedeutet kein Pattern. LIKE, REGEX, REGEXI verwenden die gemeinsame Datenbankauswahl; leeres Pattern ist ungueltig, aktive nichtleere Namensliste und Pattern sind unvereinbar. REGEX und REGEXI verlangen SQL Server 2025/Compatibility Level 170 in der Installationsdatenbank. Regexsyntaxfehler werden im Auswahlpfad sichtbar.

**@SchemaName:** @SchemaName nvarchar(max); Default NULL. Im regulären Pfad ist genau ein nichtleerer, nicht nur aus U+0020 bestehender Schemaname erforderlich; keine Liste oder Wildcard. SQL bindet Text ohne numerische Sonderdeutung. Der Rohwert wird nicht still gekuerzt oder getrimmt; maximal 128 UTF-16-Codeeinheiten vor QUOTENAME.

**@ObjectName:** @ObjectName nvarchar(max); Default NULL. Im regulären Pfad ist genau ein nichtleerer, nicht nur aus U+0020 bestehender Objektname erforderlich; keine Liste oder Wildcard. Der Rohwert wird nicht still gekuerzt oder getrimmt; maximal 128 UTF-16-Codeeinheiten vor QUOTENAME. Der qualifizierte Name muss insgesamt in sysname passen, sonst INVALID_PARAMETER.

**@MaxZeilen:** @MaxZeilen int; Default 1000. NULL oder 0 ist unbegrenzt, negative Werte sind INVALID_PARAMETER. Positiv begrenzt OBJECT-Rechte global nach DatabaseId, EntityName, SubentityName und PermissionName erst nach allen Quellenlesungen. ObservedRows und ReturnedRows bleiben getrennt; Kontext, Status und Warnungen werden nicht gekappt.

**@LockTimeoutMs:** @LockTimeoutMs int; Default 0. 0 bis 60000 Millisekunden, NULL und andere Werte INVALID_PARAMETER. Dynamische Quellen verwenden diesen Wert; 0 ist NOWAIT. Vorbereitende Temp-DDL erhaelt bei eingehendem LOCK_TIMEOUT 0 bis zu 1000 ms. Der Callerwert wird auf allen Pfaden wiederhergestellt, ohne Gesamtzeitgarantie.

**@ResultSetArt:** @ResultSetArt varchar(16); Default CONSOLE. Nach aeusserem U+0020-Trim/UPPER sind nur CONSOLE, RAW, TABLE und NONE gueltig; NULL/leer sind ungueltig. CONSOLE zeigt eine beschriftete Sicht, RAW fuenf Mengen, TABLE angeforderte lokale Ziele, NONE keine fachliche Menge. JSON ist unabhaengig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default NULL. Ausserhalb TABLE sind nur NULL/leer/U+0020 erlaubt. Bei TABLE erwartet der gemeinsame Helper mindestens eine eindeutige Zuordnung aus moduleStatus, callerContexts, objectPermissions, sourceStatus und warnings zu vorhandenen leeren lokalen #Temp-Zielen mit genau einer Seed-Spalte; keine Duplikate, keine ##- oder #Monitor*-Ziele, Namen hoechstens 116 Zeichen. Ablehnung vor Quellenzugriff ergibt ERROR_HANDLED/51011 und JSON NULL.

**@JsonErzeugen:** @JsonErzeugen bit; Default 0. Nur 1 erzeugt JSON in @Json, unabhaengig vom Resultmodus; 0 oder NULL erzeugt keines. meta und fuenf Arrays behalten NULL-Felder. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default NULL. Optionaler OUTPUT-Empfaenger, mit OUTPUT binden. Beim Eintritt, bei Hilfe, Validierungsfehler und aeusserem Fehler NULL; nur bei regulärem Pfad und @JsonErzeugen=1 gesetzt.

**@PrintMeldungen:** @PrintMeldungen bit; Default 1. 1 erlaubt niedrige NOWAIT-Diagnosemeldungen, 0 unterdrueckt sie; NULL aktiviert sie nicht. Hilfe druckt unabhaengig. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.

**@Hilfe:** @Hilfe bit; Default 0. 1 druckt diese Hilfe und liefert AVAILABLE/IsPartial=0/RETURN 0 vor TABLE- oder Quellenpruefung; JSON und Fehlerausgaben bleiben NULL. 0 oder NULL setzt den Normalpfad fort.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe AVAILABLE, Parameter INVALID_PARAMETER, Auswahlfehler deren Status. Normal AVAILABLE_LIMITED bei mindestens einer nichtleeren OBJECT-Quelle, sonst EMPTY_UNPROVEN bei erfolgreicher leerer Quelle, sonst erster nativer Fehler nach DatabaseId, sonst NO_TARGETS. Quellenfehler aendern RETURN 0 nicht; pruefen Sie sourceStatus.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe 0; Validierung, regulärer Bericht und aeusserer Fehler 1. Caller-Sicht, leere Quellen, Outputlimit und getrennte Zeitpunkte begrenzen die Aussage.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe NULL, Validierung 51011, sonst erste native Fehlernummer nach DatabaseId/SourceKey oder NULL; aeusserer Fehler gibt den vorbereiteten oder abgefangenen Code.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe NULL, Validierung feste Diagnose, sonst erste native Fehlermeldung nach DatabaseId/SourceKey oder NULL; aeussere Fehler bleiben diagnostisch erhalten.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| callerContexts | 1 | 1 | [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContextDatabaseId] int NOT NULL, [ServerPrincipalId] int NULL, [DatabasePrincipalId] int NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL |
| objectPermissions | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @SchemaName=N'dbo',@ObjectName=N'Probe',@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Leere oder fehlerhafte Quellen beweisen keine Objektabwesenheit; der Bericht beweist keinen konkreten Statementzugriff.

Keine persistenten Datenbank- oder Objektänderungen; lokale Temp-DDL dient der Aufbereitung. Keine Identitaetsaenderung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentObjectPermissionAnalysis
Version      : 1.0.0
Stand        : 2026-11-16
Zweck        : Die Procedure zeigt native OBJECT-Rechte eines ausdruecklich
               benannten Schema-/Objektpaars je ausgewaehlter Datenbank im
               aktuellen Ausfuehrungskontext.
Grenzen      : Leere oder fehlerhafte Quellen beweisen keine Objektabwesenheit;
               der Bericht beweist keinen konkreten Statementzugriff.
Nebenwirkung : Keine persistenten Datenbank- oder Objektänderungen; lokale
               Temp-DDL dient der Aufbereitung. Keine Identitaetsaenderung.
Datenschutz  : Der Bericht erfragt keine SID- oder Tokenquellen. Native Namen
               und diagnostische Fehlermeldungen bleiben erhalten.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentObjectPermissionAnalysis
Die Procedure liest native OBJECT-Rechte des aktuellen Aufrufers fuer ein ausdruecklich benanntes Schema-/Objektpaar je ausgewaehlter Datenbank. Sie wechselt keine Identitaet und liest keine Datenzeilen des Zielobjekts.
Ohne Datenbankfilter gelten sichtbare, ONLINE befindliche, zugaengliche Benutzerdatenbanken ohne Snapshots. Systemdatenbanken sind nur mit Opt-in enthalten. Leere oder fehlerhafte Objektquellen beweisen weder Objektabwesenheit noch fehlende Rechte.
RAW liefert fuenf benannte Mengen; TABLE schreibt die angeforderte Teilmenge, CONSOLE eine Ansicht und NONE keine Resultsets. JSON enthaelt meta und dieselben fuenf Arrays. Quellen sind getrennt und nicht atomar.
```

