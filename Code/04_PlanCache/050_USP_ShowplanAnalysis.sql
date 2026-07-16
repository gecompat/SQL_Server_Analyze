USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ShowplanAnalysis
Version      : 1.1.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Analysiert gezielt oder explizit breit Showplan-XML auf Statements,
               Warnings, Missing Indexes, Objekte, Statistiken, Operatoren,
               Cardinality-Abweichungen und Memory Grants.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_query_stats, sys.dm_exec_sql_text,
               sys.dm_exec_plan_attributes, sys.dm_exec_query_plan,
               sys.dm_exec_query_plan_stats und Showplan-XML.
Parameter    : @PlanHandle, @QueryHash, @QueryPlanHash, @DatabaseNames,
               @TextPattern, @AnalyseModus, @PlanQuelle, @Sortierung,
               @MinExecutionCount, @MaxAnalyseobjekte, @MaxDurationSeconds,
               @MaxZeilen, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Status je Plan. 3. Statements. 4. Findings.
               5. Missing-Index-Spalten. 6. verwendete Objekte.
               7. verwendete Statistiken. 8. Operatoren.
               9. Cardinality. 10. Memory-Grant-Informationen. 11. Parameterwerte.
Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+ VIEW SERVER PERFORMANCE STATE.
Eigenlast    : XML wird erst nach Kandidatenselektion planweise geladen und
               geschreddert. VOLL oder mehr als 20 Pläne prüft PLAN_CACHE_DEEP
               und SHOWPLAN_XML_DEEP; dies gilt ebenfalls ab mehr als 20 Plänen.
               Zeit- und Mengenlimits sind hart vorgesehen.
Locking      : Keine Benutzerobjekte.
Partial      : Jeder Plan wird isoliert verarbeitet. Timeout, Cache-Eviction,
               deaktivierte Last-Actual-Plan-Erfassung und XML-Fehler lassen
               andere Pläne und Resultsets bestehen.
Beispiele    : EXEC monitor.USP_ShowplanAnalysis @PlanHandle=0x...;
               EXEC monitor.USP_ShowplanAnalysis @QueryHash=0x...,@PlanQuelle='AUTO';
               EXEC monitor.USP_ShowplanAnalysis @AnalyseModus='VOLL',@MaxAnalyseobjekte=500,@MaxDurationSeconds=60;
               EXEC monitor.USP_ShowplanAnalysis @Hilfe=1;
Änderungen   : 1.1.0 - Deep-Gate ab mehr als 20 Plänen und sichere
               Vorberechnung der Runtime-Counter vor Aggregation.
               1.0.0 - Erstfassung Phase 3.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ShowplanAnalysis]
      @PlanHandle          varbinary(64)  = NULL
    , @QueryHash           binary(8)      = NULL
    , @QueryPlanHash       binary(8)      = NULL
    , @DatabaseNames       nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen bit   = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @MaxDatenbanken      int            = 16
    , @TextPattern         nvarchar(4000) = NULL
    , @AnalyseModus        varchar(16)    = 'GEZIELT'
    , @PlanQuelle          varchar(16)    = 'AUTO'
    , @Sortierung         varchar(32)    = 'CPU_TOTAL'
    , @MinExecutionCount   bigint         = 1
    , @MaxAnalyseobjekte  int            = 20
    , @MaxDurationSeconds  int            = 30
    , @MaxZeilen          int            = 50000
    , @ResultSetArt        varchar(16)    = 'CONSOLE'
    , @JsonErzeugen        bit            = 0
    , @Json                 nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen      bit            = 1
    , @Hilfe               bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @EffectiveMaxAnalyseobjekte bigint = CASE WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxAnalyseobjekte) END;
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    SET @AnalyseModus=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
    SET @PlanQuelle=UPPER(LTRIM(RTRIM(COALESCE(@PlanQuelle,'AUTO'))));
    SET @Sortierung=UPPER(LTRIM(RTRIM(COALESCE(@Sortierung,'CPU_TOTAL'))));
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ShowplanAnalysis';
        PRINT N'@PlanHandle, @QueryHash, @QueryPlanHash, @DatabaseNames, @TextPattern: Selektoren. GEZIELT benötigt mindestens einen Selektor.';
        PRINT N'@AnalyseModus GEZIELT oder VOLL. VOLL und mehr als 20 Pläne prüfen PLAN_CACHE_DEEP und SHOWPLAN_XML_DEEP.';
        PRINT N'@PlanQuelle AUTO, COMPILE oder LAST_ACTUAL. AUTO versucht Last Actual und fällt je Plan auf Compile zurück.';
        PRINT N'@Sortierung CPU_TOTAL, ELAPSED_TOTAL, READS_TOTAL, EXECUTIONS, SPILLS_TOTAL, GRANT_MAX, LAST_EXECUTION.';
        PRINT N'@MinExecutionCount bigint=1; @MaxAnalyseobjekte int=20 und @MaxZeilen int=50000: positive Werte begrenzen, NULL/0 = unbegrenzt; @MaxDurationSeconds int=30 (1..3600).';
        PRINT N'@PrintMeldungen bit=1; @Hilfe bit=0. Das Framework aktiviert LAST_QUERY_PLAN_STATS niemals.';
        PRINT N'Findings sind Diagnosehinweise und keine automatischen Tuning- oder Indexbefehle.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3),@StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,
            @RowCount bigint=0,@ProcessedPlans int=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@Detail nvarchar(2000)=NULL,
            @PlanCacheAllowed bit=1,@ShowplanAllowed bit=1,@CrossDatabaseRequested bit=0,@OrderExpression nvarchar(300),@Sql nvarchar(max),
            @RequiredPermission nvarchar(256)=CASE WHEN TRY_CONVERT([int],SERVERPROPERTY(N'ProductMajorVersion'))>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;

    CREATE TABLE [#Candidate]
    (
        [CandidateId] int IDENTITY(1,1) PRIMARY KEY,[PlanHandle] varbinary(64) NOT NULL,[SqlHandle] varbinary(64) NULL,
        [StatementStartOffset] int NULL,[StatementEndOffset] int NULL,[QueryHash] binary(8) NULL,[QueryPlanHash] binary(8) NULL,
        [ExecutionCount] bigint NULL,[TotalWorkerTime] bigint NULL,[TotalElapsedTime] bigint NULL,[TotalLogicalReads] bigint NULL,
        [TotalSpills] bigint NULL,[MaxGrantKb] bigint NULL,[LastExecutionTime] datetime NULL
    );
    CREATE TABLE [#PlanStatus]([CandidateId] int,[PlanHandle] varbinary(64),[PlanSource] varchar(16),[StatusCode] varchar(40),[ParseDurationMs] bigint,[StatementCount] bigint,[FindingCount] bigint,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL);
    CREATE TABLE [#Statements]([CandidateId] int,[StatementId] int IDENTITY(1,1),[StatementType] nvarchar(128),[StatementText] nvarchar(max),[StatementSubTreeCost] decimal(38,8) NULL,[CardinalityEstimationModelVersion] int NULL,[OptimizationLevel] nvarchar(128),[EarlyAbortReason] nvarchar(256),[RetrievedFromCache] bit NULL,[StatementQueryHash] nvarchar(130),[StatementQueryPlanHash] nvarchar(130));
    CREATE TABLE [#Findings]([CandidateId] int,[FindingType] varchar(64),[Severity] varchar(16),[NodeId] int NULL,[PhysicalOp] nvarchar(128) NULL,[LogicalOp] nvarchar(128) NULL,[Detail] nvarchar(4000) NULL);
    CREATE TABLE [#MissingIndexes]([CandidateId] int,[Impact] decimal(19,4) NULL,[DatabaseName] nvarchar(256),[SchemaName] nvarchar(256),[TableName] nvarchar(256),[ColumnGroupUsage] nvarchar(60),[ColumnName] nvarchar(256),[ColumnId] int NULL);
    CREATE TABLE [#Objects]([CandidateId] int,[DatabaseName] nvarchar(256),[SchemaName] nvarchar(256),[TableName] nvarchar(256),[IndexName] nvarchar(256),[AliasName] nvarchar(256),[Storage] nvarchar(128));
    CREATE TABLE [#Statistics]([CandidateId] int,[DatabaseName] nvarchar(256),[SchemaName] nvarchar(256),[TableName] nvarchar(256),[StatisticsName] nvarchar(256),[LastUpdate] datetime NULL,[ModificationCount] bigint NULL,[SamplingPercent] decimal(19,4) NULL);
    CREATE TABLE [#Operators]([CandidateId] int,[NodeId] int NULL,[PhysicalOp] nvarchar(128),[LogicalOp] nvarchar(128),[EstimateRows] decimal(38,4) NULL,[EstimatedRowsRead] decimal(38,4) NULL,[EstimatedTotalSubtreeCost] decimal(38,8) NULL,[Parallel] bit NULL,[EstimateRebinds] decimal(38,4) NULL,[EstimateRewinds] decimal(38,4) NULL);
    CREATE TABLE [#Cardinality]([CandidateId] int,[NodeId] int NULL,[PhysicalOp] nvarchar(128),[LogicalOp] nvarchar(128),[EstimateRows] decimal(38,4) NULL,[ActualRows] decimal(38,4) NULL,[EstimateRowsRead] decimal(38,4) NULL,[ActualRowsRead] decimal(38,4) NULL,[ActualExecutions] bigint NULL,[ActualToEstimatedRatio] decimal(38,6) NULL);
    CREATE TABLE [#Memory]([CandidateId] int,[SerialRequiredMemoryKb] bigint NULL,[SerialDesiredMemoryKb] bigint NULL,[RequiredMemoryKb] bigint NULL,[DesiredMemoryKb] bigint NULL,[RequestedMemoryKb] bigint NULL,[GrantWaitTimeMs] bigint NULL,[GrantedMemoryKb] bigint NULL,[MaxUsedMemoryKb] bigint NULL,[MaxQueryMemoryKb] bigint NULL,[LastRequestedMemoryKb] bigint NULL,[IsMemoryGrantFeedbackAdjusted] nvarchar(128));
    CREATE TABLE [#Parameters]([CandidateId] int,[ParameterName] nvarchar(256),[ParameterDataType] nvarchar(256),[CompiledValue] nvarchar(4000),[RuntimeValue] nvarchar(4000));

    IF @AnalyseModus NOT IN('GEZIELT','VOLL') OR @PlanQuelle NOT IN('AUTO','COMPILE','LAST_ACTUAL') OR @MaxAnalyseobjekte<0 OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600 OR @MaxZeilen<0 OR @MinExecutionCount<0 OR @MaxDatenbanken<0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'Ungültiger Modus oder Grenzwert.';END;
    IF @StatusCode='AVAILABLE' AND @AnalyseModus='GEZIELT' AND @PlanHandle IS NULL AND @QueryHash IS NULL AND @QueryPlanHash IS NULL AND @DatabaseNames=N'' AND @DatabaseNamePattern IS NULL AND @TextPattern IS NULL
    BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'GEZIELT benötigt mindestens einen Selektor.';END;
    IF @StatusCode='AVAILABLE' AND (@AnalyseModus='VOLL' OR @EffectiveMaxAnalyseobjekte>20)
    BEGIN
        SELECT @PlanCacheAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='PLAN_CACHE_DEEP';
        SELECT @ShowplanAllowed=COALESCE(MAX(CONVERT(tinyint,[IsAllowed])),0) FROM [monitor].[VW_AnalyseAccessCurrent] WHERE [AnalysisClass]='SHOWPLAN_XML_DEEP';
        IF @PlanCacheAllowed=0 OR @ShowplanAllowed=0 BEGIN SET @StatusCode='DENIED_GROUP';SET @ErrorMessage=N'PLAN_CACHE_DEEP und SHOWPLAN_XML_DEEP sind erforderlich.';END;
    END;
    IF @StatusCode='AVAILABLE' SET @Deadline=DATEADD(SECOND,@MaxDurationSeconds,@CollectionTimeUtc);
    CREATE TABLE [#DatabaseCandidates]([DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname NOT NULL,[StateDesc] nvarchar(60),[UserAccessDesc] nvarchar(60),[IsReadOnly] bit,[CompatibilityLevel] tinyint,[CollationName] sysname,[RecoveryModelDesc] nvarchar(60),[IsSystemDatabase] bit,[RequestedOrdinal] int);
    CREATE TABLE [#DatabaseCandidateWarnings]([RequestedName] sysname NULL,[StatusCode] varchar(40) NOT NULL,[ErrorMessage] nvarchar(2048) NULL);
    DECLARE @TextMode varchar(8),@TextValue nvarchar(4000),@TextRegexFlags varchar(8),@TextPatternValid bit;
    SELECT @TextMode=[PatternMode],@TextValue=[PatternValue],@TextRegexFlags=[RegexFlags],@TextPatternValid=[IsValid] FROM [monitor].[TVF_ParsePattern](@TextPattern);
    IF @StatusCode='AVAILABLE' AND @TextPatternValid=0 BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@TextPattern ist ungültig.';END;
    IF @StatusCode='AVAILABLE' EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@MaxDatenbanken=@MaxDatenbanken,@AnalysisClass='PLAN_CACHE_DEEP',@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;
    IF @StatusCode='AVAILABLE' AND @TextMode IN('REGEX','REGEXI') AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17 OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] AS [d] WITH(NOLOCK) WHERE [d].[name]=N'DeineDatenbank' AND [d].[compatibility_level]>=170)) BEGIN SET @StatusCode='UNAVAILABLE_FEATURE';SET @ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';END;

    SET @OrderExpression=CASE @Sortierung WHEN 'CPU_TOTAL' THEN N'[qs].[total_worker_time]' WHEN 'ELAPSED_TOTAL' THEN N'[qs].[total_elapsed_time]'
        WHEN 'READS_TOTAL' THEN N'[qs].[total_logical_reads]' WHEN 'EXECUTIONS' THEN N'[qs].[execution_count]' WHEN 'SPILLS_TOTAL' THEN N'[qs].[total_spills]'
        WHEN 'GRANT_MAX' THEN N'[qs].[max_grant_kb]' WHEN 'LAST_EXECUTION' THEN N'DATEDIFF_BIG(MILLISECOND,''20000101'',[qs].[last_execution_time])' ELSE NULL END;
    IF @StatusCode='AVAILABLE' AND @OrderExpression IS NULL BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'Unbekannter @Sortierung-Wert.';END;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        IF @PlanHandle IS NOT NULL
            INSERT [#Candidate]([PlanHandle]) VALUES(@PlanHandle);
        ELSE
        BEGIN
            SET @Sql=N'INSERT [#Candidate]([PlanHandle],[SqlHandle],[StatementStartOffset],[StatementEndOffset],[QueryHash],[QueryPlanHash],[ExecutionCount],[TotalWorkerTime],[TotalElapsedTime],[TotalLogicalReads],[TotalSpills],[MaxGrantKb],[LastExecutionTime])
            SELECT TOP(@TopRows) [qs].[plan_handle],[qs].[sql_handle],[qs].[statement_start_offset],[qs].[statement_end_offset],[qs].[query_hash],[qs].[query_plan_hash],[qs].[execution_count],[qs].[total_worker_time],[qs].[total_elapsed_time],[qs].[total_logical_reads],[qs].[total_spills],[qs].[max_grant_kb],[qs].[last_execution_time]
            FROM [sys].[dm_exec_query_stats] AS [qs] ';
            SET @Sql+=N'OUTER APPLY (SELECT TOP (1) TRY_CONVERT(int, [value]) AS [dbid] FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) WHERE [attribute] = ''dbid'') AS [pa] ';
            IF @TextMode IS NOT NULL SET @Sql+=N'OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st] ';
            SET @Sql+=N'WHERE [qs].[execution_count] >= @MinExec AND (@QH IS NULL OR [qs].[query_hash] = @QH) AND (@QPH IS NULL OR [qs].[query_plan_hash] = @QPH) ';
            SET @Sql+=N'AND EXISTS(SELECT 1 FROM [#DatabaseCandidates] AS [dc] WHERE [dc].[DatabaseId]=[pa].[dbid]) ';
            IF @TextMode='LIKE' SET @Sql+=N'AND [st].[text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextValue COLLATE SQL_Latin1_General_CP1_CS_AS ';
            IF @TextMode IN('REGEX','REGEXI') SET @Sql+=N'AND REGEXP_LIKE([st].[text],@TextValue,@TextFlags)=1 ';
            SET @Sql+=N'ORDER BY '+@OrderExpression+N' DESC, [qs].[last_execution_time] DESC OPTION (RECOMPILE, MAXDOP 1);';
            EXEC [sys].[sp_executesql] @Sql,N'@TopRows bigint,@MinExec bigint,@QH binary(8),@QPH binary(8),@TextValue nvarchar(4000),@TextFlags varchar(8)',@TopRows=@EffectiveMaxAnalyseobjekte,@MinExec=@MinExecutionCount,@QH=@QueryHash,@QPH=@QueryPlanHash,@TextValue=@TextValue,@TextFlags=@TextRegexFlags;
        END;
        SELECT @RowCount=COUNT_BIG(*) FROM [#Candidate];SET @Detail=CASE WHEN @RowCount=0 THEN N'Keine passenden Plankandidaten.' ELSE N'Plankandidaten vorselektiert; XML wird planweise verarbeitet.' END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;
        SET @StatusCode=CASE WHEN @ErrorNumber IN(229,262,297,300,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    DECLARE @CandidateId int,@CurrentPlanHandle varbinary(64),@PlanXml xml,@PlanSource varchar(16),@Started datetime2(3),@PlanError int,@PlanErrorMessage nvarchar(2048),@StatementCount bigint,@FindingCount bigint;
    DECLARE PlanCursor CURSOR LOCAL FAST_FORWARD FOR SELECT [CandidateId],[PlanHandle] FROM [#Candidate] ORDER BY [CandidateId];
    IF @StatusCode='AVAILABLE'
    BEGIN
        OPEN PlanCursor;FETCH NEXT FROM PlanCursor INTO @CandidateId,@CurrentPlanHandle;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline OR (SELECT COUNT_BIG(*) FROM [#Findings])>=@EffectiveMaxZeilen
            BEGIN SET @StatusCode='PARTIAL';SET @IsPartial=1;SET @Detail=N'Zeit- oder Ergebnismengenbudget erreicht; verbleibende Pläne wurden nicht verarbeitet.';BREAK;END;
            SELECT @PlanXml=NULL,@PlanSource=NULL,@Started=SYSUTCDATETIME(),@PlanError=NULL,@PlanErrorMessage=NULL,@StatementCount=0,@FindingCount=0;
            BEGIN TRY
                IF @PlanQuelle IN('AUTO','LAST_ACTUAL')
                BEGIN
                    SELECT @PlanXml=[query_plan] FROM sys.dm_exec_query_plan_stats(@CurrentPlanHandle);
                    IF @PlanXml IS NOT NULL SET @PlanSource='LAST_ACTUAL';
                END;
                IF @PlanXml IS NULL AND @PlanQuelle IN('AUTO','COMPILE')
                BEGIN
                    SELECT @PlanXml=[query_plan] FROM sys.dm_exec_query_plan(@CurrentPlanHandle);
                    IF @PlanXml IS NOT NULL SET @PlanSource='COMPILE';
                END;
                IF @PlanXml IS NULL
                BEGIN
                    INSERT [#PlanStatus] VALUES(@CandidateId,@CurrentPlanHandle,COALESCE(@PlanSource,@PlanQuelle),'UNAVAILABLE_OBJECT',DATEDIFF_BIG([MILLISECOND],@Started,SYSUTCDATETIME()),0,0,NULL,N'Plan nicht verfügbar, evictet, nicht cachebar, Last Actual deaktiviert oder XML-Tiefenlimit erreicht.');
                END
                ELSE
                BEGIN
                    INSERT [#Statements]([CandidateId],[StatementType],[StatementText],[StatementSubTreeCost],[CardinalityEstimationModelVersion],[OptimizationLevel],[EarlyAbortReason],[RetrievedFromCache],[StatementQueryHash],[StatementQueryPlanHash])
                    SELECT @CandidateId,NULLIF(s.value('string((@StatementType)[1])','nvarchar(128)'),N''),NULLIF(s.value('string((@StatementText)[1])','nvarchar(max)'),N''),
                           TRY_CONVERT(decimal(38,8),NULLIF(s.value('string((@StatementSubTreeCost)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT([int],NULLIF(s.value('string((@CardinalityEstimationModelVersion)[1])','nvarchar(100)'),N'')),
                           NULLIF(s.value('string((@StatementOptmLevel)[1])','nvarchar(128)'),N''),NULLIF(s.value('string((@StatementOptmEarlyAbortReason)[1])','nvarchar(256)'),N''),
                           TRY_CONVERT([bit],NULLIF(s.value('string((@RetrievedFromCache)[1])','nvarchar(20)'),N'')),NULLIF(s.value('string((@QueryHash)[1])','nvarchar(130)'),N''),NULLIF(s.value('string((@QueryPlanHash)[1])','nvarchar(130)'),N'')
                    FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [X]([s]);

                    INSERT [#Operators]([CandidateId],[NodeId],[PhysicalOp],[LogicalOp],[EstimateRows],[EstimatedRowsRead],[EstimatedTotalSubtreeCost],[Parallel],[EstimateRebinds],[EstimateRewinds])
                    SELECT @CandidateId,TRY_CONVERT([int],NULLIF(r.value('string((@NodeId)[1])','nvarchar(50)'),N'')),NULLIF(r.value('string((@PhysicalOp)[1])','nvarchar(128)'),N''),NULLIF(r.value('string((@LogicalOp)[1])','nvarchar(128)'),N''),
                           TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimateRows)[1])','nvarchar(100)'),N'')),TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimatedRowsRead)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT(decimal(38,8),NULLIF(r.value('string((@EstimatedTotalSubtreeCost)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bit],NULLIF(r.value('string((@Parallel)[1])','nvarchar(20)'),N'')),
                           TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimateRebinds)[1])','nvarchar(100)'),N'')),TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimateRewinds)[1])','nvarchar(100)'),N''))
                    FROM @PlanXml.nodes('//*[local-name(.)="RelOp"]') AS [X]([r]);

                    INSERT [#Cardinality]([CandidateId],[NodeId],[PhysicalOp],[LogicalOp],[EstimateRows],[ActualRows],[EstimateRowsRead],[ActualRowsRead],[ActualExecutions],[ActualToEstimatedRatio])
                    SELECT @CandidateId,[v].[NodeId],[v].[PhysicalOp],[v].[LogicalOp],[v].[EstimateRows],
                           SUM([av].[ActualRows]),
                           [v].[EstimateRowsRead],
                           SUM([av].[ActualRowsRead]),
                           SUM([av].[ActualExecutions]),NULL
                    FROM @PlanXml.nodes('//*[local-name(.)="RelOp"]') AS [X]([r])
                    CROSS APPLY (VALUES
                    (
                        TRY_CONVERT([int],NULLIF(r.value('string((@NodeId)[1])','nvarchar(50)'),N'')),
                        NULLIF(r.value('string((@PhysicalOp)[1])','nvarchar(128)'),N''),
                        NULLIF(r.value('string((@LogicalOp)[1])','nvarchar(128)'),N''),
                        TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimateRows)[1])','nvarchar(100)'),N'')),
                        TRY_CONVERT(decimal(38,4),NULLIF(r.value('string((@EstimatedRowsRead)[1])','nvarchar(100)'),N''))
                    )) AS [v]([NodeId],[PhysicalOp],[LogicalOp],[EstimateRows],[EstimateRowsRead])
                    OUTER APPLY r.nodes('./*[local-name(.)="RunTimeInformation"]/*[local-name(.)="RunTimeCountersPerThread"]') AS [A]([a])
                    OUTER APPLY
                    (
                        VALUES
                        (
                            TRY_CONVERT(decimal(38,4),NULLIF(a.value('string((@ActualRows)[1])','nvarchar(100)'),N'')),
                            TRY_CONVERT(decimal(38,4),NULLIF(a.value('string((@ActualRowsRead)[1])','nvarchar(100)'),N'')),
                            TRY_CONVERT([bigint],NULLIF(a.value('string((@ActualExecutions)[1])','nvarchar(100)'),N''))
                        )
                    ) AS [av]([ActualRows],[ActualRowsRead],[ActualExecutions])
                    GROUP BY [v].[NodeId],[v].[PhysicalOp],[v].[LogicalOp],[v].[EstimateRows],[v].[EstimateRowsRead];
                    UPDATE [#Cardinality] SET [ActualToEstimatedRatio]=[ActualRows]/NULLIF([EstimateRows],0) WHERE [CandidateId]=@CandidateId;

                    INSERT [#Findings] SELECT @CandidateId,'NO_JOIN_PREDICATE','HIGH',TRY_CONVERT([int],NULLIF(r.value('string((@NodeId)[1])','nvarchar(50)'),N'')),r.value('string((@PhysicalOp)[1])','nvarchar(128)'),r.value('string((@LogicalOp)[1])','nvarchar(128)'),N'Warnings/@NoJoinPredicate=1'
                    FROM @PlanXml.nodes('//*[local-name(.)="RelOp"]') AS [X]([r]) WHERE r.exist('./*[local-name(.)="Warnings"][@NoJoinPredicate="1"]')=1;
                    INSERT [#Findings] SELECT @CandidateId,'IMPLICIT_CONVERSION','MEDIUM',NULL,NULL,NULL,LEFT(NULLIF(s.value('string((@ScalarString)[1])','nvarchar(4000)'),N''),4000)
                    FROM @PlanXml.nodes('//*[local-name(.)="ScalarOperator"][contains(@ScalarString,"CONVERT_IMPLICIT")]') AS [X]([s]);
                    INSERT [#Findings] SELECT @CandidateId,'PLAN_AFFECTING_CONVERT','HIGH',NULL,NULL,NULL,LEFT(CONCAT(N'Issue=',p.value('string((@ConvertIssue)[1])','nvarchar(256)'),N'; Expression=',p.value('string((@Expression)[1])','nvarchar(3500)')),4000)
                    FROM @PlanXml.nodes('//*[local-name(.)="PlanAffectingConvert"]') AS [X]([p]);
                    INSERT [#Findings] SELECT @CandidateId,'SPILL','HIGH',NULL,NULL,NULL,LEFT(CONCAT(N'Element=',sp.value('local-name(.)','nvarchar(128)'),N'; SpillLevel=',sp.value('string((@SpillLevel)[1])','nvarchar(100)'),N'; SpilledDataSize=',sp.value('string((@SpilledDataSize)[1])','nvarchar(100)')),4000)
                    FROM @PlanXml.nodes('//*[local-name(.)="SpillToTempDb" or local-name(.)="HashSpillDetails" or local-name(.)="SortSpillDetails"]') AS [X]([sp]);
                    INSERT [#Findings] SELECT @CandidateId,'COLUMN_WITHOUT_STATISTICS','HIGH',NULL,NULL,NULL,LEFT(CONCAT(c.value('string((@Database)[1])','nvarchar(256)'),N'.',c.value('string((@Schema)[1])','nvarchar(256)'),N'.',c.value('string((@Table)[1])','nvarchar(256)'),N'.',c.value('string((@Column)[1])','nvarchar(256)')),4000)
                    FROM @PlanXml.nodes('//*[local-name(.)="ColumnsWithNoStatistics"]/*[local-name(.)="ColumnReference"]') AS [X]([c]);
                    INSERT [#Findings] SELECT @CandidateId,'UNMATCHED_INDEX','MEDIUM',NULL,NULL,NULL,N'Plan enthält UnmatchedIndexes-Warnung.' FROM @PlanXml.nodes('//*[local-name(.)="UnmatchedIndexes"]') AS [X]([u]);
                    INSERT [#Findings] SELECT @CandidateId,'OPTIMIZER_EARLY_ABORT','MEDIUM',NULL,NULL,NULL,s.value('string((@StatementOptmEarlyAbortReason)[1])','nvarchar(4000)')
                    FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"][@StatementOptmEarlyAbortReason]') AS [X]([s]);
                    INSERT [#Findings] SELECT @CandidateId,'KEY_LOOKUP','MEDIUM',TRY_CONVERT([int],NULLIF(r.value('string((@NodeId)[1])','nvarchar(50)'),N'')),r.value('string((@PhysicalOp)[1])','nvarchar(128)'),r.value('string((@LogicalOp)[1])','nvarchar(128)'),N'Key Lookup bzw. Lookup=1 im Plan.'
                    FROM @PlanXml.nodes('//*[local-name(.)="RelOp"]') AS [X]([r]) WHERE r.value('string((@PhysicalOp)[1])','nvarchar(128)')='Key Lookup' OR r.exist('.//*[@Lookup="1"]')=1;
                    INSERT [#Findings] SELECT @CandidateId,'TABLE_SCAN','INFO',TRY_CONVERT([int],NULLIF(r.value('string((@NodeId)[1])','nvarchar(50)'),N'')),r.value('string((@PhysicalOp)[1])','nvarchar(128)'),r.value('string((@LogicalOp)[1])','nvarchar(128)'),N'Table Scan; fachlich und mengenbezogen bewerten.'
                    FROM @PlanXml.nodes('//*[local-name(.)="RelOp"][@PhysicalOp="Table Scan"]') AS [X]([r]);

                    INSERT [#MissingIndexes]([CandidateId],[Impact],[DatabaseName],[SchemaName],[TableName],[ColumnGroupUsage],[ColumnName],[ColumnId])
                    SELECT @CandidateId,TRY_CONVERT(decimal(19,4),NULLIF(g.value('string((@Impact)[1])','nvarchar(100)'),N'')),mi.value('string((@Database)[1])','nvarchar(256)'),mi.value('string((@Schema)[1])','nvarchar(256)'),mi.value('string((@Table)[1])','nvarchar(256)'),
                           cg.value('string((@Usage)[1])','nvarchar(60)'),c.value('string((@Name)[1])','nvarchar(256)'),TRY_CONVERT([int],NULLIF(c.value('string((@ColumnId)[1])','nvarchar(50)'),N''))
                    FROM @PlanXml.nodes('//*[local-name(.)="MissingIndexGroup"]') AS [G]([g])
                    CROSS APPLY g.nodes('./*[local-name(.)="MissingIndex"]') AS [MI]([mi])
                    CROSS APPLY mi.nodes('./*[local-name(.)="ColumnGroup"]') AS [CG]([cg])
                    CROSS APPLY cg.nodes('./*[local-name(.)="Column"]') AS [C]([c]);

                    INSERT [#Objects]
                    SELECT DISTINCT @CandidateId,o.value('string((@Database)[1])','nvarchar(256)'),o.value('string((@Schema)[1])','nvarchar(256)'),o.value('string((@Table)[1])','nvarchar(256)'),o.value('string((@Index)[1])','nvarchar(256)'),o.value('string((@Alias)[1])','nvarchar(256)'),o.value('string((@Storage)[1])','nvarchar(128)')
                    FROM @PlanXml.nodes('//*[local-name(.)="Object"]') AS [X]([o]);

                    INSERT [#Statistics]
                    SELECT DISTINCT @CandidateId,s.value('string((@Database)[1])','nvarchar(256)'),s.value('string((@Schema)[1])','nvarchar(256)'),s.value('string((@Table)[1])','nvarchar(256)'),s.value('string((@Statistics)[1])','nvarchar(256)'),
                           TRY_CONVERT([datetime],NULLIF(s.value('string((@LastUpdate)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(s.value('string((@ModificationCount)[1])','nvarchar(100)'),N'')),TRY_CONVERT(decimal(19,4),NULLIF(s.value('string((@SamplingPercent)[1])','nvarchar(100)'),N''))
                    FROM @PlanXml.nodes('//*[local-name(.)="OptimizerStatsUsage"]/*[local-name(.)="StatisticsInfo"]') AS [X]([s]);

                    INSERT [#Memory]
                    SELECT @CandidateId,TRY_CONVERT([bigint],NULLIF(m.value('string((@SerialRequiredMemory)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(m.value('string((@SerialDesiredMemory)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT([bigint],NULLIF(m.value('string((@RequiredMemory)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(m.value('string((@DesiredMemory)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT([bigint],NULLIF(m.value('string((@RequestedMemory)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(m.value('string((@GrantWaitTime)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT([bigint],NULLIF(m.value('string((@GrantedMemory)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(m.value('string((@MaxUsedMemory)[1])','nvarchar(100)'),N'')),
                           TRY_CONVERT([bigint],NULLIF(m.value('string((@MaxQueryMemory)[1])','nvarchar(100)'),N'')),TRY_CONVERT([bigint],NULLIF(m.value('string((@LastRequestedMemory)[1])','nvarchar(100)'),N'')),m.value('string((@IsMemoryGrantFeedbackAdjusted)[1])','nvarchar(128)')
                    FROM @PlanXml.nodes('//*[local-name(.)="MemoryGrantInfo"]') AS [X]([m]);

                    INSERT [#Parameters]
                    SELECT @CandidateId,p.value('string((@Column)[1])','nvarchar(256)'),p.value('string((@ParameterDataType)[1])','nvarchar(256)'),
                           p.value('string((@ParameterCompiledValue)[1])','nvarchar(4000)'),p.value('string((@ParameterRuntimeValue)[1])','nvarchar(4000)')
                    FROM @PlanXml.nodes('//*[local-name(.)="ParameterList"]/*[local-name(.)="ColumnReference"]') AS [X]([p]);

                    INSERT [#Findings]
                    SELECT @CandidateId,'CARDINALITY_MISESTIMATE',CASE WHEN [ActualToEstimatedRatio]>=100 OR [ActualToEstimatedRatio]<=0.01 THEN 'HIGH' ELSE 'MEDIUM' END,[NodeId],[PhysicalOp],[LogicalOp],
                           CONCAT(N'Actual/Estimated=',CONVERT(nvarchar(100),[ActualToEstimatedRatio]),N'; Estimated=',CONVERT(nvarchar(100),[EstimateRows]),N'; Actual=',CONVERT(nvarchar(100),[ActualRows]))
                    FROM [#Cardinality] WHERE [CandidateId]=@CandidateId AND [ActualToEstimatedRatio] IS NOT NULL AND ([ActualToEstimatedRatio]>=10 OR [ActualToEstimatedRatio]<=0.1);
                    INSERT [#Findings]
                    SELECT @CandidateId,'MEMORY_GRANT_OVER','MEDIUM',NULL,NULL,NULL,CONCAT(N'GrantedKB=',[GrantedMemoryKb],N'; MaxUsedKB=',[MaxUsedMemoryKb])
                    FROM [#Memory] WHERE [CandidateId]=@CandidateId AND [GrantedMemoryKb]>=10240 AND [GrantedMemoryKb]>4*NULLIF([MaxUsedMemoryKb],0);
                    INSERT [#Findings]
                    SELECT @CandidateId,'MEMORY_GRANT_PRESSURE','HIGH',NULL,NULL,NULL,CONCAT(N'GrantedKB=',[GrantedMemoryKb],N'; MaxUsedKB=',[MaxUsedMemoryKb],N'; GrantWaitMs=',[GrantWaitTimeMs])
                    FROM [#Memory] WHERE [CandidateId]=@CandidateId AND (([MaxUsedMemoryKb] IS NOT NULL AND [GrantedMemoryKb] IS NOT NULL AND [MaxUsedMemoryKb]>=[GrantedMemoryKb]) OR COALESCE([GrantWaitTimeMs],0)>0);

                    SELECT @StatementCount=COUNT_BIG(*) FROM [#Statements] WHERE [CandidateId]=@CandidateId;
                    SELECT @FindingCount=COUNT_BIG(*) FROM [#Findings] WHERE [CandidateId]=@CandidateId;
                    INSERT [#PlanStatus] VALUES(@CandidateId,@CurrentPlanHandle,@PlanSource,'AVAILABLE',DATEDIFF_BIG([MILLISECOND],@Started,SYSUTCDATETIME()),@StatementCount,@FindingCount,NULL,NULL);
                    SET @ProcessedPlans+=1;
                END;
            END TRY
            BEGIN CATCH
                SET @PlanError=ERROR_NUMBER();SET @PlanErrorMessage=ERROR_MESSAGE();SET @IsPartial=1;SET @StatusCode='PARTIAL';
                INSERT [#PlanStatus] VALUES(@CandidateId,@CurrentPlanHandle,COALESCE(@PlanSource,@PlanQuelle),'ERROR_HANDLED',DATEDIFF_BIG([MILLISECOND],@Started,SYSUTCDATETIME()),0,0,@PlanError,@PlanErrorMessage);
            END CATCH;
            FETCH NEXT FROM PlanCursor INTO @CandidateId,@CurrentPlanHandle;
        END;
        CLOSE PlanCursor;DEALLOCATE PlanCursor;
    END;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE') BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ShowplanAnalysis: %s - %s', @StatusCode, COALESCE(@ErrorMessage,@Detail,N''));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;
    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN
        SELECT N'USP_ShowplanAnalysis' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@RowCount [CandidateCount],@ProcessedPlans [ProcessedPlanCount],@RequiredPermission [RequiredPermission],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage],@Detail [Detail];
        IF @ResultSetArtNormalisiert='RAW'
        BEGIN
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#PlanStatus] ORDER BY [CandidateId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Statements] ORDER BY [CandidateId],[StatementId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Findings] ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[CandidateId],[FindingType],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#MissingIndexes] ORDER BY [Impact] DESC,[CandidateId],[TableName],[ColumnGroupUsage],[ColumnId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Objects] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[IndexName];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Statistics] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[StatisticsName];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Operators] ORDER BY [CandidateId],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Cardinality] WHERE [ActualRows] IS NOT NULL OR [ActualRowsRead] IS NOT NULL ORDER BY ABS(LOG10(CASE WHEN [ActualToEstimatedRatio]>0 THEN [ActualToEstimatedRatio] ELSE 1 END)) DESC,[CandidateId],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Memory] ORDER BY [CandidateId];
            SELECT TOP (@EffectiveMaxZeilen) * FROM [#Parameters] ORDER BY [CandidateId],[ParameterName];
        END
        ELSE
        BEGIN
            SELECT TOP (@EffectiveMaxZeilen) N'Showplan Status' [Ergebnis],[CandidateId] [Kandidat],[PlanSource] [Planquelle],[StatusCode] [Status],CONCAT([ParseDurationMs],N' ms') [Parsezeit],[StatementCount] [Statements],[FindingCount] [Findings],[ErrorMessage] [Hinweis] FROM [#PlanStatus] ORDER BY [CandidateId];
            SELECT TOP (@EffectiveMaxZeilen) N'Showplan Statement' [Ergebnis],[CandidateId] [Kandidat],[StatementId] [Statement],[StatementType] [Typ],[StatementSubTreeCost] [Kosten],[OptimizationLevel] [Optimierung],[EarlyAbortReason] [Abbruchgrund],[CandidateId] [Kandidat SQL],[StatementText] [SQL-Text] FROM [#Statements] ORDER BY [CandidateId],[StatementId];
            SELECT TOP (@EffectiveMaxZeilen) N'Showplan Finding' [Ergebnis],[CandidateId] [Kandidat],[Severity] [Schweregrad],[FindingType] [Finding],[NodeId] [Node],[PhysicalOp] [physischer Operator],[LogicalOp] [logischer Operator],[Detail] [Details] FROM [#Findings] ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[CandidateId],[FindingType],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) N'Fehlender Index' [Ergebnis],[CandidateId] [Kandidat],CONCAT(CONVERT(varchar(40),CONVERT(decimal(19,2),[Impact])),N' %') [Impact],[DatabaseName] [Datenbank],[SchemaName] [Schema],[TableName] [Tabelle],[ColumnGroupUsage] [Spaltengruppe],[ColumnName] [Spalte] FROM [#MissingIndexes] ORDER BY [Impact] DESC,[CandidateId],[TableName],[ColumnId];
            SELECT TOP (@EffectiveMaxZeilen) N'Verwendetes Objekt' [Ergebnis],[CandidateId] [Kandidat],[DatabaseName] [Datenbank],[SchemaName] [Schema],[TableName] [Tabelle],[IndexName] [Index],[AliasName] [Alias],[Storage] [Storage] FROM [#Objects] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[IndexName];
            SELECT TOP (@EffectiveMaxZeilen) N'Verwendete Statistik' [Ergebnis],[CandidateId] [Kandidat],[DatabaseName] [Datenbank],[SchemaName] [Schema],[TableName] [Tabelle],[StatisticsName] [Statistik],[LastUpdate] [letzte Aktualisierung],[ModificationCount] [Änderungen],[SamplingPercent] [Sample %] FROM [#Statistics] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[StatisticsName];
            SELECT TOP (@EffectiveMaxZeilen) N'Showplan Operator' [Ergebnis],[CandidateId] [Kandidat],[NodeId] [Node],[PhysicalOp] [physischer Operator],[LogicalOp] [logischer Operator],[EstimateRows] [geschätzte Zeilen],[EstimatedRowsRead] [geschätzt gelesen],[EstimatedTotalSubtreeCost] [Teilbaumkosten],[Parallel] [parallel] FROM [#Operators] ORDER BY [CandidateId],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) N'Kardinalität' [Ergebnis],[CandidateId] [Kandidat],[NodeId] [Node],[PhysicalOp] [Operator],[EstimateRows] [geschätzt],[ActualRows] [tatsächlich],[ActualToEstimatedRatio] [Ist/Schätzung] FROM [#Cardinality] WHERE [ActualRows] IS NOT NULL OR [ActualRowsRead] IS NOT NULL ORDER BY ABS(LOG10(CASE WHEN [ActualToEstimatedRatio]>0 THEN [ActualToEstimatedRatio] ELSE 1 END)) DESC,[CandidateId],[NodeId];
            SELECT TOP (@EffectiveMaxZeilen) N'Memory Grant im Plan' [Ergebnis],[CandidateId] [Kandidat],CONCAT(CONVERT(varchar(40),CONVERT(decimal(19,2),[RequestedMemoryKb]/1024.0)),N' MB') [angefordert],CONCAT(CONVERT(varchar(40),CONVERT(decimal(19,2),[GrantedMemoryKb]/1024.0)),N' MB') [gewährt],CONCAT(CONVERT(varchar(40),CONVERT(decimal(19,2),[MaxUsedMemoryKb]/1024.0)),N' MB') [maximal verwendet],[IsMemoryGrantFeedbackAdjusted] [Feedback] FROM [#Memory] ORDER BY [CandidateId];
            SELECT TOP (@EffectiveMaxZeilen) N'Planparameter' [Ergebnis],[CandidateId] [Kandidat],[ParameterName] [Parameter],[ParameterDataType] [Datentyp],[CompiledValue] [kompiliert],[RuntimeValue] [Laufzeit] FROM [#Parameters] ORDER BY [CandidateId],[ParameterName];
        END;
    END;
    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ShowplanAnalysis' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@RowCount [candidateCount],@ProcessedPlans [processedPlanCount],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @PlanStatusJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#PlanStatus] ORDER BY [CandidateId] FOR JSON PATH,INCLUDE_NULL_VALUES),@StatementsJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Statements] ORDER BY [CandidateId],[StatementId] FOR JSON PATH,INCLUDE_NULL_VALUES),@FindingsJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Findings] ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[CandidateId],[FindingType],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES),@MissingJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#MissingIndexes] ORDER BY [Impact] DESC,[CandidateId],[TableName],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES),@ObjectsJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Objects] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[IndexName] FOR JSON PATH,INCLUDE_NULL_VALUES),@StatisticsJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Statistics] ORDER BY [CandidateId],[DatabaseName],[SchemaName],[TableName],[StatisticsName] FOR JSON PATH,INCLUDE_NULL_VALUES),@OperatorsJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Operators] ORDER BY [CandidateId],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES),@CardinalityJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Cardinality] WHERE [ActualRows] IS NOT NULL OR [ActualRowsRead] IS NOT NULL ORDER BY [CandidateId],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES),@MemoryJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Memory] ORDER BY [CandidateId] FOR JSON PATH,INCLUDE_NULL_VALUES),@ParametersJson nvarchar(max)=(SELECT TOP(@EffectiveMaxZeilen) * FROM [#Parameters] ORDER BY [CandidateId],[ParameterName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"planStatus":',COALESCE(@PlanStatusJson,N'[]'),N',"statements":',COALESCE(@StatementsJson,N'[]'),N',"findings":',COALESCE(@FindingsJson,N'[]'),N',"missingIndexes":',COALESCE(@MissingJson,N'[]'),N',"objects":',COALESCE(@ObjectsJson,N'[]'),N',"statistics":',COALESCE(@StatisticsJson,N'[]'),N',"operators":',COALESCE(@OperatorsJson,N'[]'),N',"cardinality":',COALESCE(@CardinalityJson,N'[]'),N',"memory":',COALESCE(@MemoryJson,N'[]'),N',"parameters":',COALESCE(@ParametersJson,N'[]'),N',"warnings":[]}');
    END;
END;
GO
