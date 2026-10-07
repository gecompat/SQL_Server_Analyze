USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/* P3: CurrentMemoryGrants-Vertrag mit unabhängigen 63 Feldern und neun Textcollations.
   Allgemeine Leerscopes belegen Schema und Parameterakzeptanz, keine positive Limitwirkung.
   Der native Block ist ausschließlich über SESSION_CONTEXT(N'ExampleMemoryGrantSessionIds')
   als Pipe-Liste dreier vorbereiteter eigener Grant-Sessions aktiviert. Er liest nur
   ExampleGrantsÄ🔬 und die Anwendungen ExampleGrantÄ🔬1 bis 3; er erzeugt keinen Workload.
   Native Werte werden vor und nach jedem TABLE-Aufruf gemessen. Nichtnumerische Werte
   müssen in beiden Messungen identisch sein; andere numerische Werte liegen innerhalb
   der Messklammer. Neun globale Pool-/Semaphoreaggregate sind nichtmonoton und werden
   nur auf NULL-Form, JSON-Typ und numerische Lesbarkeit geprüft, ohne Werteparität oder
   Messklammerbehauptung. Dies ist kein atomarer Vollfeld-Punktvergleich flüchtiger DMVs.
   TABLE und JSON werden dagegen vollständig innerhalb desselben Aufrufs verglichen.
   Der Test erzeugt keinen Parent-Snapshot und verändert keine Fixture. */
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),
 @CallerLockTimeout int=@@LOCK_TIMEOUT;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
 OR @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
 THROW 58500,N'MEMORY_GRANTS_FRAMEWORK',1;
