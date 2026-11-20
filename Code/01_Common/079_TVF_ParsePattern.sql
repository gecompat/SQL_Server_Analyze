USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParsePattern
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Inline Table-valued Function
Zweck        : Zerlegt ein optionales LIKE- oder Regex-Präfix und liefert den
               unverändert verbleibenden Patterninhalt samt Modus und Flags.
SQL-Version  : Kompilierbar ab SQL Server 2019; die Regex-Ausführung erfolgt
               versionsadaptiv durch den Aufrufer auf SQL Server 2025 mit
               Compatibility Level 170. Der Parser prüft diese Voraussetzungen
               und die Regex-Syntax nicht.
Parameter    : @Pattern nvarchar(4000), ohne Default. Zuerst werden äußere
               Leerzeichen mit LTRIM/RTRIM entfernt. Danach wird ein Präfix
               regexi:, regex: oder like: ohne Beachtung der Großschreibung
               entfernt; der verbleibende Inhalt wird nicht erneut getrimmt.
Modi         : NONE bei NULL, REGEXI mit Flag i, REGEX mit Flag c und sonst
               LIKE. Auch ein leeres Präfix wie „like:“ ergibt LIKE.
Ergebnis     : Eine Zeile mit PatternMode, PatternValue, RegexFlags, IsRegex,
               IsValid, ErrorCode und ErrorMessage. NULL ergibt gültiges NONE.
               Ein leerer oder nur aus Leerzeichen bestehender Eingang sowie
               ein leeres Präfix-Ergebnis liefern EMPTY_PATTERN. IsValid
               prüft ausschließlich auf leeren Inhalt, nicht Syntax,
               Kompatibilität oder Treffer.
Beispiele   : SELECT * FROM [monitor].[TVF_ParsePattern](N' regexi:^App ');
               SELECT * FROM [monitor].[TVF_ParsePattern](N'LIKE:');
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ParsePattern 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ParsePattern"
-- schema_name: "monitor"
-- object_name: "TVF_ParsePattern"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Zerlegt ein optionales LIKE- oder Regex-Präfix und liefert den unverändert verbleibenden Patterninhalt samt Modus und Flags."
-- source_path: "Code/01_Common/079_TVF_ParsePattern.sql"
-- ---
-- 
-- # monitor.TVF_ParsePattern
-- 
-- ## Zweck und Einsatz
-- 
-- Zerlegt ein optionales LIKE- oder Regex-Präfix und liefert den unverändert verbleibenden Patterninhalt samt Modus und Flags.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParsePattern]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @Pattern | nvarchar(4000) | ja | kein Default |
-- 
-- **@Pattern:** Pflichtwert nvarchar(4000), kein Default. NULL ergibt gültigen Modus NONE; leerer oder nur aus Leerzeichen bestehender Text ergibt EMPTY_PATTERN. Äußere Leerzeichen werden entfernt, dann wird regexi:, regex: oder like: ohne Beachtung der Großschreibung erkannt. Ein leerer Inhalt nach Präfix ergibt EMPTY_PATTERN. Die Funktion validiert keine Regex-Syntax.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile pro Aufruf. Spalten: `PatternMode varchar(8)` (NONE, LIKE, REGEX oder REGEXI), `PatternValue nvarchar(4000)` in binär unterscheidender Kollation, `RegexFlags varchar(8)` (c/i oder NULL), `IsRegex bit`, `IsValid bit`, `ErrorCode varchar(40)` und `ErrorMessage nvarchar(4000)` (beide NULL bei gültiger Eingabe). Die Funktion prüft Syntaxform und Leerwert, führt aber keinen Regex aus.
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_ParsePattern](N' regexi:^App '); SELECT * FROM [monitor].[TVF_ParsePattern](N'LIKE:');
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_ParsePattern
CREATE OR ALTER FUNCTION [monitor].[TVF_ParsePattern]
(
    @Pattern nvarchar(4000)
)
RETURNS TABLE
AS
RETURN
(
    WITH [P] AS
    (
        SELECT [TrimmedPattern] = CASE WHEN @Pattern IS NULL THEN NULL
                                       ELSE LTRIM(RTRIM(@Pattern)) END
    ),
    [N] AS
    (
        SELECT
              [PatternMode] = CONVERT(varchar(8),
                  CASE WHEN [TrimmedPattern] IS NULL THEN 'NONE'
                       WHEN UPPER(LEFT([TrimmedPattern], 7)) = 'REGEXI:' THEN 'REGEXI'
                       WHEN UPPER(LEFT([TrimmedPattern], 6)) = 'REGEX:'  THEN 'REGEX'
                       WHEN UPPER(LEFT([TrimmedPattern], 5)) = 'LIKE:'   THEN 'LIKE'
                       ELSE 'LIKE' END)
            , [PatternValue] = CONVERT(nvarchar(4000),
                  CASE WHEN [TrimmedPattern] IS NULL THEN NULL
                       WHEN UPPER(LEFT([TrimmedPattern], 7)) = 'REGEXI:' THEN SUBSTRING([TrimmedPattern], 8, 4000)
                       WHEN UPPER(LEFT([TrimmedPattern], 6)) = 'REGEX:'  THEN SUBSTRING([TrimmedPattern], 7, 4000)
                       WHEN UPPER(LEFT([TrimmedPattern], 5)) = 'LIKE:'   THEN SUBSTRING([TrimmedPattern], 6, 4000)
                       ELSE [TrimmedPattern] END)
        FROM [P]
    )
    SELECT
          [PatternMode]
        , [PatternValue] COLLATE SQL_Latin1_General_CP1_CS_AS AS [PatternValue]
        , CONVERT(varchar(8), CASE WHEN [PatternMode] = 'REGEXI' THEN 'i'
                                   WHEN [PatternMode] = 'REGEX' THEN 'c'
                              END) AS [RegexFlags]
        , CONVERT(bit, CASE WHEN [PatternMode] IN ('REGEX', 'REGEXI') THEN 1 ELSE 0 END) AS [IsRegex]
        , CONVERT(bit, CASE WHEN [PatternMode] = 'NONE' THEN 1
                            WHEN NULLIF([PatternValue], N'') IS NULL THEN 0
                            ELSE 1 END) AS [IsValid]
        , CONVERT(varchar(40), CASE WHEN [PatternMode] <> 'NONE' AND NULLIF([PatternValue], N'') IS NULL
                                    THEN 'EMPTY_PATTERN' END) AS [ErrorCode]
        , CONVERT(nvarchar(4000), CASE WHEN [PatternMode] <> 'NONE' AND NULLIF([PatternValue], N'') IS NULL
                                       THEN N'Das Pattern darf nach dem Präfix nicht leer sein.' END) AS [ErrorMessage]
    FROM [N]
);
GO
