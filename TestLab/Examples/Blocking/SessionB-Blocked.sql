SET NOCOUNT ON;
SET XACT_ABORT OFF;
SET LOCK_TIMEOUT 45000;

DECLARE @ScenarioId varchar(40) = '$(ScenarioId)';
DECLARE @LabRunId varchar(40) = '$(LabRunId)';
DECLARE @ContextToken binary(128) =
    CONVERT(binary(128), HASHBYTES('SHA2_256', CONCAT(@LabRunId, '|', @ScenarioId)));

SET CONTEXT_INFO @ContextToken;

UPDATE [Lab001Wave3].[dbo].[Workload]
SET [Amount] += 1
WHERE [SyntheticId] = 1;
