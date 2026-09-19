USE [DeineDatenbank];
GO

/*
Datei: 142_IntelligentQueryProcessingAnalysis_Collation_Runtime_Contract.sql
Zweck: Prüft den kollationssicheren unbekannten-Datenbankpfad der IQP-Analyse.
Datenschutz: Liest keine Query-Texte oder Showplans.
Nebenwirkung: Keine.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;

EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
      @DatabaseNames = N'[CodexIqpMissing]'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'IQP analysis did not return valid JSON.', 1;

IF JSON_VALUE(@Json, '$.meta.statusCode') NOT IN ('DATABASE_UNAVAILABLE', 'AVAILABLE_LIMITED', 'HIGH_IMPACT_CONFIRMATION_REQUIRED')
   OR JSON_QUERY(@Json, '$.databaseState') IS NULL
   OR JSON_QUERY(@Json, '$.warnings') IS NULL
    THROW 55001, N'IQP analysis JSON contract is incomplete.', 1;

PRINT N'IQP collation contract passed.';
GO
