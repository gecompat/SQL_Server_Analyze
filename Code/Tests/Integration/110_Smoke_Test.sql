USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 110_Smoke_Test.sql
Zweck        : Führt nach einer Installation oder einem Upgrade einen kompakten,
               optionalen Smoke-Test aus. Der Test persistiert keine Daten,
               ändert keine Konfiguration und führt keine Deep-Scans aus.
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
(N'monitor.VW_AnalysisCatalog','V'),
(N'monitor.VW_AnalysisSearchTerm','V'),
(N'monitor.VW_AnalysisRelation','V'),
(N'monitor.VW_FrameworkFeatureCatalog','V'),
(N'monitor.WaitTypeCatalog','U'),
(N'monitor.WaitTypeCatalogSource','U'),
(N'monitor.FrameworkVersion','U'),
(N'monitor.TVF_WaitTypeInfo','IF'),
(N'monitor.TVF_WaitTypeSources','IF'),
(N'monitor.TVF_StatementText','IF'),
(N'monitor.TVF_InterpretPerformanceCounter','IF'),
(N'monitor.TVF_InterpretContentionCounter','IF'),
(N'monitor.TVF_ClassifyErrorLogEvent','IF'),
(N'monitor.USP_CheckAnalyseAccess','P'),
(N'monitor.USP_CheckFrameworkCapabilities','P'),
(N'monitor.USP_AnalysisNavigator','P'),
(N'monitor.USP_CurrentOverview','P'),
(N'monitor.USP_CurrentWaits','P'),
(N'monitor.USP_ObjectAnalysis','P'),
(N'monitor.USP_VectorIndexAnalysis','P'),
(N'monitor.USP_PlanCacheAnalysis','P'),
(N'monitor.USP_QueryStoreAnalysis','P'),
(N'monitor.USP_FrameworkUsageFromQueryStore','P'),
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
(N'monitor.USP_ErrorLogAnalysis','P'),
(N'monitor.USP_WorkerPressureAnalysis','P'),
(N'monitor.USP_DatabaseConfigurationAnalysis','P'),
(N'monitor.USP_ServerFeatureCapabilities','P'),
(N'monitor.USP_SpecialFeatureInventory','P'),
(N'monitor.USP_InMemoryOltpAnalysis','P'),
(N'monitor.USP_TemporalAnalysis','P'),
(N'monitor.USP_ServiceBrokerAnalysis','P'),
(N'monitor.USP_FullTextAnalysis','P'),
(N'monitor.USP_DataCaptureDeepAnalysis','P'),
(N'monitor.USP_EncryptionAnalysis','P'),
(N'monitor.USP_ExternalRuntimeAnalysis','P'),
(N'monitor.USP_ClrAnalysis','P'),
(N'monitor.USP_MaintenanceOperations','P');

SELECT @Missing = STRING_AGG([ObjectName],N', ')
FROM @Expected AS [e]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [sys].[objects] AS [o] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
            =PARSENAME([e].[ObjectName],2) COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
            =PARSENAME([e].[ObjectName],1) COLLATE SQL_Latin1_General_CP1_CS_AS
      AND [o].[type] COLLATE SQL_Latin1_General_CP1_CS_AS
            =[e].[ObjectType] COLLATE SQL_Latin1_General_CP1_CS_AS
);

IF @Missing IS NOT NULL
BEGIN
    DECLARE @MissingMessage nvarchar(2048)=CONCAT(N'Fehlende Kernobjekte: ',@Missing);
    THROW 54000,@MissingMessage,1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[FrameworkVersion] WITH (NOLOCK)
    WHERE [FrameworkName]=N'SQLServerMonitoringFramework'
      AND [FrameworkVersion]='1.1.0-special.19'
)
    THROW 54001,N'FrameworkVersion fehlt oder entspricht nicht dem Spezialfall-Release.',1;

IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 98
    THROW 54025,N'Der Analysis Catalog enthält nicht genau alle 98 öffentlichen Procedures.',1;

IF EXISTS
(
    SELECT 1
    FROM [monitor].[VW_AnalysisCatalog] AS [c]
    WHERE NOT EXISTS
          (
              SELECT 1
              FROM [monitor].[VW_AnalysisSearchTerm] AS [t]
              WHERE [t].[ProcedureName] = [c].[ProcedureName]
                AND [t].[LanguageCode] = 'de'
          )
       OR NOT EXISTS
          (
              SELECT 1
              FROM [monitor].[VW_AnalysisSearchTerm] AS [t]
              WHERE [t].[ProcedureName] = [c].[ProcedureName]
                AND [t].[LanguageCode] = 'en'
          )
)
    THROW 54026,N'Mindestens eine öffentliche Procedure besitzt keine deutschen und englischen Suchbegriffe.',1;

IF EXISTS
(
    SELECT 1
    FROM [monitor].[VW_AnalysisRelation] AS [r]
    LEFT JOIN [monitor].[VW_AnalysisCatalog] AS [source]
      ON [source].[ProcedureName] = [r].[SourceProcedure]
    LEFT JOIN [monitor].[VW_AnalysisCatalog] AS [target]
      ON [target].[ProcedureName] = [r].[TargetProcedure]
    WHERE [source].[ProcedureName] IS NULL
       OR [target].[ProcedureName] IS NULL
)
    THROW 54027,N'Der Analysis-Relationskatalog enthält eine unbekannte Procedure.',1;

EXEC [monitor].[USP_AnalysisNavigator]
      @Suchtext = N'blocking locks'
    , @MaxZeilen = 5
    , @ResultSetArt = 'RAW';

EXEC [monitor].[USP_AnalysisNavigator]
      @SymptomCode = 'BLOCKING'
    , @MaxZeilen = 5
    , @ResultSetArt = 'RAW';

EXEC [monitor].[USP_AnalysisNavigator]
      @ProcedureName = N'USP_CurrentBlocking'
    , @MaxZeilen = 5
    , @ResultSetArt = 'RAW';

SELECT N'SMOKE_TEST_OK' AS [StatusCode],COUNT_BIG(*) AS [GepruefteObjekte]
FROM @Expected;
GO
