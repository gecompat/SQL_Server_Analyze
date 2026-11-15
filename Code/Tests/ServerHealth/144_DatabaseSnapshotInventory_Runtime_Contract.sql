USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57740,N'Database snapshot contract requires the isolated remote CI sysadmin target without an ambient transaction.',1;
IF COALESCE(TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),-1) NOT IN (15,16,17)
    THROW 57741,N'Database snapshot contract requires a selected SQL Server 2019, 2022, or 2025 native CI target.',1;
GO

DECLARE @Suffix nvarchar(48)=CONVERT(nvarchar(12),@@SPID)+N'_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),16),
        @SourceDb sysname,@SnapshotA sysname,@SnapshotB sysname,@Missing sysname,
        @Reader sysname,@FixtureCredential nvarchar(128),@OriginalLogin sysname=SUSER_SNAME(),
        @SourceFile sysname,@SourceFileTwo sysname,@SourcePhysical nvarchar(260),@Directory nvarchar(260),
        @SourcePathTwo nvarchar(max),@SnapshotPathA1 nvarchar(max),@SnapshotPathA2 nvarchar(max),
        @SnapshotPathB1 nvarchar(max),@SnapshotPathB2 nvarchar(max),
        @Sql nvarchar(max),@StressSql nvarchar(max),@Json nvarchar(max),@Names nvarchar(max),
        @Map nvarchar(max),@AfterInnerLock int=NULL,
        @Return int,@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),
        @SourceCreated bit=0,@SnapshotACreated bit=0,@SnapshotBCreated bit=0,
        @LoginCreated bit=0,@UserCreated bit=0,@Impersonating bit=0,
        @NativeError int=NULL,@CleanupError int=NULL,@Failure nvarchar(2048)=NULL,
        @OriginalLock int=@@LOCK_TIMEOUT,
        @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @TransactionStatus varchar(40),@TransactionCount int,@TransactionXactState int,
        @AfterTransactionCount int,@AfterTransactionXactState int;
SELECT @SourceDb=N'ExampleSnapshotSource_'+@Suffix,
       @SnapshotA=N'ExampleSnapshotA_'+@Suffix,
       @SnapshotB=N'ExampleSnapshotB_'+@Suffix,
       @Missing=N'ExampleMissingSnapshot_'+@Suffix,
       @SourceFileTwo=N'ExampleSnapshotDataTwo_'+@Suffix,
       @Reader=N'ExampleSnapshotReader_'+@Suffix,
       @FixtureCredential=N'Example!'+CONVERT(nvarchar(36),NEWID());
IF DB_ID(@SourceDb) IS NOT NULL OR DB_ID(@SnapshotA) IS NOT NULL OR DB_ID(@SnapshotB) IS NOT NULL OR DB_ID(@Missing) IS NOT NULL OR SUSER_ID(@Reader) IS NOT NULL
    THROW 57742,N'Database snapshot owned fixture name collision.',1;
