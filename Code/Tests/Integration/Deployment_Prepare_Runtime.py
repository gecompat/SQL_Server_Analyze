#!/usr/bin/env python3
"""Build a native synthetic deployment regression; never connect to a server.

The emitted SQL creates two explicitly named test databases only when neither
exists. It leaves its databases intact for inspection. Execute only in a
dedicated SQL Server test instance, for example the functional-impact CI job.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('deployment_generator', ROOT / 'Code/Install/deployment_generator.py')
g = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = g
spec.loader.exec_module(g)
FRAMEWORK = 'SQLServerAnalyzeDeploymentFramework'
TARGET = 'SQLServerAnalyzeDeploymentTarget'

# Exact historical helper from 4ca1916c, retained solely as an upgrade fixture.
# It is never a product installer input. Normalize repository line endings only.
LEGACY_PURGE_V1_1_0 = r"""/*
===============================================================================
Objekt       : snapshot.InternalPurgeExpiredData
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Löscht ausschließlich abgelaufene Snapshotdaten child-first in
               begrenzten Batches; nicht abgelaufene Daten bleiben erhalten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalPurgeExpiredData]
      @MaxBatches        int
    , @Force             bit
    , @PurgeRunIdOut     bigint OUTPUT
    , @StatusCodeOut     varchar(40) OUTPUT
    , @BudgetExceededOut bit OUTPUT
    , @ErrorNumberOut    int OUTPUT
    , @ErrorMessageOut   nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 0;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),
            @RawRetentionDays smallint,
            @PayloadRetentionDays smallint,
            @PurgeIntervalMinutes smallint,
            @BatchRows int,
            @SoftBudgetMB bigint,
            @UsedBefore decimal(19,3),
            @UsedAfter decimal(19,3),
            @LastPurgeUtc datetime2(3),
            @Batch int=0,
            @Deleted int,
            @Rows int,
            @MetricDeleted bigint=0,
            @PayloadDeleted bigint=0,
            @ModuleDeleted bigint=0,
            @RunsDeleted bigint=0,
            @ScopeDeleted bigint=0;

    SELECT @PurgeRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@BudgetExceededOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @MaxBatches NOT BETWEEN 1 AND 1000
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorMessageOut=N'@MaxBatches muss zwischen 1 und 1000 liegen.';
        RETURN;
    END;

    SELECT @RawRetentionDays=[RawRetentionDays],
           @PayloadRetentionDays=[PayloadRetentionDays],
           @PurgeIntervalMinutes=[PurgeIntervalMinutes],
           @BatchRows=[PurgeBatchRows],
           @SoftBudgetMB=[SoftBudgetMB]
    FROM [snapshot].[RetentionPolicy]
    WHERE [RetentionPolicyCode]='DEFAULT';

    SELECT TOP (1) @LastPurgeUtc=[EndedAtUtc]
    FROM [snapshot].[PurgeRun]
    WHERE [StatusCode] IN ('AVAILABLE','AVAILABLE_LIMITED')
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [PurgeRunId] DESC;

    SELECT @UsedBefore=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @Force=0
       AND @UsedBefore<=@SoftBudgetMB
       AND @LastPurgeUtc IS NOT NULL
       AND DATEADD(MINUTE,@PurgeIntervalMinutes,@LastPurgeUtc)>@Now
    BEGIN
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',@BudgetExceededOut=0;
        RETURN;
    END;

    INSERT [snapshot].[PurgeRun]
    ([StartedAtUtc],[StatusCode],[UsedDataMbBefore],[SoftBudgetMb])
    VALUES (@Now,'RUNNING',@UsedBefore,@SoftBudgetMB);
    SET @PurgeRunIdOut=CONVERT(bigint,SCOPE_IDENTITY());

    BEGIN TRY
        WHILE @Batch<@MaxBatches
        BEGIN
            SET @Deleted=0;
            BEGIN TRANSACTION;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[MetricSample] AS [m]
            WHERE [m].[CollectedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @MetricDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [p]
            FROM [snapshot].[PayloadSnapshot] AS [p]
            WHERE [p].[CapturedAtUtc]<DATEADD(DAY,-@PayloadRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @PayloadDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[ModuleStatus] AS [m]
            JOIN [snapshot].[CaptureRun] AS [r]
              ON [r].[CaptureRunId]=[m].[CaptureRunId]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId]);
            SET @Rows=@@ROWCOUNT;
            SET @ModuleDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [r]
            FROM [snapshot].[CaptureRun] AS [r]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [p] WHERE [p].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[ModuleStatus] AS [s] WHERE [s].[CaptureRunId]=[r].[CaptureRunId]);
            SET @Rows=@@ROWCOUNT;
            SET @RunsDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [s]
            FROM [snapshot].[Scope] AS [s]
            WHERE [s].[ScopeType]<>'SERVER'
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[ScopeId]=[s].[ScopeId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[Scope] AS [c] WHERE [c].[ParentScopeId]=[s].[ScopeId]);
            SET @Rows=@@ROWCOUNT;
            SET @ScopeDeleted+=@Rows;
            SET @Deleted+=@Rows;

            COMMIT TRANSACTION;
            SET @Batch+=1;
            IF @Deleted=0 BREAK;
        END;

        SELECT @UsedAfter=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
        FROM [sys].[database_files] WITH (NOLOCK)
        WHERE [type]=0;

        SET @BudgetExceededOut=CASE WHEN @UsedAfter>@SoftBudgetMB THEN 1 ELSE 0 END;
        SET @StatusCodeOut=CASE WHEN @Batch>=@MaxBatches AND @Deleted>0 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END;

        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [UsedDataMbAfter]=@UsedAfter
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @BudgetExceededOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END CATCH;
END;
GO
"""
LEGACY_PURGE_V1_1_0_SHA256 = 'ebf85095ea0800d39ac05daf136a5c6a20d10b3a4742d890883d44ce53cea408'


def configured(sql, framework=FRAMEWORK, target=TARGET):
    return sql.replace("@FrameworkDatabase nvarchar(max)=N'DeineDatenbank'", '@FrameworkDatabase nvarchar(max)='+g.lit(framework), 1).replace('@SnapshotDatabase nvarchar(max)=NULL', '@SnapshotDatabase nvarchar(max)='+g.lit(target), 1)


def negative(sql, number, label, assert_sql=''):
    return (f"BEGIN TRY EXEC sys.sp_executesql {g.lit(sql)}; THROW 53800,{g.lit('Expected rejection: '+label)},1; END TRY\n"
            f"BEGIN CATCH IF ERROR_NUMBER()<>{number} THROW; END CATCH;\n{assert_sql}\nGO\n")


def binary_columns(table):
    return ','.join('CONVERT(varbinary(max),'+g.q(name)+') AS '+g.q(name) for name in table.columns)


def equal_rows(left, right, columns, label):
    return (f"IF EXISTS(SELECT {columns} FROM {left} EXCEPT SELECT {columns} FROM {right}) "
            f"OR EXISTS(SELECT {columns} FROM {right} EXCEPT SELECT {columns} FROM {left}) "
            f"OR (SELECT COUNT_BIG(*) FROM {left})<>(SELECT COUNT_BIG(*) FROM {right}) "
            f"THROW 53801,{g.lit('Binary value mismatch: '+label)},1;\n")


# Historical 1.1.1 modules from e2fd110e; synthetic upgrade fixtures only.
LEGACY_TARGET_V1_1_1 = {
'020_InternalConfigureSnapshotPolicy.sql': ('e56d0e1976ff6db332d01f2dea3195cbc4701ad3d8e3c80d17e98569affe69d2', r"""/*
===============================================================================
Objekt       : snapshot.InternalConfigureSnapshotPolicy
Version      : 1.0.0
Stand        : 2026-07-21
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
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut='AVAILABLE',@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @CollectionIntervalSeconds NOT BETWEEN 1 AND 3600
       OR @MaxRows NOT BETWEEN 1 AND 100000
       OR @RawRetentionDays NOT BETWEEN 1 AND 3650
       OR @PayloadRetentionDays NOT BETWEEN 1 AND 3650
       OR @RollupRetentionDays NOT BETWEEN 1 AND 3650
       OR @SoftBudgetMB<1
       OR @PurgeIntervalMinutes NOT BETWEEN 1 AND 1440
       OR @PurgeBatchRows NOT BETWEEN 1 AND 100000
       OR @BudgetAction<>'PURGE_EXPIRED_THEN_STOP'
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',
               @ErrorMessageOut=N'Ungültige Snapshot-, Retention- oder Budgetpolicy.';
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

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
        SET [IsEnabled]=1,
            [CollectionIntervalSeconds]=@CollectionIntervalSeconds,
            [MaxRows]=@MaxRows,
            [PayloadEnabled]=@PayloadEnabled,
            [RetentionPolicyCode]='DEFAULT',
            [LastUpdatedUtc]=SYSUTCDATETIME()
        WHERE [CollectorCode]='PERFORMANCE_COUNTERS';

        IF @@ROWCOUNT<>1
            THROW 53700,N'Die Performance-Counter-Policy fehlt.',1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;
END;
GO
"""),
'040_InternalPrepareCollectionCycle.sql': ('a7713788bbc7fdb106b70c5db39c6ecec794111cfac05ee435c388b94de44130', r"""/*
===============================================================================
Objekt       : snapshot.InternalPrepareCollectionCycle
Version      : 1.0.0
Stand        : 2026-07-21
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

    SELECT @IntervalSeconds=[c].[CollectionIntervalSeconds],
           @SoftBudgetMB=[r].[SoftBudgetMB]
    FROM [snapshot].[CollectorPolicy] AS [c]
    JOIN [snapshot].[RetentionPolicy] AS [r]
      ON [r].[RetentionPolicyCode]=[c].[RetentionPolicyCode]
    WHERE [c].[CollectorCode]='PERFORMANCE_COUNTERS'
      AND [c].[IsEnabled]=1;

    IF @IntervalSeconds IS NULL
        SELECT @StatusCodeOut='DISABLED',@ErrorMessageOut=N'Der Performance-Counter-Sammler ist deaktiviert.';

    SELECT @UsedDataMB=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @StatusCodeOut='AVAILABLE' AND @UsedDataMB>@SoftBudgetMB
        SELECT @StatusCodeOut='STOPPED_SIZE_BUDGET',
               @ErrorMessageOut=N'Das konfigurierte weiche Datenbudget ist nach dem Purge weiterhin überschritten.';

    SELECT TOP (1) @LastCompletedUtc=[EndedAtUtc]
    FROM [snapshot].[CaptureRun]
    WHERE [CollectorCode]='PERFORMANCE_COUNTERS'
      AND [StatusCode] IN ('AVAILABLE','PARTIAL')
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [CaptureRunId] DESC;

    IF @StatusCodeOut='AVAILABLE'
       AND @RunEvenIfNotDue=0
       AND @LastCompletedUtc IS NOT NULL
       AND DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',
               @ErrorMessageOut=N'Das konfigurierte Sammlerintervall ist noch nicht abgelaufen.';

    INSERT [snapshot].[CaptureRun]
    (
          [CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc]
        , [SourceDatabaseName],[ContractVersion],[StatusCode],[IsPartial]
        , [ErrorMessage],[MetricSampleCount],[PayloadCount]
    )
    VALUES
    (
          'PERFORMANCE_COUNTERS',@SchedulerType,@Now
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
"""),
'070_InternalPurgeExpiredData.sql': ('4b1bdeaeb915409c9a53d2f6ec2f7bf35dfb9b35bb43a3ef7fb0fbd93bea239b', r"""/*
===============================================================================
Objekt       : snapshot.InternalPurgeExpiredData
Version      : 1.0.1
Stand        : 2026-10-25
Zweck        : Löscht ausschließlich abgelaufene Snapshotdaten child-first in
               begrenzten Batches; nicht abgelaufene Daten bleiben erhalten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalPurgeExpiredData]
      @MaxBatches        int
    , @Force             bit
    , @PurgeRunIdOut     bigint OUTPUT
    , @StatusCodeOut     varchar(40) OUTPUT
    , @BudgetExceededOut bit OUTPUT
    , @ErrorNumberOut    int OUTPUT
    , @ErrorMessageOut   nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 0;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),
            @RawRetentionDays smallint,
            @PayloadRetentionDays smallint,
            @PurgeIntervalMinutes smallint,
            @BatchRows int,
            @SoftBudgetMB bigint,
            @UsedBefore decimal(19,3),
            @UsedAfter decimal(19,3),
            @LastPurgeUtc datetime2(3),
            @Batch int=0,
            @Deleted int,
            @Rows int,
            @MetricDeleted bigint=0,
            @PayloadDeleted bigint=0,
            @ModuleDeleted bigint=0,
            @RunsDeleted bigint=0,
            @ScopeDeleted bigint=0;

    SELECT @PurgeRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@BudgetExceededOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @MaxBatches NOT BETWEEN 1 AND 1000
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorMessageOut=N'@MaxBatches muss zwischen 1 und 1000 liegen.';
        RETURN;
    END;

    SELECT @RawRetentionDays=[RawRetentionDays],
           @PayloadRetentionDays=[PayloadRetentionDays],
           @PurgeIntervalMinutes=[PurgeIntervalMinutes],
           @BatchRows=[PurgeBatchRows],
           @SoftBudgetMB=[SoftBudgetMB]
    FROM [snapshot].[RetentionPolicy]
    WHERE [RetentionPolicyCode]='DEFAULT';

    SELECT TOP (1) @LastPurgeUtc=[EndedAtUtc]
    FROM [snapshot].[PurgeRun]
    WHERE [StatusCode] IN ('AVAILABLE','AVAILABLE_LIMITED')
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [PurgeRunId] DESC;

    SELECT @UsedBefore=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @Force=0
       AND @UsedBefore<=@SoftBudgetMB
       AND @LastPurgeUtc IS NOT NULL
       AND DATEADD(MINUTE,@PurgeIntervalMinutes,@LastPurgeUtc)>@Now
    BEGIN
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',@BudgetExceededOut=0;
        RETURN;
    END;

    INSERT [snapshot].[PurgeRun]
    ([StartedAtUtc],[StatusCode],[UsedDataMbBefore],[SoftBudgetMb])
    VALUES (@Now,'RUNNING',@UsedBefore,@SoftBudgetMB);
    SET @PurgeRunIdOut=CONVERT(bigint,SCOPE_IDENTITY());

    BEGIN TRY
        WHILE @Batch<@MaxBatches
        BEGIN
            SET @Deleted=0;
            BEGIN TRANSACTION;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[MetricSample] AS [m]
            WHERE [m].[CollectedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @MetricDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [p]
            FROM [snapshot].[PayloadSnapshot] AS [p]
            WHERE [p].[CapturedAtUtc]<DATEADD(DAY,-@PayloadRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @PayloadDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[ModuleStatus] AS [m]
            JOIN [snapshot].[CaptureRun] AS [r]
              ON [r].[CaptureRunId]=[m].[CaptureRunId]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId]);
            SET @Rows=@@ROWCOUNT;
            SET @ModuleDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [r]
            FROM [snapshot].[CaptureRun] AS [r]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [p] WHERE [p].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[ModuleStatus] AS [s] WHERE [s].[CaptureRunId]=[r].[CaptureRunId])
              -- Preserve the latest finalized Wait run as the comparison fence,
              -- including a failed run whose children have expired or never existed.
              AND
              (
                  [r].[CollectorCode]<>'WAIT_STATS'
                  OR [r].[EndedAtUtc] IS NULL
                  OR EXISTS
                  (
                      SELECT 1 FROM [snapshot].[CaptureRun] AS [later]
                      WHERE [later].[CollectorCode]='WAIT_STATS'
                        AND [later].[EndedAtUtc] IS NOT NULL
                        AND [later].[CaptureRunId]>[r].[CaptureRunId]
                  )
              );
            SET @Rows=@@ROWCOUNT;
            SET @RunsDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [s]
            FROM [snapshot].[Scope] AS [s]
            WHERE [s].[ScopeType]<>'SERVER'
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[ScopeId]=[s].[ScopeId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[Scope] AS [c] WHERE [c].[ParentScopeId]=[s].[ScopeId]);
            SET @Rows=@@ROWCOUNT;
            SET @ScopeDeleted+=@Rows;
            SET @Deleted+=@Rows;

            COMMIT TRANSACTION;
            SET @Batch+=1;
            IF @Deleted=0 BREAK;
        END;

        SELECT @UsedAfter=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
        FROM [sys].[database_files] WITH (NOLOCK)
        WHERE [type]=0;

        SET @BudgetExceededOut=CASE WHEN @UsedAfter>@SoftBudgetMB THEN 1 ELSE 0 END;
        SET @StatusCodeOut=CASE WHEN @Batch>=@MaxBatches AND @Deleted>0 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END;

        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [UsedDataMbAfter]=@UsedAfter
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @BudgetExceededOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END CATCH;
END;
GO
"""),
}

# Released 1.2.0 helpers at 8046679c; exact affected upgrade inputs.
LEGACY_TARGET_V1_2_0 = {
'020_InternalConfigureSnapshotPolicy.sql': ('a54532eb001f8a4b2bfc088fd7ed1cd0c48719e62c42c192fd23a85bbc7c58fe', r"""/*
===============================================================================
Objekt       : snapshot.InternalConfigureSnapshotPolicy
Version      : 1.1.0
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
             OR @ExpectedTargetCreateDate IS NOT NULL THEN 1 ELSE 0 END,
            @OwnTransaction bit=0;

    IF @UseV2Contract=1 AND ((@@OPTIONS & 2)<>0 OR (@CollectorCode='WAIT_STATS' AND @@TRANCOUNT<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der neue Wait-Vertrag benötigt IMPLICIT_TRANSACTIONS OFF und für WAIT_STATS keine Callertransaktion.';
        RETURN 51011;
    END;

    IF @CollectorCode NOT IN ('PERFORMANCE_COUNTERS','WAIT_STATS') OR @CollectorEnabled IS NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungültiger Collector oder Aktivierungswert.';
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
            AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.0') AND [SchemaVersion]=2)
           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                         WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                           AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly'))
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53761,
                   @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.0 fehlt.';
            RETURN;
        END;
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
        ELSE SAVE TRANSACTION SQLSA_SnapshotPolicy;

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
        ELSE IF @UseV2Contract=1 AND @OwnTransaction=0 AND XACT_STATE()=1
            ROLLBACK TRANSACTION SQLSA_SnapshotPolicy;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=ERROR_MESSAGE();
    END CATCH;
END;
GO
"""),
'040_InternalPrepareCollectionCycle.sql': ('8231718112476b559c74c9fbb61d194f33ec184578e7dce2a263d68c8e8ff186', r"""/*
===============================================================================
Objekt       : snapshot.InternalPrepareCollectionCycle
Version      : 1.1.0
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
           AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.0') AND [SchemaVersion]=2)
        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS [wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))
        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] WITH (NOLOCK)
                      WHERE [p].[object_id] IN(SELECT [hp].[object_id] FROM [sys].[procedures] AS [hp] WITH (NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON [hs].[schema_id]=[hp].[schema_id] WHERE CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') AND CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))
                        AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly')))
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',
               @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.0 fehlt.';
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
"""),
'055_InternalCompleteWaitStatsCycle.sql': ('f8c97b31a9c3063bf8f56b0e8865ff1db12573216ab7049b5a3626e87e2a7f48', r"""/*
===============================================================================
Objekt       : snapshot.InternalCompleteWaitStatsCycle
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure bindet einen vollständigen Waitread an seinen Run
               und speichert Rohwerte und Differenzkandidaten atomar.
Grenze       : Monotonie beweist keine ununterbrochene Resetkontinuität.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalCompleteWaitStatsCycle]
      @CaptureRunId bigint
    , @CollectorJson nvarchar(max)
    , @ExpectedTargetDatabaseId int
    , @ExpectedTargetDatabaseName sysname
    , @ExpectedTargetCreateDate datetime
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
AS
BEGIN
    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @CaptureRunId IS NULL OR @CaptureRunId<=0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Waitabschluss benötigt einen gültigen Lauf ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
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
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53764,
               @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
        RETURN;
    END;

    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET XACT_ABORT ON;

    DECLARE @OwnRun bit=0,@StartedAtUtc datetime2(3),@MaxRows int,@PayloadEnabled bit,
            @PolicyEnabled bit,@SourceStatus varchar(40),@SourcePartial bit,@SourceComplete bit,
            @SourceError int,@SourceMessage nvarchar(2048),@NativeRows bigint,
            @MeasurementStart datetime2(3),@MeasurementEnd datetime2(3),
            @EngineName nvarchar(128),@EngineStartLocal datetime,@EngineTicks bigint,
            @MetaJson nvarchar(max),@EngineJson nvarchar(max),@Epoch uniqueidentifier,
            @ServerScopeId bigint,@PreviousRunId bigint,@PreviousContext nvarchar(max),
            @PreviousContextVersion int,@ComparisonStatus varchar(40),@EpochDecision varchar(40),
            @RawJson nvarchar(max),@ContextJson nvarchar(max),@RawHash varbinary(32),
            @WrittenTypes bigint=0,@ActiveTypes bigint=0,@EligibleTypes bigint=0,
            @ComparableTypes bigint=0,@CandidateSamples bigint=0,@WriteLimited bit=0;

    DECLARE @SourceRoot TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceMeta TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceEngine TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceRows TABLE([Ordinal] bigint,[Json] nvarchar(max),[JsonType] int);
    DECLARE @SourceRowFields TABLE([Ordinal] bigint,[Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @Waits TABLE
    (
        [WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [WaitingTasksCount] bigint NOT NULL,[WaitTimeMs] bigint NOT NULL,
        [MaxWaitTimeMs] bigint NOT NULL,[SignalWaitTimeMs] bigint NOT NULL,
        [ScopeIdentityJson] nvarchar(max) NOT NULL,[ScopeKeyHash] binary(32) NOT NULL,
        [IsEligible] bit NOT NULL DEFAULT(0),[IsSelected] bit NOT NULL DEFAULT(0),
        [ScopeId] bigint NULL,[IsComparable] bit NOT NULL DEFAULT(0),
        [DeltaStatus] varchar(40) NULL
    );

    BEGIN TRY
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
           (SELECT 1 FROM [snapshot].[PackageVersion]
            WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
              AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.0')
              AND [SchemaVersion]=2)
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,
                   @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.0 fehlt.';
            RETURN;
        END;
        DECLARE @ProbeRun bigint,@ProbeStatus varchar(40),@ProbeBudget bit,@ProbeError int,
                @ProbeMessage nvarchar(2048),@RetentionContract int;
        EXEC [snapshot].[InternalPurgeExpiredData]
             @MaxBatches=1,@Force=0,@PurgeRunIdOut=@ProbeRun OUTPUT,@StatusCodeOut=@ProbeStatus OUTPUT,
             @BudgetExceededOut=@ProbeBudget OUTPUT,@ErrorNumberOut=@ProbeError OUTPUT,
             @ErrorMessageOut=@ProbeMessage OUTPUT,@ContractOnly=1,
             @RetentionContractVersionOut=@RetentionContract OUTPUT,
             @ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,
             @ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,
             @ExpectedTargetCreateDate=@ExpectedTargetCreateDate;
        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR COALESCE(@RetentionContract,0)<>1
           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT NULL
            THROW 53762,N'Der benötigte read-only Retentionsvertrag fehlt.',1;

        BEGIN TRANSACTION;
        SELECT @StartedAtUtc=[StartedAtUtc]
        FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)
        WHERE [CaptureRunId]=@CaptureRunId
          AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'WAIT_STATS')
          AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING'
          AND [ResetEpochId] IS NULL AND [MetricSampleCount]=0 AND [PayloadCount]=0;
        IF @StartedAtUtc IS NULL
           OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
            THROW 53763,N'Der Waitabschluss benötigt genau einen unbeschriebenen eigenen laufenden Wait-Run.',1;
        SET @OwnRun=1;
        SELECT @MaxRows=[MaxRows],@PayloadEnabled=[PayloadEnabled],@PolicyEnabled=[IsEnabled]
        FROM [snapshot].[CollectorPolicy]
        WHERE [CollectorCode]='WAIT_STATS';
        IF COALESCE(@PolicyEnabled,0)<>1 OR @MaxRows IS NULL OR @MaxRows NOT BETWEEN 1 AND 100000
            THROW 53763,N'Die aktive gültige Wait-Policy fehlt.',1;

        IF COALESCE(ISJSON(@CollectorJson),0)<>1
            THROW 53763,N'Der transiente Wait-Sourcevertrag ist kein gültiges JSON-Objekt.',1;
        INSERT @SourceRoot SELECT [key],[value],[type] FROM OPENJSON(@CollectorJson);
        IF (SELECT COUNT_BIG(*) FROM @SourceRoot)<>2
           OR (SELECT COUNT_BIG(*) FROM @SourceRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'meta') AND [JsonType]=5)<>1
           OR (SELECT COUNT_BIG(*) FROM @SourceRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'waits') AND [JsonType]=4)<>1
            THROW 53763,N'Der transiente Wait-Rootvertrag ist ungültig.',1;
        SELECT @MetaJson=[Value] FROM @SourceRoot WHERE [Name]=N'meta';
        INSERT @SourceMeta SELECT [key],[value],[type] FROM OPENJSON(@MetaJson);
        DECLARE @ExpectedMeta TABLE([Name] nvarchar(60),[Type1] int,[Type2] int);
        INSERT @ExpectedMeta VALUES
          (N'schemaVersion',2,2),(N'resultName',1,1),(N'measurementStartUtc',1,0),
          (N'measurementEndUtc',1,0),(N'statusCode',1,1),(N'isPartial',3,3),
          (N'errorNumber',2,0),(N'errorMessage',1,0),(N'nativeRows',1,0),
          (N'sourceComplete',3,3),(N'engineContext',5,0);
        IF (SELECT COUNT_BIG(*) FROM @SourceMeta)<>11
           OR EXISTS
           (SELECT 1 FROM @ExpectedMeta AS [e]
            WHERE (SELECT COUNT_BIG(*) FROM @SourceMeta AS [m]
                   WHERE CONVERT(varbinary(max),[m].[Name])=CONVERT(varbinary(max),[e].[Name])
                     AND [m].[JsonType] IN([e].[Type1],[e].[Type2]))<>1)
           OR NOT EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'schemaVersion' AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'1'))
           OR NOT EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'resultName' AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'SnapshotWaitStats'))
            THROW 53763,N'Der transiente Wait-Metavertrag ist ungültig.',1;
        IF NOT EXISTS
           (SELECT 1 FROM @SourceMeta AS [m]
            CROSS JOIN (VALUES(N'AVAILABLE'),(N'EMPTY_UNPROVEN'),(N'DENIED_PERMISSION'),
                              (N'UNAVAILABLE_OBJECT'),(N'ERROR_HANDLED')) AS [v]([Status])
            WHERE [m].[Name]=N'statusCode'
              AND CONVERT(varbinary(max),[m].[Value])=CONVERT(varbinary(max),[v].[Status]))
            THROW 53763,N'Der transiente Source-Status ist unbekannt.',1;
        SELECT @SourceStatus=CONVERT(varchar(40),[Value]) FROM @SourceMeta WHERE [Name]=N'statusCode';
        SELECT @SourceComplete=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @SourceMeta WHERE [Name]=N'sourceComplete';
        SELECT @SourcePartial=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @SourceMeta WHERE [Name]=N'isPartial';
        SELECT @EngineJson=[Value] FROM @SourceMeta WHERE [Name]=N'engineContext';
        SELECT @SourceMessage=[Value] FROM @SourceMeta WHERE [Name]=N'errorMessage';
        IF EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'errorMessage' AND DATALENGTH([Value])>4096)
           OR EXISTS
           (SELECT 1 FROM @SourceMeta WHERE [Name]=N'errorNumber' AND [JsonType]<>0
            AND (TRY_CONVERT(int,[Value]) IS NULL OR TRY_CONVERT(int,[Value])<=0
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[Value])))))
            THROW 53763,N'Der transiente Fehlervertrag ist ungültig.',1;
        SELECT @SourceError=TRY_CONVERT(int,[Value]) FROM @SourceMeta WHERE [Name]=N'errorNumber';

        IF EXISTS
           (SELECT 1 FROM @SourceMeta WHERE [Name] IN(N'measurementStartUtc',N'measurementEndUtc') AND [JsonType]<>0
            AND (DATALENGTH([Value])<>48 OR RIGHT([Value],1)<>N'Z'
                 OR TRY_CONVERT(datetime2(3),LEFT([Value],23),126) IS NULL
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime2(3),LEFT([Value],23),126))),3)+N'Z')))
            THROW 53763,N'Das transiente UTC-Messfenster ist ungültig.',1;
        SELECT @MeasurementStart=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @SourceMeta WHERE [Name]=N'measurementStartUtc';
        SELECT @MeasurementEnd=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @SourceMeta WHERE [Name]=N'measurementEndUtc';
        IF (@MeasurementStart IS NULL AND @MeasurementEnd IS NOT NULL)
           OR (@MeasurementStart IS NOT NULL AND @MeasurementEnd IS NULL)
           OR @MeasurementStart>@MeasurementEnd
            THROW 53763,N'Das transiente Messfenster ist unvollständig oder rückläufig.',1;

        IF @EngineJson IS NOT NULL
        BEGIN
            INSERT @SourceEngine SELECT [key],[value],[type] FROM OPENJSON(@EngineJson);
            IF (SELECT COUNT_BIG(*) FROM @SourceEngine)<>3
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'serverName') AND [JsonType]=1 AND DATALENGTH([Value]) BETWEEN 2 AND 256)<>1
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'sqlServerStartTimeLocal') AND [JsonType]=1)<>1
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'sqlServerStartTimeMsTicks') AND [JsonType]=1)<>1
                THROW 53763,N'Der native Enginekontext ist unvollständig.',1;
            SELECT @EngineName=[Value] FROM @SourceEngine WHERE [Name]=N'serverName';
            IF EXISTS
               (SELECT 1 FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeLocal'
                AND (DATALENGTH([Value])<>46 OR TRY_CONVERT(datetime,[Value],126) IS NULL
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime,[Value],126))),3))))
               OR EXISTS
               (SELECT 1 FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeMsTicks'
                AND (TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
                THROW 53763,N'Die native Startidentität ist ungültig.',1;
            SELECT @EngineStartLocal=TRY_CONVERT(datetime,[Value],126) FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeLocal';
            SELECT @EngineTicks=TRY_CONVERT(bigint,[Value]) FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeMsTicks';
        END;

        INSERT @SourceRows SELECT TRY_CONVERT(bigint,[key]),[value],[type] FROM OPENJSON(@CollectorJson,N'$.waits');
        IF EXISTS(SELECT 1 FROM @SourceRows WHERE [JsonType]<>5)
            THROW 53763,N'Eine transiente Waitzeile ist kein Objekt.',1;
        INSERT @SourceRowFields
        SELECT [r].[Ordinal],[j].[key],[j].[value],[j].[type]
        FROM @SourceRows AS [r] CROSS APPLY OPENJSON([r].[Json]) AS [j];
        DECLARE @ExpectedWaitFields TABLE([Name] nvarchar(60),[JsonType] int);
        INSERT @ExpectedWaitFields VALUES(N'WaitType',1),(N'WaitingTasksCount',2),
                                          (N'WaitTimeMs',2),(N'MaxWaitTimeMs',2),(N'SignalWaitTimeMs',2);
        IF EXISTS
           (SELECT 1 FROM @SourceRows AS [r]
            WHERE (SELECT COUNT_BIG(*) FROM @SourceRowFields AS [f] WHERE [f].[Ordinal]=[r].[Ordinal])<>5
               OR EXISTS(SELECT 1 FROM @ExpectedWaitFields AS [e]
                         WHERE (SELECT COUNT_BIG(*) FROM @SourceRowFields AS [f]
                                WHERE [f].[Ordinal]=[r].[Ordinal] AND [f].[JsonType]=[e].[JsonType]
                                  AND CONVERT(varbinary(max),[f].[Name])=CONVERT(varbinary(max),[e].[Name]))<>1))
           OR EXISTS(SELECT 1 FROM @SourceRowFields WHERE [Name]=N'WaitType' AND DATALENGTH([Value]) NOT BETWEEN 2 AND 120)
           OR EXISTS
           (SELECT 1 FROM @SourceRowFields WHERE [JsonType]=2
            AND (TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
            THROW 53763,N'Der transiente Waitrow-Vertrag ist ungültig.',1;
        INSERT @Waits
        ([WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs],[ScopeIdentityJson],[ScopeKeyHash])
        SELECT [v].[WaitType],[v].[WaitingTasksCount],[v].[WaitTimeMs],[v].[MaxWaitTimeMs],[v].[SignalWaitTimeMs],
               [j].[IdentityJson],HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
        FROM @SourceRows AS [r]
        CROSS APPLY OPENJSON([r].[Json]) WITH
         ([WaitType] nvarchar(60) N'$.WaitType',[WaitingTasksCount] bigint N'$.WaitingTasksCount',
          [WaitTimeMs] bigint N'$.WaitTimeMs',[MaxWaitTimeMs] bigint N'$.MaxWaitTimeMs',
          [SignalWaitTimeMs] bigint N'$.SignalWaitTimeMs') AS [v]
        CROSS APPLY(SELECT [v].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson]);
        IF EXISTS(SELECT [ScopeKeyHash] FROM @Waits GROUP BY [ScopeKeyHash] HAVING COUNT_BIG(*)>1)
            THROW 53763,N'Der native Waitcache enthält doppelte Typen oder widersprüchliche Identitäten.',1;

        IF @SourceComplete=1
        BEGIN
            IF @SourceStatus NOT IN('AVAILABLE','EMPTY_UNPROVEN') OR @EngineName IS NULL
               OR @MeasurementStart IS NULL OR @MeasurementEnd IS NULL
               OR @MeasurementStart<@StartedAtUtc OR @MeasurementEnd>CONVERT(datetime2(3),SYSUTCDATETIME())
               OR @SourceError IS NOT NULL OR @SourceMessage IS NOT NULL
               OR EXISTS
               (SELECT 1 FROM @SourceMeta WHERE [Name]=N'nativeRows'
                AND ([JsonType]<>1 OR TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
                THROW 53763,N'Die behauptete vollständige Sourceaufnahme ist widersprüchlich.',1;
            SELECT @NativeRows=TRY_CONVERT(bigint,[Value]) FROM @SourceMeta WHERE [Name]=N'nativeRows';
            IF @NativeRows<>(SELECT COUNT_BIG(*) FROM @Waits)
               OR (@SourceStatus='AVAILABLE' AND (@NativeRows=0 OR @SourcePartial<>0))
               OR (@SourceStatus='EMPTY_UNPROVEN' AND (@NativeRows<>0 OR @SourcePartial<>1))
                THROW 53763,N'Sourcestatus und tatsächliche Waitmenge widersprechen sich.',1;
        END
        ELSE
        BEGIN
            IF @SourceStatus NOT IN('DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED')
               OR @SourcePartial<>1 OR EXISTS(SELECT 1 FROM @Waits)
               OR EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'nativeRows' AND [JsonType]<>0)
                THROW 53763,N'Der fehlgeschlagene Sourcevertrag behauptet eine vollständige Aufnahme.',1;
            SELECT @StatusCodeOut=@SourceStatus,@IsPartialOut=1,@ErrorNumberOut=@SourceError,
                   @ErrorMessageOut=@SourceMessage;
            GOTO FinalizeWithoutMetrics;
        END;

        DECLARE @Metrics TABLE
        ([Code] varchar(96) COLLATE DATABASE_DEFAULT,[ValueType] varchar(24) COLLATE DATABASE_DEFAULT,
         [Unit] varchar(40) COLLATE DATABASE_DEFAULT,[Id] bigint NULL);
        INSERT @Metrics ([Code],[ValueType],[Unit]) VALUES
          ('WAIT_TASK_COUNT','BIGINT','count'),('WAIT_TIME_MS','BIGINT','ms'),
          ('WAIT_SIGNAL_TIME_MS','BIGINT','ms'),('WAIT_MAX_TIME_MS','BIGINT','ms'),
          ('WAIT_TASK_COUNT_DELTA_CANDIDATE','BIGINT','count'),('WAIT_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('WAIT_DELTA_STATUS','STRING','status'),('WAIT_CAPTURE_CONTEXT','STRING','json');
        UPDATE [e] SET [Id]=[d].[MetricDefinitionId]
        FROM @Metrics AS [e] JOIN [snapshot].[MetricDefinition] AS [d] ON [d].[MetricCode]=[e].[Code]
        WHERE CONVERT(varbinary(max),[d].[MetricCode])=CONVERT(varbinary(max),[e].[Code])
          AND CONVERT(varbinary(max),[d].[ValueType])=CONVERT(varbinary(max),[e].[ValueType])
          AND CONVERT(varbinary(max),[d].[Unit])=CONVERT(varbinary(max),[e].[Unit])
          AND [d].[ContractVersion]=1;
        IF EXISTS(SELECT 1 FROM @Metrics WHERE [Id] IS NULL)
            THROW 53760,N'Der vollständige typisierte Waitmetrikvertrag fehlt.',1;
        DECLARE @ContextMetric bigint=(SELECT [Id] FROM @Metrics WHERE [Code]='WAIT_CAPTURE_CONTEXT'),
                @DeltaStatusMetric bigint=(SELECT [Id] FROM @Metrics WHERE [Code]='WAIT_DELTA_STATUS'),
                @ServerIdentity nvarchar(100)=N'{"scope":"SERVER"}',@ServerHash varbinary(32);
        SET @ServerHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ServerIdentity));
        IF EXISTS
           (SELECT 1 FROM [snapshot].[Scope] WHERE [ScopeType]='SERVER' AND [ScopeKeyHash]=@ServerHash
            AND ([ScopeId]<=0 OR CONVERT(varbinary(max),[ScopeType])<>CONVERT(varbinary(max),'SERVER')
                 OR [ParentScopeId] IS NOT NULL OR CONVERT(varbinary(max),[ScopeIdentityJson])<>CONVERT(varbinary(max),@ServerIdentity)))
            THROW 53766,N'Der vorhandene SERVER-Scope widerspricht seiner Identität.',1;
        SELECT @ServerScopeId=[ScopeId] FROM [snapshot].[Scope]
        WHERE [ScopeType]='SERVER' AND [ParentScopeId] IS NULL AND [ScopeKeyHash]=@ServerHash;

        DECLARE @PreviousStatus varchar(40),@PreviousError int,@PreviousEpoch uniqueidentifier,
                @PreviousStarted datetime2(3),@PreviousEnded datetime2(3),@PreviousSampleCount bigint,
                @PreviousContextEpoch uniqueidentifier,@PreviousMeasurementStart datetime2(3),
                @PreviousMeasurementEnd datetime2(3),@PreviousEngineName nvarchar(128),
                @PreviousEngineStart datetime,@PreviousEngineTicks bigint,
                @ContextValid bit=0,@RawValid bit=0,@PreviousTechnicalPartial bit=0,
                @EngineChanged bit=0,@CounterDecrease bit=0,@WaitTypeMissing bit=0,
                @IntervalInvalid bit=0,@PreviousWritten bigint,@PreviousActive bigint,
                @PreviousEligible bigint,@PreviousNative bigint,@PreviousRawCount bigint,
                @PreviousComparable bigint,@PreviousCandidateCount bigint,@PreviousLimited bit,
                @PreviousRawHash varchar(64),@PreviousContextStatus varchar(40),
                @PreviousContextDecision varchar(40),@PreviousContextParent bigint;
        SELECT TOP(1) @PreviousRunId=[CaptureRunId],@PreviousStatus=[StatusCode],@PreviousError=[ErrorNumber],
               @PreviousEpoch=[ResetEpochId],@PreviousStarted=[StartedAtUtc],@PreviousEnded=[EndedAtUtc],
               @PreviousSampleCount=[MetricSampleCount]
        FROM [snapshot].[CaptureRun]
        WHERE CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'WAIT_STATS')
          AND [EndedAtUtc] IS NOT NULL AND [CaptureRunId]<@CaptureRunId
        ORDER BY [CaptureRunId] DESC;
        IF @PreviousRunId IS NOT NULL AND (@PreviousStatus NOT IN('AVAILABLE','PARTIAL') OR @PreviousError IS NOT NULL)
            SET @PreviousTechnicalPartial=1;
        IF @PreviousRunId IS NOT NULL
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric) = 1
                SELECT @PreviousContext=[StringValue]
                FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric;
        END;

        DECLARE @ContextRoot TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
        DECLARE @ContextFields TABLE([Path] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
        DECLARE @ContextSpec TABLE([Path] nvarchar(128),[JsonType] int,[Nullable] bit,[Kind] varchar(24));
        INSERT @ContextSpec VALUES
          (N'schemaVersion',2,0,'ONE'),(N'collectorCode',1,0,'WAIT_STATS'),(N'metricContractVersion',2,0,'ONE'),
          (N'captureRunId',1,0,'POSITIVE_ID'),(N'serverScopeId',1,0,'POSITIVE_ID'),(N'resetEpochId',1,0,'GUID'),
          (N'engine.serverName',1,0,'ENGINE_NAME'),(N'engine.sqlServerStartTimeLocal',1,0,'LOCAL_MS'),
          (N'engine.sqlServerStartTimeMsTicks',1,0,'DECIMAL'),
          (N'window.measurementStartUtc',1,0,'UTC_MS'),(N'window.measurementEndUtc',1,0,'UTC_MS'),
          (N'capture.sourceComplete',3,0,'TRUE'),(N'capture.nativeWaitTypeCount',1,0,'DECIMAL'),
          (N'capture.activeTypeCount',1,0,'DECIMAL'),(N'capture.eligibleTypeCount',1,0,'DECIMAL'),
          (N'capture.writtenTypeCount',1,0,'DECIMAL'),(N'capture.writeLimited',3,0,'BOOLEAN'),
          (N'capture.rawMetricSampleCount',1,0,'DECIMAL'),(N'capture.rawProjectionSha256',1,0,'SHA256'),
          (N'comparison.previousCaptureRunId',1,1,'POSITIVE_ID'),(N'comparison.previousContextVersion',2,1,'POSITIVE_VERSION'),
          (N'comparison.status',1,0,'GLOBAL_STATUS'),(N'comparison.comparableTypeCount',1,0,'DECIMAL'),
          (N'comparison.candidateSampleCount',1,0,'DECIMAL'),(N'epochDecision',1,0,'EPOCH_DECISION');
        IF @PreviousContext IS NOT NULL AND DATALENGTH(@PreviousContext)<=8000 AND ISJSON(@PreviousContext)=1
        BEGIN
            INSERT @ContextRoot SELECT [key],[value],[type] FROM OPENJSON(@PreviousContext);
            IF (SELECT COUNT_BIG(*) FROM @ContextRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'schemaVersion'))=1
                SELECT @PreviousContextVersion=TRY_CONVERT(int,[Value])
                FROM @ContextRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'schemaVersion')
                  AND [JsonType]=2 AND TRY_CONVERT(int,[Value])>0
                  AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[Value])));
            INSERT @ContextFields
            SELECT [Name],[Value],[JsonType] FROM @ContextRoot WHERE [JsonType]<>5;
            INSERT @ContextFields
            SELECT CONCAT([r].[Name],N'.',[j].[key]),[j].[value],[j].[type]
            FROM @ContextRoot AS [r] CROSS APPLY OPENJSON([r].[Value]) AS [j] WHERE [r].[JsonType]=5;
            IF (SELECT COUNT_BIG(*) FROM @ContextRoot)=11
               AND (SELECT COUNT_BIG(*) FROM @ContextRoot WHERE [JsonType]=5)=4
               AND NOT EXISTS
               (SELECT 1 FROM (VALUES(N'engine'),(N'window'),(N'capture'),(N'comparison')) AS [e]([Name])
                WHERE (SELECT COUNT_BIG(*) FROM @ContextRoot AS [r]
                       WHERE CONVERT(varbinary(max),[r].[Name])=CONVERT(varbinary(max),[e].[Name]) AND [r].[JsonType]=5)<>1)
               AND (SELECT COUNT_BIG(*) FROM @ContextFields)=25
               AND NOT EXISTS
               (SELECT 1 FROM @ContextSpec AS [e]
                WHERE (SELECT COUNT_BIG(*) FROM @ContextFields AS [f]
                       WHERE CONVERT(varbinary(max),[f].[Path])=CONVERT(varbinary(max),[e].[Path])
                         AND ([f].[JsonType]=[e].[JsonType] OR ([e].[Nullable]=1 AND [f].[JsonType]=0)))<>1)
               AND NOT EXISTS
               (
                   SELECT 1 FROM @ContextFields AS [f] JOIN @ContextSpec AS [e]
                     ON CONVERT(varbinary(max),[f].[Path])=CONVERT(varbinary(max),[e].[Path])
                   WHERE [f].[JsonType]<>0 AND
                   (
                       ([e].[Kind]='ONE' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'1'))
                       OR ([e].[Kind]='WAIT_STATS' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'WAIT_STATS'))
                       OR ([e].[Kind] IN('DECIMAL','POSITIVE_ID') AND
                           (TRY_CONVERT(bigint,[f].[Value]) IS NULL OR TRY_CONVERT(bigint,[f].[Value])<CASE WHEN [e].[Kind]='POSITIVE_ID' THEN 1 ELSE 0 END
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[f].[Value])))))
                       OR ([e].[Kind]='POSITIVE_VERSION' AND
                           (TRY_CONVERT(int,[f].[Value]) IS NULL OR TRY_CONVERT(int,[f].[Value])<1
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[f].[Value])))))
                       OR ([e].[Kind]='ENGINE_NAME' AND DATALENGTH([f].[Value]) NOT BETWEEN 2 AND 256)
                       OR ([e].[Kind]='GUID' AND
                           (DATALENGTH([f].[Value])<>72 OR TRY_CONVERT(uniqueidentifier,[f].[Value]) IS NULL
                            OR TRY_CONVERT(uniqueidentifier,[f].[Value])='00000000-0000-0000-0000-000000000000'
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),LOWER(CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,[f].[Value]))))))
                       OR ([e].[Kind]='LOCAL_MS' AND
                           (DATALENGTH([f].[Value])<>46 OR TRY_CONVERT(datetime,[f].[Value],126) IS NULL
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[f].[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime,[f].[Value],126))),3))))
                       OR ([e].[Kind]='UTC_MS' AND
                           (DATALENGTH([f].[Value])<>48 OR RIGHT([f].[Value],1)<>N'Z'
                            OR TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126) IS NULL
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126))),3)+N'Z')))
                       OR ([e].[Kind]='TRUE' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'true'))
                       OR ([e].[Kind]='SHA256' AND
                           (DATALENGTH([f].[Value])<>128 OR [f].[Value] COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'))
                   )
               )
                SET @ContextValid=1;
        END;

        DECLARE @GlobalStatuses TABLE([Value] nvarchar(40));
        INSERT @GlobalStatuses VALUES(N'SOURCE_EMPTY_UNPROVEN'),(N'WRITE_LIMITED'),(N'FIRST_OBSERVATION'),
          (N'PREVIOUS_CAPTURE_PARTIAL'),(N'PREVIOUS_CONTEXT_INVALID'),(N'PREVIOUS_RAW_INCOMPLETE'),
          (N'ENGINE_CONTEXT_CHANGED'),(N'INTERVAL_NOT_POSITIVE'),(N'WAIT_TYPE_MISSING'),
          (N'COUNTER_DECREASE'),(N'NO_COMPARABLE_TYPES'),(N'MONOTONIC_CONTINUITY_UNPROVEN');
        IF @ContextValid=1
        BEGIN
            IF NOT EXISTS
               (SELECT 1 FROM @ContextFields AS [f] CROSS JOIN @GlobalStatuses AS [s]
                WHERE [f].[Path]=N'comparison.status'
                  AND CONVERT(varbinary(max),[f].[Value])=CONVERT(varbinary(max),[s].[Value]))
               OR NOT EXISTS
               (SELECT 1 FROM @ContextFields AS [f]
                CROSS JOIN (VALUES(N'NEW_FIRST'),(N'NEW_ENGINE_CONTEXT'),(N'NEW_COUNTER_DECREASE'),
                                  (N'NEW_COMPARISON_BREAK'),(N'RETAIN_CONTEXT')) AS [e]([Value])
                WHERE [f].[Path]=N'epochDecision'
                  AND CONVERT(varbinary(max),[f].[Value])=CONVERT(varbinary(max),[e].[Value]))
                SET @ContextValid=0;
        END;
        IF @ContextValid=1
        BEGIN
            SELECT @PreviousContextEpoch=TRY_CONVERT(uniqueidentifier,[Value]) FROM @ContextFields WHERE [Path]=N'resetEpochId';
            SELECT @PreviousMeasurementStart=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @ContextFields WHERE [Path]=N'window.measurementStartUtc';
            SELECT @PreviousMeasurementEnd=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @ContextFields WHERE [Path]=N'window.measurementEndUtc';
            SELECT @PreviousEngineName=[Value] FROM @ContextFields WHERE [Path]=N'engine.serverName';
            SELECT @PreviousEngineStart=TRY_CONVERT(datetime,[Value],126) FROM @ContextFields WHERE [Path]=N'engine.sqlServerStartTimeLocal';
            SELECT @PreviousEngineTicks=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'engine.sqlServerStartTimeMsTicks';
            SELECT @PreviousWritten=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.writtenTypeCount';
            SELECT @PreviousActive=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.activeTypeCount';
            SELECT @PreviousEligible=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.eligibleTypeCount';
            SELECT @PreviousNative=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.nativeWaitTypeCount';
            SELECT @PreviousRawCount=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.rawMetricSampleCount';
            SELECT @PreviousLimited=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @ContextFields WHERE [Path]=N'capture.writeLimited';
            SELECT @PreviousRawHash=CONVERT(varchar(64),[Value]) FROM @ContextFields WHERE [Path]=N'capture.rawProjectionSha256';
            SELECT @PreviousComparable=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.comparableTypeCount';
            SELECT @PreviousCandidateCount=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.candidateSampleCount';
            SELECT @PreviousContextStatus=CONVERT(varchar(40),[Value]) FROM @ContextFields WHERE [Path]=N'comparison.status';
            SELECT @PreviousContextDecision=CONVERT(varchar(40),[Value]) FROM @ContextFields WHERE [Path]=N'epochDecision';
            SELECT @PreviousContextParent=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.previousCaptureRunId';
            IF @ServerScopeId IS NULL OR @PreviousEpoch IS NULL OR @PreviousContextEpoch<>@PreviousEpoch
               OR EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'captureRunId' AND TRY_CONVERT(bigint,[Value])<>@PreviousRunId)
               OR EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'serverScopeId' AND TRY_CONVERT(bigint,[Value])<>@ServerScopeId)
               OR @PreviousStarted>@PreviousMeasurementStart OR @PreviousMeasurementStart>@PreviousMeasurementEnd
               OR @PreviousMeasurementEnd>@PreviousEnded
               OR (@PreviousContextParent IS NOT NULL AND @PreviousContextParent>=@PreviousRunId)
               OR (@PreviousContextParent IS NULL AND EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'comparison.previousContextVersion' AND [JsonType]<>0))
               OR (@PreviousContextParent IS NULL AND @PreviousContextDecision<>'NEW_FIRST')
               OR (@PreviousContextParent IS NOT NULL AND @PreviousContextDecision='NEW_FIRST')
               OR NOT EXISTS
               (SELECT 1 FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric
                  AND [ScopeId]=@ServerScopeId AND [ResetEpochId]=@PreviousEpoch
                  AND [CollectedAtUtc]=@PreviousMeasurementEnd
                  AND CONVERT(varbinary(max),[QualityCode])=CONVERT(varbinary(max),'CAPTURE_CONTEXT_V1')
                  AND [IsPartial]=0 AND [StringValue] IS NOT NULL)
                SET @ContextValid=0;
            -- Bound multiplicands before doing any arithmetic on stored counts.
            IF @PreviousWritten>100000 OR @PreviousComparable>100000 OR @PreviousCandidateCount>300000
               OR @PreviousRawCount>400000 OR @PreviousComparable>@PreviousWritten
               OR @PreviousWritten>@PreviousEligible OR @PreviousEligible>@PreviousNative
               OR @PreviousActive>@PreviousEligible
               OR (@PreviousEligible>0 AND @PreviousWritten=0)
                SET @ContextValid=0;
            IF @ContextValid=1 AND
               (@PreviousRawCount<>4*@PreviousWritten OR @PreviousCandidateCount<>3*@PreviousComparable
                OR @PreviousLimited<>CASE WHEN @PreviousWritten<@PreviousEligible THEN 1 ELSE 0 END
                OR @PreviousSampleCount<>5*@PreviousWritten+@PreviousCandidateCount+1
                OR (@PreviousNative=0 AND @PreviousContextStatus<>'SOURCE_EMPTY_UNPROVEN')
                OR (@PreviousNative>0 AND @PreviousContextStatus='SOURCE_EMPTY_UNPROVEN')
                OR (@PreviousLimited=1 AND @PreviousContextStatus<>'WRITE_LIMITED')
                OR (@PreviousLimited=0 AND @PreviousContextStatus='WRITE_LIMITED')
                OR (@PreviousContextStatus='MONOTONIC_CONTINUITY_UNPROVEN' AND @PreviousComparable=0)
                OR (@PreviousContextStatus<>'MONOTONIC_CONTINUITY_UNPROVEN' AND @PreviousComparable<>0)
                OR (@PreviousContextStatus='FIRST_OBSERVATION' AND @PreviousContextParent IS NOT NULL)
                OR (@PreviousContextParent IS NULL AND @PreviousContextStatus NOT IN('SOURCE_EMPTY_UNPROVEN','WRITE_LIMITED','FIRST_OBSERVATION'))
                OR (@PreviousContextDecision='RETAIN_CONTEXT' AND @PreviousContextStatus NOT IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN'))
                OR (@PreviousContextStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN') AND @PreviousContextDecision<>'RETAIN_CONTEXT')
                OR (@PreviousContextDecision IN('RETAIN_CONTEXT','NEW_ENGINE_CONTEXT','NEW_COUNTER_DECREASE')
                    AND NOT EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'comparison.previousContextVersion'
                                   AND [JsonType]=2 AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'1')))
                OR (@PreviousNative=0 AND @PreviousContextDecision='NEW_COUNTER_DECREASE')
                OR (@PreviousContextStatus='ENGINE_CONTEXT_CHANGED' AND @PreviousContextDecision<>'NEW_ENGINE_CONTEXT')
                OR (@PreviousContextStatus='COUNTER_DECREASE' AND @PreviousContextDecision<>'NEW_COUNTER_DECREASE'))
                SET @ContextValid=0;
        END;

        DECLARE @PreviousRows TABLE
        (
            [ScopeId] bigint,[WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2,
            [IdentityJson] nvarchar(max),[ScopeKeyHash] binary(32),
            [WaitingTasksCount] bigint,[WaitTimeMs] bigint,[MaxWaitTimeMs] bigint,[SignalWaitTimeMs] bigint,
            [DeltaStatus] nvarchar(4000),[RawCount] bigint,[StatusCount] bigint,[CandidateCount] bigint
        );
        IF @ContextValid=1
        BEGIN
            SET @RawValid=1;
            IF @PreviousLimited=1 OR @PreviousNative=0 SET @PreviousTechnicalPartial=1;
            IF CONVERT(varbinary(max),@EngineName)<>CONVERT(varbinary(max),@PreviousEngineName)
               OR @EngineStartLocal<>@PreviousEngineStart OR @EngineTicks<>@PreviousEngineTicks
                SET @EngineChanged=1;
            IF @MeasurementStart<@PreviousMeasurementEnd OR @MeasurementEnd<=@PreviousMeasurementEnd
                SET @IntervalInvalid=1;
            IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@PreviousRunId)<>@PreviousSampleCount
               OR EXISTS
               (
                   SELECT 1 FROM [snapshot].[MetricSample] AS [s]
                   LEFT JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
                   LEFT JOIN [snapshot].[Scope] AS [p] ON [p].[ScopeId]=[s].[ScopeId]
                   WHERE [s].[CaptureRunId]=@PreviousRunId AND
                   ([m].[Id] IS NULL OR [s].[ResetEpochId] IS NULL OR [s].[ResetEpochId]<>@PreviousEpoch
                    OR [s].[CollectedAtUtc]<>@PreviousMeasurementEnd
                    OR ([s].[MetricDefinitionId]<>@ContextMetric AND
                        ([p].[ScopeType]<>'WAIT_TYPE' OR [p].[ParentScopeId]<>@ServerScopeId OR [p].[ParentScopeId] IS NULL))
                    OR ([m].[ValueType]='BIGINT' AND ([s].[BigintValue] IS NULL OR [s].[BigintValue]<0))
                    OR ([m].[ValueType]='STRING' AND [s].[StringValue] IS NULL)
                    OR ([m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS')
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'MEASURED_CUMULATIVE') OR [s].[IsPartial]<>0))
                    OR ([m].[Code] LIKE '%_DELTA_CANDIDATE'
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'MONOTONIC_CONTINUITY_UNPROVEN') OR [s].[IsPartial]<>1))
                    OR ([m].[Code]='WAIT_DELTA_STATUS'
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'COMPARISON_STATUS') OR [s].[IsPartial]<>1)))
               )
                SET @RawValid=0;
            INSERT @PreviousRows
            SELECT [p].[ScopeId],
                   CASE WHEN DATALENGTH(JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType')) BETWEEN 2 AND 120
                        THEN CONVERT(nvarchar(60),JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType')) END,
                   [p].[ScopeIdentityJson],[p].[ScopeKeyHash],
                   MAX(CASE WHEN [m].[Code]='WAIT_TASK_COUNT' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_MAX_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_SIGNAL_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_DELTA_STATUS' THEN [s].[StringValue] END),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS') THEN 1 ELSE 0 END)),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code]='WAIT_DELTA_STATUS' THEN 1 ELSE 0 END)),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code] LIKE '%_DELTA_CANDIDATE' THEN 1 ELSE 0 END))
            FROM [snapshot].[MetricSample] AS [s]
            JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
            JOIN [snapshot].[Scope] AS [p] ON [p].[ScopeId]=[s].[ScopeId]
            WHERE [s].[CaptureRunId]=@PreviousRunId AND [s].[MetricDefinitionId]<>@ContextMetric
            GROUP BY [p].[ScopeId],[p].[ScopeIdentityJson],[p].[ScopeKeyHash];
            IF (SELECT COUNT_BIG(*) FROM @PreviousRows)<>@PreviousWritten
               OR EXISTS
               (
                   SELECT 1 FROM @PreviousRows AS [p]
                   CROSS APPLY(SELECT [p].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson])
                   WHERE [p].[WaitType] IS NULL OR [p].[RawCount]<>4 OR [p].[StatusCount]<>1
                      OR [p].[WaitingTasksCount] IS NULL OR [p].[WaitTimeMs] IS NULL
                      OR [p].[MaxWaitTimeMs] IS NULL OR [p].[SignalWaitTimeMs] IS NULL
                      OR [p].[DeltaStatus] IS NULL
                      OR CONVERT(varbinary(max),[p].[IdentityJson])<>CONVERT(varbinary(max),[j].[IdentityJson])
                      OR [p].[ScopeKeyHash]<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
                      OR ([p].[CandidateCount]<>0 AND [p].[CandidateCount]<>3)
                      OR NOT EXISTS(SELECT 1 FROM @GlobalStatuses AS [v]
                                    WHERE CONVERT(varbinary(max),[v].[Value])=CONVERT(varbinary(max),[p].[DeltaStatus]))
                      OR ([p].[CandidateCount]=3 AND CONVERT(varbinary(max),[p].[DeltaStatus])<>CONVERT(varbinary(max),N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR ([p].[CandidateCount]=0 AND CONVERT(varbinary(max),[p].[DeltaStatus])=CONVERT(varbinary(max),N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR (@PreviousContextStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                          AND [p].[DeltaStatus] NOT IN(N'FIRST_OBSERVATION',N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR (@PreviousContextStatus NOT IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                          AND CONVERT(varbinary(max),[p].[DeltaStatus])<>CONVERT(varbinary(max),CONVERT(nvarchar(40),@PreviousContextStatus)))
               )
               OR (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [CandidateCount]=3)<>@PreviousComparable
               OR (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0)>@PreviousActive
               OR (@PreviousLimited=0 AND (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0)<>@PreviousActive)
                SET @RawValid=0;
            DECLARE @PreviousRawJson nvarchar(max)=
             (SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
              FROM @PreviousRows ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @PreviousRawJson=COALESCE(@PreviousRawJson,N'[]');
            IF CONVERT(varbinary(max),LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PreviousRawJson)),2)))
                <>CONVERT(varbinary(max),@PreviousRawHash)
                SET @RawValid=0;
        END;

        IF @ContextValid=1 AND (@PreviousStatus NOT IN('AVAILABLE','PARTIAL') OR @PreviousError IS NOT NULL)
        BEGIN
            SET @ContextValid=0;
            SET @RawValid=0;
            SET @EngineChanged=0;
        END;
        IF @ContextValid=1 AND @RawValid=1
        BEGIN
            IF EXISTS(SELECT 1 FROM @PreviousRows AS [p]
                      WHERE NOT EXISTS(SELECT 1 FROM @Waits AS [c] WHERE [c].[ScopeKeyHash]=[p].[ScopeKeyHash]))
                SET @WaitTypeMissing=1;
            IF @EngineChanged=0 AND EXISTS
               (SELECT 1 FROM @PreviousRows AS [p] JOIN @Waits AS [c] ON [c].[ScopeKeyHash]=[p].[ScopeKeyHash]
                WHERE [c].[WaitingTasksCount]<[p].[WaitingTasksCount] OR [c].[WaitTimeMs]<[p].[WaitTimeMs]
                   OR [c].[MaxWaitTimeMs]<[p].[MaxWaitTimeMs] OR [c].[SignalWaitTimeMs]<[p].[SignalWaitTimeMs])
                SET @CounterDecrease=1;
        END;

        -- Hints preserve actually observed current zeros even when the old context
        -- or some old samples are missing. Hints never qualify numeric candidates.
        DECLARE @PreviousTypeHints TABLE([ScopeKeyHash] binary(32) PRIMARY KEY);
        IF @PreviousRunId IS NOT NULL AND @ServerScopeId IS NOT NULL
            INSERT @PreviousTypeHints
            SELECT DISTINCT [p].[ScopeKeyHash]
            FROM [snapshot].[Scope] AS [p]
            CROSS APPLY(SELECT JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType') AS [WaitType]) AS [n]
            CROSS APPLY(SELECT [n].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson])
            WHERE CONVERT(varbinary(max),[p].[ScopeType])=CONVERT(varbinary(max),'WAIT_TYPE')
              AND [p].[ParentScopeId]=@ServerScopeId AND DATALENGTH([n].[WaitType]) BETWEEN 2 AND 120
              AND CONVERT(varbinary(max),[p].[ScopeIdentityJson])=CONVERT(varbinary(max),[j].[IdentityJson])
              AND [p].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
              AND EXISTS(SELECT 1 FROM [snapshot].[MetricSample] AS [s] JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
                         WHERE [s].[CaptureRunId]=@PreviousRunId AND [s].[ScopeId]=[p].[ScopeId]
                           AND [s].[MetricDefinitionId]<>@ContextMetric);
        SELECT @ActiveTypes=COUNT_BIG(*) FROM @Waits
        WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0;
        UPDATE [c] SET [IsEligible]=1 FROM @Waits AS [c]
        WHERE [c].[WaitingTasksCount]>0 OR [c].[WaitTimeMs]>0 OR [c].[MaxWaitTimeMs]>0 OR [c].[SignalWaitTimeMs]>0
           OR EXISTS(SELECT 1 FROM @PreviousTypeHints AS [p] WHERE [p].[ScopeKeyHash]=[c].[ScopeKeyHash]);
        SELECT @EligibleTypes=COUNT_BIG(*) FROM @Waits WHERE [IsEligible]=1;
        ;WITH [Chosen] AS
        (
            SELECT [ScopeKeyHash],ROW_NUMBER() OVER
             (ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash]) AS [Ordinal]
            FROM @Waits WHERE [IsEligible]=1
        )
        UPDATE [c] SET [IsSelected]=1 FROM @Waits AS [c]
        JOIN [Chosen] AS [s] ON [s].[ScopeKeyHash]=[c].[ScopeKeyHash] WHERE [s].[Ordinal]<=@MaxRows;
        SELECT @WrittenTypes=COUNT_BIG(*) FROM @Waits WHERE [IsSelected]=1;
        SET @WriteLimited=CASE WHEN @WrittenTypes<@EligibleTypes THEN 1 ELSE 0 END;

        IF @NativeRows=0 SET @ComparisonStatus='SOURCE_EMPTY_UNPROVEN';
        ELSE IF @WriteLimited=1 SET @ComparisonStatus='WRITE_LIMITED';
        ELSE IF @PreviousRunId IS NULL SET @ComparisonStatus='FIRST_OBSERVATION';
        ELSE IF @PreviousTechnicalPartial=1 SET @ComparisonStatus='PREVIOUS_CAPTURE_PARTIAL';
        ELSE IF @ContextValid=0 SET @ComparisonStatus='PREVIOUS_CONTEXT_INVALID';
        ELSE IF @RawValid=0 SET @ComparisonStatus='PREVIOUS_RAW_INCOMPLETE';
        ELSE IF @EngineChanged=1 SET @ComparisonStatus='ENGINE_CONTEXT_CHANGED';
        ELSE IF @IntervalInvalid=1 SET @ComparisonStatus='INTERVAL_NOT_POSITIVE';
        ELSE IF @WaitTypeMissing=1 SET @ComparisonStatus='WAIT_TYPE_MISSING';
        ELSE IF @CounterDecrease=1 SET @ComparisonStatus='COUNTER_DECREASE';
        ELSE
        BEGIN
            UPDATE [c] SET [IsComparable]=1 FROM @Waits AS [c]
            WHERE [c].[IsSelected]=1 AND EXISTS(SELECT 1 FROM @PreviousRows AS [p] WHERE [p].[ScopeKeyHash]=[c].[ScopeKeyHash]);
            SELECT @ComparableTypes=COUNT_BIG(*) FROM @Waits WHERE [IsComparable]=1;
            SET @ComparisonStatus=CASE WHEN @ComparableTypes=0 THEN 'NO_COMPARABLE_TYPES' ELSE 'MONOTONIC_CONTINUITY_UNPROVEN' END;
        END;
        SET @CandidateSamples=3*@ComparableTypes;
        IF @PreviousRunId IS NULL SET @EpochDecision='NEW_FIRST';
        ELSE IF @ContextValid=1 AND @EngineChanged=1 SET @EpochDecision='NEW_ENGINE_CONTEXT';
        ELSE IF @ContextValid=1 AND @RawValid=1 AND @CounterDecrease=1 SET @EpochDecision='NEW_COUNTER_DECREASE';
        ELSE IF @ComparisonStatus IN('SOURCE_EMPTY_UNPROVEN','WRITE_LIMITED','PREVIOUS_CAPTURE_PARTIAL',
                 'PREVIOUS_CONTEXT_INVALID','PREVIOUS_RAW_INCOMPLETE','INTERVAL_NOT_POSITIVE','WAIT_TYPE_MISSING')
            SET @EpochDecision='NEW_COMPARISON_BREAK';
        ELSE SET @EpochDecision='RETAIN_CONTEXT';
        SET @Epoch=CASE WHEN @EpochDecision='RETAIN_CONTEXT' THEN @PreviousEpoch ELSE NEWID() END;
        IF @Epoch IS NULL OR @Epoch='00000000-0000-0000-0000-000000000000'
           OR (@EpochDecision<>'RETAIN_CONTEXT' AND @PreviousEpoch IS NOT NULL AND @Epoch=@PreviousEpoch)
            THROW 53766,N'Eine neue Vergleichsepoche konnte nicht eindeutig gebildet werden.',1;
        UPDATE @Waits SET [DeltaStatus]=CASE WHEN @ComparisonStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                       THEN CASE WHEN [IsComparable]=1 THEN 'MONOTONIC_CONTINUITY_UNPROVEN' ELSE 'FIRST_OBSERVATION' END
                       ELSE @ComparisonStatus END WHERE [IsSelected]=1;

        IF @ServerScopeId IS NULL
        BEGIN
            INSERT [snapshot].[Scope] ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
            VALUES('SERVER',NULL,@ServerHash,@ServerIdentity,SYSUTCDATETIME());
            SET @ServerScopeId=CONVERT(bigint,SCOPE_IDENTITY());
        END;
        IF @ServerScopeId<=0 THROW 53766,N'Der SERVER-Scope benötigt eine positive Kennung.',1;
        IF EXISTS
           (SELECT 1 FROM @Waits AS [c] JOIN [snapshot].[Scope] AS [s]
             ON [s].[ScopeType]='WAIT_TYPE' AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[IsSelected]=1 AND ([s].[ScopeId]<=0
              OR CONVERT(varbinary(max),[s].[ScopeType])<>CONVERT(varbinary(max),'WAIT_TYPE')
              OR CONVERT(varbinary(max),[s].[ScopeIdentityJson])<>CONVERT(varbinary(max),[c].[ScopeIdentityJson])))
            THROW 53766,N'Ein vorhandener Wait-Scope widerspricht seiner Identität.',1;
        INSERT [snapshot].[Scope] ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
        SELECT 'WAIT_TYPE',@ServerScopeId,[c].[ScopeKeyHash],[c].[ScopeIdentityJson],SYSUTCDATETIME()
        FROM @Waits AS [c] WHERE [c].[IsSelected]=1 AND NOT EXISTS
         (SELECT 1 FROM [snapshot].[Scope] AS [s]
          WHERE [s].[ScopeType]='WAIT_TYPE' AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]);
        UPDATE [c] SET [ScopeId]=[s].[ScopeId] FROM @Waits AS [c]
        JOIN [snapshot].[Scope] AS [s] ON [s].[ScopeType]='WAIT_TYPE'
          AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
        WHERE [c].[IsSelected]=1;

        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[c].[ScopeId],[m].[Id],@MeasurementEnd,@Epoch,[v].[Value],'MEASURED_CUMULATIVE',0
        FROM @Waits AS [c]
        CROSS APPLY(VALUES('WAIT_TASK_COUNT',[c].[WaitingTasksCount]),('WAIT_TIME_MS',[c].[WaitTimeMs]),
                          ('WAIT_MAX_TIME_MS',[c].[MaxWaitTimeMs]),('WAIT_SIGNAL_TIME_MS',[c].[SignalWaitTimeMs])) AS [v]([Code],[Value])
        JOIN @Metrics AS [m] ON [m].[Code]=[v].[Code] WHERE [c].[IsSelected]=1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[c].[ScopeId],[m].[Id],@MeasurementEnd,@Epoch,[v].[Value],'MONOTONIC_CONTINUITY_UNPROVEN',1
        FROM @Waits AS [c] JOIN @PreviousRows AS [p] ON [p].[ScopeKeyHash]=[c].[ScopeKeyHash]
        CROSS APPLY(VALUES('WAIT_TASK_COUNT_DELTA_CANDIDATE',[c].[WaitingTasksCount]-[p].[WaitingTasksCount]),
                          ('WAIT_TIME_MS_DELTA_CANDIDATE',[c].[WaitTimeMs]-[p].[WaitTimeMs]),
                          ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE',[c].[SignalWaitTimeMs]-[p].[SignalWaitTimeMs])) AS [v]([Code],[Value])
        JOIN @Metrics AS [m] ON [m].[Code]=[v].[Code] WHERE [c].[IsComparable]=1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[ScopeId],@DeltaStatusMetric,@MeasurementEnd,@Epoch,[DeltaStatus],'COMPARISON_STATUS',1
        FROM @Waits WHERE [IsSelected]=1;

        DECLARE @StoredRaw TABLE
        ([ScopeId] bigint,[WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2,[ScopeKeyHash] binary(32),
         [WaitingTasksCount] bigint,[WaitTimeMs] bigint,[MaxWaitTimeMs] bigint,[SignalWaitTimeMs] bigint,[RawCount] bigint);
        INSERT @StoredRaw
        SELECT [c].[ScopeId],[c].[WaitType],[c].[ScopeKeyHash],
               MAX(CASE WHEN [m].[Code]='WAIT_TASK_COUNT' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_TIME_MS' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_MAX_TIME_MS' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_SIGNAL_TIME_MS' THEN [s].[BigintValue] END),COUNT_BIG(*)
        FROM @Waits AS [c] JOIN [snapshot].[MetricSample] AS [s] ON [s].[ScopeId]=[c].[ScopeId] AND [s].[CaptureRunId]=@CaptureRunId
        JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
        WHERE [c].[IsSelected]=1 AND [m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS')
        GROUP BY [c].[ScopeId],[c].[WaitType],[c].[ScopeKeyHash];
        IF (SELECT COUNT_BIG(*) FROM @StoredRaw)<>@WrittenTypes
           OR EXISTS(SELECT 1 FROM @StoredRaw AS [s] JOIN @Waits AS [c] ON [c].[ScopeId]=[s].[ScopeId]
                     WHERE [s].[RawCount]<>4 OR [s].[WaitingTasksCount]<>[c].[WaitingTasksCount]
                        OR [s].[WaitTimeMs]<>[c].[WaitTimeMs] OR [s].[MaxWaitTimeMs]<>[c].[MaxWaitTimeMs]
                        OR [s].[SignalWaitTimeMs]<>[c].[SignalWaitTimeMs])
            THROW 53766,N'Die tatsächliche Rohprojektion weicht von der ausgewählten Aufnahme ab.',1;
        SELECT @RawJson=(SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
                         FROM @StoredRaw ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash]
                         FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @RawJson=COALESCE(@RawJson,N'[]');
        SET @RawHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@RawJson));

        SELECT @ContextJson=
        (
            SELECT 1 AS [schemaVersion],'WAIT_STATS' AS [collectorCode],1 AS [metricContractVersion],
                   CONVERT(varchar(20),@CaptureRunId) AS [captureRunId],
                   CONVERT(varchar(20),@ServerScopeId) AS [serverScopeId],
                   LOWER(CONVERT(varchar(36),@Epoch)) AS [resetEpochId],
                   JSON_QUERY((SELECT @EngineName AS [serverName],
                     CONVERT(nvarchar(19),@EngineStartLocal,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EngineStartLocal)),3) AS [sqlServerStartTimeLocal],
                     CONVERT(varchar(20),@EngineTicks) AS [sqlServerStartTimeMsTicks]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [engine],
                   JSON_QUERY((SELECT
                     CONVERT(nvarchar(19),@MeasurementStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@MeasurementStart)),3)+N'Z' AS [measurementStartUtc],
                     CONVERT(nvarchar(19),@MeasurementEnd,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@MeasurementEnd)),3)+N'Z' AS [measurementEndUtc]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [window],
                   JSON_QUERY((SELECT CONVERT(bit,1) AS [sourceComplete],
                     CONVERT(varchar(20),@NativeRows) AS [nativeWaitTypeCount],
                     CONVERT(varchar(20),@ActiveTypes) AS [activeTypeCount],
                     CONVERT(varchar(20),@EligibleTypes) AS [eligibleTypeCount],
                     CONVERT(varchar(20),@WrittenTypes) AS [writtenTypeCount],@WriteLimited AS [writeLimited],
                     CONVERT(varchar(20),4*@WrittenTypes) AS [rawMetricSampleCount],
                     LOWER(CONVERT(varchar(64),@RawHash,2)) AS [rawProjectionSha256]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [capture],
                   JSON_QUERY((SELECT CONVERT(varchar(20),@PreviousRunId) AS [previousCaptureRunId],
                     @PreviousContextVersion AS [previousContextVersion],@ComparisonStatus AS [status],
                     CONVERT(varchar(20),@ComparableTypes) AS [comparableTypeCount],
                     CONVERT(varchar(20),@CandidateSamples) AS [candidateSampleCount]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [comparison],
                   @EpochDecision AS [epochDecision]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        IF DATALENGTH(@ContextJson)>8000 OR COALESCE(ISJSON(@ContextJson),0)<>1
            THROW 53766,N'Der Aufnahme-/Vergleichskontext überschreitet seinen Stringvertrag.',1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        VALUES(@CaptureRunId,@ServerScopeId,@ContextMetric,@MeasurementEnd,@Epoch,@ContextJson,'CAPTURE_CONTEXT_V1',0);
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
              <>5*@WrittenTypes+@CandidateSamples+1
           OR 5*@WrittenTypes+@CandidateSamples+1>8*CONVERT(bigint,@MaxRows)+1
            THROW 53766,N'Die tatsächlich gespeicherte Waitmenge widerspricht dem Mengenvertrag.',1;
        IF @PayloadEnabled=1
            INSERT [snapshot].[PayloadSnapshot]
            ([CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat],[PayloadContractVersion],
             [CompressionType],[PayloadHash],[Payload],[UncompressedCharacterCount])
            VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',@MeasurementEnd,'JSON',1,'GZIP',
                   HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',@MeasurementEnd,@SourceStatus,@SourcePartial,NULL,NULL,
               N'Ein vollständiger nativer Cache mit Enginekontext vor und nach dem Read; keine behauptete atomare DMV-Sicht.'),
              (@CaptureRunId,N'snapshot.InternalCompleteWaitStatsCycle',@MeasurementEnd,'PARTIAL',1,NULL,
               CONVERT(nvarchar(40),@ComparisonStatus),N'Monotone Differenzkandidaten beweisen keine ununterbrochene Resetkontinuität.');
        DECLARE @FinishedAt datetime2(3)=SYSUTCDATETIME();
        IF @FinishedAt<@MeasurementEnd OR @FinishedAt<@StartedAtUtc
            THROW 53766,N'Die tatsächliche Finalisierungszeit liegt vor der Aufnahme.',1;
        UPDATE [snapshot].[CaptureRun]
        SET [EndedAtUtc]=@FinishedAt,[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=@Epoch,
            [StatusCode]='PARTIAL',[IsPartial]=1,[ErrorNumber]=NULL,[ErrorMessage]=CONVERT(nvarchar(40),@ComparisonStatus),
            [MetricSampleCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId),
            [PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
        WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
        IF @@ROWCOUNT<>1 THROW 53766,N'Der eigene Wait-Run konnte nicht finalisiert werden.',1;
        COMMIT TRANSACTION;
        SELECT @StatusCodeOut='PARTIAL',@IsPartialOut=1,@ErrorNumberOut=NULL,
               @ErrorMessageOut=CONVERT(nvarchar(40),@ComparisonStatus);
        RETURN;

FinalizeWithoutMetrics:
        IF @PayloadEnabled=1
            INSERT [snapshot].[PayloadSnapshot]
            ([CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat],[PayloadContractVersion],
             [CompressionType],[PayloadHash],[Payload],[UncompressedCharacterCount])
            VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',SYSUTCDATETIME(),'JSON',1,'GZIP',
                   HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',SYSUTCDATETIME(),@StatusCodeOut,1,@ErrorNumberOut,@ErrorMessageOut,
               N'Kein vollständiger Counterread; keine Rohsamples, kein Kontextsample und keine erfundene Epoche.');
        UPDATE [snapshot].[CaptureRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=NULL,
            [StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,
            [MetricSampleCount]=0,[PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
        WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
        IF @@ROWCOUNT<>1 THROW 53766,N'Der fehlgeschlagene eigene Wait-Run konnte nicht finalisiert werden.',1;
        COMMIT TRANSACTION;
        RETURN;
    END TRY
    BEGIN CATCH
        DECLARE @Failure int=ERROR_NUMBER(),@FailureMessage nvarchar(2048)=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN @Failure IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                  WHEN @Failure IN(53761,53762,53764,2812,8144,8145) THEN 'TARGET_UNAVAILABLE'
                                  WHEN @OwnRun=0 AND @Failure=53763 THEN 'INVALID_PARAMETER'
                                  ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=CASE WHEN @OwnRun=0 AND @Failure=53763 THEN 51011 ELSE @Failure END,
               @ErrorMessageOut=@FailureMessage;
        IF @OwnRun=1 AND DB_ID()=@ExpectedTargetDatabaseId
           AND EXISTS(SELECT 1 FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                      WHERE [d].[database_id]=@ExpectedTargetDatabaseId AND [d].[create_date]=@ExpectedTargetCreateDate
                        AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
                        AND [d].[state]=0 AND [d].[is_read_only]=0)
        BEGIN TRY
            BEGIN TRANSACTION;
            IF EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)
                      WHERE [CaptureRunId]=@CaptureRunId AND [CollectorCode]='WAIT_STATS'
                        AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING')
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
            BEGIN
                INSERT [snapshot].[ModuleStatus]
                ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                VALUES(@CaptureRunId,N'snapshot.InternalCompleteWaitStatsCycle',SYSUTCDATETIME(),@StatusCodeOut,1,
                       @ErrorNumberOut,@ErrorMessageOut,N'Die eigene Aufnahme wurde zurückgerollt; keine erfolgreiche Finalisierung wird behauptet.');
                UPDATE [snapshot].[CaptureRun]
                SET [EndedAtUtc]=SYSUTCDATETIME(),[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=NULL,
                    [StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,
                    [MetricSampleCount]=0,[PayloadCount]=0
                WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
            END;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SET @ErrorMessageOut=LEFT(CONCAT(@FailureMessage,N' Fehlerfinalisierung nicht bestätigt: ',ERROR_MESSAGE()),2048);
        END CATCH;
        IF @OwnRun=0 AND @Failure=53763 RETURN 51011;
    END CATCH;
END;
GO
"""),
'070_InternalPurgeExpiredData.sql': ('d2603c04e4885a6ec84888c2abc7811bb4d42f048e9eea23dab6cfb65171f396', r"""/*
===============================================================================
Objekt       : snapshot.InternalPurgeExpiredData
Version      : 1.1.0
Stand        : 2026-10-25
Zweck        : Löscht ausschließlich abgelaufene Snapshotdaten child-first in
               begrenzten Batches; nicht abgelaufene Daten bleiben erhalten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalPurgeExpiredData]
      @MaxBatches        int
    , @Force             bit
    , @PurgeRunIdOut     bigint OUTPUT
    , @StatusCodeOut     varchar(40) OUTPUT
    , @BudgetExceededOut bit OUTPUT
    , @ErrorNumberOut    int OUTPUT
    , @ErrorMessageOut   nvarchar(2048) OUTPUT
    , @ContractOnly      bit = 0
    , @RetentionContractVersionOut int = NULL OUTPUT
    , @ExpectedTargetDatabaseId int = NULL
    , @ExpectedTargetDatabaseName sysname = NULL
    , @ExpectedTargetCreateDate datetime = NULL
AS
BEGIN
    SELECT @PurgeRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@BudgetExceededOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL,@RetentionContractVersionOut=1;

    IF @ContractOnly IS NULL
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'@ContractOnly darf nicht NULL sein.';
        RETURN 51011;
    END;

    IF (@ContractOnly=1 OR @ExpectedTargetDatabaseId IS NOT NULL OR @ExpectedTargetDatabaseName IS NOT NULL OR @ExpectedTargetCreateDate IS NOT NULL) AND (@@OPTIONS & 2)<>0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der neue Wait-Vertrag benötigt IMPLICIT_TRANSACTIONS OFF.';
        RETURN 51011;
    END;

    IF @ExpectedTargetDatabaseId IS NOT NULL OR @ExpectedTargetDatabaseName IS NOT NULL
       OR @ExpectedTargetCreateDate IS NOT NULL
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

    -- The installation/runtime handshake does not read or change package data.
    IF @ContractOnly=1 RETURN;

    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 0;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),
            @RawRetentionDays smallint,
            @PayloadRetentionDays smallint,
            @PurgeIntervalMinutes smallint,
            @BatchRows int,
            @SoftBudgetMB bigint,
            @UsedBefore decimal(19,3),
            @UsedAfter decimal(19,3),
            @LastPurgeUtc datetime2(3),
            @Batch int=0,
            @Deleted int,
            @Rows int,
            @MetricDeleted bigint=0,
            @PayloadDeleted bigint=0,
            @ModuleDeleted bigint=0,
            @RunsDeleted bigint=0,
            @ScopeDeleted bigint=0;

    SELECT @PurgeRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@BudgetExceededOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @MaxBatches NOT BETWEEN 1 AND 1000
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@ErrorMessageOut=N'@MaxBatches muss zwischen 1 und 1000 liegen.';
        RETURN;
    END;

    SELECT @RawRetentionDays=[RawRetentionDays],
           @PayloadRetentionDays=[PayloadRetentionDays],
           @PurgeIntervalMinutes=[PurgeIntervalMinutes],
           @BatchRows=[PurgeBatchRows],
           @SoftBudgetMB=[SoftBudgetMB]
    FROM [snapshot].[RetentionPolicy]
    WHERE [RetentionPolicyCode]='DEFAULT';

    SELECT TOP (1) @LastPurgeUtc=[EndedAtUtc]
    FROM [snapshot].[PurgeRun]
    WHERE [StatusCode] IN ('AVAILABLE','AVAILABLE_LIMITED')
      AND [EndedAtUtc] IS NOT NULL
    ORDER BY [PurgeRunId] DESC;

    SELECT @UsedBefore=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
    FROM [sys].[database_files] WITH (NOLOCK)
    WHERE [type]=0;

    IF @Force=0
       AND @UsedBefore<=@SoftBudgetMB
       AND @LastPurgeUtc IS NOT NULL
       AND DATEADD(MINUTE,@PurgeIntervalMinutes,@LastPurgeUtc)>@Now
    BEGIN
        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',@BudgetExceededOut=0;
        RETURN;
    END;

    INSERT [snapshot].[PurgeRun]
    ([StartedAtUtc],[StatusCode],[UsedDataMbBefore],[SoftBudgetMb])
    VALUES (@Now,'RUNNING',@UsedBefore,@SoftBudgetMB);
    SET @PurgeRunIdOut=CONVERT(bigint,SCOPE_IDENTITY());

    BEGIN TRY
        WHILE @Batch<@MaxBatches
        BEGIN
            SET @Deleted=0;
            BEGIN TRANSACTION;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[MetricSample] AS [m]
            WHERE [m].[CollectedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @MetricDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [p]
            FROM [snapshot].[PayloadSnapshot] AS [p]
            WHERE [p].[CapturedAtUtc]<DATEADD(DAY,-@PayloadRetentionDays,@Now);
            SET @Rows=@@ROWCOUNT;
            SET @PayloadDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [m]
            FROM [snapshot].[ModuleStatus] AS [m]
            JOIN [snapshot].[CaptureRun] AS [r]
              ON [r].[CaptureRunId]=[m].[CaptureRunId]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [x] WHERE [x].[CaptureRunId]=[r].[CaptureRunId]);
            SET @Rows=@@ROWCOUNT;
            SET @ModuleDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [r]
            FROM [snapshot].[CaptureRun] AS [r]
            WHERE [r].[StartedAtUtc]<DATEADD(DAY,-@RawRetentionDays,@Now)
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[PayloadSnapshot] AS [p] WHERE [p].[CaptureRunId]=[r].[CaptureRunId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[ModuleStatus] AS [s] WHERE [s].[CaptureRunId]=[r].[CaptureRunId])
              -- Preserve the latest finalized Wait run as the comparison fence,
              -- including a failed run whose children have expired or never existed.
              AND
              (
                  [r].[CollectorCode]<>'WAIT_STATS'
                  OR [r].[EndedAtUtc] IS NULL
                  OR EXISTS
                  (
                      SELECT 1 FROM [snapshot].[CaptureRun] AS [later]
                      WHERE [later].[CollectorCode]='WAIT_STATS'
                        AND [later].[EndedAtUtc] IS NOT NULL
                        AND [later].[CaptureRunId]>[r].[CaptureRunId]
                  )
              );
            SET @Rows=@@ROWCOUNT;
            SET @RunsDeleted+=@Rows;
            SET @Deleted+=@Rows;

            DELETE TOP (@BatchRows) [s]
            FROM [snapshot].[Scope] AS [s]
            WHERE [s].[ScopeType]<>'SERVER'
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[MetricSample] AS [m] WHERE [m].[ScopeId]=[s].[ScopeId])
              AND NOT EXISTS (SELECT 1 FROM [snapshot].[Scope] AS [c] WHERE [c].[ParentScopeId]=[s].[ScopeId]);
            SET @Rows=@@ROWCOUNT;
            SET @ScopeDeleted+=@Rows;
            SET @Deleted+=@Rows;

            COMMIT TRANSACTION;
            SET @Batch+=1;
            IF @Deleted=0 BREAK;
        END;

        SELECT @UsedAfter=CONVERT(decimal(19,3),COALESCE(SUM(CONVERT(decimal(38,3),[size]))*8.0/1024.0,0))
        FROM [sys].[database_files] WITH (NOLOCK)
        WHERE [type]=0;

        SET @BudgetExceededOut=CASE WHEN @UsedAfter>@SoftBudgetMB THEN 1 ELSE 0 END;
        SET @StatusCodeOut=CASE WHEN @Batch>=@MaxBatches AND @Deleted>0 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END;

        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [UsedDataMbAfter]=@UsedAfter
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @BudgetExceededOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        UPDATE [snapshot].[PurgeRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[StatusCode]=@StatusCodeOut,
            [BatchesExecuted]=@Batch,[MetricRowsDeleted]=@MetricDeleted,
            [PayloadRowsDeleted]=@PayloadDeleted,[ModuleRowsDeleted]=@ModuleDeleted,
            [CaptureRunsDeleted]=@RunsDeleted,[ScopeRowsDeleted]=@ScopeDeleted,
            [ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut
        WHERE [PurgeRunId]=@PurgeRunIdOut;
    END CATCH;
END;
GO
"""),
}

# Released 1.2.1 bodies are reconstructed only by exact reverse fragments.
# The full independent released-byte hashes prevent a current-source approximation.
LEGACY_TARGET_V1_2_1_PATCHES = {'020_InternalConfigureSnapshotPolicy.sql': ('397b29eb601df68ecedb0bfabf7b1af9909fcd03b5d4276dcdbe8b5bab2a4230',
                                             [('===============================================================================\n'
                                               'Objekt       : snapshot.InternalConfigureSnapshotPolicy\n'
                                               'Version      : 1.2.0\n'
                                               'Stand        : 2026-10-26\n'
                                               'Zweck        : Schreibt die typisierten SC-023-Policies in '
                                               'der aktuell\n'
                                               '               verbundenen Snapshot-Datenbank.\n'
                                               '===============================================================================\n',
                                               '===============================================================================\n'
                                               'Objekt       : snapshot.InternalConfigureSnapshotPolicy\n'
                                               'Version      : 1.2.0\n'
                                               'Stand        : 2026-10-25\n'
                                               'Zweck        : Schreibt die typisierten SC-023-Policies in '
                                               'der aktuell\n'
                                               '               verbundenen Snapshot-Datenbank.\n'
                                               '===============================================================================\n'),
                                              ('\n'
                                               '    IF @JoinFrameworkTransaction IS NULL OR\n'
                                               '       (@JoinFrameworkTransaction=1 AND\n'
                                               "         (@CollectorCode NOT IN('WAIT_STATS','FILE_IO') OR "
                                               '@UpdateSharedPolicy<>1 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 '
                                               'OR (@@OPTIONS & 2)<>0))\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Die ausdrückliche "
                                               'Transaktionsbeteiligung benötigt WAIT_STATS oder FILE_IO mit '
                                               "Shared1 und eine committable Besitzertransaktion.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @UseV2Contract=1 AND ((@@OPTIONS & 2)<>0 OR '
                                               "(@CollectorCode IN('WAIT_STATS','FILE_IO') AND "
                                               '@@TRANCOUNT<>0 AND @JoinFrameworkTransaction=0))\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Der Collectorvertrag "
                                               'benötigt IMPLICIT_TRANSACTIONS OFF und außerhalb der '
                                               "Besitzerbeteiligung keine Callertransaktion.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @CollectorCode NOT IN '
                                               "('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO') OR "
                                               '@CollectorEnabled IS NULL\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Ungültiger Collector oder "
                                               "Aktivierungswert.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               "    IF @CollectorCode IN('WAIT_STATS','FILE_IO') OR "
                                               '@ExpectedTargetDatabaseId IS NOT NULL\n'
                                               '       OR @ExpectedTargetDatabaseName IS NOT NULL OR '
                                               '@ExpectedTargetCreateDate IS NOT NULL\n'
                                               '    BEGIN\n'
                                               '        IF @ExpectedTargetDatabaseId IS NULL OR '
                                               '@ExpectedTargetDatabaseName IS NULL\n',
                                               '\n'
                                               '    IF @JoinFrameworkTransaction IS NULL OR\n'
                                               '       (@JoinFrameworkTransaction=1 AND\n'
                                               "         (@CollectorCode<>'WAIT_STATS' OR "
                                               '@UpdateSharedPolicy<>1 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 '
                                               'OR (@@OPTIONS & 2)<>0))\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Die ausdrückliche "
                                               'Transaktionsbeteiligung benötigt WAIT_STATS/Shared1 und eine '
                                               "committable Besitzertransaktion.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @UseV2Contract=1 AND ((@@OPTIONS & 2)<>0 OR '
                                               "(@CollectorCode='WAIT_STATS' AND @@TRANCOUNT<>0 AND "
                                               '@JoinFrameworkTransaction=0))\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Der neue Wait-Vertrag "
                                               'benötigt IMPLICIT_TRANSACTIONS OFF und für WAIT_STATS keine '
                                               "Callertransaktion.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @CollectorCode NOT IN '
                                               "('PERFORMANCE_COUNTERS','WAIT_STATS') OR @CollectorEnabled "
                                               'IS NULL\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='INVALID_PARAMETER',@ErrorNumberOut=51011,\n"
                                               "               @ErrorMessageOut=N'Ungültiger Collector oder "
                                               "Aktivierungswert.';\n"
                                               '        RETURN 51011;\n'
                                               '    END;\n'
                                               '\n'
                                               "    IF @CollectorCode='WAIT_STATS' OR "
                                               '@ExpectedTargetDatabaseId IS NOT NULL\n'
                                               '       OR @ExpectedTargetDatabaseName IS NOT NULL OR '
                                               '@ExpectedTargetCreateDate IS NOT NULL\n'
                                               '    BEGIN\n'
                                               '        IF @ExpectedTargetDatabaseId IS NULL OR '
                                               '@ExpectedTargetDatabaseName IS NULL\n'),
                                              ('        END;\n'
                                               '        IF (SELECT COUNT_BIG(*) FROM '
                                               '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                               '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                               '            AND '
                                               "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                               'AND [SchemaVersion]=2) OR '
                                               '(CONVERT(varbinary(max),[PackageVersion]) '
                                               "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                               'AND [SchemaVersion]=3)))\n'
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                               '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH '
                                               '(NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS '
                                               '[p] WITH (NOLOCK)\n'
                                               '                         WHERE [p].[object_id] IN(SELECT '
                                               '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                               '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                               '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n"
                                               '                           AND '
                                               "CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly'))\n"
                                               '        BEGIN\n'
                                               '            SELECT '
                                               "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53761,\n"
                                               "                   @ErrorMessageOut=N'Das vollständig "
                                               "installierte kompatible Collector-Target fehlt.';\n"
                                               '            RETURN;\n'
                                               '        END;\n'
                                               '    END;\n'
                                               '\n'
                                               "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                               '[snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') "
                                               'AND [SchemaVersion]=3)\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53781,@ErrorMessageOut=N'Das "
                                               "vollständige Datei-I/O-Target 1.3.0 fehlt.';\n"
                                               '        RETURN;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @CollectionIntervalSeconds NOT BETWEEN 1 AND 3600\n',
                                               '        END;\n'
                                               '        IF (SELECT COUNT_BIG(*) FROM '
                                               '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                               '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                               '            AND '
                                               "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                               'AND [SchemaVersion]=2)\n'
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                               '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH '
                                               '(NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS '
                                               '[p] WITH (NOLOCK)\n'
                                               '                         WHERE [p].[object_id] IN(SELECT '
                                               '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                               '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                               '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n"
                                               '                           AND '
                                               "CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),N'@ContractOnly'))\n"
                                               '        BEGIN\n'
                                               '            SELECT '
                                               "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53761,\n"
                                               "                   @ErrorMessageOut=N'Das vollständig "
                                               "installierte Wait-Target 1.2.1 fehlt.';\n"
                                               '            RETURN;\n'
                                               '        END;\n'
                                               '    END;\n'
                                               '\n'
                                               '    IF @CollectionIntervalSeconds NOT BETWEEN 1 AND '
                                               '3600\n')]),
 '040_InternalPrepareCollectionCycle.sql': ('de3379b41e0e9ece57cc82001d99fd8140429a9e673595fb65492b88b6a07128',
                                            [('===============================================================================\n'
                                              'Objekt       : snapshot.InternalPrepareCollectionCycle\n'
                                              'Version      : 1.2.0\n'
                                              'Stand        : 2026-10-26\n'
                                              'Zweck        : Prüft Intervall und Größenbudget und eröffnet '
                                              'genau einen Lauf.\n'
                                              '===============================================================================\n'
                                              '*/\n',
                                              '===============================================================================\n'
                                              'Objekt       : snapshot.InternalPrepareCollectionCycle\n'
                                              'Version      : 1.2.0\n'
                                              'Stand        : 2026-10-25\n'
                                              'Zweck        : Prüft Intervall und Größenbudget und eröffnet '
                                              'genau einen Lauf.\n'
                                              '===============================================================================\n'
                                              '*/\n'),
                                             ("           @StatusCodeOut='AVAILABLE',@ErrorMessageOut=NULL;\n"
                                              '\n'
                                              '    SET '
                                              "@CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));\n"
                                              '    IF @CollectorCode NOT IN '
                                              "('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO')\n"
                                              '       OR @PolicyOnly IS NULL OR (@PolicyOnly=1 AND '
                                              "@CollectorCode NOT IN('WAIT_STATS','FILE_IO'))\n"
                                              "       OR (@CollectorCode IN('WAIT_STATS','FILE_IO') AND "
                                              '(@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))\n'
                                              '    BEGIN\n'
                                              "        SELECT @StatusCodeOut='INVALID_PARAMETER',\n"
                                              "               @ErrorMessageOut=N'Ungültiger Collector oder "
                                              "unzulässiger Wait-Callertransaktionszustand.';\n"
                                              '        RETURN 51011;\n'
                                              '    END;\n'
                                              "    IF @CollectorCode IN('WAIT_STATS','FILE_IO') OR "
                                              '@ExpectedTargetDatabaseId IS NOT NULL\n'
                                              '       OR @ExpectedTargetDatabaseName IS NOT NULL OR '
                                              '@ExpectedTargetCreateDate IS NOT NULL\n'
                                              '    BEGIN\n'
                                              '        IF @ExpectedTargetDatabaseId IS NULL OR '
                                              '@ExpectedTargetDatabaseName IS NULL\n',
                                              "           @StatusCodeOut='AVAILABLE',@ErrorMessageOut=NULL;\n"
                                              '\n'
                                              '    SET '
                                              "@CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));\n"
                                              '    IF @CollectorCode NOT IN '
                                              "('PERFORMANCE_COUNTERS','WAIT_STATS')\n"
                                              '       OR @PolicyOnly IS NULL OR (@PolicyOnly=1 AND '
                                              "@CollectorCode<>'WAIT_STATS')\n"
                                              "       OR (@CollectorCode='WAIT_STATS' AND (@@TRANCOUNT<>0 OR "
                                              '(@@OPTIONS & 2)<>0))\n'
                                              '    BEGIN\n'
                                              "        SELECT @StatusCodeOut='INVALID_PARAMETER',\n"
                                              "               @ErrorMessageOut=N'Ungültiger Collector oder "
                                              "unzulässiger Wait-Callertransaktionszustand.';\n"
                                              '        RETURN 51011;\n'
                                              '    END;\n'
                                              "    IF @CollectorCode='WAIT_STATS' OR "
                                              '@ExpectedTargetDatabaseId IS NOT NULL\n'
                                              '       OR @ExpectedTargetDatabaseName IS NOT NULL OR '
                                              '@ExpectedTargetCreateDate IS NOT NULL\n'
                                              '    BEGIN\n'
                                              '        IF @ExpectedTargetDatabaseId IS NULL OR '
                                              '@ExpectedTargetDatabaseName IS NULL\n'),
                                             ('            RETURN;\n'
                                              '        END;\n'
                                              '    END;\n'
                                              "    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND\n"
                                              '       ((SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '           AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              '(CONVERT(varbinary(max),[PackageVersion]) '
                                              "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                              '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) '
                                              'ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] '
                                              'WITH (NOLOCK)\n'
                                              '                      WHERE [p].[object_id] IN(SELECT '
                                              '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                              '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                              '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n",
                                              '            RETURN;\n'
                                              '        END;\n'
                                              '    END;\n'
                                              "    IF @CollectorCode='WAIT_STATS' AND\n"
                                              '       ((SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '           AND '
                                              "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2)\n'
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                              '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) '
                                              'ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] '
                                              'WITH (NOLOCK)\n'
                                              '                      WHERE [p].[object_id] IN(SELECT '
                                              '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                              '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                              '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n"),
                                             ('    BEGIN\n'
                                              "        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',\n"
                                              "               @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n"
                                              '        RETURN;\n'
                                              '    END;\n'
                                              '\n'
                                              "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                              '[snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') "
                                              'AND [SchemaVersion]=3)\n'
                                              '    BEGIN\n'
                                              '        SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorMessageOut=N'Datei-I/O "
                                              "benötigt das vollständige Schema-3-Target.';\n"
                                              '        RETURN;\n'
                                              '    END;\n'
                                              '\n',
                                              '    BEGIN\n'
                                              "        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',\n"
                                              "               @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n"
                                              '        RETURN;\n'
                                              '    END;\n'
                                              '\n'),
                                             ('    BEGIN\n'
                                              '        SELECT TOP(1) @LastCompletedUtc=[EndedAtUtc]\n'
                                              '        FROM [snapshot].[CaptureRun]\n'
                                              '        WHERE [CollectorCode]=@CollectorCode AND [EndedAtUtc] '
                                              'IS NOT NULL\n'
                                              '        ORDER BY [CaptureRunId] DESC;\n'
                                              "        IF @StatusCodeOut='AVAILABLE' AND @RunEvenIfNotDue=0 "
                                              'AND @LastCompletedUtc IS NOT NULL\n'
                                              '           AND '
                                              'DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now\n',
                                              '    BEGIN\n'
                                              '        SELECT TOP(1) @LastCompletedUtc=[EndedAtUtc]\n'
                                              '        FROM [snapshot].[CaptureRun]\n'
                                              "        WHERE [CollectorCode]='WAIT_STATS' AND [EndedAtUtc] "
                                              'IS NOT NULL\n'
                                              '        ORDER BY [CaptureRunId] DESC;\n'
                                              "        IF @StatusCodeOut='AVAILABLE' AND @RunEvenIfNotDue=0 "
                                              'AND @LastCompletedUtc IS NOT NULL\n'
                                              '           AND '
                                              'DATEADD(SECOND,@IntervalSeconds,@LastCompletedUtc)>@Now\n'),
                                             ('    SELECT TOP (1) @LastCompletedUtc=[EndedAtUtc]\n'
                                              '    FROM [snapshot].[CaptureRun]\n'
                                              '    WHERE [CollectorCode]=@CollectorCode\n'
                                              "      AND (@CollectorCode IN('WAIT_STATS','FILE_IO') OR "
                                              "[StatusCode] IN ('AVAILABLE','PARTIAL'))\n"
                                              '      AND [EndedAtUtc] IS NOT NULL\n'
                                              '    ORDER BY [CaptureRunId] DESC;\n'
                                              '\n',
                                              '    SELECT TOP (1) @LastCompletedUtc=[EndedAtUtc]\n'
                                              '    FROM [snapshot].[CaptureRun]\n'
                                              '    WHERE [CollectorCode]=@CollectorCode\n'
                                              "      AND (@CollectorCode='WAIT_STATS' OR [StatusCode] IN "
                                              "('AVAILABLE','PARTIAL'))\n"
                                              '      AND [EndedAtUtc] IS NOT NULL\n'
                                              '    ORDER BY [CaptureRunId] DESC;\n'
                                              '\n'),
                                             ("        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',\n"
                                              "               @ErrorMessageOut=N'Das konfigurierte "
                                              "Sammlerintervall ist noch nicht abgelaufen.';\n"
                                              '\n'
                                              "    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND "
                                              "@StatusCodeOut<>'AVAILABLE' RETURN;\n"
                                              '\n'
                                              '    INSERT [snapshot].[CaptureRun]\n'
                                              '    (\n',
                                              "        SELECT @StatusCodeOut='SKIPPED_NOT_DUE',\n"
                                              "               @ErrorMessageOut=N'Das konfigurierte "
                                              "Sammlerintervall ist noch nicht abgelaufen.';\n"
                                              '\n'
                                              "    IF @CollectorCode='WAIT_STATS' AND "
                                              "@StatusCodeOut<>'AVAILABLE' RETURN;\n"
                                              '\n'
                                              '    INSERT [snapshot].[CaptureRun]\n'
                                              '    (\n')]),
 '055_InternalCompleteWaitStatsCycle.sql': ('0010c55376a06586134c801c743e1cd1a49aefac40b095d112d2ddab53067d41',
                                            [('===============================================================================\n'
                                              'Objekt       : snapshot.InternalCompleteWaitStatsCycle\n'
                                              'Version      : 1.0.1\n'
                                              'Stand        : 2026-10-26\n'
                                              'Zweck        : Die Procedure bindet einen vollständigen '
                                              'Waitread an seinen Run\n'
                                              '               und speichert Rohwerte und Differenzkandidaten '
                                              'atomar.\n'
                                              'Grenze       : Monotonie beweist keine ununterbrochene '
                                              'Resetkontinuität.\n',
                                              '===============================================================================\n'
                                              'Objekt       : snapshot.InternalCompleteWaitStatsCycle\n'
                                              'Version      : 1.0.1\n'
                                              'Stand        : 2026-10-25\n'
                                              'Zweck        : Die Procedure bindet einen vollständigen '
                                              'Waitread an seinen Run\n'
                                              '               und speichert Rohwerte und Differenzkandidaten '
                                              'atomar.\n'
                                              'Grenze       : Monotonie beweist keine ununterbrochene '
                                              'Resetkontinuität.\n'),
                                             ('        IF (SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '           (SELECT 1 FROM [snapshot].[PackageVersion]\n'
                                              '            WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '              AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              '(CONVERT(varbinary(max),[PackageVersion]) '
                                              "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        BEGIN\n'
                                              '            SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,\n"
                                              "                   @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n",
                                              '        IF (SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '           (SELECT 1 FROM [snapshot].[PackageVersion]\n'
                                              '            WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '              AND '
                                              "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1')\n"
                                              '              AND [SchemaVersion]=2)\n'
                                              '        BEGIN\n'
                                              '            SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,\n"
                                              "                   @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n"),
                                             ('             '
                                              '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,\n'
                                              '             '
                                              '@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                              '             '
                                              '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                              "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                              'COALESCE(@RetentionContract,0)<>CASE WHEN EXISTS(SELECT 1 '
                                              'FROM [snapshot].[PackageVersion] WHERE '
                                              "[PackageVersion]='1.3.1' AND [SchemaVersion]=3) THEN 3 WHEN "
                                              'EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              '[SchemaVersion]=3) THEN 2 ELSE 1 END\n'
                                              '           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT '
                                              'NULL OR COALESCE(@ProbeBudget,1)<>0\n'
                                              "            THROW 53762,N'Der benötigte read-only "
                                              "Retentionsvertrag fehlt.',1;\n"
                                              '\n'
                                              '        BEGIN TRANSACTION;\n',
                                              '             '
                                              '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,\n'
                                              '             '
                                              '@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                              '             '
                                              '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                              "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                              'COALESCE(@RetentionContract,0)<>1\n'
                                              '           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT '
                                              'NULL\n'
                                              "            THROW 53762,N'Der benötigte read-only "
                                              "Retentionsvertrag fehlt.',1;\n"
                                              '\n'
                                              '        BEGIN TRANSACTION;\n')]),
 '070_InternalPurgeExpiredData.sql': ('d2603c04e4885a6ec84888c2abc7811bb4d42f048e9eea23dab6cfb65171f396',
                                      [('        END;\n'
                                        '    END;\n'
                                        '\n'
                                        '    SET NOCOUNT ON;\n'
                                        '    SET LOCK_TIMEOUT 0;\n'
                                        '    SET @RetentionContractVersionOut=CASE WHEN EXISTS(SELECT 1 FROM '
                                        '[snapshot].[PackageVersion] WITH (NOLOCK)\n'
                                        '      WHERE [SchemaVersion]=3 AND [PackageVersion] '
                                        "IN('1.2.2','1.3.0','1.3.1')) THEN 3 ELSE 1 END;\n"
                                        '    -- The handshake reads only the admitted version and creates no '
                                        'purge receipt.\n'
                                        '    IF @ContractOnly=1 RETURN;\n'
                                        '\n'
                                        '    SET NOCOUNT ON;\n',
                                        '        END;\n'
                                        '    END;\n'
                                        '\n'
                                        '    -- The installation/runtime handshake does not read or change '
                                        'package data.\n'
                                        '    IF @ContractOnly=1 RETURN;\n'
                                        '\n'
                                        '    SET NOCOUNT ON;\n'),
                                       ('              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[MetricSample] AS [m] WHERE '
                                        '[m].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[PayloadSnapshot] AS [p] WHERE '
                                        '[p].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[ModuleStatus] AS [s] WHERE '
                                        '[s].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              -- Waits retain their latest finalized run. File I/O '
                                        'retains its latest\n'
                                        '              -- run even when finalization is unconfirmed or '
                                        'children are absent.\n'
                                        '              AND\n'
                                        '              (\n'
                                        '                  [r].[CollectorCode] NOT '
                                        "IN('WAIT_STATS','FILE_IO')\n"
                                        "                  OR ([r].[CollectorCode]='WAIT_STATS' AND "
                                        '[r].[EndedAtUtc] IS NULL)\n'
                                        '                  OR EXISTS\n'
                                        '                  (\n'
                                        '                      SELECT 1 FROM [snapshot].[CaptureRun] AS '
                                        '[later]\n'
                                        '                      WHERE '
                                        '[later].[CollectorCode]=[r].[CollectorCode]\n'
                                        "                        AND ([r].[CollectorCode]='FILE_IO' OR "
                                        '[later].[EndedAtUtc] IS NOT NULL)\n'
                                        '                        AND '
                                        '[later].[CaptureRunId]>[r].[CaptureRunId]\n'
                                        '                  )\n'
                                        '              );\n',
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[MetricSample] AS [m] WHERE '
                                        '[m].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[PayloadSnapshot] AS [p] WHERE '
                                        '[p].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[ModuleStatus] AS [s] WHERE '
                                        '[s].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              -- Preserve the latest finalized Wait run as the '
                                        'comparison fence,\n'
                                        '              -- including a failed run whose children have expired '
                                        'or never existed.\n'
                                        '              AND\n'
                                        '              (\n'
                                        "                  [r].[CollectorCode]<>'WAIT_STATS'\n"
                                        '                  OR [r].[EndedAtUtc] IS NULL\n'
                                        '                  OR EXISTS\n'
                                        '                  (\n'
                                        '                      SELECT 1 FROM [snapshot].[CaptureRun] AS '
                                        '[later]\n'
                                        "                      WHERE [later].[CollectorCode]='WAIT_STATS'\n"
                                        '                        AND [later].[EndedAtUtc] IS NOT NULL\n'
                                        '                        AND '
                                        '[later].[CaptureRunId]>[r].[CaptureRunId]\n'
                                        '                  )\n'
                                        '              );\n')])}

# Exact released 1.3.0 target bodies; source digest and native stored hashes bind recovery.
LEGACY_TARGET_V1_3_0_PATCHES = {'020_InternalConfigureSnapshotPolicy.sql': ('d6d77e052c0a4816cedb066ddcd29e04e9567c4268111285bc3a09c5c1c32585',
                                             [('===============================================================================\n'
                                               'Objekt       : snapshot.InternalConfigureSnapshotPolicy\n'
                                               'Version      : 1.2.0\n'
                                               'Stand        : 2026-10-26\n'
                                               'Zweck        : Schreibt die typisierten SC-023-Policies in '
                                               'der aktuell\n'
                                               '               verbundenen Snapshot-Datenbank.\n'
                                               '===============================================================================\n',
                                               '===============================================================================\n'
                                               'Objekt       : snapshot.InternalConfigureSnapshotPolicy\n'
                                               'Version      : 1.2.0\n'
                                               'Stand        : 2026-10-25\n'
                                               'Zweck        : Schreibt die typisierten SC-023-Policies in '
                                               'der aktuell\n'
                                               '               verbundenen Snapshot-Datenbank.\n'
                                               '===============================================================================\n'),
                                              ('        END;\n'
                                               '        IF (SELECT COUNT_BIG(*) FROM '
                                               '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                               '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                               '            AND '
                                               "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                               'AND [SchemaVersion]=2) OR '
                                               '(CONVERT(varbinary(max),[PackageVersion]) '
                                               "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                               'AND [SchemaVersion]=3)))\n'
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                               '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH '
                                               '(NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS '
                                               '[p] WITH (NOLOCK)\n'
                                               '                         WHERE [p].[object_id] IN(SELECT '
                                               '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                               '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                               '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n",
                                               '        END;\n'
                                               '        IF (SELECT COUNT_BIG(*) FROM '
                                               '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                               '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                               '            AND '
                                               "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                               'AND [SchemaVersion]=2) OR '
                                               "(CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') "
                                               'AND [SchemaVersion]=3)))\n'
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                               '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH '
                                               '(NOLOCK) ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                               '           OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS '
                                               '[p] WITH (NOLOCK)\n'
                                               '                         WHERE [p].[object_id] IN(SELECT '
                                               '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                               '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                               '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                               "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                               'AND '
                                               "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n"),
                                              ('        END;\n'
                                               '    END;\n'
                                               '\n'
                                               "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                               '[snapshot].[PackageVersion] WHERE '
                                               "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') "
                                               'AND [SchemaVersion]=3)\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53781,@ErrorMessageOut=N'Das "
                                               "vollständige Datei-I/O-Target 1.3.0 fehlt.';\n"
                                               '        RETURN;\n',
                                               '        END;\n'
                                               '    END;\n'
                                               '\n'
                                               "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                               "[snapshot].[PackageVersion] WHERE [PackageVersion]='1.3.0' "
                                               'AND [SchemaVersion]=3)\n'
                                               '    BEGIN\n'
                                               '        SELECT '
                                               "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorNumberOut=53781,@ErrorMessageOut=N'Das "
                                               "vollständige Datei-I/O-Target 1.3.0 fehlt.';\n"
                                               '        RETURN;\n')]),
 '040_InternalPrepareCollectionCycle.sql': ('f06365f0e3c9ffe5996e3a3415a243db25aab77065d6d39db76aef6f31447b5c',
                                            [('===============================================================================\n'
                                              'Objekt       : snapshot.InternalPrepareCollectionCycle\n'
                                              'Version      : 1.2.0\n'
                                              'Stand        : 2026-10-26\n'
                                              'Zweck        : Prüft Intervall und Größenbudget und eröffnet '
                                              'genau einen Lauf.\n'
                                              '===============================================================================\n'
                                              '*/\n',
                                              '===============================================================================\n'
                                              'Objekt       : snapshot.InternalPrepareCollectionCycle\n'
                                              'Version      : 1.2.0\n'
                                              'Stand        : 2026-10-25\n'
                                              'Zweck        : Prüft Intervall und Größenbudget und eröffnet '
                                              'genau einen Lauf.\n'
                                              '===============================================================================\n'
                                              '*/\n'),
                                             ("    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND\n"
                                              '       ((SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '           AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              '(CONVERT(varbinary(max),[PackageVersion]) '
                                              "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                              '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) '
                                              'ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] '
                                              'WITH (NOLOCK)\n'
                                              '                      WHERE [p].[object_id] IN(SELECT '
                                              '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                              '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                              '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n",
                                              "    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND\n"
                                              '       ((SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '          (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '           AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              "(CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[procedures] AS '
                                              '[wp] WITH (NOLOCK) JOIN [sys].[schemas] AS [ws] WITH (NOLOCK) '
                                              'ON [ws].[schema_id]=[wp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[ws].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[wp].[name])=CONVERT(varbinary(max),N'InternalCompleteWaitStatsCycle'))\n"
                                              '        OR NOT EXISTS(SELECT 1 FROM [sys].[parameters] AS [p] '
                                              'WITH (NOLOCK)\n'
                                              '                      WHERE [p].[object_id] IN(SELECT '
                                              '[hp].[object_id] FROM [sys].[procedures] AS [hp] WITH '
                                              '(NOLOCK) JOIN [sys].[schemas] AS [hs] WITH (NOLOCK) ON '
                                              '[hs].[schema_id]=[hp].[schema_id] WHERE '
                                              "CONVERT(varbinary(max),[hs].[name])=CONVERT(varbinary(max),N'snapshot') "
                                              'AND '
                                              "CONVERT(varbinary(max),[hp].[name])=CONVERT(varbinary(max),N'InternalPurgeExpiredData'))\n"),
                                             ('        RETURN;\n'
                                              '    END;\n'
                                              '\n'
                                              "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                              '[snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') "
                                              'AND [SchemaVersion]=3)\n'
                                              '    BEGIN\n'
                                              '        SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorMessageOut=N'Datei-I/O "
                                              "benötigt das vollständige Schema-3-Target.';\n"
                                              '        RETURN;\n',
                                              '        RETURN;\n'
                                              '    END;\n'
                                              '\n'
                                              "    IF @CollectorCode='FILE_IO' AND NOT EXISTS(SELECT 1 FROM "
                                              '[snapshot].[PackageVersion] WHERE '
                                              "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') "
                                              'AND [SchemaVersion]=3)\n'
                                              '    BEGIN\n'
                                              '        SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@ErrorMessageOut=N'Datei-I/O "
                                              "benötigt das vollständige Schema-3-Target.';\n"
                                              '        RETURN;\n')]),
 '055_InternalCompleteWaitStatsCycle.sql': ('190fc9c2ae4337f3f6bcd4a1132b1ee955df62f1eded6674c19f7498b9687608',
                                            [('===============================================================================\n'
                                              'Objekt       : snapshot.InternalCompleteWaitStatsCycle\n'
                                              'Version      : 1.0.1\n'
                                              'Stand        : 2026-10-26\n'
                                              'Zweck        : Die Procedure bindet einen vollständigen '
                                              'Waitread an seinen Run\n'
                                              '               und speichert Rohwerte und Differenzkandidaten '
                                              'atomar.\n'
                                              'Grenze       : Monotonie beweist keine ununterbrochene '
                                              'Resetkontinuität.\n',
                                              '===============================================================================\n'
                                              'Objekt       : snapshot.InternalCompleteWaitStatsCycle\n'
                                              'Version      : 1.0.1\n'
                                              'Stand        : 2026-10-25\n'
                                              'Zweck        : Die Procedure bindet einen vollständigen '
                                              'Waitread an seinen Run\n'
                                              '               und speichert Rohwerte und Differenzkandidaten '
                                              'atomar.\n'
                                              'Grenze       : Monotonie beweist keine ununterbrochene '
                                              'Resetkontinuität.\n'),
                                             ('        IF (SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '           (SELECT 1 FROM [snapshot].[PackageVersion]\n'
                                              '            WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '              AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              '(CONVERT(varbinary(max),[PackageVersion]) '
                                              "IN(CONVERT(varbinary(max),'1.3.0'),CONVERT(varbinary(max),'1.3.1')) "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        BEGIN\n'
                                              '            SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,\n"
                                              "                   @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n",
                                              '        IF (SELECT COUNT_BIG(*) FROM '
                                              '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                              '           (SELECT 1 FROM [snapshot].[PackageVersion]\n'
                                              '            WHERE '
                                              "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                              '              AND '
                                              "((CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1') "
                                              'AND [SchemaVersion]=2) OR '
                                              "(CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') "
                                              'AND [SchemaVersion]=3)))\n'
                                              '        BEGIN\n'
                                              '            SELECT '
                                              "@StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,\n"
                                              "                   @ErrorMessageOut=N'Das vollständig "
                                              "installierte Wait-Target 1.2.1 fehlt.';\n"),
                                             ('             '
                                              '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,\n'
                                              '             '
                                              '@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                              '             '
                                              '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                              "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                              'COALESCE(@RetentionContract,0)<>CASE WHEN EXISTS(SELECT 1 '
                                              'FROM [snapshot].[PackageVersion] WHERE '
                                              "[PackageVersion]='1.3.1' AND [SchemaVersion]=3) THEN 3 WHEN "
                                              'EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                              '[SchemaVersion]=3) THEN 2 ELSE 1 END\n'
                                              '           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT '
                                              'NULL OR COALESCE(@ProbeBudget,1)<>0\n'
                                              "            THROW 53762,N'Der benötigte read-only "
                                              "Retentionsvertrag fehlt.',1;\n"
                                              '\n',
                                              '             '
                                              '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,\n'
                                              '             '
                                              '@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                              '             '
                                              '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                              "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                              'COALESCE(@RetentionContract,0)<>CASE WHEN EXISTS(SELECT 1 '
                                              'FROM [snapshot].[PackageVersion] WHERE [SchemaVersion]=3) '
                                              'THEN 2 ELSE 1 END\n'
                                              '           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT '
                                              'NULL OR COALESCE(@ProbeBudget,1)<>0\n'
                                              "            THROW 53762,N'Der benötigte read-only "
                                              "Retentionsvertrag fehlt.',1;\n"
                                              '\n')]),
 '057_InternalCompleteFileIOCycle.sql': ('1abdc3645d1de792db9d232f8e1253bcfed443050cdd1410d4e031c77ed085b8',
                                         [('/*\n'
                                           '===============================================================================\n'
                                           'Objekt       : snapshot.InternalCompleteFileIOCycle\n'
                                           'Version      : 1.1.0\n'
                                           'Stand        : 2026-10-26\n'
                                           'Zweck        : Die Procedure bindet Datei-I/O-Rohwerte und '
                                           'Vergleichskontexte\n'
                                           '               atomar an einen vorbereiteten eigenen Lauf.\n',
                                           '/*\n'
                                           '===============================================================================\n'
                                           'Objekt       : snapshot.InternalCompleteFileIOCycle\n'
                                           'Version      : 1.0.0\n'
                                           'Stand        : 2026-10-26\n'
                                           'Zweck        : Die Procedure bindet Datei-I/O-Rohwerte und '
                                           'Vergleichskontexte\n'
                                           '               atomar an einen vorbereiteten eigenen Lauf.\n'),
                                          ('    SET NOCOUNT ON;\n'
                                           '    SET LOCK_TIMEOUT 0;\n'
                                           '    SET XACT_ABORT ON;\n'
                                           '    DECLARE @OwnRun bit=0,@SourceValidated '
                                           'bit=0,@ValidatedIssuesJson nvarchar(max),\n'
                                           '            @SourceErrorNumber int,@SourceErrorMessage '
                                           'nvarchar(2048),@Started datetime2(3),@SourceName '
                                           'sysname,@MaxRows int,@Payload bit,\n'
                                           '            @Now datetime2(3),@Meta nvarchar(max),@Engine '
                                           'nvarchar(max),@Framework nvarchar(max),@Selection '
                                           'nvarchar(max),\n'
                                           '            @Start datetime2(3),@End datetime2(3),@ReadStart '
                                           'datetime2(3),@ReadEnd datetime2(3),\n'
                                           '            @SourceStatus varchar(40),@Complete bit,@Fatal '
                                           'bit,@Native bigint,@Eligible bigint,@Excluded bigint,@Unbound '
                                           'bigint,\n'
                                           '            @Written bigint,@Comparable bigint=0,@Limited '
                                           'bit,@ServerScope bigint,@ServerIdentity nvarchar(max),\n'
                                           '            @Previous bigint,@PreviousStatus '
                                           'varchar(40),@PreviousEnded datetime2(3),@PreviousContext '
                                           'nvarchar(max),@PreviousValid bit=0,\n'
                                           '            @SelectionHash varchar(64),@EngineHash '
                                           'varchar(64),@FrameworkHash varchar(64),\n'
                                           '            @Context nvarchar(max),@ContextEpoch '
                                           'uniqueidentifier=NEWID(),@Manifest nvarchar(max),@ManifestHash '
                                           'varchar(64);\n'
                                           '    DECLARE @Objects TABLE([Id] int IDENTITY PRIMARY KEY,[Kind] '
                                           'varchar(8),[Ordinal] int,[Json] nvarchar(max));\n',
                                           '    SET NOCOUNT ON;\n'
                                           '    SET LOCK_TIMEOUT 0;\n'
                                           '    SET XACT_ABORT ON;\n'
                                           '    DECLARE @OwnRun bit=0,@Started datetime2(3),@SourceName '
                                           'sysname,@MaxRows int,@Payload bit,\n'
                                           '            @Now datetime2(3),@Meta nvarchar(max),@Engine '
                                           'nvarchar(max),@Framework nvarchar(max),@Selection '
                                           'nvarchar(max),\n'
                                           '            @Start datetime2(3),@End datetime2(3),@ReadStart '
                                           'datetime2(3),@ReadEnd datetime2(3),\n'
                                           '            @SourceStatus varchar(40),@Complete bit,@Fatal '
                                           'bit,@Native bigint,@Eligible bigint,@Excluded bigint,@Unbound '
                                           'bigint,\n'
                                           '            @Written bigint,@Comparable bigint=0,@Limited '
                                           'bit,@ServerScope bigint,@ServerIdentity nvarchar(max),\n'
                                           '            @Previous bigint,@PreviousStatus '
                                           'varchar(40),@PreviousContext nvarchar(max),@PreviousValid '
                                           'bit=0,\n'
                                           '            @SelectionHash varchar(64),@EngineHash '
                                           'varchar(64),@FrameworkHash varchar(64),\n'
                                           '            @Context nvarchar(max),@ContextEpoch '
                                           'uniqueidentifier=NEWID(),@Manifest nvarchar(max),@ManifestHash '
                                           'varchar(64);\n'
                                           '    DECLARE @Objects TABLE([Id] int IDENTITY PRIMARY KEY,[Kind] '
                                           'varchar(8),[Ordinal] int,[Json] nvarchar(max));\n'),
                                          ('    BEGIN TRY\n'
                                           '        IF (SELECT COUNT_BIG(*) FROM '
                                           '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                           '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                           "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                           '            AND '
                                           "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') "
                                           'AND [SchemaVersion]=3)\n'
                                           "            THROW 53781,N'Der Dateiabschluss benötigt das "
                                           "vollständige Schema-3-Target.',1;\n"
                                           '        DECLARE @Probe bigint,@ProbeStatus '
                                           'varchar(40),@ProbeBudget bit,@ProbeError int,@ProbeMessage '
                                           'nvarchar(2048),@Retention int;\n'
                                           '        EXEC [snapshot].[InternalPurgeExpiredData] '
                                           '@MaxBatches=1,@Force=0,@PurgeRunIdOut=@Probe OUTPUT,\n',
                                           '    BEGIN TRY\n'
                                           '        IF (SELECT COUNT_BIG(*) FROM '
                                           '[snapshot].[PackageVersion])<>1 OR NOT EXISTS\n'
                                           '           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE '
                                           "CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')\n"
                                           '            AND '
                                           "CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.0') "
                                           'AND [SchemaVersion]=3)\n'
                                           "            THROW 53781,N'Der Dateiabschluss benötigt das "
                                           "vollständige Schema-3-Target.',1;\n"
                                           '        DECLARE @Probe bigint,@ProbeStatus '
                                           'varchar(40),@ProbeBudget bit,@ProbeError int,@ProbeMessage '
                                           'nvarchar(2048),@Retention int;\n'
                                           '        EXEC [snapshot].[InternalPurgeExpiredData] '
                                           '@MaxBatches=1,@Force=0,@PurgeRunIdOut=@Probe OUTPUT,\n'),
                                          ('             @ErrorMessageOut=@ProbeMessage '
                                           'OUTPUT,@ContractOnly=1,@RetentionContractVersionOut=@Retention '
                                           'OUTPUT,\n'
                                           '             '
                                           '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                           '             '
                                           '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                           "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                           'COALESCE(@ProbeBudget,1)<>0 OR COALESCE(@Retention,0)<>3\n'
                                           '           OR @Probe IS NOT NULL OR @ProbeError IS NOT NULL\n'
                                           "            THROW 53781,N'Der tatsächlich ausgeführte "
                                           "schreibfreie Retentionsvertrag 3 fehlt.',1;\n"
                                           '        BEGIN TRANSACTION;\n'
                                           '        SELECT '
                                           '@Started=[StartedAtUtc],@SourceName=[SourceDatabaseName] FROM '
                                           '[snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)\n'
                                           '        WHERE [CaptureRunId]=@CaptureRunId AND '
                                           "CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'FILE_IO')\n",
                                           '             @ErrorMessageOut=@ProbeMessage '
                                           'OUTPUT,@ContractOnly=1,@RetentionContractVersionOut=@Retention '
                                           'OUTPUT,\n'
                                           '             '
                                           '@ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,\n'
                                           '             '
                                           '@ExpectedTargetCreateDate=@ExpectedTargetCreateDate;\n'
                                           "        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR "
                                           'COALESCE(@ProbeBudget,1)<>0 OR COALESCE(@Retention,0)<>2\n'
                                           '           OR @Probe IS NOT NULL OR @ProbeError IS NOT NULL\n'
                                           "            THROW 53781,N'Der tatsächlich ausgeführte "
                                           "schreibfreie Retentionsvertrag 2 fehlt.',1;\n"
                                           '        BEGIN TRANSACTION;\n'
                                           '        SELECT '
                                           '@Started=[StartedAtUtc],@SourceName=[SourceDatabaseName] FROM '
                                           '[snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)\n'
                                           '        WHERE [CaptureRunId]=@CaptureRunId AND '
                                           "CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'FILE_IO')\n"),
                                          ('           OR @Complete<>CASE WHEN @SourceStatus '
                                           "IN('AVAILABLE','EMPTY_UNPROVEN') THEN 1 ELSE 0 END\n"
                                           '           OR (@Start IS NULL AND @End IS NOT NULL) OR (@Start '
                                           'IS NOT NULL AND @End IS NULL)\n'
                                           '           OR (@ReadStart IS NULL AND @ReadEnd IS NOT NULL) OR '
                                           '(@ReadStart IS NOT NULL AND @ReadEnd IS NULL)\n'
                                           '           OR @Start>@End OR @ReadStart>@ReadEnd\n'
                                           '           OR @Fatal=0 AND (@ReadStart<@Start OR @ReadEnd>@End '
                                           'OR @Start<@Started)\n'
                                           '           OR @Fatal=0 AND (@Engine IS NULL OR @Start IS NULL OR '
                                           '@End IS NULL)\n'
                                           '           OR @Fatal=1 AND @Engine IS NOT NULL\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState') COLLATE "
                                           'Latin1_General_100_BIN2 NOT '
                                           "IN('NOT_STARTED','SUCCEEDED','FAILED')\n"
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' "
                                           'AND (@Native IS NULL OR @Fatal=0 AND @ReadStart IS NULL)\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' "
                                           'AND (@ReadStart IS NOT NULL OR @ReadEnd IS NOT NULL)\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')='FAILED' AND "
                                           '(@Native IS NOT NULL OR @Fatal=0)\n'
                                           '           OR '
                                           "CONVERT(varbinary(max),JSON_VALUE(@Framework,'$.databaseName'))<>CONVERT(varbinary(max),@SourceName)\n"
                                           '           OR NOT EXISTS(SELECT 1 FROM '
                                           '[master].[sys].[databases] WITH (NOLOCK)\n'
                                           '             WHERE '
                                           "[database_id]=TRY_CONVERT(int,JSON_VALUE(@Framework,'$.databaseId'))\n",
                                           '           OR @Complete<>CASE WHEN @SourceStatus '
                                           "IN('AVAILABLE','EMPTY_UNPROVEN') THEN 1 ELSE 0 END\n"
                                           '           OR (@Start IS NULL AND @End IS NOT NULL) OR (@Start '
                                           'IS NOT NULL AND @End IS NULL)\n'
                                           '           OR (@ReadStart IS NULL AND @ReadEnd IS NOT NULL) OR '
                                           '(@ReadStart IS NOT NULL AND @ReadEnd IS NULL)\n'
                                           '           OR @Start>@End OR @ReadStart>@ReadEnd OR '
                                           '@ReadStart<@Start OR @ReadEnd>@End OR @Start<@Started\n'
                                           '           OR @Fatal=0 AND (@Engine IS NULL OR @Start IS NULL OR '
                                           '@End IS NULL)\n'
                                           '           OR @Fatal=1 AND @Engine IS NOT NULL\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState') COLLATE "
                                           'Latin1_General_100_BIN2 NOT '
                                           "IN('NOT_STARTED','SUCCEEDED','FAILED')\n"
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' "
                                           'AND (@ReadStart IS NULL OR @Native IS NULL)\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' "
                                           'AND (@ReadStart IS NOT NULL OR @ReadEnd IS NOT NULL)\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')='FAILED' AND "
                                           '@Native IS NOT NULL\n'
                                           '           OR '
                                           "CONVERT(varbinary(max),JSON_VALUE(@Framework,'$.databaseName'))<>CONVERT(varbinary(max),@SourceName)\n"
                                           '           OR NOT EXISTS(SELECT 1 FROM '
                                           '[master].[sys].[databases] WITH (NOLOCK)\n'
                                           '             WHERE '
                                           "[database_id]=TRY_CONVERT(int,JSON_VALUE(@Framework,'$.databaseId'))\n"),
                                          ('           OR EXISTS(SELECT 1 FROM @Databases GROUP BY '
                                           'CONVERT(varbinary(256),[Name]) HAVING COUNT_BIG(*)<>1)\n'
                                           '           OR (SELECT COUNT_BIG(*) FROM '
                                           "@Databases)<>TRY_CONVERT(bigint,JSON_VALUE(@Selection,'$.selectedDatabaseCount'))\n"
                                           '           OR '
                                           "JSON_VALUE(@Meta,'$.nativeReadState')='NOT_STARTED' AND\n"
                                           '               ((NOT EXISTS(SELECT 1 FROM @Databases) AND '
                                           'COALESCE(@Native,-1)<>0)\n'
                                           '                OR EXISTS(SELECT 1 FROM @Databases) AND '
                                           '(@Fatal=0 OR @Native IS NOT NULL))\n'
                                           "            THROW 53782,N'Die tatsächliche Datenbankauswahl ist "
                                           "widersprüchlich.',1;\n"
                                           '        DECLARE @CanonicalDatabases nvarchar(max)=(SELECT [Id] '
                                           'AS [DatabaseId],[Name] AS [DatabaseName],\n'
                                           '            '
                                           "CONVERT(nvarchar(19),[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[Created])),3) "
                                           'AS [DatabaseCreateDateNative]\n',
                                           '           OR EXISTS(SELECT 1 FROM @Databases GROUP BY '
                                           'CONVERT(varbinary(256),[Name]) HAVING COUNT_BIG(*)<>1)\n'
                                           '           OR (SELECT COUNT_BIG(*) FROM '
                                           "@Databases)<>TRY_CONVERT(bigint,JSON_VALUE(@Selection,'$.selectedDatabaseCount'))\n"
                                           '           OR '
                                           "JSON_VALUE(@Meta,'$.nativeReadState')='NOT_STARTED' AND\n"
                                           '               (EXISTS(SELECT 1 FROM @Databases) OR '
                                           'COALESCE(@Native,-1)<>0)\n'
                                           "            THROW 53782,N'Die tatsächliche Datenbankauswahl ist "
                                           "widersprüchlich.',1;\n"
                                           '        DECLARE @CanonicalDatabases nvarchar(max)=(SELECT [Id] '
                                           'AS [DatabaseId],[Name] AS [DatabaseName],\n'
                                           '            '
                                           "CONVERT(nvarchar(19),[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[Created])),3) "
                                           'AS [DatabaseCreateDateNative]\n'),
                                          ('            '
                                           "JSON_QUERY([Json],'$.MetadataBefore'),JSON_QUERY([Json],'$.MetadataAfter') "
                                           "FROM @Objects WHERE [Kind]='FILE';\n"
                                           '        IF EXISTS(SELECT 1 FROM @Files GROUP BY '
                                           '[DatabaseId],[FileId] HAVING COUNT_BIG(*)<>1)\n'
                                           '           OR EXISTS(SELECT 1 FROM @Files [f] WHERE NOT '
                                           'EXISTS(SELECT 1 FROM @Databases [d] WHERE '
                                           '[d].[Id]=[f].[DatabaseId]))\n'
                                           '           OR @Fatal=0 AND '
                                           "JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' AND (SELECT "
                                           'COUNT_BIG(*) FROM @Files)<>@Native\n'
                                           '           OR '
                                           "(JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' OR @Fatal=1) "
                                           'AND EXISTS(SELECT 1 FROM @Files)\n'
                                           "            THROW 53782,N'Die native Dateimenge verletzt ihre "
                                           "Auswahl- oder Mengenbindung.',1;\n"
                                           '        UPDATE [f] SET [Partition]=CASE\n',
                                           '            '
                                           "JSON_QUERY([Json],'$.MetadataBefore'),JSON_QUERY([Json],'$.MetadataAfter') "
                                           "FROM @Objects WHERE [Kind]='FILE';\n"
                                           '        IF EXISTS(SELECT 1 FROM @Files GROUP BY '
                                           '[DatabaseId],[FileId] HAVING COUNT_BIG(*)<>1)\n'
                                           '           OR EXISTS(SELECT 1 FROM @Files [f] WHERE NOT '
                                           'EXISTS(SELECT 1 FROM @Databases [d] WHERE '
                                           '[d].[Id]=[f].[DatabaseId]))\n'
                                           "           OR JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' "
                                           'AND (SELECT COUNT_BIG(*) FROM @Files)<>@Native\n'
                                           '           OR '
                                           "(JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' OR @Fatal=1) "
                                           'AND EXISTS(SELECT 1 FROM @Files)\n'
                                           "            THROW 53782,N'Die native Dateimenge verletzt ihre "
                                           "Auswahl- oder Mengenbindung.',1;\n"
                                           '        UPDATE [f] SET [Partition]=CASE\n'),
                                          ('          (SELECT TOP(@MaxRows) [Ordinal] FROM @Files WHERE '
                                           "[Partition]='ELIGIBLE' ORDER BY [DatabaseId],[FileId]);\n"
                                           '        SELECT @Written=COUNT_BIG(*) FROM @Files WHERE '
                                           '[Selected]=1;\n'
                                           '        SET @Limited=CASE WHEN @Written<@Eligible THEN 1 ELSE 0 '
                                           'END;\n'
                                           '        SELECT @ValidatedIssuesJson=COALESCE((SELECT * FROM '
                                           '@Issues ORDER BY [Ordinal] FOR JSON '
                                           "PATH,INCLUDE_NULL_VALUES),N'[]');\n"
                                           '        SELECT '
                                           '@SourceValidated=1,@SourceErrorNumber=@ErrorNumberOut,@SourceErrorMessage=@ErrorMessageOut;\n'
                                           '        SET @Now=SYSUTCDATETIME();\n'
                                           '        IF @Fatal=1 AND (@Start<@Started OR @End>@Now)\n'
                                           '            SELECT '
                                           '@Start=NULL,@End=NULL,@ReadStart=NULL,@ReadEnd=NULL;\n'
                                           '        IF @Fatal=1 AND (@ReadStart<@Start OR @ReadEnd>@End OR '
                                           '@Start IS NULL)\n'
                                           '            SELECT @ReadStart=NULL,@ReadEnd=NULL;\n'
                                           '        IF @Started>@Now OR @Fatal=0 AND @End>@Now\n'
                                           "            THROW 53784,N'Die tatsächliche Targetzeit bestätigt "
                                           "keine zeitliche Abschlussbindung.',1;\n"
                                           '        IF @Fatal=1\n'
                                           '        BEGIN\n'
                                           '            SET @StatusCodeOut=@SourceStatus;\n',
                                           '          (SELECT TOP(@MaxRows) [Ordinal] FROM @Files WHERE '
                                           "[Partition]='ELIGIBLE' ORDER BY [DatabaseId],[FileId]);\n"
                                           '        SELECT @Written=COUNT_BIG(*) FROM @Files WHERE '
                                           '[Selected]=1;\n'
                                           '        SET @Limited=CASE WHEN @Written<@Eligible THEN 1 ELSE 0 '
                                           'END;\n'
                                           '        SET @Now=SYSUTCDATETIME();\n'
                                           "        IF @End>@Now OR @Started>@Now THROW 53782,N'Das "
                                           "Messfenster liegt nach der tatsächlichen Abschlussprüfung.',1;\n"
                                           '        IF @Fatal=1\n'
                                           '        BEGIN\n'
                                           '            SET @StatusCodeOut=@SourceStatus;\n'),
                                          ('        UPDATE [f] SET [ScopeId]=[s].[ScopeId] FROM @Files [f] '
                                           'JOIN [snapshot].[Scope] [s]\n'
                                           "          ON [s].[ScopeType]='FILE_IO_FILE' AND "
                                           "[s].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])) "
                                           'WHERE [Selected]=1;\n'
                                           '\n'
                                           '        SELECT TOP(1) '
                                           '@Previous=[CaptureRunId],@PreviousStatus=[StatusCode],@PreviousEnded=[EndedAtUtc] '
                                           'FROM [snapshot].[CaptureRun]\n'
                                           "          WHERE [CollectorCode]='FILE_IO' AND "
                                           '[CaptureRunId]<@CaptureRunId ORDER BY [CaptureRunId] DESC;\n'
                                           '        DECLARE @PreviousFiles TABLE([ScopeId] bigint PRIMARY '
                                           'KEY,[Json] nvarchar(max),[Identity] nvarchar(max),[Hash] '
                                           'binary(32),\n'
                                           '          [Epoch] uniqueidentifier,[DatabaseId] int,[FileId] '
                                           'int,[RawJson] nvarchar(max),[RawCount] bigint,\n'
                                           '          [ContextValid] bit DEFAULT(0),[RawValid] bit '
                                           'DEFAULT(0));\n'
                                           '        IF @Previous IS NOT NULL AND @PreviousEnded IS NOT NULL '
                                           "AND @PreviousStatus='PARTIAL'\n"
                                           '        BEGIN\n'
                                           '            SELECT @PreviousContext=[s].[StringValue] FROM '
                                           '[snapshot].[MetricSample] [s] JOIN @Metrics [m] ON '
                                           '[m].[Id]=[s].[MetricDefinitionId]\n'
                                           '              WHERE [s].[CaptureRunId]=@Previous AND '
                                           "[m].[Code]='IO_CAPTURE_CONTEXT';\n",
                                           '        UPDATE [f] SET [ScopeId]=[s].[ScopeId] FROM @Files [f] '
                                           'JOIN [snapshot].[Scope] [s]\n'
                                           "          ON [s].[ScopeType]='FILE_IO_FILE' AND "
                                           "[s].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])) "
                                           'WHERE [Selected]=1;\n'
                                           '\n'
                                           '        SELECT TOP(1) '
                                           '@Previous=[CaptureRunId],@PreviousStatus=[StatusCode] FROM '
                                           '[snapshot].[CaptureRun]\n'
                                           "          WHERE [CollectorCode]='FILE_IO' AND [EndedAtUtc] IS "
                                           'NOT NULL AND [CaptureRunId]<@CaptureRunId ORDER BY '
                                           '[CaptureRunId] DESC;\n'
                                           '        DECLARE @PreviousFiles TABLE([ScopeId] bigint PRIMARY '
                                           'KEY,[Json] nvarchar(max),[Identity] nvarchar(max),[Hash] '
                                           'binary(32),\n'
                                           '          [Epoch] uniqueidentifier,[DatabaseId] int,[FileId] '
                                           'int,[RawJson] nvarchar(max),[RawCount] bigint,\n'
                                           '          [ContextValid] bit DEFAULT(0),[RawValid] bit '
                                           'DEFAULT(0));\n'
                                           "        IF @Previous IS NOT NULL AND @PreviousStatus='PARTIAL'\n"
                                           '        BEGIN\n'
                                           '            SELECT @PreviousContext=[s].[StringValue] FROM '
                                           '[snapshot].[MetricSample] [s] JOIN @Metrics [m] ON '
                                           '[m].[Id]=[s].[MetricDefinitionId]\n'
                                           '              WHERE [s].[CaptureRunId]=@Previous AND '
                                           "[m].[Code]='IO_CAPTURE_CONTEXT';\n"),
                                          ('            SET @Comparison=CASE WHEN @Complete=0 THEN '
                                           "'SOURCE_PARTIAL'\n"
                                           '              WHEN @IdentityComplete=0 THEN '
                                           "'CURRENT_IDENTITY_INCOMPLETE'\n"
                                           "              WHEN @Previous IS NULL THEN 'NO_PREVIOUS_CAPTURE'\n"
                                           '              WHEN @PreviousEnded IS NULL THEN '
                                           "'PREVIOUS_CAPTURE_UNCONFIRMED'\n"
                                           "              WHEN @PreviousStatus<>'PARTIAL' THEN "
                                           "'PREVIOUS_CAPTURE_FAILED'\n"
                                           '              WHEN @PreviousValid=0 THEN '
                                           "'PREVIOUS_CAPTURE_CONTEXT_INVALID'\n"
                                           '              WHEN '
                                           "JSON_VALUE(@PreviousContext,'$.capture.sourceComplete')<>'true' "
                                           "THEN 'PREVIOUS_SOURCE_PARTIAL'\n",
                                           '            SET @Comparison=CASE WHEN @Complete=0 THEN '
                                           "'SOURCE_PARTIAL'\n"
                                           '              WHEN @IdentityComplete=0 THEN '
                                           "'CURRENT_IDENTITY_INCOMPLETE'\n"
                                           "              WHEN @Previous IS NULL THEN 'NO_PREVIOUS_CAPTURE'\n"
                                           "              WHEN @PreviousStatus<>'PARTIAL' THEN "
                                           "'PREVIOUS_CAPTURE_FAILED'\n"
                                           '              WHEN @PreviousValid=0 THEN '
                                           "'PREVIOUS_CAPTURE_CONTEXT_INVALID'\n"
                                           '              WHEN '
                                           "JSON_VALUE(@PreviousContext,'$.capture.sourceComplete')<>'true' "
                                           "THEN 'PREVIOUS_SOURCE_PARTIAL'\n"),
                                          ('            '
                                           "VALUES(@CaptureRunId,N'SnapshotFileIO',COALESCE(@End,SYSUTCDATETIME()),'JSON',1,'GZIP',\n"
                                           '              '
                                           "HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);\n"
                                           '        DECLARE @IssueOrdinal int,@SourceModule '
                                           'sysname,@IssueStatus varchar(40),@IssueError int,@IssueMessage '
                                           'nvarchar(2048),\n'
                                           '          @PersistSourceModule sysname,@PersistContextModule '
                                           'sysname,\n'
                                           '          @Evidence nvarchar(1000),@ScopeType '
                                           'varchar(16),@IssueDB int,@IssueFile int,@IssueName '
                                           'sysname,@ModuleId bigint,@IssueContext nvarchar(max);\n'
                                           '        DECLARE [SourceIssues] CURSOR LOCAL FAST_FORWARD FOR '
                                           'SELECT '
                                           '[Ordinal],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],\n'
                                           '          '
                                           '[EvidenceLimit],[ScopeType],[DatabaseId],[FileId],[DatabaseName] '
                                           'FROM @Issues ORDER BY [Ordinal];\n',
                                           '            '
                                           "VALUES(@CaptureRunId,N'SnapshotFileIO',COALESCE(@End,SYSUTCDATETIME()),'JSON',1,'GZIP',\n"
                                           '              '
                                           "HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);\n"
                                           '        DECLARE @IssueOrdinal int,@SourceModule '
                                           'sysname,@IssueStatus varchar(40),@IssueError int,@IssueMessage '
                                           'nvarchar(2048),\n'
                                           '          @Evidence nvarchar(1000),@ScopeType '
                                           'varchar(16),@IssueDB int,@IssueFile int,@IssueName '
                                           'sysname,@ModuleId bigint,@IssueContext nvarchar(max);\n'
                                           '        DECLARE [SourceIssues] CURSOR LOCAL FAST_FORWARD FOR '
                                           'SELECT '
                                           '[Ordinal],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],\n'
                                           '          '
                                           '[EvidenceLimit],[ScopeType],[DatabaseId],[FileId],[DatabaseName] '
                                           'FROM @Issues ORDER BY [Ordinal];\n'),
                                          ('        FETCH NEXT FROM [SourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '        WHILE @@FETCH_STATUS=0\n'
                                           '        BEGIN\n'
                                           '            SELECT @PersistSourceModule=CASE WHEN EXISTS(SELECT '
                                           '1 FROM @Issues WHERE [SourceName]=@SourceModule AND '
                                           '[Ordinal]<@IssueOrdinal)\n'
                                           '              THEN '
                                           "CONVERT(sysname,CONCAT(@SourceModule,N'#',@IssueOrdinal)) ELSE "
                                           '@SourceModule END,\n'
                                           '              @PersistContextModule=CASE WHEN @IssueOrdinal=0 '
                                           "THEN N'FileIOSourceIssueContext' ELSE "
                                           "CONVERT(sysname,CONCAT(N'FileIOSourceIssueContext#',@IssueOrdinal)) "
                                           'END;\n'
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            '
                                           'VALUES(@CaptureRunId,@PersistSourceModule,COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,@IssueError,@IssueMessage,@Evidence);\n'
                                           '            SET @ModuleId=CONVERT(bigint,SCOPE_IDENTITY());\n'
                                           '            SELECT @IssueContext=(SELECT '
                                           'CONVERT(varchar(20),@ModuleId) AS '
                                           '[sourceModuleStatusId],@ScopeType AS [ScopeType],@IssueDB AS '
                                           '[DatabaseId],\n'
                                           '              @IssueFile AS [FileId],@IssueName AS '
                                           '[DatabaseName],@IssueStatus AS [StatusCode] FOR JSON '
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           "            IF DATALENGTH(@IssueContext)>4096 THROW 53784,N'Der "
                                           "gebundene Issuekontext überschreitet sein Meldungslimit.',1;\n"
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            '
                                           'VALUES(@CaptureRunId,@PersistContextModule,COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,NULL,@IssueContext,NULL);\n'
                                           '            FETCH NEXT FROM [SourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '        END;\n'
                                           '        CLOSE [SourceIssues]; DEALLOCATE [SourceIssues];\n',
                                           '        FETCH NEXT FROM [SourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '        WHILE @@FETCH_STATUS=0\n'
                                           '        BEGIN\n'
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            '
                                           'VALUES(@CaptureRunId,@SourceModule,COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,@IssueError,@IssueMessage,@Evidence);\n'
                                           '            SET @ModuleId=CONVERT(bigint,SCOPE_IDENTITY());\n'
                                           '            SELECT @IssueContext=(SELECT '
                                           'CONVERT(varchar(20),@ModuleId) AS '
                                           '[sourceModuleStatusId],@ScopeType AS [ScopeType],@IssueDB AS '
                                           '[DatabaseId],\n'
                                           '              @IssueFile AS [FileId],@IssueName AS '
                                           '[DatabaseName],@IssueStatus AS [StatusCode] FOR JSON '
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           "            IF DATALENGTH(@IssueContext)>4096 THROW 53784,N'Der "
                                           "gebundene Issuekontext überschreitet sein Meldungslimit.',1;\n"
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            '
                                           "VALUES(@CaptureRunId,N'FileIOSourceIssueContext',COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,NULL,@IssueContext,NULL);\n"
                                           '            FETCH NEXT FROM [SourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '        END;\n'
                                           '        CLOSE [SourceIssues]; DEALLOCATE [SourceIssues];\n'),
                                          ('        COMMIT TRANSACTION;\n'
                                           '    END TRY\n'
                                           '    BEGIN CATCH\n'
                                           '        DECLARE @Failure int=ERROR_NUMBER(),@FailureMessage '
                                           'nvarchar(2048)=ERROR_MESSAGE(),\n'
                                           '                @FailureModuleId bigint,@Recorded '
                                           'datetime2(3),@Confirmed bit,@Boundary nvarchar(max);\n'
                                           '        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n'
                                           '        SELECT @StatusCodeOut=CASE WHEN @Failure '
                                           "IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'\n"
                                           '          WHEN @Failure IN(53781,53764,2812,8144,8145) THEN '
                                           "'TARGET_UNAVAILABLE'\n"
                                           '          WHEN @OwnRun=0 AND @Failure=53783 THEN '
                                           "'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,\n"
                                           '          @IsPartialOut=1,@ErrorNumberOut=CASE WHEN @OwnRun=0 '
                                           'AND @Failure=53783 THEN 51011 ELSE @Failure END,\n'
                                           '          @ErrorMessageOut=@FailureMessage;\n'
                                           '        IF @OwnRun=1\n'
                                           '        BEGIN TRY\n'
                                           '            IF DB_ID()<>@ExpectedTargetDatabaseId OR NOT '
                                           'EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)\n'
                                           '              WHERE [database_id]=@ExpectedTargetDatabaseId AND '
                                           '[create_date]=@ExpectedTargetCreateDate\n'
                                           '                AND '
                                           'CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName) '
                                           'AND [state]=0 AND [is_read_only]=0)\n'
                                           "                THROW 53764,N'Die Fehlerfinalisierung kann die "
                                           "gebundene Targetidentität nicht bestätigen.',1;\n"
                                           '            BEGIN TRANSACTION;\n'
                                           '            IF NOT EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] '
                                           'WITH (UPDLOCK,HOLDLOCK) WHERE [CaptureRunId]=@CaptureRunId\n'
                                           "              AND [CollectorCode]='FILE_IO' AND "
                                           "[StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL\n"
                                           '              AND [StartedAtUtc]=@Started AND '
                                           'CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@SourceName))\n'
                                           '              OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] '
                                           'WHERE [CaptureRunId]=@CaptureRunId)\n'
                                           '              OR EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] '
                                           'WHERE [CaptureRunId]=@CaptureRunId)\n'
                                           '              OR EXISTS(SELECT 1 FROM '
                                           '[snapshot].[PayloadSnapshot] WHERE '
                                           '[CaptureRunId]=@CaptureRunId)\n'
                                           "                THROW 53784,N'Die Fehlerfinalisierung bestätigt "
                                           "keinen unveränderten eigenen Lauf.',1;\n"
                                           '            SELECT @Recorded=SYSUTCDATETIME();\n'
                                           '            SET @Confirmed=CASE WHEN @Recorded>=@Started THEN 1 '
                                           'ELSE 0 END;\n'
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            VALUES(@CaptureRunId,CASE WHEN @SourceValidated=0 '
                                           "AND @Failure=53782 THEN N'SOURCE_CONTRACT'\n"
                                           "                   ELSE N'snapshot.InternalCompleteFileIOCycle' "
                                           "END,@Recorded,'ERROR_HANDLED',1,@Failure,@FailureMessage,\n"
                                           "              N'Die Fachwrites wurden zurückgerollt; keine "
                                           "numerische Aufnahme wird behauptet.');\n"
                                           '            SET '
                                           '@FailureModuleId=CONVERT(bigint,SCOPE_IDENTITY());\n'
                                           '            IF @SourceValidated=1\n'
                                           '            BEGIN\n'
                                           '                DELETE @Issues;\n'
                                           '                INSERT '
                                           '@Issues([Ordinal],[ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '                SELECT '
                                           '[Ordinal],[ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit]\n'
                                           '                FROM OPENJSON(@ValidatedIssuesJson) WITH\n'
                                           '                 ([Ordinal] int,[ScopeType] '
                                           'varchar(16),[SourceName] nvarchar(128),[DatabaseId] int,[FileId] '
                                           'int,[DatabaseName] nvarchar(128),\n'
                                           '                  [StatusCode] varchar(40),[ErrorNumber] '
                                           'int,[ErrorMessage] nvarchar(2048),[EvidenceLimit] '
                                           'nvarchar(1000));\n'
                                           '                DECLARE [FailureSourceIssues] CURSOR LOCAL '
                                           'FAST_FORWARD FOR\n'
                                           '                SELECT '
                                           '[Ordinal],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit],[ScopeType],[DatabaseId],[FileId],[DatabaseName]\n'
                                           '                FROM @Issues ORDER BY [Ordinal];\n'
                                           '                OPEN [FailureSourceIssues];\n'
                                           '                FETCH NEXT FROM [FailureSourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '                WHILE @@FETCH_STATUS=0\n'
                                           '                BEGIN\n'
                                           '                    SELECT @PersistSourceModule=CASE WHEN '
                                           'EXISTS(SELECT 1 FROM @Issues WHERE [SourceName]=@SourceModule '
                                           'AND [Ordinal]<@IssueOrdinal)\n'
                                           '                      THEN '
                                           "CONVERT(sysname,CONCAT(@SourceModule,N'#',@IssueOrdinal)) ELSE "
                                           '@SourceModule END,\n'
                                           '                      @PersistContextModule=CASE WHEN '
                                           "@IssueOrdinal=0 THEN N'FileIOSourceIssueContext' ELSE "
                                           "CONVERT(sysname,CONCAT(N'FileIOSourceIssueContext#',@IssueOrdinal)) "
                                           'END;\n'
                                           '                    INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '                    '
                                           'VALUES(@CaptureRunId,@PersistSourceModule,@Recorded,@IssueStatus,1,@IssueError,@IssueMessage,@Evidence);\n'
                                           '                    SET '
                                           '@ModuleId=CONVERT(bigint,SCOPE_IDENTITY());\n'
                                           '                    SELECT @IssueContext=(SELECT '
                                           'CONVERT(varchar(20),@ModuleId) AS '
                                           '[sourceModuleStatusId],@ScopeType AS [ScopeType],@IssueDB AS '
                                           '[DatabaseId],\n'
                                           '                      @IssueFile AS [FileId],@IssueName AS '
                                           '[DatabaseName],@IssueStatus AS [StatusCode] FOR JSON '
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           '                    INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '                    '
                                           'VALUES(@CaptureRunId,@PersistContextModule,@Recorded,@IssueStatus,1,NULL,@IssueContext,NULL);\n'
                                           '                    FETCH NEXT FROM [FailureSourceIssues] INTO '
                                           '@IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;\n'
                                           '                END;\n'
                                           '                CLOSE [FailureSourceIssues]; DEALLOCATE '
                                           '[FailureSourceIssues];\n'
                                           '            END\n'
                                           '            ELSE IF @Failure=53782\n'
                                           '            BEGIN\n'
                                           '                SELECT @IssueContext=(SELECT '
                                           'CONVERT(varchar(20),@FailureModuleId) AS '
                                           "[sourceModuleStatusId],'SOURCE' AS [ScopeType],\n"
                                           '                  CONVERT(int,NULL) AS '
                                           '[DatabaseId],CONVERT(int,NULL) AS '
                                           '[FileId],CONVERT(nvarchar(128),NULL) AS [DatabaseName],\n'
                                           "                  'ERROR_HANDLED' AS [StatusCode] FOR JSON "
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           '                INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorMessage])\n'
                                           '                '
                                           "VALUES(@CaptureRunId,N'FileIOSourceIssueContext',@Recorded,'ERROR_HANDLED',1,@IssueContext);\n"
                                           '            END;\n'
                                           '            INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '            '
                                           "VALUES(@CaptureRunId,N'FileIOCollector',@Recorded,'ERROR_HANDLED',1,NULL,\n"
                                           '              CASE WHEN @SourceValidated=1 THEN '
                                           '@SourceErrorMessage ELSE @FailureMessage END,\n'
                                           "              N'Der Targetabschluss enthält keine numerischen "
                                           "Samples; die Quelldiagnose bleibt getrennt erhalten.');\n"
                                           '            IF @Confirmed=0\n'
                                           '            BEGIN\n'
                                           '                SELECT @Boundary=(SELECT 1 AS '
                                           '[schemaVersion],CONVERT(varchar(20),@CaptureRunId) AS '
                                           '[captureRunId],\n'
                                           '                  CONVERT(varchar(20),@FailureModuleId) AS '
                                           "[failureModuleStatusId],'FINALIZATION_UNCONFIRMED' AS "
                                           '[statusCode],\n'
                                           '                  '
                                           "CONVERT(nvarchar(19),@Started,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@Started)),3)+N'Z' "
                                           'AS [startedAtUtc],\n'
                                           '                  '
                                           "CONVERT(nvarchar(19),@Recorded,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@Recorded)),3)+N'Z' "
                                           'AS [recordedAtUtc],\n'
                                           '                  @SourceValidated AS '
                                           '[sourceIssuesPreserved],CONVERT(bit,0) AS '
                                           '[finalizationConfirmed]\n'
                                           '                  FOR JSON '
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           '                INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage])\n'
                                           '                '
                                           "VALUES(@CaptureRunId,N'FileIOFinalizationBoundary',@Recorded,'FINALIZATION_UNCONFIRMED',1,NULL,@Boundary);\n"
                                           '            END;\n'
                                           '            UPDATE [snapshot].[CaptureRun] SET [EndedAtUtc]=CASE '
                                           'WHEN @Confirmed=1 THEN @Recorded END,\n'
                                           '              '
                                           "[ResetEpochId]=NULL,[SqlServerStartTimeUtc]=NULL,[StatusCode]='ERROR_HANDLED',[IsPartial]=1,\n"
                                           '              [ErrorNumber]=CASE WHEN @SourceValidated=1 THEN '
                                           '@SourceErrorNumber ELSE @Failure END,\n'
                                           '              [ErrorMessage]=CASE WHEN @SourceValidated=1 THEN '
                                           '@SourceErrorMessage ELSE @FailureMessage '
                                           'END,[MetricSampleCount]=0,[PayloadCount]=0\n'
                                           '            WHERE [CaptureRunId]=@CaptureRunId AND '
                                           "[StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL;\n"
                                           "            IF @@ROWCOUNT<>1 THROW 53784,N'Der eigene "
                                           "Fehlerabschluss wurde nicht bestätigt.',1;\n"
                                           '            COMMIT TRANSACTION;\n'
                                           '            SELECT @StatusCodeOut=CASE WHEN @Confirmed=1 THEN '
                                           "'ERROR_HANDLED' ELSE 'FINALIZATION_UNCONFIRMED' END,\n"
                                           '              @ErrorNumberOut=CASE WHEN @SourceValidated=1 THEN '
                                           '@SourceErrorNumber ELSE @Failure END,\n'
                                           '              @ErrorMessageOut=CASE WHEN @SourceValidated=1 THEN '
                                           '@SourceErrorMessage ELSE @FailureMessage END;\n'
                                           '        END TRY\n'
                                           '        BEGIN CATCH\n'
                                           '            SELECT '
                                           "@StatusCodeOut='FINALIZATION_UNCONFIRMED',@IsPartialOut=1,\n"
                                           '              '
                                           '@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());\n'
                                           '            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n'
                                           '        END CATCH;\n'
                                           '        IF @OwnRun=0 AND @Failure=53783 RETURN 51011;\n'
                                           '    END CATCH;\n',
                                           '        COMMIT TRANSACTION;\n'
                                           '    END TRY\n'
                                           '    BEGIN CATCH\n'
                                           '        DECLARE @Failure int=ERROR_NUMBER(),@FailureMessage '
                                           'nvarchar(2048)=ERROR_MESSAGE();\n'
                                           '        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n'
                                           '        SELECT @StatusCodeOut=CASE WHEN @Failure '
                                           "IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'\n"
                                           '          WHEN @Failure IN(53781,53764,2812,8144,8145) THEN '
                                           "'TARGET_UNAVAILABLE' WHEN @OwnRun=0 AND @Failure=53783 THEN "
                                           "'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,\n"
                                           '          @IsPartialOut=1,@ErrorNumberOut=CASE WHEN @OwnRun=0 '
                                           'AND @Failure=53783 THEN 51011 ELSE @Failure '
                                           'END,@ErrorMessageOut=@FailureMessage;\n'
                                           '        IF @OwnRun=1 AND DB_ID()=@ExpectedTargetDatabaseId AND '
                                           'EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)\n'
                                           '          WHERE [database_id]=@ExpectedTargetDatabaseId AND '
                                           '[create_date]=@ExpectedTargetCreateDate\n'
                                           '            AND '
                                           'CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName) '
                                           'AND [state]=0 AND [is_read_only]=0)\n'
                                           '        BEGIN TRY\n'
                                           '            BEGIN TRANSACTION;\n'
                                           '            IF EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] WITH '
                                           '(UPDLOCK,HOLDLOCK) WHERE [CaptureRunId]=@CaptureRunId\n'
                                           "              AND [CollectorCode]='FILE_IO' AND "
                                           "[StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL)\n"
                                           '              AND NOT EXISTS(SELECT 1 FROM '
                                           '[snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)\n'
                                           '              AND NOT EXISTS(SELECT 1 FROM '
                                           '[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)\n'
                                           '              AND NOT EXISTS(SELECT 1 FROM '
                                           '[snapshot].[PayloadSnapshot] WHERE '
                                           '[CaptureRunId]=@CaptureRunId)\n'
                                           '            BEGIN\n'
                                           '                INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])\n'
                                           '                VALUES(@CaptureRunId,CASE WHEN @Failure=53782 '
                                           "THEN N'SOURCE_CONTRACT' ELSE N'FileIOCollector' "
                                           'END,SYSUTCDATETIME(),@StatusCodeOut,1,\n'
                                           "                  @ErrorNumberOut,@ErrorMessageOut,N'Die "
                                           'Fachwrites wurden zurückgerollt; keine numerische Aufnahme wird '
                                           "behauptet.');\n"
                                           '                SET @ModuleId=CONVERT(bigint,SCOPE_IDENTITY());\n'
                                           '                IF @Failure=53782\n'
                                           '                BEGIN\n'
                                           '                    SELECT @IssueContext=(SELECT '
                                           'CONVERT(varchar(20),@ModuleId) AS '
                                           "[sourceModuleStatusId],'SOURCE' AS [ScopeType],\n"
                                           '                      CONVERT(int,NULL) AS '
                                           '[DatabaseId],CONVERT(int,NULL) AS '
                                           '[FileId],CONVERT(nvarchar(128),NULL) AS [DatabaseName],\n'
                                           '                      @StatusCodeOut AS [StatusCode] FOR JSON '
                                           'PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);\n'
                                           '                    INSERT '
                                           '[snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorMessage])\n'
                                           '                    '
                                           "VALUES(@CaptureRunId,N'FileIOSourceIssueContext',SYSUTCDATETIME(),@StatusCodeOut,1,@IssueContext),\n"
                                           '                          '
                                           "(@CaptureRunId,N'FileIOCollector',SYSUTCDATETIME(),@StatusCodeOut,1,@ErrorMessageOut);\n"
                                           '                END;\n'
                                           '                UPDATE [snapshot].[CaptureRun] SET '
                                           '[EndedAtUtc]=SYSUTCDATETIME(),[ResetEpochId]=NULL,[SqlServerStartTimeUtc]=NULL,\n'
                                           '                  '
                                           '[StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,[MetricSampleCount]=0,[PayloadCount]=0\n'
                                           '                  WHERE [CaptureRunId]=@CaptureRunId AND '
                                           "[StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL;\n"
                                           '            END;\n'
                                           '            COMMIT TRANSACTION;\n'
                                           '        END TRY\n'
                                           '        BEGIN CATCH\n'
                                           '            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n'
                                           "            SET @ErrorMessageOut=LEFT(CONCAT(@FailureMessage,N' "
                                           "Fehlerfinalisierung nicht bestätigt: ',ERROR_MESSAGE()),2048);\n"
                                           '        END CATCH;\n'
                                           '        IF @OwnRun=0 AND @Failure=53783 RETURN 51011;\n'
                                           '    END CATCH;\n')]),
 '070_InternalPurgeExpiredData.sql': ('64c209d09b29a72837af3d64d9b1e479d8cd92769f6ca0579a43406896d11a2d',
                                      [('    SET NOCOUNT ON;\n'
                                        '    SET LOCK_TIMEOUT 0;\n'
                                        '    SET @RetentionContractVersionOut=CASE WHEN EXISTS(SELECT 1 FROM '
                                        '[snapshot].[PackageVersion] WITH (NOLOCK)\n'
                                        '      WHERE [SchemaVersion]=3 AND [PackageVersion] '
                                        "IN('1.2.2','1.3.0','1.3.1')) THEN 3 ELSE 1 END;\n"
                                        '    -- The handshake reads only the admitted version and creates no '
                                        'purge receipt.\n'
                                        '    IF @ContractOnly=1 RETURN;\n'
                                        '\n',
                                        '    SET NOCOUNT ON;\n'
                                        '    SET LOCK_TIMEOUT 0;\n'
                                        '    SET @RetentionContractVersionOut=CASE WHEN EXISTS(SELECT 1 FROM '
                                        '[snapshot].[PackageVersion] WITH (NOLOCK)\n'
                                        '      WHERE [SchemaVersion]=3 AND [PackageVersion] '
                                        "IN('1.2.2','1.3.0')) THEN 2 ELSE 1 END;\n"
                                        '    -- The handshake reads only the admitted version and creates no '
                                        'purge receipt.\n'
                                        '    IF @ContractOnly=1 RETURN;\n'
                                        '\n'),
                                       ('              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[MetricSample] AS [m] WHERE '
                                        '[m].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[PayloadSnapshot] AS [p] WHERE '
                                        '[p].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[ModuleStatus] AS [s] WHERE '
                                        '[s].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              -- Waits retain their latest finalized run. File I/O '
                                        'retains its latest\n'
                                        '              -- run even when finalization is unconfirmed or '
                                        'children are absent.\n'
                                        '              AND\n'
                                        '              (\n'
                                        '                  [r].[CollectorCode] NOT '
                                        "IN('WAIT_STATS','FILE_IO')\n"
                                        "                  OR ([r].[CollectorCode]='WAIT_STATS' AND "
                                        '[r].[EndedAtUtc] IS NULL)\n'
                                        '                  OR EXISTS\n'
                                        '                  (\n'
                                        '                      SELECT 1 FROM [snapshot].[CaptureRun] AS '
                                        '[later]\n'
                                        '                      WHERE '
                                        '[later].[CollectorCode]=[r].[CollectorCode]\n'
                                        "                        AND ([r].[CollectorCode]='FILE_IO' OR "
                                        '[later].[EndedAtUtc] IS NOT NULL)\n'
                                        '                        AND '
                                        '[later].[CaptureRunId]>[r].[CaptureRunId]\n'
                                        '                  )\n'
                                        '              );\n',
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[MetricSample] AS [m] WHERE '
                                        '[m].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[PayloadSnapshot] AS [p] WHERE '
                                        '[p].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              AND NOT EXISTS (SELECT 1 FROM '
                                        '[snapshot].[ModuleStatus] AS [s] WHERE '
                                        '[s].[CaptureRunId]=[r].[CaptureRunId])\n'
                                        '              -- Preserve the latest finalized Wait run as the '
                                        'comparison fence,\n'
                                        '              -- including a failed run whose children have expired '
                                        'or never existed.\n'
                                        '              AND\n'
                                        '              (\n'
                                        '                  [r].[CollectorCode] NOT '
                                        "IN('WAIT_STATS','FILE_IO')\n"
                                        '                  OR [r].[EndedAtUtc] IS NULL\n'
                                        '                  OR EXISTS\n'
                                        '                  (\n'
                                        '                      SELECT 1 FROM [snapshot].[CaptureRun] AS '
                                        '[later]\n'
                                        '                      WHERE '
                                        '[later].[CollectorCode]=[r].[CollectorCode]\n'
                                        '                        AND [later].[EndedAtUtc] IS NOT NULL\n'
                                        '                        AND '
                                        '[later].[CaptureRunId]>[r].[CaptureRunId]\n'
                                        '                  )\n'
                                        '              );\n')])}

FILE_IO_METRIC_CODES = ('IO_READ_COUNT', 'IO_READ_BYTES', 'IO_READ_STALL_MS', 'IO_WRITE_COUNT', 'IO_WRITE_BYTES', 'IO_WRITE_STALL_MS', 'IO_SIZE_ON_DISK_BYTES', 'IO_READ_COUNT_DELTA_CANDIDATE', 'IO_READ_BYTES_DELTA_CANDIDATE', 'IO_READ_STALL_MS_DELTA_CANDIDATE', 'IO_WRITE_COUNT_DELTA_CANDIDATE', 'IO_WRITE_BYTES_DELTA_CANDIDATE', 'IO_WRITE_STALL_MS_DELTA_CANDIDATE', 'IO_DELTA_STATUS', 'IO_FILE_CONTEXT', 'IO_CAPTURE_CONTEXT')

def snapshot_schema_cases(deployed, tables):
    """Preserve actual old module/data contracts across all canonical routes."""
    target_tables=[t for t in tables if t.role=='SNAPSHOT']
    schema=(ROOT/g.SNAPSHOT_SCHEMA_SOURCE).read_text(encoding='utf-8-sig')
    direct='\n'.join(g.split_batches(schema))
    standalone,_=g.generate_snapshot_target(ROOT)
    routes=[('DIRECT',direct),('STANDALONE',standalone),('COMBINED',deployed)]
    target_sources,_,_=g.load_sources(ROOT,True)
    current={Path(source.path).name: (ROOT/source.path).read_text(encoding='utf-8-sig')
             for source in target_sources if source.role=='SNAPSHOT'}
    direct_patch=''.join('EXEC sys.sp_executesql '+g.lit(batch)+';\n'
                         for text in current.values() for batch in g.split_batches(text))
    historical={}
    for name,(digest,text) in LEGACY_TARGET_V1_1_1.items():
        text=text.replace('\r\n','\n')
        if hashlib.sha256(text.encode()).hexdigest()!=digest:
            raise RuntimeError('Historical Snapshot helper binding changed: '+name)
        historical[name]=text
    historical_new={}
    for name,(digest,text) in LEGACY_TARGET_V1_2_0.items():
        text=text.replace('\r\n','\n')
        if hashlib.sha256(text.encode()).hexdigest()!=digest:
            raise RuntimeError('Historical Snapshot 1.2.0 helper binding changed: '+name)
        historical_new[name]=text
    old_wait=g.stored_module_definition(g.split_batches(historical_new['055_InternalCompleteWaitStatsCycle.sql'])[0])
    if hashlib.sha256(old_wait.encode('utf-16le')).hexdigest()!='e392b9581c55955b81674e468aa88eac444339585dfd787a682abf66b3a48c49':
        raise RuntimeError('Released Wait recovery hash does not bind the actual 1.2.0 fixture')
    historical_ready={}
    for name,(digest,patches) in LEGACY_TARGET_V1_2_1_PATCHES.items():
        text=current[name]
        for fragment,released in patches:
            if text.count(fragment)!=1: raise RuntimeError('Released1.2.1 fixture fragment changed: '+name)
            text=text.replace(fragment,released,1)
        if hashlib.sha256(text.encode()).hexdigest()!=digest: raise RuntimeError('Released1.2.1 byte binding changed: '+name)
        historical_ready[name]=text
    ready_wait=g.stored_module_definition(g.split_batches(historical_ready['055_InternalCompleteWaitStatsCycle.sql'])[0])
    if hashlib.sha256(ready_wait.encode('utf-16le')).hexdigest()!='aeb295d67a15ce0fcf452404dde233729012e42340c138c8924f27447e1b8762':
        raise RuntimeError('Released1.2.1 stored helper binding changed')
    historical_file_io={}
    for name,(digest,patches) in LEGACY_TARGET_V1_3_0_PATCHES.items():
        text=current[name]
        for fragment,released in patches:
            if text.count(fragment)!=1: raise RuntimeError('Released1.3.0 fixture fragment changed: '+name)
            text=text.replace(fragment,released,1)
        if hashlib.sha256(text.encode()).hexdigest()!=digest: raise RuntimeError('Released1.3.0 byte binding changed: '+name)
        historical_file_io[name]=text
    for name,digest in (('055_InternalCompleteWaitStatsCycle.sql','86272875a1bb5052072b6106d2845658c2fea26414820ef0f0c018a8b88c7c40'),
                        ('057_InternalCompleteFileIOCycle.sql','5a2846e5b919adb69eae95cc4869f5a43b4b69b0b7fe57192a0a0dc002cee592')):
        definition=g.stored_module_definition(g.split_batches(historical_file_io[name])[0])
        if hashlib.sha256(definition.encode('utf-16le')).hexdigest()!=digest:
            raise RuntimeError('Released1.3.0 stored helper binding changed: '+name)
    legacy=LEGACY_PURGE_V1_1_0.replace('\r\n','\n')
    if hashlib.sha256(legacy.encode()).hexdigest()!=LEGACY_PURGE_V1_1_0_SHA256:
        raise RuntimeError('Historical Snapshot 1.1.0 Purge fixture binding changed')
    metrics=('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_SIGNAL_TIME_MS','WAIT_MAX_TIME_MS',
             'WAIT_TASK_COUNT_DELTA_CANDIDATE','WAIT_TIME_MS_DELTA_CANDIDATE',
             'WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE','WAIT_DELTA_STATUS','WAIT_CAPTURE_CONTEXT')
    metric_list=','.join(g.lit(x) for x in metrics)

    def shape(version):
        out=[]
        for table in target_tables:
            if table.name not in g.SNAPSHOT_LEGACY_CHECKS: continue
            new,old=g.SNAPSHOT_LEGACY_CHECKS[table.name]
            cname=next(n for n,k in table.constraints if k=='CHECK' and n in
                       ('CK_snapshot_CollectorPolicy_CollectorCode','CK_snapshot_Scope_ScopeType'))
            out.append(f'ALTER TABLE {table.object_name} DROP CONSTRAINT {g.q(cname)};\n'
                       f'ALTER TABLE {table.object_name} WITH CHECK ADD CONSTRAINT {g.q(cname)} {old if version==1 else g.SNAPSHOT_SCHEMA2_CHECKS[table.name]};\n')
        out.append("UPDATE snapshot.PackageVersion SET PackageVersion="+g.lit('1.0.0' if version==1 else '1.1.1')+
                   f",SchemaVersion={version} WHERE PackageCode='SC-023';\n")
        return ''.join(out)

    def arrange_old(version):
        if version in ('1.2.0','1.2.1','1.3.0'):
            # Preserve installed Wait definitions, identities and custom values.
            out=["UPDATE snapshot.CollectorPolicy SET IsEnabled=1,PayloadEnabled=1,MaxRows=123,RetentionPolicyCode=COALESCE((SELECT TOP(1) RetentionPolicyCode FROM snapshot.RetentionPolicy WHERE IsFrameworkDefault=0 ORDER BY RetentionPolicyCode),'DEFAULT') WHERE CollectorCode='WAIT_STATS';\n",
                 "UPDATE snapshot.MetricDefinition SET Description=N'Example existing Wait definition',IsFrameworkDefault=0,SeedVersion=2 WHERE MetricCode='WAIT_TIME_MS';\n"]
            selected=historical_file_io if version=='1.3.0' else historical_new if version=='1.2.0' else historical_ready
            if version=='1.3.0':
                out.append("UPDATE snapshot.CollectorPolicy SET IsEnabled=1,PayloadEnabled=1,MaxRows=123,CollectionIntervalSeconds=77,SeedVersion=42 WHERE CollectorCode='FILE_IO';\nUPDATE snapshot.MetricDefinition SET Description=N'Example released file I/O Ä漢字  ',IsFrameworkDefault=0,SeedVersion=3 WHERE MetricCode='IO_READ_COUNT';\n")
        else:
            out=[f"IF EXISTS(SELECT 1 FROM snapshot.MetricSample s JOIN snapshot.MetricDefinition d ON d.MetricDefinitionId=s.MetricDefinitionId WHERE d.MetricCode IN({metric_list})) THROW 53826,N'Historical fixture owns no Wait samples.',1;\n",
                 f'DELETE snapshot.MetricDefinition WHERE MetricCode IN({metric_list});\n',
                 "DELETE snapshot.CollectorPolicy WHERE CollectorCode='WAIT_STATS';\n",
                 'DROP PROCEDURE IF EXISTS snapshot.InternalCompleteWaitStatsCycle;\n']
            selected=historical
        if version!='1.3.0':
            out.insert(0,"IF EXISTS(SELECT 1 FROM snapshot.MetricSample s JOIN snapshot.MetricDefinition d ON d.MetricDefinitionId=s.MetricDefinitionId WHERE d.MetricCode LIKE 'IO[_]%') THROW 53826,N'Historical fixture owns no file-I/O samples.',1;\nDELETE snapshot.MetricDefinition WHERE MetricCode LIKE 'IO[_]%'; DELETE snapshot.CollectorPolicy WHERE CollectorCode='FILE_IO'; DROP PROCEDURE IF EXISTS snapshot.InternalCompleteFileIOCycle;\n")
        for name,text in selected.items():
            if version in ('1.0.0','1.1.0') and name.startswith('070_'): text=legacy
            out += ['EXEC sys.sp_executesql '+g.lit(batch)+';\n' for batch in g.split_batches(text)]
        if version!='1.3.0': out.append(shape(1 if version=='1.0.0' else 2))
        out.append('UPDATE snapshot.PackageVersion SET PackageVersion='+g.lit(version)+';\nGO\n')
        if version=='1.2.1':
            out.append("IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'snapshot.InternalCompleteWaitStatsCycle')),NCHAR(13)+NCHAR(10),NCHAR(10)))))<>0xaeb295d67a15ce0fcf452404dde233729012e42340c138c8924f27447e1b8762 THROW 53826,N'Released1.2.1 native stored binding differs.',1;\n")
            out.append("DECLARE @OldId int,@OldCreated datetime,@OldStatus varchar(40),@OldError int,@OldMessage nvarchar(2048); EXEC "+g.q(FRAMEWORK)+".monitor.InternalValidateSnapshotWaitTarget @TargetDatabaseName="+g.lit(TARGET)+",@TargetDatabaseIdOut=@OldId OUTPUT,@TargetCreateDateOut=@OldCreated OUTPUT,@StatusCodeOut=@OldStatus OUTPUT,@ErrorNumberOut=@OldError OUTPUT,@ErrorMessageOut=@OldMessage OUTPUT; IF COALESCE(@OldStatus,'')<>'AVAILABLE' OR @OldError IS NOT NULL OR @OldId<>DB_ID() THROW 53826,N'New framework rejected actual complete old1.2.1 Wait target.',1;\nGO\n")
        if version=='1.3.0':
            for name,digest in (('InternalCompleteWaitStatsCycle','86272875a1bb5052072b6106d2845658c2fea26414820ef0f0c018a8b88c7c40'),
                                ('InternalCompleteFileIOCycle','5a2846e5b919adb69eae95cc4869f5a43b4b69b0b7fe57192a0a0dc002cee592')):
                out.append("IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'snapshot."+name+"')),NCHAR(13)+NCHAR(10),NCHAR(10)))))<>0x"+digest+" THROW 53826,N'Released1.3.0 native stored binding differs.',1;\n")
            out.append("DECLARE @OldId int,@OldCreated datetime,@OldStatus varchar(40),@OldError int,@OldMessage nvarchar(2048); EXEC "+g.q(FRAMEWORK)+".monitor.InternalValidateSnapshotWaitTarget @TargetDatabaseName="+g.lit(TARGET)+",@TargetDatabaseIdOut=@OldId OUTPUT,@TargetCreateDateOut=@OldCreated OUTPUT,@StatusCodeOut=@OldStatus OUTPUT,@ErrorNumberOut=@OldError OUTPUT,@ErrorMessageOut=@OldMessage OUTPUT; IF COALESCE(@OldStatus,'')<>'AVAILABLE' OR @OldError IS NOT NULL OR @OldId<>DB_ID() THROW 53826,N'New framework rejected actual complete old1.3.0 Wait target.',1;\n")
            out.append("EXEC "+g.q(FRAMEWORK)+".monitor.InternalValidateSnapshotWaitTarget @TargetDatabaseName="+g.lit(TARGET)+",@TargetDatabaseIdOut=@OldId OUTPUT,@TargetCreateDateOut=@OldCreated OUTPUT,@StatusCodeOut=@OldStatus OUTPUT,@ErrorNumberOut=@OldError OUTPUT,@ErrorMessageOut=@OldMessage OUTPUT,@CollectorCode='FILE_IO'; IF COALESCE(@OldStatus,'')<>'TARGET_UNAVAILABLE' THROW 53826,N'New public FILE_IO admitted an actual old1.3.0 target.',1;\nGO\n")
        for i,t in enumerate(tables,1):
            if t.role!='SNAPSHOT': continue
            out.append(f'DROP TABLE IF EXISTS qa.LegacyBefore_{i}; SELECT * INTO qa.LegacyBefore_{i} FROM {t.object_name};\n')
        return ''.join(out)+'GO\n'

    def preserve(label,ready,had_wait=False,had_file_io=False):
        out=[]
        for i,t in enumerate(tables,1):
            if t.role!='SNAPSHOT': continue
            cols=binary_columns(t); before=f'qa.LegacyBefore_{i}'
            if t.name=='PackageVersion':
                cols='CONVERT(varbinary(max),PackageCode) AS PackageCode,CONVERT(varbinary(max),InstalledAtUtc) AS InstalledAtUtc'
            if ready and not had_file_io and t.name in ('MetricDefinition','CollectorPolicy'):
                io_codes=','.join(g.lit(c) for c in FILE_IO_METRIC_CODES)
                added=io_codes+(','+metric_list if not had_wait else '')
                pred=f'MetricCode NOT IN({added})' if t.name=='MetricDefinition' else ("CollectorCode NOT IN('FILE_IO','WAIT_STATS')" if not had_wait else "CollectorCode<>'FILE_IO'")
                out.append(equal_rows(before,f'(SELECT * FROM {t.object_name} WHERE {pred}) AS preserved',cols,label+' '+t.name))
                seed_pred=f'MetricCode IN({added})' if t.name=='MetricDefinition' else ("CollectorCode IN('FILE_IO','WAIT_STATS')" if not had_wait else "CollectorCode='FILE_IO'")
                count=(16+(0 if had_wait else 9)) if t.name=='MetricDefinition' else (1 if had_wait else 2)
                out.append(f'IF (SELECT COUNT_BIG(*) FROM {t.object_name} WHERE {seed_pred})<>{count} THROW 53826,N\'Unexpected added seed set.\',1;\n')
            else: out.append(equal_rows(before,t.object_name,cols,label+' '+t.name))
        version='1.3.1' if ready else '1.2.2'
        out.append(f"IF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageCode='SC-023' AND PackageVersion='{version}' AND SchemaVersion=3) THROW 53813,N'Snapshot migration version mismatch.',1;\n")
        if ready:
            if not had_wait:
                out.append("IF NOT EXISTS(SELECT 1 FROM snapshot.CollectorPolicy WHERE CollectorCode='WAIT_STATS' AND IsEnabled=0 AND PayloadEnabled=0 AND IsFrameworkDefault=0) THROW 53826,N'New Wait policy must remain opt-in.',1;\n")
            for name,text in current.items():
                if not name.startswith(('020_','040_','050_','055_','057_','060_','070_')): continue
                proc=text.split('CREATE OR ALTER PROCEDURE',1)[1].split('\n',1)[0].strip()
                definition=g.split_batches(text)[0]
                # Use the identical complete canonical batch as the preflight hash.
                definition=g.stored_module_definition(definition)
                digest=hashlib.sha256(definition.encode('utf-16le')).hexdigest()
                out.append(f"IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID({g.lit(proc)})),NCHAR(13)+NCHAR(10),NCHAR(10)))))<>0x{digest} OR OBJECT_DEFINITION(OBJECT_ID({g.lit(proc)})) IS NULL THROW 53826,{g.lit('Current helper body mismatch: '+proc)},1;\n")
        return ''.join(out)

    def state(variable):
        items=['JSON_QUERY((SELECT '+binary_columns(t)+' FROM '+t.object_name+' ORDER BY '+g.q(t.columns[0])+" FOR JSON PATH,INCLUDE_NULL_VALUES)) AS "+g.q(t.name) for t in target_tables]
        items += ["JSON_QUERY((SELECT name,type,create_date,modify_date FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot') ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS objects",
                  "JSON_QUERY((SELECT name,object_id,parent_object_id,definition,is_disabled,is_not_trusted,is_not_for_replication FROM sys.check_constraints WHERE schema_id=SCHEMA_ID(N'snapshot') ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS checks",
                  "JSON_QUERY((SELECT object_id,column_id,name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM sys.columns WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id,column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS columns",
                  "JSON_QUERY((SELECT object_id,definition,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS modules",
                  "JSON_QUERY((SELECT object_id,last_value FROM sys.identity_columns WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS identities"]
        return f'SET {variable}=(SELECT '+','.join(items)+' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);\n'

    negatives=[
        ('unknown version',"UPDATE snapshot.PackageVersion SET PackageVersion='9.9.9';",53935,shape(1)),
        ('padded version',"UPDATE snapshot.PackageVersion SET PackageVersion='1.0.0 ';",53935,shape(1)),
        ('padded package',"UPDATE snapshot.PackageVersion SET PackageCode='SC-023 ';",53935,"UPDATE snapshot.PackageVersion SET PackageCode='SC-023';"),
        ('wrong case package',"ALTER TABLE snapshot.PackageVersion NOCHECK CONSTRAINT CK_snapshot_PackageVersion_PackageCode; UPDATE snapshot.PackageVersion SET PackageCode='sc-023';",53935,"UPDATE snapshot.PackageVersion SET PackageCode='SC-023'; ALTER TABLE snapshot.PackageVersion WITH CHECK CHECK CONSTRAINT CK_snapshot_PackageVersion_PackageCode;"),
        ('missing CHECK','ALTER TABLE snapshot.CollectorPolicy DROP CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode;',53908,"ALTER TABLE snapshot.CollectorPolicy WITH CHECK ADD CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode CHECK(CollectorCode='PERFORMANCE_COUNTERS');"),
        ('disabled CHECK','ALTER TABLE snapshot.Scope NOCHECK CONSTRAINT CK_snapshot_Scope_ScopeType;',53908,'ALTER TABLE snapshot.Scope WITH CHECK CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;'),
        ('untrusted CHECK','ALTER TABLE snapshot.Scope NOCHECK CONSTRAINT CK_snapshot_Scope_ScopeType; ALTER TABLE snapshot.Scope CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;',53908,'ALTER TABLE snapshot.Scope WITH CHECK CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;'),
        ('additional CHECK','ALTER TABLE snapshot.Scope ADD CONSTRAINT CK_ExampleAdditionalScope CHECK(ScopeId>0);',53908,'ALTER TABLE snapshot.Scope DROP CONSTRAINT CK_ExampleAdditionalScope;'),
        ('additional column','ALTER TABLE snapshot.Scope ADD ExampleUnexpectedColumn int NULL;',53906,'ALTER TABLE snapshot.Scope DROP COLUMN ExampleUnexpectedColumn;'),
        ('mixed domains',"ALTER TABLE snapshot.Scope DROP CONSTRAINT CK_snapshot_Scope_ScopeType; ALTER TABLE snapshot.Scope WITH CHECK ADD CONSTRAINT CK_snapshot_Scope_ScopeType CHECK([ScopeType] IN ('SERVER','PERFORMANCE_COUNTER','WAIT_TYPE'));",53908,shape(1)),
        ('unknown enum',"ALTER TABLE snapshot.CollectorPolicy DROP CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode; ALTER TABLE snapshot.CollectorPolicy WITH CHECK ADD CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode CHECK(CollectorCode IN('PERFORMANCE_COUNTERS','EXAMPLE_UNSUPPORTED'));",53908,shape(1)),
    ]
    out=['USE '+g.q(TARGET)+';\nGO\nCREATE TABLE qa.SnapshotMigrationInput(Route varchar(16) PRIMARY KEY,SqlText nvarchar(max) NOT NULL);\n']
    for label,route in routes+[('DIRECT_TARGET',direct_patch)]:
        out.append('INSERT qa.SnapshotMigrationInput VALUES('+g.lit(label)+','+g.lit(route)+');\n')
    out.append('GO\n')
    for label,route in routes:
        call="DECLARE @SnapshotRouteSql nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+");\nEXEC sys.sp_executesql @SnapshotRouteSql;\n"
        out.append(arrange_old('1.0.0')+call+'GO\n'+preserve('V1 '+label,label!='DIRECT'))
        out.append('GO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before')+call+state('@After'))
        out.append("SET @Before=JSON_MODIFY(JSON_MODIFY(@Before,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); SET @After=JSON_MODIFY(JSON_MODIFY(@After,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL);\nIF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53814,N'Snapshot repetition changed existing state.',1;\nGO\n")
        patch_route='DIRECT_TARGET' if label=='DIRECT' else label
        patch_call="DECLARE @SnapshotPatchSql nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(patch_route)+"); EXEC sys.sp_executesql @SnapshotPatchSql;\n"
        for version in ('1.1.0','1.1.1','1.2.0','1.2.1','1.3.0'):
            out.append(arrange_old(version)+patch_call+'GO\n'+preserve(version+' '+label,True,version in ('1.2.0','1.2.1','1.3.0'),version=='1.3.0')+'GO\n')
        if label=='STANDALONE':
            out.append('SET QUOTED_IDENTIFIER OFF; SET ANSI_NULLS OFF; SET ANSI_PADDING OFF; SET ANSI_WARNINGS OFF; SET ARITHABORT OFF; SET CONCAT_NULL_YIELDS_NULL OFF; SET NUMERIC_ROUNDABORT ON; SET LOCK_TIMEOUT -1;\n'+call)
            out.append('SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; SET LOCK_TIMEOUT 10000;\n')
            out.append("IF (SELECT COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID(N'snapshot'))<>7 OR EXISTS(SELECT 1 FROM sys.procedures p JOIN sys.sql_modules m ON m.object_id=p.object_id WHERE p.schema_id=SCHEMA_ID(N'snapshot') AND (m.uses_ansi_nulls<>1 OR m.uses_quoted_identifier<>1)) THROW 53820,N'Snapshot standalone inherited noncanonical module settings.',1;\nGO\n")
            out.append('SET XACT_ABORT ON; BEGIN TRANSACTION;\n'+negative(route,50000,'Snapshot standalone caller transaction',"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 16384)=0 THROW 53817,N'Snapshot standalone changed caller transaction/options.',1; ROLLBACK TRANSACTION;"))
            out.append('SET IMPLICIT_TRANSACTIONS ON;\n'+negative(route,50000,'Snapshot standalone implicit transactions',"IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=0 THROW 53818,N'Snapshot standalone changed implicit transaction state.',1; SET IMPLICIT_TRANSACTIONS OFF;"))
        out.append(arrange_old('1.0.0'))
        if label=='DIRECT':
            out.append('BEGIN TRANSACTION;\n'+call+"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53819,N'Direct Snapshot installer completed caller transaction.',1; ROLLBACK TRANSACTION;\nIF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageVersion='1.0.0' AND SchemaVersion=1) THROW 53819,N'Direct Snapshot caller rollback failed.',1;\nGO\n")
            out.append('SET XACT_ABORT ON; SET IMPLICIT_TRANSACTIONS ON;\n'+negative(route,50000,'Direct Snapshot implicit transactions',"IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=0 OR (@@OPTIONS & 16384)=0 THROW 53818,N'Direct Snapshot changed implicit transaction state.',1; SET IMPLICIT_TRANSACTIONS OFF;"))
        selected=negatives if label!='COMBINED' else [negatives[i] for i in (0,2,3,8,9)]
        for case,arrange,error,restore in selected:
            out.append(arrange+'\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before'))
            out.append("DECLARE @SnapshotRouteSql nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+");\n")
            out.append(f'BEGIN TRY EXEC sys.sp_executesql @SnapshotRouteSql; THROW 53815,{g.lit("Expected Snapshot rejection: "+label+" "+case)},1; END TRY\nBEGIN CATCH IF ERROR_NUMBER()<>{error} THROW; END CATCH;\n')
            out.append(state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) OR @@TRANCOUNT<>0 THROW 53816,N'Rejected Snapshot route changed state.',1;\nGO\n"+restore+'\nGO\n')
        out.append(shape(2)+'GO\n')
    # A foreign new helper on an old package is rejected before any DDL/seed.
    out.append(arrange_old('1.1.1')+"EXEC(N'CREATE PROCEDURE snapshot.InternalCompleteWaitStatsCycle AS SELECT 1;');\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
    out.append("DECLARE @BadRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); BEGIN TRY EXEC sys.sp_executesql @BadRoute; THROW 53826,N'Expected foreign helper rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53762 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Foreign helper rejection changed state.',1;\nGO\nDROP PROCEDURE snapshot.InternalCompleteWaitStatsCycle;\n")
    # Canonical partial SQLCMD progress is recoverable while still staged.
    out += ['EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(current['055_InternalCompleteWaitStatsCycle.sql'])]
    out.append("DECLARE @Recover nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @Recover;\nGO\n"+preserve('canonical partial recovery',True)+'GO\n')
    # Stop a real released1.2.0 upgrade after030, leaving its actual old055.
    out.append(arrange_old('1.2.0')+"DECLARE @Stage nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT'); EXEC sys.sp_executesql @Stage;\nIF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageVersion='1.2.2') THROW 53826,N'Expected staged old-Wait upgrade.',1;\n")
    out.append("IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'snapshot.InternalCompleteWaitStatsCycle')),NCHAR(13)+NCHAR(10),NCHAR(10)))))<>0xe392b9581c55955b81674e468aa88eac444339585dfd787a682abf66b3a48c49 THROW 53826,N'Staged recovery did not retain the actual released old helper.',1;\nGO\nDECLARE @OldRecover nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @OldRecover;\nGO\n"+preserve('released Wait partial recovery',True,True)+'GO\n')
    out.append(arrange_old('1.3.0')+"UPDATE snapshot.PackageVersion SET PackageVersion='1.2.2';\nGO\nDECLARE @OldFileRecover nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @OldFileRecover;\nGO\n"+preserve('released1.3.0 staged helper recovery',True,True,True)+'GO\n')
    # A released1.2.1 helper is also preserved after the schema3 stage and recovered by its exact stored hash.
    out.append(arrange_old('1.2.1')+"DECLARE @StageReady nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT'); EXEC sys.sp_executesql @StageReady;\nIF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageVersion='1.2.2' AND SchemaVersion=3) THROW 53826,N'Expected staged released1.2.1 upgrade.',1;\n")
    out.append("IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'snapshot.InternalCompleteWaitStatsCycle')),NCHAR(13)+NCHAR(10),NCHAR(10)))))<>0xaeb295d67a15ce0fcf452404dde233729012e42340c138c8924f27447e1b8762 THROW 53826,N'Staged recovery lost the actual released1.2.1 helper.',1;\nGO\nDECLARE @ReadyRecover nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @ReadyRecover;\nGO\n"+preserve('released1.2.1 staged recovery',True,True)+'GO\n')
    out.append(arrange_old('1.2.1')+"EXEC(N'CREATE PROCEDURE snapshot.InternalCompleteFileIOCycle AS SELECT 1;');\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
    out.append("DECLARE @ForeignIO nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); BEGIN TRY EXEC sys.sp_executesql @ForeignIO; THROW 53826,N'Expected foreign file-I/O helper rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53762 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Foreign file-I/O helper rejection changed state.',1;\nGO\nDROP PROCEDURE snapshot.InternalCompleteFileIOCycle;\nGO\nDECLARE @CompleteIO nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @CompleteIO;\nGO\n")
    for label,route in routes:
        out.append("UPDATE snapshot.MetricDefinition SET Unit='EXAMPLE_WRONG' WHERE MetricCode='WAIT_TIME_MS';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
        out.append("DECLARE @SeedRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+"); BEGIN TRY EXEC sys.sp_executesql @SeedRoute; THROW 53826,N'Expected seed collision rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53760 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Seed preflight rejection changed state.',1;\nGO\nUPDATE snapshot.MetricDefinition SET Unit='ms' WHERE MetricCode='WAIT_TIME_MS';\nGO\n")
    # Compatible custom seeds and the disabled, customized Wait policy survive.
    out.append("UPDATE snapshot.MetricDefinition SET Description=N'Example custom Wait description',IsFrameworkDefault=0,SeedVersion=2 WHERE MetricCode='WAIT_TIME_MS'; UPDATE snapshot.CollectorPolicy SET MaxRows=123,IsEnabled=0 WHERE CollectorCode='WAIT_STATS';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
    out.append("DECLARE @CustomRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @CustomRoute;\n"+state('@After')+"SET @Before=JSON_MODIFY(JSON_MODIFY(@Before,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); SET @After=JSON_MODIFY(JSON_MODIFY(@After,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Compatible custom seeds or policies were overwritten.',1;\nGO\n")
    finish=''.join('EXEC sys.sp_executesql '+g.lit(b)+';\n' for name in ('075_CompleteWaitStatsInstallation.sql','078_CompleteFileIOInstallation.sql') for b in g.split_batches(current[name]))
    for label,arrange,restore in [
        ('missing helper','DROP PROCEDURE snapshot.InternalFinalizeCollectionCycle;\n',current['060_InternalFinalizeCollectionCycle.sql']),
        ('missing file-I/O helper','DROP PROCEDURE snapshot.InternalCompleteFileIOCycle;\n',current['057_InternalCompleteFileIOCycle.sql']),
        ('mistyped handshake',''.join('EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(current['070_InternalPurgeExpiredData.sql'].replace('@RetentionContractVersionOut int','@RetentionContractVersionOut smallint'))),current['070_InternalPurgeExpiredData.sql'])]:
        out.append("UPDATE snapshot.PackageVersion SET PackageVersion='1.2.2';\n"+arrange+'GO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before'))
        expected_error=53781 if label=='missing file-I/O helper' else 53762
        out.append('BEGIN TRY\n'+finish+f"THROW 53826,N'Expected incomplete closure rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>{expected_error} THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Closure rejection changed staged state.',1;\nGO\n")
        out += ['EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(restore)]
        out.append(finish+'GO\n')
    # The final closure alone cannot advertise Ready after a Wait seed is lost.
    final_io=''.join('EXEC sys.sp_executesql '+g.lit(batch)+';\n' for batch in g.split_batches(current['078_CompleteFileIOInstallation.sql']))
    out.append("UPDATE snapshot.PackageVersion SET PackageVersion='1.2.2'; SELECT * INTO qa.FinalWaitSeedBefore FROM snapshot.MetricDefinition WHERE MetricCode='WAIT_SIGNAL_TIME_MS'; DELETE snapshot.MetricDefinition WHERE MetricCode='WAIT_SIGNAL_TIME_MS';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
    out.append('BEGIN TRY\n'+final_io+"THROW 53826,N'Expected last-closure missing Wait seed rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53781 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Missing Wait seed closure changed stage state.',1;\nGO\nSET IDENTITY_INSERT snapshot.MetricDefinition ON; INSERT snapshot.MetricDefinition(MetricDefinitionId,MetricCode,ValueType,Unit,ContractVersion,Description,IsFrameworkDefault,SeedVersion,LastUpdatedUtc) SELECT MetricDefinitionId,MetricCode,ValueType,Unit,ContractVersion,Description,IsFrameworkDefault,SeedVersion,LastUpdatedUtc FROM qa.FinalWaitSeedBefore; SET IDENTITY_INSERT snapshot.MetricDefinition OFF;\nGO\n"+finish+'GO\n')
    for label,route in routes:
        out.append("UPDATE snapshot.MetricDefinition SET Unit='EXAMPLE_WRONG' WHERE MetricCode='IO_READ_COUNT';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
        out.append("DECLARE @IOSeedRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+"); BEGIN TRY EXEC sys.sp_executesql @IOSeedRoute; THROW 53826,N'Expected file-I/O seed collision rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53780 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'File-I/O seed preflight changed state.',1;\nGO\nUPDATE snapshot.MetricDefinition SET Unit='count' WHERE MetricCode='IO_READ_COUNT';\nGO\n")
    out.append("SELECT N'PASS' AS SnapshotSchemaMigration,N'3 V1 routes, 15 real-helper patch upgrades with released1.2.1 and1.3.0 Wait admission and old-Wait partial recovery, repetition, 27 shape/version rejections, collision and partial recovery' AS Scope;\nGO\n")
    out.append("DECLARE @Installer sysname=N'ExampleSnapshotInstaller_'+REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),@CredentialValue nvarchar(128)=N'Example!'+CONVERT(nvarchar(36),NEWID()),@PermissionSql nvarchar(max),@Impersonated bit=0,@InstallerSid varbinary(85),@PermissionBefore nvarchar(max),@PermissionAfter nvarchar(max),@InstallerSource nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT');\n")
    out.append("SET @PermissionSql=N'CREATE LOGIN '+QUOTENAME(@Installer)+N' WITH PASSWORD='+QUOTENAME(@CredentialValue,NCHAR(39))+N',CHECK_POLICY=OFF;'; EXEC master.sys.sp_executesql @PermissionSql; SET @InstallerSid=SUSER_SID(@Installer);\nBEGIN TRY\n")
    out.append("SET @PermissionSql=N'CREATE USER '+QUOTENAME(@Installer)+N' FOR LOGIN '+QUOTENAME(@Installer)+N'; GRANT CONTROL ON DATABASE::'+QUOTENAME(DB_NAME())+N' TO '+QUOTENAME(@Installer)+N';'; EXEC sys.sp_executesql @PermissionSql; SET @PermissionSql=N'GRANT VIEW ANY DEFINITION TO '+QUOTENAME(@Installer)+N';'; EXEC master.sys.sp_executesql @PermissionSql;\n")
    out.append("EXECUTE AS LOGIN=@Installer; SET @Impersonated=1; EXEC sys.sp_executesql @InstallerSource; REVERT; SET @Impersonated=0;\n")
    for permission in ('VIEW ANY DEFINITION','CONTROL'):
        change='DENY VIEW ANY DEFINITION' if permission=='VIEW ANY DEFINITION' else 'GRANT VIEW ANY DEFINITION'
        out.append("SET @PermissionSql=N'"+change+" TO '+QUOTENAME(@Installer)+N';'; EXEC master.sys.sp_executesql @PermissionSql;\n")
        if permission=='CONTROL':
            out.append("SET @PermissionSql=N'REVOKE CONTROL ON DATABASE::'+QUOTENAME(DB_NAME())+N' FROM '+QUOTENAME(@Installer)+N';'; EXEC sys.sp_executesql @PermissionSql;\n")
        out.append(state('@PermissionBefore'))
        out.append("BEGIN TRY EXECUTE AS LOGIN=@Installer; SET @Impersonated=1; EXEC sys.sp_executesql @InstallerSource; REVERT; SET @Impersonated=0; THROW 53821,N'Expected Snapshot installer permission rejection.',1; END TRY\nBEGIN CATCH IF @Impersonated=1 BEGIN REVERT; SET @Impersonated=0; END; IF ERROR_NUMBER()<>53901 THROW; END CATCH;\n")
        out.append(state('@PermissionAfter')+"IF CONVERT(varbinary(max),@PermissionBefore)<>CONVERT(varbinary(max),@PermissionAfter) OR @@TRANCOUNT<>0 THROW 53822,N'Denied Snapshot installer changed state.',1;\n")
    cleanup="IF SUSER_SID(@Installer)<>@InstallerSid THROW 53823,N'Own installer identity changed.',1; IF EXISTS(SELECT 1 FROM sys.database_principals WHERE name=@Installer AND sid=@InstallerSid) BEGIN SET @PermissionSql=N'DROP USER '+QUOTENAME(@Installer)+N';'; EXEC sys.sp_executesql @PermissionSql; END; SET @PermissionSql=N'DROP LOGIN '+QUOTENAME(@Installer)+N';'; EXEC master.sys.sp_executesql @PermissionSql;\n"
    out.append(cleanup+"END TRY\nBEGIN CATCH\nIF @Impersonated=1 REVERT;\n"+cleanup+"THROW;\nEND CATCH;\nSELECT N'PASS' AS SnapshotInstallerPermissions,N'CONTROL plus server definition visibility; two exact denied-state preservation cases' AS Scope;\nGO\n")
    return ''.join(out)


def prepare_snapshot_schema_only(packaged_installer=None):
    sql,_=g.generate(ROOT,True)
    if packaged_installer is not None:
        packaged=packaged_installer.read_text(encoding='utf-8-sig')
        if packaged!=sql: raise g.BuildError('Packaged snapshot-risk deployment differs from canonical sources')
        sql=packaged
    _,tables,_=g.load_sources(ROOT,True)
    deployed=configured(sql)
    out=["USE master;\nGO\nSET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;\n",
         f"IF DB_ID({g.lit(FRAMEWORK)}) IS NOT NULL OR DB_ID({g.lit(TARGET)}) IS NOT NULL THROW 53802,N'Regression requires absent dedicated test databases.',1;\n",
         f'CREATE DATABASE {g.q(FRAMEWORK)} COLLATE SQL_Latin1_General_CP1_CS_AS;\nGO\nCREATE DATABASE {g.q(TARGET)} COLLATE Latin1_General_100_CS_AS;\nGO\n',deployed+'\nGO\nUSE '+g.q(TARGET)+';\nGO\nCREATE SCHEMA qa AUTHORIZATION dbo;\nGO\n']
    out.append((ROOT/'Code/Tests/Integration/Deployment_Filled_Target.sql').read_text(encoding='utf-8-sig').replace('USE [DeineDatenbank];','USE '+g.q(TARGET)+';',1))
    for i,table in enumerate(tables,1):
        if table.role=='SNAPSHOT':
            out.append(f'SELECT * INTO qa.Before_{i} FROM {table.object_name};\n')
    out.append('GO\n'+snapshot_schema_cases(deployed,tables))
    return ''.join(out)


def prepare(packaged_installer=None):
    sql, info = g.generate(ROOT, True)
    if packaged_installer is not None:
        packaged = packaged_installer.read_text(encoding='utf-8-sig')
        if packaged != sql:
            raise g.BuildError('Packaged combined deployment differs from canonical sources')
        sql = packaged
    _, tables, _ = g.load_sources(ROOT, True)
    deployed = configured(sql)
    out = ["USE [master];\nGO\nSET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ARITHABORT ON; SET XACT_ABORT ON;\n",
           f"IF DB_ID({g.lit(FRAMEWORK)}) IS NOT NULL OR DB_ID({g.lit(TARGET)}) IS NOT NULL THROW 53802,N'Regression requires absent dedicated test databases.',1;\n",
           f"CREATE DATABASE {g.q(FRAMEWORK)} COLLATE SQL_Latin1_General_CP1_CS_AS;\nGO\n",
           f"CREATE DATABASE {g.q(TARGET)} COLLATE Latin1_General_100_CS_AS;\nGO\n",
           deployed+'\nGO\n']
    # Fresh receipts exist in both contexts with no pre-existing table manifest.
    for role, db in [('FRAMEWORK',FRAMEWORK), ('SNAPSHOT',TARGET)]:
        check = ("DECLARE @Run sysname=(SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%');\n"
                 "IF @Run IS NULL THROW 53803,N'Missing fresh receipt.',1;\n"
                 "DECLARE @Check nvarchar(max)=N'IF EXISTS(SELECT 1 FROM monitor_deployment.'+QUOTENAME(@Run)+N' WHERE Manifest<>N''[]'' OR FormatVersion<>1 OR DatabaseRole<>@Role OR SourceSha256<>@Digest) THROW 53803,N''Invalid fresh receipt.'',1;';\n"
                 f"EXEC sys.sp_executesql @Check,N'@Role varchar(16),@Digest binary(32)',@Role='{role}',@Digest=0x{info['digest']};\n")
        out.append('USE '+g.q(db)+';\nGO\n'+check+'GO\nCREATE SCHEMA qa AUTHORIZATION dbo;\nGO\n')
    for role, db, file in [('FRAMEWORK',FRAMEWORK,'Deployment_Filled_Core.sql'), ('SNAPSHOT',TARGET,'Deployment_Filled_Target.sql')]:
        fixture = (ROOT/'Code/Tests/Integration'/file).read_text(encoding='utf-8-sig')
        out.append(fixture.replace('USE [DeineDatenbank];','USE '+g.q(db)+';',1))
        out.append('USE '+g.q(db)+';\nGO\n')
        out.append("CREATE TABLE qa.BeforeMeta(TableSchema sysname,TableName sysname,IdentityValue decimal(38,0) NULL);\n")
        for i, table in enumerate(tables,1):
            if table.role!=role:
                continue
            cols=','.join('CONVERT(binary(8),'+g.q(c)+') AS '+g.q(c) if 'rowversion' in table.column_specs[c].lower() else
                          'CONVERT('+g.ident(g.tokens(table.column_specs[c])[1])+','+g.q(c)+') AS '+g.q(c) if 'IDENTITY' in table.column_specs[c].upper() else g.q(c) for c in table.columns)
            out.append(f"IF NOT EXISTS(SELECT 1 FROM {table.object_name}) THROW 53804,{g.lit('Unfilled table fixture: '+table.object_name)},1;\n")
            out.append(f"SELECT {cols} INTO qa.Before_{i} FROM {table.object_name};\n")
            out.append(f"INSERT qa.BeforeMeta VALUES({g.lit(table.schema)},{g.lit(table.name)},CONVERT(decimal(38,0),IDENT_CURRENT({g.lit(table.object_name)})));\n")
        if role=='FRAMEWORK':
            out.append("SELECT OBJECT_DEFINITION(OBJECT_ID(N'monitor.VW_AnalyseAccessPolicy')) AS Definition INTO qa.BeforePolicy;\n")
            for name in ['FrameworkInstallationHistory','FrameworkExpectedObject','FrameworkProcedureContract']:
                out.append(f'SELECT * INTO qa.Before_{name} FROM monitor.{name};\n')
        out.append('GO\n')
    # All failed preflights are followed by native product and receipt checks.
    out.append(negative(configured(sql,'missing synthetic framework'),53922,'missing database'))
    out.append(negative(configured(sql,FRAMEWORK,FRAMEWORK),53921,'same target'))
    out.append(negative(configured(sql,FRAMEWORK,'master'),53922,'system target'))
    out.append(negative(configured(sql,'x'*129),53920,'overlength database'))
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\n')
    out.append("ALTER TABLE monitor.WaitTypeCatalog ADD UnexpectedLocalColumn int NULL;\nGO\n")
    out.append(negative(deployed,53906,'extra column'))
    out.append("ALTER TABLE monitor.WaitTypeCatalog DROP COLUMN UnexpectedLocalColumn;\nGO\n")
    wait_contract=next(t for t in tables if t.name=='WaitTypeCatalog')
    default_names=[name for name,kind in wait_contract.constraints if kind=='DEFAULT'][:2]
    def swap_names(names):
        first,second=names
        return ''.join('EXEC sys.sp_rename '+g.lit('monitor.'+old)+','+g.lit(new)+",N'OBJECT';\n"
                       for old,new in [(first,'SQLSA_RegressionSwap'),(second,first),('SQLSA_RegressionSwap',second)])+'GO\n'
    out.append(swap_names(default_names))
    out.append(negative(deployed,53908,'default name-parent binding'))
    out.append(swap_names(default_names))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=0 WHERE WaitType=N'CURSOR';\nGO\n")
    out.append(negative(deployed,53930,'custom retired reference'))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=1 WHERE WaitType=N'CURSOR';\nGO\n")
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=0 WHERE WaitType=N'CXPACKET' AND SourceOrdinal=1;\nGO\n")
    out.append(negative(deployed,53933,'custom required source collision'))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=1 WHERE WaitType=N'CXPACKET' AND SourceOrdinal=1;\nGO\n")
    out.append("UPDATE monitor.SqlServerBuildCatalog SET ReleaseName=N'SYNTHETIC_CONFLICT' WHERE BuildVersion=(SELECT MIN(BuildVersion) FROM monitor.SqlServerBuildCatalog WHERE ProductMajorVersion<>99);\nGO\n")
    out.append(negative(deployed,53931,'markerless conflict'))
    out.append("UPDATE c SET ReleaseName=b.ReleaseName FROM monitor.SqlServerBuildCatalog c JOIN qa.Before_"+str(next(i for i,t in enumerate(tables,1) if t.name=='SqlServerBuildCatalog'))+" b ON b.BuildVersion=c.BuildVersion;\nGO\n")
    # A direct rejection must preserve an already active, committable caller TX
    # and the caller's XACT_ABORT option even through nested sp_executesql.
    out.append("SET XACT_ABORT ON; BEGIN TRANSACTION; INSERT qa.BeforeMeta VALUES(N'caller',N'caller',NULL);\n")
    out.append(negative(deployed,50000,'caller transaction',"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 16384)=0 OR NOT EXISTS(SELECT 1 FROM qa.BeforeMeta WHERE TableSchema=N'caller') THROW 53805,N'Caller transaction or option changed.',1; ROLLBACK TRANSACTION;"))
    fault=g.invoke('SELECT [SQLSA_IntentionalMissingColumn] FROM [monitor].[WaitTypeCatalog];','@FrameworkDatabase','Intentional lower-scope compile failure')
    prefix,commit,suffix=deployed.rpartition('COMMIT TRANSACTION;')
    if not commit:
        raise g.BuildError('Native regression could not locate the outer commit')
    out.append(negative(prefix+fault+commit+suffix,207,'late compile failure'))
    for role,db in [('FRAMEWORK',FRAMEWORK),('SNAPSHOT',TARGET)]:
        out.append('USE '+g.q(db)+';\nGO\n')
        for i,table in enumerate(tables,1):
            if table.role==role:
                out.append(equal_rows(f'qa.Before_{i}',table.object_name,binary_columns(table),table.object_name+' late rollback'))
        out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>1 OR EXISTS(SELECT 1 FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'State[_]%') THROW 53806,N'Rejected deployment wrote receipts or state tables.',1;\nGO\n")
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\n')
    out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>1 THROW 53806,N'Rejected deployment wrote receipts.',1;\nGO\n")
    out.append(deployed+'\nGO\n')
    for role, db in [('FRAMEWORK',FRAMEWORK),('SNAPSHOT',TARGET)]:
        out.append('USE '+g.q(db)+';\nGO\n')
        out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>2 THROW 53806,N'Reapply receipt count mismatch.',1;\n")
        out.append("DECLARE @Run sysname=(SELECT TOP(1) name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%' ORDER BY create_date DESC,object_id DESC),@Manifest nvarchar(max),@Read nvarchar(max),@State sysname,@Compare nvarchar(max);\nSET @Read=N'SELECT @Result=Manifest FROM monitor_deployment.'+QUOTENAME(@Run); EXEC sys.sp_executesql @Read,N'@Result nvarchar(max) OUTPUT',@Manifest OUTPUT;\n")
        for i, table in enumerate(tables,1):
            if table.role!=role:
                continue
            cols=binary_columns(table)
            before=f'qa.Before_{i}'
            # The archive target is selected by the receipt's source identity,
            # not a parallel hardcoded ordinal map of mutable table names.
            out.append(f"SET @State=NULL; SELECT @State=archiveName FROM OPENJSON(@Manifest) WITH(originalSchema sysname,originalObject sysname,archiveName sysname) WHERE originalSchema={g.lit(table.schema)} AND originalObject={g.lit(table.name)};\n")
            compare=equal_rows(before,'monitor_deployment.[ARCHIVE]',cols,table.object_name+' archive')
            out.append('IF @State IS NOT NULL BEGIN SET @Compare=REPLACE('+g.lit(compare)+",N'[ARCHIVE]',QUOTENAME(@State)); EXEC sys.sp_executesql @Compare; END;\n")
            if 'IsFrameworkDefault' in table.columns:
                before += ' WHERE IsFrameworkDefault=0'
                active=table.object_name+' WHERE IsFrameworkDefault=0'
                out.append(equal_rows('('+f'SELECT * FROM {before}'+') b','('+f'SELECT * FROM {active}'+') a',cols,table.object_name+' custom'))
            elif table.name not in ('FrameworkVersion','PackageVersion'):
                out.append(equal_rows(before,table.object_name,cols,table.object_name+' active'))
            out.append(f"IF EXISTS(SELECT 1 FROM qa.BeforeMeta WHERE TableSchema={g.lit(table.schema)} AND TableName={g.lit(table.name)} AND IdentityValue<>CONVERT(decimal(38,0),IDENT_CURRENT({g.lit(table.object_name)}))) THROW 53807,N'Identity counter changed.',1;\n")
        if role=='FRAMEWORK':
            out.append("IF EXISTS(SELECT 1 FROM qa.BeforePolicy WHERE CONVERT(varbinary(max),Definition)<>CONVERT(varbinary(max),OBJECT_DEFINITION(OBJECT_ID(N'monitor.VW_AnalyseAccessPolicy')))) THROW 53808,N'Policy definition changed.',1;\n")
            for name, columns in [('FrameworkInstallationHistory','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value'),('FrameworkExpectedObject','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value'),('FrameworkProcedureContract','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value')]:
                out.append(equal_rows('qa.Before_'+name,'monitor.'+name,columns,name+' legacy'))
            out.append("IF EXISTS(SELECT 1 FROM monitor.PlanAnalysisProfile WHERE ProfileCode='BALANCED' AND IsEnabled<>0) OR EXISTS(SELECT 1 FROM monitor.PlanAnalysisRuleThreshold WHERE ProfileCode='BALANCED' AND IsEnabled<>0) OR EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE RuleCode='SSMS_OBJECT_EXPLORER' AND IsEnabled<>0) THROW 53809,N'Operator activation overwritten.',1;\n")
            out.append("IF EXISTS(SELECT 1 FROM monitor.WaitTypeCatalog WHERE WaitType=N'CURSOR') OR EXISTS(SELECT 1 FROM monitor.WaitTypeCatalogSource WHERE WaitType=N'CURSOR') THROW 53810,N'Retired defaults remain active.',1;\n")
        out.append('GO\n')
    # Reconstruct the known old Wait shape without relying on canonical fresh
    # column_id values. This fixture is synthetic; production code never drops
    # these columns. The next deployment must add all twelve by name/facets.
    wait=next(t for t in tables if t.name=='WaitTypeCatalog')
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\nDECLARE @Default sysname,@Drop nvarchar(max);\n')
    for column in wait.additions:
        out.append(f"SET @Default=NULL; SELECT @Default=d.name FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=OBJECT_ID(N'monitor.WaitTypeCatalog') AND c.name={g.lit(column)}; IF @Default IS NOT NULL BEGIN SET @Drop=N'ALTER TABLE monitor.WaitTypeCatalog DROP CONSTRAINT '+QUOTENAME(@Default); EXEC sys.sp_executesql @Drop; END; ALTER TABLE monitor.WaitTypeCatalog DROP COLUMN {g.q(column)};\n")
    remaining=[c for c in wait.columns if c not in wait.additions]
    out.append('SELECT '+','.join(g.q(c) for c in remaining)+' INTO qa.BeforeOldWait FROM monitor.WaitTypeCatalog;\nGO\n')
    out.append(deployed+'\nGO\nUSE '+g.q(FRAMEWORK)+';\nGO\n')
    for column in wait.additions:
        out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'monitor.WaitTypeCatalog') AND name={g.lit(column)}) THROW 53811,N'Known additive migration omitted a column.',1;\n")
    out.append("DECLARE @Run sysname=(SELECT TOP(1) name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%' ORDER BY create_date DESC,object_id DESC),@Manifest nvarchar(max),@Read nvarchar(max),@State sysname,@Compare nvarchar(max); SET @Read=N'SELECT @Result=Manifest FROM monitor_deployment.'+QUOTENAME(@Run); EXEC sys.sp_executesql @Read,N'@Result nvarchar(max) OUTPUT',@Manifest OUTPUT; SELECT @State=archiveName FROM OPENJSON(@Manifest) WITH(originalObject sysname,archiveName sysname) WHERE originalObject=N'WaitTypeCatalog'; IF @State IS NULL THROW 53812,N'Missing old-shape archive.',1;\n")
    old_columns=','.join('CONVERT(varbinary(max),'+g.q(c)+') AS '+g.q(c) for c in remaining)
    comparison=equal_rows('qa.BeforeOldWait','monitor_deployment.[ARCHIVE]',old_columns,'known old Wait shape')
    out.append('SET @Compare=REPLACE('+g.lit(comparison)+",N'[ARCHIVE]',QUOTENAME(@State)); EXEC sys.sp_executesql @Compare;\nGO\n")
    out.append(snapshot_schema_cases(deployed,tables))
    out.append("SELECT N'PASS' AS DeploymentRuntimeContract,N'Fresh, filled all20, binary archives, custom/legacy/policy/identity, Snapshot migration and preflight rejection' AS Scope;\nGO\n")
    return ''.join(out)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--packaged-installer', type=Path)
    parser.add_argument('--snapshot-schema-only', action='store_true')
    args=parser.parse_args()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(prepare_snapshot_schema_only(args.packaged_installer) if args.snapshot_schema_only else prepare(args.packaged_installer),encoding='utf-8',newline='\n')
    print('Prepared native synthetic deployment regression:',args.output)


if __name__=='__main__':
    main()
