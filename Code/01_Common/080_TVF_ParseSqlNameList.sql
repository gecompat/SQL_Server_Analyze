USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseSqlNameList
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Inline Table-valued Function
Zweck        : Prüft die Namen einer bracket-aware Pipe-Liste anhand von
               PARSENAME und liefert die in sysname konvertierten Namenswerte.
Parameter    : @List nvarchar(max) besitzt keinen Default. NULL liefert keine
               Zeile; N'' liefert eine ungültige Zeile mit EMPTY_LIST.
Struktur     : | trennt nur außerhalb von [...]; innerhalb gehört es zum Wert.
               ]] maskiert eine schließende Klammer. TVF_ParsePipeList entfernt
               äußere Leerzeichen der Elemente und vergibt ItemOrdinal ab 1.
               Leere Elemente bleiben als ungültige Zeilen erhalten; gleiche
               Elemente werden nicht zusammengefasst. Ein Rohsegment mit mehr
               als 4000 UTF-16-Codeeinheiten erhält ITEM_TOO_LONG und ItemText=NULL.
Ausgabe      : ItemOrdinal und ItemText beschreiben die Eingabe. NameValue wird
               auch bei ungültigen Zeilen aus PARSENAME(ItemText,1) berechnet.
               IsValid, ErrorCode und ErrorMessage kennzeichnen die Prüfung;
               ein nicht leeres NameValue ersetzt deshalb keine IsValid-Prüfung.
Fehler       : EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente
               prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach
               EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Seine Fehler
               haben Vorrang vor der nachfolgenden Namensprüfung.
               Für dort gültige Elemente folgt INVALID_SQL_NAME bei fehlendem
               Teil 1. Ein vorhandener Teil 2 oder ein Punkt außerhalb eines
               einzelnen vollständig quotierten Namens ergibt
               MULTIPART_NAME_NOT_ALLOWED, auch bei ausgelassenem Qualifizierer.
               LEN(Teil 1)>128 ergibt SQL_NAME_TOO_LONG.
Grenzen      : Punkte innerhalb genau eines vollständig quotierten Namens
               bleiben zulässig. Die Funktion prüft weder die vollständige
               Bezeichnergrammatik noch Katalogexistenz oder Berechtigungen.
               Fehlerhafte Elemente werden als Zeilen ausgegeben.
               Eine physische Reihenfolge ist erst mit ORDER BY ItemOrdinal
               zugesichert. Die Funktion liest keine Kataloge und speichert nichts.
