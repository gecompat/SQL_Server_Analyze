USE [DeineDatenbank];
GO
/*
Zweck: Prüft den freigegebenen Segmentvertrag an eigenen synthetischen Columnstore-Quellen.
Grenzen: Keine fremden Objekte, keine Workload-/Sortierqualitätsbehauptung; originale native Metadaten vor Assertion.
*/
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR @@LOCK_TIMEOUT<>-1 OR (@@OPTIONS&16384)<>0
    THROW 56990,N'Own columnstore fixture requires a clean caller',1;
IF OBJECT_ID(N'tempdb..#129_WI4_Export') IS NOT NULL OR OBJECT_ID(N'tempdb..#129_WI4_Native') IS NOT NULL OR OBJECT_ID(N'tempdb..#129_WI4_After') IS NOT NULL OR OBJECT_ID(N'tempdb..#129_WI4_Oracle') IS NOT NULL
    THROW 56991,N'Own columnstore fixture temp names are occupied',1;
DECLARE @OwnDb sysname=N'ExampleColumnstoreOverlap_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @OwnId int=NULL,@OwnObject int=NULL,@Created bit=0,@CallerDb int=DB_ID(),@CallerSid int=@@SPID,
    @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),@Sql nvarchar(max),@Selection nvarchar(max),
    @Json nvarchar(max),@Physical nvarchar(max),@Case int=0,@Limit int,@ExpectedRows bigint,
    @OriginalError int=NULL,@CleanupError int=NULL,@SourceCount bigint,@NativeStrict bigint,@NativeTouch bigint,
    @SentinelJson nvarchar(max),@DefaultJson nvarchar(max),@DeepColumn int=NULL,@DeepIndex int=NULL,@DeepPartition int=NULL,
    @CallerOptions int=@@OPTIONS,@SnapshotSql nvarchar(max),@OracleLimit int,
    @FixtureCL int=(SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID());
CREATE TABLE [#129_WI4_Native]
(
    [ObjectId] int NULL,[IndexId] int NULL,[PartitionNumber] int NULL,[ColumnId] int NULL,[SegmentId] int NULL,
    [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SystemTypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EncodingType] int NULL,[NativeRowCount] int NULL,[CollationId] int NULL,[MinNumber] bigint NULL,[MaxNumber] bigint NULL,[MinBinary] varbinary(18) NULL,[MaxBinary] varbinary(18) NULL
);
BEGIN TRY
    IF DB_ID(@OwnDb) IS NOT NULL THROW 56991,N'Own columnstore database collision',1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@OwnDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;'; EXEC sys.sp_executesql @Sql;
    SELECT @Created=1,@OwnId=DB_ID(@OwnDb),@Selection=QUOTENAME(@OwnDb);
    IF @OwnId IS NULL OR @OwnId<=0 THROW 56992,N'Own database identity absent',1;
    SELECT N'OWN_COLUMNSTORE_DATABASE' EvidenceKind,@OwnId OwnedDatabaseId;
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@OwnDb)+N' SET COMPATIBILITY_LEVEL='+CONVERT(nvarchar(3),@FixtureCL)+N';';EXEC sys.sp_executesql @Sql;
    SET @Sql=N'USE '+QUOTENAME(@OwnDb)+N';
