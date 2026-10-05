USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 123_LogShippingStatus_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft den Log-Shipping-Statuspfad mit explizit
               kollationierten lokalen Arbeits-Temp-Tabellen.
Datenschutz  : Der Test liest nur generische lokale Systemmetadaten.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_LogShippingStatus]
      @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54904,N'Der Log-Shipping-Collationvertrag lieferte kein JSON-Ergebnis.',1;
IF JSON_VALUE(@Json,N'$.meta.statusCode') NOT IN (N'AVAILABLE',N'UNAVAILABLE_FEATURE')
    THROW 54905,N'Der Log-Shipping-Collationvertrag lieferte einen unerwarteten Quellstatus.',1;
GO
