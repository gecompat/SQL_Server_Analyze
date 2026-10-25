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
                       f'ALTER TABLE {table.object_name} WITH CHECK ADD CONSTRAINT {g.q(cname)} {old if version==1 else new};\n')
        out.append("UPDATE snapshot.PackageVersion SET PackageVersion="+g.lit('1.0.0' if version==1 else '1.1.1')+
                   f",SchemaVersion={version} WHERE PackageCode='SC-023';\n")
        return ''.join(out)

    def arrange_old(version):
        # Only the named, sample-free synthetic test target is reconstructed.
        out=[f"IF EXISTS(SELECT 1 FROM snapshot.MetricSample s JOIN snapshot.MetricDefinition d ON d.MetricDefinitionId=s.MetricDefinitionId WHERE d.MetricCode IN({metric_list})) THROW 53826,N'Historical fixture owns no Wait samples.',1;\n",
             f'DELETE snapshot.MetricDefinition WHERE MetricCode IN({metric_list});\n',
             "DELETE snapshot.CollectorPolicy WHERE CollectorCode='WAIT_STATS';\n",
             'DROP PROCEDURE IF EXISTS snapshot.InternalCompleteWaitStatsCycle;\n']
        for name,text in historical.items():
            if version in ('1.0.0','1.1.0') and name.startswith('070_'): text=legacy
            out += ['EXEC sys.sp_executesql '+g.lit(batch)+';\n' for batch in g.split_batches(text)]
        out.append(shape(1 if version=='1.0.0' else 2))
        out.append('UPDATE snapshot.PackageVersion SET PackageVersion='+g.lit(version)+';\nGO\n')
        for i,t in enumerate(tables,1):
            if t.role!='SNAPSHOT': continue
            out.append(f'DROP TABLE IF EXISTS qa.LegacyBefore_{i}; SELECT * INTO qa.LegacyBefore_{i} FROM {t.object_name};\n')
        return ''.join(out)+'GO\n'

    def preserve(label,ready):
        out=[]
        for i,t in enumerate(tables,1):
            if t.role!='SNAPSHOT': continue
            cols=binary_columns(t); before=f'qa.LegacyBefore_{i}'
            if t.name=='PackageVersion':
                cols='CONVERT(varbinary(max),PackageCode) AS PackageCode,CONVERT(varbinary(max),InstalledAtUtc) AS InstalledAtUtc'
            if ready and t.name in ('MetricDefinition','CollectorPolicy'):
                pred=f'MetricCode NOT IN({metric_list})' if t.name=='MetricDefinition' else "CollectorCode<>'WAIT_STATS'"
                out.append(equal_rows(before,f'(SELECT * FROM {t.object_name} WHERE {pred}) AS preserved',cols,label+' '+t.name))
                seed_pred=f'MetricCode IN({metric_list})' if t.name=='MetricDefinition' else "CollectorCode='WAIT_STATS'"
                out.append(f'IF (SELECT COUNT_BIG(*) FROM {t.object_name} WHERE {seed_pred})<>{9 if t.name=="MetricDefinition" else 1} THROW 53826,N\'Unexpected added seed set.\',1;\n')
            else: out.append(equal_rows(before,t.object_name,cols,label+' '+t.name))
        version='1.2.0' if ready else '1.1.1'
        out.append(f"IF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageCode='SC-023' AND PackageVersion='{version}' AND SchemaVersion=2) THROW 53813,N'Snapshot migration version mismatch.',1;\n")
        if ready:
            out.append("IF NOT EXISTS(SELECT 1 FROM snapshot.CollectorPolicy WHERE CollectorCode='WAIT_STATS' AND IsEnabled=0 AND PayloadEnabled=0 AND IsFrameworkDefault=0) THROW 53826,N'New Wait policy must remain opt-in.',1;\n")
            for name,text in current.items():
                if not name.startswith(('020_','040_','050_','055_','060_','070_')): continue
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
        for version in ('1.1.0','1.1.1'):
            out.append(arrange_old(version)+patch_call+'GO\n'+preserve(version+' '+label,True)+'GO\n')
        if label=='STANDALONE':
            out.append('SET QUOTED_IDENTIFIER OFF; SET ANSI_NULLS OFF; SET ANSI_PADDING OFF; SET ANSI_WARNINGS OFF; SET ARITHABORT OFF; SET CONCAT_NULL_YIELDS_NULL OFF; SET NUMERIC_ROUNDABORT ON; SET LOCK_TIMEOUT -1;\n'+call)
            out.append('SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; SET LOCK_TIMEOUT 10000;\n')
            out.append("IF (SELECT COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID(N'snapshot'))<>6 OR EXISTS(SELECT 1 FROM sys.procedures p JOIN sys.sql_modules m ON m.object_id=p.object_id WHERE p.schema_id=SCHEMA_ID(N'snapshot') AND (m.uses_ansi_nulls<>1 OR m.uses_quoted_identifier<>1)) THROW 53820,N'Snapshot standalone inherited noncanonical module settings.',1;\nGO\n")
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
    for label,route in routes:
        out.append("UPDATE snapshot.MetricDefinition SET Unit='EXAMPLE_WRONG' WHERE MetricCode='WAIT_TIME_MS';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
        out.append("DECLARE @SeedRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+"); BEGIN TRY EXEC sys.sp_executesql @SeedRoute; THROW 53826,N'Expected seed collision rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53760 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Seed preflight rejection changed state.',1;\nGO\nUPDATE snapshot.MetricDefinition SET Unit='ms' WHERE MetricCode='WAIT_TIME_MS';\nGO\n")
    # Compatible custom seeds and the disabled, customized Wait policy survive.
    out.append("UPDATE snapshot.MetricDefinition SET Description=N'Example custom Wait description',IsFrameworkDefault=0,SeedVersion=2 WHERE MetricCode='WAIT_TIME_MS'; UPDATE snapshot.CollectorPolicy SET MaxRows=123,IsEnabled=0 WHERE CollectorCode='WAIT_STATS';\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n"+state('@Before'))
    out.append("DECLARE @CustomRoute nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route='DIRECT_TARGET'); EXEC sys.sp_executesql @CustomRoute;\n"+state('@After')+"SET @Before=JSON_MODIFY(JSON_MODIFY(@Before,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); SET @After=JSON_MODIFY(JSON_MODIFY(@After,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Compatible custom seeds or policies were overwritten.',1;\nGO\n")
    finish=''.join('EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(current['075_CompleteWaitStatsInstallation.sql']))
    for label,arrange,restore in [
        ('missing helper','DROP PROCEDURE snapshot.InternalFinalizeCollectionCycle;\n',current['060_InternalFinalizeCollectionCycle.sql']),
        ('mistyped handshake',''.join('EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(current['070_InternalPurgeExpiredData.sql'].replace('@RetentionContractVersionOut int','@RetentionContractVersionOut smallint'))),current['070_InternalPurgeExpiredData.sql'])]:
        out.append("UPDATE snapshot.PackageVersion SET PackageVersion='1.1.1';\n"+arrange+'GO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before'))
        out.append('BEGIN TRY\n'+finish+"THROW 53826,N'Expected incomplete closure rejection.',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>53762 THROW; END CATCH;\n"+state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53826,N'Closure rejection changed staged state.',1;\nGO\n")
        out += ['EXEC sys.sp_executesql '+g.lit(b)+';\n' for b in g.split_batches(restore)]
        out.append(finish+'GO\n')
    out.append("SELECT N'PASS' AS SnapshotSchemaMigration,N'3 V1 routes, 6 real-helper patch upgrades, repetition, 27 shape/version rejections, collision and partial recovery' AS Scope;\nGO\n")
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
