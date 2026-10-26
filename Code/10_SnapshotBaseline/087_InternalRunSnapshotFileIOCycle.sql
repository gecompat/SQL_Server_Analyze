USE [DeineDatenbank];
GO
/*
===============================================================================
Objekt       : monitor.InternalRunSnapshotFileIOCycle
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Die Procedure erfasst einen vollständigen nativen Datei-I/O-Cache mit gebundener
               Targetidentität und finalisiert ihn über das Datei-I/O-Backend.
Grenze       : Vorher-/Nachher-Enginekontext beweist keine atomare DMV-Sicht
               und keine ununterbrochene Resetkontinuität.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalRunSnapshotFileIOCycle]
      @SchedulerType varchar(16)
    , @RunEvenIfNotDue bit
    , @CaptureRunIdOut bigint OUTPUT
    , @TargetDatabaseNameOut sysname OUTPUT
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
    , @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
AS
BEGIN
    SELECT @CaptureRunIdOut=NULL,@TargetDatabaseNameOut=NULL,@StatusCodeOut='AVAILABLE',
           @IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @RunEvenIfNotDue IS NULL
       OR @SchedulerType IS NULL OR @SchedulerType NOT IN('MANUAL','EXTERNAL','SQL_AGENT')
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Datei-I/O-Lauf benötigt gültige Steuerwerte ohne Callertransaktion oder implizite Transaktionen.';
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
    DECLARE @NativeState varchar(16)='NOT_STARTED',@ReadStart datetime2(3),@ReadEnd datetime2(3),
            @RunStarted datetime2(3),@FrameworkCreated datetime,@SelectionJson nvarchar(max),@DatabasesJson nvarchar(max),
            @IssuesJson nvarchar(max),@CandidateStatus varchar(40),@CandidateMessage nvarchar(2048),@CrossDatabase bit;
    CREATE TABLE [#InternalRunSnapshotFileIOCycle_Candidates]
    ([DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL);
    CREATE TABLE [#InternalRunSnapshotFileIOCycle_Warnings]
    ([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#InternalRunSnapshotFileIOCycle_Databases]
    ([DatabaseId] int PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Created] datetime NOT NULL,
     [MetadataStatusCode] varchar(40) NOT NULL DEFAULT('ERROR_HANDLED'),[BeforeRead] bit NOT NULL DEFAULT(0),[AfterRead] bit NOT NULL DEFAULT(0));
    CREATE TABLE [#InternalRunSnapshotFileIOCycle_Metadata]
    ([Phase] tinyint NOT NULL,[DatabaseId] int NOT NULL,[FileId] int NOT NULL,[FileGuid] uniqueidentifier NULL,
     [CreateLsn] numeric(25,0) NULL,[FileType] tinyint NOT NULL,[FileState] tinyint NOT NULL,
     [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,PRIMARY KEY([Phase],[DatabaseId],[FileId]));
    DECLARE @NativeFiles TABLE
    ([DatabaseId] int NOT NULL,[FileId] int NOT NULL,[SampleMs] bigint NOT NULL,[Reads] bigint NOT NULL,[ReadBytes] bigint NOT NULL,
     [ReadStallMs] bigint NOT NULL,[Writes] bigint NOT NULL,[WriteBytes] bigint NOT NULL,[WriteStallMs] bigint NOT NULL,
     [SizeOnDiskBytes] bigint NOT NULL,[FileHandle] varbinary(8) NULL,PRIMARY KEY([DatabaseId],[FileId]));
    DECLARE @Issues TABLE
    ([Ordinal] int IDENTITY PRIMARY KEY,[ScopeType] varchar(16) NOT NULL,[SourceName] sysname NOT NULL,[DatabaseId] int NULL,
     [FileId] int NULL,[DatabaseName] nvarchar(128) NULL,[StatusCode] varchar(40) NOT NULL,[ErrorNumber] int NULL,
     [ErrorMessage] nvarchar(2048) NULL,[EvidenceLimit] nvarchar(1000) NULL);
    BEGIN TRY
        SELECT @TargetDatabaseNameOut=[TargetDatabaseName],@Enabled=[IsEnabled]
        FROM [monitor].[SnapshotTargetConfiguration] WHERE [ConfigurationId]=1;
        IF COALESCE(@Enabled,0)<>1
        BEGIN
            SELECT @StatusCodeOut='DISABLED',@IsPartialOut=1,@ErrorMessageOut=N'Das optionale Snapshotpaket ist nicht aktiviert.';
            GOTO FileIOFinish;
        END;
        SELECT @SourceName=[name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID();
        IF @SourceName IS NULL THROW 53764,N'Der tatsächliche Frameworkkontext ist nicht sichtbar.',1;
        EXEC @LockResult=[sys].[sp_getapplock]
         @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0,@DbPrincipal=N'public';
        IF @LockResult<0
        BEGIN
            SELECT @StatusCodeOut='SKIPPED_CONCURRENT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Ein anderer Snapshotlauf oder Purge besitzt bereits die Paket-Applock.';
            GOTO FileIOFinish;
        END;
        SET @LockHeld=1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@TargetDatabaseIdOut=@TargetId OUTPUT,@TargetCreateDateOut=@TargetCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT,@CollectorCode='FILE_IO';
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO FileIOFinish;
        END;
        SET @TargetQuoted=QUOTENAME(@TargetDatabaseNameOut);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,@CollectorCode=''FILE_IO'',@PolicyOnly=1,
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
            GOTO FileIOFinish;
        END;
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
         @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,
         @AnalysisClass='STANDARD_CURRENT',@HighImpactConfirmed=0,@StatusCode=@CandidateStatus OUTPUT,
         @ErrorMessage=@CandidateMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabase OUTPUT,
         @CandidateTable=N'#InternalRunSnapshotFileIOCycle_Candidates',@WarningTable=N'#InternalRunSnapshotFileIOCycle_Warnings';
        IF COALESCE(@CandidateStatus,'')<>'AVAILABLE'
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@CandidateStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,
              @ErrorNumberOut=CASE WHEN @CandidateStatus='INVALID_PARAMETER' THEN 51011 END,@ErrorMessageOut=@CandidateMessage;
            GOTO FileIOFinish;
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
            GOTO FileIOFinish;
        END;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT,@CollectorCode='FILE_IO';
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO FileIOFinish;
        END;
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=''FILE_IO'',@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Source sysname,@Scheduler varchar(16),@Force bit,@Run bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Source=@SourceName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,@Run=@CaptureRunIdOut OUTPUT,@Collect=@Prepared OUTPUT,
 @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF COALESCE(@Prepared,0)<>1
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PrepareStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,@ErrorMessageOut=@PrepareMessage;
            GOTO FileIOFinish;
        END;
        IF @CaptureRunIdOut IS NULL OR @CaptureRunIdOut<=0 THROW 53763,N'Die Vorbereitung bestätigt keinen eigenen Datei-I/O-Run.',1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT,@CollectorCode='FILE_IO';
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage,@Unhandled=1;
            GOTO FileIOFinish;
        END;

        SELECT @SourceStatus='AVAILABLE',@SourcePartial=0,@SourceComplete=1,@SourceError=NULL,@SourceMessage=NULL,
               @StartUtc=SYSUTCDATETIME(),@EngineJson=NULL,@RowsJson=N'[]',@NativeRows=NULL;
        INSERT [#InternalRunSnapshotFileIOCycle_Databases]([DatabaseId],[DatabaseName],[Created])
        SELECT [d].[database_id],[d].[name],[d].[create_date]
        FROM [#InternalRunSnapshotFileIOCycle_Candidates] [c] JOIN [master].[sys].[databases] [d] WITH (NOLOCK)
          ON [d].[database_id]=[c].[DatabaseId] AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),[c].[DatabaseName])
        WHERE [d].[state]=0;
        INSERT @Issues([ScopeType],[SourceName],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
        SELECT 'SELECTION',N'DATABASE_SELECTION',[RequestedName],'SELECTION_UNRESOLVED',[ErrorMessage],
          N'Die angeforderte Datenbank wurde nicht als aktueller Onlinekandidat bestätigt.' FROM [#InternalRunSnapshotFileIOCycle_Warnings];
        INSERT @Issues([ScopeType],[SourceName],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
        SELECT 'SELECTION',N'DATABASE_SELECTION',[c].[DatabaseName],'SELECTION_UNRESOLVED',
          N'Der zuvor sichtbare Kandidat stimmt nicht mehr mit einer aktuellen Online-Datenbank überein.',
          N'Der Kandidat wird nicht durch eine anders benannte oder neu angelegte Datenbank ersetzt.'
        FROM [#InternalRunSnapshotFileIOCycle_Candidates] [c] WHERE NOT EXISTS
          (SELECT 1 FROM [#InternalRunSnapshotFileIOCycle_Databases] [d] WHERE [d].[DatabaseId]=[c].[DatabaseId]);
        IF NOT EXISTS(SELECT 1 FROM [#InternalRunSnapshotFileIOCycle_Databases]) SET @NativeRows=0;
        DECLARE @FaultSource sysname=N'sys.dm_os_sys_info',@Phase tinyint=1,@DbId int,@DbName sysname,@DbCreated datetime,
                @MetadataStatus varchar(40),@MetadataError int,@MetadataMessage nvarchar(2048),@CanonicalDatabases nvarchar(max);
        BEGIN TRY
            SELECT @FrameworkCreated=[create_date] FROM [master].[sys].[databases] WITH (NOLOCK)
              WHERE [database_id]=DB_ID() AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@SourceName);
            IF @FrameworkCreated IS NULL THROW 53787,N'Die tatsächliche Frameworkidentität ist nicht vollständig sichtbar.',1;
            SET @Sql=N'SELECT @Started=[StartedAtUtc] FROM '+@TargetQuoted+N'.[snapshot].[CaptureRun]
 WHERE [CaptureRunId]=@Run AND [CollectorCode]=''FILE_IO'' AND [StatusCode]=''RUNNING'' AND [EndedAtUtc] IS NULL
 AND CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@Source);';
            EXEC [sys].[sp_executesql] @Sql,N'@Started datetime2(3) OUTPUT,@Run bigint,@Source sysname',@RunStarted OUTPUT,@CaptureRunIdOut,@SourceName;
            IF @RunStarted IS NULL THROW 53787,N'Der tatsächliche Datei-I/O-Runstart ist nicht bestätigt.',1;
            SELECT @EngineName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @EngineStart=[sqlserver_start_time],@EngineTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR NULLIF(@EngineName,N'') IS NULL OR @EngineStart IS NULL OR @EngineTicks IS NULL OR @EngineTicks<0
                THROW 53787,N'Der Enginekontext vor dem Datei-I/O-Read ist nicht vollständig.',1;
            WHILE @Phase<=2
            BEGIN
                DECLARE [FileIODatabases] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseId],[DatabaseName],[Created] FROM [#InternalRunSnapshotFileIOCycle_Databases] ORDER BY [DatabaseId];
                OPEN [FileIODatabases];
                FETCH NEXT FROM [FileIODatabases] INTO @DbId,@DbName,@DbCreated;
                WHILE @@FETCH_STATUS=0
                BEGIN
                    BEGIN TRY
                        SET @Sql=N'USE '+QUOTENAME(@DbName)+N';
IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
 WHERE [database_id]=@Id AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@Name)
 AND [create_date]=@Created AND [state]=0)
 THROW 53786,N''Die ausgewählte Datenbankidentität hat sich während des Metadatenreads geändert.'',1;
INSERT [#InternalRunSnapshotFileIOCycle_Metadata]([Phase],[DatabaseId],[FileId],[FileGuid],[CreateLsn],[FileType],[FileState],[LogicalName])
SELECT @Phase,@Id,[file_id],[file_guid],[create_lsn],[type],[state],[name] FROM [sys].[database_files] WITH (NOLOCK);
IF @@ROWCOUNT=0 THROW 53787,N''Der Metadatenread bestätigt keine sichtbare Datei.'',1;';
                        EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Phase tinyint',@DbId,@DbName,@DbCreated,@Phase;
                        UPDATE [#InternalRunSnapshotFileIOCycle_Databases]
                        SET [BeforeRead]=CASE WHEN @Phase=1 THEN 1 ELSE [BeforeRead] END,
                            [AfterRead]=CASE WHEN @Phase=2 THEN 1 ELSE [AfterRead] END,
                            [MetadataStatusCode]=CASE WHEN @Phase=2 AND [BeforeRead]=1 THEN 'AVAILABLE' ELSE [MetadataStatusCode] END
                        WHERE [DatabaseId]=@DbId;
                    END TRY
                    BEGIN CATCH
                        SELECT @MetadataStatus=CASE WHEN ERROR_NUMBER()=53786 THEN 'TARGET_CHANGED'
                          WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER() IN(207,208,911) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                          @MetadataError=CASE WHEN ERROR_NUMBER() NOT IN(53786,53787) THEN ERROR_NUMBER() END,
                          @MetadataMessage=CONVERT(nvarchar(2048),ERROR_MESSAGE());
                        DELETE [#InternalRunSnapshotFileIOCycle_Metadata] WHERE [DatabaseId]=@DbId AND [Phase]=@Phase;
                        UPDATE [#InternalRunSnapshotFileIOCycle_Databases] SET [MetadataStatusCode]=@MetadataStatus WHERE [DatabaseId]=@DbId;
                        INSERT @Issues([ScopeType],[SourceName],[DatabaseId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES('DATABASE',CASE WHEN @MetadataStatus='TARGET_CHANGED' THEN N'sys.databases' ELSE N'sys.database_files' END,
                          @DbId,@DbName,CASE WHEN @MetadataStatus='TARGET_CHANGED' THEN 'DATABASE_CONTEXT_CHANGED' ELSE @MetadataStatus END,
                          @MetadataError,@MetadataMessage,N'Vorher-/Nachher-Katalogreads ersetzen keine atomare Sicht auf Datenbank und native Datei.');
                    END CATCH;
                    FETCH NEXT FROM [FileIODatabases] INTO @DbId,@DbName,@DbCreated;
                END;
                CLOSE [FileIODatabases]; DEALLOCATE [FileIODatabases];
                IF @Phase=1 AND EXISTS(SELECT 1 FROM [#InternalRunSnapshotFileIOCycle_Databases])
                BEGIN
                    SET @FaultSource=N'sys.dm_io_virtual_file_stats';
                    BEGIN TRY
                        SET @ReadStart=SYSUTCDATETIME();
                        -- One complete native cache. Selection and MaxRows are applied only afterwards.
                        INSERT @NativeFiles([DatabaseId],[FileId],[SampleMs],[Reads],[ReadBytes],[ReadStallMs],[Writes],[WriteBytes],[WriteStallMs],[SizeOnDiskBytes],[FileHandle])
                        SELECT [database_id],[file_id],[sample_ms],[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],
                          [num_of_writes],[num_of_bytes_written],[io_stall_write_ms],[size_on_disk_bytes],[file_handle]
                        FROM [sys].[dm_io_virtual_file_stats](NULL,NULL);
                    END TRY
                    BEGIN CATCH
                        SELECT @NativeState='FAILED',@NativeRows=NULL,@ReadStart=NULL,@ReadEnd=NULL;
                        THROW;
                    END CATCH;
                    SET @NativeState='SUCCEEDED';
                    SELECT @NativeRows=COUNT_BIG(*) FROM @NativeFiles [f] JOIN [#InternalRunSnapshotFileIOCycle_Databases] [d] ON [d].[DatabaseId]=[f].[DatabaseId];
                    SET @ReadEnd=SYSUTCDATETIME();
                END;
                SET @Phase+=1;
            END;
            SET @FaultSource=N'sys.dm_os_sys_info';
            SELECT @AfterName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @AfterStart=[sqlserver_start_time],@AfterTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR @AfterName IS NULL OR @AfterStart IS NULL OR @AfterTicks IS NULL
               OR CONVERT(varbinary(max),@AfterName)<>CONVERT(varbinary(max),@EngineName)
               OR @AfterStart<>@EngineStart OR @AfterTicks<>@EngineTicks
                THROW 53787,N'Der Enginekontext vor und nach dem vollständigen Datei-I/O-Read stimmt nicht überein.',1;
            SET @EndUtc=SYSUTCDATETIME();
            IF @StartUtc<@RunStarted OR @EndUtc<@StartUtc OR @ReadStart<@StartUtc OR @ReadEnd<@ReadStart OR @ReadEnd>@EndUtc
                THROW 53787,N'Die tatsächlichen UTC-Beobachtungen bestätigen keine geordnete Bindung an den Runstart.',1;
            SET @FaultSource=N'sys.dm_io_virtual_file_stats';
            IF EXISTS(SELECT 1 FROM @NativeFiles WHERE [SampleMs]<0 OR [Reads]<0 OR [ReadBytes]<0 OR [ReadStallMs]<0
               OR [Writes]<0 OR [WriteBytes]<0 OR [WriteStallMs]<0 OR [SizeOnDiskBytes]<0)
                THROW 53787,N'Der native Dateicache enthält einen ungültigen negativen Messwert.',1;
            DECLARE @Assessment TABLE([DatabaseId] int,[FileId] int,[IssueStatus] varchar(40),[BeforeJson] nvarchar(max),[AfterJson] nvarchar(max));
            INSERT @Assessment
            SELECT [f].[DatabaseId],[f].[FileId],
              CASE WHEN [d].[MetadataStatusCode]<>'AVAILABLE' OR [b].[FileId] IS NULL OR [a].[FileId] IS NULL THEN 'FILE_METADATA_UNAVAILABLE'
                WHEN [b].[FileType]<>[a].[FileType] THEN 'FILE_TYPE_CHANGED'
                WHEN [b].[FileState]<>[a].[FileState] THEN 'FILE_STATE_CHANGED'
                WHEN [b].[FileType] NOT IN(0,1) THEN 'UNSUPPORTED_FILE_TYPE'
                WHEN [b].[FileState]<>0 THEN 'FILE_NOT_ONLINE'
                WHEN [f].[FileHandle] IS NULL OR [b].[FileGuid] IS NULL OR [a].[FileGuid] IS NULL OR [b].[CreateLsn] IS NULL OR [a].[CreateLsn] IS NULL THEN 'IDENTITY_FIELD_UNKNOWN'
                WHEN [b].[FileGuid]<>[a].[FileGuid] OR [b].[CreateLsn]<>[a].[CreateLsn] THEN 'IDENTITY_OBSERVATION_CHANGED' END,
              CASE WHEN [b].[FileId] IS NOT NULL THEN (SELECT [b].[DatabaseId],[b].[FileId],LOWER(CONVERT(varchar(36),[b].[FileGuid])) AS [FileGuid],
                CONVERT(varchar(25),[b].[CreateLsn]) AS [CreateLsn],[b].[FileType],[b].[FileState],[b].[LogicalName]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) END,
              CASE WHEN [a].[FileId] IS NOT NULL THEN (SELECT [a].[DatabaseId],[a].[FileId],LOWER(CONVERT(varchar(36),[a].[FileGuid])) AS [FileGuid],
                CONVERT(varchar(25),[a].[CreateLsn]) AS [CreateLsn],[a].[FileType],[a].[FileState],[a].[LogicalName]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) END
            FROM @NativeFiles [f] JOIN [#InternalRunSnapshotFileIOCycle_Databases] [d] ON [d].[DatabaseId]=[f].[DatabaseId]
            LEFT JOIN [#InternalRunSnapshotFileIOCycle_Metadata] [b] ON [b].[Phase]=1 AND [b].[DatabaseId]=[f].[DatabaseId] AND [b].[FileId]=[f].[FileId]
            LEFT JOIN [#InternalRunSnapshotFileIOCycle_Metadata] [a] ON [a].[Phase]=2 AND [a].[DatabaseId]=[f].[DatabaseId] AND [a].[FileId]=[f].[FileId];
            INSERT @Issues([ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
            SELECT 'FILE',N'sys.database_files',[a].[DatabaseId],[a].[FileId],[d].[DatabaseName],[a].[IssueStatus],
              CASE [a].[IssueStatus]
                WHEN 'FILE_METADATA_UNAVAILABLE' THEN N'Die native Datei besitzt keine zwei bestätigten stabilen Katalogbindungen.'
                WHEN 'FILE_TYPE_CHANGED' THEN N'Der beobachtete Dateityp hat sich geändert.'
                WHEN 'FILE_STATE_CHANGED' THEN N'Der beobachtete Dateistatus hat sich geändert.'
                WHEN 'UNSUPPORTED_FILE_TYPE' THEN N'Der Dateityp gehört nicht zum abgegrenzten ROWS-/LOG-Scope.'
                WHEN 'FILE_NOT_ONLINE' THEN N'Die Datei ist nicht als ONLINE beobachtet.'
                WHEN 'IDENTITY_FIELD_UNKNOWN' THEN N'Mindestens ein erforderliches Identitätsfeld ist nicht beobachtet.'
                ELSE N'Die vorher/nachher beobachtete Dateiidentität hat sich geändert.' END,
              N'Der Katalog ist keine atomare Identitätsbestätigung des nativen VFS-Reads; monotone Werte beweisen keine Resetkontinuität.'
            FROM @Assessment [a] JOIN [#InternalRunSnapshotFileIOCycle_Databases] [d] ON [d].[DatabaseId]=[a].[DatabaseId] WHERE [a].[IssueStatus] IS NOT NULL;
            INSERT @Issues([ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
            SELECT 'FILE',N'sys.dm_io_virtual_file_stats',[m].[DatabaseId],[m].[FileId],[d].[DatabaseName],'NATIVE_FILE_UNAVAILABLE',
              N'Eine im Katalog beobachtete Online-ROWS-/LOG-Datei fehlt im vollständigen nativen Cache.',
              N'Für diese fehlende Beobachtung wird kein Nullsample erzeugt.'
            FROM (SELECT DISTINCT [DatabaseId],[FileId] FROM [#InternalRunSnapshotFileIOCycle_Metadata] WHERE [FileType] IN(0,1) AND [FileState]=0) [m]
            JOIN [#InternalRunSnapshotFileIOCycle_Databases] [d] ON [d].[DatabaseId]=[m].[DatabaseId]
            WHERE NOT EXISTS(SELECT 1 FROM @NativeFiles [f] WHERE [f].[DatabaseId]=[m].[DatabaseId] AND [f].[FileId]=[m].[FileId]);
            INSERT @Issues([ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
            SELECT 'FILE',N'sys.database_files',[b].[DatabaseId],[b].[FileId],[d].[DatabaseName],
              CASE WHEN [b].[FileType] NOT IN(0,1) THEN 'UNSUPPORTED_FILE_TYPE' ELSE 'FILE_NOT_ONLINE' END,
              N'Die stabile Katalogdatei liegt außerhalb des Online-ROWS-/LOG-Scope und besitzt keine native Zeile.',
              N'Der Ausschluss wird ausdrücklich erhalten; ein nicht beobachteter nativer Wert wird nicht als Nullsample ergänzt.'
            FROM [#InternalRunSnapshotFileIOCycle_Metadata] [b] JOIN [#InternalRunSnapshotFileIOCycle_Metadata] [a]
              ON [a].[Phase]=2 AND [a].[DatabaseId]=[b].[DatabaseId] AND [a].[FileId]=[b].[FileId]
              AND [a].[FileType]=[b].[FileType] AND [a].[FileState]=[b].[FileState]
            JOIN [#InternalRunSnapshotFileIOCycle_Databases] [d] ON [d].[DatabaseId]=[b].[DatabaseId]
            WHERE [b].[Phase]=1 AND ([b].[FileType] NOT IN(0,1) OR [b].[FileState]<>0)
              AND NOT EXISTS(SELECT 1 FROM @NativeFiles [f] WHERE [f].[DatabaseId]=[b].[DatabaseId] AND [f].[FileId]=[b].[FileId]);
            SELECT @EngineJson=(SELECT @EngineName AS [serverName],
             CONVERT(nvarchar(19),@EngineStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@EngineStart)),3) AS [sqlServerStartTimeLocal],
             CONVERT(varchar(20),@EngineTicks) AS [sqlServerStartTimeMsTicks]
             FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            SELECT @RowsJson=COALESCE((SELECT [f].[DatabaseId],[f].[FileId],[f].[SampleMs],[f].[Reads],[f].[ReadBytes],[f].[ReadStallMs],
              [f].[Writes],[f].[WriteBytes],[f].[WriteStallMs],[f].[SizeOnDiskBytes],LOWER(CONVERT(varchar(18),[f].[FileHandle],1)) AS [FileHandle],
              JSON_QUERY([a].[BeforeJson]) AS [MetadataBefore],JSON_QUERY([a].[AfterJson]) AS [MetadataAfter]
              FROM @NativeFiles [f] JOIN @Assessment [a] ON [a].[DatabaseId]=[f].[DatabaseId] AND [a].[FileId]=[f].[FileId]
              ORDER BY [f].[DatabaseId],[f].[FileId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
            IF EXISTS(SELECT 1 FROM @Issues WHERE [StatusCode] NOT IN('UNSUPPORTED_FILE_TYPE','FILE_NOT_ONLINE','IDENTITY_OBSERVATION_CHANGED','IDENTITY_FIELD_UNKNOWN'))
              OR EXISTS(SELECT 1 FROM [#InternalRunSnapshotFileIOCycle_Databases] WHERE [MetadataStatusCode]<>'AVAILABLE')
                SELECT @SourceStatus='PARTIAL',@SourcePartial=1,@SourceComplete=0;
            ELSE IF NOT EXISTS(SELECT 1 FROM @Assessment WHERE [IssueStatus] IS NULL OR [IssueStatus] IN('IDENTITY_FIELD_UNKNOWN','IDENTITY_OBSERVATION_CHANGED'))
                SELECT @SourceStatus='EMPTY_UNPROVEN',@SourcePartial=1;
        END TRY
        BEGIN CATCH
            SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                                     WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                   @SourcePartial=1,@SourceComplete=0,@EngineJson=NULL,@RowsJson=N'[]',@EndUtc=SYSUTCDATETIME();
            INSERT @Issues([ScopeType],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            VALUES('SOURCE',@FaultSource,@SourceStatus,CASE WHEN ERROR_NUMBER()<>53787 THEN ERROR_NUMBER() END,
              CONVERT(nvarchar(2048),ERROR_MESSAGE()),N'Der native Readzustand und seine tatsächliche Menge bleiben unabhängig von einer später fehlenden Messbindung erhalten.');
            INSERT @Issues([ScopeType],[SourceName],[DatabaseId],[DatabaseName],[StatusCode],[ErrorMessage],[EvidenceLimit])
            SELECT 'DATABASE',N'sys.database_files',[DatabaseId],[DatabaseName],'ERROR_HANDLED',
              N'Nicht alle erforderlichen Katalogreads wurden nach dem fatalen Sourceabbruch ausgeführt.',
              N'Dafür wird keine native Fehlernummer behauptet.'
            FROM [#InternalRunSnapshotFileIOCycle_Databases] WHERE [BeforeRead]=0 OR [AfterRead]=0;
            IF @EndUtc<@StartUtc OR @StartUtc<@RunStarted SELECT @StartUtc=NULL,@EndUtc=NULL;
            IF @ReadStart>@ReadEnd OR @ReadStart<@StartUtc OR @ReadEnd>@EndUtc OR @StartUtc IS NULL
                SELECT @ReadStart=NULL,@ReadEnd=NULL;
        END CATCH;
        SELECT TOP(1) @SourceError=[ErrorNumber],@SourceMessage=[ErrorMessage] FROM @Issues
          ORDER BY CASE WHEN [ErrorNumber] IS NULL THEN 1 ELSE 0 END,[Ordinal];
        SELECT @CanonicalDatabases=COALESCE((SELECT [DatabaseId],[DatabaseName],
          CONVERT(nvarchar(19),[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[Created])),3) AS [DatabaseCreateDateNative]
          FROM [#InternalRunSnapshotFileIOCycle_Databases] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
        SELECT @SelectionJson=(SELECT @DatabaseNames AS [requestedDatabaseNames],@DatabaseNamePattern AS [requestedDatabaseNamePattern],
          @SystemdatenbankenEinbeziehen AS [systemDatabasesIncluded],CONVERT(varchar(20),(SELECT COUNT_BIG(*) FROM [#InternalRunSnapshotFileIOCycle_Databases])) AS [selectedDatabaseCount],
          LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CanonicalDatabases)),2)) AS [selectionSha256]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SELECT @DatabasesJson=COALESCE((SELECT [DatabaseId],[DatabaseName],
          CONVERT(nvarchar(19),[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[Created])),3) AS [DatabaseCreateDateNative],[MetadataStatusCode]
          FROM [#InternalRunSnapshotFileIOCycle_Databases] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
        SELECT @IssuesJson=COALESCE((SELECT [ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
          FROM @Issues ORDER BY [Ordinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
        SELECT @SourceJson=(SELECT JSON_QUERY((SELECT 1 AS [schemaVersion],N'SnapshotFileIO' AS [resultName],
          @SourceStatus AS [statusCode],@NativeState AS [nativeReadState],@SourcePartial AS [isPartial],@SourceComplete AS [sourceComplete],
          @SourceError AS [errorNumber],@SourceMessage AS [errorMessage],
          CASE WHEN @StartUtc IS NOT NULL THEN CONVERT(nvarchar(19),@StartUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@StartUtc)),3)+N'Z' END AS [measurementStartUtc],
          CASE WHEN @EndUtc IS NOT NULL THEN CONVERT(nvarchar(19),@EndUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@EndUtc)),3)+N'Z' END AS [measurementEndUtc],
          CASE WHEN @ReadStart IS NOT NULL THEN CONVERT(nvarchar(19),@ReadStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@ReadStart)),3)+N'Z' END AS [nativeReadStartUtc],
          CASE WHEN @ReadEnd IS NOT NULL THEN CONVERT(nvarchar(19),@ReadEnd,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@ReadEnd)),3)+N'Z' END AS [nativeReadEndUtc],
          CONVERT(varchar(20),@NativeRows) AS [selectedNativeRows],
          JSON_QUERY((SELECT DB_ID() AS [databaseId],@SourceName AS [databaseName],
            CONVERT(nvarchar(19),@FrameworkCreated,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@FrameworkCreated)),3) AS [databaseCreateDateNative]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [framework],JSON_QUERY(@EngineJson) AS [engine],JSON_QUERY(@SelectionJson) AS [selection]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [meta],JSON_QUERY(@DatabasesJson) AS [databases],
          JSON_QUERY(@RowsJson) AS [files],JSON_QUERY(@IssuesJson) AS [issues]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalCompleteFileIOCycle]
 @CaptureRunId=@Run,@CollectorJson=@Json,@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Run bigint,@Json nvarchar(max),@Id int,@Name sysname,@Created datetime,@Status varchar(40) OUTPUT,@Partial bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
 @Run=@CaptureRunIdOut,@Json=@SourceJson,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,
 @Status=@StatusCodeOut OUTPUT,@Partial=@IsPartialOut OUTPUT,@Error=@ErrorNumberOut OUTPUT,@Message=@ErrorMessageOut OUTPUT;
        SET @CompletionReturned=1;
        IF @@TRANCOUNT<>0 THROW 53768,N'Der Datei-I/O-Abschluss hat eine unerwartete Transaktion hinterlassen.',1;
        SET @Sql=N'USE '+@TargetQuoted+N';
IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
 WHERE [database_id]=@Id AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@Name) AND [create_date]=@Created AND [state]=0 AND [is_read_only]=0)
 THROW 53764,N''Die Targetidentität vor der Ergebnisprojektion hat sich geändert.'',1;
INSERT [#RunSnapshotCollectionCycle_Run]
([CaptureRunId],[TargetDatabaseName],[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
SELECT [CaptureRunId],@Name,[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage]
FROM [snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),''FILE_IO'')
 AND CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@Source);
SET @Found=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
SELECT [ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run;';
        EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Run bigint,@Source sysname,@Found bit OUTPUT',
 @Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,@Run=@CaptureRunIdOut,@Source=@SourceName,@Found=@ProjectionFound OUTPUT;
        IF @ProjectionFound<>1 THROW 53763,N'Die Projektion bestätigt keinen passenden eigenen Datei-I/O-Run.',1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        IF @StatusCodeOut<>'FINALIZATION_UNCONFIRMED'
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                  WHEN ERROR_NUMBER() IN(53760,53761,53762,53764,208,2812,8144,8145) THEN 'TARGET_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());
        SET @Unhandled=1;
    END CATCH;
FileIOFinish:
    IF @LockHeld=1
    BEGIN TRY
        EXEC @LockResult=[sys].[sp_releaseapplock] @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockOwner='Session',@DbPrincipal=N'public';
        IF @LockResult<0 THROW 53768,N'Die Freigabe der eigenen Paket-Applock ist nicht bestätigt.',1;
        SET @LockHeld=0;
    END TRY
    BEGIN CATCH
        IF @StatusCodeOut<>'FINALIZATION_UNCONFIRMED'
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Unhandled=1;
    END CATCH;
    IF @Unhandled=1 OR @StatusCodeOut='FINALIZATION_UNCONFIRMED' OR (@Prepared=1 AND @StatusCodeOut='TARGET_UNAVAILABLE')
    BEGIN TRY
        IF @ProjectionFound=0 AND @SourceJson IS NOT NULL
            INSERT [#RunSnapshotCollectionCycle_Modules]
            ([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            SELECT NULL,@CaptureRunIdOut,[SourceName],SYSUTCDATETIME(),[StatusCode],1,[ErrorNumber],[ErrorMessage],
              N'Nicht persistierte Quelldiagnose aus dem unveränderten lokalen Sourceframe; Targetreadback ist nicht bestätigt.'
            FROM @Issues;
        DECLARE @Limit nvarchar(1000)=CASE WHEN @CompletionReturned=1
          THEN N'Der Backendaufruf ist beendet; eine gespeicherte Aufnahme bleibt erhalten. Ergebnisprojektion und Abschlussdetails sind hier nicht vollständig bestätigt.'
          ELSE N'Ein eröffneter Lauf kann unvollständig sein. Es wird kein Legacy-Abschluss und keine erfundene Nullprojektion geschrieben.' END;
        SET @Limit=CONCAT(@Limit,N' Gebundenes Target: ',QUOTENAME(@TargetDatabaseNameOut),N'.');
        SET @Sql=N'INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
VALUES(NULL,@Run,N''monitor.InternalRunSnapshotFileIOCycle'',SYSUTCDATETIME(),@Status,1,@Error,@Message,@Limit);';
        EXEC [sys].[sp_executesql] @Sql,N'@Run bigint,@Status varchar(40),@Error int,@Message nvarchar(2048),@Limit nvarchar(1000)',
 @Run=@CaptureRunIdOut,@Status=@StatusCodeOut,@Error=@ErrorNumberOut,@Message=@ErrorMessageOut,@Limit=@Limit;
    END TRY
    BEGIN CATCH
        -- Preserve the authoritative failure outputs if the caller result table is unavailable.
    END CATCH;
    IF @StatusCodeOut='INVALID_PARAMETER' AND @ErrorNumberOut=51011 RETURN 51011;
END;
GO
