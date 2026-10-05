USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 127_ServerCpuTopology_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft die CPU-Topologieanalyse mit explizit
               kollationierten lokalen Arbeits-Temp-Tabellen.
Datenschutz  : Der Test liest nur generische lokale Server-DMVs.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @StatusCode varchar(40) = NULL;
DECLARE @IsPartial bit = NULL;
DECLARE @ErrorNumber int = NULL;
DECLARE @ErrorMessage nvarchar(2048) = NULL;

EXEC [monitor].[USP_ServerCpuTopology]
      @PrintMeldungen = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF ISJSON(@Json) <> 1
    THROW 54912,N'Der CPU-Topologie-Collationvertrag lieferte kein JSON-Ergebnis.',1;
IF @StatusCode <> 'AVAILABLE' OR @IsPartial <> 0 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
    THROW 54913,N'Der CPU-Topologie-Collationvertrag lieferte keinen vollstaendigen Quellstatus.',1;
GO
