---
skill_format_version: "1.0.0"
name: "monitor.USP_CompileContextAnalysis"
schema_name: "monitor"
object_name: "USP_CompileContextAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure trennt lokale OPTIMIZED_SP_EXECUTESQL-Konfiguration von serverweiten Compile-Countern, Compile-Waits und Cachemetadaten."
source_path: "Code/08_ServerHealth/250_USP_CompileContextAnalysis.sql"
---

# monitor.USP_CompileContextAnalysis

## Zweck und Einsatz

Die Procedure trennt lokale OPTIMIZED_SP_EXECUTESQL-Konfiguration von serverweiten Compile-Countern, Compile-Waits und Cachemetadaten.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CompileContextAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `master.sys.databases`, `[sys].[database_scoped_configurations]`, `[sys].[sp_executesql]`, `sys.database_scoped_configurations`, `[sys].[dm_os_sys_info]`, `sys.dm_os_sys_info` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @SampleSeconds | tinyint | nein | 0 |
| @MaxZeilen | int | nein | 2000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, N'' und eine nach außen getrimmte leere Zeichenfolge bedeuten keine Einschränkung; andernfalls ist eine eindeutige Pipe-Liste exakter SQL-Datenbanknamen zulässig. Es gilt die bracket-aware Namenslistenprüfung des Datenbankauswahlhelfers: äußere Segmentleerzeichen werden entfernt, Namen mit Leerzeichen oder Pipe können bracket-quotiert werden, und ]] maskiert darin eine schließende Klammer. Ungültige Elemente, doppelte gültige Namen sowie eine gleichzeitige nichtleere Namensliste und ein gesetztes Pattern führen zu INVALID_PARAMETER. Die Procedure fordert für die Auswahlklasse STANDARD_CURRENT an; der gebundene Klassenvertrag setzt dafür kein High-Impact-Gruppengate. Die Auswahl umfasst sichtbare, zugreifbare, online befindliche Datenbanken ohne Datenbank-Snapshots; fehlende oder nicht auswählbare explizite Namen werden als DATABASE_SELECTION-Warnings gemeldet. Ohne Einschränkung gibt es keinen CURRENT-Scope und kein Vorab- oder Datenbankanzahllimit.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbanken mit database_id 1 bis 4 aus; 1 lässt master, tempdb, model und msdb in die Auswahl zu. NULL wird als ungültiger Parameter behandelt. Der Schalter gewährt selbst keine Berechtigung und macht nicht zugreifbare Datenbanken nicht sichtbar. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern. Ein gesetztes Pattern wird nach dem gemeinsamen Parservertrag außen getrimmt; die Präfixe like:, regex: und regexi: wählen LIKE, case-sensitive Regex beziehungsweise case-insensitive Regex, ohne Beachtung der Präfixgroßschreibung. Ohne Präfix gilt LIKE. Nach dem Präfix darf der Inhalt nicht leer sein; ein ungültiges/leeres Pattern und die gleichzeitige Verwendung mit einer nichtleeren exakten Namensliste führen zu INVALID_PARAMETER. LIKE wird case-sensitive ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank; andernfalls meldet der Auswahlhelfer UNAVAILABLE_FEATURE. Der Regextext wird nicht vorab syntaktisch geprüft. NULL ist damit von leerem Text und einem leeren Präfix zu unterscheiden. Eine fehlerhafte Regex kann im Auswahlhelfer beim Ausführen scheitern; der umgebende CATCH dokumentiert eine partielle DATABASE_SELECTION-Quelle, während unabhängige Serverquellen weiterlaufen können.

