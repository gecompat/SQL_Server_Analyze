USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 120_OPS005_Linked_Server_Runtime_Contract.sql
Zweck        : Prüft Inventar, sicheren Default, doppeltes Opt-in und einen
               tatsächlich nicht verfügbaren synthetischen Provider.
Datenschutz  : Ausschließlich feste synthetische Objekt- und Zielnamen.
 Nebenwirkung : Synthetische Linked Server, ein Login und zugehörige Benutzer
                werden im Fehler- und Erfolgsfall wieder entfernt. Der Test prüft
                einen absichtlich nicht erreichbaren, synthetischen Remote-Endpunkt.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ServerName sysname = N'ExampleOps005Linked';
DECLARE @TimeoutServerName sysname = N'ExampleOps005TimeoutLinked';
DECLARE @ProviderServerName sysname = N'ExampleOps005UnavailableProvider';
DECLARE @UnavailableProvider nvarchar(128) = N'ExampleUnavailableOleDbProvider_'
    + REPLACE(CONVERT(nvarchar(36), NEWID()), N'-', N'');
DECLARE @ExpectedProviderError int = NULL,@ProviderError int = NULL;
DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;
DECLARE @RestrictedLoginPassword nvarchar(128) = N'A!a' + CONVERT(nvarchar(36), NEWID());
DECLARE @RestrictedLoginSql nvarchar(max) =
    N'CREATE LOGIN [ExampleOps005RestrictedLogin] WITH PASS' + N'WORD = N''' +
    REPLACE(@RestrictedLoginPassword, N'''', N'''''') + N''';';

IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
    THROW 54850, N'Der synthetische Linked-Server-Name ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @TimeoutServerName)
    THROW 54854, N'Der synthetische Timeout-Linked-Server-Name ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ProviderServerName)
    THROW 54866, N'Der synthetische Provider-Linked-Server-Name ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
    THROW 54863, N'Der synthetische Linked-Server-Benutzername ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [master].[sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
    THROW 54864, N'Der synthetische Master-Benutzername ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name] = N'ExampleOps005RestrictedLogin')
    THROW 54865, N'Der synthetische Linked-Server-Loginname ist bereits belegt.', 1;

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

    EXEC (@RestrictedLoginSql);
    EXEC [master].[sys].[sp_executesql]
        N'CREATE USER [ExampleOps005RestrictedUser] FOR LOGIN [ExampleOps005RestrictedLogin];';
    EXEC [master].[sys].[sp_executesql]
        N'DENY EXECUTE ON [dbo].[sp_testlinkedserver] TO [ExampleOps005RestrictedUser];';
    CREATE USER [ExampleOps005RestrictedUser] FOR LOGIN [ExampleOps005RestrictedLogin];
    GRANT EXECUTE ON [monitor].[USP_LinkedServerAnalysis] TO [ExampleOps005RestrictedUser];

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;

    BEGIN TRY
        EXECUTE AS LOGIN = N'ExampleOps005RestrictedLogin';

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
        IF ORIGINAL_LOGIN() <> SUSER_SNAME() REVERT;
        DROP USER IF EXISTS [ExampleOps005RestrictedUser];
        EXEC [master].[sys].[sp_executesql]
            N'DROP USER IF EXISTS [ExampleOps005RestrictedUser];';
        IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name] = N'ExampleOps005RestrictedLogin')
            DROP LOGIN [ExampleOps005RestrictedLogin];
        THROW;
    END CATCH;

    DROP USER IF EXISTS [ExampleOps005RestrictedUser];
    EXEC [master].[sys].[sp_executesql]
        N'DROP USER IF EXISTS [ExampleOps005RestrictedUser];';
    IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name] = N'ExampleOps005RestrictedLogin')
        DROP LOGIN [ExampleOps005RestrictedLogin];

    EXEC [master].[dbo].[sp_dropserver]
          @server = @ServerName
        , @droplogins = 'droplogins';
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
        THROW 54859, N'Der synthetic Linked-Server ''ExampleOps005Linked'' konnte trotz erfolgreichem Lauf nicht bereinigt werden.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
        THROW 54861, N'Der synthetic Benutzer ''ExampleOps005RestrictedUser'' konnte trotz erfolgreichem Lauf nicht bereinigt werden.', 1;

    EXEC [master].[dbo].[sp_addlinkedserver]
          @server = @ProviderServerName
        , @srvproduct = N'ExampleSyntheticUnavailableProvider'
        , @provider = @UnavailableProvider
        , @datasrc = N'example-provider.invalid';

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @ProviderError=NULL;
    EXEC [monitor].[USP_LinkedServerAnalysis]
          @ConnectivityTestEnabled=0,@HighImpactConfirmed=0,@MaxZeilen=40,
          @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
          @ErrorNumberOut=@ProviderError OUTPUT;
    IF @Status IS NULL OR @Status<>'AVAILABLE' OR @Partial IS NULL OR @Partial<>0
       OR @ProviderError IS NOT NULL OR COALESCE(ISJSON(@Json),0)<>1
       OR NOT EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json) WITH
           ([ServerName] sysname '$.ServerName',[Provider] nvarchar(128) '$.Provider',
            [ConnectivityStatus] varchar(40) '$.ConnectivityStatus',[StatusCode] varchar(40) '$.StatusCode') AS [j]
           WHERE [j].[ServerName]=@ProviderServerName COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [j].[Provider]=@UnavailableProvider COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [j].[ConnectivityStatus]='NOT_EXECUTED' AND [j].[StatusCode]='AVAILABLE'
       )
        THROW 54868,N'Das lokale Inventar eines nicht verfügbaren Providers verändert den sicheren Default.',1;

    BEGIN TRY
        EXEC [master].[dbo].[sp_testlinkedserver] @servername=@ProviderServerName;
        THROW 54867,N'Der synthetische Provider ist unerwartet verfügbar.',1;
    END TRY
    BEGIN CATCH
        SET @ExpectedProviderError=ERROR_NUMBER();
        IF @ExpectedProviderError NOT IN(7302,7403) THROW;
    END CATCH;

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_LinkedServerAnalysis]
          @ConnectivityTestEnabled=1,@HighImpactConfirmed=1,@MaxZeilen=40,
          @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Status IS NULL OR @Status<>'AVAILABLE_LIMITED' OR @Partial IS NULL OR @Partial<>1
       OR COALESCE(ISJSON(@Json),0)<>1 OR NOT EXISTS
       (
           SELECT 1 FROM OPENJSON(@Json) WITH
           ([ServerName] sysname '$.ServerName',[Provider] nvarchar(128) '$.Provider',
            [Product] nvarchar(128) '$.Product',[ConnectivityStatus] varchar(40) '$.ConnectivityStatus',
            [StatusCode] varchar(40) '$.StatusCode',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') AS [j]
           WHERE [j].[ServerName]=@ProviderServerName COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [j].[Provider]=@UnavailableProvider COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [j].[Product]=N'ExampleSyntheticUnavailableProvider'
             AND [j].[ConnectivityStatus]='FAILED' AND [j].[StatusCode]='SOURCE_UNAVAILABLE'
             AND [j].[EvidenceLimit] LIKE CONCAT(N'Remote-Testfehler ',@ExpectedProviderError,N':%')
       )
        THROW 54868,N'Der native Providerfehler fehlt in der gebundenen SOURCE_UNAVAILABLE-Evidenz.',2;

    IF NOT EXISTS
    (
        SELECT 1 FROM [sys].[servers]
        WHERE [name]=@ProviderServerName
          AND [provider]=@UnavailableProvider COLLATE SQL_Latin1_General_CP1_CS_AS
          AND [product]=N'ExampleSyntheticUnavailableProvider'
          AND [data_source]=N'example-provider.invalid'
    )
        THROW 54869,N'Der Provider-Linked-Server hat vor dem Erfolgs-Cleanup seine eigene Identität verloren.',4;
    EXEC [master].[dbo].[sp_dropserver] @server=@ProviderServerName,@droplogins='droplogins';
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name]=@ProviderServerName)
        THROW 54869,N'Der eigene Provider-Linked-Server ist nach Erfolg nicht bereinigt.',1;
    PRINT N'OPS005_PROVIDER_UNAVAILABLE_PASS';
