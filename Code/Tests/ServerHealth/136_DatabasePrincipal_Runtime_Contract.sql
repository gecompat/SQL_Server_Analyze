USE [DeineDatenbank];
GO
IF OBJECT_ID(N'tempdb..#ExampleDbPrincipalRuntimeContract') IS NOT NULL
    THROW 57188,N'Databaseprincipal scoped fixture procedure already exists.',1;
GO
CREATE PROCEDURE [#ExampleDbPrincipalRuntimeContract] @NativeTableCases int OUTPUT
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @DbA sysname,@DbB sysname,@DbC sysname,@Login sysname,@OrphanLogin sysname,@OwnerLogin sysname,@RestrictedLogin sysname,
    @User sysname,@OrphanUser sysname,@OwnerUser sysname,@RestrictedUser sysname,@ContainedUser sysname,@RoleA sysname,@RoleB sysname,@Schema sysname,
    @Sql nvarchar(max),@Inner nvarchar(max),@Credential nvarchar(128),@Exact nvarchar(max),@Pattern nvarchar(4000),
    @IdA int,@IdB int,@IdC int,@GuidA uniqueidentifier,@GuidB uniqueidentifier,@GuidC uniqueidentifier,
    @UserAId int,@UserBId int,@RoleAId int,@RoleBId int,@ObjectAId int,@SchemaAId int,@OwnerUserAId int,
    @OwnerLoginId int,@RestrictedLoginId int,@OrphanUserId int,@ContainedUserId int,
    @FrameworkUserId int,@FrameworkUserSid varbinary(85),@FrameworkUserMade bit=0,
    @OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
    @OriginalTx int=@@TRANCOUNT,@OriginalDatabase int=DB_ID(),@OriginalContained int,@OriginalAdvanced int,
    @OriginalContainedConfigured int,@OriginalAdvancedConfigured int,
    @ChangedContained bit=0,@ChangedAdvanced bit=0,@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),
    @Return int,@Json nvarchar(max),@Expected nvarchar(max),@Case int=0,@Limit int,@SourceLock int,@ProbeError int,
    @FailureNumber int=NULL,@FailureMessage nvarchar(2048)=NULL,@CleanupErrors nvarchar(max)=N'',@AllFunctionalCases bit=0;
IF @OriginalTx<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57110,N'Databaseprincipal fixture requires an isolated sysadmin target without ambient transaction.',1;
SELECT @DbA=N'ExampleDbPrincipalA|'+@Suffix,@DbB=N'ExampleDbPrincipalB]'+@Suffix,@DbC=N'ExampleDbPrincipalC_'+@Suffix,
       @Login=N'ExampleDbLogin_'+@Suffix,@OrphanLogin=N'ExampleDbOrphan_'+@Suffix,
       @OwnerLogin=N'ExampleDbOwner_'+@Suffix,@RestrictedLogin=N'ExampleDbReader_'+@Suffix,
       @User=N'ExampleDbUser_'+@Suffix,@OrphanUser=N'ExampleOrphanUser_'+@Suffix,@OwnerUser=N'ExampleOwnerUser_'+@Suffix,
       @RestrictedUser=N'ExampleReaderUser_'+@Suffix,@ContainedUser=N'ExampleContained_'+@Suffix,
       @RoleA=N'ExampleDbRoleA_'+@Suffix,@RoleB=N'ExampleDbRoleB_'+@Suffix,@Schema=N'ExampleDbSchema_'+@Suffix;
