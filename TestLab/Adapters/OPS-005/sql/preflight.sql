USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Major int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));

IF @Major NOT IN (15, 16, 17)
    THROW 55500, N'ADAPTER_UNSUPPORTED_SQL_VERSION: SQL Server 2019, 2022 oder 2025 ist erforderlich.', 1;

IF IS_SRVROLEMEMBER(N'sysadmin') <> 1
    THROW 55500, N'ADAPTER_PERMISSION_MISSING: Der OPS-005-Vertrag benötigt in der isolierten Instanz sysadmin.', 1;

IF EXISTS
(
    SELECT 1
    FROM [sys].[databases]
    WHERE [database_id] > 4
      AND [name] <> N'DeineDatenbank'
)
    THROW 55501, N'ADAPTER_ISOLATION_REQUIRED: Die Instanz enthält eine fremde Benutzerdatenbank.', 1;

SELECT
      N'OPS-005' AS [ScenarioId]
    , N'PREFLIGHT' AS [Phase]
    , N'PASS' AS [Outcome]
    , @Major AS [ProductMajorVersion];
GO
