USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretDatabaseMailStatus
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Klassifiziert aggregierte Database-Mail-Status ohne
               Seiteneffekte.
Eingaben     : @SentStatus (varchar(8)); NULL und alle Werte außerhalb
               'failed', 'unsent' und 'retrying' fallen in die informative
               Regel. Der Textvergleich folgt der Datenbankkollation und
               garantiert keine Unterscheidung von Groß-/Kleinschreibung.
Ausgabe      : Genau eine Zeile mit FindingCode (varchar(100)) und
               FindingSeverity (varchar(16)). 'failed' ergibt
               DATABASE_MAIL_FAILED_IN_WINDOW/HIGH; 'unsent' und 'retrying'
               ergeben DATABASE_MAIL_PENDING_IN_WINDOW/MEDIUM; sonst
               DATABASE_MAIL_STATUS_INFORMATIONAL/INFO.
Beispiel     : SELECT FindingCode, FindingSeverity
                 FROM monitor.TVF_InterpretDatabaseMailStatus('failed');
               Erwartet: DATABASE_MAIL_FAILED_IN_WINDOW / HIGH.
Grenzen      : Die Funktion klassifiziert nur den übergebenen Status; sie
               liest weder Mail-Verlauf noch Kataloge und führt keinen Versand
               aus. Das Ergebnis beweist weder Zustellung noch Fehlerursache.
Datenschutz  : Verarbeitet ausschließlich den technischen Versandstatus; keine
               Adresse, Empfänger, Betreffzeile oder Nachricht.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_InterpretDatabaseMailStatus 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_InterpretDatabaseMailStatus"
-- schema_name: "monitor"
-- object_name: "TVF_InterpretDatabaseMailStatus"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Klassifiziert aggregierte Database-Mail-Status ohne Seiteneffekte."
-- source_path: "Code/01_Common/094_TVF_InterpretDatabaseMailStatus.sql"
-- ---
-- 
-- # monitor.TVF_InterpretDatabaseMailStatus
-- 
-- ## Zweck und Einsatz
-- 
-- Klassifiziert aggregierte Database-Mail-Status ohne Seiteneffekte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretDatabaseMailStatus]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SentStatus | varchar(8) | ja | kein Default |
-- 
-- **@SentStatus:** Pflichtwert varchar(8), kein Default. 'failed' ergibt DATABASE_MAIL_FAILED_IN_WINDOW/HIGH, 'unsent' oder 'retrying' MEDIUM, alle anderen Werte einschließlich NULL INFO. Vergleich folgt der Datenbankcollation; es wird kein Mail-Verlauf gelesen oder Versand ausgeführt.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile mit FindingCode (varchar(100)) und FindingSeverity (varchar(16)). 'failed' ergibt DATABASE_MAIL_FAILED_IN_WINDOW/HIGH; 'unsent' und 'retrying' ergeben DATABASE_MAIL_PENDING_IN_WINDOW/MEDIUM; sonst DATABASE_MAIL_STATUS_INFORMATIONAL/INFO.
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT FindingCode, FindingSeverity FROM monitor.TVF_InterpretDatabaseMailStatus('failed');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Die Funktion klassifiziert nur den übergebenen Status; sie liest weder Mail-Verlauf noch Kataloge und führt keinen Versand aus. Das Ergebnis beweist weder Zustellung noch Fehlerursache.
-- 
-- USAGE_SKILL_END monitor.TVF_InterpretDatabaseMailStatus
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretDatabaseMailStatus]
(
    @SentStatus varchar(8)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [FindingCode] = CONVERT(varchar(100),
              CASE WHEN @SentStatus='failed' THEN 'DATABASE_MAIL_FAILED_IN_WINDOW'
                   WHEN @SentStatus IN ('unsent','retrying') THEN 'DATABASE_MAIL_PENDING_IN_WINDOW'
                   ELSE 'DATABASE_MAIL_STATUS_INFORMATIONAL' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN @SentStatus='failed' THEN 'HIGH'
                   WHEN @SentStatus IN ('unsent','retrying') THEN 'MEDIUM'
                   ELSE 'INFO' END)
);
GO
