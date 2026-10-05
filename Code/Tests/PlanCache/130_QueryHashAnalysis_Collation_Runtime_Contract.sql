USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

EXEC [sys].[sp_executesql]
    N'SELECT N''QueryHashAnalysisCollationRuntime'' AS [SampleStatementText];';

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryHashAnalysis]
      @AnalyseModus = 'TOP'
    , @MinExecutionCount = 0
    , @MinPlanVarianten = 1
    , @MaxZeilen = 5
    , @MaxSqlTextZeichen = 100
    , @HighImpactConfirmed = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55100, N'USP_QueryHashAnalysis did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.resultName') <> N'QueryHashAnalysis'
    OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL')
    OR JSON_QUERY(@Json, N'$.queryHashes') IS NULL
    THROW 55101, N'USP_QueryHashAnalysis returned an unexpected JSON contract.', 1;

PRINT N'Query-hash analysis collation runtime contract passed.';
GO
