USE [DeineDatenbank];
GO

/*
Datei: 140_QueryStoreRuntimeStats_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren leeren Kandidatenpfad von Query Store Runtime Stats.
Datenschutz: Liest keine Query-Store-Datenbanken, Query-Texte oder Pläne.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_QueryStoreRuntimeStats]
      @QueryStoreDatabaseNames = N''
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'Query Store Runtime Stats did not return valid JSON.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, '$.runtimeStats') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 55001, N'Query Store Runtime Stats JSON contract is incomplete.', 1;

PRINT N'Query Store Runtime Stats collation contract passed.';
GO
