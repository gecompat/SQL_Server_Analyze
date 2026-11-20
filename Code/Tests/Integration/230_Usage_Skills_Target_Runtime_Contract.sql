/*
Usage Skill native runtime contract. The metadata view documents source text; its rows
are not installation or permission attestations. This fixture uses only local #Temp
objects and Help calls. No diagnosis, source query or persistent write is requested.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'tempdb..#UsageSkillTargetActual') IS NOT NULL
    THROW 59001,N'USAGE_SKILL_TEMP_COLLISION',1;
CREATE TABLE [#UsageSkillTargetActual]
(
    [SkillFormatVersion] varchar(16) NULL,
    [SchemaName] sysname NULL,
    [ObjectName] sysname NULL,
    [SkillMarkdown] nvarchar(max) NULL
);

IF (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills])<>18
 OR (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [DatabaseRole] IN ('snapshot_target','both'))<>18
 OR EXISTS
 (
   SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
   WHERE [v].[SkillFormatVersion]<>'1.0.0' OR [v].[SkillFormatVersion] IS NULL
      OR [v].[Description] IS NULL OR NULLIF(LTRIM(RTRIM([v].[Description])),N'') IS NULL
      OR [v].[SkillMarkdown] IS NULL OR DATALENGTH([v].[SkillMarkdown])=0
      OR NOT EXISTS
      (
        SELECT 1 FROM [sys].[objects] AS [o]
        JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
        WHERE [s].[name]=[v].[SchemaName] COLLATE DATABASE_DEFAULT
          AND [o].[name]=[v].[ObjectName] COLLATE DATABASE_DEFAULT
          AND (([v].[ObjectType]='TABLE' AND [o].[type]='U')
            OR ([v].[ObjectType]='VIEW' AND [o].[type]='V')
            OR ([v].[ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE') AND [o].[type]='P')
            OR ([v].[ObjectType]='FUNCTION' AND [o].[type] IN ('FN','IF','TF')))
      )
 )
 OR EXISTS
 (
    SELECT [SchemaName],[ObjectName]
    FROM [monitor_metadata].[VW_ObjectUsageSkills]
    GROUP BY [SchemaName],[ObjectName]
    HAVING COUNT_BIG(*)<>1
 )
    THROW 59002,N'USAGE_SKILL_ROLE_CATALOG',1;

DECLARE @PilotCount int=0;
IF NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalPrepareCollectionCycle' AND [ObjectType]='INTERNAL_PROCEDURE')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'PackageVersion' AND [ObjectType]='TABLE')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor_metadata' AND [ObjectName]=N'VW_ObjectUsageSkills' AND [ObjectType]='VIEW')
    THROW 59003,N'USAGE_SKILL_TARGET_PILOT',1;
SET @PilotCount=3;
DECLARE @ExpectedProcedureCount int=7,@PilotProcedureCount int=1,
        @PilotPublic sysname=N'InternalPrepareCollectionCycle',
        @PilotInternal sysname=N'InternalPrepareCollectionCycle';
IF (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE'))<>@ExpectedProcedureCount
    THROW 59004,N'USAGE_SKILL_PROCEDURE_POPULATION',1;

DECLARE @Stage int=0,@HelpCalls int=0,@Schema sysname,@Object sysname,@ObjectId int,
        @ExpectedMarkdown nvarchar(max),@ArgList nvarchar(max),@CallSql nvarchar(max),
        @BeforeDb int,@BeforeLogin int,@BeforeTran int,@BeforeLock int,@BeforeOptions int,@BeforeXact int,
        @AfterDb int,@AfterLogin int,@AfterTran int,@AfterLock int,@AfterOptions int,@AfterXact int;

WHILE @Stage<=1
BEGIN
    DECLARE [UsageSkillHelpCursor] CURSOR LOCAL FAST_FORWARD FOR
       SELECT [SchemaName],[ObjectName],[SkillMarkdown]
       FROM [monitor_metadata].[VW_ObjectUsageSkills]
       WHERE [ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE')
         AND (@Stage=1 OR [ObjectName] IN (@PilotPublic,@PilotInternal))
       ORDER BY [SchemaName],[ObjectName];
    OPEN [UsageSkillHelpCursor];
    FETCH NEXT FROM [UsageSkillHelpCursor] INTO @Schema,@Object,@ExpectedMarkdown;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @ObjectId=NULL;
        SELECT @ObjectId=[o].[object_id]
        FROM [sys].[objects] AS [o]
        JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
        WHERE [s].[name]=@Schema AND [o].[name]=@Object AND [o].[type]='P';
        IF @ObjectId IS NULL OR
           (SELECT COUNT_BIG(*) FROM [sys].[parameters]
            WHERE [object_id]=@ObjectId AND [name]=N'@Hilfe')<>1
        BEGIN
            CLOSE [UsageSkillHelpCursor];DEALLOCATE [UsageSkillHelpCursor];
            THROW 59006,N'USAGE_SKILL_HELP_SIGNATURE',1;
        END;
        SELECT @ArgList=STRING_AGG(CONVERT(nvarchar(max),[p].[name]+N'=NULL'),N',')
                        WITHIN GROUP (ORDER BY [p].[parameter_id])
        FROM [sys].[parameters] AS [p]
        WHERE [p].[object_id]=@ObjectId AND [p].[name]<>N'@Hilfe';
        SET @CallSql=N'EXEC '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Object)+N' '
                   +COALESCE(@ArgList+N',',N'')+N'@Hilfe=1;';
        DELETE FROM [#UsageSkillTargetActual];
        SELECT @BeforeDb=DB_ID(),@BeforeLogin=SUSER_ID(),@BeforeTran=@@TRANCOUNT,
               @BeforeLock=@@LOCK_TIMEOUT,@BeforeOptions=(@@OPTIONS&16384);
        SELECT @BeforeXact=XACT_STATE();
        INSERT [#UsageSkillTargetActual] ([SkillFormatVersion],[SchemaName],[ObjectName],[SkillMarkdown])
        EXEC [sys].[sp_executesql] @CallSql;
        SELECT @AfterDb=DB_ID(),@AfterLogin=SUSER_ID(),@AfterTran=@@TRANCOUNT,
               @AfterLock=@@LOCK_TIMEOUT,@AfterOptions=(@@OPTIONS&16384);
        SELECT @AfterXact=XACT_STATE();
        IF @AfterDb<>@BeforeDb OR @AfterLogin<>@BeforeLogin OR @AfterTran<>@BeforeTran
           OR @AfterLock<>@BeforeLock OR @AfterOptions<>@BeforeOptions OR @AfterXact<>@BeforeXact
           OR @AfterDb IS NULL OR @AfterLogin IS NULL
            THROW 59007,N'USAGE_SKILL_HELP_CALLER_STATE',1;
        IF (SELECT COUNT_BIG(*) FROM [#UsageSkillTargetActual])<>1
           OR EXISTS
           (
             SELECT 1 FROM [#UsageSkillTargetActual] AS [a]
             WHERE [a].[SkillFormatVersion]<>'1.0.0' OR [a].[SkillFormatVersion] IS NULL
                OR [a].[SchemaName] COLLATE Latin1_General_100_BIN2<>@Schema COLLATE Latin1_General_100_BIN2
                OR [a].[ObjectName] COLLATE Latin1_General_100_BIN2<>@Object COLLATE Latin1_General_100_BIN2
                OR [a].[SkillMarkdown] IS NULL
                OR DATALENGTH([a].[SkillMarkdown])<>DATALENGTH(@ExpectedMarkdown)
                OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
                   <>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExpectedMarkdown))
           )
            THROW 59008,N'USAGE_SKILL_HELP_TEXT_PARITY',1;
        SET @HelpCalls+=1;
        FETCH NEXT FROM [UsageSkillHelpCursor] INTO @Schema,@Object,@ExpectedMarkdown;
    END;
    CLOSE [UsageSkillHelpCursor];DEALLOCATE [UsageSkillHelpCursor];
    SET @Stage+=1;
END;
IF @HelpCalls<>@ExpectedProcedureCount+@PilotProcedureCount
    THROW 59009,N'USAGE_SKILL_HELP_COVERAGE',1;
DECLARE @SentinelCalls TABLE([SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[CallSql] nvarchar(max) NOT NULL);
INSERT @SentinelCalls([SchemaName],[ObjectName],[CallSql]) VALUES
(N'snapshot',N'InternalConfigureSnapshotPolicy',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 int=CONVERT(int,1737);DECLARE @u3 nvarchar(2048)=N''UsageSentinel'';EXEC [snapshot].[InternalConfigureSnapshotPolicy] @CollectionIntervalSeconds=NULL,@MaxRows=NULL,@PayloadEnabled=NULL,@RawRetentionDays=NULL,@PayloadRetentionDays=NULL,@RollupRetentionDays=NULL,@SoftBudgetMB=NULL,@PurgeIntervalMinutes=NULL,@PurgeBatchRows=NULL,@BudgetAction=NULL,@StatusCodeOut=@u1 OUTPUT,@ErrorNumberOut=@u2 OUTPUT,@ErrorMessageOut=@u3 OUTPUT,@CollectorCode=NULL,@CollectorEnabled=NULL,@UpdateSharedPolicy=NULL,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetDatabaseName=NULL,@ExpectedTargetCreateDate=NULL,@JoinFrameworkTransaction=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'snapshot',N'InternalPrepareCollectionCycle',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 varchar(40)=''USAGE_SENTINEL'';DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [snapshot].[InternalPrepareCollectionCycle] @SourceDatabaseName=NULL,@SchedulerType=NULL,@RunEvenIfNotDue=NULL,@CaptureRunIdOut=@u1 OUTPUT,@ShouldCollectOut=@u2 OUTPUT,@StatusCodeOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@CollectorCode=NULL,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetDatabaseName=NULL,@ExpectedTargetCreateDate=NULL,@PolicyOnly=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'snapshot',N'InternalCompletePerformanceCounterCycle',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [snapshot].[InternalCompletePerformanceCounterCycle] @CaptureRunId=NULL,@CollectorJson=NULL,@SourceStatusCode=NULL,@SourceIsPartial=NULL,@SourceErrorNumber=NULL,@SourceErrorMessage=NULL,@StatusCodeOut=@u1 OUTPUT,@IsPartialOut=@u2 OUTPUT,@ErrorNumberOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'snapshot',N'InternalCompleteWaitStatsCycle',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [snapshot].[InternalCompleteWaitStatsCycle] @CaptureRunId=NULL,@CollectorJson=NULL,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetDatabaseName=NULL,@ExpectedTargetCreateDate=NULL,@StatusCodeOut=@u1 OUTPUT,@IsPartialOut=@u2 OUTPUT,@ErrorNumberOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'snapshot',N'InternalFinalizeCollectionCycle',N'EXEC [snapshot].[InternalFinalizeCollectionCycle] @CaptureRunId=NULL,@StatusCode=NULL,@IsPartial=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,@Hilfe=1;'),
(N'snapshot',N'InternalPurgeExpiredData',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 varchar(40)=''USAGE_SENTINEL'';DECLARE @u3 bit=CONVERT(bit,1);DECLARE @u4 int=CONVERT(int,1737);DECLARE @u5 nvarchar(2048)=N''UsageSentinel'';DECLARE @u6 int=CONVERT(int,1737);EXEC [snapshot].[InternalPurgeExpiredData] @MaxBatches=NULL,@Force=NULL,@PurgeRunIdOut=@u1 OUTPUT,@StatusCodeOut=@u2 OUTPUT,@BudgetExceededOut=@u3 OUTPUT,@ErrorNumberOut=@u4 OUTPUT,@ErrorMessageOut=@u5 OUTPUT,@ContractOnly=NULL,@RetentionContractVersionOut=@u6 OUTPUT,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetDatabaseName=NULL,@ExpectedTargetCreateDate=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u6 IS NULL OR @u6<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'snapshot',N'InternalCompleteFileIOCycle',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [snapshot].[InternalCompleteFileIOCycle] @CaptureRunId=NULL,@CollectorJson=NULL,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetDatabaseName=NULL,@ExpectedTargetCreateDate=NULL,@StatusCodeOut=@u1 OUTPUT,@IsPartialOut=@u2 OUTPUT,@ErrorNumberOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;');
IF (SELECT COUNT_BIG(*) FROM @SentinelCalls)<>7
    THROW 59010,N'USAGE_SKILL_OUTPUT_CONTRACT_COUNT',1;
DECLARE @SentinelCount int=0;
DECLARE [UsageSkillSentinelCursor] CURSOR LOCAL FAST_FORWARD FOR
 SELECT [SchemaName],[ObjectName],[CallSql] FROM @SentinelCalls ORDER BY [SchemaName],[ObjectName];
OPEN [UsageSkillSentinelCursor];
FETCH NEXT FROM [UsageSkillSentinelCursor] INTO @Schema,@Object,@CallSql;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @ExpectedMarkdown=[SkillMarkdown]
    FROM [monitor_metadata].[VW_ObjectUsageSkills]
    WHERE [SchemaName]=@Schema AND [ObjectName]=@Object AND [ObjectType]='INTERNAL_PROCEDURE';
    DELETE FROM [#UsageSkillTargetActual];
    SELECT @BeforeDb=DB_ID(),@BeforeLogin=SUSER_ID(),@BeforeTran=@@TRANCOUNT,
           @BeforeLock=@@LOCK_TIMEOUT,@BeforeOptions=(@@OPTIONS&16384);
    SELECT @BeforeXact=XACT_STATE();
    INSERT [#UsageSkillTargetActual] ([SkillFormatVersion],[SchemaName],[ObjectName],[SkillMarkdown])
    EXEC [sys].[sp_executesql] @CallSql;
    SELECT @AfterDb=DB_ID(),@AfterLogin=SUSER_ID(),@AfterTran=@@TRANCOUNT,
           @AfterLock=@@LOCK_TIMEOUT,@AfterOptions=(@@OPTIONS&16384);
    SELECT @AfterXact=XACT_STATE();
    IF @AfterDb<>@BeforeDb OR @AfterLogin<>@BeforeLogin OR @AfterTran<>@BeforeTran
       OR @AfterLock<>@BeforeLock OR @AfterOptions<>@BeforeOptions OR @AfterXact<>@BeforeXact
       OR @AfterDb IS NULL OR @AfterLogin IS NULL
        THROW 59011,N'USAGE_SKILL_OUTPUT_CALLER_STATE',1;
    IF @ExpectedMarkdown IS NULL OR (SELECT COUNT_BIG(*) FROM [#UsageSkillTargetActual])<>1
       OR EXISTS (SELECT 1 FROM [#UsageSkillTargetActual] AS [a]
          WHERE [a].[SkillFormatVersion]<>'1.0.0' OR [a].[SkillFormatVersion] IS NULL
             OR [a].[SchemaName] COLLATE Latin1_General_100_BIN2<>@Schema COLLATE Latin1_General_100_BIN2
             OR [a].[ObjectName] COLLATE Latin1_General_100_BIN2<>@Object COLLATE Latin1_General_100_BIN2
             OR [a].[SkillMarkdown] IS NULL OR DATALENGTH([a].[SkillMarkdown])<>DATALENGTH(@ExpectedMarkdown)
             OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
                <>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExpectedMarkdown)))
        THROW 59012,N'USAGE_SKILL_OUTPUT_HELP_PARITY',1;
    SET @SentinelCount+=1;
    FETCH NEXT FROM [UsageSkillSentinelCursor] INTO @Schema,@Object,@CallSql;
END;
CLOSE [UsageSkillSentinelCursor];DEALLOCATE [UsageSkillSentinelCursor];
IF @SentinelCount<>7 THROW 59013,N'USAGE_SKILL_OUTPUT_COVERAGE',1;
DROP TABLE [#UsageSkillTargetActual];
PRINT N'USAGE_SKILL_TARGET_RUNTIME_CONTRACT PASS';
GO