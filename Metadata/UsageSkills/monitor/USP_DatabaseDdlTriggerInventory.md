---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabaseDdlTriggerInventory"
schema_name: "monitor"
object_name: "USP_DatabaseDdlTriggerInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert caller-sichtbare datenbankweite DDL-Trigger in ausgewählten ONLINE-Datenbanken."
source_path: "Code/03_ObjectIndex/100_USP_DatabaseDdlTriggerInventory.sql"
---

# monitor.USP_DatabaseDdlTriggerInventory

## Zweck und Einsatz

Inventarisiert caller-sichtbare datenbankweite DDL-Trigger in ausgewählten ONLINE-Datenbanken.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseDdlTriggerInventory]. Die Quelle nennt insbesondere `sys.triggers`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[master].[sys].[databases]`, `[sys].[triggers]`, `[sys].[sp_executesql]`, `[monitor].[InternalWriteResultTable]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Eine aktive bracket-aware Pipe-Liste enthält einteilige Datenbanknamen; | innerhalb [...] ist Namensinhalt und ]] maskiert ]. Äußere Leerzeichen werden getrimmt; leere oder doppelte Segmente und Namen über 128 Zeichen sind ungültig. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten enthalten, die Gesamtliste ist offen. Eine aktive Liste und ein nicht-NULL-Pattern sind unzulässig. Standard sind caller-sichtbare zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbank-IDs bis 4 aus; 1 lässt sie als Kandidaten zu. NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere numerische Werte werden 1; Sichtbarkeit und Zugriff bleiben erforderlich.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern; nicht-NULL-Leertext ist ungültig. like:, regex: und regexi: sind zulässige Präfixe, ohne Präfix gilt LIKE. LIKE und regex sind case-sensitiv, regexi ist case-insensitiv. LIKE verwendet SQL-LIKE-Syntax mit %, _, Zeichenklassen und ohne eigene ESCAPE-Klausel. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Eine aktive exakte Liste und Pattern sind unzulässig.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL oder 0 bedeuten unbegrenzt; negative Werte sind INVALID_PARAMETER. Positive Werte 1 bis 2147483647 begrenzen ausschließlich ausgegebene ddlTriggers-Zeilen in der Reihenfolge DatabaseId, TriggerObjectId. Auswahl und Kataloglesearbeit bleiben unbegrenzt; echte Kürzung erhält OUTPUT_LIMIT.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Nur 0 bis 60000 Millisekunden sind zulässig; NULL ist INVALID_PARAMETER. 0 ist NOWAIT. Der Wert gilt je dynamischem Datenbank-Katalogbatch und ist keine Gesamtdauergrenze. Der vorherige Sessionwert wird wiederhergestellt.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach äußerem U+0020-Trimmen und Großschreibung sind CONSOLE, RAW, TABLE und NONE zulässig. NULL oder leer ist INVALID_PARAMETER. CONSOLE liefert eine formatierte Fachmenge, RAW moduleStatus, ddlTriggers, sourceStatus und warnings in dieser Reihenfolge, TABLE schreibt benannte Mengen, NONE liefert keine Fachresultsets. JSON ist unabhängig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE akzeptiert ein JSON-Objekt mit wenigstens einer Zuordnung der exakt case-sensitiven Schlüssel moduleStatus, ddlTriggers, sourceStatus, warnings zu verschiedenen lokalen #Temp-Zielen. Ziele müssen existieren, leer sein und genau eine Seed-Spalte haben; Namen höchstens 116 Zeichen, nicht ## oder #Monitor. Doppelte und unbekannte Schlüssel, doppelte oder ungültige Ziele werden vor Quellenzugriff abgewiesen. Ein späterer Writer-Fehler kann frühere Zielschreibungen belassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit schemaVersion 1, meta und allen vier Arrays; NULL und 0 erzeugen keines. Numerische 0 wird 0, andere numerische Werte werden 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden; Eingang wird auf NULL gesetzt. Bei JsonErzeugen=1 entsteht JSON im normalen Pfad. Hilfe, direkte Parameterfehler und äußerer CATCH lassen NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt zusätzliche niedrige Severity-Meldungen zu Fehlern aus; 0 und NULL unterdrücken sie. Andere Ergebnisse bleiben gleich. Numerische 0 wird 0, andere numerische Werte werden 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt diese Hilfe vor Auswahl und Katalogzugriff aus, setzt StatusCodeOut=AVAILABLE und IsPartialOut=0 und kehrt mit 0 zurück. NULL und 0 führen den normalen Pfad aus.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional an varchar(40) mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE bedeutet nur Hilfe; AVAILABLE_LIMITED erfolgreiche sichtbare Quelle, auch leer; SKIPPED keine Kandidatendatenbank; INVALID_PARAMETER ungültige Eingabe oder Auswahl; INTERNAL_ERROR Auswahlhelferfehler; SELECTION_UNAVAILABLE fehlender Auswahlstatus; UNAVAILABLE_FEATURE fehlende Regexvoraussetzung; DATABASE_UNAVAILABLE fehlende, nicht online befindliche oder nicht zugreifbare Datenbank; SYSTEM_DATABASE_EXCLUDED explizit ausgeschlossene Systemdatenbank; DENIED_PERMISSION native Berechtigungsfehler; SOURCE_UNAVAILABLE unbekanntes Prüfergebnis oder Quellenfehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Der erste relevante Quellenfehler bestimmt den globalen Status.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optional an bit mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe liefert 0; jeder normale Lauf und Fehlerpfad 1. Numerische 0/1-Ausgabe kennzeichnet begrenzte Metadatensicht, nicht eine Fehlerursache.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optional an int mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolg und Hilfe lassen NULL; direkte Parameterfehler liefern 51011; gefangene SQL-Fehler ihre native oder Writer-Fehlernummer.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional an nvarchar(2048) mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolg und Hilfe lassen NULL; gefangene SQL-Fehler liefern die links auf 2048 Zeichen gekürzte Meldung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| ddlTriggers | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [TriggerObjectId] int NOT NULL, [TriggerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ParentClass] tinyint NOT NULL, [ParentClassDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [TriggerType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [TriggerTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsDisabled] bit NOT NULL, [CreateDate] datetime NOT NULL, [ModifyDate] datetime NOT NULL, [MetadataVisibility] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabaseDdlTriggerInventory] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Kein Nachweis für Ausführung, Wirkung, Ownership oder Vollständigkeit.

