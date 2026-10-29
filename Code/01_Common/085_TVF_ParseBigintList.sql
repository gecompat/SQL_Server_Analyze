USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseBigintList
Version      : 1.1.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Zerlegt eine Liste ganzzahliger bigint-Werte. Pipe, Beistrich
               und Strichpunkt sind gleichwertige Trennzeichen und dürfen
               gemischt auftreten.
Parameter    : @List ist eine nvarchar(max)-Liste ohne Standardwert. NULL liefert
               keine Zeilen. N'' liefert eine ungültige Zeile mit EMPTY_LIST;
               eine reine Leerzeichenfolge ergibt nach dem Trimmen EMPTY_ITEM.
Struktur     : Pipe trennt nur außerhalb von [...]; innerhalb ist sie Teil des
               Werts. ]] maskiert eine schließende Klammer. Äußere Leerzeichen
               werden entfernt; Rohsegmente über 4000 UTF-16-Codeeinheiten
               erhalten ITEM_TOO_LONG und ItemText=NULL.
Resultset    : ItemOrdinal, ItemText, NumberValue, IsValid, ErrorCode und
               ErrorMessage. Die Listenzerlegung erhält Reihenfolge und
               Duplikate; ungültige Elemente bleiben als Zeilen erhalten.
Prüfung      : Alle Beistriche und Strichpunkte werden vor der bracket-aware
               Pipe-Zerlegung in Pipe-Zeichen umgewandelt, auch innerhalb
               eckiger Klammern. NumberValue entsteht durch TRY_CONVERT(bigint)
               auf dem an den Rändern getrimmten ItemText. Der Text wird dabei
               nicht entquotet. Es gibt weder einen zusätzlichen ID-Bereichs-
               filter noch eine Deduplizierung. NULL in NumberValue kann bei
               IsValid=0 durch INVALID_BIGINT entstehen; aus einem nicht-NULL-
               Zahlenwert allein folgt keine gültige Zeile.
Fehlerfolge  : EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente
               gilt ITEM_TOO_LONG vor EMPTY_ITEM vor INVALID_BRACKET_SYNTAX.
               Erst bei gültiger Listenstruktur kennzeichnet eine gescheiterte
               bigint-Konvertierung das Element als INVALID_BIGINT.
Hinweis      : Negative konvertierbare Werte können gültig sein; ein zulässiger
               ID-Bereich wird erst beim Verbraucher geprüft. NULL in NumberValue
               ist kein gültiger Zahlenwert. Eine physische Reihenfolge ist nur
               mit ORDER BY ItemOrdinal zugesichert.
Beispiel     : SELECT * FROM monitor.TVF_ParseBigintList(N'57|61, -2;57')
               ORDER BY ItemOrdinal;
Aenderungen  : 1.1.0 - Beistrich und Strichpunkt als weitere Trennzeichen.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseBigintList]
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
        , [NumberValue] = TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText])))
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1
                     AND TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NOT NULL
                   THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN 'INVALID_BIGINT' END)
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN N'Das Listenelement ist keine gültige bigint-Ganzzahl.' END)
    FROM [monitor].[TVF_ParsePipeList]
         (TRANSLATE(@List, N',;', N'||')) AS [l]
);
GO
