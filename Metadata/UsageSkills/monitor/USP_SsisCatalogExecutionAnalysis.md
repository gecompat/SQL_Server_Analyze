---
skill_format_version: "1.0.0"
name: "monitor.USP_SsisCatalogExecutionAnalysis"
schema_name: "monitor"
object_name: "USP_SsisCatalogExecutionAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest strukturierte Metadaten einer expliziten SSISDB-Ausführung."
source_path: "Code/10_SSIS/030_USP_SsisCatalogExecutionAnalysis.sql"
---

# monitor.USP_SsisCatalogExecutionAnalysis

## Zweck und Einsatz

Liest strukturierte Metadaten einer expliziten SSISDB-Ausführung.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SsisCatalogExecutionAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[sys].[sp_executesql]`, `[master].[sys].[databases]`, `master.sys.databases`, `[sys].[dm_os_host_info]`, `sys.dm_os_host_info` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ExecutionId | bigint | nein | NULL |
| @IncludeMessages | bit | nein | 1 |
| @IncludeParameters | bit | nein | 1 |
| @IncludePerformance | bit | nein | 1 |
| @MaxZeilen | int | nein | 1000 |
| @MaxDurationSeconds | int | nein | 30 |
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
| @ErrorMessageOut | nvarchar(4000) | nein | NULL OUTPUT |

**@ExecutionId:** @ExecutionId bigint; Default: NULL. Einzelne positive Ganzzahl 1 bis 9223372036854775807 als bigint für genau eine lokale SSISDB-Ausführung. Keine Liste oder freie Textquelle. NULL, ausgelassen oder kleiner als 1 ist im normalen Analysepfad ungültig und verhindert fachliche Quellenzugriffe. Wert 1 in Beispielen ist synthetisch und muss durch eine bekannte sichtbare ID ersetzt werden. Ausgelassen gilt der deklarierte Default NULL.

**@IncludeMessages:** @IncludeMessages bit; Default: 1. 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Ereignismetadaten aus catalog.event_messages; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Meldungstexte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@IncludeParameters:** @IncludeParameters bit; Default: 1. 1 fordert bei sichtbarer Ausführung und noch verfügbarem Zeitbudget den Read an: Definitionen und Flags aus catalog.execution_parameter_values; 0 überspringt die Quelle und markiert sie als nicht angefordert. NULL wird zu 1. Parameterwerte werden nicht gelesen. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@IncludePerformance:** @IncludePerformance bit; Default: 1. 1 liest Executable-Statistik, Executable-Namen, Phasen und Row-Flow, soweit die Ausführung sichtbar ist; 0 überspringt diese Quellen. NULL wird zu 1. Execution-, Meldungs- und Parameterquellen sind davon unabhängig. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Einzelner SQL-int-Wert 0 bis 2147483647 oder NULL als Obergrenze je Detailquelle. Positives N liest höchstens N+1 geordnete Zeilen einschließlich Sentinel und gibt bei Überschreitung höchstens N zurück. NULL/0 bedeutet unbegrenzt; negativ ist ungültig. N+1 wird nach bigint-Konvertierung berechnet, daher kein int-Maximum-Überlauf. Betroffen sind nur Executable-Statistik, Executable-Namen, Meldungen, Parameter, Phasen und Row-Flow (Ordinale 2–7); nicht die einzelne Execution-Kopfzeile, Plattformprobe, Findings, warnings, sourceStatus oder moduleStatus. Ausgelassen gilt der deklarierte Default 1000.

**@MaxDurationSeconds:** @MaxDurationSeconds int; Default: 30. Einzelner SQL-int-Wert in Sekunden. Kooperatives Gesamtzeitbudget zwischen den sieben SSISDB-Quellen, Bereich 1–60 Sekunden. NULL oder außerhalb ist ungültig. Die Deadline wird zwischen Quellen geprüft; eine laufende SQL-Abfrage wird nicht hart abgebrochen. Erschöpfung kann spätere Quellen auslassen und Partialität verursachen. Ausgelassen gilt der deklarierte Default 30.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Einzelner SQL-int-Wert. Katalog-Sperrwartezeit in Millisekunden, Bereich 0–60000. NULL oder außerhalb ist ungültig. 0 bedeutet NOWAIT; positive Werte begrenzen die Wartezeit. Der eingehende LOCK_TIMEOUT wird nach dem Erfassungspfad wiederhergestellt. TABLE-Vorprüfung folgt zusätzlich dem Vertrag der internen Helfer. Ausgelassen gilt der deklarierte Default 0.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Textwert wird an varchar(16) gebunden und kann dabei auf diese Typbreite gekürzt werden; dann werden mit LTRIM/RTRIM U+0020-Randzeichen entfernt, UPPER angewandt und mit SQL_Latin1_General_CP1_CS_AS verglichen. Vollständige Wertemenge: CONSOLE = eine Übersicht; RAW = zehn geordnete Resultsets; TABLE = benannte lokale Temp-Tabellen; NONE = keine fachlichen Grids. Erst der nach Typzuweisung normalisierte Wert wird geprüft. NULL, leer oder nur U+0020 sind ungültig; weitere Whitespacezeichen werden nicht allgemein entfernt. Ausgelassen gilt der deklarierte Default 'CONSOLE'.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. JSON-Objekt mit Resultsetnamen als Schlüssel und lokalen #Temp-Tabellennamen als Stringwert. Alle erlaubten Schlüssel: moduleStatus (Modulstatus), execution (Ausführung), executables (Executable-Statistik), messages (Ereignismetadaten), parameters (Parameterdefinitionen), phases (Phasen), rowFlow (Datenflussstatistik), findings (Befunde), sourceStatus (Quellenstatus), warnings (Warnungen). Mindestens ein Schlüssel ist erforderlich; eine beliebige nichtleere Teilmenge dieser zehn Schlüssel genügt. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Ziele müssen auch bei case-insensitivem Vergleich eindeutig sein, lokal und mit LEN höchstens 116, nicht ##Temp und nicht Präfix #Monitor. Jedes Ziel existiert bereits, ist leer und hat genau eine beliebige Seed-Spalte. TABLE verlangt gültige nichtleere Zuordnung; außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen erlaubt, nichtleerer Wert ungültig. Vorprüfung läuft nach Hilfe-Return, vor Hauptvalidierung, mit @ThrowOnError=1; Fehler können THROW entweichen und werden nicht als OUTPUT-Fehler garantiert. Ausgelassen gilt der deklarierte Default NULL.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt JSON mit denselben zehn Mengen einschließlich NULL-Feldern und leeren Arrays; 0 erzeugt kein JSON. NULL wirkt wie 0. JSON kann zusätzlich zu jedem ResultSetArt-Modus angefordert werden. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max) OUTPUT für das durch @JsonErzeugen=1 erzeugte Objekt. Empfänger als nvarchar(max)-Variable mit OUTPUT binden. Wird zu Beginn auf NULL gesetzt und bleibt ohne JSON-Erzeugung sowie bei Hilfe NULL. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Deklarierter bit-Eingabeparameter, nach der Signatur im Prozedurkörper nicht referenziert. Für 0, 1, NULL oder Auslassen ist daher keine Wirkung belegt; keine Funktion aus dem Namen ableiten. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 oder NULL führt normal aus; NULL wird wie 0 behandelt. 1 druckt Hilfe und kehrt sofort zurück. Zuvor setzt die Procedure @Json, @StatusCodeOut, @IsPartialOut, @ErrorNumberOut und @ErrorMessageOut auf NULL. Hilfe umgeht TABLE-Vorprüfung, normale Parametervalidierung und Quellenzugriffe. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit-Schalter 0 oder 1 übergeben; numerisch 0 wird 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler varchar(40) OUTPUT für Sammelstatus; mit OUTPUT empfangen. Beim Eintritt NULL, bei Hilfe weiterhin NULL. Erreichbare Werte im normalen Ablauf: AVAILABLE (vollständig gesammelt), AVAILABLE_LIMITED (sichtbare Ausführung mit partieller Sammlung oder ohne nachweisbar sichtbare Ausführung nach leerem beziehungsweise wegen Zeitbudget ausgelassenem Kopfread), INVALID_PARAMETER (Hauptvalidierung verhindert Quellenzugriff), DENIED_PERMISSION (Zugriff verweigert), SOURCE_UNAVAILABLE (Katalog/Quelle nicht verfügbar), UNAVAILABLE_PLATFORM (nicht unterstützte Linux-Plattformbeobachtung), ERROR_HANDLED (behandelter sonstiger Fehler der Katalogsichtbarkeits- oder Execution-Quelle). TABLE-Preflight kann vorher THROW auslösen; dann ist kein Status-OUTPUT garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler bit OUTPUT für Partialität, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL. Im normalen Ablauf 0 = vollständig, 1 = teilweise oder durch Hauptparameterfehler verhindert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler int OUTPUT für die maßgebliche erfasste SQL-Fehlernummer, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler können THROW auslösen statt diesen OUTPUT zu befüllen. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Die Quellenfolge bestimmt das erste tatsächliche Fehlerpaar; reine Hauptparameterfehler und reine Limit-/Sichtbarkeitswarnungen setzen keine synthetische Fehlernummer.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(4000) OUTPUT; Default: NULL. Optionales nvarchar(4000) OUTPUT für die maßgebliche erfasste SQL-Fehlermeldung, mit OUTPUT empfangen. Beim Eintritt NULL und bei Hilfe NULL; bei fehlerfreier Sammlung NULL. TABLE-Vorprüfungsfehler sind nicht als hier abgefangene Ausgabe garantiert. Der Eingabewert einschließlich NULL oder Leertext steuert die Analyse nicht und wird beim Eintritt verworfen. Ausgelassen gilt der deklarierte Default NULL. Zusammen mit @ErrorNumberOut wird das erste tatsächliche native Fehlerpaar nach Quellenfolge projiziert; eine reine Hauptparameterablehnung setzt hier keinen synthetischen Text.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SchemaVersion] int NOT NULL , [ExecutionId] bigint NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| execution | 1 | 1 | [ExecutionId] bigint NOT NULL , [FolderName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProjectLsn] bigint NULL , [OperationType] smallint NULL , [ExecutionStatus] int NULL , [CreatedTime] datetimeoffset(7) NULL , [StartTime] datetimeoffset(7) NULL , [EndTime] datetimeoffset(7) NULL , [Use32BitRuntime] bit NULL |
| executables | 1 | 1 | [StatisticsId] bigint NOT NULL , [ExecutionId] bigint NOT NULL , [ExecutableId] bigint NULL , [ExecutableName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StartTime] datetimeoffset(7) NULL , [EndTime] datetimeoffset(7) NULL , [ExecutionDurationMs] int NULL , [ExecutionResult] smallint NULL |
| messages | 1 | 1 | [EventMessageId] bigint NOT NULL , [ExecutionId] bigint NOT NULL , [MessageTime] datetimeoffset(7) NULL , [MessageType] smallint NULL , [MessageSourceType] smallint NULL , [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventName] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MessageSourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SubcomponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MessageCode] int NULL |
| parameters | 1 | 1 | [ExecutionParameterId] bigint NOT NULL , [ExecutionId] bigint NOT NULL , [ObjectType] smallint NULL , [ParameterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParameterDataType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsSensitive] bit NULL , [IsRequired] bit NULL , [IsValueSet] bit NULL , [IsRuntimeOverride] bit NULL |
| phases | 1 | 1 | [PhaseStatsId] bigint NOT NULL , [ExecutionId] bigint NOT NULL , [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TaskName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SubcomponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StartTime] datetimeoffset(7) NULL , [EndTime] datetimeoffset(7) NULL |
| rowFlow | 1 | 1 | [DataStatsId] bigint NOT NULL , [ExecutionId] bigint NOT NULL , [PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TaskName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RowsSent] bigint NULL , [CreatedTime] datetimeoffset(7) NULL |
| findings | 1 | 1 | [FindingOrdinal] int NOT NULL , [FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ExecutionId] bigint NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ObservedRowCount] bigint NULL , [ReturnedRowCount] bigint NULL , [IsTruncated] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int NOT NULL , [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_SsisCatalogExecutionAnalysis liest strukturierte Metadaten genau einer positiven Execution-ID aus lokaler SSISDB. Die Procedure startet oder stoppt keine Pakete. Meldungstexte, Parameterwerte, Pfade und Host- oder Identitätswerte werden nicht gelesen. Getrennte Katalogabfragen bilden keine atomare Gesamtsicht.

Die fünf OUTPUT-Parameter werden beim Eintritt auf NULL gesetzt; Hilfe kehrt vor TABLE-Vorprüfung, fachlicher Parametervalidierung und Quellenreads zurück. Bei normaler Analyse ist das Zeitbudget kooperativ und beendet keine bereits laufende Abfrage.

Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1;

Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @MaxZeilen=200, @ResultSetArt='RAW';

Beispiel: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SsisCatalogExecutionAnalysis
Version      : 1.0.0
Stand        : 2026-10-16
Typ          : Stored Procedure
Zweck        : Liest strukturierte Metadaten einer expliziten SSISDB-Ausführung.
Datenschutz  : Keine Meldungs-, Parameter-, Pfad-, Host- oder Identitätswerte.
Grenze       : Keine Aktionen; Zeitbudget kooperativ zwischen sieben Quellen.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SsisCatalogExecutionAnalysis liest strukturierte Metadaten genau einer positiven Execution-ID aus lokaler SSISDB. Die Procedure startet oder stoppt keine Pakete. Meldungstexte, Parameterwerte, Pfade und Host- oder Identitätswerte werden nicht gelesen. Getrennte Katalogabfragen bilden keine atomare Gesamtsicht.
Die fünf OUTPUT-Parameter werden beim Eintritt auf NULL gesetzt; Hilfe kehrt vor TABLE-Vorprüfung, fachlicher Parametervalidierung und Quellenreads zurück. Bei normaler Analyse ist das Zeitbudget kooperativ und beendet keine bereits laufende Abfrage.
Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1;
Beispiel: EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @MaxZeilen=200, @ResultSetArt='RAW';
Beispiel: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