CREATE TABLE dbo.ExampleOverlap
(
 A_Bit bit NOT NULL,B_Tiny tinyint NOT NULL,C_Small smallint NOT NULL,D_Big bigint NOT NULL,E_Money money NOT NULL,
 F_Binary binary(4) NOT NULL,G_VarBinary varbinary(4) NOT NULL,H_Char char(6) NOT NULL,I_NChar nchar(6) NOT NULL,
 J_Varchar varchar(6) NOT NULL,K_Nvarchar nvarchar(6) NOT NULL,L_Unsupported int NOT NULL,M_Point bigint NOT NULL
);
CREATE CLUSTERED COLUMNSTORE INDEX ExampleOverlapIndex ON dbo.ExampleOverlap;
DECLARE @Batch int=0;
WHILE @Batch<2
BEGIN
 ;WITH d AS(SELECT n FROM(VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9))v(n)),
 nums AS(SELECT TOP(102400) ROW_NUMBER() OVER(ORDER BY a.n,b.n,c.n,d.n,e.n,f.n)-1 n FROM d a CROSS JOIN d b CROSS JOIN d c CROSS JOIN d d CROSS JOIN d e CROSS JOIN d f)
 INSERT dbo.ExampleOverlap WITH(TABLOCK)
 SELECT CONVERT(bit,n%2),CONVERT(tinyint,n%100),CONVERT(smallint,n%200-100+@Batch*100),CONVERT(bigint,n%200-100+@Batch*100),
  CONVERT(money,(n%200-100+@Batch*100)/10.0),CONVERT(binary(4),CONVERT(int,n%200+@Batch*100)),CONVERT(varbinary(4),CONVERT(int,n%200+@Batch*100)),
  RIGHT(''000000''+CONVERT(varchar(6),n%200+@Batch*100),6),RIGHT(N''000000''+CONVERT(nvarchar(6),n%200+@Batch*100),6),
  RIGHT(''000000''+CONVERT(varchar(6),n%200+@Batch*100),6),RIGHT(N''000000''+CONVERT(nvarchar(6),n%200+@Batch*100),6),CONVERT(int,n%200),CONVERT(bigint,7+@Batch*2)
 FROM nums OPTION(MAXDOP 1);
 SET @Batch+=1;
END;
SELECT @ObjectId=OBJECT_ID(N''dbo.ExampleOverlap'');';
    EXEC sys.sp_executesql @Sql,N'@ObjectId int OUTPUT',@ObjectId=@OwnObject OUTPUT;
    IF @OwnObject IS NULL OR @OwnObject<=0 THROW 56992,N'Own object identity absent',1;
    SET @Sql=N'USE '+QUOTENAME(@OwnDb)+N';
INSERT #129_WI4_Native
SELECT p.object_id,p.index_id,p.partition_number,s.column_id,s.segment_id,c.name,t.name,s.encoding_type,s.row_count,s.collation_id,s.min_data_id,s.max_data_id,'
        +CASE WHEN @Major>=16 THEN N's.min_deep_data,s.max_deep_data' ELSE N'CONVERT(varbinary(18),NULL),CONVERT(varbinary(18),NULL)' END+N'
