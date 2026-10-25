USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerPrincipalAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften,
               explizite Berechtigungen und konfigurierte SQL-Login-Policies.
Quellen      : sys.server_principals, sys.server_role_members,
               sys.server_permissions und sys.sql_logins.
Grenzen      : Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite
               Rollenrechte und externe Gruppen werden nicht aufgelöst.
Datenschutz  : Liest keine Passwort-Hashes, Credentials oder Schlüssel.
Nebenwirkung : Verändert weder Principals noch Berechtigungen oder Nutzdaten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ServerPrincipalAnalysis]
      @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),
        @Started datetime2(3),@Observed bigint,@Returned bigint,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ServerPrincipalAnalysis';
        PRINT N'Liest sichtbare Principals, direkte Rollen, explizite Serverrechte und SQL-Login-Policyflags. Keine effektive Rechteberechnung.';
        PRINT N'RAW/TABLE/JSON: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings.';
        PRINT N'@MaxZeilen begrenzt jedes der vier Fachresultsets; 0 oder NULL bedeutet unbegrenzt. @LockTimeoutMs erlaubt 0 bis 60000.';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,@ErrorMessageOut=N'Ungültiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        RAISERROR(N'%s',16,1,@ErrorMessageOut);
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
    CREATE TABLE [#ServerPrincipalAnalysis_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [RowCount] bigint NOT NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_principals]
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
    CREATE TABLE [#ServerPrincipalAnalysis_roleMemberships]
    (
        [RolePrincipalId] int NOT NULL,
        [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MemberPrincipalId] int NOT NULL,
        [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_permissions]
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
    CREATE TABLE [#ServerPrincipalAnalysis_loginPolicies]
    (
        [PrincipalId] int NOT NULL,
        [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsPolicyChecked] bit NULL,
        [IsExpirationChecked] bit NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_sourceStatus]
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
    CREATE TABLE [#ServerPrincipalAnalysis_warnings]
    (
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_Map]
    (
        [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
        IF @Mode='TABLE'
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|principals|roleMemberships|permissions|loginPolicies|sourceStatus|warnings',
                @MappingTable=N'#ServerPrincipalAnalysis_Map',@ThrowOnError=1;
        SET LOCK_TIMEOUT 0;
        IF @LockTimeoutMs>0
        BEGIN
            SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
            EXEC [sys].[sp_executesql] @SetLock;
        END;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#ServerPrincipalAnalysis_principals]
            SELECT [p].[principal_id],[p].[name],[p].[type],[p].[type_desc],CONVERT(bit,[p].[is_disabled]),[p].[create_date],[p].[modify_date],[p].[is_fixed_role],[p].[owning_principal_id]
            FROM [sys].[server_principals] AS [p] WITH (NOLOCK);
            SET @Observed=@@ROWCOUNT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PRINCIPALS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_principals];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PRINCIPALS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#ServerPrincipalAnalysis_roleMemberships]
            SELECT [m].[role_principal_id],[r].[PrincipalName],[m].[member_principal_id],[p].[PrincipalName]
            FROM [sys].[server_role_members] AS [m] WITH (NOLOCK)
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [r] ON [r].[PrincipalId]=[m].[role_principal_id]
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [p] ON [p].[PrincipalId]=[m].[member_principal_id];
            SET @Observed=@@ROWCOUNT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_ROLE_MEMBERS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_roleMemberships];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_ROLE_MEMBERS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#ServerPrincipalAnalysis_permissions]
            SELECT [e].[grantee_principal_id],[p].[PrincipalName],[e].[grantor_principal_id],[g].[PrincipalName],[e].[class],[e].[class_desc],[e].[major_id],[e].[permission_name],[e].[state],[e].[state_desc]
            FROM [sys].[server_permissions] AS [e] WITH (NOLOCK)
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [p] ON [p].[PrincipalId]=[e].[grantee_principal_id]
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [g] ON [g].[PrincipalId]=[e].[grantor_principal_id];
            SET @Observed=@@ROWCOUNT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PERMISSIONS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_permissions];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PERMISSIONS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#ServerPrincipalAnalysis_loginPolicies]
            SELECT [p].[principal_id],[p].[name],[p].[is_policy_checked],[p].[is_expiration_checked]
            FROM [sys].[sql_logins] AS [p] WITH (NOLOCK);
            SET @Observed=@@ROWCOUNT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SQL_LOGIN_POLICIES',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_loginPolicies];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SQL_LOGIN_POLICIES',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [PrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_principals])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_principals];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_PRINCIPALS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [RolePrincipalId],[MemberPrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_roleMemberships])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_roleMemberships];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_ROLE_MEMBERS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_permissions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_permissions];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_PERMISSIONS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [PrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_loginPolicies])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_loginPolicies];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SQL_LOGIN_POLICIES';
        INSERT [#ServerPrincipalAnalysis_warnings] VALUES
            ('METADATA_COMPLETENESS_UNPROVEN',NULL,N'Alle Mengen beschreiben ausschließlich sichtbare lokale Metadaten. Implizite Rollenrechte, externe Gruppen und effektive Berechtigungen sind nicht ausgewertet.');
        INSERT [#ServerPrincipalAnalysis_warnings]
            SELECT 'OUTPUT_LIMIT', [SourceKey],N'Das Fachresultset ist gekappt. Die Namensauflösung verwendet die davor materialisierte Principalsicht; ein Ausgabelimit begrenzt nicht die Kataloglesearbeit.'
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#ServerPrincipalAnalysis_warnings]
            SELECT 'SOURCE_UNAVAILABLE',[SourceKey],N'Die Quelle konnte nicht gelesen werden; andere sichtbare Mengen bleiben eigenständig auswertbar.'
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
            ORDER BY [SourceKey];
        IF NOT EXISTS(SELECT 1 FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NULL)
            SELECT TOP (1) @Status=[StatusCode] FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_principals])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_roleMemberships])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_permissions])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_loginPolicies]);
        INSERT [#ServerPrincipalAnalysis_moduleStatus] VALUES
            (N'USP_ServerPrincipalAnalysis',@CapturedAtUtc,@Status,1,@Rows,
             N'Getrennte Katalogmomentaufnahmen im Caller-Kontext; sichtbare direkte Zuordnungen und Policyflags, keine vollständige effektive Berechtigungsanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'ServerPrincipalAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_principals nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_principals] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_roleMemberships nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_roleMemberships] ORDER BY [RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_permissions nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_permissions] ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_loginPolicies nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_loginPolicies] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_warnings] ORDER BY [WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"principals":',COALESCE(@Json_principals,N'[]'),N',"roleMemberships":',COALESCE(@Json_roleMemberships,N'[]'),N',"permissions":',COALESCE(@Json_permissions,N'[]'),N',"loginPolicies":',COALESCE(@Json_loginPolicies,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#ServerPrincipalAnalysis_moduleStatus];
            SELECT * FROM [#ServerPrincipalAnalysis_principals] ORDER BY [PrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_roleMemberships] ORDER BY [RolePrincipalId],[MemberPrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_permissions] ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_loginPolicies] ORDER BY [PrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey];
            SELECT * FROM [#ServerPrincipalAnalysis_warnings] ORDER BY [WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [ServerPrincipalOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#ServerPrincipalAnalysis_Map] ORDER BY [ResultName];
            OPEN [ServerPrincipalOutput];
            FETCH NEXT FROM [ServerPrincipalOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#ServerPrincipalAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
                FETCH NEXT FROM [ServerPrincipalOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [ServerPrincipalOutput]; DEALLOCATE [ServerPrincipalOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#ServerPrincipalAnalysis_Console]
            (
                [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            );
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Principal',[PrincipalName],CONCAT([PrincipalTypeDescription],N'; deaktiviert=',[IsDisabled],N'; feste Rolle=',[IsFixedRole])
                FROM [#ServerPrincipalAnalysis_principals];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Direkte Rolle',COALESCE([MemberName],CONVERT(nvarchar(20),[MemberPrincipalId])),
                       CONCAT(N'Rolle=',COALESCE([RoleName],CONVERT(nvarchar(20),[RolePrincipalId])))
                FROM [#ServerPrincipalAnalysis_roleMemberships];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Explizites Recht',COALESCE([GranteeName],CONVERT(nvarchar(20),[GranteePrincipalId])),
                       CONCAT([PermissionStateDescription],N' ',[PermissionName],N'; Klasse=',[ClassDescription],N'; MajorId=',[MajorId])
                FROM [#ServerPrincipalAnalysis_permissions];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Login-Policy',[PrincipalName],CONCAT(N'Policy=',[IsPolicyChecked],N'; Ablauf=',[IsExpirationChecked])
                FROM [#ServerPrincipalAnalysis_loginPolicies];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Quelle',[SourceKey],CONCAT([StatusCode],N'; sichtbar=',[ObservedRows],N'; Ausgabe=',[ReturnedRows])
                FROM [#ServerPrincipalAnalysis_sourceStatus];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Aussagegrenze',[WarningCode],[Detail] FROM [#ServerPrincipalAnalysis_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#ServerPrincipalAnalysis_Console',
                @ResultLabel=N'Sichtbare Serverprincipals und direkte Berechtigungsevidenz',
                @EmptyMessage=N'Keine sichtbaren Serverprincipal-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_ServerPrincipalAnalysis: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=ERROR_NUMBER(),@Message=ERROR_MESSAGE(),@Json=NULL;
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        RAISERROR(N'%s',16,1,@Message);
        RETURN @Error;
    END CATCH;
END;
GO
