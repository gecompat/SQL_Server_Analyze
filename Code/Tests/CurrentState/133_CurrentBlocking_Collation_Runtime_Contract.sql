USE [DeineDatenbank];
GO
SET NOCOUNT ON;
GO
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_CurrentBlocking] @MitSqlText=0,@BlockingObjektTiefe='NONE',@MitLockDetails=0,@MaxZeilen=5,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'CurrentBlocking' OR JSON_QUERY(@Json,N'$.blockingChains') IS NULL THROW 55500,N'CurrentBlocking JSON contract failed.',1;
PRINT N'Current blocking collation runtime contract passed.';
GO
