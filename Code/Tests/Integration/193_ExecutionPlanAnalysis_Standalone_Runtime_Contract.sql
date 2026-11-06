USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 193_ExecutionPlanAnalysis_Standalone_Runtime_Contract.sql
Zweck        : Installiert PLAN-001 zweimal in einer leeren synthetischen
               SQL-Server-2025-Datenbank und prüft Public APIs, Idempotenz,
               Installationsscope sowie den unabhängigen @PlanXml-Pfad.
Ausführung   : sqlcmd-Arbeitsverzeichnis muss Code/Install sein.
Datenschutz  : Ausschließlich generische synthetische Testwerte.
===============================================================================
*/
SET NOCOUNT ON;

IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 53620,N'Der Standalone-Installervertrag ist während der Entwicklung für SQL Server 2025 vorgesehen.',1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[database_query_store_options] WITH (NOLOCK)
    WHERE [actual_state_desc]<>N'OFF'
)
    THROW 53621,N'Query Store muss für den unabhängigen Standalone-Test deaktiviert sein.',1;

CREATE TABLE [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions]
(
      [event_session_id] int NOT NULL PRIMARY KEY
    , [name] sysname NOT NULL
    , [startup_state] bit NULL
);

INSERT [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions]
(
      [event_session_id]
    , [name]
    , [startup_state]
)
SELECT [event_session_id],[name],[startup_state]
FROM [sys].[server_event_sessions] WITH (NOLOCK);

CREATE TABLE [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline]
(
      [MetricName] varchar(64) NOT NULL PRIMARY KEY
    , [MetricCount] bigint NOT NULL
    , [MetricChecksum] int NULL
);

INSERT [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline]
(
      [MetricName]
    , [MetricCount]
    , [MetricChecksum]
)
SELECT
      'SERVER_EVENT_SESSIONS'
    , COUNT_BIG(*)
    , CHECKSUM_AGG(BINARY_CHECKSUM([event_session_id],[name],[startup_state]))
FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions];
GO

/* 1. Erstinstallation des eigenständigen Teilprojekts. */
:r Install_ExecutionPlanAnalysis.sql

/* 2. Beide öffentlichen Procedures mit synthetischer Evidenz aufrufen. */
:r ../Tests/PlanCache/120_ExecutionPlanAnalysis_Runtime_Contract.sql

USE [DeineDatenbank];
GO
SET NOCOUNT ON;

IF EXISTS
(
    SELECT 1
    FROM [sys].[procedures] AS [p] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[p].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [p].[name]=N'USP_ShowplanAnalysis'
)
    THROW 53622,N'Die Erstinstallation hat USP_ShowplanAnalysis unerwartet installiert.',1;

CREATE USER [ExampleStandaloneUser] WITHOUT LOGIN;
GRANT EXECUTE ON [monitor].[USP_ExecutionPlanAnalysis] TO [ExampleStandaloneUser];
GRANT EXECUTE ON [monitor].[USP_CreateExecutionEvidenceJson] TO [ExampleStandaloneUser];
GO

EXECUTE AS USER=N'ExampleStandaloneUser';

DECLARE @Plan xml=N'
<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.600" Build="17.0.1000.1">
  <BatchSequence><Batch><Statements>
    <StmtSimple StatementId="1" StatementCompId="1" StatementType="SELECT" StatementText="SELECT ExampleValue" StatementSubTreeCost="0.1" StatementEstRows="1" StatementOptmLevel="TRIVIAL" QueryHash="0x0303030303030303" QueryPlanHash="0x3333333333333333">
      <QueryPlan CardinalityEstimationModelVersion="170" CompileTime="1" CompileCPU="1" CompileMemory="64">
        <RelOp NodeId="0" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" EstimatedTotalSubtreeCost="0.1">
          <RunTimeInformation><RunTimeCountersPerThread Thread="0" ActualRows="1" ActualExecutions="1" /></RunTimeInformation>
          <ConstantScan />
        </RelOp>
      </QueryPlan>
    </StmtSimple>
  </Statements></Batch></BatchSequence>
</ShowPlanXML>';
DECLARE
      @AnalysisJson nvarchar(max)
    , @AnalysisStatus varchar(40)
    , @AnalysisPartial bit
    , @AnalysisError int
    , @AnalysisMessage nvarchar(2048);

DECLARE @StandaloneIncomingTimeout int=@@LOCK_TIMEOUT,@StandaloneIncomingTranCount int=@@TRANCOUNT;
BEGIN TRY
    EXEC [sys].[sp_executesql] N'DECLARE @Case tinyint=0,@IncomingTimeout int;
