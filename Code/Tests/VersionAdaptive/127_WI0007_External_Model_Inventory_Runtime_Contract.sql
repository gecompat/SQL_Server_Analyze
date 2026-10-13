USE [DeineDatenbank];
GO

/*
Prüft die aggregierte Inventur mit einem eigenen synthetischen Modellkatalog.
Es wird keine AI-Funktion ausgeführt und kein Credential angelegt. Alle eigenen
Datenbankobjekte werden entfernt; die Modellanlage ersetzt keinen Inferenztest.
*/
SET NOCOUNT ON;
DECLARE @Db sysname=N'ExampleExternalModels_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @Model sysname=N'ExampleExternalModel_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @OwnDbId int=NULL,@OwnModelId int=NULL,@Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
    @CallerCompatibility int=(SELECT [compatibility_level] FROM [sys].[databases] WITH(NOLOCK) WHERE [database_id]=DB_ID()),
    @OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
    @Sql nvarchar(max),@Restore nvarchar(100),@SourceCount bigint,@AfterCount bigint,@AfterModelId int,
    @Case int=0,@Limit int,@OnlyDetected bit,@Json nvarchar(max),@TableJson nvarchar(max),
    @Status varchar(40),@Partial bit,@Names nvarchar(max),@ExpectedCount bigint,@ExpectedStatus varchar(40);
IF @@TRANCOUNT<>0 OR @Major IS NULL OR DB_ID(@Db) IS NOT NULL
    THROW 56900,N'WI-0007: Own source entry binding failed.',1;
SET @Restore=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Db)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @OwnDbId=DB_ID(@Db);
    IF @OwnDbId IS NULL THROW 56901,N'WI-0007: Own database binding missing.',1;
    SET @Names=QUOTENAME(@Db);
    EXEC [monitor].[USP_SpecialFeatureInventory] @DatabaseNames=@Names,@MaxZeilen=0,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    SELECT N'EMPTY_CATALOG_BEFORE_ASSERTION' [FrameType],@Status [StatusCode],@Partial [IsPartial],@Json [JsonOutput];
    IF COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR
        (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.features') WITH([FeatureCode] varchar(64)) WHERE [FeatureCode]='EXTERNAL_MODELS')<>1
        OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.features')
            WITH([FeatureCode] varchar(64),[DetectionStatus] varchar(40),[DetectedItemCount] bigint)
            WHERE [FeatureCode]='EXTERNAL_MODELS' AND
                ((@Major>=17 AND ([DetectionStatus]<>'NOT_DETECTED_VISIBLE_SCOPE' OR [DetectedItemCount] IS NULL OR [DetectedItemCount]<>0))
                 OR (@Major<17 AND ([DetectionStatus]<>'UNAVAILABLE_VERSION' OR [DetectedItemCount] IS NOT NULL))))
        THROW 56911,N'WI-0007: Empty native catalogue or older fallback mismatch.',1;
    IF @Major>=17
    BEGIN
        SET @Sql=N'USE '+QUOTENAME(@Db)+N'; CREATE EXTERNAL MODEL '+QUOTENAME(@Model)+N'
WITH(LOCATION=''https://example.invalid/api/embed'',API_FORMAT=''Ollama'',MODEL_TYPE=EMBEDDINGS,MODEL=''ExampleEmbeddingModel'');';
        EXEC [sys].[sp_executesql] @Sql;
        SET @Sql=N'USE '+QUOTENAME(@Db)+N'; SELECT @pCount=COUNT_BIG(*) FROM [sys].[external_models] WITH(NOLOCK);
SELECT @pId=[external_model_id] FROM [sys].[external_models] WITH(NOLOCK) WHERE [name]=@pName COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [sys].[sp_executesql] @Sql,N'@pCount bigint OUTPUT,@pId int OUTPUT,@pName sysname',
            @pCount=@SourceCount OUTPUT,@pId=@OwnModelId OUTPUT,@pName=@Model;
        SELECT N'OWN_MODEL_SOURCE_BEFORE_ASSERTION' [FrameType],@OwnDbId [DatabaseId],@OwnModelId [OwnModelId],@SourceCount [VisibleModelCount],@CallerCompatibility [CallerCompatibilityLevel];
        IF @OwnModelId IS NULL OR COALESCE(@SourceCount,-1)<>1 THROW 56902,N'WI-0007: Own native model source mismatch.',1;
    END;
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Db)+N' SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(10),@CallerCompatibility)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    IF NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH(NOLOCK) WHERE [database_id]=@OwnDbId AND [compatibility_level]=@CallerCompatibility)
        THROW 56912,N'WI-0007: Own source compatibility binding failed.',1;
    SELECT @ExpectedCount=CASE WHEN @Major>=17 THEN 1 END,
        @ExpectedStatus=CASE WHEN @Major>=17 THEN 'DETECTED' ELSE 'UNAVAILABLE_VERSION' END;
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=2 THEN 1 WHEN @Case=3 THEN NULL ELSE 0 END,
            @OnlyDetected=CASE WHEN @Case=1 THEN 1 ELSE 0 END;
        CREATE TABLE [#ExampleExternalModelFeatures]([Seed] bit NULL);
        SET LOCK_TIMEOUT 739;
        EXEC [monitor].[USP_SpecialFeatureInventory]
            @DatabaseNames=@Names,@NurErkannteFeatures=@OnlyDetected,@MaxZeilen=@Limit,
            @ResultSetArt='TABLE',@ResultTablesJson=N'{"features":"#ExampleExternalModelFeatures"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        EXEC [sys].[sp_executesql]
            N'SELECT @pJson=(SELECT * FROM [#ExampleExternalModelFeatures] ORDER BY [DatabaseName],[FeatureCode] FOR JSON PATH,INCLUDE_NULL_VALUES);',
            N'@pJson nvarchar(max) OUTPUT',@pJson=@TableJson OUTPUT;
        SELECT N'CONSUMER_BEFORE_ASSERTION' [FrameType],@Case [CaseNumber],@Status [StatusCode],@Partial [IsPartial],@Json [JsonOutput],@TableJson [PhysicalTableJson];
        IF COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR COALESCE(ISJSON(@Json),0)<>1
            OR @@LOCK_TIMEOUT<>739 OR @@TRANCOUNT<>0
            OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@OriginalAbort
            OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion')),-1)<>1
            OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.featureRowCount')),-1)<>19
            OR COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.features'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56903,N'WI-0007: Status caller or same-call TABLE JSON mismatch.',1;
        IF @Case=2 AND (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.features'))<>1
            THROW 56904,N'WI-0007: Positive output limit mismatch.',1;
        IF @Case<>2 AND NOT(@OnlyDetected=1 AND @Major<17)
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.features') WITH([FeatureCode] varchar(64)) WHERE [FeatureCode]='EXTERNAL_MODELS')<>1
                THROW 56905,N'WI-0007: External model feature missing.',1;
            IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.features')
                WITH([FeatureCode] varchar(64),[DatabaseName] sysname,[DetectionStatus] varchar(40),[DetectedItemCount] bigint,
                    [ConfigurationState] nvarchar(120),[SourceObjects] nvarchar(1000),[RecommendedModule] sysname,[RecommendedModuleStatus] varchar(40))
                WHERE [FeatureCode]='EXTERNAL_MODELS' AND
                    ([DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>@Db COLLATE SQL_Latin1_General_CP1_CS_AS
                     OR [DetectionStatus]<>@ExpectedStatus OR [DetectedItemCount]<>@ExpectedCount
                     OR ([DetectedItemCount] IS NULL AND @ExpectedCount IS NOT NULL)
                     OR ([DetectedItemCount] IS NOT NULL AND @ExpectedCount IS NULL)
                     OR [ConfigurationState] IS NOT NULL OR [SourceObjects]<>N'sys.external_models'
                     OR [RecommendedModule] IS NOT NULL OR [RecommendedModuleStatus]<>'NOT_PLANNED'))
                THROW 56906,N'WI-0007: External model aggregate or fallback mismatch.',1;
        END;
        IF @OnlyDetected=1 AND @Major<17 AND EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.features') WITH([FeatureCode] varchar(64)) WHERE [FeatureCode]='EXTERNAL_MODELS')
            THROW 56907,N'WI-0007: Detected-only filter retained unavailable feature.',1;
        DROP TABLE [#ExampleExternalModelFeatures];
        SET @Case+=1;
    END;
    IF @Major>=17
    BEGIN
        SET @Sql=N'USE '+QUOTENAME(@Db)+N'; SELECT @pCount=COUNT_BIG(*) FROM [sys].[external_models] WITH(NOLOCK);
SELECT @pId=[external_model_id] FROM [sys].[external_models] WITH(NOLOCK) WHERE [name]=@pName COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [sys].[sp_executesql] @Sql,N'@pCount bigint OUTPUT,@pId int OUTPUT,@pName sysname',
            @pCount=@AfterCount OUTPUT,@pId=@AfterModelId OUTPUT,@pName=@Model;
        SELECT N'OWN_MODEL_SOURCE_AFTER_BEFORE_ASSERTION' [FrameType],@OwnDbId [DatabaseId],@AfterModelId [OwnModelId],@AfterCount [VisibleModelCount];
        IF COALESCE(@AfterCount,-1)<>@SourceCount OR @AfterModelId IS NULL OR @AfterModelId<>@OwnModelId
            THROW 56908,N'WI-0007: Own model source changed.',1;
    END;
    IF DB_ID(@Db)<>@OwnDbId OR DB_ID(@Db) IS NULL THROW 56909,N'WI-0007: Own cleanup database mismatch.',1;
    SET LOCK_TIMEOUT 5000;
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@Db)+N';';EXEC [sys].[sp_executesql] @Sql;
    IF DB_ID(@Db) IS NOT NULL THROW 56910,N'WI-0007: Own database remains.',1;
    EXEC [sys].[sp_executesql] @Restore;
    SELECT N'WI-0007' [WorkItem],N'PASS' [Status],@Major [ProductMajorVersion],4 [TableJsonCases],CASE WHEN @Major>=17 THEN 1 ELSE 0 END [NativeOwnModelObjects];
END TRY
BEGIN CATCH
    SELECT N'ORIGINAL_FAILURE' [FrameType],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    BEGIN TRY
        IF @OwnDbId IS NOT NULL AND DB_ID(@Db)=@OwnDbId
        BEGIN
            SET LOCK_TIMEOUT 5000;
            SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Db)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@Db)+N';';
            EXEC [sys].[sp_executesql] @Sql;
        END;
        EXEC [sys].[sp_executesql] @Restore;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_CLEANUP_FAILURE' [FrameType],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    THROW;
END CATCH;
GO
