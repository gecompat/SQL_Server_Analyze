USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
-- Eigene Ringbuffer im frischen Testcontainer erfassen ausschließlich diese Session.
DECLARE @First sysname=N'ExampleXeTargetÄ',@Second sysname=N'ExampleXeTargetÜ',
        @FirstCreated bit=0,@SecondCreated bit=0,@Sql nvarchar(max),@Case tinyint=0,
        @Names nvarchar(max),@Targets nvarchar(max),@Data bit,@Characters int,@Flush bit,@Confirmed bit,
        @Expected bigint,@ExpectedStatus varchar(40),@ExpectedPartial bit,@Json nvarchar(max),
        @Start datetime2(3),@End datetime2(3),
        @RestoreLockTimeout nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name] IN(@First,@Second))
    THROW 55980,N'Die eigene XE-Fixture darf keine bestehende Session verwenden.',1;
CREATE TABLE [#ExampleXeTargetBefore]
([SessionName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[TargetName] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [SessionCreateTime] datetime,[ExecutionCount] bigint,[ExecutionDurationMs] bigint,[BytesWritten] bigint,[SessionAddress] varbinary(8));
CREATE TABLE [#ExampleXeTargetAfter]
([SessionName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[TargetName] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [SessionCreateTime] datetime,[ExecutionCount] bigint,[ExecutionDurationMs] bigint,[BytesWritten] bigint,[SessionAddress] varbinary(8));
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
BEGIN TRY
    SET @Sql=N'CREATE EVENT SESSION '+QUOTENAME(@First)+N' ON SERVER
      ADD EVENT [sqlserver].[error_reported](WHERE ([error_number]=(50000) AND [severity]=(16) AND [sqlserver].[session_id]=('+CONVERT(nvarchar(20),@@SPID)+N')))
      ADD TARGET [package0].[ring_buffer] WITH(MAX_DISPATCH_LATENCY=1 SECONDS,STARTUP_STATE=OFF);';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @FirstCreated=1;
    SET @Sql=REPLACE(@Sql,QUOTENAME(@First),QUOTENAME(@Second));
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @SecondCreated=1;
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@First)+N' ON SERVER STATE=START;
      ALTER EVENT SESSION '+QUOTENAME(@Second)+N' ON SERVER STATE=START;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    BEGIN TRY RAISERROR(N'Example own XE target event Ä.',16,1); END TRY BEGIN CATCH END CATCH;
    BEGIN TRY RAISERROR(N'Example own XE target event Ü.',16,1); END TRY BEGIN CATCH END CATCH;
    WAITFOR DELAY '00:00:02';
    IF (SELECT COUNT_BIG(*) FROM [sys].[dm_xe_sessions] AS [s]
       JOIN [sys].[dm_xe_session_targets] AS [t] ON [t].[event_session_address]=[s].[address]
       CROSS APPLY(SELECT TRY_CONVERT(xml,[t].[target_data]) AS [EventXml]) AS [x]
       WHERE [s].[name] IN(@First,@Second) AND [t].[target_name]=N'ring_buffer'
         AND [x].[EventXml].value('count(/RingBufferTarget/event[@name="error_reported"])','int')=2)<>2
        THROW 55980,N'Die beiden eigenen Ringbuffer enthalten nicht die zwei synthetischen Ereignisse.',1;
    WHILE @Case<7
    BEGIN
        SELECT @Names=CASE WHEN @Case=3 THEN QUOTENAME(@First) ELSE QUOTENAME(@First)+N'|'+QUOTENAME(@Second) END,
          @Targets=CASE WHEN @Case=4 THEN N'ExampleMissingTarget' ELSE N'ring_buffer' END,
          @Data=CASE WHEN @Case IN(1,2,3) THEN 1 ELSE 0 END,@Characters=CASE WHEN @Case=1 THEN 5 ELSE 0 END,
          @Flush=CASE WHEN @Case=5 THEN 0 ELSE 1 END,@Confirmed=CASE WHEN @Case=6 THEN 0 ELSE 1 END,
          @Expected=CASE WHEN @Case>=4 THEN 0 WHEN @Case=3 THEN 1 ELSE 2 END,
          @ExpectedStatus=CASE WHEN @Case=4 THEN 'AVAILABLE_LIMITED' WHEN @Case=5 THEN 'AVAILABLE_DISABLED'
                              WHEN @Case=6 THEN 'HIGH_IMPACT_CONFIRMATION_REQUIRED' ELSE 'AVAILABLE' END,
          @ExpectedPartial=CASE WHEN @Case=4 THEN 1 ELSE 0 END,@Json=NULL;
        DELETE [#ExampleXeTargetBefore]; DELETE [#ExampleXeTargetAfter];
        INSERT [#ExampleXeTargetBefore]
        SELECT [s].[name],[t].[target_name],[s].[create_time],[t].[execution_count],[t].[execution_duration_ms],[t].[bytes_written],[s].[address]
        FROM [sys].[dm_xe_sessions] AS [s] JOIN [sys].[dm_xe_session_targets] AS [t] ON [t].[event_session_address]=[s].[address]
        WHERE [s].[name] IN(@First,@Second) AND [t].[target_name]=N'ring_buffer';
        CREATE TABLE [#ExampleXeTargetExport]([Dummy] int NULL);
        SET @Start=SYSUTCDATETIME();
        EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=@Names,@TargetNames=@Targets,
          @MitTargetData=@Data,@MaxTargetDataZeichen=@Characters,@BestaetigeTargetFlush=@Flush,@HighImpactConfirmed=@Confirmed,
          @ResultSetArt='TABLE',@ResultTablesJson=N'{"targets":"#ExampleXeTargetExport"}',
          @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SET @End=SYSUTCDATETIME();
        INSERT [#ExampleXeTargetAfter]
        SELECT [s].[name],[t].[target_name],[s].[create_time],[t].[execution_count],[t].[execution_duration_ms],[t].[bytes_written],[s].[address]
        FROM [sys].[dm_xe_sessions] AS [s] JOIN [sys].[dm_xe_session_targets] AS [t] ON [t].[event_session_address]=[s].[address]
        WHERE [s].[name] IN(@First,@Second) AND [t].[target_name]=N'ring_buffer';
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeTargetExport') AND [collation_name] IS NOT NULL)<>8
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleXeTargetExport')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55981,N'Der XE-Target-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @ExpectedPartial=1 THEN N'true' ELSE N'false' END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.errorNumber'),N'null')<>N'null'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleXeTargetExport])<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.targets'))<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings'))<>CASE WHEN @Case=1 THEN 1 ELSE 0 END
            THROW 55982,N'Der XE-Target-Status-, Filter- oder Gatevertrag ist verletzt.',1;
        -- Native create_time-Werte variierten zwischen Reads um einen datetime-Tick.
        -- Die Adresse muss stabil bleiben; beide Zeitgegenproben erlauben höchstens 10 ms.
        IF EXISTS(SELECT 1 FROM [#ExampleXeTargetExport] AS [r]
          LEFT JOIN [#ExampleXeTargetBefore] AS [b] ON [b].[SessionName]=[r].[SessionName] AND [b].[TargetName]=[r].[TargetName]
          LEFT JOIN [#ExampleXeTargetAfter] AS [a] ON [a].[SessionName]=[r].[SessionName] AND [a].[TargetName]=[r].[TargetName]
          WHERE [b].[SessionName] IS NULL OR [a].[SessionName] IS NULL OR [r].[SessionCreateTime] IS NULL
            OR [b].[SessionCreateTime] IS NULL OR [a].[SessionCreateTime] IS NULL
            OR [b].[SessionAddress] IS NULL OR [a].[SessionAddress] IS NULL OR [b].[SessionAddress]<>[a].[SessionAddress]
            OR DATEDIFF_BIG(millisecond,[r].[SessionCreateTime],[b].[SessionCreateTime]) NOT BETWEEN -10 AND 10
            OR DATEDIFF_BIG(millisecond,[r].[SessionCreateTime],[a].[SessionCreateTime]) NOT BETWEEN -10 AND 10
            OR [r].[CapturedAtUtc] NOT BETWEEN @Start AND @End
            OR [r].[ExecutionCount] NOT BETWEEN [b].[ExecutionCount] AND [a].[ExecutionCount]
            OR [r].[ExecutionDurationMs] NOT BETWEEN [b].[ExecutionDurationMs] AND [a].[ExecutionDurationMs]
            OR [r].[BytesWritten] NOT BETWEEN [b].[BytesWritten] AND [a].[BytesWritten]
            OR [r].[SourceType]<>'LIVE_DMV' OR [r].[SourceObject]<>N'sys.dm_xe_session_targets'
            OR [r].[EvidenceScope]<>'SERVER_XE_TARGET' OR [r].[ValueStatus]<>'AVAILABLE' OR [r].[IsCurrent]<>1 OR [r].[IsCumulative]<>1)
            THROW 55983,N'Die nativen XE-Targetmetadaten oder Zählerintervalle stimmen nicht überein.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleXeTargetExport]
           WHERE (@Data=0 AND ([TargetData] IS NOT NULL OR [TargetDataCharacters] IS NOT NULL OR [TargetDataBytes] IS NOT NULL
                                OR [TargetDataIsTruncated]<>0 OR [TargetDataStatus]<>'NOT_REQUESTED'))
              OR (@Data=1 AND ([TargetData] IS NULL OR [TargetDataCharacters] IS NULL OR [TargetDataBytes] IS NULL
                               OR [TargetDataCharacters]<=5 OR [TargetDataBytes]<=10))
              OR (@Case=1 AND (LEN([TargetData])<>5 OR DATALENGTH([TargetData])<>10 OR [TargetDataIsTruncated]<>1
                               OR [TargetDataStatus]<>'OUTPUT_VALUE_TRUNCATED'))
              OR (@Data=1 AND @Characters=0 AND (LEN([TargetData])<>[TargetDataCharacters] OR DATALENGTH([TargetData])<>[TargetDataBytes]
                                                OR [TargetDataIsTruncated]<>0 OR [TargetDataStatus]<>'AVAILABLE')))
            THROW 55984,N'Der optionale XE-Targetdaten- oder Kürzungsvertrag ist verletzt.',1;
        IF @Case=1 AND (COALESCE(JSON_VALUE(@Json,N'$.warnings[0].code'),N'')<>N'OUTPUT_VALUE_TRUNCATED'
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.warnings[0].truncatedValueCount')),-1)<>2
           OR COALESCE(JSON_VALUE(@Json,N'$.warnings[0].parameterName'),N'')<>N'@MaxTargetDataZeichen'
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.warnings[0].parameterValue')),-1)<>5
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.warnings[0].largestRequiredCharacters')),-1)
              <>(SELECT MAX([TargetDataCharacters]) FROM [#ExampleXeTargetExport]))
            THROW 55984,N'Die gemeinsame XE-Target-Kürzungswarning fehlt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleXeTargetExport] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.targets'));
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
            THROW 55985,N'Die typisierte XE-Target-TABLE-/JSON-Parität fehlt.',1;
        DROP TABLE [#ExampleXeTargetExport]; SET @Case+=1;
    END;
END TRY
BEGIN CATCH
    IF @SecondCreated=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Second)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    IF @FirstCreated=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@First)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    EXEC(@RestoreLockTimeout); THROW;
END CATCH;
IF @SecondCreated=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Second)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
IF @FirstCreated=1 BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@First)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; END;
EXEC(@RestoreLockTimeout);
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name] IN(@First,@Second))
    THROW 55986,N'Die eigenen XE-Sessions wurden nicht entfernt.',1;
GO
