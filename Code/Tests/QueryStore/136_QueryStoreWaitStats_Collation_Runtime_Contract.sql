USE [DeineDatenbank];
GO

/*
Datei: 136_QueryStoreWaitStats_Collation_Runtime_Contract.sql
Zweck: Prüft den strukturierten Leerlistenvertrag von USP_QueryStoreWaitStats.
Datenschutz: Es werden keine Query-Store-Datenbanken, Query-Texte oder Wait-Details gelesen, ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N''
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54970, N'Der QueryStoreWaitStats-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.waitStats') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54971, N'Der QueryStoreWaitStats-Collationvertrag lieferte keinen vollständigen Leerlistenstatus.', 1;
GO
