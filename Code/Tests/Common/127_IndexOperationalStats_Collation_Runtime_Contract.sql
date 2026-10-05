USE [DeineDatenbank];
GO

SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.ExampleOperationalÄ') IS NOT NULL
    THROW 55760,N'Der eigene Operational-Stats-Fixturename ist bereits belegt.',1;
DECLARE @Created bit=0, @Json nvarchar(max), @Db sysname=DB_NAME();
BEGIN TRY
    CREATE TABLE [dbo].[ExampleOperationalÄ]([Id] int NOT NULL PRIMARY KEY);
    SET @Created=1;
    INSERT [dbo].[ExampleOperationalÄ]([Id]) VALUES(1);
    CREATE TABLE [#ExampleOperationalExport]([Dummy] int NULL);
    EXEC [monitor].[USP_IndexOperationalStats]
        @DatabaseNames=@Db, @SchemaNames=N'dbo', @ObjectNames=N'ExampleOperationalÄ',
        @ResultSetArt='TABLE',
        @ResultTablesJson=N'{"indexOperationalStats":"#ExampleOperationalExport"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0) <> 1
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') <> N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'') <> N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.indexOperationalStats')) <> 1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleOperationalExport]) <> 1
       OR NOT EXISTS (SELECT 1 FROM [#ExampleOperationalExport]
                      WHERE [DatabaseName]=@Db AND [SchemaName]=N'dbo'
                        AND [ObjectName]=N'ExampleOperationalÄ' AND [IndexId]=1
                        AND [PartitionNumber]=1 AND [LeafInsertCount]>=1)
        THROW 55761,N'Der gezielte Operational-Stats-JSON- und TABLE-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleOperationalExport')
          AND [collation_name] IS NOT NULL) <> 6
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns]
                  WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleOperationalExport')
                    AND [collation_name] IS NOT NULL
                    AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS <> N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55762,N'Der Operational-Stats-Export übernimmt eine fremde tempdb-Collation.',1;

    IF NOT EXISTS
       (SELECT 1 FROM [#ExampleOperationalExport] AS [e]
        CROSS APPLY (SELECT SUM([leaf_insert_count]) AS [LeafInsertCount],
                            SUM([leaf_allocation_count]) AS [LeafPageAllocationCount],
                            SUM([nonleaf_allocation_count]) AS [NonleafPageAllocationCount],
                            SUM([page_latch_wait_count]) AS [PageLatchWaitCount],
                            SUM([page_latch_wait_in_ms]) AS [PageLatchWaitMs],
                            SUM([tree_page_latch_wait_count]) AS [TreePageLatchWaitCount],
                            SUM([tree_page_latch_wait_in_ms]) AS [TreePageLatchWaitMs]
                     FROM [sys].[dm_db_index_operational_stats](DB_ID(),OBJECT_ID(N'dbo.ExampleOperationalÄ'),1,NULL)) AS [n]
        WHERE [e].[LeafInsertCount]=[n].[LeafInsertCount]
          AND [e].[LeafPageAllocationCount]=[n].[LeafPageAllocationCount]
          AND [e].[NonleafPageAllocationCount]=[n].[NonleafPageAllocationCount]
          AND [e].[PageLatchWaitCount]=[n].[PageLatchWaitCount] AND [e].[PageLatchWaitMs]=[n].[PageLatchWaitMs]
          AND [e].[TreePageLatchWaitCount]=[n].[TreePageLatchWaitCount] AND [e].[TreePageLatchWaitMs]=[n].[TreePageLatchWaitMs])
        THROW 55763,N'Die Operational-Stats-Zähler weichen von der nativen Fixturequelle ab.',1;
    SET @Json=NULL;
    EXEC [monitor].[USP_IndexOperationalStats]
        @DatabaseNames=@Db, @SchemaNames=N'dbo', @ObjectNames=N'exampleOperationalÄ',
        @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0) <> 1
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'') <> N'UNAVAILABLE_OBJECT'
       OR EXISTS (SELECT 1 FROM OPENJSON(@Json,N'$.indexOperationalStats'))
        THROW 55764,N'Der exakte Operational-Stats-Objektfilter ignoriert Groß- und Kleinschreibung.',1;
    DROP TABLE [dbo].[ExampleOperationalÄ]; SET @Created=0;
END TRY
BEGIN CATCH
    IF @Created=1 DROP TABLE [dbo].[ExampleOperationalÄ];
    THROW;
END CATCH;
GO
