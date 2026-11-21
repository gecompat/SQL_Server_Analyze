USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ReplicationStatus
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten
Parameter    : @MitDistributionDetails, @MaxZeilen, @HighImpactConfirmed,
               @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe
Resultsets   : 1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.
Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
               Framework vergibt keine Rechte und ändert keine Konfiguration.
Eigenlast    : Mittel; optionale Distribution-DB-Auswertung.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Partial      : Fehlende Features, Objekte oder Rechte werden strukturiert als
               Partial Result behandelt; andere Module bleiben ausführbar.
Änderungen   : 1.1.0 - Negative @MaxZeilen-Werte werden vor Rechte- und
               Datenzugriffen strukturiert abgewiesen.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_ReplicationStatus 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_ReplicationStatus"
-- schema_name: "monitor"
-- object_name: "USP_ReplicationStatus"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler."
-- source_path: "Code/07_Infrastructure/070_USP_ReplicationStatus.sql"
-- ---
-- 
-- # monitor.USP_ReplicationStatus
-- 
-- ## Zweck und Einsatz
-- 
-- Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- SQL Server 2019 oder neuer.
-- 
-- sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten
-- 
-- Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @MitDistributionDetails | bit | nein | 0 |
-- | @MaxZeilen | int | nein | 5000 |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@MitDistributionDetails:** @MitDistributionDetails bit; Default: 0. Default 0. 0 liest nur sichtbare Replikationsrollen; 1 aktiviert Details aus der online erkannten lokalen Distribution-Datenbank (Publikationen, Subscriptions samt letzter Agent-Historyzeile, Fehler). Fehlt sie, entsteht ein Partialstatus bzw. ohne Basiszeilen UNAVAILABLE_FEATURE. NULL wird nicht geprüft und aktiviert den Pfad nicht. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 5000. Default 5000 je Datenbank-, Publikations-, Subscription- und Fehlerresultset getrennt, ohne gemeinsames Gesamtbudget. Positive Werte begrenzen je Menge; 0 oder NULL bedeutet unbegrenzt. Negative Werte setzen INVALID_PARAMETER/Partial und verhindern die Facherhebung, sofern kein früherer Gate-Status den Status bereits geändert hat. Bei @Hilfe=1 wird der Wert nicht validiert, weil die Hilfe vorher zurückkehrt. Die Grenze verhindert nicht die Latest-History-Auflösung je Subscription. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Nur bei MitDistributionDetails=1 prüft die Procedure die Klasse ENTERPRISE_TOPOLOGY_DEEP. Der gebundene Wert 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED. Nach Bestätigung mit 1 kann die aktuelle Zugriffspolicy DENIED_GROUP ergeben. Der Detailpfad setzt Bestätigung und aktuelle Berechtigung voraus. NULL ergibt bei aktiviertem Detailpfad INVALID_PARAMETER. Bei deaktiviertem Detailpfad wird der Wert nicht geprüft. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE (nur Datenbankrollenansicht über Console-Helper), RAW (Modulstatus plus vier Fachergebnissets), TABLE (nur databases in Zieltemp-Tabelle) und NONE (keine Resultsets). NULL/Leerwert/anderer Wert ergibt INVALID_PARAMETER. CONSOLE und TABLE unterdrücken den normalen Status-/RAW-Pfad. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Default NULL. Nur mit TABLE zulässig; sonst wird nichtleeres JSON mit Fehler 51011 abgewiesen. Erwartet ein Objekt mit einzigem Resultnamen databases und Ziel als Wert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, maximal 116 Zeichen und genau eine Seed-Spalte. NULL/leeres JSON ist ungültig. Der Preflight läuft vor HELP und Fachdatenzugriff. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Default 0. 1 erzeugt zusätzlich JSON in Json mit meta, databases, publications, subscriptions und errors; 0 nicht. JSON-Erzeugung ist unabhängig von ResultSetArt. NULL aktiviert den IF-Zweig nicht. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, Default NULL. Wird am Anfang auf NULL gesetzt und bei JsonErzeugen=1 mit dem JSON-Objekt aus meta und vier Ergebnisarrays gebunden. Andernfalls bleibt NULL. Der Aufrufer bindet eine nvarchar(max)-OUTPUT-Variable. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Default 1. Bei 1 wird eine behandelte Catch-Fehlermeldung mit Severity 10 ausgegeben; 0 unterdrückt sie. NULL wirkt nicht wie 1. Steuert keine Resultsets. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. Default 0. 1 druckt kurze Hilfe und kehrt zurück, 0 fährt fort; NULL wirkt wie 0. TABLE-Kombinationsprüfung und Preflight laufen vor der Hilfeprüfung. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- ## Resultate und Ausgabe
-- 
-- 1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | databases | 1 | 1 | [DatabaseName] sysname,[IsPublished] bit,[IsSubscribed] bit,[IsMergePublished] bit,[IsDistributor] bit |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_ReplicationStatus
-- 
-- Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;
-- 
-- Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt='RAW';
-- 
-- Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];
-- 
-- Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#ReplicationStatus_HelpExample"}'; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_ReplicationStatus
-- Version      : 1.1.0
-- Stand        : 2026-07-14
-- Typ          : Stored Procedure
-- Zweck        : Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Datenquellen : sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten
-- Parameter    : @MitDistributionDetails, @MaxZeilen, @HighImpactConfirmed,
--                @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
--                @PrintMeldungen, @Hilfe
-- Resultsets   : 1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.
-- Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
--                Framework vergibt keine Rechte und ändert keine Konfiguration.
-- Eigenlast    : Mittel; optionale Distribution-DB-Auswertung.
-- Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
-- Partial      : Fehlende Features, Objekte oder Rechte werden strukturiert als
--                Partial Result behandelt; andere Module bleiben ausführbar.
-- Änderungen   : 1.1.0 - Negative @MaxZeilen-Werte werden vor Rechte- und
--                Datenzugriffen strukturiert abgewiesen.
--                1.0.0 - Erstfassung Phase 6.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_ReplicationStatus
-- Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;
-- Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt='RAW';
-- Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];
-- Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#ReplicationStatus_HelpExample"}'; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_ReplicationStatus
CREATE OR ALTER PROCEDURE [monitor].[USP_ReplicationStatus]
 @MitDistributionDetails bit=0,@MaxZeilen int=5000,@HighImpactConfirmed bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,@PrintMeldungen bit=1,@Hilfe bit=0
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_ReplicationStatus';
        PRINT N'@MitDistributionDetails bit; Default: 0. Default 0. 0 liest nur sichtbare Replikationsrollen; 1 aktiviert Details aus der online erkannten lokalen Distribution-Datenbank (Publikationen, Subscriptions samt letzter Agent-Historyzeile, Fehler). Fehlt sie, entsteht ein Partialstatus bzw. ohne Basiszeilen UNAVAILABLE_FEATURE. NULL wird nicht geprüft und aktiviert den Pfad nicht. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int; Default: 5000. Default 5000 je Datenbank-, Publikations-, Subscription- und Fehlerresultset getrennt, ohne gemeinsames Gesamtbudget. Positive Werte begrenzen je Menge; 0 oder NULL bedeutet unbegrenzt. Negative Werte setzen INVALID_PARAMETER/Partial und verhindern die Facherhebung, sofern kein früherer Gate-Status den Status bereits geändert hat. Bei @Hilfe=1 wird der Wert nicht validiert, weil die Hilfe vorher zurückkehrt. Die Grenze verhindert nicht die Latest-History-Auflösung je Subscription. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Nur bei MitDistributionDetails=1 prüft die Procedure die Klasse ENTERPRISE_TOPOLOGY_DEEP. Der gebundene Wert 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED. Nach Bestätigung mit 1 kann die aktuelle Zugriffspolicy DENIED_GROUP ergeben. Der Detailpfad setzt Bestätigung und aktuelle Berechtigung voraus. NULL ergibt bei aktiviertem Detailpfad INVALID_PARAMETER. Bei deaktiviertem Detailpfad wird der Wert nicht geprüft. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE (nur Datenbankrollenansicht über Console-Helper), RAW (Modulstatus plus vier Fachergebnissets), TABLE (nur databases in Zieltemp-Tabelle) und NONE (keine Resultsets). NULL/Leerwert/anderer Wert ergibt INVALID_PARAMETER. CONSOLE und TABLE unterdrücken den normalen Status-/RAW-Pfad. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Default NULL. Nur mit TABLE zulässig; sonst wird nichtleeres JSON mit Fehler 51011 abgewiesen. Erwartet ein Objekt mit einzigem Resultnamen databases und Ziel als Wert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, maximal 116 Zeichen und genau eine Seed-Spalte. NULL/leeres JSON ist ungültig. Der Preflight läuft vor HELP und Fachdatenzugriff. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit; Default: 0. Default 0. 1 erzeugt zusätzlich JSON in Json mit meta, databases, publications, subscriptions und errors; 0 nicht. JSON-Erzeugung ist unabhängig von ResultSetArt. NULL aktiviert den IF-Zweig nicht. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, Default NULL. Wird am Anfang auf NULL gesetzt und bei JsonErzeugen=1 mit dem JSON-Objekt aus meta und vier Ergebnisarrays gebunden. Andernfalls bleibt NULL. Der Aufrufer bindet eine nvarchar(max)-OUTPUT-Variable. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.';
        PRINT N'@PrintMeldungen bit; Default: 1. Default 1. Bei 1 wird eine behandelte Catch-Fehlermeldung mit Severity 10 ausgegeben; 0 unterdrückt sie. NULL wirkt nicht wie 1. Steuert keine Resultsets. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit; Default: 0. Default 0. 1 druckt kurze Hilfe und kehrt zurück, 0 fährt fort; NULL wirkt wie 0. TABLE-Kombinationsprüfung und Preflight laufen vor der Hilfeprüfung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databases":"#ReplicationStatus_HelpExample"}''; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_ReplicationStatus
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_ReplicationStatus') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_ReplicationStatus"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_ReplicationStatus"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler."'
            + NCHAR(10)
            + N'source_path: "Code/07_Infrastructure/070_USP_ReplicationStatus.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_ReplicationStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.'
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
            + N'| @MitDistributionDetails | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 5000 |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
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
            + N'**@MitDistributionDetails:** @MitDistributionDetails bit; Default: 0. Default 0. 0 liest nur sichtbare Replikationsrollen; 1 aktiviert Details aus der online erkannten lokalen Distribution-Datenbank (Publikationen, Subscriptions samt letzter Agent-Historyzeile, Fehler). Fehlt sie, entsteht ein Partialstatus bzw. ohne Basiszeilen UNAVAILABLE_FEATURE. NULL wird nicht geprüft und aktiviert den Pfad nicht. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 5000. Default 5000 je Datenbank-, Publikations-, Subscription- und Fehlerresultset getrennt, ohne gemeinsames Gesamtbudget. Positive Werte begrenzen je Menge; 0 oder NULL bedeutet unbegrenzt. Negative Werte setzen INVALID_PARAMETER/Partial und verhindern die Facherhebung, sofern kein früherer Gate-Status den Status bereits geändert hat. Bei @Hilfe=1 wird der Wert nicht validiert, weil die Hilfe vorher zurückkehrt. Die Grenze verhindert nicht die Latest-History-Auflösung je Subscription. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Nur bei MitDistributionDetails=1 prüft die Procedure die Klasse ENTERPRISE_TOPOLOGY_DEEP. Der gebundene Wert 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED. Nach Bestätigung mit 1 kann die aktuelle Zugriffspolicy DENIED_GROUP ergeben. Der Detailpfad setzt Bestätigung und aktuelle Berechtigung voraus. NULL ergibt bei aktiviertem Detailpfad INVALID_PARAMETER. Bei deaktiviertem Detailpfad wird der Wert nicht geprüft. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE (nur Datenbankrollenansicht über Console-Helper), RAW (Modulstatus plus vier Fachergebnissets), TABLE (nur databases in Zieltemp-Tabelle) und NONE (keine Resultsets). NULL/Leerwert/anderer Wert ergibt INVALID_PARAMETER. CONSOLE und TABLE unterdrücken den normalen Status-/RAW-Pfad. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Default NULL. Nur mit TABLE zulässig; sonst wird nichtleeres JSON mit Fehler 51011 abgewiesen. Erwartet ein Objekt mit einzigem Resultnamen databases und Ziel als Wert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, maximal 116 Zeichen und genau eine Seed-Spalte. NULL/leeres JSON ist ungültig. Der Preflight läuft vor HELP und Fachdatenzugriff. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Default 0. 1 erzeugt zusätzlich JSON in Json mit meta, databases, publications, subscriptions und errors; 0 nicht. JSON-Erzeugung ist unabhängig von ResultSetArt. NULL aktiviert den IF-Zweig nicht. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, Default NULL. Wird am Anfang auf NULL gesetzt und bei JsonErzeugen=1 mit dem JSON-Objekt aus meta und vier Ergebnisarrays gebunden. Andernfalls bleibt NULL. Der Aufrufer bindet eine nvarchar(max)-OUTPUT-Variable. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Default 1. Bei 1 wird eine behandelte Catch-Fehlermeldung mit Severity 10 ausgegeben; 0 unterdrückt sie. NULL wirkt nicht wie 1. Steuert keine Resultsets. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. Default 0. 1 druckt kurze Hilfe und kehrt zurück, 0 fährt fort; NULL wirkt wie 0. TABLE-Kombinationsprüfung und Preflight laufen vor der Hilfeprüfung. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| databases | 1 | 1 | [DatabaseName] sysname,[IsPublished] bit,[IsSubscribed] bit,[IsMergePublished] bit,[IsDistributor] bit |'
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
            + N'EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_ReplicationStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databases":"#ReplicationStatus_HelpExample"}''; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;'
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
            + N'Objekt       : monitor.USP_ReplicationStatus'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-14'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Datenquellen : sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten'
            + NCHAR(10)
            + N'Parameter    : @MitDistributionDetails, @MaxZeilen, @HighImpactConfirmed,'
            + NCHAR(10)
            + N'               @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,'
            + NCHAR(10)
            + N'               @PrintMeldungen, @Hilfe'
            + NCHAR(10)
            + N'Resultsets   : 1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.'
            + NCHAR(10)
            + N'Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das'
            + NCHAR(10)
            + N'               Framework vergibt keine Rechte und ändert keine Konfiguration.'
            + NCHAR(10)
            + N'Eigenlast    : Mittel; optionale Distribution-DB-Auswertung.'
            + NCHAR(10)
            + N'Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.'
            + NCHAR(10)
            + N'Partial      : Fehlende Features, Objekte oder Rechte werden strukturiert als'
            + NCHAR(10)
            + N'               Partial Result behandelt; andere Module bleiben ausführbar.'
            + NCHAR(10)
            + N'Änderungen   : 1.1.0 - Negative @MaxZeilen-Werte werden vor Rechte- und'
            + NCHAR(10)
            + N'               Datenzugriffen strukturiert abgewiesen.'
            + NCHAR(10)
            + N'               1.0.0 - Erstfassung Phase 6.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_ReplicationStatus'
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];'
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databases":"#ReplicationStatus_HelpExample"}''; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_ReplicationStatus
        RETURN;
    END

 SET @Json=NULL;
 DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'databases',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    ;
 DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@DistDb sysname=NULL,@sql nvarchar(max),@Allowed bit=1;
 IF @MaxZeilen<0 SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@MaxZeilen darf nicht negativ sein; NULL/0 bedeutet unbegrenzt.';
 CREATE TABLE [#ReplicationStatus_Db]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[IsPublished] bit,[IsSubscribed] bit,[IsMergePublished] bit,[IsDistributor] bit);
 CREATE TABLE [#ReplicationStatus_Pub]([PublicationId] int,[PublisherDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PublicationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PublicationType] int,[ImmediateSync] bit,[AllowPush] bit,[AllowPull] bit,[Status] int);
 CREATE TABLE [#ReplicationStatus_Sub]([PublisherDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PublicationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SubscriberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SubscriberDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SubscriptionType] int,[Status] int,[AgentId] int,[LastAction] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastTimestamp] datetime);
 CREATE TABLE [#ReplicationStatus_Err]([ErrorId] int,[ErrorTime] datetime,[SourceName] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorCode] int,[ErrorText] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
 IF @StatusCode='AVAILABLE' AND @MitDistributionDetails=1 EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='ENTERPRISE_TOPOLOGY_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;
 IF @ResultSetArtNormalisiert NOT IN ('RAW','CONSOLE','NONE') SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 SET LOCK_TIMEOUT 0;
 IF @StatusCode='AVAILABLE' BEGIN TRY
  INSERT [#ReplicationStatus_Db] SELECT TOP (@EffectiveMaxZeilen) [name],[is_published],[is_subscribed],[is_merge_published],[is_distributor] FROM [sys].[databases] WITH (NOLOCK) WHERE [is_published]=1 OR [is_subscribed]=1 OR [is_merge_published]=1 OR [is_distributor]=1 ORDER BY [name];
  IF @MitDistributionDetails=1
  BEGIN
   SELECT TOP(1) @DistDb=[name] FROM [sys].[databases] WITH (NOLOCK) WHERE [is_distributor]=1 AND [state]=0;
   IF @DistDb IS NULL BEGIN SET @IsPartial=1; IF NOT EXISTS(SELECT 1 FROM [#ReplicationStatus_Db]) SET @StatusCode='UNAVAILABLE_FEATURE'; SET @ErrorMessage=N'Keine online sichtbare Distribution-Datenbank gefunden.'; END
   ELSE BEGIN
    SET @sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(@DistDb)+N'.[sys].[tables] AS [t] WITH (NOLOCK) JOIN '+QUOTENAME(@DistDb)+N'.[sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[schema_id]=[t].[schema_id] WHERE [sc].[name]=N''dbo'' AND [t].[name]=N''MSpublications'') INSERT [#ReplicationStatus_Pub] ([PublicationId],[PublisherDatabase],[PublicationName],[PublicationType],[ImmediateSync],[AllowPush],[AllowPull],[Status]) SELECT TOP (@EffectiveMaxZeilen) [publication_id],[publisher_db],[publication],[publication_type],[immediate_sync],[allow_push],[allow_pull],[status] FROM '+QUOTENAME(@DistDb)+N'.[dbo].[MSpublications] WITH (NOLOCK) ORDER BY [publisher_db],[publication];';
    EXEC [sys].[sp_executesql] @sql,N'@EffectiveMaxZeilen bigint',@EffectiveMaxZeilen=@EffectiveMaxZeilen;
    SET @sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(@DistDb)+N'.[sys].[tables] AS [t] WITH (NOLOCK) JOIN '+QUOTENAME(@DistDb)+N'.[sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[schema_id]=[t].[schema_id] WHERE [sc].[name]=N''dbo'' AND [t].[name]=N''MSsubscriptions'') INSERT [#ReplicationStatus_Sub] ([PublisherDatabase],[PublicationName],[SubscriberName],[SubscriberDatabase],[SubscriptionType],[Status],[AgentId],[LastAction],[LastTimestamp]) SELECT TOP (@EffectiveMaxZeilen) [s].[publisher_db],[p].[publication],[a].[subscriber_name],[s].[subscriber_db],[s].[subscription_type],[s].[status],[s].[agent_id],[h].[comments],[h].[time] FROM '+QUOTENAME(@DistDb)+N'.[dbo].[MSsubscriptions] AS [s] WITH (NOLOCK) LEFT JOIN '+QUOTENAME(@DistDb)+N'.[dbo].[MSpublications] AS [p] WITH (NOLOCK) ON [p].[publication_id]=[s].[publication_id] LEFT JOIN '+QUOTENAME(@DistDb)+N'.[dbo].[MSdistribution_agents] AS [a] WITH (NOLOCK) ON [a].[id]=[s].[agent_id] OUTER APPLY (SELECT TOP (1) [dh].[comments],[dh].[time] FROM '+QUOTENAME(@DistDb)+N'.[dbo].[MSdistribution_history] AS [dh] WITH (NOLOCK) WHERE [dh].[agent_id]=[s].[agent_id] ORDER BY [dh].[time] DESC) AS [h] ORDER BY [s].[publisher_db],[p].[publication];';
    EXEC [sys].[sp_executesql] @sql,N'@EffectiveMaxZeilen bigint',@EffectiveMaxZeilen=@EffectiveMaxZeilen;
    SET @sql=N'IF EXISTS(SELECT 1 FROM '+QUOTENAME(@DistDb)+N'.[sys].[tables] AS [t] WITH (NOLOCK) JOIN '+QUOTENAME(@DistDb)+N'.[sys].[schemas] AS [sc] WITH (NOLOCK) ON [sc].[schema_id]=[t].[schema_id] WHERE [sc].[name]=N''dbo'' AND [t].[name]=N''MSrepl_errors'') INSERT [#ReplicationStatus_Err] ([ErrorId],[ErrorTime],[SourceName],[ErrorCode],[ErrorText]) SELECT TOP (@EffectiveMaxZeilen) [id],[time],[source_name],[error_code],[error_text] FROM '+QUOTENAME(@DistDb)+N'.[dbo].[MSrepl_errors] WITH (NOLOCK) ORDER BY [time] DESC;';
    EXEC [sys].[sp_executesql] @sql,N'@EffectiveMaxZeilen bigint',@EffectiveMaxZeilen=@EffectiveMaxZeilen;
   END
  END
 END TRY BEGIN CATCH SELECT @StatusCode='ERROR_HANDLED',@IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(); IF @PrintMeldungen=1 RAISERROR(N'Replication konnte nicht vollständig gelesen werden: %s',10,1,@ErrorMessage) WITH NOWAIT; END CATCH;

 IF @ResultSetArtNormalisiert<>'NONE'
 BEGIN
  SELECT @CollectionTimeUtc AS [CollectionTimeUtc],CAST(N'monitor.USP_ReplicationStatus' AS nvarchar(256)) AS [ModuleName],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage];
  IF @ResultSetArtNormalisiert='RAW'
  BEGIN SELECT * FROM [#ReplicationStatus_Db] ORDER BY [DatabaseName];SELECT * FROM [#ReplicationStatus_Pub] ORDER BY [PublisherDatabase],[PublicationName];SELECT * FROM [#ReplicationStatus_Sub] ORDER BY [PublisherDatabase],[PublicationName];SELECT * FROM [#ReplicationStatus_Err] ORDER BY [ErrorTime] DESC;END
  ELSE
  BEGIN SELECT N'Replikations-Datenbank' [Ergebnis],[x].* FROM [#ReplicationStatus_Db] [x] ORDER BY [DatabaseName];SELECT N'Replikations-Publikation' [Ergebnis],[x].* FROM [#ReplicationStatus_Pub] [x] ORDER BY [PublisherDatabase],[PublicationName];SELECT N'Replikations-Subscription' [Ergebnis],[x].* FROM [#ReplicationStatus_Sub] [x] ORDER BY [PublisherDatabase],[PublicationName];SELECT N'Replikationsfehler' [Ergebnis],[x].* FROM [#ReplicationStatus_Err] [x] ORDER BY [ErrorTime] DESC;END
 END;
 IF @JsonErzeugen=1
 BEGIN
  DECLARE @MetaJson nvarchar(max)=(SELECT N'ReplicationStatus' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
  DECLARE @DbJson nvarchar(max)=(SELECT * FROM [#ReplicationStatus_Db] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES),@PubJson nvarchar(max)=(SELECT * FROM [#ReplicationStatus_Pub] ORDER BY [PublisherDatabase],[PublicationName] FOR JSON PATH,INCLUDE_NULL_VALUES),@SubJson nvarchar(max)=(SELECT * FROM [#ReplicationStatus_Sub] ORDER BY [PublisherDatabase],[PublicationName] FOR JSON PATH,INCLUDE_NULL_VALUES),@ErrJson nvarchar(max)=(SELECT * FROM [#ReplicationStatus_Err] ORDER BY [ErrorTime] DESC FOR JSON PATH,INCLUDE_NULL_VALUES);
  SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"databases":',COALESCE(@DbJson,N'[]'),N',"publications":',COALESCE(@PubJson,N'[]'),N',"subscriptions":',COALESCE(@SubJson,N'[]'),N',"errors":',COALESCE(@ErrJson,N'[]'),N'}');
 END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ReplicationStatus_Db'
            , @ResultLabel=N'ReplicationStatus'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ReplicationStatus_Db'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
