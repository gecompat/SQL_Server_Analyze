# Eigenständige Analysebeschreibungen je Procedure

**Stand:** 20. Juli 2026<br>
**Strukturelle Abdeckung:** 84 Procedures<br>
**Tief geprüft nach Qualitätsvertrag v2:** 3 Procedures

Jede Seite verbindet den sicheren Einstieg mit der fachlichen Leserichtung. Sie beantwortet insbesondere:

1. Was bedeutet eine Zeile im jeweiligen Resultset?
2. Welche Werte müssen zuerst und gemeinsam gelesen werden?
3. Warum kann eine Konstellation technisch problematisch sein?
4. Unter welchen Bedingungen ist derselbe Einzelwert unkritisch?
5. Welche zweite Analyse bestätigt oder widerlegt die Vermutung?
6. Warum ist eine leere oder partielle Ausgabe nicht automatisch eine Entwarnung?

Die vollständigen technischen Spaltentabellen bleiben in den verlinkten Familienguides. Exakte Parameter und Defaults liefert zusätzlich `@Hilfe=1` beziehungsweise das [Procedure-Referenzhandbuch](../../Reference/Procedure_Reference.md).

## Reifegrad richtig lesen

Alle 84 öffentlichen Procedures besitzen eine `BASELINE`-Seite. Das ist noch kein Nachweis, dass Kosten, Limits, Datenentstehung und Aussagegrenzen bereits vollständig am aktuellen T-SQL geprüft wurden. Den verbindlichen Unterschied zwischen `BASELINE` und `DEEP_REVIEWED` beschreibt der [Qualitätsvertrag](../Documentation_Quality_Contract.md); der Status je Procedure liegt im [Review-Manifest](../../../Metadata/Quality/Analysis_Documentation_Review.csv).

Als fachliche Referenz für die weitere Überarbeitung dienen derzeit:

- [USP_CurrentRequests](USP_CurrentRequests.md): flüchtiger Live-Snapshot,
- [USP_IndexPhysicalStats](USP_IndexPhysicalStats.md): physischer Scan mit High-Impact-Gate,
- [USP_ExtendedEventsReadEvents](USP_ExtendedEventsReadEvents.md): Datei/XML und bewusste Nebenwirkung.

Bei allen übrigen Seiten bedeutet `BASELINE`: für Nutzung weiterhin mit SQL-Quelle, Familienguide und gemeinsamen Verträgen abgleichen; fehlende Tiefe nicht als nicht anwendbar interpretieren.

## Common

- [USP_CheckAnalyseAccess](USP_CheckAnalyseAccess.md)
- [USP_CheckFrameworkCapabilities](USP_CheckFrameworkCapabilities.md)
- [USP_PrepareDatabaseCandidates](USP_PrepareDatabaseCandidates.md)
- [USP_PrepareNameFilters](USP_PrepareNameFilters.md)

## Current State

- [USP_CurrentSessions](USP_CurrentSessions.md)
- [USP_CurrentRequests](USP_CurrentRequests.md)
- [USP_CurrentBlocking](USP_CurrentBlocking.md)
- [USP_CurrentWaits](USP_CurrentWaits.md)
- [USP_CurrentTransactions](USP_CurrentTransactions.md)
- [USP_CurrentMemoryGrants](USP_CurrentMemoryGrants.md)
- [USP_CurrentTempDB](USP_CurrentTempDB.md)
- [USP_CurrentIO](USP_CurrentIO.md)
- [USP_CurrentLog](USP_CurrentLog.md)
- [USP_CurrentOverview](USP_CurrentOverview.md)

## Object und Index

- [USP_ObjectInventory](USP_ObjectInventory.md)
- [USP_IndexUsage](USP_IndexUsage.md)
- [USP_IndexOperationalStats](USP_IndexOperationalStats.md)
- [USP_MissingIndexes](USP_MissingIndexes.md)
- [USP_Statistics](USP_Statistics.md)
- [USP_StatisticsDistributionAnalysis](USP_StatisticsDistributionAnalysis.md)
- [USP_Partitions](USP_Partitions.md)
- [USP_Columnstore](USP_Columnstore.md)
- [USP_IndexPhysicalStats](USP_IndexPhysicalStats.md)
- [USP_SchemaDesignAnalysis](USP_SchemaDesignAnalysis.md)
- [USP_ObjectAnalysis](USP_ObjectAnalysis.md)

## Plan Cache und Showplan

- [USP_QueryStats](USP_QueryStats.md)
- [USP_QueryHashAnalysis](USP_QueryHashAnalysis.md)
- [USP_PlanCacheHealth](USP_PlanCacheHealth.md)
- [USP_PlanDetails](USP_PlanDetails.md)
- [USP_ShowplanAnalysis](USP_ShowplanAnalysis.md)
- [USP_PlanCacheAnalysis](USP_PlanCacheAnalysis.md)

