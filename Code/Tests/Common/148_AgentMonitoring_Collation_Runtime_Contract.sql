USE [DeineDatenbank];
GO
-- Ausschließlich eigene Jobdefinitionen im neu erzeugten lokalen Testcontainer.
-- Der Vertrag startet keine Jobs und erzeugt keine Mail oder Alertaktionen.
SET NOCOUNT ON;
DECLARE @First sysname=N'ExampleMonitoringJobÄ',@Second sysname=N'ExampleMonitoringJobÜ',
        @FirstId uniqueidentifier,@SecondId uniqueidentifier,@Return int,@Case tinyint=0,
        @Limit int,@Jobs bit,@Rows bigint,@JobRows bigint,@Json nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@RestoreLockTimeout nvarchar(100)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs]) OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysalerts])
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysnotifications]) OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysmail_allitems])
    THROW 55970,N'Die erforderlichen leeren nativen Agent-/Mail-Fixtures sind nicht vorhanden.',1;
CREATE TABLE [#ExampleMonitoringRequirements]
([Requirement] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[MessageId] int,[Severity] int);
INSERT [#ExampleMonitoringRequirements] VALUES
(N'MESSAGE_823',823,0),(N'MESSAGE_824',824,0),(N'MESSAGE_825',825,0),
(N'SEVERITY_19',0,19),(N'SEVERITY_20',0,20),(N'SEVERITY_21',0,21),(N'SEVERITY_22',0,22),
(N'SEVERITY_23',0,23),(N'SEVERITY_24',0,24),(N'SEVERITY_25',0,25);
CREATE TABLE [#ExampleMonitoringNativeFindings]
([Category] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [ScopeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[MetricValue] bigint);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    EXEC @Return=[msdb].[dbo].[sp_add_job] @job_name=@First,@enabled=1,@notify_level_eventlog=0,@job_id=@FirstId OUTPUT;
    IF @Return<>0 OR @FirstId IS NULL THROW 55970,N'Die eigene aktivierte Jobdefinition fehlt.',1;
    EXEC @Return=[msdb].[dbo].[sp_add_job] @job_name=@Second,@enabled=0,@notify_level_eventlog=0,@job_id=@SecondId OUTPUT;
    IF @Return<>0 OR @SecondId IS NULL THROW 55970,N'Die eigene deaktivierte Jobdefinition fehlt.',1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs])<>2
       OR NOT EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@FirstId AND [name]=@First AND [enabled]=1)
       OR NOT EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@SecondId AND [name]=@Second AND [enabled]=0)
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] IN(@FirstId,@SecondId))
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobschedules] WHERE [job_id] IN(@FirstId,@SecondId))
       OR EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobhistory] WHERE [job_id] IN(@FirstId,@SecondId))
        THROW 55970,N'Die nativen eigenen Jobs besitzen unerwartete Schritte, Zeitpläne oder Historie.',1;
    SELECT [job_id] AS [JobId],[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [JobName],[enabled] AS [IsEnabled],
       CONVERT(datetime,NULL) AS [LatestRunDateTime],CONVERT(int,NULL) AS [LatestRunStatus],CONVERT(int,NULL) AS [LatestRunDuration],
       CONVERT(bigint,0) AS [ScheduleCount],CONVERT(bigint,0) AS [EnabledScheduleCount],
       CONVERT(varchar(100),CASE WHEN [enabled]=1 THEN 'ENABLED_JOB_WITHOUT_SCHEDULE' ELSE 'JOB_STATE_INFORMATIONAL' END)
          COLLATE SQL_Latin1_General_CP1_CS_AS AS [FindingCode],
       CONVERT(varchar(16),'INFO') COLLATE SQL_Latin1_General_CP1_CS_AS AS [FindingSeverity]
    INTO [#ExampleMonitoringNativeJobs] FROM [msdb].[dbo].[sysjobs] WHERE [job_id] IN(@FirstId,@SecondId);
    SELECT [servicename] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ServiceName],
       [status_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [StatusDesc],
       [startup_type_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [StartupTypeDesc],[last_startup_time] AS [LastStartupTime],
       CONVERT(varchar(80),CASE WHEN [status_desc]=N'Running' THEN 'AGENT_SERVICE_RUNNING' ELSE 'AGENT_SERVICE_NOT_RUNNING' END)
          COLLATE SQL_Latin1_General_CP1_CS_AS AS [FindingCode]
    INTO [#ExampleMonitoringNativeServices] FROM [sys].[dm_server_services] WHERE [servicename] LIKE N'SQL Server Agent%';
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
               @Jobs=CASE WHEN @Case=3 THEN 0 ELSE 1 END,@Rows=CASE WHEN @Case=1 THEN 1 WHEN @Case=3 THEN 10 ELSE 11 END,
               @JobRows=CASE WHEN @Case=3 THEN 0 WHEN @Case=1 THEN 1 ELSE 2 END,
               @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
        DELETE [#ExampleMonitoringNativeFindings];
        INSERT [#ExampleMonitoringNativeFindings]
        SELECT 'ALERT_COVERAGE','REQUIRED_AGENT_ALERT_MISSING','HIGH',N'ALERT_REQUIREMENT',[r].[Requirement],NULL
        FROM [#ExampleMonitoringRequirements] AS [r] WHERE NOT EXISTS
        (SELECT 1 FROM [msdb].[dbo].[sysalerts] AS [a] WHERE [a].[enabled]=1
          AND (([r].[MessageId]>0 AND [a].[message_id]=[r].[MessageId]) OR ([r].[Severity]>0 AND [a].[severity]=[r].[Severity])));
        IF @Jobs=1 INSERT [#ExampleMonitoringNativeFindings]
        SELECT 'JOB_ACTIVITY',[FindingCode],[FindingSeverity],N'JOB',[JobName],NULL
        FROM [#ExampleMonitoringNativeJobs] WHERE [IsEnabled]=1;
        IF (SELECT COUNT_BIG(*) FROM [#ExampleMonitoringNativeFindings])<>CASE WHEN @Jobs=1 THEN 11 ELSE 10 END
            THROW 55970,N'Die native Alertabdeckung oder der eigene On-demand-Jobfall fehlt.',1;
        CREATE TABLE [#ExampleMonitoringFindings]([Dummy] int NULL);
        EXEC [monitor].[USP_AgentMonitoringAnalysis] @MitJobStatus=@Jobs,@MitDatabaseMail=@Jobs,@MaxZeilen=@Limit,
          @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleMonitoringFindings"}',
          @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
          @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMonitoringFindings') AND [collation_name] IS NOT NULL)<>7
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleMonitoringFindings')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55971,N'Der Agent-Monitoring-Export übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
           OR @Error IS NOT NULL OR @Message IS NOT NULL
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
           OR (SELECT COUNT_BIG(*) FROM [#ExampleMonitoringFindings])<>@Rows
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>@Rows
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.jobs'))<>@JobRows
           OR COALESCE(JSON_QUERY(@Json,N'$.mailStatus'),N'')<>N'[]'
           OR EXISTS(SELECT 1 FROM [#ExampleMonitoringFindings] WHERE NULLIF([Evidence],N'') IS NULL OR NULLIF([EvidenceLimit],N'') IS NULL)
            THROW 55972,N'Der Agent-Monitoring-Status-, Limit- oder Opt-out-Vertrag ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
          ((SELECT TOP(@Rows) * FROM [#ExampleMonitoringNativeFindings]
              ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[Category],[ScopeName] FOR JSON PATH,INCLUDE_NULL_VALUES),
           (SELECT [Category],[FindingCode],[Severity],[ScopeType],[ScopeName],[MetricValue] FROM [#ExampleMonitoringFindings] FOR JSON PATH,INCLUDE_NULL_VALUES)),
          ((SELECT * FROM [#ExampleMonitoringFindings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.findings')),
          (COALESCE((SELECT TOP(@JobRows) * FROM [#ExampleMonitoringNativeJobs] ORDER BY [JobName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),JSON_QUERY(@Json,N'$.jobs')),
          (COALESCE((SELECT * FROM [#ExampleMonitoringNativeServices] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),JSON_QUERY(@Json,N'$.services'));
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE LEFT(COALESCE([p].[ActualJson],N''),1)<>N'['
           OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]))
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
            THROW 55974,N'Die native Agent-Monitoring- oder TABLE-/JSON-Multimengenparität fehlt.',1;
        DROP TABLE [#ExampleMonitoringFindings];
        SET @Case+=1;
    END;
    DROP TABLE [#ExampleMonitoringNativeJobs]; DROP TABLE [#ExampleMonitoringNativeServices];
    DROP TABLE [#ExampleMonitoringNativeFindings]; DROP TABLE [#ExampleMonitoringRequirements];
END TRY
BEGIN CATCH
    IF @SecondId IS NOT NULL EXEC [msdb].[dbo].[sp_delete_job] @job_id=@SecondId,@delete_unused_schedule=0;
    IF @FirstId IS NOT NULL EXEC [msdb].[dbo].[sp_delete_job] @job_id=@FirstId,@delete_unused_schedule=0;
    EXEC(@RestoreLockTimeout);
    THROW;
END CATCH;
IF @SecondId IS NOT NULL EXEC [msdb].[dbo].[sp_delete_job] @job_id=@SecondId,@delete_unused_schedule=0;
IF @FirstId IS NOT NULL EXEC [msdb].[dbo].[sp_delete_job] @job_id=@FirstId,@delete_unused_schedule=0;
EXEC(@RestoreLockTimeout);
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] IN(@FirstId,@SecondId))
    THROW 55975,N'Die eigenen Agent-Monitoring-Jobs wurden nicht entfernt.',1;
GO
