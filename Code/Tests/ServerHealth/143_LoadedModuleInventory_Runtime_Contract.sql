USE [DeineDatenbank];
GO

/*
Primary native SQL Server 2025 / CL170 contract for monitor.USP_LoadedModuleInventory.
A targeted SQL Server 2019 / CL150 FULL_RELEASE is planned for the DMV rights boundary.
Only the current SQL-process DMV is read. No module, driver, CLR assembly or
host file is loaded, created, inspected or modified by this fixture.
*/
SET NOCOUNT ON;
DECLARE @Reader sysname,@FixtureCredential nvarchar(128),@Sql nvarchar(max),
        @LoginCreated bit=0,@UserCreated bit=0,@Impersonating bit=0,
        @OriginalLockTimeout int=@@LOCK_TIMEOUT,
        @OriginalXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @OriginalTransactionCount int=@@TRANCOUNT,
        @CleanupNativeError int,@CaughtNativeNumber int,
        @Return int,@Status varchar(40),@Partial bit,@Error int,
        @Message nvarchar(2048),@Json nvarchar(max),
        @BeforeCount bigint,@AfterCount bigint,@DirectCount bigint,
        @NativeNameType int,@NativeNameMaxLength int,
        @DirectError int,@DirectState varchar(40),
        @ChildStatus varchar(40),@ChildPartial bit,@ChildReturn int,
        @ChildLock int,@ChildAbort bit,@ChildXact int,@ChildTx int;
IF @OriginalTransactionCount<>0 THROW 57501,N'Loaded-module fixture requires no ambient transaction.',1;
SELECT @Reader=N'ExampleLoadedModuleReader_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),12),
       @FixtureCredential=N'Example!'+CONVERT(nvarchar(36),NEWID());
IF SUSER_ID(@Reader) IS NOT NULL OR DATABASE_PRINCIPAL_ID(@Reader) IS NOT NULL
    THROW 57502,N'Owned loaded-module fixture principal collision.',1;

