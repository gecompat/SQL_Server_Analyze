USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57600,N'Plan guide contract requires the isolated remote CI sysadmin target without an ambient transaction.',1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 57601,N'Plan guide contract requires the selected SQL Server 2025 native CI target.',1;
GO
DECLARE @Suffix nvarchar(48)=CONVERT(nvarchar(12),@@SPID)+N'_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),16),
        @PositiveDb sysname,@EmptyDb sysname,@Reader sysname,@FixtureCredential nvarchar(128),
        @PositiveDbId int,@RestrictedObserved bigint,@RestrictedNativeError int,
        @Sql nvarchar(max),@GuideBatch nvarchar(max),@Names nvarchar(max),@Json nvarchar(max),@TablePayload nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
        @OriginalLock int=@@LOCK_TIMEOUT,@OriginalTx int=@@TRANCOUNT,
        @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @Impersonating bit=0,@LoginCreated bit=0,@InstallUserCreated bit=0,
        @PositiveDbCreated bit=0,@EmptyDbCreated bit=0,
        @CleanupFailure nvarchar(2048)=NULL,@CleanupNativeError int=NULL;
SELECT @PositiveDb=N'ExamplePlanGuidePos_'+@Suffix,
       @EmptyDb=N'ExamplePlanGuideEmpty_'+@Suffix,
       @Reader=N'ExamplePlanGuideReader_'+@Suffix,
       @FixtureCredential=N'Example!'+CONVERT(nvarchar(36),NEWID());
IF DB_ID(@PositiveDb) IS NOT NULL OR DB_ID(@EmptyDb) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.server_principals WHERE [name]=@Reader)
    THROW 57602,N'Plan guide owned fixture name collision.',1;
