USE [DeineDatenbank];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Database sysname=DB_NAME(),@Names nvarchar(max)=QUOTENAME(DB_NAME())+N'|[master]',
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@Case tinyint=0,@Limit int,@Details bit,@Expected int,@FirstDatabaseId int;
SELECT TOP(1) @FirstDatabaseId=[database_id] FROM [master].[sys].[databases]
WHERE [database_id] IN(DB_ID(),DB_ID(N'master'))
ORDER BY [name] COLLATE SQL_Latin1_General_CP1_CS_AS,[database_id];
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[suspect_pages] WHERE [database_id]=DB_ID() AND [file_id]=1 AND [page_id]=1)
    THROW 55869,N'Der eigene synthetische Suspect-Page-Schlüssel ist bereits belegt.',1;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT [msdb].[dbo].[suspect_pages]([database_id],[file_id],[page_id],[event_type],[error_count],[last_update_date])
    VALUES(DB_ID(),1,1,1,1,GETDATE());
    WHILE @Case<3
    BEGIN
        SELECT @Limit=CASE WHEN @Case=0 THEN 0 WHEN @Case=1 THEN 1 ELSE NULL END,
               @Details=CASE WHEN @Case=0 THEN 0 ELSE 1 END,@Expected=CASE WHEN @Case=1 THEN 1 ELSE 2 END;
        CREATE TABLE [#ExampleIntegrity]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=@Names,@SystemdatenbankenEinbeziehen=1,
            @MitPageDetails=@Details,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
            @ResultTablesJson=N'{"integrity":"#ExampleIntegrity"}',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleIntegrity') AND [collation_name] IS NOT NULL)<>5
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleIntegrity') AND [collation_name] IS NOT NULL
                       AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55861,N'Der DatabaseIntegrity-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL OR JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL
           OR (SELECT COUNT_BIG(*) FROM [#ExampleIntegrity])<>@Expected
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
           OR (@Case=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleIntegrity] WHERE [DatabaseId]=@FirstDatabaseId))
           OR (@Case<>1 AND NOT EXISTS(SELECT 1 FROM [#ExampleIntegrity]
                         WHERE [DatabaseId]=DB_ID() AND [DatabaseName]=@Database COLLATE SQL_Latin1_General_CP1_CS_AS
                           AND [FindingCode]='SUSPECT_PAGES_PRESENT' AND [SuspectPageCount]=1))
            THROW 55860,N'Der positive DatabaseIntegrity-Status- oder Limitvertrag ist verletzt.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleIntegrity] AS [e]
                  WHERE [e].[LastGoodCheckDbTime] IS NOT NULL OR [e].[CheckdbAgeHours] IS NOT NULL
                    OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] AS [d]
                                   WHERE [d].[database_id]=[e].[DatabaseId]
                                     AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[DatabaseName]
                                     AND [d].[state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[StateDesc]
                                     AND [d].[page_verify_option_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[PageVerifyOptionDesc])
                    OR [e].[SuspectPageCount]<>(SELECT COUNT_BIG(*) FROM [msdb].[dbo].[suspect_pages] WHERE [database_id]=[e].[DatabaseId])
                    OR [e].[DamagedBackupCount]<>0 OR [e].[BackupWithoutChecksumCount]<>0
                    OR [e].[HadrPageRepairCount]<>0 OR [e].[HadrPageRepairPendingCount]<>0)
            THROW 55862,N'Die DatabaseIntegrity-Ausgabe weicht von nativen Metadaten oder dem CHECKDB-Evidenzvertrag ab.',1;
        IF (@Details=0 AND COALESCE(JSON_QUERY(@Json,N'$.pageDetails'),N'')<>N'[]')
           OR (@Details=1 AND ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.pageDetails'))<>1
               OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.pageDetails')
                             WITH([DatabaseName] sysname N'$.DatabaseName',[FileId] int N'$.FileId',[PageId] bigint N'$.PageId',
                                  [EventType] int N'$.EventType',[PageTypeDesc] nvarchar(64) N'$.PageTypeDesc',
                                  [ObjectId] int N'$.ObjectId',[IndexId] int N'$.IndexId',
                                  [PartitionId] bigint N'$.PartitionId',[AllocUnitId] bigint N'$.AllocUnitId') AS [e]
                             CROSS APPLY [sys].[dm_db_page_info](DB_ID(),1,1,'LIMITED') AS [p]
                             WHERE [e].[DatabaseName]=@Database COLLATE SQL_Latin1_General_CP1_CS_AS
                               AND [e].[FileId]=1 AND [e].[PageId]=1 AND [e].[EventType]=1
                               AND [e].[PageTypeDesc] IS NULL AND [p].[page_type_desc] IS NULL
                               AND NOT EXISTS(SELECT [e].[ObjectId],[e].[IndexId],[e].[PartitionId],[e].[AllocUnitId]
                                              EXCEPT SELECT [p].[object_id],[p].[index_id],[p].[partition_id],[p].[alloc_unit_id]))))
            THROW 55864,N'Der opt-in DatabaseIntegrity-Seitendetailvertrag ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleIntegrity] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.integrity'));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
               WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
                 OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55863,N'TABLE und JSON enthalten verschiedene DatabaseIntegrity-Ergebnisse.',1;

        DROP TABLE [#ExampleIntegrity];
        SET @Case+=1;
    END;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[suspect_pages] WHERE [database_id]=DB_ID() AND [file_id]=1 AND [page_id]=1)
    THROW 55869,N'Die eigene synthetische Suspect-Page-Fixture wurde nicht zurückgerollt.',1;
GO
