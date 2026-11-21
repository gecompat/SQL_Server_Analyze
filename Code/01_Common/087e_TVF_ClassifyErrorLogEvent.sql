USE [DeineDatenbank];
GO

/*
Die Inline-TVF ordnet eine übergebene Errorlogmeldung genau einer Kategorie zu und liefert stets eine Zeile mit [Category]. Sie liest selbst keine Errorlogdaten und persistiert keine Ergebnisse. @ProductName bezeichnet das Produkt, @RuleCategory die zuvor ermittelte Regelkategorie und @MessageText den Meldungstext; alle drei Eingaben sind erforderlich.

Die erste zutreffende CASE-Bedingung entscheidet: SQL_AGENT überschreibt zuerst alle anderen Hinweise; danach folgen die Fehler 823/824/825, lange I/O-Dauer, fehlgeschlagenes Backup/Restore, Cache-Flush, Autogrow, Stack Dump/Assertion, Login/Verbindung, Log Shipping und Replikation. Trifft nichts zu, wird @RuleCategory übernommen, bei NULL stattdessen UNCLASSIFIED. Ein leerer @RuleCategory wird nicht normalisiert. Die Ausgabe wird in varchar(80) konvertiert; längere Regelkategorien können dadurch abgeschnitten werden.

Die Meldungsmuster verwenden eine explizite CI-Kollation; der Vergleich von @ProductName folgt der Datenbankkollation. Die englischen Teilzeichenfolgen sind Heuristiken, keine Lokalisierung und kein vollständiger Parser. NULL in den Eingaben erzeugt keinen zusätzlichen Fehlerzweig: nicht erfüllte Bedingungen fallen auf die Regelkategorie beziehungsweise UNCLASSIFIED zurück. Andere Produktnamen werden weiterhin anhand der Meldungsmuster klassifiziert und erreichen die Rückfallkategorie nur, wenn kein Muster passt.

Beispiel mit synthetischen Eingaben:
SELECT *
FROM [monitor].[TVF_ClassifyErrorLogEvent]
     ('SQL', 'CUSTOM_RULE', N'Autogrow completed');
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ClassifyErrorLogEvent 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ClassifyErrorLogEvent"
-- schema_name: "monitor"
-- object_name: "TVF_ClassifyErrorLogEvent"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Inline-TVF ordnet eine übergebene Errorlogmeldung genau einer Kategorie zu und liefert stets eine Zeile mit [Category]."
-- source_path: "Code/01_Common/087e_TVF_ClassifyErrorLogEvent.sql"
-- ---
-- 
-- # monitor.TVF_ClassifyErrorLogEvent
-- 
-- ## Zweck und Einsatz
-- 
-- Die Inline-TVF ordnet eine übergebene Errorlogmeldung genau einer Kategorie zu und liefert stets eine Zeile mit [Category]. Sie liest selbst keine Errorlogdaten und persistiert keine Ergebnisse. @ProductName bezeichnet das Produkt, @RuleCategory die zuvor ermittelte Regelkategorie und @MessageText den Meldungstext; alle drei Eingaben sind erforderlich.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ClassifyErrorLogEvent]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @ProductName | varchar(32) | ja | kein Default |
-- | @RuleCategory | varchar(80) | ja | kein Default |
-- | @MessageText | nvarchar(max) | ja | kein Default |
-- 
-- **@ProductName:** Pflichtwert varchar(32), kein Default. Produktbezeichner für die erste SQL_AGENT-Regel; der Vergleich folgt der Datenbankkollation. NULL löst keinen separaten Fehler aus, und andere Namen können über Meldungsmuster klassifiziert werden.
-- 
-- **@RuleCategory:** Pflichtwert varchar(80), kein Default. Bereits ermittelte Regelkategorie als Fallback, falls kein priorisiertes Meldungsmuster greift. NULL ergibt UNCLASSIFIED, leer bleibt leer; die Ausgabe wird auf varchar(80) konvertiert.
-- 
-- **@MessageText:** Pflichtwert nvarchar(max), kein Default. Bereits vorliegender Errorlogtext; die Funktion liest keinen Log. Englische Teilzeichenfolgen werden mit expliziter CI-Collation heuristisch geprüft; NULL führt ohne Sonderfehler zum Fallback.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile mit `Category varchar(80)`. Der CASE klassifiziert den übergebenen Ereignistext und ProductName; ohne passende interne Regel wird der übergebene RuleCategory-Wert oder UNCLASSIFIED verwendet. Die Funktion liest selbst kein Fehlerlog.
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT *
-- FROM [monitor].[TVF_ClassifyErrorLogEvent]
--      ('SQL', 'CUSTOM_RULE', N'Autogrow completed');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_ClassifyErrorLogEvent
CREATE OR ALTER FUNCTION [monitor].[TVF_ClassifyErrorLogEvent]
(
      @ProductName varchar(32)
    , @RuleCategory varchar(80)
    , @MessageText nvarchar(max)
)
RETURNS TABLE
AS
RETURN
(
    SELECT CONVERT(varchar(80),
        CASE
          WHEN @ProductName='SQL_AGENT' THEN 'AGENT_ERROR'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Error: 823%'
            OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Error: 824%'
            OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Error: 825%' THEN 'IO_ERROR'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%taking longer than 15 seconds%' THEN 'LONG_IO'
          WHEN (@MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Backup%'
             OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Restore%')
           AND (@MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%fail%'
             OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%error%') THEN 'BACKUP_RESTORE'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%cachestore flush%'
            OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%FlushCache%' THEN 'CACHE_FLUSH'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Autogrow%' THEN 'AUTOGROWTH'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Stack Dump%'
            OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Assertion%' THEN 'DUMP_ASSERTION'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Login failed%'
            OR @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%17830%' THEN 'LOGIN_CONNECTIVITY'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Log Shipping%' THEN 'LOG_SHIPPING'
          WHEN @MessageText COLLATE SQL_Latin1_General_CP1_CI_AS LIKE N'%Replication%' THEN 'REPLICATION'
          ELSE COALESCE(@RuleCategory,'UNCLASSIFIED')
        END) AS [Category]
);
GO
