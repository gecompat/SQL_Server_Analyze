USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_StartupParameters
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest SQL-Startparameter und Registry-basierte
               Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.
Datenquellen : sys.dm_server_registry
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach ein technisches Fachresultset.
               CONSOLE gibt nur die Console-Helferausgabe für startupParameters aus; TABLE schreibt ausschließlich das gemappte startupParameters-Resultset.
               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
===============================================================================
*/

-- USAGE_SKILL_BEGIN monitor.USP_StartupParameters 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_StartupParameters"
-- schema_name: "monitor"
-- object_name: "USP_StartupParameters"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin."
-- source_path: "Code/08_ServerHealth/070_USP_StartupParameters.sql"
-- ---
-- 
-- # monitor.USP_StartupParameters
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_StartupParameters] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.dm_os_host_info` und `sys.dm_server_registry` sowie Masterkataloge; Registry-/Hostsicht kann nach Plattform und Callerrechten fehlen.
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
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei @Hilfe=1 wird der Ziel-Preflight übersprungen; bei ResultSetArt TABLE läuft er im normalen Pfad.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16): CONSOLE beschriftet startupParameters, RAW liefert die technischen Zeilen und TABLE exportiert startupParameters; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden intern für reguläre Resultsets zu NONE und danach über eigene Exportzweige bedient. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. Bei einem Quellenfehler ersetzt dessen Status INVALID_PARAMETER; bei erfolgreicher Quellenprüfung bleibt INVALID_PARAMETER bestehen.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit startupParameters erforderlich, das auf eine existierende leere lokale #temp-Tabelle mit genau einer Seed-Spalte zeigt. Andernfalls wirft der Preflight im normalen Pfad Fehler 51011; Hilfe kehrt vorher zurück. Außerhalb von TABLE ist nur NULL oder leerer/nur aus Leerzeichen bestehender Inhalt zulässig.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt zusätzlich JSON, 0 erzeugt es nicht; NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. NONE unterdrückt Resultsets, nicht aber Quellenabfragen oder angefordertes JSON. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. Statuswerte: AVAILABLE; INVALID_PARAMETER; UNAVAILABLE_PLATFORM (DMV fehlt und Host ist Linux); UNAVAILABLE_OBJECT (DMV fehlt und Linux ist nicht erkannt); DENIED_PERMISSION (Fehler 229, 297, 300 oder 371); ERROR_HANDLED (sonstiger Registrylesefehler). Zuweisung erst nach Quellenprüfung, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, 1 bei invalidem Modus, nicht verfügbarer DMV oder abgefangenem Quellfehler. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer eines abgefangenen Registrylesefehlers, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Enthält Quell-/Validierungshinweis oder NULL bei AVAILABLE. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | startupParameters | 1 | 1 | [registry_key] nvarchar(512),[value_name] nvarchar(256),[value_data] nvarchar(2048),[ParameterType] varchar(40) |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_StartupParameters] @ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_StartupParameters
-- 
-- Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.
-- 
-- Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.
-- 
-- DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
-- 
-- CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt='TABLE', @ResultTablesJson=N'{"startupParameters":"#StartupParameters_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_StartupParameters
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Zweck        : Die Procedure liest SQL-Startparameter und Registry-basierte
--                Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.
-- Datenquellen : sys.dm_server_registry
-- Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach ein technisches Fachresultset.
--                CONSOLE gibt nur die Console-Helferausgabe für startupParameters aus; TABLE schreibt ausschließlich das gemappte startupParameters-Resultset.
--                CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
--                Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_StartupParameters
-- Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.
-- Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.
-- DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
-- CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt='TABLE', @ResultTablesJson=N'{"startupParameters":"#StartupParameters_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_StartupParameters
CREATE OR ALTER PROCEDURE [monitor].[USP_StartupParameters]
 @PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,@ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe=1 BEGIN PRINT N'monitor.USP_StartupParameters';
        PRINT N'Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.';
        PRINT N'Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei @Hilfe=1 wird der Ziel-Preflight übersprungen; bei ResultSetArt TABLE läuft er im normalen Pfad.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16): CONSOLE beschriftet startupParameters, RAW liefert die technischen Zeilen und TABLE exportiert startupParameters; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden intern für reguläre Resultsets zu NONE und danach über eigene Exportzweige bedient. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. Bei einem Quellenfehler ersetzt dessen Status INVALID_PARAMETER; bei erfolgreicher Quellenprüfung bleibt INVALID_PARAMETER bestehen.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit startupParameters erforderlich, das auf eine existierende leere lokale #temp-Tabelle mit genau einer Seed-Spalte zeigt. Andernfalls wirft der Preflight im normalen Pfad Fehler 51011; Hilfe kehrt vorher zurück. Außerhalb von TABLE ist nur NULL oder leerer/nur aus Leerzeichen bestehender Inhalt zulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt zusätzlich JSON, 0 erzeugt es nicht; NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. NONE unterdrückt Resultsets, nicht aber Quellenabfragen oder angefordertes JSON. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. Statuswerte: AVAILABLE; INVALID_PARAMETER; UNAVAILABLE_PLATFORM (DMV fehlt und Host ist Linux); UNAVAILABLE_OBJECT (DMV fehlt und Linux ist nicht erkannt); DENIED_PERMISSION (Fehler 229, 297, 300 oder 371); ERROR_HANDLED (sonstiger Registrylesefehler). Zuweisung erst nach Quellenprüfung, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, 1 bei invalidem Modus, nicht verfügbarer DMV oder abgefangenem Quellfehler. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer eines abgefangenen Registrylesefehlers, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Enthält Quell-/Validierungshinweis oder NULL bei AVAILABLE. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"startupParameters":"#StartupParameters_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];';
        PRINT N'EXEC [monitor].[USP_StartupParameters] @Hilfe=1;';







        -- USAGE_SKILL_HELP_BEGIN monitor.USP_StartupParameters
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_StartupParameters') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_StartupParameters"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_StartupParameters"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/070_USP_StartupParameters.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_StartupParameters'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_StartupParameters] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.dm_os_host_info` und `sys.dm_server_registry` sowie Masterkataloge; Registry-/Hostsicht kann nach Plattform und Callerrechten fehlen.'
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
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei @Hilfe=1 wird der Ziel-Preflight übersprungen; bei ResultSetArt TABLE läuft er im normalen Pfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16): CONSOLE beschriftet startupParameters, RAW liefert die technischen Zeilen und TABLE exportiert startupParameters; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden intern für reguläre Resultsets zu NONE und danach über eigene Exportzweige bedient. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. Bei einem Quellenfehler ersetzt dessen Status INVALID_PARAMETER; bei erfolgreicher Quellenprüfung bleibt INVALID_PARAMETER bestehen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit startupParameters erforderlich, das auf eine existierende leere lokale #temp-Tabelle mit genau einer Seed-Spalte zeigt. Andernfalls wirft der Preflight im normalen Pfad Fehler 51011; Hilfe kehrt vorher zurück. Außerhalb von TABLE ist nur NULL oder leerer/nur aus Leerzeichen bestehender Inhalt zulässig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt zusätzlich JSON, 0 erzeugt es nicht; NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. NONE unterdrückt Resultsets, nicht aber Quellenabfragen oder angefordertes JSON. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. Statuswerte: AVAILABLE; INVALID_PARAMETER; UNAVAILABLE_PLATFORM (DMV fehlt und Host ist Linux); UNAVAILABLE_OBJECT (DMV fehlt und Linux ist nicht erkannt); DENIED_PERMISSION (Fehler 229, 297, 300 oder 371); ERROR_HANDLED (sonstiger Registrylesefehler). Zuweisung erst nach Quellenprüfung, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, 1 bei invalidem Modus, nicht verfügbarer DMV oder abgefangenem Quellfehler. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer eines abgefangenen Registrylesefehlers, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Enthält Quell-/Validierungshinweis oder NULL bei AVAILABLE. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| startupParameters | 1 | 1 | [registry_key] nvarchar(512),[value_name] nvarchar(256),[value_data] nvarchar(2048),[ParameterType] varchar(40) |'
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
            + N'EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_StartupParameters'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;'
            + NCHAR(10)
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"startupParameters":"#StartupParameters_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];'
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
            + N'Objekt       : monitor.USP_StartupParameters'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Zweck        : Die Procedure liest SQL-Startparameter und Registry-basierte'
            + NCHAR(10)
            + N'               Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.'
            + NCHAR(10)
            + N'Datenquellen : sys.dm_server_registry'
            + NCHAR(10)
            + N'Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach ein technisches Fachresultset.'
            + NCHAR(10)
            + N'               CONSOLE gibt nur die Console-Helferausgabe für startupParameters aus; TABLE schreibt ausschließlich das gemappte startupParameters-Resultset.'
            + NCHAR(10)
            + N'               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.'
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
            + N'monitor.USP_StartupParameters'
            + NCHAR(10)
            + N'Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.'
            + NCHAR(10)
            + N'Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.'
            + NCHAR(10)
            + N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"startupParameters":"#StartupParameters_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_StartupParameters
        RETURN;END
SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'startupParameters',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL,@Platform nvarchar(60)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
CREATE TABLE [#StartupParameters_X]
(
    [registry_key] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [value_name] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [value_data] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [ParameterType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS
);
 BEGIN TRY SELECT TOP(1)@Platform=[host_platform] FROM [sys].[dm_os_host_info] WITH (NOLOCK);END TRY BEGIN CATCH END CATCH;
 IF NOT EXISTS(SELECT 1 FROM [master].[sys].[all_objects] AS [o] WITH (NOLOCK) JOIN [master].[sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] WHERE [s].[name]=N'sys' AND [o].[name]=N'dm_server_registry') SELECT @S=CASE WHEN @Platform=N'Linux'THEN'UNAVAILABLE_PLATFORM'ELSE'UNAVAILABLE_OBJECT'END,@P=1,@M=N'sys.dm_server_registry ist nicht verfügbar; Startparameter können auf dieser Plattform/Version nicht über diese Quelle gelesen werden.';
 ELSE BEGIN SET LOCK_TIMEOUT 0;BEGIN TRY INSERT [#StartupParameters_X] SELECT [registry_key],[value_name],CONVERT(nvarchar(2048),[value_data]),CASE WHEN CONVERT(nvarchar(2048),[value_data])LIKE'-T%'OR CONVERT(nvarchar(2048),[value_data])LIKE'-t%'THEN'TRACE_FLAG'WHEN CONVERT(nvarchar(2048),[value_data])LIKE'-d%'THEN'MASTER_DATA_PATH'WHEN CONVERT(nvarchar(2048),[value_data])LIKE'-l%'THEN'MASTER_LOG_PATH'WHEN CONVERT(nvarchar(2048),[value_data])LIKE'-e%'THEN'ERRORLOG_PATH'ELSE'OTHER'END FROM [sys].[dm_server_registry] WITH (NOLOCK) WHERE [value_name] LIKE'SQLArg%'OR [value_name] IN('ImagePath','ObjectName');END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE();END CATCH;END;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'RAISERROR(N'USP_StartupParameters: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_StartupParameters' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#StartupParameters_X] ORDER BY [registry_key],[value_name]; END ELSE BEGIN SELECT N'startupParameters' [Ergebnis],[x].* FROM [#StartupParameters_X] [x] ORDER BY [registry_key],[value_name]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'StartupParameters' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#StartupParameters_X] ORDER BY [registry_key],[value_name] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"startupParameters":',COALESCE(@J0,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#StartupParameters_X'
            , @ResultLabel=N'StartupParameters'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#StartupParameters_X'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
