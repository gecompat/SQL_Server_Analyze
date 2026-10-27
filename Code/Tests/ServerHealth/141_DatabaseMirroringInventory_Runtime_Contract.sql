USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57410,N'Database Mirroring contract requires an isolated SQL Server 2019, 2022, or 2025 sysadmin target without an ambient transaction.',1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) NOT IN (15,16,17)
    THROW 57411,N'Database Mirroring runtime contract requires a supported SQL Server 2019, 2022, or 2025 target.',1;
GO
DECLARE @OriginalLock int=@@LOCK_TIMEOUT,
        @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @OriginalIsolation tinyint,
        @RestoreLock nvarchar(100),
        @OriginalTx int=@@TRANCOUNT,
        @Json nvarchar(max),@JsonNull nvarchar(max),@JsonOne nvarchar(max),@JsonZero nvarchar(max),
        @JsonUnlimited nvarchar(max),@JsonRestricted nvarchar(max),@JsonDenied nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
        @Map nvarchar(max)=N'{"moduleStatus":"#DbmiOut_moduleStatus","databaseMirroring":"#DbmiOut_databaseMirroring","sourceStatus":"#DbmiOut_sourceStatus","warnings":"#DbmiOut_warnings"}',
        @Login sysname,@EphemeralCredential nvarchar(128),@Sql nvarchar(max),
        @ProductMajor int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @UserCreated bit=0,
        @LoginCreated bit=0,@Impersonating bit=0,@DbName sysname,
        @SourceRows bigint,@ReturnRows bigint,@LimitApplied bit;
