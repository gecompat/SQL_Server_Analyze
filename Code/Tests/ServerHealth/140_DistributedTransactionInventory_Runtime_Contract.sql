USE [DeineDatenbank];
GO
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57400,N'MSDTC contract requires an isolated SQL Server 2025 sysadmin target without an ambient transaction.',1;
IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<>17
    THROW 57401,N'MSDTC runtime contract is scoped to SQL Server 2025 CI.',1;
GO
DECLARE @OriginalLock int=@@LOCK_TIMEOUT,
    @OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
    @OriginalTx int=@@TRANCOUNT,
    @Json nvarchar(max),@JsonTable nvarchar(max),@JsonNone nvarchar(max),@JsonConsole nvarchar(max),@JsonRaw nvarchar(max),
    @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,@Map nvarchar(max),
    @RestrictedLogin sysname,@RestrictedUser sysname,@Credential nvarchar(128),@Suffix nvarchar(32),@Sql nvarchar(max),@Impersonating bit=0,@MadeRestrictedLogin bit=0,@MadeRestrictedUser bit=0,
    @ConsoleStatus varchar(40),@ConsolePartial bit,@ConsoleProductMajor nvarchar(128),@ConsoleConfigured int,@ConsoleRunning int,
    @ConsoleLinked bigint,@ConsoleActive bigint,@ConsoleDetail nvarchar(1000),@NativeLinkedRows bigint,@NativeActiveRows bigint,@RestoreLock nvarchar(100);
CREATE TABLE [#MdtcOut_moduleStatus]([Seed] int NULL);
CREATE TABLE [#MdtcOut_serverContext]([Seed] int NULL);
CREATE TABLE [#MdtcOut_promotionConfiguration]([Seed] int NULL);
CREATE TABLE [#MdtcOut_linkedServerPromotion]([Seed] int NULL);
CREATE TABLE [#MdtcOut_activeDistributedTransactions]([Seed] int NULL);
CREATE TABLE [#MdtcOut_sourceStatus]([Seed] int NULL);
CREATE TABLE [#MdtcOut_warnings]([Seed] int NULL);
CREATE TABLE [#MdtcExpected_moduleStatus]([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcExpected_serverContext]([ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
CREATE TABLE [#MdtcExpected_promotionConfiguration]([ConfiguredValue] int NULL,[RunningValue] int NULL,[IsDynamic] bit NOT NULL);
CREATE TABLE [#MdtcExpected_linkedServerPromotion]([ServerId] int NOT NULL,[RemoteProcTransactionPromotionEnabled] bit NOT NULL,[ModifiedAt] datetime NULL);
CREATE TABLE [#MdtcExpected_activeDistributedTransactions]([TransactionId] bigint NOT NULL,[TransactionType] int NOT NULL,[TransactionBeginTime] datetime NULL,[TransactionState] int NOT NULL);
CREATE TABLE [#MdtcExpected_sourceStatus]([SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CaptureStartedAtUtc] datetime2(3) NOT NULL,[CaptureEndedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowsReturned] bigint NULL,[LimitApplied] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[VisibilityLimit] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcExpected_warnings]([WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcNativeConfig]([ConfiguredValue] int NULL,[RunningValue] int NULL,[IsDynamic] bit NOT NULL);
CREATE TABLE [#MdtcModeJson]([ModeName] varchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Payload] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcModePayload]([ModeName] varchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[moduleStatus] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[serverContext] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[promotionConfiguration] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[linkedServerPromotion] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[activeDistributedTransactions] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[sourceStatus] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[warnings] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcNativeLinked]([ServerId] int NOT NULL,[RemoteProcTransactionPromotionEnabled] bit NOT NULL,[ModifiedAt] datetime NULL);
CREATE TABLE [#MdtcNativeActive]([TransactionId] bigint NOT NULL,[TransactionType] int NOT NULL,[TransactionBeginTime] datetime NULL,[TransactionState] int NOT NULL);
CREATE TABLE [#MdtcConsole]([StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ConfiguredValue] int NULL,[RunningValue] int NULL,[LinkedServerRowsReturned] bigint NOT NULL,[ActiveTransactionRowsReturned] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#MdtcPhysicalPairs]([TargetName] sysname NOT NULL,[ExpectedName] sysname NOT NULL);
INSERT [#MdtcPhysicalPairs] VALUES
 (N'#MdtcOut_moduleStatus',N'#MdtcExpected_moduleStatus'),
 (N'#MdtcOut_serverContext',N'#MdtcExpected_serverContext'),
 (N'#MdtcOut_promotionConfiguration',N'#MdtcExpected_promotionConfiguration'),
 (N'#MdtcOut_linkedServerPromotion',N'#MdtcExpected_linkedServerPromotion'),
 (N'#MdtcOut_activeDistributedTransactions',N'#MdtcExpected_activeDistributedTransactions'),
 (N'#MdtcOut_sourceStatus',N'#MdtcExpected_sourceStatus'),
 (N'#MdtcOut_warnings',N'#MdtcExpected_warnings');
SELECT @Map=N'{"moduleStatus":"#MdtcOut_moduleStatus","serverContext":"#MdtcOut_serverContext","promotionConfiguration":"#MdtcOut_promotionConfiguration","linkedServerPromotion":"#MdtcOut_linkedServerPromotion","activeDistributedTransactions":"#MdtcOut_activeDistributedTransactions","sourceStatus":"#MdtcOut_sourceStatus","warnings":"#MdtcOut_warnings"}';
BEGIN TRY
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';';
    SET LOCK_TIMEOUT 137;
    SET XACT_ABORT ON;
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1000,@ResultSetArt='TABLE',@ResultTablesJson=@Map,
        @JsonErzeugen=1,@Json=@JsonTable OUTPUT,@PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@JsonTable)<>1
       OR @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0
        THROW 57402,N'MSDTC TABLE capture or caller-state preservation failed.',1;
    IF (SELECT COUNT(*) FROM [#MdtcOut_moduleStatus])<>1 OR (SELECT COUNT(*) FROM [#MdtcOut_serverContext])<>1
       OR (SELECT COUNT(*) FROM [#MdtcOut_promotionConfiguration])<>1
       OR (SELECT COUNT(*) FROM [#MdtcOut_sourceStatus])<>3
        THROW 57403,N'MSDTC baseline resultset cardinality contract failed.',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@JsonTable))<>8
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonTable,N'$.moduleStatus'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonTable,N'$.serverContext'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonTable,N'$.promotionConfiguration'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@JsonTable,N'$.sourceStatus'))<>3
        THROW 57404,N'MSDTC JSON envelope or required SQL-visible arrays are incomplete.',1;
    INSERT [#MdtcModeJson] VALUES('TABLE',@JsonTable);
    INSERT [#MdtcExpected_moduleStatus]
    SELECT * FROM OPENJSON(@JsonTable,N'$.moduleStatus') WITH
      ([ModuleName] sysname N'$.ModuleName',[CapturedAtUtc] datetime2(3) N'$.CapturedAtUtc',
       [StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',
       [Detail] nvarchar(1000) N'$.Detail');
    INSERT [#MdtcExpected_serverContext]
    SELECT * FROM OPENJSON(@JsonTable,N'$.serverContext') WITH
      ([ProductMajorVersion] nvarchar(128) N'$.ProductMajorVersion');
    INSERT [#MdtcExpected_promotionConfiguration]
    SELECT * FROM OPENJSON(@JsonTable,N'$.promotionConfiguration') WITH
      ([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic');
    INSERT [#MdtcExpected_linkedServerPromotion]
    SELECT * FROM OPENJSON(@JsonTable,N'$.linkedServerPromotion') WITH
      ([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt');
    INSERT [#MdtcExpected_activeDistributedTransactions]
    SELECT * FROM OPENJSON(@JsonTable,N'$.activeDistributedTransactions') WITH
      ([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState');
    INSERT [#MdtcExpected_sourceStatus]
    SELECT * FROM OPENJSON(@JsonTable,N'$.sourceStatus') WITH
      ([SourceName] varchar(64) N'$.SourceName',[CaptureStartedAtUtc] datetime2(3) N'$.CaptureStartedAtUtc',
       [CaptureEndedAtUtc] datetime2(3) N'$.CaptureEndedAtUtc',[StatusCode] varchar(40) N'$.StatusCode',
       [IsPartial] bit N'$.IsPartial',[RowsReturned] bigint N'$.RowsReturned',[LimitApplied] bit N'$.LimitApplied',
       [ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage',[VisibilityLimit] nvarchar(500) N'$.VisibilityLimit');
    INSERT [#MdtcExpected_warnings]
    SELECT * FROM OPENJSON(@JsonTable,N'$.warnings') WITH
      ([WarningCode] varchar(40) N'$.WarningCode',[SourceName] varchar(64) N'$.SourceName',[Detail] nvarchar(1000) N'$.Detail');
    IF EXISTS(SELECT * FROM [#MdtcOut_moduleStatus] EXCEPT SELECT * FROM [#MdtcExpected_moduleStatus])
       OR EXISTS(SELECT * FROM [#MdtcExpected_moduleStatus] EXCEPT SELECT * FROM [#MdtcOut_moduleStatus])
       OR EXISTS(SELECT * FROM [#MdtcOut_serverContext] EXCEPT SELECT * FROM [#MdtcExpected_serverContext])
       OR EXISTS(SELECT * FROM [#MdtcExpected_serverContext] EXCEPT SELECT * FROM [#MdtcOut_serverContext])
       OR EXISTS(SELECT * FROM [#MdtcOut_promotionConfiguration] EXCEPT SELECT * FROM [#MdtcExpected_promotionConfiguration])
       OR EXISTS(SELECT * FROM [#MdtcExpected_promotionConfiguration] EXCEPT SELECT * FROM [#MdtcOut_promotionConfiguration])
       OR EXISTS(SELECT * FROM [#MdtcOut_linkedServerPromotion] EXCEPT SELECT * FROM [#MdtcExpected_linkedServerPromotion])
       OR EXISTS(SELECT * FROM [#MdtcExpected_linkedServerPromotion] EXCEPT SELECT * FROM [#MdtcOut_linkedServerPromotion])
       OR EXISTS(SELECT * FROM [#MdtcOut_activeDistributedTransactions] EXCEPT SELECT * FROM [#MdtcExpected_activeDistributedTransactions])
       OR EXISTS(SELECT * FROM [#MdtcExpected_activeDistributedTransactions] EXCEPT SELECT * FROM [#MdtcOut_activeDistributedTransactions])
       OR EXISTS(SELECT * FROM [#MdtcOut_sourceStatus] EXCEPT SELECT * FROM [#MdtcExpected_sourceStatus])
       OR EXISTS(SELECT * FROM [#MdtcExpected_sourceStatus] EXCEPT SELECT * FROM [#MdtcOut_sourceStatus])
       OR EXISTS(SELECT * FROM [#MdtcOut_warnings] EXCEPT SELECT * FROM [#MdtcExpected_warnings])
       OR EXISTS(SELECT * FROM [#MdtcExpected_warnings] EXCEPT SELECT * FROM [#MdtcOut_warnings])
        THROW 57405,N'MSDTC TABLE/JSON two-way result parity failed.',1;

    SELECT TOP (1) CASE WHEN [value] IS NULL THEN NULL
                WHEN CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([value],N'BaseType')) COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS THEN CONVERT(int,[value]) ELSE NULL END AS [ConfiguredValue],
           CASE WHEN [value_in_use] IS NULL THEN NULL
                WHEN CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([value_in_use],N'BaseType')) COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS THEN CONVERT(int,[value_in_use]) ELSE NULL END AS [RunningValue],
           [is_dynamic] AS [IsDynamic],[value] AS [NativeConfiguredValue],[value_in_use] AS [NativeRunningValue],
           CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([value],N'BaseType')) COLLATE SQL_Latin1_General_CP1_CS_AS AS [ConfiguredBaseType],
           CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([value_in_use],N'BaseType')) COLLATE SQL_Latin1_General_CP1_CS_AS AS [RunningBaseType]
    INTO [#MdtcNativeConfigActual]
    FROM [sys].[configurations] WITH (NOLOCK)
    WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'remote proc trans' COLLATE SQL_Latin1_General_CP1_CS_AS
    ORDER BY [name] COLLATE SQL_Latin1_General_CP1_CS_AS;
    IF (SELECT COUNT(*) FROM [#MdtcNativeConfigActual])<>1
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual] EXCEPT SELECT * FROM [#MdtcOut_promotionConfiguration])
       OR EXISTS(SELECT * FROM [#MdtcOut_promotionConfiguration] EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual])
        THROW 57406,N'MSDTC SQL configuration values differ from the independent native oracle.',1;
    IF EXISTS(SELECT 1 FROM [#MdtcNativeConfigActual]
              WHERE ([NativeConfiguredValue] IS NOT NULL AND ([ConfiguredBaseType] IS NULL OR [ConfiguredBaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                 OR ([NativeRunningValue] IS NOT NULL AND ([RunningBaseType] IS NULL OR [RunningBaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS)))
       AND NOT EXISTS(SELECT 1 FROM OPENJSON(@JsonTable,N'$.warnings') WITH([WarningCode] varchar(40) N'$.WarningCode',[SourceName] varchar(64) N'$.SourceName',[Detail] nvarchar(1000) N'$.Detail')
                      WHERE [WarningCode]='CONFIG_VALUE_TYPE_UNSUPPORTED' AND [SourceName]='SERVER_CONFIGURATION'
                        AND [Detail]=N'Der native sql_variant-Wert konnte nicht typgetreu als int abgebildet werden; das betroffene Ausgabefeld bleibt NULL.')
        THROW 57430,N'MSDTC non-int config variants must become typed NULL with the fixed source warning.',1;
    IF NOT EXISTS(SELECT 1 FROM [#MdtcNativeConfigActual]
                  WHERE ([NativeConfiguredValue] IS NOT NULL AND ([ConfiguredBaseType] IS NULL OR [ConfiguredBaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                     OR ([NativeRunningValue] IS NOT NULL AND ([RunningBaseType] IS NULL OR [RunningBaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS)))
       AND EXISTS(SELECT 1 FROM OPENJSON(@JsonTable,N'$.warnings') WITH([WarningCode] varchar(40) N'$.WarningCode',[SourceName] varchar(64) N'$.SourceName')
                  WHERE [WarningCode]='CONFIG_VALUE_TYPE_UNSUPPORTED' AND [SourceName]='SERVER_CONFIGURATION')
        THROW 57431,N'MSDTC supported int or NULL config variants must not emit a type warning.',1;
    IF EXISTS(SELECT 1 FROM [#MdtcOut_activeDistributedTransactions] WHERE [TransactionType]<>4)
        THROW 57407,N'MSDTC output contains a non-distributed transaction type.',1;

    SELECT [server_id] AS [ServerId],
           [is_remote_proc_transaction_promotion_enabled] AS [RemoteProcTransactionPromotionEnabled],
           [modify_date] AS [ModifiedAt]
    INTO [#MdtcNativeLinkedActual]
    FROM [sys].[servers] WITH (NOLOCK)
    WHERE [is_linked]=1
    ORDER BY [server_id];
    IF EXISTS(SELECT * FROM [#MdtcNativeLinkedActual] EXCEPT SELECT * FROM [#MdtcOut_linkedServerPromotion])
       OR EXISTS(SELECT * FROM [#MdtcOut_linkedServerPromotion] EXCEPT SELECT * FROM [#MdtcNativeLinkedActual])
        THROW 57408,N'MSDTC linked-server promotion metadata differs from the independent native oracle.',1;

    INSERT [#MdtcNativeActive]([TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState])
    SELECT [transaction_id],[transaction_type],[transaction_begin_time],[transaction_state]
    FROM [sys].[dm_tran_active_transactions] WITH (NOLOCK) WHERE [transaction_type]=4;
    SELECT @NativeActiveRows=COUNT_BIG(*) FROM [#MdtcNativeActive];
    IF EXISTS(SELECT * FROM [#MdtcNativeActive] EXCEPT SELECT * FROM [#MdtcOut_activeDistributedTransactions])
       OR EXISTS(SELECT * FROM [#MdtcOut_activeDistributedTransactions] EXCEPT SELECT * FROM [#MdtcNativeActive])
        THROW 57409,N'MSDTC active-DTC metadata differs from the exact native type-4 oracle; this is not a commit-health claim.',1;
    IF EXISTS(SELECT 1 FROM [#MdtcExpected_sourceStatus] WHERE [SourceName] NOT IN('SERVER_CONFIGURATION','LINKED_SERVER_PROMOTION','ACTIVE_DISTRIBUTED_TRANSACTIONS'))
       OR (SELECT COUNT(DISTINCT [SourceName]) FROM [#MdtcExpected_sourceStatus])<>3
       OR EXISTS(SELECT 1 FROM [#MdtcExpected_sourceStatus] WHERE [CaptureEndedAtUtc]<[CaptureStartedAtUtc] OR [IsPartial]<>1)
        THROW 57410,N'MSDTC source-isolation status contract failed.',1;

    DECLARE @PairTarget sysname,@PairExpected sysname,@PhysicalSql nvarchar(max),@PhysicalMismatch bit;
    DECLARE [MdtcPhysicalAbi] CURSOR LOCAL FAST_FORWARD FOR SELECT [TargetName],[ExpectedName] FROM [#MdtcPhysicalPairs];
    OPEN [MdtcPhysicalAbi];
    FETCH NEXT FROM [MdtcPhysicalAbi] INTO @PairTarget,@PairExpected;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @PhysicalMismatch=0;
        SET @PhysicalSql=N';WITH [ActualAbi] AS
        (SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],
                [c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name],[c].[is_identity],[c].[is_computed]
         FROM [tempdb].[sys].[columns] AS [c]
         WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@PairTarget+N''')),
        [ExpectedAbi] AS
        (SELECT ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal],[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],
                TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType],
                [c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name],[c].[is_identity],[c].[is_computed]
         FROM [tempdb].[sys].[columns] AS [c]
         WHERE [c].[object_id]=OBJECT_ID(N''tempdb..'+@PairExpected+N'''))
        SELECT @Mismatch=CASE WHEN EXISTS
        (SELECT [a].[Ordinal],[a].[ColumnName],[a].[BaseType],[a].[max_length],[a].[precision],[a].[scale],[a].[is_nullable],[a].[collation_name],[a].[is_identity],[a].[is_computed]
         FROM [ActualAbi] AS [a] FULL OUTER JOIN [ExpectedAbi] AS [e] ON [e].[Ordinal]=[a].[Ordinal]
         WHERE [a].[Ordinal] IS NULL OR [e].[Ordinal] IS NULL OR [a].[ColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[ColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS
            OR [a].[BaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[BaseType] COLLATE SQL_Latin1_General_CP1_CS_AS
            OR [a].[max_length]<>[e].[max_length] OR [a].[precision]<>[e].[precision] OR [a].[scale]<>[e].[scale]
            OR [a].[is_nullable]<>[e].[is_nullable] OR ISNULL([a].[collation_name],N'''') COLLATE SQL_Latin1_General_CP1_CS_AS<>ISNULL([e].[collation_name],N'''') COLLATE SQL_Latin1_General_CP1_CS_AS
            OR [a].[is_identity]<>[e].[is_identity] OR [a].[is_computed]<>[e].[is_computed]) THEN 1 ELSE 0 END;';
        EXEC [sys].[sp_executesql] @PhysicalSql,N'@Mismatch bit OUTPUT',@Mismatch=@PhysicalMismatch OUTPUT;
        IF @PhysicalMismatch=1 THROW 57411,N'MSDTC TABLE physical ABI differs by ordinal, column name, base type, length, precision, scale, nullability, collation, identity or computed flag.',1;
        FETCH NEXT FROM [MdtcPhysicalAbi] INTO @PairTarget,@PairExpected;
    END;
    CLOSE [MdtcPhysicalAbi]; DEALLOCATE [MdtcPhysicalAbi];

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1000,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@JsonNone OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@JsonNone)<>1
        THROW 57412,N'MSDTC NONE result status or JSON envelope is invalid.',1;
    INSERT [#MdtcModeJson] VALUES('NONE',@JsonNone);

    BEGIN TRANSACTION;
    EXEC [monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1000,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0 OR ISJSON(@Json)<>1
        THROW 57425,N'MSDTC caller transaction or session-state preservation failed inside a local caller transaction.',1;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT<>@OriginalTx OR XACT_STATE()<>0
        THROW 57426,N'MSDTC caller transaction fixture did not roll back cleanly.',1;

    INSERT [#MdtcConsole]
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1000,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@JsonConsole OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    SELECT @ConsoleStatus=[StatusCode],@ConsolePartial=[IsPartial],@ConsoleProductMajor=[ProductMajorVersion],
           @ConsoleConfigured=[ConfiguredValue],@ConsoleRunning=[RunningValue],
           @ConsoleLinked=[LinkedServerRowsReturned],@ConsoleActive=[ActiveTransactionRowsReturned],@ConsoleDetail=[Detail]
    FROM [#MdtcConsole];
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@JsonConsole)<>1
       OR (SELECT COUNT(*) FROM [#MdtcConsole])<>1 OR @ConsoleStatus<>@Status OR @ConsolePartial<>@Partial
       OR @ConsoleProductMajor<>JSON_VALUE(@JsonConsole,N'$.serverContext[0].ProductMajorVersion')
       OR EXISTS(SELECT @ConsoleConfigured EXCEPT SELECT [ConfiguredValue] FROM [#MdtcNativeConfigActual])
       OR EXISTS(SELECT [ConfiguredValue] FROM [#MdtcNativeConfigActual] EXCEPT SELECT @ConsoleConfigured)
       OR EXISTS(SELECT @ConsoleRunning EXCEPT SELECT [RunningValue] FROM [#MdtcNativeConfigActual])
       OR EXISTS(SELECT [RunningValue] FROM [#MdtcNativeConfigActual] EXCEPT SELECT @ConsoleRunning)
       OR @ConsoleLinked<>(SELECT COUNT_BIG(*) FROM [#MdtcNativeLinkedActual])
       OR @ConsoleActive<>(SELECT COUNT_BIG(*) FROM [#MdtcNativeActive])
       OR @ConsoleDetail<>N'Caller-sichtbare lokale SQL-Metadaten; keine DTC-Dienst-, Teilnehmer-, Commit- oder Recoveryprüfung.'
        THROW 57413,N'MSDTC CONSOLE JSON, native summary values or fixed summary contract failed.',1;
    INSERT [#MdtcModeJson] VALUES('CONSOLE',@JsonConsole);

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1000,@ResultSetArt='RAW',@JsonErzeugen=1,@Json=@JsonRaw OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@JsonRaw)<>1
        THROW 57414,N'MSDTC RAW result status or JSON envelope is invalid.',1;
    INSERT [#MdtcModeJson] VALUES('RAW',@JsonRaw);
    INSERT [#MdtcModePayload]
    SELECT [ModeName],
        JSON_QUERY((SELECT [ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail]
            FROM OPENJSON([Payload],N'$.moduleStatus') WITH
             ([ModuleName] sysname N'$.ModuleName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowCount] bigint N'$.RowCount',[Detail] nvarchar(1000) N'$.Detail')
            FOR JSON PATH,INCLUDE_NULL_VALUES)),
        JSON_QUERY([Payload],N'$.serverContext'),JSON_QUERY([Payload],N'$.promotionConfiguration'),
        JSON_QUERY([Payload],N'$.linkedServerPromotion'),JSON_QUERY([Payload],N'$.activeDistributedTransactions'),
        JSON_QUERY((SELECT [SourceName],[StatusCode],[IsPartial],[RowsReturned],[LimitApplied],[ErrorNumber],[ErrorMessage],[VisibilityLimit]
            FROM OPENJSON([Payload],N'$.sourceStatus') WITH
             ([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowsReturned] bigint N'$.RowsReturned',[LimitApplied] bit N'$.LimitApplied',[ErrorNumber] int N'$.ErrorNumber',[ErrorMessage] nvarchar(2048) N'$.ErrorMessage',[VisibilityLimit] nvarchar(500) N'$.VisibilityLimit')
            FOR JSON PATH,INCLUDE_NULL_VALUES)),
        JSON_QUERY([Payload],N'$.warnings')
    FROM [#MdtcModeJson];
    IF (SELECT COUNT(*) FROM [#MdtcModePayload])<>4
       OR EXISTS(SELECT [moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]
                 FROM [#MdtcModePayload] WHERE [ModeName]<>'TABLE'
                 EXCEPT SELECT [moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]
                 FROM [#MdtcModePayload] WHERE [ModeName]='TABLE')
       OR EXISTS(SELECT [moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]
                 FROM [#MdtcModePayload] WHERE [ModeName]='TABLE'
                 EXCEPT SELECT [moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]
                 FROM [#MdtcModePayload] WHERE [ModeName]<>'TABLE')
        THROW 57427,N'MSDTC stable JSON arrays differ across TABLE, NONE, CONSOLE and RAW; only capture timestamps are ignored.',1;

    SELECT @NativeLinkedRows=COUNT_BIG(*) FROM [#MdtcNativeLinkedActual];
    SELECT TOP (1) [server_id] AS [ServerId],[is_remote_proc_transaction_promotion_enabled] AS [RemoteProcTransactionPromotionEnabled],[modify_date] AS [ModifiedAt]
    INTO [#MdtcNativeLinkedTopOne]
    FROM [sys].[servers] WITH (NOLOCK) WHERE [is_linked]=1 ORDER BY [server_id];
    SELECT TOP (1) [transaction_id] AS [TransactionId],[transaction_type] AS [TransactionType],
           [transaction_begin_time] AS [TransactionBeginTime],[transaction_state] AS [TransactionState]
    INTO [#MdtcNativeActiveTopOne]
    FROM [sys].[dm_tran_active_transactions] WITH (NOLOCK)
    WHERE [transaction_type]=4 ORDER BY [transaction_begin_time],[transaction_id];

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@Json)<>1
        THROW 57415,N'MSDTC positive-limit call return, status, partiality or JSON envelope is invalid.',1;
    IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.linkedServerPromotion'))<>(SELECT COUNT_BIG(*) FROM [#MdtcNativeLinkedTopOne])
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.activeDistributedTransactions'))<>(SELECT COUNT_BIG(*) FROM [#MdtcNativeActiveTopOne])
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual] EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic'))
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic') EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual])
       OR EXISTS(SELECT * FROM [#MdtcNativeLinkedTopOne] EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt'))
       OR EXISTS(SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt') EXCEPT SELECT * FROM [#MdtcNativeLinkedTopOne])
       OR EXISTS(SELECT * FROM [#MdtcNativeActiveTopOne] EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState'))
       OR EXISTS(SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState') EXCEPT SELECT * FROM [#MdtcNativeActiveTopOne])
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus'))<>3
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowsReturned] bigint N'$.RowsReturned',[LimitApplied] bit N'$.LimitApplied',[ErrorNumber] int N'$.ErrorNumber')
          WHERE [StatusCode]<>'AVAILABLE_LIMITED' OR [IsPartial]<>1 OR [ErrorNumber] IS NOT NULL
             OR [RowsReturned]<>CASE [SourceName] WHEN 'SERVER_CONFIGURATION' THEN 1 WHEN 'LINKED_SERVER_PROMOTION' THEN CASE WHEN @NativeLinkedRows>1 THEN 1 ELSE @NativeLinkedRows END WHEN 'ACTIVE_DISTRIBUTED_TRANSACTIONS' THEN CASE WHEN @NativeActiveRows>1 THEN 1 ELSE @NativeActiveRows END ELSE -1 END
             OR [LimitApplied]<>CASE WHEN [SourceName]='LINKED_SERVER_PROMOTION' AND @NativeLinkedRows>1 THEN 1 WHEN [SourceName]='ACTIVE_DISTRIBUTED_TRANSACTIONS' AND @NativeActiveRows>1 THEN 1 ELSE 0 END)
        THROW 57434,N'MSDTC positive limit must return exact native TOP(1) rows, counts and truncation flags.',1;

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@Json)<>1
        THROW 57416,N'MSDTC @MaxZeilen=0 return, status, partiality or JSON envelope is invalid.',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.promotionConfiguration'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.linkedServerPromotion'))<>@NativeLinkedRows
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.activeDistributedTransactions'))<>@NativeActiveRows
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowsReturned] bigint N'$.RowsReturned',[LimitApplied] bit N'$.LimitApplied',[ErrorNumber] int N'$.ErrorNumber')
          WHERE [StatusCode]<>'AVAILABLE_LIMITED' OR [IsPartial]<>1 OR [ErrorNumber] IS NOT NULL OR [LimitApplied]<>0
             OR [RowsReturned]<>CASE [SourceName] WHEN 'SERVER_CONFIGURATION' THEN 1 WHEN 'LINKED_SERVER_PROMOTION' THEN @NativeLinkedRows WHEN 'ACTIVE_DISTRIBUTED_TRANSACTIONS' THEN @NativeActiveRows ELSE -1 END)
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic') EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual])
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual] EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic'))
       OR EXISTS(SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM [#MdtcNativeLinkedActual] EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt'))
       OR EXISTS(SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt') EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM [#MdtcNativeLinkedActual])
       OR EXISTS(SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM [#MdtcNativeActive] EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState'))
       OR EXISTS(SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState') EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM [#MdtcNativeActive])
        THROW 57435,N'MSDTC @MaxZeilen=0 unlimited mode differs from exact native source rows, counts or statuses.',1;
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@Json)<>1
        THROW 57417,N'MSDTC @MaxZeilen=NULL return, status, partiality or JSON envelope is invalid.',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.promotionConfiguration'))<>1
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.linkedServerPromotion'))<>@NativeLinkedRows
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.activeDistributedTransactions'))<>@NativeActiveRows
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode',[IsPartial] bit N'$.IsPartial',[RowsReturned] bigint N'$.RowsReturned',[LimitApplied] bit N'$.LimitApplied',[ErrorNumber] int N'$.ErrorNumber')
          WHERE [StatusCode]<>'AVAILABLE_LIMITED' OR [IsPartial]<>1 OR [ErrorNumber] IS NOT NULL OR [LimitApplied]<>0
             OR [RowsReturned]<>CASE [SourceName] WHEN 'SERVER_CONFIGURATION' THEN 1 WHEN 'LINKED_SERVER_PROMOTION' THEN @NativeLinkedRows WHEN 'ACTIVE_DISTRIBUTED_TRANSACTIONS' THEN @NativeActiveRows ELSE -1 END)
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic') EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual])
       OR EXISTS(SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual] EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM OPENJSON(@Json,N'$.promotionConfiguration') WITH([ConfiguredValue] int N'$.ConfiguredValue',[RunningValue] int N'$.RunningValue',[IsDynamic] bit N'$.IsDynamic'))
       OR EXISTS(SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM [#MdtcNativeLinkedActual] EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt'))
       OR EXISTS(SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM OPENJSON(@Json,N'$.linkedServerPromotion') WITH([ServerId] int N'$.ServerId',[RemoteProcTransactionPromotionEnabled] bit N'$.RemoteProcTransactionPromotionEnabled',[ModifiedAt] datetime N'$.ModifiedAt') EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM [#MdtcNativeLinkedActual])
       OR EXISTS(SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM [#MdtcNativeActive] EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState'))
       OR EXISTS(SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM OPENJSON(@Json,N'$.activeDistributedTransactions') WITH([TransactionId] bigint N'$.TransactionId',[TransactionType] int N'$.TransactionType',[TransactionBeginTime] datetime N'$.TransactionBeginTime',[TransactionState] int N'$.TransactionState') EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM [#MdtcNativeActive])
        THROW 57436,N'MSDTC @MaxZeilen=NULL unlimited mode differs from exact native source rows, counts or statuses.',1;
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory] @MaxZeilen=-1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
       OR @Message<>N'Ungültiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.'
        THROW 57418,N'MSDTC negative row-limit rejection contract failed.',1;

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory] @LockTimeoutMs=NULL,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
        THROW 57419,N'MSDTC NULL lock-timeout rejection contract failed.',1;

    EXEC @Return=[monitor].[USP_DistributedTransactionInventory] @LockTimeoutMs=-1,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @ErrorNumberOut=@Error OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
        THROW 57428,N'MSDTC negative lock-timeout rejection contract failed.',1;
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory] @LockTimeoutMs=60001,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @ErrorNumberOut=@Error OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
        THROW 57429,N'MSDTC excessive lock-timeout rejection contract failed.',1;
    EXEC @Return=[monitor].[USP_DistributedTransactionInventory] @ResultSetArt='INVALID',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,
        @ErrorNumberOut=@Error OUTPUT;
    IF @Return<>51011 OR @Status<>'INVALID_PARAMETER' OR @Json IS NOT NULL
        THROW 57420,N'MSDTC invalid output-mode rejection contract failed.',1;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0
        THROW 57421,N'MSDTC caller transaction or session state changed after successful and invalid paths.',1;

    SET @Suffix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'');
    SELECT @RestrictedLogin=N'ExampleMdtcReader_'+@Suffix,@RestrictedUser=N'ExampleMdtcReader_'+@Suffix,
           @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
    IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name]=@RestrictedLogin)
       OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name]=@RestrictedUser)
        THROW 57422,N'MSDTC restricted-caller fixture name collision.',1;
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@RestrictedLogin)+N' WITH PASS'+N'WORD='+QUOTENAME(@Credential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
    EXEC [master].[sys].[sp_executesql] @Sql; SET @MadeRestrictedLogin=1; SET @Credential=NULL;
    SET @Sql=N'GRANT VIEW SERVER PERFORMANCE STATE TO '+QUOTENAME(@RestrictedLogin)+N'; GRANT VIEW SERVER SECURITY STATE TO '+QUOTENAME(@RestrictedLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql;
    SET @Sql=N'CREATE USER '+QUOTENAME(@RestrictedUser)+N' FOR LOGIN '+QUOTENAME(@RestrictedLogin)+N';';
    EXEC [sys].[sp_executesql] @Sql; SET @MadeRestrictedUser=1;
    SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_DistributedTransactionInventory] TO '+QUOTENAME(@RestrictedUser)+N'; DENY SELECT ON [sys].[dm_tran_active_transactions] TO '+QUOTENAME(@RestrictedUser)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    EXECUTE AS LOGIN=@RestrictedLogin; SET @Impersonating=1;
    EXEC [monitor].[USP_DistributedTransactionInventory]
        @MaxZeilen=10,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,
        @PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
    REVERT; SET @Impersonating=0;
    IF ISJSON(@Json)<>1 OR @Status<>'DENIED_PERMISSION' OR @Partial<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode',[ErrorNumber] int N'$.ErrorNumber')
            WHERE [SourceName]='ACTIVE_DISTRIBUTED_TRANSACTIONS' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber]=229)
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus')
            WITH([SourceName] varchar(64) N'$.SourceName',[StatusCode] varchar(40) N'$.StatusCode')
            WHERE [SourceName]='SERVER_CONFIGURATION' AND [StatusCode]='AVAILABLE_LIMITED')
        THROW 57423,N'MSDTC isolated DENY 229 source-failure contract failed.',1;
    SET @Sql=N'REVOKE SELECT ON [sys].[dm_tran_active_transactions] FROM '+QUOTENAME(@RestrictedUser)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'DROP USER '+QUOTENAME(@RestrictedUser)+N';';
    EXEC [sys].[sp_executesql] @Sql; SET @MadeRestrictedUser=0;
    SET @Sql=N'REVOKE VIEW SERVER PERFORMANCE STATE FROM '+QUOTENAME(@RestrictedLogin)+N'; REVOKE VIEW SERVER SECURITY STATE FROM '+QUOTENAME(@RestrictedLogin)+N'; DROP LOGIN '+QUOTENAME(@RestrictedLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @Sql; SET @MadeRestrictedLogin=0;
    SET @RestrictedLogin=NULL; SET @RestrictedUser=NULL;
    IF @@TRANCOUNT<>@OriginalTx OR @@LOCK_TIMEOUT<>137 OR (@@OPTIONS&16384)=0
        THROW 57424,N'MSDTC cleanup changed caller transaction or session state.',1;

    EXEC [sys].[sp_executesql] @RestoreLock;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    PRINT N'MSDTC_RUNTIME_CONTRACT_PASS';
END TRY
BEGIN CATCH
    IF @Impersonating=1 REVERT;
    IF @@TRANCOUNT>@OriginalTx ROLLBACK TRANSACTION;
    BEGIN TRY
        IF @MadeRestrictedUser=1 AND @RestrictedUser IS NOT NULL AND USER_ID(@RestrictedUser) IS NOT NULL
        BEGIN
            SET @Sql=N'REVOKE SELECT ON [sys].[dm_tran_active_transactions] FROM '+QUOTENAME(@RestrictedUser)+N'; DROP USER '+QUOTENAME(@RestrictedUser)+N';';
            EXEC [sys].[sp_executesql] @Sql; SET @MadeRestrictedUser=0;
        END;
        IF @MadeRestrictedLogin=1 AND @RestrictedLogin IS NOT NULL AND SUSER_ID(@RestrictedLogin) IS NOT NULL
        BEGIN
            SET @Sql=N'REVOKE VIEW SERVER PERFORMANCE STATE FROM '+QUOTENAME(@RestrictedLogin)+N'; REVOKE VIEW SERVER SECURITY STATE FROM '+QUOTENAME(@RestrictedLogin)+N'; DROP LOGIN '+QUOTENAME(@RestrictedLogin)+N';';
            EXEC [master].[sys].[sp_executesql] @Sql; SET @MadeRestrictedLogin=0;
        END;
    END TRY
    BEGIN CATCH
        THROW 57490,N'MSDTC owned principal cleanup failed.',1;
    END CATCH;
    EXEC [sys].[sp_executesql] @RestoreLock;
    IF @OriginalAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
GO