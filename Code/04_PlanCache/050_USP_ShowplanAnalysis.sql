USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ShowplanAnalysis
Version      : 2.0.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Selektiert begrenzt Plan-Cache-Kandidaten und verwendet je
               eindeutigem Planhandle die zentrale Execution-Plan-Analyse.
               Mehrere dm_exec_query_stats-Statements desselben Batchplans
               führen nicht mehr zu wiederholtem XML-Shredding.
SQL-Version  : SQL Server 2019 oder neuer.
Resultsets   : CONSOLE/TABLE: findings. RAW: moduleStatus, planStatus, findings.
Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+
               VIEW SERVER PERFORMANCE STATE für Plan-Cache-Quellen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ShowplanAnalysis]
      @PlanHandle                    varbinary(64)   = NULL
    , @QueryHash                     binary(8)       = NULL
    , @QueryPlanHash                 binary(8)       = NULL
    , @DatabaseNames                 nvarchar(max)   = NULL
    , @SystemdatenbankenEinbeziehen  bit             = 0
    , @DatabaseNamePattern           nvarchar(4000)  = NULL
    , @HighImpactConfirmed           bit             = 0
    , @TextPattern                   nvarchar(4000)  = NULL
    , @AnalyseModus                  varchar(16)      = 'GEZIELT'
    , @PlanQuelle                    varchar(16)      = 'AUTO'
    , @Sortierung                    varchar(32)      = 'CPU_TOTAL'
    , @MinExecutionCount             bigint          = 1
    , @MaxAnalyseobjekte             int             = 20
    , @MaxDurationSeconds            int             = 30
    , @MaxZeilen                     int             = 50000
    , @ParentQueryStatsSnapshot      bit             = 0
    , @WorkloadProfil                varchar(32)      = 'AUTO'
    , @MinSchweregrad                varchar(16)      = 'INFO'
    , @MitThreadRuntime              bit             = 0
    , @MitSqlText                    bit             = 0
    , @StatistikEvidenzModus         varchar(16)      = 'PLAN_ONLY'
    , @HistogrammModus               varchar(16)      = 'NONE'
    , @MetadatenQuellenmodus         varchar(16)      = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt       bit             = 0
    , @EvidenzDatenschutzModus       varchar(24)      = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus    varchar(16)      = 'RAW'
    , @SensitiveDataConfirmed        bit             = 0
    , @MaxStatistiken                int             = 100
    , @MaxHistogrammSchritte         int             = 20000
    , @ResultSetArt                  varchar(16)      = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 0
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @Deadline datetime2(3)=DATEADD(SECOND,@MaxDurationSeconds,@Now);
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
    DECLARE @Source varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@PlanQuelle,'AUTO'))));
    DECLARE @Order varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@Sortierung,'CPU_TOTAL'))));
    DECLARE @Limit bigint=CASE WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxAnalyseobjekte END;
    DECLARE @ResultLimit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    DECLARE @ProcessedPlans int=0,@CandidateCount int=0;
    DECLARE @CrossDatabaseRequested bit=0;
    DECLARE @ChildAnalyseTiefe varchar(16)=CASE WHEN @Mode='VOLL' THEN 'FULL' ELSE 'STANDARD' END;
    DECLARE @ChildMaxRows int=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 50000 WHEN @MaxZeilen>2147483647 THEN 2147483647 ELSE @MaxZeilen END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ShowplanAnalysis';
        PRINT N'Selektiert eindeutige Planhandles und verwendet monitor.USP_ExecutionPlanAnalysis als zentrale Analyse-Engine.';
        PRINT N'@AnalyseModus GEZIELT|VOLL. GEZIELT benötigt mindestens einen Plan-, Hash-, Datenbank- oder Textselektor.';
        PRINT N'@PlanQuelle AUTO|COMPILE|LAST_ACTUAL; @Sortierung CPU_TOTAL|ELAPSED_TOTAL|READS_TOTAL|EXECUTIONS|SPILLS_TOTAL|GRANT_MAX|LAST_EXECUTION.';
        PRINT N'@MaxAnalyseobjekte und @MaxZeilen: positive Grenze; NULL/0 unbegrenzt. Breite Pfade benötigen High-Impact-Bestätigung.';
        PRINT N'Die Datenschutz-, Statistik- und Histogrammparameter entsprechen USP_ExecutionPlanAnalysis.';
        RETURN;
    END;

    CREATE TABLE [#ShowplanAnalysis_TableMap]([ResultName] sysname NOT NULL,[TargetTable] sysname NOT NULL);
    CREATE TABLE [#ShowplanAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname NOT NULL
        , [StateDesc] nvarchar(60) NULL,[UserAccessDesc] nvarchar(60) NULL,[IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL,[CollationName] sysname NULL,[RecoveryModelDesc] nvarchar(60) NULL
        , [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#ShowplanAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname NULL,[StatusCode] varchar(40) NOT NULL,[ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Candidates]
    (
          [CandidateId] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [PlanHandle] varbinary(64) NOT NULL UNIQUE
        , [ExecutionCount] bigint NULL,[TotalWorkerTime] bigint NULL,[TotalElapsedTime] bigint NULL
        , [TotalLogicalReads] bigint NULL,[TotalSpills] bigint NULL,[MaxGrantKb] bigint NULL
        , [LastExecutionTime] datetime NULL
    );
    CREATE TABLE [#ShowplanAnalysis_PlanStatus]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL,[PlanSource] varchar(24) NULL,[RuntimeCounterScope] varchar(32) NULL
        , [FindingCount] int NOT NULL,[ParseDurationMs] bigint NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Findings]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[FindingOrdinal] bigint NOT NULL
        , [FindingCode] varchar(100) NOT NULL,[Category] varchar(40) NOT NULL,[Severity] varchar(16) NOT NULL
        , [Confidence] varchar(32) NOT NULL,[EvidenceLevel] varchar(40) NOT NULL
        , [StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL
        , [PhysicalOp] nvarchar(128) NULL,[LogicalOp] nvarchar(128) NULL
        , [MetricName] varchar(80) NULL,[MetricValue] decimal(38,4) NULL,[MetricUnit] nvarchar(40) NULL
        , [ThresholdValue] decimal(38,4) NULL,[ThresholdSource] varchar(80) NULL,[WorkloadProfile] varchar(32) NOT NULL
        , [Summary] nvarchar(1000) NOT NULL,[Evidence] nvarchar(2000) NOT NULL,[EvidenceLimit] nvarchar(2000) NOT NULL
        , [CounterEvidence] nvarchar(1000) NULL,[RecommendedNextCheck] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Analyses]
    (
          [CandidateId] int NOT NULL PRIMARY KEY
        , [AnalysisJson] nvarchar(max) NULL
    );
    CREATE TABLE [#ShowplanAnalysis_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL,[CollectionTimeUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL,[CandidateCount] int NOT NULL,[ProcessedPlanCount] int NOT NULL
        , [FindingCount] bigint NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @Mode NOT IN ('GEZIELT','VOLL') OR @Source NOT IN ('AUTO','COMPILE','LAST_ACTUAL')
       OR @Order NOT IN ('CPU_TOTAL','ELAPSED_TOTAL','READS_TOTAL','EXECUTIONS','SPILLS_TOTAL','GRANT_MAX','LAST_EXECUTION')
       OR @MaxAnalyseobjekte<0 OR @MaxZeilen<0 OR @MinExecutionCount<0
       OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600 OR @ParentQueryStatsSnapshot NOT IN (0,1)
       OR @JsonErzeugen NOT IN (0,1)
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungültiger Modus-, Grenzwert-, Quell- oder Ausgabeparameter.';
    END;
    IF @StatusCode='AVAILABLE' AND @Mode='GEZIELT' AND @PlanHandle IS NULL AND @QueryHash IS NULL AND @QueryPlanHash IS NULL
       AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NULL
       AND @DatabaseNamePattern IS NULL AND @TextPattern IS NULL
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'GEZIELT benötigt mindestens einen Selektor.';
    END;

    IF @StatusCode='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'findings'
            , @MappingTable=N'#ShowplanAnalysis_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCode='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultTablesJson ist ausschließlich mit TABLE zulässig.';
    END;
    IF @ConsoleRequested=1 SET @OutputMode='NONE';

    DECLARE @TextMode varchar(8),@TextValue nvarchar(4000),@TextFlags varchar(8),@TextValid bit;
    SELECT @TextMode=[PatternMode],@TextValue=[PatternValue],@TextFlags=[RegexFlags],@TextValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@TextPattern);
    IF @StatusCode='AVAILABLE' AND @TextValid=0
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@TextPattern ist ungültig.';
    IF @StatusCode='AVAILABLE' AND @TextMode IN ('REGEX','REGEXI')
       AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17
            OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID() AND [compatibility_level]>=170))
        SELECT @StatusCode='UNAVAILABLE_FEATURE',@IsPartial=1,@ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';

    IF @StatusCode='AVAILABLE' AND @PlanHandle IS NULL
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @AnalysisClass='PLAN_CACHE_CURRENT'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
            , @CandidateTable=N'#ShowplanAnalysis_DatabaseCandidates'
            , @WarningTable=N'#ShowplanAnalysis_DatabaseCandidateWarnings';
    END;

    IF @StatusCode='AVAILABLE' AND (@Mode='VOLL' OR @Limit>20)
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass='PLAN_CACHE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;
        IF @StatusCode='AVAILABLE'
            EXEC [monitor].[InternalCheckAnalysisPath]
                  @AnalysisClass='SHOWPLAN_XML_DEEP',@HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        IF @PlanHandle IS NOT NULL
            INSERT [#ShowplanAnalysis_Candidates]([PlanHandle]) VALUES(@PlanHandle);
        ELSE
        BEGIN
            DECLARE @OrderExpression nvarchar(300)=CASE @Order
                WHEN 'CPU_TOTAL' THEN N'SUM([qs].[total_worker_time])'
                WHEN 'ELAPSED_TOTAL' THEN N'SUM([qs].[total_elapsed_time])'
                WHEN 'READS_TOTAL' THEN N'SUM([qs].[total_logical_reads])'
                WHEN 'EXECUTIONS' THEN N'SUM([qs].[execution_count])'
                WHEN 'SPILLS_TOTAL' THEN N'SUM([qs].[total_spills])'
                WHEN 'GRANT_MAX' THEN N'MAX([qs].[max_grant_kb])'
                WHEN 'LAST_EXECUTION' THEN N'DATEDIFF_BIG(MILLISECOND,''20000101'',MAX([qs].[last_execution_time]))' END;
            DECLARE @Sql nvarchar(max)=N'
INSERT [#ShowplanAnalysis_Candidates]
([PlanHandle],[ExecutionCount],[TotalWorkerTime],[TotalElapsedTime],[TotalLogicalReads],[TotalSpills],[MaxGrantKb],[LastExecutionTime])
SELECT TOP (@TopRows)
      [qs].[plan_handle],SUM([qs].[execution_count]),SUM([qs].[total_worker_time])
    , SUM([qs].[total_elapsed_time]),SUM([qs].[total_logical_reads]),SUM([qs].[total_spills])
    , MAX([qs].[max_grant_kb]),MAX([qs].[last_execution_time])
FROM '+CASE WHEN @ParentQueryStatsSnapshot=1 THEN N'[#PlanCacheAnalysis_QueryStatsSnapshot]' ELSE N'[sys].[dm_exec_query_stats]' END+N' AS [qs] WITH (NOLOCK)
OUTER APPLY (SELECT TOP (1) TRY_CONVERT(int,[value]) [dbid] FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) WHERE [attribute]=''dbid'') AS [pa] '
                +CASE WHEN @TextMode IS NOT NULL THEN N'OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st] ' ELSE N'' END+N'
WHERE [qs].[execution_count]>=@MinExec
  AND (@QH IS NULL OR [qs].[query_hash]=@QH)
  AND (@QPH IS NULL OR [qs].[query_plan_hash]=@QPH)
  AND EXISTS(SELECT 1 FROM [#ShowplanAnalysis_DatabaseCandidates] AS [dc] WHERE [dc].[DatabaseId]=[pa].[dbid]) '
                +CASE WHEN @TextMode='LIKE' THEN N'AND [st].[text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextValue COLLATE SQL_Latin1_General_CP1_CS_AS '
                      WHEN @TextMode IN ('REGEX','REGEXI') THEN N'AND REGEXP_LIKE([st].[text],@TextValue,@TextFlags) ' ELSE N'' END+N'
GROUP BY [qs].[plan_handle]
ORDER BY '+@OrderExpression+N' DESC,MAX([qs].[last_execution_time]) DESC
OPTION (RECOMPILE,MAXDOP 1);';
            EXEC [sys].[sp_executesql]
                  @Sql
                , N'@TopRows bigint,@MinExec bigint,@QH binary(8),@QPH binary(8),@TextValue nvarchar(4000),@TextFlags varchar(8)'
                , @TopRows=@Limit,@MinExec=@MinExecutionCount,@QH=@QueryHash,@QPH=@QueryPlanHash
                , @TextValue=@TextValue,@TextFlags=@TextFlags;
        END;
        SELECT @CandidateCount=COUNT(*) FROM [#ShowplanAnalysis_Candidates];
    END TRY
    BEGIN CATCH
        SELECT @StatusCode=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
    END CATCH;

    DECLARE @CandidateId int,@CurrentPlanHandle varbinary(64),@ChildJson nvarchar(max),@ChildStatus varchar(40),@ChildPartial bit,@ChildError int,@ChildMessage nvarchar(2048),@Started datetime2(3);
    DECLARE [PlanCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [CandidateId],[PlanHandle] FROM [#ShowplanAnalysis_Candidates] ORDER BY [CandidateId];
    IF @StatusCode='AVAILABLE'
    BEGIN
        OPEN [PlanCursor];
        FETCH NEXT FROM [PlanCursor] INTO @CandidateId,@CurrentPlanHandle;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline
            BEGIN
                SELECT @StatusCode='PARTIAL',@IsPartial=1,@ErrorMessage=N'Das Zeitbudget wurde erreicht; weitere Pläne wurden nicht analysiert.';
                BREAK;
            END;
            SELECT @Started=SYSUTCDATETIME(),@ChildJson=NULL,@ChildStatus=NULL,@ChildPartial=NULL,@ChildError=NULL,@ChildMessage=NULL;
            BEGIN TRY
                EXEC [monitor].[USP_ExecutionPlanAnalysis]
                      @PlanHandle=@CurrentPlanHandle
                    , @PlanQuelle=@Source
                    , @StatementQueryHash=@QueryHash
                    , @StatementQueryPlanHash=@QueryPlanHash
                    , @AnalyseTiefe=@ChildAnalyseTiefe
                    , @WorkloadProfil=@WorkloadProfil
                    , @MinSchweregrad=@MinSchweregrad
                    , @MitThreadRuntime=@MitThreadRuntime
                    , @MitSqlText=@MitSqlText
                    , @StatistikEvidenzModus=@StatistikEvidenzModus
                    , @HistogrammModus=@HistogrammModus
                    , @MetadatenQuellenmodus=@MetadatenQuellenmodus
                    , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
                    , @EvidenzDatenschutzModus=@EvidenzDatenschutzModus
                    , @IdentifierDatenschutzModus=@IdentifierDatenschutzModus
                    , @SensitiveDataConfirmed=@SensitiveDataConfirmed
                    , @MaxOperatoren=@ChildMaxRows
                    , @MaxFindings=@ChildMaxRows
                    , @MaxStatistiken=@MaxStatistiken
                    , @MaxHistogrammSchritte=@MaxHistogrammSchritte
                    , @MaxDurationSeconds=@MaxDurationSeconds
                    , @HighImpactConfirmed=@HighImpactConfirmed
                    , @ResultSetArt='NONE'
                    , @JsonErzeugen=1
                    , @Json=@ChildJson OUTPUT
                    , @PrintMeldungen=0
                    , @StatusCodeOut=@ChildStatus OUTPUT
                    , @IsPartialOut=@ChildPartial OUTPUT
                    , @ErrorNumberOut=@ChildError OUTPUT
                    , @ErrorMessageOut=@ChildMessage OUTPUT;

                DECLARE @ChildPlanSource varchar(24)=NULL,@ChildRuntimeScope varchar(32)=NULL,@ChildFindingCount int=0;
                IF ISJSON(@ChildJson)=1
                BEGIN
                    SELECT
                          @ChildPlanSource=JSON_VALUE(@ChildJson,N'$.meta.planSource')
                        , @ChildRuntimeScope=JSON_VALUE(@ChildJson,N'$.meta.runtimeCounterScope')
                        , @ChildFindingCount=(SELECT COUNT(*) FROM OPENJSON(@ChildJson,N'$.findings'));
                END;

                INSERT [#ShowplanAnalysis_PlanStatus]
                SELECT @CandidateId,@CurrentPlanHandle,COALESCE(@ChildStatus,'STATUS_UNAVAILABLE'),COALESCE(@ChildPartial,1),
                       @ChildPlanSource,@ChildRuntimeScope,@ChildFindingCount,
                       DATEDIFF_BIG(MILLISECOND,@Started,SYSUTCDATETIME()),@ChildError,@ChildMessage;
                INSERT [#ShowplanAnalysis_Analyses] VALUES(@CandidateId,CASE WHEN ISJSON(@ChildJson)=1 THEN @ChildJson END);

                IF ISJSON(@ChildJson)=1
                BEGIN
                    INSERT [#ShowplanAnalysis_Findings]
                    (
                          [CandidateId],[PlanHandle],[FindingOrdinal],[FindingCode],[Category],[Severity],[Confidence],[EvidenceLevel]
                        , [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
                        , [ThresholdValue],[ThresholdSource],[WorkloadProfile],[Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
                    )
                    SELECT @CandidateId,@CurrentPlanHandle,[FindingOrdinal],[FindingCode],[Category],[Severity],[Confidence],[EvidenceLevel]
                         , [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
                         , [ThresholdValue],[ThresholdSource],[WorkloadProfile],[Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
                    FROM OPENJSON(@ChildJson,N'$.findings')
                    WITH
                    (
                          [FindingOrdinal] bigint N'$.FindingOrdinal',[FindingCode] varchar(100) N'$.FindingCode'
                        , [Category] varchar(40) N'$.Category',[Severity] varchar(16) N'$.Severity'
                        , [Confidence] varchar(32) N'$.Confidence',[EvidenceLevel] varchar(40) N'$.EvidenceLevel'
                        , [StatementOrdinal] int N'$.StatementOrdinal',[StatementId] int N'$.StatementId',[NodeId] int N'$.NodeId'
                        , [PhysicalOp] nvarchar(128) N'$.PhysicalOp',[LogicalOp] nvarchar(128) N'$.LogicalOp'
                        , [MetricName] varchar(80) N'$.MetricName',[MetricValue] decimal(38,4) N'$.MetricValue'
                        , [MetricUnit] nvarchar(40) N'$.MetricUnit',[ThresholdValue] decimal(38,4) N'$.ThresholdValue'
                        , [ThresholdSource] varchar(80) N'$.ThresholdSource',[WorkloadProfile] varchar(32) N'$.WorkloadProfile'
                        , [Summary] nvarchar(1000) N'$.Summary',[Evidence] nvarchar(2000) N'$.Evidence'
                        , [EvidenceLimit] nvarchar(2000) N'$.EvidenceLimit',[CounterEvidence] nvarchar(1000) N'$.CounterEvidence'
                        , [RecommendedNextCheck] nvarchar(1000) N'$.RecommendedNextCheck'
                    );
                END;
                SET @ProcessedPlans+=1;
                IF COALESCE(@ChildStatus,'STATUS_UNAVAILABLE')<>'AVAILABLE'
                BEGIN
                    SET @IsPartial=1;
                    IF @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
                END;
            END TRY
            BEGIN CATCH
                INSERT [#ShowplanAnalysis_PlanStatus]
                VALUES(@CandidateId,@CurrentPlanHandle,'ERROR_HANDLED',1,NULL,NULL,0,DATEDIFF_BIG(MILLISECOND,@Started,SYSUTCDATETIME()),ERROR_NUMBER(),ERROR_MESSAGE());
                SET @IsPartial=1;
                IF @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
                IF @ErrorNumber IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER(); SET @ErrorMessage=ERROR_MESSAGE(); END;
            END CATCH;
            IF (SELECT COUNT_BIG(*) FROM [#ShowplanAnalysis_Findings])>=@ResultLimit
            BEGIN
                SELECT @StatusCode='PARTIAL',@IsPartial=1,@ErrorMessage=N'Das Findinglimit wurde erreicht; weitere Pläne wurden nicht analysiert.';
                BREAK;
            END;
            FETCH NEXT FROM [PlanCursor] INTO @CandidateId,@CurrentPlanHandle;
        END;
        CLOSE [PlanCursor];DEALLOCATE [PlanCursor];
    END;

    IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
    INSERT [#ShowplanAnalysis_ModuleStatus]
    SELECT N'USP_ShowplanAnalysis',@Now,@StatusCode,@IsPartial,@CandidateCount,@ProcessedPlans,
           (SELECT COUNT_BIG(*) FROM [#ShowplanAnalysis_Findings]),@ErrorNumber,@ErrorMessage;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @Meta nvarchar(max)=(SELECT N'ShowplanAnalysis' [resultName],2 [schemaVersion],@Now [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@CandidateCount [candidateCount],@ProcessedPlans [processedPlanCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @PlanStatusJson nvarchar(max)=(SELECT * FROM [#ShowplanAnalysis_PlanStatus] ORDER BY [CandidateId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FindingsJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[CandidateId],[FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @AnalysesJson nvarchar(max)=N'[]';
        SELECT @AnalysesJson=COALESCE(N'['+STRING_AGG(CONVERT(nvarchar(max),[AnalysisJson]),N',') WITHIN GROUP (ORDER BY [CandidateId])+N']',N'[]')
        FROM [#ShowplanAnalysis_Analyses] WHERE ISJSON([AnalysisJson])=1;
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"planStatus":',COALESCE(@PlanStatusJson,N'[]'),N',"findings":',COALESCE(@FindingsJson,N'[]'),N',"analyses":',COALESCE(@AnalysesJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#ShowplanAnalysis_ModuleStatus];
        SELECT * FROM [#ShowplanAnalysis_PlanStatus] ORDER BY [CandidateId];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[CandidateId],[FindingOrdinal];
    END;
    IF @ConsoleRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ShowplanAnalysis_Findings',@ResultLabel=N'Showplan Finding'
            , @EmptyMessage=N'Keine Showplan-Findings im gewählten Scope'
            , @StatusCode=@StatusCode,@StatusMessage=@ErrorMessage;
    IF @TableRequested=1
    BEGIN
        DECLARE @TargetTable sysname=(SELECT TOP (1) [TargetTable] FROM [#ShowplanAnalysis_TableMap] WHERE [ResultName]=N'findings');
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable=N'#ShowplanAnalysis_Findings',@TargetTable=@TargetTable,@ThrowOnError=1;
    END;
    IF @PrintMeldungen=1 AND @StatusCode<>'AVAILABLE'
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_ShowplanAnalysis: %s - %s',@StatusCode,COALESCE(@ErrorMessage,N'partielle Analyse'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO
