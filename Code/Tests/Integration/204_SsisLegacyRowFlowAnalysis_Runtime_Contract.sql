USE [DeineDatenbank];
GO
/* Synthetic observed-event tests; no provider-generation claim. */
DECLARE @DbId int=DB_ID(),@ProcId int=NULL,@TableId int=NULL,@UserId int=NULL;
DECLARE @OuterOptions int=@@OPTIONS,@OuterLock int=@@LOCK_TIMEOUT,@OuterTran int=@@TRANCOUNT;
IF OBJECT_ID(N'tempdb..#ExampleSsisRowFlowOwnership') IS NOT NULL THROW 56690,N'ROWFLOW_FOREIGN_OWNERSHIP_TEMP',1;
IF EXISTS(SELECT 1 FROM sys.all_objects WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleSsisRowFlowFixtureScope',N'ExampleSsisRowFlowLogSource')) THROW 56691,N'ROWFLOW_FOREIGN_FIXTURE',1;
IF EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRowFlowLogReader') THROW 56696,N'ROWFLOW_FOREIGN_READER',1;
CREATE TABLE #ExampleSsisRowFlowOwnership(TableId int NULL,UserId int NULL);
INSERT #ExampleSsisRowFlowOwnership VALUES(NULL,NULL);
DECLARE @OwnershipId int=OBJECT_ID(N'tempdb..#ExampleSsisRowFlowOwnership');
BEGIN TRY
 EXEC(N'CREATE PROCEDURE dbo.ExampleSsisRowFlowFixtureScope @OwnedTableId int OUTPUT AS BEGIN
SET NOCOUNT ON;
DECLARE @Db sysname=(SELECT name FROM sys.databases WITH (NOLOCK) WHERE database_id=DB_ID());
DECLARE @Id uniqueidentifier=''00000000-0000-0000-0000-000000000001'',@A uniqueidentifier=''00000000-0000-0000-0000-000000000010'',@B uniqueidentifier=''00000000-0000-0000-0000-000000000020'';
DECLARE @Status varchar(40),@Partial bit;
DECLARE @J nvarchar(max),@J0 nvarchar(max),@Error int,@Message nvarchar(4000),@DirectError int,@DirectMessage nvarchar(4000);
DECLARE @Options int=@@OPTIONS,@Lock int=@@LOCK_TIMEOUT,@Tran int=@@TRANCOUNT,@Xact int=XACT_STATE();
CREATE TABLE dbo.ExampleSsisRowFlowLogSource
([id] int NOT NULL,[event] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[source] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [sourceid] uniqueidentifier NULL,[executionid] uniqueidentifier NULL,[starttime] datetime NULL,[endtime] datetime NULL,[datacode] int NULL,[message] nvarchar(2048) NULL);
SELECT @OwnedTableId=object_id FROM sys.tables WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleSsisRowFlowLogSource'';
UPDATE #ExampleSsisRowFlowOwnership SET TableId=@OwnedTableId;

-- R-S01: expected values are authored independently of the decoder, including every new field.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-01'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
DECLARE @ExpectedrowFlowEvents nvarchar(max)=N''{"RowFlowEventOrdinal":1,"ExecutionId":"00000000-0000-0000-0000-000000000001","LogId":2,"SourceId":"00000000-0000-0000-0000-000000000010","SourceName":"ExampleFlow","EventTime":"2026-01-01T00:00:01","ParserId":"ORPS_EN_1","ParseStatus":"PARSED","PathId":1,"PathName":"ExamplePath","DestinationComponentId":2,"DestinationComponentName":"ExampleDestination","InputId":3,"InputName":"ExampleInput","RowsSent":7,"OccurrenceStartLogId":1,"OccurrenceEndLogId":99,"GroupingStatus":"ASSIGNED","InputIsTruncated":false}'';
IF EXISTS(SELECT [key],value,type FROM OPENJSON(JSON_QUERY(@J,''$.rowFlowEvents[0]'')) EXCEPT SELECT [key],value,type FROM OPENJSON(@ExpectedrowFlowEvents)) OR EXISTS(SELECT [key],value,type FROM OPENJSON(@ExpectedrowFlowEvents) EXCEPT SELECT [key],value,type FROM OPENJSON(JSON_QUERY(@J,''$.rowFlowEvents[0]''))) THROW 56602,N''ROWFLOW_ALL_FIELDS_rowFlowEvents'',1;
DECLARE @ExpectedrowFlow nvarchar(max)=N''{"RowFlowOrdinal":1,"ExecutionId":"00000000-0000-0000-0000-000000000001","SourceId":"00000000-0000-0000-0000-000000000010","SourceName":"ExampleFlow","OccurrenceStartLogId":1,"OccurrenceEndLogId":99,"PathId":1,"PathName":"ExamplePath","DestinationComponentId":2,"DestinationComponentName":"ExampleDestination","InputId":3,"InputName":"ExampleInput","EventCount":1,"RowsSentSum":7,"MinRowsSent":7,"MaxRowsSent":7,"FirstObservedTime":"2026-01-01T00:00:01","LastObservedTime":"2026-01-01T00:00:01","EvidenceLogIdsJson":"[2]","SourceNameConflict":false,"PathNameConflict":false,"DestinationNameConflict":false,"InputNameConflict":false,"InputIsTruncated":false,"CoverageStatus":"OBSERVED_TRANSFERS"}'';
IF EXISTS(SELECT [key],value,type FROM OPENJSON(JSON_QUERY(@J,''$.rowFlow[0]'')) EXCEPT SELECT [key],value,type FROM OPENJSON(@ExpectedrowFlow)) OR EXISTS(SELECT [key],value,type FROM OPENJSON(@ExpectedrowFlow) EXCEPT SELECT [key],value,type FROM OPENJSON(JSON_QUERY(@J,''$.rowFlow[0]''))) THROW 56602,N''ROWFLOW_ALL_FIELDS_rowFlow'',1;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.meta.SchemaVersion'')=N''3'' AND JSON_VALUE(@J,N''$.meta.RowFlowCatalogVersion'')=N''1'' AND (SELECT COUNT(*) FROM OPENJSON(@J,''$.rowFlowEvents''))=1 AND (SELECT COUNT(*) FROM OPENJSON(@J,''$.rowFlow''))=1) THROW 56601,N''ROWFLOW_S01_SHAPES'',1;
CREATE TABLE #ExampleRowEvents(Seed int NULL);CREATE TABLE #ExampleRowGroups(Seed int NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@ResultTablesJson=N''{"rowFlowEvents":"#ExampleRowEvents","rowFlow":"#ExampleRowGroups"}'';
SELECT N''R-Consumer-02'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
DECLARE @PhysicalrowFlowEvents nvarchar(max);EXEC sys.sp_executesql N''SELECT @T=(SELECT * FROM #ExampleRowEvents ORDER BY RowFlowEventOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES)'',N''@T nvarchar(max) OUTPUT'',@T=@PhysicalrowFlowEvents OUTPUT;
IF NOT EXISTS(SELECT 1 WHERE CONVERT(varbinary(max),@PhysicalrowFlowEvents)=CONVERT(varbinary(max),JSON_QUERY(@J,''$.rowFlowEvents''))) THROW 56601,N''ROWFLOW_TABLE_JSON_rowFlowEvents'',1;
IF EXISTS(SELECT 1 FROM (VALUES (1,N''RowFlowEventOrdinal'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
(2,N''ExecutionId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
(3,N''LogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(4,N''SourceId'',N''uniqueidentifier'',16,0,0,1,CONVERT(sysname,NULL)),
(5,N''SourceName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(6,N''EventTime'',N''datetime'',8,23,3,1,CONVERT(sysname,NULL)),
(7,N''ParserId'',N''varchar'',32,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(8,N''ParseStatus'',N''varchar'',40,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(9,N''PathId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
(10,N''PathName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(11,N''DestinationComponentId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
(12,N''DestinationComponentName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(13,N''InputId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
(14,N''InputName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(15,N''RowsSent'',N''bigint'',8,19,0,1,CONVERT(sysname,NULL)),
(16,N''OccurrenceStartLogId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
(17,N''OccurrenceEndLogId'',N''int'',4,10,0,1,CONVERT(sysname,NULL)),
(18,N''GroupingStatus'',N''varchar'',40,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(19,N''InputIsTruncated'',N''bit'',1,1,0,0,CONVERT(sysname,NULL))) AS e(Ordinal,Name,TypeName,MaxLength,PrecisionValue,ScaleValue,Nullable,CollationName)
FULL JOIN (SELECT ROW_NUMBER() OVER(ORDER BY c.column_id) AS Ordinal,c.name,t.name AS TypeName,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity,c.is_computed
 FROM tempdb.sys.columns AS c WITH (NOLOCK) INNER JOIN tempdb.sys.types AS t WITH (NOLOCK) ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleRowEvents'')) AS a ON a.Ordinal=e.Ordinal
WHERE a.Ordinal IS NULL OR e.Ordinal IS NULL OR CONVERT(varbinary(max),a.name)<>CONVERT(varbinary(max),e.Name) OR a.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS<>e.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS
OR a.max_length<>e.MaxLength OR a.precision<>e.PrecisionValue OR a.scale<>e.ScaleValue OR a.is_nullable<>e.Nullable OR a.is_identity<>0 OR a.is_computed<>0
OR ISNULL(a.collation_name,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(e.CollationName,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 56603,N''ROWFLOW_PHYSICAL_rowFlowEvents'',1;
DECLARE @PhysicalrowFlow nvarchar(max);EXEC sys.sp_executesql N''SELECT @T=(SELECT * FROM #ExampleRowGroups ORDER BY RowFlowOrdinal FOR JSON PATH,INCLUDE_NULL_VALUES)'',N''@T nvarchar(max) OUTPUT'',@T=@PhysicalrowFlow OUTPUT;
IF NOT EXISTS(SELECT 1 WHERE CONVERT(varbinary(max),@PhysicalrowFlow)=CONVERT(varbinary(max),JSON_QUERY(@J,''$.rowFlow''))) THROW 56601,N''ROWFLOW_TABLE_JSON_rowFlow'',1;
IF EXISTS(SELECT 1 FROM (VALUES (1,N''RowFlowOrdinal'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
(2,N''ExecutionId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
(3,N''SourceId'',N''uniqueidentifier'',16,0,0,0,CONVERT(sysname,NULL)),
(4,N''SourceName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(5,N''OccurrenceStartLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(6,N''OccurrenceEndLogId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(7,N''PathId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(8,N''PathName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(9,N''DestinationComponentId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(10,N''DestinationComponentName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(11,N''InputId'',N''int'',4,10,0,0,CONVERT(sysname,NULL)),
(12,N''InputName'',N''nvarchar'',8000,0,0,1,N''SQL_Latin1_General_CP1_CS_AS''),
(13,N''EventCount'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
(14,N''RowsSentSum'',N''decimal'',17,38,0,0,CONVERT(sysname,NULL)),
(15,N''MinRowsSent'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
(16,N''MaxRowsSent'',N''bigint'',8,19,0,0,CONVERT(sysname,NULL)),
(17,N''FirstObservedTime'',N''datetime'',8,23,3,0,CONVERT(sysname,NULL)),
(18,N''LastObservedTime'',N''datetime'',8,23,3,0,CONVERT(sysname,NULL)),
(19,N''EvidenceLogIdsJson'',N''nvarchar'',-1,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(20,N''SourceNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
(21,N''PathNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
(22,N''DestinationNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
(23,N''InputNameConflict'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
(24,N''InputIsTruncated'',N''bit'',1,1,0,0,CONVERT(sysname,NULL)),
(25,N''CoverageStatus'',N''varchar'',40,0,0,0,N''SQL_Latin1_General_CP1_CS_AS'')) AS e(Ordinal,Name,TypeName,MaxLength,PrecisionValue,ScaleValue,Nullable,CollationName)
FULL JOIN (SELECT ROW_NUMBER() OVER(ORDER BY c.column_id) AS Ordinal,c.name,t.name AS TypeName,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity,c.is_computed
 FROM tempdb.sys.columns AS c WITH (NOLOCK) INNER JOIN tempdb.sys.types AS t WITH (NOLOCK) ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleRowGroups'')) AS a ON a.Ordinal=e.Ordinal
WHERE a.Ordinal IS NULL OR e.Ordinal IS NULL OR CONVERT(varbinary(max),a.name)<>CONVERT(varbinary(max),e.Name) OR a.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS<>e.TypeName COLLATE SQL_Latin1_General_CP1_CS_AS
OR a.max_length<>e.MaxLength OR a.precision<>e.PrecisionValue OR a.scale<>e.ScaleValue OR a.is_nullable<>e.Nullable OR a.is_identity<>0 OR a.is_computed<>0
OR ISNULL(a.collation_name,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(e.CollationName,N'''') COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 56603,N''ROWFLOW_PHYSICAL_rowFlow'',1;
-- R-S02: multiple stored transfers, including explicit zero and repeated payloads with distinct IDs.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 3''),
 (3,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 0''),
 (4,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 8''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-03'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlow[0].EventCount'')=N''3'' AND JSON_VALUE(@J,N''$.rowFlow[0].RowsSentSum'')=N''11'' AND JSON_VALUE(@J,N''$.rowFlow[0].MinRowsSent'')=N''0'' AND JSON_VALUE(@J,N''$.rowFlow[0].MaxRowsSent'')=N''8'' AND JSON_VALUE(@J,N''$.rowFlow[0].EvidenceLogIdsJson'')=N''[2,3,4]'') THROW 56601,N''ROWFLOW_S02_SUMS'',1;
-- R-S03/S04/S06: exact event/profile grammar, no partial payload, numeric range and decimal sums.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 0''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-04'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_GRAMMAR_zero'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',NULL),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-05'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MESSAGE_MISSING'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_null'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-06'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''UNSUPPORTED_FORMAT'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_empty'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Zeilen wurden gesendet''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-07'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''UNSUPPORTED_FORMAT'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_locale'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''rows were provided to a data flow component as input. : : 1 : examplepath : 2 : exampledestination : 3 : exampleinput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-08'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''UNSUPPORTED_FORMAT'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_prefixcase'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 9223372036854775808''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-09'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''NUMERIC_OUT_OF_RANGE'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_overflow'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 0 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-10'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''NUMERIC_OUT_OF_RANGE'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_idzero'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 2147483647 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 9223372036854775807''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-11'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_GRAMMAR_idmax'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 2147483648 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-12'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''NUMERIC_OUT_OF_RANGE'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_idlarge'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : -1''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-13'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_negative'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : +1''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-14'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_plus'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 01''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-15'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_leadingzero'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7 ''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-16'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_space'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 1.0''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-17'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_decimal'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 1e3''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-18'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_exponent'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7 : 8''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-19'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_extra'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-20'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_few'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path:Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-21'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_colon'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path''+NCHAR(13)+N''Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-22'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_cr'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path''+NCHAR(10)+N''Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-23'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_lf'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path''+NCHAR(9)+N''Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-24'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_tab'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path''+NCHAR(0)+N''Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-25'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_nul'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : Path\u0000Name : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-26'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_GRAMMAR_literalnul'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 :  : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-27'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].RowsSent'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_GRAMMAR_emptyname'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 9223372036854775807''),
 (3,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 9223372036854775807''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-28'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlow[0].RowsSentSum'')=N''18446744073709551614'') THROW 56601,N''ROWFLOW_S04_DECIMAL'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent '',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (3,N''onpipelinerowssent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-29'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'' AND EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.StatusCode'')=N''AVAILABLE_EMPTY'')) THROW 56601,N''ROWFLOW_S03_ORDINAL_EVENT'',1;
-- R-S05: source and payload name conflicts use exact UTF-16 including trailing spaces.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : PfadΩ : 2 : ExampleSame : 3 : Input  : 7''),
 (3,N''OnPipelineRowsSent'',N''ExampleFlow '',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : pfadΩ : 2 : ExampleSame  : 3 : Input : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-30'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlow[0].SourceNameConflict'')=N''true'' AND JSON_VALUE(@J,N''$.rowFlow[0].PathNameConflict'')=N''true'' AND JSON_VALUE(@J,N''$.rowFlow[0].DestinationNameConflict'')=N''true'' AND JSON_VALUE(@J,N''$.rowFlow[0].InputNameConflict'')=N''true'' AND JSON_VALUE(@J,''$.rowFlow[0].SourceName'') IS NULL AND JSON_VALUE(@J,''$.rowFlow[0].PathName'') IS NULL) THROW 56601,N''ROWFLOW_S05_NAMES'',1;
-- R-S07: exact byte guard, no LEN-based acceptance at capacity.
DECLARE @Wide nvarchar(max)=N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1900)+N'' : 2 : C : 3 : I : 7'';
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(128) NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),17)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-31'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_S07_128_-1'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),18)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-32'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'') THROW 56601,N''ROWFLOW_S07_128_0'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(2048) NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1937)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-33'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_S07_2048_-1'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1938)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-34'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'') THROW 56601,N''ROWFLOW_S07_2048_0'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(4000) NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1937)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-35'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'') THROW 56601,N''ROWFLOW_S07_4000_-1'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1938)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-36'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'') THROW 56601,N''ROWFLOW_S07_4000_0'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1939)+N'' : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-37'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'') THROW 56601,N''ROWFLOW_S07_4000_1'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(max) NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',REPLICATE(CONVERT(nvarchar(max),N'' ''),2048)),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-38'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'') THROW 56601,N''ROWFLOW_S07_MAX_TRAILING'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(2048) NULL;
-- R-S08/S09: repeated occurrences, missing identity/time, boundary and disjoint path groups.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',NULL,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-39'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].GroupingStatus'')=N''SOURCE_ID_MISSING'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].OccurrenceStartLogId'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S08_missing_source'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,NULL,N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-40'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].GroupingStatus'')=N''EVENT_TIME_MISSING'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].OccurrenceStartLogId'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S08_missing_time'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260102'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-41'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].GroupingStatus'')=N''TIME_OUTSIDE_PAIR'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].OccurrenceStartLogId'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S08_outside'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@B,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-42'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlowEvents[0].GroupingStatus'')=N''NO_OBSERVED_PAIR'' AND JSON_VALUE(@J,''$.rowFlowEvents[0].OccurrenceStartLogId'') IS NULL AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S08_unpaired'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 10''),
 (3,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 2 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 10''),
 (4,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 3 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 2''),
 (5,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',NULL),
 (6,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',NULL),
 (7,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 10''),
 (8,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-43'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE (SELECT COUNT(*) FROM OPENJSON(@J,''$.rowFlow''))=4 AND JSON_VALUE(@J,N''$.rowFlow[0].RowsSentSum'')=N''10'' AND JSON_VALUE(@J,N''$.rowFlow[1].RowsSentSum'')=N''10'' AND JSON_VALUE(@J,N''$.rowFlow[2].RowsSentSum'')=N''2'' AND JSON_VALUE(@J,N''$.rowFlow[3].RowsSentSum'')=N''10'') THROW 56601,N''ROWFLOW_S09_SEPARATE_PATH_OCCURRENCE'',1;
DECLARE @ExpectedPaths TABLE(SourceId uniqueidentifier,OccurrenceStartLogId int,OccurrenceEndLogId int,PathId int,DestinationComponentId int,InputId int,EventCount bigint,RowsSentSum decimal(38,0),EvidenceLogIdsJson nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS);
INSERT @ExpectedPaths VALUES(@A,1,5,1,2,3,1,10,N''[2]''),(@A,1,5,2,2,3,1,10,N''[3]''),(@A,1,5,3,2,3,1,2,N''[4]''),(@A,6,8,1,2,3,1,10,N''[7]'');
DECLARE @ActualPaths TABLE(SourceId uniqueidentifier,OccurrenceStartLogId int,OccurrenceEndLogId int,PathId int,DestinationComponentId int,InputId int,EventCount bigint,RowsSentSum decimal(38,0),EvidenceLogIdsJson nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS);
INSERT @ActualPaths SELECT * FROM OPENJSON(@J,''$.rowFlow'') WITH(SourceId uniqueidentifier,OccurrenceStartLogId int,OccurrenceEndLogId int,PathId int,DestinationComponentId int,InputId int,EventCount bigint,RowsSentSum decimal(38,0),EvidenceLogIdsJson nvarchar(max));
IF (SELECT COUNT(*) FROM @ActualPaths)<>4 OR EXISTS(SELECT * FROM @ActualPaths EXCEPT SELECT * FROM @ExpectedPaths) OR EXISTS(SELECT * FROM @ExpectedPaths EXCEPT SELECT * FROM @ActualPaths) THROW 56606,N''ROWFLOW_S09_EXACT_KEY_EVIDENCE_SET'',1;
-- R-S10: a sentinel never contributes; duplicate ID integrity is checked before its removal.
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=2,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-44'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE (SELECT COUNT(*) FROM OPENJSON(@J,''$.rowFlowEvents''))=1 AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'' AND JSON_VALUE(@J,N''$.rowFlowEvents[0].InputIsTruncated'')=N''true'') THROW 56601,N''ROWFLOW_S10_PREFIX'',1;
INSERT dbo.ExampleSsisRowFlowLogSource SELECT * FROM dbo.ExampleSsisRowFlowLogSource WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=2,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-45'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND EXISTS(SELECT 1 FROM OPENJSON(@J,''$.warnings'') WHERE JSON_VALUE(value,''$.WarningCode'')=N''DUPLICATE_LOG_ID_OBSERVED'')) THROW 56601,N''ROWFLOW_S10_DUPLICATE'',1;
-- R-S11/S12: four opt-ins, invalid mappings and messages opt-out without a message source column.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
 (1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),
 (2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),
 (99,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=0,@IncludeRowFlowAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-46'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.meta.SchemaVersion'')=N''1'' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''rowFlow'') AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'')) THROW 56601,N''ROWFLOW_S11_FLAGS_00'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=1,@IncludeRowFlowAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-47'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.meta.SchemaVersion'')=N''2'' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''rowFlow'') AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'')) THROW 56601,N''ROWFLOW_S11_FLAGS_10'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=0,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-48'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.meta.SchemaVersion'')=N''3'' AND JSON_QUERY(@J,''$.rowFlow'') IS NOT NULL) THROW 56601,N''ROWFLOW_S11_FLAGS_01'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=1,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
SELECT N''R-Consumer-49'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.meta.SchemaVersion'')=N''3'' AND JSON_QUERY(@J,''$.rowFlow'') IS NOT NULL) THROW 56601,N''ROWFLOW_S11_FLAGS_11'',1;
BEGIN TRY EXEC [monitor].[USP_SsisLegacyLogAnalysis] @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"rowFlow":"#ExampleRowGroups"}'',@IncludeRowFlowAnalysis=0;THROW 56604,N''ROWFLOW_MAPPING_GUARD_MISSING'',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>51011 THROW;END CATCH;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@IncludeTimeline=0;
SELECT N''R-Consumer-50'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,N''$.rowFlow[0].RowsSentSum'')=N''7'' AND JSON_QUERY(@J,''$.timeline'')=N''[]'') THROW 56601,N''ROWFLOW_S12_TIMELINE_OFF'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource DROP COLUMN message;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@IncludeMessages=0;
SELECT N''R-Consumer-51'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.Detail'')=N''MESSAGES_DISABLED'' AND JSON_VALUE(value,''$.ObservedRowCount'') IS NULL) AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S12_NO_MESSAGE'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ADD message AS CONVERT(nvarchar(2048),N''ExampleComputed'');
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@IncludeMessages=0;
SELECT N''R-Consumer-52'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.Detail'')=N''MESSAGES_DISABLED'')) THROW 56601,N''ROWFLOW_S12_COMPUTED_OPT_OUT'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-53'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
IF NOT EXISTS(SELECT 1 WHERE JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.Detail'')=N''NO_VALID_EVENT_BUFFER'')) THROW 56601,N''ROWFLOW_S12_COMPUTED_REJECTED'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource DROP COLUMN message;ALTER TABLE dbo.ExampleSsisRowFlowLogSource ADD message nvarchar(2048) NULL;
-- Additional targeted R-S04/05/07/08/10/11/12 edge cases on the unchanged original procedure.
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=REPLACE(message,N'' : 7'',N'' : 1,000'') WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-4'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].ParseStatus'')=N''MALFORMED_PAYLOAD'') THROW 56607,N''ROWFLOW_EDGE_ASCII_LOCALE'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET source=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-9'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlow[0].SourceName'') IS NULL AND JSON_VALUE(@J,''$.rowFlow[0].SourceNameConflict'')=N''false'') THROW 56607,N''ROWFLOW_EDGE_NULL_SOURCE_NAME'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=REPLACE(message,N''ExamplePath'',N''ExamplePath ''+NCHAR(0xD83D)+NCHAR(0xDE00)) WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-14'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'' AND CONVERT(varbinary(max),JSON_VALUE(@J,''$.rowFlow[0].PathName''))=CONVERT(varbinary(max),N''ExamplePath ''+NCHAR(0xD83D)+NCHAR(0xDE00))) THROW 56607,N''ROWFLOW_EDGE_UTF16_SURROGATE'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET starttime=''20260101'';
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-19'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].GroupingStatus'')=N''ASSIGNED'') THROW 56607,N''ROWFLOW_EDGE_EQUAL_TIME'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET starttime=''20251231'' WHERE id=3;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-24'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].GroupingStatus'')=N''NO_OBSERVED_PAIR'') THROW 56607,N''ROWFLOW_EDGE_REVERSED_PAIR'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
UPDATE dbo.ExampleSsisRowFlowLogSource SET starttime=NULL WHERE id=3;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-29'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].GroupingStatus'')=N''NO_OBSERVED_PAIR'') THROW 56607,N''ROWFLOW_EDGE_NULL_PAIR_TIME'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime) VALUES(0,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'');
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-34'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].GroupingStatus'')=N''NO_OBSERVED_PAIR'' AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56607,N''ROWFLOW_EDGE_AMBIGUOUS_V1_STREAM'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=1,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-38'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'' AND EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.ObservedRowCount'')=N''0'')) THROW 56607,N''ROWFLOW_EDGE_CAP_ONE_SENTINEL'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=NULL,@IncludeTaskAnalysis=NULL,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-42'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.meta.SchemaVersion'')=N''1'' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key] IN(N''rowFlow'',N''rowFlowEvents'',N''taskDurations'',N''taskLoggingCoverage''))) THROW 56607,N''ROWFLOW_EDGE_NULL_OPTINS'',1;
CREATE TABLE #ExampleRowEmptyEvents(Seed int NULL);CREATE TABLE #ExampleRowEmptyGroups(Seed int NULL);
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @IncludeRowFlowAnalysis=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"rowFlowEvents":"#ExampleRowEmptyEvents","rowFlow":"#ExampleRowEmptyGroups"}'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-TypedEmpty'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Error AS OutputError,@Message AS OutputMessage;
IF NOT EXISTS(SELECT 1 WHERE @Status=''INVALID_PARAMETER'' AND (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N''tempdb..#ExampleRowEmptyEvents''))=19 AND (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N''tempdb..#ExampleRowEmptyGroups''))=25 AND JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56607,N''ROWFLOW_EDGE_TYPED_EMPTY'',1;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(max) NULL;
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1965)+N'' : 2 : C : 3 : I : 7'' WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-52'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].ParseStatus'')=N''PARSED'' AND CONVERT(varbinary(max),JSON_VALUE(@J,''$.timeline[1].MessageText''))=(SELECT CONVERT(varbinary(max),message) FROM dbo.ExampleSsisRowFlowLogSource WHERE id=2)) THROW 56607,N''ROWFLOW_EDGE_MAX_BOUNDARY_2047'',1;
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1966)+N'' : 2 : C : 3 : I : 7'' WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-56'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'' AND CONVERT(varbinary(max),JSON_VALUE(@J,''$.timeline[1].MessageText''))=(SELECT CONVERT(varbinary(max),message) FROM dbo.ExampleSsisRowFlowLogSource WHERE id=2)) THROW 56607,N''ROWFLOW_EDGE_MAX_BOUNDARY_2048'',1;
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=N''Rows were provided to a data flow component as input. : : 1 : ''+REPLICATE(CONVERT(nvarchar(max),N''X''),1967)+N'' : 2 : C : 3 : I : 7'' WHERE id=2;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-60'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_VALUE(@J,''$.rowFlowEvents[0].ParseStatus'')=N''POTENTIALLY_TRUNCATED'' AND CONVERT(varbinary(max),JSON_VALUE(@J,''$.timeline[1].MessageText''))=(SELECT CONVERT(varbinary(max),message) FROM dbo.ExampleSsisRowFlowLogSource WHERE id=2)) THROW 56607,N''ROWFLOW_EDGE_MAX_BOUNDARY_2049'',1;
UPDATE dbo.ExampleSsisRowFlowLogSource SET message=NULL;ALTER TABLE dbo.ExampleSsisRowFlowLogSource ALTER COLUMN message nvarchar(2048) NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
ALTER TABLE dbo.ExampleSsisRowFlowLogSource DROP COLUMN event;ALTER TABLE dbo.ExampleSsisRowFlowLogSource ADD event AS CONVERT(nvarchar(128),N''OnPipelineRowsSent'');
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@IncludeTaskAnalysis=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Edge-66'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
IF NOT EXISTS(SELECT 1 WHERE JSON_QUERY(@J,''$.rowFlowEvents'')=N''[]'' AND EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''6'' AND JSON_VALUE(value,''$.Detail'')=N''NO_VALID_EVENT_BUFFER'')) THROW 56607,N''ROWFLOW_EDGE_COMPUTED_REQUIRED'',1;
ALTER TABLE dbo.ExampleSsisRowFlowLogSource DROP COLUMN event;ALTER TABLE dbo.ExampleSsisRowFlowLogSource ADD event nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL;
TRUNCATE TABLE dbo.ExampleSsisRowFlowLogSource;INSERT dbo.ExampleSsisRowFlowLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,''20260101'',NULL),(2,N''OnPipelineRowsSent'',N''ExampleFlow'',@A,@Id,''20260101 00:00:01'',N''Rows were provided to a data flow component as input. : : 1 : ExamplePath : 2 : ExampleDestination : 3 : ExampleInput : 7''),(3,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,''20260101 00:00:02'',NULL);
CREATE USER ExampleRowFlowLogReader WITHOUT LOGIN;
DECLARE @OwnedUserId int=(SELECT principal_id FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleRowFlowLogReader'');
UPDATE #ExampleSsisRowFlowOwnership SET UserId=@OwnedUserId;
GRANT EXECUTE ON SCHEMA::monitor TO ExampleRowFlowLogReader;
GRANT VIEW DEFINITION ON dbo.ExampleSsisRowFlowLogSource TO ExampleRowFlowLogReader;
DENY SELECT ON dbo.ExampleSsisRowFlowLogSource TO ExampleRowFlowLogReader;
DECLARE @Impersonated bit=0;
BEGIN TRY
 EXECUTE AS USER=''ExampleRowFlowLogReader'';SET @Impersonated=1;
 BEGIN TRY EXEC(N''SELECT TOP(1) id FROM dbo.ExampleSsisRowFlowLogSource''); END TRY BEGIN CATCH SELECT @DirectError=ERROR_NUMBER(),@DirectMessage=ERROR_MESSAGE();END CATCH;

EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisRowFlowLogSource'',@ExecutionId=@Id,@IncludeRowFlowAnalysis=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
SELECT N''R-Consumer-54'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState;
 REVERT;SET @Impersonated=0;
SELECT @DirectError AS DirectError,@DirectMessage AS DirectMessage,@Error AS AnalyzerError,@Message AS AnalyzerMessage,@J AS CaptureJson,DB_ID() AS FixtureDbId,@OwnedTableId AS FixtureTableId;
END TRY BEGIN CATCH
 IF @Impersonated=1 BEGIN TRY REVERT;END TRY BEGIN CATCH SELECT ERROR_NUMBER() AS RevertError,ERROR_MESSAGE() AS RevertMessage;END CATCH;
 THROW;
END CATCH;
IF NOT EXISTS(SELECT 1 WHERE @DirectError=229 AND @Error=229 AND CONVERT(varbinary(max),@Message)=CONVERT(varbinary(max),@DirectMessage) AND JSON_QUERY(@J,''$.rowFlow'')=N''[]'') THROW 56601,N''ROWFLOW_S12_NATIVE_DENIED'',1;
IF (SELECT principal_id FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleRowFlowLogReader'')<>@OwnedUserId THROW 56605,N''ROWFLOW_READER_ID_CHANGED'',1;DROP USER ExampleRowFlowLogReader;UPDATE #ExampleSsisRowFlowOwnership SET UserId=NULL;
IF NOT EXISTS(SELECT 1 WHERE @@OPTIONS=@Options AND @@LOCK_TIMEOUT=@Lock AND @@TRANCOUNT=@Tran AND XACT_STATE()=@Xact) THROW 56601,N''ROWFLOW_CALLER'',1;
SELECT N''AVAILABLE'' AS StatusCode,N''SSIS row flow synthetic contract'' AS Detail;
END;');

 SELECT @ProcId=object_id FROM sys.procedures WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisRowFlowFixtureScope';
 IF @ProcId IS NULL THROW 56692,N'ROWFLOW_OWN_PROC_NOT_CAPTURED',1;
 EXEC dbo.ExampleSsisRowFlowFixtureScope @OwnedTableId=@TableId OUTPUT;
 IF DB_ID()<>@DbId OR OBJECT_ID(N'dbo.ExampleSsisRowFlowLogSource')<>@TableId OR OBJECT_ID(N'dbo.ExampleSsisRowFlowFixtureScope')<>@ProcId THROW 56693,N'ROWFLOW_CLEANUP_BINDING',1;
 DROP TABLE dbo.ExampleSsisRowFlowLogSource;
 DROP PROCEDURE dbo.ExampleSsisRowFlowFixtureScope;
 IF @@OPTIONS<>@OuterOptions OR @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTran THROW 56694,N'ROWFLOW_OUTER_CALLER',1;
END TRY
BEGIN CATCH
 DECLARE @OriginalError int=ERROR_NUMBER(),@OriginalMessage nvarchar(4000)=ERROR_MESSAGE();
 DECLARE @CleanupError nvarchar(4000)=N'',@ScopeValid bit=0;
 BEGIN TRY
  IF DB_ID()<>@DbId OR OBJECT_ID(N'tempdb..#ExampleSsisRowFlowOwnership')<>@OwnershipId THROW 56695,N'ROWFLOW_FAILURE_CLEANUP_SCOPE',1;
  SELECT @TableId=TableId,@UserId=UserId FROM #ExampleSsisRowFlowOwnership;
  SET @ScopeValid=1;
 END TRY BEGIN CATCH SET @CleanupError=ERROR_MESSAGE(); END CATCH;
 IF @ScopeValid=1
 BEGIN
  BEGIN TRY
   IF @UserId IS NOT NULL AND EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE principal_id=@UserId AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleRowFlowLogReader') DROP USER ExampleRowFlowLogReader;
  END TRY BEGIN CATCH SET @CleanupError+=N' User: '+ERROR_MESSAGE(); END CATCH;
  BEGIN TRY
   IF @TableId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleSsisRowFlowLogSource')=@TableId DROP TABLE dbo.ExampleSsisRowFlowLogSource;
  END TRY BEGIN CATCH SET @CleanupError+=N' Table: '+ERROR_MESSAGE(); END CATCH;
  BEGIN TRY
   IF @ProcId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleSsisRowFlowFixtureScope')=@ProcId DROP PROCEDURE dbo.ExampleSsisRowFlowFixtureScope;
  END TRY BEGIN CATCH SET @CleanupError+=N' Proc: '+ERROR_MESSAGE(); END CATCH;
 END;
 BEGIN TRY
  IF OBJECT_ID(N'tempdb..#ExampleSsisRowFlowOwnership')=@OwnershipId DROP TABLE #ExampleSsisRowFlowOwnership;
 END TRY BEGIN CATCH SET @CleanupError+=N' Temp: '+ERROR_MESSAGE(); END CATCH;
 SELECT @OriginalError AS OriginalError,@OriginalMessage AS OriginalMessage,@CleanupError AS CleanupError;
 THROW;
END CATCH;
DROP TABLE #ExampleSsisRowFlowOwnership;
GO
