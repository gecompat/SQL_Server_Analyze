USE [DeineDatenbank];
GO
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
-- Die Fixture erstellt ausschließlich eigene synthetische Sessions ohne Target.
DECLARE @Prefix sysname=N'ExampleWi0005_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @Run sysname,@Stop sysname,@Unlimited sysname,@Auto sysname,@Name sysname,@Sql nvarchar(max),
    @Names nvarchar(max),@SelectedNames nvarchar(max),@Pattern nvarchar(4000),@Json nvarchar(max),@Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
    @Case int=0,@Runtime bit,@OnlyRunning bit,@Limit int,@Enabled bit,@Expected int,
    @BeforeStart datetime,@AfterStart datetime,@NativeDuration bigint,@ExpectedJson nvarchar(max),@ClockKnown bit=0,
    @NativeBeforeJson nvarchar(max),@NativeAfterJson nvarchar(max),@RestartPreviousJson nvarchar(max),@GuardJson nvarchar(max),
    @SourceStable bit,@RestartAfterStart datetime,
    @RestoreLock nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
SELECT @Run=@Prefix+N'_A',@Stop=@Prefix+N'_B',@Unlimited=@Prefix+N'_C',@Auto=@Prefix+N'_D';
DECLARE @Owned TABLE([Name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[Created] bit NOT NULL);
INSERT @Owned VALUES(@Run,0),(@Stop,0),(@Unlimited,0),(@Auto,0);
DECLARE @NativeSnapshot TABLE
(
    [Phase] varchar(6) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EventSessionId] int NOT NULL,[SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RuntimeAddress] varbinary(8) NULL,[NativeCreateTime] datetime NULL,[NativeCreateTimeBytes] varbinary(8) NULL,
    [NativeCreateTimeType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    PRIMARY KEY([Phase],[SessionName])
);
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] AS [s] JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 56000,N'WI-0005: Eigene Sessionnamen sind bereits vorhanden.',1;
BEGIN TRY
    IF @Major>=17
        EXEC [sys].[sp_executesql] N'SELECT @Known=CONVERT(bit,CASE WHEN CURRENT_TIMEZONE_ID() COLLATE SQL_Latin1_General_CP1_CS_AS=''UTC'' AND DATEPART(TZOFFSET,SYSDATETIMEOFFSET())=0 THEN 1 ELSE 0 END);',N'@Known bit OUTPUT',@Known=@ClockKnown OUTPUT;
    DECLARE [Wi0005Create] CURSOR LOCAL FAST_FORWARD FOR SELECT [Name] FROM @Owned ORDER BY [Name];
    OPEN [Wi0005Create]; FETCH NEXT FROM [Wi0005Create] INTO @Name;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'CREATE EVENT SESSION '+QUOTENAME(@Name)+N' ON SERVER ADD EVENT [sqlserver].[error_reported](WHERE([error_number]=(50000))) WITH(STARTUP_STATE=OFF'+
            CASE WHEN @Major>=17 THEN CASE WHEN @Name=@Unlimited THEN N',MAX_DURATION=UNLIMITED' WHEN @Name=@Auto THEN N',MAX_DURATION=2 SECONDS' ELSE N',MAX_DURATION=120 SECONDS' END ELSE N'' END+N');';
        EXEC [master].[sys].[sp_executesql] @Sql;
        UPDATE @Owned SET [Created]=1 WHERE [Name]=@Name;
        FETCH NEXT FROM [Wi0005Create] INTO @Name;
    END;
    CLOSE [Wi0005Create]; DEALLOCATE [Wi0005Create];
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Run)+N' ON SERVER STATE=START; ALTER EVENT SESSION '+QUOTENAME(@Unlimited)+N' ON SERVER STATE=START;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Names=QUOTENAME(@Run)+N'|'+QUOTENAME(@Stop)+N'|'+QUOTENAME(@Unlimited);
    WHILE @Case<11
    BEGIN
        SELECT @Enabled=CASE WHEN @Case=0 THEN 0 ELSE 1 END,
            @Runtime=CASE WHEN @Case IN(2,5) THEN 0 ELSE 1 END,
            @OnlyRunning=CASE WHEN @Case=10 THEN NULL WHEN @Case IN(3,5,9) THEN 1 ELSE 0 END,
            @Limit=CASE WHEN @Case IN(4,9) THEN 1 WHEN @Case=6 THEN NULL WHEN @Case=8 THEN -1 ELSE 0 END,
            @Expected=CASE WHEN @Case IN(5,8) THEN 0 WHEN @Case IN(4,9) THEN 1 WHEN @Case IN(3,10) THEN 2 ELSE 3 END;
        SELECT @SelectedNames=CASE WHEN @Case=7 THEN NULL ELSE @Names END,
            @Pattern=CASE WHEN @Case=7 THEN N'like:'+REPLACE(@Prefix,N'_',N'[_]')+N'[_][ABC]' ELSE NULL END;
        CREATE TABLE [#Wi0005TimeBoundsRuntimeContract_Sessions]([Dummy] int NULL);
        CREATE TABLE [#Wi0005TimeBoundsRuntimeContract_Bounds]([Dummy] int NULL);
        CREATE TABLE [#Wi0005TimeBoundsRuntimeContract_GuardValues]
        (
            [SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ConsumerEventSessionId] int NOT NULL,[ConsumerStart] datetime NULL,
            [NativeEventSessionId] int NULL,[NativeRuntimeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [NativeRuntimeAddress] varbinary(8) NULL,[NativeStart] datetime NULL,[NativeStartBytes] varbinary(8) NULL,
            [CatalogMissing] bit NOT NULL,[RuntimeOrStartMissing] bit NOT NULL,[RuntimeBindingMismatch] bit NOT NULL,
            [StartOutsideBoundedComparison] bit NOT NULL
        );
        DELETE @NativeSnapshot;
        INSERT @NativeSnapshot
        SELECT 'BEFORE',[s].[event_session_id],[s].[name],[r].[address],[r].[create_time],
                CONVERT(varbinary(8),[r].[create_time]),
                CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(CONVERT(sql_variant,[r].[create_time]),N'BaseType'))
            FROM [sys].[server_event_sessions] AS [s]
            INNER JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [o].[Created]=1
            LEFT JOIN [sys].[dm_xe_sessions] AS [r] ON [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
            WHERE [s].[name] IN(@Run,@Stop,@Unlimited);
        SET @NativeBeforeJson=(SELECT [EventSessionId],[SessionName],[RuntimeAddress],[NativeCreateTime],[NativeCreateTimeBytes],[NativeCreateTimeType]
            FROM @NativeSnapshot WHERE [Phase]='BEFORE' ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @BeforeStart=[NativeCreateTime] FROM @NativeSnapshot WHERE [Phase]='BEFORE' AND [SessionName]=@Run;
        EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@SelectedNames,@ExtendedEventSessionNamePattern=@Pattern,
            @NurLaufend=@OnlyRunning,@MitLaufzeitstatus=@Runtime,@MitZeitgrenzen=@Enabled,
            @MitEvents=0,@MitActions=0,@MitTargets=0,@MaxZeilen=@Limit,
            @ResultSetArt='TABLE',@ResultTablesJson=N'{"sessions":"#Wi0005TimeBoundsRuntimeContract_Sessions","timeBounds":"#Wi0005TimeBoundsRuntimeContract_Bounds"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        INSERT @NativeSnapshot
        SELECT 'AFTER',[s].[event_session_id],[s].[name],[r].[address],[r].[create_time],
                CONVERT(varbinary(8),[r].[create_time]),
                CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(CONVERT(sql_variant,[r].[create_time]),N'BaseType'))
            FROM [sys].[server_event_sessions] AS [s]
            INNER JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [o].[Created]=1
            LEFT JOIN [sys].[dm_xe_sessions] AS [r] ON [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
            WHERE [s].[name] IN(@Run,@Stop,@Unlimited);
        SET @NativeAfterJson=(SELECT [EventSessionId],[SessionName],[RuntimeAddress],[NativeCreateTime],[NativeCreateTimeBytes],[NativeCreateTimeType]
            FROM @NativeSnapshot WHERE [Phase]='AFTER' ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @AfterStart=[NativeCreateTime] FROM @NativeSnapshot WHERE [Phase]='AFTER' AND [SessionName]=@Run;
        SET @SourceStable=CONVERT(bit,CASE WHEN (SELECT COUNT(*) FROM @NativeSnapshot WHERE [Phase]='BEFORE')<>3
            OR (SELECT COUNT(*) FROM @NativeSnapshot WHERE [Phase]='AFTER')<>3
            OR EXISTS(SELECT 1 FROM @NativeSnapshot AS [b]
                LEFT JOIN @NativeSnapshot AS [a] ON [a].[Phase]='AFTER' AND [a].[SessionName]=[b].[SessionName]
                WHERE [b].[Phase]='BEFORE' AND ([a].[EventSessionId] IS NULL OR [a].[EventSessionId]<>[b].[EventSessionId]
                    OR ([b].[SessionName]=@Stop AND ([b].[RuntimeAddress] IS NOT NULL OR [a].[RuntimeAddress] IS NOT NULL
                        OR [b].[NativeCreateTime] IS NOT NULL OR [a].[NativeCreateTime] IS NOT NULL))
                    OR ([b].[SessionName]<>@Stop AND ([b].[RuntimeAddress] IS NULL OR [a].[RuntimeAddress] IS NULL
                        OR [b].[RuntimeAddress]<>[a].[RuntimeAddress] OR [b].[NativeCreateTime] IS NULL OR [a].[NativeCreateTime] IS NULL
                        OR ABS(DATEDIFF_BIG(MILLISECOND,[b].[NativeCreateTime],[a].[NativeCreateTime]))>10))))
            THEN 0 ELSE 1 END);
        SET @ExpectedJson=(SELECT * FROM [#Wi0005TimeBoundsRuntimeContract_Bounds] ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        INSERT [#Wi0005TimeBoundsRuntimeContract_GuardValues]
        SELECT [b].[SessionName],[b].[EventSessionId],[b].[RunningSince],[s].[event_session_id],
            [r].[name],[r].[address],[r].[create_time],CONVERT(varbinary(8),[r].[create_time]),
            CONVERT(bit,CASE WHEN [s].[event_session_id]=[b].[EventSessionId]
                AND [s].[event_session_id]=[p].[EventSessionId] AND [s].[event_session_id]=[a].[EventSessionId] THEN 0 ELSE 1 END),
            CONVERT(bit,CASE WHEN @Runtime=1 AND [b].[SessionName]<>@Stop AND ([b].[RunningSince] IS NULL OR [r].[name] IS NULL) THEN 1 ELSE 0 END),
            CONVERT(bit,CASE WHEN @Runtime=1 AND [b].[SessionName]<>@Stop
                AND ([r].[address] IS NULL OR [p].[RuntimeAddress] IS NULL OR [a].[RuntimeAddress] IS NULL
                    OR [r].[address]<>[p].[RuntimeAddress] OR [r].[address]<>[a].[RuntimeAddress]) THEN 1 ELSE 0 END),
            CONVERT(bit,CASE WHEN @Runtime=1 AND [b].[SessionName]<>@Stop
                AND ([b].[RunningSince] IS NULL OR [r].[create_time] IS NULL OR [p].[NativeCreateTime] IS NULL OR [a].[NativeCreateTime] IS NULL
                    OR ABS(DATEDIFF_BIG(MILLISECOND,[r].[create_time],[b].[RunningSince]))>10
                    OR ABS(DATEDIFF_BIG(MILLISECOND,[r].[create_time],[p].[NativeCreateTime]))>10
                    OR ABS(DATEDIFF_BIG(MILLISECOND,[r].[create_time],[a].[NativeCreateTime]))>10
                    OR ABS(DATEDIFF_BIG(MILLISECOND,[p].[NativeCreateTime],[b].[RunningSince]))>10
                    OR ABS(DATEDIFF_BIG(MILLISECOND,[a].[NativeCreateTime],[b].[RunningSince]))>10) THEN 1 ELSE 0 END)
        FROM [#Wi0005TimeBoundsRuntimeContract_Bounds] AS [b]
        LEFT JOIN [sys].[server_event_sessions] AS [s] ON [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[b].[SessionName]
        LEFT JOIN [sys].[dm_xe_sessions] AS [r] ON [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[b].[SessionName]
        LEFT JOIN @NativeSnapshot AS [p] ON [p].[Phase]='BEFORE' AND [p].[SessionName]=[b].[SessionName]
        LEFT JOIN @NativeSnapshot AS [a] ON [a].[Phase]='AFTER' AND [a].[SessionName]=[b].[SessionName];
        SET @GuardJson=(SELECT * FROM [#Wi0005TimeBoundsRuntimeContract_GuardValues] ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        -- Vor jedem fachlichen Guard werden Consumer und eigene native Quellen ausgegeben.
        -- Der private Captureclient behält diese Zeile auch bei einer nachfolgenden SQL-Assertion.
        SELECT N'BEFORE_ASSERTION' AS [FrameType],@Case AS [CaseNumber],@Json AS [ConsumerJson],@ExpectedJson AS [TableJson],
            @BeforeStart AS [BeforeStart],@AfterStart AS [AfterStart],
            @NativeBeforeJson AS [NativeBeforeJson],@NativeAfterJson AS [NativeAfterJson],@GuardJson AS [GuardValuesJson],@SourceStable AS [SourceStable];
        IF @SourceStable=0
            THROW 56001,N'WI-0005: Native Quellenklammer verletzt Identität, Runtimebindung oder begrenzten Zeitvergleich.',1;
        IF (SELECT COUNT(*) FROM [#Wi0005TimeBoundsRuntimeContract_Sessions])<>@Expected
            OR (SELECT COUNT(*) FROM [#Wi0005TimeBoundsRuntimeContract_Bounds])<>CASE WHEN @Enabled=1 THEN @Expected ELSE 0 END
            OR COALESCE(JSON_VALUE(@Json,N'$.meta.schemaVersion'),N'')<>CASE WHEN @Enabled=1 THEN N'2' ELSE N'1' END
            OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>CASE WHEN @Case=8 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END
            OR (@Enabled=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'timeBounds'))
            OR (@Enabled=1 AND JSON_QUERY(@Json,N'$.timeBounds') IS NULL)
            THROW 56002,N'WI-0005: Default-, Auswahl-, Schema- oder Statusvertrag verletzt.',1;
        IF @Enabled=1 AND COALESCE(@ExpectedJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.timeBounds') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56003,N'WI-0005: Gleichaufrufbezogene physische TABLE-/JSON-Parität fehlt.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Wi0005TimeBoundsRuntimeContract_Bounds'))<>12
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Wi0005TimeBoundsRuntimeContract_Bounds')
                AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56004,N'WI-0005: Natives Exportschema oder Textcollation verändert.',1;
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_Bounds] AS [b]
            WHERE [SourceStatus]<>CASE WHEN @Major>=17 THEN 'AVAILABLE' ELSE 'UNAVAILABLE_VERSION' END
                OR [ErrorNumber] IS NOT NULL OR [ErrorMessage] IS NOT NULL
                OR [RuntimeState]<>CASE WHEN @Runtime=0 THEN 'NOT_COLLECTED' WHEN [SessionName]=@Stop THEN 'STOPPED' ELSE 'RUNNING' END
                OR (@Runtime=0 AND ([RunningSince] IS NOT NULL OR [RemainingSecondsEstimate] IS NOT NULL))
                OR (([SessionName] IN(@Stop,@Unlimited) OR @Major<17) AND [RemainingSecondsEstimate] IS NOT NULL)
                OR (@Major<17 AND ([MaxDurationSeconds] IS NOT NULL OR [IsTimeBound] IS NOT NULL)))
            THROW 56005,N'WI-0005: Runtime-, Unbegrenzt- oder Versionsfallback fehlerhaft.',1;
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_GuardValues] WHERE [CatalogMissing]=1)
            THROW 56012,N'WI-0005: Native Katalogidentität fehlt.',1;
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_GuardValues] WHERE [RuntimeOrStartMissing]=1)
            THROW 56013,N'WI-0005: Runtimezeile oder Consumerstartzeit fehlt.',1;
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_GuardValues] WHERE [RuntimeBindingMismatch]=1)
            THROW 56015,N'WI-0005: Runtimeadresse weicht von den gebundenen Quellenklammern ab.',1;
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_GuardValues] WHERE [StartOutsideBoundedComparison]=1)
            THROW 56014,N'WI-0005: Consumerstartzeit liegt außerhalb des begrenzten nativen Zeitvergleichs.',1;
        IF @Major>=17
        BEGIN
            SET @Sql=N'SELECT @Duration=[max_duration] FROM [sys].[server_event_sessions] WHERE [name]=@Name;';
            EXEC [sys].[sp_executesql] @Sql,N'@Name sysname,@Duration bigint OUTPUT',@Name=@Run,@Duration=@NativeDuration OUTPUT;
            IF @NativeDuration IS NULL OR @NativeDuration<>120 OR EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_Bounds]
                WHERE [MaxDurationSeconds] IS NULL OR [IsTimeBound] IS NULL
                   OR [MaxDurationSeconds]<>CASE WHEN [SessionName]=@Unlimited THEN 0 ELSE @NativeDuration END
                   OR [IsTimeBound]<>CASE WHEN [SessionName]=@Unlimited THEN 0 ELSE 1 END
                   OR ([SessionName]=@Run AND @Runtime=1 AND ([RunningSince] IS NULL OR ABS(DATEDIFF_BIG(MILLISECOND,[RunningSince],@BeforeStart))>10
                       OR (@ClockKnown=1 AND ([RemainingSecondsEstimate] IS NULL OR [RemainingSecondsEstimate]<=0 OR [RemainingSecondsEstimate]>120))
                       OR (@ClockKnown=0 AND [RemainingSecondsEstimate] IS NOT NULL))))
                THROW 56006,N'WI-0005: Native Dauer oder begrenzte Schätzung falsch.',1;
        END;
        SELECT @Case AS [CaseNumber],@Json AS [ConsumerJson],@ExpectedJson AS [TableJson];
        DROP TABLE [#Wi0005TimeBoundsRuntimeContract_Sessions]; DROP TABLE [#Wi0005TimeBoundsRuntimeContract_Bounds];
        DROP TABLE [#Wi0005TimeBoundsRuntimeContract_GuardValues];
        SET @Case+=1;
    END;
    SET @RestartPreviousJson=@NativeAfterJson;
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Run)+N' ON SERVER STATE=STOP;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    WAITFOR DELAY '00:00:00.020';
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Run)+N' ON SERVER STATE=START;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    DELETE @NativeSnapshot;
    INSERT @NativeSnapshot
    SELECT 'BEFORE',[s].[event_session_id],[s].[name],[r].[address],[r].[create_time],CONVERT(varbinary(8),[r].[create_time]),
            CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(CONVERT(sql_variant,[r].[create_time]),N'BaseType'))
        FROM [sys].[server_event_sessions] AS [s]
        INNER JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [o].[Created]=1
        LEFT JOIN [sys].[dm_xe_sessions] AS [r] ON [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
        WHERE [s].[name]=@Run;
    SET @NativeBeforeJson=(SELECT [EventSessionId],[SessionName],[RuntimeAddress],[NativeCreateTime],[NativeCreateTimeBytes],[NativeCreateTimeType]
        FROM @NativeSnapshot WHERE [Phase]='BEFORE' ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
    SELECT @AfterStart=[NativeCreateTime] FROM @NativeSnapshot WHERE [Phase]='BEFORE' AND [SessionName]=@Run;
    EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@Run,@MitZeitgrenzen=1,@MitEvents=0,@MitActions=0,@MitTargets=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    INSERT @NativeSnapshot
    SELECT 'AFTER',[s].[event_session_id],[s].[name],[r].[address],[r].[create_time],CONVERT(varbinary(8),[r].[create_time]),
            CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(CONVERT(sql_variant,[r].[create_time]),N'BaseType'))
        FROM [sys].[server_event_sessions] AS [s]
        INNER JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [o].[Created]=1
        LEFT JOIN [sys].[dm_xe_sessions] AS [r] ON [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
        WHERE [s].[name]=@Run;
    SET @NativeAfterJson=(SELECT [EventSessionId],[SessionName],[RuntimeAddress],[NativeCreateTime],[NativeCreateTimeBytes],[NativeCreateTimeType]
        FROM @NativeSnapshot WHERE [Phase]='AFTER' ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
    SELECT @RestartAfterStart=[NativeCreateTime] FROM @NativeSnapshot WHERE [Phase]='AFTER' AND [SessionName]=@Run;
    SET @SourceStable=CONVERT(bit,CASE WHEN (SELECT COUNT(*) FROM @NativeSnapshot WHERE [Phase]='BEFORE')<>1
        OR (SELECT COUNT(*) FROM @NativeSnapshot WHERE [Phase]='AFTER')<>1
        OR EXISTS(SELECT 1 FROM @NativeSnapshot AS [b]
            LEFT JOIN @NativeSnapshot AS [a] ON [a].[Phase]='AFTER' AND [a].[SessionName]=[b].[SessionName]
            WHERE [b].[Phase]='BEFORE' AND ([a].[EventSessionId] IS NULL OR [a].[EventSessionId]<>[b].[EventSessionId]
                OR [b].[RuntimeAddress] IS NULL OR [a].[RuntimeAddress] IS NULL OR [b].[RuntimeAddress]<>[a].[RuntimeAddress]
                OR [b].[NativeCreateTime] IS NULL OR [a].[NativeCreateTime] IS NULL
                OR ABS(DATEDIFF_BIG(MILLISECOND,[b].[NativeCreateTime],[a].[NativeCreateTime]))>10))
        THEN 0 ELSE 1 END);
    SELECT N'RESTART_BEFORE_ASSERTION' AS [FrameType],@Json AS [ConsumerJson],@BeforeStart AS [PreviousStart],@AfterStart AS [RestartStart],
        @RestartAfterStart AS [RestartAfterStart],@RestartPreviousJson AS [PreviousNativeJson],@NativeBeforeJson AS [NativeBeforeJson],@NativeAfterJson AS [NativeAfterJson],@SourceStable AS [SourceStable];
    IF @SourceStable=0 OR @AfterStart IS NULL OR @AfterStart<=@BeforeStart
        OR TRY_CONVERT(datetime,JSON_VALUE(@Json,N'$.timeBounds[0].RunningSince')) IS NULL
        OR ABS(DATEDIFF_BIG(MILLISECOND,TRY_CONVERT(datetime,JSON_VALUE(@Json,N'$.timeBounds[0].RunningSince')),@AfterStart))>10
        OR ABS(DATEDIFF_BIG(MILLISECOND,TRY_CONVERT(datetime,JSON_VALUE(@Json,N'$.timeBounds[0].RunningSince')),@RestartAfterStart))>10
        THROW 56007,N'WI-0005: Neuer nativer Startwert wird nicht übernommen.',1;
    IF @Major>=17
    BEGIN
        SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Auto)+N' ON SERVER STATE=START;'; EXEC [master].[sys].[sp_executesql] @Sql;
        IF NOT EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] WHERE [name]=@Auto) THROW 56008,N'WI-0005: Eigene endliche Session lief nicht.',1;
        DECLARE @Poll int=0;
        WHILE @Poll<15 AND EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] WHERE [name]=@Auto)
        BEGIN WAITFOR DELAY '00:00:01'; SET @Poll+=1; END;
        IF EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] WHERE [name]=@Auto) THROW 56009,N'WI-0005: Native automatische Beendigung wurde im begrenzten Beobachtungsfenster nicht bestätigt.',1;
        EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@Auto,@MitZeitgrenzen=1,@MitEvents=0,@MitActions=0,@MitTargets=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF COALESCE(JSON_VALUE(@Json,N'$.timeBounds[0].RuntimeState'),N'')<>N'STOPPED' OR JSON_VALUE(@Json,N'$.timeBounds[0].RemainingSecondsEstimate') IS NOT NULL
            THROW 56010,N'WI-0005: Automatisch beendete Session wird falsch eingeordnet.',1;
    END;
