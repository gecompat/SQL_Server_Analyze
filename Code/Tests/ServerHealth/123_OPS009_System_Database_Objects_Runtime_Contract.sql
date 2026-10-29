USE [DeineDatenbank];
GO

/* Prüft positives Inventar, Begrenzung und partielle Sichtbarkeit mit drei synthetischen Tabellen. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ObjectName sysname = N'ExampleOps009Object';
DECLARE @RestrictedLogin sysname = N'ExampleOps009RestrictedLogin';
DECLARE @RestrictedCredential nvarchar(128) = N'ExampleOps009Aa1' + NCHAR(33) + CONVERT(nvarchar(36), NEWID());
DECLARE @Json nvarchar(max) = NULL;
DECLARE @JsonNull nvarchar(max) = NULL;
DECLARE @JsonZero nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Sql nvarchar(max) = NULL;
DECLARE @Partial bit = NULL;
DECLARE @LimitedDatabaseName sysname = NULL;
DECLARE @LimitedSchemaName sysname = NULL;
DECLARE @LimitedObjectName sysname = NULL;
DECLARE @ConsoleRows TABLE ([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[CreateDate] datetime,[ModifyDate] datetime,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS);
DECLARE @MasterCreated bit=0, @ModelCreated bit=0, @MsdbCreated bit=0;
DECLARE @LoginCreated bit=0, @UserCreated bit=0, @MasterUserCreated bit=0;

IF OBJECT_ID(N'master.dbo.ExampleOps009Object') IS NOT NULL
   OR OBJECT_ID(N'model.dbo.ExampleOps009Object') IS NOT NULL
   OR OBJECT_ID(N'msdb.dbo.ExampleOps009Object') IS NOT NULL
    THROW 54890, N'Der synthetische Systemdatenbank-Objektname ist bereits belegt.', 1;
IF EXISTS (SELECT 1 FROM [master].[sys].[server_principals] WHERE [name] = @RestrictedLogin)
   OR USER_ID(N'ExampleOps009RestrictedUser') IS NOT NULL
   OR EXISTS (SELECT 1 FROM [master].[sys].[database_principals] WHERE [name]=N'ExampleOps009RestrictedUser')
    THROW 54893, N'Die synthetischen Berechtigungsfixture-Namen sind bereits belegt.', 1;

BEGIN TRY
    EXEC [master].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';
    SET @MasterCreated=1;
    EXEC [model].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';
    SET @ModelCreated=1;
    EXEC [msdb].[sys].[sp_executesql] N'CREATE TABLE [dbo].[ExampleOps009Object]([SyntheticId] int NOT NULL);';
    SET @MsdbCreated=1;

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF COALESCE(@Status,'')<>'INVALID_PARAMETER' OR COALESCE(@Partial,0)<>1 OR COALESCE(ISJSON(@Json),0)<>1 OR EXISTS(SELECT 1 FROM OPENJSON(@Json)) THROW 54901,N'Der negative Zeilenlimit-Parameter weist den Systemdatenbank-Aufruf nicht als ungültig ohne Inventarzeilen aus.',1;

    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 100
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;

    IF COALESCE(@Status,'') <> 'AVAILABLE' OR COALESCE(@Partial,1) <> 0
       OR COALESCE(ISJSON(@Json),0) <> 1
       OR
       (
           SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([DatabaseName] sysname '$.DatabaseName', [ObjectName] sysname '$.ObjectName') AS [j]
           WHERE [j].[DatabaseName] IN (N'master', N'model', N'msdb')
             AND [j].[ObjectName] = @ObjectName
       ) <> 3
        THROW 54891, N'Das positive Systemdatenbank-Inventar ist verletzt.', 1;

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = NULL
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @JsonNull OUTPUT
        , @PrintMeldungen = 0;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 0
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @JsonZero OUTPUT
        , @PrintMeldungen = 0;
    IF COALESCE(ISJSON(@JsonNull), 0) <> 1
       OR COALESCE(ISJSON(@JsonZero), 0) <> 1
       OR @JsonNull <> @JsonZero
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@JsonNull)
           WITH ([DatabaseName] sysname '$.DatabaseName', [ObjectName] sysname '$.ObjectName')
           WHERE [DatabaseName] IN (N'master', N'model', N'msdb') AND [ObjectName] = @ObjectName) <> 3
        THROW 54896, N'Die NULL-/0-Äquivalenz für das nichtleere Systemdatenbank-Inventar ist verletzt.', 1;

    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = NULL
        , @ResultSetArt = 'RAW'
        , @JsonErzeugen = 0
        , @PrintMeldungen = 0;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 0
        , @ResultSetArt = 'RAW'
        , @JsonErzeugen = 0
        , @PrintMeldungen = 0;

    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 1
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;
    IF COALESCE(@Status,'') <> 'AVAILABLE' OR COALESCE(@Partial,1) <> 0
       OR COALESCE(ISJSON(@Json),0) <> 1 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 1
        THROW 54892, N'Die Begrenzung des Systemdatenbank-Inventars ist verletzt.', 1;

    SELECT TOP (1) @LimitedDatabaseName=[DatabaseName],@LimitedSchemaName=[SchemaName],@LimitedObjectName=[ObjectName] FROM OPENJSON(@Json) WITH ([DatabaseName] sysname '$.DatabaseName',[SchemaName] sysname '$.SchemaName',[ObjectName] sysname '$.ObjectName') ORDER BY [DatabaseName],[SchemaName],[ObjectName];
    CREATE TABLE [#OPS009_System_Database_Objects_Runtime_Contract_LimitTarget] ([Placeholder] int NULL);
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"systemDatabaseObjects":"#OPS009_System_Database_Objects_Runtime_Contract_LimitTarget"}',@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM [#OPS009_System_Database_Objects_Runtime_Contract_LimitTarget])<>1 OR NOT EXISTS(SELECT 1 FROM [#OPS009_System_Database_Objects_Runtime_Contract_LimitTarget] WHERE [DatabaseName]=@LimitedDatabaseName AND [SchemaName]=@LimitedSchemaName AND [ObjectName]=@LimitedObjectName) THROW 54897,N'Die begrenzte TABLE-Ausgabe stimmt nicht mit JSON überein.',1;
    INSERT @ConsoleRows EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM @ConsoleRows)<>1 OR NOT EXISTS(SELECT 1 FROM @ConsoleRows WHERE [DatabaseName]=@LimitedDatabaseName AND [SchemaName]=@LimitedSchemaName AND [ObjectName]=@LimitedObjectName) THROW 54898,N'Die begrenzte CONSOLE-Ausgabe stimmt nicht mit JSON überein.',1;
    CREATE TABLE [#OPS009_System_Database_Objects_Runtime_Contract_UnboundedTarget] ([Placeholder] int NULL);
    DELETE FROM @ConsoleRows;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen=NULL,@ResultSetArt='TABLE',@ResultTablesJson=N'{"systemDatabaseObjects":"#OPS009_System_Database_Objects_Runtime_Contract_UnboundedTarget"}',@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM [#OPS009_System_Database_Objects_Runtime_Contract_UnboundedTarget])<>(SELECT COUNT_BIG(*) FROM OPENJSON(@JsonNull)) THROW 54899,N'Die unbeschränkte TABLE-Ausgabe weicht von JSON ab.',1;
    INSERT @ConsoleRows EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen=0,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM @ConsoleRows)<>(SELECT COUNT_BIG(*) FROM OPENJSON(@JsonZero)) THROW 54900,N'Die unbeschränkte CONSOLE-Ausgabe weicht von JSON ab.',1;

    SET @Sql = N'CREATE LOGIN [ExampleOps009RestrictedLogin] WITH '
             + N'PASS' + N'WORD = '
             + QUOTENAME(@RestrictedCredential, N'''')
             + N', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @RestrictedCredential=NULL;
    SET @Sql=NULL;
    CREATE USER [ExampleOps009RestrictedUser] FOR LOGIN [ExampleOps009RestrictedLogin];
    SET @UserCreated=1;
    GRANT EXECUTE ON [monitor].[USP_SystemDatabaseObjectInventory] TO [ExampleOps009RestrictedUser];
    EXECUTE AS LOGIN = N'ExampleOps009RestrictedLogin';
    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;
    REVERT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
       OR COALESCE(@Status,'') <> 'AVAILABLE_LIMITED' OR COALESCE(@Partial,0) <> 1
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@Json)
              WITH ([StatusCode] varchar(40) '$.StatusCode') AS [j]
              WHERE [j].[StatusCode] = 'DENIED_PERMISSION'
          )
        THROW 54894, N'Der eingeschränkte Loginpfad weist keine partielle Metadatensicht aus.', 1;

    EXEC [master].[sys].[sp_executesql] N'CREATE USER [ExampleOps009RestrictedUser] FOR LOGIN [ExampleOps009RestrictedLogin];';
    SET @MasterUserCreated=1;
    EXEC [master].[sys].[sp_executesql] N'GRANT SELECT ON [dbo].[ExampleOps009Object] TO [ExampleOps009RestrictedUser];';
    EXECUTE AS LOGIN = N'ExampleOps009RestrictedLogin';
    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen=20, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT,
          @PrintMeldungen=0, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    REVERT;
    IF COALESCE(@Status,'') <> 'AVAILABLE_LIMITED' OR COALESCE(@Partial,0) <> 1
       OR COALESCE(ISJSON(@Json),0) <> 1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WITH ([DatabaseName] sysname, [ObjectName] sysname, [StatusCode] varchar(40))
           WHERE [ObjectName]=@ObjectName AND [DatabaseName]=N'master' AND [StatusCode]='AVAILABLE') <> 1
       OR EXISTS (SELECT 1 FROM OPENJSON(@Json)
                  WITH ([DatabaseName] sysname, [ObjectName] sysname)
                  WHERE [ObjectName]=@ObjectName AND [DatabaseName] IN (N'model',N'msdb'))
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json)
                      WITH ([DatabaseName] sysname, [StatusCode] varchar(40))
                      WHERE [DatabaseName]=N'model' AND [StatusCode]='DENIED_PERMISSION')
        THROW 54895, N'Das selektive Metadatenprofil trennt sichtbares Objekt und verweigerten Datenbankzugriff nicht.', 1;
    EXEC [master].[sys].[sp_executesql] N'DROP USER [ExampleOps009RestrictedUser];';
    SET @MasterUserCreated=0;

    DROP USER [ExampleOps009RestrictedUser];
    SET @UserCreated=0;
    EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleOps009RestrictedLogin];';
    SET @LoginCreated=0;
    EXEC [master].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    SET @MasterCreated=0;
    EXEC [model].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    SET @ModelCreated=0;
    EXEC [msdb].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    SET @MsdbCreated=0;

    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;
    EXEC [monitor].[USP_SystemDatabaseObjectInventory]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;
    IF COALESCE(@Status,'') <> 'AVAILABLE_EMPTY' OR COALESCE(@Partial,1) <> 0
       OR COALESCE(ISJSON(@Json), 0) <> 1
       OR EXISTS (SELECT 1 FROM OPENJSON(@Json))
        THROW 54894, N'Der leere Systemdatenbank-Inventarvertrag ist verletzt.', 1;
END TRY
BEGIN CATCH
    IF SUSER_SNAME() = N'ExampleOps009RestrictedLogin' REVERT;
    IF @UserCreated=1 DROP USER [ExampleOps009RestrictedUser];
    IF @MasterUserCreated=1 EXEC [master].[sys].[sp_executesql] N'DROP USER [ExampleOps009RestrictedUser];';
    IF @LoginCreated=1
        EXEC [master].[sys].[sp_executesql] N'DROP LOGIN [ExampleOps009RestrictedLogin];';
    IF @MasterCreated=1 EXEC [master].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    IF @ModelCreated=1 EXEC [model].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    IF @MsdbCreated=1 EXEC [msdb].[sys].[sp_executesql] N'DROP TABLE [dbo].[ExampleOps009Object];';
    THROW;
END CATCH;
GO