SET @Exact=QUOTENAME(@DbA)+N'|'+QUOTENAME(@DbB);
CREATE TABLE [#ExampleDbPrincipal_OwnDatabases]
([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseGuid] uniqueidentifier NULL);
CREATE TABLE [#ExampleDbPrincipal_OwnLogins]
([LoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PrincipalId] int NULL,[Sid] varbinary(85) NULL);
BEGIN TRY
    IF EXISTS(SELECT 1 FROM [sys].[databases] WHERE [name] IN (@DbA,@DbB,@DbC))
       OR EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] IN (@Login,@OrphanLogin,@OwnerLogin,@RestrictedLogin))
       OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@RestrictedUser)
        THROW 57111,N'Databaseprincipal fixture collision.',1;
    SELECT @OriginalContained=CONVERT(int,[value_in_use]),@OriginalContainedConfigured=CONVERT(int,[value]) FROM [sys].[configurations] WHERE [name]=N'contained database authentication';
    SELECT @OriginalAdvanced=CONVERT(int,[value_in_use]),@OriginalAdvancedConfigured=CONVERT(int,[value]) FROM [sys].[configurations] WHERE [name]=N'show advanced options';
    -- Documented default normalizations are not pending configuration changes:
    -- https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/server-configuration-options-sql-server
    DECLARE @PendingDynamicCount int,@PendingDynamicDetails nvarchar(max);
    SELECT @PendingDynamicCount=COUNT(*),
           @PendingDynamicDetails=STRING_AGG(CONVERT(nvarchar(max),CONCAT([name],N':',CONVERT(int,[value]),N'/',CONVERT(int,[value_in_use]))),N'; ')
    FROM [sys].[configurations]
    WHERE [is_dynamic]=1 AND [value]<>[value_in_use]
      AND NOT (([name]=N'min server memory (MB)' AND CONVERT(int,[value])=0 AND CONVERT(int,[value_in_use])=16)
            OR ([name]=N'max server memory (MB)' AND CONVERT(int,[value])=0 AND CONVERT(int,[value_in_use])=2147483647));
    IF @OriginalContained IS NULL OR @OriginalContainedConfigured IS NULL
       OR @OriginalAdvanced IS NULL OR @OriginalAdvancedConfigured IS NULL
       OR @OriginalContained<>@OriginalContainedConfigured OR @OriginalAdvanced<>@OriginalAdvancedConfigured
       OR @PendingDynamicCount<>0
    BEGIN
        DECLARE @PendingConfiguration nvarchar(2048)=CONCAT(N'Fixture requires stable configuration before mutation; contained configured=',
            @OriginalContainedConfigured,N', running=',@OriginalContained,N'; advanced configured=',@OriginalAdvancedConfigured,
            N', running=',@OriginalAdvanced,N'; pending dynamic count=',@PendingDynamicCount,N'; differences=',
            @PendingDynamicDetails COLLATE SQL_Latin1_General_CP1_CS_AS);
        THROW 57152,@PendingConfiguration,1;
    END;
    IF @OriginalAdvanced=0
    BEGIN EXEC [master].[sys].[sp_configure] N'show advanced options',1;SET @ChangedAdvanced=1;RECONFIGURE;END;
    IF @OriginalContained=0
    BEGIN EXEC [master].[sys].[sp_configure] N'contained database authentication',1;SET @ChangedContained=1;RECONFIGURE;END;

    DECLARE @ArrangeName sysname;
    DECLARE [ExampleDbPrincipalArrangeLogins] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [n] FROM (VALUES(@Login),(@OrphanLogin),(@OwnerLogin),(@RestrictedLogin)) AS [v]([n]);
    OPEN [ExampleDbPrincipalArrangeLogins];FETCH NEXT FROM [ExampleDbPrincipalArrangeLogins] INTO @ArrangeName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
        SET @Sql=N'CREATE LOGIN '+QUOTENAME(@ArrangeName)+N' WITH PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        INSERT [#ExampleDbPrincipal_OwnLogins]
            SELECT [name],[principal_id],[sid] FROM [sys].[server_principals] WHERE [name]=@ArrangeName;
        FETCH NEXT FROM [ExampleDbPrincipalArrangeLogins] INTO @ArrangeName;
    END;
    CLOSE [ExampleDbPrincipalArrangeLogins];DEALLOCATE [ExampleDbPrincipalArrangeLogins];SET @Credential=NULL;
    SELECT @OwnerLoginId=[principal_id] FROM [sys].[server_principals] WHERE [name]=@OwnerLogin;
    SELECT @RestrictedLoginId=[principal_id] FROM [sys].[server_principals] WHERE [name]=@RestrictedLogin;
    SET @Sql=N'GRANT VIEW ANY DATABASE TO '+QUOTENAME(@RestrictedLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;

    DECLARE [ExampleDbPrincipalArrangeDatabases] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [n] FROM (VALUES(@DbA),(@DbB),(@DbC)) AS [v]([n]);
    OPEN [ExampleDbPrincipalArrangeDatabases];FETCH NEXT FROM [ExampleDbPrincipalArrangeDatabases] INTO @ArrangeName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'CREATE DATABASE '+QUOTENAME(@ArrangeName)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        INSERT [#ExampleDbPrincipal_OwnDatabases]
            SELECT [d].[name],[d].[database_id],[r].[database_guid]
            FROM [sys].[databases] AS [d] INNER JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id]
            WHERE [d].[name]=@ArrangeName;
        FETCH NEXT FROM [ExampleDbPrincipalArrangeDatabases] INTO @ArrangeName;
    END;
    CLOSE [ExampleDbPrincipalArrangeDatabases];DEALLOCATE [ExampleDbPrincipalArrangeDatabases];
    SELECT @IdA=[DatabaseId],@GuidA=[DatabaseGuid] FROM [#ExampleDbPrincipal_OwnDatabases] WHERE [DatabaseName]=@DbA;
    SELECT @IdB=[DatabaseId],@GuidB=[DatabaseGuid] FROM [#ExampleDbPrincipal_OwnDatabases] WHERE [DatabaseName]=@DbB;
    SELECT @IdC=[DatabaseId],@GuidC=[DatabaseGuid] FROM [#ExampleDbPrincipal_OwnDatabases] WHERE [DatabaseName]=@DbC;
    IF @IdA IS NULL OR @GuidA IS NULL OR @IdB IS NULL OR @GuidB IS NULL OR @IdC IS NULL OR @GuidC IS NULL
        THROW 57112,N'Databaseprincipal owned database binding is incomplete.',1;

    -- Replay the actual source guard with controlled identity mismatches; this is a
    -- guard-stage test, not evidence of a concurrent rename/drop race in the SUT.
    DECLARE @GuardDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_DatabasePrincipalAnalysis')),
        @GuardStart int,@GuardEnd int,@Guard nvarchar(max),@GuardAssignment nvarchar(max),
        @GuardCreated datetime,@GuardId int,@GuardName sysname,@GuardExpectedCreated datetime,@GuardCase int=0;
    SELECT @GuardStart=CHARINDEX(N'-- TARGET_IDENTITY_GUARD_BEGIN',@GuardDefinition COLLATE SQL_Latin1_General_CP1_CS_AS),
           @GuardEnd=CHARINDEX(N'-- TARGET_IDENTITY_GUARD_END',@GuardDefinition COLLATE SQL_Latin1_General_CP1_CS_AS);
    IF @GuardStart=0 OR @GuardEnd<=@GuardStart
        THROW 57189,N'Databaseprincipal source identity guard is not discoverable for the stage probe.',1;
    SET @GuardAssignment=N'DECLARE @IdentityGuard nvarchar(max);'+CHAR(10)
        +SUBSTRING(@GuardDefinition,@GuardStart,@GuardEnd-@GuardStart)+N'SET @Result=@IdentityGuard;';
    EXEC [sys].[sp_executesql] @GuardAssignment,N'@Result nvarchar(max) OUTPUT',@Result=@Guard OUTPUT;
    SELECT @GuardCreated=[create_date] FROM [sys].[databases] WHERE [database_id]=@IdA;
    WHILE @GuardCase<4
    BEGIN
        SELECT @GuardId=CASE WHEN @GuardCase=1 THEN -1 ELSE @IdA END,
               @GuardName=CASE WHEN @GuardCase=2 THEN N'ExampleWrongIdentity' ELSE @DbA END,
               @GuardExpectedCreated=CASE WHEN @GuardCase=3 THEN DATEADD(day,-1,@GuardCreated) ELSE @GuardCreated END,
               @ProbeError=NULL;
        SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; '+@Guard;
        BEGIN TRY
            EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime',
                @Id=@GuardId,@Name=@GuardName,@Created=@GuardExpectedCreated;
        END TRY
        BEGIN CATCH
            SET @ProbeError=ERROR_NUMBER();
        END CATCH;
        IF (@GuardCase=0 AND @ProbeError IS NOT NULL)
           OR (@GuardCase>0 AND COALESCE(@ProbeError,0)<>51012)
            THROW 57189,N'Databaseprincipal source identity guard stage mismatch.',1;
        SET @GuardCase+=1;
    END;

    DECLARE [ExampleDbPrincipalArrangeUsers] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [n] FROM (VALUES(@DbA),(@DbB)) AS [v]([n]);
    OPEN [ExampleDbPrincipalArrangeUsers];FETCH NEXT FROM [ExampleDbPrincipalArrangeUsers] INTO @ArrangeName;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'USE '+QUOTENAME(@ArrangeName)+N'; CREATE USER '+QUOTENAME(@User)+N' FOR LOGIN '+QUOTENAME(@Login)+N';
            CREATE USER '+QUOTENAME(@RestrictedUser)+N' FOR LOGIN '+QUOTENAME(@RestrictedLogin)+N';
            CREATE USER '+QUOTENAME(@OwnerUser)+N' WITHOUT LOGIN;
            CREATE ROLE '+QUOTENAME(@RoleA)+N'; CREATE ROLE '+QUOTENAME(@RoleB)+N';
            ALTER ROLE '+QUOTENAME(@RoleA)+N' ADD MEMBER '+QUOTENAME(@User)+N';
            ALTER ROLE '+QUOTENAME(@RoleB)+N' ADD MEMBER '+QUOTENAME(@RoleA)+N';';
        EXEC [sys].[sp_executesql] @Sql;
        SET @Inner=N'CREATE SCHEMA '+QUOTENAME(@Schema)+N' AUTHORIZATION '+QUOTENAME(@OwnerUser)+N';';
        SET @Sql=N'EXEC '+QUOTENAME(@ArrangeName)+N'.[sys].[sp_executesql] @Ddl;';
        EXEC [sys].[sp_executesql] @Sql,N'@Ddl nvarchar(max)',@Ddl=@Inner;
        SET @Sql=N'USE '+QUOTENAME(@ArrangeName)+N'; CREATE TABLE '+QUOTENAME(@Schema)+N'.[ExampleEvidence]([Id] int NOT NULL,[Value] nvarchar(20) NULL);
            INSERT '+QUOTENAME(@Schema)+N'.[ExampleEvidence] VALUES(1,N''Example'');
            GRANT SELECT ON '+QUOTENAME(@Schema)+N'.[ExampleEvidence] TO '+QUOTENAME(@RoleA)+N';
            GRANT VIEW DEFINITION ON '+QUOTENAME(@Schema)+N'.[ExampleEvidence] TO '+QUOTENAME(@RoleA)+N' WITH GRANT OPTION;
            REVOKE SELECT ON '+QUOTENAME(@Schema)+N'.[ExampleEvidence]([Value]) FROM '+QUOTENAME(@RoleA)+N';
            DENY UPDATE ON '+QUOTENAME(@Schema)+N'.[ExampleEvidence] TO '+QUOTENAME(@User)+N';
            GRANT VIEW DEFINITION ON USER::'+QUOTENAME(@User)+N' TO '+QUOTENAME(@RestrictedUser)+N';';
        EXEC [sys].[sp_executesql] @Sql;
        FETCH NEXT FROM [ExampleDbPrincipalArrangeUsers] INTO @ArrangeName;
    END;
    CLOSE [ExampleDbPrincipalArrangeUsers];DEALLOCATE [ExampleDbPrincipalArrangeUsers];
    SET @Sql=N'ALTER AUTHORIZATION ON DATABASE::'+QUOTENAME(@DbA)+N' TO '+QUOTENAME(@OwnerLogin)+N'; ALTER AUTHORIZATION ON DATABASE::'+QUOTENAME(@DbB)+N' TO '+QUOTENAME(@OwnerLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
    SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbA)+N' SET CONTAINMENT=PARTIAL;';EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; CREATE USER '+QUOTENAME(@OrphanUser)+N' FOR LOGIN '+QUOTENAME(@OrphanLogin)+N';
        CREATE USER '+QUOTENAME(@ContainedUser)+N' WITH PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N';';
    EXEC [sys].[sp_executesql] @Sql;SET @Credential=NULL;
    IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_OwnLogins] AS [o] INNER JOIN [sys].[server_principals] AS [p]
                  ON [p].[principal_id]=[o].[PrincipalId] AND [p].[sid]=[o].[Sid]
                 AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[o].[LoginName] COLLATE SQL_Latin1_General_CP1_CS_AS
                  WHERE [o].[LoginName]=@OrphanLogin)
        THROW 57113,N'Databaseprincipal orphan login ownership differs.',1;
    SET @Sql=N'DROP LOGIN '+QUOTENAME(@OrphanLogin)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
    DELETE FROM [#ExampleDbPrincipal_OwnLogins] WHERE [LoginName]=@OrphanLogin;
    SET @Sql=N'CREATE USER '+QUOTENAME(@RestrictedUser)+N' FOR LOGIN '+QUOTENAME(@RestrictedLogin)+N';';
    EXEC [sys].[sp_executesql] @Sql;SET @FrameworkUserMade=1;
    SELECT @FrameworkUserId=[principal_id],@FrameworkUserSid=[sid] FROM [sys].[database_principals] WHERE [name]=@RestrictedUser;
    SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_DatabasePrincipalAnalysis] TO '+QUOTENAME(@RestrictedUser)+N';';
    EXEC [sys].[sp_executesql] @Sql;

    CREATE TABLE [#ExampleDbPrincipal_Expected_moduleStatus]([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_databaseContext]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalId] int NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerBindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_principals]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_roleMemberships]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RolePrincipalId] int NOT NULL, [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_permissions]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [GranteePrincipalId] int NOT NULL, [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MajorId] int NOT NULL, [MinorId] int NOT NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_schemaOwners]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwningPrincipalId] int NOT NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_loginBindings]([DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ServerPrincipalId] int NULL, [ServerPrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_sourceStatus]([DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#ExampleDbPrincipal_Expected_warnings]([DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ExampleDbPrincipal_Shapes]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    INSERT [#ExampleDbPrincipal_Shapes] VALUES
        (N'moduleStatus',N'#ExampleDbPrincipal_Expected_moduleStatus',N'#ExampleDbPrincipal_moduleStatus'),
        (N'databaseContext',N'#ExampleDbPrincipal_Expected_databaseContext',N'#ExampleDbPrincipal_databaseContext'),
        (N'principals',N'#ExampleDbPrincipal_Expected_principals',N'#ExampleDbPrincipal_principals'),
        (N'roleMemberships',N'#ExampleDbPrincipal_Expected_roleMemberships',N'#ExampleDbPrincipal_roleMemberships'),
        (N'permissions',N'#ExampleDbPrincipal_Expected_permissions',N'#ExampleDbPrincipal_permissions'),
        (N'schemaOwners',N'#ExampleDbPrincipal_Expected_schemaOwners',N'#ExampleDbPrincipal_schemaOwners'),
        (N'loginBindings',N'#ExampleDbPrincipal_Expected_loginBindings',N'#ExampleDbPrincipal_loginBindings'),
        (N'sourceStatus',N'#ExampleDbPrincipal_Expected_sourceStatus',N'#ExampleDbPrincipal_sourceStatus'),
        (N'warnings',N'#ExampleDbPrincipal_Expected_warnings',N'#ExampleDbPrincipal_warnings');

    SET @Sql=N'SELECT @UserId=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@User;
        SELECT @RoleIdA=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@RoleA;
        SELECT @RoleIdB=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@RoleB;
        SELECT @OwnerUserId=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@OwnerUser;
        SELECT @OrphanId=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@Orphan;
        SELECT @ContainedId=[principal_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[database_principals] WHERE [name]=@Contained;
        SELECT @SchemaId=[schema_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[schemas] WHERE [name]=@Schema;
        SELECT @ObjectId=[o].[object_id] FROM '+QUOTENAME(@DbA)+N'.[sys].[objects] AS [o]
        INNER JOIN '+QUOTENAME(@DbA)+N'.[sys].[schemas] AS [x] ON [x].[schema_id]=[o].[schema_id]
        WHERE [x].[name]=@Schema AND [o].[name]=N''ExampleEvidence'';';
    EXEC [sys].[sp_executesql] @Sql,
        N'@User sysname,@RoleA sysname,@RoleB sysname,@OwnerUser sysname,@Orphan sysname,@Contained sysname,@Schema sysname,
          @UserId int OUTPUT,@RoleIdA int OUTPUT,@RoleIdB int OUTPUT,@OwnerUserId int OUTPUT,@OrphanId int OUTPUT,@ContainedId int OUTPUT,@SchemaId int OUTPUT,@ObjectId int OUTPUT',
        @User=@User,@RoleA=@RoleA,@RoleB=@RoleB,@OwnerUser=@OwnerUser,@Orphan=@OrphanUser,@Contained=@ContainedUser,@Schema=@Schema,
        @UserId=@UserAId OUTPUT,@RoleIdA=@RoleAId OUTPUT,@RoleIdB=@RoleBId OUTPUT,@OwnerUserId=@OwnerUserAId OUTPUT,
        @OrphanId=@OrphanUserId OUTPUT,@ContainedId=@ContainedUserId OUTPUT,@SchemaId=@SchemaAId OUTPUT,@ObjectId=@ObjectAId OUTPUT;
    SET @Sql=N'SELECT @UserId=[principal_id] FROM '+QUOTENAME(@DbB)+N'.[sys].[database_principals] WHERE [name]=@User;';
    EXEC [sys].[sp_executesql] @Sql,N'@User sysname,@UserId int OUTPUT',@User=@User,@UserId=@UserBId OUTPUT;
    IF @UserAId IS NULL OR @UserBId IS NULL OR @UserAId<>@UserBId
       OR @RoleAId IS NULL OR @RoleBId IS NULL OR @OwnerUserAId IS NULL OR @OrphanUserId IS NULL
       OR @ContainedUserId IS NULL OR @SchemaAId IS NULL OR @ObjectAId IS NULL
        THROW 57114,N'Independent database fixture identities or repeated local principal IDs differ.',1;

    DECLARE @NativeDbId int;
    DECLARE [ExampleDbPrincipalNativeReference] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [DatabaseName],[DatabaseId] FROM [#ExampleDbPrincipal_OwnDatabases] WHERE [DatabaseId] IN (@IdA,@IdB) ORDER BY [DatabaseId];
    OPEN [ExampleDbPrincipalNativeReference];FETCH NEXT FROM [ExampleDbPrincipalNativeReference] INTO @ArrangeName,@NativeDbId;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Sql=N'INSERT [#ExampleDbPrincipal_Expected_principals]
            SELECT @Id,@Name,[principal_id],[name],[type],[type_desc],[authentication_type],[authentication_type_desc],
                [default_schema_name],[create_date],[modify_date],[is_fixed_role],[owning_principal_id]
            FROM '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals];
            INSERT [#ExampleDbPrincipal_Expected_roleMemberships]
            SELECT @Id,@Name,[r].[role_principal_id],[p].[name],[r].[member_principal_id],[m].[name]
            FROM '+QUOTENAME(@ArrangeName)+N'.[sys].[database_role_members] AS [r]
            LEFT JOIN '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals] AS [p] ON [p].[principal_id]=[r].[role_principal_id]
            LEFT JOIN '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals] AS [m] ON [m].[principal_id]=[r].[member_principal_id];
            INSERT [#ExampleDbPrincipal_Expected_permissions]
            SELECT @Id,@Name,[r].[grantee_principal_id],[p].[name],[r].[grantor_principal_id],[g].[name],
                   [r].[class],[r].[class_desc],[r].[major_id],[r].[minor_id],[r].[permission_name],[r].[state],[r].[state_desc]
            FROM '+QUOTENAME(@ArrangeName)+N'.[sys].[database_permissions] AS [r]
            LEFT JOIN '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals] AS [p] ON [p].[principal_id]=[r].[grantee_principal_id]
            LEFT JOIN '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals] AS [g] ON [g].[principal_id]=[r].[grantor_principal_id];
            INSERT [#ExampleDbPrincipal_Expected_schemaOwners]
            SELECT @Id,@Name,[x].[schema_id],[x].[name],[x].[principal_id],[p].[name]
            FROM '+QUOTENAME(@ArrangeName)+N'.[sys].[schemas] AS [x]
            LEFT JOIN '+QUOTENAME(@ArrangeName)+N'.[sys].[database_principals] AS [p] ON [p].[principal_id]=[x].[principal_id];';
        EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname',@Id=@NativeDbId,@Name=@ArrangeName;
        INSERT [#ExampleDbPrincipal_Expected_databaseContext]
            SELECT [database_id],[name],[state_desc],[containment_desc],@OwnerLoginId,@OwnerLogin,'S','MATCHED_VISIBLE_OWNER'
            FROM [sys].[databases] WHERE [database_id]=@NativeDbId;
        FETCH NEXT FROM [ExampleDbPrincipalNativeReference] INTO @ArrangeName,@NativeDbId;
    END;
    CLOSE [ExampleDbPrincipalNativeReference];DEALLOCATE [ExampleDbPrincipalNativeReference];
    IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_Expected_permissions]
                  WHERE [DatabaseId]=@IdA AND [MajorId]=@ObjectAId AND [MinorId]=2 AND [GranteePrincipalId]=@RoleAId AND [PermissionState]='R')
       OR NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_Expected_permissions]
                     WHERE [DatabaseId]=@IdA AND [MajorId]=@ObjectAId AND [GranteePrincipalId]=@RoleAId AND [PermissionState]='W')
       OR NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_Expected_permissions]
                     WHERE [DatabaseId]=@IdA AND [MajorId]=@ObjectAId AND [GranteePrincipalId]=@UserAId AND [PermissionState]='D')
        THROW 57115,N'Independent native column REVOKE or grant-state fixture is not established.',1;

    CREATE TABLE [#ExampleDbPrincipal_ExpectedFacets]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Ordinal] bigint NOT NULL,
     [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SystemTypeId] tinyint NOT NULL,
     [MaxLength] smallint NOT NULL,[Precision] tinyint NOT NULL,[Scale] tinyint NOT NULL,[IsNullable] bit NOT NULL,
     [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    SELECT TOP(0) * INTO [#ExampleDbPrincipal_ActualFacets] FROM [#ExampleDbPrincipal_ExpectedFacets];
    INSERT [#ExampleDbPrincipal_ExpectedFacets]
        SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),
               [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
        FROM [#ExampleDbPrincipal_Shapes] AS [s] INNER JOIN [tempdb].[sys].[columns] AS [c]
          ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ExpectedName]);
    CREATE TABLE [#ExampleDbPrincipal_Sentinel]([Id] int NOT NULL PRIMARY KEY,[Value] int NOT NULL);
    INSERT [#ExampleDbPrincipal_Sentinel] VALUES(1,10);
    WHILE @Case<4
    BEGIN
        SET @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;
        SET @SourceLock=CASE WHEN @Case%2=0 THEN 0 ELSE 31 END;
        SET LOCK_TIMEOUT 37;
        IF @Case%2=0 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        CREATE TABLE [#ExampleDbPrincipal_moduleStatus]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_databaseContext]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_principals]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_roleMemberships]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_permissions]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_schemaOwners]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_loginBindings]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_sourceStatus]([Seed] int NULL);
        CREATE TABLE [#ExampleDbPrincipal_warnings]([Seed] int NULL);
        IF @Case=3
        BEGIN BEGIN TRANSACTION;UPDATE [#ExampleDbPrincipal_Sentinel] SET [Value]=11 WHERE [Id]=1;END;
        EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@MaxZeilen=@Limit,@LockTimeoutMs=@SourceLock,@ResultSetArt='TABLE',
            @ResultTablesJson=N'{"moduleStatus":"#ExampleDbPrincipal_moduleStatus","databaseContext":"#ExampleDbPrincipal_databaseContext","principals":"#ExampleDbPrincipal_principals","roleMemberships":"#ExampleDbPrincipal_roleMemberships","permissions":"#ExampleDbPrincipal_permissions","schemaOwners":"#ExampleDbPrincipal_schemaOwners","loginBindings":"#ExampleDbPrincipal_loginBindings","sourceStatus":"#ExampleDbPrincipal_sourceStatus","warnings":"#ExampleDbPrincipal_warnings"}',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT;
        IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1 OR ISJSON(@Json)<>1 OR @Error IS NOT NULL
           OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>10 OR JSON_VALUE(@Json,N'$.meta.resultName') COLLATE SQL_Latin1_General_CP1_CS_AS<>N'DatabasePrincipalAnalysis'
           OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion'))<>1
           OR @@LOCK_TIMEOUT<>37 OR DB_ID()<>@OriginalDatabase OR @@TRANCOUNT<>CASE WHEN @Case=3 THEN 1 ELSE 0 END
           OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>CASE WHEN @Case%2=0 THEN 1 ELSE 0 END
            THROW 57116,N'Databaseprincipal status or caller state differs.',1;
        IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_sourceStatus])<>13
           OR EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_sourceStatus]
                     WHERE [StatusCode]<>'AVAILABLE_LIMITED' OR [VisibilityScope]<>'VISIBLE_ONLY'
                        OR [StartedAtUtc]>[CompletedAtUtc] OR [ObservedRows] IS NULL)
            THROW 57117,N'Databaseprincipal successful source scope or timing differs.',1;
        IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_databaseContext])<>2
           OR EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_databaseContext] WHERE [DatabaseId] NOT IN (@IdA,@IdB))
            THROW 57118,N'Databaseprincipal explicit bracket-aware selection differs.',1;
        DELETE FROM [#ExampleDbPrincipal_ActualFacets];
        INSERT [#ExampleDbPrincipal_ActualFacets]
            SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),
                   [c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
            FROM [#ExampleDbPrincipal_Shapes] AS [s] INNER JOIN [tempdb].[sys].[columns] AS [c]
              ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ActualName]);
        IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_ActualFacets] EXCEPT SELECT * FROM [#ExampleDbPrincipal_ExpectedFacets])
           OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_ExpectedFacets] EXCEPT SELECT * FROM [#ExampleDbPrincipal_ActualFacets])
            THROW 57119,N'Databaseprincipal independent nine-set native schema facets differ.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.moduleStatus'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: moduleStatus.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_databaseContext] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.databaseContext'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: databaseContext.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_principals] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.principals'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: principals.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_roleMemberships] ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.roleMemberships'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: roleMemberships.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_permissions] ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.permissions'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: permissions.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_schemaOwners] ORDER BY [DatabaseId],[SchemaId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.schemaOwners'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: schemaOwners.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_loginBindings] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.loginBindings'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: loginBindings.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: sourceStatus.',1;
        SET @Expected=(SELECT * FROM [#ExampleDbPrincipal_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.warnings'),N'[]' COLLATE SQL_Latin1_General_CP1_CS_AS) COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57120,N'Databaseprincipal same-call TABLE JSON parity differs: warnings.',1;
        IF @Case<>1
        BEGIN
            IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_Expected_databaseContext] EXCEPT SELECT * FROM [#ExampleDbPrincipal_databaseContext])
               OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_databaseContext] EXCEPT SELECT * FROM [#ExampleDbPrincipal_Expected_databaseContext])
                THROW 57121,N'Databaseprincipal independent native value oracle differs: databaseContext.',1;
            IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_Expected_principals] EXCEPT SELECT * FROM [#ExampleDbPrincipal_principals])
               OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_principals] EXCEPT SELECT * FROM [#ExampleDbPrincipal_Expected_principals])
                THROW 57121,N'Databaseprincipal independent native value oracle differs: principals.',1;
            IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_Expected_roleMemberships] EXCEPT SELECT * FROM [#ExampleDbPrincipal_roleMemberships])
               OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_roleMemberships] EXCEPT SELECT * FROM [#ExampleDbPrincipal_Expected_roleMemberships])
                THROW 57121,N'Databaseprincipal independent native value oracle differs: roleMemberships.',1;
            IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_Expected_permissions] EXCEPT SELECT * FROM [#ExampleDbPrincipal_permissions])
               OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_permissions] EXCEPT SELECT * FROM [#ExampleDbPrincipal_Expected_permissions])
                THROW 57121,N'Databaseprincipal independent native value oracle differs: permissions.',1;
            IF EXISTS(SELECT * FROM [#ExampleDbPrincipal_Expected_schemaOwners] EXCEPT SELECT * FROM [#ExampleDbPrincipal_schemaOwners])
               OR EXISTS(SELECT * FROM [#ExampleDbPrincipal_schemaOwners] EXCEPT SELECT * FROM [#ExampleDbPrincipal_Expected_schemaOwners])
                THROW 57121,N'Databaseprincipal independent native value oracle differs: schemaOwners.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_roleMemberships]
                          WHERE [DatabaseId]=@IdA AND [RolePrincipalId]=@RoleAId AND [MemberPrincipalId]=@UserAId)
               OR NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_roleMemberships]
                              WHERE [DatabaseId]=@IdA AND [RolePrincipalId]=@RoleBId AND [MemberPrincipalId]=@RoleAId)
               OR EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_roleMemberships]
                          WHERE [DatabaseId]=@IdA AND [RolePrincipalId]=@RoleBId AND [MemberPrincipalId]=@UserAId)
                THROW 57122,N'Databaseprincipal direct role edges or transitive exclusion differs.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_loginBindings]
                          WHERE [DatabaseId]=@IdA AND [PrincipalId]=@OrphanUserId AND [BindingStatus]='NO_VISIBLE_LOGIN_MATCH'
                            AND [ServerPrincipalId] IS NULL AND [ServerPrincipalName] IS NULL)
               OR NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_loginBindings]
                              WHERE [DatabaseId]=@IdA AND [PrincipalId]=@ContainedUserId AND [BindingStatus]='DATABASE_AUTHENTICATED'
                                AND [ServerPrincipalId] IS NULL AND [ServerPrincipalName] IS NULL)
               OR NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_loginBindings]
                              WHERE [DatabaseId]=@IdA AND [PrincipalId]=@OwnerUserAId AND [BindingStatus]='NOT_APPLICABLE')
               OR EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_loginBindings]
                          WHERE [PrincipalName] IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') AND [BindingStatus]<>'NOT_APPLICABLE')
                THROW 57123,N'Databaseprincipal independent orphan contained or builtin binding states differ.',1;
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_loginBindings] WHERE [DatabaseId] IN (@IdA,@IdB)
                 AND [PrincipalName]=@User AND [BindingStatus]='MATCHED_VISIBLE_LOGIN' AND [ServerPrincipalName]=@Login)<>2
                THROW 57124,N'Databaseprincipal repeated local principal ID lost its database or visible login binding.',1;
        END
        ELSE
        BEGIN
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_principals])>1 THROW 57125,N'Databaseprincipal global limit differs: principals.',1;
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_roleMemberships])>1 THROW 57125,N'Databaseprincipal global limit differs: roleMemberships.',1;
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_permissions])>1 THROW 57125,N'Databaseprincipal global limit differs: permissions.',1;
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_schemaOwners])>1 THROW 57125,N'Databaseprincipal global limit differs: schemaOwners.',1;
            IF (SELECT COUNT(*) FROM [#ExampleDbPrincipal_loginBindings])>1 THROW 57125,N'Databaseprincipal global limit differs: loginBindings.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_sourceStatus] WHERE [IsLimited]=1 AND [ObservedRows]>[ReturnedRows])
               OR EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_roleMemberships] WHERE [RoleName] IS NULL OR [MemberName] IS NULL)
                THROW 57126,N'Databaseprincipal limit diagnostics or prelimit lookup differs.',1;
        END;
        IF @Case=3
        BEGIN
            IF XACT_STATE()<>1 OR (SELECT [Value] FROM [#ExampleDbPrincipal_Sentinel] WHERE [Id]=1)<>11
                THROW 57127,N'Databaseprincipal caller transaction or independent sentinel differs.',1;
            ROLLBACK TRANSACTION;
            IF (SELECT [Value] FROM [#ExampleDbPrincipal_Sentinel] WHERE [Id]=1)<>10
                THROW 57128,N'Databaseprincipal caller rollback ownership differs.',1;
        END;
        DROP TABLE [#ExampleDbPrincipal_moduleStatus];
        DROP TABLE [#ExampleDbPrincipal_databaseContext];
        DROP TABLE [#ExampleDbPrincipal_principals];
        DROP TABLE [#ExampleDbPrincipal_roleMemberships];
        DROP TABLE [#ExampleDbPrincipal_permissions];
        DROP TABLE [#ExampleDbPrincipal_schemaOwners];
        DROP TABLE [#ExampleDbPrincipal_loginBindings];
        DROP TABLE [#ExampleDbPrincipal_sourceStatus];
        DROP TABLE [#ExampleDbPrincipal_warnings];
        SET @Case+=1;
    END;
    DECLARE @DefaultDatabases bigint=(SELECT COUNT_BIG(*) FROM [master].[sys].[databases]
        WHERE [database_id]>4 AND [source_database_id] IS NULL AND [state]=0 AND HAS_DBACCESS([name])=1);
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @MaxZeilen=1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>@DefaultDatabases
        THROW 57129,N'Databaseprincipal default selection does not cover visible online user databases.',1;
    SET @Exact=QUOTENAME(@DbA);
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF ISJSON(@Json)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseContext') WITH([DatabaseId] int N'$.DatabaseId') WHERE [DatabaseId]=@IdA)
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseContext') WITH([DatabaseId] int N'$.DatabaseId') WHERE [DatabaseId]<>@IdA)
        THROW 57190,N'Databaseprincipal exact-name consumer selection did not resolve only the requested numeric database identity.',1;
    DECLARE @WrongCaseName sysname=N'e'+SUBSTRING(@DbA,2,128);
    SET @Exact=QUOTENAME(@WrongCaseName);
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'DATABASE_UNAVAILABLE'
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode')
            WHERE [SourceKind]='SELECTION' AND [StatusCode]='DATABASE_UNAVAILABLE')
        THROW 57191,N'Databaseprincipal wrong-case exact-name selection was not rejected as unavailable.',1;
    SET @Exact=QUOTENAME(@DbA)+N'|'+QUOTENAME(@DbB);
    SET @Pattern=N'like:ExampleDbPrincipalA%'+@Suffix;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNamePattern=@Pattern,@MaxZeilen=1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext') WITH([DatabaseId] int N'$.DatabaseId') WHERE [DatabaseId]=@IdA)<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>1
        THROW 57130,N'Databaseprincipal independent LIKE selection differs.',1;
    DECLARE @MissingName sysname=N'ExampleDbMissing_'+@Suffix;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@MissingName,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'DATABASE_UNAVAILABLE'
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.principals'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode')
            WHERE [SourceKind]='SELECTION' AND [StatusCode]='DATABASE_UNAVAILABLE')
        THROW 57131,N'Databaseprincipal missing-or-hidden target boundary differs.',1;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=N'master',@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'SYSTEM_DATABASE_EXCLUDED' OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>0
        THROW 57132,N'Databaseprincipal system database exclusion differs.',1;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=N'master',@SystemdatenbankenEinbeziehen=1,
        @MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseContext') WITH([DatabaseId] int N'$.DatabaseId') WHERE [DatabaseId]=1)
        THROW 57133,N'Databaseprincipal explicit system database opt-in differs.',1;
    SET @Pattern=N'regex:^ExampleDbPrincipalA[|]'+@Suffix+N'$';
    EXEC @Return=[monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNamePattern=@Pattern,@MaxZeilen=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17
       AND TRY_CONVERT(int,DATABASEPROPERTYEX(DB_NAME(),N'CompatibilityLevel'))>=170
    BEGIN
        IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED' OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>1
            THROW 57134,N'Databaseprincipal supported regex selection differs.',1;
    END
    ELSE IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'UNAVAILABLE_FEATURE' OR @Json IS NOT NULL OR COALESCE(@Return,0)<>51011
        THROW 57135,N'Databaseprincipal native unsupported regex boundary differs.',1;

    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@RestrictedLogin,'''')+N';
        BEGIN TRY
            IF SUSER_ID()<>@ExpectedLoginId THROW 57136,N''Restricted database fixture context differs.'',1;
            IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@HiddenLogin)
                THROW 57137,N''Restricted server metadata fixture is not established.'',1;
            IF COALESCE(HAS_DBACCESS(@DeniedDatabase),1)<>0
                THROW 57138,N''Restricted database access fixture is not established.'',1;
            EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',
                @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
            REVERT;
        END TRY
        BEGIN CATCH REVERT;THROW;END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,
        N'@ExpectedLoginId int,@HiddenLogin sysname,@DeniedDatabase sysname,@Names nvarchar(max),@Json nvarchar(max) OUTPUT,@Status varchar(40) OUTPUT',
        @ExpectedLoginId=@RestrictedLoginId,@HiddenLogin=@Login,@DeniedDatabase=@DbC,@Names=@Exact,@Json=@Json OUTPUT,@Status=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED'
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.loginBindings')
            WITH([PrincipalName] sysname N'$.PrincipalName',[BindingStatus] varchar(40) N'$.BindingStatus')
            WHERE [PrincipalName]=@User AND [BindingStatus]='NO_VISIBLE_LOGIN_MATCH')<>2
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext')
            WITH([OwnerBindingStatus] varchar(40) N'$.OwnerBindingStatus') WHERE [OwnerBindingStatus]='NO_VISIBLE_OWNER_MATCH')<>2
        THROW 57139,N'Databaseprincipal restricted metadata was misclassified as a complete identity or owner proof.',1;
    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@RestrictedLogin,'''')+N';
        BEGIN TRY
            EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',
                @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
            REVERT;
        END TRY
        BEGIN CATCH REVERT;THROW;END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(max),@Json nvarchar(max) OUTPUT,@Status varchar(40) OUTPUT',
        @Names=@DbC,@Json=@Json OUTPUT,@Status=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'DATABASE_UNAVAILABLE' OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.principals'))<>0
        THROW 57140,N'Databaseprincipal inaccessible target became a successful empty source.',1;

    SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; DENY SELECT ON [sys].[database_permissions] TO '+QUOTENAME(@RestrictedUser)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Inner=N'SELECT @Rows=COUNT_BIG(*) FROM '+QUOTENAME(@DbA)+N'.[sys].[database_permissions];';
    SET @ProbeError=NULL;
    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@RestrictedLogin,'''')+N';
        BEGIN TRY
            SET XACT_ABORT OFF;
            BEGIN TRY
                DECLARE @ProbeRows bigint;
                EXEC [sys].[sp_executesql] @Probe,N''@Rows bigint OUTPUT'',@Rows=@ProbeRows OUTPUT;
            END TRY
            BEGIN CATCH SET @ProbeError=ERROR_NUMBER();END CATCH;
            IF COALESCE(@ProbeError,0)<>229 THROW 57141,N''Owned database permission-source denial is not established.'',1;
            CREATE TABLE [#ExampleDbPrincipal_RestrictedSentinel]([Id] int NOT NULL PRIMARY KEY,[Value] int NOT NULL);
            INSERT [#ExampleDbPrincipal_RestrictedSentinel] VALUES(1,10);
            SET LOCK_TIMEOUT 53;SET XACT_ABORT ON;BEGIN TRANSACTION;
            UPDATE [#ExampleDbPrincipal_RestrictedSentinel] SET [Value]=11 WHERE [Id]=1;
            EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Names,@ResultSetArt=''NONE'',
                @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
            IF XACT_STATE()<>1 OR @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS&16384)<>16384
               OR (SELECT [Value] FROM [#ExampleDbPrincipal_RestrictedSentinel] WHERE [Id]=1)<>11
                THROW 57142,N''Denied database source changed caller state or independent sentinel.'',1;
            ROLLBACK TRANSACTION;
            IF (SELECT [Value] FROM [#ExampleDbPrincipal_RestrictedSentinel] WHERE [Id]=1)<>10
                THROW 57143,N''Denied database source consumed caller rollback ownership.'',1;
            DROP TABLE [#ExampleDbPrincipal_RestrictedSentinel];
            REVERT;
        END TRY
        BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;REVERT;THROW;END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,
        N'@Probe nvarchar(max),@Names nvarchar(max),@ProbeError int OUTPUT,@Json nvarchar(max) OUTPUT,@Status varchar(40) OUTPUT',
        @Probe=@Inner,@Names=@Exact,@ProbeError=@ProbeError OUTPUT,@Json=@Json OUTPUT,@Status=@Status OUTPUT;
    IF COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED'
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([DatabaseId] int N'$.DatabaseId',[SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[ErrorNumber] int N'$.ErrorNumber')
            WHERE [DatabaseId]=@IdA AND [SourceKey]='DATABASE_PERMISSIONS' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber]=@ProbeError)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([DatabaseId] int N'$.DatabaseId',[SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode')
            WHERE [DatabaseId]=@IdB AND [SourceKey]='DATABASE_PERMISSIONS' AND [StatusCode]='AVAILABLE_LIMITED')
        THROW 57144,N'Databaseprincipal source denial was not isolated by native database identity.',1;

    SET LOCK_TIMEOUT 43;SET XACT_ABORT ON;BEGIN TRANSACTION;
    UPDATE [#ExampleDbPrincipal_Sentinel] SET [Value]=13 WHERE [Id]=1;
    SET @Json=N'{"previous":true}';
    EXEC @Return=[monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"unknown":"#ExampleDbMissing"}',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,0)<>51011 OR COALESCE(@Error,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'ERROR_HANDLED' OR @Json IS NOT NULL
       OR XACT_STATE()<>1 OR @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>43 OR (@@OPTIONS&16384)<>16384
       OR (SELECT [Value] FROM [#ExampleDbPrincipal_Sentinel] WHERE [Id]=1)<>13
        THROW 57145,N'Databaseprincipal rejected TABLE mapping lost RETURN OUTPUT JSON or caller ownership.',1;
    EXEC @Return=[monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@MaxZeilen=-1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,0)<>51011 OR COALESCE(@Error,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'INVALID_PARAMETER' OR @Json IS NOT NULL
       OR XACT_STATE()<>1 OR @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>43 OR (@@OPTIONS&16384)<>16384
        THROW 57146,N'Databaseprincipal negative limit or caller state differs.',1;
    EXEC @Return=[monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@DatabaseNamePattern=N'like:Example%',
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,0)<>51011 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'INVALID_PARAMETER' OR @Json IS NOT NULL OR XACT_STATE()<>1
        THROW 57147,N'Databaseprincipal incompatible filter rejection differs.',1;
    ROLLBACK TRANSACTION;
    IF (SELECT [Value] FROM [#ExampleDbPrincipal_Sentinel] WHERE [Id]=1)<>10
        THROW 57148,N'Databaseprincipal rejected calls consumed the caller sentinel rollback.',1;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@MaxZeilen=1,@ResultSetArt='RAW',@PrintMeldungen=0;
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @Hilfe=1,@PrintMeldungen=0;
    CREATE TABLE [#ExampleDbPrincipal_Console]
    ([Ergebnis] nvarchar(200),[Bereich] nvarchar(64),[Objekt] nvarchar(256),[Detail] nvarchar(1000));
    INSERT [#ExampleDbPrincipal_Console]
        EXEC [monitor].[USP_DatabasePrincipalAnalysis] @DatabaseNames=@Exact,@MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
    IF NOT EXISTS(SELECT 1 FROM [#ExampleDbPrincipal_Console] WHERE [Bereich]=N'Aussagegrenze' AND [Objekt]=N'METADATA_COMPLETENESS_UNPROVEN')
        THROW 57149,N'Databaseprincipal CONSOLE schema or evidence boundary differs.',1;
    IF EXISTS(SELECT 1 FROM [sys].[configurations] WHERE [name] IN (N'contained database authentication',N'show advanced options')
              AND CONVERT(int,[value_in_use])<>1)
        THROW 57150,N'Databaseprincipal consumer changed fixture configuration.',1;
    SET @AllFunctionalCases=1;

END TRY
BEGIN CATCH
    SELECT @FailureNumber=ERROR_NUMBER(),@FailureMessage=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
IF @@TRANCOUNT>@OriginalTx ROLLBACK TRANSACTION;
SET XACT_ABORT OFF;
IF @FailureNumber IS NOT NULL
    RAISERROR(N'DATABASE_PRINCIPAL_PRIMARY_FAILURE %d: %s',10,1,@FailureNumber,@FailureMessage) WITH NOWAIT;
BEGIN TRY
    IF @FrameworkUserMade=1
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals]
                      WHERE [principal_id]=@FrameworkUserId AND [sid]=@FrameworkUserSid AND [name]=@RestrictedUser)
            THROW 57180,N'Owned framework-user identity differs during cleanup.',1;
        SET @Sql=N'DROP USER '+QUOTENAME(@RestrictedUser)+N';';EXEC [sys].[sp_executesql] @Sql;
        IF EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@RestrictedUser)
            THROW 57181,N'Owned framework-user cleanup is incomplete.',1;
    END;
END TRY
BEGIN CATCH
    SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; framework user: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());
END CATCH;
DECLARE @CleanupName sysname,@CleanupId int,@CleanupGuid uniqueidentifier,@CleanupSid varbinary(85);
DECLARE [ExampleDbPrincipalCleanupDatabases] CURSOR LOCAL FAST_FORWARD FOR
    SELECT [DatabaseName],[DatabaseId],[DatabaseGuid] FROM [#ExampleDbPrincipal_OwnDatabases] ORDER BY [DatabaseId] DESC;
OPEN [ExampleDbPrincipalCleanupDatabases];
FETCH NEXT FROM [ExampleDbPrincipalCleanupDatabases] INTO @CleanupName,@CleanupId,@CleanupGuid;
WHILE @@FETCH_STATUS=0
BEGIN
    BEGIN TRY
        IF NOT EXISTS(SELECT 1 FROM [sys].[databases] AS [d]
                      INNER JOIN [sys].[database_recovery_status] AS [r] ON [r].[database_id]=[d].[database_id]
                      WHERE [d].[database_id]=@CleanupId AND [r].[database_guid]=@CleanupGuid
                        AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@CleanupName COLLATE SQL_Latin1_General_CP1_CS_AS)
            THROW 57182,N'Owned target-database identity differs during cleanup.',1;
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@CleanupName)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
        IF EXISTS(SELECT 1 FROM [sys].[databases] WHERE [name]=@CleanupName)
            THROW 57183,N'Owned target-database cleanup is incomplete.',1;
    END TRY
    BEGIN CATCH
        SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; target database: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM [ExampleDbPrincipalCleanupDatabases] INTO @CleanupName,@CleanupId,@CleanupGuid;
END;
CLOSE [ExampleDbPrincipalCleanupDatabases];DEALLOCATE [ExampleDbPrincipalCleanupDatabases];
DECLARE [ExampleDbPrincipalCleanupLogins] CURSOR LOCAL FAST_FORWARD FOR
    SELECT [LoginName],[PrincipalId],[Sid] FROM [#ExampleDbPrincipal_OwnLogins] ORDER BY [PrincipalId] DESC;
OPEN [ExampleDbPrincipalCleanupLogins];
FETCH NEXT FROM [ExampleDbPrincipalCleanupLogins] INTO @CleanupName,@CleanupId,@CleanupSid;
WHILE @@FETCH_STATUS=0
BEGIN
    BEGIN TRY
        IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals]
                      WHERE [principal_id]=@CleanupId AND [sid]=@CleanupSid AND [name]=@CleanupName)
            THROW 57184,N'Owned fixture-login identity differs during cleanup.',1;
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@CleanupName)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
        IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@CleanupName)
            THROW 57185,N'Owned fixture-login cleanup is incomplete.',1;
    END TRY
    BEGIN CATCH
        SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; fixture login: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM [ExampleDbPrincipalCleanupLogins] INTO @CleanupName,@CleanupId,@CleanupSid;
END;
CLOSE [ExampleDbPrincipalCleanupLogins];DEALLOCATE [ExampleDbPrincipalCleanupLogins];
BEGIN TRY
    IF @ChangedContained=1
    BEGIN EXEC [master].[sys].[sp_configure] N'contained database authentication',@OriginalContained;RECONFIGURE;END;
    IF @ChangedAdvanced=1
    BEGIN EXEC [master].[sys].[sp_configure] N'show advanced options',@OriginalAdvanced;RECONFIGURE;END;
    IF EXISTS(SELECT 1 FROM [sys].[configurations] WHERE [name]=N'contained database authentication' AND (CONVERT(int,[value_in_use])<>@OriginalContained OR CONVERT(int,[value])<>@OriginalContainedConfigured))
       OR EXISTS(SELECT 1 FROM [sys].[configurations] WHERE [name]=N'show advanced options' AND (CONVERT(int,[value_in_use])<>@OriginalAdvanced OR CONVERT(int,[value])<>@OriginalAdvancedConfigured))
        THROW 57186,N'Owned fixture configuration restoration differs.',1;
END TRY
BEGIN CATCH
    SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; configuration: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());
END CATCH;
IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
IF @@TRANCOUNT<>@OriginalTx OR DB_ID()<>@OriginalDatabase
   OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@OriginalAbort
    SET @CleanupErrors=CONCAT(@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS,N'; original caller state differs');
IF @CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS<>N''
BEGIN
    DECLARE @CombinedFailure nvarchar(2048)=LEFT(CONCAT(N'Databaseprincipal fixture cleanup failed; primary=',@FailureNumber,
        N' ',@FailureMessage COLLATE SQL_Latin1_General_CP1_CS_AS,N'; cleanup=',@CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS),2048);
    RAISERROR(N'%s',16,1,@CombinedFailure);
END;
IF @FailureNumber IS NOT NULL RAISERROR(N'%s',16,1,@FailureMessage);
IF @FailureNumber IS NULL AND @CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS=N'' AND @AllFunctionalCases<>1
    THROW 57187,N'Databaseprincipal fixture functional cases are incomplete.',1;
IF @FailureNumber IS NULL AND @CleanupErrors COLLATE SQL_Latin1_General_CP1_CS_AS=N'' AND @AllFunctionalCases=1
BEGIN
    SET @NativeTableCases=@Case;
    RETURN 0;
END;
RETURN 1;
END;
GO
DECLARE @FixtureParentLock int=@@LOCK_TIMEOUT,
    @FixtureParentAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
    @FixtureParentTransaction int=@@TRANCOUNT,@FixtureParentDatabase int=DB_ID(),@FixtureReturn int,@FixtureCases int;
BEGIN TRY
    EXEC @FixtureReturn=[#ExampleDbPrincipalRuntimeContract] @NativeTableCases=@FixtureCases OUTPUT;
    IF COALESCE(@FixtureReturn,-1)<>0 OR COALESCE(@FixtureCases,0)<>4 OR @@LOCK_TIMEOUT<>@FixtureParentLock
       OR @@TRANCOUNT<>@FixtureParentTransaction OR DB_ID()<>@FixtureParentDatabase
       OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@FixtureParentAbort
        THROW 57189,N'Databaseprincipal scoped fixture did not restore its original caller.',1;
    DROP PROCEDURE [#ExampleDbPrincipalRuntimeContract];
    SELECT N'DATABASE_PRINCIPAL_CONTRACT_PASS' AS [Result],@FixtureCases AS [NativeTableCases],
           CAST(1 AS bit) AS [RestrictedCallerAndSourceFault],CAST(1 AS bit) AS [CallerAndOwnedCleanup];
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>@FixtureParentTransaction ROLLBACK TRANSACTION;
    IF OBJECT_ID(N'tempdb..#ExampleDbPrincipalRuntimeContract') IS NOT NULL
        DROP PROCEDURE [#ExampleDbPrincipalRuntimeContract];
    THROW;
END CATCH;
GO
