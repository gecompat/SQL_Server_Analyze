USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Path nvarchar(4000),@Pattern nvarchar(4000),@Sql nvarchar(max),@Created bit=0,
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@Case tinyint=0,@Limit int,@Xml bit,
        @Start datetime2(7),@End datetime2(7),@Expected bigint;
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name]=N'ExampleCommonCriticalEvents')
    THROW 55889,N'Die eigene Ereignisfixture darf keine bestehende XE-Session verwenden.',1;
SET @Path=CONVERT(nvarchar(4000),SERVERPROPERTY(N'InstanceDefaultLogPath'));
IF NULLIF(@Path,N'') IS NULL THROW 55889,N'Ein nativer Dateipfad für die eigene Ereignisfixture fehlt.',1;
SET @Path=CONCAT(@Path,N'example_common_critical_',CONVERT(nvarchar(36),NEWID()),N'.xel');
SET @Pattern=LEFT(@Path,LEN(@Path)-4)+N'*.xel';
CREATE TABLE [#ExampleCriticalNative]
(
    [TimestampUtc] datetime2(7) NULL,[EventName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ErrorNumber] int NULL,[Severity] int NULL,[ComponentName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [StateDesc] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MessageText] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EventXml] xml NULL
);
BEGIN TRY
    SET @Sql=N'CREATE EVENT SESSION [ExampleCommonCriticalEvents] ON SERVER
        ADD EVENT [sqlserver].[error_reported](WHERE ([error_number]=(50000) AND [severity]=(16)
            AND [sqlserver].[session_id]=('+CONVERT(nvarchar(20),@@SPID)+N')))
        ADD TARGET [package0].[event_file](SET filename=N'''+REPLACE(@Path,N'''',N'''''')+N''',max_file_size=(5),max_rollover_files=(1))
        WITH(MAX_DISPATCH_LATENCY=1 SECONDS,STARTUP_STATE=OFF);';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Created=1;
    ALTER EVENT SESSION [ExampleCommonCriticalEvents] ON SERVER STATE=START;
    BEGIN TRY RAISERROR(N'Example common critical event one.',16,1); END TRY BEGIN CATCH END CATCH;
    WAITFOR DELAY '00:00:00.250';
    BEGIN TRY RAISERROR(N'Example common critical event two.',16,1); END TRY BEGIN CATCH END CATCH;
    WAITFOR DELAY '00:00:02';
    ALTER EVENT SESSION [ExampleCommonCriticalEvents] ON SERVER STATE=STOP;
    WAITFOR DELAY '00:00:01';
    ;WITH [Events] AS
    (
        SELECT [timestamp_utc],[object_name],CONVERT(xml,[event_data]) AS [EventXml]
        FROM [sys].[fn_xe_file_target_read_file](@Pattern,NULL,NULL,NULL)
        WHERE [object_name]=N'error_reported'
    )
    INSERT [#ExampleCriticalNative]
    SELECT [timestamp_utc],[object_name],
           [EventXml].value('(event/data[@name="error_number"]/value/text())[1]','int'),
           [EventXml].value('(event/data[@name="severity"]/value/text())[1]','int'),
           [EventXml].value('(event/data[@name="component_name"]/value/text())[1]','sysname'),
           [EventXml].value('(event/data[@name="state_desc"]/value/text())[1]','sysname'),
           [EventXml].value('(event/data[@name="message"]/value/text())[1]','nvarchar(4000)'),[EventXml]
    FROM [Events];
    IF (SELECT COUNT_BIG(*) FROM [#ExampleCriticalNative])<>2
       OR (SELECT COUNT_BIG(*) FROM [#ExampleCriticalNative]
           WHERE [ErrorNumber]=50000 AND [Severity]=16
             AND [MessageText]=N'Example common critical event one.')<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleCriticalNative]
           WHERE [ErrorNumber]=50000 AND [Severity]=16
             AND [MessageText]=N'Example common critical event two.')<>1
       OR EXISTS(SELECT 1 FROM [#ExampleCriticalNative] WHERE [TimestampUtc] IS NULL)
        THROW 55889,N'Die zwei eigenen Ereignisse wurden nicht nativ bestätigt.',1;
    SELECT @Start=MIN([TimestampUtc]),@End=DATEADD(MICROSECOND,1,MAX([TimestampUtc]))
    FROM [#ExampleCriticalNative];
    WHILE @Case<3
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
               @Xml=CASE WHEN @Case=0 THEN 0 ELSE 1 END,@Expected=CASE WHEN @Case=1 THEN 1 ELSE 2 END;
        CREATE TABLE [#ExampleCriticalExport]([Dummy] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
        EXEC [monitor].[USP_CriticalEngineEvents] @SourceExtendedEventSessionName=N'ExampleCommonCriticalEvents',
            @VonUtc=@Start,@BisUtc=@End,@MinErrorSeverity=16,@MitSystemHealth=1,@MitServerDiagnostics=0,@MitEventXml=@Xml,
            @MaxZeilen=@Limit,@ResultSetArt='TABLE',@ResultTablesJson=N'{"events":"#ExampleCriticalExport"}',
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCriticalExport')
              AND [collation_name] IS NOT NULL)<>5
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCriticalExport')
                       AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55881,N'Der CriticalEngineEvents-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR JSON_VALUE(@Json,N'$.meta.errorNumber') IS NOT NULL OR JSON_VALUE(@Json,N'$.meta.errorMessage') IS NOT NULL
           OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]' OR COALESCE(JSON_QUERY(@Json,N'$.serverDiagnostics'),N'')<>N'[]'
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sources'))<>1
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sources')
                         WITH([StatusCode] varchar(40) '$.StatusCode',[ErrorNumber] int '$.ErrorNumber')
                         WHERE [StatusCode]='AVAILABLE' AND [ErrorNumber] IS NULL)
           OR (SELECT COUNT_BIG(*) FROM [#ExampleCriticalExport])<>@Expected
            THROW 55880,N'Der positive CriticalEngineEvents-Status- oder Limitvertrag ist verletzt.',1;
        IF EXISTS(SELECT 1 FROM [#ExampleCriticalExport] AS [e]
                  WHERE [e].[FindingCode]<>'SEVERE_ERROR_REPORTED' OR [e].[FindingCode] IS NULL
                     OR NOT EXISTS(SELECT 1 FROM [#ExampleCriticalNative] AS [n]
                                   WHERE NOT EXISTS(SELECT [e].[TimestampUtc],[e].[EventName],[e].[ErrorNumber],[e].[Severity],
                                                           [e].[ComponentName],[e].[StateDesc],[e].[MessageText],CONVERT(nvarchar(max),[e].[EventXml])
                                                    EXCEPT SELECT [n].[TimestampUtc],[n].[EventName],[n].[ErrorNumber],[n].[Severity],
                                                                  [n].[ComponentName],[n].[StateDesc],[n].[MessageText],
                                                                  CASE WHEN @Xml=1 THEN CONVERT(nvarchar(max),[n].[EventXml]) END COLLATE SQL_Latin1_General_CP1_CS_AS)))
           OR (@Case=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleCriticalExport]
                                      WHERE [TimestampUtc]=(SELECT MAX([TimestampUtc]) FROM [#ExampleCriticalNative])))
            THROW 55882,N'Die CriticalEngineEvents-Ausgabe weicht vom nativen Ereignis ab.',1;
        DELETE @Parity;
        INSERT @Parity VALUES((SELECT * FROM [#ExampleCriticalExport] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.events'));
        IF @Case<>1
            INSERT @Parity VALUES
            (
                (SELECT [TimestampUtc],[EventName],[ErrorNumber],[Severity],[ComponentName],[StateDesc],[MessageText],
                        'SEVERE_ERROR_REPORTED' AS [FindingCode],CASE WHEN @Xml=1 THEN [EventXml] END AS [EventXml]
                 FROM [#ExampleCriticalNative] FOR JSON PATH,INCLUDE_NULL_VALUES),
                (SELECT * FROM [#ExampleCriticalExport] FOR JSON PATH,INCLUDE_NULL_VALUES)
            );
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
        THROW 55883,N'TABLE und JSON enthalten verschiedene CriticalEngineEvents-Ergebnisse.',1;


        DROP TABLE [#ExampleCriticalExport];
        SET @Case+=1;
    END;
    DROP EVENT SESSION [ExampleCommonCriticalEvents] ON SERVER;
    SET @Created=0;
END TRY
BEGIN CATCH
    IF @Created=1 DROP EVENT SESSION [ExampleCommonCriticalEvents] ON SERVER;
    THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM [sys].[server_event_sessions] WHERE [name]=N'ExampleCommonCriticalEvents')
    THROW 55889,N'Die eigene Ereignisfixture wurde nicht entfernt.',1;
DROP TABLE [#ExampleCriticalNative];
GO
