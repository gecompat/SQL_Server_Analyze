USE [DeineDatenbank];
GO
/*
Datei: 128_WI0009_External_Data_Runtime_Contract.sql
Zweck: Prüft den unveränderten Analyzer an eigenen leeren nativen Katalogen.
Grenzen: Keine External-Table-Anlage, Remoteabfrage oder positive Katalogbehauptung.
*/
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR @@LOCK_TIMEOUT<>-1 OR (@@OPTIONS&16384)<>0
    THROW 56980,N'External-data fixture requires a clean caller',1;
DECLARE @OwnDb sysname=N'ExampleExternalData_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @OwnId int=NULL,@Created bit=0,@CallerDb int=DB_ID(),@CallerSid int=@@SPID,
    @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),@Sql nvarchar(max),
    @Json nvarchar(max),@Status varchar(40),@Partial bit,@Physical nvarchar(max),@Case int=0,
    @Mapping nvarchar(max)=N'{"moduleStatus":"#128_WI9_moduleStatus","databaseStatus":"#128_WI9_databaseStatus","dataSources":"#128_WI9_dataSources","fileFormats":"#128_WI9_fileFormats","externalTables":"#128_WI9_externalTables","modelSummary":"#128_WI9_modelSummary","sourceStatus":"#128_WI9_sourceStatus","warnings":"#128_WI9_warnings"}',@Selection nvarchar(max),@Limit int,@OriginalError nvarchar(2048);
IF OBJECT_ID(N'tempdb..#128_WI9_moduleStatus') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_databaseStatus') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_dataSources') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_fileFormats') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_externalTables') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_modelSummary') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_sourceStatus') IS NOT NULL OR OBJECT_ID(N'tempdb..#128_WI9_warnings') IS NOT NULL
    THROW 56988,N'External-data fixture requires absent caller temp targets',1;
