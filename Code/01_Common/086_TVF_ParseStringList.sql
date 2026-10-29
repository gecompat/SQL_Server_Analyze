USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseStringList
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Inline Table-valued Function
Zweck        : Liefert allgemeine Textwerte aus einer bracket-aware Pipe-Liste;
               ein Punkt besitzt hier keine Bedeutung als Mehrteilname.
Parameter    : @List nvarchar(max) besitzt keinen Default. NULL liefert keine
               Zeile; N'' liefert eine ungültige Zeile mit EMPTY_LIST.
Struktur     : | trennt nur außerhalb von [...]; innerhalb gehört es zum Wert.
               ]] maskiert eine schließende Klammer. TVF_ParsePipeList entfernt
               äußere Leerzeichen und vergibt ItemOrdinal ab 1. Leere Elemente
               bleiben als ungültige Zeilen erhalten. Gleiche Werte werden
               nicht zusammengefasst. Rohsegmente mit mehr als 4000 UTF-16-
               Codeeinheiten erhalten ITEM_TOO_LONG und ItemText=NULL.
Werte        : ItemText enthält die getrimmte Schreibweise. StringValue entfernt
               bei bracket-quotierten Elementen die äußeren Klammern und ersetzt
               ]] durch ]. Der Wert wird in nvarchar(4000) konvertiert und unter
               SQL_Latin1_General_CP1_CS_AS zurückgegeben. Ein nach der Entquotung
               leerer Wert ist ebenfalls ungültig.
Ausgabe      : ItemOrdinal, ItemText, StringValue, IsValid, ErrorCode und
               ErrorMessage beschreiben jedes Element. StringValue wird auch
               für ungültige Elemente berechnet; Verbraucher müssen IsValid
               prüfen und dürfen Gültigkeit nicht aus dem Wert allein ableiten.
Fehler       : EMPTY_LIST ist der Sonderfall der leeren Eingabe. Bei Elementen
               prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach
               EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Diese Fehler
               haben Vorrang; erst bei gültigem Parserergebnis kennzeichnet
               diese Funktion einen leeren entquoteten Wert als EMPTY_VALUE.
Grenzen      : Fehlerhafte Elemente bleiben als Ergebniszeilen erhalten und
               werden nicht als Fehler geworfen. Eine physische Reihenfolge ist
               erst mit ORDER BY ItemOrdinal zugesichert. Die Funktion prüft
               keine Katalogexistenz und liest oder persistiert keine Fachdaten.
Beispiel     : Der folgende Aufruf verwendet synthetische Textwerte:
               SELECT * FROM monitor.TVF_ParseStringList(
                   N'[Sample.Loader]|[Text with | delimiter]|[right]]bracket]')
               ORDER BY ItemOrdinal;
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseStringList]
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
        , [StringValue] = CONVERT
          (
              nvarchar(4000),
              CASE WHEN [l].[IsBracketQuoted] = 1
                   THEN REPLACE(SUBSTRING([l].[ItemText], 2, LEN([l].[ItemText]) - 2), N']]', N']')
                   ELSE [l].[ItemText]
              END
          ) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [IsValid] = CONVERT
          (
              bit,
              CASE WHEN [l].[IsValid] = 1
                      AND NULLIF
                          (
                              CASE WHEN [l].[IsBracketQuoted] = 1
                                   THEN REPLACE(SUBSTRING([l].[ItemText], 2, LEN([l].[ItemText]) - 2), N']]', N']')
                                   ELSE [l].[ItemText]
                              END,
                              N''
                          ) IS NOT NULL
                   THEN 1 ELSE 0 END
          )
        , [ErrorCode] = CONVERT
          (
              varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN NULLIF
                        (
                            CASE WHEN [l].[IsBracketQuoted] = 1
                                 THEN REPLACE(SUBSTRING([l].[ItemText], 2, LEN([l].[ItemText]) - 2), N']]', N']')
                                 ELSE [l].[ItemText]
                            END,
                            N''
                        ) IS NULL THEN 'EMPTY_VALUE'
              END
          )
        , [ErrorMessage] = CONVERT
          (
              nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN NULLIF
                        (
                            CASE WHEN [l].[IsBracketQuoted] = 1
                                 THEN REPLACE(SUBSTRING([l].[ItemText], 2, LEN([l].[ItemText]) - 2), N']]', N']')
                                 ELSE [l].[ItemText]
                            END,
                            N''
                        ) IS NULL THEN N'Der Listenwert darf nicht leer sein.'
              END
          )
    FROM [monitor].[TVF_ParsePipeList](@List) AS [l]
);
GO
