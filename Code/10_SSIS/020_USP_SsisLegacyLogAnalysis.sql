USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SsisLegacyLogAnalysis
Version      : 1.4.0
Stand        : 2026-10-19
Typ          : Stored Procedure
Zweck        : Liest eine explizite Legacy-Loggingquelle für genau eine GUID.
Grenze       : Keine Quellaktionen; Meldungstexte bleiben Laufzeitausgaben.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisLegacyLogAnalysis]
      @LoggingDatabase sysname = NULL
    , @LoggingSchema sysname = N'dbo'
    , @LoggingTable sysname = N'sysssislog'
    , @ExecutionId uniqueidentifier = NULL
    , @IncludeTimeline bit = 1
    , @IncludeMessages bit = 1
    , @HighImpactConfirmed bit = 0
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
    , @ErrorMessageOut nvarchar(4000) = NULL OUTPUT
    , @IncludeTaskAnalysis bit = 0
    , @IncludeRowFlowAnalysis bit = 0
    , @IncludeComponentPhaseAnalysis bit = 0
    , @IncludeComponentLifecyclePhases bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF COALESCE(@Hilfe,0)=1
    BEGIN
        PRINT N'monitor.USP_SsisLegacyLogAnalysis: explizite @LoggingDatabase und @ExecutionId; Default dbo.sysssislog.';
        PRINT N'Alle gespeicherten Meldungen sind standardmäßig eingeschlossen. Keine zusätzlichen Indizes oder Quelländerungen.';
        PRINT N'RAW9, CONSOLE1, TABLE mit @ResultTablesJson, NONE0; optional JSON derselben Mengen.';
        PRINT N'@IncludeTaskAnalysis=1 ergänzt beobachtete Laufzeiten und Loggingabdeckung: RAW11, SchemaVersion2; keine Tasktyp- oder Konfigurationsbestimmung.';
        PRINT N'@IncludeRowFlowAnalysis=1 ergänzt OnPipelineRowsSent-Pfade: SchemaVersion3, RAW11 oder mit Taskanalyse RAW13; keine Paketgesamtmenge.';
        PRINT N'@IncludeComponentPhaseAnalysis=1 ergänzt PipelineComponentTime-Berichte für ProcessInput/PrimeOutput: SchemaVersion4, zwei letzte Mengen; keine CPU- oder exklusive Zeit.';
        PRINT N'@IncludeComponentLifecyclePhases=1 benötigt @IncludeComponentPhaseAnalysis=1 und ergänzt Validate/PreExecute/PostExecute: SchemaVersion5; getrennte VALIDATE-/EXECUTE-Berichtskontexte.';
        PRINT N'@MaxZeilen NULL/0 und eingeschlossenes nvarchar(max) benötigen @HighImpactConfirmed=1. Zeitbudget ist kooperativ.';
        RETURN;
    END;
    SELECT @IncludeComponentLifecyclePhases=COALESCE(@IncludeComponentLifecyclePhases,0),@IncludeComponentPhaseAnalysis=COALESCE(@IncludeComponentPhaseAnalysis,0),@IncludeRowFlowAnalysis=COALESCE(@IncludeRowFlowAnalysis,0),@IncludeTaskAnalysis=COALESCE(@IncludeTaskAnalysis,0),@IncludeTimeline=COALESCE(@IncludeTimeline,1),@IncludeMessages=COALESCE(@IncludeMessages,1),@HighImpactConfirmed=COALESCE(@HighImpactConfirmed,0);
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3),@Status varchar(40)='AVAILABLE',@Partial bit=0;
    DECLARE @Error int=NULL,@Message nvarchar(4000)=NULL,@Step int=1,@Continue bit=1,@ValidBuffer bit=0,@Truncated bit=0;
    DECLARE @DerivationComplete bit=0,@TaskComplete bit=0,@TaskStarted bit=0;
    DECLARE @TaskSources bigint=NULL,@TaskValid bigint=NULL,@TaskUnresolved bigint=NULL;
    DECLARE @RowComplete bit=0,@RowStarted bit=0,@RowCandidates bigint=NULL,@RowParsed bigint=NULL,@RowAssigned bigint=NULL;
    DECLARE @PhaseComplete bit=0,@PhaseStarted bit=0,@PhaseCandidates bigint=NULL,@PhaseParsed bigint=NULL,@PhaseAssigned bigint=NULL;
    DECLARE @AllowedNames nvarchar(max)=N'moduleStatus|execution|timeline|errorChain|iterations|loggingQuality|findings|sourceStatus|warnings';
    IF @IncludeTaskAnalysis=1 SET @AllowedNames+=N'|taskDurations|taskLoggingCoverage';
    IF @IncludeRowFlowAnalysis=1 SET @AllowedNames+=N'|rowFlowEvents|rowFlow';
    IF @IncludeComponentPhaseAnalysis=1 SET @AllowedNames+=N'|componentPhaseEvents|componentPhaseTimes';
    DECLARE @Limit bigint=CASE WHEN COALESCE(@MaxZeilen,0)=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @Take bigint=CASE WHEN COALESCE(@MaxZeilen,0)=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen)+1 END;
    DECLARE @PreviousLock int=@@LOCK_TIMEOUT,@PreviousAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END;
    DECLARE @RestoreLock nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
    DECLARE @LockSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),COALESCE(@LockTimeoutMs,0))+N';';
    CREATE TABLE [#SsisLegacyLogAnalysis_ResultTables]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    IF @OutputMode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
            @AllowedResultNames=@AllowedNames,
            @MappingTable=N'#SsisLegacyLogAnalysis_ResultTables',@ThrowOnError=1;
    CREATE TABLE [#SsisLegacyLogAnalysis_ModuleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SchemaVersion] int NOT NULL,
        [LoggingDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [LoggingSchema] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [LoggingTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ExecutionId] uniqueidentifier NULL,
        [MessagesIncluded] bit NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Execution]
    (
        [ExecutionId] uniqueidentifier NOT NULL,
        [AnalyzedEventCount] bigint NOT NULL,
        [SourceCount] bigint NOT NULL,
        [FirstObservedTime] datetime NULL,
        [LastObservedTime] datetime NULL,
        [ErrorEventCount] bigint NOT NULL,
        [WarningEventCount] bigint NOT NULL,
        [TaskFailedEventCount] bigint NOT NULL,
        [CancelRequestCount] bigint NOT NULL,
        [BoundaryStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PackageStartLogId] int NULL,
        [PackageEndLogId] int NULL,
        [PackageDurationMs] bigint NULL,
        [ObservedOutcome] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FirstErrorLogId] int NULL,
        [FirstErrorMessage] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsCompleteSlice] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Timeline]
    (
        [TimelineOrdinal] bigint NOT NULL,
        [LogId] int NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceId] uniqueidentifier NULL,
        [EventTime] datetime NULL,
        [RawEndTime] datetime NULL,
        [DataCode] int NULL,
        [PreviousLogId] int NULL,
        [DeltaFromPreviousMs] bigint NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_ErrorChain]
    (
        [ErrorOrdinal] bigint NOT NULL,
        [LogId] int NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceId] uniqueidentifier NULL,
        [EventTime] datetime NULL,
        [DataCode] int NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PreviousRelevantLogId] int NULL,
        [RelationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Iterations]
    (
        [IterationOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StartLogId] int NULL,
        [EndLogId] int NULL,
        [StartTime] datetime NULL,
        [EndTime] datetime NULL,
        [DurationMs] bigint NULL,
        [PairStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SampleIsPartial] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_LoggingQuality]
    (
        [QualityOrdinal] int NOT NULL,
        [QualityCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AffectedRowCount] bigint NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Findings]
    (
        [FindingOrdinal] int NOT NULL,
        [FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [LogId] int NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_SourceStatus]
    (
        [SourceOrdinal] int NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ObservedRowCount] bigint NULL,
        [ReturnedRowCount] bigint NULL,
        [IsTruncated] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Warnings]
    (
        [WarningOrdinal] int NOT NULL,
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_TaskDurations]
    (
        [TaskDurationOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NOT NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [BasisFirstLogId] int NOT NULL,
        [BasisLastLogId] int NOT NULL,
        [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PairRowCount] bigint NOT NULL,
        [ValidPairCount] bigint NOT NULL,
        [UnknownTimePairCount] bigint NOT NULL,
        [NonMonotonicPairCount] bigint NOT NULL,
        [OpenStartCount] bigint NOT NULL,
        [OpenEndCount] bigint NOT NULL,
        [AmbiguousBoundaryCount] bigint NOT NULL,
        [TotalDurationMs] decimal(38,0) NULL,
        [AverageDurationMs] decimal(38,6) NULL,
        [MinDurationMs] bigint NULL,
        [MaxDurationMs] bigint NULL,
        [SourceNameConflict] bit NOT NULL,
        [InputIsTruncated] bit NOT NULL,
        [MetricStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_TaskLoggingCoverage]
    (
        [CoverageOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NULL,
        [UnresolvedLogId] int NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [BasisFirstLogId] int NOT NULL,
        [BasisLastLogId] int NOT NULL,
        [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ObservedEventCount] bigint NOT NULL,
        [ExecuteStartCount] bigint NOT NULL,
        [ExecuteEndCount] bigint NOT NULL,
        [ValidateStartCount] bigint NOT NULL,
        [ValidateEndCount] bigint NOT NULL,
        [KnownOtherEventCount] bigint NOT NULL,
        [UnknownEventNameCount] bigint NOT NULL,
        [MissingEventNameCount] bigint NOT NULL,
        [MissingEventTimeCount] bigint NOT NULL,
        [AmbiguousBoundaryCount] bigint NOT NULL,
        [UnresolvedBoundaryCount] bigint NOT NULL,
        [IncompleteBoundaryCount] bigint NOT NULL,
        [InvalidTimePairCount] bigint NOT NULL,
        [SourceNameConflict] bit NOT NULL,
        [InputIsTruncated] bit NOT NULL,
        [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_RowFlowEvents]
    (
        [RowFlowEventOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [LogId] int NOT NULL,
        [SourceId] uniqueidentifier NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EventTime] datetime NULL,
        [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PathId] int NULL,
        [PathName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [DestinationComponentId] int NULL,
        [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [InputId] int NULL,
        [InputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RowsSent] bigint NULL,
        [OccurrenceStartLogId] int NULL,
        [OccurrenceEndLogId] int NULL,
        [GroupingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [InputIsTruncated] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_RowFlow]
    (
        [RowFlowOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NOT NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [OccurrenceStartLogId] int NOT NULL,
        [OccurrenceEndLogId] int NOT NULL,
        [PathId] int NOT NULL,
        [PathName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [DestinationComponentId] int NOT NULL,
        [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [InputId] int NOT NULL,
        [InputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EventCount] bigint NOT NULL,
        [RowsSentSum] decimal(38,0) NOT NULL,
        [MinRowsSent] bigint NOT NULL,
        [MaxRowsSent] bigint NOT NULL,
        [FirstObservedTime] datetime NOT NULL,
        [LastObservedTime] datetime NOT NULL,
        [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceNameConflict] bit NOT NULL,
        [PathNameConflict] bit NOT NULL,
        [DestinationNameConflict] bit NOT NULL,
        [InputNameConflict] bit NOT NULL,
        [InputIsTruncated] bit NOT NULL,
        [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_ComponentPhaseEvents]
    (
        [PhaseEventOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [LogId] int NOT NULL,
        [SourceId] uniqueidentifier NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EventTime] datetime NULL,
        [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ComponentId] int NULL,
        [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PhaseName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ReportedDurationMs] bigint NULL,
        [OutputId] int NULL,
        [OutputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ContextStartLogId] int NULL,
        [ContextEndLogId] int NULL,
        [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [InputIsTruncated] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_ComponentPhaseTimes]
    (
        [PhaseTimeOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NOT NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ContextStartLogId] int NOT NULL,
        [ContextEndLogId] int NOT NULL,
        [ComponentId] int NULL,
        [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PhaseName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [OutputId] int NULL,
        [OutputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EventCount] bigint NOT NULL,
        [ReportedDurationSumMs] decimal(38,0) NOT NULL,
        [MinReportedDurationMs] bigint NOT NULL,
        [MaxReportedDurationMs] bigint NOT NULL,
        [AvgReportedDurationMs] decimal(38,6) NOT NULL,
        [FirstObservedTime] datetime NOT NULL,
        [LastObservedTime] datetime NOT NULL,
        [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceNameConflict] bit NOT NULL,
        [ComponentNameConflict] bit NOT NULL,
        [OutputNameConflict] bit NOT NULL,
        [InputIsTruncated] bit NOT NULL,
        [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Buffer]
    ([LogId] int NOT NULL,[EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceId] uniqueidentifier NULL,
     [ExecutionId] uniqueidentifier NOT NULL,[EventTime] datetime NULL,[RawEndTime] datetime NULL,[DataCode] int NULL,
     [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Columns]
    ([ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] int NOT NULL,[MaxLength] smallint NOT NULL,[IsNullable] bit NOT NULL,[IsComputed] bit NOT NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Indexes] ([IndexId] int NOT NULL,[Supporting] bit NOT NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Pairs]
    ([LogId] int NOT NULL,[SourceId] uniqueidentifier NULL,[SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsStart] bit NOT NULL,[EventTime] datetime NULL,
     [Seq] bigint NOT NULL,[PreviousStart] bit NULL,[NextStart] bit NULL,[NextLogId] int NULL,[NextTime] datetime NULL);
    INSERT [#SsisLegacyLogAnalysis_SourceStatus]
        ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
    VALUES (1,N'sourceMetadata','NOT_READ',0,0,N'NOT_READ',@Now),(2,N'sourceIndexes','NOT_READ',0,0,N'NOT_READ',@Now),
           (3,N'sourceEvents','NOT_READ',0,0,N'NOT_READ',@Now),(4,N'eventDerivation','NOT_READ',0,0,N'NOT_READ',@Now);
    IF @IncludeTaskAnalysis=1
        INSERT [#SsisLegacyLogAnalysis_SourceStatus]
            ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
        VALUES(5,N'taskAnalysis','NOT_READ',1,0,N'NOT_READ',@Now);
    IF @IncludeRowFlowAnalysis=1
        INSERT [#SsisLegacyLogAnalysis_SourceStatus]
            ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
        VALUES(6,N'rowFlowAnalysis','NOT_READ',1,0,N'NOT_READ',@Now);
    IF @IncludeComponentPhaseAnalysis=1
        INSERT [#SsisLegacyLogAnalysis_SourceStatus]
            ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
        VALUES(7,N'componentPhaseAnalysis','NOT_READ',1,0,N'NOT_READ',@Now);
    IF @IncludeTimeline=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TIMELINE_NOT_REQUESTED',NULL,N'Der Timelineexport wurde abgeschaltet.');
    IF @IncludeMessages=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'MESSAGES_NOT_REQUESTED',NULL,N'Der fachliche Meldungstextzugriff wurde abgeschaltet.');
    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(@ResultTablesJson)),N'') IS NOT NULL)
       OR NULLIF(LTRIM(RTRIM(@LoggingDatabase)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LoggingSchema)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LoggingTable)),N'') IS NULL
       OR @ExecutionId IS NULL OR @ExecutionId='00000000-0000-0000-0000-000000000000'
       OR (@IncludeComponentLifecyclePhases=1 AND @IncludeComponentPhaseAnalysis=0)
       OR @MaxZeilen<0 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
    END;
    IF @Continue=1 AND COALESCE(@MaxZeilen,0)=0 AND @HighImpactConfirmed=0
    BEGIN
        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'HIGH_IMPACT_CONFIRMATION_REQUIRED',NULL,N'Unbegrenzte Sammlung benötigt die ausdrückliche Bestätigung.');
    END;
    SET @Deadline=DATEADD(second,CASE WHEN @MaxDurationSeconds BETWEEN 1 AND 60 THEN @MaxDurationSeconds ELSE 30 END,@Now);
    DECLARE @DatabaseId int=NULL,@ObjectId int=NULL,@Created datetime=NULL,@CurrentDb int=NULL,@CurrentObject int=NULL,@CurrentCreated datetime=NULL;
    DECLARE @Sql nvarchar(max),@Source nvarchar(780)=QUOTENAME(@LoggingDatabase)+N'.'+QUOTENAME(@LoggingSchema)+N'.'+QUOTENAME(@LoggingTable);
    DECLARE @UseDb nvarchar(300)=N'USE '+QUOTENAME(@LoggingDatabase)+N'; ';
    BEGIN TRY
        IF @Continue=1
        BEGIN
            SET XACT_ABORT OFF;
            SET LOCK_TIMEOUT 0;
        END;
        WHILE @Step<=4 AND @Continue=1
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline
            BEGIN
                SELECT @Status='AVAILABLE_LIMITED',@Partial=1,@Continue=0;
                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TIME_BUDGET_EXHAUSTED',
                    CASE @Step WHEN 1 THEN N'sourceMetadata' WHEN 2 THEN N'sourceIndexes' WHEN 3 THEN N'sourceEvents' ELSE N'eventDerivation' END,N'Das kooperative Budget ist vor diesem Schritt ausgeschöpft.');
                BREAK;
            END;
            BEGIN TRY
                IF @Step=1
                BEGIN
                    SET @Sql=@UseDb+@LockSql+N'
                        SELECT @Db=DB_ID(),@Obj=o.object_id,@Created=o.create_date
                        FROM sys.all_objects AS o WITH (NOLOCK) INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                        WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab
                          AND o.type IN (''U'',''S'') AND NOT EXISTS (SELECT 1 FROM sys.external_tables AS e WITH (NOLOCK) WHERE e.object_id=o.object_id);
                        INSERT [#SsisLegacyLogAnalysis_Columns]
                        SELECT name,system_type_id,max_length,is_nullable,is_computed FROM sys.all_columns WITH (NOLOCK) WHERE object_id=@Obj;';
                    EXEC sys.sp_executesql @Sql,N'@Sch sysname,@Tab sysname,@Db int OUTPUT,@Obj int OUTPUT,@Created datetime OUTPUT',
                        @Sch=@LoggingSchema,@Tab=@LoggingTable,@Db=@DatabaseId OUTPUT,@Obj=@ObjectId OUTPUT,@Created=@Created OUTPUT;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Columns]),
                        [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Columns]),[StatusCode]='AVAILABLE',[Detail]=N'VISIBLE_OBJECT_METADATA' WHERE [SourceOrdinal]=1;
                    IF @ObjectId IS NULL
                    BEGIN
                        SELECT @Status='SOURCE_UNAVAILABLE',@Partial=1,@Continue=0;
                        UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'OBJECT_NOT_VISIBLE_OR_ABSENT' WHERE [SourceOrdinal]=1;
                    END
                    ELSE IF EXISTS
                    (
                        SELECT 1 FROM (VALUES (N'id',56,4,4),(N'event',231,2,256),(N'source',231,2,8000),
                            (N'sourceid',36,16,16),(N'executionid',36,16,16),(N'starttime',61,8,8),(N'endtime',61,8,8),(N'datacode',56,4,4)) AS e(n,t,lo,hi)
                        LEFT JOIN [#SsisLegacyLogAnalysis_Columns] AS c ON c.ColumnName=e.n COLLATE SQL_Latin1_General_CP1_CS_AS
                        WHERE c.ColumnName IS NULL OR c.TypeId<>e.t OR c.MaxLength NOT BETWEEN e.lo AND e.hi OR c.IsComputed=1 OR (e.n=N'id' AND c.IsNullable=1)
                    ) OR (@IncludeMessages=1 AND NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message' AND TypeId=231 AND (MaxLength=-1 OR MaxLength BETWEEN 2 AND 8000) AND IsComputed=0))
                    BEGIN
                        SELECT @Status='SOURCE_UNAVAILABLE',@Partial=1,@Continue=0;
                        UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'SOURCE_SCHEMA_UNSUPPORTED' WHERE [SourceOrdinal]=1;
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_SCHEMA_UNSUPPORTED',N'sourceMetadata',N'Die eingeschlossene Projektion besitzt kein unterstütztes gespeichertes Schema.');
                    END;
                END;
                IF @Step=2
                BEGIN
                    SET @Sql=@UseDb+@LockSql+N'INSERT [#SsisLegacyLogAnalysis_Indexes]
                        SELECT i.index_id,CONVERT(bit,CASE WHEN i.type IN (1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND EXISTS
                         (SELECT 1 FROM sys.index_columns AS ic WITH (NOLOCK) INNER JOIN sys.all_columns AS c WITH (NOLOCK) ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                          WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name COLLATE SQL_Latin1_General_CP1_CS_AS=N''executionid'') THEN 1 ELSE 0 END)
                        FROM sys.indexes AS i WITH (NOLOCK) WHERE i.object_id=@Obj;';
                    EXEC sys.sp_executesql @Sql,N'@Obj int',@Obj=@ObjectId;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]='AVAILABLE',[ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Indexes]),
                        [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Indexes]),[Detail]=N'ADVISORY_INDEX_METADATA_ONLY' WHERE [SourceOrdinal]=2;
                    IF NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Indexes] WHERE Supporting=1)
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SUPPORTING_INDEX_NOT_OBSERVED',N'sourceIndexes',N'Kein führender executionid-Index beobachtet; ein Scan ist möglich. Keine Indexpflicht oder Plangarantie.');
                END;
                IF @Step=3
                BEGIN
                    IF @IncludeMessages=1 AND @HighImpactConfirmed=0 AND EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message' AND MaxLength=-1)
                    BEGIN
                        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'HIGH_IMPACT_CONFIRMATION_REQUIRED',N'sourceEvents',N'Die eingeschlossene MAX-Textquelle benötigt die ausdrückliche Bestätigung.');
                    END
                    ELSE
                    BEGIN
                        -- Only bounded identifiers are concatenated. Message opt-out has no source expression.
                        SET @Sql=@UseDb+@LockSql+N'
                          SELECT @Db=DB_ID(),@Obj=o.object_id,@Created=o.create_date FROM sys.all_objects AS o WITH (NOLOCK)
                          INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                          WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab;
                          IF @Db=@ExpectedDb AND @Obj=@ExpectedObj AND @Created=@ExpectedCreated
                          BEGIN
                            INSERT [#SsisLegacyLogAnalysis_Buffer]
                            SELECT TOP (@Take) [id],[event],[source],[sourceid],[executionid],[starttime],[endtime],[datacode],'+
                            CASE WHEN @IncludeMessages=1 THEN N'[message]' ELSE N'CONVERT(nvarchar(max),NULL)' END+N'
                            FROM '+@Source+N' WITH (NOLOCK) WHERE [executionid]=@Id ORDER BY [id];
                            SELECT @Db=DB_ID(),@Obj=NULL,@Created=NULL;
                            SELECT @Obj=o.object_id,@Created=o.create_date FROM sys.all_objects AS o WITH (NOLOCK)
                            INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                            WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab;
                          END;';
                        EXEC sys.sp_executesql @Sql,N'@Sch sysname,@Tab sysname,@Id uniqueidentifier,@Take bigint,@ExpectedDb int,@ExpectedObj int,@ExpectedCreated datetime,@Db int OUTPUT,@Obj int OUTPUT,@Created datetime OUTPUT',
                            @Sch=@LoggingSchema,@Tab=@LoggingTable,@Id=@ExecutionId,@Take=@Take,@ExpectedDb=@DatabaseId,@ExpectedObj=@ObjectId,@ExpectedCreated=@Created,
                            @Db=@CurrentDb OUTPUT,@Obj=@CurrentObject OUTPUT,@Created=@CurrentCreated OUTPUT;
                        IF @CurrentDb<>@DatabaseId OR @CurrentObject IS NULL OR @CurrentObject<>@ObjectId OR @CurrentCreated IS NULL OR @CurrentCreated<>@Created
                        BEGIN
                            SELECT @Status='ERROR_HANDLED',@Partial=1,@Continue=0;
                            INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_IDENTITY_CHANGED',N'sourceEvents',N'Die Quellenidentität wurde zwischen den Zugriffen verändert. Der Puffer wurde verworfen.');
                        END
                        ELSE IF EXISTS(SELECT LogId FROM [#SsisLegacyLogAnalysis_Buffer] GROUP BY LogId HAVING COUNT_BIG(*)>1)
                        BEGIN
                            SELECT @Status='ERROR_HANDLED',@Partial=1,@Continue=0;
                            INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'DUPLICATE_LOG_ID_OBSERVED',N'sourceEvents',N'Doppelte IDs im vollständigen N+1-Puffer; keine Deduplizierung oder erneute Abfrage.');
                        END;
                        IF @Continue=0
                        BEGIN
                            DELETE FROM [#SsisLegacyLogAnalysis_Buffer];
                            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'BUFFER_INTEGRITY_REJECTED' WHERE SourceOrdinal=3;
                        END
                        ELSE
                        BEGIN
                            DECLARE @Observed bigint=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer]);
                            IF @Observed>@Limit
                            BEGIN
                                SET @Truncated=1;
                                DELETE FROM [#SsisLegacyLogAnalysis_Buffer] WHERE LogId NOT IN(SELECT TOP (@Limit) LogId FROM [#SsisLegacyLogAnalysis_Buffer] ORDER BY LogId);
                                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_EVENTS_TRUNCATED',N'sourceEvents',N'N+1 ist eine Untergrenze; nur die ersten N Ereignisse werden abgeleitet.');
                            END;
                            SET @ValidBuffer=1;
                            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=CASE WHEN @Truncated=1 THEN 'AVAILABLE_LIMITED' WHEN @Observed=0 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
                                [IsPartial]=@Truncated,[IsTruncated]=@Truncated,[ObservedRowCount]=@Observed,[ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer]),[Detail]=N'BOUNDED_EVENT_BUFFER' WHERE SourceOrdinal=3;
                            IF @Observed=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'EXECUTION_NOT_VISIBLE_OR_ABSENT',N'sourceEvents',N'Keine sichtbaren Ereignisse für diese ID; Abwesenheit der Ausführung ist nicht bewiesen.');
                        END;
                    END;
                END;
                IF @Step=4 AND @ValidBuffer=1
                BEGIN
                    INSERT [#SsisLegacyLogAnalysis_Timeline]
                    SELECT ROW_NUMBER() OVER(ORDER BY LogId),LogId,ExecutionId,EventName,SourceName,SourceId,EventTime,RawEndTime,DataCode,
                        LAG(LogId) OVER(ORDER BY LogId),
                        CASE WHEN EventTime>=LAG(EventTime) OVER(ORDER BY LogId) THEN DATEDIFF_BIG(millisecond,LAG(EventTime) OVER(ORDER BY LogId),EventTime) END,
                        CASE EventName WHEN N'OnError' THEN 'ERROR' WHEN N'OnTaskFailed' THEN 'WARNING' WHEN N'OnWarning' THEN 'WARNING'
                             WHEN NULL THEN 'UNKNOWN' ELSE CASE WHEN EventName IS NULL THEN 'UNKNOWN' ELSE 'INFO' END END,MessageText
                    FROM [#SsisLegacyLogAnalysis_Buffer];
                    INSERT [#SsisLegacyLogAnalysis_ErrorChain]
                    SELECT ROW_NUMBER() OVER(ORDER BY LogId),LogId,ExecutionId,EventName,SourceName,SourceId,EventTime,DataCode,Severity,
                        LAG(LogId) OVER(ORDER BY LogId),'TEMPORAL_ONLY',MessageText
                    FROM [#SsisLegacyLogAnalysis_Timeline] WHERE EventName IN(N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel');

                    ;WITH e AS
                    (
                        SELECT LogId,SourceId,SourceName,EventTime,
                            CONVERT(varchar(16),CASE WHEN EventName IN(N'OnPreValidate',N'OnPostValidate') THEN 'VALIDATE'
                                 WHEN EventName IN(N'OnPreExecute',N'OnPostExecute') THEN 'EXECUTE' ELSE 'PACKAGE' END) COLLATE SQL_Latin1_General_CP1_CS_AS AS PairKind,
                            CONVERT(bit,CASE WHEN EventName IN(N'OnPreValidate',N'OnPreExecute',N'PackageStart') THEN 1 ELSE 0 END) AS IsStart
                        FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnPreValidate',N'OnPostValidate',N'OnPreExecute',N'OnPostExecute',N'PackageStart',N'PackageEnd')
                    )
                    INSERT [#SsisLegacyLogAnalysis_Pairs]
                    SELECT LogId,SourceId,SourceName,PairKind,IsStart,EventTime,
                        ROW_NUMBER() OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),
                        LAG(IsStart) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),LEAD(IsStart) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),
                        LEAD(LogId) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),LEAD(EventTime) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId)
                    FROM e;
                    ;WITH p AS
                    (
                        SELECT *,MAX(CASE WHEN IsStart=PreviousStart THEN 1 ELSE 0 END) OVER(PARTITION BY SourceId,PairKind) AS Ambiguous
                        FROM [#SsisLegacyLogAnalysis_Pairs]
                    ), r AS
                    (
                        SELECT SourceId,SourceName,PairKind,LogId,EventTime,IsStart,NextLogId,NextTime,
                            CONVERT(varchar(40),CASE WHEN SourceId IS NULL THEN 'UNRESOLVED_SOURCE' WHEN Ambiguous=1 THEN 'AMBIGUOUS'
                                WHEN IsStart=0 THEN 'END_ONLY' WHEN NextStart IS NULL THEN 'START_ONLY'
                                WHEN EventTime IS NULL OR NextTime IS NULL THEN 'PAIRED_TIME_UNKNOWN'
                                WHEN NextTime<EventTime THEN 'NON_MONOTONIC_TIME' ELSE 'PAIRED' END) COLLATE SQL_Latin1_General_CP1_CS_AS AS PairStatus
                        FROM p WHERE SourceId IS NULL OR Ambiguous=1 OR IsStart=1 OR PreviousStart IS NULL
                    )
                    INSERT [#SsisLegacyLogAnalysis_Iterations]
                    SELECT ROW_NUMBER() OVER(ORDER BY SourceId,PairKind,LogId),@ExecutionId,SourceId,SourceName,PairKind,
                        CASE WHEN IsStart=1 THEN LogId END,
                        CASE WHEN IsStart=0 THEN LogId WHEN PairStatus IN('PAIRED','PAIRED_TIME_UNKNOWN','NON_MONOTONIC_TIME') THEN NextLogId END,
                        CASE WHEN IsStart=1 THEN EventTime END,
                        CASE WHEN IsStart=0 THEN EventTime WHEN PairStatus IN('PAIRED','PAIRED_TIME_UNKNOWN','NON_MONOTONIC_TIME') THEN NextTime END,
                        CASE WHEN PairStatus='PAIRED' THEN DATEDIFF_BIG(millisecond,EventTime,NextTime) END,PairStatus,@Truncated
                    FROM r;

                    IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer])
                    BEGIN
                        DECLARE @Boundary varchar(40)='AMBIGUOUS',@PackageStart int=NULL,@PackageEnd int=NULL,@PackageMs bigint=NULL;
                        IF NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE') SET @Boundary='ABSENT';
                        ELSE IF (SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE')=1
                        BEGIN
                            SELECT @Boundary=CASE WHEN PairStatus IN('PAIRED','START_ONLY','END_ONLY') THEN PairStatus ELSE 'AMBIGUOUS' END,
                                @PackageStart=StartLogId,@PackageEnd=EndLogId,@PackageMs=DurationMs
                            FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE';
                        END;
                        INSERT [#SsisLegacyLogAnalysis_Execution]
                        SELECT @ExecutionId,COUNT_BIG(*),COUNT_BIG(DISTINCT SourceId),MIN(EventTime),MAX(EventTime),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnError' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnWarning' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnTaskFailed' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnQueryCancel' THEN 1 ELSE 0 END)),
                            @Boundary,@PackageStart,@PackageEnd,CASE WHEN @Boundary='PAIRED' THEN @PackageMs END,
                            CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnError') THEN 'ERROR_EVENT_OBSERVED'
                                 WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnTaskFailed') THEN 'TASK_FAILURE_OBSERVED'
                                 WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnQueryCancel') THEN 'CANCEL_REQUEST_OBSERVED'
                                 WHEN @Boundary='PAIRED' THEN 'COMPLETION_EVENT_PAIR_OBSERVED' ELSE 'INCOMPLETE_OR_UNRESOLVED' END,
                            NULL,NULL,CONVERT(bit,1-@Truncated)
                        FROM [#SsisLegacyLogAnalysis_Buffer];
                        UPDATE e SET FirstErrorLogId=b.LogId,FirstErrorMessage=b.MessageText
                        FROM [#SsisLegacyLogAnalysis_Execution] AS e CROSS APPLY
                          (SELECT TOP (1) LogId,MessageText FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed')
                           ORDER BY CASE WHEN EventName=N'OnError' THEN 0 ELSE 1 END,LogId) AS b;

                        INSERT [#SsisLegacyLogAnalysis_LoggingQuality]
                        SELECT 0,v.Code,v.Severity,v.Affected,v.Detail
                        FROM (VALUES
                          ('EVENT_BUFFER_TRUNCATED','WARNING',CONVERT(bigint,NULL),N'Der N+1-Puffer ist ein begrenzter Ausschnitt.',CONVERT(int,@Truncated)),
                          ('PACKAGE_BOUNDARY_ABSENT','INFO',CONVERT(bigint,NULL),N'Kein PackageStart-/PackageEnd-Ereignis beobachtet.',CASE WHEN @Boundary='ABSENT' THEN 1 ELSE 0 END),
                          ('PACKAGE_BOUNDARY_UNRESOLVED','WARNING',CONVERT(bigint,NULL),N'Keine eindeutige zeitlich gültige Paketgrenze.',CASE WHEN @Boundary NOT IN('PAIRED','ABSENT') THEN 1 ELSE 0 END),
                          ('PAIRING_AMBIGUOUS','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairStatus='AMBIGUOUS'),N'Mehrdeutige Ereignisfolgen werden nicht willkürlich gepaart.',1),
                          ('PAIRING_INCOMPLETE','WARNING',(SELECT COUNT_BIG(DISTINCT COALESCE(StartLogId,EndLogId)) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairStatus IN('START_ONLY','END_ONLY')),N'Ungepaarte beobachtete Start- oder Endereignisse; kein Nachweis eines nicht beendeten Tasks.',1),
                          ('SOURCE_ID_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE SourceId IS NULL),N'Ereignisse ohne Source-ID erlauben keine sichere Paarzuordnung.',1),
                          ('EVENT_NAME_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IS NULL),N'Ein Ereignisname fehlt.',1),
                          ('EVENT_TIME_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventTime IS NULL),N'Ein Ereigniszeitpunkt fehlt.',1),
                          ('NON_MONOTONIC_TIME','WARNING',(SELECT COUNT_BIG(*) FROM (SELECT EventTime,LAG(EventTime) OVER(ORDER BY LogId) AS PreviousTime FROM [#SsisLegacyLogAnalysis_Buffer]) AS b WHERE EventTime<PreviousTime),N'Zeitwerte sind gegenüber der protokollierten ID-Reihenfolge rückläufig.',1),
                          ('UNKNOWN_EVENT_NAME','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName NOT IN(N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel',N'OnPreValidate',N'OnPostValidate',N'OnPreExecute',N'OnPostExecute',N'PackageStart',N'PackageEnd')),N'Der gespeicherte Ereignisname besitzt hier keine eigene Interpretation.',1),
                          ('NO_ERROR_EVENTS_OBSERVED','INFO',CONVERT(bigint,NULL),N'Kein OnError beobachtet; kein Nachweis von Fehlerfreiheit.',CASE WHEN NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnError') THEN 1 ELSE 0 END),
                          ('ERROR_MESSAGE_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed') AND (MessageText IS NULL OR DATALENGTH(MessageText)=0)),N'Ein eingeschlossener Fehlertext fehlt oder ist leer; die Ursache bleibt unbekannt.',CONVERT(int,@IncludeMessages))
                        ) AS v(Code,Severity,Affected,Detail,Enabled) WHERE v.Enabled=1 AND (v.Affected IS NULL OR v.Affected>0);
                    END;
                    INSERT [#SsisLegacyLogAnalysis_LoggingQuality] VALUES(0,'CONSISTENT_SNAPSHOT_NOT_GUARANTEED','INFO',NULL,N'NOLOCK liefert keine transaktionskonsistente Momentaufnahme.');
                    ;WITH q AS(SELECT *,ROW_NUMBER() OVER(ORDER BY QualityCode) AS n FROM [#SsisLegacyLogAnalysis_LoggingQuality]) UPDATE q SET QualityOrdinal=CONVERT(int,n);
                    INSERT [#SsisLegacyLogAnalysis_Findings]
                    SELECT 0,CASE EventName WHEN N'OnError' THEN 'LEGACY_ERROR_EVENT' WHEN N'OnTaskFailed' THEN 'LEGACY_TASK_FAILED_EVENT' ELSE 'LEGACY_CANCEL_REQUEST' END,
                        CASE EventName WHEN N'OnError' THEN 'ERROR' WHEN N'OnTaskFailed' THEN 'WARNING' ELSE 'INFO' END,@ExecutionId,'RUNTIME_OBSERVED',N'Legacy event buffer',LogId,
                        N'Das Ereignis ist im begrenzten Logpuffer beobachtet; Meldungstext und zeitliche Folge belegen keine technische Root Cause.'
                    FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed',N'OnQueryCancel');
                    INSERT [#SsisLegacyLogAnalysis_Findings]
                    SELECT 0,QualityCode,Severity,@ExecutionId,'DERIVED',N'Legacy event buffer',NULL,Detail FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE Severity='WARNING';
                    ;WITH f AS(SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN LogId IS NULL THEN 1 ELSE 0 END,LogId,FindingCode) AS n FROM [#SsisLegacyLogAnalysis_Findings]) UPDATE f SET FindingOrdinal=CONVERT(int,n);
                    DECLARE @DerivedPartial bit=CASE WHEN @Truncated=1 OR EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE Severity='WARNING') THEN 1 ELSE 0 END;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=CASE WHEN @DerivedPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
                        [IsPartial]=@DerivedPartial,[Detail]=N'DERIVATION_COMPLETE' WHERE SourceOrdinal=4;
                    SET @DerivationComplete=1;
                END;
            END TRY
            BEGIN CATCH
                DECLARE @NativeError int=ERROR_NUMBER(),@NativeMessage nvarchar(4000)=ERROR_MESSAGE();
                DECLARE @NativeStatus varchar(40)=CASE WHEN @NativeError IN(229,262,297,300,371) THEN 'DENIED'
                    WHEN @NativeError IN(207,208,911,916,942) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END;
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@NativeStatus,[IsPartial]=1,[ErrorNumber]=@NativeError,[ErrorMessage]=@NativeMessage,
                    [ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,[Detail]=N'NATIVE_SOURCE_ERROR' WHERE SourceOrdinal=@Step;
                IF @Error IS NULL SELECT @Error=@NativeError,@Message=@NativeMessage;
                SET @Partial=1;
                IF @Step=2
                    INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_INDEX_METADATA_UNAVAILABLE',N'sourceIndexes',N'Die beratende Indexdiagnose ist fehlgeschlagen; die erforderliche Ereignissammlung wird fortgesetzt.');
                ELSE SELECT @Status=@NativeStatus,@Continue=0;
                IF @Step=3 DELETE FROM [#SsisLegacyLogAnalysis_Buffer];
                IF @Step=4
                BEGIN
                    DELETE FROM [#SsisLegacyLogAnalysis_Execution];
                    DELETE FROM [#SsisLegacyLogAnalysis_Timeline];
                    DELETE FROM [#SsisLegacyLogAnalysis_ErrorChain];
                    DELETE FROM [#SsisLegacyLogAnalysis_Iterations];
                    DELETE FROM [#SsisLegacyLogAnalysis_LoggingQuality];
                    DELETE FROM [#SsisLegacyLogAnalysis_Findings];
                END;
            END CATCH;
            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET CollectionTimeUtc=SYSUTCDATETIME() WHERE SourceOrdinal=@Step;
            SET @Step+=1;
        END;
        -- BEGIN TASK ANALYSIS: original event derivation must have completed, even for an empty buffer.
        IF @IncludeTaskAnalysis=1
        BEGIN
            DECLARE @TaskReason nvarchar(2000)=CASE WHEN @Status='INVALID_PARAMETER' THEN N'INVALID_PARAMETER'
                WHEN @ValidBuffer=0 THEN N'NO_VALID_EVENT_BUFFER' WHEN @DerivationComplete=0 THEN N'PRIOR_DERIVATION_NOT_COMPLETED'
                WHEN SYSUTCDATETIME()>=@Deadline THEN N'TIME_BUDGET_EXHAUSTED' END;
            IF @TaskReason IS NULL
            BEGIN TRY
                SET @TaskStarted=1;
                ;WITH g AS
                (
                    SELECT SourceId,CASE WHEN SourceId IS NULL THEN LogId END AS UnresolvedLogId,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN NULL ELSE MAX(SourceName) END AS SourceName,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN 1 ELSE 0 END) AS NameConflict,
                        MIN(LogId) AS FirstId,MAX(LogId) AS LastId,
                        N'['+STRING_AGG(CONVERT(nvarchar(max),LogId),N',') WITHIN GROUP(ORDER BY LogId)+N']' AS EvidenceIds,
                        COUNT_BIG(*) AS EventCount,
                        SUM(CONVERT(bigint,CASE WHEN EventName=N'OnPreExecute' THEN 1 ELSE 0 END)) AS ExecuteStarts,
                        SUM(CONVERT(bigint,CASE WHEN EventName=N'OnPostExecute' THEN 1 ELSE 0 END)) AS ExecuteEnds,
                        SUM(CONVERT(bigint,CASE WHEN EventName=N'OnPreValidate' THEN 1 ELSE 0 END)) AS ValidateStarts,
                        SUM(CONVERT(bigint,CASE WHEN EventName=N'OnPostValidate' THEN 1 ELSE 0 END)) AS ValidateEnds,
                        SUM(CONVERT(bigint,CASE WHEN EventName IN(N'PackageStart',N'PackageEnd',N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel') THEN 1 ELSE 0 END)) AS KnownOther,
                        SUM(CONVERT(bigint,CASE WHEN EventName NOT IN(N'OnPreExecute',N'OnPostExecute',N'OnPreValidate',N'OnPostValidate',N'PackageStart',N'PackageEnd',N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel') THEN 1 ELSE 0 END)) AS UnknownNames,
                        SUM(CONVERT(bigint,CASE WHEN EventName IS NULL THEN 1 ELSE 0 END)) AS MissingNames,
                        SUM(CONVERT(bigint,CASE WHEN EventTime IS NULL THEN 1 ELSE 0 END)) AS MissingTimes
                    FROM [#SsisLegacyLogAnalysis_Buffer]
                    GROUP BY SourceId,CASE WHEN SourceId IS NULL THEN LogId END
                )
                INSERT [#SsisLegacyLogAnalysis_TaskLoggingCoverage]
                SELECT ROW_NUMBER() OVER(ORDER BY CASE WHEN g.SourceId IS NULL THEN 1 ELSE 0 END,g.SourceId,g.UnresolvedLogId),
                    @ExecutionId,g.SourceId,g.UnresolvedLogId,g.SourceName,'UNRESOLVED',g.FirstId,g.LastId,g.EvidenceIds,
                    g.EventCount,g.ExecuteStarts,g.ExecuteEnds,g.ValidateStarts,g.ValidateEnds,g.KnownOther,g.UnknownNames,g.MissingNames,g.MissingTimes,
                    a.Ambiguous,CASE WHEN g.SourceId IS NULL THEN g.ExecuteStarts+g.ExecuteEnds+g.ValidateStarts+g.ValidateEnds ELSE 0 END,
                    a.Incomplete,a.InvalidTime,g.NameConflict,@Truncated,
                    CASE WHEN g.SourceId IS NULL THEN 'UNRESOLVED_SOURCE' WHEN @Truncated=1 THEN 'TRUNCATED_INPUT'
                         WHEN a.Ambiguous>0 THEN 'AMBIGUOUS_BOUNDARIES' WHEN a.Incomplete>0 THEN 'INCOMPLETE_BOUNDARIES'
                         WHEN a.InvalidTime>0 THEN 'INVALID_BOUNDARY_TIME'
                         WHEN g.ExecuteStarts+g.ExecuteEnds+g.ValidateStarts+g.ValidateEnds=0 THEN 'NO_BOUNDARY_OBSERVED' ELSE 'OBSERVED_BOUNDARIES' END
                FROM g OUTER APPLY
                (
                    SELECT COALESCE(SUM(CONVERT(bigint,CASE WHEN PairStatus='AMBIGUOUS' THEN 1 ELSE 0 END)),0) AS Ambiguous,
                        COALESCE(SUM(CONVERT(bigint,CASE WHEN PairStatus IN('START_ONLY','END_ONLY') THEN 1 ELSE 0 END)),0) AS Incomplete,
                        COALESCE(SUM(CONVERT(bigint,CASE WHEN PairStatus IN('PAIRED_TIME_UNKNOWN','NON_MONOTONIC_TIME') THEN 1 ELSE 0 END)),0) AS InvalidTime
                    FROM [#SsisLegacyLogAnalysis_Iterations] AS i WHERE i.SourceId=g.SourceId AND i.PairKind IN('EXECUTE','VALIDATE')
                ) AS a;
                ;WITH a AS
                (
                    SELECT SourceId,PairKind,COUNT_BIG(*) AS PairRows,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='PAIRED' AND DurationMs>=0 THEN 1 ELSE 0 END)) AS ValidPairs,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='PAIRED_TIME_UNKNOWN' THEN 1 ELSE 0 END)) AS UnknownPairs,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='NON_MONOTONIC_TIME' THEN 1 ELSE 0 END)) AS NonMonotonicPairs,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='START_ONLY' THEN 1 ELSE 0 END)) AS OpenStarts,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='END_ONLY' THEN 1 ELSE 0 END)) AS OpenEnds,
                        SUM(CONVERT(bigint,CASE WHEN PairStatus='AMBIGUOUS' THEN 1 ELSE 0 END)) AS Ambiguous,
                        SUM(CASE WHEN PairStatus='PAIRED' AND DurationMs>=0 THEN CONVERT(decimal(38,0),DurationMs) END) AS TotalMs,
                        MIN(CASE WHEN PairStatus='PAIRED' AND DurationMs>=0 THEN DurationMs END) AS MinMs,
                        MAX(CASE WHEN PairStatus='PAIRED' AND DurationMs>=0 THEN DurationMs END) AS MaxMs
                    FROM [#SsisLegacyLogAnalysis_Iterations] WHERE SourceId IS NOT NULL AND PairKind IN('EXECUTE','VALIDATE')
                    GROUP BY SourceId,PairKind
                ), e AS
                (
                    SELECT SourceId,PairKind,MIN(LogId) AS FirstId,MAX(LogId) AS LastId,
                        N'['+STRING_AGG(CONVERT(nvarchar(max),LogId),N',') WITHIN GROUP(ORDER BY LogId)+N']' AS EvidenceIds
                    FROM [#SsisLegacyLogAnalysis_Pairs] WHERE SourceId IS NOT NULL AND PairKind IN('EXECUTE','VALIDATE')
                    GROUP BY SourceId,PairKind
                )
                INSERT [#SsisLegacyLogAnalysis_TaskDurations]
                SELECT ROW_NUMBER() OVER(ORDER BY a.SourceId,a.PairKind),@ExecutionId,a.SourceId,c.SourceName,'UNRESOLVED',a.PairKind,
                    e.FirstId,e.LastId,e.EvidenceIds,a.PairRows,a.ValidPairs,a.UnknownPairs,a.NonMonotonicPairs,a.OpenStarts,a.OpenEnds,a.Ambiguous,
                    a.TotalMs,CONVERT(decimal(38,6),a.TotalMs/NULLIF(CONVERT(decimal(19,0),a.ValidPairs),0)),a.MinMs,a.MaxMs,c.SourceNameConflict,@Truncated,
                    CASE WHEN @Truncated=1 THEN 'TRUNCATED_INPUT' WHEN a.Ambiguous>0 THEN 'AMBIGUOUS_BOUNDARIES'
                         WHEN a.OpenStarts+a.OpenEnds>0 THEN 'INCOMPLETE_BOUNDARIES' WHEN a.UnknownPairs+a.NonMonotonicPairs>0 THEN 'INVALID_BOUNDARY_TIME'
                         WHEN a.ValidPairs=0 THEN 'NO_VALID_PAIRS' ELSE 'OBSERVED_INTERVALS' END
                FROM a INNER JOIN e ON e.SourceId=a.SourceId AND e.PairKind=a.PairKind
                INNER JOIN [#SsisLegacyLogAnalysis_TaskLoggingCoverage] AS c ON c.SourceId=a.SourceId;
                IF SYSUTCDATETIME()>=@Deadline SET @TaskReason=N'TIME_BUDGET_EXHAUSTED';
                ELSE
                BEGIN
                    SELECT @TaskSources=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage] WHERE SourceId IS NOT NULL;
                    SELECT @TaskValid=COALESCE(SUM(ValidPairCount),0) FROM [#SsisLegacyLogAnalysis_TaskDurations];
                    SELECT @TaskUnresolved=COALESCE(SUM(AmbiguousBoundaryCount+UnresolvedBoundaryCount+IncompleteBoundaryCount),0)
                        FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage];
                    DECLARE @TaskLimited bit=CASE WHEN @Truncated=1 OR EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage]
                        WHERE SourceId IS NULL OR SourceNameConflict=1 OR AmbiguousBoundaryCount>0 OR IncompleteBoundaryCount>0 OR InvalidTimePairCount>0) THEN 1 ELSE 0 END;
                    DECLARE @TaskRows bigint=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_TaskDurations])+(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage]);
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @TaskRows=0 THEN 'AVAILABLE_EMPTY' WHEN @TaskLimited=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
                        IsPartial=@TaskLimited,ObservedRowCount=@TaskRows,ReturnedRowCount=@TaskRows,Detail=N'OBSERVED_SOURCE_INTERVALS_ONLY' WHERE SourceOrdinal=5;
                    IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage] WHERE SourceNameConflict=1)
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TASK_ANALYSIS_SOURCE_NAME_CONFLICT',N'taskAnalysis',N'Ordinal verschiedene Namen derselben Source-ID; kein Anzeigename ausgewählt.');
                    SET @TaskComplete=1;
                END;
            END TRY
            BEGIN CATCH
                DECLARE @TaskError int=ERROR_NUMBER(),@TaskMessage nvarchar(4000)=ERROR_MESSAGE();
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @TaskError IN(229,262,297,300,371) THEN 'DENIED'
                    WHEN @TaskError IN(207,208,911,916,942) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                    IsPartial=1,ErrorNumber=@TaskError,ErrorMessage=@TaskMessage,Detail=N'NATIVE_SOURCE_ERROR' WHERE SourceOrdinal=5;
                IF @Error IS NULL SELECT @Error=@TaskError,@Message=@TaskMessage;
                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TASK_ANALYSIS_ERROR',N'taskAnalysis',N'Die Zusatzableitung ist fehlgeschlagen; gültige vorherige Mengen bleiben erhalten.');
            END CATCH;
            IF @TaskComplete=0
            BEGIN
                DELETE FROM [#SsisLegacyLogAnalysis_TaskDurations];
                DELETE FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage];
                SELECT @TaskSources=NULL,@TaskValid=NULL,@TaskUnresolved=NULL;
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET ObservedRowCount=NULL,ReturnedRowCount=NULL,IsTruncated=0,
                    StatusCode=CASE WHEN @TaskReason=N'TIME_BUDGET_EXHAUSTED' AND @TaskStarted=1 THEN 'AVAILABLE_LIMITED' ELSE StatusCode END,
                    Detail=COALESCE(@TaskReason,Detail) WHERE SourceOrdinal=5;
                IF @TaskReason=N'TIME_BUDGET_EXHAUSTED'
                    INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TASK_ANALYSIS_TIME_BUDGET_EXHAUSTED',N'taskAnalysis',N'Die Zusatzableitung wurde nicht innerhalb des kooperativen Budgets übernommen.');
            END;
            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET CollectionTimeUtc=SYSUTCDATETIME() WHERE SourceOrdinal=5;
            IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_SourceStatus] WHERE SourceOrdinal=5 AND IsPartial=1)
            BEGIN
                SET @Partial=1;
                IF @Status IN('AVAILABLE','AVAILABLE_EMPTY','AVAILABLE_LIMITED') SET @Status='AVAILABLE_LIMITED';
            END;
        END;
        -- END TASK ANALYSIS
        -- BEGIN ROW FLOW ANALYSIS: only the validated buffer and completed v1 pairs are consumed.
        IF @IncludeRowFlowAnalysis=1
        BEGIN
            DECLARE @RowReason nvarchar(2000)=CASE WHEN @Status='INVALID_PARAMETER' THEN N'INVALID_PARAMETER'
                WHEN @ValidBuffer=0 THEN N'NO_VALID_EVENT_BUFFER' WHEN @DerivationComplete=0 THEN N'PRIOR_DERIVATION_NOT_COMPLETED'
                WHEN @IncludeMessages=0 THEN N'MESSAGES_DISABLED' WHEN SYSUTCDATETIME()>=@Deadline THEN N'TIME_BUDGET_EXHAUSTED' END;
            IF @RowReason IS NULL
            BEGIN TRY
                SET @RowStarted=1;
                DECLARE @RowMessageBytes int=(SELECT CASE WHEN MaxLength=-1 OR MaxLength>4096 THEN 4096 ELSE MaxLength END
                    FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message');
                DECLARE @RowPrefix nvarchar(100)=N'Rows were provided to a data flow component as input. : : ';
                DECLARE @RowPrefix2 nvarchar(100)=N'Rows were provided to a data flow component as input. :  : ';
                INSERT [#SsisLegacyLogAnalysis_RowFlowEvents]
                SELECT ROW_NUMBER() OVER(ORDER BY LogId),@ExecutionId,LogId,SourceId,SourceName,EventTime,
                    CASE WHEN MessageText IS NOT NULL AND DATALENGTH(MessageText)<@RowMessageBytes
                        AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,LEN(@RowPrefix+N'#')-1))=CONVERT(varbinary(max),@RowPrefix) THEN 'ORPS_EN_1'
                         WHEN MessageText IS NOT NULL AND DATALENGTH(MessageText)<@RowMessageBytes
                         AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,LEN(@RowPrefix2+N'#')-1))=CONVERT(varbinary(max),@RowPrefix2) THEN 'ORPS_EN_2' END,
                    CASE WHEN MessageText IS NULL THEN 'MESSAGE_MISSING'
                         WHEN DATALENGTH(MessageText)>=@RowMessageBytes THEN 'POTENTIALLY_TRUNCATED'
                         WHEN CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,LEN(@RowPrefix+N'#')-1))<>CONVERT(varbinary(max),@RowPrefix)
                          AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,LEN(@RowPrefix2+N'#')-1))<>CONVERT(varbinary(max),@RowPrefix2) THEN 'UNSUPPORTED_FORMAT'
                         ELSE 'MALFORMED_PAYLOAD' END,
                    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'NOT_PARSED',@Truncated
                FROM [#SsisLegacyLogAnalysis_Buffer]
                WHERE CONVERT(varbinary(max),EventName)=CONVERT(varbinary(max),N'OnPipelineRowsSent');

                ;WITH tokens AS
                (
                    SELECT e.LogId,e.ParserId,CONVERT(int,j.[key]) AS TokenOrdinal,j.[value] COLLATE SQL_Latin1_General_CP1_CS_AS AS TokenValue
                    FROM [#SsisLegacyLogAnalysis_RowFlowEvents] AS e
                    INNER JOIN [#SsisLegacyLogAnalysis_Buffer] AS b ON b.LogId=e.LogId
                    CROSS APPLY OPENJSON(N'["'+REPLACE(STRING_ESCAPE(SUBSTRING(b.MessageText COLLATE Latin1_General_100_BIN2,CASE WHEN e.ParserId='ORPS_EN_2' THEN LEN(@RowPrefix2+N'#') ELSE LEN(@RowPrefix+N'#') END,2147483647),'json'),N' : ',N'","')+N'"]') AS j
                    WHERE e.ParserId IN('ORPS_EN_1','ORPS_EN_2')
                ), payload AS
                (
                    SELECT LogId,ParserId,COUNT_BIG(*) AS TokenCount,
                        MAX(CASE WHEN TokenOrdinal=0 THEN TokenValue END) AS PathToken,
                        MAX(CASE WHEN TokenOrdinal=1 THEN TokenValue END) AS PathTokenName,
                        MAX(CASE WHEN TokenOrdinal=2 THEN TokenValue END) AS ComponentToken,
                        MAX(CASE WHEN TokenOrdinal=3 THEN TokenValue END) AS ComponentTokenName,
                        MAX(CASE WHEN TokenOrdinal=4 THEN TokenValue END) AS InputToken,
                        MAX(CASE WHEN TokenOrdinal=5 THEN TokenValue END) AS InputTokenName,
                        MAX(CASE WHEN TokenOrdinal=6 THEN TokenValue END) AS RowsToken,
                        MAX(CASE WHEN TokenOrdinal=7 THEN TokenValue END) AS RepeatedComponent,
                        MAX(CASE WHEN TokenOrdinal=8 THEN TokenValue END) AS PathForm,
                        MAX(CASE WHEN TokenOrdinal=9 THEN TokenValue END) AS InputForm,
                        MAX(CASE WHEN TokenOrdinal=10 THEN TokenValue END) AS EndToken,
                        MAX(CASE WHEN TokenOrdinal IN(0,2,4,6) AND (DATALENGTH(TokenValue)=0
                            OR TokenValue COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
                            OR (DATALENGTH(TokenValue)>2 AND LEFT(TokenValue,1)=N'0')) THEN 1
                            WHEN TokenOrdinal IN(1,3,5) AND (DATALENGTH(TokenValue) NOT BETWEEN 2 AND 8000
                            OR CHARINDEX(N':',TokenValue)>0 OR CHARINDEX(NCHAR(13),TokenValue)>0 OR CHARINDEX(NCHAR(10),TokenValue)>0 OR CHARINDEX(NCHAR(9),TokenValue)>0
                            OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(TokenValue,'json'),N'\\',N''))>0) THEN 1 ELSE 0 END) AS BadShape
                    FROM tokens GROUP BY LogId,ParserId
                ), parsed AS
                (
                    SELECT *,TRY_CONVERT(int,PathToken) AS ParsedPath,TRY_CONVERT(int,ComponentToken) AS ParsedComponent,
                        TRY_CONVERT(int,InputToken) AS ParsedInput,TRY_CONVERT(bigint,RowsToken) AS ParsedRows
                    FROM payload
                ), checked AS
                (
                    SELECT *,CASE WHEN BadShape=1 OR (ParserId='ORPS_EN_1' AND TokenCount<>7)
                        OR (ParserId='ORPS_EN_2' AND (TokenCount<>11 OR DATALENGTH(EndToken)<>0
                            OR CONVERT(varbinary(max),RepeatedComponent)<>CONVERT(varbinary(max),ComponentTokenName)
                            OR DATALENGTH(PathForm)<16
                            OR CONVERT(varbinary(max),LEFT(PathForm COLLATE Latin1_General_100_BIN2,6))<>CONVERT(varbinary(max),N'Paths[')
                            OR CONVERT(varbinary(max),RIGHT(PathForm COLLATE Latin1_General_100_BIN2,1))<>CONVERT(varbinary(max),N']')
                            OR CHARINDEX(N':',PathForm)>0 OR CHARINDEX(NCHAR(13),PathForm)>0 OR CHARINDEX(NCHAR(10),PathForm)>0 OR CHARINDEX(NCHAR(9),PathForm)>0
                            OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(PathForm,'json'),N'\\',N''))>0
                            OR CHARINDEX(N'[',SUBSTRING(PathForm COLLATE Latin1_General_100_BIN2,7,CASE WHEN DATALENGTH(PathForm)>=14 THEN DATALENGTH(PathForm)/2-7 ELSE 0 END))>0
                            OR CHARINDEX(N']',SUBSTRING(PathForm COLLATE Latin1_General_100_BIN2,7,CASE WHEN DATALENGTH(PathForm)>=14 THEN DATALENGTH(PathForm)/2-7 ELSE 0 END))>0
                            OR CONVERT(varbinary(max),InputForm)<>CONVERT(varbinary(max),ComponentTokenName+N'.Inputs['+InputTokenName+N']')))
                        THEN 'MALFORMED_PAYLOAD'
                        WHEN ParsedPath IS NULL OR ParsedPath<1 OR ParsedComponent IS NULL OR ParsedComponent<1 OR ParsedInput IS NULL OR ParsedInput<1 OR ParsedRows IS NULL THEN 'NUMERIC_OUT_OF_RANGE'
                        ELSE 'PARSED' END AS FinalParseStatus FROM parsed
                )
                UPDATE e SET ParseStatus=p.FinalParseStatus,
                    PathId=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedPath END,
                    PathName=CASE WHEN p.FinalParseStatus='PARSED' THEN p.PathTokenName END,
                    DestinationComponentId=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedComponent END,
                    DestinationComponentName=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ComponentTokenName END,
                    InputId=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedInput END,
                    InputName=CASE WHEN p.FinalParseStatus='PARSED' THEN p.InputTokenName END,
                    RowsSent=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedRows END
                FROM [#SsisLegacyLogAnalysis_RowFlowEvents] AS e INNER JOIN checked AS p ON p.LogId=e.LogId;

                UPDATE e SET GroupingStatus=g.FinalGroupingStatus,
                    OccurrenceStartLogId=CASE WHEN g.FinalGroupingStatus='ASSIGNED' THEN p.StartId END,
                    OccurrenceEndLogId=CASE WHEN g.FinalGroupingStatus='ASSIGNED' THEN p.EndId END
                FROM [#SsisLegacyLogAnalysis_RowFlowEvents] AS e OUTER APPLY
                (
                    SELECT COUNT_BIG(*) AS PairCount,MIN(StartLogId) AS StartId,MIN(EndLogId) AS EndId,MIN(StartTime) AS PairStart,MIN(EndTime) AS PairEnd
                    FROM [#SsisLegacyLogAnalysis_Iterations] AS i
                    WHERE i.SourceId=e.SourceId AND i.PairKind='EXECUTE' AND i.PairStatus='PAIRED' AND i.StartLogId<e.LogId AND e.LogId<i.EndLogId
                ) AS p CROSS APPLY
                (
                    SELECT CASE WHEN e.ParseStatus<>'PARSED' THEN 'NOT_PARSED' WHEN e.SourceId IS NULL THEN 'SOURCE_ID_MISSING'
                        WHEN e.EventTime IS NULL THEN 'EVENT_TIME_MISSING' WHEN p.PairCount=0 THEN 'NO_OBSERVED_PAIR'
                        WHEN p.PairCount>1 THEN 'AMBIGUOUS_PAIR' WHEN e.EventTime<p.PairStart OR e.EventTime>p.PairEnd THEN 'TIME_OUTSIDE_PAIR' ELSE 'ASSIGNED' END AS FinalGroupingStatus
                ) AS g;
                ;WITH g AS
                (
                    SELECT ExecutionId,SourceId,OccurrenceStartLogId,OccurrenceEndLogId,PathId,DestinationComponentId,InputId,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN NULL ELSE MAX(SourceName) END AS SourceName,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),PathName))>1 THEN NULL ELSE MAX(PathName) END AS PathName,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),DestinationComponentName))>1 THEN NULL ELSE MAX(DestinationComponentName) END AS DestinationComponentName,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),InputName))>1 THEN NULL ELSE MAX(InputName) END AS InputName,
                        COUNT_BIG(*) AS EventCount,SUM(CONVERT(decimal(38,0),RowsSent)) AS RowsSentSum,MIN(RowsSent) AS MinRowsSent,MAX(RowsSent) AS MaxRowsSent,
                        MIN(EventTime) AS FirstObservedTime,MAX(EventTime) AS LastObservedTime,
                        N'['+STRING_AGG(CONVERT(nvarchar(max),LogId),N',') WITHIN GROUP(ORDER BY LogId)+N']' AS EvidenceLogIdsJson,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN 1 ELSE 0 END) AS SourceNameConflict,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),PathName))>1 THEN 1 ELSE 0 END) AS PathNameConflict,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),DestinationComponentName))>1 THEN 1 ELSE 0 END) AS DestinationNameConflict,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),InputName))>1 THEN 1 ELSE 0 END) AS InputNameConflict
                    FROM [#SsisLegacyLogAnalysis_RowFlowEvents] WHERE GroupingStatus='ASSIGNED'
                    GROUP BY ExecutionId,SourceId,OccurrenceStartLogId,OccurrenceEndLogId,PathId,DestinationComponentId,InputId
                )
                INSERT [#SsisLegacyLogAnalysis_RowFlow]
                SELECT ROW_NUMBER() OVER(ORDER BY SourceId,OccurrenceStartLogId,OccurrenceEndLogId,PathId,DestinationComponentId,InputId),
                    ExecutionId,SourceId,SourceName,OccurrenceStartLogId,OccurrenceEndLogId,PathId,PathName,DestinationComponentId,DestinationComponentName,InputId,InputName,
                    EventCount,RowsSentSum,MinRowsSent,MaxRowsSent,FirstObservedTime,LastObservedTime,EvidenceLogIdsJson,
                    SourceNameConflict,PathNameConflict,DestinationNameConflict,InputNameConflict,@Truncated,
                    CASE WHEN SourceNameConflict=1 OR PathNameConflict=1 OR DestinationNameConflict=1 OR InputNameConflict=1 THEN 'OBSERVED_NAME_CONFLICT'
                         WHEN @Truncated=1 THEN 'OBSERVED_PREFIX' ELSE 'OBSERVED_TRANSFERS' END
                FROM g;
                IF SYSUTCDATETIME()>=@Deadline SET @RowReason=N'TIME_BUDGET_EXHAUSTED';
                ELSE
                BEGIN
                    SELECT @RowCandidates=COUNT_BIG(*),@RowParsed=COALESCE(SUM(CONVERT(bigint,CASE WHEN ParseStatus='PARSED' THEN 1 ELSE 0 END)),0),
                        @RowAssigned=COALESCE(SUM(CONVERT(bigint,CASE WHEN GroupingStatus='ASSIGNED' THEN 1 ELSE 0 END)),0)
                    FROM [#SsisLegacyLogAnalysis_RowFlowEvents];
                    DECLARE @RowGroups bigint=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_RowFlow]);
                    DECLARE @RowConflict bit=CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_RowFlow]
                        WHERE SourceNameConflict=1 OR PathNameConflict=1 OR DestinationNameConflict=1 OR InputNameConflict=1) THEN 1 ELSE 0 END;
                    DECLARE @RowLimited bit=CASE WHEN @Truncated=1 OR @RowParsed<@RowCandidates OR @RowAssigned<@RowParsed OR @RowConflict=1 THEN 1 ELSE 0 END;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @RowCandidates=0 THEN 'AVAILABLE_EMPTY' WHEN @RowLimited=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
                        IsPartial=CASE WHEN @RowCandidates=0 THEN 0 ELSE @RowLimited END,ObservedRowCount=@RowCandidates+@RowGroups,ReturnedRowCount=@RowCandidates+@RowGroups,
                        Detail=N'Candidates='+CONVERT(nvarchar(20),@RowCandidates)+N';Parsed='+CONVERT(nvarchar(20),@RowParsed)+N';Assigned='+CONVERT(nvarchar(20),@RowAssigned)+N';Groups='+CONVERT(nvarchar(20),@RowGroups)
                    WHERE SourceOrdinal=6;
                    IF @RowCandidates=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_EVENT_NOT_OBSERVED',N'rowFlowAnalysis',N'Keine OnPipelineRowsSent-Meldung beobachtet; keine Aussage über tatsächliche Zeilenmenge oder Loggingkonfiguration.');
                    IF @RowParsed<@RowCandidates INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_PAYLOAD_NOT_PARSED',N'rowFlowAnalysis',N'Mindestens ein Kandidat entspricht nicht dem zugelassenen vollständigen Payloadprofil.');
                    IF @RowAssigned<@RowParsed INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_OCCURRENCE_NOT_ASSIGNED',N'rowFlowAnalysis',N'Mindestens ein lesbarer Kandidat besitzt kein eindeutiges zeitlich einschließendes EXECUTE-Paar.');
                    IF @RowConflict=1 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_NAME_CONFLICT',N'rowFlowAnalysis',N'Ordinal verschiedene beitragende Namen; der betroffene Gruppenname bleibt NULL.');
                    SET @RowComplete=1;
                END;
            END TRY
            BEGIN CATCH
                DECLARE @RowError int=ERROR_NUMBER(),@RowMessage nvarchar(4000)=ERROR_MESSAGE();
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @RowError IN(229,262,297,300,371) THEN 'DENIED'
                    WHEN @RowError IN(207,208,911,916,942) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                    IsPartial=1,ErrorNumber=@RowError,ErrorMessage=@RowMessage,Detail=N'NATIVE_SOURCE_ERROR' WHERE SourceOrdinal=6;
                IF @Error IS NULL SELECT @Error=@RowError,@Message=@RowMessage;
                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_ANALYSIS_ERROR',N'rowFlowAnalysis',N'Die Zeilenflussableitung ist fehlgeschlagen; gültige vorherige Mengen bleiben erhalten.');
            END CATCH;
            IF @RowComplete=0
            BEGIN
                DELETE FROM [#SsisLegacyLogAnalysis_RowFlowEvents];
                DELETE FROM [#SsisLegacyLogAnalysis_RowFlow];
                SELECT @RowCandidates=NULL,@RowParsed=NULL,@RowAssigned=NULL;
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET ObservedRowCount=NULL,ReturnedRowCount=NULL,IsTruncated=0,
                    StatusCode=CASE WHEN @RowReason=N'TIME_BUDGET_EXHAUSTED' AND @RowStarted=1 THEN 'AVAILABLE_LIMITED' ELSE StatusCode END,
                    Detail=COALESCE(@RowReason,Detail) WHERE SourceOrdinal=6;
                IF @RowReason=N'MESSAGES_DISABLED' INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_MESSAGES_DISABLED',N'rowFlowAnalysis',N'Der Meldungstextzugriff und damit der Zeilenflussdecoder sind abgeschaltet.');
                IF @RowReason=N'TIME_BUDGET_EXHAUSTED' INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'ROWFLOW_TIME_BUDGET_EXHAUSTED',N'rowFlowAnalysis',N'Die Zeilenflussableitung wurde nicht innerhalb des kooperativen Budgets übernommen.');
            END;
            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET CollectionTimeUtc=SYSUTCDATETIME() WHERE SourceOrdinal=6;
            IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_SourceStatus] WHERE SourceOrdinal=6 AND IsPartial=1)
            BEGIN
                SET @Partial=1;
                IF @Status IN('AVAILABLE','AVAILABLE_EMPTY','AVAILABLE_LIMITED') SET @Status='AVAILABLE_LIMITED';
            END;
        END;
        -- END ROW FLOW ANALYSIS
        -- BEGIN COMPONENT PHASE ANALYSIS: reported method values and report contexts remain distinct.
        IF @IncludeComponentPhaseAnalysis=1
        BEGIN
            DECLARE @PhaseReason nvarchar(2000)=CASE WHEN @Status='INVALID_PARAMETER' THEN N'INVALID_PARAMETER'
                WHEN @ValidBuffer=0 THEN N'NO_VALID_EVENT_BUFFER' WHEN @DerivationComplete=0 THEN N'PRIOR_DERIVATION_NOT_COMPLETED'
                WHEN @IncludeMessages=0 THEN N'MESSAGES_DISABLED' WHEN SYSUTCDATETIME()>=@Deadline THEN N'TIME_BUDGET_EXHAUSTED' END;
            IF @PhaseReason IS NULL
            BEGIN TRY
                SET @PhaseStarted=1;
                DECLARE @PhaseMessageBytes int=(SELECT CASE WHEN MaxLength=-1 OR MaxLength>4096 THEN 4096 ELSE MaxLength END
                    FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message');
                DECLARE @PhasePrefix nvarchar(32)=N'The component "';
                INSERT [#SsisLegacyLogAnalysis_ComponentPhaseEvents]
                SELECT ROW_NUMBER() OVER(ORDER BY LogId),@ExecutionId,LogId,SourceId,SourceName,EventTime,
                    CASE WHEN MessageText IS NOT NULL AND DATALENGTH(MessageText)<@PhaseMessageBytes THEN
                        CASE WHEN CONVERT(varbinary(max),EventName)=CONVERT(varbinary(max),N'PipelineComponentTime')
                                  AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,15))=CONVERT(varbinary(max),@PhasePrefix) THEN 'PCT_EN_1'
                             WHEN CONVERT(varbinary(max),EventName)=CONVERT(varbinary(max),N'User:PipelineComponentTime')
                                  AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,4))=CONVERT(varbinary(max),N'The ') THEN CASE WHEN @IncludeComponentLifecyclePhases=1 THEN 'PCT_EN_3' ELSE 'PCT_EN_2' END END END,
                    CASE WHEN MessageText IS NULL THEN 'MESSAGE_MISSING'
                         WHEN DATALENGTH(MessageText)>=@PhaseMessageBytes THEN 'POTENTIALLY_TRUNCATED'
                         WHEN (CONVERT(varbinary(max),EventName)=CONVERT(varbinary(max),N'PipelineComponentTime')
                                  AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,15))=CONVERT(varbinary(max),@PhasePrefix))
                           OR (CONVERT(varbinary(max),EventName)=CONVERT(varbinary(max),N'User:PipelineComponentTime')
                                  AND CONVERT(varbinary(max),LEFT(MessageText COLLATE Latin1_General_100_BIN2,4))=CONVERT(varbinary(max),N'The ')) THEN 'MALFORMED_PAYLOAD'
                         ELSE 'UNSUPPORTED_FORMAT' END,
                    NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'NOT_PARSED',@Truncated
                FROM [#SsisLegacyLogAnalysis_Buffer]
                WHERE CONVERT(varbinary(max),EventName) IN(CONVERT(varbinary(max),N'PipelineComponentTime'),CONVERT(varbinary(max),N'User:PipelineComponentTime'));
                CREATE TABLE [#SsisLegacyLogAnalysis_PhasePayload]
                ([LogId] int NOT NULL,[TokenCount] int NOT NULL,
                 [PrefixToken] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [ComponentTokenName] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [MiddleToken] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [OutputTokenName] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [EndToken] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContainsTextNul] bit NOT NULL);
                ;WITH quotes AS
                (
                    SELECT e.LogId,b.MessageText COLLATE Latin1_General_100_BIN2 AS TextValue,
                        a.Q1,z.Q2,y.Q3,x.Q4,v.Q5
                    FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] AS e
                    INNER JOIN [#SsisLegacyLogAnalysis_Buffer] AS b ON b.LogId=e.LogId
                    CROSS APPLY(SELECT CHARINDEX(N'"',b.MessageText COLLATE Latin1_General_100_BIN2) AS Q1) AS a
                    CROSS APPLY(SELECT CASE WHEN a.Q1>0 THEN CHARINDEX(N'"',b.MessageText COLLATE Latin1_General_100_BIN2,a.Q1+1) ELSE 0 END AS Q2) AS z
                    CROSS APPLY(SELECT CASE WHEN z.Q2>0 THEN CHARINDEX(N'"',b.MessageText COLLATE Latin1_General_100_BIN2,z.Q2+1) ELSE 0 END AS Q3) AS y
                    CROSS APPLY(SELECT CASE WHEN y.Q3>0 THEN CHARINDEX(N'"',b.MessageText COLLATE Latin1_General_100_BIN2,y.Q3+1) ELSE 0 END AS Q4) AS x
                    CROSS APPLY(SELECT CASE WHEN x.Q4>0 THEN CHARINDEX(N'"',b.MessageText COLLATE Latin1_General_100_BIN2,x.Q4+1) ELSE 0 END AS Q5) AS v
                    WHERE e.ParserId='PCT_EN_1'
                ), payload AS
                (
                    SELECT LogId,CASE WHEN Q2>0 AND Q3=0 THEN 3 WHEN Q4>0 AND Q5=0 THEN 5 ELSE 0 END AS TokenCount,
                        LEFT(TextValue,CASE WHEN Q1>0 THEN Q1-1 ELSE 0 END) AS PrefixToken,
                        SUBSTRING(TextValue,Q1+1,CASE WHEN Q2>Q1 THEN Q2-Q1-1 ELSE 0 END) AS ComponentTokenName,
                        SUBSTRING(TextValue,Q2+1,CASE WHEN Q3>Q2 THEN Q3-Q2-1 ELSE DATALENGTH(TextValue)/2 END) AS MiddleToken,
                        CASE WHEN Q4>Q3 THEN SUBSTRING(TextValue,Q3+1,Q4-Q3-1) END AS OutputTokenName,
                        CASE WHEN Q4>0 THEN SUBSTRING(TextValue,Q4+1,2147483647) END AS EndToken,
                        CONVERT(bit,CASE WHEN CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(TextValue,'json'),N'\\',N''))>0 THEN 1 ELSE 0 END) AS ContainsTextNul
                    FROM quotes
                )
                INSERT [#SsisLegacyLogAnalysis_PhasePayload]
                SELECT LogId,TokenCount,PrefixToken,ComponentTokenName,MiddleToken,OutputTokenName,EndToken,ContainsTextNul FROM payload;
                ;WITH positions AS
                (
                    SELECT *,CHARINDEX(N') spent ',MiddleToken COLLATE Latin1_General_100_BIN2) AS ClosePos,
                        CHARINDEX(N' milliseconds in ',MiddleToken COLLATE Latin1_General_100_BIN2) AS TimePos
                    FROM [#SsisLegacyLogAnalysis_PhasePayload]
                ), slices AS
                (
                    SELECT *,SUBSTRING(MiddleToken COLLATE Latin1_General_100_BIN2,3,CASE WHEN ClosePos>=3 THEN ClosePos-3 ELSE 0 END) AS ComponentToken,
                        SUBSTRING(MiddleToken COLLATE Latin1_General_100_BIN2,ClosePos+8,CASE WHEN TimePos>=ClosePos+8 THEN TimePos-ClosePos-8 ELSE 0 END) AS TimeToken,
                        SUBSTRING(EndToken COLLATE Latin1_General_100_BIN2,3,CASE WHEN DATALENGTH(EndToken)>=8 THEN DATALENGTH(EndToken)/2-4 ELSE 0 END) AS OutputToken
                    FROM positions
                ), syntax AS
                (
                    SELECT *,CASE WHEN ContainsTextNul=1 OR TokenCount NOT IN(3,5)
                        OR CONVERT(varbinary(max),PrefixToken)<>CONVERT(varbinary(max),N'The component ')
                        OR DATALENGTH(ComponentTokenName) NOT BETWEEN 2 AND 8000
                        OR CHARINDEX(NCHAR(13),ComponentTokenName)>0 OR CHARINDEX(NCHAR(10),ComponentTokenName)>0 OR CHARINDEX(NCHAR(9),ComponentTokenName)>0
                        OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(ComponentTokenName,'json'),N'\\',N''))>0
                        OR ClosePos<3 OR TimePos<ClosePos+8
                        OR CONVERT(varbinary(max),MiddleToken)<>CONVERT(varbinary(max),N' ('+ComponentToken+N') spent '+TimeToken+N' milliseconds in '+
                            CASE WHEN TokenCount=3 THEN N'ProcessInput.' ELSE N'PrimeOutput filling buffers on output ' END)
                        OR DATALENGTH(ComponentToken)=0 OR ComponentToken COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
                        OR (DATALENGTH(ComponentToken)>2 AND LEFT(ComponentToken,1)=N'0')
                        OR DATALENGTH(TimeToken)=0 OR TimeToken COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
                        OR (DATALENGTH(TimeToken)>2 AND LEFT(TimeToken,1)=N'0')
                        OR (TokenCount=5 AND (DATALENGTH(OutputTokenName) NOT BETWEEN 2 AND 8000
                            OR CHARINDEX(NCHAR(13),OutputTokenName)>0 OR CHARINDEX(NCHAR(10),OutputTokenName)>0 OR CHARINDEX(NCHAR(9),OutputTokenName)>0
                            OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(OutputTokenName,'json'),N'\\',N''))>0
                            OR CONVERT(varbinary(max),EndToken)<>CONVERT(varbinary(max),N' ('+OutputToken+N').')
                            OR DATALENGTH(OutputToken)=0 OR OutputToken COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
                            OR (DATALENGTH(OutputToken)>2 AND LEFT(OutputToken,1)=N'0'))) THEN 1 ELSE 0 END AS BadShape,
                        TRY_CONVERT(int,ComponentToken) AS ParsedComponent,TRY_CONVERT(bigint,TimeToken) AS ParsedTime,TRY_CONVERT(int,OutputToken) AS ParsedOutput
                    FROM slices
                ), checked AS
                (
                    SELECT *,CASE WHEN BadShape=1 THEN 'MALFORMED_PAYLOAD'
                        WHEN ParsedComponent IS NULL OR ParsedComponent<1 OR ParsedTime IS NULL
                         OR (TokenCount=5 AND (ParsedOutput IS NULL OR ParsedOutput<1)) THEN 'NUMERIC_OUT_OF_RANGE'
                        ELSE 'PARSED' END AS FinalParseStatus FROM syntax
                )
                UPDATE e SET ParseStatus=p.FinalParseStatus,
                    ComponentId=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedComponent END,
                    ComponentName=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ComponentTokenName END,
                    PhaseName=CASE WHEN p.FinalParseStatus='PARSED' THEN CASE WHEN p.TokenCount=3 THEN 'ProcessInput' ELSE 'PrimeOutput' END END,
                    ReportedDurationMs=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedTime END,
                    OutputId=CASE WHEN p.FinalParseStatus='PARSED' AND p.TokenCount=5 THEN p.ParsedOutput END,
                    OutputName=CASE WHEN p.FinalParseStatus='PARSED' AND p.TokenCount=5 THEN p.OutputTokenName END
                FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] AS e INNER JOIN checked AS p ON p.LogId=e.LogId;

                -- Named reports do not provide numeric component/output identities.
                CREATE TABLE [#SsisLegacyLogAnalysis_PhaseNamedPayload]
                ([LogId] int NOT NULL,[TextValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [ComponentTokenName] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [TimeToken] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [MethodTail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                 [OutputTokenName] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
                ;WITH positions AS
                (
                    SELECT e.LogId,b.MessageText COLLATE Latin1_General_100_BIN2 AS TextValue,a.SpentPos,z.TimePos
                    FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] AS e
                    INNER JOIN [#SsisLegacyLogAnalysis_Buffer] AS b ON b.LogId=e.LogId
                    CROSS APPLY(SELECT CHARINDEX(N' spent ',b.MessageText COLLATE Latin1_General_100_BIN2,5) AS SpentPos) AS a
                    CROSS APPLY(SELECT CASE WHEN a.SpentPos>=5 THEN CHARINDEX(N' milliseconds in ',b.MessageText COLLATE Latin1_General_100_BIN2,a.SpentPos+7) ELSE 0 END AS TimePos) AS z
                    WHERE e.ParserId IN('PCT_EN_2','PCT_EN_3')
                )
                INSERT [#SsisLegacyLogAnalysis_PhaseNamedPayload]
                SELECT LogId,TextValue,SUBSTRING(TextValue,5,CASE WHEN SpentPos>=5 THEN SpentPos-5 ELSE 0 END),
                    SUBSTRING(TextValue,SpentPos+7,CASE WHEN TimePos>=SpentPos+7 THEN TimePos-SpentPos-7 ELSE 0 END),
                    SUBSTRING(TextValue,CASE WHEN TimePos>0 THEN TimePos+17 ELSE 1 END,2147483647),NULL FROM positions;
                UPDATE [#SsisLegacyLogAnalysis_PhaseNamedPayload]
                SET OutputTokenName=SUBSTRING(MethodTail COLLATE Latin1_General_100_BIN2,
                    32+DATALENGTH(ComponentTokenName)/2+9,
                    CASE WHEN DATALENGTH(MethodTail)/2>=31+DATALENGTH(ComponentTokenName)/2+9+2
                         THEN DATALENGTH(MethodTail)/2-(31+DATALENGTH(ComponentTokenName)/2+9)-2 ELSE 0 END);
                ;WITH syntax AS
                (
                    SELECT *,CASE WHEN CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(TextValue,'json'),N'\\',N''))>0
                        OR DATALENGTH(ComponentTokenName) NOT BETWEEN 2 AND 8000
                        OR CHARINDEX(N'"',ComponentTokenName)>0 OR CHARINDEX(N'[',ComponentTokenName)>0 OR CHARINDEX(N']',ComponentTokenName)>0
                        OR CHARINDEX(NCHAR(13),ComponentTokenName)>0 OR CHARINDEX(NCHAR(10),ComponentTokenName)>0 OR CHARINDEX(NCHAR(9),ComponentTokenName)>0
                        OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(ComponentTokenName,'json'),N'\\',N''))>0
                        OR CHARINDEX(N' spent ',ComponentTokenName COLLATE Latin1_General_100_BIN2)>0 OR CHARINDEX(N'.Outputs[',ComponentTokenName COLLATE Latin1_General_100_BIN2)>0
                        OR DATALENGTH(TimeToken)=0 OR TimeToken COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9]%'
                        OR (DATALENGTH(TimeToken)>2 AND LEFT(TimeToken,1)=N'0')
                        OR (NOT(CONVERT(varbinary(max),MethodTail)=CONVERT(varbinary(max),N'ProcessInput.')
                            OR (@IncludeComponentLifecyclePhases=1 AND CONVERT(varbinary(max),MethodTail) IN(CONVERT(varbinary(max),N'Validate.'),CONVERT(varbinary(max),N'PreExecute.'),CONVERT(varbinary(max),N'PostExecute.')))) AND
                            (DATALENGTH(OutputTokenName) NOT BETWEEN 2 AND 8000
                             OR CHARINDEX(N'"',OutputTokenName)>0 OR CHARINDEX(N'[',OutputTokenName)>0 OR CHARINDEX(N']',OutputTokenName)>0
                             OR CHARINDEX(NCHAR(13),OutputTokenName)>0 OR CHARINDEX(NCHAR(10),OutputTokenName)>0 OR CHARINDEX(NCHAR(9),OutputTokenName)>0
                             OR CHARINDEX(N'\u0000',REPLACE(STRING_ESCAPE(OutputTokenName,'json'),N'\\',N''))>0
                             OR CONVERT(varbinary(max),MethodTail)<>CONVERT(varbinary(max),N'PrimeOutput filling buffers on '+ComponentTokenName+N'.Outputs['+OutputTokenName+N'].')))
                        OR CONVERT(varbinary(max),TextValue)<>CONVERT(varbinary(max),N'The '+ComponentTokenName+N' spent '+TimeToken+N' milliseconds in '+MethodTail)
                        THEN 1 ELSE 0 END AS BadShape,TRY_CONVERT(bigint,TimeToken) AS ParsedTime FROM [#SsisLegacyLogAnalysis_PhaseNamedPayload]
                ), checked AS
                (
                    SELECT *,CASE WHEN BadShape=1 THEN 'MALFORMED_PAYLOAD' WHEN ParsedTime IS NULL THEN 'NUMERIC_OUT_OF_RANGE' ELSE 'PARSED' END AS FinalParseStatus FROM syntax
                )
                UPDATE e SET ParseStatus=p.FinalParseStatus,
                    ComponentName=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ComponentTokenName END,
                    PhaseName=CASE WHEN p.FinalParseStatus='PARSED' THEN CASE CONVERT(varbinary(max),p.MethodTail)
                        WHEN CONVERT(varbinary(max),N'ProcessInput.') THEN 'ProcessInput'
                        WHEN CONVERT(varbinary(max),N'Validate.') THEN 'Validate'
                        WHEN CONVERT(varbinary(max),N'PreExecute.') THEN 'PreExecute'
                        WHEN CONVERT(varbinary(max),N'PostExecute.') THEN 'PostExecute' ELSE 'PrimeOutput' END END,
                    ReportedDurationMs=CASE WHEN p.FinalParseStatus='PARSED' THEN p.ParsedTime END,
                    OutputName=CASE WHEN p.FinalParseStatus='PARSED' AND CONVERT(varbinary(max),p.MethodTail) NOT IN(CONVERT(varbinary(max),N'ProcessInput.'),CONVERT(varbinary(max),N'Validate.'),CONVERT(varbinary(max),N'PreExecute.'),CONVERT(varbinary(max),N'PostExecute.')) THEN p.OutputTokenName END
                FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] AS e INNER JOIN checked AS p ON p.LogId=e.LogId;

                UPDATE e SET ContextStatus=g.FinalContextStatus,
                    ContextStartLogId=CASE WHEN g.FinalContextStatus='ASSIGNED' THEN p.StartId END,
                    ContextEndLogId=CASE WHEN g.FinalContextStatus='ASSIGNED' THEN p.EndId END
                FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] AS e OUTER APPLY
                (
                    SELECT COUNT_BIG(*) AS PairCount,MIN(StartLogId) AS StartId,MIN(EndLogId) AS EndId,MIN(StartTime) AS PairStart,MIN(EndTime) AS PairEnd
                    FROM [#SsisLegacyLogAnalysis_Iterations] AS i
                    WHERE i.SourceId=e.SourceId AND i.PairKind=CASE WHEN e.ParserId='PCT_EN_3' AND e.PhaseName='Validate' THEN 'VALIDATE' ELSE 'EXECUTE' END AND i.PairStatus='PAIRED' AND i.StartLogId<e.LogId AND e.LogId<i.EndLogId
                ) AS p CROSS APPLY
                (
                    SELECT CASE WHEN e.ParseStatus<>'PARSED' THEN 'NOT_PARSED' WHEN e.SourceId IS NULL THEN 'SOURCE_ID_MISSING'
                        WHEN e.EventTime IS NULL THEN 'EVENT_TIME_MISSING' WHEN p.PairCount=0 THEN 'NO_OBSERVED_PAIR'
                        WHEN p.PairCount>1 THEN 'AMBIGUOUS_PAIR' WHEN e.EventTime<p.PairStart OR e.EventTime>p.PairEnd THEN 'TIME_OUTSIDE_PAIR' ELSE 'ASSIGNED' END AS FinalContextStatus
                ) AS g;
                ;WITH g AS
                (
                    SELECT ExecutionId,SourceId,ContextStartLogId,ContextEndLogId,ComponentId,PhaseName,OutputId,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN NULL ELSE MAX(SourceName) END AS SourceName,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),ComponentName))>1 THEN NULL ELSE MAX(ComponentName) END AS ComponentName,
                        CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),OutputName))>1 THEN NULL ELSE MAX(OutputName) END AS OutputName,
                        COUNT_BIG(*) AS EventCount,SUM(CONVERT(decimal(38,0),ReportedDurationMs)) AS ReportedDurationSumMs,
                        MIN(ReportedDurationMs) AS MinReportedDurationMs,MAX(ReportedDurationMs) AS MaxReportedDurationMs,
                        MIN(EventTime) AS FirstObservedTime,MAX(EventTime) AS LastObservedTime,
                        N'['+STRING_AGG(CONVERT(nvarchar(max),LogId),N',') WITHIN GROUP(ORDER BY LogId)+N']' AS EvidenceLogIdsJson,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),SourceName))>1 THEN 1 ELSE 0 END) AS SourceNameConflict,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),ComponentName))>1 THEN 1 ELSE 0 END) AS ComponentNameConflict,
                        CONVERT(bit,CASE WHEN COUNT(DISTINCT CONVERT(varbinary(8000),OutputName))>1 THEN 1 ELSE 0 END) AS OutputNameConflict
                    FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] WHERE ContextStatus='ASSIGNED'
                    GROUP BY ExecutionId,SourceId,ContextStartLogId,ContextEndLogId,ComponentId,PhaseName,OutputId,ParserId,
                        CONVERT(varbinary(8000),CASE WHEN ParserId IN('PCT_EN_2','PCT_EN_3') THEN ComponentName END),
                        CONVERT(varbinary(8000),CASE WHEN ParserId IN('PCT_EN_2','PCT_EN_3') THEN OutputName END)
                )
                INSERT [#SsisLegacyLogAnalysis_ComponentPhaseTimes]
                SELECT ROW_NUMBER() OVER(ORDER BY SourceId,ContextStartLogId,ContextEndLogId,ComponentId,PhaseName COLLATE Latin1_General_100_BIN2,OutputId,CONVERT(varbinary(8000),ComponentName),CONVERT(varbinary(8000),OutputName)),
                    ExecutionId,SourceId,SourceName,ContextStartLogId,ContextEndLogId,ComponentId,ComponentName,PhaseName,OutputId,OutputName,
                    EventCount,ReportedDurationSumMs,MinReportedDurationMs,MaxReportedDurationMs,
                    CONVERT(decimal(38,6),CONVERT(decimal(26,0),
                        (ReportedDurationSumMs*CONVERT(decimal(7,0),1000000)-(ReportedDurationSumMs*CONVERT(decimal(7,0),1000000))%CONVERT(decimal(19,0),EventCount))/CONVERT(decimal(19,0),EventCount)
                        +CASE WHEN ((ReportedDurationSumMs*CONVERT(decimal(7,0),1000000))%CONVERT(decimal(19,0),EventCount))*2>=EventCount THEN 1 ELSE 0 END)/CONVERT(decimal(7,0),1000000)),
                    FirstObservedTime,LastObservedTime,EvidenceLogIdsJson,SourceNameConflict,ComponentNameConflict,OutputNameConflict,@Truncated,
                    CASE WHEN SourceNameConflict=1 OR ComponentNameConflict=1 OR OutputNameConflict=1 THEN 'OBSERVED_NAME_CONFLICT'
                         WHEN @Truncated=1 THEN 'OBSERVED_PREFIX' ELSE 'OBSERVED_REPORTS' END FROM g;
                IF SYSUTCDATETIME()>=@Deadline SET @PhaseReason=N'TIME_BUDGET_EXHAUSTED';
                ELSE
                BEGIN
                    SELECT @PhaseCandidates=COUNT_BIG(*),@PhaseParsed=COALESCE(SUM(CONVERT(bigint,CASE WHEN ParseStatus='PARSED' THEN 1 ELSE 0 END)),0),
                        @PhaseAssigned=COALESCE(SUM(CONVERT(bigint,CASE WHEN ContextStatus='ASSIGNED' THEN 1 ELSE 0 END)),0)
                    FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents];
                    DECLARE @PhaseGroups bigint=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_ComponentPhaseTimes]);
                    DECLARE @PhaseConflict bit=CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_ComponentPhaseTimes]
                        WHERE SourceNameConflict=1 OR ComponentNameConflict=1 OR OutputNameConflict=1) THEN 1 ELSE 0 END;
                    DECLARE @PhaseLimited bit=CASE WHEN @Truncated=1 OR @PhaseParsed<@PhaseCandidates OR @PhaseAssigned<@PhaseParsed OR @PhaseConflict=1 THEN 1 ELSE 0 END;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @PhaseCandidates=0 THEN 'AVAILABLE_EMPTY' WHEN @PhaseLimited=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
                        IsPartial=CASE WHEN @PhaseCandidates=0 THEN 0 ELSE @PhaseLimited END,ObservedRowCount=@PhaseCandidates+@PhaseGroups,ReturnedRowCount=@PhaseCandidates+@PhaseGroups,
                        Detail=N'Candidates='+CONVERT(nvarchar(20),@PhaseCandidates)+N';Parsed='+CONVERT(nvarchar(20),@PhaseParsed)+N';ContextAssigned='+CONVERT(nvarchar(20),@PhaseAssigned)+N';Groups='+CONVERT(nvarchar(20),@PhaseGroups)
                    WHERE SourceOrdinal=7;
                    IF @PhaseCandidates=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_EVENT_NOT_OBSERVED',N'componentPhaseAnalysis',N'Keine PipelineComponentTime-Meldung beobachtet; kein Nachweis einer Nullzeit oder Loggingkonfiguration.');
                    IF @PhaseParsed<@PhaseCandidates INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_PAYLOAD_NOT_PARSED',N'componentPhaseAnalysis',N'Mindestens ein Kandidat entspricht nicht dem zugelassenen vollständigen Zeitprofil.');
                    IF @PhaseAssigned<@PhaseParsed INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_CONTEXT_NOT_ASSIGNED',N'componentPhaseAnalysis',CASE WHEN @IncludeComponentLifecyclePhases=1 THEN N'Mindestens ein lesbarer Bericht besitzt keinen eindeutigen zeitlich einschließenden methodenspezifischen Berichtskontext.' ELSE N'Mindestens ein lesbarer Bericht besitzt keinen eindeutigen zeitlich einschließenden EXECUTE-Berichtskontext.' END);
                    IF @PhaseConflict=1 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_NAME_CONFLICT',N'componentPhaseAnalysis',N'Ordinal verschiedene beitragende Namen; der betroffene Gruppenname bleibt NULL.');
                    SET @PhaseComplete=1;
                END;
            END TRY
            BEGIN CATCH
                DECLARE @PhaseError int=ERROR_NUMBER(),@PhaseMessage nvarchar(4000)=ERROR_MESSAGE();
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET StatusCode=CASE WHEN @PhaseError IN(229,262,297,300,371) THEN 'DENIED'
                    WHEN @PhaseError IN(207,208,911,916,942) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                    IsPartial=1,ErrorNumber=@PhaseError,ErrorMessage=@PhaseMessage,Detail=N'NATIVE_SOURCE_ERROR' WHERE SourceOrdinal=7;
                IF @Error IS NULL SELECT @Error=@PhaseError,@Message=@PhaseMessage;
                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_ANALYSIS_ERROR',N'componentPhaseAnalysis',N'Die Phasenableitung ist fehlgeschlagen; gültige vorherige Mengen bleiben erhalten.');
            END CATCH;
            IF @PhaseComplete=0
            BEGIN
                DELETE FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents];
                DELETE FROM [#SsisLegacyLogAnalysis_ComponentPhaseTimes];
                SELECT @PhaseCandidates=NULL,@PhaseParsed=NULL,@PhaseAssigned=NULL;
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET ObservedRowCount=NULL,ReturnedRowCount=NULL,IsTruncated=0,
                    StatusCode=CASE WHEN @PhaseReason=N'TIME_BUDGET_EXHAUSTED' AND @PhaseStarted=1 THEN 'AVAILABLE_LIMITED' ELSE StatusCode END,
                    Detail=COALESCE(@PhaseReason,Detail) WHERE SourceOrdinal=7;
                IF @PhaseReason=N'MESSAGES_DISABLED' INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_MESSAGES_DISABLED',N'componentPhaseAnalysis',N'Der Meldungstextzugriff und damit der Komponentenzeitenparser sind abgeschaltet.');
                IF @PhaseReason=N'TIME_BUDGET_EXHAUSTED' INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'COMPONENT_PHASE_TIME_BUDGET_EXHAUSTED',N'componentPhaseAnalysis',N'Die Phasenableitung wurde nicht innerhalb des kooperativen Budgets übernommen.');
            END;
            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET CollectionTimeUtc=SYSUTCDATETIME() WHERE SourceOrdinal=7;
            IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_SourceStatus] WHERE SourceOrdinal=7 AND IsPartial=1)
            BEGIN
                SET @Partial=1;
                IF @Status IN('AVAILABLE','AVAILABLE_EMPTY','AVAILABLE_LIMITED') SET @Status='AVAILABLE_LIMITED';
            END;
        END;
        -- END COMPONENT PHASE ANALYSIS
        EXEC sys.sp_executesql @RestoreLock;
        IF @PreviousAbort=1 SET XACT_ABORT ON;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_executesql @RestoreLock;
        IF @PreviousAbort=1 SET XACT_ABORT ON;
        THROW;
    END CATCH;

    IF @IncludeTimeline=0 DELETE FROM [#SsisLegacyLogAnalysis_Timeline];
    DECLARE @Detail nvarchar(2000)=N'',@Before bigint,@After bigint,@TotalBefore bigint=0,@TotalAfter bigint=0,@AnyTruncation bit=0;
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Timeline];
    DELETE FROM [#SsisLegacyLogAnalysis_Timeline] WHERE [TimelineOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Timeline];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'timeline',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'timeline:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_ErrorChain];
    DELETE FROM [#SsisLegacyLogAnalysis_ErrorChain] WHERE [ErrorOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_ErrorChain];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'errorChain',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'errorChain:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations];
    DELETE FROM [#SsisLegacyLogAnalysis_Iterations] WHERE [IterationOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'iterations',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'iterations:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_LoggingQuality];
    DELETE FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE [QualityOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_LoggingQuality];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'loggingQuality',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'loggingQuality:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Findings];
    DELETE FROM [#SsisLegacyLogAnalysis_Findings] WHERE [FindingOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Findings];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'findings',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'findings:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET ObservedRowCount=@TotalBefore,ReturnedRowCount=@TotalAfter,
        IsTruncated=@AnyTruncation,IsPartial=CASE WHEN @AnyTruncation=1 THEN 1 ELSE IsPartial END,
        StatusCode=CASE WHEN @AnyTruncation=1 THEN 'AVAILABLE_LIMITED' ELSE StatusCode END,Detail=RTRIM(@Detail)
    WHERE SourceOrdinal=4 AND StatusCode IN('AVAILABLE','AVAILABLE_LIMITED');
    IF @Continue=1
    BEGIN
        SELECT @Partial=CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_SourceStatus] WHERE IsPartial=1) THEN 1 ELSE 0 END;
        SELECT @Status=CASE WHEN @Partial=1 THEN 'AVAILABLE_LIMITED'
            WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Execution]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END;
    END;
    ;WITH w AS(SELECT *,ROW_NUMBER() OVER(ORDER BY WarningCode,SourceName) AS n FROM [#SsisLegacyLogAnalysis_Warnings]) UPDATE w SET WarningOrdinal=CONVERT(int,n);
    INSERT [#SsisLegacyLogAnalysis_ModuleStatus]
    VALUES(N'USP_SsisLegacyLogAnalysis',CASE WHEN @IncludeComponentPhaseAnalysis=1 THEN CASE WHEN @IncludeComponentLifecyclePhases=1 THEN 5 ELSE 4 END WHEN @IncludeRowFlowAnalysis=1 THEN 3 WHEN @IncludeTaskAnalysis=1 THEN 2 ELSE 1 END,@LoggingDatabase,@LoggingSchema,@LoggingTable,@ExecutionId,@IncludeMessages,@Status,@Partial,@Error,@Message,@Now);
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
    IF COALESCE(@JsonErzeugen,0)=1
        SELECT @Json=(SELECT
            JSON_QUERY((SELECT N'USP_SsisLegacyLogAnalysis' AS ModuleName,CASE WHEN @IncludeComponentPhaseAnalysis=1 THEN CASE WHEN @IncludeComponentLifecyclePhases=1 THEN 5 ELSE 4 END WHEN @IncludeRowFlowAnalysis=1 THEN 3 WHEN @IncludeTaskAnalysis=1 THEN 2 ELSE 1 END AS SchemaVersion,@Now AS CollectionTimeUtc,@Status AS StatusCode,@Partial AS IsPartial FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) AS [meta]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ModuleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [moduleStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Execution] ORDER BY [ExecutionId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [execution]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Timeline] ORDER BY [TimelineOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [timeline]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ErrorChain] ORDER BY [ErrorOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [errorChain]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Iterations] ORDER BY [IterationOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [iterations]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_LoggingQuality] ORDER BY [QualityOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [loggingQuality]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Findings] ORDER BY [FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [findings]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_SourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [warnings]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    IF COALESCE(@JsonErzeugen,0)=1 AND @IncludeTaskAnalysis=1
    BEGIN
        SET @Json=JSON_MODIFY(@Json,'$.meta.TaskAnalysisCatalogVersion',1);
        SET @Json=JSON_MODIFY(@Json,'$.taskDurations',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_TaskDurations] ORDER BY TaskDurationOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        SET @Json=JSON_MODIFY(@Json,'$.taskLoggingCoverage',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage] ORDER BY CoverageOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
    END;
    IF COALESCE(@JsonErzeugen,0)=1 AND @IncludeRowFlowAnalysis=1
    BEGIN
        SET @Json=JSON_MODIFY(@Json,'$.meta.RowFlowCatalogVersion',1);
        SET @Json=JSON_MODIFY(@Json,'$.rowFlowEvents',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_RowFlowEvents] ORDER BY RowFlowEventOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        SET @Json=JSON_MODIFY(@Json,'$.rowFlow',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_RowFlow] ORDER BY RowFlowOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
    END;
    IF COALESCE(@JsonErzeugen,0)=1 AND @IncludeComponentPhaseAnalysis=1
    BEGIN
        SET @Json=JSON_MODIFY(@Json,'$.meta.ComponentPhaseCatalogVersion',CASE WHEN @IncludeComponentLifecyclePhases=1 THEN 2 ELSE 1 END);
        SET @Json=JSON_MODIFY(@Json,'$.componentPhaseEvents',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] ORDER BY PhaseEventOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
        SET @Json=JSON_MODIFY(@Json,'$.componentPhaseTimes',JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ComponentPhaseTimes] ORDER BY PhaseTimeOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')));
    END;
    IF @OutputMode='TABLE'
    BEGIN
        DECLARE @TargetTable sysname;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'moduleStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ModuleStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'execution'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Execution',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'timeline'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Timeline',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'errorChain'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ErrorChain',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'iterations'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Iterations',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'loggingQuality'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_LoggingQuality',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'findings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Findings',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'sourceStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_SourceStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'warnings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Warnings',@TargetTable,@ThrowOnError=1;
        IF @IncludeTaskAnalysis=1
        BEGIN
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'taskDurations'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_TaskDurations',@TargetTable,@ThrowOnError=1;
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'taskLoggingCoverage'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_TaskLoggingCoverage',@TargetTable,@ThrowOnError=1;
        END;
        IF @IncludeRowFlowAnalysis=1
        BEGIN
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'rowFlowEvents'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_RowFlowEvents',@TargetTable,@ThrowOnError=1;
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'rowFlow'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_RowFlow',@TargetTable,@ThrowOnError=1;
        END;
        IF @IncludeComponentPhaseAnalysis=1
        BEGIN
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'componentPhaseEvents'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ComponentPhaseEvents',@TargetTable,@ThrowOnError=1;
            SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'componentPhaseTimes'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ComponentPhaseTimes',@TargetTable,@ThrowOnError=1;
        END;
    END;
    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#SsisLegacyLogAnalysis_ModuleStatus] ORDER BY [ModuleName];
        SELECT * FROM [#SsisLegacyLogAnalysis_Execution] ORDER BY [ExecutionId];
        SELECT * FROM [#SsisLegacyLogAnalysis_Timeline] ORDER BY [TimelineOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_ErrorChain] ORDER BY [ErrorOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Iterations] ORDER BY [IterationOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_LoggingQuality] ORDER BY [QualityOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Findings] ORDER BY [FindingOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Warnings] ORDER BY [WarningOrdinal];
        IF @IncludeTaskAnalysis=1
        BEGIN
            SELECT * FROM [#SsisLegacyLogAnalysis_TaskDurations] ORDER BY TaskDurationOrdinal;
            SELECT * FROM [#SsisLegacyLogAnalysis_TaskLoggingCoverage] ORDER BY CoverageOrdinal;
        END;
        IF @IncludeRowFlowAnalysis=1
        BEGIN
            SELECT * FROM [#SsisLegacyLogAnalysis_RowFlowEvents] ORDER BY RowFlowEventOrdinal;
            SELECT * FROM [#SsisLegacyLogAnalysis_RowFlow] ORDER BY RowFlowOrdinal;
        END;
        IF @IncludeComponentPhaseAnalysis=1
        BEGIN
            SELECT * FROM [#SsisLegacyLogAnalysis_ComponentPhaseEvents] ORDER BY PhaseEventOrdinal;
            SELECT * FROM [#SsisLegacyLogAnalysis_ComponentPhaseTimes] ORDER BY PhaseTimeOrdinal;
        END;
    END;
    IF @ConsoleResultRequested=1
    BEGIN
        CREATE TABLE [#SsisLegacyLogAnalysis_Console]
        ([Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unvollständig] bit NOT NULL,[ExecutionId] uniqueidentifier NULL,
         [AnalysierteEreignisse] bigint NULL,[BeobachteterAusgang] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErsteFehlerLogId] int NULL,
         [ErsterFehlertext] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErsterZeitpunkt] datetime NULL,[LetzterZeitpunkt] datetime NULL,
         [Hinweis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        INSERT [#SsisLegacyLogAnalysis_Console]
        SELECT m.StatusCode,m.IsPartial,m.ExecutionId,e.AnalyzedEventCount,e.ObservedOutcome,e.FirstErrorLogId,e.FirstErrorMessage,e.FirstObservedTime,e.LastObservedTime,
            N'Beobachteter Logausschnitt; Quellenstatus und Grenzen beachten. Kein Nachweis einer technischen Root Cause.'
        FROM [#SsisLegacyLogAnalysis_ModuleStatus] AS m LEFT JOIN [#SsisLegacyLogAnalysis_Execution] AS e ON e.ExecutionId=m.ExecutionId;
        IF @IncludeTaskAnalysis=1
        BEGIN
            ALTER TABLE [#SsisLegacyLogAnalysis_Console] ADD [BeobachteteQuellen] bigint NULL,[GueltigeIntervalle] bigint NULL,[UngeklaerteGrenzereignisse] bigint NULL;
            EXEC sys.sp_executesql N'UPDATE [#SsisLegacyLogAnalysis_Console] SET [BeobachteteQuellen]=@Sources,[GueltigeIntervalle]=@Valid,[UngeklaerteGrenzereignisse]=@Unresolved;',
                N'@Sources bigint,@Valid bigint,@Unresolved bigint',@Sources=@TaskSources,@Valid=@TaskValid,@Unresolved=@TaskUnresolved;
        END;
        IF @IncludeRowFlowAnalysis=1
        BEGIN
            ALTER TABLE [#SsisLegacyLogAnalysis_Console] ADD [RowFlowMeldungen] bigint NULL,[RowFlowGeleseneMeldungen] bigint NULL,[RowFlowZugeordneteMeldungen] bigint NULL;
            EXEC sys.sp_executesql N'UPDATE [#SsisLegacyLogAnalysis_Console] SET [RowFlowMeldungen]=@Candidates,[RowFlowGeleseneMeldungen]=@Parsed,[RowFlowZugeordneteMeldungen]=@Assigned;',
                N'@Candidates bigint,@Parsed bigint,@Assigned bigint',@Candidates=@RowCandidates,@Parsed=@RowParsed,@Assigned=@RowAssigned;
        END;
        IF @IncludeComponentPhaseAnalysis=1
        BEGIN
            ALTER TABLE [#SsisLegacyLogAnalysis_Console] ADD [PhasenMeldungen] bigint NULL,[PhasenGeleseneMeldungen] bigint NULL,[PhasenKontextMeldungen] bigint NULL;
            EXEC sys.sp_executesql N'UPDATE [#SsisLegacyLogAnalysis_Console] SET [PhasenMeldungen]=@Candidates,[PhasenGeleseneMeldungen]=@Parsed,[PhasenKontextMeldungen]=@Assigned;',
                N'@Candidates bigint,@Parsed bigint,@Assigned bigint',@Candidates=@PhaseCandidates,@Parsed=@PhaseParsed,@Assigned=@PhaseAssigned;
        END;
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisLegacyLogAnalysis_Console',@ResultLabel=N'SSIS-Legacy-Ausführung',@EmptyMessage=N'Keine sichtbare Legacy-Ausführung';
    END;
END;
GO
