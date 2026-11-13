USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57500,N'Sensitivity summary contract requires the isolated remote CI sysadmin target without an ambient transaction.',1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 57501,N'Sensitivity summary contract requires the selected SQL Server 2025 native CI target.',1;
GO
DECLARE @Suffix nvarchar(48)=CONVERT(nvarchar(12),@@SPID)+N'_'+LEFT(REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),16),
        @PositiveDb sysname,@EmptyDb sysname,@Reader sysname,@Password nvarchar(128),
        @Sql nvarchar(max),@Names nvarchar(max),@Json nvarchar(max),@TableJson nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
        @ExpectedTables bigint,@ExpectedColumns bigint,@ExpectedClassified bigint,
        @OriginalLock int=@@LOCK_TIMEOUT,
        @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @OriginalTx int=@@TRANCOUNT,@Impersonating bit=0,@LoginCreated bit=0,
        @InstallUserCreated bit=0,@PositiveDbCreated bit=0,@EmptyDbCreated bit=0,
        @CleanupFailure nvarchar(2048)=NULL;
SELECT @PositiveDb=N'ExampleClassificationPos_'+@Suffix,
       @EmptyDb=N'ExampleClassificationEmpty_'+@Suffix,
       @Reader=N'ExampleClassificationReader_'+@Suffix,
       @Password=N'Example!'+CONVERT(nvarchar(36),NEWID());
IF DB_ID(@PositiveDb) IS NOT NULL OR DB_ID(@EmptyDb) IS NOT NULL
   OR EXISTS(SELECT 1 FROM sys.server_principals WHERE [name]=@Reader)
    THROW 57502,N'Sensitivity summary owned fixture name collision.',1;
CREATE TABLE #SensitivityOut_moduleStatus([Seed] int NULL);
CREATE TABLE #SensitivityOut_classificationSummary([Seed] int NULL);
CREATE TABLE #SensitivityOut_sourceStatus([Seed] int NULL);
CREATE TABLE #SensitivityOut_warnings([Seed] int NULL);
        CREATE TABLE [#SensitivityExpected_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#SensitivityExpected_classificationSummary]
        (
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibleTableCount] bigint NULL,
            [VisibleTableColumnCount] bigint NULL,
            [ClassifiedVisibleTableColumnCount] bigint NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#SensitivityExpected_sourceStatus]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [StartedAtUtc] datetime2(3) NOT NULL,
            [CompletedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ObservedRows] bigint NULL,
            [ReturnedRows] bigint NULL,
            [IsLimited] bit NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#SensitivityExpected_warnings]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
CREATE TABLE #SensitivityPhysicalPairs([ActualTable] sysname NOT NULL,[ExpectedTable] sysname NOT NULL);
INSERT #SensitivityPhysicalPairs VALUES
(N'#SensitivityOut_moduleStatus',N'#SensitivityExpected_moduleStatus'),
(N'#SensitivityOut_classificationSummary',N'#SensitivityExpected_classificationSummary'),
(N'#SensitivityOut_sourceStatus',N'#SensitivityExpected_sourceStatus'),
(N'#SensitivityOut_warnings',N'#SensitivityExpected_warnings');
DECLARE @Map nvarchar(max)=N'{"moduleStatus":"#SensitivityOut_moduleStatus","classificationSummary":"#SensitivityOut_classificationSummary","sourceStatus":"#SensitivityOut_sourceStatus","warnings":"#SensitivityOut_warnings"}';
BEGIN TRY
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@PositiveDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @PositiveDbCreated=1;
    SET @Sql=N'CREATE DATABASE '+QUOTENAME(@EmptyDb)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @EmptyDbCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
        EXEC(N''CREATE SCHEMA [ExampleClassification263]'');
        CREATE TABLE [ExampleClassification263].[SyntheticColumns]
          ([ClassifiedSynthetic] int NULL,[UnclassifiedSynthetic] int NULL);
        ADD SENSITIVITY CLASSIFICATION TO [ExampleClassification263].[SyntheticColumns].[ClassifiedSynthetic]
          WITH (LABEL=N''NO_LEAK_LABEL_263'',LABEL_ID=N''NO_LEAK_LABEL_ID_263'',
                INFORMATION_TYPE=N''NO_LEAK_INFORMATION_TYPE_263'',
                INFORMATION_TYPE_ID=N''NO_LEAK_INFORMATION_TYPE_ID_263'');';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
        SELECT @Tables=COUNT_BIG(*) FROM sys.tables;
        SELECT @Columns=COUNT_BIG(*) FROM sys.tables AS t
          JOIN sys.columns AS c ON c.object_id=t.object_id;
        SELECT @Classified=COUNT_BIG(*) FROM sys.tables AS t
          JOIN sys.columns AS c ON c.object_id=t.object_id
          WHERE EXISTS(SELECT 1 FROM sys.sensitivity_classifications AS sc
                       WHERE sc.class=1 AND sc.major_id=t.object_id AND sc.minor_id=c.column_id);';
    EXEC [master].[sys].[sp_executesql] @Sql,
      N'@Tables bigint OUTPUT,@Columns bigint OUTPUT,@Classified bigint OUTPUT',
      @Tables=@ExpectedTables OUTPUT,@Columns=@ExpectedColumns OUTPUT,
      @Classified=@ExpectedClassified OUTPUT;
    IF @ExpectedTables<1 OR @ExpectedColumns<2 OR @ExpectedClassified<>1
        THROW 57503,N'Native positive fixture oracle was not established.',1;
    SET @Names=QUOTENAME(@PositiveDb)+N'|'+QUOTENAME(@EmptyDb);
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
      @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
      @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR @Error IS NOT NULL
       OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'SensitivityClassificationSummary'
       OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.schemaVersion'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.classificationSummary'))<>2
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.classificationSummary')
          WITH(DatabaseName sysname N'$.DatabaseName',VisibleTableCount bigint N'$.VisibleTableCount',
               VisibleTableColumnCount bigint N'$.VisibleTableColumnCount',
               ClassifiedVisibleTableColumnCount bigint N'$.ClassifiedVisibleTableColumnCount',
               StatusCode varchar(40) N'$.StatusCode',VisibilityScope varchar(32) N'$.VisibilityScope')
          WHERE DatabaseName=@PositiveDb AND VisibleTableCount=@ExpectedTables
            AND VisibleTableColumnCount=@ExpectedColumns
            AND ClassifiedVisibleTableColumnCount=1 AND StatusCode='AVAILABLE_LIMITED'
            AND VisibilityScope='VISIBLE_ONLY')
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.classificationSummary')
          WITH(DatabaseName sysname N'$.DatabaseName',VisibleTableCount bigint N'$.VisibleTableCount',
               VisibleTableColumnCount bigint N'$.VisibleTableColumnCount',
               ClassifiedVisibleTableColumnCount bigint N'$.ClassifiedVisibleTableColumnCount',
               StatusCode varchar(40) N'$.StatusCode')
          WHERE DatabaseName=@EmptyDb AND VisibleTableCount=0
            AND VisibleTableColumnCount=0 AND ClassifiedVisibleTableColumnCount=0
            AND StatusCode='AVAILABLE_LIMITED')
        THROW 57504,N'Positive or empty JSON summary contract mismatch.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNamePattern=N'like:ExampleClassificationNoMatch263_%',
      @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
      @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF @Return<>0 OR @Status<>'SKIPPED'
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.classificationSummary'))<>0
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
          WITH(SourceKey varchar(64) N'$.SourceKey',StatusCode varchar(40) N'$.StatusCode',IsLimited bit N'$.IsLimited')
          WHERE SourceKey='SENSITIVITY_CLASSIFICATION_CATALOG' AND StatusCode='SKIPPED' AND IsLimited=0)
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.warnings')
          WITH(WarningCode varchar(64) N'$.WarningCode') WHERE WarningCode='OUTPUT_LIMIT')
        THROW 57513,N'No-candidate status was falsely reported as a successful catalog read.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
      @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR COALESCE(ISJSON(@Json),0)<>1
       OR JSON_QUERY(@Json,N'$.moduleStatus') IS NULL
       OR JSON_QUERY(@Json,N'$.classificationSummary') IS NULL
       OR JSON_QUERY(@Json,N'$.sourceStatus') IS NULL
       OR JSON_QUERY(@Json,N'$.warnings') IS NULL
        THROW 57517,N'Privacy oracle requires a successful four-set JSON result.',1;
    IF @Json LIKE N'%NO_LEAK_%' OR @Json LIKE N'%SyntheticColumns%'
       OR @Json LIKE N'%ClassifiedSynthetic%' OR @Json LIKE N'%UnclassifiedSynthetic%'
        THROW 57505,N'Classification metadata privacy sentinel escaped.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
      @JsonErzeugen=1,@Json=@TableJson OUTPUT,@PrintMeldungen=0,
      @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT_BIG(*) FROM #SensitivityOut_moduleStatus)<>1
       OR (SELECT COUNT_BIG(*) FROM #SensitivityOut_classificationSummary)<>2
       OR (SELECT COUNT_BIG(*) FROM #SensitivityOut_sourceStatus)<3
       OR (SELECT COUNT_BIG(*) FROM #SensitivityOut_warnings)<1
       OR COALESCE(ISJSON(@TableJson),0)<>1
       OR JSON_QUERY(@TableJson,N'$.moduleStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.classificationSummary') IS NULL
       OR JSON_QUERY(@TableJson,N'$.sourceStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.warnings') IS NULL
       OR COALESCE((SELECT * FROM #SensitivityOut_classificationSummary ORDER BY DatabaseId FOR JSON PATH,INCLUDE_NULL_VALUES),N'')
           <>COALESCE(JSON_QUERY(@TableJson,N'$.classificationSummary'),N'')
        THROW 57506,N'Four-set TABLE/JSON contract mismatch.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='RAW',@PrintMeldungen=0,
      @StatusCodeOut=@Status OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'
        THROW 57520,N'RAW output branch failed on owned fixture databases.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='CONSOLE',@PrintMeldungen=0,
      @StatusCodeOut=@Status OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'
        THROW 57521,N'CONSOLE output branch failed on owned fixture databases.',1;
    DECLARE @ActualTable sysname,@ExpectedTable sysname,@AbiSql nvarchar(max);
    DECLARE [SensitivityAbi] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [ActualTable],[ExpectedTable] FROM [#SensitivityPhysicalPairs];
    OPEN [SensitivityAbi];
    FETCH NEXT FROM [SensitivityAbi] INTO @ActualTable,@ExpectedTable;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @AbiSql=N'IF EXISTS
        (
            SELECT [Ordinal],[ColumnName],[BaseType],[MaxLength],[Precision],[Scale],[IsNullable],[CollationName],[IsIdentity],[IsComputed]
            FROM
            (
                SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                       TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],[c].[max_length] AS [MaxLength],
                       [c].[precision] AS [Precision],[c].[scale] AS [Scale],
                       [c].[is_nullable] AS [IsNullable],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName],
                       [c].[is_identity] AS [IsIdentity],[c].[is_computed] AS [IsComputed]
                FROM tempdb.sys.columns AS [c] WITH (NOLOCK)
                WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@ActualTable+N''')
            ) AS [a]
            EXCEPT
            SELECT [Ordinal],[ColumnName],[BaseType],[MaxLength],[Precision],[Scale],[IsNullable],[CollationName],[IsIdentity],[IsComputed]
            FROM
            (
                SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                       TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],[c].[max_length] AS [MaxLength],
                       [c].[precision] AS [Precision],[c].[scale] AS [Scale],
                       [c].[is_nullable] AS [IsNullable],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName],
                       [c].[is_identity] AS [IsIdentity],[c].[is_computed] AS [IsComputed]
                FROM tempdb.sys.columns AS [c] WITH (NOLOCK)
                WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@ExpectedTable+N''')
            ) AS [e]
        )
        OR EXISTS
        (
            SELECT [Ordinal],[ColumnName],[BaseType],[MaxLength],[Precision],[Scale],[IsNullable],[CollationName],[IsIdentity],[IsComputed]
            FROM
            (
                SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                       TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],[c].[max_length] AS [MaxLength],
                       [c].[precision] AS [Precision],[c].[scale] AS [Scale],
                       [c].[is_nullable] AS [IsNullable],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName],
                       [c].[is_identity] AS [IsIdentity],[c].[is_computed] AS [IsComputed]
                FROM tempdb.sys.columns AS [c] WITH (NOLOCK)
                WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@ExpectedTable+N''')
            ) AS [e]
            EXCEPT
            SELECT [Ordinal],[ColumnName],[BaseType],[MaxLength],[Precision],[Scale],[IsNullable],[CollationName],[IsIdentity],[IsComputed]
            FROM
            (
                SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                       TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],[c].[max_length] AS [MaxLength],
                       [c].[precision] AS [Precision],[c].[scale] AS [Scale],
                       [c].[is_nullable] AS [IsNullable],[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName],
                       [c].[is_identity] AS [IsIdentity],[c].[is_computed] AS [IsComputed]
                FROM tempdb.sys.columns AS [c] WITH (NOLOCK)
                WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@ActualTable+N''')
            ) AS [a]
        )
        THROW 57514,N''Physical result ABI mismatch: '+@ActualTable+N''',1;';
        EXEC [sys].[sp_executesql] @AbiSql;
        FETCH NEXT FROM [SensitivityAbi] INTO @ActualTable,@ExpectedTable;
    END;
    CLOSE [SensitivityAbi]; DEALLOCATE [SensitivityAbi];
    IF COALESCE(ISJSON(@TableJson),0)<>1
       OR JSON_QUERY(@TableJson,N'$.moduleStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.classificationSummary') IS NULL
       OR JSON_QUERY(@TableJson,N'$.sourceStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.warnings') IS NULL
        THROW 57518,N'TABLE JSON privacy oracle requires four valid sets.',1;
    IF COALESCE(ISJSON(@TableJson),0)<>1
       OR JSON_QUERY(@TableJson,N'$.moduleStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.classificationSummary') IS NULL
       OR JSON_QUERY(@TableJson,N'$.sourceStatus') IS NULL
       OR JSON_QUERY(@TableJson,N'$.warnings') IS NULL
        THROW 57518,N'TABLE JSON privacy oracle requires four valid sets.',1;
    IF @TableJson LIKE N'%NO_LEAK_%' OR @TableJson LIKE N'%SyntheticColumns%'
        THROW 57507,N'TABLE JSON privacy sentinel escaped.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@MaxZeilen=1,@ResultSetArt='NONE',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF @Return<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.classificationSummary'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
          WITH(SourceKey varchar(64) N'$.SourceKey',IsLimited bit N'$.IsLimited')
          WHERE SourceKey='SENSITIVITY_CLASSIFICATION_CATALOG' AND IsLimited=1)
        THROW 57508,N'Output-row limit contract mismatch.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@MaxZeilen=0,@ResultSetArt='NONE',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF @Return<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.classificationSummary'))<>2
        THROW 57515,N'Zero output limit did not mean unlimited.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@MaxZeilen=NULL,@ResultSetArt='NONE',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF @Return<>0 OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.classificationSummary'))<>2
        THROW 57516,N'NULL output limit did not mean unlimited.',1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@ResultSetArt='TABLE',
      @ResultTablesJson=N'{"unknownResult":"#SensitivityOut_moduleStatus"}',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
      @ErrorNumberOut=@Error OUTPUT;
    IF @Return<>51011 OR @Error<>51011 OR @Json IS NOT NULL
        THROW 57517,N'Invalid TABLE mapping was not rejected before catalog access.',1;
    BEGIN TRANSACTION;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 7000;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@Names,@LockTimeoutMs=250,@ResultSetArt='NONE',@PrintMeldungen=0;
    IF @Return<>0 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>7000
       OR (@@OPTIONS&16384)=0
        THROW 57509,N'Caller transaction or session state changed.',1;
    ROLLBACK TRANSACTION;
    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';'; EXEC [sys].[sp_executesql] @Sql;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)+N' WITH PASS'+N'WORD='+QUOTENAME(@Password,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Password=NULL;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
      GRANT EXECUTE ON [monitor].[USP_SensitivityClassificationSummary] TO '+QUOTENAME(@Reader)+N';
      GRANT EXECUTE ON [monitor].[USP_PrepareDatabaseCandidates] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @InstallUserCreated=1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
      CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
      GRANT CONNECT TO '+QUOTENAME(@Reader)+N';
      GRANT VIEW ANY SENSITIVITY CLASSIFICATION TO '+QUOTENAME(@Reader)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Sql=N'USE '+QUOTENAME(@EmptyDb)+N';
      CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
      GRANT CONNECT TO '+QUOTENAME(@Reader)+N';
      GRANT VIEW ANY SENSITIVITY CLASSIFICATION TO '+QUOTENAME(@Reader)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Sql=N'GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Reader)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@EmptyDb,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
      @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    REVERT;
    SET @Impersonating=0;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.classificationSummary')
          WITH(VisibleTableCount bigint N'$.VisibleTableCount',
               VisibleTableColumnCount bigint N'$.VisibleTableColumnCount',
               ClassifiedVisibleTableColumnCount bigint N'$.ClassifiedVisibleTableColumnCount',
               StatusCode varchar(40) N'$.StatusCode')
          WHERE VisibleTableCount=0 AND VisibleTableColumnCount=0
            AND ClassifiedVisibleTableColumnCount=0 AND StatusCode='AVAILABLE_LIMITED')
        THROW 57510,N'Restricted visible-empty catalog contract mismatch.',1;
    SET @Sql=N'USE '+QUOTENAME(@PositiveDb)+N';
       DENY VIEW ANY SENSITIVITY CLASSIFICATION TO '+QUOTENAME(@Reader)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@Reader;
    SET @Impersonating=1;
    EXEC @Return=[monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames=@PositiveDb,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
      @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
    REVERT;
    SET @Impersonating=0;
    IF @Return<>0 OR @Status<>'DENIED_PERMISSION' OR @Error IS NOT NULL
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.classificationSummary')
          WITH(VisibleTableCount bigint N'$.VisibleTableCount',
               VisibleTableColumnCount bigint N'$.VisibleTableColumnCount',
               ClassifiedVisibleTableColumnCount bigint N'$.ClassifiedVisibleTableColumnCount',
               StatusCode varchar(40) N'$.StatusCode')
          WHERE VisibleTableCount IS NULL AND VisibleTableColumnCount IS NULL
            AND ClassifiedVisibleTableColumnCount IS NULL AND StatusCode='DENIED_PERMISSION')
        THROW 57511,N'Permission preflight NULL-count contract mismatch.',1;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
        THROW 57512,N'Caller state was not restored.',1;
END TRY
BEGIN CATCH
    -- Each owned fixture cleanup is independent. Bare THROW keeps the original error.
BEGIN TRY
    IF @Impersonating=1
    BEGIN
        REVERT;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0
    BEGIN
        ROLLBACK TRANSACTION;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF @InstallUserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
            EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF @PositiveDbCreated=1 AND DB_ID(@PositiveDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@PositiveDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@PositiveDb)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF @EmptyDbCreated=1 AND DB_ID(@EmptyDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@EmptyDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@EmptyDb)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF 1=1
    BEGIN
        SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
            EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
BEGIN TRY
    IF 1=1
    BEGIN
        IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END;
END TRY
BEGIN CATCH
    -- Preserve the original error and continue owned cleanup.
END CATCH;
    THROW;
END CATCH;
BEGIN TRY
    IF @Impersonating=1
    BEGIN
        REVERT;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF XACT_STATE()<>0
    BEGIN
        ROLLBACK TRANSACTION;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @InstallUserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Reader)+N';';
            EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Reader)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @PositiveDbCreated=1 AND DB_ID(@PositiveDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@PositiveDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@PositiveDb)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF @EmptyDbCreated=1 AND DB_ID(@EmptyDb) IS NOT NULL
    BEGIN
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@EmptyDb)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@EmptyDb)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF 1=1
    BEGIN
        SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
            EXEC [sys].[sp_executesql] @Sql;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
BEGIN TRY
    IF 1=1
    BEGIN
        IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END;
END TRY
BEGIN CATCH
    IF @CleanupFailure IS NULL SET @CleanupFailure=LEFT(ERROR_MESSAGE(),2048);
END CATCH;
IF @CleanupFailure IS NOT NULL THROW 57519,@CleanupFailure,1;
SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       CAST('142' AS varchar(16)) AS [ContractId],
       N'Sensitivity summary native positive, empty, denied, caller, TABLE, JSON and cleanup contract passed.' AS [Detail];
GO
