/*
Zweck: Prüft die Katalogsicht von Analyze an einer eigenen registrierten SAFE-Assembly.
Voraussetzungen: Die GitHub-CI bindet eine eigens erzeugte Assembly und eine
isolierte Linux-Testinstanz. Auf die passive Katalogprüfung folgt der Aufruf
der eigenen Funktion und ein Vergleich mit der geladenen Assembly.
*/
USE [DeineDatenbank];
GO
SET NOCOUNT ON;

DECLARE @Binary varbinary(max) = __WI_CLR_PROBE_BYTES__;
IF DB_NAME()<>N'SQLServerAnalyzeTest' OR @@TRANCOUNT<>0
    OR COALESCE(TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),-1)<>17
    OR COALESCE((SELECT compatibility_level FROM sys.databases WHERE database_id=DB_ID()),-1)<>170
    OR NOT EXISTS (SELECT 1 FROM sys.dm_os_host_info WHERE host_platform=N'Linux')
    OR DATALENGTH(@Binary) NOT BETWEEN 1 AND 65536
    THROW 56860,N'CLR fixture isolation or binary binding failed',1;

DECLARE @OwnedDb sysname=N'ExampleClrProbe_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');
DECLARE @OldDbId int=DB_ID(),@OldSpid int=@@SPID,@OldOptions int=@@OPTIONS,@OldTimeout int=@@LOCK_TIMEOUT;
DECLARE @OwnedDbId int,@ClrBefore int,@StrictBefore int,@StrictConfiguredBefore int,@Sql nvarchar(max),@Hash varbinary(64)=HASHBYTES('SHA2_512',@Binary);
DECLARE @OwnTrust bit=0,@ClrChangeAttempted bit=0,@ClrConfiguredBefore int;
DECLARE @Error int,@ConfigCleanupError int,@DbCleanupError int,@TrustCleanupError int;
DECLARE @AssemblyId int,@ClrName nvarchar(4000),@AssemblyClass sysname,@AssemblyMethod sysname;
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@Names nvarchar(max)=QUOTENAME(@OwnedDb);
SELECT @ClrBefore=CONVERT(int,value_in_use),@ClrConfiguredBefore=CONVERT(int,value)
FROM sys.configurations WHERE name=N'clr enabled';
SELECT @StrictBefore=CONVERT(int,value_in_use),@StrictConfiguredBefore=CONVERT(int,value)
FROM sys.configurations WHERE name=N'clr strict security';
DECLARE @ConfigBefore TABLE
    ([Id] int NOT NULL PRIMARY KEY,[Name] nvarchar(35),[Configured] int,[InUse] int,[IsDynamic] bit);
INSERT @ConfigBefore
SELECT configuration_id,name,CONVERT(int,value),CONVERT(int,value_in_use),is_dynamic FROM sys.configurations;

IF @ClrBefore IS NULL OR ISNULL(@ClrConfiguredBefore,-1)<>@ClrBefore
   OR ISNULL(@StrictBefore,0)<>1 OR ISNULL(@StrictConfiguredBefore,0)<>1 OR DB_ID(@OwnedDb) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.trusted_assemblies WHERE [hash]=@Hash)
    THROW 56861,N'CLR fixture requires unused names and strict security',1;
IF @ClrBefore=0 AND EXISTS
(
    SELECT 1 FROM @ConfigBefore
    WHERE [IsDynamic]=1 AND [Configured]<>[InUse]
      AND NOT ([Name]=N'max server memory (MB)' AND [Configured]=0 AND [InUse]=2147483647)
      AND NOT ([Name]=N'min server memory (MB)' AND [Configured]=0 AND [InUse] IN(8,16))
)
    THROW 56873,N'CLR fixture will not apply other pending server configuration',1;

BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@OwnedDb)+N';';
    EXEC sys.sp_executesql @Sql;
    SET @OwnedDbId=DB_ID(@OwnedDb);
    IF @OwnedDbId IS NULL OR NOT EXISTS(SELECT 1 FROM sys.databases WHERE database_id=@OwnedDbId AND is_trustworthy_on=0)
        THROW 56862,N'CLR fixture database ownership or trustworthy mismatch',1;
    EXEC master.sys.sp_add_trusted_assembly @hash=@Hash,@description=N'Example Analyze SAFE metadata fixture';
    SET @OwnTrust=1;

    SET @Sql=N'USE '+QUOTENAME(@OwnedDb)+N';
        CREATE ASSEMBLY [ExampleAnalyzeClrProbe] FROM '+CONVERT(nvarchar(max),@Binary,1)+N' WITH PERMISSION_SET=SAFE;
        EXEC sys.sp_executesql N''CREATE FUNCTION dbo.ExampleAnalyzeClrValue() RETURNS int
            AS EXTERNAL NAME [ExampleAnalyzeClrProbe].[ExampleAnalyzeProbe.Marker].[ReadValue];'';';
    EXEC sys.sp_executesql @Sql;
    SET @Sql=N'USE '+QUOTENAME(@OwnedDb)+N';
        SELECT @Id=a.assembly_id,@Name=a.clr_name,@Class=m.assembly_class,@Method=m.assembly_method
        FROM sys.assemblies AS a
        INNER JOIN sys.assembly_modules AS m ON m.assembly_id=a.assembly_id
        WHERE a.is_user_defined=1 AND a.name=N''ExampleAnalyzeClrProbe'' AND a.permission_set_desc=N''SAFE_ACCESS''
            AND m.object_id=OBJECT_ID(N''dbo.ExampleAnalyzeClrValue'',N''FS'');';
    EXEC sys.sp_executesql @Sql,N'@Id int OUTPUT,@Name nvarchar(4000) OUTPUT,@Class sysname OUTPUT,@Method sysname OUTPUT',
        @Id=@AssemblyId OUTPUT,@Name=@ClrName OUTPUT,@Class=@AssemblyClass OUTPUT,@Method=@AssemblyMethod OUTPUT;
    IF @AssemblyId IS NULL OR @ClrName IS NULL OR ISNULL(@AssemblyClass,N'')<>N'ExampleAnalyzeProbe.Marker'
       OR ISNULL(@AssemblyMethod,N'')<>N'ReadValue'
        THROW 56863,N'CLR fixture native SAFE registration unavailable',1;

    CREATE TABLE [#WIClrProbe_Findings]([Seed] int NULL);
    EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=@Names,@AssemblyNames=N'[ExampleAnalyzeClrProbe]',
        @MitModulzuordnung=1,@MitBerechtigungsanalyse=0,@SampleSeconds=0,
        @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#WIClrProbe_Findings"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;

    IF @@TRANCOUNT<>0 OR DB_ID()<>@OldDbId OR @@SPID<>@OldSpid OR @@OPTIONS<>@OldOptions OR @@LOCK_TIMEOUT<>@OldTimeout
        THROW 56864,N'CLR fixture caller state changed',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR ISNULL(@Status,'') NOT IN('AVAILABLE','AVAILABLE_LIMITED','AVAILABLE_WITH_FINDING')
       OR @Partial IS NULL OR CHARINDEX(CONVERT(varchar(128),@Hash,2),@Json COLLATE Latin1_General_100_CI_AS)>0
        THROW 56865,N'CLR fixture Analyze status or hash exclusion mismatch',1;
    IF (@ClrBefore=0 AND @Status NOT IN('AVAILABLE_LIMITED','AVAILABLE_WITH_FINDING'))
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings') WITH
            ([DatabaseName] sysname,[ObjectName] nvarchar(512),[FindingCode] varchar(120))
           WHERE [DatabaseName]=@OwnedDb AND [ObjectName]=N'ExampleAnalyzeClrProbe'
             AND [FindingCode]='USER_ASSEMBLY_WHILE_CLR_DISABLED')<>CASE WHEN @ClrBefore=0 THEN 1 ELSE 0 END
        THROW 56865,N'CLR fixture Analyze disabled-state finding mismatch',1;
    IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databaseStatus') WITH
        ([DatabaseId] int,[DatabaseName] sysname,[IsTrustworthyOn] bit,[AssemblyCount] bigint,
         [HighPermissionAssemblyCount] bigint,[ModuleCount] bigint,[SourceFailureCount] int)
        WHERE [DatabaseId]=@OwnedDbId AND [DatabaseName]=@OwnedDb AND [IsTrustworthyOn]=0
          AND [AssemblyCount]=1 AND [HighPermissionAssemblyCount]=0 AND [ModuleCount]=1 AND [SourceFailureCount]=0)
        THROW 56866,N'CLR fixture Analyze database metadata mismatch',1;

    DECLARE @AssemblyMask int,@ModuleMask int,@AssemblyRows int,@ModuleRows int;
    SELECT @AssemblyMask=
          CASE WHEN [DatabaseId]=@OwnedDbId AND [DatabaseName]=@OwnedDb THEN 0 ELSE 1 END
        + CASE WHEN [AssemblyId]=@AssemblyId AND [AssemblyName]=N'ExampleAnalyzeClrProbe' THEN 0 ELSE 2 END
        + CASE WHEN [ClrName]=@ClrName THEN 0 ELSE 4 END
        + CASE WHEN [PermissionSetDesc]=N'SAFE_ACCESS' THEN 0 ELSE 8 END
        + CASE WHEN [TrustVerificationStatus]='NOT_EVALUATED_BINARY_EXCLUDED' THEN 0 ELSE 16 END
        + CASE WHEN [OwnerName] IS NULL THEN 0 ELSE 32 END
    FROM OPENJSON(@Json,N'$.assemblies') WITH
        ([DatabaseId] int,[DatabaseName] sysname,[AssemblyId] int,[AssemblyName] sysname,[ClrName] nvarchar(4000),
         [PermissionSetDesc] nvarchar(60),[TrustVerificationStatus] varchar(40),[OwnerName] sysname);
    SELECT @AssemblyRows=COUNT_BIG(*) FROM OPENJSON(@Json,N'$.assemblies');

    SELECT @ModuleMask=
          CASE WHEN [DatabaseName]=@OwnedDb AND [SchemaName]=N'dbo' AND [ObjectName]=N'ExampleAnalyzeClrValue' THEN 0 ELSE 1 END
        + CASE WHEN [ObjectType]='FS' THEN 0 ELSE 2 END
        + CASE WHEN [AssemblyName]=N'ExampleAnalyzeClrProbe' THEN 0 ELSE 4 END
        + CASE WHEN [AssemblyClass]=@AssemblyClass THEN 0 ELSE 8 END
        + CASE WHEN [AssemblyMethod]=@AssemblyMethod THEN 0 ELSE 16 END
        + CASE WHEN [ExecuteAsPrincipal] IS NULL THEN 0 ELSE 32 END
    FROM OPENJSON(@Json,N'$.assemblyModules') WITH
        ([DatabaseName] sysname,[SchemaName] sysname,[ObjectName] sysname,[ObjectType] char(2),[AssemblyName] sysname,
         [AssemblyClass] sysname,[AssemblyMethod] sysname,[ExecuteAsPrincipal] sysname);
    SELECT @ModuleRows=COUNT_BIG(*) FROM OPENJSON(@Json,N'$.assemblyModules');

    IF @AssemblyRows<>1 OR @ModuleRows<>1 OR ISNULL(@AssemblyMask,-1)<>0 OR ISNULL(@ModuleMask,-1)<>0
    BEGIN
        PRINT CONCAT('WI_CLR_CATALOG_MISMATCH A_ROWS=',@AssemblyRows,' A_MASK=',ISNULL(@AssemblyMask,-1),
            ' M_ROWS=',@ModuleRows,' M_MASK=',ISNULL(@ModuleMask,-1));
        THROW 56867,N'CLR fixture Analyze JSON catalog mismatch',1;
    END;

    EXEC sys.sp_executesql N'
        DECLARE @F nvarchar(max)=(SELECT * FROM [#WIClrProbe_Findings]
            ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);
        IF ISNULL(JSON_QUERY(@J,N''$.findings''),N'''') COLLATE Latin1_General_100_BIN2
            <>COALESCE(@F,N''[]'') COLLATE Latin1_General_100_BIN2
            THROW 56868,N''CLR fixture findings TABLE and JSON differ'',1;',
        N'@J nvarchar(max)',@J=@Json;
    DROP TABLE [#WIClrProbe_Findings];

    IF @ClrBefore=0
    BEGIN
        SET @ClrChangeAttempted=1;
        EXEC sys.sp_configure N'clr enabled',1;
        RECONFIGURE;
    END;
    IF COALESCE((SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr enabled'),-1)<>1
        THROW 56873,N'CLR fixture could not activate its isolated runtime',1;

    DECLARE @Value int,@LoadTime datetime,@AppDomainId int;
    SET @Sql=N'SELECT @Result='+QUOTENAME(@OwnedDb)+N'.dbo.ExampleAnalyzeClrValue();';
    EXEC sys.sp_executesql @Sql,N'@Result int OUTPUT',@Result=@Value OUTPUT;
    IF ISNULL(@Value,-1)<>17
        THROW 56874,N'CLR fixture managed runtime return mismatch',1;

    SELECT TOP(1) @LoadTime=l.load_time,@AppDomainId=d.appdomain_id
    FROM sys.dm_clr_loaded_assemblies AS l
    INNER JOIN sys.dm_clr_appdomains AS d ON d.appdomain_address=l.appdomain_address
    WHERE d.db_id=@OwnedDbId AND l.assembly_id=@AssemblyId
    ORDER BY l.load_time DESC,d.appdomain_id;
    IF @LoadTime IS NULL OR @AppDomainId IS NULL
        THROW 56875,N'CLR fixture native loaded registration unavailable',1;

    EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=@Names,@AssemblyNames=N'[ExampleAnalyzeClrProbe]',
        @MitModulzuordnung=1,@MitBerechtigungsanalyse=0,@SampleSeconds=0,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @@TRANCOUNT<>0 OR DB_ID()<>@OldDbId OR @@SPID<>@OldSpid OR @@OPTIONS<>@OldOptions OR @@LOCK_TIMEOUT<>@OldTimeout
        THROW 56876,N'CLR runtime fixture caller state changed',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR ISNULL(@Status,'') NOT IN('AVAILABLE','AVAILABLE_LIMITED','AVAILABLE_WITH_FINDING')
       OR @Partial IS NULL OR CHARINDEX(CONVERT(varchar(128),@Hash,2),@Json COLLATE Latin1_General_100_CI_AS)>0
        THROW 56877,N'CLR runtime fixture Analyze status or hash exclusion mismatch',1;
    IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.loadedAssemblies') WITH
        ([DatabaseId] int,[DatabaseName] sysname,[AssemblyId] int,[AssemblyName] sysname,
         [AppDomainId] int,[LoadTime] datetime,[MappingStatus] varchar(40))
        WHERE [DatabaseId]=@OwnedDbId AND [DatabaseName]=@OwnedDb AND [AssemblyId]=@AssemblyId
          AND [AssemblyName]=N'ExampleAnalyzeClrProbe' AND [AppDomainId]=@AppDomainId
          AND [LoadTime]=@LoadTime AND [MappingStatus]='CATALOG_MAPPED')
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.appDomains') WITH
        ([DatabaseId] int,[DatabaseName] sysname,[AppDomainId] int)
        WHERE [DatabaseId]=@OwnedDbId AND [DatabaseName]=@OwnedDb AND [AppDomainId]=@AppDomainId)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblies') WITH
        ([DatabaseId] int,[AssemblyId] int,[IsLoaded] bit,[LastVisibleLoadTime] datetime)
        WHERE [DatabaseId]=@OwnedDbId AND [AssemblyId]=@AssemblyId AND [IsLoaded]=1 AND [LastVisibleLoadTime]=@LoadTime)
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH
        ([SourceCode] varchar(80),[StatusCode] varchar(40),[ErrorNumber] int)
        WHERE [SourceCode] IN('CLR_APPDOMAINS','CLR_LOADED_ASSEMBLIES') AND [StatusCode]='AVAILABLE'
          AND [ErrorNumber] IS NULL)<>2
        THROW 56878,N'CLR fixture Analyze loaded mapping mismatch',1;

    DECLARE @NativeMemoryRows int, @NativeCounterRows int;
    SELECT @NativeMemoryRows=COUNT(DISTINCT [type])
    FROM sys.dm_os_memory_clerks
    WHERE [type] IN (N'MEMORYCLERK_SQLCLR',N'MEMORYCLERK_SQLCLRASSEMBLY');
    SELECT @NativeCounterRows=COUNT(*)
    FROM sys.dm_os_performance_counters
    WHERE [object_name] LIKE N'%:CLR%';

    EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=@Names,@AssemblyNames=N'[ExampleAnalyzeClrProbe]',
        @MitModulzuordnung=0,@NurProblematisch=1,@SampleSeconds=0,@MaxZeilen=0,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR @@TRANCOUNT<>0 OR DB_ID()<>@OldDbId OR @@SPID<>@OldSpid
       OR @@OPTIONS<>@OldOptions OR @@LOCK_TIMEOUT<>@OldTimeout
       OR (@NativeMemoryRows<=1 AND @NativeCounterRows<=1)
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.memory'))<>@NativeMemoryRows
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.performanceCounters'))<>@NativeCounterRows
       OR EXISTS (SELECT 1 FROM OPENJSON(@Json,N'$.warnings') WITH ([WarningCode] varchar(120))
                  WHERE [WarningCode]='RESULTSET_TRUNCATED')
       OR EXISTS
       (
           SELECT [r].[key]
           FROM OPENJSON(@Json) AS [r]
           CROSS APPLY OPENJSON([r].[value]) AS [e]
           WHERE [r].[key] IN (N'findings',N'assemblies',N'assemblyModules',N'assemblyDependencies',N'appDomains',
                              N'loadedAssemblies',N'clrTasks',N'activeRequests')
           GROUP BY [r].[key]
           HAVING COUNT(*)>1
       )
        THROW 56879,N'CLR truncation fixture did not isolate memory or counter overflow above one row.',1;

    EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=@Names,@AssemblyNames=N'[ExampleAnalyzeClrProbe]',
        @MitModulzuordnung=0,@NurProblematisch=1,@SampleSeconds=0,@MaxZeilen=1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF COALESCE(ISJSON(@Json),0)<>1 OR @@TRANCOUNT<>0 OR DB_ID()<>@OldDbId OR @@SPID<>@OldSpid
       OR @@OPTIONS<>@OldOptions OR @@LOCK_TIMEOUT<>@OldTimeout
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.memory'))<>CASE WHEN @NativeMemoryRows>0 THEN 1 ELSE 0 END
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.performanceCounters'))<>CASE WHEN @NativeCounterRows>0 THEN 1 ELSE 0 END
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings') WITH ([WarningCode] varchar(120))
           WHERE [WarningCode]='RESULTSET_TRUNCATED')<>1
        THROW 56880,N'CLR fixture exceeded the memory or counter limit without exactly one warning.',1;
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
END CATCH;

IF @Error IS NOT NULL
    PRINT CONCAT('WI_CLR_FIXTURE_SQL_ERROR=',@Error);

BEGIN TRY
    IF @ClrChangeAttempted=1
    BEGIN
        EXEC sys.sp_configure N'clr enabled',@ClrConfiguredBefore;
        RECONFIGURE;
    END;
END TRY
BEGIN CATCH
    SET @ConfigCleanupError=ERROR_NUMBER();
END CATCH;

BEGIN TRY
    IF @OwnedDbId IS NOT NULL
    BEGIN
        IF DB_ID(@OwnedDb) IS NULL OR DB_ID(@OwnedDb)<>@OwnedDbId
            THROW 56869,N'CLR fixture lost owned database binding',1;
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnedDb)+N';';
        EXEC sys.sp_executesql @Sql;
    END;
END TRY
BEGIN CATCH
    SET @DbCleanupError=ERROR_NUMBER();
END CATCH;

BEGIN TRY
    IF @OwnTrust=1
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM sys.trusted_assemblies WHERE [hash]=@Hash AND [description]=N'Example Analyze SAFE metadata fixture')
            THROW 56870,N'CLR fixture lost owned trust binding',1;
        EXEC master.sys.sp_drop_trusted_assembly @hash=@Hash;
    END;
END TRY
BEGIN CATCH
    SET @TrustCleanupError=ERROR_NUMBER();
END CATCH;

IF @ConfigCleanupError IS NOT NULL OR @DbCleanupError IS NOT NULL OR @TrustCleanupError IS NOT NULL
   OR DB_ID(@OwnedDb) IS NOT NULL OR EXISTS(SELECT 1 FROM sys.trusted_assemblies WHERE [hash]=@Hash)
   OR COALESCE((SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr enabled'),-1)<>@ClrBefore
   OR COALESCE((SELECT CONVERT(int,value) FROM sys.configurations WHERE name=N'clr enabled'),-1)<>@ClrConfiguredBefore
   OR COALESCE((SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr strict security'),-1)<>@StrictBefore
   OR COALESCE((SELECT CONVERT(int,value) FROM sys.configurations WHERE name=N'clr strict security'),-1)<>@StrictConfiguredBefore
   OR EXISTS
   (
       SELECT [Id],[Configured],[InUse] FROM @ConfigBefore
       EXCEPT
       SELECT configuration_id,CONVERT(int,value),CONVERT(int,value_in_use) FROM sys.configurations
   )
   OR EXISTS
   (
       SELECT configuration_id,CONVERT(int,value),CONVERT(int,value_in_use) FROM sys.configurations
       EXCEPT
       SELECT [Id],[Configured],[InUse] FROM @ConfigBefore
   )
    THROW 56871,N'CLR fixture owned cleanup or configuration mismatch',1;

IF @Error IS NOT NULL
    THROW 56872,N'CLR fixture failed before acceptance',1;
SELECT 'WI_CLR_SAFE_REGISTRATION_CATALOG=PASS';
GO
