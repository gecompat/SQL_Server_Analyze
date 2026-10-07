USE [DeineDatenbank];

GO

SET QUOTED_IDENTIFIER ON;

SET ANSI_NULLS ON;

GO

/* Common190: CurrentIO-Ausgabegrenzen und Collations.
   Fünf unabhängige Literalvorlagen prüfen 65 Felder, 23 Texte und 40 NOT-NULL-Felder.
   Ohne den eigenen Zweidatenbank-Kontext bleibt der native Dateiblock NOT_EXECUTED.
   Kein Workload, keine Datenbank und kein Parent-Snapshot werden erzeugt.
   Live-Dateizähler werden vor/nach dem Aufruf geklammert; Formeln und alle 19
   Dateifelder werden unabhängig geprüft. Keine atomare Cross-call-Parität.
   Positive Pending-I/O-Handle-/Schedulerwerte bleiben ohne positive Fixture unbelegt.
   Sample 0 kopiert die erste Pending-Beobachtung: ObservationCount 1 ist kein Samplebeweis.
   CONSOLE hat ein gemeinsames TOP über Pending-I/O und Dateien; direkte positive
   Aufrufe prüfen hier nur JSON/Status. Tatsächliche Grids brauchen einen Clientnachweis. */

CREATE TABLE [#ExampleIOSchema1]
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CollectionTimeUtc] datetime2(3) NOT NULL
  , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [IsPartial] bit NOT NULL
  , [ReturnedRowCount] bigint NOT NULL
  , [HasMoreRows] bit NOT NULL
  , [CrossDatabaseRequested] bit NOT NULL
  , [SampleSeconds] tinyint NOT NULL
  , [PendingIoRequested] bit NOT NULL
  , [PendingIoRowCount] bigint NOT NULL
  , [PendingIoHasMoreRows] bit NOT NULL
  , [ErrorNumber] int NULL
  , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#ExampleIOSchema2]
(
    [SourceOrdinal] int NOT NULL PRIMARY KEY
  , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CapturedAtUtc] datetime2(3) NOT NULL
  , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [IsPartial] bit NOT NULL
  , [ReturnedRowCount] bigint NOT NULL
  , [ErrorNumber] int NULL
  , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

