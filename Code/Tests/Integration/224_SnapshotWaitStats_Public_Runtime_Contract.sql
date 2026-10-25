/*
Datei        : 224_SnapshotWaitStats_Public_Runtime_Contract.sql
Zweck        : Prüft die öffentliche Waitaktivierung mit eigener Targetdatenbank.
Artefakt-UID : urn:uuid:01a17523-3897-773d-94af-57d3690a5fb6
Registrierung: DEFERRED; keine finale lesbare Testkennung vergeben.
Grenze       : Native DMV-Abnahme ohne Cache-Reset oder atomare Quellenbehauptung.
*/
GO
USE [SQLServerAnalyzeTest];
GO
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
IF DB_ID(N'SQLServerAnalyzeWaitPublicTest') IS NOT NULL
 OR SUSER_ID(N'ExampleWaitPublicReader') IS NOT NULL
 OR DATABASE_PRINCIPAL_ID(N'ExampleWaitPublicReader') IS NOT NULL
 OR OBJECT_ID(N'[monitor].[ExampleWaitPublicFrameworkFailure]') IS NOT NULL
 THROW 53780,N'Public Wait fixture requires absent owned database and login.',1;
SELECT * INTO [#WaitPublicContract_Configuration] FROM [monitor].[SnapshotTargetConfiguration];
CREATE TABLE [#WaitPublicContract_Ownership]
([DatabaseId] int NULL,[Created] datetime NULL,[LoginSid] varbinary(85) NULL,
 [FrameworkUserId] int NULL,[TargetUserId] int NULL,[FrameworkTriggerId] int NULL,
 [PolicyTriggerId] int NULL,[ProjectionTriggerId] int NULL,[Impersonating] bit NOT NULL,[OriginalSid] varbinary(85) NOT NULL);
INSERT [#WaitPublicContract_Ownership]([Impersonating],[OriginalSid]) VALUES(0,SUSER_SID());
CREATE DATABASE [SQLServerAnalyzeWaitPublicTest] COLLATE SQL_Latin1_General_CP1_CS_AS;
UPDATE [#WaitPublicContract_Ownership] SET [DatabaseId]=DB_ID(N'SQLServerAnalyzeWaitPublicTest'),[Created]=(SELECT [create_date] FROM [master].[sys].[databases] WHERE [database_id]=DB_ID(N'SQLServerAnalyzeWaitPublicTest'));
GO
USE [SQLServerAnalyzeWaitPublicTest];
GO
:r Install_SnapshotBaseline_Target.sql
USE [SQLServerAnalyzeTest];
GO
CREATE PROCEDURE [#WaitPublicContract_Cleanup]
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Id int,@Created datetime,@Sid varbinary(85),@OriginalSid varbinary(85),@Impersonating bit,
 @FwUser int,@TargetUser int,@FwTrigger int,@PolicyTrigger int,@ProjectionTrigger int;
 SELECT @Id=[DatabaseId],@Created=[Created],@Sid=[LoginSid],@OriginalSid=[OriginalSid],@Impersonating=[Impersonating],
 @FwUser=[FrameworkUserId],@TargetUser=[TargetUserId],@FwTrigger=[FrameworkTriggerId],
 @PolicyTrigger=[PolicyTriggerId],@ProjectionTrigger=[ProjectionTriggerId] FROM [#WaitPublicContract_Ownership];
 IF SUSER_SID()<>@OriginalSid THROW 53783,N'Unexpected cleanup security context.',1;
 SET IMPLICIT_TRANSACTIONS OFF;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 IF DB_ID(N'SQLServerAnalyzeWaitPublicTest') IS NOT NULL AND NOT EXISTS
 (SELECT 1 FROM [master].[sys].[databases] WHERE [database_id]=@Id AND [name]=N'SQLServerAnalyzeWaitPublicTest' COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
 THROW 53783,N'Owned database identity changed; cleanup stopped.',1;
 DECLARE @FwCleanup nvarchar(max)=N'
 IF OBJECT_ID(N''[monitor].[ExampleWaitPublicFrameworkFailure]'') IS NOT NULL
 BEGIN
  IF COALESCE(OBJECT_ID(N''[monitor].[ExampleWaitPublicFrameworkFailure]''),-1)<>COALESCE(@Trigger,-2) THROW 53783,N''Owned framework trigger identity changed.'',1;
  DROP TRIGGER [monitor].[ExampleWaitPublicFrameworkFailure];
 END;
 IF DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'') IS NOT NULL
 BEGIN
  IF COALESCE(DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader''),-1)<>COALESCE(@User,-2)
   OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=@User AND sid=@Sid) THROW 53783,N''Owned framework user identity changed.'',1;
  DROP USER [ExampleWaitPublicReader];
 END;
 UPDATE [c] SET [TargetDatabaseName]=[b].[TargetDatabaseName],[IsEnabled]=[b].[IsEnabled],
 [DefaultSchedulerType]=[b].[DefaultSchedulerType],[PackageContractVersion]=[b].[PackageContractVersion],
 [SeedVersion]=[b].[SeedVersion],[LastUpdatedUtc]=[b].[LastUpdatedUtc]
 FROM [monitor].[SnapshotTargetConfiguration] AS [c] JOIN [#WaitPublicContract_Configuration] AS [b] ON [b].[ConfigurationId]=[c].[ConfigurationId];';
 EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] @FwCleanup,N'@Trigger int,@User int,@Sid varbinary(85)',@FwTrigger,@FwUser,@Sid;
 IF DB_ID(N'SQLServerAnalyzeWaitPublicTest') IS NOT NULL
 BEGIN
  DECLARE @TargetCheck nvarchar(max)=N'
  IF DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'') IS NOT NULL AND
   (COALESCE(DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader''),-1)<>COALESCE(@User,-2) OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=@User AND sid=@Sid)) THROW 53783,N''Owned target user identity changed.'',1;
  IF OBJECT_ID(N''[snapshot].[ExampleWaitPublicPolicyFailure]'') IS NOT NULL AND COALESCE(OBJECT_ID(N''[snapshot].[ExampleWaitPublicPolicyFailure]''),-1)<>COALESCE(@Policy,-2) THROW 53783,N''Owned policy trigger identity changed.'',1;
  IF OBJECT_ID(N''[snapshot].[ExampleWaitPublicProjectionFailure]'') IS NOT NULL AND COALESCE(OBJECT_ID(N''[snapshot].[ExampleWaitPublicProjectionFailure]''),-1)<>COALESCE(@Projection,-2) THROW 53783,N''Owned projection trigger identity changed.'',1;';
  EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] @TargetCheck,N'@User int,@Sid varbinary(85),@Policy int,@Projection int',@TargetUser,@Sid,@PolicyTrigger,@ProjectionTrigger;
  EXEC [master].[sys].[sp_executesql] N'DROP DATABASE [SQLServerAnalyzeWaitPublicTest];';
 END;
 IF SUSER_ID(N'ExampleWaitPublicReader') IS NOT NULL
 BEGIN
  IF @Sid IS NULL OR SUSER_SID(N'ExampleWaitPublicReader')<>@Sid THROW 53783,N'Owned login identity changed.',1;
  EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleWaitPublicReader];';
 END;
 IF DB_ID(N'SQLServerAnalyzeWaitPublicTest') IS NOT NULL OR SUSER_ID(N'ExampleWaitPublicReader') IS NOT NULL
  THROW 53783,N'Owned cleanup did not establish absence.',1;
