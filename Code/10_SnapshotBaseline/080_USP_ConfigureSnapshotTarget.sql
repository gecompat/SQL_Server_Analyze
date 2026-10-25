USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ConfigureSnapshotTarget
Version      : 1.1.0
Stand        : 2026-10-25
Zweck        : Aktiviert ein explizit installiertes SC-023-Ziel und schreibt
               alle bekannten Collector-/Retentionwerte typisiert.
Nebenwirkung : Persistente Konfiguration in Framework- und Snapshot-Datenbank.
Rechte       : Vergibt keine Rechte; DDL-/DML- und EXECUTE-Rechte sind extern.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ConfigureSnapshotTarget]
      @TargetDatabaseName       sysname
    , @IsEnabled                bit          = 1
    , @SchedulerType            varchar(16)  = 'EXTERNAL'
    , @CollectionIntervalSeconds smallint     = 30
    , @MaxRows                  int           = 1000
    , @PayloadEnabled           bit           = 0
    , @RawRetentionDays         smallint      = 14
    , @PayloadRetentionDays     smallint      = 7
    , @RollupRetentionDays      smallint      = 180
    , @SoftBudgetMB             int           = 10240
    , @PurgeIntervalMinutes     smallint      = 60
    , @PurgeBatchRows           int           = 10000
    , @BudgetAction             varchar(32)   = 'PURGE_EXPIRED_THEN_STOP'
    , @PrintMeldungen           bit           = 1
    , @Hilfe                    bit           = 0
    , @StatusCodeOut            varchar(40)   = NULL OUTPUT
    , @IsPartialOut             bit           = NULL OUTPUT
    , @ErrorNumberOut           int           = NULL OUTPUT
    , @ErrorMessageOut          nvarchar(2048)= NULL OUTPUT
    , @CollectorCode            varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled         bit = 1
    , @UpdateSharedPolicy       bit = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @UpdateSharedPolicy IS NULL SET @UpdateSharedPolicy=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN 1 ELSE 0 END;
    DECLARE @NewPolicyContract bit=CASE WHEN @CollectorCode<>'PERFORMANCE_COUNTERS' OR @CollectorEnabled<>1
       OR @CollectorEnabled IS NULL OR @UpdateSharedPolicy<>1 THEN 1 ELSE 0 END;
    IF @Hilfe=1 AND (@NewPolicyContract=1 OR @CollectorCode NOT IN('PERFORMANCE_COUNTERS','WAIT_STATS'))
    BEGIN
        PRINT N'monitor.USP_ConfigureSnapshotTarget';
        PRINT N'@CollectorCode wählt PERFORMANCE_COUNTERS oder WAIT_STATS; @CollectorEnabled steuert nur die ausgewählte Policy.';
        PRINT N'@UpdateSharedPolicy=0 erhält gemeinsame Werte; 1 ändert sie atomar. Neue Optionen benötigen Target 1.2.1.';
        RETURN;
    END;
    IF @CollectorCode NOT IN('PERFORMANCE_COUNTERS','WAIT_STATS') OR @CollectorEnabled IS NULL
       OR (@NewPolicyContract=1 AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Neue Collectoroptionen benötigen einen gültigen Collector ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ConfigureSnapshotTarget';
        PRINT N'Konfiguriert das separat installierte SC-023-Ziel. Keine Datenbank, Rechte oder Schedulerobjekte werden erstellt.';
        PRINT N'@CollectorCode=WAIT_STATS wählt ausdrücklich den Wait-Sammler. @CollectorEnabled steuert nur die ausgewählte Policy.';
        PRINT N'@UpdateSharedPolicy=0 erhält gemeinsame Werte; 1 ändert sie atomar. Neue Optionen benötigen Target 1.2.1 und keine Callertransaktion.';
        RETURN;
    END;

    SET @SchedulerType=UPPER(LTRIM(RTRIM(COALESCE(@SchedulerType,''))));
    SET @BudgetAction=UPPER(LTRIM(RTRIM(COALESCE(@BudgetAction,''))));

    IF @NewPolicyContract=1
    BEGIN
        DECLARE @NewTargetId int,@NewTargetCreated datetime,@NewTargetStatus varchar(40),@NewTargetError int,
                @NewTargetMessage nvarchar(2048),@NewSql nvarchar(max),@NewJoin bit,
                @NewPrint nvarchar(2048);
        BEGIN TRY
            IF NULLIF(LTRIM(RTRIM(@TargetDatabaseName)),N'') IS NULL
               OR (@UpdateSharedPolicy=1 AND (@IsEnabled IS NULL OR @SchedulerType NOT IN('MANUAL','EXTERNAL','SQL_AGENT')))
            BEGIN
                SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
                       @ErrorMessageOut=N'Ungültige wirksame Ziel-, Aktivierungs- oder Scheduleroption.';
                RETURN 51011;
            END;
            IF @UpdateSharedPolicy=0 AND NOT EXISTS
               (SELECT 1 FROM [monitor].[SnapshotTargetConfiguration]
                WHERE [ConfigurationId]=1 AND CONVERT(varbinary(max),[TargetDatabaseName])=CONVERT(varbinary(max),@TargetDatabaseName))
            BEGIN
                SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53764,
                       @ErrorMessageOut=N'Collector-only-Konfiguration benötigt die passende bestehende Framework-Zielbindung.';
                RETURN;
            END;
            EXEC [monitor].[InternalValidateSnapshotWaitTarget]
                 @TargetDatabaseName=@TargetDatabaseName,@TargetDatabaseIdOut=@NewTargetId OUTPUT,
                 @TargetCreateDateOut=@NewTargetCreated OUTPUT,@StatusCodeOut=@NewTargetStatus OUTPUT,
                 @ErrorNumberOut=@NewTargetError OUTPUT,@ErrorMessageOut=@NewTargetMessage OUTPUT;
            IF COALESCE(@NewTargetStatus,'')<>'AVAILABLE' OR @NewTargetError IS NOT NULL
            BEGIN
                SELECT @StatusCodeOut=COALESCE(NULLIF(@NewTargetStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                       @ErrorNumberOut=@NewTargetError,@ErrorMessageOut=@NewTargetMessage;
                RETURN;
            END;
            IF @UpdateSharedPolicy=1 BEGIN TRANSACTION;
            SET @NewJoin=CASE WHEN @CollectorCode='WAIT_STATS' AND @UpdateSharedPolicy=1 THEN 1 ELSE 0 END;
            SET @NewSql=N'EXEC '+QUOTENAME(@TargetDatabaseName)+N'.[snapshot].[InternalConfigureSnapshotPolicy]
 @CollectionIntervalSeconds=@Interval,@MaxRows=@MaxRows,@PayloadEnabled=@Payload,
 @RawRetentionDays=@RawDays,@PayloadRetentionDays=@PayloadDays,@RollupRetentionDays=@RollupDays,
 @SoftBudgetMB=@Budget,@PurgeIntervalMinutes=@PurgeMinutes,@PurgeBatchRows=@Batch,@BudgetAction=@Action,
 @StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=@Collector,@CollectorEnabled=@Enabled,@UpdateSharedPolicy=@Shared,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Target,@ExpectedTargetCreateDate=@Created,
 @JoinFrameworkTransaction=@Join;';
            EXEC [sys].[sp_executesql] @NewSql,
 N'@Interval smallint,@MaxRows int,@Payload bit,@RawDays smallint,@PayloadDays smallint,@RollupDays smallint,@Budget int,@PurgeMinutes smallint,@Batch int,@Action varchar(32),@Status varchar(40) OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT,@Collector varchar(64),@Enabled bit,@Shared bit,@Id int,@Target sysname,@Created datetime,@Join bit',
 @Interval=@CollectionIntervalSeconds,@MaxRows=@MaxRows,@Payload=@PayloadEnabled,@RawDays=@RawRetentionDays,
 @PayloadDays=@PayloadRetentionDays,@RollupDays=@RollupRetentionDays,@Budget=@SoftBudgetMB,
 @PurgeMinutes=@PurgeIntervalMinutes,@Batch=@PurgeBatchRows,@Action=@BudgetAction,
 @Status=@NewTargetStatus OUTPUT,@Error=@NewTargetError OUTPUT,@Message=@NewTargetMessage OUTPUT,
 @Collector=@CollectorCode,@Enabled=@CollectorEnabled,@Shared=@UpdateSharedPolicy,@Id=@NewTargetId,
 @Target=@TargetDatabaseName,@Created=@NewTargetCreated,@Join=@NewJoin;
            IF COALESCE(@NewTargetStatus,'')<>'AVAILABLE' OR @NewTargetError IS NOT NULL
            BEGIN
                -- Entry admitted no Caller transaction; any remaining TX belongs to this operation.
                IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
                SELECT @StatusCodeOut=COALESCE(NULLIF(@NewTargetStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                       @ErrorNumberOut=@NewTargetError,@ErrorMessageOut=@NewTargetMessage;
                RETURN;
            END;
            IF @UpdateSharedPolicy=1
            BEGIN
                IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53768,N'Die eigene Konfigurationstransaktion hat ihren Zustand geändert.',1;
                UPDATE [monitor].[SnapshotTargetConfiguration]
                SET [TargetDatabaseName]=@TargetDatabaseName,[IsEnabled]=@IsEnabled,[DefaultSchedulerType]=@SchedulerType,
                    [PackageContractVersion]=1,[LastUpdatedUtc]=SYSUTCDATETIME()
                WHERE [ConfigurationId]=1;
                IF @@ROWCOUNT<>1 THROW 53701,N'Die Framework-Zielkonfiguration fehlt.',1;
                IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53768,N'Der Frameworkwrite hat den Transaktionszustand geändert.',1;
                COMMIT TRANSACTION;
            END
            ELSE IF @@TRANCOUNT<>0 THROW 53768,N'Der Collector-only-Aufruf hat eine unerwartete Transaktion hinterlassen.',1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
                   @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());
        END CATCH;
        IF @PrintMeldungen=1 AND @StatusCodeOut<>'AVAILABLE'
        BEGIN
            SET @NewPrint=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
            RAISERROR(N'USP_ConfigureSnapshotTarget: %s',10,1,@NewPrint) WITH NOWAIT;
        END;
        RETURN;
    END;

    IF NULLIF(LTRIM(RTRIM(@TargetDatabaseName)),N'') IS NULL
       OR @SchedulerType NOT IN ('MANUAL','EXTERNAL','SQL_AGENT')
       OR @IsEnabled IS NULL OR @IsEnabled NOT IN (0,1)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Zielname, Aktivierungswert oder Scheduler-Typ.';
        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM [master].[sys].[databases] WITH (NOLOCK)
        WHERE [name]=@TargetDatabaseName
          AND [state]=0
          AND [is_read_only]=0
    )
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,
               @ErrorMessageOut=N'Die konfigurierte Snapshot-Datenbank ist nicht online und schreibbar.';
        RETURN;
    END;

    DECLARE @Sql nvarchar(max),@TargetQuoted nvarchar(258)=QUOTENAME(@TargetDatabaseName),
            @TargetStatus varchar(40),@TargetError int,@TargetMessage nvarchar(2048);

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalConfigureSnapshotPolicy]
              @CollectionIntervalSeconds=@p1,@MaxRows=@p2,@PayloadEnabled=@p3,
              @RawRetentionDays=@p4,@PayloadRetentionDays=@p5,@RollupRetentionDays=@p6,
              @SoftBudgetMB=@p7,@PurgeIntervalMinutes=@p8,@PurgeBatchRows=@p9,
              @BudgetAction=@p10,@StatusCodeOut=@s OUTPUT,@ErrorNumberOut=@e OUTPUT,
              @ErrorMessageOut=@m OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
             N'@p1 smallint,@p2 int,@p3 bit,@p4 smallint,@p5 smallint,@p6 smallint,@p7 int,@p8 smallint,@p9 int,@p10 varchar(32),@s varchar(40) OUTPUT,@e int OUTPUT,@m nvarchar(2048) OUTPUT',
             @CollectionIntervalSeconds,@MaxRows,@PayloadEnabled,@RawRetentionDays,@PayloadRetentionDays,@RollupRetentionDays,
             @SoftBudgetMB,@PurgeIntervalMinutes,@PurgeBatchRows,@BudgetAction,
             @s=@TargetStatus OUTPUT,@e=@TargetError OUTPUT,@m=@TargetMessage OUTPUT;

        IF @TargetStatus<>'AVAILABLE'
        BEGIN
            ROLLBACK TRANSACTION;
            SELECT @StatusCodeOut=@TargetStatus,@IsPartialOut=1,@ErrorNumberOut=@TargetError,@ErrorMessageOut=@TargetMessage;
            RETURN;
        END;

        UPDATE [monitor].[SnapshotTargetConfiguration]
        SET [TargetDatabaseName]=@TargetDatabaseName,[IsEnabled]=@IsEnabled,
            [DefaultSchedulerType]=@SchedulerType,[PackageContractVersion]=1,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [ConfigurationId]=1;

        IF @@ROWCOUNT<>1
            THROW 53701,N'Die Framework-Zielkonfiguration fehlt.',1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'TARGET_UNAVAILABLE' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;

    IF @PrintMeldungen=1 AND @StatusCodeOut<>'AVAILABLE'
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
        RAISERROR(N'USP_ConfigureSnapshotTarget: %s',10,1,@PrintMessage) WITH NOWAIT;
    END;
END;
GO
