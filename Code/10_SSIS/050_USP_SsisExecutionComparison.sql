USE [DeineDatenbank];
GO

/* monitor.USP_SsisExecutionComparison; Version 1.0.0; Stand 2026-10-25.
   Vergleicht genau zwei unabhängig gebundene Captures desselben Exports.
   Modellvalidierung, Scopeauflösung und Kennzahlen bleiben bei den bestehenden
   Consumern. Es erfolgen weder SSISDB-Reads noch Paket-/SQL-Ausführung oder CLR.
   Pfade bezeichnen beobachtete Positionen; Arbeitslastgleichheit bleibt unbelegt.
   Zwei 16-MiB-Modelle und zwei 16-MiB-Captures, je 50000 Quellbelege, höchstens
   200000 Kennzahlen je Seite und ein gemeinsames kooperatives Zeitbudget. */
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisExecutionComparison]
 @BaselineProjectModelsJson nvarchar(max)=NULL,@BaselineScopeSnapshotJson nvarchar(max)=NULL,
 @BaselineScopeHandoverId uniqueidentifier=NULL,@BaselineExecutionId bigint=NULL,
 @CandidateProjectModelsJson nvarchar(max)=NULL,@CandidateScopeSnapshotJson nvarchar(max)=NULL,
 @CandidateScopeHandoverId uniqueidentifier=NULL,@CandidateExecutionId bigint=NULL,
 @MinDurationDeltaMs bigint=NULL,@MinDurationDeltaPercent decimal(9,4)=NULL,
 @MaxZeilen int=1000,@MaxDurationSeconds int=30,@LockTimeoutMs int=0,
 @ResultSetArt varchar(16)='CONSOLE',@ResultTablesJson nvarchar(max)=NULL,
 @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,@PrintMeldungen bit=1,@Hilfe bit=0,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,
 @ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;
 IF @Hilfe=1
 BEGIN
  PRINT N'monitor.USP_SsisExecutionComparison: zwei lokal gebundene Scope-/Pipelinecaptures desselben exakten Modellexports; kein CLR oder SSISDB-Zugriff.';
  PRINT N'Pro Seite: @*ProjectModelsJson, @*ScopeSnapshotJson, @*ScopeHandoverId und @*ExecutionId. Vergleichskontext aus -IncludeComparisonContext.';
  PRINT N'CONSOLE|RAW|TABLE|NONE; JSON über OUTPUT. Gruppen: comparisonBinding|objectComparison|comparisonFindings|comparisonCoverage.';
  PRINT N'Grenzwerte sind optional und nichtnegativ; beide gesetzten Dauergrenzen müssen überschritten sein. Prozentänderung bei Basis null bleibt unbekannt.';
  PRINT N'Gleiche Pfade belegen Positionsbezug, keine gleiche Datei oder Zeile. Alle Ausgaben bleiben partiell; Hinweise beweisen keine Regressionsursache.';
  RETURN;
 END;
 IF XACT_STATE()=-1 THROW 50000,N'COMPARISON_INVALID: Callertransaktion ist nicht schreibfähig.',1;
 DECLARE @savedX bit=CASE WHEN @@OPTIONS&16384=16384 THEN 1 ELSE 0 END;
 SET XACT_ABORT OFF;
 DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80),@setLock nvarchar(80),
  @mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS,
  @limit int=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END,
  @deadline datetime2(3)=DATEADD(second,COALESCE(@MaxDurationSeconds,30),SYSUTCDATETIME()),
  @status varchar(40)='COMPARISON_BINDING_UNPROVEN',@reason varchar(64)=NULL,@error int=NULL,@canPair bit=0,
  @context varchar(40)='CONTEXT_UNPROVEN',@sameExport bit=0;
 DECLARE @ConsoleResultRequested bit=CASE WHEN @mode='CONSOLE' THEN 1 ELSE 0 END;
 CREATE TABLE #SsisExecutionComparison_Binding(
  [BaselineExecutionId] bigint NULL,[CandidateExecutionId] bigint NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [BaselineProjectLsn] bigint NULL,[CandidateProjectLsn] bigint NULL,[BaselineArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ModelExportMatch] bit NOT NULL,[BaselineLoggingLevel] int NULL,[CandidateLoggingLevel] int NULL,[BaselineUse32BitRuntime] bit NULL,[CandidateUse32BitRuntime] bit NULL,
  [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WorkloadEquivalence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL);
 CREATE TABLE #SsisExecutionComparison_Objects(
  [ComparisonKeySha256] binary(32) NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [BaselineValue] decimal(38,0) NULL,[CandidateValue] decimal(38,0) NULL,[DeltaValue] decimal(38,0) NULL,[DeltaPercent] decimal(38,6) NULL,
  [ComparisonStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [BaselineSourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineSourceId] bigint NULL,[CandidateSourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateSourceId] bigint NULL,
  [BaselineMatchCount] int NOT NULL,[CandidateMatchCount] int NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionComparison_Findings(
  [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleVersion] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ComparisonKeySha256] binary(32) NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineSourceId] bigint NULL,[CandidateSourceId] bigint NULL,
  [ObservedDelta] decimal(38,0) NULL,[ThresholdMs] bigint NULL,[ThresholdPercent] decimal(9,4) NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionComparison_Coverage(
  [Scope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [SourceRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[UnassignedRowCount] int NOT NULL,[UnknownValueCount] int NOT NULL,
  [PairedMetricCount] int NOT NULL,[BaselineOnlyCount] int NOT NULL,[CandidateOnlyCount] int NOT NULL,[AmbiguousMetricCount] int NOT NULL,[NotComparableMetricCount] int NOT NULL,
  [OutputTruncated] bit NOT NULL,[IsPartial] bit NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE #SsisExecutionComparison_Map([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE #SsisExecutionComparison_Sides(
  [Side] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[Models] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Capture] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [HandoverId] uniqueidentifier NULL,[ExecutionId] bigint NULL,[Analysis] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Use32BitRuntime] bit NULL,[PhaseSourceQualified] bit NOT NULL DEFAULT(0),[PathSourceQualified] bit NOT NULL DEFAULT(0));
 INSERT #SsisExecutionComparison_Sides([Side],[Models],[Capture],[HandoverId],[ExecutionId]) VALUES('B',@BaselineProjectModelsJson,@BaselineScopeSnapshotJson,@BaselineScopeHandoverId,@BaselineExecutionId),('C',@CandidateProjectModelsJson,@CandidateScopeSnapshotJson,@CandidateScopeHandoverId,@CandidateExecutionId);
 CREATE TABLE #SsisExecutionComparison_MetricInput(
  [RunOrdinal] int NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [Value] decimal(38,0) NULL,[Quality] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NULL,[KeyJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[KeyHash] binary(32) NULL,[VolumeSignature] binary(32) NULL);
 BEGIN TRY
  IF @mode<>'TABLE' AND @ResultTablesJson IS NOT NULL THROW 51011,N'ResultTablesJson ist ausschließlich für TABLE zulässig.',1;
  IF @mode='TABLE' EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'comparisonBinding|objectComparison|comparisonFindings|comparisonCoverage',@MappingTable=N'#SsisExecutionComparison_Map',@ThrowOnError=1;
  IF @mode NOT IN('RAW','TABLE','CONSOLE','NONE') OR @limit<1 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60 OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000 OR @JsonErzeugen IS NULL
   OR COALESCE(@BaselineExecutionId,0)<1 OR COALESCE(@CandidateExecutionId,0)<1 OR @BaselineExecutionId=@CandidateExecutionId OR @MinDurationDeltaMs<0 OR @MinDurationDeltaPercent<0 THROW 57930,N'INVALID_PARAMETER',1;
  SET @setLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';EXEC sys.sp_executesql @setLock;
  IF EXISTS(SELECT 1 FROM #SsisExecutionComparison_Sides WHERE COALESCE(ISJSON([Models]),0)<>1 OR COALESCE(ISJSON([Capture]),0)<>1 OR DATALENGTH([Models])>16777216 OR DATALENGTH([Capture])>16777216) THROW 57930,N'COMPARISON_TRANSPORT_INVALID',1;
  DECLARE @side char(1),@models nvarchar(max),@capture nvarchar(max),@handover uniqueidentifier,@execution bigint,@analysis nvarchar(max),@childStatus varchar(40),@remaining int;
  DECLARE [comparisonSides] CURSOR LOCAL FAST_FORWARD FOR SELECT [Side],[Models],[Capture],[HandoverId],[ExecutionId] FROM #SsisExecutionComparison_Sides ORDER BY [Side];
  OPEN [comparisonSides];FETCH NEXT FROM [comparisonSides] INTO @side,@models,@capture,@handover,@execution;
  WHILE @@FETCH_STATUS=0
  BEGIN
   DECLARE @run int=CASE WHEN @side='B' THEN 0 ELSE 1 END,@bitness bit,@captureBound bit,@metricsJson nvarchar(max),@metricError int,@metricReason varchar(64);
   EXEC [monitor].[InternalSsisExecutionMetrics] @run,@models,@capture,@handover,@execution,@deadline,@LockTimeoutMs,@analysis OUTPUT,@childStatus OUTPUT,@bitness OUTPUT,@captureBound OUTPUT,@metricsJson OUTPUT,@metricError OUTPUT,@metricReason OUTPUT;
   UPDATE #SsisExecutionComparison_Sides SET [Analysis]=@analysis,[StatusCode]=@childStatus,[Use32BitRuntime]=@bitness WHERE [Side]=@side;
   IF @metricError IS NOT NULL THROW 57930,@metricReason,1;
   IF @captureBound<>1 THROW 57930,N'COMPARISON_SIDE_BINDING_UNPROVEN',1;
   INSERT #SsisExecutionComparison_MetricInput SELECT [RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId],[KeyJson],CONVERT(binary(32),[KeyHashHex],2),CONVERT(binary(32),[VolumeSignatureHex],2) FROM OPENJSON(@metricsJson) WITH([RunOrdinal] int,[ObjectKind] varchar(16),[PackageKey] varchar(16),[ModelNodeId] varchar(128),[FlowNodeId] varchar(128),[ExecutionPath] nvarchar(4000),[PhaseName] nvarchar(128),[PortRole] varchar(16),[MetricName] varchar(32),[Unit] varchar(16),[Value] decimal(38,0),[Quality] varchar(32),[SourceName] varchar(32),[SourceId] bigint,[KeyJson] nvarchar(max),[KeyHashHex] varchar(64),[VolumeSignatureHex] varchar(64));
   IF EXISTS(SELECT 1 FROM #SsisExecutionComparison_MetricInput GROUP BY [KeyHash] HAVING MIN([KeyJson] COLLATE Latin1_General_100_BIN2)<>MAX([KeyJson] COLLATE Latin1_General_100_BIN2) OR MIN(DATALENGTH([KeyJson]))<>MAX(DATALENGTH([KeyJson]))) THROW 57930,N'COMPARISON_KEY_COLLISION',1;
   FETCH NEXT FROM [comparisonSides] INTO @side,@models,@capture,@handover,@execution;
  END;CLOSE [comparisonSides];DEALLOCATE [comparisonSides];
  SET @sameExport=CASE WHEN HASHBYTES('SHA2_256',CONVERT(varbinary(max),@BaselineProjectModelsJson))=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CandidateProjectModelsJson)) THEN 1 ELSE 0 END;
  IF @sameExport=0 THROW 57930,N'COMPARISON_MODEL_EXPORT_DIFFERENT',1;
  IF EXISTS(SELECT 1 FROM (VALUES('projectId'),('projectLsn'),('catalogDatabaseGuid'),('sourceBindingSha256'),('packageFileName')) AS [fields]([name])
    CROSS APPLY(SELECT JSON_VALUE(@BaselineScopeSnapshotJson,'$.execution.'+[name]) AS [b],JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.'+[name]) AS [c]) AS [v]
    WHERE [v].[b] IS NULL OR [v].[c] IS NULL OR [v].[b] COLLATE Latin1_General_100_BIN2<>[v].[c] COLLATE Latin1_General_100_BIN2 OR DATALENGTH([v].[b])<>DATALENGTH([v].[c]))
    OR JSON_VALUE(@BaselineScopeSnapshotJson,'$.archiveSha256') COLLATE Latin1_General_100_BIN2<>JSON_VALUE(@CandidateScopeSnapshotJson,'$.archiveSha256') COLLATE Latin1_General_100_BIN2 THROW 57930,N'COMPARISON_SOURCE_VERSION_DIFFERENT',1;
  SET @canPair=1;SET @status='COMPARISON_CAPTURE_BOUND';
  SET @context=CASE WHEN EXISTS(SELECT 1 FROM #SsisExecutionComparison_Sides WHERE [Use32BitRuntime] IS NULL) THEN 'RUNTIME_CONTEXT_UNPROVEN'
   WHEN (SELECT [Use32BitRuntime] FROM #SsisExecutionComparison_Sides WHERE [Side]='B')<>(SELECT [Use32BitRuntime] FROM #SsisExecutionComparison_Sides WHERE [Side]='C') THEN 'RUNTIME_BITNESS_DIFFERENT'
   WHEN COALESCE(TRY_CONVERT(int,JSON_VALUE(@BaselineScopeSnapshotJson,'$.execution.loggingLevel')),0) NOT IN(1,2,3) OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.loggingLevel')),0) NOT IN(1,2,3) THEN 'LOGGING_CONTEXT_UNPROVEN'
   WHEN JSON_VALUE(@BaselineScopeSnapshotJson,'$.execution.loggingLevel')<>JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.loggingLevel') THEN 'LOGGING_LEVEL_DIFFERENT'
   WHEN COALESCE(TRY_CONVERT(int,JSON_VALUE(@BaselineScopeSnapshotJson,'$.execution.executionStatus')),0)<>7 OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.executionStatus')),0)<>7 THEN 'NOT_BOTH_SUCCEEDED'
   ELSE 'MATCHED_OBSERVATION_CONTEXT' END;
  ;WITH [g] AS(
   SELECT [KeyHash],MAX([ObjectKind]) [ObjectKind],MAX([PackageKey]) [PackageKey],MAX([ModelNodeId]) [ModelNodeId],MAX([FlowNodeId]) [FlowNodeId],MAX([ExecutionPath]) [ExecutionPath],MAX([PhaseName]) [PhaseName],MAX([PortRole]) [PortRole],MAX([MetricName]) [MetricName],MAX([Unit]) [Unit],
    SUM(CASE WHEN [RunOrdinal]=0 THEN 1 ELSE 0 END) [BCount],SUM(CASE WHEN [RunOrdinal]=1 THEN 1 ELSE 0 END) [CCount],
    MAX(CASE WHEN [RunOrdinal]=0 THEN [Value] END) [BValue],MAX(CASE WHEN [RunOrdinal]=1 THEN [Value] END) [CValue],
    MAX(CASE WHEN [RunOrdinal]=0 THEN [SourceName] END) [BSource],MAX(CASE WHEN [RunOrdinal]=1 THEN [SourceName] END) [CSource],MAX(CASE WHEN [RunOrdinal]=0 THEN [SourceId] END) [BId],MAX(CASE WHEN [RunOrdinal]=1 THEN [SourceId] END) [CId],
    SUM(CASE WHEN [Quality]='UNKNOWN' THEN 1 ELSE 0 END) [UnknownCount],SUM(CASE WHEN [Quality]='AMBIGUOUS' THEN 1 ELSE 0 END) [AmbiguousCount],SUM(CASE WHEN [Quality]='LIMITED' THEN 1 ELSE 0 END) [LimitedCount]
   FROM #SsisExecutionComparison_MetricInput GROUP BY [KeyHash])
  INSERT #SsisExecutionComparison_Objects
  SELECT [KeyHash],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],CASE WHEN [BCount]=1 THEN [BValue] END,CASE WHEN [CCount]=1 THEN [CValue] END,
   CASE WHEN [BCount]=1 AND [CCount]=1 AND [UnknownCount]=0 AND [AmbiguousCount]=0 AND [LimitedCount]=0 AND [Unit]<>'STATUS' AND @context='MATCHED_OBSERVATION_CONTEXT' THEN [CValue]-[BValue] END,NULL,
   CASE WHEN [BCount]>1 OR [CCount]>1 OR [AmbiguousCount]>0 THEN 'AMBIGUOUS' WHEN [BCount]=0 THEN 'CANDIDATE_ONLY' WHEN [CCount]=0 THEN 'BASELINE_ONLY' WHEN [UnknownCount]>0 OR [LimitedCount]>0 THEN 'NOT_COMPARABLE' WHEN [Unit]='STATUS' THEN 'STATUS_ONLY' WHEN @context<>'MATCHED_OBSERVATION_CONTEXT' THEN 'CONTEXT_LIMITED' ELSE 'COMPARABLE_OBSERVATION' END,
   CASE WHEN [BCount]>1 OR [CCount]>1 OR [AmbiguousCount]>0 THEN 'INVOCATION_PAIRING_UNPROVEN' WHEN [BCount]=0 OR [CCount]=0 THEN 'NOT_OBSERVED_ON_BOTH_SIDES' WHEN [UnknownCount]>0 THEN 'UNKNOWN_METRIC_VALUE' WHEN [LimitedCount]>0 THEN 'SOURCE_COVERAGE_LIMITED' WHEN [Unit]='STATUS' THEN 'OBSERVED_STATUS' WHEN @context<>'MATCHED_OBSERVATION_CONTEXT' THEN @context ELSE 'OBSERVED_VALUES_ONLY' END,
   [BSource],CASE WHEN [BCount]=1 THEN [BId] END,[CSource],CASE WHEN [CCount]=1 THEN [CId] END,[BCount],[CCount],1 FROM [g];
  -- Ganzzahliger Quotient und Rest vermeiden Rundungsverluste durch die
  -- automatische decimal-Skalenreduktion. Die Quellcaps begrenzen Phasensummen
  -- auf 50000 bigint-Intervalle; der mit 10^8 skalierte Zähler passt in decimal(38,0).
  UPDATE [o] SET [DeltaPercent]=TRY_CONVERT(decimal(38,6),
   CONVERT(decimal(38,0),SIGN([o].[DeltaValue])*(([n].[v]-[r].[v])/[o].[BaselineValue]+CASE WHEN [r].[v]*2>=[o].[BaselineValue] THEN 1 ELSE 0 END))/CONVERT(decimal(7,0),1000000))
  FROM #SsisExecutionComparison_Objects AS [o]
  CROSS APPLY(SELECT ABS([o].[DeltaValue])*CONVERT(decimal(9,0),100000000) AS [v]) AS [n]
  CROSS APPLY(SELECT [n].[v]%NULLIF([o].[BaselineValue],0) AS [v]) AS [r]
  WHERE [o].[DeltaValue] IS NOT NULL AND [o].[BaselineValue]>0;
  -- Volumenbezug bleibt auf die tatsächlich beobachteten Pfadsets beschränkt.
  -- Gleiche beobachtete Zähler beweisen keine gleichen Datensätze oder Parameter.
  UPDATE [o] SET [ComparisonStatus]='VOLUME_CONTEXT_LIMITED',[ReasonCode]='OBSERVED_PATH_VOLUME_DIFFERENT_OR_UNKNOWN'
  FROM #SsisExecutionComparison_Objects AS [o] WHERE [o].[Unit]='MS' AND [o].[ComparisonStatus]='COMPARABLE_OBSERVATION' AND NOT EXISTS(
   SELECT 1 FROM #SsisExecutionComparison_MetricInput AS [b] JOIN #SsisExecutionComparison_MetricInput AS [c] ON [c].[KeyHash]=[b].[KeyHash] AND [c].[RunOrdinal]=1
   WHERE [b].[RunOrdinal]=0 AND [b].[KeyHash]=[o].[ComparisonKeySha256] AND [b].[VolumeSignature]=[c].[VolumeSignature]);
  INSERT #SsisExecutionComparison_Findings
  SELECT CASE WHEN [Unit]='STATUS' THEN 'SSIS_COMPARISON_STATUS_CHANGED' WHEN [MetricName]='PATH_ROWS_SENT' THEN 'SSIS_COMPARISON_OBSERVED_ROWS_CHANGED' ELSE 'SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED' END,'1.0.0','INFO',[ComparisonKeySha256],[MetricName],[BaselineSourceId],[CandidateSourceId],[DeltaValue],@MinDurationDeltaMs,@MinDurationDeltaPercent,
   CASE WHEN [Unit]='STATUS' THEN 'OBSERVED_STATUS_CHANGED' WHEN [MetricName]='PATH_ROWS_SENT' THEN 'OBSERVED_ROWS_CHANGED' ELSE 'HIGHER_OBSERVED_DURATION_WORKLOAD_UNPROVEN' END,1
  FROM #SsisExecutionComparison_Objects WHERE
   ([ComparisonStatus]='STATUS_ONLY' AND [BaselineValue]<>[CandidateValue])
   OR ([MetricName]='PATH_ROWS_SENT' AND [ComparisonStatus]='COMPARABLE_OBSERVATION' AND [DeltaValue]<>0)
   OR ([Unit]='MS' AND [ComparisonStatus]='COMPARABLE_OBSERVATION' AND [DeltaValue]>0 AND (@MinDurationDeltaMs IS NOT NULL OR @MinDurationDeltaPercent IS NOT NULL) AND (@MinDurationDeltaMs IS NULL OR [DeltaValue]>@MinDurationDeltaMs) AND (@MinDurationDeltaPercent IS NULL OR ([BaselineValue]>0 AND [DeltaValue]*CONVERT(decimal(7,0),1000000)>[BaselineValue]*CONVERT(decimal(9,0),@MinDurationDeltaPercent*10000))));
  IF SYSUTCDATETIME()>=@deadline THROW 57930,N'COMPARISON_TIME_LIMIT',1;
 END TRY
 BEGIN CATCH
  SELECT @error=COALESCE(@metricError,ERROR_NUMBER()),@reason=CASE WHEN ERROR_NUMBER()=57930 THEN CONVERT(varchar(64),ERROR_MESSAGE()) ELSE 'COMPARISON_INPUT_REJECTED' END;
  IF @error=51011 BEGIN SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;THROW;END;
  IF CURSOR_STATUS('local','comparisonSides')>=0 CLOSE [comparisonSides];IF CURSOR_STATUS('local','comparisonSides')>-3 DEALLOCATE [comparisonSides];
  SELECT @canPair=0,@status=CASE WHEN @reason='INVALID_PARAMETER' THEN 'INVALID_PARAMETER' ELSE 'COMPARISON_BINDING_UNPROVEN' END;
  DELETE #SsisExecutionComparison_Objects;DELETE #SsisExecutionComparison_Findings;
 END CATCH;
 BEGIN TRY
 INSERT #SsisExecutionComparison_Binding
 SELECT @BaselineExecutionId,@CandidateExecutionId,@status,@reason,[b].[StatusCode],[c].[StatusCode],TRY_CONVERT(bigint,JSON_VALUE([b].[Analysis],'$.scopeBinding[0].ProjectLsn')),TRY_CONVERT(bigint,JSON_VALUE([c].[Analysis],'$.scopeBinding[0].ProjectLsn')),JSON_VALUE([b].[Analysis],'$.scopeBinding[0].ArchiveSha256'),JSON_VALUE([c].[Analysis],'$.scopeBinding[0].ArchiveSha256'),@sameExport,
  TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([b].[Capture])=1 THEN [b].[Capture] ELSE N'{}' END,'$.execution.loggingLevel')),TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([c].[Capture])=1 THEN [c].[Capture] ELSE N'{}' END,'$.execution.loggingLevel')),[b].[Use32BitRuntime],[c].[Use32BitRuntime],@context,'UNPROVEN',1,@error
 FROM #SsisExecutionComparison_Sides AS [b] CROSS JOIN #SsisExecutionComparison_Sides AS [c] WHERE [b].[Side]='B' AND [c].[Side]='C';
 INSERT #SsisExecutionComparison_Coverage
 SELECT CASE WHEN [s].[Side]='B' THEN 'BASELINE' ELSE 'CANDIDATE' END,[p].[SourceName],[p].[StatusCode],[p].[ObservedRowCount],[p].[MappedRowCount],[p].[UnassignedRowCount],[p].[UnknownValueCount],0,0,0,0,0,0,1,[p].[ReasonCode]
 FROM #SsisExecutionComparison_Sides AS [s] CROSS APPLY OPENJSON([s].[Analysis],'$.pipelineDiagnosticCoverage') WITH([SourceName] varchar(32),[StatusCode] varchar(40),[ObservedRowCount] int,[MappedRowCount] int,[UnassignedRowCount] int,[UnknownValueCount] int,[ReasonCode] varchar(64)) AS [p];
 INSERT #SsisExecutionComparison_Coverage SELECT 'PAIR','metrics',@status,(SELECT COUNT(*) FROM #SsisExecutionComparison_MetricInput),(SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [BaselineMatchCount]=1 AND [CandidateMatchCount]=1),0,0,
  (SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [BaselineMatchCount]=1 AND [CandidateMatchCount]=1),(SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [ComparisonStatus]='BASELINE_ONLY'),(SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [ComparisonStatus]='CANDIDATE_ONLY'),(SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [ComparisonStatus]='AMBIGUOUS'),(SELECT COUNT(*) FROM #SsisExecutionComparison_Objects WHERE [ComparisonStatus] NOT IN('COMPARABLE_OBSERVATION','STATUS_ONLY')),0,1,COALESCE(@reason,'OBSERVED_POSITION_AND_VALUES_ONLY');
 IF @canPair=0 OR @context<>'MATCHED_OBSERVATION_CONTEXT' OR EXISTS(SELECT 1 FROM #SsisExecutionComparison_Objects WHERE [ComparisonStatus] NOT IN('COMPARABLE_OBSERVATION','STATUS_ONLY')) OR EXISTS(SELECT 1 FROM #SsisExecutionComparison_Coverage WHERE [UnassignedRowCount]>0 OR [UnknownValueCount]>0 OR [StatusCode] NOT IN('AVAILABLE','AVAILABLE_EMPTY','COMPARISON_CAPTURE_BOUND'))
  INSERT #SsisExecutionComparison_Findings VALUES('SSIS_COMPARISON_EVIDENCE_LIMITED','1.0.0','INFO',NULL,NULL,NULL,NULL,NULL,NULL,NULL,COALESCE(@reason,CASE WHEN @context<>'MATCHED_OBSERVATION_CONTEXT' THEN @context ELSE 'PARTIAL_METRIC_COMPARABILITY' END),1);
 UPDATE #SsisExecutionComparison_Coverage SET [OutputTruncated]=CASE WHEN (SELECT COUNT(*) FROM #SsisExecutionComparison_Objects)>@limit OR (SELECT COUNT(*) FROM #SsisExecutionComparison_Findings)>@limit OR (SELECT COUNT(*) FROM #SsisExecutionComparison_Coverage)>@limit THEN 1 ELSE 0 END;
 DECLARE @spec nvarchar(max)=N'[{"name":"comparisonBinding","table":"#SsisExecutionComparison_Binding","order":"BaselineExecutionId"},{"name":"objectComparison","table":"#SsisExecutionComparison_Objects","order":"ComparisonKeySha256"},{"name":"comparisonFindings","table":"#SsisExecutionComparison_Findings","order":"RuleId,ComparisonKeySha256"},{"name":"comparisonCoverage","table":"#SsisExecutionComparison_Coverage","order":"Scope,SourceName"}]';
 IF @JsonErzeugen=1 SET @Json=N'{"meta":{"schemaVersion":1,"comparisonSchemaVersion":1,"isPartial":true}}';
 DECLARE @name sysname,@table sysname,@order nvarchar(128),@target sysname,@array nvarchar(max),@sql nvarchar(max);
 DECLARE [comparisonOutputs] CURSOR LOCAL FAST_FORWARD FOR SELECT [name],[table],[order] FROM OPENJSON(@spec) WITH([name] sysname,[table] sysname,[order] nvarchar(128));OPEN [comparisonOutputs];FETCH NEXT FROM [comparisonOutputs] INTO @name,@table,@order;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @sql=N'SELECT @a=COALESCE((SELECT TOP(@n) * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N' FOR JSON PATH,INCLUDE_NULL_VALUES),N''[]'');';EXEC sys.sp_executesql @sql,N'@n int,@a nvarchar(max) OUTPUT',@n=@limit,@a=@array OUTPUT;
  IF @JsonErzeugen=1 SET @Json=JSON_MODIFY(@Json,'$.'+@name,JSON_QUERY(@array));
  SET @sql=N';WITH r AS(SELECT *,ROW_NUMBER() OVER(ORDER BY '+@order+N') AS OutputRow FROM '+QUOTENAME(@table)+N') DELETE FROM r WHERE OutputRow>@n;';EXEC sys.sp_executesql @sql,N'@n int',@n=@limit;
  IF @mode='RAW' BEGIN SET @sql=N'SELECT * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N';';EXEC sys.sp_executesql @sql;END;
  IF @mode='TABLE' BEGIN SELECT @target=[TargetTable] FROM #SsisExecutionComparison_Map WHERE [ResultName]=@name;IF @target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @table,@target,@ThrowOnError=1;SET @target=NULL;END;
  FETCH NEXT FROM [comparisonOutputs] INTO @name,@table,@order;
 END;CLOSE [comparisonOutputs];DEALLOCATE [comparisonOutputs];
 IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisExecutionComparison_Binding',@ResultLabel=N'SsisExecutionComparison',@EmptyMessage=N'Keine fachlichen Ergebnisse';
 SELECT @StatusCodeOut=@status,@IsPartialOut=1,@ErrorNumberOut=@error,@ErrorMessageOut=CONVERT(nvarchar(2048),@reason);
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','comparisonOutputs')>=0 CLOSE [comparisonOutputs];IF CURSOR_STATUS('local','comparisonOutputs')>-3 DEALLOCATE [comparisonOutputs];
  SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;THROW;
 END CATCH;
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
END;
GO
