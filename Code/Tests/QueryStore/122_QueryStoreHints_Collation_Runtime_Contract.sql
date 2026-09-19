USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 122_QueryStoreHints_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft den Query-Store-Hints-Pfad mit explizit
               kollationierten lokalen Arbeits-Temp-Tabellen.
Datenschutz  : Der Test verwendet ausschliesslich die aktuelle Testdatenbank.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) < 16
    THROW 54901,N'Der Query-Store-Hints-Collationvertrag erfordert mindestens SQL Server 2022.',1;

DECLARE @DatabaseName sysname = DB_NAME();
DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames = @DatabaseName
    , @HighImpactConfirmed = 1
    , @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54902,N'Der Query-Store-Hints-Collationvertrag lieferte kein JSON-Ergebnis.',1;
IF JSON_VALUE(@Json,N'$.meta.statusCode') <> N'AVAILABLE'
    THROW 54903,N'Der Query-Store-Hints-Collationvertrag lieferte keinen verfügbaren Quellstatus.',1;
GO