**@SampleSeconds:** @SampleSeconds tinyint; Default: 0. 0 liest Counter und Waits jeweils einmal als Momentaufnahme; Before-, Delta-, Rate- und Intervallwerte sind dabei NULL. 1 bis 60 führt zwei Aufnahmen aus und genau ein gemeinsames WAITFOR mit der angegebenen Anzahl Sekunden dazwischen aus. Counter und Waits erhalten getrennte, unmittelbar nach ihrer jeweiligen Aufnahme gebundene UTC-Intervalle; die tatsächliche Dauer kann von der angeforderten Wartezeit abweichen. NULL oder ein Wert über 60 ist INVALID_PARAMETER; ein negativer Wert kann im tinyint-Eingabetyp nicht dargestellt werden. Sampling bleibt serverweit und wird nicht den ausgewählten Datenbanken zugeordnet.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. 0 und NULL bedeuten keine Zeilenbegrenzung. Jeder positive int-Wert von 1 bis 2.147.483.647 begrenzt jeweils configurations, counters, waits, cache, sourceStatus und warnings nach deren Erhebung; moduleStatus bleibt eine einzelne Zeile. Die jeweiligen Gruppen werden nach ihren festen Schlüsseln sortiert und unabhängig gekürzt. Die Begrenzung reduziert weder die gelesenen Datenquellen noch die Zahl ausgewählter Datenbanken; die gemeldete RowCount summiert die nach der jeweiligen Kürzung verbleibenden Zeilen aus configurations, counters, waits und cache; sourceStatus und warnings zählen nicht mit. Sie ist keine Zählung der vom gewählten Ausgabepfad tatsächlich gelieferten Zeilen. Negative Werte führen zu INVALID_PARAMETER.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Der Wert wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind genau RAW (sieben fachliche Resultsets in der Reihenfolge moduleStatus, configurations, counters, waits, cache, sourceStatus, warnings), TABLE (nur die per JSON-Mapping ausgewählten Resultgruppen in lokale Temp-Tabellen schreiben), CONSOLE (eine formatierte Übersicht aus Konfigurationen, Counter-Rohwerten, Waitzeit und Cacheeinträgen sowie einer Modulstatuszeile mit Status und RowCount) und NONE (keine fachlichen Resultsets). NULL oder ein anderer Wert wird zu einem leeren beziehungsweise nicht erlaubten Modus und führt zu INVALID_PARAMETER. JSON-Erzeugung und Meldungsausgabe werden unabhängig davon gesteuert.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur mit TABLE wird die JSON-Zuordnung verarbeitet; bei einem anderen Modus führt ein nichtleerer, außen getrimmter Wert zu einer ausgelösten Ausnahme. Für TABLE ist ein gültiges, nichtleeres JSON-Objekt mit mindestens einer Zuordnung erforderlich. Erlaubte, exakt groß-/kleinschreibungsabhängige Schlüssel sind moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings; jeder Wert benennt eine vorhandene, leere lokale #Temp-Tabelle. Die Zielnamen müssen höchstens 116 Zeichen lang sein, dürfen nicht mit ## beginnen und nicht dem reservierten Präfix #Monitor entsprechen. Doppelte Schlüssel oder Ziele, unbekannte Schlüssel, NULL-/Nicht-String-Werte, fehlende oder gefüllte Ziele sowie Ziele mit mehr als einer Seed-Spalte werden vor den fachlichen Quellenzugriffen abgelehnt. Der spätere Writer ersetzt die Seed-Spalte durch das fachliche Ergebnisschema. NULL, leerer oder nur aus U+0020-Leerzeichen bestehender Wert genügt bei TABLE nicht und löst INVALID_RESULT_TABLE_MAPPING aus. moduleStatus bedeutet Modulstatus, configurations Konfigurationen, counters Counterwerte, waits Waitwerte, cache Cacheaggregate, sourceStatus Quellenstatus und warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von der ResultSetArt ein JSON-Dokument im OUTPUT-Parameter, einschließlich Metadaten und der sieben Gruppen moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings. 0 erzeugt es nicht; dann bleibt @Json NULL. NULL ist INVALID_PARAMETER. Schema 1 enthält eine einzelne meta-Struktur mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage; Gruppen sind Arrays, leere Gruppen werden als [] ausgegeben und NULL-Spalten bleiben enthalten. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Zum Empfang ist eine passend typisierte lokale Variable mit OUTPUT-Bindung zu übergeben. Der Wert wird zu Beginn des Aufrufs vor dem HELP-Zweig auf NULL gesetzt. Bei aktivierter JSON-Erzeugung enthält er das Schema-1-Dokument; bei deaktivierter Erzeugung und auch bei HELP bleibt er NULL. Die Initialisierung findet vor möglichen Ausnahmen statt. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 lässt bei einem nicht AVAILABLE-Gesamtstatus eine Statusmeldung mit Schweregrad 10 und WITH NOWAIT ausgeben; 0 unterdrückt diese Meldung. NULL ist INVALID_PARAMETER. Der Schalter unterdrückt weder CONSOLE-Ausgaben noch fachliche Resultsets oder die OUTPUT-Bindungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 druckt die eingebauten Hilfetexte, setzt die vier Status-/Fehler-OUTPUTs auf AVAILABLE, 0, NULL und NULL und kehrt vor Validierung, Kandidatenauswahl und Quellenzugriff zurück. @Json wurde bereits vorher auf NULL gesetzt. 0 führt den normalen Ablauf aus; NULL wird durch die IF-Prüfung wie 0 behandelt und ist kein eigener Validierungsfehler. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Bei HELP wird AVAILABLE zugewiesen. Nach normaler Verarbeitung sind die Gesamtwerte: AVAILABLE ohne markierte Partialität, AVAILABLE_LIMITED bei tatsächlich partieller Evidenz, INVALID_PARAMETER bei ungültigen geprüften Modus-, Mengen-, Sample-, Bit- oder Auswahlparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlenden Regex-Voraussetzungen. Eine abgefangene Auswahl-Ausnahme wird als partielle DATABASE_SELECTION-Quelle erfasst; unabhängige Serverquellen können danach weiterlaufen. Nicht abgefangene Mapping-/Ausgabefehler umgehen den normalen Abschlusssatz. Die Bindung ist optional: zum Empfangen eine varchar(40)-Variable mit OUTPUT übergeben; andernfalls auslassen. HELP überschreibt einen anfänglichen NULL- oder anderen Empfängerwert mit AVAILABLE.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. HELP setzt sie auf 0. Im normalen Abschluss ist 1 gesetzt, wenn eine Quelle oder explizite Datenbankauswahl-Warnung partiell ist oder ein Counter-/Wait-Sample nicht vergleichbar ist; dann wird ein zuvor AVAILABLE-Status zu AVAILABLE_LIMITED. 0 bedeutet nur, dass diese Implementierungsbedingungen keine Partialität markiert haben, nicht dass zwischenzeitliche Resets ausgeschlossen sind. Bei ungültigen geprüften Eingaben wird 1 gesetzt. Bei nicht abgefangenen Ausnahmen wird der normale Abschluss nicht erreicht. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die erste tatsächlich gespeicherte Fehlernummer in der Quellenreihenfolge und innerhalb einer Quelle in Beobachtungsreihenfolge: Konfiguration/Datenbankauswahl, Serverstartzeit oder Counter, Waits, danach Cache. Fehlende Zeilen und Versionsfallbacks ohne ausgelöste SQL-Ausnahme liefern für sich keine Fehlernummer; ein vom Auswahlhelfer zurückgegebener Status kann dennoch eine Fehlermeldung ohne Fehlernummer hinterlassen. Bei keinem gespeicherten Fehler ist der Wert NULL; nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die zur ersten gespeicherten ErrorNumber gehörende SQL-Fehlermeldung in derselben Quellenreihenfolge; wenn weder eine gespeicherte SQL-Ausnahme noch eine Fehlermeldung des Auswahlhelfers vorliegt, ist der Wert NULL. Hinweise zu fehlenden Zeilen, Versionsfallbacks oder sonstigen Quellenlimits stehen in sourceStatus und warnings. Nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [RowCount] bigint NOT NULL , [RequiredPermission] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| configurations | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CompatibilityLevel] tinyint NULL , [ConfigurationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapabilityStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Enabled] bit NULL , [ValueForSecondary] int NULL , [IsValueDefault] bit NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| counters | 1 | 1 | [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CounterType] int NOT NULL , [BeforeValue] bigint NULL , [AfterValue] bigint NOT NULL , [DeltaValue] bigint NULL , [RatePerSecond] decimal(38,6) NULL , [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SampleStartUtc] datetime2(7) NULL , [SampleEndUtc] datetime2(7) NOT NULL , [ElapsedSeconds] decimal(19,6) NULL , [ResetDetected] bit NOT NULL , [SqlServerStartTime] datetime2(3) NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| waits | 1 | 1 | [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [BeforeWaitingTasksCount] bigint NULL , [AfterWaitingTasksCount] bigint NOT NULL , [DeltaWaitingTasksCount] bigint NULL , [BeforeWaitTimeMs] bigint NULL , [AfterWaitTimeMs] bigint NOT NULL , [DeltaWaitTimeMs] bigint NULL , [BeforeSignalWaitTimeMs] bigint NULL , [AfterSignalWaitTimeMs] bigint NOT NULL , [DeltaSignalWaitTimeMs] bigint NULL , [SampleStartUtc] datetime2(7) NULL , [SampleEndUtc] datetime2(7) NOT NULL , [ElapsedSeconds] decimal(19,6) NULL , [ResetDetected] bit NOT NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| cache | 1 | 1 | [CacheType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EntriesCount] bigint NULL , [PagesKb] bigint NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [RowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| warnings | 1 | 1 | [WarningCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Queryzuordnung, Ursachenbehauptung, SQL- oder Planinhalte. Zwei Aufnahmen erkennen nicht jeden zwischenzeitlichen Reset.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CompileContextAnalysis
Version      : 1.0.0
Stand        : 2026-10-13
Zweck        : Die Procedure trennt lokale OPTIMIZED_SP_EXECUTESQL-Konfiguration von
               serverweiten Compile-Countern, Compile-Waits und Cachemetadaten.
