USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);
DECLARE @SessionIds nvarchar(12) = CONVERT(nvarchar(12), @@SPID);

EXEC [monitor].[USP_PlanDetails]
    @SessionIds = @SessionIds,
    @MitPlanAttributes = 0,
    @MitCompilePlan = 0,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_PlanDetails did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL')
    THROW 55000, N'USP_PlanDetails returned an unexpected status for the collation contract.', 1;

IF JSON_QUERY(@Json, N'$.candidates') IS NULL OR JSON_QUERY(@Json, N'$.attributes') IS NULL OR JSON_QUERY(@Json, N'$.plans') IS NULL
    THROW 55000, N'USP_PlanDetails JSON does not contain required arrays.', 1;

PRINT N'Plan Details collation runtime contract passed.';
GO
