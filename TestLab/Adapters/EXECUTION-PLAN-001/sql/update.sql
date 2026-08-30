USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-execution-plan-001';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);
DECLARE @Created bit = 0;

IF DB_ID(N'LabAnalyze') IS NULL
    THROW 55402, N'ADAPTER_STATE_CONFLICT: Die Frameworkdatenbank fehlt.', 1;

SELECT
      @ExistingProject = MAX
      (
          CASE WHEN [name] = N'SQLANALYZE.AdapterProject'
               THEN CONVERT(nvarchar(128), [value]) END
      )
    , @ExistingContract = MAX
      (
          CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion'
               THEN CONVERT(nvarchar(32), [value]) END
      )
FROM [LabAnalyze].[sys].[extended_properties]
WHERE [class] = 0
  AND [major_id] = 0
  AND [minor_id] = 0;

IF @ExistingProject <> @ProjectId OR @ExistingContract <> @ContractVersion
    THROW 55402, N'ADAPTER_STATE_CONFLICT: Die Frameworkmarker stimmen nicht überein.', 1;

IF DB_ID(N'AnalyzeAdapterPlan') IS NULL
BEGIN
    CREATE DATABASE [AnalyzeAdapterPlan]
    COLLATE SQL_Latin1_General_CP1_CS_AS;
    SET @Created = 1;
END;

IF @Created = 1
BEGIN
    EXEC [AnalyzeAdapterPlan].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterProject'
        , @value = @ProjectId;
    EXEC [AnalyzeAdapterPlan].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterContractVersion'
        , @value = @ContractVersion;
END
ELSE
BEGIN
    SELECT
          @ExistingProject = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterProject'
                   THEN CONVERT(nvarchar(128), [value]) END
          )
        , @ExistingContract = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion'
                   THEN CONVERT(nvarchar(32), [value]) END
          )
    FROM [AnalyzeAdapterPlan].[sys].[extended_properties]
    WHERE [class] = 0
      AND [major_id] = 0
      AND [minor_id] = 0;

    IF @ExistingProject <> @ProjectId OR @ExistingContract <> @ContractVersion
        THROW 55402, N'ADAPTER_STATE_CONFLICT: Die Szenariodatenbank besitzt nicht die erwarteten Marker.', 1;
END;

DECLARE @CompatibilityLevel int = CASE
    WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) = 15 THEN 150
    WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) = 16 THEN 160
    WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) = 17 THEN 170
END;
DECLARE @CompatibilitySql nvarchar(max) =
    N'ALTER DATABASE [AnalyzeAdapterPlan] SET COMPATIBILITY_LEVEL = ' +
    CONVERT(nvarchar(3), @CompatibilityLevel) + N';';
EXEC [sys].[sp_executesql] @CompatibilitySql;
GO
USE [AnalyzeAdapterPlan];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DROP TABLE IF EXISTS [dbo].[PlanWorkload];
CREATE TABLE [dbo].[PlanWorkload]
(
      [SyntheticId] int NOT NULL
        CONSTRAINT [PK_AnalyzeAdapterPlanWorkload] PRIMARY KEY
    , [GroupId] int NOT NULL
    , [Payload] char(128) NOT NULL
);

;WITH [Numbers] AS
(
    SELECT TOP (8192)
           ROW_NUMBER() OVER
           (
               ORDER BY [a].[object_id], [b].[object_id]
           ) AS [Number]
    FROM [sys].[all_objects] AS [a]
    CROSS JOIN [sys].[all_objects] AS [b]
)
INSERT [dbo].[PlanWorkload]
(
      [SyntheticId]
    , [GroupId]
    , [Payload]
)
SELECT
      CONVERT(int, [Number])
    , CASE WHEN [Number] <= 8000 THEN 1
           ELSE CONVERT(int, [Number] % 97) END
    , REPLICATE(CONVERT(char(1), [Number] % 10), 128)
FROM [Numbers];

CREATE INDEX [IX_AnalyzeAdapterPlanWorkload_GroupId]
ON [dbo].[PlanWorkload] ([GroupId]);
GO
CREATE OR ALTER PROCEDURE [dbo].[LabPlanProbe]
    @GroupId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [SyntheticId], [Payload]
    FROM [dbo].[PlanWorkload]
    WHERE [GroupId] = @GroupId
    OPTION (MAXDOP 2);
END;
GO
EXEC [dbo].[LabPlanProbe] @GroupId = 1;
EXEC [dbo].[LabPlanProbe] @GroupId = 97;

SELECT SUM([SyntheticId]) AS [SyntheticSum]
FROM [dbo].[PlanWorkload]
WHERE [GroupId] = 97
OPTION (MAXDOP 2);
/* SQLANALYZE_ADAPTER_EXECPLAN */
GO
