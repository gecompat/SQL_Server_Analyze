USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

CREATE TABLE [dbo].[CollationIndexUsageObject]
(
    [Id] int NOT NULL PRIMARY KEY,
    [Name] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

DECLARE @Json nvarchar(max);
DECLARE @DatabaseName sysname = DB_NAME();

EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames = @DatabaseName
    , @ObjectNames = N'CollationIndexUsageObject'
    , @MitMemoryOptimized = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
   OR JSON_VALUE(@Json, N'$.meta.resultName') <> N'USP_IndexUsage'
   OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, N'$.rowstoreIndexes') IS NULL
    THROW 55750, N'IndexUsage returned an unexpected runtime contract.', 1;

PRINT N'IndexUsage collation runtime contract passed.';
GO
