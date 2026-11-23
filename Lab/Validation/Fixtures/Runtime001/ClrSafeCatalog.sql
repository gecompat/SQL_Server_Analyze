/*
Zweck: Prüft die Katalogsicht von Analyze an einer eigenen registrierten SAFE-Assembly.
Voraussetzungen: Die GitHub-CI bindet eine eigens erzeugte Assembly und eine
isolierte Linux-Testinstanz. Die Fixture führt die registrierte Funktion nicht aus.
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
DECLARE @OwnedDbId int,@ClrBefore int,@StrictBefore int,@Sql nvarchar(max),@Hash varbinary(64)=HASHBYTES('SHA2_512',@Binary);
DECLARE @OwnTrust bit=0,@Error int,@DbCleanupError int,@TrustCleanupError int;
DECLARE @AssemblyId int,@ClrName nvarchar(4000),@AssemblyClass sysname,@AssemblyMethod sysname;
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@Names nvarchar(max)=QUOTENAME(@OwnedDb);
SELECT @ClrBefore=CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr enabled';
SELECT @StrictBefore=CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr strict security';
IF @ClrBefore IS NULL OR ISNULL(@StrictBefore,0)<>1 OR DB_ID(@OwnedDb) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.trusted_assemblies WHERE [hash]=@Hash)
    THROW 56861,N'CLR fixture requires unused names and strict security',1;

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

    IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.assemblies'))<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.assemblyModules'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblies') WITH
            ([DatabaseId] int,[DatabaseName] sysname,[AssemblyId] int,[AssemblyName] sysname,[ClrName] nvarchar(4000),
             [PermissionSetDesc] nvarchar(60),[TrustVerificationStatus] varchar(40),[OwnerName] sysname)
            WHERE [DatabaseId]=@OwnedDbId AND [DatabaseName]=@OwnedDb AND [AssemblyId]=@AssemblyId
              AND [AssemblyName]=N'ExampleAnalyzeClrProbe' AND [ClrName]=@ClrName AND [PermissionSetDesc]=N'SAFE_ACCESS'
              AND [TrustVerificationStatus]='NOT_EVALUATED_BINARY_EXCLUDED' AND [OwnerName] IS NULL)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.assemblyModules') WITH
            ([DatabaseName] sysname,[SchemaName] sysname,[ObjectName] sysname,[ObjectType] char(2),[AssemblyName] sysname,
             [AssemblyClass] sysname,[AssemblyMethod] sysname,[ExecuteAsPrincipal] sysname)
            WHERE [DatabaseName]=@OwnedDb AND [SchemaName]=N'dbo' AND [ObjectName]=N'ExampleAnalyzeClrValue'
              AND [ObjectType]='FS' AND [AssemblyName]=N'ExampleAnalyzeClrProbe'
              AND [AssemblyClass]=@AssemblyClass AND [AssemblyMethod]=@AssemblyMethod AND [ExecuteAsPrincipal] IS NULL)
        THROW 56867,N'CLR fixture Analyze JSON catalog mismatch',1;

    EXEC sys.sp_executesql N'
        DECLARE @F nvarchar(max)=(SELECT * FROM [#WIClrProbe_Findings]
            ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);
        IF ISNULL(JSON_QUERY(@J,N''$.findings''),N'''') COLLATE Latin1_General_100_BIN2
            <>COALESCE(@F,N''[]'') COLLATE Latin1_General_100_BIN2
            THROW 56868,N''CLR fixture findings TABLE and JSON differ'',1;',
        N'@J nvarchar(max)',@J=@Json;
    DROP TABLE [#WIClrProbe_Findings];
END TRY
BEGIN CATCH
    SET @Error=ERROR_NUMBER();
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
END CATCH;

IF @Error IS NOT NULL
    PRINT CONCAT('WI_CLR_FIXTURE_SQL_ERROR=',@Error);

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

IF @DbCleanupError IS NOT NULL OR @TrustCleanupError IS NOT NULL
   OR DB_ID(@OwnedDb) IS NOT NULL OR EXISTS(SELECT 1 FROM sys.trusted_assemblies WHERE [hash]=@Hash)
   OR COALESCE((SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr enabled'),-1)<>@ClrBefore
   OR COALESCE((SELECT CONVERT(int,value_in_use) FROM sys.configurations WHERE name=N'clr strict security'),-1)<>@StrictBefore
    THROW 56871,N'CLR fixture owned cleanup or configuration mismatch',1;

IF @Error IS NOT NULL
    THROW 56872,N'CLR fixture failed before acceptance',1;
SELECT 'WI_CLR_SAFE_REGISTRATION_CATALOG=PASS';
GO
