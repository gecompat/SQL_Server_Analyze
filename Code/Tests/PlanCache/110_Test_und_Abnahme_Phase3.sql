USE [DeineDatenbank];
GO

-- Sichere Signatur-/Hilfeprüfung; keine ressourcenintensive Analyse.
EXEC [monitor].[USP_QueryStats] @Hilfe=1;
EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;
GO
