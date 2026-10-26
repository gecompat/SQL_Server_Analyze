USE [DeineDatenbank];
GO
IF OBJECT_ID(N'tempdb..#ExampleRlsMaskContract') IS NOT NULL
    THROW 57289,N'RLS and masking scoped fixture procedure already exists.',1;
GO
CREATE PROCEDURE [#ExampleRlsMaskContract]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
        @DbA sysname,@DbB sysname,@DbEmpty sysname,@Schema sysname,@Function sysname,@PolicyA sysname,@PolicyB sysname,
        @TableA sysname,@TableB sysname,@Sql nvarchar(max),@Names nvarchar(max),@NamesBoth nvarchar(max),@Json nvarchar(max),@PositiveJson nvarchar(max),
        @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
        @OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @OriginalTx int=@@TRANCOUNT,@NativeTableCases int=0,@RestrictedLogin sysname,@RestrictedUser sysname,
        @CatalogObject sysname,@ExpectedSource varchar(64),@FirstDatabaseId int,
        @Credential nvarchar(128),@Impersonating bit=0;
    CREATE TABLE [#RlsMaskOutput_moduleStatus]([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#RlsMaskOutput_databaseContext]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#RlsMaskOutput_securityPolicies]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PolicyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsEnabled] bit NOT NULL,[IsNotForReplication] bit NOT NULL,[UsesDatabaseCollation] bit NOT NULL,[IsSchemabindingEnabled] bit NULL,[CreateDate] datetime NOT NULL,[ModifyDate] datetime NOT NULL);
    CREATE TABLE [#RlsMaskOutput_securityPredicates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PredicateId] int NOT NULL,[TargetObjectId] int NOT NULL,[PredicateType] int NOT NULL,[PredicateTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Operation] int NULL,[OperationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#RlsMaskOutput_maskedColumns]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[ColumnId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsMasked] bit NOT NULL);
    CREATE TABLE [#RlsMaskOutput_sourceStatus]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StartedAtUtc] datetime2(3) NOT NULL,[CompletedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedRows] bigint NULL,[ReturnedRows] bigint NULL,[IsLimited] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#RlsMaskOutput_warnings]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#RlsMaskExpected_securityPolicies]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PolicyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsEnabled] bit NOT NULL,[IsNotForReplication] bit NOT NULL,[UsesDatabaseCollation] bit NOT NULL,[IsSchemabindingEnabled] bit NULL,[CreateDate] datetime NOT NULL,[ModifyDate] datetime NOT NULL);
    CREATE TABLE [#RlsMaskExpected_securityPredicates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PredicateId] int NOT NULL,[TargetObjectId] int NOT NULL,[PredicateType] int NOT NULL,[PredicateTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Operation] int NULL,[OperationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#RlsMaskExpected_maskedColumns]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[ColumnId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsMasked] bit NOT NULL);
    IF @OriginalTx<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
        THROW 57210,N'RLS and masking fixture requires an isolated sysadmin target without ambient transaction.',1;
    SELECT @DbA=N'ExampleRlsMaskA_'+@Suffix,@DbB=N'ExampleRlsMaskB_'+@Suffix,@DbEmpty=N'ExampleRlsMaskEmpty_'+@Suffix,
           @Schema=N'ExampleRlsMask_'+@Suffix,@Function=N'ExampleRlsPredicate_'+@Suffix,
           @PolicyA=N'ExampleRlsPolicyA_'+@Suffix,@PolicyB=N'ExampleRlsPolicyB_'+@Suffix,
           @TableA=N'ExampleRlsTableA_'+@Suffix,@TableB=N'ExampleRlsTableB_'+@Suffix;
    BEGIN TRY
        SET @Sql=N'CREATE DATABASE '+QUOTENAME(@DbA)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Sql=N'CREATE DATABASE '+QUOTENAME(@DbB)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Sql=N'CREATE DATABASE '+QUOTENAME(@DbEmpty)+N' COLLATE SQL_Latin1_General_CP1_CS_AS;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        DECLARE @FixtureDatabase sysname,@Definition nvarchar(max);
        DECLARE [RlsMaskFixtureDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseName] FROM (VALUES(@DbA),(@DbB)) AS [v]([DatabaseName]);
        OPEN [RlsMaskFixtureDatabases]; FETCH NEXT FROM [RlsMaskFixtureDatabases] INTO @FixtureDatabase;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; CREATE SCHEMA '+QUOTENAME(@Schema)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
            SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; CREATE TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@TableA)+N'([TenantId] int NOT NULL,[SensitiveA] varchar(40) MASKED WITH (FUNCTION=''partial(1,"NO_LEAK_MASK_TOKEN",0)'') NULL,[SensitiveB] varchar(40) MASKED WITH (FUNCTION=''default()'') NULL); CREATE TABLE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@TableB)+N'([TenantId] int NOT NULL);';
            EXEC [master].[sys].[sp_executesql] @Sql;
            SET @Definition=N'CREATE FUNCTION '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Function)+N'(@TenantId int) RETURNS TABLE WITH SCHEMABINDING AS RETURN SELECT 1 AS [allowed] WHERE @TenantId=0 /* EXAMPLE_NO_LEAK_PREDICATE_TOKEN */;';
            SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; EXEC [sys].[sp_executesql] @Definition;';
            EXEC [master].[sys].[sp_executesql] @Sql,N'@Definition nvarchar(max)',@Definition=@Definition;
            SET @Definition=N'CREATE SECURITY POLICY '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@PolicyA)+N' ADD FILTER PREDICATE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Function)+N'([TenantId]) ON '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@TableA)+N' WITH (STATE=ON);';
            SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; EXEC [sys].[sp_executesql] @Definition;';
            EXEC [master].[sys].[sp_executesql] @Sql,N'@Definition nvarchar(max)',@Definition=@Definition;
            SET @Definition=N'CREATE SECURITY POLICY '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@PolicyB)+N' ADD FILTER PREDICATE '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Function)+N'([TenantId]) ON '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@TableB)+N' WITH (STATE=OFF);';
            SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; EXEC [sys].[sp_executesql] @Definition;';
            EXEC [master].[sys].[sp_executesql] @Sql,N'@Definition nvarchar(max)',@Definition=@Definition;
            FETCH NEXT FROM [RlsMaskFixtureDatabases] INTO @FixtureDatabase;
        END;
        CLOSE [RlsMaskFixtureDatabases]; DEALLOCATE [RlsMaskFixtureDatabases];
        SET @Names=QUOTENAME(@DbA);
        SET @NamesBoth=QUOTENAME(@DbA)+N'|'+QUOTENAME(@DbB);
        SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; '
            +N'INSERT [#RlsMaskExpected_securityPolicies] SELECT DB_ID(),DB_NAME(),[p].[object_id],[p].[name],[p].[schema_id],[s].[name],[p].[is_enabled],[p].[is_not_for_replication],[p].[uses_database_collation],[p].[is_schemabinding_enabled],[p].[create_date],[p].[modify_date] FROM [sys].[security_policies] AS [p] LEFT JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[p].[schema_id]; '
            +N'INSERT [#RlsMaskExpected_securityPredicates] SELECT DB_ID(),DB_NAME(),[p].[object_id],[p].[predicate_id],[p].[target_object_id],[p].[predicate_type],[p].[predicate_type_desc],[p].[operation],[p].[operation_desc] FROM [sys].[security_predicates] AS [p]; '
            +N'INSERT [#RlsMaskExpected_maskedColumns] SELECT DB_ID(),DB_NAME(),[m].[object_id],[m].[column_id],[s].[name],[t].[name],[m].[name],[m].[is_masked] FROM [sys].[masked_columns] AS [m] LEFT JOIN [sys].[tables] AS [t] ON [t].[object_id]=[m].[object_id] LEFT JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[t].[schema_id];';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Sql=N'USE '+QUOTENAME(@DbB)+N'; '
            +N'INSERT [#RlsMaskExpected_securityPolicies] SELECT DB_ID(),DB_NAME(),[p].[object_id],[p].[name],[p].[schema_id],[s].[name],[p].[is_enabled],[p].[is_not_for_replication],[p].[uses_database_collation],[p].[is_schemabinding_enabled],[p].[create_date],[p].[modify_date] FROM [sys].[security_policies] AS [p] LEFT JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[p].[schema_id]; '
            +N'INSERT [#RlsMaskExpected_securityPredicates] SELECT DB_ID(),DB_NAME(),[p].[object_id],[p].[predicate_id],[p].[target_object_id],[p].[predicate_type],[p].[predicate_type_desc],[p].[operation],[p].[operation_desc] FROM [sys].[security_predicates] AS [p]; '
            +N'INSERT [#RlsMaskExpected_maskedColumns] SELECT DB_ID(),DB_NAME(),[m].[object_id],[m].[column_id],[s].[name],[t].[name],[m].[name],[m].[is_masked] FROM [sys].[masked_columns] AS [m] LEFT JOIN [sys].[tables] AS [t] ON [t].[object_id]=[m].[object_id] LEFT JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[t].[schema_id];';
        EXEC [master].[sys].[sp_executesql] @Sql;

        -- Assert all three synthetic catalog sources and exact database binding.
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@MaxZeilen=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
           OR JSON_VALUE(@Json,N'$.meta.resultName')<>N'RowLevelSecurityAndMaskingInventory'
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPolicies'))<>2
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPredicates'))<>2
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.maskedColumns'))<>2
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.databaseContext'))<>1
           OR JSON_VALUE(@Json,N'$.databaseContext[0].DatabaseName')<>@DbA
           OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.databaseContext[0].DatabaseId'))<>DB_ID(@DbA)
           OR JSON_VALUE(@Json,N'$.databaseContext[0].ContextStatus')<>N'AVAILABLE_LIMITED'
           OR JSON_VALUE(@Json,N'$.securityPolicies[0].IsSchemabindingEnabled') IS NULL
           OR JSON_QUERY(@Json,N'$.securityPolicies')<>(SELECT * FROM [#RlsMaskExpected_securityPolicies] WHERE [DatabaseName]=@DbA ORDER BY [DatabaseId],[PolicyObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.securityPredicates')<>(SELECT * FROM [#RlsMaskExpected_securityPredicates] WHERE [DatabaseName]=@DbA ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.maskedColumns')<>(SELECT * FROM [#RlsMaskExpected_maskedColumns] WHERE [DatabaseName]=@DbA ORDER BY [DatabaseId],[ObjectId],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR @Json LIKE N'%EXAMPLE_NO_LEAK_PREDICATE_TOKEN%'
           OR @Json LIKE N'%NO_LEAK_MASK_TOKEN%'
           OR @Json LIKE N'%predicate_definition%'
           OR @Json LIKE N'%masking_function%'
            THROW 57220,N'RLS and masking independent catalog-value/privacy contract mismatch.',1;
        IF NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey]='SECURITY_POLICIES' AND [StatusCode]='AVAILABLE_LIMITED' AND [ObservedRows]=2 AND [ReturnedRows]=2 AND [IsLimited]=0)
            THROW 57221,N'RLS and masking source status is incomplete.',1;
        IF EXISTS(SELECT [SourceKey] FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND ([StatusCode]<>'AVAILABLE_LIMITED' OR [ObservedRows]<>[ReturnedRows] OR [IsLimited]<>0))
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>4
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
            THROW 57229,N'RLS and masking source/warning counts or values mismatch.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.securityPolicies') AS [r] CROSS APPLY OPENJSON([r].[value]) AS [f] WHERE [f].[key] IN(N'PredicateDefinition',N'predicate_definition',N'MaskingFunction',N'masking_function'))
            THROW 57227,N'RLS and masking schema exposes a forbidden expression field.',1;
        SET @PositiveJson=@Json;

        -- Omitted @MaxZeilen uses the reviewed default of 1000 without truncating these fixture rows.
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
           OR JSON_QUERY(@Json,N'$.securityPolicies')<>JSON_QUERY(@PositiveJson,N'$.securityPolicies')
           OR JSON_QUERY(@Json,N'$.securityPredicates')<>JSON_QUERY(@PositiveJson,N'$.securityPredicates')
           OR JSON_QUERY(@Json,N'$.maskedColumns')<>JSON_QUERY(@PositiveJson,N'$.maskedColumns')
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND ([ObservedRows]<>2 OR [ReturnedRows]<>2 OR [IsLimited]<>0))
            THROW 57235,N'RLS and masking default output-limit contract mismatch.',1;

        -- Empty synthetic database remains an available limited observation.
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=QUOTENAME(@DbEmpty),@MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N'$.meta.statusCode')<>'AVAILABLE_LIMITED'
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPolicies'))<>0
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPredicates'))<>0
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.maskedColumns'))<>0
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.warnings'))=0
            THROW 57222,N'RLS and masking empty-visible-source contract mismatch.',1;

        -- The global per-inventory limit caps catalog rows across two populated databases.
        SELECT @FirstDatabaseId=MIN([DatabaseId]) FROM (VALUES(DB_ID(@DbA)),(DB_ID(@DbB))) AS [v]([DatabaseId]);
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@NamesBoth,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0;
        IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPolicies'))<>1
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPredicates'))<>1
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.maskedColumns'))<>1
           OR JSON_VALUE(@Json,N'$.securityPolicies[0].DatabaseName')<>@DbA
           OR JSON_VALUE(@Json,N'$.securityPredicates[0].DatabaseName')<>@DbA
           OR JSON_VALUE(@Json,N'$.maskedColumns[0].DatabaseName')<>@DbA
           OR JSON_QUERY(@Json,N'$.securityPolicies')<>(SELECT TOP(1) * FROM [#RlsMaskExpected_securityPolicies] ORDER BY [DatabaseId],[PolicyObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.securityPredicates')<>(SELECT TOP(1) * FROM [#RlsMaskExpected_securityPredicates] ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.maskedColumns')<>(SELECT TOP(1) * FROM [#RlsMaskExpected_maskedColumns] ORDER BY [DatabaseId],[ObjectId],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[SourceKey] varchar(64) N'$.SourceKey',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND [IsLimited]=1)<>6
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[SourceKey] varchar(64) N'$.SourceKey',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND [IsLimited]=0)<>0
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[SourceKey] varchar(64) N'$.SourceKey',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND ([ObservedRows]<>2 OR [ReturnedRows]<>CASE WHEN [DatabaseId]=@FirstDatabaseId THEN 1 ELSE 0 END OR [IsLimited]<>1))
            THROW 57223,N'RLS and masking global output limit mismatch.',1;

        -- Exercise all output paths and verify caller session/transaction state.
        SET LOCK_TIMEOUT 1731; SET XACT_ABORT ON; BEGIN TRANSACTION;
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @DatabaseNames=@Names,@MaxZeilen=0,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>1731 OR (@@OPTIONS&16384)=0 OR ISJSON(@Json)<>1
           OR JSON_QUERY(@Json,N'$.databaseContext')<>JSON_QUERY(@PositiveJson,N'$.databaseContext')
           OR (SELECT [ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail] FROM OPENJSON(@Json,N'$.moduleStatus') WITH([ModuleName] nvarchar(128) N'$.ModuleName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail') FOR JSON PATH,INCLUDE_NULL_VALUES)<>(SELECT [ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail] FROM OPENJSON(@PositiveJson,N'$.moduleStatus') WITH([ModuleName] nvarchar(128) N'$.ModuleName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail') FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.securityPolicies')<>JSON_QUERY(@PositiveJson,N'$.securityPolicies')
           OR JSON_QUERY(@Json,N'$.securityPredicates')<>JSON_QUERY(@PositiveJson,N'$.securityPredicates')
           OR JSON_QUERY(@Json,N'$.maskedColumns')<>JSON_QUERY(@PositiveJson,N'$.maskedColumns')
           OR (SELECT [DatabaseId],[DatabaseName],[SourceKey],[SourceKind],[StatusCode],[VisibilityScope],[ObservedRows],[ReturnedRows],[IsLimited],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[DatabaseName] nvarchar(128) N'$.DatabaseName',[SourceKey] varchar(64) N'$.SourceKey',[SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage') ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)<>(SELECT [DatabaseId],[DatabaseName],[SourceKey],[SourceKind],[StatusCode],[VisibilityScope],[ObservedRows],[ReturnedRows],[IsLimited],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@PositiveJson,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[DatabaseName] nvarchar(128) N'$.DatabaseName',[SourceKey] varchar(64) N'$.SourceKey',[SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage') ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.warnings')<>JSON_QUERY(@PositiveJson,N'$.warnings')
            THROW 57224,N'RLS and masking CONSOLE JSON value parity or caller-state contract mismatch.',1;
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @DatabaseNames=@Names,@MaxZeilen=0,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF @@TRANCOUNT<>1 OR @@LOCK_TIMEOUT<>1731 OR (@@OPTIONS&16384)=0 OR ISJSON(@Json)<>1
           OR JSON_QUERY(@Json,N'$.databaseContext')<>JSON_QUERY(@PositiveJson,N'$.databaseContext')
           OR (SELECT [ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail] FROM OPENJSON(@Json,N'$.moduleStatus') WITH([ModuleName] nvarchar(128) N'$.ModuleName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail') FOR JSON PATH,INCLUDE_NULL_VALUES)<>(SELECT [ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail] FROM OPENJSON(@PositiveJson,N'$.moduleStatus') WITH([ModuleName] nvarchar(128) N'$.ModuleName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail') FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.securityPolicies')<>JSON_QUERY(@PositiveJson,N'$.securityPolicies')
           OR JSON_QUERY(@Json,N'$.securityPredicates')<>JSON_QUERY(@PositiveJson,N'$.securityPredicates')
           OR JSON_QUERY(@Json,N'$.maskedColumns')<>JSON_QUERY(@PositiveJson,N'$.maskedColumns')
           OR (SELECT [DatabaseId],[DatabaseName],[SourceKey],[SourceKind],[StatusCode],[VisibilityScope],[ObservedRows],[ReturnedRows],[IsLimited],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@Json,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[DatabaseName] nvarchar(128) N'$.DatabaseName',[SourceKey] varchar(64) N'$.SourceKey',[SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage') ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)<>(SELECT [DatabaseId],[DatabaseName],[SourceKey],[SourceKind],[StatusCode],[VisibilityScope],[ObservedRows],[ReturnedRows],[IsLimited],[ErrorNumber],[ErrorMessage] FROM OPENJSON(@PositiveJson,N'$.sourceStatus') WITH([DatabaseId] int N'$.DatabaseId',[DatabaseName] nvarchar(128) N'$.DatabaseName',[SourceKey] varchar(64) N'$.SourceKey',[SourceKind] varchar(16) N'$.SourceKind',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage') ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)
           OR JSON_QUERY(@Json,N'$.warnings')<>JSON_QUERY(@PositiveJson,N'$.warnings')
            THROW 57225,N'RLS and masking RAW JSON value parity or caller-state contract mismatch.',1;
        COMMIT TRANSACTION;
        DECLARE @Map nvarchar(max)=N'{"moduleStatus":"#RlsMaskOutput_moduleStatus","databaseContext":"#RlsMaskOutput_databaseContext","securityPolicies":"#RlsMaskOutput_securityPolicies","securityPredicates":"#RlsMaskOutput_securityPredicates","maskedColumns":"#RlsMaskOutput_maskedColumns","sourceStatus":"#RlsMaskOutput_sourceStatus","warnings":"#RlsMaskOutput_warnings"}';
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @DatabaseNames=@NamesBoth,@MaxZeilen=NULL,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF (SELECT COUNT(*) FROM [#RlsMaskOutput_moduleStatus])<>1
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_databaseContext])<>2
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_securityPolicies])<>4
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_securityPredicates])<>4
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_maskedColumns])<>4
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_sourceStatus])<>8
           OR (SELECT COUNT(*) FROM [#RlsMaskOutput_warnings])<>1
           OR NOT EXISTS(SELECT 1 FROM [#RlsMaskOutput_securityPolicies] WHERE [IsSchemabindingEnabled] IS NOT NULL)
           OR ISJSON(@Json)<>1 OR @Json LIKE N'%EXAMPLE_NO_LEAK_PREDICATE_TOKEN%' OR @Json LIKE N'%NO_LEAK_MASK_TOKEN%'
           OR (SELECT * FROM [#RlsMaskOutput_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.moduleStatus')
           OR (SELECT * FROM [#RlsMaskOutput_databaseContext] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.databaseContext')
           OR (SELECT * FROM [#RlsMaskOutput_securityPolicies] ORDER BY [DatabaseId],[PolicyObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.securityPolicies')
           OR (SELECT * FROM [#RlsMaskOutput_securityPredicates] ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.securityPredicates')
           OR (SELECT * FROM [#RlsMaskOutput_maskedColumns] ORDER BY [DatabaseId],[ObjectId],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.maskedColumns')
           OR (SELECT * FROM [#RlsMaskOutput_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.sourceStatus')
           OR (SELECT * FROM [#RlsMaskOutput_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES)<>JSON_QUERY(@Json,N'$.warnings')
            THROW 57228,N'RLS and masking TABLE schema, values, or privacy contract mismatch.',1;

        -- A minimally privileged caller sees an empty but successful visible subset.
        SELECT @RestrictedLogin=N'ExampleRlsMaskReader_'+@Suffix,@RestrictedUser=N'ExampleRlsMaskReader_'+@Suffix,
               @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
        IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RestrictedLogin)
            THROW 57230,N'RLS and masking restricted-caller fixture collision.',1;
        SET @Sql=N'CREATE LOGIN '+QUOTENAME(@RestrictedLogin)+N' WITH PASS'+N'WORD='+QUOTENAME(@Credential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Credential=NULL;
        SET @Sql=N'CREATE USER '+QUOTENAME(@RestrictedUser)+N' FOR LOGIN '+QUOTENAME(@RestrictedLogin)+N'; GRANT EXECUTE ON [monitor].[USP_RowLevelSecurityAndMaskingInventory] TO '+QUOTENAME(@RestrictedUser)+N'; GRANT EXECUTE ON [monitor].[USP_PrepareDatabaseCandidates] TO '+QUOTENAME(@RestrictedUser)+N';';
        EXEC [sys].[sp_executesql] @Sql;
        SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; CREATE USER '+QUOTENAME(@RestrictedUser)+N' FOR LOGIN '+QUOTENAME(@RestrictedLogin)+N'; GRANT CONNECT TO '+QUOTENAME(@RestrictedUser)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Sql=N'GRANT VIEW ANY DATABASE TO '+QUOTENAME(@RestrictedLogin)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
        EXECUTE AS LOGIN = @RestrictedLogin; SET @Impersonating=1;
        EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        REVERT; SET @Impersonating=0;
        IF @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
           OR JSON_VALUE(@Json,N'$.databaseContext[0].DatabaseName')<>@DbA
           OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.databaseContext[0].DatabaseId'))<>DB_ID(@DbA)
           OR JSON_VALUE(@Json,N'$.databaseContext[0].ContextStatus')<>N'AVAILABLE_LIMITED'
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey]='SECURITY_POLICIES' AND [StatusCode]='AVAILABLE_LIMITED' AND [VisibilityScope]='VISIBLE_ONLY' AND [ObservedRows]=0 AND [ReturnedRows]=0 AND [IsLimited]=0)
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey]='SECURITY_PREDICATES' AND [StatusCode]='AVAILABLE_LIMITED' AND [VisibilityScope]='VISIBLE_ONLY' AND [ObservedRows]=0 AND [ReturnedRows]=0 AND [IsLimited]=0)
           OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[IsLimited] bit N'$.IsLimited') WHERE [SourceKey]='MASKED_COLUMNS' AND [StatusCode]='AVAILABLE_LIMITED' AND [VisibilityScope]='VISIBLE_ONLY' AND [ObservedRows]=0 AND [ReturnedRows]=0 AND [IsLimited]=0)
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPolicies'))<>0
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.securityPredicates'))<>0
           OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.maskedColumns'))<>0
            THROW 57231,N'RLS and masking restricted metadata visibility contract mismatch.',1;
        DECLARE [RlsMaskDeniedSources] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [CatalogObject],[SourceKey] FROM (VALUES(N'security_policies','SECURITY_POLICIES'),(N'security_predicates','SECURITY_PREDICATES'),(N'masked_columns','MASKED_COLUMNS')) AS [v]([CatalogObject],[SourceKey]);
        OPEN [RlsMaskDeniedSources]; FETCH NEXT FROM [RlsMaskDeniedSources] INTO @CatalogObject,@ExpectedSource;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; DENY SELECT ON [sys].'+QUOTENAME(@CatalogObject)+N' TO '+QUOTENAME(@RestrictedUser)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
            EXECUTE AS LOGIN = @RestrictedLogin; SET @Impersonating=1;
            EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory]
                @DatabaseNames=@Names,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
                @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
            REVERT; SET @Impersonating=0;
            IF @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@Json)<>1
               OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows',[ReturnedRows] bigint N'$.ReturnedRows',[ErrorNumber] int N'$.ErrorNumber') WHERE [SourceKey]=@ExpectedSource AND [StatusCode]='SOURCE_UNAVAILABLE' AND [VisibilityScope]='UNPROVEN' AND [ObservedRows] IS NULL AND [ReturnedRows] IS NULL AND [ErrorNumber]=229)
               OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceKey] varchar(64) N'$.SourceKey',[StatusCode] varchar(40) N'$.StatusCode',[VisibilityScope] varchar(32) N'$.VisibilityScope',[ObservedRows] bigint N'$.ObservedRows') WHERE [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND [SourceKey]<>@ExpectedSource AND [StatusCode]='AVAILABLE_LIMITED' AND [VisibilityScope]='VISIBLE_ONLY' AND [ObservedRows]=0)<>2
               OR @Json LIKE N'%EXAMPLE_NO_LEAK_PREDICATE_TOKEN%' OR @Json LIKE N'%NO_LEAK_MASK_TOKEN%'
                THROW 57234,N'RLS and masking isolated source permission-failure contract mismatch.',1;
            SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; REVOKE SELECT ON [sys].'+QUOTENAME(@CatalogObject)+N' FROM '+QUOTENAME(@RestrictedUser)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql;
            FETCH NEXT FROM [RlsMaskDeniedSources] INTO @CatalogObject,@ExpectedSource;
        END;
        CLOSE [RlsMaskDeniedSources]; DEALLOCATE [RlsMaskDeniedSources];
        SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; DROP USER '+QUOTENAME(@RestrictedUser)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @Sql=N'DROP USER '+QUOTENAME(@RestrictedUser)+N'; REVOKE VIEW ANY DATABASE FROM '+QUOTENAME(@RestrictedLogin)+N'; DROP LOGIN '+QUOTENAME(@RestrictedLogin)+N';';
        EXEC [master].[sys].[sp_executesql] @Sql;
        SET @RestrictedLogin=NULL; SET @RestrictedUser=NULL;
        SET LOCK_TIMEOUT @OriginalLock; IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;

        -- A negative limit is rejected before any catalog query and returns no JSON.
        EXEC @Return=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
           OR @Message LIKE N'%EXAMPLE_NO_LEAK_PREDICATE_TOKEN%' OR @Message LIKE N'%NO_LEAK_MASK_TOKEN%'
            THROW 57226,N'RLS and masking negative limit contract mismatch.',1;
        EXEC @Return=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@LockTimeoutMs=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
            THROW 57232,N'RLS and masking NULL lock-timeout contract mismatch.',1;
        EXEC @Return=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
            @DatabaseNames=@Names,@LockTimeoutMs=60001,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
            @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
            THROW 57233,N'RLS and masking excessive lock-timeout contract mismatch.',1;
        SET @NativeTableCases=1;
    END TRY
    BEGIN CATCH
        IF @Impersonating=1 REVERT;
        IF @@TRANCOUNT>@OriginalTx ROLLBACK TRANSACTION;
        SET LOCK_TIMEOUT @OriginalLock; IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        BEGIN TRY
            IF @RestrictedLogin IS NOT NULL AND DB_ID(@DbA) IS NOT NULL BEGIN SET @Sql=N'USE '+QUOTENAME(@DbA)+N'; IF USER_ID('+QUOTENAME(@RestrictedUser,'''')+N') IS NOT NULL DROP USER '+QUOTENAME(@RestrictedUser)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
            IF @RestrictedLogin IS NOT NULL AND USER_ID(@RestrictedUser) IS NOT NULL BEGIN SET @Sql=N'DROP USER '+QUOTENAME(@RestrictedUser)+N';'; EXEC [sys].[sp_executesql] @Sql; END;
            IF @RestrictedLogin IS NOT NULL AND SUSER_ID(@RestrictedLogin) IS NOT NULL BEGIN SET @Sql=N'REVOKE VIEW ANY DATABASE FROM '+QUOTENAME(@RestrictedLogin)+N'; DROP LOGIN '+QUOTENAME(@RestrictedLogin)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
            IF DB_ID(@DbA) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbA)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbA)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
            IF DB_ID(@DbB) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbB)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbB)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
            IF DB_ID(@DbEmpty) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbEmpty)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbEmpty)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
        END TRY BEGIN CATCH THROW 57290,N'RLS and masking fixture cleanup failed.',1; END CATCH;
        THROW;
    END CATCH;
    IF DB_ID(@DbA) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbA)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbA)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    IF DB_ID(@DbB) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbB)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbB)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    IF DB_ID(@DbEmpty) IS NOT NULL BEGIN SET @Sql=N'ALTER DATABASE '+QUOTENAME(@DbEmpty)+N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '+QUOTENAME(@DbEmpty)+N';'; EXEC [master].[sys].[sp_executesql] @Sql; END;
    PRINT N'RLS_MASKING_RUNTIME_CONTRACT_PASS';
END;
GO
EXEC [#ExampleRlsMaskContract];
GO
DROP PROCEDURE [#ExampleRlsMaskContract];
GO
