USE [DeineDatenbank];
GO
/* Prüft eigene leere Broker-Queues, native Metadaten und gemeinsame Findingsexports.
Nachrichten, Dialoge und Aktivierungsausführung sind nicht Bestandteil der Fixture. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleBrokerSourceÄ') IS NOT NULL THROW 56100,N'Broker fixture already exists.',1;
DECLARE @OwnedDatabaseId int=NULL,@OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @FrameworkLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID()),
        @Sql nvarchar(max),@Case int=0,@Limit int,@Problems bit,@Objects nvarchar(max),
        @Names nvarchar(max),@QueueRowsWarn bigint,@Json nvarchar(max),@Status varchar(40),@Partial bit;
BEGIN TRY
    CREATE DATABASE [ExampleBrokerSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedDatabaseId=DB_ID(N'ExampleBrokerSourceÄ');
    SET @Sql=N'ALTER DATABASE [ExampleBrokerSourceÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(3),@FrameworkLevel)+N';';
    EXEC(@Sql);
    ALTER DATABASE [ExampleBrokerSourceÄ] SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE;
    EXEC(N'USE [ExampleBrokerSourceÄ];
      CREATE QUEUE [dbo].[ExampleBrokerQueueÄ] WITH STATUS=OFF,RETENTION=OFF,POISON_MESSAGE_HANDLING(STATUS=OFF);
      CREATE SERVICE [ExampleBrokerServiceÄ] ON QUEUE [dbo].[ExampleBrokerQueueÄ] ([DEFAULT]);
      CREATE QUEUE [dbo].[ExampleBrokerQueueÜ] WITH STATUS=ON,RETENTION=ON;
      CREATE SERVICE [ExampleBrokerServiceÜ] ON QUEUE [dbo].[ExampleBrokerQueueÜ] ([DEFAULT]);');
    IF (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=@OwnedDatabaseId)<>@FrameworkLevel
       OR CONVERT(sysname,DATABASEPROPERTYEX(N'ExampleBrokerSourceÄ',N'Collation')) COLLATE SQL_Latin1_General_CP1_CS_AS<>N'Latin1_General_100_CI_AS'
        THROW 56101,N'Broker source compatibility level differs from framework.',1;
    CREATE TABLE [#ExampleBrokerNative]
      ([QueueName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[QueueObjectId] int,
       [ServiceCount] int,[IsActivationEnabled] bit,[IsReceiveEnabled] bit,[IsEnqueueEnabled] bit,
       [IsRetentionEnabled] bit,[IsPoisonMessageHandlingEnabled] bit,[MaxReaders] smallint,
       [ActivationProcedure] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS,[ExecuteAsPrincipalId] int,
       [QueueRowsApprox] bigint,[QueueReservedMb] decimal(19,2),[QueueUsedMb] decimal(19,2));
    INSERT [#ExampleBrokerNative]
    SELECT [q].[name],[q].[object_id],CONVERT(int,[svc].[ServiceCount]),[q].[is_activation_enabled],
           [q].[is_receive_enabled],[q].[is_enqueue_enabled],[q].[is_retention_enabled],
           [q].[is_poison_message_handling_enabled],[q].[max_readers],[q].[activation_procedure],
           [q].[execute_as_principal_id],[p].[RowsApprox],[p].[ReservedMb],[p].[UsedMb]
    FROM [ExampleBrokerSourceÄ].[sys].[service_queues] [q]
    OUTER APPLY (SELECT COUNT_BIG(*) AS [ServiceCount] FROM [ExampleBrokerSourceÄ].[sys].[services] [s]
                 WHERE [s].[service_queue_id]=[q].[object_id]) [svc]
    OUTER APPLY
      (SELECT SUM(CASE WHEN [index_id] IN(0,1) THEN CONVERT(bigint,[row_count]) END) AS [RowsApprox],
              CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[reserved_page_count]))*8.0/1024.0) AS [ReservedMb],
              CONVERT(decimal(19,2),SUM(CONVERT(decimal(38,2),[used_page_count]))*8.0/1024.0) AS [UsedMb]
       FROM [ExampleBrokerSourceÄ].[sys].[dm_db_partition_stats] WHERE [object_id]=[q].[object_id]) [p]
    WHERE [q].[is_ms_shipped]=0;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleBrokerNative])<>2
       OR EXISTS(SELECT 1 FROM [#ExampleBrokerNative] WHERE [ServiceCount]<>1 OR [QueueRowsApprox]<>0
                    OR [IsActivationEnabled]<>0 OR [ActivationProcedure] IS NOT NULL)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleBrokerNative] WHERE [QueueName]=N'ExampleBrokerQueueÄ'
                     AND [IsReceiveEnabled]=0 AND [IsRetentionEnabled]=0 AND [IsPoisonMessageHandlingEnabled]=0)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleBrokerNative] WHERE [QueueName]=N'ExampleBrokerQueueÜ'
                     AND [IsReceiveEnabled]=1 AND [IsRetentionEnabled]=1 AND [IsPoisonMessageHandlingEnabled]=1)
        THROW 56102,N'Broker native fixture profile failed.',1;
    CREATE TABLE [#ExampleBrokerExpected]
      ([ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS,
       [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,[Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,
       [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS,[MetricValue] decimal(38,4),[ThresholdValue] decimal(38,4));
    DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
    WHILE @Case<9
    BEGIN
        SELECT @Limit=CASE WHEN @Case IN(1,3) THEN 1 WHEN @Case=4 THEN NULL ELSE 0 END,
               @Problems=CASE WHEN @Case IN(2,3,7) THEN 1 ELSE 0 END,
               @Objects=CASE WHEN @Case=5 THEN N'[ExampleBrokerQueueÄ]' WHEN @Case=7 THEN N'[ExampleBrokerQueueÜ]'
                             WHEN @Case=8 THEN N'[exampleBrokerQueueä]' ELSE NULL END,
               @Names=CASE WHEN @Case=6 THEN N'[ExampleBrokerSourceÄ]|[ExampleBrokerMissingÖ]' ELSE N'[ExampleBrokerSourceÄ]' END,
               @QueueRowsWarn=CASE WHEN @Case=7 THEN 10000 ELSE 0 END;
        DELETE [#ExampleBrokerExpected];
        INSERT [#ExampleBrokerExpected]
        SELECT [QueueName],'QUEUE_RECEIVE_DISABLED','WARN','HIGH','IS_RECEIVE_ENABLED',0,1
        FROM [#ExampleBrokerNative] WHERE [IsReceiveEnabled]=0;
        INSERT [#ExampleBrokerExpected]
        SELECT [QueueName],'QUEUE_ENQUEUE_DISABLED','WARN','HIGH','IS_ENQUEUE_ENABLED',0,1
        FROM [#ExampleBrokerNative] WHERE [IsEnqueueEnabled]=0;
        INSERT [#ExampleBrokerExpected]
        SELECT [QueueName],'QUEUE_BACKLOG_CONTEXT','WARN','MEDIUM','QUEUE_ROWS_APPROX',[QueueRowsApprox],@QueueRowsWarn
        FROM [#ExampleBrokerNative] WHERE [QueueRowsApprox]>=@QueueRowsWarn;
        INSERT [#ExampleBrokerExpected]
        SELECT [QueueName],'QUEUE_RETENTION_ENABLED_CONTEXT','INFO','MEDIUM','IS_RETENTION_ENABLED',1,0
        FROM [#ExampleBrokerNative] WHERE [IsRetentionEnabled]=1;
        INSERT [#ExampleBrokerExpected]
        SELECT [QueueName],'POISON_HANDLING_DISABLED_CONTEXT','INFO','MEDIUM','IS_POISON_HANDLING_ENABLED',0,1
        FROM [#ExampleBrokerNative] WHERE [IsPoisonMessageHandlingEnabled]=0;
        IF @Objects IS NOT NULL DELETE [#ExampleBrokerExpected]
            WHERE [ObjectName]<>CASE WHEN @Case=5 THEN N'ExampleBrokerQueueÄ' WHEN @Case=7 THEN N'ExampleBrokerQueueÜ' ELSE N'exampleBrokerQueueä' END;
        DECLARE @FullCount bigint=(SELECT COUNT_BIG(*) FROM [#ExampleBrokerExpected]),
                @WarnCount bigint=(SELECT COUNT_BIG(*) FROM [#ExampleBrokerExpected] WHERE [Severity]='WARN'),
                @QueueCount int=CASE WHEN @Case=8 THEN 0 WHEN @Objects IS NOT NULL THEN 1 ELSE 2 END;
        IF @Problems=1 DELETE [#ExampleBrokerExpected] WHERE [Severity]<>'WARN';
        IF @Limit=1 DELETE [#ExampleBrokerExpected]
            WHERE [FindingCode]<>'QUEUE_RECEIVE_DISABLED' OR [ObjectName]<>N'ExampleBrokerQueueÄ';
        CREATE TABLE [#ExampleBrokerExport]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_ServiceBrokerAnalysis] @DatabaseNames=@Names,@ObjectNames=@Objects,@HighImpactConfirmed=1,
             @NurProblematisch=@Problems,@QueueRowsWarn=@QueueRowsWarn,@MaxZeilen=@Limit,
             @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleBrokerExport"}',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(@Status,'')<>CASE WHEN @Case=6 THEN 'AVAILABLE_LIMITED' WHEN @WarnCount=0 THEN 'AVAILABLE' ELSE 'AVAILABLE_WITH_FINDING' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case=6 THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Case=6 THEN N'true' ELSE N'false' END
            THROW 56110,N'Broker module status or partiality failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleBrokerExport])<>(SELECT COUNT_BIG(*) FROM [#ExampleBrokerExpected])
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>(SELECT COUNT_BIG(*) FROM [#ExampleBrokerExpected])
           OR (@Problems=1 AND EXISTS(SELECT 1 FROM [#ExampleBrokerExport] WHERE COALESCE([Severity],'')<>'WARN'))
            THROW 56111,N'Broker findings export limit or filter failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBrokerExport'))<>13
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBrokerExport') AND [collation_name] IS NOT NULL)<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleBrokerExport') AND [collation_name] IS NOT NULL
                     AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56112,N'Broker export schema or text collation failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>7
           OR (SELECT COUNT_BIG(DISTINCT [SourceCode]) FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                 ([DatabaseName] sysname '$.DatabaseName',[SourceCode] varchar(64) '$.SourceCode',
                  [StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',[RowCount] bigint '$.RowCount')
               WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleBrokerSourceÄ'
                 AND [StatusCode]='AVAILABLE' AND [IsPartial]=0
                 AND [SourceCode] IN('BROKER_FEATURE_GATE','BROKER_QUEUE_CATALOG','BROKER_QUEUE_CAPACITY',
                                    'BROKER_QUEUE_MONITOR','BROKER_ACTIVATED_TASKS','BROKER_TRANSMISSION','BROKER_CONVERSATION')
                 AND [RowCount]=CASE WHEN [SourceCode]='BROKER_FEATURE_GATE' THEN 1
                                     WHEN [SourceCode] IN('BROKER_TRANSMISSION','BROKER_CONVERSATION') THEN 0 ELSE @QueueCount END)<>7
            THROW 56113,N'Broker independent source set or row counts failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseStatus'))<>CASE WHEN @Case=6 THEN 2 ELSE 1 END
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
             ([DatabaseName] sysname '$.DatabaseName',[IsBrokerEnabled] bit '$.IsBrokerEnabled',[UserQueueCount] bigint '$.UserQueueCount',
              [UserServiceCount] bigint '$.UserServiceCount',[TransmissionMessageCount] bigint '$.TransmissionMessageCount',
              [ConversationEndpointCount] bigint '$.ConversationEndpointCount',[FindingCount] bigint '$.FindingCount',
              [SourceFailureCount] int '$.SourceFailureCount',[IsPartial] bit '$.IsPartial')
             WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleBrokerSourceÄ' AND [IsBrokerEnabled]=1
               AND [UserQueueCount]=2 AND [UserServiceCount]=2 AND [TransmissionMessageCount]=0 AND [ConversationEndpointCount]=0
               AND [FindingCount]=@FullCount AND [SourceFailureCount]=0 AND [IsPartial]=0)
            THROW 56114,N'Broker complete counters changed with output selection.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleBrokerExport] WHERE COALESCE([DatabaseName],N'')<>N'ExampleBrokerSourceÄ'
                      OR COALESCE([SchemaName],N'')<>N'dbo' OR [FindingOrdinal] IS NULL
                      OR NULLIF([Evidence],N'') IS NULL OR NULLIF([EvidenceLimit],N'') IS NULL OR NULLIF([RecommendedNextCheck],N'') IS NULL)
           OR EXISTS(SELECT [FindingOrdinal] FROM [#ExampleBrokerExport] GROUP BY [FindingOrdinal] HAVING COUNT_BIG(*)<>1)
           OR EXISTS(SELECT [ObjectName],[FindingCode] FROM [#ExampleBrokerExport] GROUP BY [ObjectName],[FindingCode] HAVING COUNT_BIG(*)<>1)
           OR EXISTS(SELECT * FROM [#ExampleBrokerExpected] EXCEPT
                     SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue] FROM [#ExampleBrokerExport])
           OR EXISTS(SELECT [ObjectName],[FindingCode],[Severity],[Confidence],[MetricName],[MetricValue],[ThresholdValue] FROM [#ExampleBrokerExport]
                     EXCEPT SELECT * FROM [#ExampleBrokerExpected])
            THROW 56115,N'Broker finding identities or independently expected metrics failed.',1;
        IF @Limit=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleBrokerExport] WHERE [FindingOrdinal]=1 AND [ObjectName]=N'ExampleBrokerQueueÄ'
                                   AND [FindingCode]='QUEUE_RECEIVE_DISABLED' AND [Severity]='WARN')
            THROW 56116,N'Broker first limited finding failed.',1;
        IF @Case IN(0,4,6) AND
           ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.queues'))<>2
            OR EXISTS(SELECT [QueueObjectId] FROM OPENJSON(@Json,N'$.queues') WITH([QueueObjectId] int '$.QueueObjectId')
                      GROUP BY [QueueObjectId] HAVING COUNT_BIG(*)<>1)
            OR EXISTS
              (SELECT 1 FROM OPENJSON(@Json,N'$.queues') WITH
                ([DatabaseName] sysname '$.DatabaseName',[SchemaName] sysname '$.SchemaName',[QueueName] sysname '$.QueueName',
                 [QueueObjectId] int '$.QueueObjectId',[ServiceCount] int '$.ServiceCount',[IsBrokerEnabled] bit '$.IsBrokerEnabled',
                 [IsActivationEnabled] bit '$.IsActivationEnabled',[IsReceiveEnabled] bit '$.IsReceiveEnabled',[IsEnqueueEnabled] bit '$.IsEnqueueEnabled',
                 [IsRetentionEnabled] bit '$.IsRetentionEnabled',[IsPoisonMessageHandlingEnabled] bit '$.IsPoisonMessageHandlingEnabled',
                 [MaxReaders] smallint '$.MaxReaders',[ActivationProcedure] nvarchar(776) '$.ActivationProcedure',
                 [ExecuteAsPrincipalId] int '$.ExecuteAsPrincipalId',[QueueRowsApprox] bigint '$.QueueRowsApprox',
                 [QueueReservedMb] decimal(19,2) '$.QueueReservedMb',[QueueUsedMb] decimal(19,2) '$.QueueUsedMb',[ActivatedTaskCount] int '$.ActivatedTaskCount') [r]
               WHERE [r].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleBrokerSourceÄ'
                  OR [r].[SchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'dbo' OR COALESCE([r].[IsBrokerEnabled],0)<>1
                  OR COALESCE([r].[ActivatedTaskCount],-1)<>0 OR [r].[ActivationProcedure] IS NOT NULL
                  OR NOT EXISTS(SELECT 1 FROM [#ExampleBrokerNative] [n] WHERE [n].[QueueObjectId]=[r].[QueueObjectId]
                      AND [n].[QueueName]=[r].[QueueName] COLLATE SQL_Latin1_General_CP1_CS_AS AND [n].[ServiceCount]=[r].[ServiceCount]
                      AND [n].[IsActivationEnabled]=[r].[IsActivationEnabled] AND [n].[IsReceiveEnabled]=[r].[IsReceiveEnabled]
                      AND [n].[IsEnqueueEnabled]=[r].[IsEnqueueEnabled] AND [n].[IsRetentionEnabled]=[r].[IsRetentionEnabled]
                      AND [n].[IsPoisonMessageHandlingEnabled]=[r].[IsPoisonMessageHandlingEnabled]
                      AND [n].[MaxReaders]=[r].[MaxReaders] AND ([n].[ExecuteAsPrincipalId]=[r].[ExecuteAsPrincipalId]
                            OR ([n].[ExecuteAsPrincipalId] IS NULL AND [r].[ExecuteAsPrincipalId] IS NULL))
                      AND ([n].[QueueRowsApprox]=[r].[QueueRowsApprox] OR ([n].[QueueRowsApprox] IS NULL AND [r].[QueueRowsApprox] IS NULL))
                      AND ([n].[QueueReservedMb]=[r].[QueueReservedMb] OR ([n].[QueueReservedMb] IS NULL AND [r].[QueueReservedMb] IS NULL))
                      AND ([n].[QueueUsedMb]=[r].[QueueUsedMb] OR ([n].[QueueUsedMb] IS NULL AND [r].[QueueUsedMb] IS NULL)))))
            THROW 56117,N'Broker native queue metadata parity failed.',1;
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.transmissionGroups'))<>0
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.conversationStates'))<>0
            THROW 56118,N'Broker own empty transmission or conversation scope failed.',1;
        IF @Case=6 AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
             ([DatabaseName] sysname '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial',
              [SourceFailureCount] int '$.SourceFailureCount',[FindingCount] bigint '$.FindingCount')
             WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleBrokerMissingÖ'
               AND [StatusCode]='DATABASE_UNAVAILABLE' AND [IsPartial]=1 AND [SourceFailureCount]=1 AND [FindingCount]=0)
            THROW 56119,N'Broker missing selection warning was overwritten.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
        ((SELECT * FROM [#ExampleBrokerExport] FOR JSON PATH,INCLUDE_NULL_VALUES),
         (SELECT * FROM OPENJSON(@Json,N'$.findings') WITH
           ([FindingOrdinal] bigint '$.FindingOrdinal',[DatabaseName] sysname '$.DatabaseName',[SchemaName] sysname '$.SchemaName',
            [ObjectName] sysname '$.ObjectName',[Severity] varchar(16) '$.Severity',[Confidence] varchar(16) '$.Confidence',
            [FindingCode] varchar(120) '$.FindingCode',[MetricName] varchar(80) '$.MetricName',[MetricValue] decimal(38,4) '$.MetricValue',
            [ThresholdValue] decimal(38,4) '$.ThresholdValue',[Evidence] nvarchar(1000) '$.Evidence',
            [EvidenceLimit] nvarchar(1000) '$.EvidenceLimit',[RecommendedNextCheck] nvarchar(1000) '$.RecommendedNextCheck')
          FOR JSON PATH,INCLUDE_NULL_VALUES));
        IF EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS
           (SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[ModuleJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM @Parity [p]
            CROSS APPLY OPENJSON([p].[TableJson]) [r] CROSS APPLY
            (SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 56120,N'Broker TABLE and JSON field multisets differ.',1;
        DROP TABLE [#ExampleBrokerExport];
        SET @Case+=1;
    END;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF DB_ID(N'ExampleBrokerSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleBrokerSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleBrokerSourceÄ];
    END;
END TRY
BEGIN CATCH
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';'; EXEC(@Sql);
    IF @OwnedDatabaseId IS NOT NULL AND DB_ID(N'ExampleBrokerSourceÄ')=@OwnedDatabaseId
    BEGIN
        ALTER DATABASE [ExampleBrokerSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleBrokerSourceÄ];
    END;
    THROW;
END CATCH;
GO
