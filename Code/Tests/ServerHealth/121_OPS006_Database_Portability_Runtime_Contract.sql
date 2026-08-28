USE [DeineDatenbank];
GO

/* Prüft leere, uncontained, fehlende und eingeschränkte Pfade ausschließlich mit synthetischen Datenbanken. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @PortableDatabase sysname = N'ExampleOps006Portable';
DECLARE @UncontainedDatabase sysname = N'ExampleOps006Uncontained';
DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;
DECLARE @Sql nvarchar(max);

IF DB_ID(@PortableDatabase) IS NOT NULL OR DB_ID(@UncontainedDatabase) IS NOT NULL
    THROW 54860, N'Ein synthetischer Portabilitäts-Datenbankname ist bereits belegt.', 1;

BEGIN TRY
    SET @Sql = N'CREATE DATABASE ' + QUOTENAME(@PortableDatabase) + N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql = N'CREATE DATABASE ' + QUOTENAME(@UncontainedDatabase) + N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;

    SET @Sql = N'USE ' + QUOTENAME(@UncontainedDatabase) + N';
EXEC(N''CREATE OR ALTER PROCEDURE [dbo].[ExampleOps006Procedure]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT_BIG(*) AS [SyntheticCount] FROM [master].[sys].[databases];
END;'');';
    EXEC [sys].[sp_executesql] @Sql;

    EXEC [monitor].[USP_DatabasePortabilityAnalysis]
          @DatabaseNames = N'[ExampleOps006Portable]'
        , @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF COALESCE(ISJSON(@Json), 0) <> 1 OR @Status NOT IN ('AVAILABLE_EMPTY', 'AVAILABLE')
        THROW 54861, N'Der portable Leerfall ist verletzt.', 1;

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;

    EXEC [monitor].[USP_DatabasePortabilityAnalysis]
          @DatabaseNames = N'[ExampleOps006Uncontained]'
        , @MaxZeilen = 100
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
       OR NOT EXISTS
          (
              SELECT 1 FROM OPENJSON(@Json)
              WITH ([EvidenceType] varchar(40) '$.EvidenceType') AS [j]
              WHERE [j].[EvidenceType] = 'UNCONTAINED_ENTITY'
          )
        THROW 54862, N'Die synthetische uncontained dependency fehlt.', 1;

    SET @Json = NULL;
    SET @Status = NULL;
    EXEC [monitor].[USP_DatabasePortabilityAnalysis]
          @DatabaseNames = N'[ExampleOps006Missing]'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;
    IF @Status <> 'NOT_FOUND' OR COALESCE(ISJSON(@Json), 0) <> 1
        THROW 54863, N'Der fehlende Datenbankpfad ist verletzt.', 1;

    DROP USER IF EXISTS [ExampleOps006RestrictedUser];
    CREATE USER [ExampleOps006RestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON [monitor].[USP_DatabasePortabilityAnalysis] TO [ExampleOps006RestrictedUser];
    EXECUTE AS USER = N'ExampleOps006RestrictedUser';
    SET @Json = NULL;
    EXEC [monitor].[USP_DatabasePortabilityAnalysis]
          @DatabaseNames = N'[ExampleOps006Uncontained]'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0;
    REVERT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
        THROW 54864, N'Der eingeschränkte Portabilitätspfad warf den Vertrag ab.', 1;

    DROP USER [ExampleOps006RestrictedUser];
    SET @Sql = N'DROP DATABASE ' + QUOTENAME(@UncontainedDatabase) + N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql = N'DROP DATABASE ' + QUOTENAME(@PortableDatabase) + N';';
    EXEC [sys].[sp_executesql] @Sql;
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleOps006RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleOps006RestrictedUser];
    IF DB_ID(@UncontainedDatabase) IS NOT NULL
    BEGIN
        SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@UncontainedDatabase) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@UncontainedDatabase) + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
    IF DB_ID(@PortableDatabase) IS NOT NULL
    BEGIN
        SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@PortableDatabase) + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE ' + QUOTENAME(@PortableDatabase) + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
    THROW;
END CATCH;
GO
