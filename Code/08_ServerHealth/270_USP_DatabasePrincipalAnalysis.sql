USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabasePrincipalAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Zeigt sichtbare Datenbankprincipals, direkte Rollen, explizite
               Rechte, Schemaownership und begrenzte sichtbare Loginbindungen.
Grenzen      : Keine effektiven Rechte oder externe Gruppenauflosung. Fehlende
               sichtbare SID-Treffer beweisen keine verwaisten Identitaeten.
Datenschutz  : SID-Vergleiche sind intern; keine SID-Ausgabe und kein Zugriff
               auf Passwort-Hashes, Credentials, Schluessel oder Nutzdaten.
Nebenwirkung : Rein lesend; keine Berechtigungs- oder Ownershipaenderung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabasePrincipalAnalysis]
      @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @MaxZeilen int = 1000
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
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@Sql nvarchar(max),@IdentityGuard nvarchar(max),@DatabaseCreatedAt datetime,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @FailureError int=NULL,@FailureStatus varchar(40)=NULL,
        @TableStatus varchar(40),@TableError int,@TableMessage nvarchar(2048),
        @Started datetime2(3),@Observed bigint,@DatabaseId int,@DatabaseName sysname,@QuotedDatabase nvarchar(258),
        @ServerSourceAvailable bit=0,@ContextAvailable bit,@PrincipalSourceAvailable bit,
        @OwnerSid varbinary(85),@OwnerCount bigint,@OwnerId int,@OwnerName sysname,@OwnerType char(1),
        @OwnerBindingStatus varchar(40),@StateDescription nvarchar(60),@ContainmentDescription nvarchar(60),
        @CrossDatabaseRequested bit;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DatabasePrincipalAnalysis';
        PRINT N'Ohne Filter: alle sichtbaren Online-Benutzerdatenbanken; Systemdatenbanken sind opt-in. DatabaseNames und DatabaseNamePattern sind getrennt.';
        PRINT N'Neun Mengen: moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus, warnings.';
        PRINT N'Keine effektiven Rechte oder sicheren Orphan-Negativschluesse. Fehler sind ueber Status, Diagnose-OUTPUT und RETURN zu pruefen.';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
    CREATE TABLE [#DatabasePrincipalAnalysis_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_databaseContext]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalId] int NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerBindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_principals]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_roleMemberships]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RolePrincipalId] int NOT NULL, [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_permissions]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [GranteePrincipalId] int NOT NULL, [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MajorId] int NOT NULL, [MinorId] int NOT NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_schemaOwners]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwningPrincipalId] int NOT NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_loginBindings]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ServerPrincipalId] int NULL, [ServerPrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_sourceStatus]
    (
        [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_warnings]
    (
        [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#DatabasePrincipalAnalysis_Map]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_Candidates]
    (
        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,
        [CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_SelectionWarnings]
    ([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_ServerCache]
    ([PrincipalId] int NOT NULL,[PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Sid] varbinary(85) NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_PrincipalCache]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL, [Sid] varbinary(85) NULL
    );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|databaseContext|principals|roleMemberships|permissions|schemaOwners|loginBindings|sourceStatus|warnings',
                @MappingTable=N'#DatabasePrincipalAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @FailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET @Started=SYSUTCDATETIME();
        EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,
            @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,
            @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,
            @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
            @CandidateTable=N'#DatabasePrincipalAnalysis_Candidates',@WarningTable=N'#DatabasePrincipalAnalysis_SelectionWarnings';
        IF COALESCE(@TableStatus,'')<>'AVAILABLE'
        BEGIN
            SELECT @FailureError=51011,@FailureStatus=COALESCE(@TableStatus,'STATUS_UNAVAILABLE');
            RAISERROR(N'%s',16,1,@TableMessage);
        END;
        INSERT [#DatabasePrincipalAnalysis_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'STATUS_UNAVAILABLE'),'UNPROVEN',NULL,NULL,0,NULL,[ErrorMessage]
            FROM [#DatabasePrincipalAnalysis_SelectionWarnings];
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',
                   LEFT(COALESCE([ErrorMessage],N'Der angeforderte Datenbankkontext ist nicht verfuegbar.'),1000)
            FROM [#DatabasePrincipalAnalysis_SelectionWarnings];
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        -- TARGET_IDENTITY_GUARD_BEGIN
        SET @IdentityGuard=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK)
            WHERE [database_id]=DB_ID() AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
            THROW 51012,N''Target database identity changed or is not available for this source.'',1; ';
        -- TARGET_IDENTITY_GUARD_END
        SET @Started=SYSUTCDATETIME();
        IF EXISTS(SELECT 1 FROM [#DatabasePrincipalAnalysis_Candidates])
        BEGIN
        BEGIN TRY
            SET @Sql=@SetLock+N'INSERT [#DatabasePrincipalAnalysis_ServerCache]
                SELECT [principal_id],[name],[type],[sid] FROM [sys].[server_principals] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Sql,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            SET @ServerSourceAvailable=1;
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,NULL,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#DatabasePrincipalAnalysis_ServerCache];
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
        END CATCH;
        END
        ELSE
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,NULL);

        DECLARE [DatabasePrincipalTargets] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#DatabasePrincipalAnalysis_Candidates] ORDER BY [DatabaseId];
        OPEN [DatabasePrincipalTargets];
        FETCH NEXT FROM [DatabasePrincipalTargets] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @QuotedDatabase=QUOTENAME(@DatabaseName),@ContextAvailable=0,@PrincipalSourceAvailable=0,
                   @OwnerSid=NULL,@DatabaseCreatedAt=NULL,@OwnerCount=0,@OwnerId=NULL,@OwnerName=NULL,@OwnerType=NULL,
                   @StateDescription=NULL,@ContainmentDescription=NULL,@OwnerBindingStatus='SOURCE_UNAVAILABLE';
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'SELECT @Sid=[owner_sid],@State=[state_desc],@Containment=[containment_desc],@Created=[create_date],
                       @Available=1
                FROM [master].[sys].[databases] WITH (NOLOCK)
                WHERE [database_id]=@Id
                  AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS;';
                EXEC [sys].[sp_executesql] @Sql,
                    N'@Id int,@Name sysname,@Sid varbinary(85) OUTPUT,@State nvarchar(60) OUTPUT,@Containment nvarchar(60) OUTPUT,@Created datetime OUTPUT,@Available bit OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Sid=@OwnerSid OUTPUT,@State=@StateDescription OUTPUT,
                    @Containment=@ContainmentDescription OUTPUT,@Created=@DatabaseCreatedAt OUTPUT,@Available=@ContextAvailable OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN @ContextAvailable=1 THEN 'AVAILABLE_LIMITED' ELSE 'DATABASE_UNAVAILABLE' END,
                     CASE WHEN @ContextAvailable=1 THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                     CASE WHEN @ContextAvailable=1 THEN CONVERT(bigint,1) ELSE NULL END,
                     CASE WHEN @ContextAvailable=1 THEN CONVERT(bigint,1) ELSE NULL END,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            IF @ContextAvailable=1 AND @ServerSourceAvailable=1
            BEGIN
                SELECT @OwnerCount=COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_ServerCache] WHERE [Sid]=@OwnerSid;
                IF @OwnerCount=1
                    SELECT @OwnerId=[PrincipalId],@OwnerName=[PrincipalName],@OwnerType=[PrincipalType]
                    FROM [#DatabasePrincipalAnalysis_ServerCache] WHERE [Sid]=@OwnerSid;
                SET @OwnerBindingStatus=CASE
                    WHEN @OwnerSid IS NULL OR DATALENGTH(@OwnerSid)=0 THEN 'OWNER_SID_UNAVAILABLE'
                    WHEN @OwnerCount>1 THEN 'AMBIGUOUS_VISIBLE_OWNER_MATCH'
                    WHEN @OwnerCount=1 AND @OwnerType IN ('S','U') THEN 'MATCHED_VISIBLE_OWNER'
                    WHEN @OwnerCount=1 THEN 'UNSUPPORTED_PRINCIPAL_TYPE'
                    ELSE 'NO_VISIBLE_OWNER_MATCH' END;
            END;
            INSERT [#DatabasePrincipalAnalysis_databaseContext] VALUES
                (@DatabaseId,@DatabaseName,@StateDescription,@ContainmentDescription,@OwnerId,@OwnerName,@OwnerType,@OwnerBindingStatus);

            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_PrincipalCache] SELECT @Id,@Name,[p].[principal_id],[p].[name],[p].[type],[p].[type_desc],[p].[authentication_type],[p].[authentication_type_desc],[p].[default_schema_name],[p].[create_date],[p].[modify_date],[p].[is_fixed_role],[p].[owning_principal_id],[p].[sid] FROM [sys].[database_principals] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_principals]([DatabaseId],[DatabaseName],[PrincipalId],[PrincipalName],[PrincipalType],[PrincipalTypeDescription],[AuthenticationType],[AuthenticationTypeDescription],[DefaultSchemaName],[CreatedAt],[ModifiedAt],[IsFixedRole],[OwningPrincipalId])
                    SELECT [DatabaseId],[DatabaseName],[PrincipalId],[PrincipalName],[PrincipalType],[PrincipalTypeDescription],[AuthenticationType],[AuthenticationTypeDescription],[DefaultSchemaName],[CreatedAt],[ModifiedAt],[IsFixedRole],[OwningPrincipalId] FROM [#DatabasePrincipalAnalysis_PrincipalCache] WHERE [DatabaseId]=@DatabaseId;
                SET @PrincipalSourceAvailable=1;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_PrincipalCache] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#DatabasePrincipalAnalysis_principals] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_roleMemberships] SELECT @Id,@Name,[m].[role_principal_id],[r].[PrincipalName],[m].[member_principal_id],[u].[PrincipalName] FROM [sys].[database_role_members] AS [m] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [r] ON [r].[DatabaseId]=@Id AND [r].[PrincipalId]=[m].[role_principal_id] LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [u] ON [u].[DatabaseId]=@Id AND [u].[PrincipalId]=[m].[member_principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_ROLE_MEMBERS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_roleMemberships] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_ROLE_MEMBERS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_permissions] SELECT @Id,@Name,[p].[grantee_principal_id],[u].[PrincipalName],[p].[grantor_principal_id],[g].[PrincipalName],[p].[class],[p].[class_desc],[p].[major_id],[p].[minor_id],[p].[permission_name],[p].[state],[p].[state_desc] FROM [sys].[database_permissions] AS [p] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [u] ON [u].[DatabaseId]=@Id AND [u].[PrincipalId]=[p].[grantee_principal_id] LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [g] ON [g].[DatabaseId]=@Id AND [g].[PrincipalId]=[p].[grantor_principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_permissions] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_schemaOwners] SELECT @Id,@Name,[s].[schema_id],[s].[name],[s].[principal_id],[p].[PrincipalName] FROM [sys].[schemas] AS [s] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [p] ON [p].[DatabaseId]=@Id AND [p].[PrincipalId]=[s].[principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_SCHEMAS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_schemaOwners] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_SCHEMAS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            INSERT [#DatabasePrincipalAnalysis_loginBindings]
                SELECT [p].[DatabaseId],[p].[DatabaseName],[p].[PrincipalId],[p].[PrincipalName],
                       CASE WHEN [p].[PrincipalName] IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN 'NOT_APPLICABLE'
                            WHEN [p].[AuthenticationType]=2 THEN 'DATABASE_AUTHENTICATED'
                            WHEN COALESCE([p].[AuthenticationType],0)<>1 OR [p].[PrincipalType]<>'S' THEN 'NOT_APPLICABLE'
                            WHEN @ServerSourceAvailable=0 THEN 'SOURCE_UNAVAILABLE'
                            WHEN [s].[PrincipalId] IS NOT NULL THEN 'MATCHED_VISIBLE_LOGIN'
                            ELSE 'NO_VISIBLE_LOGIN_MATCH' END,
                       CASE WHEN [p].[AuthenticationType]=1 AND [p].[PrincipalType]='S'
                                 AND [p].[PrincipalName] NOT IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN [s].[PrincipalId] ELSE NULL END,
                       CASE WHEN [p].[AuthenticationType]=1 AND [p].[PrincipalType]='S'
                                 AND [p].[PrincipalName] NOT IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN [s].[PrincipalName] ELSE NULL END
                FROM [#DatabasePrincipalAnalysis_PrincipalCache] AS [p]
                OUTER APPLY
                (SELECT TOP (1) [l].[PrincipalId],[l].[PrincipalName]
                 FROM [#DatabasePrincipalAnalysis_ServerCache] AS [l]
                 WHERE [l].[PrincipalType]='S' AND [l].[Sid]=[p].[Sid] ORDER BY [l].[PrincipalId]) AS [s]
                WHERE [p].[DatabaseId]=@DatabaseId;
            SET @Observed=@@ROWCOUNT;
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (@DatabaseId,@DatabaseName,'LOGIN_BINDINGS','DERIVED',@Started,SYSUTCDATETIME(),
                 CASE WHEN @PrincipalSourceAvailable=1 AND @ServerSourceAvailable=1 THEN 'AVAILABLE_LIMITED' ELSE 'STATUS_UNAVAILABLE' END,
                 CASE WHEN @PrincipalSourceAvailable=1 AND @ServerSourceAvailable=1 THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                 CASE WHEN @PrincipalSourceAvailable=1 THEN @Observed ELSE NULL END,
                 CASE WHEN @PrincipalSourceAvailable=1 THEN @Observed ELSE NULL END,0,NULL,NULL);

            FETCH NEXT FROM [DatabasePrincipalTargets] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [DatabasePrincipalTargets]; DEALLOCATE [DatabasePrincipalTargets];

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_principals])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_principals] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_PRINCIPALS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_roleMemberships])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_roleMemberships] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_ROLE_MEMBERS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_permissions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_permissions] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_PERMISSIONS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[SchemaId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_schemaOwners])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_schemaOwners] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_SCHEMAS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_loginBindings])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_loginBindings] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='LOGIN_BINDINGS' AND [s].[ObservedRows] IS NOT NULL;
        INSERT [#DatabasePrincipalAnalysis_warnings] VALUES
            (NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN',NULL,
             N'Alle Mengen beschreiben sichtbare lokale Katalogmetadaten. Implizite Rollenrechte, externe Gruppen und effektive Berechtigungen sind nicht ausgewertet.');
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OUTPUT_LIMIT',[SourceKey],
                   N'Das globale Fachlimit kappt die Ausgabe. Namens- und SID-Bindungen verwenden die zuvor materialisierte ungekappte Sicht; das Limit begrenzt nicht die Kataloglesearbeit.'
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'SOURCE_UNAVAILABLE',[SourceKey],
                   N'Die Quelle oder eine benoetigte Zuordnung ist nicht verfuegbar. Fehlende sichtbare Werte beweisen keine Abwesenheit.'
            FROM [#DatabasePrincipalAnalysis_sourceStatus]
            WHERE [VisibilityScope]='UNPROVEN' AND [StatusCode]<>'SKIPPED' AND [SourceKind]<>'SELECTION';
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OWNER_BINDING_LIMITED','DATABASE_CONTEXT',
                   CONCAT(N'Ownerbindung=',[OwnerBindingStatus],N'; keine Directoryaufloesung oder Ownereignungspruefung.')
            FROM [#DatabasePrincipalAnalysis_databaseContext] WHERE [OwnerBindingStatus]<>'MATCHED_VISIBLE_OWNER';
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT DISTINCT [DatabaseId],[DatabaseName],'NO_VISIBLE_LOGIN_MATCH','LOGIN_BINDINGS',
                   N'Mindestens ein sichtbarer instanzgebundener SQL-Benutzer besitzt keinen sichtbaren SQL-Login-Treffer. Eingeschraenkte Serversicht bleibt eine moegliche Ursache; kein Orphan-Nachweis.'
            FROM [#DatabasePrincipalAnalysis_loginBindings] WHERE [BindingStatus]='NO_VISIBLE_LOGIN_MATCH';
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
            ORDER BY [DatabaseId],[SourceKey];
        IF NOT EXISTS(SELECT 1 FROM [#DatabasePrincipalAnalysis_sourceStatus]
                      WHERE [DatabaseId] IS NOT NULL AND [SourceKind]='NATIVE' AND [StatusCode]='AVAILABLE_LIMITED')
            SELECT TOP (1) @Status=[StatusCode],@Message=COALESCE(@Message,[ErrorMessage])
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [StatusCode] NOT IN ('AVAILABLE_LIMITED','SKIPPED')
            ORDER BY [DatabaseName],[SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_principals])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_roleMemberships])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_permissions])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_schemaOwners])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_loginBindings]);
        INSERT [#DatabasePrincipalAnalysis_moduleStatus] VALUES
            (N'USP_DatabasePrincipalAnalysis',@CapturedAtUtc,@Status,1,@Rows,
             N'Getrennte Katalogmomentaufnahmen im Caller-Kontext; RowCount summiert die fuenf begrenzbaren Fachmengen. Sichtbare Bindungen sind keine vollstaendige effektive Berechtigungsanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'DatabasePrincipalAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databaseContext nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_databaseContext] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_principals nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_principals] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_roleMemberships nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_roleMemberships] ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_permissions nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_permissions] ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_schemaOwners nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_schemaOwners] ORDER BY [DatabaseId],[SchemaId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_loginBindings nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_loginBindings] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"databaseContext":',COALESCE(@Json_databaseContext,N'[]'),N',"principals":',COALESCE(@Json_principals,N'[]'),N',"roleMemberships":',COALESCE(@Json_roleMemberships,N'[]'),N',"permissions":',COALESCE(@Json_permissions,N'[]'),N',"schemaOwners":',COALESCE(@Json_schemaOwners,N'[]'),N',"loginBindings":',COALESCE(@Json_loginBindings,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#DatabasePrincipalAnalysis_moduleStatus];
            SELECT * FROM [#DatabasePrincipalAnalysis_databaseContext] ORDER BY [DatabaseId];
            SELECT * FROM [#DatabasePrincipalAnalysis_principals] ORDER BY [DatabaseId],[PrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_roleMemberships] ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_permissions] ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_schemaOwners] ORDER BY [DatabaseId],[SchemaId];
            SELECT * FROM [#DatabasePrincipalAnalysis_loginBindings] ORDER BY [DatabaseId],[PrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#DatabasePrincipalAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DatabasePrincipalOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#DatabasePrincipalAnalysis_Map] ORDER BY [ResultName];
            OPEN [DatabasePrincipalOutput];
            FETCH NEXT FROM [DatabasePrincipalOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DatabasePrincipalAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @FailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DatabasePrincipalOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DatabasePrincipalOutput]; DEALLOCATE [DatabasePrincipalOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#DatabasePrincipalAnalysis_Console]
            ([Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
             [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Datenbank',[DatabaseName],CONCAT([StateDescription],N'; Containment=',[ContainmentDescription],
                    N'; Ownerbindung=',[OwnerBindingStatus],N'; sichtbarer Owner=',[OwnerName])
                FROM [#DatabasePrincipalAnalysis_databaseContext];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Principal',[PrincipalName],CONCAT(N'DB=',[DatabaseName],N'; ',[PrincipalTypeDescription],
                    N'; Authentifizierung=',[AuthenticationTypeDescription],N'; feste Rolle=',[IsFixedRole])
                FROM [#DatabasePrincipalAnalysis_principals];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Direkte Rolle',COALESCE([MemberName],CONVERT(nvarchar(20),[MemberPrincipalId])),
                    CONCAT(N'DB=',[DatabaseName],N'; Rolle=',COALESCE([RoleName],CONVERT(nvarchar(20),[RolePrincipalId])))
                FROM [#DatabasePrincipalAnalysis_roleMemberships];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Explizites Recht',COALESCE([GranteeName],CONVERT(nvarchar(20),[GranteePrincipalId])),
                    CONCAT(N'DB=',[DatabaseName],N'; ',[PermissionStateDescription],N' ',[PermissionName],
                           N'; Klasse=',[ClassDescription],N'; MajorId=',[MajorId],N'; MinorId=',[MinorId])
                FROM [#DatabasePrincipalAnalysis_permissions];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Schemaowner',[SchemaName],CONCAT(N'DB=',[DatabaseName],N'; Owner=',
                    COALESCE([OwnerName],CONVERT(nvarchar(20),[OwningPrincipalId])))
                FROM [#DatabasePrincipalAnalysis_schemaOwners];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Loginbindung',[PrincipalName],CONCAT(N'DB=',[DatabaseName],N'; ',[BindingStatus],
                    N'; sichtbarer Login=',[ServerPrincipalName]) FROM [#DatabasePrincipalAnalysis_loginBindings];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Quelle',[SourceKey],CONCAT(N'DB=',[DatabaseName],N'; ',[SourceKind],N'; ',[StatusCode],
                    N'; sichtbar=',[ObservedRows],N'; Ausgabe=',[ReturnedRows]) FROM [#DatabasePrincipalAnalysis_sourceStatus];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Aussagegrenze',[WarningCode],[Detail] FROM [#DatabasePrincipalAnalysis_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DatabasePrincipalAnalysis_Console',
                @ResultLabel=N'Sichtbare Datenbankprincipals und direkte Berechtigungsevidenz',
                @EmptyMessage=N'Keine sichtbaren Datenbankprincipal-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_DatabasePrincipalAnalysis: mindestens eine Quelle ist nicht verfuegbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;

    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@FailureError,ERROR_NUMBER()),@Message=LEFT(ERROR_MESSAGE(),2048),@Json=NULL;
        SELECT @StatusCodeOut=COALESCE(@FailureStatus,'ERROR_HANDLED'),@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
