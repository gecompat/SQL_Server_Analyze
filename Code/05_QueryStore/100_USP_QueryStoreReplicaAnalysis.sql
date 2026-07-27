USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStoreReplicaAnalysis
Version      : 1.0.0
Stand        : 2026-07-27
Typ          : Stored Procedure
Zweck        : Trennt Query-Store-Laufzeit-, Wait- und Plan-Forcing-Evidenz
               nach replica_group_id und ordnet beobachtete Rollen zu.
SQL-Version  : SQL Server 2019 oder neuer; Replica-Kataloge ab SQL Server 2025.
Datenquellen : sys.database_query_store_options, sys.query_store_replicas,
               sys.query_store_runtime_stats, sys.query_store_wait_stats,
               sys.query_store_plan_forcing_locations.
Abgrenzung   : Keine Querytexte, Plan-XML, Hints, Identitäten oder Nutzdaten.
               Beobachtete Rollen sind historischer Query-Store-Kontext und
               keine aktuelle Verfügbarkeits-, Synchronitäts- oder Healthaussage.
Eigenlast    : LOW_MEDIUM. Jede unterstützte Quelle wird je Datenbank höchstens
               einmal gelesen; Zeitfenster, Datenbankscope und Zeilenlimit gelten.
Locking      : Konfigurierbarer LOCK_TIMEOUT; ursprünglicher Wert wird restauriert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames          nvarchar(max)  = NULL
    , @QueryStoreDatabaseNamePattern    nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ReplicaGroupIds                  nvarchar(max)  = NULL
    , @VonUtc                           datetime2(7)   = NULL
    , @BisUtc                           datetime2(7)   = NULL
    , @MaxZeilen                        int            = 200
    , @LockTimeoutMs                    int            = 0
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTablesJson                 nvarchar(max)  = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
    , @StatusCodeOut                    varchar(40)    = NULL OUTPUT
    , @IsPartialOut                     bit            = NULL OUTPUT
    , @ErrorNumberOut                   int            = NULL OUTPUT
    , @ErrorMessageOut                  nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;

    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME();
    DECLARE @ProductMajorVersion int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL;
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @CrossDatabaseRequested bit=0;
    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(64);
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @LocalLimit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                                    THEN CONVERT(bigint,9223372036854775807)
                                    WHEN @MaxZeilen<2147483647 THEN CONVERT(bigint,@MaxZeilen)+1
                                    ELSE CONVERT(bigint,@MaxZeilen) END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_QueryStoreReplicaAnalysis';
        PRINT N'Trennt Query-Store-Runtime-, Wait- und Forcing-Evidenz nach replica_group_id.';
        PRINT N'@ReplicaGroupIds akzeptiert numerische Pipe-, Beistrich- oder Strichpunktlisten.';
        PRINT N'@VonUtc/@BisUtc begrenzen Runtime- und Wait-Intervalle; Default ist die letzte Stunde.';
        PRINT N'SQL Server 2019/2022 liefern kontrolliert UNAVAILABLE_VERSION; versionsspezifische Quellen werden dort nicht referenziert.';
        PRINT N'@ResultSetArt=CONSOLE|RAW|TABLE|NONE; TABLE-Namen: moduleStatus, replicas, runtimeByReplica, waitsByReplica, forcingByReplica, sourceStatus, warnings.';
        RETURN;
    END;

    IF @BisUtc IS NULL SET @BisUtc=SYSUTCDATETIME();
    IF @VonUtc IS NULL SET @VonUtc=DATEADD(HOUR,-1,@BisUtc);

    CREATE TABLE [#QueryStoreReplicaAnalysis_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) NULL
        , [UserAccessDesc] nvarchar(60) NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname NULL
        , [RecoveryModelDesc] nvarchar(60) NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_CandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_ReplicaFilter]
    (
          [ItemOrdinal] int NOT NULL
        , [ReplicaGroupId] bigint NULL
        , [IsValid] bit NOT NULL
        , PRIMARY KEY([ItemOrdinal])
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_Replicas]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
        , [CurrentQueryStoreStateDesc] nvarchar(60) NULL
        , [CurrentConnectionRoleDesc] varchar(40) NOT NULL
        , [ReplicaGroupId] bigint NOT NULL
        , [RoleType] tinyint NULL
        , [RoleTypeDesc] varchar(40) NOT NULL
        , [RoleClass] varchar(24) NOT NULL
        , [ReplicaName] nvarchar(4000) NULL
        , [IsPrimaryRole] bit NOT NULL
        , [IsSecondaryRole] bit NOT NULL
        , [IsNamedReplica] bit NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_RuntimeByReplica]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
        , [CurrentConnectionRoleDesc] varchar(40) NOT NULL
        , [ReplicaGroupId] bigint NULL
        , [RoleType] tinyint NULL
        , [RoleTypeDesc] varchar(40) NOT NULL
        , [RoleClass] varchar(24) NOT NULL
        , [ReplicaName] nvarchar(4000) NULL
        , [MappingStatusCode] varchar(40) NOT NULL
        , [RecordedRows] bigint NOT NULL
        , [QueryCount] bigint NOT NULL
        , [PlanCount] bigint NOT NULL
        , [ExecutionCount] bigint NOT NULL
        , [FirstExecutionTimeUtc] datetimeoffset NULL
        , [LastExecutionTimeUtc] datetimeoffset NULL
        , [TotalDurationMs] decimal(38,3) NULL
        , [TotalCpuMs] decimal(38,3) NULL
        , [TotalLogicalReads] decimal(38,3) NULL
        , [TotalLogicalWrites] decimal(38,3) NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_WaitsByReplica]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
        , [CurrentConnectionRoleDesc] varchar(40) NOT NULL
        , [ReplicaGroupId] bigint NULL
        , [RoleType] tinyint NULL
        , [RoleTypeDesc] varchar(40) NOT NULL
        , [RoleClass] varchar(24) NOT NULL
        , [ReplicaName] nvarchar(4000) NULL
        , [MappingStatusCode] varchar(40) NOT NULL
        , [ExecutionTypeDesc] nvarchar(128) NULL
        , [WaitCategory] tinyint NULL
        , [WaitCategoryDesc] nvarchar(128) NULL
        , [RecordedRows] bigint NOT NULL
        , [FirstIntervalStartUtc] datetimeoffset NULL
        , [LastIntervalEndUtc] datetimeoffset NULL
        , [TotalQueryWaitTimeMs] bigint NULL
        , [MaxQueryWaitTimeMs] bigint NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_ForcingByReplica]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
        , [CurrentConnectionRoleDesc] varchar(40) NOT NULL
        , [ReplicaGroupId] bigint NULL
        , [RoleType] tinyint NULL
        , [RoleTypeDesc] varchar(40) NOT NULL
        , [RoleClass] varchar(24) NOT NULL
        , [ReplicaName] nvarchar(4000) NULL
        , [MappingStatusCode] varchar(40) NOT NULL
        , [ForcingLocationCount] bigint NOT NULL
        , [ForcedQueryCount] bigint NOT NULL
        , [ForcedPlanCount] bigint NOT NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_SourceStatus]
    (
          [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseId] int NULL
        , [DatabaseName] sysname NULL
        , [SourceName] sysname NOT NULL
        , [SourceObject] nvarchar(256) NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_Warnings]
    (
          [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname NULL
        , [SourceName] sysname NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [Message] nvarchar(2048) NOT NULL
    );
    CREATE TABLE [#QueryStoreReplicaAnalysis_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [ProductMajorVersion] int NULL
        , [CrossDatabaseRequested] bit NOT NULL
        , [DatabaseCount] int NOT NULL
        , [ReplicaRowCount] bigint NOT NULL
        , [RuntimeRowCount] bigint NOT NULL
        , [WaitRowCount] bigint NOT NULL
        , [ForcingRowCount] bigint NOT NULL
        , [HasMoreReplicaRows] bit NOT NULL
        , [HasMoreRuntimeRows] bit NOT NULL
        , [HasMoreWaitRows] bit NOT NULL
        , [HasMoreForcingRows] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @ReplicaGroupIds IS NOT NULL
    BEGIN
        INSERT [#QueryStoreReplicaAnalysis_ReplicaFilter]([ItemOrdinal],[ReplicaGroupId],[IsValid])
        SELECT [ItemOrdinal],[ValueBigint],[IsValid]
        FROM [monitor].[TVF_ParseBigintList](@ReplicaGroupIds);
    END;

    IF @MaxZeilen<0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @HighImpactConfirmed IS NULL OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @VonUtc>=@BisUtc OR @OutputMode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
       OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter] WHERE [IsValid]=0)
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungültiger Zeitraum, Zeilen-, Replica-, Lock-Timeout- oder Ausgabeparameter.';
    END;

    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|replicas|runtimeByReplica|waitsByReplica|forcingByReplica|sourceStatus|warnings'
            , @MappingTable=N'#QueryStoreReplicaAnalysis_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@QueryStoreDatabaseNames
            , @SystemdatenbankenEinbeziehen=0
            , @DatabaseNamePattern=@QueryStoreDatabaseNamePattern
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @AnalysisClass='QUERY_STORE_CURRENT'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
            , @CandidateTable=N'#QueryStoreReplicaAnalysis_DatabaseCandidates'
            , @WarningTable=N'#QueryStoreReplicaAnalysis_CandidateWarnings';

    INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
    SELECT [RequestedName],N'databaseCandidates',[StatusCode],NULL,COALESCE([ErrorMessage],N'Datenbankkandidat ist nicht verfügbar.')
    FROM [#QueryStoreReplicaAnalysis_CandidateWarnings];

    IF EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_CandidateWarnings])
        SET @IsPartial=1;

    IF @StatusCode='AVAILABLE'
    BEGIN
        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;

        DECLARE
              @DatabaseId int
            , @DatabaseName sysname
            , @ActualState smallint
            , @ActualStateDesc nvarchar(60)
            , @WaitStatsCaptureMode smallint
            , @CurrentIsPrimaryReplica int
            , @CurrentRoleDesc varchar(40)
            , @HasReplicaCatalog bit
            , @ReplicaCatalogSchemaValid bit
            , @RuntimeReplicaColumnValid bit
            , @WaitReplicaColumnValid bit
            , @HasForcingLocations bit
            , @ForcingSchemaValid bit
            , @ProbeSql nvarchar(max)
            , @ReplicaSql nvarchar(max)
            , @RuntimeSql nvarchar(max)
            , @WaitSql nvarchar(max)
            , @ForcingSql nvarchar(max)
            , @RowsBefore bigint
            , @RowsAfter bigint;

        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName]
            FROM [#QueryStoreReplicaAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];

        OPEN [DatabaseCursor];
        FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF @ProductMajorVersion IS NULL OR @ProductMajorVersion<17
            BEGIN
                INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                VALUES
                  (@DatabaseId,@DatabaseName,N'queryStoreOptions',N'sys.database_query_store_options',@CapturedAtUtc,'AVAILABLE',0,0,N'VIEW DATABASE STATE / VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Die Basisoptionen bleiben versionsübergreifend verfügbar; der Replica-Slice referenziert sie vor SQL Server 2025 nicht erneut.')
                , (@DatabaseId,@DatabaseName,N'replicaCatalog',N'sys.query_store_replicas',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Query Store für lesbare Secondaries und sys.query_store_replicas werden im freigegebenen Produktvertrag erst ab SQL Server 2025 ausgewertet.')
                , (@DatabaseId,@DatabaseName,N'runtimeByReplica',N'sys.query_store_runtime_stats.replica_group_id',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Vor SQL Server 2025 wird keine Replica-Rollenaussage erzeugt.')
                , (@DatabaseId,@DatabaseName,N'waitsByReplica',N'sys.query_store_wait_stats.replica_group_id',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Vor SQL Server 2025 wird keine Replica-Rollenaussage erzeugt.')
                , (@DatabaseId,@DatabaseName,N'forcingByReplica',N'sys.query_store_plan_forcing_locations',@CapturedAtUtc,'UNAVAILABLE_VERSION',0,0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Replica-spezifische Plan-Forcing-Locations werden erst ab SQL Server 2025 ausgewertet.');
            END
            ELSE
            BEGIN
                SELECT @ActualState=NULL,@ActualStateDesc=NULL,@WaitStatsCaptureMode=NULL,
                       @CurrentIsPrimaryReplica=NULL,@HasReplicaCatalog=0,@ReplicaCatalogSchemaValid=0,
                       @RuntimeReplicaColumnValid=0,@WaitReplicaColumnValid=0,
                       @HasForcingLocations=0,@ForcingSchemaValid=0;

                SET @ProbeSql=N'USE '+QUOTENAME(@DatabaseName)+N';
SELECT TOP(1)
       @pActualState=[actual_state],
       @pActualStateDesc=[actual_state_desc],
       @pWaitStatsCaptureMode=[wait_stats_capture_mode]
FROM [sys].[database_query_store_options] WITH (NOLOCK);

SELECT @pCurrentIsPrimaryReplica=TRY_CONVERT(int,[sys].[fn_hadr_is_primary_replica](DB_NAME()));

SELECT @pHasReplicaCatalog=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_replicas''
) THEN 1 ELSE 0 END);

SELECT @pReplicaCatalogSchemaValid=CONVERT(bit,CASE WHEN COUNT(DISTINCT [c].[name])=3 THEN 1 ELSE 0 END)
FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_replicas''
  AND [c].[name] IN(N''replica_group_id'',N''role_type'',N''replica_name'');

SELECT @pRuntimeReplicaColumnValid=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_runtime_stats'' AND [c].[name]=N''replica_group_id''
) THEN 1 ELSE 0 END);

SELECT @pWaitReplicaColumnValid=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_wait_stats'' AND [c].[name]=N''replica_group_id''
) THEN 1 ELSE 0 END);

