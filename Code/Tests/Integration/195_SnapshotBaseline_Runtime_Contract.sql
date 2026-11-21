/*
===============================================================================
Datei        : 195_SnapshotBaseline_Runtime_Contract.sql
Zweck        : Prüft SC-023 isoliert mit ausschließlich synthetischen Namen.
Ausführung   : sqlcmd-Arbeitsverzeichnis Code/Install; Core ist installiert,
               SQLServerAnalyzeSnapshotTest ist leer und explizit angelegt.
Datenschutz  : Keine Laufzeitwerte werden ausgegeben oder in Artefakte kopiert.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE [#SnapshotBaselineRuntimeContract_State]
(
      [StateName] varchar(40) NOT NULL PRIMARY KEY
    , [BigintValue] bigint NULL
    , [GuidValue] uniqueidentifier NULL
);

USE [SQLServerAnalyzeTest];
GO

IF EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor' AND [t].[name]=N'SnapshotTargetConfiguration'
)
    THROW 53720,N'SC023_CORE_STATELESS_CONTRACT',1;
GO

USE [SQLServerAnalyzeSnapshotTest];
GO
:r Install_SnapshotBaseline_Target.sql

USE [SQLServerAnalyzeTest];
GO
:r Install_SnapshotBaseline_Framework.sql

USE [SQLServerAnalyzeSnapshotTest];
GO
:r ../Tests/Integration/230_Usage_Skills_Target_Runtime_Contract.sql


-- Das eigene isolierte Target qualifiziert die vollständige alte und neue
-- 1.3.1-Helfersignatur sowie vier unvollständige Hilfesignaturen. Die alten
-- 1.2.1-/1.3.0-Routen bleiben zusätzlich in der Frozen-Release-Fixture gebunden.
USE [SQLServerAnalyzeSnapshotTest];
GO
DECLARE @OwnDbId int=DB_ID(),@OwnDbName sysname=DB_NAME(),@OriginalCount int,
        @Case int,@Method int,@Definition nvarchar(max),@Executable nvarchar(max),
        @Mutated nvarchar(max),@RestoreSql nvarchar(max),@Name sysname,
        @ObjectId int,@HelpLine nvarchar(80)=N'    , @Hilfe bit = 0'+NCHAR(10),
        @AsLine nvarchar(20)=N'AS'+NCHAR(10)+N'BEGIN'+NCHAR(10),
        @OldHeader nvarchar(40)=N'CREATE   PROCEDURE',
        @NewHeader nvarchar(40)=N'CREATE OR ALTER PROCEDURE',
        @AdmissionId int,@AdmissionDate datetime,@AdmissionStatus varchar(40),
        @AdmissionError int,@AdmissionMessage nvarchar(2048),@OriginalError int,
        @CleanupError int,@DiagnosticOriginal int,@DiagnosticCleanup int,
        @OriginalOptions int=@@OPTIONS,
        @ScopedDdl nvarchar(max)=N'USE [SQLServerAnalyzeSnapshotTest]; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; EXEC [sys].[sp_executesql] @InnerSql;';
DECLARE @Originals TABLE
(
      [Sequence] int NOT NULL PRIMARY KEY
    , [MethodName] sysname NOT NULL UNIQUE
    , [ObjectId] int NOT NULL
    , [Definition] nvarchar(max) NOT NULL
    , [StoredHeader] nvarchar(40) NOT NULL
    , [HeaderPos] int NOT NULL
    , [RestoreSql] nvarchar(max) NOT NULL
    , [DefinitionHash] varbinary(32) NOT NULL
    , [IsDirty] bit NOT NULL DEFAULT 0
);
IF @OwnDbId IS NULL OR CONVERT(varbinary(max),@OwnDbName)<>CONVERT(varbinary(max),N'SQLServerAnalyzeSnapshotTest')
   OR @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0
       THROW 53800,N'SC023_HELP_PROFILE_OWN_CONTEXT_INVALID',1;
INSERT @Originals([Sequence],[MethodName],[ObjectId],[Definition],[StoredHeader],[HeaderPos],[RestoreSql],[DefinitionHash])
SELECT [v].[Sequence],[v].[MethodName],[p].[object_id],[m].[definition],
       CASE WHEN [h].[OldPos]>0 THEN @OldHeader ELSE @NewHeader END,
       CASE WHEN [h].[OldPos]>0 THEN [h].[OldPos] ELSE [h].[NewPos] END,
       CASE WHEN [h].[OldPos]>0
            THEN STUFF([m].[definition],[h].[OldPos],LEN(@OldHeader),@NewHeader)
            ELSE [m].[definition] END,
       HASHBYTES('SHA2_256',CONVERT(varbinary(max),[m].[definition]))
FROM (VALUES
    (1,N'InternalConfigureSnapshotPolicy'),
    (2,N'InternalPrepareCollectionCycle'),
    (3,N'InternalCompleteWaitStatsCycle'),
    (4,N'InternalPurgeExpiredData')
) AS [v]([Sequence],[MethodName])
JOIN [sys].[schemas] AS [s] ON [s].[name]=N'snapshot'
JOIN [sys].[procedures] AS [p] ON [p].[schema_id]=[s].[schema_id] AND [p].[name]=[v].[MethodName]
JOIN [sys].[sql_modules] AS [m] ON [m].[object_id]=[p].[object_id]
CROSS APPLY
(
    SELECT CHARINDEX(@OldHeader+N' [snapshot].'+QUOTENAME([v].[MethodName]),[m].[definition]) AS [OldPos],
           CHARINDEX(@NewHeader+N' [snapshot].'+QUOTENAME([v].[MethodName]),[m].[definition]) AS [NewPos]
) AS [h]
WHERE [m].[uses_ansi_nulls]=1 AND [m].[uses_quoted_identifier]=1
  AND (([h].[OldPos]>0 AND [h].[NewPos]=0) OR ([h].[NewPos]>0 AND [h].[OldPos]=0));
SELECT @OriginalCount=COUNT(*) FROM @Originals;
IF @OriginalCount<>4 OR EXISTS
(
    SELECT 1 FROM @Originals
    WHERE [HeaderPos]<1
       OR SUBSTRING([Definition],[HeaderPos],LEN([StoredHeader]+N' [snapshot].'+QUOTENAME([MethodName])))
            COLLATE SQL_Latin1_General_CP1_CS_AS
          <>[StoredHeader]+N' [snapshot].'+QUOTENAME([MethodName])
       OR ([HeaderPos]<>1 AND
           SUBSTRING([Definition],[HeaderPos]-LEN(N'-- USAGE_SKILL_END snapshot.'+[MethodName]+NCHAR(10)),
                     LEN(N'-- USAGE_SKILL_END snapshot.'+[MethodName]+NCHAR(10)))
              COLLATE SQL_Latin1_General_CP1_CS_AS
           <>N'-- USAGE_SKILL_END snapshot.'+[MethodName]+NCHAR(10))
       OR CHARINDEX(@OldHeader+N' [snapshot].'+QUOTENAME([MethodName]),
                     [Definition],[HeaderPos]+1)>0
       OR CHARINDEX(@NewHeader+N' [snapshot].'+QUOTENAME([MethodName]),
                     [Definition],[HeaderPos]+1)>0
       OR STUFF([RestoreSql],[HeaderPos],LEN(@NewHeader),[StoredHeader])
              COLLATE SQL_Latin1_General_CP1_CS_AS
          <>[Definition] COLLATE SQL_Latin1_General_CP1_CS_AS
       OR DATALENGTH(STUFF([RestoreSql],[HeaderPos],LEN(@NewHeader),[StoredHeader]))
          <>DATALENGTH([Definition])
       OR LEN([Definition])-LEN(REPLACE([Definition],@HelpLine,N''))<>LEN(@HelpLine)
       OR LEN([Definition])-LEN(REPLACE([Definition],@AsLine,N''))<>LEN(@AsLine)
)
    THROW 53801,N'SC023_HELP_PROFILE_ORIGINAL_BINDING_INVALID',1;
EXEC [SQLServerAnalyzeTest].[monitor].[InternalValidateSnapshotWaitTarget]
     @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',
     @TargetDatabaseIdOut=@AdmissionId OUTPUT,@TargetCreateDateOut=@AdmissionDate OUTPUT,
     @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,
     @ErrorMessageOut=@AdmissionMessage OUTPUT;
IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL OR COALESCE(@AdmissionId,-1)<>@OwnDbId
    THROW 53802,N'SC023_HELP_PROFILE_NEW_POSITIVE_FAILED',1;
BEGIN TRY
    -- Alle vier alten Signaturen gemeinsam: kein gemischtes Profil.
    SET @Method=1;
    WHILE @Method<=4
    BEGIN
        SELECT @Name=[MethodName],@ObjectId=[ObjectId],@Executable=[RestoreSql]
        FROM @Originals WHERE [Sequence]=@Method;
        IF COALESCE(DB_ID(),-1)<>@OwnDbId OR COALESCE(OBJECT_ID(N'[snapshot].'+QUOTENAME(@Name),N'P'),-1)<>@ObjectId
            THROW 53803,N'SC023_HELP_PROFILE_OWNERSHIP_CHANGED',1;
        SET @Mutated=REPLACE(@Executable,@HelpLine,N'');
        SET @Mutated=REPLACE(@Mutated,@AsLine,@AsLine+N'    DECLARE @Hilfe bit=0;'+NCHAR(10));
        UPDATE @Originals SET [IsDirty]=1 WHERE [Sequence]=@Method;
        EXEC [sys].[sp_executesql] @ScopedDdl,N'@InnerSql nvarchar(max)',@InnerSql=@Mutated;
        SET @Method+=1;
    END;
    SELECT @AdmissionId=NULL,@AdmissionDate=NULL,@AdmissionStatus=NULL,
           @AdmissionError=NULL,@AdmissionMessage=NULL;
    EXEC [SQLServerAnalyzeTest].[monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',
         @TargetDatabaseIdOut=@AdmissionId OUTPUT,@TargetCreateDateOut=@AdmissionDate OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,
         @ErrorMessageOut=@AdmissionMessage OUTPUT;
    IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL OR COALESCE(@AdmissionId,-1)<>@OwnDbId
        THROW 53804,N'SC023_HELP_PROFILE_OLD_POSITIVE_FAILED',1;
    SET @Method=4;
    WHILE @Method>=1
    BEGIN
        SELECT @Name=[MethodName],@ObjectId=[ObjectId],@RestoreSql=[RestoreSql]
        FROM @Originals WHERE [Sequence]=@Method;
        IF COALESCE(DB_ID(),-1)<>@OwnDbId OR COALESCE(OBJECT_ID(N'[snapshot].'+QUOTENAME(@Name),N'P'),-1)<>@ObjectId
            THROW 53803,N'SC023_HELP_PROFILE_OWNERSHIP_CHANGED',1;
        EXEC [sys].[sp_executesql] @ScopedDdl,N'@InnerSql nvarchar(max)',@InnerSql=@RestoreSql;
        IF NOT EXISTS
        (
            SELECT 1 FROM [sys].[sql_modules] AS [m]
            WHERE [m].[object_id]=@ObjectId
              AND [m].[uses_ansi_nulls]=1 AND [m].[uses_quoted_identifier]=1
              AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[m].[definition]))
                  =(SELECT [DefinitionHash] FROM @Originals WHERE [Sequence]=@Method)
              AND DATALENGTH([m].[definition])
                  =(SELECT DATALENGTH([Definition]) FROM @Originals WHERE [Sequence]=@Method)
        )
            THROW 53805,N'SC023_HELP_PROFILE_RESTORE_MISMATCH',1;
        UPDATE @Originals SET [IsDirty]=0 WHERE [Sequence]=@Method;
        SET @Method-=1;
    END;
    -- Jeweils nur der gebundene eigene Purge-Helper wird kurzfristig geändert.
    SET @Case=1;
    WHILE @Case<=4
    BEGIN
        SELECT @Name=[MethodName],@ObjectId=[ObjectId],@Executable=[RestoreSql],
               @RestoreSql=[RestoreSql]
        FROM @Originals WHERE [Sequence]=4;
        IF COALESCE(DB_ID(),-1)<>@OwnDbId OR COALESCE(OBJECT_ID(N'[snapshot].'+QUOTENAME(@Name),N'P'),-1)<>@ObjectId
            THROW 53803,N'SC023_HELP_PROFILE_OWNERSHIP_CHANGED',1;
        SET @Mutated=CASE @Case
            WHEN 1 THEN REPLACE(REPLACE(@Executable,@HelpLine,N''),
                       @AsLine,@AsLine+N'    DECLARE @Hilfe bit=0;'+NCHAR(10))
            WHEN 2 THEN REPLACE(@Executable,@HelpLine,N'    , @Hilfe int = 0'+NCHAR(10))
            WHEN 3 THEN REPLACE(@Executable,
                       N'    , @ExpectedTargetCreateDate datetime = NULL'+NCHAR(10)+@HelpLine,
                       N'    , @Hilfe bit = 0'+NCHAR(10)
                        +N'    , @ExpectedTargetCreateDate datetime = NULL'+NCHAR(10))
            WHEN 4 THEN REPLACE(@Executable,@HelpLine,N'    , @Hilfe bit = 0 OUTPUT'+NCHAR(10))
            END;
        IF @Mutated=@Executable
            THROW 53806,N'SC023_HELP_PROFILE_MUTATION_MARKER_MISSING',1;
        UPDATE @Originals SET [IsDirty]=1 WHERE [Sequence]=4;
        EXEC [sys].[sp_executesql] @ScopedDdl,N'@InnerSql nvarchar(max)',@InnerSql=@Mutated;
        SELECT @AdmissionId=NULL,@AdmissionDate=NULL,@AdmissionStatus=NULL,
               @AdmissionError=NULL,@AdmissionMessage=NULL;
        EXEC [SQLServerAnalyzeTest].[monitor].[InternalValidateSnapshotWaitTarget]
             @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',
             @TargetDatabaseIdOut=@AdmissionId OUTPUT,@TargetCreateDateOut=@AdmissionDate OUTPUT,
             @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,
             @ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'TARGET_UNAVAILABLE' OR COALESCE(@AdmissionError,-1)<>53762
            THROW 53807,N'SC023_HELP_PROFILE_NEGATIVE_NOT_REJECTED',1;
        IF COALESCE(DB_ID(),-1)<>@OwnDbId OR COALESCE(OBJECT_ID(N'[snapshot].'+QUOTENAME(@Name),N'P'),-1)<>@ObjectId
            THROW 53803,N'SC023_HELP_PROFILE_OWNERSHIP_CHANGED',1;
        EXEC [sys].[sp_executesql] @ScopedDdl,N'@InnerSql nvarchar(max)',@InnerSql=@RestoreSql;
        IF NOT EXISTS
        (
            SELECT 1 FROM [sys].[sql_modules] AS [m]
            WHERE [m].[object_id]=@ObjectId
              AND [m].[uses_ansi_nulls]=1 AND [m].[uses_quoted_identifier]=1
              AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[m].[definition]))
                  =(SELECT [DefinitionHash] FROM @Originals WHERE [Sequence]=4)
              AND DATALENGTH([m].[definition])
                  =(SELECT DATALENGTH([Definition]) FROM @Originals WHERE [Sequence]=4)
        )
            THROW 53805,N'SC023_HELP_PROFILE_RESTORE_MISMATCH',1;
        UPDATE @Originals SET [IsDirty]=0 WHERE [Sequence]=4;
        SET @Case+=1;
    END;
END TRY
BEGIN CATCH
    SET @OriginalError=ERROR_NUMBER();
    SET @Method=4;
    WHILE @Method>=1
    BEGIN
        IF EXISTS(SELECT 1 FROM @Originals WHERE [Sequence]=@Method AND [IsDirty]=1)
        BEGIN
            SELECT @Name=[MethodName],@ObjectId=[ObjectId],@RestoreSql=[RestoreSql]
            FROM @Originals WHERE [Sequence]=@Method;
            BEGIN TRY
                IF COALESCE(DB_ID(),-1)<>@OwnDbId OR COALESCE(OBJECT_ID(N'[snapshot].'+QUOTENAME(@Name),N'P'),-1)<>@ObjectId
                    THROW 53803,N'SC023_HELP_PROFILE_OWNERSHIP_CHANGED',1;
                EXEC [sys].[sp_executesql] @ScopedDdl,N'@InnerSql nvarchar(max)',@InnerSql=@RestoreSql;
                IF NOT EXISTS
                (
                    SELECT 1 FROM [sys].[sql_modules] AS [m]
                    WHERE [m].[object_id]=@ObjectId
                      AND [m].[uses_ansi_nulls]=1 AND [m].[uses_quoted_identifier]=1
                      AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[m].[definition]))
                          =(SELECT [DefinitionHash] FROM @Originals WHERE [Sequence]=@Method)
                      AND DATALENGTH([m].[definition])
                          =(SELECT DATALENGTH([Definition]) FROM @Originals WHERE [Sequence]=@Method)
                )
                    THROW 53805,N'SC023_HELP_PROFILE_RESTORE_MISMATCH',1;
                UPDATE @Originals SET [IsDirty]=0 WHERE [Sequence]=@Method;
            END TRY
            BEGIN CATCH
                SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());
            END CATCH;
        END;
        SET @Method-=1;
    END;
    IF @@OPTIONS<>@OriginalOptions
        SET @CleanupError=COALESCE(@CleanupError,53811);
    IF @CleanupError IS NOT NULL
    BEGIN
        SELECT @DiagnosticOriginal=@OriginalError,@DiagnosticCleanup=@CleanupError;
        RAISERROR(N'SC023_HELP_PROFILE_FAILURE original=%d cleanup=%d',16,1,
                  @DiagnosticOriginal,@DiagnosticCleanup);
        THROW 53808,N'SC023_HELP_PROFILE_RESTORE_FAILED',1;
    END;
    THROW;
END CATCH;
IF EXISTS(SELECT 1 FROM @Originals WHERE [IsDirty]=1)
    THROW 53809,N'SC023_HELP_PROFILE_RESIDUAL_DIRTY',1;
IF @@OPTIONS<>@OriginalOptions
    THROW 53811,N'SC023_HELP_PROFILE_CALLER_OPTIONS_CHANGED',1;
SELECT @AdmissionId=NULL,@AdmissionDate=NULL,@AdmissionStatus=NULL,
       @AdmissionError=NULL,@AdmissionMessage=NULL;
EXEC [SQLServerAnalyzeTest].[monitor].[InternalValidateSnapshotWaitTarget]
     @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',
     @TargetDatabaseIdOut=@AdmissionId OUTPUT,@TargetCreateDateOut=@AdmissionDate OUTPUT,
     @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,
     @ErrorMessageOut=@AdmissionMessage OUTPUT;
IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL OR COALESCE(@AdmissionId,-1)<>@OwnDbId
    THROW 53810,N'SC023_HELP_PROFILE_RESTORED_POSITIVE_FAILED',1;
USE [SQLServerAnalyzeTest];
GO

DECLARE @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@IsEnabled=1,
     @SchedulerType='EXTERNAL',@CollectionIntervalSeconds=30,@MaxRows=100,
     @PayloadEnabled=1,@RawRetentionDays=14,@PayloadRetentionDays=7,
     @RollupRetentionDays=180,@SoftBudgetMB=10240,@PurgeIntervalMinutes=60,
     @PurgeBatchRows=1000,@PrintMeldungen=0,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'AVAILABLE' THROW 53721,N'SC023_CONFIGURE_FAILED',1;

CREATE TABLE [#SnapshotBaselineRuntimeContract_CollectedRun]([Seed] bit NULL);
CREATE TABLE [#SnapshotBaselineRuntimeContract_CollectedModules]([Seed] bit NULL);
DECLARE @Run1 bigint,@Run2 bigint,@Run3 bigint,@Run4 bigint,@Json nvarchar(max),@Epoch1 uniqueidentifier,@Epoch2 uniqueidentifier;
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='MANUAL',@RunEvenIfNotDue=1,@ResultSetArt='TABLE',
     @ResultTablesJson=N'{"run":"#SnapshotBaselineRuntimeContract_CollectedRun","modules":"#SnapshotBaselineRuntimeContract_CollectedModules"}',
     @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@CaptureRunIdOut=@Run1 OUTPUT,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status NOT IN ('AVAILABLE','PARTIAL') OR @Run1 IS NULL OR ISJSON(@Json)<>1
    THROW 53722,N'SC023_FIRST_CYCLE_FAILED',1;
IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedRun') AND [collation_name] IS NOT NULL)<>5
   OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedModules') AND [collation_name] IS NOT NULL)<>4
   OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id] IN(OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedRun'),OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedModules'))
       AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
    THROW 53744,N'SC023_COLLECTION_TABLE_COLLATION_FAILED',1;
DECLARE @CollectedRun nvarchar(max)=(SELECT * FROM [#SnapshotBaselineRuntimeContract_CollectedRun] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
        @CollectedModules nvarchar(max)=(SELECT * FROM [#SnapshotBaselineRuntimeContract_CollectedModules] ORDER BY [ModuleStatusId] FOR JSON PATH,INCLUDE_NULL_VALUES),
        @NativeRun nvarchar(max)=(SELECT [CaptureRunId],N'SQLServerAnalyzeSnapshotTest' AS [TargetDatabaseName],[CollectorCode],[SchedulerType],
            [StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage]
            FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run1 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
        @NativeModules nvarchar(max)=(SELECT [ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
            FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run1 ORDER BY [ModuleStatusId] FOR JSON PATH,INCLUDE_NULL_VALUES);
IF (SELECT COUNT_BIG(*) FROM [#SnapshotBaselineRuntimeContract_CollectedRun])<>1
   OR (SELECT COUNT_BIG(*) FROM [#SnapshotBaselineRuntimeContract_CollectedModules])<>1
   OR COALESCE(@CollectedRun,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.run'),N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
   OR COALESCE(@CollectedRun,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@NativeRun,N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
   OR COALESCE(@CollectedModules,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.modules'),N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
   OR COALESCE(@CollectedModules,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@NativeModules,N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
    THROW 53745,N'SC023_COLLECTION_NATIVE_TABLE_JSON_PARITY_FAILED',1;
IF NOT EXISTS (SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run1)
    THROW 53723,N'SC023_METRIC_SAMPLE_MISSING',1;
IF NOT EXISTS
(
    SELECT 1
    FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PayloadSnapshot]
    WHERE [CaptureRunId]=@Run1
      AND [PayloadHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),CONVERT(nvarchar(max),DECOMPRESS([Payload]))))
      AND [UncompressedCharacterCount]=LEN(CONVERT(nvarchar(max),DECOMPRESS([Payload])))
)
    THROW 53724,N'SC023_PAYLOAD_LOSSLESS_CONTRACT',1;
SELECT @Epoch1=[ResetEpochId]
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
WHERE [CaptureRunId]=@Run1;
IF @Epoch1 IS NULL THROW 53725,N'SC023_RESET_EPOCH_MISSING',1;
INSERT [#SnapshotBaselineRuntimeContract_State]([StateName],[BigintValue],[GuidValue])
VALUES ('FIRST_RUN',@Run1,@Epoch1);

DECLARE @UnicodeRun bigint,@UnicodeJson nvarchar(max),@UnicodeStart datetime2(3);
SELECT @UnicodeStart=[SqlServerStartTimeUtc]
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run1;
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial])
VALUES('PERFORMANCE_COUNTERS','MANUAL',SYSUTCDATETIME(),N'ExampleUnicodeFramework',1,'AVAILABLE',0);
SET @UnicodeRun=CONVERT(bigint,SCOPE_IDENTITY());
SET @UnicodeJson=CONCAT(N'{"meta":{"sqlServerStartTime":"',CONVERT(nvarchar(30),@UnicodeStart,126),N'"},"counters":[',
  N'{"ObjectName":"ExampleCounterÄ","CounterName":"RequestsÄ","InstanceName":"ExampleInstanceÜ","CounterType":65792,"MetricValue":1.25,"MetricUnit":"COUNT","AfterValue":17,"FindingCode":"EXAMPLE_MEASURED"},',
  N'{"ObjectName":"ExampleCounterÄ","CounterName":"Requestsä","InstanceName":"ExampleInstanceÜ","CounterType":65792,"MetricValue":2.5,"MetricUnit":"COUNT","AfterValue":29,"FindingCode":"EXAMPLE_MEASURED"}]}');
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalCompletePerformanceCounterCycle]
     @CaptureRunId=@UnicodeRun,@CollectorJson=@UnicodeJson,@SourceStatusCode='AVAILABLE',@SourceIsPartial=0,
     @SourceErrorNumber=NULL,@SourceErrorMessage=NULL,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalFinalizeCollectionCycle]
     @CaptureRunId=@UnicodeRun,@StatusCode=@Status,@IsPartial=@Partial,@ErrorNumber=@Error,@ErrorMessage=@Message;
IF COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(@Partial,1)<>0 OR @Error IS NOT NULL
   OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@UnicodeRun)<>4
   OR (SELECT COUNT_BIG(DISTINCT [ScopeId]) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@UnicodeRun)<>2
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
       WHERE [CaptureRunId]=@UnicodeRun AND [MetricSampleCount]=4 AND [PayloadCount]=1 AND [ResetEpochId]=@Epoch1)
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@UnicodeRun
       AND [PayloadHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@UnicodeJson))
       AND CONVERT(nvarchar(max),DECOMPRESS([Payload])) COLLATE SQL_Latin1_General_CP1_CS_AS=@UnicodeJson COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 53748,N'SC023_UNICODE_COUNTER_PERSISTENCE_FAILED',1;
DECLARE @ExpectedUnicodeSamples TABLE([CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[MetricCode] varchar(96) COLLATE SQL_Latin1_General_CP1_CS_AS,
                                      [BigintValue] bigint,[NumericValue] decimal(38,6));
INSERT @ExpectedUnicodeSamples VALUES(N'RequestsÄ','PERFORMANCE_COUNTER_RAW',17,NULL),(N'RequestsÄ','PERFORMANCE_COUNTER_INTERPRETED',NULL,1.25),
                                    (N'Requestsä','PERFORMANCE_COUNTER_RAW',29,NULL),(N'Requestsä','PERFORMANCE_COUNTER_INTERPRETED',NULL,2.5);
IF EXISTS(SELECT [CounterName],[MetricCode],[BigintValue],[NumericValue] FROM @ExpectedUnicodeSamples
    EXCEPT SELECT JSON_VALUE([s].[ScopeIdentityJson],N'$.counterName') COLLATE SQL_Latin1_General_CP1_CS_AS,[d].[MetricCode] COLLATE SQL_Latin1_General_CP1_CS_AS,[m].[BigintValue],[m].[NumericValue]
    FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [m]
    JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope] AS [s] ON [s].[ScopeId]=[m].[ScopeId]
    JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition] AS [d] ON [d].[MetricDefinitionId]=[m].[MetricDefinitionId] WHERE [m].[CaptureRunId]=@UnicodeRun)
   OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] AS [m]
    JOIN [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope] AS [s] ON [s].[ScopeId]=[m].[ScopeId] WHERE [m].[CaptureRunId]=@UnicodeRun
       AND ([m].[QualityCode]<>'EXAMPLE_MEASURED' OR [m].[IsPartial]<>0 OR [m].[ResetEpochId]<>@Epoch1
            OR COALESCE(JSON_VALUE([s].[ScopeIdentityJson],N'$.objectName'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleCounterÄ'
            OR COALESCE(JSON_VALUE([s].[ScopeIdentityJson],N'$.instanceName'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>N'ExampleInstanceÜ'
            OR COALESCE(TRY_CONVERT(int,JSON_VALUE([s].[ScopeIdentityJson],N'$.counterType')),-1)<>65792
            OR COALESCE(JSON_VALUE([s].[ScopeIdentityJson],N'$.metricUnit'),N'')<>N'COUNT'
            OR [s].[ScopeKeyHash]<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),[s].[ScopeIdentityJson]))))
    THROW 53749,N'SC023_UNICODE_COUNTER_SCOPE_VALUE_FAILED',1;

EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='EXTERNAL',@RunEvenIfNotDue=1,@ResultSetArt='NONE',@PrintMeldungen=0,
     @CaptureRunIdOut=@Run2 OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status NOT IN ('AVAILABLE','PARTIAL') OR @Run2 IS NULL THROW 53726,N'SC023_EXTERNAL_ENTRY_FAILED',1;
SELECT @Epoch2=[ResetEpochId]
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
WHERE [CaptureRunId]=@Run2;
IF @Epoch2<>@Epoch1 THROW 53727,N'SC023_RESET_EPOCH_DRIFT',1;

EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='SQL_AGENT',@RunEvenIfNotDue=1,@ResultSetArt='NONE',@PrintMeldungen=0,
     @CaptureRunIdOut=@Run3 OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status NOT IN ('AVAILABLE','PARTIAL') OR @Run3 IS NULL THROW 53728,N'SC023_SQL_AGENT_ENTRY_FAILED',1;

EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='EXTERNAL',@RunEvenIfNotDue=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @CaptureRunIdOut=@Run4 OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'SKIPPED_NOT_DUE' OR @Run4 IS NULL
    THROW 53729,N'SC023_DUE_CONTRACT_FAILED',1;
IF EXISTS (SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@Run4)
    THROW 53730,N'SC023_NOT_DUE_READ_SOURCE',1;

CREATE TABLE [#SnapshotBaselineRuntimeContract_RunOutput]
([Seed] bit NULL);
CREATE TABLE [#SnapshotBaselineRuntimeContract_ModuleOutput]
([Seed] bit NULL);
DECLARE @TableRun bigint;
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='EXTERNAL',@RunEvenIfNotDue=0,@ResultSetArt='TABLE',
     @ResultTablesJson=N'{"run":"#SnapshotBaselineRuntimeContract_RunOutput","modules":"#SnapshotBaselineRuntimeContract_ModuleOutput"}',
     @PrintMeldungen=0,@CaptureRunIdOut=@TableRun OUTPUT,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'SKIPPED_NOT_DUE' OR @TableRun IS NULL
   OR (SELECT COUNT_BIG(*) FROM [#SnapshotBaselineRuntimeContract_RunOutput])<>1
   OR (SELECT COUNT_BIG(*) FROM [#SnapshotBaselineRuntimeContract_ModuleOutput])<>1
    THROW 53742,N'SC023_COLLECTION_TABLE_OUTPUT_FAILED',1;
GO

USE [SQLServerAnalyzeSnapshotTest];
GO
IF NOT EXISTS (SELECT 1 FROM [snapshot].[RetentionPolicy] WHERE [RetentionPolicyCode]='EXAMPLE_LOCAL')
    INSERT [snapshot].[RetentionPolicy]
    ([RetentionPolicyCode],[RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays],[SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows],[BudgetAction],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
    VALUES ('EXAMPLE_LOCAL',30,15,365,2048,120,500,'PURGE_EXPIRED_THEN_STOP',0,1,CONVERT(datetime2(3),'2026-01-01T00:00:00'));
GO
:r Install_SnapshotBaseline_Target.sql

USE [SQLServerAnalyzeTest];
GO
:r Install_SnapshotBaseline_Framework.sql

IF NOT EXISTS
(
    SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
    WHERE [RetentionPolicyCode]='EXAMPLE_LOCAL'
      AND [LastUpdatedUtc]=CONVERT(datetime2(3),'2026-01-01T00:00:00')
)
    THROW 53731,N'SC023_REINSTALL_CHANGED_LOCAL_POLICY',1;
IF NOT EXISTS
(
    SELECT 1 FROM [monitor].[SnapshotTargetConfiguration]
    WHERE [ConfigurationId]=1 AND [TargetDatabaseName]=N'SQLServerAnalyzeSnapshotTest' AND [IsEnabled]=1
)
    THROW 53732,N'SC023_REINSTALL_CHANGED_FRAMEWORK_CONFIG',1;

DECLARE @OldRun bigint,@ScopeId bigint,@MetricId bigint;
SELECT TOP (1) @ScopeId=[ScopeId]
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope]
WHERE [ScopeType]='SERVER' ORDER BY [ScopeId];
SELECT @MetricId=[MetricDefinitionId]
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricDefinition]
WHERE [MetricCode]='PERFORMANCE_COUNTER_RAW';
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SourceDatabaseName],[SqlServerStartTimeUtc],[ResetEpochId],[ContractVersion],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount])
VALUES ('PERFORMANCE_COUNTERS','MANUAL',DATEADD(DAY,-30,SYSUTCDATETIME()),DATEADD(DAY,-30,SYSUTCDATETIME()),N'ExampleFrameworkDatabase',DATEADD(DAY,-40,SYSUTCDATETIME()),NEWID(),1,'AVAILABLE',0,1,0);
SET @OldRun=CONVERT(bigint,SCOPE_IDENTITY());
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample]
([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
VALUES (@OldRun,@ScopeId,@MetricId,DATEADD(DAY,-30,SYSUTCDATETIME()),NEWID(),1,'EXAMPLE_MEASURED',0);
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus]
([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[EvidenceLimit])
VALUES (@OldRun,N'ExampleCollector',DATEADD(DAY,-30,SYSUTCDATETIME()),'AVAILABLE',0,N'Synthetic retention fixture.');

CREATE TABLE [#SnapshotBaselineRuntimeContract_CollectedPurge]([Seed] bit NULL);
DECLARE @PurgeRun bigint,@PurgeJson nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
EXEC [monitor].[USP_PurgeSnapshotData]
     @MaxBatches=2,@Force=1,@ResultSetArt='TABLE',
     @ResultTablesJson=N'{"purge":"#SnapshotBaselineRuntimeContract_CollectedPurge"}',@JsonErzeugen=1,@Json=@PurgeJson OUTPUT,@PrintMeldungen=0,
     @PurgeRunIdOut=@PurgeRun OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status NOT IN ('AVAILABLE','AVAILABLE_LIMITED') OR @PurgeRun IS NULL OR ISJSON(@PurgeJson)<>1
    THROW 53733,N'SC023_PURGE_FAILED',1;
IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedPurge') AND [collation_name] IS NOT NULL)<>3
   OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#SnapshotBaselineRuntimeContract_CollectedPurge')
       AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
    THROW 53746,N'SC023_PURGE_TABLE_COLLATION_FAILED',1;
DECLARE @PurgeTableJson nvarchar(max)=(SELECT * FROM [#SnapshotBaselineRuntimeContract_CollectedPurge] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
        @NativePurgeJson nvarchar(max)=(SELECT [PurgeRunId],N'SQLServerAnalyzeSnapshotTest' AS [TargetDatabaseName],[StartedAtUtc],[EndedAtUtc],[StatusCode],
            [BatchesExecuted],[MetricRowsDeleted],[PayloadRowsDeleted],[ModuleRowsDeleted],[CaptureRunsDeleted],[ScopeRowsDeleted],
            [UsedDataMbBefore],[UsedDataMbAfter],[SoftBudgetMb],CONVERT(bit,0) AS [BudgetExceeded],[ErrorNumber],[ErrorMessage]
            FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun] WHERE [PurgeRunId]=@PurgeRun FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
IF COALESCE(ISJSON(@PurgeJson),0)<>1 OR @PurgeRun IS NULL
   OR COALESCE(@PurgeTableJson,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@PurgeJson,N'$.purge'),N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
   OR COALESCE(@PurgeTableJson,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@NativePurgeJson,N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
    THROW 53747,N'SC023_PURGE_NATIVE_TABLE_JSON_PARITY_FAILED',1;

IF EXISTS (SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@OldRun)
    THROW 53734,N'SC023_EXPIRED_RUN_RETAINED',1;
DECLARE @FirstRunRestored bigint=(SELECT [BigintValue] FROM [#SnapshotBaselineRuntimeContract_State] WHERE [StateName]='FIRST_RUN');
IF NOT EXISTS (SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@FirstRunRestored)
    THROW 53735,N'SC023_UNEXPIRED_RUN_DELETED',1;

CREATE TABLE [#SnapshotBaselineRuntimeContract_PurgeOutput]
([Seed] bit NULL);
DECLARE @TablePurgeRun bigint;
EXEC [monitor].[USP_PurgeSnapshotData]
     @MaxBatches=2,@Force=0,@ResultSetArt='TABLE',
     @ResultTablesJson=N'{"purge":"#SnapshotBaselineRuntimeContract_PurgeOutput"}',
     @JsonErzeugen=1,@Json=@PurgeJson OUTPUT,@PrintMeldungen=0,@PurgeRunIdOut=@TablePurgeRun OUTPUT,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'SKIPPED_NOT_DUE'
   OR (SELECT COUNT_BIG(*) FROM [#SnapshotBaselineRuntimeContract_PurgeOutput])<>1
    THROW 53743,N'SC023_PURGE_TABLE_OUTPUT_FAILED',1;
IF @TablePurgeRun IS NOT NULL OR COALESCE(ISJSON(@PurgeJson),0)<>1
   OR EXISTS(SELECT 1 FROM [#SnapshotBaselineRuntimeContract_PurgeOutput] WHERE [PurgeRunId] IS NOT NULL
       OR [StatusCode]<>'SKIPPED_NOT_DUE' OR [BatchesExecuted]<>0 OR [MetricRowsDeleted]<>0 OR [PayloadRowsDeleted]<>0
       OR [ModuleRowsDeleted]<>0 OR [CaptureRunsDeleted]<>0 OR [ScopeRowsDeleted]<>0 OR [BudgetExceeded]<>0)
   OR COALESCE((SELECT * FROM [#SnapshotBaselineRuntimeContract_PurgeOutput] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
        <>COALESCE(JSON_QUERY(@PurgeJson,N'$.purge'),N'!') COLLATE SQL_Latin1_General_CP1_CS_AS
    THROW 53750,N'SC023_PURGE_SKIP_TABLE_JSON_PARITY_FAILED',1;

UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
SET [SoftBudgetMB]=1
WHERE [RetentionPolicyCode]='DEFAULT';
DECLARE @BudgetRun bigint;
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='MANUAL',@RunEvenIfNotDue=1,@ResultSetArt='NONE',@PrintMeldungen=0,
     @CaptureRunIdOut=@BudgetRun OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'STOPPED_SIZE_BUDGET' OR @BudgetRun IS NULL
    THROW 53736,N'SC023_BUDGET_STOP_FAILED',1;
IF EXISTS (SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@BudgetRun)
    THROW 53737,N'SC023_BUDGET_STOP_READ_SOURCE',1;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
SET [SoftBudgetMB]=10240
WHERE [RetentionPolicyCode]='DEFAULT';

-- Synthetic rows exercise the real shared Purge; no Wait collector is activated.
DECLARE @WaitOld bigint,@WaitFailed bigint,@WaitNew bigint,@PerfExpired bigint,
        @WaitPurge bigint,@WaitBudget bit,@WaitEpoch uniqueidentifier=NEWID(),
        @WaitCutoff datetime2(3)=DATEADD(DAY,-40,SYSUTCDATETIME());
IF NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy] WHERE [CollectorCode]='WAIT_STATS')
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CollectorPolicy]
([CollectorCode],[IsEnabled],[CollectionIntervalSeconds],[MaxRows],[PayloadEnabled],
 [RetentionPolicyCode],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
VALUES('WAIT_STATS',0,30,1000,0,'DEFAULT',0,1,SYSUTCDATETIME());
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
SET [PurgeBatchRows]=1 WHERE [RetentionPolicyCode]='DEFAULT';

INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial],[MetricSampleCount])
VALUES('WAIT_STATS','MANUAL',@WaitCutoff,@WaitCutoff,N'ExampleWaitRetentionFramework',1,'AVAILABLE',0,3);
SET @WaitOld=CONVERT(bigint,SCOPE_IDENTITY());
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope]
([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
SELECT 'WAIT_TYPE',@ScopeId,HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson])),[j].[IdentityJson],@WaitCutoff
FROM (VALUES(1),(2),(3)) AS [v]([n])
CROSS APPLY(SELECT CONCAT(N'EXAMPLE_RETENTION_WAIT_',CONVERT(nvarchar(10),[v].[n])) AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson]);
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample]
([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
SELECT @WaitOld,[ScopeId],@MetricId,@WaitCutoff,@WaitEpoch,1,'EXAMPLE_RETENTION_FIXTURE',0
FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[Scope]
WHERE [ScopeType]='WAIT_TYPE' AND JSON_VALUE([ScopeIdentityJson],N'$.waitType') IN
      (N'EXAMPLE_RETENTION_WAIT_1',N'EXAMPLE_RETENTION_WAIT_2',N'EXAMPLE_RETENTION_WAIT_3');
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial],[ErrorNumber])
VALUES('WAIT_STATS','MANUAL',DATEADD(SECOND,1,@WaitCutoff),DATEADD(SECOND,1,@WaitCutoff),N'ExampleWaitRetentionFramework',1,'ERROR_HANDLED',1,50000);
SET @WaitFailed=CONVERT(bigint,SCOPE_IDENTITY());

EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData]
     @MaxBatches=1,@Force=1,@PurgeRunIdOut=@WaitPurge OUTPUT,@StatusCodeOut=@Status OUTPUT,
     @BudgetExceededOut=@WaitBudget OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_LIMITED') OR @Error IS NOT NULL
   OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@WaitOld)<>2
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun]
       WHERE [PurgeRunId]=@WaitPurge AND [BatchesExecuted]=1 AND [MetricRowsDeleted]=1)
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@WaitOld)
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@WaitFailed)
   OR (SELECT MAX([CaptureRunId]) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
       WHERE [CollectorCode]='WAIT_STATS' AND [EndedAtUtc] IS NOT NULL)<>@WaitFailed
    THROW 53751,N'SC023_WAIT_RETENTION_FAILED_RUN_FENCE',1;

-- Neither a newer Performance-Counter run nor an unfinalized Wait run releases the fence.
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial])
VALUES('PERFORMANCE_COUNTERS','MANUAL',@WaitCutoff,@WaitCutoff,N'ExampleWaitRetentionFramework',1,'AVAILABLE',0);
SET @PerfExpired=CONVERT(bigint,SCOPE_IDENTITY());
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
([CollectorCode],[SchedulerType],[StartedAtUtc],[SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial])
VALUES('WAIT_STATS','MANUAL',SYSUTCDATETIME(),N'ExampleWaitRetentionFramework',1,'RUNNING',0);
SET @WaitNew=CONVERT(bigint,SCOPE_IDENTITY());
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData]
     @MaxBatches=10,@Force=1,@PurgeRunIdOut=@WaitPurge OUTPUT,@StatusCodeOut=@Status OUTPUT,
     @BudgetExceededOut=@WaitBudget OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_LIMITED') OR @Error IS NOT NULL
   OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId] IN(@WaitOld,@PerfExpired))
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@WaitFailed)
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@WaitNew AND [EndedAtUtc] IS NULL)
    THROW 53752,N'SC023_WAIT_RETENTION_COLLECTOR_FINALIZED_BOUNDARY',1;

-- A real finalization releases the previous fence. Children of the new fence still expire.
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus]
([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial])
VALUES(@WaitNew,N'ExampleWaitRetentionFixture',@WaitCutoff,'AVAILABLE',0);
INSERT [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample]
([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
VALUES(@WaitNew,@ScopeId,@MetricId,@WaitCutoff,@WaitEpoch,2,'EXAMPLE_RETENTION_FIXTURE',0);
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalFinalizeCollectionCycle]
     @CaptureRunId=@WaitNew,@StatusCode='AVAILABLE',@IsPartial=0,@ErrorNumber=NULL,@ErrorMessage=NULL;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
SET [StartedAtUtc]=DATEADD(SECOND,2,@WaitCutoff),[EndedAtUtc]=DATEADD(SECOND,2,@WaitCutoff)
WHERE [CaptureRunId]=@WaitNew;
EXEC [SQLServerAnalyzeSnapshotTest].[snapshot].[InternalPurgeExpiredData]
     @MaxBatches=10,@Force=1,@PurgeRunIdOut=@WaitPurge OUTPUT,@StatusCodeOut=@Status OUTPUT,
     @BudgetExceededOut=@WaitBudget OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_LIMITED') OR @Error IS NOT NULL
   OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun] WHERE [CaptureRunId]=@WaitFailed)
   OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[MetricSample] WHERE [CaptureRunId]=@WaitNew)
   OR EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@WaitNew)
   OR NOT EXISTS(SELECT 1 FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]
       WHERE [CaptureRunId]=@WaitNew AND [EndedAtUtc] IS NOT NULL AND [MetricSampleCount]=1)
    THROW 53753,N'SC023_WAIT_RETENTION_CHILD_EXPIRY_AND_FENCE_RELEASE',1;
UPDATE [SQLServerAnalyzeSnapshotTest].[snapshot].[RetentionPolicy]
SET [PurgeBatchRows]=1000 WHERE [RetentionPolicyCode]='DEFAULT';

EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName=N'SQLServerAnalyzeSnapshotTest',@IsEnabled=0,@PrintMeldungen=0,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'AVAILABLE' THROW 53738,N'SC023_DISABLE_CONFIG_FAILED',1;
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @ResultSetArt='NONE',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
     @IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'DISABLED' THROW 53739,N'SC023_DISABLED_CONTRACT_FAILED',1;

:r ../Tests/Integration/223_SnapshotWaitStats_Target_Runtime_Contract.sql
:r ../Tests/Integration/224_SnapshotWaitStats_Public_Runtime_Contract.sql
:r ../Tests/Integration/227_SnapshotFileIO_Target_Runtime_Contract.sql
:r ../Tests/Integration/228_SnapshotFileIO_Public_Runtime_Contract.sql

PRINT N'SC023_RUNTIME_CONTRACT PASS';
GO
