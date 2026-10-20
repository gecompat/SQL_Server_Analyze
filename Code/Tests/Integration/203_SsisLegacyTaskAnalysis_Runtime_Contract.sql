USE [DeineDatenbank];
GO
DECLARE @CiFileMarker nvarchar(400)=CONCAT(N'CI_BEGIN|203|file|0|',CONVERT(varchar(27),SYSUTCDATETIME(),126),N'Z|',@@SPID,N'|',@@LOCK_TIMEOUT,N'|-');
RAISERROR(N'%s',10,1,@CiFileMarker) WITH NOWAIT;
GO
/* Synthetic observed-event tests; no provider-generation claim. */
DECLARE @DbId int=DB_ID(),@ProcId int=NULL,@TableId int=NULL,@UserId int=NULL;
DECLARE @OuterOptions int=@@OPTIONS,@OuterLock int=@@LOCK_TIMEOUT,@OuterTran int=@@TRANCOUNT;
IF OBJECT_ID(N'tempdb..#ExampleSsisTaskOwnership') IS NOT NULL THROW 56590,N'TASK_FOREIGN_OWNERSHIP_TEMP',1;
IF EXISTS(SELECT 1 FROM sys.all_objects WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleSsisTaskFixtureScope',N'ExampleSsisTaskLogSource')) THROW 56591,N'TASK_FOREIGN_FIXTURE',1;
IF EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTaskLogReader') THROW 56596,N'TASK_FOREIGN_READER',1;
CREATE TABLE #ExampleSsisTaskOwnership(TableId int NULL,UserId int NULL);
INSERT #ExampleSsisTaskOwnership VALUES(NULL,NULL);
DECLARE @OwnershipId int=OBJECT_ID(N'tempdb..#ExampleSsisTaskOwnership');
BEGIN TRY
 EXEC(N'CREATE PROCEDURE dbo.ExampleSsisTaskFixtureScope @OwnedTableId int OUTPUT AS BEGIN
SET NOCOUNT ON;
DECLARE @CiOrdinal int=0,@CiMarker nvarchar(1000);
DECLARE @Db sysname=(SELECT name FROM sys.databases WITH (NOLOCK) WHERE database_id=DB_ID());
DECLARE @Id uniqueidentifier=''00000000-0000-0000-0000-000000000001'';
DECLARE @A uniqueidentifier=''00000000-0000-0000-0000-000000000010'',@B uniqueidentifier=''00000000-0000-0000-0000-000000000020'';
DECLARE @J nvarchar(max),@J0 nvarchar(max),@JNull nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(4000);
DECLARE @Options int=@@OPTIONS,@Lock int=@@LOCK_TIMEOUT,@Tran int=@@TRANCOUNT;
CREATE TABLE dbo.ExampleSsisTaskLogSource
([id] int NOT NULL,[event] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [source] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[sourceid] uniqueidentifier NULL,[executionid] uniqueidentifier NULL,
 [starttime] datetime NULL,[endtime] datetime NULL,[datacode] int NULL,[message] nvarchar(2048) NULL);
SELECT @OwnedTableId=object_id FROM sys.tables WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleSsisTaskLogSource'';
UPDATE #ExampleSsisTaskOwnership SET TableId=@OwnedTableId;

-- S01: independent exact arithmetic, distinct phase kinds, and all new TABLE/JSON fields.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreValidate'',N''ExampleTask'',@A,@Id,''20260101 00:00:00'',''20270101'',0),
 (2,N''OnPostValidate'',N''ExampleTask'',@A,@Id,''20260101 00:00:01'',''20270101'',0),
 (3,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:02'',''20270101'',0),
 (4,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:04'',''20270101'',0),
 (5,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:06'',''20270101'',0),
 (6,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:09'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C001|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C001|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56501,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.meta.SchemaVersion'')=N''2'' AND JSON_VALUE(@J,''$.meta.TaskAnalysisCatalogVersion'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].PairKind'')=N''EXECUTE'' AND JSON_VALUE(@J,''$.taskDurations[0].ValidPairCount'')=N''2'' AND JSON_VALUE(@J,''$.taskDurations[0].PairRowCount'')=N''2'' AND JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'')=N''5000'' AND JSON_VALUE(@J,''$.taskDurations[0].AverageDurationMs'')=N''2500.000000'' AND JSON_VALUE(@J,''$.taskDurations[0].MinDurationMs'')=N''2000'' AND JSON_VALUE(@J,''$.taskDurations[0].MaxDurationMs'')=N''3000'' AND JSON_VALUE(@J,''$.taskDurations[0].EvidenceLogIdsJson'')=N''[3,4,5,6]'' AND JSON_VALUE(@J,''$.taskDurations[1].TotalDurationMs'')=N''1000'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ObservedEventCount'')=N''6'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ExecuteStartCount'')=N''2'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ExecuteEndCount'')=N''2'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ValidateStartCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ValidateEndCount'')=N''1'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'')=N''3'') THROW 56502,N''TASK_S01_ARITHMETIC'',1;
