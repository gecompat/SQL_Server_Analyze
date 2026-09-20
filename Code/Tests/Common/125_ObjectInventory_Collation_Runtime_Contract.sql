USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

CREATE TABLE [dbo].[CollationRuntimeObject]
(
    [Id] int NOT NULL PRIMARY KEY,
    [Name] nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

DECLARE @Json nvarchar(max);
DECLARE @DatabaseName sysname = DB_NAME();

EXEC [monitor].[USP_ObjectInventory]
      @DatabaseNames = @DatabaseName
    , @ObjectNames = N'CollationRuntimeObject'
    , @MitIndizes = 0
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
   OR JSON_VALUE(@Json, N'$.meta.resultName') <> N'USP_ObjectInventory'
   OR JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'AVAILABLE_LIMITED')
   OR JSON_QUERY(@Json, N'$.objects') IS NULL
    THROW 55740, N'ObjectInventory returned an unexpected runtime contract.', 1;

PRINT N'ObjectInventory collation runtime contract passed.';
GO
