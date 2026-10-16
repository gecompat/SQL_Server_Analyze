USE [DeineDatenbank];
GO
/* Synthetic format tests only; no SSIS execution or provider generation claim. */
DECLARE @DatabaseId int=DB_ID(),@OwnedProc int=NULL,@OwnedTable int=NULL,@OwnedUser int=NULL;
DECLARE @OuterOptions int=@@OPTIONS,@OuterLock int=@@LOCK_TIMEOUT,@OuterTran int=@@TRANCOUNT;
IF OBJECT_ID(N'tempdb..#ExampleSsisLegacyOwnership') IS NOT NULL THROW 56334,N'LEGACY_FOREIGN_OWNERSHIP_TEMP_REJECTED',1;
IF EXISTS(SELECT 1 FROM sys.all_objects WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleSsisLegacyFixtureScope',N'ExampleSsisLegacy.Log]Source'))
 THROW 56327,N'LEGACY_FOREIGN_FIXTURE_REJECTED',1;
IF EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyReader') THROW 56333,N'LEGACY_FOREIGN_PRINCIPAL_REJECTED',1;
CREATE TABLE [#ExampleSsisLegacyOwnership]([OwnedTableId] int NULL,[OwnedUserId] int NULL);
DECLARE @OwnershipTempId int=OBJECT_ID(N'tempdb..#ExampleSsisLegacyOwnership');
INSERT [#ExampleSsisLegacyOwnership] VALUES(NULL,NULL);
BEGIN TRY
    EXEC(N'CREATE PROCEDURE [dbo].[ExampleSsisLegacyFixtureScope] @OwnedTableId int OUTPUT AS BEGIN

SET NOCOUNT ON;
DECLARE @Db sysname=(SELECT name FROM sys.databases WITH (NOLOCK) WHERE database_id=DB_ID());
DECLARE @Id uniqueidentifier=''00000000-0000-0000-0000-000000000001'',@Other uniqueidentifier=''00000000-0000-0000-0000-000000000002'';
DECLARE @Source uniqueidentifier=''00000000-0000-0000-0000-000000000010'';
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(4000);
DECLARE @Long nvarchar(max)=REPLICATE(CONVERT(nvarchar(max),N''測試''),2500)+N''  ''+NCHAR(13)+NCHAR(10);
DECLARE @InitialOptions int=@@OPTIONS,@InitialTran int=@@TRANCOUNT,@InitialLock int=@@LOCK_TIMEOUT;
-- Synthetic compatible heap, not a native provider-generation acceptance.
CREATE TABLE [dbo].[ExampleSsisLegacy.Log]]Source]
([id] int NOT NULL,[event] sysname NULL,[source] nvarchar(4000) NULL,[sourceid] uniqueidentifier NULL,[executionid] uniqueidentifier NULL,
 [starttime] datetime NULL,[endtime] datetime NULL,[datacode] int NULL,[message] nvarchar(2048) NULL);
SELECT @OwnedTableId=object_id FROM sys.tables WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleSsisLegacy.Log]Source'' AND schema_id=1;
IF @OwnedTableId IS NULL THROW 56300,N''LEGACY_FIXTURE_ID_NOT_CAPTURED'',1;
UPDATE [#ExampleSsisLegacyOwnership] SET OwnedTableId=@OwnedTableId;
INSERT [dbo].[ExampleSsisLegacy.Log]]Source] VALUES
 (1,N''PackageStart'',N''ExamplePackage'',@Source,@Id,''20260101'',''20260102'',0,N''Synthetic start''),
 (2,N''OnPreExecute'',N''ExampleTask'',@Source,@Id,''20260101 00:00:01'',''20260102'',0,N''Synthetic lookup cache rows 42''),
 (3,N''OnWarning'',N''ExampleLookup'',@Source,@Id,''20260101 00:00:02'',''20260102'',0,N''Synthetic duplicate lookup warning''),
 (4,N''OnError'',N''ExampleTask'',@Source,@Id,''20260101 00:00:03'',''20260102'',1,N''Synthetic error 測試  ''+NCHAR(13)+NCHAR(10)),
 (5,N''OnPostExecute'',N''ExampleRenamedTask'',@Source,@Id,''20260101 00:00:04'',''20260102'',0,N''Synthetic elapsed 3000 ms''),
 (6,N''PackageEnd'',N''ExamplePackage'',@Source,@Id,''20260101 00:00:05'',''20260102'',0,N''Synthetic end''),
 (7,N''OnError'',N''ExampleOtherExecution'',@Source,@Other,''20260101'',''20260101'',9,N''Synthetic excluded other execution'');
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @Hilfe=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''invalid'',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF @Json IS NOT NULL THROW 56301,N''LEGACY_HELP_PRECEDENCE'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
IF @Status IS NULL OR @Status IS NULL OR @Status<>''INVALID_PARAMETER'' OR @Error IS NOT NULL THROW 56302,N''LEGACY_REQUIRED_DATABASE_AND_ID'',1;
BEGIN TRY
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @ResultSetArt=''TABLE'',@ResultTablesJson=N''invalid'';
    THROW 56303,N''LEGACY_MAPPING_NOT_REJECTED'',1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>51011 THROW;
