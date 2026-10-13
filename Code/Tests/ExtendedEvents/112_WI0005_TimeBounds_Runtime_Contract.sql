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
    @RestoreLock nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
SELECT @Run=@Prefix+N'_A',@Stop=@Prefix+N'_B',@Unlimited=@Prefix+N'_C',@Auto=@Prefix+N'_D';
DECLARE @Owned TABLE([Name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[Created] bit NOT NULL);
INSERT @Owned VALUES(@Run,0),(@Stop,0),(@Unlimited,0),(@Auto,0);
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
        SELECT @BeforeStart=[create_time] FROM [sys].[dm_xe_sessions] WHERE [name]=@Run;
        EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@SelectedNames,@ExtendedEventSessionNamePattern=@Pattern,
            @NurLaufend=@OnlyRunning,@MitLaufzeitstatus=@Runtime,@MitZeitgrenzen=@Enabled,
            @MitEvents=0,@MitActions=0,@MitTargets=0,@MaxZeilen=@Limit,
            @ResultSetArt='TABLE',@ResultTablesJson=N'{"sessions":"#Wi0005TimeBoundsRuntimeContract_Sessions","timeBounds":"#Wi0005TimeBoundsRuntimeContract_Bounds"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SELECT @AfterStart=[create_time] FROM [sys].[dm_xe_sessions] WHERE [name]=@Run;
        IF @BeforeStart IS NULL OR @AfterStart IS NULL OR @BeforeStart<>@AfterStart
            THROW 56001,N'WI-0005: Analyzer hat die eigene laufende Quelle verändert.',1;
        IF (SELECT COUNT(*) FROM [#Wi0005TimeBoundsRuntimeContract_Sessions])<>@Expected
            OR (SELECT COUNT(*) FROM [#Wi0005TimeBoundsRuntimeContract_Bounds])<>CASE WHEN @Enabled=1 THEN @Expected ELSE 0 END
            OR COALESCE(JSON_VALUE(@Json,N'$.meta.schemaVersion'),N'')<>CASE WHEN @Enabled=1 THEN N'2' ELSE N'1' END
            OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>CASE WHEN @Case=8 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END
            OR (@Enabled=0 AND EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'timeBounds'))
            OR (@Enabled=1 AND JSON_QUERY(@Json,N'$.timeBounds') IS NULL)
            THROW 56002,N'WI-0005: Default-, Auswahl-, Schema- oder Statusvertrag verletzt.',1;
        SET @ExpectedJson=(SELECT * FROM [#Wi0005TimeBoundsRuntimeContract_Bounds] ORDER BY [SessionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
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
        IF EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_Bounds] AS [b]
            WHERE NOT EXISTS(SELECT 1 FROM [sys].[server_event_sessions] AS [s] WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[b].[SessionName] AND [s].[event_session_id]=[b].[EventSessionId])
               OR (@Runtime=1 AND [b].[SessionName]<>@Stop AND ([b].[RunningSince] IS NULL OR NOT EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] AS [r] WHERE [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[b].[SessionName] AND [r].[create_time]=[b].[RunningSince]))))
            THROW 56012,N'WI-0005: Native Sessionidentität oder Startzeit fehlt.',1;
        IF @Major>=17
        BEGIN
            SET @Sql=N'SELECT @Duration=[max_duration] FROM [sys].[server_event_sessions] WHERE [name]=@Name;';
            EXEC [sys].[sp_executesql] @Sql,N'@Name sysname,@Duration bigint OUTPUT',@Name=@Run,@Duration=@NativeDuration OUTPUT;
            IF @NativeDuration IS NULL OR @NativeDuration<>120 OR EXISTS(SELECT 1 FROM [#Wi0005TimeBoundsRuntimeContract_Bounds]
                WHERE [MaxDurationSeconds] IS NULL OR [IsTimeBound] IS NULL
                   OR [MaxDurationSeconds]<>CASE WHEN [SessionName]=@Unlimited THEN 0 ELSE @NativeDuration END
                   OR [IsTimeBound]<>CASE WHEN [SessionName]=@Unlimited THEN 0 ELSE 1 END
                   OR ([SessionName]=@Run AND @Runtime=1 AND ([RunningSince] IS NULL OR [RunningSince]<>@BeforeStart
                       OR (@ClockKnown=1 AND ([RemainingSecondsEstimate] IS NULL OR [RemainingSecondsEstimate]<=0 OR [RemainingSecondsEstimate]>120))
                       OR (@ClockKnown=0 AND [RemainingSecondsEstimate] IS NOT NULL))))
                THROW 56006,N'WI-0005: Native Dauer oder begrenzte Schätzung falsch.',1;
        END;
        SELECT @Case AS [CaseNumber],@Json AS [ConsumerJson],@ExpectedJson AS [TableJson];
        DROP TABLE [#Wi0005TimeBoundsRuntimeContract_Sessions]; DROP TABLE [#Wi0005TimeBoundsRuntimeContract_Bounds];
        SET @Case+=1;
    END;
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Run)+N' ON SERVER STATE=STOP;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    WAITFOR DELAY '00:00:00.020';
    SET @Sql=N'ALTER EVENT SESSION '+QUOTENAME(@Run)+N' ON SERVER STATE=START;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SELECT @AfterStart=[create_time] FROM [sys].[dm_xe_sessions] WHERE [name]=@Run;
    EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=@Run,@MitZeitgrenzen=1,@MitEvents=0,@MitActions=0,@MitTargets=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF @AfterStart IS NULL OR @AfterStart<=@BeforeStart
        OR TRY_CONVERT(datetime,JSON_VALUE(@Json,N'$.timeBounds[0].RunningSince')) IS NULL
        OR TRY_CONVERT(datetime,JSON_VALUE(@Json,N'$.timeBounds[0].RunningSince'))<>@AfterStart
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
