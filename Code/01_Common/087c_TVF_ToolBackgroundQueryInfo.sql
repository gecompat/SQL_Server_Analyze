USE [DeineDatenbank];
GO

/*
Die Inline-Tabellenfunktion ordnet einen einzelnen clientseitig gelieferten
program_name-Wert anhand der lokalen Regeltabelle einer Diagnosekategorie zu.
@ProgramName hat den Typ nvarchar(128) und keinen Default. Die Funktion liest
nur monitor.ToolBackgroundQueryPattern mit NOLOCK; sie greift weder auf DMVs
noch auf SQL-Text oder fremde Datenbanken zu und speichert selbst keine Daten.

Das Ergebnis hat genau eine Zeile und fünf Spalten: IsToolBackgroundQuery
(bit) sowie ToolBackgroundRuleCode, ToolBackgroundCategory,
ToolBackgroundDetection und ToolBackgroundConfidence. Es gilt die aktivierte
Regel mit der höchsten Priority; bei Gleichstand entscheidet RuleCode
aufsteigend gemäß der vorhandenen Collation. Der Vergleich verwendet
Latin1_General_100_CI_AS und SQL-LIKE-Semantik, einschließlich der
Platzhalterzeichen %, _ und []. Bei keinem Treffer liefert die Funktion
IsToolBackgroundQuery=0 und NULL für die vier Metadatenspalten. Ein leerer
Eingabewert ist kein Sonderfall ohne Treffer und kann eine konfigurierte
Wildcard-Regel erfüllen.

Ein Treffer ist eine Heuristik ohne Sicherheitswirkung: program_name wird
clientseitig gesetzt und kann vorgetäuscht werden. Ein Nichttreffer ohne
Widerspruch autorisiert keine Schlussfolgerung. HIGH, MEDIUM und LOW sind
Kennzeichnungen und keine Wahrscheinlichkeiten. Dieses synthetische Beispiel
wertet den Beispielwert gegen die lokal konfigurierte Regelmenge aus und
erfasst keine Analysedaten:

SELECT *
FROM [monitor].[TVF_ToolBackgroundQueryInfo](N'Beispielprogramm');


===============================================================================
Objekt       : monitor.TVF_ToolBackgroundQueryInfo
Version      : 1.1.0
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Wertet aktivierte LIKE-Regeln aus ToolBackgroundQueryPattern aus.
Vertrag      : Heuristik für die Diagnoseausgabe, kein Sicherheitsmerkmal.
Eigenlast    : Kein DMV-, SQL-Text- oder fremder Datenbankzugriff.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ToolBackgroundQueryInfo 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ToolBackgroundQueryInfo"
-- schema_name: "monitor"
-- object_name: "TVF_ToolBackgroundQueryInfo"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Wertet aktivierte LIKE-Regeln aus ToolBackgroundQueryPattern aus."
-- source_path: "Code/01_Common/087c_TVF_ToolBackgroundQueryInfo.sql"
-- ---
-- 
-- # monitor.TVF_ToolBackgroundQueryInfo
-- 
-- ## Zweck und Einsatz
-- 
-- Wertet aktivierte LIKE-Regeln aus ToolBackgroundQueryPattern aus.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht SELECT auf [monitor].[TVF_ToolBackgroundQueryInfo] im vorgesehenen Datenbankkontext. Die Funktion liest aktive Muster aus `monitor.ToolBackgroundQueryPattern` und vergleicht den übergebenen Programmnamen; sie greift nicht auf laufende SQL-Texte zu.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @ProgramName | nvarchar(128) | ja | kein Default |
-- 
-- **@ProgramName:** Pflichtwert nvarchar(128), kein Default. Ein einzelner Programmname für Musterabgleich; die Funktion liest nur monitor.ToolBackgroundQueryPattern, weder DMV noch SQL-Text. NULL oder leerer Text ergibt nach den vorhandenen Musterregeln keinen belegten Programmnamen.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile pro Aufruf. Spalten: `IsToolBackgroundQuery bit`, `ToolBackgroundRuleCode varchar(64)`, `ToolBackgroundCategory varchar(40)`, `ToolBackgroundDetection varchar(40)` und `ToolBackgroundConfidence varchar(16)`. Die vier Regelspalten sind NULL ohne aktiv passende Regel. Ein TOP-1-Treffer folgt Priority absteigend und RuleCode; die Funktion liest nur konfigurierte Programmnamenmuster, keine laufenden Querytexte.
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_ToolBackgroundQueryInfo](N'Beispielprogramm');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_ToolBackgroundQueryInfo
CREATE OR ALTER FUNCTION [monitor].[TVF_ToolBackgroundQueryInfo]
(
    @ProgramName nvarchar(128)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          [IsToolBackgroundQuery] = CONVERT
            (
                bit,
                CASE WHEN [rule].[RuleCode] IS NULL THEN 0 ELSE 1 END
            )
        , [ToolBackgroundRuleCode] = [rule].[RuleCode]
        , [rule].[ToolBackgroundCategory]
        , [rule].[ToolBackgroundDetection]
        , [rule].[ToolBackgroundConfidence]
    FROM (VALUES (CONVERT(bit, 1))) AS [seed]([Value])
    OUTER APPLY
    (
        SELECT TOP (1)
              [p].[RuleCode]
            , [p].[ToolBackgroundCategory]
            , [p].[ToolBackgroundDetection]
            , [p].[ToolBackgroundConfidence]
        FROM [monitor].[ToolBackgroundQueryPattern] AS [p] WITH (NOLOCK)
        WHERE [p].[IsEnabled] = 1
          AND @ProgramName COLLATE Latin1_General_100_CI_AS
              LIKE [p].[ProgramNameLikePattern] COLLATE Latin1_General_100_CI_AS
        ORDER BY [p].[Priority] DESC, [p].[RuleCode]
    ) AS [rule]
);
GO
