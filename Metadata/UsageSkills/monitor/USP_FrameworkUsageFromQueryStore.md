---
skill_format_version: "1.0.0"
name: "monitor.USP_FrameworkUsageFromQueryStore"
schema_name: "monitor"
object_name: "USP_FrameworkUsageFromQueryStore"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Ermittelt aus dem Query Store der Frameworkdatenbank, welche monitor-Procedures tatsächlich ausgeführt wurden und welche aggregierte Laufzeit-, CPU-, I/O- und Plan-Evidenz vorliegt."
source_path: "Code/09_VersionAdaptive/500_USP_FrameworkUsageFromQueryStore.sql"
---

# monitor.USP_FrameworkUsageFromQueryStore

## Zweck und Einsatz

Ermittelt aus dem Query Store der Frameworkdatenbank, welche monitor-Procedures tatsächlich ausgeführt wurden und welche aggregierte Laufzeit-, CPU-, I/O- und Plan-Evidenz vorliegt.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.database_query_store_options, sys.query_store_query, sys.query_store_plan, sys.query_store_runtime_stats, sys.objects und sys.schemas. Jede Quelle wird je Aufruf höchstens einmal logisch gelesen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxZeilen | int | nein | 100 |
| @MinAusfuehrungen | bigint | nein | 1 |
| @ZeitraumTage | int | nein | NULL |
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

**@MaxZeilen:** @MaxZeilen int; Default: 100. NULL oder 0 bedeutet unbegrenzt; positive Werte begrenzen nur usage nach Aggregation und Mindestfilter. Negative Werte sind ungültig. HasMoreRows nutzt einen zusätzlichen Kandidaten mit BIGINT-Arithmetik, auch bei int.MaxValue; ReturnedRowCount ist die endgültige usage-Anzahl. Der frameworkUsage-Eintrag im sourceStatus meldet ebenfalls nur die endgültige ausgegebene Anzahl, nicht die vollständige Kandidatenmenge. Als positive ganze Zahl von 1 bis 2147483647 übergeben. Sortierung nach ExecutionCount absteigend, danach ProcedureName aufsteigend. Status- und Warningmengen werden nicht begrenzt; ein Limit allein setzt IsPartial nicht.

**@MinAusfuehrungen:** @MinAusfuehrungen bigint; Default: 1. Mindestens 1; NULL und kleinere Werte sind ungültig. Filtert nach Aggregation je Procedure anhand der Summe erfasster Statementausführungen, nicht äußerer EXEC-Aufrufe. Als ganze bigint-Zahl von 1 bis 9223372036854775807 übergeben.

