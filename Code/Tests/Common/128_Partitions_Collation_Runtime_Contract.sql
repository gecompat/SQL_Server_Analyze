USE [DeineDatenbank];
GO

SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.ExamplePartitionsÄ') IS NOT NULL
   OR EXISTS (SELECT 1 FROM [sys].[partition_functions] WHERE [name]=N'ExamplePartitionsFunction')
   OR EXISTS (SELECT 1 FROM [sys].[partition_schemes] WHERE [name]=N'ExamplePartitionsScheme')
    THROW 55770,N'Die eigenen Partitionsfixture-Namen sind bereits belegt.',1;
DECLARE @TableCreated bit=0, @FunctionCreated bit=0, @SchemeCreated bit=0;
DECLARE @Json nvarchar(max), @Db sysname=DB_NAME();
BEGIN TRY
    CREATE PARTITION FUNCTION [ExamplePartitionsFunction](int) AS RANGE RIGHT FOR VALUES(10,20);
    SET @FunctionCreated=1;
    CREATE PARTITION SCHEME [ExamplePartitionsScheme] AS PARTITION [ExamplePartitionsFunction] ALL TO ([PRIMARY]);
    SET @SchemeCreated=1;
    CREATE TABLE [dbo].[ExamplePartitionsÄ]([Id] int NOT NULL PRIMARY KEY) ON [ExamplePartitionsScheme]([Id]);
    SET @TableCreated=1;
    INSERT [dbo].[ExamplePartitionsÄ]([Id]) VALUES(5),(15),(25);
    ALTER INDEX ALL ON [dbo].[ExamplePartitionsÄ] REBUILD PARTITION=2 WITH(DATA_COMPRESSION=PAGE);
    CREATE TABLE [#ExamplePartitionsExport]([Dummy] int NULL);
    EXEC [monitor].[USP_Partitions]
        @DatabaseNames=@Db, @SchemaNames=N'dbo', @ObjectNames=N'ExamplePartitionsÄ',
        @NurPartitionierte=1, @NurGemischteKompression=1, @MaxZeilen=3,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"partitions":"#ExamplePartitionsExport"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0) <> 1
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') <> N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'') <> N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.partitions')) <> 3
       OR (SELECT COUNT_BIG(*) FROM [#ExamplePartitionsExport]) <> 3
       OR EXISTS (SELECT 1 FROM [#ExamplePartitionsExport]
                  WHERE [DatabaseName]<>@Db OR [ObjectName]<>N'ExamplePartitionsÄ'
                    OR [PartitionCount]<>3 OR [HasMixedCompression]<>1 OR COALESCE([BoundaryOnRight],0)<>1)
        THROW 55771,N'Der gezielte Partitions-JSON- und TABLE-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePartitionsExport') AND [collation_name] IS NOT NULL) <> 13
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns]
                  WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePartitionsExport') AND [collation_name] IS NOT NULL
                    AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS <> N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55772,N'Der Partitionsexport übernimmt eine fremde tempdb-Collation.',1;
    IF (SELECT COUNT_BIG(*) FROM [#ExamplePartitionsExport] AS [e]
        JOIN [sys].[partitions] AS [p] ON [p].[partition_id]=[e].[PartitionId]
        WHERE [p].[object_id]=OBJECT_ID(N'dbo.ExamplePartitionsÄ') AND [e].[RowCount]=[p].[rows]
          AND [e].[DataCompressionDesc]=[p].[data_compression_desc] COLLATE SQL_Latin1_General_CP1_CS_AS) <> 3
       OR NOT EXISTS (SELECT 1 FROM [#ExamplePartitionsExport] WHERE [PartitionNumber]=1
                      AND [LowerBoundaryValue] IS NULL AND [UpperBoundaryValue]=N'10' AND [UpperBoundaryInclusive]=0)
       OR NOT EXISTS (SELECT 1 FROM [#ExamplePartitionsExport] WHERE [PartitionNumber]=2
                      AND [LowerBoundaryValue]=N'10' AND [LowerBoundaryInclusive]=1
                        AND [UpperBoundaryValue]=N'20' AND [UpperBoundaryInclusive]=0)
       OR NOT EXISTS (SELECT 1 FROM [#ExamplePartitionsExport] WHERE [PartitionNumber]=3
                      AND [LowerBoundaryValue]=N'20' AND [LowerBoundaryInclusive]=1 AND [UpperBoundaryValue] IS NULL)
        THROW 55773,N'Die Partitionsgrenzen oder Kompressions- und Zeilenzähler weichen von der Fixture ab.',1;
    SET @Json=NULL;
    EXEC [monitor].[USP_Partitions]
        @DatabaseNames=@Db, @SchemaNames=N'dbo', @ObjectNames=N'ExamplePartitionsÄ', @MaxZeilen=2,
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0) <> 1
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') <> N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'') <> N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.partitions')) <> 2
        THROW 55774,N'Die Partitionsausgabe hält die Zeilenbegrenzung nicht ein.',1;
    SET @Json=NULL;
    EXEC [monitor].[USP_Partitions]
        @DatabaseNames=@Db, @SchemaNames=N'dbo', @ObjectNames=N'examplePartitionsÄ',
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0) <> 1
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') <> N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'') <> N'false'
       OR COALESCE(JSON_QUERY(@Json,N'$.partitions'),N'') <> N'[]'
        THROW 55775,N'Der exakte Partitionsobjektfilter ignoriert Groß- und Kleinschreibung.',1;
    DROP TABLE [dbo].[ExamplePartitionsÄ]; SET @TableCreated=0;
    DROP PARTITION SCHEME [ExamplePartitionsScheme]; SET @SchemeCreated=0;
    DROP PARTITION FUNCTION [ExamplePartitionsFunction]; SET @FunctionCreated=0;
END TRY
BEGIN CATCH
    IF @TableCreated=1 DROP TABLE [dbo].[ExamplePartitionsÄ];
    IF @SchemeCreated=1 DROP PARTITION SCHEME [ExamplePartitionsScheme];
    IF @FunctionCreated=1 DROP PARTITION FUNCTION [ExamplePartitionsFunction];
    THROW;
END CATCH;
GO
