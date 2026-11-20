---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryHashAnalysis"
schema_name: "monitor"
object_name: "USP_QueryHashAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Aggregiert gecachte Statement-Statistiken je query_hash und zeigt Planvielfalt, Recompiles und kumulative Ressourcenanteile."
source_path: "Code/04_PlanCache/020_USP_QueryHashAnalysis.sql"
---

# monitor.USP_QueryHashAnalysis

## Zweck und Einsatz

Aggregiert gecachte Statement-Statistiken je query_hash und zeigt Planvielfalt, Recompiles und kumulative Ressourcenanteile.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_exec_query_stats, sys.dm_exec_sql_text.

VIEW SERVER STATE beziehungsweise SQL Server 2022+ VIEW SERVER PERFORMANCE STATE. Keine Rechtevergabe.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryHash | binary(8) | nein | NULL |
| @Sortierung | varchar(32) | nein | 'CPU_TOTAL' |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MinExecutionCount | bigint | nein | 1 |
| @MinPlanVarianten | int | nein | 1 |
| @MaxZeilen | int | nein | 100 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @ParentQueryStatsSnapshot | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryHash:** @QueryHash binary(8). Default ist NULL. Optionaler Filter auf genau diesen 8-Byte-query_hash. NULL aggregiert alle Hashes und aktiviert PLAN_CACHE_DEEP; für einen einzelnen Hash wird dieser breite Pfad vermieden. Ein angegebener Hash kann im aktuellen Cache fehlen.

**@Sortierung:** @Sortierung varchar(32). Default ist 'CPU_TOTAL'. CPU_TOTAL ordnet nach kumulierter CPU, ELAPSED_TOTAL nach kumulierter Laufzeit, READS_TOTAL nach logischen Reads, WRITES_TOTAL nach logischen Writes, EXECUTIONS nach Ausführungszahl, PLAN_VARIANTS nach Anzahl verschiedener Plan-Hashes und SPILLS_TOTAL nach kumulierten Spills. Auswahl absteigend und bei Gleichstand nach letzter Ausführung absteigend. NULL entspricht CPU_TOTAL. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER.

**@AnalyseModus:** @AnalyseModus varchar(16). Default ist 'TOP'. TOP prüft bei angegebenem Query Hash und positivem Limit bis 1000 keinen tiefen Pfad. VOLL prüft PLAN_CACHE_DEEP. Das Zeilenlimit gilt in beiden Modi. NULL entspricht TOP. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER.

**@MinExecutionCount:** @MinExecutionCount bigint. Default ist 1. Ganzzahliges Minimum der Summe der Ausführungen je Hash. 0 lässt auch Gruppen mit Summe 0 zu. Bei NULL trifft der Vergleich auf keine Gruppe. Negative Werte ergeben INVALID_PARAMETER.

**@MinPlanVarianten:** @MinPlanVarianten int. Default ist 1. Mindestens 1 verschiedener query_plan_hash je Query Hash. Bei NULL trifft der Vergleich auf keine Gruppe. Werte unter 1 ergeben INVALID_PARAMETER.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Maximale Zahl der Hash-Gruppen. Positiv begrenzt; NULL oder 0 bedeutet unbegrenzt und aktiviert damit PLAN_CACHE_DEEP. Negative Werte sind ungültig; mehr als 1000 Zeilen aktiviert ebenfalls den geschützten Pfad.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 4000. Maximale Unicode-Zeichenlänge des Beispielstatements. Positiv kürzt und kennzeichnet den Text; NULL oder 0 lässt ihn vollständig. Negative Werte sind ungültig.

**@ParentQueryStatsSnapshot:** @ParentQueryStatsSnapshot bit. Default ist 0. 0 liest die DMV frisch. 1 liest ausschließlich den lokalen Snapshot des laufenden Aufrufs von USP_PlanCacheAnalysis. Fehlt er, meldet die Analyse ERROR_HANDLED. NULL ergibt INVALID_PARAMETER.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. Muss für einen aktivierten PLAN_CACHE_DEEP-Pfad 1 sein und bestätigt den Hochaufwandspfad; zusätzlich gelten dessen aktuelle Freigabe und Berechtigungen. 0 oder NULL lässt den geschützten Pfad nicht zu. Bei einem einzelnen Hash im TOP-Modus mit höchstens 1000 Zeilen wird dieser Gate nicht aktiviert.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt die beschrifteten Hashgruppen. RAW liefert Modulstatus und Hashgruppen. TABLE schreibt das benannte Resultset queryHashes. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel queryHashes und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 oder NULL deaktiviert JSON.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit meta, queryHashes und warnings.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort.

