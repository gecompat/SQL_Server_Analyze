USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_ShowplanAnalysis]
    @DatabaseNames = N'[DeineDatenbank]',
    @MinExecutionCount = 9223372036854775807,
    @MaxAnalyseobjekte = 1,
    @MaxZeilen = 1,
    @MitSqlText = 0,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_ShowplanAnalysis did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL', N'AVAILABLE_LIMITED')
    THROW 55000, N'USP_ShowplanAnalysis returned an unexpected status for the collation contract.', 1;

IF JSON_QUERY(@Json, N'$.planStatus') IS NULL OR JSON_QUERY(@Json, N'$.findings') IS NULL
    THROW 55000, N'USP_ShowplanAnalysis JSON does not contain required arrays.', 1;

PRINT N'Showplan Analysis collation runtime contract passed.';
GO
