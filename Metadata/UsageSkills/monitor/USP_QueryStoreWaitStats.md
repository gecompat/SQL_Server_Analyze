---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreWaitStats"
schema_name: "monitor"
object_name: "USP_QueryStoreWaitStats"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Query-Store-Wait-Statistiken aus einer oder mehreren Quelldatenbanken mit einem exakten globalen Top-N über lokale N+1-Kandidaten."
source_path: "Code/05_QueryStore/030_USP_QueryStoreWaitStats.sql"
---

# monitor.USP_QueryStoreWaitStats

## Zweck und Einsatz

Liefert Query-Store-Wait-Statistiken aus einer oder mehreren Quelldatenbanken mit einem exakten globalen Top-N über lokale N+1-Kandidaten. Ein optionaler Filter beschränkt die Ausgabe auf in Showplans referenzierte Datenbanken.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_QueryStoreWaitStats]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseSqlNameList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[InternalCheckAnalysisPath]`, `[master].[sys].[databases]`, `[sys].[database_query_store_options]`, `[sys].[query_store_wait_stats]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

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
| @WaitCategory | nvarchar(128) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
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

**@ReferencedDatabaseNames:** @ReferencedDatabaseNames nvarchar(max); Default: NULL. ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus.

**@ReferencedDatabaseNamePattern:** @ReferencedDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert.

**@QueryId:** @QueryId bigint; Default: NULL. Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch.

**@QueryHash:** @QueryHash binary(8); Default: NULL. Ausgelassen/NULL: kein Hashfilter. Acht Byte als Binärwert übergeben, zum Beispiel 0x0123456789ABCDEF; exakter Vergleich ohne zusätzliche Werte- oder Existenzprüfung. SQL-Typkonvertierungen erfolgen vor dem Procedurekörper.

**@WaitCategory:** @WaitCategory nvarchar(128); Default: NULL. ausgelassen/NULL kein Filter. Einzelner Literalwert ohne Trim, Liste, LIKE oder Regex. wait_category_desc wird mit seiner nativen Quellcollation verglichen; keine allgemeine Case-Zusage. Zusätzlich vergleicht CONVERT(nvarchar(10),wait_category) explizit mit SQL_Latin1_General_CP1_CS_AS; 03 ist nicht 3. Leer-, Leerzeichen- und unbekannte Werte sind zulässige Literalfilter. Höchstens 128 Zeichen. Kein abgeschlossener Modul-Optionskatalog: native Beschreibung oder dezimaler Kategoriencode als Text, zum Beispiel N'3', werden als Filterwert verwendet.

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. ausgelassen/NULL wird nach Ermittlung von @BisUtc auf @BisUtc minus eine Stunde gesetzt. UTC-Start muss kleiner als @BisUtc sein, sonst INVALID_PARAMETER. Überlappung: Intervallende > @VonUtc und Intervallstart < @BisUtc; vollständige Intervalle, keine anteilige Kürzung. Leerwert ist keine datetime2-Eingabe. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig.

**@BisUtc:** @BisUtc datetime2(7); Default: NULL. ausgelassen/NULL = SYSUTCDATETIME(). UTC-Überlappungsfenster mit @VonUtc; Intervallende > Startparameter und Intervallstart < Endparameter. @VonUtc >= @BisUtc ist INVALID_PARAMETER; bei NULLem @VonUtc reicht das Fenster eine Stunde zurück. DATEDIFF(HOUR,@VonUtc,@BisUtc)>24 fordert QUERY_STORE_DEEP an. Leerwert ist keine datetime2-Eingabe. Als datetime2(7)-Variable oder ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 in UTC übergeben; keine Zeitzonenumrechnung. Keine Leerzeichenfolge als Datum verwenden. Ist @VonUtc NULL, muss das effektive Ende mindestens 0001-01-01T01:00:00.0000000 betragen, damit DATEADD eine Stunde abziehen kann. Frühere Endwerte können vor der normalen Fachvalidierung ungefangen überlaufen. Vollständig gesetzte gültige Grenzen bleiben zulässig.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'TOP'. ausgelassen/NULL = TOP; äußeres Trim und Großschreibungsnormalisierung. Geschlossene Wertemenge: TOP sammelt lokale N+1-Kandidaten je Datenbank und begrenzt danach global; VOLL fordert QUERY_STORE_DEEP an. VOLL hebt @MaxZeilen nicht auf. Leer/Leerzeichen/andere Werte sind ungültig.

