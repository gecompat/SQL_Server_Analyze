---
skill_format_version: "1.0.0"
name: "monitor.USP_SensitivityClassificationSummary"
schema_name: "monitor"
object_name: "USP_SensitivityClassificationSummary"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zählt Klassifikationsmetadaten je caller-sichtbarer Datenbank."
source_path: "Code/08_ServerHealth/320_USP_SensitivityClassificationSummary.sql"
---

# monitor.USP_SensitivityClassificationSummary

## Zweck und Einsatz

Die Procedure zählt Klassifikationsmetadaten je caller-sichtbarer Datenbank.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SensitivityClassificationSummary]. Die Quelle nennt insbesondere `sys.tables`, `sys.columns`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[master].[sys].[databases]`, `[sys].[sp_executesql]`, `[sys].[tables]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Eine aktive bracket-aware Pipe-Liste enthält einteilige Datenbanknamen; | innerhalb [...] ist Namensinhalt und ]] maskiert ]. Äußere Leerzeichen werden getrimmt; leere oder doppelte Segmente und Namen über 128 Zeichen sind ungültig. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; diese Grenze gilt nicht für die Gesamtliste. Eine aktive Liste und ein nicht-NULL-Pattern sind unzulässig. Standardauswahl: caller-sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbank-IDs bis 4 aus, 1 lässt sie als Kandidaten zu. NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere numerische Werte werden 1. Sichtbarkeit und Zugriff bleiben erforderlich.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern; nicht-NULL-Leertext ist ungültig. Optionales like:, regex: oder regexi: vor einem nichtleeren Pattern; ohne Präfix gilt LIKE. LIKE und regex sind case-sensitiv, regexi ist case-insensitiv. LIKE verwendet SQL-LIKE-Syntax mit %, _, Zeichenklassen und ohne eigene ESCAPE-Klausel. Regex-Syntax wird vom Parser nicht vorvalidiert. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Eine aktive exakte Liste und Pattern sind unzulässig.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL und 0 bedeuten unbegrenzt, negative Werte INVALID_PARAMETER, positive Werte 1 bis 2147483647 begrenzen ausschließlich ausgegebene classificationSummary-Datenbankzeilen nach DatabaseId. Die Kandidatenermittlung und Kataloglesearbeit werden nicht begrenzt. Ein abgeschnittenes Ergebnis erhält OUTPUT_LIMIT.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Nur 0 bis 60000 Millisekunden sind zulässig; NULL ist INVALID_PARAMETER. 0 ist NOWAIT. Der Wert gilt je dynamischem Datenbank-Katalogbatch und ist keine Gesamtdauergrenze. Der vorherige Sessionwert wird wiederhergestellt.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach äußerem U+0020-Trimmen und Großschreibung sind ausschließlich CONSOLE, RAW, TABLE und NONE zulässig; NULL/leer ist ungültig. CONSOLE zeigt genau eine formatierte Fachmenge. RAW liefert moduleStatus, classificationSummary, sourceStatus, warnings. TABLE schreibt gemappte Mengen; NONE liefert keine Resultsets. JSON bleibt unabhängig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE nimmt ein JSON-Objekt mit wenigstens einer Zuordnung an. Schlüssel sind exakt moduleStatus, classificationSummary, sourceStatus, warnings; Werte sind unterschiedliche lokale #Temp-Namen. Zielnamen sind maximal 116 Zeichen lang, beginnen mit #, nicht mit ## oder dem reservierten #Monitor-Präfix. Die Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Zielnamen case-insensitiv geprüft; ungültige, doppelte oder unbekannte Schlüssel/Ziele werden vor der fachlichen Quellenlesung abgewiesen. Ein späterer Writer-Fehler kann bereits geschriebene Ziele hinterlassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit schemaVersion 1, meta und allen vier Arrays; NULL und 0 erzeugen kein JSON. Numerische 0 wird 0, andere numerische Werte werden 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden. Eingang wird auf NULL gesetzt; JSON entsteht nur bei JsonErzeugen=1 im normalen Pfad. Hilfe, frühe Parameterfehler und äußerer CATCH lassen NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt zusätzliche niedrige Severity-Meldungen zu Fehlern aus; 0 und NULL unterdrücken sie. Status, Resultsets und OUTPUT-Werte bleiben davon unabhängig. Numerische 0 wird 0, andere numerische Werte werden 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt diese Hilfe vor Auswahl und Katalogzugriff aus, setzt StatusCodeOut=AVAILABLE und IsPartialOut=0 und kehrt mit 0 zurück. NULL und 0 führen den normalen Pfad aus.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE bedeutet nur Hilfe; AVAILABLE_LIMITED erfolgreiche sichtbare Quelle; SKIPPED keine Kandidatendatenbank und keine Katalogaufnahme; INVALID_PARAMETER direkte Eingabe oder Auswahlvertrag; INTERNAL_ERROR interner Kandidaten-Vorbereitungsfehler; SELECTION_UNAVAILABLE fehlender Helferstatus als Fallback; UNAVAILABLE_FEATURE fehlende Regexvoraussetzung; DATABASE_UNAVAILABLE nicht erreichbare Datenbank; SYSTEM_DATABASE_EXCLUDED ausgeschlossene explizite Systemdatenbank; DENIED_PERMISSION negative effektive Rechteprüfung oder native Berechtigungsfehler; SOURCE_UNAVAILABLE unbekanntes Prüfergebnis oder Quellenfehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Der erste relevante Quellenfehler bestimmt den globalen Status.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe liefert 0, jeder normale Lauf und Fehlerpfad 1, weil Metadatensicht begrenzt sein kann.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolgreicher Lauf/Hilfe lassen NULL. Direkte Eingabefehler liefern 51011; Preflight-Rechteprüfung ohne nativen Fehler lässt NULL. Gefangene SQL-Fehler liefern die echte Fehlernummer.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Bei negativer/unklarer Rechteprüfung gibt es einen festen Text; gefangene SQL-Fehler bewahren ERROR_MESSAGE links auf 2048 Zeichen. Hilfe/erfolgreicher Lauf lassen NULL.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| classificationSummary | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibleTableCount] bigint NULL, [VisibleTableColumnCount] bigint NULL, [ClassifiedVisibleTableColumnCount] bigint NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SensitivityClassificationSummary] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Nur sichtbare Tabellen und Spalten; kein Vollständigkeits-, Schutzwirkungs- oder Datenqualitätsurteil.

