USE [DeineDatenbank];
GO
/* Prüft die drei bestehenden Orchestratoren ohne Feature-/Konfigurations-DDL.
   TABLE und SQL-erfasstes CONSOLE prüfen vollständige Modulzeilen;
   MaxZeilen begrenzt ausschließlich die jeweiligen Children, nicht moduleStatus.
   Plan Cache verwendet einen unabhängig als leer bestätigten synthetischen Hash.
   Query Store bleibt in der Frameworkdatenbank; XE verwendet ausschließlich einen
   unabhängig als fehlend bestätigten Unicode-Sessionnamen, ohne Target-Flush.
   Drei CONSOLE-Pfade (Plan Cache 3/7, Query Store 3) laufen direkt: Der bestehende
   Candidatehelper emittiert dort leere dreifeldrige WarningTable-Proben, die nicht
   in ein sechsfeldriges INSERT-EXEC-Ziel passen. Ihre JSON-Verträge werden geprüft;
   tatsächliche CONSOLE-Zeilenparität benötigt zusätzlich einen Client-Capture.
   Snapshotstatus, Childobjekte, Metadaten und Warnungen werden getrennt geprüft.
   Nur Plan Cache besitzt ein JSON-modules-Array. RAW prüft hier ausschließlich
   den ungültigen Leerscope und JSON, keine positive Mehrfachresultset-Parität.
   Keine positive ERROR_HANDLED-/Berechtigungs-/Ereignis- oder Plan-XML-Evidenz.
   Frameworklevel 150/160/170 ist zulässig; native Nachweise bleiben laufbezogen. */
SET NOCOUNT ON;
DECLARE @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @OriginalLockTimeout int=@@LOCK_TIMEOUT,@Proc int=1,@Case int,@Route int,@Invalid bit,@All bit,@Pair bit,
        @Mode varchar(16),@Limit int,@Mapping nvarchar(max),@Json nvarchar(max),@RowsJson nvarchar(max),
        @Call nvarchar(max),@Exec nvarchar(max),@Name nvarchar(128),@ExpectedStatus varchar(40),
        @FrameworkName nvarchar(max)=QUOTENAME(DB_NAME()),@XeName nvarchar(128)=N'ExampleOrchestratorÄ',
        @XeNames nvarchar(max)=N'[ExampleOrchestratorÄ]',@Hash binary(8)=0xF0E1D2C3B4A59687,
        @From datetime2(7),@To datetime2(7),@Bad bit,@Snapshot bit,@PositiveCalls int=0,@DirectCalls int=0,@Direct bit,@EmptyCalls int=0,@ExpectedRowsJson nvarchar(max),
        @SchemaId int,@TargetId int,@Preflight int,@Caught bit,@Before datetime2(3),@After datetime2(3);
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 56900,N'Orchestrator framework compatibility level is outside the contract.',1;
CREATE TABLE [#ExampleOrchestratorSchema]
(
      [ExecutionOrdinal] tinyint NOT NULL
    , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleOrchestratorExpected]
(
      [ExecutionOrdinal] tinyint NOT NULL
    , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleOrchestratorActual]
(
      [ExecutionOrdinal] tinyint NOT NULL
    , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleOrchestratorConsole]
(
      [Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ExecutionOrdinal] tinyint NOT NULL
    , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorNumber] int NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleOrchestratorEmptyConsole]
