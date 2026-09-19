USE [DeineDatenbank];
GO

/* Prueft die read-only Leerinventur fuer einen reservierten, nicht vorhandenen Auditnamen. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;

EXEC [monitor].[USP_AuditConfigurationAnalysis]
      @DatabaseNames = N'DeineDatenbank'
    , @AuditNames = N'ExampleWi0008AbsentAudit'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT;

IF @Status <> 'AVAILABLE'
   OR COALESCE(ISJSON(@Json), 0) <> 1
   OR JSON_VALUE(@Json, '$.meta.statusCode') <> 'AVAILABLE'
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.audits'))
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.serverSpecifications'))
   OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.databaseSpecifications'))
   OR
      (
          SELECT COUNT_BIG(*)
          FROM OPENJSON(@Json, '$.sourceStatus')
          WITH
          (
                [SourceName] nvarchar(160) '$.SourceName'
              , [StatusCode] varchar(40) '$.StatusCode'
              , [IsPartial] bit '$.IsPartial'
          ) AS [s]
          WHERE [s].[StatusCode] = 'AVAILABLE'
            AND [s].[IsPartial] = 0
      ) <> 3
    THROW 54910, N'Der WI-0008-Leerinventarvertrag fuer Auditkonfigurationen ist verletzt.', 1;

DECLARE @RestrictedJson nvarchar(max) = NULL;
DECLARE @RestrictedStatus varchar(40) = NULL;

BEGIN TRY
    CREATE USER [ExampleWi0008RestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON [monitor].[USP_AuditConfigurationAnalysis] TO [ExampleWi0008RestrictedUser];
    EXECUTE AS USER = N'ExampleWi0008RestrictedUser';
    EXEC [monitor].[USP_AuditConfigurationAnalysis]
          @DatabaseNames = N'DeineDatenbank'
        , @AuditNames = N'ExampleWi0008AbsentAudit'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @RestrictedJson OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @RestrictedStatus OUTPUT;
    REVERT;

    IF @RestrictedStatus <> 'AVAILABLE_LIMITED'
       OR COALESCE(ISJSON(@RestrictedJson), 0) <> 1
       OR JSON_VALUE(@RestrictedJson, '$.meta.statusCode') <> 'AVAILABLE_LIMITED'
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@RestrictedJson, '$.sourceStatus')
              WITH
              (
                    [StatusCode] varchar(40) '$.StatusCode'
                  , [IsPartial] bit '$.IsPartial'
              ) AS [s]
              WHERE [s].[StatusCode] = 'DENIED_PERMISSION'
                AND [s].[IsPartial] = 1
          )
        THROW 54911, N'Der WI-0008-Vertrag fuer verweigerte Auditmetadaten ist verletzt.', 1;

    DROP USER [ExampleWi0008RestrictedUser];
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleWi0008RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleWi0008RestrictedUser];
    THROW;
END CATCH;

DECLARE @DisabledAuditName sysname = N'ExampleWi0008DisabledAudit';
DECLARE @DisabledAuditJson nvarchar(max) = NULL;
DECLARE @DisabledAuditStatus varchar(40) = NULL;
DECLARE @DropAuditSql nvarchar(max) = N'DROP SERVER AUDIT ' + QUOTENAME(@DisabledAuditName) + N';';

IF EXISTS (SELECT 1 FROM [sys].[server_audits] WHERE [name] = @DisabledAuditName)
    THROW 54912, N'Der synthetische deaktivierte Auditname ist bereits belegt.', 1;

BEGIN TRY
    DECLARE @AuditPath nvarchar(4000) = CONVERT(nvarchar(4000), SERVERPROPERTY(N'InstanceDefaultDataPath'));
    IF NULLIF(@AuditPath, N'') IS NULL
        THROW 54913, N'Der Standarddatenpfad fuer das synthetische Audit ist nicht verfuegbar.', 1;

    DECLARE @CreateAuditSql nvarchar(max) = N'CREATE SERVER AUDIT ' + QUOTENAME(@DisabledAuditName)
        + N' TO FILE (FILEPATH = N''' + REPLACE(@AuditPath, N'''', N'''''') + N''') WITH (ON_FAILURE = CONTINUE);';
    EXEC [master].[sys].[sp_executesql] @CreateAuditSql;

    EXEC [monitor].[USP_AuditConfigurationAnalysis]
          @DatabaseNames = N'DeineDatenbank'
        , @AuditNames = @DisabledAuditName
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @DisabledAuditJson OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @DisabledAuditStatus OUTPUT;

    IF @DisabledAuditStatus <> 'AVAILABLE_WITH_FINDING'
       OR COALESCE(ISJSON(@DisabledAuditJson), 0) <> 1
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@DisabledAuditJson, '$.audits')
              WITH
              (
                    [AuditName] sysname '$.AuditName'
                  , [IsEnabled] bit '$.IsEnabled'
                  , [FindingCode] varchar(64) '$.FindingCode'
                  , [FindingSeverity] varchar(16) '$.FindingSeverity'
              ) AS [a]
              WHERE [a].[AuditName] = @DisabledAuditName
                AND [a].[IsEnabled] = 0
                AND [a].[FindingCode] = 'AUDIT_DISABLED'
                AND [a].[FindingSeverity] = 'MEDIUM'
          )
        THROW 54914, N'Der WI-0008-Vertrag fuer deaktivierte Auditkonfigurationen ist verletzt.', 1;

    EXEC [master].[sys].[sp_executesql] @DropAuditSql;
END TRY
BEGIN CATCH
    IF EXISTS (SELECT 1 FROM [sys].[server_audits] WHERE [name] = @DisabledAuditName)
        EXEC [master].[sys].[sp_executesql] @DropAuditSql;
    THROW;
END CATCH;

DECLARE @RunningAuditName sysname = N'ExampleWi0008RunningAudit';
DECLARE @RunningAuditJson nvarchar(max) = NULL;
DECLARE @RunningAuditStatus varchar(40) = NULL;
DECLARE @StartRunningAuditSql nvarchar(max) = N'ALTER SERVER AUDIT ' + QUOTENAME(@RunningAuditName) + N' WITH (STATE = ON);';
DECLARE @StopRunningAuditSql nvarchar(max) = N'ALTER SERVER AUDIT ' + QUOTENAME(@RunningAuditName) + N' WITH (STATE = OFF);';
DECLARE @DropRunningAuditSql nvarchar(max) = N'DROP SERVER AUDIT ' + QUOTENAME(@RunningAuditName) + N';';

IF EXISTS (SELECT 1 FROM [sys].[server_audits] WHERE [name] = @RunningAuditName)
    THROW 54915, N'Der synthetische aktive Auditname ist bereits belegt.', 1;

BEGIN TRY
    DECLARE @RunningAuditPath nvarchar(4000) = CONVERT(nvarchar(4000), SERVERPROPERTY(N'InstanceDefaultDataPath'));
    IF NULLIF(@RunningAuditPath, N'') IS NULL
        THROW 54916, N'Der Standarddatenpfad fuer das aktive synthetische Audit ist nicht verfuegbar.', 1;

    DECLARE @CreateRunningAuditSql nvarchar(max) = N'CREATE SERVER AUDIT ' + QUOTENAME(@RunningAuditName)
        + N' TO FILE (FILEPATH = N''' + REPLACE(@RunningAuditPath, N'''', N'''''') + N''') WITH (ON_FAILURE = CONTINUE);';
    EXEC [master].[sys].[sp_executesql] @CreateRunningAuditSql;
    EXEC [master].[sys].[sp_executesql] @StopRunningAuditSql;
    EXEC [master].[sys].[sp_executesql] @StartRunningAuditSql;

    WAITFOR DELAY '00:00:01';
    EXEC [monitor].[USP_AuditConfigurationAnalysis]
          @DatabaseNames = N'DeineDatenbank'
        , @AuditNames = @RunningAuditName
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @RunningAuditJson OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @RunningAuditStatus OUTPUT;

    IF @RunningAuditStatus <> 'AVAILABLE'
       OR COALESCE(ISJSON(@RunningAuditJson), 0) <> 1
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@RunningAuditJson, '$.audits')
              WITH
              (
                    [AuditName] sysname '$.AuditName'
                  , [IsEnabled] bit '$.IsEnabled'
                  , [RuntimeStatus] nvarchar(60) '$.RuntimeStatus'
                  , [FindingCode] varchar(64) '$.FindingCode'
                  , [FindingSeverity] varchar(16) '$.FindingSeverity'
              ) AS [a]
              WHERE [a].[AuditName] = @RunningAuditName
                AND [a].[IsEnabled] = 1
                AND [a].[RuntimeStatus] IN (N'STARTED', N'RUNNING')
                AND [a].[FindingCode] = 'AUDIT_CONFIGURED'
                AND [a].[FindingSeverity] = 'INFO'
          )
        THROW 54917, N'Der WI-0008-Vertrag fuer den aktiven Audit-Runtimezustand ist verletzt.', 1;

    EXEC [master].[sys].[sp_executesql] @StopRunningAuditSql;
    EXEC [master].[sys].[sp_executesql] @DropRunningAuditSql;
END TRY
BEGIN CATCH
    IF EXISTS (SELECT 1 FROM [sys].[server_audits] WHERE [name] = @RunningAuditName)
    BEGIN
        BEGIN TRY
            EXEC [master].[sys].[sp_executesql] @StopRunningAuditSql;
        END TRY
        BEGIN CATCH
        END CATCH;
        EXEC [master].[sys].[sp_executesql] @DropRunningAuditSql;
    END;
    THROW;
END CATCH;
GO
