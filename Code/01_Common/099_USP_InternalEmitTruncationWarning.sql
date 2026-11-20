USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalEmitTruncationWarning
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Gibt höchstens eine technische Severity-10-Warning für alle im
               Aufruf sichtbar gekürzten Werte aus.
Resultsets   : Keine.
Nebenwirkung : Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die
               Ausgabe aktiviert und mindestens ein Wert gekürzt ist.
Parameter    : @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit die Anzahl gekürzter Werte; der Helper
               ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab.
               NULL, 0 und negative Werte unterdrücken die Meldung.
               @ParameterName sysname, Default: keiner; Pflichtargument und
               ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu
               <unbekannter Parameter> und im Vorschlag zu den begrenzenden
               Parameter; ein leerer Wert bleibt leer.
               @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich
               Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.
               @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der
               Caller meldet damit den größten benötigten Zeichenbedarf; der
               Helper berechnet oder prüft diesen Wert nicht. NULL wird im
               Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.
               @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken
               die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale
               SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare
               Zahlen auf 1 abbilden.
               Keine Parameter sind OUTPUT-Parameter.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalEmitTruncationWarning 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalEmitTruncationWarning"
-- schema_name: "monitor"
-- object_name: "InternalEmitTruncationWarning"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus."
-- source_path: "Code/01_Common/099_USP_InternalEmitTruncationWarning.sql"
-- ---
-- 
-- # monitor.InternalEmitTruncationWarning
-- 
-- ## Zweck und Einsatz
-- 
-- Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitTruncationWarning]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @TruncatedValueCount | bigint | ja | kein Default |
-- | @ParameterName | sysname | ja | kein Default |
-- | @ParameterValue | int | ja | kein Default |
-- | @LargestRequiredCharacters | bigint | ja | kein Default |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@TruncatedValueCount:** @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der Caller meldet damit die Anzahl gekürzter Werte; der Helper ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab. NULL, 0 und negative Werte unterdrücken die Meldung.
-- 
-- **@ParameterName:** @ParameterName sysname, Default: keiner; Pflichtargument und ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu <unbekannter Parameter> und im Vorschlag zu den begrenzenden Parameter; ein leerer Wert bleibt leer.
-- 
-- **@ParameterValue:** @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.
-- 
-- **@LargestRequiredCharacters:** @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der Caller meldet damit den größten benötigten Zeichenbedarf; der Helper berechnet oder prüft diesen Wert nicht. NULL wird im Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare Zahlen auf 1 abbilden. Keine Parameter sind OUTPUT-Parameter.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Keine.
-- 
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalEmitTruncationWarning';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=NULL, @ParameterName=NULL, @ParameterValue=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die Ausgabe aktiviert und mindestens ein Wert gekürzt ist.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalEmitTruncationWarning
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Gibt höchstens eine technische Severity-10-Warning für alle im
--                Aufruf sichtbar gekürzten Werte aus.
-- Resultsets   : Keine.
-- Nebenwirkung : Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die
--                Ausgabe aktiviert und mindestens ein Wert gekürzt ist.
-- Parameter    : @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der
--                Caller meldet damit die Anzahl gekürzter Werte; der Helper
--                ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab.
--                NULL, 0 und negative Werte unterdrücken die Meldung.
--                @ParameterName sysname, Default: keiner; Pflichtargument und
--                ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu
--                <unbekannter Parameter> und im Vorschlag zu den begrenzenden
--                Parameter; ein leerer Wert bleibt leer.
--                @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich
--                Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.
--                @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der
--                Caller meldet damit den größten benötigten Zeichenbedarf; der
--                Helper berechnet oder prüft diesen Wert nicht. NULL wird im
--                Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.
--                @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken
--                die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale
--                SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare
--                Zahlen auf 1 abbilden.
--                Keine Parameter sind OUTPUT-Parameter.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalEmitTruncationWarning
CREATE OR ALTER PROCEDURE [monitor].[InternalEmitTruncationWarning]
      @TruncatedValueCount       bigint
    , @ParameterName             sysname
    , @ParameterValue            int
    , @LargestRequiredCharacters bigint
    , @PrintMeldungen            bit = 1
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalEmitTruncationWarning
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalEmitTruncationWarning') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalEmitTruncationWarning"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalEmitTruncationWarning"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/099_USP_InternalEmitTruncationWarning.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalEmitTruncationWarning'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Gibt höchstens eine technische Severity-10-Warning für alle im Aufruf sichtbar gekürzten Werte aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitTruncationWarning]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.'
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
            + N'| @TruncatedValueCount | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @ParameterName | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @ParameterValue | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @LargestRequiredCharacters | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TruncatedValueCount:** @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der Caller meldet damit die Anzahl gekürzter Werte; der Helper ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab. NULL, 0 und negative Werte unterdrücken die Meldung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ParameterName:** @ParameterName sysname, Default: keiner; Pflichtargument und ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu <unbekannter Parameter> und im Vorschlag zu den begrenzenden Parameter; ein leerer Wert bleibt leer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ParameterValue:** @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LargestRequiredCharacters:** @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der Caller meldet damit den größten benötigten Zeichenbedarf; der Helper berechnet oder prüft diesen Wert nicht. NULL wird im Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare Zahlen auf 1 abbilden. Keine Parameter sind OUTPUT-Parameter.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Keine.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
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
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalEmitTruncationWarning'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=NULL, @ParameterName=NULL, @ParameterValue=NULL, @LargestRequiredCharacters=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die Ausgabe aktiviert und mindestens ein Wert gekürzt ist.'
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
            + N'Objekt       : monitor.InternalEmitTruncationWarning'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Gibt höchstens eine technische Severity-10-Warning für alle im'
            + NCHAR(10)
            + N'               Aufruf sichtbar gekürzten Werte aus.'
            + NCHAR(10)
            + N'Resultsets   : Keine.'
            + NCHAR(10)
            + N'Nebenwirkung : Ausschließlich RAISERROR Severity 10 WITH NOWAIT, wenn die'
            + NCHAR(10)
            + N'               Ausgabe aktiviert und mindestens ein Wert gekürzt ist.'
            + NCHAR(10)
            + N'Parameter    : @TruncatedValueCount bigint, Default: keiner; Pflichtargument. Der'
            + NCHAR(10)
            + N'               Caller meldet damit die Anzahl gekürzter Werte; der Helper'
            + NCHAR(10)
            + N'               ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab.'
            + NCHAR(10)
            + N'               NULL, 0 und negative Werte unterdrücken die Meldung.'
            + NCHAR(10)
            + N'               @ParameterName sysname, Default: keiner; Pflichtargument und'
            + NCHAR(10)
            + N'               ausschließlich Textlabel. NULL wird im ersten Textvorkommen zu'
            + NCHAR(10)
            + N'               <unbekannter Parameter> und im Vorschlag zu den begrenzenden'
            + NCHAR(10)
            + N'               Parameter; ein leerer Wert bleibt leer.'
            + NCHAR(10)
            + N'               @ParameterValue int, Default: keiner; Pflichtargument und ausschließlich'
            + NCHAR(10)
            + N'               Anzeigewert; NULL wird als NULL ausgegeben. Es erfolgt keine Bereichsprüfung.'
            + NCHAR(10)
            + N'               @LargestRequiredCharacters bigint, Default: keiner; Pflichtargument. Der'
            + NCHAR(10)
            + N'               Caller meldet damit den größten benötigten Zeichenbedarf; der'
            + NCHAR(10)
            + N'               Helper berechnet oder prüft diesen Wert nicht. NULL wird im'
            + NCHAR(10)
            + N'               Bedarfstext als NULL und im Vorschlag als 0 ausgegeben.'
            + NCHAR(10)
            + N'               @PrintMeldungen bit hat den Default 1; 0 und NULL unterdrücken'
            + NCHAR(10)
            + N'               die Meldung, 1 erlaubt sie bei positivem Zähler. Die normale'
            + NCHAR(10)
            + N'               SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare'
            + NCHAR(10)
            + N'               Zahlen auf 1 abbilden.'
            + NCHAR(10)
            + N'               Keine Parameter sind OUTPUT-Parameter.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalEmitTruncationWarning
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    IF COALESCE(@PrintMeldungen,0) <> 1
       OR COALESCE(@TruncatedValueCount,0) <= 0
        RETURN;

    DECLARE @Message nvarchar(2048) = LEFT
    (
        CONCAT
        (
              N'OUTPUT_VALUE_TRUNCATED: '
            , CONVERT(nvarchar(30),@TruncatedValueCount)
            , N' Wert(e) wurden durch '
            , COALESCE(@ParameterName,N'<unbekannter Parameter>')
            , N'='
            , COALESCE(CONVERT(nvarchar(30),@ParameterValue),N'NULL')
            , N' gekürzt. Der größte Wert benötigt '
            , COALESCE(CONVERT(nvarchar(30),@LargestRequiredCharacters),N'NULL')
            , N' Zeichen. Verwenden Sie '
            , COALESCE(@ParameterName,N'den begrenzenden Parameter')
            , N'='
            , COALESCE(CONVERT(nvarchar(30),@LargestRequiredCharacters),N'0')
            , N' oder 0 für eine vollständige Ausgabe.'
        ),
        2048
    );

    RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
END;
GO
