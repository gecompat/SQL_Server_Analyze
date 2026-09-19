USE [DeineDatenbank];
GO

/*
Datei: 132_CurrentTransactions_Collation_Runtime_Contract.sql
Zweck: Prüft den JSON-Vertrag von USP_CurrentTransactions mit explizit kollationierten Arbeitstabellen.
Datenschutz: SQL-Text wird nicht angefordert; die Ergebnismenge wird nicht ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_CurrentTransactions]
      @MitSqlText = 0
    , @MaxZeilen = 10
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54930, N'Der CurrentTransactions-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.transactions') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54931, N'Der CurrentTransactions-Collationvertrag lieferte keinen vollständigen Status.', 1;
GO
