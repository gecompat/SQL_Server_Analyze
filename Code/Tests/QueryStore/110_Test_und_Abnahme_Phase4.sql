USE [DeineDatenbank];
GO

-- Sichere Signatur-/Hilfeprüfung; keine ressourcenintensive Analyse.
EXEC [monitor].[USP_QueryStoreStatus] @Hilfe=1;
EXEC [monitor].[USP_QueryStoreRuntimeStats] @Hilfe=1;
EXEC [monitor].[USP_QueryStoreAnalysis] @Hilfe=1;
EXEC [monitor].[USP_FrameworkUsageFromQueryStore] @Hilfe=1;
GO

EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;
GO