CREATE TABLE [#ExpectedBefore]
(
    [ModuleName] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ModuleBasename] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Debug] bit NULL,[Patched] bit NULL,[Prerelease] bit NULL,
    [PrivateBuild] bit NULL,[SpecialBuild] bit NULL,
    [Language] int NULL
);
SELECT TOP(0) * INTO [#ExpectedAfter] FROM [#ExpectedBefore];
SELECT TOP(0) * INTO [#ExpectedFirst] FROM [#ExpectedBefore];
CREATE TABLE [#Lm_moduleStatus]([Seed] int NULL);
CREATE TABLE [#Lm_loadedModules]([Seed] int NULL);
CREATE TABLE [#Lm_sourceStatus]([Seed] int NULL);
CREATE TABLE [#Lm_warnings]([Seed] int NULL);
CREATE TABLE [#Lm_Flagged]([Seed] int NULL);
CREATE TABLE [#Lm_Limited]([Seed] int NULL);
CREATE TABLE [#Lm_Json]
(
    [ModuleName] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ModuleBasename] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [FileVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ProductVersion] varchar(23) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Debug] bit NULL,[Patched] bit NULL,[Prerelease] bit NULL,
    [PrivateBuild] bit NULL,[SpecialBuild] bit NULL,
    [Language] int NULL
);
BEGIN TRY
    SELECT @NativeNameType=[system_type_id],@NativeNameMaxLength=[max_length]
    FROM [sys].[all_columns] WITH (NOLOCK)
    WHERE [object_id]=OBJECT_ID(N'sys.dm_os_loaded_modules') AND [name]=N'name';
    IF COALESCE(@NativeNameType,-1)<>231 OR COALESCE(@NativeNameMaxLength,-1)<>510
        THROW 57527,N'Native DMV name type exceeds the reviewed nvarchar(255) contract.',1;
    /* Independent literal counterexamples for both separator families and ambiguity. */
    IF EXISTS
    (
        SELECT 1
        FROM
        (
            VALUES (N'C:\Example\alpha.dll',N'alpha.dll'),
                   (N'/opt/example/beta.so',N'beta.so'),
                   (N'plain.dll',N'plain.dll'),
                   (N'C:ambiguous.dll',NULL),
                   (N'/opt/example/',NULL)
        ) AS [v]([RawName],[Expected])
        CROSS APPLY
        (
            SELECT RIGHT([v].[RawName],
                CHARINDEX(N'\',REVERSE(REPLACE([v].[RawName],N'/',N'\'))+N'\')-1)
                AS [Candidate]
        ) AS [b]
        CROSS APPLY
        (
            SELECT CASE WHEN NULLIF(LTRIM(RTRIM([b].[Candidate])),N'') IS NULL
                           OR CHARINDEX(N':',[b].[Candidate])>0
                        THEN NULL ELSE [b].[Candidate] END AS [Actual]
        ) AS [x]
        WHERE ([x].[Actual] IS NULL AND [v].[Expected] IS NOT NULL)
           OR ([x].[Actual] IS NOT NULL AND [v].[Expected] IS NULL)
           OR [x].[Actual] COLLATE Latin1_General_100_BIN2
              <> [v].[Expected] COLLATE Latin1_General_100_BIN2
    ) THROW 57503,N'Basename projection counterexamples failed.',1;

    INSERT [#ExpectedBefore]
        ([ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
         [Prerelease],[PrivateBuild],[SpecialBuild],[Language])
    SELECT [m].[name],CASE WHEN [b].[BaseName] IS NULL
                  OR NULLIF(LTRIM(RTRIM([b].[BaseName])),N'') IS NULL
                  OR CHARINDEX(N':',[b].[BaseName])>0
                THEN NULL ELSE [b].[BaseName] END,
           [m].[file_version],[m].[product_version],[m].[debug],[m].[patched],
           [m].[prerelease],[m].[private_build],[m].[special_build],
           [m].[language]
    FROM [sys].[dm_os_loaded_modules] AS [m] WITH (NOLOCK)
    CROSS APPLY
    (
        SELECT RIGHT([m].[name],
            CHARINDEX(N'\',REVERSE(REPLACE([m].[name],N'/',N'\'))+N'\')-1)
            AS [BaseName]
    ) AS [b];
    SET @BeforeCount=@@ROWCOUNT;
    INSERT [#ExpectedFirst] SELECT TOP(1) * FROM [#ExpectedBefore]
    ORDER BY [ModuleName] COLLATE Latin1_General_100_BIN2,
             [ModuleBasename] COLLATE Latin1_General_100_BIN2,
             [FileVersion] COLLATE Latin1_General_100_BIN2,
             [ProductVersion] COLLATE Latin1_General_100_BIN2,
             [Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language];
    IF COALESCE(@BeforeCount,0)=0 THROW 57504,N'Native loaded-module positive source has zero rows.',1;

    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @NurBuildFlags=0,@MaxZeilen=0,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"moduleStatus":"#Lm_moduleStatus","loadedModules":"#Lm_loadedModules","sourceStatus":"#Lm_sourceStatus","warnings":"#Lm_warnings"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;

    INSERT [#ExpectedAfter]
        ([ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
         [Prerelease],[PrivateBuild],[SpecialBuild],[Language])
    SELECT [m].[name],CASE WHEN [b].[BaseName] IS NULL
                  OR NULLIF(LTRIM(RTRIM([b].[BaseName])),N'') IS NULL
                  OR CHARINDEX(N':',[b].[BaseName])>0
                THEN NULL ELSE [b].[BaseName] END,
           [m].[file_version],[m].[product_version],[m].[debug],[m].[patched],
           [m].[prerelease],[m].[private_build],[m].[special_build],
           [m].[language]
    FROM [sys].[dm_os_loaded_modules] AS [m] WITH (NOLOCK)
    CROSS APPLY
    (
        SELECT RIGHT([m].[name],
            CHARINDEX(N'\',REVERSE(REPLACE([m].[name],N'/',N'\'))+N'\')-1)
            AS [BaseName]
    ) AS [b];
    SET @AfterCount=@@ROWCOUNT;
    IF @AfterCount<>@BeforeCount OR COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'<NULL>')<>'AVAILABLE_LIMITED'
       OR COALESCE(CONVERT(int,@Partial),-1)<>1 OR @Error IS NOT NULL OR @Message IS NOT NULL OR @Json IS NULL
       OR (SELECT COUNT_BIG(*) FROM [#Lm_loadedModules])<>@BeforeCount
       OR (SELECT COUNT_BIG(*) FROM [#Lm_moduleStatus])<>1
       OR (SELECT COUNT_BIG(*) FROM [#Lm_sourceStatus])<>1
       OR NOT EXISTS
         (SELECT 1 FROM [#Lm_sourceStatus]
          WHERE [SourceKey]='SYS_DM_OS_LOADED_MODULES' AND [NativeReadState]='SUCCEEDED'
            AND [StatusCode]='AVAILABLE_LIMITED' AND [ObservedRows]=@BeforeCount
            AND [MatchedRows]=@BeforeCount AND [ReturnedRows]=@BeforeCount
            AND [IsLimited]=0 AND [ErrorNumber] IS NULL AND [ErrorMessage] IS NULL)
        THROW 57505,N'Native positive status or source counts changed.',1;

    /* Bag parity preserves duplicate projected module rows. */
    IF EXISTS
    (
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity]
        FROM [#ExpectedBefore]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
        EXCEPT
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#Lm_loadedModules]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
    )
    OR EXISTS
    (
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#Lm_loadedModules]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
        EXCEPT
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#ExpectedBefore]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
    )
    OR EXISTS
    (
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#ExpectedBefore]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
        EXCEPT
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#ExpectedAfter]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
    )
    OR EXISTS
    (
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#ExpectedAfter]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
        EXCEPT
        SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
               [Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*)
        FROM [#ExpectedBefore]
        GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
                 [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
    ) THROW 57506,N'Native loaded-module bag or pre/post source parity failed.',1;

    IF EXISTS
    (
        SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],
               [name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],
               [precision],[scale],[is_nullable],
               [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM tempdb.sys.columns
        WHERE [object_id]=OBJECT_ID(N'tempdb..#Lm_loadedModules')
        EXCEPT
        SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])),
               [name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],
               [precision],[scale],[is_nullable],
               [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM tempdb.sys.columns
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExpectedBefore')
    )
    OR (SELECT COUNT_BIG(*) FROM tempdb.sys.columns
        WHERE [object_id]=OBJECT_ID(N'tempdb..#Lm_loadedModules'))<>10
        THROW 57507,N'TABLE schema differs from the ten-field native contract.',1;

    IF ISJSON(@Json)<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
           WHERE [key] IN(N'meta',N'moduleStatus',N'loadedModules',N'sourceStatus',N'warnings'))<>5
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json)
                 WHERE [key] IN(N'moduleStatus',N'loadedModules',N'sourceStatus',N'warnings')
                   AND [type]<>4)
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.loadedModules'))<>@BeforeCount
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sourceStatus'))<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json))<>5
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key]=N'meta' AND [type]=5)
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.moduleStatus'))<>1
        THROW 57508,N'JSON root, arrays or cardinality differ.',1;

    INSERT [#Lm_Json]
    SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],
           [Prerelease],[PrivateBuild],[SpecialBuild],[Language]
    FROM OPENJSON(@Json,'$.loadedModules')
    WITH
    (
        [ModuleName] nvarchar(255),[ModuleBasename] nvarchar(255),[FileVersion] varchar(23),[ProductVersion] varchar(23),
        [Debug] bit,[Patched] bit,[Prerelease] bit,[PrivateBuild] bit,
        [SpecialBuild] bit,[Language] int
    );
    IF EXISTS
       (SELECT 1 FROM OPENJSON(@Json,'$.loadedModules') AS [j]
        CROSS APPLY OPENJSON([j].[value]) AS [f]
        WHERE [f].[key] NOT IN(N'ModuleName',N'ModuleBasename',N'FileVersion',N'ProductVersion',N'Debug',N'Patched',N'Prerelease',N'PrivateBuild',N'SpecialBuild',N'Language'))
       OR EXISTS
       (SELECT 1 FROM OPENJSON(@Json,'$.loadedModules') AS [j]
        WHERE (SELECT COUNT_BIG(*) FROM OPENJSON([j].[value]))<>10)
       OR EXISTS
       (SELECT 1 FROM OPENJSON(@Json,'$.loadedModules') AS [j]
        CROSS APPLY OPENJSON([j].[value]) AS [f]
        GROUP BY [j].[key],[f].[key] COLLATE SQL_Latin1_General_CP1_CS_AS
        HAVING COUNT_BIG(*)<>1)
        THROW 57528,N'JSON business keys differ from the ten-field contract.',1;
    IF (SELECT COUNT_BIG(*) FROM [#Lm_Json])<>@BeforeCount
       OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Json]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_loadedModules]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language]) OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_loadedModules]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Json]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language])
        THROW 57509,N'TABLE and typed JSON bag values differ.',1;

    IF EXISTS(SELECT 1 FROM [#Lm_loadedModules]
              WHERE [ModuleBasename] LIKE N'%/%'
                 OR [ModuleBasename] LIKE N'%\%' OR [ModuleBasename] LIKE N'%:%')
       OR EXISTS
          (SELECT 1 FROM OPENJSON(@Json,'$.loadedModules') AS [j]
           CROSS APPLY OPENJSON([j].[value]) AS [f]
           WHERE [f].[key] IN(N'base_address',N'company',N'description',N'PathRedacted'))
        THROW 57510,N'Native basename or ten-field JSON contract changed.',1;

    SET @Json=NULL;SET @Status=NULL;SET @Error=NULL;SET @Message=NULL;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @NurBuildFlags=1,@MaxZeilen=0,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"loadedModules":"#Lm_Flagged"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'<NULL>')<>'AVAILABLE_LIMITED' OR @Error IS NOT NULL
       OR (SELECT COUNT_BIG(*) FROM [#Lm_Flagged])<>
          (SELECT COUNT_BIG(*) FROM [#ExpectedBefore]
           WHERE [Debug]=1 OR [Patched]=1 OR [Prerelease]=1
              OR [PrivateBuild]=1 OR [SpecialBuild]=1)
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].ObservedRows')),-1)<>@BeforeCount
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].MatchedRows')),-1)
          <>(SELECT COUNT_BIG(*) FROM [#Lm_Flagged])
       OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#ExpectedBefore] WHERE [Debug]=1 OR [Patched]=1 OR [Prerelease]=1 OR [PrivateBuild]=1 OR [SpecialBuild]=1 GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Flagged]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language]) OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Flagged]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#ExpectedBefore] WHERE [Debug]=1 OR [Patched]=1 OR [Prerelease]=1 OR [PrivateBuild]=1 OR [SpecialBuild]=1 GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language])
        THROW 57511,N'Native build-flag filter or source work changed.',1;

    SET @Json=NULL;SET @Status=NULL;SET @Error=NULL;SET @Message=NULL;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @NurBuildFlags=0,@MaxZeilen=1,@ResultSetArt='TABLE',
        @ResultTablesJson=N'{"loadedModules":"#Lm_Limited"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status,'<NULL>')<>'AVAILABLE_LIMITED' OR @Error IS NOT NULL
       OR (SELECT COUNT_BIG(*) FROM [#Lm_Limited])<>1
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].ObservedRows')),-1)<>@BeforeCount
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].ReturnedRows')),-1)<>1
       OR COALESCE(JSON_VALUE(@Json,'$.sourceStatus[0].IsLimited'),N'<NULL>')
          <>CASE WHEN @BeforeCount>1 THEN N'true' ELSE N'false' END
       OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#ExpectedFirst]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Limited]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language]) OR EXISTS(SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#Lm_Limited]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language] EXCEPT SELECT [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language],COUNT_BIG(*) AS [Multiplicity] FROM [#ExpectedFirst]  GROUP BY [ModuleName],[ModuleBasename],[FileVersion],[ProductVersion],[Debug],[Patched],[Prerelease],[PrivateBuild],[SpecialBuild],[Language])
        THROW 57512,N'Output limit changed full native source work.',1;

    SET @Json=N'old';SET @Status=NULL;SET @Error=NULL;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @NurBuildFlags=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,
        @Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,-1)<>51011 OR COALESCE(@Status,'<NULL>')<>'INVALID_PARAMETER' OR COALESCE(@Error,-1)<>51011 OR @Json IS NOT NULL
        THROW 57513,N'NULL filter did not fail before source read.',1;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @MaxZeilen=-1,@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,-1)<>51011 OR COALESCE(@Status,'<NULL>')<>'INVALID_PARAMETER' OR COALESCE(@Error,-1)<>51011
        THROW 57514,N'Negative limit did not fail.',1;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @ResultSetArt='TABLE',@ResultTablesJson=N'{"loadedModules":"#MissingOwnedLoadedModuleTarget"}',
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    IF COALESCE(@Return,-1)<>51011 OR COALESCE(@Status,'<NULL>')<>'INVALID_PARAMETER' OR COALESCE(@Error,-1)<>51011
        THROW 57515,N'Invalid TABLE mapping did not fail.',1;

    SET @Sql=N'
        SET XACT_ABORT ON;
        SET LOCK_TIMEOUT 7000;
        DECLARE @ReferenceState int,@ReferenceCount int,@r int,@e int,@s varchar(40),@p bit;
        SET @ReferenceState=XACT_STATE();SET @ReferenceCount=@@TRANCOUNT;
        IF @ReferenceState<>0 OR @ReferenceCount<>0 THROW 57516,N''Reference initial transaction state changed.'',1;
        BEGIN TRAN;
        SET @ReferenceState=XACT_STATE();SET @ReferenceCount=@@TRANCOUNT;
        IF @ReferenceState<>1 OR @ReferenceCount<>1 THROW 57517,N''Reference active transaction state changed.'',1;
        EXEC @r=[monitor].[USP_LoadedModuleInventory]
            @ResultSetArt=''NONE'',@PrintMeldungen=0,
            @StatusCodeOut=@s OUTPUT,@ErrorNumberOut=@e OUTPUT;
        SET @ReferenceState=XACT_STATE();SET @ReferenceCount=@@TRANCOUNT;
        IF COALESCE(@r,-1)<>51011 OR COALESCE(@s,''<NULL>'')<>''INVALID_PARAMETER''
           OR COALESCE(@e,-1)<>51011 OR @ReferenceState<>1 OR @ReferenceCount<>1
            THROW 57525,N''Active caller transaction was not rejected unchanged.'',1;
        EXEC @r=[monitor].[USP_LoadedModuleInventory]
            @Hilfe=1,@ResultSetArt=NULL,@StatusCodeOut=@s OUTPUT,@IsPartialOut=@p OUTPUT;
        SET @ReferenceState=XACT_STATE();SET @ReferenceCount=@@TRANCOUNT;
        IF COALESCE(@r,-1)<>0 OR COALESCE(@s,''<NULL>'')<>''AVAILABLE''
           OR COALESCE(CONVERT(int,@p),-1)<>0 OR @ReferenceState<>1 OR @ReferenceCount<>1
            THROW 57526,N''Help in caller transaction changed state.'',1;
        ROLLBACK;
        SET @ReferenceState=XACT_STATE();SET @ReferenceCount=@@TRANCOUNT;
        IF @ReferenceState<>0 OR @ReferenceCount<>0 THROW 57518,N''Reference rolled-back transaction state changed.'',1;
        EXEC @r=[monitor].[USP_LoadedModuleInventory]
            @NurBuildFlags=0,@MaxZeilen=1,@ResultSetArt=''NONE'',@PrintMeldungen=0,
            @StatusCodeOut=@s OUTPUT,@IsPartialOut=@p OUTPUT;
        SET @ChildXactOut=XACT_STATE();
        SET @ChildTxOut=@@TRANCOUNT;
        SET @ChildLockOut=@@LOCK_TIMEOUT;
        SET @ChildAbortOut=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END;
        IF COALESCE(@r,-1)<>0 OR COALESCE(@s,''<NULL>'')<>''AVAILABLE_LIMITED'' OR COALESCE(CONVERT(int,@p),-1)<>1 OR @ChildXactOut<>0
           OR @ChildTxOut<>0 OR @ChildLockOut<>7000 OR @ChildAbortOut<>1
            THROW 57519,N''Loaded-module child caller state changed.'',1;
        SELECT @ChildReturnOut=@r,@ChildStatusOut=@s,@ChildPartialOut=@p;';
    EXEC [sys].[sp_executesql] @Sql,
        N'@ChildReturnOut int OUTPUT,@ChildStatusOut varchar(40) OUTPUT,@ChildPartialOut bit OUTPUT,
          @ChildLockOut int OUTPUT,@ChildAbortOut bit OUTPUT,@ChildXactOut int OUTPUT,@ChildTxOut int OUTPUT',
        @ChildReturnOut=@ChildReturn OUTPUT,@ChildStatusOut=@ChildStatus OUTPUT,
        @ChildPartialOut=@ChildPartial OUTPUT,@ChildLockOut=@ChildLock OUTPUT,
        @ChildAbortOut=@ChildAbort OUTPUT,@ChildXactOut=@ChildXact OUTPUT,@ChildTxOut=@ChildTx OUTPUT;
    IF COALESCE(@ChildReturn,-1)<>0 OR COALESCE(@ChildStatus,'<NULL>')<>'AVAILABLE_LIMITED' OR COALESCE(CONVERT(int,@ChildPartial),-1)<>1
       OR @@TRANCOUNT<>@OriginalTransactionCount OR @@LOCK_TIMEOUT<>@OriginalLockTimeout
       OR CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END<>@OriginalXactAbort
        THROW 57520,N'Outer caller state changed after typed child batch.',1;

    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)+N' WITH PASS'+N'WORD='
             +QUOTENAME(@FixtureCredential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @UserCreated=1;
    SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_LoadedModuleInventory] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    BEGIN TRY
        SELECT @DirectCount=COUNT_BIG(*) FROM [sys].[dm_os_loaded_modules] WITH (NOLOCK);
        SET @DirectState='AVAILABLE';
    END TRY
    BEGIN CATCH
        SET @DirectError=ERROR_NUMBER();
        IF @DirectError NOT IN(229,262,297,300,371,916)
        BEGIN
            RAISERROR(N'Unexpected restricted DMV probe native number: %d',10,1,@DirectError) WITH NOWAIT;
            THROW 57529,N'Unexpected restricted DMV probe failure.',1;
        END;
        SET @DirectState='DENIED_PERMISSION';
        SET @DirectCount=NULL;
    END CATCH;
    SET @Json=NULL;SET @Status=NULL;SET @Error=NULL;SET @Message=NULL;
    EXEC @Return=[monitor].[USP_LoadedModuleInventory]
        @MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,
        @ErrorMessageOut=@Message OUTPUT;
    IF COALESCE(@Return,-1)<>0 OR @Json IS NULL OR ISJSON(@Json)<>1
        THROW 57521,N'Restricted caller status was not returned.',1;
    IF COALESCE(@DirectState,'<NULL>')='DENIED_PERMISSION'
    BEGIN
        IF COALESCE(@Status,'<NULL>')<>'DENIED_PERMISSION' OR COALESCE(@Error,-1)<>COALESCE(@DirectError,-2)
           OR @Message IS NULL
           OR COALESCE(JSON_VALUE(@Json,'$.sourceStatus[0].NativeReadState'),N'<NULL>')<>'FAILED'
           OR JSON_VALUE(@Json,'$.sourceStatus[0].ObservedRows') IS NOT NULL
           OR JSON_VALUE(@Json,'$.sourceStatus[0].MatchedRows') IS NOT NULL
           OR JSON_VALUE(@Json,'$.sourceStatus[0].ReturnedRows') IS NOT NULL
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.loadedModules'))<>0
            THROW 57522,N'Genuine restricted DMV denial was not preserved.',1;
    END
    ELSE
    BEGIN
        IF COALESCE(@Status,'<NULL>')<>CASE WHEN @DirectCount=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END
           OR @Error IS NOT NULL
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].ObservedRows')),-1)<>@DirectCount
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].MatchedRows')),-1)<>@DirectCount
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.sourceStatus[0].ReturnedRows')),-1)<>@DirectCount
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.loadedModules'))<>@DirectCount
            THROW 57523,N'Granted restricted DMV read was misclassified.',1;
    END;
    REVERT;
    SET @Impersonating=0;

    SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @UserCreated=0;
    SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=0;
    IF @@TRANCOUNT<>@OriginalTransactionCount OR @@LOCK_TIMEOUT<>@OriginalLockTimeout
       OR CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END<>@OriginalXactAbort
        THROW 57524,N'Final caller state changed.',1;
END TRY
BEGIN CATCH
    SET @CaughtNativeNumber=ERROR_NUMBER();
    IF @@TRANCOUNT>@OriginalTransactionCount
    BEGIN TRY ROLLBACK; END TRY
    BEGIN CATCH
        SET @CleanupNativeError=ERROR_NUMBER();
        RAISERROR(N'Owned loaded-module fixture cleanup rollback failed: %d',10,1,@CleanupNativeError) WITH NOWAIT;
    END CATCH;
    IF @Impersonating=1
    BEGIN TRY REVERT; SET @Impersonating=0; END TRY
    BEGIN CATCH
        SET @CleanupNativeError=ERROR_NUMBER();
        RAISERROR(N'Owned loaded-module fixture cleanup REVERT failed: %d',10,1,@CleanupNativeError) WITH NOWAIT;
    END CATCH;
    IF @UserCreated=1
    BEGIN TRY
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
        SET @UserCreated=0;
    END TRY
    BEGIN CATCH
        SET @CleanupNativeError=ERROR_NUMBER();
        RAISERROR(N'Owned loaded-module fixture cleanup user failed: %d',10,1,@CleanupNativeError) WITH NOWAIT;
    END CATCH;
    IF @LoginCreated=1
    BEGIN TRY
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
        EXEC [sys].[sp_executesql] @Sql;
        SET @LoginCreated=0;
    END TRY
    BEGIN CATCH
        SET @CleanupNativeError=ERROR_NUMBER();
        RAISERROR(N'Owned loaded-module fixture cleanup login failed: %d',10,1,@CleanupNativeError) WITH NOWAIT;
    END CATCH;
    IF @CaughtNativeNumber BETWEEN 57501 AND 57529 THROW;
    RAISERROR(N'Unexpected loaded-module fixture native number: %d',10,1,@CaughtNativeNumber) WITH NOWAIT;
    THROW 57530,N'Unexpected native loaded-module fixture failure.',1;
END CATCH;
GO
