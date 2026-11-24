USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : RUNTIME-001 External Runtime und SQL CLR Runtime Contract
Stand        : 2026-07-22
Zweck        : Prüft Installation, JSON-, TABLE-, Status-, Discovery- und
               Lock-Timeout-Verträge der beiden rein lesenden Analyseverfahren.
Datenschutz  : Verwendet nur den aktuellen Testdatenbankkontext und synthetische
               lokale Temp-Tabellen; keine Runtime-, Assembly- oder Scriptdaten
               werden erzeugt oder persistiert.
Grenzen      : Der Test aktiviert keine Features und führt keinen externen oder
               CLR-Code aus. Windows-Nachweise mit aktivierten Features bleiben extern.
===============================================================================
*/
SET NOCOUNT ON;

-- Der Test darf seine absichtlich gesetzten Calleroptionen nicht an Folgetests vererben.
DECLARE @Runtime001EntryLockTimeout int=@@LOCK_TIMEOUT,
        @Runtime001EntryOptions int=@@OPTIONS,
        @Runtime001EntryTranCount int=@@TRANCOUNT;
EXEC [sys].[sp_executesql] N'IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[procedures] [p] WITH (NOLOCK)
    JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
    WHERE [s].[name]=N''monitor'' AND [p].[name]=N''USP_ExternalRuntimeAnalysis''
)
    THROW 51180,N''RUNTIME-001: USP_ExternalRuntimeAnalysis ist nicht installiert.'',1;
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[procedures] [p] WITH (NOLOCK)
    JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
    WHERE [s].[name]=N''monitor'' AND [p].[name]=N''USP_ClrAnalysis''
)
    THROW 51181,N''RUNTIME-001: USP_ClrAnalysis ist nicht installiert.'',1;

IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalyseClassCatalog]
    WHERE [AnalysisClass] IN(''EXTERNAL_RUNTIME_CURRENT'',''CLR_CURRENT''))<>2
    THROW 51182,N''RUNTIME-001: Analyseklassen fehlen.'',1;

IF NOT EXISTS(SELECT 1 FROM [monitor].[VW_AnalysisCatalog] WHERE [ProcedureName]=N''USP_ExternalRuntimeAnalysis'')
   OR NOT EXISTS(SELECT 1 FROM [monitor].[VW_AnalysisCatalog] WHERE [ProcedureName]=N''USP_ClrAnalysis'')
    THROW 51183,N''RUNTIME-001: Analysis-Catalog-Routing fehlt.'',1;

DECLARE @DatabaseNames nvarchar(max)=
(
    SELECT QUOTENAME([name])
    FROM [master].[sys].[databases] WITH (NOLOCK)
    WHERE [database_id]=DB_ID()
);
DECLARE @Json nvarchar(max),@Status varchar(40),@IsPartial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048);

SET LOCK_TIMEOUT 4321;
EXEC [monitor].[USP_ExternalRuntimeAnalysis]
      @DatabaseNames=@DatabaseNames
    , @SampleSeconds=0
    , @MitDateimetadaten=0
    , @MitBerechtigungsanalyse=0
    , @MitSitzungskontext=0
    , @MaxZeilen=20
    , @ResultSetArt=''NONE''
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@IsPartial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;

IF @@LOCK_TIMEOUT<>4321
    THROW 51184,N''RUNTIME-001: USP_ExternalRuntimeAnalysis stellt LOCK_TIMEOUT nicht wieder her.'',1;
IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N''$.meta.module'')<>N''USP_ExternalRuntimeAnalysis''
   OR JSON_QUERY(@Json,N''$.sourceStatus'') IS NULL OR JSON_QUERY(@Json,N''$.findings'') IS NULL
    THROW 51185,N''RUNTIME-001: External-Runtime-JSON-Vertrag verletzt.'',1;
IF @Status IS NULL OR @Status NOT IN(''AVAILABLE'',''AVAILABLE_WITH_FINDING'',''AVAILABLE_LIMITED'',''FEATURE_DISABLED'',''NOT_APPLICABLE'')
    THROW 51186,N''RUNTIME-001: Unerwarteter External-Runtime-Status.'',1;

SET @Json=NULL; SET @Status=NULL; SET @IsPartial=NULL; SET @ErrorNumber=NULL; SET @ErrorMessage=NULL;
EXEC [monitor].[USP_ClrAnalysis]
      @DatabaseNames=@DatabaseNames
    , @SampleSeconds=0
    , @MitModulzuordnung=1
    , @MitBerechtigungsanalyse=0
    , @MitSitzungskontext=0
    , @MaxZeilen=20
    , @ResultSetArt=''NONE''
    , @JsonErzeugen=1
    , @Json=@Json OUTPUT
    , @PrintMeldungen=0
    , @StatusCodeOut=@Status OUTPUT
    , @IsPartialOut=@IsPartial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT
    , @ErrorMessageOut=@ErrorMessage OUTPUT;

