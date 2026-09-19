USE [DeineDatenbank];
GO
/*
Datei: 144_CurrentTempDB_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren Low-Impact-Pfad von Current TempDB.
Datenschutz: Liest keine Dateipfade und keine Nutzdaten.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Json nvarchar(max) = NULL;
EXEC [monitor].[USP_CurrentTempDB]
      @AktuelleSessionEinbeziehen = 0, @MitDateien = 0, @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
IF ISJSON(@Json) <> 1 THROW 55000, N'Current TempDB did not return valid JSON.', 1;
IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, '$.sessions') IS NULL OR JSON_QUERY(@Json, '$.tempdbGovernance') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL THROW 55001, N'Current TempDB JSON contract is incomplete.', 1;
PRINT N'Current TempDB collation contract passed.';
GO
