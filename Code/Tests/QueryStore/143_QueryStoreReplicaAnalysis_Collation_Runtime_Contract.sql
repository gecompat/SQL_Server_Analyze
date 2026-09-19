USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
    @QueryStoreDatabaseNames = N'[DeineDatenbank]',
    @MaxZeilen = 1,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_QueryStoreReplicaAnalysis did not return valid JSON.', 1;

IF TRY_CONVERT(int, JSON_VALUE(@Json, N'$.meta.productMajorVersion')) < 17
   AND JSON_VALUE(@Json, N'$.meta.statusCode') <> N'UNAVAILABLE_VERSION'
    THROW 55000, N'USP_QueryStoreReplicaAnalysis did not report the pre-2025 version boundary.', 1;

IF TRY_CONVERT(int, JSON_VALUE(@Json, N'$.meta.productMajorVersion')) >= 17
   AND JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED', N'NOT_APPLICABLE')
    THROW 55000, N'USP_QueryStoreReplicaAnalysis returned an unexpected SQL Server 2025 status.', 1;

IF JSON_QUERY(@Json, N'$.moduleStatus') IS NULL OR JSON_QUERY(@Json, N'$.sourceStatus') IS NULL
    THROW 55000, N'USP_QueryStoreReplicaAnalysis JSON does not contain required status arrays.', 1;

PRINT N'Query Store Replica Analysis collation runtime contract passed.';
GO