CREATE TABLE [#ExampleIOSchema3]
(
    [DatabaseId] int NOT NULL
  , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [FileId] int NOT NULL
  , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [SampleSeconds] int NOT NULL
  , [Reads] bigint NOT NULL
  , [ReadBytes] bigint NOT NULL
  , [ReadStallMs] bigint NOT NULL
  , [Writes] bigint NOT NULL
  , [WriteBytes] bigint NOT NULL
  , [WriteStallMs] bigint NOT NULL
  , [ReadLatencyMs] decimal(19,3) NULL
  , [WriteLatencyMs] decimal(19,3) NULL
  , [OverallLatencyMs] decimal(19,3) NULL
  , [ReadThroughputMbPerSecond] decimal(19,3) NULL
  , [WriteThroughputMbPerSecond] decimal(19,3) NULL
  , [SizeOnDiskMb] decimal(19,2) NULL
);

CREATE TABLE [#ExampleIOSchema4]
(
    [CapturedAtUtc] datetime2(3) NOT NULL
  , [RequestAddress] varbinary(8) NOT NULL
  , [DatabaseId] int NULL
  , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FileId] int NULL
  , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [PhysicalPath] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [IoType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [PendingLayer] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [PendingDurationMs] bigint NOT NULL
  , [SchedulerId] int NULL
  , [RequestCountOnScheduler] int NULL
  , [IoWaitTaskCountOnScheduler] int NULL
  , [WasPresentInFirstSample] bit NOT NULL
  , [ObservationCount] tinyint NOT NULL
  , [FirstSamplePendingMs] bigint NULL
  , [IoOffset] bigint NOT NULL
  , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CorrelationScope] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

CREATE TABLE [#ExampleIOSchema5]
(
    [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#ExampleIOObserved1]
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CollectionTimeUtc] datetime2(3) NOT NULL
  , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [IsPartial] bit NOT NULL
  , [ReturnedRowCount] bigint NOT NULL
  , [HasMoreRows] bit NOT NULL
  , [CrossDatabaseRequested] bit NOT NULL
  , [SampleSeconds] tinyint NOT NULL
  , [PendingIoRequested] bit NOT NULL
  , [PendingIoRowCount] bigint NOT NULL
  , [PendingIoHasMoreRows] bit NOT NULL
  , [ErrorNumber] int NULL
  , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleIOObserved2]
(
    [SourceOrdinal] int NOT NULL PRIMARY KEY
  , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [CapturedAtUtc] datetime2(3) NOT NULL
  , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [IsPartial] bit NOT NULL
  , [ReturnedRowCount] bigint NOT NULL
  , [ErrorNumber] int NULL
  , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE [#ExampleIOObserved3]
(
    [DatabaseId] int NOT NULL
  , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
  , [FileId] int NOT NULL
  , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
  , [SampleSeconds] int NOT NULL
  , [Reads] bigint NOT NULL
  , [ReadBytes] bigint NOT NULL
  , [ReadStallMs] bigint NOT NULL
  , [Writes] bigint NOT NULL
  , [WriteBytes] bigint NOT NULL
  , [WriteStallMs] bigint NOT NULL
  , [ReadLatencyMs] decimal(19,3) NULL
  , [WriteLatencyMs] decimal(19,3) NULL
  , [OverallLatencyMs] decimal(19,3) NULL
  , [ReadThroughputMbPerSecond] decimal(19,3) NULL
  , [WriteThroughputMbPerSecond] decimal(19,3) NULL
  , [SizeOnDiskMb] decimal(19,2) NULL
);
DECLARE @FrameworkLevel int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
 OR CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
 THROW 59300,N'CURRENT_IO_FRAMEWORK',1;
DECLARE @OriginalLock int=@@LOCK_TIMEOUT,@Json nvarchar(max),@Sql nvarchar(max),@Map nvarchar(max),
 @Schema sysname,@Target sysname,@Array nvarchar(max),@TableJson nvarchar(max),@Rows int,
 @Missing sysname=N'ExampleMissingCurrentIO190Ä🔬',@Names nvarchar(max),@Pattern nvarchar(4000),
 @Max int,@Sample tinyint,@Pending bit,@Repeated bit,@Paths bit,@Min decimal(19,3),@MinPending bigint,
 @Case int,@K int,@Mask int,@NativeCases int=0,@CoreCases int=0,@NullMutations int=0,
 @FixtureStatus varchar(20)='NOT_EXECUTED',@Context nvarchar(4000)=TRY_CONVERT(nvarchar(4000),SESSION_CONTEXT(N'ExampleCurrentIOFixtureDatabase')),
 @Upper sysname=N'ExampleIOÄ''🔬',@Lower sysname=N'ExampleIOä''🔬',@OwnNames nvarchar(max),@Limit bigint,
 @Parent uniqueidentifier,@BeforeUtc datetime2(3),@AfterUtc datetime2(3);
IF EXISTS(SELECT 1 FROM sys.databases WHERE name COLLATE SQL_Latin1_General_CP1_CS_AS=@Missing COLLATE SQL_Latin1_General_CP1_CS_AS)
 THROW 59300,N'CURRENT_IO_MISSING_NAME_OCCUPIED',1;
CREATE TABLE #ExampleIOFixture(DatabaseId int NOT NULL PRIMARY KEY,DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
IF @Context IS NOT NULL AND (SELECT COUNT(*) FROM STRING_SPLIT(@Context,N'|'))=2
 AND NOT EXISTS(SELECT value COLLATE Latin1_General_100_BIN2 FROM STRING_SPLIT(@Context,N'|')
  EXCEPT SELECT n COLLATE Latin1_General_100_BIN2 FROM (VALUES(@Upper),(@Lower)) own(n))
 AND (SELECT COUNT(DISTINCT value COLLATE Latin1_General_100_BIN2) FROM STRING_SPLIT(@Context,N'|'))=2
BEGIN
 INSERT #ExampleIOFixture SELECT d.database_id,d.name FROM sys.databases d
 WHERE d.name COLLATE Latin1_General_100_BIN2 IN(@Upper COLLATE Latin1_General_100_BIN2,@Lower COLLATE Latin1_General_100_BIN2)
 AND d.state=0 AND d.compatibility_level=170 AND d.collation_name=N'Latin1_General_100_CI_AS'
 AND (SELECT COUNT(*) FROM sys.master_files m WHERE m.database_id=d.database_id)=3;
 IF (SELECT COUNT(*) FROM #ExampleIOFixture)=2 AND NOT EXISTS(SELECT 1 FROM sys.databases d WHERE d.name COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'ExampleIO%' COLLATE SQL_Latin1_General_CP1_CS_AS AND NOT EXISTS(SELECT 1 FROM #ExampleIOFixture f WHERE f.DatabaseId=d.database_id))
 BEGIN
  SET @FixtureStatus='PASS';SET @OwnNames=QUOTENAME(@Upper)+N'|'+QUOTENAME(@Lower);
 END;
END;
CREATE TABLE #ExampleIONative
(
 Phase bit NOT NULL,DatabaseId int NOT NULL,FileId int NOT NULL,DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 LogicalName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,PhysicalName nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 FileTypeDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 Reads bigint NOT NULL,ReadBytes bigint NOT NULL,ReadStallMs bigint NOT NULL,Writes bigint NOT NULL,
 WriteBytes bigint NOT NULL,WriteStallMs bigint NOT NULL,SizeBytes bigint NOT NULL,
 PRIMARY KEY(Phase,DatabaseId,FileId)
);
CREATE TABLE #ExampleIOCases
(CaseNumber int PRIMARY KEY,Names nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Pattern nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 MaxRows int NULL,Sample tinyint NULL,Pending bit NULL,Repeated bit NULL,Paths bit NULL,MinLatency decimal(19,3) NULL,MinPending bigint NULL,
 ExpectedInvalid bit NOT NULL,NativeCase bit NOT NULL,MapMask int NOT NULL);
INSERT #ExampleIOCases VALUES
 (0,QUOTENAME(@Missing),NULL,NULL,0,0,0,0,0,0,0,0,31),
 (1,QUOTENAME(@Missing),NULL,0,0,1,0,0,0,0,0,0,31),
 (2,QUOTENAME(@Missing),NULL,1,0,1,0,1,0,0,0,0,31),
 (3,QUOTENAME(@Missing),NULL,2,0,0,0,0,0,0,0,0,31),
 (4,QUOTENAME(@Missing),NULL,2147483647,0,0,0,0,0,0,0,0,31),
 (5,QUOTENAME(@Missing),NULL,-1,0,1,0,0,0,0,1,0,31),
 (6,QUOTENAME(@Missing),NULL,0,NULL,1,0,0,0,0,1,0,31),
 (7,QUOTENAME(@Missing),NULL,0,0,NULL,0,0,0,0,1,0,31),
 (8,QUOTENAME(@Missing),NULL,0,61,1,0,0,0,0,1,0,31),
 (9,QUOTENAME(@Missing),NULL,0,0,1,1,0,0,0,1,0,31),
 (10,QUOTENAME(@Missing),NULL,0,0,1,NULL,0,0,0,1,0,31),
 (11,QUOTENAME(@Missing),NULL,0,0,1,0,NULL,0,0,1,0,31),
 (12,QUOTENAME(@Missing),NULL,0,0,1,0,0,NULL,0,1,0,31),
 (13,QUOTENAME(@Missing),NULL,0,0,1,0,0,-1,0,1,0,31),
 (14,QUOTENAME(@Missing),NULL,0,0,1,0,0,0,NULL,1,0,31),
 (15,QUOTENAME(@Missing),NULL,0,0,1,0,0,0,-1,1,0,31),
 (16,QUOTENAME(@Missing),NULL,0,0,0,0,0,0,0,0,0,1),
 (17,QUOTENAME(@Missing),NULL,0,0,0,0,0,0,0,0,0,2),
 (18,QUOTENAME(@Missing),NULL,0,0,0,0,0,0,0,0,0,4),
 (19,QUOTENAME(@Missing),NULL,0,0,0,0,0,0,0,0,0,8),
 (20,QUOTENAME(@Missing),NULL,0,0,0,0,0,0,0,0,0,16),
 (21,QUOTENAME(@Missing),NULL,-1,0,1,0,0,0,0,1,0,17),
 (22,QUOTENAME(@Missing),NULL,0,0,1,0,0,0,0,0,0,10);
IF @FixtureStatus='PASS'
 INSERT #ExampleIOCases VALUES
 (30,@OwnNames,NULL,NULL,0,0,0,0,0,0,0,1,31),
 (31,@OwnNames,NULL,0,0,0,0,0,0,0,0,1,31),
 (32,@OwnNames,NULL,1,0,0,0,0,0,0,0,1,31),
 (33,@OwnNames,NULL,2,0,0,0,0,0,0,0,1,31),
 (34,QUOTENAME(@Upper),NULL,0,0,0,0,0,0,0,0,1,31),
 (35,QUOTENAME(@Lower),NULL,0,0,0,0,0,0,0,0,1,31),
 (36,NULL,N'like:ExampleIO%',0,0,0,0,0,0,0,0,1,31),
 (37,QUOTENAME(@Upper)+N'|'+QUOTENAME(@Missing),NULL,1,0,0,0,0,0,0,0,1,31),
 (38,@OwnNames,NULL,0,0,1,0,0,0,0,0,1,31),
 (39,@OwnNames,NULL,1,0,1,0,1,0,0,0,1,31),
 (40,@OwnNames,NULL,2,0,1,0,0,0,0,0,1,31),
 (41,@OwnNames,NULL,0,0,0,0,0,9999999999999999,0,0,1,31),
 (42,@OwnNames,NULL,0,1,0,0,0,0,0,0,1,31),
 (43,@OwnNames,NULL,0,1,1,1,1,0,0,0,1,31);
SET LOCK_TIMEOUT 731;
BEGIN TRY
 SET @Case=-1;
 WHILE EXISTS(SELECT 1 FROM #ExampleIOCases WHERE CaseNumber>@Case)
 BEGIN
  SELECT @Case=MIN(CaseNumber) FROM #ExampleIOCases WHERE CaseNumber>@Case;
  SELECT @Names=Names,@Pattern=Pattern,@Max=MaxRows,@Sample=Sample,@Pending=Pending,@Repeated=Repeated,@Paths=Paths,
   @Min=MinLatency,@MinPending=MinPending,@Mask=MapMask FROM #ExampleIOCases WHERE CaseNumber=@Case;
  CREATE TABLE #ExampleIOExport1(Dummy int NULL);CREATE TABLE #ExampleIOExport2(Dummy int NULL);
  CREATE TABLE #ExampleIOExport3(Dummy int NULL);CREATE TABLE #ExampleIOExport4(Dummy int NULL);CREATE TABLE #ExampleIOExport5(Dummy int NULL);
  SET @Map=N'{';SET @K=1;
  WHILE @K<=5
  BEGIN
   IF (@Mask & CONVERT(int,POWER(2,@K-1)))<>0
    SET @Map+=CASE WHEN LEN(@Map)>1 THEN N',' ELSE N'' END+N'"'+CASE @K WHEN 1 THEN N'moduleStatus' WHEN 2 THEN N'sourceStatus' WHEN 3 THEN N'files' WHEN 4 THEN N'pendingIo' ELSE N'warnings' END+N'":"#ExampleIOExport'+CONVERT(nvarchar(1),@K)+N'"';
   ELSE
   BEGIN
    SET @Sql=N'INSERT #ExampleIOExport'+CONVERT(nvarchar(1),@K)+N' VALUES(4242);';EXEC sys.sp_executesql @Sql;
   END;
   SET @K+=1;
  END;
  SET @Map+=N'}';DELETE #ExampleIONative;
  IF @Case>=30
   INSERT #ExampleIONative SELECT 0,v.database_id,v.file_id,d.name,m.name,m.physical_name,m.type_desc,
    v.num_of_reads,v.num_of_bytes_read,v.io_stall_read_ms,v.num_of_writes,v.num_of_bytes_written,v.io_stall_write_ms,v.size_on_disk_bytes
   FROM sys.dm_io_virtual_file_stats(NULL,NULL) v JOIN sys.databases d ON d.database_id=v.database_id
   JOIN sys.master_files m ON m.database_id=v.database_id AND m.file_id=v.file_id JOIN #ExampleIOFixture f ON f.DatabaseId=v.database_id;
  SET @BeforeUtc=SYSUTCDATETIME();SET @Json=NULL;
  EXEC monitor.USP_CurrentIO @DatabaseNames=@Names,@DatabaseNamePattern=@Pattern,@SampleSeconds=@Sample,
   @PendingIoEinbeziehen=@Pending,@NurWiederholtPending=@Repeated,@PhysischePfadeEinbeziehen=@Paths,
   @MinLatencyMs=@Min,@MinPendingIoMs=@MinPending,@MaxZeilen=@Max,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  SET @AfterUtc=SYSUTCDATETIME();
  IF @Case>=30
   INSERT #ExampleIONative SELECT 1,v.database_id,v.file_id,d.name,m.name,m.physical_name,m.type_desc,
    v.num_of_reads,v.num_of_bytes_read,v.io_stall_read_ms,v.num_of_writes,v.num_of_bytes_written,v.io_stall_write_ms,v.size_on_disk_bytes
   FROM sys.dm_io_virtual_file_stats(NULL,NULL) v JOIN sys.databases d ON d.database_id=v.database_id
   JOIN sys.master_files m ON m.database_id=v.database_id AND m.file_id=v.file_id JOIN #ExampleIOFixture f ON f.DatabaseId=v.database_id;
  IF @Sample=1 AND DATEDIFF_BIG(millisecond,@BeforeUtc,@AfterUtc)<900 THROW 59304,N'CURRENT_IO_SAMPLE_ELAPSED',1;
  IF @@LOCK_TIMEOUT<>731 OR ISJSON(@Json)<>1 THROW 59304,N'CURRENT_IO_JSON_CALLER',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>5 OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json)
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM STRING_SPLIT(N'meta|sourceStatus|files|pendingIo|warnings',N'|'))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE type<>CASE WHEN [key]=N'meta' THEN 5 ELSE 4 END)
   THROW 59305,N'CURRENT_IO_TOP_KEYS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>14
   OR EXISTS(SELECT [key] FROM OPENJSON(@Json,N'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
   OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,N'$.meta')
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2 FROM STRING_SPLIT(N'resultName|schemaVersion|generatedAtUtc|evidenceSnapshotStartedAtUtc|evidenceSnapshotId|statusCode|isPartial|requestedMaxRows|returnedRows|hasMoreRows|sampleSeconds|pendingIoRequested|pendingIoReturnedRows|pendingIoHasMoreRows',N'|'))
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE type<>CASE
    WHEN [key] IN(N'isPartial',N'hasMoreRows',N'pendingIoHasMoreRows') THEN 3
    WHEN [key]=N'evidenceSnapshotId' THEN 1
    WHEN [key]=N'requestedMaxRows' AND @Max IS NULL THEN 0
    WHEN [key]=N'sampleSeconds' AND @Sample IS NULL THEN 0
    WHEN [key]=N'pendingIoRequested' AND @Pending IS NULL THEN 0
    WHEN [key]=N'pendingIoRequested' THEN 3
    WHEN [key] IN(N'schemaVersion',N'requestedMaxRows',N'returnedRows',N'sampleSeconds',N'pendingIoReturnedRows') THEN 2 ELSE 1 END)
   OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>3
   OR ISNULL(JSON_VALUE(@Json,N'$.meta.resultName'),N'')<>N'CurrentIO'
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@Json,N'$.meta.evidenceSnapshotId')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.evidenceSnapshotStartedAtUtc')) NOT BETWEEN @BeforeUtc AND @AfterUtc
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @BeforeUtc AND @AfterUtc
   THROW 59306,N'CURRENT_IO_META',1;
  IF (SELECT ExpectedInvalid FROM #ExampleIOCases WHERE CaseNumber=@Case)=1
  BEGIN
   IF ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER' OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true'
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.files'))<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.pendingIo'))<>0
    THROW 59307,N'CURRENT_IO_INVALID',1;
  END;
  IF @Case=37 AND (ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE_LIMITED' OR JSON_VALUE(@Json,N'$.meta.isPartial')<>N'true' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH(RequestedName nvarchar(128) '$.RequestedName') WHERE RequestedName COLLATE Latin1_General_100_BIN2=@Missing COLLATE Latin1_General_100_BIN2)) THROW 59307,N'CURRENT_IO_MIXED_WARNING',1;
  SET @K=1;
  WHILE @K<=5
  BEGIN
   SET @Schema=N'#ExampleIOSchema'+CONVERT(nvarchar(1),@K);SET @Target=N'#ExampleIOExport'+CONVERT(nvarchar(1),@K);
   IF (@Mask & CONVERT(int,POWER(2,@K-1)))=0
   BEGIN
    IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target))<>1 THROW 59308,N'CURRENT_IO_UNMAPPED_SCHEMA',1;
    SET @Sql=N'IF (SELECT COUNT(*) FROM '+QUOTENAME(@Target)+N')<>1 OR NOT EXISTS(SELECT 1 FROM '+QUOTENAME(@Target)+N' WHERE Dummy=4242) THROW 59308,N''CURRENT_IO_UNMAPPED_SEED'',1;';EXEC sys.sp_executesql @Sql;
   END
   ELSE
   BEGIN
    SET @Array=CASE @K WHEN 1 THEN NULL WHEN 2 THEN JSON_QUERY(@Json,N'$.sourceStatus') WHEN 3 THEN JSON_QUERY(@Json,N'$.files') WHEN 4 THEN JSON_QUERY(@Json,N'$.pendingIo') ELSE JSON_QUERY(@Json,N'$.warnings') END;
    IF @K=1
    BEGIN
     SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleIOExport1 FOR JSON PATH,INCLUDE_NULL_VALUES);';
     EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
     SET @Array=(SELECT N'USP_CurrentIO' ModuleName,TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) CollectionTimeUtc,
      JSON_VALUE(@Json,N'$.meta.statusCode') StatusCode,CONVERT(bit,CASE JSON_VALUE(@Json,N'$.meta.isPartial') WHEN N'true' THEN 1 ELSE 0 END) IsPartial,
      TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')) ReturnedRowCount,CONVERT(bit,CASE JSON_VALUE(@Json,N'$.meta.hasMoreRows') WHEN N'true' THEN 1 ELSE 0 END) HasMoreRows,
      CONVERT(bit,CASE WHEN @Case>=30 AND (@Names=@OwnNames OR @Pattern IS NOT NULL OR @Case=37) THEN 1 ELSE 0 END) CrossDatabaseRequested,
      COALESCE(@Sample,CONVERT(tinyint,0)) SampleSeconds,COALESCE(@Pending,CONVERT(bit,0)) PendingIoRequested,
      TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.pendingIoReturnedRows')) PendingIoRowCount,
      CONVERT(bit,CASE JSON_VALUE(@Json,N'$.meta.pendingIoHasMoreRows') WHEN N'true' THEN 1 ELSE 0 END) PendingIoHasMoreRows,
      TRY_CONVERT(int,JSON_VALUE(@TableJson,N'$[0].ErrorNumber')) ErrorNumber,JSON_VALUE(@TableJson,N'$[0].ErrorMessage') ErrorMessage FOR JSON PATH,INCLUDE_NULL_VALUES);
    END;
