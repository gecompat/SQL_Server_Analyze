USE [DeineDatenbank];
GO
SET NOCOUNT ON;
DECLARE @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @LoginA sysname,@LoginB sysname,@RoleA sysname,@RoleB sysname,@UserB sysname,
    @MadeA bit=0,@MadeB bit=0,@MadeRoleA bit=0,@MadeRoleB bit=0,@MadeUser bit=0,
    @IdA int,@IdB int,@RoleIdA int,@RoleIdB int,@SidA varbinary(85),@SidB varbinary(85),
    @RoleSidA varbinary(85),@RoleSidB varbinary(85),@UserIdB int,@UserSidB varbinary(85),
    @Sql nvarchar(max),@Json nvarchar(max),@Expected nvarchar(max),@Status varchar(40),@Partial bit,
    @OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
    @OriginalTx int=@@TRANCOUNT,@Restore nvarchar(100),@Case int=0,@Limit int;
IF @OriginalTx<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57060,N'Serverprincipal fixture requires an isolated sysadmin test target without ambient transaction.',1;
SELECT @LoginA=N'ExamplePrincipalA_'+@Suffix,@LoginB=N'ExamplePrincipalB_'+@Suffix,
       @RoleA=N'ExampleRoleA_'+@Suffix,@RoleB=N'ExampleRoleB_'+@Suffix,@UserB=N'ExampleUserB_'+@Suffix;
