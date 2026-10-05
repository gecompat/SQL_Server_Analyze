USE [DeineDatenbank];
GO

/*
Datei: 135_CurrentWaits_Collation_Runtime_Contract.sql
Zweck: Prüft den JSON-Vertrag von USP_CurrentWaits mit explizit kollationierten Arbeitstabellen.
Datenschutz: SQL-Text wird nicht angefordert; Warte- und Sitzungsdetails werden nicht ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_CurrentWaits]
      @MitSqlText = 0
    , @SampleSeconds = 0
    , @MaxZeilen = 10
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54960, N'Der CurrentWaits-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.currentTasks') IS NULL
    OR JSON_QUERY(@Json, '$.instanceWaits') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54961, N'Der CurrentWaits-Collationvertrag lieferte keinen vollständigen Status.', 1;
GO
