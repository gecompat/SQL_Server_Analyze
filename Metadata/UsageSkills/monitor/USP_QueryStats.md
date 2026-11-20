---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStats"
schema_name: "monitor"
object_name: "USP_QueryStats"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert kumulative Statement-Statistiken des aktuellen Plan Cache."
source_path: "Code/04_PlanCache/010_USP_QueryStats.sql"
---

# monitor.USP_QueryStats

## Zweck und Einsatz

Liefert kumulative Statement-Statistiken des aktuellen Plan Cache. Datenbanknamen unterstützen bracket-aware Pipe-Listen und LIKE-/Regex-Patterns. RAW, CONSOLE und JSON verwenden dieselbe intern materialisierte Datenbasis.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_QueryStats] im vorgesehenen Datenbankkontext. Die Procedure liest Plan-Cache-DMVs einschließlich `sys.dm_exec_cached_plans`, SQL-Text und Planattributen. Die dafür nötige serverweite Sicht ist versions- und rechteabhängig; ein erfolgreiches EXECUTE beweist keinen vollständigen Cache.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @QueryHash | binary(8) | nein | NULL |
| @QueryPlanHash | binary(8) | nein | NULL |
| @SqlHandle | varbinary(64) | nein | NULL |
| @PlanHandle | varbinary(64) | nein | NULL |
| @TextPattern | nvarchar(4000) | nein | NULL |
| @Sortierung | varchar(32) | nein | 'CPU_TOTAL' |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MinExecutionCount | bigint | nein | 1 |
| @VonUtc | datetime2(7) | nein | NULL |
| @MaxZeilen | int | nein | 100 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ParentQueryStatsSnapshot | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter Datenbanknamen; NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. | trennt außerhalb von [...]; ]] maskiert ] innerhalb; äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen; ungültige Liste INVALID_PARAMETER.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL führt zur Parameterablehnung; ausgelassen = 0. SQL-bit-Konvertierung kann numerische Nichtnullwerte als 1 abbilden.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL. Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung; äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern; leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 lässt den hohen Aufwand unbestätigt. 1 bestätigt einen geschützten Pfad. Die Berechtigung wird zusätzlich geprüft. NULL ist für die Pfadprüfung ungültig.

**@QueryHash:** @QueryHash binary(8). Default ist NULL. Optionaler exakter 8-Byte Query Hash; NULL = kein Hashfilter. Andere Längen/Typkonvertierungen richten sich nach T-SQL-Bindung; keine zusätzliche Hexstring-Validierung im Procedurecode.

**@QueryPlanHash:** @QueryPlanHash binary(8). Default ist NULL. Optionaler exakter 8-Byte Planhash; NULL = kein Planhashfilter.

**@SqlHandle:** @SqlHandle varbinary(64). Default ist NULL. Optionaler SQL-Handle bis 64 Byte; NULL = kein Handlefilter.

**@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Optionaler Plan-Handle bis 64 Byte; NULL = kein Handlefilter.

**@TextPattern:** @TextPattern nvarchar(4000). Default ist NULL. SQL-Textpattern. NULL = kein Filter; Parser erkennt case-insensitive like:, regex:, regexi:, sonst LIKE. Außenleerzeichen getrimmt, Patternrest nicht. Leerer effektiver Inhalt INVALID_PARAMETER. Nicht als Pipe-Liste zerlegt. LIKE nutzt %/_/SQL LIKE-Syntax; Regex braucht SQL Server 2025 und Installations-DB-Kompatibilität 170, Syntaxfehler werden von Regex-Ausführung gemeldet.

**@Sortierung:** @Sortierung varchar(32). Default ist 'CPU_TOTAL'. Case-insensitive nach LTRIM/RTRIM; geschlossene Menge: CPU_TOTAL = kumulative CPU; CPU_AVG = CPU je Ausführung; ELAPSED_TOTAL = kumulative Laufzeit; ELAPSED_AVG = Laufzeit je Ausführung; READS_TOTAL = kumulative logische Reads; READS_AVG = logische Reads je Ausführung; WRITES_TOTAL = kumulative logische Writes; WRITES_AVG = logische Writes je Ausführung; EXECUTIONS = Ausführungszahl; GRANT_MAX = maximaler Grant; SPILLS_TOTAL = kumulative Spills; ROWS_TOTAL = kumulative Zeilen; LAST_EXECUTION = letzte Ausführungszeit. NULL normalisiert auf Default. Ungültiger Wert INVALID_PARAMETER.

**@AnalyseModus:** @AnalyseModus varchar(16). Default ist 'TOP'. TOP verwendet bei einem positiven Limit bis 1000 den aktuellen Plan-Cache-Pfad. VOLL prüft PLAN_CACHE_DEEP und behält das Zeilenlimit bei. NULL entspricht TOP. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER.

**@MinExecutionCount:** @MinExecutionCount bigint. Default ist 1. Ganzzahliges Minimum für execution_count. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Zeile.

