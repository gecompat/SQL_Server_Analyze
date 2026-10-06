USE [DeineDatenbank];
GO
/* Prüft den Findings-Export anhand eigener CT-Metadaten aus zwei leeren Tabellen.
Die Fixture aktiviert weder CDC noch Replikation und schreibt keine Change-Zeilen.
Ein synthetischer Wasserstand über der nativen aktuellen Version erzeugt WARNs;
deaktiviertes Auto-Cleanup liefert INFO-Kontext. Retentionverlust, CDC und positive
Replikationsquellen bleiben außerhalb dieses Vertrags. Der Runner verwendet die
Framework-Compatibility-Level 150, 160 und 170; beide Quellen werden daran angepasst. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleDataCaptureDeepSourceÄ') IS NOT NULL THROW 56300,N'DataCaptureDeep source fixture already exists.',1;
IF DB_ID(N'ExampleDataCaptureDeepOtherÖ') IS NOT NULL THROW 56301,N'DataCaptureDeep second fixture already exists.',1;
IF DB_ID(N'ExampleDataCaptureDeepMissingÜ') IS NOT NULL THROW 56302,N'DataCaptureDeep missing selection fixture already exists.',1;
DECLARE @OwnedSourceId int=NULL,@OwnedOtherId int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @SourceLevel int,@OtherLevel int,@CurrentVersion bigint,@ClientVersion bigint,
        @Sql nvarchar(max),@Case int=0,@Limit int,@Problems bit,@Timeout int,
        @Names nvarchar(max),@Objects nvarchar(max),@Schemas nvarchar(max),@FullObjects nvarchar(max),
        @Pattern nvarchar(4000),@Json nvarchar(max),@Status varchar(40),@Partial bit,
        @Invalid bit,@NativeScopeCount bigint,@FullFindingCount bigint,@OutputFindingCount bigint,@OutputCtCount bigint;
IF @FrameworkLevel NOT IN(150,160,170) THROW 56303,N'DataCaptureDeep framework compatibility level is outside the contract.',1;
BEGIN TRY
    CREATE DATABASE [ExampleDataCaptureDeepSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedSourceId=DB_ID(N'ExampleDataCaptureDeepSourceÄ');
    CREATE DATABASE [ExampleDataCaptureDeepOtherÖ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedOtherId=DB_ID(N'ExampleDataCaptureDeepOtherÖ');
    SET @Sql=N'ALTER DATABASE [ExampleDataCaptureDeepSourceÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';
ALTER DATABASE [ExampleDataCaptureDeepOtherÖ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';';
    EXEC(@Sql);
    SELECT @SourceLevel=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedSourceId;
    SELECT @OtherLevel=[compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedOtherId;
    IF @SourceLevel<>@FrameworkLevel OR @OtherLevel<>@FrameworkLevel
       OR (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@FrameworkLevel
       OR CONVERT(sysname,DATABASEPROPERTYEX(N'ExampleDataCaptureDeepSourceÄ',N'Collation')) COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS'
       OR CONVERT(sysname,DATABASEPROPERTYEX(N'ExampleDataCaptureDeepOtherÖ',N'Collation')) COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS'
        THROW 56304,N'DataCaptureDeep framework/source compatibility levels or source collations failed.',1;
    ALTER DATABASE [ExampleDataCaptureDeepSourceÄ] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = OFF);
    SET @Sql=N'USE [ExampleDataCaptureDeepSourceÄ];
EXEC(N''CREATE SCHEMA [ExampleSchemaÜ]'');
CREATE TABLE [ExampleSchemaÜ].[ExampleCtÄ]([Id] int NOT NULL PRIMARY KEY);
CREATE TABLE [ExampleSchemaÜ].[ExampleCtÖ]([Id] int NOT NULL PRIMARY KEY);
ALTER TABLE [ExampleSchemaÜ].[ExampleCtÄ] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE [ExampleSchemaÜ].[ExampleCtÖ] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
SELECT @pCurrent=CHANGE_TRACKING_CURRENT_VERSION();';
    EXEC [sys].[sp_executesql] @Sql,N'@pCurrent bigint OUTPUT',@pCurrent=@CurrentVersion OUTPUT;
    IF @CurrentVersion IS NULL OR @CurrentVersion=9223372036854775807
        THROW 56305,N'DataCaptureDeep native current CT version is unavailable or cannot be incremented.',1;
    IF NOT EXISTS(SELECT 1 FROM [sys].[change_tracking_databases] WHERE [database_id]=@OwnedSourceId
                  AND [is_auto_cleanup_on]=0 AND [retention_period]=2)
       OR EXISTS(SELECT 1 FROM [sys].[databases] WHERE [database_id] IN(@OwnedSourceId,@OwnedOtherId)
                  AND ([is_cdc_enabled]=1 OR [is_published]=1 OR [is_subscribed]=1 OR [is_merge_published]=1 OR [is_distributor]=1))
       OR EXISTS(SELECT 1 FROM [ExampleDataCaptureDeepSourceÄ].[sys].[partitions] [p]
                  JOIN [ExampleDataCaptureDeepSourceÄ].[sys].[tables] [t] ON [t].[object_id]=[p].[object_id]
                  WHERE [p].[index_id] IN(0,1) AND [p].[rows]<>0 AND [t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleCtÄ',N'ExampleCtÖ'))
        THROW 56306,N'DataCaptureDeep own fixture is not the intended empty CT metadata scope.',1;
    CREATE TABLE [#ExampleDeepNativeCt]
      ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [SchemaName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [TableName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [TableObjectId] int NOT NULL,[IsTrackColumnsUpdatedOn] bit NOT NULL,
       [BeginVersion] bigint NULL,[CleanupVersion] bigint NULL,[MinValidVersion] bigint NULL,[CurrentVersion] bigint NOT NULL);
    SET @Sql=N'USE [ExampleDataCaptureDeepSourceÄ];
INSERT [#ExampleDeepNativeCt]
SELECT DB_NAME(),[s].[name],[t].[name],[ct].[object_id],[ct].[is_track_columns_updated_on],
       [ct].[begin_version],[ct].[cleanup_version],CHANGE_TRACKING_MIN_VALID_VERSION([ct].[object_id]),CHANGE_TRACKING_CURRENT_VERSION()
FROM [sys].[change_tracking_tables] [ct]
JOIN [sys].[tables] [t] ON [t].[object_id]=[ct].[object_id]
JOIN [sys].[schemas] [s] ON [s].[schema_id]=[t].[schema_id];';
    EXEC(@Sql);
    IF (SELECT COUNT_BIG(*) FROM [#ExampleDeepNativeCt])<>2
       OR NOT EXISTS(SELECT 1 FROM [#ExampleDeepNativeCt] WHERE [SchemaName]=N'ExampleSchemaÜ' AND [TableName]=N'ExampleCtÄ' AND [IsTrackColumnsUpdatedOn]=1)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleDeepNativeCt] WHERE [SchemaName]=N'ExampleSchemaÜ' AND [TableName]=N'ExampleCtÖ' AND [IsTrackColumnsUpdatedOn]=0)
       OR EXISTS(SELECT 1 FROM [#ExampleDeepNativeCt] WHERE [CurrentVersion]<>@CurrentVersion
                  OR [MinValidVersion] IS NULL OR [MinValidVersion]>@CurrentVersion)
        THROW 56307,N'DataCaptureDeep native CT identities, versions or tracked-column flags failed.',1;
    CREATE TABLE [#ExampleDeepExpectedSources]
      ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
       [SourceCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL);
    INSERT [#ExampleDeepExpectedSources] VALUES
      (N'ExampleDataCaptureDeepSourceÄ','DATA_CAPTURE_FEATURE_GATE','AVAILABLE',0,1),
      (N'ExampleDataCaptureDeepSourceÄ','CHANGE_TRACKING_TABLES','AVAILABLE',0,2),
      (N'ExampleDataCaptureDeepSourceÄ','CDC_CAPTURE_INSTANCES','NOT_APPLICABLE',0,0),
      (N'ExampleDataCaptureDeepSourceÄ','CDC_LOG_SCAN_SESSIONS','NOT_APPLICABLE',0,0),
      (N'ExampleDataCaptureDeepSourceÄ','CDC_ERRORS','NOT_APPLICABLE',0,0),
      (N'ExampleDataCaptureDeepSourceÄ','CDC_JOBS','NOT_APPLICABLE',0,0),
      (NULL,'REPLICATION_DISTRIBUTOR_DISCOVERY','NOT_APPLICABLE',0,0),
      (NULL,'REPLICATION_DISTRIBUTION_AGENTS','NOT_APPLICABLE',0,0),
      (NULL,'REPLICATION_LOG_READER_AGENTS','NOT_APPLICABLE',0,0),
      (NULL,'REPLICATION_MERGE_AGENTS','NOT_APPLICABLE',0,0),
      (NULL,'REPLICATION_ERRORS','NOT_APPLICABLE',0,0);
    CREATE TABLE [#ExampleDeepExpectedCt]
      ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [SchemaName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [TableName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [TableObjectId] int NOT NULL,[IsTrackColumnsUpdatedOn] bit NOT NULL,
       [BeginVersion] bigint NULL,[CleanupVersion] bigint NULL,[MinValidVersion] bigint NULL,[CurrentVersion] bigint NOT NULL,
       [ClientVersion] bigint NULL,[AssessmentStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExampleDeepExpectedFindings]
      ([DatabaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
       [SchemaName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
       [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
       [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
       [MetricValue] decimal(38,4) NULL,[ThresholdValue] decimal(38,4) NULL);
    DECLARE @Parity TABLE([TableJson] nvarchar(max),[ProductJson] nvarchar(max));
    WHILE @Case<18
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN NULL WHEN @Case IN(2,16) THEN 1 WHEN @Case=8 THEN -1 ELSE 0 END,
               @Problems=CASE WHEN @Case IN(3,16,17) THEN 1 ELSE 0 END,
               @Names=CASE WHEN @Case=7 THEN N'[ExampleDataCaptureDeepSourceÄ]|[ExampleDataCaptureDeepMissingÜ]'
                           WHEN @Case=12 THEN N'[ExampleDataCaptureDeepSourceÄ]|[ExampleDataCaptureDeepOtherÖ]'
                           ELSE N'[ExampleDataCaptureDeepSourceÄ]' END,
               @Objects=CASE WHEN @Case IN(4,11) THEN N'[ExampleCtÖ]' WHEN @Case=15 THEN N'[exampleCtÖ]' ELSE NULL END,
               @Schemas=CASE WHEN @Case=5 THEN N'[ExampleSchemaÜ]' ELSE NULL END,
               @FullObjects=CASE WHEN @Case=6 THEN N'[ExampleDataCaptureDeepSourceÄ].[ExampleSchemaÜ].[ExampleCtÖ]' ELSE NULL END,
               @Pattern=CASE WHEN @Case=11 THEN N'like:ExampleCt%' ELSE NULL END,
               @ClientVersion=CASE WHEN @Case=9 THEN -1 WHEN @Case=13 THEN NULL WHEN @Case IN(14,17) THEN @CurrentVersion ELSE @CurrentVersion+1 END,
               @Timeout=CASE WHEN @Case=10 THEN -1 ELSE 0 END,
               @Invalid=CASE WHEN @Case BETWEEN 8 AND 12 THEN 1 ELSE 0 END,
               @Json=NULL,@Status=NULL,@Partial=NULL;
        TRUNCATE TABLE [#ExampleDeepExpectedCt];
        TRUNCATE TABLE [#ExampleDeepExpectedFindings];
        IF @Invalid=0
        BEGIN
            INSERT [#ExampleDeepExpectedCt]
            SELECT *,@ClientVersion,CASE WHEN @ClientVersion>@CurrentVersion THEN 'REVIEW' ELSE 'AVAILABLE' END
            FROM [#ExampleDeepNativeCt]
            WHERE @Case NOT IN(4,6,15) OR (@Case IN(4,6) AND [TableName]=N'ExampleCtÖ');
            IF @ClientVersion>@CurrentVersion
                INSERT [#ExampleDeepExpectedFindings]
                SELECT [DatabaseName],[SchemaName],[TableName],'WARN','HIGH','CT_CLIENT_VERSION_IN_FUTURE','CLIENT_VERSION',@ClientVersion,[CurrentVersion]
                FROM [#ExampleDeepExpectedCt];
            IF @ClientVersion IS NULL
                INSERT [#ExampleDeepExpectedFindings] VALUES
                (N'ExampleDataCaptureDeepSourceÄ',NULL,NULL,'INFO','HIGH','CT_CLIENT_WATERMARK_NOT_SUPPLIED','CLIENT_VERSION',NULL,NULL);
            INSERT [#ExampleDeepExpectedFindings] VALUES
                (N'ExampleDataCaptureDeepSourceÄ',NULL,NULL,'INFO','HIGH','CT_AUTO_CLEANUP_DISABLED','AUTO_CLEANUP_ON',0,1);
        END;
        SELECT @NativeScopeCount=COUNT_BIG(*) FROM [#ExampleDeepExpectedCt];
        SELECT @FullFindingCount=COUNT_BIG(*) FROM [#ExampleDeepExpectedFindings];
        DELETE [#ExampleDeepExpectedFindings] WHERE @Problems=1 AND [Severity]<>'WARN';
        DELETE [#ExampleDeepExpectedCt] WHERE @Problems=1 AND [AssessmentStatus]<>'REVIEW';
        SELECT @OutputFindingCount=CASE WHEN @Limit>0 AND COUNT_BIG(*)>@Limit THEN @Limit ELSE COUNT_BIG(*) END FROM [#ExampleDeepExpectedFindings];
        SELECT @OutputCtCount=CASE WHEN @Limit>0 AND COUNT_BIG(*)>@Limit THEN @Limit ELSE COUNT_BIG(*) END FROM [#ExampleDeepExpectedCt];
        CREATE TABLE [#ExampleDeepExport]([Dummy] int NULL);
        EXEC [monitor].[USP_DataCaptureDeepAnalysis]
             @DatabaseNames=@Names,@SchemaNames=@Schemas,@ObjectNames=@Objects,@FullObjectNames=@FullObjects,@ObjectNamePattern=@Pattern,
             @ChangeTrackingClientVersion=@ClientVersion,@NurProblematisch=@Problems,@MaxZeilen=@Limit,@LockTimeoutMs=@Timeout,
             @HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleDeepExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(@Status,'')<>CASE WHEN @Invalid=1 THEN 'INVALID_PARAMETER' WHEN @Case=7 THEN 'AVAILABLE_LIMITED'
                                       WHEN @Case IN(13,14,15,17) THEN 'AVAILABLE' ELSE 'AVAILABLE_WITH_FINDING' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Invalid=1 OR @Case=7 THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Invalid=1 OR @Case=7 THEN N'true' ELSE N'false' END
            THROW 56310,N'DataCaptureDeep module status or partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleDeepExport])<>@OutputFindingCount
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>@OutputFindingCount
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.changeTrackingTables'))<>@OutputCtCount
           OR (@Limit=1 AND @Invalid=0 AND NOT EXISTS(SELECT 1 FROM [#ExampleDeepExport] WHERE [Severity]='WARN'))
            THROW 56311,N'DataCaptureDeep exact positive findings/filter/limit counts failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleDeepExport'))<>13
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleDeepExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleDeepExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
           OR EXISTS(SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleDeepExport')
                     EXCEPT SELECT [ColumnName] FROM (VALUES
                     (N'FindingOrdinal'),(N'DatabaseName'),(N'SchemaName'),(N'ObjectName'),(N'Severity'),(N'Confidence'),(N'FindingCode'),
                     (N'MetricName'),(N'MetricValue'),(N'ThresholdValue'),(N'Evidence'),(N'EvidenceLimit'),(N'RecommendedNextCheck')) [v]([ColumnName]))
            THROW 56312,N'DataCaptureDeep export schema or ten text collations failed.',1;
        IF EXISTS(SELECT [DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue]
                  FROM [#ExampleDeepExport] EXCEPT SELECT * FROM [#ExampleDeepExpectedFindings])
           OR ((@Limit IS NULL OR @Limit<>1) AND EXISTS(SELECT * FROM [#ExampleDeepExpectedFindings] EXCEPT
                  SELECT [DatabaseName],[SchemaName],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue] FROM [#ExampleDeepExport]))
           OR EXISTS(SELECT [FindingOrdinal] FROM [#ExampleDeepExport] GROUP BY [FindingOrdinal] HAVING COUNT_BIG(*)<>1)
           OR EXISTS(SELECT [ObjectName],[FindingCode] FROM [#ExampleDeepExport] GROUP BY [ObjectName],[FindingCode] HAVING COUNT_BIG(*)<>1)
            THROW 56313,N'DataCaptureDeep findings differ from independent native CT expectations.',1;
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleDeepExport] FOR JSON PATH),JSON_QUERY(@Json,N'$.findings'));
        IF EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[TableJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ProductJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[ProductJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p] CROSS APPLY OPENJSON([p].[TableJson]) [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56314,N'DataCaptureDeep TABLE/JSON thirteen-field multiset parity failed.',1;
        IF EXISTS(SELECT 1 FROM (VALUES(N'cdcCaptureInstances'),(N'cdcScanSessions'),(N'cdcErrors'),(N'cdcJobs'),(N'replicationAgents'),(N'replicationErrors')) [a]([ArrayName])
                  CROSS APPLY OPENJSON(@Json,N'$.'+[a].[ArrayName]))
            THROW 56315,N'DataCaptureDeep CT-only fixture reached positive CDC or replication details.',1;
        IF @Invalid=0
        BEGIN
            UPDATE [#ExampleDeepExpectedSources] SET [RowCount]=@NativeScopeCount WHERE [SourceCode]='CHANGE_TRACKING_TABLES';
            /* Beide nullable EXCEPT-Seiten verwenden den Basistyp nvarchar(128). */
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>11
               OR EXISTS(SELECT * FROM [#ExampleDeepExpectedSources] EXCEPT SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount'))
               OR EXISTS(SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount')
                  EXCEPT SELECT * FROM [#ExampleDeepExpectedSources])
                THROW 56316,N'DataCaptureDeep independent eleven-source set or native unbounded row count failed.',1;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>CASE WHEN @Case=7 THEN 2 ELSE 1 END
               OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',
                   [IsChangeTrackingEnabled] bit '$.IsChangeTrackingEnabled',[CtTableCount] bigint '$.CtTableCount',[IsCdcEnabled] bit '$.IsCdcEnabled',
                   [CdcCaptureInstanceCount] bigint '$.CdcCaptureInstanceCount',[HasReplicationRole] bit '$.HasReplicationRole',
                   [FindingCount] bigint '$.FindingCount',[SourceFailureCount] int '$.SourceFailureCount')
                  WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleDataCaptureDeepSourceÄ'
                    AND [StatusCode]=CASE WHEN @ClientVersion>@CurrentVersion AND @NativeScopeCount>0 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END
                    AND [IsPartial]=0 AND [IsChangeTrackingEnabled]=1 AND [CtTableCount]=2 AND [IsCdcEnabled]=0
                    AND [CdcCaptureInstanceCount]=0 AND [HasReplicationRole]=0 AND [FindingCount]=@FullFindingCount AND [SourceFailureCount]=0)
                THROW 56317,N'DataCaptureDeep database status or complete counters failed.',1;
            IF @Case=7 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',
                   [FindingCount] bigint '$.FindingCount',[SourceFailureCount] int '$.SourceFailureCount',[ErrorMessage] nvarchar(2048) '$.ErrorMessage')
                  WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleDataCaptureDeepMissingÜ'
                    AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1 AND [FindingCount]=0 AND [SourceFailureCount]=1 AND NULLIF([ErrorMessage],N'') IS NOT NULL)
                THROW 56318,N'DataCaptureDeep missing selection warning was overwritten.',1;
            IF EXISTS(SELECT * FROM OPENJSON(@Json,N'$.changeTrackingTables') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[SchemaName] nvarchar(128) '$.SchemaName',[TableName] nvarchar(128) '$.TableName',
                   [TableObjectId] int '$.TableObjectId',[IsTrackColumnsUpdatedOn] bit '$.IsTrackColumnsUpdatedOn',[BeginVersion] bigint '$.BeginVersion',
                   [CleanupVersion] bigint '$.CleanupVersion',[MinValidVersion] bigint '$.MinValidVersion',[CurrentVersion] bigint '$.CurrentVersion',
                   [ClientVersion] bigint '$.ClientVersion',[AssessmentStatus] varchar(32) '$.AssessmentStatus') EXCEPT SELECT * FROM [#ExampleDeepExpectedCt])
               OR ((@Limit IS NULL OR @Limit<>1) AND EXISTS(SELECT * FROM [#ExampleDeepExpectedCt] EXCEPT SELECT * FROM OPENJSON(@Json,N'$.changeTrackingTables') WITH
                  ([DatabaseName] nvarchar(128) '$.DatabaseName',[SchemaName] nvarchar(128) '$.SchemaName',[TableName] nvarchar(128) '$.TableName',
                   [TableObjectId] int '$.TableObjectId',[IsTrackColumnsUpdatedOn] bit '$.IsTrackColumnsUpdatedOn',[BeginVersion] bigint '$.BeginVersion',
                   [CleanupVersion] bigint '$.CleanupVersion',[MinValidVersion] bigint '$.MinValidVersion',[CurrentVersion] bigint '$.CurrentVersion',
                   [ClientVersion] bigint '$.ClientVersion',[AssessmentStatus] varchar(32) '$.AssessmentStatus')))
                THROW 56319,N'DataCaptureDeep native CT metadata/version/identity parity failed.',1;
        END
        ELSE
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>CASE WHEN @Case=12 THEN 2 ELSE 0 END
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>5
               OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
                         [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount')
                         WHERE [DatabaseName] IS NOT NULL OR [SourceCode] NOT IN('REPLICATION_DISTRIBUTOR_DISCOVERY','REPLICATION_DISTRIBUTION_AGENTS',
                               'REPLICATION_LOG_READER_AGENTS','REPLICATION_MERGE_AGENTS','REPLICATION_ERRORS') OR [StatusCode]<>'NOT_APPLICABLE' OR [IsPartial]<>0 OR [RowCount]<>0)
                THROW 56320,N'DataCaptureDeep invalid parameters reached database sources.',1;
            IF @Case=12 AND
               ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus') WITH([DatabaseName] nvarchar(128) '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',
                   [IsPartial] bit '$.IsPartial',[FindingCount] bigint '$.FindingCount',[CtTableCount] bigint '$.CtTableCount',
                   [SourceFailureCount] int '$.SourceFailureCount',[Detail] nvarchar(2000) '$.Detail')
                 WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleDataCaptureDeepSourceÄ',N'ExampleDataCaptureDeepOtherÖ')
                   AND [StatusCode]='INVALID_PARAMETER' AND [IsPartial]=1 AND [FindingCount]=0 AND [CtTableCount]=0 AND [SourceFailureCount]=1 AND NULLIF([Detail],N'') IS NOT NULL)<>2)
                THROW 56321,N'DataCaptureDeep multi-database consumer status was overwritten.',1;
        END;
        DROP TABLE [#ExampleDeepExport];
        SET @Case+=1;
    END;
    /* Die gemeinsamen Exportpfade werden zusätzlich positiv aufgerufen. TABLE/JSON
       besitzt oben den vollständigen Zeilenvergleich; RAW/CONSOLE liefern hier Status und JSON-Gegenprobe. */
    SET @ClientVersion=@CurrentVersion+1;
    EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDataCaptureDeepSourceÄ]',@ChangeTrackingClientVersion=@ClientVersion,
         @MaxZeilen=1,@NurProblematisch=1,@HighImpactConfirmed=1,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@Json OUTPUT,
         @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>1
        THROW 56322,N'DataCaptureDeep positive RAW status or JSON count failed.',1;
    EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=N'[ExampleDataCaptureDeepSourceÄ]',@ChangeTrackingClientVersion=@ClientVersion,
         @MaxZeilen=1,@NurProblematisch=1,@HighImpactConfirmed=1,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,
         @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>1
        THROW 56323,N'DataCaptureDeep positive CONSOLE status or JSON count failed.',1;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleDataCaptureDeepSourceÄ')=@OwnedSourceId
    BEGIN
        ALTER DATABASE [ExampleDataCaptureDeepSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleDataCaptureDeepSourceÄ];
    END;
    IF DB_ID(N'ExampleDataCaptureDeepOtherÖ')=@OwnedOtherId
    BEGIN
        ALTER DATABASE [ExampleDataCaptureDeepOtherÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleDataCaptureDeepOtherÖ];
    END;
    SELECT @FrameworkLevel AS [FrameworkCompatibilityLevel],@SourceLevel AS [CtSourceCompatibilityLevel],@OtherLevel AS [SecondSourceCompatibilityLevel],
           @Case AS [TableJsonCases],N'CT-Metadaten und positive Findingfilter wurden geprüft; Retentionverlust, CDC und positive Replikationsquellen bleiben unbelegt.' AS [Detail];
END TRY
BEGIN CATCH
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedSourceId IS NOT NULL AND DB_ID(N'ExampleDataCaptureDeepSourceÄ')=@OwnedSourceId
    BEGIN
        ALTER DATABASE [ExampleDataCaptureDeepSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleDataCaptureDeepSourceÄ];
    END;
    IF @OwnedOtherId IS NOT NULL AND DB_ID(N'ExampleDataCaptureDeepOtherÖ')=@OwnedOtherId
    BEGIN
        ALTER DATABASE [ExampleDataCaptureDeepOtherÖ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleDataCaptureDeepOtherÖ];
    END;
    THROW;
END CATCH;
GO