## Query Store

- [USP_QueryStoreStatus](USP_QueryStoreStatus.md)
- [USP_QueryStoreRuntimeStats](USP_QueryStoreRuntimeStats.md)
- [USP_QueryStoreWaitStats](USP_QueryStoreWaitStats.md)
- [USP_QueryStorePlanChanges](USP_QueryStorePlanChanges.md)
- [USP_QueryStoreRegressions](USP_QueryStoreRegressions.md)
- [USP_QueryStoreForcedPlans](USP_QueryStoreForcedPlans.md)
- [USP_QueryStoreHints](USP_QueryStoreHints.md)
- [USP_IntelligentQueryProcessingAnalysis](USP_IntelligentQueryProcessingAnalysis.md)
- [USP_QueryStoreAnalysis](USP_QueryStoreAnalysis.md)

## Extended Events

- [USP_ExtendedEventsSessions](USP_ExtendedEventsSessions.md)
- [USP_ExtendedEventsReadEvents](USP_ExtendedEventsReadEvents.md)
- [USP_ExtendedEventsDeadlocks](USP_ExtendedEventsDeadlocks.md)
- [USP_ExtendedEventsBlockedProcesses](USP_ExtendedEventsBlockedProcesses.md)
- [USP_ExtendedEventsTargetRuntime](USP_ExtendedEventsTargetRuntime.md)
- [USP_ExtendedEventsAnalysis](USP_ExtendedEventsAnalysis.md)

## Infrastruktur

- [USP_AgentStatus](USP_AgentStatus.md)
- [USP_AgentJobs](USP_AgentJobs.md)
- [USP_ResourceGovernorAnalysis](USP_ResourceGovernorAnalysis.md)
- [USP_AvailabilityGroups](USP_AvailabilityGroups.md)
- [USP_BackupRecovery](USP_BackupRecovery.md)
- [USP_LogShippingStatus](USP_LogShippingStatus.md)
- [USP_ReplicationStatus](USP_ReplicationStatus.md)
- [USP_DataCaptureStatus](USP_DataCaptureStatus.md)
- [USP_InfrastructureAnalysis](USP_InfrastructureAnalysis.md)
- [USP_BackupChainAnalysis](USP_BackupChainAnalysis.md)
- [USP_AvailabilityDeepAnalysis](USP_AvailabilityDeepAnalysis.md)
- [USP_AgentMonitoringAnalysis](USP_AgentMonitoringAnalysis.md)
- [USP_MaintenanceOperations](USP_MaintenanceOperations.md)

## Server Health

- [USP_ServerCpuTopology](USP_ServerCpuTopology.md)
- [USP_ServerNuma](USP_ServerNuma.md)
- [USP_ServerMemory](USP_ServerMemory.md)
- [USP_TempDBConfiguration](USP_TempDBConfiguration.md)
- [USP_ServerConfiguration](USP_ServerConfiguration.md)
- [USP_TraceFlags](USP_TraceFlags.md)
- [USP_StartupParameters](USP_StartupParameters.md)
- [USP_OSInformation](USP_OSInformation.md)
- [USP_ServerSecurityConfiguration](USP_ServerSecurityConfiguration.md)
- [USP_ServerHealthAnalysis](USP_ServerHealthAnalysis.md)
- [USP_DatabaseIntegrityAnalysis](USP_DatabaseIntegrityAnalysis.md)
- [USP_DatabaseCapacityAnalysis](USP_DatabaseCapacityAnalysis.md)
- [USP_PerformanceCounters](USP_PerformanceCounters.md)
- [USP_CriticalEngineEvents](USP_CriticalEngineEvents.md)
- [USP_InternalContentionAnalysis](USP_InternalContentionAnalysis.md)
- [USP_BufferPoolAnalysis](USP_BufferPoolAnalysis.md)
- [USP_DiagnosticFindings](USP_DiagnosticFindings.md)

## Versionsadaptive Spezialanalysen

- [USP_ServerFeatureCapabilities](USP_ServerFeatureCapabilities.md)
- [USP_SpecialFeatureInventory](USP_SpecialFeatureInventory.md)
- [USP_InMemoryOltpAnalysis](USP_InMemoryOltpAnalysis.md)
- [USP_TemporalAnalysis](USP_TemporalAnalysis.md)
- [USP_ServiceBrokerAnalysis](USP_ServiceBrokerAnalysis.md)
- [USP_FullTextAnalysis](USP_FullTextAnalysis.md)
- [USP_DataCaptureDeepAnalysis](USP_DataCaptureDeepAnalysis.md)
- [USP_EncryptionAnalysis](USP_EncryptionAnalysis.md)