END TRY
BEGIN CATCH
    DECLARE [Wi0005FailureCleanup] CURSOR LOCAL FAST_FORWARD FOR SELECT [Name] FROM @Owned WHERE [Created]=1;
    OPEN [Wi0005FailureCleanup]; FETCH NEXT FROM [Wi0005FailureCleanup] INTO @Name;
    WHILE @@FETCH_STATUS=0
    BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Name)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; FETCH NEXT FROM [Wi0005FailureCleanup] INTO @Name; END;
    CLOSE [Wi0005FailureCleanup]; DEALLOCATE [Wi0005FailureCleanup];
    EXEC [sys].[sp_executesql] @RestoreLock; THROW;
END CATCH;
DECLARE [Wi0005Cleanup] CURSOR LOCAL FAST_FORWARD FOR SELECT [Name] FROM @Owned WHERE [Created]=1;
OPEN [Wi0005Cleanup]; FETCH NEXT FROM [Wi0005Cleanup] INTO @Name;
WHILE @@FETCH_STATUS=0
BEGIN SET @Sql=N'DROP EVENT SESSION '+QUOTENAME(@Name)+N' ON SERVER;'; EXEC [master].[sys].[sp_executesql] @Sql; FETCH NEXT FROM [Wi0005Cleanup] INTO @Name; END;
CLOSE [Wi0005Cleanup]; DEALLOCATE [Wi0005Cleanup];
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] AS [s] JOIN @Owned AS [o] ON [o].[Name]=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
    OR EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] AS [r] JOIN @Owned AS [o] ON [o].[Name]=[r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 56011,N'WI-0005: Eigene Sessionquelle bleibt nach Cleanup vorhanden.',1;
EXEC [sys].[sp_executesql] @RestoreLock;
SELECT N'WI-0005' AS [WorkItem],N'PASS' AS [Status],@Major AS [NativeMajorVersion],11 AS [TableJsonCases],@ClockKnown AS [FixedUtcClockQualified];
GO
