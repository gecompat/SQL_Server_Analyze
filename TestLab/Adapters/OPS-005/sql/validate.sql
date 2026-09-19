USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-ops-005-linked-server';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);
DECLARE @RuntimeContract nvarchar(32);

IF DB_ID(N'LabAnalyzeOps005') IS NULL
    THROW 55503, N'PROJECT_ASSERTION_FAILED: Die OPS-005-Frameworkdatenbank fehlt.', 1;

SELECT
      @ExistingProject = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterProject' THEN CONVERT(nvarchar(128), [value]) END)
    , @ExistingContract = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion' THEN CONVERT(nvarchar(32), [value]) END)
    , @RuntimeContract = MAX(CASE WHEN [name] = N'SQLANALYZE.Ops005RuntimeContract' THEN CONVERT(nvarchar(32), [value]) END)
FROM [LabAnalyzeOps005].[sys].[extended_properties]
WHERE [class] = 0 AND [major_id] = 0 AND [minor_id] = 0;

IF @ExistingProject <> @ProjectId
   OR @ExistingContract <> @ContractVersion
   OR @RuntimeContract <> N'PASS'
    THROW 55503, N'PROJECT_ASSERTION_FAILED: Der OPS-005-Adaptermarker oder der Runtimevertragsnachweis fehlt.', 1;

IF OBJECT_ID(N'LabAnalyzeOps005.monitor.USP_LinkedServerAnalysis', N'P') IS NULL
    THROW 55503, N'PROJECT_ASSERTION_FAILED: Der Linked-Server-Analyzer wurde nicht installiert.', 1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[servers]
    WHERE [name] IN (N'ExampleOps005Linked', N'ExampleOps005TimeoutLinked')
)
    THROW 55503, N'PROJECT_ASSERTION_FAILED: Der Runtimevertrag hinterließ einen Linked-Server-Fixture.', 1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[server_principals]
    WHERE [name] = N'ExampleOps005RestrictedLogin'
)
    THROW 55503, N'PROJECT_ASSERTION_FAILED: Der Runtimevertrag hinterließ einen Login-Fixture.', 1;

SELECT
      N'OPS-005' AS [ScenarioId]
    , N'VALIDATE' AS [Phase]
    , N'PASS' AS [Outcome];
GO
