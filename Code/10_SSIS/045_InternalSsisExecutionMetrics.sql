USE [DeineDatenbank];
GO
/* Gemeinsamer nativer Consumer für Paarvergleich und Mehrlauf-Baselines.
   Jeder Capture wird genau einmal unabhängig durch den bestehenden Modell-/
   Scopeconsumer geprüft. Der Baustein besitzt sein Kennzahlziel und liefert das gemeinsame
   native Kennzahlenschema über einen internen JSON-OUTPUT-Vertrag. Schlüssel bezeichnen Modell und beobachtete
   Aufrufposition, niemals laufübergreifend native Statistik-IDs. Parser,
   Komponentenprofile und Lineage bleiben ausschließlich beim Toolbelt. */
CREATE OR ALTER PROCEDURE [monitor].[InternalSsisExecutionMetrics]
 @RunOrdinal int,@Models nvarchar(max),@Capture nvarchar(max),@HandoverId uniqueidentifier,
 @ExecutionId bigint,@Deadline datetime2(3),@LockTimeoutMs int,
 @AnalysisJson nvarchar(max) OUTPUT,@StatusCodeOut varchar(40) OUTPUT,@Use32BitRuntimeOut bit OUTPUT,@BoundOut bit OUTPUT,@MetricsJson nvarchar(max) OUTPUT,@ErrorNumberOut int OUTPUT,@ReasonCodeOut varchar(64) OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT @AnalysisJson=NULL,@StatusCodeOut=NULL,@Use32BitRuntimeOut=NULL,@BoundOut=0,@MetricsJson=N'[]',@ErrorNumberOut=NULL,@ReasonCodeOut=NULL;
 DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80);
 CREATE TABLE #InternalSsisExecutionMetrics_Metrics(
  [RunOrdinal] int NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [Value] decimal(38,0) NULL,[Quality] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NULL,[KeyJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[KeyHash] binary(32) NULL,[VolumeSignature] binary(32) NULL);

 BEGIN TRY
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
 IF COALESCE(ISJSON(@Models),0)<>1 OR COALESCE(ISJSON(@Capture),0)<>1 OR DATALENGTH(@Models)>16777216 OR DATALENGTH(@Capture)>16777216 THROW 57930,N'COMPARISON_TRANSPORT_INVALID',1;
 DECLARE @modelsLocal nvarchar(max)=@Models,@captureLocal nvarchar(max)=@Capture,@handover uniqueidentifier=@HandoverId,@execution bigint=@ExecutionId,
  @analysis nvarchar(max),@childStatus varchar(40),@remaining int;
 CREATE TABLE #InternalSsisExecutionMetrics_Input([RunOrdinal] int NOT NULL,[Models] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Capture] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionId] bigint NULL,[Analysis] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Use32BitRuntime] bit NULL,[PhaseSourceQualified] bit NOT NULL DEFAULT(0),[PathSourceQualified] bit NOT NULL DEFAULT(0));
 INSERT #InternalSsisExecutionMetrics_Input([RunOrdinal],[Models],[Capture],[ExecutionId]) VALUES(@RunOrdinal,@Models,@Capture,@ExecutionId);
 CREATE TABLE #InternalSsisExecutionMetrics_Stats([RunOrdinal] int NOT NULL,[SourceId] bigint NOT NULL,[DurationMs] bigint NULL,[ExecutionResult] int NULL,PRIMARY KEY([RunOrdinal],[SourceId]));
 CREATE TABLE #InternalSsisExecutionMetrics_Flows([RunOrdinal] int NOT NULL,[FlowStatisticsId] bigint NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPathUnique] bit NOT NULL,PRIMARY KEY([RunOrdinal],[FlowStatisticsId]));
   SET @remaining=CONVERT(int,DATEDIFF_BIG(millisecond,SYSUTCDATETIME(),@Deadline)/1000);IF @remaining<1 THROW 57930,N'COMPARISON_TIME_LIMIT',1;
   EXEC monitor.USP_SsisPackageModelAnalysis @IncludeExecutionScopes=1,@IncludePipelineCorrelation=1,@IncludePipelineDiagnostics=1,@ProjectModelsJson=@Models,@ScopeSnapshotJson=@Capture,@ScopeHandoverId=@handover,@ExecutionId=@execution,@MaxZeilen=0,@MaxDurationSeconds=@remaining,@LockTimeoutMs=@LockTimeoutMs,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@analysis OUTPUT,@StatusCodeOut=@childStatus OUTPUT;
   SET @AnalysisJson=@analysis;SET @StatusCodeOut=@childStatus;
   IF @childStatus<>'SCOPE_CAPTURE_BOUND' OR EXISTS(SELECT 1 FROM OPENJSON(@analysis,'$.pipelineCoverage') WHERE JSON_VALUE([value],'$.StatusCode')='PIPELINE_BINDING_UNPROVEN') BEGIN SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;RETURN;END;
   SET @BoundOut=1;
   UPDATE #InternalSsisExecutionMetrics_Input SET
    [PhaseSourceQualified]=CASE WHEN EXISTS(SELECT 1 FROM OPENJSON(@analysis,'$.pipelineDiagnosticCoverage') WHERE JSON_VALUE([value],'$.SourceName')='componentPhases' AND JSON_VALUE([value],'$.StatusCode') IN('AVAILABLE','AVAILABLE_EMPTY') AND JSON_VALUE([value],'$.UnassignedRowCount')='0' AND JSON_VALUE([value],'$.UnknownValueCount')='0') THEN 1 ELSE 0 END,
    [PathSourceQualified]=CASE WHEN EXISTS(SELECT 1 FROM OPENJSON(@analysis,'$.pipelineDiagnosticCoverage') WHERE JSON_VALUE([value],'$.SourceName')='pathTransfers' AND JSON_VALUE([value],'$.StatusCode') IN('AVAILABLE','AVAILABLE_EMPTY') AND JSON_VALUE([value],'$.UnassignedRowCount')='0' AND JSON_VALUE([value],'$.UnknownValueCount')='0') THEN 1 ELSE 0 END WHERE [RunOrdinal]=@RunOrdinal;
   -- Der alte Scopeconsumer ignoriert die additive Erweiterung; der Vergleich
   -- akzeptiert nur dieses exakte, bereits mitattestierte Kontextprofil.
   IF JSON_VALUE(@Capture,'$.comparisonContext.contract') COLLATE Latin1_General_100_BIN2=N'ssis-comparison-context' AND DATALENGTH(JSON_VALUE(@Capture,'$.comparisonContext.contract'))=46
    AND JSON_VALUE(@Capture,'$.comparisonContext.version') COLLATE Latin1_General_100_BIN2=N'1.0.0' AND DATALENGTH(JSON_VALUE(@Capture,'$.comparisonContext.version'))=10
    AND (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.comparisonContext'))=3
    AND EXISTS(SELECT 1 FROM OPENJSON(@Capture,'$.comparisonContext') WHERE [key] COLLATE Latin1_General_100_BIN2=N'use32BitRuntime' AND DATALENGTH([key])=30 AND [type]=3)
    UPDATE #InternalSsisExecutionMetrics_Input SET [Use32BitRuntime]=CASE WHEN JSON_VALUE(@Capture,'$.comparisonContext.use32BitRuntime')='true' THEN 1 ELSE 0 END WHERE [RunOrdinal]=@RunOrdinal;

 UPDATE #InternalSsisExecutionMetrics_Input SET [Analysis]=@analysis;
 SELECT @Use32BitRuntimeOut=[Use32BitRuntime] FROM #InternalSsisExecutionMetrics_Input;
  INSERT #InternalSsisExecutionMetrics_Stats SELECT @RunOrdinal,[o].[SourceId],[o].[DurationMs],[o].[ExecutionResult] FROM #InternalSsisExecutionMetrics_Input AS [s] CROSS APPLY OPENJSON([s].[Analysis],'$.scopeObservations') WITH([SourceKind] varchar(16),[SourceId] bigint,[DurationMs] bigint,[ExecutionResult] int) AS [o] WHERE [o].[SourceKind]='STATISTIC';
  INSERT #InternalSsisExecutionMetrics_Flows SELECT @RunOrdinal,[f].* FROM #InternalSsisExecutionMetrics_Input AS [s] CROSS APPLY OPENJSON([s].[Analysis],'$.pipelineInstances') WITH([FlowStatisticsId] bigint,[PackageKey] varchar(16),[FlowNodeId] varchar(128),[ExecutionPath] nvarchar(4000),[IsPathUnique] bit) AS [f];
  INSERT #InternalSsisExecutionMetrics_Metrics([RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId])
  SELECT @RunOrdinal,'EXECUTION',JSON_VALUE([s].[Models],'$.rootPackageKey'),'pkg1',NULL,N'\',NULL,NULL,'EXECUTION_STATUS','STATUS',TRY_CONVERT(int,JSON_VALUE([s].[Capture],'$.execution.executionStatus')),'KNOWN','execution',[s].[ExecutionId] FROM #InternalSsisExecutionMetrics_Input AS [s]
  UNION ALL SELECT [f].[RunOrdinal],'FLOW',[f].[PackageKey],[f].[FlowNodeId],[f].[FlowNodeId],[f].[ExecutionPath],NULL,NULL,[m].[MetricName],[m].[Unit],[m].[Value],CASE WHEN [f].[IsPathUnique]=0 THEN 'AMBIGUOUS' WHEN [m].[Value] IS NULL OR [m].[Value]<0 THEN 'UNKNOWN' ELSE 'KNOWN' END,'scopeObservations',[f].[FlowStatisticsId]
   FROM #InternalSsisExecutionMetrics_Flows AS [f] JOIN #InternalSsisExecutionMetrics_Stats AS [o] ON [o].[RunOrdinal]=[f].[RunOrdinal] AND [o].[SourceId]=[f].[FlowStatisticsId]
   CROSS APPLY(VALUES('FLOW_DURATION_MS','MS',CONVERT(decimal(38,0),[o].[DurationMs])),('FLOW_RESULT','STATUS',CONVERT(decimal(38,0),[o].[ExecutionResult]))) AS [m]([MetricName],[Unit],[Value]);
  INSERT #InternalSsisExecutionMetrics_Metrics([RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId])
  SELECT @RunOrdinal,'PHASE',[p].[PackageKey],[p].[ComponentNodeId],[p].[FlowNodeId],[f].[ExecutionPath],[p].[PhaseName],NULL,[m].[MetricName],[m].[Unit],[m].[Value],CASE WHEN [p].[UnknownIntervalCount]>0 OR [m].[Value] IS NULL THEN 'UNKNOWN' WHEN [s].[PhaseSourceQualified]=0 THEN 'LIMITED' ELSE 'KNOWN' END,'componentPhases',[p].[EvidencePhaseStatsId]
  FROM #InternalSsisExecutionMetrics_Input AS [s] CROSS APPLY OPENJSON([s].[Analysis],'$.componentPhaseSummary') WITH([FlowStatisticsId] bigint,[PackageKey] varchar(16),[FlowNodeId] varchar(128),[ComponentNodeId] varchar(128),[PhaseName] nvarchar(128),[UnknownIntervalCount] int,[ObservedIntervalSumMs] decimal(38,0),[LongestIntervalMs] bigint,[SpanMs] bigint,[ObservedIntervalCount] int,[EvidencePhaseStatsId] bigint) AS [p]
  JOIN #InternalSsisExecutionMetrics_Flows AS [f] ON [f].[RunOrdinal]=@RunOrdinal AND [f].[FlowStatisticsId]=[p].[FlowStatisticsId]
  CROSS APPLY(VALUES('PHASE_INTERVAL_SUM_MS','MS',[p].[ObservedIntervalSumMs]),('PHASE_LONGEST_MS','MS',CONVERT(decimal(38,0),[p].[LongestIntervalMs])),('PHASE_SPAN_MS','MS',CONVERT(decimal(38,0),[p].[SpanMs])),('PHASE_INTERVAL_COUNT','COUNT',CONVERT(decimal(38,0),[p].[ObservedIntervalCount]))) AS [m]([MetricName],[Unit],[Value]);
  INSERT #InternalSsisExecutionMetrics_Metrics([RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId])
  SELECT @RunOrdinal,'PATH',[p].[PackageKey],[p].[ModelEdgeId],[p].[FlowNodeId],[f].[ExecutionPath],NULL,[p].[PortRole],[m].[MetricName],[m].[Unit],[m].[Value],CASE WHEN [p].[UnknownRowCount]>0 OR [m].[Value] IS NULL THEN 'UNKNOWN' WHEN [s].[PathSourceQualified]=0 THEN 'LIMITED' ELSE 'KNOWN' END,'pathTransfers',[p].[FirstDataStatsId]
  FROM #InternalSsisExecutionMetrics_Input AS [s] CROSS APPLY OPENJSON([s].[Analysis],'$.pathTransferSummary') WITH([FlowStatisticsId] bigint,[PackageKey] varchar(16),[FlowNodeId] varchar(128),[ModelEdgeId] varchar(128),[PortRole] varchar(16),[UnknownRowCount] int,[ObservedRowsSent] decimal(38,0),[ObservedTransferCount] int,[FirstDataStatsId] bigint) AS [p]
  JOIN #InternalSsisExecutionMetrics_Flows AS [f] ON [f].[RunOrdinal]=@RunOrdinal AND [f].[FlowStatisticsId]=[p].[FlowStatisticsId]
  CROSS APPLY(VALUES('PATH_ROWS_SENT','ROWS',[p].[ObservedRowsSent]),('PATH_TRANSFER_COUNT','COUNT',CONVERT(decimal(38,0),[p].[ObservedTransferCount]))) AS [m]([MetricName],[Unit],[Value]);
  IF EXISTS(SELECT 1 FROM #InternalSsisExecutionMetrics_Metrics WHERE [RunOrdinal]=@RunOrdinal GROUP BY [RunOrdinal] HAVING COUNT(*)>200000) THROW 57930,N'COMPARISON_METRIC_LIMIT',1;
  IF SYSUTCDATETIME()>=@Deadline THROW 57930,N'COMPARISON_TIME_LIMIT',1;
  UPDATE [m] SET [KeyJson]=(SELECT [ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[MetricName] FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) FROM #InternalSsisExecutionMetrics_Metrics AS [m] WHERE [RunOrdinal]=@RunOrdinal;
  UPDATE #InternalSsisExecutionMetrics_Metrics SET [KeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[KeyJson])) WHERE [RunOrdinal]=@RunOrdinal;
  IF EXISTS(SELECT 1 FROM #InternalSsisExecutionMetrics_Metrics GROUP BY [KeyHash] HAVING MIN([KeyJson] COLLATE Latin1_General_100_BIN2)<>MAX([KeyJson] COLLATE Latin1_General_100_BIN2) OR MIN(DATALENGTH([KeyJson]))<>MAX(DATALENGTH([KeyJson]))) THROW 57930,N'COMPARISON_KEY_COLLISION',1;

 -- Canonical observed path set, including exact model keys and row counters.
 -- An absent, ambiguous, unknown or limited set has no volume signature.
 UPDATE [m] SET [VolumeSignature]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),(
  SELECT [p].[KeyJson],[p].[Value] FROM #InternalSsisExecutionMetrics_Metrics AS [p]
  WHERE [p].[RunOrdinal]=@RunOrdinal AND [p].[MetricName]='PATH_ROWS_SENT' AND [p].[PackageKey]=[m].[PackageKey] AND [p].[FlowNodeId]=[m].[FlowNodeId]
   AND [p].[ExecutionPath] COLLATE Latin1_General_100_BIN2=[m].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[ExecutionPath])=DATALENGTH([m].[ExecutionPath])
  ORDER BY [p].[KeyHash] FOR JSON PATH,INCLUDE_NULL_VALUES)))
 FROM #InternalSsisExecutionMetrics_Metrics AS [m] WHERE [m].[RunOrdinal]=@RunOrdinal AND [m].[Unit]='MS'
  AND EXISTS(SELECT 1 FROM #InternalSsisExecutionMetrics_Metrics AS [p] WHERE [p].[RunOrdinal]=@RunOrdinal AND [p].[MetricName]='PATH_ROWS_SENT' AND [p].[PackageKey]=[m].[PackageKey] AND [p].[FlowNodeId]=[m].[FlowNodeId] AND [p].[ExecutionPath] COLLATE Latin1_General_100_BIN2=[m].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[ExecutionPath])=DATALENGTH([m].[ExecutionPath]))
  AND NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionMetrics_Metrics AS [p] WHERE [p].[RunOrdinal]=@RunOrdinal AND [p].[MetricName]='PATH_ROWS_SENT' AND [p].[PackageKey]=[m].[PackageKey] AND [p].[FlowNodeId]=[m].[FlowNodeId] AND [p].[ExecutionPath] COLLATE Latin1_General_100_BIN2=[m].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[ExecutionPath])=DATALENGTH([m].[ExecutionPath]) GROUP BY [p].[KeyHash] HAVING COUNT(*)<>1 OR MIN([p].[Quality])<>'KNOWN');
 IF SYSUTCDATETIME()>=@Deadline THROW 57930,N'COMPARISON_TIME_LIMIT',1;
 SET @MetricsJson=COALESCE((SELECT [RunOrdinal],[ObjectKind],[PackageKey],[ModelNodeId],[FlowNodeId],[ExecutionPath],[PhaseName],[PortRole],[MetricName],[Unit],[Value],[Quality],[SourceName],[SourceId],[KeyJson],CONVERT(varchar(64),[KeyHash],2) AS [KeyHashHex],CONVERT(varchar(64),[VolumeSignature],2) AS [VolumeSignatureHex] FROM #InternalSsisExecutionMetrics_Metrics FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
 END TRY
 BEGIN CATCH
  SELECT @BoundOut=0,@MetricsJson=N'[]',@ErrorNumberOut=ERROR_NUMBER(),@ReasonCodeOut=CASE WHEN ERROR_NUMBER()=57930 THEN CONVERT(varchar(64),ERROR_MESSAGE()) ELSE 'COMPARISON_INPUT_REJECTED' END;
  SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
 END CATCH;
END;
GO
