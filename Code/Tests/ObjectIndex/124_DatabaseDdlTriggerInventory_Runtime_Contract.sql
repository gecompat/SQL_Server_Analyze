USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57600,N'Database DDL trigger contract requires the isolated remote CI sysadmin target without an ambient transaction.',1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 57601,N'Database DDL trigger contract requires the selected SQL Server 2025 native CI target.',1;
GO
DECLARE @Suffix nvarchar(48)=CONVERT(nvarchar(12),@@SPID)+N'_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),16),
        @PositiveDb sysname,@EmptyDb sysname,@Reader sysname,@FixtureCredential nvarchar(128),
        @PositiveDbId int,@DmlExcludedCount bigint=NULL,@DmlExcludedAfterCount bigint=NULL,@RestrictedObserved bigint,@RestrictedNativeError int,
        @Sql nvarchar(max),@Names nvarchar(max),@Json nvarchar(max),@TablePayload nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
        @OriginalLock int=@@LOCK_TIMEOUT,@OriginalTx int=@@TRANCOUNT,
        @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @Impersonating bit=0,@LoginCreated bit=0,@InstallUserCreated bit=0,
        @PositiveDbCreated bit=0,@EmptyDbCreated bit=0,
        @CleanupFailure nvarchar(2048)=NULL,@CleanupNativeError int=NULL;
SELECT @PositiveDb=N'ExampleDdlTriggerPos_'+@Suffix,
       @EmptyDb=N'ExampleDdlTriggerEmpty_'+@Suffix,
       @Reader=N'ExampleDdlTriggerReader_'+@Suffix,
       @FixtureCredential=N'Example!'+CONVERT(nvarchar(36),NEWID());
IF DB_ID(@PositiveDb) IS NOT NULL OR DB_ID(@EmptyDb) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.server_principals WHERE [name]=@Reader)
    THROW 57602,N'Database DDL trigger owned fixture name collision.',1;
