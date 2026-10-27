USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DistributedTransactionInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Inventarisiert lokale serverweite MSDTC-Konfigurations- und
               aktive Transaktionsmetadaten.
Quellen      : sys.configurations, sys.servers und
               sys.dm_tran_active_transactions.
Grenzen      : Caller-sichtbare SQL-Metadaten; kein Dienst-, Netzwerk-,
               Teilnehmer-, Commit- oder Recovery-Nachweis.
Datenschutz  : Keine Transaktionsnamen, UOWs, SQL-Texte, Identitäten,
               Linked-Servernamen oder Endpunktdaten.
Nebenwirkung : Rein lesend; keine Berechtigungs-, Konfigurations- oder
               Transaktionsänderung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DistributedTransactionInventory]
      @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @ProbeLimit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen)+1 END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@SetLockSource nvarchar(max),
        @Started datetime2(3),@Observed bigint,@Returned bigint,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @ConfigurationValue sql_variant=NULL,@ConfigurationValueInUse sql_variant=NULL,
        @ConfigurationIsDynamic bit=NULL,@ConfiguredInt int=NULL,@RunningInt int=NULL,
        @ConfiguredBaseType nvarchar(128),@RunningBaseType nvarchar(128);
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableStatus varchar(40),@TableMessage nvarchar(2048),
        @TableError int,@TableFailureError int=NULL;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DistributedTransactionInventory';
        PRINT N'Zeigt caller-sichtbare lokale MSDTC-Konfiguration und aktive Transaktionen mit transaction_type = 4.';
        PRINT N'RAW/TABLE/JSON: moduleStatus, serverContext, promotionConfiguration, linkedServerPromotion, activeDistributedTransactions, sourceStatus, warnings.';
        PRINT N'Keine Dienst-, Netzwerk-, Teilnehmer-, Commit- oder Recoveryprüfung. @MaxZeilen begrenzt jede Fachmenge; NULL/0 bedeutet unbegrenzt.';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,@ErrorMessageOut=N'Ungültiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#DistributedTransactionInventory_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_serverContext]
        (
            [ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_promotionConfiguration]
        (
            [ConfiguredValue] int NULL,
            [RunningValue] int NULL,
            [IsDynamic] bit NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_linkedServerPromotion]
        (
            [ServerId] int NOT NULL,
            [RemoteProcTransactionPromotionEnabled] bit NOT NULL,
            [ModifiedAt] datetime NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_activeDistributedTransactions]
        (
            [TransactionId] bigint NOT NULL,
            [TransactionType] int NOT NULL,
            [TransactionBeginTime] datetime NULL,
            [TransactionState] int NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_sourceStatus]
        (
            [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CaptureStartedAtUtc] datetime2(3) NOT NULL,
            [CaptureEndedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowsReturned] bigint NULL,
            [LimitApplied] bit NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [VisibilityLimit] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_warnings]
        (
            [WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceName] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DistributedTransactionInventory_Console]
        (
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [ProductMajorVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ConfiguredValue] int NULL,
            [RunningValue] int NULL,
            [LinkedServerRowsReturned] bigint NOT NULL,
            [ActiveTransactionRowsReturned] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        INSERT [#DistributedTransactionInventory_serverContext]([ProductMajorVersion])
        VALUES(CONVERT(nvarchar(128),SERVERPROPERTY(N'ProductMajorVersion')) COLLATE SQL_Latin1_General_CP1_CS_AS);

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|serverContext|promotionConfiguration|linkedServerPromotion|activeDistributedTransactions|sourceStatus|warnings',
                @MappingTable=N'#DistributedTransactionInventory_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TableFailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @Observed=0;
            SET @SetLockSource=@SetLock+N'SELECT @ConfiguredValue=[c].[value],@RunningValue=[c].[value_in_use],@IsDynamic=[c].[is_dynamic]
                FROM [sys].[configurations] AS [c] WITH (NOLOCK)
                WHERE [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''remote proc trans'' COLLATE SQL_Latin1_General_CP1_CS_AS;
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,
                N'@ConfiguredValue sql_variant OUTPUT,@RunningValue sql_variant OUTPUT,@IsDynamic bit OUTPUT,@Rows bigint OUTPUT',
                @ConfiguredValue=@ConfigurationValue OUTPUT,@RunningValue=@ConfigurationValueInUse OUTPUT,
                @IsDynamic=@ConfigurationIsDynamic OUTPUT,@Rows=@Observed OUTPUT;
            IF @Observed>0
            BEGIN
                SET @ConfiguredBaseType=CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(@ConfigurationValue,N'BaseType'));
                SET @RunningBaseType=CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY(@ConfigurationValueInUse,N'BaseType'));
                SET @ConfiguredInt=CASE WHEN @ConfigurationValue IS NULL THEN NULL
                    WHEN @ConfiguredBaseType COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS
                    THEN CONVERT(int,@ConfigurationValue) ELSE NULL END;
                SET @RunningInt=CASE WHEN @ConfigurationValueInUse IS NULL THEN NULL
                    WHEN @RunningBaseType COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS
                    THEN CONVERT(int,@ConfigurationValueInUse) ELSE NULL END;
                INSERT [#DistributedTransactionInventory_promotionConfiguration]
                    ([ConfiguredValue],[RunningValue],[IsDynamic])
                VALUES(@ConfiguredInt,@RunningInt,@ConfigurationIsDynamic);
                IF (@ConfigurationValue IS NOT NULL AND (@ConfiguredBaseType IS NULL OR @ConfiguredBaseType COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                   OR (@ConfigurationValueInUse IS NOT NULL AND (@RunningBaseType IS NULL OR @RunningBaseType COLLATE SQL_Latin1_General_CP1_CS_AS<>N'int' COLLATE SQL_Latin1_General_CP1_CS_AS))
                    INSERT [#DistributedTransactionInventory_warnings]
                        VALUES('CONFIG_VALUE_TYPE_UNSUPPORTED','SERVER_CONFIGURATION',
                               N'Der native sql_variant-Wert konnte nicht typgetreu als int abgebildet werden; das betroffene Ausgabefeld bleibt NULL.');
            END;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('SERVER_CONFIGURATION',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Caller-sichtbare sys.configurations-Zeile; nur der Serverdefault für remote proc trans.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_promotionConfiguration];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('SERVER_CONFIGURATION',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#DistributedTransactionInventory_linkedServerPromotion]
                ([ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt])
                SELECT TOP (@ProbeLimit) [s].[server_id],[s].[is_remote_proc_transaction_promotion_enabled],[s].[modify_date]
                FROM [sys].[servers] AS [s] WITH (NOLOCK)
                WHERE [s].[is_linked]=1
                ORDER BY [s].[server_id];
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@ProbeLimit bigint,@Rows bigint OUTPUT',@ProbeLimit=@ProbeLimit,@Rows=@Observed OUTPUT;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('LINKED_SERVER_PROMOTION',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Nur caller-sichtbare Linked-Serverflags; Namen und Verbindungseigenschaften sind ausgeschlossen.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_linkedServerPromotion];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('LINKED_SERVER_PROMOTION',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#DistributedTransactionInventory_activeDistributedTransactions]
                ([TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState])
                SELECT TOP (@ProbeLimit) [t].[transaction_id],[t].[transaction_type],[t].[transaction_begin_time],[t].[transaction_state]
                FROM [sys].[dm_tran_active_transactions] AS [t] WITH (NOLOCK)
                WHERE [t].[transaction_type]=4
                ORDER BY [t].[transaction_begin_time],[t].[transaction_id];
                SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@ProbeLimit bigint,@Rows bigint OUTPUT',@ProbeLimit=@ProbeLimit,@Rows=@Observed OUTPUT;
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('ACTIVE_DISTRIBUTED_TRANSACTIONS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED',1,@Observed,0,NULL,NULL,
                   N'Nur sichtbare lokale Transaktionsmetadaten mit transaction_type = 4; kein Teilnehmer- oder Commitnachweis.');
        END TRY
        BEGIN CATCH
            DELETE FROM [#DistributedTransactionInventory_activeDistributedTransactions];
            INSERT [#DistributedTransactionInventory_sourceStatus]
            VALUES('ACTIVE_DISTRIBUTED_TRANSACTIONS',@Started,SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                1,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'UNPROVEN');
        END CATCH;

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [ServerId]) AS [OutputOrdinal]
         FROM [#DistributedTransactionInventory_linkedServerPromotion])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion];
        UPDATE [#DistributedTransactionInventory_sourceStatus]
           SET [RowsReturned]=@Returned,
               [LimitApplied]=CASE WHEN [RowsReturned]>@Returned THEN 1 ELSE 0 END
         WHERE [SourceName]='LINKED_SERVER_PROMOTION';

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [TransactionBeginTime],[TransactionId]) AS [OutputOrdinal]
         FROM [#DistributedTransactionInventory_activeDistributedTransactions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions];
        UPDATE [#DistributedTransactionInventory_sourceStatus]
           SET [RowsReturned]=@Returned,
               [LimitApplied]=CASE WHEN [RowsReturned]>@Returned THEN 1 ELSE 0 END
         WHERE [SourceName]='ACTIVE_DISTRIBUTED_TRANSACTIONS';

        INSERT [#DistributedTransactionInventory_warnings]
        VALUES('METADATA_COMPLETENESS_UNPROVEN',NULL,
               N'Alle Mengen beschreiben ausschließlich caller-sichtbare lokale SQL-Metadaten. Sie belegen weder MSDTC-Gesundheit noch Teilnehmererreichbarkeit, Commit oder Recovery.');
        INSERT [#DistributedTransactionInventory_warnings]
            SELECT 'OUTPUT_LIMIT',[SourceName],
                   N'Das Fachresultset ist gekappt. Das Zeilenlimit begrenzt die Ausgabe, nicht garantiert die vorgelagerte Katalog- oder DMV-Lesearbeit.'
            FROM [#DistributedTransactionInventory_sourceStatus] WHERE [LimitApplied]=1;
        INSERT [#DistributedTransactionInventory_warnings]
            SELECT 'SOURCE_UNAVAILABLE',[SourceName],
                   N'Die Quelle konnte nicht gelesen werden; andere sichtbare Quellen bleiben separat auswertbar.'
            FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
          FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
          ORDER BY [SourceName];
        SELECT TOP (1) @Status=[StatusCode]
          FROM [#DistributedTransactionInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
          ORDER BY [SourceName];
        SET @Status=COALESCE(@Status,'AVAILABLE_LIMITED');
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_promotionConfiguration])+
            (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion])+
            (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions]);
        INSERT [#DistributedTransactionInventory_moduleStatus]
        VALUES(N'USP_DistributedTransactionInventory',@CapturedAtUtc,@Status,1,@Rows,
               N'Getrennte lokale serverweite Konfigurations- und Transaktionsmetadatenaufnahmen im Caller-Kontext; kein DTC-Dienst- oder Commitnachweis.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'DistributedTransactionInventory' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_serverContext nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_serverContext] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_promotionConfiguration nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_promotionConfiguration] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_linkedServerPromotion nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_linkedServerPromotion] ORDER BY [ServerId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_activeDistributedTransactions nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_activeDistributedTransactions] ORDER BY [TransactionBeginTime],[TransactionId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_sourceStatus] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#DistributedTransactionInventory_warnings] ORDER BY [WarningCode],[SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"serverContext":',COALESCE(@Json_serverContext,N'[]'),
                N',"promotionConfiguration":',COALESCE(@Json_promotionConfiguration,N'[]'),
                N',"linkedServerPromotion":',COALESCE(@Json_linkedServerPromotion,N'[]'),
                N',"activeDistributedTransactions":',COALESCE(@Json_activeDistributedTransactions,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#DistributedTransactionInventory_moduleStatus];
            SELECT * FROM [#DistributedTransactionInventory_serverContext];
            SELECT * FROM [#DistributedTransactionInventory_promotionConfiguration];
            SELECT * FROM [#DistributedTransactionInventory_linkedServerPromotion] ORDER BY [ServerId];
            SELECT * FROM [#DistributedTransactionInventory_activeDistributedTransactions] ORDER BY [TransactionBeginTime],[TransactionId];
            SELECT * FROM [#DistributedTransactionInventory_sourceStatus] ORDER BY [SourceName];
            SELECT * FROM [#DistributedTransactionInventory_warnings] ORDER BY [WarningCode],[SourceName];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DistributedTransactionOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#DistributedTransactionInventory_Map] ORDER BY [ResultName];
            OPEN [DistributedTransactionOutput];
            FETCH NEXT FROM [DistributedTransactionOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DistributedTransactionInventory_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DistributedTransactionOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DistributedTransactionOutput]; DEALLOCATE [DistributedTransactionOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT [#DistributedTransactionInventory_Console]
            SELECT @Status,CONVERT(bit,1),[ctx].[ProductMajorVersion],
                   [cfg].[ConfiguredValue],[cfg].[RunningValue],
                   (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_linkedServerPromotion]),
                   (SELECT COUNT_BIG(*) FROM [#DistributedTransactionInventory_activeDistributedTransactions]),
                   N'Caller-sichtbare lokale SQL-Metadaten; keine DTC-Dienst-, Teilnehmer-, Commit- oder Recoveryprüfung.'
            FROM [#DistributedTransactionInventory_serverContext] AS [ctx]
            LEFT JOIN [#DistributedTransactionInventory_promotionConfiguration] AS [cfg] ON 1=1;
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DistributedTransactionInventory_Console',
                @ResultLabel=N'Sichtbare MSDTC-Konfiguration und aktive Transaktionsmetadaten',
                @EmptyMessage=N'Keine sichtbaren SQL-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_DistributedTransactionInventory: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),@Message=ERROR_MESSAGE(),@Json=NULL;
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO