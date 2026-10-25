/*
===============================================================================
Objekt       : snapshot.InternalPrepareCollectionCycle
Version      : 1.2.0
Stand        : 2026-10-25
Zweck        : Prüft Intervall und Größenbudget und eröffnet genau einen Lauf.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalPrepareCollectionCycle]
      @SourceDatabaseName sysname
    , @SchedulerType      varchar(16)
    , @RunEvenIfNotDue    bit
    , @CaptureRunIdOut    bigint OUTPUT
    , @ShouldCollectOut   bit OUTPUT
    , @StatusCodeOut      varchar(40) OUTPUT
    , @ErrorMessageOut    nvarchar(2048) OUTPUT
    , @CollectorCode      varchar(64) = 'PERFORMANCE_COUNTERS'
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetDatabaseName sysname = NULL
    , @ExpectedTargetCreateDate datetime = NULL
    , @PolicyOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),
            @IntervalSeconds smallint,
            @SoftBudgetMB bigint,
            @UsedDataMB decimal(19,3),
            @LastCompletedUtc datetime2(3);

    SELECT @CaptureRunIdOut=NULL,@ShouldCollectOut=0,
           @StatusCodeOut='AVAILABLE',@ErrorMessageOut=NULL;

    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @CollectorCode NOT IN ('PERFORMANCE_COUNTERS','WAIT_STATS')
       OR @PolicyOnly IS NULL OR (@PolicyOnly=1 AND @CollectorCode<>'WAIT_STATS')
       OR (@CollectorCode='WAIT_STATS' AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',
               @ErrorMessageOut=N'Ungültiger Collector oder unzulässiger Wait-Callertransaktionszustand.';
        RETURN 51011;
    END;
    IF @CollectorCode='WAIT_STATS' OR @ExpectedTargetDatabaseId IS NOT NULL
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
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',
                   @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
            RETURN;
        END;
    END;
    IF @CollectorCode='WAIT_STATS' AND
       ((SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
           AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') AND [SchemaVersion]=2)
        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                      WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                        AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly')))
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',
               @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.1 fehlt.';
        RETURN;
    END;

    SELECT @IntervalSeconds=[c].[CollectionIntervalSeconds],
           @SoftBudgetMB=[r].[SoftBudgetMB]
    FROM [snapshot].[CollectorPolicy] AS [c]
    JOIN [snapshot].[RetentionPolicy] AS [r]
      ON [r].[RetentionPolicyCode]=[c].[RetentionPolicyCode]
    WHERE [c].[CollectorCode]=@CollectorCode
      AND [c].[IsEnabled]=1;

    IF @IntervalSeconds IS NULL
        SELECT @StatusCodeOut='DISABLED',@ErrorMessageOut=CASE WHEN @CollectorCode='PERFORMANCE_COUNTERS' THEN N'Der Performance-Counter-Sammler ist deaktiviert.' ELSE N'Der Wait-Sammler ist deaktiviert.' END;

    IF @PolicyOnly=1
    BEGIN
        SELECT TOP(1) @LastCompletedUtc=[EndedAtUtc]
        FROM [snapshot].[CaptureRun]
        WHERE [CollectorCode]='WAIT_STATS' AND [EndedAtUtc] IS NOT NULL
        ORDER BY [CaptureRunId] DESC;
        IF @StatusCodeOut='AVAILABLE' AND @RunEvenIfNotDue=0 AND @LastCompletedUtc IS NOT NULL
           AND DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now
            SELECT @StatusCodeOut='SKIPPED_NOT_DUE',@ErrorMessageOut=N'Das konfigurierte Sammlerintervall ist noch nicht abgelaufen.';
        -- Budget is checked after the real purge in the normal preparation path.
        RETURN;
    END;

    SELECT @UsedDataMB=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @StatusCodeOut='AVAILABLE' AND @UsedDataMB>@SoftBudgetMB
        SELECT @StatusCodeOut='STOPPED_SIZE_BUDGET',
               @ErrorMessageOut=N'Das konfigurierte weiche Datenbudget ist nach dem Purge weiterhin überschritten.';

    SELECT TOP (1) @LastCompletedUtc=[EndedAtUtc]
    FROM [snapshot].[CaptureRun]
    WHERE [CollectorCode]=@CollectorCode
      AND (@CollectorCode='WAIT_STATS' OR [StatusCode] IN ('AVAILABLE','PARTIAL'))
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [CaptureRunId] DESC;

    IF @StatusCodeOut='AVAILABLE'
       AND @RunEvenIfNotDue=0
       AND @LastCompletedUtc IS NOT NULL
       AND DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',
               @ErrorMessageOut=N'Das konfigurierte Sammlerintervall ist noch nicht abgelaufen.';

    IF @CollectorCode='WAIT_STATS' AND @StatusCodeOut<>'AVAILABLE' RETURN;

    INSERT [snapshot].[CaptureRun]
    (
          [CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc]
        , [SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial]
        , [ErrorMessage],[MetricSampleCount],[PayloadCount]
    )
    VALUES
    (
          @CollectorCode,@SchedulerType,@Now
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN NULL ELSE @Now END
        , @SourceDatabaseName,1
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN 'RUNNING' ELSE @StatusCodeOut END
        , CASE WHEN @StatusCodeOut='AVAILABLE' THEN 0 ELSE 1 END
        , @ErrorMessageOut,0,0
    );

    SET @CaptureRunIdOut=CONVERT(bigint,SCOPE_IDENTITY());
    SET @ShouldCollectOut=CASE WHEN @StatusCodeOut='AVAILABLE' THEN 1 ELSE 0 END;

    IF @ShouldCollectOut=0
    BEGIN
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorMessage],[EvidenceLimit])
        VALUES
        (@CaptureRunIdOut,N'monitor.USP_PerformanceCounters',@Now,@StatusCodeOut,1,@ErrorMessageOut,
         N'Kein Quellread wurde ausgeführt.');
    END;
END;
GO
