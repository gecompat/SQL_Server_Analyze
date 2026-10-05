USE [DeineDatenbank];
GO
/* Prüft sieben Serverversions-Exporte mit eigenen synthetischen Datenbanken. */
SET NOCOUNT ON;
IF DB_ID(N'ExampleVersionSourceÄ') IS NOT NULL OR DB_ID(N'ExampleVersionSourceÜ') IS NOT NULL
    THROW 56040,N'Server version fixture already exists.',1;
DECLARE @CreatedA bit=0,@CreatedB bit=0;
BEGIN TRY
    CREATE DATABASE [ExampleVersionSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @CreatedA=1;
    CREATE DATABASE [ExampleVersionSourceÜ] COLLATE SQL_Latin1_General_CP1_CS_AS;
    SET @CreatedB=1;
    ALTER DATABASE [ExampleVersionSourceÄ] SET COMPATIBILITY_LEVEL=150;
    ALTER DATABASE [ExampleVersionSourceÜ] SET COMPATIBILITY_LEVEL=160;
    DECLARE @Map TABLE
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY
        , [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [TextColumns] int
        , [OrderBy] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS
    );
    INSERT @Map VALUES
      (N'serverVersion',N'#ServerVersionCollationRuntimeContract_Server',20,N'[ProductMajorVersion]'),
      (N'buildAssessment',N'#ServerVersionCollationRuntimeContract_Build',14,N'[ProductVersion]'),
      (N'lifecycle',N'#ServerVersionCollationRuntimeContract_Lifecycle',8,N'[ProductMajorVersion]'),
      (N'instanceFeatures',N'#ServerVersionCollationRuntimeContract_Features',6,N'[FeatureName]'),
      (N'databaseCompatibility',N'#ServerVersionCollationRuntimeContract_Databases',8,N'[DatabaseName]'),
      (N'references',N'#ServerVersionCollationRuntimeContract_References',3,N'[ReferenceType],[ProductMajorVersion]'),
      (N'warnings',N'#ServerVersionCollationRuntimeContract_Warnings',5,N'[WarningOrdinal]');
    DECLARE @Case int=0,@IncludeDatabases bit,@Limit int,@Selection nvarchar(max),@Json nvarchar(max);
    DECLARE @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
    DECLARE @ResultName sysname,@TableName sysname,@TextColumns int,@OrderBy nvarchar(256),@Sql nvarchar(max),@TableJson nvarchar(max),@ActualArray nvarchar(max);
    WHILE @Case<4
    BEGIN
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Server]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Build]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Lifecycle]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Features]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Databases]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_References]([Seed] bit NULL);
        CREATE TABLE [#ServerVersionCollationRuntimeContract_Warnings]([Seed] bit NULL);
        SET @IncludeDatabases=CASE WHEN @Case=0 THEN 0 ELSE 1 END;
        SET @Limit=CASE WHEN @Case=1 THEN 0 ELSE 1 END;
        SET @Selection=CASE WHEN @Case=0 THEN NULL WHEN @Case=3 THEN N'[ExampleVersionSourceÄ]|[ExampleVersionMissingÖ]'
                            ELSE N'[ExampleVersionSourceÜ]|[ExampleVersionSourceÄ]' END;
        EXEC [monitor].[USP_ServerVersionInformation]
              @MitDatenbankKompatibilitaet=@IncludeDatabases,@DatabaseNames=@Selection,@MaxZeilen=@Limit,
              @ResultSetArt='TABLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
              @ResultTablesJson=N'{"serverVersion":"#ServerVersionCollationRuntimeContract_Server","buildAssessment":"#ServerVersionCollationRuntimeContract_Build","lifecycle":"#ServerVersionCollationRuntimeContract_Lifecycle","instanceFeatures":"#ServerVersionCollationRuntimeContract_Features","databaseCompatibility":"#ServerVersionCollationRuntimeContract_Databases","references":"#ServerVersionCollationRuntimeContract_References","warnings":"#ServerVersionCollationRuntimeContract_Warnings"}',
              @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF ISJSON(@Json)<>1 OR COALESCE(@Status,'')<>CASE WHEN @Case=3 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case=3 THEN 1 ELSE 0 END
            THROW 56042,N'Server version status or envelope failed.',1;
        DECLARE [ExportCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TableName],[TextColumns],[OrderBy] FROM @Map;
        OPEN [ExportCursor];
        FETCH NEXT FROM [ExportCursor] INTO @ResultName,@TableName,@TextColumns,@OrderBy;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..'+@TableName) AND [collation_name] IS NOT NULL)<>@TextColumns
               OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..'+@TableName)
                         AND [collation_name] IS NOT NULL AND [collation_name]<>N'SQL_Latin1_General_CP1_CS_AS')
                THROW 56041,N'Server version export text collation failed.',1;
            SET @ActualArray=JSON_QUERY(@Json,N'$.'+@ResultName);
            IF LEFT(COALESCE(@ActualArray,N''),1)<>N'[' THROW 56043,N'Server version array missing.',1;
            SET @Sql=N'SELECT @pJson=(SELECT * FROM '+QUOTENAME(@TableName)+N' ORDER BY '+@OrderBy+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
            EXEC [sys].[sp_executesql] @Sql,N'@pJson nvarchar(max) OUTPUT',@pJson=@TableJson OUTPUT;
            IF CONVERT(varbinary(max),COALESCE(@TableJson,N'[]'))<>CONVERT(varbinary(max),@ActualArray)
                THROW 56044,N'Server version complete TABLE JSON representation failed.',1;
            FETCH NEXT FROM [ExportCursor] INTO @ResultName,@TableName,@TextColumns,@OrderBy;
        END;
        CLOSE [ExportCursor];
        DEALLOCATE [ExportCursor];
        IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.serverVersion'))<>1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.buildAssessment'))<>1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.lifecycle'))<>1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.instanceFeatures'))<>9
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.references'))<>5
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseCompatibility'))<>CASE WHEN @Case=0 THEN 0 WHEN @Case=1 THEN 2 ELSE 1 END
            THROW 56045,N'Server version result counts failed.',1;
        IF COALESCE(JSON_VALUE(@Json,'$.serverVersion[0].ProductVersion'),N'')<>CONVERT(nvarchar(32),SERVERPROPERTY(N'ProductVersion'))
           OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,'$.serverVersion[0].ProductMajorVersion')),0)<>TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))
           OR COALESCE(JSON_VALUE(@Json,'$.serverVersion[0].ServerCollation'),N'')<>CONVERT(nvarchar(128),SERVERPROPERTY(N'Collation'))
           OR COALESCE(JSON_VALUE(@Json,'$.serverVersion[0].TempDbCollation'),N'')<>CONVERT(nvarchar(128),DATABASEPROPERTYEX(N'tempdb',N'Collation'))
            THROW 56046,N'Server version native instance identity failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.instanceFeatures') WITH([FeatureName] nvarchar(128),[FeatureValue] int) [j]
                  WHERE [j].[FeatureValue]<>TRY_CONVERT(int,SERVERPROPERTY([j].[FeatureName]))
                     OR ([j].[FeatureValue] IS NULL AND SERVERPROPERTY([j].[FeatureName]) IS NOT NULL)
                     OR ([j].[FeatureValue] IS NOT NULL AND SERVERPROPERTY([j].[FeatureName]) IS NULL))
            THROW 56047,N'Server version native feature values failed.',1;
        IF EXISTS(SELECT [v].[FeatureName] FROM
                  (VALUES(N'IsClustered'),(N'IsHadrEnabled'),(N'HadrManagerStatus'),(N'IsLocalDB'),
                         (N'IsFullTextInstalled'),(N'IsPolyBaseInstalled'),(N'IsXTPSupported'),
                         (N'IsAdvancedAnalyticsInstalled'),(N'IsTempDbMetadataMemoryOptimized')) [v]([FeatureName])
                  EXCEPT SELECT [FeatureName] FROM OPENJSON(@Json,'$.instanceFeatures') WITH([FeatureName] nvarchar(128)))
            THROW 56047,N'Server version native feature names failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseCompatibility') WITH([DatabaseId] int,[DatabaseName] nvarchar(128),[CompatibilityLevel] int,[CollationName] nvarchar(128),[StateDesc] nvarchar(60)) [j]
                  LEFT JOIN [master].[sys].[databases] [d] ON [d].[database_id]=[j].[DatabaseId]
                  WHERE [d].[database_id] IS NULL OR COALESCE([j].[DatabaseName],N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                     OR COALESCE([j].[CompatibilityLevel],0)<>[d].[compatibility_level]
                     OR COALESCE([j].[CollationName],N'')<>[d].[collation_name]
                     OR COALESCE([j].[StateDesc],N'')<>[d].[state_desc])
           OR (@Case=2 AND COALESCE(JSON_VALUE(@Json,'$.databaseCompatibility[0].DatabaseName'),N'')<>N'ExampleVersionSourceÜ')
           OR (@Case=3 AND COALESCE(JSON_VALUE(@Json,'$.databaseCompatibility[0].DatabaseName'),N'')<>N'ExampleVersionSourceÄ')
            THROW 56048,N'Server version native database identity or requested-order limit failed.',1;
        IF @Case=1 AND EXISTS(SELECT [v].[DatabaseName] FROM (VALUES(N'ExampleVersionSourceÄ'),(N'ExampleVersionSourceÜ')) [v]([DatabaseName])
                             EXCEPT SELECT [DatabaseName] FROM OPENJSON(@Json,'$.databaseCompatibility') WITH([DatabaseName] nvarchar(128)))
            THROW 56048,N'Server version exact own database set failed.',1;
        IF @Case=3 AND (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.warnings') WITH([IsPartial] bit,[SourceObject] nvarchar(256),[StatusCode] varchar(40),[Message] nvarchar(2048))
                       WHERE [IsPartial]=1 AND [SourceObject]=N'master.sys.databases' AND [StatusCode]='DATABASE_UNAVAILABLE'
                         AND [Message]=N'Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.')<>1
            THROW 56049,N'Server version partial selection warning missing.',1;
        DROP TABLE [#ServerVersionCollationRuntimeContract_Server];
        DROP TABLE [#ServerVersionCollationRuntimeContract_Build];
        DROP TABLE [#ServerVersionCollationRuntimeContract_Lifecycle];
        DROP TABLE [#ServerVersionCollationRuntimeContract_Features];
        DROP TABLE [#ServerVersionCollationRuntimeContract_Databases];
        DROP TABLE [#ServerVersionCollationRuntimeContract_References];
        DROP TABLE [#ServerVersionCollationRuntimeContract_Warnings];
        SET @Case+=1;
    END;
    DROP DATABASE [ExampleVersionSourceÄ];
    SET @CreatedA=0;
    DROP DATABASE [ExampleVersionSourceÜ];
    SET @CreatedB=0;
END TRY
BEGIN CATCH
    IF @CreatedA=1 AND DB_ID(N'ExampleVersionSourceÄ') IS NOT NULL
    BEGIN
        ALTER DATABASE [ExampleVersionSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleVersionSourceÄ];
    END;
    IF @CreatedB=1 AND DB_ID(N'ExampleVersionSourceÜ') IS NOT NULL
    BEGIN
        ALTER DATABASE [ExampleVersionSourceÜ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleVersionSourceÜ];
    END;
    THROW;
END CATCH;
PRINT N'SERVER_VERSION_COLLATION_RUNTIME_CONTRACT PASS';
GO
