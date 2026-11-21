---
skill_format_version: "1.0.0"
name: "monitor.USP_PlanDetails"
schema_name: "monitor"
object_name: "USP_PlanDetails"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan."
source_path: "Code/04_PlanCache/040_USP_PlanDetails.sql"
---

# monitor.USP_PlanDetails

## Zweck und Einsatz

Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_exec_requests, sys.dm_exec_query_stats, sys.dm_exec_sql_text, sys.dm_exec_plan_attributes, sys.dm_exec_query_plan, sys.dm_exec_text_query_plan, sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.

VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @PlanHandle | varbinary(64) | nein | NULL |
| @SqlHandle | varbinary(64) | nein | NULL |
| @QueryHash | binary(8) | nein | NULL |
| @MitPlanAttributes | bit | nein | 1 |
| @MitCompilePlan | bit | nein | 1 |
| @MitTextPlan | bit | nein | 0 |
| @MitLastActualPlan | bit | nein | 0 |
| @MitLivePlan | bit | nein | 0 |
| @MaxAnalyseobjekte | int | nein | 20 |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxSqlTextZeichen | int | nein | 8000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SessionIds:** @SessionIds nvarchar(max). Default ist NULL. Liste ganzer Session-IDs von 1 bis 32767, z. B. 57|61. Pipe, Beistrich und Strichpunkt sind Trennzeichen. NULL lässt diesen Selektor aus. Leere, nur aus Leerzeichen bestehende oder ungültige Elemente ergeben INVALID_PARAMETER. Doppelte IDs werden zusammengefasst. Live-XML erfordert genau eine eindeutige Session-ID.

**@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. NULL lässt diesen Selektor aus. Nicht-null wird als Kandidat aufgenommen, auch wenn der Handle inzwischen nicht mehr im Cache auflösbar ist.

**@SqlHandle:** @SqlHandle varbinary(64). Default ist NULL. Exakter SQL-Handle. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Zeilen dieses Handles. Bis zum Kandidatenlimit, nach total_worker_time absteigend.

**@QueryHash:** @QueryHash binary(8). Default ist NULL. Exakter 8-Byte Queryhash. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Kandidaten dieses Hashes. Bis zum Kandidatenlimit, nach total_worker_time absteigend.

**@MitPlanAttributes:** @MitPlanAttributes bit. Default ist 1. 0 unterdrückt Planattribute. 1 liest sie für jeden behaltenen Kandidaten. NULL wird von der Implementierung nicht als eigener Modus unterstützt (SQL-IF-Zweig wird nicht aktiviert).

**@MitCompilePlan:** @MitCompilePlan bit. Default ist 1. 0 unterdrückt kompiliertes Showplan-XML. 1 fordert sys.dm_exec_query_plan an. NULL aktiviert den Zweig nicht. Fehlender Plan wird als nicht verfügbar je Candidate ausgegeben.

**@MitTextPlan:** @MitTextPlan bit. Default ist 0. 0 unterdrückt Text-Showplan. 1 fordert ihn an. NULL aktiviert den Zweig nicht.

**@MitLastActualPlan:** @MitLastActualPlan bit. Default ist 0. 0 unterdrückt Last-known-Actual-Plan. 1 liest vorhandene LAST_QUERY_PLAN_STATS-Evidenz. Die Procedure aktiviert die Datenbankoption nicht. NULL aktiviert den Zweig nicht. Fehlendes XML kann deaktiviert, ungeeignet, nicht cachebar oder evicted bedeuten.

**@MitLivePlan:** @MitLivePlan bit. Default ist 0. 0 unterdrückt Live-Abfrage. 1 erfordert genau eine eindeutige Session-ID in SessionIds. Sonst wird ein INVALID_PARAMETER-Planstatus ausgegeben. Liest laufenden Request, aktiviert kein Profiling. NULL aktiviert den Zweig nicht.

