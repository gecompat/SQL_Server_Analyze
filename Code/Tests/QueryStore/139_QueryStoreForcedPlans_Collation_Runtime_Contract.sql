USE [DeineDatenbank];
GO

/*
Datei: 139_QueryStoreForcedPlans_Collation_Runtime_Contract.sql
Zweck: Prüft den strukturierten Leerlistenvertrag von USP_QueryStoreForcedPlans.
Datenschutz: Es werden keine Query-Store-Datenbanken, Query-Texte oder Plan-XML gelesen, ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreForcedPlans]
      @QueryStoreDatabaseNames = N''
    , @MitPlanXml = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'Der QueryStoreForcedPlans-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.forcedPlans') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 55001, N'Der QueryStoreForcedPlans-Collationvertrag lieferte keinen vollständigen Leerlistenstatus.', 1;
GO