CREATE TABLE #ExampleGrantSchema
(
 [SessionId] smallint NULL,
 [RequestId] int NULL,
 [SchedulerId] int NULL,
 [Dop] smallint NULL,
 [RequestTime] datetime NULL,
 [GrantTime] datetime NULL,
 [WaitTimeMs] bigint NULL,
 [IsWaiting] bit NOT NULL,
 [IsSmall] bit NULL,
 [RequestedMemoryMb] decimal(19,2) NULL,
 [RequiredMemoryMb] decimal(19,2) NULL,
 [GrantedMemoryMb] decimal(19,2) NULL,
 [UsedMemoryMb] decimal(19,2) NULL,
 [MaxUsedMemoryMb] decimal(19,2) NULL,
 [IdealMemoryMb] decimal(19,2) NULL,
 [GroupId] int NULL,
 [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [PoolId] int NULL,
 [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ResourceSemaphoreId] smallint NULL,
 [RequestMaxMemoryGrantPercent] decimal(9,4) NULL,
 [PoolMaxWorkspaceMemoryMb] decimal(19,2) NULL,
 [PoolTargetWorkspaceMemoryMb] decimal(19,2) NULL,
 [PoolUsedWorkspaceMemoryMb] decimal(19,2) NULL,
 [ConfiguredRequestMaxGrantMemoryMb] decimal(19,2) NULL,
 [TargetRequestMaxGrantMemoryMb] decimal(19,2) NULL,
 [HistoricalMaxRequestGrantMemoryMb] decimal(19,2) NULL,
 [RequestedOfRequestMaxPercent] decimal(9,2) NULL,
 [GrantedOfRequestMaxPercent] decimal(9,2) NULL,
 [UsedOfRequestMaxPercent] decimal(9,2) NULL,
 [MaxUsedOfRequestMaxPercent] decimal(9,2) NULL,
 [IdealOfRequestMaxPercent] decimal(9,2) NULL,
 [RequestedOfTargetMaxPercent] decimal(9,2) NULL,
 [GrantedOfTargetMaxPercent] decimal(9,2) NULL,
 [UsedOfGrantedPercent] decimal(9,2) NULL,
 [MaxUsedOfGrantedPercent] decimal(9,2) NULL,
 [SemaphoreTargetMemoryMb] decimal(19,2) NULL,
 [SemaphoreMaxTargetMemoryMb] decimal(19,2) NULL,
 [SemaphoreTotalMemoryMb] decimal(19,2) NULL,
 [SemaphoreAvailableMemoryMb] decimal(19,2) NULL,
 [SemaphoreGrantedMemoryMb] decimal(19,2) NULL,
 [SemaphoreUsedMemoryMb] decimal(19,2) NULL,
 [SemaphoreGranteeCount] int NULL,
 [SemaphoreWaiterCount] int NULL,
 [ReservedWorkerCount] bigint NULL,
 [UsedWorkerCount] bigint NULL,
 [MaxUsedWorkerCount] bigint NULL,
 [QueueId] smallint NULL,
 [WaitOrder] int NULL,
 [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [DatabaseId] smallint NULL,
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [ElapsedMs] int NULL,
 [CpuMs] int NULL,
 [LogicalReads] bigint NULL,
 [CurrentStatementCharacters] bigint NULL,
 [CurrentStatementBytes] bigint NULL,
 [CurrentStatementIsTruncated] bit NOT NULL,
 [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
SELECT CONVERT(int,0) MeasurementPhase,* INTO #ExampleGrantNative FROM #ExampleGrantSchema;
CREATE TABLE #ExampleGrantUnboundedFields(FieldName sysname COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY);
INSERT #ExampleGrantUnboundedFields VALUES
 (N'SemaphoreTargetMemoryMb'),
 (N'SemaphoreMaxTargetMemoryMb'),
 (N'SemaphoreTotalMemoryMb'),
 (N'SemaphoreAvailableMemoryMb'),
 (N'SemaphoreGrantedMemoryMb'),
 (N'SemaphoreUsedMemoryMb'),
 (N'SemaphoreGranteeCount'),
 (N'SemaphoreWaiterCount'),
 (N'PoolUsedWorkspaceMemoryMb');
CREATE TABLE #ExampleGrantFixture(SessionId smallint NOT NULL PRIMARY KEY);
CREATE TABLE #ExampleGrantSelected(SessionId smallint NOT NULL PRIMARY KEY);
CREATE TABLE #ExampleGrantCases
(CaseNumber int PRIMARY KEY,IsNative bit NOT NULL,RowLimit int NULL,TextLimit int NULL,
 MitText bit NULL,Waiting bit NULL,IncludeSelf bit NULL,MinRequested decimal(19,2) NULL,
 MinGranted decimal(19,2) NULL,SessionList nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 ParentId uniqueidentifier NULL,ExpectedStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
DECLARE @EmptyMinimum decimal(19,2)=99999999999999999.99;
INSERT #ExampleGrantCases VALUES
 (0,0,NULL,NULL,1,0,0,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE'),
 (1,0,0,0,1,0,0,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE'),
 (2,0,1,3000,1,0,0,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE'),
 (3,0,2,3000,0,0,0,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE'),
 (4,0,-1,3000,1,0,0,@EmptyMinimum,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (5,0,1,-1,1,0,0,@EmptyMinimum,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (6,0,1,3000,1,0,0,-1,NULL,NULL,NULL,'INVALID_PARAMETER'),
 (7,0,1,3000,1,0,0,NULL,-1,NULL,NULL,'INVALID_PARAMETER'),
 (8,0,1,3000,1,0,0,@EmptyMinimum,NULL,N'0',NULL,'INVALID_PARAMETER'),
 (9,0,1,3000,1,0,0,@EmptyMinimum,NULL,N'32768',NULL,'INVALID_PARAMETER'),
 (10,0,1,3000,1,0,0,@EmptyMinimum,NULL,N'ExampleBad',NULL,'INVALID_PARAMETER'),
 (11,0,1,3000,1,0,0,@EmptyMinimum,NULL,N'1|ExampleBad',NULL,'INVALID_PARAMETER'),
 (12,0,1,3000,NULL,NULL,NULL,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE'),
 (13,0,2147483647,0,0,0,0,@EmptyMinimum,NULL,NULL,NULL,'AVAILABLE');
DECLARE @NativeFixtureStatus varchar(20)='NOT_EXECUTED',
 @FixtureList nvarchar(max)=TRY_CONVERT(nvarchar(max),SESSION_CONTEXT(N'ExampleMemoryGrantSessionIds')),
 @FixtureDatabaseId int=DB_ID(N'ExampleGrantsÄ🔬'),@FirstSession smallint;
IF @FixtureList IS NOT NULL
BEGIN
 IF EXISTS(SELECT 1 FROM STRING_SPLIT(@FixtureList,N'|') WHERE TRY_CONVERT(smallint,value) IS NULL OR TRY_CONVERT(int,value) NOT BETWEEN 1 AND 32767)
  OR(SELECT COUNT(*) FROM STRING_SPLIT(@FixtureList,N'|'))<>3
  OR(SELECT COUNT(DISTINCT TRY_CONVERT(smallint,value)) FROM STRING_SPLIT(@FixtureList,N'|'))<>3
  THROW 58500,N'MEMORY_GRANTS_FIXTURE_SESSION_LIST',1;
 INSERT #ExampleGrantFixture SELECT TRY_CONVERT(smallint,value) FROM STRING_SPLIT(@FixtureList,N'|');
 IF @FrameworkLevel=170 AND EXISTS(SELECT 1 FROM sys.databases WHERE database_id=@FixtureDatabaseId
   AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleGrantsÄ🔬' COLLATE SQL_Latin1_General_CP1_CS_AS
   AND collation_name IN(N'Latin1_General_100_CI_AS',N'SQL_Latin1_General_CP1_CI_AS') AND compatibility_level=170)
  AND(SELECT COUNT(*) FROM sys.dm_exec_query_memory_grants g JOIN #ExampleGrantFixture f ON f.SessionId=g.session_id
   JOIN sys.dm_exec_sessions s ON s.session_id=g.session_id JOIN sys.dm_exec_requests r ON r.session_id=g.session_id AND r.request_id=g.request_id
   WHERE r.database_id=@FixtureDatabaseId AND g.grant_time IS NOT NULL AND g.requested_memory_kb>0
    AND s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleGrantÄ🔬1',N'ExampleGrantÄ🔬2',N'ExampleGrantÄ🔬3'))=3
  AND(SELECT COUNT(DISTINCT s.program_name COLLATE SQL_Latin1_General_CP1_CS_AS) FROM sys.dm_exec_sessions s
   JOIN #ExampleGrantFixture f ON f.SessionId=s.session_id)=3
 BEGIN
  SELECT @FirstSession=MIN(SessionId) FROM #ExampleGrantFixture;
  INSERT #ExampleGrantCases VALUES
   (20,1,NULL,NULL,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (21,1,0,0,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (22,1,1,3000,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (23,1,2,3000,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (24,1,0,3000,1,1,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (25,1,0,3000,1,0,0,@EmptyMinimum,NULL,@FixtureList,NULL,'AVAILABLE'),
   (26,1,0,3000,1,0,0,NULL,@EmptyMinimum,@FixtureList,NULL,'AVAILABLE'),
   (27,1,0,3000,0,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (28,1,2,12,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (29,1,1,0,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (30,1,0,NULL,1,0,0,NULL,NULL,CONVERT(nvarchar(10),@FirstSession),NULL,'AVAILABLE'),
   (31,1,1,NULL,1,0,0,NULL,NULL,CONCAT(@FirstSession,N'|',@FirstSession),NULL,'AVAILABLE'),
   (32,1,0,3000,1,0,0,NULL,0,@FixtureList,NULL,'AVAILABLE'),
   (33,1,0,3000,1,NULL,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (34,1,1,3000,1,0,1,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (35,1,2147483647,3000,1,0,0,NULL,NULL,@FixtureList,NULL,'AVAILABLE'),
   (36,1,-1,3000,1,0,0,NULL,NULL,@FixtureList,NULL,'INVALID_PARAMETER'),
   (37,1,1,-1,1,0,0,NULL,NULL,@FixtureList,NULL,'INVALID_PARAMETER');
  SET @NativeFixtureStatus='PASS';
 END;
END;
DECLARE @NativeSql nvarchar(max)=N'INSERT #ExampleGrantNative(MeasurementPhase,[SessionId],[RequestId],[SchedulerId],[Dop],[RequestTime],[GrantTime],[WaitTimeMs],[IsWaiting],[IsSmall],[RequestedMemoryMb],[RequiredMemoryMb],[GrantedMemoryMb],[UsedMemoryMb],[MaxUsedMemoryMb],[IdealMemoryMb],[GroupId],[WorkloadGroupName],[PoolId],[PoolName],[ResourceSemaphoreId],[RequestMaxMemoryGrantPercent],[PoolMaxWorkspaceMemoryMb],[PoolTargetWorkspaceMemoryMb],[PoolUsedWorkspaceMemoryMb],[ConfiguredRequestMaxGrantMemoryMb],[TargetRequestMaxGrantMemoryMb],[HistoricalMaxRequestGrantMemoryMb],[RequestedOfRequestMaxPercent],[GrantedOfRequestMaxPercent],[UsedOfRequestMaxPercent],[MaxUsedOfRequestMaxPercent],[IdealOfRequestMaxPercent],[RequestedOfTargetMaxPercent],[GrantedOfTargetMaxPercent],[UsedOfGrantedPercent],[MaxUsedOfGrantedPercent],[SemaphoreTargetMemoryMb],[SemaphoreMaxTargetMemoryMb],[SemaphoreTotalMemoryMb],[SemaphoreAvailableMemoryMb],[SemaphoreGrantedMemoryMb],[SemaphoreUsedMemoryMb],[SemaphoreGranteeCount],[SemaphoreWaiterCount],[ReservedWorkerCount],[UsedWorkerCount],[MaxUsedWorkerCount],[QueueId],[WaitOrder],[LoginName],[HostName],[ProgramName],[DatabaseId],[DatabaseName],[RequestStatus],[Command],[ElapsedMs],[CpuMs],[LogicalReads],[CurrentStatementCharacters],[CurrentStatementBytes],[CurrentStatementIsTruncated],[CurrentStatement])
        SELECT @Phase,
              [g].[session_id]
            , [g].[request_id]
            , [g].[scheduler_id]
            , [g].[dop]
            , [g].[request_time]
            , [g].[grant_time]
            , [g].[wait_time_ms]
            , CONVERT(bit, CASE WHEN [g].[grant_time] IS NULL THEN 1 ELSE 0 END)
            , [g].[is_small]
            , CONVERT(decimal(19,2), [g].[requested_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[required_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[granted_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[max_used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[ideal_memory_kb] / 1024.0)
            , [g].[group_id]
            , [wg].[name]
            , [g].[pool_id]
            , [rp].[name]
            , [g].[resource_semaphore_id]
            , [calc].[RequestMaxMemoryGrantPercent]
            , [calc].[PoolMaxWorkspaceMemoryMb]
            , [calc].[PoolTargetWorkspaceMemoryMb]
            , [calc].[PoolUsedWorkspaceMemoryMb]
            , [calc].[ConfiguredRequestMaxGrantMemoryMb]
            , [calc].[TargetRequestMaxGrantMemoryMb]
            , CONVERT(decimal(19,2), [wg].[max_request_grant_memory_kb] / 1024.0)
            , CONVERT(decimal(9,2), 100.0 * [g].[requested_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[granted_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[used_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[max_used_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[ideal_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[requested_memory_kb]
                / NULLIF([calc].[TargetRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[granted_memory_kb]
                / NULLIF([calc].[TargetRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[used_memory_kb]
                / NULLIF([g].[granted_memory_kb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[max_used_memory_kb]
                / NULLIF([g].[granted_memory_kb], 0))
            , CONVERT(decimal(19,2), [sem].[target_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[max_target_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[total_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[available_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[granted_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[used_memory_kb] / 1024.0)
            , [sem].[grantee_count]
            , [sem].[waiter_count]
            , [g].[reserved_worker_count]
            , [g].[used_worker_count]
            , [g].[max_used_worker_count]
            , [g].[queue_id]
            , [g].[wait_order]
            , [s].[login_name]
            , [s].[host_name]
            , [s].[program_name]
            , [r].[database_id]
            , [d].[name]
            , [r].[status]
            , [r].[command]
            , [r].[total_elapsed_time]
            , [r].[cpu_time]
            , [r].[logical_reads]
            , CASE WHEN @Text=1 THEN CONVERT(bigint,LEN([statementText].[StatementText] COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1) END
            , CASE WHEN @Text=1 THEN DATALENGTH([statementText].[StatementText]) END
            , CONVERT(bit,CASE WHEN @Text=1 AND @TextLimit>0 AND LEN([statementText].[StatementText] COLLATE Latin1_General_100_CI_AS_SC+NCHAR(1))-1>@TextLimit THEN 1 ELSE 0 END)
            , CASE WHEN @Text=1 THEN CASE WHEN @TextLimit IS NULL OR @TextLimit=0 THEN [statementText].[StatementText] COLLATE SQL_Latin1_General_CP1_CS_AS ELSE LEFT([statementText].[StatementText] COLLATE Latin1_General_100_CI_AS_SC,@TextLimit) COLLATE SQL_Latin1_General_CP1_CS_AS END END
 FROM sys.dm_exec_query_memory_grants g
 LEFT JOIN sys.dm_exec_sessions s ON s.session_id=g.session_id
 LEFT JOIN sys.dm_exec_requests r ON r.session_id=g.session_id AND r.request_id=g.request_id
 LEFT JOIN sys.databases d ON d.database_id=r.database_id
 LEFT JOIN sys.dm_resource_governor_workload_groups wg ON wg.group_id=g.group_id
 LEFT JOIN sys.dm_resource_governor_resource_pools rp ON rp.pool_id=g.pool_id
 LEFT JOIN sys.dm_exec_query_resource_semaphores sem ON sem.pool_id=g.pool_id AND sem.resource_semaphore_id=g.resource_semaphore_id
 OUTER APPLY sys.dm_exec_sql_text(CASE WHEN @Text=1 THEN g.sql_handle END)t
 OUTER APPLY(SELECT StatementText=CASE WHEN t.text IS NULL THEN NULL
  WHEN COALESCE(r.statement_start_offset,0)<0 OR COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))<0
   OR COALESCE(r.statement_start_offset,0)>COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))
   OR COALESCE(r.statement_start_offset,0)>DATALENGTH(t.text)
   OR COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))>DATALENGTH(t.text)
   OR COALESCE(r.statement_start_offset,0)%2<>0 OR COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))%2<>0 THEN NULL
  ELSE SUBSTRING(t.text COLLATE Latin1_General_100_BIN2,COALESCE(r.statement_start_offset,0)/2+1,
   (COALESCE(NULLIF(r.statement_end_offset,-1),DATALENGTH(t.text))-COALESCE(r.statement_start_offset,0))/2+1) END)statementText
        OUTER APPLY
        (
            SELECT
                  [RequestMaxMemoryGrantPercent] = CONVERT(decimal(9,4), [wg].[request_max_memory_grant_percent_numeric])
                , [PoolMaxWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[max_memory_kb] / 1024.0)
                , [PoolTargetWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[target_memory_kb] / 1024.0)
                , [PoolUsedWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[used_memory_kb] / 1024.0)
                , [ConfiguredRequestMaxGrantMemoryKb] =
                    CONVERT(decimal(38,4), [rp].[max_memory_kb])
                    * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0
                , [TargetRequestMaxGrantMemoryKb] =
                    CONVERT(decimal(38,4), [rp].[target_memory_kb])
                    * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0
                , [ConfiguredRequestMaxGrantMemoryMb] = CONVERT
                  (
                      decimal(19,2),
                      CONVERT(decimal(38,4), [rp].[max_memory_kb])
                      * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0 / 1024.0
                  )
                , [TargetRequestMaxGrantMemoryMb] = CONVERT
                  (
                      decimal(19,2),
                      CONVERT(decimal(38,4), [rp].[target_memory_kb])
                      * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0 / 1024.0
                  )
        ) AS [calc]
 WHERE EXISTS(SELECT 1 FROM #ExampleGrantSelected x WHERE x.SessionId=g.session_id)
 AND (@IncludeSelf=1 OR g.session_id<>@@SPID) AND (@Waiting=0 OR g.grant_time IS NULL)
 AND (@MinRequested IS NULL OR g.requested_memory_kb>=@MinRequested*1024.0)
 AND (@MinGranted IS NULL OR g.granted_memory_kb>=@MinGranted*1024.0);',
 @NativeParameters nvarchar(max)=N'@Phase int,@Text bit,@TextLimit int,@Waiting bit,@IncludeSelf bit,@MinRequested decimal(19,2),@MinGranted decimal(19,2)';

DECLARE @Case int,@Native bit,@Limit int,@TextLimit int,@Text bit,@Waiting bit,@IncludeSelf bit,
 @MinRequested decimal(19,2),@MinGranted decimal(19,2),@Sessions nvarchar(max),@ParentId uniqueidentifier,@Status varchar(40),
 @Json nvarchar(max),@TableJson nvarchar(max),@DataJson nvarchar(max),@BeforeJson nvarchar(max),@AfterJson nvarchar(max),
 @Before datetime2(3),@After datetime2(3),@FullRows bigint,@Rows bigint,@SafeLimit bigint,
 @CoreCases int=0,@NativeCases int=0,@Sql nvarchar(max);
DECLARE cases CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM #ExampleGrantCases ORDER BY CaseNumber;
OPEN cases;
FETCH NEXT FROM cases INTO @Case,@Native,@Limit,@TextLimit,@Text,@Waiting,@IncludeSelf,@MinRequested,@MinGranted,@Sessions,@ParentId,@Status;
WHILE @@FETCH_STATUS=0
BEGIN
 CREATE TABLE #ExampleGrantTarget(Dummy int NULL);
 TRUNCATE TABLE #ExampleGrantNative;
 TRUNCATE TABLE #ExampleGrantSelected;
 IF @Native=1 INSERT #ExampleGrantSelected SELECT TRY_CONVERT(smallint,value) FROM STRING_SPLIT(@Sessions,N'|') GROUP BY TRY_CONVERT(smallint,value);
 SET @Before=SYSUTCDATETIME();
 IF @Native=1 AND @Status='AVAILABLE'
  EXEC sys.sp_executesql @NativeSql,@NativeParameters,@Phase=0,@Text=@Text,@TextLimit=@TextLimit,@Waiting=@Waiting,
   @IncludeSelf=@IncludeSelf,@MinRequested=@MinRequested,@MinGranted=@MinGranted;
 EXEC monitor.USP_CurrentMemoryGrants @SessionIds=@Sessions,@AktuelleSessionEinbeziehen=@IncludeSelf,@NurWartende=@Waiting,
  @MinRequestedMb=@MinRequested,@MinGrantedMb=@MinGranted,@MitSqlText=@Text,@MaxSqlTextZeichen=@TextLimit,@MaxZeilen=@Limit,
  @ParentCurrentStateSnapshotId=@ParentId,@ResultSetArt='TABLE',@ResultTablesJson=N'{"memoryGrants":"#ExampleGrantTarget"}',
  @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF @Native=1 AND @Status='AVAILABLE'
  EXEC sys.sp_executesql @NativeSql,@NativeParameters,@Phase=1,@Text=@Text,@TextLimit=@TextLimit,@Waiting=@Waiting,
   @IncludeSelf=@IncludeSelf,@MinRequested=@MinRequested,@MinGranted=@MinGranted;
 SET @After=SYSUTCDATETIME();
 IF @@LOCK_TIMEOUT<>@CallerLockTimeout THROW 58501,N'MEMORY_GRANTS_CALLER_LOCK_TIMEOUT',1;
 IF EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id) Ordinal,name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,
    max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleGrantTarget') EXCEPT
   SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,
    max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleGrantSchema'))
  OR EXISTS(SELECT ROW_NUMBER()OVER(ORDER BY column_id) Ordinal,name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,
    max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleGrantSchema') EXCEPT
   SELECT ROW_NUMBER()OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,system_type_id,user_type_id,
    max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2,is_nullable,is_identity
   FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleGrantTarget'))
  THROW 58502,N'MEMORY_GRANTS_SCHEMA',1;
 EXEC sys.sp_executesql N'SELECT @j=(SELECT * FROM #ExampleGrantTarget FOR JSON PATH,INCLUDE_NULL_VALUES);',
  N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
 SET @TableJson=COALESCE(@TableJson,N'[]');
 SELECT @FullRows=COUNT_BIG(*) FROM #ExampleGrantNative WHERE MeasurementPhase=0;
 SET @SafeLimit=CASE WHEN @Limit IS NULL OR @Limit=0 THEN 9223372036854775807 WHEN @Limit>0 THEN @Limit ELSE 0 END;
 SET @Rows=CASE WHEN @FullRows>@SafeLimit THEN @SafeLimit ELSE @FullRows END;
 IF ISJSON(@Json)<>1 OR(SELECT COUNT(*) FROM OPENJSON(@Json))<>3
  OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
  OR EXISTS(SELECT [key] FROM OPENJSON(@Json) EXCEPT SELECT v.k FROM(VALUES(N'meta'),(N'memoryGrants'),(N'warnings'))v(k))
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE [key] WHEN N'meta' THEN 5 ELSE 4 END)
  OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>15
  OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
  OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT v.k FROM(VALUES(N'resultName'),(N'schemaVersion'),
   (N'generatedAtUtc'),(N'evidenceSnapshotStartedAtUtc'),(N'evidenceSnapshotId'),(N'statusCode'),(N'isPartial'),
   (N'requestedMaxRows'),(N'returnedRows'),(N'resultLimited'),(N'hasMoreRows'),(N'requiredPermission'),(N'errorNumber'),(N'errorMessage'),(N'detail'))v(k))
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [type]<>CASE [key]
   WHEN N'schemaVersion' THEN 2 WHEN N'returnedRows' THEN 2 WHEN N'isPartial' THEN 3 WHEN N'resultLimited' THEN 3 WHEN N'hasMoreRows' THEN 3
   WHEN N'requestedMaxRows' THEN CASE WHEN @Limit IS NULL THEN 0 ELSE 2 END WHEN N'errorNumber' THEN 0
   WHEN N'errorMessage' THEN CASE WHEN @Status='AVAILABLE' THEN 0 ELSE 1 END
   WHEN N'detail' THEN CASE WHEN @Status='AVAILABLE' THEN 1 ELSE 0 END ELSE 1 END)
  OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'CurrentMemoryGrants'
  OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>2
  OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'false'
  OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
  OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
  OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
  OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
  OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) NOT BETWEEN @Before AND @After
  OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL
  OR(@Status='AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL)
  OR(@Status<>'AVAILABLE' AND JSON_VALUE(@Json,N'$.meta.errorMessage') IS NULL)
  OR(@Limit IS NULL AND JSON_VALUE(@Json,N'$.meta.requestedMaxRows') IS NOT NULL)
  OR(@Limit IS NOT NULL AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),-2147483648)<>@Limit)
  OR ISNULL(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@Rows
  OR JSON_VALUE(@Json,N'$.meta.requiredPermission')<>CASE WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=16
   THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END
  OR JSON_VALUE(@Json,N'$.meta.hasMoreRows')<>CASE WHEN @FullRows>@SafeLimit THEN N'true' ELSE N'false' END
  OR JSON_VALUE(@Json,N'$.meta.resultLimited')<>JSON_VALUE(@Json,N'$.meta.hasMoreRows')
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings'))
  THROW 58503,N'MEMORY_GRANTS_META',1;
 SET @DataJson=JSON_QUERY(@Json,N'$.memoryGrants');
 IF(SELECT COUNT_BIG(*) FROM OPENJSON(@DataJson))<>@Rows OR(SELECT COUNT_BIG(*) FROM OPENJSON(@TableJson))<>@Rows
  THROW 58504,N'MEMORY_GRANTS_COUNTS',1;
 IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@DataJson)
   GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*)
   FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson)
   GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*)
   FROM OPENJSON(@DataJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT 1 FROM OPENJSON(@DataJson)a WHERE(SELECT COUNT(*) FROM OPENJSON(a.value))<>63
   OR EXISTS(SELECT [key] FROM OPENJSON(a.value) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) EXCEPT
    SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleGrantSchema')))
  THROW 58505,N'MEMORY_GRANTS_TABLE_JSON',1;
 IF @Native=1 AND @Status='AVAILABLE'
 BEGIN
  IF @FullRows<>(SELECT COUNT_BIG(*) FROM #ExampleGrantNative WHERE MeasurementPhase=1)
   OR EXISTS(SELECT SessionId,RequestId FROM #ExampleGrantNative WHERE MeasurementPhase=0 EXCEPT
    SELECT SessionId,RequestId FROM #ExampleGrantNative WHERE MeasurementPhase=1)
   OR EXISTS(SELECT MeasurementPhase,SessionId,RequestId FROM #ExampleGrantNative GROUP BY MeasurementPhase,SessionId,RequestId HAVING COUNT(*)<>1)
   THROW 58506,N'MEMORY_GRANTS_NATIVE_KEYS',1;
  SELECT @BeforeJson=(SELECT [SessionId],[RequestId],[SchedulerId],[Dop],[RequestTime],[GrantTime],[WaitTimeMs],[IsWaiting],[IsSmall],[RequestedMemoryMb],[RequiredMemoryMb],[GrantedMemoryMb],[UsedMemoryMb],[MaxUsedMemoryMb],[IdealMemoryMb],[GroupId],[WorkloadGroupName],[PoolId],[PoolName],[ResourceSemaphoreId],[RequestMaxMemoryGrantPercent],[PoolMaxWorkspaceMemoryMb],[PoolTargetWorkspaceMemoryMb],[PoolUsedWorkspaceMemoryMb],[ConfiguredRequestMaxGrantMemoryMb],[TargetRequestMaxGrantMemoryMb],[HistoricalMaxRequestGrantMemoryMb],[RequestedOfRequestMaxPercent],[GrantedOfRequestMaxPercent],[UsedOfRequestMaxPercent],[MaxUsedOfRequestMaxPercent],[IdealOfRequestMaxPercent],[RequestedOfTargetMaxPercent],[GrantedOfTargetMaxPercent],[UsedOfGrantedPercent],[MaxUsedOfGrantedPercent],[SemaphoreTargetMemoryMb],[SemaphoreMaxTargetMemoryMb],[SemaphoreTotalMemoryMb],[SemaphoreAvailableMemoryMb],[SemaphoreGrantedMemoryMb],[SemaphoreUsedMemoryMb],[SemaphoreGranteeCount],[SemaphoreWaiterCount],[ReservedWorkerCount],[UsedWorkerCount],[MaxUsedWorkerCount],[QueueId],[WaitOrder],[LoginName],[HostName],[ProgramName],[DatabaseId],[DatabaseName],[RequestStatus],[Command],[ElapsedMs],[CpuMs],[LogicalReads],[CurrentStatementCharacters],[CurrentStatementBytes],[CurrentStatementIsTruncated],[CurrentStatement] FROM #ExampleGrantNative WHERE MeasurementPhase=0 FOR JSON PATH,INCLUDE_NULL_VALUES),
   @AfterJson=(SELECT [SessionId],[RequestId],[SchedulerId],[Dop],[RequestTime],[GrantTime],[WaitTimeMs],[IsWaiting],[IsSmall],[RequestedMemoryMb],[RequiredMemoryMb],[GrantedMemoryMb],[UsedMemoryMb],[MaxUsedMemoryMb],[IdealMemoryMb],[GroupId],[WorkloadGroupName],[PoolId],[PoolName],[ResourceSemaphoreId],[RequestMaxMemoryGrantPercent],[PoolMaxWorkspaceMemoryMb],[PoolTargetWorkspaceMemoryMb],[PoolUsedWorkspaceMemoryMb],[ConfiguredRequestMaxGrantMemoryMb],[TargetRequestMaxGrantMemoryMb],[HistoricalMaxRequestGrantMemoryMb],[RequestedOfRequestMaxPercent],[GrantedOfRequestMaxPercent],[UsedOfRequestMaxPercent],[MaxUsedOfRequestMaxPercent],[IdealOfRequestMaxPercent],[RequestedOfTargetMaxPercent],[GrantedOfTargetMaxPercent],[UsedOfGrantedPercent],[MaxUsedOfGrantedPercent],[SemaphoreTargetMemoryMb],[SemaphoreMaxTargetMemoryMb],[SemaphoreTotalMemoryMb],[SemaphoreAvailableMemoryMb],[SemaphoreGrantedMemoryMb],[SemaphoreUsedMemoryMb],[SemaphoreGranteeCount],[SemaphoreWaiterCount],[ReservedWorkerCount],[UsedWorkerCount],[MaxUsedWorkerCount],[QueueId],[WaitOrder],[LoginName],[HostName],[ProgramName],[DatabaseId],[DatabaseName],[RequestStatus],[Command],[ElapsedMs],[CpuMs],[LogicalReads],[CurrentStatementCharacters],[CurrentStatementBytes],[CurrentStatementIsTruncated],[CurrentStatement] FROM #ExampleGrantNative WHERE MeasurementPhase=1 FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF EXISTS(SELECT 1 FROM OPENJSON(@DataJson)a
   WHERE NOT EXISTS(SELECT 1 FROM OPENJSON(@BeforeJson)b WHERE JSON_VALUE(a.value,N'$.SessionId')=JSON_VALUE(b.value,N'$.SessionId')
    AND JSON_VALUE(a.value,N'$.RequestId')=JSON_VALUE(b.value,N'$.RequestId')))
   OR EXISTS(SELECT JSON_VALUE(value,N'$.SessionId'),JSON_VALUE(value,N'$.RequestId') FROM OPENJSON(@DataJson)
    GROUP BY JSON_VALUE(value,N'$.SessionId'),JSON_VALUE(value,N'$.RequestId') HAVING COUNT(*)<>1)
   THROW 58506,N'MEMORY_GRANTS_OUTPUT_KEYS',1;
  IF EXISTS
  (
   SELECT 1 FROM OPENJSON(@DataJson)a
   JOIN OPENJSON(@BeforeJson)b ON JSON_VALUE(a.value,N'$.SessionId')=JSON_VALUE(b.value,N'$.SessionId')
    AND JSON_VALUE(a.value,N'$.RequestId')=JSON_VALUE(b.value,N'$.RequestId')
   JOIN OPENJSON(@AfterJson)c ON JSON_VALUE(a.value,N'$.SessionId')=JSON_VALUE(c.value,N'$.SessionId')
    AND JSON_VALUE(a.value,N'$.RequestId')=JSON_VALUE(c.value,N'$.RequestId')
   CROSS APPLY OPENJSON(a.value)av CROSS APPLY OPENJSON(b.value)bv CROSS APPLY OPENJSON(c.value)cv
   WHERE av.[key]=bv.[key] AND av.[key]=cv.[key] AND
   (
    av.[type]<>bv.[type] OR av.[type]<>cv.[type]
    OR(av.[type]<>2 AND EXISTS(SELECT bv.[value] COLLATE Latin1_General_100_BIN2 EXCEPT SELECT cv.[value] COLLATE Latin1_General_100_BIN2))
    OR(av.[type]<>2 AND EXISTS(SELECT av.[value] COLLATE Latin1_General_100_BIN2 EXCEPT SELECT bv.[value] COLLATE Latin1_General_100_BIN2))
    OR(av.[type]=2 AND(TRY_CONVERT(decimal(38,8),av.[value]) IS NULL OR TRY_CONVERT(decimal(38,8),bv.[value]) IS NULL
      OR TRY_CONVERT(decimal(38,8),cv.[value]) IS NULL))
    OR(av.[type]=2 AND NOT EXISTS(SELECT 1 FROM #ExampleGrantUnboundedFields u WHERE u.FieldName=av.[key] COLLATE Latin1_General_100_BIN2)
     AND TRY_CONVERT(decimal(38,8),av.[value]) NOT BETWEEN
       CASE WHEN TRY_CONVERT(decimal(38,8),bv.[value])<TRY_CONVERT(decimal(38,8),cv.[value]) THEN TRY_CONVERT(decimal(38,8),bv.[value]) ELSE TRY_CONVERT(decimal(38,8),cv.[value]) END
       AND CASE WHEN TRY_CONVERT(decimal(38,8),bv.[value])>TRY_CONVERT(decimal(38,8),cv.[value]) THEN TRY_CONVERT(decimal(38,8),bv.[value]) ELSE TRY_CONVERT(decimal(38,8),cv.[value]) END)
   )
  ) THROW 58507,N'MEMORY_GRANTS_NATIVE_MEASUREMENT_BOUNDS',1;
  IF EXISTS(SELECT JSON_VALUE(value,N'$.SessionId'),JSON_VALUE(value,N'$.RequestId') FROM OPENJSON(@DataJson) EXCEPT
   SELECT ExpectedSession,ExpectedRequest FROM(SELECT TOP(@SafeLimit) CONVERT(nvarchar(10),SessionId) ExpectedSession,
     CONVERT(nvarchar(10),RequestId) ExpectedRequest FROM #ExampleGrantNative WHERE MeasurementPhase=0
     ORDER BY IsWaiting DESC,RequestedMemoryMb DESC,WaitTimeMs DESC,SessionId,RequestId)selection)
   OR EXISTS(SELECT 1 FROM
    (SELECT a.[key],g.IsWaiting,g.RequestedMemoryMb,g.WaitTimeMs,g.SessionId,g.RequestId,
      ROW_NUMBER()OVER(ORDER BY g.IsWaiting DESC,g.RequestedMemoryMb DESC,g.WaitTimeMs DESC,g.SessionId,g.RequestId)-1 ExpectedOrdinal
     FROM OPENJSON(@DataJson)a JOIN #ExampleGrantNative g ON g.MeasurementPhase=0
      AND g.SessionId=TRY_CONVERT(smallint,JSON_VALUE(a.value,N'$.SessionId')) AND g.RequestId=TRY_CONVERT(int,JSON_VALUE(a.value,N'$.RequestId')))o
    WHERE TRY_CONVERT(bigint,o.[key])<>o.ExpectedOrdinal)
   THROW 58508,N'MEMORY_GRANTS_NATIVE_SELECTION_ORDER',1;
 END;
 DROP TABLE #ExampleGrantTarget;
 IF @Native=1 SET @NativeCases+=1; ELSE SET @CoreCases+=1;
 FETCH NEXT FROM cases INTO @Case,@Native,@Limit,@TextLimit,@Text,@Waiting,@IncludeSelf,@MinRequested,@MinGranted,@Sessions,@ParentId,@Status;
END;
CLOSE cases; DEALLOCATE cases;
CREATE TABLE #ExampleGrantEmptyConsole(Ergebnis nvarchar(200),Status varchar(40),Hinweis nvarchar(2048));
DECLARE @EmptyCase int=0;
WHILE @EmptyCase<3
BEGIN
 TRUNCATE TABLE #ExampleGrantEmptyConsole;
 SET @Limit=CASE WHEN @EmptyCase=0 THEN -1 ELSE 1 END;
 SET @TextLimit=CASE WHEN @EmptyCase=1 THEN -1 ELSE 3000 END;
 INSERT #ExampleGrantEmptyConsole EXEC monitor.USP_CurrentMemoryGrants @MinRequestedMb=@EmptyMinimum,
  @MaxZeilen=@Limit,@MaxSqlTextZeichen=@TextLimit,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF(SELECT COUNT(*) FROM #ExampleGrantEmptyConsole)<>1
  OR EXISTS(SELECT 1 FROM #ExampleGrantEmptyConsole WHERE Ergebnis<>N'Keine aktiven Memory Grants' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.memoryGrants')) OR @@LOCK_TIMEOUT<>@CallerLockTimeout
  THROW 58509,N'MEMORY_GRANTS_EMPTY_CONSOLE',1;
 SET @EmptyCase+=1;
END;
DECLARE @Consumer int=0,@OutputMode varchar(16),@JsonBit bit;
WHILE @Consumer<3
BEGIN
 SET @OutputMode=CASE WHEN @Consumer=1 THEN ' rAw ' ELSE 'NONE' END;
 SET @JsonBit=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;
 SET @Json=N'{"ExampleStale":true}';
 EXEC monitor.USP_CurrentMemoryGrants @MaxZeilen=-1,@ResultSetArt=@OutputMode,@JsonErzeugen=@JsonBit,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF @JsonBit=0 AND @Json IS NOT NULL OR @JsonBit=1 AND(JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER'
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.memoryGrants'))) OR @@LOCK_TIMEOUT<>@CallerLockTimeout
  THROW 58510,N'MEMORY_GRANTS_CONSUMER',1;
 SET @Consumer+=1;
END;
CREATE TABLE #ExampleGrantPreflight(Dummy int NULL);
INSERT #ExampleGrantPreflight VALUES(4242);
DECLARE @Preflight int=0,@Map nvarchar(max),@Caught int;
WHILE @Preflight<6
BEGIN
 SET @Map=CASE @Preflight WHEN 0 THEN NULL WHEN 1 THEN N'{}' WHEN 2 THEN N'{"wrong":"#ExampleGrantPreflight"}'
  WHEN 3 THEN N'{"memoryGrants":"dbo.ExampleGrantPermanent"}' WHEN 4 THEN N'{"memoryGrants":"#ExampleGrantAbsent"}'
  ELSE N'{"memoryGrants":"#ExampleGrantPreflight"}' END;
 SET @OutputMode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
 SET @Caught=0;
 BEGIN TRY
  EXEC monitor.USP_CurrentMemoryGrants @MaxZeilen=-1,@ResultSetArt=@OutputMode,@ResultTablesJson=@Map,@PrintMeldungen=0;
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()<>51011 THROW;
  SET @Caught=1;
 END CATCH;
 IF @Caught<>1 OR(SELECT COUNT(*) FROM #ExampleGrantPreflight WHERE Dummy=4242)<>1
  THROW 58511,N'MEMORY_GRANTS_PREFLIGHT',1;
 SET @Preflight+=1;
END;
DECLARE @MissingParentStatus varchar(20)='NOT_EXECUTED',@MissingParentId uniqueidentifier=NEWID();
IF OBJECT_ID(N'tempdb..#CurrentOverview_CurrentStateSnapshot_Context') IS NULL
BEGIN
 EXEC monitor.USP_CurrentMemoryGrants @ParentCurrentStateSnapshotId=@MissingParentId,@ResultSetArt='NONE',
  @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARENT_SNAPSHOT'
  OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true' OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.errorNumber'))<>208
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.memoryGrants'))
  OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
  THROW 58512,N'MEMORY_GRANTS_MISSING_PARENT',1;
 SET @MissingParentStatus='PASS';
END;
DECLARE @ConsoleNative int=0;
IF @NativeFixtureStatus='PASS'
BEGIN
 WHILE @ConsoleNative<3
 BEGIN
  SET @Limit=CASE @ConsoleNative WHEN 0 THEN 1 WHEN 1 THEN 2 ELSE 0 END;
  EXEC monitor.USP_CurrentMemoryGrants @SessionIds=@FixtureList,@MaxZeilen=@Limit,@ResultSetArt='CONSOLE',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF JSON_VALUE(@Json,N'$.meta.statusCode')<>'AVAILABLE' OR(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.memoryGrants'))<>
   CASE WHEN @Limit=0 THEN 3 ELSE @Limit END OR @@LOCK_TIMEOUT<>@CallerLockTimeout
   THROW 58513,N'MEMORY_GRANTS_DIRECT_CONSOLE',1;
  SET @ConsoleNative+=1;
 END;
END;
SELECT N'PASS' ContractStatus,@FrameworkLevel FrameworkCompatibilityLevel,@CoreCases CoreCases,
 @NativeFixtureStatus NativeFixtureStatus,@NativeCases NativeCases,63 FieldCount,9 TextCollationCount,
 (SELECT COUNT(*) FROM #ExampleGrantUnboundedFields) NativeNumericUnboundedFields,
 @Consumer ConsumerCases,@Preflight PreflightCases,@EmptyCase EmptyConsoleCases,
 @ConsoleNative DirectConsoleCases,@MissingParentStatus MissingParentStatus;
GO
