---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabaseMirroringInventory"
schema_name: "monitor"
object_name: "USP_DatabaseMirroringInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure gibt caller-sichtbare lokale Database-Mirroring-Katalogwerte je ausgewählter Online-Datenbank aus."
source_path: "Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql"
---

# monitor.USP_DatabaseMirroringInventory

## Zweck und Einsatz

Die Procedure gibt caller-sichtbare lokale Database-Mirroring-Katalogwerte je ausgewählter Online-Datenbank aus.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseMirroringInventory]. Die Quelle nennt insbesondere `master.sys.databases`, `master.sys.database_mirroring`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[master].[sys].[databases]`, `[master].[sys].[database_mirroring]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. Die Liste schränkt die Auswahl auf angeforderte, gültige einteilige Datenbanknamen ein; NULL, eine exakt leere Eingabe oder ausschließlich äußere U+0020-Leerzeichen werden vom Auswahlhelfer zu keiner Einschränkung normalisiert. Eine aktive Liste muss bracket-aware mit | getrennt sein: | innerhalb [..] gehört zum Namen, ]] maskiert dort eine schließende Klammer. Segmente werden außen getrimmt; doppelte Namen und ungültige Elemente machen die Auswahl ungültig. Die Prüfung nutzt TVF_ParseSqlNameList/PARSENAME: Teil 1 muss vorhanden, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Der Parser prüft weder die vollständige SQL-Namensgrammatik noch Existenz oder Berechtigungen. Aktive Liste und nicht-NULL @DatabaseNamePattern sind unzulässig zusammen. Auswahl umfasst nur sichtbare, ONLINE befindliche, zugreifbare, nicht als Snapshot markierte Datenbanken. Jedes rohe Listensegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; längere Segmente sind INVALID_PARAMETER. Diese Grenze gilt je Segment, nicht für die Gesamtlänge der nvarchar(max)-Liste. Doppelte Namen werden case-sensitiv geprüft. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. Steuert den Datenbank-ID-Filter: 0 schließt Systemdatenbanken mit IDs bis 4 aus, 1 nimmt sie in die Kandidatenmenge auf; andere numerische Bit-Eingaben werden durch den Bit-Parametertyp als 0 oder 1 abgebildet. NULL ist ausdrücklich ungültig und liefert INVALID_PARAMETER vor Quellenlesung. Der Schalter garantiert weder Sichtbarkeit noch Online-Status oder HAS_DBACCESS. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Optionaler zusätzlicher Namensfilter; nicht-NULL ist mit einer aktiven exakten @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst äußere Leerzeichen, entfernt danach ohne Beachtung der Groß-/Kleinschreibung höchstens das Präfix regexi:, regex: oder like:; der Rest wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE verwendet SQL-LIKE-Syntax und wird case-sensitive ausgewertet. regex: führt case-sensitives Regex mit Flag c, regexi: case-insensitives Regex mit Flag i aus; Regex-Syntax wird vom Parser nicht validiert. Ein leerer Eingang oder leeres Präfix-Ergebnis ist ungültig. Regex setzt SQL Server 2025 (Major Version mindestens 17) und Compatibility Level 170 der Installationsdatenbank voraus; bei Nichterfüllung löscht der Helper Kandidaten und gibt UNAVAILABLE_FEATURE zurück. Der gemeinsame Kandidatenhelfer führt den Regexabgleich dynamisch aus; Fehler dabei werden vom Auswahl-CATCH als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED eingeordnet. SQL-LIKE unterstützt Prozentzeichen für beliebig viele Zeichen, Unterstrich für ein Zeichen und Zeichenklassen in [...]; der Aufruf definiert keine eigene ESCAPE-Klausel. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Globales Ausgabelimit für databaseMirroring nach der vollständigen Kandidaten- und Katalogermittlung, sortiert nach DatabaseId; es begrenzt weder Kandidatenermittlung noch vorgelagerte Kataloglesearbeit. NULL oder 0 setzt das Limit auf bigint-Maximum und wirkt damit unbegrenzt; negative Werte sind INVALID_PARAMETER. sourceStatus unterscheidet beobachtete Auswahl-/Quellzeilen und tatsächlich ausgegebene Mirroringzeilen; OUTPUT_LIMIT wird nur bei tatsächlich abgeschnittenen Fachzeilen angelegt. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Wählt die Resultset-Ausgabe. Nach LTRIM/RTRIM und UPPER sind genau CONSOLE, RAW, TABLE und NONE zulässig; NULL oder Leertext wird zu leer und ist INVALID_PARAMETER. CONSOLE erzeugt eine formatierte Einzelansicht über InternalEmitConsoleResult. RAW liefert die vier Resultsets moduleStatus, databaseMirroring, sourceStatus und warnings in dieser Reihenfolge. TABLE schreibt die angeforderten benannten Resultsets in Caller-Temp-Tabellen; die Zuordnung ist Pflicht. NONE unterdrückt Resultsets. Json-Erzeugen ist unabhängig von dieser Auswahl. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Wird nur mit ResultSetArt TABLE verarbeitet; außerhalb TABLE ist ein nicht-NULL, nach Trim nicht-leerer Wert INVALID_PARAMETER. In TABLE ist ein gültiges JSON-Objekt mit mindestens einem Schlüssel und Textwerten erforderlich. Erlaubte, exakt groß-/kleinschreibungssensitive Schlüssel sind moduleStatus, databaseMirroring, sourceStatus und warnings; jeder benennt eine jeweils unterschiedliche lokale #Temp-Zieltabelle. Doppelte Resultset-Schlüssel werden binär verglichen, Zielnamen dagegen case-insensitive; unbekannte Schlüssel, doppelte Ziele, Nicht-Textwerte und ungültige Ziele werden vor fachlichem Quellenzugriff abgelehnt. Zielname maximal 116 Zeichen, lokal mit #, nicht ## und nicht mit reserviertem #Monitor-Präfix. Jedes Ziel muss vorher vorhanden, leer und mit genau einer Seed-Spalte versehen sein. Die Vorprüfung validiert die Zuordnung und Seed-Ziele; der Writer passt die einzelne Dummy-Spalte an das Quellschema an; öffentlich sind gefüllte Ziele wegen der Vorprüfung unzulässig. Ein späterer Writer-Fehler kann nach früheren erfolgreichen Zielen auftreten; der Aufruf kann daher teilweise geschriebene Ziele hinterlassen. Die vier Schlüssel bedeuten einzeln: moduleStatus liefert Modulstatus, Partialität und Zeilenzahl; databaseMirroring caller-sichtbare Mirroring-Katalogwerte je ausgewählter Online-Datenbank; sourceStatus Auswahl- und Katalogquellenstatus mit beobachteten und ausgegebenen Zeilen sowie Fehlern; warnings Warnungen und Aussagegrenzen. NULL und leere Werte sind im TABLE-Modus ungültig; außerhalb TABLE sind NULL, Leerstring und reine U+0020-Leerzeichen erlaubt. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Schaltet die JSON-Ausgabe unabhängig von ResultSetArt ein: Wert 1 erzeugt die schemaVersion-1-Metahülle mit moduleStatus, databaseMirroring, sourceStatus und warnings; NULL oder 0 erzeugt kein JSON und @Json bleibt NULL. Numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Der Schalter ist nicht als ungültig validiert. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT nvarchar(max); der Aufrufer bindet eine nvarchar(max)-Variable mit OUTPUT. Die Variable wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 wird JSON auch dann erzeugt, wenn Auswahlstatus, Quellfehler oder Auswahlwarnungen als innerer Fehlerstatus erfasst wurden; diese Fälle laufen bis zur JSON-Erzeugung weiter und erscheinen in meta sowie den Arrays. Bei Hilfe, ohne JSON-Anforderung und bei jedem äußeren CATCH bleibt @Json NULL; ein äußerer Fehler nach der JSON-Erzeugung, etwa ein TABLE-Schreibfehler, setzt es erneut auf NULL. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Steuert zusätzliche Meldungen mit niedriger Severity: 1 gibt sie an den Client aus, 0 unterdrückt sie; NULL verhält sich wegen der IF-Prüfungen wie unterdrückt. Numerische Bit-Eingaben werden als 0/1 übernommen. Die Auswahl-/Katalogstatus und OUTPUT-Fehlerdaten werden unabhängig davon gesetzt; dieser Schalter ändert keine Resultsets. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Bei 1 gibt die Procedure die eingebaute Hilfe per PRINT aus, setzt StatusCodeOut auf AVAILABLE und IsPartialOut auf 0 und kehrt vor Auswahl, Temp-Tabellen und Katalogzugriff mit RETURN zurück. NULL oder 0 führen den normalen Ablauf aus. Die Hilfe-Ausgabe ist keine Quellen- oder Plattformqualifikation; numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Sämtliche Statuswerte und Bedeutungen: AVAILABLE kennzeichnet die Hilfe ohne Quellenanalyse; AVAILABLE_LIMITED eine erfolgreiche, stets partielle normale Katalogsicht, auch ohne Fachzeilen; INVALID_PARAMETER ungültige direkte Eingaben oder einen ungültigen Auswahlvertrag; INTERNAL_ERROR einen internen Vorbereitungsfehler des Auswahlhelfers; UNAVAILABLE_FEATURE einen hier nicht verfügbaren Regexfilter; SELECTION_UNAVAILABLE den Fallback bei NULL als Auswahlstatus; DENIED_PERMISSION einen abgefangenen Berechtigungsfehler 229, 297, 300 oder 371; TIMEOUT einen Sperrtimeout 1222; ERROR_HANDLED einen sonstigen abgefangenen Auswahl-/Katalogfehler oder jeden äußeren Fehler; DATABASE_UNAVAILABLE einen explizit angeforderten fehlenden, nicht online befindlichen oder nicht zugreifbaren Namen; SYSTEM_DATABASE_EXCLUDED eine explizit angeforderte Systemdatenbank ohne Opt-in. Die normale Auswahl übernimmt einen nicht-AVAILABLE-Helferstatus oder den NULL-Fallback; Auswahl- und Katalog-CATCH setzen ihren Fehler sofort. Nur solange kein Fehler gesetzt ist, übernimmt die spätere Fehlerauswahl die erste sourceStatus-Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName: DATABASE_MIRRORING_CATALOG vor DATABASE_SELECTION. Auswahlwarnungen tragen 51011 und können so den globalen Status setzen, obwohl der Katalog gelesen wurde. Ein äußerer CATCH, auch nach TABLE-Vorprüfung oder -Schreiben, überschreibt den Status mit ERROR_HANDLED. Hilfe und normale innere Fehlerpfade liefern RETURN 0; direkte Validierung RETURN 51011. Der äußere CATCH liefert den gespeicherten TABLE-Fehlercode (Vorprüfung 51011, Writercode oder 51010), sonst die native Fehlernummer. Ein Status beweist weder Gesundheit noch vollständige Sicht. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bit; wird beim Eintritt auf NULL zurückgesetzt. Hilfe setzt 0. Jeder normale Lauf sowie INVALID_PARAMETER und der äußere Fehler-CATCH setzen 1, auch wenn die Fachmenge leer ist. Numerische Bit-Ausgabe; kennzeichnet keine bestimmte Fehlerursache. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. Optionales OUTPUT int; wird am Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern 51011. Ein nicht-AVAILABLE-Auswahlstatus liefert 51011 aus den Auswahlwarnungen oder als Fallback; Auswahl-/Katalog-CATCH liefert die SQL-Fehlernummer. Fehlende, ausgeschlossene oder nicht zugreifbare explizite Datenbanknamen werden als sourceStatus-Warnungen mit 51011 eingetragen und können bei der globalen Fehlerauswahl übernommen werden. Ohne vorher gesetzten Fehler werden Nummer und Meldung aus der ersten Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName übernommen. Der äußere CATCH priorisiert TableFailureError: 51011 bei TABLE-Preflight, sonst Writer-Fehlernummer oder 51010; andernfalls native SQL-Fehlernummer. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Optionales OUTPUT nvarchar(2048); wird beim Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern den Validierungstext. Bei Auswahlstatusfehlern kommt der Auswahlhelper-Text oder der Fallbacktext; Auswahl-/Katalog-CATCH liefert den abgefangenen SQL-Text, auf 2048 Zeichen begrenzt. Auswahlwarnungen für nicht verfügbare, ausgeschlossene oder nicht zugreifbare explizite Namen werden mit ihrer Warnmeldung in sourceStatus aufgenommen und können über die sortierte Fehlerauswahl ausgegeben werden. Bei mehreren Fehlern gehört die Meldung zur ersten sourceStatus-Zeile nach SourceKey, DatabaseId und DatabaseName. Im äußeren CATCH ist @ErrorMessageOut der abgefangene SQL-Fehlertext, links auf 2048 Zeichen begrenzt; bei TABLE-Fehlern stammt er aus dem ausgelösten Fehlertext, die TableFailureError-Priorität beeinflusst nur @ErrorNumberOut und den RETURN-Wert. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| databaseMirroring | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [MirroringState] tinyint NULL, [MirroringStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MirroringRole] tinyint NULL, [MirroringRoleDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MirroringSafetyLevel] tinyint NULL, [MirroringSafetyLevelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MirroringWitnessState] tinyint NULL, [MirroringWitnessStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ConfiguredRedoQueueLimitMb] int NULL, [RedoQueueLimitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabaseMirroringInventory] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Auswahl umfasst sichtbare Online-Datenbanken. Werte belegen weder eine vollständige Metadatensicht noch Mirroring-Gesundheit.

Read-only; keine Konfigurations-, Netzwerk- oder Probeoperation.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DatabaseMirroringInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Die Procedure gibt caller-sichtbare lokale Database-Mirroring-Katalogwerte je
               ausgewählter Online-Datenbank aus.
Quellen      : master.sys.databases, master.sys.database_mirroring.
Grenzen      : Die Auswahl umfasst sichtbare Online-Datenbanken. Werte belegen
               weder eine vollständige Metadatensicht noch Mirroring-Gesundheit.
Datenschutz  : Partner-, Witness-, GUID- und LSN-Werte werden nicht ausgegeben.
Nebenwirkung : Read-only; keine Konfigurations-, Netzwerk- oder Probeoperation.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabaseMirroringInventory
Die Procedure liest lokale, caller-sichtbare Mirroring-Katalogwerte zu ausgewählten ONLINE-Datenbanken, ohne Konfigurations-, Netzwerk- oder Probeoperationen auszuführen. Die Ausgabe belegt keine Mirroring-Gesundheit.
Die Auswahl umfasst sichtbare ONLINE-Datenbanken; Systemdatenbanken werden nur opt-in aufgenommen. Nicht ONLINE befindliche Datenbanken einschließlich RESTORING-Mirror-Datenbanken sind ausgeschlossen.
Bei @Hilfe=1 gibt die Procedure die Hinweise aus und kehrt vor Datenbankauswahl und Quellenlesung zurück. Ein AVAILABLE-Hilfestatus ist keine Laufzeitqualifikation.
DECLARE @DiagnosticJson nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@DiagnosticJson OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @DiagnosticJson AS [DiagnosticJson];
CREATE TABLE [#DatabaseMirroringInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databaseMirroring":"#DatabaseMirroringInventory_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#DatabaseMirroringInventory_HelpExample]; DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; THROW; END CATCH;
Für nicht-NULL-Werte einer Mirror-Datenbank ist sysadmin erforderlich; SQL Server 2022+ fordert VIEW SERVER PERFORMANCE STATE; die Quelle spezifiziert keine weitere Serverberechtigung für SQL Server 2019.
TABLE-Zuordnung: {"moduleStatus":"#DbmiModule","databaseMirroring":"#DbmiRows","sourceStatus":"#DbmiSources","warnings":"#DbmiWarnings"}.
Beispiel Pattern: EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNamePattern=N'like:Prod%', @ResultSetArt='CONSOLE';
Beispiel JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNames=N'[ExampleDatabase]', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
JSON: schemaVersion=1; meta sowie moduleStatus, databaseMirroring, sourceStatus und warnings.
```