SELECT @pHasForcingLocations=CONVERT(bit,CASE WHEN EXISTS
(
    SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
    INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_plan_forcing_locations''
) THEN 1 ELSE 0 END);

SELECT @pForcingSchemaValid=CONVERT(bit,CASE WHEN COUNT(DISTINCT [c].[name])=3 THEN 1 ELSE 0 END)
FROM [sys].[all_objects] AS [o] WITH (NOLOCK)
INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id]
WHERE [s].[name]=N''sys'' AND [o].[name]=N''query_store_plan_forcing_locations''
  AND [c].[name] IN(N''query_id'',N''plan_id'',N''replica_group_id'');';

                BEGIN TRY
                    EXEC [sys].[sp_executesql]
                          @ProbeSql
                        , N'@pActualState smallint OUTPUT,@pActualStateDesc nvarchar(60) OUTPUT,@pWaitStatsCaptureMode smallint OUTPUT,@pCurrentIsPrimaryReplica int OUTPUT,@pHasReplicaCatalog bit OUTPUT,@pReplicaCatalogSchemaValid bit OUTPUT,@pRuntimeReplicaColumnValid bit OUTPUT,@pWaitReplicaColumnValid bit OUTPUT,@pHasForcingLocations bit OUTPUT,@pForcingSchemaValid bit OUTPUT'
                        , @pActualState=@ActualState OUTPUT
                        , @pActualStateDesc=@ActualStateDesc OUTPUT
                        , @pWaitStatsCaptureMode=@WaitStatsCaptureMode OUTPUT
                        , @pCurrentIsPrimaryReplica=@CurrentIsPrimaryReplica OUTPUT
                        , @pHasReplicaCatalog=@HasReplicaCatalog OUTPUT
                        , @pReplicaCatalogSchemaValid=@ReplicaCatalogSchemaValid OUTPUT
                        , @pRuntimeReplicaColumnValid=@RuntimeReplicaColumnValid OUTPUT
                        , @pWaitReplicaColumnValid=@WaitReplicaColumnValid OUTPUT
                        , @pHasForcingLocations=@HasForcingLocations OUTPUT
                        , @pForcingSchemaValid=@ForcingSchemaValid OUTPUT;

                    SET @CurrentRoleDesc=CASE @CurrentIsPrimaryReplica WHEN 1 THEN 'PRIMARY' WHEN 0 THEN 'SECONDARY' ELSE 'NOT_IN_AG_OR_UNKNOWN' END;

                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES
                    (@DatabaseId,@DatabaseName,N'queryStoreOptions',N'sys.database_query_store_options',@CapturedAtUtc,
                     CASE WHEN @ActualState IN(1,2,4) THEN 'AVAILABLE' WHEN @ActualState=3 THEN 'ERROR_STATE' ELSE 'FEATURE_DISABLED' END,
                     CONVERT(bit,CASE WHEN @ActualState=3 THEN 1 ELSE 0 END),1,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,
                     CONCAT(N'actual_state_desc=',COALESCE(@ActualStateDesc,N'UNKNOWN'),N'; aktueller AG-Rollenhinweis=',@CurrentRoleDesc,N'.'));
                END TRY
                BEGIN CATCH
                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES
                    (@DatabaseId,@DatabaseName,N'queryStoreOptions',N'sys.database_query_store_options',@CapturedAtUtc,
                     CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                     1,0,N'VIEW DATABASE PERFORMANCE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Die Capability- und Schemaprüfung ist fehlgeschlagen; versionsspezifische Quellen wurden nicht referenziert.');
                    INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
                    VALUES(@DatabaseName,N'queryStoreOptions',
                           CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                           ERROR_NUMBER(),ERROR_MESSAGE());
                    SET @IsPartial=1;
                    SELECT @ActualState=NULL,@HasReplicaCatalog=0,@ReplicaCatalogSchemaValid=0,
                           @RuntimeReplicaColumnValid=0,@WaitReplicaColumnValid=0,@HasForcingLocations=0,@ForcingSchemaValid=0,
                           @CurrentRoleDesc='UNKNOWN';
                END CATCH;

                IF @ActualState IN(1,2,4) AND @HasReplicaCatalog=1 AND @ReplicaCatalogSchemaValid=1
                BEGIN
                    SELECT @RowsBefore=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_Replicas];
                    SET @ReplicaSql=N'USE '+QUOTENAME(@DatabaseName)+N';
INSERT [#QueryStoreReplicaAnalysis_Replicas]
([CapturedAtUtc],[DatabaseId],[DatabaseName],[CurrentQueryStoreStateDesc],[CurrentConnectionRoleDesc],
 [ReplicaGroupId],[RoleType],[RoleTypeDesc],[RoleClass],[ReplicaName],
 [IsPrimaryRole],[IsSecondaryRole],[IsNamedReplica],[StatusCode],[EvidenceLimit])
SELECT @pCapturedAtUtc,@pDatabaseId,@pDatabaseName,@pActualStateDesc,@pCurrentRoleDesc,
       [r].[replica_group_id],[r].[role_type],[m].[RoleTypeDesc],[m].[RoleClass],
       CONVERT(nvarchar(4000),[r].[replica_name]),
       [m].[IsPrimaryRole],[m].[IsSecondaryRole],[m].[IsNamedReplica],''AVAILABLE'',[m].[EvidenceLimit]
FROM [sys].[query_store_replicas] AS [r] WITH (NOLOCK)
CROSS APPLY [DeineDatenbank].[monitor].[TVF_QueryStoreReplicaRoleInfo]([r].[role_type]) AS [m]
WHERE NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter])
   OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter] AS [f]
             WHERE [f].[IsValid]=1 AND [f].[ReplicaGroupId]=[r].[replica_group_id])
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql] @ReplicaSql,
                             N'@pCapturedAtUtc datetime2(3),@pDatabaseId int,@pDatabaseName sysname,@pActualStateDesc nvarchar(60),@pCurrentRoleDesc varchar(40)',
                             @CapturedAtUtc,@DatabaseId,@DatabaseName,@ActualStateDesc,@CurrentRoleDesc;
                        SELECT @RowsAfter=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_Replicas];
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'replicaCatalog',N'sys.query_store_replicas',@CapturedAtUtc,
                               CASE WHEN @RowsAfter=@RowsBefore THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@RowsAfter-@RowsBefore,
                               N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Eine Zeile beschreibt eine beobachtete Query-Store-Rolle. Failover kann mehrere historische Rollen erzeugen; dies ist keine aktuelle Healthaussage.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'replicaCatalog',N'sys.query_store_replicas',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'VIEW DATABASE PERFORMANCE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Replica-Katalogfehler ist auf diese Quelle begrenzt.');
                        INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
                        VALUES(@DatabaseName,N'replicaCatalog','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                        SET @IsPartial=1;
                    END CATCH;
                END
                ELSE
                BEGIN
                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@DatabaseId,@DatabaseName,N'replicaCatalog',N'sys.query_store_replicas',@CapturedAtUtc,
                           CASE WHEN @ActualState NOT IN(1,2,4) THEN 'FEATURE_DISABLED'
                                WHEN @HasReplicaCatalog=0 THEN 'UNAVAILABLE_FEATURE' ELSE 'UNAVAILABLE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @ActualState IN(1,2,4) THEN 1 ELSE 0 END),0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,
                           N'Die Replicaquelle wird nur nach erfolgreicher Version-, Objekt- und Pflichtspaltenprüfung referenziert.');
                    IF @ActualState IN(1,2,4) SET @IsPartial=1;
                END;

                IF @ActualState IN(1,2,4) AND @RuntimeReplicaColumnValid=1
                BEGIN
                    SELECT @RowsBefore=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica];
                    SET @RuntimeSql=N'USE '+QUOTENAME(@DatabaseName)+N';
;WITH [ReplicaMap] AS
(
    SELECT [replica_group_id],MIN([role_type]) AS [role_type],MAX(CONVERT(nvarchar(4000),[replica_name])) AS [replica_name]
    FROM [sys].[query_store_replicas] WITH (NOLOCK)
    GROUP BY [replica_group_id]
),
[R] AS
(
    SELECT [rs].[replica_group_id],COUNT_BIG(*) AS [RecordedRows],
           COUNT_BIG(DISTINCT [p].[query_id]) AS [QueryCount],
           COUNT_BIG(DISTINCT [rs].[plan_id]) AS [PlanCount],
           SUM(CONVERT(bigint,[rs].[count_executions])) AS [ExecutionCount],
           MIN([rs].[first_execution_time]) AS [FirstExecutionTime],
           MAX([rs].[last_execution_time]) AS [LastExecutionTime],
           SUM(CONVERT(float,[rs].[avg_duration])*[rs].[count_executions])/1000.0 AS [TotalDurationMs],
           SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions])/1000.0 AS [TotalCpuMs],
           SUM(CONVERT(float,[rs].[avg_logical_io_reads])*[rs].[count_executions]) AS [TotalLogicalReads],
           SUM(CONVERT(float,[rs].[avg_logical_io_writes])*[rs].[count_executions]) AS [TotalLogicalWrites]
    FROM [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
    INNER JOIN [sys].[query_store_runtime_stats_interval] AS [i] WITH (NOLOCK)
      ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id]
    INNER JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK) ON [p].[plan_id]=[rs].[plan_id]
    WHERE [i].[end_time]>@pFromUtc AND [i].[start_time]<@pToUtc
      AND (NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter])
           OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter] AS [f]
                     WHERE [f].[IsValid]=1 AND [f].[ReplicaGroupId]=[rs].[replica_group_id]))
    GROUP BY [rs].[replica_group_id]
)
INSERT [#QueryStoreReplicaAnalysis_RuntimeByReplica]
([CapturedAtUtc],[DatabaseId],[DatabaseName],[CurrentConnectionRoleDesc],[ReplicaGroupId],
 [RoleType],[RoleTypeDesc],[RoleClass],[ReplicaName],[MappingStatusCode],
 [RecordedRows],[QueryCount],[PlanCount],[ExecutionCount],[FirstExecutionTimeUtc],[LastExecutionTimeUtc],
 [TotalDurationMs],[TotalCpuMs],[TotalLogicalReads],[TotalLogicalWrites],[EvidenceLimit])
SELECT @pCapturedAtUtc,@pDatabaseId,@pDatabaseName,@pCurrentRoleDesc,[R].[replica_group_id],
       [rm].[role_type],[mi].[RoleTypeDesc],[mi].[RoleClass],[rm].[replica_name],
       CASE WHEN [rm].[replica_group_id] IS NULL THEN ''REPLICA_METADATA_MISSING'' ELSE ''AVAILABLE'' END,
       [R].[RecordedRows],[R].[QueryCount],[R].[PlanCount],[R].[ExecutionCount],
       [R].[FirstExecutionTime],[R].[LastExecutionTime],
       CONVERT(decimal(38,3),[R].[TotalDurationMs]),CONVERT(decimal(38,3),[R].[TotalCpuMs]),
       CONVERT(decimal(38,3),[R].[TotalLogicalReads]),CONVERT(decimal(38,3),[R].[TotalLogicalWrites]),
       N''Intervallaggregate nach replica_group_id; keine aktuelle Einzelausführung, kein Querytext und keine Replikatsynchronitätsaussage.''
FROM [R]
LEFT JOIN [ReplicaMap] AS [rm] ON [rm].[replica_group_id]=[R].[replica_group_id]
CROSS APPLY [DeineDatenbank].[monitor].[TVF_QueryStoreReplicaRoleInfo]([rm].[role_type]) AS [mi]
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql] @RuntimeSql,
                             N'@pCapturedAtUtc datetime2(3),@pDatabaseId int,@pDatabaseName sysname,@pCurrentRoleDesc varchar(40),@pFromUtc datetime2(7),@pToUtc datetime2(7)',
                             @CapturedAtUtc,@DatabaseId,@DatabaseName,@CurrentRoleDesc,@VonUtc,@BisUtc;
                        SELECT @RowsAfter=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica];
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'runtimeByReplica',N'sys.query_store_runtime_stats.replica_group_id',@CapturedAtUtc,
                               CASE WHEN @RowsAfter=@RowsBefore THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@RowsAfter-@RowsBefore,
                               N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Runtimewerte werden je replica_group_id getrennt und aus Query-Store-Intervallen gewichtet.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'runtimeByReplica',N'sys.query_store_runtime_stats.replica_group_id',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'VIEW DATABASE PERFORMANCE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Runtimefehler ist auf diese Quelle begrenzt.');
                        INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
                        VALUES(@DatabaseName,N'runtimeByReplica','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                        SET @IsPartial=1;
                    END CATCH;
                END
                ELSE
                BEGIN
                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@DatabaseId,@DatabaseName,N'runtimeByReplica',N'sys.query_store_runtime_stats.replica_group_id',@CapturedAtUtc,
                           CASE WHEN @ActualState NOT IN(1,2,4) THEN 'FEATURE_DISABLED' ELSE 'UNAVAILABLE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @ActualState IN(1,2,4) THEN 1 ELSE 0 END),0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Die Replica-Spalte wird erst nach Pflichtspaltenprüfung referenziert.');
                    IF @ActualState IN(1,2,4) SET @IsPartial=1;
                END;

                IF @ActualState IN(1,2,4) AND @WaitStatsCaptureMode=1 AND @WaitReplicaColumnValid=1
                BEGIN
                    SELECT @RowsBefore=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_WaitsByReplica];
                    SET @WaitSql=N'USE '+QUOTENAME(@DatabaseName)+N';
;WITH [ReplicaMap] AS
(
    SELECT [replica_group_id],MIN([role_type]) AS [role_type],MAX(CONVERT(nvarchar(4000),[replica_name])) AS [replica_name]
    FROM [sys].[query_store_replicas] WITH (NOLOCK)
    GROUP BY [replica_group_id]
),
[W] AS
(
    SELECT [ws].[replica_group_id],[ws].[execution_type_desc],[ws].[wait_category],[ws].[wait_category_desc],
           COUNT_BIG(*) AS [RecordedRows],MIN([i].[start_time]) AS [FirstStart],MAX([i].[end_time]) AS [LastEnd],
           SUM(CONVERT(bigint,[ws].[total_query_wait_time_ms])) AS [TotalWait],
           MAX(CONVERT(bigint,[ws].[max_query_wait_time_ms])) AS [MaxWait]
    FROM [sys].[query_store_wait_stats] AS [ws] WITH (NOLOCK)
    INNER JOIN [sys].[query_store_runtime_stats_interval] AS [i] WITH (NOLOCK)
      ON [i].[runtime_stats_interval_id]=[ws].[runtime_stats_interval_id]
    WHERE [i].[end_time]>@pFromUtc AND [i].[start_time]<@pToUtc
      AND (NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter])
           OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter] AS [f]
                     WHERE [f].[IsValid]=1 AND [f].[ReplicaGroupId]=[ws].[replica_group_id]))
    GROUP BY [ws].[replica_group_id],[ws].[execution_type_desc],[ws].[wait_category],[ws].[wait_category_desc]
)
INSERT [#QueryStoreReplicaAnalysis_WaitsByReplica]
([CapturedAtUtc],[DatabaseId],[DatabaseName],[CurrentConnectionRoleDesc],[ReplicaGroupId],
 [RoleType],[RoleTypeDesc],[RoleClass],[ReplicaName],[MappingStatusCode],
 [ExecutionTypeDesc],[WaitCategory],[WaitCategoryDesc],[RecordedRows],
 [FirstIntervalStartUtc],[LastIntervalEndUtc],[TotalQueryWaitTimeMs],[MaxQueryWaitTimeMs],[EvidenceLimit])
SELECT TOP(@pLocalLimit) @pCapturedAtUtc,@pDatabaseId,@pDatabaseName,@pCurrentRoleDesc,[W].[replica_group_id],
       [rm].[role_type],[mi].[RoleTypeDesc],[mi].[RoleClass],[rm].[replica_name],
       CASE WHEN [rm].[replica_group_id] IS NULL THEN ''REPLICA_METADATA_MISSING'' ELSE ''AVAILABLE'' END,
       [W].[execution_type_desc],[W].[wait_category],[W].[wait_category_desc],[W].[RecordedRows],
       [W].[FirstStart],[W].[LastEnd],[W].[TotalWait],[W].[MaxWait],
       N''Wait-Intervalaggregate nach replica_group_id und Kategorie; keine vollständige Wait-Timeline oder aktuelle Taskzuordnung.''
FROM [W]
LEFT JOIN [ReplicaMap] AS [rm] ON [rm].[replica_group_id]=[W].[replica_group_id]
CROSS APPLY [DeineDatenbank].[monitor].[TVF_QueryStoreReplicaRoleInfo]([rm].[role_type]) AS [mi]
ORDER BY [W].[TotalWait] DESC,[W].[LastEnd] DESC
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql] @WaitSql,
                             N'@pCapturedAtUtc datetime2(3),@pDatabaseId int,@pDatabaseName sysname,@pCurrentRoleDesc varchar(40),@pFromUtc datetime2(7),@pToUtc datetime2(7),@pLocalLimit bigint',
                             @CapturedAtUtc,@DatabaseId,@DatabaseName,@CurrentRoleDesc,@VonUtc,@BisUtc,@LocalLimit;
                        SELECT @RowsAfter=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_WaitsByReplica];
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'waitsByReplica',N'sys.query_store_wait_stats.replica_group_id',@CapturedAtUtc,
                               CASE WHEN @RowsAfter=@RowsBefore THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@RowsAfter-@RowsBefore,
                               N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Waitwerte werden je replica_group_id, Ausführungstyp und Kategorie getrennt.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'waitsByReplica',N'sys.query_store_wait_stats.replica_group_id',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'VIEW DATABASE PERFORMANCE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Waitfehler ist auf diese Quelle begrenzt.');
                        INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
                        VALUES(@DatabaseName,N'waitsByReplica','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                        SET @IsPartial=1;
                    END CATCH;
                END
                ELSE
                BEGIN
                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@DatabaseId,@DatabaseName,N'waitsByReplica',N'sys.query_store_wait_stats.replica_group_id',@CapturedAtUtc,
                           CASE WHEN @ActualState NOT IN(1,2,4) THEN 'FEATURE_DISABLED'
                                WHEN @WaitStatsCaptureMode<>1 THEN 'NOT_APPLICABLE'
                                ELSE 'UNAVAILABLE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @ActualState IN(1,2,4) AND @WaitStatsCaptureMode=1 THEN 1 ELSE 0 END),0,
                           N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Wait-Capture und Pflichtspalte müssen verfügbar sein; fehlendes Wait-Capture ist kein Fehler.');
                    IF @ActualState IN(1,2,4) AND @WaitStatsCaptureMode=1 SET @IsPartial=1;
                END;

                IF @ActualState IN(1,2,4) AND @HasForcingLocations=1 AND @ForcingSchemaValid=1
                BEGIN
                    SELECT @RowsBefore=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_ForcingByReplica];
                    SET @ForcingSql=N'USE '+QUOTENAME(@DatabaseName)+N';
