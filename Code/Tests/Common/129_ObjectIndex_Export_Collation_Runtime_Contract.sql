USE [DeineDatenbank];
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
IF DB_ID(N'ExampleObjectIndexSource') IS NOT NULL
    THROW 55780,N'Der eigene Fixture-Datenbankname ist bereits belegt.',1;
DECLARE @DatabaseCreated bit=0, @Json nvarchar(max), @FailureMessage nvarchar(2048), @ProductMajorVersion int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
BEGIN TRY
    EXEC(N'CREATE DATABASE [ExampleObjectIndexSource] COLLATE Latin1_General_100_CI_AS;');
    SET @DatabaseCreated=1;
    EXEC [ExampleObjectIndexSource].[sys].[sp_executesql] N'
        CREATE TABLE [dbo].[ExampleObjectIndexÄ]([Id] int NOT NULL PRIMARY KEY, [Code] int NOT NULL);
        INSERT [dbo].[ExampleObjectIndexÄ] VALUES(1,10),(2,10),(3,20);
        CREATE STATISTICS [ExampleCodeStatistics] ON [dbo].[ExampleObjectIndexÄ]([Code]) WITH FULLSCAN;
        CREATE TABLE [dbo].[ExampleColumnstoreÄ]([Id] int NOT NULL,[OrderValue] int NOT NULL);
        CREATE CLUSTERED COLUMNSTORE INDEX [ExampleColumnstoreIndex] ON [dbo].[ExampleColumnstoreÄ];
        INSERT [dbo].[ExampleColumnstoreÄ] VALUES(1,10),(2,20),(3,30);';
    IF @ProductMajorVersion>=16
        EXEC [ExampleObjectIndexSource].[sys].[sp_executesql] N'
            DROP INDEX [ExampleColumnstoreIndex] ON [dbo].[ExampleColumnstoreÄ];
            CREATE CLUSTERED COLUMNSTORE INDEX [ExampleColumnstoreIndex] ON [dbo].[ExampleColumnstoreÄ] ORDER([OrderValue]);';
    CREATE TABLE [#ExampleObjectIndexExport1]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_MissingIndexes] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ',
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"missingIndexes":"#ExampleObjectIndexExport1"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_MissingIndexes: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport1') AND [collation_name] IS NOT NULL)<>10
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport1') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_MissingIndexes.missingIndexes: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport2]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_Statistics] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ',
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"statistics":"#ExampleObjectIndexExport2"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_Statistics: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexExport2] WHERE [DatabaseName]=N'ExampleObjectIndexSource' AND [SchemaName]=N'dbo' AND [ObjectName]=N'ExampleObjectIndexÄ')
        THROW 55783,N'Die kontrollierte Fixture liefert keine erwarteten Datenzeilen.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport2') AND [collation_name] IS NOT NULL)<>12
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport2') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_Statistics.statistics: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport3]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_StatisticsDistributionAnalysis] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ', @MinVerteilungsZeilen=1, @MaxVerteilungsStatistiken=1,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExampleObjectIndexExport3"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_StatisticsDistributionAnalysis: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport3') AND [collation_name] IS NOT NULL)<>11
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport3') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_StatisticsDistributionAnalysis.findings: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport4]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexOrdering]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_Columnstore] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleColumnstoreÄ',
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"rowgroups":"#ExampleObjectIndexExport4","ordering":"#ExampleObjectIndexOrdering"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_Columnstore: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexExport4] WHERE [DatabaseName]=N'ExampleObjectIndexSource' AND [SchemaName]=N'dbo' AND [ObjectName]=N'ExampleColumnstoreÄ')
        THROW 55783,N'Die kontrollierte Fixture liefert keine erwarteten Datenzeilen.',1;
    IF @ProductMajorVersion<16
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexOrdering] WHERE [SourceStatus]='UNAVAILABLE_VERSION')
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.ordering') WITH ([SourceStatus] varchar(40) N'$.SourceStatus') WHERE [SourceStatus]='UNAVAILABLE_VERSION')
            THROW 55785,N'USP_Columnstore.ordering: Der SQL-Server-2019-Fallback ist verletzt.',1;
    END
    ELSE
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexOrdering] WHERE [ColumnName]=N'OrderValue' AND [ColumnStoreOrderOrdinal]=1 AND [SourceStatus]='AVAILABLE')
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.ordering') WITH ([ColumnName] sysname N'$.ColumnName',[ColumnStoreOrderOrdinal] tinyint N'$.ColumnStoreOrderOrdinal',[SourceStatus] varchar(40) N'$.SourceStatus') WHERE [ColumnName]=N'OrderValue' AND [ColumnStoreOrderOrdinal]=1 AND [SourceStatus]='AVAILABLE')
            THROW 55785,N'USP_Columnstore.ordering: Der TABLE-/JSON-Vertrag ist verletzt.',1;
        IF @ProductMajorVersion>=17
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexOrdering] WHERE [ColumnName]=N'OrderValue' AND [DataClusteringOrdinal] IS NOT NULL)
               OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.ordering') WITH ([ColumnName] sysname N'$.ColumnName',[DataClusteringOrdinal] tinyint N'$.DataClusteringOrdinal') WHERE [ColumnName]=N'OrderValue' AND [DataClusteringOrdinal] IS NOT NULL)
                THROW 55786,N'USP_Columnstore.ordering: Der SQL-Server-2025-Data-Clustering-Vertrag ist verletzt.',1;
        END;
    END;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport4') AND [collation_name] IS NOT NULL)<>9
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport4') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_Columnstore.rowgroups: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexOrdering') AND [collation_name] IS NOT NULL)<>8
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexOrdering') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_Columnstore.ordering: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport5]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ', @MinPageCount=0,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"indexPhysicalStats":"#ExampleObjectIndexExport5"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_IndexPhysicalStats: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF NOT EXISTS(SELECT 1 FROM [#ExampleObjectIndexExport5] WHERE [DatabaseName]=N'ExampleObjectIndexSource' AND [SchemaName]=N'dbo' AND [ObjectName]=N'ExampleObjectIndexÄ')
        THROW 55783,N'Die kontrollierte Fixture liefert keine erwarteten Datenzeilen.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport5') AND [collation_name] IS NOT NULL)<>8
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport5') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_IndexPhysicalStats.indexPhysicalStats: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport6]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexExport7]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexExport8]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexExport9]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexExport10]([Dummy] int NULL);
    CREATE TABLE [#ExampleObjectIndexExport11]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_VectorIndexAnalysis] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ',
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ExampleObjectIndexExport6","vectorIndexes":"#ExampleObjectIndexExport7","maintenance":"#ExampleObjectIndexExport8","findings":"#ExampleObjectIndexExport9","sourceStatus":"#ExampleObjectIndexExport10","warnings":"#ExampleObjectIndexExport11"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_VectorIndexAnalysis: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport6') AND [collation_name] IS NOT NULL)<>3
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport6') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.moduleStatus: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport7') AND [collation_name] IS NOT NULL)<>8
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport7') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.vectorIndexes: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport8') AND [collation_name] IS NOT NULL)<>7
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport8') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.maintenance: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport9') AND [collation_name] IS NOT NULL)<>11
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport9') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.findings: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport10') AND [collation_name] IS NOT NULL)<>7
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport10') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.sourceStatus: Der TABLE-Export übernimmt eine fremde Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport11') AND [collation_name] IS NOT NULL)<>4
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport11') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_VectorIndexAnalysis.warnings: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport12]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_ObjectAnalysis] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10, @SchemaNames=N'dbo', @ObjectNames=N'ExampleObjectIndexÄ',
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ExampleObjectIndexExport12"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
    BEGIN
        SET @FailureMessage=CONCAT(N'USP_ObjectAnalysis: ',JSON_VALUE(@Json,N'$.meta.statusCode'),N'; Inventar: ',
            JSON_VALUE(@Json,N'$.objectInventory.meta.statusCode'),N'; ',JSON_VALUE(@Json,N'$.objectInventory.databaseStatus[0].ErrorNumber'),N'; ',
            JSON_VALUE(@Json,N'$.objectInventory.databaseStatus[0].ErrorMessage'));
        THROW 55781,@FailureMessage,1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleObjectIndexExport12])<>3
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.moduleStatus'))<>3
       OR COALESCE(JSON_VALUE(@Json,N'$.objectInventory.meta.statusCode'),N'')<>N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.objectInventory.meta.isPartial'),N'')<>N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectInventory.objects'))<>1
        THROW 55784,N'Der Orchestrator liefert nicht die drei erwarteten Module und das eigene Inventarobjekt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport12') AND [collation_name] IS NOT NULL)<>3
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport12') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_ObjectAnalysis.moduleStatus: Der TABLE-Export übernimmt eine fremde Collation.',1;
    CREATE TABLE [#ExampleObjectIndexExport13]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_SchemaDesignAnalysis] @DatabaseNames=N'ExampleObjectIndexSource', @HighImpactConfirmed=1, @MaxZeilen=10,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ExampleObjectIndexExport13"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false' OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_WITH_FINDING',N'NOT_APPLICABLE')
        THROW 55781,N'USP_SchemaDesignAnalysis: Der gezielte JSON-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport13') AND [collation_name] IS NOT NULL)<>9
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleObjectIndexExport13') AND [collation_name] IS NOT NULL
                  AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55782,N'USP_SchemaDesignAnalysis.findings: Der TABLE-Export übernimmt eine fremde Collation.',1;
    EXEC(N'DROP DATABASE [ExampleObjectIndexSource];'); SET @DatabaseCreated=0;
END TRY
BEGIN CATCH
    IF @DatabaseCreated=1
        EXEC(N'ALTER DATABASE [ExampleObjectIndexSource] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [ExampleObjectIndexSource];');
    THROW;
END CATCH;
GO
