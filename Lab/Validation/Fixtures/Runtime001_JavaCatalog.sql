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