Quellen      : Sichtbare Datenbankkataloge; Performance-Counter, Waitstatistik,
               Serverstartzeit und zwei Memory-Cache-Klassen.
Eigenlast    : Kleine Katalogabfragen; Sampling ist standardmäßig aus und
               verwendet optional genau ein WAITFOR von einer bis 60 Sekunden.
Grenzen      : Keine Queryzuordnung, Ursachenbehauptung, SQL- oder Planinhalte.
               Zwei Aufnahmen erkennen nicht jeden zwischenzeitlichen Reset.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CompileContextAnalysis
Die Procedure erfasst sichtbare OPTIMIZED_SP_EXECUTESQL-Konfigurationen je ausgewählter Datenbank und getrennte serverweite Compile-Counter, den Compile-Wait und zwei aggregierte Cacheklassen.
Die optionale Probe verwendet zwei Aufnahmen und ein gemeinsames WAITFOR; die Datenbankauswahl ordnet serverweite Werte keiner Datenbank zu.
Die Ausgabe enthält Rohwerte, Quellenstatus und Evidenzgrenzen. Sie ordnet keine Query oder Compile-Ursache zu und ändert keine Serverkonfiguration.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#CompileContextAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"configurations":"#CompileContextAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#CompileContextAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
    THROW;
END CATCH;
```

