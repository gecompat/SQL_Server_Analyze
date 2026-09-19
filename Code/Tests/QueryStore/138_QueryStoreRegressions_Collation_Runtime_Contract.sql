USE [DeineDatenbank];
GO

/*
Datei: 138_QueryStoreRegressions_Collation_Runtime_Contract.sql
Zweck: Prüft den strukturierten Leerlistenvertrag von USP_QueryStoreRegressions.
Datenschutz: Es werden keine Query-Store-Datenbanken, Query-Texte oder Regressionsergebnisse gelesen, ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames = N''
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54990, N'Der QueryStoreRegressions-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.regressions') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54991, N'Der QueryStoreRegressions-Collationvertrag lieferte keinen vollständigen Leerlistenstatus.', 1;
GO
