USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
P3: Prüft sieben bestehende Resultsets mit 105 Feldern und 45 Textcollations.
Alle Ausgaben verwenden bereits dieselben materialisierten Mengen. Der Test
prüft negative Limits und gültige TABLE-Zuordnungen bei ungültigen Parametern.
Der optionale positive Block liest nur extern vorbereitete eigene Unicode-CI-
Datenbanken auf SQL Server 2025 mit eingefrorenem Query Store. Er erzeugt keine
Objekte, ändert keine Optionen und führt keinen synthetischen Workload aus.
Katalogrollen und Runtimewerte sind native Evidenz ohne HADR-Healthaussage.
Waits und Forcing bleiben in dieser Fixture leer; positive Aggregationen dort,
AG/Secondary-Workload, fehlende Rollenzuordnung, Berechtigungen, Timeouts sowie
ältere Engines und weitere native Compatibility Levels werden nicht belegt.
RAW-Zeilenparität und vollständige positive CONSOLE-Metadaten benötigen einen
zusätzlichen Clientcapture; die direkten Aufrufe hier prüfen Status und JSON.
*/
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170) THROW 58200,N'REPLICA_FRAMEWORK_LEVEL',1;
IF COALESCE(CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')),N'')<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58201,N'REPLICA_FRAMEWORK_COLLATION',1;
DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),@OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @UpperName nvarchar(128)=N'ExampleReplicaÄ🔬',@LowerName nvarchar(128)=N'exampleReplicaÄ🔬',@WrongName nvarchar(128)=N'EXAMPLEReplicaÄ🔬';
DECLARE @MissingName nvarchar(128)=N'ExampleMissingReplicaÄ🔬',@MissingScope nvarchar(258),@AllNames nvarchar(max),@FixtureStatus varchar(24)='NOT_EXECUTED';
SET @MissingScope=QUOTENAME(@MissingName);SET @AllNames=QUOTENAME(@UpperName)+N'|'+QUOTENAME(@LowerName);
IF EXISTS(SELECT 1 FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@MissingName,@WrongName))
 THROW 58202,N'REPLICA_MISSING_IDENTIFIER',1;
