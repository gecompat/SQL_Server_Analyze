USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 167_Special_Case_API_Contract.sql
Zweck        : Metadatenbasierter API-Vertrag der Spezialfallmodule.
Nebenwirkung : keine fachlichen Scans und keine Persistenz.
===============================================================================
*/
SET NOCOUNT ON;

DECLARE @Expected TABLE
(
      [ProcedureName] sysname NOT NULL
    , [RequiredParameter] sysname NOT NULL
);

INSERT @Expected
VALUES
(N'USP_DatabaseIntegrityAnalysis',N'@ResultSetArt'),
(N'USP_DatabaseIntegrityAnalysis',N'@Json'),
(N'USP_DatabaseIntegrityAnalysis',N'@BackupHistoryDays'),
(N'USP_DatabaseCapacityAnalysis',N'@ResultSetArt'),
(N'USP_PerformanceCounters',N'@SampleSeconds'),
(N'USP_CriticalEngineEvents',N'@MitServerDiagnostics'),
(N'USP_IntelligentQueryProcessingAnalysis',N'@DatabaseNames'),
(N'USP_InternalContentionAnalysis',N'@SampleSeconds'),
(N'USP_BufferPoolAnalysis',N'@MitBufferPoolVerteilung'),
(N'USP_BackupChainAnalysis',N'@HistoryDays'),
(N'USP_SchemaDesignAnalysis',N'@IdentityWarnPercent'),
(N'USP_StatisticsDistributionAnalysis',N'@MaxVerteilungsStatistiken'),
(N'USP_StatisticsDistributionAnalysis',N'@SkewWarnFaktor'),
(N'USP_ObjectAnalysis',N'@MitStatisticsDistribution'),
(N'USP_AvailabilityDeepAnalysis',N'@MitClusterNetzwerken'),
(N'USP_AgentMonitoringAnalysis',N'@HistoryHours'),
(N'USP_DiagnosticFindings',N'@NurAbPrioritaet'),
(N'USP_DiagnosticFindings',N'@MitStatistikverteilung'),
(N'USP_DiagnosticFindings',N'@Json'),
(N'USP_SpecialFeatureInventory',N'@NurErkannteFeatures'),
(N'USP_SpecialFeatureInventory',N'@StatusCodeOut'),
(N'USP_InMemoryOltpAnalysis',N'@MitHashIndexStats'),
(N'USP_InMemoryOltpAnalysis',N'@HashAvgChainWarn'),
(N'USP_InMemoryOltpAnalysis',N'@StatusCodeOut'),
(N'USP_TemporalAnalysis',N'@HistorySizeWarnMb'),
(N'USP_TemporalAnalysis',N'@MinHistoryMbForRatioWarn'),
(N'USP_TemporalAnalysis',N'@StatusCodeOut');

DECLARE @Missing nvarchar(max);

SELECT @Missing = STRING_AGG(CONCAT([e].[ProcedureName],N'.',[e].[RequiredParameter]),N', ')
FROM @Expected AS [e]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [sys].[procedures] AS [p]
    JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[p].[schema_id]
    JOIN [sys].[parameters] AS [x] ON [x].[object_id]=[p].[object_id]
    WHERE [s].[name]=N'monitor'
      AND [p].[name]=[e].[ProcedureName]
      AND [x].[name]=[e].[RequiredParameter]
);

IF @Missing IS NOT NULL
BEGIN
    DECLARE @Message nvarchar(2048)=CONCAT(N'Fehlende Spezialfall-API: ',@Missing);
    THROW 54100,@Message,1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[sql_expression_dependencies] AS [d]
    WHERE [d].[referencing_id]=OBJECT_ID(N'monitor.USP_DiagnosticFindings')
      AND [d].[referenced_entity_name]=N'USP_DatabaseIntegrityAnalysis'
)
    THROW 54101,N'USP_DiagnosticFindings besitzt keine erkennbare Abhängigkeit zur Integritätsevidenz.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[parameters]
    WHERE [object_id]=OBJECT_ID(N'monitor.USP_ServerHealthAnalysis')
      AND [name]=N'@MitFindings'
)
    THROW 54102,N'Der Server-Health-Orchestrator veröffentlicht @MitFindings nicht.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[sql_expression_dependencies] AS [d]
    WHERE [d].[referencing_id]=OBJECT_ID(N'monitor.USP_DiagnosticFindings')
      AND [d].[referenced_entity_name]=N'USP_StatisticsDistributionAnalysis'
)
    THROW 54103,N'USP_DiagnosticFindings besitzt keine erkennbare Abhängigkeit zur Statistikverteilung.',1;

DECLARE @InMemoryDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_InMemoryOltpAnalysis'));
IF @InMemoryDefinition IS NULL
    THROW 54104,N'Die Definition der In-Memory-OLTP-Analyse ist nicht sichtbar.',1;

IF @InMemoryDefinition LIKE N'%[[]relative_file_path[]]%'
 OR @InMemoryDefinition LIKE N'%[[]container_id[]]%'
 OR @InMemoryDefinition LIKE N'%[[]xtp_transaction_id[]]%'
 OR @InMemoryDefinition LIKE N'%[[]transaction_id[]]%'
 OR @InMemoryDefinition LIKE N'%[[]session_id[]]%'
 OR @InMemoryDefinition LIKE N'%[[]memory_address[]]%'
    THROW 54105,N'Die In-Memory-OLTP-Analyse referenziert einen ausgeschlossenen Detailidentifikator.',1;

DECLARE @TemporalDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_TemporalAnalysis'));
IF @TemporalDefinition IS NULL
    THROW 54106,N'Die Definition der Temporal-Tables-Analyse ist nicht sichtbar.',1;

IF @TemporalDefinition NOT LIKE N'%[[]sys[]].[[]periods[]]%'
 OR @TemporalDefinition NOT LIKE N'%[[]history_table_id[]]%'
 OR @TemporalDefinition NOT LIKE N'%[[]dm_db_partition_stats[]]%'
    THROW 54107,N'Die Temporal-Tables-Analyse besitzt nicht alle erwarteten read-only Metadatenquellen.',1;

IF @TemporalDefinition LIKE N'%FOR SYSTEM_TIME AS OF%'
 OR @TemporalDefinition LIKE N'%FOR SYSTEM_TIME ALL%'
 OR @TemporalDefinition LIKE N'%SYSTEM_VERSIONING = OFF%'
    THROW 54108,N'Die Temporal-Tables-Analyse enthält einen ausgeschlossenen Nutzdaten- oder Änderungszugriff.',1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [VerifiedContractEntries],
       N'Nur Katalog- und Abhängigkeitsprüfung; keine fachlichen Scans.' AS [Detail]
FROM @Expected;
GO