END;
GO
-- The canonical installer above runs before framework mutation or impersonation.
-- Installation failures require the dedicated outer Lab-finally; all following phases
-- have this shared recovery boundary and ID/SID-bound cleanup.
BEGIN TRY
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'DECLARE @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Run bigint,@Json nvarchar(max),
 @Before nvarchar(max),@After nvarchar(max),@Purges bigint,@Samples bigint,@Runs bigint;
EXEC [monitor].[USP_ConfigureSnapshotTarget]
 @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',@CollectorCode=''WAIT_STATS'',@CollectorEnabled=0,
 @UpdateSharedPolicy=1,@MaxRows=3,@PayloadEnabled=1,@PrintMeldungen=0,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
IF COALESCE(@Status,'''')<>''AVAILABLE'' OR @Error IS NOT NULL OR @@TRANCOUNT<>0
 THROW 53780,N''Public Wait shared configuration failed.'',1;
SELECT @Before=(SELECT * FROM [monitor].[SnapshotTargetConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES);
SELECT @Purges=COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun];
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''NONE'',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''DISABLED'' OR @Run IS NOT NULL
 OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun])
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun])<>@Purges
 THROW 53780,N''Disabled Wait must return before capture or purge writes.'',1;

-- Shared0 must leave the complete framework row, retention and other collector intact.
INSERT [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy]
([RetentionPolicyCode],[RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays],[SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows],[BudgetAction],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
SELECT ''EXAMPLE_WAIT_CUSTOM'',[RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays],[SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows],[BudgetAction],0,2,[LastUpdatedUtc]
 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] WHERE [RetentionPolicyCode]=''DEFAULT'';
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] SET [RetentionPolicyCode]=''EXAMPLE_WAIT_CUSTOM'' WHERE [CollectorCode]=''WAIT_STATS'';

DECLARE @OtherBefore nvarchar(max)=(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]=''PERFORMANCE_COUNTERS'' FOR JSON PATH,INCLUDE_NULL_VALUES),
 @RetentionBefore nvarchar(max)=(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] FOR JSON PATH,INCLUDE_NULL_VALUES);
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',
 @CollectorCode='' wait_stats '',@CollectorEnabled=1,@MaxRows=3,@PayloadEnabled=1,
 @IsEnabled=0,@RawRetentionDays=365,@SoftBudgetMB=1,@PrintMeldungen=0,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
SELECT @After=(SELECT * FROM [monitor].[SnapshotTargetConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES);
IF COALESCE(@Status,'''')<>''AVAILABLE'' OR @Error IS NOT NULL OR CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After)
 OR CONVERT(varbinary(max),@OtherBefore)<>CONVERT(varbinary(max),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]=''PERFORMANCE_COUNTERS'' FOR JSON PATH,INCLUDE_NULL_VALUES))
 OR CONVERT(varbinary(max),@RetentionBefore)<>CONVERT(varbinary(max),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] FOR JSON PATH,INCLUDE_NULL_VALUES))
 THROW 53780,N''Collector-only configuration changed shared state.'',1;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]=''WAIT_STATS'' AND [RetentionPolicyCode]=''EXAMPLE_WAIT_CUSTOM'') THROW 53780,N''Collector-only configuration overwrote the custom retention binding.'',1;
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] SET [RetentionPolicyCode]=''DEFAULT'' WHERE [CollectorCode]=''WAIT_STATS'';
CREATE TABLE [#WaitPublicContract_Run]([Seed] bit NULL);
CREATE TABLE [#WaitPublicContract_Modules]([Seed] bit NULL);
SELECT CONVERT(varbinary(120),[wait_type]) AS [WaitType] INTO [#WaitPublicContract_NativeBefore] FROM [sys].[dm_os_wait_stats];
DECLARE @EngineBefore datetime,@TicksBefore bigint,@ServerBefore nvarchar(128)=CONVERT(nvarchar(128),SERVERPROPERTY(''ServerName''));
SELECT @EngineBefore=[sqlserver_start_time],@TicksBefore=[sqlserver_start_time_ms_ticks] FROM [sys].[dm_os_sys_info];
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"run":"#WaitPublicContract_Run","modules":"#WaitPublicContract_Modules"}'',
 @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
IF COALESCE(@Status,'''')<>''PARTIAL'' OR @Error IS NOT NULL OR @Run IS NULL OR ISJSON(@Json)<>1
 OR (SELECT COUNT_BIG(*) FROM [#WaitPublicContract_Run])<>1
 OR COALESCE(JSON_VALUE(@Json,N''$.run.CollectorCode''),N'''')<>N''WAIT_STATS''
 THROW 53780,N''Native Wait TABLE and JSON capture failed.'',1;
IF CONVERT(varbinary(max),(SELECT * FROM [#WaitPublicContract_Run] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES))
 <>CONVERT(varbinary(max),JSON_QUERY(@Json,N''$.run''))
 OR CONVERT(varbinary(max),(SELECT * FROM [#WaitPublicContract_Modules] ORDER BY [ModuleStatusId] FOR JSON PATH,INCLUDE_NULL_VALUES))
 <>CONVERT(varbinary(max),JSON_QUERY(@Json,N''$.modules''))
 THROW 53780,N''Public Wait TABLE and JSON projection differ.'',1;
DECLARE @Context nvarchar(4000);
SELECT @Context=[s].[StringValue] FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[MetricSample] AS [s]
 JOIN [SQLServerAnalyzeWaitPublicTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
 WHERE [s].[CaptureRunId]=@Run AND [d].[MetricCode]=''WAIT_CAPTURE_CONTEXT'';
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun]
 WHERE [CaptureRunId]=@Run AND [EndedAtUtc] IS NOT NULL AND [MetricSampleCount]>0
 AND [SqlServerStartTimeUtc] IS NULL AND [ResetEpochId] IS NOT NULL)
 OR @Context IS NULL OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Context,N''$.capture.nativeWaitTypeCount'')),-1)<=3
 OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Context,N''$.capture.writtenTypeCount'')),-1)<>3
 OR COALESCE(JSON_VALUE(@Context,N''$.capture.sourceComplete''),N'''')<>N''true''
 THROW 53780,N''Native full read, write cap, context or epoch contract failed.'',1;
-- Compare independently observed identities, without asserting simultaneous volatile counter values.
SELECT CONVERT(varbinary(120),[wait_type]) AS [WaitType] INTO [#WaitPublicContract_NativeAfter] FROM [sys].[dm_os_wait_stats];
DECLARE @EngineAfter datetime,@TicksAfter bigint,@ServerAfter nvarchar(128)=CONVERT(nvarchar(128),SERVERPROPERTY(''ServerName'')),@Payload nvarchar(max);
SELECT @EngineAfter=[sqlserver_start_time],@TicksAfter=[sqlserver_start_time_ms_ticks] FROM [sys].[dm_os_sys_info];
SELECT @Payload=CONVERT(nvarchar(max),DECOMPRESS([Payload])) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@Run;
SELECT CONVERT(varbinary(120),[WaitType]) AS [WaitType] INTO [#WaitPublicContract_PayloadTypes]
 FROM OPENJSON(@Payload,N''$.waits'') WITH ([WaitType] nvarchar(60));
IF @Payload IS NULL OR @EngineBefore<>@EngineAfter OR @TicksBefore<>@TicksAfter
 OR CONVERT(varbinary(max),@ServerBefore)<>CONVERT(varbinary(max),@ServerAfter)
 OR EXISTS(SELECT [WaitType] FROM [#WaitPublicContract_NativeBefore] EXCEPT SELECT [WaitType] FROM [#WaitPublicContract_NativeAfter])
 OR EXISTS(SELECT [WaitType] FROM [#WaitPublicContract_NativeAfter] EXCEPT SELECT [WaitType] FROM [#WaitPublicContract_NativeBefore])
 OR EXISTS(SELECT [WaitType] FROM [#WaitPublicContract_NativeBefore] EXCEPT SELECT [WaitType] FROM [#WaitPublicContract_PayloadTypes])
 OR EXISTS(SELECT [WaitType] FROM [#WaitPublicContract_PayloadTypes] EXCEPT SELECT [WaitType] FROM [#WaitPublicContract_NativeBefore])
 OR (SELECT COUNT_BIG(*) FROM [#WaitPublicContract_NativeBefore])<>(SELECT COUNT_BIG(*) FROM [#WaitPublicContract_PayloadTypes])
 OR COALESCE(JSON_VALUE(@Payload,N''$.meta.engineContext.serverName''),N'''') COLLATE Latin1_General_100_BIN2<>@ServerBefore COLLATE Latin1_General_100_BIN2
 OR COALESCE(TRY_CONVERT(datetime,JSON_VALUE(@Payload,N''$.meta.engineContext.sqlServerStartTimeLocal''),126),''1900-01-01'')<>@EngineBefore
 OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Payload,N''$.meta.engineContext.sqlServerStartTimeMsTicks'')),-1)<>@TicksBefore
 THROW 53780,N''Native full WaitType set or engine identity differs from the independent oracle.'',1;
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PayloadSnapshot]
 WHERE [CaptureRunId]=@Run AND [PayloadHash]=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),CONVERT(nvarchar(max),DECOMPRESS([Payload])))))
 THROW 53780,N''Native Wait payload hash is not lossless.'',1;

