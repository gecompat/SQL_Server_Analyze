USE [DeineDatenbank];
GO

/* OPS-009: visible user-object inventory in master, model and msdb; no DDL. */
CREATE OR ALTER PROCEDURE [monitor].[USP_SystemDatabaseObjectInventory]
      @MaxZeilen int=2000,@ResultSetArt varchar(16)='CONSOLE',@ResultTablesJson nvarchar(max)=NULL,@JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
      @PrintMeldungen bit=1,@Hilfe bit=0,@StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,
      @ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET @Json=NULL;
 DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
 DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
 IF @Hilfe=1 BEGIN PRINT N'monitor.USP_SystemDatabaseObjectInventory'; PRINT N'Inventarisiert sichtbare Benutzerobjekte in master, model und msdb; keine DDL-Aktion.'; RETURN; END;
 DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
 SET LOCK_TIMEOUT 0;
 DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
 IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
 IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'systemDatabaseObjects',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; SET @Mode='NONE'; END;
 CREATE TABLE [#SystemDatabaseObjectInventory_Objects]([DatabaseName]sysname,[SchemaName]sysname,[ObjectName]sysname,[ObjectType]nvarchar(60),[CreateDate]datetime,[ModifyDate]datetime,[StatusCode]varchar(40),[EvidenceLimit]nvarchar(1000));
 IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
 IF @Status='AVAILABLE' BEGIN
  DECLARE @Db sysname,@Sql nvarchar(max); DECLARE [d] CURSOR LOCAL FAST_FORWARD FOR SELECT [name] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id] IN(1,3,4) AND [state]=0 AND HAS_DBACCESS([name])=1;
  OPEN [d]; FETCH NEXT FROM [d] INTO @Db; WHILE @@FETCH_STATUS=0 BEGIN
   BEGIN TRY SET @Sql=N'INSERT [#SystemDatabaseObjectInventory_Objects] SELECT @Db,[s].[name],[o].[name],[o].[type_desc],[o].[create_date],[o].[modify_date],''AVAILABLE'',N''Sichtbares Inventar; Bewertung benötigt Objektverantwortung und Betriebszweck.'' FROM '+QUOTENAME(@Db)+N'.[sys].[objects] [o] WITH (NOLOCK) JOIN '+QUOTENAME(@Db)+N'.[sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] WHERE [o].[is_ms_shipped]=0 AND [o].[type] NOT IN(''S'',''IT'');'; EXEC [sys].[sp_executesql] @Sql,N'@Db sysname',@Db; END TRY
   BEGIN CATCH INSERT [#SystemDatabaseObjectInventory_Objects] VALUES(@Db,NULL,NULL,NULL,NULL,NULL,'SOURCE_UNAVAILABLE',CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800))); SET @Partial=1; END CATCH;
   FETCH NEXT FROM [d] INTO @Db; END; CLOSE [d]; DEALLOCATE [d]; IF NOT EXISTS(SELECT 1 FROM [#SystemDatabaseObjectInventory_Objects]) SET @Status='AVAILABLE_EMPTY'; ELSE IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
 END;
 IF @JsonErzeugen=1 SELECT @Json=(SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#SystemDatabaseObjectInventory_Objects] ORDER BY [DatabaseName],[SchemaName],[ObjectName] FOR JSON PATH);
 IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],COUNT_BIG(*) [ObjectCount],@ErrorMessage [ErrorMessage] FROM [#SystemDatabaseObjectInventory_Objects]; SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END)* FROM [#SystemDatabaseObjectInventory_Objects] ORDER BY [DatabaseName],[SchemaName],[ObjectName]; END;
 IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
 IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#SystemDatabaseObjectInventory_Objects',@TargetTable=@TableTarget,@ThrowOnError=1;
 SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
 SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO
