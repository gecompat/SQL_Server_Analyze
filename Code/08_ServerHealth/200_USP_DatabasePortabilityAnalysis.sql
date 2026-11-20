USE [DeineDatenbank];
GO

/* OPS-006: read-only portability evidence; no automatic DDL. */
-- USAGE_SKILL_BEGIN monitor.USP_DatabasePortabilityAnalysis 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_DatabasePortabilityAnalysis"
-- schema_name: "monitor"
-- object_name: "USP_DatabasePortabilityAnalysis"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "OPS-006: read-only portability evidence; no automatic DDL."
-- source_path: "Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql"
-- ---
-- 
-- # monitor.USP_DatabasePortabilityAnalysis
-- 
-- ## Zweck und Einsatz
-- 
-- OPS-006: read-only portability evidence; no automatic DDL.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabasePortabilityAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[databases]`, `sys.dm_db_persisted_sku_features`, `[sys].[dm_db_persisted_sku_features]`, `[sys].[sp_executesql]`, `sys.dm_db_uncontained_entities`, `[sys].[dm_db_uncontained_entities]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @DatabaseNames | nvarchar(max) | nein | NULL |
-- | @MaxZeilen | int | nein | 2000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- 
-- **@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste expliziter, einteiliger Datenbanknamen. NULL, leer oder nur U+0020-Leerzeichen wählt alle online befindlichen, zugänglichen Benutzerdatenbanken (database_id>4). Ungültige/duplizierte Namen oder keine gültigen Namen ergeben INVALID_PARAMETER. Abgleich ist case-sensitiv unter SQL_Latin1_General_CP1_CS_AS; Systemdatenbanken sind ausgeschlossen. Sind alle explizit angeforderten Namen offline/unsichtbar, Status NOT_FOUND; bei teilweise fehlendem Scope AVAILABLE_LIMITED. Der Trenner | wirkt außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere Listenelemente sind ungültig; ein rohes Element ist auf 4.000 Zeichen und der ausgewertete Namensbestandteil auf 128 Zeichen begrenzt.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 2000. Positive Werte von 1 bis 2.147.483.647 begrenzen ausschließlich RAW- und JSON-Evidenzzeilen, sortiert nach DatabaseName, EvidenceType und FeatureName. 0 und NULL verwenden dort die technische Höchstgrenze 2.147.483.647 und bedeuten praktisch unbegrenzt. CONSOLE und TABLE übernehmen die gesamte materialisierte Evidenzmenge ohne dieses Limit; Status und Zählkopf beziehen sich ebenfalls auf die Vollmenge. Die Grenze reduziert die Quellabfragen nicht. Negative Werte sind ungültig, setzen INVALID_PARAMETER/IsPartial=1 und überspringen Quellenabfragen; RAW/JSON liefern dann eine leere Evidenzmenge mit sicherer TOP-Grenze 0.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel portability und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt nach DatabaseName, EvidenceType und FeatureName sortiertes Array mit derselben TOP-Grenze wie die Zeilenausgabe. NULL aktiviert IF nicht; leer wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Im regulären Aufruf werden AVAILABLE (Quellen liefen), AVAILABLE_EMPTY (beide Evidenzquellen lieferten keine Zeile), AVAILABLE_LIMITED (mindestens eine Quelle/Datenbank eingeschränkt), NOT_FOUND (alle explizit genannten Benutzerdatenbanken offline oder unsichtbar) oder INVALID_PARAMETER (ungültige Zeilengrenze, Ausgabeart oder Namensliste) zurückgegeben. Die einzelnen Quellenzeilen haben zusätzlich AVAILABLE oder SOURCE_STATUS mit DENIED_PERMISSION, UNSUPPORTED_SOURCE, LOCK_TIMEOUT oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Eingaben oder nicht verfügbaren angeforderten Datenbanken; sonst NULL. Einzelne Quellenfehler stehen in den Evidenzzeilen, ohne automatische Übernahme in diesen Parameter. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | portability | 1 | 1 | [DatabaseName] sysname NOT NULL , [EvidenceType] varchar(40) NOT NULL , [FeatureName] nvarchar(256) NULL , [FeatureType] nvarchar(256) NULL , [StatementType] nvarchar(256) NULL , [SourceObject] nvarchar(256) NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_DatabasePortabilityAnalysis
-- 
-- Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.
-- 
-- DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- 
-- CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
-- DECLARE @ResultTablesJson nvarchar(max)=N'{"portability":"#DatabasePortabilityAnalysis_HelpExample"}';
-- BEGIN TRY
--     EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
--     SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
--     DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
-- END TRY
-- BEGIN CATCH
--     DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
--     THROW;
-- END CATCH;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- OPS-006: read-only portability evidence; no automatic DDL.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_DatabasePortabilityAnalysis
-- Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.
-- DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
-- DECLARE @ResultTablesJson nvarchar(max)=N'{"portability":"#DatabasePortabilityAnalysis_HelpExample"}';
-- BEGIN TRY
--     EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
--     SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
--     DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
-- END TRY
-- BEGIN CATCH
--     DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
--     THROW;
-- END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_DatabasePortabilityAnalysis
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabasePortabilityAnalysis]
      @DatabaseNames   nvarchar(max)  = NULL
    , @MaxZeilen       int            = 2000
    , @ResultSetArt    varchar(16)    = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen    bit            = 0
    , @Json            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen  bit            = 1
    , @Hilfe           bit            = 0
    , @StatusCodeOut   varchar(40)    = NULL OUTPUT
    , @IsPartialOut    bit            = NULL OUTPUT
    , @ErrorNumberOut  int            = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_DatabasePortabilityAnalysis';
        PRINT N'Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste expliziter, einteiliger Datenbanknamen. NULL, leer oder nur U+0020-Leerzeichen wählt alle online befindlichen, zugänglichen Benutzerdatenbanken (database_id>4). Ungültige/duplizierte Namen oder keine gültigen Namen ergeben INVALID_PARAMETER. Abgleich ist case-sensitiv unter SQL_Latin1_General_CP1_CS_AS; Systemdatenbanken sind ausgeschlossen. Sind alle explizit angeforderten Namen offline/unsichtbar, Status NOT_FOUND; bei teilweise fehlendem Scope AVAILABLE_LIMITED. Der Trenner | wirkt außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere Listenelemente sind ungültig; ein rohes Element ist auf 4.000 Zeichen und der ausgewertete Namensbestandteil auf 128 Zeichen begrenzt.';
        PRINT N'@MaxZeilen int; Default: 2000. Positive Werte von 1 bis 2.147.483.647 begrenzen ausschließlich RAW- und JSON-Evidenzzeilen, sortiert nach DatabaseName, EvidenceType und FeatureName. 0 und NULL verwenden dort die technische Höchstgrenze 2.147.483.647 und bedeuten praktisch unbegrenzt. CONSOLE und TABLE übernehmen die gesamte materialisierte Evidenzmenge ohne dieses Limit; Status und Zählkopf beziehen sich ebenfalls auf die Vollmenge. Die Grenze reduziert die Quellabfragen nicht. Negative Werte sind ungültig, setzen INVALID_PARAMETER/IsPartial=1 und überspringen Quellenabfragen; RAW/JSON liefern dann eine leere Evidenzmenge mit sicherer TOP-Grenze 0.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel portability und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt nach DatabaseName, EvidenceType und FeatureName sortiertes Array mit derselben TOP-Grenze wie die Zeilenausgabe. NULL aktiviert IF nicht; leer wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Im regulären Aufruf werden AVAILABLE (Quellen liefen), AVAILABLE_EMPTY (beide Evidenzquellen lieferten keine Zeile), AVAILABLE_LIMITED (mindestens eine Quelle/Datenbank eingeschränkt), NOT_FOUND (alle explizit genannten Benutzerdatenbanken offline oder unsichtbar) oder INVALID_PARAMETER (ungültige Zeilengrenze, Ausgabeart oder Namensliste) zurückgegeben. Die einzelnen Quellenzeilen haben zusätzlich AVAILABLE oder SOURCE_STATUS mit DENIED_PERMISSION, UNSUPPORTED_SOURCE, LOCK_TIMEOUT oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Eingaben oder nicht verfügbaren angeforderten Datenbanken; sonst NULL. Einzelne Quellenfehler stehen in den Evidenzzeilen, ohne automatische Übernahme in diesen Parameter. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N''{"portability":"#DatabasePortabilityAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_DatabasePortabilityAnalysis] @Hilfe=1;';


        -- USAGE_SKILL_HELP_BEGIN monitor.USP_DatabasePortabilityAnalysis
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_DatabasePortabilityAnalysis') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_DatabasePortabilityAnalysis"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_DatabasePortabilityAnalysis"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "OPS-006: read-only portability evidence; no automatic DDL."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_DatabasePortabilityAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'OPS-006: read-only portability evidence; no automatic DDL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabasePortabilityAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[databases]`, `sys.dm_db_persisted_sku_features`, `[sys].[dm_db_persisted_sku_features]`, `[sys].[sp_executesql]`, `sys.dm_db_uncontained_entities`, `[sys].[dm_db_uncontained_entities]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @DatabaseNames | nvarchar(max) | nein | NULL |'
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
            + N'| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste expliziter, einteiliger Datenbanknamen. NULL, leer oder nur U+0020-Leerzeichen wählt alle online befindlichen, zugänglichen Benutzerdatenbanken (database_id>4). Ungültige/duplizierte Namen oder keine gültigen Namen ergeben INVALID_PARAMETER. Abgleich ist case-sensitiv unter SQL_Latin1_General_CP1_CS_AS; Systemdatenbanken sind ausgeschlossen. Sind alle explizit angeforderten Namen offline/unsichtbar, Status NOT_FOUND; bei teilweise fehlendem Scope AVAILABLE_LIMITED. Der Trenner | wirkt außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere Listenelemente sind ungültig; ein rohes Element ist auf 4.000 Zeichen und der ausgewertete Namensbestandteil auf 128 Zeichen begrenzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 2000. Positive Werte von 1 bis 2.147.483.647 begrenzen ausschließlich RAW- und JSON-Evidenzzeilen, sortiert nach DatabaseName, EvidenceType und FeatureName. 0 und NULL verwenden dort die technische Höchstgrenze 2.147.483.647 und bedeuten praktisch unbegrenzt. CONSOLE und TABLE übernehmen die gesamte materialisierte Evidenzmenge ohne dieses Limit; Status und Zählkopf beziehen sich ebenfalls auf die Vollmenge. Die Grenze reduziert die Quellabfragen nicht. Negative Werte sind ungültig, setzen INVALID_PARAMETER/IsPartial=1 und überspringen Quellenabfragen; RAW/JSON liefern dann eine leere Evidenzmenge mit sicherer TOP-Grenze 0.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel portability und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt nach DatabaseName, EvidenceType und FeatureName sortiertes Array mit derselben TOP-Grenze wie die Zeilenausgabe. NULL aktiviert IF nicht; leer wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Im regulären Aufruf werden AVAILABLE (Quellen liefen), AVAILABLE_EMPTY (beide Evidenzquellen lieferten keine Zeile), AVAILABLE_LIMITED (mindestens eine Quelle/Datenbank eingeschränkt), NOT_FOUND (alle explizit genannten Benutzerdatenbanken offline oder unsichtbar) oder INVALID_PARAMETER (ungültige Zeilengrenze, Ausgabeart oder Namensliste) zurückgegeben. Die einzelnen Quellenzeilen haben zusätzlich AVAILABLE oder SOURCE_STATUS mit DENIED_PERMISSION, UNSUPPORTED_SOURCE, LOCK_TIMEOUT oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Eingaben oder nicht verfügbaren angeforderten Datenbanken; sonst NULL. Einzelne Quellenfehler stehen in den Evidenzzeilen, ohne automatische Übernahme in diesen Parameter. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| portability | 1 | 1 | [DatabaseName] sysname NOT NULL , [EvidenceType] varchar(40) NOT NULL , [FeatureName] nvarchar(256) NULL , [FeatureType] nvarchar(256) NULL , [StatementType] nvarchar(256) NULL , [SourceObject] nvarchar(256) NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |'
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
            + N'EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_DatabasePortabilityAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.'
            + NCHAR(10)
            + NCHAR(10)
            + N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
            + NCHAR(10)
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);'
            + NCHAR(10)
            + N'DECLARE @ResultTablesJson nvarchar(max)=N''{"portability":"#DatabasePortabilityAnalysis_HelpExample"}'';'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N'    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;'
            + NCHAR(10)
            + N'    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    THROW;'
            + NCHAR(10)
            + N'END CATCH;'
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
            + N'OPS-006: read-only portability evidence; no automatic DDL.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_DatabasePortabilityAnalysis'
            + NCHAR(10)
            + N'Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.'
            + NCHAR(10)
            + N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);'
            + NCHAR(10)
            + N'DECLARE @ResultTablesJson nvarchar(max)=N''{"portability":"#DatabasePortabilityAnalysis_HelpExample"}'';'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N'    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;'
            + NCHAR(10)
            + N'    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_DatabasePortabilityAnalysis
        RETURN;
    END

    SET @Json = NULL;
    DECLARE @Status varchar(40) = 'AVAILABLE', @Partial bit = 0;
    DECLARE @ErrorNumber int = NULL, @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Mode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));

    ;
    DECLARE @PreviousLockTimeout int=@@LOCK_TIMEOUT,@RestoreLockTimeoutSql nvarchar(100); SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'portability',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';

    CREATE TABLE [#DatabasePortabilityAnalysis_Portability]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FeatureType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatementType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    DECLARE @EffectiveDatabaseNames nvarchar(max)=
        CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NULL THEN NULL ELSE @DatabaseNames END;
    DECLARE @RequestedDatabaseCount int=0,@UnavailableDatabaseCount int=0;
    CREATE TABLE [#DatabasePortabilityAnalysis_Requested]
    (
          [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValid] bit NOT NULL
    );
    IF @EffectiveDatabaseNames IS NOT NULL
        INSERT [#DatabasePortabilityAnalysis_Requested]([NameValue],[IsValid])
        SELECT [NameValue],[IsValid] FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames);
    SELECT @RequestedDatabaseCount=COUNT(*)
    FROM [#DatabasePortabilityAnalysis_Requested]
    WHERE [IsValid]=1;

    IF @MaxZeilen < 0 OR @Mode NOT IN ('CONSOLE','RAW','NONE')
        SELECT @Status='INVALID_PARAMETER', @Partial=1,
               @ErrorMessage=N'Ungültiger Zeilen- oder Ausgabeparameter.';
    ELSE IF @EffectiveDatabaseNames IS NOT NULL
         AND
         (
             @RequestedDatabaseCount=0
             OR EXISTS(SELECT 1 FROM [#DatabasePortabilityAnalysis_Requested] WHERE [IsValid]=0)
             OR EXISTS
                (
                    SELECT [NameValue]
                    FROM [#DatabasePortabilityAnalysis_Requested]
                    WHERE [IsValid]=1
                    GROUP BY [NameValue]
                    HAVING COUNT_BIG(*)>1
                )
         )
        SELECT @Status='INVALID_PARAMETER',@Partial=1,
               @ErrorMessage=N'@DatabaseNames enthält ungültige oder doppelte einteilige Datenbanknamen.';

    IF @Status = 'AVAILABLE'
    BEGIN
        DECLARE @Db sysname, @Sql nvarchar(max);
        DECLARE [dbs] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [name]
            FROM [sys].[databases] AS [d] WITH (NOLOCK)
            WHERE [d].[state] = 0 AND [d].[database_id] > 4
              AND HAS_DBACCESS([d].[name]) = 1
              AND
              (
                  @EffectiveDatabaseNames IS NULL
                  OR EXISTS
                     (
                         SELECT 1
                         FROM [#DatabasePortabilityAnalysis_Requested] AS [r]
                         WHERE [r].[IsValid]=1
                           AND [r].[NameValue]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                     )
              )
            ORDER BY [d].[name];
        OPEN [dbs]; FETCH NEXT FROM [dbs] INTO @Db;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @Sql = N'
INSERT [#DatabasePortabilityAnalysis_Portability]
SELECT @Db, ''PERSISTED_SKU_FEATURE'', [feature_name], NULL, NULL,
       N''sys.dm_db_persisted_sku_features'', ''AVAILABLE'',
       N''Persistiertes Feature ist ein Migrationshinweis; Zielunterstützung separat prüfen.''
FROM ' + QUOTENAME(@Db) + N'.[sys].[dm_db_persisted_sku_features];';
                EXEC [sys].[sp_executesql] @Sql, N'@Db sysname', @Db=@Db;
            END TRY
            BEGIN CATCH
                INSERT [#DatabasePortabilityAnalysis_Portability]
                VALUES (@Db,'SOURCE_STATUS',NULL,NULL,NULL,N'sys.dm_db_persisted_sku_features',
                        CASE WHEN ERROR_NUMBER() IN (229,371) THEN 'DENIED_PERMISSION'
                             WHEN ERROR_NUMBER() IN (207,208) THEN 'UNSUPPORTED_SOURCE'
                             WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT'
                             ELSE 'SOURCE_UNAVAILABLE' END,
                        CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                SET @Partial=1;
            END CATCH;
            BEGIN TRY
                SET @Sql = N'
INSERT [#DatabasePortabilityAnalysis_Portability]
SELECT @Db, ''UNCONTAINED_ENTITY'', [feature_name], [feature_type_name], [statement_type],
       N''sys.dm_db_uncontained_entities'', ''AVAILABLE'',
       N''Metadatenfund ohne automatische Umschreibung oder DDL-Anweisung.''
FROM ' + QUOTENAME(@Db) + N'.[sys].[dm_db_uncontained_entities];';
                EXEC [sys].[sp_executesql] @Sql, N'@Db sysname', @Db=@Db;
            END TRY
            BEGIN CATCH
                INSERT [#DatabasePortabilityAnalysis_Portability]
                VALUES (@Db,'SOURCE_STATUS',NULL,NULL,NULL,N'sys.dm_db_uncontained_entities',
                        CASE WHEN ERROR_NUMBER() IN (229,371) THEN 'DENIED_PERMISSION'
                             WHEN ERROR_NUMBER() IN (207,208) THEN 'UNSUPPORTED_SOURCE'
                             WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT'
                             ELSE 'SOURCE_UNAVAILABLE' END,
                        CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                SET @Partial=1;
            END CATCH;
            FETCH NEXT FROM [dbs] INTO @Db;
        END;
        CLOSE [dbs]; DEALLOCATE [dbs];
        IF @EffectiveDatabaseNames IS NOT NULL
            SELECT @UnavailableDatabaseCount=COUNT(*)
            FROM [#DatabasePortabilityAnalysis_Requested] AS [r]
            WHERE [r].[IsValid]=1
              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM [sys].[databases] AS [d] WITH (NOLOCK)
                      WHERE [d].[state]=0
                        AND [d].[database_id]>4
                        AND HAS_DBACCESS([d].[name])=1
                        AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[r].[NameValue]
                  );
        IF @UnavailableDatabaseCount=@RequestedDatabaseCount AND @RequestedDatabaseCount>0
            SELECT @Status='NOT_FOUND', @Partial=1, @ErrorMessage=N'Keine angeforderte Benutzerdatenbank ist online und sichtbar.';
        ELSE IF @UnavailableDatabaseCount>0
            SELECT @Status='AVAILABLE_LIMITED',@Partial=1,@ErrorMessage=N'Mindestens eine angeforderte Benutzerdatenbank ist nicht online oder nicht sichtbar.';
        ELSE IF NOT EXISTS(SELECT 1 FROM [#DatabasePortabilityAnalysis_Portability])
            SET @Status='AVAILABLE_EMPTY';
        ELSE IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
    END;

    IF @JsonErzeugen=1
        SELECT @Json=COALESCE((SELECT TOP (CASE WHEN @MaxZeilen<0 THEN 0 WHEN COALESCE(@MaxZeilen,0)=0 THEN 2147483647 ELSE @MaxZeilen END) *
                      FROM [#DatabasePortabilityAnalysis_Portability] ORDER BY [DatabaseName],[EvidenceType],[FeatureName] FOR JSON PATH),N'[]');
    IF @Mode IN('CONSOLE','RAW')
    BEGIN
        SELECT @Status AS [StatusCode],@Partial AS [IsPartial],COUNT_BIG(*) AS [EvidenceRows],
               @ErrorMessage AS [ErrorMessage] FROM [#DatabasePortabilityAnalysis_Portability];
        SELECT TOP (CASE WHEN @MaxZeilen<0 THEN 0 WHEN COALESCE(@MaxZeilen,0)=0 THEN 2147483647 ELSE @MaxZeilen END) *
        FROM [#DatabasePortabilityAnalysis_Portability] ORDER BY [DatabaseName],[EvidenceType],[FeatureName];
    END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DatabasePortabilityAnalysis_Portability',@ResultLabel=N'portability',@EmptyMessage=N'Keine Portabilitätsevidenz im sichtbaren Scope';
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#DatabasePortabilityAnalysis_Portability',@TargetTable=@TableTarget,@ThrowOnError=1;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql; SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO
