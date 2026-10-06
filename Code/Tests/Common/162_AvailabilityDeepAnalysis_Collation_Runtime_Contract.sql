USE [DeineDatenbank];
GO
/* Prüft den vorhandenen AvailabilityDeep-Leerscope bei tatsächlich deaktiviertem
   HADR. Die sieben Arrays bleiben leer; NULL-/0-/positive Limits belegen nur
   Akzeptanz. Positive Replika-, Queue-, Cluster-, Seeding-, Repair-, Berechtigungs-
   oder Limitwirkung bleibt unbelegt. Es werden keine Quelldatenbanken angelegt.
   Frameworklevels 150/160/170 sind zulässig; der Lauf belegt nur sein echtes Level. */
SET NOCOUNT ON;
DECLARE @HadrEnabled int=TRY_CONVERT(int,SERVERPROPERTY(N'IsHadrEnabled')),
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @OriginalLockTimeout int=@@LOCK_TIMEOUT,@RestoreSql nvarchar(64),@Case int=0,@Route int=0,
        @Limit int,@Queue bigint,@Lag int,@Networks bit,@Invalid bit,@ExpectedStatus varchar(40),
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048),
        @Before datetime2(3),@After datetime2(3),@Mode varchar(16);
IF @HadrEnabled IS NULL OR @HadrEnabled<>0
BEGIN
    SELECT CAST('UNAVAILABLE_FEATURE' AS varchar(40)) AS [StatusCode],CAST(1 AS bit) AS [IsPartial],
           CAST('NOT_EXECUTED' AS varchar(40)) AS [ExecutionState],@HadrEnabled AS [IsHadrEnabled],
           @FrameworkLevel AS [FrameworkCompatibilityLevel],0 AS [TableJsonCases],0 AS [RawConsoleStatusCases],
           N'Dieser Leerscope-Vertrag benötigt tatsächlich deaktiviertes HADR; keine Fälle ausgeführt.' AS [Detail];
    RETURN;
END;
IF @FrameworkLevel IS NULL OR @FrameworkLevel NOT IN(150,160,170)
    THROW 56600,N'AvailabilityDeep framework level is outside the contract.',1;
IF @Major IS NULL OR @Major<15 THROW 56601,N'AvailabilityDeep contract requires a visible SQL Server 2019 or newer version.',1;
CREATE TABLE [#ExampleAvailabilityDeepSchema]
(
      [AvailabilityGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ReplicaServerName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsLocal] bit NULL
    , [RoleDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [OperationalStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ConnectedStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [SynchronizationHealthDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [AvailabilityModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [FailoverModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [SeedingModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
CREATE TABLE [#ExampleAvailabilityDeepTopKeys]
  ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[JsonType] int NOT NULL);
INSERT [#ExampleAvailabilityDeepTopKeys] VALUES
 (N'meta',5),(N'cluster',4),(N'members',4),(N'networks',4),(N'replicas',4),(N'databases',4),(N'seeding',4),(N'pageRepair',4);
CREATE TABLE [#ExampleAvailabilityDeepMetaKeys]
  ([KeyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[JsonType] int NOT NULL);
INSERT [#ExampleAvailabilityDeepMetaKeys] VALUES
 (N'resultName',1),(N'schemaVersion',2),(N'generatedAtUtc',1),(N'statusCode',1),(N'isPartial',3),
 (N'queueWarnMb',2),(N'secondaryLagWarnSeconds',2),(N'productMajorVersion',2);
BEGIN TRY
    WHILE @Case<10
    BEGIN
        SELECT @Limit=CASE WHEN @Case=0 THEN NULL WHEN @Case=2 THEN 1 WHEN @Case=3 THEN -1 ELSE 0 END,
               @Queue=CASE WHEN @Case=4 THEN NULL WHEN @Case=5 THEN -1 WHEN @Case=8 THEN 0 ELSE 1024 END,
               @Lag=CASE WHEN @Case=6 THEN NULL WHEN @Case=7 THEN -1 WHEN @Case=8 THEN 0 ELSE 60 END,
               @Networks=CASE WHEN @Case=9 THEN 1 ELSE 0 END,
               @Invalid=CASE WHEN @Case BETWEEN 3 AND 7 THEN 1 ELSE 0 END,
               @Json=NULL,@Status=NULL,@Partial=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,@Before=SYSUTCDATETIME();
        SET @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' ELSE 'NOT_APPLICABLE' END;
        CREATE TABLE [#ExampleAvailabilityDeepExport]([Dummy] int NULL);
        EXEC [monitor].[USP_AvailabilityDeepAnalysis]
             @QueueWarnMb=@Queue,@SecondaryLagWarnSeconds=@Lag,@MitClusterNetzwerken=@Networks,@MaxZeilen=@Limit,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"replicas":"#ExampleAvailabilityDeepExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        SET @After=SYSUTCDATETIME();
        UPDATE [#ExampleAvailabilityDeepMetaKeys] SET [JsonType]=CASE WHEN @Queue IS NULL THEN 0 ELSE 2 END WHERE [KeyName]=N'queueWarnMb';
        UPDATE [#ExampleAvailabilityDeepMetaKeys] SET [JsonType]=CASE WHEN @Lag IS NULL THEN 0 ELSE 2 END WHERE [KeyName]=N'secondaryLagWarnSeconds';
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus
           OR COALESCE(CONVERT(int,@Partial),-1)<>CONVERT(int,@Invalid) OR @ErrorNumber IS NOT NULL
           OR NULLIF(@ErrorMessage,N'') IS NULL
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.resultName'),N'')<>N'AvailabilityDeepAnalysis'
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Invalid=1 THEN N'true' ELSE N'false' END
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.productMajorVersion')),-1)<>@Major
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
           OR (@Queue IS NULL AND JSON_VALUE(@Json,N'$.meta.queueWarnMb') IS NOT NULL)
           OR (@Queue IS NOT NULL AND COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.queueWarnMb')),-9223372036854775808)<>@Queue)
           OR (@Lag IS NULL AND JSON_VALUE(@Json,N'$.meta.secondaryLagWarnSeconds') IS NOT NULL)
           OR (@Lag IS NOT NULL AND COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.secondaryLagWarnSeconds')),-2147483648)<>@Lag)
            THROW 56602,N'AvailabilityDeep complete consumer status or metadata-value contract failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>8
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepTopKeys]
                     EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json)
                     EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepTopKeys])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.meta'))<>8
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepMetaKeys]
                     EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta'))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta')
                     EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepMetaKeys])
            THROW 56603,N'AvailabilityDeep eight top-level and eight metadata properties or native JSON types failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json) [a] CROSS APPLY OPENJSON([a].[value]) [r] WHERE [a].[type]=4)
            THROW 56604,N'AvailabilityDeep seven independently expected arrays are not empty.',1;
        IF (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
           OR COALESCE(TRY_CONVERT(int,SERVERPROPERTY(N'IsHadrEnabled')),-1)<>0
            THROW 56605,N'AvailabilityDeep native disabled-HADR prerequisite or framework level changed.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleAvailabilityDeepExport])
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepExport'))<>11
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepExport')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepSchema'))
           OR EXISTS(SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepSchema')
                     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY [column_id]) AS [ColumnOrdinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS,[is_nullable] FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleAvailabilityDeepExport'))
            THROW 56606,N'AvailabilityDeep independent eleven-field empty TABLE schema or ten text collations failed.',1;
        DROP TABLE [#ExampleAvailabilityDeepExport];
        SET @Case+=1;
    END;
    /* RAW/CONSOLE-Zeilen werden nicht separat abgefangen. Zwei zusätzliche
       JSON-Verbraucher-Aufrufe prüfen JSON-Verbraucher bei NULL-Queue und ungültiger Ausgabeart. */
    WHILE @Route<6
    BEGIN
        SELECT @Mode=CASE WHEN @Route IN(0,2) THEN 'RAW' WHEN @Route IN(1,3) THEN 'CONSOLE'
                          WHEN @Route=4 THEN 'NONE' ELSE 'UNSUPPORTED' END,
               @Limit=CASE WHEN @Route IN(2,3) THEN -1 ELSE 1 END,
               @Queue=CASE WHEN @Route=4 THEN NULL ELSE 1024 END,@Lag=60,
               @Invalid=CASE WHEN @Route>=2 THEN 1 ELSE 0 END,
               @Json=NULL,@Status=NULL,@Partial=NULL,@ErrorNumber=NULL,@ErrorMessage=NULL,@Before=SYSUTCDATETIME();
        SET @ExpectedStatus=CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' ELSE 'NOT_APPLICABLE' END;
        EXEC [monitor].[USP_AvailabilityDeepAnalysis] @QueueWarnMb=@Queue,@SecondaryLagWarnSeconds=@Lag,@MaxZeilen=@Limit,
             @ResultSetArt=@Mode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        SET @After=SYSUTCDATETIME();
        UPDATE [#ExampleAvailabilityDeepMetaKeys] SET [JsonType]=CASE WHEN @Queue IS NULL THEN 0 ELSE 2 END WHERE [KeyName]=N'queueWarnMb';
        UPDATE [#ExampleAvailabilityDeepMetaKeys] SET [JsonType]=CASE WHEN @Lag IS NULL THEN 0 ELSE 2 END WHERE [KeyName]=N'secondaryLagWarnSeconds';
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus
           OR COALESCE(CONVERT(int,@Partial),-1)<>CONVERT(int,@Invalid) OR @ErrorNumber IS NOT NULL
           OR NULLIF(@ErrorMessage,N'') IS NULL
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.resultName'),N'')<>N'AvailabilityDeepAnalysis'
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Invalid=1 THEN N'true' ELSE N'false' END
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.productMajorVersion')),-1)<>@Major
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) IS NULL
           OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,N'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
           OR (@Queue IS NULL AND JSON_VALUE(@Json,N'$.meta.queueWarnMb') IS NOT NULL)
           OR (@Queue IS NOT NULL AND COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.queueWarnMb')),-9223372036854775808)<>@Queue)
           OR (@Lag IS NULL AND JSON_VALUE(@Json,N'$.meta.secondaryLagWarnSeconds') IS NOT NULL)
           OR (@Lag IS NOT NULL AND COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.secondaryLagWarnSeconds')),-2147483648)<>@Lag)
            THROW 56602,N'AvailabilityDeep complete consumer status or metadata-value contract failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>8
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepTopKeys]
                     EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json)
                     EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepTopKeys])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.meta'))<>8
           OR EXISTS(SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepMetaKeys]
                     EXCEPT SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta'))
           OR EXISTS(SELECT [key] COLLATE SQL_Latin1_General_CP1_CS_AS,[type] FROM OPENJSON(@Json,N'$.meta')
                     EXCEPT SELECT [KeyName],[JsonType] FROM [#ExampleAvailabilityDeepMetaKeys])
            THROW 56603,N'AvailabilityDeep eight top-level and eight metadata properties or native JSON types failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json) [a] CROSS APPLY OPENJSON([a].[value]) [r] WHERE [a].[type]=4)
            THROW 56604,N'AvailabilityDeep seven independently expected arrays are not empty.',1;
        IF (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
           OR COALESCE(TRY_CONVERT(int,SERVERPROPERTY(N'IsHadrEnabled')),-1)<>0
            THROW 56605,N'AvailabilityDeep native disabled-HADR prerequisite or framework level changed.',1;
        SET @Route+=1;
    END;
    SET @RestoreSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@RestoreSql);
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@HadrEnabled AS [IsHadrEnabled],@Case AS [TableJsonCases],
           4 AS [RawConsoleStatusCases],2 AS [AdditionalJsonConsumerCases],
           N'Deaktiviertes HADR und leeres Replikaschema geprüft; positive HADR-Quellen und Limitwirkung bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    SET @RestoreSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@RestoreSql);
    THROW;
END CATCH;
GO
