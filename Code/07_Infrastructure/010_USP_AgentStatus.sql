USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AgentStatus
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs
Parameter    : @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe
Resultsets   : RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.
               NONE: keine Resultsets.
JSON         : meta, agentStatus.
Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte.
Eigenlast    : Gering.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Änderungen   : 2.0.0 - Einheitlicher RAW/CONSOLE/NONE- und JSON-Vertrag.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_AgentStatus 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_AgentStatus"
-- schema_name: "monitor"
-- object_name: "USP_AgentStatus"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar."
-- source_path: "Code/07_Infrastructure/010_USP_AgentStatus.sql"
-- ---
-- 
-- # monitor.USP_AgentStatus
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- SQL Server 2019 oder neuer.
-- 
-- sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs
-- 
-- Nur lesender Zugriff. Das Framework vergibt keine Rechte.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt und der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert eine beschriftete Console-Ausgabe, RAW den Modulstatus und die Rohzeile, TABLE exportiert agentStatus in das zugeordnete Ziel, NONE unterdrückt Resultsets. CONSOLE und TABLE unterdrücken zuerst direkte Resultsets und rufen anschließend ihren Ausgabeadapter auf. Andere Werte werden nach dem Hilferücksprung als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird im normalen Pfad Fehler 51011 ausgelöst; Hilfe kehrt vorher zurück. TABLE erwartet die JSON-Objektform {"agentStatus":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight des normalen Pfads Fehler 51011 aus; Hilfe kehrt vorher zurück. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta und agentStatus einschließlich NULL-Werten und einem leeren Array befüllt. SQL Server konvertiert das Argument vor Eintritt in den Prozedurcode zu bit: 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Lesefehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Agentdatensammlung zurück; sie startet, stoppt oder konfiguriert den Dienst nicht. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Die Prüfung der ResultTables-Kombination und der TABLE-Zieltabellen-Preflight laufen nur im normalen Pfad nach dem Hilfezweig und können dort Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- ## Resultate und Ausgabe
-- 
-- RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | agentStatus | 1 | 1 | [ServiceName] nvarchar(256) NULL , [StartupTypeDesc] nvarchar(60) NULL , [StatusDesc] nvarchar(60) NULL , [ProcessId] int NULL , [LastStartupTime] datetime2(3) NULL , [AgentSessionId] int NULL , [JobCount] int NULL , [EnabledJobCount] int NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_AgentStatus] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_AgentStatus
-- 
-- Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.
-- 
-- Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.
-- 
-- Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;
-- 
-- Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt='RAW', @PrintMeldungen=0;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_AgentStatus
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Typ          : Stored Procedure
-- Zweck        : Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Datenquellen : sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs
-- Parameter    : @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
--                @PrintMeldungen, @Hilfe
-- Resultsets   : RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.
--                NONE: keine Resultsets.
-- JSON         : meta, agentStatus.
-- Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte.
-- Eigenlast    : Gering.
-- Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
-- Änderungen   : 2.0.0 - Einheitlicher RAW/CONSOLE/NONE- und JSON-Vertrag.
--                1.0.0 - Erstfassung Phase 6.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_AgentStatus
-- Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.
-- Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.
-- Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;
-- Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt='RAW', @PrintMeldungen=0;
-- Beispiel 3: DECLARE @AgentStatusJson nvarchar(max); EXEC [monitor].[USP_AgentStatus] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentStatusJson OUTPUT, @PrintMeldungen=0; SELECT @AgentStatusJson AS [Json];
-- Beispiel 4: CREATE TABLE #AgentStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentStatus] @ResultSetArt='TABLE', @ResultTablesJson=N'{"agentStatus":"#AgentStatus_HelpExample"}', @PrintMeldungen=0; SELECT * FROM #AgentStatus_HelpExample; DROP TABLE #AgentStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentStatus_HelpExample; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_AgentStatus
CREATE OR ALTER PROCEDURE [monitor].[USP_AgentStatus]
      @ResultSetArt   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen   bit            = 0
    , @Json           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen bit            = 1
    , @Hilfe          bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_AgentStatus';
        PRINT N'Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.';
        PRINT N'Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt und der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert eine beschriftete Console-Ausgabe, RAW den Modulstatus und die Rohzeile, TABLE exportiert agentStatus in das zugeordnete Ziel, NONE unterdrückt Resultsets. CONSOLE und TABLE unterdrücken zuerst direkte Resultsets und rufen anschließend ihren Ausgabeadapter auf. Andere Werte werden nach dem Hilferücksprung als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird im normalen Pfad Fehler 51011 ausgelöst; Hilfe kehrt vorher zurück. TABLE erwartet die JSON-Objektform {"agentStatus":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight des normalen Pfads Fehler 51011 aus; Hilfe kehrt vorher zurück. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta und agentStatus einschließlich NULL-Werten und einem leeren Array befüllt. SQL Server konvertiert das Argument vor Eintritt in den Prozedurcode zu bit: 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Lesefehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Agentdatensammlung zurück; sie startet, stoppt oder konfiguriert den Dienst nicht. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Die Prüfung der ResultTables-Kombination und der TABLE-Zieltabellen-Preflight laufen nur im normalen Pfad nach dem Hilfezweig und können dort Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @AgentStatusJson nvarchar(max); EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentStatusJson OUTPUT, @PrintMeldungen=0; SELECT @AgentStatusJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #AgentStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"agentStatus":"#AgentStatus_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM #AgentStatus_HelpExample; DROP TABLE #AgentStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentStatus_HelpExample; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_AgentStatus
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_AgentStatus') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_AgentStatus"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_AgentStatus"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar."'
            + NCHAR(10)
            + N'source_path: "Code/07_Infrastructure/010_USP_AgentStatus.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_AgentStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nur lesender Zugriff. Das Framework vergibt keine Rechte.'
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
            + N'**@ResultSetArt:** @ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt und der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert eine beschriftete Console-Ausgabe, RAW den Modulstatus und die Rohzeile, TABLE exportiert agentStatus in das zugeordnete Ziel, NONE unterdrückt Resultsets. CONSOLE und TABLE unterdrücken zuerst direkte Resultsets und rufen anschließend ihren Ausgabeadapter auf. Andere Werte werden nach dem Hilferücksprung als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird im normalen Pfad Fehler 51011 ausgelöst; Hilfe kehrt vorher zurück. TABLE erwartet die JSON-Objektform {"agentStatus":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight des normalen Pfads Fehler 51011 aus; Hilfe kehrt vorher zurück. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta und agentStatus einschließlich NULL-Werten und einem leeren Array befüllt. SQL Server konvertiert das Argument vor Eintritt in den Prozedurcode zu bit: 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Lesefehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Agentdatensammlung zurück; sie startet, stoppt oder konfiguriert den Dienst nicht. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Die Prüfung der ResultTables-Kombination und der TABLE-Zieltabellen-Preflight laufen nur im normalen Pfad nach dem Hilfezweig und können dort Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| agentStatus | 1 | 1 | [ServiceName] nvarchar(256) NULL , [StartupTypeDesc] nvarchar(60) NULL , [StatusDesc] nvarchar(60) NULL , [ProcessId] int NULL , [LastStartupTime] datetime2(3) NULL , [AgentSessionId] int NULL , [JobCount] int NULL , [EnabledJobCount] int NULL |'
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
            + N'EXEC [monitor].[USP_AgentStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_AgentStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''RAW'', @PrintMeldungen=0;'
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
            + N'Objekt       : monitor.USP_AgentStatus'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Datenquellen : sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs'
            + NCHAR(10)
            + N'Parameter    : @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,'
            + NCHAR(10)
            + N'               @PrintMeldungen, @Hilfe'
            + NCHAR(10)
            + N'Resultsets   : RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.'
            + NCHAR(10)
            + N'               NONE: keine Resultsets.'
            + NCHAR(10)
            + N'JSON         : meta, agentStatus.'
            + NCHAR(10)
            + N'Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte.'
            + NCHAR(10)
            + N'Eigenlast    : Gering.'
            + NCHAR(10)
            + N'Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.'
            + NCHAR(10)
            + N'Änderungen   : 2.0.0 - Einheitlicher RAW/CONSOLE/NONE- und JSON-Vertrag.'
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
            + N'monitor.USP_AgentStatus'
            + NCHAR(10)
            + N'Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.'
            + NCHAR(10)
            + N'Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.'
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''RAW'', @PrintMeldungen=0;'
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @AgentStatusJson nvarchar(max); EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentStatusJson OUTPUT, @PrintMeldungen=0; SELECT @AgentStatusJson AS [Json];'
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #AgentStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"agentStatus":"#AgentStatus_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM #AgentStatus_HelpExample; DROP TABLE #AgentStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentStatus_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_AgentStatus
        RETURN;
    END


    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'agentStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';

    ;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#AgentStatus_AgentStatus]
    (
          [ServiceName]        nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartupTypeDesc]    nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [StatusDesc]         nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [ProcessId]          int           NULL
        , [LastStartupTime]    datetime2(3)  NULL
        , [AgentSessionId]     int           NULL
        , [JobCount]           int           NULL
        , [EnabledJobCount]    int           NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @IsPartial = 1;
        SET @ErrorMessage = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#AgentStatus_AgentStatus]
        (
              [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
            , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
        )
        SELECT TOP (1)
              [s].[servicename]
            , [s].[startup_type_desc]
            , [s].[status_desc]
            , [s].[process_id]
            , (SELECT MAX([agent_start_date]) FROM [msdb].[dbo].[syssessions] WITH (NOLOCK))
            , (SELECT MAX([session_id]) FROM [msdb].[dbo].[syssessions] WITH (NOLOCK))
            , (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WITH (NOLOCK))
            , (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WITH (NOLOCK) WHERE [enabled] = 1)
        FROM [sys].[dm_server_services] AS [s] WITH (NOLOCK)
        WHERE [s].[servicename] LIKE N'SQL Server Agent%'
        ORDER BY [s].[servicename];

        IF NOT EXISTS (SELECT 1 FROM [#AgentStatus_AgentStatus])
        BEGIN
            SET @StatusCode = 'UNAVAILABLE_FEATURE';
            SET @IsPartial = 1;
            SET @ErrorMessage = N'Kein sichtbarer SQL-Server-Agent-Dienst gefunden.';
        END;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'ERROR_HANDLED'
            , @IsPartial = 1
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();

        IF @PrintMeldungen = 1
            RAISERROR(N'Agentstatus konnte nicht vollständig gelesen werden: %s', 10, 1, @ErrorMessage) WITH NOWAIT;
    END CATCH;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_AgentStatus' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT
                  [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
                , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
            FROM [#AgentStatus_AgentStatus];
        END;
        ELSE
        BEGIN
            SELECT
                  N'SQL Server Agent' AS [Ergebnis]
                , [ServiceName] AS [Dienst]
                , [StartupTypeDesc] AS [Starttyp]
                , [StatusDesc] AS [Dienststatus]
                , [ProcessId] AS [Prozess-ID]
                , [LastStartupTime] AS [Letzter Agent-Start]
                , [AgentSessionId] AS [Agent-Session]
                , [JobCount] AS [Jobs gesamt]
                , [EnabledJobCount] AS [Aktive Jobs]
            FROM [#AgentStatus_AgentStatus];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'AgentStatus' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        DECLARE @DataJson nvarchar(max) =
        (
            SELECT
                  [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
                , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
            FROM [#AgentStatus_AgentStatus]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"agentStatus":', COALESCE(@DataJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#AgentStatus_AgentStatus'
            , @ResultLabel=N'AgentStatus'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AgentStatus_AgentStatus'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