**@ZeitraumTage:** @ZeitraumTage int; Default: NULL. NULL oder 0 bedeutet gesamte sichtbare Retention; 1 bis 365000 ist zulässig. Negative Werte und größere Werte sind ungültig. Positiv berechnet CutoffUtc aus SYSUTCDATETIME() und verwendet last_execution_time >= CutoffUtc; die vollständige Runtime-Stats-Zeile zählt, keine anteilige Intervallüberlappung. Ganze Tage übergeben. NULL und 0 erscheinen in der Fenstermetadatenangabe als NULL; die Procedure setzt weder Retention noch Query-Store-Capture um.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. 0 bis 60000 zulässig; NULL und Werte außerhalb ungültig. 0 bedeutet kein Warten auf gesperrte Ressourcen. Setzt ein SQL-Lock-Timeout, kein Ausführungszeitbudget; im regulären Finalize-Pfad wird der vorherige @@LOCK_TIMEOUT wiederhergestellt. Positive ganze Millisekunden von 1 bis 60000 übergeben; eine allgemeine Wiederherstellungszusage bei ungefangenen Fehlern folgt daraus nicht.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Trimmen und Großschreibung. Geschlossene Werte: CONSOLE liefert nur usage mit Ergebnislabel oder Leeranzeige; RAW liefert moduleStatus, usage, sourceStatus, warnings; TABLE schreibt eine nichtleere Teilmenge der vier erlaubten Gruppen in lokale Ziele; NONE unterdrückt fachliche Resultsets. NULL, leerer Text und andere Werte sind ungültig. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen; ein solcher Leerwert ist ungültig. Die SQL-Bindung an varchar(16) erfolgt vor der Prüfung. JSON und technische Meldungen werden unabhängig gesteuert.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt liefert dort im normalen Ablauf INVALID_PARAMETER, keinen frühen Mapping-THROW. Bei TABLE ist ein nichtleeres JSON-Objekt mit einer nichtleeren Teilmenge von vier binär exakten Schlüsseln erforderlich: moduleStatus (Gesamtstatus und Zähler), usage (Nutzungsaggregate), sourceStatus (Quellenstatus), warnings (Warnungen). Jeder Stringwert benennt ein eigenes vorhandenes, leeres lokales #Temp-Ziel mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, case-insensitiv doppelte Ziele, Nicht-Stringwerte oder ungültige Ziele scheitern im ThrowOnError-Preflight nach Hilfe, aber vor normaler Fachvalidierung. Der Writer ersetzt die Seed-Struktur; nicht angeforderte Ziele werden nicht verändert.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. NULL ungültig. 0 erzeugt kein JSON; 1 erzeugt meta, usage, sourceStatus und warnings, kein moduleStatus-Array. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. JSON ist unabhängig von ResultSetArt. meta beschreibt Gesamtstatus/Zähler, usage die begrenzte Nutzungsmenge, sourceStatus die Quellenlage und warnings Warnungen.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT wird am Aufrufanfang auf NULL gesetzt, auch bei HELP. Bei normaler Ausführung wird es nur mit @JsonErzeugen=1 als JSON-Objekt gesetzt. Zum Empfang eine nvarchar(max)-Variable als Json=@Variable OUTPUT binden; der Eingabewert wird verworfen. Ohne OUTPUT-Bindung gibt es keinen übernommenen Wert; ungefangene Fehler garantieren keine OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. NULL ungültig. 0 ist still; 1 gibt nur bei Status außerhalb AVAILABLE und AVAILABLE_EMPTY eine Meldung mit Schweregrad 10 aus. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@Hilfe:** @Hilfe bit; Default: 0. Nur 1 aktiviert HELP. HELP beendet nach Hilfetexten vor TABLE-Preflight und regulärer Parameterprüfung; @Json ist bereits NULL, die vier Status-/Fehler-OUTPUT-Parameter bleiben unverändert. NULL aktiviert HELP nicht und wird nicht separat geprüft. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT des abschließenden Modulstatus, kein Eingabefilter. Eine varchar(40)-Variable mit OUTPUT binden. Vollständige aktuelle Statusmenge: AVAILABLE (ausgabefähige Nutzung), AVAILABLE_EMPTY (lesbarer Query Store ohne Treffer nach Filtern), INVALID_PARAMETER (ungültiger Aufruf), UNAVAILABLE_FEATURE (Query Store nicht lesbar aktiv), DENIED_PERMISSION (kontrollierter Berechtigungsfehler) und ERROR_HANDLED (anderer kontrollierter Quellenfehler, auch Locktimeout 1222). Bei Hilfe bleibt der Eingabewert unverändert; im normalen Ablauf wird erst nach Resultset-/TABLE-/Meldungsausgabe zugewiesen. Bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT der abschließenden Partialität; eine bit-Variable mit OUTPUT binden, kein Eingabeschalter. 1 steht bei ungültigen Parametern und kontrolliertem Quellenfehler; 0 bei regulären Nutzungsdaten, leerem Ergebnis und UNAVAILABLE_FEATURE. Das Zeilenlimit allein setzt das Bit nicht. Bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert. Normale Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT der Modulfehlernummer; eine int-Variable mit OUTPUT binden, kein Eingabefilter. Im normalen Ablauf enthält sie bei kontrolliertem Quellenfehler ERROR_NUMBER(), sonst NULL; ein Validierungs- oder Featurestatus benötigt keine technische Fehlernummer. Bei Hilfe bleibt der Eingabewert unverändert. Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT des Modulfehlertexts; eine nvarchar(2048)-Variable mit OUTPUT binden, kein Eingabefilter. Im normalen Ablauf NULL ohne Modulfehler; sonst gesetzte Validierungs-/Featuremeldung oder Meldung des kontrollierten Quellenfehlers, nötigenfalls erste Warning nach WarningOrdinal. Bei Hilfe bleibt der Eingabewert unverändert. Zuweisung erst am Ende nach der Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [QueryStoreActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [QueryStoreReadonlyReason] bigint NULL , [RequestedWindowDays] int NULL , [MinimumExecutions] bigint NOT NULL , [ReturnedRowCount] bigint NOT NULL , [HasMoreRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| usage | 1 | 1 | [ProcedureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ExecutionCount] bigint NOT NULL , [LastExecutionTime] datetimeoffset(7) NULL , [AvgDurationMs] decimal(19,3) NULL , [AvgCpuMs] decimal(19,3) NULL , [AvgLogicalReads] decimal(19,2) NULL , [AvgMemoryGrantKB] decimal(19,2) NULL , [PlanCount] bigint NOT NULL , [QueryCount] bigint NOT NULL , [FirstSeen] datetimeoffset(7) NULL , [LastSeen] datetimeoffset(7) NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int NOT NULL , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

