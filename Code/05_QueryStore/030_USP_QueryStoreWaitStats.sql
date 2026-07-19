USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreWaitStats
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Query-Store-Wait-Statistiken aus einer oder mehreren
               Quelldatenbanken; exaktes globales Top-N über lokale N+1-
               Kandidaten. Optionaler Filter auf in Showplans referenzierte DBs.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit meta, waitStats,
               warnings. Steuerwerte werden case-insensitiv normalisiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames          nvarchar(max)  = N''
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @WaitCategory                     nvarchar(128)  = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @BisUtc                           datetime2(7)   = NULL
    , @AnalyseModus                     varchar(16)    = 'TOP'
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
    SET NOCOUNT ON;
    SET @Json = NULL;
    SET @AnalyseModus = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus, 'TOP'))));
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN CONVERT(bigint,@MaxZeilen) ELSE 0 END;
    DECLARE @LocalRows bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE CONVERT(bigint,@MaxZeilen) END;
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_QueryStoreWaitStats';
        PRINT N'@QueryStoreDatabaseNames: exakte bracket-aware Pipe-Liste; NULL=alle; N''''=ungültig.';
        PRINT N'@ReferencedDatabaseNames/Pattern: optionaler Showplan-Referenzfilter.';
        PRINT N'@MaxZeilen ist global; lokal werden N+1 Kandidaten je DB gelesen.';
        PRINT N'@ResultSetArt RAW|CONSOLE|TABLE|NONE; @JsonErzeugen=1 setzt @Json OUTPUT.';
        RETURN;
    END;
    IF @BisUtc IS NULL SET @BisUtc=SYSUTCDATETIME();
    IF @VonUtc IS NULL SET @VonUtc=DATEADD(HOUR,-1,@BisUtc);
    DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorMessage nvarchar(2048)=NULL,@Allowed bit=1,@Db sysname,@DbCompat tinyint,@Sql nvarchar(max),@RowCount bigint=0,@HasMoreRows bit=0,@Cross bit=0,@Message nvarchar(2048);
    DECLARE @RefMode varchar(8),@RefValue nvarchar(4000),@RefFlags varchar(8),@RefValid bit,@RefPredicate nvarchar(max)=N'';
    SELECT @RefMode=[PatternMode],@RefValue=[PatternValue],@RefFlags=[RegexFlags],@RefValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);
    CREATE TABLE [#QueryStoreWaitStats_DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
    CREATE TABLE [#QueryStoreWaitStats_Result]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname,[QueryId] bigint,[PlanId] bigint,[QueryHash] binary(8),[QueryPlanHash] binary(8),[WaitCategory] tinyint,[WaitCategoryDesc] nvarchar(128),[ExecutionTypeDesc] nvarchar(128),[FirstIntervalStartUtc] datetimeoffset,[LastIntervalEndUtc] datetimeoffset,[RecordedRows] bigint,[TotalQueryWaitTimeMs] bigint,[AverageRecordedQueryWaitTimeMs] decimal(38,3),[MaxQueryWaitTimeMs] bigint,[QuerySqlText] nvarchar(max));
    CREATE TABLE [#QueryStoreWaitStats_Errors]([DatabaseName] sysname,[StatusCode] varchar(40),[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048));
    IF @AnalyseModus NOT IN('TOP','VOLL') OR @MaxZeilen<0 OR @MaxDatenbanken<0 OR @MaxSqlTextZeichen < 0 OR @VonUtc>=@BisUtc OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') OR @RefValid=0 OR (@ReferencedDatabaseNames IS NOT NULL AND @ReferencedDatabaseNamePattern IS NOT NULL) OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) WHERE [IsValid]=0))
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'Ungültiger Parameter oder Zeitraum.';END;
    IF @StatusCode='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='CROSS_DATABASE_DEEP',@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT,@CandidateTable=N'#QueryStoreWaitStats_DatabaseCandidates';
    IF @StatusCode='AVAILABLE' AND (@AnalyseModus='VOLL' OR @EffectiveMaxZeilen>1000 OR DATEDIFF(HOUR,@VonUtc,@BisUtc)>24 OR @ReferencedDatabaseNames IS NOT NULL OR @ReferencedDatabaseNamePattern IS NOT NULL)
    BEGIN SELECT @Allowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='QUERY_STORE_DEEP';IF @Allowed=0 BEGIN SET @StatusCode='DENIED_GROUP';SET @ErrorMessage=N'QUERY_STORE_DEEP ist nicht freigegeben.';END;END;
    IF @ReferencedDatabaseNames IS NOT NULL SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) JOIN [monitor].[TVF_ParseSqlNameList](@ReferencedNames) [rf] ON [rf].[IsValid]=1 AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS)';
    ELSE IF @RefMode='LIKE' SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @RefValue COLLATE SQL_Latin1_General_CP1_CS_AS)';
    ELSE IF @RefMode IN('REGEX','REGEXI') SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE REGEXP_LIKE(PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1),@RefValue,@RefFlags))';
    SET LOCK_TIMEOUT 0;
    IF @StatusCode='AVAILABLE'
    BEGIN
      DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[CompatibilityLevel] FROM [#QueryStoreWaitStats_DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db,@DbCompat;
      WHILE @@FETCH_STATUS=0
      BEGIN
        IF @RefMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR @DbCompat<170) BEGIN INSERT [#QueryStoreWaitStats_Errors] VALUES(@Db,'UNAVAILABLE_FEATURE',NULL,N'Regex benötigt SQL Server 2025 und Compatibility Level 170.');SET @IsPartial=1;END
        ELSE BEGIN TRY
          SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WITH (NOLOCK) WHERE [actual_state] IN(1,2,4) AND [wait_stats_capture_mode]=1)
BEGIN
;WITH [W] AS
(
 SELECT [ws].[plan_id],[ws].[execution_type_desc],[ws].[wait_category],[ws].[wait_category_desc],MIN([i].[start_time]) [FirstStart],MAX([i].[end_time]) [LastEnd],COUNT_BIG(*) [RecordedRows],SUM([ws].[total_query_wait_time_ms]) [TotalWait],AVG(CONVERT(float,[ws].[avg_query_wait_time_ms])) [AverageWait],MAX([ws].[max_query_wait_time_ms]) [MaxWait]
 FROM [sys].[query_store_wait_stats] [ws] WITH (NOLOCK) JOIN [sys].[query_store_runtime_stats_interval] [i] WITH (NOLOCK) ON [i].[runtime_stats_interval_id]=[ws].[runtime_stats_interval_id]
 WHERE [i].[end_time]>@FromUtc AND [i].[start_time]<@ToUtc AND (@WaitCategory IS NULL OR [ws].[wait_category_desc]=@WaitCategory OR CONVERT(nvarchar(10),[ws].[wait_category])=@WaitCategory)
 GROUP BY [ws].[plan_id],[ws].[execution_type_desc],[ws].[wait_category],[ws].[wait_category_desc]
)
INSERT [#QueryStoreWaitStats_Result]
SELECT TOP(@TopRows) DB_ID(),(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),[q].[query_id],[p].[plan_id],[q].[query_hash],[p].[query_plan_hash],[W].[wait_category],[W].[wait_category_desc],[W].[execution_type_desc],[W].[FirstStart],[W].[LastEnd],[W].[RecordedRows],[W].[TotalWait],CONVERT(decimal(38,3),[W].[AverageWait]),[W].[MaxWait],CASE WHEN @TextChars IS NULL OR @TextChars=0 THEN [qt].[query_sql_text] ELSE LEFT([qt].[query_sql_text],@TextChars) END
FROM [W] JOIN [sys].[query_store_plan] [p] WITH (NOLOCK) ON [p].[plan_id]=[W].[plan_id] JOIN [sys].[query_store_query] [q] WITH (NOLOCK) ON [q].[query_id]=[p].[query_id] JOIN [sys].[query_store_query_text] [qt] WITH (NOLOCK) ON [qt].[query_text_id]=[q].[query_text_id]
WHERE (@QueryId IS NULL OR [q].[query_id]=@QueryId) AND (@QueryHash IS NULL OR [q].[query_hash]=@QueryHash)'+@RefPredicate+N'
ORDER BY [W].[TotalWait] DESC,[W].[LastEnd] DESC;
END;';
          EXEC [sys].[sp_executesql] @Sql,N'@FromUtc datetime2(7),@ToUtc datetime2(7),@WaitCategory nvarchar(128),@QueryId bigint,@QueryHash binary(8),@TopRows bigint,@TextChars int,@ReferencedNames nvarchar(max),@RefValue nvarchar(4000),@RefFlags varchar(8)',@VonUtc,@BisUtc,@WaitCategory,@QueryId,@QueryHash,@LocalRows,@MaxSqlTextZeichen,@ReferencedDatabaseNames,@RefValue,@RefFlags;
        END TRY BEGIN CATCH INSERT [#QueryStoreWaitStats_Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @IsPartial=1;IF @PrintMeldungen=1 BEGIN SET @Message=FORMATMESSAGE(N'WARNUNG USP_QueryStoreWaitStats [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;END;END CATCH;
        FETCH NEXT FROM [c] INTO @Db,@DbCompat;
      END;CLOSE [c];DEALLOCATE [c];
    END;
    SELECT @RowCount=COUNT_BIG(*) FROM [#QueryStoreWaitStats_Result];SET @HasMoreRows=CONVERT(bit,CASE WHEN @EffectiveMaxZeilen<9223372036854775807 AND @RowCount>@EffectiveMaxZeilen THEN 1 ELSE 0 END);IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';
    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN
      SELECT N'USP_QueryStoreWaitStats' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],CASE WHEN @RowCount>@EffectiveMaxZeilen THEN @EffectiveMaxZeilen ELSE @RowCount END [ReturnedRowCount],@HasMoreRows [HasMoreRows],@ErrorMessage [ErrorMessage];
      IF @ResultSetArtNormalisiert='RAW' SELECT TOP(@EffectiveMaxZeilen) * FROM [#QueryStoreWaitStats_Result] ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC;
      ELSE SELECT TOP(@EffectiveMaxZeilen) N'Query-Store Wait' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[PlanId] [Plan],[WaitCategoryDesc] [Wait-Kategorie],CONCAT(CONVERT(varchar(30),CONVERT(decimal(19,2),[TotalQueryWaitTimeMs]/1000.0)),N' s') [Gesamte Wartezeit],[RecordedRows] [Messpunkte],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#QueryStoreWaitStats_Result] ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC;
      SELECT * FROM [#QueryStoreWaitStats_Errors] ORDER BY [DatabaseName];
    END;
    IF @JsonErzeugen=1
    BEGIN
      DECLARE @Meta nvarchar(max)=(SELECT N'QueryStoreWaitStats' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@MaxZeilen [requestedMaxRows],CASE WHEN @RowCount>@EffectiveMaxZeilen THEN @EffectiveMaxZeilen ELSE @RowCount END [returnedRows],@HasMoreRows [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
      DECLARE @Data nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#QueryStoreWaitStats_Result] ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC FOR JSON PATH,INCLUDE_NULL_VALUES);
      DECLARE @Warnings nvarchar(max)=(SELECT * FROM [#QueryStoreWaitStats_Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);
      SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"waitStats":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStoreWaitStats_Result'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