CREATE TABLE #PlanGuideOut_moduleStatus([Seed] int NULL);
CREATE TABLE #PlanGuideOut_planGuides([Seed] int NULL);
CREATE TABLE #PlanGuideOut_sourceStatus([Seed] int NULL);
CREATE TABLE #PlanGuideOut_warnings([Seed] int NULL);
CREATE TABLE #ExpectedPlanGuides
(
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [PlanGuideId] int NOT NULL,
            [PlanGuideName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ScopeType] tinyint NOT NULL,
            [ScopeTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsDisabled] bit NOT NULL,
            [ScopeObjectId] int NULL,
            [CreateDate] datetime NOT NULL,
            [ModifyDate] datetime NOT NULL,
            [ValidationStatus] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@PositiveDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @PositiveDbCreated=1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@EmptyDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @EmptyDbCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      CREATE TABLE dbo.ExamplePlanGuideData(ExampleId int NOT NULL,ExampleValue int NULL);
      DECLARE @SqlStatement nvarchar(max)=N''SELECT ExampleValue FROM dbo.ExamplePlanGuideData WHERE ExampleId=1'',
              @ObjectStatement nvarchar(max)=N''SELECT ExampleValue FROM dbo.ExamplePlanGuideData WHERE ExampleId=2'';
      EXEC(N''CREATE PROCEDURE dbo.ExamplePlanGuideObject AS ''+@ObjectStatement);
      EXEC [sys].[sp_create_plan_guide]
          @name=N''ExamplePlanGuideSql'',@stmt=@SqlStatement,
          @type=N''SQL'',@module_or_batch=@SqlStatement,
          @params=NULL,@hints=N''OPTION (MAXDOP 1)'';
      EXEC [sys].[sp_create_plan_guide]
          @name=N''ExamplePlanGuideObject'',@stmt=@ObjectStatement,
          @type=N''OBJECT'',@module_or_batch=N''dbo.ExamplePlanGuideObject'',
          @params=NULL,@hints=N''OPTION (MAXDOP 1)'';
      DECLARE @Template nvarchar(max),@TemplateParams nvarchar(max);
      EXEC [sys].[sp_get_query_template]
           N''SELECT ExampleValue FROM dbo.ExamplePlanGuideData WHERE ExampleId=3'',
           @Template OUTPUT,@TemplateParams OUTPUT;
      IF NULLIF(@Template,N'''') IS NULL OR NULLIF(@TemplateParams,N'''') IS NULL
          THROW 57619,N''Synthetic template query was not parameterized.'',1;
      EXEC [sys].[sp_create_plan_guide]
          @name=N''ExamplePlanGuideTemplate'',@stmt=@Template,
          @type=N''TEMPLATE'',@module_or_batch=NULL,
          @params=@TemplateParams,@hints=N''OPTION (PARAMETERIZATION FORCED)'';
      EXEC [sys].[sp_control_plan_guide] N''DISABLE'',N''ExamplePlanGuideObject'';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      INSERT #ExpectedPlanGuides
        ([DatabaseId],[DatabaseName],[PlanGuideId],[PlanGuideName],[ScopeType],
         [ScopeTypeDesc],[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus])
      SELECT @Id,@Name,[plan_guide_id],[name],[scope_type],[scope_type_desc],
             [is_disabled],[scope_object_id],[create_date],[modify_date],''UNASSESSED''
      FROM [sys].[plan_guides];';
    SET @PositiveDbId=DB_ID(@PositiveDb);
    EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname',
        @Id=@PositiveDbId,@Name=@PositiveDb;
    IF (SELECT COUNT(*) FROM #ExpectedPlanGuides)<>3
       OR (SELECT COUNT(*) FROM #ExpectedPlanGuides WHERE ScopeType IN(1,2,3))<>3
       OR (SELECT COUNT(*) FROM #ExpectedPlanGuides WHERE IsDisabled=1)<>1
       THROW 57614,N'Plan guide fixture catalog setup differs from expected scope and disabled states.',1;
    SET @Names=QUOTENAME(@PositiveDb)+N'|'+QUOTENAME(@EmptyDb);
    EXEC @Return=[monitor].[USP_PlanGuideInventory]
        @DatabaseNames=@Names,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"moduleStatus":"#PlanGuideOut_moduleStatus","planGuides":"#PlanGuideOut_planGuides","sourceStatus":"#PlanGuideOut_sourceStatus","warnings":"#PlanGuideOut_warnings"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    SELECT @TablePayload=
        (SELECT * FROM #PlanGuideOut_moduleStatus FOR JSON PATH)
       +(SELECT * FROM #PlanGuideOut_planGuides FOR JSON PATH)
       +(SELECT * FROM #PlanGuideOut_sourceStatus FOR JSON PATH)
       +(SELECT * FROM #PlanGuideOut_warnings FOR JSON PATH);
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(ISJSON(@Json),0)<>1
       OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@Status
       OR COALESCE(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>'true'
       OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),-1)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]='meta' AND [type]=5)
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','planGuides','sourceStatus','warnings') AND [type]=4)<>4
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json)
           WHERE [key] NOT IN('meta','moduleStatus','planGuides','sourceStatus','warnings'))
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedPlanGuides
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #PlanGuideOut_planGuides)
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #PlanGuideOut_planGuides
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedPlanGuides)
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedPlanGuides
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,'$.planGuides') WITH
            ([DatabaseId] int,[DatabaseName] sysname,[PlanGuideId] int,[PlanGuideName] sysname,
             [ScopeType] tinyint,[ScopeTypeDesc] nvarchar(60),[IsDisabled] bit,
             [ScopeObjectId] int,[CreateDate] datetime,[ModifyDate] datetime,
             [ValidationStatus] varchar(16)))
       OR EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,'$.planGuides') WITH
            ([DatabaseId] int,[DatabaseName] sysname,[PlanGuideId] int,[PlanGuideName] sysname,
             [ScopeType] tinyint,[ScopeTypeDesc] nvarchar(60),[IsDisabled] bit,
             [ScopeObjectId] int,[CreateDate] datetime,[ModifyDate] datetime,
             [ValidationStatus] varchar(16))
                 EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PlanGuideId],[PlanGuideName] COLLATE SQL_Latin1_General_CP1_CS_AS,[ScopeType],[ScopeTypeDesc] COLLATE SQL_Latin1_General_CP1_CS_AS,[IsDisabled],[ScopeObjectId],[CreateDate],[ModifyDate],[ValidationStatus] COLLATE SQL_Latin1_General_CP1_CS_AS FROM #ExpectedPlanGuides)
       OR EXISTS(SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#PlanGuideOut_planGuides')
                 EXCEPT
                 SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedPlanGuides'))
       OR EXISTS(SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedPlanGuides')
                 EXCEPT
                 SELECT [name],[system_type_id],[max_length],[is_nullable],[collation_name]
                 FROM tempdb.sys.columns
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#PlanGuideOut_planGuides'))
       OR NOT EXISTS(SELECT 1 FROM #PlanGuideOut_sourceStatus
                     WHERE DatabaseName=@PositiveDb AND SourceKey='PLAN_GUIDES_CATALOG'
                       AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=3
                       AND ReturnedRows=3 AND IsLimited=0 AND ErrorNumber IS NULL)
       OR NOT EXISTS(SELECT 1 FROM #PlanGuideOut_sourceStatus
                     WHERE DatabaseName=@EmptyDb AND SourceKey='PLAN_GUIDES_CATALOG'
                       AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=0
                       AND ReturnedRows=0 AND IsLimited=0 AND ErrorNumber IS NULL)
       OR @TablePayload IS NULL
       OR CHARINDEX(N'ExamplePlanGuideData',@Json)>0
       OR CHARINDEX(N'OPTION (MAXDOP 1)',@Json)>0
       OR CHARINDEX(N'PARAMETERIZATION FORCED',@Json)>0
       OR CHARINDEX(N'ExampleId=1',@Json)>0
       OR CHARINDEX(N'ExampleId=2',@Json)>0
       OR CHARINDEX(N'ExampleId=3',@Json)>0
       OR CHARINDEX(N'ExamplePlanGuideData',@TablePayload)>0
       OR CHARINDEX(N'OPTION (MAXDOP 1)',@TablePayload)>0
       OR CHARINDEX(N'PARAMETERIZATION FORCED',@TablePayload)>0
       OR CHARINDEX(N'ExampleId=1',@TablePayload)>0
       OR CHARINDEX(N'ExampleId=2',@TablePayload)>0
       OR CHARINDEX(N'ExampleId=3',@TablePayload)>0
       THROW 57603,N'Plan guide positive TABLE/JSON/catalog contract failed.',1;
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    SET @Names=QUOTENAME(@EmptyDb);
    EXEC @Return=[monitor].[USP_PlanGuideInventory]
        @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,
        @Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,
        @ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(ISJSON(@Json),0)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','planGuides','sourceStatus','warnings') AND [type]=4)<>4
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.planGuides'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
              WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                   ObservedRows bigint,ReturnedRows bigint,IsLimited bit,ErrorNumber int)
              WHERE DatabaseName=@EmptyDb AND SourceKey='PLAN_GUIDES_CATALOG'
                AND StatusCode='AVAILABLE_LIMITED' AND ObservedRows=0 AND ReturnedRows=0
                AND IsLimited=0 AND ErrorNumber IS NULL)
       THROW 57605,N'Plan guide visible-empty contract failed.',1;
    SELECT @Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_PlanGuideInventory]
        @DatabaseNames=@Names,@MaxZeilen=-1,@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>51011) OR COALESCE(@Status,'')<>'INVALID_PARAMETER' OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,-1)<>51011
       THROW 57606,N'Plan guide negative limit acceptance failed.',1;
    SELECT @Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_PlanGuideInventory]
        @DatabaseNames=@Names,@ResultSetArt='TABLE',@ResultTablesJson=N'{"unknown":"#PlanGuideOut_planGuides"}',
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>51011) OR COALESCE(@Status,'')<>'ERROR_HANDLED' OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,-1)<>51011
       THROW 57607,N'Plan guide invalid TABLE mapping failed.',1;
    SET @Names=QUOTENAME(@PositiveDb);
    SET @Sql=N'BEGIN TRANSACTION; SET XACT_ABORT ON; SET LOCK_TIMEOUT 7000;
      EXEC @R=[monitor].[USP_PlanGuideInventory]
          @DatabaseNames=@N,@MaxZeilen=1,@ResultSetArt=''NONE'',
          @JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@S OUTPUT,@IsPartialOut=@P OUTPUT,
          @ErrorNumberOut=@E OUTPUT,@ErrorMessageOut=@M OUTPUT;
      IF @@TRANCOUNT<>@ExpectedTx+1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>7000
         OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>1
         OR @R IS NULL OR @R<>0 OR COALESCE(@S,'''')<>''AVAILABLE_LIMITED''
         THROW 57612,N''Plan guide inner caller state changed.'',1;
      ROLLBACK TRANSACTION;
      IF @@TRANCOUNT<>@ExpectedTx OR XACT_STATE()<>0 OR @@LOCK_TIMEOUT<>7000
         OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>1
         THROW 57618,N''Plan guide inner rollback or caller state changed.'',1;';
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL,@Return=NULL;
    EXEC [sys].[sp_executesql] @Sql,
        N'@N nvarchar(max),@R int OUTPUT,@J nvarchar(max) OUTPUT,@S varchar(40) OUTPUT,
          @P bit OUTPUT,@E int OUTPUT,@M nvarchar(2048) OUTPUT,@ExpectedTx int',
        @N=@Names,@R=@Return OUTPUT,@J=@Json OUTPUT,@S=@Status OUTPUT,@P=@Partial OUTPUT,
        @E=@Error OUTPUT,@M=@Message OUTPUT,@ExpectedTx=@OriginalTx;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED'
       OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.planGuides'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings')
            WITH(WarningCode varchar(64)) WHERE WarningCode='OUTPUT_LIMIT')
       OR @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
       THROW 57613,N'Plan guide limit or caller-option restoration failed.',1;
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)+N' WITH PASS'+N'WORD='+QUOTENAME(@FixtureCredential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N'; GRANT EXECUTE ON [monitor].[USP_PlanGuideInventory] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @InstallUserCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N'; CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@EmptyDb)+N'; CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    SET @Names=QUOTENAME(@PositiveDb)+N'|'+QUOTENAME(@EmptyDb);
    SELECT @RestrictedObserved=NULL,@RestrictedNativeError=NULL;
    BEGIN TRY
        SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
          SELECT @Rows=COUNT_BIG(*) FROM [sys].[plan_guides];';
        EXEC [sys].[sp_executesql] @Sql,N'@Rows bigint OUTPUT',
            @Rows=@RestrictedObserved OUTPUT;
    END TRY
    BEGIN CATCH
        SET @RestrictedNativeError=ERROR_NUMBER();
    END CATCH;
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC @Return=[monitor].[USP_PlanGuideInventory]
        @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (@Return IS NULL OR @Return<>0) OR COALESCE(@Partial,0)<>1
       OR COALESCE(ISJSON(@Json),0)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)
           WHERE [key] IN('moduleStatus','planGuides','sourceStatus','warnings') AND [type]=4)<>4
       OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>COALESCE(@Status,'')
       THROW 57608,N'Plan guide restricted-caller JSON/status contract failed.',1;
    IF @RestrictedNativeError IS NULL
    BEGIN
        IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR @Error IS NOT NULL
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.planGuides'))<>@RestrictedObserved
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
                WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                     ObservedRows bigint,ReturnedRows bigint)
                WHERE DatabaseName=@PositiveDb AND SourceKey='PLAN_GUIDES_CATALOG'
                  AND StatusCode='AVAILABLE_LIMITED'
                  AND ObservedRows=@RestrictedObserved AND ReturnedRows=@RestrictedObserved)
           THROW 57615,N'Plan guide restricted visible-source contract failed.',1;
    END
    ELSE IF @RestrictedNativeError IN(229,297,300,371)
    BEGIN
        IF COALESCE(@Status,'')<>'DENIED_PERMISSION'
           OR COALESCE(@Error,-1)<>@RestrictedNativeError
           OR @Message IS NULL
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.planGuides'))
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus')
                WITH(DatabaseName nvarchar(128),SourceKey varchar(64),StatusCode varchar(40),
                     ObservedRows bigint,ReturnedRows bigint,ErrorNumber int)
                WHERE DatabaseName=@PositiveDb AND SourceKey='PLAN_GUIDES_CATALOG'
                  AND StatusCode='DENIED_PERMISSION' AND ObservedRows IS NULL
                  AND ReturnedRows IS NULL AND ErrorNumber=@RestrictedNativeError)
           THROW 57616,N'Plan guide restricted native-denial contract failed.',1;
    END
    ELSE
        THROW 57617,N'Plan guide restricted native source failed outside the tested permission boundary.',1;
    REVERT;
    SET @Impersonating=0;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
       THROW 57609,N'Plan guide caller state changed.',1;
END TRY
BEGIN CATCH
BEGIN TRY
    IF @Impersonating=1 BEGIN REVERT; SET @Impersonating=0; END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_REVERT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_ROLLBACK native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @InstallUserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_DROP_FRAMEWORK_USER native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_DROP_LOGIN native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @PositiveDbCreated=1 AND DB_ID(@PositiveDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@PositiveDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@PositiveDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_DROP_POSITIVE_DB native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @EmptyDbCreated=1 AND DB_ID(@EmptyDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@EmptyDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@EmptyDb)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_DROP_EMPTY_DB native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    EXEC [sys].[sp_executesql] @Sql;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_RESTORE_LOCK_TIMEOUT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
END CATCH;
BEGIN TRY
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
END TRY BEGIN CATCH
    SET @CleanupNativeError=ERROR_NUMBER();
    RAISERROR(N'PLAN_GUIDE_CLEANUP_RESTORE_XACT_ABORT native=%d',10,1,@CleanupNativeError) WITH NOWAIT;
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
PRINT N'Plan guide inventory native contract passed.';
GO
