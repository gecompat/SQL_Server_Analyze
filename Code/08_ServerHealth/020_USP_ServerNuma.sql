USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerNuma
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung,
               den Scheduler-Skew und die Memory Nodes.
Datenquellen : sys.dm_os_nodes, sys.dm_os_schedulers, sys.dm_os_memory_nodes
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach zwei technische Fachresultsets.
               CONSOLE gibt nur die Console-Helferausgabe der NUMA-Knoten aus; TABLE schreibt ausschließlich das gemappte numaNodes-Resultset.
               Beide liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
===============================================================================
*/

-- USAGE_SKILL_BEGIN monitor.USP_ServerNuma 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_ServerNuma"
-- schema_name: "monitor"
-- object_name: "USP_ServerNuma"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes."
-- source_path: "Code/08_ServerHealth/020_USP_ServerNuma.sql"
-- ---
-- 
-- # monitor.USP_ServerNuma
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerNuma] im vorgesehenen Datenbankkontext. Die Procedure liest Scheduler, OS-Knoten und Memory-Knoten aus Server-DMVs. Ohne entsprechende Servermetadatenrechte ist das Ergebnis eingeschränkt.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. TABLE-Preflight und Ablehnung eines nichtleeren Mappings außerhalb TABLE laufen nur im normalen Pfad; sie können dort werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.
-- 
-- **@ResultTablesJson:** @ResultTablesJson ordnet für TABLE genau numaNodes einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | numaNodes | 1 | 1 | [node_id] int,[node_state_desc] nvarchar(60),[memory_node_id] int,[online_scheduler_count] int,[idle_scheduler_count] int,[active_worker_count] int,[avg_load_balance] bigint,[SchedulerCount] bigint,[VisibleOnline] bigint,[CurrentTasks] bigint,[RunnableTasks] bigint,[ActiveWorkers] bigint,[LoadFactor] bigint,[RunnablePerScheduler] decimal(19,4),[Finding] varchar(50) |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'CONSOLE';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_ServerNuma
-- 
-- Server-Health-Momentaufnahme; read-only und nicht atomar.
-- 
-- Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).
-- 
-- RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.
-- 
-- Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_ServerNuma
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Zweck        : Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung,
--                den Scheduler-Skew und die Memory Nodes.
-- Datenquellen : sys.dm_os_nodes, sys.dm_os_schedulers, sys.dm_os_memory_nodes
-- Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach zwei technische Fachresultsets.
--                CONSOLE gibt nur die Console-Helferausgabe der NUMA-Knoten aus; TABLE schreibt ausschließlich das gemappte numaNodes-Resultset.
--                Beide liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
--                Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_ServerNuma
-- Server-Health-Momentaufnahme; read-only und nicht atomar.
-- Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).
-- RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.
-- Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.
-- CREATE TABLE [#ServerNuma_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'TABLE',@ResultTablesJson=N'{"numaNodes":"#ServerNuma_HelpExample"}'; DROP TABLE [#ServerNuma_HelpExample];
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_ServerNuma
CREATE OR ALTER PROCEDURE [monitor].[USP_ServerNuma]
 @PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,@ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe=1 BEGIN PRINT N'monitor.USP_ServerNuma';
        PRINT N'Server-Health-Momentaufnahme; read-only und nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).';
        PRINT N'@ResultTablesJson ordnet für TABLE genau numaNodes einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.';
        PRINT N'RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.';
        PRINT N'Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. TABLE-Preflight und Ablehnung eines nichtleeren Mappings außerhalb TABLE laufen nur im normalen Pfad; sie können dort werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Als TABLE-Eingabe ist ein JSON-Objekt mit genau einem Mapping für den registrierten Namen numaNodes auf eine vorhandene, leere lokale #temp-Tabelle nötig; diese muss genau eine Seed-/Platzhalterspalte besitzen. Das Ziel wird nur im normalen Pfad vor Quellerhebung geprüft; fehlerhafte oder fehlende TABLE-Ziele werfen beim Preflight Fehler 51011, daher werden Status-OUTPUTs nicht regulär gesetzt. Außerhalb von TABLE sind nur NULL, leer oder Leerzeichen erlaubt; jeder andere Inhalt wirft im normalen Pfad Fehler 51011 vor OUTPUT-Zuweisung; Hilfe kehrt vorher zurück.';
        PRINT N'@JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.';
        PRINT N'EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N''CONSOLE'';';
        PRINT N'EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N''RAW'';';
        PRINT N'EXEC [monitor].[USP_ServerNuma] @JsonErzeugen=1,@ResultSetArt=N''NONE'';';
        PRINT N'CREATE TABLE [#ServerNuma_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N''TABLE'',@ResultTablesJson=N''{"numaNodes":"#ServerNuma_HelpExample"}''; DROP TABLE [#ServerNuma_HelpExample];';
        PRINT N'EXEC [monitor].[USP_ServerNuma] @Hilfe=1;';







        -- USAGE_SKILL_HELP_BEGIN monitor.USP_ServerNuma
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_ServerNuma') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_ServerNuma"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_ServerNuma"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/020_USP_ServerNuma.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_ServerNuma'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerNuma] im vorgesehenen Datenbankkontext. Die Procedure liest Scheduler, OS-Knoten und Memory-Knoten aus Server-DMVs. Ohne entsprechende Servermetadatenrechte ist das Ergebnis eingeschränkt.'
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
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. TABLE-Preflight und Ablehnung eines nichtleeren Mappings außerhalb TABLE laufen nur im normalen Pfad; sie können dort werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson ordnet für TABLE genau numaNodes einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| numaNodes | 1 | 1 | [node_id] int,[node_state_desc] nvarchar(60),[memory_node_id] int,[online_scheduler_count] int,[idle_scheduler_count] int,[active_worker_count] int,[avg_load_balance] bigint,[SchedulerCount] bigint,[VisibleOnline] bigint,[CurrentTasks] bigint,[RunnableTasks] bigint,[ActiveWorkers] bigint,[LoadFactor] bigint,[RunnablePerScheduler] decimal(19,4),[Finding] varchar(50) |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N''CONSOLE'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_ServerNuma'
            + NCHAR(10)
            + NCHAR(10)
            + N'Server-Health-Momentaufnahme; read-only und nicht atomar.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).'
            + NCHAR(10)
            + NCHAR(10)
            + N'RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.'
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
            + N'Objekt       : monitor.USP_ServerNuma'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Zweck        : Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung,'
            + NCHAR(10)
            + N'               den Scheduler-Skew und die Memory Nodes.'
            + NCHAR(10)
            + N'Datenquellen : sys.dm_os_nodes, sys.dm_os_schedulers, sys.dm_os_memory_nodes'
            + NCHAR(10)
            + N'Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach zwei technische Fachresultsets.'
            + NCHAR(10)
            + N'               CONSOLE gibt nur die Console-Helferausgabe der NUMA-Knoten aus; TABLE schreibt ausschließlich das gemappte numaNodes-Resultset.'
            + NCHAR(10)
            + N'               Beide liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.'
            + NCHAR(10)
            + N'               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_ServerNuma'
            + NCHAR(10)
            + N'Server-Health-Momentaufnahme; read-only und nicht atomar.'
            + NCHAR(10)
            + N'Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).'
            + NCHAR(10)
            + N'RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.'
            + NCHAR(10)
            + N'Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#ServerNuma_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N''TABLE'',@ResultTablesJson=N''{"numaNodes":"#ServerNuma_HelpExample"}''; DROP TABLE [#ServerNuma_HelpExample];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_ServerNuma
        RETURN;END
SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'numaNodes',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#ServerNuma_N]([node_id] int,[node_state_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[memory_node_id] int,[online_scheduler_count] int,[idle_scheduler_count] int,[active_worker_count] int,[avg_load_balance] bigint,[SchedulerCount] bigint,[VisibleOnline] bigint,[CurrentTasks] bigint,[RunnableTasks] bigint,[ActiveWorkers] bigint,[LoadFactor] bigint,[RunnablePerScheduler] decimal(19,4),[Finding] varchar(50) COLLATE SQL_Latin1_General_CP1_CS_AS);
 CREATE TABLE [#ServerNuma_MN]([memory_node_id] int,[virtual_address_space_reserved_kb] bigint,[virtual_address_space_committed_kb] bigint,[locked_page_allocations_kb] bigint,[pages_kb] bigint,[shared_memory_reserved_kb] bigint,[shared_memory_committed_kb] bigint);
 SET LOCK_TIMEOUT 0;
 BEGIN TRY
  ;WITH X AS(SELECT [parent_node_id],COUNT_BIG(*)[SchedulerCount],SUM(CONVERT(bigint,CASE WHEN [status]='VISIBLE ONLINE' THEN 1 ELSE 0 END))[VisibleOnline],SUM(CONVERT(bigint,[current_tasks_count]))[CurrentTasks],SUM(CONVERT(bigint,[runnable_tasks_count]))[RunnableTasks],SUM(CONVERT(bigint,[active_workers_count]))[ActiveWorkers],SUM(CONVERT(bigint,[load_factor]))[LoadFactor] FROM [sys].[dm_os_schedulers] WITH (NOLOCK) WHERE [scheduler_id]<1048576 GROUP BY [parent_node_id])
  INSERT [#ServerNuma_N] SELECT [n].[node_id],[n].[node_state_desc],[n].[memory_node_id],[n].[online_scheduler_count],[n].[idle_scheduler_count],[n].[active_worker_count],[n].[avg_load_balance],[x].[SchedulerCount],[x].[VisibleOnline],[x].[CurrentTasks],[x].[RunnableTasks],[x].[ActiveWorkers],[x].[LoadFactor],
   CONVERT(decimal(19,4),1.0*[x].[RunnableTasks]/NULLIF([x].[VisibleOnline],0)),CASE WHEN [n].[node_state_desc] NOT LIKE 'ONLINE%' THEN 'NODE_NOT_ONLINE' WHEN [x].[RunnableTasks]>0 THEN 'RUNNABLE_TASKS_PRESENT' ELSE 'OK_SNAPSHOT' END
  FROM [sys].[dm_os_nodes] n WITH (NOLOCK) LEFT JOIN [X] x ON [x].[parent_node_id]=[n].[node_id] WHERE [n].[node_state_desc]<>'ONLINE DAC';
  INSERT [#ServerNuma_MN] SELECT [memory_node_id],[virtual_address_space_reserved_kb],[virtual_address_space_committed_kb],[locked_page_allocations_kb],[pages_kb],[shared_memory_reserved_kb],[shared_memory_committed_kb] FROM [sys].[dm_os_memory_nodes] WITH (NOLOCK) WHERE [memory_node_id]<64;
 END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE(); END CATCH;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;
 IF @PrintMeldungen=1 AND @S<>'AVAILABLE' RAISERROR(N'USP_ServerNuma: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_ServerNuma' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ServerNuma_N] ORDER BY [node_id];SELECT * FROM [#ServerNuma_MN] ORDER BY [memory_node_id]; END ELSE BEGIN SELECT N'numaNodes' [Ergebnis],[x].* FROM [#ServerNuma_N] [x] ORDER BY [node_id];SELECT N'memoryNodes' [Ergebnis],[x].* FROM [#ServerNuma_MN] [x] ORDER BY [memory_node_id]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ServerNuma' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#ServerNuma_N] ORDER BY [node_id] FOR JSON PATH,INCLUDE_NULL_VALUES),@J1 nvarchar(max)=(SELECT * FROM [#ServerNuma_MN] ORDER BY [memory_node_id] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"numaNodes":',COALESCE(@J0,N'[]'),N',"memoryNodes":',COALESCE(@J1,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerNuma_N'
            , @ResultLabel=N'ServerNuma'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerNuma_N'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
