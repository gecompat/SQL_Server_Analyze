/*
===============================================================================
Datei        : 075_CompleteWaitStatsInstallation.sql
Version      : 1.2.1
Stand        : 2026-10-25
Zweck        : Prüft die vollständige Wait-Targetclosure, ergänzt fehlende
               kompatible Seeds und markiert erst danach den Paketabschluss.
Kontext      : Letzte Quelle des geprüften Snapshot-Targetinstallers.
===============================================================================
*/
SET NOCOUNT ON;
SET LOCK_TIMEOUT 0;

-- SNAPSHOT_WAIT_METRIC_CONTRACT_BEGIN
DECLARE @SnapshotWaitExpectedMetrics TABLE
(
    [MetricCode] varchar(96) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    [ValueType] varchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
    [Unit] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
    [Description] nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL
);
INSERT @SnapshotWaitExpectedMetrics ([MetricCode],[ValueType],[Unit],[Description])
VALUES
 ('WAIT_TASK_COUNT','BIGINT','count',N'Unveränderter nativer kumulativer Wait-Taskcounter.'),
 ('WAIT_TIME_MS','BIGINT','ms',N'Unveränderte native kumulative gesamte Waitzeit.'),
 ('WAIT_SIGNAL_TIME_MS','BIGINT','ms',N'Unveränderte native kumulative Signalwaitzeit.'),
 ('WAIT_MAX_TIME_MS','BIGINT','ms',N'Native bisherige maximale Waitzeit; kein additiver Counter.'),
 ('WAIT_TASK_COUNT_DELTA_CANDIDATE','BIGINT','count',N'Monotone Taskdifferenz mit unbewiesener Resetkontinuität.'),
 ('WAIT_TIME_MS_DELTA_CANDIDATE','BIGINT','ms',N'Monotone Waitzeitdifferenz mit unbewiesener Resetkontinuität.'),
 ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE','BIGINT','ms',N'Monotone Signalzeitdifferenz mit unbewiesener Resetkontinuität.'),
 ('WAIT_DELTA_STATUS','STRING','status',N'Expliziter Status für Differenzkandidaten oder ihre Unterdrückung.'),
 ('WAIT_CAPTURE_CONTEXT','STRING','json',N'Versionierter Aufnahme-, Rohwert- und Vergleichskontext auf SERVER-Scope.');
-- SNAPSHOT_WAIT_METRIC_CONTRACT_END

-- SNAPSHOT_WAIT_SEED_CHECK_BEGIN
IF EXISTS
(
    SELECT 1
    FROM [snapshot].[MetricDefinition] AS [d]
    JOIN @SnapshotWaitExpectedMetrics AS [e]
      ON [d].[MetricCode]=[e].[MetricCode]
    WHERE CONVERT(varbinary(max),[d].[MetricCode])<>CONVERT(varbinary(max),[e].[MetricCode])
       OR CONVERT(varbinary(max),[d].[ValueType])<>CONVERT(varbinary(max),[e].[ValueType])
       OR CONVERT(varbinary(max),[d].[Unit])<>CONVERT(varbinary(max),[e].[Unit])
       OR [d].[ContractVersion]<>1
)
    THROW 53760,N'Eine vorhandene Waitmetrik widerspricht dem Metrikvertrag.',1;
-- SNAPSHOT_WAIT_SEED_CHECK_END

IF DB_ID()<=4
   OR (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1
   OR NOT EXISTS
      (SELECT 1 FROM [snapshot].[PackageVersion]
       WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023') AND [PackageVersion]='1.1.1' AND [SchemaVersion]=2)
    THROW 53761,N'Der Wait-Paketabschluss benötigt die geprüfte Schema-2-Grundlage.',1;

DECLARE @SnapshotWaitExpectedHelpers TABLE
([Name] sysname COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,[ObjectId] int NULL);
INSERT @SnapshotWaitExpectedHelpers ([Name],[ObjectId])
SELECT [e].[Name],[p].[object_id]
FROM (VALUES(N'InternalConfigureSnapshotPolicy'),(N'InternalPrepareCollectionCycle'),
 (N'InternalCompletePerformanceCounterCycle'),(N'InternalCompleteWaitStatsCycle'),
 (N'InternalFinalizeCollectionCycle'),(N'InternalPurgeExpiredData')) AS [e]([Name])
LEFT JOIN [sys].[procedures] AS [p] WITH (NOLOCK)
 ON CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[Name])
 AND [p].[schema_id] IN(SELECT [s].[schema_id] FROM [sys].[schemas] AS [s] WITH (NOLOCK)
                       WHERE CONVERT(varbinary(max),[s].[name])=CONVERT(varbinary(max),N'snapshot'));
IF EXISTS
(
    SELECT 1 FROM @SnapshotWaitExpectedHelpers AS [e]
    LEFT JOIN [sys].[sql_modules] AS [m] WITH (NOLOCK)
      ON [m].[object_id]=[e].[ObjectId]
    WHERE [m].[object_id] IS NULL OR [m].[definition] IS NULL
       OR [m].[uses_ansi_nulls]<>1 OR [m].[uses_quoted_identifier]<>1
)
    THROW 53762,N'Die erforderliche Wait-Helperclosure ist unvollständig.',1;

DECLARE @SnapshotWaitExpectedParameters TABLE
(
    [ProcedureName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
    [ParameterName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
    [SystemTypeId] int NOT NULL,
    [MaxLength] smallint NOT NULL,
    [IsOutput] bit NOT NULL,
    PRIMARY KEY ([ProcedureName],[ParameterName])
);
INSERT @SnapshotWaitExpectedParameters VALUES
 (N'InternalConfigureSnapshotPolicy',N'@CollectorCode',167,64,0),
 (N'InternalConfigureSnapshotPolicy',N'@CollectorEnabled',104,1,0),
 (N'InternalConfigureSnapshotPolicy',N'@UpdateSharedPolicy',104,1,0),
 (N'InternalConfigureSnapshotPolicy',N'@JoinFrameworkTransaction',104,1,0),
 (N'InternalPrepareCollectionCycle',N'@CollectorCode',167,64,0),
 (N'InternalPrepareCollectionCycle',N'@PolicyOnly',104,1,0),
 (N'InternalPurgeExpiredData',N'@ContractOnly',104,1,0),
 (N'InternalPurgeExpiredData',N'@RetentionContractVersionOut',56,4,1),
 (N'InternalCompleteWaitStatsCycle',N'@CaptureRunId',127,8,0),
 (N'InternalCompleteWaitStatsCycle',N'@CollectorJson',231,-1,0),
 (N'InternalCompleteWaitStatsCycle',N'@StatusCodeOut',167,40,1),
 (N'InternalCompleteWaitStatsCycle',N'@IsPartialOut',104,1,1),
 (N'InternalCompleteWaitStatsCycle',N'@ErrorNumberOut',56,4,1),
 (N'InternalCompleteWaitStatsCycle',N'@ErrorMessageOut',231,4096,1);
INSERT @SnapshotWaitExpectedParameters
SELECT [e].[Name],[p].[ParameterName],[p].[SystemTypeId],[p].[MaxLength],CONVERT(bit,0)
FROM @SnapshotWaitExpectedHelpers AS [e]
CROSS JOIN
 (VALUES(N'@ExpectedTargetDatabaseId',56,4),
        (N'@ExpectedTargetDatabaseName',231,256),
        (N'@ExpectedTargetCreateDate',61,8)) AS [p]([ParameterName],[SystemTypeId],[MaxLength])
WHERE [e].[Name] IN(N'InternalConfigureSnapshotPolicy',N'InternalPrepareCollectionCycle',
                   N'InternalCompleteWaitStatsCycle',N'InternalPurgeExpiredData');
IF EXISTS
(
    SELECT 1 FROM @SnapshotWaitExpectedParameters AS [e]
    LEFT JOIN @SnapshotWaitExpectedHelpers AS [h]
      ON CONVERT(varbinary(max),[h].[Name])=CONVERT(varbinary(max),[e].[ProcedureName])
    LEFT JOIN [sys].[parameters] AS [p] WITH (NOLOCK)
      ON [p].[object_id]=[h].[ObjectId]
     AND CONVERT(varbinary(max),[p].[name])=CONVERT(varbinary(max),[e].[ParameterName])
    WHERE [p].[parameter_id] IS NULL OR [p].[system_type_id]<>[e].[SystemTypeId]
       OR [p].[max_length]<>[e].[MaxLength] OR [p].[is_output]<>[e].[IsOutput]
)
    THROW 53762,N'Die erforderlichen Wait-Helpersignaturen fehlen.',1;

INSERT [snapshot].[MetricDefinition]
([MetricCode],[ValueType],[Unit],[ContractVersion],[Description],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
SELECT [e].[MetricCode],[e].[ValueType],[e].[Unit],1,[e].[Description],1,1,SYSUTCDATETIME()
FROM @SnapshotWaitExpectedMetrics AS [e]
WHERE NOT EXISTS
 (SELECT 1 FROM [snapshot].[MetricDefinition] AS [d] WHERE [d].[MetricCode]=[e].[MetricCode]);

IF NOT EXISTS(SELECT 1 FROM [snapshot].[CollectorPolicy] WHERE [CollectorCode]='WAIT_STATS')
    INSERT [snapshot].[CollectorPolicy]
    ([CollectorCode],[IsEnabled],[CollectionIntervalSeconds],[MaxRows],[PayloadEnabled],
     [RetentionPolicyCode],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc])
    VALUES('WAIT_STATS',0,30,1000,0,'DEFAULT',0,1,SYSUTCDATETIME());

UPDATE [snapshot].[PackageVersion]
SET [PackageVersion]='1.2.1',[LastInstallerRunUtc]=SYSUTCDATETIME()
WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023') AND [PackageVersion]='1.1.1' AND [SchemaVersion]=2;
IF @@ROWCOUNT<>1
    THROW 53761,N'Der Wait-Paketabschluss konnte nicht markiert werden.',1;
GO
