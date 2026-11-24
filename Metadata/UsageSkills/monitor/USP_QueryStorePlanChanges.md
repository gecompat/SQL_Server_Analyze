---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStorePlanChanges"
schema_name: "monitor"
object_name: "USP_QueryStorePlanChanges"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Abfragen mit mehreren Query-Store-Plänen und begrenzt die globale Ausgabe über lokale N+1-Kandidaten."
source_path: "Code/05_QueryStore/040_USP_QueryStorePlanChanges.sql"
---

# monitor.USP_QueryStorePlanChanges

## Zweck und Einsatz

Liefert Abfragen mit mehreren Query-Store-Plänen und begrenzt die globale Ausgabe über lokale N+1-Kandidaten. Ein optionaler Filter beschränkt die Referenzdatenbanken.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStorePlanChanges]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_query]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ReferencedDatabaseNames | nvarchar(max) | nein | NULL |
| @ReferencedDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @QueryId | bigint | nein | NULL |
| @QueryHash | binary(8) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @NurMehrerePlaene | bit | nein | 1 |
| @MitPlanXml | bit | nein | 0 |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MaxZeilen | int | nein | 100 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. Der Filter wirkt auf die Summaryaggregation; der Planexport enthält anschließend alle gespeicherten Pläne der ausgewählten Datenbank-/Querykeys.

**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.

**@QueryHash:** @QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. NULL ohne Zeitfilter. Sonst skalarer UTC-Grenzzeitpunkt; Query qualifiziert, wenn ein Plan last_compile_start_time >= Wert ODER last_execution_time >= Wert erfüllt. Keine relative Stunde/obere Grenze; Plandetails bleiben zeitlich unbeschränkt. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden.

**@NurMehrerePlaene:** @NurMehrerePlaene bit; Default: 1. 1 und NULL verlangen HAVING COUNT_BIG(*)>1; NULL wird nicht coalesced. 0 schließt auch Queries mit genau einem Plan ein. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gezählt werden Planzeilen nach Zeit-/Referenzfilter der Summaryaggregation; nicht zwingend gleichzeitig aktive oder verschiedene Planhashes.

**@MitPlanXml:** @MitPlanXml bit; Default: 0. 1 fordert gespeicherte XML für alle lokal gesammelten Pläne an, parst/exportiert vor globalem Querylimit; Deep-Prüfung. 0 unterdrückt Ausgabe/Parsing mit NOT_REQUESTED. NULL unterdrückt ebenfalls, Status PENDING. Referenzfilter können XML unabhängig vom Export lesen. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Gespeicherter historischer Showplan, kein aktueller Laufzeitplan. Ungültiges XML bleibt als Rohtext mit Fehler-/Partialhinweis erhalten.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'TOP'. Ausgelassen/NULL: TOP. Nach äußerem Trimmen von U+0020 und Großschreibungsnormalisierung sind genau TOP und VOLL erlaubt: TOP verwendet lokale N+1-Querykandidaten und das globale Querylimit; VOLL aktiviert QUERY_STORE_DEEP, hebt @MaxZeilen aber nicht auf. Leer, nur Leerzeichen oder andere Werte sind ungültig. Deep wird außerdem durch @MitPlanXml=1, ein normalisiertes Zeilenlimit über 1000 (einschließlich NULL/0 unbegrenzt) oder einen nicht-NULL Referenzfilter aktiviert; @VonUtc allein aktiviert Deep nicht.