DECLARE @Sql nvarchar(max),@Db nvarchar(128),@DbId int;
CREATE TABLE #ExampleReplicaReplicasSchema
([CapturedAtUtc] datetime2(3) NOT NULL,
 [DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CurrentQueryStoreStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaGroupId] bigint NOT NULL,
 [RoleType] tinyint NULL,
 [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [IsPrimaryRole] bit NOT NULL,
 [IsSecondaryRole] bit NOT NULL,
 [IsNamedReplica] bit NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
SELECT TOP(0) * INTO #ExampleReplicaReplicasNative FROM #ExampleReplicaReplicasSchema;
SELECT TOP(0) * INTO #ExampleReplicaReplicasExpected FROM #ExampleReplicaReplicasSchema;
CREATE TABLE #ExampleReplicaRuntimeByReplicaSchema
([CapturedAtUtc] datetime2(3) NOT NULL,
 [DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaGroupId] bigint NULL,
 [RoleType] tinyint NULL,
 [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RecordedRows] bigint NOT NULL,
 [QueryCount] bigint NOT NULL,
 [PlanCount] bigint NOT NULL,
 [ExecutionCount] bigint NOT NULL,
 [FirstExecutionTimeUtc] datetimeoffset NULL,
 [LastExecutionTimeUtc] datetimeoffset NULL,
 [TotalDurationMs] decimal(38,3) NULL,
 [TotalCpuMs] decimal(38,3) NULL,
 [TotalLogicalReads] decimal(38,3) NULL,
 [TotalLogicalWrites] decimal(38,3) NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
SELECT TOP(0) * INTO #ExampleReplicaRuntimeByReplicaNative FROM #ExampleReplicaRuntimeByReplicaSchema;
SELECT TOP(0) * INTO #ExampleReplicaRuntimeByReplicaExpected FROM #ExampleReplicaRuntimeByReplicaSchema;
CREATE TABLE #ExampleReplicaWaitsByReplicaSchema
([CapturedAtUtc] datetime2(3) NOT NULL,
 [DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaGroupId] bigint NULL,
 [RoleType] tinyint NULL,
 [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ExecutionTypeDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WaitCategory] tinyint NULL,
 [WaitCategoryDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RecordedRows] bigint NOT NULL,
 [FirstIntervalStartUtc] datetimeoffset NULL,
 [LastIntervalEndUtc] datetimeoffset NULL,
 [TotalQueryWaitTimeMs] bigint NULL,
 [MaxQueryWaitTimeMs] bigint NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleReplicaForcingByReplicaSchema
([CapturedAtUtc] datetime2(3) NOT NULL,
 [DatabaseId] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaGroupId] bigint NULL,
 [RoleType] tinyint NULL,
 [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ForcingLocationCount] bigint NOT NULL,
 [ForcedQueryCount] bigint NOT NULL,
 [ForcedPlanCount] bigint NOT NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleReplicaSourceStatusSchema
([SourceOrdinal] int NOT NULL,
 [DatabaseId] int NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsPartial] bit NOT NULL,
 [ReturnedRowCount] bigint NOT NULL,
 [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ErrorNumber] int NULL,
 [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleReplicaWarningsSchema
([WarningOrdinal] int NOT NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ErrorNumber] int NULL,
 [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE #ExampleReplicaModuleStatusSchema
([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [CapturedAtUtc] datetime2(3) NOT NULL,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [IsPartial] bit NOT NULL,
 [ProductMajorVersion] int NULL,
 [CrossDatabaseRequested] bit NOT NULL,
 [DatabaseCount] int NOT NULL,
 [ReplicaRowCount] bigint NOT NULL,
 [RuntimeRowCount] bigint NOT NULL,
 [WaitRowCount] bigint NOT NULL,
 [ForcingRowCount] bigint NOT NULL,
 [HasMoreReplicaRows] bit NOT NULL,
 [HasMoreRuntimeRows] bit NOT NULL,
 [HasMoreWaitRows] bit NOT NULL,
 [HasMoreForcingRows] bit NOT NULL,
 [ErrorNumber] int NULL,
 [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SELECT TOP(0) * INTO #ExampleReplicaSourceStatusExpected FROM #ExampleReplicaSourceStatusSchema;
CREATE TABLE #ExampleReplicaOptions
([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [Level] int NOT NULL,[CollationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [ActualState] int NOT NULL,[ActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [DesiredState] int NOT NULL,[CaptureMode] int NOT NULL,[WaitMode] int NOT NULL,[CurrentIsPrimary] int NULL,
 [CatalogRows] bigint NOT NULL,[KeysValid] bit NOT NULL,[RuntimeGroups] int NOT NULL,[WaitRows] bigint NOT NULL,[ForcingRows] bigint NOT NULL,
 [FirstIntervalStart] datetimeoffset NULL,[LastIntervalEnd] datetimeoffset NULL);
CREATE TABLE #ExampleReplicaSelected([DatabaseId] int NOT NULL,[DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedOrdinal] int NOT NULL);
CREATE TABLE #ExampleReplicaRoleLiteral
([RoleType] tinyint NOT NULL,[RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPrimaryRole] bit NOT NULL,[IsSecondaryRole] bit NOT NULL,[IsNamedReplica] bit NOT NULL);
INSERT #ExampleReplicaRoleLiteral VALUES(1,'PRIMARY','READ_WRITE_ROLE',1,0,0),(2,'SECONDARY','READ_ONLY_ROLE',0,1,0),
 (3,'GEO_PRIMARY','READ_WRITE_ROLE',1,0,0),(4,'GEO_SECONDARY','READ_ONLY_ROLE',0,1,0);
CREATE TABLE #ExampleReplicaContract
([ResultName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaTable] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 [TargetTable] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Fields] int NOT NULL,[Texts] int NOT NULL);
INSERT #ExampleReplicaContract VALUES
 (N'replicas',N'#ExampleReplicaReplicasSchema',N'#ExampleReplicaReplicasExport',15,8),
 (N'runtimeByReplica',N'#ExampleReplicaRuntimeByReplicaSchema',N'#ExampleReplicaRuntimeByReplicaExport',21,7),
 (N'waitsByReplica',N'#ExampleReplicaWaitsByReplicaSchema',N'#ExampleReplicaWaitsByReplicaExport',19,9),
 (N'forcingByReplica',N'#ExampleReplicaForcingByReplicaSchema',N'#ExampleReplicaForcingByReplicaExport',14,7),
 (N'sourceStatus',N'#ExampleReplicaSourceStatusSchema',N'#ExampleReplicaSourceStatusExport',13,7),
 (N'warnings',N'#ExampleReplicaWarningsSchema',N'#ExampleReplicaWarningsExport',6,4),
 (N'moduleStatus',N'#ExampleReplicaModuleStatusSchema',N'#ExampleReplicaModuleStatusExport',17,3);
DECLARE @Mapping nvarchar(max)=N'{"replicas":"#ExampleReplicaReplicasExport","runtimeByReplica":"#ExampleReplicaRuntimeByReplicaExport","waitsByReplica":"#ExampleReplicaWaitsByReplicaExport","forcingByReplica":"#ExampleReplicaForcingByReplicaExport","sourceStatus":"#ExampleReplicaSourceStatusExport","warnings":"#ExampleReplicaWarningsExport","moduleStatus":"#ExampleReplicaModuleStatusExport"}';
DECLARE @NativeFrom datetime2(7),@NativeTo datetime2(7),@Now datetime2(7)=SYSUTCDATETIME();
CREATE TABLE #ExampleReplicaCases
([CaseNumber] int NOT NULL,[Native] bit NOT NULL,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,[Groups] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [WindowKind] int NOT NULL,[LockMs] int NULL,[HighImpact] bit NULL,[JsonBit] bit NULL,[PrintBit] bit NULL,
 [ExpectedStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedPartial] bit NOT NULL,
 [MissingWarning] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExpectedCrossDatabase] bit NOT NULL);
INSERT #ExampleReplicaCases VALUES
 (0,0,@MissingScope,NULL,NULL,NULL,0,0,0,1,0,'AVAILABLE_LIMITED',1,@MissingName,0),
 (1,0,@MissingScope,NULL,0,NULL,0,0,0,1,0,'AVAILABLE_LIMITED',1,@MissingName,0),
 (2,0,@MissingScope,NULL,1,NULL,0,0,0,1,0,'AVAILABLE_LIMITED',1,@MissingName,0),
 (3,0,@MissingScope,NULL,-1,NULL,0,0,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (4,0,@MissingScope,NULL,-2,NULL,0,0,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (5,0,@MissingScope,NULL,0,NULL,0,-1,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (6,0,@MissingScope,NULL,0,NULL,0,60001,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (7,0,@MissingScope,NULL,0,NULL,0,0,NULL,1,0,'INVALID_PARAMETER',1,NULL,0),
 (8,0,@MissingScope,NULL,0,NULL,0,0,0,NULL,0,'INVALID_PARAMETER',1,NULL,0),
 (9,0,@MissingScope,NULL,0,NULL,0,0,0,1,NULL,'INVALID_PARAMETER',1,NULL,0),
 (10,0,@MissingScope,NULL,0,NULL,3,0,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (11,0,@MissingScope,NULL,0,N'ExampleInvalidNumber',0,0,0,1,0,'INVALID_PARAMETER',1,NULL,0),
 (12,0,N'[ExampleInvalid',NULL,0,NULL,0,0,0,1,0,'INVALID_PARAMETER',0,NULL,0),
 (13,0,@MissingScope+N'|'+@MissingScope,NULL,0,NULL,0,0,0,1,0,'INVALID_PARAMETER',0,NULL,1);
IF @Major IS NULL OR @Major<17 UPDATE #ExampleReplicaCases SET ExpectedStatus='UNAVAILABLE_VERSION' WHERE CaseNumber IN(0,1,2);
-- Positive source preparation belongs to the external owner, not this test.
IF @Major>=17 AND @FrameworkLevel=170 AND TRY_CONVERT(int,SERVERPROPERTY(N'IsHadrEnabled'))=0
 AND (SELECT COUNT(*) FROM master.sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@UpperName,@LowerName) AND state=0 AND HAS_DBACCESS(name)=1)=2
BEGIN
 DECLARE [Fixture180] CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM master.sys.databases
  WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS IN(@UpperName,@LowerName) ORDER BY database_id;
 OPEN [Fixture180];FETCH NEXT FROM [Fixture180] INTO @Db;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@Db)+N'; INSERT #ExampleReplicaOptions
   (DatabaseId,DatabaseName,[Level],CollationName,ActualState,ActualStateDesc,DesiredState,CaptureMode,WaitMode,CurrentIsPrimary,
    CatalogRows,KeysValid,RuntimeGroups,WaitRows,ForcingRows,FirstIntervalStart,LastIntervalEnd)
   SELECT DB_ID(),DB_NAME(),(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
    CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N''Collation'')),actual_state,actual_state_desc,desired_state,query_capture_mode,wait_stats_capture_mode,
    TRY_CONVERT(int,sys.fn_hadr_is_primary_replica(DB_NAME())),(SELECT COUNT_BIG(*) FROM sys.query_store_replicas),
    CONVERT(bit,CASE WHEN (SELECT COUNT(*) FROM sys.query_store_replicas WHERE replica_group_id IN(1,2,3,4) AND role_type=replica_group_id)=4
     AND NOT EXISTS(SELECT 1 FROM sys.query_store_runtime_stats WHERE replica_group_id<>1 OR count_executions<=0) THEN 1 ELSE 0 END),
    (SELECT COUNT(DISTINCT replica_group_id) FROM sys.query_store_runtime_stats),
    (SELECT COUNT_BIG(*) FROM sys.query_store_wait_stats),(SELECT COUNT_BIG(*) FROM sys.query_store_plan_forcing_locations),
    (SELECT MIN(i.start_time) FROM sys.query_store_runtime_stats rs JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=rs.runtime_stats_interval_id),
    (SELECT MAX(i.end_time) FROM sys.query_store_runtime_stats rs JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=rs.runtime_stats_interval_id)
   FROM sys.database_query_store_options;';
  EXEC sys.sp_executesql @Sql;
  FETCH NEXT FROM [Fixture180] INTO @Db;
 END;
 CLOSE [Fixture180];DEALLOCATE [Fixture180];
 IF (SELECT COUNT(*) FROM #ExampleReplicaOptions)=2 AND (SELECT COUNT(DISTINCT DatabaseId) FROM #ExampleReplicaOptions)=2
  AND NOT EXISTS(SELECT 1 FROM #ExampleReplicaOptions WHERE [Level]<>170 OR CollationName<>N'Latin1_General_100_CI_AS'
   OR ActualState<>1 OR DesiredState<>1 OR CaptureMode<>3 OR CurrentIsPrimary IS NOT NULL OR CatalogRows<>4 OR KeysValid<>1 OR RuntimeGroups<>1
   OR WaitRows<>0 OR ForcingRows<>0 OR FirstIntervalStart IS NULL OR LastIntervalEnd IS NULL OR FirstIntervalStart>=LastIntervalEnd)
 BEGIN
  SELECT @NativeFrom=CONVERT(datetime2(7),MIN(FirstIntervalStart)),@NativeTo=CONVERT(datetime2(7),MAX(LastIntervalEnd)) FROM #ExampleReplicaOptions;
  SET @FixtureStatus='PENDING';
  INSERT #ExampleReplicaCases VALUES
   (20,1,@AllNames,NULL,NULL,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (21,1,@AllNames,NULL,0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (22,1,@AllNames,NULL,1,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (23,1,@AllNames,NULL,2,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (24,1,QUOTENAME(@UpperName),NULL,0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,0),
   (25,1,QUOTENAME(@LowerName),NULL,0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,0),
   (26,1,NULL,N'like:ExampleReplica%',0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (27,1,NULL,N'like:%ReplicaÄ🔬',0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (28,1,@AllNames,NULL,0,N'1',0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (29,1,@AllNames,NULL,0,N'2',0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (30,1,@AllNames,NULL,0,N'1|2',0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (31,1,@AllNames,NULL,0,N'999999',0,0,0,1,0,'NOT_APPLICABLE',0,NULL,1),
   (32,1,QUOTENAME(@UpperName)+N'|'+@MissingScope,NULL,0,NULL,0,0,0,1,0,'AVAILABLE_LIMITED',1,@MissingName,1),
   (33,1,QUOTENAME(@WrongName),NULL,0,NULL,0,0,0,1,0,'AVAILABLE_LIMITED',1,@WrongName,0),
   (34,1,QUOTENAME(@LowerName)+N'|'+QUOTENAME(@UpperName),NULL,0,NULL,0,0,0,1,0,'AVAILABLE',0,NULL,1),
   (35,1,@AllNames,NULL,0,NULL,1,0,0,1,0,'AVAILABLE',0,NULL,1),
   (36,1,@AllNames,NULL,0,NULL,2,0,0,1,0,'AVAILABLE',0,NULL,1),
   (37,1,@AllNames,NULL,-1,NULL,0,0,0,1,0,'INVALID_PARAMETER',1,NULL,0);
 END;
END;
DECLARE @LoadSql nvarchar(max)=N'
INSERT #ExampleReplicaReplicasNative
 SELECT @at,DB_ID(),DB_NAME(),o.actual_state_desc,''NOT_IN_AG_OR_UNKNOWN'',r.replica_group_id,r.role_type,
  l.RoleTypeDesc,l.RoleClass,CONVERT(nvarchar(4000),r.replica_name),l.IsPrimaryRole,l.IsSecondaryRole,l.IsNamedReplica,''AVAILABLE'',
  N''Rollenabbildung für sys.query_store_replicas.role_type; beobachtete Rollen sind keine aktuelle Erreichbarkeits- oder Healthaussage.''
 FROM sys.query_store_replicas r CROSS JOIN sys.database_query_store_options o
 JOIN #ExampleReplicaRoleLiteral l ON l.RoleType=r.role_type
 WHERE @groups IS NULL OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''1'' COLLATE SQL_Latin1_General_CP1_CS_AS AND r.replica_group_id=1)
  OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''2'' COLLATE SQL_Latin1_General_CP1_CS_AS AND r.replica_group_id=2)
  OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''1|2'' COLLATE SQL_Latin1_General_CP1_CS_AS AND r.replica_group_id IN(1,2));
INSERT #ExampleReplicaRuntimeByReplicaNative
 SELECT @at,DB_ID(),DB_NAME(),''NOT_IN_AG_OR_UNKNOWN'',rs.replica_group_id,
  MAX(r.role_type),MAX(l.RoleTypeDesc),MAX(l.RoleClass),MAX(CONVERT(nvarchar(4000),r.replica_name)),''AVAILABLE'',
  COUNT_BIG(*),COUNT_BIG(DISTINCT p.query_id),COUNT_BIG(DISTINCT rs.plan_id),SUM(CONVERT(bigint,rs.count_executions)),
  MIN(rs.first_execution_time),MAX(rs.last_execution_time),
  CONVERT(decimal(38,3),SUM(CONVERT(float,rs.avg_duration)*rs.count_executions)/1000.0),
  CONVERT(decimal(38,3),SUM(CONVERT(float,rs.avg_cpu_time)*rs.count_executions)/1000.0),
  CONVERT(decimal(38,3),SUM(CONVERT(float,rs.avg_logical_io_reads)*rs.count_executions)),
  CONVERT(decimal(38,3),SUM(CONVERT(float,rs.avg_logical_io_writes)*rs.count_executions)),
  N''Intervallaggregate nach replica_group_id; keine aktuelle Einzelausführung, kein Querytext und keine Replikatsynchronitätsaussage.''
 FROM sys.query_store_runtime_stats rs JOIN sys.query_store_runtime_stats_interval i ON i.runtime_stats_interval_id=rs.runtime_stats_interval_id
 JOIN sys.query_store_plan p ON p.plan_id=rs.plan_id JOIN sys.query_store_replicas r ON r.replica_group_id=rs.replica_group_id
 JOIN #ExampleReplicaRoleLiteral l ON l.RoleType=r.role_type
 WHERE i.end_time>@from AND i.start_time<@to
  AND (@groups IS NULL OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''1'' COLLATE SQL_Latin1_General_CP1_CS_AS AND rs.replica_group_id=1)
   OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''2'' COLLATE SQL_Latin1_General_CP1_CS_AS AND rs.replica_group_id=2)
   OR (@groups COLLATE SQL_Latin1_General_CP1_CS_AS=N''1|2'' COLLATE SQL_Latin1_General_CP1_CS_AS AND rs.replica_group_id IN(1,2)))
 GROUP BY rs.replica_group_id;';
DECLARE @CoreCases int=0,@NativeCases int=0,@ConsumerCases int=0,@PreflightCases int=0,@SqlConsoleCases int=0,@DirectConsoleCases int=0;
DECLARE @Case int,@Native bit,@Names nvarchar(max),@Pattern nvarchar(4000),@MaxRows int,@Groups nvarchar(max),@Window int,@Lock int,@High bit,@Generate bit,@Print bit,
 @Status varchar(40),@Partial bit,@Missing nvarchar(128),@Cross bit,@OutStatus varchar(40),@OutPartial bit,@OutError int,@OutMessage nvarchar(2048);
DECLARE @From datetime2(7),@To datetime2(7),@Json nvarchar(max),@Before datetime2(3),@After datetime2(3),@At datetime2(3),@Limit bigint;
DECLARE @ResultName nvarchar(128),@SchemaTable nvarchar(128),@TargetTable nvarchar(128),@Fields int,@Texts int,@TableJson nvarchar(max),@ExpectedJson nvarchar(max),@Array nvarchar(max),@Rows bigint;
CREATE TABLE #ExampleReplicaPreflight([Dummy] int NULL);
BEGIN TRY
 SET LOCK_TIMEOUT 137;
 DECLARE [Cases180] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleReplicaCases ORDER BY CaseNumber;
 OPEN [Cases180];FETCH NEXT FROM [Cases180] INTO @Case,@Native,@Names,@Pattern,@MaxRows,@Groups,@Window,@Lock,@High,@Generate,@Print,@Status,@Partial,@Missing,@Cross;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @Limit=CASE WHEN @MaxRows IS NULL OR @MaxRows=0 THEN CONVERT(bigint,9223372036854775807) WHEN @MaxRows<0 THEN 0 ELSE @MaxRows END;
  SELECT @From=CASE WHEN @Native=1 THEN @NativeFrom ELSE DATEADD(HOUR,-1,@Now) END,@To=CASE WHEN @Native=1 THEN @NativeTo ELSE @Now END;
  IF @Window=1 SELECT @From=DATEADD(YEAR,-1,@NativeFrom),@To=DATEADD(MINUTE,1,DATEADD(YEAR,-1,@NativeFrom));
  IF @Window=2 SELECT @From=DATEADD(MILLISECOND,1,@NativeFrom),@To=DATEADD(MILLISECOND,-1,@NativeTo);
  IF @Window=3 SET @From=@To;
  TRUNCATE TABLE #ExampleReplicaSelected;
  TRUNCATE TABLE #ExampleReplicaReplicasNative;TRUNCATE TABLE #ExampleReplicaRuntimeByReplicaNative;
  TRUNCATE TABLE #ExampleReplicaReplicasExpected;TRUNCATE TABLE #ExampleReplicaRuntimeByReplicaExpected;TRUNCATE TABLE #ExampleReplicaSourceStatusExpected;
  IF @Native=1 AND @Case<>37
  BEGIN
   INSERT #ExampleReplicaSelected
   SELECT DatabaseId,DatabaseName,CONVERT(int,CASE WHEN @Case=34 THEN CASE WHEN DatabaseName=@LowerName THEN 1 ELSE 2 END
    WHEN @Pattern IS NOT NULL THEN ROW_NUMBER() OVER(ORDER BY DatabaseId) ELSE CASE WHEN DatabaseName=@UpperName THEN 1 ELSE 2 END END)
   FROM #ExampleReplicaOptions o
   WHERE @Names=@AllNames OR @Case=34 OR @Names=QUOTENAME(DatabaseName) OR (@Case=32 AND DatabaseName=@UpperName)
    OR (@Pattern IS NOT NULL AND DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS LIKE SUBSTRING(@Pattern,6,4000) COLLATE SQL_Latin1_General_CP1_CS_AS);
   DECLARE [Native180] CURSOR LOCAL FAST_FORWARD FOR SELECT DatabaseId,DatabaseName FROM #ExampleReplicaSelected ORDER BY RequestedOrdinal;
   OPEN [Native180];FETCH NEXT FROM [Native180] INTO @DbId,@Db;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @Sql=N'USE '+QUOTENAME(@Db)+N'; IF DB_ID()<>@id
     OR (SELECT actual_state FROM sys.database_query_store_options)<>1
     OR (SELECT desired_state FROM sys.database_query_store_options)<>1
     OR (SELECT query_capture_mode FROM sys.database_query_store_options)<>3
     OR (SELECT COUNT_BIG(*) FROM sys.query_store_replicas)<>4
     OR EXISTS(SELECT 1 FROM sys.query_store_wait_stats) OR EXISTS(SELECT 1 FROM sys.query_store_plan_forcing_locations)
     THROW 58204,N''REPLICA_NATIVE_FIXTURE_STABILITY'',1;'+@LoadSql;
    EXEC sys.sp_executesql @Sql,N'@id int,@at datetime2(3),@from datetime2(7),@to datetime2(7),@groups nvarchar(max)',
     @DbId,N'20000101',@From,@To,@Groups;
    FETCH NEXT FROM [Native180] INTO @DbId,@Db;
   END;
   CLOSE [Native180];DEALLOCATE [Native180];
  END;
  INSERT #ExampleReplicaReplicasExpected SELECT TOP(@Limit) * FROM #ExampleReplicaReplicasNative ORDER BY DatabaseId,ReplicaGroupId,RoleType;
  INSERT #ExampleReplicaRuntimeByReplicaExpected SELECT TOP(@Limit) * FROM #ExampleReplicaRuntimeByReplicaNative
   ORDER BY TotalCpuMs DESC,LastExecutionTimeUtc DESC,DatabaseId,ReplicaGroupId;
  CREATE TABLE #ExampleReplicaReplicasExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaRuntimeByReplicaExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaWaitsByReplicaExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaForcingByReplicaExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaSourceStatusExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaWarningsExport([Dummy] int NULL);
  CREATE TABLE #ExampleReplicaModuleStatusExport([Dummy] int NULL);
  SET @Json=N'ExamplePreviousJson';SET @Before=SYSUTCDATETIME();
  EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@Names,@QueryStoreDatabaseNamePattern=@Pattern,@ReplicaGroupIds=@Groups,
   @VonUtc=@From,@BisUtc=@To,@MaxZeilen=@MaxRows,@LockTimeoutMs=@Lock,@HighImpactConfirmed=@High,@ResultSetArt='TABLE',
   @ResultTablesJson=@Mapping,@JsonErzeugen=@Generate,@Json=@Json OUTPUT,@PrintMeldungen=@Print,
   @StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT,@ErrorNumberOut=@OutError OUTPUT,@ErrorMessageOut=@OutMessage OUTPUT;
  SET @After=SYSUTCDATETIME();
  IF @@LOCK_TIMEOUT<>137 OR @OutStatus<>@Status OR @OutPartial<>@Partial OR @OutError IS NOT NULL
   OR (@Status='INVALID_PARAMETER' AND @OutMessage IS NULL) THROW 58205,N'REPLICA_OUTPUT_STATUS_LOCK',1;
  -- The TABLE bridge drops the two source identities, as it does for existing callers.
  DECLARE [Contract180] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleReplicaContract;
  OPEN [Contract180];FETCH NEXT FROM [Contract180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
  WHILE @@FETCH_STATUS=0
  BEGIN
   IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable))<>@Fields
    OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable) AND collation_name=N'SQL_Latin1_General_CP1_CS_AS')<>@Texts
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
     FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable)
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
     FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable))
    OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
     FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable)
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
     FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable)) THROW 58206,N'REPLICA_TABLE_SCHEMA',1;
   FETCH NEXT FROM [Contract180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
  END;
  CLOSE [Contract180];DEALLOCATE [Contract180];
  SET @Sql=N'SELECT @a=CapturedAtUtc FROM #ExampleReplicaModuleStatusExport;';
  EXEC sys.sp_executesql @Sql,N'@a datetime2(3) OUTPUT',@At OUTPUT;
  IF @At IS NULL OR @At<@Before OR @At>@After THROW 58207,N'REPLICA_CAPTURE_TIME',1;
  SET @Sql=N'IF EXISTS(SELECT 1 FROM #ExampleReplicaModuleStatusExport WHERE ModuleName<>N''USP_QueryStoreReplicaAnalysis'' OR StatusCode<>@status OR IsPartial<>@partial
   OR ProductMajorVersion<>@major OR CrossDatabaseRequested<>@cross OR DatabaseCount<>(SELECT COUNT(*) FROM #ExampleReplicaSelected)
   OR ReplicaRowCount<>(SELECT COUNT_BIG(*) FROM #ExampleReplicaReplicasExpected) OR RuntimeRowCount<>(SELECT COUNT_BIG(*) FROM #ExampleReplicaRuntimeByReplicaExpected)
   OR WaitRowCount<>0 OR ForcingRowCount<>0 OR HasMoreReplicaRows<>CASE WHEN (SELECT COUNT_BIG(*) FROM #ExampleReplicaReplicasNative)>@limit THEN 1 ELSE 0 END
   OR HasMoreRuntimeRows<>CASE WHEN (SELECT COUNT_BIG(*) FROM #ExampleReplicaRuntimeByReplicaNative)>@limit THEN 1 ELSE 0 END
   OR HasMoreWaitRows<>0 OR HasMoreForcingRows<>0 OR ErrorNumber IS NOT NULL OR ErrorMessage COLLATE Latin1_General_100_BIN2<>@message COLLATE Latin1_General_100_BIN2
   OR (ErrorMessage IS NULL AND @message IS NOT NULL) OR (ErrorMessage IS NOT NULL AND @message IS NULL))
   OR (SELECT COUNT(*) FROM #ExampleReplicaModuleStatusExport)<>1 THROW 58208,N''REPLICA_MODULE_FULL_VALUES'',1;';
  EXEC sys.sp_executesql @Sql,N'@status varchar(40),@partial bit,@major int,@cross bit,@limit bigint,@message nvarchar(2048)',@Status,@Partial,@Major,@Cross,@Limit,@OutMessage;
  IF @Generate IS NULL
  BEGIN
   IF @Json IS NOT NULL THROW 58209,N'REPLICA_NULL_JSON_BIT',1;
  END
  ELSE
  BEGIN
   IF @Json IS NULL OR ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>8
    OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json) EXCEPT SELECT * FROM
     (VALUES(N'meta',5),(N'moduleStatus',4),(N'replicas',4),(N'runtimeByReplica',4),(N'waitsByReplica',4),(N'forcingByReplica',4),(N'sourceStatus',4),(N'warnings',4)) t(k,v))
    OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>13
    OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT k FROM
     (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),(N'productMajorVersion'),(N'fromUtc'),(N'toUtc'),
      (N'requestedMaxRows'),(N'hasMoreReplicaRows'),(N'hasMoreRuntimeRows'),(N'hasMoreWaitRows'),(N'hasMoreForcingRows')) t(k))
    OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE
     ([key] IN(N'resultName',N'generatedAtUtc',N'statusCode',N'fromUtc',N'toUtc') AND [type]<>1)
     OR ([key] IN(N'schemaVersion',N'productMajorVersion') AND [type]<>2)
     OR ([key] IN(N'isPartial',N'hasMoreReplicaRows',N'hasMoreRuntimeRows',N'hasMoreWaitRows',N'hasMoreForcingRows') AND [type]<>3)
     OR ([key]=N'requestedMaxRows' AND [type]<>CASE WHEN @MaxRows IS NULL THEN 0 ELSE 2 END))
    OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStoreReplicaAnalysis' OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
    OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Partial=1 THEN N'true' ELSE N'false' END
    OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.productMajorVersion'))<>@Major
    OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'))<>@At
    OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.fromUtc'))<>@From OR TRY_CONVERT(datetime2(7),JSON_VALUE(@Json,N'$.meta.toUtc'))<>@To
    OR (@MaxRows IS NOT NULL AND COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),2147483647)<>@MaxRows)
    OR JSON_VALUE(@Json,N'$.meta.hasMoreReplicaRows')<>CASE WHEN (SELECT COUNT_BIG(*) FROM #ExampleReplicaReplicasNative)>@Limit THEN N'true' ELSE N'false' END
    OR JSON_VALUE(@Json,N'$.meta.hasMoreRuntimeRows')<>CASE WHEN (SELECT COUNT_BIG(*) FROM #ExampleReplicaRuntimeByReplicaNative)>@Limit THEN N'true' ELSE N'false' END
    OR JSON_VALUE(@Json,N'$.meta.hasMoreWaitRows')<>N'false' OR JSON_VALUE(@Json,N'$.meta.hasMoreForcingRows')<>N'false'
     THROW 58210,N'REPLICA_META',1;
  END;
  UPDATE #ExampleReplicaReplicasExpected SET CapturedAtUtc=@At;
  UPDATE #ExampleReplicaRuntimeByReplicaExpected SET CapturedAtUtc=@At;
  DECLARE @SourceBase int=0,@CatalogCount bigint,@RuntimeCount bigint,@WaitMode int,@ActualDesc nvarchar(60);
  DECLARE [Sources180] CURSOR LOCAL FAST_FORWARD FOR SELECT s.DatabaseId,s.DatabaseName,o.WaitMode,o.ActualStateDesc
   FROM #ExampleReplicaSelected s JOIN #ExampleReplicaOptions o ON o.DatabaseId=s.DatabaseId ORDER BY s.RequestedOrdinal;
  OPEN [Sources180];FETCH NEXT FROM [Sources180] INTO @DbId,@Db,@WaitMode,@ActualDesc;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SELECT @CatalogCount=COUNT_BIG(*) FROM #ExampleReplicaReplicasNative WHERE DatabaseId=@DbId;
   SELECT @RuntimeCount=COUNT_BIG(*) FROM #ExampleReplicaRuntimeByReplicaNative WHERE DatabaseId=@DbId;
   INSERT #ExampleReplicaSourceStatusExpected VALUES
    (@SourceBase+1,@DbId,@Db,N'queryStoreOptions',N'sys.database_query_store_options',@At,'AVAILABLE',0,1,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,
     N'actual_state_desc='+@ActualDesc+N'; aktueller AG-Rollenhinweis=NOT_IN_AG_OR_UNKNOWN.'),
    (@SourceBase+2,@DbId,@Db,N'replicaCatalog',N'sys.query_store_replicas',@At,CASE WHEN @CatalogCount=0 THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@CatalogCount,
     N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Eine Zeile beschreibt eine beobachtete Query-Store-Rolle. Failover kann mehrere historische Rollen erzeugen; dies ist keine aktuelle Healthaussage.'),
    (@SourceBase+3,@DbId,@Db,N'runtimeByReplica',N'sys.query_store_runtime_stats.replica_group_id',@At,CASE WHEN @RuntimeCount=0 THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@RuntimeCount,
     N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Runtimewerte werden je replica_group_id getrennt und aus Query-Store-Intervallen gewichtet.'),
    (@SourceBase+4,@DbId,@Db,N'waitsByReplica',N'sys.query_store_wait_stats.replica_group_id',@At,CASE WHEN @WaitMode=1 THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'NOT_APPLICABLE' END,0,0,
     N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,CASE WHEN @WaitMode=1 THEN N'Waitwerte werden je replica_group_id, Ausführungstyp und Kategorie getrennt.'
      ELSE N'Wait-Capture und Pflichtspalte müssen verfügbar sein; fehlendes Wait-Capture ist kein Fehler.' END),
    (@SourceBase+5,@DbId,@Db,N'forcingByReplica',N'sys.query_store_plan_forcing_locations',@At,'EMPTY_VISIBLE_SCOPE',0,0,
     N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Forcing-Locations werden nach replica_group_id getrennt und ausschließlich inventarisiert.');
   SET @SourceBase+=5;
   FETCH NEXT FROM [Sources180] INTO @DbId,@Db,@WaitMode,@ActualDesc;
  END;
  CLOSE [Sources180];DEALLOCATE [Sources180];
  DECLARE [Parity180] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleReplicaContract;
  OPEN [Parity180];FETCH NEXT FROM [Parity180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @Sql=N'SELECT @j=(SELECT * FROM '+QUOTENAME(@TargetTable)+N' FOR JSON PATH,INCLUDE_NULL_VALUES),@r=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@TargetTable)+N');';
   EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT,@r bigint OUTPUT',@TableJson OUTPUT,@Rows OUTPUT;
   SET @TableJson=COALESCE(@TableJson,N'[]');SET @Array=CASE WHEN @Generate IS NULL THEN @TableJson ELSE JSON_QUERY(@Json,N'$.'+@ResultName) END;
   IF @Rows<>(SELECT COUNT(*) FROM OPENJSON(@Array))
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2
     EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Array) GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Array) GROUP BY value COLLATE Latin1_General_100_BIN2
     EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT 1 FROM OPENJSON(@Array) a WHERE a.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>@Fields
     OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
     OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value)
      EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable))
     OR EXISTS(SELECT 1 FROM OPENJSON(a.value) p JOIN tempdb.sys.columns c ON c.name=p.[key] COLLATE SQL_Latin1_General_CP1_CS_AS AND c.object_id=OBJECT_ID(N'tempdb..'+@SchemaTable)
      WHERE (p.type=0 AND c.is_nullable=0) OR (p.type<>0 AND p.type<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(48,52,56,127,106,108,59,62) THEN 2 ELSE 1 END)))
      THROW 58211,N'REPLICA_TABLE_JSON_FIELDS_MULTISET',1;
   SET @ExpectedJson=N'[]';
   IF @ResultName=N'replicas' SELECT @ExpectedJson=(SELECT * FROM #ExampleReplicaReplicasExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @ResultName=N'runtimeByReplica' SELECT @ExpectedJson=(SELECT * FROM #ExampleReplicaRuntimeByReplicaExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @ResultName=N'sourceStatus' SELECT @ExpectedJson=(SELECT * FROM #ExampleReplicaSourceStatusExpected FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @ResultName=N'warnings' AND @Missing IS NOT NULL
    SELECT @ExpectedJson=(SELECT CONVERT(int,1) AS WarningOrdinal,CONVERT(nvarchar(128),@Missing) AS DatabaseName,CONVERT(nvarchar(128),N'databaseCandidates') AS SourceName,
     CONVERT(varchar(40),'DATABASE_UNAVAILABLE') AS StatusCode,CONVERT(int,NULL) AS ErrorNumber,
     CONVERT(nvarchar(2048),N'Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.') AS Message FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF @ResultName<>N'moduleStatus' AND
    (EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
     OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@ExpectedJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2))
      THROW 58212,N'REPLICA_NATIVE_FULL_FIELDS',1;
   FETCH NEXT FROM [Parity180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
  END;
  CLOSE [Parity180];DEALLOCATE [Parity180];
  DROP TABLE #ExampleReplicaReplicasExport;DROP TABLE #ExampleReplicaRuntimeByReplicaExport;DROP TABLE #ExampleReplicaWaitsByReplicaExport;
  DROP TABLE #ExampleReplicaForcingByReplicaExport;DROP TABLE #ExampleReplicaSourceStatusExport;DROP TABLE #ExampleReplicaWarningsExport;DROP TABLE #ExampleReplicaModuleStatusExport;
  IF @Native=1 SET @NativeCases+=1;ELSE SET @CoreCases+=1;
  FETCH NEXT FROM [Cases180] INTO @Case,@Native,@Names,@Pattern,@MaxRows,@Groups,@Window,@Lock,@High,@Generate,@Print,@Status,@Partial,@Missing,@Cross;
 END;
 CLOSE [Cases180];DEALLOCATE [Cases180];
 -- Each selective TABLE mapping is tested with sentinel rows in every unrequested target.
 SELECT ResultName,SchemaTable,REPLACE(TargetTable,N'Export',N'Partial') AS TargetTable,Fields,Texts INTO #ExampleReplicaPartialContract FROM #ExampleReplicaContract;
 DECLARE @MapRun int=0,@MapCase int,@SelectedMap nvarchar(max),@GeneralPartialMaps int=0,@NativePartialMaps int=0,@Mapped bit;
 WHILE @MapRun<CASE WHEN @FixtureStatus='PENDING' THEN 2 ELSE 1 END
 BEGIN
  SET @MapCase=0;
  WHILE @MapCase<9
  BEGIN
   CREATE TABLE #ExampleReplicaReplicasPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaRuntimeByReplicaPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaWaitsByReplicaPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaForcingByReplicaPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaSourceStatusPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaWarningsPartial([Dummy] int NULL);
   CREATE TABLE #ExampleReplicaModuleStatusPartial([Dummy] int NULL);
   IF @MapCase<7
   BEGIN
    SELECT @ResultName=ResultName,@TargetTable=TargetTable FROM
     (SELECT *,ROW_NUMBER() OVER(ORDER BY ResultName COLLATE Latin1_General_100_BIN2) AS rn FROM #ExampleReplicaPartialContract) m WHERE rn=@MapCase+1;
    SET @SelectedMap=N'{"'+@ResultName+N'":"'+@TargetTable+N'"}';
   END
   ELSE SET @SelectedMap=CASE @MapCase
    WHEN 7 THEN N'{"moduleStatus":"#ExampleReplicaModuleStatusPartial","sourceStatus":"#ExampleReplicaSourceStatusPartial"}'
    ELSE N'{"replicas":"#ExampleReplicaReplicasPartial","warnings":"#ExampleReplicaWarningsPartial"}' END;
   DECLARE [Sentinels180] CURSOR LOCAL FAST_FORWARD FOR SELECT ResultName,TargetTable FROM #ExampleReplicaPartialContract;
   OPEN [Sentinels180];FETCH NEXT FROM [Sentinels180] INTO @ResultName,@TargetTable;
   WHILE @@FETCH_STATUS=0
   BEGIN
    IF NOT EXISTS(SELECT 1 FROM OPENJSON(@SelectedMap) WHERE [key]=@ResultName)
    BEGIN SET @Sql=N'INSERT '+QUOTENAME(@TargetTable)+N' VALUES(4242);';EXEC sys.sp_executesql @Sql;END;
    FETCH NEXT FROM [Sentinels180] INTO @ResultName,@TargetTable;
   END;
   CLOSE [Sentinels180];DEALLOCATE [Sentinels180];
   SELECT @Names=CASE WHEN @MapRun=0 THEN @MissingScope ELSE @AllNames END,@MaxRows=CASE WHEN @MapRun=0 THEN -1 ELSE 1 END,
    @From=CASE WHEN @MapRun=0 THEN DATEADD(HOUR,-1,@Now) ELSE @NativeFrom END,@To=CASE WHEN @MapRun=0 THEN @Now ELSE @NativeTo END;
   EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@Names,@VonUtc=@From,@BisUtc=@To,@MaxZeilen=@MaxRows,
    @ResultSetArt='TABLE',@ResultTablesJson=@SelectedMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
    @StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
   IF @@LOCK_TIMEOUT<>137 OR @OutStatus<>CASE WHEN @MapRun=0 THEN 'INVALID_PARAMETER' ELSE 'AVAILABLE' END
    OR @OutPartial<>CASE WHEN @MapRun=0 THEN 1 ELSE 0 END OR ISJSON(@Json)<>1
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.replicas'))<>@MapRun OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.runtimeByReplica'))<>@MapRun
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>10*@MapRun
    OR JSON_QUERY(@Json,N'$.waitsByReplica')<>N'[]' OR JSON_QUERY(@Json,N'$.forcingByReplica')<>N'[]' OR JSON_QUERY(@Json,N'$.warnings')<>N'[]'
    OR JSON_VALUE(@Json,N'$.meta.hasMoreReplicaRows')<>CASE WHEN @MapRun=0 THEN N'false' ELSE N'true' END
    OR JSON_VALUE(@Json,N'$.meta.hasMoreRuntimeRows')<>CASE WHEN @MapRun=0 THEN N'false' ELSE N'true' END
    OR JSON_VALUE(@Json,N'$.meta.hasMoreWaitRows')<>N'false' OR JSON_VALUE(@Json,N'$.meta.hasMoreForcingRows')<>N'false'
     THROW 58213,N'REPLICA_SELECTIVE_MAP_STATUS',1;
   DECLARE [Selective180] CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleReplicaPartialContract;
   OPEN [Selective180];FETCH NEXT FROM [Selective180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @Mapped=CASE WHEN EXISTS(SELECT 1 FROM OPENJSON(@SelectedMap) WHERE [key]=@ResultName) THEN 1 ELSE 0 END;
    IF @Mapped=0
    BEGIN
     IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable))<>1
      OR NOT EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable) AND name=N'Dummy') THROW 58214,N'REPLICA_UNREQUESTED_SCHEMA',1;
     SET @Sql=N'IF (SELECT COUNT(*) FROM '+QUOTENAME(@TargetTable)+N')<>1 OR EXISTS(SELECT 1 FROM '+QUOTENAME(@TargetTable)+N' WHERE Dummy<>4242 OR Dummy IS NULL) THROW 58214,N''REPLICA_UNREQUESTED_SENTINEL'',1;';
     EXEC sys.sp_executesql @Sql;
    END
    ELSE
    BEGIN
     IF EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
      FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable)
      EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
      FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable))
      OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
      FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@SchemaTable)
      EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,user_type_id,system_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
      FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@TargetTable)) THROW 58215,N'REPLICA_SELECTIVE_SCHEMA',1;
     SET @Sql=N'SELECT @j=(SELECT * FROM '+QUOTENAME(@TargetTable)+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
     EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@TableJson OUTPUT;
     SET @Array=JSON_QUERY(@Json,N'$.'+@ResultName);
     IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Array) GROUP BY value COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Array) GROUP BY value COLLATE Latin1_General_100_BIN2
      EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
       THROW 58216,N'REPLICA_SELECTIVE_JSON_FULL_VALUES',1;
    END;
    FETCH NEXT FROM [Selective180] INTO @ResultName,@SchemaTable,@TargetTable,@Fields,@Texts;
   END;
   CLOSE [Selective180];DEALLOCATE [Selective180];
   DROP TABLE #ExampleReplicaReplicasPartial;DROP TABLE #ExampleReplicaRuntimeByReplicaPartial;DROP TABLE #ExampleReplicaWaitsByReplicaPartial;
   DROP TABLE #ExampleReplicaForcingByReplicaPartial;DROP TABLE #ExampleReplicaSourceStatusPartial;DROP TABLE #ExampleReplicaWarningsPartial;DROP TABLE #ExampleReplicaModuleStatusPartial;
   IF @MapRun=0 SET @GeneralPartialMaps+=1;ELSE SET @NativePartialMaps+=1;
   SET @MapCase+=1;
  END;
  SET @MapRun+=1;
 END;
 -- Invalid parameters bypass candidate probes, allowing SQL capture of the actual 18-field CONSOLE row.
 SELECT TOP(0) CONVERT(nvarchar(200),NULL) COLLATE SQL_Latin1_General_CP1_CS_AS AS Ergebnis,* INTO #ExampleReplicaConsole FROM #ExampleReplicaModuleStatusSchema;
 DECLARE @ConsoleCase int=0;
 WHILE @ConsoleCase<3
 BEGIN
  TRUNCATE TABLE #ExampleReplicaConsole;
  SELECT @MaxRows=CASE WHEN @ConsoleCase=0 THEN -1 ELSE 0 END,@Lock=CASE WHEN @ConsoleCase=1 THEN -1 ELSE 0 END,
   @Groups=CASE WHEN @ConsoleCase=2 THEN N'ExampleInvalidNumber' ELSE NULL END;
  INSERT #ExampleReplicaConsole EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@MaxRows,
   @LockTimeoutMs=@Lock,@ReplicaGroupIds=@Groups,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
   @StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
  IF (SELECT COUNT(*) FROM #ExampleReplicaConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleReplicaConsole
   WHERE Ergebnis<>N'QueryStoreReplicaAnalysis' OR ModuleName<>N'USP_QueryStoreReplicaAnalysis' OR StatusCode<>'INVALID_PARAMETER' OR IsPartial<>1
    OR DatabaseCount<>0 OR ReplicaRowCount<>0 OR RuntimeRowCount<>0 OR WaitRowCount<>0 OR ForcingRowCount<>0
    OR HasMoreReplicaRows<>0 OR HasMoreRuntimeRows<>0 OR HasMoreWaitRows<>0 OR HasMoreForcingRows<>0 OR ErrorNumber IS NOT NULL OR ErrorMessage IS NULL)
   OR @OutStatus<>'INVALID_PARAMETER' OR @OutPartial<>1 OR @@LOCK_TIMEOUT<>137 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>N'INVALID_PARAMETER'
    THROW 58217,N'REPLICA_INVALID_SQL_CONSOLE',1;
  SELECT @TableJson=(SELECT ModuleName,CapturedAtUtc,StatusCode,IsPartial,ProductMajorVersion,CrossDatabaseRequested,DatabaseCount,
   ReplicaRowCount,RuntimeRowCount,WaitRowCount,ForcingRowCount,HasMoreReplicaRows,HasMoreRuntimeRows,HasMoreWaitRows,HasMoreForcingRows,ErrorNumber,ErrorMessage
   FROM #ExampleReplicaConsole FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF @TableJson COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,N'$.moduleStatus') COLLATE Latin1_General_100_BIN2 THROW 58218,N'REPLICA_SQL_CONSOLE_JSON',1;
  SET @ConsoleCase+=1;SET @SqlConsoleCases+=1;
 END;
 IF @FixtureStatus='PENDING'
 BEGIN
  SET @ConsoleCase=0;
  WHILE @ConsoleCase<3
  BEGIN
   SET @MaxRows=CASE @ConsoleCase WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
   EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@AllNames,@VonUtc=@NativeFrom,@BisUtc=@NativeTo,@MaxZeilen=@MaxRows,
    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
   IF @OutStatus<>'AVAILABLE' OR @OutPartial<>0 OR @@LOCK_TIMEOUT<>137 OR ISJSON(@Json)<>1
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.replicas'))<>CASE WHEN @MaxRows=0 THEN 8 ELSE @MaxRows END
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.runtimeByReplica'))<>CASE WHEN @MaxRows=1 THEN 1 ELSE 2 END
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>10 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.moduleStatus'))<>1
     THROW 58219,N'REPLICA_DIRECT_CONSOLE_STATUS_JSON',1;
   SET @ConsoleCase+=1;SET @DirectConsoleCases+=1;
  END;
  IF @NativeCases<>18 OR @NativePartialMaps<>9 THROW 58220,N'REPLICA_NATIVE_CASE_COUNTS',1;
  SET @FixtureStatus='PASS';
 END;
 DECLARE @Consumer int=0,@Mode varchar(16),@ConsumerMap nvarchar(max);
 WHILE @Consumer<5
 BEGIN
  SELECT @Mode=CASE @Consumer WHEN 1 THEN 'RAW' WHEN 3 THEN 'UNSUPPORTED' ELSE 'NONE' END,
   @Generate=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END,@MaxRows=CASE WHEN @Consumer<2 THEN -1 ELSE 0 END,
   @ConsumerMap=CASE WHEN @Consumer=4 THEN N'{"moduleStatus":"#ExampleReplicaPreflight"}' ELSE NULL END;
  SET @Json=N'ExamplePreviousJson';
  EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=@MaxRows,@ResultSetArt=@Mode,
   @ResultTablesJson=@ConsumerMap,@JsonErzeugen=@Generate,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@OutStatus OUTPUT,@IsPartialOut=@OutPartial OUTPUT;
  IF @@LOCK_TIMEOUT<>137 OR (@Consumer<>2 AND (@OutStatus<>'INVALID_PARAMETER' OR @OutPartial<>1 OR ISJSON(@Json)<>1
   OR JSON_VALUE(@Json,N'$.meta.requestedMaxRows')<>CONVERT(nvarchar(12),@MaxRows) OR JSON_VALUE(@Json,N'$.meta.hasMoreReplicaRows')<>N'false'
   OR JSON_VALUE(@Json,N'$.meta.hasMoreRuntimeRows')<>N'false' OR JSON_VALUE(@Json,N'$.meta.hasMoreWaitRows')<>N'false'
   OR JSON_VALUE(@Json,N'$.meta.hasMoreForcingRows')<>N'false' OR JSON_QUERY(@Json,N'$.replicas')<>N'[]' OR JSON_QUERY(@Json,N'$.runtimeByReplica')<>N'[]'))
   OR (@Consumer=2 AND (@Json IS NOT NULL OR @OutStatus<>CASE WHEN @Major IS NULL OR @Major<17 THEN 'UNAVAILABLE_VERSION' ELSE 'AVAILABLE_LIMITED' END OR @OutPartial<>1))
    THROW 58221,N'REPLICA_CONSUMER',1;
  SET @Consumer+=1;SET @ConsumerCases+=1;
 END;
 DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
 WHILE @Preflight<6
 BEGIN
  SET @BadMap=CASE @Preflight WHEN 0 THEN N'{}' WHEN 1 THEN N'{"unknown":"#ExampleReplicaPreflight"}'
   WHEN 2 THEN N'{"moduleStatus":"#ExampleMissingTarget180"}' WHEN 3 THEN N'{"moduleStatus":"ExamplePermanent"}'
   WHEN 4 THEN N'{"moduleStatus":"#ExampleReplicaPreflight","replicas":"#ExampleReplicaPreflight"}' ELSE N'{"moduleStatus":1}' END;
  SET @Caught=0;
  BEGIN TRY
   EXEC monitor.USP_QueryStoreReplicaAnalysis @QueryStoreDatabaseNames=@MissingScope,@MaxZeilen=-1,
    @ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
  END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
  IF @Caught<>51011 OR @@LOCK_TIMEOUT<>137 OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleReplicaPreflight'))<>1
   OR EXISTS(SELECT 1 FROM #ExampleReplicaPreflight) THROW 58222,N'REPLICA_MAPPING_PREFLIGHT',1;
  SET @Preflight+=1;SET @PreflightCases+=1;
 END;
 IF @CoreCases<>14 OR @GeneralPartialMaps<>9 OR @SqlConsoleCases<>3 OR @ConsumerCases<>5 OR @PreflightCases<>6 THROW 58223,N'REPLICA_CORE_COUNTS',1;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 SELECT 'PASS' AS ContractStatus,@FrameworkLevel AS FrameworkCompatibilityLevel,
  (SELECT [Level] FROM #ExampleReplicaOptions WHERE DatabaseName=@UpperName) AS UpperSourceCompatibilityLevel,
  (SELECT [Level] FROM #ExampleReplicaOptions WHERE DatabaseName=@LowerName) AS LowerSourceCompatibilityLevel,
  105 AS SchemaFields,45 AS SchemaTextFields,@CoreCases AS CoreCases,@GeneralPartialMaps AS GeneralSelectiveTableCases,
  @ConsumerCases AS ConsumerCases,@PreflightCases AS PreflightCases,@SqlConsoleCases AS InvalidSqlConsoleCases,
  @FixtureStatus AS PositiveFixtureStatus,@NativeCases AS NativeCases,@NativePartialMaps AS NativeSelectiveTableCases,@DirectConsoleCases AS DirectConsoleStatusJsonCases;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLockTimeout)+N';';EXEC sys.sp_executesql @Sql;
 THROW;
END CATCH;
GO