CREATE TABLE #SnapshotOut_moduleStatus(Seed int NULL);
CREATE TABLE #SnapshotOut_snapshots(Seed int NULL);
CREATE TABLE #SnapshotOut_snapshotFiles(Seed int NULL);
CREATE TABLE #SnapshotOut_sourceStatus(Seed int NULL);
CREATE TABLE #SnapshotOut_warnings(Seed int NULL);
CREATE TABLE #SnapshotConsole
(Ergebnis nvarchar(200) NULL,Bereich nvarchar(64) NULL,Objekt nvarchar(260) NULL,Detail nvarchar(1000) NULL);
CREATE TABLE #RestrictedNativeSnapshots
(SnapshotDatabaseId int NOT NULL,SnapshotName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 SourceDatabaseId int NOT NULL,SourceDatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 CatalogCreateDate datetime NOT NULL,SnapshotStateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 IsReadOnly bit NULL);
CREATE TABLE #RestrictedNativeFiles
(SnapshotDatabaseId int NOT NULL,FileId int NOT NULL,
 LogicalFileName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 PhysicalName nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 IsSparse bit NOT NULL,FileStateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
 MaximumSnapshotSizePages int NOT NULL,MaximumSnapshotSizeBytes bigint NOT NULL);
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@SourceDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @SourceCreated=1;
    SELECT TOP(1) @SourceFile=f.name,@SourcePhysical=f.physical_name
    FROM [master].[sys].[master_files] AS f
    WHERE f.database_id=DB_ID(@SourceDb) AND f.type=0 ORDER BY f.file_id;
    IF @SourceFile IS NULL OR @SourcePhysical IS NULL
       OR CHARINDEX(N'/',REVERSE(@SourcePhysical))=0
        THROW 57743,N'Database snapshot fixture source file location unavailable in selected Linux CI target.',1;
    SET @Directory=LEFT(@SourcePhysical,LEN(@SourcePhysical)-CHARINDEX(N'/',REVERSE(@SourcePhysical))+1);
    SELECT @SourcePathTwo=@Directory+@SourceFileTwo+N'.ndf',
           @SnapshotPathA1=@Directory+@SnapshotA+N'_1.ss',
           @SnapshotPathA2=@Directory+@SnapshotA+N'_2.ss',
           @SnapshotPathB1=@Directory+@SnapshotB+N'_1.ss',
           @SnapshotPathB2=@Directory+@SnapshotB+N'_2.ss';
    IF LEN(@SourcePathTwo)>260 OR LEN(@SnapshotPathA1)>260 OR LEN(@SnapshotPathA2)>260
       OR LEN(@SnapshotPathB1)>260 OR LEN(@SnapshotPathB2)>260
        THROW 57744,N'Database snapshot synthetic file path exceeds native catalog width.',1;
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@SourceDb)
        +N' ADD FILE (NAME='+QUOTENAME(@SourceFileTwo,N'''')
        +N',FILENAME=N'''+REPLACE(@SourcePathTwo,N'''',N'''''')
        +N''',SIZE=8MB) TO FILEGROUP [PRIMARY];';
    EXEC [master].[sys].[sp_executesql] @Sql;
    IF (SELECT COUNT_BIG(*) FROM master.sys.master_files
        WHERE database_id=DB_ID(@SourceDb) AND type=0)<>2
        THROW 57761,N'Database snapshot fixture source does not have exactly two owned data files.',1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@SnapshotA)
        +N' ON (NAME='+QUOTENAME(@SourceFile,N'''')
        +N',FILENAME=N'''+REPLACE(@SnapshotPathA1,N'''',N'''''')
        +N'''),(NAME='+QUOTENAME(@SourceFileTwo,N'''')
        +N',FILENAME=N'''+REPLACE(@SnapshotPathA2,N'''',N'''''')
        +N''') AS SNAPSHOT OF '+QUOTENAME(@SourceDb)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @SnapshotACreated=1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@SnapshotB)
        +N' ON (NAME='+QUOTENAME(@SourceFile,N'''')
        +N',FILENAME=N'''+REPLACE(@SnapshotPathB1,N'''',N'''''')
        +N'''),(NAME='+QUOTENAME(@SourceFileTwo,N'''')
        +N',FILENAME=N'''+REPLACE(@SnapshotPathB2,N'''',N'''''')
        +N''') AS SNAPSHOT OF '+QUOTENAME(@SourceDb)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @SnapshotBCreated=1;

    IF (SELECT COUNT_BIG(*) FROM master.sys.databases
        WHERE database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB))
          AND source_database_id=DB_ID(@SourceDb) AND state=0)<>2
        THROW 57745,N'Database snapshot native positive fixture did not create two ONLINE snapshots.',1;
    IF (SELECT COUNT_BIG(*) FROM master.sys.master_files
        WHERE database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB)) AND is_sparse=1)<>4
        THROW 57746,N'Database snapshot native positive fixture lacks sparse file catalog rows.',1;

    SET @Names=QUOTENAME(@SnapshotA)+N'|'+QUOTENAME(@SnapshotB);
    SET @Map=N'{"moduleStatus":"#SnapshotOut_moduleStatus","snapshots":"#SnapshotOut_snapshots","snapshotFiles":"#SnapshotOut_snapshotFiles","sourceStatus":"#SnapshotOut_sourceStatus","warnings":"#SnapshotOut_warnings"}';
    SET @StressSql=N'SET LOCK_TIMEOUT 7000;
        EXEC @RetOut=[monitor].[USP_DatabaseSnapshotInventory]
            @SnapshotNames=@NamesIn,@ResultSetArt=''TABLE'',@ResultTablesJson=@MapIn,
            @JsonErzeugen=1,@Json=@JsonOut OUTPUT,@PrintMeldungen=0,
            @StatusCodeOut=@StatusOut OUTPUT,@IsPartialOut=@PartialOut OUTPUT,
            @ErrorNumberOut=@ErrorOut OUTPUT,@ErrorMessageOut=@MessageOut OUTPUT;
        SELECT @AfterLockOut=@@LOCK_TIMEOUT;';
    EXEC [sys].[sp_executesql] @StressSql,
        N'@NamesIn nvarchar(max),@MapIn nvarchar(max),@RetOut int OUTPUT,
          @JsonOut nvarchar(max) OUTPUT,@StatusOut varchar(40) OUTPUT,
          @PartialOut bit OUTPUT,@ErrorOut int OUTPUT,@MessageOut nvarchar(2048) OUTPUT,
          @AfterLockOut int OUTPUT',
        @NamesIn=@Names,@MapIn=@Map,@RetOut=@Return OUTPUT,
        @JsonOut=@Json OUTPUT,@StatusOut=@Status OUTPUT,@PartialOut=@Partial OUTPUT,
        @ErrorOut=@Error OUTPUT,@MessageOut=@Message OUTPUT,@AfterLockOut=@AfterInnerLock OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(@AfterInnerLock,-1)<>7000 OR @@LOCK_TIMEOUT<>@OriginalLock
        THROW 57747,N'Database snapshot positive status or caller lock-timeout contract failed.',1;
    IF COALESCE(ISJSON(@Json),0)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>6
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='meta' AND [type]=5)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='moduleStatus' AND [type]=4)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='snapshots' AND [type]=4)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='snapshotFiles' AND [type]=4)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='sourceStatus' AND [type]=4)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]='warnings' AND [type]=4)<>1
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json)
                 WHERE [key] NOT IN('meta','moduleStatus','snapshots','snapshotFiles','sourceStatus','warnings'))
       OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>'AVAILABLE_LIMITED'
       OR COALESCE(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>'true'
       OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>1
        THROW 57748,N'Database snapshot JSON envelope contract failed.',1;
    IF (SELECT COUNT_BIG(*) FROM #SnapshotOut_snapshots)<>2
       OR (SELECT COUNT_BIG(*) FROM #SnapshotOut_snapshotFiles)<>4
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshots'))<>2
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshotFiles'))<>4
       OR EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json,'$.snapshots') AS j
           WHERE (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.[value])
                  WHERE [key] IN('SnapshotDatabaseId','SnapshotName','SourceDatabaseId',
                                 'SourceDatabaseName','CatalogCreateDate','SnapshotStateDesc',
                                 'IsReadOnly','VisibleSparseFileCount','FileMetadataStatus',
                                 'MetadataVisibility'))<>10
              OR (SELECT COUNT(*) FROM OPENJSON(j.[value]))<>10
       )
       OR EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json,'$.snapshotFiles') AS j
           WHERE (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.[value])
                  WHERE [key] IN('SnapshotDatabaseId','SnapshotName','FileId','LogicalFileName',
                                 'PhysicalName','IsSparse','FileStateDesc',
                                 'MaximumSnapshotSizePages','MaximumSnapshotSizeBytes',
                                 'MetadataVisibility'))<>10
              OR (SELECT COUNT(*) FROM OPENJSON(j.[value]))<>10
       )
       OR COALESCE(COL_LENGTH(N'tempdb..#SnapshotOut_snapshotFiles',N'MaximumSnapshotSizeBytes'),-1)<>8
       OR COALESCE(COL_LENGTH(N'tempdb..#SnapshotOut_snapshotFiles',N'PhysicalName'),-1)<>520
       OR EXISTS(SELECT 1 FROM #SnapshotOut_snapshots
                 WHERE COALESCE(VisibleSparseFileCount,-1)<>2
                    OR FileMetadataStatus<>'AVAILABLE_LIMITED'
                    OR MetadataVisibility<>'VISIBLE_ONLY')
       OR EXISTS(SELECT 1 FROM #SnapshotOut_snapshotFiles
                 WHERE MetadataVisibility<>'VISIBLE_ONLY')
        THROW 57749,N'Database snapshot positive result cardinality or native TABLE type failed.',1;
    IF EXISTS
    (
        SELECT d.database_id,d.name,d.source_database_id,src.name,d.create_date,d.state_desc,d.is_read_only
        FROM master.sys.databases AS d
        LEFT JOIN master.sys.databases AS src ON src.database_id=d.source_database_id
        WHERE d.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB))
        EXCEPT
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM #SnapshotOut_snapshots
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM #SnapshotOut_snapshots
        EXCEPT
        SELECT d.database_id,d.name,d.source_database_id,src.name,d.create_date,d.state_desc,d.is_read_only
        FROM master.sys.databases AS d
        LEFT JOIN master.sys.databases AS src ON src.database_id=d.source_database_id
        WHERE d.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB))
    )
        THROW 57750,N'Database snapshot TABLE snapshot identities differ from native catalog.',1;
    IF EXISTS
    (
        SELECT f.database_id,f.file_id,f.name,f.physical_name,f.is_sparse,f.state_desc,
               f.size,CONVERT(bigint,f.size)*8192
        FROM master.sys.master_files AS f
        WHERE f.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB)) AND f.is_sparse=1
        EXCEPT
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,FileStateDesc,
               MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM #SnapshotOut_snapshotFiles
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,FileStateDesc,
               MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM #SnapshotOut_snapshotFiles
        EXCEPT
        SELECT f.database_id,f.file_id,f.name,f.physical_name,f.is_sparse,f.state_desc,
               f.size,CONVERT(bigint,f.size)*8192
        FROM master.sys.master_files AS f
        WHERE f.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB)) AND f.is_sparse=1
    )
        THROW 57751,N'Database snapshot TABLE file metadata differs from native catalog.',1;
    IF EXISTS
    (
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM #SnapshotOut_snapshots
        EXCEPT
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM OPENJSON(@Json,'$.snapshots') WITH
        (
            SnapshotDatabaseId int,SnapshotName sysname,SourceDatabaseId int,
            SourceDatabaseName sysname,CatalogCreateDate datetime,
            SnapshotStateDesc nvarchar(60),IsReadOnly bit
        )
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM OPENJSON(@Json,'$.snapshots') WITH
        (
            SnapshotDatabaseId int,SnapshotName sysname,SourceDatabaseId int,
            SourceDatabaseName sysname,CatalogCreateDate datetime,
            SnapshotStateDesc nvarchar(60),IsReadOnly bit
        )
        EXCEPT
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM #SnapshotOut_snapshots
    )
        THROW 57752,N'Database snapshot JSON and typed TABLE snapshot identities differ.',1;
    IF EXISTS
    (
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM #SnapshotOut_snapshotFiles
        EXCEPT
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM OPENJSON(@Json,'$.snapshotFiles') WITH
        (
            SnapshotDatabaseId int,FileId int,LogicalFileName sysname,PhysicalName nvarchar(260),
            IsSparse bit,FileStateDesc nvarchar(60),MaximumSnapshotSizePages int,
            MaximumSnapshotSizeBytes bigint
        )
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM OPENJSON(@Json,'$.snapshotFiles') WITH
        (
            SnapshotDatabaseId int,FileId int,LogicalFileName sysname,PhysicalName nvarchar(260),
            IsSparse bit,FileStateDesc nvarchar(60),MaximumSnapshotSizePages int,
            MaximumSnapshotSizeBytes bigint
        )
        EXCEPT
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM #SnapshotOut_snapshotFiles
    )
        THROW 57753,N'Database snapshot JSON and typed TABLE file metadata differ.',1;

    EXEC [monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Missing,@ResultSetArt='RAW',@PrintMeldungen=0
    WITH RESULT SETS
    (
        (ModuleName nvarchar(128),CapturedAtUtc datetime2(3),StatusCode varchar(40),
         IsPartial bit,RowCount bigint,Detail nvarchar(1000)),
        (SnapshotDatabaseId int,SnapshotName nvarchar(128),SourceDatabaseId int,
         SourceDatabaseName nvarchar(128),CatalogCreateDate datetime,
         SnapshotStateDesc nvarchar(60),IsReadOnly bit,VisibleSparseFileCount bigint,
         FileMetadataStatus varchar(40),MetadataVisibility varchar(32)),
        (SnapshotDatabaseId int,SnapshotName nvarchar(128),FileId int,
         LogicalFileName nvarchar(128),PhysicalName nvarchar(260),IsSparse bit,
         FileStateDesc nvarchar(60),MaximumSnapshotSizePages int,
         MaximumSnapshotSizeBytes bigint,MetadataVisibility varchar(32)),
        (DatabaseId int,DatabaseName nvarchar(128),SourceKey varchar(64),
         SourceKind varchar(16),StartedAtUtc datetime2(3),CompletedAtUtc datetime2(3),
         StatusCode varchar(40),VisibilityScope varchar(32),ObservedRows bigint,
         ReturnedRows bigint,IsLimited bit,ErrorNumber int,ErrorMessage nvarchar(2048)),
        (DatabaseId int,DatabaseName nvarchar(128),WarningCode varchar(64),
         SourceKey varchar(64),Detail nvarchar(1000))
    );

    INSERT #SnapshotConsole
    EXEC [monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Names,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM #SnapshotConsole WHERE Bereich=N'Snapshot'
        AND Objekt IN(@SnapshotA,@SnapshotB))<>2
       OR NOT EXISTS(SELECT 1 FROM #SnapshotConsole WHERE Bereich=N'Datei')
       OR NOT EXISTS(SELECT 1 FROM #SnapshotConsole WHERE Bereich=N'Quelle')
        THROW 57763,N'Database snapshot CONSOLE one-result-set synthetic oracle failed.',1;

    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)
        +N' WITH PASS'+N'WORD='+QUOTENAME(@FixtureCredential,N'''')
        +N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @UserCreated=1;
    SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_DatabaseSnapshotInventory] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE [master]; GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Reader)+N'; GRANT VIEW ANY DEFINITION TO '+QUOTENAME(@Reader)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    IF COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),-1)<>0
        THROW 57764,N'Database snapshot restricted fixture caller unexpectedly has sysadmin.',1;
    INSERT #RestrictedNativeSnapshots
    SELECT d.database_id,d.name,d.source_database_id,src.name,d.create_date,d.state_desc,d.is_read_only
    FROM master.sys.databases AS d
    LEFT JOIN master.sys.databases AS src ON src.database_id=d.source_database_id
    WHERE d.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB));
    INSERT #RestrictedNativeFiles
    SELECT f.database_id,f.file_id,f.name,f.physical_name,f.is_sparse,f.state_desc,
           f.size,CONVERT(bigint,f.size)*8192
    FROM master.sys.master_files AS f
    WHERE f.database_id IN(DB_ID(@SnapshotA),DB_ID(@SnapshotB)) AND f.is_sparse=1;
    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR (SELECT COUNT_BIG(*) FROM #RestrictedNativeSnapshots)<>2
       OR (SELECT COUNT_BIG(*) FROM #RestrictedNativeFiles)<>4
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshots'))<>2
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshotFiles'))<>4
        THROW 57765,N'Database snapshot restricted caller setup or product status failed.',1;
    IF EXISTS
    (
        SELECT 1 FROM OPENJSON(@Json,'$.snapshots') AS j
        WHERE (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.[value])
               WHERE [key] IN('SnapshotDatabaseId','SnapshotName','SourceDatabaseId',
                              'SourceDatabaseName','CatalogCreateDate','SnapshotStateDesc',
                              'IsReadOnly','VisibleSparseFileCount','FileMetadataStatus',
                              'MetadataVisibility'))<>10
           OR (SELECT COUNT(*) FROM OPENJSON(j.[value]))<>10
    )
       OR EXISTS
    (
        SELECT 1 FROM OPENJSON(@Json,'$.snapshotFiles') AS j
        WHERE (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.[value])
               WHERE [key] IN('SnapshotDatabaseId','SnapshotName','FileId','LogicalFileName',
                              'PhysicalName','IsSparse','FileStateDesc',
                              'MaximumSnapshotSizePages','MaximumSnapshotSizeBytes',
                              'MetadataVisibility'))<>10
           OR (SELECT COUNT(*) FROM OPENJSON(j.[value]))<>10
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly FROM #RestrictedNativeSnapshots
        EXCEPT
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM OPENJSON(@Json,'$.snapshots') WITH
        (SnapshotDatabaseId int,SnapshotName sysname,SourceDatabaseId int,
         SourceDatabaseName sysname,CatalogCreateDate datetime,SnapshotStateDesc nvarchar(60),IsReadOnly bit)
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly
        FROM OPENJSON(@Json,'$.snapshots') WITH
        (SnapshotDatabaseId int,SnapshotName sysname,SourceDatabaseId int,
         SourceDatabaseName sysname,CatalogCreateDate datetime,SnapshotStateDesc nvarchar(60),IsReadOnly bit)
        EXCEPT
        SELECT SnapshotDatabaseId,SnapshotName,SourceDatabaseId,SourceDatabaseName,
               CatalogCreateDate,SnapshotStateDesc,IsReadOnly FROM #RestrictedNativeSnapshots
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes FROM #RestrictedNativeFiles
        EXCEPT
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM OPENJSON(@Json,'$.snapshotFiles') WITH
        (SnapshotDatabaseId int,FileId int,LogicalFileName sysname,PhysicalName nvarchar(260),
         IsSparse bit,FileStateDesc nvarchar(60),MaximumSnapshotSizePages int,MaximumSnapshotSizeBytes bigint)
    )
       OR EXISTS
    (
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes
        FROM OPENJSON(@Json,'$.snapshotFiles') WITH
        (SnapshotDatabaseId int,FileId int,LogicalFileName sysname,PhysicalName nvarchar(260),
         IsSparse bit,FileStateDesc nvarchar(60),MaximumSnapshotSizePages int,MaximumSnapshotSizeBytes bigint)
        EXCEPT
        SELECT SnapshotDatabaseId,FileId,LogicalFileName,PhysicalName,IsSparse,
               FileStateDesc,MaximumSnapshotSizePages,MaximumSnapshotSizeBytes FROM #RestrictedNativeFiles
    )
        THROW 57766,N'Database snapshot restricted caller and direct native catalogs differ.',1;
    REVERT;
    SET @Impersonating=0;
    IF SUSER_SNAME()<>@OriginalLogin
        THROW 57767,N'Database snapshot fixture caller context was not restored.',1;

    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Names,@NurOnline=0,@SystemdatenbankenEinbeziehen=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshots'))<>2
        THROW 57760,N'Database snapshot explicit catalog-state and system-source filter contract failed.',1;

    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Names,@MaxZeilen=1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshots'))<>1
       OR TRY_CONVERT(int,JSON_VALUE(@Json,'$.snapshots[0].SnapshotDatabaseId')) IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshotFiles'))<>2
       OR EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json,'$.snapshotFiles')
           WHERE TRY_CONVERT(int,JSON_VALUE([value],'$.SnapshotDatabaseId')) IS NULL
              OR TRY_CONVERT(int,JSON_VALUE([value],'$.SnapshotDatabaseId'))
                 <>TRY_CONVERT(int,JSON_VALUE(@Json,'$.snapshots[0].SnapshotDatabaseId'))
       )
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshotFiles')) <>
          (SELECT COUNT_BIG(*) FROM master.sys.master_files
           WHERE database_id=TRY_CONVERT(int,JSON_VALUE(@Json,'$.snapshots[0].SnapshotDatabaseId'))
             AND is_sparse=1)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')
                     WHERE JSON_VALUE([value],'$.WarningCode')='OUTPUT_LIMIT')
        THROW 57754,N'Database snapshot output limit and complete-file-set contract failed.',1;

    SET @Json=NULL;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Missing,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'SKIPPED'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.snapshots'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')
                     WHERE JSON_VALUE([value],'$.WarningCode')='SNAPSHOT_UNAVAILABLE')
        THROW 57755,N'Database snapshot explicit missing target was treated as a positive result.',1;

    CREATE TABLE #InvalidSnapshotInputs
    (
        CaseId int NOT NULL PRIMARY KEY, Names nvarchar(max) NULL,
        Online bit NULL, [System] bit NULL, MaxRows int NULL, LockMs int NULL,
        Mode varchar(16) NULL, MapJson nvarchar(max) NULL
    );
    INSERT #InvalidSnapshotInputs VALUES
        (1,@Names,NULL,0,1000,0,'NONE',NULL),
        (2,@Names,1,NULL,1000,0,'NONE',NULL),
        (3,@Names,1,0,1000,NULL,'NONE',NULL),
        (4,@Names,1,0,1000,-1,'NONE',NULL),
        (5,@Names,1,0,1000,60001,'NONE',NULL),
        (6,@Names,1,0,-1,0,'NONE',NULL),
        (7,@Names,1,0,1000,0,NULL,NULL),
        (8,@Names,1,0,1000,0,'',NULL),
        (9,@Names,1,0,1000,0,'FOREIGN',NULL),
        (10,@Names,1,0,1000,0,'TABLE',N'{}'),
        (11,N'[Malformed',1,0,1000,0,'NONE',NULL),
        (12,N'[Example]|[Example]',1,0,1000,0,'NONE',NULL);
    DECLARE @CaseId int,@BadNames nvarchar(max),@BadOnline bit,@BadSystem bit,
            @BadMax int,@BadLock int,@BadMode varchar(16),@BadMap nvarchar(max);
    DECLARE InvalidSnapshotCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT CaseId,Names,Online,[System],MaxRows,LockMs,Mode,MapJson
        FROM #InvalidSnapshotInputs ORDER BY CaseId;
    OPEN InvalidSnapshotCursor;
    FETCH NEXT FROM InvalidSnapshotCursor INTO
        @CaseId,@BadNames,@BadOnline,@BadSystem,@BadMax,@BadLock,@BadMode,@BadMap;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @Json=N'PREVIOUS',@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL,@Return=NULL;
        EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
            @SnapshotNames=@BadNames,@NurOnline=@BadOnline,
            @SystemdatenbankenEinbeziehen=@BadSystem,
            @MaxZeilen=@BadMax,@LockTimeoutMs=@BadLock,
            @ResultSetArt=@BadMode,@ResultTablesJson=@BadMap,
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
            @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF COALESCE(@Return,-1)<>51011 OR COALESCE(@Status,'')<>'INVALID_PARAMETER'
           OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,-1)<>51011
           OR @Message IS NULL OR @Json IS NOT NULL
           OR @@LOCK_TIMEOUT<>@OriginalLock OR @@TRANCOUNT<>0
            THROW 57756,N'Database snapshot invalid input, JSON clear, or caller-state contract failed.',1;
        FETCH NEXT FROM InvalidSnapshotCursor INTO
            @CaseId,@BadNames,@BadOnline,@BadSystem,@BadMax,@BadLock,@BadMode,@BadMap;
    END;
    CLOSE InvalidSnapshotCursor; DEALLOCATE InvalidSnapshotCursor;

    BEGIN TRANSACTION;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @Hilfe=1,@ResultSetArt='FOREIGN',@JsonErzeugen=1,
        @Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    SELECT @TransactionCount=@@TRANCOUNT;
    SELECT @TransactionXactState=XACT_STATE();
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE'
       OR COALESCE(@Partial,1)<>0 OR @Json IS NOT NULL
       OR @TransactionCount<>1 OR @TransactionXactState<>1
        THROW 57769,N'Database snapshot help must precede validation and work inside caller transaction.',1;
    ROLLBACK TRANSACTION;
    SELECT @AfterTransactionCount=@@TRANCOUNT;
    SELECT @AfterTransactionXactState=XACT_STATE();
    IF @AfterTransactionCount<>0 OR @AfterTransactionXactState<>0
        THROW 57770,N'Database snapshot help changed caller transaction state.',1;

    BEGIN TRANSACTION;
    EXEC @Return=[monitor].[USP_DatabaseSnapshotInventory]
        @SnapshotNames=@Names,@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@TransactionStatus OUTPUT;
    SELECT @TransactionCount=@@TRANCOUNT;
    SELECT @TransactionXactState=XACT_STATE();
    ROLLBACK TRANSACTION;
    SELECT @AfterTransactionCount=@@TRANCOUNT;
    SELECT @AfterTransactionXactState=XACT_STATE();
    IF COALESCE(@Return,-1)<>51011 OR COALESCE(@TransactionStatus,'')<>'INVALID_PARAMETER'
       OR COALESCE(@TransactionCount,-1)<>1 OR COALESCE(@TransactionXactState,-1)<>1
       OR COALESCE(@AfterTransactionCount,-1)<>0 OR COALESCE(@AfterTransactionXactState,-1)<>0
        THROW 57757,N'Database snapshot caller transaction guard failed.',1;
END TRY
BEGIN CATCH
    SET @NativeError=ERROR_NUMBER();
    SET @Failure=N'DATABASE_SNAPSHOT_RUNTIME_CONTRACT native='+CONVERT(nvarchar(20),@NativeError);
END CATCH;

BEGIN TRY
    IF @Impersonating=1
    BEGIN
        REVERT;
        SET @Impersonating=0;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @UserCreated=1 AND USER_ID(@Reader) IS NOT NULL
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @LoginCreated=1 AND SUSER_ID(@Reader) IS NOT NULL
    BEGIN
        SET @Sql=N'USE [master]; DROP LOGIN '+QUOTENAME(@Reader)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @SnapshotBCreated=1 AND DB_ID(@SnapshotB) IS NOT NULL
    BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@SnapshotB)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @SnapshotACreated=1 AND DB_ID(@SnapshotA) IS NOT NULL
    BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@SnapshotA)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @SourceCreated=1 AND DB_ID(@SourceDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@SourceDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@SourceDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
BEGIN TRY
    IF @@LOCK_TIMEOUT<>@OriginalLock
        THROW 57762,N'Database snapshot fixture caller lock-timeout changed outside the scoped stress batch.',1;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
END TRY BEGIN CATCH
    IF @CleanupError IS NULL SET @CleanupError=ERROR_NUMBER();
END CATCH;
IF @CleanupError IS NULL AND
   (DB_ID(@SourceDb) IS NOT NULL OR DB_ID(@SnapshotA) IS NOT NULL OR DB_ID(@SnapshotB) IS NOT NULL
    OR USER_ID(@Reader) IS NOT NULL OR SUSER_ID(@Reader) IS NOT NULL OR @Impersonating<>0
    OR SUSER_SNAME()<>@OriginalLogin)
    SET @CleanupError=57768;
IF @CleanupError IS NOT NULL
BEGIN
    SET @Failure=N'DATABASE_SNAPSHOT_CLEANUP native='+CONVERT(nvarchar(20),@CleanupError);
    THROW 57758,@Failure,1;
END;
IF @Failure IS NOT NULL THROW 57759,@Failure,1;
PRINT N'Database snapshot inventory native contract passed.';
GO
