USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CreateExecutionEvidenceJson]
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_CreateExecutionEvidenceJson did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') <> N'AVAILABLE'
    THROW 55000, N'USP_CreateExecutionEvidenceJson returned an unexpected status for the collation contract.', 1;

IF JSON_QUERY(@Json, N'$.statisticsIo') IS NULL OR JSON_QUERY(@Json, N'$.collectionStatus') IS NULL
    THROW 55000, N'USP_CreateExecutionEvidenceJson JSON does not contain required arrays.', 1;

PRINT N'Execution Evidence collation runtime contract passed.';
GO
