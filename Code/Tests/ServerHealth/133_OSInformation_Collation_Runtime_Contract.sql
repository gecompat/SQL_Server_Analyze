USE [DeineDatenbank];
GO

/*
Datei: 133_OSInformation_Collation_Runtime_Contract.sql
Zweck: Prüft den JSON-Vertrag von USP_OSInformation mit explizit kollationierten Arbeitstabellen.
Datenschutz: Host- und Dienstinformationen werden nicht ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @StatusCode varchar(40) = NULL;
DECLARE @IsPartial bit = NULL;

EXEC [monitor].[USP_OSInformation]
      @PrintMeldungen = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT;

IF ISJSON(@Json) <> 1
    THROW 54940, N'Der OSInformation-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF @StatusCode <> 'AVAILABLE'
    OR @IsPartial <> 0
    OR JSON_QUERY(@Json, '$.sources') IS NULL
    OR JSON_QUERY(@Json, '$.host') IS NULL
    OR JSON_QUERY(@Json, '$.services') IS NULL
    THROW 54941, N'Der OSInformation-Collationvertrag lieferte keinen vollständigen Status.', 1;
GO