;WITH [ReplicaMap] AS
(
    SELECT [replica_group_id],MIN([role_type]) AS [role_type],MAX(CONVERT(nvarchar(4000),[replica_name])) AS [replica_name]
    FROM [sys].[query_store_replicas] WITH (NOLOCK)
    GROUP BY [replica_group_id]
),
[F] AS
(
    SELECT [pfl].[replica_group_id],COUNT_BIG(*) AS [LocationCount],
           COUNT_BIG(DISTINCT [pfl].[query_id]) AS [QueryCount],COUNT_BIG(DISTINCT [pfl].[plan_id]) AS [PlanCount]
    FROM [sys].[query_store_plan_forcing_locations] AS [pfl] WITH (NOLOCK)
    WHERE NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter])
       OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ReplicaFilter] AS [rf]
                 WHERE [rf].[IsValid]=1 AND [rf].[ReplicaGroupId]=[pfl].[replica_group_id])
    GROUP BY [pfl].[replica_group_id]
)
INSERT [#QueryStoreReplicaAnalysis_ForcingByReplica]
([CapturedAtUtc],[DatabaseId],[DatabaseName],[CurrentConnectionRoleDesc],[ReplicaGroupId],
 [RoleType],[RoleTypeDesc],[RoleClass],[ReplicaName],[MappingStatusCode],
 [ForcingLocationCount],[ForcedQueryCount],[ForcedPlanCount],[EvidenceLimit])
SELECT @pCapturedAtUtc,@pDatabaseId,@pDatabaseName,@pCurrentRoleDesc,[F].[replica_group_id],
       [rm].[role_type],[mi].[RoleTypeDesc],[mi].[RoleClass],[rm].[replica_name],
       CASE WHEN [rm].[replica_group_id] IS NULL THEN ''REPLICA_METADATA_MISSING'' ELSE ''AVAILABLE'' END,
       [F].[LocationCount],[F].[QueryCount],[F].[PlanCount],
       N''Replica-spezifische Forcing-Locations; keine Planwirkung, Regressionsursache oder Änderungsempfehlung.''
FROM [F]
LEFT JOIN [ReplicaMap] AS [rm] ON [rm].[replica_group_id]=[F].[replica_group_id]
CROSS APPLY [DeineDatenbank].[monitor].[TVF_QueryStoreReplicaRoleInfo]([rm].[role_type]) AS [mi]
OPTION (MAXDOP 1,RECOMPILE);';
                    BEGIN TRY
                        EXEC [sys].[sp_executesql] @ForcingSql,
                             N'@pCapturedAtUtc datetime2(3),@pDatabaseId int,@pDatabaseName sysname,@pCurrentRoleDesc varchar(40)',
                             @CapturedAtUtc,@DatabaseId,@DatabaseName,@CurrentRoleDesc;
                        SELECT @RowsAfter=COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_ForcingByReplica];
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'forcingByReplica',N'sys.query_store_plan_forcing_locations',@CapturedAtUtc,
                               CASE WHEN @RowsAfter=@RowsBefore THEN 'EMPTY_VISIBLE_SCOPE' ELSE 'AVAILABLE' END,0,@RowsAfter-@RowsBefore,
                               N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,N'Forcing-Locations werden nach replica_group_id getrennt und ausschließlich inventarisiert.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                        ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                        VALUES(@DatabaseId,@DatabaseName,N'forcingByReplica',N'sys.query_store_plan_forcing_locations',@CapturedAtUtc,
                               CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                               1,0,N'VIEW DATABASE PERFORMANCE STATE',ERROR_NUMBER(),ERROR_MESSAGE(),N'Der Forcingfehler ist auf diese Quelle begrenzt.');
                        INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
                        VALUES(@DatabaseName,N'forcingByReplica','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE());
                        SET @IsPartial=1;
                    END CATCH;
                END
                ELSE
                BEGIN
                    INSERT [#QueryStoreReplicaAnalysis_SourceStatus]
                    ([DatabaseId],[DatabaseName],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@DatabaseId,@DatabaseName,N'forcingByReplica',N'sys.query_store_plan_forcing_locations',@CapturedAtUtc,
                           CASE WHEN @ActualState NOT IN(1,2,4) THEN 'FEATURE_DISABLED'
                                WHEN @HasForcingLocations=0 THEN 'UNAVAILABLE_FEATURE' ELSE 'UNAVAILABLE_SCHEMA' END,
                           CONVERT(bit,CASE WHEN @ActualState IN(1,2,4) THEN 1 ELSE 0 END),0,N'VIEW DATABASE PERFORMANCE STATE',NULL,NULL,
                           N'Die Forcingquelle wird nur nach erfolgreicher Objekt- und Pflichtspaltenprüfung referenziert.');
                    IF @ActualState IN(1,2,4) SET @IsPartial=1;
                END;
            END;

            FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [DatabaseCursor];
        DEALLOCATE [DatabaseCursor];

        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
    END;

    DECLARE @ReplicaCandidateCount bigint=(SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_Replicas]);
    DECLARE @RuntimeCandidateCount bigint=(SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica]);
    DECLARE @WaitCandidateCount bigint=(SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_WaitsByReplica]);
    DECLARE @ForcingCandidateCount bigint=(SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_ForcingByReplica]);
    DECLARE @HasMoreReplicaRows bit=CONVERT(bit,CASE WHEN @ReplicaCandidateCount>@Limit THEN 1 ELSE 0 END);
    DECLARE @HasMoreRuntimeRows bit=CONVERT(bit,CASE WHEN @RuntimeCandidateCount>@Limit THEN 1 ELSE 0 END);
    DECLARE @HasMoreWaitRows bit=CONVERT(bit,CASE WHEN @WaitCandidateCount>@Limit THEN 1 ELSE 0 END);
    DECLARE @HasMoreForcingRows bit=CONVERT(bit,CASE WHEN @ForcingCandidateCount>@Limit THEN 1 ELSE 0 END);

    IF @Limit<9223372036854775807
    BEGIN
        ;WITH [x] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[ReplicaGroupId],[RoleType]) AS [rn] FROM [#QueryStoreReplicaAnalysis_Replicas])
        DELETE FROM [x] WHERE [rn]>@Limit;
        ;WITH [x] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [TotalCpuMs] DESC,[LastExecutionTimeUtc] DESC,[DatabaseId],[ReplicaGroupId]) AS [rn] FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica])
        DELETE FROM [x] WHERE [rn]>@Limit;
        ;WITH [x] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC,[DatabaseId],[ReplicaGroupId]) AS [rn] FROM [#QueryStoreReplicaAnalysis_WaitsByReplica])
        DELETE FROM [x] WHERE [rn]>@Limit;
        ;WITH [x] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [ForcingLocationCount] DESC,[DatabaseId],[ReplicaGroupId]) AS [rn] FROM [#QueryStoreReplicaAnalysis_ForcingByReplica])
        DELETE FROM [x] WHERE [rn]>@Limit;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        IF @ProductMajorVersion IS NULL OR @ProductMajorVersion<17
            SET @StatusCode='UNAVAILABLE_VERSION';
        ELSE IF @IsPartial=1
            SET @StatusCode='AVAILABLE_LIMITED';
        ELSE IF NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_Replicas])
             AND NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica])
             AND NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_WaitsByReplica])
             AND NOT EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ForcingByReplica])
            SET @StatusCode='NOT_APPLICABLE';
    END;

    IF EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica] WHERE [MappingStatusCode]<>'AVAILABLE')
       OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_WaitsByReplica] WHERE [MappingStatusCode]<>'AVAILABLE')
       OR EXISTS(SELECT 1 FROM [#QueryStoreReplicaAnalysis_ForcingByReplica] WHERE [MappingStatusCode]<>'AVAILABLE')
    BEGIN
        IF @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';
        SET @IsPartial=1;
        INSERT [#QueryStoreReplicaAnalysis_Warnings]([DatabaseName],[SourceName],[StatusCode],[ErrorNumber],[Message])
        SELECT DISTINCT [DatabaseName],N'replicaMapping','REPLICA_METADATA_MISSING',NULL,
               N'Mindestens eine replica_group_id besitzt keine sichtbare Zuordnung in sys.query_store_replicas; die Messwerte bleiben getrennt und werden nicht einer Rolle zugeschrieben.'
        FROM
        (
            SELECT [DatabaseName] FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica] WHERE [MappingStatusCode]<>'AVAILABLE'
            UNION
            SELECT [DatabaseName] FROM [#QueryStoreReplicaAnalysis_WaitsByReplica] WHERE [MappingStatusCode]<>'AVAILABLE'
            UNION
            SELECT [DatabaseName] FROM [#QueryStoreReplicaAnalysis_ForcingByReplica] WHERE [MappingStatusCode]<>'AVAILABLE'
        ) AS [u];
    END;

    INSERT [#QueryStoreReplicaAnalysis_ModuleStatus]
    SELECT N'USP_QueryStoreReplicaAnalysis',@CapturedAtUtc,@StatusCode,@IsPartial,@ProductMajorVersion,
           @CrossDatabaseRequested,
           (SELECT COUNT(*) FROM [#QueryStoreReplicaAnalysis_DatabaseCandidates]),
           (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_Replicas]),
           (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica]),
           (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_WaitsByReplica]),
           (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_ForcingByReplica]),
           @HasMoreReplicaRows,@HasMoreRuntimeRows,@HasMoreWaitRows,@HasMoreForcingRows,@ErrorNumber,@ErrorMessage;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=
        (
            SELECT N'QueryStoreReplicaAnalysis' AS [resultName],1 AS [schemaVersion],
                   @CapturedAtUtc AS [generatedAtUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],
                   @ProductMajorVersion AS [productMajorVersion],@VonUtc AS [fromUtc],@BisUtc AS [toUtc],
                   @MaxZeilen AS [requestedMaxRows],@HasMoreReplicaRows AS [hasMoreReplicaRows],
                   @HasMoreRuntimeRows AS [hasMoreRuntimeRows],@HasMoreWaitRows AS [hasMoreWaitRows],
                   @HasMoreForcingRows AS [hasMoreForcingRows]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @ModuleJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_ModuleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ReplicasJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_Replicas] ORDER BY [DatabaseId],[ReplicaGroupId],[RoleType] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RuntimeJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica] ORDER BY [TotalCpuMs] DESC,[LastExecutionTimeUtc] DESC FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WaitsJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_WaitsByReplica] ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ForcingJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_ForcingByReplica] ORDER BY [ForcingLocationCount] DESC,[DatabaseId],[ReplicaGroupId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @SourcesJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_SourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max)=(SELECT * FROM [#QueryStoreReplicaAnalysis_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),
                         N',"moduleStatus":',COALESCE(@ModuleJson,N'[]'),
                         N',"replicas":',COALESCE(@ReplicasJson,N'[]'),
                         N',"runtimeByReplica":',COALESCE(@RuntimeJson,N'[]'),
                         N',"waitsByReplica":',COALESCE(@WaitsJson,N'[]'),
                         N',"forcingByReplica":',COALESCE(@ForcingJson,N'[]'),
                         N',"sourceStatus":',COALESCE(@SourcesJson,N'[]'),
                         N',"warnings":',COALESCE(@WarningsJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#QueryStoreReplicaAnalysis_ModuleStatus];
        SELECT * FROM [#QueryStoreReplicaAnalysis_Replicas] ORDER BY [DatabaseId],[ReplicaGroupId],[RoleType];
        SELECT * FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica] ORDER BY [TotalCpuMs] DESC,[LastExecutionTimeUtc] DESC;
        SELECT * FROM [#QueryStoreReplicaAnalysis_WaitsByReplica] ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC;
        SELECT * FROM [#QueryStoreReplicaAnalysis_ForcingByReplica] ORDER BY [ForcingLocationCount] DESC,[DatabaseId],[ReplicaGroupId];
        SELECT * FROM [#QueryStoreReplicaAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#QueryStoreReplicaAnalysis_Warnings] ORDER BY [WarningOrdinal];
    END
    ELSE IF @OutputMode='CONSOLE'
    BEGIN
        SELECT N'Query Store Replica Analysis' AS [Ergebnis],@CapturedAtUtc AS [Stand_UTC],
               @StatusCode AS [Status],@IsPartial AS [Partiell],@VonUtc AS [Von_UTC],@BisUtc AS [Bis_UTC],
               (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_Replicas]) AS [Beobachtete_Rollen],
               (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica]) AS [Runtime_Gruppen],
               (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_WaitsByReplica]) AS [Wait_Gruppen],
               (SELECT COUNT_BIG(*) FROM [#QueryStoreReplicaAnalysis_ForcingByReplica]) AS [Forcing_Gruppen];

        SELECT N'Beobachtete Query-Store-Rolle' AS [Ergebnis],[DatabaseName] AS [Datenbank],
               [ReplicaGroupId] AS [Replica_Group_ID],[RoleTypeDesc] AS [Beobachtete_Rolle],
               [RoleClass] AS [Rollenklasse],[CurrentConnectionRoleDesc] AS [Aktuelle_Verbindungsrolle],
               [ReplicaName] AS [Replica_Name],[StatusCode] AS [Status]
        FROM [#QueryStoreReplicaAnalysis_Replicas]
        ORDER BY [DatabaseId],[ReplicaGroupId],[RoleType];

        SELECT N'Runtime nach Replica-Rolle' AS [Ergebnis],[DatabaseName] AS [Datenbank],
               [ReplicaGroupId] AS [Replica_Group_ID],[RoleTypeDesc] AS [Rolle],
               [ExecutionCount] AS [Ausführungen],CONCAT(CONVERT(varchar(50),[TotalCpuMs]),N' ms') AS [CPU_gesamt],
               CONCAT(CONVERT(varchar(50),[TotalDurationMs]),N' ms') AS [Dauer_gesamt],
               [TotalLogicalReads] AS [Logical_Reads],[LastExecutionTimeUtc] AS [Letzte_Ausführung_UTC],
               [MappingStatusCode] AS [Zuordnung]
        FROM [#QueryStoreReplicaAnalysis_RuntimeByReplica]
        ORDER BY [TotalCpuMs] DESC,[LastExecutionTimeUtc] DESC;

        SELECT N'Waits nach Replica-Rolle' AS [Ergebnis],[DatabaseName] AS [Datenbank],
               [ReplicaGroupId] AS [Replica_Group_ID],[RoleTypeDesc] AS [Rolle],
               [WaitCategoryDesc] AS [Wait_Kategorie],[ExecutionTypeDesc] AS [Ausführungstyp],
               CONCAT(CONVERT(varchar(50),CONVERT(decimal(38,3),[TotalQueryWaitTimeMs]/1000.0)),N' s') AS [Wait_gesamt],
               [MappingStatusCode] AS [Zuordnung]
        FROM [#QueryStoreReplicaAnalysis_WaitsByReplica]
        ORDER BY [TotalQueryWaitTimeMs] DESC,[LastIntervalEndUtc] DESC;

        SELECT N'Query-Store-Quellenstatus' AS [Ergebnis],[DatabaseName] AS [Datenbank],
               [SourceName] AS [Quelle],[StatusCode] AS [Status],[ReturnedRowCount] AS [Zeilen],
               [ErrorMessage] AS [Fehler],[EvidenceLimit] AS [Aussagegrenze]
        FROM [#QueryStoreReplicaAnalysis_SourceStatus]
        ORDER BY [SourceOrdinal];
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        DECLARE @TargetTable sysname;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'moduleStatus';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_ModuleStatus',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'replicas';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_Replicas',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'runtimeByReplica';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_RuntimeByReplica',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'waitsByReplica';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_WaitsByReplica',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'forcingByReplica';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_ForcingByReplica',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'sourceStatus';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_SourceStatus',@TargetTable=@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'warnings';
        IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_Warnings',@TargetTable=@TargetTable,@ThrowOnError=1;
    END;
END;
GO