IF EXISTS
(
 SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,
  system_type_id,user_type_id,max_length,precision,scale,is_nullable,is_identity,collation_name COLLATE Latin1_General_100_BIN2
 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Schema)
 EXCEPT
 SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,
  system_type_id,user_type_id,max_length,precision,scale,is_nullable,is_identity,collation_name COLLATE Latin1_General_100_BIN2
 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)
)
OR EXISTS
(
 SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,
  system_type_id,user_type_id,max_length,precision,scale,is_nullable,is_identity,collation_name COLLATE Latin1_General_100_BIN2
 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target)
 EXCEPT
 SELECT ROW_NUMBER() OVER(ORDER BY column_id),name COLLATE Latin1_General_100_BIN2,
  system_type_id,user_type_id,max_length,precision,scale,is_nullable,is_identity,collation_name COLLATE Latin1_General_100_BIN2
 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Schema)
) THROW 59301,N'CURRENT_IO_LITERAL_SCHEMA',1;
SET @Sql=N'SELECT @rows=COUNT(*) FROM '+QUOTENAME(@Target)+N';SELECT @json=(SELECT * FROM '+QUOTENAME(@Target)+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
EXEC sys.sp_executesql @Sql,N'@rows int OUTPUT,@json nvarchar(max) OUTPUT',@rows=@Rows OUTPUT,@json=@TableJson OUTPUT;
IF EXISTS(SELECT 1 FROM OPENJSON(@Array) a WHERE a.type<>5
 OR (SELECT COUNT(*) FROM OPENJSON(a.value))<>(SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Schema))
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value) GROUP BY [key] COLLATE Latin1_General_100_BIN2 HAVING COUNT(*)<>1)
 OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(a.value)
  EXCEPT SELECT name COLLATE Latin1_General_100_BIN2 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Schema))
 OR EXISTS(SELECT 1 FROM OPENJSON(a.value) p JOIN tempdb.sys.columns c ON p.[key] COLLATE Latin1_General_100_BIN2=c.name COLLATE Latin1_General_100_BIN2
  AND c.object_id=OBJECT_ID(N'tempdb..'+@Schema)
  WHERE (p.type=0 AND c.is_nullable=0) OR (p.type<>0 AND p.type<>CASE WHEN c.system_type_id=104 THEN 3 WHEN c.system_type_id IN(48,52,56,127,106,108) THEN 2 ELSE 1 END)))
 THROW 59302,N'CURRENT_IO_JSON_FIELDS_TYPES',1;
IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@Array,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@Array,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@TableJson,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
 THROW 59303,N'CURRENT_IO_TABLE_JSON_FULL_MULTISET',1;
   END;
   SET @K+=1;
  END;
  DELETE #ExampleIOObserved1;DELETE #ExampleIOObserved2;DELETE #ExampleIOObserved3;
  IF (@Mask&1)<>0
  BEGIN
   SET @Sql=N'SELECT @j=(SELECT * FROM #ExampleIOExport1 FOR JSON PATH,INCLUDE_NULL_VALUES);';
   EXEC sys.sp_executesql @Sql,N'@j nvarchar(max) OUTPUT',@j=@TableJson OUTPUT;
   INSERT #ExampleIOObserved1 SELECT * FROM OPENJSON(@TableJson) WITH([ModuleName] sysname '$.ModuleName',[CollectionTimeUtc] datetime2(3) '$.CollectionTimeUtc',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[ReturnedRowCount] bigint '$.ReturnedRowCount',[HasMoreRows] bit '$.HasMoreRows',[CrossDatabaseRequested] bit '$.CrossDatabaseRequested',[SampleSeconds] tinyint '$.SampleSeconds',[PendingIoRequested] bit '$.PendingIoRequested',[PendingIoRowCount] bigint '$.PendingIoRowCount',[PendingIoHasMoreRows] bit '$.PendingIoHasMoreRows',[ErrorNumber] int '$.ErrorNumber',[ErrorMessage] nvarchar(2048) '$.ErrorMessage');
  END;
  INSERT #ExampleIOObserved2 SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceOrdinal] int '$.SourceOrdinal',[SourceName] sysname '$.SourceName',[SourceObject] nvarchar(256) '$.SourceObject',[CapturedAtUtc] datetime2(3) '$.CapturedAtUtc',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[ReturnedRowCount] bigint '$.ReturnedRowCount',[ErrorNumber] int '$.ErrorNumber',[ErrorMessage] nvarchar(2048) '$.ErrorMessage',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit');
  INSERT #ExampleIOObserved3 SELECT * FROM OPENJSON(@Json,N'$.files') WITH([DatabaseId] int '$.DatabaseId',[DatabaseName] sysname '$.DatabaseName',[FileId] int '$.FileId',[LogicalName] sysname '$.LogicalName',[PhysicalName] nvarchar(260) '$.PhysicalName',[FileTypeDesc] nvarchar(60) '$.FileTypeDesc',[SampleSeconds] int '$.SampleSeconds',[Reads] bigint '$.Reads',[ReadBytes] bigint '$.ReadBytes',[ReadStallMs] bigint '$.ReadStallMs',[Writes] bigint '$.Writes',[WriteBytes] bigint '$.WriteBytes',[WriteStallMs] bigint '$.WriteStallMs',[ReadLatencyMs] decimal(19,3) '$.ReadLatencyMs',[WriteLatencyMs] decimal(19,3) '$.WriteLatencyMs',[OverallLatencyMs] decimal(19,3) '$.OverallLatencyMs',[ReadThroughputMbPerSecond] decimal(19,3) '$.ReadThroughputMbPerSecond',[WriteThroughputMbPerSecond] decimal(19,3) '$.WriteThroughputMbPerSecond',[SizeOnDiskMb] decimal(19,2) '$.SizeOnDiskMb');
  IF @Mask=31
  BEGIN
   IF (SELECT COUNT(*) FROM #ExampleIOObserved1)<>1 OR (SELECT COUNT(*) FROM #ExampleIOObserved2)<>3
    OR (SELECT ReturnedRowCount FROM #ExampleIOObserved1)<>(SELECT COUNT(*) FROM #ExampleIOObserved3)
    OR (SELECT PendingIoRowCount FROM #ExampleIOObserved1)<>(SELECT COUNT(*) FROM OPENJSON(@Json,N'$.pendingIo'))
    THROW 59309,N'CURRENT_IO_COUNTS',1;
   IF EXISTS(SELECT SourceOrdinal,SourceName COLLATE Latin1_General_100_BIN2,SourceObject COLLATE Latin1_General_100_BIN2 FROM #ExampleIOObserved2
    EXCEPT SELECT n,c COLLATE Latin1_General_100_BIN2,o COLLATE Latin1_General_100_BIN2 FROM (VALUES(1,N'fileStatistics',N'sys.dm_io_virtual_file_stats'),(2,N'pendingIo',N'sys.dm_io_pending_io_requests'),(3,N'pendingIoContext',N'sys.dm_os_schedulers|sys.dm_exec_requests|sys.dm_os_tasks|sys.dm_os_waiting_tasks')) e(n,c,o))
    THROW 59310,N'CURRENT_IO_SOURCE_IDENTITIES',1;
   IF @Pending=0 AND EXISTS(SELECT 1 FROM #ExampleIOObserved2 WHERE SourceOrdinal IN(2,3) AND (StatusCode<>N'NOT_REQUESTED' OR IsPartial<>0 OR ReturnedRowCount<>0))
    THROW 59310,N'CURRENT_IO_NOT_REQUESTED',1;
   IF @Sample=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.pendingIo') WITH(ObservationCount tinyint '$.ObservationCount',WasPresentInFirstSample bit '$.WasPresentInFirstSample',FindingCode varchar(80) '$.FindingCode') WHERE ObservationCount IS NULL OR ObservationCount<>1 OR WasPresentInFirstSample IS NULL OR WasPresentInFirstSample<>1 OR FindingCode IS NULL OR FindingCode<>N'POINT_IN_TIME_PENDING_IO')
    THROW 59310,N'CURRENT_IO_COPIED_SAMPLE',1;
  END;
  IF @Case>=30
  BEGIN
   IF EXISTS(SELECT DatabaseId,FileId,DatabaseName COLLATE Latin1_General_100_BIN2,LogicalName COLLATE Latin1_General_100_BIN2,PhysicalName COLLATE Latin1_General_100_BIN2,FileTypeDesc COLLATE Latin1_General_100_BIN2 FROM #ExampleIONative WHERE Phase=0 EXCEPT SELECT DatabaseId,FileId,DatabaseName COLLATE Latin1_General_100_BIN2,LogicalName COLLATE Latin1_General_100_BIN2,PhysicalName COLLATE Latin1_General_100_BIN2,FileTypeDesc COLLATE Latin1_General_100_BIN2 FROM #ExampleIONative WHERE Phase=1) THROW 59311,N'CURRENT_IO_NATIVE_CATALOG_DRIFT',1;
   IF (SELECT COUNT(*) FROM #ExampleIONative)<>12 OR EXISTS(SELECT 1 FROM #ExampleIONative WHERE Reads+Writes<=0)
    THROW 59311,N'CURRENT_IO_NATIVE_FIXTURE_DRIFT',1;
   IF EXISTS(SELECT 1 FROM #ExampleIOObserved3 o LEFT JOIN #ExampleIONative b ON b.Phase=0 AND b.DatabaseId=o.DatabaseId AND b.FileId=o.FileId
    LEFT JOIN #ExampleIONative a ON a.Phase=1 AND a.DatabaseId=o.DatabaseId AND a.FileId=o.FileId
    WHERE a.DatabaseId IS NULL OR b.DatabaseId IS NULL
     OR (@Sample=0 AND (o.Reads NOT BETWEEN b.Reads AND a.Reads OR o.ReadBytes NOT BETWEEN b.ReadBytes AND a.ReadBytes
      OR o.ReadStallMs NOT BETWEEN b.ReadStallMs AND a.ReadStallMs OR o.Writes NOT BETWEEN b.Writes AND a.Writes
      OR o.WriteBytes NOT BETWEEN b.WriteBytes AND a.WriteBytes OR o.WriteStallMs NOT BETWEEN b.WriteStallMs AND a.WriteStallMs))
     OR (@Sample>0 AND (o.Reads NOT BETWEEN 0 AND a.Reads-b.Reads OR o.ReadBytes NOT BETWEEN 0 AND a.ReadBytes-b.ReadBytes
      OR o.ReadStallMs NOT BETWEEN 0 AND a.ReadStallMs-b.ReadStallMs OR o.Writes NOT BETWEEN 0 AND a.Writes-b.Writes
      OR o.WriteBytes NOT BETWEEN 0 AND a.WriteBytes-b.WriteBytes OR o.WriteStallMs NOT BETWEEN 0 AND a.WriteStallMs-b.WriteStallMs))
     OR o.SizeOnDiskMb IS NULL OR o.SizeOnDiskMb NOT BETWEEN CONVERT(decimal(19,2),(CASE WHEN b.SizeBytes<a.SizeBytes THEN b.SizeBytes ELSE a.SizeBytes END)/1048576.0)
      AND CONVERT(decimal(19,2),(CASE WHEN b.SizeBytes>a.SizeBytes THEN b.SizeBytes ELSE a.SizeBytes END)/1048576.0))
    THROW 59312,N'CURRENT_IO_NATIVE_COUNTER_BRACKETS',1;
   DECLARE @ExpectedFiles nvarchar(max)=
   (SELECT o.DatabaseId,b.DatabaseName,o.FileId,b.LogicalName,b.PhysicalName,b.FileTypeDesc,CONVERT(int,@Sample) SampleSeconds,
     o.Reads,o.ReadBytes,o.ReadStallMs,o.Writes,o.WriteBytes,o.WriteStallMs,
     CONVERT(decimal(19,3),o.ReadStallMs*1.0/NULLIF(o.Reads,0)) ReadLatencyMs,
     CONVERT(decimal(19,3),o.WriteStallMs*1.0/NULLIF(o.Writes,0)) WriteLatencyMs,
     CONVERT(decimal(19,3),(o.ReadStallMs+o.WriteStallMs)*1.0/NULLIF(o.Reads+o.Writes,0)) OverallLatencyMs,
     CONVERT(decimal(19,3),CASE WHEN @Sample>0 THEN o.ReadBytes/1048576.0/@Sample END) ReadThroughputMbPerSecond,
     CONVERT(decimal(19,3),CASE WHEN @Sample>0 THEN o.WriteBytes/1048576.0/@Sample END) WriteThroughputMbPerSecond,o.SizeOnDiskMb
    FROM #ExampleIOObserved3 o JOIN #ExampleIONative b ON b.Phase=0 AND b.DatabaseId=o.DatabaseId AND b.FileId=o.FileId
    FOR JSON PATH,INCLUDE_NULL_VALUES);
   IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedFiles,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,N'$.files') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(@Json,N'$.files') GROUP BY value COLLATE Latin1_General_100_BIN2
    EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT(*) FROM OPENJSON(COALESCE(@ExpectedFiles,N'[]')) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 59313,N'CURRENT_IO_NATIVE_CATALOG_FORMULAS',1;
   SET @Limit=CASE WHEN @Max IS NULL OR @Max=0 THEN 9223372036854775807 ELSE @Max END;
   IF @Sample=0 AND @Case<>41
   BEGIN
    DECLARE @NativeSelected int=(SELECT COUNT(*) FROM #ExampleIONative WHERE Phase=0 AND
     (@Names=@OwnNames OR @Pattern IS NOT NULL OR @Case=37 AND DatabaseName=@Upper OR @Names=QUOTENAME(DatabaseName)));
    IF (SELECT COUNT(*) FROM #ExampleIOObserved3)<>CASE WHEN @NativeSelected>@Limit THEN @Limit ELSE @NativeSelected END
     OR (SELECT HasMoreRows FROM #ExampleIOObserved1)<>CONVERT(bit,CASE WHEN @NativeSelected>@Limit THEN 1 ELSE 0 END)
     OR (SELECT ReturnedRowCount FROM #ExampleIOObserved2 WHERE SourceOrdinal=1)<>CASE WHEN @NativeSelected>@Limit THEN @Limit+1 ELSE @NativeSelected END
     THROW 59314,N'CURRENT_IO_NATIVE_CAP_COUNTS',1;
    -- Reject an excluded native candidate whose lower possible latency outranks a selected upper bound.
    -- Genuine overlaps/ties are admissible; no cross-call deterministic identity is inferred.
    IF EXISTS(SELECT 1 FROM #ExampleIONative x JOIN #ExampleIONative y ON y.Phase=1 AND y.DatabaseId=x.DatabaseId AND y.FileId=x.FileId
      CROSS JOIN #ExampleIOObserved3 o JOIN #ExampleIONative ob ON ob.Phase=0 AND ob.DatabaseId=o.DatabaseId AND ob.FileId=o.FileId
      JOIN #ExampleIONative oa ON oa.Phase=1 AND oa.DatabaseId=o.DatabaseId AND oa.FileId=o.FileId
      WHERE x.Phase=0 AND (@Names=@OwnNames OR @Pattern IS NOT NULL OR @Case=37 AND x.DatabaseName=@Upper OR @Names=QUOTENAME(x.DatabaseName))
       AND NOT EXISTS(SELECT 1 FROM #ExampleIOObserved3 q WHERE q.DatabaseId=x.DatabaseId AND q.FileId=x.FileId)
       AND CONVERT(decimal(19,3),(x.ReadStallMs+x.WriteStallMs)*1.0/NULLIF(y.Reads+y.Writes,0))>
        CONVERT(decimal(19,3),(oa.ReadStallMs+oa.WriteStallMs)*1.0/NULLIF(ob.Reads+ob.Writes,0)))
     THROW 59315,N'CURRENT_IO_NATIVE_RANK_BOUNDS',1;
   END;
   IF @Case=41 AND (SELECT COUNT(*) FROM #ExampleIOObserved3)<>0 THROW 59315,N'CURRENT_IO_NATIVE_MINIMUM',1;
   IF @Case=30
   BEGIN
    DECLARE @Field sysname,@Probe nvarchar(max),@One nvarchar(max)=(SELECT TOP(1) value FROM OPENJSON(@ExpectedFiles));
    DECLARE @Fields TABLE(Name sysname COLLATE SQL_Latin1_General_CP1_CS_AS);INSERT @Fields VALUES(N'LogicalName'),(N'PhysicalName'),(N'FileTypeDesc');
    WHILE EXISTS(SELECT 1 FROM @Fields)
    BEGIN
     SELECT TOP(1) @Field=Name FROM @Fields;SET @Probe=JSON_MODIFY(@One,N'strict $.'+@Field,NULL);
     IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Probe) a JOIN OPENJSON(@One) e ON a.[key] COLLATE Latin1_General_100_BIN2=e.[key] COLLATE Latin1_General_100_BIN2
       WHERE a.type<>e.type OR (a.value IS NULL AND e.value IS NOT NULL) OR (a.value IS NOT NULL AND e.value IS NULL)
        OR a.value COLLATE Latin1_General_100_BIN2<>e.value COLLATE Latin1_General_100_BIN2)
      THROW 59316,N'CURRENT_IO_NULL_MUTATION_NOT_REJECTED',1;
     SET @NullMutations+=1;DELETE @Fields WHERE Name=@Field;
    END;
   END;
   SET @NativeCases+=1;
  END
  ELSE SET @CoreCases+=1;
  DROP TABLE #ExampleIOExport1;DROP TABLE #ExampleIOExport2;DROP TABLE #ExampleIOExport3;DROP TABLE #ExampleIOExport4;DROP TABLE #ExampleIOExport5;
 END;
 DECLARE @Consumer int=0;
 WHILE @Consumer<4
 BEGIN
  SET @Json=N'ExampleSentinel';SET @Names=QUOTENAME(@Missing);
  DECLARE @Mode varchar(16)=CASE @Consumer WHEN 0 THEN 'NONE' WHEN 1 THEN 'RAW' WHEN 2 THEN 'NONE' ELSE 'NONE' END,
   @MakeJson bit=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;
  SET @Parent=CASE WHEN @Consumer=3 THEN NEWID() ELSE NULL END;
  EXEC monitor.USP_CurrentIO @DatabaseNames=@Names,@PendingIoEinbeziehen=0,@ParentCurrentStateSnapshotId=@Parent,
   @ResultSetArt=@Mode,@JsonErzeugen=@MakeJson,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF @@LOCK_TIMEOUT<>731 OR (@MakeJson=0 AND @Json IS NOT NULL)
   OR (@MakeJson=1 AND (ISJSON(@Json)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.files'))<>0))
   THROW 59317,N'CURRENT_IO_CONSUMER',1;
  IF @Consumer=3 AND ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'INVALID_PARENT_SNAPSHOT'
   THROW 59317,N'CURRENT_IO_MISSING_PARENT',1;
  SET @Consumer+=1;
 END;
 CREATE TABLE #ExampleIOPreflight1(Dummy int NULL);INSERT #ExampleIOPreflight1 VALUES(4242);
 CREATE TABLE #ExampleIOPreflight2(Dummy int NULL);INSERT #ExampleIOPreflight2 VALUES(4242);
 CREATE TABLE #ExampleIOPreflight3(Dummy int NULL);INSERT #ExampleIOPreflight3 VALUES(4242);
 CREATE TABLE #ExampleIOPreflight4(Dummy int NULL);INSERT #ExampleIOPreflight4 VALUES(4242);
 CREATE TABLE #ExampleIOPreflight5(Dummy int NULL);INSERT #ExampleIOPreflight5 VALUES(4242);
 CREATE TABLE #ExampleIOPreflight6(Dummy int NULL);INSERT #ExampleIOPreflight6 VALUES(4242);
 DECLARE @Preflight int=1,@Rejected int;
 WHILE @Preflight<=6
 BEGIN
  SET @Rejected=0;SET @Json=N'ExampleSentinel';
  SET @Map=CASE @Preflight WHEN 1 THEN N'[]' WHEN 2 THEN N'{}' WHEN 3 THEN N'{"unknown":"#ExampleIOPreflight3"}'
   WHEN 4 THEN N'{"files":"##ExampleGlobalIO190"}' WHEN 5 THEN N'{"files":"#ExampleMissingTarget190"}' ELSE N'{"files":"#ExampleIOPreflight6"}' END;
  BEGIN TRY
   EXEC monitor.USP_CurrentIO @DatabaseNames=@Names,@MaxZeilen=-1,@PendingIoEinbeziehen=0,@ResultSetArt='TABLE',
    @ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  END TRY
  BEGIN CATCH
   IF ERROR_NUMBER()<>51011 THROW;
   SET @Rejected=1;
  END CATCH;
  IF @Rejected<>1 OR @Json<>N'ExampleSentinel' THROW 59318,N'CURRENT_IO_PREFLIGHT',1;
  SET @Target=N'#ExampleIOPreflight'+CONVERT(nvarchar(1),@Preflight);
  IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..'+@Target))<>1 THROW 59318,N'CURRENT_IO_PREFLIGHT_SCHEMA',1;
  SET @Sql=N'IF (SELECT COUNT(*) FROM '+QUOTENAME(@Target)+N')<>1 OR NOT EXISTS(SELECT 1 FROM '+QUOTENAME(@Target)+N' WHERE Dummy=4242) THROW 59318,N''CURRENT_IO_PREFLIGHT_SEED'',1;';EXEC sys.sp_executesql @Sql;
  SET @Preflight+=1;
 END;
 CREATE TABLE #ExampleIOEmptyConsole(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  Status varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,Hinweis nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 DECLARE @Console int=0;
 WHILE @Console<3
 BEGIN
  DELETE #ExampleIOEmptyConsole;SET @Names=QUOTENAME(@Missing);SET @Max=CASE @Console WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
  INSERT #ExampleIOEmptyConsole EXEC monitor.USP_CurrentIO @DatabaseNames=@Names,@MaxZeilen=@Max,@PendingIoEinbeziehen=0,
   @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF (SELECT COUNT(*) FROM #ExampleIOEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleIOEmptyConsole WHERE
    Ergebnis IS NULL OR Ergebnis<>N'Keine Datei-I/O-Daten entsprechen den Filtern.'
    OR Status IS NULL OR Status<>N'AVAILABLE_LIMITED' OR Hinweis IS NOT NULL)
   OR ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE_LIMITED'
   OR ISNULL(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'true'
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH(RequestedName nvarchar(128) '$.RequestedName',StatusCode varchar(40) '$.StatusCode')
    WHERE RequestedName COLLATE Latin1_General_100_BIN2=@Missing COLLATE Latin1_General_100_BIN2 AND StatusCode=N'DATABASE_UNAVAILABLE')
   THROW 59319,N'CURRENT_IO_EMPTY_CONSOLE',1;
  SET @Console+=1;
 END;
 DECLARE @DirectConsole int=0;
 IF @FixtureStatus='PASS'
 WHILE @DirectConsole<3
 BEGIN
  SET @Max=CASE @DirectConsole WHEN 0 THEN 0 WHEN 1 THEN 1 ELSE 2 END;
  EXEC monitor.USP_CurrentIO @DatabaseNames=@OwnNames,@MaxZeilen=@Max,@PendingIoEinbeziehen=0,@ResultSetArt='CONSOLE',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF ISNULL(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE' OR @@LOCK_TIMEOUT<>731
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.files'))<>CASE WHEN @Max=0 THEN 6 ELSE @Max END
   THROW 59320,N'CURRENT_IO_DIRECT_CONSOLE_STATUS_ONLY',1;
  SET @DirectConsole+=1;
 END;
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLock)+N';';EXEC sys.sp_executesql @Sql;
 SELECT N'PASS' ContractStatus,@FrameworkLevel FrameworkLevel,@CoreCases CoreCases,@FixtureStatus PositiveFilesFixtureStatus,
  @NativeCases NativeCases,@NullMutations NullMutationRejections,4 ConsumerCases,6 PreflightCases,3 EmptySqlConsoleCases,
  @DirectConsole DirectConsoleStatusCases,N'NOT_EXECUTED' PositivePendingNativeStatus,65 SchemaFields,23 TextCollations;
END TRY
BEGIN CATCH
 SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLock)+N';';EXEC sys.sp_executesql @Sql;
 DROP TABLE IF EXISTS #ExampleIOExport1;DROP TABLE IF EXISTS #ExampleIOExport2;DROP TABLE IF EXISTS #ExampleIOExport3;
 DROP TABLE IF EXISTS #ExampleIOExport4;DROP TABLE IF EXISTS #ExampleIOExport5;
 DROP TABLE IF EXISTS #ExampleIOSchema1;DROP TABLE IF EXISTS #ExampleIOSchema2;DROP TABLE IF EXISTS #ExampleIOSchema3;
 DROP TABLE IF EXISTS #ExampleIOSchema4;DROP TABLE IF EXISTS #ExampleIOSchema5;
 DROP TABLE IF EXISTS #ExampleIOObserved1;DROP TABLE IF EXISTS #ExampleIOObserved2;DROP TABLE IF EXISTS #ExampleIOObserved3;
 DROP TABLE IF EXISTS #ExampleIOFixture;DROP TABLE IF EXISTS #ExampleIONative;DROP TABLE IF EXISTS #ExampleIOCases;
 DROP TABLE IF EXISTS #ExampleIOPreflight1;DROP TABLE IF EXISTS #ExampleIOPreflight2;DROP TABLE IF EXISTS #ExampleIOPreflight3;
 DROP TABLE IF EXISTS #ExampleIOPreflight4;DROP TABLE IF EXISTS #ExampleIOPreflight5;DROP TABLE IF EXISTS #ExampleIOPreflight6;
 DROP TABLE IF EXISTS #ExampleIOEmptyConsole;
 THROW;
END CATCH;
DROP TABLE #ExampleIOSchema1;DROP TABLE #ExampleIOSchema2;DROP TABLE #ExampleIOSchema3;DROP TABLE #ExampleIOSchema4;DROP TABLE #ExampleIOSchema5;
DROP TABLE #ExampleIOObserved1;DROP TABLE #ExampleIOObserved2;DROP TABLE #ExampleIOObserved3;
DROP TABLE #ExampleIOFixture;DROP TABLE #ExampleIONative;DROP TABLE #ExampleIOCases;
DROP TABLE #ExampleIOPreflight1;DROP TABLE #ExampleIOPreflight2;DROP TABLE #ExampleIOPreflight3;DROP TABLE #ExampleIOPreflight4;DROP TABLE #ExampleIOPreflight5;DROP TABLE #ExampleIOPreflight6;
DROP TABLE #ExampleIOEmptyConsole;
GO