WHILE @Case<2
BEGIN
    IF @Case=0 SET LOCK_TIMEOUT 0; ELSE SET LOCK_TIMEOUT 137;
    SET @IncomingTimeout=@@LOCK_TIMEOUT;
    SELECT @AnalysisJson=NULL,@AnalysisStatus=NULL,@AnalysisPartial=NULL,@AnalysisError=NULL,@AnalysisMessage=NULL;
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@Plan
    , @ResultSetArt=''NONE''
    , @JsonErzeugen=1
    , @Json=@AnalysisJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@AnalysisStatus OUTPUT
    , @IsPartialOut=@AnalysisPartial OUTPUT
    , @ErrorNumberOut=@AnalysisError OUTPUT
    , @ErrorMessageOut=@AnalysisMessage OUTPUT;

    IF COALESCE(@AnalysisStatus,'''') NOT IN (''AVAILABLE'',''PARTIAL'') OR COALESCE(ISJSON(@AnalysisJson),0)<>1
       OR @AnalysisError IS NOT NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@AnalysisJson,N''$.statements''))<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@AnalysisJson,N''$.operatorTree''))<>1
       OR @@LOCK_TIMEOUT<>@IncomingTimeout
        THROW 53623,N''Der berechtigungsarme Standalone-Aufruf oder sein Timeout-Scope ist fehlgeschlagen.'',1;
    SET @Case+=1;
END;',
        N'@Plan xml,@AnalysisJson nvarchar(max) OUTPUT,@AnalysisStatus varchar(40) OUTPUT,
          @AnalysisPartial bit OUTPUT,@AnalysisError int OUTPUT,@AnalysisMessage nvarchar(2048) OUTPUT',
        @Plan=@Plan,@AnalysisJson=@AnalysisJson OUTPUT,@AnalysisStatus=@AnalysisStatus OUTPUT,
        @AnalysisPartial=@AnalysisPartial OUTPUT,@AnalysisError=@AnalysisError OUTPUT,@AnalysisMessage=@AnalysisMessage OUTPUT;
    IF @@LOCK_TIMEOUT<>@StandaloneIncomingTimeout OR @@TRANCOUNT<>@StandaloneIncomingTranCount
        THROW 53623,N'Die begrenzten Standalone-Proben haben den äußeren Caller-Scope verändert.',1;
END TRY
BEGIN CATCH
    DECLARE @StandaloneOriginalError int=ERROR_NUMBER(),@StandaloneRevertError int=0,@StandaloneDropError int=0;
    BEGIN TRY REVERT; END TRY BEGIN CATCH SET @StandaloneRevertError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY DROP USER [ExampleStandaloneUser]; END TRY BEGIN CATCH SET @StandaloneDropError=ERROR_NUMBER(); END CATCH;
    RAISERROR(N'STANDALONE_CLEANUP original=%d revert=%d drop=%d',10,1,
        @StandaloneOriginalError,@StandaloneRevertError,@StandaloneDropError) WITH NOWAIT;
    THROW;
END CATCH;

DECLARE
      @EvidenceJson nvarchar(max)
    , @EvidenceStatus varchar(40)
    , @EvidencePartial bit
    , @EvidenceError int
    , @EvidenceMessage nvarchar(2048);

EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @StatisticsIoText=N'Table ''ExampleObject''. Scan count 1, logical reads 2, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.'
    , @StatisticsTimeText=N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 1 ms.'
    , @ResultSetArt='NONE'
    , @Json=@EvidenceJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@EvidenceStatus OUTPUT
    , @IsPartialOut=@EvidencePartial OUTPUT
    , @ErrorNumberOut=@EvidenceError OUTPUT
    , @ErrorMessageOut=@EvidenceMessage OUTPUT;

IF @EvidenceStatus NOT IN ('AVAILABLE','PARTIAL') OR ISJSON(@EvidenceJson)<>1
    THROW 53624,N'Der berechtigungsarme Standalone-Aufruf des Evidenzerzeugers ist fehlgeschlagen.',1;

REVERT;
DROP USER [ExampleStandaloneUser];
GO

/* Kontrollierte Fehlerprobe an einer eigenen Kopie, keine Reproduktion einer Sperre. */
DECLARE @SetupDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_ExecutionPlanAnalysis')),
    @SetupHeader nvarchar(128)=N'PROCEDURE [monitor].[USP_ExecutionPlanAnalysis]',
    @SetupNeedle nvarchar(64)=N'SET LOCK_TIMEOUT 100;',@SetupHeaderAt int,@SetupNeedleAt int,
    @SetupOwnedId int=NULL,@SetupCallerLock int=@@LOCK_TIMEOUT,
    @SetupCallerTran int=@@TRANCOUNT,@SetupCallerOptions int=@@OPTIONS;
IF OBJECT_ID(N'monitor.ExampleOwnedTempSetupProbe') IS NOT NULL
    THROW 53636,N'Owned setup probe collision.',1;
SELECT @SetupHeaderAt=CHARINDEX(@SetupHeader,@SetupDefinition),
       @SetupNeedleAt=CHARINDEX(@SetupNeedle,@SetupDefinition);
IF @SetupDefinition IS NULL OR @SetupHeaderAt=0 OR @SetupNeedleAt=0
   OR CHARINDEX(@SetupNeedle,@SetupDefinition,@SetupNeedleAt+LEN(@SetupNeedle))<>0
    THROW 53636,N'Owned setup probe binding changed.',1;
SET @SetupDefinition=N'CREATE PROCEDURE [monitor].[ExampleOwnedTempSetupProbe]'
    +SUBSTRING(@SetupDefinition,@SetupHeaderAt+LEN(@SetupHeader),LEN(@SetupDefinition));
SET @SetupDefinition=REPLACE(@SetupDefinition,@SetupNeedle,
    @SetupNeedle+N' THROW 53634,N''Example owned temp setup failure.'',7;');
BEGIN TRY
    EXEC [sys].[sp_executesql] @SetupDefinition;
    SET @SetupOwnedId=OBJECT_ID(N'monitor.ExampleOwnedTempSetupProbe');
    IF @SetupOwnedId IS NULL THROW 53636,N'Owned setup probe creation failed.',1;
    EXEC [sys].[sp_executesql] N'
DECLARE @Case int=0,@Caught bit,@IncomingLock int,@IncomingTran int=@@TRANCOUNT;
WHILE @Case<2
BEGIN
    IF @Case=0 SET LOCK_TIMEOUT 0; ELSE SET LOCK_TIMEOUT 137;
    SELECT @IncomingLock=@@LOCK_TIMEOUT,@Caught=0;
    BEGIN TRY
        EXEC [monitor].[ExampleOwnedTempSetupProbe] @ResultSetArt=''NONE'',@PrintMeldungen=0;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>53634 OR ERROR_STATE()<>7
           OR ERROR_MESSAGE()<>N''Example owned temp setup failure.'' THROW;
        SET @Caught=1;
    END CATCH;
    IF @Caught<>1 OR @@LOCK_TIMEOUT<>@IncomingLock OR @@TRANCOUNT<>@IncomingTran
        THROW 53635,N''Owned setup error or caller scope changed.'',1;
    SET @Case+=1;
END;';
    IF @@LOCK_TIMEOUT<>@SetupCallerLock OR @@TRANCOUNT<>@SetupCallerTran OR @@OPTIONS<>@SetupCallerOptions
        THROW 53635,N'Owned setup outer caller scope changed.',1;
    IF ISNULL(OBJECT_ID(N'monitor.ExampleOwnedTempSetupProbe'),0)<>@SetupOwnedId
        THROW 53637,N'Owned setup probe ownership changed.',1;
    DROP PROCEDURE [monitor].[ExampleOwnedTempSetupProbe];
    IF OBJECT_ID(N'monitor.ExampleOwnedTempSetupProbe') IS NOT NULL
        THROW 53637,N'Owned setup probe cleanup failed.',1;
END TRY
BEGIN CATCH
    IF @SetupOwnedId IS NOT NULL AND OBJECT_ID(N'monitor.ExampleOwnedTempSetupProbe')=@SetupOwnedId
        DROP PROCEDURE [monitor].[ExampleOwnedTempSetupProbe];
    THROW;
END CATCH;
GO

/* Synthetische lokale Konfiguration muss die erneute Installation überleben. */
INSERT [monitor].[PlanAnalysisProfile]
(
      [ProfileCode]
    , [Description]
    , [Priority]
    , [IsEnabled]
    , [IsFrameworkDefault]
    , [SeedVersion]
    , [LastUpdatedUtc]
)
VALUES
(
      'EXAMPLE_LOCAL'
    , N'Synthetic local profile for the standalone installer contract.'
    , 900
    , 1
    , 0
    , 0
    , CONVERT(datetime2(0),'2026-01-01T00:00:00')
);

INSERT [monitor].[PlanAnalysisRuleThreshold]
(
      [RuleCode]
    , [ProfileCode]
    , [Severity]
    , [IsEnabled]
    , [MinRatio]
    , [RequiredEvidenceLevel]
    , [IsFrameworkDefault]
    , [SeedVersion]
    , [LastUpdatedUtc]
)
VALUES
(
      'EXAMPLE_CUSTOM_RULE'
    , 'EXAMPLE_LOCAL'
    , 'INFO'
    , 1
    , CONVERT(decimal(19,6),2.500000)
    , 'RUNTIME_MEASURED'
    , 0
    , 0
    , CONVERT(datetime2(0),'2026-01-01T00:00:00')
);

INSERT [monitor].[PlanAnalysisProfileAssignment]
(
      [Priority]
    , [IsEnabled]
    , [ProfileCode]
    , [DatabaseNamePattern]
    , [IsFrameworkDefault]
    , [Comment]
    , [LastUpdatedUtc]
)
VALUES
(
      900
    , 1
    , 'EXAMPLE_LOCAL'
    , N'ExampleDatabase%'
    , 0
    , N'Synthetic local assignment for the standalone installer contract.'
    , CONVERT(datetime2(0),'2026-01-01T00:00:00')
);
GO

/* 3. Die öffentliche Bestätigung darf ohne optionalen Pfadprüfer nicht ausfallen. */
IF OBJECT_ID(N'monitor.InternalCheckAnalysisPath',N'P') IS NULL
    THROW 53638,N'Der interne Pfadprüfer fehlt vor der isolierten Abwesenheitsprobe.',1;
DROP PROCEDURE [monitor].[InternalCheckAnalysisPath];
GO
IF OBJECT_ID(N'monitor.InternalCheckAnalysisPath',N'P') IS NOT NULL
    THROW 53639,N'Der optionale Pfadprüfer ist für die Abwesenheitsprobe noch vorhanden.',1;

DECLARE @StandaloneGatePlan xml=N'
<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.600" Build="17.0.1000.1">
  <BatchSequence><Batch><Statements>
    <StmtSimple StatementId="1" StatementCompId="1" StatementType="SELECT" StatementText="SELECT ExampleValue" StatementSubTreeCost="0.1" StatementEstRows="1" StatementOptmLevel="TRIVIAL">
      <QueryPlan CardinalityEstimationModelVersion="170">
        <RelOp NodeId="0" PhysicalOp="Constant Scan" LogicalOp="Constant Scan" EstimateRows="1" EstimatedTotalSubtreeCost="0.1"><ConstantScan /></RelOp>
      </QueryPlan>
    </StmtSimple>
  </Statements></Batch></BatchSequence>
</ShowPlanXML>';
DECLARE
      @StandaloneGateJson nvarchar(max)
    , @StandaloneGateStatus varchar(40)
    , @StandaloneGatePartial bit
    , @StandaloneGateError int
    , @StandaloneGateMessage nvarchar(2048);

/* 0 und NULL müssen denselben öffentlichen Status liefern, ohne den Helfer. */
SELECT @StandaloneGateJson=NULL,@StandaloneGateStatus='STALE',@StandaloneGatePartial=NULL,
       @StandaloneGateError=999,@StandaloneGateMessage=N'SENTINEL';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@StandaloneGatePlan
    , @AnalyseTiefe='FULL'
    , @HighImpactConfirmed=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@StandaloneGateJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@StandaloneGateStatus OUTPUT
    , @IsPartialOut=@StandaloneGatePartial OUTPUT
    , @ErrorNumberOut=@StandaloneGateError OUTPUT
    , @ErrorMessageOut=@StandaloneGateMessage OUTPUT;
IF COALESCE(@StandaloneGateStatus,'')<>'HIGH_IMPACT_CONFIRMATION_REQUIRED'
   OR COALESCE(@StandaloneGatePartial,0)<>1 OR @StandaloneGateError IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(@StandaloneGateMessage)),N'') IS NULL
   OR COALESCE(ISJSON(@StandaloneGateJson),0)<>1
    THROW 53640,N'Der öffentliche FULL-Pfad hat @HighImpactConfirmed=0 ohne Helfer nicht abgewiesen.',1;

SELECT @StandaloneGateJson=NULL,@StandaloneGateStatus='STALE',@StandaloneGatePartial=NULL,
       @StandaloneGateError=999,@StandaloneGateMessage=N'SENTINEL';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@StandaloneGatePlan
    , @AnalyseTiefe='FULL'
    , @HighImpactConfirmed=NULL
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@StandaloneGateJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@StandaloneGateStatus OUTPUT
    , @IsPartialOut=@StandaloneGatePartial OUTPUT
    , @ErrorNumberOut=@StandaloneGateError OUTPUT
    , @ErrorMessageOut=@StandaloneGateMessage OUTPUT;
IF COALESCE(@StandaloneGateStatus,'')<>'HIGH_IMPACT_CONFIRMATION_REQUIRED'
   OR COALESCE(@StandaloneGatePartial,0)<>1 OR @StandaloneGateError IS NOT NULL
   OR NULLIF(LTRIM(RTRIM(@StandaloneGateMessage)),N'') IS NULL
   OR COALESCE(ISJSON(@StandaloneGateJson),0)<>1
    THROW 53641,N'Der öffentliche FULL-Pfad hat @HighImpactConfirmed=NULL ohne Helfer nicht abgewiesen.',1;

/* Explizite 1 erreicht die Analyse, wenn der optionale Helfer nicht installiert ist. */
SELECT @StandaloneGateJson=NULL,@StandaloneGateStatus='STALE',@StandaloneGatePartial=NULL,
       @StandaloneGateError=999,@StandaloneGateMessage=N'SENTINEL';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@StandaloneGatePlan
    , @AnalyseTiefe='FULL'
    , @HighImpactConfirmed=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@StandaloneGateJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@StandaloneGateStatus OUTPUT
    , @IsPartialOut=@StandaloneGatePartial OUTPUT
    , @ErrorNumberOut=@StandaloneGateError OUTPUT
    , @ErrorMessageOut=@StandaloneGateMessage OUTPUT;
IF COALESCE(@StandaloneGateStatus,'') NOT IN ('AVAILABLE','PARTIAL')
   OR @StandaloneGatePartial IS NULL OR @StandaloneGateError IS NOT NULL
   OR COALESCE(ISJSON(@StandaloneGateJson),0)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@StandaloneGateJson,N'$.statements'))<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@StandaloneGateJson,N'$.operatorTree'))<>1
    THROW 53642,N'Der öffentliche FULL-Pfad hat @HighImpactConfirmed=1 ohne Helfer nicht erreicht oder lieferte nicht genau eine synthetische Statement- und Operatorzeile.',1;

/* Nicht angeforderter High-Impact-Pfad und NULL-Modusfallbacks bleiben zulässig. */
SELECT @StandaloneGateJson=NULL,@StandaloneGateStatus='STALE',@StandaloneGatePartial=NULL,
       @StandaloneGateError=999,@StandaloneGateMessage=N'SENTINEL';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml=@StandaloneGatePlan
    , @AnalyseTiefe='STANDARD'
    , @StatistikEvidenzModus=NULL
    , @HistogrammModus=NULL
    , @HighImpactConfirmed=NULL
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@StandaloneGateJson OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@StandaloneGateStatus OUTPUT
    , @IsPartialOut=@StandaloneGatePartial OUTPUT
    , @ErrorNumberOut=@StandaloneGateError OUTPUT
    , @ErrorMessageOut=@StandaloneGateMessage OUTPUT;
IF COALESCE(@StandaloneGateStatus,'') NOT IN ('AVAILABLE','PARTIAL')
   OR @StandaloneGatePartial IS NULL OR @StandaloneGateError IS NOT NULL
   OR COALESCE(ISJSON(@StandaloneGateJson),0)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@StandaloneGateJson,N'$.statements'))<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@StandaloneGateJson,N'$.operatorTree'))<>1
    THROW 53643,N'Unbenutztes NULL oder NULL-Modusfallbacks wurden ohne Helfer global abgewiesen oder lieferten nicht genau eine synthetische Statement- und Operatorzeile.',1;
GO

/* 4. Zweite Installation stellt den Helfer wieder her und prüft Idempotenz. */
:r Install_ExecutionPlanAnalysis.sql

USE [DeineDatenbank];
GO
SET NOCOUNT ON;

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisProfile]
    WHERE [ProfileCode]='EXAMPLE_LOCAL'
      AND [Description]=N'Synthetic local profile for the standalone installer contract.'
      AND [IsFrameworkDefault]=0
      AND [SeedVersion]=0
      AND [LastUpdatedUtc]=CONVERT(datetime2(0),'2026-01-01T00:00:00')
)
    THROW 53625,N'Die erneute Installation hat das synthetische lokale Profil verändert oder entfernt.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisRuleThreshold]
    WHERE [RuleCode]='EXAMPLE_CUSTOM_RULE'
      AND [ProfileCode]='EXAMPLE_LOCAL'
      AND [Severity]='INFO'
      AND [MinRatio]=CONVERT(decimal(19,6),2.500000)
      AND [IsFrameworkDefault]=0
      AND [SeedVersion]=0
      AND [LastUpdatedUtc]=CONVERT(datetime2(0),'2026-01-01T00:00:00')
)
    THROW 53626,N'Die erneute Installation hat den synthetischen lokalen Schwellenwert verändert oder entfernt.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisProfileAssignment]
    WHERE [ProfileCode]='EXAMPLE_LOCAL'
      AND [DatabaseNamePattern]=N'ExampleDatabase%'
      AND [IsFrameworkDefault]=0
      AND [Comment]=N'Synthetic local assignment for the standalone installer contract.'
      AND [LastUpdatedUtc]=CONVERT(datetime2(0),'2026-01-01T00:00:00')
)
    THROW 53627,N'Die erneute Installation hat die synthetische lokale Profilzuordnung verändert oder entfernt.',1;

/* 5. Nur die transitive PLAN-001-Abhängigkeitsschließung darf vorhanden sein. */
DECLARE @ExpectedObjects TABLE
(
      [ObjectName] sysname NOT NULL PRIMARY KEY
    , [ObjectType] char(2) NOT NULL
);

INSERT @ExpectedObjects([ObjectName],[ObjectType])
VALUES
  (N'VW_AnalyseClassCatalog','V')
, (N'VW_AnalyseAccessPolicy','V')
, (N'VW_AnalyseAccessCurrent','V')
, (N'TVF_ParsePipeList','TF')
, (N'TVF_ParseBigintList','IF')
, (N'InternalCheckAnalysisPath','P')
, (N'InternalWriteResultTable','P')
, (N'InternalPrepareResultTables','P')
, (N'InternalEmitConsoleResult','P')
, (N'PlanAnalysisProfile','U')
, (N'PlanAnalysisRuleThreshold','U')
, (N'PlanAnalysisProfileAssignment','U')
, (N'TVF_ParseStatisticsIoText','TF')
, (N'TVF_ParseStatisticsTimeText','TF')
, (N'TVF_ExecutionPlanObjectReferences','IF')
, (N'TVF_ExecutionPlanStatisticsUsage','IF')
, (N'TVF_ExecutionPlanColumnReferences','IF')
, (N'InternalCollectExecutionPlanMetadata','P')
, (N'InternalAnalyzeExecutionPlan','P')
, (N'USP_CreateExecutionEvidenceJson','P')
, (N'USP_ExecutionPlanAnalysis','P');

IF EXISTS
(
    SELECT 1
    FROM @ExpectedObjects AS [e]
    LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[name]=N'monitor'
    LEFT JOIN [sys].[objects] AS [o] WITH (NOLOCK)
      ON [o].[schema_id]=[s].[schema_id]
     AND [o].[name]=[e].[ObjectName]
     AND [o].[type] COLLATE DATABASE_DEFAULT=[e].[ObjectType]
    WHERE [o].[object_id] IS NULL
)
    THROW 53628,N'Die Standalone-Installation enthält nicht alle erforderlichen PLAN-001-Objekte.',1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[objects] AS [o] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[o].[schema_id]
    LEFT JOIN @ExpectedObjects AS [e]
      ON [e].[ObjectName]=[o].[name]
     AND [e].[ObjectType]=[o].[type] COLLATE DATABASE_DEFAULT
    WHERE [s].[name]=N'monitor'
      AND [o].[type] IN ('U','V','P','IF','TF','FN')
      AND [o].[is_ms_shipped]=0
      AND [e].[ObjectName] IS NULL
)
    THROW 53629,N'Die Standalone-Installation enthält ein unnötiges Frameworkmodul.',1;

/* 6. Keine unresolved Abhängigkeit zu einem nicht installierten monitor-Modul. */
IF EXISTS
(
    SELECT 1
    FROM [sys].[sql_expression_dependencies] AS [d] WITH (NOLOCK)
    JOIN [sys].[objects] AS [referencing] WITH (NOLOCK)
      ON [referencing].[object_id]=[d].[referencing_id]
    JOIN [sys].[schemas] AS [referencingSchema] WITH (NOLOCK)
      ON [referencingSchema].[schema_id]=[referencing].[schema_id]
    LEFT JOIN @ExpectedObjects AS [expectedReferenced]
      ON [expectedReferenced].[ObjectName]=[d].[referenced_entity_name]
    WHERE [referencingSchema].[name]=N'monitor'
      AND [referencing].[type] IN ('V','P','IF','TF','FN')
      AND [d].[referenced_database_name] IS NULL
      AND [d].[referenced_schema_name]=N'monitor'
      AND [expectedReferenced].[ObjectName] IS NULL
)
    THROW 53630,N'Die Standalone-Installation besitzt eine unresolved Abhängigkeit zu einem nicht installierten monitor-Modul.',1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[procedures] AS [p] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[p].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [p].[name]=N'USP_ShowplanAnalysis'
)
    THROW 53631,N'USP_ShowplanAnalysis wurde durch den Standalone-Installer installiert.',1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[database_query_store_options] WITH (NOLOCK)
    WHERE [actual_state_desc]<>N'OFF'
)
    THROW 53632,N'Der Standalone-Test hat Query Store aktiviert oder benötigt.',1;

CREATE TABLE [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions]
(
      [event_session_id] int NOT NULL PRIMARY KEY
    , [name] sysname NOT NULL
    , [startup_state] bit NULL
);

INSERT [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions]
(
      [event_session_id]
    , [name]
    , [startup_state]
)
SELECT [event_session_id],[name],[startup_state]
FROM [sys].[server_event_sessions] WITH (NOLOCK);

IF EXISTS
(
    SELECT 1
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline] AS [b]
    CROSS APPLY
    (
        SELECT
              COUNT_BIG(*) AS [MetricCount]
            , CHECKSUM_AGG(BINARY_CHECKSUM([event_session_id],[name],[startup_state])) AS [MetricChecksum]
        FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions]
    ) AS [currentState]
    WHERE [b].[MetricName]='SERVER_EVENT_SESSIONS'
      AND
      (
           [b].[MetricCount]<>[currentState].[MetricCount]
        OR ISNULL([b].[MetricChecksum],0)<>ISNULL([currentState].[MetricChecksum],0)
      )
)
BEGIN
    SELECT
          SYSUTCDATETIME() AS [DiagnosticCapturedUtc]
        , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductVersion')) AS [ProductVersion]
        , CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductLevel')) AS [ProductLevel]
        , CONVERT(nvarchar(128),SERVERPROPERTY(N'Edition')) AS [Edition];

    SELECT
          SUM(CONVERT(bigint,CASE WHEN [b].[event_session_id] IS NULL THEN 1 ELSE 0 END)) AS [AddedRows]
        , SUM(CONVERT(bigint,CASE WHEN [c].[event_session_id] IS NULL THEN 1 ELSE 0 END)) AS [RemovedRows]
        , SUM(CONVERT(bigint,CASE WHEN [b].[event_session_id] IS NOT NULL AND [c].[event_session_id] IS NOT NULL THEN 1 ELSE 0 END)) AS [ChangedRows]
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions] AS [b]
    FULL OUTER JOIN [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions] AS [c]
      ON [c].[event_session_id]=[b].[event_session_id]
    WHERE [b].[event_session_id] IS NULL
       OR [c].[event_session_id] IS NULL
       OR CONVERT(varbinary(256),[b].[name])<>CONVERT(varbinary(256),[c].[name])
       OR ([b].[startup_state]<>[c].[startup_state]
           OR [b].[startup_state] IS NULL AND [c].[startup_state] IS NOT NULL
           OR [b].[startup_state] IS NOT NULL AND [c].[startup_state] IS NULL);

    SELECT TOP (100)
          CASE
              WHEN [b].[event_session_id] IS NULL THEN 'ADDED'
              WHEN [c].[event_session_id] IS NULL THEN 'REMOVED'
              ELSE 'CHANGED'
          END AS [ChangeType]
        , COALESCE([b].[event_session_id],[c].[event_session_id]) AS [event_session_id]
        , [b].[name] AS [BeforeName]
        , [c].[name] AS [AfterName]
        , [b].[startup_state] AS [BeforeStartupState]
        , [c].[startup_state] AS [AfterStartupState]
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions] AS [b]
    FULL OUTER JOIN [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions] AS [c]
      ON [c].[event_session_id]=[b].[event_session_id]
    WHERE [b].[event_session_id] IS NULL
       OR [c].[event_session_id] IS NULL
       OR CONVERT(varbinary(256),[b].[name])<>CONVERT(varbinary(256),[c].[name])
       OR ([b].[startup_state]<>[c].[startup_state]
           OR [b].[startup_state] IS NULL AND [c].[startup_state] IS NOT NULL
           OR [b].[startup_state] IS NOT NULL AND [c].[startup_state] IS NULL)
    ORDER BY COALESCE([b].[event_session_id],[c].[event_session_id]);

    DECLARE
          @StandaloneXeDiagnosticBaselineRows bigint
        , @StandaloneXeDiagnosticCurrentRows bigint
        , @StandaloneXeDiagnosticAdded bigint
        , @StandaloneXeDiagnosticRemoved bigint
        , @StandaloneXeDiagnosticChanged bigint
        , @StandaloneXeDiagnosticFirstId int=-1
        , @StandaloneXeDiagnosticFirstType varchar(7)='NONE'
        , @StandaloneXeDiagnosticFirstBeforeName nvarchar(128)=N'<none>'
        , @StandaloneXeDiagnosticFirstAfterName nvarchar(128)=N'<none>'
        , @StandaloneXeDiagnosticFirstBeforeStartup nvarchar(8)=N'<none>'
        , @StandaloneXeDiagnosticFirstAfterStartup nvarchar(8)=N'<none>'
        , @StandaloneXeDiagnosticUtc nvarchar(33)=CONVERT(nvarchar(33),SYSUTCDATETIME(),126)
        , @StandaloneXeDiagnosticVersion nvarchar(128)=CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductVersion'))
        , @StandaloneXeDiagnosticBaselineText nvarchar(20)
        , @StandaloneXeDiagnosticCurrentText nvarchar(20)
        , @StandaloneXeDiagnosticAddedText nvarchar(20)
        , @StandaloneXeDiagnosticRemovedText nvarchar(20)
        , @StandaloneXeDiagnosticChangedText nvarchar(20)
        , @StandaloneXeDiagnosticFirstIdText nvarchar(11)
        , @StandaloneXeDiagnosticAdditionalText nvarchar(20)
        , @StandaloneXeDiagnosticTruncatedText nvarchar(1);

    SELECT @StandaloneXeDiagnosticBaselineRows=[MetricCount]
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline]
    WHERE [MetricName]='SERVER_EVENT_SESSIONS';

    SELECT @StandaloneXeDiagnosticCurrentRows=COUNT_BIG(*)
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions];

    SELECT
          @StandaloneXeDiagnosticAdded=COUNT_BIG(CASE WHEN [b].[event_session_id] IS NULL THEN 1 END)
        , @StandaloneXeDiagnosticRemoved=COUNT_BIG(CASE WHEN [c].[event_session_id] IS NULL THEN 1 END)
        , @StandaloneXeDiagnosticChanged=COUNT_BIG(CASE WHEN [b].[event_session_id] IS NOT NULL AND [c].[event_session_id] IS NOT NULL THEN 1 END)
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions] AS [b]
    FULL OUTER JOIN [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions] AS [c]
      ON [c].[event_session_id]=[b].[event_session_id]
    WHERE [b].[event_session_id] IS NULL
       OR [c].[event_session_id] IS NULL
       OR CONVERT(varbinary(256),[b].[name])<>CONVERT(varbinary(256),[c].[name])
       OR ([b].[startup_state]<>[c].[startup_state]
           OR [b].[startup_state] IS NULL AND [c].[startup_state] IS NOT NULL
           OR [b].[startup_state] IS NOT NULL AND [c].[startup_state] IS NULL);

    SELECT TOP (1)
          @StandaloneXeDiagnosticFirstType=CASE
              WHEN [b].[event_session_id] IS NULL THEN 'ADDED'
              WHEN [c].[event_session_id] IS NULL THEN 'REMOVED'
              ELSE 'CHANGED'
          END
        , @StandaloneXeDiagnosticFirstId=COALESCE([b].[event_session_id],[c].[event_session_id])
        , @StandaloneXeDiagnosticFirstBeforeName=COALESCE([b].[name],N'<absent>')
        , @StandaloneXeDiagnosticFirstAfterName=COALESCE([c].[name],N'<absent>')
        , @StandaloneXeDiagnosticFirstBeforeStartup=CASE WHEN [b].[event_session_id] IS NULL THEN N'<absent>' WHEN [b].[startup_state] IS NULL THEN N'<NULL>' ELSE CONVERT(nvarchar(8),[b].[startup_state]) END
        , @StandaloneXeDiagnosticFirstAfterStartup=CASE WHEN [c].[event_session_id] IS NULL THEN N'<absent>' WHEN [c].[startup_state] IS NULL THEN N'<NULL>' ELSE CONVERT(nvarchar(8),[c].[startup_state]) END
    FROM [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Baseline_EventSessions] AS [b]
    FULL OUTER JOIN [#193_ExecutionPlanAnalysis_Standalone_Runtime_Contract_Current_EventSessions] AS [c]
      ON [c].[event_session_id]=[b].[event_session_id]
    WHERE [b].[event_session_id] IS NULL
       OR [c].[event_session_id] IS NULL
       OR CONVERT(varbinary(256),[b].[name])<>CONVERT(varbinary(256),[c].[name])
       OR ([b].[startup_state]<>[c].[startup_state]
           OR [b].[startup_state] IS NULL AND [c].[startup_state] IS NOT NULL
           OR [b].[startup_state] IS NOT NULL AND [c].[startup_state] IS NULL)
    ORDER BY COALESCE([b].[event_session_id],[c].[event_session_id]);

    SELECT
          @StandaloneXeDiagnosticBaselineText=CONVERT(nvarchar(20),@StandaloneXeDiagnosticBaselineRows)
        , @StandaloneXeDiagnosticCurrentText=CONVERT(nvarchar(20),@StandaloneXeDiagnosticCurrentRows)
        , @StandaloneXeDiagnosticAddedText=CONVERT(nvarchar(20),@StandaloneXeDiagnosticAdded)
        , @StandaloneXeDiagnosticRemovedText=CONVERT(nvarchar(20),@StandaloneXeDiagnosticRemoved)
        , @StandaloneXeDiagnosticChangedText=CONVERT(nvarchar(20),@StandaloneXeDiagnosticChanged)
        , @StandaloneXeDiagnosticFirstIdText=CONVERT(nvarchar(11),@StandaloneXeDiagnosticFirstId)
        , @StandaloneXeDiagnosticAdditionalText=CONVERT(nvarchar(20),CASE
              WHEN @StandaloneXeDiagnosticAdded+@StandaloneXeDiagnosticRemoved+@StandaloneXeDiagnosticChanged>0
              THEN @StandaloneXeDiagnosticAdded+@StandaloneXeDiagnosticRemoved+@StandaloneXeDiagnosticChanged-1
              ELSE 0
          END)
        , @StandaloneXeDiagnosticTruncatedText=CASE
              WHEN @StandaloneXeDiagnosticAdded+@StandaloneXeDiagnosticRemoved+@StandaloneXeDiagnosticChanged>100 THEN N'Y' ELSE N'N'
          END;

    RAISERROR
    (
        N'Error: STANDALONE_XE_DIAGNOSTIC utc=%s version=%s baselineRows=%s currentRows=%s added=%s removed=%s changed=%s firstChange=%s id=%s before=%s/startup=%s after=%s/startup=%s additionalDiffRows=%s detailTruncated=%s'
        , 10
        , 1
        , @StandaloneXeDiagnosticUtc
        , @StandaloneXeDiagnosticVersion
        , @StandaloneXeDiagnosticBaselineText
        , @StandaloneXeDiagnosticCurrentText
        , @StandaloneXeDiagnosticAddedText
        , @StandaloneXeDiagnosticRemovedText
        , @StandaloneXeDiagnosticChangedText
        , @StandaloneXeDiagnosticFirstType
        , @StandaloneXeDiagnosticFirstIdText
        , @StandaloneXeDiagnosticFirstBeforeName
        , @StandaloneXeDiagnosticFirstBeforeStartup
        , @StandaloneXeDiagnosticFirstAfterName
        , @StandaloneXeDiagnosticFirstAfterStartup
        , @StandaloneXeDiagnosticAdditionalText
        , @StandaloneXeDiagnosticTruncatedText
    ) WITH NOWAIT;

    THROW 53633,N'Der Standalone-Test hat die Extended-Events-Sessionkonfiguration verändert.',1;
END;

DELETE [monitor].[PlanAnalysisProfileAssignment]
WHERE [ProfileCode]='EXAMPLE_LOCAL';

DELETE [monitor].[PlanAnalysisRuleThreshold]
WHERE [ProfileCode]='EXAMPLE_LOCAL';

DELETE [monitor].[PlanAnalysisProfile]
WHERE [ProfileCode]='EXAMPLE_LOCAL';

SELECT
      N'ExecutionPlanAnalysisStandalone' AS [ContractName]
    , N'PASSED' AS [StatusCode]
    , N'First install, public APIs, reinstall, scope and independence passed with synthetic values only.' AS [Detail];
GO