**@MaxZeilen:** @MaxZeilen int; Default: 100. Positiv: globales Limit an Query-Summaryzeilen. NULL/0 unbegrenzt; negativ ungültig. Je Quelle lokale N+1-Kandidaten (bei int.MaxValue N ohne Überlauf), danach globale Sortierung LastExecutionTimeUtc DESC, LastCompileTimeUtc DESC; gleiche Sortwerte nicht eindeutig. Limit zählt Queries, nicht Pläne; alle Pläne der Querykeys bleiben. >1000 sowie NULL/0 unbegrenzt aktivieren Deep.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. Begrenzt nur QuerySqlText in Unicode-Zeichen/SC-Codepoints, nicht Grapheme und nicht Plan-XML. NULL/0 vollständig; negativ ungültig. Projektion/Truncationbewertung vor globaler Querybegrenzung.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert vier Resultsets (Metadaten, Querysummaries, Plandetails, Warnungen); CONSOLE liefert die Querysummary mit Ergebnislabel, bei Leere eine Hinweiszeile; TABLE schreibt nur die angeforderte nichtleere Teilmenge queries/plans in geprüfte lokale Temp-Ziele; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight läuft nur im normalen Pfad nach dem Hilfezweig und vor der Fachvalidierung.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE. Nichtleerer Wert außerhalb TABLE löst im normalen Pfad vor der Fachvalidierung Fehler aus; Hilfe kehrt vorher zurück. NULL/leer sind im TABLE-Aufruf ungültig. Erforderlich ist ein nichtleeres JSON-Objekt mit einem oder beiden Schlüsseln queries/plans; Werte sind unterschiedliche, vorhandene, leere lokale #Temp-Tabellen mit genau einer beliebigen Seed-Spalte. Resultsetnamen werden exakt und case-sensitiv geprüft; doppelte Namen, doppelte Ziele, unbekannte Namen, Nicht-Stringwerte, Zielnamen >116 Zeichen, ##-Ziele und Namen mit #Monitor-Präfix sind ungültig. Eine Seed-Zeile ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das jeweilige Ergebnisschema. queries bezeichnet die begrenzte Querysummary, plans alle gespeicherten Pläne ihrer ausgewählten Querykeys.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt JSON unabhängig von ResultSetArt. 0 oder NULL deaktiviert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. Die JSON-Objekte heißen meta (Metadaten), queries (begrenzte Summaries), plans (alle Pläne ausgewählter Querykeys), warnings (Warnungen).

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für JSON mit meta, queries, plans und warnings; beim Eintritt NULL, nur bei @JsonErzeugen=1 befüllt. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ausgelassen wird kein Ergebnis an den Aufrufer zurückgegeben; ein Eingabewert wird überschrieben. Bei Hilfe bleibt NULL; bei einem ungefangenen THROW besteht keine Zusage einer OUTPUT-Rückübertragung. Summaries sind global begrenzt, Pläne vollständig je ausgewähltem Querykey.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt Hilfe aus und kehrt vor normaler Parameterprüfung/Datenbankverarbeitung zurück. Typbindung bleibt erforderlich; die TABLE-Mapping-Prüfung läuft nur im normalen Pfad. 0/NULL normale Ausführung. @Json beim Eintritt auch für Hilfe NULL; PrintMeldungen steuert Hilfe-PRINTs nicht. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

## Resultate und Ausgabe

RAW/CONSOLE/NONE sowie JSON mit meta, queries, plans, warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| queries | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCount] bigint,[ForcedPlanCount] bigint,[DistinctPlanHashCount] bigint,[FirstCompileTimeUtc] datetimeoffset NULL,[LastCompileTimeUtc] datetimeoffset NULL,[LastExecutionTimeUtc] datetimeoffset NULL,[TotalCompiles] bigint,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| plans | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[PlanId] bigint,[QueryPlanHash] binary(8),[EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS,[CompatibilityLevel] smallint,[IsParallelPlan] bit,[IsForcedPlan] bit,[PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[ForceFailureCount] bigint,[LastForceFailureReason] int,[LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CountCompiles] bigint,[InitialCompileStartTimeUtc] datetimeoffset,[LastCompileStartTimeUtc] datetimeoffset,[LastExecutionTimeUtc] datetimeoffset,[AverageCompileDurationMs] decimal(38,3),[LastCompileDurationMs] decimal(38,3),[QueryPlanTextFallback] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanSourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanSourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanCapturedAtUtc] datetime2(3) NULL,[QueryPlanStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryPlanCharacters] bigint NULL,[QueryPlanBytes] bigint NULL,[QueryPlan] xml NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStorePlanChanges]
      @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStorePlanChanges

monitor.USP_QueryStorePlanChanges wertet gespeicherte Query-Store-Metadaten sichtbarer Benutzerdatenbanken aus. Ausgabe sind historische Pläne und Querydaten, kein aktueller Laufzeitplan und kein Performance-/Gesundheitsnachweis.

Die folgenden Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 beendet vorher; die SQL-Typbindung bleibt aktiv, Mappingprüfungen werden übersprungen. Zeichenparameter unterliegen bereits bei der Bindung ihrer deklarierten SQL-Typbreite.

DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';

DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStorePlanChanges
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Abfragen mit mehreren Query-Store-Plänen und begrenzt
               die globale Ausgabe über lokale N+1-Kandidaten. Ein optionaler
               Filter beschränkt die Referenzdatenbanken.
Ausgabe      : RAW/CONSOLE/NONE sowie JSON mit meta, queries, plans, warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStorePlanChanges
monitor.USP_QueryStorePlanChanges wertet gespeicherte Query-Store-Metadaten sichtbarer Benutzerdatenbanken aus. Ausgabe sind historische Pläne und Querydaten, kein aktueller Laufzeitplan und kein Performance-/Gesundheitsnachweis.
Die folgenden Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 beendet vorher; die SQL-Typbindung bleibt aktiv, Mappingprüfungen werden übersprungen. Zeichenparameter unterliegen bereits bei der Bindung ihrer deklarierten SQL-Typbreite.
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';
DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStorePlanChanges_HelpQueries]([Seed] int NULL);
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

BEGIN TRY
    EXEC [monitor].[USP_QueryStorePlanChanges]
          @QueryStoreDatabaseNames = N'[ExampleDatabase]'
        , @VonUtc = @ExampleVonUtc
        , @MaxZeilen = 100
        , @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"queries":"#QueryStorePlanChanges_HelpQueries"}';

    SELECT * FROM [#QueryStorePlanChanges_HelpQueries];
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#QueryStorePlanChanges_HelpQueries];
    THROW;
END CATCH;
```

