SET NOCOUNT ON;

DECLARE @ProbeDatabase sysname=N'ExampleExternalRuntimeProbe';
DECLARE @Json nvarchar(max), @Return int, @LockTimeoutBefore int=@@LOCK_TIMEOUT;
DECLARE @ExternalScriptsBefore int=(
    SELECT CONVERT(int,[value_in_use]) FROM sys.configurations WHERE [name]=N'external scripts enabled'
);
IF ISNULL(@ExternalScriptsBefore,0)<>1
    THROW 56971,N'The owned SQL fixture did not enable external scripts.',1;

SELECT @ProbeDatabase COLLATE Latin1_General_100_BIN2 AS [DatabaseName],l.[external_language_id] AS [ExternalLanguageId],
       l.[language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       f.[file_name] COLLATE Latin1_General_100_BIN2 AS [FileName],
       f.[platform_desc] COLLATE Latin1_General_100_BIN2 AS [FilePlatformDesc]
INTO [#ExampleJava_ExpectedLanguages]
FROM [ExampleExternalRuntimeProbe].[sys].[external_languages] AS l
JOIN [ExampleExternalRuntimeProbe].[sys].[external_language_files] AS f
     ON f.[external_language_id]=l.[external_language_id]
WHERE l.[language]=N'Java' AND f.[platform_desc]=N'LINUX' AND f.[file_name] IS NOT NULL;

SELECT @ProbeDatabase COLLATE Latin1_General_100_BIN2 AS [DatabaseName],l.[external_library_id] AS [ExternalLibraryId],
       l.[name] COLLATE Latin1_General_100_BIN2 AS [LibraryName],l.[language] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       l.[scope_desc] COLLATE Latin1_General_100_BIN2 AS [ScopeDesc],
       f.[platform_desc] COLLATE Latin1_General_100_BIN2 AS [FilePlatformDesc]
INTO [#ExampleJava_ExpectedLibraries]
FROM [ExampleExternalRuntimeProbe].[sys].[external_libraries] AS l
JOIN [ExampleExternalRuntimeProbe].[sys].[external_library_files] AS f
     ON f.[external_library_id]=l.[external_library_id]
WHERE l.[language]=N'Java' AND f.[platform_desc]=N'LINUX'
  AND l.[name] IN (N'SqlServerLabJavaSdk',N'SqlServerLabJavaProbe');

IF (SELECT COUNT(*) FROM [#ExampleJava_ExpectedLanguages])<>1
   OR (SELECT COUNT(DISTINCT [LibraryName]) FROM [#ExampleJava_ExpectedLibraries])<>2
   OR (SELECT COUNT(*) FROM [#ExampleJava_ExpectedLibraries])<>2
    THROW 56972,N'The native Java language and two owned library files were not visible.',1;

CREATE TABLE [#ExampleJava_Findings]([Seed] int NULL);
EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=N'[ExampleExternalRuntimeProbe]', @LanguageNames=N'Java',
     @MitDateimetadaten=1, @ResultSetArt='TABLE', @PrintMeldungen=0,
     @ResultTablesJson=N'{"findings":"#ExampleJava_Findings"}',
     @JsonErzeugen=1, @Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1
   OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
   OR ISNULL((SELECT CONVERT(int,[value_in_use]) FROM sys.configurations WHERE [name]=N'external scripts enabled'),-1)<>@ExternalScriptsBefore
    THROW 56973,N'Analyze did not preserve the active Java fixture and caller state.',1;

SELECT [DatabaseName] COLLATE Latin1_General_100_BIN2 AS [DatabaseName],[ExternalLanguageId],
       [LanguageName] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [FileName] COLLATE Latin1_General_100_BIN2 AS [FileName],
       [FilePlatformDesc] COLLATE Latin1_General_100_BIN2 AS [FilePlatformDesc]
INTO [#ExampleJava_JsonLanguages]
FROM OPENJSON(@Json,N'$.languages') WITH
(
    [DatabaseName] sysname,
    [ExternalLanguageId] int,
    [LanguageName] sysname,
    [FileName] sysname,
    [FilePlatformDesc] nvarchar(60)
);
SELECT [DatabaseName] COLLATE Latin1_General_100_BIN2 AS [DatabaseName],[ExternalLibraryId],
       [LibraryName] COLLATE Latin1_General_100_BIN2 AS [LibraryName],
       [LanguageName] COLLATE Latin1_General_100_BIN2 AS [LanguageName],
       [ScopeDesc] COLLATE Latin1_General_100_BIN2 AS [ScopeDesc],
       [FilePlatformDesc] COLLATE Latin1_General_100_BIN2 AS [FilePlatformDesc]
INTO [#ExampleJava_JsonLibraries]
FROM OPENJSON(@Json,N'$.libraries') WITH
(
    [DatabaseName] sysname,
    [ExternalLibraryId] int,
    [LibraryName] sysname,
    [LanguageName] sysname,
    [ScopeDesc] varchar(7),
    [FilePlatformDesc] nvarchar(60)
);

IF (SELECT COUNT(*) FROM [#ExampleJava_JsonLanguages])<>1
   OR EXISTS(SELECT * FROM [#ExampleJava_JsonLanguages] EXCEPT SELECT * FROM [#ExampleJava_ExpectedLanguages])
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.languages') WITH
             ([FileMetadataStatus] varchar(40),[AssessmentStatus] varchar(40))
             WHERE ISNULL([FileMetadataStatus],'')<>'AVAILABLE'
                OR ISNULL([AssessmentStatus],'')<>'REGISTERED_STARTABILITY_UNVERIFIED')
    THROW 56974,N'Analyze Java language metadata differs from the native projection.',1;

IF (SELECT COUNT(*) FROM [#ExampleJava_JsonLibraries])<>2
   OR EXISTS(SELECT * FROM [#ExampleJava_JsonLibraries] EXCEPT SELECT * FROM [#ExampleJava_ExpectedLibraries])
   OR EXISTS(SELECT * FROM [#ExampleJava_ExpectedLibraries] EXCEPT SELECT * FROM [#ExampleJava_JsonLibraries])
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.libraries') WITH
             ([FileMetadataStatus] varchar(40),[AssessmentStatus] varchar(40))
             WHERE ISNULL([FileMetadataStatus],'')<>'AVAILABLE'
                OR ISNULL([AssessmentStatus],'')<>'REGISTERED_STARTABILITY_UNVERIFIED')
    THROW 56975,N'Analyze Java library metadata differs from the native projection.',1;

DECLARE @TableFindings nvarchar(max);
EXEC sys.sp_executesql N'SET @Rows=(SELECT * FROM [#ExampleJava_Findings]
    ORDER BY CASE [Severity] WHEN ''WARN'' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH);',
    N'@Rows nvarchar(max) OUTPUT',@Rows=@TableFindings OUTPUT;
IF ISNULL(JSON_QUERY(@Json,N'$.findings'),N'') COLLATE Latin1_General_100_BIN2
   <> ISNULL(@TableFindings,N'[]') COLLATE Latin1_General_100_BIN2
    THROW 56976,N'Analyze Java findings differ between TABLE and JSON.',1;
GO

-- Die Katalogrechte der eigenen Probe-Datenbank lassen die Server-DMVs gesperrt.
DECLARE @RestrictedName sysname=N'ExampleRuntimeLimited_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');
DECLARE @TransientCredential nvarchar(128)=N'Example!'+CONVERT(nvarchar(36),NEWID());
DECLARE @Sql nvarchar(max),@Failure int=NULL,@Cleanup int=NULL,@Details nvarchar(2048);

IF SUSER_ID(@RestrictedName) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.database_principals WHERE [name]=@RestrictedName)
   OR EXISTS(SELECT 1 FROM [ExampleExternalRuntimeProbe].[sys].[database_principals] WHERE [name]=@RestrictedName)
    THROW 56990,N'The dedicated restricted login unexpectedly exists.',1;

BEGIN TRY
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@RestrictedName)+N' WITH PASSWORD '+N'= '+QUOTENAME(@TransientCredential,'''')+N', CHECK_POLICY=OFF;';
    EXEC sys.sp_executesql @Sql;
    SET @TransientCredential=NULL;
    SET @Sql=N'CREATE USER '+QUOTENAME(@RestrictedName)+N' FOR LOGIN '+QUOTENAME(@RestrictedName)+N';
        GRANT EXECUTE ON [monitor].[USP_ExternalRuntimeAnalysis] TO '+QUOTENAME(@RestrictedName)+N';';
    EXEC sys.sp_executesql @Sql;
    SET @Sql=N'CREATE USER '+QUOTENAME(@RestrictedName)+N' FOR LOGIN '+QUOTENAME(@RestrictedName)+N';
        GRANT VIEW DEFINITION TO '+QUOTENAME(@RestrictedName)+N';';
    EXEC [ExampleExternalRuntimeProbe].[sys].[sp_executesql] @Sql;

    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@RestrictedName,'''')+N';
        BEGIN TRY
            DECLARE @Rows bigint,@RequestError int=NULL,@StatsError int=NULL,@Return int,
                    @Json nvarchar(max),@Status varchar(40),@ModuleError int,@BeforeLock int=@@LOCK_TIMEOUT;
            DECLARE @HasPerformancePermission int=HAS_PERMS_BY_NAME(NULL,NULL,''VIEW SERVER PERFORMANCE STATE'');
            IF @HasPerformancePermission IS NULL
                THROW 56997,N''The native server permission precheck was indeterminate.'',1;
            IF @HasPerformancePermission<>0
                THROW 56991,N''The owned login can read server performance state.'',1;
            BEGIN TRY
                EXEC sys.sp_executesql N''SELECT @Rows=COUNT_BIG(*) FROM sys.dm_external_script_requests;'',
                    N''@Rows bigint OUTPUT'',@Rows=@Rows OUTPUT;
            END TRY
            BEGIN CATCH SET @RequestError=ERROR_NUMBER();END CATCH;
            BEGIN TRY
                EXEC sys.sp_executesql N''SELECT @Rows=COUNT_BIG(*) FROM sys.dm_external_script_execution_stats;'',
                    N''@Rows bigint OUTPUT'',@Rows=@Rows OUTPUT;
            END TRY
            BEGIN CATCH SET @StatsError=ERROR_NUMBER();END CATCH;
            IF ISNULL(@RequestError,0) NOT IN (229,297,300,371,916)
               OR ISNULL(@StatsError,0) NOT IN (229,297,300,371,916)
                THROW 56992,N''The native active-request and execution-stats permission denials were not established.'',1;

            EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
                @DatabaseNames=N''[ExampleExternalRuntimeProbe]'',@LanguageNames=N''Java'',
                @MaxZeilen=0,@ResultSetArt=''NONE'',@PrintMeldungen=0,@JsonErzeugen=1,@Json=@Json OUTPUT,
                @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@ModuleError OUTPUT;
            IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR ISNULL(@Status,'''')<>''AVAILABLE_LIMITED''
               OR @@LOCK_TIMEOUT<>@BeforeLock
               OR ISNULL(JSON_QUERY(@Json,N''$.activeRequests''),N'''')<>N''[]''
               OR ISNULL(JSON_QUERY(@Json,N''$.executionStats''),N'''')<>N''[]''
               OR (SELECT COUNT(DISTINCT [SourceCode]) FROM OPENJSON(@Json,N''$.sourceStatus'')
                   WITH ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint,[ErrorNumber] int)
                   WHERE [StatusCode]=''DENIED_PERMISSION'' AND [IsPartial]=1 AND [RowCount]=0
                     AND (([SourceCode]=''ACTIVE_EXTERNAL_REQUESTS'' AND [ErrorNumber]=@RequestError)
                       OR ([SourceCode]=''EXECUTION_STATS_T1'' AND [ErrorNumber]=@StatsError)))<>2
            BEGIN
                DECLARE @SafeJson nvarchar(max)=CASE WHEN ISJSON(@Json)=1 THEN @Json ELSE N''{}'' END;
                DECLARE @AppliedRequests int,@AppliedStats int,@AppliedRequestError int,@AppliedStatsError int;
                SELECT @AppliedRequests=SUM(CASE WHEN [SourceCode]=''ACTIVE_EXTERNAL_REQUESTS'' AND [StatusCode]=''DENIED_PERMISSION''
                                            AND [IsPartial]=1 AND [RowCount]=0 THEN 1 ELSE 0 END),
                       @AppliedStats=SUM(CASE WHEN [SourceCode]=''EXECUTION_STATS_T1'' AND [StatusCode]=''DENIED_PERMISSION''
                                            AND [IsPartial]=1 AND [RowCount]=0 THEN 1 ELSE 0 END),
                       @AppliedRequestError=MAX(CASE WHEN [SourceCode]=''ACTIVE_EXTERNAL_REQUESTS'' THEN [ErrorNumber] END),
                       @AppliedStatsError=MAX(CASE WHEN [SourceCode]=''EXECUTION_STATS_T1'' THEN [ErrorNumber] END)
                FROM OPENJSON(@SafeJson,N''$.sourceStatus'')
                WITH ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint,[ErrorNumber] int);
                DECLARE @Details nvarchar(2048)=CONCAT(
                    N''ret='',@Return,N''; moduleError='',@ModuleError,N''; json='',ISNULL(ISJSON(@Json),0),
                    N''; limited='',IIF(@Status=''AVAILABLE_LIMITED'',1,0),N''; lock='',IIF(@@LOCK_TIMEOUT=@BeforeLock,1,0),
                    N''; activeEmpty='',IIF(JSON_QUERY(@SafeJson,N''$.activeRequests'')=N''[]'',1,0),
                    N''; statsEmpty='',IIF(JSON_QUERY(@SafeJson,N''$.executionStats'')=N''[]'',1,0),
                    N''; nativeReq='',@RequestError,N''; nativeStats='',@StatsError,
                    N''; reqDenied='',@AppliedRequests,N''; statsDenied='',@AppliedStats,
                    N''; analyzeReq='',@AppliedRequestError,N''; analyzeStats='',@AppliedStatsError);
                THROW 56993,@Details,1;
            END;
            IF (SELECT COUNT(*) FROM OPENJSON(@Json,N''$.languages'')
                WITH ([DatabaseName] sysname,[LanguageName] sysname,[FileMetadataStatus] varchar(40))
                WHERE [DatabaseName]=N''ExampleExternalRuntimeProbe'' AND [LanguageName]=N''Java''
                  AND [FileMetadataStatus]=''NOT_REQUESTED'')<>1
                THROW 56994,N''Visible Java registration was lost after the independent source denials.'',1;
            REVERT;
        END TRY
        BEGIN CATCH REVERT;THROW;END CATCH;';
    EXEC sys.sp_executesql @Sql;
END TRY
BEGIN CATCH
    SET @Failure=ERROR_NUMBER();
    IF @Failure=56993 SET @Details=ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SET @Sql=N'DROP USER IF EXISTS '+QUOTENAME(@RestrictedName)+N';';
    EXEC [ExampleExternalRuntimeProbe].[sys].[sp_executesql] @Sql;
    EXEC sys.sp_executesql @Sql;
    IF SUSER_ID(@RestrictedName) IS NOT NULL
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@RestrictedName)+N';';
        EXEC sys.sp_executesql @Sql;
    END;
END TRY
BEGIN CATCH SET @Cleanup=ERROR_NUMBER();END CATCH;

IF SUSER_ID(@RestrictedName) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.database_principals WHERE [name]=@RestrictedName)
   OR EXISTS(SELECT 1 FROM [ExampleExternalRuntimeProbe].[sys].[database_principals] WHERE [name]=@RestrictedName)
    SET @Cleanup=ISNULL(@Cleanup,56996);

IF @Failure IS NOT NULL OR @Cleanup IS NOT NULL
BEGIN
    DECLARE @FailureSummary nvarchar(2048)=CONCAT(N'Restricted external-runtime fixture failed. Test=',@Failure,N'; cleanup=',@Cleanup,N'; ',@Details);
    THROW 56995,@FailureSummary,1;
END;
GO
