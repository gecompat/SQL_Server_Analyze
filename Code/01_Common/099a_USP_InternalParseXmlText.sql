USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalParseXmlText
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne
               vorherige Kürzung in natives xml und klassifiziert Ausfälle.
Resultsets   : Keine; ausschließlich OUTPUT-Parameter.
Grenze       : Die aufrufende Procedure materialisiert den Quelltext genau
               einmal und entscheidet, ob ein Textfallback exportiert wird.
===============================================================================
*/
/*
Parametervertrag:
- @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...)
  nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL
  beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist
  XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020
  einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung
  AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.
- @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL.
  Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei
  einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei
  erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY.
- @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus.
  Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus
  sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich
  und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener
  Fehler 6335, 6336 oder 6337) und XML_INVALID (jeder andere gefangene Fehler).
  PENDING ist nur der initiale Zwischenwert vor CONVERT und kein normaler
  Endstatus.
- @ErrorNumber int: OUTPUT-Empfänger für ERROR_NUMBER() eines gefangenen
  Fehlers. Default: NULL. Ein bestehender Empfängerwert wird auf NULL gesetzt; ohne
  gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL.
- @ErrorMessage nvarchar(2048): OUTPUT-Empfänger für den nativen
  ERROR_MESSAGE()-Text eines gefangenen Fehlers, begrenzt durch nvarchar(2048). Default: NULL. Der
  bisherige Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei
  SOURCE_NULL, bleibt der Wert NULL.

Jeder OUTPUT-Wert wird durch Bindung als @Parameter=@typisierteVariable
OUTPUT empfangen. Ausgelassene optionale OUTPUT-Argumente empfangen keine
Daten.
*/
-- USAGE_SKILL_BEGIN monitor.InternalParseXmlText 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalParseXmlText"
-- schema_name: "monitor"
-- object_name: "InternalParseXmlText"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle."
-- source_path: "Code/01_Common/099a_USP_InternalParseXmlText.sql"
-- ---
-- 
-- # monitor.InternalParseXmlText
-- 
-- ## Zweck und Einsatz
-- 
-- Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalParseXmlText]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @XmlText | nvarchar(max) | ja | kein Default |
-- | @XmlValue | xml OUTPUT | nein | NULL |
-- | @StatusCode | varchar(40) OUTPUT | nein | NULL |
-- | @ErrorNumber | int OUTPUT | nein | NULL |
-- | @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@XmlText:** - @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...) nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020 einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.
-- 
-- **@XmlValue:** - @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL. Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@StatusCode:** - @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus. Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener Fehler 6335, 6336 oder 6337) und XML_INVALID (jeder andere gefangene Fehler). PENDING ist nur der initiale Zwischenwert vor CONVERT und kein normaler Endstatus. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorNumber:** - @ErrorNumber int: OUTPUT-Empfänger für ERROR_NUMBER() eines gefangenen Fehlers. Default: NULL. Ein bestehender Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessage:** - @ErrorMessage nvarchar(2048): OUTPUT-Empfänger für den nativen ERROR_MESSAGE()-Text eines gefangenen Fehlers, begrenzt durch nvarchar(2048). Default: NULL. Der bisherige Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Im Normalpfad gibt es kein Resultset. `@XmlValue` (xml OUTPUT) enthält bei erfolgreicher Konvertierung den vollständigen XML-Wert, sonst NULL. `@StatusCode` (varchar(40) OUTPUT) meldet SOURCE_NULL bei NULL-Text, XML_EMPTY bei leerem/Whitespace-Text nach erfolgreicher Konvertierung, AVAILABLE bei anderem gültigem XML, XML_UNAVAILABLE_LIMIT bei den nativen Fehlern 6335/6336/6337 und sonst XML_INVALID. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) bleiben ohne abgefangenen Fehler NULL oder enthalten dessen Nummer und Meldung. Die Procedure kürzt den nvarchar(max)-Eingang nicht vor der Konvertierung; die aufrufende Procedure entscheidet über einen Textfallback.
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalParseXmlText';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalParseXmlText] @XmlText=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Parametervertrag:
-- - @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...)
--   nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL
--   beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist
--   XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020
--   einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung
--   AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.
-- - @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL.
--   Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei
--   einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei
--   erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY.
-- - @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus.
--   Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus
--   sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich
--   und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich
--   und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener
--   Fehler 6
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalParseXmlText
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne
--                vorherige Kürzung in natives xml und klassifiziert Ausfälle.
-- Resultsets   : Keine; ausschließlich OUTPUT-Parameter.
-- Grenze       : Die aufrufende Procedure materialisiert den Quelltext genau
--                einmal und entscheidet, ob ein Textfallback exportiert wird.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalParseXmlText
CREATE OR ALTER PROCEDURE [monitor].[InternalParseXmlText]
      @XmlText       nvarchar(max)
    , @XmlValue      xml            = NULL OUTPUT
    , @StatusCode    varchar(40)    = NULL OUTPUT
    , @ErrorNumber   int            = NULL OUTPUT
    , @ErrorMessage  nvarchar(2048) = NULL OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalParseXmlText
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalParseXmlText') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalParseXmlText"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalParseXmlText"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/099a_USP_InternalParseXmlText.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalParseXmlText'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne vorherige Kürzung in natives xml und klassifiziert Ausfälle.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalParseXmlText]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Der Quelltext bindet die Eingaben und lokale Hilfsobjekte; etwaige native Rechtefehler entstehen bei den konkret aufgerufenen SQL-Operationen.'
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
            + N'| @XmlText | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @XmlValue | xml OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorNumber | int OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) OUTPUT | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@XmlText:** - @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...) nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020 einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@XmlValue:** - @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL. Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** - @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus. Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener Fehler 6335, 6336 oder 6337) und XML_INVALID (jeder andere gefangene Fehler). PENDING ist nur der initiale Zwischenwert vor CONVERT und kein normaler Endstatus. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumber:** - @ErrorNumber int: OUTPUT-Empfänger für ERROR_NUMBER() eines gefangenen Fehlers. Default: NULL. Ein bestehender Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** - @ErrorMessage nvarchar(2048): OUTPUT-Empfänger für den nativen ERROR_MESSAGE()-Text eines gefangenen Fehlers, begrenzt durch nvarchar(2048). Default: NULL. Der bisherige Empfängerwert wird auf NULL gesetzt; ohne gefangenen Fehler, auch bei SOURCE_NULL, bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Im Normalpfad gibt es kein Resultset. `@XmlValue` (xml OUTPUT) enthält bei erfolgreicher Konvertierung den vollständigen XML-Wert, sonst NULL. `@StatusCode` (varchar(40) OUTPUT) meldet SOURCE_NULL bei NULL-Text, XML_EMPTY bei leerem/Whitespace-Text nach erfolgreicher Konvertierung, AVAILABLE bei anderem gültigem XML, XML_UNAVAILABLE_LIMIT bei den nativen Fehlern 6335/6336/6337 und sonst XML_INVALID. `@ErrorNumber` (int OUTPUT) und `@ErrorMessage` (nvarchar(2048) OUTPUT) bleiben ohne abgefangenen Fehler NULL oder enthalten dessen Nummer und Meldung. Die Procedure kürzt den nvarchar(max)-Eingang nicht vor der Konvertierung; die aufrufende Procedure entscheidet über einen Textfallback.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
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
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalParseXmlText'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalParseXmlText] @XmlText=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parametervertrag:'
            + NCHAR(10)
            + N'- @XmlText nvarchar(max): Eingabe als vollständiger Quelltext, den CONVERT(xml, ...)'
            + NCHAR(10)
            + N'  nach nativer XML-Syntax konvertiert. Default: keiner; Pflichtargument. NULL'
            + NCHAR(10)
            + N'  beendet die Verarbeitung mit SOURCE_NULL. Bei nicht-NULL Eingaben ist'
            + NCHAR(10)
            + N'  XML_EMPTY nur dann der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020'
            + NCHAR(10)
            + N'  einen leeren Wert ergibt; andernfalls ist eine erfolgreiche Konvertierung'
            + NCHAR(10)
            + N'  AVAILABLE. Tabs werden dadurch nicht pauschal als leer klassifiziert.'
            + NCHAR(10)
            + N'- @XmlValue xml: OUTPUT-Empfänger für den nativen XML-Wert. Default: NULL.'
            + NCHAR(10)
            + N'  Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt; bei SOURCE_NULL und bei'
            + NCHAR(10)
            + N'  einem gefangenen Konvertierungsfehler bleibt der Empfänger NULL. Bei'
            + NCHAR(10)
            + N'  erfolgreicher Konvertierung enthält er den konvertierten Wert, auch bei XML_EMPTY.'
            + NCHAR(10)
            + N'- @StatusCode varchar(40): OUTPUT-Empfänger für den Verarbeitungsstatus.'
            + NCHAR(10)
            + N'  Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert. Normale Endstatus'
            + NCHAR(10)
            + N'  sind SOURCE_NULL (Quellwert ist NULL), XML_EMPTY (Konvertierung erfolgreich'
            + NCHAR(10)
            + N'  und LTRIM/RTRIM(U+0020) ist leer), AVAILABLE (Konvertierung erfolgreich'
            + NCHAR(10)
            + N'  und LTRIM/RTRIM(U+0020) ist nicht leer), XML_UNAVAILABLE_LIMIT (gefangener'
            + NCHAR(10)
            + N'  Fehler 6'
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
            + N'Objekt       : monitor.InternalParseXmlText'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Konvertiert einen vollständigen nvarchar(max)-Quellwert ohne'
            + NCHAR(10)
            + N'               vorherige Kürzung in natives xml und klassifiziert Ausfälle.'
            + NCHAR(10)
            + N'Resultsets   : Keine; ausschließlich OUTPUT-Parameter.'
            + NCHAR(10)
            + N'Grenze       : Die aufrufende Procedure materialisiert den Quelltext genau'
            + NCHAR(10)
            + N'               einmal und entscheidet, ob ein Textfallback exportiert wird.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalParseXmlText
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    SELECT @XmlValue=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,
           @StatusCode=CASE WHEN @XmlText IS NULL THEN 'SOURCE_NULL' ELSE 'PENDING' END;

    IF @XmlText IS NULL RETURN;

    BEGIN TRY
        SET @XmlValue=CONVERT(xml,@XmlText);
        SET @StatusCode=CASE
            WHEN NULLIF(LTRIM(RTRIM(@XmlText)),N'') IS NULL THEN 'XML_EMPTY'
            ELSE 'AVAILABLE' END;
    END TRY
    BEGIN CATCH
        SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),
               @StatusCode=CASE
                   WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT'
                   ELSE 'XML_INVALID' END;
    END CATCH;
END;
GO
