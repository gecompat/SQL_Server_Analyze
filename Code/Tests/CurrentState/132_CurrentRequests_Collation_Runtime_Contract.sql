USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CurrentRequests]
      @AktuelleSessionEinbeziehen = 1
    , @SystemSessionsEinbeziehen = 1
    , @MitSqlText = 0
    , @GesamtenSqlTextEinbeziehen = 0
    , @InputBufferEinbeziehen = 0
    , @ModulInfoEinbeziehen = 0
    , @MaxZeilen = 5
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55400, N'USP_CurrentRequests did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.resultName') <> N'USP_CurrentRequests'
    OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
    OR JSON_QUERY(@Json, N'$.requests') IS NULL
    OR JSON_QUERY(@Json, N'$.snapshotStatus') IS NULL
    THROW 55401, N'USP_CurrentRequests returned an unexpected JSON contract.', 1;

PRINT N'Current requests collation runtime contract passed.';
GO
