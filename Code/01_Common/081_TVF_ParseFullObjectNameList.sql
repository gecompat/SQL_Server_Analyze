USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseFullObjectNameList
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Inline Table-valued Function
Zweck        : Zerlegt eine Pipe-Liste und prüft ein-, zwei- oder dreiteilige
               Objektbezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt.
               Vierteilige Bezüge mit Linked Server werden abgewiesen.
Parameter    : @List ist eine nvarchar(max)-Liste ohne Standardwert. NULL liefert
               keine Zeilen. N'' liefert eine ungültige Zeile mit EMPTY_LIST;
               eine reine Leerzeichenfolge ergibt nach dem Trimmen EMPTY_ITEM.
Struktur     : Pipe trennt nur außerhalb von [...]; innerhalb ist sie Teil des
               Werts. ]] maskiert eine schließende Klammer. Äußere Leerzeichen
               werden entfernt; Rohsegmente über 4000 UTF-16-Codeeinheiten
               erhalten ITEM_TOO_LONG und ItemText=NULL.
Resultset    : ItemOrdinal, ItemText, DatabaseName, SchemaName, ObjectName,
               PartCount, IsValid, ErrorCode und ErrorMessage. Die drei
               Namensfelder enthalten die von PARSENAME entquoteten Bestandteile
               als sysname. PartCount ist 3 bei vorhandenem Teil 3, sonst 2 bei
               Teil 2, sonst 1 bei Teil 1 und sonst 0; Teil 4 wird dabei nicht
               gezählt. Dieser Wert wird unabhängig von IsValid berechnet.
               Ungültige Listenelemente behalten ihre Fehlerangaben; vorhandene
               Namenswerte oder PartCount beweisen allein keine Gültigkeit.
               Duplikate bleiben erhalten. Die physische Reihenfolge erfordert
               ORDER BY ItemOrdinal.
Prüfung      : Die Funktion löst keinen nicht angegebenen Datenbank- oder
               Schemanamen auf und prüft weder Existenz noch Berechtigungen.
               Sie beansprucht keine allgemeine SQL-Syntaxvalidierung.
Fehlerfolge  : Fehler der Listenzerlegung werden übernommen. Bei leerer Eingabe
               gilt EMPTY_LIST als Sonderfall. Für Elementfehler gilt danach
               ITEM_TOO_LONG vor EMPTY_ITEM vor INVALID_BRACKET_SYNTAX. Bei
               gültiger Listenstruktur folgen INVALID_OBJECT_REFERENCE bei
               fehlendem Objektteil, FOUR_PART_NAME_NOT_ALLOWED bei vorhandenem
               Teil 4 und SCHEMA_NAME_REQUIRED bei Teil 3 ohne Teil 2. Die letzte
               CASE-Regel SQL_NAME_TOO_LONG prüft die Länge geparster Teile.
               PARSENAME liefert für überlange Bestandteile bereits NULL; daher
               ist für eine Längenverletzung kein bestimmter Fehlercode
               zugesichert und eine frühere Regel kann greifen.
Beispiel     : SELECT * FROM [monitor].[TVF_ParseFullObjectNameList](
                   N'[DeineDatenbank].dbo.[IrgendeinObjekt]|dbo.AnderesObjekt')
               ORDER BY ItemOrdinal;
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseFullObjectNameList]
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
        , [DatabaseName] = CONVERT(sysname, PARSENAME([l].[ItemText], 3))
        , [SchemaName]   = CONVERT(sysname, PARSENAME([l].[ItemText], 2))
        , [ObjectName]   = CONVERT(sysname, PARSENAME([l].[ItemText], 1))
        , [PartCount]    = CONVERT(tinyint,
              CASE WHEN PARSENAME([l].[ItemText], 3) IS NOT NULL THEN 3
                   WHEN PARSENAME([l].[ItemText], 2) IS NOT NULL THEN 2
                   WHEN PARSENAME([l].[ItemText], 1) IS NOT NULL THEN 1
                   ELSE 0 END)
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1
                     AND PARSENAME([l].[ItemText], 1) IS NOT NULL
                     AND PARSENAME([l].[ItemText], 4) IS NULL
                     AND NOT (PARSENAME([l].[ItemText], 3) IS NOT NULL
                              AND PARSENAME([l].[ItemText], 2) IS NULL)
                     AND LEN(PARSENAME([l].[ItemText], 1)) <= 128
                     AND COALESCE(LEN(PARSENAME([l].[ItemText], 2)), 0) <= 128
                     AND COALESCE(LEN(PARSENAME([l].[ItemText], 3)), 0) <= 128
                   THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN PARSENAME([l].[ItemText], 1) IS NULL THEN 'INVALID_OBJECT_REFERENCE'
                   WHEN PARSENAME([l].[ItemText], 4) IS NOT NULL THEN 'FOUR_PART_NAME_NOT_ALLOWED'
                   WHEN PARSENAME([l].[ItemText], 3) IS NOT NULL
                    AND PARSENAME([l].[ItemText], 2) IS NULL THEN 'SCHEMA_NAME_REQUIRED'
                   WHEN LEN(PARSENAME([l].[ItemText], 1)) > 128
                     OR COALESCE(LEN(PARSENAME([l].[ItemText], 2)), 0) > 128
                     OR COALESCE(LEN(PARSENAME([l].[ItemText], 3)), 0) > 128 THEN 'SQL_NAME_TOO_LONG'
              END)
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN PARSENAME([l].[ItemText], 1) IS NULL THEN N'Der Objektbezug ist syntaktisch ungültig.'
                   WHEN PARSENAME([l].[ItemText], 4) IS NOT NULL THEN N'Vierteilige Linked-Server-Namen werden nicht unterstützt.'
                   WHEN PARSENAME([l].[ItemText], 3) IS NOT NULL
                    AND PARSENAME([l].[ItemText], 2) IS NULL THEN N'Bei einem dreiteiligen Objektbezug ist das Schema erforderlich.'
                   WHEN LEN(PARSENAME([l].[ItemText], 1)) > 128
                     OR COALESCE(LEN(PARSENAME([l].[ItemText], 2)), 0) > 128
                     OR COALESCE(LEN(PARSENAME([l].[ItemText], 3)), 0) > 128 THEN N'Mindestens ein Namensbestandteil überschreitet die sysname-Länge von 128 Zeichen.'
              END)
    FROM [monitor].[TVF_ParsePipeList](@List) AS [l]
);
GO
