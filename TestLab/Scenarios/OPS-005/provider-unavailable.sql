/*
OPS-005: Prüft einen fehlenden Provider auf einem eigenen Windows-SQL-2025-Run.
Der aufrufende Runner bindet OperationId, Datenbankmarker und Quelldefinition.
Dieser manuelle Fall gehört nicht zum bestehenden Linux-Adaptervertrag 120.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @Operation uniqueidentifier = TRY_CONVERT(uniqueidentifier, @OperationId);
IF @Operation IS NULL OR @Operation = '00000000-0000-0000-0000-000000000000'
    THROW 54890, N'OPS005_OPERATION_REQUIRED', 1;
IF COALESCE(CONVERT(nvarchar(36), (SELECT [value] FROM sys.extended_properties
    WHERE [class]=0 AND [major_id]=0 AND [minor_id]=0 AND [name]=N'SQLANALYZE.Ops005Operation')), N'')
    <> CONVERT(nvarchar(36), @Operation)
    THROW 54890, N'OPS005_DATABASE_OWNERSHIP_REQUIRED', 2;
IF COALESCE(CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')), 0) <> 17
    OR COALESCE((SELECT [compatibility_level] FROM sys.databases WHERE [database_id]=DB_ID()), 0) <> 170
    OR COALESCE(CONVERT(nvarchar(128), SERVERPROPERTY(N'Collation')), N'') <> N'SQL_Latin1_General_CP1_CS_AS'
    OR COALESCE(CONVERT(nvarchar(128), DATABASEPROPERTYEX(N'master', N'Collation')), N'') <> N'SQL_Latin1_General_CP1_CS_AS'
    OR COALESCE(CONVERT(nvarchar(128), DATABASEPROPERTYEX(N'tempdb', N'Collation')), N'') <> N'SQL_Latin1_General_CP1_CS_AS'
    OR COALESCE(CONVERT(nvarchar(128), DATABASEPROPERTYEX(DB_NAME(), N'Collation')), N'') <> N'SQL_Latin1_General_CP1_CS_AS'
    OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1 OR @@TRANCOUNT <> 0
    THROW 54890, N'OPS005_NATIVE_PREREQUISITE_FAILED', 3;
IF EXISTS (SELECT 1 FROM sys.databases WHERE [database_id]>4 AND [database_id]<>DB_ID())
    OR EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]<>0)
    THROW 54890, N'OPS005_ISOLATION_REQUIRED', 4;

DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_LinkedServerAnalysis'));
DECLARE @DefinitionStart int=CHARINDEX(N'CREATE OR ALTER PROCEDURE', @Definition);
IF COALESCE(@DefinitionStart,0)=0
BEGIN
    SET @DefinitionStart=CHARINDEX(N'CREATE   PROCEDURE [monitor].[USP_LinkedServerAnalysis]',@Definition);
    IF @DefinitionStart>0
        SET @Definition=STUFF(@Definition,@DefinitionStart,DATALENGTH(N'CREATE   ')/2,N'CREATE OR ALTER ');
END;
IF @DefinitionStart IS NULL OR @DefinitionStart=0
    THROW 54890, N'OPS005_DEFINITION_MISSING', 5;
SET @Definition=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM
    REPLACE(SUBSTRING(@Definition, @DefinitionStart, LEN(@Definition)), NCHAR(13)+NCHAR(10), NCHAR(10)));
IF @ExpectedDefinitionHash IS NULL OR DATALENGTH(@ExpectedDefinitionHash)<>32
    OR HASHBYTES('SHA2_256', @Definition)<>@ExpectedDefinitionHash
    THROW 54890, N'OPS005_DEFINITION_CHANGED', 6;
DECLARE @Abi TABLE([id] int, [name] sysname, [type] sysname, [length] smallint, [output] bit);
INSERT @Abi VALUES
    (1,N'@ConnectivityTestEnabled',N'bit',1,0),(2,N'@HighImpactConfirmed',N'bit',1,0),
    (3,N'@MaxZeilen',N'int',4,0),(4,N'@ResultSetArt',N'varchar',16,0),
    (5,N'@ResultTablesJson',N'nvarchar',-1,0),(6,N'@JsonErzeugen',N'bit',1,0),
    (7,N'@Json',N'nvarchar',-1,1),(8,N'@PrintMeldungen',N'bit',1,0),(9,N'@Hilfe',N'bit',1,0),
    (10,N'@StatusCodeOut',N'varchar',40,1),(11,N'@IsPartialOut',N'bit',1,1),
    (12,N'@ErrorNumberOut',N'int',4,1),(13,N'@ErrorMessageOut',N'nvarchar',4096,1);
IF (SELECT COUNT(*) FROM sys.parameters WHERE [object_id]=OBJECT_ID(N'monitor.USP_LinkedServerAnalysis'))<>13
    OR EXISTS (SELECT 1 FROM @Abi AS a LEFT JOIN sys.parameters AS p
        ON p.[object_id]=OBJECT_ID(N'monitor.USP_LinkedServerAnalysis') AND p.[parameter_id]=a.[id]
        WHERE p.[name] IS NULL OR p.[name]<>a.[name] OR TYPE_NAME(p.[system_type_id])<>a.[type]
            OR p.[max_length]<>a.[length] OR p.[is_output]<>a.[output])
    THROW 54890, N'OPS005_ABI_CHANGED', 7;

DECLARE @Name sysname=N'ExampleOps005_'+REPLACE(CONVERT(nvarchar(36),@Operation),N'-',N'');
DECLARE @Provider nvarchar(128)=N'ExampleUnavailableOleDbProvider_'+REPLACE(CONVERT(nvarchar(36),@Operation),N'-',N'');
DECLARE @Product nvarchar(128)=N'ExampleSyntheticUnavailableProvider', @Source nvarchar(4000)=N'example-provider.invalid';
DECLARE @OwnId int, @OwnModified datetime, @AddReturn int, @DropReturn int, @Created bit=0;
DECLARE @SutCalls int=0, @Preprobes int=0, @NativeError int, @Case int=1;
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048);
DECLARE @Connectivity bit, @HighImpact bit, @ExpectedStatus varchar(40), @ExpectedConnectivity varchar(40);
DECLARE @ExpectedPartial bit, @BeforeLock int, @BeforeOptions int, @BeforeTran int;
DECLARE @CaseEvidence TABLE([CaseNumber] int, [StatusCode] varchar(40), [IsPartial] bit,
    [ErrorNumber] int, [Json] nvarchar(max), [LockTimeout] int, [SessionOptions] int, [TranCount] int);
DECLARE @OriginalError int, @OriginalState int, @OriginalMessage nvarchar(2048), @CleanupError int;
DECLARE @Cleanup varchar(40)='NOT_CREATED';

BEGIN TRY
    SET @Cleanup='ADD_RESULT_NOT_VERIFIED';
    EXEC @AddReturn=master.dbo.sp_addlinkedserver @server=@Name, @srvproduct=@Product, @provider=@Provider, @datasrc=@Source;
    IF @AddReturn IS NULL OR @AddReturn<>0
        THROW 54891, N'OPS005_PROVIDER_FIXTURE_ADD_FAILED', 1;
    SELECT @OwnId=[server_id], @OwnModified=[modify_date] FROM sys.servers
    WHERE [name]=@Name AND [provider]=@Provider AND [product]=@Product AND [data_source]=@Source AND [is_linked]=1;
    IF @OwnId IS NULL OR @OwnModified IS NULL OR (SELECT COUNT(*) FROM sys.servers WHERE [server_id]<>0)<>1
        THROW 54891, N'OPS005_PROVIDER_FIXTURE_IDENTITY_MISSING', 2;
    SET @Created=1;
    SET @Cleanup='PENDING';

    WHILE @Case<=5
    BEGIN
        IF @Case=5
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId AND [modify_date]=@OwnModified
                AND [name]=@Name AND [provider]=@Provider AND [product]=@Product AND [data_source]=@Source AND [is_linked]=1)
                THROW 54892, N'OPS005_FIXTURE_IDENTITY_LOST', 1;
            EXEC @DropReturn=master.dbo.sp_dropserver @server=@Name, @droplogins='droplogins';
            IF @DropReturn IS NULL OR @DropReturn<>0 OR EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId OR [name]=@Name)
                THROW 54892, N'OPS005_FIXTURE_CLEANUP_FAILED', 2;
            SET @Created=0;
            SET @Cleanup='REMOVED';
            IF EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]<>0)
                THROW 54892, N'OPS005_FINAL_CATALOG_CHANGED', 3;
        END;
        IF @Case<=4 AND ((SELECT COUNT(*) FROM sys.servers WHERE [server_id]<>0)<>1
            OR NOT EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId AND [modify_date]=@OwnModified
                AND [name]=@Name AND [provider]=@Provider AND [product]=@Product AND [data_source]=@Source AND [is_linked]=1))
            THROW 54892, N'OPS005_FOREIGN_OR_CHANGED_FIXTURE', 4;
        IF @Case=4
        BEGIN
            SET @Preprobes=@Preprobes+1;
            BEGIN TRY
                EXEC master.dbo.sp_testlinkedserver @servername=@Name;
            END TRY
            BEGIN CATCH
                SET @NativeError=ERROR_NUMBER();
            END CATCH;
            IF @NativeError IS NULL OR @NativeError NOT IN (7302,7403)
                THROW 54893, N'OPS005_NATIVE_PROVIDER_ERROR_REQUIRED', 1;
            IF (SELECT COUNT(*) FROM sys.servers WHERE [server_id]<>0)<>1
                OR NOT EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId AND [modify_date]=@OwnModified
                    AND [name]=@Name AND [provider]=@Provider AND [product]=@Product AND [data_source]=@Source AND [is_linked]=1)
                THROW 54892, N'OPS005_PREPROBE_IDENTITY_CHANGED', 5;
        END;
        SELECT @Connectivity=CASE WHEN @Case IN (3,4) THEN 1 ELSE 0 END,
            @HighImpact=CASE WHEN @Case IN (2,4) THEN 1 ELSE 0 END,
            @ExpectedStatus=CASE @Case WHEN 3 THEN 'AUTHORIZATION_REQUIRED' WHEN 4 THEN 'AVAILABLE_LIMITED' WHEN 5 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
            @ExpectedPartial=CASE WHEN @Case IN (3,4) THEN 1 ELSE 0 END,
            @ExpectedConnectivity=CASE @Case WHEN 3 THEN 'AUTHORIZATION_REQUIRED' WHEN 4 THEN 'FAILED' ELSE 'NOT_EXECUTED' END,
            @Json=NULL, @Status=NULL, @Partial=NULL, @ErrorNumber=NULL, @ErrorMessage=NULL,
            @BeforeLock=@@LOCK_TIMEOUT, @BeforeOptions=@@OPTIONS, @BeforeTran=@@TRANCOUNT;
        SET @SutCalls=@SutCalls+1;
        EXEC monitor.USP_LinkedServerAnalysis
            @ConnectivityTestEnabled=@Connectivity, @HighImpactConfirmed=@HighImpact, @MaxZeilen=40,
            @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0,
            @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
        INSERT @CaseEvidence VALUES (@Case,@Status,@Partial,@ErrorNumber,@Json,@@LOCK_TIMEOUT,@@OPTIONS,@@TRANCOUNT);
        IF @BeforeLock<>@@LOCK_TIMEOUT OR @BeforeOptions<>@@OPTIONS OR @BeforeTran<>@@TRANCOUNT
            THROW 54894, N'OPS005_CALLER_STATE_CHANGED', 1;
        IF @Status IS NULL OR @Status<>@ExpectedStatus OR @Partial IS NULL OR @Partial<>@ExpectedPartial
            OR COALESCE(ISJSON(@Json, ARRAY),0)<>1
            THROW 54894, N'OPS005_GLOBAL_OUTPUT_MISMATCH', 2;
        IF @Case=5
        BEGIN
            IF @Json<>N'[]' OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
                THROW 54894, N'OPS005_EMPTY_DEFAULT_MISMATCH', 3;
        END
        ELSE
        BEGIN
            IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>1
                OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$[0]'))<>9
                OR EXISTS (SELECT 1 FROM OPENJSON(@Json,N'$[0]') WHERE [key] NOT IN
                    (N'ServerName',N'Product',N'Provider',N'IsDataAccessEnabled',N'IsRpcOutEnabled',
                     N'IsCollationCompatible',N'ConnectivityStatus',N'StatusCode',N'EvidenceLimit'))
                OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json) WITH
                    ([ServerName] sysname, [Product] nvarchar(128), [Provider] nvarchar(128),
                     [IsDataAccessEnabled] bit, [IsRpcOutEnabled] bit, [IsCollationCompatible] bit,
                     [ConnectivityStatus] varchar(40), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)) AS j
                    JOIN sys.servers AS s ON s.[server_id]=@OwnId
                    WHERE j.[ServerName]=@Name AND j.[Provider]=@Provider AND j.[Product]=@Product
                        AND j.[IsDataAccessEnabled]=s.[is_data_access_enabled] AND j.[IsRpcOutEnabled]=s.[is_rpc_out_enabled]
                        AND j.[IsCollationCompatible]=s.[is_collation_compatible]
                        AND j.[ConnectivityStatus]=@ExpectedConnectivity
                        AND j.[StatusCode]=CASE WHEN @Case=4 THEN 'SOURCE_UNAVAILABLE' ELSE 'AVAILABLE' END
                        AND j.[EvidenceLimit] IS NOT NULL
                        AND (@Case<>4 OR LEFT(j.[EvidenceLimit],DATALENGTH(CONCAT(N'Remote-Testfehler ',@NativeError,N': '))/2)
                            =CONCAT(N'Remote-Testfehler ',@NativeError,N': ')))
                THROW 54894, N'OPS005_ROW_OUTPUT_MISMATCH', 4;
            IF (@Case=4 AND (@ErrorNumber IS NULL OR @ErrorNumber<>@NativeError OR @ErrorMessage IS NULL))
                OR (@Case<>4 AND @ErrorNumber IS NOT NULL)
                OR (@Case IN (1,2) AND @ErrorMessage IS NOT NULL)
                OR (@Case=3 AND @ErrorMessage IS NULL)
                THROW 54894, N'OPS005_ERROR_OUTPUT_MISMATCH', 5;
        END;
        SET @Case=@Case+1;
    END;
    IF @SutCalls<>5 OR @Preprobes<>1 OR @Cleanup<>'REMOVED'
        THROW 54894, N'OPS005_ACCEPTANCE_INCOMPLETE', 6;
    SELECT N'OPS005_PROVIDER_ACCEPTANCE' AS [Scope], N'PASSED' AS [Outcome],
        @SutCalls AS [SutCalls], @Preprobes AS [Preprobes], @NativeError AS [NativeError], @Cleanup AS [FixtureCleanup],
        (SELECT * FROM @CaseEvidence ORDER BY [CaseNumber] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [Cases];
END TRY
BEGIN CATCH
    SELECT @OriginalError=ERROR_NUMBER(), @OriginalState=ERROR_STATE(), @OriginalMessage=ERROR_MESSAGE();
    IF @Created=1
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId AND [modify_date]=@OwnModified
            AND [name]=@Name AND [provider]=@Provider AND [product]=@Product AND [data_source]=@Source AND [is_linked]=1)
        BEGIN
            BEGIN TRY
                SET @DropReturn=NULL;
                EXEC @DropReturn=master.dbo.sp_dropserver @server=@Name, @droplogins='droplogins';
                IF @DropReturn IS NULL OR @DropReturn<>0 OR EXISTS (SELECT 1 FROM sys.servers WHERE [server_id]=@OwnId OR [name]=@Name)
                    THROW 54892, N'OPS005_ERROR_CLEANUP_FAILED', 6;
                SET @Cleanup='REMOVED_AFTER_FAILURE';
            END TRY
            BEGIN CATCH
                SELECT @CleanupError=ERROR_NUMBER(), @Cleanup='RECOVERY_REQUIRED';
            END CATCH;
        END
        ELSE SET @Cleanup='IDENTITY_LOST_NOT_DROPPED';
    END;
    SELECT N'OPS005_PROVIDER_ACCEPTANCE' AS [Scope], N'FAILED' AS [Outcome], @SutCalls AS [SutCalls],
        @Preprobes AS [Preprobes], @AddReturn AS [AddReturn], @OriginalError AS [OriginalError],
        @OriginalState AS [OriginalState], @OriginalMessage AS [OriginalMessage],
        @Cleanup AS [FixtureCleanup], @CleanupError AS [CleanupError],
        (SELECT * FROM @CaseEvidence ORDER BY [CaseNumber] FOR JSON PATH, INCLUDE_NULL_VALUES) AS [Cases];
    THROW;
END CATCH;
