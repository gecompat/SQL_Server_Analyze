USE [DeineDatenbank];
GO

/*
Datei: 143_CurrentMemoryGrants_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren leeren Memory-Grant-Pfad.
Datenschutz: Liest keine Nutzdaten ausser der eigenen Sitzungsmetadaten.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_CurrentMemoryGrants]
      @AktuelleSessionEinbeziehen = 0
    , @MitSqlText = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'Current Memory Grants did not return valid JSON.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, '$.memoryGrants') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 55001, N'Current Memory Grants JSON contract is incomplete.', 1;

PRINT N'Current Memory Grants collation contract passed.';
GO
