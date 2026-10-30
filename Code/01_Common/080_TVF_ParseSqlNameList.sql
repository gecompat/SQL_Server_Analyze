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
               Für dort gültige Elemente prüft diese Funktion Teil 1 auf NULL
               (INVALID_SQL_NAME), danach Teil 2 auf einen Wert
               (MULTIPART_NAME_NOT_ALLOWED) und danach LEN(Teil 1)>128
               (SQL_NAME_TOO_LONG). Für IsValid=1 muss Teil 1 ungleich NULL
               und Teil 2 gleich NULL sein; LEN(Teil 1) darf höchstens 128 ergeben.
Grenzen      : Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine
               allgemeine SQL-Bezeichnervalidierung und keine Prüfung von
               Katalogexistenz oder Berechtigungen. Fehlerhafte Zeilen werden
               ausgegeben und nicht durch die Funktion als Fehler geworfen.
               Eine physische Reihenfolge ist erst mit ORDER BY ItemOrdinal
               zugesichert. Die Funktion liest keine Kataloge und speichert nichts.
Beispiel     : Der folgende Aufruf verwendet synthetische Namen:
               SELECT * FROM [monitor].[TVF_ParseSqlNameList](
                   N'[ColumnOne]|[Column With Spaces]|[Column|WithPipe]')
               ORDER BY ItemOrdinal;
===============================================================================
*/
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
        , [NameValue] = CONVERT(sysname, PARSENAME([l].[ItemText], 1))
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1
                     AND PARSENAME([l].[ItemText], 1) IS NOT NULL
                     AND PARSENAME([l].[ItemText], 2) IS NULL
                     AND LEN(PARSENAME([l].[ItemText], 1)) <= 128
                   THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN PARSENAME([l].[ItemText], 1) IS NULL THEN 'INVALID_SQL_NAME'
                   WHEN PARSENAME([l].[ItemText], 2) IS NOT NULL THEN 'MULTIPART_NAME_NOT_ALLOWED'
                   WHEN LEN(PARSENAME([l].[ItemText], 1)) > 128 THEN 'SQL_NAME_TOO_LONG'
              END)
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN PARSENAME([l].[ItemText], 1) IS NULL THEN N'Das Listenelement ist kein gültiger SQL-Name.'
                   WHEN PARSENAME([l].[ItemText], 2) IS NOT NULL THEN N'Für diesen Parameter ist nur ein einteiliger SQL-Name zulässig.'
                   WHEN LEN(PARSENAME([l].[ItemText], 1)) > 128 THEN N'Der SQL-Name überschreitet die sysname-Länge von 128 Zeichen.'
              END)
    FROM [monitor].[TVF_ParsePipeList](@List) AS [l]
);
GO
