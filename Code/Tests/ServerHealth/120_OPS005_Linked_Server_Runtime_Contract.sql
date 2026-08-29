USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 120_OPS005_Linked_Server_Runtime_Contract.sql
Zweck        : Prüft lokales Inventar, sicheren Default und doppeltes Opt-in.
Datenschutz  : Ausschließlich feste synthetische Objekt- und Zielnamen.
Nebenwirkung : Ein synthetischer Linked Server wird im Fehler- und Erfolgsfall
               wieder entfernt. Ein Remotezugriff wird nicht ausgeführt.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ServerName sysname = N'ExampleOps005Linked';
DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;

IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [name] = @ServerName)
    THROW 54850, N'Der synthetische Linked-Server-Name ist bereits belegt.', 1;

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

    EXEC [master].[dbo].[sp_dropserver]
          @server = @ServerName
        , @droplogins = 'droplogins';
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
    THROW;
END CATCH;
GO