## Resultate und Ausgabe

1. Modulstatus. 2. Query-Hash-Aggregate mit Beispielstatement.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| queryHashes | 1 | 1 | [QueryHash] binary(8) NOT NULL , [PlanVariantCount] int NOT NULL , [PlanHandleCount] int NOT NULL , [CompilationCount] bigint NOT NULL , [ExecutionCount] bigint NOT NULL , [TotalCpuMs] decimal(38,3) NULL , [AvgCpuMs] decimal(38,3) NULL , [TotalElapsedMs] decimal(38,3) NULL , [AvgElapsedMs] decimal(38,3) NULL , [TotalReads] bigint NOT NULL , [AvgReads] decimal(38,3) NULL , [TotalWrites] bigint NOT NULL , [TotalSpills] bigint NOT NULL , [MaxGrantKb] bigint NOT NULL , [FirstCreationTime] datetime NULL , [LastExecutionTime] datetime NULL , [SampleStatementTextCharacters] bigint NULL , [SampleStatementTextBytes] bigint NULL , [SampleStatementTextIsTruncated] bit NOT NULL DEFAULT(0) , [SampleStatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_QueryHashAnalysis @MinPlanVarianten=2; EXEC monitor.USP_QueryHashAnalysis @Sortierung='READS_TOTAL'; EXEC monitor.USP_QueryHashAnalysis @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryHashAnalysis

Die Procedure gruppiert aktuell sichtbare Cacheeinträge nach Query Hash und zeigt Verbrauch und Planvarianten.

Hilfe anzeigen. EXEC [monitor].[USP_QueryHashAnalysis] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryHashAnalysis
Version      : 2.1.0
Stand        : 2026-07-19
Typ          : Stored Procedure
Zweck        : Aggregiert gecachte Statement-Statistiken je query_hash und zeigt
               Planvielfalt, Recompiles und kumulative Ressourcenanteile.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_query_stats, sys.dm_exec_sql_text.
Parameter    : @QueryHash, @Sortierung, @AnalyseModus, @MinExecutionCount,
               @MinPlanVarianten, @MaxZeilen, @MaxSqlTextZeichen,
               @ParentQueryStatsSnapshot,
               @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Query-Hash-Aggregate mit Beispielstatement.
Berechtigung : VIEW SERVER STATE beziehungsweise SQL Server 2022+
               VIEW SERVER PERFORMANCE STATE. Keine Rechtevergabe.
Eigenlast    : Gruppiert sys.dm_exec_query_stats. Ohne konkreten @QueryHash sowie
               im Modus VOLL wird PLAN_CACHE_DEEP geprüft. Text wird nur für
               gewählte Hashes geladen.
Locking      : Keine Benutzerobjekte.
Partial      : Cache-Eviction kann Beispieltexte zwischen Auswahl und Ausgabe entfernen.
Beispiele    : EXEC monitor.USP_QueryHashAnalysis @MinPlanVarianten=2;
               EXEC monitor.USP_QueryHashAnalysis @Sortierung='READS_TOTAL';
               EXEC monitor.USP_QueryHashAnalysis @Hilfe=1;
Änderungen   : 2.1.0 - Query-Stats je Aufruf einmal gelesen oder vom laufgebundenen
                         Parent-Snapshot übernommen.
               1.1.0 - Breite Aggregation ohne @QueryHash gruppengeschützt.
               1.0.0 - Erstfassung Phase 3.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryHashAnalysis
Die Procedure gruppiert aktuell sichtbare Cacheeinträge nach Query Hash und zeigt Verbrauch und Planvarianten.
Hilfe anzeigen. EXEC [monitor].[USP_QueryHashAnalysis] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Benanntes Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #QueryHashAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_QueryHashAnalysis] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"queryHashes":"#QueryHashAnalysis_HelpExample"}'; SELECT * FROM #QueryHashAnalysis_HelpExample; DROP TABLE #QueryHashAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #QueryHashAnalysis_HelpExample; THROW; END CATCH;
```