BEGIN TRY
    IF DB_ID(@OwnDb) IS NOT NULL THROW 56981,N'Own external-data database collision',1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@OwnDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC sys.sp_executesql @Sql;
    SELECT @Created=1,@OwnId=DB_ID(@OwnDb),@Selection=QUOTENAME(@OwnDb);
    IF @OwnId IS NULL OR @OwnId<=0 THROW 56982,N'Own external-data database binding',1;
    SELECT N'OWN_NATIVE_EMPTY_DATABASE' EvidenceKind,@OwnId OwnedDatabaseId;
    SET LOCK_TIMEOUT 137;
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;
    WHILE @Case<4
    BEGIN
        SET @Limit=CASE @Case WHEN 0 THEN NULL WHEN 1 THEN 0 WHEN 2 THEN 1 ELSE 2000 END;
        CREATE TABLE [#128_WI9_moduleStatus]([Seed] bit NULL);
CREATE TABLE [#128_WI9_databaseStatus]([Seed] bit NULL);
CREATE TABLE [#128_WI9_dataSources]([Seed] bit NULL);
CREATE TABLE [#128_WI9_fileFormats]([Seed] bit NULL);
CREATE TABLE [#128_WI9_externalTables]([Seed] bit NULL);
CREATE TABLE [#128_WI9_modelSummary]([Seed] bit NULL);
CREATE TABLE [#128_WI9_sourceStatus]([Seed] bit NULL);
CREATE TABLE [#128_WI9_warnings]([Seed] bit NULL);
        EXEC monitor.USP_ExternalDataAnalysis @DatabaseNames=@Selection,@MaxZeilen=@Limit,
            @ResultSetArt='TABLE',@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        SELECT N'ORIGINAL_NATIVE_EMPTY' EvidenceKind,@Case CaseOrdinal,@Json JsonOutput;
        EXEC sys.sp_executesql N'IF COALESCE(@Status,'''')<>''AVAILABLE'' OR COALESCE(CONVERT(int,@Partial),-1)<>0 OR COALESCE(ISJSON(@Json),0)<>1
            OR COALESCE(JSON_VALUE(@Json,N''$.meta.schemaVersion''),N'''')<>N''1''
            OR (SELECT COUNT_BIG(*) FROM [#128_WI9_databaseStatus])<>1
            OR EXISTS(SELECT 1 FROM [#128_WI9_databaseStatus] WHERE DatabaseName IS NULL OR DatabaseName<>@OwnDb OR IsPartial IS NULL OR IsPartial<>0 OR StatusCode IS NULL OR StatusCode<>''AVAILABLE''
                OR DataSourceCount IS NULL OR DataSourceCount<>0 OR FileFormatCount IS NULL OR FileFormatCount<>0 OR ExternalTableCount IS NULL OR ExternalTableCount<>0
                OR (@Major>=17 AND (ExternalModelCount IS NULL OR ExternalModelCount<>0))
                OR (@Major<17 AND ExternalModelCount IS NOT NULL) OR ErrorNumber IS NOT NULL OR ErrorMessage IS NOT NULL)
            OR EXISTS(SELECT 1 FROM [#128_WI9_dataSources]) OR EXISTS(SELECT 1 FROM [#128_WI9_fileFormats])
            OR EXISTS(SELECT 1 FROM [#128_WI9_externalTables]) OR EXISTS(SELECT 1 FROM [#128_WI9_warnings])
            OR (SELECT COUNT_BIG(*) FROM [#128_WI9_sourceStatus])<>CASE WHEN @Limit=1 THEN 1 ELSE 6 END
            OR EXISTS(SELECT 1 FROM [#128_WI9_sourceStatus] WHERE DatabaseName IS NULL OR DatabaseName<>@OwnDb OR SourceStatus IS NULL OR ErrorNumber IS NOT NULL OR ErrorMessage IS NOT NULL
                OR SourceStatus<>CASE WHEN SourceName=N''sys.external_models'' AND @Major<17 THEN ''UNAVAILABLE_VERSION'' ELSE ''AVAILABLE'' END)
            OR (SELECT COUNT_BIG(*) FROM [#128_WI9_modelSummary])<>1
            OR EXISTS(SELECT 1 FROM [#128_WI9_modelSummary] WHERE DatabaseName IS NULL OR DatabaseName<>@OwnDb OR SourceStatus IS NULL
                OR SourceStatus<>CASE WHEN @Major<17 THEN ''UNAVAILABLE_VERSION'' ELSE ''AVAILABLE'' END
                OR (@Major>=17 AND (VisibleModelCount IS NULL OR VisibleModelCount<>0)) OR (@Major<17 AND VisibleModelCount IS NOT NULL))
            THROW 56983,N''Native empty-catalog or version contract mismatch'',1;',
            N'@Status varchar(40),@Partial bit,@Json nvarchar(max),@OwnDb sysname,@Major int,@Limit int',
            @Status=@Status,@Partial=@Partial,@Json=@Json,@OwnDb=@OwnDb,@Major=@Major,@Limit=@Limit;
        IF @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0 OR @@SPID<>@CallerSid OR DB_ID()<>@CallerDb
            THROW 56984,N'External-data caller state mismatch',1;
        EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_moduleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'moduleStatus' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.moduleStatus') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.moduleStatus') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_databaseStatus] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'databaseStatus' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.databaseStatus') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.databaseStatus') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_dataSources] ORDER BY [DatabaseName],[DataSourceId] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'dataSources' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.dataSources') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.dataSources') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_fileFormats] ORDER BY [DatabaseName],[FileFormatId] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'fileFormats' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.fileFormats') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.fileFormats') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_externalTables] ORDER BY [DatabaseName],[ObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'externalTables' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.externalTables') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.externalTables') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_modelSummary] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'modelSummary' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.modelSummary') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.modelSummary') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_sourceStatus] ORDER BY [DatabaseName],[SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'sourceStatus' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.sourceStatus') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.sourceStatus') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
EXEC sys.sp_executesql N'SELECT @p=(SELECT * FROM [#128_WI9_warnings] ORDER BY [DatabaseName],[WarningCode],[Detail] FOR JSON PATH,INCLUDE_NULL_VALUES);',N'@p nvarchar(max) OUTPUT',@p=@Physical OUTPUT;
        SELECT N'PHYSICAL_BEFORE_ASSERTION' EvidenceKind,@Case CaseOrdinal,N'warnings' ResultName,@Physical PhysicalJson;
        IF JSON_QUERY(@Json,N'$.warnings') IS NULL OR COALESCE(@Physical,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>JSON_QUERY(@Json,N'$.warnings') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56985,N'External-data physical JSON parity mismatch',1;
DROP TABLE IF EXISTS [#128_WI9_moduleStatus];
DROP TABLE IF EXISTS [#128_WI9_databaseStatus];
DROP TABLE IF EXISTS [#128_WI9_dataSources];
DROP TABLE IF EXISTS [#128_WI9_fileFormats];
DROP TABLE IF EXISTS [#128_WI9_externalTables];
DROP TABLE IF EXISTS [#128_WI9_modelSummary];
DROP TABLE IF EXISTS [#128_WI9_sourceStatus];
DROP TABLE IF EXISTS [#128_WI9_warnings];
        SET @Case+=1;
    END;
    ROLLBACK TRANSACTION;
    SET XACT_ABORT OFF;
    SET LOCK_TIMEOUT -1;
    IF DB_ID(@OwnDb)<>@OwnId OR DB_ID(@OwnDb) IS NULL THROW 56986,N'Own external-data cleanup binding',1;
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@OwnDb)+N';';EXEC sys.sp_executesql @Sql;
    IF DB_ID(@OwnDb) IS NOT NULL THROW 56987,N'Own external-data database remains',1;
    SELECT N'OWN_NATIVE_EMPTY_CLEANUP' EvidenceKind,DB_ID(@OwnDb) RemainingDatabaseId,@@SPID CallerSid,@@TRANCOUNT TranCount,@@LOCK_TIMEOUT LockTimeout;
    DROP TABLE IF EXISTS [#128_WI9_moduleStatus];
DROP TABLE IF EXISTS [#128_WI9_databaseStatus];
DROP TABLE IF EXISTS [#128_WI9_dataSources];
DROP TABLE IF EXISTS [#128_WI9_fileFormats];
DROP TABLE IF EXISTS [#128_WI9_externalTables];
DROP TABLE IF EXISTS [#128_WI9_modelSummary];
DROP TABLE IF EXISTS [#128_WI9_sourceStatus];
DROP TABLE IF EXISTS [#128_WI9_warnings];
END TRY
BEGIN CATCH
    SET @OriginalError=ERROR_MESSAGE();
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    SET XACT_ABORT OFF;
    SET LOCK_TIMEOUT -1;
    BEGIN TRY
        IF @Created=1 AND @OwnId IS NOT NULL AND DB_ID(@OwnDb)=@OwnId
        BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@OwnDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@OwnDb)+N';';EXEC sys.sp_executesql @Sql;END;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_EXTERNAL_DATA_CLEANUP_FAILURE' EvidenceKind,ERROR_NUMBER() CleanupErrorNumber;
    END CATCH;
    DROP TABLE IF EXISTS [#128_WI9_moduleStatus];
DROP TABLE IF EXISTS [#128_WI9_databaseStatus];
DROP TABLE IF EXISTS [#128_WI9_dataSources];
DROP TABLE IF EXISTS [#128_WI9_fileFormats];
DROP TABLE IF EXISTS [#128_WI9_externalTables];
DROP TABLE IF EXISTS [#128_WI9_modelSummary];
DROP TABLE IF EXISTS [#128_WI9_sourceStatus];
DROP TABLE IF EXISTS [#128_WI9_warnings];
    THROW;
END CATCH;
GO
