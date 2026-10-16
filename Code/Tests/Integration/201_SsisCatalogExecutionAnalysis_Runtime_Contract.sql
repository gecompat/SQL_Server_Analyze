USE [DeineDatenbank];
GO
/* The owned procedure bounds SET options and export temp-table lifetime.
   The original database and procedure IDs guard both cleanup paths. */
DECLARE @ExampleScopeDatabaseId int=DB_ID(),@ExampleScopeProcId int=NULL;
DECLARE @ExampleOuterOptions int=@@OPTIONS,@ExampleOuterLock int=@@LOCK_TIMEOUT,@ExampleOuterTran int=@@TRANCOUNT;
IF EXISTS (SELECT 1 FROM sys.procedures AS [p] WITH (NOLOCK)
           INNER JOIN sys.schemas AS [s] WITH (NOLOCK) ON [p].[schema_id]=[s].[schema_id]
           WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
             AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisCatalogFixtureScope')
    THROW 56211,N'SSIS_CATALOG_FOREIGN_FIXTURE_SCOPE',1;
BEGIN TRY
    EXEC (N'CREATE PROCEDURE [dbo].[ExampleSsisCatalogFixtureScope] AS BEGIN
DECLARE @ExampleInitialLock int=@@LOCK_TIMEOUT,@ExampleInitialAbort bit=CASE WHEN (16384 & @@OPTIONS)=16384 THEN 1 ELSE 0 END;
DECLARE @ExampleStatus varchar(40),@ExamplePartial bit,@ExampleError int,@ExampleMessage nvarchar(4000),@ExampleJson nvarchar(max);
DECLARE @ExampleMapping nvarchar(max)=N''{"moduleStatus":"#ExampleSsisCatalog_moduleStatus","execution":"#ExampleSsisCatalog_execution","executables":"#ExampleSsisCatalog_executables","messages":"#ExampleSsisCatalog_messages","parameters":"#ExampleSsisCatalog_parameters","phases":"#ExampleSsisCatalog_phases","rowFlow":"#ExampleSsisCatalog_rowFlow","findings":"#ExampleSsisCatalog_findings","sourceStatus":"#ExampleSsisCatalog_sourceStatus","warnings":"#ExampleSsisCatalog_warnings"}'';
CREATE TABLE [#ExampleSsisCatalog_moduleStatus] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_execution] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_executables] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_messages] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_parameters] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_phases] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_rowFlow] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_findings] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_sourceStatus] ([Seed] int NULL);
CREATE TABLE [#ExampleSsisCatalog_warnings] ([Seed] int NULL);

BEGIN TRY
    -- Help precedes invalid TABLE preparation and source access.
    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @Hilfe=1,@ExecutionId=-1,
        @ResultSetArt=''TABLE'',@ResultTablesJson=N''invalid'',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT;
    IF @ExampleJson IS NOT NULL THROW 56200,N''SSIS catalog help produced JSON.'',1;

    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=NULL,@ResultSetArt=''NONE'',
        @JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@StatusCodeOut=@ExampleStatus OUTPUT,
        @IsPartialOut=@ExamplePartial OUTPUT,@ErrorNumberOut=@ExampleError OUTPUT,@ErrorMessageOut=@ExampleMessage OUTPUT;
    IF @ExampleStatus IS NULL OR @ExampleStatus<>''INVALID_PARAMETER'' OR @ExamplePartial IS NULL OR @ExamplePartial<>1
       OR @ExampleError IS NOT NULL OR @ExampleMessage IS NOT NULL
       OR COALESCE(ISJSON(@ExampleJson),0)<>1 OR JSON_VALUE(@ExampleJson,''$.moduleStatus[0].StatusCode'')<>''INVALID_PARAMETER''
        THROW 56201,N''SSIS catalog invalid ID contract failed.'',1;

    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1,@ResultSetArt=''NONE'',
        @ResultTablesJson=N''{}'',@StatusCodeOut=@ExampleStatus OUTPUT,@IsPartialOut=@ExamplePartial OUTPUT;
    IF @ExampleStatus IS NULL OR @ExampleStatus<>''INVALID_PARAMETER'' OR @ExamplePartial IS NULL OR @ExamplePartial<>1
        THROW 56210,N''SSIS catalog accepted TABLE mapping in NONE mode.'',1;

    DECLARE @ExampleCase int=1;
    WHILE @ExampleCase<=5
    BEGIN
        DECLARE @ExampleLimit int=CASE WHEN @ExampleCase=1 THEN -1 ELSE 1 END;
        DECLARE @ExampleDuration int=CASE WHEN @ExampleCase=2 THEN NULL WHEN @ExampleCase=3 THEN 61 ELSE 30 END;
        DECLARE @ExampleLock int=CASE WHEN @ExampleCase=4 THEN NULL WHEN @ExampleCase=5 THEN 60001 ELSE 0 END;
        EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1,@MaxZeilen=@ExampleLimit,
            @MaxDurationSeconds=@ExampleDuration,@LockTimeoutMs=@ExampleLock,@ResultSetArt=''NONE'',
            @StatusCodeOut=@ExampleStatus OUTPUT,@IsPartialOut=@ExamplePartial OUTPUT,
            @ErrorNumberOut=@ExampleError OUTPUT,@ErrorMessageOut=@ExampleMessage OUTPUT;
        IF @ExampleStatus IS NULL OR @ExampleStatus<>''INVALID_PARAMETER'' OR @ExamplePartial IS NULL OR @ExamplePartial<>1
           OR @ExampleError IS NOT NULL OR @ExampleMessage IS NOT NULL
            THROW 56202,N''SSIS catalog bounded parameter validation failed.'',1;
        SET @ExampleCase+=1;
    END;
    BEGIN TRY
        EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''invalid'';
        THROW 56203,N''SSIS catalog accepted invalid TABLE mapping.'',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51011 THROW;
    END CATCH;

    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 137;
    DECLARE @ExampleCallerTran int=@@TRANCOUNT;
    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=9223372036854775807,
        @IncludeMessages=0,@IncludeParameters=0,@IncludePerformance=0,@LockTimeoutMs=0,
        @ResultSetArt=''TABLE'',@ResultTablesJson=@ExampleMapping,@JsonErzeugen=1,@Json=@ExampleJson OUTPUT,
        @StatusCodeOut=@ExampleStatus OUTPUT,@IsPartialOut=@ExamplePartial OUTPUT,
        @ErrorNumberOut=@ExampleError OUTPUT,@ErrorMessageOut=@ExampleMessage OUTPUT;
    IF @@LOCK_TIMEOUT<>137 OR (16384 & @@OPTIONS)<>16384 OR @@TRANCOUNT<>@ExampleCallerTran
        THROW 56204,N''SSIS catalog caller state changed.'',1;
    IF @ExampleStatus IS NULL OR @ExampleStatus NOT IN (''UNAVAILABLE_PLATFORM'',''SOURCE_UNAVAILABLE'',''AVAILABLE_LIMITED'')
       OR @ExamplePartial IS NULL OR @ExamplePartial<>1
        THROW 56205,N''SSIS catalog absent-source status failed.'',1;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_moduleStatus])<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_execution])<>0
       OR (SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_sourceStatus] WHERE [Detail]=N''SOURCE_NOT_REQUESTED'' AND [IsPartial]=0)<>6
        THROW 56206,N''SSIS catalog absent-source TABLE contract failed.'',1;
    IF COALESCE(ISJSON(@ExampleJson),0)<>1
       OR JSON_VALUE(@ExampleJson,''$.moduleStatus[0].SchemaVersion'')<>''1''
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson))<>10
        THROW 56207,N''SSIS catalog ten-array JSON contract failed.'',1;
    IF JSON_QUERY(@ExampleJson,''$.moduleStatus'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.moduleStatus''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_moduleStatus])
        THROW 56208,N''SSIS catalog moduleStatus TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.execution'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.execution''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_execution])
        THROW 56208,N''SSIS catalog execution TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.executables'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.executables''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_executables])
        THROW 56208,N''SSIS catalog executables TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.messages'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.messages''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_messages])
        THROW 56208,N''SSIS catalog messages TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.parameters'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.parameters''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_parameters])
        THROW 56208,N''SSIS catalog parameters TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.phases'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.phases''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_phases])
        THROW 56208,N''SSIS catalog phases TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.rowFlow'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.rowFlow''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_rowFlow])
        THROW 56208,N''SSIS catalog rowFlow TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.findings'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.findings''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_findings])
        THROW 56208,N''SSIS catalog findings TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.sourceStatus'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.sourceStatus''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_sourceStatus])
        THROW 56208,N''SSIS catalog sourceStatus TABLE/JSON row count differs.'',1;
    IF JSON_QUERY(@ExampleJson,''$.warnings'') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@ExampleJson,''$.warnings''))<>(SELECT COUNT_BIG(*) FROM [#ExampleSsisCatalog_warnings])
        THROW 56208,N''SSIS catalog warnings TABLE/JSON row count differs.'',1;
    IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ExampleJson,''$.moduleStatus[0]'') WHERE [key]=N''ErrorNumber'')
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@ExampleJson,''$.moduleStatus[0]'') WHERE [key]=N''ErrorMessage'')
        THROW 56209,N''SSIS catalog JSON omitted NULL fields.'',1;

    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=9223372036854775807,
        @MaxZeilen=2147483647,@ResultSetArt=''RAW'',@PrintMeldungen=0;
    EXEC [monitor].[USP_SsisCatalogExecutionAnalysis] @ExecutionId=9223372036854775807,
        @MaxZeilen=0,@ResultSetArt=''CONSOLE'',@PrintMeldungen=0;
