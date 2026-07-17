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
(N'USP_AvailabilityDeepAnalysis',N'@MitClusterNetzwerken'),
(N'USP_AgentMonitoringAnalysis',N'@HistoryHours'),
(N'USP_DiagnosticFindings',N'@NurAbPrioritaet'),
(N'USP_DiagnosticFindings',N'@Json');

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

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [VerifiedContractEntries],
       N'Nur Katalog- und Abhängigkeitsprüfung; keine fachlichen Scans.' AS [Detail]
FROM @Expected;
GO
