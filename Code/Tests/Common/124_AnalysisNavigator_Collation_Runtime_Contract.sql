USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_AnalysisNavigator]
      @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
   OR JSON_VALUE(@Json, N'$.meta.resultName') <> N'AnalysisNavigator'
   OR JSON_VALUE(@Json, N'$.meta.statusCode') <> N'AVAILABLE'
   OR JSON_QUERY(@Json, N'$.navigation') IS NULL
    THROW 55730, N'AnalysisNavigator returned an unexpected runtime contract.', 1;

PRINT N'AnalysisNavigator collation runtime contract passed.';
GO