END TRY
BEGIN CATCH
    THROW;
END CATCH;
PRINT N''SSIS catalog absent-source and output contract passed; positive Windows catalog evidence is separate.'';
END;');

    SELECT @ExampleScopeProcId=[p].[object_id] FROM sys.procedures AS [p] WITH (NOLOCK)
    INNER JOIN sys.schemas AS [s] WITH (NOLOCK) ON [p].[schema_id]=[s].[schema_id]
    WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
      AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisCatalogFixtureScope';
    EXEC [dbo].[ExampleSsisCatalogFixtureScope];
    IF @@OPTIONS<>@ExampleOuterOptions OR @@LOCK_TIMEOUT<>@ExampleOuterLock OR @@TRANCOUNT<>@ExampleOuterTran
        THROW 56212,N'SSIS_CATALOG_OUTER_CALLER_CHANGED',1;
    IF DB_ID()<>@ExampleScopeDatabaseId OR @ExampleScopeProcId IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.procedures AS [p] WITH (NOLOCK)
                      INNER JOIN sys.schemas AS [s] WITH (NOLOCK) ON [p].[schema_id]=[s].[schema_id]
                      WHERE [p].[object_id]=@ExampleScopeProcId AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
                        AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisCatalogFixtureScope')
        THROW 56213,N'SSIS_CATALOG_FIXTURE_IDENTITY_CHANGED',1;
    DROP PROCEDURE [dbo].[ExampleSsisCatalogFixtureScope];
END TRY
BEGIN CATCH
    DECLARE @ExampleOriginalError int=ERROR_NUMBER(),@ExampleOriginalMessage nvarchar(4000)=ERROR_MESSAGE();
    RAISERROR(N'SSIS catalog test original error %d: %s',10,1,@ExampleOriginalError,@ExampleOriginalMessage);
    BEGIN TRY
        IF DB_ID()=@ExampleScopeDatabaseId AND @ExampleScopeProcId IS NOT NULL
           AND EXISTS (SELECT 1 FROM sys.procedures AS [p] WITH (NOLOCK)
                       INNER JOIN sys.schemas AS [s] WITH (NOLOCK) ON [p].[schema_id]=[s].[schema_id]
                       WHERE [p].[object_id]=@ExampleScopeProcId AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
                         AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSsisCatalogFixtureScope')
            DROP PROCEDURE [dbo].[ExampleSsisCatalogFixtureScope];
    END TRY
    BEGIN CATCH
        DECLARE @ExampleCleanupMessage nvarchar(4000)=ERROR_MESSAGE();
        RAISERROR(N'SSIS catalog test cleanup error: %s',10,1,@ExampleCleanupMessage);
    END CATCH;
    THROW;
END CATCH;
GO