Produktpfad read-only im Caller-Kontext.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SensitivityClassificationSummary
Version      : 1.0.0
Stand        : 2026-11-13
Zweck        : Die Procedure zählt Klassifikationsmetadaten je caller-sichtbarer Datenbank.
Quellen      : sys.tables, sys.columns, sys.sensitivity_classifications.
Grenzen      : Nur sichtbare Tabellen und Spalten; kein Vollständigkeits-,
               Schutzwirkungs- oder Datenqualitätsurteil.
Datenschutz  : Keine Tabellenwerte, Klassifikationstexte oder Objekt-/Spaltennamen.
Nebenwirkung : Produktpfad read-only im Caller-Kontext.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SensitivityClassificationSummary
Die Procedure zählt sichtbare Tabellen, deren Spalten und klassifizierte sichtbare Tabellenspalten je ausgewählter ONLINE-Datenbank. Es werden keine Tabellenwerte oder Klassifikationstexte gelesen. Eine Nullzählung ist nur nach erfolgreicher Quelle ein sichtbares Nullergebnis und kein Abwesenheits- oder Vollständigkeitsbeweis. Die drei Zählabfragen laufen nacheinander und sind keine atomare Aufnahme.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE #SensitivityClassificationSummaryExample ([Seed] int NULL); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt='TABLE', @ResultTablesJson=N'{"classificationSummary":"#SensitivityClassificationSummaryExample"}'; SELECT * FROM #SensitivityClassificationSummaryExample; DROP TABLE #SensitivityClassificationSummaryExample;
```

