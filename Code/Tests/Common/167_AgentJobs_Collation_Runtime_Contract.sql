USE [DeineDatenbank];
GO
/*
Datei        : 167_AgentJobs_Collation_Runtime_Contract.sql
Zweck        : Prüft den bestehenden 17-Felder-Jobs-TABLE-Vertrag, sechs
               Textcollations, JSON mit zehn Meta- und zehn Stepsfeldern,
               exakte Listen einschließlich Duplikaten, LIKE und Limits.
Nebenwirkung : Keine Job-, Step-, Schedule-, History- oder Konfigurationsänderung.
Positive Fixture: Extern vorbereitete eigene Jobs ExampleAgentJobÄ und
               exampleAgentJobÄ mit unterschiedlichen Enabled-Schaltern,
               definierten Steps und aktiven Schedules. Keine Activity-,
               History- oder Jobserverzeilen; keine Jobausführung.
Grenze       : Ohne beide Jobs laufen die allgemeinen Fälle weiter; nur die
               positive native Gegenprobe meldet NOT_EXECUTED. Keine positive
               Lauf-/History-/Berechtigungs- oder Regexevidenz. RAW wird extern
               geprüft; dieser Vertrag erfasst ausschließlich TABLE/JSON und
               positive beziehungsweise leere CONSOLE-Ergebnisse.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
DECLARE @MsdbLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [name]=N'msdb');
IF @FrameworkLevel NOT IN(150,160,170) OR @MsdbLevel IS NULL
    THROW 56900,N'AGENT_JOBS_LEVEL_METADATA',1;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 56901,N'AGENT_JOBS_FRAMEWORK_COLLATION',1;
DECLARE @UpperId uniqueidentifier,@LowerId uniqueidentifier;
SELECT @UpperId=[job_id] FROM [msdb].[dbo].[sysjobs]
WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleAgentJobÄ';
SELECT @LowerId=[job_id] FROM [msdb].[dbo].[sysjobs]
WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'exampleAgentJobÄ';
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs]
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleMissingAgentJobÄ')
    THROW 56902,N'AGENT_JOBS_EMPTY_NAME_ALREADY_EXISTS',1;
DECLARE @Fixture bit=CASE WHEN @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId THEN 1 ELSE 0 END;
DECLARE @FixtureStatus varchar(40)=CASE WHEN @Fixture=1 THEN 'PENDING' ELSE 'NOT_EXECUTED' END;
DECLARE @CoreTableCases int=0,@NativeCases int=0,@Consumers int=0,@Preflights int=0,
        @ConsolePositive int=0,@ConsoleEmpty int=0;
CREATE TABLE [#ExpectedJobs167]
(
    [JobId] uniqueidentifier NULL,
    [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Enabled] bit NULL,
    [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsRunning] bit NULL,
    [RunStart] datetime NULL,
    [RunningMinutes] int NULL,
    [LastRunDateTime] datetime NULL,
    [LastRunStatus] int NULL,
    [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunDurationSeconds] int NULL,
    [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ScheduleCount] int NULL,
    [EnabledScheduleCount] int NULL,
    [StepCount] int NULL,
    [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#NativeJobs167]
(
    [JobId] uniqueidentifier NULL,
    [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Enabled] bit NULL,
    [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsRunning] bit NULL,
    [RunStart] datetime NULL,
    [RunningMinutes] int NULL,
    [LastRunDateTime] datetime NULL,
    [LastRunStatus] int NULL,
    [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunDurationSeconds] int NULL,
    [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ScheduleCount] int NULL,
    [EnabledScheduleCount] int NULL,
    [StepCount] int NULL,
    [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#SelectedJobs167]
(
    [JobId] uniqueidentifier NULL,
    [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Enabled] bit NULL,
    [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsRunning] bit NULL,
    [RunStart] datetime NULL,
    [RunningMinutes] int NULL,
    [LastRunDateTime] datetime NULL,
    [LastRunStatus] int NULL,
    [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunDurationSeconds] int NULL,
    [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ScheduleCount] int NULL,
    [EnabledScheduleCount] int NULL,
    [StepCount] int NULL,
    [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#NativeSteps167]
(
    [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StepId] int NULL,
    [StepName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Subsystem] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunOutcome] int NULL,
    [LastRunOutcomeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunDateTime] datetime NULL,
    [LastRunDurationSeconds] int NULL,
    [LastRunRetries] int NULL,
    [LastRunMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#SelectedSteps167]
(
    [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StepId] int NULL,
    [StepName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Subsystem] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunOutcome] int NULL,
    [LastRunOutcomeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [LastRunDateTime] datetime NULL,
    [LastRunDurationSeconds] int NULL,
    [LastRunRetries] int NULL,
    [LastRunMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#NativeJobOrder167]([JobId] uniqueidentifier NOT NULL,[NativeOrdinal] bigint NOT NULL);
CREATE TABLE [#NativeStepOrder167]([JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StepId] int NOT NULL,[NativeOrdinal] bigint NOT NULL);
IF @Fixture=1
BEGIN
    IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobhistory] WHERE [job_id] IN(@UpperId,@LowerId))
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] IN(@UpperId,@LowerId))
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] IN(@UpperId,@LowerId))
        THROW 56903,N'AGENT_JOBS_FIXTURE_EXECUTION_STATE_PRESENT',1;
    IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'[Ee]xampleAgentJobÄ'
          AND [job_id] NOT IN(@UpperId,@LowerId))
        THROW 56904,N'AGENT_JOBS_FIXTURE_PATTERN_NOT_ISOLATED',1;
    INSERT [#NativeJobs167]
    SELECT [j].[job_id],[j].[name],CONVERT(bit,[j].[enabled]),SUSER_SNAME([j].[owner_sid]),[c].[name],
           CONVERT(bit,0),NULL,NULL,NULL,NULL,NULL,NULL,NULL,
           (SELECT COUNT(*) FROM [msdb].[dbo].[sysjobschedules] AS [s] WHERE [s].[job_id]=[j].[job_id]),
           (SELECT COUNT(*) FROM [msdb].[dbo].[sysjobschedules] AS [s]
            JOIN [msdb].[dbo].[sysschedules] AS [d] ON [d].[schedule_id]=[s].[schedule_id]
            WHERE [s].[job_id]=[j].[job_id] AND [d].[enabled]=1),
           (SELECT COUNT(*) FROM [msdb].[dbo].[sysjobsteps] AS [st] WHERE [st].[job_id]=[j].[job_id]),
           CASE WHEN [j].[enabled]=0 THEN 'DISABLED' ELSE NULL END
    FROM [msdb].[dbo].[sysjobs] AS [j]
    JOIN [msdb].[dbo].[syscategories] AS [c] ON [c].[category_id]=[j].[category_id]
    WHERE [j].[job_id] IN(@UpperId,@LowerId);
    IF (SELECT COUNT(*) FROM [#NativeJobs167])<>2
       OR NOT EXISTS(SELECT 1 FROM [#NativeJobs167] WHERE [JobId]=@UpperId AND [Enabled]=0)
       OR NOT EXISTS(SELECT 1 FROM [#NativeJobs167] WHERE [JobId]=@LowerId AND [Enabled]=1)
       OR EXISTS(SELECT 1 FROM [#NativeJobs167] WHERE [ScheduleCount]<1 OR [EnabledScheduleCount]<1 OR [StepCount]<1)
        THROW 56905,N'AGENT_JOBS_NATIVE_FIXTURE_DEFINITIONS',1;
    INSERT [#NativeSteps167]
    SELECT [j].[name],[st].[step_id],[st].[step_name],[st].[subsystem],NULL,NULL,NULL,NULL,NULL,NULL
    FROM [msdb].[dbo].[sysjobsteps] AS [st]
    JOIN [msdb].[dbo].[sysjobs] AS [j] ON [j].[job_id]=[st].[job_id]
    WHERE [j].[job_id] IN(@UpperId,@LowerId);
    -- Native msdb order belongs to the preserved early TOP selection.
    INSERT [#NativeJobOrder167]
    SELECT [job_id],ROW_NUMBER() OVER(ORDER BY [name]) FROM [msdb].[dbo].[sysjobs]
    WHERE [job_id] IN(@UpperId,@LowerId);
    INSERT [#NativeStepOrder167]
    SELECT [j].[name],[st].[step_id],ROW_NUMBER() OVER(ORDER BY [j].[name],[st].[step_id])
    FROM [msdb].[dbo].[sysjobsteps] AS [st]
    JOIN [msdb].[dbo].[sysjobs] AS [j] ON [j].[job_id]=[st].[job_id]
    WHERE [j].[job_id] IN(@UpperId,@LowerId);
END;
CREATE TABLE [#Cases167]
([CaseNumber] int NOT NULL PRIMARY KEY,[Names] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [Pattern] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MaxRows] int NULL,
 [Problems] bit NOT NULL,[Minutes] int NOT NULL,[Invalid] bit NOT NULL,[Positive] bit NOT NULL);
INSERT [#Cases167] VALUES
(0,N'[ExampleMissingAgentJobÄ]',NULL,NULL,0,60,0,0),
(1,N'[ExampleMissingAgentJobÄ]',NULL,0,0,60,0,0),
(2,N'[ExampleMissingAgentJobÄ]',NULL,1,0,60,0,0),
(3,N'[ExampleMissingAgentJobÄ]|[ExampleMissingAgentJobÄ]',NULL,0,0,60,0,0),
(4,N'[ExampleMissingAgentJobÄ]|ExampleMissingAgentJobÄ',NULL,0,0,60,0,0),
(5,N'[ExampleMissingAgentJobÄ]|[ExampleMissingAgentJobÄ]|[Invalid',NULL,0,0,60,1,0),
(6,N'[ExampleMissingAgentJobÄ]',NULL,-1,0,60,1,0),
(7,N'[ExampleMissingAgentJobÄ]',NULL,0,0,0,1,0),
(8,N'[Invalid',NULL,0,0,60,1,0),
(9,N'[ExampleMissingAgentJobÄ]',N'like:ExampleMissingAgentJobÄ',0,0,60,1,0),
(10,NULL,N'like:ExampleMissingAgentJobÄ',1,0,60,0,0);
IF @Fixture=1
INSERT [#Cases167] VALUES
(20,N'[ExampleAgentJobÄ]|[exampleAgentJobÄ]',NULL,NULL,0,60,0,1),
(21,N'[ExampleAgentJobÄ]|[exampleAgentJobÄ]',NULL,0,0,60,0,1),
(22,N'[ExampleAgentJobÄ]|[exampleAgentJobÄ]',NULL,1,0,60,0,1),
(23,N'[ExampleAgentJobÄ]|[exampleAgentJobÄ]',NULL,2,0,60,0,1),
(24,N'[ExampleAgentJobÄ]',NULL,0,0,60,0,1),
(25,N'[exampleAgentJobÄ]',NULL,0,0,60,0,1),
(26,N'[ExampleAgentJobÄ]|[ExampleAgentJobÄ]|[exampleAgentJobÄ]|exampleAgentJobÄ',NULL,0,0,60,0,1),
(27,NULL,N'like:[Ee]xampleAgentJobÄ',0,0,60,0,1),
(28,NULL,N'like:ExampleAgentJobÄ',0,0,60,0,1),
(29,N'[ExampleAgentJobÄ]|[exampleAgentJobÄ]',NULL,0,1,60,0,1),
(30,N'[ExampleAgentJobÄ]|[ExampleAgentJobÄ]',NULL,0,0,60,0,1),
(31,N'[ExampleAgentJobÄ]|ExampleAgentJobÄ',NULL,0,0,60,0,1),
(32,NULL,N'like:exampleAgentJobÄ',1,0,60,0,1);
DECLARE @Case int,@Names nvarchar(max),@Pattern nvarchar(4000),@Max int,@Problems bit,@Minutes int,@Invalid bit,@Positive bit;
DECLARE @Json nvarchar(max),@Before datetime2(3),@After datetime2(3),@RowsJson nvarchar(max),@NativeJson nvarchar(max),@NativeStepsJson nvarchar(max);
DECLARE @Limit bigint,@Returned bigint,@StepRows bigint;
BEGIN TRY
    DECLARE [CaseCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [CaseNumber] FROM [#Cases167] ORDER BY [CaseNumber];
    OPEN [CaseCursor]; FETCH NEXT FROM [CaseCursor] INTO @Case;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @Names=[Names],@Pattern=[Pattern],@Max=[MaxRows],@Problems=[Problems],@Minutes=[Minutes],
               @Invalid=[Invalid],@Positive=[Positive] FROM [#Cases167] WHERE [CaseNumber]=@Case;
        IF @Positive=1 AND
        (EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobhistory] WHERE [job_id] IN(@UpperId,@LowerId))
         OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] IN(@UpperId,@LowerId))
         OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] IN(@UpperId,@LowerId)))
            THROW 56906,N'AGENT_JOBS_FIXTURE_CHANGED',1;
        CREATE TABLE [#Jobs167]([Dummy] int NULL);
        SELECT @Json=N'not-cleared',@Before=SYSUTCDATETIME();
        SET LOCK_TIMEOUT 731;
        EXEC [monitor].[USP_AgentJobs]
            @JobNames=@Names,@JobNamePattern=@Pattern,@NurProblematisch=@Problems,
            @LongRunningMinutes=@Minutes,@MaxZeilen=@Max,@ResultSetArt='TABLE',
            @ResultTablesJson=N'{"jobs":"#Jobs167"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        SET @After=SYSUTCDATETIME();
        -- Der prozedurinterne Wert 0 verändert den Callerwert beim Return nicht.
        IF @@LOCK_TIMEOUT<>731 THROW 56907,N'AGENT_JOBS_EXISTING_LOCK_TIMEOUT',1;
        IF EXISTS
        (
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],
                   [collation_name],[is_nullable],[is_identity]
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Jobs167')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],
                   [collation_name],[is_nullable],[is_identity]
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedJobs167')
        ) OR EXISTS
        (
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],
                   [collation_name],[is_nullable],[is_identity]
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedJobs167')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],
                   [collation_name],[is_nullable],[is_identity]
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Jobs167')
        ) THROW 56908,N'AGENT_JOBS_INDEPENDENT_17_FIELD_SCHEMA',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Jobs167')
            AND [collation_name] IS NOT NULL)<>6 THROW 56909,N'AGENT_JOBS_SIX_TEXT_COLUMNS',1;
        EXEC [sys].[sp_executesql] N'
SELECT @rows=COUNT_BIG(*) FROM [#Jobs167];
SELECT @tableJson=(SELECT * FROM [#Jobs167]
    ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END,[JobName] FOR JSON PATH,INCLUDE_NULL_VALUES);
',N'@rows bigint OUTPUT,@tableJson nvarchar(max) OUTPUT',@rows=@Returned OUTPUT,@tableJson=@RowsJson OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1 THROW 56910,N'AGENT_JOBS_JSON_VALIDITY',1;
        IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>3
           OR EXISTS(SELECT [key],[type] FROM OPENJSON(@Json)
               EXCEPT SELECT * FROM (VALUES(N'meta',5),(N'jobs',4),(N'steps',4)) AS [e]([k],[t]))
           OR EXISTS(SELECT * FROM (VALUES(N'meta',5),(N'jobs',4),(N'steps',4)) AS [e]([k],[t])
               EXCEPT SELECT [key],[type] FROM OPENJSON(@Json))
            THROW 56911,N'AGENT_JOBS_THREE_TOP_KEYS',1;
        DECLARE @MetaShape TABLE([Property] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[JsonType] int NOT NULL);
        INSERT @MetaShape VALUES(N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),
            (N'isPartial',3),(N'requestedMaxRows',CASE WHEN @Max IS NULL THEN 0 ELSE 2 END),
            (N'jobCount',2),(N'stepCount',2),(N'errorNumber',0),(N'errorMessage',CASE WHEN @Invalid=1 THEN 1 ELSE 0 END);
        IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>10
           OR EXISTS(SELECT [Property],[JsonType] FROM @MetaShape EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta'))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta') EXCEPT SELECT [Property],[JsonType] FROM @MetaShape)
            THROW 56912,N'AGENT_JOBS_TEN_META_NULL_PROPERTIES',1;
        DELETE FROM @MetaShape;
        DECLARE @Captured datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc'));
        SELECT @StepRows=COUNT_BIG(*) FROM OPENJSON(@Json,N'$.steps');
        IF @Captured IS NULL OR @Captured<@Before OR @Captured>@After
           OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'AgentJobs'
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),0)<>1
           OR JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END
           OR JSON_VALUE(@Json,N'$.meta.isPartial')<>CASE WHEN @Invalid=1 THEN N'true' ELSE N'false' END
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.jobCount')),-1)<>@Returned
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.stepCount')),-1)<>@StepRows
           OR (@Max IS NOT NULL AND COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.requestedMaxRows')),-9223372036854775808)<>@Max)
           OR (@Max IS NULL AND JSON_VALUE(@Json,N'$.meta.requestedMaxRows') IS NOT NULL)
           OR (@Invalid=1 AND JSON_VALUE(@Json,N'$.meta.errorMessage')<>N'Ungültige Filter-, Grenzwert- oder Ausgabeparameter.')
            THROW 56913,N'AGENT_JOBS_FULL_META_VALUES',1;
        IF COALESCE(@RowsJson,N'[]')<>JSON_QUERY(@Json,N'$.jobs')
            THROW 56914,N'AGENT_JOBS_FULL_TABLE_JSON_PARITY',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.jobs') AS [a] WHERE (SELECT COUNT(*) FROM OPENJSON([a].[value]))<>17)
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.steps') AS [a] WHERE (SELECT COUNT(*) FROM OPENJSON([a].[value]))<>10)
            THROW 56915,N'AGENT_JOBS_FULL_NULL_PROPERTY_COUNTS',1;
        IF @Positive=0
        BEGIN
            IF @Returned<>0 OR @StepRows<>0 THROW 56916,N'AGENT_JOBS_CORE_EMPTY_SCOPE',1;
            SET @CoreTableCases+=1;
        END
        ELSE
        BEGIN
            TRUNCATE TABLE [#SelectedJobs167]; TRUNCATE TABLE [#SelectedSteps167];
            SET @Limit=CASE WHEN @Max IS NULL OR @Max=0 THEN 9223372036854775807 ELSE @Max END;
            -- The expected key set is specified independently of the product parser.
            INSERT [#SelectedJobs167]
            SELECT TOP(@Limit) [j].* FROM [#NativeJobs167] AS [j]
            JOIN [#NativeJobOrder167] AS [o] ON [o].[JobId]=[j].[JobId]
            WHERE (@Case NOT IN(24,28,30,31) OR [j].[JobId]=@UpperId)
              AND (@Case NOT IN(25,32) OR [j].[JobId]=@LowerId)
              AND (@Problems=0 OR [j].[Enabled]=0)
            ORDER BY [o].[NativeOrdinal];
            IF @Problems=0
            INSERT [#SelectedSteps167]
            SELECT TOP(@Limit) [st].* FROM [#NativeSteps167] AS [st]
            JOIN [#NativeStepOrder167] AS [o] ON [o].[JobName]=[st].[JobName] AND [o].[StepId]=[st].[StepId]
            JOIN [#SelectedJobs167] AS [j] ON [j].[JobName]=[st].[JobName]
            ORDER BY [o].[NativeOrdinal];
            SELECT @NativeJson=(SELECT * FROM [#SelectedJobs167]
                ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END,[JobName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SELECT @NativeStepsJson=(SELECT * FROM [#SelectedSteps167] ORDER BY [JobName],[StepId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            IF COALESCE(@NativeJson,N'[]')<>JSON_QUERY(@Json,N'$.jobs')
               OR COALESCE(@NativeStepsJson,N'[]')<>JSON_QUERY(@Json,N'$.steps')
                THROW 56917,N'AGENT_JOBS_NATIVE_17_AND_10_FIELD_ORACLE',1;
            IF @Case=29 AND (@Returned<>1 OR @StepRows<>0
                OR NOT EXISTS(SELECT 1 FROM [#SelectedJobs167] WHERE [JobId]=@UpperId AND [StepCount]>0 AND [ProblemCode]='DISABLED'))
                THROW 56918,N'AGENT_JOBS_PROBLEM_HISTORY_STEP_BOUNDARY',1;
            IF @Case IN(20,21,26,27) AND @Returned<>2
                THROW 56919,N'AGENT_JOBS_CASE_AND_DUPLICATE_IDENTITIES',1;
            IF @Case IN(22,24,25,28,30,31,32) AND @Returned<>1
                THROW 56920,N'AGENT_JOBS_EXACT_LIKE_LIMIT_SELECTION',1;
            SET @NativeCases+=1;
        END;
        IF @Case IN(0,3,6,20,22,29)
        BEGIN
            CREATE TABLE [#ConsoleEmpty167]([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
            CREATE TABLE [#ConsoleJobs167]([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [JobId] uniqueidentifier NULL,
                [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [Enabled] bit NULL,
                [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [IsRunning] bit NULL,
                [RunStart] datetime NULL,
                [RunningMinutes] int NULL,
                [LastRunDateTime] datetime NULL,
                [LastRunStatus] int NULL,
                [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [LastRunDurationSeconds] int NULL,
                [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [ScheduleCount] int NULL,
                [EnabledScheduleCount] int NULL,
                [StepCount] int NULL,
                [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
            );
            SET LOCK_TIMEOUT 731;
            IF @Positive=1
                INSERT [#ConsoleJobs167]
                EXEC [monitor].[USP_AgentJobs] @JobNames=@Names,@JobNamePattern=@Pattern,
                    @NurProblematisch=@Problems,@LongRunningMinutes=@Minutes,@MaxZeilen=@Max,
                    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
            ELSE
                INSERT [#ConsoleEmpty167]
                EXEC [monitor].[USP_AgentJobs] @JobNames=@Names,@JobNamePattern=@Pattern,
                    @NurProblematisch=@Problems,@LongRunningMinutes=@Minutes,@MaxZeilen=@Max,
                    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
            IF @@LOCK_TIMEOUT<>731 OR COALESCE(ISJSON(@Json),0)<>1
                THROW 56921,N'AGENT_JOBS_CONSOLE_JSON_LOCK',1;
            IF @Positive=1
            BEGIN
                IF EXISTS(SELECT 1 FROM [#ConsoleJobs167] WHERE [Ergebnis]<>N'AgentJobs' OR [Ergebnis] IS NULL)
                   OR (SELECT COUNT(*) FROM [#ConsoleJobs167])<>@Returned
                    THROW 56922,N'AGENT_JOBS_CONSOLE_LABEL_COUNT',1;
                SELECT @RowsJson=(SELECT
                    [JobId],[JobName],[Enabled],[OwnerName],[CategoryName],[IsRunning],[RunStart],[RunningMinutes],[LastRunDateTime],[LastRunStatus],[LastRunStatusDesc],[LastRunDurationSeconds],[LastMessage],[ScheduleCount],[EnabledScheduleCount],[StepCount],[ProblemCode]
                    FROM [#ConsoleJobs167] ORDER BY CASE WHEN [ProblemCode] IS NULL THEN 1 ELSE 0 END,[JobName]
                    FOR JSON PATH,INCLUDE_NULL_VALUES);
                IF COALESCE(@RowsJson,N'[]')<>JSON_QUERY(@Json,N'$.jobs')
                   OR COALESCE(@RowsJson,N'[]')<>COALESCE(@NativeJson,N'[]')
                   OR COALESCE(@NativeStepsJson,N'[]')<>JSON_QUERY(@Json,N'$.steps')
                    THROW 56923,N'AGENT_JOBS_CONSOLE_NATIVE_18_FIELD_CAPTURE',1;
                SET @ConsolePositive+=1;
            END
            ELSE
            BEGIN
                IF (SELECT COUNT(*) FROM [#ConsoleEmpty167])<>1
                   OR NOT EXISTS(SELECT 1 FROM [#ConsoleEmpty167]
                       WHERE [Ergebnis]=N'Keine fachlichen Ergebnisse' AND [Status] IS NULL AND [Hinweis] IS NULL)
                   OR JSON_QUERY(@Json,N'$.jobs')<>N'[]' OR JSON_QUERY(@Json,N'$.steps')<>N'[]'
                    THROW 56924,N'AGENT_JOBS_EMPTY_CONSOLE_THREE_FIELDS',1;
                SET @ConsoleEmpty+=1;
            END;
            IF JSON_VALUE(@Json,N'$.meta.statusCode')<>CASE WHEN @Invalid=1 THEN N'INVALID_PARAMETER' ELSE N'AVAILABLE' END
                THROW 56925,N'AGENT_JOBS_CONSOLE_STATUS',1;
            DROP TABLE [#ConsoleEmpty167]; DROP TABLE [#ConsoleJobs167];
        END;
        DROP TABLE [#Jobs167];
        FETCH NEXT FROM [CaseCursor] INTO @Case;
    END;
    CLOSE [CaseCursor]; DEALLOCATE [CaseCursor];
    EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleMissingAgentJobÄ]',@MaxZeilen=0,
        @ResultSetArt='UNSUPPORTED',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER'
       OR JSON_QUERY(@Json,N'$.jobs')<>N'[]' OR JSON_QUERY(@Json,N'$.steps')<>N'[]'
        THROW 56926,N'AGENT_JOBS_INVALID_CONSUMER',1;
    SET @Consumers+=1;
    SET @Json=N'not-cleared';
    EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleMissingAgentJobÄ]',@MaxZeilen=0,
        @ResultSetArt='NONE',@JsonErzeugen=0,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF @Json IS NOT NULL THROW 56927,N'AGENT_JOBS_DISABLED_JSON_CLEARED',1;
    SET @Consumers+=1;
    CREATE TABLE [#Preflight167]([Dummy] int NULL);
    CREATE TABLE [#PreflightOther167]([Dummy] int NULL);
    DECLARE @Preflight int=0,@BadMap nvarchar(max),@BadMode varchar(16),@Caught int;
    WHILE @Preflight<6
    BEGIN
        SET @BadMap=CASE @Preflight
            WHEN 0 THEN N'{"unknown":"#Preflight167"}'
            WHEN 1 THEN N'{"jobs":"#MissingAgentJobs167"}'
            WHEN 2 THEN N'{"jobs":"monitor.ExampleAgentJobs"}'
            WHEN 3 THEN N'{"jobs":"#Preflight167","jobs":"#PreflightOther167"}'
            ELSE N'{"jobs":"#Preflight167"}' END;
        SET @BadMode=CASE WHEN @Preflight=5 THEN 'NONE' ELSE 'TABLE' END;
        IF @Preflight=4 INSERT [#Preflight167] VALUES(1);
        SET @Caught=NULL;
        SET LOCK_TIMEOUT 731;
        BEGIN TRY
            EXEC [monitor].[USP_AgentJobs] @MaxZeilen=-1,@ResultSetArt=@BadMode,
                @ResultTablesJson=@BadMap,@PrintMeldungen=0;
        END TRY
        BEGIN CATCH
            SET @Caught=ERROR_NUMBER();
        END CATCH;
        IF COALESCE(@Caught,0)<>51011 OR @@LOCK_TIMEOUT<>731
            THROW 56928,N'AGENT_JOBS_TABLE_PREFLIGHT',1;
        IF NOT EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#Preflight167') AND [name]=N'Dummy')
            THROW 56929,N'AGENT_JOBS_PREFLIGHT_TARGET_CHANGED',1;
        SET @Preflights+=1; SET @Preflight+=1;
    END;
    IF @Fixture=1
    BEGIN
        IF @NativeCases<>13 OR @ConsolePositive<>3 THROW 56930,N'AGENT_JOBS_POSITIVE_COVERAGE',1;
        SET @FixtureStatus='PASS';
    END;
    IF @CoreTableCases<>11 OR @Consumers<>2 OR @Preflights<>6 OR @ConsoleEmpty<>3
        THROW 56931,N'AGENT_JOBS_CORE_COVERAGE',1;
    DECLARE @RestoreSuccess nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSuccess;
    SELECT N'AgentJobs' AS [ContractName],@FrameworkLevel AS [FrameworkCompatibilityLevel],@MsdbLevel AS [MsdbCompatibilityLevel],
        @CoreTableCases AS [CoreTableCases],@Consumers AS [ConsumerCases],@Preflights AS [MappingPreflightCases],
        @FixtureStatus AS [PositiveFixtureStatus],@NativeCases AS [PositiveNativeCases],
        @ConsolePositive AS [PositiveConsoleCaptures],@ConsoleEmpty AS [EmptyConsoleCaptures];
    RAISERROR(N'AGENT_JOBS_COLLATION_CORE PASS; positive fixture status is reported separately.',10,1) WITH NOWAIT;
END TRY
BEGIN CATCH
    DECLARE @RestoreFailure nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreFailure;
    THROW;
END CATCH;
GO
