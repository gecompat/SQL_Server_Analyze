USE [DeineDatenbank];
GO
/*
===============================================================================
Objekt       : monitor.InternalRunSnapshotWaitStatsCycle
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure erfasst einen vollständigen nativen Waitcache mit gebundener
               Targetidentität und finalisiert ihn über das Wait-Backend.
Grenze       : Vorher-/Nachher-Enginekontext beweist keine atomare DMV-Sicht
               und keine ununterbrochene Resetkontinuität.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalRunSnapshotWaitStatsCycle]
      @SchedulerType varchar(16)
    , @RunEvenIfNotDue bit
    , @CaptureRunIdOut bigint OUTPUT
    , @TargetDatabaseNameOut sysname OUTPUT
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
AS
BEGIN
    SELECT @CaptureRunIdOut=NULL,@TargetDatabaseNameOut=NULL,@StatusCodeOut='AVAILABLE',
           @IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @RunEvenIfNotDue IS NULL
       OR @SchedulerType IS NULL OR @SchedulerType NOT IN('MANUAL','EXTERNAL','SQL_AGENT')
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Waitlauf benötigt gültige Steuerwerte ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET XACT_ABORT ON;
    DECLARE @TargetId int,@TargetCreated datetime,@CheckId int,@CheckCreated datetime,
            @TargetQuoted nvarchar(258),@SourceName sysname,@Enabled bit,
            @Sql nvarchar(max),@LockResult int,@LockHeld bit=0,@Unhandled bit=0,
            @Prepared bit=0,@CompletionReturned bit=0,@ProjectionFound bit=0,
            @AdmissionStatus varchar(40),@AdmissionError int,@AdmissionMessage nvarchar(2048),
            @PurgeId bigint,@PurgeStatus varchar(40),@PurgeBudget bit,@PurgeError int,@PurgeMessage nvarchar(2048),
            @PrepareStatus varchar(40),@PrepareMessage nvarchar(2048),@PolicyRun bigint,@PolicyCollect bit,
            @EngineName nvarchar(128),@EngineStart datetime,@EngineTicks bigint,
            @AfterName nvarchar(128),@AfterStart datetime,@AfterTicks bigint,
            @StartUtc datetime2(3),@EndUtc datetime2(3),@NativeRows bigint,
            @SourceStatus varchar(40),@SourcePartial bit,@SourceComplete bit,
            @SourceError int,@SourceMessage nvarchar(2048),@EngineJson nvarchar(max),@RowsJson nvarchar(max),@SourceJson nvarchar(max);
    DECLARE @WaitRows TABLE
    ([WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2 NOT NULL,
     [WaitingTasksCount] bigint NOT NULL,[WaitTimeMs] bigint NOT NULL,
     [MaxWaitTimeMs] bigint NOT NULL,[SignalWaitTimeMs] bigint NOT NULL);
    BEGIN TRY
        SELECT @TargetDatabaseNameOut=[TargetDatabaseName],@Enabled=[IsEnabled]
        FROM [monitor].[SnapshotTargetConfiguration] WHERE [ConfigurationId]=1;
        IF COALESCE(@Enabled,0)<>1
        BEGIN
            SELECT @StatusCodeOut='DISABLED',@IsPartialOut=1,@ErrorMessageOut=N'Das optionale Snapshotpaket ist nicht aktiviert.';
            GOTO WaitFinish;
        END;
        SELECT @SourceName=[name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID();
        IF @SourceName IS NULL THROW 53764,N'Der tatsächliche Frameworkkontext ist nicht sichtbar.',1;
        EXEC @LockResult=[sys].[sp_getapplock]
         @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0,@DbPrincipal=N'public';
        IF @LockResult<0
        BEGIN
            SELECT @StatusCodeOut='SKIPPED_CONCURRENT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Ein anderer Snapshotlauf oder Purge besitzt bereits die Paket-Applock.';
            GOTO WaitFinish;
        END;
        SET @LockHeld=1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@TargetDatabaseIdOut=@TargetId OUTPUT,@TargetCreateDateOut=@TargetCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO WaitFinish;
        END;
        SET @TargetQuoted=QUOTENAME(@TargetDatabaseNameOut);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,@CollectorCode=''WAIT_STATS'',@PolicyOnly=1,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Source sysname,@Scheduler varchar(16),@Force bit,@Run bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Source=@SourceName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,@Run=@PolicyRun OUTPUT,@Collect=@PolicyCollect OUTPUT,
 @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF @PolicyRun IS NOT NULL OR COALESCE(@PolicyCollect,0)<>0 THROW 53768,N'Die Policyprüfung bestätigt keinen schreibfreien Aufruf.',1;
        IF COALESCE(@PrepareStatus,'')<>'AVAILABLE'
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PrepareStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,@ErrorMessageOut=@PrepareMessage;
            GOTO WaitFinish;
        END;
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPurgeExpiredData]
 @MaxBatches=10,@Force=0,@PurgeRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,
 @BudgetExceededOut=@Budget OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Run bigint OUTPUT,@Status varchar(40) OUTPUT,@Budget bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Run=@PurgeId OUTPUT,@Status=@PurgeStatus OUTPUT,@Budget=@PurgeBudget OUTPUT,@Error=@PurgeError OUTPUT,@Message=@PurgeMessage OUTPUT,
 @Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF COALESCE(@PurgeStatus,'') NOT IN('AVAILABLE','AVAILABLE_LIMITED','SKIPPED_NOT_DUE') OR @PurgeError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PurgeStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,
                   @ErrorNumberOut=@PurgeError,@ErrorMessageOut=@PurgeMessage;
            GOTO WaitFinish;
        END;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO WaitFinish;
        END;
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=''WAIT_STATS'',@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Source sysname,@Scheduler varchar(16),@Force bit,@Run bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Source=@SourceName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,@Run=@CaptureRunIdOut OUTPUT,@Collect=@Prepared OUTPUT,
 @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF COALESCE(@Prepared,0)<>1
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PrepareStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,@ErrorMessageOut=@PrepareMessage;
            GOTO WaitFinish;
        END;
        IF @CaptureRunIdOut IS NULL OR @CaptureRunIdOut<=0 THROW 53763,N'Die Vorbereitung bestätigt keinen eigenen Wait-Run.',1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage,@Unhandled=1;
            GOTO WaitFinish;
        END;

        SELECT @SourceStatus='AVAILABLE',@SourcePartial=0,@SourceComplete=1,@SourceError=NULL,@SourceMessage=NULL,
               @StartUtc=SYSUTCDATETIME(),@EngineJson=NULL,@RowsJson=NULL,@NativeRows=NULL;
        BEGIN TRY
            SELECT @EngineName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @EngineStart=[sqlserver_start_time],@EngineTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR @EngineName IS NULL OR DATALENGTH(@EngineName)=0 OR @EngineStart IS NULL OR @EngineTicks IS NULL OR @EngineTicks<0
                THROW 53767,N'Der native Enginekontext vor dem Waitread ist nicht vollständig.',1;
            -- Exactly one complete native enumeration; MaxRows limits only backend writes.
            INSERT @WaitRows ([WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs])
            SELECT [wait_type],[waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms]
            FROM [sys].[dm_os_wait_stats] WITH (NOLOCK);
            SELECT @NativeRows=COUNT_BIG(*) FROM @WaitRows;
            SELECT @AfterName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @AfterStart=[sqlserver_start_time],@AfterTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR @AfterName IS NULL OR @AfterStart IS NULL OR @AfterTicks IS NULL
               OR CONVERT(varbinary(max),@AfterName)<>CONVERT(varbinary(max),@EngineName)
               OR @AfterStart<>@EngineStart OR @AfterTicks<>@EngineTicks
                THROW 53767,N'Der Enginekontext vor und nach dem vollständigen Waitread stimmt nicht überein.',1;
            SET @EndUtc=SYSUTCDATETIME();
            IF @EndUtc<@StartUtc THROW 53767,N'Das native UTC-Messfenster ist nicht geordnet.',1;
            SELECT @EngineJson=(SELECT @EngineName AS [serverName],
             CONVERT(nvarchar(19),@EngineStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EngineStart)),3) AS [sqlServerStartTimeLocal],
             CONVERT(varchar(20),@EngineTicks) AS [sqlServerStartTimeMsTicks]
             FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            SELECT @RowsJson=(SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
              FROM @WaitRows ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]) FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @RowsJson=COALESCE(@RowsJson,N'[]');
            IF @NativeRows=0 SELECT @SourceStatus='EMPTY_UNPROVEN',@SourcePartial=1;
        END TRY
        BEGIN CATCH
            SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                     WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                   @SourcePartial=1,@SourceComplete=0,@SourceError=ERROR_NUMBER(),
                   @SourceMessage=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@NativeRows=NULL,@RowsJson=N'[]',@EngineJson=NULL,
                   @EndUtc=SYSUTCDATETIME();
            IF @EndUtc<@StartUtc SELECT @StartUtc=NULL,@EndUtc=NULL;
        END CATCH;
        SELECT @SourceJson=(SELECT JSON_QUERY((SELECT 1 AS [schemaVersion],N'SnapshotWaitStats' AS [resultName],
          CASE WHEN @StartUtc IS NOT NULL THEN CONVERT(nvarchar(19),@StartUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@StartUtc)),3)+N'Z' END AS [measurementStartUtc],
          CASE WHEN @EndUtc IS NOT NULL THEN CONVERT(nvarchar(19),@EndUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EndUtc)),3)+N'Z' END AS [measurementEndUtc],
          @SourceStatus AS [statusCode],@SourcePartial AS [isPartial],@SourceError AS [errorNumber],@SourceMessage AS [errorMessage],
          CONVERT(varchar(20),@NativeRows) AS [nativeRows],@SourceComplete AS [sourceComplete],JSON_QUERY(@EngineJson) AS [engineContext]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [meta],JSON_QUERY(@RowsJson) AS [waits]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalCompleteWaitStatsCycle]
 @CaptureRunId=@Run,@CollectorJson=@Json,@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Run bigint,@Json nvarchar(max),@Id int,@Name sysname,@Created datetime,@Status varchar(40) OUTPUT,@Partial bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
 @Run=@CaptureRunIdOut,@Json=@SourceJson,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,
 @Status=@StatusCodeOut OUTPUT,@Partial=@IsPartialOut OUTPUT,@Error=@ErrorNumberOut OUTPUT,@Message=@ErrorMessageOut OUTPUT;
        SET @CompletionReturned=1;
        IF @@TRANCOUNT<>0 THROW 53768,N'Der Waitabschluss hat eine unerwartete Transaktion hinterlassen.',1;
        SET @Sql=N'USE '+@TargetQuoted+N';
IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
 WHERE [database_id]=@Id AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@Name) AND [create_date]=@Created AND [state]=0 AND [is_read_only]=0)
 THROW 53764,N''Die Targetidentität vor der Ergebnisprojektion hat sich geändert.'',1;
INSERT [#RunSnapshotCollectionCycle_Run]
([CaptureRunId],[TargetDatabaseName],[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
SELECT [CaptureRunId],@Name,[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage]
FROM [snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),''WAIT_STATS'')
 AND CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@Source);
SET @Found=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
SELECT [ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run;';
        EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Run bigint,@Source sysname,@Found bit OUTPUT',
 @Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,@Run=@CaptureRunIdOut,@Source=@SourceName,@Found=@ProjectionFound OUTPUT;
        IF @ProjectionFound<>1 THROW 53763,N'Die Projektion bestätigt keinen passenden eigenen Wait-Run.',1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                  WHEN ERROR_NUMBER() IN(53760,53761,53762,53764,208,2812,8144,8145) THEN 'TARGET_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Unhandled=1;
    END CATCH;
WaitFinish:
    IF @LockHeld=1
    BEGIN TRY
        EXEC @LockResult=[sys].[sp_releaseapplock] @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockOwner='Session',@DbPrincipal=N'public';
        IF @LockResult<0 THROW 53768,N'Die Freigabe der eigenen Paket-Applock ist nicht bestätigt.',1;
        SET @LockHeld=0;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Unhandled=1;
    END CATCH;
    IF @Unhandled=1 OR (@Prepared=1 AND @StatusCodeOut='TARGET_UNAVAILABLE')
    BEGIN TRY
        DECLARE @Limit nvarchar(1000)=CASE WHEN @CompletionReturned=1
          THEN N'Der Backendaufruf ist beendet; eine gespeicherte Aufnahme bleibt erhalten. Ergebnisprojektion und Abschlussdetails sind hier nicht vollständig bestätigt.'
          ELSE N'Ein eröffneter Lauf kann unvollständig sein. Es wird kein Legacy-Abschluss und keine erfundene Nullprojektion geschrieben.' END;
        SET @Limit=CONCAT(@Limit,N' Gebundenes Target: ',QUOTENAME(@TargetDatabaseNameOut),N'.');
        SET @Sql=N'INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
VALUES(NULL,@Run,N''monitor.InternalRunSnapshotWaitStatsCycle'',SYSUTCDATETIME(),@Status,1,@Error,@Message,@Limit);';
        EXEC [sys].[sp_executesql] @Sql,N'@Run bigint,@Status varchar(40),@Error int,@Message nvarchar(2048),@Limit nvarchar(1000)',
 @Run=@CaptureRunIdOut,@Status=@StatusCodeOut,@Error=@ErrorNumberOut,@Message=@ErrorMessageOut,@Limit=@Limit;
    END TRY
    BEGIN CATCH
        -- Preserve the authoritative failure outputs if the caller result table is unavailable.
    END CATCH;
END;
GO