END CATCH;
DECLARE @Mapping nvarchar(max)=N''{"moduleStatus":"#ExampleSsisLegacy_moduleStatus","execution":"#ExampleSsisLegacy_execution","timeline":"#ExampleSsisLegacy_timeline","errorChain":"#ExampleSsisLegacy_errorChain","iterations":"#ExampleSsisLegacy_iterations","loggingQuality":"#ExampleSsisLegacy_loggingQuality","findings":"#ExampleSsisLegacy_findings","sourceStatus":"#ExampleSsisLegacy_sourceStatus","warnings":"#ExampleSsisLegacy_warnings"}'';
CREATE TABLE [#ExampleSsisLegacy_moduleStatus]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_execution]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_timeline]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_errorChain]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_iterations]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_loggingQuality]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_findings]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_sourceStatus]([Seed] int NULL);
CREATE TABLE [#ExampleSsisLegacy_warnings]([Seed] int NULL);
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status IS NULL OR @Status IS NULL OR @Status<>''AVAILABLE'' OR @Partial IS NULL OR @Partial IS NULL OR @Partial<>0 OR @Error IS NOT NULL OR @Message IS NOT NULL
    THROW 56304,N''LEGACY_HEAP_ANALYZER_STATUS'',1;
IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_timeline])<>6
 OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline] WHERE ExecutionId<>@Id)
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution] WHERE AnalyzedEventCount=6 AND SourceCount=1 AND BoundaryStatus=''PAIRED''
    AND PackageDurationMs=5000 AND ObservedOutcome=''ERROR_EVENT_OBSERVED'' AND ErrorEventCount=1 AND WarningEventCount=1 AND FirstErrorLogId=4 AND IsCompleteSlice=1)
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_iterations] WHERE PairKind=''EXECUTE'' AND StartLogId=2 AND EndLogId=5 AND DurationMs=3000 AND SourceName=N''ExampleTask'')
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_warnings] WHERE WarningCode=''SUPPORTING_INDEX_NOT_OBSERVED'')
 OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_sourceStatus])<>4
    THROW 56305,N''LEGACY_SYNTHETIC_ORACLE'',1;
IF NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline] WHERE LogId=2 AND MessageText=N''Synthetic lookup cache rows 42'')
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline] WHERE LogId=3 AND MessageText=N''Synthetic duplicate lookup warning'')
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution] WHERE FirstErrorMessage=N''Synthetic error 測試  ''+NCHAR(13)+NCHAR(10))
    THROW 56306,N''LEGACY_ALL_EVENT_MESSAGES'',1;
IF COALESCE(ISJSON(@Json),0)<>1 OR JSON_QUERY(@Json,''$.meta'') IS NULL
 OR COALESCE(JSON_VALUE(@Json,''$.meta.ModuleName''),N'''')<>N''USP_SsisLegacyLogAnalysis''
 OR COALESCE(JSON_VALUE(@Json,''$.meta.SchemaVersion''),N'''')<>N''1''
 OR COALESCE(JSON_VALUE(@Json,''$.meta.StatusCode''),N'''')<>@Status
 OR COALESCE(JSON_VALUE(@Json,''$.meta.IsPartial''),N'''')<>N''false''
 OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,''$.meta.CollectionTimeUtc'')) IS NULL
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_moduleStatus] WHERE CollectionTimeUtc=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,''$.meta.CollectionTimeUtc''))
     AND StatusCode=@Status AND IsPartial=@Partial AND ErrorNumber IS NULL AND ErrorMessage IS NULL)
 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json) WHERE [key] IN(N''moduleStatus'',N''execution'',N''timeline'',N''errorChain'',N''iterations'',N''loggingQuality'',N''findings'',N''sourceStatus'',N''warnings'') AND [type]=4)<>9
 THROW 56330,N''LEGACY_JSON_ENVELOPE_ARRAYS'',1;