CREATE TABLE #ExampleTaskDuration([Seed] int NULL); CREATE TABLE #ExampleTaskCoverage([Seed] int NULL);
DECLARE @Mapping nvarchar(max)=N''{"taskDurations":"#ExampleTaskDuration","taskLoggingCoverage":"#ExampleTaskCoverage"}'';
DECLARE @DurationId int=OBJECT_ID(N''tempdb..#ExampleTaskDuration''),@CoverageId int=OBJECT_ID(N''tempdb..#ExampleTaskCoverage'');
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C002|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=1,
 @MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@J OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C002|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
DECLARE @TableJson nvarchar(max),@CompareSql nvarchar(max)=N''SELECT @T=(SELECT * FROM #ExampleTaskDuration ORDER BY TaskDurationOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES)'';
EXEC sys.sp_executesql @CompareSql,N''@T nvarchar(max) OUTPUT'',@T=@TableJson OUTPUT;
IF @TableJson IS NULL OR JSON_QUERY(@J,''$.taskDurations'') IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),JSON_QUERY(@J,''$.taskDurations'')) THROW 56580,N''TASK_TABLE_JSON_ALL_23_FIELDS'',1;
SET @CompareSql=N''SELECT @T=(SELECT * FROM #ExampleTaskCoverage ORDER BY CoverageOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES)'';
EXEC sys.sp_executesql @CompareSql,N''@T nvarchar(max) OUTPUT'',@T=@TableJson OUTPUT;
IF @TableJson IS NULL OR JSON_QUERY(@J,''$.taskLoggingCoverage'') IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),JSON_QUERY(@J,''$.taskLoggingCoverage'')) THROW 56581,N''TASK_TABLE_JSON_ALL_25_FIELDS'',1;

