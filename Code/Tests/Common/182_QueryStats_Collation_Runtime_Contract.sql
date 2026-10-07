USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/* P3: Unabhängiger QueryStats-Vertrag mit 60 TABLE-Feldern, 59 JSON-Feldern
   und fünf Textcollations. Allgemeine Leerscopes belegen ABI und Akzeptanz,
   keine positive Rang-/Limitwirkung. Der optionale native Block liest nur
   die vorbereitete eigene ExampleStats-Fixture und erzeugt keinen Workload.
   Ein einmaliger Cache-/Text-/Attributstand ist keine atomare DMV-Messung;
   Eviction und Änderungen während des Aufrufs bleiben eine Evidenzgrenze.
   Bestehende Rangties erlauben verschiedene Auswahlen zwischen Aufrufen.
   Dieser Test erzeugt keinen Parent-Snapshot und ändert keine Fixture. */
SET NOCOUNT ON;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 58400,N'QUERY_STATS_FRAMEWORK_COLLATION',1;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
 @CallerLockTimeout int=@@LOCK_TIMEOUT;
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
 THROW 58400,N'QUERY_STATS_FRAMEWORK_LEVEL',1;
CREATE TABLE #ExampleStatsSchema
(
 [QueryHash] binary(8) NULL,
 [QueryPlanHash] binary(8) NULL,
 [PlanHandle] varbinary(64) NOT NULL,
 [SqlHandle] varbinary(64) NOT NULL,
 [StatementStartOffset] int NOT NULL,
 [StatementEndOffset] int NOT NULL,
 [PlanGenerationNumber] bigint NOT NULL,
 [DatabaseId] int NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ObjectId] int NULL,
 [StatementTextCharacters] bigint NULL,
 [StatementTextBytes] bigint NULL,
 [StatementTextIsTruncated] bit NOT NULL,
 [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [BatchTextCharacters] bigint NULL,
 [BatchTextBytes] bigint NULL,
 [BatchTextIsTruncated] bit NOT NULL,
 [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [CreationTime] datetime NOT NULL,
 [LastExecutionTime] datetime NOT NULL,
 [ExecutionCount] bigint NOT NULL,
 [TotalCpuMs] decimal(38,3) NULL,
 [LastCpuMs] decimal(38,3) NULL,
 [MinCpuMs] decimal(38,3) NULL,
 [MaxCpuMs] decimal(38,3) NULL,
 [AvgCpuMs] decimal(38,3) NULL,
 [TotalElapsedMs] decimal(38,3) NULL,
 [LastElapsedMs] decimal(38,3) NULL,
 [MinElapsedMs] decimal(38,3) NULL,
 [MaxElapsedMs] decimal(38,3) NULL,
 [AvgElapsedMs] decimal(38,3) NULL,
 [TotalLogicalReads] bigint NOT NULL,
 [LastLogicalReads] bigint NOT NULL,
 [AvgLogicalReads] decimal(38,3) NULL,
 [TotalLogicalWrites] bigint NOT NULL,
 [LastLogicalWrites] bigint NOT NULL,
 [AvgLogicalWrites] decimal(38,3) NULL,
 [TotalPhysicalReads] bigint NOT NULL,
 [LastPhysicalReads] bigint NOT NULL,
 [TotalRows] bigint NOT NULL,
 [LastRows] bigint NOT NULL,
 [MinRows] bigint NOT NULL,
 [MaxRows] bigint NOT NULL,
 [LastDop] bigint NOT NULL,
 [MinDop] bigint NOT NULL,
 [MaxDop] bigint NOT NULL,
 [MaxGrantKb] bigint NOT NULL,
 [LastGrantKb] bigint NOT NULL,
 [LastUsedGrantKb] bigint NOT NULL,
 [LastIdealGrantKb] bigint NOT NULL,
 [TotalSpilledPages] bigint NOT NULL,
 [LastSpilledPages] bigint NOT NULL,
 [CacheObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PlanUseCounts] int NULL,
 [PlanSizeBytes] bigint NULL,
 [ResourcePoolId] int NULL,
 [SetOptions] int NULL,
 [CompileUserId] int NULL,
 [SortValue] decimal(38,4) NULL
);
SELECT * INTO #ExampleStatsExpected FROM #ExampleStatsSchema;
CREATE TABLE #ExampleStatsNative
(
 [sql_handle] varbinary(64) NULL,
 [statement_start_offset] int NULL,
 [statement_end_offset] int NULL,
 [plan_generation_num] bigint NULL,
 [plan_handle] varbinary(64) NULL,
 [creation_time] datetime NULL,
 [last_execution_time] datetime NULL,
 [execution_count] bigint NULL,
 [total_worker_time] bigint NULL,
 [last_worker_time] bigint NULL,
 [min_worker_time] bigint NULL,
 [max_worker_time] bigint NULL,
 [total_physical_reads] bigint NULL,
 [last_physical_reads] bigint NULL,
 [total_logical_writes] bigint NULL,
 [last_logical_writes] bigint NULL,
 [total_logical_reads] bigint NULL,
 [last_logical_reads] bigint NULL,
 [total_elapsed_time] bigint NULL,
 [last_elapsed_time] bigint NULL,
 [min_elapsed_time] bigint NULL,
 [max_elapsed_time] bigint NULL,
 [query_hash] binary(8) NULL,
 [query_plan_hash] binary(8) NULL,
 [total_rows] bigint NULL,
 [last_rows] bigint NULL,
 [min_rows] bigint NULL,
 [max_rows] bigint NULL,
 [last_dop] bigint NULL,
 [min_dop] bigint NULL,
 [max_dop] bigint NULL,
 [max_grant_kb] bigint NULL,
 [last_grant_kb] bigint NULL,
 [last_used_grant_kb] bigint NULL,
 [last_ideal_grant_kb] bigint NULL,
 [total_spills] bigint NULL,
 [last_spills] bigint NULL,
 [TextDatabaseId] int NULL,
 [TextObjectId] int NULL,
 [NativeBatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PlanDatabaseId] int NULL,
 [NativeCacheObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [NativeObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [NativePlanUseCounts] int NULL,
 [NativePlanSizeBytes] bigint NULL,
 [NativeResourcePoolId] int NULL,
 [NativeSetOptions] int NULL,
 [NativeCompileUserId] int NULL
);
CREATE TABLE #ExampleStatsEligible(JsonValue nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
 JsonPublic nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,SortRank bigint NOT NULL);
CREATE TABLE #ExampleStatsCases
(CaseNumber int PRIMARY KEY,IsNative bit NOT NULL,SortOrder varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 RowLimit int NULL,TextLimit int NULL,MinExecutions bigint NULL,AnalysisMode varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 ParentSnapshot bit NULL,JsonBit bit NULL,ExactQueryHash binary(8) NULL,ExactPlanHash binary(8) NULL,
 ExactSqlHandle varbinary(64) NULL,ExactPlanHandle varbinary(64) NULL,SinceUtc datetime2(7) NULL,
 ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT #ExampleStatsCases VALUES
 (0,0,'CPU_TOTAL',NULL,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (1,0,'CPU_TOTAL',0,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (2,0,'CPU_TOTAL',1,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (3,0,'CPU_TOTAL',2,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (4,0,'CPU_TOTAL',-1,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (5,0,'CPU_TOTAL',1,-1,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (6,0,'CPU_TOTAL',1,4000,-1,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (7,0,'CPU_TOTAL',1,4000,9223372036854775807,'BAD',0,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (8,0,'BAD',1,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (9,0,'CPU_TOTAL',1,4000,9223372036854775807,'TOP',NULL,1,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (10,0,'CPU_TOTAL',1,4000,9223372036854775807,'TOP',0,NULL,NULL,NULL,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (11,0,'CPU_TOTAL',1,4000,NULL,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (12,0,'CPU_TOTAL',1,NULL,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (13,0,'CPU_TOTAL',1,0,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (14,0,'CPU_TOTAL',1,4000,9223372036854775807,NULL,0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
 (15,0,NULL,1,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE');
INSERT #ExampleStatsCases SELECT 20+v.n,0,v.s,1,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'
 FROM (VALUES (0,'CPU_TOTAL'),(1,'CPU_AVG'),(2,'ELAPSED_TOTAL'),(3,'ELAPSED_AVG'),(4,'READS_TOTAL'),(5,'READS_AVG'),(6,'WRITES_TOTAL'),(7,'WRITES_AVG'),(8,'EXECUTIONS'),(9,'GRANT_MAX'),(10,'SPILLS_TOTAL'),(11,'ROWS_TOTAL'),(12,'LAST_EXECUTION'))v(n,s);
IF EXISTS(SELECT 1 FROM sys.dm_exec_query_stats WHERE execution_count=9223372036854775807)
 THROW 58400,N'QUERY_STATS_EMPTY_SCOPE_PRECONDITION',1;
DECLARE @NativeFixtureStatus varchar(20)='NOT_EXECUTED',@NativeDatabase sysname=N'ExampleStatsÄ🔬',
 @NativeLevel int=NULL,@NativeObjects int=0,@NativeOptions int=0,@NativeTableRows bigint=NULL,
 @NativeDatabaseId int=DB_ID(N'ExampleStatsÄ🔬'),@NativeEligibleRows bigint=NULL,@Sql nvarchar(max);
IF @FrameworkLevel=170 AND @NativeDatabaseId IS NOT NULL
 AND EXISTS(SELECT 1 FROM sys.databases WHERE database_id=@NativeDatabaseId
  AND name COLLATE SQL_Latin1_General_CP1_CS_AS=@NativeDatabase COLLATE SQL_Latin1_General_CP1_CS_AS
  AND collation_name IN(N'SQL_Latin1_General_CP1_CI_AS',N'Latin1_General_100_CI_AS')
  AND compatibility_level=170 AND is_query_store_on=0 AND is_read_only=0)
BEGIN
 SET @Sql=N'USE '+QUOTENAME(@NativeDatabase)+N';
 SELECT @l=compatibility_level FROM sys.databases WHERE database_id=DB_ID();
 SELECT @o=COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID(N''dbo'')
  AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N''ExampleSumÄ🔬'',N''ExampleCountÄ🔬'',N''ExampleRowsÄ🔬'');
 SELECT @m=COUNT(*) FROM sys.sql_modules WHERE object_id IN(OBJECT_ID(N''dbo.[ExampleSumÄ🔬]''),
  OBJECT_ID(N''dbo.[ExampleCountÄ🔬]''),OBJECT_ID(N''dbo.[ExampleRowsÄ🔬]'')) AND uses_quoted_identifier=1 AND uses_ansi_nulls=1;
 IF OBJECT_ID(N''dbo.ExampleValues'',N''U'') IS NOT NULL SELECT @r=COUNT_BIG(*) FROM dbo.ExampleValues;';
 EXEC sys.sp_executesql @Sql,N'@l int OUTPUT,@o int OUTPUT,@m int OUTPUT,@r bigint OUTPUT',
  @l=@NativeLevel OUTPUT,@o=@NativeObjects OUTPUT,@m=@NativeOptions OUTPUT,@r=@NativeTableRows OUTPUT;
 IF @NativeLevel=170 AND @NativeObjects=3 AND @NativeOptions=3 AND @NativeTableRows=4
 BEGIN
  SET @Sql=N'USE '+QUOTENAME(@NativeDatabase)+N';
  SELECT @e=COUNT_BIG(*) FROM sys.dm_exec_query_stats q CROSS APPLY sys.dm_exec_sql_text(q.sql_handle)t
  OUTER APPLY(SELECT TOP(1) TRY_CONVERT(int,value) DatabaseId FROM sys.dm_exec_plan_attributes(q.plan_handle) WHERE attribute=''dbid'')dbp
  WHERE COALESCE(t.dbid,dbp.DatabaseId)=DB_ID()
   AND t.text COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N''%CREATE PROCEDURE dbo.[[]Example%'';
  INSERT #ExampleStatsNative SELECT q.[sql_handle],q.[statement_start_offset],q.[statement_end_offset],q.[plan_generation_num],q.[plan_handle],q.[creation_time],q.[last_execution_time],q.[execution_count],q.[total_worker_time],q.[last_worker_time],q.[min_worker_time],q.[max_worker_time],q.[total_physical_reads],q.[last_physical_reads],q.[total_logical_writes],q.[last_logical_writes],q.[total_logical_reads],q.[last_logical_reads],q.[total_elapsed_time],q.[last_elapsed_time],q.[min_elapsed_time],q.[max_elapsed_time],q.[query_hash],q.[query_plan_hash],q.[total_rows],q.[last_rows],q.[min_rows],q.[max_rows],q.[last_dop],q.[min_dop],q.[max_dop],q.[max_grant_kb],q.[last_grant_kb],q.[last_used_grant_kb],q.[last_ideal_grant_kb],q.[total_spills],q.[last_spills],t.dbid,t.objectid,t.text,dbp.DatabaseId,
   c.cacheobjtype,c.objtype,c.usecounts,c.size_in_bytes,c.pool_id,TRY_CONVERT(int,so.value),TRY_CONVERT(int,cu.value)
  FROM sys.dm_exec_query_stats q CROSS APPLY sys.dm_exec_sql_text(q.sql_handle)t
  LEFT JOIN sys.dm_exec_cached_plans c ON c.plan_handle=q.plan_handle
  OUTER APPLY(SELECT TOP(1) TRY_CONVERT(int,value) DatabaseId FROM sys.dm_exec_plan_attributes(q.plan_handle) WHERE attribute=''dbid'')dbp
  OUTER APPLY(SELECT TOP(1) value FROM sys.dm_exec_plan_attributes(q.plan_handle) WHERE attribute=''set_options'')so
  OUTER APPLY(SELECT TOP(1) value FROM sys.dm_exec_plan_attributes(q.plan_handle) WHERE attribute=''user_id'')cu
  WHERE COALESCE(t.dbid,dbp.DatabaseId)=DB_ID()
   AND t.objectid IN(OBJECT_ID(N''dbo.[ExampleSumÄ🔬]''),OBJECT_ID(N''dbo.[ExampleCountÄ🔬]''),OBJECT_ID(N''dbo.[ExampleRowsÄ🔬]''))
   AND t.text COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N''%CREATE PROCEDURE dbo.[[]Example%'';';
  EXEC sys.sp_executesql @Sql,N'@e bigint OUTPUT',@e=@NativeEligibleRows OUTPUT;
  IF @NativeEligibleRows=3 AND (SELECT COUNT(*) FROM #ExampleStatsNative)=3 AND (SELECT COUNT(DISTINCT TextObjectId) FROM #ExampleStatsNative)=3
   AND NOT EXISTS(SELECT 1 FROM #ExampleStatsNative WHERE execution_count<=0 OR NativeBatchText IS NULL
    OR statement_start_offset<0 OR statement_start_offset%2<>0 OR statement_end_offset IS NULL
    OR statement_end_offset<>-1 AND(statement_end_offset<statement_start_offset OR statement_end_offset%2<>0))
  BEGIN
   SET @NativeFixtureStatus='PASS';
   INSERT #ExampleStatsCases SELECT 100+v.n,1,'CPU_TOTAL',v.l,4000,0,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'
    FROM(VALUES(0,CONVERT(int,NULL)),(1,0),(2,1),(3,2))v(n,l);
   INSERT #ExampleStatsCases SELECT 110+v.n,1,v.s,1,4000,0,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'
    FROM(VALUES (0,'CPU_TOTAL'),(1,'CPU_AVG'),(2,'ELAPSED_TOTAL'),(3,'ELAPSED_AVG'),(4,'READS_TOTAL'),(5,'READS_AVG'),(6,'WRITES_TOTAL'),(7,'WRITES_AVG'),(8,'EXECUTIONS'),(9,'GRANT_MAX'),(10,'SPILLS_TOTAL'),(11,'ROWS_TOTAL'),(12,'LAST_EXECUTION'))v(n,s);
   INSERT #ExampleStatsCases VALUES
    (130,1,'CPU_TOTAL',0,5,0,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (131,1,'CPU_TOTAL',0,NULL,0,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (132,1,'CPU_TOTAL',0,0,0,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (133,1,'CPU_TOTAL',0,4000,NULL,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (134,1,'CPU_TOTAL',0,4000,3,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (135,1,'CPU_TOTAL',0,4000,9223372036854775807,'TOP',0,1,NULL,NULL,NULL,NULL,NULL,'AVAILABLE'),
    (136,1,'CPU_TOTAL',0,4000,0,'TOP',0,1,NULL,NULL,NULL,NULL,'99991231','AVAILABLE');
   INSERT #ExampleStatsCases SELECT 137,1,'CPU_TOTAL',0,4000,0,'TOP',0,1,query_hash,NULL,NULL,NULL,NULL,'AVAILABLE'
    FROM #ExampleStatsNative WHERE TextObjectId=(SELECT MIN(TextObjectId) FROM #ExampleStatsNative);
   INSERT #ExampleStatsCases SELECT 138,1,'CPU_TOTAL',0,4000,0,'TOP',0,1,NULL,query_plan_hash,NULL,NULL,NULL,'AVAILABLE'
    FROM #ExampleStatsNative WHERE TextObjectId=(SELECT MIN(TextObjectId) FROM #ExampleStatsNative);
   INSERT #ExampleStatsCases SELECT 139,1,'CPU_TOTAL',0,4000,0,'TOP',0,1,NULL,NULL,sql_handle,NULL,NULL,'AVAILABLE'
    FROM #ExampleStatsNative WHERE TextObjectId=(SELECT MIN(TextObjectId) FROM #ExampleStatsNative);
   INSERT #ExampleStatsCases SELECT 140,1,'CPU_TOTAL',0,4000,0,'TOP',0,1,NULL,NULL,NULL,plan_handle,NULL,'AVAILABLE'
    FROM #ExampleStatsNative WHERE TextObjectId=(SELECT MIN(TextObjectId) FROM #ExampleStatsNative);
  END;
 END;
END;
DECLARE @Case int,@Native bit,@Sort varchar(32),@Limit int,@TextLimit int,@MinExec bigint,@Mode varchar(16),
 @Parent bit,@JsonBit bit,@Hash binary(8),@PlanHash binary(8),@SqlHandle varbinary(64),@PlanHandle varbinary(64),
 @Since datetime2(7),@Status varchar(40),@Json nvarchar(max),@TableJson nvarchar(max),@DataJson nvarchar(max),
 @PublicTableJson nvarchar(max),@SafeLimit bigint,@Rows bigint,@FullRows bigint,@BoundaryRank bigint,
 @ExpectedSort varchar(32),@DatabaseNames nvarchar(max),@TextPattern nvarchar(4000),@Before datetime2(3),@After datetime2(3),
 @CoreCases int=0,@NativeCases int=0;
DECLARE cases CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleStatsCases ORDER BY CaseNumber;
OPEN cases;
FETCH NEXT FROM cases INTO @Case,@Native,@Sort,@Limit,@TextLimit,@MinExec,@Mode,@Parent,@JsonBit,@Hash,@PlanHash,@SqlHandle,@PlanHandle,@Since,@Status;
WHILE @@FETCH_STATUS=0
BEGIN
 TRUNCATE TABLE #ExampleStatsExpected;
 TRUNCATE TABLE #ExampleStatsEligible;
 SET @SafeLimit=CASE WHEN @Limit IS NULL OR @Limit=0 THEN 9223372036854775807 WHEN @Limit<0 THEN 0 ELSE @Limit END;
 SET @ExpectedSort=COALESCE(@Sort,'CPU_TOTAL');
 SET @DatabaseNames=QUOTENAME(CASE WHEN @Native=1 THEN @NativeDatabase ELSE DB_NAME() END);
 SET @TextPattern=CASE WHEN @Native=1 THEN N'like:%CREATE PROCEDURE dbo.[[]Example%' ELSE NULL END;
 IF @Native=1
 BEGIN
  INSERT #ExampleStatsExpected
  SELECT n.query_hash,n.query_plan_hash,n.plan_handle,n.sql_handle,n.statement_start_offset,n.statement_end_offset,n.plan_generation_num,
   COALESCE(n.TextDatabaseId,n.PlanDatabaseId),@NativeDatabase,n.TextObjectId,
   CONVERT(bigint,LEN(x.StatementText COLLATE Latin1_General_100_CI_AS_SC+N'.')-1),DATALENGTH(x.StatementText),
   CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN(x.StatementText COLLATE Latin1_General_100_CI_AS_SC+N'.')-1>@TextLimit THEN 1 ELSE 0 END),
   CASE WHEN @TextLimit>0 THEN LEFT(x.StatementText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) ELSE x.StatementText END,
   CONVERT(bigint,LEN(n.NativeBatchText COLLATE Latin1_General_100_CI_AS_SC+N'.')-1),DATALENGTH(n.NativeBatchText),
   CONVERT(bit,CASE WHEN @TextLimit>0 AND LEN(n.NativeBatchText COLLATE Latin1_General_100_CI_AS_SC+N'.')-1>@TextLimit THEN 1 ELSE 0 END),
   CASE WHEN @TextLimit>0 THEN LEFT(n.NativeBatchText COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) ELSE n.NativeBatchText END,
   n.creation_time,n.last_execution_time,n.execution_count,
   CONVERT(decimal(38,3),n.total_worker_time/1000.0),CONVERT(decimal(38,3),n.last_worker_time/1000.0),
   CONVERT(decimal(38,3),n.min_worker_time/1000.0),CONVERT(decimal(38,3),n.max_worker_time/1000.0),
   CONVERT(decimal(38,3),(n.total_worker_time/NULLIF(n.execution_count,0))/1000.0),
   CONVERT(decimal(38,3),n.total_elapsed_time/1000.0),CONVERT(decimal(38,3),n.last_elapsed_time/1000.0),
   CONVERT(decimal(38,3),n.min_elapsed_time/1000.0),CONVERT(decimal(38,3),n.max_elapsed_time/1000.0),
   CONVERT(decimal(38,3),(n.total_elapsed_time/NULLIF(n.execution_count,0))/1000.0),
   n.total_logical_reads,n.last_logical_reads,CONVERT(decimal(38,3),n.total_logical_reads*1.0/NULLIF(n.execution_count,0)),
   n.total_logical_writes,n.last_logical_writes,CONVERT(decimal(38,3),n.total_logical_writes*1.0/NULLIF(n.execution_count,0)),
   n.total_physical_reads,n.last_physical_reads,n.total_rows,n.last_rows,n.min_rows,n.max_rows,n.last_dop,n.min_dop,n.max_dop,
   n.max_grant_kb,n.last_grant_kb,n.last_used_grant_kb,n.last_ideal_grant_kb,n.total_spills,n.last_spills,
   n.NativeCacheObjectType,n.NativeObjectType,n.NativePlanUseCounts,n.NativePlanSizeBytes,n.NativeResourcePoolId,n.NativeSetOptions,n.NativeCompileUserId,
   CONVERT(decimal(38,4),CASE COALESCE(@Sort,'CPU_TOTAL') WHEN 'CPU_TOTAL' THEN total_worker_time WHEN 'CPU_AVG' THEN total_worker_time*1.0/NULLIF(execution_count,0) WHEN 'ELAPSED_TOTAL' THEN total_elapsed_time WHEN 'ELAPSED_AVG' THEN total_elapsed_time*1.0/NULLIF(execution_count,0) WHEN 'READS_TOTAL' THEN total_logical_reads WHEN 'READS_AVG' THEN total_logical_reads*1.0/NULLIF(execution_count,0) WHEN 'WRITES_TOTAL' THEN total_logical_writes WHEN 'WRITES_AVG' THEN total_logical_writes*1.0/NULLIF(execution_count,0) WHEN 'EXECUTIONS' THEN execution_count WHEN 'GRANT_MAX' THEN max_grant_kb WHEN 'SPILLS_TOTAL' THEN total_spills WHEN 'ROWS_TOTAL' THEN total_rows WHEN 'LAST_EXECUTION' THEN DATEDIFF_BIG(MILLISECOND,'20000101',last_execution_time) END)
  FROM #ExampleStatsNative n CROSS APPLY(SELECT SUBSTRING(n.NativeBatchText,n.statement_start_offset/2+1,
   (CASE WHEN n.statement_end_offset=-1 THEN DATALENGTH(n.NativeBatchText) ELSE n.statement_end_offset END-n.statement_start_offset)/2+1))x(StatementText)
  WHERE n.execution_count>=@MinExec AND(@Since IS NULL OR n.last_execution_time>=@Since)
   AND(@Hash IS NULL OR n.query_hash=@Hash) AND(@PlanHash IS NULL OR n.query_plan_hash=@PlanHash)
   AND(@SqlHandle IS NULL OR n.sql_handle=@SqlHandle) AND(@PlanHandle IS NULL OR n.plan_handle=@PlanHandle);
 END;
 SET @FullRows=(SELECT COUNT_BIG(*) FROM #ExampleStatsExpected);
 SET @Rows=CASE WHEN @FullRows>@SafeLimit THEN @SafeLimit ELSE @FullRows END;
 INSERT #ExampleStatsEligible SELECT (SELECT e.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
  (SELECT e.[QueryHash],e.[QueryPlanHash],e.[PlanHandle],e.[SqlHandle],e.[StatementStartOffset],e.[StatementEndOffset],e.[PlanGenerationNumber],e.[DatabaseId],e.[DatabaseName],e.[ObjectId],e.[StatementTextCharacters],e.[StatementTextBytes],e.[StatementTextIsTruncated],e.[StatementText],e.[BatchTextCharacters],e.[BatchTextBytes],e.[BatchTextIsTruncated],e.[BatchText],e.[CreationTime],e.[LastExecutionTime],e.[ExecutionCount],e.[TotalCpuMs],e.[LastCpuMs],e.[MinCpuMs],e.[MaxCpuMs],e.[AvgCpuMs],e.[TotalElapsedMs],e.[LastElapsedMs],e.[MinElapsedMs],e.[MaxElapsedMs],e.[AvgElapsedMs],e.[TotalLogicalReads],e.[LastLogicalReads],e.[AvgLogicalReads],e.[TotalLogicalWrites],e.[LastLogicalWrites],e.[AvgLogicalWrites],e.[TotalPhysicalReads],e.[LastPhysicalReads],e.[TotalRows],e.[LastRows],e.[MinRows],e.[MaxRows],e.[LastDop],e.[MinDop],e.[MaxDop],e.[MaxGrantKb],e.[LastGrantKb],e.[LastUsedGrantKb],e.[LastIdealGrantKb],e.[TotalSpilledPages],e.[LastSpilledPages],e.[CacheObjectType],e.[ObjectType],e.[PlanUseCounts],e.[PlanSizeBytes],e.[ResourcePoolId],e.[SetOptions],e.[CompileUserId] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
  RANK()OVER(ORDER BY SortValue DESC,LastExecutionTime DESC) FROM #ExampleStatsExpected e;
 SET @BoundaryRank=(SELECT MAX(SortRank) FROM #ExampleStatsEligible WHERE SortRank<=@SafeLimit);
 CREATE TABLE #ExampleStatsTarget(Dummy int NULL);
 SET @Before=SYSUTCDATETIME();
 EXEC monitor.USP_QueryStats @DatabaseNames=@DatabaseNames,@TextPattern=@TextPattern,@Sortierung=@Sort,
  @AnalyseModus=@Mode,@MinExecutionCount=@MinExec,@MaxZeilen=@Limit,@MaxSqlTextZeichen=@TextLimit,
  @ParentQueryStatsSnapshot=@Parent,@QueryHash=@Hash,@QueryPlanHash=@PlanHash,@SqlHandle=@SqlHandle,@PlanHandle=@PlanHandle,
  @VonUtc=@Since,@HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"queries":"#ExampleStatsTarget"}',
  @JsonErzeugen=@JsonBit,@Json=@Json OUTPUT,@PrintMeldungen=0;
 SET @After=SYSUTCDATETIME();
 IF @@LOCK_TIMEOUT<>@CallerLockTimeout THROW 58401,N'QUERY_STATS_CALLER_LOCK_TIMEOUT',1;
 IF EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatsSchema') EXCEPT
   SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatsTarget'))
  OR EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatsTarget') EXCEPT
   SELECT ROW_NUMBER()OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatsSchema'))
  THROW 58402,N'QUERY_STATS_SCHEMA',1;
 EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleStatsTarget FOR JSON PATH,INCLUDE_NULL_VALUES);
  SELECT @p=(SELECT [QueryHash],[QueryPlanHash],[PlanHandle],[SqlHandle],[StatementStartOffset],[StatementEndOffset],[PlanGenerationNumber],[DatabaseId],[DatabaseName],[ObjectId],[StatementTextCharacters],[StatementTextBytes],[StatementTextIsTruncated],[StatementText],[BatchTextCharacters],[BatchTextBytes],[BatchTextIsTruncated],[BatchText],[CreationTime],[LastExecutionTime],[ExecutionCount],[TotalCpuMs],[LastCpuMs],[MinCpuMs],[MaxCpuMs],[AvgCpuMs],[TotalElapsedMs],[LastElapsedMs],[MinElapsedMs],[MaxElapsedMs],[AvgElapsedMs],[TotalLogicalReads],[LastLogicalReads],[AvgLogicalReads],[TotalLogicalWrites],[LastLogicalWrites],[AvgLogicalWrites],[TotalPhysicalReads],[LastPhysicalReads],[TotalRows],[LastRows],[MinRows],[MaxRows],[LastDop],[MinDop],[MaxDop],[MaxGrantKb],[LastGrantKb],[LastUsedGrantKb],[LastIdealGrantKb],[TotalSpilledPages],[LastSpilledPages],[CacheObjectType],[ObjectType],[PlanUseCounts],[PlanSizeBytes],[ResourcePoolId],[SetOptions],[CompileUserId] FROM #ExampleStatsTarget FOR JSON PATH,INCLUDE_NULL_VALUES);',
  N'@j nvarchar(max) OUTPUT,@p nvarchar(max) OUTPUT',@j=@TableJson OUTPUT,@p=@PublicTableJson OUTPUT;
 IF @JsonBit IS NULL
 BEGIN
  IF @Json IS NOT NULL OR EXISTS(SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]')))
   THROW 58403,N'QUERY_STATS_NULL_JSON_BIT',1;
 END
 ELSE
 BEGIN
  IF ISJSON(@Json)<>1 OR(SELECT COUNT(*) FROM OPENJSON(@Json))<>3
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json) EXCEPT SELECT v.k FROM(VALUES(N'meta'),(N'queries'),(N'warnings'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE [key] WHEN N'meta' THEN 5 ELSE 4 END)
   OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>10
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT v.k FROM(VALUES(N'resultName'),(N'schemaVersion'),
    (N'generatedAtUtc'),(N'statusCode'),(N'requestedMaxRows'),(N'returnedRows'),(N'hasMoreRows'),(N'sortBy'),(N'errorNumber'),(N'errorMessage'))v(k))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [type]<>CASE [key]
    WHEN N'schemaVersion' THEN 2 WHEN N'returnedRows' THEN 2 WHEN N'hasMoreRows' THEN 3
    WHEN N'requestedMaxRows' THEN CASE WHEN @Limit IS NULL THEN 0 ELSE 2 END WHEN N'errorNumber' THEN 0
    WHEN N'errorMessage' THEN CASE WHEN @Status='AVAILABLE' THEN 0 ELSE 1 END ELSE 1 END)
   OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'QueryStats'
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
   OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status OR JSON_VALUE(@Json,N'$.meta.sortBy')<>@ExpectedSort
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
   OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL
   OR(@Status='AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL)
   OR(@Status<>'AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NULL)
   OR(@Limit IS NULL AND JSON_VALUE(@Json,N'$.meta.requestedMaxRows') IS NOT NULL)
   OR(@Limit IS NOT NULL AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),-2147483648)<>@Limit)
   OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@Rows
   OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @FullRows>@SafeLimit THEN N'true' ELSE N'false' END
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings'))
   THROW 58403,N'QUERY_STATS_META',1;
  SET @DataJson=JSON_QUERY(@Json,N'$.queries');
  IF(SELECT COUNT_BIG(*) FROM OPENJSON(@DataJson))<>@Rows
   OR(SELECT COUNT_BIG(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')))<>@Rows
   THROW 58404,N'QUERY_STATS_COUNTS',1;
  IF EXISTS(SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]'))a WHERE NOT EXISTS
    (SELECT 1 FROM #ExampleStatsEligible e WHERE a.value COLLATE Latin1_General_100_BIN2=e.JsonValue AND e.SortRank<=@BoundaryRank))
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(COALESCE(@TableJson,N'[]'))
    GROUP BY value COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
   OR EXISTS(SELECT 1 FROM #ExampleStatsEligible e WHERE e.SortRank<@BoundaryRank AND NOT EXISTS
    (SELECT 1 FROM OPENJSON(COALESCE(@TableJson,N'[]'))a WHERE a.value COLLATE Latin1_General_100_BIN2=e.JsonValue))
   THROW 58405,N'QUERY_STATS_NATIVE_VALUES_RANK',1;
  IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@DataJson)
    GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT
    SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@PublicTableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(COALESCE(@PublicTableJson,N'[]'))
    GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT
    SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@DataJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT 1 FROM OPENJSON(@DataJson)a WHERE(SELECT COUNT(*) FROM OPENJSON(a.value))<>59
    OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
    OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT
     SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleStatsSchema') AND name<>N'SortValue'))
   OR EXISTS(SELECT 1 FROM(SELECT e.SortRank,LAG(e.SortRank)OVER(ORDER BY CONVERT(int,a.[key])) PreviousRank
     FROM OPENJSON(@DataJson)a JOIN #ExampleStatsEligible e ON a.value COLLATE Latin1_General_100_BIN2=e.JsonPublic)r WHERE r.SortRank<r.PreviousRank)
   THROW 58406,N'QUERY_STATS_JSON_VALUES_ORDER',1;
 END;
 DROP TABLE #ExampleStatsTarget;
 IF @Native=1 SET @NativeCases+=1; ELSE SET @CoreCases+=1;
 FETCH NEXT FROM cases INTO @Case,@Native,@Sort,@Limit,@TextLimit,@MinExec,@Mode,@Parent,@JsonBit,@Hash,@PlanHash,@SqlHandle,@PlanHandle,@Since,@Status;
END;
CLOSE cases; DEALLOCATE cases;
CREATE TABLE #ExampleStatsEmptyConsole(Ergebnis nvarchar(200),Status varchar(40),Hinweis nvarchar(2048));
DECLARE @EmptyCase int=0;
WHILE @EmptyCase<3
BEGIN
 TRUNCATE TABLE #ExampleStatsEmptyConsole;
 SET @Limit=CASE WHEN @EmptyCase=0 THEN -1 ELSE 1 END;
 SET @TextLimit=CASE WHEN @EmptyCase=1 THEN -1 ELSE 4000 END;
 INSERT #ExampleStatsEmptyConsole EXEC monitor.USP_QueryStats @DatabaseNames=@DatabaseNames,@MinExecutionCount=9223372036854775807,
  @MaxZeilen=@Limit,@MaxSqlTextZeichen=@TextLimit,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF(SELECT COUNT(*) FROM #ExampleStatsEmptyConsole)<>1
  OR EXISTS(SELECT 1 FROM #ExampleStatsEmptyConsole WHERE Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queries')) OR @@LOCK_TIMEOUT<>@CallerLockTimeout
  THROW 58407,N'QUERY_STATS_EMPTY_CONSOLE',1;
 SET @EmptyCase+=1;
END;
DECLARE @Consumer int=0,@OutputMode varchar(16);
WHILE @Consumer<3
BEGIN
 SET @OutputMode=CASE WHEN @Consumer=1 THEN ' rAw ' ELSE 'NONE' END;
 SET @JsonBit=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;
 SET @Json=N'{"ExampleStale":true}';
 EXEC monitor.USP_QueryStats @MaxZeilen=-1,@ResultSetArt=@OutputMode,@JsonErzeugen=@JsonBit,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF @JsonBit=0 AND @Json IS NOT NULL OR @JsonBit=1 AND(JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER'
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queries'))) OR @@LOCK_TIMEOUT<>@CallerLockTimeout
  THROW 58408,N'QUERY_STATS_CONSUMER',1;
 SET @Consumer+=1;
END;
CREATE TABLE #ExampleStatsPreflight(Dummy int NULL);
INSERT #ExampleStatsPreflight VALUES(4242);
DECLARE @Preflight int=0,@Map nvarchar(max),@Caught int;
WHILE @Preflight<6
BEGIN
 SET @Map=CASE @Preflight WHEN 0 THEN NULL WHEN 1 THEN N'{}' WHEN 2 THEN N'{"wrong":"#ExampleStatsPreflight"}'
  WHEN 3 THEN N'{"queries":"dbo.ExampleStatsPermanent"}' WHEN 4 THEN N'{"queries":"#ExampleStatsAbsent"}'
  ELSE N'{"queries":"#ExampleStatsPreflight"}' END;
 SET @OutputMode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
 SET @Caught=0;
 BEGIN TRY
  EXEC monitor.USP_QueryStats @MaxZeilen=-1,@ResultSetArt=@OutputMode,@ResultTablesJson=@Map,@PrintMeldungen=0;
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>51011 THROW;
  SET @Caught=1;
 END CATCH;
 IF @Caught<>1 OR(SELECT COUNT(*) FROM #ExampleStatsPreflight WHERE Dummy=4242)<>1
  THROW 58409,N'QUERY_STATS_PREFLIGHT',1;
 SET @Preflight+=1;
END;
DECLARE @MissingSnapshotStatus varchar(20)='NOT_EXECUTED';
IF OBJECT_ID(N'tempdb..#PlanCacheAnalysis_QueryStatsSnapshot') IS NULL
BEGIN
 EXEC monitor.USP_QueryStats @DatabaseNames=@DatabaseNames,@MinExecutionCount=9223372036854775807,@ParentQueryStatsSnapshot=1,
  @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF JSON_VALUE(@Json,N'$.meta.statusCode')<>'ERROR_HANDLED' OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.errorNumber'))<>208
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.queries')) THROW 58410,N'QUERY_STATS_MISSING_SNAPSHOT',1;
 SET @MissingSnapshotStatus='PASS';
END;
DECLARE @ConsoleNative int=0;
IF @NativeFixtureStatus='PASS'
BEGIN
 WHILE @ConsoleNative<3
 BEGIN
  SET @Limit=CASE @ConsoleNative WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
  EXEC monitor.USP_QueryStats @DatabaseNames=@DatabaseNames,@TextPattern=N'like:%CREATE PROCEDURE dbo.[[]Example%',@MaxZeilen=@Limit,
   @HighImpactConfirmed=1,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>'AVAILABLE' OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queries'))<>
   CASE WHEN @Limit=0 THEN 3 ELSE @Limit END OR @@LOCK_TIMEOUT<>@CallerLockTimeout
   THROW 58411,N'QUERY_STATS_DIRECT_CONSOLE',1;
  SET @ConsoleNative+=1;
 END;
END;
SELECT N'PASS' ContractStatus,@FrameworkLevel FrameworkCompatibilityLevel,@CoreCases CoreCases,
 @NativeFixtureStatus NativeFixtureStatus,@NativeLevel SourceCompatibilityLevel,@NativeCases NativeCases,
 60 TableFields,59 JsonFields,5 TextCollations,3 Consumers,6 Preflights,3 EmptySqlConsole,
 @ConsoleNative DirectNativeConsole,@MissingSnapshotStatus MissingSnapshotStatus;
GO
