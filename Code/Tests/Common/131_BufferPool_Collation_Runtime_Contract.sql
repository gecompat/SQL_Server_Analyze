USE [DeineDatenbank];
GO

SET NOCOUNT ON;
DECLARE @Collect bit=0, @Json nvarchar(max), @Status varchar(40), @Partial bit;
DECLARE @Limit int;
WHILE 1=1
BEGIN
    SET @Limit=CASE WHEN @Collect=0 THEN 1 ELSE 10 END;
    CREATE TABLE [#ExampleBufferMemoryExport]([Dummy] int NULL);
    SELECT @Json=NULL, @Status=NULL, @Partial=NULL;
    EXEC [monitor].[USP_BufferPoolAnalysis]
        @MitMemoryClerks=1, @MitBufferPoolVerteilung=@Collect, @MaxZeilen=@Limit,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"memory":"#ExampleBufferMemoryExport"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    IF COALESCE(ISJSON(@Json),0)<>1
       OR COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_WITH_FINDING')
       OR COALESCE(@Partial,1)<>0
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.memory'))<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.resourceSemaphores')) NOT BETWEEN 1 AND @Limit
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.memoryClerks')) NOT BETWEEN 1 AND @Limit
       OR (SELECT COUNT_BIG(*) FROM [#ExampleBufferMemoryExport])<>1
        THROW 55800,N'Der positive BufferPool-JSON- oder TABLE-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBufferMemoryExport') AND [collation_name] IS NOT NULL)<>4
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns]
                  WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBufferMemoryExport') AND [collation_name] IS NOT NULL
                    AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55801,N'Der Speicherexport übernimmt eine fremde tempdb-Collation.',1;
    IF NOT EXISTS (SELECT 1 FROM [#ExampleBufferMemoryExport]
                   WHERE [PhysicalMemoryInUseKb]>0 AND [TotalPhysicalMemoryKb]>0
                     AND [AvailablePhysicalMemoryKb] BETWEEN 0 AND [TotalPhysicalMemoryKb]
                     AND [AvailablePhysicalMemoryPercent]=CONVERT(decimal(9,2),
                         100.0*[AvailablePhysicalMemoryKb]/NULLIF([TotalPhysicalMemoryKb],0)))
       OR TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.memory[0].PhysicalMemoryInUseKb')) IS NULL
       OR TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.memory[0].PhysicalMemoryInUseKb'))
           <>(SELECT [PhysicalMemoryInUseKb] FROM [#ExampleBufferMemoryExport])
        THROW 55802,N'Die Speichermessung oder TABLE-/JSON-Parität ist verletzt.',1;
    IF @Collect=0 AND (COALESCE(JSON_VALUE(@Json,N'$.meta.bufferPoolDistributionCollected'),N'')<>N'false'
                       OR COALESCE(JSON_QUERY(@Json,N'$.bufferPool'),N'')<>N'[]')
        THROW 55803,N'Der Standardpfad hat die optionale BufferPool-Verteilung aktiviert.',1;
    IF @Collect=1 AND (COALESCE(JSON_VALUE(@Json,N'$.meta.bufferPoolDistributionCollected'),N'')<>N'true'
                       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.bufferPool')) NOT BETWEEN 1 AND @Limit
                       OR NOT EXISTS
                       (SELECT 1 FROM OPENJSON(@Json,N'$.bufferPool') WITH
                        ([DatabaseId] int N'$.DatabaseId', [DatabaseName] nvarchar(128) N'$.DatabaseName',
                         [CachedPages] bigint N'$.CachedPages', [CachedSizeMb] decimal(19,2) N'$.CachedSizeMb') AS [b]
                        JOIN [master].[sys].[databases] AS [d] ON [d].[database_id]=[b].[DatabaseId]
                        WHERE [b].[DatabaseName]=[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                          AND [b].[CachedPages]>0 AND [b].[CachedSizeMb]=CONVERT(decimal(19,2),[b].[CachedPages]*8.0/1024.0)))
        THROW 55804,N'Die aktivierte BufferPool-Verteilung oder native Datenbankidentität ist verletzt.',1;
    DROP TABLE [#ExampleBufferMemoryExport];
    IF @Collect=1 BREAK;
    SET @Collect=1;
END;
GO