CREATE TABLE #DdlTriggerOut_moduleStatus([Seed] int NULL);
CREATE TABLE #DdlTriggerOut_ddlTriggers([Seed] int NULL);
CREATE TABLE #DdlTriggerOut_sourceStatus([Seed] int NULL);
CREATE TABLE #DdlTriggerOut_warnings([Seed] int NULL);
CREATE TABLE #ExpectedDdlTriggers
(
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TriggerObjectId] int NOT NULL,
            [TriggerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ParentClass] tinyint NOT NULL,
            [ParentClassDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TriggerType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TriggerTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsDisabled] bit NOT NULL,
            [CreateDate] datetime NOT NULL,
            [ModifyDate] datetime NOT NULL,
            [MetadataVisibility] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@PositiveDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @PositiveDbCreated=1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@EmptyDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @EmptyDbCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      CREATE TABLE dbo.ExampleDdlTriggerData(ExampleId int NOT NULL);
      EXEC(N''CREATE TRIGGER ExampleDdlTriggerEnabled ON DATABASE FOR CREATE_TABLE AS BEGIN DECLARE @ExampleDefinitionSentinel int=1; END;'');
      EXEC(N''CREATE TRIGGER ExampleDdlTriggerDisabled ON DATABASE FOR CREATE_TABLE AS BEGIN DECLARE @ExampleDefinitionSentinel int=2; END;'');
      EXEC(N''CREATE TRIGGER dbo.ExampleDmlTriggerExcluded ON dbo.ExampleDdlTriggerData AFTER INSERT AS BEGIN RETURN; END;'');
      DISABLE TRIGGER ExampleDdlTriggerDisabled ON DATABASE;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      INSERT #ExpectedDdlTriggers
        ([DatabaseId],[DatabaseName],[TriggerObjectId],[TriggerName],[ParentClass],
         [ParentClassDesc],[TriggerType],[TriggerTypeDesc],[IsDisabled],
         [CreateDate],[ModifyDate],[MetadataVisibility])
      SELECT @Id,@Name,[object_id],[name],[parent_class],[parent_class_desc],
             [type],[type_desc],[is_disabled],[create_date],[modify_date],''VISIBLE_ONLY''
      FROM [sys].[triggers] WITH (NOLOCK)
      WHERE [parent_class]=0;
      SELECT @DmlCount=COUNT_BIG(*)
      FROM [sys].[triggers] WITH (NOLOCK)
      WHERE [parent_class]=1 AND [name]=N''ExampleDmlTriggerExcluded'';';
    SET @PositiveDbId=DB_ID(@PositiveDb);
    EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@DmlCount bigint OUTPUT',
        @Id=@PositiveDbId,@Name=@PositiveDb,@DmlCount=@DmlExcludedCount OUTPUT;
    IF (SELECT COUNT(*) FROM #ExpectedDdlTriggers)<>2
       OR (SELECT COUNT(*) FROM #ExpectedDdlTriggers WHERE ParentClass=0 AND ParentClassDesc=N'DATABASE')<>2
       OR (SELECT COUNT(*) FROM #ExpectedDdlTriggers WHERE TriggerType='TR')<>2
       OR NOT EXISTS(SELECT 1 FROM #ExpectedDdlTriggers
                     WHERE TriggerName=N'ExampleDdlTriggerEnabled' AND IsDisabled=0)
       OR NOT EXISTS(SELECT 1 FROM #ExpectedDdlTriggers
                     WHERE TriggerName=N'ExampleDdlTriggerDisabled' AND IsDisabled=1)
       OR (SELECT COUNT(*) FROM #ExpectedDdlTriggers WHERE IsDisabled=1)<>1
       OR (SELECT COUNT(*) FROM #ExpectedDdlTriggers WHERE IsDisabled=0)<>1
       OR COALESCE(@DmlExcludedCount,-1)<>1
       THROW 57614,N'Database DDL trigger fixture catalog setup differs from expected scope and disabled states.',1;
    SET @Names=QUOTENAME(@PositiveDb)+N'|'+QUOTENAME(@EmptyDb);
    EXEC @Return=[monitor].[USP_DatabaseDdlTriggerInventory]
        @DatabaseNames=@Names,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"moduleStatus":"#DdlTriggerOut_moduleStatus","ddlTriggers":"#DdlTriggerOut_ddlTriggers","sourceStatus":"#DdlTriggerOut_sourceStatus","warnings":"#DdlTriggerOut_warnings"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    SELECT @TablePayload=
        (SELECT * FROM #DdlTriggerOut_moduleStatus FOR JSON PATH)
       +(SELECT * FROM #DdlTriggerOut_ddlTriggers FOR JSON PATH)
       +(SELECT * FROM #DdlTriggerOut_sourceStatus FOR JSON PATH)
       +(SELECT * FROM #DdlTriggerOut_warnings FOR JSON PATH);
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(ISJSON(@Json),0)<>1
       OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@Status
       OR COALESCE(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>'true'
       OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]='meta' AND [type]=5)
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','ddlTriggers','sourceStatus','warnings') AND [type]=4)<>4
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json)
           WHERE [key] NOT IN('meta','moduleStatus','ddlTriggers','sourceStatus','warnings'))
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedDdlTriggers
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #DdlTriggerOut_ddlTriggers)
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #DdlTriggerOut_ddlTriggers
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedDdlTriggers)
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedDdlTriggers
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,'$.ddlTriggers') WITH
            ([DatabaseId] int,[DatabaseName] sysname,[TriggerObjectId] int,[TriggerName] sysname,
             [ParentClass] tinyint,[ParentClassDesc] nvarchar(60),
             [TriggerType] char(2),[TriggerTypeDesc] nvarchar(60),[IsDisabled] bit,
             [CreateDate] datetime,[ModifyDate] datetime,[MetadataVisibility] varchar(16)))
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,'$.ddlTriggers') WITH
            ([DatabaseId] int,[DatabaseName] sysname,[TriggerObjectId] int,[TriggerName] sysname,
             [ParentClass] tinyint,[ParentClassDesc] nvarchar(60),
             [TriggerType] char(2),[TriggerTypeDesc] nvarchar(60),[IsDisabled] bit,
             [CreateDate] datetime,[ModifyDate] datetime,[MetadataVisibility] varchar(16))
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerObjectId],[TriggerName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ParentClass],[ParentClassDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerType] COLLATE SQL_Latin1_General_CP1_CS_AS,[TriggerTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[CreateDate],[ModifyDate],[MetadataVisibility] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedDdlTriggers)
       OR EXISTS(SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#DdlTriggerOut_ddlTriggers')
                 EXCEPT
                 SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedDdlTriggers'))
       OR EXISTS(SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedDdlTriggers')
                 EXCEPT
                 SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#DdlTriggerOut_ddlTriggers'))
       OR NOT EXISTS(SELECT 1 FROM #DdlTriggerOut_sourceStatus
                     WHERE DatabaseName=@PositiveDb AND SourceKey='DATABASE_DDL_TRIGGERS_CATALOG'
                       AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=2
                       AND ReturnedRows=2 AND IsLimited=0 AND ErrorNumber IS NULL)
       OR NOT EXISTS(SELECT 1 FROM #DdlTriggerOut_sourceStatus
                     WHERE DatabaseName=@EmptyDb AND SourceKey='DATABASE_DDL_TRIGGERS_CATALOG'
                       AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=0
                       AND ReturnedRows=0 AND IsLimited=0 AND ErrorNumber IS NULL)
       OR @TablePayload IS NULL
       OR CHARINDEX(N'ExampleDefinitionSentinel',@Json)>0
       OR CHARINDEX(N'CREATE_TABLE',@Json)>0
       OR CHARINDEX(N'ExampleDdlTriggerData',@Json)>0
       OR CHARINDEX(N'ExampleDmlTriggerExcluded',@Json)>0
       OR CHARINDEX(N'ExampleDefinitionSentinel',@TablePayload)>0
       OR CHARINDEX(N'CREATE_TABLE',@TablePayload)>0
       OR CHARINDEX(N'ExampleDdlTriggerData',@TablePayload)>0
       OR CHARINDEX(N'ExampleDmlTriggerExcluded',@TablePayload)>0
       THROW 57603,N'Database DDL trigger positive TABLE/JSON/catalog contract failed.',1;
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    SET @Names=QUOTENAME(@EmptyDb);
    EXEC @Return=[monitor].[USP_DatabaseDdlTriggerInventory]
        @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,
        @Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,
        @ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(ISJSON(@Json),0)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','ddlTriggers','sourceStatus','warnings') AND [type]=4)<>4
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.ddlTriggers'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
              WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                   ObservedRows bigint,ReturnedRows bigint,IsLimited bit,ErrorNumber int)
              WHERE DatabaseName=@EmptyDb AND SourceKey='DATABASE_DDL_TRIGGERS_CATALOG'
                AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=0 AND ReturnedRows=0
                AND IsLimited=0 AND ErrorNumber IS NULL)
       THROW 57605,N'Database DDL trigger visible-empty contract failed.',1;
    SELECT @Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_DatabaseDdlTriggerInventory]
        @DatabaseNames=@Names,@MaxZeilen=-1,@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>51011) OR COALESCE(@Status,'')<>'INVALID_PARAMETER' OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,-1)<>51011
       THROW 57606,N'Database DDL trigger negative limit acceptance failed.',1;
    SELECT @Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_DatabaseDdlTriggerInventory]
        @DatabaseNames=@Names,@ResultSetArt='TABLE',@ResultTablesJson=N'{"unknown":"#DdlTriggerOut_ddlTriggers"}',
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>51011) OR COALESCE(@Status,'')<>'ERROR_HANDLED' OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,-1)<>51011
       THROW 57607,N'Database DDL trigger invalid TABLE mapping failed.',1;
    SET @Names=QUOTENAME(@PositiveDb);
    SET @Sql=N'SET XACT_ABORT ON; SET LOCK_TIMEOUT 7000;
      DECLARE @ReferenceBeforeState int,@ReferenceBeforeTx int,
              @ReferenceDuringState int,@ReferenceDuringTx int,
              @ReferenceAfterState int,@ReferenceAfterTx int,
              @SutActiveState int,
              @AfterRollbackTxCount int,@AfterRollbackXactState int,
              @AfterRollbackLockTimeout int,@AfterRollbackAbortBit int;
      SET @ReferenceBeforeState=XACT_STATE();
      SET @ReferenceBeforeTx=@@TRANCOUNT;
      IF @ReferenceBeforeState<>0 OR @ReferenceBeforeTx<>@ExpectedTx
      BEGIN
         RAISERROR(N''Database DDL trigger reference before: tx=%d xact=%d.'',10,1,
                   @ReferenceBeforeTx,@ReferenceBeforeState) WITH NOWAIT;
         THROW 57620,N''Database DDL trigger reference transaction before BEGIN differs.'',1;
      END;
      BEGIN TRANSACTION;
      SET @ReferenceDuringState=XACT_STATE();
      SET @ReferenceDuringTx=@@TRANCOUNT;
      IF @ReferenceDuringState<>1 OR @ReferenceDuringTx<>@ExpectedTx+1
      BEGIN
         RAISERROR(N''Database DDL trigger reference during: tx=%d xact=%d.'',10,1,
                   @ReferenceDuringTx,@ReferenceDuringState) WITH NOWAIT;
         IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
         THROW 57621,N''Database DDL trigger reference transaction after BEGIN differs.'',1;
      END;
      ROLLBACK TRANSACTION;
      SET @ReferenceAfterState=XACT_STATE();
      SET @ReferenceAfterTx=@@TRANCOUNT;
      IF @ReferenceAfterState<>0 OR @ReferenceAfterTx<>@ExpectedTx
      BEGIN
         RAISERROR(N''Database DDL trigger reference after: tx=%d xact=%d.'',10,1,
                   @ReferenceAfterTx,@ReferenceAfterState) WITH NOWAIT;
         THROW 57622,N''Database DDL trigger reference transaction after ROLLBACK differs.'',1;
      END;
      BEGIN TRANSACTION; SET XACT_ABORT ON; SET LOCK_TIMEOUT 7000;
      EXEC @R=[monitor].[USP_DatabaseDdlTriggerInventory]
          @DatabaseNames=@N,@MaxZeilen=1,@ResultSetArt=''NONE'',
          @JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@S OUTPUT,@IsPartialOut=@P OUTPUT,
          @ErrorNumberOut=@E OUTPUT,@ErrorMessageOut=@M OUTPUT;
      SET @SutActiveState=XACT_STATE();
      IF @@TRANCOUNT<>@ExpectedTx+1 OR @SutActiveState<>1 OR @@LOCK_TIMEOUT<>7000
         OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>1
         OR @R IS NULL OR @R<>0 OR COALESCE(@S,'''')<>''AVAILABLE_LIMITED''
         THROW 57612,N''Database DDL trigger inner caller state changed.'',1;
      ROLLBACK TRANSACTION;
      SET @AfterRollbackXactState=XACT_STATE();
      SET @AfterRollbackTxCount=@@TRANCOUNT;
      SET @AfterRollbackLockTimeout=@@LOCK_TIMEOUT;
      SET @AfterRollbackAbortBit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END;
      IF @AfterRollbackTxCount<>@ExpectedTx OR @AfterRollbackXactState<>0
         OR @AfterRollbackLockTimeout<>7000 OR @AfterRollbackAbortBit<>1
      BEGIN
         RAISERROR(N''Database DDL trigger post-rollback state: tx=%d xact=%d lock=%d abort=%d.'',10,1,
                   @AfterRollbackTxCount,@AfterRollbackXactState,
                   @AfterRollbackLockTimeout,@AfterRollbackAbortBit) WITH NOWAIT;
         THROW 57618,N''Database DDL trigger inner rollback or caller state changed.'',1;
      END;';
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL,@Return=NULL;
    EXEC [sys].[sp_executesql] @Sql,
        N'@N nvarchar(max),@R int OUTPUT,@J nvarchar(max) OUTPUT,@S varchar(40) OUTPUT,
          @P bit OUTPUT,@E int OUTPUT,@M nvarchar(2048) OUTPUT,@ExpectedTx int',
        @N=@Names,@R=@Return OUTPUT,@J=@Json OUTPUT,@S=@Status OUTPUT,@P=@Partial OUTPUT,
        @E=@Error OUTPUT,@M=@Message OUTPUT,@ExpectedTx=@OriginalTx;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.ddlTriggers'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')
            WITH(WarningCode varchar(64)) WHERE WarningCode='OUTPUT_LIMIT')
       OR @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
       THROW 57613,N'Database DDL trigger limit or caller-option restoration failed.',1;
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)+N' WITH PASS'+N'WORD='+QUOTENAME(@FixtureCredential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N'; GRANT EXECUTE ON [monitor].[USP_DatabaseDdlTriggerInventory] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @InstallUserCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N'; CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@EmptyDb)+N'; CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE [master]; GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    SET @Names=QUOTENAME(@PositiveDb)+N'|'+QUOTENAME(@EmptyDb);
    SELECT @RestrictedObserved=NULL,@RestrictedNativeError=NULL;
    BEGIN TRY
        SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
          SELECT @Rows=COUNT_BIG(*) FROM [sys].[triggers] WITH (NOLOCK) WHERE [parent_class]=0;';
        EXEC [sys].[sp_executesql] @Sql,N'@Rows bigint OUTPUT',
            @Rows=@RestrictedObserved OUTPUT;
    END TRY
    BEGIN CATCH
        SET @RestrictedNativeError=ERROR_NUMBER();
    END CATCH;
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_DatabaseDdlTriggerInventory]
        @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Partial,0)<>1
       OR COALESCE(ISJSON(@Json),0)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','ddlTriggers','sourceStatus','warnings') AND [type]=4)<>4
       OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>COALESCE(@Status,'')
       THROW 57608,N'Database DDL trigger restricted-caller JSON/status contract failed.',1;
    IF @RestrictedNativeError IS NULL
    BEGIN
        IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR @Error IS NOT NULL
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.ddlTriggers'))<>@RestrictedObserved
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
                WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                     ObservedRows bigint,ReturnedRows bigint)
                WHERE DatabaseName=@PositiveDb AND SourceKey='DATABASE_DDL_TRIGGERS_CATALOG'
                  AND StatusCode='AVAILABLE_LIMITED'
                  AND ObservedRows=@RestrictedObserved AND ReturnedRows=@RestrictedObserved)
           THROW 57615,N'Database DDL trigger restricted visible-source contract failed.',1;
    END
    ELSE IF @RestrictedNativeError IN(229,297,300,371)
    BEGIN
        IF COALESCE(@Status,'')<>'DENIED_PERMISSION'
           OR COALESCE(@Error,-1)<>@RestrictedNativeError
           OR @Message IS NULL
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.ddlTriggers'))
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
                WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                     ObservedRows bigint,ReturnedRows bigint,ErrorNumber int)
                WHERE DatabaseName=@PositiveDb AND SourceKey='DATABASE_DDL_TRIGGERS_CATALOG'
                  AND StatusCode='DENIED_PERMISSION' AND ObservedRows IS NULL
                  AND ReturnedRows IS NULL AND ErrorNumber=@RestrictedNativeError)
           THROW 57616,N'Database DDL trigger restricted native-denial contract failed.',1;
    END
    ELSE
        THROW 57617,N'Database DDL trigger restricted native source failed outside the tested permission boundary.',1;
    REVERT;
    SET @Impersonating=0;
    SELECT TOP (0) * INTO #AfterDdlTriggers FROM #ExpectedDdlTriggers;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      INSERT #AfterDdlTriggers
        ([DatabaseId],[DatabaseName],[TriggerObjectId],[TriggerName],[ParentClass],
         [ParentClassDesc],[TriggerType],[TriggerTypeDesc],[IsDisabled],
         [CreateDate],[ModifyDate],[MetadataVisibility])
      SELECT @Id,@Name,[object_id],[name],[parent_class],[parent_class_desc],
             [type],[type_desc],[is_disabled],[create_date],[modify_date],''VISIBLE_ONLY''
      FROM [sys].[triggers] WITH (NOLOCK)
      WHERE [parent_class]=0;
      SELECT @DmlCount=COUNT_BIG(*)
      FROM [sys].[triggers] WITH (NOLOCK)
      WHERE [parent_class]=1 AND [name]=N''ExampleDmlTriggerExcluded'';';
    EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@DmlCount bigint OUTPUT',
        @Id=@PositiveDbId,@Name=@PositiveDb,@DmlCount=@DmlExcludedAfterCount OUTPUT;
    IF EXISTS(SELECT * FROM #ExpectedDdlTriggers EXCEPT SELECT * FROM #AfterDdlTriggers)
       OR EXISTS(SELECT * FROM #AfterDdlTriggers EXCEPT SELECT * FROM #ExpectedDdlTriggers)
       OR COALESCE(@DmlExcludedAfterCount,-1)<>1
       THROW 57623,N'Database DDL trigger source metadata changed during the read-only fixture.',1;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
       THROW 57609,N'Database DDL trigger caller state changed.',1;
END TRY
BEGIN CATCH
BEGIN TRY
    IF @Impersonating=1 BEGIN REVERT; SET @Impersonating=0; END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_REVERT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_ROLLBACK native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @InstallUserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_DROP_FRAMEWORK_USER native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_DROP_LOGIN native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @PositiveDbCreated=1 AND DB_ID(@PositiveDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@PositiveDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@PositiveDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_DROP_POSITIVE_DB native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @EmptyDbCreated=1 AND DB_ID(@EmptyDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@EmptyDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@EmptyDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_DROP_EMPTY_DB native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    EXEC [sys].[sp_executesql] @Sql;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_RESTORE_LOCK_TIMEOUT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'DDL_TRIGGER_CLEANUP_RESTORE_XACT_ABORT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
    THROW;
END CATCH;
BEGIN TRY
    IF @Impersonating=1 BEGIN REVERT; SET @Impersonating=0; END;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @InstallUserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @PositiveDbCreated=1 AND DB_ID(@PositiveDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@PositiveDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@PositiveDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @EmptyDbCreated=1 AND DB_ID(@EmptyDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@EmptyDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@EmptyDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    EXEC [sys].[sp_executesql] @Sql;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
END TRY BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
IF @CleanupFailure IS NOT NULL THROW 57610,@CleanupFailure,1;
PRINT N'Database DDL trigger inventory native contract passed.';
GO
