USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Major int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));

IF @Major NOT IN (15, 16, 17)
    THROW 55400, N'ADAPTER_UNSUPPORTED_SQL_VERSION: SQL Server 2019, 2022 oder 2025 ist erforderlich.', 1;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 55400, N'ADAPTER_PERMISSION_MISSING: Der isolierte Quick-Slice benötigt sysadmin.', 1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[databases]
    WHERE [database_id] > 4
      AND [name] NOT IN (N'LabAnalyze', N'AnalyzeAdapterPlan')
)
    THROW 55401, N'ADAPTER_ISOLATION_REQUIRED: Die Instanz enthält eine fremde Benutzerdatenbank.', 1;

SELECT
      N'EXECUTION-PLAN-001' AS [ScenarioId]
    , N'PREFLIGHT' AS [Phase]
    , N'PASS' AS [Outcome]
    , @Major AS [ProductMajorVersion];
GO
