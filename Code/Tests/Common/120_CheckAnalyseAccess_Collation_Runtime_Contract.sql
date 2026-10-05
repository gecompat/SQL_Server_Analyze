USE [DeineDatenbank];
GO
SET NOCOUNT ON;
GO
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'CheckAnalyseAccess' OR JSON_QUERY(@Json,N'$.access') IS NULL
    THROW 55600,N'CheckAnalyseAccess JSON contract failed.',1;
PRINT N'CheckAnalyseAccess collation runtime contract passed.';
GO
