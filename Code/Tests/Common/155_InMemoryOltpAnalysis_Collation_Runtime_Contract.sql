USE [DeineDatenbank];
GO
/*
Prüft In-Memory-OLTP-Findings mit zwei kleinen eigenen XTP-Tabellen.
Der opt-in Hashscan ist auf deren synthetische Daten beschränkt.
*/
SET NOCOUNT ON;
IF DB_ID(N'ExampleInMemorySourceÄ') IS NOT NULL
    THROW 56070,N'In-memory fixture already exists.',1;
DECLARE @OwnedDatabaseId int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT;
BEGIN TRY
    CREATE DATABASE [ExampleInMemorySourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedDatabaseId=DB_ID(N'ExampleInMemorySourceÄ');
    DECLARE @DataPath nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultDataPath'));
    IF NULLIF(@DataPath,N'') IS NULL THROW 56075,N'In-memory fixture data directory unavailable.',1;
    ALTER DATABASE [ExampleInMemorySourceÄ] ADD FILEGROUP [ExampleMemoryGroup] CONTAINS MEMORY_OPTIMIZED_DATA;
    DECLARE @FileSql nvarchar(max)=N'ALTER DATABASE [ExampleInMemorySourceÄ] ADD FILE (NAME=N''ExampleMemoryContainer'',FILENAME=N'''
      +REPLACE(@DataPath+N'ExampleInMemorySourceContainer-'+CONVERT(nvarchar(36),NEWID()),N'''',N'''''')+N''') TO FILEGROUP [ExampleMemoryGroup];';
    EXEC [sys].[sp_executesql] @FileSql;
    EXEC(N'USE [ExampleInMemorySourceÄ]; CREATE TABLE [dbo].[ExampleXtpTableÄ]
           ([ExampleId] int NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT=8))
           WITH(MEMORY_OPTIMIZED=ON,DURABILITY=SCHEMA_ONLY);');
    EXEC(N'USE [ExampleInMemorySourceÄ]; CREATE TABLE [dbo].[ExampleXtpTableÜ]
           ([ExampleId] int NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT=16))
           WITH(MEMORY_OPTIMIZED=ON,DURABILITY=SCHEMA_ONLY);');
    EXEC(N'USE [ExampleInMemorySourceÄ]; CREATE TYPE [dbo].[ExampleXtpType] AS TABLE
           ([ExampleId] int NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH(BUCKET_COUNT=8))
           WITH(MEMORY_OPTIMIZED=ON);');
    EXEC(N'USE [ExampleInMemorySourceÄ]; INSERT [dbo].[ExampleXtpTableÄ] VALUES(1),(2),(3),(4);
           INSERT [dbo].[ExampleXtpTableÜ] VALUES(1),(2),(3),(4);');
    CREATE TABLE [#InMemoryCollationRuntimeContract_NativeIndexes]
    ([TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,
     [ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [BucketCount] bigint NOT NULL);
    INSERT [#InMemoryCollationRuntimeContract_NativeIndexes]
    SELECT [t].[name],[t].[object_id],[h].[index_id],[h].[name],[h].[bucket_count]
    FROM [ExampleInMemorySourceÄ].[sys].[tables] [t]
    JOIN [ExampleInMemorySourceÄ].[sys].[hash_indexes] [h] ON [h].[object_id]=[t].[object_id]
    WHERE [t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleXtpTableÄ',N'ExampleXtpTableÜ');
    IF (SELECT COUNT_BIG(*) FROM [#InMemoryCollationRuntimeContract_NativeIndexes])<>2
        THROW 56076,N'In-memory native fixture catalogue identity failed.',1;
    CREATE TABLE [#InMemoryCollationRuntimeContract_SourceCodes]
    ([SourceCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY);
    INSERT [#InMemoryCollationRuntimeContract_SourceCodes] VALUES
      ('XTP_FEATURE_GATE'),('XTP_TABLE_MEMORY'),('XTP_MEMORY_CONSUMERS'),('XTP_HASH_INDEX_CATALOG'),
      ('XTP_HASH_INDEX_STATS'),('XTP_CHECKPOINT_FILES'),('XTP_TRANSACTIONS'),('RESOURCE_POOL_MEMORY');
    DECLARE @Case int=0,@Limit int,@OnlyProblems bit,@HashStats bit,@ObjectNames nvarchar(max),@Selection nvarchar(max);
    DECLARE @Json nvarchar(max),@TableJson nvarchar(max),@Count bigint,@Status varchar(40),@Partial bit;
    DECLARE @FirstInfo nvarchar(max),@FirstWarning nvarchar(max);
    WHILE @Case<8
    BEGIN
        SELECT @Json=NULL,@TableJson=NULL,@Count=NULL,@Status=NULL,@Partial=NULL;
        SET @Limit=CASE WHEN @Case IN(1,4) THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;
        SET @OnlyProblems=CASE WHEN @Case IN(2,4,5) THEN 1 ELSE 0 END;
        SET @HashStats=CASE WHEN @Case IN(3,4,5) THEN 1 ELSE 0 END;
        SET @ObjectNames=CASE WHEN @Case=6 THEN N'[ExampleXtpTableÄ]' ELSE NULL END;
        SET @Selection=CASE WHEN @Case=7 THEN N'[ExampleInMemorySourceÄ]|[ExampleInMemoryMissingÖ]'
                            ELSE N'[ExampleInMemorySourceÄ]' END;
        CREATE TABLE [#InMemoryCollationRuntimeContract_Collected]([Seed] bit NULL);
        EXEC [monitor].[USP_InMemoryOltpAnalysis]
              @DatabaseNames=@Selection,@ObjectNames=@ObjectNames,@MitHashIndexStats=@HashStats,
              @HighImpactConfirmed=1,@MinTableMemoryMb=0,@HashMaxChainWarn=1,
              @NurProblematisch=@OnlyProblems,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
              @ResultTablesJson=N'{"findings":"#InMemoryCollationRuntimeContract_Collected"}',
              @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
              @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF ISJSON(@Json)<>1 OR LEFT(COALESCE(JSON_QUERY(@Json,'$.findings'),N''),1)<>N'['
            THROW 56077,N'In-memory findings JSON envelope failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#InMemoryCollationRuntimeContract_Collected') AND [collation_name] IS NOT NULL)<>11
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#InMemoryCollationRuntimeContract_Collected')
                       AND [collation_name] IS NOT NULL AND [collation_name]<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56071,N'In-memory TABLE text collation failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sourceStatus'))<>8
           OR EXISTS(SELECT [SourceCode] FROM [#InMemoryCollationRuntimeContract_SourceCodes]
                     EXCEPT SELECT [SourceCode] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FROM OPENJSON(@Json,'$.sourceStatus') WITH([SourceCode] varchar(64)))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH
                     ([DatabaseName] nvarchar(128),[SourceCode] varchar(64),[StatusCode] varchar(40),[IsPartial] bit)
                     WHERE COALESCE([DatabaseName],N'')<>N'ExampleInMemorySourceÄ'
                        OR COALESCE(CONVERT(int,[IsPartial]),-1)<>0
                        OR COALESCE([StatusCode],'')<>CASE WHEN [SourceCode]='XTP_HASH_INDEX_STATS' AND @HashStats=0 THEN 'NOT_REQUESTED' ELSE 'AVAILABLE' END)
            THROW 56072,N'In-memory isolated native sources failed.',1;
        EXEC [sys].[sp_executesql]
             N'SELECT @pCount=COUNT_BIG(*) FROM [#InMemoryCollationRuntimeContract_Collected];
               SELECT @pJson=(SELECT * FROM [#InMemoryCollationRuntimeContract_Collected]
                              ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);',
             N'@pCount bigint OUTPUT,@pJson nvarchar(max) OUTPUT',@pCount=@Count OUTPUT,@pJson=@TableJson OUTPUT;
        DECLARE @ExpectedCount int=CASE WHEN @Case=2 THEN 0 WHEN @Case IN(1,4,6) THEN 1 WHEN @Case=3 THEN 4 ELSE 2 END;
        IF COALESCE(@Count,-1)<>@ExpectedCount
           OR COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,'$.findings'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.findings'))<>@ExpectedCount
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.findings') WITH([DatabaseName] nvarchar(128),[Severity] varchar(16))
                     WHERE COALESCE([DatabaseName],N'')<>N'ExampleInMemorySourceÄ'
                        OR (@OnlyProblems=1 AND COALESCE([Severity],'')<>'WARN'))
            THROW 56073,N'In-memory shared findings selection failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.findings') WITH
                  ([SchemaName] nvarchar(128),[ObjectName] nvarchar(128),[IndexName] nvarchar(128),[Severity] varchar(16),
                   [FindingCode] varchar(64),[MetricName] varchar(64),[MetricValue] decimal(19,4),[ThresholdValue] decimal(19,4)) [j]
                  LEFT JOIN [#InMemoryCollationRuntimeContract_NativeIndexes] [e]
                    ON [e].[TableName]=[j].[ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
                  WHERE [e].[ObjectId] IS NULL OR COALESCE([j].[SchemaName],N'')<>N'dbo'
                     OR COALESCE([j].[Severity],'') NOT IN('INFO','WARN')
                     OR (@Case=6 AND [j].[ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleXtpTableÄ')
                     OR ([j].[Severity]='INFO' AND (COALESCE([j].[FindingCode],'')<>'LARGE_MEMORY_CONSUMER_CONTEXT'
                          OR COALESCE([j].[MetricName],'')<>'TOTAL_USED_MB' OR [j].[IndexName] IS NOT NULL
                          OR COALESCE([j].[MetricValue],-1)<0 OR COALESCE([j].[ThresholdValue],-1)<>0))
                     OR ([j].[Severity]='WARN' AND (COALESCE([j].[FindingCode],'')<>'HASH_MAX_CHAIN_REVIEW'
                          OR COALESCE([j].[MetricName],'')<>'MAX_CHAIN_LENGTH' OR COALESCE([j].[MetricValue],-1)<1
                          OR COALESCE([j].[ThresholdValue],-1)<>1
                          OR COALESCE([j].[IndexName],N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[IndexName])))
            THROW 56080,N'In-memory independent finding identities failed.',1;
        IF @Limit=0 OR @Limit IS NULL
        BEGIN
            IF EXISTS(SELECT 1 FROM [#InMemoryCollationRuntimeContract_NativeIndexes] [e]
                      CROSS JOIN (VALUES('LARGE_MEMORY_CONSUMER_CONTEXT'),('HASH_MAX_CHAIN_REVIEW')) [c]([FindingCode])
                      WHERE (@Case<>6 OR [e].[TableName]=N'ExampleXtpTableÄ')
                        AND (([c].[FindingCode]='LARGE_MEMORY_CONSUMER_CONTEXT' AND @OnlyProblems=0)
                             OR ([c].[FindingCode]='HASH_MAX_CHAIN_REVIEW' AND @HashStats=1))
                        AND (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.findings') WITH
                             ([ObjectName] nvarchar(128),[FindingCode] varchar(64)) [j]
                             WHERE [j].[ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[TableName]
                               AND [j].[FindingCode] COLLATE SQL_Latin1_General_CP1_CS_AS=[c].[FindingCode])<>1)
                THROW 56080,N'In-memory exact finding pair multiplicity failed.',1;
        END;
        IF @Case=0 SET @FirstInfo=JSON_VALUE(@Json,'$.findings[0].ObjectName');
        IF @Case=3 SET @FirstWarning=JSON_VALUE(@Json,'$.findings[0].ObjectName');
        IF (@Case=1 AND COALESCE(JSON_VALUE(@Json,'$.findings[0].ObjectName'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@FirstInfo,N'') COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR (@Case=4 AND COALESCE(JSON_VALUE(@Json,'$.findings[0].ObjectName'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@FirstWarning,N'') COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56081,N'In-memory first limited finding identity failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseStatus') WITH([DatabaseName] nvarchar(128))
                  WHERE [DatabaseName] IS NULL OR [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS NOT IN(N'ExampleInMemorySourceÄ',N'ExampleInMemoryMissingÖ')
                     OR (@Case<>7 AND [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleInMemoryMissingÖ'))
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseStatus') WITH([DatabaseName] nvarchar(128))
               WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleInMemorySourceÄ')<>1
           OR (@Case=7 AND (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseStatus') WITH([DatabaseName] nvarchar(128))
                           WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleInMemoryMissingÖ')<>1)
            THROW 56074,N'In-memory exact database status identity failed.',1;
        IF COALESCE(@Status,'')<>CASE WHEN @Case=7 THEN 'AVAILABLE_LIMITED' WHEN @HashStats=1 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case=7 THEN 1 ELSE 0 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseStatus'))<>CASE WHEN @Case=7 THEN 2 ELSE 1 END
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseStatus') WITH
                     ([DatabaseName] nvarchar(128),[StatusCode] varchar(40),[IsPartial] bit,[SourceFailureCount] int,[FindingCount] bigint,
                      [MemoryOptimizedTableCount] bigint,[MemoryOptimizedTableTypeCount] bigint,[MemoryOptimizedFilegroupCount] bigint) [d]
                     WHERE ([d].[DatabaseName]=N'ExampleInMemorySourceÄ' AND
                           (COALESCE([d].[MemoryOptimizedTableCount],-1)<>2 OR COALESCE([d].[MemoryOptimizedTableTypeCount],-1)<>1
                            OR COALESCE([d].[MemoryOptimizedFilegroupCount],-1)<>1 OR COALESCE([d].[SourceFailureCount],-1)<>0
                            OR COALESCE([d].[FindingCount],-1)<>CASE WHEN @Case=6 THEN 1 WHEN @HashStats=1 THEN 4 ELSE 2 END
                            OR COALESCE(CONVERT(int,[d].[IsPartial]),-1)<>0
                            OR COALESCE([d].[StatusCode],'')<>CASE WHEN @HashStats=1 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END))
                        OR ([d].[DatabaseName]=N'ExampleInMemoryMissingÖ' AND
                           (COALESCE([d].[StatusCode],'')<>'DATABASE_UNAVAILABLE' OR COALESCE(CONVERT(int,[d].[IsPartial]),-1)<>1
                            OR COALESCE([d].[SourceFailureCount],-1)<>1 OR COALESCE([d].[FindingCount],-1)<>0)))
            THROW 56074,N'In-memory full counts or missing selection status failed.',1;
        IF @OnlyProblems=0 AND @Limit<>1
        BEGIN
            DECLARE @ExpectedHashRows int=CASE WHEN @Case=6 THEN 1 ELSE 2 END;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.hashIndexes'))<>@ExpectedHashRows
               OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.hashIndexes') WITH
                         ([DatabaseName] nvarchar(128),[SchemaName] nvarchar(128),[TableName] nvarchar(128),[IndexName] nvarchar(128),
                          [ObjectId] int,[IndexId] int,[ConfiguredBucketCount] bigint,[RuntimeStatsStatus] varchar(40),
                          [TotalBucketCount] bigint,[EmptyBucketCount] bigint,[EmptyBucketPercent] decimal(9,4),[AverageChainLength] decimal(19,4),[MaxChainLength] bigint) [j]
                         LEFT JOIN [#InMemoryCollationRuntimeContract_NativeIndexes] [e] ON [e].[TableName]=[j].[TableName] COLLATE SQL_Latin1_General_CP1_CS_AS
                         WHERE [e].[ObjectId] IS NULL OR COALESCE([j].[ObjectId],-1)<>[e].[ObjectId]
                            OR COALESCE([j].[IndexId],-1)<>[e].[IndexId] OR COALESCE([j].[ConfiguredBucketCount],-1)<>[e].[BucketCount]
                            OR COALESCE([j].[IndexName],N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[IndexName]
                            OR COALESCE([j].[SchemaName],N'')<>N'dbo' OR COALESCE([j].[DatabaseName],N'')<>N'ExampleInMemorySourceÄ'
                            OR COALESCE([j].[RuntimeStatsStatus],'')<>CASE WHEN @HashStats=1 THEN 'AVAILABLE' ELSE 'NOT_REQUESTED' END
                            OR (@HashStats=1 AND (COALESCE([j].[TotalBucketCount],-1)<>[e].[BucketCount]
                                OR COALESCE([j].[MaxChainLength],-1)<1 OR [j].[EmptyBucketPercent] IS NULL
                                OR [j].[EmptyBucketCount] IS NULL OR [j].[EmptyBucketCount]<0 OR [j].[EmptyBucketCount]>[j].[TotalBucketCount]
                                OR [j].[AverageChainLength] IS NULL OR [j].[AverageChainLength]<0
                                OR [j].[EmptyBucketPercent]<>CONVERT(decimal(9,4),100.0*[j].[EmptyBucketCount]/NULLIF([j].[TotalBucketCount],0)))))
                THROW 56078,N'In-memory native hash identity and arithmetic failed.',1;
        END;
        DROP TABLE [#InMemoryCollationRuntimeContract_Collected];
        SET @Case+=1;
    END;
    IF COALESCE(DB_ID(N'ExampleInMemorySourceÄ'),-1)<>COALESCE(@OwnedDatabaseId,-2)
        THROW 56079,N'In-memory owned database identity changed.',1;
    DROP DATABASE [ExampleInMemorySourceÄ];
    SET @OwnedDatabaseId=NULL;
    DECLARE @SuccessRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @SuccessRestoreSql;
END TRY
BEGIN CATCH
    DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSql;
    IF @OwnedDatabaseId IS NOT NULL AND DB_ID(N'ExampleInMemorySourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleInMemorySourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleInMemorySourceÄ];
    END;
    THROW;
END CATCH;
PRINT N'INMEMORY_COLLATION_RUNTIME_CONTRACT PASS';
GO