**@MaxZeilen:** @MaxZeilen int; Default: 100. ausgelassen verwendet diesen Wert. NULL/0 global unbegrenzt; positiver int begrenzt global nach TotalQueryWaitTimeMs DESC, LastIntervalEndUtc DESC. Je DB bis N+1 lokale Kandidaten, bei INT_MAX ohne +1. Negative Werte INVALID_PARAMETER; keine Tie-Garantie. Unbegrenzt oder >1000 fordert QUERY_STORE_DEEP an. VOLL hebt das Limit nicht auf. Zähler, HasMoreRows, Textprojektion und Warnungen entstehen vor dem globalen Limit.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int; Default: 4000. ausgelassen verwendet diesen Wert. NULL/0 vollständiger SQL-Text; positiver Wert begrenzt Zeichen und liefert Originalzeichen/-bytes sowie Truncation-Flag. Negativ = INVALID_PARAMETER mit leerer fachlicher Exportmenge. Kürzung erzeugt bei @PrintMeldungen=1 eine technische Severity-10-Warnung. NULL/0 löst allein kein QUERY_STORE_DEEP aus. Surrogatpaare zählen als ein SC-Zeichen, keine Grapheme.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. ausgelassen verwendet diesen Wert. Nach Trim/Upper exakt RAW (Metadaten, Rohdaten, Warnungen), CONSOLE (Waitdaten mit Ergebnislabel, bei Leere eine Hinweiszeile; keine zusätzlichen Metadaten-/Warnungsgrids), TABLE (nur waitStats ins geprüfte lokale Ziel) oder NONE (keine normalen Resultsets). NULL/leer/Leerzeichen/andere Werte ungültig. JSON wird separat gesteuert. TABLE-Preflight läuft im normalen Pfad nach dem Hilfezweig und vor der Fachvalidierung.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel waitStats und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. ausgelassen/0/NULL erzeugt kein JSON. 1 erzeugt @Json mit meta, waitStats und warnings aus der Exportmenge. Unabhängig von @ResultSetArt, auch mit NONE; erweitert den Scope nicht. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

**@Hilfe:** @Hilfe bit; Default: 0. ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung bleibt aktiv; der TABLE-Mapping-Preflight wird im Hilfezweig nicht ausgeführt; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden.

## Resultate und Ausgabe

RAW, CONSOLE, TABLE oder NONE; optional JSON mit meta, waitStats, warnings. Steuerwerte werden case-insensitiv normalisiert.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| waitStats | 1 | 1 | [QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[QueryId] bigint,[PlanId] bigint,[QueryHash] binary(8),[QueryPlanHash] binary(8),[WaitCategory] tinyint,[WaitCategoryDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[ExecutionTypeDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[FirstIntervalStartUtc] datetimeoffset,[LastIntervalEndUtc] datetimeoffset,[RecordedRows] bigint,[TotalQueryWaitTimeMs] bigint,[AverageRecordedQueryWaitTimeMs] decimal(38,3),[MaxQueryWaitTimeMs] bigint,[QuerySqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS,[SourceType] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CapturedAtUtc] datetime2(3) NULL,[EvidenceScope] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsAggregated] bit NULL,[QuerySqlTextCharacters] bigint NULL,[QuerySqlTextBytes] bigint NULL,[QuerySqlTextIsTruncated] bit NOT NULL DEFAULT(0),[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreWaitStats]
      @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreWaitStats

monitor.USP_QueryStoreWaitStats liefert aggregierte, retentionbegrenzte Query-Store-Wait-Statistiken aus geeigneten Quelldatenbanken. Optionale Filter begrenzen Query, Waitkategorie, UTC-Intervall und Datenbankreferenzen in gespeicherten Showplans; je Quelldatenbank werden lokale N+1-Kandidaten gesammelt, danach gilt das globale @MaxZeilen-Limit.

Die folgenden Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 beendet vorher; die SQL-Typbindung bleibt aktiv, Mappingprüfungen werden übersprungen. Zeichenparameter unterliegen bereits bei der Bindung ihrer deklarierten SQL-Typbreite.

DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';

DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreWaitStats
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Query-Store-Wait-Statistiken aus einer oder mehreren
               Quelldatenbanken mit einem exakten globalen Top-N über lokale
               N+1-Kandidaten. Ein optionaler Filter beschränkt die Ausgabe auf
               in Showplans referenzierte Datenbanken.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit meta, waitStats,
               warnings. Steuerwerte werden case-insensitiv normalisiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreWaitStats
monitor.USP_QueryStoreWaitStats liefert aggregierte, retentionbegrenzte Query-Store-Wait-Statistiken aus geeigneten Quelldatenbanken. Optionale Filter begrenzen Query, Waitkategorie, UTC-Intervall und Datenbankreferenzen in gespeicherten Showplans; je Quelldatenbank werden lokale N+1-Kandidaten gesammelt, danach gilt das globale @MaxZeilen-Limit.
Die folgenden Validierungsregeln gelten im normalen Analysepfad. @Hilfe=1 beendet vorher; die SQL-Typbindung bleibt aktiv, Mappingprüfungen werden übersprungen. Zeichenparameter unterliegen bereits bei der Bindung ihrer deklarierten SQL-Typbreite.
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @MaxZeilen = 100
    , @ResultSetArt = 'RAW';
DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = @ExampleVonUtc
    , @BisUtc = @ExampleBisUtc
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @ExampleJson OUTPUT;

SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreWaitStats_HelpExample]([Seed] int NULL);
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreWaitStats]
          @QueryStoreDatabaseNames = N'[ExampleDatabase]'
        , @VonUtc = @ExampleVonUtc
        , @BisUtc = @ExampleBisUtc
        , @MaxZeilen = 100
        , @ResultSetArt = 'TABLE'
        , @ResultTablesJson = N'{"waitStats":"#QueryStoreWaitStats_HelpExample"}';

    SELECT * FROM [#QueryStoreWaitStats_HelpExample];
    DROP TABLE IF EXISTS [#QueryStoreWaitStats_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#QueryStoreWaitStats_HelpExample];
    THROW;
END CATCH;
```

