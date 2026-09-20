USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);
DECLARE @PlanXml xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.0" Build="15.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT 1" StatementId="1" StatementCompId="1" StatementType="SELECT"><QueryPlan /></StmtSimple></Statements></Batch></BatchSequence></ShowPlanXML>';

EXEC [monitor].[USP_CreateExecutionEvidenceJson]
    @PlanXml = @PlanXml,
    @StatistikEvidenzModus = 'USED',
    @MetadatenQuellenmodus = 'CURRENT_SERVER',
    @QuellumgebungBestaetigt = 1,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_CreateExecutionEvidenceJson did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL')
    THROW 55000, N'USP_CreateExecutionEvidenceJson returned an unexpected metadata status.', 1;

IF JSON_QUERY(@Json, N'$.statistics.currentSnapshot') IS NULL OR JSON_QUERY(@Json, N'$.collectionStatus') IS NULL
    THROW 55000, N'Execution evidence JSON does not contain required metadata arrays.', 1;

PRINT N'Execution-plan metadata collation runtime contract passed.';
GO
