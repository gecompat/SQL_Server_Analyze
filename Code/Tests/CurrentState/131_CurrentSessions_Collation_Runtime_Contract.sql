USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CurrentSessions]
      @AktuelleSessionEinbeziehen = 1
    , @SystemSessionsEinbeziehen = 1
    , @MitSqlText = 0
    , @MaxZeilen = 5
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55300, N'USP_CurrentSessions did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.resultName') <> N'USP_CurrentSessions'
    OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
    OR JSON_QUERY(@Json, N'$.sessions') IS NULL
    THROW 55301, N'USP_CurrentSessions returned an unexpected JSON contract.', 1;

PRINT N'Current sessions collation runtime contract passed.';
GO
