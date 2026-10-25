USE [DeineDatenbank];
GO

/*
Objekt: monitor.USP_SsisPackageModelAnalysis; Version 1.9.0; Stand 2026-10-25.
Zweck: Validiert ein optional zugeliefertes neutrales SSIS-Modell ohne CLR.
Quelle: Caller-JSON, optionale Originalbytes und lokale Herkunftsbelege;
        lokale SQL-Kataloge nur mit expliziter Metadatenzuordnung, kein Paket-SQL.
Vertrag: SSIS_Analyze_Toolbelt_Exchange_Contract.md; Schema aus Toolbelt.
Grenzen: 16 MiB JSON/Bytes, 32 JSON-Ebenen, 20000 Knoten, 50000 Kanten;
         kooperatives Zeitbudget. Producerangaben ohne qualifizierte lokale Übergabe bleiben UNVERIFIED.
Seiteneffekte: Eigene lokale Temp-Tabellen und explizite TABLE-Ausgabeziele.
Die BIN2-Vergleiche gelten nur für den ordinalen Austauschvertrag; native
Resultsets behalten die explizite Frameworkcollation.
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson nvarchar(max) = NULL
    , @PackageBytes varbinary(max) = NULL
    , @MaxZeilen int = 1000
    , @MaxDurationSeconds int = 30
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
    , @IncludePackageViews bit = 0
    , @IncludeObjectRules bit = 0
    , @LocalHandoverId uniqueidentifier = NULL
    , @IncludeSqlMetadata bit = 0
    , @SqlMetadataBindingsJson nvarchar(max) = NULL
    , @IncludeExecutionCorrelation bit = 0
    , @ExecutionId bigint = NULL
    , @ExecutionSnapshotJson nvarchar(max) = NULL
    , @RuntimeHandoverId uniqueidentifier = NULL
    , @IncludeIterationCorrelation bit = 0
    , @IncludeExecutionScopes bit = 0
    , @ProjectModelsJson nvarchar(max) = NULL
    , @ScopeSnapshotJson nvarchar(max) = NULL
    , @ScopeHandoverId uniqueidentifier = NULL
    , @IncludePipelineCorrelation bit = 0
    , @IncludePipelineDiagnostics bit = 0
    , @PipelinePhaseThresholdMs bigint = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_SsisPackageModelAnalysis: natives SSIS-Modell 1.0.0; kein CLR, Toolbelt- oder Dateizugriff.';
        PRINT N'@PackageModelJson erforderlich; @PackageBytes optional zum unabhängigen Bytevergleich. ProducerTrust ist ohne @LocalHandoverId UNVERIFIED.';
        PRINT N'CONSOLE|RAW|TABLE|NONE; JSON über OUTPUT. TABLE-Namen: moduleStatus|sourceBinding|nodes|edges|coverage|findings|sourceStatus|warnings.';
        PRINT N'@IncludePackageViews=1 ergänzt packageOverview|executables|dataFlows|components|columnRelations. Die fünf Sichten zeigen ausschließlich gelieferte Beziehungen.';
        PRINT N'@IncludeObjectRules=1 ergänzt objectFindings mit konkreten Knoten-/Kantenbelegen; statische Hinweise, keine Laufzeiturteile.';
        PRINT N'@LocalHandoverId prüft eine separat berechtigt registrierte lokale Übergabe; benötigt dieselben @PackageBytes. Kein Trust-Flag im Caller-JSON.';
        PRINT N'@IncludeSqlMetadata=1 ergänzt sqlMetadata aus expliziten paketgebundenen lokalen SQL-Spaltenzuordnungen; keine Paket-SQL-Ausführung oder Typkonvertierungsfreigabe.';
        PRINT N'@IncludeExecutionCorrelation=1 ergänzt runtimeBinding|executionCorrelation für @ExecutionId. Nur qualifizierte lokale Katalogcaptures werden zugeordnet; kein SSISDB-Zugriff im Importer.';
        PRINT N'@IncludeIterationCorrelation=1 verlangt Ausführungskorrelation und den Iterationscapture 1.1; ergänzt executionObjectSummary|executionCoverage. Beobachtungen sind kein Vollständigkeitsnachweis.';
        PRINT N'@IncludeExecutionScopes=1 verwendet exklusiv @ProjectModelsJson, @ScopeSnapshotJson und @ScopeHandoverId für Kindpaket-/Handlerbelege; sieben eigene Resultsets, stets partiell.';
        PRINT N'@IncludePipelineCorrelation=1 ergänzt im Scopemodus pipelineInstances|componentPhases|pathTransfers|pipelineCoverage aus gebundenen Belegen; keine Laufzeit-Lineage.';
        PRINT N'@IncludePipelineDiagnostics=1 verlangt Scope- und Pipelinekorrelation; ergänzt componentPhaseSummary|pathTransferSummary|pipelineFindings|pipelineDiagnosticCoverage. @PipelinePhaseThresholdMs ist ein optionaler nichtnegativer Einzelintervall-Grenzwert.';
        RETURN;
    END;
    IF XACT_STATE()=-1 THROW 50000,N'EXCHANGE_INVALID: Callertransaktion ist nicht schreibfähig.',1;
    IF @IncludeExecutionScopes=1
    BEGIN
        IF @PackageModelJson IS NOT NULL OR @PackageBytes IS NOT NULL OR COALESCE(@IncludePackageViews,1)<>0 OR COALESCE(@IncludeObjectRules,1)<>0 OR COALESCE(@IncludeSqlMetadata,1)<>0 OR COALESCE(@IncludeExecutionCorrelation,1)<>0 OR COALESCE(@IncludeIterationCorrelation,1)<>0 OR @LocalHandoverId IS NOT NULL OR @ExecutionSnapshotJson IS NOT NULL OR @RuntimeHandoverId IS NOT NULL OR @SqlMetadataBindingsJson IS NOT NULL OR @IncludePipelineCorrelation IS NULL
            SET @MaxDurationSeconds=0; -- Der Scopeconsumer liefert den kontrollierten INVALID_PARAMETER-Vertrag.
        EXEC monitor.InternalSsisExecutionScopes @IncludePipelineCorrelation=@IncludePipelineCorrelation,@IncludePipelineDiagnostics=@IncludePipelineDiagnostics,@PipelinePhaseThresholdMs=@PipelinePhaseThresholdMs,@Models=@ProjectModelsJson,@Capture=@ScopeSnapshotJson,@Handover=@ScopeHandoverId,@ExecutionId=@ExecutionId,@LockTimeoutMs=@LockTimeoutMs,@MaxZeilen=@MaxZeilen,@MaxDurationSeconds=@MaxDurationSeconds,@ResultSetArt=@ResultSetArt,@ResultTablesJson=@ResultTablesJson,@JsonErzeugen=@JsonErzeugen,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCodeOut OUTPUT,@IsPartialOut=@IsPartialOut OUTPUT,@ErrorNumberOut=@ErrorNumberOut OUTPUT,@ErrorMessageOut=@ErrorMessageOut OUTPUT;
        RETURN;
    END;

    SET XACT_ABORT OFF;
    DECLARE @Started datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3),@Status varchar(40)='AVAILABLE_LIMITED',@Partial bit=1;
    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80),@Error int=NULL,@Message nvarchar(2048)=NULL;
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 9223372036854775807 ELSE @MaxZeilen END;
    DECLARE @ProfileSupported bit=1,@SchemaVersion int=1;
    DECLARE @ValidationStage varchar(24)='PARAMETERS',@ProducerTrust varchar(24)='UNVERIFIED';
    DECLARE @AllowedResultNames nvarchar(max)=N'moduleStatus|sourceBinding|nodes|edges|coverage|findings|sourceStatus|warnings'
        +CASE WHEN @IncludePackageViews=1 THEN N'|packageOverview|executables|dataFlows|components|columnRelations' ELSE N'' END
        +CASE WHEN @IncludeObjectRules=1 THEN N'|objectFindings' ELSE N'' END
        +CASE WHEN @IncludeSqlMetadata=1 THEN N'|sqlMetadata' ELSE N'' END
        +CASE WHEN @IncludeExecutionCorrelation=1 THEN N'|runtimeBinding|executionCorrelation' ELSE N'' END
        +CASE WHEN @IncludeIterationCorrelation=1 THEN N'|executionObjectSummary|executionCoverage' ELSE N'' END;

    CREATE TABLE #SsisPackageModelAnalysis_ResultTables([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    IF @Mode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
            @AllowedResultNames=@AllowedResultNames,
            @MappingTable=N'#SsisPackageModelAnalysis_ResultTables',@ThrowOnError=1;
    CREATE TABLE #SsisPackageModelAnalysis_ModuleStatus(
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CollectionTimeUtc] datetime2(3) NOT NULL,[SchemaVersion] int NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[NodeCount] int NOT NULL,[EdgeCount] int NOT NULL,
        [ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Binding(
        [PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ByteLength] int NOT NULL,
        [BindingStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ProducerTrust] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ProducerVersion] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceCommit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[BuildSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Nodes(
        [NodeOrdinal] int NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [NodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [NodeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[AttributesJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Edges(
        [EdgeOrdinal] int NOT NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [EdgeKind] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FromNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Resolution] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Evidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MappingRole] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsInterpretable] bit NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Coverage(
        [Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[ReportedStatus] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ReasonCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsProfileSupported] bit NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Findings(
        [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLevel] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Finding] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_SourceStatus(
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,[ReturnedRowCount] bigint NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Warnings(
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WarningSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_PackageOverview(
        [PackageNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ExecutableCount] int NOT NULL,[ObservedDataFlowScopeCount] int NOT NULL,[ComponentCount] int NOT NULL,[PortCount] int NOT NULL,[ColumnCount] int NOT NULL,
        [VariableCount] int NOT NULL,[ParameterCount] int NOT NULL,[ConnectionCount] int NOT NULL,[DeclaredPathCount] int NOT NULL,[ColumnRelationCount] int NOT NULL,
        [UnresolvedEdgeCount] int NOT NULL,[LimitedFeatureCount] int NOT NULL,[SourceNodeCount] int NOT NULL,[SourceEdgeCount] int NOT NULL,
        [ProducerTrust] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Executables(
        [NodeOrdinal] int NOT NULL,[ExecutableNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[OwnerDepth] int NOT NULL,[ExecutableType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsDisabled] bit NULL,[IsEventHandler] bit NULL,[DirectComponentCount] int NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_DataFlows(
        [NodeOrdinal] int NOT NULL,[ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ScopeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ComponentCount] int NOT NULL,[PortCount] int NOT NULL,[DataColumnCount] int NOT NULL,[DeclaredPathCount] int NOT NULL,[UnresolvedEdgeCount] int NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_Components(
        [NodeOrdinal] int NOT NULL,[ComponentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ComponentName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ComponentClassId] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [InputPortCount] int NOT NULL,[OutputPortCount] int NOT NULL,[UnknownDirectionPortCount] int NOT NULL,[DataColumnCount] int NOT NULL,[ExternalMetadataColumnCount] int NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_ColumnRelations(
        [EdgeOrdinal] int NOT NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EdgeKind] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FromNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FromNodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FromNodeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FromColumnNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [FromComponentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FromColumnName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [FromTypeCode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FromLength] int NULL,[ToColumnNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ToComponentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToColumnName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ToTypeCode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToLength] int NULL,[Resolution] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Evidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MappingRole] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsInterpretable] bit NOT NULL);

    CREATE TABLE #SsisPackageModelAnalysis_ObjectFindings(
        [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLevel] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [BindingStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ProducerTrust] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Finding] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);

    CREATE TABLE #SsisPackageModelAnalysis_SqlMetadata(
        [BindingOrdinal] int NOT NULL,[BindingId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [KeySetId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DatabaseId] int NULL,[ObjectId] int NULL,[ColumnId] int NULL,[SqlObjectType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SqlTypeSchema] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SqlTypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SystemTypeId] int NULL,[MaxLengthBytes] smallint NULL,[Precision] tinyint NULL,[Scale] tinyint NULL,
        [SqlCollation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsNullable] bit NULL,[IsComputed] bit NULL,[IsIdentity] bit NULL,
        [ModelTypeCode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ModelIsNullable] bit NULL,[NullableAgreement] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [UniqueKeyStatus] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeCompatibilityStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[BindingStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ProducerTrust] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedUtc] datetime2(3) NULL,[ErrorNumber] int NULL);
    CREATE TABLE #SsisPackageModelAnalysis_RuntimeBinding(
        [ExecutionId] bigint NOT NULL,[CatalogDatabaseGuid] uniqueidentifier NULL,[SourceBindingSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ProjectId] bigint NULL,[ProjectLsn] bigint NULL,
        [PackageFileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionCreatedUtc] datetimeoffset(7) NULL,
        [ExecutionStatus] int NULL,[StartTime] datetimeoffset(7) NULL,[EndTime] datetimeoffset(7) NULL,[SnapshotStartedUtc] datetime2(7) NULL,[SnapshotCompletedUtc] datetime2(7) NULL,
        [PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RootObservationQualified] bit NOT NULL,[ObservedRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL);
    CREATE TABLE #SsisPackageModelAnalysis_ExecutionCorrelation(
        [StatisticsId] bigint NOT NULL PRIMARY KEY,[ExecutionId] bigint NOT NULL,[ExecutableId] bigint NOT NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ModelNodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutableGuid] uniqueidentifier NULL,[PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PackagePath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StartTime] datetimeoffset(7) NULL,[EndTime] datetimeoffset(7) NULL,[DurationMs] int NULL,[ExecutionResult] int NULL,
        [CorrelationStatus] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_ExecutionObjectSummary(
        [ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[ModelNodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ObservedInstanceCount] int NOT NULL,[SucceededCount] int NOT NULL,[FailedCount] int NOT NULL,[CancelledCount] int NOT NULL,[OtherResultCount] int NOT NULL,
        [KnownDurationCount] int NOT NULL,[MinDurationMs] int NULL,[MaxDurationMs] int NULL,[InclusiveObservedDurationMs] bigint NULL,
        [ObservationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
    CREATE TABLE #SsisPackageModelAnalysis_ExecutionCoverage(
        [ExecutionId] bigint NOT NULL,[CaptureMethod] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LoggingLevel] int NULL,
        [LoggingCoverage] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservationScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CaptureState] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[UnassignedRowCount] int NOT NULL,[IsPartial] bit NOT NULL);

    -- BEGIN GENERATED SSIS EXCHANGE RULES
    DECLARE @FieldRulesJson nvarchar(max) = N'[{"role":"ROOT","name":"contract","types":"1","required":true,"enum":["ssis-package-model"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"version","types":"1","required":true,"enum":["1.0.0"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"identityProfile","types":"1","required":true,"enum":["document-order-v1"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"producer","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"PRODUCER"},{"role":"ROOT","name":"source","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"SOURCE"},{"role":"ROOT","name":"profiles","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"PROFILES"},{"role":"ROOT","name":"coverage","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":8,"maxItems":8,"pattern":null,"childRole":"COVERAGE_ARRAY"},{"role":"ROOT","name":"nodes","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":1,"maxItems":20000,"pattern":null,"childRole":"NODES_ARRAY"},{"role":"ROOT","name":"edges","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":50000,"pattern":null,"childRole":"EDGES_ARRAY"},{"role":"ROOT","name":"diagnostics","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":1000,"pattern":null,"childRole":"DIAGNOSTICS_ARRAY"},{"role":"PRODUCER","name":"id","types":"1","required":true,"enum":["toolbelt.ssis-model"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"PRODUCER","name":"version","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PRODUCER","name":"sourceCommit","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX40","childRole":null},{"role":"PRODUCER","name":"buildSha256","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX64","childRole":null},{"role":"SOURCE","name":"kind","types":"1","required":true,"enum":["DTSX_BYTES"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"packageSha256","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX64","childRole":null},{"role":"SOURCE","name":"byteLength","types":"2","required":true,"enum":null,"maxLength":null,"min":1,"max":16777216,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"packageFormatVersion","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"xmlProfile","types":"1","required":true,"enum":["2012/01","2014/01","UNKNOWN"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"PROFILES","name":"format","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PROFILES","name":"components","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PROFILES","name":"lineage","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"COVERAGE","name":"feature","types":"1","required":true,"enum":["inventory","controlFlow","pipelineGraph","columnMetadata","directColumnMapping","valueLineage","rowLineage","expressionReferences"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"COVERAGE","name":"status","types":"1","required":true,"enum":["COMPLETE","PARTIAL","UNSUPPORTED","NOT_REQUESTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"COVERAGE","name":"reasonCode","types":"01","required":true,"enum":["PROFILE_LIMIT","UNKNOWN_COMPONENT","ENCRYPTED_CONTENT","EXPRESSION_UNRESOLVED","MISSING_CONTEXT","UNSUPPORTED_PACKAGE_FORMAT","SCOPE_NOT_REQUESTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"id","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"NODE","name":"kind","types":"1","required":true,"enum":["PACKAGE","EXECUTABLE","COMPONENT","PORT","COLUMN","VARIABLE","PARAMETER","CONNECTION","EXPRESSION"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"parentId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"NODE","name":"name","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"attributes","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"id","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"EDGEID","childRole":null},{"role":"EDGE","name":"kind","types":"1","required":true,"enum":["CONTROL_FLOW","PIPELINE_PATH","COLUMN_MAP","VALUE_DEPENDENCY","ROW_DEPENDENCY","EXPRESSION_REFERENCE"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"scopeId","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"fromId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"toId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"resolution","types":"1","required":true,"enum":["RESOLVED","UNRESOLVED","UNSUPPORTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"evidence","types":"1","required":true,"enum":["DECLARED","DERIVED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"mappingRole","types":"01","required":true,"enum":["DATA_TRANSFER","METADATA_REFERENCE",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"ruleId","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"RULEID","childRole":null},{"role":"DIAGNOSTIC","name":"code","types":"1","required":true,"enum":["UNKNOWN_COMPONENT","ENCRYPTED_CONTENT","EXPRESSION_UNRESOLVED","MISSING_CONTEXT","PARTIAL_LINEAGE","PROFILE_LIMIT","UNSUPPORTED_PACKAGE_FORMAT"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"DIAGNOSTIC","name":"objectId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"ATTR_PACKAGE","name":"protectionLevel","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"executableType","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"isDisabled","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"isEventHandler","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COMPONENT","name":"componentClassId","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"direction","types":"01","required":true,"enum":["INPUT","OUTPUT",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"portRole","types":"01","required":true,"enum":["REGULAR","ERROR","NO_MATCH","DEFAULT","UNKNOWN",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"synchronousInputPortId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"ATTR_COLUMN","name":"columnRole","types":"1","required":true,"enum":["DATA","EXTERNAL_METADATA"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"length","types":"02","required":true,"enum":null,"maxLength":null,"min":-1,"max":2147483647,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"precision","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":255,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"scale","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":255,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"codePage","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":2147483647,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"isNullable","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"namespace","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"isReadOnly","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"evaluateAsExpression","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PARAMETER","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_CONNECTION","name":"connectionKind","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXPRESSION","name":"propertyName","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null}]';
    -- END GENERATED SSIS EXCHANGE RULES

    BEGIN TRY
        IF @IncludePipelineDiagnostics IS NULL OR @IncludePipelineDiagnostics<>0 OR @PipelinePhaseThresholdMs IS NOT NULL OR @IncludePipelineCorrelation IS NULL OR @IncludePipelineCorrelation<>0 OR @IncludeExecutionScopes IS NULL OR @ProjectModelsJson IS NOT NULL OR @ScopeSnapshotJson IS NOT NULL OR @ScopeHandoverId IS NOT NULL OR @MaxZeilen<0 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
           OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000 OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
           OR @IncludeExecutionCorrelation IS NULL OR @IncludeExecutionCorrelation=1 AND (@ExecutionId IS NULL OR @ExecutionId<1)
           OR @IncludeIterationCorrelation IS NULL OR @IncludeIterationCorrelation=1 AND @IncludeExecutionCorrelation<>1 OR @IncludeExecutionCorrelation=0 AND (@ExecutionId IS NOT NULL OR @ExecutionSnapshotJson IS NOT NULL OR @RuntimeHandoverId IS NOT NULL) OR @IncludeSqlMetadata IS NULL OR @IncludeSqlMetadata=0 AND @SqlMetadataBindingsJson IS NOT NULL OR @IncludeObjectRules IS NULL OR @IncludePackageViews IS NULL OR @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR (@Mode<>'TABLE' AND @ResultTablesJson IS NOT NULL)
            THROW 50000,N'INVALID_PARAMETER',1;
        SET @Deadline=DATEADD(second,@MaxDurationSeconds,@Started);
        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@LockTimeoutMs)+N';'; EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF DATALENGTH(@PackageModelJson)>16777216 OR DATALENGTH(@PackageBytes)>16777216 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
        IF @PackageModelJson IS NULL OR ISJSON(@PackageModelJson)<>1 OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@PackageModelJson,NCHAR(9),N' '),NCHAR(10),N' '),NCHAR(13),N' ')),1)<>N'{'
            THROW 50000,N'EXCHANGE_INVALID',1;
        IF COALESCE(JSON_VALUE(@PackageModelJson,'$.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-package-model'
            OR COALESCE(JSON_VALUE(@PackageModelJson,'$.version'),'') COLLATE Latin1_General_100_BIN2<>'1.0.0'
            OR COALESCE(JSON_VALUE(@PackageModelJson,'$.identityProfile'),'') COLLATE Latin1_General_100_BIN2<>'document-order-v1'
            THROW 50000,N'EXCHANGE_VERSION_UNSUPPORTED',1;

        SET @ValidationStage='JSON_TREE';
        CREATE TABLE #SsisPackageModelAnalysis_Rules(
            [Role] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Types] varchar(6) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Required] bit NOT NULL,[EnumJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [MaxLength] int NULL,[Minimum] bigint NULL,[Maximum] bigint NULL,[MinItems] int NULL,[MaxItems] int NULL,
            [Pattern] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ChildRole] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        INSERT #SsisPackageModelAnalysis_Rules
        SELECT [role],[name],[types],[required],[enum],[maxLength],[min],[max],[minItems],[maxItems],[pattern],[childRole]
        FROM OPENJSON(@FieldRulesJson) WITH([role] varchar(40),[name] nvarchar(128),[types] varchar(6),[required] bit,[enum] nvarchar(max) AS JSON,
            [maxLength] int,[min] bigint,[max] bigint,[minItems] int,[maxItems] int,[pattern] varchar(16),[childRole] varchar(40));
        CREATE TABLE #SsisPackageModelAnalysis_Tokens(
            [TokenId] int IDENTITY(1,1) NOT NULL PRIMARY KEY,[ParentId] int NULL,[Depth] int NOT NULL,[Role] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Name] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Value] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Type] int NOT NULL);
        INSERT #SsisPackageModelAnalysis_Tokens([ParentId],[Depth],[Role],[Name],[Value],[Type]) VALUES(NULL,1,'ROOT',NULL,@PackageModelJson,5);
        DECLARE @Depth int=1;
        WHILE EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens WHERE [Depth]=@Depth AND [Type] IN (4,5))
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
            IF @Depth>=32 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            INSERT #SsisPackageModelAnalysis_Tokens([ParentId],[Depth],[Role],[Name],[Value],[Type])
            SELECT [p].[TokenId],@Depth+1,
                CASE [p].[Role] WHEN 'NODES_ARRAY' THEN 'NODE' WHEN 'EDGES_ARRAY' THEN 'EDGE' WHEN 'COVERAGE_ARRAY' THEN 'COVERAGE' WHEN 'DIAGNOSTICS_ARRAY' THEN 'DIAGNOSTIC'
                    ELSE CASE WHEN [p].[Role]='NODE' AND [j].[key] COLLATE Latin1_General_100_BIN2='attributes'
                        THEN 'ATTR_'+JSON_VALUE([p].[Value],'$.kind') ELSE [r].[ChildRole] END END,
                [j].[key],[j].[value],[j].[type]
            FROM #SsisPackageModelAnalysis_Tokens AS [p] CROSS APPLY OPENJSON([p].[Value]) AS [j]
            LEFT JOIN #SsisPackageModelAnalysis_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[j].[key] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([j].[key])
            WHERE [p].[Depth]=@Depth AND [p].[Type] IN (4,5);
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens WHERE [Depth]=@Depth+1 AND [Role] IN ('NODE','EDGE','COVERAGE','DIAGNOSTIC') AND [Type]<>5) THROW 50000,N'EXCHANGE_INVALID',1;
            IF (SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_Tokens)>1000000 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [p] JOIN #SsisPackageModelAnalysis_Tokens AS [c] ON [c].[ParentId]=[p].[TokenId]
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 GROUP BY [p].[TokenId],[c].[Name] COLLATE Latin1_General_100_BIN2,DATALENGTH([c].[Name]) HAVING COUNT_BIG(*)>1)
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [p] JOIN #SsisPackageModelAnalysis_Tokens AS [c] ON [c].[ParentId]=[p].[TokenId]
                LEFT JOIN #SsisPackageModelAnalysis_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 AND ([r].[Name] IS NULL OR CHARINDEX(CONVERT(varchar(1),[c].[Type]),[r].[Types])=0
                    OR [c].[Type]=1 AND [r].[MaxLength] IS NOT NULL AND DATALENGTH([c].[Value])/2>[r].[MaxLength]
                    OR [c].[Type]<>0 AND [r].[EnumJson] IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON([r].[EnumJson]) AS [v]
                        WHERE [v].[type]=[c].[Type] AND [v].[value] COLLATE Latin1_General_100_BIN2=[c].[Value] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([v].[value])=DATALENGTH([c].[Value]))))
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [p] JOIN #SsisPackageModelAnalysis_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Required]=1
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [c]
                    WHERE [c].[ParentId]=[p].[TokenId] AND [c].[Name] COLLATE Latin1_General_100_BIN2=[r].[Name] COLLATE Latin1_General_100_BIN2))
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [c] JOIN #SsisPackageModelAnalysis_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId]
                JOIN #SsisPackageModelAnalysis_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
                CROSS APPLY(SELECT COUNT_BIG(*) AS [N] FROM OPENJSON([c].[Value])) AS [a]
                WHERE [c].[Depth]=@Depth+1 AND [c].[Type]=4 AND ([a].[N]<COALESCE([r].[MinItems],0) OR [a].[N]>COALESCE([r].[MaxItems],2147483647)))
                THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            SET @Depth+=1;
        END;

        -- Zahlenlexeme werden exakt auf Ganzzahligkeit geprüft. Float-/Decimal-
        -- Rundung darf einen kleinen Bruchteil nicht in eine gültige ID-Zahl verwandeln.
        SET @ValidationStage='NUMBERS';
        CREATE TABLE #SsisPackageModelAnalysis_Numbers([TokenId] int NOT NULL PRIMARY KEY,[NumberValue] bigint NULL);
        ;WITH [n0] AS(
            SELECT [TokenId],[Value],CASE WHEN LEFT([Value],1)='-' THEN 1 ELSE 0 END AS [Negative],CHARINDEX('e',LOWER([Value])) AS [ExpAt]
            FROM #SsisPackageModelAnalysis_Tokens WHERE [Type]=2),
        [n1] AS(
            SELECT *,CASE WHEN [ExpAt]=0 THEN [Value] ELSE LEFT([Value],[ExpAt]-1) END AS [Mantissa],
                CASE WHEN [ExpAt]=0 THEN 0 ELSE TRY_CONVERT(int,SUBSTRING([Value],[ExpAt]+1,4000)) END AS [Exponent] FROM [n0]),
        [n2] AS(
            SELECT *,REPLACE(REPLACE([Mantissa],'-',''),'.','') AS [Digits],
                CASE WHEN CHARINDEX('.',[Mantissa])=0 THEN 0 ELSE LEN([Mantissa])-CHARINDEX('.',[Mantissa]) END AS [Fraction] FROM [n1]),
        [n3] AS(
            SELECT *,SUBSTRING([Digits],NULLIF(PATINDEX('%[^0]%',[Digits]),0),2147483647) AS [Significant],
                CONVERT(bigint,[Fraction])-CONVERT(bigint,[Exponent]) AS [Scale] FROM [n2])
        INSERT #SsisPackageModelAnalysis_Numbers
        SELECT [TokenId],CASE WHEN [Significant] IS NULL THEN 0
            WHEN [Scale] IS NOT NULL AND [Scale]<=PATINDEX('%[^0]%',REVERSE([Significant]))-1
                AND CONVERT(bigint,LEN([Significant]))-[Scale] BETWEEN 1 AND 10
            THEN TRY_CONVERT(bigint,CASE WHEN [Negative]=1 THEN '-' ELSE '' END+
                CASE WHEN [Scale]>=0 THEN LEFT([Significant],CONVERT(int,CONVERT(bigint,LEN([Significant]))-[Scale]))
                ELSE [Significant]+REPLICATE('0',CONVERT(int,CASE WHEN -[Scale]<=10 THEN -[Scale] ELSE 0 END)) END) END
        FROM [n3];
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [c] JOIN #SsisPackageModelAnalysis_Numbers AS [n] ON [n].[TokenId]=[c].[TokenId]
            JOIN #SsisPackageModelAnalysis_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId] JOIN #SsisPackageModelAnalysis_Rules AS [r]
                ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
            WHERE [n].[NumberValue] IS NULL OR [n].[NumberValue]<[r].[Minimum] OR [n].[NumberValue]>[r].[Maximum]) THROW 50000,N'EXCHANGE_INVALID',1;

        -- Die Musterklassen werden vom kanonischen Schema abgeleitet; keine
        -- zweite Liste fachlicher Felder oder erlaubter Enumerationswerte.
        SET @ValidationStage='PATTERNS';
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Tokens AS [c] JOIN #SsisPackageModelAnalysis_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId]
            JOIN #SsisPackageModelAnalysis_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
            WHERE [c].[Type]=1 AND (
                [r].[Pattern] IN ('HEX40','HEX64') AND (DATALENGTH([c].[Value])/2<>CASE WHEN [r].[Pattern]='HEX40' THEN 40 ELSE 64 END OR [c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9a-f]%')
                OR [r].[Pattern]='RULEID' AND ([c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Z0-9_]%' OR LEFT([c].[Value],1) COLLATE Latin1_General_100_BIN2 NOT LIKE '[A-Z]')
                OR [r].[Pattern] IN ('ID','EDGEID') AND NOT EXISTS(
                    SELECT 1 FROM (VALUES('pkg'),('exe'),('cmp'),('port'),('col'),('var'),('par'),('con'),('expr'),('edge')) AS [prefix]([P])
                    WHERE LEFT([c].[Value],LEN([prefix].[P])) COLLATE Latin1_General_100_BIN2=[prefix].[P] COLLATE Latin1_General_100_BIN2
                        AND SUBSTRING([c].[Value],LEN([prefix].[P])+1,1) COLLATE Latin1_General_100_BIN2 LIKE '[1-9]'
                        AND SUBSTRING([c].[Value],LEN([prefix].[P])+1,4000) COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'
                        AND ([r].[Pattern]='EDGEID' AND [prefix].[P]='edge' OR [r].[Pattern]='ID' AND [prefix].[P]<>'edge'))
                OR [r].[Pattern]='VERSION' AND (LEN([c].[Value])-LEN(REPLACE([c].[Value],'.',''))<>2 OR [c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9.]%'
                    OR EXISTS(SELECT 1 FROM STRING_SPLIT([c].[Value],'.') AS [v] WHERE [v].[value]='' OR LEN([v].[value])>1 AND LEFT([v].[value],1)='0')
                    OR LEFT([c].[Value],1)='.' OR RIGHT([c].[Value],1)='.' OR CHARINDEX('..',[c].[Value])>0)))
            THROW 50000,N'EXCHANGE_INVALID',1;

        SET @ValidationStage='REFERENCES';
        INSERT #SsisPackageModelAnalysis_Nodes
        SELECT CONVERT(int,[j].[key])+1,JSON_VALUE([j].[value],'$.id'),JSON_VALUE([j].[value],'$.kind'),JSON_VALUE([j].[value],'$.parentId'),JSON_VALUE([j].[value],'$.name'),JSON_QUERY([j].[value],'$.attributes')
        FROM OPENJSON(@PackageModelJson,'$.nodes') AS [j];
        INSERT #SsisPackageModelAnalysis_Edges
        SELECT CONVERT(int,[j].[key])+1,JSON_VALUE([j].[value],'$.id'),JSON_VALUE([j].[value],'$.kind'),JSON_VALUE([j].[value],'$.scopeId'),JSON_VALUE([j].[value],'$.fromId'),JSON_VALUE([j].[value],'$.toId'),
            JSON_VALUE([j].[value],'$.resolution'),JSON_VALUE([j].[value],'$.evidence'),JSON_VALUE([j].[value],'$.ruleId'),JSON_VALUE([j].[value],'$.mappingRole'),1
        FROM OPENJSON(@PackageModelJson,'$.edges') AS [j];
        INSERT #SsisPackageModelAnalysis_Coverage
        SELECT JSON_VALUE([value],'$.feature'),JSON_VALUE([value],'$.status'),JSON_VALUE([value],'$.reasonCode'),1 FROM OPENJSON(@PackageModelJson,'$.coverage');
        IF (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='PACKAGE' AND [NodeId]='pkg1' AND [ParentNodeId] IS NULL)<>1
            OR EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='PACKAGE' AND ([NodeId]<>'pkg1' OR [ParentNodeId] IS NOT NULL))
            OR EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes AS [n] LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [p] ON [p].[NodeId]=[n].[ParentNodeId]
                WHERE [n].[NodeKind]<>'PACKAGE' AND ([p].[NodeId] IS NULL OR NOT (
                    [n].[NodeKind]='EXECUTABLE' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE') OR [n].[NodeKind]='COMPONENT' AND [p].[NodeKind]='EXECUTABLE'
                    OR [n].[NodeKind]='PORT' AND [p].[NodeKind]='COMPONENT' OR [n].[NodeKind]='COLUMN' AND [p].[NodeKind]='PORT'
                    OR [n].[NodeKind]='VARIABLE' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE') OR [n].[NodeKind] IN ('PARAMETER','CONNECTION') AND [p].[NodeKind]='PACKAGE'
                    OR [n].[NodeKind]='EXPRESSION' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE','COMPONENT','PORT','COLUMN','VARIABLE','CONNECTION'))))
            OR EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes AS [n] JOIN (VALUES('PACKAGE','pkg'),('EXECUTABLE','exe'),('COMPONENT','cmp'),('PORT','port'),('COLUMN','col'),('VARIABLE','var'),('PARAMETER','par'),('CONNECTION','con'),('EXPRESSION','expr')) AS [k]([Kind],[Prefix]) ON [n].[NodeKind]=[k].[Kind]
                WHERE LEFT([n].[NodeId],LEN([k].[Prefix]))<>[k].[Prefix])
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        CREATE TABLE #SsisPackageModelAnalysis_Owners([NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[ScopeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [OwnerDepth] int NOT NULL,[ScopePath] varchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        INSERT #SsisPackageModelAnalysis_Owners VALUES('pkg1','pkg1',1,'/pkg1/');
        DECLARE @Added int=1;
        WHILE @Added>0
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
            INSERT #SsisPackageModelAnalysis_Owners
            SELECT [n].[NodeId],CASE WHEN [n].[NodeKind]='EXECUTABLE' THEN [n].[NodeId] ELSE [p].[ScopeId] END,[p].[OwnerDepth]+1,
                [p].[ScopePath]+CASE WHEN [n].[NodeKind]='EXECUTABLE' THEN [n].[NodeId]+'/' ELSE '' END
            FROM #SsisPackageModelAnalysis_Nodes AS [n] JOIN #SsisPackageModelAnalysis_Owners AS [p] ON [p].[NodeId]=[n].[ParentNodeId]
            WHERE NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Owners AS [o] WHERE [o].[NodeId]=[n].[NodeId]);
            SET @Added=@@ROWCOUNT;
            IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Owners WHERE [OwnerDepth]>128) THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
        END;
        IF (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Owners)<>(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes) THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Coverage WHERE [ReportedStatus]='COMPLETE' AND [ReasonCode] IS NOT NULL OR [ReportedStatus]<>'COMPLETE' AND [ReasonCode] IS NULL)
            THROW 50000,N'EXCHANGE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes AS [n] WHERE [n].[NodeKind]='PORT' AND JSON_VALUE([n].[AttributesJson],'$.synchronousInputPortId') IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes AS [p] WHERE [p].[NodeId]=JSON_VALUE([n].[AttributesJson],'$.synchronousInputPortId') AND [p].[ParentNodeId]=[n].[ParentNodeId]
                AND [p].[NodeKind]='PORT' AND JSON_VALUE([p].[AttributesJson],'$.direction')='INPUT' AND JSON_VALUE([n].[AttributesJson],'$.direction')='OUTPUT'))
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@PackageModelJson,'$.diagnostics') AS [d] WHERE JSON_VALUE([d].[value],'$.objectId') IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes AS [n] WHERE [n].[NodeId]=JSON_VALUE([d].[value],'$.objectId'))) THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges AS [e]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [f] ON [f].[NodeId]=[e].[FromNodeId] LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [t] ON [t].[NodeId]=[e].[ToNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [s] ON [s].[NodeId]=[e].[ScopeNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Owners AS [so] ON [so].[NodeId]=[s].[NodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Owners AS [fo] ON [fo].[NodeId]=[f].[NodeId] LEFT JOIN #SsisPackageModelAnalysis_Owners AS [to] ON [to].[NodeId]=[t].[NodeId]
            WHERE [s].[NodeId] IS NULL OR [s].[NodeKind] NOT IN ('PACKAGE','EXECUTABLE') OR [e].[FromNodeId] IS NULL AND [e].[ToNodeId] IS NULL
                OR [e].[FromNodeId] IS NOT NULL AND [f].[NodeId] IS NULL OR [e].[ToNodeId] IS NOT NULL AND [t].[NodeId] IS NULL
                OR [e].[Resolution]='RESOLVED' AND ([f].[NodeId] IS NULL OR [t].[NodeId] IS NULL)
                OR [e].[Evidence]='DECLARED' AND [e].[RuleId] IS NOT NULL OR [e].[Evidence]='DERIVED' AND [e].[RuleId] IS NULL
                OR [f].[NodeKind] IN ('VARIABLE','PARAMETER') AND CHARINDEX('/'+[f].[ParentNodeId]+'/',[so].[ScopePath])=0
                OR [e].[EdgeKind]='COLUMN_MAP' AND ([e].[MappingRole]='DATA_TRANSFER' AND (JSON_VALUE([f].[AttributesJson],'$.columnRole')<>'DATA' OR JSON_VALUE([t].[AttributesJson],'$.columnRole')<>'DATA')
                    OR [e].[MappingRole]='METADATA_REFERENCE' AND (JSON_VALUE([f].[AttributesJson],'$.columnRole')<>'DATA' OR JSON_VALUE([t].[AttributesJson],'$.columnRole')<>'EXTERNAL_METADATA'))
                OR [e].[EdgeKind]='COLUMN_MAP' AND COALESCE([e].[MappingRole],'') NOT IN ('DATA_TRANSFER','METADATA_REFERENCE') OR [e].[EdgeKind]<>'COLUMN_MAP' AND [e].[MappingRole] IS NOT NULL
                OR [f].[NodeId] IS NOT NULL AND NOT ([e].[EdgeKind]='CONTROL_FLOW' AND [f].[NodeKind]='EXECUTABLE' AND [f].[ParentNodeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='PIPELINE_PATH' AND [f].[NodeKind]='PORT' AND COALESCE(JSON_VALUE([f].[AttributesJson],'$.direction'),'')='OUTPUT' AND [fo].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='COLUMN_MAP' AND [f].[NodeKind]='COLUMN' AND [fo].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind] IN ('VALUE_DEPENDENCY','ROW_DEPENDENCY') AND [f].[NodeKind] IN ('COLUMN','VARIABLE','PARAMETER') AND ([f].[NodeKind]<>'COLUMN' OR [fo].[ScopeId]=[e].[ScopeNodeId])
                    OR [e].[EdgeKind]='EXPRESSION_REFERENCE' AND [f].[NodeKind] IN ('VARIABLE','PARAMETER'))
                OR [t].[NodeId] IS NOT NULL AND NOT ([e].[EdgeKind]='CONTROL_FLOW' AND [t].[NodeKind]='EXECUTABLE' AND [t].[ParentNodeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='PIPELINE_PATH' AND [t].[NodeKind]='PORT' AND COALESCE(JSON_VALUE([t].[AttributesJson],'$.direction'),'')='INPUT' AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind] IN ('COLUMN_MAP','VALUE_DEPENDENCY') AND [t].[NodeKind]='COLUMN' AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='ROW_DEPENDENCY' AND [t].[NodeKind] IN ('COLUMN','PORT') AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='EXPRESSION_REFERENCE' AND [t].[NodeKind]='EXPRESSION' AND [to].[ScopeId]=[e].[ScopeNodeId]))
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        SET @ValidationStage='PROFILES';
        IF JSON_VALUE(@PackageModelJson,'$.profiles.format')<>'1.0.0' THROW 50000,N'EXCHANGE_PROFILE_UNSUPPORTED',1;
        IF JSON_VALUE(@PackageModelJson,'$.profiles.components')<>'1.0.0' OR JSON_VALUE(@PackageModelJson,'$.profiles.lineage')<>'1.0.0'
        BEGIN
            SET @ProfileSupported=0; UPDATE #SsisPackageModelAnalysis_Coverage SET [IsProfileSupported]=0 WHERE [Feature] IN ('valueLineage','rowLineage','expressionReferences');
        END;
        UPDATE #SsisPackageModelAnalysis_Edges SET [IsInterpretable]=0 WHERE [Evidence]='DERIVED' AND (@ProfileSupported=0 OR NOT (
            [EdgeKind]='VALUE_DEPENDENCY' AND [RuleId] IN ('MAPPED_VALUE_INPUT','BOUND_EXPRESSION_INPUT') OR [EdgeKind]='ROW_DEPENDENCY' AND [RuleId] IN ('LOOKUP_ROW_SELECTION','SPLIT_ROW_SELECTION')));
        IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges WHERE [IsInterpretable]=0)
            INSERT #SsisPackageModelAnalysis_Warnings VALUES('EXCHANGE_PROFILE_UNSUPPORTED','INFO',N'Abgeleitete Beziehungen ohne unterstütztes Regelprofil bleiben uninterpretiert.');

        SET @ValidationStage='BINDING';
        DECLARE @PackageHash varchar(64)=JSON_VALUE(@PackageModelJson,'$.source.packageSha256');
        DECLARE @DeclaredLength int=(SELECT [n].[NumberValue] FROM #SsisPackageModelAnalysis_Tokens AS [c] JOIN #SsisPackageModelAnalysis_Numbers AS [n] ON [n].[TokenId]=[c].[TokenId]
            JOIN #SsisPackageModelAnalysis_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId] WHERE [p].[Role]='SOURCE' AND [c].[Name]='byteLength');
        IF @PackageBytes IS NOT NULL AND (DATALENGTH(@PackageBytes)<>@DeclaredLength OR CONVERT(varchar(64),HASHBYTES('SHA2_256',@PackageBytes),2) COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2)
            THROW 50000,N'EXCHANGE_SOURCE_MISMATCH',1;
        IF @LocalHandoverId IS NOT NULL
        BEGIN
            SET @ValidationStage='LOCAL_HANDOVER';
            DECLARE @Receipt nvarchar(3750),@ReceiptName sysname=N'SSIS_HANDOVER_'+LOWER(CONVERT(nvarchar(36),@LocalHandoverId));
            SELECT @Receipt=TRY_CONVERT(nvarchar(3750),[value]) FROM [sys].[extended_properties] WITH (READCOMMITTEDLOCK)
            WHERE [class]=1 AND [major_id]=@@PROCID AND [minor_id]=0 AND [name] COLLATE Latin1_General_100_BIN2=@ReceiptName COLLATE Latin1_General_100_BIN2;
            IF @PackageBytes IS NULL OR @Receipt IS NULL OR ISJSON(@Receipt)<>1 THROW 50000,N'EXCHANGE_HANDOVER_INVALID',1;
            CREATE TABLE #SsisPackageModelAnalysis_HandoverFields([FieldName] nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL,[FieldValue] nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,[JsonType] int NOT NULL);
            INSERT #SsisPackageModelAnalysis_HandoverFields SELECT [key],[value],[type] FROM OPENJSON(@Receipt);
            IF (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_HandoverFields)<>10 OR
                EXISTS(SELECT [FieldName] FROM #SsisPackageModelAnalysis_HandoverFields GROUP BY [FieldName] HAVING COUNT(*)<>1) OR
                EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_HandoverFields WHERE NOT EXISTS(SELECT 1 FROM (VALUES(N'contract'),(N'version'),(N'method'),(N'modelSha256'),(N'packageSha256'),(N'byteLength'),(N'buildSha256'),(N'sourceCommit'),(N'issuedUtc'),(N'expiresUtc')) AS [allowed]([FieldName])
                        WHERE [allowed].[FieldName] COLLATE Latin1_General_100_BIN2=#SsisPackageModelAnalysis_HandoverFields.[FieldName] AND DATALENGTH([allowed].[FieldName])=DATALENGTH(#SsisPackageModelAnalysis_HandoverFields.[FieldName])) OR
                    [JsonType]<>CASE WHEN [FieldName]='byteLength' THEN 2 ELSE 1 END OR [FieldValue] IS NULL)
                THROW 50000,N'EXCHANGE_HANDOVER_INVALID',1;
            DECLARE @Issued datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@Receipt,'$.issuedUtc'),127),@Expires datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@Receipt,'$.expiresUtc'),127);
            IF JSON_VALUE(@Receipt,'$.contract') COLLATE Latin1_General_100_BIN2<>'ssis-local-handover' OR DATALENGTH(JSON_VALUE(@Receipt,'$.contract'))<>38
                OR JSON_VALUE(@Receipt,'$.version') COLLATE Latin1_General_100_BIN2<>'1.0.0' OR DATALENGTH(JSON_VALUE(@Receipt,'$.version'))<>10
                OR JSON_VALUE(@Receipt,'$.method') COLLATE Latin1_General_100_BIN2<>'QUALIFIED_HOST_SNAPSHOT' OR DATALENGTH(JSON_VALUE(@Receipt,'$.method'))<>46
                OR @Issued IS NULL OR @Expires IS NULL OR @Issued>@Started OR @Expires<=@Started OR @Expires>DATEADD(hour,24,@Issued)
                OR DATALENGTH(JSON_VALUE(@Receipt,'$.modelSha256'))<>128 OR UPPER(JSON_VALUE(@Receipt,'$.modelSha256')) COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PackageModelJson)),2) COLLATE Latin1_General_100_BIN2
                OR DATALENGTH(JSON_VALUE(@Receipt,'$.packageSha256'))<>128 OR UPPER(JSON_VALUE(@Receipt,'$.packageSha256')) COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2
                OR TRY_CONVERT(int,JSON_VALUE(@Receipt,'$.byteLength')) IS NULL OR TRY_CONVERT(int,JSON_VALUE(@Receipt,'$.byteLength'))<>@DeclaredLength
                OR DATALENGTH(JSON_VALUE(@Receipt,'$.buildSha256'))<>128 OR UPPER(JSON_VALUE(@Receipt,'$.buildSha256')) COLLATE Latin1_General_100_BIN2<>UPPER(JSON_VALUE(@PackageModelJson,'$.producer.buildSha256')) COLLATE Latin1_General_100_BIN2
                OR DATALENGTH(JSON_VALUE(@Receipt,'$.sourceCommit'))<>80 OR UPPER(JSON_VALUE(@Receipt,'$.sourceCommit')) COLLATE Latin1_General_100_BIN2<>UPPER(JSON_VALUE(@PackageModelJson,'$.producer.sourceCommit')) COLLATE Latin1_General_100_BIN2
                THROW 50000,N'EXCHANGE_HANDOVER_INVALID',1;
            SET @ProducerTrust='VERIFIED_LOCAL';
        END;
        INSERT #SsisPackageModelAnalysis_Binding VALUES(@PackageHash,@DeclaredLength,CASE WHEN @PackageBytes IS NULL THEN 'DECLARED_ONLY' ELSE 'PACKAGE_BYTES_MATCH' END,@ProducerTrust,
            JSON_VALUE(@PackageModelJson,'$.producer.version'),JSON_VALUE(@PackageModelJson,'$.producer.sourceCommit'),JSON_VALUE(@PackageModelJson,'$.producer.buildSha256'));
        IF @ProducerTrust='UNVERIFIED' INSERT #SsisPackageModelAnalysis_Findings VALUES('SSIS_MODEL_UNVERIFIED_PRODUCER','INFO','IMPORTED_STATIC',NULL,N'Das Modell enthält statische Producerbehauptungen; die angegebenen Digests authentifizieren den Erzeuger nicht.');
        INSERT #SsisPackageModelAnalysis_Findings
        SELECT 'SSIS_MODEL_COVERAGE_LIMITED','INFO','IMPORTED_STATIC',[Feature],N'Die berichtete Abdeckung oder das unterstützte Profil reicht für eine uneingeschränkte Auswertung dieses Features nicht aus.'
        FROM #SsisPackageModelAnalysis_Coverage WHERE [ReportedStatus]<>'COMPLETE' OR [IsProfileSupported]=0;
        IF @IncludeObjectRules=1
        BEGIN
            SET @ValidationStage='OBJECT_RULES';
            CREATE TABLE #SsisPackageModelAnalysis_RuleEvidence(
                [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Finding] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
            INSERT #SsisPackageModelAnalysis_RuleEvidence
            SELECT 'SSIS_EXECUTABLE_DISABLED','inventory',[NodeId],NULL,[ParentNodeId],N'Das Modell deklariert das Executable als deaktiviert; eine tatsächliche Ausführung wird nicht behauptet.'
            FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='EXECUTABLE' AND JSON_VALUE([AttributesJson],'$.isDisabled')='true';
            INSERT #SsisPackageModelAnalysis_RuleEvidence
            SELECT DISTINCT 'SSIS_COMPONENT_PROFILE_UNKNOWN','inventory',[n].[NodeId],NULL,[n].[ParentNodeId],N'Der Producer meldet für diese Komponente UNKNOWN_COMPONENT; komponentenabhängige Aussagen sind begrenzt.'
            FROM OPENJSON(@PackageModelJson,'$.diagnostics') WITH([Code] varchar(40) '$.code',[ObjectId] varchar(128) '$.objectId') AS [d]
            JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId]=[d].[ObjectId] COLLATE SQL_Latin1_General_CP1_CS_AS
            WHERE [d].[Code] COLLATE Latin1_General_100_BIN2='UNKNOWN_COMPONENT' AND [n].[NodeKind]='COMPONENT';
            INSERT #SsisPackageModelAnalysis_RuleEvidence
            SELECT 'SSIS_EDGE_UNRESOLVED',CASE [EdgeKind] WHEN 'CONTROL_FLOW' THEN 'controlFlow' WHEN 'PIPELINE_PATH' THEN 'pipelineGraph'
                WHEN 'COLUMN_MAP' THEN 'directColumnMapping' WHEN 'VALUE_DEPENDENCY' THEN 'valueLineage' WHEN 'ROW_DEPENDENCY' THEN 'rowLineage' ELSE 'expressionReferences' END,
                NULL,[EdgeId],[ScopeNodeId],N'Die gelieferte Beziehung ist UNRESOLVED; fehlende Endpunkte werden nicht ergänzt.'
            FROM #SsisPackageModelAnalysis_Edges WHERE [Resolution]='UNRESOLVED';
            INSERT #SsisPackageModelAnalysis_RuleEvidence
            SELECT 'SSIS_COLUMN_MULTIPLE_DIRECT_SOURCES','directColumnMapping',[ToNodeId],NULL,[ScopeNodeId],N'Das Modell enthält mehrere unterschiedliche direkte DATA_TRANSFER-Quellen für diese Spalte; dies ist kein Nachweis eines Laufzeitfehlers.'
            FROM #SsisPackageModelAnalysis_Edges WHERE [EdgeKind]='COLUMN_MAP' AND [MappingRole]='DATA_TRANSFER' AND [Resolution]='RESOLVED' AND [IsInterpretable]=1
            GROUP BY [ScopeNodeId],[ToNodeId] HAVING COUNT(DISTINCT [FromNodeId])>1;
            IF JSON_VALUE(@PackageModelJson,'$.profiles.components')='1.0.0' AND (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Coverage WHERE [Feature] IN ('inventory','pipelineGraph') AND [ReportedStatus]='COMPLETE' AND [IsProfileSupported]=1)=2
            INSERT #SsisPackageModelAnalysis_RuleEvidence
            SELECT 'SSIS_PORT_NO_DECLARED_PATH','pipelineGraph',[n].[NodeId],NULL,[o].[ScopeId],N'Für diesen regulären Port ist bei vollständig gemeldeter Inventar-/Graphabdeckung keine passende deklarierte Pipelinekante vorhanden; Erreichbarkeit und Zeilenfluss bleiben unbelegt.'
            FROM #SsisPackageModelAnalysis_Nodes AS [n] JOIN #SsisPackageModelAnalysis_Owners AS [o] ON [o].[NodeId]=[n].[NodeId]
            WHERE [n].[NodeKind]='PORT' AND JSON_VALUE([n].[AttributesJson],'$.portRole')='REGULAR'
                AND JSON_VALUE([n].[AttributesJson],'$.direction') IN ('INPUT','OUTPUT')
                AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges AS [uncertain] WHERE [uncertain].[EdgeKind]='PIPELINE_PATH' AND [uncertain].[ScopeNodeId]=[o].[ScopeId] AND [uncertain].[Resolution]<>'RESOLVED')
                AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges AS [e] WHERE [e].[EdgeKind]='PIPELINE_PATH' AND [e].[ScopeNodeId]=[o].[ScopeId]
                    AND (JSON_VALUE([n].[AttributesJson],'$.direction')='INPUT' AND [e].[ToNodeId]=[n].[NodeId] OR JSON_VALUE([n].[AttributesJson],'$.direction')='OUTPUT' AND [e].[FromNodeId]=[n].[NodeId]));
            INSERT #SsisPackageModelAnalysis_ObjectFindings
            SELECT [r].[RuleId],'INFO','IMPORTED_STATIC',[r].[Feature],[r].[NodeId],[r].[EdgeId],[r].[ScopeNodeId],[b].[PackageSha256],[b].[BindingStatus],[b].[ProducerTrust],[r].[Finding]
            FROM #SsisPackageModelAnalysis_RuleEvidence AS [r] CROSS JOIN #SsisPackageModelAnalysis_Binding AS [b];
        END;
        IF @IncludePackageViews=1
        BEGIN
            SET @ValidationStage='PACKAGE_VIEWS';
            CREATE INDEX [IX_SsisPackageModelAnalysis_NodeOwner] ON #SsisPackageModelAnalysis_Nodes([ParentNodeId],[NodeKind]);
            CREATE INDEX [IX_SsisPackageModelAnalysis_EdgeScope] ON #SsisPackageModelAnalysis_Edges([ScopeNodeId],[EdgeKind]);
            CREATE TABLE #SsisPackageModelAnalysis_ColumnLengths([NodeOrdinal] int NOT NULL PRIMARY KEY,[DeclaredLength] int NOT NULL);
            INSERT #SsisPackageModelAnalysis_ColumnLengths
            SELECT CONVERT(int,[node].[Name])+1,CONVERT(int,[number].[NumberValue])
            FROM #SsisPackageModelAnalysis_Numbers AS [number]
            JOIN #SsisPackageModelAnalysis_Tokens AS [leaf] ON [leaf].[TokenId]=[number].[TokenId]
            JOIN #SsisPackageModelAnalysis_Tokens AS [attributes] ON [attributes].[TokenId]=[leaf].[ParentId]
            JOIN #SsisPackageModelAnalysis_Tokens AS [node] ON [node].[TokenId]=[attributes].[ParentId]
            WHERE [attributes].[Role]='ATTR_COLUMN' AND [leaf].[Name]='length';
            -- Vollständiger validierter Graph vor Ausgabekürzung; keine neue Komponenten- oder Lineagesemantik.
            INSERT #SsisPackageModelAnalysis_Executables
            SELECT [n].[NodeOrdinal],[n].[NodeId],[n].[ParentNodeId],[n].[NodeName],[o].[OwnerDepth],JSON_VALUE([n].[AttributesJson],'$.executableType'),
                CASE JSON_VALUE([n].[AttributesJson],'$.isDisabled') WHEN 'true' THEN 1 WHEN 'false' THEN 0 END,
                CASE JSON_VALUE([n].[AttributesJson],'$.isEventHandler') WHEN 'true' THEN 1 WHEN 'false' THEN 0 END,
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes AS [c] WHERE [c].[ParentNodeId]=[n].[NodeId] AND [c].[NodeKind]='COMPONENT')
            FROM #SsisPackageModelAnalysis_Nodes AS [n] JOIN #SsisPackageModelAnalysis_Owners AS [o] ON [o].[NodeId]=[n].[NodeId]
            WHERE [n].[NodeKind]='EXECUTABLE';
            INSERT #SsisPackageModelAnalysis_Components
            SELECT [c].[NodeOrdinal],[c].[NodeId],[c].[ParentNodeId],[c].[NodeName],JSON_VALUE([c].[AttributesJson],'$.componentClassId'),
                [p].[Inputs],[p].[Outputs],[p].[Unknowns],[v].[DataColumns],[v].[MetadataColumns]
            FROM #SsisPackageModelAnalysis_Nodes AS [c]
            CROSS APPLY(SELECT COUNT(CASE WHEN JSON_VALUE([x].[AttributesJson],'$.direction')='INPUT' THEN 1 END) AS [Inputs],
                COUNT(CASE WHEN JSON_VALUE([x].[AttributesJson],'$.direction')='OUTPUT' THEN 1 END) AS [Outputs],
                COUNT(CASE WHEN JSON_VALUE([x].[AttributesJson],'$.direction') IS NULL THEN 1 END) AS [Unknowns]
                FROM #SsisPackageModelAnalysis_Nodes AS [x] WHERE [x].[ParentNodeId]=[c].[NodeId] AND [x].[NodeKind]='PORT') AS [p]
            CROSS APPLY(SELECT COUNT(CASE WHEN JSON_VALUE([x].[AttributesJson],'$.columnRole')='DATA' THEN 1 END) AS [DataColumns],
                COUNT(CASE WHEN JSON_VALUE([x].[AttributesJson],'$.columnRole')='EXTERNAL_METADATA' THEN 1 END) AS [MetadataColumns]
                FROM #SsisPackageModelAnalysis_Nodes AS [x] JOIN #SsisPackageModelAnalysis_Nodes AS [p] ON [p].[NodeId]=[x].[ParentNodeId]
                WHERE [p].[ParentNodeId]=[c].[NodeId] AND [p].[NodeKind]='PORT' AND [x].[NodeKind]='COLUMN') AS [v]
            WHERE [c].[NodeKind]='COMPONENT';
            INSERT #SsisPackageModelAnalysis_DataFlows
            SELECT [n].[NodeOrdinal],[n].[NodeId],[n].[NodeName],
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Components AS [c] WHERE [c].[ScopeNodeId]=[n].[NodeId]),
                COALESCE((SELECT SUM([c].[InputPortCount]+[c].[OutputPortCount]+[c].[UnknownDirectionPortCount]) FROM #SsisPackageModelAnalysis_Components AS [c] WHERE [c].[ScopeNodeId]=[n].[NodeId]),0),
                COALESCE((SELECT SUM([c].[DataColumnCount]) FROM #SsisPackageModelAnalysis_Components AS [c] WHERE [c].[ScopeNodeId]=[n].[NodeId]),0),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges AS [e] WHERE [e].[ScopeNodeId]=[n].[NodeId] AND [e].[EdgeKind]='PIPELINE_PATH'),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges AS [e] WHERE [e].[ScopeNodeId]=[n].[NodeId] AND [e].[EdgeKind] IN ('PIPELINE_PATH','COLUMN_MAP','VALUE_DEPENDENCY','ROW_DEPENDENCY') AND [e].[Resolution]='UNRESOLVED')
            FROM #SsisPackageModelAnalysis_Nodes AS [n] WHERE [n].[NodeKind]='EXECUTABLE' AND
                (EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Components AS [c] WHERE [c].[ScopeNodeId]=[n].[NodeId]) OR
                 EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges AS [e] WHERE [e].[ScopeNodeId]=[n].[NodeId] AND [e].[EdgeKind] IN ('PIPELINE_PATH','COLUMN_MAP','VALUE_DEPENDENCY','ROW_DEPENDENCY')));
            INSERT #SsisPackageModelAnalysis_ColumnRelations
            SELECT [e].[EdgeOrdinal],[e].[EdgeId],[e].[EdgeKind],[a].[NodeId],[a].[NodeKind],[a].[NodeName],[e].[ScopeNodeId],
                CASE WHEN [a].[NodeKind]='COLUMN' THEN [a].[NodeId] END,CASE WHEN [a].[NodeKind]='COLUMN' THEN [ap].[ParentNodeId] END,CASE WHEN [a].[NodeKind]='COLUMN' THEN [a].[NodeName] END,
                CASE WHEN [a].[NodeKind]='COLUMN' THEN JSON_VALUE([a].[AttributesJson],'$.typeCode') END,[al].[DeclaredLength],
                [b].[NodeId],[bp].[ParentNodeId],[b].[NodeName],JSON_VALUE([b].[AttributesJson],'$.typeCode'),[bl].[DeclaredLength],
                [e].[Resolution],[e].[Evidence],[e].[RuleId],[e].[MappingRole],[e].[IsInterpretable]
            FROM #SsisPackageModelAnalysis_Edges AS [e]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [a] ON [a].[NodeId]=[e].[FromNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [ap] ON [ap].[NodeId]=[a].[ParentNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [b] ON [b].[NodeId]=[e].[ToNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [bp] ON [bp].[NodeId]=[b].[ParentNodeId]
            LEFT JOIN #SsisPackageModelAnalysis_ColumnLengths AS [al] ON [al].[NodeOrdinal]=[a].[NodeOrdinal]
            LEFT JOIN #SsisPackageModelAnalysis_ColumnLengths AS [bl] ON [bl].[NodeOrdinal]=[b].[NodeOrdinal]
            WHERE [e].[EdgeKind] IN ('COLUMN_MAP','VALUE_DEPENDENCY');
            INSERT #SsisPackageModelAnalysis_PackageOverview
            SELECT [n].[NodeId],[n].[NodeName],
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Executables),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_DataFlows),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Components),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='PORT'),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='COLUMN'),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='VARIABLE'),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='PARAMETER'),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind]='CONNECTION'),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges WHERE [EdgeKind]='PIPELINE_PATH'),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_ColumnRelations),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges WHERE [Resolution]='UNRESOLVED'),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Coverage WHERE [ReportedStatus]<>'COMPLETE' OR [IsProfileSupported]=0),
                (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges),@ProducerTrust
            FROM #SsisPackageModelAnalysis_Nodes AS [n] WHERE [n].[NodeKind]='PACKAGE';
        END;
        IF @IncludeSqlMetadata=1
        BEGIN
            SET @ValidationStage='SQL_METADATA';
            DECLARE @SqlMetadataStatus varchar(40)='SQL_METADATA_BINDINGS_INVALID',@SqlMetadataError int=NULL;
            BEGIN TRY
                -- Dieser flache Zuordnungsvertrag bindet explizite Namen an dieses
                -- Paket. Er liest keine DTSX-Eigenschaften oder Connection Strings.
                IF @SqlMetadataBindingsJson IS NULL OR DATALENGTH(@SqlMetadataBindingsJson)>16777216 OR ISJSON(@SqlMetadataBindingsJson)<>1
                    THROW 50000,N'SQL_METADATA_BINDINGS_INVALID',1;
                IF (SELECT COUNT(*) FROM OPENJSON(@SqlMetadataBindingsJson))<>4
                    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@SqlMetadataBindingsJson) GROUP BY [key] COLLATE Latin1_General_100_BIN2,DATALENGTH([key]) HAVING COUNT(*)<>1)
                    OR EXISTS(SELECT 1 FROM OPENJSON(@SqlMetadataBindingsJson) WHERE NOT([type]=1 AND [key] COLLATE Latin1_General_100_BIN2 IN ('contract','version','packageSha256') OR [type]=4 AND [key] COLLATE Latin1_General_100_BIN2='bindings'))
                    OR COALESCE(JSON_VALUE(@SqlMetadataBindingsJson,'$.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-sql-metadata-bindings' OR DATALENGTH(JSON_VALUE(@SqlMetadataBindingsJson,'$.contract'))<>DATALENGTH(N'ssis-sql-metadata-bindings')
                    OR COALESCE(JSON_VALUE(@SqlMetadataBindingsJson,'$.version'),'') COLLATE Latin1_General_100_BIN2<>'1.0.0' OR DATALENGTH(JSON_VALUE(@SqlMetadataBindingsJson,'$.version'))<>10
                    OR COALESCE(UPPER(JSON_VALUE(@SqlMetadataBindingsJson,'$.packageSha256')),'') COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2 OR DATALENGTH(JSON_VALUE(@SqlMetadataBindingsJson,'$.packageSha256'))<>128
                    OR JSON_QUERY(@SqlMetadataBindingsJson,'$.bindings') IS NULL OR (SELECT COUNT(*) FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings')) NOT BETWEEN 1 AND 1000
                    OR EXISTS(SELECT 1 FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') WHERE [type]<>5)
                    THROW 50000,N'SQL_METADATA_BINDINGS_INVALID',1;
                IF EXISTS(SELECT 1 FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') AS [b] WHERE (SELECT COUNT(*) FROM OPENJSON([b].[value]))<>7)
                    OR EXISTS(SELECT [b].[key],[j].[key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') AS [b] CROSS APPLY OPENJSON([b].[value]) AS [j] GROUP BY [b].[key],[j].[key] COLLATE Latin1_General_100_BIN2,DATALENGTH([j].[key]) HAVING COUNT(*)<>1)
                    OR EXISTS(SELECT 1 FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') AS [b] CROSS APPLY OPENJSON([b].[value]) AS [j]
                        WHERE DATALENGTH([j].[key])<>DATALENGTH(RTRIM([j].[key])) OR NOT([j].[key] COLLATE Latin1_General_100_BIN2 IN ('bindingId','nodeId','databaseName','schemaName','objectName','columnName') AND [j].[type]=1 OR [j].[key] COLLATE Latin1_General_100_BIN2='keySetId' AND [j].[type] IN (0,1))
                            OR [j].[type]=1 AND (DATALENGTH([j].[value])=0 OR [j].[key] COLLATE Latin1_General_100_BIN2 IN ('bindingId','keySetId') AND (DATALENGTH([j].[value])>128 OR [j].[value] COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9_.:-]%')
                                OR [j].[key] COLLATE Latin1_General_100_BIN2 IN ('databaseName','schemaName','objectName','columnName','nodeId') AND DATALENGTH([j].[value])>256))
                    THROW 50000,N'SQL_METADATA_BINDINGS_INVALID',1;
                IF EXISTS(SELECT 1 FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') WITH([NodeId] nvarchar(128) '$.nodeId') AS [j]
                    LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId] COLLATE Latin1_General_100_BIN2=[j].[NodeId] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([n].[NodeId])*2=DATALENGTH([j].[NodeId]) AND [n].[NodeKind]='COLUMN' WHERE [n].[NodeId] IS NULL)
                    THROW 50000,N'SQL_METADATA_COLUMN_REFERENCE_INVALID',1;
                INSERT #SsisPackageModelAnalysis_SqlMetadata
                SELECT CONVERT(int,[b].[key]),[j].[BindingId],[j].[NodeId],[j].[DatabaseName],[j].[SchemaName],[j].[ObjectName],[j].[ColumnName],[j].[KeySetId],NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
                    JSON_VALUE([n].[AttributesJson],'$.typeCode'),CASE JSON_VALUE([n].[AttributesJson],'$.isNullable') WHEN 'true' THEN 1 WHEN 'false' THEN 0 END,
                    'UNKNOWN',CASE WHEN [j].[KeySetId] IS NULL THEN 'NOT_REQUESTED' ELSE 'KEYSET_INCOMPLETE' END,'NOT_QUALIFIED','SQL_DATABASE_NOT_VISIBLE','CALLER_EXPLICIT',@PackageHash,@ProducerTrust,'LOCAL_CATALOG_METADATA',NULL,NULL
                FROM OPENJSON(@SqlMetadataBindingsJson,'$.bindings') AS [b] CROSS APPLY OPENJSON([b].[value]) WITH([BindingId] varchar(64) '$.bindingId',[NodeId] varchar(128) '$.nodeId',[DatabaseName] nvarchar(128) '$.databaseName',[SchemaName] nvarchar(128) '$.schemaName',[ObjectName] nvarchar(128) '$.objectName',[ColumnName] nvarchar(128) '$.columnName',[KeySetId] varchar(64) '$.keySetId') AS [j]
                JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId]=[j].[NodeId];
                -- Derselbe Schlüsselsatz darf weder verschiedene Objekte noch
                -- doppelte SQL-Spalten enthalten. Namen werden ordinal verglichen.
                IF EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_SqlMetadata AS [a] JOIN #SsisPackageModelAnalysis_SqlMetadata AS [b] ON [a].[KeySetId]=[b].[KeySetId]
                    WHERE [a].[DatabaseName] COLLATE Latin1_General_100_BIN2<>[b].[DatabaseName] COLLATE Latin1_General_100_BIN2 OR DATALENGTH([a].[DatabaseName])<>DATALENGTH([b].[DatabaseName])
                        OR [a].[SchemaName] COLLATE Latin1_General_100_BIN2<>[b].[SchemaName] COLLATE Latin1_General_100_BIN2 OR DATALENGTH([a].[SchemaName])<>DATALENGTH([b].[SchemaName])
                        OR [a].[ObjectName] COLLATE Latin1_General_100_BIN2<>[b].[ObjectName] COLLATE Latin1_General_100_BIN2 OR DATALENGTH([a].[ObjectName])<>DATALENGTH([b].[ObjectName]))
                    OR EXISTS(SELECT [KeySetId],[ColumnName] COLLATE Latin1_General_100_BIN2 FROM #SsisPackageModelAnalysis_SqlMetadata WHERE [KeySetId] IS NOT NULL GROUP BY [KeySetId],[ColumnName] COLLATE Latin1_General_100_BIN2,DATALENGTH([ColumnName]) HAVING COUNT(*)>1)
                    THROW 50000,N'SQL_METADATA_KEYSET_INVALID',1;
                DECLARE @MetadataDb sysname,@MetadataDatabaseId int,@MetadataSql nvarchar(max),@MetadataRows bigint;
                DECLARE [MetadataDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] COLLATE Latin1_General_100_BIN2 FROM #SsisPackageModelAnalysis_SqlMetadata GROUP BY [DatabaseName] COLLATE Latin1_General_100_BIN2,DATALENGTH([DatabaseName]);
                OPEN [MetadataDatabases];FETCH NEXT FROM [MetadataDatabases] INTO @MetadataDb;
                WHILE @@FETCH_STATUS=0
                BEGIN
                    IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
                    SET @MetadataDatabaseId=NULL;
                    SELECT @MetadataDatabaseId=[database_id] FROM [sys].[databases] WITH (NOLOCK) WHERE [name] COLLATE Latin1_General_100_BIN2=@MetadataDb COLLATE Latin1_General_100_BIN2 AND DATALENGTH([name])=DATALENGTH(@MetadataDb) AND [state]=0;
                    BEGIN TRY
                        IF @MetadataDatabaseId IS NOT NULL
                        BEGIN
                            -- Ausschließlich der gegen sys.databases geprüfte Name
                            -- wird quotiert. Alle Objekt-/Spaltennamen bleiben Daten.
                            SET @MetadataSql=N'USE '+QUOTENAME(@MetadataDb)+N';
UPDATE [b] SET [DatabaseId]=DB_ID(),[ObjectId]=[o].[object_id],[ColumnId]=[c].[column_id],[SqlObjectType]=[o].[type],[SqlTypeSchema]=[ts].[name],[SqlTypeName]=[t].[name],[SystemTypeId]=[c].[system_type_id],
 [MaxLengthBytes]=[c].[max_length],[Precision]=[c].[precision],[Scale]=[c].[scale],[SqlCollation]=[c].[collation_name],[IsNullable]=[c].[is_nullable],[IsComputed]=[c].[is_computed],[IsIdentity]=[c].[is_identity],
 [NullableAgreement]=CASE WHEN [c].[column_id] IS NULL OR [b].[ModelIsNullable] IS NULL THEN ''UNKNOWN'' WHEN [b].[ModelIsNullable]=[c].[is_nullable] THEN ''AGREES'' ELSE ''DIFFERS'' END,
 [StatusCode]=CASE WHEN [o].[object_id] IS NULL THEN ''SQL_OBJECT_NOT_VISIBLE'' WHEN [c].[column_id] IS NULL THEN ''SQL_COLUMN_NOT_VISIBLE'' ELSE ''SQL_COLUMN_OBSERVED'' END,[ObservedUtc]=SYSUTCDATETIME()
FROM #SsisPackageModelAnalysis_SqlMetadata AS [b]
LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[name] COLLATE Latin1_General_100_BIN2=[b].[SchemaName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([s].[name])=DATALENGTH([b].[SchemaName])
LEFT JOIN [sys].[objects] AS [o] WITH (NOLOCK) ON [o].[schema_id]=[s].[schema_id] AND [o].[name] COLLATE Latin1_General_100_BIN2=[b].[ObjectName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[name])=DATALENGTH([b].[ObjectName]) AND [o].[type] IN (''U'',''V'')
LEFT JOIN [sys].[columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id] AND [c].[name] COLLATE Latin1_General_100_BIN2=[b].[ColumnName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([c].[name])=DATALENGTH([b].[ColumnName])
LEFT JOIN [sys].[types] AS [t] WITH (NOLOCK) ON [t].[user_type_id]=[c].[user_type_id]
LEFT JOIN [sys].[schemas] AS [ts] WITH (NOLOCK) ON [ts].[schema_id]=[t].[schema_id]
WHERE [b].[DatabaseName] COLLATE Latin1_General_100_BIN2=@Db COLLATE Latin1_General_100_BIN2 AND DATALENGTH([b].[DatabaseName])=DATALENGTH(@Db);
UPDATE [b] SET [UniqueKeyStatus]=CASE WHEN EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_SqlMetadata AS [k] WHERE [k].[KeySetId]=[b].[KeySetId] AND [k].[StatusCode]<>''SQL_COLUMN_OBSERVED'') THEN ''KEYSET_INCOMPLETE''
 WHEN EXISTS(SELECT 1 FROM [sys].[indexes] AS [i] WITH (NOLOCK) WHERE [i].[object_id]=[b].[ObjectId] AND [i].[is_unique]=1 AND [i].[is_disabled]=0 AND [i].[is_hypothetical]=0 AND [i].[has_filter]=0
  AND (SELECT COUNT(*) FROM [sys].[index_columns] AS [ic] WITH (NOLOCK) WHERE [ic].[object_id]=[i].[object_id] AND [ic].[index_id]=[i].[index_id] AND [ic].[key_ordinal]>0)=(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_SqlMetadata AS [k] WHERE [k].[KeySetId]=[b].[KeySetId])
  AND NOT EXISTS(SELECT 1 FROM [sys].[index_columns] AS [ic] WITH (NOLOCK) WHERE [ic].[object_id]=[i].[object_id] AND [ic].[index_id]=[i].[index_id] AND [ic].[key_ordinal]>0 AND NOT EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_SqlMetadata AS [k] WHERE [k].[KeySetId]=[b].[KeySetId] AND [k].[ColumnId]=[ic].[column_id]))) THEN ''UNIQUE_INDEX_OBSERVED'' ELSE ''NO_VISIBLE_UNFILTERED_UNIQUE_INDEX'' END
FROM #SsisPackageModelAnalysis_SqlMetadata AS [b] WHERE [b].[KeySetId] IS NOT NULL AND [b].[DatabaseName] COLLATE Latin1_General_100_BIN2=@Db COLLATE Latin1_General_100_BIN2 AND DATALENGTH([b].[DatabaseName])=DATALENGTH(@Db);';
                            EXEC [sys].[sp_executesql] @MetadataSql,N'@Db sysname',@Db=@MetadataDb;
                        END;
                        SELECT @MetadataRows=COUNT_BIG(*) FROM #SsisPackageModelAnalysis_SqlMetadata WHERE [DatabaseName] COLLATE Latin1_General_100_BIN2=@MetadataDb COLLATE Latin1_General_100_BIN2 AND DATALENGTH([DatabaseName])=DATALENGTH(@MetadataDb) AND [StatusCode]='SQL_COLUMN_OBSERVED';
                        INSERT #SsisPackageModelAnalysis_SourceStatus VALUES(N'SQL-Metadaten: '+@MetadataDb,CASE WHEN @MetadataDatabaseId IS NULL THEN 'SQL_DATABASE_NOT_VISIBLE' ELSE 'AVAILABLE_LIMITED' END,1,@MetadataRows,N'Sichtbare lokale Katalogmetadaten; explizite Callerbindung. Fehlende Sichtbarkeit beweist keine Objektabwesenheit oder Typkompatibilität.');
                    END TRY
                    BEGIN CATCH
                        UPDATE #SsisPackageModelAnalysis_SqlMetadata SET [DatabaseId]=NULL,[ObjectId]=NULL,[ColumnId]=NULL,[SqlObjectType]=NULL,[SqlTypeSchema]=NULL,[SqlTypeName]=NULL,[SystemTypeId]=NULL,[MaxLengthBytes]=NULL,[Precision]=NULL,[Scale]=NULL,[SqlCollation]=NULL,[IsNullable]=NULL,[IsComputed]=NULL,[IsIdentity]=NULL,[NullableAgreement]='UNKNOWN',[UniqueKeyStatus]=CASE WHEN [KeySetId] IS NULL THEN 'NOT_REQUESTED' ELSE 'KEYSET_INCOMPLETE' END,[StatusCode]='SQL_SOURCE_FAILED',[ObservedUtc]=NULL,[ErrorNumber]=ERROR_NUMBER()
                        WHERE [DatabaseName] COLLATE Latin1_General_100_BIN2=@MetadataDb COLLATE Latin1_General_100_BIN2 AND DATALENGTH([DatabaseName])=DATALENGTH(@MetadataDb);
                        INSERT #SsisPackageModelAnalysis_SourceStatus VALUES(N'SQL-Metadaten: '+@MetadataDb,'SQL_SOURCE_FAILED',1,0,N'Der isolierte Katalogzugriff ist fehlgeschlagen; Fehlernummer '+CONVERT(nvarchar(12),ERROR_NUMBER())+N'.');
                    END CATCH;
                    FETCH NEXT FROM [MetadataDatabases] INTO @MetadataDb;
                END;
                CLOSE [MetadataDatabases];DEALLOCATE [MetadataDatabases];
                SET @SqlMetadataStatus='AVAILABLE_LIMITED';
            END TRY
            BEGIN CATCH
                IF CURSOR_STATUS('local','MetadataDatabases')>=0 CLOSE [MetadataDatabases];
                IF CURSOR_STATUS('local','MetadataDatabases')>-3 DEALLOCATE [MetadataDatabases];
                SET @SqlMetadataError=ERROR_NUMBER();DELETE #SsisPackageModelAnalysis_SqlMetadata;
                INSERT #SsisPackageModelAnalysis_SourceStatus VALUES(N'SQL-Metadatenzuordnung',@SqlMetadataStatus,1,0,N'Die optionale paketgebundene Zuordnung ist ungültig oder unvollständig; keine SQL-Metadatenbewertung.');
                INSERT #SsisPackageModelAnalysis_Warnings VALUES(@SqlMetadataStatus,'INFO',N'Der optionale Metadatenpfad ist nicht qualifiziert; das statische Modell bleibt getrennt nutzbar.');
            END CATCH;
        END;
        IF @IncludeExecutionCorrelation=1
        BEGIN
            SET @ValidationStage='EXECUTION_CAPTURE';
            DECLARE @RuntimeStatus varchar(40)='RUNTIME_BINDING_UNPROVEN',@RuntimeReason varchar(64)=NULL,@RuntimeError int=NULL,@RootQualified bit=0;
            DECLARE @CatalogGuid uniqueidentifier=NULL,@RuntimeSourceBinding varchar(64)=NULL,@RuntimeProjectId bigint=NULL,@RuntimeProjectLsn bigint=NULL,@RuntimeFile nvarchar(260)=NULL,@RuntimeCreated datetimeoffset(7)=NULL;
            DECLARE @RuntimeLoggingLevel int=NULL,@RuntimeMethod varchar(64)=NULL;
            DECLARE @RuntimeExecutionStatus int=NULL,@RuntimeStart datetimeoffset(7)=NULL,@RuntimeEnd datetimeoffset(7)=NULL,@CaptureStart datetime2(7)=NULL,@CaptureEnd datetime2(7)=NULL;
            BEGIN TRY
                IF @ProducerTrust<>'VERIFIED_LOCAL' THROW 50000,N'MODEL_HANDOVER_UNVERIFIED',1;
                IF @ExecutionSnapshotJson IS NULL OR @RuntimeHandoverId IS NULL THROW 50000,N'QUALIFIED_CAPTURE_MISSING',1;
                IF DATALENGTH(@ExecutionSnapshotJson)>16777216 OR ISJSON(@ExecutionSnapshotJson)<>1 THROW 50000,N'RUNTIME_CAPTURE_INVALID',1;
                DECLARE @RuntimeReceipt nvarchar(3750),@RuntimeName sysname=N'SSIS_RUNTIME_'+LOWER(CONVERT(nvarchar(36),@RuntimeHandoverId));
                SELECT @RuntimeReceipt=TRY_CONVERT(nvarchar(3750),[value]) FROM [sys].[extended_properties] WITH (READCOMMITTEDLOCK)
                WHERE [class]=1 AND [major_id]=@@PROCID AND [minor_id]=0 AND [name] COLLATE Latin1_General_100_BIN2=@RuntimeName COLLATE Latin1_General_100_BIN2;
                IF @RuntimeReceipt IS NULL OR ISJSON(@RuntimeReceipt)<>1 THROW 50000,N'RUNTIME_HANDOVER_INVALID',1;
                IF (SELECT COUNT(*) FROM OPENJSON(@RuntimeReceipt))<>5 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@RuntimeReceipt) GROUP BY [key] COLLATE Latin1_General_100_BIN2,DATALENGTH([key]) HAVING COUNT(*)<>1)
                    OR EXISTS(SELECT 1 FROM OPENJSON(@RuntimeReceipt) WHERE [type]<>1 OR [key] COLLATE Latin1_General_100_BIN2 NOT IN ('contract','version','snapshotSha256','issuedUtc','expiresUtc'))
                    THROW 50000,N'RUNTIME_HANDOVER_INVALID',1;
                DECLARE @RuntimeIssued datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@RuntimeReceipt,'$.issuedUtc'),127),@RuntimeExpires datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@RuntimeReceipt,'$.expiresUtc'),127);
                IF COALESCE(JSON_VALUE(@RuntimeReceipt,'$.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-local-runtime-handover' OR DATALENGTH(JSON_VALUE(@RuntimeReceipt,'$.contract'))<>DATALENGTH(N'ssis-local-runtime-handover')
                    OR COALESCE(JSON_VALUE(@RuntimeReceipt,'$.version'),'') COLLATE Latin1_General_100_BIN2<>'1.0.0' OR DATALENGTH(JSON_VALUE(@RuntimeReceipt,'$.version'))<>10
                    OR @RuntimeIssued IS NULL OR @RuntimeExpires IS NULL OR @RuntimeIssued>@Started OR @RuntimeExpires<=@Started OR @RuntimeExpires>DATEADD(hour,24,@RuntimeIssued)
                    OR DATALENGTH(JSON_VALUE(@RuntimeReceipt,'$.snapshotSha256'))<>128 OR COALESCE(UPPER(JSON_VALUE(@RuntimeReceipt,'$.snapshotSha256')),'') COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExecutionSnapshotJson)),2) COLLATE Latin1_General_100_BIN2
                    THROW 50000,N'RUNTIME_HANDOVER_INVALID',1;
                -- Der Capturetransport erlaubt unbekannte Annotationen; bekannte Bindungen
                -- werden ausdrücklich geprüft. Doppelte Objektschlüssel sind überall ungültig.
                CREATE TABLE #SsisPackageModelAnalysis_RuntimeContainers([ContainerId] int IDENTITY PRIMARY KEY,[Depth] int NOT NULL,[JsonType] int NOT NULL,[ValueText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
                INSERT #SsisPackageModelAnalysis_RuntimeContainers VALUES(0,5,@ExecutionSnapshotJson);
                DECLARE @RuntimeDepth int=0,@RuntimeTokens bigint=0;
                WHILE EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_RuntimeContainers WHERE [Depth]=@RuntimeDepth)
                BEGIN
                    IF @RuntimeDepth>16 OR SYSUTCDATETIME()>=@Deadline THROW 50000,N'RUNTIME_CAPTURE_LIMIT',1;
                    SELECT @RuntimeTokens+=COUNT_BIG(*) FROM #SsisPackageModelAnalysis_RuntimeContainers AS [c] CROSS APPLY OPENJSON([c].[ValueText]) AS [j] WHERE [c].[Depth]=@RuntimeDepth;
                    IF @RuntimeTokens>1048576 THROW 50000,N'RUNTIME_CAPTURE_LIMIT',1;
                    IF EXISTS(SELECT [c].[ContainerId],[j].[key] COLLATE Latin1_General_100_BIN2 FROM #SsisPackageModelAnalysis_RuntimeContainers AS [c] CROSS APPLY OPENJSON([c].[ValueText]) AS [j]
                        WHERE [c].[Depth]=@RuntimeDepth AND [c].[JsonType]=5 GROUP BY [c].[ContainerId],[j].[key] COLLATE Latin1_General_100_BIN2,DATALENGTH([j].[key]) HAVING COUNT(*)>1)
                        THROW 50000,N'RUNTIME_CAPTURE_INVALID',1;
                    INSERT #SsisPackageModelAnalysis_RuntimeContainers SELECT @RuntimeDepth+1,[j].[type],[j].[value] FROM #SsisPackageModelAnalysis_RuntimeContainers AS [c] CROSS APPLY OPENJSON([c].[ValueText]) AS [j] WHERE [c].[Depth]=@RuntimeDepth AND [j].[type] IN (4,5);
                    DELETE #SsisPackageModelAnalysis_RuntimeContainers WHERE [Depth]=@RuntimeDepth;
                    SET @RuntimeDepth+=1;
                END;
                IF COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-execution-snapshot' OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.contract'))<>DATALENGTH(N'ssis-execution-snapshot')
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.version'),'') COLLATE Latin1_General_100_BIN2<>CASE WHEN @IncludeIterationCorrelation=1 THEN '1.1.0' ELSE '1.0.0' END OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.version'))<>10
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.method'),'') COLLATE Latin1_General_100_BIN2<>CASE WHEN @IncludeIterationCorrelation=1 THEN 'SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1' ELSE 'SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1' END OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.method'))<>DATALENGTH(CASE WHEN @IncludeIterationCorrelation=1 THEN N'SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1' ELSE N'SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1' END)
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.identityProfile'),'') COLLATE Latin1_General_100_BIN2<>'document-order-v1' OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.identityProfile'))<>34
                    OR COALESCE(UPPER(JSON_VALUE(@ExecutionSnapshotJson,'$.modelSha256')),'') COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PackageModelJson)),2) COLLATE Latin1_General_100_BIN2 OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.modelSha256'))<>128
                    OR COALESCE(UPPER(JSON_VALUE(@ExecutionSnapshotJson,'$.packageSha256')),'') COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2 OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.packageSha256'))<>128
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-object-identities' OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.contract'))<>DATALENGTH(N'ssis-object-identities')
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.version'),'') COLLATE Latin1_General_100_BIN2<>CASE WHEN @IncludeIterationCorrelation=1 THEN '1.1.0' ELSE '1.0.0' END OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.version'))<>10
                    OR COALESCE(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.identityProfile'),'') COLLATE Latin1_General_100_BIN2<>'document-order-v1' OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.identityProfile'))<>34
                    OR COALESCE(UPPER(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.packageSha256')),'') COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2 OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.identities.packageSha256'))<>128
                    THROW 50000,N'RUNTIME_MODEL_BINDING_INVALID',1;
                SELECT @CatalogGuid=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.catalogDatabaseGuid')),@RuntimeSourceBinding=JSON_VALUE(@ExecutionSnapshotJson,'$.execution.sourceBindingSha256'),@RuntimeProjectId=TRY_CONVERT(bigint,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.projectId')),
                    @RuntimeProjectLsn=TRY_CONVERT(bigint,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.projectLsn')),@RuntimeFile=JSON_VALUE(@ExecutionSnapshotJson,'$.execution.packageFileName'),
                    @RuntimeCreated=TRY_CONVERT(datetimeoffset(7),JSON_VALUE(@ExecutionSnapshotJson,'$.execution.executionCreatedUtc'),127),@RuntimeExecutionStatus=TRY_CONVERT(int,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.executionStatus')),
                    @RuntimeStart=TRY_CONVERT(datetimeoffset(7),JSON_VALUE(@ExecutionSnapshotJson,'$.execution.startTime'),127),@RuntimeEnd=TRY_CONVERT(datetimeoffset(7),JSON_VALUE(@ExecutionSnapshotJson,'$.execution.endTime'),127),
                    @CaptureStart=TRY_CONVERT(datetime2(7),JSON_VALUE(@ExecutionSnapshotJson,'$.execution.snapshotStartedUtc'),127),@CaptureEnd=TRY_CONVERT(datetime2(7),JSON_VALUE(@ExecutionSnapshotJson,'$.execution.snapshotCompletedUtc'),127);
                IF COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.executionId')),0)<>@ExecutionId OR @CatalogGuid IS NULL OR @CatalogGuid='00000000-0000-0000-0000-000000000000' OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.execution.catalogDatabaseGuid'))<>72
                    OR @RuntimeSourceBinding IS NULL OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.execution.sourceBindingSha256'))<>128 OR @RuntimeSourceBinding COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9a-f]%'
                    OR @RuntimeProjectId IS NULL OR @RuntimeProjectId<1 OR @RuntimeProjectLsn IS NULL OR @RuntimeProjectLsn<1 OR @RuntimeFile IS NULL OR DATALENGTH(JSON_VALUE(@ExecutionSnapshotJson,'$.execution.packageFileName')) NOT BETWEEN 2 AND 520
                    OR JSON_VALUE(@ExecutionSnapshotJson,'$.execution.startTime') IS NOT NULL AND @RuntimeStart IS NULL
                    OR JSON_VALUE(@ExecutionSnapshotJson,'$.execution.endTime') IS NOT NULL AND @RuntimeEnd IS NULL
                    OR JSON_QUERY(@ExecutionSnapshotJson,'$.execution.startTime') IS NOT NULL OR JSON_QUERY(@ExecutionSnapshotJson,'$.execution.endTime') IS NOT NULL
                    OR @RuntimeCreated IS NULL OR @RuntimeExecutionStatus NOT BETWEEN 1 AND 9 OR @RuntimeExecutionStatus IS NULL OR @CaptureStart IS NULL OR @CaptureEnd IS NULL OR @CaptureEnd<@CaptureStart
                    THROW 50000,N'RUNTIME_EXECUTION_BINDING_INVALID',1;
                SET @RuntimeMethod=JSON_VALUE(@ExecutionSnapshotJson,'$.method');
                IF @IncludeIterationCorrelation=1
                BEGIN
                    IF NOT EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.execution') WHERE [key] COLLATE Latin1_General_100_BIN2=N'loggingLevel' AND DATALENGTH([key])=DATALENGTH(N'loggingLevel') AND [type] IN(0,2))
                        OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.execution') WHERE [key] COLLATE Latin1_General_100_BIN2=N'loggingLevel' AND DATALENGTH([key])=DATALENGTH(N'loggingLevel') AND [type]=2 AND ([value] COLLATE Latin1_General_100_BIN2 NOT IN(N'0',N'1',N'2',N'3',N'4',N'100')))
                        OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects') AS [x] WHERE (SELECT COUNT(*) FROM OPENJSON([x].[value]) WHERE [key] COLLATE Latin1_General_100_BIN2=N'iterationContainer' AND DATALENGTH([key])=DATALENGTH(N'iterationContainer') AND [type]=3)<>1)
                        THROW 50000,N'RUNTIME_ITERATION_PROFILE_INVALID',1;
                    SET @RuntimeLoggingLevel=TRY_CONVERT(int,JSON_VALUE(@ExecutionSnapshotJson,'$.execution.loggingLevel'));
                END;
                CREATE TABLE #SsisPackageModelAnalysis_RuntimeIdentities([NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[NodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeGuid] uniqueidentifier NULL,[PackagePath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
                IF JSON_QUERY(@ExecutionSnapshotJson,'$.identities.objects') IS NULL OR LEFT(LTRIM(JSON_QUERY(@ExecutionSnapshotJson,'$.identities.objects')),1)<>N'['
                    OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects') WHERE [type]<>5)
                    OR (SELECT COUNT(*) FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects'))<>(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeKind] IN ('PACKAGE','EXECUTABLE'))
                    OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects') WITH([NodeId] nvarchar(max) '$.nodeId',[NodeKind] nvarchar(max) '$.nodeKind',[NativeGuid] nvarchar(max) '$.dtsId',[PackagePath] nvarchar(max) '$.packagePath') AS [j]
                        LEFT JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId] COLLATE Latin1_General_100_BIN2=[j].[NodeId] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([n].[NodeId])*2=DATALENGTH([j].[NodeId]) AND [n].[NodeKind] COLLATE Latin1_General_100_BIN2=[j].[NodeKind] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([n].[NodeKind])*2=DATALENGTH([j].[NodeKind])
                        WHERE [n].[NodeId] IS NULL OR [n].[NodeKind] NOT IN ('PACKAGE','EXECUTABLE') OR DATALENGTH([j].[PackagePath])>8000 OR [j].[NativeGuid] IS NOT NULL AND (DATALENGTH([j].[NativeGuid])<>72 OR TRY_CONVERT(uniqueidentifier,[j].[NativeGuid]) IS NULL))
                    THROW 50000,N'RUNTIME_OBJECT_IDENTITIES_INVALID',1;
                INSERT #SsisPackageModelAnalysis_RuntimeIdentities
                SELECT [NodeId],[NodeKind],TRY_CONVERT(uniqueidentifier,[NativeGuid]),[PackagePath] FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects') WITH([NodeId] varchar(128) '$.nodeId',[NodeKind] varchar(16) '$.nodeKind',[NativeGuid] nvarchar(36) '$.dtsId',[PackagePath] nvarchar(4000) '$.packagePath');
                IF JSON_QUERY(@ExecutionSnapshotJson,'$.observations') IS NULL OR LEFT(LTRIM(JSON_QUERY(@ExecutionSnapshotJson,'$.observations')),1)<>N'[' OR (SELECT COUNT(*) FROM OPENJSON(@ExecutionSnapshotJson,'$.observations'))>50000 OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.observations') WHERE [type]<>5)
                    OR EXISTS(SELECT 1 FROM OPENJSON(@ExecutionSnapshotJson,'$.observations') WITH([StatisticsId] nvarchar(max) '$.statisticsId',[ExecutionId] nvarchar(max) '$.executionId',[ExecutableId] nvarchar(max) '$.executableId',[NativeGuid] nvarchar(max) '$.executableGuid',[PackageName] nvarchar(max) '$.packageName',[PackagePath] nvarchar(max) '$.packagePath',[ExecutionPath] nvarchar(max) '$.executionPath',[StartTime] nvarchar(max) '$.startTime',[EndTime] nvarchar(max) '$.endTime',[DurationMs] nvarchar(max) '$.durationMs',[ExecutionResult] nvarchar(max) '$.executionResult') AS [j]
                        WHERE COALESCE(TRY_CONVERT(bigint,[j].[StatisticsId]),0)<1 OR COALESCE(TRY_CONVERT(bigint,[j].[ExecutionId]),0)<>@ExecutionId OR COALESCE(TRY_CONVERT(bigint,[j].[ExecutableId]),0)<1
                            OR [j].[StartTime] IS NOT NULL AND TRY_CONVERT(datetimeoffset(7),[j].[StartTime],127) IS NULL OR [j].[EndTime] IS NOT NULL AND TRY_CONVERT(datetimeoffset(7),[j].[EndTime],127) IS NULL
                            OR [j].[DurationMs] IS NOT NULL AND TRY_CONVERT(int,[j].[DurationMs]) IS NULL OR [j].[ExecutionResult] IS NOT NULL AND TRY_CONVERT(int,[j].[ExecutionResult]) IS NULL
                            OR DATALENGTH([j].[PackageName])>520 OR DATALENGTH([j].[PackagePath])>8000 OR DATALENGTH([j].[ExecutionPath])>8000 OR [j].[NativeGuid] IS NOT NULL AND (DATALENGTH([j].[NativeGuid])<>72 OR TRY_CONVERT(uniqueidentifier,[j].[NativeGuid]) IS NULL))
                    THROW 50000,N'RUNTIME_OBSERVATIONS_INVALID',1;
                INSERT #SsisPackageModelAnalysis_ExecutionCorrelation
                SELECT TRY_CONVERT(bigint,[StatisticsId]),@ExecutionId,TRY_CONVERT(bigint,[ExecutableId]),NULL,NULL,TRY_CONVERT(uniqueidentifier,[NativeGuid]),[PackageName],[PackagePath],[ExecutionPath],TRY_CONVERT(datetimeoffset(7),[StartTime],127),TRY_CONVERT(datetimeoffset(7),[EndTime],127),TRY_CONVERT(int,[DurationMs]),TRY_CONVERT(int,[ExecutionResult]),'NO_QUALIFIED_ROOT_OBSERVATION','IMPORTED_CATALOG_OBSERVATION'
                FROM OPENJSON(@ExecutionSnapshotJson,'$.observations') WITH([StatisticsId] nvarchar(40) '$.statisticsId',[ExecutableId] nvarchar(40) '$.executableId',[NativeGuid] nvarchar(36) '$.executableGuid',[PackageName] nvarchar(260) '$.packageName',[PackagePath] nvarchar(4000) '$.packagePath',[ExecutionPath] nvarchar(4000) '$.executionPath',[StartTime] nvarchar(64) '$.startTime',[EndTime] nvarchar(64) '$.endTime',[DurationMs] nvarchar(64) '$.durationMs',[ExecutionResult] nvarchar(64) '$.executionResult');
                DECLARE @RootCount int,@RootRuntimePackage nvarchar(260),@RootPackagePath nvarchar(4000),@RootExecutionPath nvarchar(4000),@RootPackageChars int;
                -- SSISDB unterscheidet Paketpfad und Laufzeitwurzel. Die Wurzel
                -- wird beobachtet, nicht aus einem Modellanzeigenamen erzeugt.
                SELECT @RootCount=COUNT(*),@RootRuntimePackage=MAX([o].[PackageName]),@RootPackagePath=MAX([o].[PackagePath]),@RootExecutionPath=MAX([o].[ExecutionPath])
                FROM #SsisPackageModelAnalysis_ExecutionCorrelation AS [o] JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [i] ON [i].[NodeKind]='PACKAGE' AND [i].[NativeGuid]=[o].[ExecutableGuid]
                WHERE [i].[PackagePath] COLLATE Latin1_General_100_BIN2=[o].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([i].[PackagePath])=DATALENGTH([o].[PackagePath])
                    AND [o].[PackageName] COLLATE Latin1_General_100_BIN2=@RuntimeFile COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH(@RuntimeFile)
                    AND LEFT([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,1) COLLATE Latin1_General_100_BIN2=N'\' COLLATE Latin1_General_100_BIN2
                    AND DATALENGTH([o].[ExecutionPath])>2 AND CHARINDEX(N'\',[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,2)=0
                    AND (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_RuntimeIdentities AS [g] WHERE [g].[NativeGuid]=[i].[NativeGuid])=1;
                IF @RootCount=1 AND @RootRuntimePackage IS NOT NULL
                BEGIN
                    SET @RootQualified=1;SET @RootPackageChars=DATALENGTH(@RootPackagePath)/2;
                    UPDATE [o] SET [CorrelationStatus]=CASE WHEN [o].[ExecutableGuid] IS NULL THEN 'NATIVE_GUID_UNAVAILABLE' WHEN [o].[PackagePath] IS NULL OR [o].[ExecutionPath] IS NULL THEN 'PATH_UNAVAILABLE' ELSE 'NO_EXACT_MODEL_OBJECT' END FROM #SsisPackageModelAnalysis_ExecutionCorrelation AS [o];
                    UPDATE [o] SET [ModelNodeId]=[i].[NodeId],[ModelNodeKind]=[i].[NodeKind],[CorrelationStatus]='EXACT_GUID_AND_PATH'
                    FROM #SsisPackageModelAnalysis_ExecutionCorrelation AS [o] JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [i] ON [i].[NativeGuid]=[o].[ExecutableGuid]
                    CROSS APPLY(SELECT CONVERT(nvarchar(max),@RootExecutionPath)+SUBSTRING([i].[PackagePath] COLLATE Latin1_General_100_BIN2,@RootPackageChars+1,4000) AS [Path]) AS [expected]
                    WHERE [i].[PackagePath] COLLATE Latin1_General_100_BIN2=[o].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([i].[PackagePath])=DATALENGTH([o].[PackagePath])
                        AND ([i].[PackagePath] COLLATE Latin1_General_100_BIN2=@RootPackagePath COLLATE Latin1_General_100_BIN2 AND DATALENGTH([i].[PackagePath])=DATALENGTH(@RootPackagePath)
                            OR LEFT([i].[PackagePath] COLLATE Latin1_General_100_BIN2,@RootPackageChars+1) COLLATE Latin1_General_100_BIN2=(@RootPackagePath+N'\') COLLATE Latin1_General_100_BIN2 AND DATALENGTH([i].[PackagePath])>DATALENGTH(@RootPackagePath))
                        AND [expected].[Path] COLLATE Latin1_General_100_BIN2=[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([expected].[Path])=DATALENGTH([o].[ExecutionPath])
                        AND [o].[PackageName] COLLATE Latin1_General_100_BIN2=@RootRuntimePackage COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH(@RootRuntimePackage)
                        AND (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_RuntimeIdentities AS [g] WHERE [g].[NativeGuid]=[i].[NativeGuid])=1;
                END;
                -- BEGIN ITERATION CORRELATION
                IF @IncludeIterationCorrelation=1 AND @RootQualified=1
                BEGIN
                    -- Ausschließlich der Toolbelt-Sidecar klassifiziert Schleifen.
                    -- Die Kette nutzt Modell-Parent-IDs und native Pfadsegmente;
                    -- weder Anzeigenamen noch pauschale Klammerentfernung sind zulässig.
                    CREATE TABLE #SsisPackageModelAnalysis_IterationRoles([NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[IsLoop] bit NOT NULL);
                    INSERT #SsisPackageModelAnalysis_IterationRoles
                    SELECT [NodeId],[IsLoop] FROM OPENJSON(@ExecutionSnapshotJson,'$.identities.objects') WITH([NodeId] varchar(128) '$.nodeId',[IsLoop] bit '$.iterationContainer');
                    CREATE TABLE #SsisPackageModelAnalysis_IterationSegments(
                        [TargetId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StepNo] int NOT NULL,[Segment] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                        [SegmentChars] int NOT NULL,[AllowCounter] bit NOT NULL,[SegmentCount] int NOT NULL,PRIMARY KEY([TargetId],[StepNo]));
                    ;WITH [ancestors] AS(
                        SELECT [i].[NodeId] AS [TargetId],[i].[NodeId],[n].[ParentNodeId],0 AS [Distance]
                        FROM #SsisPackageModelAnalysis_RuntimeIdentities AS [i] JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId]=[i].[NodeId]
                        UNION ALL
                        SELECT [a].[TargetId],[n].[NodeId],[n].[ParentNodeId],[a].[Distance]+1
                        FROM [ancestors] AS [a] JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId]=[a].[ParentNodeId]
                        WHERE [a].[Distance]<32
                    ),[segments] AS(
                        SELECT [a].[TargetId],[a].[NodeId],[a].[Distance],
                            SUBSTRING([i].[PackagePath] COLLATE Latin1_General_100_BIN2,DATALENGTH([parent].[PackagePath])/2+1,4000) AS [Segment],
                            CASE WHEN [role].[IsLoop]=1 AND [a].[NodeId]<>[a].[TargetId] THEN 1 ELSE 0 END AS [AllowCounter],
                            CASE WHEN [parent].[PackagePath] IS NOT NULL AND LEFT([i].[PackagePath] COLLATE Latin1_General_100_BIN2,DATALENGTH([parent].[PackagePath])/2+1) COLLATE Latin1_General_100_BIN2=(CONVERT(nvarchar(max),[parent].[PackagePath])+N'\') COLLATE Latin1_General_100_BIN2
                                AND JSON_VALUE([n].[AttributesJson],'$.isEventHandler')='false' THEN 1 ELSE 0 END AS [ValidSegment]
                        FROM [ancestors] AS [a] JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [i] ON [i].[NodeId]=[a].[NodeId]
                        JOIN #SsisPackageModelAnalysis_Nodes AS [n] ON [n].[NodeId]=[a].[NodeId]
                        JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [parent] ON [parent].[NodeId]=[a].[ParentNodeId]
                        JOIN #SsisPackageModelAnalysis_IterationRoles AS [role] ON [role].[NodeId]=[a].[NodeId]
                        WHERE [a].[ParentNodeId] IS NOT NULL
                            AND EXISTS(SELECT 1 FROM [ancestors] AS [root] JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [ri] ON [ri].[NodeId]=[root].[NodeId]
                                WHERE [root].[TargetId]=[a].[TargetId] AND [root].[ParentNodeId] IS NULL AND [ri].[NodeKind]='PACKAGE' AND [ri].[PackagePath] COLLATE Latin1_General_100_BIN2=@RootPackagePath COLLATE Latin1_General_100_BIN2 AND DATALENGTH([ri].[PackagePath])=DATALENGTH(@RootPackagePath))
                    )
                    INSERT #SsisPackageModelAnalysis_IterationSegments
                    SELECT [TargetId],ROW_NUMBER() OVER(PARTITION BY [TargetId] ORDER BY [Distance] DESC),[Segment],DATALENGTH([Segment])/2,[AllowCounter],COUNT(*) OVER(PARTITION BY [TargetId])
                    FROM [segments] AS [s]
                    WHERE NOT EXISTS(SELECT 1 FROM [segments] AS [bad] WHERE [bad].[TargetId]=[s].[TargetId] AND ([bad].[ValidSegment]=0 OR DATALENGTH([bad].[Segment])<=2 OR CHARINDEX(N'\',[bad].[Segment] COLLATE Latin1_General_100_BIN2,2)>0))
                    OPTION(MAXRECURSION 33);
                    CREATE TABLE #SsisPackageModelAnalysis_IterationPositions(
                        [StatisticsId] bigint NOT NULL PRIMARY KEY,[TargetId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NextChar] int NOT NULL,[SegmentCount] int NOT NULL,[ValidPath] bit NOT NULL);
                    INSERT #SsisPackageModelAnalysis_IterationPositions
                    SELECT [o].[StatisticsId],[i].[NodeId],DATALENGTH(@RootExecutionPath)/2+1,MAX([s].[SegmentCount]),1
                    FROM #SsisPackageModelAnalysis_ExecutionCorrelation AS [o]
                    JOIN #SsisPackageModelAnalysis_RuntimeIdentities AS [i] ON [i].[NativeGuid]=[o].[ExecutableGuid]
                    JOIN #SsisPackageModelAnalysis_IterationSegments AS [s] ON [s].[TargetId]=[i].[NodeId]
                    WHERE [o].[ModelNodeId] IS NULL AND [o].[PackagePath] COLLATE Latin1_General_100_BIN2=[i].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackagePath])=DATALENGTH([i].[PackagePath])
                        AND [o].[PackageName] COLLATE Latin1_General_100_BIN2=@RootRuntimePackage COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH(@RootRuntimePackage)
                        AND LEFT([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,DATALENGTH(@RootExecutionPath)/2) COLLATE Latin1_General_100_BIN2=@RootExecutionPath COLLATE Latin1_General_100_BIN2
                        AND (SELECT COUNT(*) FROM #SsisPackageModelAnalysis_RuntimeIdentities AS [g] WHERE [g].[NativeGuid]=[i].[NativeGuid])=1
                    GROUP BY [o].[StatisticsId],[i].[NodeId];
                    DECLARE @IterationStep int=1;
                    WHILE @IterationStep<=32 AND EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_IterationPositions WHERE [ValidPath]=1 AND [SegmentCount]>=@IterationStep)
                    BEGIN
                        IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'RUNTIME_CAPTURE_LIMIT',1;
                        UPDATE [p] SET [ValidPath]=CASE WHEN SUBSTRING([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,[p].[NextChar],[s].[SegmentChars]) COLLATE Latin1_General_100_BIN2=[s].[Segment] COLLATE Latin1_General_100_BIN2
                            AND DATALENGTH(SUBSTRING([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,[p].[NextChar],[s].[SegmentChars]))=DATALENGTH([s].[Segment])
                            AND ([suffix].[HasCounter]=0 OR [suffix].[CloseChar]>[offset].[NextChar]+1 AND DATALENGTH([digits].[Value]) BETWEEN 2 AND 38
                                AND LEFT([digits].[Value],1) COLLATE Latin1_General_100_BIN2 BETWEEN N'1' AND N'9' AND [digits].[Value] COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[^0-9]%'
                                AND TRY_CONVERT(bigint,[digits].[Value])>0) THEN 1 ELSE 0 END,
                            [NextChar]=CASE WHEN [suffix].[HasCounter]=1 THEN [suffix].[CloseChar]+1 ELSE [offset].[NextChar] END
                        FROM #SsisPackageModelAnalysis_IterationPositions AS [p]
                        JOIN #SsisPackageModelAnalysis_IterationSegments AS [s] ON [s].[TargetId]=[p].[TargetId] AND [s].[StepNo]=@IterationStep
                        JOIN #SsisPackageModelAnalysis_ExecutionCorrelation AS [o] ON [o].[StatisticsId]=[p].[StatisticsId]
                        CROSS APPLY(SELECT [p].[NextChar]+[s].[SegmentChars] AS [NextChar]) AS [offset]
                        CROSS APPLY(SELECT CASE WHEN [s].[AllowCounter]=1 AND SUBSTRING([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,[offset].[NextChar],1)=N'[' THEN 1 ELSE 0 END AS [HasCounter],CHARINDEX(N']',[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,[offset].[NextChar]+1) AS [CloseChar]) AS [suffix]
                        CROSS APPLY(SELECT SUBSTRING([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,[offset].[NextChar]+1,CASE WHEN [suffix].[CloseChar]>[offset].[NextChar] THEN [suffix].[CloseChar]-[offset].[NextChar]-1 ELSE 0 END) AS [Value]) AS [digits]
                        WHERE [p].[ValidPath]=1;
                        SET @IterationStep+=1;
                    END;
                    UPDATE [o] SET [ModelNodeId]=[p].[TargetId],[ModelNodeKind]='EXECUTABLE',[CorrelationStatus]='EXACT_GUID_AND_ITERATION_PATH'
                    FROM #SsisPackageModelAnalysis_ExecutionCorrelation AS [o] JOIN #SsisPackageModelAnalysis_IterationPositions AS [p] ON [p].[StatisticsId]=[o].[StatisticsId]
                    WHERE [p].[ValidPath]=1 AND [p].[NextChar]=DATALENGTH([o].[ExecutionPath])/2+1;
                END;
                -- END ITERATION CORRELATION
                SET @RuntimeStatus='RUNTIME_BOUND_CAPTURE';SET @RuntimeReason=CASE WHEN @RootQualified=0 THEN 'NO_QUALIFIED_ROOT_OBSERVATION' END;
            END TRY
            BEGIN CATCH
                SET @RuntimeError=ERROR_NUMBER();SET @RuntimeReason=CASE WHEN ERROR_NUMBER()=50000 THEN CONVERT(varchar(64),ERROR_MESSAGE()) ELSE 'RUNTIME_CAPTURE_INVALID' END;
                DELETE #SsisPackageModelAnalysis_ExecutionCorrelation;
                SELECT @RuntimeLoggingLevel=NULL,@RuntimeMethod=NULL;
                SELECT @CatalogGuid=NULL,@RuntimeSourceBinding=NULL,@RuntimeProjectId=NULL,@RuntimeProjectLsn=NULL,@RuntimeFile=NULL,@RuntimeCreated=NULL,@RuntimeExecutionStatus=NULL,@RuntimeStart=NULL,@RuntimeEnd=NULL,@CaptureStart=NULL,@CaptureEnd=NULL,@RootQualified=0;
            END CATCH;
            INSERT #SsisPackageModelAnalysis_RuntimeBinding VALUES(@ExecutionId,@CatalogGuid,@RuntimeSourceBinding,@RuntimeProjectId,@RuntimeProjectLsn,@RuntimeFile,@RuntimeCreated,@RuntimeExecutionStatus,@RuntimeStart,@RuntimeEnd,@CaptureStart,@CaptureEnd,@PackageHash,@RuntimeStatus,@RuntimeReason,@RootQualified,(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_ExecutionCorrelation),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_ExecutionCorrelation WHERE [ModelNodeId] IS NOT NULL),1,@RuntimeError);
            INSERT #SsisPackageModelAnalysis_SourceStatus VALUES(N'Qualifizierter SSISDB-Capture',@RuntimeStatus,1,(SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_ExecutionCorrelation),N'Importierte Katalogbeobachtung des ausgewiesenen Quellslices; kein Livezugriff, keine Vollständigkeitsgarantie und keine Laufzeit-Lineage.');
            -- BEGIN ITERATION SUMMARY
            IF @IncludeIterationCorrelation=1
            BEGIN
                INSERT #SsisPackageModelAnalysis_ExecutionCoverage
                SELECT @ExecutionId,@RuntimeMethod,@RuntimeLoggingLevel,CASE WHEN @RuntimeLoggingLevel IS NULL THEN 'UNKNOWN' ELSE 'CONFIGURATION_OBSERVED' END,'VISIBLE_STATISTICS_ONLY',
                    CASE WHEN @RuntimeStatus<>'RUNTIME_BOUND_CAPTURE' THEN 'UNPROVEN' WHEN @RuntimeExecutionStatus IN(3,4,6,7,9) THEN 'TERMINAL_CAPTURE' ELSE 'IN_PROGRESS_CAPTURE' END,
                    COUNT(*),COUNT([ModelNodeId]),COUNT(*)-COUNT([ModelNodeId]),1 FROM #SsisPackageModelAnalysis_ExecutionCorrelation;
                IF @RuntimeStatus='RUNTIME_BOUND_CAPTURE'
                    INSERT #SsisPackageModelAnalysis_ExecutionObjectSummary
                    SELECT [n].[NodeId],[n].[NodeKind],COUNT([o].[StatisticsId]),SUM(CASE WHEN [o].[ExecutionResult]=0 THEN 1 ELSE 0 END),SUM(CASE WHEN [o].[ExecutionResult]=1 THEN 1 ELSE 0 END),SUM(CASE WHEN [o].[ExecutionResult]=3 THEN 1 ELSE 0 END),
                        SUM(CASE WHEN [o].[StatisticsId] IS NOT NULL AND ([o].[ExecutionResult] IS NULL OR [o].[ExecutionResult] NOT IN(0,1,3)) THEN 1 ELSE 0 END),
                        SUM(CASE WHEN [o].[DurationMs]>=0 THEN 1 ELSE 0 END),MIN(CASE WHEN [o].[DurationMs]>=0 THEN [o].[DurationMs] END),MAX(CASE WHEN [o].[DurationMs]>=0 THEN [o].[DurationMs] END),
                        CASE WHEN COUNT([o].[StatisticsId])>0 AND COUNT([o].[StatisticsId])=SUM(CASE WHEN [o].[DurationMs]>=0 THEN 1 ELSE 0 END) THEN SUM(CONVERT(bigint,[o].[DurationMs])) END,
                        CASE WHEN COUNT([o].[StatisticsId])=0 THEN 'UNASSIGNED_OR_NOT_OBSERVED' ELSE 'OBSERVED_PARTIAL' END,1
                    FROM #SsisPackageModelAnalysis_Nodes AS [n] LEFT JOIN #SsisPackageModelAnalysis_ExecutionCorrelation AS [o] ON [o].[ModelNodeId]=[n].[NodeId]
                    WHERE [n].[NodeKind] IN('PACKAGE','EXECUTABLE') GROUP BY [n].[NodeId],[n].[NodeKind];
            END;
            -- END ITERATION SUMMARY
            IF @RuntimeReason IS NOT NULL INSERT #SsisPackageModelAnalysis_Warnings VALUES(@RuntimeReason,'INFO',N'Die optionale Laufzeitquelle besitzt keine uneingeschränkt qualifizierte Objektzuordnung; statische Modellangaben bleiben getrennt.');
        END;
        IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
    END TRY
    BEGIN CATCH
        SET @Error=ERROR_NUMBER();
        SET @Message=CASE WHEN ERROR_NUMBER()=50000 THEN ERROR_MESSAGE() ELSE N'Native Modellvalidierung fehlgeschlagen; Fehlernummer '+CONVERT(nvarchar(12),ERROR_NUMBER())+N'.' END;
        SET @Message+=N' Stage='+@ValidationStage;
        SET @Status=CASE WHEN ERROR_NUMBER()=50000 AND ERROR_MESSAGE() IN ('INVALID_PARAMETER','EXCHANGE_INVALID','EXCHANGE_VERSION_UNSUPPORTED','EXCHANGE_LIMIT_EXCEEDED','EXCHANGE_REFERENCE_INVALID','EXCHANGE_PROFILE_UNSUPPORTED','EXCHANGE_SOURCE_MISMATCH','EXCHANGE_HANDOVER_INVALID','EXCHANGE_TIME_BUDGET_EXHAUSTED') THEN ERROR_MESSAGE() ELSE 'EXCHANGE_INVALID' END;
        DELETE #SsisPackageModelAnalysis_ExecutionObjectSummary; DELETE #SsisPackageModelAnalysis_ExecutionCoverage; DELETE #SsisPackageModelAnalysis_RuntimeBinding; DELETE #SsisPackageModelAnalysis_ExecutionCorrelation; DELETE #SsisPackageModelAnalysis_SqlMetadata; DELETE #SsisPackageModelAnalysis_SourceStatus; DELETE #SsisPackageModelAnalysis_Binding; DELETE #SsisPackageModelAnalysis_Nodes; DELETE #SsisPackageModelAnalysis_Edges; DELETE #SsisPackageModelAnalysis_Coverage; DELETE #SsisPackageModelAnalysis_Findings; DELETE #SsisPackageModelAnalysis_Warnings;
        DELETE #SsisPackageModelAnalysis_ObjectFindings; DELETE #SsisPackageModelAnalysis_PackageOverview; DELETE #SsisPackageModelAnalysis_Executables; DELETE #SsisPackageModelAnalysis_DataFlows; DELETE #SsisPackageModelAnalysis_Components; DELETE #SsisPackageModelAnalysis_ColumnRelations;
    END CATCH;
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC [sys].[sp_executesql] @LockTimeoutSql;
    IF @Status='AVAILABLE_LIMITED' AND (EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeOrdinal]>@Limit) OR EXISTS(SELECT 1 FROM #SsisPackageModelAnalysis_Edges WHERE [EdgeOrdinal]>@Limit) OR (SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_ObjectFindings)>@Limit OR (SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_SqlMetadata)>@Limit OR (SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_ExecutionCorrelation)>@Limit OR (SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_ExecutionObjectSummary)>@Limit)
        INSERT #SsisPackageModelAnalysis_Warnings VALUES('RESULT_TRUNCATED','INFO',N'Nur die Ausgabe ist begrenzt; die Validierung verwendete den vollständigen Graphen.');
    INSERT #SsisPackageModelAnalysis_ModuleStatus VALUES('USP_SsisPackageModelAnalysis',@Started,@SchemaVersion,@Status,@Partial,(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Nodes),(SELECT COUNT(*) FROM #SsisPackageModelAnalysis_Edges),@Error,@Message);
    INSERT #SsisPackageModelAnalysis_SourceStatus VALUES(N'Caller SSIS-Modell',@Status,@Partial,(SELECT COUNT_BIG(*) FROM #SsisPackageModelAnalysis_Nodes),N'Native Strukturprüfung; ProducerTrust='+CONVERT(nvarchar(24),CASE WHEN @Status='AVAILABLE_LIMITED' THEN @ProducerTrust ELSE 'UNVERIFIED' END)+N'. Keine Paket- oder SQL-Ausführung.');
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
    IF @JsonErzeugen=1
    BEGIN
        SET @Json=(SELECT @SchemaVersion AS [meta.schemaVersion],@Status AS [meta.statusCode],@Partial AS [meta.isPartial],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_ModuleStatus FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [moduleStatus],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Binding FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceBinding],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Nodes WHERE [NodeOrdinal]<=@Limit ORDER BY [NodeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [nodes],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Edges WHERE [EdgeOrdinal]<=@Limit ORDER BY [EdgeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [edges],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Coverage ORDER BY [Feature] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [coverage],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Findings FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [findings],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_SourceStatus FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceStatus],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_Warnings FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [warnings] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
        IF @IncludeExecutionCorrelation=1
        BEGIN
            SET @Json=JSON_MODIFY(@Json,'$.meta.executionCorrelationSchemaVersion',1);
            SET @Json=JSON_MODIFY(@Json,'$.runtimeBinding',JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_RuntimeBinding FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.executionCorrelation',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_ExecutionCorrelation ORDER BY [StatisticsId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        END;
        IF @IncludeIterationCorrelation=1
        BEGIN
            SET @Json=JSON_MODIFY(@Json,'$.meta.iterationCorrelationSchemaVersion',1);
            SET @Json=JSON_MODIFY(@Json,'$.executionObjectSummary',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_ExecutionObjectSummary ORDER BY [ModelNodeId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.executionCoverage',JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_ExecutionCoverage FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        END;
        IF @IncludeSqlMetadata=1
        BEGIN
            SET @Json=JSON_MODIFY(@Json,'$.meta.sqlMetadataSchemaVersion',1);
            SET @Json=JSON_MODIFY(@Json,'$.sqlMetadata',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_SqlMetadata ORDER BY [BindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        END;
        IF @IncludeObjectRules=1
        BEGIN
            SET @Json=JSON_MODIFY(@Json,'$.meta.objectRulesSchemaVersion',1);
            SET @Json=JSON_MODIFY(@Json,'$.objectFindings',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_ObjectFindings ORDER BY [RuleId],[NodeId],[EdgeId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        END;
        IF @IncludePackageViews=1
        BEGIN
            SET @Json=JSON_MODIFY(@Json,'$.meta.packageViewsSchemaVersion',1);
            SET @Json=JSON_MODIFY(@Json,'$.packageOverview',JSON_QUERY(COALESCE((SELECT * FROM #SsisPackageModelAnalysis_PackageOverview FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.executables',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_Executables ORDER BY [NodeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.dataFlows',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_DataFlows ORDER BY [NodeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.components',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_Components ORDER BY [NodeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
            SET @Json=JSON_MODIFY(@Json,'$.columnRelations',JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM #SsisPackageModelAnalysis_ColumnRelations ORDER BY [EdgeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        END;
    END;
    -- Dieselbe begrenzte Materialisierung versorgt RAW, TABLE und JSON.
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [ModelNodeId]) AS [OutputRow] FROM #SsisPackageModelAnalysis_ExecutionObjectSummary) DELETE [r] WHERE [OutputRow]>@Limit;
    DELETE #SsisPackageModelAnalysis_Nodes WHERE [NodeOrdinal]>@Limit; DELETE #SsisPackageModelAnalysis_Edges WHERE [EdgeOrdinal]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [NodeOrdinal]) AS [OutputRow] FROM #SsisPackageModelAnalysis_Executables) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [NodeOrdinal]) AS [OutputRow] FROM #SsisPackageModelAnalysis_DataFlows) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [NodeOrdinal]) AS [OutputRow] FROM #SsisPackageModelAnalysis_Components) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [EdgeOrdinal]) AS [OutputRow] FROM #SsisPackageModelAnalysis_ColumnRelations) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [RuleId],[NodeId],[EdgeId]) AS [OutputRow] FROM #SsisPackageModelAnalysis_ObjectFindings) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [BindingOrdinal]) AS [OutputRow] FROM #SsisPackageModelAnalysis_SqlMetadata) DELETE [r] WHERE [OutputRow]>@Limit;
    ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [StatisticsId]) AS [OutputRow] FROM #SsisPackageModelAnalysis_ExecutionCorrelation) DELETE [r] WHERE [OutputRow]>@Limit;
    IF @Mode='TABLE'
    BEGIN
        DECLARE @Target sysname;
        IF @IncludeExecutionCorrelation=1
        BEGIN
            IF @IncludeIterationCorrelation=1
            BEGIN
                SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='executionObjectSummary'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ExecutionObjectSummary',@Target,@ThrowOnError=1;
                SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='executionCoverage'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ExecutionCoverage',@Target,@ThrowOnError=1;
            END;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='runtimeBinding'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_RuntimeBinding',@Target,@ThrowOnError=1;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='executionCorrelation'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ExecutionCorrelation',@Target,@ThrowOnError=1;
        END;
        IF @IncludeSqlMetadata=1
        BEGIN
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='sqlMetadata'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_SqlMetadata',@Target,@ThrowOnError=1;
        END;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='moduleStatus'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ModuleStatus',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='sourceBinding'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Binding',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='nodes'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Nodes',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='edges'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Edges',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='coverage'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Coverage',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='findings'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Findings',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='sourceStatus'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_SourceStatus',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='warnings'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Warnings',@Target,@ThrowOnError=1;
        IF @IncludeObjectRules=1
        BEGIN
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='objectFindings'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ObjectFindings',@Target,@ThrowOnError=1;
        END;
        IF @IncludePackageViews=1
        BEGIN
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='packageOverview'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_PackageOverview',@Target,@ThrowOnError=1;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='executables'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Executables',@Target,@ThrowOnError=1;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='dataFlows'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_DataFlows',@Target,@ThrowOnError=1;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='components'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_Components',@Target,@ThrowOnError=1;
            SET @Target=(SELECT [TargetTable] FROM #SsisPackageModelAnalysis_ResultTables WHERE [ResultName]='columnRelations'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageModelAnalysis_ColumnRelations',@Target,@ThrowOnError=1;
        END;
    END;
    IF @Mode='RAW'
    BEGIN
        SELECT * FROM #SsisPackageModelAnalysis_ModuleStatus; SELECT * FROM #SsisPackageModelAnalysis_Binding;
        SELECT * FROM #SsisPackageModelAnalysis_Nodes ORDER BY [NodeOrdinal]; SELECT * FROM #SsisPackageModelAnalysis_Edges ORDER BY [EdgeOrdinal];
        SELECT * FROM #SsisPackageModelAnalysis_Coverage ORDER BY [Feature]; SELECT * FROM #SsisPackageModelAnalysis_Findings;
        SELECT * FROM #SsisPackageModelAnalysis_SourceStatus; SELECT * FROM #SsisPackageModelAnalysis_Warnings;
        IF @IncludePackageViews=1
        BEGIN
            SELECT * FROM #SsisPackageModelAnalysis_PackageOverview; SELECT * FROM #SsisPackageModelAnalysis_Executables ORDER BY [NodeOrdinal];
            SELECT * FROM #SsisPackageModelAnalysis_DataFlows ORDER BY [NodeOrdinal]; SELECT * FROM #SsisPackageModelAnalysis_Components ORDER BY [NodeOrdinal];
            SELECT * FROM #SsisPackageModelAnalysis_ColumnRelations ORDER BY [EdgeOrdinal];
        END;
    END;
    IF @Mode='RAW' AND @IncludeObjectRules=1 SELECT * FROM #SsisPackageModelAnalysis_ObjectFindings ORDER BY [RuleId],[NodeId],[EdgeId];
    IF @Mode='RAW' AND @IncludeSqlMetadata=1 SELECT * FROM #SsisPackageModelAnalysis_SqlMetadata ORDER BY [BindingOrdinal];
    IF @Mode='RAW' AND @IncludeExecutionCorrelation=1
    BEGIN
        SELECT * FROM #SsisPackageModelAnalysis_RuntimeBinding; SELECT * FROM #SsisPackageModelAnalysis_ExecutionCorrelation ORDER BY [StatisticsId];
    END;
    IF @Mode='RAW' AND @IncludeIterationCorrelation=1
    BEGIN
        SELECT * FROM #SsisPackageModelAnalysis_ExecutionObjectSummary ORDER BY [ModelNodeId]; SELECT * FROM #SsisPackageModelAnalysis_ExecutionCoverage;
    END;
    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisPackageModelAnalysis_ModuleStatus',@ResultLabel=N'SsisPackageModelAnalysis',@EmptyMessage=N'Keine fachlichen Ergebnisse';
END;
GO
