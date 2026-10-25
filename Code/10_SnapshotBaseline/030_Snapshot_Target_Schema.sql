/*
===============================================================================
Datei        : 030_Snapshot_Target_Schema.sql
Version      : 1.1.1
Stand        : 2026-10-25
Zweck        : Erstellt das versionierte Basisschema des optionalen SC-023-
               Snapshot-/Baseline-Ziels in der aktuell verbundenen Datenbank.
Voraussetzung: Die Verbindung zeigt auf eine beschreibbare Nicht-Systemdatenbank.
Datenschutz  : Die Tabellen dürfen im autorisierten Betrieb vollständige reale
               Laufzeitevidenz speichern. Dieses Installationsskript enthält
               ausschließlich generische Seeds und keine Laufzeitwerte.
Locking      : Die privilegierte native Strukturvorprüfung verwendet
               LOCK_TIMEOUT 10000 und hält die geprüften Tabellen bis zum
               Transaktionsende. Die anschließende eigene DDL verwendet
               LOCK_TIMEOUT 0 und wartet nicht auf fremde Sch-M-Sperren.
Rechte       : CONTROL DATABASE und VIEW ANY DEFINITION sind für die native
               Strukturprüfung erforderlich. Das Skript vergibt keine Rechte.
===============================================================================
*/

IF (@@OPTIONS & 2)<>0 BEGIN EXEC sys.sp_executesql N'SET XACT_ABORT OFF; RAISERROR(N''Snapshot schema installation requires IMPLICIT_TRANSACTIONS OFF.'',16,1);'; RETURN; END;

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 0;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE
      @SnapshotTargetDatabaseId int = NULL
    , @SnapshotTargetDatabaseName sysname = NULL
    , @SnapshotTargetState tinyint = NULL
    , @SnapshotTargetIsReadOnly bit = NULL;

SELECT TOP (1)
       @SnapshotTargetDatabaseId = [r].[database_id]
FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
WHERE [r].[session_id] = @@SPID;

SELECT
      @SnapshotTargetDatabaseName = [d].[name]
    , @SnapshotTargetState = [d].[state]
    , @SnapshotTargetIsReadOnly = [d].[is_read_only]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[database_id] = @SnapshotTargetDatabaseId;

IF @SnapshotTargetDatabaseId IS NULL
   OR @SnapshotTargetDatabaseName IS NULL
    THROW 51030, N'Die aktuell verbundene Zieldatenbank konnte nicht sicher aufgelöst werden.', 1;

IF @SnapshotTargetDatabaseId <= 4
    THROW 51031, N'Das SC-023-Zielschema darf nicht in einer SQL-Server-Systemdatenbank installiert werden.', 1;

IF @SnapshotTargetState <> 0 OR @SnapshotTargetIsReadOnly <> 0
    THROW 51032, N'Die SC-023-Zieldatenbank muss ONLINE und beschreibbar sein.', 1;

DECLARE @SnapshotMigrationStage tinyint=0;
DECLARE @SnapshotSchemaOwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
BEGIN TRY
IF @SnapshotSchemaOwnTransaction=1 BEGIN TRANSACTION;
ELSE SAVE TRANSACTION SQLSA_SnapshotSchema2;
-- SNAPSHOT_SCHEMA_PREFLIGHT_BEGIN
-- Derived model SHA256: 3d37c5f8816e8570b9f3b2c0d93475840007b1e695f54ae9f4e3362eabb51623
SET NOCOUNT ON; SET LOCK_TIMEOUT 10000;
IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CONTROL'),0)<>1 OR ISNULL(HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION'),0)<>1 THROW 53901,N'Deployment requires CONTROL DATABASE and visible server metadata.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_class=0 AND is_disabled=0) OR EXISTS(SELECT 1 FROM sys.server_triggers WHERE is_disabled=0) THROW 53902,N'Active DDL triggers are unsupported.',1;
IF SCHEMA_ID(N'monitor_deployment') IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM sys.schemas WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) OR NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=3 AND major_id=SCHEMA_ID(N'monitor_deployment') AND name=N'SQL_Server_Analyze.DeploymentFormat' AND CONVERT(nvarchar(30),value)=N'1')) THROW 53903,N'Unknown deployment schema ownership or format.',1;
DECLARE @ObjectId int,@ExpectedId int,@LockCount bigint,@ConstraintSql nvarchar(max),@Prefix nvarchar(33);
CREATE TABLE #SnapshotTargetSchema_ConstraintMap(CanonicalName sysname COLLATE DATABASE_DEFAULT NOT NULL,ParentColumn sysname COLLATE DATABASE_DEFAULT NULL,ConstraintType char(2) COLLATE DATABASE_DEFAULT NOT NULL,Definition nvarchar(max) COLLATE DATABASE_DEFAULT NULL,IsDisabled bit NOT NULL,IsNotTrusted bit NOT NULL,IsNotForReplication bit NOT NULL);
CREATE TABLE #SnapshotTargetSchema_KnownForeignKeys(ParentSchema sysname COLLATE DATABASE_DEFAULT,ParentTable sysname COLLATE DATABASE_DEFAULT,ConstraintName sysname COLLATE DATABASE_DEFAULT);
DECLARE @SnapshotExpectedLegacy bit=0;
IF OBJECT_ID(N'[snapshot].[PackageVersion]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[RetentionPolicy]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[CollectorPolicy]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[CaptureRun]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[ModuleStatus]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[Scope]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[MetricDefinition]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[MetricSample]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[PayloadSnapshot]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[PurgeRun]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalConfigureSnapshotPolicy]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalPrepareCollectionCycle]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalCompletePerformanceCounterCycle]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalCompleteWaitStatsCycle]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalFinalizeCollectionCycle]') IS NOT NULL OR OBJECT_ID(N'[snapshot].[InternalPurgeExpiredData]') IS NOT NULL BEGIN
IF OBJECT_ID(N'[snapshot].[PackageVersion]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[RetentionPolicy]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[CollectorPolicy]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[CaptureRun]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[ModuleStatus]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[Scope]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[MetricDefinition]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[MetricSample]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[PayloadSnapshot]',N'U') IS NULL OR OBJECT_ID(N'[snapshot].[PurgeRun]',N'U') IS NULL THROW 53935,N'Incomplete Snapshot schema.',1;
DECLARE @SnapshotVersionLock bigint; SELECT TOP(1) @SnapshotVersionLock=1 FROM [snapshot].[PackageVersion] WITH(TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
EXEC sys.sp_executesql N'IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 THROW 53935,N''Unknown Snapshot version cardinality.'',1; IF EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),PackageCode)=CONVERT(varbinary(max),''SC-023'') AND CONVERT(varbinary(max),PackageVersion)=CONVERT(varbinary(max),''1.0.0'') AND SchemaVersion=1) SET @Legacy=1; ELSE IF NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),PackageCode)=CONVERT(varbinary(max),''SC-023'') AND CONVERT(varbinary(max),PackageVersion) IN(CONVERT(varbinary(max),''1.1.0''),CONVERT(varbinary(max),''1.1.1''),CONVERT(varbinary(max),''1.2.0''),CONVERT(varbinary(max),''1.2.1'')) AND SchemaVersion=2) THROW 53935,N''Unknown Snapshot package/schema version.'',1;',N'@Legacy bit OUTPUT',@SnapshotExpectedLegacy OUTPUT;
END;
IF SCHEMA_ID(N'snapshot') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name=N'snapshot' AND principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) THROW 53903,N'Noncanonical product schema ownership.',1;
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'CollectorPolicy',N'FK_snapshot_CollectorPolicy_RetentionPolicy');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'CaptureRun',N'FK_snapshot_CaptureRun_CollectorPolicy');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'ModuleStatus',N'FK_snapshot_ModuleStatus_CaptureRun');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'Scope',N'FK_snapshot_Scope_ParentScope');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'MetricSample',N'FK_snapshot_MetricSample_CaptureRun');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'MetricSample',N'FK_snapshot_MetricSample_Scope');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'MetricSample',N'FK_snapshot_MetricSample_MetricDefinition');
INSERT #SnapshotTargetSchema_KnownForeignKeys VALUES(N'snapshot',N'PayloadSnapshot',N'FK_snapshot_PayloadSnapshot_CaptureRun');
CREATE TABLE [#SnapshotTargetSchema_Expected_1]
(
[PackageCode] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL,
[PackageVersion] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[SchemaVersion] int NOT NULL,
[InstalledAtUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
[LastInstallerRunUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
PRIMARY KEY CLUSTERED ([PackageCode]),
CHECK ([PackageCode] = 'SC-023'),
CHECK ([SchemaVersion] > 0)
);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_1]
(
[PackageCode] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL,
[PackageVersion] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[SchemaVersion] int NOT NULL,
[InstalledAtUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_1_0]
              DEFAULT (SYSUTCDATETIME()),
[LastInstallerRunUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_1_1]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_1_2]
              PRIMARY KEY CLUSTERED ([PackageCode]),
CONSTRAINT [SQLSA_1_3]
              CHECK ([PackageCode] = ''SC-023''),
CONSTRAINT [SQLSA_1_4]
              CHECK ([SchemaVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_1_0'' THEN N''DF_snapshot_PackageVersion_InstalledAtUtc'' WHEN @Prefix+N''SQLSA_1_1'' THEN N''DF_snapshot_PackageVersion_LastInstallerRunUtc'' WHEN @Prefix+N''SQLSA_1_2'' THEN N''PK_snapshot_PackageVersion'' WHEN @Prefix+N''SQLSA_1_3'' THEN N''CK_snapshot_PackageVersion_PackageCode'' WHEN @Prefix+N''SQLSA_1_4'' THEN N''CK_snapshot_PackageVersion_SchemaVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_1]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_1_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_1_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_1_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_1_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_1_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_1_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_1_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_1_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_1_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_1_4]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_1'); SET @ObjectId=OBJECT_ID(N'[snapshot].[PackageVersion]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[PackageVersion]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[PackageVersion] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[PackageVersion]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PackageVersion' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PackageVersion' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>0 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PackageVersion_InstalledAtUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_PackageVersion_InstalledAtUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PackageVersion_LastInstallerRunUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_PackageVersion_LastInstallerRunUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_PackageVersion') THROW 53911,N'Missing canonical constraint: PK_snapshot_PackageVersion',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PackageVersion_PackageCode') THROW 53911,N'Missing canonical constraint: CK_snapshot_PackageVersion_PackageCode',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PackageVersion_SchemaVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_PackageVersion_SchemaVersion',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>0 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_2]
(
[RetentionPolicyCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[RawRetentionDays] smallint NOT NULL,
[PayloadRetentionDays] smallint NOT NULL,
[RollupRetentionDays] smallint NOT NULL,
[SoftBudgetMB] bigint NOT NULL,
[PurgeIntervalMinutes] int NOT NULL,
[PurgeBatchRows] int NOT NULL,
[BudgetAction] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
PRIMARY KEY CLUSTERED ([RetentionPolicyCode]),
CHECK ([RawRetentionDays] BETWEEN 1 AND 36500),
CHECK ([PayloadRetentionDays] BETWEEN 1 AND 36500),
CHECK ([RollupRetentionDays] BETWEEN 1 AND 36500),
CHECK ([SoftBudgetMB] > 0),
CHECK ([PurgeIntervalMinutes] BETWEEN 1 AND 10080),
CHECK ([PurgeBatchRows] BETWEEN 1 AND 100000),
CHECK ([BudgetAction] = 'PURGE_EXPIRED_THEN_STOP'),
CHECK ([SeedVersion] > 0)
);
CREATE UNIQUE INDEX [UX_snapshot_RetentionPolicy_FrameworkDefault]
        ON [#SnapshotTargetSchema_Expected_2]([IsFrameworkDefault])
        WHERE [IsFrameworkDefault] = 1;
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_2]
(
[RetentionPolicyCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[RawRetentionDays] smallint NOT NULL,
[PayloadRetentionDays] smallint NOT NULL,
[RollupRetentionDays] smallint NOT NULL,
[SoftBudgetMB] bigint NOT NULL,
[PurgeIntervalMinutes] int NOT NULL,
[PurgeBatchRows] int NOT NULL,
[BudgetAction] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [SQLSA_2_0]
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_2_1]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_2_2]
              PRIMARY KEY CLUSTERED ([RetentionPolicyCode]),
CONSTRAINT [SQLSA_2_3]
              CHECK ([RawRetentionDays] BETWEEN 1 AND 36500),
CONSTRAINT [SQLSA_2_4]
              CHECK ([PayloadRetentionDays] BETWEEN 1 AND 36500),
CONSTRAINT [SQLSA_2_5]
              CHECK ([RollupRetentionDays] BETWEEN 1 AND 36500),
CONSTRAINT [SQLSA_2_6]
              CHECK ([SoftBudgetMB] > 0),
CONSTRAINT [SQLSA_2_7]
              CHECK ([PurgeIntervalMinutes] BETWEEN 1 AND 10080),
CONSTRAINT [SQLSA_2_8]
              CHECK ([PurgeBatchRows] BETWEEN 1 AND 100000),
CONSTRAINT [SQLSA_2_9]
              CHECK ([BudgetAction] = ''PURGE_EXPIRED_THEN_STOP''),
CONSTRAINT [SQLSA_2_10]
              CHECK ([SeedVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_2_0'' THEN N''DF_snapshot_RetentionPolicy_IsFrameworkDefault'' WHEN @Prefix+N''SQLSA_2_1'' THEN N''DF_snapshot_RetentionPolicy_LastUpdatedUtc'' WHEN @Prefix+N''SQLSA_2_2'' THEN N''PK_snapshot_RetentionPolicy'' WHEN @Prefix+N''SQLSA_2_3'' THEN N''CK_snapshot_RetentionPolicy_RawRetentionDays'' WHEN @Prefix+N''SQLSA_2_4'' THEN N''CK_snapshot_RetentionPolicy_PayloadRetentionDays'' WHEN @Prefix+N''SQLSA_2_5'' THEN N''CK_snapshot_RetentionPolicy_RollupRetentionDays'' WHEN @Prefix+N''SQLSA_2_6'' THEN N''CK_snapshot_RetentionPolicy_SoftBudgetMB'' WHEN @Prefix+N''SQLSA_2_7'' THEN N''CK_snapshot_RetentionPolicy_PurgeIntervalMinutes'' WHEN @Prefix+N''SQLSA_2_8'' THEN N''CK_snapshot_RetentionPolicy_PurgeBatchRows'' WHEN @Prefix+N''SQLSA_2_9'' THEN N''CK_snapshot_RetentionPolicy_BudgetAction'' WHEN @Prefix+N''SQLSA_2_10'' THEN N''CK_snapshot_RetentionPolicy_SeedVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_2]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_5]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_6]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_6]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_7]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_7]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_8]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_8]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_9]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_9]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_2_10]',N'CONSTRAINT ['+@Prefix+N'SQLSA_2_10]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_2'); SET @ObjectId=OBJECT_ID(N'[snapshot].[RetentionPolicy]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[RetentionPolicy]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[RetentionPolicy] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[RetentionPolicy]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_RetentionPolicy' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_RetentionPolicy' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'UX_snapshot_RetentionPolicy_FrameworkDefault')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>1 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_RetentionPolicy_IsFrameworkDefault') THROW 53911,N'Missing canonical constraint: DF_snapshot_RetentionPolicy_IsFrameworkDefault',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_RetentionPolicy_LastUpdatedUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_RetentionPolicy_LastUpdatedUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_RetentionPolicy') THROW 53911,N'Missing canonical constraint: PK_snapshot_RetentionPolicy',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_RawRetentionDays') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_RawRetentionDays',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_PayloadRetentionDays') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_PayloadRetentionDays',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_RollupRetentionDays') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_RollupRetentionDays',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_SoftBudgetMB') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_SoftBudgetMB',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_PurgeIntervalMinutes') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_PurgeIntervalMinutes',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_PurgeBatchRows') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_PurgeBatchRows',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_BudgetAction') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_BudgetAction',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_RetentionPolicy_SeedVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_RetentionPolicy_SeedVersion',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>0 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_3]
(
[CollectorCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsEnabled] bit NOT NULL
              DEFAULT (1),
[CollectionIntervalSeconds] int NOT NULL,
[MaxRows] int NOT NULL,
[PayloadEnabled] bit NOT NULL,
[RetentionPolicyCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
PRIMARY KEY CLUSTERED ([CollectorCode]),
CHECK ([CollectorCode] IN ('PERFORMANCE_COUNTERS','WAIT_STATS')),
CHECK ([CollectionIntervalSeconds] BETWEEN 1 AND 3600),
CHECK ([MaxRows] BETWEEN 1 AND 100000),
CHECK ([SeedVersion] > 0)
);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_3]
(
[CollectorCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsEnabled] bit NOT NULL
              CONSTRAINT [SQLSA_3_0] DEFAULT (1),
[CollectionIntervalSeconds] int NOT NULL,
[MaxRows] int NOT NULL,
[PayloadEnabled] bit NOT NULL,
[RetentionPolicyCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [SQLSA_3_1]
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_3_2]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_3_3]
              PRIMARY KEY CLUSTERED ([CollectorCode]),
CONSTRAINT [SQLSA_3_4]
              CHECK ([CollectorCode] IN (''PERFORMANCE_COUNTERS'',''WAIT_STATS'')),
CONSTRAINT [SQLSA_3_5]
              CHECK ([CollectionIntervalSeconds] BETWEEN 1 AND 3600),
CONSTRAINT [SQLSA_3_6]
              CHECK ([MaxRows] BETWEEN 1 AND 100000),
CONSTRAINT [SQLSA_3_7]
              CHECK ([SeedVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_3_0'' THEN N''DF_snapshot_CollectorPolicy_IsEnabled'' WHEN @Prefix+N''SQLSA_3_1'' THEN N''DF_snapshot_CollectorPolicy_IsFrameworkDefault'' WHEN @Prefix+N''SQLSA_3_2'' THEN N''DF_snapshot_CollectorPolicy_LastUpdatedUtc'' WHEN @Prefix+N''SQLSA_3_3'' THEN N''PK_snapshot_CollectorPolicy'' WHEN @Prefix+N''SQLSA_3_4'' THEN N''CK_snapshot_CollectorPolicy_CollectorCode'' WHEN @Prefix+N''SQLSA_3_5'' THEN N''CK_snapshot_CollectorPolicy_CollectionIntervalSeconds'' WHEN @Prefix+N''SQLSA_3_6'' THEN N''CK_snapshot_CollectorPolicy_MaxRows'' WHEN @Prefix+N''SQLSA_3_7'' THEN N''CK_snapshot_CollectorPolicy_SeedVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_3]'') AND o.type IN(''D'',''C'');';
IF @SnapshotExpectedLegacy=1 SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_3]
(
[CollectorCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsEnabled] bit NOT NULL
              CONSTRAINT [SQLSA_3_0] DEFAULT (1),
[CollectionIntervalSeconds] int NOT NULL,
[MaxRows] int NOT NULL,
[PayloadEnabled] bit NOT NULL,
[RetentionPolicyCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [SQLSA_3_1]
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_3_2]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_3_3]
              PRIMARY KEY CLUSTERED ([CollectorCode]),
CONSTRAINT [SQLSA_3_4]
              CHECK ([CollectorCode] = ''PERFORMANCE_COUNTERS''),
CONSTRAINT [SQLSA_3_5]
              CHECK ([CollectionIntervalSeconds] BETWEEN 1 AND 3600),
CONSTRAINT [SQLSA_3_6]
              CHECK ([MaxRows] BETWEEN 1 AND 100000),
CONSTRAINT [SQLSA_3_7]
              CHECK ([SeedVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_3_0'' THEN N''DF_snapshot_CollectorPolicy_IsEnabled'' WHEN @Prefix+N''SQLSA_3_1'' THEN N''DF_snapshot_CollectorPolicy_IsFrameworkDefault'' WHEN @Prefix+N''SQLSA_3_2'' THEN N''DF_snapshot_CollectorPolicy_LastUpdatedUtc'' WHEN @Prefix+N''SQLSA_3_3'' THEN N''PK_snapshot_CollectorPolicy'' WHEN @Prefix+N''SQLSA_3_4'' THEN N''CK_snapshot_CollectorPolicy_CollectorCode'' WHEN @Prefix+N''SQLSA_3_5'' THEN N''CK_snapshot_CollectorPolicy_CollectionIntervalSeconds'' WHEN @Prefix+N''SQLSA_3_6'' THEN N''CK_snapshot_CollectorPolicy_MaxRows'' WHEN @Prefix+N''SQLSA_3_7'' THEN N''CK_snapshot_CollectorPolicy_SeedVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_3]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_5]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_6]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_6]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_3_7]',N'CONSTRAINT ['+@Prefix+N'SQLSA_3_7]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_3'); SET @ObjectId=OBJECT_ID(N'[snapshot].[CollectorPolicy]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[CollectorPolicy]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[CollectorPolicy] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[CollectorPolicy]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_CollectorPolicy' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_CollectorPolicy' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>0 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CollectorPolicy_IsEnabled') THROW 53911,N'Missing canonical constraint: DF_snapshot_CollectorPolicy_IsEnabled',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CollectorPolicy_IsFrameworkDefault') THROW 53911,N'Missing canonical constraint: DF_snapshot_CollectorPolicy_IsFrameworkDefault',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CollectorPolicy_LastUpdatedUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_CollectorPolicy_LastUpdatedUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_CollectorPolicy') THROW 53911,N'Missing canonical constraint: PK_snapshot_CollectorPolicy',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CollectorPolicy_CollectorCode') THROW 53911,N'Missing canonical constraint: CK_snapshot_CollectorPolicy_CollectorCode',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CollectorPolicy_CollectionIntervalSeconds') THROW 53911,N'Missing canonical constraint: CK_snapshot_CollectorPolicy_CollectionIntervalSeconds',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CollectorPolicy_MaxRows') THROW 53911,N'Missing canonical constraint: CK_snapshot_CollectorPolicy_MaxRows',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CollectorPolicy_SeedVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_CollectorPolicy_SeedVersion',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_CollectorPolicy_RetentionPolicy') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>1 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CollectorPolicy_RetentionPolicy' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[RetentionPolicy]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CollectorPolicy_RetentionPolicy')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CollectorPolicy_RetentionPolicy' AND ((fkc.constraint_column_id=1 AND pc.name=N'RetentionPolicyCode' AND rc.name=N'RetentionPolicyCode')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_4]
(
[CaptureRunId] bigint IDENTITY(1,1) NOT NULL,
[CollectorCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[SchedulerType] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[StartedAtUtc] datetime2(3) NOT NULL,
[EndedAtUtc] datetime2(3) NULL,
[SourceDatabaseName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[SqlServerStartTimeUtc] datetime2(3) NULL,
[ResetEpochId] uniqueidentifier NULL,
[ContractVersion] int NOT NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              DEFAULT (0),
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
[MetricSampleCount] bigint NOT NULL
              DEFAULT (0),
[PayloadCount] bigint NOT NULL
              DEFAULT (0),
PRIMARY KEY CLUSTERED ([CaptureRunId]),
CHECK ([SchedulerType] IN ('MANUAL','EXTERNAL','SQL_AGENT')),
CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
CHECK ([MetricSampleCount] >= 0),
CHECK ([PayloadCount] >= 0),
CHECK ([ContractVersion] > 0)
);
CREATE INDEX [IX_snapshot_CaptureRun_CollectorStarted]
        ON [#SnapshotTargetSchema_Expected_4]([CollectorCode],[StartedAtUtc] DESC,[CaptureRunId] DESC)
        INCLUDE ([EndedAtUtc],[StatusCode],[IsPartial],[SqlServerStartTimeUtc],[ResetEpochId]);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_4]
(
[CaptureRunId] bigint IDENTITY(1,1) NOT NULL,
[CollectorCode] varchar(64) COLLATE DATABASE_DEFAULT NOT NULL,
[SchedulerType] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[StartedAtUtc] datetime2(3) NOT NULL,
[EndedAtUtc] datetime2(3) NULL,
[SourceDatabaseName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[SqlServerStartTimeUtc] datetime2(3) NULL,
[ResetEpochId] uniqueidentifier NULL,
[ContractVersion] int NOT NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              CONSTRAINT [SQLSA_4_0] DEFAULT (0),
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
[MetricSampleCount] bigint NOT NULL
              CONSTRAINT [SQLSA_4_1] DEFAULT (0),
[PayloadCount] bigint NOT NULL
              CONSTRAINT [SQLSA_4_2] DEFAULT (0),
CONSTRAINT [SQLSA_4_3]
              PRIMARY KEY CLUSTERED ([CaptureRunId]),
CONSTRAINT [SQLSA_4_4]
              CHECK ([SchedulerType] IN (''MANUAL'',''EXTERNAL'',''SQL_AGENT'')),
CONSTRAINT [SQLSA_4_5]
              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
CONSTRAINT [SQLSA_4_6]
              CHECK ([MetricSampleCount] >= 0),
CONSTRAINT [SQLSA_4_7]
              CHECK ([PayloadCount] >= 0),
CONSTRAINT [SQLSA_4_8]
              CHECK ([ContractVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_4_0'' THEN N''DF_snapshot_CaptureRun_IsPartial'' WHEN @Prefix+N''SQLSA_4_1'' THEN N''DF_snapshot_CaptureRun_MetricSampleCount'' WHEN @Prefix+N''SQLSA_4_2'' THEN N''DF_snapshot_CaptureRun_PayloadCount'' WHEN @Prefix+N''SQLSA_4_3'' THEN N''PK_snapshot_CaptureRun'' WHEN @Prefix+N''SQLSA_4_4'' THEN N''CK_snapshot_CaptureRun_SchedulerType'' WHEN @Prefix+N''SQLSA_4_5'' THEN N''CK_snapshot_CaptureRun_EndedAtUtc'' WHEN @Prefix+N''SQLSA_4_6'' THEN N''CK_snapshot_CaptureRun_MetricSampleCount'' WHEN @Prefix+N''SQLSA_4_7'' THEN N''CK_snapshot_CaptureRun_PayloadCount'' WHEN @Prefix+N''SQLSA_4_8'' THEN N''CK_snapshot_CaptureRun_ContractVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_4]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_5]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_6]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_6]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_7]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_7]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_4_8]',N'CONSTRAINT ['+@Prefix+N'SQLSA_4_8]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_4'); SET @ObjectId=OBJECT_ID(N'[snapshot].[CaptureRun]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[CaptureRun]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[CaptureRun] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[CaptureRun]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_CaptureRun' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_CaptureRun' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'IX_snapshot_CaptureRun_CollectorStarted')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>1 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CaptureRun_IsPartial') THROW 53911,N'Missing canonical constraint: DF_snapshot_CaptureRun_IsPartial',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CaptureRun_MetricSampleCount') THROW 53911,N'Missing canonical constraint: DF_snapshot_CaptureRun_MetricSampleCount',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_CaptureRun_PayloadCount') THROW 53911,N'Missing canonical constraint: DF_snapshot_CaptureRun_PayloadCount',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_CaptureRun') THROW 53911,N'Missing canonical constraint: PK_snapshot_CaptureRun',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CaptureRun_SchedulerType') THROW 53911,N'Missing canonical constraint: CK_snapshot_CaptureRun_SchedulerType',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CaptureRun_EndedAtUtc') THROW 53911,N'Missing canonical constraint: CK_snapshot_CaptureRun_EndedAtUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CaptureRun_MetricSampleCount') THROW 53911,N'Missing canonical constraint: CK_snapshot_CaptureRun_MetricSampleCount',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CaptureRun_PayloadCount') THROW 53911,N'Missing canonical constraint: CK_snapshot_CaptureRun_PayloadCount',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_CaptureRun_ContractVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_CaptureRun_ContractVersion',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_CaptureRun_CollectorPolicy') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>1 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CaptureRun_CollectorPolicy' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[CollectorPolicy]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CaptureRun_CollectorPolicy')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_CaptureRun_CollectorPolicy' AND ((fkc.constraint_column_id=1 AND pc.name=N'CollectorCode' AND rc.name=N'CollectorCode')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_5]
(
[ModuleStatusId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ModuleName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[CollectionTimeUtc] datetime2(3) NOT NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              DEFAULT (0),
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
[EvidenceLimit] nvarchar(1000) COLLATE DATABASE_DEFAULT NULL,
PRIMARY KEY CLUSTERED ([ModuleStatusId]),
UNIQUE ([CaptureRunId],[ModuleName])
);
CREATE INDEX [IX_snapshot_ModuleStatus_CaptureRun]
        ON [#SnapshotTargetSchema_Expected_5]([CaptureRunId],[ModuleStatusId]);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_5]
(
[ModuleStatusId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ModuleName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[CollectionTimeUtc] datetime2(3) NOT NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              CONSTRAINT [SQLSA_5_0] DEFAULT (0),
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
[EvidenceLimit] nvarchar(1000) COLLATE DATABASE_DEFAULT NULL,
CONSTRAINT [SQLSA_5_1]
              PRIMARY KEY CLUSTERED ([ModuleStatusId]),
CONSTRAINT [SQLSA_5_2]
              UNIQUE ([CaptureRunId],[ModuleName])
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_5_0'' THEN N''DF_snapshot_ModuleStatus_IsPartial'' WHEN @Prefix+N''SQLSA_5_1'' THEN N''PK_snapshot_ModuleStatus'' WHEN @Prefix+N''SQLSA_5_2'' THEN N''UQ_snapshot_ModuleStatus_RunModule'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_5]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_5_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_5_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_5_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_5_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_5_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_5_2]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_5'); SET @ObjectId=OBJECT_ID(N'[snapshot].[ModuleStatus]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[ModuleStatus]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[ModuleStatus] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[ModuleStatus]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_ModuleStatus' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_ModuleStatus_RunModule' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_ModuleStatus' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_ModuleStatus_RunModule' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'IX_snapshot_ModuleStatus_CaptureRun')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>1 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_ModuleStatus_IsPartial') THROW 53911,N'Missing canonical constraint: DF_snapshot_ModuleStatus_IsPartial',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_ModuleStatus') THROW 53911,N'Missing canonical constraint: PK_snapshot_ModuleStatus',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'UQ_snapshot_ModuleStatus_RunModule') THROW 53911,N'Missing canonical constraint: UQ_snapshot_ModuleStatus_RunModule',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_ModuleStatus_CaptureRun') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>1 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_ModuleStatus_CaptureRun' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[CaptureRun]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_ModuleStatus_CaptureRun')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_ModuleStatus_CaptureRun' AND ((fkc.constraint_column_id=1 AND pc.name=N'CaptureRunId' AND rc.name=N'CaptureRunId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_6]
(
[ScopeId] bigint IDENTITY(1,1) NOT NULL,
[ScopeType] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[ParentScopeId] bigint NULL,
[ScopeKeyHash] varbinary(32) NOT NULL,
[ScopeIdentityJson] nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
[CreatedAtUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
PRIMARY KEY CLUSTERED ([ScopeId]),
UNIQUE ([ScopeType],[ScopeKeyHash]),
CHECK ([ScopeType] IN ('SERVER','PERFORMANCE_COUNTER','WAIT_TYPE')),
CHECK (DATALENGTH([ScopeKeyHash]) = 32),
CHECK (ISJSON([ScopeIdentityJson]) = 1)
);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_6]
(
[ScopeId] bigint IDENTITY(1,1) NOT NULL,
[ScopeType] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[ParentScopeId] bigint NULL,
[ScopeKeyHash] varbinary(32) NOT NULL,
[ScopeIdentityJson] nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
[CreatedAtUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_6_0]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_6_1]
              PRIMARY KEY CLUSTERED ([ScopeId]),
CONSTRAINT [SQLSA_6_2]
              UNIQUE ([ScopeType],[ScopeKeyHash]),
CONSTRAINT [SQLSA_6_3]
              CHECK ([ScopeType] IN (''SERVER'',''PERFORMANCE_COUNTER'',''WAIT_TYPE'')),
CONSTRAINT [SQLSA_6_4]
              CHECK (DATALENGTH([ScopeKeyHash]) = 32),
CONSTRAINT [SQLSA_6_5]
              CHECK (ISJSON([ScopeIdentityJson]) = 1)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_6_0'' THEN N''DF_snapshot_Scope_CreatedAtUtc'' WHEN @Prefix+N''SQLSA_6_1'' THEN N''PK_snapshot_Scope'' WHEN @Prefix+N''SQLSA_6_2'' THEN N''UQ_snapshot_Scope_TypeKeyHash'' WHEN @Prefix+N''SQLSA_6_3'' THEN N''CK_snapshot_Scope_ScopeType'' WHEN @Prefix+N''SQLSA_6_4'' THEN N''CK_snapshot_Scope_ScopeKeyHash'' WHEN @Prefix+N''SQLSA_6_5'' THEN N''CK_snapshot_Scope_ScopeIdentityJson'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_6]'') AND o.type IN(''D'',''C'');';
IF @SnapshotExpectedLegacy=1 SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_6]
(
[ScopeId] bigint IDENTITY(1,1) NOT NULL,
[ScopeType] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[ParentScopeId] bigint NULL,
[ScopeKeyHash] varbinary(32) NOT NULL,
[ScopeIdentityJson] nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
[CreatedAtUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_6_0]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_6_1]
              PRIMARY KEY CLUSTERED ([ScopeId]),
CONSTRAINT [SQLSA_6_2]
              UNIQUE ([ScopeType],[ScopeKeyHash]),
CONSTRAINT [SQLSA_6_3]
              CHECK ([ScopeType] IN (''SERVER'',''PERFORMANCE_COUNTER'')),
CONSTRAINT [SQLSA_6_4]
              CHECK (DATALENGTH([ScopeKeyHash]) = 32),
CONSTRAINT [SQLSA_6_5]
              CHECK (ISJSON([ScopeIdentityJson]) = 1)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_6_0'' THEN N''DF_snapshot_Scope_CreatedAtUtc'' WHEN @Prefix+N''SQLSA_6_1'' THEN N''PK_snapshot_Scope'' WHEN @Prefix+N''SQLSA_6_2'' THEN N''UQ_snapshot_Scope_TypeKeyHash'' WHEN @Prefix+N''SQLSA_6_3'' THEN N''CK_snapshot_Scope_ScopeType'' WHEN @Prefix+N''SQLSA_6_4'' THEN N''CK_snapshot_Scope_ScopeKeyHash'' WHEN @Prefix+N''SQLSA_6_5'' THEN N''CK_snapshot_Scope_ScopeIdentityJson'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_6]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_6_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_6_5]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_6'); SET @ObjectId=OBJECT_ID(N'[snapshot].[Scope]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[Scope]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[Scope] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[Scope]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_Scope' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_Scope_TypeKeyHash' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_Scope' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_Scope_TypeKeyHash' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>0 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_Scope_CreatedAtUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_Scope_CreatedAtUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_Scope') THROW 53911,N'Missing canonical constraint: PK_snapshot_Scope',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'UQ_snapshot_Scope_TypeKeyHash') THROW 53911,N'Missing canonical constraint: UQ_snapshot_Scope_TypeKeyHash',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_Scope_ScopeType') THROW 53911,N'Missing canonical constraint: CK_snapshot_Scope_ScopeType',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_Scope_ScopeKeyHash') THROW 53911,N'Missing canonical constraint: CK_snapshot_Scope_ScopeKeyHash',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_Scope_ScopeIdentityJson') THROW 53911,N'Missing canonical constraint: CK_snapshot_Scope_ScopeIdentityJson',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_Scope_ParentScope') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>1 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_Scope_ParentScope' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[Scope]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_Scope_ParentScope')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_Scope_ParentScope' AND ((fkc.constraint_column_id=1 AND pc.name=N'ParentScopeId' AND rc.name=N'ScopeId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_7]
(
[MetricDefinitionId] bigint IDENTITY(1,1) NOT NULL,
[MetricCode] varchar(96) COLLATE DATABASE_DEFAULT NOT NULL,
[ValueType] varchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
[Unit] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[ContractVersion] int NOT NULL,
[Description] nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              DEFAULT (SYSUTCDATETIME()),
PRIMARY KEY CLUSTERED ([MetricDefinitionId]),
UNIQUE ([MetricCode]),
CHECK ([ValueType] IN ('NUMERIC','BIGINT','STRING')),
CHECK ([ContractVersion] > 0),
CHECK ([SeedVersion] > 0)
);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_7]
(
[MetricDefinitionId] bigint IDENTITY(1,1) NOT NULL,
[MetricCode] varchar(96) COLLATE DATABASE_DEFAULT NOT NULL,
[ValueType] varchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
[Unit] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[ContractVersion] int NOT NULL,
[Description] nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL,
[IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [SQLSA_7_0]
              DEFAULT (0),
[SeedVersion] int NOT NULL,
[LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [SQLSA_7_1]
              DEFAULT (SYSUTCDATETIME()),
CONSTRAINT [SQLSA_7_2]
              PRIMARY KEY CLUSTERED ([MetricDefinitionId]),
CONSTRAINT [SQLSA_7_3]
              UNIQUE ([MetricCode]),
CONSTRAINT [SQLSA_7_4]
              CHECK ([ValueType] IN (''NUMERIC'',''BIGINT'',''STRING'')),
CONSTRAINT [SQLSA_7_5]
              CHECK ([ContractVersion] > 0),
CONSTRAINT [SQLSA_7_6]
              CHECK ([SeedVersion] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_7_0'' THEN N''DF_snapshot_MetricDefinition_IsFrameworkDefault'' WHEN @Prefix+N''SQLSA_7_1'' THEN N''DF_snapshot_MetricDefinition_LastUpdatedUtc'' WHEN @Prefix+N''SQLSA_7_2'' THEN N''PK_snapshot_MetricDefinition'' WHEN @Prefix+N''SQLSA_7_3'' THEN N''UQ_snapshot_MetricDefinition_MetricCode'' WHEN @Prefix+N''SQLSA_7_4'' THEN N''CK_snapshot_MetricDefinition_ValueType'' WHEN @Prefix+N''SQLSA_7_5'' THEN N''CK_snapshot_MetricDefinition_ContractVersion'' WHEN @Prefix+N''SQLSA_7_6'' THEN N''CK_snapshot_MetricDefinition_SeedVersion'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_7]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_5]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_7_6]',N'CONSTRAINT ['+@Prefix+N'SQLSA_7_6]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_7'); SET @ObjectId=OBJECT_ID(N'[snapshot].[MetricDefinition]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[MetricDefinition]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[MetricDefinition] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[MetricDefinition]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_MetricDefinition' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_MetricDefinition_MetricCode' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_MetricDefinition' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_MetricDefinition_MetricCode' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>0 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_MetricDefinition_IsFrameworkDefault') THROW 53911,N'Missing canonical constraint: DF_snapshot_MetricDefinition_IsFrameworkDefault',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_MetricDefinition_LastUpdatedUtc') THROW 53911,N'Missing canonical constraint: DF_snapshot_MetricDefinition_LastUpdatedUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_MetricDefinition') THROW 53911,N'Missing canonical constraint: PK_snapshot_MetricDefinition',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'UQ_snapshot_MetricDefinition_MetricCode') THROW 53911,N'Missing canonical constraint: UQ_snapshot_MetricDefinition_MetricCode',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_MetricDefinition_ValueType') THROW 53911,N'Missing canonical constraint: CK_snapshot_MetricDefinition_ValueType',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_MetricDefinition_ContractVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_MetricDefinition_ContractVersion',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_MetricDefinition_SeedVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_MetricDefinition_SeedVersion',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>0 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_8]
(
[MetricSampleId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ScopeId] bigint NOT NULL,
[MetricDefinitionId] bigint NOT NULL,
[CollectedAtUtc] datetime2(3) NOT NULL,
[ResetEpochId] uniqueidentifier NOT NULL,
[NumericValue] decimal(38,6) NULL,
[BigintValue] bigint NULL,
[StringValue] nvarchar(4000) COLLATE DATABASE_DEFAULT NULL,
[QualityCode] varchar(80) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              DEFAULT (0),
PRIMARY KEY CLUSTERED ([MetricSampleId]),
UNIQUE ([CaptureRunId],[ScopeId],[MetricDefinitionId]),
CHECK
              (
                  (CASE WHEN [NumericValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [BigintValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [StringValue] IS NULL THEN 0 ELSE 1 END) = 1
              )
);
CREATE INDEX [IX_snapshot_MetricSample_CollectedAtUtc]
        ON [#SnapshotTargetSchema_Expected_8]([CollectedAtUtc],[MetricSampleId])
        INCLUDE ([CaptureRunId],[ScopeId],[MetricDefinitionId]);
CREATE INDEX [IX_snapshot_MetricSample_ScopeMetricTime]
        ON [#SnapshotTargetSchema_Expected_8]([ScopeId],[MetricDefinitionId],[CollectedAtUtc] DESC)
        INCLUDE ([ResetEpochId],[NumericValue],[BigintValue],[QualityCode],[IsPartial]);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_8]
(
[MetricSampleId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ScopeId] bigint NOT NULL,
[MetricDefinitionId] bigint NOT NULL,
[CollectedAtUtc] datetime2(3) NOT NULL,
[ResetEpochId] uniqueidentifier NOT NULL,
[NumericValue] decimal(38,6) NULL,
[BigintValue] bigint NULL,
[StringValue] nvarchar(4000) COLLATE DATABASE_DEFAULT NULL,
[QualityCode] varchar(80) COLLATE DATABASE_DEFAULT NOT NULL,
[IsPartial] bit NOT NULL
              CONSTRAINT [SQLSA_8_0] DEFAULT (0),
CONSTRAINT [SQLSA_8_1]
              PRIMARY KEY CLUSTERED ([MetricSampleId]),
CONSTRAINT [SQLSA_8_2]
              UNIQUE ([CaptureRunId],[ScopeId],[MetricDefinitionId]),
CONSTRAINT [SQLSA_8_3]
              CHECK
              (
                  (CASE WHEN [NumericValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [BigintValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [StringValue] IS NULL THEN 0 ELSE 1 END) = 1
              )
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_8_0'' THEN N''DF_snapshot_MetricSample_IsPartial'' WHEN @Prefix+N''SQLSA_8_1'' THEN N''PK_snapshot_MetricSample'' WHEN @Prefix+N''SQLSA_8_2'' THEN N''UQ_snapshot_MetricSample_RunScopeMetric'' WHEN @Prefix+N''SQLSA_8_3'' THEN N''CK_snapshot_MetricSample_ExactlyOneValue'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_8]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_8_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_8_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_8_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_8_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_8_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_8_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_8_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_8_3]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_8'); SET @ObjectId=OBJECT_ID(N'[snapshot].[MetricSample]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[MetricSample]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[MetricSample] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[MetricSample]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_MetricSample' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_MetricSample_RunScopeMetric' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_MetricSample' WHEN i.is_unique_constraint=1 THEN N'UQ_snapshot_MetricSample_RunScopeMetric' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'IX_snapshot_MetricSample_CollectedAtUtc',N'IX_snapshot_MetricSample_ScopeMetricTime')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>2 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_MetricSample_IsPartial') THROW 53911,N'Missing canonical constraint: DF_snapshot_MetricSample_IsPartial',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_MetricSample') THROW 53911,N'Missing canonical constraint: PK_snapshot_MetricSample',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'UQ_snapshot_MetricSample_RunScopeMetric') THROW 53911,N'Missing canonical constraint: UQ_snapshot_MetricSample_RunScopeMetric',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_MetricSample_ExactlyOneValue') THROW 53911,N'Missing canonical constraint: CK_snapshot_MetricSample_ExactlyOneValue',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_MetricSample_CaptureRun',N'FK_snapshot_MetricSample_Scope',N'FK_snapshot_MetricSample_MetricDefinition') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>3 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_CaptureRun' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[CaptureRun]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_CaptureRun')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_CaptureRun' AND ((fkc.constraint_column_id=1 AND pc.name=N'CaptureRunId' AND rc.name=N'CaptureRunId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_Scope' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[Scope]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_Scope')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_Scope' AND ((fkc.constraint_column_id=1 AND pc.name=N'ScopeId' AND rc.name=N'ScopeId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_MetricDefinition' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[MetricDefinition]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_MetricDefinition')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_MetricSample_MetricDefinition' AND ((fkc.constraint_column_id=1 AND pc.name=N'MetricDefinitionId' AND rc.name=N'MetricDefinitionId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_9]
(
[PayloadSnapshotId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ModuleName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[CapturedAtUtc] datetime2(3) NOT NULL,
[PayloadFormat] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[PayloadContractVersion] int NOT NULL,
[CompressionType] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[PayloadHash] varbinary(32) NOT NULL,
[Payload] varbinary(max) NOT NULL,
[UncompressedCharacterCount] bigint NOT NULL,
PRIMARY KEY CLUSTERED ([PayloadSnapshotId]),
CHECK ([PayloadFormat] IN ('JSON','TEXT','XML','SQL_TEXT','PLAN_XML','ERROR_CONTEXT','PATH')),
CHECK ([PayloadContractVersion] > 0),
CHECK ([CompressionType] IN ('NONE','GZIP')),
CHECK (DATALENGTH([PayloadHash]) = 32),
CHECK ([UncompressedCharacterCount] >= 0)
);
CREATE INDEX [IX_snapshot_PayloadSnapshot_CapturedAtUtc]
        ON [#SnapshotTargetSchema_Expected_9]([CapturedAtUtc],[PayloadSnapshotId])
        INCLUDE ([CaptureRunId],[ModuleName],[PayloadFormat]);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_9]
(
[PayloadSnapshotId] bigint IDENTITY(1,1) NOT NULL,
[CaptureRunId] bigint NOT NULL,
[ModuleName] sysname COLLATE DATABASE_DEFAULT NOT NULL,
[CapturedAtUtc] datetime2(3) NOT NULL,
[PayloadFormat] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[PayloadContractVersion] int NOT NULL,
[CompressionType] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL,
[PayloadHash] varbinary(32) NOT NULL,
[Payload] varbinary(max) NOT NULL,
[UncompressedCharacterCount] bigint NOT NULL,
CONSTRAINT [SQLSA_9_0]
              PRIMARY KEY CLUSTERED ([PayloadSnapshotId]),
CONSTRAINT [SQLSA_9_1]
              CHECK ([PayloadFormat] IN (''JSON'',''TEXT'',''XML'',''SQL_TEXT'',''PLAN_XML'',''ERROR_CONTEXT'',''PATH'')),
CONSTRAINT [SQLSA_9_2]
              CHECK ([PayloadContractVersion] > 0),
CONSTRAINT [SQLSA_9_3]
              CHECK ([CompressionType] IN (''NONE'',''GZIP'')),
CONSTRAINT [SQLSA_9_4]
              CHECK (DATALENGTH([PayloadHash]) = 32),
CONSTRAINT [SQLSA_9_5]
              CHECK ([UncompressedCharacterCount] >= 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_9_0'' THEN N''PK_snapshot_PayloadSnapshot'' WHEN @Prefix+N''SQLSA_9_1'' THEN N''CK_snapshot_PayloadSnapshot_PayloadFormat'' WHEN @Prefix+N''SQLSA_9_2'' THEN N''CK_snapshot_PayloadSnapshot_PayloadContractVersion'' WHEN @Prefix+N''SQLSA_9_3'' THEN N''CK_snapshot_PayloadSnapshot_CompressionType'' WHEN @Prefix+N''SQLSA_9_4'' THEN N''CK_snapshot_PayloadSnapshot_PayloadHash'' WHEN @Prefix+N''SQLSA_9_5'' THEN N''CK_snapshot_PayloadSnapshot_UncompressedCharacterCount'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_9]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_9_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_9_5]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_9'); SET @ObjectId=OBJECT_ID(N'[snapshot].[PayloadSnapshot]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[PayloadSnapshot]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[PayloadSnapshot] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[PayloadSnapshot]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PayloadSnapshot' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PayloadSnapshot' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'IX_snapshot_PayloadSnapshot_CapturedAtUtc')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>1 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_PayloadSnapshot') THROW 53911,N'Missing canonical constraint: PK_snapshot_PayloadSnapshot',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PayloadSnapshot_PayloadFormat') THROW 53911,N'Missing canonical constraint: CK_snapshot_PayloadSnapshot_PayloadFormat',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PayloadSnapshot_PayloadContractVersion') THROW 53911,N'Missing canonical constraint: CK_snapshot_PayloadSnapshot_PayloadContractVersion',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PayloadSnapshot_CompressionType') THROW 53911,N'Missing canonical constraint: CK_snapshot_PayloadSnapshot_CompressionType',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PayloadSnapshot_PayloadHash') THROW 53911,N'Missing canonical constraint: CK_snapshot_PayloadSnapshot_PayloadHash',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PayloadSnapshot_UncompressedCharacterCount') THROW 53911,N'Missing canonical constraint: CK_snapshot_PayloadSnapshot_UncompressedCharacterCount',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'FK_snapshot_PayloadSnapshot_CaptureRun') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>1 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_PayloadSnapshot_CaptureRun' AND fk.referenced_object_id=OBJECT_ID(N'[snapshot].[CaptureRun]')) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_PayloadSnapshot_CaptureRun')<>1 OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name=N'FK_snapshot_PayloadSnapshot_CaptureRun' AND ((fkc.constraint_column_id=1 AND pc.name=N'CaptureRunId' AND rc.name=N'CaptureRunId')))<>1 THROW 53912,N'Foreign-key column contract mismatch.',1;
END;
CREATE TABLE [#SnapshotTargetSchema_Expected_10]
(
[PurgeRunId] bigint IDENTITY(1,1) NOT NULL,
[StartedAtUtc] datetime2(3) NOT NULL,
[EndedAtUtc] datetime2(3) NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[BatchesExecuted] int NOT NULL
              DEFAULT (0),
[MetricRowsDeleted] bigint NOT NULL
              DEFAULT (0),
[PayloadRowsDeleted] bigint NOT NULL
              DEFAULT (0),
[ModuleRowsDeleted] bigint NOT NULL
              DEFAULT (0),
[CaptureRunsDeleted] bigint NOT NULL
              DEFAULT (0),
[ScopeRowsDeleted] bigint NOT NULL
              DEFAULT (0),
[UsedDataMbBefore] decimal(19,3) NULL,
[UsedDataMbAfter] decimal(19,3) NULL,
[SoftBudgetMb] bigint NOT NULL,
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
PRIMARY KEY CLUSTERED ([PurgeRunId]),
CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
CHECK ([BatchesExecuted] >= 0),
CHECK ([MetricRowsDeleted] >= 0
                 AND [PayloadRowsDeleted] >= 0
                 AND [ModuleRowsDeleted] >= 0
                 AND [CaptureRunsDeleted] >= 0
                 AND [ScopeRowsDeleted] >= 0),
CHECK ([SoftBudgetMb] > 0)
);
CREATE INDEX [IX_snapshot_PurgeRun_StartedAtUtc]
        ON [#SnapshotTargetSchema_Expected_10]([StartedAtUtc] DESC,[PurgeRunId] DESC)
        INCLUDE ([EndedAtUtc],[StatusCode]);
DELETE FROM #SnapshotTargetSchema_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')+N'_';
SET @ConstraintSql=N'CREATE TABLE [#SnapshotTargetSchema_ConstraintRef_10]
(
[PurgeRunId] bigint IDENTITY(1,1) NOT NULL,
[StartedAtUtc] datetime2(3) NOT NULL,
[EndedAtUtc] datetime2(3) NULL,
[StatusCode] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
[BatchesExecuted] int NOT NULL
              CONSTRAINT [SQLSA_10_0] DEFAULT (0),
[MetricRowsDeleted] bigint NOT NULL
              CONSTRAINT [SQLSA_10_1] DEFAULT (0),
[PayloadRowsDeleted] bigint NOT NULL
              CONSTRAINT [SQLSA_10_2] DEFAULT (0),
[ModuleRowsDeleted] bigint NOT NULL
              CONSTRAINT [SQLSA_10_3] DEFAULT (0),
[CaptureRunsDeleted] bigint NOT NULL
              CONSTRAINT [SQLSA_10_4] DEFAULT (0),
[ScopeRowsDeleted] bigint NOT NULL
              CONSTRAINT [SQLSA_10_5] DEFAULT (0),
[UsedDataMbBefore] decimal(19,3) NULL,
[UsedDataMbAfter] decimal(19,3) NULL,
[SoftBudgetMb] bigint NOT NULL,
[ErrorNumber] int NULL,
[ErrorMessage] nvarchar(2048) COLLATE DATABASE_DEFAULT NULL,
CONSTRAINT [SQLSA_10_6]
              PRIMARY KEY CLUSTERED ([PurgeRunId]),
CONSTRAINT [SQLSA_10_7]
              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc]),
CONSTRAINT [SQLSA_10_8]
              CHECK ([BatchesExecuted] >= 0),
CONSTRAINT [SQLSA_10_9]
              CHECK ([MetricRowsDeleted] >= 0
                 AND [PayloadRowsDeleted] >= 0
                 AND [ModuleRowsDeleted] >= 0
                 AND [CaptureRunsDeleted] >= 0
                 AND [ScopeRowsDeleted] >= 0),
CONSTRAINT [SQLSA_10_10]
              CHECK ([SoftBudgetMb] > 0)
);
INSERT #SnapshotTargetSchema_ConstraintMap SELECT CASE o.name WHEN @Prefix+N''SQLSA_10_0'' THEN N''DF_snapshot_PurgeRun_BatchesExecuted'' WHEN @Prefix+N''SQLSA_10_1'' THEN N''DF_snapshot_PurgeRun_MetricRowsDeleted'' WHEN @Prefix+N''SQLSA_10_2'' THEN N''DF_snapshot_PurgeRun_PayloadRowsDeleted'' WHEN @Prefix+N''SQLSA_10_3'' THEN N''DF_snapshot_PurgeRun_ModuleRowsDeleted'' WHEN @Prefix+N''SQLSA_10_4'' THEN N''DF_snapshot_PurgeRun_CaptureRunsDeleted'' WHEN @Prefix+N''SQLSA_10_5'' THEN N''DF_snapshot_PurgeRun_ScopeRowsDeleted'' WHEN @Prefix+N''SQLSA_10_6'' THEN N''PK_snapshot_PurgeRun'' WHEN @Prefix+N''SQLSA_10_7'' THEN N''CK_snapshot_PurgeRun_EndedAtUtc'' WHEN @Prefix+N''SQLSA_10_8'' THEN N''CK_snapshot_PurgeRun_BatchesExecuted'' WHEN @Prefix+N''SQLSA_10_9'' THEN N''CK_snapshot_PurgeRun_DeletedRows'' WHEN @Prefix+N''SQLSA_10_10'' THEN N''CK_snapshot_PurgeRun_SoftBudgetMb'' END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID(N''tempdb..[#SnapshotTargetSchema_ConstraintRef_10]'') AND o.type IN(''D'',''C'');';
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_0]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_0]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_1]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_1]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_2]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_2]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_3]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_3]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_4]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_4]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_5]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_5]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_6]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_6]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_7]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_7]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_8]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_8]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_9]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_9]');
SET @ConstraintSql=REPLACE(@ConstraintSql,N'CONSTRAINT [SQLSA_10_10]',N'CONSTRAINT ['+@Prefix+N'SQLSA_10_10]');
EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;
SET @ExpectedId=OBJECT_ID(N'tempdb..#SnapshotTargetSchema_Expected_10'); SET @ObjectId=OBJECT_ID(N'[snapshot].[PurgeRun]');
IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,N'Wrong table object type: [snapshot].[PurgeRun]',1;
IF @ObjectId IS NOT NULL BEGIN
SELECT TOP(1) @LockCount=1 FROM [snapshot].[PurgeRun] WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;
IF EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT [column_id],[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed] FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,N'Column contract mismatch: [snapshot].[PurgeRun]',1;
IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;
IF EXISTS(SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))) OR EXISTS(SELECT ParentColumn,CanonicalName,Definition FROM #SnapshotTargetSchema_ConstraintMap k WHERE ConstraintType='D' AND (ParentColumn NOT IN (N'') OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn)) EXCEPT SELECT c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF EXISTS(SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId EXCEPT SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C') OR EXISTS(SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SnapshotTargetSchema_ConstraintMap WHERE ConstraintType='C' EXCEPT SELECT d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication FROM sys.check_constraints d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId) THROW 53908,N'Constraint contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;
IF EXISTS(SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId EXCEPT SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PurgeRun' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId) OR EXISTS(SELECT CASE WHEN i.is_primary_key=1 THEN N'PK_snapshot_PurgeRun' WHEN i.is_unique_constraint=1 THEN N'' ELSE i.name COLLATE DATABASE_DEFAULT END,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId EXCEPT SELECT i.name COLLATE DATABASE_DEFAULT,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId) THROW 53909,N'Index contract mismatch.',1;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN (N'IX_snapshot_PurgeRun_StartedAtUtc')) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>1 THROW 53910,N'Additional or missing named index.',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_BatchesExecuted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_BatchesExecuted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_MetricRowsDeleted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_MetricRowsDeleted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_PayloadRowsDeleted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_PayloadRowsDeleted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_ModuleRowsDeleted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_ModuleRowsDeleted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_CaptureRunsDeleted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_CaptureRunsDeleted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'DF_snapshot_PurgeRun_ScopeRowsDeleted') THROW 53911,N'Missing canonical constraint: DF_snapshot_PurgeRun_ScopeRowsDeleted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'PK_snapshot_PurgeRun') THROW 53911,N'Missing canonical constraint: PK_snapshot_PurgeRun',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PurgeRun_EndedAtUtc') THROW 53911,N'Missing canonical constraint: CK_snapshot_PurgeRun_EndedAtUtc',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PurgeRun_BatchesExecuted') THROW 53911,N'Missing canonical constraint: CK_snapshot_PurgeRun_BatchesExecuted',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PurgeRun_DeletedRows') THROW 53911,N'Missing canonical constraint: CK_snapshot_PurgeRun_DeletedRows',1;
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name=N'CK_snapshot_PurgeRun_SoftBudgetMb') THROW 53911,N'Missing canonical constraint: CK_snapshot_PurgeRun_SoftBudgetMb',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN (N'') OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>0 THROW 53912,N'Foreign-key contract mismatch.',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SnapshotTargetSchema_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;
END;
IF OBJECT_ID(N'[snapshot].[InternalConfigureSnapshotPolicy]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalConfigureSnapshotPolicy]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalConfigureSnapshotPolicy]',1;
IF OBJECT_ID(N'[snapshot].[InternalPrepareCollectionCycle]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalPrepareCollectionCycle]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalPrepareCollectionCycle]',1;
IF OBJECT_ID(N'[snapshot].[InternalCompletePerformanceCounterCycle]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalCompletePerformanceCounterCycle]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalCompletePerformanceCounterCycle]',1;
IF OBJECT_ID(N'[snapshot].[InternalCompleteWaitStatsCycle]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalCompleteWaitStatsCycle]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalCompleteWaitStatsCycle]',1;
IF OBJECT_ID(N'[snapshot].[InternalFinalizeCollectionCycle]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalFinalizeCollectionCycle]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalFinalizeCollectionCycle]',1;
IF OBJECT_ID(N'[snapshot].[InternalPurgeExpiredData]') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'[snapshot].[InternalPurgeExpiredData]') AND type=N'P') THROW 53913,N'Module object type mismatch: [snapshot].[InternalPurgeExpiredData]',1;
IF OBJECT_ID(N'[snapshot].[MetricDefinition]',N'U') IS NOT NULL EXEC sys.sp_executesql N'DECLARE @SnapshotWaitExpectedMetrics TABLE
(
    [MetricCode] varchar(96) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    [ValueType] varchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
    [Unit] varchar(40) COLLATE DATABASE_DEFAULT NOT NULL,
    [Description] nvarchar(1000) COLLATE DATABASE_DEFAULT NOT NULL
);
INSERT @SnapshotWaitExpectedMetrics ([MetricCode],[ValueType],[Unit],[Description])
VALUES
 (''WAIT_TASK_COUNT'',''BIGINT'',''count'',N''Unveränderter nativer kumulativer Wait-Taskcounter.''),
 (''WAIT_TIME_MS'',''BIGINT'',''ms'',N''Unveränderte native kumulative gesamte Waitzeit.''),
 (''WAIT_SIGNAL_TIME_MS'',''BIGINT'',''ms'',N''Unveränderte native kumulative Signalwaitzeit.''),
 (''WAIT_MAX_TIME_MS'',''BIGINT'',''ms'',N''Native bisherige maximale Waitzeit; kein additiver Counter.''),
 (''WAIT_TASK_COUNT_DELTA_CANDIDATE'',''BIGINT'',''count'',N''Monotone Taskdifferenz mit unbewiesener Resetkontinuität.''),
 (''WAIT_TIME_MS_DELTA_CANDIDATE'',''BIGINT'',''ms'',N''Monotone Waitzeitdifferenz mit unbewiesener Resetkontinuität.''),
 (''WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE'',''BIGINT'',''ms'',N''Monotone Signalzeitdifferenz mit unbewiesener Resetkontinuität.''),
 (''WAIT_DELTA_STATUS'',''STRING'',''status'',N''Expliziter Status für Differenzkandidaten oder ihre Unterdrückung.''),
 (''WAIT_CAPTURE_CONTEXT'',''STRING'',''json'',N''Versionierter Aufnahme-, Rohwert- und Vergleichskontext auf SERVER-Scope.'');
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
    THROW 53760,N''Eine vorhandene Waitmetrik widerspricht dem Metrikvertrag.'',1;
';
IF OBJECT_ID(N'[snapshot].[InternalCompleteWaitStatsCycle]',N'P') IS NOT NULL AND OBJECT_ID(N'[snapshot].[PackageVersion]',N'U') IS NOT NULL EXEC sys.sp_executesql N'IF NOT EXISTS(SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),PackageCode)=CONVERT(varbinary(max),''SC-023'') AND CONVERT(varbinary(max),PackageVersion) IN(CONVERT(varbinary(max),''1.2.0''),CONVERT(varbinary(max),''1.2.1'')) AND SchemaVersion=2) AND (OBJECT_DEFINITION(OBJECT_ID(N''[snapshot].[InternalCompleteWaitStatsCycle]'',N''P'')) IS NULL OR HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N'' '' FROM REPLACE(OBJECT_DEFINITION(OBJECT_ID(N''[snapshot].[InternalCompleteWaitStatsCycle]'',N''P'')),NCHAR(13)+NCHAR(10),NCHAR(10))))) NOT IN(0xaeb295d67a15ce0fcf452404dde233729012e42340c138c8924f27447e1b8762,0xe392b9581c55955b81674e468aa88eac444339585dfd787a682abf66b3a48c49)) THROW 53762,N''A noncanonical object occupies the new Wait helper name.'',1;';
DROP TABLE #SnapshotTargetSchema_ConstraintMap,#SnapshotTargetSchema_KnownForeignKeys,[#SnapshotTargetSchema_Expected_1],[#SnapshotTargetSchema_Expected_2],[#SnapshotTargetSchema_Expected_3],[#SnapshotTargetSchema_Expected_4],[#SnapshotTargetSchema_Expected_5],[#SnapshotTargetSchema_Expected_6],[#SnapshotTargetSchema_Expected_7],[#SnapshotTargetSchema_Expected_8],[#SnapshotTargetSchema_Expected_9],[#SnapshotTargetSchema_Expected_10];
SET LOCK_TIMEOUT 0;
-- SNAPSHOT_SCHEMA_PREFLIGHT_END
IF @SnapshotExpectedLegacy=1
BEGIN
    ALTER TABLE [snapshot].[CollectorPolicy] DROP CONSTRAINT [CK_snapshot_CollectorPolicy_CollectorCode];
    ALTER TABLE [snapshot].[CollectorPolicy] WITH CHECK ADD CONSTRAINT [CK_snapshot_CollectorPolicy_CollectorCode] CHECK ([CollectorCode] IN ('PERFORMANCE_COUNTERS','WAIT_STATS'));
    SET @SnapshotMigrationStage=1;
    ALTER TABLE [snapshot].[Scope] DROP CONSTRAINT [CK_snapshot_Scope_ScopeType];
    ALTER TABLE [snapshot].[Scope] WITH CHECK ADD CONSTRAINT [CK_snapshot_Scope_ScopeType] CHECK ([ScopeType] IN ('SERVER','PERFORMANCE_COUNTER','WAIT_TYPE'));
    SET @SnapshotMigrationStage=2;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[schemas] AS [s] WITH (NOLOCK)
    WHERE [s].[name] = N'snapshot'
)
BEGIN
    EXEC [sys].[sp_executesql]
         N'CREATE SCHEMA [snapshot] AUTHORIZATION [dbo];';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'PackageVersion'
)
BEGIN
    CREATE TABLE [snapshot].[PackageVersion]
    (
          [PackageCode] varchar(32) NOT NULL
        , [PackageVersion] varchar(16) NOT NULL
        , [SchemaVersion] int NOT NULL
        , [InstalledAtUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_PackageVersion_InstalledAtUtc]
              DEFAULT (SYSUTCDATETIME())
        , [LastInstallerRunUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_PackageVersion_LastInstallerRunUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_PackageVersion]
              PRIMARY KEY CLUSTERED ([PackageCode])
        , CONSTRAINT [CK_snapshot_PackageVersion_PackageCode]
              CHECK ([PackageCode] = 'SC-023')
        , CONSTRAINT [CK_snapshot_PackageVersion_SchemaVersion]
              CHECK ([SchemaVersion] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'RetentionPolicy'
)
BEGIN
    CREATE TABLE [snapshot].[RetentionPolicy]
    (
          [RetentionPolicyCode] varchar(64) NOT NULL
        , [RawRetentionDays] smallint NOT NULL
        , [PayloadRetentionDays] smallint NOT NULL
        , [RollupRetentionDays] smallint NOT NULL
        , [SoftBudgetMB] bigint NOT NULL
        , [PurgeIntervalMinutes] int NOT NULL
        , [PurgeBatchRows] int NOT NULL
        , [BudgetAction] varchar(40) NOT NULL
        , [IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [DF_snapshot_RetentionPolicy_IsFrameworkDefault]
              DEFAULT (0)
        , [SeedVersion] int NOT NULL
        , [LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_RetentionPolicy_LastUpdatedUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_RetentionPolicy]
              PRIMARY KEY CLUSTERED ([RetentionPolicyCode])
        , CONSTRAINT [CK_snapshot_RetentionPolicy_RawRetentionDays]
              CHECK ([RawRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PayloadRetentionDays]
              CHECK ([PayloadRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_RollupRetentionDays]
              CHECK ([RollupRetentionDays] BETWEEN 1 AND 36500)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_SoftBudgetMB]
              CHECK ([SoftBudgetMB] > 0)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeIntervalMinutes]
              CHECK ([PurgeIntervalMinutes] BETWEEN 1 AND 10080)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_PurgeBatchRows]
              CHECK ([PurgeBatchRows] BETWEEN 1 AND 100000)
        , CONSTRAINT [CK_snapshot_RetentionPolicy_BudgetAction]
              CHECK ([BudgetAction] = 'PURGE_EXPIRED_THEN_STOP')
        , CONSTRAINT [CK_snapshot_RetentionPolicy_SeedVersion]
              CHECK ([SeedVersion] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'CollectorPolicy'
)
BEGIN
    CREATE TABLE [snapshot].[CollectorPolicy]
    (
          [CollectorCode] varchar(64) NOT NULL
        , [IsEnabled] bit NOT NULL
              CONSTRAINT [DF_snapshot_CollectorPolicy_IsEnabled] DEFAULT (1)
        , [CollectionIntervalSeconds] int NOT NULL
        , [MaxRows] int NOT NULL
        , [PayloadEnabled] bit NOT NULL
        , [RetentionPolicyCode] varchar(64) NOT NULL
        , [IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [DF_snapshot_CollectorPolicy_IsFrameworkDefault]
              DEFAULT (0)
        , [SeedVersion] int NOT NULL
        , [LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_CollectorPolicy_LastUpdatedUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_CollectorPolicy]
              PRIMARY KEY CLUSTERED ([CollectorCode])
        , CONSTRAINT [FK_snapshot_CollectorPolicy_RetentionPolicy]
              FOREIGN KEY ([RetentionPolicyCode])
              REFERENCES [snapshot].[RetentionPolicy]([RetentionPolicyCode])
        , CONSTRAINT [CK_snapshot_CollectorPolicy_CollectorCode]
              CHECK ([CollectorCode] IN ('PERFORMANCE_COUNTERS','WAIT_STATS'))
        , CONSTRAINT [CK_snapshot_CollectorPolicy_CollectionIntervalSeconds]
              CHECK ([CollectionIntervalSeconds] BETWEEN 1 AND 3600)
        , CONSTRAINT [CK_snapshot_CollectorPolicy_MaxRows]
              CHECK ([MaxRows] BETWEEN 1 AND 100000)
        , CONSTRAINT [CK_snapshot_CollectorPolicy_SeedVersion]
              CHECK ([SeedVersion] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'CaptureRun'
)
BEGIN
    CREATE TABLE [snapshot].[CaptureRun]
    (
          [CaptureRunId] bigint IDENTITY(1,1) NOT NULL
        , [CollectorCode] varchar(64) NOT NULL
        , [SchedulerType] varchar(16) NOT NULL
        , [StartedAtUtc] datetime2(3) NOT NULL
        , [EndedAtUtc] datetime2(3) NULL
        , [SourceDatabaseName] sysname NOT NULL
        , [SqlServerStartTimeUtc] datetime2(3) NULL
        , [ResetEpochId] uniqueidentifier NULL
        , [ContractVersion] int NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
              CONSTRAINT [DF_snapshot_CaptureRun_IsPartial] DEFAULT (0)
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , [MetricSampleCount] bigint NOT NULL
              CONSTRAINT [DF_snapshot_CaptureRun_MetricSampleCount] DEFAULT (0)
        , [PayloadCount] bigint NOT NULL
              CONSTRAINT [DF_snapshot_CaptureRun_PayloadCount] DEFAULT (0)
        , CONSTRAINT [PK_snapshot_CaptureRun]
              PRIMARY KEY CLUSTERED ([CaptureRunId])
        , CONSTRAINT [FK_snapshot_CaptureRun_CollectorPolicy]
              FOREIGN KEY ([CollectorCode])
              REFERENCES [snapshot].[CollectorPolicy]([CollectorCode])
        , CONSTRAINT [CK_snapshot_CaptureRun_SchedulerType]
              CHECK ([SchedulerType] IN ('MANUAL','EXTERNAL','SQL_AGENT'))
        , CONSTRAINT [CK_snapshot_CaptureRun_EndedAtUtc]
              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc])
        , CONSTRAINT [CK_snapshot_CaptureRun_MetricSampleCount]
              CHECK ([MetricSampleCount] >= 0)
        , CONSTRAINT [CK_snapshot_CaptureRun_PayloadCount]
              CHECK ([PayloadCount] >= 0)
        , CONSTRAINT [CK_snapshot_CaptureRun_ContractVersion]
              CHECK ([ContractVersion] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'ModuleStatus'
)
BEGIN
    CREATE TABLE [snapshot].[ModuleStatus]
    (
          [ModuleStatusId] bigint IDENTITY(1,1) NOT NULL
        , [CaptureRunId] bigint NOT NULL
        , [ModuleName] sysname NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
              CONSTRAINT [DF_snapshot_ModuleStatus_IsPartial] DEFAULT (0)
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , [EvidenceLimit] nvarchar(1000) NULL
        , CONSTRAINT [PK_snapshot_ModuleStatus]
              PRIMARY KEY CLUSTERED ([ModuleStatusId])
        , CONSTRAINT [FK_snapshot_ModuleStatus_CaptureRun]
              FOREIGN KEY ([CaptureRunId])
              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])
        , CONSTRAINT [UQ_snapshot_ModuleStatus_RunModule]
              UNIQUE ([CaptureRunId],[ModuleName])
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'Scope'
)
BEGIN
    CREATE TABLE [snapshot].[Scope]
    (
          [ScopeId] bigint IDENTITY(1,1) NOT NULL
        , [ScopeType] varchar(40) NOT NULL
        , [ParentScopeId] bigint NULL
        , [ScopeKeyHash] varbinary(32) NOT NULL
        , [ScopeIdentityJson] nvarchar(max) NOT NULL
        , [CreatedAtUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_Scope_CreatedAtUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_Scope]
              PRIMARY KEY CLUSTERED ([ScopeId])
        , CONSTRAINT [FK_snapshot_Scope_ParentScope]
              FOREIGN KEY ([ParentScopeId])
              REFERENCES [snapshot].[Scope]([ScopeId])
        , CONSTRAINT [UQ_snapshot_Scope_TypeKeyHash]
              UNIQUE ([ScopeType],[ScopeKeyHash])
        , CONSTRAINT [CK_snapshot_Scope_ScopeType]
              CHECK ([ScopeType] IN ('SERVER','PERFORMANCE_COUNTER','WAIT_TYPE'))
        , CONSTRAINT [CK_snapshot_Scope_ScopeKeyHash]
              CHECK (DATALENGTH([ScopeKeyHash]) = 32)
        , CONSTRAINT [CK_snapshot_Scope_ScopeIdentityJson]
              CHECK (ISJSON([ScopeIdentityJson]) = 1)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'MetricDefinition'
)
BEGIN
    CREATE TABLE [snapshot].[MetricDefinition]
    (
          [MetricDefinitionId] bigint IDENTITY(1,1) NOT NULL
        , [MetricCode] varchar(96) NOT NULL
        , [ValueType] varchar(24) NOT NULL
        , [Unit] varchar(40) NOT NULL
        , [ContractVersion] int NOT NULL
        , [Description] nvarchar(1000) NOT NULL
        , [IsFrameworkDefault] bit NOT NULL
              CONSTRAINT [DF_snapshot_MetricDefinition_IsFrameworkDefault]
              DEFAULT (0)
        , [SeedVersion] int NOT NULL
        , [LastUpdatedUtc] datetime2(3) NOT NULL
              CONSTRAINT [DF_snapshot_MetricDefinition_LastUpdatedUtc]
              DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_snapshot_MetricDefinition]
              PRIMARY KEY CLUSTERED ([MetricDefinitionId])
        , CONSTRAINT [UQ_snapshot_MetricDefinition_MetricCode]
              UNIQUE ([MetricCode])
        , CONSTRAINT [CK_snapshot_MetricDefinition_ValueType]
              CHECK ([ValueType] IN ('NUMERIC','BIGINT','STRING'))
        , CONSTRAINT [CK_snapshot_MetricDefinition_ContractVersion]
              CHECK ([ContractVersion] > 0)
        , CONSTRAINT [CK_snapshot_MetricDefinition_SeedVersion]
              CHECK ([SeedVersion] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'MetricSample'
)
BEGIN
    CREATE TABLE [snapshot].[MetricSample]
    (
          [MetricSampleId] bigint IDENTITY(1,1) NOT NULL
        , [CaptureRunId] bigint NOT NULL
        , [ScopeId] bigint NOT NULL
        , [MetricDefinitionId] bigint NOT NULL
        , [CollectedAtUtc] datetime2(3) NOT NULL
        , [ResetEpochId] uniqueidentifier NOT NULL
        , [NumericValue] decimal(38,6) NULL
        , [BigintValue] bigint NULL
        , [StringValue] nvarchar(4000) NULL
        , [QualityCode] varchar(80) NOT NULL
        , [IsPartial] bit NOT NULL
              CONSTRAINT [DF_snapshot_MetricSample_IsPartial] DEFAULT (0)
        , CONSTRAINT [PK_snapshot_MetricSample]
              PRIMARY KEY CLUSTERED ([MetricSampleId])
        , CONSTRAINT [FK_snapshot_MetricSample_CaptureRun]
              FOREIGN KEY ([CaptureRunId])
              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])
        , CONSTRAINT [FK_snapshot_MetricSample_Scope]
              FOREIGN KEY ([ScopeId])
              REFERENCES [snapshot].[Scope]([ScopeId])
        , CONSTRAINT [FK_snapshot_MetricSample_MetricDefinition]
              FOREIGN KEY ([MetricDefinitionId])
              REFERENCES [snapshot].[MetricDefinition]([MetricDefinitionId])
        , CONSTRAINT [UQ_snapshot_MetricSample_RunScopeMetric]
              UNIQUE ([CaptureRunId],[ScopeId],[MetricDefinitionId])
        , CONSTRAINT [CK_snapshot_MetricSample_ExactlyOneValue]
              CHECK
              (
                  (CASE WHEN [NumericValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [BigintValue] IS NULL THEN 0 ELSE 1 END)
                + (CASE WHEN [StringValue] IS NULL THEN 0 ELSE 1 END) = 1
              )
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'PayloadSnapshot'
)
BEGIN
    CREATE TABLE [snapshot].[PayloadSnapshot]
    (
          [PayloadSnapshotId] bigint IDENTITY(1,1) NOT NULL
        , [CaptureRunId] bigint NOT NULL
        , [ModuleName] sysname NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [PayloadFormat] varchar(40) NOT NULL
        , [PayloadContractVersion] int NOT NULL
        , [CompressionType] varchar(16) NOT NULL
        , [PayloadHash] varbinary(32) NOT NULL
        , [Payload] varbinary(max) NOT NULL
        , [UncompressedCharacterCount] bigint NOT NULL
        , CONSTRAINT [PK_snapshot_PayloadSnapshot]
              PRIMARY KEY CLUSTERED ([PayloadSnapshotId])
        , CONSTRAINT [FK_snapshot_PayloadSnapshot_CaptureRun]
              FOREIGN KEY ([CaptureRunId])
              REFERENCES [snapshot].[CaptureRun]([CaptureRunId])
        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadFormat]
              CHECK ([PayloadFormat] IN ('JSON','TEXT','XML','SQL_TEXT','PLAN_XML','ERROR_CONTEXT','PATH'))
        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadContractVersion]
              CHECK ([PayloadContractVersion] > 0)
        , CONSTRAINT [CK_snapshot_PayloadSnapshot_CompressionType]
              CHECK ([CompressionType] IN ('NONE','GZIP'))
        , CONSTRAINT [CK_snapshot_PayloadSnapshot_PayloadHash]
              CHECK (DATALENGTH([PayloadHash]) = 32)
        , CONSTRAINT [CK_snapshot_PayloadSnapshot_UncompressedCharacterCount]
              CHECK ([UncompressedCharacterCount] >= 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'PurgeRun'
)
BEGIN
    CREATE TABLE [snapshot].[PurgeRun]
    (
          [PurgeRunId] bigint IDENTITY(1,1) NOT NULL
        , [StartedAtUtc] datetime2(3) NOT NULL
        , [EndedAtUtc] datetime2(3) NULL
        , [StatusCode] varchar(40) NOT NULL
        , [BatchesExecuted] int NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_BatchesExecuted] DEFAULT (0)
        , [MetricRowsDeleted] bigint NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_MetricRowsDeleted] DEFAULT (0)
        , [PayloadRowsDeleted] bigint NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_PayloadRowsDeleted] DEFAULT (0)
        , [ModuleRowsDeleted] bigint NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_ModuleRowsDeleted] DEFAULT (0)
        , [CaptureRunsDeleted] bigint NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_CaptureRunsDeleted] DEFAULT (0)
        , [ScopeRowsDeleted] bigint NOT NULL
              CONSTRAINT [DF_snapshot_PurgeRun_ScopeRowsDeleted] DEFAULT (0)
        , [UsedDataMbBefore] decimal(19,3) NULL
        , [UsedDataMbAfter] decimal(19,3) NULL
        , [SoftBudgetMb] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , CONSTRAINT [PK_snapshot_PurgeRun]
              PRIMARY KEY CLUSTERED ([PurgeRunId])
        , CONSTRAINT [CK_snapshot_PurgeRun_EndedAtUtc]
              CHECK ([EndedAtUtc] IS NULL OR [EndedAtUtc] >= [StartedAtUtc])
        , CONSTRAINT [CK_snapshot_PurgeRun_BatchesExecuted]
              CHECK ([BatchesExecuted] >= 0)
        , CONSTRAINT [CK_snapshot_PurgeRun_DeletedRows]
              CHECK ([MetricRowsDeleted] >= 0
                 AND [PayloadRowsDeleted] >= 0
                 AND [ModuleRowsDeleted] >= 0
                 AND [CaptureRunsDeleted] >= 0
                 AND [ScopeRowsDeleted] >= 0)
        , CONSTRAINT [CK_snapshot_PurgeRun_SoftBudgetMb]
              CHECK ([SoftBudgetMb] > 0)
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'RetentionPolicy'
      AND [i].[name] = N'UX_snapshot_RetentionPolicy_FrameworkDefault'
)
BEGIN
    CREATE UNIQUE INDEX [UX_snapshot_RetentionPolicy_FrameworkDefault]
        ON [snapshot].[RetentionPolicy]([IsFrameworkDefault])
        WHERE [IsFrameworkDefault] = 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'CaptureRun'
      AND [i].[name] = N'IX_snapshot_CaptureRun_CollectorStarted'
)
BEGIN
    CREATE INDEX [IX_snapshot_CaptureRun_CollectorStarted]
        ON [snapshot].[CaptureRun]([CollectorCode],[StartedAtUtc] DESC,[CaptureRunId] DESC)
        INCLUDE ([EndedAtUtc],[StatusCode],[IsPartial],[SqlServerStartTimeUtc],[ResetEpochId]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'ModuleStatus'
      AND [i].[name] = N'IX_snapshot_ModuleStatus_CaptureRun'
)
BEGIN
    CREATE INDEX [IX_snapshot_ModuleStatus_CaptureRun]
        ON [snapshot].[ModuleStatus]([CaptureRunId],[ModuleStatusId]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'MetricSample'
      AND [i].[name] = N'IX_snapshot_MetricSample_CollectedAtUtc'
)
BEGIN
    CREATE INDEX [IX_snapshot_MetricSample_CollectedAtUtc]
        ON [snapshot].[MetricSample]([CollectedAtUtc],[MetricSampleId])
        INCLUDE ([CaptureRunId],[ScopeId],[MetricDefinitionId]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'MetricSample'
      AND [i].[name] = N'IX_snapshot_MetricSample_ScopeMetricTime'
)
BEGIN
    CREATE INDEX [IX_snapshot_MetricSample_ScopeMetricTime]
        ON [snapshot].[MetricSample]([ScopeId],[MetricDefinitionId],[CollectedAtUtc] DESC)
        INCLUDE ([ResetEpochId],[NumericValue],[BigintValue],[QualityCode],[IsPartial]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'PayloadSnapshot'
      AND [i].[name] = N'IX_snapshot_PayloadSnapshot_CapturedAtUtc'
)
BEGIN
    CREATE INDEX [IX_snapshot_PayloadSnapshot_CapturedAtUtc]
        ON [snapshot].[PayloadSnapshot]([CapturedAtUtc],[PayloadSnapshotId])
        INCLUDE ([CaptureRunId],[ModuleName],[PayloadFormat]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[indexes] AS [i] WITH (NOLOCK)
    INNER JOIN [sys].[tables] AS [t] WITH (NOLOCK)
      ON [t].[object_id] = [i].[object_id]
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [t].[schema_id]
    WHERE [s].[name] = N'snapshot'
      AND [t].[name] = N'PurgeRun'
      AND [i].[name] = N'IX_snapshot_PurgeRun_StartedAtUtc'
)
BEGIN
    CREATE INDEX [IX_snapshot_PurgeRun_StartedAtUtc]
        ON [snapshot].[PurgeRun]([StartedAtUtc] DESC,[PurgeRunId] DESC)
        INCLUDE ([EndedAtUtc],[StatusCode]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [snapshot].[PackageVersion] WITH (NOLOCK)
    WHERE [PackageCode] = 'SC-023'
)
BEGIN
    INSERT [snapshot].[PackageVersion]
    (
          [PackageCode],[PackageVersion],[SchemaVersion]
        , [InstalledAtUtc],[LastInstallerRunUtc]
    )
    VALUES
    (
          'SC-023','1.1.1',2
        , SYSUTCDATETIME(),SYSUTCDATETIME()
    );
END
ELSE
BEGIN
    UPDATE [snapshot].[PackageVersion]
    SET [PackageVersion] = '1.1.1'
      , [SchemaVersion] = 2
      , [LastInstallerRunUtc] = SYSUTCDATETIME()
    WHERE [PackageCode] = 'SC-023';
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [snapshot].[RetentionPolicy] WITH (NOLOCK)
    WHERE [RetentionPolicyCode] = 'DEFAULT'
)
BEGIN
    INSERT [snapshot].[RetentionPolicy]
    (
          [RetentionPolicyCode]
        , [RawRetentionDays],[PayloadRetentionDays],[RollupRetentionDays]
        , [SoftBudgetMB],[PurgeIntervalMinutes],[PurgeBatchRows]
        , [BudgetAction],[IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc]
    )
    VALUES
    (
          'DEFAULT'
        , 14,7,180
        , 10240,60,10000
        , 'PURGE_EXPIRED_THEN_STOP',1,1,SYSUTCDATETIME()
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [snapshot].[CollectorPolicy] WITH (NOLOCK)
    WHERE [CollectorCode] = 'PERFORMANCE_COUNTERS'
)
BEGIN
    INSERT [snapshot].[CollectorPolicy]
    (
          [CollectorCode],[IsEnabled],[CollectionIntervalSeconds]
        , [MaxRows],[PayloadEnabled],[RetentionPolicyCode]
        , [IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc]
    )
    VALUES
    (
          'PERFORMANCE_COUNTERS',1,30
        , 1000,0,'DEFAULT'
        , 1,1,SYSUTCDATETIME()
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [snapshot].[MetricDefinition] WITH (NOLOCK)
    WHERE [MetricCode] = 'PERFORMANCE_COUNTER_RAW'
)
BEGIN
    INSERT [snapshot].[MetricDefinition]
    (
          [MetricCode],[ValueType],[Unit],[ContractVersion],[Description]
        , [IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc]
    )
    VALUES
    (
          'PERFORMANCE_COUNTER_RAW','BIGINT','RAW_VALUE',1
        , N'Unveränderter kumulativer oder aktueller Wert aus monitor.USP_PerformanceCounters.'
        , 1,1,SYSUTCDATETIME()
    );
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [snapshot].[MetricDefinition] WITH (NOLOCK)
    WHERE [MetricCode] = 'PERFORMANCE_COUNTER_INTERPRETED'
)
BEGIN
    INSERT [snapshot].[MetricDefinition]
    (
          [MetricCode],[ValueType],[Unit],[ContractVersion],[Description]
        , [IsFrameworkDefault],[SeedVersion],[LastUpdatedUtc]
    )
    VALUES
    (
          'PERFORMANCE_COUNTER_INTERPRETED','NUMERIC','SOURCE_DEFINED',1
        , N'Vom Quellvertrag abgeleiteter Wert; Einheit und Interpretation stehen in der Scope-Identität und Qualitätsklassifikation.'
        , 1,1,SYSUTCDATETIME()
    );
END;
IF @SnapshotSchemaOwnTransaction=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
DECLARE @SnapshotMigrationError int=ERROR_NUMBER();
IF @SnapshotSchemaOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
ELSE IF @SnapshotSchemaOwnTransaction=0 AND XACT_STATE()=1 ROLLBACK TRANSACTION SQLSA_SnapshotSchema2;
RAISERROR(N'SNAPSHOT_SCHEMA_MIGRATION_FAILED CompletedStage=%d NativeError=%d',10,1,@SnapshotMigrationStage,@SnapshotMigrationError) WITH NOWAIT;
THROW;
END CATCH;
GO
