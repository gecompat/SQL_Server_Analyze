USE [DeineDatenbank];
GO
/* Prüft einen eigenen leeren Full-Text-Katalogscope und dessen Exportvertrag.
Die Fixture erzeugt weder Full-Text-Objekte noch Inhalte. Nichtleere Findings,
positive Filter-/Limitwirkung und die gegateten DMV-Pfade bleiben unbelegt.
Der Runner führt diesen Vertrag mit Framework-Compatibility-Level 150, 160 und 170 aus. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleFullTextSourceÄ') IS NOT NULL THROW 56200,N'FullText fixture already exists.',1;
IF DB_ID(N'ExampleFullTextMissingÖ') IS NOT NULL THROW 56201,N'FullText missing selection fixture already exists.',1;
DECLARE @OwnedDatabaseId int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @SourceLevel int,@Sql nvarchar(max),@Case int=0,@Limit int,@Problems bit,
        @Names nvarchar(max),@Objects nvarchar(max),@Pattern nvarchar(4000),
        @Age bigint,@Timeout int,@Json nvarchar(max),@Status varchar(40),@Partial bit;
IF @FrameworkLevel NOT IN(150,160,170) THROW 56202,N'FullText framework compatibility level is outside the contract.',1;
BEGIN TRY
    CREATE DATABASE [ExampleFullTextSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedDatabaseId=DB_ID(N'ExampleFullTextSourceÄ');
    SET @Sql=N'ALTER DATABASE [ExampleFullTextSourceÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';';
    EXEC(@Sql);
    SELECT @SourceLevel=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedDatabaseId;
    IF @SourceLevel<>@FrameworkLevel
       OR CONVERT(sysname,DATABASEPROPERTYEX(N'ExampleFullTextSourceÄ',N'Collation')) COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS'
        THROW 56203,N'FullText source compatibility level or collation failed.',1;
    IF EXISTS(SELECT 1 FROM [ExampleFullTextSourceÄ].[sys].[fulltext_catalogs])
       OR EXISTS(SELECT 1 FROM [ExampleFullTextSourceÄ].[sys].[fulltext_indexes])
       OR EXISTS(SELECT 1 FROM [ExampleFullTextSourceÄ].[sys].[fulltext_index_columns])
        THROW 56204,N'FullText own native catalog scope is not empty.',1;
    CREATE TABLE [#ExampleFullTextSources]
      ([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
       [SourceCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL);
    INSERT [#ExampleFullTextSources] VALUES
      (N'ExampleFullTextSourceÄ','FULLTEXT_FEATURE_GATE','AVAILABLE',0,1),
      (N'ExampleFullTextSourceÄ','FULLTEXT_CATALOG_INDEX','NOT_APPLICABLE',0,0),
      (N'ExampleFullTextSourceÄ','FULLTEXT_FRAGMENTS','NOT_APPLICABLE',0,0),
      (N'ExampleFullTextSourceÄ','FULLTEXT_POPULATION','NOT_APPLICABLE',0,0),
      (N'ExampleFullTextSourceÄ','FULLTEXT_BATCHES','NOT_APPLICABLE',0,0),
      (N'ExampleFullTextSourceÄ','FULLTEXT_SEMANTIC_POPULATION','NOT_APPLICABLE',0,0),
      (NULL,'FULLTEXT_MEMORY_POOLS','NOT_APPLICABLE',0,0),
      (NULL,'FULLTEXT_FDHOSTS','NOT_APPLICABLE',0,0);
    WHILE @Case<10
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN NULL WHEN @Case=2 THEN 1 WHEN @Case=6 THEN -1 ELSE 0 END,
               @Problems=CASE WHEN @Case=3 THEN 1 ELSE 0 END,
               @Names=CASE WHEN @Case=5 THEN N'[ExampleFullTextSourceÄ]|[ExampleFullTextMissingÖ]' ELSE N'[ExampleFullTextSourceÄ]' END,
               @Objects=CASE WHEN @Case IN(4,9) THEN N'[ExampleFullTextObjectÜ]' ELSE NULL END,
               @Pattern=CASE WHEN @Case=9 THEN N'like:ExampleFullText%' ELSE NULL END,
               @Age=CASE WHEN @Case=7 THEN -1 ELSE 60 END,
               @Timeout=CASE WHEN @Case=8 THEN -1 ELSE 0 END,
               @Json=NULL,@Status=NULL,@Partial=NULL;
        CREATE TABLE [#ExampleFullTextExport]([Dummy] int NULL);
        EXEC [monitor].[USP_FullTextAnalysis]
             @DatabaseNames=@Names,@ObjectNames=@Objects,@ObjectNamePattern=@Pattern,
             @NurProblematisch=@Problems,@PopulationAgeWarnMinutes=@Age,@LockTimeoutMs=@Timeout,
             @MaxZeilen=@Limit,@HighImpactConfirmed=1,@ResultSetArt='TABLE',
             @ResultTablesJson=N'{"findings":"#ExampleFullTextExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(@Status,'')<>CASE WHEN @Case>=6 THEN 'INVALID_PARAMETER' WHEN @Case=5 THEN 'AVAILABLE_LIMITED' ELSE 'NOT_APPLICABLE' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case>=5 THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Case>=5 THEN N'true' ELSE N'false' END
            THROW 56210,N'FullText module status or partiality failed.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleFullTextExport])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>0
            THROW 56211,N'FullText empty findings export failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFullTextExport'))<>13
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFullTextExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFullTextExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS
             (SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [tempdb].[sys].[columns]
              WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFullTextExport')
              EXCEPT SELECT [ColumnName] FROM (VALUES
                (N'FindingOrdinal'),(N'DatabaseName'),(N'SchemaName'),(N'ObjectName'),(N'Severity'),(N'Confidence'),
                (N'FindingCode'),(N'MetricName'),(N'MetricValue'),(N'ThresholdValue'),(N'Evidence'),(N'EvidenceLimit'),(N'RecommendedNextCheck')) [v]([ColumnName]))
            THROW 56212,N'FullText export schema or text collation failed.',1;
        IF EXISTS(SELECT 1 FROM (VALUES(N'catalogs'),(N'fullTextIndexes'),(N'populations'),
                   (N'outstandingBatches'),(N'semanticPopulations'),(N'memoryPools'),(N'fdHosts')) [a]([ArrayName])
                  CROSS APPLY OPENJSON(@Json,N'$.'+[a].[ArrayName]))
            THROW 56213,N'FullText own empty detail arrays failed.',1;
        IF @Case<6
        BEGIN
            /* Nullable Datenbanknamen verwenden für den EXCEPT-Nullvergleich den Basistyp nvarchar(128). */
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>8
               OR EXISTS
                 (SELECT * FROM [#ExampleFullTextSources] EXCEPT SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                   ([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
                    [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount'))
               OR EXISTS
                 (SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                   ([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
                    [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount')
                  EXCEPT SELECT * FROM [#ExampleFullTextSources])
                THROW 56214,N'FullText negative feature gate or independent source set failed.',1;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>CASE WHEN @Case=5 THEN 2 ELSE 1 END
               OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
                 ([DatabaseName] sysname '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',
                  [IsFullTextInstalled] bit '$.IsFullTextInstalled',[CatalogCount] bigint '$.CatalogCount',
                  [FullTextIndexCount] bigint '$.FullTextIndexCount',[ActivePopulationCount] bigint '$.ActivePopulationCount',
                  [OutstandingBatchCount] bigint '$.OutstandingBatchCount',[FindingCount] bigint '$.FindingCount',[SourceFailureCount] int '$.SourceFailureCount')
                 WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleFullTextSourceÄ'
                   AND [StatusCode]='NOT_APPLICABLE_VISIBLE_SCOPE' AND [IsPartial]=0
                   AND [IsFullTextInstalled]=COALESCE(TRY_CONVERT(bit,SERVERPROPERTY(N'IsFullTextInstalled')),0)
                   AND [CatalogCount]=0 AND [FullTextIndexCount]=0 AND [ActivePopulationCount]=0
                   AND [OutstandingBatchCount]=0 AND [FindingCount]=0 AND [SourceFailureCount]=0)
                THROW 56215,N'FullText database status differs from own native empty scope.',1;
            IF @Case=5 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
                 ([DatabaseName] sysname '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',
                  [SourceFailureCount] int '$.SourceFailureCount',[FindingCount] bigint '$.FindingCount',[ErrorMessage] nvarchar(2048) '$.ErrorMessage')
                 WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleFullTextMissingÖ'
                   AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1 AND [SourceFailureCount]=1
                   AND [FindingCount]=0 AND NULLIF([ErrorMessage],N'') IS NOT NULL)
                THROW 56216,N'FullText missing selection warning was overwritten.',1;
        END
        ELSE IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>0
                OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceCode] varchar(64) '$.SourceCode')
                          WHERE [SourceCode] NOT IN('FULLTEXT_MEMORY_POOLS','FULLTEXT_FDHOSTS'))
            THROW 56217,N'FullText invalid parameter reached database sources.',1;
        DROP TABLE [#ExampleFullTextExport];
        SET @Case+=1;
    END;
    /* Führt RAW und CONSOLE auf derselben leeren Quelle aus; keine positive Zeilenparität. */
    EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleFullTextSourceÄ]',@MaxZeilen=NULL,
         @HighImpactConfirmed=1,@ResultSetArt='RAW',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Status,'')<>'NOT_APPLICABLE' THROW 56218,N'FullText empty RAW status failed.',1;
    EXEC [monitor].[USP_FullTextAnalysis] @DatabaseNames=N'[ExampleFullTextSourceÄ]',@MaxZeilen=1,@NurProblematisch=1,
         @HighImpactConfirmed=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Status,'')<>'NOT_APPLICABLE' THROW 56219,N'FullText empty CONSOLE status failed.',1;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleFullTextSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleFullTextSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleFullTextSourceÄ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@SourceLevel AS [SourceCompatibilityLevel],
           @Case AS [EmptyAndNegativeCases],
           N'Leerer Feature-Scope, Exportcollation und Parameter wurden geprüft; nichtleere Findings und positive Full-Text-Quellen bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedDatabaseId IS NOT NULL AND DB_ID(N'ExampleFullTextSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleFullTextSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleFullTextSourceÄ];
    END;
    THROW;
END CATCH;
GO
