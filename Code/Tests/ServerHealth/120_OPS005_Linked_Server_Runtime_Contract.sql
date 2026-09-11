USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 120_OPS005_Linked_Server_Runtime_Contract.sql
Zweck        : Prüft lokales Inventar, sicheren Default und doppeltes Opt-in.
Datenschutz  : Ausschließlich feste synthetische Objekt- und Zielnamen.
 Nebenwirkung : Synthetische Linked Server und ein synthetischer Benutzer werden
                im Fehler- und Erfolgsfall wieder entfernt. Der Test prüft einen
                absichtlich nicht erreichbaren, synthetischen Remote-Endpunkt.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ServerName sysname = N'ExampleOps005Linked';
DECLARE @TimeoutServerName sysname = N'ExampleOps005TimeoutLinked';
DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;

IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
    THROW 54850, N'Der synthetische Linked-Server-Name ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @TimeoutServerName)
    THROW 54854, N'Der synthetische Timeout-Linked-Server-Name ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
    THROW 54863, N'Der synthetische Linked-Server-Benutzername ist bereits belegt.', 1;

BEGIN TRY
    EXEC [master].[dbo].[sp_addlinkedserver]
          @server = @ServerName
        , @srvproduct = N'ExampleSyntheticProduct'
        , @provider = N'MSOLEDBSQL'
        , @datasrc = N'ExampleInvalidEndpoint';

    EXEC [monitor].[USP_LinkedServerAnalysis]
          @ConnectivityTestEnabled = 0
        , @HighImpactConfirmed = 0
        , @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF COALESCE(ISJSON(@Json), 0) <> 1
       OR @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@Json)
                   WITH
                   (
                         [ServerName] sysname '$.ServerName'
                       , [ConnectivityStatus] varchar(40) '$.ConnectivityStatus'
                   ) AS [j]
              WHERE [j].[ServerName] = @ServerName
                AND [j].[ConnectivityStatus] = 'NOT_EXECUTED'
          )
        THROW 54851, N'Der lokale Linked-Server-Defaultvertrag ist verletzt.', 1;

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;

    EXEC [monitor].[USP_LinkedServerAnalysis]
          @ConnectivityTestEnabled = 1
        , @HighImpactConfirmed = 0
        , @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF @Status <> 'AUTHORIZATION_REQUIRED'
       OR @Partial <> 1
       OR NOT EXISTS
           (
               SELECT 1
              FROM OPENJSON(@Json)
                   WITH
                   (
                         [ServerName] sysname '$.ServerName'
                       , [ConnectivityStatus] varchar(40) '$.ConnectivityStatus'
                   ) AS [j]
              WHERE [j].[ServerName] = @ServerName
                AND [j].[ConnectivityStatus] = 'AUTHORIZATION_REQUIRED'
           )
        THROW 54852, N'Das doppelte Linked-Server-Opt-in ist verletzt.', 1;

    EXEC [master].[dbo].[sp_addlinkedserver]
          @server = @TimeoutServerName
        , @srvproduct = N'ExampleSyntheticTimeoutProduct'
        , @provider = N'MSOLEDBSQL'
        , @datasrc = N'example-timeout.invalid:65535';

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;

    EXEC [monitor].[USP_LinkedServerAnalysis]
          @ConnectivityTestEnabled = 1
        , @HighImpactConfirmed = 1
        , @MaxZeilen = 40
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF @Status <> 'AVAILABLE_LIMITED'
       OR @Partial <> 1
       OR COALESCE(ISJSON(@Json), 0) <> 1
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@Json)
                   WITH
                   (
                         [ServerName] sysname '$.ServerName'
                       , [ConnectivityStatus] varchar(40) '$.ConnectivityStatus'
                       , [StatusCode] varchar(40) '$.StatusCode'
                       , [Provider] nvarchar(128) '$.Provider'
                       , [Product] nvarchar(128) '$.Product'
                   ) AS [j]
              WHERE [j].[ServerName] = @TimeoutServerName
                AND [j].[ConnectivityStatus] = 'FAILED'
                AND [j].[Provider] = N'MSOLEDBSQL'
                AND [j].[Product] = N'ExampleSyntheticTimeoutProduct'
                AND [j].[StatusCode] IN ('SOURCE_TIMEOUT','SOURCE_UNAVAILABLE')
          )
        THROW 54855, N'Der Timeout-Linked-Server-Pfad ist verletzt.', 1;

    EXEC [master].[dbo].[sp_dropserver]
          @server = @TimeoutServerName
        , @droplogins = 'droplogins';

    DROP USER IF EXISTS [ExampleOps005RestrictedUser];
    CREATE USER [ExampleOps005RestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON [monitor].[USP_LinkedServerAnalysis] TO [ExampleOps005RestrictedUser];
    DENY EXECUTE ON [master].[dbo].[sp_testlinkedserver] TO [ExampleOps005RestrictedUser];

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;

    BEGIN TRY
        EXECUTE AS USER = N'ExampleOps005RestrictedUser';

        EXEC [monitor].[USP_LinkedServerAnalysis]
              @ConnectivityTestEnabled = 1
            , @HighImpactConfirmed = 1
            , @MaxZeilen = 20
            , @ResultSetArt = 'NONE'
            , @JsonErzeugen = 1
            , @Json = @Json OUTPUT
            , @PrintMeldungen = 0
            , @StatusCodeOut = @Status OUTPUT
            , @IsPartialOut = @Partial OUTPUT;

        REVERT;
        IF @Status <> 'AVAILABLE_LIMITED'
           OR @Partial <> 1
           OR COALESCE(ISJSON(@Json), 0) <> 1
           OR NOT EXISTS
              (
                  SELECT 1
                  FROM OPENJSON(@Json)
                       WITH
                       (
                             [ServerName] sysname '$.ServerName'
                           , [ConnectivityStatus] varchar(40) '$.ConnectivityStatus'
                           , [StatusCode] varchar(40) '$.StatusCode'
                       ) AS [j]
                  WHERE [j].[ServerName] = @ServerName
                    AND [j].[ConnectivityStatus] = 'FAILED'
                    AND [j].[StatusCode] = 'DENIED_PERMISSION'
              )
            THROW 54853, N'Der Linked-Server-Berechtigungsfall ist verletzt.', 1;
    END TRY
    BEGIN CATCH
        IF USER_NAME() = N'ExampleOps005RestrictedUser' REVERT;
        DROP USER IF EXISTS [ExampleOps005RestrictedUser];
        THROW;
    END CATCH;

    DROP USER IF EXISTS [ExampleOps005RestrictedUser];

    EXEC [master].[dbo].[sp_dropserver]
          @server = @ServerName
        , @droplogins = 'droplogins';
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
        THROW 54859, N'Der synthetic Linked-Server ''ExampleOps005Linked'' konnte trotz erfolgreichem Lauf nicht bereinigt werden.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
        THROW 54861, N'Der synthetic Benutzer ''ExampleOps005RestrictedUser'' konnte trotz erfolgreichem Lauf nicht bereinigt werden.', 1;
END TRY
BEGIN CATCH
    IF EXISTS
    (
        SELECT 1
        FROM [sys].[servers]
        WHERE [name] = @ServerName
          AND [product] = N'ExampleSyntheticProduct'
    )
        EXEC [master].[dbo].[sp_dropserver]
              @server = @ServerName
            , @droplogins = 'droplogins';
    IF EXISTS
    (
        SELECT 1
        FROM [sys].[servers]
        WHERE [name] = @TimeoutServerName
          AND [product] = N'ExampleSyntheticTimeoutProduct'
    )
        EXEC [master].[dbo].[sp_dropserver]
              @server = @TimeoutServerName
            , @droplogins = 'droplogins';
    DROP USER IF EXISTS [ExampleOps005RestrictedUser];
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
        THROW 54856, N'Der synthetic Linked-Server ''ExampleOps005Linked'' ist nach Fehlern nicht bereinigt.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @TimeoutServerName)
        THROW 54857, N'Der synthetic Timeout-Linked-Server ''ExampleOps005TimeoutLinked'' ist nach Fehlern nicht bereinigt.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
        THROW 54858, N'Der synthetic Benutzer ''ExampleOps005RestrictedUser'' ist nach Fehlern nicht bereinigt.', 1;
    THROW;
END CATCH;
GO
