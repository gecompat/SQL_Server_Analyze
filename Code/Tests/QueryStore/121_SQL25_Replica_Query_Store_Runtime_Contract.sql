USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 121_SQL25_Replica_Query_Store_Runtime_Contract.sql
Zweck        : Prüft SQL25-005 versionsadaptiv, ohne Querytexte, Pläne,
               Replikatidentitäten oder Runtimepayloads zu persistieren.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE TABLE [#SQL25ReplicaQueryStore_Failure]
(
      [TestName] sysname NOT NULL
    , [Detail] nvarchar(2048) NOT NULL
);

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1)
    WHERE [RoleTypeDesc]='PRIMARY' AND [RoleClass]='READ_WRITE_ROLE'
      AND [IsPrimaryRole]=1 AND [IsSecondaryRole]=0
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_PRIMARY',N'role_type 1 wurde nicht als PRIMARY eingeordnet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](2)
    WHERE [RoleTypeDesc]='SECONDARY' AND [RoleClass]='READ_ONLY_ROLE'
      AND [IsSecondaryRole]=1
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_SECONDARY',N'role_type 2 wurde nicht als SECONDARY eingeordnet.');

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5)
    WHERE [RoleTypeDesc]='NAMED_REPLICA' AND [IsNamedReplica]=1
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'ROLE_NAMED',N'role_type >= 5 wurde nicht als Named Replica eingeordnet.');

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;
END TRY
BEGIN CATCH
    INSERT [#SQL25ReplicaQueryStore_Failure]
    VALUES(N'HELP',CONCAT(N'@Hilfe ist fehlgeschlagen: ',ERROR_NUMBER(),N'.'));
END CATCH;

DECLARE @Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048),@Json nvarchar(max);
EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @MaxZeilen=-1
    , @ResultSetArt='NONE'
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;
IF @Status<>'INVALID_PARAMETER'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'INVALID_PARAMETER',CONCAT(N'Erwartet INVALID_PARAMETER, erhalten ',COALESCE(@Status,N'NULL'),N'.'));

SET LOCK_TIMEOUT 731;
EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames=N'[DeineDatenbank]'
    , @MaxZeilen=5
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;
IF @@LOCK_TIMEOUT<>731
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'LOCK_TIMEOUT',N'Der ursprüngliche LOCK_TIMEOUT wurde nicht restauriert.');
SET LOCK_TIMEOUT -1;

IF ISJSON(@Json)<>1
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'JSON_VALID',N'Die JSON-Ausgabe ist ungültig.');
IF JSON_QUERY(@Json,N'$.moduleStatus') IS NULL OR JSON_QUERY(@Json,N'$.replicas') IS NULL
   OR JSON_QUERY(@Json,N'$.runtimeByReplica') IS NULL OR JSON_QUERY(@Json,N'$.waitsByReplica') IS NULL
   OR JSON_QUERY(@Json,N'$.forcingByReplica') IS NULL OR JSON_QUERY(@Json,N'$.sourceStatus') IS NULL
   OR JSON_QUERY(@Json,N'$.warnings') IS NULL
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'JSON_SHAPE',N'Mindestens ein kanonisches JSON-Array fehlt.');

DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
IF @Major<17 AND @Status<>'UNAVAILABLE_VERSION'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'VERSION_GATE',CONCAT(N'Vor SQL Server 2025 wurde ',COALESCE(@Status,N'NULL'),N' statt UNAVAILABLE_VERSION geliefert.'));
IF @Major>=17 AND @Status NOT IN('AVAILABLE','AVAILABLE_LIMITED','NOT_APPLICABLE')
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'SQL2025_STATUS',CONCAT(N'Unerwarteter SQL-Server-2025-Status: ',COALESCE(@Status,N'NULL'),N'.'));

CREATE TABLE [#SQL25Replica_Module]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Replicas]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Runtime]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Waits]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Forcing]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Sources]([Seed] bit NULL);
CREATE TABLE [#SQL25Replica_Warnings]([Seed] bit NULL);

BEGIN TRY
    EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
          @QueryStoreDatabaseNames=N'[DeineDatenbank]'
        , @MaxZeilen=5
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=N'{"moduleStatus":"#SQL25Replica_Module","replicas":"#SQL25Replica_Replicas","runtimeByReplica":"#SQL25Replica_Runtime","waitsByReplica":"#SQL25Replica_Waits","forcingByReplica":"#SQL25Replica_Forcing","sourceStatus":"#SQL25Replica_Sources","warnings":"#SQL25Replica_Warnings"}'
        , @PrintMeldungen=0;
END TRY
BEGIN CATCH
    INSERT [#SQL25ReplicaQueryStore_Failure]
    VALUES(N'TABLE_EXECUTION',CONCAT(N'TABLE ist fehlgeschlagen: ',ERROR_NUMBER(),N'.'));
END CATCH;

IF NOT EXISTS(SELECT 1 FROM [#SQL25Replica_Module])
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'TABLE_MODULE',N'moduleStatus wurde nicht geschrieben.');
IF NOT EXISTS(SELECT 1 FROM [#SQL25Replica_Sources] WHERE [SourceName]=N'replicaCatalog')
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'TABLE_SOURCES',N'replicaCatalog fehlt im sourceStatus.');
IF @Major<17 AND EXISTS
(
    SELECT 1 FROM [#SQL25Replica_Sources]
    WHERE [SourceName] IN(N'replicaCatalog',N'runtimeByReplica',N'waitsByReplica',N'forcingByReplica')
      AND [StatusCode]<>'UNAVAILABLE_VERSION'
)
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'PRE17_SOURCES',N'Eine versionsspezifische Quelle liefert vor SQL Server 2025 keinen UNAVAILABLE_VERSION-Status.');

DECLARE @Definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_QueryStoreReplicaAnalysis'));
IF @Definition LIKE N'%query_sql_text%' OR @Definition LIKE N'%query_plan]%' OR @Definition LIKE N'%ALTER DATABASE%'
   OR @Definition LIKE N'%sp_query_store_force_plan%' OR @Definition LIKE N'%sp_query_store_set_hints%'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'READ_ONLY_PRIVACY',N'Die Definition referenziert ausgeschlossene Payload- oder Mutationspfade.');
IF @Definition NOT LIKE N'%query_store_replicas%' OR @Definition NOT LIKE N'%replica_group_id%'
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'REPLICA_CONTRACT',N'Die Replica-Katalog- oder Gruppierungsreferenz fehlt.');

DECLARE @ParentJson nvarchar(max);
EXEC [monitor].[USP_QueryStoreAnalysis]
      @QueryStoreDatabaseNames=N'[DeineDatenbank]'
    , @MitStatus=0
    , @MitRuntimeStats=0
    , @MitReplicaKontext=1
    , @MaxZeilen=5
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@ParentJson OUTPUT
    , @PrintMeldungen=0;
IF ISJSON(@ParentJson)<>1 OR JSON_QUERY(@ParentJson,N'$.replicaContext') IS NULL
    INSERT [#SQL25ReplicaQueryStore_Failure] VALUES(N'PARENT_JSON',N'Der Query-Store-Orchestrator enthält keinen gültigen replicaContext.');

IF EXISTS(SELECT 1 FROM [#SQL25ReplicaQueryStore_Failure])
BEGIN
    SELECT * FROM [#SQL25ReplicaQueryStore_Failure] ORDER BY [TestName];
    THROW 56905,N'SQL25-005 Replica Query Store Runtime Contract fehlgeschlagen.',1;
END;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       N'SQL25_REPLICA_QUERY_STORE_RUNTIME_CONTRACT PASS' AS [Detail];
GO
