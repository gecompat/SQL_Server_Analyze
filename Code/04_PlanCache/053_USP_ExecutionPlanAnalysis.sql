USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ExecutionPlanAnalysis
Version      : 1.0.1
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Analysiert genau ein direkt übergebenes oder gezielt beschafftes
               Showplan-XML. Der direkte @PlanXml-Pfad ist eigenständig nutzbar.
Planquellen  : IMPORTED, COMPILE, LAST_ACTUAL, CURRENT_ACTUAL, QUERY_STORE.
Evidenz      : Optional bereits strukturiertes Evidence JSON oder bereits
               erfasste SET STATISTICS IO/TIME-Meldungen. Es wird kein fremdes
               SQL ausgeführt und keine Erfassungsoption aktiviert.
Datenschutz  : Parameter-/Histogrammwerte standardmäßig DERIVED_ONLY. SQL-Text
               wird nur mit @MitSqlText=1 ausgegeben.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml                        xml             = NULL
    , @PlanHandle                     varbinary(64)   = NULL
    , @SessionIds                     nvarchar(max)   = NULL
    , @RequestId                      int             = NULL
    , @QueryStoreDatabaseName         sysname         = NULL
    , @QueryStorePlanId               bigint          = NULL
    , @PlanQuelle                     varchar(24)      = 'AUTO'
    , @StatementId                    int             = NULL
    , @StatementQueryHash             binary(8)       = NULL
    , @StatementQueryPlanHash         binary(8)       = NULL
    , @EvidenzJson                    nvarchar(max)   = NULL
    , @StatisticsIoText               nvarchar(max)   = NULL
    , @StatisticsTimeText             nvarchar(max)   = NULL
    , @StatisticsLanguage             varchar(16)     = 'AUTO'
    , @StatistikEvidenzModus          varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus                varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus          varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt        bit             = 0
    , @MitPredicateHistogramMap       bit             = 1
    , @AnalyseTiefe                   varchar(16)      = 'STANDARD'
    , @WorkloadProfil                 varchar(32)      = 'AUTO'
    , @Regelsatz                      varchar(32)      = 'DEFAULT'
    , @MinSchweregrad                 varchar(16)      = 'INFO'
    , @MitThreadRuntime               bit             = 0
    , @MitSqlText                     bit             = 0
    , @EvidenzDatenschutzModus        varchar(24)      = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus     varchar(16)      = 'RAW'
    , @SensitiveDataConfirmed         bit             = 0
    , @MaxOperatoren                  int             = 50000
    , @MaxFindings                    int             = 5000
    , @MaxStatistiken                 int             = 100
    , @MaxHistogrammSchritte          int             = 20000
    , @MaxDurationSeconds             int             = 30
    , @LockTimeoutMs                  int             = 0
    , @HighImpactConfirmed            bit             = 0
    , @ResultSetArt                   varchar(16)      = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)   = NULL
    , @JsonErzeugen                   bit             = 0
    , @Json                           nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                 bit             = 1
    , @Hilfe                          bit             = 0
    , @StatusCodeOut                  varchar(40)     = NULL OUTPUT
    , @IsPartialOut                   bit             = NULL OUTPUT
    , @ErrorNumberOut                 int             = NULL OUTPUT
    , @ErrorMessageOut                nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @RequestedPlanSource varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@PlanQuelle,'AUTO'))));
    DECLARE @Depth varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseTiefe,'STANDARD'))));
    DECLARE @Profile varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@WorkloadProfil,'AUTO'))));
    DECLARE @RuleSet varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@Regelsatz,'DEFAULT'))));
    DECLARE @MinSeverity varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MinSchweregrad,'INFO'))));
    DECLARE @PrivacyMode varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))));
    DECLARE @IdentifierMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))));
    DECLARE @StatisticsMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'PLAN_ONLY'))));
    DECLARE @HistogramMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))));
    DECLARE @MetadataMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MetadatenQuellenmodus,'EVIDENCE_ONLY'))));
    DECLARE @EffectivePlanSource varchar(24)=NULL;
    DECLARE @RuntimeScope varchar(32)='NONE';
    DECLARE @EffectivePlanXml xml=NULL;
    DECLARE @EvidenceForAnalysis nvarchar(max)=@EvidenzJson;
    DECLARE @Deadline datetime2(3)=DATEADD(SECOND,@MaxDurationSeconds,@Now);
    DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);
    DECLARE @EffectiveSessionId smallint=NULL;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ExecutionPlanAnalysis';
        PRINT N'Genau eine Planquelle: @PlanXml, @PlanHandle, genau ein Wert in @SessionIds oder @QueryStoreDatabaseName+@QueryStorePlanId.';
        PRINT N'Der direkte @PlanXml-Pfad benötigt weder Plan Cache noch Query Store. Es wird niemals übergebenes SQL ausgeführt.';
        PRINT N'@PlanQuelle gilt für @PlanHandle: AUTO|COMPILE|LAST_ACTUAL. AUTO fällt kontrolliert auf COMPILE zurück.';
        PRINT N'Optional: @EvidenzJson oder bereits erfasste @StatisticsIoText/@StatisticsTimeText.';
        PRINT N'@StatistikEvidenzModus NONE|PLAN_ONLY|USED|RELEVANT|OBJECT_ALL; @HistogrammModus NONE|SUMMARY|STEPS.';
        PRINT N'@EvidenzDatenschutzModus DERIVED_ONLY|TOKENIZED|STRUCTURE_ONLY|RAW; RAW benötigt @SensitiveDataConfirmed=1.';
        PRINT N'@ResultSetArt CONSOLE|RAW|TABLE|NONE; CONSOLE liefert Findings, TABLE verwendet benannte Ziele.';
        RETURN;
    END;

    CREATE TABLE [#ExecutionPlanAnalysis_TableMap]
    (
          [ResultName] sysname NOT NULL
        , [TargetTable] sysname NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [PlanSource] varchar(24) NULL
        , [RuntimeCounterScope] varchar(32) NULL
        , [WorkloadProfile] varchar(32) NULL
        , [StatementCount] int NOT NULL
        , [OperatorCount] int NOT NULL
        , [FindingCount] int NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Capabilities]
    (
          [AnalysisObjectId] int NOT NULL
        , [FeatureCode] varchar(80) NOT NULL
        , [IsAvailable] bit NOT NULL
        , [AvailabilityReason] varchar(80) NOT NULL
        , [EvidenceSource] varchar(40) NOT NULL
        , [Detail] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_PlanDocuments]
    (
          [AnalysisObjectId] int NOT NULL
        , [PlanSource] varchar(24) NOT NULL
        , [RuntimeCounterScope] varchar(32) NOT NULL
        , [ShowplanVersion] nvarchar(64) NULL
        , [ShowplanBuild] nvarchar(64) NULL
        , [SourceProductVersion] nvarchar(128) NULL
        , [SourceCompatibilityLevel] smallint NULL
        , [CardinalityEstimationModelVersion] int NULL
        , [IsPlanComplete] bit NOT NULL
        , [PlanDocumentHash] varbinary(32) NULL
        , [StatementCount] int NOT NULL
        , [OperatorCount] int NOT NULL
        , [HasRuntimeCounters] bit NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Statements]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [StatementCompId] int NULL
        , [StatementType] nvarchar(128) NULL
        , [StatementText] nvarchar(max) NULL
        , [StatementQueryHash] nvarchar(130) NULL
        , [StatementQueryPlanHash] nvarchar(130) NULL
        , [StatementSubTreeCost] decimal(38,8) NULL
        , [StatementEstimatedRows] decimal(38,4) NULL
        , [OptimizationLevel] nvarchar(128) NULL
        , [EarlyAbortReason] nvarchar(256) NULL
        , [CardinalityEstimationModelVersion] int NULL
        , [CompileTimeMs] bigint NULL
        , [CompileCpuMs] bigint NULL
        , [CompileMemoryKb] bigint NULL
        , [RetrievedFromCache] bit NULL
        , [NonParallelPlanReason] nvarchar(256) NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Operators]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [ParentNodeId] int NULL
        , [ChildOrdinal] int NULL
        , [Depth] int NULL
        , [OperatorPath] nvarchar(1000) NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [EstimateRows] decimal(38,4) NULL
        , [EstimatedRowsRead] decimal(38,4) NULL
        , [EstimatedExecutions] decimal(38,4) NULL
        , [EstimateRebinds] decimal(38,4) NULL
        , [EstimateRewinds] decimal(38,4) NULL
        , [EstimatedCpu] decimal(38,8) NULL
        , [EstimatedIo] decimal(38,8) NULL
        , [AverageRowSize] decimal(38,4) NULL
        , [EstimatedTotalSubtreeCost] decimal(38,8) NULL
        , [Parallel] bit NULL
        , [EstimatedExecutionMode] nvarchar(60) NULL
        , [ActualExecutionMode] nvarchar(60) NULL
        , [Ordered] bit NULL
        , [ScanDirection] nvarchar(60) NULL
        , [ObjectDatabaseName] nvarchar(256) NULL
        , [ObjectSchemaName] nvarchar(256) NULL
        , [ObjectName] nvarchar(256) NULL
        , [IndexName] nvarchar(256) NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_OperatorThreadRuntime]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [ThreadId] int NULL
        , [BrickId] int NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [ActualRebinds] bigint NULL
        , [ActualRewinds] bigint NULL
        , [ActualEndOfScans] bigint NULL
        , [ActualScans] bigint NULL
        , [ActualLogicalReads] bigint NULL
        , [ActualPhysicalReads] bigint NULL
        , [ActualReadAheads] bigint NULL
        , [ActualCpuMs] bigint NULL
        , [ActualElapsedMs] bigint NULL
        , [ActualLobLogicalReads] bigint NULL
        , [ActualLobPhysicalReads] bigint NULL
        , [IsRowsReadPaired] bit NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_OperatorRuntime]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [RuntimeCounterCount] int NOT NULL
        , [RowsReadCounterCount] int NOT NULL
        , [RowsReadCounterCoveragePercent] decimal(9,4) NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [PairedActualRows] decimal(38,4) NULL
        , [PairedActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [ActualRebinds] bigint NULL
        , [ActualRewinds] bigint NULL
        , [ActualLogicalReads] bigint NULL
        , [ActualPhysicalReads] bigint NULL
        , [ActualReadAheads] bigint NULL
        , [ActualCpuMs] bigint NULL
        , [ActualElapsedMs] bigint NULL
        , [EstimatedRowsTotal] decimal(38,4) NULL
        , [ActualToEstimatedRatio] decimal(38,8) NULL
        , [CardinalityLog10Error] decimal(19,6) NULL
        , [RowsReadNotReturned] decimal(38,4) NULL
        , [RowsReadNotReturnedPercent] decimal(19,6) NULL
        , [RuntimeMetricStatus] varchar(40) NOT NULL
        , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_AccessPaths]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NOT NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [DatabaseName] nvarchar(256) NULL
        , [SchemaName] nvarchar(256) NULL
        , [ObjectName] nvarchar(256) NULL
        , [IndexName] nvarchar(256) NULL
        , [StorageType] nvarchar(128) NULL
        , [IsLookup] bit NOT NULL
        , [Ordered] bit NULL
        , [ScanDirection] nvarchar(60) NULL
        , [EstimateRows] decimal(38,4) NULL
        , [EstimatedRowsRead] decimal(38,4) NULL
        , [ActualRows] decimal(38,4) NULL
        , [ActualRowsRead] decimal(38,4) NULL
        , [ActualExecutions] bigint NULL
        , [RowsReadNotReturned] decimal(38,4) NULL
        , [RowsReadNotReturnedPercent] decimal(19,6) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_StatisticsUsage]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatisticsUsageOrdinal] bigint NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [StatementCompId] int NULL
        , [DatabaseName] sysname NULL
        , [SchemaName] sysname NULL
        , [ObjectName] sysname NULL
        , [StatisticsName] sysname NULL
        , [LastUpdateAtCompile] datetime2(7) NULL
        , [ModificationCountAtCompile] bigint NULL
        , [SamplingPercentAtCompile] decimal(19,6) NULL
        , [CurrentLastUpdated] datetime2(7) NULL
        , [CurrentRows] bigint NULL
        , [CurrentRowsSampled] bigint NULL
        , [CurrentModificationCounter] bigint NULL
        , [CurrentSamplePercent] decimal(19,6) NULL
        , [StatisticsChangedSinceCompile] bit NULL
        , [MetadataMatchStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Parameters]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [ParameterName] nvarchar(256) NULL
        , [ParameterDataType] nvarchar(256) NULL
        , [CompiledValue] nvarchar(4000) NULL
        , [RuntimeValue] nvarchar(4000) NULL
        , [CompiledValueToken] varbinary(32) NULL
        , [RuntimeValueToken] varbinary(32) NULL
        , [CompiledValueLength] int NULL
        , [RuntimeValueLength] int NULL
        , [ValueHandlingStatus] varchar(40) NOT NULL
        , [ValueSource] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_MemoryAndSpills]
    (
          [AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NOT NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [RecordType] varchar(24) NOT NULL
        , [SpillKind] nvarchar(128) NULL
        , [SpillLevel] int NULL
        , [SpilledDataSize] bigint NULL
        , [WritesToTempDb] bigint NULL
        , [ReadsFromTempDb] bigint NULL
        , [RequestedMemoryKb] bigint NULL
        , [GrantedMemoryKb] bigint NULL
        , [MaxUsedMemoryKb] bigint NULL
        , [GrantWaitTimeMs] bigint NULL
        , [MemoryGrantFeedbackState] nvarchar(128) NULL
        , [Detail] nvarchar(1000) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_ExecutionEvidence]
    (
          [AnalysisObjectId] int NOT NULL
        , [EvidenceType] varchar(40) NOT NULL
        , [StatementOrdinal] int NULL
        , [ScopeName] nvarchar(512) NULL
        , [MetricName] varchar(80) NOT NULL
        , [MetricValue] decimal(38,4) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [EvidenceStatus] varchar(40) NOT NULL
        , [SameExecutionConfidence] varchar(40) NOT NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_Findings]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL
        , [AnalysisObjectId] int NOT NULL
        , [FindingCode] varchar(100) NOT NULL
        , [Category] varchar(40) NOT NULL
        , [Severity] varchar(16) NOT NULL
        , [Confidence] varchar(32) NOT NULL
        , [EvidenceLevel] varchar(40) NOT NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [NodeId] int NULL
        , [PhysicalOp] nvarchar(128) NULL
        , [LogicalOp] nvarchar(128) NULL
        , [MetricName] varchar(80) NULL
        , [MetricValue] decimal(38,4) NULL
        , [MetricUnit] nvarchar(40) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [ThresholdSource] varchar(80) NULL
        , [WorkloadProfile] varchar(32) NOT NULL
        , [Summary] nvarchar(1000) NOT NULL
        , [Evidence] nvarchar(2000) NOT NULL
        , [EvidenceLimit] nvarchar(2000) NOT NULL
        , [CounterEvidence] nvarchar(1000) NULL
        , [RecommendedNextCheck] nvarchar(1000) NOT NULL
        , PRIMARY KEY ([FindingOrdinal])
    );
    CREATE TABLE [#ExecutionPlanAnalysis_HistogramSummaries]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NULL,[LeadingColumnName] sysname NULL
        , [HistogramSteps] int NULL,[HistogramEstimatedRows] float NULL,[MaxEqualRows] float NULL
        , [MaxRangeRows] float NULL,[MaxStepRows] float NULL,[DominantStepPercent] decimal(19,6) NULL
        , [TailStepRows] float NULL,[TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_HistogramSteps]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NULL,[LeadingColumnName] sysname NULL
        , [StepOrdinal] int NULL,[RangeHighKey] nvarchar(4000) NULL,[RangeHighKeyToken] varbinary(32) NULL
        , [RangeRows] float NULL,[EqualRows] float NULL,[DistinctRangeRows] bigint NULL,[AverageRangeRows] float NULL
        , [IsPredicateTarget] bit NULL,[PredicateMatchCount] int NULL,[SensitiveValueStatus] varchar(40) NULL
    );
    CREATE TABLE [#ExecutionPlanAnalysis_PredicateHistogramMappings]
    (
          [PredicateReferenceId] bigint NULL,[StatementOrdinal] int NULL,[NodeId] int NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ColumnName] sysname NULL
        , [StatisticsName] sysname NULL,[PredicateKind] varchar(40) NULL,[ValueSource] varchar(32) NULL
        , [MappingStatus] varchar(48) NULL,[MappingConfidence] varchar(16) NULL,[MatchedStepOrdinal] int NULL
        , [MatchesRangeHighKey] bit NULL,[IsBelowHistogram] bit NULL,[IsAboveHistogram] bit NULL
        , [SensitiveValueStatus] varchar(40) NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @RequestedPlanSource NOT IN ('AUTO','COMPILE','LAST_ACTUAL')
       OR @Depth NOT IN ('SUMMARY','STANDARD','FULL')
       OR @RuleSet<>'DEFAULT'
       OR @MinSeverity NOT IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL')
       OR @MitThreadRuntime NOT IN (0,1) OR @MitSqlText NOT IN (0,1)
       OR @PrivacyMode NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierMode NOT IN ('RAW','TOKENIZED','OMIT')
       OR @StatisticsMode NOT IN ('NONE','PLAN_ONLY','USED','RELEVANT','OBJECT_ALL')
       OR @HistogramMode NOT IN ('NONE','SUMMARY','STEPS')
       OR @MetadataMode NOT IN ('EVIDENCE_ONLY','CURRENT_SERVER')
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxOperatoren IS NULL OR @MaxOperatoren<1
       OR @MaxFindings IS NULL OR @MaxFindings<1
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @JsonErzeugen NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Modus-, Grenzwert-, Planquellen-, Ausgabe- oder Datenschutzparameter.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND NULLIF(LTRIM(RTRIM(COALESCE(@SessionIds,N''))),N'') IS NOT NULL
    BEGIN
        IF EXISTS
           (
               SELECT 1
               FROM [monitor].[TVF_ParseBigintList](@SessionIds)
               WHERE [IsValid]<>1
                  OR [NumberValue] NOT BETWEEN 1 AND 32767
           )
           OR 1<>(SELECT COUNT(*) FROM [monitor].[TVF_ParseBigintList](@SessionIds))
        BEGIN
            SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
                   @ErrorMessageOut=N'@SessionIds muss für diese Ein-Plan-Analyse genau eine gültige smallint-Session-ID enthalten.';
        END
        ELSE
        BEGIN
            SELECT @EffectiveSessionId=CONVERT(smallint,[NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds);
        END;
    END;

    DECLARE @PlanSourceGroupCount int=
          CASE WHEN @PlanXml IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @PlanHandle IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @EffectiveSessionId IS NOT NULL THEN 1 ELSE 0 END
        + CASE WHEN @QueryStoreDatabaseName IS NOT NULL OR @QueryStorePlanId IS NOT NULL THEN 1 ELSE 0 END;

    IF @StatusCodeOut='AVAILABLE' AND @PlanSourceGroupCount<>1
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Genau eine Planquelle muss angegeben werden.';
    END;
    IF @StatusCodeOut='AVAILABLE'
       AND ((@QueryStoreDatabaseName IS NULL AND @QueryStorePlanId IS NOT NULL)
         OR (@QueryStoreDatabaseName IS NOT NULL AND @QueryStorePlanId IS NULL))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Query Store benötigt @QueryStoreDatabaseName und @QueryStorePlanId gemeinsam.';
    END;
    IF @StatusCodeOut='AVAILABLE' AND @PrivacyMode='RAW' AND @SensitiveDataConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'RAW-Parameter- oder Histogrammwerte benötigen @SensitiveDataConfirmed=1.';
    END;
    IF @StatusCodeOut='AVAILABLE' AND @MetadataMode='CURRENT_SERVER' AND @QuellumgebungBestaetigt<>1
    BEGIN
        SELECT @StatusCodeOut='SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'CURRENT_SERVER-Anreicherung benötigt @QuellumgebungBestaetigt=1.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|capabilities|planDocuments|statements|operatorTree|operatorRuntime|operatorThreadRuntime|accessPaths|statisticsUsage|parametersAndVariants|memoryAndSpills|executionEvidence|histogramSummaries|histogramSteps|predicateHistogramMappings|findings'
            , @MappingTable=N'#ExecutionPlanAnalysis_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCodeOut='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.';
    END;
    IF @ConsoleRequested=1 SET @OutputMode='NONE';

    /* Planbeschaffung. Direkt übergebenes XML bleibt vollständig standalone. */
    IF @StatusCodeOut='AVAILABLE'
    BEGIN TRY
        IF @PlanXml IS NOT NULL
        BEGIN
            SET @EffectivePlanXml=@PlanXml;
            SET @EffectivePlanSource='IMPORTED';
            SET @RuntimeScope=CASE WHEN @PlanXml.exist('//*[local-name(.)="RunTimeCountersPerThread"]')=1
                                   THEN 'IMPORTED_ACTUAL' ELSE 'NONE' END;
        END
        ELSE IF @PlanHandle IS NOT NULL
        BEGIN
            IF @RequestedPlanSource IN ('AUTO','LAST_ACTUAL')
            BEGIN
                SELECT @EffectivePlanXml=[query_plan]
                FROM [sys].[dm_exec_query_plan_stats](@PlanHandle);
                IF @EffectivePlanXml IS NOT NULL
                BEGIN
                    SET @EffectivePlanSource='LAST_ACTUAL';
                    SET @RuntimeScope='LAST_COMPLETED_EXECUTION';
                END;
            END;
            IF @EffectivePlanXml IS NULL AND @RequestedPlanSource IN ('AUTO','COMPILE')
            BEGIN
                SELECT @EffectivePlanXml=[query_plan]
                FROM [sys].[dm_exec_query_plan](@PlanHandle);
                IF @EffectivePlanXml IS NOT NULL
                BEGIN
                    SET @EffectivePlanSource='COMPILE';
                    SET @RuntimeScope='NONE';
                END;
            END;
        END
        ELSE IF @EffectiveSessionId IS NOT NULL
        BEGIN
            DECLARE @RequestCount int;
            SELECT @RequestCount=COUNT(*)
            FROM [sys].[dm_exec_query_statistics_xml](@EffectiveSessionId)
            WHERE @RequestId IS NULL OR [request_id]=@RequestId;
            IF @RequestCount>1 AND @RequestId IS NULL
                THROW 51031,N'Die Sitzung besitzt mehrere aktive Requests; @RequestId ist erforderlich.',1;
            SELECT TOP (1) @EffectivePlanXml=[query_plan]
            FROM [sys].[dm_exec_query_statistics_xml](@EffectiveSessionId)
            WHERE @RequestId IS NULL OR [request_id]=@RequestId
            ORDER BY [request_id];
            IF @EffectivePlanXml IS NOT NULL
            BEGIN
                SET @EffectivePlanSource='CURRENT_ACTUAL';
                SET @RuntimeScope='CURRENT_PARTIAL_EXECUTION';
            END;
        END
        ELSE
        BEGIN
            DECLARE @QueryStoreSql nvarchar(max)=N'USE '+QUOTENAME(@QueryStoreDatabaseName)+N';
SELECT @PlanXmlOut=CONVERT(xml,[p].[query_plan])
FROM [sys].[query_store_plan] AS [p] WITH (NOLOCK)
WHERE [p].[plan_id]=@PlanId;';
            EXEC [sys].[sp_executesql]
                  @QueryStoreSql
                , N'@PlanId bigint,@PlanXmlOut xml OUTPUT'
                , @PlanId=@QueryStorePlanId
                , @PlanXmlOut=@EffectivePlanXml OUTPUT;
            IF @EffectivePlanXml IS NOT NULL
            BEGIN
                SET @EffectivePlanSource='QUERY_STORE';
                SET @RuntimeScope='NONE';
            END;
        END;

        IF @EffectivePlanXml IS NULL
        BEGIN
            SELECT @StatusCodeOut='UNAVAILABLE_OBJECT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Die angeforderte Planquelle lieferte kein Showplan-XML.';
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    IF @StatusCodeOut='AVAILABLE'
       AND (@Depth='FULL' OR @StatisticsMode IN ('RELEVANT','OBJECT_ALL') OR @HistogramMode='STEPS')
    BEGIN
        IF @HighImpactConfirmed<>1
        BEGIN
            SELECT @StatusCodeOut='HIGH_IMPACT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
                   @ErrorMessageOut=N'Der angeforderte FULL-/breite Statistik-/Histogrammpfad benötigt @HighImpactConfirmed=1.';
        END;
        ELSE IF EXISTS
        (
            SELECT 1 FROM [sys].[procedures] AS [p] WITH (NOLOCK)
            JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
            WHERE [s].[name]=N'monitor' AND [p].[name]=N'InternalCheckAnalysisPath'
        )
        BEGIN
            DECLARE @GateStatus varchar(40),@GateMessage nvarchar(2048);
            EXEC [sys].[sp_executesql]
                  N'EXEC [monitor].[InternalCheckAnalysisPath]
                          @AnalysisClass=''SHOWPLAN_XML_DEEP'',
                          @HighImpactConfirmed=@Confirmed,
                          @StatusCode=@Status OUTPUT,
                          @ErrorMessage=@Message OUTPUT;'
                , N'@Confirmed bit,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT'
                , @Confirmed=@HighImpactConfirmed,@Status=@GateStatus OUTPUT,@Message=@GateMessage OUTPUT;
            IF @GateStatus<>'AVAILABLE'
                SELECT @StatusCodeOut=@GateStatus,@IsPartialOut=1,@ErrorMessageOut=@GateMessage;
        END;
    END;

    /* AUTO-Profil: explizite lokale Zuordnung, sonst BALANCED. */
    IF @StatusCodeOut='AVAILABLE'
    BEGIN
        IF @Profile='AUTO'
        BEGIN
            SELECT TOP (1) @Profile=[a].[ProfileCode]
            FROM [monitor].[PlanAnalysisProfileAssignment] AS [a] WITH (NOLOCK)
            JOIN [monitor].[PlanAnalysisProfile] AS [p] WITH (NOLOCK)
              ON [p].[ProfileCode]=[a].[ProfileCode] AND [p].[IsEnabled]=1
            WHERE [a].[IsEnabled]=1
              AND (@StatementId IS NULL OR [a].[StatementId] IS NULL OR [a].[StatementId]=@StatementId)
              AND (@StatementQueryHash IS NULL OR [a].[QueryHash] IS NULL OR [a].[QueryHash]=@StatementQueryHash)
              AND ([a].[QueryStoreQueryId] IS NULL)
              AND ([a].[DatabaseNamePattern] IS NULL OR @QueryStoreDatabaseName LIKE [a].[DatabaseNamePattern])
            ORDER BY [a].[Priority],[a].[AssignmentId];
            SET @Profile=COALESCE(@Profile,'BALANCED');
        END;
        IF NOT EXISTS(SELECT 1 FROM [monitor].[PlanAnalysisProfile] WHERE [ProfileCode]=@Profile AND [IsEnabled]=1)
            SET @Profile='BALANCED';
    END;

    /* Bereits erfasste Meldungen beziehungsweise Current-Server-Evidenz normalisieren. */
    IF @StatusCodeOut='AVAILABLE'
       AND
       (
            @EvidenceForAnalysis IS NULL
         OR @StatisticsIoText IS NOT NULL
         OR @StatisticsTimeText IS NOT NULL
         OR @StatisticsMode IN ('USED','RELEVANT','OBJECT_ALL')
         OR @HistogramMode<>'NONE'
       )
    BEGIN
        DECLARE @EvidenceStatus varchar(40),@EvidencePartial bit,@EvidenceError int,@EvidenceMessage nvarchar(2048);
        EXEC [monitor].[USP_CreateExecutionEvidenceJson]
              @PlanXml=@EffectivePlanXml
            , @StatisticsIoText=@StatisticsIoText
            , @StatisticsTimeText=@StatisticsTimeText
            , @StatisticsLanguage=@StatisticsLanguage
            , @StatistikEvidenzModus=@StatisticsMode
            , @HistogrammModus=@HistogramMode
            , @MetadatenQuellenmodus=@MetadataMode
            , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
            , @EvidenzDatenschutzModus=@PrivacyMode
            , @IdentifierDatenschutzModus='RAW'
            , @SensitiveDataConfirmed=@SensitiveDataConfirmed
            , @MitPredicateHistogramMap=@MitPredicateHistogramMap
            , @StatementId=@StatementId
            , @ExistingEvidenceJson=@EvidenceForAnalysis
            , @MaxStatistiken=@MaxStatistiken
            , @MaxHistogrammSchritte=@MaxHistogrammSchritte
            , @LockTimeoutMs=@LockTimeoutMs
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @RawTextHandling='HASH_ONLY'
            , @StrictValidation=1
            , @ResultSetArt='NONE'
            , @JsonErzeugen=1
            , @Json=@EvidenceForAnalysis OUTPUT
            , @PrintMeldungen=0
            , @StatusCodeOut=@EvidenceStatus OUTPUT
            , @IsPartialOut=@EvidencePartial OUTPUT
            , @ErrorNumberOut=@EvidenceError OUTPUT
            , @ErrorMessageOut=@EvidenceMessage OUTPUT;
        IF COALESCE(@EvidencePartial,0)=1 OR @EvidenceStatus='PARTIAL'
            SET @IsPartialOut=1;
        IF @EvidenceStatus NOT IN ('AVAILABLE','PARTIAL')
        BEGIN
            SET @IsPartialOut=1;
            IF @ErrorMessageOut IS NULL SET @ErrorMessageOut=CONCAT(N'Evidenzanreicherung: ',COALESCE(@EvidenceMessage,@EvidenceStatus));
        END;
    END;

    IF @StatusCodeOut='AVAILABLE'
    BEGIN
        DECLARE @AnalyzerStatus varchar(40),@AnalyzerPartial bit,@AnalyzerError int,@AnalyzerMessage nvarchar(2048);
        EXEC [monitor].[InternalAnalyzeExecutionPlan]
              @AnalysisObjectId=1
            , @PlanXml=@EffectivePlanXml
            , @PlanSource=@EffectivePlanSource
            , @RuntimeCounterScope=@RuntimeScope
            , @WorkloadProfile=@Profile
            , @MinSeverity=@MinSeverity
            , @EvidenceJson=@EvidenceForAnalysis
            , @MitThreadRuntime=@MitThreadRuntime
            , @EvidenzDatenschutzModus=@PrivacyMode
            , @IdentifierDatenschutzModus=@IdentifierMode
            , @StatusCodeOut=@AnalyzerStatus OUTPUT
            , @IsPartialOut=@AnalyzerPartial OUTPUT
            , @ErrorNumberOut=@AnalyzerError OUTPUT
            , @ErrorMessageOut=@AnalyzerMessage OUTPUT;
        IF @AnalyzerStatus<>'AVAILABLE'
        BEGIN
            SET @StatusCodeOut=@AnalyzerStatus;
            SET @IsPartialOut=1;
            SET @ErrorNumberOut=@AnalyzerError;
            SET @ErrorMessageOut=@AnalyzerMessage;
        END;
    END;

    /* Current-Statistics- und Histogrammteile aus normalisierter Evidenz ergänzen. */
    IF @EvidenceForAnalysis IS NOT NULL AND ISJSON(@EvidenceForAnalysis)=1
    BEGIN
        ;WITH [CurrentStats] AS
        (
            SELECT *
            FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.currentSnapshot')
            WITH
            (
                  [DatabaseName] sysname N'$.databaseName'
                , [SchemaName] sysname N'$.schemaName'
                , [ObjectName] sysname N'$.objectName'
                , [StatisticsName] sysname N'$.statisticsName'
                , [LastUpdated] datetime2(7) N'$.lastUpdated'
                , [Rows] bigint N'$.rows'
                , [RowsSampled] bigint N'$.rowsSampled'
                , [ModificationCounter] bigint N'$.modificationCounter'
                , [SamplePercent] decimal(19,6) N'$.samplePercent'
            )
        )
        UPDATE [u]
        SET
              [u].[CurrentLastUpdated]=[c].[LastUpdated]
            , [u].[CurrentRows]=[c].[Rows]
            , [u].[CurrentRowsSampled]=[c].[RowsSampled]
            , [u].[CurrentModificationCounter]=[c].[ModificationCounter]
            , [u].[CurrentSamplePercent]=[c].[SamplePercent]
            , [u].[StatisticsChangedSinceCompile]=CONVERT(bit,CASE
                  WHEN [u].[LastUpdateAtCompile] IS NULL OR [c].[LastUpdated] IS NULL THEN 0
                  WHEN [u].[LastUpdateAtCompile]<>[c].[LastUpdated] THEN 1 ELSE 0 END)
            , [u].[MetadataMatchStatus]='AVAILABLE'
        FROM [#ExecutionPlanAnalysis_StatisticsUsage] AS [u]
        JOIN [CurrentStats] AS [c]
          ON [c].[DatabaseName]=[u].[DatabaseName]
         AND [c].[SchemaName]=[u].[SchemaName]
         AND [c].[ObjectName]=[u].[ObjectName]
         AND [c].[StatisticsName]=[u].[StatisticsName];

        INSERT [#ExecutionPlanAnalysis_HistogramSummaries]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.histogramSummaries')
        WITH
        (
              [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
            , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
            , [HistogramSteps] int N'$.histogramSteps',[HistogramEstimatedRows] float N'$.histogramEstimatedRows'
            , [MaxEqualRows] float N'$.maxEqualRows',[MaxRangeRows] float N'$.maxRangeRows'
            , [MaxStepRows] float N'$.maxStepRows',[DominantStepPercent] decimal(19,6) N'$.dominantStepPercent'
            , [TailStepRows] float N'$.tailStepRows',[TailStepPercent] decimal(19,6) N'$.tailStepPercent'
            , [CollectionStatus] varchar(40) N'$.collectionStatus'
        );
        INSERT [#ExecutionPlanAnalysis_HistogramSteps]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.statistics.histogramSteps')
        WITH
        (
              [DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[StatisticsName] sysname N'$.statisticsName'
            , [StatisticsId] int N'$.statisticsId',[LeadingColumnName] sysname N'$.leadingColumnName'
            , [StepOrdinal] int N'$.stepOrdinal',[RangeHighKey] nvarchar(4000) N'$.rangeHighKey'
            , [RangeHighKeyToken] varbinary(32) N'$.rangeHighKeyToken'
            , [RangeRows] float N'$.rangeRows',[EqualRows] float N'$.equalRows'
            , [DistinctRangeRows] bigint N'$.distinctRangeRows',[AverageRangeRows] float N'$.averageRangeRows'
            , [IsPredicateTarget] bit N'$.isPredicateTarget',[PredicateMatchCount] int N'$.predicateMatchCount'
            , [SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
        );
        INSERT [#ExecutionPlanAnalysis_PredicateHistogramMappings]
        SELECT *
        FROM OPENJSON(@EvidenceForAnalysis,N'$.predicateHistogramMappings')
        WITH
        (
              [PredicateReferenceId] bigint N'$.predicateReferenceId',[StatementOrdinal] int N'$.statementOrdinal'
            , [NodeId] int N'$.nodeId',[DatabaseName] sysname N'$.databaseName',[SchemaName] sysname N'$.schemaName'
            , [ObjectName] sysname N'$.objectName',[ColumnName] sysname N'$.columnName'
            , [StatisticsName] sysname N'$.statisticsName',[PredicateKind] varchar(40) N'$.predicateKind'
            , [ValueSource] varchar(32) N'$.valueSource',[MappingStatus] varchar(48) N'$.mappingStatus'
            , [MappingConfidence] varchar(16) N'$.mappingConfidence',[MatchedStepOrdinal] int N'$.matchedStepOrdinal'
            , [MatchesRangeHighKey] bit N'$.matchesRangeHighKey',[IsBelowHistogram] bit N'$.isBelowHistogram'
            , [IsAboveHistogram] bit N'$.isAboveHistogram',[SensitiveValueStatus] varchar(40) N'$.sensitiveValueStatus'
        );
    END;

    IF @StatementId IS NOT NULL
    BEGIN
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_ExecutionEvidence] WHERE [StatementOrdinal] IS NOT NULL AND [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementId]=@StatementId);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementId]<>@StatementId OR [StatementId] IS NULL;
    END;

    IF @StatementQueryHash IS NOT NULL
    BEGIN
        DECLARE @QueryHashText nvarchar(130)=CONVERT(nvarchar(130),@StatementQueryHash,1);
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]=@QueryHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryHash]<>@QueryHashText OR [StatementQueryHash] IS NULL;
    END;

    IF @StatementQueryPlanHash IS NOT NULL
    BEGIN
        DECLARE @QueryPlanHashText nvarchar(130)=CONVERT(nvarchar(130),@StatementQueryPlanHash,1);
        DELETE FROM [#ExecutionPlanAnalysis_Findings] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_MemoryAndSpills] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Parameters] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_StatisticsUsage] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_AccessPaths] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_OperatorRuntime] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Operators] WHERE [StatementOrdinal] NOT IN
            (SELECT [StatementOrdinal] FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]=@QueryPlanHashText);
        DELETE FROM [#ExecutionPlanAnalysis_Statements] WHERE [StatementQueryPlanHash]<>@QueryPlanHashText OR [StatementQueryPlanHash] IS NULL;
    END;

    IF @MitSqlText=0 UPDATE [#ExecutionPlanAnalysis_Statements] SET [StatementText]=NULL;

    /* Identifikatordatenschutz erst nach fachlicher Korrelation. */
    IF @IdentifierMode IN ('TOKENIZED','OMIT')
    BEGIN
        UPDATE [#ExecutionPlanAnalysis_Operators]
        SET [ObjectDatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectDatabaseName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectDatabaseName])),1) END,
            [ObjectSchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectSchemaName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectSchemaName])),1) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1) END,
            [IndexName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [IndexName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[IndexName])),1) END;
        UPDATE [#ExecutionPlanAnalysis_AccessPaths]
        SET [DatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [DatabaseName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1) END,
            [SchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [SchemaName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1) END,
            [IndexName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [IndexName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[IndexName])),1) END;
        UPDATE [#ExecutionPlanAnalysis_StatisticsUsage]
        SET [DatabaseName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [DatabaseName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[DatabaseName])),1)) END,
            [SchemaName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [SchemaName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[SchemaName])),1)) END,
            [ObjectName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ObjectName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ObjectName])),1)) END,
            [StatisticsName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [StatisticsName] IS NOT NULL THEN CONVERT(sysname,CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[StatisticsName])),1)) END;
        UPDATE [#ExecutionPlanAnalysis_Parameters]
        SET [ParameterName]=CASE WHEN @IdentifierMode='TOKENIZED' AND [ParameterName] IS NOT NULL THEN CONVERT(nvarchar(130),HASHBYTES('SHA2_256',@TokenSalt+CONVERT(varbinary(max),[ParameterName])),1) END;
    END;

    IF (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Operators])>@MaxOperatoren
    BEGIN
        CREATE TABLE [#ExecutionPlanAnalysis_RetainedOperators]
        (
              [AnalysisObjectId] int NOT NULL
            , [StatementOrdinal] int NOT NULL
            , [NodeId] int NOT NULL
            , PRIMARY KEY ([AnalysisObjectId],[StatementOrdinal],[NodeId])
        );
        INSERT [#ExecutionPlanAnalysis_RetainedOperators]([AnalysisObjectId],[StatementOrdinal],[NodeId])
        SELECT TOP (@MaxOperatoren) [AnalysisObjectId],[StatementOrdinal],[NodeId]
        FROM [#ExecutionPlanAnalysis_Operators]
        ORDER BY [StatementOrdinal],[NodeId];

        DELETE [o]
        FROM [#ExecutionPlanAnalysis_Operators] AS [o]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[o].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[o].[StatementOrdinal]
              AND [k].[NodeId]=[o].[NodeId]
        );
        DELETE [r]
        FROM [#ExecutionPlanAnalysis_OperatorRuntime] AS [r]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[r].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[r].[StatementOrdinal]
              AND [k].[NodeId]=[r].[NodeId]
        );
        DELETE [r]
        FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] AS [r]
        WHERE NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[r].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[r].[StatementOrdinal]
              AND [k].[NodeId]=[r].[NodeId]
        );
        DELETE [a]
        FROM [#ExecutionPlanAnalysis_AccessPaths] AS [a]
        WHERE [a].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[a].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[a].[StatementOrdinal]
              AND [k].[NodeId]=[a].[NodeId]
        );
        DELETE [m]
        FROM [#ExecutionPlanAnalysis_MemoryAndSpills] AS [m]
        WHERE [m].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[m].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[m].[StatementOrdinal]
              AND [k].[NodeId]=[m].[NodeId]
        );
        DELETE [f]
        FROM [#ExecutionPlanAnalysis_Findings] AS [f]
        WHERE [f].[NodeId] IS NOT NULL
          AND NOT EXISTS
        (
            SELECT 1 FROM [#ExecutionPlanAnalysis_RetainedOperators] AS [k]
            WHERE [k].[AnalysisObjectId]=[f].[AnalysisObjectId]
              AND [k].[StatementOrdinal]=[f].[StatementOrdinal]
              AND [k].[NodeId]=[f].[NodeId]
        );
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END;
    IF (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Findings])>@MaxFindings
    BEGIN
        DELETE [f]
        FROM [#ExecutionPlanAnalysis_Findings] AS [f]
        WHERE [f].[FindingOrdinal] NOT IN
        (
            SELECT TOP (@MaxFindings) [FindingOrdinal]
            FROM [#ExecutionPlanAnalysis_Findings]
            ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,
                     [FindingOrdinal]
        );
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
    END;
    IF SYSUTCDATETIME()>@Deadline
    BEGIN
        SET @IsPartialOut=1;
        IF @StatusCodeOut='AVAILABLE' SET @StatusCodeOut='PARTIAL';
        IF @ErrorMessageOut IS NULL SET @ErrorMessageOut=N'Das kooperative Zeitbudget wurde während der Verarbeitung überschritten.';
    END;

    INSERT [#ExecutionPlanAnalysis_ModuleStatus]
    SELECT N'USP_ExecutionPlanAnalysis',@Now,@StatusCodeOut,@IsPartialOut,@EffectivePlanSource,@RuntimeScope,@Profile,
           (SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Statements]),(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Operators]),(SELECT COUNT(*) FROM [#ExecutionPlanAnalysis_Findings]),
           @ErrorNumberOut,@ErrorMessageOut;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'ExecutionPlanAnalysis' [resultName],1 [schemaVersion],@Now [generatedAtUtc],@StatusCodeOut [statusCode],@IsPartialOut [isPartial],@EffectivePlanSource [planSource],@RuntimeScope [runtimeCounterScope],@Profile [workloadProfile] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @CapabilitiesJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Capabilities] ORDER BY [FeatureCode] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_PlanDocuments] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatementsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Statements] ORDER BY [StatementOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @OperatorsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Operators] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RuntimeJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_OperatorRuntime] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ThreadsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] ORDER BY [StatementOrdinal],[NodeId],[ThreadId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @AccessJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_AccessPaths] ORDER BY [StatementOrdinal],[NodeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @StatsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_StatisticsUsage] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ParametersJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Parameters] ORDER BY [StatementOrdinal],[ParameterName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MemoryJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_MemoryAndSpills] ORDER BY [StatementOrdinal],[NodeId],[RecordType] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @EvidenceJsonOut nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_ExecutionEvidence] ORDER BY [StatementOrdinal],[EvidenceType],[MetricName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramSummaryJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_HistogramSummaries] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @HistogramStepsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_HistogramSteps] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @MappingsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_PredicateHistogramMappings] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FindingsJson nvarchar(max)=(SELECT * FROM [#ExecutionPlanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"capabilities":',COALESCE(@CapabilitiesJson,N'[]'),N',"planDocuments":',COALESCE(@PlanJson,N'[]'),N',"statements":',COALESCE(@StatementsJson,N'[]'),N',"operatorTree":',COALESCE(@OperatorsJson,N'[]'),N',"operatorRuntime":',COALESCE(@RuntimeJson,N'[]'),N',"operatorThreadRuntime":',COALESCE(@ThreadsJson,N'[]'),N',"accessPaths":',COALESCE(@AccessJson,N'[]'),N',"statisticsUsage":',COALESCE(@StatsJson,N'[]'),N',"parametersAndVariants":',COALESCE(@ParametersJson,N'[]'),N',"memoryAndSpills":',COALESCE(@MemoryJson,N'[]'),N',"executionEvidence":',COALESCE(@EvidenceJsonOut,N'[]'),N',"histogramSummaries":',COALESCE(@HistogramSummaryJson,N'[]'),N',"histogramSteps":',COALESCE(@HistogramStepsJson,N'[]'),N',"predicateHistogramMappings":',COALESCE(@MappingsJson,N'[]'),N',"findings":',COALESCE(@FindingsJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#ExecutionPlanAnalysis_ModuleStatus];
        SELECT * FROM [#ExecutionPlanAnalysis_Capabilities] ORDER BY [FeatureCode];
        SELECT * FROM [#ExecutionPlanAnalysis_PlanDocuments];
        SELECT * FROM [#ExecutionPlanAnalysis_Statements] ORDER BY [StatementOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_Operators] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_OperatorRuntime] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_OperatorThreadRuntime] ORDER BY [StatementOrdinal],[NodeId],[ThreadId];
        SELECT * FROM [#ExecutionPlanAnalysis_AccessPaths] ORDER BY [StatementOrdinal],[NodeId];
        SELECT * FROM [#ExecutionPlanAnalysis_StatisticsUsage] ORDER BY [StatementOrdinal],[StatisticsUsageOrdinal];
        SELECT * FROM [#ExecutionPlanAnalysis_Parameters] ORDER BY [StatementOrdinal],[ParameterName];
        SELECT * FROM [#ExecutionPlanAnalysis_MemoryAndSpills] ORDER BY [StatementOrdinal],[NodeId],[RecordType];
        SELECT * FROM [#ExecutionPlanAnalysis_ExecutionEvidence] ORDER BY [StatementOrdinal],[EvidenceType],[MetricName];
        SELECT * FROM [#ExecutionPlanAnalysis_HistogramSummaries];
        SELECT * FROM [#ExecutionPlanAnalysis_HistogramSteps];
        SELECT * FROM [#ExecutionPlanAnalysis_PredicateHistogramMappings];
        SELECT * FROM [#ExecutionPlanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[FindingOrdinal];
    END;

    IF @ConsoleRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExecutionPlanAnalysis_Findings'
            , @ResultLabel=N'Execution Plan Finding'
            , @EmptyMessage=N'Keine Findings im gewählten Scope'
            , @StatusCode=@StatusCodeOut
            , @StatusMessage=@ErrorMessageOut;

    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [OutputCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable] FROM [#ExecutionPlanAnalysis_TableMap] ORDER BY [ResultName];
        OPEN [OutputCursor];
        FETCH NEXT FROM [OutputCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'moduleStatus' THEN N'#ExecutionPlanAnalysis_ModuleStatus'
                WHEN N'capabilities' THEN N'#ExecutionPlanAnalysis_Capabilities'
                WHEN N'planDocuments' THEN N'#ExecutionPlanAnalysis_PlanDocuments'
                WHEN N'statements' THEN N'#ExecutionPlanAnalysis_Statements'
                WHEN N'operatorTree' THEN N'#ExecutionPlanAnalysis_Operators'
                WHEN N'operatorRuntime' THEN N'#ExecutionPlanAnalysis_OperatorRuntime'
                WHEN N'operatorThreadRuntime' THEN N'#ExecutionPlanAnalysis_OperatorThreadRuntime'
                WHEN N'accessPaths' THEN N'#ExecutionPlanAnalysis_AccessPaths'
                WHEN N'statisticsUsage' THEN N'#ExecutionPlanAnalysis_StatisticsUsage'
                WHEN N'parametersAndVariants' THEN N'#ExecutionPlanAnalysis_Parameters'
                WHEN N'memoryAndSpills' THEN N'#ExecutionPlanAnalysis_MemoryAndSpills'
                WHEN N'executionEvidence' THEN N'#ExecutionPlanAnalysis_ExecutionEvidence'
                WHEN N'histogramSummaries' THEN N'#ExecutionPlanAnalysis_HistogramSummaries'
                WHEN N'histogramSteps' THEN N'#ExecutionPlanAnalysis_HistogramSteps'
                WHEN N'predicateHistogramMappings' THEN N'#ExecutionPlanAnalysis_PredicateHistogramMappings'
                WHEN N'findings' THEN N'#ExecutionPlanAnalysis_Findings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [OutputCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [OutputCursor];DEALLOCATE [OutputCursor];
    END;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE')
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_ExecutionPlanAnalysis: %s - %s',@StatusCodeOut,COALESCE(@ErrorMessageOut,N'partielle Analyse'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO
