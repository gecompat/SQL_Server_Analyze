USE [DeineDatenbank];
GO

/* Prüft positives Inventar, Begrenzung und partielle Sichtbarkeit mit drei synthetischen Tabellen. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ObjectName sysname = N'ExampleOps009Object';
DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;

IF OBJECT_ID(N'master.dbo.ExampleOps009Object', N'U') IS NOT NULL
   OR OBJECT_ID(N'model.dbo.ExampleOps009Object', N'U') IS NOT NULL
   OR OBJECT_ID(N'msdb.dbo.ExampleOps009Object', N'U') IS NOT NULL
    THROW 54890, N'Der synthetische Systemdatenbank-Objektname ist bereits belegt.', 1;

BEGIN TRY
    EXEC [master].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';
    EXEC [model].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';
    EXEC [msdb].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';

    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 100
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;

    IF @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
       OR
       (
           SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([DatabaseName] sysname '$.DatabaseName', [ObjectName] sysname '$.ObjectName') AS [j]
           WHERE [j].[DatabaseName] IN (N'master', N'model', N'msdb')
             AND [j].[ObjectName] = @ObjectName
       ) <> 3
        THROW 54891, N'Das positive Systemdatenbank-Inventar ist verletzt.', 1;

    SET @Json = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 1
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0;
    IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) > 1
        THROW 54892, N'Die Begrenzung des Systemdatenbank-Inventars ist verletzt.', 1;

    DROP USER IF EXISTS [ExampleOps009RestrictedUser];
    CREATE USER [ExampleOps009RestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON [monitor].[USP_SystemDatabaseObjectInventory] TO [ExampleOps009RestrictedUser];
    EXECUTE AS USER = N'ExampleOps009RestrictedUser';
    SET @Json = NULL;
    SET @Status = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;
    REVERT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
       OR @Status NOT IN ('AVAILABLE_EMPTY', 'AVAILABLE_LIMITED')
       OR
          (
              @Status = 'AVAILABLE_LIMITED'
              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM OPENJSON(@Json)
                      WITH ([StatusCode] varchar(40) '$.StatusCode') AS [j]
                      WHERE [j].[StatusCode] = 'DENIED_PERMISSION'
                  )
          )
       OR
          (
              @Status = 'AVAILABLE_EMPTY'
              AND EXISTS
                  (
                      SELECT 1
                      FROM OPENJSON(@Json)
                      WITH ([ObjectName] sysname '$.ObjectName') AS [j]
                      WHERE [j].[ObjectName] = @ObjectName
                  )
          )
        THROW 54893, N'Der eingeschränkte Inventarpfad weist weder eine leere noch eine partielle Metadatensicht aus.', 1;

    DROP USER [ExampleOps009RestrictedUser];
    EXEC [master].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    EXEC [model].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    EXEC [msdb].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';

    SET @Json = NULL;
    SET @Status = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;
    IF @Status <> 'AVAILABLE_EMPTY'
       OR COALESCE(ISJSON(@Json), 0) <> 1
       OR EXISTS (SELECT 1 FROM OPENJSON(@Json))
        THROW 54894, N'Der leere Systemdatenbank-Inventarvertrag ist verletzt.', 1;
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleOps009RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleOps009RestrictedUser];
    IF OBJECT_ID(N'master.dbo.ExampleOps009Object', N'U') IS NOT NULL EXEC [master].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    IF OBJECT_ID(N'model.dbo.ExampleOps009Object', N'U') IS NOT NULL EXEC [model].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    IF OBJECT_ID(N'msdb.dbo.ExampleOps009Object', N'U') IS NOT NULL EXEC [msdb].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    THROW;
END CATCH;
GO
