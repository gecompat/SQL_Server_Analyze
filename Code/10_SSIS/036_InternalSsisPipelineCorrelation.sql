USE [DeineDatenbank];
GO
/* Interner Consumer für optionale Pipelinebelege. Der aufrufende Scopeconsumer
   hat Einzelmodelle, JSON-Schlüssel und lokale Capturebindung bereits geprüft.
   Dieser Baustein verwendet ausschließlich diese materialisierten Modelle und
   Toolbelt-Referenzen; kein DTSX-Zugriff, keine Typklassifikation oder Lineage.
   Phasennamen bezeichnen Quellenwerte, Zeitintervalle keine CPU-Zeit.
   Die vier Ergebnisziele gehören dem aufrufenden Scopeconsumer. */
CREATE OR ALTER PROCEDURE [monitor].[InternalSsisPipelineCorrelation]
 @Models nvarchar(max),@Capture nvarchar(max),@Bound bit,@Deadline datetime2(3),@Limit int
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80),@reason nvarchar(256)=NULL,@error int=NULL,@valid bit=0;
 CREATE TABLE #InternalSsisPipelineCorrelation_Flows([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Supported] bit NOT NULL,PRIMARY KEY([PackageKey],[NodeId]));
 CREATE TABLE #InternalSsisPipelineCorrelation_Components([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Name] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Supported] bit NOT NULL,PRIMARY KEY([PackageKey],[NodeId]));
 CREATE TABLE #InternalSsisPipelineCorrelation_Paths([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IdentificationString] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Name] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[DestinationName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Supported] bit NOT NULL,PRIMARY KEY([PackageKey],[EdgeId]));
 CREATE TABLE #InternalSsisPipelineCorrelation_Sources([SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL);
 BEGIN TRY
  IF @Bound<>1 OR @Bound IS NULL THROW 57910,N'SCOPE_BINDING_UNPROVEN',1;
  IF SYSUTCDATETIME()>=@Deadline THROW 57910,N'PIPELINE_TIME_LIMIT',1;
  IF COALESCE(LEFT(LTRIM(JSON_QUERY(@Capture,'$.componentPhases')),1),N'')<>N'[' OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Capture,'$.pathTransfers')),1),N'')<>N'['
   OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Capture,'$.pipelineSources')),1),N'')<>N'['
   OR (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.componentPhases'))+(SELECT COUNT(*) FROM OPENJSON(@Capture,'$.pathTransfers'))+(SELECT COUNT(*) FROM OPENJSON(@Capture,'$.observations'))+(SELECT COUNT(*) FROM OPENJSON(@Capture,'$.events'))>50000 THROW 57910,N'PIPELINE_SOURCE_LIMIT',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.pipelineSources'))<>2 OR EXISTS(
   SELECT 1 FROM OPENJSON(@Capture,'$.pipelineSources') WITH([source] nvarchar(max) '$.source',[status] nvarchar(max) '$.status',[error] nvarchar(max) '$.errorNumber') AS [s]
   WHERE COALESCE([source],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'componentPhases',N'pathTransfers') OR DATALENGTH([source])<>2*LEN([source])
    OR COALESCE([status],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'AVAILABLE',N'AVAILABLE_EMPTY',N'UNAVAILABLE',N'DENIED_PERMISSION') OR DATALENGTH([status])<>2*LEN([status])
    OR [status] IN(N'AVAILABLE',N'AVAILABLE_EMPTY') AND [error] IS NOT NULL OR [status] IN(N'UNAVAILABLE',N'DENIED_PERMISSION') AND COALESCE(TRY_CONVERT(int,[error]),0)<1) THROW 57910,N'PIPELINE_SOURCE_STATUS_INVALID',1;
  INSERT #InternalSsisPipelineCorrelation_Sources SELECT [source],[status],TRY_CONVERT(int,[error]) FROM OPENJSON(@Capture,'$.pipelineSources') WITH([source] varchar(32) '$.source',[status] varchar(40) '$.status',[error] nvarchar(40) '$.errorNumber');
  IF EXISTS(SELECT 1 FROM #InternalSsisPipelineCorrelation_Sources AS [s] WHERE [s].[StatusCode]<>'AVAILABLE' AND
   CASE WHEN [s].[SourceName]='componentPhases' THEN (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.componentPhases')) ELSE (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.pathTransfers')) END>0) THROW 57910,N'PIPELINE_SOURCE_STATUS_INVALID',1;
  DECLARE @package nvarchar(max),@key varchar(16),@identities nvarchar(max),@flows nvarchar(max),@flow nvarchar(max),@flowId varchar(128),@edges nvarchar(max);
  DECLARE [pipelinePackages] CURSOR LOCAL FAST_FORWARD FOR SELECT [value] FROM OPENJSON(@Models,'$.packages');
  OPEN [pipelinePackages];FETCH NEXT FROM [pipelinePackages] INTO @package;
  WHILE @@FETCH_STATUS=0
  BEGIN
   IF SYSUTCDATETIME()>=@Deadline THROW 57910,N'PIPELINE_TIME_LIMIT',1;
   SELECT @key=JSON_VALUE(@package,'$.packageKey'),@identities=JSON_QUERY(@package,'$.pipelineIdentities'),@edges=JSON_QUERY(@package,'$.model.edges');
   IF COALESCE(JSON_VALUE(@identities,'$.contract'),N'') COLLATE Latin1_General_100_BIN2<>N'ssis-pipeline-identities' OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.contract')),0)<>48
    OR COALESCE(JSON_VALUE(@identities,'$.version'),N'')<>N'1.0.0' OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.version')),0)<>10
    OR COALESCE(JSON_VALUE(@identities,'$.identityProfile'),N'')<>N'document-order-v1' OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.identityProfile')),0)<>34
    OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.packageSha256')),0)<>128 OR COALESCE(JSON_VALUE(@identities,'$.packageSha256'),N'') COLLATE Latin1_General_100_BIN2<>JSON_VALUE(@package,'$.model.source.packageSha256') COLLATE Latin1_General_100_BIN2
    OR COALESCE(LEFT(LTRIM(JSON_QUERY(@identities,'$.pipelines')),1),N'')<>N'[' THROW 57910,N'PIPELINE_IDENTITIES_INVALID',1;
   SET @flows=JSON_QUERY(@identities,'$.pipelines');
   DECLARE [pipelineFlows] CURSOR LOCAL FAST_FORWARD FOR SELECT [value] FROM OPENJSON(@flows);
   OPEN [pipelineFlows];FETCH NEXT FROM [pipelineFlows] INTO @flow;
   WHILE @@FETCH_STATUS=0
   BEGIN
    IF SYSUTCDATETIME()>=@Deadline THROW 57910,N'PIPELINE_TIME_LIMIT',1;
    IF COALESCE(DATALENGTH(JSON_VALUE(@flow,'$.nodeId')),0) NOT BETWEEN 2 AND 256 OR COALESCE(JSON_VALUE(@flow,'$.profileStatus'),N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'SUPPORTED',N'UNQUALIFIED')
     OR DATALENGTH(JSON_VALUE(@flow,'$.profileStatus'))<>2*LEN(JSON_VALUE(@flow,'$.profileStatus'))
     OR COALESCE(LEFT(LTRIM(JSON_QUERY(@flow,'$.components')),1),N'')<>N'[' OR COALESCE(LEFT(LTRIM(JSON_QUERY(@flow,'$.paths')),1),N'')<>N'[' THROW 57910,N'PIPELINE_IDENTITIES_INVALID',1;
    SET @flowId=JSON_VALUE(@flow,'$.nodeId');
    IF NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_PipelineNodes WHERE [PackageKey]=@key AND [NodeId] COLLATE Latin1_General_100_BIN2=@flowId COLLATE Latin1_General_100_BIN2 AND DATALENGTH([NodeId])*2=DATALENGTH(JSON_VALUE(@flow,'$.nodeId')) AND [NodeKind]='EXECUTABLE') THROW 57910,N'PIPELINE_FLOW_REFERENCE_INVALID',1;
    INSERT #InternalSsisPipelineCorrelation_Flows VALUES(@key,@flowId,CASE WHEN JSON_VALUE(@flow,'$.profileStatus')='SUPPORTED' THEN 1 ELSE 0 END);
    IF (SELECT COUNT(*) FROM OPENJSON(@flow,'$.components'))<>(SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PipelineNodes WHERE [PackageKey]=@key AND [ParentNodeId]=@flowId AND [NodeKind]='COMPONENT')
     OR (SELECT COUNT(*) FROM OPENJSON(@flow,'$.paths'))<>(SELECT COUNT(*) FROM OPENJSON(@edges) WHERE JSON_VALUE([value],'$.kind')='PIPELINE_PATH' AND JSON_VALUE([value],'$.scopeId')=@flowId) THROW 57910,N'PIPELINE_OCCURRENCE_SET_INVALID',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@flow,'$.components') WITH([id] nvarchar(max) '$.nodeId',[name] nvarchar(max) '$.name',[native] nvarchar(max) '$.nativeRefId',[status] nvarchar(max) '$.profileStatus') AS [i]
     LEFT JOIN #InternalSsisExecutionScopes_PipelineNodes AS [n] ON [n].[PackageKey]=@key AND [n].[NodeId] COLLATE Latin1_General_100_BIN2=[i].[id] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([n].[NodeId])*2=DATALENGTH([i].[id])
     WHERE [n].[NodeId] IS NULL OR [n].[NodeKind]<>'COMPONENT' OR [n].[ParentNodeId]<>@flowId
      OR COALESCE([i].[name],N'') COLLATE Latin1_General_100_BIN2<>COALESCE([n].[NodeName],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH(COALESCE([i].[name],N''))<>DATALENGTH(COALESCE([n].[NodeName],N'')) OR DATALENGTH([i].[native])>8000
      OR COALESCE([i].[status],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'SUPPORTED',N'UNQUALIFIED') OR DATALENGTH([i].[status])<>2*LEN([i].[status])) THROW 57910,N'PIPELINE_COMPONENT_REFERENCE_INVALID',1;
    INSERT #InternalSsisPipelineCorrelation_Components SELECT @key,@flowId,[id],[name],CASE WHEN [status]='SUPPORTED' THEN 1 ELSE 0 END FROM OPENJSON(@flow,'$.components') WITH([id] varchar(128) '$.nodeId',[name] nvarchar(256) '$.name',[status] varchar(16) '$.profileStatus');
    IF EXISTS(SELECT 1 FROM OPENJSON(@flow,'$.paths') WITH([id] nvarchar(max) '$.edgeId',[from] nvarchar(max) '$.fromPortId',[to] nvarchar(max) '$.toPortId',[source] nvarchar(max) '$.sourceComponentId',[destination] nvarchar(max) '$.destinationComponentId',[native] nvarchar(max) '$.nativeRefId',[name] nvarchar(max) '$.name',[identification] nvarchar(max) '$.identificationString',[status] nvarchar(max) '$.profileStatus') AS [i]
     OUTER APPLY(SELECT [id],[from],[to],[scope] FROM OPENJSON(@edges) WITH([id] nvarchar(128) '$.id',[from] nvarchar(128) '$.fromId',[to] nvarchar(128) '$.toId',[kind] nvarchar(32) '$.kind',[scope] nvarchar(128) '$.scopeId') WHERE [id] COLLATE Latin1_General_100_BIN2=[i].[id] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([id])=DATALENGTH([i].[id]) AND [kind]=N'PIPELINE_PATH') AS [e]
     LEFT JOIN #InternalSsisExecutionScopes_PipelineNodes AS [f] ON [f].[PackageKey]=@key AND [f].[NodeId] COLLATE Latin1_General_100_BIN2=[i].[from] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[NodeId])*2=DATALENGTH([i].[from])
     LEFT JOIN #InternalSsisExecutionScopes_PipelineNodes AS [t] ON [t].[PackageKey]=@key AND [t].[NodeId] COLLATE Latin1_General_100_BIN2=[i].[to] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([t].[NodeId])*2=DATALENGTH([i].[to])
     WHERE [e].[id] IS NULL OR [e].[scope]<>@flowId OR COALESCE([e].[from],N'') COLLATE Latin1_General_100_BIN2<>COALESCE([i].[from],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH(COALESCE([e].[from],N''))<>DATALENGTH(COALESCE([i].[from],N''))
      OR COALESCE([e].[to],N'') COLLATE Latin1_General_100_BIN2<>COALESCE([i].[to],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH(COALESCE([e].[to],N''))<>DATALENGTH(COALESCE([i].[to],N''))
      OR COALESCE(CONVERT(nvarchar(128),[f].[ParentNodeId]),N'') COLLATE Latin1_General_100_BIN2<>COALESCE([i].[source],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH(COALESCE(CONVERT(nvarchar(128),[f].[ParentNodeId]),N''))<>DATALENGTH(COALESCE([i].[source],N''))
      OR COALESCE(CONVERT(nvarchar(128),[t].[ParentNodeId]),N'') COLLATE Latin1_General_100_BIN2<>COALESCE([i].[destination],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH(COALESCE(CONVERT(nvarchar(128),[t].[ParentNodeId]),N''))<>DATALENGTH(COALESCE([i].[destination],N''))
      OR DATALENGTH([i].[native])>8000 OR DATALENGTH([i].[name])>8000 OR DATALENGTH([i].[identification])>8000
      OR COALESCE([i].[status],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'SUPPORTED',N'UNQUALIFIED') OR DATALENGTH([i].[status])<>2*LEN([i].[status])) THROW 57910,N'PIPELINE_PATH_REFERENCE_INVALID',1;
    INSERT #InternalSsisPipelineCorrelation_Paths
    SELECT @key,@flowId,[i].[id],[i].[identification],[i].[name],[s].[Name],[d].[Name],CASE WHEN [i].[status]='SUPPORTED' AND [s].[Supported]=1 AND [d].[Supported]=1 THEN 1 ELSE 0 END
    FROM OPENJSON(@flow,'$.paths') WITH([id] varchar(128) '$.edgeId',[source] varchar(128) '$.sourceComponentId',[destination] varchar(128) '$.destinationComponentId',[name] nvarchar(4000) '$.name',[identification] nvarchar(4000) '$.identificationString',[status] varchar(16) '$.profileStatus') AS [i]
    LEFT JOIN #InternalSsisPipelineCorrelation_Components AS [s] ON [s].[PackageKey]=@key AND [s].[NodeId]=[i].[source] AND [s].[FlowNodeId]=@flowId
    LEFT JOIN #InternalSsisPipelineCorrelation_Components AS [d] ON [d].[PackageKey]=@key AND [d].[NodeId]=[i].[destination] AND [d].[FlowNodeId]=@flowId;
    FETCH NEXT FROM [pipelineFlows] INTO @flow;
   END;CLOSE [pipelineFlows];DEALLOCATE [pipelineFlows];
   FETCH NEXT FROM [pipelinePackages] INTO @package;
  END;CLOSE [pipelinePackages];DEALLOCATE [pipelinePackages];
  IF SYSUTCDATETIME()>=@Deadline THROW 57910,N'PIPELINE_TIME_LIMIT',1;
  -- Quelle nennt das zuerst gestartete Paket. Die Paketinstanz kommt dagegen
  -- aus der bereits belegten Executable-Statistik, niemals aus diesem Namen.
  INSERT #InternalSsisExecutionScopes_PipelineInstances
  SELECT [o].[SourceId],[o].[InvocationId],[o].[PackageKey],[o].[ModelNodeId],[n].[NodeName],[o].[ExecutionPath],CASE WHEN COUNT(*) OVER(PARTITION BY [o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,DATALENGTH([o].[ExecutionPath]))=1 THEN 1 ELSE 0 END
  FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN #InternalSsisPipelineCorrelation_Flows AS [f] ON [f].[PackageKey]=[o].[PackageKey] AND [f].[NodeId]=[o].[ModelNodeId] AND [f].[Supported]=1
  JOIN #InternalSsisExecutionScopes_PipelineNodes AS [n] ON [n].[PackageKey]=[f].[PackageKey] AND [n].[NodeId]=[f].[NodeId] WHERE [o].[SourceKind]='STATISTIC' AND [o].[CorrelationStatus]='EXACT_SCOPED_IDENTITY';
  IF EXISTS(SELECT 1 FROM OPENJSON(@Capture,'$.componentPhases') WITH([id] nvarchar(max) '$.phaseStatsId',[package] nvarchar(max) '$.packageName',[task] nvarchar(max) '$.taskName',[component] nvarchar(max) '$.componentName',[phase] nvarchar(max) '$.phaseName',[path] nvarchar(max) '$.executionPath',[start] nvarchar(max) '$.startTime',[end] nvarchar(max) '$.endTime') AS [r]
   WHERE COALESCE(TRY_CONVERT(bigint,[id]),0)<1 OR DATALENGTH([id])>40 OR DATALENGTH([package])>520 OR DATALENGTH([task])>8000 OR DATALENGTH([component])>8000 OR DATALENGTH([phase])>256 OR DATALENGTH([path])>8000 OR DATALENGTH([start])>128 OR DATALENGTH([end])>128 OR [start] IS NOT NULL AND TRY_CONVERT(datetimeoffset(7),[start],127) IS NULL OR [end] IS NOT NULL AND TRY_CONVERT(datetimeoffset(7),[end],127) IS NULL)
   OR EXISTS(SELECT 1 FROM OPENJSON(@Capture,'$.pathTransfers') WITH([id] nvarchar(max) '$.dataStatsId',[package] nvarchar(max) '$.packageName',[task] nvarchar(max) '$.taskName',[identification] nvarchar(max) '$.pathIdentificationString',[name] nvarchar(max) '$.pathName',[source] nvarchar(max) '$.sourceComponentName',[destination] nvarchar(max) '$.destinationComponentName',[path] nvarchar(max) '$.executionPath',[rows] nvarchar(max) '$.rowsSent',[time] nvarchar(max) '$.createdTime') AS [r]
   WHERE COALESCE(TRY_CONVERT(bigint,[id]),0)<1 OR DATALENGTH([id])>40 OR DATALENGTH([package])>520 OR DATALENGTH([task])>8000 OR DATALENGTH([identification])>8000 OR DATALENGTH([name])>8000 OR DATALENGTH([source])>8000 OR DATALENGTH([destination])>8000 OR DATALENGTH([path])>8000 OR DATALENGTH([rows])>40 OR DATALENGTH([time])>128 OR [rows] IS NOT NULL AND (TRY_CONVERT(bigint,[rows]) IS NULL OR TRY_CONVERT(bigint,[rows])<0) OR [time] IS NOT NULL AND TRY_CONVERT(datetimeoffset(7),[time],127) IS NULL) THROW 57910,N'PIPELINE_OBSERVATIONS_INVALID',1;
  INSERT #InternalSsisExecutionScopes_ComponentPhases
  SELECT TRY_CONVERT(bigint,[id]),NULL,NULL,NULL,NULL,NULL,[package],[task],[component],[phase],[path],TRY_CONVERT(datetimeoffset(7),[start],127),TRY_CONVERT(datetimeoffset(7),[end],127),
   CASE WHEN TRY_CONVERT(datetimeoffset(7),[end],127)>=TRY_CONVERT(datetimeoffset(7),[start],127) THEN DATEDIFF_BIG(millisecond,TRY_CONVERT(datetimeoffset(7),[start],127),TRY_CONVERT(datetimeoffset(7),[end],127)) END,'UNASSIGNED'
  FROM OPENJSON(@Capture,'$.componentPhases') WITH([id] nvarchar(40) '$.phaseStatsId',[package] nvarchar(260) '$.packageName',[task] nvarchar(4000) '$.taskName',[component] nvarchar(4000) '$.componentName',[phase] nvarchar(128) '$.phaseName',[path] nvarchar(4000) '$.executionPath',[start] nvarchar(64) '$.startTime',[end] nvarchar(64) '$.endTime');
  INSERT #InternalSsisExecutionScopes_PathTransfers
  SELECT TRY_CONVERT(bigint,[id]),NULL,NULL,NULL,NULL,NULL,[package],[task],[identification],[name],[source],[destination],[path],TRY_CONVERT(bigint,[rows]),TRY_CONVERT(datetimeoffset(7),[time],127),'UNASSIGNED'
  FROM OPENJSON(@Capture,'$.pathTransfers') WITH([id] nvarchar(40) '$.dataStatsId',[package] nvarchar(260) '$.packageName',[task] nvarchar(4000) '$.taskName',[identification] nvarchar(4000) '$.pathIdentificationString',[name] nvarchar(4000) '$.pathName',[source] nvarchar(4000) '$.sourceComponentName',[destination] nvarchar(4000) '$.destinationComponentName',[path] nvarchar(4000) '$.executionPath',[rows] nvarchar(40) '$.rowsSent',[time] nvarchar(64) '$.createdTime');
  DECLARE @entry nvarchar(260)=JSON_VALUE(@Capture,'$.execution.packageFileName');
  ;WITH [m] AS(
   SELECT [p].[PhaseStatsId],[f].[FlowStatisticsId],[f].[InvocationId],[f].[PackageKey],[f].[FlowNodeId],[c].[NodeId],COUNT(*) OVER(PARTITION BY [p].[PhaseStatsId]) AS [Candidates]
   FROM #InternalSsisExecutionScopes_ComponentPhases AS [p] JOIN #InternalSsisExecutionScopes_PipelineInstances AS [f] ON [f].[IsPathUnique]=1 AND [f].[ExecutionPath] COLLATE Latin1_General_100_BIN2=[p].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[ExecutionPath])=DATALENGTH([p].[ExecutionPath])
   JOIN #InternalSsisPipelineCorrelation_Components AS [c] ON [c].[PackageKey]=[f].[PackageKey] AND [c].[FlowNodeId]=[f].[FlowNodeId] AND [c].[Supported]=1 AND [c].[Name] COLLATE Latin1_General_100_BIN2=[p].[ComponentName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([c].[Name])=DATALENGTH([p].[ComponentName])
   WHERE [f].[FlowName] COLLATE Latin1_General_100_BIN2=[p].[TaskName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[FlowName])=DATALENGTH([p].[TaskName]) AND [p].[PackageName] COLLATE Latin1_General_100_BIN2=@entry COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[PackageName])=DATALENGTH(@entry))
  UPDATE [p] SET [FlowStatisticsId]=[m].[FlowStatisticsId],[InvocationId]=[m].[InvocationId],[PackageKey]=[m].[PackageKey],[FlowNodeId]=[m].[FlowNodeId],[ComponentNodeId]=[m].[NodeId],[CorrelationStatus]='SCOPED_EXACT_COMPONENT_NAME'
  FROM #InternalSsisExecutionScopes_ComponentPhases AS [p] JOIN [m] ON [m].[PhaseStatsId]=[p].[PhaseStatsId] WHERE [m].[Candidates]=1;
  IF SYSUTCDATETIME()>=@Deadline THROW 57910,N'PIPELINE_TIME_LIMIT',1;
  ;WITH [m] AS(
   SELECT [r].[DataStatsId],[f].[FlowStatisticsId],[f].[InvocationId],[f].[PackageKey],[f].[FlowNodeId],[p].[EdgeId],COUNT(*) OVER(PARTITION BY [r].[DataStatsId]) AS [Candidates]
   FROM #InternalSsisExecutionScopes_PathTransfers AS [r] JOIN #InternalSsisExecutionScopes_PipelineInstances AS [f] ON [f].[IsPathUnique]=1 AND [f].[ExecutionPath] COLLATE Latin1_General_100_BIN2=[r].[ExecutionPath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[ExecutionPath])=DATALENGTH([r].[ExecutionPath])
   JOIN #InternalSsisPipelineCorrelation_Paths AS [p] ON [p].[PackageKey]=[f].[PackageKey] AND [p].[FlowNodeId]=[f].[FlowNodeId] AND [p].[Supported]=1
    AND [p].[IdentificationString] COLLATE Latin1_General_100_BIN2=[r].[PathIdentificationString] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[IdentificationString])=DATALENGTH([r].[PathIdentificationString])
    AND [p].[Name] COLLATE Latin1_General_100_BIN2=[r].[PathName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[Name])=DATALENGTH([r].[PathName])
    AND [p].[SourceName] COLLATE Latin1_General_100_BIN2=[r].[SourceComponentName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[SourceName])=DATALENGTH([r].[SourceComponentName])
    AND [p].[DestinationName] COLLATE Latin1_General_100_BIN2=[r].[DestinationComponentName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[DestinationName])=DATALENGTH([r].[DestinationComponentName])
   WHERE [f].[FlowName] COLLATE Latin1_General_100_BIN2=[r].[TaskName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[FlowName])=DATALENGTH([r].[TaskName]) AND [r].[PackageName] COLLATE Latin1_General_100_BIN2=@entry COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[PackageName])=DATALENGTH(@entry))
  UPDATE [r] SET [FlowStatisticsId]=[m].[FlowStatisticsId],[InvocationId]=[m].[InvocationId],[PackageKey]=[m].[PackageKey],[FlowNodeId]=[m].[FlowNodeId],[ModelEdgeId]=[m].[EdgeId],[CorrelationStatus]='SCOPED_EXACT_PATH_REFERENCE'
  FROM #InternalSsisExecutionScopes_PathTransfers AS [r] JOIN [m] ON [m].[DataStatsId]=[r].[DataStatsId] WHERE [m].[Candidates]=1;
  SET @valid=1;
 END TRY
 BEGIN CATCH
  SELECT @error=ERROR_NUMBER(),@reason=CASE WHEN ERROR_NUMBER()=57910 THEN ERROR_MESSAGE() ELSE N'PIPELINE_INPUT_REJECTED' END;
  IF CURSOR_STATUS('local','pipelineFlows')>=0 CLOSE [pipelineFlows];IF CURSOR_STATUS('local','pipelineFlows')>-3 DEALLOCATE [pipelineFlows];
  IF CURSOR_STATUS('local','pipelinePackages')>=0 CLOSE [pipelinePackages];IF CURSOR_STATUS('local','pipelinePackages')>-3 DEALLOCATE [pipelinePackages];
  DELETE #InternalSsisExecutionScopes_PipelineInstances;DELETE #InternalSsisExecutionScopes_ComponentPhases;DELETE #InternalSsisExecutionScopes_PathTransfers;
 END CATCH;
 INSERT #InternalSsisExecutionScopes_PipelineCoverage
 SELECT [s].[name],CASE WHEN @valid=0 THEN 'PIPELINE_BINDING_UNPROVEN' ELSE [source].[StatusCode] END,CASE WHEN @valid=0 THEN @error ELSE [source].[ErrorNumber] END,[counts].[Observed],[counts].[Mapped],[counts].[Observed]-[counts].[Mapped],TRY_CONVERT(int,JSON_VALUE(@Capture,'$.execution.loggingLevel')),1,
  CASE WHEN [counts].[Observed]>@Limit OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PipelineInstances)>@Limit THEN 1 ELSE 0 END,@reason
 FROM(VALUES('componentPhases'),('pathTransfers')) AS [s]([name])
 LEFT JOIN #InternalSsisPipelineCorrelation_Sources AS [source] ON [source].[SourceName]=[s].[name]
 CROSS APPLY(SELECT CASE WHEN [s].[name]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_ComponentPhases) ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PathTransfers) END AS [Observed],
  CASE WHEN [s].[name]='componentPhases' THEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_ComponentPhases WHERE [ComponentNodeId] IS NOT NULL) ELSE (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_PathTransfers WHERE [ModelEdgeId] IS NOT NULL) END AS [Mapped]) AS [counts];
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
END;
GO
