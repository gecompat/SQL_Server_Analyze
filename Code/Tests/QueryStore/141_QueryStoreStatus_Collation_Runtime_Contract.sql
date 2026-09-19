USE [DeineDatenbank];
GO

/*
Datei: 141_QueryStoreStatus_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren unbekannten-Datenbankpfad von Query Store Status.
Datenschutz: Liest keine Query-Store-Nutzdaten.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreStatus]
      @QueryStoreDatabaseNames = N'[CodexQueryStoreStatusMissing]'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'Query Store Status did not return valid JSON.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('DATABASE_UNAVAILABLE', 'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, '$.queryStoreStatus') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 55001, N'Query Store Status JSON contract is incomplete.', 1;

PRINT N'Query Store Status collation contract passed.';
GO
