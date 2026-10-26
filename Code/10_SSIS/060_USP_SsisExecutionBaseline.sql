USE [DeineDatenbank];
GO
/* monitor.USP_SsisExecutionBaseline; Version 1.0.0; Stand 2026-10-26.
   Explizite, unabhängig gebundene Kohorte mit höchstens 20 Basisläufen und
   einem anderen Kandidaten desselben exakten Exports. Jede Captureanalyse
   erfolgt einmal. Kennzahlen und Positionsschlüssel stammen aus dem gemeinsamen
   nativen Consumer; Parser und Lineage bleiben ausschließlich im Toolbelt.
   Median, Minimum, Maximum und Spannweite beschreiben beobachtete Werte;
   Arbeitslastgleichheit und statistische Signifikanz werden nicht behauptet. */
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisExecutionBaseline]
 @BaselineExecutionsJson nvarchar(max)=NULL,
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
  PRINT N'monitor.USP_SsisExecutionBaseline: 1 bis 20 explizite Basisläufe plus anderer Kandidat, gleicher exakter Export und dieselbe Quell-/Projektversion.';
  PRINT N'@BaselineExecutionsJson ist ein Array mit genau vier Strings je Eintrag: projectModelsJson, scopeSnapshotJson, scopeHandoverId, executionId. IDs sind positive kanonische Dezimalstrings.';
  PRINT N'Captures benötigen unabhängige lokale Scopeattestierung; -IncludeComparisonContext liefert den optionalen Laufzeitkontext. Kein CLR und keine direkten SSISDB-Reads.';
  PRINT N'Je Kennzahl zählen nur bekannte, eindeutige Werte bei gleichem Logging, gleicher Bitness und erfolgreichem Abschluss. Dauer benötigt außerdem das gleiche bekannte beobachtete Pfadzeilenset.';
  PRINT N'Mindestens fünf verwendbare Basiswerte sind für fachliche INFO-Hinweise nötig. Prozent bei Median null bleibt unbekannt. Optionale Dauergrenzen sind strikt; zwei gesetzte Grenzen gelten gemeinsam.';
  PRINT N'CONSOLE|RAW|TABLE|NONE; JSON über OUTPUT. Gruppen: baselineBinding|executionCohort|metricBaseline|baselineFindings|baselineCoverage.';
  PRINT N'64 MiB gesamte Eingaben; 16 MiB je Modell/Capture; 100000 Quellzeilen; 400000 Kennzahlen und höchstens 400000 Kennzahl-/Laufzellen; gemeinsames kooperatives Zeitbudget bis 60 Sekunden.';
  RETURN;
 END;
 IF XACT_STATE()=-1 THROW 50000,N'BASELINE_INVALID: Callertransaktion ist nicht schreibfähig.',1;
 DECLARE @savedX bit=CASE WHEN @@OPTIONS&16384=16384 THEN 1 ELSE 0 END;SET XACT_ABORT OFF;
 DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80),
  @mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS,
  @limit int=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END,
  @deadline datetime2(3)=DATEADD(second,COALESCE(@MaxDurationSeconds,30),SYSUTCDATETIME()),
  @status varchar(40)='BASELINE_BINDING_UNPROVEN',@reason varchar(64)=NULL,@error int=NULL,@bound bit=0,@baselineCount int=0,@sourceRows bigint=0;
 DECLARE @ConsoleResultRequested bit=CASE WHEN @mode='CONSOLE' THEN 1 ELSE 0 END;
 CREATE TABLE #SsisExecutionBaseline_Binding(
  [CandidateExecutionId] bigint NULL,[BaselineExecutionCount] int NOT NULL,[AnalyzedExecutionCount] int NOT NULL,
  [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ProjectLsn] bigint NULL,[ArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ModelExportSha256] binary(32) NULL,
  [MinimumFindingCount] int NOT NULL,[MetricCount] int NOT NULL,[WorkloadEquivalence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL);
 CREATE TABLE #SsisExecutionBaseline_Cohort(
  [RunOrdinal] int NOT NULL,[Role] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExecutionId] bigint NULL,
  [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionStatus] int NULL,[LoggingLevel] int NULL,[Use32BitRuntime] bit NULL,
  [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IncludedMetricCount] int NOT NULL,[ExcludedMetricCount] int NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionBaseline_Metrics(
  [ComparisonKeySha256] binary(32) NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ValidBaselineCount] int NOT NULL,[ExcludedBaselineCount] int NOT NULL,[MedianValue] decimal(38,1) NULL,[MinValue] decimal(38,0) NULL,[MaxValue] decimal(38,0) NULL,[SpreadValue] decimal(38,0) NULL,
  [CandidateValue] decimal(38,0) NULL,[DeltaValue] decimal(38,1) NULL,[DeltaPercent] decimal(38,6) NULL,
  [ComparisonStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CandidateSourceId] bigint NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionBaseline_Findings(
  [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleVersion] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [ComparisonKeySha256] binary(32) NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ValidBaselineCount] int NOT NULL,[ObservedDelta] decimal(38,1) NULL,
  [ThresholdMs] bigint NULL,[ThresholdPercent] decimal(9,4) NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionBaseline_Coverage(
  [RunOrdinal] int NULL,[ExecutionId] bigint NULL,[ComparisonKeySha256] binary(32) NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [SourceId] bigint NULL,[ObservedValue] decimal(38,0) NULL,[ObservedRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[UnknownValueCount] int NOT NULL,[OutputTruncated] bit NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #SsisExecutionBaseline_Map([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE #SsisExecutionBaseline_Runs([RunOrdinal] int NOT NULL PRIMARY KEY,[Models] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Capture] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HandoverId] uniqueidentifier NULL,[ExecutionId] bigint NULL,[Analysis] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Use32BitRuntime] bit NULL,[ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL DEFAULT('CONTEXT_UNPROVEN'));
 CREATE TABLE #SsisExecutionBaseline_MetricInput(
  [RunOrdinal] int NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [Value] decimal(38,0) NULL,[Quality] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NULL,[KeyJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[KeyHash] binary(32) NULL,[VolumeSignature] binary(32) NULL);

 CREATE INDEX IX_SsisExecutionMetrics_Key ON #SsisExecutionBaseline_MetricInput([KeyHash],[RunOrdinal]);
 CREATE TABLE #SsisExecutionBaseline_Values([RunOrdinal] int NOT NULL,[KeyHash] binary(32) NOT NULL,[MatchCount] int NOT NULL,[Value] decimal(38,0) NULL,[Quality] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NULL,[VolumeSignature] binary(32) NULL,PRIMARY KEY([KeyHash],[RunOrdinal]));
 CREATE TABLE #SsisExecutionBaseline_Cells([RunOrdinal] int NOT NULL,[KeyHash] binary(32) NOT NULL,[Value] decimal(38,0) NULL,[Included] bit NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,PRIMARY KEY([KeyHash],[RunOrdinal]));
 CREATE TABLE #SsisExecutionBaseline_Statistics([KeyHash] binary(32) NOT NULL PRIMARY KEY,[N] int NOT NULL,[MedianTwice] decimal(38,0) NULL,[MinValue] decimal(38,0) NULL,[MaxValue] decimal(38,0) NULL,[DeltaTwice] decimal(38,0) NULL);
 BEGIN TRY
  IF @mode<>'TABLE' AND @ResultTablesJson IS NOT NULL THROW 51011,N'ResultTablesJson ist ausschließlich für TABLE zulässig.',1;
  IF @mode='TABLE' EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'baselineBinding|executionCohort|metricBaseline|baselineFindings|baselineCoverage',@MappingTable=N'#SsisExecutionBaseline_Map',@ThrowOnError=1;
  IF @mode NOT IN('RAW','TABLE','CONSOLE','NONE') OR @limit<1 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60 OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000 OR @JsonErzeugen IS NULL
   OR COALESCE(@CandidateExecutionId,0)<1 OR @MinDurationDeltaMs<0 OR @MinDurationDeltaPercent<0 THROW 57940,N'INVALID_PARAMETER',1;
  SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
  IF COALESCE(ISJSON(@BaselineExecutionsJson),0)<>1 OR LEFT(LTRIM(@BaselineExecutionsJson),1)<>N'[' OR COALESCE(ISJSON(@CandidateProjectModelsJson),0)<>1 OR COALESCE(ISJSON(@CandidateScopeSnapshotJson),0)<>1
   OR CONVERT(bigint,DATALENGTH(@BaselineExecutionsJson))+DATALENGTH(@CandidateProjectModelsJson)+DATALENGTH(@CandidateScopeSnapshotJson)>67108864 THROW 57940,N'BASELINE_TRANSPORT_INVALID',1;
  SELECT @baselineCount=COUNT(*) FROM OPENJSON(@BaselineExecutionsJson);
  IF @baselineCount NOT BETWEEN 1 AND 20 THROW 57940,N'BASELINE_COHORT_LIMIT',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@BaselineExecutionsJson) AS [r] WHERE [type]<>5 OR (SELECT COUNT(*) FROM OPENJSON([r].[value]))<>4
    OR EXISTS(SELECT 1 FROM OPENJSON([r].[value]) WHERE [type]<>1 OR [key] COLLATE Latin1_General_100_BIN2 NOT IN(N'projectModelsJson',N'scopeSnapshotJson',N'scopeHandoverId',N'executionId') OR DATALENGTH([key])<>2*LEN([key]))
    OR (SELECT COUNT(DISTINCT [key] COLLATE Latin1_General_100_BIN2) FROM OPENJSON([r].[value]))<>4) THROW 57940,N'BASELINE_ENTRY_INVALID',1;
  INSERT #SsisExecutionBaseline_Runs([RunOrdinal],[Models],[Capture],[HandoverId],[ExecutionId])
  SELECT CONVERT(int,[r].[key])+1,[p].[models],[p].[capture],TRY_CONVERT(uniqueidentifier,[p].[handover]),TRY_CONVERT(bigint,[p].[execution]) FROM OPENJSON(@BaselineExecutionsJson) AS [r]
  CROSS APPLY OPENJSON([r].[value]) WITH([models] nvarchar(max) '$.projectModelsJson',[capture] nvarchar(max) '$.scopeSnapshotJson',[handover] nvarchar(max) '$.scopeHandoverId',[execution] nvarchar(max) '$.executionId') AS [p]
  WHERE [p].[execution]=CONVERT(nvarchar(20),TRY_CONVERT(bigint,[p].[execution])) COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[execution])=DATALENGTH(CONVERT(nvarchar(20),TRY_CONVERT(bigint,[p].[execution])));
  IF (SELECT COUNT(*) FROM #SsisExecutionBaseline_Runs)<>@baselineCount THROW 57940,N'BASELINE_ENTRY_INVALID',1;
  INSERT #SsisExecutionBaseline_Runs([RunOrdinal],[Models],[Capture],[HandoverId],[ExecutionId]) VALUES(0,@CandidateProjectModelsJson,@CandidateScopeSnapshotJson,@CandidateScopeHandoverId,@CandidateExecutionId);
  IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Runs WHERE [HandoverId] IS NULL OR COALESCE([ExecutionId],0)<1) THROW 57940,N'BASELINE_ENTRY_INVALID',1;
  IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Runs GROUP BY [ExecutionId] HAVING COUNT(*)>1) THROW 57940,N'BASELINE_DUPLICATE_EXECUTION',1;
  IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Runs WHERE COALESCE(ISJSON([Models]),0)<>1 OR COALESCE(ISJSON([Capture]),0)<>1 OR DATALENGTH([Models])>16777216 OR DATALENGTH([Capture])>16777216) THROW 57940,N'BASELINE_TRANSPORT_INVALID',1;
  SELECT @sourceRows=SUM(CONVERT(bigint,[n].[observations])+[n].[events]+[n].[phases]+[n].[paths]) FROM #SsisExecutionBaseline_Runs CROSS APPLY(SELECT (SELECT COUNT(*) FROM OPENJSON([Capture],'$.observations')) [observations],(SELECT COUNT(*) FROM OPENJSON([Capture],'$.events')) [events],(SELECT COUNT(*) FROM OPENJSON([Capture],'$.componentPhases')) [phases],(SELECT COUNT(*) FROM OPENJSON([Capture],'$.pathTransfers')) [paths]) AS [n];
  IF @sourceRows>100000 THROW 57940,N'BASELINE_SOURCE_LIMIT',1;
  DECLARE @run int,@models nvarchar(max),@capture nvarchar(max),@handover uniqueidentifier,@execution bigint,@analysis nvarchar(max),@childStatus varchar(40),@bitness bit,@captureBound bit,@metricsJson nvarchar(max),@metricError int,@metricReason varchar(64);
  DECLARE [baselineRuns] CURSOR LOCAL FAST_FORWARD FOR SELECT [RunOrdinal],[Models],[Capture],[HandoverId],[ExecutionId] FROM #SsisExecutionBaseline_Runs ORDER BY [RunOrdinal];
  OPEN [baselineRuns];FETCH NEXT FROM [baselineRuns] INTO @run,@models,@capture,@handover,@execution;
  WHILE @@FETCH_STATUS=0
  BEGIN
   EXEC [monitor].[InternalSsisExecutionMetrics] @run,@models,@capture,@handover,@execution,@deadline,@LockTimeoutMs,@analysis OUTPUT,@childStatus OUTPUT,@bitness OUTPUT,@captureBound OUTPUT,@metricsJson OUTPUT,@metricError OUTPUT,@metricReason OUTPUT;
   UPDATE #SsisExecutionBaseline_Runs SET [Analysis]=@analysis,[BindingStatus]=@childStatus,[Use32BitRuntime]=@bitness WHERE [RunOrdinal]=@run;
   IF @metricError IS NOT NULL THROW 57930,@metricReason,1;
   IF @captureBound<>1 THROW 57930,N'COMPARISON_SIDE_BINDING_UNPROVEN',1;
   INSERT #SsisExecutionBaseline_MetricInput SELECT [RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId],[KeyJson],CONVERT(binary(32),[KeyHashHex],2),CONVERT(binary(32),[VolumeSignatureHex],2) FROM OPENJSON(@metricsJson) WITH([RunOrdinal] int,[ObjectKind] varchar(16),[PackageKey] varchar(16),[ModelNodeId] varchar(128),[FlowNodeId] varchar(128),[ExecutionPath] nvarchar(4000),[PhaseName] nvarchar(128),[PortRole] varchar(16),[MetricName] varchar(32),[Unit] varchar(16),[Value] decimal(38,0),[Quality] varchar(32),[SourceName] varchar(32),[SourceId] bigint,[KeyJson] nvarchar(max),[KeyHashHex] varchar(64),[VolumeSignatureHex] varchar(64));
   IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_MetricInput GROUP BY [KeyHash] HAVING MIN([KeyJson] COLLATE Latin1_General_100_BIN2)<>MAX([KeyJson] COLLATE Latin1_General_100_BIN2) OR MIN(DATALENGTH([KeyJson]))<>MAX(DATALENGTH([KeyJson]))) THROW 57930,N'COMPARISON_KEY_COLLISION',1;
   IF (SELECT COUNT(*) FROM #SsisExecutionBaseline_MetricInput)>400000 THROW 57940,N'BASELINE_METRIC_LIMIT',1;
   FETCH NEXT FROM [baselineRuns] INTO @run,@models,@capture,@handover,@execution;
  END;CLOSE [baselineRuns];DEALLOCATE [baselineRuns];
  IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Runs WHERE HASHBYTES('SHA2_256',CONVERT(varbinary(max),[Models]))<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CandidateProjectModelsJson))) THROW 57940,N'BASELINE_MODEL_EXPORT_DIFFERENT',1;
  IF EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Runs AS [r] CROSS JOIN (VALUES('projectId'),('projectLsn'),('catalogDatabaseGuid'),('sourceBindingSha256'),('packageFileName')) AS [f]([name])
   CROSS APPLY(SELECT JSON_VALUE([r].[Capture],'$.execution.'+[f].[name]) [b],JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.'+[f].[name]) [c]) AS [v]
   WHERE [v].[b] IS NULL OR [v].[c] IS NULL OR [v].[b] COLLATE Latin1_General_100_BIN2<>[v].[c] COLLATE Latin1_General_100_BIN2 OR DATALENGTH([v].[b])<>DATALENGTH([v].[c])
    OR JSON_VALUE([r].[Capture],'$.archiveSha256') COLLATE Latin1_General_100_BIN2<>JSON_VALUE(@CandidateScopeSnapshotJson,'$.archiveSha256') COLLATE Latin1_General_100_BIN2) THROW 57940,N'BASELINE_SOURCE_VERSION_DIFFERENT',1;
  SELECT @bound=1,@status='BASELINE_CAPTURE_BOUND';
  UPDATE [r] SET [ContextStatus]=CASE WHEN [r].[Use32BitRuntime] IS NULL OR [c].[Use32BitRuntime] IS NULL THEN 'RUNTIME_CONTEXT_UNPROVEN'
   WHEN [r].[Use32BitRuntime]<>[c].[Use32BitRuntime] THEN 'RUNTIME_BITNESS_DIFFERENT'
   WHEN COALESCE(TRY_CONVERT(int,JSON_VALUE([r].[Capture],'$.execution.loggingLevel')),0) NOT IN(1,2,3) OR COALESCE(TRY_CONVERT(int,JSON_VALUE([c].[Capture],'$.execution.loggingLevel')),0) NOT IN(1,2,3) THEN 'LOGGING_CONTEXT_UNPROVEN'
   WHEN JSON_VALUE([r].[Capture],'$.execution.loggingLevel')<>JSON_VALUE([c].[Capture],'$.execution.loggingLevel') THEN 'LOGGING_LEVEL_DIFFERENT'
   WHEN COALESCE(TRY_CONVERT(int,JSON_VALUE([r].[Capture],'$.execution.executionStatus')),0)<>7 OR COALESCE(TRY_CONVERT(int,JSON_VALUE([c].[Capture],'$.execution.executionStatus')),0)<>7 THEN 'NOT_BOTH_SUCCEEDED'
   ELSE 'MATCHED_OBSERVATION_CONTEXT' END FROM #SsisExecutionBaseline_Runs AS [r] CROSS JOIN #SsisExecutionBaseline_Runs AS [c] WHERE [c].[RunOrdinal]=0;
  INSERT #SsisExecutionBaseline_Values SELECT [RunOrdinal],[KeyHash],COUNT(*),CASE WHEN COUNT(*)=1 THEN MAX([Value]) END,CASE WHEN COUNT(*)>1 THEN 'AMBIGUOUS' ELSE MAX([Quality]) END,CASE WHEN COUNT(*)=1 THEN MAX([SourceId]) END,CASE WHEN COUNT(*)=1 THEN MAX([VolumeSignature]) END FROM #SsisExecutionBaseline_MetricInput WHERE [Unit]<>'STATUS' GROUP BY [RunOrdinal],[KeyHash];
  INSERT #SsisExecutionBaseline_Metrics
  SELECT [KeyHash],MAX([ObjectKind]),MAX([PackageKey]),MAX([ModelNodeId]),MAX([FlowNodeId]),MAX([ExecutionPath]),MAX([PhaseName]),MAX([PortRole]),MAX([MetricName]),MAX([Unit]),0,@baselineCount,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'EVIDENCE_LIMITED','NOT_EVALUATED',NULL,1 FROM #SsisExecutionBaseline_MetricInput WHERE [Unit]<>'STATUS' GROUP BY [KeyHash];
  IF CONVERT(bigint,(SELECT COUNT(*) FROM #SsisExecutionBaseline_Metrics))*(@baselineCount+1)>400000 THROW 57940,N'BASELINE_CELL_LIMIT',1;
  INSERT #SsisExecutionBaseline_Cells
  SELECT [r].[RunOrdinal],[k].[ComparisonKeySha256],[v].[Value],CASE WHEN [q].[ReasonCode]='KNOWN_OBSERVATION' THEN 1 ELSE 0 END,[q].[ReasonCode]
  FROM #SsisExecutionBaseline_Runs AS [r] CROSS JOIN #SsisExecutionBaseline_Metrics AS [k]
  LEFT JOIN #SsisExecutionBaseline_Values AS [v] ON [v].[RunOrdinal]=[r].[RunOrdinal] AND [v].[KeyHash]=[k].[ComparisonKeySha256]
  LEFT JOIN #SsisExecutionBaseline_Values AS [c] ON [c].[RunOrdinal]=0 AND [c].[KeyHash]=[k].[ComparisonKeySha256]
  CROSS APPLY(SELECT CASE WHEN [v].[KeyHash] IS NULL THEN 'METRIC_NOT_OBSERVED' WHEN [v].[MatchCount]<>1 OR [v].[Quality]='AMBIGUOUS' THEN 'INVOCATION_PAIRING_UNPROVEN'
   WHEN [v].[Quality]='UNKNOWN' OR [v].[Value] IS NULL THEN 'UNKNOWN_METRIC_VALUE' WHEN [v].[Quality]<>'KNOWN' THEN 'SOURCE_COVERAGE_LIMITED'
   WHEN [r].[ContextStatus]<>'MATCHED_OBSERVATION_CONTEXT' THEN [r].[ContextStatus]
   WHEN [k].[Unit]='MS' AND ([c].[MatchCount] IS NULL OR [c].[MatchCount]<>1 OR [c].[Quality]<>'KNOWN' OR [v].[VolumeSignature] IS NULL OR [c].[VolumeSignature] IS NULL OR [v].[VolumeSignature]<>[c].[VolumeSignature]) THEN 'OBSERVED_PATH_VOLUME_DIFFERENT_OR_UNKNOWN'
   ELSE 'KNOWN_OBSERVATION' END AS [ReasonCode]) AS [q];
  ;WITH [ordered] AS(SELECT [KeyHash],[Value],ROW_NUMBER() OVER(PARTITION BY [KeyHash] ORDER BY [Value],[RunOrdinal]) [rn],COUNT(*) OVER(PARTITION BY [KeyHash]) [n] FROM #SsisExecutionBaseline_Cells WHERE [RunOrdinal]>0 AND [Included]=1)
  INSERT #SsisExecutionBaseline_Statistics([KeyHash],[N],[MedianTwice],[MinValue],[MaxValue])
  SELECT [KeyHash],MAX([n]),SUM(CASE WHEN [rn]=([n]+1)/2 THEN [Value] ELSE 0 END)+SUM(CASE WHEN [rn]=([n]+2)/2 THEN [Value] ELSE 0 END),MIN([Value]),MAX([Value]) FROM [ordered] GROUP BY [KeyHash];
  UPDATE [s] SET [DeltaTwice]=[c].[Value]*2-[s].[MedianTwice] FROM #SsisExecutionBaseline_Statistics AS [s] JOIN #SsisExecutionBaseline_Cells AS [c] ON [c].[KeyHash]=[s].[KeyHash] AND [c].[RunOrdinal]=0 AND [c].[Included]=1;
  UPDATE [m] SET [ValidBaselineCount]=COALESCE([s].[N],0),[ExcludedBaselineCount]=@baselineCount-COALESCE([s].[N],0),[MedianValue]=CONVERT(decimal(30,1),[s].[MedianTwice])/2,[MinValue]=[s].[MinValue],[MaxValue]=[s].[MaxValue],[SpreadValue]=[s].[MaxValue]-[s].[MinValue],
   [CandidateValue]=[c].[Value],[CandidateSourceId]=[v].[SourceId],[DeltaValue]=CONVERT(decimal(30,1),[s].[DeltaTwice])/2,
   [ComparisonStatus]=CASE WHEN [c].[Included]=0 THEN 'CANDIDATE_EVIDENCE_LIMITED' WHEN COALESCE([s].[N],0)=0 THEN 'NO_BASELINE_OBSERVATIONS' WHEN [s].[N]<5 THEN 'INSUFFICIENT_BASELINE_COUNT' ELSE 'COMPARABLE_OBSERVATION' END,
   [ReasonCode]=CASE WHEN [c].[Included]=0 THEN [c].[ReasonCode] WHEN COALESCE([s].[N],0)<5 THEN 'FEWER_THAN_FIVE_USABLE_BASELINES' ELSE 'OBSERVED_VALUES_ONLY' END
  FROM #SsisExecutionBaseline_Metrics AS [m] JOIN #SsisExecutionBaseline_Cells AS [c] ON [c].[KeyHash]=[m].[ComparisonKeySha256] AND [c].[RunOrdinal]=0
  LEFT JOIN #SsisExecutionBaseline_Statistics AS [s] ON [s].[KeyHash]=[m].[ComparisonKeySha256]
  LEFT JOIN #SsisExecutionBaseline_Values AS [v] ON [v].[KeyHash]=[m].[ComparisonKeySha256] AND [v].[RunOrdinal]=0;
  -- Twice-median integer arithmetic preserves exact half-units and avoids float.
  UPDATE [m] SET [DeltaPercent]=TRY_CONVERT(decimal(38,6),CONVERT(decimal(38,0),SIGN([s].[DeltaTwice])*(([n].[v]-[r].[v])/[s].[MedianTwice]+CASE WHEN [r].[v]*2>=[s].[MedianTwice] THEN 1 ELSE 0 END))/CONVERT(decimal(7,0),1000000))
  FROM #SsisExecutionBaseline_Metrics AS [m] JOIN #SsisExecutionBaseline_Statistics AS [s] ON [s].[KeyHash]=[m].[ComparisonKeySha256]
  CROSS APPLY(SELECT ABS([s].[DeltaTwice])*CONVERT(decimal(9,0),100000000) [v]) AS [n] CROSS APPLY(SELECT [n].[v]%NULLIF([s].[MedianTwice],0) [v]) AS [r] WHERE [s].[MedianTwice]>0 AND [s].[DeltaTwice] IS NOT NULL;
  INSERT #SsisExecutionBaseline_Findings
  SELECT CASE WHEN [m].[Unit]='ROWS' THEN 'SSIS_BASELINE_OBSERVED_ROWS_CHANGED' ELSE 'SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED' END,'1.0.0','INFO',[m].[ComparisonKeySha256],[m].[MetricName],[m].[ValidBaselineCount],[m].[DeltaValue],@MinDurationDeltaMs,@MinDurationDeltaPercent,
   CASE WHEN [m].[Unit]='ROWS' THEN 'OBSERVED_ROWS_DIFFER_FROM_MEDIAN' ELSE 'HIGHER_OBSERVED_DURATION_WORKLOAD_UNPROVEN' END,1
  FROM #SsisExecutionBaseline_Metrics AS [m] JOIN #SsisExecutionBaseline_Statistics AS [s] ON [s].[KeyHash]=[m].[ComparisonKeySha256] WHERE [m].[ComparisonStatus]='COMPARABLE_OBSERVATION'
   AND ([m].[Unit]='ROWS' AND [s].[DeltaTwice]<>0 OR [m].[Unit]='MS' AND [s].[DeltaTwice]>0 AND (@MinDurationDeltaMs IS NOT NULL OR @MinDurationDeltaPercent IS NOT NULL)
    AND (@MinDurationDeltaMs IS NULL OR [s].[DeltaTwice]>CONVERT(decimal(38,0),@MinDurationDeltaMs)*2)
    AND (@MinDurationDeltaPercent IS NULL OR [s].[MedianTwice]>0 AND [s].[DeltaTwice]*CONVERT(decimal(7,0),1000000)>[s].[MedianTwice]*CONVERT(decimal(9,0),@MinDurationDeltaPercent*10000)));
  IF SYSUTCDATETIME()>=@deadline THROW 57940,N'BASELINE_TIME_LIMIT',1;
 END TRY
 BEGIN CATCH
  SELECT @error=COALESCE(@metricError,ERROR_NUMBER()),@reason=CASE WHEN ERROR_NUMBER() IN(57930,57940) THEN CONVERT(varchar(64),ERROR_MESSAGE()) ELSE 'BASELINE_INPUT_REJECTED' END;
  IF @error=51011 BEGIN SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;THROW;END;
  IF CURSOR_STATUS('local','baselineRuns')>=0 CLOSE [baselineRuns];IF CURSOR_STATUS('local','baselineRuns')>-3 DEALLOCATE [baselineRuns];
  SELECT @bound=0,@status=CASE WHEN @reason='INVALID_PARAMETER' THEN 'INVALID_PARAMETER' ELSE 'BASELINE_BINDING_UNPROVEN' END;
  DELETE #SsisExecutionBaseline_Metrics;DELETE #SsisExecutionBaseline_Findings;DELETE #SsisExecutionBaseline_Cells;
 END CATCH;
 BEGIN TRY
  INSERT #SsisExecutionBaseline_Binding SELECT @CandidateExecutionId,@baselineCount,(SELECT COUNT(*) FROM #SsisExecutionBaseline_Runs WHERE [Analysis] IS NOT NULL),@status,@reason,
   CASE WHEN @bound=1 THEN TRY_CONVERT(bigint,JSON_VALUE(@CandidateScopeSnapshotJson,'$.execution.projectLsn')) END,CASE WHEN @bound=1 THEN JSON_VALUE(@CandidateScopeSnapshotJson,'$.archiveSha256') END,
   CASE WHEN @bound=1 THEN HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CandidateProjectModelsJson)) END,5,(SELECT COUNT(*) FROM #SsisExecutionBaseline_Metrics),'UNPROVEN',1,@error;
  INSERT #SsisExecutionBaseline_Cohort SELECT [r].[RunOrdinal],CASE WHEN [r].[RunOrdinal]=0 THEN 'CANDIDATE' ELSE 'BASELINE' END,[r].[ExecutionId],[r].[BindingStatus],
   TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([r].[Capture])=1 THEN [r].[Capture] ELSE N'{}' END,'$.execution.executionStatus')),TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([r].[Capture])=1 THEN [r].[Capture] ELSE N'{}' END,'$.execution.loggingLevel')),[r].[Use32BitRuntime],[r].[ContextStatus],
   (SELECT COUNT(*) FROM #SsisExecutionBaseline_Cells AS [c] WHERE [c].[RunOrdinal]=[r].[RunOrdinal] AND [c].[Included]=1),(SELECT COUNT(*) FROM #SsisExecutionBaseline_Cells AS [c] WHERE [c].[RunOrdinal]=[r].[RunOrdinal] AND [c].[Included]=0),1 FROM #SsisExecutionBaseline_Runs AS [r];
  INSERT #SsisExecutionBaseline_Coverage SELECT [c].[RunOrdinal],[r].[ExecutionId],[c].[KeyHash],'metrics',CASE WHEN [c].[Included]=1 THEN 'INCLUDED' ELSE 'EXCLUDED' END,[c].[ReasonCode],[v].[SourceId],[v].[Value],CASE WHEN [v].[MatchCount] IS NULL THEN 0 ELSE [v].[MatchCount] END,[c].[Included],CASE WHEN [c].[ReasonCode]='UNKNOWN_METRIC_VALUE' THEN 1 ELSE 0 END,0,1 FROM #SsisExecutionBaseline_Cells AS [c] JOIN #SsisExecutionBaseline_Runs AS [r] ON [r].[RunOrdinal]=[c].[RunOrdinal] LEFT JOIN #SsisExecutionBaseline_Values AS [v] ON [v].[RunOrdinal]=[c].[RunOrdinal] AND [v].[KeyHash]=[c].[KeyHash];
  INSERT #SsisExecutionBaseline_Coverage SELECT [r].[RunOrdinal],[r].[ExecutionId],NULL,[p].[SourceName],[p].[StatusCode],[p].[ReasonCode],NULL,NULL,[p].[ObservedRowCount],[p].[MappedRowCount],[p].[UnknownValueCount],0,1 FROM #SsisExecutionBaseline_Runs AS [r] CROSS APPLY OPENJSON([r].[Analysis],'$.pipelineDiagnosticCoverage') WITH([SourceName] varchar(32),[StatusCode] varchar(40),[ReasonCode] varchar(64),[ObservedRowCount] int,[MappedRowCount] int,[UnknownValueCount] int) AS [p];
  INSERT #SsisExecutionBaseline_Coverage VALUES(NULL,NULL,NULL,'cohort',@status,COALESCE(@reason,'EXPLICIT_COHORT_OBSERVATIONS_ONLY'),NULL,NULL,(SELECT COUNT(*) FROM #SsisExecutionBaseline_MetricInput),(SELECT COUNT(*) FROM #SsisExecutionBaseline_Metrics),0,0,1);
  IF @bound=0 OR EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Metrics WHERE [ComparisonStatus]<>'COMPARABLE_OBSERVATION' OR [ExcludedBaselineCount]>0) OR EXISTS(SELECT 1 FROM #SsisExecutionBaseline_Coverage WHERE [StatusCode] NOT IN('INCLUDED','AVAILABLE','AVAILABLE_EMPTY','BASELINE_CAPTURE_BOUND'))
   INSERT #SsisExecutionBaseline_Findings VALUES('SSIS_BASELINE_EVIDENCE_LIMITED','1.0.0','INFO',NULL,NULL,0,NULL,NULL,NULL,COALESCE(@reason,'PARTIAL_COHORT_OR_METRIC_COVERAGE'),1);
  UPDATE #SsisExecutionBaseline_Coverage SET [OutputTruncated]=CASE WHEN (SELECT COUNT(*) FROM #SsisExecutionBaseline_Cohort)>@limit OR (SELECT COUNT(*) FROM #SsisExecutionBaseline_Metrics)>@limit OR (SELECT COUNT(*) FROM #SsisExecutionBaseline_Findings)>@limit OR (SELECT COUNT(*) FROM #SsisExecutionBaseline_Coverage)>@limit THEN 1 ELSE 0 END;
  DECLARE @spec nvarchar(max)=N'[{"name":"baselineBinding","table":"#SsisExecutionBaseline_Binding","order":"CandidateExecutionId"},{"name":"executionCohort","table":"#SsisExecutionBaseline_Cohort","order":"RunOrdinal"},{"name":"metricBaseline","table":"#SsisExecutionBaseline_Metrics","order":"ComparisonKeySha256"},{"name":"baselineFindings","table":"#SsisExecutionBaseline_Findings","order":"RuleId,ComparisonKeySha256"},{"name":"baselineCoverage","table":"#SsisExecutionBaseline_Coverage","order":"RunOrdinal,SourceName,ComparisonKeySha256"}]';
  IF @JsonErzeugen=1 SET @Json=N'{"meta":{"schemaVersion":1,"baselineSchemaVersion":1,"isPartial":true}}';
  DECLARE @name sysname,@table sysname,@order nvarchar(128),@target sysname,@array nvarchar(max),@sql nvarchar(max);
  DECLARE [baselineOutputs] CURSOR LOCAL FAST_FORWARD FOR SELECT [name],[table],[order] FROM OPENJSON(@spec) WITH([name] sysname,[table] sysname,[order] nvarchar(128));OPEN [baselineOutputs];FETCH NEXT FROM [baselineOutputs] INTO @name,@table,@order;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @sql=N'SELECT @a=COALESCE((SELECT TOP(@n) * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N' FOR JSON PATH,INCLUDE_NULL_VALUES),N''[]'');';EXEC sys.sp_executesql @sql,N'@n int,@a nvarchar(max) OUTPUT',@n=@limit,@a=@array OUTPUT;
   IF @JsonErzeugen=1 SET @Json=JSON_MODIFY(@Json,'$.'+@name,JSON_QUERY(@array));
   SET @sql=N';WITH r AS(SELECT *,ROW_NUMBER() OVER(ORDER BY '+@order+N') AS OutputRow FROM '+QUOTENAME(@table)+N') DELETE FROM r WHERE OutputRow>@n;';EXEC sys.sp_executesql @sql,N'@n int',@n=@limit;
   IF @mode='RAW' BEGIN SET @sql=N'SELECT * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N';';EXEC sys.sp_executesql @sql;END;
   IF @mode='TABLE' BEGIN SELECT @target=[TargetTable] FROM #SsisExecutionBaseline_Map WHERE [ResultName]=@name;IF @target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @table,@target,@ThrowOnError=1;SET @target=NULL;END;
   FETCH NEXT FROM [baselineOutputs] INTO @name,@table,@order;
  END;CLOSE [baselineOutputs];DEALLOCATE [baselineOutputs];
  IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisExecutionBaseline_Binding',@ResultLabel=N'SsisExecutionBaseline',@EmptyMessage=N'Keine fachlichen Ergebnisse';
  SELECT @StatusCodeOut=@status,@IsPartialOut=1,@ErrorNumberOut=@error,@ErrorMessageOut=CONVERT(nvarchar(2048),@reason);
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','baselineOutputs')>=0 CLOSE [baselineOutputs];IF CURSOR_STATUS('local','baselineOutputs')>-3 DEALLOCATE [baselineOutputs];
  SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;THROW;
 END CATCH;
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;IF @savedX=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
END;
GO