SET @Restore=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
BEGIN TRY
    IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] IN (@LoginA,@LoginB,@RoleA,@RoleB))
        THROW 57061,N'Serverprincipal fixture collision.',1;
    DECLARE @Password nvarchar(128)=N'Example!'+CONVERT(nvarchar(36),NEWID());
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@LoginA)+N' WITH PASSWORD='+QUOTENAME(@Password,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [sys].[sp_executesql] @Sql;SET @MadeA=1;
    SELECT @IdA=[principal_id],@SidA=[sid] FROM [sys].[server_principals] WHERE [name]=@LoginA;
    SET @Password=N'Example!'+CONVERT(nvarchar(36),NEWID());
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@LoginB)+N' WITH PASSWORD='+QUOTENAME(@Password,'''')+N',CHECK_POLICY=ON,CHECK_EXPIRATION=ON;';
    EXEC [sys].[sp_executesql] @Sql;SET @MadeB=1;
    SELECT @IdB=[principal_id],@SidB=[sid] FROM [sys].[server_principals] WHERE [name]=@LoginB;
    SET @Password=NULL;
    SET @Sql=N'ALTER LOGIN '+QUOTENAME(@LoginA)+N' DISABLE;';EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'CREATE SERVER ROLE '+QUOTENAME(@RoleA)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeRoleA=1;
    SELECT @RoleIdA=[principal_id],@RoleSidA=[sid] FROM [sys].[server_principals] WHERE [name]=@RoleA;
    SET @Sql=N'CREATE SERVER ROLE '+QUOTENAME(@RoleB)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeRoleB=1;
    SELECT @RoleIdB=[principal_id],@RoleSidB=[sid] FROM [sys].[server_principals] WHERE [name]=@RoleB;
    SET @Sql=N'ALTER SERVER ROLE '+QUOTENAME(@RoleA)+N' ADD MEMBER '+QUOTENAME(@LoginA)+N'; ALTER SERVER ROLE '+QUOTENAME(@RoleB)+N' ADD MEMBER '+QUOTENAME(@RoleA)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'GRANT VIEW SERVER STATE TO '+QUOTENAME(@RoleA)+N' WITH GRANT OPTION; DENY ALTER ANY LOGIN TO '+QUOTENAME(@LoginB)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'CREATE USER '+QUOTENAME(@UserB)+N' FOR LOGIN '+QUOTENAME(@LoginB)+N';';
    EXEC [sys].[sp_executesql] @Sql;SET @MadeUser=1;
    SELECT @UserIdB=[principal_id],@UserSidB=[sid] FROM [sys].[database_principals] WHERE [name]=@UserB;
    SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_ServerPrincipalAnalysis] TO '+QUOTENAME(@UserB)+N';';
    EXEC [sys].[sp_executesql] @Sql;

    CREATE TABLE [#ExamplePrincipal_Expected_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [RowCount] bigint NOT NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ExamplePrincipal_Expected_principals]
    (
        [PrincipalId] int NOT NULL,
        [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsDisabled] bit NULL,
        [CreatedAt] datetime NULL,
        [ModifiedAt] datetime NULL,
        [IsFixedRole] bit NULL,
        [OwningPrincipalId] int NULL
    );
    CREATE TABLE [#ExamplePrincipal_Expected_roleMemberships]
    (
        [RolePrincipalId] int NOT NULL,
        [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MemberPrincipalId] int NOT NULL,
        [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ExamplePrincipal_Expected_permissions]
    (
        [GranteePrincipalId] int NOT NULL,
        [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [GrantorPrincipalId] int NOT NULL,
        [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Class] tinyint NOT NULL,
        [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MajorId] int NOT NULL,
        [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ExamplePrincipal_Expected_loginPolicies]
    (
        [PrincipalId] int NOT NULL,
        [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsPolicyChecked] bit NULL,
        [IsExpirationChecked] bit NULL
    );
    CREATE TABLE [#ExamplePrincipal_Expected_sourceStatus]
    (
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
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
    CREATE TABLE [#ExamplePrincipal_Expected_warnings]
    (
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    WHILE @Case<4
    BEGIN
        SET @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;
        SET LOCK_TIMEOUT 37;
        IF @Case%2=0 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        CREATE TABLE [#ExamplePrincipal_moduleStatus]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_principals]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_roleMemberships]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_permissions]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_loginPolicies]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_sourceStatus]([Seed] int NULL);
        CREATE TABLE [#ExamplePrincipal_warnings]([Seed] int NULL);
        IF @Case=3 BEGIN TRANSACTION;
        EXEC [monitor].[USP_ServerPrincipalAnalysis] @MaxZeilen=@Limit,@ResultSetArt='TABLE',
            @ResultTablesJson=N'{"moduleStatus":"#ExamplePrincipal_moduleStatus","principals":"#ExamplePrincipal_principals","roleMemberships":"#ExamplePrincipal_roleMemberships","permissions":"#ExamplePrincipal_permissions","loginPolicies":"#ExamplePrincipal_loginPolicies","sourceStatus":"#ExamplePrincipal_sourceStatus","warnings":"#ExamplePrincipal_warnings"}',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1 OR ISJSON(@Json)<>1
           OR @@LOCK_TIMEOUT<>37 OR @@TRANCOUNT<>CASE WHEN @Case=3 THEN 1 ELSE 0 END
           OR CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END<>CASE WHEN @Case%2=0 THEN 1 ELSE 0 END
            THROW 57062,N'Serverprincipal status or caller state differs.',1;
        IF (SELECT COUNT(*) FROM [#ExamplePrincipal_sourceStatus])<>4
           OR EXISTS(SELECT 1 FROM [#ExamplePrincipal_sourceStatus] WHERE [VisibilityScope]<>'VISIBLE_ONLY'
                     OR [StatusCode]<>'AVAILABLE_LIMITED' OR [ObservedRows] IS NULL OR [StartedAtUtc]>[CompletedAtUtc])
            THROW 57063,N'Serverprincipal source status differs.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_moduleStatus')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_moduleStatus'))
            THROW 57082,N'Serverprincipal published native schema facets differ: moduleStatus.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.moduleStatus'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: moduleStatus.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_moduleStatus'))<>6
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_moduleStatus') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: moduleStatus.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_principals] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_principals')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_principals'))
            THROW 57082,N'Serverprincipal published native schema facets differ: principals.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.principals'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: principals.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_principals'))<>9
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_principals') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: principals.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExamplePrincipal_principals])>1 THROW 57066,N'Serverprincipal per-set limit differs.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_roleMemberships] ORDER BY [RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_roleMemberships')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_roleMemberships'))
            THROW 57082,N'Serverprincipal published native schema facets differ: roleMemberships.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.roleMemberships'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: roleMemberships.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_roleMemberships'))<>4
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_roleMemberships') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: roleMemberships.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExamplePrincipal_roleMemberships])>1 THROW 57066,N'Serverprincipal per-set limit differs.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_permissions] ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_permissions')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_permissions'))
            THROW 57082,N'Serverprincipal published native schema facets differ: permissions.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.permissions'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: permissions.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_permissions'))<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_permissions') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: permissions.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExamplePrincipal_permissions])>1 THROW 57066,N'Serverprincipal per-set limit differs.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_loginPolicies] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_loginPolicies')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_loginPolicies'))
            THROW 57082,N'Serverprincipal published native schema facets differ: loginPolicies.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.loginPolicies'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: loginPolicies.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_loginPolicies'))<>4
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_loginPolicies') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: loginPolicies.',1;
        IF @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExamplePrincipal_loginPolicies])>1 THROW 57066,N'Serverprincipal per-set limit differs.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_sourceStatus] ORDER BY [SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_sourceStatus')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_sourceStatus'))
            THROW 57082,N'Serverprincipal published native schema facets differ: sourceStatus.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.sourceStatus'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: sourceStatus.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_sourceStatus'))<>10
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_sourceStatus') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: sourceStatus.',1;
        SET @Expected=(SELECT * FROM [#ExamplePrincipal_warnings] ORDER BY [WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF EXISTS(
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_warnings')
            EXCEPT
            SELECT ROW_NUMBER() OVER(ORDER BY [column_id]),[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_Expected_warnings'))
            THROW 57082,N'Serverprincipal published native schema facets differ: warnings.',1;
        IF COALESCE(@Expected,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 57064,N'Serverprincipal same-call TABLE JSON parity differs: warnings.',1;
        IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_warnings'))<>3
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExamplePrincipal_warnings') AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 57065,N'Serverprincipal native schema or text collation differs: warnings.',1;
        IF @Case<>1
        BEGIN
            IF EXISTS(
                SELECT [p].[principal_id],[p].[name],[p].[type],[p].[type_desc],CONVERT(bit,[p].[is_disabled]),
                       [p].[create_date],[p].[modify_date],[p].[is_fixed_role],[p].[owning_principal_id]
                FROM [sys].[server_principals] AS [p] WHERE [p].[principal_id] IN (@IdA,@IdB,@RoleIdA,@RoleIdB)
                EXCEPT SELECT * FROM [#ExamplePrincipal_principals] WHERE [PrincipalId] IN (@IdA,@IdB,@RoleIdA,@RoleIdB))
                THROW 57067,N'Serverprincipal independent native principal oracle differs.',1;
            IF (SELECT COUNT(*) FROM [#ExamplePrincipal_principals] WHERE [PrincipalId] IN (@IdA,@IdB,@RoleIdA,@RoleIdB))<>4
                THROW 57068,N'Serverprincipal fixture principal count differs.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_roleMemberships] WHERE [RolePrincipalId]=@RoleIdA AND [MemberPrincipalId]=@IdA)
               OR NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_roleMemberships] WHERE [RolePrincipalId]=@RoleIdB AND [MemberPrincipalId]=@RoleIdA)
               OR EXISTS(SELECT 1 FROM [#ExamplePrincipal_roleMemberships] WHERE [RolePrincipalId]=@RoleIdB AND [MemberPrincipalId]=@IdA)
                THROW 57069,N'Serverprincipal direct-role oracle differs or transitive membership was invented.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_permissions] WHERE [GranteePrincipalId]=@RoleIdA AND [PermissionName]=N'VIEW SERVER STATE' AND [PermissionState]='W')
               OR NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_permissions] WHERE [GranteePrincipalId]=@IdB AND [PermissionName]=N'ALTER ANY LOGIN' AND [PermissionState]='D')
                THROW 57070,N'Serverprincipal independent explicit-right oracle differs.',1;
            IF NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_loginPolicies] WHERE [PrincipalId]=@IdA AND [IsPolicyChecked]=0 AND [IsExpirationChecked]=0)
               OR NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_loginPolicies] WHERE [PrincipalId]=@IdB AND [IsPolicyChecked]=1 AND [IsExpirationChecked]=1)
                THROW 57071,N'Serverprincipal native SQL-login-policy oracle differs.',1;
        END
        ELSE IF NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_sourceStatus] WHERE [IsLimited]=1 AND [ObservedRows]>[ReturnedRows])
            THROW 57072,N'Serverprincipal limit status was lost.',1;
        IF @Case=3
        BEGIN
            IF XACT_STATE()<>1 THROW 57073,N'Serverprincipal ambient transaction is not committable.',1;
            ROLLBACK TRANSACTION;
        END;
        DROP TABLE [#ExamplePrincipal_moduleStatus];
        DROP TABLE [#ExamplePrincipal_principals];
        DROP TABLE [#ExamplePrincipal_roleMemberships];
        DROP TABLE [#ExamplePrincipal_permissions];
        DROP TABLE [#ExamplePrincipal_loginPolicies];
        DROP TABLE [#ExamplePrincipal_sourceStatus];
        DROP TABLE [#ExamplePrincipal_warnings];
        SET @Case+=1;
    END;

    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@LoginB,'''')+N';
        BEGIN TRY
            IF SUSER_ID()<>@ExpectedId THROW 57081,N''Restricted fixture context differs.'',1;
            EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,
                @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@PrintMeldungen=0;
            REVERT;
        END TRY
        BEGIN CATCH
            REVERT;
            THROW;
        END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,N'@ExpectedId int,@Json nvarchar(max) OUTPUT,@Status varchar(40) OUTPUT,@Partial bit OUTPUT',
        @ExpectedId=@IdB,@Json=@Json OUTPUT,@Status=@Status OUTPUT,@Partial=@Partial OUTPUT;
    IF COALESCE(@Partial,0)<>1 OR ISJSON(@Json)<>1
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.principals') WITH([PrincipalId] int N'$.PrincipalId') WHERE [PrincipalId]=@IdA)
        THROW 57074,N'Serverprincipal restricted metadata visibility differs.',1;

    SET @Sql=N'DENY SELECT ON [sys].[sql_logins] TO '+QUOTENAME(@UserB)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    DECLARE @ProbeError int=NULL;
    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@LoginB,'''')+N';
        BEGIN TRY
            SET XACT_ABORT OFF;
            BEGIN TRY
                DECLARE @ProbeRows bigint=(SELECT COUNT_BIG(*) FROM [sys].[sql_logins]);
            END TRY
            BEGIN CATCH
                SET @ProbeError=ERROR_NUMBER();
            END CATCH;
            IF COALESCE(@ProbeError,0)<>229 THROW 57083,N''Owned SQL-login-source denial is not established.'',1;
            SET LOCK_TIMEOUT 53;
            SET XACT_ABORT ON;
            BEGIN TRANSACTION;
            EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,
                @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@PrintMeldungen=0;
            IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS & 16384)<>16384
                THROW 57084,N''Denied-source caller transaction or options differ.'',1;
            ROLLBACK TRANSACTION;
            REVERT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
            REVERT;
            THROW;
        END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,N'@ProbeError int OUTPUT,@Json nvarchar(max) OUTPUT,@Status varchar(40) OUTPUT,@Partial bit OUTPUT',
        @ProbeError=@ProbeError OUTPUT,@Json=@Json OUTPUT,@Status=@Status OUTPUT,@Partial=@Partial OUTPUT;
    IF COALESCE(@Status,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[ErrorNumber] int N'$.ErrorNumber')
            WHERE [SourceKey]='SQL_LOGIN_POLICIES' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber]=@ProbeError)
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceKey] varchar(64) N'$.SourceKey',[ErrorNumber] int N'$.ErrorNumber')
            WHERE [SourceKey]<>'SQL_LOGIN_POLICIES' AND [ErrorNumber] IS NULL)<>3
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.principals') WITH([PrincipalId] int N'$.PrincipalId') WHERE [PrincipalId]=@IdB)
        THROW 57085,N'Controlled source-error isolation or native diagnostic binding differs.',1;

    EXEC [monitor].[USP_ServerPrincipalAnalysis] @MaxZeilen=1,@ResultSetArt='RAW',@PrintMeldungen=0;
    EXEC [monitor].[USP_ServerPrincipalAnalysis] @Hilfe=1,@PrintMeldungen=0;

    CREATE TABLE [#ExamplePrincipal_Sentinel]([Id] int NOT NULL PRIMARY KEY,[Value] int NOT NULL);
    INSERT [#ExamplePrincipal_Sentinel] VALUES(1,10);
    SET LOCK_TIMEOUT 43;SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    UPDATE [#ExamplePrincipal_Sentinel] SET [Value]=11 WHERE [Id]=1;
    BEGIN TRY
        EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"unknown":"#ExampleMissing"}';
        THROW 57075,N'Serverprincipal invalid TABLE mapping was accepted.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()=57075 THROW;
        IF ERROR_NUMBER()<>50000 OR @@LOCK_TIMEOUT<>43 OR (@@OPTIONS & 16384)<>16384
           OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (SELECT [Value] FROM [#ExamplePrincipal_Sentinel] WHERE [Id]=1)<>11
            THROW 57076,N'Serverprincipal rejected-mapping caller transaction or sentinel differs.',1;
    END CATCH;
    BEGIN TRY
        EXEC [monitor].[USP_ServerPrincipalAnalysis] @MaxZeilen=-1,@ResultSetArt='NONE',
            @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@ProbeError OUTPUT;
        THROW 57077,N'Serverprincipal negative limit was accepted.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>50000 OR @ProbeError<>51011 OR @Status<>'INVALID_PARAMETER'
           OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>43 OR (@@OPTIONS & 16384)<>16384
           OR (SELECT [Value] FROM [#ExamplePrincipal_Sentinel] WHERE [Id]=1)<>11 THROW;
    END CATCH;
    ROLLBACK TRANSACTION;
    IF (SELECT [Value] FROM [#ExamplePrincipal_Sentinel] WHERE [Id]=1)<>10
        THROW 57086,N'Caller retained rollback ownership differs.',1;
    DROP TABLE [#ExamplePrincipal_Sentinel];
    CREATE TABLE [#ExamplePrincipal_Console]
    ([Ergebnis] nvarchar(200),[Bereich] nvarchar(64),[Objekt] nvarchar(256),[Detail] nvarchar(1000));
    INSERT [#ExamplePrincipal_Console]
        EXEC [monitor].[USP_ServerPrincipalAnalysis] @MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
    IF NOT EXISTS(SELECT 1 FROM [#ExamplePrincipal_Console] WHERE [Bereich]=N'Aussagegrenze' AND [Objekt]=N'METADATA_COMPLETENESS_UNPROVEN')
        THROW 57078,N'Serverprincipal single CONSOLE evidence boundary differs.',1;
    DROP TABLE [#ExamplePrincipal_Console];

    IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@UserB AND [principal_id]=@UserIdB AND [sid]=@UserSidB)
        THROW 57079,N'Serverprincipal user ownership changed before cleanup.',1;
    SET @Sql=N'DROP USER '+QUOTENAME(@UserB)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeUser=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleB AND [principal_id]=@RoleIdB AND [sid]=@RoleSidB)
        THROW 57079,N'Serverprincipal role ownership changed before cleanup.',1;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleA AND [principal_id]=@RoleIdA AND [sid]=@RoleSidA)
        THROW 57079,N'Serverprincipal member-role ownership changed before cleanup.',1;
    SET @Sql=N'ALTER SERVER ROLE '+QUOTENAME(@RoleB)+N' DROP MEMBER '+QUOTENAME(@RoleA)+N'; DROP SERVER ROLE '+QUOTENAME(@RoleB)+N';';
    EXEC [sys].[sp_executesql] @Sql;SET @MadeRoleB=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleA AND [principal_id]=@RoleIdA AND [sid]=@RoleSidA)
        THROW 57079,N'Serverprincipal role ownership changed before cleanup.',1;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@LoginA AND [principal_id]=@IdA AND [sid]=@SidA)
        THROW 57079,N'Serverprincipal member-login ownership changed before cleanup.',1;
    SET @Sql=N'ALTER SERVER ROLE '+QUOTENAME(@RoleA)+N' DROP MEMBER '+QUOTENAME(@LoginA)+N'; DROP SERVER ROLE '+QUOTENAME(@RoleA)+N';';
    EXEC [sys].[sp_executesql] @Sql;SET @MadeRoleA=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [principal_id]=@IdB AND [sid]=@SidB AND [name]=@LoginB)
        THROW 57079,N'Serverprincipal fixture ownership changed before cleanup.',1;
    SET @Sql=N'DROP LOGIN '+QUOTENAME(@LoginB)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeB=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [principal_id]=@IdA AND [sid]=@SidA AND [name]=@LoginA)
        THROW 57079,N'Serverprincipal fixture ownership changed before cleanup.',1;
    SET @Sql=N'DROP LOGIN '+QUOTENAME(@LoginA)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeA=0;
    IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] IN (@LoginA,@LoginB,@RoleA,@RoleB))
       OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@UserB)
        THROW 57080,N'Serverprincipal fixture cleanup is incomplete.',1;
    EXEC [sys].[sp_executesql] @Restore;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    SELECT N'SERVER_PRINCIPAL_CONTRACT_PASS' AS [Result],@Case AS [NativeTableCases],
           CAST(1 AS bit) AS [RestrictedCaller],CAST(1 AS bit) AS [CallerAndOwnedCleanup];
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>@OriginalTx ROLLBACK TRANSACTION;
    SET XACT_ABORT OFF;
    IF @MadeUser=1 AND EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@UserB AND [principal_id]=@UserIdB AND [sid]=@UserSidB)
    BEGIN SET @Sql=N'DROP USER '+QUOTENAME(@UserB)+N';';EXEC [sys].[sp_executesql] @Sql;END;
    IF @MadeRoleB=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleB AND [principal_id]=@RoleIdB AND [sid]=@RoleSidB)
    BEGIN
        IF EXISTS(SELECT 1 FROM [sys].[server_role_members] WHERE [role_principal_id]=@RoleIdB AND [member_principal_id]=@RoleIdA)
           AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleA AND [principal_id]=@RoleIdA AND [sid]=@RoleSidA)
        BEGIN SET @Sql=N'ALTER SERVER ROLE '+QUOTENAME(@RoleB)+N' DROP MEMBER '+QUOTENAME(@RoleA)+N';';EXEC [sys].[sp_executesql] @Sql;END;
        SET @Sql=N'DROP SERVER ROLE '+QUOTENAME(@RoleB)+N';';EXEC [sys].[sp_executesql] @Sql;
    END;
    IF @MadeRoleA=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RoleA AND [principal_id]=@RoleIdA AND [sid]=@RoleSidA)
    BEGIN
        IF EXISTS(SELECT 1 FROM [sys].[server_role_members] WHERE [role_principal_id]=@RoleIdA AND [member_principal_id]=@IdA)
           AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@LoginA AND [principal_id]=@IdA AND [sid]=@SidA)
        BEGIN SET @Sql=N'ALTER SERVER ROLE '+QUOTENAME(@RoleA)+N' DROP MEMBER '+QUOTENAME(@LoginA)+N';';EXEC [sys].[sp_executesql] @Sql;END;
        SET @Sql=N'DROP SERVER ROLE '+QUOTENAME(@RoleA)+N';';EXEC [sys].[sp_executesql] @Sql;
    END;
    IF @MadeB=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@LoginB AND [sid]=@SidB AND [principal_id]=@IdB)
    BEGIN SET @Sql=N'DROP LOGIN '+QUOTENAME(@LoginB)+N';';EXEC [sys].[sp_executesql] @Sql;END;
    IF @MadeA=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@LoginA AND [sid]=@SidA AND [principal_id]=@IdA)
    BEGIN SET @Sql=N'DROP LOGIN '+QUOTENAME(@LoginA)+N';';EXEC [sys].[sp_executesql] @Sql;END;
    EXEC [sys].[sp_executesql] @Restore;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
GO
