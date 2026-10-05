USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @MitGruppenpruefung = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55700, N'USP_CheckFrameworkCapabilities did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.resultName') <> N'CheckFrameworkCapabilities'
   OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, N'$.capabilities') IS NULL
    THROW 55701, N'USP_CheckFrameworkCapabilities returned an unexpected JSON contract.', 1;

PRINT N'CheckFrameworkCapabilities collation runtime contract passed.';
GO