IF @@LOCK_TIMEOUT<>4321
    THROW 51187,N''RUNTIME-001: USP_ClrAnalysis stellt LOCK_TIMEOUT nicht wieder her.'',1;
IF ISJSON(@Json)<>1 OR JSON_VALUE(@Json,N''$.meta.module'')<>N''USP_ClrAnalysis''
   OR JSON_QUERY(@Json,N''$.sourceStatus'') IS NULL OR JSON_QUERY(@Json,N''$.findings'') IS NULL
    THROW 51188,N''RUNTIME-001: SQL-CLR-JSON-Vertrag verletzt.'',1;
IF @Status IS NULL OR @Status NOT IN(''AVAILABLE'',''AVAILABLE_WITH_FINDING'',''AVAILABLE_LIMITED'',''FEATURE_DISABLED'',''NOT_APPLICABLE'')
    THROW 51189,N''RUNTIME-001: Unerwarteter SQL-CLR-Status.'',1;
SET LOCK_TIMEOUT 0;

CREATE TABLE [#Runtime001ExternalRuntimeClrRuntimeContract_ExternalFindings]([Dummy] int NULL);
EXEC [monitor].[USP_ExternalRuntimeAnalysis]
      @DatabaseNames=@DatabaseNames
    , @SampleSeconds=0
    , @MaxZeilen=20
    , @ResultSetArt=''TABLE''
    , @ResultTablesJson=N''{"findings":"#Runtime001ExternalRuntimeClrRuntimeContract_ExternalFindings"}''
    , @PrintMeldungen=0;

IF NOT EXISTS
(
    SELECT 1
    FROM [tempdb].[sys].[columns] [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] [t] WITH (NOLOCK) ON [t].[object_id]=[c].[object_id]
    WHERE [t].[name] LIKE N''#Runtime001ExternalRuntimeClrRuntimeContract_ExternalFindings%'' AND [c].[name]=N''FindingCode''
)
    THROW 51190,N''RUNTIME-001: External-Runtime-TABLE-Schema fehlt.'',1;

CREATE TABLE [#Runtime001ExternalRuntimeClrRuntimeContract_ClrFindings]([Dummy] int NULL);
EXEC [monitor].[USP_ClrAnalysis]
      @DatabaseNames=@DatabaseNames
    , @SampleSeconds=0
    , @MaxZeilen=20
    , @ResultSetArt=''TABLE''
    , @ResultTablesJson=N''{"findings":"#Runtime001ExternalRuntimeClrRuntimeContract_ClrFindings"}''
    , @PrintMeldungen=0;

IF NOT EXISTS
(
    SELECT 1
    FROM [tempdb].[sys].[columns] [c] WITH (NOLOCK)
    JOIN [tempdb].[sys].[tables] [t] WITH (NOLOCK) ON [t].[object_id]=[c].[object_id]
    WHERE [t].[name] LIKE N''#Runtime001ExternalRuntimeClrRuntimeContract_ClrFindings%'' AND [c].[name]=N''FindingCode''
)
    THROW 51191,N''RUNTIME-001: SQL-CLR-TABLE-Schema fehlt.'',1;

CREATE TABLE [#Runtime001ExternalRuntimeClrRuntimeContract_Features]([Dummy] int NULL);
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames=@DatabaseNames
    , @MaxZeilen=100
    , @ResultSetArt=''TABLE''
    , @ResultTablesJson=N''{"features":"#Runtime001ExternalRuntimeClrRuntimeContract_Features"}''
    , @PrintMeldungen=0;

DECLARE @FeatureRoutingOk bit=0;
EXEC [sys].[sp_executesql]
      N''SELECT @pOk=CONVERT(bit,CASE WHEN
            EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Features] WHERE [FeatureCode]=''''CLR'''' AND [RecommendedModule]=N''''USP_ClrAnalysis'''' AND [RecommendedModuleStatus]=''''IMPLEMENTED'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Features] WHERE [FeatureCode]=''''EXTERNAL_RUNTIME'''' AND [RecommendedModule]=N''''USP_ExternalRuntimeAnalysis'''' AND [RecommendedModuleStatus]=''''IMPLEMENTED'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Features] WHERE [FeatureCode]=''''EXTERNAL_SCRIPTS'''' AND [RecommendedModule]=N''''USP_ExternalRuntimeAnalysis'''' AND [RecommendedModuleStatus]=''''IMPLEMENTED'''')
        THEN 1 ELSE 0 END);''
    , N''@pOk bit OUTPUT''
    , @pOk=@FeatureRoutingOk OUTPUT;
IF @FeatureRoutingOk<>1
    THROW 51192,N''RUNTIME-001: Special-Feature-Routing verletzt.'',1;

CREATE TABLE [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities]([Dummy] int NULL);
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames=@DatabaseNames
    , @MitSpezialindizes=0
    , @MitQueryStoreReplicas=0
    , @MitPlattformdetails=0
    , @MaxZeilen=100
    , @ResultSetArt=''TABLE''
    , @ResultTablesJson=N''{"capabilities":"#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities"}''
    , @PrintMeldungen=0;

DECLARE @CapabilityRoutingOk bit=0;
EXEC [sys].[sp_executesql]
      N''SELECT @pOk=CONVERT(bit,CASE WHEN
            EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''EXTERNAL_SCRIPT_REQUESTS'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''EXTERNAL_RESOURCE_POOLS'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''EXTERNAL_LANGUAGE_CATALOG'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''LAUNCHPAD_SERVICE_STATE'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''CLR_HOST_RUNTIME'''')
        AND EXISTS(SELECT 1 FROM [#Runtime001ExternalRuntimeClrRuntimeContract_Capabilities] WHERE [FeatureName]=''''CLR_TRUSTED_ASSEMBLIES'''')
        THEN 1 ELSE 0 END);''
    , N''@pOk bit OUTPUT''
    , @pOk=@CapabilityRoutingOk OUTPUT;
IF @CapabilityRoutingOk<>1
    THROW 51193,N''RUNTIME-001: Capability-Routing verletzt.'',1;

DECLARE @ExternalDefinition nvarchar(max),@ClrDefinition nvarchar(max);
SELECT @ExternalDefinition=[m].[definition]
FROM [sys].[sql_modules] [m] WITH (NOLOCK)
JOIN [sys].[procedures] [p] WITH (NOLOCK) ON [p].[object_id]=[m].[object_id]
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
WHERE [s].[name]=N''monitor'' AND [p].[name]=N''USP_ExternalRuntimeAnalysis'';
SELECT @ClrDefinition=[m].[definition]
FROM [sys].[sql_modules] [m] WITH (NOLOCK)
JOIN [sys].[procedures] [p] WITH (NOLOCK) ON [p].[object_id]=[m].[object_id]
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]
WHERE [s].[name]=N''monitor'' AND [p].[name]=N''USP_ClrAnalysis'';
IF @ExternalDefinition IS NULL
   OR @ClrDefinition IS NULL
   OR @ExternalDefinition LIKE N''%sp_execute_external_script%''
   OR @ExternalDefinition LIKE N''%CREATE EXTERNAL LANGUAGE%''
   OR @ExternalDefinition LIKE N''%CREATE EXTERNAL LIBRARY%''
   OR @ClrDefinition LIKE N''%CREATE ASSEMBLY%''
   OR @ClrDefinition LIKE N''%ALTER ASSEMBLY%''
    THROW 51194,N''RUNTIME-001: Ein Analysemodul enthält einen verbotenen Ausführungs- oder Mutationspfad.'',1;

SELECT CAST(''AVAILABLE'' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(2 AS int) AS [ValidatedModules],
       N''RUNTIME-001: Read-only-, JSON-, TABLE-, Routing-, Capability- und Lock-Timeout-Verträge erfüllt; keine Featureaktivierung oder Testausführung.'' AS [Detail];';
IF @@LOCK_TIMEOUT<>@Runtime001EntryLockTimeout OR @@OPTIONS<>@Runtime001EntryOptions
   OR @@TRANCOUNT<>@Runtime001EntryTranCount
    THROW 51195,N'RUNTIME-001: Der Test hat Callerzustand verändert.',1;
GO

-- Führt ausschließlich den installierten Projektionsblock mit eigenen Messwerten aus.
DECLARE @PoolProjectionDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_ExternalRuntimeAnalysis'));
DECLARE @PoolTablesStart int=CHARINDEX(N'CREATE TABLE [#ExternalRuntimeAnalysis_PoolSamples]',@PoolProjectionDefinition);
DECLARE @PoolTablesEnd int=CHARINDEX(N'CREATE TABLE [#ExternalRuntimeAnalysis_ExecutionStatSamples]',@PoolProjectionDefinition);
DECLARE @PoolProjectionStart int=CHARINDEX(N'INSERT [#ExternalRuntimeAnalysis_ExternalPools]',@PoolProjectionDefinition);
DECLARE @PoolProjectionEnd int=CHARINDEX(N'INSERT [#ExternalRuntimeAnalysis_ExecutionStats]',@PoolProjectionDefinition);
IF @PoolProjectionDefinition IS NULL OR @PoolTablesStart<=0 OR @PoolTablesEnd<=@PoolTablesStart
   OR @PoolProjectionStart<=@PoolTablesEnd OR @PoolProjectionEnd<=@PoolProjectionStart
    THROW 51196,N'Installed external pool projection anchors are unavailable.',1;
IF OBJECT_ID(N'tempdb..#ExternalRuntimeAnalysis_PoolSamples') IS NOT NULL
   OR OBJECT_ID(N'tempdb..#ExternalRuntimeAnalysis_ExternalPools') IS NOT NULL
    THROW 51197,N'External pool projection test temp table name already exists.',1;

DECLARE @PoolProjectionSql nvarchar(max)=
    SUBSTRING(@PoolProjectionDefinition,@PoolTablesStart,@PoolTablesEnd-@PoolTablesStart)+N'
INSERT [#ExternalRuntimeAnalysis_PoolSamples]
    ([SamplePoint],[ReadAtUtc],[ExternalPoolId],[PoolName],[PoolVersion],[StatisticsStartTime],
     [TotalCpuKernelMs],[TotalCpuUserMs],[ReadIoCount],[WriteIoCount])
SELECT ''T1'',N''20260101'', [PoolId],N''ExamplePool'',1,N''20260101'',10,20,30,40
FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8)) AS [ids]([PoolId]);
INSERT [#ExternalRuntimeAnalysis_PoolSamples]
    ([SamplePoint],[ReadAtUtc],[ExternalPoolId],[PoolName],[PoolVersion],[StatisticsStartTime],
     [TotalCpuKernelMs],[TotalCpuUserMs],[ReadIoCount],[WriteIoCount])
SELECT ''T2'',DATEADD(second,1,CONVERT(datetime2(3),N''20260101'')),[PoolId],N''ExamplePool'',
       CASE WHEN [PoolId]=7 THEN 2 ELSE 1 END,
       CASE WHEN [PoolId]=8 THEN CONVERT(datetime,N''20260102'') ELSE CONVERT(datetime,N''20260101'') END,
       CASE WHEN [PoolId]=2 THEN 9 ELSE 13 END,
       CASE WHEN [PoolId]=3 THEN 19 ELSE 24 END,
       CASE WHEN [PoolId]=4 THEN 29 ELSE 35 END,
       CASE WHEN [PoolId]=5 THEN 39 ELSE 46 END
FROM (VALUES (1),(2),(3),(4),(5),(7),(8)) AS [ids]([PoolId]);'+
    SUBSTRING(@PoolProjectionDefinition,@PoolProjectionStart,@PoolProjectionEnd-@PoolProjectionStart)+N'
IF (SELECT COUNT(*) FROM [#ExternalRuntimeAnalysis_ExternalPools])<>8
   OR (SELECT COUNT(DISTINCT [ExternalPoolId]) FROM [#ExternalRuntimeAnalysis_ExternalPools])<>8
   OR NOT EXISTS
      (SELECT 1 FROM [#ExternalRuntimeAnalysis_ExternalPools]
       WHERE [ExternalPoolId]=1 AND [DeltaStatus]=''DELTA_AVAILABLE'' AND [SampleSeconds]=1
             AND [CpuKernelDelta]=3 AND [CpuUserDelta]=4 AND [ReadIoDelta]=5 AND [WriteIoDelta]=6)
   OR NOT EXISTS
      (SELECT 1 FROM [#ExternalRuntimeAnalysis_ExternalPools]
       WHERE [ExternalPoolId]=6 AND [DeltaStatus]=''T2_UNAVAILABLE'' AND [SampleSeconds] IS NULL
             AND [CpuKernelDelta] IS NULL AND [CpuUserDelta] IS NULL AND [ReadIoDelta] IS NULL AND [WriteIoDelta] IS NULL)
   OR EXISTS
      (SELECT 1 FROM [#ExternalRuntimeAnalysis_ExternalPools]
       WHERE [ExternalPoolId] IN(2,3,4,5,7,8)
         AND ([DeltaStatus]<>''RESET_BOUNDARY'' OR [SampleSeconds]<>1 OR [SampleSeconds] IS NULL
              OR [CpuKernelDelta] IS NOT NULL OR [CpuUserDelta] IS NOT NULL
              OR [ReadIoDelta] IS NOT NULL OR [WriteIoDelta] IS NOT NULL))
    THROW 51198,N''External pool reset boundary leaked a delta or changed the positive control.'',1;
PRINT N''External pool projection: 8 synthetic sample-pair cases passed.'';
';
EXEC [sys].[sp_executesql] @PoolProjectionSql,N'@SampleSeconds tinyint,@HostPlatform nvarchar(60)',
     @SampleSeconds=1,@HostPlatform=N'Linux';
GO
