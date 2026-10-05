USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
DECLARE @Session sysname=N'ExampleXeReaderÄ',@Created bit=0,@Sql nvarchar(max),@Path nvarchar(4000),@Pattern nvarchar(4000),
        @Target xml,@Case tinyint=0,@Source varchar(20),@ResolvedSource varchar(20),@Xml bit,@Limit int,
        @Names nvarchar(max),@Selection nvarchar(258),@From datetime2(7),@To datetime2(7),@FirstTime datetime2(7),@SecondTime datetime2(7),
        @Flush bit,@Confirmed bit,@Expected bigint,@ExpectedStatus varchar(40),@Json nvarchar(max),
        @RestoreLockTimeout nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name]=@Session)
    THROW 55990,N'Die eigene Readerfixture darf keine bestehende XE-Session verwenden.',1;
SET @Path=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultLogPath'));
IF NULLIF(@Path,N'') IS NULL THROW 55990,N'Der native Pfad für die eigene Eventdatei fehlt.',1;
SET @Path=CONCAT(@Path,N'example_xe_reader_',CONVERT(nvarchar(36),NEWID()),N'.xel');
SET @Pattern=LEFT(@Path,LEN(@Path)-4)+N'*.xel';
CREATE TABLE [#ExampleXeReaderNative]
([SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS,[EventName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [TimestampUtc] datetime2(7),[FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS,[FileOffset] bigint,[EventXml] xml);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    SET @Sql=N'CREATE EVENT SESSION '+QUOTENAME(@Session)+N' ON SERVER
      ADD EVENT [sqlserver].[error_reported](WHERE ([error_number]=(50000) AND [severity]=(16) AND [sqlserver].[session_id]=('+CONVERT(nvarchar(20),@@SPID)+N')))
      ADD TARGET [package0].[ring_buffer],
      ADD TARGET [package0].[event_file](SET filename=N'''+REPLACE(@Path,N'''',N'''''')+N''',max_file_size=(5),max_rollover_files=(1))
      WITH(MAX_DISPATCH_LATENCY=1 SECONDS,STARTUP_STATE=OFF);';
    EXEC [master].[sys].[sp_executesql] @Sql; SET @Created=1;
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Session)+N' ON SERVER STATE=START;'; EXEC [master].[sys].[sp_executesql] @Sql;
    BEGIN TRY RAISERROR(N'Example own XE reader event Ä.',16,1); END TRY BEGIN CATCH END CATCH;
    WAITFOR DELAY '00:00:00.250';
    BEGIN TRY RAISERROR(N'Example own XE reader event Ü.',16,1); END TRY BEGIN CATCH END CATCH;
    WAITFOR DELAY '00:00:02';
    SELECT @Target=TRY_CONVERT(xml,[t].[target_data]) FROM [sys].[dm_xe_sessions] AS [s]
      JOIN [sys].[dm_xe_session_targets] AS [t] ON [t].[event_session_address]=[s].[address]
      WHERE [s].[name]=@Session AND [t].[target_name]=N'ring_buffer';
    INSERT [#ExampleXeReaderNative]
    SELECT 'RING_BUFFER',[x].[e].value('(@name)[1]','sysname'),[x].[e].value('(@timestamp)[1]','datetime2(7)'),NULL,NULL,[x].[e].query('.')
    FROM @Target.nodes('/RingBufferTarget/event') AS [x]([e]);
    SELECT @FirstTime=MIN([TimestampUtc]),@SecondTime=MAX([TimestampUtc]) FROM [#ExampleXeReaderNative];
    IF (SELECT COUNT_BIG(*) FROM [#ExampleXeReaderNative])<>2 OR @FirstTime IS NULL OR @SecondTime IS NULL OR @FirstTime>=@SecondTime
       OR EXISTS(SELECT 1 FROM [#ExampleXeReaderNative] WHERE [EventName]<>N'error_reported'
          OR [EventXml].value('(/event/data[@name="error_number"]/value/text())[1]','int')<>50000
          OR [EventXml].value('(/event/data[@name="severity"]/value/text())[1]','int')<>16)
        THROW 55990,N'Die beiden eigenen Ringbufferereignisse fehlen oder besitzen unerwartete Metadaten.',1;
    WHILE @Case<13
    BEGIN
        IF @Case=7
        BEGIN
            SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Session)+N' ON SERVER STATE=STOP;'; EXEC [master].[sys].[sp_executesql] @Sql;
            WAITFOR DELAY '00:00:01';
            INSERT [#ExampleXeReaderNative]
            SELECT 'EVENT_FILE',[object_name],[timestamp_utc],[file_name],[file_offset],CONVERT(xml,[event_data])
            FROM [sys].[fn_xe_file_target_read_file](@Pattern,NULL,NULL,NULL);
            IF (SELECT COUNT_BIG(*) FROM [#ExampleXeReaderNative] WHERE [SourceType]='EVENT_FILE')<>2
               OR EXISTS(SELECT 1 FROM [#ExampleXeReaderNative] WHERE [SourceType]='EVENT_FILE'
                   AND ([FileName] IS NULL OR [FileOffset] IS NULL OR [EventName]<>N'error_reported'
                        OR [TimestampUtc] NOT IN(@FirstTime,@SecondTime)
                        OR [EventXml].value('(/event/data[@name="error_number"]/value/text())[1]','int')<>50000
                        OR [EventXml].value('(/event/data[@name="severity"]/value/text())[1]','int')<>16))
                THROW 55990,N'Die native eigene Eventdatei entspricht nicht den zwei Ringbufferereignissen.',1;
        END;
        SELECT @Source=CASE WHEN @Case=10 THEN 'AUTO' WHEN @Case>=7 THEN 'EVENT_FILE' ELSE 'RING_BUFFER' END,
          @ResolvedSource=CASE WHEN @Case>=7 THEN 'EVENT_FILE' ELSE 'RING_BUFFER' END,
          @Xml=CASE WHEN @Case IN(2,8,9) THEN 0 ELSE 1 END,
          @Limit=CASE WHEN @Case IN(1,8) THEN 1 WHEN @Case IN(2,9) THEN NULL ELSE 0 END,
          @Names=CASE WHEN @Case=4 THEN N'ExampleMissingEvent' ELSE N'error_reported' END,
          @Selection=CASE WHEN @Case=0 THEN @Session ELSE QUOTENAME(@Session) END,
          @From=CASE WHEN @Case IN(3,11) THEN @SecondTime ELSE @FirstTime END,
          @To=CASE WHEN @Case=12 THEN @SecondTime ELSE DATEADD(SECOND,1,@SecondTime) END,
          @Flush=CASE WHEN @Case=5 THEN 0 ELSE 1 END,@Confirmed=CASE WHEN @Case=6 THEN 0 ELSE 1 END,
          @Expected=CASE WHEN @Case IN(4,5,6) THEN 0 WHEN @Case IN(1,3,8,11,12) THEN 1 ELSE 2 END,
          @ExpectedStatus=CASE WHEN @Case=4 THEN 'AVAILABLE_LIMITED' WHEN @Case=5 THEN 'AVAILABLE_DISABLED'
                              WHEN @Case=6 THEN 'HIGH_IMPACT_CONFIRMATION_REQUIRED' ELSE 'AVAILABLE' END,@Json=NULL;
        CREATE TABLE [#ExampleXeReaderExport]([Dummy] int NULL);
        EXEC [monitor].[USP_ExtendedEventsReadEvents] @SourceExtendedEventSessionName=@Selection,@Quelle=@Source,
          @EventNames=@Names,@VonUtc=@From,@BisUtc=@To,@MaxZeilen=@Limit,@MitEventXml=@Xml,
          @BestaetigeTargetFlush=@Flush,@HighImpactConfirmed=@Confirmed,@ResultSetArt='TABLE',
          @ResultTablesJson=N'{"events":"#ExampleXeReaderExport"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeReaderExport') AND [collation_name] IS NOT NULL)<>3
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeReaderExport')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55991,N'Der XE-Reader-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Case=4 THEN N'true' ELSE N'false' END
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedRows')),-1)<>@Expected
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.source'),N'')<>@ResolvedSource
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL
           OR LEFT(COALESCE(JSON_QUERY(@Json,N'$.events'),N''),1)<>N'['
           OR (SELECT COUNT_BIG(*) FROM [#ExampleXeReaderExport])<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.events'))<>@Expected
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sources'))<>CASE WHEN @Case=6 THEN 0 ELSE 1 END
            THROW 55992,N'Der XE-Reader-Status-, Filter-, Limit- oder Gatevertrag ist verletzt.',1;
        IF @Case<>6 AND (COALESCE(JSON_VALUE(@Json,N'$.sources[0].SourceType'),N'')<>@ResolvedSource
           OR COALESCE(JSON_VALUE(@Json,N'$.sources[0].SessionName'),N'')<>@Session
           OR COALESCE(JSON_VALUE(@Json,N'$.sources[0].TargetName'),N'')<>CASE WHEN @Case>=7 THEN N'event_file' ELSE N'ring_buffer' END
           OR COALESCE(JSON_VALUE(@Json,N'$.sources[0].StatusCode'),N'')<>CASE WHEN @Case=5 THEN N'AVAILABLE_DISABLED' ELSE N'AVAILABLE' END
           OR (@Case>=7 AND COALESCE(JSON_VALUE(@Json,N'$.sources[0].ResolvedPath'),N'')<>@Pattern)
           OR (@Case<7 AND JSON_VALUE(@Json,N'$.sources[0].ResolvedPath') IS NOT NULL))
            THROW 55993,N'Der native Readerquellenstatus stimmt nicht überein.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.events') WITH([ErrorNumber] int,[Severity] int) AS [e]
           WHERE [ErrorNumber] IS NULL OR [ErrorNumber]<>50000 OR [Severity] IS NULL OR [Severity]<>16)
            THROW 55993,N'Die angereicherten eigenen Fehlernummern und Schweregrade fehlen.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          ((SELECT TOP(@Expected) * FROM [#ExampleXeReaderNative] WHERE [SourceType]=@ResolvedSource
              AND [TimestampUtc]>=@From AND [TimestampUtc]<@To ORDER BY [TimestampUtc] DESC,[FileName] DESC,[FileOffset] DESC
              FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [#ExampleXeReaderExport] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT TOP(@Expected) [SourceType],[EventName],[TimestampUtc],[FileName],[FileOffset],
              CASE WHEN @Xml=1 THEN CONVERT(nvarchar(max),[EventXml]) END AS [EventXml]
              FROM [#ExampleXeReaderNative] WHERE [SourceType]=@ResolvedSource AND [TimestampUtc]>=@From AND [TimestampUtc]<@To
              ORDER BY [TimestampUtc] DESC,[FileName] DESC,[FileOffset] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT [SourceType],[EventName],[TimestampUtc],[FileName],[FileOffset],[EventXml]
              FROM OPENJSON(@Json,N'$.events') WITH([SourceType] varchar(20),[EventName] nvarchar(128),[TimestampUtc] datetime2(7),
                   [FileName] nvarchar(260),[FileOffset] bigint,[EventXml] nvarchar(max)) FOR JSON PATH,INCLUDE_NULL_VALUES));
        UPDATE @Parity SET [ExpectedJson]=COALESCE([ExpectedJson],N'[]'),[ActualJson]=COALESCE([ActualJson],N'[]');
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE LEFT(COALESCE([p].[ActualJson],N''),1)<>N'['
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
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
            THROW 55994,N'Die nativen XE-Reader-TABLE- oder JSON-Kernprojektionen stimmen nicht überein.',1;
        DROP TABLE [#ExampleXeReaderExport]; SET @Case+=1;
    END;
END TRY
BEGIN CATCH
    IF @Created=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Session)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    EXEC(@RestoreLockTimeout); THROW;
END CATCH;
IF @Created=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Session)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
EXEC(@RestoreLockTimeout);
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name]=@Session)
    THROW 55995,N'Die eigene XE-Readersession wurde nicht entfernt.',1;
-- Eventdateien bleiben im eigenen Testcontainer und werden mit dessen Volume entfernt.
GO
