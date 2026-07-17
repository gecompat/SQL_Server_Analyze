USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 110_Smoke_Test.sql
Zweck        : Kompakter optionaler Smoke Test nach Installation oder Upgrade.
               Keine Persistenz, keine Konfigurationsänderung, keine Deep-Scans.
===============================================================================
*/
SET NOCOUNT ON;
USE [DeineDatenbank];
GO

DECLARE @Missing nvarchar(max);
DECLARE @Expected TABLE([ObjectName] nvarchar(256), [ObjectType] char(2));

INSERT @Expected([ObjectName],[ObjectType])
VALUES
(N'monitor.VW_ModuleStatusCatalog','V'),
(N'monitor.VW_AnalyseClassCatalog','V'),
(N'monitor.VW_FrameworkFeatureCatalog','V'),
(N'monitor.WaitTypeCatalog','U'),
(N'monitor.FrameworkVersion','U'),
(N'monitor.TVF_WaitTypeInfo','IF'),
(N'monitor.TVF_StatementText','IF'),
(N'monitor.USP_CheckAnalyseAccess','P'),
(N'monitor.USP_CheckFrameworkCapabilities','P'),
(N'monitor.USP_CurrentOverview','P'),
(N'monitor.USP_CurrentWaits','P'),
(N'monitor.USP_ObjectAnalysis','P'),
(N'monitor.USP_PlanCacheAnalysis','P'),
(N'monitor.USP_QueryStoreAnalysis','P'),
(N'monitor.USP_ExtendedEventsAnalysis','P'),
(N'monitor.USP_InfrastructureAnalysis','P'),
(N'monitor.USP_ServerHealthAnalysis','P'),
(N'monitor.USP_DatabaseIntegrityAnalysis','P'),
(N'monitor.USP_DatabaseCapacityAnalysis','P'),
(N'monitor.USP_PerformanceCounters','P'),
(N'monitor.USP_CriticalEngineEvents','P'),
(N'monitor.USP_IntelligentQueryProcessingAnalysis','P'),
(N'monitor.USP_InternalContentionAnalysis','P'),
(N'monitor.USP_BufferPoolAnalysis','P'),
(N'monitor.USP_BackupChainAnalysis','P'),
(N'monitor.USP_SchemaDesignAnalysis','P'),
(N'monitor.USP_StatisticsDistributionAnalysis','P'),
(N'monitor.USP_AvailabilityDeepAnalysis','P'),
(N'monitor.USP_AgentMonitoringAnalysis','P'),
(N'monitor.USP_DiagnosticFindings','P'),
(N'monitor.USP_ServerFeatureCapabilities','P'),
(N'monitor.USP_SpecialFeatureInventory','P'),
(N'monitor.USP_InMemoryOltpAnalysis','P'),
(N'monitor.USP_TemporalAnalysis','P');

SELECT @Missing = STRING_AGG([ObjectName],N', ')
FROM @Expected
WHERE OBJECT_ID([ObjectName],[ObjectType]) IS NULL;

IF @Missing IS NOT NULL
BEGIN
    DECLARE @MissingMessage nvarchar(2048)=CONCAT(N'Fehlende Kernobjekte: ',@Missing);
    THROW 54000,@MissingMessage,1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[FrameworkVersion] WITH (READUNCOMMITTED)
    WHERE [FrameworkName]=N'SQLServerMonitoringFramework'
      AND [FrameworkVersion]='1.1.0-special.5'
)
    THROW 54001,N'FrameworkVersion fehlt oder entspricht nicht dem Spezialfall-Release.',1;

IF (SELECT COUNT_BIG(*) FROM [monitor].[WaitTypeCatalog] WITH (READUNCOMMITTED) WHERE [IsFrameworkDefault]=1) < 350
    THROW 54002,N'Der Framework-Wait-Katalog ist unvollständig.',1;

IF EXISTS
(
    SELECT 1
    FROM [monitor].[WaitTypeCatalog] WITH (READUNCOMMITTED)
    WHERE [IsFrameworkDefault]=1
      AND ([Meaning] IS NULL OR [TypicalOccurrence] IS NULL OR [HighWaitImpact] IS NULL
           OR [RecommendedChecks] IS NULL OR [HelpUrl] IS NULL)
)
    THROW 54003,N'Der Framework-Wait-Katalog enthält unvollständige Pflichtinformationen.',1;