**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Inklusiver Grenzwert für last_execution_time als datetime2-Wert, z. B. 2026-01-01T00:00:00. Die Procedure vergleicht direkt mit dem Cachewert und rechnet keine Zeitzone um. NULL lässt den Zeitfilter aus.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Positiv begrenzt Ausgabe; NULL oder 0 bedeutet unbegrenzt; negativ INVALID_PARAMETER. Ausgelassen = 100. Unbegrenzt oder >1000 sowie VOLL erfordern PLAN_CACHE_DEEP. Positive Auswahl sammelt bis Limit+1 zur HasMoreRows-Ermittlung.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 4000. Positiv kürzt Statement- und Batchtext auf Zeichenlimit; NULL oder 0 bedeutet ungekürzt; negativ INVALID_PARAMETER. Zeichenprojektion zählt unter SC-Collation, nicht Grapheme.

**@ParentQueryStatsSnapshot:** @ParentQueryStatsSnapshot bit. Default ist 0. 0 = DMV frisch lesen; 1 = ausschließlich laufinterne Wiederverwendung durch USP_PlanCacheAnalysis. NULL INVALID_PARAMETER. Schalter ist kein öffentlicher externer Snapshotvertrag.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt die beschriftete Abfrageauswahl. RAW liefert Modulstatus, Abfragezeilen und Auswahlwarnungen. TABLE schreibt das benannte Resultset queries. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel queries und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 deaktiviert JSON. NULL ergibt INVALID_PARAMETER.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit meta, queries und warnings.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| queries | 1 | 1 | [QueryHash] binary(8) NULL , [QueryPlanHash] binary(8) NULL , [PlanHandle] varbinary(64) NOT NULL , [SqlHandle] varbinary(64) NOT NULL , [StatementStartOffset] int NOT NULL , [StatementEndOffset] int NOT NULL , [PlanGenerationNumber] bigint NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ObjectId] int NULL , [StatementTextCharacters] bigint NULL , [StatementTextBytes] bigint NULL , [StatementTextIsTruncated] bit NOT NULL DEFAULT(0) , [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchTextCharacters] bigint NULL , [BatchTextBytes] bigint NULL , [BatchTextIsTruncated] bit NOT NULL DEFAULT(0) , [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CreationTime] datetime NOT NULL , [LastExecutionTime] datetime NOT NULL , [ExecutionCount] bigint NOT NULL , [TotalCpuMs] decimal(38,3) NULL , [LastCpuMs] decimal(38,3) NULL , [MinCpuMs] decimal(38,3) NULL , [MaxCpuMs] decimal(38,3) NULL , [AvgCpuMs] decimal(38,3) NULL , [TotalElapsedMs] decimal(38,3) NULL , [LastElapsedMs] decimal(38,3) NULL , [MinElapsedMs] decimal(38,3) NULL , [MaxElapsedMs] decimal(38,3) NULL , [AvgElapsedMs] decimal(38,3) NULL , [TotalLogicalReads] bigint NOT NULL , [LastLogicalReads] bigint NOT NULL , [AvgLogicalReads] decimal(38,3) NULL , [TotalLogicalWrites] bigint NOT NULL , [LastLogicalWrites] bigint NOT NULL , [AvgLogicalWrites] decimal(38,3) NULL , [TotalPhysicalReads] bigint NOT NULL , [LastPhysicalReads] bigint NOT NULL , [TotalRows] bigint NOT NULL , [LastRows] bigint NOT NULL , [MinRows] bigint NOT NULL , [MaxRows] bigint NOT NULL , [LastDop] bigint NOT NULL , [MinDop] bigint NOT NULL , [MaxDop] bigint NOT NULL , [MaxGrantKb] bigint NOT NULL , [LastGrantKb] bigint NOT NULL , [LastUsedGrantKb] bigint NOT NULL , [LastIdealGrantKb] bigint NOT NULL , [TotalSpilledPages] bigint NOT NULL , [LastSpilledPages] bigint NOT NULL , [CacheObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PlanUseCounts] int NULL , [PlanSizeBytes] bigint NULL , [ResourcePoolId] int NULL , [SetOptions] int NULL , [CompileUserId] int NULL , [SortValue] decimal(38,4) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStats] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStats

Die Procedure rangiert aktuell gecachte Statements nach Verbrauch, Ausführungszahl und letzter Ausführung. Der Cache erfasst nur die derzeit sichtbaren Einträge.

Hilfe anzeigen. EXEC [monitor].[USP_QueryStats] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStats
Version      : 2.1.0
Stand        : 2026-07-19
Zweck        : Liefert kumulative Statement-Statistiken des aktuellen Plan
               Cache. Datenbanknamen unterstützen bracket-aware Pipe-Listen
               und LIKE-/Regex-Patterns. RAW, CONSOLE und JSON verwenden
               dieselbe intern materialisierte Datenbasis.
SQL-Version  : SQL Server 2019 oder neuer; Regex nur ab SQL Server 2025 und
               Compatibility Level 170.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStats
Die Procedure rangiert aktuell gecachte Statements nach Verbrauch, Ausführungszahl und letzter Ausführung. Der Cache erfasst nur die derzeit sichtbaren Einträge.
Hilfe anzeigen. EXEC [monitor].[USP_QueryStats] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Benanntes Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #QueryStats_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"queries":"#QueryStats_HelpExample"}'; SELECT * FROM #QueryStats_HelpExample; DROP TABLE #QueryStats_HelpExample; END TRY BEGIN CATCH DROP TABLE #QueryStats_HelpExample; THROW; END CATCH;
```

