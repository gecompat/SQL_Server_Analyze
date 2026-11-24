USE [DeineDatenbank];
GO

/* OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen. */
-- USAGE_SKILL_BEGIN monitor.USP_MsdbHealthAnalysis 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_MsdbHealthAnalysis"
-- schema_name: "monitor"
-- object_name: "USP_MsdbHealthAnalysis"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen."
-- source_path: "Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql"
-- ---
-- 
-- # monitor.USP_MsdbHealthAnalysis
-- 
-- ## Zweck und Einsatz
-- 
-- OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_MsdbHealthAnalysis]. Die Quelle nennt insbesondere `msdb.dbo.syspolicy_policies`, `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[databases]`, `master.sys.master_files`, `[sys].[master_files]`, `msdb.dbo`, `[msdb].[dbo]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
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
-- **@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL wird vor der Validierung zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach Area sortiert die ersten Zeilen. EvidenceRows wird vor dem Kürzen gezählt. Negative Werte ergeben INVALID_PARAMETER und verhindern Quellenaggregation.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel msdbHealth und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die bereits nach @MaxZeilen gekürzten Zeilen nach Area sortiert. NULL aktiviert IF nicht; leere Menge wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Mögliche Gesamtwerte sind AVAILABLE (Auswertung ohne gemeldete Quellfehler), AVAILABLE_LIMITED (mindestens eine Quelle nicht lesbar), UNSUPPORTED (msdb fehlt) und INVALID_PARAMETER (negative Zeilengrenze oder ungültige Ausgabeart). Evidenzzeilen haben AVAILABLE, UNSUPPORTED (fehlendes bisheriges Historienobjekt) oder SOURCE_UNAVAILABLE (Quellenfehler; PBM-Views werden ohne Sichtbarkeitsvorprüfung direkt gelesen). NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender msdb; sonst NULL. Fehler einzelner Historien- und PBM-Quellen stehen in den Fachzeilen. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | msdbHealth | 1 | 1 | [Area] varchar(40) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [RowCount] bigint NULL , [OldestUtc] datetime2(3) NULL , [NewestUtc] datetime2(3) NULL , [SizeMb] decimal(19,2) NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_MsdbHealthAnalysis
-- 
-- Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.
-- 
-- Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.
-- 
-- Die Prozedur versucht jede fest benannte msdb-Quelle direkt zu lesen. Ein verweigerter Zugriff liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount. Nur bei einer optionalen Historienquelle mit nativer Namensauflösung SQL 208 meldet sie UNSUPPORTED. PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen die drei syspolicy-Views direkt und liefern nur COUNT_BIG. OldestUtc, NewestUtc und SizeMb bleiben für PBM NULL. Die Views erfordern PolicyAdministratorRole in msdb. Die Prozedur vergibt keine Rolle.
-- 
-- DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_MsdbHealthAnalysis
-- Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.
-- Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.
-- Die Prozedur versucht jede fest benannte msdb-Quelle direkt zu lesen. Ein verweigerter Zugriff liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount. Nur bei einer optionalen Historienquelle mit nativer Namensauflösung SQL 208 meldet sie UNSUPPORTED. PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen die drei syspolicy-Views direkt und liefern nur COUNT_BIG. OldestUtc, NewestUtc und SizeMb bleiben für PBM NULL. Die Views erfordern PolicyAdministratorRole in msdb. Die Prozedur vergibt keine Rolle.
-- DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
-- CREATE TABLE [#MsdbHealthAnalysis_HelpExample] ([Seed] int NULL);
-- DECLARE @ResultTablesJson nvarchar(max)=N'{"msdbHealth":"#MsdbHealthAnalysis_HelpExample"}';
-- BEGIN TRY
--     EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
--     SELECT * FROM [#MsdbHealthAnalysis_HelpExample];
--     DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
-- END TRY
-- BEGIN CATCH
--     DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
--     THROW;
-- END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_MsdbHealthAnalysis
CREATE OR ALTER PROCEDURE [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen       int            = 2000
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

    IF @Hilfe=1 BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_MsdbHealthAnalysis';
        PRINT N'Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.';
        PRINT N'Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.';
        PRINT N'Die Prozedur versucht jede fest benannte msdb-Quelle direkt zu lesen. Ein verweigerter Zugriff liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount. Nur bei einer optionalen Historienquelle mit nativer Namensauflösung SQL 208 meldet sie UNSUPPORTED. PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen die drei syspolicy-Views direkt und liefern nur COUNT_BIG. OldestUtc, NewestUtc und SizeMb bleiben für PBM NULL. Die Views erfordern PolicyAdministratorRole in msdb. Die Prozedur vergibt keine Rolle.';
        PRINT N'@MaxZeilen int; Default: 2000. NULL wird vor der Validierung zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach Area sortiert die ersten Zeilen. EvidenceRows wird vor dem Kürzen gezählt. Negative Werte ergeben INVALID_PARAMETER und verhindern Quellenaggregation.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel msdbHealth und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die bereits nach @MaxZeilen gekürzten Zeilen nach Area sortiert. NULL aktiviert IF nicht; leere Menge wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Mögliche Gesamtwerte sind AVAILABLE (Auswertung ohne gemeldete Quellfehler), AVAILABLE_LIMITED (mindestens eine Quelle nicht lesbar), UNSUPPORTED (msdb fehlt) und INVALID_PARAMETER (negative Zeilengrenze oder ungültige Ausgabeart). Evidenzzeilen haben AVAILABLE, UNSUPPORTED (fehlendes bisheriges Historienobjekt) oder SOURCE_UNAVAILABLE (Quellenfehler; PBM-Views werden ohne Sichtbarkeitsvorprüfung direkt gelesen). NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender msdb; sonst NULL. Fehler einzelner Historien- und PBM-Quellen stehen in den Fachzeilen. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#MsdbHealthAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N''{"msdbHealth":"#MsdbHealthAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#MsdbHealthAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_MsdbHealthAnalysis] @Hilfe=1;';








        -- USAGE_SKILL_HELP_BEGIN monitor.USP_MsdbHealthAnalysis
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_MsdbHealthAnalysis') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_MsdbHealthAnalysis"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_MsdbHealthAnalysis"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_MsdbHealthAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_MsdbHealthAnalysis]. Die Quelle nennt insbesondere `msdb.dbo.syspolicy_policies`, `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[databases]`, `master.sys.master_files`, `[sys].[master_files]`, `msdb.dbo`, `[msdb].[dbo]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL wird vor der Validierung zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach Area sortiert die ersten Zeilen. EvidenceRows wird vor dem Kürzen gezählt. Negative Werte ergeben INVALID_PARAMETER und verhindern Quellenaggregation.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel msdbHealth und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die bereits nach @MaxZeilen gekürzten Zeilen nach Area sortiert. NULL aktiviert IF nicht; leere Menge wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.'
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
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Mögliche Gesamtwerte sind AVAILABLE (Auswertung ohne gemeldete Quellfehler), AVAILABLE_LIMITED (mindestens eine Quelle nicht lesbar), UNSUPPORTED (msdb fehlt) und INVALID_PARAMETER (negative Zeilengrenze oder ungültige Ausgabeart). Evidenzzeilen haben AVAILABLE, UNSUPPORTED (fehlendes bisheriges Historienobjekt) oder SOURCE_UNAVAILABLE (Quellenfehler; PBM-Views werden ohne Sichtbarkeitsvorprüfung direkt gelesen). NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender msdb; sonst NULL. Fehler einzelner Historien- und PBM-Quellen stehen in den Fachzeilen. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| msdbHealth | 1 | 1 | [Area] varchar(40) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [RowCount] bigint NULL , [OldestUtc] datetime2(3) NULL , [NewestUtc] datetime2(3) NULL , [SizeMb] decimal(19,2) NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |'
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
            + N'EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_MsdbHealthAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Prozedur versucht jede fest benannte msdb-Quelle direkt zu lesen. Ein verweigerter Zugriff liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount. Nur bei einer optionalen Historienquelle mit nativer Namensauflösung SQL 208 meldet sie UNSUPPORTED. PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen die drei syspolicy-Views direkt und liefern nur COUNT_BIG. OldestUtc, NewestUtc und SizeMb bleiben für PBM NULL. Die Views erfordern PolicyAdministratorRole in msdb. Die Prozedur vergibt keine Rolle.'
            + NCHAR(10)
            + NCHAR(10)
            + N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
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
            + N'OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_MsdbHealthAnalysis'
            + NCHAR(10)
            + N'Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.'
            + NCHAR(10)
            + N'Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.'
            + NCHAR(10)
            + N'Die Prozedur versucht jede fest benannte msdb-Quelle direkt zu lesen. Ein verweigerter Zugriff liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount. Nur bei einer optionalen Historienquelle mit nativer Namensauflösung SQL 208 meldet sie UNSUPPORTED. PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen die drei syspolicy-Views direkt und liefern nur COUNT_BIG. OldestUtc, NewestUtc und SizeMb bleiben für PBM NULL. Die Views erfordern PolicyAdministratorRole in msdb. Die Prozedur vergibt keine Rolle.'
            + NCHAR(10)
            + N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#MsdbHealthAnalysis_HelpExample] ([Seed] int NULL);'
            + NCHAR(10)
            + N'DECLARE @ResultTablesJson nvarchar(max)=N''{"msdbHealth":"#MsdbHealthAnalysis_HelpExample"}'';'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N'    EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;'
            + NCHAR(10)
            + N'    SELECT * FROM [#MsdbHealthAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_MsdbHealthAnalysis
        RETURN;
    END
 SET @Json=NULL;
    SET @MaxZeilen=COALESCE(@MaxZeilen,0);
    DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    ;
    DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'msdbHealth',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';
    CREATE TABLE [#MsdbHealthAnalysis_Health]
    (
          [Area] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RowCount] bigint NULL,[OldestUtc] datetime2(3) NULL,[NewestUtc] datetime2(3) NULL
        , [SizeMb] decimal(19,2) NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
    IF @Status='AVAILABLE' AND NOT EXISTS (SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=4)
        SELECT @Status='UNSUPPORTED',@Partial=1,@ErrorMessage=N'msdb ist nicht verfügbar.';
    IF @Status='AVAILABLE'
    BEGIN
        INSERT [#MsdbHealthAnalysis_Health]
        SELECT 'DATABASE_SIZE',N'master.sys.master_files',NULL,NULL,NULL,
               CONVERT(decimal(19,2),SUM(CONVERT(bigint,[size]))*8.0/1024.0),'AVAILABLE',
               N'Aktuelle Dateigröße; kein Wachstums- oder freier Speicherplatznachweis.'
        FROM [sys].[master_files] WITH (NOLOCK) WHERE [database_id]=4;
        DECLARE @Defs TABLE
        (
              [Area] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
            , [DateColumn] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        INSERT @Defs VALUES
          ('BACKUP_HISTORY','backupset','backup_finish_date'),('RESTORE_HISTORY','restorehistory','restore_date'),
          ('AGENT_HISTORY','sysjobhistory',NULL),('DATABASE_MAIL','sysmail_allitems','send_request_date'),
          ('MAINTENANCE_PLAN','sysmaintplan_log','start_time'),
          ('PBM_POLICIES','syspolicy_policies',NULL),
          ('PBM_CONDITIONS','syspolicy_conditions',NULL),
          ('PBM_CATEGORIES','syspolicy_policy_categories',NULL);
        DECLARE @Area varchar(40),@Obj sysname,@Date sysname,@Sql nvarchar(max),@Source nvarchar(256),
                @IsPbm bit,@EvidenceLimit nvarchar(1000);
        DECLARE [d] CURSOR LOCAL FAST_FORWARD FOR SELECT [Area],[ObjectName],[DateColumn] FROM @Defs;
        OPEN [d]; FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Source=N'msdb.dbo.'+@Obj;
            SET @IsPbm=CASE WHEN @Area IN('PBM_POLICIES','PBM_CONDITIONS','PBM_CATEGORIES') THEN 1 ELSE 0 END;
            SET @EvidenceLimit=CASE WHEN @IsPbm=1
                THEN N'Caller-sichtbare PBM-Kataloganzahl; keine Policy-Auswertung, Retentions- oder Gesundheitsbewertung.'
                ELSE N'Retentionbewertung ist kontextabhängig; es wird nichts gelöscht.' END;
            BEGIN TRY
                SET @Sql=N'INSERT [#MsdbHealthAnalysis_Health] SELECT @Area,@Source,COUNT_BIG(*),' +
                    CASE WHEN @Date IS NULL THEN N'NULL,NULL' ELSE N'MIN('+QUOTENAME(@Date)+N'),MAX('+QUOTENAME(@Date)+N')' END +
                    N',NULL,''AVAILABLE'',@EvidenceLimit FROM [msdb].[dbo].'+QUOTENAME(@Obj)+N' WITH (NOLOCK);';
                EXEC [sys].[sp_executesql] @Sql,
                    N'@Area varchar(40),@Source nvarchar(256),@EvidenceLimit nvarchar(1000)',
                    @Area=@Area,@Source=@Source,@EvidenceLimit=@EvidenceLimit;
            END TRY
            BEGIN CATCH
                IF @IsPbm=0 AND ERROR_NUMBER()=208
                    INSERT [#MsdbHealthAnalysis_Health]
                    VALUES(@Area,@Source,NULL,NULL,NULL,NULL,'UNSUPPORTED',
                           N'Der direkte Quellenzugriff kann den Objektnamen nicht auflösen (SQL 208).');
                ELSE
                BEGIN
                    INSERT [#MsdbHealthAnalysis_Health]
                    VALUES(@Area,@Source,NULL,NULL,NULL,NULL,'SOURCE_UNAVAILABLE',
                           CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                    SET @Partial=1;
                END;
            END CATCH;
            FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        END; CLOSE [d]; DEALLOCATE [d];
        IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
    END;
    DECLARE @EvidenceRows bigint=(SELECT COUNT_BIG(*) FROM [#MsdbHealthAnalysis_Health]);
    IF @MaxZeilen>0
    BEGIN
        ;WITH [LimitedRows] AS
        (
            SELECT ROW_NUMBER() OVER (ORDER BY [Area]) AS [Ordinal]
            FROM [#MsdbHealthAnalysis_Health]
        )
        DELETE FROM [LimitedRows] WHERE [Ordinal]>@MaxZeilen;
    END;
    IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area] FOR JSON PATH),N'[]');
    IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],@EvidenceRows [EvidenceRows],@ErrorMessage [ErrorMessage]; SELECT * FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area]; END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#MsdbHealthAnalysis_Health',@ResultLabel=N'msdbHealth',@EmptyMessage=N'Keine msdb-Health-Evidenz im sichtbaren Scope';
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#MsdbHealthAnalysis_Health',@TargetTable=@TableTarget,@ThrowOnError=1;
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO
