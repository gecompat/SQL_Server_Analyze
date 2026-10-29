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
