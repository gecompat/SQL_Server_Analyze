USE [DeineDatenbank];
GO
IF OBJECT_ID(N'tempdb..#ExampleCallerPermissionRuntimeContract') IS NOT NULL THROW 57299,N'Caller permission scoped fixture already exists.',1;
GO
CREATE PROCEDURE [#ExampleCallerPermissionRuntimeContract] @NativeTableCases int OUTPUT
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
 @DbA sysname,@DbB sysname,@DbC sysname,@Login sysname,@User sysname,@LocalUser sysname,@RoleLeaf sysname,@RoleParent sysname,
 @Sql nvarchar(max),@Credential nvarchar(128),@Exact nvarchar(max),@Framework sysname=DB_NAME(),@FrameworkId int=DB_ID(),
 @FrameworkUserMade bit=0,@LocalUserMade bit=0,@MasterUserMade bit=0,@MasterUserId int,@MasterUserSid varbinary(85),@MasterUser sysname,@LoginId int,@LoginSid varbinary(85),@UserA int,@UserB int,@FrameworkUserId int,@FrameworkUserSid varbinary(85),@LocalUserId int,@LocalUserSid varbinary(85),
 @IdA int,@IdB int,@IdC int,@GuidA uniqueidentifier,@GuidB uniqueidentifier,@GuidC uniqueidentifier,
 @Json nvarchar(max),@Expected nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
 @CallStart datetime2(3),@CallEnd datetime2(3),@OriginalTx int=@@TRANCOUNT,@OriginalDb int=DB_ID(),
 @Case int=0,@Limit int,@SourceLock int,@ProbeError int,@ProbeRows bigint,
 @Failure int=NULL,@FailureMessage nvarchar(2048)=NULL,@CleanupErrors nvarchar(max)=N'',@AllCases bit=0;
IF @OriginalTx<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1 THROW 57210,N'Caller fixture requires an isolated sysadmin target without ambient transaction.',1;
SELECT @DbA=N'ExampleCallerA|'+@Suffix,@DbB=N'ExampleCallerB]'+@Suffix,@DbC=N'ExampleCallerC_'+@Suffix,
 @Login=N'ExampleCallerLogin_'+@Suffix,@User=N'ExampleCallerUser_'+@Suffix,@LocalUser=N'ExampleCallerLocal_'+@Suffix,
 @RoleLeaf=N'ExampleCallerLeaf_'+@Suffix,@RoleParent=N'ExampleCallerParent_'+@Suffix,@MasterUser=N'ExampleCallerMaster_'+@Suffix;
SET @Exact=QUOTENAME(@DbA)+N'|'+QUOTENAME(@DbB);
CREATE TABLE [#ExampleCallerPermission_OwnDatabases]([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseGuid] uniqueidentifier NULL);
CREATE TABLE [#ExampleCallerPermission_Sentinel]([Id] int NOT NULL PRIMARY KEY,[Value] int NOT NULL);
INSERT [#ExampleCallerPermission_Sentinel] VALUES(1,10);
BEGIN TRY
 IF EXISTS(SELECT 1 FROM [sys].[databases] WHERE [name] IN (@DbA,@DbB,@DbC)) OR EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@Login)
 OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] IN (@User,@LocalUser)) OR EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [name]=@MasterUser) THROW 57211,N'Caller fixture collision.',1;
 SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
 SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Login)+N' WITH PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';EXEC [master].[sys].[sp_executesql] @Sql;SET @Credential=NULL;
 SELECT @LoginId=[principal_id],@LoginSid=[sid] FROM [sys].[server_principals] WHERE [name]=@Login;
 SET @Sql=N'CREATE USER '+QUOTENAME(@User)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';EXEC [sys].[sp_executesql] @Sql;SET @FrameworkUserMade=1;
 SELECT @FrameworkUserId=[principal_id],@FrameworkUserSid=[sid] FROM [sys].[database_principals] WHERE [name]=@User;
 IF @FrameworkUserId IS NULL OR @FrameworkUserSid IS NULL THROW 57212,N'Framework user native binding is incomplete.',1;
 SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_CurrentCallerPermissionAnalysis] TO '+QUOTENAME(@User)+N';';EXEC [sys].[sp_executesql] @Sql;
 SET @Sql=N'CREATE USER '+QUOTENAME(@LocalUser)+N' WITHOUT LOGIN;';EXEC [sys].[sp_executesql] @Sql;SET @LocalUserMade=1;
 SELECT @LocalUserId=[principal_id],@LocalUserSid=[sid] FROM [sys].[database_principals] WHERE [name]=@LocalUser;
 IF @LocalUserId IS NULL OR @LocalUserSid IS NULL THROW 57212,N'Local user native binding is incomplete.',1;
 SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_CurrentCallerPermissionAnalysis] TO '+QUOTENAME(@LocalUser)+N';';EXEC [sys].[sp_executesql] @Sql;
 DECLARE @ArrangeName sysname;
 DECLARE [ExampleCallerPermissionArrangeDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [n] FROM (VALUES(@DbA),(@DbB),(@DbC)) AS [v]([n]);
 OPEN [ExampleCallerPermissionArrangeDatabases];FETCH NEXT FROM [ExampleCallerPermissionArrangeDatabases] INTO @ArrangeName;
 WHILE @@FETCH_STATUS=0
 BEGIN
  INSERT [#ExampleCallerPermission_OwnDatabases] VALUES(@ArrangeName,NULL,NULL);
  SET @Sql=N'CREATE DATABASE '+QUOTENAME(@ArrangeName)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';EXEC [master].[sys].[sp_executesql] @Sql;
  UPDATE [o] SET [DatabaseId]=[d].[database_id],[DatabaseGuid]=[r].[database_guid] FROM [#ExampleCallerPermission_OwnDatabases] AS [o]
  INNER JOIN [sys].[databases] AS [d] ON [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[o].[DatabaseName]
  INNER JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id] WHERE [o].[DatabaseName]=@ArrangeName COLLATE SQL_Latin1_General_CP1_CS_AS;
  FETCH NEXT FROM [ExampleCallerPermissionArrangeDatabases] INTO @ArrangeName;
 END;
 CLOSE [ExampleCallerPermissionArrangeDatabases];DEALLOCATE [ExampleCallerPermissionArrangeDatabases];
 SELECT @IdA=[DatabaseId],@GuidA=[DatabaseGuid] FROM [#ExampleCallerPermission_OwnDatabases] WHERE [DatabaseName]=@DbA COLLATE SQL_Latin1_General_CP1_CS_AS;
 SELECT @IdB=[DatabaseId],@GuidB=[DatabaseGuid] FROM [#ExampleCallerPermission_OwnDatabases] WHERE [DatabaseName]=@DbB COLLATE SQL_Latin1_General_CP1_CS_AS;
 SELECT @IdC=[DatabaseId],@GuidC=[DatabaseGuid] FROM [#ExampleCallerPermission_OwnDatabases] WHERE [DatabaseName]=@DbC COLLATE SQL_Latin1_General_CP1_CS_AS;
 IF @LoginId IS NULL OR @LoginSid IS NULL OR @FrameworkUserId IS NULL OR @LocalUserId IS NULL OR @IdA IS NULL OR @IdB IS NULL OR @IdC IS NULL OR @GuidA IS NULL OR @GuidB IS NULL OR @GuidC IS NULL THROW 57212,N'Caller ownership binding incomplete.',1;
 SET @Sql=N'USE '+QUOTENAME(@DbA)+N';CREATE USER '+QUOTENAME(@User)+N' FOR LOGIN '+QUOTENAME(@Login)+N';CREATE ROLE '+QUOTENAME(@RoleLeaf)+N';CREATE ROLE '+QUOTENAME(@RoleParent)+N';
  ALTER ROLE '+QUOTENAME(@RoleLeaf)+N' ADD MEMBER '+QUOTENAME(@User)+N';ALTER ROLE '+QUOTENAME(@RoleParent)+N' ADD MEMBER '+QUOTENAME(@RoleLeaf)+N';
  GRANT SELECT TO '+QUOTENAME(@RoleLeaf)+N';GRANT EXECUTE,UPDATE TO '+QUOTENAME(@RoleParent)+N';DENY UPDATE TO '+QUOTENAME(@User)+N';
  CREATE TABLE [dbo].[ExamplePermissionProbe]([Value] int NOT NULL);INSERT [dbo].[ExamplePermissionProbe] VALUES(11);DENY SELECT ON OBJECT::[dbo].[ExamplePermissionProbe] TO '+QUOTENAME(@User)+N';SELECT @Id=DATABASE_PRINCIPAL_ID(@Name);';
 EXEC [sys].[sp_executesql] @Sql,N'@Name sysname,@Id int OUTPUT',@Name=@User,@Id=@UserA OUTPUT;
 SET @Sql=N'USE '+QUOTENAME(@DbB)+N';CREATE USER '+QUOTENAME(@User)+N' FOR LOGIN '+QUOTENAME(@Login)+N';SELECT @Id=DATABASE_PRINCIPAL_ID(@Name);';EXEC [sys].[sp_executesql] @Sql,N'@Name sysname,@Id int OUTPUT',@Name=@User,@Id=@UserB OUTPUT;
 IF @UserA IS NULL OR @UserA<>@UserB THROW 57213,N'Repeated local IDs not independently arranged.',1;
 CREATE TABLE [#ExampleCallerPermission_Expected_moduleStatus]
 (
[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Expected_callerContexts]
 (
[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ContextDatabaseId] int NOT NULL,
    [ServerPrincipalId] int NULL,
    [DatabasePrincipalId] int NULL,
    [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Expected_serverPermissions]
 (
[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Expected_databasePermissions]
 (
[DatabaseId] int NOT NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Expected_sourceStatus]
 (
[DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StartedAtUtc] datetime2(3) NOT NULL,
    [CompletedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservedRows] bigint NULL,
    [ReturnedRows] bigint NULL,
    [IsLimited] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Expected_warnings]
 (
[DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleCallerPermission_Shapes]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 INSERT [#ExampleCallerPermission_Shapes] VALUES
  (N'moduleStatus',N'#ExampleCallerPermission_Expected_moduleStatus',N'#ExampleCallerPermission_moduleStatus'),
  (N'callerContexts',N'#ExampleCallerPermission_Expected_callerContexts',N'#ExampleCallerPermission_callerContexts'),
  (N'serverPermissions',N'#ExampleCallerPermission_Expected_serverPermissions',N'#ExampleCallerPermission_serverPermissions'),
  (N'databasePermissions',N'#ExampleCallerPermission_Expected_databasePermissions',N'#ExampleCallerPermission_databasePermissions'),
  (N'sourceStatus',N'#ExampleCallerPermission_Expected_sourceStatus',N'#ExampleCallerPermission_sourceStatus'),
  (N'warnings',N'#ExampleCallerPermission_Expected_warnings',N'#ExampleCallerPermission_warnings');
 INSERT [#ExampleCallerPermission_Expected_serverPermissions] SELECT [entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM [sys].[fn_my_permissions](NULL,'SERVER');
 SET @Sql=N'USE '+QUOTENAME(@DbA)+N';INSERT [#ExampleCallerPermission_Expected_databasePermissions] SELECT @Id,@Name,[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM sys.fn_my_permissions(NULL,''DATABASE'');';EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname',@Id=@IdA,@Name=@DbA;
 SET @Sql=N'USE '+QUOTENAME(@DbB)+N';INSERT [#ExampleCallerPermission_Expected_databasePermissions] SELECT @Id,@Name,[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM sys.fn_my_permissions(NULL,''DATABASE'');';EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname',@Id=@IdB,@Name=@DbB;
 CREATE TABLE [#ExampleCallerPermission_ExpectedFacets]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Ordinal] bigint NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] tinyint NOT NULL,[Length] smallint NOT NULL,[Precision] tinyint NOT NULL,[Scale] tinyint NOT NULL,[Nullable] bit NOT NULL,[Collation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#ExampleCallerPermission_ActualFacets]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Ordinal] bigint NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] tinyint NOT NULL,[Length] smallint NOT NULL,[Precision] tinyint NOT NULL,[Scale] tinyint NOT NULL,[Nullable] bit NOT NULL,[Collation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 INSERT [#ExampleCallerPermission_ExpectedFacets] SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),[c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
 FROM [#ExampleCallerPermission_Shapes] AS [s] INNER JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ExpectedName]);
 WHILE @Case<4
 BEGIN
  CREATE TABLE [#ExampleCallerPermission_moduleStatus]([Seed] int NULL);
  CREATE TABLE [#ExampleCallerPermission_callerContexts]([Seed] int NULL);
  CREATE TABLE [#ExampleCallerPermission_serverPermissions]([Seed] int NULL);
  CREATE TABLE [#ExampleCallerPermission_databasePermissions]([Seed] int NULL);
  CREATE TABLE [#ExampleCallerPermission_sourceStatus]([Seed] int NULL);
  CREATE TABLE [#ExampleCallerPermission_warnings]([Seed] int NULL);
  DECLARE @Map nvarchar(max)=N'{"moduleStatus":"#ExampleCallerPermission_moduleStatus","callerContexts":"#ExampleCallerPermission_callerContexts","serverPermissions":"#ExampleCallerPermission_serverPermissions","databasePermissions":"#ExampleCallerPermission_databasePermissions","sourceStatus":"#ExampleCallerPermission_sourceStatus","warnings":"#ExampleCallerPermission_warnings"}';
  SET @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;SET @SourceLock=CASE WHEN @Case%2=0 THEN 31 ELSE 0 END;
  IF @Case IN (2,3) SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
  SET LOCK_TIMEOUT 43;
  IF @Case=3 BEGIN BEGIN TRANSACTION;UPDATE [#ExampleCallerPermission_Sentinel] SET [Value]=11 WHERE [Id]=1;END;
  SET @CallStart=SYSUTCDATETIME();
  EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Exact,@MaxZeilen=@Limit,@LockTimeoutMs=@SourceLock,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
  SET @CallEnd=SYSUTCDATETIME();
  IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL THROW 57214,N'Caller TABLE status or return differs.',1;
  IF @@LOCK_TIMEOUT<>43 OR @@TRANCOUNT<>CASE WHEN @Case=3 THEN 1 ELSE 0 END OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>CASE WHEN @Case IN (2,3) THEN 1 ELSE 0 END OR DB_ID()<>@OriginalDb THROW 57215,N'Caller option or transaction restoration differs.',1;
  IF ISJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS))<>7 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS) WHERE [type]=4)<>6 OR TRY_CONVERT(int,JSON_VALUE(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.meta.schemaVersion'))<>1 THROW 57216,N'Caller six-array JSON differs.',1;
  DELETE FROM [#ExampleCallerPermission_ActualFacets];
  INSERT [#ExampleCallerPermission_ActualFacets] SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),[c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
  FROM [#ExampleCallerPermission_Shapes] AS [s] INNER JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ActualName]);
  IF EXISTS(SELECT * FROM [#ExampleCallerPermission_ActualFacets] EXCEPT SELECT * FROM [#ExampleCallerPermission_ExpectedFacets]) OR EXISTS(SELECT * FROM [#ExampleCallerPermission_ExpectedFacets] EXCEPT SELECT * FROM [#ExampleCallerPermission_ActualFacets]) THROW 57217,N'Caller six-set independent native schema facets differ.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.moduleStatus'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: moduleStatus.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_callerContexts] ORDER BY [DatabaseId],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: callerContexts.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_serverPermissions] ORDER BY [EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.serverPermissions'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: serverPermissions.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_databasePermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: databasePermissions.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: sourceStatus.',1;
  SET @Expected=(SELECT * FROM [#ExampleCallerPermission_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS)<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.warnings'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57218,N'Caller TABLE JSON parity differs: warnings.',1;
  IF (SELECT COUNT(*) FROM [#ExampleCallerPermission_callerContexts])<>3 OR EXISTS(SELECT 1 FROM [#ExampleCallerPermission_callerContexts] WHERE [CapturedAtUtc]<@CallStart OR [CapturedAtUtc]>@CallEnd OR [ServerPrincipalId]<>SUSER_ID() OR [DatabasePrincipalId]<>1 OR [ContextStatus]<>'CAPTURED_CURRENT_IDS' OR ([SourceKey]='DATABASE_CURRENT_PERMISSIONS' AND [ContextDatabaseId]<>[DatabaseId]) OR ([SourceKey]='SERVER_CURRENT_PERMISSIONS' AND ([ContextDatabaseId]<>@FrameworkId OR [DatabaseId] IS NOT NULL))) THROW 57219,N'Caller context IDs truncated or rebound.',1;
  IF (SELECT COUNT(*) FROM [#ExampleCallerPermission_sourceStatus])<>6 OR EXISTS(SELECT 1 FROM [#ExampleCallerPermission_sourceStatus] WHERE [StartedAtUtc]<@CallStart OR [CompletedAtUtc]>@CallEnd OR [StartedAtUtc]>[CompletedAtUtc] OR [ErrorNumber] IS NOT NULL) OR (SELECT COUNT(*) FROM [#ExampleCallerPermission_moduleStatus])<>1 OR (SELECT [RowCount] FROM [#ExampleCallerPermission_moduleStatus])<>(SELECT COUNT_BIG(*) FROM [#ExampleCallerPermission_serverPermissions])+(SELECT COUNT_BIG(*) FROM [#ExampleCallerPermission_databasePermissions]) THROW 57220,N'Caller source times or row count differ.',1;
  IF @Case<>1
  BEGIN
   IF EXISTS(SELECT * FROM [#ExampleCallerPermission_Expected_serverPermissions] EXCEPT SELECT * FROM [#ExampleCallerPermission_serverPermissions]) OR EXISTS(SELECT * FROM [#ExampleCallerPermission_serverPermissions] EXCEPT SELECT * FROM [#ExampleCallerPermission_Expected_serverPermissions]) OR EXISTS(SELECT * FROM [#ExampleCallerPermission_Expected_databasePermissions] EXCEPT SELECT * FROM [#ExampleCallerPermission_databasePermissions]) OR EXISTS(SELECT * FROM [#ExampleCallerPermission_databasePermissions] EXCEPT SELECT * FROM [#ExampleCallerPermission_Expected_databasePermissions]) THROW 57221,N'Caller native value oracle differs.',1;
  END
  ELSE
  BEGIN
   IF (SELECT COUNT(*) FROM [#ExampleCallerPermission_serverPermissions])<>1 OR (SELECT COUNT(*) FROM [#ExampleCallerPermission_databasePermissions])<>1 OR NOT EXISTS(SELECT 1 FROM [#ExampleCallerPermission_sourceStatus] WHERE [IsLimited]=1 AND [ObservedRows]>[ReturnedRows]) OR NOT EXISTS(SELECT 1 FROM [#ExampleCallerPermission_sourceStatus] WHERE [DatabaseId]=@IdB AND [SourceKey]='DATABASE_CURRENT_PERMISSIONS' AND [ObservedRows]>0 AND [ReturnedRows]=0 AND [IsLimited]=1) THROW 57222,N'Caller global limits differ.',1;
  END;
  IF @Case=3
  BEGIN
   IF XACT_STATE()<>1 OR (SELECT [Value] FROM [#ExampleCallerPermission_Sentinel] WHERE [Id]=1)<>11 THROW 57223,N'Caller ambient sentinel changed.',1;
   UPDATE [#ExampleCallerPermission_Sentinel] SET [Value]=12 WHERE [Id]=1;ROLLBACK TRANSACTION;
   IF (SELECT [Value] FROM [#ExampleCallerPermission_Sentinel] WHERE [Id]=1)<>10 THROW 57224,N'Caller rollback ownership differs.',1;
  END;
  DROP TABLE [#ExampleCallerPermission_moduleStatus];
  DROP TABLE [#ExampleCallerPermission_callerContexts];
  DROP TABLE [#ExampleCallerPermission_serverPermissions];
  DROP TABLE [#ExampleCallerPermission_databasePermissions];
  DROP TABLE [#ExampleCallerPermission_sourceStatus];
  DROP TABLE [#ExampleCallerPermission_warnings];
  SET @Case+=1;
 END;
 DECLARE @DefaultCount bigint=(SELECT COUNT_BIG(*) FROM [master].[sys].[databases] WHERE [database_id]>4 AND [source_database_id] IS NULL AND [state]=0 AND HAS_DBACCESS([name])=1);
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts') WITH([SourceKey] varchar(64),[DatabaseId] int) WHERE [SourceKey]='DATABASE_CURRENT_PERMISSIONS')<>@DefaultCount THROW 57225,N'Caller default scope differs.',1;
 DECLARE @Pattern nvarchar(4000)=N'like:ExampleCallerA%'+@Suffix;
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNamePattern=@Pattern,@ServerrechteEinbeziehen=0,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts'))<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.serverPermissions'))<>0 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40)) WHERE [SourceKey]='SERVER_CURRENT_PERMISSIONS' AND [StatusCode]='SKIPPED') THROW 57226,N'Caller LIKE scope or server opt-out differs.',1;
 DECLARE @Missing sysname=N'ExampleCallerMissing_'+@Suffix;
 CREATE TABLE [#ExampleCallerPermission_Console]
 ([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Scope] varchar(8) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
  [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 INSERT [#ExampleCallerPermission_Console] EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Missing,@MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
 IF NOT EXISTS(SELECT 1 FROM [#ExampleCallerPermission_Console] WHERE [Scope]='SERVER' AND [PermissionName] IS NOT NULL)
    OR NOT EXISTS(SELECT 1 FROM [#ExampleCallerPermission_Console] WHERE [Scope]='SOURCE' AND [DatabaseName]=@Missing COLLATE SQL_Latin1_General_CP1_CS_AS AND [SourceKey]='DATABASE_SELECTION' AND [StatusCode]='DATABASE_UNAVAILABLE' AND [Detail] IS NOT NULL)
    THROW 57243,N'Caller CONSOLE hid an unavailable target behind successful server rights.',1;
 DROP TABLE [#ExampleCallerPermission_Console];
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Missing,@ServerrechteEinbeziehen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
 IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'NO_TARGETS' OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions'))<>0 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKind] varchar(16),[StatusCode] varchar(40)) WHERE [SourceKind]='SELECTION' AND [StatusCode]='DATABASE_UNAVAILABLE') THROW 57227,N'Caller missing-target boundary differs.',1;
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=N'master',@ServerrechteEinbeziehen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions'))<>0 THROW 57228,N'Caller system database was not opt-in.',1;
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=N'master',@SystemdatenbankenEinbeziehen=1,@ServerrechteEinbeziehen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts') WITH([DatabaseId] int,[ContextDatabaseId] int) WHERE [DatabaseId]=1 AND [ContextDatabaseId]=1) THROW 57229,N'Caller explicit system scope differs.',1;
 -- Independent role grants and an object DENY distinguish permission levels.
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Names,@MaxZeilen=0,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT,@ErrorNumberOut=@Er OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT,@Er int OUTPUT',@Names=@Exact,@Ret=@Return OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT,@Er=@Error OUTPUT;
 IF @Return<>0 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED' OR @Error IS NOT NULL
  OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions') WITH([DatabaseId] int,[PermissionName] nvarchar(128)) WHERE [DatabaseId]=@IdA AND [PermissionName]='SELECT')
  OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions') WITH([DatabaseId] int,[PermissionName] nvarchar(128)) WHERE [DatabaseId]=@IdA AND [PermissionName]='EXECUTE')
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions') WITH([DatabaseId] int,[PermissionName] nvarchar(128)) WHERE [DatabaseId]=@IdA AND [PermissionName]='UPDATE')
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions') WITH([DatabaseId] int,[PermissionName] nvarchar(128)) WHERE [DatabaseId]=@IdB AND [PermissionName] IN ('SELECT','EXECUTE','UPDATE')) THROW 57230,N'Caller independent inherited grants or direct DENY differ.',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts') WITH([DatabaseId] int,[ContextDatabaseId] int,[ServerPrincipalId] int,[DatabasePrincipalId] int) WHERE [DatabaseId] IN (@IdA,@IdB) AND [ContextDatabaseId]=[DatabaseId] AND [ServerPrincipalId]=@LoginId AND [DatabasePrincipalId]=@UserA)<>2 THROW 57231,N'Caller repeated local IDs lost database binding.',1;
 DECLARE @NativeProbe nvarchar(max)=N'BEGIN TRY SELECT @Rows=COUNT_BIG(*) FROM [dbo].[ExamplePermissionProbe];END TRY BEGIN CATCH SET @Err=ERROR_NUMBER();END CATCH;';
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC '+QUOTENAME(@DbA)+N'.[sys].[sp_executesql] @Probe,N''@Rows bigint OUTPUT,@Err int OUTPUT'',@Rows=@Rows OUTPUT,@Err=@Err OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 SET @ProbeError=NULL;EXEC [sys].[sp_executesql] @Sql,N'@Probe nvarchar(max),@Rows bigint OUTPUT,@Err int OUTPUT',@Probe=@NativeProbe,@Rows=@ProbeRows OUTPUT,@Err=@ProbeError OUTPUT;
 IF COALESCE(@ProbeError,0)<>229 THROW 57232,N'Caller object-DENY counterprobe did not reject access.',1;
 -- This built-in function has server-scoped permissions, administered in master.
 SET @Sql=N'CREATE USER '+QUOTENAME(@MasterUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MasterUserMade=1;
 SELECT @MasterUserId=[principal_id],@MasterUserSid=[sid] FROM [master].[sys].[database_principals] WHERE [name]=@MasterUser;
 IF @MasterUserId IS NULL OR @MasterUserSid IS NULL THROW 57242,N'Owned master-user binding incomplete.',1;
 SET @Sql=N'DENY SELECT ON OBJECT::[sys].[fn_my_permissions] TO '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 SET @NativeProbe=N'BEGIN TRY SELECT @Rows=COUNT_BIG(*) FROM sys.fn_my_permissions(NULL,''DATABASE'');END TRY BEGIN CATCH SET @Err=ERROR_NUMBER();END CATCH;';
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC '+QUOTENAME(@DbA)+N'.[sys].[sp_executesql] @Probe,N''@Rows bigint OUTPUT,@Err int OUTPUT'',@Rows=@Rows OUTPUT,@Err=@Err OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 SET @ProbeError=NULL;EXEC [sys].[sp_executesql] @Sql,N'@Probe nvarchar(max),@Rows bigint OUTPUT,@Err int OUTPUT',@Probe=@NativeProbe,@Rows=@ProbeRows OUTPUT,@Err=@ProbeError OUTPUT;
 IF COALESCE(@ProbeError,0)<>229 THROW 57233,N'Caller native function-denial counterprobe differs.',1;
 SET XACT_ABORT ON;SET LOCK_TIMEOUT 53;BEGIN TRANSACTION;UPDATE [#ExampleCallerPermission_Sentinel] SET [Value]=11 WHERE [Id]=1;
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT,@ErrorNumberOut=@Er OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT,@Er int OUTPUT',@Names=@Exact,@Ret=@Return OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT,@Er=@Error OUTPUT;
 IF @Return<>0 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'DENIED_PERMISSION' OR COALESCE(@Error,0)<>229 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS&16384)<>16384 OR (SELECT [Value] FROM [#ExampleCallerPermission_Sentinel] WHERE [Id]=1)<>11
  OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([DatabaseId] int,[SourceKey] varchar(64),[StatusCode] varchar(40),[ErrorNumber] int,[ObservedRows] bigint) WHERE [DatabaseId]=@IdA AND [SourceKey]='DATABASE_CURRENT_PERMISSIONS' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber]=229 AND [ObservedRows] IS NULL)
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions'))
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.serverPermissions'))
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts'))
  OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40)) WHERE [SourceKey]='DATABASE_CONTEXT' AND [StatusCode]='AVAILABLE_LIMITED')<>2
  THROW 57234,N'Caller all-rights-source failure was masked by context metadata or changed the caller transaction.',1;
 ROLLBACK TRANSACTION;
 SET @Sql=N'REVOKE SELECT ON OBJECT::[sys].[fn_my_permissions] FROM '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 -- A local user has no registered server principal, without SID-name output.
 SET @Sql=N'EXECUTE AS USER='+QUOTENAME(@LocalUser,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@St OUTPUT,@ErrorNumberOut=@Er OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 DECLARE @FrameworkExact nvarchar(max)=QUOTENAME(@Framework);
 EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@St varchar(40) OUTPUT,@Er int OUTPUT',@Names=@FrameworkExact,@Ret=@Return OUTPUT,@J=@Json OUTPUT,@St=@Status OUTPUT,@Er=@Error OUTPUT;
 IF @Return<>0 OR ISJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS)<>1
  OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.callerContexts') WITH([SourceKey] varchar(64),[ServerPrincipalId] int,[DatabasePrincipalId] int,[ContextDatabaseId] int,[ContextStatus] varchar(40)) WHERE [SourceKey]='SERVER_CURRENT_PERMISSIONS' AND [ServerPrincipalId] IS NULL AND [DatabasePrincipalId]=@LocalUserId AND [ContextDatabaseId]=@FrameworkId AND [ContextStatus]='PARTIAL_CURRENT_IDS')
  OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint,[ReturnedRows] bigint) WHERE [SourceKey]='SERVER_CURRENT_PERMISSIONS' AND [StatusCode]='EMPTY_UNPROVEN' AND [ObservedRows]=0 AND [ReturnedRows]=0) THROW 57235,N'Caller loginless context or empty-source boundary differs.',1;
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 DECLARE @Inaccessible nvarchar(max)=QUOTENAME(@DbC);
 EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Ret int OUTPUT,@J nvarchar(max) OUTPUT',@Names=@Inaccessible,@Ret=@Return OUTPUT,@J=@Json OUTPUT;
 IF @Return<>0 OR EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databasePermissions')) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([DatabaseName] sysname,[SourceKind] varchar(16),[StatusCode] varchar(40)) WHERE [DatabaseName]=@DbC COLLATE SQL_Latin1_General_CP1_CS_AS AND [SourceKind]='SELECTION' AND [StatusCode]<>'AVAILABLE') THROW 57236,N'Caller inaccessible selection not isolated.',1;
 SET XACT_ABORT ON;SET LOCK_TIMEOUT 59;BEGIN TRANSACTION;UPDATE [#ExampleCallerPermission_Sentinel] SET [Value]=11 WHERE [Id]=1;
 SET @Json=N'{"previous":true}';
 EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"unknown":"#ExampleMissing"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 IF COALESCE(@Return,0)<>51011 OR COALESCE(@Error,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'ERROR_HANDLED' OR @Json IS NOT NULL OR NULLIF(@Message COLLATE SQL_Latin1_General_CP1_CS_AS,N'') IS NULL OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>59 OR (@@OPTIONS&16384)<>16384 OR (SELECT [Value] FROM [#ExampleCallerPermission_Sentinel] WHERE [Id]=1)<>11 THROW 57237,N'Caller rejected TABLE mapping or sentinel differs.',1;
 EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
 IF COALESCE(@Return,0)<>51011 OR COALESCE(@Error,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'INVALID_PARAMETER' OR @Json IS NOT NULL OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>59 OR (@@OPTIONS&16384)<>16384 THROW 57238,N'Caller invalid-limit contract differs.',1;
 EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Exact,@DatabaseNamePattern=@Pattern,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
 IF COALESCE(@Return,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'INVALID_PARAMETER' OR @Json IS NOT NULL OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 57239,N'Caller selection combination not rejected.',1;
 ROLLBACK TRANSACTION;
 EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Exact,@ServerrechteEinbeziehen=NULL,@ResultSetArt='NONE',@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
 IF COALESCE(@Return,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'INVALID_PARAMETER' THROW 57240,N'Caller nullable selector rejection differs.',1;
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Exact,@MaxZeilen=1,@ResultSetArt='RAW',@PrintMeldungen=0;
 EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @DatabaseNames=@Exact,@MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
 EXEC @Return=[monitor].[USP_CurrentCallerPermissionAnalysis] @Hilfe=1,@ResultSetArt='NONE',@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;
 IF @Return<>0 OR @Json IS NOT NULL OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE' THROW 57241,N'Caller help contract differs.',1;
 SET @AllCases=1;
END TRY
BEGIN CATCH
 SELECT @Failure=ERROR_NUMBER(),@FailureMessage=ERROR_MESSAGE();PRINT CONCAT(N'CALLER_PERMISSION_PRIMARY_FAILURE ',@Failure,N': ',@FailureMessage COLLATE SQL_Latin1_General_CP1_CS_AS);
END CATCH;
SET XACT_ABORT OFF;SET LOCK_TIMEOUT 1000;
IF @@TRANCOUNT>@OriginalTx ROLLBACK TRANSACTION;
-- Attempt each cleanup independently, using captured native identities.
DECLARE @CleanupName sysname,@CleanupId int,@CleanupSid varbinary(85),@CleanupGuid uniqueidentifier;
DECLARE [ExampleCallerPermissionCleanupUsers] CURSOR LOCAL FAST_FORWARD FOR SELECT [n],[id],[sid] FROM (VALUES(@User,@FrameworkUserId,@FrameworkUserSid),(@LocalUser,@LocalUserId,@LocalUserSid)) AS [v]([n],[id],[sid]) WHERE [id] IS NOT NULL;
OPEN [ExampleCallerPermissionCleanupUsers];FETCH NEXT FROM [ExampleCallerPermissionCleanupUsers] INTO @CleanupName,@CleanupId,@CleanupSid;
WHILE @@FETCH_STATUS=0
BEGIN
 BEGIN TRY
  IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [principal_id]=@CleanupId AND [sid]=@CleanupSid AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@CleanupName COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57280,N'Owned framework-user identity changed.',1;
  SET @Sql=N'DROP USER '+QUOTENAME(@CleanupName)+N';';EXEC [sys].[sp_executesql] @Sql;
 END TRY BEGIN CATCH SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; framework user: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
 FETCH NEXT FROM [ExampleCallerPermissionCleanupUsers] INTO @CleanupName,@CleanupId,@CleanupSid;
END;
CLOSE [ExampleCallerPermissionCleanupUsers];DEALLOCATE [ExampleCallerPermissionCleanupUsers];
DECLARE [ExampleCallerPermissionCleanupDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName],[DatabaseId],[DatabaseGuid] FROM [#ExampleCallerPermission_OwnDatabases] ORDER BY [DatabaseId] DESC;
OPEN [ExampleCallerPermissionCleanupDatabases];FETCH NEXT FROM [ExampleCallerPermissionCleanupDatabases] INTO @CleanupName,@CleanupId,@CleanupGuid;
WHILE @@FETCH_STATUS=0
BEGIN
 BEGIN TRY
  IF NOT EXISTS(SELECT 1 FROM [sys].[databases] AS [d] INNER JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id] WHERE [d].[database_id]=@CleanupId AND [r].[database_guid]=@CleanupGuid AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@CleanupName COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57281,N'Owned database identity changed.',1;
  SET @Sql=N'DROP DATABASE '+QUOTENAME(@CleanupName)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 END TRY BEGIN CATCH SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; database: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
 FETCH NEXT FROM [ExampleCallerPermissionCleanupDatabases] INTO @CleanupName,@CleanupId,@CleanupGuid;
END;
CLOSE [ExampleCallerPermissionCleanupDatabases];DEALLOCATE [ExampleCallerPermissionCleanupDatabases];
BEGIN TRY
 IF @MasterUserId IS NOT NULL
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [principal_id]=@MasterUserId AND [sid]=@MasterUserSid AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MasterUser COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57284,N'Owned master-user identity changed.',1;
  SET @Sql=N'DROP USER '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 END;
END TRY BEGIN CATCH SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; master user: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @LoginId IS NOT NULL
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [principal_id]=@LoginId AND [sid]=@LoginSid AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS) THROW 57282,N'Owned login identity changed.',1;
  SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 END;
END TRY BEGIN CATCH SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; login: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF (@FrameworkUserMade=1 AND EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@User COLLATE SQL_Latin1_General_CP1_CS_AS))
 OR (@LocalUserMade=1 AND EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@LocalUser COLLATE SQL_Latin1_General_CP1_CS_AS))
 OR (@MasterUserMade=1 AND EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MasterUser COLLATE SQL_Latin1_General_CP1_CS_AS))
  THROW 57285,N'Created fixture users remain; missing identity bindings require recovery instead of an unbound DROP.',1;
END TRY BEGIN CATCH SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; residual user: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
IF @CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS<>N''
BEGIN
 DECLARE @CombinedFailure nvarchar(2048)=LEFT(CONCAT(N'Caller fixture cleanup failed; primary=',@Failure,N' ',@FailureMessage COLLATE SQL_Latin1_General_CP1_CS_AS,N'; cleanup=',@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS),2048);
 RAISERROR(N'%s',16,1,@CombinedFailure);RETURN 1;
END;
IF @Failure IS NOT NULL BEGIN RAISERROR(N'%s',16,1,@FailureMessage);RETURN 1;END;
IF @AllCases<>1 THROW 57283,N'Caller functional cases incomplete.',1;
SET @NativeTableCases=@Case;RETURN 0;
END;
GO
DECLARE @ParentLock int=@@LOCK_TIMEOUT,@ParentAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,@ParentTx int=@@TRANCOUNT,@ParentDb int=DB_ID(),@FixtureReturn int,@FixtureCases int;
BEGIN TRY
 EXEC @FixtureReturn=[#ExampleCallerPermissionRuntimeContract] @NativeTableCases=@FixtureCases OUTPUT;
 IF COALESCE(@FixtureReturn,-1)<>0 OR COALESCE(@FixtureCases,0)<>4 OR @@LOCK_TIMEOUT<>@ParentLock OR @@TRANCOUNT<>@ParentTx OR DB_ID()<>@ParentDb OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@ParentAbort THROW 57298,N'Caller scoped fixture did not restore parent.',1;
 DROP PROCEDURE [#ExampleCallerPermissionRuntimeContract];
 SELECT N'CURRENT_CALLER_PERMISSION_CONTRACT_PASS' AS [Result],@FixtureCases AS [NativeTableCases],CAST(1 AS bit) AS [RestrictedCallerSourceFaultAndOwnedCleanup];
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>@ParentTx ROLLBACK TRANSACTION;
 IF OBJECT_ID(N'tempdb..#ExampleCallerPermissionRuntimeContract') IS NOT NULL DROP PROCEDURE [#ExampleCallerPermissionRuntimeContract];
 THROW;
END CATCH;
GO
