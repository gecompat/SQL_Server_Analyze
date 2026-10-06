USE [DeineDatenbank];
GO
/*
Datei        : 166_FrameworkUsage_QueryStore_Collation_Runtime_Contract.sql
Zweck        : Prüft vier bestehende TABLE-Schemas, JSON-/OUTPUT-Parität,
               Parameter-, Mapping- und LOCK_TIMEOUT-Verträge sowie CONSOLE.
Nebenwirkung : Keine Procedure-, Query-Store- oder Konfigurationsänderung.
Positive Fixture: Zwei extern vorbereitete eigene Unicode-monitor-Procedures
               USP_ExampleFrameworkUsageÄ und usp_ExampleFrameworkUsageÄ mit
               gespeicherten Runtime-Statistiken; Query Store bleibt READ_ONLY.
Grenze       : Ohne diese Fixture laufen die allgemeinen Fälle weiter. Nur die
               positive native Gegenprobe meldet dann NOT_EXECUTED. RAW-Zeilen,
               DENIED_PERMISSION und ERROR_HANDLED werden nicht nachgewiesen.
               Statementanzahlen sind keine Anzahl äußerer EXEC-Aufrufe.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
IF @FrameworkLevel NOT IN(150,160,170)
    THROW 56800,N'FRAMEWORK_USAGE_FRAMEWORK_LEVEL',1;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),N'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 56801,N'FRAMEWORK_USAGE_FRAMEWORK_COLLATION',1;
DECLARE @NativeState smallint, @NativeDesc nvarchar(60), @NativeReason bigint;
SELECT @NativeState=[actual_state],@NativeDesc=[actual_state_desc],@NativeReason=[readonly_reason]
FROM [sys].[database_query_store_options];
DECLARE @UpperId int=OBJECT_ID(N'[monitor].[USP_ExampleFrameworkUsageÄ]',N'P');
DECLARE @LowerId int=OBJECT_ID(N'[monitor].[usp_ExampleFrameworkUsageÄ]',N'P');
DECLARE @PositiveFixture bit=CASE WHEN @NativeState=1 AND @UpperId IS NOT NULL AND @LowerId IS NOT NULL AND @UpperId<>@LowerId THEN 1 ELSE 0 END;
DECLARE @SelectiveMin bigint=NULL;
DECLARE @PositiveFixtureStatus varchar(40)=CASE WHEN @PositiveFixture=1 THEN 'PENDING' ELSE 'NOT_EXECUTED' END;
DECLARE @CoreCases int=0,@PositiveCases int=0,@ConsolePositive int=0,@ConsoleEmpty int=0,@PreflightCases int=0;
CREATE TABLE [#ExpectedModule166]
(
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [QueryStoreActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [QueryStoreReadonlyReason] bigint NULL,
    [RequestedWindowDays] int NULL,
    [MinimumExecutions] bigint NOT NULL,
    [ReturnedRowCount] bigint NOT NULL,
    [HasMoreRows] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);

CREATE TABLE [#ExpectedUsage166]
(
    [ProcedureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ExecutionCount] bigint NOT NULL,
    [LastExecutionTime] datetimeoffset(7) NULL,
    [AvgDurationMs] decimal(19,3) NULL,
    [AvgCpuMs] decimal(19,3) NULL,
    [AvgLogicalReads] decimal(19,2) NULL,
    [AvgMemoryGrantKB] decimal(19,2) NULL,
    [PlanCount] bigint NOT NULL,
    [QueryCount] bigint NOT NULL,
    [FirstSeen] datetimeoffset(7) NULL,
    [LastSeen] datetimeoffset(7) NULL
);

CREATE TABLE [#ExpectedSource166]
(
    [SourceOrdinal] int NOT NULL,
    [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [ReturnedRowCount] bigint NOT NULL,
    [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

CREATE TABLE [#ExpectedWarnings166]
(
    [WarningOrdinal] int NOT NULL,
    [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ErrorNumber] int NULL,
    [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

CREATE TABLE [#NativeStats166]
(
    [ProcedureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObjectId] int NOT NULL,[QueryId] bigint NOT NULL,[PlanId] bigint NOT NULL,
    [Executions] bigint NOT NULL,[FirstTime] datetimeoffset(7) NOT NULL,[LastTime] datetimeoffset(7) NOT NULL,
    [Duration] float NOT NULL,[Cpu] float NOT NULL,[Reads] float NOT NULL,[MemoryPages] float NOT NULL
);
IF @PositiveFixture=1
BEGIN
    INSERT [#NativeStats166]
    SELECT [o].[name],[o].[object_id],[q].[query_id],[p].[plan_id],CONVERT(bigint,[r].[count_executions]),
           [r].[first_execution_time],[r].[last_execution_time],
           CONVERT(float,[r].[avg_duration]),CONVERT(float,[r].[avg_cpu_time]),
           CONVERT(float,[r].[avg_logical_io_reads]),CONVERT(float,[r].[avg_query_max_used_memory])
    FROM [sys].[query_store_runtime_stats] AS [r]
    JOIN [sys].[query_store_plan] AS [p] ON [p].[plan_id]=[r].[plan_id]
    JOIN [sys].[query_store_query] AS [q] ON [q].[query_id]=[p].[query_id]
    JOIN [sys].[objects] AS [o] ON [o].[object_id]=[q].[object_id] AND [o].[type]='P'
    JOIN [sys].[schemas] AS [sc] ON [sc].[schema_id]=[o].[schema_id]
    WHERE [sc].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'monitor';
    IF NOT EXISTS(SELECT 1 FROM [#NativeStats166] WHERE [ObjectId]=@UpperId AND [Executions]>0)
       OR NOT EXISTS(SELECT 1 FROM [#NativeStats166] WHERE [ObjectId]=@LowerId AND [Executions]>0)
        THROW 56802,N'FRAMEWORK_USAGE_POSITIVE_NATIVE_ROWS_MISSING',1;
    IF (SELECT COUNT(DISTINCT [ProcedureName]) FROM [#NativeStats166] WHERE [ObjectId] IN(@UpperId,@LowerId))<>2
        THROW 56803,N'FRAMEWORK_USAGE_NATIVE_CASE_IDENTITIES',1;
    DECLARE @LowerExecutions bigint,@UpperExecutions bigint;
    SELECT @LowerExecutions=SUM([Executions]) FROM [#NativeStats166] WHERE [ObjectId]=@LowerId;
    SELECT @UpperExecutions=SUM([Executions]) FROM [#NativeStats166] WHERE [ObjectId]=@UpperId;
    IF @LowerExecutions=@UpperExecutions
        THROW 56840,N'FRAMEWORK_USAGE_FIXTURE_REQUIRES_DISTINCT_EXECUTION_TOTALS',1;
    SET @SelectiveMin=CASE WHEN @LowerExecutions<@UpperExecutions THEN @LowerExecutions ELSE @UpperExecutions END+1;
END;
CREATE TABLE [#OracleUsage166]
(
    [ProcedureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ExecutionCount] bigint NOT NULL,
    [LastExecutionTime] datetimeoffset(7) NULL,
    [AvgDurationMs] decimal(19,3) NULL,
    [AvgCpuMs] decimal(19,3) NULL,
    [AvgLogicalReads] decimal(19,2) NULL,
    [AvgMemoryGrantKB] decimal(19,2) NULL,
    [PlanCount] bigint NOT NULL,
    [QueryCount] bigint NOT NULL,
    [FirstSeen] datetimeoffset(7) NULL,
    [LastSeen] datetimeoffset(7) NULL
);
CREATE TABLE [#Cases166]
([CaseNumber] int NOT NULL PRIMARY KEY,[MaxRows] int NULL,[MinExecutions] bigint NULL,[Days] int NULL,
 [LockMs] int NULL,[JsonFlag] bit NULL,[PrintFlag] bit NULL,[Invalid] bit NOT NULL);
INSERT [#Cases166] VALUES
 (0,NULL,1,NULL,0,1,0,0),(1,0,1,0,0,1,0,0),(2,1,1,NULL,0,1,0,0),
 (3,2,1,NULL,731,1,0,0),(4,0,9223372036854775807,NULL,0,1,0,0),
 (5,0,1,1,0,1,0,0),(6,0,2,0,60000,1,0,0),(7,2147483647,1,365000,0,1,0,0),
 (8,-1,1,NULL,0,1,0,1),(9,0,NULL,NULL,0,1,0,1),(10,0,0,NULL,0,1,0,1),
 (11,0,-1,NULL,0,1,0,1),(12,0,1,-1,0,1,0,1),(13,0,1,365001,0,1,0,1),
 (14,0,1,NULL,NULL,1,0,1),(15,0,1,NULL,-1,1,0,1),(16,0,1,NULL,60001,1,0,1),
 (17,0,1,NULL,0,NULL,0,1),(18,0,1,NULL,0,1,NULL,1);
IF @PositiveFixture=1 UPDATE [#Cases166] SET [MinExecutions]=@SelectiveMin WHERE [CaseNumber]=6;
DECLARE @Case int=0,@Max int,@Min bigint,@Days int,@Lock int,@JsonFlag bit,@Print bit,@Invalid bit;
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@Number int,@Message nvarchar(2048);
DECLARE @Before datetimeoffset(7),@After datetimeoffset(7),@Cutoff datetimeoffset(7),@Limit bigint,@OracleCount bigint;
DECLARE @Map nvarchar(max)=N'{"moduleStatus":"#Module166","usage":"#Usage166","sourceStatus":"#Source166","warnings":"#Warnings166"}';
DECLARE @Targets TABLE([ActualName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ExpectedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS);
INSERT @Targets VALUES(N'#Module166',N'#ExpectedModule166'),(N'#Usage166',N'#ExpectedUsage166'),
                      (N'#Source166',N'#ExpectedSource166'),(N'#Warnings166',N'#ExpectedWarnings166');
BEGIN TRY
    SET LOCK_TIMEOUT 731;
    WHILE @Case<=18
    BEGIN
        SELECT @Max=[MaxRows],@Min=[MinExecutions],@Days=[Days],@Lock=[LockMs],
               @JsonFlag=[JsonFlag],@Print=[PrintFlag],@Invalid=[Invalid]
        FROM [#Cases166] WHERE [CaseNumber]=@Case;
        CREATE TABLE [#Module166]([Dummy] int NULL);
        CREATE TABLE [#Usage166]([Dummy] int NULL);
        CREATE TABLE [#Source166]([Dummy] int NULL);
        CREATE TABLE [#Warnings166]([Dummy] int NULL);
        SELECT @Json=N'not-cleared',@Status=NULL,@Partial=NULL,@Number=NULL,@Message=NULL,@Before=SYSUTCDATETIME();
        EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
             @MaxZeilen=@Max,@MinAusfuehrungen=@Min,@ZeitraumTage=@Days,@LockTimeoutMs=@Lock,
             @ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=@JsonFlag,@Json=@Json OUTPUT,
             @PrintMeldungen=@Print,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
             @ErrorNumberOut=@Number OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        SET @After=SYSUTCDATETIME();
        IF @@LOCK_TIMEOUT<>731 THROW 56804,N'FRAMEWORK_USAGE_LOCK_RESTORE',1;
        IF EXISTS
        (
            SELECT [ActualName],ROW_NUMBER() OVER(PARTITION BY [ActualName] ORDER BY [c].[column_id]) AS [Ordinal],
                   [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],
                   [c].[collation_name],[c].[is_nullable],[c].[is_identity]
            FROM @Targets AS [t] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[t].[ActualName])
            EXCEPT
            SELECT [ActualName],ROW_NUMBER() OVER(PARTITION BY [ActualName] ORDER BY [c].[column_id]),
                   [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],
                   [c].[collation_name],[c].[is_nullable],[c].[is_identity]
            FROM @Targets AS [t] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[t].[ExpectedName])
        ) OR EXISTS
        (
            SELECT [ActualName],ROW_NUMBER() OVER(PARTITION BY [ActualName] ORDER BY [c].[column_id]) AS [Ordinal],
                   [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],
                   [c].[collation_name],[c].[is_nullable],[c].[is_identity]
            FROM @Targets AS [t] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[t].[ExpectedName])
            EXCEPT
            SELECT [ActualName],ROW_NUMBER() OVER(PARTITION BY [ActualName] ORDER BY [c].[column_id]),
                   [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],
                   [c].[collation_name],[c].[is_nullable],[c].[is_identity]
            FROM @Targets AS [t] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[t].[ActualName])
        ) THROW 56805,N'FRAMEWORK_USAGE_FOUR_SCHEMAS',1;
        IF (SELECT COUNT(*) FROM @Targets AS [t] JOIN [tempdb].[sys].[columns] AS [c]
            ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[t].[ActualName]) WHERE [c].[collation_name] IS NOT NULL)<>14
            THROW 56806,N'FRAMEWORK_USAGE_TEXT_COLUMN_COUNT',1;
        DECLARE @Returned bigint,@More bit,@RowsJson nvarchar(max),@ExpectedJson nvarchar(max);
        EXEC [sys].[sp_executesql] N'
IF (SELECT COUNT_BIG(*) FROM [#Module166])<>1 THROW 56807,N''FRAMEWORK_USAGE_MODULE_COUNT'',1;
SELECT @rows=COUNT_BIG(*) FROM [#Usage166];
SELECT @more=[HasMoreRows] FROM [#Module166];
IF NOT EXISTS
(
    SELECT 1 FROM [#Module166]
    WHERE [ModuleName]=N''USP_FrameworkUsageFromQueryStore'' AND [StatusCode]=@status
      AND [IsPartial]=@partial AND [ReturnedRowCount]=@rows
      AND [CapturedAtUtc]>=CONVERT(datetime2(3),@before) AND [CapturedAtUtc]<=CONVERT(datetime2(3),@after)
      AND [MinimumExecutions]=COALESCE(@min,0)
      AND ([RequestedWindowDays]=NULLIF(@days,0) OR ([RequestedWindowDays] IS NULL AND NULLIF(@days,0) IS NULL))
      AND ([ErrorNumber]=@number OR ([ErrorNumber] IS NULL AND @number IS NULL))
      AND ([ErrorMessage]=@message OR ([ErrorMessage] IS NULL AND @message IS NULL))
) THROW 56808,N''FRAMEWORK_USAGE_MODULE_OUTPUT_PARITY'',1;
IF @invalid=1
BEGIN
    IF @status<>''INVALID_PARAMETER'' OR @partial<>1 OR @number IS NOT NULL OR @message IS NULL
       OR @rows<>0 OR @more<>0 OR (SELECT COUNT_BIG(*) FROM [#Warnings166])<>0
       OR (SELECT COUNT_BIG(*) FROM [#Source166])<>1
       OR NOT EXISTS(SELECT 1 FROM [#Source166] WHERE [SourceOrdinal]=1 AND [SourceName]=N''parameterValidation''
           AND [SourceObject]=N''procedure parameters'' AND [StatusCode]=''INVALID_PARAMETER'' AND [IsPartial]=1
           AND [ReturnedRowCount]=0 AND [RequiredPermission] IS NULL AND [ErrorNumber] IS NULL AND [ErrorMessage]=@message)
       OR EXISTS(SELECT 1 FROM [#Module166] WHERE [QueryStoreActualStateDesc] IS NOT NULL OR [QueryStoreReadonlyReason] IS NOT NULL)
        THROW 56809,N''FRAMEWORK_USAGE_INVALID_PROJECTED_SCHEMAS'',1;
END
ELSE
BEGIN
    IF (SELECT COUNT_BIG(*) FROM [#Source166])<>2 OR @partial<>0 OR @number IS NOT NULL
        THROW 56810,N''FRAMEWORK_USAGE_NATIVE_SOURCE_COUNT'',1;
    IF NOT EXISTS(SELECT 1 FROM [#Module166] WHERE ([QueryStoreActualStateDesc]=@desc OR ([QueryStoreActualStateDesc] IS NULL AND @desc IS NULL))
        AND ([QueryStoreReadonlyReason]=@reason OR ([QueryStoreReadonlyReason] IS NULL AND @reason IS NULL)))
        THROW 56811,N''FRAMEWORK_USAGE_NATIVE_OPTIONS'',1;
    IF NOT EXISTS(SELECT 1 FROM [#Source166] WHERE [SourceOrdinal]=1 AND [SourceName]=N''queryStoreOptions''
        AND [SourceObject]=N''sys.database_query_store_options'' AND [IsPartial]=0 AND [ReturnedRowCount]=1
        AND [StatusCode]=CASE WHEN @native IN(1,2) THEN ''AVAILABLE'' ELSE ''UNAVAILABLE_FEATURE'' END)
        THROW 56812,N''FRAMEWORK_USAGE_NATIVE_OPTIONS_SOURCE'',1;
    IF NOT EXISTS(SELECT 1 FROM [#Source166] WHERE [SourceOrdinal]=2 AND [SourceName]=N''frameworkUsage''
        AND [SourceObject]=N''sys.query_store_query + sys.query_store_plan + sys.query_store_runtime_stats''
        AND [IsPartial]=0 AND [ReturnedRowCount]=@rows
        AND [StatusCode]=CASE WHEN @native IN(1,2) THEN @status ELSE ''NOT_EXECUTED'' END)
        THROW 56813,N''FRAMEWORK_USAGE_NATIVE_AGGREGATE_SOURCE'',1;
    IF @native IN(1,2)
    BEGIN
        IF @status<>CASE WHEN @rows=0 THEN ''AVAILABLE_EMPTY'' ELSE ''AVAILABLE'' END OR @message IS NOT NULL
           OR EXISTS(SELECT 1 FROM [#Warnings166]) THROW 56814,N''FRAMEWORK_USAGE_ACTIVE_STATUS'',1;
    END
    ELSE IF @status<>''UNAVAILABLE_FEATURE'' OR @rows<>0 OR @more<>0 OR @message IS NULL
         OR (SELECT COUNT_BIG(*) FROM [#Warnings166])<>1
        THROW 56815,N''FRAMEWORK_USAGE_INACTIVE_STATUS'',1;
END;
IF (@max IS NULL OR @max=0) AND @more<>0 THROW 56816,N''FRAMEWORK_USAGE_UNLIMITED_SENTINEL'',1;
IF @max>0 AND (@rows>@max OR (@more=1 AND @rows<>@max)) THROW 56817,N''FRAMEWORK_USAGE_LIMIT_SENTINEL'',1;
IF @flag IS NULL
BEGIN
    IF @json IS NOT NULL THROW 56818,N''FRAMEWORK_USAGE_NULL_JSON_FLAG'',1;
END
ELSE
BEGIN
    IF COALESCE(ISJSON(@json),0)<>1 THROW 56819,N''FRAMEWORK_USAGE_JSON_VALIDITY'',1;
    IF EXISTS(SELECT [key],[type] FROM OPENJSON(@json) EXCEPT SELECT * FROM (VALUES(N''meta'',5),(N''usage'',4),(N''sourceStatus'',4),(N''warnings'',4)) AS [e]([k],[t]))
       OR (SELECT COUNT(*) FROM OPENJSON(@json))<>4 THROW 56820,N''FRAMEWORK_USAGE_JSON_TOP_KEYS'',1;
    DECLARE @meta nvarchar(max);
    SELECT @meta=(SELECT N''FrameworkUsageFromQueryStore'' AS [resultName],1 AS [schemaVersion],
        [CapturedAtUtc] AS [generatedAtUtc],[StatusCode] AS [statusCode],[IsPartial] AS [isPartial],
        [QueryStoreActualStateDesc] AS [queryStoreActualStateDesc],[QueryStoreReadonlyReason] AS [queryStoreReadonlyReason],
        [RequestedWindowDays] AS [requestedWindowDays],@min AS [minimumExecutions],
        [ReturnedRowCount] AS [returnedRowCount],[HasMoreRows] AS [hasMoreRows],
        [ErrorNumber] AS [errorNumber],[ErrorMessage] AS [errorMessage]
        FROM [#Module166] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
    IF JSON_QUERY(@json,N''$.meta'')<>@meta OR (SELECT COUNT(*) FROM OPENJSON(@json,N''$.meta''))<>13
        THROW 56821,N''FRAMEWORK_USAGE_FULL_META_NULL_PARITY'',1;
    SELECT @usage=(SELECT * FROM [#Usage166] ORDER BY [ExecutionCount] DESC,[ProcedureName] FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF COALESCE(@usage,N''[]'')<>JSON_QUERY(@json,N''$.usage'') THROW 56822,N''FRAMEWORK_USAGE_11_FIELD_PARITY'',1;
    DECLARE @sources nvarchar(max),@warnings nvarchar(max);
    SELECT @sources=(SELECT * FROM [#Source166] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
    SELECT @warnings=(SELECT * FROM [#Warnings166] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF COALESCE(@sources,N''[]'')<>JSON_QUERY(@json,N''$.sourceStatus'')
       OR COALESCE(@warnings,N''[]'')<>JSON_QUERY(@json,N''$.warnings'')
        THROW 56823,N''FRAMEWORK_USAGE_FULL_SOURCE_WARNING_PARITY'',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@json,N''$.usage'') AS [a] WHERE (SELECT COUNT(*) FROM OPENJSON([a].[value]))<>11)
       OR EXISTS(SELECT 1 FROM OPENJSON(@json,N''$.sourceStatus'') AS [a] WHERE (SELECT COUNT(*) FROM OPENJSON([a].[value]))<>11)
       OR EXISTS(SELECT 1 FROM OPENJSON(@json,N''$.warnings'') AS [a] WHERE (SELECT COUNT(*) FROM OPENJSON([a].[value]))<>5)
        THROW 56824,N''FRAMEWORK_USAGE_ARRAY_NULL_PROPERTIES'',1;
END;
',N'@json nvarchar(max),@status varchar(40),@partial bit,@number int,@message nvarchar(2048),
@before datetimeoffset(7),@after datetimeoffset(7),@min bigint,@days int,@invalid bit,@max int,@flag bit,
@native smallint,@desc nvarchar(60),@reason bigint,@rows bigint OUTPUT,@more bit OUTPUT,@usage nvarchar(max) OUTPUT',
            @json=@Json,@status=@Status,@partial=@Partial,@number=@Number,@message=@Message,
            @before=@Before,@after=@After,@min=@Min,@days=@Days,@invalid=@Invalid,@max=@Max,@flag=@JsonFlag,
            @native=@NativeState,@desc=@NativeDesc,@reason=@NativeReason,
            @rows=@Returned OUTPUT,@more=@More OUTPUT,@usage=@RowsJson OUTPUT;
        IF @PositiveFixture=1 AND @Invalid=0
        BEGIN
            IF NOT EXISTS(SELECT 1 FROM [sys].[database_query_store_options] WHERE [actual_state]=1
                AND [actual_state_desc]=@NativeDesc AND [readonly_reason]=@NativeReason)
                THROW 56825,N'FRAMEWORK_USAGE_FIXTURE_READONLY_CHANGED',1;
            SET @Cutoff=CASE WHEN @Days>0 THEN DATEADD(DAY,-@Days,@Before) ELSE NULL END;
            IF @Days>0 AND EXISTS(SELECT 1 FROM [#NativeStats166]
                WHERE [LastTime]>=@Cutoff AND [LastTime]<DATEADD(DAY,-@Days,@After))
                THROW 56826,N'FRAMEWORK_USAGE_WINDOW_BOUNDARY_MOVED',1;
            TRUNCATE TABLE [#OracleUsage166];
            INSERT [#OracleUsage166]
            SELECT [ProcedureName],SUM([Executions]),MAX([LastTime]),
                   CONVERT(decimal(19,3),SUM([Duration]*CONVERT(float,[Executions]))/NULLIF(SUM(CONVERT(float,[Executions])),0.0)/1000.0),
                   CONVERT(decimal(19,3),SUM([Cpu]*CONVERT(float,[Executions]))/NULLIF(SUM(CONVERT(float,[Executions])),0.0)/1000.0),
                   CONVERT(decimal(19,2),SUM([Reads]*CONVERT(float,[Executions]))/NULLIF(SUM(CONVERT(float,[Executions])),0.0)),
                   CONVERT(decimal(19,2),SUM([MemoryPages]*8.0*CONVERT(float,[Executions]))/NULLIF(SUM(CONVERT(float,[Executions])),0.0)),
                   CONVERT(bigint,COUNT(DISTINCT [PlanId])),CONVERT(bigint,COUNT(DISTINCT [QueryId])),MIN([FirstTime]),MAX([LastTime])
            FROM [#NativeStats166]
            WHERE @Cutoff IS NULL OR [LastTime]>=@Cutoff
            GROUP BY [ProcedureName] HAVING SUM([Executions])>=@Min;
            IF @Case=6 AND (SELECT COUNT(*) FROM [#OracleUsage166]
                WHERE [ProcedureName] IN(N'USP_ExampleFrameworkUsageÄ',N'usp_ExampleFrameworkUsageÄ'))<>1
                THROW 56841,N'FRAMEWORK_USAGE_NATIVE_SELECTIVE_MINIMUM',1;
            SELECT @OracleCount=COUNT_BIG(*) FROM [#OracleUsage166];
            SET @Limit=CASE WHEN @Max IS NULL OR @Max=0 THEN 9223372036854775807 ELSE @Max END;
            SELECT @ExpectedJson=(SELECT TOP(@Limit) * FROM [#OracleUsage166]
                ORDER BY [ExecutionCount] DESC,[ProcedureName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            IF COALESCE(@RowsJson,N'[]')<>COALESCE(@ExpectedJson,N'[]')
                THROW 56827,N'FRAMEWORK_USAGE_INDEPENDENT_NATIVE_11_FIELDS',1;
            IF @Returned<>CASE WHEN @OracleCount>@Limit THEN @Limit ELSE @OracleCount END
               OR @More<>CASE WHEN @OracleCount>@Limit THEN 1 ELSE 0 END
                THROW 56828,N'FRAMEWORK_USAGE_NATIVE_LIMIT_PLUS_ONE',1;
            SET @PositiveCases+=1;
        END;
        SET @CoreCases+=1;
        IF @Case IN(4,8,9) OR (@PositiveFixture=1 AND @Case IN(0,2,5))
        BEGIN
            CREATE TABLE [#ConsolePositive166]([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [ProcedureName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [ExecutionCount] bigint NOT NULL,
                [LastExecutionTime] datetimeoffset(7) NULL,
                [AvgDurationMs] decimal(19,3) NULL,
                [AvgCpuMs] decimal(19,3) NULL,
                [AvgLogicalReads] decimal(19,2) NULL,
                [AvgMemoryGrantKB] decimal(19,2) NULL,
                [PlanCount] bigint NOT NULL,
                [QueryCount] bigint NOT NULL,
                [FirstSeen] datetimeoffset(7) NULL,
                [LastSeen] datetimeoffset(7) NULL
            );
            CREATE TABLE [#ConsoleEmpty166]([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
            IF @Case IN(4,8,9)
                INSERT [#ConsoleEmpty166]
                EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
                    @MaxZeilen=@Max,@MinAusfuehrungen=@Min,@ZeitraumTage=@Days,@LockTimeoutMs=@Lock,
                    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
                    @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
            ELSE
                INSERT [#ConsolePositive166]
                EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
                    @MaxZeilen=@Max,@MinAusfuehrungen=@Min,@ZeitraumTage=@Days,@LockTimeoutMs=@Lock,
                    @ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
                    @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
            IF @@LOCK_TIMEOUT<>731 OR COALESCE(ISJSON(@Json),0)<>1 OR @Status IS NULL OR @Partial IS NULL THROW 56829,N'FRAMEWORK_USAGE_CONSOLE_LOCK_JSON',1;
            IF @Case IN(4,8,9)
            BEGIN
                IF (SELECT COUNT(*) FROM [#ConsoleEmpty166])<>1
                   OR NOT EXISTS(SELECT 1 FROM [#ConsoleEmpty166]
                       WHERE [Ergebnis]=N'Keine sichtbare Framework-Nutzung im gewählten Query-Store-Scope'
                         AND [Status] IS NULL AND [Hinweis] IS NULL)
                   OR JSON_QUERY(@Json,N'$.usage')<>N'[]'
                    THROW 56830,N'FRAMEWORK_USAGE_EMPTY_CONSOLE_THREE_FIELDS',1;
                SET @ConsoleEmpty+=1;
            END
            ELSE
            BEGIN
                TRUNCATE TABLE [#ExpectedUsage166];
                INSERT [#ExpectedUsage166]
                SELECT * FROM OPENJSON(@Json,N'$.usage') WITH
                (
                    [ProcedureName] sysname '$.ProcedureName',
                    [ExecutionCount] bigint '$.ExecutionCount',
                    [LastExecutionTime] datetimeoffset(7) '$.LastExecutionTime',
                    [AvgDurationMs] decimal(19,3) '$.AvgDurationMs',
                    [AvgCpuMs] decimal(19,3) '$.AvgCpuMs',
                    [AvgLogicalReads] decimal(19,2) '$.AvgLogicalReads',
                    [AvgMemoryGrantKB] decimal(19,2) '$.AvgMemoryGrantKB',
                    [PlanCount] bigint '$.PlanCount',
                    [QueryCount] bigint '$.QueryCount',
                    [FirstSeen] datetimeoffset(7) '$.FirstSeen',
                    [LastSeen] datetimeoffset(7) '$.LastSeen'
                );
                IF (SELECT COUNT_BIG(*) FROM [#ConsolePositive166])<>(SELECT COUNT_BIG(*) FROM [#ExpectedUsage166])
                   OR EXISTS(SELECT 1 FROM [#ConsolePositive166] WHERE [Ergebnis]<>N'Framework-Nutzung aus Query Store' OR [Ergebnis] IS NULL)
                   OR EXISTS(SELECT [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs],[AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount],[FirstSeen],[LastSeen] FROM [#ConsolePositive166] EXCEPT SELECT * FROM [#ExpectedUsage166])
                   OR EXISTS(SELECT * FROM [#ExpectedUsage166] EXCEPT SELECT [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs],[AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount],[FirstSeen],[LastSeen] FROM [#ConsolePositive166])
                    THROW 56831,N'FRAMEWORK_USAGE_POSITIVE_CONSOLE_UNORDERED_12_FIELDS',1;
                SET @ConsolePositive+=1;
            END;
            IF JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status
               OR TRY_CONVERT(bit,JSON_VALUE(@Json,N'$.meta.isPartial'))<>@Partial
                THROW 56832,N'FRAMEWORK_USAGE_CONSOLE_OUTPUT_PARITY',1;
            DROP TABLE [#ConsolePositive166]; DROP TABLE [#ConsoleEmpty166];
        END;
        DROP TABLE [#Module166]; DROP TABLE [#Usage166]; DROP TABLE [#Source166]; DROP TABLE [#Warnings166];
        SET @Case+=1;
    END;
    DECLARE @Consumer int=0;
    WHILE @Consumer<3
    BEGIN
        SET @Json=N'not-cleared';
        DECLARE @OutputMode varchar(16)=CASE WHEN @Consumer=0 THEN 'UNSUPPORTED' ELSE 'NONE' END;
        DECLARE @ConsumerMap nvarchar(max)=CASE WHEN @Consumer=1 THEN @Map ELSE NULL END;
        DECLARE @ConsumerJson bit=CASE WHEN @Consumer=2 THEN 0 ELSE 1 END;
        EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
            @MaxZeilen=1,@ResultSetArt=@OutputMode,@ResultTablesJson=@ConsumerMap,
            @JsonErzeugen=@ConsumerJson,@Json=@Json OUTPUT,@PrintMeldungen=0,
            @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@Number OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF @@LOCK_TIMEOUT<>731 THROW 56833,N'FRAMEWORK_USAGE_CONSUMER_LOCK',1;
        IF @Consumer<2 AND (@Status<>'INVALID_PARAMETER' OR @Partial<>1 OR @Number IS NOT NULL
            OR @Message IS NULL OR COALESCE(ISJSON(@Json),0)<>1 OR JSON_QUERY(@Json,N'$.usage')<>N'[]'
            OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@Status
            OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>1)
            THROW 56834,N'FRAMEWORK_USAGE_INVALID_CONSUMER_JSON_OUTPUT',1;
        IF @Consumer=2 AND @Json IS NOT NULL THROW 56835,N'FRAMEWORK_USAGE_DISABLED_JSON_CLEARED',1;
        SET @CoreCases+=1;
        SET @Consumer+=1;
    END;
    CREATE TABLE [#Preflight166]([Dummy] int NULL);
    DECLARE @BadMap nvarchar(max),@Caught int,@Preflight int=0;
    WHILE @Preflight<4
    BEGIN
        SET @BadMap=CASE @Preflight
            WHEN 0 THEN N'{"unknown":"#Preflight166"}'
            WHEN 1 THEN N'{"usage":"#MissingFrameworkUsage166"}'
            WHEN 2 THEN N'{"usage":"monitor.ExampleFrameworkUsage"}'
            WHEN 3 THEN N'{"usage":"#Preflight166","warnings":"#Preflight166"}' END;
        SET @Caught=NULL;
        BEGIN TRY
            EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
                @MaxZeilen=-1,@ResultSetArt='TABLE',@ResultTablesJson=@BadMap,@PrintMeldungen=0;
        END TRY
        BEGIN CATCH
            SET @Caught=ERROR_NUMBER();
        END CATCH;
        IF COALESCE(@Caught,0)<>51011 OR @@LOCK_TIMEOUT<>731
            THROW 56836,N'FRAMEWORK_USAGE_EARLY_TABLE_PREFLIGHT',1;
        IF NOT EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#Preflight166') AND [name]=N'Dummy')
            THROW 56837,N'FRAMEWORK_USAGE_REJECTED_MAPPING_MUTATION',1;
        SET @PreflightCases+=1;
        SET @Preflight+=1;
    END;
    IF @PositiveFixture=1
    BEGIN
        IF @PositiveCases<>8 OR @ConsolePositive<>3
            THROW 56838,N'FRAMEWORK_USAGE_POSITIVE_COVERAGE',1;
        SET @PositiveFixtureStatus='PASS';
    END;
    IF @CoreCases<>22 OR @ConsoleEmpty<>3 OR @PreflightCases<>4
        THROW 56839,N'FRAMEWORK_USAGE_CORE_COVERAGE',1;
    DECLARE @RestoreSuccess nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSuccess;
    SELECT N'FrameworkUsageFromQueryStore' AS [ContractName],@FrameworkLevel AS [FrameworkCompatibilityLevel],
           @CoreCases AS [CoreCases],@PreflightCases AS [MappingPreflightCases],
           @PositiveFixtureStatus AS [PositiveFixtureStatus],@PositiveCases AS [PositiveNativeCases],
           @ConsolePositive AS [PositiveConsoleCaptures],@ConsoleEmpty AS [EmptyConsoleCaptures];
    RAISERROR(N'FRAMEWORK_USAGE_COLLATION_CORE PASS; positive fixture status is reported separately.',10,1) WITH NOWAIT;
END TRY
BEGIN CATCH
    DECLARE @RestoreFailure nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreFailure;
    THROW;
END CATCH;
GO
