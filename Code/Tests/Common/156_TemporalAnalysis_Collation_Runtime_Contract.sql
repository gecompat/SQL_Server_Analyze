USE [DeineDatenbank];
GO
/* Prüft eigene Temporal-Paare, native Metadaten und gemeinsame Exportverträge.
Nach acht leeren Fällen erzeugt ein eigener synthetischer Datensatz eine History-Version; die DMV-Kapazitätswerte bleiben approximativ. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleTemporalSourceÄ') IS NOT NULL THROW 56080,N'Temporal fixture already exists.',1;
DECLARE @OwnedDatabaseId int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @Sql nvarchar(max),@Case int=0,@Limit int,@Problems bit,@Objects nvarchar(max),
        @Names nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Partial bit,@Expected int;
BEGIN TRY
    CREATE DATABASE [ExampleTemporalSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedDatabaseId=DB_ID(N'ExampleTemporalSourceÄ');
    ALTER DATABASE [ExampleTemporalSourceÄ] SET TEMPORAL_HISTORY_RETENTION OFF;
    EXEC(N'USE [ExampleTemporalSourceÄ];
      CREATE TABLE [dbo].[ExampleTemporalHistoryÄ]
        ([Id] int NOT NULL,[ExampleValue] int NOT NULL,[ExampleStartÄ] datetime2 NOT NULL,[ExampleEndÜ] datetime2 NOT NULL);
      CREATE CLUSTERED INDEX [ExampleHistoryPeriodIndex] ON [dbo].[ExampleTemporalHistoryÄ]([ExampleEndÜ],[ExampleStartÄ]);
      CREATE TABLE [dbo].[ExampleTemporalTableÄ]
        ([Id] int NOT NULL PRIMARY KEY,[ExampleValue] int NOT NULL,
         [ExampleStartÄ] datetime2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL DEFAULT SYSUTCDATETIME(),
         [ExampleEndÜ] datetime2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL DEFAULT CONVERT(datetime2,''9999-12-31 23:59:59.9999999''),
         PERIOD FOR SYSTEM_TIME([ExampleStartÄ],[ExampleEndÜ]))
        WITH(SYSTEM_VERSIONING=ON(HISTORY_TABLE=[dbo].[ExampleTemporalHistoryÄ],DATA_CONSISTENCY_CHECK=OFF,HISTORY_RETENTION_PERIOD=7 DAYS));
      CREATE TABLE [dbo].[ExampleTemporalHistoryÜ]
        ([Id] int NOT NULL,[ExampleValue] int NOT NULL,[ExampleStartÄ] datetime2 NOT NULL,[ExampleEndÜ] datetime2 NOT NULL);
      CREATE INDEX [ExampleHistoryReverseIndex] ON [dbo].[ExampleTemporalHistoryÜ]([ExampleStartÄ],[ExampleEndÜ]);
      CREATE TABLE [dbo].[ExampleTemporalTableÜ]
        ([Id] int NOT NULL PRIMARY KEY,[ExampleValue] int NOT NULL,
         [ExampleStartÄ] datetime2 GENERATED ALWAYS AS ROW START NOT NULL DEFAULT SYSUTCDATETIME(),
         [ExampleEndÜ] datetime2 GENERATED ALWAYS AS ROW END NOT NULL DEFAULT CONVERT(datetime2,''9999-12-31 23:59:59.9999999''),
         PERIOD FOR SYSTEM_TIME([ExampleStartÄ],[ExampleEndÜ]))
        WITH(SYSTEM_VERSIONING=ON(HISTORY_TABLE=[dbo].[ExampleTemporalHistoryÜ],DATA_CONSISTENCY_CHECK=OFF));');
    CREATE TABLE [#ExampleTemporalNative]
      ([TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,
       [HistoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectId] int,[HistoryId] int,
       [StartName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[EndName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
       [StartHidden] bit,[EndHidden] bit,[PeriodLeading] bit);
    INSERT [#ExampleTemporalNative]
    SELECT [t].[name],[h].[name],[t].[object_id],[h].[object_id],[s].[name],[e].[name],[s].[is_hidden],[e].[is_hidden],
           CONVERT(bit,CASE WHEN EXISTS
             (SELECT 1 FROM [ExampleTemporalSourceÄ].[sys].[indexes] [i]
              JOIN [ExampleTemporalSourceÄ].[sys].[index_columns] [k1]
                ON [k1].[object_id]=[i].[object_id] AND [k1].[index_id]=[i].[index_id] AND [k1].[key_ordinal]=1
              JOIN [ExampleTemporalSourceÄ].[sys].[index_columns] [k2]
                ON [k2].[object_id]=[i].[object_id] AND [k2].[index_id]=[i].[index_id] AND [k2].[key_ordinal]=2
              JOIN [ExampleTemporalSourceÄ].[sys].[columns] [c1]
                ON [c1].[object_id]=[k1].[object_id] AND [c1].[column_id]=[k1].[column_id]
              JOIN [ExampleTemporalSourceÄ].[sys].[columns] [c2]
                ON [c2].[object_id]=[k2].[object_id] AND [c2].[column_id]=[k2].[column_id]
              WHERE [i].[object_id]=[h].[object_id] AND [i].[type] IN(1,2) AND [i].[is_disabled]=0
                AND [c1].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                AND [c2].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS)
           THEN 1 ELSE 0 END)
    FROM [ExampleTemporalSourceÄ].[sys].[tables] [t]
    JOIN [ExampleTemporalSourceÄ].[sys].[tables] [h] ON [h].[object_id]=[t].[history_table_id]
    JOIN [ExampleTemporalSourceÄ].[sys].[periods] [p] ON [p].[object_id]=[t].[object_id]
    JOIN [ExampleTemporalSourceÄ].[sys].[columns] [s] ON [s].[object_id]=[t].[object_id] AND [s].[column_id]=[p].[start_column_id]
    JOIN [ExampleTemporalSourceÄ].[sys].[columns] [e] ON [e].[object_id]=[t].[object_id] AND [e].[column_id]=[p].[end_column_id]
    WHERE [t].[temporal_type]=2;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleTemporalNative])<>2 THROW 56081,N'Own temporal native pairs missing.',1;
    DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
    IF NOT EXISTS(SELECT 1 FROM [#ExampleTemporalNative]
                  WHERE [TableName]=N'ExampleTemporalTableÄ' AND [HistoryName]=N'ExampleTemporalHistoryÄ'
                    AND [StartHidden]=1 AND [EndHidden]=1 AND [PeriodLeading]=1)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleTemporalNative]
                     WHERE [TableName]=N'ExampleTemporalTableÜ' AND [HistoryName]=N'ExampleTemporalHistoryÜ'
                       AND [StartHidden]=0 AND [EndHidden]=0 AND [PeriodLeading]=0)
        THROW 56088,N'Temporal fixture native hidden or index profiles unexpected.',1;
    WHILE @Case<8
    BEGIN
        SELECT @Limit=CASE WHEN @Case IN(1,3) THEN 1 WHEN @Case=4 THEN NULL ELSE 0 END,
               @Problems=CASE WHEN @Case IN(2,3,7) THEN 1 ELSE 0 END,
               @Objects=CASE WHEN @Case IN(5,7) THEN N'[ExampleTemporalTableÄ]' ELSE NULL END,
               @Names=CASE WHEN @Case=6 THEN N'[ExampleTemporalSourceÄ]|[ExampleTemporalMissingÖ]' ELSE N'[ExampleTemporalSourceÄ]' END,
               @Expected=CASE WHEN @Case IN(1,3) THEN 1 WHEN @Case=2 THEN 2 WHEN @Case=5 THEN 3 WHEN @Case=7 THEN 0 ELSE 6 END;
        IF @Case=7 ALTER DATABASE [ExampleTemporalSourceÄ] SET TEMPORAL_HISTORY_RETENTION ON;
        CREATE TABLE [#ExampleTemporalExport]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_TemporalAnalysis] @DatabaseNames=@Names,@ObjectNames=@Objects,@HighImpactConfirmed=1,
             @NurProblematisch=@Problems,@HistorySizeWarnMb=0,@HistoryRowsWarn=0,
             @HistoryToCurrentRatioWarn=1000000,@MinHistoryMbForRatioWarn=0,@MaxZeilen=@Limit,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleTemporalExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(@Status,'')<>CASE WHEN @Case=6 THEN 'AVAILABLE_LIMITED' WHEN @Case=7 THEN 'AVAILABLE' ELSE 'AVAILABLE_WITH_FINDING' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case=6 THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Case=6 THEN N'true' ELSE N'false' END
            THROW 56090,N'Temporal module status or partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleTemporalExport])<>@Expected
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>@Expected
           OR (@Problems=1 AND EXISTS(SELECT 1 FROM [#ExampleTemporalExport] WHERE COALESCE([Severity],'')<>'WARN'))
            THROW 56082,N'Temporal findings export limit or filter failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleTemporalExport') AND [collation_name] IS NOT NULL)<>12
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleTemporalExport') AND [collation_name] IS NOT NULL
                       AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56083,N'Temporal export text collation failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>4
           OR (SELECT COUNT_BIG(DISTINCT [SourceCode]) FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([DatabaseName] sysname '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
                 [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial')
            WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalSourceÄ'
              AND [StatusCode]='AVAILABLE' AND [IsPartial]=0
              AND [SourceCode] IN('TEMPORAL_FEATURE_GATE','TEMPORAL_CATALOG','TEMPORAL_CAPACITY','TEMPORAL_HISTORY_INDEX'))<>4
            THROW 56084,N'Temporal native sources are incomplete.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>CASE WHEN @Case=6 THEN 2 ELSE 1 END
           OR NOT EXISTS
           (SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
             ([DatabaseName] sysname '$.DatabaseName',[TemporalTableCount] bigint '$.TemporalTableCount',
              [HistoryTableCount] bigint '$.HistoryTableCount',[FindingCount] bigint '$.FindingCount',
              [SourceFailureCount] int '$.SourceFailureCount',[IsPartial] bit '$.IsPartial')
            WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalSourceÄ'
              AND [TemporalTableCount]=2 AND [HistoryTableCount]=2 AND [SourceFailureCount]=0 AND [IsPartial]=0
              AND [FindingCount]=CASE WHEN @Case=5 THEN 3 WHEN @Case=7 THEN 2 ELSE 6 END)
            THROW 56091,N'Temporal complete database counters changed with output selection.',1;
        IF EXISTS
           (SELECT 1 FROM [#ExampleTemporalExport]
            WHERE COALESCE([DatabaseName],N'')<>N'ExampleTemporalSourceÄ' OR COALESCE([SchemaName],N'')<>N'dbo'
               OR COALESCE([HistorySchemaName],N'')<>N'dbo'
               OR ([ObjectName]=N'ExampleTemporalTableÄ' AND COALESCE([HistoryTableName],N'')<>N'ExampleTemporalHistoryÄ')
               OR ([ObjectName]=N'ExampleTemporalTableÜ' AND COALESCE([HistoryTableName],N'')<>N'ExampleTemporalHistoryÜ')
               OR [FindingOrdinal] IS NULL)
           OR EXISTS(SELECT [FindingOrdinal] FROM [#ExampleTemporalExport] GROUP BY [FindingOrdinal] HAVING COUNT_BIG(*)<>1)
           OR EXISTS(SELECT [ObjectName],[FindingCode] FROM [#ExampleTemporalExport]
                     GROUP BY [ObjectName],[FindingCode] HAVING COUNT_BIG(*)<>1)
            THROW 56092,N'Temporal finding identity or multiplicity failed.',1;
        IF @Case IN(1,3) AND NOT EXISTS
           (SELECT 1 FROM [#ExampleTemporalExport] WHERE [FindingOrdinal]=1 AND [ObjectName]=N'ExampleTemporalTableÄ'
              AND [FindingCode]='RETENTION_CONFIGURED_DATABASE_CLEANUP_DISABLED' AND [Severity]='WARN')
            THROW 56093,N'Temporal limited first finding is not the independent retention warning.',1;
        CREATE TABLE [#ExampleTemporalExpectedFindings]
          ([ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS,
           [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,[Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,
           [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS,[MetricValue] decimal(38,4),[ThresholdValue] decimal(38,4));
        IF @Case<>7
            INSERT [#ExampleTemporalExpectedFindings] VALUES
              (N'ExampleTemporalTableÄ','RETENTION_CONFIGURED_DATABASE_CLEANUP_DISABLED','WARN','HIGH','DATABASE_RETENTION_ENABLED',0,1);
        IF @Case NOT IN(1,3,5,7)
            INSERT [#ExampleTemporalExpectedFindings] VALUES
              (N'ExampleTemporalTableÜ','HISTORY_PERIOD_INDEX_REVIEW','WARN','MEDIUM','PERIOD_LEADING_HISTORY_INDEX',0,1);
        IF @Problems=0 AND @Case<>1
        BEGIN
            INSERT [#ExampleTemporalExpectedFindings]
            SELECT [TableName],'LARGE_HISTORY_SIZE_CONTEXT','INFO','MEDIUM','HISTORY_RESERVED_MB',0,0
            FROM [#ExampleTemporalNative] WHERE @Objects IS NULL OR [TableName]=N'ExampleTemporalTableÄ';
            INSERT [#ExampleTemporalExpectedFindings]
            SELECT [TableName],'LARGE_HISTORY_ROW_CONTEXT','INFO','MEDIUM','HISTORY_ROWS_APPROX',0,0
            FROM [#ExampleTemporalNative] WHERE @Objects IS NULL OR [TableName]=N'ExampleTemporalTableÄ';
        END;
        IF EXISTS
           (SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue]
            FROM [#ExampleTemporalExpectedFindings]
            EXCEPT SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue]
            FROM [#ExampleTemporalExport])
           OR EXISTS
           (SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue]
            FROM [#ExampleTemporalExport]
            EXCEPT SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue]
            FROM [#ExampleTemporalExpectedFindings])
            THROW 56094,N'Temporal findings differ from independently expected identities and metrics.',1;
        DROP TABLE [#ExampleTemporalExpectedFindings];
        IF @Case IN(0,4,6) AND EXISTS
          (SELECT 1 FROM [#ExampleTemporalNative] [n] WHERE NOT EXISTS
            (SELECT 1 FROM OPENJSON(@Json,N'$.temporalTables') WITH
              ([CurrentTableName] sysname '$.CurrentTableName',[HistoryTableName] sysname '$.HistoryTableName',
               [CurrentObjectId] int '$.CurrentObjectId',[HistoryObjectId] int '$.HistoryObjectId',
               [PeriodStartColumnName] sysname '$.PeriodStartColumnName',[PeriodEndColumnName] sysname '$.PeriodEndColumnName',
               [PeriodStartIsHidden] bit '$.PeriodStartIsHidden',[PeriodEndIsHidden] bit '$.PeriodEndIsHidden',
               [HasPeriodLeadingHistoryIndex] bit '$.HasPeriodLeadingHistoryIndex') [r]
             WHERE [r].[CurrentTableName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[TableName]
               AND [r].[HistoryTableName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[HistoryName]
               AND [r].[CurrentObjectId]=[n].[ObjectId] AND [r].[HistoryObjectId]=[n].[HistoryId]
               AND [r].[PeriodStartColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[StartName]
               AND [r].[PeriodEndColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[EndName]
               AND [r].[PeriodStartIsHidden]=[n].[StartHidden] AND [r].[PeriodEndIsHidden]=[n].[EndHidden]
               AND [r].[HasPeriodLeadingHistoryIndex]=[n].[PeriodLeading]))
            THROW 56085,N'Temporal native mapping or history-index order failed.',1;
        IF @Case IN(0,4,6) AND
           ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.temporalTables'))<>2
            OR EXISTS(SELECT [CurrentObjectId] FROM OPENJSON(@Json,N'$.temporalTables')
                      WITH([CurrentObjectId] int '$.CurrentObjectId') GROUP BY [CurrentObjectId] HAVING COUNT_BIG(*)<>1)
            OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.temporalTables') WITH([CurrentObjectId] int '$.CurrentObjectId') [r]
                      WHERE [r].[CurrentObjectId] IS NULL OR NOT EXISTS
                            (SELECT 1 FROM [#ExampleTemporalNative] [n] WHERE [n].[ObjectId]=[r].[CurrentObjectId])))
            THROW 56089,N'Temporal native pair set is not exact.',1;
        IF @Case IN(0,4,5,6) AND
           ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.historyIndexes'))<>CASE WHEN @Case=5 THEN 1 ELSE 2 END
            OR EXISTS
             (SELECT 1 FROM OPENJSON(@Json,N'$.historyIndexes') WITH
               ([CurrentTableName] sysname '$.CurrentTableName',[HistoryTableName] sysname '$.HistoryTableName',
                [FirstKeyColumnName] sysname '$.FirstKeyColumnName',[SecondKeyColumnName] sysname '$.SecondKeyColumnName',
                [IsPeriodLeadingIndex] bit '$.IsPeriodLeadingIndex') [r]
              WHERE NOT EXISTS
               (SELECT 1 FROM [#ExampleTemporalNative] [n]
                WHERE [r].[CurrentTableName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[TableName]
                  AND [r].[HistoryTableName] COLLATE SQL_Latin1_General_CP1_CS_AS=[n].[HistoryName]
                  AND [r].[IsPeriodLeadingIndex]=[n].[PeriodLeading]
                  AND [r].[FirstKeyColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS=
                      CASE WHEN [n].[PeriodLeading]=1 THEN [n].[EndName] ELSE [n].[StartName] END
                  AND [r].[SecondKeyColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS=
                      CASE WHEN [n].[PeriodLeading]=1 THEN [n].[StartName] ELSE [n].[EndName] END))
            OR EXISTS
             (SELECT [CurrentTableName] FROM OPENJSON(@Json,N'$.historyIndexes')
               WITH([CurrentTableName] sysname '$.CurrentTableName')
              GROUP BY [CurrentTableName] HAVING COUNT_BIG(*)<>1))
            THROW 56095,N'Temporal native history-index set or leading columns failed.',1;
        IF @Case IN(0,4,5,6) AND EXISTS
           (SELECT 1 FROM OPENJSON(@Json,N'$.temporalTables') WITH
             ([CurrentTableName] sysname '$.CurrentTableName',[HistoryRetentionPeriod] int '$.HistoryRetentionPeriod',
              [HistoryRetentionUnitDesc] nvarchar(10) '$.HistoryRetentionUnitDesc',[RetentionMode] varchar(16) '$.RetentionMode',
              [DatabaseRetentionEnabled] bit '$.DatabaseRetentionEnabled',[CurrentRowsApprox] bigint '$.CurrentRowsApprox',
              [HistoryRowsApprox] bigint '$.HistoryRowsApprox',[HistoryIndexCount] int '$.HistoryIndexCount') [r]
            WHERE [r].[DatabaseRetentionEnabled]<>0 OR [r].[DatabaseRetentionEnabled] IS NULL
               OR [r].[CurrentRowsApprox]<>0 OR [r].[CurrentRowsApprox] IS NULL
               OR [r].[HistoryRowsApprox]<>0 OR [r].[HistoryRowsApprox] IS NULL
               OR [r].[HistoryIndexCount]<>1 OR [r].[HistoryIndexCount] IS NULL
               OR NOT EXISTS
                (SELECT 1 FROM [ExampleTemporalSourceÄ].[sys].[tables] [t]
                 WHERE [t].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[r].[CurrentTableName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   AND [t].[history_retention_period]=[r].[HistoryRetentionPeriod]
                   AND [t].[history_retention_period_unit_desc] COLLATE SQL_Latin1_General_CP1_CS_AS=
                       [r].[HistoryRetentionUnitDesc] COLLATE SQL_Latin1_General_CP1_CS_AS
                   AND [r].[RetentionMode]=CASE WHEN [t].[history_retention_period_unit]=-1 THEN 'INFINITE' ELSE 'FINITE' END))
            THROW 56096,N'Temporal retention or empty native metadata parity failed.',1;
        IF @Case=6 AND NOT EXISTS
          (SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus')
            WITH([DatabaseName] sysname '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial')
            WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalMissingÖ'
              AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1)
            THROW 56086,N'Temporal missing database status was overwritten.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
        (
          (SELECT * FROM [#ExampleTemporalExport] FOR JSON PATH,INCLUDE_NULL_VALUES),
          (SELECT * FROM OPENJSON(@Json,N'$.findings') WITH
            ([FindingOrdinal] bigint '$.FindingOrdinal',[DatabaseName] sysname '$.DatabaseName',
             [SchemaName] sysname '$.SchemaName',[ObjectName] sysname '$.ObjectName',
             [HistorySchemaName] sysname '$.HistorySchemaName',[HistoryTableName] sysname '$.HistoryTableName',
             [Severity] varchar(16) '$.Severity',[Confidence] varchar(16) '$.Confidence',
             [FindingCode] varchar(120) '$.FindingCode',[MetricName] varchar(80) '$.MetricName',
             [MetricValue] decimal(38,4) '$.MetricValue',[ThresholdValue] decimal(38,4) '$.ThresholdValue',
             [Evidence] nvarchar(1000) '$.Evidence',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit',
             [RecommendedNextCheck] nvarchar(1000) '$.RecommendedNextCheck')
           FOR JSON PATH,INCLUDE_NULL_VALUES)
        );
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleTemporalExport'))<>15
           OR EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
             ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
             ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
             ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
             ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56087,N'Temporal TABLE and JSON field multisets differ.',1;
        DROP TABLE [#ExampleTemporalExport];
        SET @Case+=1;
    END;
    /* Eigener nichtleerer History-Fall nach allen acht unveränderten Leerfällen. */
    DECLARE @PositiveDbId int=DB_ID(),@PositiveLoginId int=SUSER_ID(),
            @PositiveTran int=@@TRANCOUNT,@PositiveLock int=@@LOCK_TIMEOUT,
            @PositiveAbort int=CASE WHEN (@@OPTIONS & 16384)<>0 THEN 1 ELSE 0 END,
            @PositiveXact int=NULL,@PositiveCurrentId int=NULL,@PositiveHistoryId int=NULL,
            @Inserted int=0,@Updated int=0,@PhysicalCurrent bigint=NULL,@PhysicalHistory bigint=NULL,
            @NativeCurrentRows bigint=NULL,@NativeHistoryRows bigint=NULL,
            @NativeCurrentReservedMb decimal(19,2)=NULL,@NativeCurrentUsedMb decimal(19,2)=NULL,
            @NativeHistoryReservedMb decimal(19,2)=NULL,@NativeHistoryUsedMb decimal(19,2)=NULL,
            @NativeRatio decimal(19,4)=NULL,@PositiveJson nvarchar(max)=NULL,
            @PositiveStatus varchar(40)=NULL,@PositivePartial bit=NULL;
    SELECT @PositiveXact=XACT_STATE();
    SELECT @PositiveCurrentId=[ObjectId],@PositiveHistoryId=[HistoryId]
    FROM [#ExampleTemporalNative]
    WHERE [TableName]=N'ExampleTemporalTableÄ' COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [HistoryName]=N'ExampleTemporalHistoryÄ' COLLATE SQL_Latin1_General_CP1_CS_AS;
    IF @OwnedDatabaseId IS NULL OR DB_ID(N'ExampleTemporalSourceÄ')<>@OwnedDatabaseId
       OR @PositiveCurrentId IS NULL OR @PositiveHistoryId IS NULL
       OR NOT EXISTS
          (SELECT 1 FROM [ExampleTemporalSourceÄ].[sys].[tables]
           WHERE [object_id]=@PositiveCurrentId AND [history_table_id]=@PositiveHistoryId
             AND [temporal_type]=2)
        THROW 56460,N'Temporal positive own pair binding failed.',1;
    SET @Sql=N'USE [ExampleTemporalSourceÄ];
INSERT [dbo].[ExampleTemporalTableÄ]([Id],[ExampleValue]) VALUES(1,10);
SET @pRows=@@ROWCOUNT;';
    EXEC [sys].[sp_executesql] @Sql,N'@pRows int OUTPUT',@pRows=@Inserted OUTPUT;
    SET @Sql=N'USE [ExampleTemporalSourceÄ];
UPDATE [dbo].[ExampleTemporalTableÄ] SET [ExampleValue]=11 WHERE [Id]=1;
SET @pRows=@@ROWCOUNT;';
    EXEC [sys].[sp_executesql] @Sql,N'@pRows int OUTPUT',@pRows=@Updated OUTPUT;
    SELECT @PhysicalCurrent=COUNT_BIG(*) FROM [ExampleTemporalSourceÄ].[dbo].[ExampleTemporalTableÄ];
    SELECT @PhysicalHistory=COUNT_BIG(*) FROM [ExampleTemporalSourceÄ].[dbo].[ExampleTemporalHistoryÄ];
    IF @Inserted<>1 OR @Updated<>1 OR @PhysicalCurrent<>1 OR @PhysicalHistory<>1
        THROW 56461,N'Temporal own one-row versioning precondition failed.',1;
    SET @Sql=N'USE [ExampleTemporalSourceÄ];
SELECT @pCurrentRows=SUM(CASE WHEN [index_id] IN(0,1) THEN CONVERT(bigint,[row_count]) END),
       @pCurrentReservedMb=CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[reserved_page_count]))*8.0/1024.0),
       @pCurrentUsedMb=CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[used_page_count]))*8.0/1024.0)
