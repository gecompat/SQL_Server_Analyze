USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreHints
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Query-Store-Hints aus einer oder mehreren Quelldatenbanken mit
               globaler Top-N-Ausgabe. Verfügbar ab SQL Server 2022.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames          nvarchar(max)  = N''
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @NurMitFehler                     bit            = 0
    , @MaxZeilen                        int            = 100
    , @MaxDatenbanken                   int            = 16
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
    DECLARE @TableResultRequested bit = CASE WHEN @Out = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @Out = 'NONE';
 IF @Hilfe=1 BEGIN PRINT N'monitor.USP_QueryStoreHints';PRINT N'Quell-DB-Liste/Pattern, globales @MaxZeilen, RAW|CONSOLE|TABLE|NONE und JSON.';RETURN;END;
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048);
 CREATE TABLE [#QueryStoreHints_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#QueryStoreHints_Result]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname,[QueryHintId] bigint,[QueryId] bigint,[ReplicaGroupId] bigint,[QueryHash] binary(8),[QueryHintText] nvarchar(max),[LastQueryHintFailureReason] int,[LastQueryHintFailureReasonDesc] nvarchar(128),[QueryHintFailureCount] bigint,[Source] int,[SourceDesc] nvarchar(128),[QuerySqlText] nvarchar(max));
 CREATE TABLE [#QueryStoreHints_Errors]([DatabaseName] sysname,[StatusCode] varchar(40),[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048));
 IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<16 BEGIN SET @Status='UNAVAILABLE_VERSION';SET @Error=N'Query Store Hints sind erst ab SQL Server 2022 verfügbar.';END;
 IF @MaxZeilen<0 OR @MaxDatenbanken<0 OR @MaxSqlTextZeichen < 0 OR @Out NOT IN('RAW','CONSOLE','NONE') BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültiger Parameter.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='CROSS_DATABASE_DEEP',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStoreHints_DatabaseCandidates';
 IF @Status='AVAILABLE' AND @Limit>1000 BEGIN SELECT @Allowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='QUERY_STORE_DEEP';IF @Allowed=0 BEGIN SET @Status='DENIED_GROUP';SET @Error=N'QUERY_STORE_DEEP ist nicht freigegeben.';END;END;
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE' BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM [#QueryStoreHints_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db;WHILE @@FETCH_STATUS=0 BEGIN BEGIN TRY SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK) JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_query_hints'') INSERT [#QueryStoreHints_Result] SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[h].[query_hint_id],[h].[query_id],[h].[replica_group_id],[q].[query_hash],[h].[query_hint_text],[h].[last_query_hint_failure_reason],[h].[last_query_hint_failure_reason_desc],[h].[query_hint_failure_count],[h].[source],[h].[source_desc],CASE WHEN @TextChars IS NULL OR @TextChars=0 THEN [qt].[query_sql_text] ELSE LEFT([qt].[query_sql_text],@TextChars) END FROM [sys].[query_store_query_hints] [h] WITH (NOLOCK) LEFT JOIN [sys].[query_store_query] [q] WITH (NOLOCK) ON [q].[query_id]=[h].[query_id] LEFT JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id] WHERE (@QueryId IS NULL OR [h].[query_id]=@QueryId) AND (@OnlyErrors=0 OR [h].[query_hint_failure_count]>0 OR [h].[last_query_hint_failure_reason]<>0) ORDER BY CASE WHEN [h].[last_query_hint_failure_reason]<>0 THEN 0 ELSE 1 END,[h].[query_hint_failure_count] DESC,[h].[query_hint_id];';EXEC [sys].[sp_executesql] @Sql,N'@TopRows bigint,@QueryId bigint,@OnlyErrors bit,@TextChars int',@Local,@QueryId,@NurMitFehler,@MaxSqlTextZeichen;END TRY BEGIN CATCH INSERT [#QueryStoreHints_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStoreHints [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;FETCH NEXT FROM [c] INTO @Db;END;CLOSE [c];DEALLOCATE [c];END;
 SELECT @Count=COUNT_BIG(*) FROM [#QueryStoreHints_Result];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
 IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStoreHints' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Error [ErrorMessage];IF @Out='RAW' SELECT TOP(@Limit) * FROM [#QueryStoreHints_Result] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId];ELSE SELECT TOP(@Limit) N'Query-Store Hint' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[QueryHintText] [Hint],[LastQueryHintFailureReasonDesc] [letzter Fehler],[QueryHintFailureCount] [Fehleranzahl],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStoreHints_Result] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId];SELECT * FROM [#QueryStoreHints_Errors] ORDER BY [DatabaseName];END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStoreHints' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT TOP(@Limit) * FROM [#QueryStoreHints_Result] ORDER BY CASE WHEN [LastQueryHintFailureReason]<>0 THEN 0 ELSE 1 END,[QueryHintFailureCount] DESC,[QueryHintId] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#QueryStoreHints_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"queryHints":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreHints_Result'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
