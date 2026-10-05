USE [DeineDatenbank];
GO

SET NOCOUNT ON;
DECLARE @Sample tinyint=0,@Json nvarchar(max),@Status varchar(40),@Partial bit;
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
WHILE @Sample<=1
BEGIN
    CREATE TABLE [#ExampleWorkerModule]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerSummary]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerSchedulers]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerWaits]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerRequests]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerSources]([Dummy] int NULL);
    CREATE TABLE [#ExampleWorkerWarnings]([Dummy] int NULL);
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
    EXEC [monitor].[USP_WorkerPressureAnalysis]
        @SampleSeconds=@Sample,@MinRequestElapsedMs=2147483647,@MaxZeilen=1,
        @ResultSetArt='TABLE',
        @ResultTablesJson=N'{"moduleStatus":"#ExampleWorkerModule","summary":"#ExampleWorkerSummary","schedulers":"#ExampleWorkerSchedulers","waits":"#ExampleWorkerWaits","requests":"#ExampleWorkerRequests","sourceStatus":"#ExampleWorkerSources","warnings":"#ExampleWorkerWarnings"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id] IN (OBJECT_ID(N'tempdb..#ExampleWorkerModule'),OBJECT_ID(N'tempdb..#ExampleWorkerSummary'),
              OBJECT_ID(N'tempdb..#ExampleWorkerSchedulers'),OBJECT_ID(N'tempdb..#ExampleWorkerWaits'),
              OBJECT_ID(N'tempdb..#ExampleWorkerRequests'),OBJECT_ID(N'tempdb..#ExampleWorkerSources'),
              OBJECT_ID(N'tempdb..#ExampleWorkerWarnings')) AND [collation_name] IS NOT NULL)<>22
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                 WHERE [object_id] IN (OBJECT_ID(N'tempdb..#ExampleWorkerModule'),OBJECT_ID(N'tempdb..#ExampleWorkerSummary'),
                       OBJECT_ID(N'tempdb..#ExampleWorkerSchedulers'),OBJECT_ID(N'tempdb..#ExampleWorkerWaits'),
                       OBJECT_ID(N'tempdb..#ExampleWorkerRequests'),OBJECT_ID(N'tempdb..#ExampleWorkerSources'),
                       OBJECT_ID(N'tempdb..#ExampleWorkerWarnings')) AND [collation_name] IS NOT NULL
                   AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55841,N'Ein WorkerPressure-Export übernimmt eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(@Partial,1)<>0
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
       OR (SELECT COUNT_BIG(*) FROM [#ExampleWorkerModule])<>1
       OR NOT EXISTS(SELECT 1 FROM [#ExampleWorkerModule]
                     WHERE [ModuleName]=N'USP_WorkerPressureAnalysis' AND [StatusCode]=@Status
                       AND [IsPartial]=0 AND [SampleSeconds]=@Sample
                       AND [ReturnedSchedulerRows]=(SELECT COUNT_BIG(*) FROM [#ExampleWorkerSchedulers])
                       AND [ReturnedRequestRows]=(SELECT COUNT_BIG(*) FROM [#ExampleWorkerRequests])
                       AND [ErrorNumber] IS NULL AND [ErrorMessage] IS NULL)
       OR (SELECT COUNT_BIG(*) FROM [#ExampleWorkerSources])<>4
       OR EXISTS(SELECT 1 FROM [#ExampleWorkerSources]
                 WHERE COALESCE([StatusCode],'')<>'AVAILABLE' OR COALESCE([IsPartial],1)<>0
                   OR [ErrorNumber] IS NOT NULL OR [ErrorMessage] IS NOT NULL)
       OR EXISTS(SELECT 1 FROM [#ExampleWorkerWarnings])
       OR (SELECT COUNT_BIG(*) FROM [#ExampleWorkerRequests])>1
       OR NOT EXISTS(SELECT 1 FROM [#ExampleWorkerSources] AS [s] CROSS JOIN [#ExampleWorkerModule] AS [m]
                     WHERE [s].[SourceName]=N'requests'
                       AND [m].[ReturnedRequestRows]=CASE WHEN [s].[ReturnedRowCount]>1 THEN 1 ELSE [s].[ReturnedRowCount] END
                       AND [m].[HasMoreRequestRows]=CASE WHEN [s].[ReturnedRowCount]>1 THEN 1 ELSE 0 END)
        THROW 55840,N'Der WorkerPressure-Modul-, Quellenstatus- oder Requestlimitvertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleWorkerSummary])<>1
       OR NOT EXISTS(SELECT 1 FROM [#ExampleWorkerSummary]
                     WHERE [VisibleOnlineSchedulers]>0
                       AND [VisibleOnlineSchedulers]=(SELECT COUNT_BIG(*) FROM [#ExampleWorkerSchedulers])
                       AND [CurrentWorkerCount]>0 AND [EffectiveMaxWorkers]=(SELECT [max_workers_count] FROM [sys].[dm_os_sys_info])
                       AND [ConfiguredMaxWorkerThreads]=(SELECT CONVERT(int,[value_in_use]) FROM [sys].[configurations]
                                                        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'max worker threads')
                       AND [WorkerOccupancyPercent]=CONVERT(decimal(9,2),100.0*[CurrentWorkerCount]/NULLIF([EffectiveMaxWorkers],0))
                       AND [AvailableWorkerCapacity]=CASE WHEN [EffectiveMaxWorkers]>[CurrentWorkerCount]
                                                          THEN [EffectiveMaxWorkers]-[CurrentWorkerCount] ELSE 0 END
                       AND [SampleSeconds]>=0 AND (@Sample=0 OR [SampleSeconds]>0))
       OR EXISTS(SELECT 1 FROM [#ExampleWorkerSchedulers] AS [e]
                 WHERE [e].[Status]<>N'VISIBLE ONLINE'
                   OR NOT EXISTS(SELECT 1 FROM [sys].[dm_os_schedulers] AS [s]
                                  WHERE [s].[scheduler_id]=[e].[SchedulerId] AND [s].[parent_node_id]=[e].[ParentNodeId]
                                    AND [s].[cpu_id]=[e].[CpuId] AND [s].[scheduler_id]<1048576
                                    AND [s].[status] COLLATE SQL_Latin1_General_CP1_CS_AS=N'VISIBLE ONLINE')
                   OR [e].[SampleSeconds]<>(SELECT [SampleSeconds] FROM [#ExampleWorkerSummary])
                   OR (@Sample=0 AND ([e].[WorkQueueDelta] IS NOT NULL OR [e].[RunnableTasksDelta] IS NOT NULL
                                     OR [e].[CurrentWorkersDelta] IS NOT NULL OR [e].[ActiveWorkersDelta] IS NOT NULL
                                     OR [e].[ContextSwitchDelta] IS NOT NULL OR [e].[YieldDelta] IS NOT NULL
                                     OR [e].[CpuUsageDeltaMs] IS NOT NULL OR [e].[SchedulerDelayDeltaMs] IS NOT NULL
                                     OR [e].[CounterResetDetected]<>0)))
        THROW 55842,N'Die positive WorkerPressure-Zusammenfassung oder native Scheduleridentität ist verletzt.',1;
    DELETE @Parity;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleWorkerSummary] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.summary')),
      ((SELECT * FROM [#ExampleWorkerSchedulers] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.schedulers')),
      ((SELECT * FROM [#ExampleWorkerWaits] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.waits')),
      ((SELECT * FROM [#ExampleWorkerRequests] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.requests')),
      ((SELECT * FROM [#ExampleWorkerSources] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.sourceStatus')),
      ((SELECT * FROM [#ExampleWorkerWarnings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.warnings'));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
               WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
                 OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55843,N'TABLE und JSON enthalten verschiedene WorkerPressure-Ergebnisse.',1;
    DROP TABLE [#ExampleWorkerModule];
    DROP TABLE [#ExampleWorkerSummary];
    DROP TABLE [#ExampleWorkerSchedulers];
    DROP TABLE [#ExampleWorkerWaits];
    DROP TABLE [#ExampleWorkerRequests];
    DROP TABLE [#ExampleWorkerSources];
    DROP TABLE [#ExampleWorkerWarnings];
    SET @Sample+=1;
END;
GO
