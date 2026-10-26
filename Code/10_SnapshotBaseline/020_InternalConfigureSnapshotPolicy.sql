/*
===============================================================================
Objekt       : snapshot.InternalConfigureSnapshotPolicy
Version      : 1.2.0
Stand        : 2026-10-25
Zweck        : Schreibt die typisierten SC-023-Policies in der aktuell
               verbundenen Snapshot-Datenbank.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalConfigureSnapshotPolicy]
      @CollectionIntervalSeconds smallint
    , @MaxRows                  int
    , @PayloadEnabled           bit
    , @RawRetentionDays         smallint
    , @PayloadRetentionDays     smallint
    , @RollupRetentionDays      smallint
    , @SoftBudgetMB             int
    , @PurgeIntervalMinutes     smallint
    , @PurgeBatchRows           int
    , @BudgetAction             varchar(32)
    , @StatusCodeOut            varchar(40) OUTPUT
    , @ErrorNumberOut           int OUTPUT
    , @ErrorMessageOut          nvarchar(2048) OUTPUT
    , @CollectorCode            varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled         bit = 1
    , @UpdateSharedPolicy       bit = NULL
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetDatabaseName sysname = NULL
    , @ExpectedTargetCreateDate datetime = NULL
    , @JoinFrameworkTransaction bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut='AVAILABLE',@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @UpdateSharedPolicy IS NULL
        SET @UpdateSharedPolicy=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN 1 ELSE 0 END;
    DECLARE @UseV2Contract bit=CASE WHEN @CollectorCode<>'PERFORMANCE_COUNTERS'
             OR @CollectorEnabled<>1 OR @CollectorEnabled IS NULL OR @UpdateSharedPolicy<>1
             OR @ExpectedTargetDatabaseId IS NOT NULL OR @ExpectedTargetDatabaseName IS NOT NULL
             OR @ExpectedTargetCreateDate IS NOT NULL OR @JoinFrameworkTransaction<>0 THEN 1 ELSE 0 END,
            @OwnTransaction bit=0,@SavepointCreated bit=0;

    IF @JoinFrameworkTransaction IS NULL OR
       (@JoinFrameworkTransaction=1 AND
         (@CollectorCode NOT IN('WAIT_STATS','FILE_IO') OR @UpdateSharedPolicy<>1 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Die ausdrückliche Transaktionsbeteiligung benötigt WAIT_STATS oder FILE_IO mit Shared1 und eine committable Besitzertransaktion.';
        RETURN 51011;
    END;

    IF @UseV2Contract=1 AND ((@@OPTIONS & 2)<>0 OR (@CollectorCode IN('WAIT_STATS','FILE_IO') AND @@TRANCOUNT<>0 AND @JoinFrameworkTransaction=0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Collectorvertrag benötigt IMPLICIT_TRANSACTIONS OFF und außerhalb der Besitzerbeteiligung keine Callertransaktion.';
        RETURN 51011;
    END;

    IF @CollectorCode NOT IN ('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO') OR @CollectorEnabled IS NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungültiger Collector oder Aktivierungswert.';
        RETURN 51011;
    END;

    IF @CollectorCode IN('WAIT_STATS','FILE_IO') OR @ExpectedTargetDatabaseId IS NOT NULL
       OR @ExpectedTargetDatabaseName IS NOT NULL OR @ExpectedTargetCreateDate IS NOT NULL
    BEGIN
        IF @ExpectedTargetDatabaseId IS NULL OR @ExpectedTargetDatabaseName IS NULL
           OR @ExpectedTargetCreateDate IS NULL OR @ExpectedTargetDatabaseId<=4
           OR DB_ID()<>@ExpectedTargetDatabaseId
               OR NOT EXISTS
           (
               SELECT 1 FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
               WHERE [d].[database_id]=@ExpectedTargetDatabaseId
                 AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
                 AND [d].[create_date]=@ExpectedTargetCreateDate
                 AND [d].[state]=0 AND [d].[is_read_only]=0
           )
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53764,
                   @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
            RETURN;
        END;
    END;

    IF @UseV2Contract=1
    BEGIN
        IF @CollectionIntervalSeconds IS NULL OR @MaxRows IS NULL OR @PayloadEnabled IS NULL
           OR (@UpdateSharedPolicy=1 AND (@RawRetentionDays IS NULL OR @PayloadRetentionDays IS NULL
               OR @RollupRetentionDays IS NULL OR @SoftBudgetMB IS NULL OR @PurgeIntervalMinutes IS NULL
               OR @PurgeBatchRows IS NULL OR @BudgetAction IS NULL))
        BEGIN
            SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
                   @ErrorMessageOut=N'Eine wirksame Policyeigenschaft darf nicht NULL sein.';
            RETURN 51011;
        END;
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
            AND ((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') AND [SchemaVersion]=2) OR (CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') AND [SchemaVersion]=3)))
           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                         WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                           AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly'))
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53761,
                   @ErrorMessageOut=N'Das vollständig installierte kompatible Collector-Target fehlt.';
            RETURN;
        END;
    END;

    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE [PackageVersion]='1.3.0' AND [SchemaVersion]=3)
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53781,@ErrorMessageOut=N'Das vollständige Datei-I/O-Target 1.3.0 fehlt.';
        RETURN;
    END;

    IF @CollectionIntervalSeconds NOT BETWEEN 1 AND 3600
       OR @MaxRows NOT BETWEEN 1 AND 100000
       OR (@UpdateSharedPolicy=1 AND
          (@RawRetentionDays NOT BETWEEN 1 AND 3650
       OR @PayloadRetentionDays NOT BETWEEN 1 AND 3650
       OR @RollupRetentionDays NOT BETWEEN 1 AND 3650
       OR @SoftBudgetMB<1
       OR @PurgeIntervalMinutes NOT BETWEEN 1 AND 1440
       OR @PurgeBatchRows NOT BETWEEN 1 AND 100000
       OR @BudgetAction<>'PURGE_EXPIRED_THEN_STOP'))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',
               @ErrorMessageOut=N'Ungültige Snapshot-, Retention- oder Budgetpolicy.';
        RETURN;
    END;

    BEGIN TRY
        IF @UseV2Contract=0
            BEGIN TRANSACTION;
        ELSE IF @@TRANCOUNT=0
        BEGIN
            BEGIN TRANSACTION;
            SET @OwnTransaction=1;
        END
        ELSE IF @JoinFrameworkTransaction=0
        BEGIN
            SAVE TRANSACTION SQLSA_SnapshotPolicy;
            SET @SavepointCreated=1;
        END;

        IF @UpdateSharedPolicy=1
        UPDATE [snapshot].[RetentionPolicy]
        SET [RawRetentionDays]=@RawRetentionDays,
            [PayloadRetentionDays]=@PayloadRetentionDays,
            [RollupRetentionDays]=@RollupRetentionDays,
            [SoftBudgetMB]=@SoftBudgetMB,
            [PurgeIntervalMinutes]=@PurgeIntervalMinutes,
            [PurgeBatchRows]=@PurgeBatchRows,
            [BudgetAction]=@BudgetAction,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [RetentionPolicyCode]='DEFAULT';

        UPDATE [snapshot].[CollectorPolicy]
        SET [IsEnabled]=@CollectorEnabled,
            [CollectionIntervalSeconds]=@CollectionIntervalSeconds,
            [MaxRows]=@MaxRows,
            [PayloadEnabled]=@PayloadEnabled,
            [RetentionPolicyCode]=CASE WHEN @UpdateSharedPolicy=1 THEN 'DEFAULT' ELSE [RetentionPolicyCode] END,
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [CollectorCode]=@CollectorCode;

        IF @@ROWCOUNT<>1
        BEGIN
            IF @CollectorCode='PERFORMANCE_COUNTERS'
                THROW 53700,N'Die Performance-Counter-Policy fehlt.',1;
            THROW 53700,N'Die Wait-Policy fehlt.',1;
        END;

        IF @UseV2Contract=0 OR @OwnTransaction=1 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF (@UseV2Contract=0 OR @OwnTransaction=1) AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated=1 AND XACT_STATE()=1
            ROLLBACK TRANSACTION SQLSA_SnapshotPolicy;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;
END;
GO
