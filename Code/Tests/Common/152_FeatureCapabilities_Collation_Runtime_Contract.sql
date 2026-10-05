USE [DeineDatenbank];
GO
/*
Prüft Capability-TABLE-/JSON-Parität, native Katalogidentität und Limits.
Die eigene synthetische Quelldatenbank wird vor und nach dem Vertrag geprüft.
Optionale Spezialindizes und Query-Store-Replikazähler bleiben deaktiviert.
*/
SET NOCOUNT ON;
DECLARE @DatabaseName sysname=N'ExampleCapabilitySourceÄ';
IF DB_ID(@DatabaseName) IS NOT NULL
    THROW 56030,N'Feature capability fixture already exists.',1;
CREATE DATABASE [ExampleCapabilitySourceÄ] COLLATE Latin1_General_100_CI_AS;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
BEGIN TRY
    DECLARE @CompatibilityLevel int=(SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
    DECLARE @CompatibilitySql nvarchar(128)=N'ALTER DATABASE [ExampleCapabilitySourceÄ] SET COMPATIBILITY_LEVEL = '+CONVERT(nvarchar(10),@CompatibilityLevel)+N';';
    EXEC [sys].[sp_executesql] @CompatibilitySql;
    DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @Platform nvarchar(60);
    SELECT TOP(1) @Platform=[host_platform] FROM [sys].[dm_os_host_info];
    CREATE TABLE [#FeatureCapabilitiesCollationRuntimeContract_Expected]
    (
          [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [MinimumKnownMajorVersion] int NOT NULL
    );
    INSERT [#FeatureCapabilitiesCollationRuntimeContract_Expected] VALUES
      (N'PERFORMANCE_STATE_PERMISSION',15),(N'ZSTD_BACKUP_COMPRESSION',17),
      (N'RESOURCE_GOVERNOR_STANDARD_EDITION',17),(N'EXTERNAL_LANGUAGE_CATALOG',15),
      (N'EXTERNAL_SCRIPT_REQUESTS',15),(N'EXTERNAL_RESOURCE_POOLS',15),
      (N'LAUNCHPAD_SERVICE_STATE',15),(N'CLR_HOST_RUNTIME',15),(N'CLR_TRUSTED_ASSEMBLIES',15);
    CREATE TABLE [#FeatureCapabilitiesCollationRuntimeContract_Linux]
    (
          [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [SourceObject] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AvailabilityStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    INSERT [#FeatureCapabilitiesCollationRuntimeContract_Linux]
    SELECT [v].[FeatureName],N'sys.'+[v].[ObjectName],
           CASE WHEN @Platform<>N'Linux' THEN 'UNAVAILABLE_PLATFORM'
                WHEN EXISTS(SELECT 1 FROM [master].[sys].[all_objects] [o]
                            JOIN [master].[sys].[schemas] [s] ON [s].[schema_id]=[o].[schema_id]
                            WHERE [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=[v].[ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
                              AND [s].[name]=N'sys') THEN 'AVAILABLE' ELSE 'UNAVAILABLE_VERSION' END
    FROM (VALUES(N'LINUX_CPU_HOST_STATS',N'dm_os_linux_cpu_stats'),
                (N'LINUX_DISK_HOST_STATS',N'dm_os_linux_disk_stats'),
                (N'LINUX_NETWORK_HOST_STATS',N'dm_os_linux_net_stats'),
                (N'LINUX_VM_HOST_STATS',N'dm_os_linux_vm_stats')) [v]([FeatureName],[ObjectName]);
    DECLARE @Case int=0,@Limit int,@IncludePlatform bit,@Selection nvarchar(max),@Json nvarchar(max);
    DECLARE @TableJson nvarchar(max),@NormalizedJson nvarchar(max),@ExpectedRows int,@ActualRows bigint;
    DECLARE @ExpectedFeatures TABLE([FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY);
    WHILE @Case<6
    BEGIN
        SET @Limit=CASE WHEN @Case IN(2,4) THEN 1 WHEN @Case=1 THEN NULL ELSE 0 END;
        SET @IncludePlatform=CASE WHEN @Case=1 THEN 0 ELSE 1 END;
        SET @Selection=CASE WHEN @Case=5 THEN N'[ExampleCapabilityMissingÜ]'
                            WHEN @Case IN(3,4) THEN N'[ExampleCapabilitySourceÄ]|[ExampleCapabilityMissingÜ]'
                            ELSE N'[ExampleCapabilitySourceÄ]' END;
        CREATE TABLE [#FeatureCapabilitiesCollationRuntimeContract_Collected]([Seed] bit NULL);
        SET LOCK_TIMEOUT 731;
        EXEC [monitor].[USP_ServerFeatureCapabilities]
              @DatabaseNames=@Selection,@MitSpezialindizes=0,@MitQueryStoreReplicas=0,
              @MitPlattformdetails=@IncludePlatform,@MaxZeilen=@Limit,
              @ResultSetArt='TABLE',@ResultTablesJson=N'{"capabilities":"#FeatureCapabilitiesCollationRuntimeContract_Collected"}',
              @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF @@LOCK_TIMEOUT<>731 THROW 56033,N'Feature capability lock timeout restore failed.',1;
        IF ISJSON(@Json)<>1 OR LEFT(COALESCE(JSON_QUERY(@Json,'$.capabilities'),N''),1)<>N'['
           OR LEFT(COALESCE(JSON_QUERY(@Json,'$.databaseFeatures'),N''),1)<>N'['
           OR COALESCE(JSON_QUERY(@Json,'$.specialIndexes'),N'')<>N'[]'
           OR LEFT(COALESCE(JSON_QUERY(@Json,'$.warnings'),N''),1)<>N'['
            THROW 56034,N'Feature capability JSON envelope failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#FeatureCapabilitiesCollationRuntimeContract_Collected')
              AND [collation_name] IS NOT NULL)<>7
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#FeatureCapabilitiesCollationRuntimeContract_Collected')
                       AND [collation_name] IS NOT NULL AND [collation_name]<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56031,N'Feature capability TABLE text collation failed.',1;
        SET @ExpectedRows=CASE WHEN @Limit=1 THEN 1 WHEN @IncludePlatform=1 THEN 13 ELSE 9 END;
        DECLARE @ProjectionSql nvarchar(max)=N'
SELECT @pCount=COUNT_BIG(*) FROM [#FeatureCapabilitiesCollationRuntimeContract_Collected];
SELECT @pJson=(SELECT [ScopeName],[FeatureName],[AvailabilityStatus],[LogicPath],
                     [MinimumKnownMajorVersion],[SourceObject],[Detail],[RequiredPermission]
              FROM [#FeatureCapabilitiesCollationRuntimeContract_Collected]
              ORDER BY [ScopeName],[FeatureName] FOR JSON PATH,INCLUDE_NULL_VALUES);';
        EXEC [sys].[sp_executesql] @ProjectionSql,N'@pCount bigint OUTPUT,@pJson nvarchar(max) OUTPUT',
             @pCount=@ActualRows OUTPUT,@pJson=@TableJson OUTPUT;
        IF @ActualRows<>@ExpectedRows OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.capabilities'))<>@ExpectedRows
            THROW 56032,N'Feature capability shared output limit failed.',1;
        SELECT @NormalizedJson=(SELECT [ScopeName],[FeatureName],[AvailabilityStatus],[LogicPath],
                                       [MinimumKnownMajorVersion],[SourceObject],[Detail],[RequiredPermission]
                                FROM OPENJSON(@Json,'$.capabilities') WITH
                                ([ScopeName] nvarchar(128),[FeatureName] nvarchar(128),[AvailabilityStatus] varchar(40),
                                 [LogicPath] nvarchar(256),[MinimumKnownMajorVersion] int,[SourceObject] nvarchar(512),
                                 [Detail] nvarchar(2000),[RequiredPermission] nvarchar(512))
                                ORDER BY [ScopeName],[FeatureName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(@TableJson,N'') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(@NormalizedJson,N'') COLLATE SQL_Latin1_General_CP1_CS_AS
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.capabilities') [j]
                     WHERE (SELECT COUNT_BIG(*) FROM OPENJSON([j].[value]))<>8)
            THROW 56035,N'Feature capability eight-field TABLE JSON parity failed.',1;
        DELETE FROM @ExpectedFeatures;
        INSERT @ExpectedFeatures SELECT TOP(CASE WHEN @Limit=1 THEN 1 ELSE 13 END) [FeatureName]
        FROM (SELECT [FeatureName] FROM [#FeatureCapabilitiesCollationRuntimeContract_Expected]
              UNION ALL SELECT [FeatureName] FROM [#FeatureCapabilitiesCollationRuntimeContract_Linux] WHERE @IncludePlatform=1) [x]
        ORDER BY [FeatureName];
        IF EXISTS(SELECT [FeatureName] FROM @ExpectedFeatures EXCEPT
                  SELECT [FeatureName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM OPENJSON(@Json,'$.capabilities') WITH([FeatureName] nvarchar(128)))
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.capabilities') WITH
                     ([ScopeName] nvarchar(128),[FeatureName] nvarchar(128),[MinimumKnownMajorVersion] int,[AvailabilityStatus] varchar(40),[SourceObject] nvarchar(512)) [j]
                     LEFT JOIN [#FeatureCapabilitiesCollationRuntimeContract_Expected] [e] ON [e].[FeatureName]=[j].[FeatureName] COLLATE SQL_Latin1_General_CP1_CS_AS
                     LEFT JOIN [#FeatureCapabilitiesCollationRuntimeContract_Linux] [l] ON [l].[FeatureName]=[j].[FeatureName] COLLATE SQL_Latin1_General_CP1_CS_AS
                     WHERE COALESCE([j].[ScopeName],N'')<>N'SERVER'
                        OR COALESCE([j].[MinimumKnownMajorVersion],0)<>COALESCE([e].[MinimumKnownMajorVersion],17)
                        OR COALESCE([j].[AvailabilityStatus],'')<>CASE WHEN [e].[FeatureName] IS NOT NULL THEN
                           CASE WHEN @Major>=[e].[MinimumKnownMajorVersion] THEN 'AVAILABLE' ELSE 'UNAVAILABLE_VERSION' END ELSE [l].[AvailabilityStatus] END
                        OR ([l].[FeatureName] IS NOT NULL AND COALESCE([j].[SourceObject],N'')<>[l].[SourceObject]))
            THROW 56036,N'Feature capability native routing identity failed.',1;
        IF COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>CASE WHEN @Case=5 THEN 'ERROR_HANDLED' WHEN @Case IN(3,4) THEN 'PARTIAL_RESULT' ELSE 'AVAILABLE' END
           OR COALESCE(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>CASE WHEN @Case>=3 THEN 'true' ELSE 'false' END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.warnings'))<>CASE WHEN @Case>=3 THEN 1 ELSE 0 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseFeatures'))<>CASE WHEN @Case=5 THEN 0 WHEN @Limit=1 THEN 1 ELSE 2 END
            THROW 56037,N'Feature capability selection status failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH([DatabaseName] nvarchar(128),[ModuleName] nvarchar(128))
                  WHERE COALESCE([DatabaseName],N'')<>N'ExampleCapabilityMissingÜ' OR COALESCE([ModuleName],N'')<>N'DatabaseSelection')
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseFeatures') WITH([DatabaseName] nvarchar(128),[CompatibilityLevel] int,[StateDesc] nvarchar(60)) [j]
                     WHERE COALESCE([j].[DatabaseName],N'')<>@DatabaseName
                        OR COALESCE([j].[CompatibilityLevel],0)<>(SELECT [compatibility_level] FROM [sys].[databases] WHERE [name]=@DatabaseName)
                        OR COALESCE([j].[StateDesc],N'')<>(SELECT [state_desc] FROM [sys].[databases] WHERE [name]=@DatabaseName))
            THROW 56038,N'Feature capability native database scope failed.',1;
        DROP TABLE [#FeatureCapabilitiesCollationRuntimeContract_Collected];
        SET @Case+=1;
    END;
    DECLARE @SuccessRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @SuccessRestoreSql;
    DROP DATABASE [ExampleCapabilitySourceÄ];
END TRY
BEGIN CATCH
    DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSql;
    IF DB_ID(N'ExampleCapabilitySourceÄ') IS NOT NULL
    BEGIN
        ALTER DATABASE [ExampleCapabilitySourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleCapabilitySourceÄ];
    END;
    THROW;
END CATCH;
PRINT N'FEATURE_CAPABILITIES_COLLATION_RUNTIME_CONTRACT PASS';
GO