IF OBJECT_ID(N'monitor.FrameworkInstallationHistory',N'U') IS NOT NULL
 OR OBJECT_ID(N'monitor.FrameworkExpectedObject',N'U') IS NOT NULL
 OR OBJECT_ID(N'monitor.FrameworkProcedureContract',N'U') IS NOT NULL
 OR OBJECT_ID(N'monitor.USP_FrameworkSelfTest',N'P') IS NOT NULL
    THROW 54004,N'Veraltete Production-Hardening-Objekte sind noch vorhanden.',1;

-- Zentrale Offsetlogik mit einem deterministischen Batch prüfen.
DECLARE @ExtractedStatement nvarchar(max);
SELECT @ExtractedStatement = [StatementText]
FROM [monitor].[TVF_StatementText]
(
      N'SELECT 1; SELECT 2;'
    , 20
    , -1
);

IF @ExtractedStatement <> N'SELECT 2;'
    THROW 54005,N'TVF_StatementText hat den erwarteten Statementausschnitt nicht geliefert.',1;

-- Aktuelle eigene Session eng begrenzt über den echten Ausführungspfad prüfen.
DECLARE @CurrentSessionIds nvarchar(20)=CONVERT(nvarchar(20),@@SPID);
DECLARE @CurrentRequestsJson nvarchar(max);
EXEC [monitor].[USP_CurrentRequests]
      @SessionIds=@CurrentSessionIds
    , @AktuelleSessionEinbeziehen=1
    , @GesamtenSqlTextEinbeziehen=1
    , @InputBufferEinbeziehen=1
    , @MaxSqlTextZeichen=0
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@CurrentRequestsJson OUTPUT;

IF COALESCE(ISJSON(@CurrentRequestsJson),0)<>1
    THROW 54006,N'USP_CurrentRequests hat kein gültiges JSON geliefert.',1;

-- Leichte Hilfepfade: prüfen die öffentlichen Einstiegspunkte ohne fachliche Deep-Scans.
EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;
EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
EXEC [monitor].[USP_CurrentOverview] @Hilfe=1;
EXEC [monitor].[USP_CurrentWaits] @Hilfe=1;
EXEC [monitor].[USP_ServerFeatureCapabilities] @Hilfe=1;
EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe=1;
EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @Hilfe=1;
EXEC [monitor].[USP_DatabaseCapacityAnalysis] @Hilfe=1;
EXEC [monitor].[USP_PerformanceCounters] @Hilfe=1;
EXEC [monitor].[USP_CriticalEngineEvents] @Hilfe=1;
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @Hilfe=1;
EXEC [monitor].[USP_InternalContentionAnalysis] @Hilfe=1;
EXEC [monitor].[USP_BufferPoolAnalysis] @Hilfe=1;
EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe=1;
EXEC [monitor].[USP_SchemaDesignAnalysis] @Hilfe=1;
EXEC [monitor].[USP_StatisticsDistributionAnalysis] @Hilfe=1;
EXEC [monitor].[USP_AvailabilityDeepAnalysis] @Hilfe=1;
EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe=1;
EXEC [monitor].[USP_DiagnosticFindings] @Hilfe=1;
EXEC [monitor].[USP_SpecialFeatureInventory] @Hilfe=1;
EXEC [monitor].[USP_InMemoryOltpAnalysis] @Hilfe=1;
EXEC [monitor].[USP_TemporalAnalysis] @Hilfe=1;

SELECT
    CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
    CAST(0 AS bit) AS [IsPartial],
    (SELECT [FrameworkVersion] FROM [monitor].[FrameworkVersion] WITH (READUNCOMMITTED)
     WHERE [FrameworkName]=N'SQLServerMonitoringFramework') AS [FrameworkVersion],
    (SELECT COUNT_BIG(*) FROM [sys].[procedures] p WITH (READUNCOMMITTED)
     JOIN [sys].[schemas] s WITH (READUNCOMMITTED) ON [s].[schema_id]=[p].[schema_id]
     WHERE [s].[name]=N'monitor') AS [ProcedureCount],
    (SELECT COUNT_BIG(*) FROM [monitor].[WaitTypeCatalog] WITH (READUNCOMMITTED)
     WHERE [IsFrameworkDefault]=1) AS [FrameworkWaitTypeCount],
    N'Kompakter Smoke Test erfolgreich.' AS [Detail];
GO
