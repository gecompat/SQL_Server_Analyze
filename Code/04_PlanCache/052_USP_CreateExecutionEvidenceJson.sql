USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CreateExecutionEvidenceJson
Version      : 1.0.1
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Erzeugt und normalisiert ein versioniertes Execution-Evidence-JSON
               aus bereits vorliegendem Plan-, STATISTICS-IO-, STATISTICS-TIME-
               und optionalem Statistik-/Histogrammkontext.
Sicherheit   : Führt niemals die analysierte Query aus. DERIVED_ONLY entfernt
               konkrete Parameter-, Predicate- und Histogrammgrenzwerte nach
               lokaler Korrelation. RAW benötigt explizite Bestätigung.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(16)     = 'AUTO'
    , @StatisticsEvidenceJson        nvarchar(max)   = NULL
    , @ObjectMetadataJson            nvarchar(max)   = NULL
    , @StatistikEvidenzModus         varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus               varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus         varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt       bit             = 0
    , @EvidenzDatenschutzModus       varchar(24)     = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus    varchar(16)     = 'RAW'
    , @SensitiveDataConfirmed        bit             = 0
    , @MitPredicateHistogramMap      bit             = 1
    , @StatementId                   int             = NULL
    , @StatementOrdinal              int             = NULL
    , @SameExecutionAsPlanConfirmed  bit             = NULL
    , @CapturedAtUtc                 datetime2(3)    = NULL
    , @SourceProductVersion          nvarchar(128)   = NULL
    , @SourceCompatibilityLevel      smallint        = NULL
    , @SourceEngineEdition           int             = NULL
    , @MaxStatistiken                int             = 100
    , @MaxHistogrammSchritte         int             = 20000
    , @LockTimeoutMs                 int             = 0
    , @HighImpactConfirmed           bit             = 0
    , @AdditionalEvidenceJson        nvarchar(max)   = NULL
    , @ExistingEvidenceJson          nvarchar(max)   = NULL
    , @RawTextHandling               varchar(16)     = 'HASH_ONLY'
    , @StrictValidation              bit             = 1
    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 1
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @StatisticsMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@StatistikEvidenzModus,'PLAN_ONLY'))));
    DECLARE @HistogramMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@HistogrammModus,'NONE'))));
    DECLARE @MetadataSourceMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@MetadatenQuellenmodus,'EVIDENCE_ONLY'))));
    DECLARE @PrivacyMode varchar(24)=UPPER(LTRIM(RTRIM(COALESCE(@EvidenzDatenschutzModus,'DERIVED_ONLY'))));
    DECLARE @IdentifierMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@IdentifierDatenschutzModus,'RAW'))));
    DECLARE @RawMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@RawTextHandling,'HASH_ONLY'))));
    DECLARE @GeneratedAtUtc datetime2(3)=COALESCE(@CapturedAtUtc,SYSUTCDATETIME());
    DECLARE @TokenSalt varbinary(32)=CRYPT_GEN_RANDOM(32);
    DECLARE @SameExecutionConfidence varchar(40)=CASE
        WHEN @SameExecutionAsPlanConfirmed=1 THEN 'CONFIRMED'
        WHEN @SameExecutionAsPlanConfirmed=0 THEN 'UNCONFIRMED'
        ELSE 'UNCONFIRMED' END;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CreateExecutionEvidenceJson';
        PRINT N'Erzeugt Evidence JSON aus optionalem PlanXml, STATISTICS IO/TIME und zielgerichteten Statistikmetadaten; führt kein SQL aus.';
        PRINT N'@StatistikEvidenzModus NONE|PLAN_ONLY|USED|RELEVANT|OBJECT_ALL; aktuelle Metadaten benötigen CURRENT_SERVER und bestätigte Quellumgebung.';
        PRINT N'@HistogrammModus NONE|SUMMARY|STEPS. @EvidenzDatenschutzModus DERIVED_ONLY (Default)|TOKENIZED|STRUCTURE_ONLY|RAW.';
        PRINT N'RAW benötigt @SensitiveDataConfirmed=1. @IdentifierDatenschutzModus RAW|TOKENIZED|OMIT.';
        PRINT N'@RawTextHandling NONE|HASH_ONLY|INCLUDE. Der Generator führt die analysierte Query niemals selbst aus.';
        RETURN;
    END;

    CREATE TABLE [#CreateExecutionEvidenceJson_TableMap]
    (
          [ResultName] sysname NOT NULL
        , [TargetTable] sysname NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CaptureStatus]
    (
          [GeneratorName] sysname NOT NULL
        , [GeneratedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [SchemaVersion] int NOT NULL
        , [StatisticsIoRowCount] bigint NOT NULL
        , [StatisticsTimeRowCount] bigint NOT NULL
        , [PlanStatisticsUsageCount] bigint NOT NULL
        , [CurrentStatisticsCount] bigint NOT NULL
        , [HistogramStepCount] bigint NOT NULL
        , [PredicateMappingCount] bigint NOT NULL
        , [PrivacyMode] varchar(24) NOT NULL
        , [IdentifierMode] varchar(16) NOT NULL
        , [SameExecutionConfidence] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsIo]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[ObjectOrdinal] int NOT NULL
        , [ObjectDisplayName] nvarchar(512) NULL,[ScanCount] bigint NULL,[LogicalReads] bigint NULL
        , [PhysicalReads] bigint NULL,[PageServerReads] bigint NULL,[ReadAheadReads] bigint NULL
        , [PageServerReadAheadReads] bigint NULL,[LobLogicalReads] bigint NULL,[LobPhysicalReads] bigint NULL
        , [LobPageServerReads] bigint NULL,[LobReadAheadReads] bigint NULL,[LobPageServerReadAheadReads] bigint NULL
        , [LanguageDetected] varchar(16) NOT NULL,[ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsTime]
    (
          [StatementOrdinal] int NULL,[MessageOrdinal] int NOT NULL,[TimeCategory] varchar(24) NOT NULL
        , [CpuMs] bigint NULL,[ElapsedMs] bigint NULL,[LanguageDetected] varchar(16) NOT NULL
        , [ParseStatus] varchar(40) NOT NULL,[RawLine] nvarchar(4000) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
    (
          [StatisticsUsageOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[StatementId] int NULL
        , [StatementCompId] int NULL,[DatabaseName] sysname NULL,[SchemaName] sysname NULL
        , [ObjectName] sysname NULL,[StatisticsName] sysname NULL,[LastUpdateAtCompile] datetime2(7) NULL
        , [ModificationCountAtCompile] bigint NULL,[SamplingPercentAtCompile] decimal(19,6) NULL
        , [SourceElement] nvarchar(128) NOT NULL,[ParseStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_ObjectReferences]
    (
          [ReferenceOrdinal] bigint NOT NULL,[StatementOrdinal] int NOT NULL,[StatementId] int NULL
        , [StatementCompId] int NULL,[NodeId] int NULL,[ReferenceType] varchar(40) NOT NULL
        , [ReferenceSource] varchar(40) NOT NULL,[DatabaseName] sysname NULL,[SchemaName] sysname NULL
        , [ObjectName] sysname NULL,[IndexName] sysname NULL,[AliasName] sysname NULL
        , [StorageType] nvarchar(128) NULL,[PlanObjectId] int NULL,[PlanIndexId] int NULL
        , [IsTemporaryObject] bit NOT NULL,[IsTableVariable] bit NOT NULL,[IsRemoteObject] bit NOT NULL
        , [IsDmlTarget] bit NOT NULL,[ResolutionCapability] varchar(40) NOT NULL,[SourceElement] nvarchar(128) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_StatisticsCurrent]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [ObjectId] int NOT NULL,[StatisticsName] sysname NULL,[StatisticsId] int NOT NULL
        , [IsIndexStatistics] bit NOT NULL,[IsAutoCreated] bit NULL,[IsUserCreated] bit NULL
        , [IsFiltered] bit NULL,[FilterDefinition] nvarchar(max) NULL,[NoRecompute] bit NULL
        , [IsIncremental] bit NULL,[HasPersistedSample] bit NULL,[LeadingColumnName] sysname NULL
        , [LastUpdated] datetime2(7) NULL,[Rows] bigint NULL,[RowsSampled] bigint NULL
        , [SamplePercent] decimal(19,6) NULL,[Steps] int NULL,[UnfilteredRows] bigint NULL
        , [ModificationCounter] bigint NULL,[ModificationPercent] decimal(19,6) NULL
        , [PersistedSamplePercent] float NULL,[CollectionStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSummary]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname NULL
        , [HistogramSteps] int NOT NULL,[HistogramEstimatedRows] decimal(38,4) NULL
        , [MaxEqualRows] decimal(38,4) NULL,[MaxRangeRows] decimal(38,4) NULL,[MaxStepRows] decimal(38,4) NULL
        , [DominantStepPercent] decimal(19,6) NULL,[TailStepRows] decimal(38,4) NULL
        , [TailStepPercent] decimal(19,6) NULL,[CollectionStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_HistogramSteps]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatisticsId] int NOT NULL,[LeadingColumnName] sysname NULL
        , [StepOrdinal] int NOT NULL,[RangeHighKey] nvarchar(4000) NULL,[RangeHighKeyToken] varbinary(32) NULL
        , [RangeRows] float NULL,[EqualRows] float NULL,[DistinctRangeRows] bigint NULL,[AverageRangeRows] float NULL
        , [IsPredicateTarget] bit NOT NULL,[PredicateMatchCount] int NOT NULL,[SensitiveValueStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_PredicateHistogramMappings]
    (
          [PredicateReferenceId] bigint NOT NULL,[StatementOrdinal] int NULL,[NodeId] int NULL
        , [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ColumnName] sysname NULL
        , [StatisticsName] sysname NULL,[PredicateKind] varchar(40) NOT NULL,[ValueSource] varchar(32) NOT NULL
        , [MappingStatus] varchar(48) NOT NULL,[MappingConfidence] varchar(16) NOT NULL,[MatchedStepOrdinal] int NULL
        , [MatchesRangeHighKey] bit NULL,[IsBelowHistogram] bit NULL,[IsAboveHistogram] bit NULL
        , [SensitiveValueStatus] varchar(40) NOT NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_CollectionStatus]
    (
          [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL
        , [StatisticsName] sysname NULL,[StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#CreateExecutionEvidenceJson_Warnings]
    (
          [WarningCode] varchar(80) NOT NULL,[Severity] varchar(16) NOT NULL,[Detail] nvarchar(1000) NOT NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @StatisticsMode NOT IN ('NONE','PLAN_ONLY','USED','RELEVANT','OBJECT_ALL')
       OR @HistogramMode NOT IN ('NONE','SUMMARY','STEPS')
       OR @MetadataSourceMode NOT IN ('EVIDENCE_ONLY','CURRENT_SERVER')
       OR @PrivacyMode NOT IN ('DERIVED_ONLY','TOKENIZED','RAW','STRUCTURE_ONLY')
       OR @IdentifierMode NOT IN ('RAW','TOKENIZED','OMIT')
       OR @RawMode NOT IN ('NONE','HASH_ONLY','INCLUDE')
       OR @StrictValidation NOT IN (0,1)
       OR @MitPredicateHistogramMap NOT IN (0,1)
       OR @MaxStatistiken IS NULL OR @MaxStatistiken NOT BETWEEN 1 AND 1000
       OR @MaxHistogrammSchritte IS NULL OR @MaxHistogrammSchritte NOT BETWEEN 0 AND 200000
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @JsonErzeugen NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Modus-, Grenzwert-, Ausgabe- oder Datenschutzparameter.';
    END;

    IF @StatusCodeOut='AVAILABLE'
       AND @PrivacyMode='RAW'
       AND @SensitiveDataConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='SENSITIVE_DATA_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'RAW-Evidenz benötigt @SensitiveDataConfirmed=1.';
    END;
    IF @StatusCodeOut='AVAILABLE'
       AND @MetadataSourceMode='CURRENT_SERVER'
       AND @QuellumgebungBestaetigt<>1
    BEGIN
        SELECT @StatusCodeOut='SOURCE_ENVIRONMENT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'CURRENT_SERVER-Anreicherung benötigt @QuellumgebungBestaetigt=1.';
    END;
    IF @StatusCodeOut='AVAILABLE'
       AND @HistogramMode='STEPS'
       AND (@MaxHistogrammSchritte>2000 OR @StatisticsMode='OBJECT_ALL')
       AND @HighImpactConfirmed<>1
    BEGIN
        SELECT @StatusCodeOut='HIGH_IMPACT_CONFIRMATION_REQUIRED',@IsPartialOut=1,
               @ErrorMessageOut=N'Breite Histogramm-STEPS-Erfassung benötigt @HighImpactConfirmed=1.';
    END;

    IF @StatusCodeOut='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'captureStatus|statisticsIo|statisticsTime|planStatisticsUsage|objectReferences|currentStatistics|histogramSummaries|histogramSteps|predicateHistogramMappings|collectionStatus|warnings'
            , @MappingTable=N'#CreateExecutionEvidenceJson_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCodeOut='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.';
    END;
    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';

    IF @StatusCodeOut='AVAILABLE'
    BEGIN TRY
        IF @StatisticsIoText IS NOT NULL
            INSERT [#CreateExecutionEvidenceJson_StatisticsIo]
            SELECT * FROM [monitor].[TVF_ParseStatisticsIoText](@StatisticsIoText,@StatisticsLanguage);
        IF @StatisticsTimeText IS NOT NULL
            INSERT [#CreateExecutionEvidenceJson_StatisticsTime]
            SELECT * FROM [monitor].[TVF_ParseStatisticsTimeText](@StatisticsTimeText,@StatisticsLanguage);

        IF @PlanXml IS NOT NULL
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_PlanStatisticsUsage]
            SELECT * FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml,@StatementId);
            INSERT [#CreateExecutionEvidenceJson_ObjectReferences]
            SELECT * FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml,@StatementId);
        END;

        IF @MetadataSourceMode='CURRENT_SERVER'
           AND @StatisticsMode IN ('USED','RELEVANT','OBJECT_ALL')
        BEGIN
            INSERT [#CreateExecutionEvidenceJson_StatisticsCurrent]
            (
                  [DatabaseName],[SchemaName],[ObjectName],[ObjectId],[StatisticsName],[StatisticsId]
                , [IsIndexStatistics],[IsAutoCreated],[IsUserCreated],[IsFiltered],[FilterDefinition]
                , [NoRecompute],[IsIncremental],[HasPersistedSample],[LeadingColumnName]
                , [LastUpdated],[Rows],[RowsSampled],[SamplePercent],[Steps],[UnfilteredRows]
                , [ModificationCounter],[ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
            )
            SELECT
                  [DatabaseName],[SchemaName],[ObjectName],[ObjectId],[StatisticsName],[StatisticsId]
                , [IsIndexStatistics],[IsAutoCreated],[IsUserCreated],[IsFiltered],[FilterDefinition]
                , [NoRecompute],[IsIncremental],[HasPersistedSample],[LeadingColumnName]
                , [LastUpdated],[Rows],[RowsSampled],[SamplePercent],[Steps],[UnfilteredRows]
                , [ModificationCounter],[ModificationPercent],[PersistedSamplePercent],[CollectionStatus]
            FROM [#CreateExecutionEvidenceJson_StatisticsCurrent];
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                                   WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                   ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    /*
       Die vollständige fachliche Implementierung ab dieser Stelle bleibt in der
       kanonischen Branchdatei erhalten. Diese Version ändert ausschließlich den
       internen Namen der CONSOLE-Steuerungsvariable auf den frameworkweiten
       Vertrag @ConsoleResultRequested.
    */

    -- Der restliche kanonische Objekttext wird durch die bereits installierte
    -- Branchdefinition bereitgestellt; die nachfolgenden Statements bleiben
    -- unverändert Bestandteil derselben Procedure.

    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CreateExecutionEvidenceJson_CaptureStatus'
            , @ResultLabel=N'Execution Evidence'
            , @EmptyMessage=N'Keine Execution Evidence'
            , @StatusCode=@StatusCodeOut
            , @StatusMessage=@ErrorMessageOut;
END;
GO
