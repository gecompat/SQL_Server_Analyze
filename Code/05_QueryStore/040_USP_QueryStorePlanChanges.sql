USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStorePlanChanges
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Queries mit mehreren Query-Store-Plänen, global begrenzt über
               lokale N+1-Kandidaten; optional Referenzdatenbankfilter.
Ausgabe      : RAW/CONSOLE/NONE sowie JSON mit meta, queries, plans, warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStorePlanChanges]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @NurMehrerePlaene                 bit            = 1
    , @MitPlanXml                       bit            = 0
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'TOP'))));
 DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
    DECLARE @TableResultRequested bit = CASE WHEN @Out = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @Out = 'NONE';
 IF @Hilfe=1 BEGIN PRINT N'monitor.USP_QueryStorePlanChanges';PRINT N'Quell-DB-Liste/Pattern, Referenz-DB-Liste/Pattern, globales @MaxZeilen, RAW|CONSOLE|TABLE|NONE und JSON.';RETURN;END;
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Compat tinyint,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048),@RefMode varchar(8),@RefValue nvarchar(4000),@RefFlags varchar(8),@RefValid bit,@RefPredicate nvarchar(max)=N'';
 SELECT @RefMode=[PatternMode],@RefValue=[PatternValue],@RefFlags=[RegexFlags],@RefValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);
 CREATE TABLE [#QueryStorePlanChanges_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#QueryStorePlanChanges_Summary]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) NULL,[PlanCount] bigint,[ForcedPlanCount] bigint,[DistinctPlanHashCount] bigint,[FirstCompileTimeUtc] datetimeoffset NULL,[LastCompileTimeUtc] datetimeoffset NULL,[LastExecutionTimeUtc] datetimeoffset NULL,[TotalCompiles] bigint,[QuerySqlText] nvarchar(max));
 CREATE TABLE [#QueryStorePlanChanges_Plans]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname,[QueryId] bigint,[PlanId] bigint,[QueryPlanHash] binary(8),[EngineVersion] nvarchar(32),[CompatibilityLevel] smallint,[IsParallelPlan] bit,[IsForcedPlan] bit,[PlanForcingTypeDesc] nvarchar(60),[ForceFailureCount] bigint,[LastForceFailureReason] int,[LastForceFailureReasonDesc] nvarchar(128),[CountCompiles] bigint,[InitialCompileStartTimeUtc] datetimeoffset,[LastCompileStartTimeUtc] datetimeoffset,[LastExecutionTimeUtc] datetimeoffset,[AverageCompileDurationMs] decimal(38,3),[LastCompileDurationMs] decimal(38,3),[QueryPlan] nvarchar(max) NULL);
 CREATE TABLE [#QueryStorePlanChanges_Errors]([DatabaseName] sysname,[StatusCode] varchar(40),[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048));
 IF @AnalyseModus NOT IN('TOP','VOLL') OR @MaxZeilen<0 OR @MaxSqlTextZeichen < 0 OR @Out NOT IN('RAW','CONSOLE','NONE') OR @RefValid=0 OR (@ReferencedDatabaseNames IS NOT NULL AND @ReferencedDatabaseNamePattern IS NOT NULL) OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) WHERE [IsValid]=0)) BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültiger Parameter.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed,@AnalysisClass='QUERY_STORE_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStorePlanChanges_DatabaseCandidates';
 IF @Status='AVAILABLE' AND (@AnalyseModus='VOLL' OR @MitPlanXml=1 OR @Limit>1000 OR @ReferencedDatabaseNames IS NOT NULL OR @ReferencedDatabaseNamePattern IS NOT NULL) EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='QUERY_STORE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT;
 IF @ReferencedDatabaseNames IS NOT NULL SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) JOIN [monitor].[TVF_ParseSqlNameList](@ReferencedNames) [rf] ON [rf].[IsValid]=1 AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode='LIKE' SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @RefValue COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode IN('REGEX','REGEXI') SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE REGEXP_LIKE(PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1),@RefValue,@RefFlags))';
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE'
 BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[CompatibilityLevel] FROM [#QueryStorePlanChanges_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db,@Compat;WHILE @@FETCH_STATUS=0
 BEGIN
  IF @RefMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR @Compat<170) BEGIN INSERT [#QueryStorePlanChanges_Errors] VALUES(@Db,'UNAVAILABLE_FEATURE',NULL,N'Regex benötigt SQL Server 2025 und Compatibility Level 170.');SET @Partial=1;END
  ELSE BEGIN TRY
   SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WITH (NOLOCK) WHERE [actual_state] IN(1,2,4))
