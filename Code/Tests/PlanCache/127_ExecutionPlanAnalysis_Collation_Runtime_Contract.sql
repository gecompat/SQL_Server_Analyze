USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);
DECLARE @SessionIds nvarchar(12) = CONVERT(nvarchar(12), @@SPID);

EXEC [monitor].[USP_ExecutionPlanAnalysis]
    @SessionIds = @SessionIds,
    @PlanQuelle = 'COMPILE',
    @MitSqlText = 0,
    @MaxOperatoren = 10,
    @MaxFindings = 10,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_ExecutionPlanAnalysis did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL', N'AVAILABLE_LIMITED')
    THROW 55000, N'USP_ExecutionPlanAnalysis returned an unexpected status for the collation contract.', 1;

IF JSON_QUERY(@Json, N'$.statements') IS NULL OR JSON_QUERY(@Json, N'$.findings') IS NULL
    THROW 55000, N'USP_ExecutionPlanAnalysis JSON does not contain required arrays.', 1;

PRINT N'Execution Plan Analysis collation runtime contract passed.';
GO
