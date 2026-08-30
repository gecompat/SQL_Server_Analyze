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
    VALUES (N'AnalyzeAdapterPlan'), (N'LabAnalyze')
) AS [Databases] ([DatabaseName]);

OPEN [DatabaseCursor];
FETCH NEXT FROM [DatabaseCursor] INTO @Database;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF DB_ID(@Database) IS NOT NULL
    BEGIN
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
            THROW 55404, N'PROJECT_CLEANUP_FAILED: Eine Datenbank besitzt nicht die erwarteten Adaptermarker.', 1;

        SET @Sql = N'ALTER DATABASE ' + QUOTENAME(@Database)
            + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE '
            + QUOTENAME(@Database) + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END;

    FETCH NEXT FROM [DatabaseCursor] INTO @Database;
END;
CLOSE [DatabaseCursor];
DEALLOCATE [DatabaseCursor];

SELECT
      N'EXECUTION-PLAN-001' AS [ScenarioId]
    , N'CLEANUP' AS [Phase]
    , N'PASS' AS [Outcome]
    , N'ADAPTER_DATABASES_REMOVED' AS [Code];
GO
