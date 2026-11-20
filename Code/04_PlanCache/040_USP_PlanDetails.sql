USE [DeineDatenbank];
GO

/*
===============================================================================
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
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_PlanDetails 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_PlanDetails"
-- schema_name: "monitor"
-- object_name: "USP_PlanDetails"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan."
-- source_path: "Code/04_PlanCache/040_USP_PlanDetails.sql"
-- ---
-- 
-- # monitor.USP_PlanDetails
-- 
-- ## Zweck und Einsatz
-- 
-- Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- SQL Server 2019 oder neuer.
-- 
-- sys.dm_exec_requests, sys.dm_exec_query_stats, sys.dm_exec_sql_text, sys.dm_exec_plan_attributes, sys.dm_exec_query_plan, sys.dm_exec_text_query_plan, sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.
-- 
-- VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SessionIds | nvarchar(max) | nein | NULL |
-- | @PlanHandle | varbinary(64) | nein | NULL |
-- | @SqlHandle | varbinary(64) | nein | NULL |
-- | @QueryHash | binary(8) | nein | NULL |
-- | @MitPlanAttributes | bit | nein | 1 |
-- | @MitCompilePlan | bit | nein | 1 |
-- | @MitTextPlan | bit | nein | 0 |
-- | @MitLastActualPlan | bit | nein | 0 |
-- | @MitLivePlan | bit | nein | 0 |
-- | @MaxAnalyseobjekte | int | nein | 20 |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @MaxSqlTextZeichen | int | nein | 8000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SessionIds:** @SessionIds nvarchar(max). Default ist NULL. Liste ganzer Session-IDs von 1 bis 32767, z. B. 57|61. Pipe, Beistrich und Strichpunkt sind Trennzeichen. NULL lässt diesen Selektor aus. Leere, nur aus Leerzeichen bestehende oder ungültige Elemente ergeben INVALID_PARAMETER. Doppelte IDs werden zusammengefasst. Live-XML erfordert genau eine eindeutige Session-ID.
-- 
-- **@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. NULL lässt diesen Selektor aus. Nicht-null wird als Kandidat aufgenommen, auch wenn der Handle inzwischen nicht mehr im Cache auflösbar ist.
-- 
-- **@SqlHandle:** @SqlHandle varbinary(64). Default ist NULL. Exakter SQL-Handle. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Zeilen dieses Handles. Bis zum Kandidatenlimit, nach total_worker_time absteigend.
-- 
-- **@QueryHash:** @QueryHash binary(8). Default ist NULL. Exakter 8-Byte Queryhash. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Kandidaten dieses Hashes. Bis zum Kandidatenlimit, nach total_worker_time absteigend.
-- 
-- **@MitPlanAttributes:** @MitPlanAttributes bit. Default ist 1. 0 unterdrückt Planattribute. 1 liest sie für jeden behaltenen Kandidaten. NULL wird von der Implementierung nicht als eigener Modus unterstützt (SQL-IF-Zweig wird nicht aktiviert).
-- 
-- **@MitCompilePlan:** @MitCompilePlan bit. Default ist 1. 0 unterdrückt kompiliertes Showplan-XML. 1 fordert sys.dm_exec_query_plan an. NULL aktiviert den Zweig nicht. Fehlender Plan wird als nicht verfügbar je Candidate ausgegeben.
-- 
-- **@MitTextPlan:** @MitTextPlan bit. Default ist 0. 0 unterdrückt Text-Showplan. 1 fordert ihn an. NULL aktiviert den Zweig nicht.
-- 
-- **@MitLastActualPlan:** @MitLastActualPlan bit. Default ist 0. 0 unterdrückt Last-known-Actual-Plan. 1 liest vorhandene LAST_QUERY_PLAN_STATS-Evidenz. Die Procedure aktiviert die Datenbankoption nicht. NULL aktiviert den Zweig nicht. Fehlendes XML kann deaktiviert, ungeeignet, nicht cachebar oder evicted bedeuten.
-- 
-- **@MitLivePlan:** @MitLivePlan bit. Default ist 0. 0 unterdrückt Live-Abfrage. 1 erfordert genau eine eindeutige Session-ID in SessionIds. Sonst wird ein INVALID_PARAMETER-Planstatus ausgegeben. Liest laufenden Request, aktiviert kein Profiling. NULL aktiviert den Zweig nicht.
-- 
-- **@MaxAnalyseobjekte:** @MaxAnalyseobjekte int. Default ist 20. Positive Zahl begrenzt die zusammengeführten Kandidaten. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Oberhalb 20 einschließlich unbegrenzt wird PLAN_CACHE_DEEP geprüft und je Policy kann HighImpactConfirmed erforderlich sein. Limit ist keine Ergebniszeilengrenze.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung, 1 bestätigt das Deep-Analyse-Gate gemäß zentraler Policy. Der Parameter übergeht das Gate nicht selbständig. NULL ist kein eigener bestätigender Wert.
-- 
-- **@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 8000. Positive Zahl kürzt Statement- und Batchtext auf diese Zeichenanzahl. 0 oder NULL erhält beide vollständig. Negativ ist INVALID_PARAMETER.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Nach Trim und Großschreibung: CONSOLE gibt lesbare benannte Resultsets. RAW gibt kanonische rohe Resultsets. NONE unterdrückt direkte Resultsets. TABLE schreibt in registrierte Zieltabellen. Geschlossene Menge: CONSOLE, RAW, NONE, TABLE. NULL/Leerwert normalisiert zu leer und ist ungültig.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel candidates, attributes und plans. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. Ein ungültiges Mapping kann Fehler 51011 auslösen.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 0 erzeugt kein JSON. 1 erzeugt JSON im OUTPUT-Parameter. NULL kein aktiver Schalterwert/keine JSON-Erzeugung.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie ein Objekt mit meta, candidates, attributes, plans und warnings.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert oder validiert den Wert nicht. 1 ermöglicht die eigene Statusmeldung nur am erreichten Ende bei einem nicht-NULL Status ungleich AVAILABLE; außerdem ermöglicht 1 die Truncation-Warnung nur bei positiver Zahl gekürzter Werte. Beide Meldungen sind RAISERROR Severity 10 WITH NOWAIT und keine SQL-Ausnahme. 0 und NULL unterdrücken diese optionalen Meldungen. Die Hilfeausgabe sowie Vorbereitungs- und SQL-Fehler sind unabhängig; vollständige Stille ist nicht garantiert.
-- 
-- **@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der Prüfung von @ResultTablesJson und beendet den Aufruf vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.
-- 
-- ## Resultate und Ausgabe
-- 
-- 1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute. 4. angeforderte Pläne mit SourceType und Status.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | candidates | 1 | 1 | [CandidateId] int,[SessionId] smallint NULL,[RequestId] int NULL,[PlanHandle] varbinary(64) NULL,[SqlHandle] varbinary(64) NULL , [QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[StatementStartOffset] int NULL,[StatementEndOffset] int NULL , [CreationTime] datetime NULL,[LastExecutionTime] datetime NULL,[ExecutionCount] bigint NULL , [StatementTextCharacters] bigint NULL,[StatementTextBytes] bigint NULL,[StatementTextIsTruncated] bit NOT NULL DEFAULT(0),[StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchTextCharacters] bigint NULL,[BatchTextBytes] bigint NULL,[BatchTextIsTruncated] bit NOT NULL DEFAULT(0),[BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SqlTextDatabaseId] int NULL,[SqlTextDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SqlTextObjectId] int NULL |
-- | attributes | 1 | 1 | [CandidateId] int,[AttributeName] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[AttributeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsCacheKey] bit |
-- | plans | 1 | 1 | [CandidateId] int,[SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ObjectId] int NULL,[IsEncrypted] bit NULL,[QueryPlanXml] xml NULL,[QueryPlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- Der folgende begrenzte Aufruf untersucht die eigene aktuelle Sitzung. Er kann ohne einen erfassten Plan leere Fachmengen liefern; Rechte und Planverfügbarkeit sind separat zu prüfen.
-- 
-- ```sql
-- DECLARE @SessionIds nvarchar(max)=CONVERT(nvarchar(20),@@SPID);
-- EXEC [monitor].[USP_PlanDetails] @SessionIds=@SessionIds, @ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_PlanDetails
-- 
-- Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.
-- 
-- Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;
-- 
-- Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt='RAW';
-- 
-- Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_PlanDetails
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Typ          : Stored Procedure
-- Zweck        : Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan,
--                Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Datenquellen : sys.dm_exec_requests, sys.dm_exec_query_stats,
--                sys.dm_exec_sql_text, sys.dm_exec_plan_attributes,
--                sys.dm_exec_query_plan, sys.dm_exec_text_query_plan,
--                sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.
-- Parameter    : @SessionIds, @PlanHandle, @SqlHandle, @QueryHash,
--                @MitPlanAttributes, @MitCompilePlan, @MitTextPlan,
--                @MitLastActualPlan, @MitLivePlan, @MaxAnalyseobjekte,
--                @MaxSqlTextZeichen, @PrintMeldungen, @Hilfe.
-- Resultsets   : 1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute.
--                4. angeforderte Pläne mit SourceType und Status.
-- Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.
-- Eigenlast    : Zielgerichtet und auf @MaxAnalyseobjekte begrenzt. Mehr als 20 Pläne
--                prüft PLAN_CACHE_DEEP. Das Framework aktiviert keine Profilingoption.
-- Locking      : Keine Benutzerobjekte.
-- Partial      : Jede Planquelle wird je Kandidat isoliert; fehlende oder evictete
--                Pläne lassen andere Quellen und Kandidaten bestehen.
-- Beispiele    : EXEC monitor.USP_PlanDetails @SessionIds=N57,@MitLivePlan=1;
--                EXEC monitor.USP_PlanDetails @PlanHandle=0x...;
--                EXEC monitor.USP_PlanDetails @QueryHash=0x...,@MitLastActualPlan=1;
--                EXEC monitor.USP_PlanDetails @Hilfe=1;
-- Änderungen   : 1.1.0 - Deep-Gate ab mehr als 20 Plänen.
--                1.0.0 - Erstfassung Phase 3.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_PlanDetails
-- Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.
-- Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;
-- Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt='RAW';
-- Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanDetails_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @ResultSetArt='TABLE', @ResultTablesJson=N'{"plans":"#PlanDetails_HelpExample"}'; SELECT * FROM #PlanDetails_HelpExample; DROP TABLE #PlanDetails_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanDetails_HelpExample; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_PlanDetails
CREATE OR ALTER PROCEDURE [monitor].[USP_PlanDetails]
      @SessionIds            nvarchar(max)  = NULL
    , @PlanHandle            varbinary(64)  = NULL
    , @SqlHandle             varbinary(64)  = NULL
    , @QueryHash             binary(8)      = NULL
    , @MitPlanAttributes     bit            = 1
    , @MitCompilePlan        bit            = 1
    , @MitTextPlan           bit            = 0
    , @MitLastActualPlan     bit            = 0
    , @MitLivePlan           bit            = 0
    , @MaxAnalyseobjekte      int            = 20
    , @HighImpactConfirmed   bit            = 0
    , @MaxSqlTextZeichen     int            = 8000
    , @ResultSetArt          varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen          bit            = 0
    , @Json                   nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen        bit            = 1
    , @Hilfe                 bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe=1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_PlanDetails';
        PRINT N'Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.';
        PRINT N'@SessionIds nvarchar(max). Default ist NULL. Liste ganzer Session-IDs von 1 bis 32767, z. B. 57|61. Pipe, Beistrich und Strichpunkt sind Trennzeichen. NULL lässt diesen Selektor aus. Leere, nur aus Leerzeichen bestehende oder ungültige Elemente ergeben INVALID_PARAMETER. Doppelte IDs werden zusammengefasst. Live-XML erfordert genau eine eindeutige Session-ID.';
        PRINT N'@PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. NULL lässt diesen Selektor aus. Nicht-null wird als Kandidat aufgenommen, auch wenn der Handle inzwischen nicht mehr im Cache auflösbar ist.';
        PRINT N'@SqlHandle varbinary(64). Default ist NULL. Exakter SQL-Handle. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Zeilen dieses Handles. Bis zum Kandidatenlimit, nach total_worker_time absteigend.';
        PRINT N'@QueryHash binary(8). Default ist NULL. Exakter 8-Byte Queryhash. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Kandidaten dieses Hashes. Bis zum Kandidatenlimit, nach total_worker_time absteigend.';
        PRINT N'@MitPlanAttributes bit. Default ist 1. 0 unterdrückt Planattribute. 1 liest sie für jeden behaltenen Kandidaten. NULL wird von der Implementierung nicht als eigener Modus unterstützt (SQL-IF-Zweig wird nicht aktiviert).';
        PRINT N'@MitCompilePlan bit. Default ist 1. 0 unterdrückt kompiliertes Showplan-XML. 1 fordert sys.dm_exec_query_plan an. NULL aktiviert den Zweig nicht. Fehlender Plan wird als nicht verfügbar je Candidate ausgegeben.';
        PRINT N'@MitTextPlan bit. Default ist 0. 0 unterdrückt Text-Showplan. 1 fordert ihn an. NULL aktiviert den Zweig nicht.';
        PRINT N'@MitLastActualPlan bit. Default ist 0. 0 unterdrückt Last-known-Actual-Plan. 1 liest vorhandene LAST_QUERY_PLAN_STATS-Evidenz. Die Procedure aktiviert die Datenbankoption nicht. NULL aktiviert den Zweig nicht. Fehlendes XML kann deaktiviert, ungeeignet, nicht cachebar oder evicted bedeuten.';
        PRINT N'@MitLivePlan bit. Default ist 0. 0 unterdrückt Live-Abfrage. 1 erfordert genau eine eindeutige Session-ID in SessionIds. Sonst wird ein INVALID_PARAMETER-Planstatus ausgegeben. Liest laufenden Request, aktiviert kein Profiling. NULL aktiviert den Zweig nicht.';
        PRINT N'@MaxAnalyseobjekte int. Default ist 20. Positive Zahl begrenzt die zusammengeführten Kandidaten. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Oberhalb 20 einschließlich unbegrenzt wird PLAN_CACHE_DEEP geprüft und je Policy kann HighImpactConfirmed erforderlich sein. Limit ist keine Ergebniszeilengrenze.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung, 1 bestätigt das Deep-Analyse-Gate gemäß zentraler Policy. Der Parameter übergeht das Gate nicht selbständig. NULL ist kein eigener bestätigender Wert.';
        PRINT N'@MaxSqlTextZeichen int. Default ist 8000. Positive Zahl kürzt Statement- und Batchtext auf diese Zeichenanzahl. 0 oder NULL erhält beide vollständig. Negativ ist INVALID_PARAMETER.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Nach Trim und Großschreibung: CONSOLE gibt lesbare benannte Resultsets. RAW gibt kanonische rohe Resultsets. NONE unterdrückt direkte Resultsets. TABLE schreibt in registrierte Zieltabellen. Geschlossene Menge: CONSOLE, RAW, NONE, TABLE. NULL/Leerwert normalisiert zu leer und ist ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel candidates, attributes und plans. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. Ein ungültiges Mapping kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 0 erzeugt kein JSON. 1 erzeugt JSON im OUTPUT-Parameter. NULL kein aktiver Schalterwert/keine JSON-Erzeugung.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie ein Objekt mit meta, candidates, attributes, plans und warnings.';
        PRINT N'@PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert oder validiert den Wert nicht. 1 ermöglicht die eigene Statusmeldung nur am erreichten Ende bei einem nicht-NULL Status ungleich AVAILABLE; außerdem ermöglicht 1 die Truncation-Warnung nur bei positiver Zahl gekürzter Werte. Beide Meldungen sind RAISERROR Severity 10 WITH NOWAIT und keine SQL-Ausnahme. 0 und NULL unterdrücken diese optionalen Meldungen. Die Hilfeausgabe sowie Vorbereitungs- und SQL-Fehler sind unabhängig; vollständige Stille ist nicht garantiert.';
        PRINT N'@Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der Prüfung von @ResultTablesJson und beendet den Aufruf vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.';
        PRINT N'Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;';
        PRINT N'Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt=''RAW'';';
        PRINT N'Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanDetails_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"plans":"#PlanDetails_HelpExample"}''; SELECT * FROM #PlanDetails_HelpExample; DROP TABLE #PlanDetails_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanDetails_HelpExample; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_PlanDetails
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_PlanDetails') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_PlanDetails"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_PlanDetails"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan."'
            + NCHAR(10)
            + N'source_path: "Code/04_PlanCache/040_USP_PlanDetails.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_PlanDetails'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan, Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'sys.dm_exec_requests, sys.dm_exec_query_stats, sys.dm_exec_sql_text, sys.dm_exec_plan_attributes, sys.dm_exec_query_plan, sys.dm_exec_text_query_plan, sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.'
            + NCHAR(10)
            + NCHAR(10)
            + N'VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @SessionIds | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @PlanHandle | varbinary(64) | nein | NULL |'
            + NCHAR(10)
            + N'| @SqlHandle | varbinary(64) | nein | NULL |'
            + NCHAR(10)
            + N'| @QueryHash | binary(8) | nein | NULL |'
            + NCHAR(10)
            + N'| @MitPlanAttributes | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @MitCompilePlan | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @MitTextPlan | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MitLastActualPlan | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MitLivePlan | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxAnalyseobjekte | int | nein | 20 |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxSqlTextZeichen | int | nein | 8000 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SessionIds:** @SessionIds nvarchar(max). Default ist NULL. Liste ganzer Session-IDs von 1 bis 32767, z. B. 57|61. Pipe, Beistrich und Strichpunkt sind Trennzeichen. NULL lässt diesen Selektor aus. Leere, nur aus Leerzeichen bestehende oder ungültige Elemente ergeben INVALID_PARAMETER. Doppelte IDs werden zusammengefasst. Live-XML erfordert genau eine eindeutige Session-ID.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. NULL lässt diesen Selektor aus. Nicht-null wird als Kandidat aufgenommen, auch wenn der Handle inzwischen nicht mehr im Cache auflösbar ist.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SqlHandle:** @SqlHandle varbinary(64). Default ist NULL. Exakter SQL-Handle. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Zeilen dieses Handles. Bis zum Kandidatenlimit, nach total_worker_time absteigend.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@QueryHash:** @QueryHash binary(8). Default ist NULL. Exakter 8-Byte Queryhash. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Kandidaten dieses Hashes. Bis zum Kandidatenlimit, nach total_worker_time absteigend.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitPlanAttributes:** @MitPlanAttributes bit. Default ist 1. 0 unterdrückt Planattribute. 1 liest sie für jeden behaltenen Kandidaten. NULL wird von der Implementierung nicht als eigener Modus unterstützt (SQL-IF-Zweig wird nicht aktiviert).'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitCompilePlan:** @MitCompilePlan bit. Default ist 1. 0 unterdrückt kompiliertes Showplan-XML. 1 fordert sys.dm_exec_query_plan an. NULL aktiviert den Zweig nicht. Fehlender Plan wird als nicht verfügbar je Candidate ausgegeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitTextPlan:** @MitTextPlan bit. Default ist 0. 0 unterdrückt Text-Showplan. 1 fordert ihn an. NULL aktiviert den Zweig nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitLastActualPlan:** @MitLastActualPlan bit. Default ist 0. 0 unterdrückt Last-known-Actual-Plan. 1 liest vorhandene LAST_QUERY_PLAN_STATS-Evidenz. Die Procedure aktiviert die Datenbankoption nicht. NULL aktiviert den Zweig nicht. Fehlendes XML kann deaktiviert, ungeeignet, nicht cachebar oder evicted bedeuten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitLivePlan:** @MitLivePlan bit. Default ist 0. 0 unterdrückt Live-Abfrage. 1 erfordert genau eine eindeutige Session-ID in SessionIds. Sonst wird ein INVALID_PARAMETER-Planstatus ausgegeben. Liest laufenden Request, aktiviert kein Profiling. NULL aktiviert den Zweig nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxAnalyseobjekte:** @MaxAnalyseobjekte int. Default ist 20. Positive Zahl begrenzt die zusammengeführten Kandidaten. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Oberhalb 20 einschließlich unbegrenzt wird PLAN_CACHE_DEEP geprüft und je Policy kann HighImpactConfirmed erforderlich sein. Limit ist keine Ergebniszeilengrenze.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung, 1 bestätigt das Deep-Analyse-Gate gemäß zentraler Policy. Der Parameter übergeht das Gate nicht selbständig. NULL ist kein eigener bestätigender Wert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxSqlTextZeichen:** @MaxSqlTextZeichen int. Default ist 8000. Positive Zahl kürzt Statement- und Batchtext auf diese Zeichenanzahl. 0 oder NULL erhält beide vollständig. Negativ ist INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16). Default ist ''CONSOLE''. Nach Trim und Großschreibung: CONSOLE gibt lesbare benannte Resultsets. RAW gibt kanonische rohe Resultsets. NONE unterdrückt direkte Resultsets. TABLE schreibt in registrierte Zieltabellen. Geschlossene Menge: CONSOLE, RAW, NONE, TABLE. NULL/Leerwert normalisiert zu leer und ist ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel candidates, attributes und plans. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. Ein ungültiges Mapping kann Fehler 51011 auslösen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 0 erzeugt kein JSON. 1 erzeugt JSON im OUTPUT-Parameter. NULL kein aktiver Schalterwert/keine JSON-Erzeugung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie ein Objekt mit meta, candidates, attributes, plans und warnings.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert oder validiert den Wert nicht. 1 ermöglicht die eigene Statusmeldung nur am erreichten Ende bei einem nicht-NULL Status ungleich AVAILABLE; außerdem ermöglicht 1 die Truncation-Warnung nur bei positiver Zahl gekürzter Werte. Beide Meldungen sind RAISERROR Severity 10 WITH NOWAIT und keine SQL-Ausnahme. 0 und NULL unterdrücken diese optionalen Meldungen. Die Hilfeausgabe sowie Vorbereitungs- und SQL-Fehler sind unabhängig; vollständige Stille ist nicht garantiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der Prüfung von @ResultTablesJson und beendet den Aufruf vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute. 4. angeforderte Pläne mit SourceType und Status.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| candidates | 1 | 1 | [CandidateId] int,[SessionId] smallint NULL,[RequestId] int NULL,[PlanHandle] varbinary(64) NULL,[SqlHandle] varbinary(64) NULL , [QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[StatementStartOffset] int NULL,[StatementEndOffset] int NULL , [CreationTime] datetime NULL,[LastExecutionTime] datetime NULL,[ExecutionCount] bigint NULL , [StatementTextCharacters] bigint NULL,[StatementTextBytes] bigint NULL,[StatementTextIsTruncated] bit NOT NULL DEFAULT(0),[StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchTextCharacters] bigint NULL,[BatchTextBytes] bigint NULL,[BatchTextIsTruncated] bit NOT NULL DEFAULT(0),[BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SqlTextDatabaseId] int NULL,[SqlTextDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SqlTextObjectId] int NULL |'
            + NCHAR(10)
            + N'| attributes | 1 | 1 | [CandidateId] int,[AttributeName] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[AttributeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsCacheKey] bit |'
            + NCHAR(10)
            + N'| plans | 1 | 1 | [CandidateId] int,[SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ObjectId] int NULL,[IsEncrypted] bit NULL,[QueryPlanXml] xml NULL,[QueryPlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende begrenzte Aufruf untersucht die eigene aktuelle Sitzung. Er kann ohne einen erfassten Plan leere Fachmengen liefern; Rechte und Planverfügbarkeit sind separat zu prüfen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'DECLARE @SessionIds nvarchar(max)=CONVERT(nvarchar(20),@@SPID);'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_PlanDetails] @SessionIds=@SessionIds, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_PlanDetails'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;'
            + NCHAR(10)
            + NCHAR(10)
            + N'Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.USP_PlanDetails'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Liefert gezielt SQL-Text, Planattribute, kompilierten Showplan,'
            + NCHAR(10)
            + N'               Text-Showplan, letzten bekannten Actual Plan oder Live-Plan.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Datenquellen : sys.dm_exec_requests, sys.dm_exec_query_stats,'
            + NCHAR(10)
            + N'               sys.dm_exec_sql_text, sys.dm_exec_plan_attributes,'
            + NCHAR(10)
            + N'               sys.dm_exec_query_plan, sys.dm_exec_text_query_plan,'
            + NCHAR(10)
            + N'               sys.dm_exec_query_plan_stats, sys.dm_exec_query_statistics_xml.'
            + NCHAR(10)
            + N'Parameter    : @SessionIds, @PlanHandle, @SqlHandle, @QueryHash,'
            + NCHAR(10)
            + N'               @MitPlanAttributes, @MitCompilePlan, @MitTextPlan,'
            + NCHAR(10)
            + N'               @MitLastActualPlan, @MitLivePlan, @MaxAnalyseobjekte,'
            + NCHAR(10)
            + N'               @MaxSqlTextZeichen, @PrintMeldungen, @Hilfe.'
            + NCHAR(10)
            + N'Resultsets   : 1. Modulstatus. 2. Kandidaten und SQL-Text. 3. Planattribute.'
            + NCHAR(10)
            + N'               4. angeforderte Pläne mit SourceType und Status.'
            + NCHAR(10)
            + N'Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.'
            + NCHAR(10)
            + N'Eigenlast    : Zielgerichtet und auf @MaxAnalyseobjekte begrenzt. Mehr als 20 Pläne'
            + NCHAR(10)
            + N'               prüft PLAN_CACHE_DEEP. Das Framework aktiviert keine Profilingoption.'
            + NCHAR(10)
            + N'Locking      : Keine Benutzerobjekte.'
            + NCHAR(10)
            + N'Partial      : Jede Planquelle wird je Kandidat isoliert; fehlende oder evictete'
            + NCHAR(10)
            + N'               Pläne lassen andere Quellen und Kandidaten bestehen.'
            + NCHAR(10)
            + N'Beispiele    : EXEC monitor.USP_PlanDetails @SessionIds=N57,@MitLivePlan=1;'
            + NCHAR(10)
            + N'               EXEC monitor.USP_PlanDetails @PlanHandle=0x...;'
            + NCHAR(10)
            + N'               EXEC monitor.USP_PlanDetails @QueryHash=0x...,@MitLastActualPlan=1;'
            + NCHAR(10)
            + N'               EXEC monitor.USP_PlanDetails @Hilfe=1;'
            + NCHAR(10)
            + N'Änderungen   : 1.1.0 - Deep-Gate ab mehr als 20 Plänen.'
            + NCHAR(10)
            + N'               1.0.0 - Erstfassung Phase 3.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_PlanDetails'
            + NCHAR(10)
            + N'Die Procedure löst ausgewählte Planhandles auf und zeigt auf Wunsch Planattribute, Compile-Pläne und verfügbare Laufzeitpläne. Sie aktiviert weder LAST_QUERY_PLAN_STATS noch Live-Profiling.'
            + NCHAR(10)
            + N'Hilfe anzeigen. EXEC [monitor].[USP_PlanDetails] @Hilfe=1;'
            + NCHAR(10)
            + N'Technische Resultsets lesen. EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
            + NCHAR(10)
            + N'Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanDetails_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"plans":"#PlanDetails_HelpExample"}''; SELECT * FROM #PlanDetails_HelpExample; DROP TABLE #PlanDetails_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanDetails_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_PlanDetails
        RETURN;
    END

    SET @Json=NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    CREATE TABLE [#PlanDetails_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
    BEGIN
        DECLARE @TablePreflightStatus varchar(40),@TablePreflightError nvarchar(2048);
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'candidates|attributes|plans'
            , @MappingTable=N'#PlanDetails_ResultTableMap'
            , @StatusCode=@TablePreflightStatus OUTPUT
            , @ErrorMessage=@TablePreflightError OUTPUT
            , @ThrowOnError=1;
    END;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @SingleSessionId smallint=NULL;
    DECLARE @EffectiveMaxAnalyseobjekte bigint = CASE WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxAnalyseobjekte) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    ;

    DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@RowCount bigint=0,
            @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@Detail nvarchar(2000)=NULL,@Allowed bit=1,
            @RequiredPermission nvarchar(256)=CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;

    CREATE TABLE [#PlanDetails_SessionIdFilter]([SessionId] smallint NOT NULL PRIMARY KEY);
    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS(SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds) WHERE [IsValid]=0 OR [NumberValue] NOT BETWEEN 1 AND 32767)
        BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@SessionIds enthält einen ungültigen Wert.';END
        ELSE INSERT [#PlanDetails_SessionIdFilter] SELECT CONVERT(smallint,[NumberValue]) FROM [monitor].[TVF_ParseBigintList](@SessionIds) GROUP BY [NumberValue];
        IF (SELECT COUNT_BIG(*) FROM [#PlanDetails_SessionIdFilter])=1 SELECT @SingleSessionId=MIN([SessionId]) FROM [#PlanDetails_SessionIdFilter];
    END;

    CREATE TABLE [#PlanDetails_Candidate]
    (
        [CandidateId] int IDENTITY(1,1) PRIMARY KEY,[SessionId] smallint NULL,[RequestId] int NULL,[PlanHandle] varbinary(64) NULL,
        [SqlHandle] varbinary(64) NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[StatementStartOffset] int NULL,
        [StatementEndOffset] int NULL,[CreationTime] datetime NULL,[LastExecutionTime] datetime NULL,[ExecutionCount] bigint NULL
    );
    CREATE TABLE [#PlanDetails_Attributes]([CandidateId] int,[AttributeName] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[AttributeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsCacheKey] bit);
    CREATE TABLE [#PlanDetails_Plans]([CandidateId] int,[SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ObjectId] int NULL,[IsEncrypted] bit NULL,[QueryPlanXml] xml NULL,[QueryPlanText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);

    SET LOCK_TIMEOUT 0;

    IF @SessionIds IS NULL AND @PlanHandle IS NULL AND @SqlHandle IS NULL AND @QueryHash IS NULL
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'Mindestens ein Selektor ist erforderlich.';END;
    IF @MaxAnalyseobjekte<0 OR @MaxSqlTextZeichen < 0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@MaxAnalyseobjekte oder @MaxSqlTextZeichen darf nicht negativ sein.';END;
    IF @StatusCode='AVAILABLE' AND @EffectiveMaxAnalyseobjekte>20
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='PLAN_CACHE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        IF @SessionIds IS NOT NULL
        BEGIN
            INSERT [#PlanDetails_Candidate]([SessionId],[RequestId],[PlanHandle],[SqlHandle],[QueryHash],[QueryPlanHash],[StatementStartOffset],[StatementEndOffset],[CreationTime],[LastExecutionTime],[ExecutionCount])
            SELECT TOP (@EffectiveMaxAnalyseobjekte) [r].[session_id],[r].[request_id],[r].[plan_handle],[r].[sql_handle],[r].[query_hash],[r].[query_plan_hash],[r].[statement_start_offset],[r].[statement_end_offset],NULL,[r].[start_time],NULL
            FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK) JOIN [#PlanDetails_SessionIdFilter] AS [sf] ON [sf].[SessionId]=[r].[session_id] ORDER BY [r].[session_id],[r].[request_id];
        END;
        IF @PlanHandle IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [#PlanDetails_Candidate] WHERE [PlanHandle]=@PlanHandle)
            INSERT [#PlanDetails_Candidate]([PlanHandle]) VALUES(@PlanHandle);
        IF @SqlHandle IS NOT NULL
            INSERT [#PlanDetails_Candidate]([PlanHandle],[SqlHandle],[QueryHash],[QueryPlanHash],[StatementStartOffset],[StatementEndOffset],[CreationTime],[LastExecutionTime],[ExecutionCount])
            SELECT TOP (@EffectiveMaxAnalyseobjekte) [qs].[plan_handle],[qs].[sql_handle],[qs].[query_hash],[qs].[query_plan_hash],[qs].[statement_start_offset],[qs].[statement_end_offset],[qs].[creation_time],[qs].[last_execution_time],[qs].[execution_count]
            FROM [sys].[dm_exec_query_stats] AS qs WITH (NOLOCK) WHERE [qs].[sql_handle]=@SqlHandle AND NOT EXISTS(SELECT 1 FROM [#PlanDetails_Candidate] c WHERE [c].[PlanHandle]=[qs].[plan_handle] AND COALESCE([c].[StatementStartOffset],-1)=COALESCE([qs].[statement_start_offset],-1))
            ORDER BY [qs].[total_worker_time] DESC;
        IF @QueryHash IS NOT NULL
            INSERT [#PlanDetails_Candidate]([PlanHandle],[SqlHandle],[QueryHash],[QueryPlanHash],[StatementStartOffset],[StatementEndOffset],[CreationTime],[LastExecutionTime],[ExecutionCount])
            SELECT TOP (@EffectiveMaxAnalyseobjekte) [qs].[plan_handle],[qs].[sql_handle],[qs].[query_hash],[qs].[query_plan_hash],[qs].[statement_start_offset],[qs].[statement_end_offset],[qs].[creation_time],[qs].[last_execution_time],[qs].[execution_count]
            FROM [sys].[dm_exec_query_stats] AS qs WITH (NOLOCK) WHERE [qs].[query_hash]=@QueryHash AND NOT EXISTS(SELECT 1 FROM [#PlanDetails_Candidate] c WHERE [c].[PlanHandle]=[qs].[plan_handle] AND COALESCE([c].[StatementStartOffset],-1)=COALESCE([qs].[statement_start_offset],-1))
            ORDER BY [qs].[total_worker_time] DESC;
        DELETE [c] FROM [#PlanDetails_Candidate] AS c WHERE [c].[CandidateId] NOT IN(SELECT TOP (@EffectiveMaxAnalyseobjekte) [CandidateId] FROM [#PlanDetails_Candidate] ORDER BY [CandidateId]);
        SELECT @RowCount=COUNT_BIG(*) FROM [#PlanDetails_Candidate];SET @Detail=CASE WHEN @RowCount=0 THEN N'Kein passender Planhandle sichtbar.' ELSE N'Kandidaten erfolgreich ermittelt.' END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;
        SET @StatusCode=CASE WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    CREATE TABLE [#PlanDetails_CandidatesOutput]
    (
          [CandidateId] int,[SessionId] smallint NULL,[RequestId] int NULL,[PlanHandle] varbinary(64) NULL,[SqlHandle] varbinary(64) NULL
        , [QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,[StatementStartOffset] int NULL,[StatementEndOffset] int NULL
        , [CreationTime] datetime NULL,[LastExecutionTime] datetime NULL,[ExecutionCount] bigint NULL
        , [StatementTextCharacters] bigint NULL,[StatementTextBytes] bigint NULL,[StatementTextIsTruncated] bit NOT NULL DEFAULT(0),[StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BatchTextCharacters] bigint NULL,[BatchTextBytes] bigint NULL,[BatchTextIsTruncated] bit NOT NULL DEFAULT(0),[BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SqlTextDatabaseId] int NULL,[SqlTextDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SqlTextObjectId] int NULL
    );
    INSERT [#PlanDetails_CandidatesOutput]
    ([CandidateId],[SessionId],[RequestId],[PlanHandle],[SqlHandle],[QueryHash],[QueryPlanHash],
     [StatementStartOffset],[StatementEndOffset],[CreationTime],[LastExecutionTime],[ExecutionCount])
    SELECT [CandidateId],[SessionId],[RequestId],[PlanHandle],[SqlHandle],[QueryHash],[QueryPlanHash],
           [StatementStartOffset],[StatementEndOffset],[CreationTime],[LastExecutionTime],[ExecutionCount]
    FROM [#PlanDetails_Candidate];

    DECLARE @ResolveCandidateDetails bit=CASE WHEN @StatusCode IN('AVAILABLE','PARTIAL') THEN 1 ELSE 0 END,
            @SourceCandidateId int,@SourcePlanHandle varbinary(64),@SourceSqlHandle varbinary(64),
            @SourceStartOffset int,@SourceEndOffset int;
    DECLARE [CandidateSourceCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [CandidateId],[PlanHandle],[SqlHandle],[StatementStartOffset],[StatementEndOffset]
        FROM [#PlanDetails_Candidate] ORDER BY [CandidateId];
    OPEN [CandidateSourceCursor];
    FETCH NEXT FROM [CandidateSourceCursor] INTO @SourceCandidateId,@SourcePlanHandle,@SourceSqlHandle,@SourceStartOffset,@SourceEndOffset;
    WHILE @@FETCH_STATUS=0
    BEGIN
    IF @ResolveCandidateDetails=1 AND @MitPlanAttributes=1
    BEGIN TRY
        INSERT [#PlanDetails_Attributes]
        SELECT [c].[CandidateId],[pa].[attribute],CONVERT(nvarchar(4000),[pa].[value]),[pa].[is_cache_key]
        FROM [#PlanDetails_Candidate] AS c CROSS APPLY sys.dm_exec_plan_attributes(@SourcePlanHandle) AS pa WHERE [c].[CandidateId]=@SourceCandidateId;
    END TRY BEGIN CATCH SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;END CATCH;

    IF @ResolveCandidateDetails=1 AND @MitCompilePlan=1
    BEGIN TRY
        INSERT [#PlanDetails_Plans]
        SELECT [c].[CandidateId],'COMPILE_XML',CASE WHEN [qp].[query_plan] IS NULL THEN 'UNAVAILABLE_OBJECT' ELSE 'AVAILABLE' END,[qp].[dbid],[qp].[objectid],[qp].[encrypted],[qp].[query_plan],NULL,NULL,CASE WHEN [qp].[query_plan] IS NULL THEN N'Plan nicht mehr im Cache oder XML-Tiefenlimit erreicht.' END
        FROM [#PlanDetails_Candidate] AS c OUTER APPLY sys.dm_exec_query_plan(@SourcePlanHandle) AS qp WHERE [c].[CandidateId]=@SourceCandidateId;
    END TRY BEGIN CATCH INSERT [#PlanDetails_Plans] VALUES(@SourceCandidateId,'COMPILE_XML','ERROR_HANDLED',NULL,NULL,NULL,NULL,NULL,ERROR_NUMBER(),ERROR_MESSAGE());SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;END CATCH;

    IF @ResolveCandidateDetails=1 AND @MitTextPlan=1
    BEGIN TRY
        INSERT [#PlanDetails_Plans]
        SELECT [c].[CandidateId],'COMPILE_TEXT',CASE WHEN [tp].[query_plan] IS NULL THEN 'UNAVAILABLE_OBJECT' ELSE 'AVAILABLE' END,[tp].[dbid],[tp].[objectid],[tp].[encrypted],NULL,[tp].[query_plan],NULL,CASE WHEN [tp].[query_plan] IS NULL THEN N'Textplan nicht verfügbar.' END
        FROM [#PlanDetails_Candidate] AS c OUTER APPLY sys.dm_exec_text_query_plan(@SourcePlanHandle,COALESCE(@SourceStartOffset,0),COALESCE(@SourceEndOffset,-1)) AS tp WHERE [c].[CandidateId]=@SourceCandidateId;
    END TRY BEGIN CATCH INSERT [#PlanDetails_Plans] VALUES(@SourceCandidateId,'COMPILE_TEXT','ERROR_HANDLED',NULL,NULL,NULL,NULL,NULL,ERROR_NUMBER(),ERROR_MESSAGE());SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;END CATCH;

    IF @ResolveCandidateDetails=1 AND @MitLastActualPlan=1
    BEGIN TRY
        INSERT [#PlanDetails_Plans]
        SELECT [c].[CandidateId],'LAST_ACTUAL_XML',CASE WHEN [qp].[query_plan] IS NULL THEN 'AVAILABLE_DISABLED' ELSE 'AVAILABLE' END,[qp].[dbid],[qp].[objectid],[qp].[encrypted],[qp].[query_plan],NULL,NULL,
               CASE WHEN [qp].[query_plan] IS NULL THEN N'LAST_QUERY_PLAN_STATS nicht aktiviert, Plan nicht geeignet, nicht cachebar oder bereits evictet.' END
        FROM [#PlanDetails_Candidate] AS c OUTER APPLY sys.dm_exec_query_plan_stats(@SourcePlanHandle) AS qp WHERE [c].[CandidateId]=@SourceCandidateId;
    END TRY BEGIN CATCH INSERT [#PlanDetails_Plans] VALUES(@SourceCandidateId,'LAST_ACTUAL_XML','ERROR_HANDLED',NULL,NULL,NULL,NULL,NULL,ERROR_NUMBER(),ERROR_MESSAGE());SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;END CATCH;

    BEGIN TRY
        UPDATE [o]
        SET [StatementText]=[statementText].[StatementText],[BatchText]=[st].[text],
            [SqlTextDatabaseId]=[st].[dbid],
            [SqlTextDatabaseName]=(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=[st].[dbid]),
            [SqlTextObjectId]=[st].[objectid]
        FROM [#PlanDetails_CandidatesOutput] AS [o]
        JOIN [#PlanDetails_Candidate] AS [c] ON [c].[CandidateId]=[o].[CandidateId]
        OUTER APPLY [sys].[dm_exec_sql_text](COALESCE(@SourceSqlHandle,@SourcePlanHandle)) AS [st]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [st].[text]
            , [c].[StatementStartOffset]
            , [c].[StatementEndOffset]
        ) AS [statementText]
        WHERE [o].[CandidateId]=@SourceCandidateId;
    END TRY BEGIN CATCH SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;END CATCH;
    FETCH NEXT FROM [CandidateSourceCursor] INTO @SourceCandidateId,@SourcePlanHandle,@SourceSqlHandle,@SourceStartOffset,@SourceEndOffset;
    END;
    CLOSE [CandidateSourceCursor];DEALLOCATE [CandidateSourceCursor];

    IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1
    BEGIN TRY
        IF @SingleSessionId IS NULL
            INSERT [#PlanDetails_Plans] VALUES(NULL,'LIVE_XML','INVALID_PARAMETER',NULL,NULL,NULL,NULL,NULL,NULL,N'@MitLivePlan erfordert genau eine Session in @SessionIds.');
        ELSE
            INSERT [#PlanDetails_Plans]
            SELECT [c].[CandidateId],'LIVE_XML',CASE WHEN [qx].[query_plan] IS NULL THEN 'UNAVAILABLE_OBJECT' ELSE 'AVAILABLE' END,NULL,NULL,NULL,[qx].[query_plan],NULL,NULL,
                   CASE WHEN [qx].[query_plan] IS NULL THEN N'Request nicht mehr aktiv oder Live-Plan nicht verfügbar.' END
            FROM [sys].[dm_exec_query_statistics_xml](@SingleSessionId) AS [qx]
            LEFT JOIN [#PlanDetails_Candidate] AS c ON [c].[SessionId]=[qx].[session_id] AND ([c].[RequestId]=[qx].[request_id] OR [c].[RequestId] IS NULL);
    END TRY BEGIN CATCH INSERT [#PlanDetails_Plans] VALUES(NULL,'LIVE_XML','ERROR_HANDLED',NULL,NULL,NULL,NULL,NULL,ERROR_NUMBER(),ERROR_MESSAGE());SET @IsPartial=1;SET @StatusCode='PARTIAL';END CATCH;

    DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
    DECLARE @ColumnTruncatedCount bigint=0,@ColumnLargestCharacters bigint=NULL;
    DECLARE @ProjectionMaxCharacters int=CASE WHEN @MaxSqlTextZeichen<0 THEN 0 ELSE @MaxSqlTextZeichen END;
    EXEC [monitor].[InternalProjectUnicodeTextColumn]
          @SourceTable=N'#PlanDetails_CandidatesOutput',@TextColumn=N'StatementText'
        , @CharactersColumn=N'StatementTextCharacters',@BytesColumn=N'StatementTextBytes'
        , @IsTruncatedColumn=N'StatementTextIsTruncated',@MaxCharacters=@ProjectionMaxCharacters
        , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
    SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
           @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
    EXEC [monitor].[InternalProjectUnicodeTextColumn]
          @SourceTable=N'#PlanDetails_CandidatesOutput',@TextColumn=N'BatchText'
        , @CharactersColumn=N'BatchTextCharacters',@BytesColumn=N'BatchTextBytes'
        , @IsTruncatedColumn=N'BatchTextIsTruncated',@MaxCharacters=@ProjectionMaxCharacters
        , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
    SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
           @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
    EXEC [monitor].[InternalEmitTruncationWarning]
          @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen'
        , @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
        , @PrintMeldungen=@PrintMeldungen;
    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE') BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_PlanDetails: %s - %s', @StatusCode, COALESCE(@ErrorMessage,N''));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;
    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN
        SELECT N'USP_PlanDetails' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@RowCount [RowCount],@RequiredPermission [RequiredPermission],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage],@Detail [Detail];
        IF @ResultSetArtNormalisiert='RAW'
        BEGIN
            SELECT * FROM [#PlanDetails_CandidatesOutput] ORDER BY [CandidateId];
            IF @MitPlanAttributes=1 SELECT * FROM [#PlanDetails_Attributes] ORDER BY [CandidateId],[AttributeName];
            IF @MitCompilePlan=1 OR @MitTextPlan=1 OR @MitLastActualPlan=1 OR @MitLivePlan=1 SELECT * FROM [#PlanDetails_Plans] ORDER BY [CandidateId],[SourceType];
        END
        ELSE
        BEGIN
            SELECT N'Plan-Kandidat' AS [Ergebnis],[CandidateId] AS [Kandidat],[SessionId] AS [Session],[RequestId] AS [Request],[SqlTextDatabaseName] AS [Datenbank],[QueryHash] AS [Query Hash],[QueryPlanHash] AS [Plan Hash],[ExecutionCount] AS [Ausführungen],[LastExecutionTime] AS [letzte Ausführung],[SessionId] AS [Session SQL],[StatementText] AS [Statement],[BatchText] AS [Batch] FROM [#PlanDetails_CandidatesOutput] ORDER BY [CandidateId];
            IF @MitPlanAttributes=1 SELECT N'Planattribut' AS [Ergebnis],[CandidateId] AS [Kandidat],[AttributeName] AS [Attribut],[AttributeValue] AS [Wert],[IsCacheKey] AS [Cache-Key] FROM [#PlanDetails_Attributes] ORDER BY [CandidateId],[AttributeName];
            IF @MitCompilePlan=1 OR @MitTextPlan=1 OR @MitLastActualPlan=1 OR @MitLivePlan=1 SELECT N'Planinhalt' AS [Ergebnis],[CandidateId] AS [Kandidat],[SourceType] AS [Quelle],[StatusCode] AS [Status],[DatabaseId] AS [Datenbank-ID],[ObjectId] AS [Objekt-ID],[ErrorMessage] AS [Hinweis],[QueryPlanXml] AS [Plan XML],[QueryPlanText] AS [Plan Text] FROM [#PlanDetails_Plans] ORDER BY [CandidateId],[SourceType];
        END;
    END;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'PlanDetails' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@RowCount [candidateCount],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @CandidatesJson nvarchar(max)=(SELECT * FROM [#PlanDetails_CandidatesOutput] ORDER BY [CandidateId] FOR JSON PATH,INCLUDE_NULL_VALUES),@AttributesJson nvarchar(max)=(SELECT * FROM [#PlanDetails_Attributes] ORDER BY [CandidateId],[AttributeName] FOR JSON PATH,INCLUDE_NULL_VALUES),@PlansJson nvarchar(max)=(SELECT [CandidateId],[SourceType],[StatusCode],[DatabaseId],[ObjectId],[IsEncrypted],CONVERT(nvarchar(max),[QueryPlanXml]) [QueryPlanXml],[QueryPlanText],[ErrorNumber],[ErrorMessage] FROM [#PlanDetails_Plans] ORDER BY [CandidateId],[SourceType] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"candidates":',COALESCE(@CandidatesJson,N'[]'),N',"attributes":',COALESCE(@AttributesJson,N'[]'),N',"plans":',COALESCE(@PlansJson,N'[]'),N',"warnings":[]}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#PlanDetails_CandidatesOutput'
            , @ResultLabel=N'PlanDetails'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        DECLARE @TableResultName sysname,@TableTarget sysname,@TableSource sysname;
        DECLARE [TableResultCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable] FROM [#PlanDetails_ResultTableMap] ORDER BY [ResultName];
        OPEN [TableResultCursor];
        FETCH NEXT FROM [TableResultCursor] INTO @TableResultName,@TableTarget;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @TableSource=CASE @TableResultName
                WHEN N'candidates' THEN N'#PlanDetails_CandidatesOutput'
                WHEN N'attributes' THEN N'#PlanDetails_Attributes'
                WHEN N'plans' THEN N'#PlanDetails_Plans' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@TableSource,@TargetTable=@TableTarget,@ThrowOnError=1;
            FETCH NEXT FROM [TableResultCursor] INTO @TableResultName,@TableTarget;
        END;
        CLOSE [TableResultCursor];DEALLOCATE [TableResultCursor];
    END;
END;
GO
