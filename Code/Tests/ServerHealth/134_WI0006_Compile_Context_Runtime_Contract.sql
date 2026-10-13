USE [DeineDatenbank];
GO
SET NOCOUNT ON;
DECLARE @OwnA sysname=N'ExampleCompileA_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @OwnB sysname=N'ExampleCompileB_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @MadeA bit=0,@MadeB bit=0,@Sql nvarchar(max),@Names nvarchar(max),@Json nvarchar(max),@Expected nvarchar(max),
    @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),@Case int=0,@Status varchar(40),@Partial bit,
    @OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
    @OriginalTx int=@@TRANCOUNT,@Restore nvarchar(100),@Sample tinyint,@Limit int,@Enable bit;
IF @OriginalTx<>0 THROW 56860,N'WI-0006: Own database fixture requires no ambient transaction.',1;
SET @Restore=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
BEGIN TRY
    IF DB_ID(@OwnA) IS NOT NULL OR DB_ID(@OwnB) IS NOT NULL THROW 56861,N'WI-0006: Own database collision.',1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@OwnA)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';EXEC [sys].[sp_executesql] @Sql;SET @MadeA=1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@OwnB)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';EXEC [sys].[sp_executesql] @Sql;SET @MadeB=1;
    SET @Names=QUOTENAME(@OwnA)+N'|'+QUOTENAME(@OwnB);
    IF @Major>=17
    BEGIN
        SET @Sql=N'EXEC '+QUOTENAME(@OwnA)+N'.[sys].[sp_executesql] N''ALTER DATABASE SCOPED CONFIGURATION SET OPTIMIZED_SP_EXECUTESQL=OFF;'';';EXEC [sys].[sp_executesql] @Sql;
        SET @Sql=N'EXEC '+QUOTENAME(@OwnB)+N'.[sys].[sp_executesql] N''ALTER DATABASE SCOPED CONFIGURATION SET OPTIMIZED_SP_EXECUTESQL=ON;'';';EXEC [sys].[sp_executesql] @Sql;
    END;
    WHILE @Case<4
    BEGIN
        SELECT @Sample=CASE WHEN @Case=1 THEN 1 ELSE 0 END,@Limit=CASE WHEN @Case=2 THEN 1 WHEN @Case=3 THEN NULL ELSE 2000 END;
        SET LOCK_TIMEOUT 37;
        IF @Case%2=0 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        CREATE TABLE [#ExampleCompile_moduleStatus]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_configurations]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_counters]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_waits]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_cache]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_sourceStatus]([Seed] int NULL);
        CREATE TABLE [#ExampleCompile_warnings]([Seed] int NULL);
        EXEC [monitor].[USP_CompileContextAnalysis] @DatabaseNames=@Names,@SampleSeconds=@Sample,@MaxZeilen=@Limit,
            @ResultSetArt='TABLE',@ResultTablesJson=N'{"moduleStatus":"#ExampleCompile_moduleStatus","configurations":"#ExampleCompile_configurations","counters":"#ExampleCompile_counters","waits":"#ExampleCompile_waits","cache":"#ExampleCompile_cache","sourceStatus":"#ExampleCompile_sourceStatus","warnings":"#ExampleCompile_warnings"}',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        SELECT N'BEFORE_ASSERTION' [FrameType],@Case [CaseNumber],@Json [ConsumerJson],@Status [StatusCode],@Partial [IsPartial],@@LOCK_TIMEOUT [CallerLockTimeout],@@TRANCOUNT [CallerTranCount],@@OPTIONS [CallerOptions];
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE' OR @Partial<>0 OR @@LOCK_TIMEOUT<>37 OR @@TRANCOUNT<>0
            OR CONVERT(bit,CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END)<>CASE WHEN @Case%2=0 THEN 1 ELSE 0 END
            THROW 56862,N'WI-0006: Status JSON or caller restoration mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'moduleStatus' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.moduleStatus') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.moduleStatus'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_moduleStatus'))<>9
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_moduleStatus') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_moduleStatus])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_configurations] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'configurations' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.configurations') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.configurations'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_configurations'))<>11
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_configurations') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_configurations])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_counters] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'counters' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.counters') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.counters'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_counters'))<>16
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_counters') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_counters])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_waits] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'waits' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.waits') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.waits'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_waits'))<>16
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_waits') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_waits])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_cache] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'cache' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.cache') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.cache'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_cache'))<>6
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_cache') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_cache])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_sourceStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'sourceStatus' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.sourceStatus') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.sourceStatus'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_sourceStatus'))<>11
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_sourceStatus') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_sourceStatus])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        SET @Expected=(SELECT * FROM [#ExampleCompile_warnings] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SELECT @Case [CaseNumber],N'warnings' [ResultName],@Expected [PhysicalTableJson],JSON_QUERY(@Json,N'$.warnings') [ConsumerArray] ;
        IF ISNULL(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL(JSON_QUERY(@Json,N'$.warnings'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56863,N'WI-0006: Same-call physical TABLE JSON parity mismatch.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_warnings'))<>4
            OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCompile_warnings') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56864,N'WI-0006: Native column count or collation mismatch.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleCompile_warnings])>1 THROW 56865,N'WI-0006: Output limit mismatch.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleCompile_configurations] WHERE [ConfigurationName]<>N'OPTIMIZED_SP_EXECUTESQL'
            OR (@Major<17 AND ([CapabilityStatus]<>'UNAVAILABLE_VERSION' OR [SourceStatus]<>'UNAVAILABLE_VERSION' OR [Enabled] IS NOT NULL OR [ValueForSecondary] IS NOT NULL OR [IsValueDefault] IS NOT NULL))
            OR (@Major>=17 AND ([CapabilityStatus]<>'AVAILABLE' OR [SourceStatus]<>'AVAILABLE' OR [Enabled] IS NULL OR [Enabled]<>CASE WHEN [DatabaseName]=@OwnB THEN 1 ELSE 0 END)))
            THROW 56866,N'WI-0006: Local native capability configuration mismatch.',1;
        IF (@Limit IS NULL OR @Limit<>1) AND (SELECT COUNT(*) FROM [#ExampleCompile_configurations])<>2 THROW 56867,N'WI-0006: Database selection mismatch.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleCompile_counters] WHERE [AfterValue] IS NULL OR [ResetDetected]<>0
            OR (@Sample=0 AND ([BeforeValue] IS NOT NULL OR [DeltaValue] IS NOT NULL OR [RatePerSecond] IS NOT NULL OR [SampleStartUtc] IS NOT NULL OR [ElapsedSeconds] IS NOT NULL))
            OR (@Sample=1 AND ([BeforeValue] IS NULL OR [ElapsedSeconds] IS NULL OR [ElapsedSeconds]<=0 OR [SampleStartUtc] IS NULL OR [SampleEndUtc]<=[SampleStartUtc] OR [DeltaValue] IS NULL OR [DeltaValue]<>[AfterValue]-[BeforeValue]
                OR ([CounterType] IN(272696320,272696576) AND ([RatePerSecond] IS NULL OR ABS([RatePerSecond]-CONVERT(decimal(38,6),[AfterValue]-[BeforeValue])/[ElapsedSeconds])>0.000001)))))
            THROW 56868,N'WI-0006: Snapshot or sampled counter arithmetic mismatch.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleCompile_waits] WHERE [WaitType]<>N'RESOURCE_SEMAPHORE_QUERY_COMPILE' OR [ResetDetected]<>0
            OR (@Sample=0 AND ([BeforeWaitingTasksCount] IS NOT NULL OR [DeltaWaitingTasksCount] IS NOT NULL OR [DeltaWaitTimeMs] IS NOT NULL OR [DeltaSignalWaitTimeMs] IS NOT NULL OR [SampleStartUtc] IS NOT NULL OR [ElapsedSeconds] IS NOT NULL))
            OR (@Sample=1 AND ([BeforeWaitingTasksCount] IS NULL OR [BeforeWaitTimeMs] IS NULL OR [BeforeSignalWaitTimeMs] IS NULL OR [ElapsedSeconds] IS NULL OR [ElapsedSeconds]<=0
                OR [DeltaWaitingTasksCount] IS NULL OR [DeltaWaitingTasksCount]<>[AfterWaitingTasksCount]-[BeforeWaitingTasksCount] OR [DeltaWaitTimeMs] IS NULL OR [DeltaWaitTimeMs]<>[AfterWaitTimeMs]-[BeforeWaitTimeMs]
                OR [DeltaSignalWaitTimeMs] IS NULL OR [DeltaSignalWaitTimeMs]<>[AfterSignalWaitTimeMs]-[BeforeSignalWaitTimeMs])))
            THROW 56869,N'WI-0006: Snapshot or sampled wait arithmetic mismatch.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleCompile_cache] WHERE [CacheType] NOT IN(N'CACHESTORE_SQLCP',N'CACHESTORE_OBJCP') OR [EntriesCount] IS NULL OR [PagesKb] IS NULL OR [EntriesCount]<0 OR [PagesKb]<0)
            THROW 56870,N'WI-0006: Native cache aggregate shape mismatch.',1;
        DROP TABLE [#ExampleCompile_moduleStatus];
        DROP TABLE [#ExampleCompile_configurations];
        DROP TABLE [#ExampleCompile_counters];
        DROP TABLE [#ExampleCompile_waits];
        DROP TABLE [#ExampleCompile_cache];
        DROP TABLE [#ExampleCompile_sourceStatus];
        DROP TABLE [#ExampleCompile_warnings];
        SET @Case+=1;
    END;
    SET LOCK_TIMEOUT 5000;
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnA)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeA=0;
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnB)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeB=0;
    IF DB_ID(@OwnA) IS NOT NULL OR DB_ID(@OwnB) IS NOT NULL THROW 56871,N'WI-0006: Own database cleanup incomplete.',1;
    EXEC [sys].[sp_executesql] @Restore;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
END TRY
BEGIN CATCH
    DECLARE @OriginalError int=ERROR_NUMBER(),@OriginalMessage nvarchar(2048)=ERROR_MESSAGE();
    SELECT N'FAILURE_BEFORE_CLEANUP' [FrameType],@Case [CaseNumber],@Json [ConsumerJson],@OriginalError [ErrorNumber],@OriginalMessage [ErrorMessage];
    BEGIN TRY
        IF @MadeA=1 BEGIN SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnA)+N';';EXEC [sys].[sp_executesql] @Sql; END;
        IF @MadeB=1 BEGIN SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnB)+N';';EXEC [sys].[sp_executesql] @Sql; END;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_CLEANUP_FAILURE' [FrameType],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    EXEC [sys].[sp_executesql] @Restore;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
SELECT N'WI-0006' [WorkItem],N'PASS' [Status],@Major [NativeMajorVersion],4 [TableJsonCases],1 [ActualSampleCases];
GO

-- These deterministic synthetic rows test the installed guard projection.
-- They do not represent actual server resets, waits or compile activity.
SET NOCOUNT ON;
DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_CompileContextAnalysis')),
    @Start int,@End int,@CounterProjection nvarchar(max),@WaitProjection nvarchar(max),@Sql nvarchar(max),
    @SampleSeconds tinyint=1,@ServerComparable bit=1,@ServerReset bit=0,
    @CounterElapsed decimal(19,6)=2,@WaitElapsed decimal(19,6)=2,
    @CounterStart datetime2(7)='2024-01-01T00:00:00',@CounterEnd datetime2(7)='2024-01-01T00:00:02',
    @WaitStart datetime2(7)='2024-01-01T00:00:00',@WaitEnd datetime2(7)='2024-01-01T00:00:02',
    @ServerStartAfter datetime2(3)='2024-01-01T00:00:00',@CounterLimit nvarchar(1000)=N'Synthetic guard probe.',@WaitLimit nvarchar(1000)=N'Synthetic guard probe.';
IF @Definition IS NULL THROW 56872,N'WI-0006: Installed producer definition missing.',1;
SET @Start=CHARINDEX(N'INSERT [#CompileContextAnalysis_counters]',@Definition);
SET @End=CHARINDEX(N'INSERT [#CompileContextAnalysis_waits]',@Definition,@Start+1);
IF @Start=0 OR @End<=@Start THROW 56873,N'WI-0006: Counter projection binding missing.',1;
SET @CounterProjection=SUBSTRING(@Definition,@Start,@End-@Start);
SET @Start=@End;SET @End=CHARINDEX(N'SELECT @SourceStatus=',@Definition,@Start+1);
IF @End<=@Start THROW 56874,N'WI-0006: Wait projection binding missing.',1;
SET @WaitProjection=SUBSTRING(@Definition,@Start,@End-@Start);
CREATE TABLE [#CompileContextAnalysis_CounterRaw]
([Phase] tinyint,[ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CounterType] int,[CounterValue] bigint);
CREATE TABLE [#CompileContextAnalysis_WaitRaw]
([Phase] tinyint,[WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitingTasksCount] bigint,[WaitTimeMs] bigint,[SignalWaitTimeMs] bigint);
CREATE TABLE [#CompileContextAnalysis_counters]([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CounterType] int NOT NULL , [BeforeValue] bigint NULL , [AfterValue] bigint NOT NULL , [DeltaValue] bigint NULL , [RatePerSecond] decimal(38,6) NULL , [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SampleStartUtc] datetime2(7) NULL , [SampleEndUtc] datetime2(7) NOT NULL , [ElapsedSeconds] decimal(19,6) NULL , [ResetDetected] bit NOT NULL , [SqlServerStartTime] datetime2(3) NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#CompileContextAnalysis_waits]([WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [BeforeWaitingTasksCount] bigint NULL , [AfterWaitingTasksCount] bigint NOT NULL , [DeltaWaitingTasksCount] bigint NULL , [BeforeWaitTimeMs] bigint NULL , [AfterWaitTimeMs] bigint NOT NULL , [DeltaWaitTimeMs] bigint NULL , [BeforeSignalWaitTimeMs] bigint NULL , [AfterSignalWaitTimeMs] bigint NOT NULL , [DeltaSignalWaitTimeMs] bigint NULL , [SampleStartUtc] datetime2(7) NULL , [SampleEndUtc] datetime2(7) NOT NULL , [ElapsedSeconds] decimal(19,6) NULL , [ResetDetected] bit NOT NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
DECLARE @Case int=0,@ExpectedReset bit,@ExpectedDelta bigint,@ExpectedRate decimal(38,6),@Type int,@After bigint;
WHILE @Case<10
BEGIN
    DELETE FROM [#CompileContextAnalysis_CounterRaw];DELETE FROM [#CompileContextAnalysis_counters];
    SELECT @Type=CASE WHEN @Case IN(3,4) THEN 999 WHEN @Case=9 THEN 272696576 ELSE 272696320 END,@After=CASE WHEN @Case IN(1,4) THEN 9 ELSE 14 END,
        @ServerReset=CASE WHEN @Case=2 THEN 1 ELSE 0 END,@ServerComparable=CASE WHEN @Case IN(2,8) THEN 0 ELSE 1 END,
        @SampleSeconds=CASE WHEN @Case=7 THEN 0 ELSE 1 END;
    IF @Case<>5 AND @Case<>7 INSERT [#CompileContextAnalysis_CounterRaw] VALUES(0,CASE WHEN @Case=6 THEN N'ExampleWrongObject' ELSE N'Example:SQL Statistics' END,N'SQL Compilations/sec',N'',CASE WHEN @Case=9 THEN 272696320 ELSE @Type END,10);
    INSERT [#CompileContextAnalysis_CounterRaw] VALUES(1,N'Example:SQL Statistics',N'SQL Compilations/sec',N'',@Type,@After);
    SELECT @ExpectedReset=CASE WHEN @Case IN(1,2,4) THEN 1 ELSE 0 END,@ExpectedDelta=CASE WHEN @Case=0 THEN 4 END,@ExpectedRate=CASE WHEN @Case=0 THEN 2 END;
    EXEC [sys].[sp_executesql] @CounterProjection,
        N'@SampleSeconds tinyint,@ServerComparable bit,@ServerReset bit,@CounterElapsed decimal(19,6),@CounterStart datetime2(7),@CounterEnd datetime2(7),@ServerStartAfter datetime2(3),@CounterLimit nvarchar(1000)',
        @SampleSeconds=@SampleSeconds,@ServerComparable=@ServerComparable,@ServerReset=@ServerReset,@CounterElapsed=@CounterElapsed,@CounterStart=@CounterStart,@CounterEnd=@CounterEnd,@ServerStartAfter=@ServerStartAfter,@CounterLimit=@CounterLimit;
    SELECT N'SYNTHETIC_COUNTER_BEFORE_ASSERTION' [FrameType],@Case [CaseNumber],* FROM [#CompileContextAnalysis_counters];
    IF (SELECT COUNT(*) FROM [#CompileContextAnalysis_counters])<>1 OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_counters] WHERE [ResetDetected]<>@ExpectedReset
        OR ([DeltaValue] IS NULL AND @ExpectedDelta IS NOT NULL) OR ([DeltaValue] IS NOT NULL AND @ExpectedDelta IS NULL) OR [DeltaValue]<>@ExpectedDelta
        OR ([RatePerSecond] IS NULL AND @ExpectedRate IS NOT NULL) OR ([RatePerSecond] IS NOT NULL AND @ExpectedRate IS NULL) OR [RatePerSecond]<>@ExpectedRate)
        THROW 56875,N'WI-0006: Synthetic counter guard mismatch.',1;
    SET @Case+=1;
END;
SET @Case=0;
WHILE @Case<7
BEGIN
    DELETE FROM [#CompileContextAnalysis_WaitRaw];DELETE FROM [#CompileContextAnalysis_waits];
    SELECT @ServerReset=CASE WHEN @Case=4 THEN 1 ELSE 0 END,@ServerComparable=CASE WHEN @Case IN(4,6) THEN 0 ELSE 1 END,@SampleSeconds=1;
    IF @Case<>5 INSERT [#CompileContextAnalysis_WaitRaw] VALUES(0,N'RESOURCE_SEMAPHORE_QUERY_COMPILE',10,20,5);
    INSERT [#CompileContextAnalysis_WaitRaw] VALUES(1,N'RESOURCE_SEMAPHORE_QUERY_COMPILE',CASE WHEN @Case=1 THEN 9 ELSE 13 END,CASE WHEN @Case=2 THEN 19 ELSE 28 END,CASE WHEN @Case=3 THEN 4 ELSE 8 END);
    SET @ExpectedReset=CASE WHEN @Case BETWEEN 1 AND 4 THEN 1 ELSE 0 END;
    EXEC [sys].[sp_executesql] @WaitProjection,
        N'@SampleSeconds tinyint,@ServerComparable bit,@ServerReset bit,@WaitElapsed decimal(19,6),@WaitStart datetime2(7),@WaitEnd datetime2(7),@WaitLimit nvarchar(1000)',
        @SampleSeconds=@SampleSeconds,@ServerComparable=@ServerComparable,@ServerReset=@ServerReset,@WaitElapsed=@WaitElapsed,@WaitStart=@WaitStart,@WaitEnd=@WaitEnd,@WaitLimit=@WaitLimit;
    SELECT N'SYNTHETIC_WAIT_BEFORE_ASSERTION' [FrameType],@Case [CaseNumber],* FROM [#CompileContextAnalysis_waits];
    IF (SELECT COUNT(*) FROM [#CompileContextAnalysis_waits])<>1 OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_waits] WHERE [ResetDetected]<>@ExpectedReset
        OR (@Case=0 AND ([DeltaWaitingTasksCount] IS NULL OR [DeltaWaitingTasksCount]<>3 OR [DeltaWaitTimeMs] IS NULL OR [DeltaWaitTimeMs]<>8 OR [DeltaSignalWaitTimeMs] IS NULL OR [DeltaSignalWaitTimeMs]<>3))
        OR (@Case<>0 AND ([DeltaWaitingTasksCount] IS NOT NULL OR [DeltaWaitTimeMs] IS NOT NULL OR [DeltaSignalWaitTimeMs] IS NOT NULL)))
        THROW 56876,N'WI-0006: Synthetic wait guard mismatch.',1;
    SET @Case+=1;
END;
DROP TABLE [#CompileContextAnalysis_counters];DROP TABLE [#CompileContextAnalysis_waits];DROP TABLE [#CompileContextAnalysis_CounterRaw];DROP TABLE [#CompileContextAnalysis_WaitRaw];
SELECT N'WI-0006' [WorkItem],N'SYNTHETIC_GUARDS_PASS' [Status],10 [SyntheticCounterCases],7 [SyntheticWaitCases];
GO
