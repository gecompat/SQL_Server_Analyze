USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-execution-plan-001';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @Database sysname;
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);
DECLARE @Sql nvarchar(max);

DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
SELECT [DatabaseName]
FROM
(
    VALUES (N'LabAnalyze'), (N'AnalyzeAdapterPlan')
) AS [Databases] ([DatabaseName]);

OPEN [DatabaseCursor];
FETCH NEXT FROM [DatabaseCursor] INTO @Database;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@Database) IS NULL
        THROW 55403, N'PROJECT_ASSERTION_FAILED: Eine Adapterdatenbank fehlt.', 1;

    SET @ExistingProject = NULL;
    SET @ExistingContract = NULL;
    SET @Sql = N'SELECT '
        + N'@Project = MAX(CASE WHEN [name] = N''SQLANALYZE.AdapterProject'' '
        + N'THEN CONVERT(nvarchar(128), [value]) END), '
        + N'@Contract = MAX(CASE WHEN [name] = N''SQLANALYZE.AdapterContractVersion'' '
        + N'THEN CONVERT(nvarchar(32), [value]) END) '
        + N'FROM ' + QUOTENAME(@Database) + N'.[sys].[extended_properties] '
        + N'WHERE [class] = 0 AND [major_id] = 0 AND [minor_id] = 0;';
    EXEC [sys].[sp_executesql]
          @Sql
        , N'@Project nvarchar(128) OUTPUT, @Contract nvarchar(32) OUTPUT'
        , @Project = @ExistingProject OUTPUT
        , @Contract = @ExistingContract OUTPUT;

    IF @ExistingProject <> @ProjectId OR @ExistingContract <> @ContractVersion
        THROW 55403, N'PROJECT_ASSERTION_FAILED: Adaptermarker stimmen nicht überein.', 1;

    FETCH NEXT FROM [DatabaseCursor] INTO @Database;
END;
CLOSE [DatabaseCursor];
DEALLOCATE [DatabaseCursor];

IF OBJECT_ID(N'LabAnalyze.monitor.USP_ExecutionPlanAnalysis', N'P') IS NULL
   OR OBJECT_ID(N'LabAnalyze.monitor.USP_CreateExecutionEvidenceJson', N'P') IS NULL
    THROW 55403, N'PROJECT_ASSERTION_FAILED: Der eigenständige Frameworkumfang ist unvollständig.', 1;

IF OBJECT_ID(N'AnalyzeAdapterPlan.dbo.PlanWorkload', N'U') IS NULL
   OR OBJECT_ID(N'AnalyzeAdapterPlan.dbo.LabPlanProbe', N'P') IS NULL
    THROW 55403, N'PROJECT_ASSERTION_FAILED: Der synthetische Szenariovertrag ist unvollständig.', 1;

DECLARE @PlanXml xml;
SELECT TOP (1)
       @PlanXml = [QueryPlan].[query_plan]
FROM [sys].[dm_exec_query_stats] AS [QueryStats]
CROSS APPLY [sys].[dm_exec_sql_text]([QueryStats].[sql_handle]) AS [SqlText]
CROSS APPLY [sys].[dm_exec_query_plan]([QueryStats].[plan_handle]) AS [QueryPlan]
WHERE [SqlText].[dbid] = DB_ID(N'AnalyzeAdapterPlan')
   OR [SqlText].[text] LIKE N'%SQLANALYZE_ADAPTER_EXECPLAN%'
ORDER BY [QueryStats].[last_execution_time] DESC;

IF @PlanXml IS NULL
    THROW 55403, N'PROJECT_ASSERTION_FAILED: Der synthetische Ausführungsplan fehlt.', 1;

DECLARE @AnalyzerJson nvarchar(max);
DECLARE @AnalyzerStatus varchar(40);
DECLARE @AnalyzerPartial bit;
DECLARE @AnalyzerErrorMessage nvarchar(2048);
DECLARE @ReturnCode int;

EXEC @ReturnCode = [LabAnalyze].[monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @PlanXml
    , @AnalyseTiefe = 'STANDARD'
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus = 'OMIT'
    , @MaxOperatoren = 1000
    , @MaxFindings = 100
    , @MaxDurationSeconds = 30
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @AnalyzerJson OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @AnalyzerStatus OUTPUT
    , @IsPartialOut = @AnalyzerPartial OUTPUT
    , @ErrorMessageOut = @AnalyzerErrorMessage OUTPUT;

IF @ReturnCode <> 0
   OR @AnalyzerStatus NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED', 'PARTIAL')
   OR ISJSON(@AnalyzerJson) <> 1
    THROW 55403, N'PROJECT_ASSERTION_FAILED: Der Execution-Plan-Analyzer-Vertrag ist nicht erfüllt.', 1;

SELECT
      N'EXECUTION-PLAN-001' AS [ScenarioId]
    , N'VALIDATE' AS [Phase]
    , N'PASS' AS [Outcome]
    , @AnalyzerStatus AS [AnalyzerStatus]
    , @AnalyzerPartial AS [IsPartial];
GO
