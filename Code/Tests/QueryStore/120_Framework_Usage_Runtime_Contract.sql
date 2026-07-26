USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 120_Framework_Usage_Runtime_Contract.sql
Zweck        : Prüft den vollständigen FRAMEWORK-USAGE-001-Vertrag auf dem
               installierten SQL Server 2019, 2022 oder 2025.
Nebenwirkung : Erzeugt ausschließlich eine synthetische monitor-Procedure in der
               Testdatenbank, führt sie aus und entfernt sie im Erfolgs- und
               Fehlerpfad. Query-Store-Konfiguration und Daten werden nicht
               geändert oder bereinigt.
===============================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @ActualState smallint=
(
    SELECT TOP(1) TRY_CONVERT(smallint,[actual_state])
    FROM [sys].[database_query_store_options] WITH (NOLOCK)
);
DECLARE @Json nvarchar(max)=NULL;
DECLARE @StatusCode varchar(40)=NULL;
DECLARE @IsPartial bit=NULL;
DECLARE @ErrorNumber int=NULL;
DECLARE @ErrorMessage nvarchar(2048)=NULL;

BEGIN TRY
    EXEC [monitor].[USP_FrameworkUsageFromQueryStore] @Hilfe=1;

    SET LOCK_TIMEOUT 731;
    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @MaxZeilen=-1
        , @ResultSetArt='NONE'
        , @PrintMeldungen=0
        , @StatusCodeOut=@StatusCode OUTPUT
        , @IsPartialOut=@IsPartial OUTPUT
        , @ErrorNumberOut=@ErrorNumber OUTPUT
        , @ErrorMessageOut=@ErrorMessage OUTPUT;

    IF @StatusCode<>'INVALID_PARAMETER'
        THROW 51000,N'FRAMEWORK_USAGE_INVALID_PARAMETER_STATUS',1;
    IF @@LOCK_TIMEOUT<>731
        THROW 51000,N'FRAMEWORK_USAGE_LOCK_TIMEOUT_INVALID_PATH',1;

    SET @StatusCode=NULL;
    SET @IsPartial=NULL;
    SET @ErrorNumber=NULL;
    SET @ErrorMessage=NULL;

    IF @ActualState=2
    BEGIN
        EXEC(N'
CREATE OR ALTER PROCEDURE [monitor].[USP_FrameworkUsageSyntheticProbe]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SyntheticObjectCount bigint;
    SELECT @SyntheticObjectCount=COUNT_BIG(*)
    FROM [sys].[objects] WITH (NOLOCK);
END;');

        DECLARE @ProbeIteration int=0;
        WHILE @ProbeIteration<20
        BEGIN
            EXEC [monitor].[USP_FrameworkUsageSyntheticProbe];
            SET @ProbeIteration+=1;
        END;
        EXEC [sys].[sp_query_store_flush_db];
    END;

    CREATE TABLE [#FrameworkUsageContract_ModuleStatus]([Seed] bit NULL);
    CREATE TABLE [#FrameworkUsageContract_Usage]([Seed] bit NULL);
    CREATE TABLE [#FrameworkUsageContract_SourceStatus]([Seed] bit NULL);
    CREATE TABLE [#FrameworkUsageContract_Warnings]([Seed] bit NULL);

    DECLARE @ResultTablesJson nvarchar(max)=N'{
      "moduleStatus":"#FrameworkUsageContract_ModuleStatus",
      "usage":"#FrameworkUsageContract_Usage",
      "sourceStatus":"#FrameworkUsageContract_SourceStatus",
      "warnings":"#FrameworkUsageContract_Warnings"
    }';

    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @MaxZeilen=0
        , @MinAusfuehrungen=1
        , @ZeitraumTage=0
        , @LockTimeoutMs=0
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=@ResultTablesJson
        , @JsonErzeugen=1
        , @Json=@Json OUTPUT
        , @PrintMeldungen=0
        , @StatusCodeOut=@StatusCode OUTPUT
        , @IsPartialOut=@IsPartial OUTPUT
        , @ErrorNumberOut=@ErrorNumber OUTPUT
        , @ErrorMessageOut=@ErrorMessage OUTPUT;

    IF @@LOCK_TIMEOUT<>731
        THROW 51000,N'FRAMEWORK_USAGE_LOCK_TIMEOUT_TABLE_PATH',1;
    IF ISJSON(@Json)<>1
        THROW 51000,N'FRAMEWORK_USAGE_JSON_INVALID',1;
    IF JSON_QUERY(@Json,N'$.usage') IS NULL
       OR JSON_QUERY(@Json,N'$.sourceStatus') IS NULL
       OR JSON_QUERY(@Json,N'$.warnings') IS NULL
        THROW 51000,N'FRAMEWORK_USAGE_JSON_ARRAY_CONTRACT',1;

    EXEC [sys].[sp_executesql] N'
IF NOT EXISTS(SELECT 1 FROM [#FrameworkUsageContract_ModuleStatus])
    THROW 51000,N''FRAMEWORK_USAGE_MODULE_STATUS_EMPTY'',1;
IF NOT EXISTS(SELECT 1 FROM [#FrameworkUsageContract_SourceStatus])
    THROW 51000,N''FRAMEWORK_USAGE_SOURCE_STATUS_EMPTY'',1;
IF NOT EXISTS
(
    SELECT 1
    FROM [#FrameworkUsageContract_ModuleStatus]
    WHERE [ModuleName]=N''USP_FrameworkUsageFromQueryStore''
      AND [StatusCode] IN(''AVAILABLE'',''AVAILABLE_EMPTY'',''UNAVAILABLE_FEATURE'')
)
    THROW 51000,N''FRAMEWORK_USAGE_MODULE_STATUS_CONTRACT'',1;
';

    IF @ActualState=2
    BEGIN
        EXEC [sys].[sp_executesql] N'
IF NOT EXISTS
(
    SELECT 1
    FROM [#FrameworkUsageContract_Usage]
    WHERE [ProcedureName]=N''USP_FrameworkUsageSyntheticProbe''
      AND [ExecutionCount]>=1
)
    THROW 51000,N''FRAMEWORK_USAGE_POSITIVE_EVIDENCE_MISSING'',1;
';
    END;

    SET @Json=N'not-cleared';
    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @MaxZeilen=1
        , @ResultSetArt='NONE'
        , @JsonErzeugen=0
        , @Json=@Json OUTPUT
        , @PrintMeldungen=0
        , @StatusCodeOut=@StatusCode OUTPUT;
    IF @Json IS NOT NULL
        THROW 51000,N'FRAMEWORK_USAGE_JSON_NOT_CLEARED',1;
    IF @@LOCK_TIMEOUT<>731
        THROW 51000,N'FRAMEWORK_USAGE_LOCK_TIMEOUT_NONE_PATH',1;

    EXEC [monitor].[USP_FrameworkUsageFromQueryStore]
          @MaxZeilen=1
        , @ResultSetArt='RAW'
        , @PrintMeldungen=0;

    IF @ActualState=2
        EXEC(N'DROP PROCEDURE IF EXISTS [monitor].[USP_FrameworkUsageSyntheticProbe];');

    DECLARE @SuccessRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @SuccessRestoreSql;
    RAISERROR(N'FRAMEWORK_USAGE_RUNTIME_CONTRACT PASS',10,1) WITH NOWAIT;
END TRY
BEGIN CATCH
    BEGIN TRY
        EXEC(N'DROP PROCEDURE IF EXISTS [monitor].[USP_FrameworkUsageSyntheticProbe];');
    END TRY
    BEGIN CATCH
    END CATCH;

    DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSql;
    THROW;
END CATCH;
GO
