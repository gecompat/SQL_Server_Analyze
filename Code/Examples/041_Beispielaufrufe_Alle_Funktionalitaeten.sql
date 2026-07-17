USE [DeineDatenbank];
GO

/* Vollständiger, sicherer Beispielkatalog. Sämtliche Aufrufe sind auskommentiert. */
USE [DeineDatenbank];
GO

-- EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe = 1;

-- EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe = 1;

-- EXEC [monitor].[USP_PrepareDatabaseCandidates] @Hilfe = 1;

-- EXEC [monitor].[USP_PrepareNameFilters] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentSessions] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentRequests] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentBlocking] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentWaits] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentTransactions] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentMemoryGrants] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentTempDB] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentIO] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentLog] @Hilfe = 1;

-- EXEC [monitor].[USP_CurrentOverview] @Hilfe = 1;

-- EXEC [monitor].[USP_ObjectInventory] @Hilfe = 1;

-- EXEC [monitor].[USP_IndexUsage] @Hilfe = 1;

-- EXEC [monitor].[USP_IndexOperationalStats] @Hilfe = 1;

-- EXEC [monitor].[USP_MissingIndexes] @Hilfe = 1;

-- EXEC [monitor].[USP_Statistics] @Hilfe = 1;

-- EXEC [monitor].[USP_Partitions] @Hilfe = 1;

-- EXEC [monitor].[USP_Columnstore] @Hilfe = 1;

-- EXEC [monitor].[USP_IndexPhysicalStats] @Hilfe = 1;

-- EXEC [monitor].[USP_ObjectAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_SchemaDesignAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStats] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryHashAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_PlanCacheHealth] @Hilfe = 1;

-- EXEC [monitor].[USP_PlanDetails] @Hilfe = 1;

-- EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreStatus] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreRuntimeStats] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreWaitStats] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStorePlanChanges] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreRegressions] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreForcedPlans] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreHints] @Hilfe = 1;

-- EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsSessions] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsReadEvents] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsDeadlocks] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @Hilfe = 1;

-- EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_AgentStatus] @Hilfe = 1;

-- EXEC [monitor].[USP_AgentJobs] @Hilfe = 1;

-- EXEC [monitor].[USP_ResourceGovernorAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_AvailabilityGroups] @Hilfe = 1;

-- EXEC [monitor].[USP_BackupRecovery] @Hilfe = 1;

-- EXEC [monitor].[USP_LogShippingStatus] @Hilfe = 1;

-- EXEC [monitor].[USP_ReplicationStatus] @Hilfe = 1;

-- EXEC [monitor].[USP_DataCaptureStatus] @Hilfe = 1;

-- EXEC [monitor].[USP_InfrastructureAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_AvailabilityDeepAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_AgentMonitoringAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerCpuTopology] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerNuma] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerMemory] @Hilfe = 1;

-- EXEC [monitor].[USP_TempDBConfiguration] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerConfiguration] @Hilfe = 1;

-- EXEC [monitor].[USP_TraceFlags] @Hilfe = 1;

-- EXEC [monitor].[USP_StartupParameters] @Hilfe = 1;

-- EXEC [monitor].[USP_OSInformation] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerSecurityConfiguration] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_DatabaseCapacityAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_PerformanceCounters] @Hilfe = 1;

-- EXEC [monitor].[USP_CriticalEngineEvents] @Hilfe = 1;

-- EXEC [monitor].[USP_InternalContentionAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_BufferPoolAnalysis] @Hilfe = 1;

-- EXEC [monitor].[USP_DiagnosticFindings] @Hilfe = 1;

-- EXEC [monitor].[USP_ServerFeatureCapabilities] @Hilfe = 1;


-- BEGIN CURRENTREQUESTS-STATEMENT-KONTEXT
-- EXEC [monitor].[USP_CurrentRequests];
-- EXEC [monitor].[USP_CurrentRequests] @GesamtenSqlTextEinbeziehen=1,@InputBufferEinbeziehen=1,@MaxSqlTextZeichen=0;
-- EXEC [monitor].[USP_CurrentRequests] @ResultSetArt='RAW';
-- DECLARE @CurrentRequestsJson nvarchar(max);
-- EXEC [monitor].[USP_CurrentRequests] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@CurrentRequestsJson OUTPUT;
-- SELECT @CurrentRequestsJson AS [Json];
-- END CURRENTREQUESTS-STATEMENT-KONTEXT