**@MaxAnalyseobjekte:** @MaxAnalyseobjekte int. Default ist 20. Positive Zahl begrenzt die zusammengeführten Kandidaten. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Oberhalb 20 einschließlich unbegrenzt wird PLAN_CACHE_DEEP geprüft und je Policy kann HighImpactConfirmed erforderlich sein. Limit ist keine Ergebniszeilengrenze.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung, 1 bestätigt das Deep-Analyse-Gate gemäß zentraler Policy. Der Parameter übergeht das Gate nicht selbständig. NULL ist kein eigener bestätigender Wert.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 8000. Positive Zahl kürzt Statement- und Batchtext auf diese Zeichenanzahl. 0 oder NULL erhält beide vollständig. Negativ ist INVALID_PARAMETER.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Nach Trim und Großschreibung: CONSOLE gibt lesbare benannte Resultsets. RAW gibt kanonische rohe Resultsets. NONE unterdrückt direkte Resultsets. TABLE schreibt in registrierte Zieltabellen. Geschlossene Menge: CONSOLE, RAW, NONE, TABLE. NULL/Leerwert normalisiert zu leer und ist ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel candidates, attributes und plans. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. Ein ungültiges Mapping kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 0 erzeugt kein JSON. 1 erzeugt JSON im OUTPUT-Parameter. NULL kein aktiver Schalterwert/keine JSON-Erzeugung.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie ein Objekt mit meta, candidates, attributes, plans und warnings.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert oder validiert den Wert nicht. 1 ermöglicht die eigene Statusmeldung nur am erreichten Ende bei einem nicht-NULL Status ungleich AVAILABLE; außerdem ermöglicht 1 die Truncation-Warnung nur bei positiver Zahl gekürzter Werte. Beide Meldungen sind RAISERROR Severity 10 WITH NOWAIT und keine SQL-Ausnahme. 0 und NULL unterdrücken diese optionalen Meldungen. Die Hilfeausgabe sowie Vorbereitungs- und SQL-Fehler sind unabhängig; vollständige Stille ist nicht garantiert.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der Prüfung von @ResultTablesJson und beendet den Aufruf vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.

## Resultate und Ausgabe

1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute. 4. angeforderte Pläne mit SourceType und Status.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| candidates | 1 | 1 | [CandidateId] int,[SessionId] smallint NULL,[RequestId] int NULL,[PlanHandle] varbinary(64) NULL,[SqlHandle] varbinary(64) NULL , [QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[StatementStartOffset] int NULL,[StatementEndOffset] int NULL , [CreationTime] datetime NULL,[LastExecutionTime] datetime NULL,[ExecutionCount] bigint NULL , [StatementTextCharacters] bigint NULL,[StatementTextBytes] bigint NULL,[StatementTextIsTruncated] bit NOT NULL DEFAULT(0),[StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchTextCharacters] bigint NULL,[BatchTextBytes] bigint NULL,[BatchTextIsTruncated] bit NOT NULL DEFAULT(0),[BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SqlTextDatabaseId] int NULL,[SqlTextDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SqlTextObjectId] int NULL |
| attributes | 1 | 1 | [CandidateId] int,[AttributeName] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[AttributeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsCacheKey] bit |
| plans | 1 | 1 | [CandidateId] int,[SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ObjectId] int NULL,[IsEncrypted] bit NULL,[QueryPlanXml] xml NULL,[QueryPlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

Der folgende begrenzte Aufruf untersucht die eigene aktuelle Sitzung. Er kann ohne einen erfassten Plan leere Fachmengen liefern; Rechte und Planverfügbarkeit sind separat zu prüfen.

```sql
DECLARE @SessionIds nvarchar(max)=CONVERT(nvarchar(20),@@SPID);
EXEC [monitor].[USP_PlanDetails] @SessionIds=@SessionIds, @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PlanDetails

Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.

Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PlanDetails
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan,
               Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_requests, sys.dm_exec_query_stats,
               sys.dm_exec_sql_text, sys.dm_exec_plan_attributes,
               sys.dm_exec_query_plan, sys.dm_exec_text_query_plan,
               sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.
Parameter    : @SessionIds, @PlanHandle, @SqlHandle, @QueryHash,
               @MitPlanAttributes, @MitCompilePlan, @MitTextPlan,
               @MitLastActualPlan, @MitLivePlan, @MaxAnalyseobjekte,
               @MaxSqlTextZeichen, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute.
               4. angeforderte Pläne mit SourceType und Status.
Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.
Eigenlast    : Zielgerichtet und auf @MaxAnalyseobjekte begrenzt. Mehr als 20 Pläne
               prüft PLAN_CACHE_DEEP. Das Framework aktiviert keine Profilingoption.
Locking      : Keine Benutzerobjekte.
Partial      : Jede Planquelle wird je Kandidat isoliert; fehlende oder evictete
               Pläne lassen andere Quellen und Kandidaten bestehen.
Beispiele    : EXEC monitor.USP_PlanDetails @SessionIds=N57,@MitLivePlan=1;
               EXEC monitor.USP_PlanDetails @PlanHandle=0x...;
               EXEC monitor.USP_PlanDetails @QueryHash=0x...,@MitLastActualPlan=1;
               EXEC monitor.USP_PlanDetails @Hilfe=1;
Änderungen   : 1.1.0 - Deep-Gate ab mehr als 20 Plänen.
               1.0.0 - Erstfassung Phase 3.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PlanDetails
Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.
Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanDetails_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @ResultSetArt='TABLE', @ResultTablesJson=N'{"plans":"#PlanDetails_HelpExample"}'; SELECT * FROM #PlanDetails_HelpExample; DROP TABLE #PlanDetails_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanDetails_HelpExample; THROW; END CATCH;
```

