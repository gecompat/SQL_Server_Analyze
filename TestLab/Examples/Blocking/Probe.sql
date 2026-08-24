SET NOCOUNT ON;

DECLARE @ScenarioId varchar(40) = '$(ScenarioId)';
DECLARE @LabRunId varchar(40) = '$(LabRunId)';
DECLARE @ContextToken binary(128) =
    CONVERT(binary(128), HASHBYTES('SHA2_256', CONCAT(@LabRunId, '|', @ScenarioId)));
DECLARE @SessionCount int;
DECLARE @BlockedRequestCount int;
DECLARE @Message nvarchar(2048);

SELECT @SessionCount = COUNT(*)
FROM [sys].[dm_exec_sessions]
WHERE [context_info] = @ContextToken;

SELECT @BlockedRequestCount = COUNT(*)
FROM [sys].[dm_exec_requests] AS [r]
INNER JOIN [sys].[dm_exec_sessions] AS [s]
    ON [s].[session_id] = [r].[session_id]
WHERE [s].[context_info] = @ContextToken
  AND [r].[blocking_session_id] > 0;

IF @SessionCount < 2 OR @BlockedRequestCount < 1
BEGIN
    SET @Message = CONCAT
    (
          N'Blocking precondition failed. Sessions='
        , @SessionCount
        , N'; BlockedRequests='
        , @BlockedRequestCount
        , N'.'
    );
    THROW 55401, @Message, 1;
END;