Read-only im Caller-Kontext; keine Trigger- oder DDL-Aktion.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DatabaseDdlTriggerInventory
Version      : 1.0.0
Stand        : 2026-11-14
Zweck        : Inventarisiert caller-sichtbare datenbankweite DDL-Trigger
               in ausgewählten ONLINE-Datenbanken.
Quellen      : sys.triggers mit parent_class=0.
Grenzen      : Kein Nachweis für Ausführung, Wirkung, Ownership oder Vollständigkeit.
Datenschutz  : Keine Triggerdefinitionen, Ereignisinhalte oder Nutzdaten.
Nebenwirkung : Read-only im Caller-Kontext; keine Trigger- oder DDL-Aktion.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabaseDdlTriggerInventory
Die Procedure liest pro ausgewählter ONLINE-Datenbank caller-sichtbare sys.triggers-Zeilen mit parent_class=0: datenbankweite DDL-Trigger. ParentClassDesc stammt aus dem nativen Katalog; TriggerType TR bezeichnet SQL-, TA CLR-Trigger, weitere native Werte bleiben erhalten. IsDisabled ist ein Konfigurationswert, kein Beleg für Ausführung oder Wirkung. MetadataVisibility ist stets VISIBLE_ONLY. Es werden weder Definitionen oder Ereignisinhalte gelesen noch Trigger ausgeführt. Leere Fachzeilen belegen nur eine leere sichtbare Menge.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabaseDdlTriggerInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE #DatabaseDdlTriggerInventoryExample ([Seed] int NULL); EXEC [monitor].[USP_DatabaseDdlTriggerInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"ddlTriggers":"#DatabaseDdlTriggerInventoryExample"}'; SELECT * FROM #DatabaseDdlTriggerInventoryExample; DROP TABLE #DatabaseDdlTriggerInventoryExample;
```

