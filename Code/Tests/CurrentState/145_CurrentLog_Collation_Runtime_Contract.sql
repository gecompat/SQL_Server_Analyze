USE [DeineDatenbank];
GO
/*
Datei: 145_CurrentLog_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren Standardpfad der Loganalyse.
Datenschutz: Liest keine VLF- oder Persistent-Version-Store-Details.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Json nvarchar(max) = NULL;
EXEC [monitor].[USP_CurrentLog]
      @DatabaseNames = N'[DeineDatenbank]', @MitVlfInformationen = 0, @MitPersistentVersionStore = 0
    , @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
IF ISJSON(@Json) <> 1 THROW 55000, N'Current Log did not return valid JSON.', 1;
IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('AVAILABLE', 'PARTIAL_RESULT')
   OR JSON_QUERY(@Json, '$.logs') IS NULL OR JSON_QUERY(@Json, '$.databaseStatus') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL THROW 55001, N'Current Log JSON contract is incomplete.', 1;
PRINT N'Current Log collation contract passed.';
GO
