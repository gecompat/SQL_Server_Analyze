USE [DeineDatenbank];
GO
/*
===============================================================================
Objekt       : monitor.InternalValidateSnapshotWaitTarget
Version      : 1.1.0
Stand        : 2026-10-26
Zweck        : Prüft die tatsächlich benötigte Wait-Targetclosure ohne Produktwrite.
Verwendung   : Interner gemeinsamer Eintritt für Konfiguration und Waitlauf.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalValidateSnapshotWaitTarget]
      @TargetDatabaseName sysname
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetCreateDate datetime = NULL
    , @TargetDatabaseIdOut int OUTPUT
    , @TargetCreateDateOut datetime OUTPUT
    , @StatusCodeOut varchar(40) OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
    , @CollectorCode varchar(64) = 'WAIT_STATS'
AS
BEGIN
    SELECT @TargetDatabaseIdOut=NULL,@TargetCreateDateOut=NULL,@StatusCodeOut='AVAILABLE',
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @CollectorCode IS NULL OR CONVERT(varbinary(max),@CollectorCode) NOT IN(CONVERT(varbinary(max),'WAIT_STATS'),CONVERT(varbinary(max),'FILE_IO'))
       OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0
       OR NULLIF(LTRIM(RTRIM(@TargetDatabaseName)),N'') IS NULL
       OR ((@ExpectedTargetDatabaseId IS NULL AND @ExpectedTargetCreateDate IS NOT NULL)
           OR (@ExpectedTargetDatabaseId IS NOT NULL AND @ExpectedTargetCreateDate IS NULL))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Die Wait-Zulassung benötigt eine vollständige Bindung ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SELECT @TargetDatabaseIdOut=[database_id],@TargetCreateDateOut=[create_date]
    FROM [master].[sys].[databases] WITH (NOLOCK)
    WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@TargetDatabaseName)
      AND [database_id]>4 AND [database_id]<>DB_ID() AND [state]=0 AND [is_read_only]=0;
    IF @TargetDatabaseIdOut IS NULL OR
       (@ExpectedTargetDatabaseId IS NOT NULL AND
        (@TargetDatabaseIdOut<>@ExpectedTargetDatabaseId OR @TargetCreateDateOut<>@ExpectedTargetCreateDate))
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53764,
               @ErrorMessageOut=N'Die erwartete separate Snapshot-Zielidentität ist nicht verfügbar.';
        RETURN;
    END;
    DECLARE @Sql nvarchar(max),@ProbeRun bigint,@ProbeStatus varchar(40),@ProbeBudget bit,
            @ProbeError int,@ProbeMessage nvarchar(2048),@RetentionContract int,@RequiredRetention int;
    BEGIN TRY
        DECLARE @AdmissionSql nvarchar(max)=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
 WHERE [database_id]=@Id AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@Name)
 AND [create_date]=@Created AND [state]=0 AND [is_read_only]=0)
 THROW 53764,N''Die gebundene Targetidentität stimmt nicht mehr überein.'',1;
IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
 (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),''SC-023'')
 AND ((@Collector=''WAIT_STATS'' AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),''1.2.1'') AND [SchemaVersion]=2)
 OR (@Collector=''WAIT_STATS'' AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),''1.3.0'') AND [SchemaVersion]=3)
 OR (CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),''1.3.1'') AND [SchemaVersion]=3)))
 THROW 53761,N''Die neuen öffentlichen Optionen benötigen das vollständige Snapshot-Target 1.2.1.'',1;
SELECT @Required=CASE WHEN [PackageVersion]=''1.3.1'' THEN 3 WHEN [SchemaVersion]=3 THEN 2 ELSE 1 END FROM [snapshot].[PackageVersion];
DECLARE @Methods TABLE([Name] sysname,[ObjectId] int NULL);
INSERT @Methods
SELECT [e].[Name],[p].[object_id] FROM (VALUES(N''InternalConfigureSnapshotPolicy''),(N''InternalPrepareCollectionCycle''),(N''InternalCompleteWaitStatsCycle''),(N''InternalPurgeExpiredData'')) AS [e]([Name])
LEFT JOIN [sys].[procedures] AS [p] WITH (NOLOCK)
 ON CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[Name])
 AND [p].[schema_id] IN(SELECT [schema_id] FROM [sys].[schemas] WITH (NOLOCK)
                       WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N''snapshot''));
IF EXISTS(SELECT 1 FROM @Methods [e] LEFT JOIN [sys].[sql_modules] [m] WITH (NOLOCK) ON [m].[object_id]=[e].[ObjectId]
 WHERE [e].[ObjectId] IS NULL OR [m].[object_id] IS NULL OR [m].[uses_ansi_nulls]<>1 OR [m].[uses_quoted_identifier]<>1)
 THROW 53762,N''Die benötigten Waithelper fehlen oder sind nicht sichtbar.'',1;
DECLARE @Params TABLE([Method] sysname,[Name] sysname,[SystemTypeId] int,[MaxLength] smallint,[IsOutput] bit);
-- WAIT_ADMISSION_PARAMETERS_BEGIN
INSERT @Params VALUES
 (N''InternalConfigureSnapshotPolicy'',N''@CollectionIntervalSeconds'',52,2,0),
 (N''InternalConfigureSnapshotPolicy'',N''@MaxRows'',56,4,0),
 (N''InternalConfigureSnapshotPolicy'',N''@PayloadEnabled'',104,1,0),
 (N''InternalConfigureSnapshotPolicy'',N''@RawRetentionDays'',52,2,0),
 (N''InternalConfigureSnapshotPolicy'',N''@PayloadRetentionDays'',52,2,0),
 (N''InternalConfigureSnapshotPolicy'',N''@RollupRetentionDays'',52,2,0),
 (N''InternalConfigureSnapshotPolicy'',N''@SoftBudgetMB'',56,4,0),
 (N''InternalConfigureSnapshotPolicy'',N''@PurgeIntervalMinutes'',52,2,0),
 (N''InternalConfigureSnapshotPolicy'',N''@PurgeBatchRows'',56,4,0),
 (N''InternalConfigureSnapshotPolicy'',N''@BudgetAction'',167,32,0),
 (N''InternalConfigureSnapshotPolicy'',N''@StatusCodeOut'',167,40,1),
 (N''InternalConfigureSnapshotPolicy'',N''@ErrorNumberOut'',56,4,1),
 (N''InternalConfigureSnapshotPolicy'',N''@ErrorMessageOut'',231,4096,1),
 (N''InternalConfigureSnapshotPolicy'',N''@CollectorCode'',167,64,0),
 (N''InternalConfigureSnapshotPolicy'',N''@CollectorEnabled'',104,1,0),
 (N''InternalConfigureSnapshotPolicy'',N''@UpdateSharedPolicy'',104,1,0),
 (N''InternalConfigureSnapshotPolicy'',N''@ExpectedTargetDatabaseId'',56,4,0),
 (N''InternalConfigureSnapshotPolicy'',N''@ExpectedTargetDatabaseName'',231,256,0),
 (N''InternalConfigureSnapshotPolicy'',N''@ExpectedTargetCreateDate'',61,8,0),
 (N''InternalConfigureSnapshotPolicy'',N''@JoinFrameworkTransaction'',104,1,0),
 (N''InternalPrepareCollectionCycle'',N''@SourceDatabaseName'',231,256,0),
 (N''InternalPrepareCollectionCycle'',N''@SchedulerType'',167,16,0),
 (N''InternalPrepareCollectionCycle'',N''@RunEvenIfNotDue'',104,1,0),
 (N''InternalPrepareCollectionCycle'',N''@CaptureRunIdOut'',127,8,1),
 (N''InternalPrepareCollectionCycle'',N''@ShouldCollectOut'',104,1,1),
 (N''InternalPrepareCollectionCycle'',N''@StatusCodeOut'',167,40,1),
 (N''InternalPrepareCollectionCycle'',N''@ErrorMessageOut'',231,4096,1),
 (N''InternalPrepareCollectionCycle'',N''@CollectorCode'',167,64,0),
 (N''InternalPrepareCollectionCycle'',N''@ExpectedTargetDatabaseId'',56,4,0),
 (N''InternalPrepareCollectionCycle'',N''@ExpectedTargetDatabaseName'',231,256,0),
 (N''InternalPrepareCollectionCycle'',N''@ExpectedTargetCreateDate'',61,8,0),
 (N''InternalPrepareCollectionCycle'',N''@PolicyOnly'',104,1,0),
 (N''InternalCompleteWaitStatsCycle'',N''@CaptureRunId'',127,8,0),
 (N''InternalCompleteWaitStatsCycle'',N''@CollectorJson'',231,-1,0),
 (N''InternalCompleteWaitStatsCycle'',N''@ExpectedTargetDatabaseId'',56,4,0),
 (N''InternalCompleteWaitStatsCycle'',N''@ExpectedTargetDatabaseName'',231,256,0),
 (N''InternalCompleteWaitStatsCycle'',N''@ExpectedTargetCreateDate'',61,8,0),
 (N''InternalCompleteWaitStatsCycle'',N''@StatusCodeOut'',167,40,1),
 (N''InternalCompleteWaitStatsCycle'',N''@IsPartialOut'',104,1,1),
 (N''InternalCompleteWaitStatsCycle'',N''@ErrorNumberOut'',56,4,1),
 (N''InternalCompleteWaitStatsCycle'',N''@ErrorMessageOut'',231,4096,1),
 (N''InternalPurgeExpiredData'',N''@MaxBatches'',56,4,0),
 (N''InternalPurgeExpiredData'',N''@Force'',104,1,0),
 (N''InternalPurgeExpiredData'',N''@PurgeRunIdOut'',127,8,1),
 (N''InternalPurgeExpiredData'',N''@StatusCodeOut'',167,40,1),
 (N''InternalPurgeExpiredData'',N''@BudgetExceededOut'',104,1,1),
 (N''InternalPurgeExpiredData'',N''@ErrorNumberOut'',56,4,1),
 (N''InternalPurgeExpiredData'',N''@ErrorMessageOut'',231,4096,1),
 (N''InternalPurgeExpiredData'',N''@ContractOnly'',104,1,0),
 (N''InternalPurgeExpiredData'',N''@RetentionContractVersionOut'',56,4,1),
 (N''InternalPurgeExpiredData'',N''@ExpectedTargetDatabaseId'',56,4,0),
 (N''InternalPurgeExpiredData'',N''@ExpectedTargetDatabaseName'',231,256,0),
 (N''InternalPurgeExpiredData'',N''@ExpectedTargetCreateDate'',61,8,0);
-- WAIT_ADMISSION_PARAMETERS_END
IF @Collector=''FILE_IO''
BEGIN
 UPDATE @Params SET [Method]=N''InternalCompleteFileIOCycle'' WHERE [Method]=N''InternalCompleteWaitStatsCycle'';
 UPDATE [e] SET [Name]=N''InternalCompleteFileIOCycle'',[ObjectId]=[p].[object_id]
 FROM @Methods [e] LEFT JOIN [sys].[procedures] [p] WITH (NOLOCK)
 ON CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N''InternalCompleteFileIOCycle'')
 AND [p].[schema_id] IN(SELECT [schema_id] FROM [sys].[schemas] WITH (NOLOCK)
 WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N''snapshot''))
 WHERE [e].[Name]=N''InternalCompleteWaitStatsCycle'';
 IF EXISTS(SELECT 1 FROM @Methods [e] LEFT JOIN [sys].[sql_modules] [m] WITH (NOLOCK) ON [m].[object_id]=[e].[ObjectId]
 WHERE [e].[ObjectId] IS NULL OR [m].[object_id] IS NULL OR [m].[uses_ansi_nulls]<>1 OR [m].[uses_quoted_identifier]<>1)
 THROW 53762,N''Die benötigten Dateihelper fehlen oder sind nicht sichtbar.'',1;
END;
IF EXISTS(SELECT 1 FROM @Params [e] JOIN @Methods [m] ON [m].[Name]=[e].[Method]
 LEFT JOIN [sys].[parameters] [p] WITH (NOLOCK) ON [p].[object_id]=[m].[ObjectId]
 AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[Name])
 WHERE [p].[parameter_id] IS NULL OR [p].[system_type_id]<>[e].[SystemTypeId]
 OR [p].[max_length]<>[e].[MaxLength] OR [p].[is_output]<>[e].[IsOutput])
 OR EXISTS(SELECT 1 FROM @Methods [m] WHERE
  (SELECT COUNT_BIG(*) FROM [sys].[parameters] [p] WITH (NOLOCK) WHERE [p].[object_id]=[m].[ObjectId] AND [p].[parameter_id]>0)
  <>(SELECT COUNT_BIG(*) FROM @Params [e] WHERE [e].[Method]=[m].[Name]))
 THROW 53762,N''Die tatsächlich benötigten Waitsignaturen passen nicht zu 1.2.1.'',1;
DECLARE @Metrics TABLE([Code] varchar(96),[Type] varchar(24),[Unit] varchar(40));
INSERT @Metrics VALUES
 (''WAIT_TASK_COUNT'',''BIGINT'',''count''),(''WAIT_TIME_MS'',''BIGINT'',''ms''),(''WAIT_SIGNAL_TIME_MS'',''BIGINT'',''ms''),
 (''WAIT_MAX_TIME_MS'',''BIGINT'',''ms''),(''WAIT_TASK_COUNT_DELTA_CANDIDATE'',''BIGINT'',''count''),
 (''WAIT_TIME_MS_DELTA_CANDIDATE'',''BIGINT'',''ms''),(''WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE'',''BIGINT'',''ms''),
 (''WAIT_DELTA_STATUS'',''STRING'',''status''),(''WAIT_CAPTURE_CONTEXT'',''STRING'',''json'');
IF @Collector=''FILE_IO''
BEGIN
 DELETE @Metrics;
 INSERT @Metrics VALUES
 (''IO_READ_COUNT'',''BIGINT'',''count''),(''IO_READ_BYTES'',''BIGINT'',''bytes''),(''IO_READ_STALL_MS'',''BIGINT'',''ms''),
 (''IO_WRITE_COUNT'',''BIGINT'',''count''),(''IO_WRITE_BYTES'',''BIGINT'',''bytes''),(''IO_WRITE_STALL_MS'',''BIGINT'',''ms''),
 (''IO_SIZE_ON_DISK_BYTES'',''BIGINT'',''bytes''),(''IO_READ_COUNT_DELTA_CANDIDATE'',''BIGINT'',''count''),
 (''IO_READ_BYTES_DELTA_CANDIDATE'',''BIGINT'',''bytes''),(''IO_READ_STALL_MS_DELTA_CANDIDATE'',''BIGINT'',''ms''),
 (''IO_WRITE_COUNT_DELTA_CANDIDATE'',''BIGINT'',''count''),(''IO_WRITE_BYTES_DELTA_CANDIDATE'',''BIGINT'',''bytes''),
 (''IO_WRITE_STALL_MS_DELTA_CANDIDATE'',''BIGINT'',''ms''),(''IO_DELTA_STATUS'',''STRING'',''status''),
 (''IO_FILE_CONTEXT'',''STRING'',''json''),(''IO_CAPTURE_CONTEXT'',''STRING'',''json'');
END;
IF EXISTS(SELECT 1 FROM @Metrics [e] LEFT JOIN [snapshot].[MetricDefinition] [d]
 ON CONVERT(varbinary(max),[d].[MetricCode])=CONVERT(varbinary(max),[e].[Code])
 WHERE [d].[MetricDefinitionId] IS NULL OR CONVERT(varbinary(max),[d].[ValueType])<>CONVERT(varbinary(max),[e].[Type])
 OR CONVERT(varbinary(max),[d].[Unit])<>CONVERT(varbinary(max),[e].[Unit]) OR [d].[ContractVersion]<>1)
 OR NOT EXISTS(SELECT 1 FROM [snapshot].[CollectorPolicy] WHERE CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),@Collector))
 THROW 53760,N''Die erforderlichen Waitdefinitionen fehlen oder widersprechen dem Metrikvertrag.'',1;
';
        SET @Sql=N'USE '+QUOTENAME(@TargetDatabaseName)+N'; EXEC [sys].[sp_executesql] @Body,N''@Id int,@Name sysname,@Created datetime,@Collector varchar(64),@Required int OUTPUT'',@Id,@Name,@Created,@Collector,@Required OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,N'@Body nvarchar(max),@Id int,@Name sysname,@Created datetime,@Collector varchar(64),@Required int OUTPUT',
             @AdmissionSql,@TargetDatabaseIdOut,@TargetDatabaseName,@TargetCreateDateOut,@CollectorCode,@RequiredRetention OUTPUT;
        SET @Sql=N'EXEC '+QUOTENAME(@TargetDatabaseName)+N'.[snapshot].[InternalPurgeExpiredData]
 @MaxBatches=1,@Force=0,@ContractOnly=1,@RetentionContractVersionOut=@V OUTPUT,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created,
 @PurgeRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@BudgetExceededOut=@Budget OUTPUT,
 @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@V int OUTPUT,@Id int,@Name sysname,@Created datetime,@Run bigint OUTPUT,@Status varchar(40) OUTPUT,@Budget bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
 @V=@RetentionContract OUTPUT,@Id=@TargetDatabaseIdOut,@Name=@TargetDatabaseName,@Created=@TargetCreateDateOut,
 @Run=@ProbeRun OUTPUT,@Status=@ProbeStatus OUTPUT,@Budget=@ProbeBudget OUTPUT,@Error=@ProbeError OUTPUT,@Message=@ProbeMessage OUTPUT;
        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR @ProbeError IS NOT NULL OR @ProbeRun IS NOT NULL
           OR @ProbeBudget IS NULL OR @ProbeBudget<>0 OR @RetentionContract IS NULL OR @RetentionContract<>@RequiredRetention
            SELECT @StatusCodeOut=CASE WHEN @ProbeStatus='DENIED_PERMISSION' THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
                   @ErrorNumberOut=COALESCE(@ProbeError,53761),
                   @ErrorMessageOut=COALESCE(@ProbeMessage,N'Der tatsächlich ausgeführte Retentionsvertragsaufruf bestätigt keine passende schreibfreie Version.');
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
               @ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());
    END CATCH;
END;
GO
