USE [DeineDatenbank];
GO

/* Prüft ausschließlich die vom Zwei-Container-Runner eingerichtete Verbindung. */
SET NOCOUNT ON;
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
IF NOT EXISTS
(
    SELECT 1 FROM [sys].[servers]
    WHERE [name] = N'ExampleOps005Success'
      AND [provider] = N'MSOLEDBSQL'
)
    THROW 54870, N'Der kontrollierte Linked-Server-Fixture fehlt.', 1;
IF EXISTS (SELECT 1 FROM [sys].[servers] WHERE [is_linked] = 1 AND [name] <> N'ExampleOps005Success')
    THROW 54871, N'Der Erfolgsnachweis verlangt eine isolierte Instanz ohne weitere Linked Server.', 1;

EXEC [monitor].[USP_LinkedServerAnalysis]
      @ConnectivityTestEnabled = 0, @HighImpactConfirmed = 0,
      @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
      @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 1) <> 0
   OR NOT EXISTS
      (SELECT 1 FROM OPENJSON(@Json) WITH ([ConnectivityStatus] varchar(40) '$.ConnectivityStatus') AS [j]
       WHERE [j].[ConnectivityStatus] = 'NOT_EXECUTED')
    THROW 54872, N'Der sichere Default des erreichbaren Ziels ist verletzt.', 1;

EXEC [monitor].[USP_LinkedServerAnalysis]
      @ConnectivityTestEnabled = 1, @HighImpactConfirmed = 0,
      @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
      @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF COALESCE(@Status, '') <> 'AUTHORIZATION_REQUIRED' OR COALESCE(@Partial, 0) <> 1
    THROW 54873, N'Der Verbindungstest wurde ohne doppelte Bestätigung freigegeben.', 1;

EXEC [monitor].[USP_LinkedServerAnalysis]
      @ConnectivityTestEnabled = 1, @HighImpactConfirmed = 1,
      @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
      @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF COALESCE(@Status, '') <> 'AVAILABLE' OR COALESCE(@Partial, 1) <> 0
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 1
   OR NOT EXISTS
      (
          SELECT 1 FROM OPENJSON(@Json)
          WITH ([ServerName] sysname '$.ServerName', [Provider] nvarchar(128) '$.Provider',
                [ConnectivityStatus] varchar(40) '$.ConnectivityStatus', [StatusCode] varchar(40) '$.StatusCode') AS [j]
          WHERE [j].[ServerName] = N'ExampleOps005Success'
            AND [j].[Provider] = N'MSOLEDBSQL'
            AND [j].[ConnectivityStatus] = 'SUCCEEDED'
            AND [j].[StatusCode] = 'AVAILABLE'
      )
    THROW 54874, N'Der kontrollierte Linked-Server-Verbindungsaufbau war nicht erfolgreich.', 1;
GO
