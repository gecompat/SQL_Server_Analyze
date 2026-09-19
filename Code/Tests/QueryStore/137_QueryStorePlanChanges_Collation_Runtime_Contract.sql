USE [DeineDatenbank];
GO

/*
Datei: 137_QueryStorePlanChanges_Collation_Runtime_Contract.sql
Zweck: Prüft den strukturierten Leerlistenvertrag von USP_QueryStorePlanChanges.
Datenschutz: Es werden keine Query-Store-Datenbanken, Query-Texte oder Plan-XML gelesen, ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames = N''
    , @MitPlanXml = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54980, N'Der QueryStorePlanChanges-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
    OR JSON_QUERY(@Json, '$.queries') IS NULL
    OR JSON_QUERY(@Json, '$.plans') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54981, N'Der QueryStorePlanChanges-Collationvertrag lieferte keinen vollständigen Leerlistenstatus.', 1;
GO
