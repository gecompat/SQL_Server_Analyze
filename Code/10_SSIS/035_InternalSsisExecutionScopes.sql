USE [DeineDatenbank];
GO

/* Gemeinsamer Laufzeitconsumer für einen lokal gebundenen Paketsatz.
   Einzelmodellvalidierung bleibt in USP_SsisPackageModelAnalysis; statische
   Rollen und Pfadschritte stammen ausschließlich aus dem Toolbelt-Export.
   Grenzen: 16 Pakete, 8 Aufrufebenen, 1024 beobachtete Paketinstanzen,
   50000 Statistik-/Ereigniszeilen und ein gemeinsames kooperatives Zeitbudget. */
CREATE OR ALTER PROCEDURE [monitor].[InternalSsisExecutionScopes]
 @Models nvarchar(max),@Capture nvarchar(max),@Handover uniqueidentifier,@ExecutionId bigint,
 @MaxZeilen int=1000,@MaxDurationSeconds int=30,@LockTimeoutMs int=0,@ResultSetArt varchar(16)='CONSOLE',@ResultTablesJson nvarchar(max)=NULL,
 @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,@StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,
 @ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @savedX bit=CASE WHEN @@OPTIONS&16384=16384 THEN 1 ELSE 0 END;SET XACT_ABORT OFF;
 DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT,@LockTimeoutSql nvarchar(80),@setLock nvarchar(80);
 DECLARE @deadline datetime2(3)=DATEADD(second,COALESCE(@MaxDurationSeconds,30),SYSUTCDATETIME()),@status varchar(40)='SCOPE_BINDING_UNPROVEN',@error int=NULL,@reason nvarchar(2048)=NULL,
 @mode varchar(16)=UPPER(COALESCE(@ResultSetArt,'')),@limit int=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END,@bound bit=0,@root bit=0,@rootKey varchar(16),@rootEntry nvarchar(260);
 CREATE TABLE #InternalSsisExecutionScopes_Binding([ExecutionId] bigint NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RootQualified] bit NOT NULL,[ProjectId] bigint NULL,[ProjectLsn] bigint NULL,[CatalogDatabaseGuid] uniqueidentifier NULL,[ArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceBindingSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ReasonCode] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Packages([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[EntryName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NodeCount] int NOT NULL,[ProducerTrust] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Invocations([InvocationId] bigint NOT NULL PRIMARY KEY,[ParentInvocationId] bigint NULL,[CallerStatisticsId] bigint NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Depth] int NOT NULL,[StartTime] datetimeoffset(7) NULL,[EndTime] datetimeoffset(7) NULL,[DurationMs] int NULL,[ExecutionResult] int NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Observations([SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NOT NULL,[ExecutableId] bigint NULL,[InvocationId] bigint NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[HandlerNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PackageName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PackagePath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutableGuid] uniqueidentifier NULL,[EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MessageCode] int NULL,[StartTime] datetimeoffset(7) NULL,[EndTime] datetimeoffset(7) NULL,[DurationMs] int NULL,[ExecutionResult] int NULL,[CorrelationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,PRIMARY KEY([SourceKind],[SourceId]));
 CREATE TABLE #InternalSsisExecutionScopes_Handlers([SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceId] bigint NOT NULL,[InvocationId] bigint NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[HandlerNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[OwnerNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[BodyNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EventName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TriggerEventMessageId] bigint NULL,[CausalityStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Summary([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedStatisticsCount] int NOT NULL,[SucceededCount] int NOT NULL,[FailedCount] int NOT NULL,[CancelledCount] int NOT NULL,[InclusiveObservedDurationMs] bigint NULL,[ObservationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Coverage([ExecutionId] bigint NULL,[StatisticsCount] int NOT NULL,[EventCount] int NOT NULL,[MappedStatisticsCount] int NOT NULL,[MappedEventCount] int NOT NULL,[InvocationCount] int NOT NULL,[HandlerEvidenceCount] int NOT NULL,[LoggingLevel] int NULL,[CaptureState] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[OutputTruncated] bit NOT NULL);
 CREATE TABLE #InternalSsisExecutionScopes_Map([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 BEGIN TRY
  IF @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000 OR @mode NOT IN('CONSOLE','RAW','TABLE','NONE') OR @limit<1 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60 OR @ExecutionId IS NULL OR @ExecutionId<1 OR @JsonErzeugen IS NULL OR (@mode<>'TABLE' AND @ResultTablesJson IS NOT NULL) THROW 57900,N'INVALID_PARAMETER',1;
  SET @setLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@LockTimeoutMs)+N';';EXEC sys.sp_executesql @setLock;
  IF @mode='TABLE' EXEC monitor.InternalPrepareResultTables @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'scopeBinding|packageScopes|packageInvocations|scopeObservations|handlerActivity|scopeObjectSummary|scopeCoverage',@MappingTable=N'#InternalSsisExecutionScopes_Map',@ThrowOnError=1;
  IF COALESCE(ISJSON(@Models),0)<>1 OR COALESCE(ISJSON(@Capture),0)<>1 OR DATALENGTH(@Models)>16777216 OR DATALENGTH(@Capture)>16777216 THROW 57900,N'SCOPE_TRANSPORT_INVALID',1;
  -- Doppelte Schlüssel werden vor jeder typisierten Projektion verworfen.
  CREATE TABLE #InternalSsisExecutionScopes_Json([Depth] int NOT NULL,[Value] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Kind] int NOT NULL);
  INSERT #InternalSsisExecutionScopes_Json VALUES(0,@Models,5),(0,@Capture,5);
  DECLARE @depth int=0;
  WHILE EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Json WHERE [Depth]=@depth)
  BEGIN
   IF @depth>32 OR SYSUTCDATETIME()>=@deadline THROW 57900,N'SCOPE_TRANSPORT_LIMIT',1;
   IF EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Json AS [c] CROSS APPLY(SELECT [key] COLLATE Latin1_General_100_BIN2 AS [k],DATALENGTH([key]) AS [l],COUNT(*) AS [n] FROM OPENJSON([c].[Value]) GROUP BY [key] COLLATE Latin1_General_100_BIN2,DATALENGTH([key])) AS [d] WHERE [c].[Depth]=@depth AND [c].[Kind]=5 AND [d].[n]>1) THROW 57900,N'SCOPE_DUPLICATE_KEY',1;
   INSERT #InternalSsisExecutionScopes_Json SELECT @depth+1,[j].[value],[j].[type] FROM #InternalSsisExecutionScopes_Json AS [c] CROSS APPLY OPENJSON([c].[Value]) AS [j] WHERE [c].[Depth]=@depth AND [j].[type] IN(4,5);
   DELETE #InternalSsisExecutionScopes_Json WHERE [Depth]=@depth;SET @depth+=1;
  END;
  IF COALESCE(JSON_VALUE(@Models,'$.contract'),N'') COLLATE Latin1_General_100_BIN2<>N'ssis-project-model-set' OR COALESCE(DATALENGTH(JSON_VALUE(@Models,'$.contract')),0)<>44 OR COALESCE(JSON_VALUE(@Models,'$.version'),N'') COLLATE Latin1_General_100_BIN2<>N'1.0.0' OR COALESCE(DATALENGTH(JSON_VALUE(@Models,'$.version')),0)<>10 OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Models,'$.packages')),1),N'')<>N'[' OR (SELECT COUNT(*) FROM OPENJSON(@Models,'$.packages')) NOT BETWEEN 1 AND 16 THROW 57900,N'SCOPE_MODEL_SET_INVALID',1;
  IF COALESCE(DATALENGTH(JSON_VALUE(@Models,'$.rootPackageKey')),0) NOT BETWEEN 2 AND 32 THROW 57900,N'SCOPE_ROOT_INVALID',1;
  SET @rootKey=JSON_VALUE(@Models,'$.rootPackageKey');
  CREATE TABLE #InternalSsisExecutionScopes_Definitions([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[NativeGuid] uniqueidentifier NULL,[PackagePath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Role] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EventName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CallTarget] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Steps] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[HandlerNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Supported] bit NOT NULL,PRIMARY KEY([PackageKey],[NodeId]));
  CREATE TABLE #InternalSsisExecutionScopes_Nodes([NodeOrdinal] int NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[NodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[NodeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[AttributesJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
  DECLARE @packageJson nvarchar(max),@key varchar(16),@entry nvarchar(260),@model nvarchar(max),@identities nvarchar(max),@modelStatus varchar(40),@remaining int;
  DECLARE [packages] CURSOR LOCAL FAST_FORWARD FOR SELECT [value] FROM OPENJSON(@Models,'$.packages');OPEN [packages];FETCH NEXT FROM [packages] INTO @packageJson;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @remaining=DATEDIFF(second,SYSUTCDATETIME(),@deadline);IF @remaining<1 THROW 57900,N'SCOPE_TIME_LIMIT',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@packageJson) WHERE [key] COLLATE Latin1_General_100_BIN2=N'packageKey' AND DATALENGTH([value])>32) OR DATALENGTH(JSON_VALUE(@packageJson,'$.entryName')) NOT BETWEEN 12 AND 520 THROW 57900,N'SCOPE_PACKAGE_KEY_INVALID',1;
   SELECT @key=JSON_VALUE(@packageJson,'$.packageKey'),@entry=JSON_VALUE(@packageJson,'$.entryName'),@model=JSON_QUERY(@packageJson,'$.model'),@identities=JSON_QUERY(@packageJson,'$.identities');
   IF @key IS NULL OR @key COLLATE Latin1_General_100_BIN2 LIKE '%[^a-zA-Z0-9]%' OR @entry IS NULL OR @entry LIKE N'%/%' OR @entry LIKE N'%\%' OR @entry LIKE N'%:%' THROW 57900,N'SCOPE_PACKAGE_KEY_INVALID',1;
   EXEC sys.sp_executesql N'CREATE TABLE #InternalSsisExecutionScopes_Imported([Seed] int);EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@m,@MaxZeilen=0,@MaxDurationSeconds=@r,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"nodes":"#InternalSsisExecutionScopes_Imported"}'',@StatusCodeOut=@s OUTPUT;IF @s=''AVAILABLE_LIMITED'' EXEC sys.sp_executesql N''INSERT #InternalSsisExecutionScopes_Nodes SELECT * FROM #InternalSsisExecutionScopes_Imported;'';',N'@m nvarchar(max),@r int,@s varchar(40) OUTPUT',@m=@model,@r=@remaining,@s=@modelStatus OUTPUT;
   IF COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.packageSha256')),0)<>128 OR @modelStatus<>'AVAILABLE_LIMITED' OR COALESCE(JSON_VALUE(@identities,'$.contract'),N'') COLLATE Latin1_General_100_BIN2<>N'ssis-object-identities' OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.contract')),0)<>44 OR COALESCE(JSON_VALUE(@identities,'$.version'),N'') COLLATE Latin1_General_100_BIN2<>N'1.2.0' OR COALESCE(DATALENGTH(JSON_VALUE(@identities,'$.version')),0)<>10 OR JSON_VALUE(@identities,'$.packageSha256') COLLATE Latin1_General_100_BIN2<>JSON_VALUE(@model,'$.source.packageSha256') COLLATE Latin1_General_100_BIN2 THROW 57900,N'SCOPE_MODEL_INVALID',1;
   INSERT #InternalSsisExecutionScopes_Packages VALUES(@key,@entry,JSON_VALUE(@model,'$.source.packageSha256'),(SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Nodes),'UNVERIFIED');
   IF (SELECT COUNT(*) FROM OPENJSON(@identities,'$.objects'))<>(SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Nodes WHERE [NodeKind] IN('PACKAGE','EXECUTABLE')) THROW 57900,N'SCOPE_IDENTITIES_INVALID',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@identities,'$.objects') WITH([id] nvarchar(max) '$.nodeId',[parent] nvarchar(max) '$.parentId',[kind] nvarchar(max) '$.nodeKind',[path] nvarchar(max) '$.packagePath',[role] nvarchar(max) '$.scopeKind',[steps] nvarchar(max) '$.steps' AS JSON) AS [i]
    LEFT JOIN #InternalSsisExecutionScopes_Nodes AS [n] ON [n].[NodeId] COLLATE Latin1_General_100_BIN2=[i].[id] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([n].[NodeId])*2=DATALENGTH([i].[id])
    WHERE [n].[NodeId] IS NULL OR [n].[NodeKind] NOT IN('PACKAGE','EXECUTABLE') OR DATALENGTH([n].[NodeKind])*2<>COALESCE(DATALENGTH([i].[kind]),0) OR DATALENGTH(COALESCE([n].[ParentNodeId],''))*2<>DATALENGTH(COALESCE([i].[parent],N'')) OR [n].[NodeKind] COLLATE Latin1_General_100_BIN2<>[i].[kind] COLLATE Latin1_General_100_BIN2 OR COALESCE([n].[ParentNodeId],'') COLLATE Latin1_General_100_BIN2<>COALESCE([i].[parent],N'') COLLATE Latin1_General_100_BIN2 OR DATALENGTH([i].[path])>8000 OR COALESCE([i].[role],N'') NOT IN(N'PACKAGE',N'CALL',N'LOOP',N'HANDLER',N'EXECUTABLE') OR COALESCE(LEFT(LTRIM([i].[steps]),1),N'')<>N'[' OR (SELECT COUNT(*) FROM OPENJSON([i].[steps]))>32) THROW 57900,N'SCOPE_IDENTITIES_INVALID',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@identities,'$.objects') WITH([steps] nvarchar(max) '$.steps' AS JSON,[event] nvarchar(max) '$.eventName',[role] nvarchar(max) '$.scopeKind') AS [i] CROSS APPLY OPENJSON([i].[steps]) AS [step]
       WHERE [step].[type]<>5 OR (SELECT COUNT(*) FROM OPENJSON([step].[value]))<>2
       OR NOT EXISTS(SELECT 1 FROM OPENJSON([step].[value]) WHERE [key] COLLATE Latin1_General_100_BIN2=N'text' AND DATALENGTH([key])=8 AND [type]=1 AND DATALENGTH([value]) BETWEEN 2 AND 8000)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON([step].[value]) WHERE [key] COLLATE Latin1_General_100_BIN2=N'counter' AND DATALENGTH([key])=14 AND [type]=3)) THROW 57900,N'SCOPE_STEPS_INVALID',1;
   IF EXISTS(SELECT 1 FROM OPENJSON(@identities,'$.objects') WITH([id] nvarchar(max) '$.nodeId',[parent] nvarchar(max) '$.parentId',[guid] nvarchar(max) '$.dtsId',[role] nvarchar(max) '$.scopeKind',[event] nvarchar(max) '$.eventName',[target] nvarchar(max) '$.callTarget',[status] nvarchar(max) '$.profileStatus') AS [i]
    JOIN #InternalSsisExecutionScopes_Nodes AS [n] ON [n].[NodeId] COLLATE Latin1_General_100_BIN2=[i].[id] COLLATE Latin1_General_100_BIN2
    WHERE COALESCE([i].[status],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'SUPPORTED',N'UNQUALIFIED') OR DATALENGTH([i].[status]) NOT IN(18,22)
     OR DATALENGTH([i].[role])<>2*LEN([i].[role]) OR DATALENGTH([i].[target])>520 OR DATALENGTH([i].[event])>64
     OR [i].[guid] IS NOT NULL AND (DATALENGTH([i].[guid]) NOT IN(72,76) OR TRY_CONVERT(uniqueidentifier,[i].[guid]) IS NULL)
     OR ([n].[NodeKind]='PACKAGE' AND [i].[role]<>N'PACKAGE') OR ([n].[NodeKind]<>'PACKAGE' AND [i].[role]=N'PACKAGE')
     OR CASE WHEN JSON_VALUE([n].[AttributesJson],'$.isEventHandler')='true' THEN 1 ELSE 0 END<>CASE WHEN [i].[role]=N'HANDLER' THEN 1 ELSE 0 END
     OR [i].[role]=N'HANDLER' AND [i].[status]=N'SUPPORTED' AND (COALESCE([i].[event],N'') COLLATE Latin1_General_100_BIN2 NOT IN(N'OnPreExecute',N'OnPostExecute',N'OnError') OR DATALENGTH([i].[event])<>2*LEN([i].[event]))) THROW 57900,N'SCOPE_IDENTITIES_INVALID',1;
   INSERT #InternalSsisExecutionScopes_Definitions
   SELECT @key,[id],[parent],TRY_CONVERT(uniqueidentifier,[guid]),[path],[role],[event],[target],[steps],CASE WHEN [role]='HANDLER' THEN [id] END,CASE WHEN [status]='SUPPORTED' THEN 1 ELSE 0 END
   FROM OPENJSON(@identities,'$.objects') WITH([id] varchar(128) '$.nodeId',[parent] varchar(128) '$.parentId',[guid] nvarchar(38) '$.dtsId',[path] nvarchar(4000) '$.packagePath',[role] varchar(16) '$.scopeKind',[event] varchar(32) '$.eventName',[target] nvarchar(260) '$.callTarget',[steps] nvarchar(max) '$.steps' AS JSON,[status] varchar(16) '$.profileStatus');
   DELETE #InternalSsisExecutionScopes_Nodes;FETCH NEXT FROM [packages] INTO @packageJson;
  END;CLOSE [packages];DEALLOCATE [packages];
  -- Zugehörigkeit zu Handlern folgt ausschließlich der geprüften Modellhierarchie.
  SET @depth=0;
  WHILE @depth<32
  BEGIN
   UPDATE [d] SET [HandlerNodeId]=[p].[HandlerNodeId] FROM #InternalSsisExecutionScopes_Definitions AS [d] JOIN #InternalSsisExecutionScopes_Definitions AS [p] ON [p].[PackageKey]=[d].[PackageKey] AND [p].[NodeId]=[d].[ParentNodeId] WHERE [d].[HandlerNodeId] IS NULL AND [p].[HandlerNodeId] IS NOT NULL;
   IF @@ROWCOUNT=0 BREAK;SET @depth+=1;
  END;
  SELECT @rootEntry=[EntryName] FROM #InternalSsisExecutionScopes_Packages WHERE [PackageKey]=@rootKey;
  IF @rootEntry IS NULL OR EXISTS(SELECT [EntryName] COLLATE Latin1_General_100_BIN2,DATALENGTH([EntryName]) FROM #InternalSsisExecutionScopes_Packages GROUP BY [EntryName] COLLATE Latin1_General_100_BIN2,DATALENGTH([EntryName]) HAVING COUNT(*)>1) THROW 57900,N'SCOPE_ROOT_INVALID',1;
  DECLARE @receipt nvarchar(3750),@receiptName sysname=N'SSIS_SCOPE_'+LOWER(CONVERT(nvarchar(36),@Handover));
  SELECT @receipt=TRY_CONVERT(nvarchar(3750),[value]) FROM [sys].[extended_properties] WITH (READCOMMITTEDLOCK) WHERE [class]=1 AND [major_id]=(SELECT [sys].[procedures].[object_id] FROM [sys].[procedures] WITH (READCOMMITTEDLOCK) JOIN [sys].[schemas] WITH (READCOMMITTEDLOCK) ON [sys].[schemas].[schema_id]=[sys].[procedures].[schema_id] WHERE [sys].[schemas].[name]=N'monitor' AND DATALENGTH([sys].[schemas].[name])=14 AND [sys].[procedures].[name]=N'USP_SsisPackageModelAnalysis' AND DATALENGTH([sys].[procedures].[name])=56) AND [minor_id]=0 AND [name] COLLATE Latin1_General_100_BIN2=@receiptName COLLATE Latin1_General_100_BIN2 AND DATALENGTH([name])=DATALENGTH(@receiptName);
  IF COALESCE(ISJSON(@receipt),0)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@receipt))<>6
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,DATALENGTH([key]) FROM OPENJSON(@receipt) GROUP BY [key] COLLATE Latin1_General_100_BIN2,DATALENGTH([key]) HAVING COUNT(*)>1)
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.issuedUtc'),127) IS NULL OR TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.expiresUtc'),127) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.expiresUtc'),127)>DATEADD(hour,24,TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.issuedUtc'),127))
   OR COALESCE(JSON_VALUE(@receipt,'$.contract'),N'') COLLATE Latin1_General_100_BIN2<>N'ssis-local-scope-handover' OR COALESCE(DATALENGTH(JSON_VALUE(@receipt,'$.contract')),0)<>50 OR COALESCE(JSON_VALUE(@receipt,'$.version'),N'') COLLATE Latin1_General_100_BIN2<>N'1.0.0' OR COALESCE(DATALENGTH(JSON_VALUE(@receipt,'$.version')),0)<>10 OR TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.issuedUtc'),127)>SYSUTCDATETIME() OR TRY_CONVERT(datetime2(3),JSON_VALUE(@receipt,'$.expiresUtc'),127)<=SYSUTCDATETIME()
   OR COALESCE(DATALENGTH(JSON_VALUE(@receipt,'$.modelSetSha256')),0)<>128 OR COALESCE(DATALENGTH(JSON_VALUE(@receipt,'$.captureSha256')),0)<>128
   OR COALESCE(UPPER(JSON_VALUE(@receipt,'$.modelSetSha256')),'') COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Models)),2) COLLATE Latin1_General_100_BIN2
   OR COALESCE(UPPER(JSON_VALUE(@receipt,'$.captureSha256')),'') COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Capture)),2) COLLATE Latin1_General_100_BIN2 THROW 57900,N'SCOPE_HANDOVER_UNPROVEN',1;
  IF COALESCE(JSON_VALUE(@Capture,'$.contract'),N'') COLLATE Latin1_General_100_BIN2<>N'ssis-execution-scopes' OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.contract')),0)<>42 OR COALESCE(JSON_VALUE(@Capture,'$.version'),N'') COLLATE Latin1_General_100_BIN2<>N'1.0.0' OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.version')),0)<>10 OR COALESCE(JSON_VALUE(@Capture,'$.method'),N'') COLLATE Latin1_General_100_BIN2<>N'SSISDB_CURRENT_PROJECT_SCOPES_V1' OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.method')),0)<>64 OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Capture,'$.execution.executionId')),0)<>@ExecutionId
   OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.modelSetSha256')),0)<>128 OR COALESCE(UPPER(JSON_VALUE(@Capture,'$.modelSetSha256')),'') COLLATE Latin1_General_100_BIN2<>CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Models)),2) COLLATE Latin1_General_100_BIN2
   OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.execution.packageFileName')),0)=0 OR JSON_VALUE(@Capture,'$.execution.packageFileName') COLLATE Latin1_General_100_BIN2<>@rootEntry COLLATE Latin1_General_100_BIN2 OR DATALENGTH(JSON_VALUE(@Capture,'$.execution.packageFileName'))<>DATALENGTH(@rootEntry) THROW 57900,N'SCOPE_CAPTURE_BINDING_INVALID',1;
  IF COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Capture,'$.execution.projectId')),0)<1 OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Capture,'$.execution.projectLsn')),0)<1 OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Capture,'$.execution.catalogDatabaseGuid')) IS NULL OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.execution.sourceBindingSha256')),0)<>128 OR COALESCE(DATALENGTH(JSON_VALUE(@Capture,'$.archiveSha256')),0)<>128 THROW 57900,N'SCOPE_SOURCE_BINDING_INVALID',1;
  SET @bound=1;UPDATE #InternalSsisExecutionScopes_Packages SET [ProducerTrust]='VERIFIED_SCOPE_CAPTURE';
  IF COALESCE(LEFT(LTRIM(JSON_QUERY(@Capture,'$.observations')),1),N'')<>N'[' OR COALESCE(LEFT(LTRIM(JSON_QUERY(@Capture,'$.events')),1),N'')<>N'[' OR (SELECT COUNT(*) FROM OPENJSON(@Capture,'$.observations'))+(SELECT COUNT(*) FROM OPENJSON(@Capture,'$.events'))>50000 THROW 57900,N'SCOPE_OBSERVATIONS_INVALID',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(@Capture,'$.observations') WITH([execution] nvarchar(max) '$.executionId',[id] nvarchar(max) '$.statisticsId',[executable] nvarchar(max) '$.executableId',[package] nvarchar(max) '$.packageName',[path] nvarchar(max) '$.packagePath',[runtime] nvarchar(max) '$.executionPath',[guid] nvarchar(max) '$.executableGuid') AS [r] WHERE COALESCE(TRY_CONVERT(bigint,[execution]),0)<>@ExecutionId OR COALESCE(TRY_CONVERT(bigint,[id]),0)<1 OR COALESCE(TRY_CONVERT(bigint,[executable]),0)<1 OR DATALENGTH([package])>520 OR DATALENGTH([path])>8000 OR DATALENGTH([runtime])>8000 OR [guid] IS NOT NULL AND (DATALENGTH([guid]) NOT IN(72,76) OR TRY_CONVERT(uniqueidentifier,[guid]) IS NULL))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Capture,'$.events') WITH([id] nvarchar(max) '$.eventMessageId',[package] nvarchar(max) '$.packageName',[path] nvarchar(max) '$.packagePath',[runtime] nvarchar(max) '$.executionPath',[guid] nvarchar(max) '$.executableGuid',[event] nvarchar(max) '$.eventName') AS [r] WHERE COALESCE(TRY_CONVERT(bigint,[id]),0)<1 OR DATALENGTH([package])>520 OR DATALENGTH([path])>8000 OR DATALENGTH([runtime])>8000 OR DATALENGTH([event])>256 OR [guid] IS NOT NULL AND (DATALENGTH([guid]) NOT IN(72,76) OR TRY_CONVERT(uniqueidentifier,[guid]) IS NULL)) THROW 57900,N'SCOPE_OBSERVATIONS_INVALID',1;
  INSERT #InternalSsisExecutionScopes_Observations
  SELECT 'STATISTIC',TRY_CONVERT(bigint,[id]),TRY_CONVERT(bigint,[executable]),NULL,NULL,NULL,NULL,[package],[path],[executionPath],TRY_CONVERT(uniqueidentifier,[guid]),NULL,NULL,TRY_CONVERT(datetimeoffset(7),[start],127),TRY_CONVERT(datetimeoffset(7),[end],127),TRY_CONVERT(int,[duration]),TRY_CONVERT(int,[result]),'UNASSIGNED'
  FROM OPENJSON(@Capture,'$.observations') WITH([executable] nvarchar(40) '$.executableId',[id] nvarchar(40) '$.statisticsId',[package] nvarchar(260) '$.packageName',[path] nvarchar(4000) '$.packagePath',[executionPath] nvarchar(4000) '$.executionPath',[guid] nvarchar(38) '$.executableGuid',[start] nvarchar(64) '$.startTime',[end] nvarchar(64) '$.endTime',[duration] nvarchar(40) '$.durationMs',[result] nvarchar(40) '$.executionResult');
  INSERT #InternalSsisExecutionScopes_Observations
  SELECT 'EVENT',TRY_CONVERT(bigint,[id]),NULL,NULL,NULL,NULL,NULL,[package],[path],[executionPath],TRY_CONVERT(uniqueidentifier,[guid]),[event],TRY_CONVERT(int,[code]),TRY_CONVERT(datetimeoffset(7),[time],127),NULL,NULL,NULL,'UNASSIGNED'
  FROM OPENJSON(@Capture,'$.events') WITH([id] nvarchar(40) '$.eventMessageId',[package] nvarchar(260) '$.packageName',[path] nvarchar(4000) '$.packagePath',[executionPath] nvarchar(4000) '$.executionPath',[guid] nvarchar(38) '$.executableGuid',[event] nvarchar(128) '$.eventName',[code] nvarchar(40) '$.messageCode',[time] nvarchar(64) '$.messageTime');
  IF EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Observations WHERE [SourceId]<1) THROW 57900,N'SCOPE_OBSERVATIONS_INVALID',1;
  DECLARE @rootCount int,@rootStatisticId bigint;
  SELECT @rootCount=COUNT(*),@rootStatisticId=MAX([o].[SourceId]) FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN #InternalSsisExecutionScopes_Definitions AS [d] ON [d].[PackageKey]=@rootKey AND [d].[Role]='PACKAGE' AND [d].[NativeGuid]=[o].[ExecutableGuid]
  WHERE [o].[SourceKind]='STATISTIC' AND [o].[PackageName] COLLATE Latin1_General_100_BIN2=@rootEntry COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH(@rootEntry) AND [o].[PackagePath] COLLATE Latin1_General_100_BIN2=[d].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackagePath])=DATALENGTH([d].[PackagePath])
   AND LEFT([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,1)=N'\' AND DATALENGTH([o].[ExecutionPath])>2 AND CHARINDEX(N'\',[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,2)=0
   AND (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Definitions AS [g] WHERE [g].[PackageKey]=[d].[PackageKey] AND [g].[NativeGuid]=[d].[NativeGuid])=1;
  IF @rootCount=1
  BEGIN
   SET @root=1;
   INSERT #InternalSsisExecutionScopes_Invocations SELECT [o].[SourceId],NULL,NULL,@rootKey,[o].[ExecutionPath],0,[o].[StartTime],[o].[EndTime],[o].[DurationMs],[o].[ExecutionResult] FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN #InternalSsisExecutionScopes_Definitions AS [d] ON [d].[PackageKey]=@rootKey AND [d].[Role]='PACKAGE' AND [d].[NativeGuid]=[o].[ExecutableGuid] WHERE [o].[SourceKind]='STATISTIC' AND [o].[SourceId]=@rootStatisticId;
   CREATE TABLE #InternalSsisExecutionScopes_Visited([InvocationId] bigint PRIMARY KEY);
   DECLARE @invocation bigint,@invocationPackage varchar(16),@invocationPath nvarchar(4000),@invocationDepth int;
   WHILE EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Invocations AS [i] WHERE NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Visited AS [v] WHERE [v].[InvocationId]=[i].[InvocationId]))
   BEGIN
    IF SYSUTCDATETIME()>=@deadline OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Invocations)>1024 THROW 57900,N'SCOPE_CORRELATION_LIMIT',1;
    SELECT TOP(1) @invocation=[i].[InvocationId],@invocationPackage=[i].[PackageKey],@invocationPath=[i].[ExecutionPath],@invocationDepth=[i].[Depth] FROM #InternalSsisExecutionScopes_Invocations AS [i] WHERE NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Visited AS [v] WHERE [v].[InvocationId]=[i].[InvocationId]) ORDER BY [i].[Depth],[i].[InvocationId];
    ;WITH [matches] AS(
     SELECT [o].[SourceKind],[o].[SourceId],[d].[NodeId],[d].[HandlerNodeId],COUNT(*) OVER(PARTITION BY [o].[SourceKind],[o].[SourceId]) AS [Candidates]
     FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN #InternalSsisExecutionScopes_Definitions AS [d] ON [d].[PackageKey]=@invocationPackage AND [d].[NativeGuid]=[o].[ExecutableGuid] AND [d].[Supported]=1
     JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[PackageKey]=[d].[PackageKey]
     WHERE [o].[PackageName] COLLATE Latin1_General_100_BIN2=[p].[EntryName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH([p].[EntryName]) AND [o].[PackagePath] COLLATE Latin1_General_100_BIN2=[d].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackagePath])=DATALENGTH([d].[PackagePath])
      AND (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Definitions AS [g] WHERE [g].[PackageKey]=[d].[PackageKey] AND [g].[NativeGuid]=[d].[NativeGuid])=1 AND EXISTS(SELECT 1 FROM monitor.InternalSsisScopePathMatch(@invocationPath,[o].[ExecutionPath],[d].[Steps]) WHERE [IsMatch]=1))
    UPDATE [o] SET [InvocationId]=@invocation,[PackageKey]=@invocationPackage,[ModelNodeId]=[m].[NodeId],[HandlerNodeId]=[m].[HandlerNodeId],[CorrelationStatus]='EXACT_SCOPED_IDENTITY'
    FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN [matches] AS [m] ON [m].[SourceKind]=[o].[SourceKind] AND [m].[SourceId]=[o].[SourceId] WHERE [m].[Candidates]=1 AND [o].[InvocationId] IS NULL;
    CREATE TABLE #InternalSsisExecutionScopes_AncestorPackages([PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    ;WITH [a] AS(SELECT [InvocationId],[ParentInvocationId],[PackageKey] FROM #InternalSsisExecutionScopes_Invocations WHERE [InvocationId]=@invocation UNION ALL SELECT [p].[InvocationId],[p].[ParentInvocationId],[p].[PackageKey] FROM #InternalSsisExecutionScopes_Invocations AS [p] JOIN [a] ON [a].[ParentInvocationId]=[p].[InvocationId]) INSERT #InternalSsisExecutionScopes_AncestorPackages SELECT [PackageKey] FROM [a] OPTION(MAXRECURSION 9);
    IF @invocationDepth<8
    BEGIN
     ;WITH [children] AS(
      SELECT [o].[SourceId],[p].[PackageKey],[o].[ExecutionPath],[o].[StartTime],[o].[EndTime],[o].[DurationMs],[o].[ExecutionResult],[caller].[SourceId] AS [CallerId],COUNT(*) OVER(PARTITION BY [o].[SourceId]) AS [Candidates],COUNT(*) OVER(PARTITION BY [p].[PackageKey],[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,DATALENGTH([o].[ExecutionPath])) AS [PathCandidates]
      FROM #InternalSsisExecutionScopes_Observations AS [caller] JOIN #InternalSsisExecutionScopes_Definitions AS [call] ON [call].[PackageKey]=@invocationPackage AND [call].[NodeId]=[caller].[ModelNodeId] AND [call].[Role]='CALL'
      JOIN #InternalSsisExecutionScopes_Packages AS [p] ON [p].[EntryName] COLLATE Latin1_General_100_BIN2=[call].[CallTarget] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[EntryName])=DATALENGTH([call].[CallTarget])
      JOIN #InternalSsisExecutionScopes_Definitions AS [definition] ON [definition].[PackageKey]=[p].[PackageKey] AND [definition].[Role]='PACKAGE' AND [definition].[Supported]=1
      JOIN #InternalSsisExecutionScopes_Observations AS [o] ON [o].[SourceKind]='STATISTIC' AND [o].[ExecutableGuid]=[definition].[NativeGuid]
      CROSS APPLY(SELECT CONVERT(nvarchar(max),[caller].[ExecutionPath])+N'\' AS [prefix]) AS [prefix]
      WHERE [caller].[SourceKind]='STATISTIC' AND [caller].[InvocationId]=@invocation AND [o].[PackageName] COLLATE Latin1_General_100_BIN2=[p].[EntryName] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackageName])=DATALENGTH([p].[EntryName])
       AND [o].[PackagePath] COLLATE Latin1_General_100_BIN2=[definition].[PackagePath] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([o].[PackagePath])=DATALENGTH([definition].[PackagePath])
       AND LEFT([o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,DATALENGTH([prefix].[prefix])/2) COLLATE Latin1_General_100_BIN2=[prefix].[prefix] COLLATE Latin1_General_100_BIN2
       AND DATALENGTH([o].[ExecutionPath])>DATALENGTH([prefix].[prefix]) AND CHARINDEX(N'\',[o].[ExecutionPath] COLLATE Latin1_General_100_BIN2,DATALENGTH([prefix].[prefix])/2+1)=0
       AND NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_AncestorPackages AS [a] WHERE [a].[PackageKey]=[p].[PackageKey]) AND NOT EXISTS(SELECT 1 FROM #InternalSsisExecutionScopes_Invocations AS [prior] WHERE [prior].[InvocationId]=[o].[SourceId])
       AND (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Definitions AS [g] WHERE [g].[PackageKey]=[definition].[PackageKey] AND [g].[NativeGuid]=[definition].[NativeGuid])=1)
     INSERT #InternalSsisExecutionScopes_Invocations SELECT [SourceId],@invocation,[CallerId],[PackageKey],[ExecutionPath],@invocationDepth+1,[StartTime],[EndTime],[DurationMs],[ExecutionResult] FROM [children] WHERE [Candidates]=1 AND [PathCandidates]=1;
    END;
    DROP TABLE #InternalSsisExecutionScopes_AncestorPackages;
    INSERT #InternalSsisExecutionScopes_Visited VALUES(@invocation);
   END;
  END;
  SET @status='SCOPE_CAPTURE_BOUND';
 END TRY
 BEGIN CATCH
  SELECT @error=ERROR_NUMBER(),@reason=CASE WHEN ERROR_NUMBER()=57900 THEN ERROR_MESSAGE() ELSE N'SCOPE_INPUT_REJECTED' END;
  IF CURSOR_STATUS('local','packages')>=0 CLOSE [packages];IF CURSOR_STATUS('local','packages')>-3 DEALLOCATE [packages];
  SET @status=CASE WHEN @reason=N'INVALID_PARAMETER' THEN 'INVALID_PARAMETER' ELSE 'SCOPE_BINDING_UNPROVEN' END;SET @bound=0;SET @root=0;
  DELETE #InternalSsisExecutionScopes_Invocations;DELETE #InternalSsisExecutionScopes_Observations;UPDATE #InternalSsisExecutionScopes_Packages SET [ProducerTrust]='UNVERIFIED';
 END CATCH;
 BEGIN TRY
 INSERT #InternalSsisExecutionScopes_Binding VALUES(@ExecutionId,@status,@root,CASE WHEN @bound=1 THEN TRY_CONVERT(bigint,JSON_VALUE(@Capture,'$.execution.projectId')) END,CASE WHEN @bound=1 THEN TRY_CONVERT(bigint,JSON_VALUE(@Capture,'$.execution.projectLsn')) END,CASE WHEN @bound=1 THEN TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Capture,'$.execution.catalogDatabaseGuid')) END,CASE WHEN @bound=1 THEN JSON_VALUE(@Capture,'$.archiveSha256') END,CASE WHEN @bound=1 THEN JSON_VALUE(@Capture,'$.execution.sourceBindingSha256') END,@reason);
 IF @bound=1
 BEGIN
  INSERT #InternalSsisExecutionScopes_Handlers SELECT [o].[SourceKind],[o].[SourceId],[o].[InvocationId],[o].[PackageKey],[o].[HandlerNodeId],[h].[ParentNodeId],[o].[ModelNodeId],[h].[EventName],NULL,'UNPROVEN' FROM #InternalSsisExecutionScopes_Observations AS [o] JOIN #InternalSsisExecutionScopes_Definitions AS [h] ON [h].[PackageKey]=[o].[PackageKey] AND [h].[NodeId]=[o].[HandlerNodeId] WHERE [o].[HandlerNodeId] IS NOT NULL;
  INSERT #InternalSsisExecutionScopes_Summary SELECT [d].[PackageKey],[d].[NodeId],COUNT([o].[SourceId]),SUM(CASE WHEN [o].[ExecutionResult]=0 THEN 1 ELSE 0 END),SUM(CASE WHEN [o].[ExecutionResult]=1 THEN 1 ELSE 0 END),SUM(CASE WHEN [o].[ExecutionResult]=3 THEN 1 ELSE 0 END),CASE WHEN COUNT([o].[SourceId])>0 AND COUNT([o].[SourceId])=SUM(CASE WHEN [o].[DurationMs]>=0 THEN 1 ELSE 0 END) THEN SUM(CONVERT(bigint,[o].[DurationMs])) END,CASE WHEN COUNT([o].[SourceId])=0 THEN 'UNASSIGNED_OR_NOT_OBSERVED' ELSE 'OBSERVED_PARTIAL' END,1
   FROM #InternalSsisExecutionScopes_Definitions AS [d] LEFT JOIN #InternalSsisExecutionScopes_Observations AS [o] ON [o].[PackageKey]=[d].[PackageKey] AND [o].[ModelNodeId]=[d].[NodeId] AND [o].[SourceKind]='STATISTIC' GROUP BY [d].[PackageKey],[d].[NodeId];
 END;
 INSERT #InternalSsisExecutionScopes_Coverage SELECT @ExecutionId,COALESCE(SUM(CASE WHEN [SourceKind]='STATISTIC' THEN 1 ELSE 0 END),0),COALESCE(SUM(CASE WHEN [SourceKind]='EVENT' THEN 1 ELSE 0 END),0),COALESCE(SUM(CASE WHEN [SourceKind]='STATISTIC' AND [ModelNodeId] IS NOT NULL THEN 1 ELSE 0 END),0),COALESCE(SUM(CASE WHEN [SourceKind]='EVENT' AND [ModelNodeId] IS NOT NULL THEN 1 ELSE 0 END),0),(SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Invocations),(SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Handlers),CASE WHEN @bound=1 THEN TRY_CONVERT(int,JSON_VALUE(@Capture,'$.execution.loggingLevel')) END,CASE WHEN @bound=0 THEN 'UNPROVEN' WHEN TRY_CONVERT(int,JSON_VALUE(@Capture,'$.execution.executionStatus')) IN(3,4,6,7,9) THEN 'TERMINAL_CAPTURE' ELSE 'IN_PROGRESS_CAPTURE' END,1,0 FROM #InternalSsisExecutionScopes_Observations;
 -- SQL SUM auf leerer Quelle bleibt unbekannt; die Quellmengen sind dennoch null Zeilen.
 UPDATE #InternalSsisExecutionScopes_Coverage SET [StatisticsCount]=COALESCE([StatisticsCount],0),[EventCount]=COALESCE([EventCount],0),[MappedStatisticsCount]=COALESCE([MappedStatisticsCount],0),[MappedEventCount]=COALESCE([MappedEventCount],0);
 UPDATE #InternalSsisExecutionScopes_Coverage SET [OutputTruncated]=CASE WHEN (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Packages)>@limit OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Invocations)>@limit OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Observations)>@limit OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Handlers)>@limit OR (SELECT COUNT(*) FROM #InternalSsisExecutionScopes_Summary)>@limit THEN 1 ELSE 0 END;
 DECLARE @spec nvarchar(max)=N'[{"name":"scopeBinding","table":"#InternalSsisExecutionScopes_Binding","order":"ExecutionId"},{"name":"packageScopes","table":"#InternalSsisExecutionScopes_Packages","order":"PackageKey"},{"name":"packageInvocations","table":"#InternalSsisExecutionScopes_Invocations","order":"InvocationId"},{"name":"scopeObservations","table":"#InternalSsisExecutionScopes_Observations","order":"SourceKind,SourceId"},{"name":"handlerActivity","table":"#InternalSsisExecutionScopes_Handlers","order":"SourceKind,SourceId"},{"name":"scopeObjectSummary","table":"#InternalSsisExecutionScopes_Summary","order":"PackageKey,ModelNodeId"},{"name":"scopeCoverage","table":"#InternalSsisExecutionScopes_Coverage","order":"ExecutionId"}]';
 IF @JsonErzeugen=1 SET @Json=N'{"meta":{"schemaVersion":1,"executionScopesSchemaVersion":1,"isPartial":true}}';
 DECLARE @name sysname,@table sysname,@order nvarchar(128),@target sysname,@array nvarchar(max),@sql nvarchar(max);
 DECLARE [outputs] CURSOR LOCAL FAST_FORWARD FOR SELECT [name],[table],[order] FROM OPENJSON(@spec) WITH([name] sysname,[table] sysname,[order] nvarchar(128));OPEN [outputs];FETCH NEXT FROM [outputs] INTO @name,@table,@order;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @sql=N'SELECT @a=COALESCE((SELECT TOP(@n) * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N' FOR JSON PATH,INCLUDE_NULL_VALUES),N''[]'');';
  EXEC sys.sp_executesql @sql,N'@n int,@a nvarchar(max) OUTPUT',@n=@limit,@a=@array OUTPUT;
  IF @JsonErzeugen=1 SET @Json=JSON_MODIFY(@Json,'$.'+@name,JSON_QUERY(@array));
  SET @sql=N';WITH r AS(SELECT *,ROW_NUMBER() OVER(ORDER BY '+@order+N') AS OutputRow FROM '+QUOTENAME(@table)+N') DELETE FROM r WHERE OutputRow>@n;';EXEC sys.sp_executesql @sql,N'@n int',@n=@limit;
  IF @mode='RAW' BEGIN SET @sql=N'SELECT * FROM '+QUOTENAME(@table)+N' ORDER BY '+@order+N';';EXEC sys.sp_executesql @sql;END;
  IF @mode='TABLE' BEGIN SELECT @target=[TargetTable] FROM #InternalSsisExecutionScopes_Map WHERE [ResultName]=@name;IF @target IS NOT NULL EXEC monitor.InternalWriteResultTable @table,@target,@ThrowOnError=1;SET @target=NULL;END;
  FETCH NEXT FROM [outputs] INTO @name,@table,@order;
 END;CLOSE [outputs];DEALLOCATE [outputs];
 IF @mode='CONSOLE' EXEC monitor.InternalEmitConsoleResult @SourceTable=N'#InternalSsisExecutionScopes_Binding',@ResultLabel=N'SsisExecutionScopes',@EmptyMessage=N'Keine fachlichen Ergebnisse';
 SELECT @StatusCodeOut=@status,@IsPartialOut=1,@ErrorNumberOut=@error,@ErrorMessageOut=@reason;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','outputs')>=0 CLOSE [outputs];IF CURSOR_STATUS('local','outputs')>-3 DEALLOCATE [outputs];
  SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
  IF @savedX=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
  THROW;
 END CATCH;
 SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @LockTimeoutSql;
 IF @savedX=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
END;
GO