LOW_TO_MEDIUM. Die Aggregation ist nach Zeitraum und Ausgabezahl begrenzbar; der Query Store muss dennoch die passenden Intervalle und Pläne auswerten.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_FrameworkUsageFromQueryStore
Version      : 2.0.0
Stand        : 2026-07-26
Typ          : Stored Procedure
Zweck        : Ermittelt aus dem Query Store der Frameworkdatenbank, welche
               monitor-Procedures tatsächlich ausgeführt wurden und welche
               aggregierte Laufzeit-, CPU-, I/O- und Plan-Evidenz vorliegt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.database_query_store_options, sys.query_store_query,
               sys.query_store_plan, sys.query_store_runtime_stats,
               sys.objects und sys.schemas. Jede Quelle wird je Aufruf höchstens
               einmal logisch gelesen.
Abgrenzung   : Keine eigene Erfassung, keine Query-Store-Konfigurationsänderung,
               kein Flush, kein Cleanup und keine Benutzerattribution. Fehlende
               Query-Store-Zeilen beweisen nicht, dass eine Procedure nie lief.
Kosten       : LOW_TO_MEDIUM. Die Aggregation ist nach Zeitraum und Ausgabezahl
               begrenzbar; der Query Store muss dennoch die passenden Intervalle
               und Pläne auswerten.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_FrameworkUsageFromQueryStore
monitor.USP_FrameworkUsageFromQueryStore
Liest ausschließlich vorhandene Query-Store-Evidenz der Frameworkdatenbank.
ExecutionCount summiert erfasste Statementausführungen je Procedure, keine äußeren EXEC-Aufrufe. Mittelwerte sind nach count_executions gewichtet. Nur vorhandene Query-Store-Evidenz der aktuellen Frameworkdatenbank, keine eigene Erfassung, Querytexte, Plan-XML, Identitäten oder Konfigurationsänderung.
Hilfe endet vor TABLE-Preflight und normaler Parameterprüfung. Nur Json wird vorher NULL; vier Status-/Fehler-OUTPUTs bleiben bei Hilfe unverändert. Ausgelassen gilt jeweils der ausdrücklich bezeichnete Default.
DECLARE @FrameworkUsageHelpJson nvarchar(max);
EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @FrameworkUsageHelpJson OUTPUT;
SELECT @FrameworkUsageHelpJson AS [Json];
CREATE TABLE [#FrameworkUsageFromQueryStore_HelpExample]
(
    [Seed] int NULL
);
BEGIN TRY
    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @ResultSetArt = 'TABLE',
          @ResultTablesJson = N'{"usage":"#FrameworkUsageFromQueryStore_HelpExample"}';
    SELECT * FROM [#FrameworkUsageFromQueryStore_HelpExample];
    DROP TABLE [#FrameworkUsageFromQueryStore_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#FrameworkUsageFromQueryStore_HelpExample];
    THROW;
END CATCH;
```

