USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreRegressions
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Vergleicht zwei Query-Store-Zeitfenster über eine oder mehrere
               Quelldatenbanken. Lokales N+1 und globales Top-N vermeiden eine
               vollständige Materialisierung aller Query-Store-Zeilen.
Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, regressions und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames          nvarchar(max)  = N''
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @ReferencedDatabaseNames          nvarchar(max)  = NULL
    , @ReferencedDatabaseNamePattern    nvarchar(4000) = NULL
    , @QueryId                          bigint         = NULL
    , @QueryHash                        binary(8)      = NULL
    , @BaselineVonUtc                   datetime2(7)   = NULL
    , @BaselineBisUtc                   datetime2(7)   = NULL
    , @VergleichVonUtc                  datetime2(7)   = NULL
    , @VergleichBisUtc                  datetime2(7)   = NULL
    , @Metrik                           varchar(32)    = 'DURATION_AVG'
    , @MinAusfuehrungenJeFenster        bigint         = 1
    , @MinRegressionProzent             decimal(9,2)   = 20.0
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MaxDatenbanken                   int            = 16
    , @MaxSqlTextZeichen                int            = 4000
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;SET @Metrik=UPPER(LTRIM(RTRIM(COALESCE(@Metrik,'DURATION_AVG'))));SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'TOP'))));
 DECLARE @Out varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),@Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen>0 THEN @MaxZeilen ELSE 0 END,@Local bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1 ELSE @MaxZeilen END;
 IF @Hilfe=1 BEGIN PRINT N'monitor.USP_QueryStoreRegressions';PRINT N'Quell-DB-Liste/Pattern; Referenz-DB-Liste/Pattern; zwei Zeitfenster; globales @MaxZeilen; RAW|CONSOLE|NONE und JSON.';RETURN;END;
 IF @VergleichBisUtc IS NULL SET @VergleichBisUtc=SYSUTCDATETIME();IF @VergleichVonUtc IS NULL SET @VergleichVonUtc=DATEADD(HOUR,-1,@VergleichBisUtc);IF @BaselineBisUtc IS NULL SET @BaselineBisUtc=@VergleichVonUtc;IF @BaselineVonUtc IS NULL SET @BaselineVonUtc=DATEADD(HOUR,-1,@BaselineBisUtc);
 DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Status varchar(40)='AVAILABLE',@Partial bit=0,@Error nvarchar(2048)=NULL,@Cross bit=0,@Allowed bit=1,@Db sysname,@Compat tinyint,@Sql nvarchar(max),@Count bigint=0,@HasMore bit=0,@Msg nvarchar(2048),@MetricB nvarchar(240),@MetricC nvarchar(240),@RefMode varchar(8),@RefValue nvarchar(4000),@RefFlags varchar(8),@RefValid bit,@RefPredicate nvarchar(max)=N'';
 SELECT @RefMode=[PatternMode],@RefValue=[PatternValue],@RefFlags=[RegexFlags],@RefValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@ReferencedDatabaseNamePattern);
 SET @MetricB=CASE @Metrik WHEN 'DURATION_AVG' THEN N'[b].[duration_weighted]/NULLIF([b].[executions],0)/1000.0' WHEN 'CPU_AVG' THEN N'[b].[cpu_weighted]/NULLIF([b].[executions],0)/1000.0' WHEN 'READS_AVG' THEN N'[b].[reads_weighted]/NULLIF([b].[executions],0)' WHEN 'WRITES_AVG' THEN N'[b].[writes_weighted]/NULLIF([b].[executions],0)' WHEN 'EXECUTIONS' THEN N'CONVERT(float,[b].[executions])' END;
 SET @MetricC=CASE @Metrik WHEN 'DURATION_AVG' THEN N'[c].[duration_weighted]/NULLIF([c].[executions],0)/1000.0' WHEN 'CPU_AVG' THEN N'[c].[cpu_weighted]/NULLIF([c].[executions],0)/1000.0' WHEN 'READS_AVG' THEN N'[c].[reads_weighted]/NULLIF([c].[executions],0)' WHEN 'WRITES_AVG' THEN N'[c].[writes_weighted]/NULLIF([c].[executions],0)' WHEN 'EXECUTIONS' THEN N'CONVERT(float,[c].[executions])' END;
 CREATE TABLE [#DatabaseCandidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
 CREATE TABLE [#Result]([QueryStoreDatabaseId] int,[QueryStoreDatabaseName] sysname,[QueryId] bigint,[QueryHash] binary(8),[ObjectId] bigint NULL,[ObjectName] nvarchar(517) NULL,[BaselineExecutions] bigint,[ComparisonExecutions] bigint,[BaselinePlanCount] bigint,[ComparisonPlanCount] bigint,[BaselineValue] decimal(38,3),[ComparisonValue] decimal(38,3),[AbsoluteChange] decimal(38,3),[RegressionPercent] decimal(38,3),[LastExecutionTimeUtc] datetimeoffset,[QuerySqlText] nvarchar(max));
 CREATE TABLE [#Errors]([DatabaseName] sysname,[StatusCode] varchar(40),[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048));
 IF @MetricB IS NULL OR @AnalyseModus NOT IN('TOP','VOLL') OR @MaxZeilen<0 OR @MaxDatenbanken<0 OR @MaxSqlTextZeichen < 0 OR @MinAusfuehrungenJeFenster<1 OR @MinRegressionProzent<0 OR @BaselineVonUtc>=@BaselineBisUtc OR @VergleichVonUtc>=@VergleichBisUtc OR @BaselineBisUtc>@VergleichVonUtc OR @Out NOT IN('RAW','CONSOLE','NONE') OR @RefValid=0 OR (@ReferencedDatabaseNames IS NOT NULL AND @ReferencedDatabaseNamePattern IS NOT NULL) OR (@ReferencedDatabaseNames IS NOT NULL AND EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames) WHERE [IsValid]=0)) BEGIN SET @Status='INVALID_PARAMETER';SET @Error=N'Ungültige Metrik, Grenze oder Zeitfenster.';END;
 IF @Status='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@QueryStoreDatabaseNames,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=@QueryStoreDatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='CROSS_DATABASE_DEEP',@StatusCode=@Status OUTPUT,@ErrorMessage=@Error OUTPUT,@CrossDatabaseRequested=@Cross OUTPUT;
 IF @Status='AVAILABLE' AND (@AnalyseModus='VOLL' OR @Limit>1000 OR DATEDIFF(HOUR,@BaselineVonUtc,@VergleichBisUtc)>24 OR @ReferencedDatabaseNames IS NOT NULL OR @ReferencedDatabaseNamePattern IS NOT NULL) BEGIN SELECT @Allowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='QUERY_STORE_DEEP';IF @Allowed=0 BEGIN SET @Status='DENIED_GROUP';SET @Error=N'QUERY_STORE_DEEP ist nicht freigegeben.';END;END;
 IF @ReferencedDatabaseNames IS NOT NULL SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) JOIN [monitor].[TVF_ParseSqlNameList](@ReferencedNames) [rf] ON [rf].[IsValid]=1 AND [rf].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS=PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode='LIKE' SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @RefValue COLLATE SQL_Latin1_General_CP1_CS_AS)';
 ELSE IF @RefMode IN('REGEX','REGEXI') SET @RefPredicate=N' AND EXISTS(SELECT 1 FROM (SELECT TRY_CONVERT(xml,[p].[query_plan]) [PlanXml]) [px] CROSS APPLY [px].[PlanXml].nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //Object[@Database]'') [n]([x]) WHERE REGEXP_LIKE(PARSENAME([n].[x].value(''@Database'',''nvarchar(776)''),1),@RefValue,@RefFlags))';
 SET LOCK_TIMEOUT 0;
 IF @Status='AVAILABLE' BEGIN DECLARE [c] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[CompatibilityLevel] FROM [#DatabaseCandidates] ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];OPEN [c];FETCH NEXT FROM [c] INTO @Db,@Compat;WHILE @@FETCH_STATUS=0 BEGIN IF @RefMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR @Compat<170) BEGIN INSERT [#Errors] VALUES(@Db,'UNAVAILABLE_FEATURE',NULL,N'Regex benötigt SQL Server 2025 und Compatibility Level 170.');SET @Partial=1;END ELSE BEGIN TRY
 SET @Sql=N'USE '+QUOTENAME(@Db)+N';IF EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WHERE [actual_state] IN(1,2,4))
BEGIN
;WITH [R0] AS
(
 SELECT [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text],[p].[plan_id],[i].[start_time],[i].[end_time],MAX([rs].[last_execution_time]) [last_execution_time],SUM([rs].[count_executions]) [executions],SUM(CONVERT(float,[rs].[avg_duration])*[rs].[count_executions]) [duration_weighted],SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions]) [cpu_weighted],SUM(CONVERT(float,[rs].[avg_logical_io_reads])*[rs].[count_executions]) [reads_weighted],SUM(CONVERT(float,[rs].[avg_logical_io_writes])*[rs].[count_executions]) [writes_weighted]
 FROM [sys].[query_store_runtime_stats] [rs] JOIN [sys].[query_store_runtime_stats_interval] [i] ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id] JOIN [sys].[query_store_plan] [p] ON [p].[plan_id]=[rs].[plan_id] JOIN [sys].[query_store_query] [q] ON [q].[query_id]=[p].[query_id] JOIN [sys].[query_store_query_text] [qt] ON [qt].[query_text_id]=[q].[query_text_id]
 WHERE (([i].[end_time]>@BFrom AND [i].[start_time]<@BTo) OR ([i].[end_time]>@CFrom AND [i].[start_time]<@CTo)) AND (@QueryId IS NULL OR [q].[query_id]=@QueryId) AND (@QueryHash IS NULL OR [q].[query_hash]=@QueryHash)'+@RefPredicate+N'
 GROUP BY [q].[query_id],[q].[query_hash],[q].[object_id],[qt].[query_sql_text],[p].[plan_id],[i].[start_time],[i].[end_time]
),[R] AS
(
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[plan_id],[last_execution_time],[executions],[duration_weighted],[cpu_weighted],[reads_weighted],[writes_weighted],''B'' [W] FROM [R0] WHERE [end_time]>@BFrom AND [start_time]<@BTo
 UNION ALL
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[plan_id],[last_execution_time],[executions],[duration_weighted],[cpu_weighted],[reads_weighted],[writes_weighted],''C'' [W] FROM [R0] WHERE [end_time]>@CFrom AND [start_time]<@CTo
),[A] AS
(
 SELECT [query_id],[query_hash],[object_id],[query_sql_text],[W],SUM([executions]) [executions],COUNT(DISTINCT [plan_id]) [plan_count],MAX([last_execution_time]) [last_execution_time],SUM([duration_weighted]) [duration_weighted],SUM([cpu_weighted]) [cpu_weighted],SUM([reads_weighted]) [reads_weighted],SUM([writes_weighted]) [writes_weighted] FROM [R] GROUP BY [query_id],[query_hash],[object_id],[query_sql_text],[W]
),[P] AS
(
 SELECT [b].[query_id],[b].[query_hash],[b].[object_id],[b].[query_sql_text],[b].[executions] [bexec],[c].[executions] [cexec],[b].[plan_count] [bplans],[c].[plan_count] [cplans],[c].[last_execution_time],CONVERT(float,'+@MetricB+N') [bvalue],CONVERT(float,'+@MetricC+N') [cvalue] FROM [A] [b] JOIN [A] [c] ON [c].[query_id]=[b].[query_id] AND [c].[W]=''C'' WHERE [b].[W]=''B'' AND [b].[executions]>=@MinExec AND [c].[executions]>=@MinExec
)
INSERT [#Result] SELECT TOP(@TopRows) DB_ID(),DB_NAME(),[P].[query_id],[P].[query_hash],[P].[object_id],CASE WHEN [P].[object_id]>0 THEN QUOTENAME([os].[name])+N''.''+QUOTENAME([oo].[name]) END,[P].[bexec],[P].[cexec],[P].[bplans],[P].[cplans],CONVERT(decimal(38,3),[P].[bvalue]),CONVERT(decimal(38,3),[P].[cvalue]),CONVERT(decimal(38,3),[P].[cvalue]-[P].[bvalue]),CONVERT(decimal(38,3),100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0)),[P].[last_execution_time],CASE WHEN @TextChars IS NULL OR @TextChars=0 THEN [P].[query_sql_text] ELSE LEFT([P].[query_sql_text],@TextChars) END FROM [P] LEFT JOIN [sys].[objects] AS [oo] WITH (NOLOCK) ON [oo].[object_id]=[P].[object_id] LEFT JOIN [sys].[schemas] AS [os] WITH (NOLOCK) ON [os].[schema_id]=[oo].[schema_id] WHERE [P].[bvalue] IS NOT NULL AND [P].[cvalue] IS NOT NULL AND 100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0)>=@MinPct ORDER BY 100.0*([P].[cvalue]-[P].[bvalue])/NULLIF(ABS([P].[bvalue]),0) DESC,[P].[cvalue]-[P].[bvalue] DESC;
END;';
 EXEC [sys].[sp_executesql] @Sql,N'@BFrom datetime2(7),@BTo datetime2(7),@CFrom datetime2(7),@CTo datetime2(7),@QueryId bigint,@QueryHash binary(8),@MinExec bigint,@MinPct decimal(9,2),@TopRows bigint,@TextChars int,@ReferencedNames nvarchar(max),@RefValue nvarchar(4000),@RefFlags varchar(8)',@BaselineVonUtc,@BaselineBisUtc,@VergleichVonUtc,@VergleichBisUtc,@QueryId,@QueryHash,@MinAusfuehrungenJeFenster,@MinRegressionProzent,@Local,@MaxSqlTextZeichen,@ReferencedDatabaseNames,@RefValue,@RefFlags;
 END TRY BEGIN CATCH INSERT [#Errors] VALUES(@Db,CASE WHEN ERROR_NUMBER() IN(229,262,297,300,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,ERROR_NUMBER(),ERROR_MESSAGE());SET @Partial=1;IF @PrintMeldungen=1 BEGIN SET @Msg=FORMATMESSAGE(N'WARNUNG USP_QueryStoreRegressions [%s]: %s',@Db,ERROR_MESSAGE());RAISERROR(N'%s',10,1,@Msg) WITH NOWAIT;END;END CATCH;FETCH NEXT FROM [c] INTO @Db,@Compat;END;CLOSE [c];DEALLOCATE [c];END;
 SELECT @Count=COUNT_BIG(*) FROM [#Result];SET @HasMore=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @Count>@Limit THEN 1 ELSE 0 END);IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
 IF @Out<>'NONE' BEGIN SELECT N'USP_QueryStoreRegressions' [ModuleName],@Now [CollectionTimeUtc],@Status [StatusCode],@Partial [IsPartial],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [ReturnedRowCount],@HasMore [HasMoreRows],@Metrik [Metric],@Error [ErrorMessage];IF @Out='RAW' SELECT TOP(@Limit) * FROM [#Result] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC;ELSE SELECT TOP(@Limit) N'Query-Store Regression' [Ergebnis],[QueryStoreDatabaseName] [Query-Store-Datenbank],[QueryId] [Query],[ObjectName] [Objekt],CONCAT(CONVERT(varchar(30),[BaselineValue]),N' → ',CONVERT(varchar(30),[ComparisonValue])) [Vergleich],CONCAT(CONVERT(varchar(30),[RegressionPercent]),N' %') [Regression],[LastExecutionTimeUtc] [letzte Ausführung],[QueryStoreDatabaseName] [Quelle],[QuerySqlText] [SQL-Text] FROM [#Result] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC;SELECT * FROM [#Errors] ORDER BY [DatabaseName];END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'QueryStoreRegressions' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@Status [statusCode],@Metrik [metric],@MaxZeilen [requestedMaxRows],CASE WHEN @Count>@Limit THEN @Limit ELSE @Count END [returnedRows],@HasMore [hasMoreRows] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@Data nvarchar(max)=(SELECT TOP(@Limit) * FROM [#Result] ORDER BY [RegressionPercent] DESC,[AbsoluteChange] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),@Warnings nvarchar(max)=(SELECT * FROM [#Errors] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"regressions":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');END;
END;
GO