FROM [sys].[dm_db_partition_stats] WHERE [object_id]=@pCurrentId;
SELECT @pHistoryRows=SUM(CASE WHEN [index_id] IN(0,1) THEN CONVERT(bigint,[row_count]) END),
       @pHistoryReservedMb=CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[reserved_page_count]))*8.0/1024.0),
       @pHistoryUsedMb=CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[used_page_count]))*8.0/1024.0)
FROM [sys].[dm_db_partition_stats] WHERE [object_id]=@pHistoryId;';
    EXEC [sys].[sp_executesql] @Sql,
         N'@pCurrentId int,@pHistoryId int,@pCurrentRows bigint OUTPUT,@pHistoryRows bigint OUTPUT,
           @pCurrentReservedMb decimal(19,2) OUTPUT,@pCurrentUsedMb decimal(19,2) OUTPUT,
           @pHistoryReservedMb decimal(19,2) OUTPUT,@pHistoryUsedMb decimal(19,2) OUTPUT',
         @pCurrentId=@PositiveCurrentId,@pHistoryId=@PositiveHistoryId,
         @pCurrentRows=@NativeCurrentRows OUTPUT,@pHistoryRows=@NativeHistoryRows OUTPUT,
         @pCurrentReservedMb=@NativeCurrentReservedMb OUTPUT,@pCurrentUsedMb=@NativeCurrentUsedMb OUTPUT,
         @pHistoryReservedMb=@NativeHistoryReservedMb OUTPUT,@pHistoryUsedMb=@NativeHistoryUsedMb OUTPUT;
    IF @NativeCurrentRows IS NULL OR @NativeCurrentRows<1
       OR @NativeHistoryRows IS NULL OR @NativeHistoryRows<1
       OR @NativeCurrentReservedMb IS NULL OR @NativeCurrentUsedMb IS NULL
       OR @NativeHistoryReservedMb IS NULL OR @NativeHistoryUsedMb IS NULL
        THROW 56462,N'Temporal native positive capacity precondition failed.',1;
    SET @NativeRatio=CONVERT(decimal(19,4),CONVERT(decimal(38,4),@NativeHistoryRows)/@NativeCurrentRows);
    IF @NativeRatio<1 OR DB_ID(N'ExampleTemporalSourceÄ')<>@OwnedDatabaseId
       OR NOT EXISTS
          (SELECT 1 FROM [ExampleTemporalSourceÄ].[sys].[tables]
           WHERE [object_id]=@PositiveCurrentId AND [history_table_id]=@PositiveHistoryId
             AND [temporal_type]=2)
        THROW 56463,N'Temporal positive ratio or own object binding failed.',1;
    CREATE TABLE [#ExampleTemporalPositiveFindings]([Dummy] int NULL);
    EXEC [monitor].[USP_TemporalAnalysis]
         @DatabaseNames=N'[ExampleTemporalSourceÄ]',@ObjectNames=N'[ExampleTemporalTableÄ]',
         @HistoryRowsWarn=1,@HistoryToCurrentRatioWarn=1,@MinHistoryMbForRatioWarn=0,
         @NurProblematisch=0,@MaxZeilen=0,@ResultSetArt='TABLE',
         @ResultTablesJson=N'{"findings":"#ExampleTemporalPositiveFindings"}',
         @JsonErzeugen=1,@Json=@PositiveJson OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@PositiveStatus OUTPUT,@IsPartialOut=@PositivePartial OUTPUT,
         @HighImpactConfirmed=1;
    IF COALESCE(ISJSON(@PositiveJson),0)<>1 OR COALESCE(@PositiveStatus,'')<>'AVAILABLE'
       OR COALESCE(CONVERT(int,@PositivePartial),-1)<>0
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@PositiveJson,N'$.temporalTables'))<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@PositiveJson,N'$.findings'))<>2
       OR (SELECT COUNT_BIG(*) FROM [#ExampleTemporalPositiveFindings])<>2
       OR NOT EXISTS
          (SELECT 1 FROM OPENJSON(@PositiveJson,N'$.sourceStatus') WITH
             ([DatabaseName] sysname '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
              [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount')
           WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalSourceÄ'
             AND [SourceCode]='TEMPORAL_CAPACITY' AND [StatusCode]='AVAILABLE'
             AND [IsPartial]=0 AND [RowCount]=1)
       OR NOT EXISTS
          (SELECT 1 FROM OPENJSON(@PositiveJson,N'$.databaseStatus') WITH
             ([DatabaseName] sysname '$.DatabaseName',[TemporalTableCount] bigint '$.TemporalTableCount',
              [HistoryTableCount] bigint '$.HistoryTableCount',[SourceFailureCount] int '$.SourceFailureCount',
              [IsPartial] bit '$.IsPartial')
           WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalSourceÄ'
             AND [TemporalTableCount]=2 AND [HistoryTableCount]=2
             AND [SourceFailureCount]=0 AND [IsPartial]=0)
        THROW 56464,N'Temporal positive status, source or output counts failed.',1;
    IF NOT EXISTS
       (SELECT 1 FROM OPENJSON(@PositiveJson,N'$.temporalTables') WITH
          ([DatabaseName] sysname '$.DatabaseName',[CurrentTableName] sysname '$.CurrentTableName',
           [CurrentObjectId] int '$.CurrentObjectId',[HistoryObjectId] int '$.HistoryObjectId',
           [CurrentRowsApprox] bigint '$.CurrentRowsApprox',[HistoryRowsApprox] bigint '$.HistoryRowsApprox',
           [CurrentReservedMb] decimal(19,2) '$.CurrentReservedMb',
           [CurrentUsedMb] decimal(19,2) '$.CurrentUsedMb',
           [HistoryReservedMb] decimal(19,2) '$.HistoryReservedMb',
           [HistoryUsedMb] decimal(19,2) '$.HistoryUsedMb',
           [HistoryToCurrentRowRatio] decimal(19,4) '$.HistoryToCurrentRowRatio')
        WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalSourceÄ'
          AND [CurrentTableName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleTemporalTableÄ'
          AND [CurrentObjectId]=@PositiveCurrentId AND [HistoryObjectId]=@PositiveHistoryId
          AND [CurrentRowsApprox]=@NativeCurrentRows AND [HistoryRowsApprox]=@NativeHistoryRows
          AND [CurrentReservedMb]=@NativeCurrentReservedMb AND [CurrentUsedMb]=@NativeCurrentUsedMb
          AND [HistoryReservedMb]=@NativeHistoryReservedMb AND [HistoryUsedMb]=@NativeHistoryUsedMb
          AND [HistoryToCurrentRowRatio]=@NativeRatio)
        THROW 56465,N'Temporal positive native capacity or ratio parity failed.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleTemporalPositiveFindings'))<>15
       OR EXISTS
          (SELECT 1 FROM OPENJSON(@PositiveJson,N'$.findings') WITH
             ([DatabaseName] sysname '$.DatabaseName',[ObjectName] sysname '$.ObjectName',
              [Severity] varchar(16) '$.Severity',[FindingCode] varchar(120) '$.FindingCode',
              [MetricName] varchar(80) '$.MetricName',[MetricValue] decimal(38,4) '$.MetricValue',
              [ThresholdValue] decimal(38,4) '$.ThresholdValue') [f]
           WHERE [f].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleTemporalSourceÄ'
              OR [f].[ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleTemporalTableÄ'
              OR [f].[Severity]<>'INFO'
              OR [f].[DatabaseName] IS NULL OR [f].[ObjectName] IS NULL
              OR [f].[Severity] IS NULL OR [f].[FindingCode] IS NULL
              OR [f].[MetricName] IS NULL OR [f].[MetricValue] IS NULL
              OR [f].[ThresholdValue] IS NULL
              OR NOT
                 (([f].[FindingCode]='LARGE_HISTORY_ROW_CONTEXT'
                   AND [f].[MetricName]='HISTORY_ROWS_APPROX'
                   AND [f].[MetricValue]=@NativeHistoryRows AND [f].[ThresholdValue]=1)
                  OR
                  ([f].[FindingCode]='HISTORY_TO_CURRENT_RATIO_CONTEXT'
                   AND [f].[MetricName]='HISTORY_TO_CURRENT_ROW_RATIO'
                   AND [f].[MetricValue]=@NativeRatio AND [f].[ThresholdValue]=1)))
       OR (SELECT COUNT_BIG(DISTINCT [FindingCode]) FROM OPENJSON(@PositiveJson,N'$.findings')
           WITH([FindingCode] varchar(120) '$.FindingCode'))<>2
        THROW 56466,N'Temporal positive threshold findings failed.',1;
    DELETE @Parity;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleTemporalPositiveFindings] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT * FROM OPENJSON(@PositiveJson,N'$.findings') WITH
         ([FindingOrdinal] bigint '$.FindingOrdinal',[DatabaseName] sysname '$.DatabaseName',
          [SchemaName] sysname '$.SchemaName',[ObjectName] sysname '$.ObjectName',
          [HistorySchemaName] sysname '$.HistorySchemaName',[HistoryTableName] sysname '$.HistoryTableName',
          [Severity] varchar(16) '$.Severity',[Confidence] varchar(16) '$.Confidence',
          [FindingCode] varchar(120) '$.FindingCode',[MetricName] varchar(80) '$.MetricName',
          [MetricValue] decimal(38,4) '$.MetricValue',[ThresholdValue] decimal(38,4) '$.ThresholdValue',
          [Evidence] nvarchar(1000) '$.Evidence',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit',
          [RecommendedNextCheck] nvarchar(1000) '$.RecommendedNextCheck')
        FOR JSON PATH,INCLUDE_NULL_VALUES));
    IF EXISTS
       (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
        CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
        (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
         ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
        GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
        EXCEPT
        SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
        CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
        (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
         ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
        GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
       OR EXISTS
       (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
        CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
        (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
         ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
        GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
        EXCEPT
        SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
        CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
        (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
         ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
        GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
        THROW 56467,N'Temporal positive findings TABLE JSON parity failed.',1;
    DECLARE @ActualDb int=DB_ID(),@ActualLogin int=SUSER_ID(),
            @ActualTran int=@@TRANCOUNT,@ActualLock int=@@LOCK_TIMEOUT,
            @ActualAbort int=CASE WHEN (@@OPTIONS & 16384)<>0 THEN 1 ELSE 0 END,
            @ActualXact int=NULL;
    SELECT @ActualXact=XACT_STATE();
    IF COALESCE(@ActualDb,-1)<>COALESCE(@PositiveDbId,-1)
       OR COALESCE(@ActualLogin,-1)<>COALESCE(@PositiveLoginId,-1)
       OR @ActualTran<>@PositiveTran OR @ActualLock<>@PositiveLock
       OR @ActualAbort<>@PositiveAbort OR @ActualXact<>@PositiveXact
    BEGIN
        RAISERROR(N'TEMPORAL_POSITIVE_CALLER originalDb=%d actualDb=%d originalLogin=%d actualLogin=%d originalTran=%d actualTran=%d originalLock=%d actualLock=%d originalAbort=%d actualAbort=%d originalXact=%d actualXact=%d',
                  10,1,@PositiveDbId,@ActualDb,@PositiveLoginId,@ActualLogin,
                  @PositiveTran,@ActualTran,@PositiveLock,@ActualLock,
                  @PositiveAbort,@ActualAbort,@PositiveXact,@ActualXact) WITH NOWAIT;
        THROW 56468,N'Temporal positive caller state changed.',1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleTemporalSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleTemporalSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleTemporalSourceÄ];
    END;
END TRY
BEGIN CATCH
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedDatabaseId IS NOT NULL AND DB_ID(N'ExampleTemporalSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleTemporalSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleTemporalSourceÄ];
    END;
    THROW;
END CATCH;
GO
