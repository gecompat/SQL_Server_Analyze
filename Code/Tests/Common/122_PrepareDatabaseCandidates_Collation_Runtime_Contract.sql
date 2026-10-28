USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

CREATE TABLE [#PrepareDatabaseCandidates_Runtime]
(
      [DatabaseId] int NOT NULL
    , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsReadOnly] bit NULL
    , [CompatibilityLevel] tinyint NULL
    , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [IsSystemDatabase] bit NULL
    , [RequestedOrdinal] int NULL
);

CREATE TABLE [#PrepareDatabaseCandidates_Warnings]
(
      [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);

-- Die Probe besitzt nur ihren dynamischen SET-Scope; der äußere Caller bleibt erhalten.
DECLARE @OuterEntryLockTimeout int=@@LOCK_TIMEOUT,@OuterEntryTranCount int=@@TRANCOUNT;
EXEC [sys].[sp_executesql] N'
DECLARE @StatusCode varchar(40);
DECLARE @ErrorMessage nvarchar(2048);
DECLARE @CrossDatabaseRequested bit;
DECLARE @DatabaseName sysname = DB_NAME();

SET LOCK_TIMEOUT 0;
EXEC [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames = @DatabaseName
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
    , @CandidateTable = N''#PrepareDatabaseCandidates_Runtime''
    , @WarningTable = N''#PrepareDatabaseCandidates_Warnings''
WITH RESULT SETS NONE;

IF @StatusCode IS NULL OR @StatusCode <> ''AVAILABLE''
   OR @CrossDatabaseRequested IS NULL
   OR @CrossDatabaseRequested <> 0
   OR @@LOCK_TIMEOUT<>0
   OR NOT EXISTS (SELECT 1 FROM [#PrepareDatabaseCandidates_Runtime])
   OR EXISTS (SELECT 1 FROM [#PrepareDatabaseCandidates_Warnings])
    THROW 55710, N''USP_PrepareDatabaseCandidates returned an unexpected runtime contract.'', 1;

DELETE FROM [#PrepareDatabaseCandidates_Runtime];
SET LOCK_TIMEOUT 137;
EXEC [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames = @DatabaseName
    , @StatusCode = @StatusCode OUTPUT
    , @ErrorMessage = @ErrorMessage OUTPUT
    , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
    , @CandidateTable = N''#PrepareDatabaseCandidates_Runtime''
    , @WarningTable = N''#PrepareDatabaseCandidates_Warnings''
WITH RESULT SETS NONE;
IF @StatusCode IS NULL OR @StatusCode<>''AVAILABLE''
   OR @CrossDatabaseRequested IS NULL OR @CrossDatabaseRequested<>0
   OR @@LOCK_TIMEOUT<>137
   OR NOT EXISTS(SELECT 1 FROM [#PrepareDatabaseCandidates_Runtime])
   OR EXISTS(SELECT 1 FROM [#PrepareDatabaseCandidates_Warnings])
    THROW 55711,N''USP_PrepareDatabaseCandidates changed caller state or candidate output.'',1;

IF EXISTS
(
    SELECT 1 FROM [tempdb].[sys].[columns] WITH (NOLOCK)
    WHERE [object_id] IN
        (OBJECT_ID(N''tempdb..#PrepareDatabaseCandidates_Runtime''),OBJECT_ID(N''tempdb..#PrepareDatabaseCandidates_Warnings''))
      AND [name] IN(N''DatabaseName'',N''CollationName'',N''StateDesc'',N''UserAccessDesc'',N''RecoveryModelDesc'',N''RequestedName'',N''StatusCode'',N''ErrorMessage'')
      AND ([collation_name] IS NULL OR [collation_name]<>N''SQL_Latin1_General_CP1_CS_AS'')
)
    THROW 55712,N''USP_PrepareDatabaseCandidates target collation contract mismatch.'',1;
IF (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WITH (NOLOCK)
    WHERE [object_id]=OBJECT_ID(N''tempdb..#PrepareDatabaseCandidates_Runtime''))<>10
 OR (SELECT COUNT(*) FROM [tempdb].[sys].[columns] WITH (NOLOCK)
    WHERE [object_id]=OBJECT_ID(N''tempdb..#PrepareDatabaseCandidates_Warnings''))<>3
    THROW 55713,N''USP_PrepareDatabaseCandidates target schema count mismatch.'',1;
';

-- Both public preparation helpers expose a side-effect-free help path.
DECLARE @HelpEntryLockTimeout int=@@LOCK_TIMEOUT,@HelpEntryTranCount int=@@TRANCOUNT,@HelpEntryOptions int=@@OPTIONS;
EXEC [sys].[sp_executesql] N'
DECLARE @StatusCode varchar(40)=''UNCHANGED_STATUS'';
DECLARE @ErrorMessage nvarchar(2048)=N''UNCHANGED_ERROR'';
DECLARE @CrossDatabaseRequested bit=1;
SET LOCK_TIMEOUT 137;
DECLARE @EntryOptions int=@@OPTIONS,@EntryTranCount int=@@TRANCOUNT;
EXEC [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames=N''bad.name|[DatabaseA]''
    , @SystemdatenbankenEinbeziehen=NULL
    , @DatabaseNamePattern=N''regexi:''
    , @AnalysisClass=''not-a-real-class''
    , @HighImpactConfirmed=NULL
    , @StatusCode=@StatusCode OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT
    , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
    , @CandidateTable=N''##invalid-global-target''
    , @WarningTable=N''not-a-temp-table''
    , @Hilfe=1
WITH RESULT SETS NONE;
IF ISNULL(@StatusCode,'''')<>''UNCHANGED_STATUS''
   OR ISNULL(@ErrorMessage,N'''')<>N''UNCHANGED_ERROR''
   OR ISNULL(@CrossDatabaseRequested,0)<>1
   OR @@OPTIONS<>@EntryOptions
   OR @@LOCK_TIMEOUT<>137 OR @@TRANCOUNT<>@EntryTranCount
    THROW 55715,N''DatabaseCandidates help path performed functional work or changed caller state.'',1;

SET LOCK_TIMEOUT 0;
DECLARE @FilterEntryOptions int=@@OPTIONS,@FilterEntryTranCount int=@@TRANCOUNT;
EXEC [monitor].[USP_PrepareNameFilters]
      @SchemaNames=N''invalid..schema''
    , @FullObjectNames=N''four.part.name.reference''
    , @StatusCode=@StatusCode OUTPUT
    , @ErrorMessage=@ErrorMessage OUTPUT
    , @FilterTable=N''##invalid-global-target''
    , @Hilfe=1
WITH RESULT SETS NONE;
IF ISNULL(@StatusCode,'''')<>''UNCHANGED_STATUS''
   OR ISNULL(@ErrorMessage,N'''')<>N''UNCHANGED_ERROR''
   OR @@OPTIONS<>@FilterEntryOptions
   OR @@LOCK_TIMEOUT<>0 OR @@TRANCOUNT<>@FilterEntryTranCount
    THROW 55716,N''NameFilters help path performed functional work or changed caller state.'',1;
';
IF @@LOCK_TIMEOUT<>@HelpEntryLockTimeout OR @@TRANCOUNT<>@HelpEntryTranCount OR @@OPTIONS<>@HelpEntryOptions
    THROW 55717,N'Preparation helper help probe leaked outer caller state.',1;

IF @@LOCK_TIMEOUT<>@OuterEntryLockTimeout OR @@TRANCOUNT<>@OuterEntryTranCount
    THROW 55714,N'PrepareDatabaseCandidates runtime probe leaked outer caller state.',1;
DROP TABLE [#PrepareDatabaseCandidates_Runtime];
DROP TABLE [#PrepareDatabaseCandidates_Warnings];
PRINT N'PrepareDatabaseCandidates collation and caller runtime contract passed.';
GO
