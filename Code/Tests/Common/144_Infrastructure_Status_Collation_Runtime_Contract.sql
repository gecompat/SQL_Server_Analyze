USE [DeineDatenbank];
GO
SET NOCOUNT ON;
/* Nur im neu erzeugten lokalen Testcontainer: zwei eigene Jobdefinitionen
   ohne Schritte, Schedules oder Start. Der Dienst wird nicht verändert.
   Native Dienstsicht kann leer sein; der Test behauptet dann keine positive
   Dienst- oder Jobzählerausgabe. Cleanup verwendet ausschließlich eigene IDs. */
DECLARE @Job1 sysname=N'ExampleInfrastructureJobÄ',@Job2 sysname=N'ExampleInfrastructureJobÜ',
        @Job1Id uniqueidentifier,@Job2Id uniqueidentifier,@Return int,
        @BaseJobs bigint=(SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs]),
        @BaseEnabled bigint=(SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WHERE [enabled]=1),
        @NativeRows bigint,@AgentJson nvarchar(max),@ParentJson nvarchar(max),@Names nvarchar(max)=QUOTENAME(DB_NAME()),
        @Case tinyint=0,@Agent bit,@Backup bit,@Max int,@ExpectedRows bigint,@ExpectedStatus varchar(40),@ExpectedPartial bit;
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(@Job1,@Job2))
   OR EXISTS(SELECT 1 FROM [msdb].[dbo].[backupset] WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS=DB_NAME() AND [type]='D' AND [is_copy_only]=0)
    THROW 55930,N'Die eigenen Jobnamen oder die erwartete leere Framework-Backuphistorie sind nicht frei.',1;
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
DECLARE @Children TABLE([Name] nvarchar(40) PRIMARY KEY,[Active] bit NOT NULL);
BEGIN TRY
    EXEC @Return=[msdb].[dbo].[sp_add_job] @job_name=@Job1,@enabled=0,@notify_level_eventlog=0,@job_id=@Job1Id OUTPUT;
    IF @Return<>0 OR @Job1Id IS NULL THROW 55930,N'Die erste eigene Jobdefinition wurde nicht erzeugt.',1;
    EXEC @Return=[msdb].[dbo].[sp_add_job] @job_name=@Job2,@enabled=1,@notify_level_eventlog=0,@job_id=@Job2Id OUTPUT;
    IF @Return<>0 OR @Job2Id IS NULL THROW 55930,N'Die zweite eigene Jobdefinition wurde nicht erzeugt.',1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs])<>@BaseJobs+2
       OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WHERE [enabled]=1)<>@BaseEnabled+1
       OR NOT EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job1Id AND [name]=@Job1 AND [enabled]=0)
       OR NOT EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job2Id AND [name]=@Job2 AND [enabled]=1)
        THROW 55930,N'Die zwei eigenen nativen Jobdefinitionen oder Zähler stimmen nicht.',1;
    SELECT TOP(1) [s].[servicename] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ServiceName],
      [s].[startup_type_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [StartupTypeDesc],
      [s].[status_desc] COLLATE SQL_Latin1_General_CP1_CS_AS AS [StatusDesc],[s].[process_id] AS [ProcessId],
      CONVERT(datetime2(3),(SELECT MAX([agent_start_date]) FROM [msdb].[dbo].[syssessions])) AS [LastStartupTime],
      (SELECT MAX([session_id]) FROM [msdb].[dbo].[syssessions]) AS [AgentSessionId],
      CONVERT(int,(SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs])) AS [JobCount],
      CONVERT(int,(SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WHERE [enabled]=1)) AS [EnabledJobCount]
    INTO [#ExampleInfrastructureNativeAgent] FROM [sys].[dm_server_services] AS [s]
    WHERE [s].[servicename] LIKE N'SQL Server Agent%' ORDER BY [s].[servicename];
    SET @NativeRows=(SELECT COUNT_BIG(*) FROM [#ExampleInfrastructureNativeAgent]);
    PRINT CONCAT(N'AGENT_NATIVE_ROWS: ',@NativeRows);
    CREATE TABLE [#ExampleInfrastructureAgent]([Dummy] int NULL);
    EXEC [monitor].[USP_AgentStatus] @ResultSetArt='TABLE',@ResultTablesJson=N'{"agentStatus":"#ExampleInfrastructureAgent"}',
      @JsonErzeugen=1,@Json=@AgentJson OUTPUT,@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleInfrastructureAgent') AND [collation_name] IS NOT NULL)<>3
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleInfrastructureAgent')
         AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55931,N'Der Agentstatusexport übernimmt eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@AgentJson),0)<>1 OR COALESCE(JSON_VALUE(@AgentJson,N'$.meta.statusCode'),'')<>CASE WHEN @NativeRows=0 THEN 'UNAVAILABLE_FEATURE' ELSE 'AVAILABLE' END
       OR COALESCE(JSON_VALUE(@AgentJson,N'$.meta.isPartial'),'')<>CASE WHEN @NativeRows=0 THEN 'true' ELSE 'false' END
       OR JSON_VALUE(@AgentJson,N'$.meta.errorNumber') IS NOT NULL
       OR (@NativeRows=0 AND COALESCE(JSON_VALUE(@AgentJson,N'$.meta.errorMessage'),N'')<>N'Kein sichtbarer SQL-Server-Agent-Dienst gefunden.')
       OR (@NativeRows=1 AND JSON_VALUE(@AgentJson,N'$.meta.errorMessage') IS NOT NULL)
       OR (SELECT COUNT_BIG(*) FROM [#ExampleInfrastructureAgent])<>@NativeRows
        THROW 55932,N'Der native Agentstatus- oder Leerfallvertrag ist verletzt.',1;
    INSERT @Parity VALUES
      (COALESCE((SELECT * FROM [#ExampleInfrastructureNativeAgent] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),COALESCE((SELECT * FROM [#ExampleInfrastructureAgent] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')),
      (COALESCE((SELECT * FROM [#ExampleInfrastructureAgent] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),JSON_QUERY(@AgentJson,N'$.agentStatus'));
    WHILE @Case<4
    BEGIN
        SELECT @Agent=CASE WHEN @Case IN(1,2) THEN 1 ELSE 0 END,@Backup=CASE WHEN @Case=2 THEN 1 ELSE 0 END,
          @Max=CASE WHEN @Case=3 THEN -1 WHEN @Case=2 THEN 1 ELSE 0 END,
          @ExpectedRows=CASE WHEN @Case=0 THEN 0 WHEN @Case=2 THEN 2 ELSE 1 END,
          @ExpectedStatus=CASE WHEN @Case=3 THEN 'AVAILABLE_LIMITED' WHEN @Case=2 THEN 'AVAILABLE_WITH_FINDING' ELSE 'AVAILABLE' END,
          @ExpectedPartial=CASE WHEN @Case=3 THEN 1 ELSE 0 END;
        CREATE TABLE [#ExampleInfrastructureModules]([Dummy] int NULL);
        CREATE TABLE [#ExampleInfrastructureExpectedModules]
        ([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        IF @Agent=1 INSERT [#ExampleInfrastructureExpectedModules] VALUES(N'USP_AgentStatus','EXECUTED',NULL,NULL);
        IF @Backup=1 INSERT [#ExampleInfrastructureExpectedModules] VALUES(N'USP_BackupChainAnalysis','AVAILABLE_WITH_FINDING',NULL,NULL);
        IF @Case=3 INSERT [#ExampleInfrastructureExpectedModules] VALUES(N'USP_InfrastructureAnalysis','INVALID_PARAMETER',NULL,N'Ungültige Scope-, Grenzwert- oder Ausgabeparameter.');
        EXEC [monitor].[USP_InfrastructureAnalysis] @MitAgent=@Agent,@MitAgentJobs=0,@MitResourceGovernor=0,@MitAvailabilityGroups=0,
          @MitBackupRecovery=0,@MitLogShipping=0,@MitReplication=0,@MitDataCapture=0,@MitBackupChain=@Backup,
          @MitAvailabilityDeep=0,@MitAgentMonitoring=0,@DatabaseNames=@Names,@MaxZeilen=@Max,@ResultSetArt='TABLE',
          @ResultTablesJson=N'{"moduleStatus":"#ExampleInfrastructureModules"}',@JsonErzeugen=1,@Json=@ParentJson OUTPUT,@PrintMeldungen=0;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleInfrastructureModules') AND [collation_name] IS NOT NULL)<>3
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleInfrastructureModules')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55933,N'Der Infrastruktur-Modulstatusexport übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@ParentJson),0)<>1 OR COALESCE(JSON_VALUE(@ParentJson,N'$.meta.statusCode'),'')<>@ExpectedStatus
           OR COALESCE(JSON_VALUE(@ParentJson,N'$.meta.isPartial'),'')<>CASE WHEN @ExpectedPartial=1 THEN 'true' ELSE 'false' END
           OR (SELECT COUNT_BIG(*) FROM [#ExampleInfrastructureModules])<>@ExpectedRows
            THROW 55934,N'Der Infrastruktur-Auswahl- oder Modulstatusvertrag ist verletzt.',1;
        DELETE @Children;
        INSERT @Children VALUES(N'agent',@Agent),(N'agentJobs',0),(N'resourceGovernor',0),(N'availabilityGroups',0),(N'backupRecovery',0),
          (N'logShipping',0),(N'replication',0),(N'dataCapture',0),(N'backupChain',@Backup),(N'availabilityDeep',0),(N'agentMonitoring',0);
        IF EXISTS(SELECT 1 FROM @Children AS [c] WHERE
          (SELECT COUNT_BIG(*) FROM OPENJSON(@ParentJson) AS [j] WHERE [j].[key] COLLATE SQL_Latin1_General_CP1_CS_AS=[c].[Name] COLLATE SQL_Latin1_General_CP1_CS_AS AND [j].[type]=CASE WHEN [c].[Active]=1 THEN 5 ELSE 0 END)<>1)
            THROW 55934,N'Die deaktivierten oder aktivierten Infrastruktur-Childobjekte stimmen nicht.',1;
        INSERT @Parity VALUES
          (COALESCE((SELECT * FROM [#ExampleInfrastructureExpectedModules] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),COALESCE((SELECT * FROM [#ExampleInfrastructureModules] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')),
          (COALESCE((SELECT * FROM [#ExampleInfrastructureExpectedModules] WHERE [StatusCode]='INVALID_PARAMETER' FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),JSON_QUERY(@ParentJson,N'$.warnings'));
        IF @Agent=1 BEGIN
          IF COALESCE(JSON_VALUE(@ParentJson,N'$.agent.meta.statusCode'),'')<>JSON_VALUE(@AgentJson,N'$.meta.statusCode')
             OR COALESCE(JSON_VALUE(@ParentJson,N'$.agent.meta.isPartial'),'')<>JSON_VALUE(@AgentJson,N'$.meta.isPartial')
             OR JSON_VALUE(@ParentJson,N'$.agent.meta.errorNumber') IS NOT NULL
             OR COALESCE(JSON_VALUE(@ParentJson,N'$.agent.meta.errorMessage'),N'')<>COALESCE(JSON_VALUE(@AgentJson,N'$.meta.errorMessage'),N'')
              THROW 55934,N'Der fachliche Agent-Childstatus wurde nicht erhalten.',1;
          INSERT @Parity VALUES(JSON_QUERY(@AgentJson,N'$.agentStatus'),JSON_QUERY(@ParentJson,N'$.agent.agentStatus'));
        END;
        IF @Backup=1 AND (COALESCE(JSON_VALUE(@ParentJson,N'$.backupChain.meta.statusCode'),'')<>'AVAILABLE_WITH_FINDING'
          OR COALESCE(JSON_VALUE(@ParentJson,N'$.backupChain.meta.isPartial'),'')<>'false'
          OR COALESCE(JSON_QUERY(@ParentJson,N'$.backupChain.backups'),N'')<>N'[]'
          OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ParentJson,N'$.backupChain.summary') WITH([DatabaseId] int N'$.DatabaseId',[FindingCode] varchar(100) N'$.FindingCode',
              [FindingSeverity] varchar(16) N'$.FindingSeverity',[LatestFullFinish] datetime N'$.LatestFullFinish')
            WHERE [DatabaseId]=DB_ID() AND [FindingCode]='FULL_BACKUP_EVIDENCE_MISSING' AND [FindingSeverity]='HIGH' AND [LatestFullFinish] IS NULL)<>1)
            THROW 55934,N'Der native Backupketten-Childscope oder seine fehlende Full-Evidenz stimmt nicht.',1;
        DROP TABLE [#ExampleInfrastructureModules]; DROP TABLE [#ExampleInfrastructureExpectedModules];
        SET @Case+=1;
    END;
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
        THROW 55935,N'Der native Agent- oder Infrastruktur-JSON-Multimengenvertrag ist verletzt.',1;
    DROP TABLE [#ExampleInfrastructureAgent]; DROP TABLE [#ExampleInfrastructureNativeAgent];
END TRY
BEGIN CATCH
    IF @Job2Id IS NOT NULL AND EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job2Id AND [name]=@Job2)
        EXEC [msdb].[dbo].[sp_delete_job] @job_id=@Job2Id;
    IF @Job1Id IS NOT NULL AND EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job1Id AND [name]=@Job1)
        EXEC [msdb].[dbo].[sp_delete_job] @job_id=@Job1Id;
    THROW;
END CATCH;
IF @Job2Id IS NOT NULL AND EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job2Id AND [name]=@Job2)
    EXEC [msdb].[dbo].[sp_delete_job] @job_id=@Job2Id;
IF @Job1Id IS NOT NULL AND EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Job1Id AND [name]=@Job1)
    EXEC [msdb].[dbo].[sp_delete_job] @job_id=@Job1Id;
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] IN(@Job1Id,@Job2Id))
   OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs])<>@BaseJobs
   OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WHERE [enabled]=1)<>@BaseEnabled
    THROW 55936,N'Die eigenen Jobdefinitionen wurden nicht entfernt.',1;
GO
