/*
Datei        : 228_SnapshotFileIO_Public_Runtime_Contract.sql
Zweck        : Prüft die öffentliche Datei-I/O-Aufnahme mit eigener Targetdatenbank.
Artefakt-UID : urn:uuid:01a1766e-cb9a-7fb5-8b75-a143663cc79f
Registrierung: DEFERRED; keine finale lesbare Testkennung vergeben.
Grenze       : Native DMV-Abnahme ohne Cache-Reset oder atomare Quellenbehauptung.
*/
GO
USE [SQLServerAnalyzeTest];
GO
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
IF DB_ID(N'SQLServerAnalyzeFileIOPublicTest') IS NOT NULL
 OR SUSER_ID(N'ExampleFileIOPublicReader') IS NOT NULL
 OR DATABASE_PRINCIPAL_ID(N'ExampleFileIOPublicReader') IS NOT NULL
 OR OBJECT_ID(N'[monitor].[ExampleFileIOPublicFrameworkFailure]') IS NOT NULL
 THROW 53780,N'Public FILE_IO fixture requires absent owned database and login.',1;
SELECT * INTO [#FileIOPublicContract_Configuration] FROM [monitor].[SnapshotTargetConfiguration];
CREATE TABLE [#FileIOPublicContract_Ownership]
([DatabaseId] int NULL,[Created] datetime NULL,[LoginSid] varbinary(85) NULL,
 [FrameworkUserId] int NULL,[TargetUserId] int NULL,[FrameworkTriggerId] int NULL,
 [PolicyTriggerId] int NULL,[ProjectionTriggerId] int NULL,[Impersonating] bit NOT NULL,[OriginalSid] varbinary(85) NOT NULL,[ProcedureId] int NULL,[ProcedureDefinition] nvarchar(max) NULL);
INSERT [#FileIOPublicContract_Ownership]([Impersonating],[OriginalSid],[ProcedureId],[ProcedureDefinition])
VALUES(0,SUSER_SID(),OBJECT_ID(N'monitor.InternalRunSnapshotFileIOCycle'),OBJECT_DEFINITION(OBJECT_ID(N'monitor.InternalRunSnapshotFileIOCycle')));
IF NOT EXISTS(SELECT 1 FROM [#FileIOPublicContract_Ownership] WHERE [ProcedureId] IS NOT NULL AND [ProcedureDefinition] IS NOT NULL)
 THROW 53783,N'Installed native source definition is not visible.',1;
CREATE TABLE [#FileIOPublicContract_SourceFrames]([SourceJson] nvarchar(max) NOT NULL);
CREATE DATABASE [SQLServerAnalyzeFileIOPublicTest] COLLATE SQL_Latin1_General_CP1_CS_AS;
UPDATE [#FileIOPublicContract_Ownership] SET [DatabaseId]=DB_ID(N'SQLServerAnalyzeFileIOPublicTest'),[Created]=(SELECT [create_date] FROM [master].[sys].[databases] WHERE [database_id]=DB_ID(N'SQLServerAnalyzeFileIOPublicTest'));
GO
USE [SQLServerAnalyzeFileIOPublicTest];
GO
:r Install_SnapshotBaseline_Target.sql
USE [SQLServerAnalyzeTest];
GO
CREATE PROCEDURE [#FileIOPublicContract_Cleanup]
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @Id int,@Created datetime,@Sid varbinary(85),@OriginalSid varbinary(85),@Impersonating bit,
 @FwUser int,@TargetUser int,@FwTrigger int,@PolicyTrigger int,@ProjectionTrigger int;
 SELECT @Id=[DatabaseId],@Created=[Created],@Sid=[LoginSid],@OriginalSid=[OriginalSid],@Impersonating=[Impersonating],
 @FwUser=[FrameworkUserId],@TargetUser=[TargetUserId],@FwTrigger=[FrameworkTriggerId],
 @PolicyTrigger=[PolicyTriggerId],@ProjectionTrigger=[ProjectionTriggerId] FROM [#FileIOPublicContract_Ownership];
 IF SUSER_SID()<>@OriginalSid THROW 53783,N'Unexpected cleanup security context.',1;
 SET IMPLICIT_TRANSACTIONS OFF;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 IF DB_ID(N'SQLServerAnalyzeFileIOPublicTest') IS NOT NULL AND NOT EXISTS
 (SELECT 1 FROM [master].[sys].[databases] WHERE [database_id]=@Id AND [name]=N'SQLServerAnalyzeFileIOPublicTest' COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
 THROW 53783,N'Owned database identity changed; cleanup stopped.',1;
 DECLARE @OriginalProcedure nvarchar(max),@OriginalProcedureId int;
 SELECT @OriginalProcedure=[ProcedureDefinition],@OriginalProcedureId=[ProcedureId] FROM [#FileIOPublicContract_Ownership];
 IF COALESCE(OBJECT_ID(N'monitor.InternalRunSnapshotFileIOCycle'),-1)<>COALESCE(@OriginalProcedureId,-2)
  THROW 53783,N'Owned source procedure identity changed.',1;
 IF CONVERT(varbinary(max),OBJECT_DEFINITION(@OriginalProcedureId))<>CONVERT(varbinary(max),@OriginalProcedure)
 BEGIN
  SET @OriginalProcedure=REPLACE(@OriginalProcedure COLLATE Latin1_General_100_BIN2,N'CREATE   PROCEDURE [monitor].[InternalRunSnapshotFileIOCycle]',N'CREATE OR ALTER PROCEDURE [monitor].[InternalRunSnapshotFileIOCycle]');
  EXEC [sys].[sp_executesql] @OriginalProcedure;
 END;
 DECLARE @FwCleanup nvarchar(max)=N'
 IF OBJECT_ID(N''[monitor].[ExampleFileIOPublicFrameworkFailure]'') IS NOT NULL
 BEGIN
  IF COALESCE(OBJECT_ID(N''[monitor].[ExampleFileIOPublicFrameworkFailure]''),-1)<>COALESCE(@Trigger,-2) THROW 53783,N''Owned framework trigger identity changed.'',1;
  DROP TRIGGER [monitor].[ExampleFileIOPublicFrameworkFailure];
 END;
 IF DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader'') IS NOT NULL
 BEGIN
  IF COALESCE(DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader''),-1)<>COALESCE(@User,-2)
   OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=@User AND sid=@Sid) THROW 53783,N''Owned framework user identity changed.'',1;
  DROP USER [ExampleFileIOPublicReader];
 END;
 UPDATE [c] SET [TargetDatabaseName]=[b].[TargetDatabaseName],[IsEnabled]=[b].[IsEnabled],
 [DefaultSchedulerType]=[b].[DefaultSchedulerType],[PackageContractVersion]=[b].[PackageContractVersion],
 [SeedVersion]=[b].[SeedVersion],[LastUpdatedUtc]=[b].[LastUpdatedUtc]
 FROM [monitor].[SnapshotTargetConfiguration] AS [c] JOIN [#FileIOPublicContract_Configuration] AS [b] ON [b].[ConfigurationId]=[c].[ConfigurationId];';
 EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] @FwCleanup,N'@Trigger int,@User int,@Sid varbinary(85)',@FwTrigger,@FwUser,@Sid;
 IF DB_ID(N'SQLServerAnalyzeFileIOPublicTest') IS NOT NULL
 BEGIN
  DECLARE @TargetCheck nvarchar(max)=N'
  IF DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader'') IS NOT NULL AND
   (COALESCE(DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader''),-1)<>COALESCE(@User,-2) OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE principal_id=@User AND sid=@Sid)) THROW 53783,N''Owned target user identity changed.'',1;
  IF OBJECT_ID(N''[snapshot].[ExampleFileIOPublicPolicyFailure]'') IS NOT NULL AND COALESCE(OBJECT_ID(N''[snapshot].[ExampleFileIOPublicPolicyFailure]''),-1)<>COALESCE(@Policy,-2) THROW 53783,N''Owned policy trigger identity changed.'',1;
  IF OBJECT_ID(N''[snapshot].[ExampleFileIOPublicProjectionFailure]'') IS NOT NULL AND COALESCE(OBJECT_ID(N''[snapshot].[ExampleFileIOPublicProjectionFailure]''),-1)<>COALESCE(@Projection,-2) THROW 53783,N''Owned projection trigger identity changed.'',1;';
  EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] @TargetCheck,N'@User int,@Sid varbinary(85),@Policy int,@Projection int',@TargetUser,@Sid,@PolicyTrigger,@ProjectionTrigger;
  EXEC [master].[sys].[sp_executesql] N'DROP DATABASE [SQLServerAnalyzeFileIOPublicTest];';
 END;
 IF SUSER_ID(N'ExampleFileIOPublicReader') IS NOT NULL
 BEGIN
  IF @Sid IS NULL OR SUSER_SID(N'ExampleFileIOPublicReader')<>@Sid THROW 53783,N'Owned login identity changed.',1;
  EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleFileIOPublicReader];';
 END;
 IF DB_ID(N'SQLServerAnalyzeFileIOPublicTest') IS NOT NULL OR SUSER_ID(N'ExampleFileIOPublicReader') IS NOT NULL
  THROW 53783,N'Owned cleanup did not establish absence.',1;
END;
GO
-- The canonical installer above runs before framework mutation or impersonation.
-- Installation failures require the dedicated outer Lab-finally; all following phases
-- have this shared recovery boundary and ID/SID-bound cleanup.
BEGIN TRY
    DECLARE @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Run bigint,@Json nvarchar(max),
            @Source nvarchar(max),@Ctx nvarchar(max),@Before nvarchar(max),@After nvarchar(max),@Rc int,
            @OriginalDefinition nvarchar(max),@SpyDefinition nvarchar(max),@FaultDefinition nvarchar(max);
    EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'SQLServerAnalyzeFileIOPublicTest',
      @CollectorCode='FILE_IO',@CollectorEnabled=1,@UpdateSharedPolicy=1,@MaxRows=1,@PayloadEnabled=1,@PrintMeldungen=0,
      @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF COALESCE(@Status,'')<>'AVAILABLE' OR @Error IS NOT NULL OR @@TRANCOUNT<>0
      THROW 53780,N'Public FILE_IO shared configuration failed.',1;
    IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='PERFORMANCE_COUNTERS' AND [MaxRows]=1000)
      THROW 53780,N'FILE_IO configuration overwrote the default collector policy.',1;
    CREATE TABLE [#FileIOPublicContract_Run]([Seed] bit NULL);
    CREATE TABLE [#FileIOPublicContract_Modules]([Seed] bit NULL);
    SELECT [file_id],[sample_ms],[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],[num_of_writes],[num_of_bytes_written],
      [io_stall_write_ms],[size_on_disk_bytes],[file_handle] INTO [#FileIOPublicContract_NativeBefore]
    FROM [sys].[dm_io_virtual_file_stats](DB_ID(),NULL);
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',@RunEvenIfNotDue=1,
      @ResultSetArt='TABLE',@ResultTablesJson=N'{"run":"#FileIOPublicContract_Run","modules":"#FileIOPublicContract_Modules"}',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,
      @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    SELECT [file_id],[sample_ms],[num_of_reads],[num_of_bytes_read],[io_stall_read_ms],[num_of_writes],[num_of_bytes_written],
      [io_stall_write_ms],[size_on_disk_bytes],[file_handle] INTO [#FileIOPublicContract_NativeAfter]
    FROM [sys].[dm_io_virtual_file_stats](DB_ID(),NULL);
    IF COALESCE(@Status,'')<>'PARTIAL' OR @Partial<>1 OR @Error IS NOT NULL OR @Run IS NULL OR COALESCE(ISJSON(@Json),0)<>1
      OR (SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_Run])<>1 OR JSON_VALUE(@Json,N'$.run.MetricSampleCount')<>N'10'
      THROW 53780,N'Native FILE_IO TABLE and JSON capture failed.',1;
    IF CONVERT(varbinary(max),(SELECT * FROM [#FileIOPublicContract_Run] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES))
       <>CONVERT(varbinary(max),JSON_QUERY(@Json,N'$.run'))
      OR CONVERT(varbinary(max),(SELECT * FROM [#FileIOPublicContract_Modules] ORDER BY [ModuleStatusId] FOR JSON PATH,INCLUDE_NULL_VALUES))
       <>CONVERT(varbinary(max),JSON_QUERY(@Json,N'$.modules'))
      THROW 53780,N'FILE_IO TABLE and JSON projections differ.',1;
    SELECT @Source=CONVERT(nvarchar(max),DECOMPRESS([Payload])) FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@Run;
    SELECT @Ctx=[s].[StringValue] FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricSample] [s]
      JOIN [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[s].[MetricDefinitionId]
      WHERE [s].[CaptureRunId]=@Run AND [d].[MetricCode]='IO_CAPTURE_CONTEXT';
    IF JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'SUCCEEDED' OR JSON_VALUE(@Source,N'$.meta.sourceComplete')<>'true'
      OR TRY_CONVERT(bigint,JSON_VALUE(@Source,N'$.meta.selectedNativeRows'))<>(SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_NativeBefore])
      OR TRY_CONVERT(bigint,JSON_VALUE(@Source,N'$.meta.selectedNativeRows'))<=1
      OR JSON_VALUE(@Ctx,N'$.capture.writtenFileCount')<>N'1' OR JSON_VALUE(@Ctx,N'$.capture.writeLimited')<>'true'
      OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Source,N'$.files'))<>(SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_NativeBefore])
      THROW 53780,N'MaxRows limited the native source instead of only backend writes.',1;
    IF EXISTS(SELECT [FileId] FROM OPENJSON(@Source,N'$.files') WITH([FileId] int)
              EXCEPT SELECT [file_id] FROM [#FileIOPublicContract_NativeBefore])
      OR EXISTS(SELECT [file_id] FROM [#FileIOPublicContract_NativeBefore]
              EXCEPT SELECT [FileId] FROM OPENJSON(@Source,N'$.files') WITH([FileId] int))
      OR EXISTS(SELECT [file_id] FROM [#FileIOPublicContract_NativeBefore]
              EXCEPT SELECT [file_id] FROM [#FileIOPublicContract_NativeAfter])
      OR EXISTS(SELECT [file_id] FROM [#FileIOPublicContract_NativeAfter]
              EXCEPT SELECT [file_id] FROM [#FileIOPublicContract_NativeBefore])
      THROW 53780,N'Independent native file ID sets differ.',1;
    DECLARE @ShiftedSource nvarchar(max)=JSON_MODIFY(@Source,N'$.files[0].FileId',
      TRY_CONVERT(int,JSON_VALUE(@Source,N'$.files[0].FileId'))+100000);
    IF NOT EXISTS(SELECT [FileId] FROM OPENJSON(@ShiftedSource,N'$.files') WITH([FileId] int)
                 EXCEPT SELECT [file_id] FROM [#FileIOPublicContract_NativeBefore])
      THROW 53780,N'The independent file-set oracle accepted a same-count shifted file ID.',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@Source,N'$.files') WITH
      ([FileId] int,[Reads] bigint,[ReadBytes] bigint,[ReadStallMs] bigint,[Writes] bigint,[WriteBytes] bigint,[WriteStallMs] bigint,[SizeOnDiskBytes] bigint,[SampleMs] bigint,[FileHandle] varchar(18)) [f]
      JOIN [#FileIOPublicContract_NativeBefore] [b] ON [b].[file_id]=[f].[FileId]
      JOIN [#FileIOPublicContract_NativeAfter] [a] ON [a].[file_id]=[f].[FileId]
      WHERE [f].[Reads] NOT BETWEEN [b].[num_of_reads] AND [a].[num_of_reads]
       OR [f].[ReadBytes] NOT BETWEEN [b].[num_of_bytes_read] AND [a].[num_of_bytes_read]
       OR [f].[ReadStallMs] NOT BETWEEN [b].[io_stall_read_ms] AND [a].[io_stall_read_ms]
       OR [f].[Writes] NOT BETWEEN [b].[num_of_writes] AND [a].[num_of_writes]
       OR [f].[WriteBytes] NOT BETWEEN [b].[num_of_bytes_written] AND [a].[num_of_bytes_written]
       OR [f].[WriteStallMs] NOT BETWEEN [b].[io_stall_write_ms] AND [a].[io_stall_write_ms]
       OR [f].[SampleMs] NOT BETWEEN [b].[sample_ms] AND [a].[sample_ms]
       OR [f].[SizeOnDiskBytes]<>[b].[size_on_disk_bytes] OR [f].[SizeOnDiskBytes]<>[a].[size_on_disk_bytes]
       OR CONVERT(varbinary(8),[f].[FileHandle],1)<>[b].[file_handle] OR CONVERT(varbinary(8),[f].[FileHandle],1)<>[a].[file_handle])
      THROW 53780,N'Independent native seven-value, handle or uptime bounds failed in the owned stable fixture.',1;
    IF (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricSample] [m]
      JOIN [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[m].[MetricDefinitionId]
      JOIN [SQLServerAnalyzeFileIOPublicTest].[snapshot].[Scope] [sc] ON [sc].[ScopeId]=[m].[ScopeId]
      CROSS APPLY OPENJSON(@Source,N'$.files') WITH ([FileId] int,[Reads] bigint,[ReadBytes] bigint,[ReadStallMs] bigint,[Writes] bigint,[WriteBytes] bigint,[WriteStallMs] bigint,[SizeOnDiskBytes] bigint) [f]
      CROSS APPLY(VALUES('IO_READ_COUNT',[f].[Reads]),('IO_READ_BYTES',[f].[ReadBytes]),('IO_READ_STALL_MS',[f].[ReadStallMs]),
       ('IO_WRITE_COUNT',[f].[Writes]),('IO_WRITE_BYTES',[f].[WriteBytes]),('IO_WRITE_STALL_MS',[f].[WriteStallMs]),('IO_SIZE_ON_DISK_BYTES',[f].[SizeOnDiskBytes])) [v]([Code],[Value])
      WHERE [m].[CaptureRunId]=@Run AND [d].[MetricCode]=[v].[Code] AND [m].[BigintValue]=[v].[Value]
       AND JSON_VALUE([sc].[ScopeIdentityJson],N'$.file.FileId')=CONVERT(nvarchar(20),[f].[FileId]))<>7
      THROW 53780,N'Persisted seven raw values differ from the actual native source frame.',1;
    DECLARE @Runs bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CaptureRun]);
    EXEC @Rc=[monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='WAIT_STATS',@DatabaseNames=N'ExampleDatabase',@ResultSetArt='NONE',@PrintMeldungen=0,
      @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF @Rc<>51011 OR @Status<>'INVALID_PARAMETER' OR @Error<>51011
      OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CaptureRun])<>@Runs
      THROW 53780,N'Foreign collector silently accepted FILE_IO filters.',1;
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',
      @ResultSetArt='NONE',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@CaptureRunIdOut=@Run OUTPUT;
    IF @Status<>'SKIPPED_NOT_DUE' OR @Run IS NOT NULL THROW 53780,N'FILE_IO interval admission failed.',1;
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNamePattern=N'LIKE:ExampleAbsentFileIO%',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@CaptureRunIdOut=@Run OUTPUT;
    SELECT @Source=CONVERT(nvarchar(max),DECOMPRESS([Payload])) FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@Run;
    IF @Status<>'PARTIAL' OR JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'NOT_STARTED'
      OR JSON_VALUE(@Source,N'$.meta.selectedNativeRows')<>N'0' OR JSON_QUERY(@Source,N'$.files')<>N'[]'
      THROW 53780,N'Empty native selection invented a read or unknown amount.',1;
    -- A local spy observes the unchanged source frame after completion. Controlled
    -- engine/future-start faults remain synthetic and never change the host clock.
    SELECT @OriginalDefinition=[ProcedureDefinition] FROM [#FileIOPublicContract_Ownership];
    SET @SpyDefinition=REPLACE(@OriginalDefinition COLLATE Latin1_General_100_BIN2,N'CREATE   PROCEDURE [monitor].[InternalRunSnapshotFileIOCycle]',N'CREATE OR ALTER PROCEDURE [monitor].[InternalRunSnapshotFileIOCycle]');
    IF CHARINDEX(N'        SET @CompletionReturned=1;',@SpyDefinition)=0 THROW 53780,N'Native spy binding changed.',1;
    SET @SpyDefinition=REPLACE(@SpyDefinition COLLATE Latin1_General_100_BIN2,N'        SET @CompletionReturned=1;',N'        INSERT [#FileIOPublicContract_SourceFrames]([SourceJson]) VALUES(@SourceJson);'+NCHAR(10)+N'        SET @CompletionReturned=1;');
    SET @FaultDefinition=REPLACE(@SpyDefinition COLLATE Latin1_General_100_BIN2,N'IF @@ROWCOUNT<>1 OR @AfterName IS NULL',N'IF 1=1 OR @AfterName IS NULL');
    IF @FaultDefinition=@SpyDefinition THROW 53780,N'Engine fault binding changed.',1;
    EXEC [sys].[sp_executesql] @FaultDefinition;
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    SET @Source=NULL;
    IF (SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_SourceFrames])<>1 THROW 53780,N'Native spy must observe exactly one actual source frame.',1;
    SELECT @Source=[SourceJson] FROM [#FileIOPublicContract_SourceFrames];
    IF @Status<>'ERROR_HANDLED' OR @Error IS NOT NULL OR JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'SUCCEEDED'
      OR TRY_CONVERT(bigint,JSON_VALUE(@Source,N'$.meta.selectedNativeRows'))<=1 OR JSON_QUERY(@Source,N'$.files')<>N'[]'
      OR JSON_VALUE(@Source,N'$.meta.engine') IS NOT NULL
      OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run)
      THROW 53780,N'Late binding failure lost the successful native read or invented numerical evidence.',1;
    DELETE [#FileIOPublicContract_SourceFrames];
    EXEC [sys].[sp_executesql] @SpyDefinition;
    EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] N'CREATE TRIGGER [snapshot].[ExampleFileIOPublicProjectionFailure]
ON [snapshot].[CaptureRun] AFTER INSERT AS
UPDATE [r] SET [StartedAtUtc]=DATEADD(hour,1,SYSUTCDATETIME()) FROM [snapshot].[CaptureRun] [r]
JOIN [inserted] [i] ON [i].[CaptureRunId]=[r].[CaptureRunId] WHERE [r].[CollectorCode]=''FILE_IO'';';
    UPDATE [#FileIOPublicContract_Ownership] SET [ProjectionTriggerId]=(SELECT [object_id] FROM [SQLServerAnalyzeFileIOPublicTest].[sys].[triggers] WHERE [name]=N'ExampleFileIOPublicProjectionFailure');
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,
      @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    SET @Source=NULL;
    IF (SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_SourceFrames])<>1 THROW 53780,N'Native spy must observe exactly one actual source frame.',1;
    SELECT @Source=[SourceJson] FROM [#FileIOPublicContract_SourceFrames];
    IF @Status<>'FINALIZATION_UNCONFIRMED' OR @Run IS NULL OR @Error IS NOT NULL
      OR JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'SUCCEEDED' OR TRY_CONVERT(bigint,JSON_VALUE(@Source,N'$.meta.selectedNativeRows'))<=1
      OR JSON_VALUE(@Source,N'$.meta.measurementStartUtc') IS NOT NULL OR JSON_VALUE(@Source,N'$.meta.measurementEndUtc') IS NOT NULL
      OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run
        AND [EndedAtUtc] IS NULL AND [StatusCode]='ERROR_HANDLED' AND [MetricSampleCount]=0 AND [PayloadCount]=0)
      OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run
        AND [ModuleName]=N'FileIOFinalizationBoundary' AND [StatusCode]='FINALIZATION_UNCONFIRMED' AND [ErrorNumber] IS NULL)
      OR JSON_VALUE(@Json,N'$.run.EndedAtUtc') IS NOT NULL OR JSON_VALUE(@Json,N'$.run.StatusCode')<>N'ERROR_HANDLED'
      THROW 53780,N'Synthetic future start invented a finalization or lost the actual successful native read.',1;
    IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[sys].[triggers] WHERE [object_id]=(SELECT [ProjectionTriggerId] FROM [#FileIOPublicContract_Ownership]) AND [name]=N'ExampleFileIOPublicProjectionFailure')
      THROW 53783,N'Owned clock fixture identity changed.',1;
    EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] N'DROP TRIGGER [snapshot].[ExampleFileIOPublicProjectionFailure];';
    UPDATE [#FileIOPublicContract_Ownership] SET [ProjectionTriggerId]=NULL;
    DELETE [#FileIOPublicContract_SourceFrames];
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'PARTIAL' OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricSample] [m]
      JOIN [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricDefinition] [d] ON [d].[MetricDefinitionId]=[m].[MetricDefinitionId]
      WHERE [m].[CaptureRunId]=@Run AND [d].[MetricCode]='IO_DELTA_STATUS'
        AND [m].[StringValue] NOT IN(N'PREVIOUS_CAPTURE_UNCONFIRMED',N'CURRENT_IDENTITY_INCOMPLETE'))
      THROW 53780,N'Healthy native capture skipped the unconfirmed predecessor fence.',1;
    DELETE [#FileIOPublicContract_SourceFrames];
    EXEC [master].[sys].[sp_executesql] N'DECLARE @Secret nvarchar(128)=CONVERT(nvarchar(36),NEWID())+N''aA!9'';
DECLARE @CreateLogin nvarchar(max)=N''CREATE LOGIN [ExampleFileIOPublicReader] WITH PASSWORD=''+QUOTENAME(@Secret,NCHAR(39))+N'',CHECK_POLICY=OFF;'';
EXEC [sys].[sp_executesql] @CreateLogin;
UPDATE [#FileIOPublicContract_Ownership] SET [LoginSid]=SUSER_SID(N''ExampleFileIOPublicReader'');';
    EXEC [SQLServerAnalyzeTest].[sys].[sp_executesql] N'CREATE USER [ExampleFileIOPublicReader] FOR LOGIN [ExampleFileIOPublicReader];
UPDATE [#FileIOPublicContract_Ownership] SET [FrameworkUserId]=DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader'');
GRANT EXECUTE ON SCHEMA::[monitor] TO [ExampleFileIOPublicReader];
GRANT SELECT ON SCHEMA::[monitor] TO [ExampleFileIOPublicReader];';
    EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] N'CREATE USER [ExampleFileIOPublicReader] FOR LOGIN [ExampleFileIOPublicReader];
UPDATE [#FileIOPublicContract_Ownership] SET [TargetUserId]=DATABASE_PRINCIPAL_ID(N''ExampleFileIOPublicReader'');
GRANT EXECUTE ON SCHEMA::[snapshot] TO [ExampleFileIOPublicReader];
GRANT SELECT ON SCHEMA::[snapshot] TO [ExampleFileIOPublicReader];';
    UPDATE [#FileIOPublicContract_Ownership] SET [Impersonating]=1;
    EXECUTE AS LOGIN=N'ExampleFileIOPublicReader';
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    REVERT;
    UPDATE [#FileIOPublicContract_Ownership] SET [Impersonating]=0;
    SET @Source=NULL;
    IF (SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_SourceFrames])<>1 THROW 53780,N'Native spy must observe exactly one actual source frame.',1;
    SELECT @Source=[SourceJson] FROM [#FileIOPublicContract_SourceFrames];
    IF @Status<>'DENIED_PERMISSION' OR @Error IS NULL OR @Run IS NULL
      OR JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'NOT_STARTED' OR JSON_VALUE(@Source,N'$.meta.selectedNativeRows') IS NOT NULL
      OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND [EndedAtUtc] IS NOT NULL AND [MetricSampleCount]=0)
      THROW 53780,N'Native engine denial fabricated a VFS attempt or an observed zero amount.',1;
    EXEC [master].[sys].[sp_executesql] N'IF CONVERT(int,SERVERPROPERTY(''ProductMajorVersion''))>=16
 EXEC(N''GRANT VIEW SERVER PERFORMANCE STATE TO [ExampleFileIOPublicReader];'');
ELSE GRANT VIEW SERVER STATE TO [ExampleFileIOPublicReader];';
    DELETE [#FileIOPublicContract_SourceFrames];
    -- Both module writes fail in the target. A separate column denial allows the
    -- actual start binding but denies the later complete run projection.
    EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] N'CREATE TRIGGER [snapshot].[ExampleFileIOPublicPolicyFailure]
ON [snapshot].[ModuleStatus] AFTER INSERT AS
THROW 53791,N''Example secondary module write failure with original complete diagnosis.'',1;';
    UPDATE [#FileIOPublicContract_Ownership] SET [PolicyTriggerId]=(SELECT [object_id] FROM [SQLServerAnalyzeFileIOPublicTest].[sys].[triggers] WHERE [name]=N'ExampleFileIOPublicPolicyFailure');
    EXEC [SQLServerAnalyzeFileIOPublicTest].[sys].[sp_executesql] N'DENY SELECT ON OBJECT::[snapshot].[CaptureRun]([MetricSampleCount]) TO [ExampleFileIOPublicReader];';
    UPDATE [#FileIOPublicContract_Ownership] SET [Impersonating]=1;
    EXECUTE AS LOGIN=N'ExampleFileIOPublicReader';
    EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='FILE_IO',@DatabaseNames=N'SQLServerAnalyzeTest|ExampleAbsentFileIODatabase',@RunEvenIfNotDue=1,
      @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run OUTPUT,
      @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    REVERT;
    UPDATE [#FileIOPublicContract_Ownership] SET [Impersonating]=0;
    SET @Source=NULL;
    IF (SELECT COUNT_BIG(*) FROM [#FileIOPublicContract_SourceFrames])<>1 THROW 53780,N'Native spy must observe exactly one actual source frame.',1;
    SELECT @Source=[SourceJson] FROM [#FileIOPublicContract_SourceFrames];
    IF @Status<>'FINALIZATION_UNCONFIRMED' OR @Run IS NULL OR @Error<>53791
      OR @Message<>N'Example secondary module write failure with original complete diagnosis.'
      OR COALESCE(JSON_QUERY(@Json,N'$.run'),N'!')<>N'{}'
      OR JSON_VALUE(@Source,N'$.meta.nativeReadState')<>'SUCCEEDED' OR JSON_VALUE(@Source,N'$.meta.errorNumber') IS NOT NULL
      OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.modules') WITH([ModuleStatusId] bigint,[ModuleName] sysname,[ErrorNumber] int) [m]
        WHERE [m].[ModuleStatusId] IS NULL AND [m].[ModuleName]=N'monitor.InternalRunSnapshotFileIOCycle' AND [m].[ErrorNumber]=53791)
      OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.modules') WITH([ModuleStatusId] bigint,[ModuleName] sysname,[ErrorNumber] int) [m]
        WHERE [m].[ModuleStatusId] IS NULL AND [m].[ModuleName]=N'DATABASE_SELECTION' AND [m].[ErrorNumber] IS NULL)
      OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run
        AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING' AND [MetricSampleCount]=0 AND [PayloadCount]=0)
      OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run)
      OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeFileIOPublicTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run)
      THROW 53780,N'Combined secondary-write/readback denial lost the real output exception or fabricated persisted data.',1;
    EXEC [#FileIOPublicContract_Cleanup];
END TRY
BEGIN CATCH
    DECLARE @OriginalError int=ERROR_NUMBER(),@OriginalLine int=ERROR_LINE(),@OriginalMessage nvarchar(2048)=ERROR_MESSAGE();
    IF SUSER_SID()=(SELECT [LoginSid] FROM [#FileIOPublicContract_Ownership]) REVERT;
    BEGIN TRY
        EXEC [#FileIOPublicContract_Cleanup];
    END TRY
    BEGIN CATCH
        DECLARE @CleanupMessage nvarchar(2048)=CONCAT(N'Original failure ',@OriginalError,N' line ',@OriginalLine,N': ',@OriginalMessage,
          N' Cleanup failure ',ERROR_NUMBER(),N': ',ERROR_MESSAGE());
        THROW 53783,@CleanupMessage,1;
    END CATCH;
    THROW;
END CATCH;
PRINT N'SC023_FILE_IO_PUBLIC_RUNTIME_CONTRACT PASS';
GO