CREATE TABLE [#ExampleSsisLegacyActualSchema]
([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [Ordinal] int NOT NULL,[TypeId] int NOT NULL,[MaxLength] int NOT NULL,[Precision] int NOT NULL,[Scale] int NOT NULL,[Nullable] bit NOT NULL,[IdentityColumn] bit NOT NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE [#ExampleSsisLegacyExpectedSchema]
([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [Ordinal] int NOT NULL,[TypeId] int NOT NULL,[MaxLength] int NOT NULL,[Precision] int NOT NULL,[Scale] int NOT NULL,[Nullable] bit NOT NULL,[IdentityColumn] bit NOT NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
DECLARE @TableJson nvarchar(max),@ArrayJson nvarchar(max);
SELECT @TableJson=(SELECT [ModuleName],[SchemaVersion],[LoggingDatabase],[LoggingSchema],[LoggingTable],[ExecutionId],[MessagesIncluded],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[CollectionTimeUtc] FROM [#ExampleSsisLegacy_moduleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.moduleStatus'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_moduleStatus]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_moduleStatus'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''moduleStatus'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_moduleStatus'');
SELECT @TableJson=(SELECT [ExecutionId],[AnalyzedEventCount],[SourceCount],[FirstObservedTime],[LastObservedTime],[ErrorEventCount],[WarningEventCount],[TaskFailedEventCount],[CancelRequestCount],[BoundaryStatus],[PackageStartLogId],[PackageEndLogId],[PackageDurationMs],[ObservedOutcome],[FirstErrorLogId],[FirstErrorMessage],[IsCompleteSlice] FROM [#ExampleSsisLegacy_execution] ORDER BY [ExecutionId] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.execution'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_execution'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''execution'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_execution'');
SELECT @TableJson=(SELECT [TimelineOrdinal],[LogId],[ExecutionId],[EventName],[SourceName],[SourceId],[EventTime],[RawEndTime],[DataCode],[PreviousLogId],[DeltaFromPreviousMs],[Severity],[MessageText] FROM [#ExampleSsisLegacy_timeline] ORDER BY [TimelineOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.timeline'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_timeline'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''timeline'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_timeline'');
SELECT @TableJson=(SELECT [ErrorOrdinal],[LogId],[ExecutionId],[EventName],[SourceName],[SourceId],[EventTime],[DataCode],[Severity],[PreviousRelevantLogId],[RelationKind],[MessageText] FROM [#ExampleSsisLegacy_errorChain] ORDER BY [ErrorOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.errorChain'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_errorChain]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_errorChain'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''errorChain'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_errorChain'');
SELECT @TableJson=(SELECT [IterationOrdinal],[ExecutionId],[SourceId],[SourceName],[PairKind],[StartLogId],[EndLogId],[StartTime],[EndTime],[DurationMs],[PairStatus],[SampleIsPartial] FROM [#ExampleSsisLegacy_iterations] ORDER BY [IterationOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.iterations'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_iterations]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_iterations'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''iterations'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_iterations'');
SELECT @TableJson=(SELECT [QualityOrdinal],[QualityCode],[Severity],[AffectedRowCount],[Detail] FROM [#ExampleSsisLegacy_loggingQuality] ORDER BY [QualityOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.loggingQuality'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_loggingQuality]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_loggingQuality'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''loggingQuality'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_loggingQuality'');
SELECT @TableJson=(SELECT [FindingOrdinal],[FindingCode],[Severity],[ExecutionId],[EvidenceLevel],[EvidenceSource],[LogId],[Detail] FROM [#ExampleSsisLegacy_findings] ORDER BY [FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.findings'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_findings]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_findings'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''findings'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_findings'');
SELECT @TableJson=(SELECT [SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[ObservedRowCount],[ReturnedRowCount],[IsTruncated],[ErrorNumber],[ErrorMessage],[Detail],[CollectionTimeUtc] FROM [#ExampleSsisLegacy_sourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.sourceStatus'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_sourceStatus]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_sourceStatus'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''sourceStatus'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_sourceStatus'');
SELECT @TableJson=(SELECT [WarningOrdinal],[WarningCode],[SourceName],[Detail] FROM [#ExampleSsisLegacy_warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),@ArrayJson=JSON_QUERY(@Json,''$.warnings'');
IF @TableJson IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_warnings]) SET @TableJson=N''[]'';
IF @TableJson IS NULL OR @ArrayJson IS NULL OR CONVERT(varbinary(max),@TableJson)<>CONVERT(varbinary(max),@ArrayJson)
    THROW 56307,N''LEGACY_TABLE_JSON_warnings'',1;
INSERT [#ExampleSsisLegacyActualSchema]
SELECT N''warnings'',c.name,CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.system_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name
FROM tempdb.sys.columns AS c WITH (NOLOCK) WHERE c.object_id=OBJECT_ID(N''tempdb..#ExampleSsisLegacy_warnings'');
INSERT [#ExampleSsisLegacyExpectedSchema] VALUES
(N''moduleStatus'',N''ModuleName'',1,231,256,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''SchemaVersion'',2,56,4,10,0,0,0,NULL),
(N''moduleStatus'',N''LoggingDatabase'',3,231,256,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''LoggingSchema'',4,231,256,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''LoggingTable'',5,231,256,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''ExecutionId'',6,36,16,0,0,1,0,NULL),
(N''moduleStatus'',N''MessagesIncluded'',7,104,1,1,0,0,0,NULL),
(N''moduleStatus'',N''StatusCode'',8,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''IsPartial'',9,104,1,1,0,0,0,NULL),
(N''moduleStatus'',N''ErrorNumber'',10,56,4,10,0,1,0,NULL),
(N''moduleStatus'',N''ErrorMessage'',11,231,8000,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''moduleStatus'',N''CollectionTimeUtc'',12,42,7,23,3,0,0,NULL),
(N''execution'',N''ExecutionId'',1,36,16,0,0,0,0,NULL),
(N''execution'',N''AnalyzedEventCount'',2,127,8,19,0,0,0,NULL),
(N''execution'',N''SourceCount'',3,127,8,19,0,0,0,NULL),
(N''execution'',N''FirstObservedTime'',4,61,8,23,3,1,0,NULL),
(N''execution'',N''LastObservedTime'',5,61,8,23,3,1,0,NULL),
(N''execution'',N''ErrorEventCount'',6,127,8,19,0,0,0,NULL),
(N''execution'',N''WarningEventCount'',7,127,8,19,0,0,0,NULL),
(N''execution'',N''TaskFailedEventCount'',8,127,8,19,0,0,0,NULL),
(N''execution'',N''CancelRequestCount'',9,127,8,19,0,0,0,NULL),
(N''execution'',N''BoundaryStatus'',10,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''execution'',N''PackageStartLogId'',11,56,4,10,0,1,0,NULL),
(N''execution'',N''PackageEndLogId'',12,56,4,10,0,1,0,NULL),
(N''execution'',N''PackageDurationMs'',13,127,8,19,0,1,0,NULL),
(N''execution'',N''ObservedOutcome'',14,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''execution'',N''FirstErrorLogId'',15,56,4,10,0,1,0,NULL),
(N''execution'',N''FirstErrorMessage'',16,231,-1,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''execution'',N''IsCompleteSlice'',17,104,1,1,0,0,0,NULL),
(N''timeline'',N''TimelineOrdinal'',1,127,8,19,0,0,0,NULL),
(N''timeline'',N''LogId'',2,56,4,10,0,0,0,NULL),
(N''timeline'',N''ExecutionId'',3,36,16,0,0,0,0,NULL),
(N''timeline'',N''EventName'',4,231,256,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''timeline'',N''SourceName'',5,231,8000,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''timeline'',N''SourceId'',6,36,16,0,0,1,0,NULL),
(N''timeline'',N''EventTime'',7,61,8,23,3,1,0,NULL),
(N''timeline'',N''RawEndTime'',8,61,8,23,3,1,0,NULL),
(N''timeline'',N''DataCode'',9,56,4,10,0,1,0,NULL),
(N''timeline'',N''PreviousLogId'',10,56,4,10,0,1,0,NULL),
(N''timeline'',N''DeltaFromPreviousMs'',11,127,8,19,0,1,0,NULL),
(N''timeline'',N''Severity'',12,167,16,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''timeline'',N''MessageText'',13,231,-1,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''errorChain'',N''ErrorOrdinal'',1,127,8,19,0,0,0,NULL),
(N''errorChain'',N''LogId'',2,56,4,10,0,0,0,NULL),
(N''errorChain'',N''ExecutionId'',3,36,16,0,0,0,0,NULL),
(N''errorChain'',N''EventName'',4,231,256,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''errorChain'',N''SourceName'',5,231,8000,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''errorChain'',N''SourceId'',6,36,16,0,0,1,0,NULL),
(N''errorChain'',N''EventTime'',7,61,8,23,3,1,0,NULL),
(N''errorChain'',N''DataCode'',8,56,4,10,0,1,0,NULL),
(N''errorChain'',N''Severity'',9,167,16,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''errorChain'',N''PreviousRelevantLogId'',10,56,4,10,0,1,0,NULL),
(N''errorChain'',N''RelationKind'',11,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''errorChain'',N''MessageText'',12,231,-1,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''iterations'',N''IterationOrdinal'',1,127,8,19,0,0,0,NULL),
(N''iterations'',N''ExecutionId'',2,36,16,0,0,0,0,NULL),
(N''iterations'',N''SourceId'',3,36,16,0,0,1,0,NULL),
(N''iterations'',N''SourceName'',4,231,8000,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''iterations'',N''PairKind'',5,167,16,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''iterations'',N''StartLogId'',6,56,4,10,0,1,0,NULL),
(N''iterations'',N''EndLogId'',7,56,4,10,0,1,0,NULL),
(N''iterations'',N''StartTime'',8,61,8,23,3,1,0,NULL),
(N''iterations'',N''EndTime'',9,61,8,23,3,1,0,NULL),
(N''iterations'',N''DurationMs'',10,127,8,19,0,1,0,NULL),
(N''iterations'',N''PairStatus'',11,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''iterations'',N''SampleIsPartial'',12,104,1,1,0,0,0,NULL),
(N''loggingQuality'',N''QualityOrdinal'',1,56,4,10,0,0,0,NULL),
(N''loggingQuality'',N''QualityCode'',2,167,64,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''loggingQuality'',N''Severity'',3,167,16,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''loggingQuality'',N''AffectedRowCount'',4,127,8,19,0,1,0,NULL),
(N''loggingQuality'',N''Detail'',5,231,4000,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''findings'',N''FindingOrdinal'',1,56,4,10,0,0,0,NULL),
(N''findings'',N''FindingCode'',2,167,64,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''findings'',N''Severity'',3,167,16,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''findings'',N''ExecutionId'',4,36,16,0,0,0,0,NULL),
(N''findings'',N''EvidenceLevel'',5,167,32,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''findings'',N''EvidenceSource'',6,231,320,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''findings'',N''LogId'',7,56,4,10,0,1,0,NULL),
(N''findings'',N''Detail'',8,231,4000,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''sourceStatus'',N''SourceOrdinal'',1,56,4,10,0,0,0,NULL),
(N''sourceStatus'',N''SourceName'',2,231,320,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''sourceStatus'',N''StatusCode'',3,167,40,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''sourceStatus'',N''IsPartial'',4,104,1,1,0,0,0,NULL),
(N''sourceStatus'',N''ObservedRowCount'',5,127,8,19,0,1,0,NULL),
(N''sourceStatus'',N''ReturnedRowCount'',6,127,8,19,0,1,0,NULL),
(N''sourceStatus'',N''IsTruncated'',7,104,1,1,0,0,0,NULL),
(N''sourceStatus'',N''ErrorNumber'',8,56,4,10,0,1,0,NULL),
(N''sourceStatus'',N''ErrorMessage'',9,231,8000,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''sourceStatus'',N''Detail'',10,231,4000,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''sourceStatus'',N''CollectionTimeUtc'',11,42,7,23,3,0,0,NULL),
(N''warnings'',N''WarningOrdinal'',1,56,4,10,0,0,0,NULL),
(N''warnings'',N''WarningCode'',2,167,64,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''warnings'',N''SourceName'',3,231,320,0,0,1,0,N''SQL_Latin1_General_CP1_CS_AS''),
(N''warnings'',N''Detail'',4,231,4000,0,0,0,0,N''SQL_Latin1_General_CP1_CS_AS'');
IF EXISTS(SELECT * FROM [#ExampleSsisLegacyActualSchema] EXCEPT SELECT * FROM [#ExampleSsisLegacyExpectedSchema])
 OR EXISTS(SELECT * FROM [#ExampleSsisLegacyExpectedSchema] EXCEPT SELECT * FROM [#ExampleSsisLegacyActualSchema])
BEGIN
 SELECT * FROM [#ExampleSsisLegacyActualSchema] ORDER BY ResultName,Ordinal;
 THROW 56308,N''LEGACY_COMPLETE_SCHEMA_SET'',1;
END;
-- Owned database-only principal: advisory index denial must not block a permitted event read.
CREATE USER [ExampleSsisLegacyReader] WITHOUT LOGIN;
UPDATE [#ExampleSsisLegacyOwnership] SET OwnedUserId=(SELECT principal_id FROM sys.database_principals WITH (NOLOCK) WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=N''ExampleSsisLegacyReader'');
GRANT SELECT,VIEW DEFINITION ON [dbo].[ExampleSsisLegacy.Log]]Source] TO [ExampleSsisLegacyReader];
GRANT EXECUTE ON [monitor].[USP_SsisLegacyLogAnalysis] TO [ExampleSsisLegacyReader];
DENY SELECT ON OBJECT::[sys].[indexes] TO [ExampleSsisLegacyReader];
DECLARE @IndexNativeError int=NULL,@IndexNativeMessage nvarchar(4000)=NULL,@EventNativeError int=NULL,@EventNativeMessage nvarchar(4000)=NULL,@ProbeCount bigint,@Impersonated bit=0;
BEGIN TRY
 EXECUTE AS USER=N''ExampleSsisLegacyReader'';
 SET @Impersonated=1;
 BEGIN TRY
  EXEC sys.sp_executesql N''SELECT @N=COUNT_BIG(*) FROM sys.indexes WITH (NOLOCK);'',N''@N bigint OUTPUT'',@N=@ProbeCount OUTPUT;
 END TRY
 BEGIN CATCH
  SELECT @IndexNativeError=ERROR_NUMBER(),@IndexNativeMessage=ERROR_MESSAGE();
 END CATCH;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 REVERT;
 SET @Impersonated=0;
END TRY
BEGIN CATCH
 IF @Impersonated=1 REVERT;
 THROW;
END CATCH;
SELECT N''INDEX_DENIAL_CONTINUED'' AS [OracleCase],@IndexNativeError AS NativeError,@IndexNativeMessage AS NativeMessage,
 @Status AS ConsumerStatus,@Error AS ConsumerError,@Message AS ConsumerMessage,JSON_QUERY(@Json,''$.sourceStatus'') AS SourceStates;
IF @Status IS NULL OR @Status IS NULL OR @Status<>''AVAILABLE_LIMITED'' OR @Partial IS NULL OR @Partial IS NULL OR @Partial<>1 OR @Error IS NULL OR @Error<>229
 OR @IndexNativeError IS NULL OR @IndexNativeError<>229 OR @IndexNativeMessage IS NULL OR @Error<>@IndexNativeError
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[1].StatusCode''),N'''')<>N''DENIED''
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[2].StatusCode''),N'''')<>N''AVAILABLE''
 OR COALESCE(JSON_VALUE(@Json,''$.execution[0].AnalyzedEventCount''),N'''')<>N''6''
 OR @Message IS NULL OR JSON_VALUE(@Json,''$.sourceStatus[1].ErrorMessage'') IS NULL
 OR CONVERT(varbinary(max),@Message)<>CONVERT(varbinary(max),@IndexNativeMessage)
 OR CONVERT(varbinary(max),JSON_VALUE(@Json,''$.sourceStatus[1].ErrorMessage''))<>CONVERT(varbinary(max),@IndexNativeMessage)
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[1].ErrorNumber''),N'''')<>CONVERT(nvarchar(20),@IndexNativeError)
 THROW 56331,N''LEGACY_OPTIONAL_INDEX_DENIAL_CONTINUES'',1;
-- An actual required-source denial wins status; the earlier index error pair remains first.
DENY SELECT ON [dbo].[ExampleSsisLegacy.Log]]Source] TO [ExampleSsisLegacyReader];
BEGIN TRY
 EXECUTE AS USER=N''ExampleSsisLegacyReader'';
 SET @Impersonated=1;
 BEGIN TRY
  EXEC sys.sp_executesql N''SELECT @N=COUNT_BIG(*) FROM [dbo].[ExampleSsisLegacy.Log]]Source] WITH (NOLOCK) WHERE executionid=@Id;'',N''@Id uniqueidentifier,@N bigint OUTPUT'',@Id=@Id,@N=@ProbeCount OUTPUT;
 END TRY
 BEGIN CATCH
  SELECT @EventNativeError=ERROR_NUMBER(),@EventNativeMessage=ERROR_MESSAGE();
 END CATCH;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 REVERT;
 SET @Impersonated=0;
END TRY
BEGIN CATCH
 IF @Impersonated=1 REVERT;
 THROW;
END CATCH;
SELECT N''REQUIRED_DENIAL_PRESERVES_FIRST_PAIR'' AS [OracleCase],@IndexNativeError AS IndexNativeError,@IndexNativeMessage AS IndexNativeMessage,
 @EventNativeError AS EventNativeError,@EventNativeMessage AS EventNativeMessage,
 @Status AS ConsumerStatus,@Error AS ConsumerError,@Message AS ConsumerMessage,JSON_QUERY(@Json,''$.sourceStatus'') AS SourceStates;
IF @Status IS NULL OR @Status IS NULL OR @Status<>''DENIED'' OR @Partial IS NULL OR @Partial IS NULL OR @Partial<>1 OR @Error IS NULL OR @Error<>229
 OR @EventNativeError IS NULL OR @EventNativeError<>229 OR @EventNativeMessage IS NULL
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[2].StatusCode''),N'''')<>N''DENIED''
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[2].ErrorNumber''),N'''')<>N''229''
 OR COALESCE(JSON_VALUE(@Json,''$.sourceStatus[3].StatusCode''),N'''')<>N''NOT_READ''
 OR @Message IS NULL OR JSON_VALUE(@Json,''$.sourceStatus[1].ErrorMessage'') IS NULL
 OR CONVERT(varbinary(max),@Message)<>CONVERT(varbinary(max),@IndexNativeMessage)
 OR CONVERT(varbinary(max),JSON_VALUE(@Json,''$.sourceStatus[1].ErrorMessage''))<>CONVERT(varbinary(max),@IndexNativeMessage)
 OR JSON_VALUE(@Json,''$.sourceStatus[2].ErrorMessage'') IS NULL
 OR CONVERT(varbinary(max),JSON_VALUE(@Json,''$.sourceStatus[2].ErrorMessage''))<>CONVERT(varbinary(max),@EventNativeMessage)
 OR JSON_QUERY(@Json,''$.timeline'')<>N''[]'' OR JSON_QUERY(@Json,''$.timeline'') IS NULL
 THROW 56332,N''LEGACY_OPTIONAL_THEN_REQUIRED_DENIAL_PRIORITY'',1;
DECLARE @Cap int=1;
WHILE @Cap<=2
BEGIN
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@MaxZeilen=@Cap,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

    IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_timeline])<>@Cap
       OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_sourceStatus] WHERE SourceOrdinal=3 AND ObservedRowCount=@Cap+1 AND ReturnedRowCount=@Cap AND IsTruncated=1)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution] WHERE IsCompleteSlice=0 AND AnalyzedEventCount=@Cap)
       OR @Status IS NULL OR @Status<>''AVAILABLE_LIMITED'' OR @Partial IS NULL OR @Partial<>1
        THROW 56309,N''LEGACY_SENTINEL_CAP_ORACLE'',1;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_warnings])>16 THROW 56310,N''LEGACY_WARNING_FINITE_BOUND'',1;
    SET @Cap+=1;
END;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@MaxZeilen=2147483647,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_timeline])<>6 THROW 56311,N''LEGACY_INT_MAX_OVERFLOW'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@MaxZeilen=0,@HighImpactConfirmed=0,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''INVALID_PARAMETER'' OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline]) THROW 56312,N''LEGACY_UNBOUNDED_GATE'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@MaxZeilen=NULL,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE'' OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_timeline])<>6 THROW 56313,N''LEGACY_UNBOUNDED_CONFIRMED'',1;
-- Duplicate sentinel must reject the entire N+1 buffer before its removal.
INSERT [dbo].[ExampleSsisLegacy.Log]]Source] SELECT * FROM [dbo].[ExampleSsisLegacy.Log]]Source] WHERE id=1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@MaxZeilen=1,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''ERROR_HANDLED'' OR @Error IS NOT NULL OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline])
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_sourceStatus] WHERE SourceOrdinal=3 AND ObservedRowCount IS NULL AND ReturnedRowCount IS NULL)
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_warnings] WHERE WarningCode=''DUPLICATE_LOG_ID_OBSERVED'') THROW 56314,N''LEGACY_DUPLICATE_CAPTURE_REJECTION'',1;
DELETE TOP (1) FROM [dbo].[ExampleSsisLegacy.Log]]Source] WHERE id=1;
ALTER TABLE [dbo].[ExampleSsisLegacy.Log]]Source] ALTER COLUMN [message] nvarchar(max) NULL;
UPDATE [dbo].[ExampleSsisLegacy.Log]]Source] SET [message]=@Long WHERE id=4;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''INVALID_PARAMETER'' OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline]) THROW 56315,N''LEGACY_MAX_TEXT_GATE'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution] WHERE DATALENGTH(FirstErrorMessage)=DATALENGTH(@Long) AND FirstErrorMessage=@Long)
 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,''$.timeline'') WITH(LogId int,MessageText nvarchar(max)) WHERE LogId=4 AND DATALENGTH(MessageText)=DATALENGTH(@Long) AND MessageText=@Long)
 THROW 56316,N''LEGACY_LONG_UNICODE_TEXT_PARITY'',1;
CREATE TABLE [#ExampleSsisLegacy_Console]
([Ergebnis] nvarchar(200),[Status] varchar(40),[Unvollständig] bit,[ExecutionId] uniqueidentifier,[AnalysierteEreignisse] bigint,
 [BeobachteterAusgang] varchar(40),[ErsteFehlerLogId] int,[ErsterFehlertext] nvarchar(max),[ErsterZeitpunkt] datetime,[LetzterZeitpunkt] datetime,[Hinweis] nvarchar(200));
INSERT [#ExampleSsisLegacy_Console]
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@HighImpactConfirmed=1,@ResultSetArt=''CONSOLE'';

IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_Console])<>1
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_Console] WHERE ErsteFehlerLogId=4 AND DATALENGTH(ErsterFehlertext)=DATALENGTH(@Long) AND ErsterFehlertext=@Long)
 THROW 56317,N''LEGACY_FULL_CONSOLE_FIRST_ERROR'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@IncludeMessages=0,@IncludeTimeline=0,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE'' OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_timeline])
 OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_errorChain] WHERE MessageText IS NOT NULL)
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution] WHERE FirstErrorLogId=4 AND FirstErrorMessage IS NULL)
 THROW 56318,N''LEGACY_INDEPENDENT_OPTOUTS'',1;
ALTER TABLE [dbo].[ExampleSsisLegacy.Log]]Source] DROP COLUMN [message];
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@IncludeMessages=0,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE'' THROW 56319,N''LEGACY_DISABLED_MESSAGE_COLUMN_ACCESS'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''SOURCE_UNAVAILABLE'' THROW 56320,N''LEGACY_REQUIRED_MESSAGE_COLUMN'',1;
ALTER TABLE [dbo].[ExampleSsisLegacy.Log]]Source] ADD [message] AS CONVERT(nvarchar(2048),N''Synthetic computed'') PERSISTED;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''SOURCE_UNAVAILABLE'' THROW 56321,N''LEGACY_COMPUTED_MESSAGE_ADMISSION'',1;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@IncludeMessages=0,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE'' THROW 56322,N''LEGACY_IGNORED_COMPUTED_MESSAGE'',1;
ALTER TABLE [dbo].[ExampleSsisLegacy.Log]]Source] DROP COLUMN [message];
ALTER TABLE [dbo].[ExampleSsisLegacy.Log]]Source] ADD [message] nvarchar(2048) NULL;
-- Ambiguous and incomplete streams retain their observed events without invented pairings.
UPDATE [dbo].[ExampleSsisLegacy.Log]]Source] SET [event]=N''OnPreExecute'' WHERE id=5;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE_LIMITED'' OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_iterations] WHERE PairKind=''EXECUTE'' AND PairStatus=''AMBIGUOUS'')<>2
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_loggingQuality] WHERE QualityCode=''ERROR_MESSAGE_MISSING'' AND AffectedRowCount=1)
 THROW 56323,N''LEGACY_AMBIGUOUS_PAIRING_AND_MISSING_ERROR_TEXT'',1;
DELETE FROM [dbo].[ExampleSsisLegacy.Log]]Source] WHERE id=5;
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_loggingQuality] WHERE QualityCode=''PAIRING_INCOMPLETE'' AND AffectedRowCount=1)
 OR NOT EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_findings] WHERE FindingCode=''PAIRING_INCOMPLETE'' AND EvidenceLevel=''DERIVED'')
 THROW 56324,N''LEGACY_INCOMPLETE_PAIRING'',1;
DELETE FROM [dbo].[ExampleSsisLegacy.Log]]Source];
TRUNCATE TABLE [#ExampleSsisLegacy_moduleStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_execution];
TRUNCATE TABLE [#ExampleSsisLegacy_timeline];
TRUNCATE TABLE [#ExampleSsisLegacy_errorChain];
TRUNCATE TABLE [#ExampleSsisLegacy_iterations];
TRUNCATE TABLE [#ExampleSsisLegacy_loggingQuality];
TRUNCATE TABLE [#ExampleSsisLegacy_findings];
TRUNCATE TABLE [#ExampleSsisLegacy_sourceStatus];
TRUNCATE TABLE [#ExampleSsisLegacy_warnings];
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''TABLE'',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

IF @Status IS NULL OR @Status<>''AVAILABLE_EMPTY'' OR @Partial IS NULL OR @Partial<>0 OR EXISTS(SELECT 1 FROM [#ExampleSsisLegacy_execution])
 OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisLegacy_loggingQuality])<>1 THROW 56325,N''LEGACY_EMPTY_QUALITY'',1;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 137;
DECLARE @CallerOptions int=@@OPTIONS;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''NONE'',@StatusCodeOut=@Status OUTPUT WITH RESULT SETS NONE;

IF @@OPTIONS<>@CallerOptions OR @@LOCK_TIMEOUT<>137 OR @@TRANCOUNT<>@InitialTran THROW 56326,N''LEGACY_CALLER_STATE'',1;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleSsisLegacy.Log]Source'',@ExecutionId=@Id,@ResultSetArt=''RAW'';

END;');
    SELECT @OwnedProc=object_id FROM sys.procedures WITH (NOLOCK) WHERE schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyFixtureScope';
    EXEC [dbo].[ExampleSsisLegacyFixtureScope] @OwnedTableId=@OwnedTable OUTPUT;
    SELECT @OwnedUser=OwnedUserId FROM [#ExampleSsisLegacyOwnership];
    IF @@OPTIONS<>@OuterOptions OR @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTran THROW 56328,N'LEGACY_OUTER_CALLER_STATE',1;
    IF DB_ID()<>@DatabaseId OR NOT EXISTS(SELECT 1 FROM sys.tables WITH (NOLOCK) WHERE object_id=@OwnedTable AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacy.Log]Source')
       OR NOT EXISTS(SELECT 1 FROM sys.procedures WITH (NOLOCK) WHERE object_id=@OwnedProc AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyFixtureScope')
        THROW 56329,N'LEGACY_FIXTURE_IDENTITY_CHANGED',1;
    DROP TABLE [dbo].[ExampleSsisLegacy.Log]]Source];
    DROP PROCEDURE [dbo].[ExampleSsisLegacyFixtureScope];
    IF DB_ID()=@DatabaseId AND EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE principal_id=@OwnedUser AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyReader') DROP USER [ExampleSsisLegacyReader];
    IF OBJECT_ID(N'tempdb..#ExampleSsisLegacyOwnership')=@OwnershipTempId DROP TABLE [#ExampleSsisLegacyOwnership];
END TRY
BEGIN CATCH
    DECLARE @Original int=ERROR_NUMBER(),@OriginalText nvarchar(4000)=ERROR_MESSAGE();
    SELECT @OwnedTable=COALESCE(@OwnedTable,OwnedTableId),@OwnedUser=OwnedUserId FROM [#ExampleSsisLegacyOwnership];
    RAISERROR(N'Legacy test original error %d: %s',10,1,@Original,@OriginalText);
    BEGIN TRY
        IF DB_ID()=@DatabaseId AND EXISTS(SELECT 1 FROM sys.tables WITH (NOLOCK) WHERE object_id=@OwnedTable AND schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacy.Log]Source') DROP TABLE [dbo].[ExampleSsisLegacy.Log]]Source];
    END TRY
    BEGIN CATCH
        DECLARE @CleanupText nvarchar(4000)=ERROR_MESSAGE();
        RAISERROR(N'Legacy test table cleanup error: %s',10,1,@CleanupText);
    END CATCH;
    BEGIN TRY
        IF DB_ID()=@DatabaseId AND EXISTS(SELECT 1 FROM sys.procedures WITH (NOLOCK) WHERE object_id=@OwnedProc AND schema_id=1 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyFixtureScope') DROP PROCEDURE [dbo].[ExampleSsisLegacyFixtureScope];
    END TRY
    BEGIN CATCH
        DECLARE @ProcCleanupText nvarchar(4000)=ERROR_MESSAGE();
        RAISERROR(N'Legacy test procedure cleanup error: %s',10,1,@ProcCleanupText);
    END CATCH;
    BEGIN TRY
        IF DB_ID()=@DatabaseId AND EXISTS(SELECT 1 FROM sys.database_principals WITH (NOLOCK) WHERE principal_id=@OwnedUser AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisLegacyReader') DROP USER [ExampleSsisLegacyReader];
    END TRY
    BEGIN CATCH
        DECLARE @UserCleanupText nvarchar(4000)=ERROR_MESSAGE();
        RAISERROR(N'Legacy test principal cleanup error: %s',10,1,@UserCleanupText);
    END CATCH;
    BEGIN TRY
        IF OBJECT_ID(N'tempdb..#ExampleSsisLegacyOwnership')=@OwnershipTempId DROP TABLE [#ExampleSsisLegacyOwnership];
    END TRY
    BEGIN CATCH
        DECLARE @TempCleanupText nvarchar(4000)=ERROR_MESSAGE();
        RAISERROR(N'Legacy test ownership temp cleanup error: %s',10,1,@TempCleanupText);
    END CATCH;
    THROW;
END CATCH;
GO