Beispiel     : Der folgende Aufruf verwendet synthetische Namen:
               SELECT * FROM [monitor].[TVF_ParseSqlNameList](
                   N'[ColumnOne]|[Column With Spaces]|[Column|WithPipe]')
               ORDER BY ItemOrdinal;
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ParseSqlNameList 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ParseSqlNameList"
-- schema_name: "monitor"
-- object_name: "TVF_ParseSqlNameList"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Prüft die Namen einer bracket-aware Pipe-Liste anhand von PARSENAME und liefert die in sysname konvertierten Namenswerte."
-- source_path: "Code/01_Common/080_TVF_ParseSqlNameList.sql"
-- ---
-- 
-- # monitor.TVF_ParseSqlNameList
-- 
-- ## Zweck und Einsatz
-- 
-- Prüft die Namen einer bracket-aware Pipe-Liste anhand von PARSENAME und liefert die in sysname konvertierten Namenswerte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseSqlNameList]. Die Funktion nutzt [monitor].[TVF_ParsePipeList] für die bracketbewusste Zerlegung und prüft die resultierenden Namen; sie liest selbst keine DMVs, fremden Datenbanken oder Dateien. Die Ausführbarkeit der installierten Funktionskette hängt vom Datenbankkontext und dessen Berechtigungsauflösung ab; ein gesonderter GRANT auf jede interne Abhängigkeit wird daraus nicht behauptet.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @List | nvarchar(max) | ja | kein Default |
-- 
-- **@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeile, N'' eine ungültige EMPTY_LIST-Zeile. Pipe trennt nur außerhalb eckiger Klammern, ]] maskiert eine schließende Klammer. Leere Elemente und Duplikate bleiben erhalten; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ITEM_TOO_LONG.
-- 
-- ## Resultate und Ausgabe
-- 
-- ItemOrdinal und ItemText beschreiben die Eingabe. NameValue wird auch bei ungültigen Zeilen aus PARSENAME(ItemText,1) berechnet. IsValid, ErrorCode und ErrorMessage kennzeichnen die Prüfung; ein nicht leeres NameValue ersetzt deshalb keine IsValid-Prüfung.
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_ParseSqlNameList](
--                    N'[ColumnOne]|[Column With Spaces]|[Column|WithPipe]')
--                ORDER BY ItemOrdinal;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Seine Fehler haben Vorrang. Für dort gültige Elemente folgt INVALID_SQL_NAME bei fehlendem Teil 1. Ein vorhandener Teil 2 oder ein Punkt außerhalb eines einzelnen vollständig quotierten Namens führt zu MULTIPART_NAME_NOT_ALLOWED. Das gilt auch für ausgelassene Qualifizierer. Die anschließende Längenprüfung von Teil 1 verwendet LEN und meldet SQL_NAME_TOO_LONG bei mehr als 128 Zeichen.
-- 
-- Ein Punkt innerhalb eines einzelnen mit eckigen Klammern oder doppelten Anführungszeichen quotierten Namens ist zulässig. Der Vergleich mit der quotierten Form des nativen Namens erfolgt bytegenau. Die Funktion prüft weder die vollständige SQL-Bezeichnergrammatik noch Katalogexistenz oder Berechtigungen. Sie gibt fehlerhafte Zeilen mit Fehlercode aus, liest keine Kataloge und schreibt keine Daten. Eine physische Reihenfolge erfordert ORDER BY ItemOrdinal.
-- 
-- USAGE_SKILL_END monitor.TVF_ParseSqlNameList
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseSqlNameList]
(
    @List nvarchar(max)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          [l].[ItemOrdinal]
        , [l].[ItemText]
        , [NameValue] = CONVERT(sysname, [parsed].[NameValue])
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1 AND [checked].[ErrorCode] IS NULL THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40), [checked].[ErrorCode])
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE [checked].[ErrorCode]
                   WHEN 'INVALID_SQL_NAME' THEN N'Das Listenelement ist kein gültiger SQL-Name.'
                   WHEN 'MULTIPART_NAME_NOT_ALLOWED' THEN N'Für diesen Parameter ist nur ein einteiliger SQL-Name zulässig.'
                   WHEN 'SQL_NAME_TOO_LONG' THEN N'Der SQL-Name überschreitet die sysname-Länge von 128 Zeichen.'
                   ELSE [l].[ErrorMessage]
              END)
    FROM [monitor].[TVF_ParsePipeList](@List) AS [l]
    CROSS APPLY (VALUES (PARSENAME([l].[ItemText], 1), PARSENAME([l].[ItemText], 2),
                         CONVERT(varbinary(8000), [l].[ItemText]))) AS [parsed]([NameValue], [Qualifier], [OriginalBytes])
    CROSS APPLY (VALUES (
        CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
             WHEN [parsed].[NameValue] IS NULL THEN 'INVALID_SQL_NAME'
             WHEN [parsed].[Qualifier] IS NOT NULL
               OR (CHARINDEX(N'.', [l].[ItemText] COLLATE Latin1_General_100_BIN2) > 0
                   AND [parsed].[OriginalBytes] NOT IN
                      (CONVERT(varbinary(8000), QUOTENAME([parsed].[NameValue])),
                       CONVERT(varbinary(8000), QUOTENAME([parsed].[NameValue], N'"'))))
                 THEN 'MULTIPART_NAME_NOT_ALLOWED'
             WHEN LEN([parsed].[NameValue]) > 128 THEN 'SQL_NAME_TOO_LONG'
        END
    )) AS [checked]([ErrorCode])
);
GO
