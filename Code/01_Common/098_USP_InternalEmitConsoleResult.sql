USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalEmitConsoleResult
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
               eine beschriftete Fachansicht. Leere Quellen liefern genau eine
               verständliche Console-Zeile; RAW und TABLE verwenden den Helper
               nicht und erhalten deshalb keine künstlichen Datenzeilen.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
@ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
@EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].
@StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.
@StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten.
Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalEmitConsoleResult 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalEmitConsoleResult"
-- schema_name: "monitor"
-- object_name: "InternalEmitConsoleResult"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle."
-- source_path: "Code/01_Common/098_USP_InternalEmitConsoleResult.sql"
-- ---
-- 
-- # monitor.InternalEmitConsoleResult
-- 
-- ## Zweck und Einsatz
-- 
-- Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitConsoleResult]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SourceTable | sysname | ja | kein Default |
-- | @ResultLabel | nvarchar(200) | ja | kein Default |
-- | @EmptyMessage | nvarchar(200) | ja | kein Default |
-- | @StatusCode | varchar(40) | nein | NULL |
-- | @StatusMessage | nvarchar(2048) | nein | NULL |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
-- 
-- **@ResultLabel:** @ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
-- 
-- **@EmptyMessage:** @EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].
-- 
-- **@StatusCode:** @StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.
-- 
-- **@StatusMessage:** @StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten. Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau ein CONSOLE-Resultset. Bei nichtleerer lokaler Quelle stehen `[Ergebnis] nvarchar(200)` und anschließend alle Spalten von `@SourceTable` in deren Quellschema; die Procedure fügt keine Sortierung und keine Zeilenkappung hinzu. Bei leerer Quelle entsteht genau eine Zeile mit `[Ergebnis] nvarchar(200)`, `[Status] varchar(40)` und `[Hinweis] nvarchar(2048)` aus den Argumenten. Es gibt keine OUTPUT-Parameter.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalEmitConsoleResult';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=NULL, @ResultLabel=NULL, @EmptyMessage=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- ===============================================================================
-- Objekt       : monitor.InternalEmitConsoleResult
-- Version      : 1.0.0
-- Stand        : 2026-07-20
-- Typ          : Interne Stored Procedure
-- Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
--                bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
-- Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
--                eine beschriftete Fachansicht. Leere Quellen liefern genau eine
--                verständliche Console-Zeile; RAW und TABLE verwenden den Helper
--                nicht und erhalten deshalb keine künstlichen Datenzeilen.
-- Parameterverträge:
-- @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
-- @ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
-- @EmptyMessage nvar
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalEmitConsoleResult
-- Version      : 1.0.0
-- Stand        : 2026-07-20
-- Typ          : Interne Stored Procedure
-- Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
--                bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
-- Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
--                eine beschriftete Fachansicht. Leere Quellen liefern genau eine
--                verständliche Console-Zeile; RAW und TABLE verwenden den Helper
--                nicht und erhalten deshalb keine künstlichen Datenzeilen.
-- Parameterverträge:
-- @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
-- @ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
-- @EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].
-- @StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.
-- @StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten.
-- Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalEmitConsoleResult
CREATE OR ALTER PROCEDURE [monitor].[InternalEmitConsoleResult]
      @SourceTable    sysname
    , @ResultLabel    nvarchar(200)
    , @EmptyMessage   nvarchar(200)
    , @StatusCode     varchar(40)    = NULL
    , @StatusMessage  nvarchar(2048) = NULL
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalEmitConsoleResult
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalEmitConsoleResult') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalEmitConsoleResult"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalEmitConsoleResult"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/098_USP_InternalEmitConsoleResult.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalEmitConsoleResult'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitConsoleResult]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @SourceTable | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @ResultLabel | nvarchar(200) | ja | kein Default |'
            + NCHAR(10)
            + N'| @EmptyMessage | nvarchar(200) | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) | nein | NULL |'
            + NCHAR(10)
            + N'| @StatusMessage | nvarchar(2048) | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultLabel:** @ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@EmptyMessage:** @EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** @StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusMessage:** @StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten. Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Genau ein CONSOLE-Resultset. Bei nichtleerer lokaler Quelle stehen `[Ergebnis] nvarchar(200)` und anschließend alle Spalten von `@SourceTable` in deren Quellschema; die Procedure fügt keine Sortierung und keine Zeilenkappung hinzu. Bei leerer Quelle entsteht genau eine Zeile mit `[Ergebnis] nvarchar(200)`, `[Status] varchar(40)` und `[Hinweis] nvarchar(2048)` aus den Argumenten. Es gibt keine OUTPUT-Parameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalEmitConsoleResult'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=NULL, @ResultLabel=NULL, @EmptyMessage=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + N'Objekt       : monitor.InternalEmitConsoleResult'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-20'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer'
            + NCHAR(10)
            + N'               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.'
            + NCHAR(10)
            + N'Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern'
            + NCHAR(10)
            + N'               eine beschriftete Fachansicht. Leere Quellen liefern genau eine'
            + NCHAR(10)
            + N'               verständliche Console-Zeile; RAW und TABLE verwenden den Helper'
            + NCHAR(10)
            + N'               nicht und erhalten deshalb keine künstlichen Datenzeilen.'
            + NCHAR(10)
            + N'Parameterverträge:'
            + NCHAR(10)
            + N'@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.'
            + NCHAR(10)
            + N'@ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].'
            + NCHAR(10)
            + N'@EmptyMessage nvar'
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
            + N'Objekt       : monitor.InternalEmitConsoleResult'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-20'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer'
            + NCHAR(10)
            + N'               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.'
            + NCHAR(10)
            + N'Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern'
            + NCHAR(10)
            + N'               eine beschriftete Fachansicht. Leere Quellen liefern genau eine'
            + NCHAR(10)
            + N'               verständliche Console-Zeile; RAW und TABLE verwenden den Helper'
            + NCHAR(10)
            + N'               nicht und erhalten deshalb keine künstlichen Datenzeilen.'
            + NCHAR(10)
            + N'Parameterverträge:'
            + NCHAR(10)
            + N'@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.'
            + NCHAR(10)
            + N'@ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].'
            + NCHAR(10)
            + N'@EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].'
            + NCHAR(10)
            + N'@StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.'
            + NCHAR(10)
            + N'@StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten.'
            + NCHAR(10)
            + N'Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalEmitConsoleResult
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    IF @SourceTable IS NULL
       OR LEFT(@SourceTable,1)<>N'#'
       OR LEFT(@SourceTable,2)=N'##'
       OR LEN(@SourceTable)>116
        THROW 51012,N'@SourceTable muss eine lokale #Temp-Tabelle des Aufrufers bezeichnen.',1;

    SET @ResultLabel=COALESCE(NULLIF(LTRIM(RTRIM(@ResultLabel)),N''),N'Ergebnis');
    SET @EmptyMessage=COALESCE(NULLIF(LTRIM(RTRIM(@EmptyMessage)),N''),N'Keine Ergebnisse');

    DECLARE @Sql nvarchar(max)=
          N'IF EXISTS (SELECT 1 FROM '+QUOTENAME(@SourceTable)+N')'
        + N' SELECT @Label AS [Ergebnis],[src].* FROM '+QUOTENAME(@SourceTable)+N' AS [src];'
        + N' ELSE SELECT @Empty AS [Ergebnis],@Status AS [Status],@Message AS [Hinweis];';

    EXEC [sys].[sp_executesql]
          @Sql
        , N'@Label nvarchar(200),@Empty nvarchar(200),@Status varchar(40),@Message nvarchar(2048)'
        , @Label=@ResultLabel
        , @Empty=@EmptyMessage
        , @Status=@StatusCode
        , @Message=@StatusMessage;
END;
GO
