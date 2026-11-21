USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AgentJobs
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler,
               Schedules und Owner.
SQL-Version  : SQL Server 2019 oder neuer.
Filter       : @JobNames als bracket-aware Pipe-Liste oder alternativ
               @JobNamePattern mit LIKE/regex/regexi.
Resultsets   : RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.
               NONE: keine fachlichen Resultsets.
JSON         : meta, jobs, steps.
Änderungen   : 2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_AgentJobs 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_AgentJobs"
-- schema_name: "monitor"
-- object_name: "USP_AgentJobs"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner."
-- source_path: "Code/07_Infrastructure/020_USP_AgentJobs.sql"
-- ---
-- 
-- # monitor.USP_AgentJobs
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentJobs] im vorgesehenen Datenbankkontext. Die Procedure liest Job-, Step-, Schedule- und Historienkataloge in `msdb` unter der SQL-Agent-Sicht des aktuellen Callers; sie startet weder Job noch Dienst. Eingeschränkte msdb-Sicht ist keine vollständige Jobinventur.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @JobNames | nvarchar(max) | nein | NULL |
-- | @JobNamePattern | nvarchar(4000) | nein | NULL |
-- | @NurProblematisch | bit | nein | 0 |
-- | @LongRunningMinutes | int | nein | 60 |
-- | @MaxZeilen | int | nein | 2000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@JobNames:** @JobNames nvarchar(max)=NULL; Default: NULL. NULL deaktiviert den exakten Namensfilter. Andernfalls wird eine bracket-aware Pipe-Liste einteiliger SQL-Namen erwartet: | trennt außerhalb von eckigen Klammern; innerhalb gehört das Pipe-Zeichen zum Namen und ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Gültige Duplikate werden nach SQL_Latin1_General_CP1_CS_AS zusammengeführt; Namen mit abweichender Groß-/Kleinschreibung bleiben getrennt. Jedes Element muss als einteiliger SQL-Name mit höchstens 128 Zeichen auswertbar sein. Leere oder ungültige Elemente und rohe Segmente über 4000 UTF-16-Codeeinheiten sind ungültig; die Existenz im Katalog wird nicht geprüft. Eine leere Liste ist ungültig. @JobNames und ein nicht-NULL @JobNamePattern dürfen nicht zusammen verwendet werden. Ungültige Listen werden nach der Hilfe als INVALID_PARAMETER gemeldet, ohne Parser-THROW. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@JobNamePattern:** @JobNamePattern nvarchar(4000)=NULL; Default: NULL. NULL deaktiviert den Patternfilter; leerer oder nur aus Leerzeichen bestehender Wert ist ungültig. Äußere Leerzeichen werden entfernt. Ohne Präfix gilt LIKE. Case-insensitive Präfixe: like: verwendet SQL-LIKE, regex: reguläre Ausdrücke mit Flag c, regexi: reguläre Ausdrücke mit Flag i. Der verbleibende Inhalt wird nicht erneut getrimmt; ein Präfix ohne Inhalt ist ungültig. Regex erfordert SQL Server 2025/ProductMajorVersion 17 oder neuer und Compatibility Level 170 der Installationsdatenbank; sonst wird UNAVAILABLE_FEATURE gemeldet. Die Regexsyntax wird nicht vorab geprüft; Fehler bei REGEXP_LIKE werden abgefangen. @JobNames und Pattern sind gegenseitig exklusiv. Das Parsing erfolgt vor der Hilfe, die übrige Validierung danach. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@NurProblematisch:** @NurProblematisch bit=0; Default: 0. Bei 0 werden alle passenden Jobs ausgewählt; bei 1 werden deaktivierte, zuletzt fehlgeschlagene Jobs, Jobs ohne Schedule, ohne aktivierten Schedule sowie laufende Jobs ab dem LongRunningMinutes-Grenzwert berücksichtigt. Steps erscheinen bei 1 nur mit letztem Status FAILED, RETRY oder CANCELED. NULL ist nicht gleich 0: SQL UNKNOWN bewirkt, dass Jobs nur bei einem zutreffenden Problemprädikat erhalten bleiben; Steps nur bei einem der drei genannten Statuswerte. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@LongRunningMinutes:** @LongRunningMinutes int=60; Default: 60. Die Laufzeitschwelle wird als ganze Zahl in Minuten übergeben; erlaubt sind 1 bis 2147483647. Werte kleiner als 1 setzen INVALID_PARAMETER. NULL passiert die Bereichsprüfung, ergibt beim Laufzeitvergleich aber UNKNOWN und erzeugt deshalb keinen LONG_RUNNING-Befund. Die aktuelle Laufzeit wird mit DATEDIFF(MINUTE, Startzeit, GETDATE()) verglichen. Bei @NurProblematisch=1 dient dieser Grenzwert auch als Filter. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen INVALID_PARAMETER. Positive Werte begrenzen Job- und Stepzeilen; NULL oder 0 bedeutet unbegrenzt. Bei Nicht-Regexfiltern begrenzt bereits das erste TOP der Jobabfrage auf @EffectiveMaxZeilen und sortiert laufende Jobs zuerst, danach nach JobName. Zeilen außerhalb dieses ersten Ausschnitts können durch die spätere Problemsortierung nicht wieder aufgenommen werden; diese Sortierung bevorzugt ProblemCode-Zeilen nur unter den bereits materialisierten Jobs. Im Regexmodus wird zuerst ohne diese Grenze materialisiert, dann das Regex angewendet und anschließend die Problem-/Jobnamenpriorisierung begrenzt. Steps verwenden unabhängig davon TOP(@EffectiveMaxZeilen), geordnet nach JobName und StepId. Es gibt keine explizite Kürzungskennzeichnung oder zusätzliche Kürzungsanzahl. JSON requestedMaxRows enthält den übergebenen Wert. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt, der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert ausschließlich beschriftete Jobs, RAW den Modulstatus sowie Jobs und Steps, TABLE nur Jobs, NONE keine fachlichen Resultsets. CONSOLE und TABLE unterdrücken direkte Resultsets und verwenden anschließend ihre Ausgabeadapter. Andere Werte werden nach der Hilfe als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird vor der Hilfe Fehler 51011 ausgelöst. TABLE erwartet die JSON-Objektform {"jobs":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight vor der Hilfe Fehler 51011 aus. Exportiert werden nur Jobs, keine Steps. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta, jobs und steps, Mengenangaben und Arrays befüllt. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Sammlungsfehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt ohne Jobdatensammlung zurück. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Ausgabe-/TABLE-Preflight und Patternparsing erfolgen vor der Hilfe; Joblistenvalidierung, Parameter- und Regexfeatureprüfung sowie Datensammlung danach. Ein Preflightfehler kann daher auch mit @Hilfe=1 auftreten. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- ## Resultate und Ausgabe
-- 
-- RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | jobs | 1 | 1 | [JobId] uniqueidentifier , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [Enabled] bit , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [IsRunning] bit , [RunStart] datetime , [RunningMinutes] int , [LastRunDateTime] datetime , [LastRunStatus] int , [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS , [LastRunDurationSeconds] int , [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS , [ScheduleCount] int , [EnabledScheduleCount] int , [StepCount] int , [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_AgentJobs] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_AgentJobs
-- 
-- Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.
-- 
-- Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.
-- 
-- Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;
-- 
-- Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleJobA]|[ExampleJobB]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_AgentJobs
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Typ          : Stored Procedure
-- Zweck        : Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler,
--                Schedules und Owner.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Filter       : @JobNames als bracket-aware Pipe-Liste oder alternativ
--                @JobNamePattern mit LIKE/regex/regexi.
-- Resultsets   : RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.
--                NONE: keine fachlichen Resultsets.
-- JSON         : meta, jobs, steps.
-- Änderungen   : 2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.
--                1.0.0 - Erstfassung Phase 6.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_AgentJobs
-- Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.
-- Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.
-- Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;
-- Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleJobA]|[ExampleJobB]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
-- Beispiel 3: DECLARE @AgentJobsJson nvarchar(max); EXEC [monitor].[USP_AgentJobs] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentJobsJson OUTPUT, @PrintMeldungen=0; SELECT @AgentJobsJson AS [Json];
-- Beispiel 4: CREATE TABLE #AgentJobs_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentJobs] @ResultSetArt='TABLE', @ResultTablesJson=N'{"jobs":"#AgentJobs_HelpExample"}', @PrintMeldungen=0; SELECT * FROM #AgentJobs_HelpExample; DROP TABLE #AgentJobs_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentJobs_HelpExample; THROW; END CATCH;
-- Beispiel 5: EXEC [monitor].[USP_AgentJobs] @JobNamePattern=N'like:ExampleJob%', @MaxZeilen=100, @ResultSetArt='RAW';
-- Beispiel 6: EXEC [monitor].[USP_AgentJobs] @NurProblematisch=1, @LongRunningMinutes=60, @MaxZeilen=100, @ResultSetArt='RAW';
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_AgentJobs
CREATE OR ALTER PROCEDURE [monitor].[USP_AgentJobs]
      @JobNames          nvarchar(max)  = NULL
    , @JobNamePattern    nvarchar(4000) = NULL
    , @NurProblematisch  bit            = 0
    , @LongRunningMinutes int           = 60
    , @MaxZeilen         int            = 2000
    , @ResultSetArt      varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen      bit            = 0
    , @Json              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen    bit            = 1
    , @Hilfe             bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_AgentJobs';
        PRINT N'Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.';
        PRINT N'Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.';
        PRINT N'@JobNames nvarchar(max)=NULL; Default: NULL. NULL deaktiviert den exakten Namensfilter. Andernfalls wird eine bracket-aware Pipe-Liste einteiliger SQL-Namen erwartet: | trennt außerhalb von eckigen Klammern; innerhalb gehört das Pipe-Zeichen zum Namen und ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Gültige Duplikate werden nach SQL_Latin1_General_CP1_CS_AS zusammengeführt; Namen mit abweichender Groß-/Kleinschreibung bleiben getrennt. Jedes Element muss als einteiliger SQL-Name mit höchstens 128 Zeichen auswertbar sein. Leere oder ungültige Elemente und rohe Segmente über 4000 UTF-16-Codeeinheiten sind ungültig; die Existenz im Katalog wird nicht geprüft. Eine leere Liste ist ungültig. @JobNames und ein nicht-NULL @JobNamePattern dürfen nicht zusammen verwendet werden. Ungültige Listen werden nach der Hilfe als INVALID_PARAMETER gemeldet, ohne Parser-THROW. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JobNamePattern nvarchar(4000)=NULL; Default: NULL. NULL deaktiviert den Patternfilter; leerer oder nur aus Leerzeichen bestehender Wert ist ungültig. Äußere Leerzeichen werden entfernt. Ohne Präfix gilt LIKE. Case-insensitive Präfixe: like: verwendet SQL-LIKE, regex: reguläre Ausdrücke mit Flag c, regexi: reguläre Ausdrücke mit Flag i. Der verbleibende Inhalt wird nicht erneut getrimmt; ein Präfix ohne Inhalt ist ungültig. Regex erfordert SQL Server 2025/ProductMajorVersion 17 oder neuer und Compatibility Level 170 der Installationsdatenbank; sonst wird UNAVAILABLE_FEATURE gemeldet. Die Regexsyntax wird nicht vorab geprüft; Fehler bei REGEXP_LIKE werden abgefangen. @JobNames und Pattern sind gegenseitig exklusiv. Das Parsing erfolgt vor der Hilfe, die übrige Validierung danach. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@NurProblematisch bit=0; Default: 0. Bei 0 werden alle passenden Jobs ausgewählt; bei 1 werden deaktivierte, zuletzt fehlgeschlagene Jobs, Jobs ohne Schedule, ohne aktivierten Schedule sowie laufende Jobs ab dem LongRunningMinutes-Grenzwert berücksichtigt. Steps erscheinen bei 1 nur mit letztem Status FAILED, RETRY oder CANCELED. NULL ist nicht gleich 0: SQL UNKNOWN bewirkt, dass Jobs nur bei einem zutreffenden Problemprädikat erhalten bleiben; Steps nur bei einem der drei genannten Statuswerte. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LongRunningMinutes int=60; Default: 60. Die Laufzeitschwelle wird als ganze Zahl in Minuten übergeben; erlaubt sind 1 bis 2147483647. Werte kleiner als 1 setzen INVALID_PARAMETER. NULL passiert die Bereichsprüfung, ergibt beim Laufzeitvergleich aber UNKNOWN und erzeugt deshalb keinen LONG_RUNNING-Befund. Die aktuelle Laufzeit wird mit DATEDIFF(MINUTE, Startzeit, GETDATE()) verglichen. Bei @NurProblematisch=1 dient dieser Grenzwert auch als Filter. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=2000; Default: 2000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen INVALID_PARAMETER. Positive Werte begrenzen Job- und Stepzeilen; NULL oder 0 bedeutet unbegrenzt. Bei Nicht-Regexfiltern begrenzt bereits das erste TOP der Jobabfrage auf @EffectiveMaxZeilen und sortiert laufende Jobs zuerst, danach nach JobName. Zeilen außerhalb dieses ersten Ausschnitts können durch die spätere Problemsortierung nicht wieder aufgenommen werden; diese Sortierung bevorzugt ProblemCode-Zeilen nur unter den bereits materialisierten Jobs. Im Regexmodus wird zuerst ohne diese Grenze materialisiert, dann das Regex angewendet und anschließend die Problem-/Jobnamenpriorisierung begrenzt. Steps verwenden unabhängig davon TOP(@EffectiveMaxZeilen), geordnet nach JobName und StepId. Es gibt keine explizite Kürzungskennzeichnung oder zusätzliche Kürzungsanzahl. JSON requestedMaxRows enthält den übergebenen Wert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt, der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert ausschließlich beschriftete Jobs, RAW den Modulstatus sowie Jobs und Steps, TABLE nur Jobs, NONE keine fachlichen Resultsets. CONSOLE und TABLE unterdrücken direkte Resultsets und verwenden anschließend ihre Ausgabeadapter. Andere Werte werden nach der Hilfe als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird vor der Hilfe Fehler 51011 ausgelöst. TABLE erwartet die JSON-Objektform {"jobs":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight vor der Hilfe Fehler 51011 aus. Exportiert werden nur Jobs, keine Steps. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta, jobs und steps, Mengenangaben und Arrays befüllt. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Sammlungsfehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt ohne Jobdatensammlung zurück. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Ausgabe-/TABLE-Preflight und Patternparsing erfolgen vor der Hilfe; Joblistenvalidierung, Parameter- und Regexfeatureprüfung sowie Datensammlung danach. Ein Preflightfehler kann daher auch mit @Hilfe=1 auftreten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N''[ExampleJobA]|[ExampleJobB]'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @AgentJobsJson nvarchar(max); EXEC [monitor].[USP_AgentJobs] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentJobsJson OUTPUT, @PrintMeldungen=0; SELECT @AgentJobsJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #AgentJobs_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentJobs] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"jobs":"#AgentJobs_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM #AgentJobs_HelpExample; DROP TABLE #AgentJobs_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentJobs_HelpExample; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_AgentJobs] @JobNamePattern=N''like:ExampleJob%'', @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 6: EXEC [monitor].[USP_AgentJobs] @NurProblematisch=1, @LongRunningMinutes=60, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_AgentJobs
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_AgentJobs') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_AgentJobs"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_AgentJobs"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner."'
            + NCHAR(10)
            + N'source_path: "Code/07_Infrastructure/020_USP_AgentJobs.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_AgentJobs'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentJobs] im vorgesehenen Datenbankkontext. Die Procedure liest Job-, Step-, Schedule- und Historienkataloge in `msdb` unter der SQL-Agent-Sicht des aktuellen Callers; sie startet weder Job noch Dienst. Eingeschränkte msdb-Sicht ist keine vollständige Jobinventur.'
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
            + N'| @JobNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JobNamePattern | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @NurProblematisch | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @LongRunningMinutes | int | nein | 60 |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 2000 |'
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
            + N'**@JobNames:** @JobNames nvarchar(max)=NULL; Default: NULL. NULL deaktiviert den exakten Namensfilter. Andernfalls wird eine bracket-aware Pipe-Liste einteiliger SQL-Namen erwartet: | trennt außerhalb von eckigen Klammern; innerhalb gehört das Pipe-Zeichen zum Namen und ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Gültige Duplikate werden nach SQL_Latin1_General_CP1_CS_AS zusammengeführt; Namen mit abweichender Groß-/Kleinschreibung bleiben getrennt. Jedes Element muss als einteiliger SQL-Name mit höchstens 128 Zeichen auswertbar sein. Leere oder ungültige Elemente und rohe Segmente über 4000 UTF-16-Codeeinheiten sind ungültig; die Existenz im Katalog wird nicht geprüft. Eine leere Liste ist ungültig. @JobNames und ein nicht-NULL @JobNamePattern dürfen nicht zusammen verwendet werden. Ungültige Listen werden nach der Hilfe als INVALID_PARAMETER gemeldet, ohne Parser-THROW. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JobNamePattern:** @JobNamePattern nvarchar(4000)=NULL; Default: NULL. NULL deaktiviert den Patternfilter; leerer oder nur aus Leerzeichen bestehender Wert ist ungültig. Äußere Leerzeichen werden entfernt. Ohne Präfix gilt LIKE. Case-insensitive Präfixe: like: verwendet SQL-LIKE, regex: reguläre Ausdrücke mit Flag c, regexi: reguläre Ausdrücke mit Flag i. Der verbleibende Inhalt wird nicht erneut getrimmt; ein Präfix ohne Inhalt ist ungültig. Regex erfordert SQL Server 2025/ProductMajorVersion 17 oder neuer und Compatibility Level 170 der Installationsdatenbank; sonst wird UNAVAILABLE_FEATURE gemeldet. Die Regexsyntax wird nicht vorab geprüft; Fehler bei REGEXP_LIKE werden abgefangen. @JobNames und Pattern sind gegenseitig exklusiv. Das Parsing erfolgt vor der Hilfe, die übrige Validierung danach. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. Bei 0 werden alle passenden Jobs ausgewählt; bei 1 werden deaktivierte, zuletzt fehlgeschlagene Jobs, Jobs ohne Schedule, ohne aktivierten Schedule sowie laufende Jobs ab dem LongRunningMinutes-Grenzwert berücksichtigt. Steps erscheinen bei 1 nur mit letztem Status FAILED, RETRY oder CANCELED. NULL ist nicht gleich 0: SQL UNKNOWN bewirkt, dass Jobs nur bei einem zutreffenden Problemprädikat erhalten bleiben; Steps nur bei einem der drei genannten Statuswerte. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LongRunningMinutes:** @LongRunningMinutes int=60; Default: 60. Die Laufzeitschwelle wird als ganze Zahl in Minuten übergeben; erlaubt sind 1 bis 2147483647. Werte kleiner als 1 setzen INVALID_PARAMETER. NULL passiert die Bereichsprüfung, ergibt beim Laufzeitvergleich aber UNKNOWN und erzeugt deshalb keinen LONG_RUNNING-Befund. Die aktuelle Laufzeit wird mit DATEDIFF(MINUTE, Startzeit, GETDATE()) verglichen. Bei @NurProblematisch=1 dient dieser Grenzwert auch als Filter. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen INVALID_PARAMETER. Positive Werte begrenzen Job- und Stepzeilen; NULL oder 0 bedeutet unbegrenzt. Bei Nicht-Regexfiltern begrenzt bereits das erste TOP der Jobabfrage auf @EffectiveMaxZeilen und sortiert laufende Jobs zuerst, danach nach JobName. Zeilen außerhalb dieses ersten Ausschnitts können durch die spätere Problemsortierung nicht wieder aufgenommen werden; diese Sortierung bevorzugt ProblemCode-Zeilen nur unter den bereits materialisierten Jobs. Im Regexmodus wird zuerst ohne diese Grenze materialisiert, dann das Regex angewendet und anschließend die Problem-/Jobnamenpriorisierung begrenzt. Steps verwenden unabhängig davon TOP(@EffectiveMaxZeilen), geordnet nach JobName und StepId. Es gibt keine explizite Kürzungskennzeichnung oder zusätzliche Kürzungsanzahl. JSON requestedMaxRows enthält den übergebenen Wert. Bei ausgelassenem Argument g'
            + N'ilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt, der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert ausschließlich beschriftete Jobs, RAW den Modulstatus sowie Jobs und Steps, TABLE nur Jobs, NONE keine fachlichen Resultsets. CONSOLE und TABLE unterdrücken direkte Resultsets und verwenden anschließend ihre Ausgabeadapter. Andere Werte werden nach der Hilfe als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird vor der Hilfe Fehler 51011 ausgelöst. TABLE erwartet die JSON-Objektform {"jobs":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight vor der Hilfe Fehler 51011 aus. Exportiert werden nur Jobs, keine Steps. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta, jobs und steps, Mengenangaben und Arrays befüllt. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Sammlungsfehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt ohne Jobdatensammlung zurück. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Ausgabe-/TABLE-Preflight und Patternparsing erfolgen vor der Hilfe; Joblistenvalidierung, Parameter- und Regexfeatureprüfung sowie Datensammlung danach. Ein Preflightfehler kann daher auch mit @Hilfe=1 auftreten. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| jobs | 1 | 1 | [JobId] uniqueidentifier , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [Enabled] bit , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [IsRunning] bit , [RunStart] datetime , [RunningMinutes] int , [LastRunDateTime] datetime , [LastRunStatus] int , [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS , [LastRunDurationSeconds] int , [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS , [ScheduleCount] int , [EnabledScheduleCount] int , [StepCount] int , [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS |'
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
            + N'EXEC [monitor].[USP_AgentJobs] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_AgentJobs'
            + NCHAR(10)
            + NCHAR(10)
            + N'Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N''[ExampleJobA]|[ExampleJobB]'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;'
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
            + N'Objekt       : monitor.USP_AgentJobs'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler,'
            + NCHAR(10)
            + N'               Schedules und Owner.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Filter       : @JobNames als bracket-aware Pipe-Liste oder alternativ'
            + NCHAR(10)
            + N'               @JobNamePattern mit LIKE/regex/regexi.'
            + NCHAR(10)
            + N'Resultsets   : RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.'
            + NCHAR(10)
            + N'               NONE: keine fachlichen Resultsets.'
            + NCHAR(10)
            + N'JSON         : meta, jobs, steps.'
            + NCHAR(10)
            + N'Änderungen   : 2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.'
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
            + N'monitor.USP_AgentJobs'
            + NCHAR(10)
            + N'Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.'
            + NCHAR(10)
            + N'Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.'
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N''[ExampleJobA]|[ExampleJobB]'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;'
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @AgentJobsJson nvarchar(max); EXEC [monitor].[USP_AgentJobs] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentJobsJson OUTPUT, @PrintMeldungen=0; SELECT @AgentJobsJson AS [Json];'
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #AgentJobs_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentJobs] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"jobs":"#AgentJobs_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM #AgentJobs_HelpExample; DROP TABLE #AgentJobs_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentJobs_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'Beispiel 5: EXEC [monitor].[USP_AgentJobs] @JobNamePattern=N''like:ExampleJob%'', @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Beispiel 6: EXEC [monitor].[USP_AgentJobs] @NurProblematisch=1, @LongRunningMinutes=60, @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_AgentJobs
        RETURN;
    END


    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'jobs',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @PatternMode varchar(8);
    DECLARE @PatternValue nvarchar(4000);
    DECLARE @RegexFlags varchar(8);
    DECLARE @PatternIsValid bit;
    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;

    SELECT
          @PatternMode = [PatternMode]
        , @PatternValue = [PatternValue]
        , @RegexFlags = [RegexFlags]
        , @PatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@JobNamePattern);

    ;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#AgentJobs_JobNameFilter]
    (
          [ItemOrdinal] int NOT NULL
        , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([JobName])
    );

    CREATE TABLE [#AgentJobs_Jobs]
    (
          [JobId] uniqueidentifier
        , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [Enabled] bit
        , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [IsRunning] bit
        , [RunStart] datetime
        , [RunningMinutes] int
        , [LastRunDateTime] datetime
        , [LastRunStatus] int
        , [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [LastRunDurationSeconds] int
        , [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [ScheduleCount] int
        , [EnabledScheduleCount] int
        , [StepCount] int
        , [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS
    );

    CREATE TABLE [#AgentJobs_Steps]
    (
          [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [StepId] int
        , [StepName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [Subsystem] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [LastRunOutcome] int
        , [LastRunOutcomeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [LastRunDateTime] datetime
        , [LastRunDurationSeconds] int
        , [LastRunRetries] int
        , [LastRunMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS
    );

    IF @JobNames IS NOT NULL
    BEGIN
        INSERT [#AgentJobs_JobNameFilter]([ItemOrdinal], [JobName])
        SELECT MIN([ItemOrdinal]), [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [monitor].[TVF_ParseSqlNameList](@JobNames)
        WHERE [IsValid] = 1
        GROUP BY [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS;
    END;

    IF @MaxZeilen < 0
       OR @LongRunningMinutes < 1
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @PatternIsValid = 0
       OR (@JobNames IS NOT NULL AND @JobNamePattern IS NOT NULL)
       OR (@JobNames IS NOT NULL AND EXISTS
          (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@JobNames) WHERE [IsValid] = 0))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @IsPartial = 1;
        SET @ErrorMessage = N'Ungültige Filter-, Grenzwert- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @PatternMode IN ('REGEX', 'REGEXI')
       AND
       (
           TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
           OR NOT EXISTS
              (
                  SELECT 1
                  FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  WHERE [d].[database_id] = DB_ID()
                    AND [d].[compatibility_level] >= 170
              )
       )
    BEGIN
        SET @StatusCode = 'UNAVAILABLE_FEATURE';
        SET @IsPartial = 1;
        SET @ErrorMessage = N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE @CollectionXactAbort int = @@OPTIONS & 16384;
        SET XACT_ABORT OFF;
    BEGIN TRY
        ;WITH [A] AS
        (
            SELECT [ja].*, ROW_NUMBER() OVER
                   (PARTITION BY [ja].[job_id] ORDER BY [ja].[session_id] DESC) AS [rn]
            FROM [msdb].[dbo].[sysjobactivity] AS [ja] WITH (NOLOCK)
        ),
        [H] AS
        (
            SELECT [h].*, ROW_NUMBER() OVER
                   (PARTITION BY [h].[job_id] ORDER BY [h].[instance_id] DESC) AS [rn]
            FROM [msdb].[dbo].[sysjobhistory] AS [h] WITH (NOLOCK)
            WHERE [h].[step_id] = 0
        ),
        [S] AS
        (
            SELECT
                  [js].[job_id]
                , COUNT_BIG(*) AS [ScheduleCount]
                , SUM(CASE WHEN [sc].[enabled] = 1 THEN 1 ELSE 0 END) AS [EnabledScheduleCount]
            FROM [msdb].[dbo].[sysjobschedules] AS [js] WITH (NOLOCK)
            JOIN [msdb].[dbo].[sysschedules] AS [sc] WITH (NOLOCK)
              ON [sc].[schedule_id] = [js].[schedule_id]
            GROUP BY [js].[job_id]
        )
        INSERT [#AgentJobs_Jobs]
        SELECT TOP (CASE WHEN @PatternMode IN ('REGEX', 'REGEXI') THEN CONVERT(bigint, 9223372036854775807) ELSE @EffectiveMaxZeilen END)
              [j].[job_id]
            , [j].[name]
            , [j].[enabled]
            , SUSER_SNAME([j].[owner_sid])
            , [c].[name]
            , CONVERT(bit, CASE WHEN [a].[start_execution_date] IS NOT NULL AND [a].[stop_execution_date] IS NULL THEN 1 ELSE 0 END)
            , [a].[start_execution_date]
            , CASE WHEN [a].[start_execution_date] IS NOT NULL AND [a].[stop_execution_date] IS NULL
                   THEN DATEDIFF(MINUTE, [a].[start_execution_date], GETDATE()) END
            , CASE WHEN [h].[run_date] > 0 THEN [msdb].[dbo].[agent_datetime]([h].[run_date], [h].[run_time]) END
            , [h].[run_status]
            , CASE [h].[run_status] WHEN 0 THEN N'FAILED' WHEN 1 THEN N'SUCCEEDED'
                   WHEN 2 THEN N'RETRY' WHEN 3 THEN N'CANCELED' WHEN 4 THEN N'IN_PROGRESS' END
            , ([h].[run_duration] / 10000) * 3600
              + (([h].[run_duration] % 10000) / 100) * 60
              + ([h].[run_duration] % 100)
            , [h].[message]
            , CONVERT(int, COALESCE([s].[ScheduleCount], 0))
            , CONVERT(int, COALESCE([s].[EnabledScheduleCount], 0))
            , (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobsteps] AS [st] WITH (NOLOCK) WHERE [st].[job_id] = [j].[job_id])
            , CASE WHEN [j].[enabled] = 0 THEN 'DISABLED'
                   WHEN [a].[start_execution_date] IS NOT NULL AND [a].[stop_execution_date] IS NULL
                    AND DATEDIFF(MINUTE, [a].[start_execution_date], GETDATE()) >= @LongRunningMinutes THEN 'LONG_RUNNING'
                   WHEN [h].[run_status] = 0 THEN 'LAST_FAILED'
                   WHEN COALESCE([s].[ScheduleCount], 0) = 0 THEN 'NO_SCHEDULE'
                   WHEN COALESCE([s].[EnabledScheduleCount], 0) = 0 THEN 'NO_ENABLED_SCHEDULE' END
        FROM [msdb].[dbo].[sysjobs] AS [j] WITH (NOLOCK)
        LEFT JOIN [msdb].[dbo].[syscategories] AS [c] WITH (NOLOCK)
          ON [c].[category_id] = [j].[category_id]
        LEFT JOIN [A] AS [a] ON [a].[job_id] = [j].[job_id] AND [a].[rn] = 1
        LEFT JOIN [H] AS [h] ON [h].[job_id] = [j].[job_id] AND [h].[rn] = 1
        LEFT JOIN [S] AS [s] ON [s].[job_id] = [j].[job_id]
        WHERE
            (
                NOT EXISTS (SELECT 1 FROM [#AgentJobs_JobNameFilter])
                OR EXISTS
                   (
                       SELECT 1
                       FROM [#AgentJobs_JobNameFilter] AS [f]
                       WHERE [f].[JobName] = [j].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                   )
            )
          AND
            (
                @PatternMode IN ('NONE', 'REGEX', 'REGEXI')
                OR [j].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                   LIKE @PatternValue COLLATE SQL_Latin1_General_CP1_CS_AS
            )
          AND
            (
                @NurProblematisch = 0
                OR [j].[enabled] = 0
                OR [h].[run_status] = 0
                OR COALESCE([s].[ScheduleCount], 0) = 0
                OR COALESCE([s].[EnabledScheduleCount], 0) = 0
                OR ([a].[start_execution_date] IS NOT NULL AND [a].[stop_execution_date] IS NULL
                    AND DATEDIFF(MINUTE, [a].[start_execution_date], GETDATE()) >= @LongRunningMinutes)
            )
        ORDER BY
              CASE WHEN [a].[start_execution_date] IS NOT NULL AND [a].[stop_execution_date] IS NULL THEN 0 ELSE 1 END
            , [j].[name];

        IF @PatternMode IN ('REGEX', 'REGEXI')
        BEGIN
            DECLARE @RegexSql nvarchar(max) = N'DELETE [j]
FROM [#AgentJobs_Jobs] AS [j]
WHERE NOT REGEXP_LIKE([j].[JobName], @Pattern, @Flags);';

            EXEC [sys].[sp_executesql]
                  @RegexSql
                , N'@Pattern nvarchar(4000), @Flags varchar(8)'
                , @Pattern = @PatternValue
                , @Flags = @RegexFlags;
        END;

        IF @EffectiveMaxZeilen < 9223372036854775807
        BEGIN
            ;WITH [D] AS
            (
                SELECT
                      [JobId]
                    , ROW_NUMBER() OVER
                      (ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END, [JobName]) AS [rn]
                FROM [#AgentJobs_Jobs]
            )
            DELETE [j]
            FROM [#AgentJobs_Jobs] AS [j]
            JOIN [D] AS [d] ON [d].[JobId] = [j].[JobId]
            WHERE [d].[rn] > @EffectiveMaxZeilen;
        END;

        ;WITH [SH] AS
        (
            SELECT [h].*, ROW_NUMBER() OVER
                   (PARTITION BY [h].[job_id], [h].[step_id] ORDER BY [h].[instance_id] DESC) AS [rn]
            FROM [msdb].[dbo].[sysjobhistory] AS [h] WITH (NOLOCK)
            WHERE [h].[step_id] > 0
        )
        INSERT [#AgentJobs_Steps]
        SELECT TOP (@EffectiveMaxZeilen)
              [j].[name], [st].[step_id], [st].[step_name], [st].[subsystem], [h].[run_status]
            , CASE [h].[run_status] WHEN 0 THEN N'FAILED' WHEN 1 THEN N'SUCCEEDED'
                   WHEN 2 THEN N'RETRY' WHEN 3 THEN N'CANCELED' WHEN 4 THEN N'IN_PROGRESS' END
            , CASE WHEN [h].[run_date] > 0 THEN [msdb].[dbo].[agent_datetime]([h].[run_date], [h].[run_time]) END
            , ([h].[run_duration] / 10000) * 3600
              + (([h].[run_duration] % 10000) / 100) * 60
              + ([h].[run_duration] % 100)
            , [h].[retries_attempted], [h].[message]
        FROM [msdb].[dbo].[sysjobsteps] AS [st] WITH (NOLOCK)
        JOIN [msdb].[dbo].[sysjobs] AS [j] WITH (NOLOCK) ON [j].[job_id] = [st].[job_id]
        JOIN [#AgentJobs_Jobs] AS [selected] ON [selected].[JobId] = [j].[job_id]
        LEFT JOIN [SH] AS [h]
          ON [h].[job_id] = [st].[job_id]
         AND [h].[step_id] = [st].[step_id]
         AND [h].[rn] = 1
        WHERE @NurProblematisch = 0 OR [h].[run_status] IN (0, 2, 3)
        ORDER BY [j].[name], [st].[step_id];
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'ERROR_HANDLED'
            , @IsPartial = 1
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();

        IF @PrintMeldungen = 1
            RAISERROR(N'Agentjobs konnten nicht vollständig gelesen werden: %s', 10, 1, @ErrorMessage) WITH NOWAIT;
    END CATCH;
        IF @CollectionXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_AgentJobs' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT * FROM [#AgentJobs_Jobs] ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END, [JobName];
            SELECT * FROM [#AgentJobs_Steps] ORDER BY [JobName], [StepId];
        END;
        ELSE
        BEGIN
            SELECT
                  N'SQL-Agent-Job' AS [Ergebnis]
                , [JobName] AS [Job]
                , [Enabled] AS [Aktiv]
                , [IsRunning] AS [Läuft]
                , CASE WHEN [RunningMinutes] IS NULL THEN NULL ELSE CONCAT([RunningMinutes], N' min') END AS [Aktuelle Laufzeit]
                , [LastRunStatusDesc] AS [Letzter Status]
                , CASE WHEN [LastRunDurationSeconds] IS NULL THEN NULL ELSE CONCAT([LastRunDurationSeconds], N' s') END AS [Letzte Laufzeit]
                , [ProblemCode] AS [Problem]
                , [OwnerName] AS [Owner]
                , [CategoryName] AS [Kategorie]
                , [ScheduleCount] AS [Schedules]
                , [EnabledScheduleCount] AS [Aktive Schedules]
                , [StepCount] AS [Steps]
                , [LastMessage] AS [Letzte Meldung]
            FROM [#AgentJobs_Jobs]
            ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END, [JobName];

            SELECT
                  N'SQL-Agent-Jobstep' AS [Ergebnis]
                , [JobName] AS [Job]
                , [StepId] AS [Step]
                , [StepName] AS [Stepname]
                , [Subsystem]
                , [LastRunOutcomeDesc] AS [Letzter Status]
                , [LastRunDateTime] AS [Letzte Ausführung]
                , CASE WHEN [LastRunDurationSeconds] IS NULL THEN NULL ELSE CONCAT([LastRunDurationSeconds], N' s') END AS [Laufzeit]
                , [LastRunRetries] AS [Retries]
                , [LastRunMessage] AS [Meldung]
            FROM [#AgentJobs_Steps]
            ORDER BY [JobName], [StepId];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'AgentJobs' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , (SELECT COUNT_BIG(*) FROM [#AgentJobs_Jobs]) AS [jobCount]
                , (SELECT COUNT_BIG(*) FROM [#AgentJobs_Steps]) AS [stepCount]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @JobsJson nvarchar(max) =
            (SELECT * FROM [#AgentJobs_Jobs] ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END, [JobName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @StepsJson nvarchar(max) =
            (SELECT * FROM [#AgentJobs_Steps] ORDER BY [JobName], [StepId] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"jobs":', COALESCE(@JobsJson, N'[]')
            , N',"steps":', COALESCE(@StepsJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#AgentJobs_Jobs'
            , @ResultLabel=N'AgentJobs'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AgentJobs_Jobs'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