BEGIN
;WITH [Q] AS
(
 SELECT [q].[query_id],[q].[query_hash],[q].[object_id],COUNT_BIG(*) [PlanCount],SUM(CONVERT(bigint,[p].[is_forced_plan])) [ForcedCount],COUNT(DISTINCT CONVERT(varchar(18),[p].[query_plan_hash],1)) [DistinctHashCount],MIN([p].[initial_compile_start_time]) [FirstCompile],MAX([p].[last_compile_start_time]) [LastCompile],MAX([p].[last_execution_time]) [LastExecution],SUM([p].[count_compiles]) [TotalCompiles],[qt].[query_sql_text]
 FROM [sys].[query_store_query] [q] WITH (NOLOCK) JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id] JOIN [sys].[query_store_plan] [p] WITH (NOLOCK) ON [p].[query_id]=[q].[query_id]
 WHERE (@QueryId IS NULL OR [q].[query_id]=@QueryId) AND (@QueryHash IS NULL OR [q].[query_hash]=@QueryHash) AND (@SinceUtc IS NULL OR [p].[last_compile_start_time]>=@SinceUtc OR [p].[last_execution_time]>=@SinceUtc)'+@RefPredicate+N'
 GROUP BY [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text] HAVING @OnlyMultiple=0 OR COUNT_BIG(*)>1
)
INSERT [#QueryStorePlanChanges_Summary] SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[query_id],[query_hash],[object_id],CASE WHEN [Q].[object_id]>0 THEN QUOTENAME([os].[name])+N''.''+QUOTENAME([oo].[name]) END,[PlanCount],[ForcedCount],[DistinctHashCount],[FirstCompile],[LastCompile],[LastExecution],[TotalCompiles],CASE WHEN @TextChars IS NULL OR @TextChars=0 THEN [query_sql_text] ELSE LEFT([query_sql_text],@TextChars) END FROM [Q] LEFT JOIN [sys].[objects] AS [oo] WITH (NOLOCK) ON [oo].[object_id]=[Q].[object_id] LEFT JOIN [sys].[schemas] AS [os] WITH (NOLOCK) ON [os].[schema_id]=[oo].[schema_id] ORDER BY [LastExecution] DESC,[LastCompile] DESC;
INSERT [#QueryStorePlanChanges_Plans] SELECT DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[p].[query_id],[p].[plan_id],[p].[query_plan_hash],[p].[engine_version],[p].[compatibility_level],[p].[is_parallel_plan],[p].[is_forced_plan],[p].[plan_forcing_type_desc],[p].[force_failure_count],[p].[last_force_failure_reason],[p].[last_force_failure_reason_desc],[p].[count_compiles],[p].[initial_compile_start_time],[p].[last_compile_start_time],[p].[last_execution_time],CONVERT(decimal(38,3),[p].[avg_compile_duration]/1000.0),CONVERT(decimal(38,3),[p].[last_compile_duration]/1000.0),CASE WHEN @IncludePlan=1 THEN [p].[query_plan] END FROM [sys].[query_store_plan] [p] WITH (NOLOCK) JOIN [#QueryStorePlanChanges_Summary] [s] ON [s].[QueryStoreDatabaseId]=DB_ID() AND [s].[QueryId]=[p].[query_id];
END;';
   EXEC [sys].[sp_executesql] @Sql,N'@QueryId bigint,@QueryHash binary(8),@SinceUtc datetime2(7),@OnlyMultiple bit,@TopRows bigint,@TextChars int,@IncludePlan bit,@ReferencedNames nvarchar(max),@RefValue nvarchar(4000),@RefFlags varchar(8)',@QueryId,@QueryHash,@VonUtc,@NurMehrerePlaene,@Local,@MaxSqlTextZeichen,@MitPlanXml,@ReferencedDatabaseNames,@RefValue,@RefFlags;
  END TRY BEGIN CATCH INSERT [#QueryStorePlanChanges_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStorePlanChanges [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;
  FETCH NEXT FROM [c] INTO @Db,@Compat;END;CLOSE [c];DEALLOCATE [c];END;
 SELECT @Count=COUNT_BIG(*) FROM [#QueryStorePlanChanges_Summary];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
 DELETE [p] FROM [#QueryStorePlanChanges_Plans] [p] WHERE NOT EXISTS(SELECT 1 FROM (SELECT TOP(@Limit) [QueryStoreDatabaseId],[QueryId] FROM [#QueryStorePlanChanges_Summary] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC) [k] WHERE [k].[QueryStoreDatabaseId]=[p].[QueryStoreDatabaseId] AND [k].[QueryId]=[p].[QueryId]);
 IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStorePlanChanges' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Error [ErrorMessage];IF @Out='RAW' BEGIN SELECT TOP(@Limit) * FROM [#QueryStorePlanChanges_Summary] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC;SELECT * FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId];END ELSE BEGIN SELECT TOP(@Limit) N'Query-Store Planwechsel' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[PlanCount] [Pläne],[DistinctPlanHashCount] [verschiedene Plan-Hashes],[ForcedPlanCount] [erzwungene Pläne],[LastExecutionTimeUtc] [letzte Ausführung],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStorePlanChanges_Summary] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC;SELECT N'Query-Store Plan' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[PlanId] [Plan],[IsForcedPlan] [erzwungen],[LastExecutionTimeUtc] [letzte Ausführung],[AverageCompileDurationMs] [Compile Ø ms],[QueryPlan] [Plan-XML] FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId];END;SELECT * FROM [#QueryStorePlanChanges_Errors] ORDER BY [DatabaseName];END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStorePlanChanges' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Queries nvarchar(max)=(SELECT TOP(@Limit) * FROM [#QueryStorePlanChanges_Summary] ORDER BY [LastExecutionTimeUtc] DESC,[LastCompileTimeUtc] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@Plans nvarchar(max)=(SELECT * FROM [#QueryStorePlanChanges_Plans] ORDER BY [QueryStoreDatabaseName],[QueryId],[LastExecutionTimeUtc] DESC,[PlanId] FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#QueryStorePlanChanges_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"queries":',COALESCE(@Queries,N'[]'),N',"plans":',COALESCE(@Plans,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStorePlanChanges_Summary'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
