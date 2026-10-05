USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
DECLARE @Running sysname=N'ExampleXeInventoryRunÄ',@Stopped sysname=N'ExampleXeInventoryStopÜ',
        @CreatedRunning bit=0,@CreatedStopped bit=0,@Sql nvarchar(max),@Json nvarchar(max),@Case tinyint=0,
        @Names nvarchar(max),@Runtime bit,@OnlyRunning bit,@Details bit,@Limit int,@Expected bigint,
        @ExpectedDetails bigint,@EventNames nvarchar(max),@TargetNames nvarchar(max),
        @BeforeAddress varbinary(8),@AfterAddress varbinary(8),@BeforeTime datetime,@AfterTime datetime,
        @ExpectedJson nvarchar(max),@ActualJson nvarchar(max),
        @RestoreLockTimeout nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name] IN(@Running,@Stopped))
    THROW 56000,N'Die eigenen Inventarfixtures dürfen keine bestehenden XE-Sessions verwenden.',1;
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    SET @Sql=N'CREATE EVENT SESSION '+QUOTENAME(@Running)+N' ON SERVER
      ADD EVENT [sqlserver].[error_reported](ACTION([sqlserver].[session_id])
        WHERE([error_number]=(50000) AND [sqlserver].[session_id]=('+CONVERT(nvarchar(20),@@SPID)+N')))
      ADD TARGET [package0].[ring_buffer](SET max_memory=(128))
      WITH(MAX_MEMORY=4096 KB,MAX_DISPATCH_LATENCY=1 SECONDS,STARTUP_STATE=OFF);';
    EXEC [master].[sys].[sp_executesql] @Sql; SET @CreatedRunning=1;
    SET @Sql=REPLACE(@Sql,QUOTENAME(@Running),QUOTENAME(@Stopped));
    EXEC [master].[sys].[sp_executesql] @Sql; SET @CreatedStopped=1;
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Running)+N' ON SERVER STATE=START;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    IF (SELECT COUNT_BIG(*) FROM [sys].[server_event_sessions] WHERE [name] IN(@Running,@Stopped))<>2
       OR (SELECT COUNT_BIG(*) FROM [sys].[dm_xe_sessions] WHERE [name] IN(@Running,@Stopped))<>1
       OR NOT EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] WHERE [name]=@Running)
       OR (SELECT COUNT_BIG(*) FROM [sys].[server_event_session_events] AS [e]
            JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[e].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND [e].[package]=N'sqlserver' AND [e].[name]=N'error_reported')<>2
       OR (SELECT COUNT_BIG(*) FROM [sys].[server_event_session_actions] AS [a]
            JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[a].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND [a].[package]=N'sqlserver' AND [a].[name]=N'session_id')<>2
       OR (SELECT COUNT_BIG(*) FROM [sys].[server_event_session_fields] AS [f]
            JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[f].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND [f].[name]=N'max_memory' AND TRY_CONVERT(int,[f].[value])=128)<>2
        THROW 56000,N'Die eigenen nativen Session-, Event-, Action- oder Feldfixtures fehlen.',1;
    WHILE @Case<9
    BEGIN
        SELECT @Names=CASE WHEN @Case=8 THEN QUOTENAME(@Stopped) ELSE QUOTENAME(@Running)+N'|'+QUOTENAME(@Stopped) END,
          @Runtime=CASE WHEN @Case IN(1,4,8) THEN 1 ELSE 0 END,@OnlyRunning=CASE WHEN @Case IN(4,5) THEN 1 ELSE 0 END,
          @Details=CASE WHEN @Case=2 THEN 0 ELSE 1 END,
          @Limit=CASE WHEN @Case=3 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
          @Expected=CASE WHEN @Case=5 THEN 0 WHEN @Case IN(3,4,8) THEN 1 ELSE 2 END,
          @ExpectedDetails=CASE WHEN @Case=2 THEN 0 WHEN @Case IN(3,4,5,8) THEN 1 ELSE 2 END,
          @EventNames=CASE WHEN @Case=6 THEN N'ExampleMissingEvent' ELSE N'error_reported' END,
          @TargetNames=CASE WHEN @Case=7 THEN N'ExampleMissingTarget' ELSE N'ring_buffer' END,@Json=NULL;
        SELECT @BeforeAddress=[address],@BeforeTime=[create_time] FROM [sys].[dm_xe_sessions] WHERE [name]=@Running;
        CREATE TABLE [#ExampleXeSessionsExport]([Dummy] int NULL);
        EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@Names,@EventNames=@EventNames,
          @TargetNames=@TargetNames,@NurLaufend=@OnlyRunning,@MitLaufzeitstatus=@Runtime,
          @MitEvents=@Details,@MitActions=@Details,@MitTargets=@Details,@MitFeldern=@Details,@MaxZeilen=@Limit,
          @ResultSetArt='TABLE',@ResultTablesJson=N'{"sessions":"#ExampleXeSessionsExport"}',
          @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SELECT @AfterAddress=[address],@AfterTime=[create_time] FROM [sys].[dm_xe_sessions] WHERE [name]=@Running;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeSessionsExport') AND [collation_name] IS NOT NULL)<>6
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeSessionsExport')
              AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56001,N'Der XE-Sessionexport übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.sessionCount')),-1)<>@Expected
           OR (SELECT COUNT_BIG(*) FROM [#ExampleXeSessionsExport])<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sessions'))<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.events'))<>CASE WHEN @Case=6 THEN 0 ELSE @ExpectedDetails END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.actions'))<>CASE WHEN @Case=6 THEN 0 ELSE @ExpectedDetails END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.targets'))<>CASE WHEN @Case=7 THEN 0 ELSE @ExpectedDetails END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.fields'))<>@ExpectedDetails
           OR EXISTS(SELECT 1 FROM(VALUES(N'$.sessions'),(N'$.events'),(N'$.actions'),(N'$.targets'),(N'$.fields')) AS [a]([Path])
               WHERE LEFT(COALESCE(JSON_QUERY(@Json,[a].[Path]),N''),1)<>N'[')
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
            THROW 56002,N'Der Sessioninventar-, Limit-, Detail- oder Filtervertrag ist verletzt.',1;
        IF @BeforeAddress IS NULL OR @AfterAddress IS NULL OR @BeforeAddress<>@AfterAddress OR @BeforeTime IS NULL OR @AfterTime IS NULL
           OR EXISTS(SELECT 1 FROM [#ExampleXeSessionsExport] WHERE [IsRunning]<>CASE WHEN @Runtime=1 AND [SessionName]=@Running THEN 1 ELSE 0 END
                OR (@Runtime=1 AND [SessionName]=@Running AND ([RunningSince] IS NULL
                     OR ABS(DATEDIFF_BIG(MILLISECOND,[RunningSince],@BeforeTime))>10 OR ABS(DATEDIFF_BIG(MILLISECOND,[RunningSince],@AfterTime))>10))
                OR ((@Runtime=0 OR [SessionName]=@Stopped) AND ([RunningSince] IS NOT NULL OR [PendingBuffers] IS NOT NULL
                     OR [TotalRegularBuffers] IS NOT NULL OR [RegularBufferSizeBytes] IS NOT NULL OR [TotalLargeBuffers] IS NOT NULL
                     OR [LargeBufferSizeBytes] IS NOT NULL OR [TotalBufferSizeBytes] IS NOT NULL OR [BufferPolicyDesc] IS NOT NULL
                     OR [DroppedEventCount] IS NOT NULL OR [DroppedBufferCount] IS NOT NULL OR [BlockedEventFireTimeMilliseconds] IS NOT NULL
                     OR [LargestEventDroppedSizeBytes] IS NOT NULL OR [BufferProcessedCount] IS NOT NULL OR [BufferFullCount] IS NOT NULL
                     OR [TotalBytesGenerated] IS NOT NULL OR [TotalTargetMemoryBytes] IS NOT NULL)))
            THROW 56003,N'Der native Laufzeitstatus oder der vorhandene Laufzeit-Opt-out-Vertrag ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          ((SELECT TOP(@Expected) [s].[event_session_id] AS [EventSessionId],[s].[name] AS [SessionName],[s].[startup_state] AS [StartupState],
               [s].[event_retention_mode] AS [EventRetentionMode],[s].[event_retention_mode_desc] AS [EventRetentionModeDesc],
               [s].[max_dispatch_latency] AS [MaxDispatchLatencyMilliseconds],[s].[max_memory] AS [MaxMemoryKb],
               [s].[max_event_size] AS [MaxEventSizeKb],[s].[memory_partition_mode] AS [MemoryPartitionMode],
               [s].[memory_partition_mode_desc] AS [MemoryPartitionModeDesc],[s].[track_causality] AS [TrackCausality],
               1 AS [EventCount],1 AS [TargetCount],1 AS [ActionCount],CONVERT(bit,1) AS [HasRingBuffer],CONVERT(bit,0) AS [HasEventFile]
             FROM [sys].[server_event_sessions] AS [s] WHERE [s].[name] IN(@Running,@Stopped)
               AND (@Case<>8 OR [s].[name]=@Stopped) AND (@OnlyRunning=0 OR (@Runtime=1 AND [s].[name]=@Running))
             ORDER BY [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT [EventSessionId],[SessionName],[StartupState],[EventRetentionMode],[EventRetentionModeDesc],
               [MaxDispatchLatencyMilliseconds],[MaxMemoryKb],[MaxEventSizeKb],[MemoryPartitionMode],[MemoryPartitionModeDesc],
               [TrackCausality],[EventCount],[TargetCount],[ActionCount],[HasRingBuffer],[HasEventFile]
            FROM [#ExampleXeSessionsExport] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT * FROM [#ExampleXeSessionsExport] FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT * FROM OPENJSON(@Json,N'$.sessions') WITH
             ([EventSessionId] int,[SessionName] nvarchar(128),[IsRunning] bit,[StartupState] bit,
              [EventRetentionMode] nchar(1),[EventRetentionModeDesc] nvarchar(60),[MaxDispatchLatencyMilliseconds] int,
              [MaxMemoryKb] int,[MaxEventSizeKb] int,[MemoryPartitionMode] nchar(1),[MemoryPartitionModeDesc] nvarchar(60),
              [TrackCausality] bit,[RunningSince] datetime,[PendingBuffers] int,[TotalRegularBuffers] int,
              [RegularBufferSizeBytes] bigint,[TotalLargeBuffers] int,[LargeBufferSizeBytes] bigint,[TotalBufferSizeBytes] bigint,
              [BufferPolicyDesc] nvarchar(256),[DroppedEventCount] int,[DroppedBufferCount] int,[BlockedEventFireTimeMilliseconds] int,
              [LargestEventDroppedSizeBytes] int,[BufferProcessedCount] bigint,[BufferFullCount] bigint,[TotalBytesGenerated] bigint,
              [TotalTargetMemoryBytes] bigint,[EventCount] int,[TargetCount] int,[ActionCount] int,[HasRingBuffer] bit,[HasEventFile] bit)
            FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT TOP(CASE WHEN @Case=6 THEN 0 ELSE @ExpectedDetails END) [s].[name] AS [SessionName],[e].[event_id] AS [EventId],
               [e].[package] AS [PackageName],[e].[name] AS [EventName],[e].[predicate] AS [Predicate]
            FROM [sys].[server_event_session_events] AS [e] JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[e].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND (@Case<>8 OR [s].[name]=@Stopped) AND (@OnlyRunning=0 OR [s].[name]=@Running)
            ORDER BY [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[e].[event_id] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.events')),
          ((SELECT TOP(CASE WHEN @Case=6 THEN 0 ELSE @ExpectedDetails END) [s].[name] AS [SessionName],N'error_reported' AS [EventName],
               1 AS [ActionOrdinal],[a].[package] AS [PackageName],[a].[name] AS [ActionName]
            FROM [sys].[server_event_session_actions] AS [a] JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[a].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND (@Case<>8 OR [s].[name]=@Stopped) AND (@OnlyRunning=0 OR [s].[name]=@Running)
            ORDER BY [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.actions')),
          ((SELECT TOP(CASE WHEN @Case=7 THEN 0 ELSE @ExpectedDetails END) [s].[name] AS [SessionName],[t].[target_id] AS [TargetId],
               [t].[package] AS [PackageName],[t].[name] AS [TargetName],CAST(NULL AS nvarchar(4000)) AS [ConfiguredFileName],
               CAST(NULL AS bigint) AS [MaxFileSizeMb],CAST(NULL AS int) AS [MaxRolloverFiles],CONVERT(bigint,128) AS [MaxMemoryKb]
            FROM [sys].[server_event_session_targets] AS [t] JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[t].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND (@Case<>8 OR [s].[name]=@Stopped) AND (@OnlyRunning=0 OR [s].[name]=@Running)
            ORDER BY [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[t].[target_id] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.targets')),
          ((SELECT TOP(@ExpectedDetails) [s].[name] AS [SessionName],'TARGET' AS [ObjectType],[f].[object_id] AS [ObjectId],
               N'ring_buffer' AS [ObjectName],[f].[name] AS [FieldName],CONVERT(nvarchar(4000),[f].[value]) AS [FieldValue]
            FROM [sys].[server_event_session_fields] AS [f] JOIN [sys].[server_event_sessions] AS [s] ON [s].[event_session_id]=[f].[event_session_id]
            WHERE [s].[name] IN(@Running,@Stopped) AND (@Case<>8 OR [s].[name]=@Stopped) AND (@OnlyRunning=0 OR [s].[name]=@Running)
            ORDER BY [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[f].[object_id],[f].[name] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.fields'));
        UPDATE @Parity SET [ExpectedJson]=COALESCE([ExpectedJson],N'[]'),[ActualJson]=COALESCE([ActualJson],N'[]');
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE
            EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
                CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
                CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
                CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
                CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
            THROW 56004,N'Die nativen Inventarfelder oder TABLE-/JSON-Multimengen stimmen nicht überein.',1;
        DROP TABLE [#ExampleXeSessionsExport]; SET @Case+=1;
    END;
END TRY
BEGIN CATCH
    IF @CreatedRunning=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Running)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    IF @CreatedStopped=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Stopped)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    EXEC(@RestoreLockTimeout); THROW;
END CATCH;
IF @CreatedRunning=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Running)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
IF @CreatedStopped=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Stopped)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
EXEC(@RestoreLockTimeout);
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name] IN(@Running,@Stopped))
    THROW 56005,N'Die eigenen XE-Inventarsessions wurden nicht entfernt.',1;
GO
