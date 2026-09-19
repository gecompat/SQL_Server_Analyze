USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 124_ReplicationStatus_Collation_Runtime_Contract.sql
Zweck        : Der Test prueft den Standardpfad des Replication-Status mit
               explizit kollationierten lokalen Arbeits-Temp-Tabellen.
Datenschutz  : Der Test liest nur generische lokale Systemmetadaten.
Nebenwirkung : Keine dauerhaften Objekte oder Datenbankaenderungen.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_ReplicationStatus]
      @MitDistributionDetails = 0
    , @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54906,N'Der Replication-Collationvertrag lieferte kein JSON-Ergebnis.',1;
IF JSON_VALUE(@Json,N'$.meta.statusCode') <> N'AVAILABLE'
    THROW 54907,N'Der Replication-Collationvertrag lieferte keinen verfügbaren Quellstatus.',1;
GO
