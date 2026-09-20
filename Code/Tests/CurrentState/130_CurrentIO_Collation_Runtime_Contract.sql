USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_CurrentIO]
      @PendingIoEinbeziehen = 0
    , @MaxZeilen = 5
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55200, N'USP_CurrentIO did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.resultName') <> N'CurrentIO'
    OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
    OR JSON_QUERY(@Json, N'$.files') IS NULL
    OR JSON_QUERY(@Json, N'$.sourceStatus') IS NULL
    THROW 55201, N'USP_CurrentIO returned an unexpected JSON contract.', 1;

PRINT N'Current I/O collation runtime contract passed.';
GO