SELECT @OriginalIsolation=[transaction_isolation_level]
FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID;
CREATE TABLE [#DbmiMarker]([Marker] int NOT NULL);
CREATE TABLE [#DbmiOut_moduleStatus]([Seed] int NULL);
CREATE TABLE [#DbmiOut_databaseMirroring]([Seed] int NULL);
CREATE TABLE [#DbmiOut_sourceStatus]([Seed] int NULL);
CREATE TABLE [#DbmiOut_warnings]([Seed] int NULL);
CREATE TABLE [#DbmiExpected_moduleStatus]([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#DbmiExpected_databaseMirroring]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[MirroringState] tinyint NULL,[MirroringStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MirroringRole] tinyint NULL,[MirroringRoleDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MirroringSafetyLevel] tinyint NULL,[MirroringSafetyLevelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MirroringWitnessState] tinyint NULL,[MirroringWitnessStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ConfiguredRedoQueueLimitMb] int NULL,[RedoQueueLimitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE [#DbmiExpected_sourceStatus]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StartedAtUtc] datetime2(3) NOT NULL,[CompletedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedRows] bigint NULL,[ReturnedRows] bigint NULL,[IsLimited] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE [#DbmiExpected_warnings]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#DbmiPhysicalPairs]([ActualTable] sysname NOT NULL,[ExpectedTable] sysname NOT NULL);
INSERT [#DbmiPhysicalPairs] VALUES
(N'#DbmiOut_moduleStatus',N'#DbmiExpected_moduleStatus'),
(N'#DbmiOut_databaseMirroring',N'#DbmiExpected_databaseMirroring'),
(N'#DbmiOut_sourceStatus',N'#DbmiExpected_sourceStatus'),
(N'#DbmiOut_warnings',N'#DbmiExpected_warnings');

BEGIN TRY
    SET LOCK_TIMEOUT 137;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    BEGIN TRANSACTION;
    INSERT [#DbmiMarker] VALUES(57412);
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=NULL,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=NULL,
        @MaxZeilen=0,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0
        THROW 57440,N'TABLE call returned a nonzero procedure return code.',1;
    IF @Status<>'AVAILABLE_LIMITED'
        THROW 57441,N'TABLE call did not report its expected successful limited status.',1;
    IF @Partial<>1
        THROW 57442,N'TABLE call did not report partial caller-visible scope.',1;
    IF ISJSON(@Json)<>1
        THROW 57443,N'TABLE call did not return the requested JSON envelope.',1;
    IF @@TRANCOUNT<>1
        THROW 57444,N'TABLE call changed the caller transaction count.',1;
    IF XACT_STATE()<>1
        THROW 57445,N'TABLE call changed the active caller transaction state.',1;
    IF @@LOCK_TIMEOUT<>137
        THROW 57446,N'TABLE call did not restore the caller LOCK_TIMEOUT.',1;
    IF (@@OPTIONS&16384)=0
        THROW 57447,N'TABLE call did not preserve caller XACT_ABORT ON.',1;
    IF (SELECT [transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID)<>3
        THROW 57448,N'TABLE call did not preserve the caller REPEATABLE READ isolation level.',1;
    IF (SELECT COUNT(*) FROM [#DbmiMarker] WHERE [Marker]=57412)<>1
        THROW 57449,N'TABLE call changed the caller sentinel row.',1;
    -- Procedure source reads use SET LOCK_TIMEOUT 0 and restore this caller value.
    IF (SELECT COUNT(*) FROM [#DbmiOut_moduleStatus])<>1
       OR (SELECT COUNT(*) FROM [#DbmiOut_databaseMirroring])<1
       OR (SELECT COUNT(*) FROM [#DbmiOut_sourceStatus] WHERE [SourceKey]='DATABASE_MIRRORING_CATALOG' AND [StatusCode]='AVAILABLE_LIMITED')<>1
        THROW 57414,N'Baseline output must contain caller-visible ONLINE databases and one successful native source status.',1;
    INSERT [#DbmiExpected_moduleStatus]
    SELECT * FROM OPENJSON(@Json,N'$.moduleStatus') WITH
      ([ModuleName] sysname N'$.ModuleName',[CapturedAtUtc] datetime2(3) N'$.CapturedAtUtc',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail');
    INSERT [#DbmiExpected_databaseMirroring]
    SELECT * FROM OPENJSON(@Json,N'$.databaseMirroring') WITH
      ([DatabaseId] int N'$.DatabaseId',[DatabaseName] sysname N'$.DatabaseName',[MirroringState] tinyint N'$.MirroringState',[MirroringStateDesc] nvarchar(60) N'$.MirroringStateDesc',[MirroringRole] tinyint N'$.MirroringRole',[MirroringRoleDesc] nvarchar(60) N'$.MirroringRoleDesc',[MirroringSafetyLevel] tinyint N'$.MirroringSafetyLevel',[MirroringSafetyLevelDesc] nvarchar(60) N'$.MirroringSafetyLevelDesc',[MirroringWitnessState] tinyint N'$.MirroringWitnessState',[MirroringWitnessStateDesc] nvarchar(60) N'$.MirroringWitnessStateDesc',[ConfiguredRedoQueueLimitMb] int N'$.ConfiguredRedoQueueLimitMb',[RedoQueueLimitType] nvarchar(60) N'$.RedoQueueLimitType');
    INSERT [#DbmiExpected_sourceStatus]
    SELECT * FROM OPENJSON(@Json,N'$.sourceStatus') WITH
      ([DatabaseId] int N'$.DatabaseId',[DatabaseName] sysname N'$.DatabaseName',[SourceKey] varchar(64) N'$.SourceKey',[SourceKind] varchar(16) N'$.SourceKind',[StartedAtUtc] datetime2(3) N'$.StartedAtUtc',[CompletedAtUtc] datetime2(3) N'$.CompletedAtUtc',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage');
    INSERT [#DbmiExpected_warnings]
    SELECT * FROM OPENJSON(@Json,N'$.warnings') WITH
      ([DatabaseId] int N'$.DatabaseId',[DatabaseName] sysname N'$.DatabaseName',[WarningCode] varchar(64) N'$.WarningCode',[SourceKey] varchar(64) N'$.SourceKey',[Detail] nvarchar(1000) N'$.Detail');
    IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>5
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseMirroring'))<>(SELECT COUNT(*) FROM [#DbmiOut_databaseMirroring])
        THROW 57415,N'JSON envelope or TABLE-to-JSON row parity failed.',1;
    IF EXISTS(SELECT * FROM [#DbmiOut_moduleStatus] EXCEPT SELECT * FROM [#DbmiExpected_moduleStatus])
       OR EXISTS(SELECT * FROM [#DbmiExpected_moduleStatus] EXCEPT SELECT * FROM [#DbmiOut_moduleStatus])
       OR EXISTS(SELECT * FROM [#DbmiOut_databaseMirroring] EXCEPT SELECT * FROM [#DbmiExpected_databaseMirroring])
       OR EXISTS(SELECT * FROM [#DbmiExpected_databaseMirroring] EXCEPT SELECT * FROM [#DbmiOut_databaseMirroring])
       OR EXISTS(SELECT * FROM [#DbmiOut_sourceStatus] EXCEPT SELECT * FROM [#DbmiExpected_sourceStatus])
       OR EXISTS(SELECT * FROM [#DbmiExpected_sourceStatus] EXCEPT SELECT * FROM [#DbmiOut_sourceStatus])
       OR EXISTS(SELECT * FROM [#DbmiOut_warnings] EXCEPT SELECT * FROM [#DbmiExpected_warnings])
       OR EXISTS(SELECT * FROM [#DbmiExpected_warnings] EXCEPT SELECT * FROM [#DbmiOut_warnings])
        THROW 57416,N'TABLE rows do not match the independently parsed JSON rows.',1;
    IF NOT EXISTS(SELECT 1 FROM [#DbmiOut_warnings] WHERE [WarningCode]='MIRRORING_NULLS_UNINTERPRETED')
       OR NOT EXISTS(SELECT 1 FROM [#DbmiOut_warnings] WHERE [WarningCode]='ROLE_VISIBILITY_LIMIT')
       OR (SELECT COUNT(*) FROM [#DbmiOut_databaseMirroring])
       <>(SELECT [ReturnedRows] FROM [#DbmiOut_sourceStatus] WHERE [SourceKey]='DATABASE_MIRRORING_CATALOG' AND [StatusCode]='AVAILABLE_LIMITED')
        THROW 57417,N'Business row count and caller-visible catalog returned-row count differ.',1;
    IF EXISTS
    (
        SELECT * FROM [#DbmiOut_databaseMirroring]
        EXCEPT
        SELECT [d].[database_id],[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_state],[m].[mirroring_state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_role],[m].[mirroring_role_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_safety_level],[m].[mirroring_safety_level_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_witness_state],[m].[mirroring_witness_state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_redo_queue],[m].[mirroring_redo_queue_type] COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
        LEFT JOIN [master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)
          ON [m].[database_id]=[d].[database_id]
        WHERE [d].[source_database_id] IS NULL AND [d].[state]=0
          AND HAS_DBACCESS([d].[name])=1 AND [d].[database_id]>4
    ) OR EXISTS
    (
        SELECT [d].[database_id],[d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_state],[m].[mirroring_state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_role],[m].[mirroring_role_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_safety_level],[m].[mirroring_safety_level_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_witness_state],[m].[mirroring_witness_state_desc] COLLATE SQL_Latin1_General_CP1_CS_AS,
               [m].[mirroring_redo_queue],[m].[mirroring_redo_queue_type] COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
        LEFT JOIN [master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)
          ON [m].[database_id]=[d].[database_id]
        WHERE [d].[source_database_id] IS NULL AND [d].[state]=0
          AND HAS_DBACCESS([d].[name])=1 AND [d].[database_id]>4
        EXCEPT SELECT * FROM [#DbmiOut_databaseMirroring]
    )
        THROW 57431,N'Native sys.databases/sys.database_mirroring oracle differs from the business result.',1;

    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=NULL,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=NULL,
        @MaxZeilen=0,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseMirroring'))<>(SELECT COUNT(*) FROM [#DbmiOut_databaseMirroring])
       OR EXISTS(SELECT * FROM OPENJSON(@Json,N'$.databaseMirroring') WITH([DatabaseId] int N'$.DatabaseId',[DatabaseName] sysname N'$.DatabaseName',[MirroringState] tinyint N'$.MirroringState',[MirroringStateDesc] nvarchar(60) N'$.MirroringStateDesc',[MirroringRole] tinyint N'$.MirroringRole',[MirroringRoleDesc] nvarchar(60) N'$.MirroringRoleDesc',[MirroringSafetyLevel] tinyint N'$.MirroringSafetyLevel',[MirroringSafetyLevelDesc] nvarchar(60) N'$.MirroringSafetyLevelDesc',[MirroringWitnessState] tinyint N'$.MirroringWitnessState',[MirroringWitnessStateDesc] nvarchar(60) N'$.MirroringWitnessStateDesc',[ConfiguredRedoQueueLimitMb] int N'$.ConfiguredRedoQueueLimitMb',[RedoQueueLimitType] nvarchar(60) N'$.RedoQueueLimitType') EXCEPT SELECT * FROM [#DbmiExpected_databaseMirroring])
        THROW 57432,N'RAW mode JSON values differ from the TABLE/JSON business ABI.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=NULL,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=NULL,
        @MaxZeilen=0,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseMirroring'))<>(SELECT COUNT(*) FROM [#DbmiExpected_databaseMirroring])
        THROW 57433,N'CONSOLE mode JSON values or status differ from the TABLE/JSON business ABI.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=NULL,@SystemdatenbankenEinbeziehen=0,@DatabaseNamePattern=NULL,
        @MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseMirroring'))<>(SELECT COUNT(*) FROM [#DbmiExpected_databaseMirroring])
        THROW 57434,N'NONE mode JSON values or status differ from the TABLE/JSON business ABI.',1;

    DECLARE @ActualTable sysname,@ExpectedTable sysname,@AbiSql nvarchar(max);
    DECLARE [DbmiAbi] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [ActualTable],[ExpectedTable] FROM [#DbmiPhysicalPairs];
    OPEN [DbmiAbi];
    FETCH NEXT FROM [DbmiAbi] INTO @ActualTable,@ExpectedTable;
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
        THROW 57418,N''Physical result ABI mismatch: '+@ActualTable+N''',1;';
        EXEC [sys].[sp_executesql] @AbiSql;
        FETCH NEXT FROM [DbmiAbi] INTO @ActualTable,@ExpectedTable;
    END;
    CLOSE [DbmiAbi]; DEALLOCATE [DbmiAbi];
    IF EXISTS(SELECT 1 FROM [#DbmiOut_databaseMirroring] AS [a]
              WHERE [a].[DatabaseName] IS NULL OR [a].[DatabaseId] IS NULL)
       OR EXISTS(SELECT 1 FROM [#DbmiOut_databaseMirroring] AS [a]
                 WHERE [a].[MirroringRoleDesc] IN (N'PRIMARY',N'SECONDARY'))
        THROW 57419,N'Native catalog values or role descriptions were fabricated or normalized.',1;
    ROLLBACK TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'[tempdb]',@SystemdatenbankenEinbeziehen=1,@MaxZeilen=NULL,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@JsonNull OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonNull,N'$.databaseMirroring'))<>1
        THROW 57420,N'Explicit System-database selection or NULL/unlimited limit failed.',1;
    DECLARE @ExpectedJsonFields TABLE
    (
        [FieldName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [MustBeNull] bit NOT NULL
    );
    DECLARE @ActualJsonFields TABLE
    (
        [FieldName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [JsonType] int NOT NULL
    );
    INSERT @ExpectedJsonFields([FieldName],[MustBeNull])
    VALUES (N'DatabaseId',0),(N'DatabaseName',0),(N'MirroringState',1),(N'MirroringStateDesc',1),(N'MirroringRole',1),(N'MirroringRoleDesc',1),(N'MirroringSafetyLevel',1),(N'MirroringSafetyLevelDesc',1),(N'MirroringWitnessState',1),(N'MirroringWitnessStateDesc',1),(N'ConfiguredRedoQueueLimitMb',1),(N'RedoQueueLimitType',1);
    INSERT @ActualJsonFields([FieldName],[JsonType])
    SELECT [v].[key],[v].[type]
    FROM OPENJSON(@JsonNull,N'$.databaseMirroring') AS [r]
    CROSS APPLY OPENJSON([r].[value]) AS [v];
    IF (SELECT COUNT(*) FROM @ActualJsonFields)<>12
       OR EXISTS(SELECT [FieldName] FROM @ExpectedJsonFields
                 EXCEPT SELECT [FieldName] FROM @ActualJsonFields)
       OR EXISTS(SELECT [FieldName] FROM @ActualJsonFields
                 EXCEPT SELECT [FieldName] FROM @ExpectedJsonFields)
       OR EXISTS(SELECT [FieldName] FROM @ActualJsonFields
                 GROUP BY [FieldName] HAVING COUNT(*)<>1)
       OR EXISTS
       (
           SELECT 1
           FROM @ExpectedJsonFields AS [e]
           INNER JOIN @ActualJsonFields AS [a] ON [a].[FieldName]=[e].[FieldName]
           WHERE ([e].[MustBeNull]=1 AND [a].[JsonType]<>0)
              OR ([e].[MustBeNull]=0 AND [a].[JsonType]=0)
       )
        THROW 57421,N'Native JSON fields for unmirrored tempdb must match all twelve business keys and preserve all ten NULL values.',1;

    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @SystemdatenbankenEinbeziehen=1,@MaxZeilen=1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@JsonOne OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    SELECT @SourceRows=TRY_CONVERT(bigint,JSON_VALUE([value],'$.ObservedRows')),
           @ReturnRows=TRY_CONVERT(bigint,JSON_VALUE([value],'$.ReturnedRows')),
           @LimitApplied=TRY_CONVERT(bit,JSON_VALUE([value],'$.IsLimited'))
    FROM OPENJSON(@JsonOne,N'$.sourceStatus')
    WHERE JSON_VALUE([value],'$.SourceKey')='DATABASE_MIRRORING_CATALOG';
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonOne,N'$.databaseMirroring'))<>1
       OR @SourceRows<2 OR @ReturnRows<>1 OR @LimitApplied<>1
        THROW 57422,N'MaxZeilen=1 was not non-vacuous or did not report the applied global output limit.',1;

    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @SystemdatenbankenEinbeziehen=1,@MaxZeilen=0,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@JsonZero OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonZero,N'$.databaseMirroring'))<2
        THROW 57423,N'MaxZeilen=0 did not return the non-vacuous complete visible candidate set.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @SystemdatenbankenEinbeziehen=1,@MaxZeilen=NULL,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@JsonUnlimited OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR (SELECT COUNT(*) FROM OPENJSON(@JsonUnlimited,N'$.databaseMirroring'))
       <>(SELECT COUNT(*) FROM OPENJSON(@JsonZero,N'$.databaseMirroring'))
        THROW 57424,N'MaxZeilen=NULL did not have the same unlimited result cardinality as zero.',1;

    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'[tempdb]',@SystemdatenbankenEinbeziehen=1,
        @DatabaseNamePattern=N'like:%',@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Error<>51011
        THROW 57425,N'Combining the exact-name filter and pattern was not rejected.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'  ',@SystemdatenbankenEinbeziehen=1,
        @DatabaseNamePattern=N'like:tempdb',@MaxZeilen=0,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@JsonUnlimited OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonUnlimited,N'$.databaseMirroring'))<>1
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@JsonUnlimited,N'$.databaseMirroring')
                   WITH([DatabaseName] sysname N'$.DatabaseName') AS [j]
              WHERE [j].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'tempdb' COLLATE SQL_Latin1_General_CP1_CS_AS
          )
        THROW 57450,N'Blank exact-name input must normalize to no selector and allow a valid pattern.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @MaxZeilen=-1,@ResultSetArt='NONE',@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Error<>51011
        THROW 57426,N'Negative MaxZeilen was not rejected.',1;
    EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
        @DatabaseNames=N'[Codex_Missing_Database]',@SystemdatenbankenEinbeziehen=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@JsonRestricted OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Status<>'DATABASE_UNAVAILABLE' OR @Error<>51011
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@JsonRestricted,N'$.warnings')
                     WHERE JSON_VALUE([value],'$.WarningCode')='TARGET_SELECTION')
        THROW 57427,N'Unavailable explicit database selection was not returned as a selection warning/error.',1;

    EXEC [monitor].[USP_DatabaseMirroringInventory]
        @Hilfe=1,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Status<>'AVAILABLE' OR @Partial<>0 OR @Json IS NOT NULL
        THROW 57428,N'Help did not return before JSON or source processing.',1;

    SET @Login=CONCAT(N'DbmiReader_',REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''));
    SET @EphemeralCredential=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Login)+N' WITH PASS'+N'WORD = N'''+REPLACE(@EphemeralCredential,N'''',N'''''')+N''', CHECK_POLICY=OFF;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=1;
    SET @Sql=N'USE [master]; GRANT VIEW ANY DATABASE TO '+QUOTENAME(@Login)+N';';
    IF @ProductMajor>=16
        SET @Sql+=N' DENY VIEW SERVER PERFORMANCE STATE TO '+QUOTENAME(@Login)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'CREATE USER '+QUOTENAME(@Login)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @UserCreated=1;
    SET @Sql=N'GRANT EXECUTE ON OBJECT::[monitor].[USP_DatabaseMirroringInventory] TO '+QUOTENAME(@Login)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    IF @ProductMajor>=16
    BEGIN
        EXECUTE AS LOGIN=@Login;
        SET @Impersonating=1;
        EXEC @Return=[monitor].[USP_DatabaseMirroringInventory]
            @DatabaseNames=N'[master]',@SystemdatenbankenEinbeziehen=1,
            @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@JsonDenied OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        REVERT;
        SET @Impersonating=0;
        IF @Status='AVAILABLE_LIMITED' OR @Error IS NULL
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@JsonDenied,N'$.sourceStatus')
                         WHERE JSON_VALUE([value],'$.SourceKey')='DATABASE_MIRRORING_CATALOG'
                           AND JSON_VALUE([value],'$.StatusCode')='DENIED_PERMISSION'
                           AND TRY_CONVERT(int,JSON_VALUE([value],'$.ErrorNumber')) IS NOT NULL)
            THROW 57429,N'DENY VIEW SERVER PERFORMANCE STATE was disguised as an empty successful inventory.',1;
    END
    ELSE
        PRINT N'SQL Server 2019: no minimum catalog-denial permission is asserted; the successful caller-visible catalog/ABI cases remain active.';

    SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @UserCreated=0;
    SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @LoginCreated=0;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    EXEC [sys].[sp_executesql] @RestoreLock;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    IF @OriginalIsolation=1 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    ELSE IF @OriginalIsolation=2 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    ELSE IF @OriginalIsolation=3 SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    ELSE IF @OriginalIsolation=4 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    ELSE IF @OriginalIsolation=5 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>@OriginalLock
       OR (CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END)<>@OriginalAbort
        THROW 57430,N'Cleanup did not restore caller state.',1;
END TRY
BEGIN CATCH
    IF @Impersonating=1 REVERT;
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @UserCreated=1
    BEGIN
        SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
    IF @LoginCreated=1
    BEGIN
        SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    EXEC [sys].[sp_executesql] @RestoreLock;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    IF @OriginalIsolation=1 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    ELSE IF @OriginalIsolation=2 SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    ELSE IF @OriginalIsolation=3 SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    ELSE IF @OriginalIsolation=4 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    ELSE IF @OriginalIsolation=5 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
    THROW;
END CATCH;
GO
SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST('141' AS varchar(16)) AS [ContractId],
       N'Database Mirroring caller visibility, four-set ABI, native NULLs, selection, limits, denied source and cleanup passed.' AS [Detail];
GO
