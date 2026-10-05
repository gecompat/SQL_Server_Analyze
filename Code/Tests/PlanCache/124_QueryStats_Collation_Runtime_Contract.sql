USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryStats]
    @DatabaseNames = N'[DeineDatenbank]',
    @MaxZeilen = 1,
    @MinExecutionCount = 9223372036854775807,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_QueryStats did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED', N'PARTIAL_RESULT')
    THROW 55000, N'USP_QueryStats returned an unexpected status for the limited collation contract.', 1;

IF JSON_QUERY(@Json, N'$.queries') IS NULL
    THROW 55000, N'USP_QueryStats JSON does not contain the queries array.', 1;

IF JSON_QUERY(@Json, N'$.warnings') IS NULL
    THROW 55000, N'USP_QueryStats JSON does not contain the warnings array.', 1;

PRINT N'Query Stats collation runtime contract passed.';
GO
