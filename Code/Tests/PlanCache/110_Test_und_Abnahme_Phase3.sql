USE [DeineDatenbank];
GO

-- Sichere Signatur-/Hilfeprüfung; keine ressourcenintensive Analyse.
EXEC [monitor].[USP_QueryStats] @Hilfe=1;
EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;
GO

/* Laufinterner Source-Snapshot: zwei Consumer verwenden denselben
   dm_exec_query_stats-Stand; es wird kein SQL-/Plantext ausgegeben. */
DECLARE @PlanCacheJson nvarchar(max);

EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats=1
    , @MitQueryHashAnalysis=1
    , @MitPlanCacheHealth=0
    , @MitShowplanAnalysis=0
    , @DatabaseNames=N'[DeineDatenbank]'
    , @MaxDatenbanken=1
    , @MaxZeilen=10
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@PlanCacheJson OUTPUT
    , @PrintMeldungen=0;

IF ISJSON(@PlanCacheJson)<>1
   OR JSON_VALUE(@PlanCacheJson,N'$.queryStats.meta.resultName')<>N'QueryStats'
   OR JSON_VALUE(@PlanCacheJson,N'$.queryHashes.meta.resultName')<>N'QueryHashAnalysis'
   OR
   (
       SELECT COUNT_BIG(*)
       FROM OPENJSON(@PlanCacheJson,N'$.modules')
       WITH
       (
           [ModuleName] sysname N'$.ModuleName',
           [InvocationStatus] varchar(40) N'$.InvocationStatus'
       )
       WHERE [ModuleName] IN(N'USP_QueryStats',N'USP_QueryHashAnalysis')
         AND [InvocationStatus]='REUSED_PARENT_SNAPSHOT'
   )<>2
    THROW 53300,N'Der laufinterne Plan-Cache-Snapshotvertrag ist verletzt.',1;
GO

/* Ein einzelner Consumer liest frisch und baut keinen Parent-Snapshot auf. */
DECLARE @SingleConsumerJson nvarchar(max);

EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats=1
    , @MitQueryHashAnalysis=0
    , @MitPlanCacheHealth=0
    , @MitShowplanAnalysis=0
    , @DatabaseNames=N'[DeineDatenbank]'
    , @MaxDatenbanken=1
    , @MaxZeilen=10
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@SingleConsumerJson OUTPUT
    , @PrintMeldungen=0;

IF ISJSON(@SingleConsumerJson)<>1
   OR JSON_VALUE(@SingleConsumerJson,N'$.modules[0].ModuleName')<>N'USP_QueryStats'
   OR JSON_VALUE(@SingleConsumerJson,N'$.modules[0].InvocationStatus')<>'EXECUTED'
    THROW 53301,N'Der Frischlesevertrag für einen einzelnen Plan-Cache-Consumer ist verletzt.',1;
GO