DECLARE @RecentPurgeEnd datetime2(3)=(SELECT MAX([EndedAtUtc]) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun]);
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun] SET [StartedAtUtc]=DATEADD(DAY,-2,SYSUTCDATETIME()),[EndedAtUtc]=DATEADD(DAY,-2,SYSUTCDATETIME());
SELECT @Purges=COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun];
SELECT @Runs=COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun];
SELECT @Samples=COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[MetricSample];
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''NONE'',@PrintMeldungen=0,
 @CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''SKIPPED_NOT_DUE'' OR @Run IS NOT NULL
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun])<>@Purges
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun])<>@Runs
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[MetricSample])<>@Samples
 THROW 53780,N''Not-due Wait wrote capture, samples or purge state.'',1;
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun] SET [EndedAtUtc]=@RecentPurgeEnd;
WAITFOR DELAY ''00:00:00.020'';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''NONE'',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
IF COALESCE(@Status,'''')<>''PARTIAL'' OR @Error IS NOT NULL OR @Run IS NULL
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[PurgeRun])<>@Purges
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun])<>@Runs+1
 THROW 53780,N''Purge interval incorrectly blocked a forced Wait capture.'',1;

EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''RAW'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''SKIPPED_NOT_DUE'' THROW 53780,N''Wait RAW interval output failed.'',1;
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''CONSOLE'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''SKIPPED_NOT_DUE'' THROW 53780,N''Wait CONSOLE interval output failed.'',1;

-- Force bypasses the collector interval, but cannot bypass the size budget.
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] SET [SoftBudgetMB]=1 WHERE [IsFrameworkDefault]=1;
SELECT @Runs=COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun];
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''NONE'',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''STOPPED_SIZE_BUDGET'' OR @Run IS NOT NULL
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun])<>@Runs
 THROW 53780,N''Force bypassed the Wait size budget.'',1;
UPDATE [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] SET [SoftBudgetMB]=10240 WHERE [IsFrameworkDefault]=1;

-- Admission precedes temp DDL and preserves the caller transaction and sentinels.
CREATE TABLE [#WaitPublicContract_Sentinel]([Value] int NOT NULL);
BEGIN TRANSACTION;
INSERT [#WaitPublicContract_Sentinel] VALUES(1);
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''NONE'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''INVALID_PARAMETER'' OR @@TRANCOUNT<>1 OR XACT_STATE()<>1
 THROW 53780,N''Wait run changed the caller transaction.'',1;
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',@CollectorCode=''WAIT_STATS'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''INVALID_PARAMETER'' OR @@TRANCOUNT<>1 OR XACT_STATE()<>1
 OR (SELECT COUNT_BIG(*) FROM [#WaitPublicContract_Sentinel])<>1
 THROW 53780,N''Wait configuration changed the caller transaction.'',1;
ROLLBACK TRANSACTION;
SET IMPLICIT_TRANSACTIONS ON;
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''NONE'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''INVALID_PARAMETER'' OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>2
 THROW 53780,N''Wait run opened an implicit transaction.'',1;
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',@CollectorCode=''WAIT_STATS'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''INVALID_PARAMETER'' OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>2
 THROW 53780,N''Wait configuration opened an implicit transaction.'',1;
SET IMPLICIT_TRANSACTIONS OFF;
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@ResultSetArt=''JSON'',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''INVALID_PARAMETER'' THROW 53780,N''Wait accepted the legacy JSON output mode.'',1;
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@Hilfe=1,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'''')<>''AVAILABLE'' THROW 53780,N''Wait help failed.'',1;
-- The original thirteen positional arguments still select Performance Counter.
EXEC [monitor].[USP_RunSnapshotCollectionCycle] ''MANUAL'',1,''NONE'',NULL,0,@Json OUTPUT,0,0,@Run OUTPUT,@Status OUTPUT,@Partial OUTPUT,@Error OUTPUT,@Message OUTPUT;
IF COALESCE(@Status,'''') NOT IN(''AVAILABLE'',''PARTIAL'') OR @Run IS NULL
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND [CollectorCode]=''PERFORMANCE_COUNTERS'')
 THROW 53780,N''Legacy positional collection no longer selects Performance Counter.'',1;';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'-- Both a target-side failure and a later framework-side failure roll back both databases.';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'CREATE TRIGGER [snapshot].[ExampleWaitPublicPolicyFailure] ON [snapshot].[CollectorPolicy] AFTER UPDATE AS
 THROW 53781,N''Owned target policy failure.'',1;';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'UPDATE [#WaitPublicContract_Ownership] SET [PolicyTriggerId]=OBJECT_ID(N''[snapshot].[ExampleWaitPublicPolicyFailure]'');';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'DECLARE @Status varchar(40),@Error int,@Before nvarchar(max),@After nvarchar(max),
 @StateSql nvarchar(max)=N''SELECT @State=CONCAT((SELECT * FROM [monitor].[SnapshotTargetConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] ORDER BY [CollectorCode] FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] ORDER BY [RetentionPolicyCode] FOR JSON PATH,INCLUDE_NULL_VALUES));'';
EXEC [sys].[sp_executesql] @StateSql,N''@State nvarchar(max) OUTPUT'',@Before OUTPUT;
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',@CollectorCode=''WAIT_STATS'',
 @UpdateSharedPolicy=1,@MaxRows=5,@RawRetentionDays=42,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
EXEC [sys].[sp_executesql] @StateSql,N''@State nvarchar(max) OUTPUT'',@After OUTPUT;
IF COALESCE(@Error,0)<>53781 OR COALESCE(@Status,'''')=''AVAILABLE'' OR @@TRANCOUNT<>0 OR CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After)
 THROW 53780,N''Target-side failure was not atomic.'',1;';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'IF COALESCE(OBJECT_ID(N''[snapshot].[ExampleWaitPublicPolicyFailure]''),-1)<>COALESCE((SELECT [PolicyTriggerId] FROM [#WaitPublicContract_Ownership]),-2) THROW 53783,N''Owned trigger identity changed.'',1;
DROP TRIGGER [snapshot].[ExampleWaitPublicPolicyFailure];';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'CREATE TRIGGER [monitor].[ExampleWaitPublicFrameworkFailure] ON [monitor].[SnapshotTargetConfiguration] AFTER UPDATE AS
 THROW 53782,N''Owned framework configuration failure.'',1;';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'UPDATE [#WaitPublicContract_Ownership] SET [FrameworkTriggerId]=OBJECT_ID(N''[monitor].[ExampleWaitPublicFrameworkFailure]'');';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'DECLARE @Status varchar(40),@Error int,@Before nvarchar(max),@After nvarchar(max),
 @StateSql nvarchar(max)=N''SELECT @State=CONCAT((SELECT * FROM [monitor].[SnapshotTargetConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CollectorPolicy] ORDER BY [CollectorCode] FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[RetentionPolicy] ORDER BY [RetentionPolicyCode] FOR JSON PATH,INCLUDE_NULL_VALUES));'';
EXEC [sys].[sp_executesql] @StateSql,N''@State nvarchar(max) OUTPUT'',@Before OUTPUT;
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N''SQLServerAnalyzeWaitPublicTest'',@CollectorCode=''WAIT_STATS'',
 @UpdateSharedPolicy=1,@MaxRows=5,@RawRetentionDays=42,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
EXEC [sys].[sp_executesql] @StateSql,N''@State nvarchar(max) OUTPUT'',@After OUTPUT;
IF COALESCE(@Error,0)<>53782 OR COALESCE(@Status,'''')=''AVAILABLE'' OR @@TRANCOUNT<>0 OR CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After)
 THROW 53780,N''Framework-side failure was not atomic.'',1;
IF COALESCE(OBJECT_ID(N''[monitor].[ExampleWaitPublicFrameworkFailure]''),-1)<>COALESCE((SELECT [FrameworkTriggerId] FROM [#WaitPublicContract_Ownership]),-2) THROW 53783,N''Owned trigger identity changed.'',1;
DROP TRIGGER [monitor].[ExampleWaitPublicFrameworkFailure];';
    EXEC [master].[sys].[sp_executesql] N'-- An owned login can execute the target contract without access to native server state.';
    EXEC [master].[sys].[sp_executesql] N'DECLARE @Secret nvarchar(128)=CONVERT(nvarchar(36),NEWID())+N''aA!9'';
DECLARE @CreateLogin nvarchar(max)=N''CREATE LOGIN [ExampleWaitPublicReader] WITH PASSWORD=''+QUOTENAME(@Secret,N'''''''')+N'',CHECK_POLICY=OFF;'';
EXEC [sys].[sp_executesql] @CreateLogin;
UPDATE [#WaitPublicContract_Ownership] SET [LoginSid]=SUSER_SID(N''ExampleWaitPublicReader'');';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'CREATE USER [ExampleWaitPublicReader] FOR LOGIN [ExampleWaitPublicReader];
UPDATE [#WaitPublicContract_Ownership] SET [FrameworkUserId]=DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'');
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'') AND sid=(SELECT [LoginSid] FROM [#WaitPublicContract_Ownership])) THROW 53783,N''Owned user SID binding failed.'',1;
GRANT EXECUTE ON SCHEMA::[monitor] TO [ExampleWaitPublicReader];
GRANT SELECT ON [monitor].[SnapshotTargetConfiguration] TO [ExampleWaitPublicReader];
';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'CREATE USER [ExampleWaitPublicReader] FOR LOGIN [ExampleWaitPublicReader];
UPDATE [#WaitPublicContract_Ownership] SET [TargetUserId]=DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'');
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=DATABASE_PRINCIPAL_ID(N''ExampleWaitPublicReader'') AND sid=(SELECT [LoginSid] FROM [#WaitPublicContract_Ownership])) THROW 53783,N''Owned user SID binding failed.'',1;
GRANT EXECUTE ON SCHEMA::[snapshot] TO [ExampleWaitPublicReader];
GRANT SELECT ON SCHEMA::[snapshot] TO [ExampleWaitPublicReader];
';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'DECLARE @Status varchar(40),@Error int,@Run bigint;
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=1;
BEGIN TRY
EXECUTE AS LOGIN=N''ExampleWaitPublicReader'';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''NONE'',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
REVERT;
END TRY
BEGIN CATCH
 IF SUSER_SID()=(SELECT [LoginSid] FROM [#WaitPublicContract_Ownership]) REVERT;
 UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
 THROW;
END CATCH;
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
IF COALESCE(@Status,'''')<>''DENIED_PERMISSION'' OR @Run IS NULL OR @Error IS NULL
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun]
 WHERE [CaptureRunId]=@Run AND [EndedAtUtc] IS NOT NULL AND [MetricSampleCount]=0 AND [ResetEpochId] IS NULL)
 OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run)
 THROW 53780,N''Native source denial did not finalize an honest empty failed run.'',1;';
    EXEC [master].[sys].[sp_executesql] N'IF CONVERT(int,SERVERPROPERTY(''ProductMajorVersion''))>=16
 EXEC(N''GRANT VIEW SERVER PERFORMANCE STATE TO [ExampleWaitPublicReader];'');
ELSE GRANT VIEW SERVER STATE TO [ExampleWaitPublicReader];';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'DECLARE @Status varchar(40),@Error int,@Run bigint;
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=1;
BEGIN TRY
EXECUTE AS LOGIN=N''ExampleWaitPublicReader'';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''NONE'',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
REVERT;
END TRY
BEGIN CATCH
 IF SUSER_SID()=(SELECT [LoginSid] FROM [#WaitPublicContract_Ownership]) REVERT;
 UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
 THROW;
END CATCH;
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
IF COALESCE(@Status,'''')<>''PARTIAL'' OR @Error IS NOT NULL OR @Run IS NULL
 THROW 53780,N''Explicit native-state permission did not enable the Wait source.'',1;';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'CREATE TRIGGER [snapshot].[ExampleWaitPublicProjectionFailure] ON [snapshot].[ModuleStatus]
 WITH EXECUTE AS OWNER AFTER INSERT AS
 DENY SELECT ON [snapshot].[CaptureRun] TO [ExampleWaitPublicReader];';
    EXEC [SQLServerAnalyzeWaitPublicTest].[sys].[sp_executesql] N'UPDATE [#WaitPublicContract_Ownership] SET [ProjectionTriggerId]=OBJECT_ID(N''[snapshot].[ExampleWaitPublicProjectionFailure]'');';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'CREATE TABLE [#WaitPublicContract_FailedRun]([Seed] bit NULL);
CREATE TABLE [#WaitPublicContract_FailedModules]([Seed] bit NULL);
DECLARE @Status varchar(40),@Error int,@Run bigint,@Json nvarchar(max);
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=1;
BEGIN TRY
EXECUTE AS LOGIN=N''ExampleWaitPublicReader'';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode=''WAIT_STATS'',@RunEvenIfNotDue=1,
 @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"run":"#WaitPublicContract_FailedRun","modules":"#WaitPublicContract_FailedModules"}'',
 @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
REVERT;
END TRY
BEGIN CATCH
 IF SUSER_SID()=(SELECT [LoginSid] FROM [#WaitPublicContract_Ownership]) REVERT;
 UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
 THROW;
END CATCH;
UPDATE [#WaitPublicContract_Ownership] SET [Impersonating]=0;
DECLARE @ModuleErrorFound bit=0;
EXEC [sys].[sp_executesql] N''IF EXISTS(SELECT 1 FROM [#WaitPublicContract_FailedModules] WHERE [CaptureRunId]=@Run AND [ErrorNumber] IS NOT NULL) SET @Found=1;'',N''@Run bigint,@Found bit OUTPUT'',@Run,@ModuleErrorFound OUTPUT;
IF @Run IS NULL OR @Error IS NULL OR COALESCE(@Status,'''')=''PARTIAL''
 OR EXISTS(SELECT 1 FROM [#WaitPublicContract_FailedRun]) OR COALESCE(JSON_QUERY(@Json,N''$.run''),N''!'')<>N''{}''
 OR @ModuleErrorFound<>1
 OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeWaitPublicTest].[snapshot].[CaptureRun]
 WHERE [CaptureRunId]=@Run AND [EndedAtUtc] IS NOT NULL AND [StatusCode]=''PARTIAL'' AND [MetricSampleCount]>0)
 THROW 53780,N''Output readback failure lost committed data or invented zero counts.'',1;';
    EXEC [#WaitPublicContract_Cleanup];
END TRY
BEGIN CATCH
    EXEC [#WaitPublicContract_Cleanup];
    THROW;
END CATCH;
PRINT N'SC023_WAIT_PUBLIC_RUNTIME_CONTRACT PASS';
GO
