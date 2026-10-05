USE [DeineDatenbank];
GO

/*
Datei: 134_PlanCacheHealth_Collation_Runtime_Contract.sql
Zweck: Prüft den SUMMARY-JSON-Vertrag von USP_PlanCacheHealth mit explizit kollationierten Arbeitstabellen.
Datenschutz: Es werden keine SQL-Texte, Planhandles oder Detailergebnisse ausgegeben oder gespeichert.
Nebenwirkung: Keine.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_PlanCacheHealth]
      @AnalyseModus = 'SUMMARY'
    , @MitDatenbankVerteilung = 0
    , @MitSingleUseDetails = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 54950, N'Der PlanCacheHealth-Collationvertrag lieferte kein JSON-Ergebnis.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
    OR JSON_QUERY(@Json, '$.overview') IS NULL
    OR JSON_QUERY(@Json, '$.categories') IS NULL
    OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 54951, N'Der PlanCacheHealth-Collationvertrag lieferte keinen vollständigen Status.', 1;
GO