FROM sys.column_store_segments s JOIN sys.partitions p ON p.partition_id=s.partition_id AND p.hobt_id=s.hobt_id
JOIN sys.columns c ON c.object_id=p.object_id AND c.column_id=s.column_id
JOIN sys.types t ON t.system_type_id=c.system_type_id AND t.user_type_id=t.system_type_id
WHERE p.object_id=@ObjectId;';
    SET @SnapshotSql=@Sql;
    EXEC sys.sp_executesql @Sql,N'@ObjectId int',@ObjectId=@OwnObject;
    SELECT N'OWN_ORIGINAL_NATIVE_SEGMENTS' EvidenceKind,* FROM [#129_WI4_Native] ORDER BY IndexId,PartitionNumber,ColumnId,SegmentId;
    SELECT @SourceCount=COUNT_BIG(*) FROM [#129_WI4_Native];
    IF @SourceCount<2 OR @SourceCount>1000 OR EXISTS(SELECT 1 FROM [#129_WI4_Native] WHERE ObjectId<>@OwnObject OR ObjectId IS NULL)
        THROW 56993,N'Positive own native segment source is not bound',1;
    ;WITH Classified AS
    (
      SELECT *,CASE
        WHEN NativeRowCount>0 AND SystemTypeName IN(N'bit',N'tinyint',N'smallint',N'bigint',N'money') AND EncodingType IN(1,2) AND MinNumber IS NOT NULL AND MaxNumber IS NOT NULL AND MinNumber<=MaxNumber THEN 1
        WHEN NativeRowCount>0 AND SystemTypeName IN(N'binary',N'varbinary',N'char',N'nchar',N'varchar',N'nvarchar') AND EncodingType IN(3,5) AND MinBinary IS NOT NULL AND MaxBinary IS NOT NULL AND MinBinary<=MaxBinary AND (SystemTypeName IN(N'binary',N'varbinary') OR CollationId IS NOT NULL) THEN 2
        ELSE NULL END RangeClass
      FROM [#129_WI4_Native]
    ),Grouped AS
    (
      SELECT ObjectId,IndexId,PartitionNumber,ColumnId,MIN(ColumnName) ColumnName,MIN(SystemTypeName) SystemTypeName,COUNT_BIG(*) Observed,
        CASE WHEN COUNT(DISTINCT RangeClass)>1 OR COUNT(DISTINCT SystemTypeName)>1 OR (MAX(CASE WHEN SystemTypeName IN(N'char',N'nchar',N'varchar',N'nvarchar') THEN 1 ELSE 0 END)=1 AND COUNT(DISTINCT CollationId)>1) THEN CONVERT(bigint,0)
          ELSE SUM(CONVERT(bigint,CASE WHEN RangeClass IS NULL THEN 0 ELSE 1 END)) END Comparable
      FROM Classified GROUP BY ObjectId,IndexId,PartitionNumber,ColumnId
    )
    SELECT *,CONVERT(bigint,NULL) StrictPairs,CONVERT(bigint,NULL) TouchPairs,
      ROW_NUMBER() OVER(ORDER BY IndexId,PartitionNumber,ColumnId) OutputOrdinal
    INTO [#129_WI4_Oracle] FROM Grouped;
    UPDATE g SET StrictPairs=(SELECT COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
       WHERE a.IndexId=g.IndexId AND a.PartitionNumber=g.PartitionNumber AND a.ColumnId=g.ColumnId AND ((g.SystemTypeName IN(N'bit',N'tinyint',N'smallint',N'bigint',N'money') AND a.MinNumber<b.MaxNumber AND b.MinNumber<a.MaxNumber) OR (g.SystemTypeName IN(N'binary',N'varbinary',N'char',N'nchar',N'varchar',N'nvarchar') AND a.MinBinary<b.MaxBinary AND b.MinBinary<a.MaxBinary))),
      TouchPairs=(SELECT COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
       WHERE a.IndexId=g.IndexId AND a.PartitionNumber=g.PartitionNumber AND a.ColumnId=g.ColumnId AND ((g.SystemTypeName IN(N'bit',N'tinyint',N'smallint',N'bigint',N'money') AND NOT(a.MinNumber<b.MaxNumber AND b.MinNumber<a.MaxNumber) AND(a.MaxNumber=b.MinNumber OR b.MaxNumber=a.MinNumber)) OR (g.SystemTypeName IN(N'binary',N'varbinary',N'char',N'nchar',N'varchar',N'nvarchar') AND NOT(a.MinBinary<b.MaxBinary AND b.MinBinary<a.MaxBinary) AND(a.MaxBinary=b.MinBinary OR b.MaxBinary=a.MinBinary))))
    FROM [#129_WI4_Oracle] g WHERE g.Observed=g.Comparable;
    SELECT N'INDEPENDENT_NATIVE_ALL_GROUP_ORACLE' EvidenceKind,* FROM [#129_WI4_Oracle] ORDER BY OutputOrdinal;
    SET @Json=NULL;
    EXEC monitor.USP_Columnstore @DatabaseNames=@Selection,@FullObjectNames=N'[dbo].[ExampleOverlap]',@HighImpactConfirmed=1,
        @MitSegmentUeberlappung=0,@MaxSegmenteAnalyse=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    SELECT N'ORIGINAL_DEFAULT_JSON' EvidenceKind,@Json JsonOutput;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.schemaVersion'),N'')<>N'1'
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N'segmentOverlap')
        THROW 56994,N'Default JSON contract changed',1;
    SET @DefaultJson=@Json;
    SET LOCK_TIMEOUT 137;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    WHILE @Case<4
    BEGIN
        CREATE TABLE [#129_WI4_Export]([Seed] bit NULL);
        SET @Limit=CASE @Case WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 2 THEN 1 ELSE 2000 END;
        SET @Json=NULL;
        EXEC monitor.USP_Columnstore @DatabaseNames=@Selection,@FullObjectNames=N'[dbo].[ExampleOverlap]',@HighImpactConfirmed=1,
            @MitSegmentUeberlappung=1,@MaxSegmenteAnalyse=2000,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
            @ResultTablesJson=N'{"segmentOverlap":"#129_WI4_Export"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SELECT N'ORIGINAL_SEGMENT_OVERLAP_JSON' EvidenceKind,@Case CaseOrdinal,@Json JsonOutput;
        EXEC sys.sp_executesql N'SELECT N''ORIGINAL_SEGMENT_OVERLAP_TABLE'' EvidenceKind,* FROM #129_WI4_Export ORDER BY DatabaseName,SchemaName,ObjectName,IndexId,PartitionNumber,ColumnId;';
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.schemaVersion'),N'')<>N'2'
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N'segmentOverlap')
            THROW 56994,N'Activated JSON schema contract changed',1;
        EXEC sys.sp_executesql N'SELECT @Physical=(SELECT * FROM #129_WI4_Export ORDER BY DatabaseName,SchemaName,ObjectName,IndexId,PartitionNumber,ColumnId FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@Physical nvarchar(max) OUTPUT',@Physical=@Physical OUTPUT;
        IF COALESCE(@Physical,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.segmentOverlap'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56995,N'Physical TABLE and same-call JSON differ',1;
        IF (SELECT COUNT_BIG(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#129_WI4_Export'))<>19
           OR EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#129_WI4_Export') AND collation_name IS NOT NULL AND collation_name COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56995,N'Native export schema or collation mismatch',1;
        IF EXISTS(SELECT [column_id],[name],[system_type_id],[max_length],[scale],[is_nullable]
            FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#129_WI4_Export')
            EXCEPT SELECT * FROM(VALUES (1,N'DatabaseName',231,256,0,0),
            (2,N'SchemaName',231,256,0,0),
            (3,N'ObjectName',231,256,0,0),
            (4,N'ObjectId',56,4,0,0),
            (5,N'IndexId',56,4,0,0),
            (6,N'IndexName',231,256,0,1),
            (7,N'PartitionNumber',56,4,0,0),
            (8,N'ColumnId',56,4,0,0),
            (9,N'ColumnName',231,256,0,1),
            (10,N'SystemTypeName',231,256,0,1),
            (11,N'ObservedSegmentCount',127,8,0,0),
            (12,N'ComparableSegmentCount',127,8,0,0),
            (13,N'UncomparableSegmentCount',127,8,0,0),
            (14,N'StrictOverlapPairCount',127,8,0,1),
            (15,N'BoundaryTouchPairCount',127,8,0,1),
            (16,N'SourceStatus',167,40,0,0),
            (17,N'IsPartial',104,1,0,0),
            (18,N'ReasonCode',167,60,0,1),
            (19,N'CollectionTimeUtc',42,7,3,0)) e(Ordinal,Name,TypeId,MaxLength,Scale,Nullable))
            THROW 56995,N'Native ordered export types/nullability mismatch',1;
        IF @Major<16
        BEGIN
            EXEC sys.sp_executesql N'IF EXISTS(SELECT 1 FROM #129_WI4_Export) THROW 56996,N''Fallback produced overlap groups'',1;';
            IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(StatusCode varchar(40) '$.StatusCode',Detail nvarchar(2000) '$.Detail') WHERE StatusCode='UNAVAILABLE_VERSION' AND Detail LIKE N'%COLUMNSTORE_OVERLAP%')
                THROW 56996,N'Native SQL2019 version fallback absent',1;
        END
        ELSE
        BEGIN
            SELECT @ExpectedRows=COUNT_BIG(*) FROM(SELECT IndexId,PartitionNumber,ColumnId FROM [#129_WI4_Native] GROUP BY IndexId,PartitionNumber,ColumnId)g;
            IF @Limit=1 SET @ExpectedRows=1;
            EXEC sys.sp_executesql N'
IF (SELECT COUNT_BIG(*) FROM #129_WI4_Export)<>@ExpectedRows OR EXISTS(SELECT 1 FROM #129_WI4_Export WHERE DatabaseName IS NULL OR SchemaName IS NULL OR ObjectName IS NULL OR ObjectId IS NULL OR IndexId IS NULL OR PartitionNumber IS NULL OR ColumnId IS NULL OR ObservedSegmentCount IS NULL OR ComparableSegmentCount IS NULL OR UncomparableSegmentCount IS NULL OR SourceStatus IS NULL OR IsPartial IS NULL OR CollectionTimeUtc IS NULL OR DatabaseName<>@OwnDb OR SchemaName<>N''dbo'' OR ObjectName<>N''ExampleOverlap'' OR ObjectId<>@OwnObject OR ObservedSegmentCount<>ComparableSegmentCount+UncomparableSegmentCount OR (UncomparableSegmentCount>0 AND (StrictOverlapPairCount IS NOT NULL OR BoundaryTouchPairCount IS NOT NULL OR SourceStatus<>''AVAILABLE_LIMITED'' OR IsPartial<>1)) OR (UncomparableSegmentCount=0 AND (StrictOverlapPairCount IS NULL OR BoundaryTouchPairCount IS NULL OR SourceStatus<>''AVAILABLE'' OR IsPartial<>0 OR ReasonCode IS NOT NULL)))
 THROW 56997,N''Native group completeness/identity contract mismatch'',1;',
                N'@ExpectedRows bigint,@OwnDb sysname,@OwnObject int',@ExpectedRows=@ExpectedRows,@OwnDb=@OwnDb,@OwnObject=@OwnObject;
            SET @OracleLimit=COALESCE(@Limit,0);
            EXEC sys.sp_executesql N'
IF EXISTS(SELECT IndexId,PartitionNumber,ColumnId FROM #129_WI4_Export GROUP BY IndexId,PartitionNumber,ColumnId HAVING COUNT_BIG(*)<>1)
 OR EXISTS(SELECT ObjectId,IndexId,PartitionNumber,ColumnId,ColumnName,SystemTypeName,ObservedSegmentCount,ComparableSegmentCount,UncomparableSegmentCount,StrictOverlapPairCount,BoundaryTouchPairCount,SourceStatus,IsPartial,ReasonCode FROM #129_WI4_Export
 EXCEPT SELECT ObjectId,IndexId,PartitionNumber,ColumnId,ColumnName,SystemTypeName,Observed,Comparable,Observed-Comparable,StrictPairs,TouchPairs,CASE WHEN Observed=Comparable THEN ''AVAILABLE'' ELSE ''AVAILABLE_LIMITED'' END,CONVERT(bit,CASE WHEN Observed=Comparable THEN 0 ELSE 1 END),CASE WHEN Observed<>Comparable THEN ''INCOMPLETE_RANGE_METADATA'' END FROM #129_WI4_Oracle WHERE @Limit<>1 OR OutputOrdinal=1)
 OR EXISTS(SELECT ObjectId,IndexId,PartitionNumber,ColumnId,ColumnName,SystemTypeName,Observed,Comparable,Observed-Comparable,StrictPairs,TouchPairs,CASE WHEN Observed=Comparable THEN ''AVAILABLE'' ELSE ''AVAILABLE_LIMITED'' END,CONVERT(bit,CASE WHEN Observed=Comparable THEN 0 ELSE 1 END),CASE WHEN Observed<>Comparable THEN ''INCOMPLETE_RANGE_METADATA'' END FROM #129_WI4_Oracle WHERE @Limit<>1 OR OutputOrdinal=1
 EXCEPT SELECT ObjectId,IndexId,PartitionNumber,ColumnId,ColumnName,SystemTypeName,ObservedSegmentCount,ComparableSegmentCount,UncomparableSegmentCount,StrictOverlapPairCount,BoundaryTouchPairCount,SourceStatus,IsPartial,ReasonCode FROM #129_WI4_Export)
 THROW 56997,N''Complete native keyed group/pair oracle mismatch'',1;',N'@Limit int',@Limit=@OracleLimit;
            IF @Case<>2
            BEGIN
                IF (SELECT COUNT_BIG(*) FROM [#129_WI4_Native] WHERE ColumnName=N'D_Big' AND EncodingType IN(1,2) AND MinNumber IS NOT NULL AND MaxNumber IS NOT NULL AND MinNumber<=MaxNumber)<2
                    THROW 56993,N'Own numeric native comparison source absent',1;
                SELECT @NativeStrict=COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
                WHERE a.ColumnName=N'D_Big' AND a.MinNumber<b.MaxNumber AND b.MinNumber<a.MaxNumber;
                SELECT @NativeTouch=COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
                WHERE a.ColumnName=N'D_Big' AND NOT(a.MinNumber<b.MaxNumber AND b.MinNumber<a.MaxNumber) AND(a.MaxNumber=b.MinNumber OR b.MaxNumber=a.MinNumber);
                SELECT N'INDEPENDENT_NATIVE_PAIR_ENUMERATION' EvidenceKind,@NativeStrict StrictPairs,@NativeTouch TouchPairs;
                EXEC sys.sp_executesql N'IF NOT EXISTS(SELECT 1 FROM #129_WI4_Export WHERE ColumnName=N''D_Big'' AND StrictOverlapPairCount=@Strict AND BoundaryTouchPairCount=@Touch AND SourceStatus=''AVAILABLE'') THROW 56997,N''Native numeric pair enumeration mismatch'',1;',N'@Strict bigint,@Touch bigint',@Strict=@NativeStrict,@Touch=@NativeTouch;
                SELECT TOP(1) @DeepColumn=ColumnId,@DeepIndex=IndexId,@DeepPartition=PartitionNumber
                FROM [#129_WI4_Native]
                WHERE SystemTypeName IN(N'char',N'nchar',N'varchar',N'nvarchar',N'binary',N'varbinary')
                GROUP BY ColumnId,IndexId,PartitionNumber
                HAVING COUNT_BIG(*)>=2 AND SUM(CASE WHEN EncodingType IN(3,5) AND MinBinary IS NOT NULL AND MaxBinary IS NOT NULL AND MinBinary<=MaxBinary THEN 0 ELSE 1 END)=0
                    AND (MAX(CASE WHEN SystemTypeName IN(N'char',N'nchar',N'varchar',N'nvarchar') THEN 1 ELSE 0 END)=0 OR (COUNT(CollationId)=COUNT(*) AND COUNT(DISTINCT CollationId)=1))
                ORDER BY ColumnId,IndexId,PartitionNumber;
                IF @DeepColumn IS NULL
                    THROW 56993,N'Own positive native deep metadata absent',1;
                SELECT @NativeStrict=COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
                WHERE a.IndexId=@DeepIndex AND a.PartitionNumber=@DeepPartition AND a.ColumnId=@DeepColumn AND a.MinBinary<b.MaxBinary AND b.MinBinary<a.MaxBinary;
                SELECT @NativeTouch=COUNT_BIG(*) FROM [#129_WI4_Native] a JOIN [#129_WI4_Native] b ON a.IndexId=b.IndexId AND a.PartitionNumber=b.PartitionNumber AND a.ColumnId=b.ColumnId AND a.SegmentId<b.SegmentId
                WHERE a.IndexId=@DeepIndex AND a.PartitionNumber=@DeepPartition AND a.ColumnId=@DeepColumn AND NOT(a.MinBinary<b.MaxBinary AND b.MinBinary<a.MaxBinary) AND(a.MaxBinary=b.MinBinary OR b.MaxBinary=a.MinBinary);
                SELECT N'INDEPENDENT_NATIVE_DEEP_PAIR_ENUMERATION' EvidenceKind,@DeepIndex IndexId,@DeepPartition PartitionNumber,@DeepColumn ColumnId,@NativeStrict StrictPairs,@NativeTouch TouchPairs;
                EXEC sys.sp_executesql N'IF NOT EXISTS(SELECT 1 FROM #129_WI4_Export WHERE IndexId=@Index AND PartitionNumber=@Partition AND ColumnId=@Column AND StrictOverlapPairCount=@Strict AND BoundaryTouchPairCount=@Touch AND SourceStatus=''AVAILABLE'') THROW 56997,N''Native deep pair enumeration mismatch'',1;',
                    N'@Index int,@Partition int,@Column int,@Strict bigint,@Touch bigint',@Index=@DeepIndex,@Partition=@DeepPartition,@Column=@DeepColumn,@Strict=@NativeStrict,@Touch=@NativeTouch;
            END;
        END;
        IF @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0 OR @@SPID<>@CallerSid OR DB_ID()<>@CallerDb
            THROW 56998,N'Caller state not preserved',1;
        DROP TABLE [#129_WI4_Export];
        SET @Case+=1;
    END;
    ROLLBACK TRANSACTION;
    SET XACT_ABORT OFF;
    SET LOCK_TIMEOUT -1;
    IF @Major>=16
    BEGIN
        SET @Json=NULL;
        EXEC monitor.USP_Columnstore @DatabaseNames=@Selection,@FullObjectNames=N'[dbo].[ExampleOverlap]',@HighImpactConfirmed=1,
            @MitSegmentUeberlappung=1,@MaxSegmenteAnalyse=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SELECT N'ORIGINAL_SEGMENT_LIMIT_JSON' EvidenceKind,@Json JsonOutput;
        IF COALESCE(JSON_QUERY(@Json,N'$.segmentOverlap'),N'')<>N'[]' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH(StatusCode varchar(40) '$.StatusCode',IsPartial bit '$.IsPartial',Detail nvarchar(2000) '$.Detail') WHERE StatusCode='AVAILABLE_LIMITED' AND IsPartial=1 AND Detail LIKE N'%SEGMENT_LIMIT_EXCEEDED%')
            THROW 56997,N'Segment sentinel did not suppress whole new result',1;
    END;
    SET @Json=NULL;
    EXEC monitor.USP_Columnstore @DatabaseNames=@Selection,@FullObjectNames=N'[dbo].[ExampleOverlap]',@HighImpactConfirmed=1,
        @MitSegmentUeberlappung=1,@MaxSegmenteAnalyse=NULL,@Hilfe=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    SELECT N'ORIGINAL_NULL_HELP_INVALID_LIMIT' EvidenceKind,@Json JsonOutput;
    IF COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER'
        THROW 56997,N'NULL help bypassed activated parameter validation',1;
    SELECT TOP(0) * INTO [#129_WI4_After] FROM [#129_WI4_Native];
    SET @Sql=REPLACE(@SnapshotSql,N'INSERT #129_WI4_Native',N'INSERT #129_WI4_After');
    EXEC sys.sp_executesql @Sql,N'@ObjectId int',@ObjectId=@OwnObject;
    SELECT N'OWN_FINAL_NATIVE_SEGMENTS' EvidenceKind,* FROM [#129_WI4_After] ORDER BY IndexId,PartitionNumber,ColumnId,SegmentId;
    IF (SELECT COUNT_BIG(*) FROM [#129_WI4_Native])<>(SELECT COUNT_BIG(*) FROM [#129_WI4_After])
        OR EXISTS(SELECT * FROM [#129_WI4_Native] EXCEPT SELECT * FROM [#129_WI4_After])
        OR EXISTS(SELECT * FROM [#129_WI4_After] EXCEPT SELECT * FROM [#129_WI4_Native])
        THROW 56998,N'Own native source changed during consumers',1;
    SELECT N'OWN_FINAL_CALLER' EvidenceKind,@@SPID CallerSid,DB_ID() CallerDatabaseId,@@OPTIONS CallerOptions,@@TRANCOUNT TranCount,@@LOCK_TIMEOUT LockTimeout;
    IF @@SPID<>@CallerSid OR DB_ID()<>@CallerDb OR @@OPTIONS<>@CallerOptions OR @@TRANCOUNT<>0 OR @@LOCK_TIMEOUT<>-1
        THROW 56998,N'Final caller not restored',1;
    DROP TABLE [#129_WI4_After];
    IF DB_ID(@OwnDb)<>@OwnId OR DB_ID(@OwnDb) IS NULL THROW 56992,N'Own cleanup database binding changed',1;
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnDb)+N';';EXEC sys.sp_executesql @Sql;
    IF DB_ID(@OwnDb) IS NOT NULL THROW 56999,N'Own database remains after cleanup',1;
    DROP TABLE [#129_WI4_Oracle];
    DROP TABLE [#129_WI4_Native];
    SELECT N'OWN_COLUMNSTORE_CLEANUP' EvidenceKind,DB_ID(@OwnDb) RemainingDatabaseId,@@SPID CallerSid,@@TRANCOUNT TranCount,@@LOCK_TIMEOUT LockTimeout;
END TRY
BEGIN CATCH
    SET @OriginalError=ERROR_NUMBER();
    BEGIN TRY
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        SET XACT_ABORT OFF; SET LOCK_TIMEOUT -1;
    END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY
        IF @Created=1 AND @OwnId IS NOT NULL AND DB_ID(@OwnDb)=@OwnId
        BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@OwnDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@OwnDb)+N';'; EXEC sys.sp_executesql @Sql; END;
    END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY DROP TABLE IF EXISTS [#129_WI4_Export]; END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY DROP TABLE IF EXISTS [#129_WI4_After]; END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY DROP TABLE IF EXISTS [#129_WI4_Oracle]; END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    BEGIN TRY DROP TABLE IF EXISTS [#129_WI4_Native]; END TRY BEGIN CATCH SET @CleanupError=ERROR_NUMBER(); END CATCH;
    SELECT N'OWN_COLUMNSTORE_FAILURE' EvidenceKind,@OriginalError OriginalErrorNumber,@CleanupError CleanupErrorNumber,DB_ID(@OwnDb) RemainingDatabaseId;
    THROW;
END CATCH;
GO
