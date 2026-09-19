USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-ops-005-linked-server';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);

IF EXISTS
(
    SELECT 1
    FROM [sys].[servers]
    WHERE [name] = N'ExampleOps005Linked'
      AND [product] = N'ExampleSyntheticProduct'
)
    EXEC [master].[dbo].[sp_dropserver] @server = N'ExampleOps005Linked', @droplogins = 'droplogins';

IF EXISTS
(
    SELECT 1
    FROM [sys].[servers]
    WHERE [name] = N'ExampleOps005TimeoutLinked'
      AND [product] = N'ExampleSyntheticTimeoutProduct'
)
    EXEC [master].[dbo].[sp_dropserver] @server = N'ExampleOps005TimeoutLinked', @droplogins = 'droplogins';

DROP USER IF EXISTS [ExampleOps005RestrictedUser];
EXEC [master].[sys].[sp_executesql] N'DROP USER IF EXISTS [ExampleOps005RestrictedUser];';
IF EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [name] = N'ExampleOps005RestrictedLogin')
    DROP LOGIN [ExampleOps005RestrictedLogin];

IF DB_ID(N'LabAnalyzeOps005') IS NOT NULL
BEGIN
    SELECT
          @ExistingProject = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterProject' THEN CONVERT(nvarchar(128), [value]) END)
        , @ExistingContract = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion' THEN CONVERT(nvarchar(32), [value]) END)
    FROM [LabAnalyzeOps005].[sys].[extended_properties]
    WHERE [class] = 0 AND [major_id] = 0 AND [minor_id] = 0;

    IF @ExistingProject <> @ProjectId OR @ExistingContract <> @ContractVersion
        THROW 55504, N'PROJECT_CLEANUP_FAILED: Die Frameworkdatenbank besitzt nicht die erwarteten Adaptermarker.', 1;

    ALTER DATABASE [LabAnalyzeOps005] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [LabAnalyzeOps005];
END;

SELECT
      N'OPS-005' AS [ScenarioId]
    , N'CLEANUP' AS [Phase]
    , N'PASS' AS [Outcome];
GO