IF EXISTS(SELECT 1 FROM (VALUES
 (1,N''TaskDurationOrdinal'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (2,N''ExecutionId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
 (3,N''SourceId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
 (4,N''SourceName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
 (5,N''SourceType'',N''varchar'',24,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
 (6,N''PairKind'',N''varchar'',16,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
 (7,N''BasisFirstLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
 (8,N''BasisLastLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
 (9,N''EvidenceLogIdsJson'',N''nvarchar'',-1,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
 (10,N''PairRowCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (11,N''ValidPairCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (12,N''UnknownTimePairCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (13,N''NonMonotonicPairCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (14,N''OpenStartCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (15,N''OpenEndCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (16,N''AmbiguousBoundaryCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (17,N''TotalDurationMs'',N''decimal'',17,38,0,1,CONVERT(sysname,NULL)),
 (18,N''AverageDurationMs'',N''decimal'',17,38,6,1,CONVERT(sysname,NULL)),
 (19,N''MinDurationMs'',N''bigint'',8,19,0,1,CONVERT(sysname,NULL)),
 (20,N''MaxDurationMs'',N''bigint'',8,19,0,1,CONVERT(sysname,NULL)),
 (21,N''SourceNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
 (22,N''InputIsTruncated'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
 (23,N''MetricStatus'',N''varchar'',40,0,0,0,N''SQL_Latin1_General_CP1_CS_AS'')) AS e(Ordinal,Name,TypeName,MaxLength,PrecisionValue,ScaleValue,Nullable,CollationName)
 FULL JOIN (SELECT ROW_NUMBER() OVER(ORDER BY c.column_id) AS column_id,c.name,t.name AS TypeName,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity
 FROM tempdb.sys.columns AS c WITH (NOLOCK) INNER JOIN tempdb.sys.types AS t WITH (NOLOCK) ON t.user_type_id=c.user_type_id WHERE c.object_id=@DurationId) AS a ON a.column_id=e.Ordinal
 WHERE a.column_id IS NULL OR e.Ordinal IS NULL OR a.name COLLATE SQL_Latin1_General_CP1_CS_AS<>e.Name COLLATE SQL_Latin1_General_CP1_CS_AS
 OR a.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS<>e.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS OR a.max_length<>e.MaxLength OR a.precision<>e.PrecisionValue OR a.scale<>e.ScaleValue OR a.is_nullable<>e.Nullable
 OR ISNULL(a.collation_name,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(e.CollationName,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS OR a.is_identity<>0)
 THROW 56582,N''TASK_PHYSICAL_TASKDURATIONS'',1;
IF EXISTS(SELECT 1 FROM (VALUES
 (1,N''CoverageOrdinal'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (2,N''ExecutionId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
 (3,N''SourceId'',N''uniqueidentifier'',16,0,0,1,CONVERT(sysname,NULL)),
 (4,N''UnresolvedLogId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
 (5,N''SourceName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
 (6,N''SourceType'',N''varchar'',24,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
 (7,N''BasisFirstLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
 (8,N''BasisLastLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
 (9,N''EvidenceLogIdsJson'',N''nvarchar'',-1,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
 (10,N''ObservedEventCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (11,N''ExecuteStartCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (12,N''ExecuteEndCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (13,N''ValidateStartCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (14,N''ValidateEndCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (15,N''KnownOtherEventCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (16,N''UnknownEventNameCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (17,N''MissingEventNameCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (18,N''MissingEventTimeCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (19,N''AmbiguousBoundaryCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (20,N''UnresolvedBoundaryCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (21,N''IncompleteBoundaryCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (22,N''InvalidTimePairCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
 (23,N''SourceNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
 (24,N''InputIsTruncated'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
 (25,N''CoverageStatus'',N''varchar'',40,0,0,0,N''SQL_Latin1_General_CP1_CS_AS'')) AS e(Ordinal,Name,TypeName,MaxLength,PrecisionValue,ScaleValue,Nullable,CollationName)
 FULL JOIN (SELECT ROW_NUMBER() OVER(ORDER BY c.column_id) AS column_id,c.name,t.name AS TypeName,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity
 FROM tempdb.sys.columns AS c WITH (NOLOCK) INNER JOIN tempdb.sys.types AS t WITH (NOLOCK) ON t.user_type_id=c.user_type_id WHERE c.object_id=@CoverageId) AS a ON a.column_id=e.Ordinal
 WHERE a.column_id IS NULL OR e.Ordinal IS NULL OR a.name COLLATE SQL_Latin1_General_CP1_CS_AS<>e.Name COLLATE SQL_Latin1_General_CP1_CS_AS
 OR a.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS<>e.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS OR a.max_length<>e.MaxLength OR a.precision<>e.PrecisionValue OR a.scale<>e.ScaleValue OR a.is_nullable<>e.Nullable
 OR ISNULL(a.collation_name,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(e.CollationName,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS OR a.is_identity<>0)
 THROW 56582,N''TASK_PHYSICAL_TASKLOGGINGCOVERAGE'',1;
-- S02: overlapping different IDs with the same display name remain separate.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleSame'',@A,@Id,''20260101 00:00:00'',''20270101'',0),
 (2,N''OnPreExecute'',N''ExampleSame'',@B,@Id,''20260101 00:00:01'',''20270101'',0),
 (3,N''OnPostExecute'',N''ExampleSame'',@B,@Id,''20260101 00:00:03'',''20270101'',0),
 (4,N''OnPostExecute'',N''ExampleSame'',@A,@Id,''20260101 00:00:04'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C003|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C003|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56503,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'')=N''4000'' AND JSON_VALUE(@J,''$.taskDurations[1].TotalDurationMs'')=N''2000'' AND JSON_VALUE(@J,''$.taskDurations[0].SourceType'')=N''UNRESOLVED'') THROW 56504,N''TASK_S02_SEPARATE_SOURCES'',1;
DECLARE @ExpectedIdentities TABLE(SourceId uniqueidentifier NOT NULL,FirstId int NOT NULL,LastId int NOT NULL,Ids nvarchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
INSERT @ExpectedIdentities VALUES(@A,1,4,N''[1,4]''),(@B,2,3,N''[2,3]'');
IF (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.taskDurations''))<>2 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.taskLoggingCoverage''))<>2
 OR EXISTS(SELECT 1 FROM @ExpectedIdentities AS e WHERE
 (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.taskDurations'') WITH(ExecutionId uniqueidentifier,SourceId uniqueidentifier,PairKind varchar(16),BasisFirstLogId int,BasisLastLogId int,EvidenceLogIdsJson nvarchar(max)) AS a
 WHERE a.ExecutionId=@Id AND a.SourceId=e.SourceId AND a.PairKind COLLATE SQL_Latin1_General_CP1_CS_AS=''EXECUTE'' AND a.BasisFirstLogId=e.FirstId AND a.BasisLastLogId=e.LastId AND CONVERT(varbinary(max),a.EvidenceLogIdsJson)=CONVERT(varbinary(max),e.Ids))<>1
 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.taskLoggingCoverage'') WITH(ExecutionId uniqueidentifier,SourceId uniqueidentifier,UnresolvedLogId int,BasisFirstLogId int,BasisLastLogId int,EvidenceLogIdsJson nvarchar(max)) AS a
 WHERE a.ExecutionId=@Id AND a.SourceId=e.SourceId AND a.UnresolvedLogId IS NULL AND a.BasisFirstLogId=e.FirstId AND a.BasisLastLogId=e.LastId AND CONVERT(varbinary(max),a.EvidenceLogIdsJson)=CONVERT(varbinary(max),e.Ids))<>1)
 THROW 56584,N''TASK_INDEPENDENT_IDENTITIES_EVIDENCE_BASIS'',1;
IF EXISTS(SELECT 1 FROM OPENJSON(@J,''$.taskDurations'') WITH(PairRowCount bigint,ValidPairCount bigint,UnknownTimePairCount bigint,NonMonotonicPairCount bigint,OpenStartCount bigint,OpenEndCount bigint,AmbiguousBoundaryCount bigint) AS a
 WHERE CASE WHEN a.PairRowCount=a.ValidPairCount+a.UnknownTimePairCount+a.NonMonotonicPairCount+a.OpenStartCount+a.OpenEndCount+a.AmbiguousBoundaryCount THEN 1 ELSE 0 END=0)
 OR EXISTS(SELECT 1 FROM OPENJSON(@J,''$.taskLoggingCoverage'') WITH(ObservedEventCount bigint,ExecuteStartCount bigint,ExecuteEndCount bigint,ValidateStartCount bigint,ValidateEndCount bigint,KnownOtherEventCount bigint,UnknownEventNameCount bigint,MissingEventNameCount bigint) AS a
 WHERE CASE WHEN a.ObservedEventCount=a.ExecuteStartCount+a.ExecuteEndCount+a.ValidateStartCount+a.ValidateEndCount+a.KnownOtherEventCount+a.UnknownEventNameCount+a.MissingEventNameCount THEN 1 ELSE 0 END=0)
 THROW 56585,N''TASK_INDEPENDENT_COUNT_DECOMPOSITIONS'',1;

-- S03: leading end, one middle pair and trailing start.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:00'',''20270101'',0),
 (2,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:01'',''20270101'',0),
 (3,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:03'',''20270101'',0),
 (4,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:04'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C004|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C004|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56505,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].ValidPairCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].OpenStartCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].OpenEndCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'')=N''2000'' AND JSON_VALUE(@J,''$.taskDurations[0].MetricStatus'')=N''INCOMPLETE_BOUNDARIES'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].IncompleteBoundaryCount'')=N''2'') THROW 56506,N''TASK_S03_OPEN'',1;
-- S04: one ambiguous source does not invalidate the other source.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (3,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (4,N''OnPreExecute'',N''ExampleTask'',@B,@Id,''20260101'',''20270101'',0),
 (5,N''OnPostExecute'',N''ExampleTask'',@B,@Id,''20260101'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C005|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C005|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56507,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].AmbiguousBoundaryCount'')=N''3'' AND JSON_VALUE(@J,''$.taskDurations[0].ValidPairCount'')=N''0'' AND JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'') IS NULL AND JSON_VALUE(@J,''$.taskDurations[0].AverageDurationMs'') IS NULL AND JSON_VALUE(@J,''$.taskDurations[0].MinDurationMs'') IS NULL AND JSON_VALUE(@J,''$.taskDurations[0].MaxDurationMs'') IS NULL AND JSON_VALUE(@J,''$.taskDurations[1].ValidPairCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[1].TotalDurationMs'')=N''0'') THROW 56508,N''TASK_S04_AMBIGUOUS'',1;
-- S05: datetime precision, missing/reversed values and DATEDIFF_BIG range.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,NULL,''20270101'',0),
 (2,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (3,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260102'',''20270101'',0),
 (4,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (5,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''17530101'',''20270101'',0),
 (6,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''99991231'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C006|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C006|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56509,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].UnknownTimePairCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].NonMonotonicPairCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].ValidPairCount'')=N''1'' AND JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'')=N''260250019200000'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].InvalidTimePairCount'')=N''2'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].MissingEventTimeCount'')=N''1'') THROW 56510,N''TASK_S05_TIME'',1;
-- S06: ordinal trailing-space conflict and NULL IDs retain original log identities.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''OnPostExecute'',N''ExampleTask '',@A,@Id,''20260101'',''20270101'',0),
 (3,N''OnPreExecute'',N''ExampleUnknown'',NULL,@Id,''20260101'',''20270101'',0),
 (4,N''OnPostExecute'',N''ExampleUnknown'',NULL,@Id,''20260101'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C007|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C007|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56511,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].SourceName'') IS NULL AND JSON_VALUE(@J,''$.taskDurations[0].SourceNameConflict'')=N''true'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].UnresolvedLogId'')=N''3'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[2].UnresolvedLogId'')=N''4'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].ObservedEventCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].UnresolvedBoundaryCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].CoverageStatus'')=N''UNRESOLVED_SOURCE'' AND (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.taskDurations''))=1) THROW 56512,N''TASK_S06_IDENTITIES'',1;
-- S07: observed non-boundaries and empty source are not missing-task/configuration evidence.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnError'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''ExampleUnknownEvent'',N''ExampleTask'',@B,@Id,NULL,''20270101'',0),
 (3,NULL,N''ExampleTask'',@B,@Id,''20260101'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C008|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C008|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56513,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskLoggingCoverage[0].KnownOtherEventCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].UnknownEventNameCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].MissingEventNameCount'')=N''1'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[1].CoverageStatus'')=N''NO_BOUNDARY_OBSERVED'' AND JSON_QUERY(@J,''$.taskDurations'')=N''[]'') THROW 56514,N''TASK_S07_OBSERVED_ONLY'',1;
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C009|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C009|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56515,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.sourceStatus[4].StatusCode'')=N''AVAILABLE_EMPTY'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'')=N''0'' AND JSON_QUERY(@J,''$.taskLoggingCoverage'')=N''[]'') THROW 56516,N''TASK_S07_EMPTY'',1;
-- S08: N+1 sentinel cannot provide an end/name. Duplicate sentinel rejects the buffer.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''OnPostExecute'',N''ExampleConflict'',@A,@Id,''20260101 00:00:01'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C010|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=1,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C010|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56517,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].SourceName'')=N''ExampleTask'' AND JSON_VALUE(@J,''$.taskDurations[0].EvidenceLogIdsJson'')=N''[1]'' AND JSON_VALUE(@J,''$.taskDurations[0].InputIsTruncated'')=N''true'' AND JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'') IS NULL) THROW 56518,N''TASK_S08_SENTINEL'',1;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C011|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=2,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C011|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56519,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].TotalDurationMs'')=N''1000'' AND JSON_VALUE(@J,''$.taskDurations[0].InputIsTruncated'')=N''false'') THROW 56520,N''TASK_S08_EXACT_CAP'',1;
UPDATE dbo.ExampleSsisTaskLogSource SET id=1 WHERE id=2;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C012|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=1,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C012|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56521,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.sourceStatus[4].Detail'')=N''NO_VALID_EVENT_BUFFER'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'') IS NULL AND JSON_QUERY(@J,''$.taskDurations'')=N''[]'') THROW 56522,N''TASK_S08_DUPLICATE_SENTINEL'',1;
-- S09 physical schemas and all-field TABLE/JSON parity are checked above; grid counts are tested by the native consumer.
-- S10: default / 0 / NULL keep v1 output. New disabled TABLE mapping is rejected before source read.
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C013|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J0 OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C013|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C014|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@IncludeTaskAnalysis=0; SET @CiMarker=CONCAT(N''CI_AFTER|203|C014|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C015|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@JNull OUTPUT,@IncludeTaskAnalysis=NULL; SET @CiMarker=CONCAT(N''CI_AFTER|203|C015|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J0,''$.meta.SchemaVersion'')=N''1'' AND JSON_VALUE(@J,''$.meta.SchemaVersion'')=N''1'' AND JSON_VALUE(@JNull,''$.meta.SchemaVersion'')=N''1'' AND JSON_QUERY(@J0,''$.taskDurations'') IS NULL AND JSON_QUERY(@J,''$.taskDurations'') IS NULL AND JSON_QUERY(@JNull,''$.taskLoggingCoverage'') IS NULL AND (SELECT COUNT_BIG(*) FROM OPENJSON(@J,''$.sourceStatus''))=4) THROW 56523,N''TASK_S10_DEFAULT'',1;
BEGIN TRY
 SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C016|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
 EXEC [monitor].[USP_SsisLegacyLogAnalysis] @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"taskDurations":"#ExampleTaskDuration"}''; SET @CiMarker=CONCAT(N''CI_AFTER|203|C016|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
 THROW 56583,N''TASK_DISABLED_MAPPING_ACCEPTED'',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51011 THROW; END CATCH;
-- S11: no message-column access; IncludeTimeline is an export option only.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:02'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C017|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C017|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56524,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
SET @J0=@J; ALTER TABLE dbo.ExampleSsisTaskLogSource DROP COLUMN message;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C018|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@IncludeMessages=0,@IncludeTimeline=0; SET @CiMarker=CONCAT(N''CI_AFTER|203|C018|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56525,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE CONVERT(varbinary(max),JSON_QUERY(@J,''$.taskDurations''))=CONVERT(varbinary(max),JSON_QUERY(@J0,''$.taskDurations'')) AND JSON_QUERY(@J,''$.timeline'')=N''[]'') THROW 56526,N''TASK_S11_MESSAGE_OPTOUT'',1;
-- S12: absent source and existing high-impact guard do not become successful empty analysis.
CREATE USER ExampleTaskLogReader WITHOUT LOGIN;
DECLARE @OwnedUserId int=(SELECT principal_id FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleTaskLogReader'');
IF @OwnedUserId IS NULL THROW 56586,N''TASK_OWN_READER_ID_NOT_CAPTURED'',1;
UPDATE #ExampleSsisTaskOwnership SET UserId=@OwnedUserId;
GRANT EXECUTE ON [monitor].[USP_SsisLegacyLogAnalysis] TO ExampleTaskLogReader;
GRANT VIEW DEFINITION ON dbo.ExampleSsisTaskLogSource TO ExampleTaskLogReader;
DENY SELECT ON dbo.ExampleSsisTaskLogSource TO ExampleTaskLogReader;
DECLARE @DirectDenied int=NULL,@DirectMessage nvarchar(4000)=NULL,@Impersonated bit=0;
BEGIN TRY
 EXECUTE AS USER=N''ExampleTaskLogReader'';SET @Impersonated=1;
 BEGIN TRY
  EXEC(N''SELECT COUNT_BIG(*) FROM dbo.ExampleSsisTaskLogSource;'');
 END TRY BEGIN CATCH SELECT @DirectDenied=ERROR_NUMBER(),@DirectMessage=ERROR_MESSAGE(); END CATCH;
 SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C019|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
 EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
  @IncludeTaskAnalysis=1,@IncludeMessages=0,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
  @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C019|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
 REVERT;SET @Impersonated=0;
END TRY BEGIN CATCH
 IF @Impersonated=1 BEGIN TRY REVERT; END TRY BEGIN CATCH SELECT ERROR_NUMBER() AS RevertError,ERROR_MESSAGE() AS RevertMessage; END CATCH;
 THROW;
END CATCH;
SELECT @DirectDenied AS DirectSqlError,@DirectMessage AS DirectSqlMessage,@Error AS AnalyzerSqlError,@Message AS AnalyzerSqlMessage,@J AS OptInCapture;
IF NOT EXISTS(SELECT 1 WHERE @DirectDenied=229 AND @Error=229 AND CONVERT(varbinary(max),@Message)=CONVERT(varbinary(max),@DirectMessage)
 AND JSON_VALUE(@J,''$.meta.StatusCode'')=N''DENIED'' AND JSON_VALUE(@J,''$.sourceStatus[4].StatusCode'')=N''NOT_READ''
 AND JSON_VALUE(@J,''$.sourceStatus[4].Detail'')=N''NO_VALID_EVENT_BUFFER'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'') IS NULL
 AND JSON_QUERY(@J,''$.taskDurations'')=N''[]'' AND JSON_QUERY(@J,''$.taskLoggingCoverage'')=N''[]'')
 THROW 56587,N''TASK_OPTIN_REAL_DENIED_REFERENCE'',1;
IF (SELECT principal_id FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleTaskLogReader'')<>@OwnedUserId THROW 56588,N''TASK_OWN_READER_ID_CHANGED'',1;
DROP USER ExampleTaskLogReader;
UPDATE #ExampleSsisTaskOwnership SET UserId=NULL;

SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C020|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleMissingTaskLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C020|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.sourceStatus[4].Detail'')=N''NO_VALID_EVENT_BUFFER'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'') IS NULL) THROW 56527,N''TASK_S12_ABSENT'',1;
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C021|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@ExecutionId=@Id,@IncludeTaskAnalysis=1,@MaxZeilen=0,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT; SET @CiMarker=CONCAT(N''CI_AFTER|203|C021|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.meta.StatusCode'')=N''INVALID_PARAMETER'' AND JSON_VALUE(@J,''$.sourceStatus[4].Detail'')=N''INVALID_PARAMETER'' AND JSON_VALUE(@J,''$.sourceStatus[4].ObservedRowCount'') IS NULL) THROW 56528,N''TASK_S12_HIGH_IMPACT'',1;
-- S13 uses the separately bound private extracted-stage harness; it is not an original-SUT fault claim.
-- S14: zero-duration and rounding, disjoint counts, caller restoration.
TRUNCATE TABLE dbo.ExampleSsisTaskLogSource;
INSERT dbo.ExampleSsisTaskLogSource (id,event,source,sourceid,executionid,starttime,endtime,datacode) VALUES
 (1,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (2,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (3,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (4,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (5,N''OnPreExecute'',N''ExampleTask'',@A,@Id,''20260101'',''20270101'',0),
 (6,N''OnPostExecute'',N''ExampleTask'',@A,@Id,''20260101 00:00:00.003'',''20270101'',0);
SET @CiOrdinal+=1; SET @CiMarker=CONCAT(N''CI_CASE|203|C022|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisTaskLogSource'',@ExecutionId=@Id,
 @IncludeTaskAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@IncludeMessages=0; SET @CiMarker=CONCAT(N''CI_AFTER|203|C022|'',@CiOrdinal,N''|'',CONVERT(varchar(27),SYSUTCDATETIME(),126),N''Z|'',@@SPID,N''|'',@@LOCK_TIMEOUT,N''|'',LEFT(CONCAT(N''-'',N''''),180)); RAISERROR(N''%s'',10,1,@CiMarker) WITH NOWAIT;
IF NOT EXISTS(SELECT 1 WHERE ISJSON(@J)=1 AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskDurations'' AND [type]=4) AND EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''taskLoggingCoverage'' AND [type]=4)) THROW 56529,N''TASK_REQUIRED_OPTIN_ARRAYS'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.taskDurations[0].ValidPairCount'')=N''3'' AND JSON_VALUE(@J,''$.taskDurations[0].AverageDurationMs'')=N''1.000000'' AND JSON_VALUE(@J,''$.taskDurations[0].MinDurationMs'')=N''0'' AND JSON_VALUE(@J,''$.taskDurations[0].PairRowCount'')=N''3'' AND JSON_VALUE(@J,''$.taskLoggingCoverage[0].ObservedEventCount'')=N''6'') THROW 56530,N''TASK_S14_DECIMAL_ZERO'',1;
IF NOT EXISTS(SELECT 1 WHERE @@OPTIONS=@Options AND @@LOCK_TIMEOUT=@Lock AND @@TRANCOUNT=@Tran) THROW 56531,N''TASK_S14_CALLER'',1;
SELECT N''AVAILABLE'' AS StatusCode,N''SSIS task analysis synthetic contract'' AS Detail;
END;');

 SELECT @ProcId=object_id FROM sys.procedures WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisTaskFixtureScope';
 IF @ProcId IS NULL THROW 56592,N'TASK_OWN_PROC_NOT_CAPTURED',1;
 EXEC dbo.ExampleSsisTaskFixtureScope @OwnedTableId=@TableId OUTPUT;
 IF DB_ID()<>@DbId OR OBJECT_ID(N'dbo.ExampleSsisTaskLogSource')<>@TableId OR OBJECT_ID(N'dbo.ExampleSsisTaskFixtureScope')<>@ProcId THROW 56593,N'TASK_CLEANUP_BINDING',1;
 DROP TABLE dbo.ExampleSsisTaskLogSource;
 DROP PROCEDURE dbo.ExampleSsisTaskFixtureScope;
 IF @@OPTIONS<>@OuterOptions OR @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTran THROW 56594,N'TASK_OUTER_CALLER',1;
END TRY
BEGIN CATCH
 DECLARE @OriginalError int=ERROR_NUMBER(),@OriginalMessage nvarchar(4000)=ERROR_MESSAGE();
 DECLARE @CleanupError nvarchar(4000)=N'',@ScopeValid bit=0;
 BEGIN TRY
  IF DB_ID()<>@DbId OR OBJECT_ID(N'tempdb..#ExampleSsisTaskOwnership')<>@OwnershipId THROW 56595,N'TASK_FAILURE_CLEANUP_SCOPE',1;
  SELECT @TableId=TableId,@UserId=UserId FROM #ExampleSsisTaskOwnership;
  SET @ScopeValid=1;
 END TRY BEGIN CATCH SET @CleanupError=ERROR_MESSAGE(); END CATCH;
 IF @ScopeValid=1
 BEGIN
  BEGIN TRY
   IF @UserId IS NOT NULL AND EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE principal_id=@UserId AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTaskLogReader') DROP USER ExampleTaskLogReader;
  END TRY BEGIN CATCH SET @CleanupError+=N' User: '+ERROR_MESSAGE(); END CATCH;
  BEGIN TRY
   IF @TableId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleSsisTaskLogSource')=@TableId DROP TABLE dbo.ExampleSsisTaskLogSource;
  END TRY BEGIN CATCH SET @CleanupError+=N' Table: '+ERROR_MESSAGE(); END CATCH;
  BEGIN TRY
   IF @ProcId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleSsisTaskFixtureScope')=@ProcId DROP PROCEDURE dbo.ExampleSsisTaskFixtureScope;
  END TRY BEGIN CATCH SET @CleanupError+=N' Proc: '+ERROR_MESSAGE(); END CATCH;
 END;
 BEGIN TRY
  IF OBJECT_ID(N'tempdb..#ExampleSsisTaskOwnership')=@OwnershipId DROP TABLE #ExampleSsisTaskOwnership;
 END TRY BEGIN CATCH SET @CleanupError+=N' Temp: '+ERROR_MESSAGE(); END CATCH;
 SELECT @OriginalError AS OriginalError,@OriginalMessage AS OriginalMessage,@CleanupError AS CleanupError;
 THROW;
END CATCH;
DROP TABLE #ExampleSsisTaskOwnership;
DECLARE @CiFileMarker nvarchar(400)=CONCAT(N'CI_END|203|file|0|',CONVERT(varchar(27),SYSUTCDATETIME(),126),N'Z|',@@SPID,N'|',@@LOCK_TIMEOUT,N'|-');
RAISERROR(N'%s',10,1,@CiFileMarker) WITH NOWAIT;
GO
