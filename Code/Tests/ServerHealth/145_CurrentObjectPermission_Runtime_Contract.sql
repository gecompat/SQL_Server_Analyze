USE [DeineDatenbank];
GO
IF OBJECT_ID(N'tempdb..#ExampleCurrentObjectPermissionContract') IS NOT NULL THROW 63050,N'OBJECT_FIXTURE_COLLISION',1;
GO
CREATE PROCEDURE [#ExampleCurrentObjectPermissionContract]
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @OriginalDb int=DB_ID(),@OriginalLock int=@@LOCK_TIMEOUT,@OriginalTx int=@@TRANCOUNT,
  @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
  @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
  @DbA sysname,@DbB sysname,@Login sysname,@FrameworkUser sysname,@DbUser sysname,
  @FrameworkUserId int,@FrameworkUserSid varbinary(85),@LoginId int,@ExpectedSid varbinary(16)=CRYPT_GEN_RANDOM(16),
  @DbAId int,@DbBId int,@DbAGuid uniqueidentifier,@DbBGuid uniqueidentifier,
  @LoginMade bit=0,@FrameworkUserMade bit=0,@DbAMade bit=0,@DbBMade bit=0,
  @Credential nvarchar(128),@Sql nvarchar(max),@Names nvarchar(max),@Json nvarchar(max),@Map nvarchar(max),
   @Long120 nvarchar(max)=REPLICATE(N'X',120),@Long121 nvarchar(max)=REPLICATE(N'X',121),
  @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Ret int,@ProbeError int,
  @NativeCountA bigint,@NativeCountB bigint,@Failure int=NULL,@CleanupError int=NULL,
  @BeforeXact int,@AfterXact int,@BeforeTran int,@AfterTran int,@Pairs int=0;
 DECLARE @FrameworkDb sysname=DB_NAME(@OriginalDb);
 IF @FrameworkDb IS NULL THROW 63207,N'OBJECT_FIXTURE_FRAMEWORK_DB_UNBOUND',1;
 IF @OriginalTx<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1 THROW 63051,N'OBJECT_FIXTURE_REQUIRES_ISOLATED_SYSADMIN',1;
 SELECT @DbA=N'ExampleObjectA|'+@Suffix,@DbB=N'ExampleObjectB]'+@Suffix,
  @Login=N'ExampleObjectLogin_'+@Suffix,@FrameworkUser=N'ExampleObjectFramework_'+@Suffix,@DbUser=N'ExampleObjectUser_'+@Suffix;
 SET @Names=QUOTENAME(@DbA)+N'|'+QUOTENAME(@DbB);
 CREATE TABLE [#ExampleObject_OwnDatabases]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseGuid] uniqueidentifier NULL);
 CREATE TABLE [#ExampleObject_Native]
 ([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE [#ExampleObject_moduleStatus]([Seed] int NULL);
 CREATE TABLE [#ExampleObject_callerContexts]([Seed] int NULL);
 CREATE TABLE [#ExampleObject_objectPermissions]([Seed] int NULL);
 CREATE TABLE [#ExampleObject_sourceStatus]([Seed] int NULL);
 CREATE TABLE [#ExampleObject_warnings]([Seed] int NULL);
 CREATE TABLE [#ExampleObject_Expected_moduleStatus]
 ([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE [#ExampleObject_Expected_callerContexts]
 ([SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContextDatabaseId] int NOT NULL,[ServerPrincipalId] int NULL,[DatabasePrincipalId] int NULL,[ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL);
 CREATE TABLE [#ExampleObject_Expected_objectPermissions]
 ([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 CREATE TABLE [#ExampleObject_Expected_sourceStatus]
 ([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StartedAtUtc] datetime2(3) NOT NULL,[CompletedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedRows] bigint NULL,[ReturnedRows] bigint NULL,[IsLimited] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#ExampleObject_Expected_warnings]
 ([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM [sys].[databases] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS IN (@DbA COLLATE SQL_Latin1_General_CP1_CS_AS,@DbB COLLATE SQL_Latin1_General_CP1_CS_AS))
   OR EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS)
   OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS)
   THROW 63052,N'OBJECT_FIXTURE_PRINCIPAL_COLLISION',1;
  SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
  SET @Sql=N'USE [master];CREATE LOGIN '+QUOTENAME(@Login)+N' WITH PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N',SID='+CONVERT(varchar(34),@ExpectedSid,1)+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
  EXEC [master].[sys].[sp_executesql] @Sql;SET @LoginMade=1;SET @Credential=NULL;SET @Sql=NULL;
  SELECT @LoginId=[principal_id] FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@ExpectedSid;
  IF @LoginId IS NULL THROW 63053,N'OBJECT_FIXTURE_LOGIN_BINDING',1;
  SET @Sql=N'USE [master];GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
  SET @Sql=N'CREATE USER '+QUOTENAME(@FrameworkUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';
  EXEC [sys].[sp_executesql] @Sql;SET @FrameworkUserMade=1;
  SELECT @FrameworkUserId=[principal_id],@FrameworkUserSid=[sid] FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@ExpectedSid;
  IF @FrameworkUserId IS NULL OR @FrameworkUserSid<>@ExpectedSid THROW 63054,N'OBJECT_FIXTURE_FRAMEWORK_USER_BINDING',1;
  SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_CurrentObjectPermissionAnalysis] TO '+QUOTENAME(@FrameworkUser)+N';';EXEC [sys].[sp_executesql] @Sql;
  INSERT [#ExampleObject_OwnDatabases] VALUES(@DbA,NULL,NULL),(@DbB,NULL,NULL);
  SET @Sql=N'USE [master];CREATE DATABASE '+QUOTENAME(@DbA)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';EXEC [master].[sys].[sp_executesql] @Sql;SET @DbAMade=1;
  SELECT @DbAId=[d].[database_id],@DbAGuid=[r].[database_guid] FROM [sys].[databases] AS [d] JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id] WHERE [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@DbA COLLATE SQL_Latin1_General_CP1_CS_AS;
  UPDATE [#ExampleObject_OwnDatabases] SET [DatabaseId]=@DbAId,[DatabaseGuid]=@DbAGuid WHERE [DatabaseName]=@DbA COLLATE SQL_Latin1_General_CP1_CS_AS;
  IF @DbAId IS NULL OR @DbAGuid IS NULL THROW 63055,N'OBJECT_FIXTURE_DATABASE_A_BINDING',1;
  SET @Sql=N'USE [master];CREATE DATABASE '+QUOTENAME(@DbB)+N' COLLATE Latin1_General_100_CI_AS;';EXEC [master].[sys].[sp_executesql] @Sql;SET @DbBMade=1;
  SELECT @DbBId=[d].[database_id],@DbBGuid=[r].[database_guid] FROM [sys].[databases] AS [d] JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id] WHERE [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@DbB COLLATE SQL_Latin1_General_CP1_CS_AS;
  UPDATE [#ExampleObject_OwnDatabases] SET [DatabaseId]=@DbBId,[DatabaseGuid]=@DbBGuid WHERE [DatabaseName]=@DbB COLLATE SQL_Latin1_General_CP1_CS_AS;
  IF @DbBId IS NULL OR @DbBGuid IS NULL THROW 63056,N'OBJECT_FIXTURE_DATABASE_B_BINDING',1;
  SET @Sql=N'USE '+QUOTENAME(@DbA)+N';CREATE USER '+QUOTENAME(@DbUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';CREATE TABLE [dbo].[ExampleObjectProbe]([Value] int NOT NULL,[OtherValue] int NULL);GRANT SELECT ON OBJECT::[dbo].[ExampleObjectProbe] TO '+QUOTENAME(@DbUser)+N';';
  EXEC [sys].[sp_executesql] @Sql;
  SET @Sql=N'USE '+QUOTENAME(@DbB)+N';CREATE USER '+QUOTENAME(@DbUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';CREATE TABLE [dbo].[ExampleObjectProbe]([Value] int NOT NULL,[OtherValue] int NULL);DENY SELECT ON OBJECT::[dbo].[ExampleObjectProbe] TO '+QUOTENAME(@DbUser)+N';';
  EXEC [sys].[sp_executesql] @Sql;
  SET @Sql=N'USE '+QUOTENAME(@DbA)+N';CREATE TABLE [dbo].'+QUOTENAME(@Long120)+N'([Value] int NOT NULL);GRANT SELECT ON OBJECT::[dbo].'+QUOTENAME(@Long120)+N' TO '+QUOTENAME(@DbUser)+N';';EXEC [sys].[sp_executesql] @Sql;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbA)+N';SELECT @Rows=COUNT_BIG(*) FROM [sys].[fn_my_permissions](@Qualified,N''OBJECT'') WHERE [permission_name]=N''SELECT'';USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH USE '+QUOTENAME(@FrameworkDb)+N';REVERT;THROW;END CATCH;';
  SET @NativeCountA=NULL;DECLARE @LongQualified sysname=CONVERT(sysname,N'[dbo].'+QUOTENAME(@Long120));
  EXEC [sys].[sp_executesql] @Sql,N'@Qualified sysname,@Rows bigint OUTPUT',@Qualified=@LongQualified,@Rows=@NativeCountA OUTPUT;
  IF COALESCE(@NativeCountA,0)=0 THROW 63204,N'OBJECT_FIXTURE_128_NATIVE_POSITIVE',1;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Rc=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N''dbo'',@ObjectName=@Obj,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
  SET @Json=NULL;SET @Ret=NULL;SET @Status=NULL;DECLARE @OnlyA nvarchar(max)=QUOTENAME(@DbA);
  EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Obj nvarchar(max),@Rc int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT',@Names=@OnlyA,@Obj=@Long120,@Rc=@Ret OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT;
  IF COALESCE(@Ret,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR ISJSON(@Json)<>1
     OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.objectPermissions') WITH([PermissionName] nvarchar(128)) WHERE [PermissionName]=N'SELECT')
    THROW 63205,N'OBJECT_FIXTURE_128_PRODUCT_POSITIVE',1;
  SET @Json=N'pre';SET @Ret=NULL;SET @Status=NULL;
  EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Obj nvarchar(max),@Rc int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT',@Names=@OnlyA,@Obj=@Long121,@Rc=@Ret OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT;
  IF COALESCE(@Ret,-1)<>51011 OR COALESCE(@Status,'')<>'INVALID_PARAMETER' OR @Json IS NOT NULL
    THROW 63206,N'OBJECT_FIXTURE_129_QUALIFIED_REJECTED',1;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbA)+N';SELECT TOP(0) [Value] FROM [dbo].[ExampleObjectProbe];USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH USE '+QUOTENAME(@FrameworkDb)+N';REVERT;THROW;END CATCH;';
  EXEC [sys].[sp_executesql] @Sql;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbB)+N';BEGIN TRY SELECT TOP(0) [Value] FROM [dbo].[ExampleObjectProbe];END TRY BEGIN CATCH SET @Err=ERROR_NUMBER();END CATCH;USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH USE '+QUOTENAME(@FrameworkDb)+N';REVERT;THROW;END CATCH;';
  SET @ProbeError=NULL;EXEC [sys].[sp_executesql] @Sql,N'@Err int OUTPUT',@Err=@ProbeError OUTPUT;
  IF COALESCE(@ProbeError,0)<>229 THROW 63057,N'OBJECT_FIXTURE_DIRECT_DENY_229',1;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbA)+N';INSERT [#ExampleObject_Native] SELECT @Id,@Name,N''dbo'',N''ExampleObjectProbe'',[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM sys.fn_my_permissions(N''[dbo].[ExampleObjectProbe]'',N''OBJECT'');USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH USE '+QUOTENAME(@FrameworkDb)+N';REVERT;THROW;END CATCH;';
  EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname',@Id=@DbAId,@Name=@DbA;
  SET @NativeCountA=(SELECT COUNT_BIG(*) FROM [#ExampleObject_Native] WHERE [DatabaseId]=@DbAId);
  IF @NativeCountA=0 OR NOT EXISTS(SELECT 1 FROM [#ExampleObject_Native] WHERE [DatabaseId]=@DbAId AND [PermissionName]=N'SELECT') THROW 63058,N'OBJECT_FIXTURE_NATIVE_POSITIVE',1;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbB)+N';INSERT [#ExampleObject_Native] SELECT @Id,@Name,N''dbo'',N''ExampleObjectProbe'',[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM sys.fn_my_permissions(N''[dbo].[ExampleObjectProbe]'',N''OBJECT'');USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH SET @Err=ERROR_NUMBER();USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END CATCH;';
  SET @ProbeError=NULL;EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Err int OUTPUT',@Id=@DbBId,@Name=@DbB,@Err=@ProbeError OUTPUT;
  SET @NativeCountB=(SELECT COUNT_BIG(*) FROM [#ExampleObject_Native] WHERE [DatabaseId]=@DbBId);
  IF @ProbeError IS NULL AND EXISTS(SELECT 1 FROM [#ExampleObject_Native] WHERE [DatabaseId]=@DbBId AND [PermissionName]=N'SELECT') THROW 63059,N'OBJECT_FIXTURE_DENY_REPORTED_SELECT',1;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N''dbo'',@ObjectName=N''ExampleObjectProbe'',@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT,@IsPartialOut=@Part OUTPUT,@ErrorNumberOut=@Er OUTPUT,@ErrorMessageOut=@Msg OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
  EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT,@Part bit OUTPUT,@Er int OUTPUT,@Msg nvarchar(2048) OUTPUT',@Names=@Names,@Ret=@Ret OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT,@Part=@Partial OUTPUT,@Er=@Error OUTPUT,@Msg=@Message OUTPUT;
  IF COALESCE(@Ret,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1 OR ISJSON(@Json)<>1 THROW 63060,N'OBJECT_FIXTURE_RESTRICTED_STATUS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>6
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'meta' AND [type]=5)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'moduleStatus' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'callerContexts' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'objectPermissions' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'sourceStatus' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@Json) WHERE [key]=N'warnings' AND [type]=4)<>1
   THROW 63061,N'OBJECT_FIXTURE_JSON_GROUPS',1;
  IF EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,N'$.objectPermissions') WITH([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,[EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128))
       EXCEPT SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName] FROM [#ExampleObject_Native])
   OR EXISTS(SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName] FROM [#ExampleObject_Native] EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,N'$.objectPermissions') WITH([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,[EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128)))
   THROW 63062,N'OBJECT_FIXTURE_NATIVE_ROW_PARITY',1;
  IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ErrorNumber] int) WHERE [DatabaseId]=@DbAId AND [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode]='AVAILABLE_LIMITED' AND [ObservedRows]=@NativeCountA AND [ErrorNumber] IS NULL)
   THROW 63063,N'OBJECT_FIXTURE_SOURCE_A_STATUS',1;
  IF @ProbeError IS NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ErrorNumber] int) WHERE [DatabaseId]=@DbBId AND [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode]=CASE WHEN @NativeCountB=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END AND [ObservedRows]=@NativeCountB AND [ErrorNumber] IS NULL)
   THROW 63064,N'OBJECT_FIXTURE_SOURCE_B_STATUS',1;
  IF @ProbeError IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ErrorNumber] int) WHERE [DatabaseId]=@DbBId AND [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode]=CASE WHEN @ProbeError IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN @ProbeError=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END AND [ObservedRows] IS NULL AND [ErrorNumber]=@ProbeError)
   THROW 63065,N'OBJECT_FIXTURE_SOURCE_B_ERROR',1;
  IF @ProbeError IS NOT NULL AND (COALESCE(@Error,-1)<>@ProbeError OR NULLIF(@Message,N'') IS NULL) THROW 63158,N'OBJECT_FIXTURE_NATIVE_ERROR_OUTPUT',1;
  SET @Map=N'{"moduleStatus":"#ExampleObject_moduleStatus","callerContexts":"#ExampleObject_callerContexts","objectPermissions":"#ExampleObject_objectPermissions","sourceStatus":"#ExampleObject_sourceStatus","warnings":"#ExampleObject_warnings"}';
  SET LOCK_TIMEOUT 43;SET XACT_ABORT ON;BEGIN TRANSACTION;SELECT @BeforeXact=XACT_STATE();SELECT @BeforeTran=@@TRANCOUNT;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
  SELECT @AfterXact=XACT_STATE();SELECT @AfterTran=@@TRANCOUNT;
  IF COALESCE(@Ret,-1)<>0 OR COALESCE(@Partial,0)<>1 OR ISJSON(@Json)<>1 OR @@LOCK_TIMEOUT<>43 OR (@@OPTIONS&16384)<>16384 OR @BeforeXact<>1 OR @AfterXact<>1 OR @BeforeTran<>1 OR @AfterTran<>1 OR DB_ID()<>@OriginalDb THROW 63066,N'OBJECT_FIXTURE_TABLE_CALLER',1;
  IF (SELECT COUNT_BIG(*) FROM [#ExampleObject_objectPermissions])<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions')) OR (SELECT [RowCount] FROM [#ExampleObject_moduleStatus])<>(SELECT COUNT_BIG(*) FROM [#ExampleObject_objectPermissions]) THROW 63067,N'OBJECT_FIXTURE_TABLE_ROWS',1;
  CREATE TABLE [#ExampleObject_ShapePairs]([ResultName] sysname,[Actual] sysname,[Expected] sysname);
  INSERT [#ExampleObject_ShapePairs] VALUES
  (N'moduleStatus',N'#ExampleObject_moduleStatus',N'#ExampleObject_Expected_moduleStatus'),
  (N'callerContexts',N'#ExampleObject_callerContexts',N'#ExampleObject_Expected_callerContexts'),
  (N'objectPermissions',N'#ExampleObject_objectPermissions',N'#ExampleObject_Expected_objectPermissions'),
  (N'sourceStatus',N'#ExampleObject_sourceStatus',N'#ExampleObject_Expected_sourceStatus'),
  (N'warnings',N'#ExampleObject_warnings',N'#ExampleObject_Expected_warnings');
  ;WITH [Facets] AS
  (SELECT [p].[ResultName],[v].[Kind],CONVERT(int,ROW_NUMBER() OVER(PARTITION BY [p].[ResultName],[v].[Kind] ORDER BY [c].[column_id])) [Ordinal],
   [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS [Name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS [CollationName],[c].[is_nullable]
   FROM [#ExampleObject_ShapePairs] [p] CROSS APPLY (VALUES(N'ACTUAL',[p].[Actual]),(N'EXPECTED',[p].[Expected])) [v]([Kind],[TableName])
   JOIN [tempdb].[sys].[columns] [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[v].[TableName]))
  SELECT @Pairs=COUNT(*) FROM [Facets];
  IF @Pairs<>(8+8+7+13+5)*2 THROW 63068,N'OBJECT_FIXTURE_SCHEMA_COUNT',1;
  ;WITH [Facets] AS
  (SELECT [p].[ResultName],[v].[Kind],CONVERT(int,ROW_NUMBER() OVER(PARTITION BY [p].[ResultName],[v].[Kind] ORDER BY [c].[column_id])) [Ordinal],
   [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS [Name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS [CollationName],[c].[is_nullable]
   FROM [#ExampleObject_ShapePairs] [p] CROSS APPLY (VALUES(N'ACTUAL',[p].[Actual]),(N'EXPECTED',[p].[Expected])) [v]([Kind],[TableName])
   JOIN [tempdb].[sys].[columns] [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[v].[TableName]))
  SELECT @Pairs=COUNT(*) FROM [Facets] [a] WHERE [a].[Kind]=N'ACTUAL' AND NOT EXISTS(SELECT 1 FROM [Facets] [e] WHERE [e].[Kind]=N'EXPECTED' AND [e].[ResultName]=[a].[ResultName] AND [e].[Ordinal]=[a].[Ordinal] AND [e].[Name]=[a].[Name] AND [e].[system_type_id]=[a].[system_type_id] AND [e].[max_length]=[a].[max_length] AND [e].[precision]=[a].[precision] AND [e].[scale]=[a].[scale] AND COALESCE([e].[CollationName],N'')=COALESCE([a].[CollationName],N'') AND [e].[is_nullable]=[a].[is_nullable]);
  IF @Pairs<>0 THROW 63069,N'OBJECT_FIXTURE_SCHEMA_FACETS',1;
  DECLARE @ExpectedJson nvarchar(max);
  SET @ExpectedJson=(SELECT * FROM [#ExampleObject_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF DATALENGTH(@ExpectedJson)<>DATALENGTH(JSON_QUERY(@Json,N'$.moduleStatus')) OR @ExpectedJson COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.moduleStatus') COLLATE SQL_Latin1_General_CP1_CS_AS THROW 63075,N'OBJECT_FIXTURE_JSON_MODULE_PARITY',1;
  SET @ExpectedJson=(SELECT * FROM [#ExampleObject_callerContexts] ORDER BY [DatabaseId],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF DATALENGTH(@ExpectedJson)<>DATALENGTH(JSON_QUERY(@Json,N'$.callerContexts')) OR @ExpectedJson COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.callerContexts') COLLATE SQL_Latin1_General_CP1_CS_AS THROW 63076,N'OBJECT_FIXTURE_JSON_CONTEXT_PARITY',1;
  SET @ExpectedJson=(SELECT * FROM [#ExampleObject_objectPermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF DATALENGTH(@ExpectedJson)<>DATALENGTH(JSON_QUERY(@Json,N'$.objectPermissions')) OR @ExpectedJson COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.objectPermissions') COLLATE SQL_Latin1_General_CP1_CS_AS THROW 63077,N'OBJECT_FIXTURE_JSON_OBJECT_PARITY',1;
  SET @ExpectedJson=(SELECT * FROM [#ExampleObject_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF DATALENGTH(@ExpectedJson)<>DATALENGTH(JSON_QUERY(@Json,N'$.sourceStatus')) OR @ExpectedJson COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.sourceStatus') COLLATE SQL_Latin1_General_CP1_CS_AS THROW 63078,N'OBJECT_FIXTURE_JSON_SOURCE_PARITY',1;
  SET @ExpectedJson=(SELECT * FROM [#ExampleObject_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF DATALENGTH(@ExpectedJson)<>DATALENGTH(JSON_QUERY(@Json,N'$.warnings')) OR @ExpectedJson COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.warnings') COLLATE SQL_Latin1_General_CP1_CS_AS THROW 63079,N'OBJECT_FIXTURE_JSON_WARNING_PARITY',1;
  ROLLBACK TRANSACTION;
  SELECT @AfterXact=XACT_STATE();SELECT @AfterTran=@@TRANCOUNT;
  IF @AfterXact<>0 OR @AfterTran<>0 THROW 63074,N'OBJECT_FIXTURE_ROLLBACK_STATE',1;
  SET XACT_ABORT OFF;SET LOCK_TIMEOUT 0;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
  IF COALESCE(@Ret,-1)<>0 OR ISJSON(@Json)<>1 OR COALESCE(@Partial,0)<>1 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions'))<2 THROW 63150,N'OBJECT_FIXTURE_NULL_LIMIT',1;
  DECLARE @UnlimitedCount bigint=(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions'));
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF COALESCE(@Ret,-1)<>0 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions'))<>@UnlimitedCount THROW 63151,N'OBJECT_FIXTURE_ZERO_LIMIT',1;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF COALESCE(@Ret,-1)<>0 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions'))<>1
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64),[ObservedRows] bigint) WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [ObservedRows] IS NOT NULL)<>2
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64),[IsLimited] bit) WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [IsLimited]=1)
   THROW 63152,N'OBJECT_FIXTURE_GLOBAL_LIMIT',1;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @Hilfe=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT;
  IF COALESCE(@Ret,-1)<>0 OR @Status<>'AVAILABLE' OR COALESCE(@Partial,1)<>0 OR @Json IS NOT NULL OR @Error IS NOT NULL THROW 63153,N'OBJECT_FIXTURE_HELP_BEFORE_WORK',1;
  DECLARE @Case int=0,@CaseSchema nvarchar(max),@CaseObject nvarchar(max),@CaseMode varchar(16);
  WHILE @Case<7
  BEGIN
   SELECT @CaseSchema=CASE WHEN @Case=0 THEN NULL WHEN @Case=2 THEN N'' WHEN @Case=3 THEN REPLICATE(N'S',129) WHEN @Case=4 THEN REPLICATE(N'S',70) ELSE N'dbo' END,
    @CaseObject=CASE WHEN @Case=1 THEN NULL WHEN @Case=4 THEN REPLICATE(N'O',70) WHEN @Case=5 THEN N'' ELSE N'ExampleObjectProbe' END,
    @CaseMode=CASE WHEN @Case=6 THEN 'FOREIGN' ELSE 'NONE' END;
   EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=@CaseSchema,@ObjectName=@CaseObject,@ResultSetArt=@CaseMode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
   IF COALESCE(@Ret,-1)<>51011 OR COALESCE(@Status,'')<>'INVALID_PARAMETER' OR COALESCE(@Partial,0)<>1 OR COALESCE(@Error,0)<>51011 OR NULLIF(@Message,N'') IS NULL OR @Json IS NOT NULL OR @@LOCK_TIMEOUT<>0 OR @@TRANCOUNT<>0 THROW 63154,N'OBJECT_FIXTURE_INVALID_INPUT',1;
   SET @Case+=1;
  END;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
  IF COALESCE(@Ret,-1)<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL THROW 63155,N'OBJECT_FIXTURE_NEGATIVE_LIMIT',1;
  EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=1,@ResultSetArt='RAW',@PrintMeldungen=0;
  EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'ExampleObjectProbe',@ResultSetArt='NONE',@PrintMeldungen=0 WITH RESULT SETS NONE;
  IF COALESCE(@Ret,-1)<>0 THROW 63157,N'OBJECT_FIXTURE_NONE_MODE',1;
  EXEC @Ret=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N'dbo',@ObjectName=N'NoSuchObject',@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
  IF COALESCE(@Ret,-1)<>0 OR ISJSON(@Json)<>1 OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40)) WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode] NOT IN ('EMPTY_UNPROVEN','ERROR_HANDLED')) THROW 63156,N'OBJECT_FIXTURE_UNPROVEN_MISSING',1;

  -- Dieselbe Schreibvariante wird ausschließlich im Ziel mit CI-Collation aufgelöst.
  SET @Sql=N'USE '+QUOTENAME(@DbA)+N';CREATE TABLE [dbo].[ExampleCaseProbe]([Value] int NOT NULL);GRANT SELECT ON OBJECT::[dbo].[ExampleCaseProbe] TO '+QUOTENAME(@DbUser)+N';'
    +N'USE '+QUOTENAME(@DbB)+N';CREATE TABLE [dbo].[ExampleCaseProbe]([Value] int NOT NULL);GRANT SELECT ON OBJECT::[dbo].[ExampleCaseProbe] TO '+QUOTENAME(@DbUser)+N';';
  EXEC [sys].[sp_executesql] @Sql;

  DECLARE @CaseTarget sysname=N'[dbo].[examplecaseprobe]',@ExactTarget sysname=N'[dbo].[ExampleCaseProbe]',
    @CaseObjectA int,@CaseObjectB int,@ExactObjectA int,@ExactObjectB int,@CaseNativeError int=NULL,@CaseNativeRows bigint;
  DELETE FROM [#ExampleObject_Native];
  DECLARE @CaseNativeSql nvarchar(max)=N';SELECT @ExactId=OBJECT_ID(@Exact,N''U''),@CaseId=OBJECT_ID(@Target,N''U'');
   BEGIN TRY
    INSERT [#ExampleObject_Native]
    SELECT @Id,@Name,N''dbo'',N''examplecaseprobe'',[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name])
    FROM [sys].[fn_my_permissions](@Target,N''OBJECT'');
   END TRY BEGIN CATCH SET @Err=ERROR_NUMBER();END CATCH;
   USE '+QUOTENAME(@FrameworkDb)+N';REVERT;END TRY BEGIN CATCH USE '+QUOTENAME(@FrameworkDb)+N';REVERT;THROW;END CATCH;';
  DECLARE @CaseNativeParams nvarchar(400)=N'@Id int,@Name sysname,@Exact sysname,@Target sysname,@ExactId int OUTPUT,@CaseId int OUTPUT,@Err int OUTPUT';
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbA)+@CaseNativeSql;
  EXEC [sys].[sp_executesql] @Sql,@CaseNativeParams,@Id=@DbAId,@Name=@DbA,@Exact=@ExactTarget,@Target=@CaseTarget,@ExactId=@ExactObjectA OUTPUT,@CaseId=@CaseObjectA OUTPUT,@Err=@CaseNativeError OUTPUT;
  IF @ExactObjectA IS NULL OR @CaseObjectA IS NOT NULL OR @CaseNativeError IN (229,297,300,371,916,1222)
    OR EXISTS(SELECT 1 FROM [#ExampleObject_Native]) THROW 63208,N'OBJECT_FIXTURE_CASE_SENSITIVE_NATIVE',1;

  SET @ProbeError=NULL;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY USE '+QUOTENAME(@DbB)+@CaseNativeSql;
  EXEC [sys].[sp_executesql] @Sql,@CaseNativeParams,@Id=@DbBId,@Name=@DbB,@Exact=@ExactTarget,@Target=@CaseTarget,@ExactId=@ExactObjectB OUTPUT,@CaseId=@CaseObjectB OUTPUT,@Err=@ProbeError OUTPUT;
  SELECT @CaseNativeRows=COUNT_BIG(*) FROM [#ExampleObject_Native];
  IF @ExactObjectB IS NULL OR @CaseObjectB IS NULL OR @ExactObjectB<>@CaseObjectB OR @ProbeError IS NOT NULL
    OR NOT EXISTS(SELECT 1 FROM [#ExampleObject_Native] WHERE [DatabaseId]=@DbBId AND [PermissionName]=N'SELECT')
    THROW 63209,N'OBJECT_FIXTURE_CASE_INSENSITIVE_NATIVE',1;

  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Rc=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N''dbo'',@ObjectName=N''examplecaseprobe'',@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
  SET @Json=NULL;SET @Ret=NULL;SET @Status=NULL;
  EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Rc int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT',@Names=@Names,@Rc=@Ret OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT;
  IF COALESCE(@Ret,-1)<>0 OR COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(ISJSON(@Json),0)<>1
    OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.objectPermissions'))<>@CaseNativeRows
    OR EXISTS(SELECT [DatabaseId],[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
      FROM OPENJSON(@Json,N'$.objectPermissions') WITH([DatabaseId] int,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,[EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128))
      EXCEPT SELECT [DatabaseId],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName] FROM [#ExampleObject_Native])
    OR EXISTS(SELECT [DatabaseId],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName] FROM [#ExampleObject_Native]
      EXCEPT SELECT [DatabaseId],[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
      FROM OPENJSON(@Json,N'$.objectPermissions') WITH([DatabaseId] int,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,[EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128)))
    THROW 63210,N'OBJECT_FIXTURE_CASE_PRODUCT_PARITY',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64)) WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS')<>2
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ErrorNumber] int)
      WHERE [DatabaseId]=@DbAId AND [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND
       ((@CaseNativeError IS NULL AND [StatusCode]='EMPTY_UNPROVEN' AND [ObservedRows]=0 AND [ErrorNumber] IS NULL)
        OR (@CaseNativeError IS NOT NULL AND [StatusCode]='ERROR_HANDLED' AND [ObservedRows] IS NULL AND [ErrorNumber]=@CaseNativeError)))
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ErrorNumber] int)
      WHERE [DatabaseId]=@DbBId AND [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode]='AVAILABLE_LIMITED' AND [ObservedRows]=@CaseNativeRows AND [ErrorNumber] IS NULL)
    THROW 63211,N'OBJECT_FIXTURE_CASE_SOURCE_PARITY',1;

  -- Eigene Spaltenfreigabe: direkter nativer Callerbeweis und TABLE/JSON unter demselben Login.
  SET @Sql=N'USE '+QUOTENAME(@DbA)+N';CREATE TABLE [dbo].[ExampleColumnProbe]([Value] int NOT NULL,[OtherValue] int NULL);GRANT SELECT ([Value]) ON OBJECT::[dbo].[ExampleColumnProbe] TO '+QUOTENAME(@DbUser)+N';';
  EXEC [sys].[sp_executesql] @Sql;
  CREATE TABLE [#ExampleColumn_Native]
  ([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
   [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
   [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
  DECLARE @ColumnMap nvarchar(max)=N'{"moduleStatus":"#ExampleColumn_moduleStatus","callerContexts":"#ExampleColumn_callerContexts","objectPermissions":"#ExampleColumn_objectPermissions","sourceStatus":"#ExampleColumn_sourceStatus","warnings":"#ExampleColumn_warnings"}',
   @ColumnJson nvarchar(max)=NULL,@ColumnModule nvarchar(max)=NULL,@ColumnContexts nvarchar(max)=NULL,
   @ColumnPermissions nvarchar(max)=NULL,@ColumnSources nvarchar(max)=NULL,@ColumnWarnings nvarchar(max)=NULL,
   @ColumnNames nvarchar(max)=QUOTENAME(@DbA),@ColumnStatus varchar(40)=NULL,@ColumnPartial bit=NULL,
   @ColumnError int=NULL,@ColumnMessage nvarchar(2048)=NULL,@ColumnReturn int=NULL,
   @ColumnParentDb int=DB_ID(),@ColumnParentLogin int=SUSER_ID(),@ColumnParentTx int=@@TRANCOUNT,
   @ColumnParentLock int=@@LOCK_TIMEOUT,@ColumnParentAbort int=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END;
  SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';
BEGIN TRY
 IF DB_ID()<>@FrameworkId OR SUSER_ID()<>@ExpectedLoginId THROW 63310,N''OBJECT_COLUMN_CALLER_ENTRY'',1;
 IF OBJECT_ID(N''tempdb..#ExampleColumn_moduleStatus'') IS NOT NULL OR OBJECT_ID(N''tempdb..#ExampleColumn_callerContexts'') IS NOT NULL OR OBJECT_ID(N''tempdb..#ExampleColumn_objectPermissions'') IS NOT NULL OR OBJECT_ID(N''tempdb..#ExampleColumn_sourceStatus'') IS NOT NULL OR OBJECT_ID(N''tempdb..#ExampleColumn_warnings'') IS NOT NULL THROW 63311,N''OBJECT_COLUMN_TABLE_COLLISION'',1;
 CREATE TABLE #ExampleColumn_moduleStatus([Seed] int NULL);
 CREATE TABLE #ExampleColumn_callerContexts([Seed] int NULL);
 CREATE TABLE #ExampleColumn_objectPermissions([Seed] int NULL);
 CREATE TABLE #ExampleColumn_sourceStatus([Seed] int NULL);
 CREATE TABLE #ExampleColumn_warnings([Seed] int NULL);
 USE '+QUOTENAME(@DbA)+N';
 INSERT #ExampleColumn_Native SELECT @Id,@Name,N''dbo'',N''ExampleColumnProbe'',[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM [sys].[fn_my_permissions](N''[dbo].[ExampleColumnProbe]'',N''OBJECT'');
 USE '+QUOTENAME(@FrameworkDb)+N';
 IF DB_ID()<>@FrameworkId OR SUSER_ID()<>@ExpectedLoginId THROW 63312,N''OBJECT_COLUMN_CALLER_RETURN'',1;
 EXEC @Rc=[monitor].[USP_CurrentObjectPermissionAnalysis] @DatabaseNames=@Names,@SchemaName=N''dbo'',@ObjectName=N''ExampleColumnProbe'',@ResultSetArt=''TABLE'',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT,@IsPartialOut=@Part OUTPUT,@ErrorNumberOut=@Er OUTPUT,@ErrorMessageOut=@Msg OUTPUT;
 IF DB_ID()<>@FrameworkId OR SUSER_ID()<>@ExpectedLoginId THROW 63313,N''OBJECT_COLUMN_CALLER_AFTER_PRODUCT'',1;
 SET @Tm=(SELECT * FROM #ExampleColumn_moduleStatus FOR JSON PATH,INCLUDE_NULL_VALUES);
 SET @Tc=(SELECT * FROM #ExampleColumn_callerContexts ORDER BY [DatabaseId],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
 SET @Tp=(SELECT * FROM #ExampleColumn_objectPermissions ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
 SET @Ts=(SELECT * FROM #ExampleColumn_sourceStatus ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
 SET @Tw=(SELECT * FROM #ExampleColumn_warnings ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
 REVERT;
END TRY
BEGIN CATCH
 USE '+QUOTENAME(@FrameworkDb)+N';
 REVERT;
 THROW;
END CATCH;';
  EXEC [sys].[sp_executesql] @Sql,
   N'@Id int,@Name sysname,@Names nvarchar(max),@Map nvarchar(max),@FrameworkId int,@ExpectedLoginId int,
     @Rc int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT,@Part bit OUTPUT,@Er int OUTPUT,@Msg nvarchar(2048) OUTPUT,
     @Tm nvarchar(max) OUTPUT,@Tc nvarchar(max) OUTPUT,@Tp nvarchar(max) OUTPUT,@Ts nvarchar(max) OUTPUT,@Tw nvarchar(max) OUTPUT',
   @Id=@DbAId,@Name=@DbA,@Names=@ColumnNames,@Map=@ColumnMap,@FrameworkId=@OriginalDb,@ExpectedLoginId=@LoginId,
   @Rc=@ColumnReturn OUTPUT,@J=@ColumnJson OUTPUT,@St=@ColumnStatus OUTPUT,@Part=@ColumnPartial OUTPUT,
   @Er=@ColumnError OUTPUT,@Msg=@ColumnMessage OUTPUT,@Tm=@ColumnModule OUTPUT,@Tc=@ColumnContexts OUTPUT,
   @Tp=@ColumnPermissions OUTPUT,@Ts=@ColumnSources OUTPUT,@Tw=@ColumnWarnings OUTPUT;
  IF DB_ID()<>@ColumnParentDb OR SUSER_ID()<>@ColumnParentLogin OR @@TRANCOUNT<>@ColumnParentTx
   OR @@LOCK_TIMEOUT<>@ColumnParentLock OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@ColumnParentAbort
   THROW 63314,N'OBJECT_COLUMN_PARENT_CALLER_RESTORE',1;
  IF NOT EXISTS(SELECT 1 FROM [#ExampleColumn_Native]
    WHERE [DatabaseId]=@DbAId AND [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@DbA COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [RequestedObjectName]=N'ExampleColumnProbe' AND [PermissionName]=N'SELECT'
      AND [SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'Value'
      AND DATALENGTH([SubentityName])=DATALENGTH(N'Value'))
   THROW 63315,N'OBJECT_COLUMN_NATIVE_POSITIVE',1;
  IF COALESCE(@ColumnReturn,-1)<>0 OR COALESCE(@ColumnStatus,'')<>'AVAILABLE_LIMITED'
   OR COALESCE(@ColumnPartial,0)<>1 OR @ColumnError IS NOT NULL OR ISJSON(@ColumnJson)<>1
   THROW 63316,N'OBJECT_COLUMN_PRODUCT_STATUS',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@ColumnJson))<>6
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'meta' AND [type]=5)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'moduleStatus' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'callerContexts' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'objectPermissions' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'sourceStatus' AND [type]=4)<>1
   OR (SELECT COUNT(*) FROM OPENJSON(@ColumnJson) WHERE [key]=N'warnings' AND [type]=4)<>1
   THROW 63317,N'OBJECT_COLUMN_JSON_GROUPS',1;
  IF EXISTS(SELECT 1 FROM (VALUES
    (N'moduleStatus',@ColumnModule),(N'callerContexts',@ColumnContexts),
    (N'objectPermissions',@ColumnPermissions),(N'sourceStatus',@ColumnSources),(N'warnings',@ColumnWarnings)) AS [p]([Key],[Rows])
    WHERE JSON_QUERY(@ColumnJson,N'$.'+[p].[Key]) IS NULL
       OR COALESCE(DATALENGTH([p].[Rows]),-1)<>COALESCE(DATALENGTH(JSON_QUERY(@ColumnJson,N'$.'+[p].[Key])),-1)
       OR [p].[Rows] COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@ColumnJson,N'$.'+[p].[Key]) COLLATE SQL_Latin1_General_CP1_CS_AS)
   THROW 63318,N'OBJECT_COLUMN_TABLE_JSON_PARITY',1;
  IF (SELECT COUNT_BIG(*) FROM OPENJSON(@ColumnJson,N'$.objectPermissions'))<>(SELECT COUNT_BIG(*) FROM [#ExampleColumn_Native])
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ColumnPermissions))<>(SELECT COUNT_BIG(*) FROM [#ExampleColumn_Native])
   THROW 63319,N'OBJECT_COLUMN_NATIVE_COUNT',1;
  IF EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM OPENJSON(@ColumnJson,N'$.objectPermissions') WITH
              ([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,
               [EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128))
            EXCEPT SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName]
                   FROM [#ExampleColumn_Native])
   OR EXISTS(SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName]
             FROM [#ExampleColumn_Native]
             EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
                    FROM OPENJSON(@ColumnJson,N'$.objectPermissions') WITH
                      ([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,
                       [EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128)))
   THROW 63320,N'OBJECT_COLUMN_NATIVE_PRODUCT_PARITY',1;
  IF EXISTS(SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,[EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM OPENJSON(@ColumnPermissions) WITH
              ([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,
               [EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128))
            EXCEPT SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName]
                   FROM [#ExampleColumn_Native])
   OR EXISTS(SELECT [DatabaseId],[DatabaseName],[RequestedSchemaName],[RequestedObjectName],[EntityName],[SubentityName],[PermissionName]
             FROM [#ExampleColumn_Native]
             EXCEPT SELECT [DatabaseId],[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [RequestedSchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,[RequestedObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [EntityName] COLLATE SQL_Latin1_General_CP1_CS_AS,[SubentityName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [PermissionName] COLLATE SQL_Latin1_General_CP1_CS_AS
                    FROM OPENJSON(@ColumnPermissions) WITH
                      ([DatabaseId] int,[DatabaseName] sysname,[RequestedSchemaName] sysname,[RequestedObjectName] sysname,
                       [EntityName] sysname,[SubentityName] sysname,[PermissionName] nvarchar(128)))
   THROW 63321,N'OBJECT_COLUMN_NATIVE_TABLE_PARITY',1;
 END TRY
 BEGIN CATCH
  SET @Failure=ERROR_NUMBER();
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 END CATCH;
 SET XACT_ABORT OFF;SET LOCK_TIMEOUT 0;
 BEGIN TRY
  IF @DbBMade=1
  BEGIN
   IF @DbBId IS NULL OR @DbBGuid IS NULL THROW 63200,N'OBJECT_FIXTURE_DATABASE_B_RECOVERY_UNBOUND',1;
   IF EXISTS(SELECT 1 FROM [sys].[databases] [d] JOIN [sys].[database_recovery_status] [r] ON [r].[database_id]=[d].[database_id] WHERE [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@DbB COLLATE SQL_Latin1_General_CP1_CS_AS AND [d].[database_id]=@DbBId AND [r].[database_guid]=@DbBGuid)
   BEGIN SET @Sql=N'USE [master];ALTER DATABASE '+QUOTENAME(@DbB)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE '+QUOTENAME(@DbB)+N';';EXEC [master].[sys].[sp_executesql] @Sql;END;
  END;
 END TRY BEGIN CATCH SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());END CATCH;
 BEGIN TRY
  IF @DbAMade=1
  BEGIN
   IF @DbAId IS NULL OR @DbAGuid IS NULL THROW 63201,N'OBJECT_FIXTURE_DATABASE_A_RECOVERY_UNBOUND',1;
   IF EXISTS(SELECT 1 FROM [sys].[databases] [d] JOIN [sys].[database_recovery_status] [r] ON [r].[database_id]=[d].[database_id] WHERE [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@DbA COLLATE SQL_Latin1_General_CP1_CS_AS AND [d].[database_id]=@DbAId AND [r].[database_guid]=@DbAGuid)
   BEGIN SET @Sql=N'USE [master];ALTER DATABASE '+QUOTENAME(@DbA)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE '+QUOTENAME(@DbA)+N';';EXEC [master].[sys].[sp_executesql] @Sql;END;
  END;
 END TRY BEGIN CATCH SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());END CATCH;
 BEGIN TRY
  IF @FrameworkUserMade=1 AND EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@ExpectedSid AND (@FrameworkUserId IS NULL OR [principal_id]=@FrameworkUserId))
  BEGIN SET @Sql=N'DROP USER '+QUOTENAME(@FrameworkUser)+N';';EXEC [sys].[sp_executesql] @Sql;END;
 END TRY BEGIN CATCH SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());END CATCH;
 BEGIN TRY
  IF @LoginMade=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@ExpectedSid AND (@LoginId IS NULL OR [principal_id]=@LoginId))
  BEGIN SET @Sql=N'USE [master];DROP LOGIN '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;END;
 END TRY BEGIN CATCH SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());END CATCH;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM [sys].[databases] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS IN (@DbA COLLATE SQL_Latin1_General_CP1_CS_AS,@DbB COLLATE SQL_Latin1_General_CP1_CS_AS))
   OR EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS)
   OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS)
   THROW 63070,N'OBJECT_FIXTURE_OWNED_OBJECTS_REMAIN',1;
 END TRY
 BEGIN CATCH
  SET @CleanupError=COALESCE(@CleanupError,ERROR_NUMBER());
 END CATCH;
 IF @OriginalAbort=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
 IF @CleanupError IS NOT NULL OR @Failure IS NOT NULL
 BEGIN
  DECLARE @DiagnosticFailure int=COALESCE(@Failure,-1),@DiagnosticCleanup int=COALESCE(@CleanupError,-1);
  RAISERROR(N'OBJECT_FIXTURE_FAILURE original=%d cleanup=%d',16,1,@DiagnosticFailure,@DiagnosticCleanup);
  THROW 63072,N'OBJECT_FIXTURE_FAILED',1;
 END;
END;
GO
DECLARE @Return int;
DECLARE @ParentTx int=@@TRANCOUNT;
DECLARE @ParentDb int=DB_ID();
DECLARE @ParentAbort int=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END;
DECLARE @ParentLock int=@@LOCK_TIMEOUT;
EXEC @Return=[#ExampleCurrentObjectPermissionContract];
DECLARE @AfterTx int=@@TRANCOUNT;
DECLARE @AfterDb int=DB_ID();
DECLARE @AfterAbort int=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END;
DECLARE @AfterLock int=@@LOCK_TIMEOUT;
IF @AfterTx<>@ParentTx OR @AfterDb<>@ParentDb OR @AfterAbort<>@ParentAbort OR @AfterLock<>@ParentLock
BEGIN
 DECLARE @NoOriginalFailure int=-1,@NoCleanupFailure int=-1;
 RAISERROR(N'OBJECT_FIXTURE_CALLER_FRAME tx=%d/%d db=%d/%d abort=%d/%d lock=%d/%d original=%d cleanup=%d',10,1,@ParentTx,@AfterTx,@ParentDb,@AfterDb,@ParentAbort,@AfterAbort,@ParentLock,@AfterLock,@NoOriginalFailure,@NoCleanupFailure) WITH NOWAIT;
 THROW 63071,N'OBJECT_FIXTURE_CALLER_RESTORE',1;
END;
IF COALESCE(@Return,-1)<>0 THROW 63073,N'OBJECT_FIXTURE_RETURN',1;
DROP PROCEDURE [#ExampleCurrentObjectPermissionContract];
GO
