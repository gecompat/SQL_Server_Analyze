USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 125_AvailabilityGroups_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft den Availability-Groups-Pfad mit explizit
               kollationierten lokalen Arbeits-Temp-Tabellen.
Datenschutz  : Der Test liest nur generische lokale HADR-Systemmetadaten.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_AvailabilityGroups]
      @MitRouting = 0
    , @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54910,N'Der Availability-Groups-Collationvertrag lieferte kein JSON-Ergebnis.',1;
IF JSON_VALUE(@Json,N'$.meta.statusCode') NOT IN (N'AVAILABLE',N'UNAVAILABLE_FEATURE')
    THROW 54911,N'Der Availability-Groups-Collationvertrag lieferte einen unerwarteten Quellstatus.',1;
GO