(
      [Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [Hinweis] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
CREATE TABLE [#ExampleOrchestratorChildren]
(
      [ProcNumber] int NOT NULL,[ExecutionOrdinal] tinyint NOT NULL
    , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [JsonKey] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ResultName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
INSERT [#ExampleOrchestratorChildren] VALUES
 (1,1,N'USP_QueryStats',N'queryStats',N'QueryStats'),
 (1,2,N'USP_QueryHashAnalysis',N'queryHashes',N'QueryHashAnalysis'),
 (1,3,N'USP_PlanCacheHealth',N'planCacheHealth',N'PlanCacheHealth'),
 (1,4,N'USP_ShowplanAnalysis',N'showplan',N'ShowplanAnalysis'),
 (2,1,N'USP_QueryStoreStatus',N'status',N'QueryStoreStatus'),
 (2,2,N'USP_QueryStoreRuntimeStats',N'runtimeStats',N'QueryStoreRuntimeStats'),
 (2,3,N'USP_QueryStoreWaitStats',N'waitStats',N'QueryStoreWaitStats'),
 (2,4,N'USP_QueryStorePlanChanges',N'planChanges',N'QueryStorePlanChanges'),
 (2,5,N'USP_QueryStoreRegressions',N'regressions',N'QueryStoreRegressions'),
 (2,6,N'USP_QueryStoreForcedPlans',N'forcedPlans',N'QueryStoreForcedPlans'),
 (2,7,N'USP_QueryStoreHints',N'queryHints',N'QueryStoreHints'),
 (2,8,N'USP_QueryStoreReplicaAnalysis',N'replicaContext',N'QueryStoreReplicaAnalysis'),
 (2,9,N'USP_IntelligentQueryProcessingAnalysis',N'intelligentQueryProcessing',N'IntelligentQueryProcessingAnalysis'),
 (3,1,N'USP_ExtendedEventsSessions',N'inventory',N'ExtendedEventsSessions'),
 (3,2,N'USP_ExtendedEventsTargetRuntime',N'targetRuntime',N'ExtendedEventsTargetRuntime'),
 (3,3,N'USP_ExtendedEventsReadEvents',N'events',N'ExtendedEventsReadEvents'),
 (3,4,N'USP_ExtendedEventsDeadlocks',N'deadlocks',N'ExtendedEventsDeadlocks'),
 (3,5,N'USP_ExtendedEventsBlockedProcesses',N'blockedProcesses',N'ExtendedEventsBlockedProcesses');
CREATE TABLE [#ExampleOrchestratorKeys]
 ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[JsonType] int NOT NULL);
CREATE TABLE [#ExampleOrchestratorWarnings]
 ([ExecutionOrdinal] tinyint NOT NULL,[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
  [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorNumber] int NULL,
  [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
BEGIN TRY
    WHILE @Proc<=3
    BEGIN
        SET @Name=CASE @Proc WHEN 1 THEN N'PlanCacheAnalysis' WHEN 2 THEN N'QueryStoreAnalysis' ELSE N'ExtendedEventsAnalysis' END;
        SET @Case=0;
        /* 0/1/2: minimaler Child mit NULL/0/1; 3: alle Children mit Limit 1;
           4: alle Children aus; 5: negatives Limit; 6: ungültiger Modus/Zeitraum;
           7: zwei Children, beim Plan Cache mit gemeinsamem Snapshot. */
        WHILE @Case<8
        BEGIN
            SET @Limit=CASE @Case WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 5 THEN -1 ELSE 1 END;
            SET @All=CASE WHEN @Case=3 THEN 1 ELSE 0 END;
            SET @Pair=CASE WHEN @Case=7 THEN 1 ELSE 0 END;
            SET @Invalid=CASE WHEN @Case IN(4,5,6) THEN 1 ELSE 0 END;
            SET @Bad=CASE WHEN @Case=6 THEN 1 ELSE 0 END;
            SET @Snapshot=CASE WHEN @Proc=1 AND @Case IN(3,7) THEN 1 ELSE 0 END;
            SET @From=DATEADD(MINUTE,-1,SYSUTCDATETIME()); SET @To=SYSUTCDATETIME();
            IF @Bad=1 AND @Proc=2 SET @From=DATEADD(MINUTE,1,@To);
            IF EXISTS(SELECT 1 FROM [sys].[dm_exec_query_stats] WHERE [query_hash]=@Hash)
                THROW 56901,N'The synthetic plan-cache hash is not empty.',1;
            IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@XeName)
               OR EXISTS(SELECT 1 FROM [sys].[dm_xe_sessions] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@XeName)
                THROW 56902,N'The synthetic XE name already exists.',1;
            DECLARE @A bit=CASE WHEN @Case=4 OR (@Proc=1 AND @Case=7) THEN 0 ELSE 1 END;
            IF @Proc=1
                SET @Call=N'EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=@pPair,@MitQueryHashAnalysis=@pPair,@MitPlanCacheHealth=@pA,@MitShowplanAnalysis=@pAll,@DatabaseNames=@pDb,@QueryHash=@pHash,@HighImpactConfirmed=1,@AnalyseModus=@pPlanMode,@MaxAnalyseobjekte=1,@MaxZeilen=@pLimit,@ResultSetArt=@pMode,@ResultTablesJson=@pMap,@JsonErzeugen=1,@Json=@pJson OUTPUT,@PrintMeldungen=0;';
            ELSE IF @Proc=2
                SET @Call=N'EXEC [monitor].[USP_QueryStoreAnalysis] @QueryStoreDatabaseNames=@pDb,@MitStatus=@pA,@MitRuntimeStats=@pPair,@MitWaitStats=@pAll,@MitPlanChanges=@pAll,@MitRegressionen=@pAll,@MitForcedPlans=@pAll,@MitHints=@pAll,@MitReplicaKontext=@pAll,@MitIQP=@pAll,@HighImpactConfirmed=1,@VonUtc=@pFrom,@BisUtc=@pTo,@MaxZeilen=@pLimit,@ResultSetArt=@pMode,@ResultTablesJson=@pMap,@JsonErzeugen=1,@Json=@pJson OUTPUT,@PrintMeldungen=0;';
            ELSE
                SET @Call=N'EXEC [monitor].[USP_ExtendedEventsAnalysis] @ExtendedEventSessionNames=@pXeNames,@SourceExtendedEventSessionName=@pXeNames,@MitSessionInventar=@pA,@MitTargetRuntime=@pAll,@MitEvents=@pPair,@MitDeadlocks=@pAll,@MitBlockedProcesses=@pAll,@Quelle=@pSource,@BestaetigeTargetFlush=0,@HighImpactConfirmed=1,@VonUtc=@pFrom,@BisUtc=@pTo,@MaxZeilen=@pLimit,@ResultSetArt=@pMode,@ResultTablesJson=@pMap,@JsonErzeugen=1,@Json=@pJson OUTPUT,@PrintMeldungen=0;';
            DECLARE @SelectedPair bit=CASE WHEN @All=1 OR @Pair=1 THEN 1 ELSE 0 END,
                    @PlanMode varchar(16)=CASE WHEN @Bad=1 THEN 'UNSUPPORTED' ELSE 'TOP' END,
                    @Source varchar(20)=CASE WHEN @Bad=1 THEN 'UNSUPPORTED' ELSE 'AUTO' END,
                    @Defs nvarchar(max)=N'@pA bit,@pPair bit,@pAll bit,@pDb nvarchar(max),@pHash binary(8),@pXeNames nvarchar(max),@pPlanMode varchar(16),@pSource varchar(20),@pFrom datetime2(7),@pTo datetime2(7),@pLimit int,@pMode varchar(16),@pMap nvarchar(max),@pJson nvarchar(max) OUTPUT';
            SET @Route=0;
            WHILE @Route<2
            BEGIN
                SET @Json=NULL; SET @RowsJson=NULL;
                TRUNCATE TABLE [#ExampleOrchestratorExpected]; TRUNCATE TABLE [#ExampleOrchestratorActual];
                TRUNCATE TABLE [#ExampleOrchestratorConsole]; TRUNCATE TABLE [#ExampleOrchestratorEmptyConsole];
                SET @Direct=CASE WHEN @Route=1 AND ((@Proc=1 AND @Case IN(3,7)) OR (@Proc=2 AND @Case=3)) THEN 1 ELSE 0 END;
                SET @Mode=CASE WHEN @Route=0 THEN 'TABLE' ELSE 'CONSOLE' END;
                SET @Mapping=CASE WHEN @Route=0 THEN N'{"moduleStatus":"#ExampleOrchestratorExport"}' ELSE NULL END;
                IF @Route=0
                BEGIN
                    CREATE TABLE [#ExampleOrchestratorExport]([Dummy] int NULL);
                    SET @Exec=@Call;
                END
                ELSE IF @Direct=1 SET @Exec=@Call;
                ELSE SET @Exec=CASE WHEN @Invalid=1 THEN N'INSERT [#ExampleOrchestratorEmptyConsole] ' ELSE N'INSERT [#ExampleOrchestratorConsole] ' END+@Call;
                SET @Before=SYSUTCDATETIME();
                EXEC [sys].[sp_executesql] @Exec,@Defs,@pA=@A,@pPair=@SelectedPair,@pAll=@All,@pDb=@FrameworkName,
                     @pHash=@Hash,@pXeNames=@XeNames,@pPlanMode=@PlanMode,@pSource=@Source,@pFrom=@From,@pTo=@To,
                     @pLimit=@Limit,@pMode=@Mode,@pMap=@Mapping,@pJson=@Json OUTPUT;
                SET @After=SYSUTCDATETIME();
                IF ISJSON(@Json)<>1 THROW 56903,N'Orchestrator JSON is not valid.',1;
                IF @Invalid=0
                BEGIN
                    INSERT [#ExampleOrchestratorExpected]
                    SELECT [ExecutionOrdinal],[ModuleName],
                           CASE WHEN @Proc=1 AND @Snapshot=1 AND [ExecutionOrdinal] IN(1,2,4) THEN 'REUSED_PARENT_SNAPSHOT'
                                WHEN @Proc=2 AND [ExecutionOrdinal] IN(8,9) THEN JSON_VALUE(@Json,N'$.'+[JsonKey]+N'.meta.statusCode')
                                ELSE 'EXECUTED' END,
                           CASE WHEN @Proc=2 AND [ExecutionOrdinal] IN(8,9) THEN TRY_CONVERT(int,JSON_VALUE(@Json,N'$.'+[JsonKey]+N'.meta.errorNumber')) END,
                           CASE WHEN @Proc=2 AND [ExecutionOrdinal] IN(8,9) THEN JSON_VALUE(@Json,N'$.'+[JsonKey]+N'.meta.errorMessage') END
                    FROM [#ExampleOrchestratorChildren]
                    WHERE [ProcNumber]=@Proc AND
                         (@All=1 OR (@Proc=1 AND ((@A=1 AND [ExecutionOrdinal]=3) OR (@Pair=1 AND [ExecutionOrdinal] IN(1,2))))
                          OR (@Proc=2 AND ([ExecutionOrdinal]=1 OR (@Pair=1 AND [ExecutionOrdinal]=2)))
                          OR (@Proc=3 AND ([ExecutionOrdinal]=1 OR (@Pair=1 AND [ExecutionOrdinal]=3))));
                END;
                SET @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER'
                    WHEN EXISTS(SELECT 1 FROM [#ExampleOrchestratorExpected] WHERE [InvocationStatus] NOT IN('EXECUTED','REUSED_PARENT_SNAPSHOT','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED')) THEN 'AVAILABLE_LIMITED'
                    WHEN EXISTS(SELECT 1 FROM [#ExampleOrchestratorExpected] WHERE [InvocationStatus]='AVAILABLE_WITH_FINDING') THEN 'AVAILABLE_WITH_FINDING'
                    ELSE 'AVAILABLE' END;
                IF JSON_VALUE(@Json,N'$.meta.resultName') IS NULL OR JSON_VALUE(@Json,N'$.meta.resultName')<>@Name
                   OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
                   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
                   OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
                   OR JSON_VALUE(@Json,N'$.meta.statusCode') IS NULL OR JSON_VALUE(@Json,N'$.meta.statusCode')<>@ExpectedStatus
                   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.meta'))<>4
                   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.meta') WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS NOT IN(N'resultName',N'schemaVersion',N'generatedAtUtc',N'statusCode') OR [type]<>CASE WHEN [key]=N'schemaVersion' THEN 2 ELSE 1 END)
                    THROW 56904,N'Orchestrator metadata differs from the complete child contract.',1;
                TRUNCATE TABLE [#ExampleOrchestratorKeys];
                INSERT [#ExampleOrchestratorKeys] VALUES(N'meta',5),(N'warnings',4);
                IF @Proc=1 INSERT [#ExampleOrchestratorKeys] VALUES(N'modules',4);
                INSERT [#ExampleOrchestratorKeys]
                SELECT [JsonKey],CASE WHEN EXISTS(SELECT 1 FROM [#ExampleOrchestratorExpected] [e] WHERE [e].[ExecutionOrdinal]=[c].[ExecutionOrdinal]) THEN 5 ELSE 0 END
                FROM [#ExampleOrchestratorChildren] [c] WHERE [ProcNumber]=@Proc;
                IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>(SELECT COUNT(*) FROM [#ExampleOrchestratorKeys])
                   OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json) EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleOrchestratorKeys])
                   OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleOrchestratorKeys] EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
                    THROW 56905,N'Orchestrator child selection or public JSON keys changed.',1;
                IF EXISTS(SELECT 1 FROM [#ExampleOrchestratorChildren] [c] JOIN [#ExampleOrchestratorExpected] [e] ON [e].[ExecutionOrdinal]=[c].[ExecutionOrdinal]
                          WHERE [c].[ProcNumber]=@Proc AND
                          (JSON_VALUE(@Json,N'$.'+[c].[JsonKey]+N'.meta.resultName') IS NULL OR JSON_VALUE(@Json,N'$.'+[c].[JsonKey]+N'.meta.resultName')<>[c].[ResultName]))
                    THROW 56906,N'A selected native child payload has the wrong identity.',1;
                /* Unabhängige native Identitäten: ausgewählte Frameworkdatenbank,
                   leerer Hashscope und fehlende Session, keine Featureaktivierung. */
                IF @Invalid=0 AND @Proc=2 AND
                   ((SELECT COUNT(*) FROM OPENJSON(@Json,N'$.status.queryStoreStatus'))<>1 OR
                    NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.status.queryStoreStatus')
                        WITH([DatabaseId] int,[DatabaseName] nvarchar(128))
                        WHERE [DatabaseId]=DB_ID() AND [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS))
                    THROW 56916,N'The selected Query Store child database identity differs from the native framework identity.',1;
                IF @Invalid=0 AND @Proc=1 AND @Snapshot=1 AND
                   ((SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queryStats.queries'))<>0 OR
                    (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.queryHashes.queryHashes'))<>0)
                    THROW 56917,N'The independently empty native hash produced query rows.',1;
                IF @Invalid=0 AND @Proc=3 AND
                   (TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.inventory.meta.sessionCount')) IS NULL OR
                    TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.inventory.meta.sessionCount'))<>0 OR
                    EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inventory.sessions')) OR
                    EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inventory.events')) OR
                    EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inventory.actions')) OR
                    EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inventory.targets')) OR
                    EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.inventory.fields')))
                    THROW 56918,N'The independently missing native XE session produced inventory rows.',1;
                IF @Route=0
                BEGIN
                    SET @SchemaId=OBJECT_ID(N'tempdb..#ExampleOrchestratorSchema'); SET @TargetId=OBJECT_ID(N'tempdb..#ExampleOrchestratorExport');
                    IF EXISTS
                    (SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=@SchemaId
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=@TargetId)
                       OR EXISTS
                    (SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=@TargetId
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name],[system_type_id],[max_length],[precision],[scale],[collation_name],[is_nullable],[is_identity] FROM [tempdb].[sys].[columns] WHERE [object_id]=@SchemaId)
                        THROW 56907,N'The independent five-field TABLE schema or three collations differ.',1;
                    EXEC [sys].[sp_executesql] N'INSERT [#ExampleOrchestratorActual] SELECT * FROM [#ExampleOrchestratorExport]; SELECT @pRows=(SELECT * FROM [#ExampleOrchestratorExport] ORDER BY [ExecutionOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@pRows nvarchar(max) OUTPUT',@pRows=@RowsJson OUTPUT;
                    DROP TABLE [#ExampleOrchestratorExport];
                END
                ELSE IF @Direct=1
                    SET @DirectCalls+=1;
                ELSE IF @Invalid=0
                BEGIN
                    INSERT [#ExampleOrchestratorActual] SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage] FROM [#ExampleOrchestratorConsole];
                    IF EXISTS(SELECT 1 FROM [#ExampleOrchestratorConsole] WHERE [Ergebnis] IS NULL OR [Ergebnis]<>@Name)
                        THROW 56908,N'The six-field positive CONSOLE label differs.',1;
                    SELECT @RowsJson=(SELECT * FROM [#ExampleOrchestratorActual] ORDER BY [ExecutionOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
                    SET @PositiveCalls+=1;
                END
                ELSE
                BEGIN
                    IF (SELECT COUNT(*) FROM [#ExampleOrchestratorEmptyConsole])<>1
                       OR NOT EXISTS(SELECT 1 FROM [#ExampleOrchestratorEmptyConsole] WHERE [Ergebnis]=N'Keine fachlichen Ergebnisse' AND [Status] IS NULL AND [Hinweis] IS NULL)
                        THROW 56909,N'The existing three-field empty CONSOLE contract differs.',1;
                    SET @EmptyCalls+=1;
                END;
                IF @Direct=0 AND
                   ((SELECT COUNT(*) FROM [#ExampleOrchestratorActual])<>(SELECT COUNT(*) FROM [#ExampleOrchestratorExpected])
                    OR EXISTS(SELECT * FROM [#ExampleOrchestratorActual] EXCEPT SELECT * FROM [#ExampleOrchestratorExpected])
                    OR EXISTS(SELECT * FROM [#ExampleOrchestratorExpected] EXCEPT SELECT * FROM [#ExampleOrchestratorActual]))
                    THROW 56910,N'Module rows, original ordinals or unbounded module selection differ.',1;
                IF @Proc=1 AND @Direct=0 AND COALESCE(@RowsJson,N'[]')<>COALESCE(JSON_QUERY(@Json,N'$.modules'),N'')
                    THROW 56911,N'Plan Cache TABLE/CONSOLE and JSON modules differ.',1;
                SELECT @ExpectedRowsJson=(SELECT * FROM [#ExampleOrchestratorExpected] ORDER BY [ExecutionOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
                IF @Proc=1 AND COALESCE(@ExpectedRowsJson,N'[]')<>COALESCE(JSON_QUERY(@Json,N'$.modules'),N'')
                    THROW 56919,N'Plan Cache JSON modules differ from the independently selected child rows.',1;
                TRUNCATE TABLE [#ExampleOrchestratorWarnings];
                INSERT [#ExampleOrchestratorWarnings]
                SELECT * FROM [#ExampleOrchestratorExpected] WHERE
                    (@Proc=1 AND [InvocationStatus] NOT IN('EXECUTED','REUSED_PARENT_SNAPSHOT')) OR
                    (@Proc=2 AND [InvocationStatus] NOT IN('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE','UNAVAILABLE_VERSION','UNAVAILABLE_FEATURE','FEATURE_DISABLED')) OR
                    (@Proc=3 AND [InvocationStatus]<>'EXECUTED');
                IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>(SELECT COUNT(*) FROM [#ExampleOrchestratorWarnings])
                   OR EXISTS(SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@Json,N'$.warnings') WITH([ExecutionOrdinal] tinyint,[ModuleName] nvarchar(128),[InvocationStatus] varchar(40),[ErrorNumber] int,[ErrorMessage] nvarchar(2048)) EXCEPT SELECT * FROM [#ExampleOrchestratorWarnings])
                   OR EXISTS(SELECT * FROM [#ExampleOrchestratorWarnings] EXCEPT SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@Json,N'$.warnings') WITH([ExecutionOrdinal] tinyint,[ModuleName] nvarchar(128),[InvocationStatus] varchar(40),[ErrorNumber] int,[ErrorMessage] nvarchar(2048)))
                    THROW 56912,N'The existing warning projection changed.',1;
                SET @Route+=1;
            END;
            SET @Case+=1;
        END;
        /* RAW-Leerscope: keine Children, deshalb keine geschützten Childinhalte. */
        SET @Json=NULL; SET @Mode='RAW'; SET @Mapping=NULL;
        EXEC [sys].[sp_executesql] @Call,@Defs,@pA=0,@pPair=0,@pAll=0,@pDb=@FrameworkName,@pHash=@Hash,
             @pXeNames=@XeNames,@pPlanMode='TOP',@pSource='AUTO',@pFrom=@From,@pTo=@To,@pLimit=1,
             @pMode=@Mode,@pMap=@Mapping,@pJson=@Json OUTPUT;
        IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode') IS NULL OR JSON_VALUE(@Json,N'$.meta.statusCode')<>'INVALID_PARAMETER'
            THROW 56913,N'RAW invalid-scope JSON did not preserve the parent status.',1;
        /* Preflight: unbekanntes Ergebnis, unzulässiges Ziel, fehlende Zuordnung,
           sowie eine Zuordnung außerhalb von TABLE, jeweils vor Childausführung. */
        SET @Preflight=0;
        WHILE @Preflight<4
        BEGIN
            SET @Mode=CASE WHEN @Preflight=3 THEN 'NONE' ELSE 'TABLE' END;
            SET @Mapping=CASE @Preflight WHEN 0 THEN N'{"unknown":"#ExampleOrchestratorPreflight"}'
                WHEN 1 THEN N'{"moduleStatus":"ExampleNotLocal"}' WHEN 2 THEN NULL
                ELSE N'{"moduleStatus":"#ExampleOrchestratorPreflight"}' END;
            CREATE TABLE [#ExampleOrchestratorPreflight]([Dummy] int NULL);
            SET @Caught=0;
            BEGIN TRY
                EXEC [sys].[sp_executesql] @Call,@Defs,@pA=1,@pPair=0,@pAll=0,@pDb=@FrameworkName,@pHash=@Hash,
                     @pXeNames=@XeNames,@pPlanMode='TOP',@pSource='AUTO',@pFrom=@From,@pTo=@To,@pLimit=1,
                     @pMode=@Mode,@pMap=@Mapping,@pJson=@Json OUTPUT;
            END TRY
            BEGIN CATCH
                IF ERROR_NUMBER()<>51011 THROW;
                SET @Caught=1;
            END CATCH;
            DROP TABLE [#ExampleOrchestratorPreflight];
            IF @Caught=0 THROW 56914,N'Invalid TABLE mapping was not rejected by preflight.',1;
            SET @Preflight+=1;
        END;
        SET @Proc+=1;
    END;
    IF @PositiveCalls<>12 OR @DirectCalls<>3 OR @EmptyCalls<>9 THROW 56915,N'Orchestrator CONSOLE coverage is incomplete.',1;
    DECLARE @RestoreLockTimeoutSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
    SELECT N'PASS' AS [StatusCode],24 AS [TableCases],12 AS [CapturedPositiveConsoleCases],3 AS [DirectConsoleCases],9 AS [CapturedEmptyConsoleCases],
           3 AS [RawInvalidScopeCases],12 AS [TableMappingPreflightCases],@FrameworkLevel AS [FrameworkCompatibilityLevel];
END TRY
BEGIN CATCH
    DECLARE @CatchRestoreLockTimeoutSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @CatchRestoreLockTimeoutSql;
    THROW;
END CATCH;
GO