END TRY
BEGIN CATCH
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name]=@ProviderServerName)
    BEGIN
        IF NOT EXISTS
        (
            SELECT 1 FROM [sys].[servers]
            WHERE [name]=@ProviderServerName
              AND [provider]=@UnavailableProvider COLLATE SQL_Latin1_General_CP1_CS_AS
              AND [product]=N'ExampleSyntheticUnavailableProvider'
              AND [data_source]=N'example-provider.invalid'
        )
            THROW 54869,N'Der Provider-Linked-Server ist keinem eigenen Erstellungsintent zuzuordnen.',2;
        EXEC [master].[dbo].[sp_dropserver] @server=@ProviderServerName,@droplogins='droplogins';
        IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name]=@ProviderServerName)
            THROW 54869,N'Der eigene Provider-Linked-Server ist nach Fehlern nicht bereinigt.',3;
    END;
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
    EXEC [master].[sys].[sp_executesql]
        N'DROP USER IF EXISTS [ExampleOps005RestrictedUser];';
    IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name] = N'ExampleOps005RestrictedLogin')
        DROP LOGIN [ExampleOps005RestrictedLogin];
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
        THROW 54856, N'Der synthetic Linked-Server ''ExampleOps005Linked'' ist nach Fehlern nicht bereinigt.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @TimeoutServerName)
        THROW 54857, N'Der synthetic Timeout-Linked-Server ''ExampleOps005TimeoutLinked'' ist nach Fehlern nicht bereinigt.', 1;
    IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name] = N'ExampleOps005RestrictedUser')
        THROW 54858, N'Der synthetic Benutzer ''ExampleOps005RestrictedUser'' ist nach Fehlern nicht bereinigt.', 1;
    THROW;
END CATCH;
GO
