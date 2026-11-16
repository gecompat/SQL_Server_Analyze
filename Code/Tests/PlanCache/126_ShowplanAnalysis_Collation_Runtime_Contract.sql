USE [DeineDatenbank];
GO

SET NOCOUNT ON;
GO

DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_ShowplanAnalysis]
    @DatabaseNames = N'[DeineDatenbank]',
    @MinExecutionCount = 9223372036854775807,
    @MaxAnalyseobjekte = 1,
    @MaxZeilen = 1,
    @MitSqlText = 0,
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @Json OUTPUT,
    @PrintMeldungen = 0;

IF ISJSON(@Json) <> 1
    THROW 55000, N'USP_ShowplanAnalysis did not return valid JSON.', 1;

IF JSON_VALUE(@Json, N'$.meta.statusCode') NOT IN (N'AVAILABLE', N'PARTIAL', N'AVAILABLE_LIMITED')
    THROW 55000, N'USP_ShowplanAnalysis returned an unexpected status for the collation contract.', 1;

IF JSON_QUERY(@Json, N'$.planStatus') IS NULL OR JSON_QUERY(@Json, N'$.findings') IS NULL
    THROW 55000, N'USP_ShowplanAnalysis JSON does not contain required arrays.', 1;

PRINT N'Showplan Analysis collation runtime contract passed.';
GO

/*
Direct wrapper regression: NULL and numeric values outside the documented
duration range are rejected before any child analysis. Safe selectors and
bounded output prevent plan XML payloads from being returned.
*/
DECLARE @DurationCases TABLE
(
      CaseName nvarchar(32) NOT NULL
    , DurationSeconds int NULL
);
INSERT INTO @DurationCases ([CaseName],[DurationSeconds])
VALUES
      (N'NULL',NULL)
    , (N'zero',0)
    , (N'negative',-1)
    , (N'above maximum',3601)
    , (N'int minimum',-2147483648)
    , (N'int maximum',2147483647);

DECLARE @CaseName nvarchar(32);
DECLARE @DurationSeconds int;
DECLARE @DurationJson nvarchar(max);
DECLARE DurationRegressionCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT [CaseName],[DurationSeconds]
    FROM @DurationCases
    ORDER BY CASE WHEN [DurationSeconds] IS NULL THEN 0 ELSE 1 END,[DurationSeconds];

OPEN DurationRegressionCursor;
FETCH NEXT FROM DurationRegressionCursor INTO @CaseName,@DurationSeconds;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DurationJson=N'output sentinel';
    EXEC [monitor].[USP_ShowplanAnalysis]
          @DatabaseNames=N'[DeineDatenbank]'
        , @MinExecutionCount=9223372036854775807
        , @MaxAnalyseobjekte=1
        , @MaxDurationSeconds=@DurationSeconds
        , @MaxZeilen=1
        , @MitSqlText=0
        , @ResultSetArt='NONE'
        , @JsonErzeugen=1
        , @Json=@DurationJson OUTPUT
        , @PrintMeldungen=0;

    IF ISNULL(ISJSON(@DurationJson),0)<>1
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER'
       OR JSON_QUERY(@DurationJson,N'$.planStatus') IS NULL
       OR EXISTS(SELECT 1 FROM OPENJSON(@DurationJson,N'$.planStatus'))
       OR JSON_QUERY(@DurationJson,N'$.findings') IS NULL
       OR EXISTS(SELECT 1 FROM OPENJSON(@DurationJson,N'$.findings'))
        THROW 55000, N'USP_ShowplanAnalysis did not reject the invalid duration without child plan data.', 1;

    SET @DurationJson=N'output sentinel';
    EXEC [monitor].[USP_PlanCacheAnalysis]
          @MitQueryStats=1
        , @MitQueryHashAnalysis=0
        , @MitPlanCacheHealth=0
        , @MitShowplanAnalysis=0
        , @QueryHash=0x0102030405060708
        , @MaxDurationSeconds=@DurationSeconds
        , @MaxZeilen=1
        , @ResultSetArt='NONE'
        , @JsonErzeugen=1
        , @Json=@DurationJson OUTPUT
        , @PrintMeldungen=0;

    IF ISNULL(ISJSON(@DurationJson),0)<>1
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'')<>N'INVALID_PARAMETER'
       OR JSON_QUERY(@DurationJson,N'$.modules') IS NULL
       OR EXISTS(SELECT 1 FROM OPENJSON(@DurationJson,N'$.modules'))
       OR JSON_QUERY(@DurationJson,N'$.showplan') IS NOT NULL
        THROW 55000, N'USP_PlanCacheAnalysis did not reject the invalid duration before child invocation.', 1;

    FETCH NEXT FROM DurationRegressionCursor INTO @CaseName,@DurationSeconds;
END;
CLOSE DurationRegressionCursor;
DEALLOCATE DurationRegressionCursor;

DECLARE @ValidDurations TABLE (DurationSeconds int NOT NULL);
INSERT INTO @ValidDurations ([DurationSeconds]) VALUES (1),(30),(3600);
DECLARE ValidDurationCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT [DurationSeconds] FROM @ValidDurations ORDER BY [DurationSeconds];

OPEN ValidDurationCursor;
FETCH NEXT FROM ValidDurationCursor INTO @DurationSeconds;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DurationJson=N'output sentinel';
    EXEC [monitor].[USP_ShowplanAnalysis]
          @DatabaseNames=N'[DeineDatenbank]'
        , @MinExecutionCount=9223372036854775807
        , @MaxAnalyseobjekte=1
        , @MaxDurationSeconds=@DurationSeconds
        , @MaxZeilen=1
        , @MitSqlText=0
        , @ResultSetArt='NONE'
        , @JsonErzeugen=1
        , @Json=@DurationJson OUTPUT
        , @PrintMeldungen=0;

    IF ISNULL(ISJSON(@DurationJson),0)<>1
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'PARTIAL',N'AVAILABLE_LIMITED')
        THROW 55000, N'USP_ShowplanAnalysis rejected a valid duration.', 1;

    SET @DurationJson=N'output sentinel';
    EXEC [monitor].[USP_PlanCacheAnalysis]
          @MitQueryStats=1
        , @MitQueryHashAnalysis=0
        , @MitPlanCacheHealth=0
        , @MitShowplanAnalysis=0
        , @QueryHash=0x0102030405060708
        , @MaxDurationSeconds=@DurationSeconds
        , @MaxZeilen=1
        , @ResultSetArt='NONE'
        , @JsonErzeugen=1
        , @Json=@DurationJson OUTPUT
        , @PrintMeldungen=0;

    IF ISNULL(ISJSON(@DurationJson),0)<>1
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_LIMITED')
       OR JSON_QUERY(@DurationJson,N'$.modules') IS NULL
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@DurationJson,N'$.modules'))<>1
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.modules[0].ModuleName'),N'')<>N'USP_QueryStats'
       OR ISNULL(JSON_VALUE(@DurationJson,N'$.modules[0].InvocationStatus'),N'')<>N'EXECUTED'
        THROW 55000, N'USP_PlanCacheAnalysis rejected a valid duration or did not invoke its enabled child.', 1;

    FETCH NEXT FROM ValidDurationCursor INTO @DurationSeconds;
END;
CLOSE ValidDurationCursor;
DEALLOCATE ValidDurationCursor;

SET @DurationJson=N'output sentinel';
EXEC [monitor].[USP_ShowplanAnalysis]
      @DatabaseNames=N'[DeineDatenbank]'
    , @MinExecutionCount=9223372036854775807
    , @MaxAnalyseobjekte=1
    , @MaxZeilen=1
    , @MitSqlText=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@DurationJson OUTPUT
    , @PrintMeldungen=0;
IF ISNULL(ISJSON(@DurationJson),0)<>1
   OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'PARTIAL',N'AVAILABLE_LIMITED')
    THROW 55000, N'USP_ShowplanAnalysis rejected the omitted default duration.', 1;

SET @DurationJson=N'output sentinel';
EXEC [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats=1
    , @MitQueryHashAnalysis=0
    , @MitPlanCacheHealth=0
    , @MitShowplanAnalysis=0
    , @QueryHash=0x0102030405060708
    , @MaxZeilen=1
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@DurationJson OUTPUT
    , @PrintMeldungen=0;
IF ISNULL(ISJSON(@DurationJson),0)<>1
   OR ISNULL(JSON_VALUE(@DurationJson,N'$.meta.statusCode'),N'') NOT IN (N'AVAILABLE',N'AVAILABLE_LIMITED')
   OR JSON_QUERY(@DurationJson,N'$.modules') IS NULL
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@DurationJson,N'$.modules'))<>1
   OR ISNULL(JSON_VALUE(@DurationJson,N'$.modules[0].ModuleName'),N'')<>N'USP_QueryStats'
   OR ISNULL(JSON_VALUE(@DurationJson,N'$.modules[0].InvocationStatus'),N'')<>N'EXECUTED'
    THROW 55000, N'USP_PlanCacheAnalysis rejected the omitted default duration or did not invoke its enabled child.', 1;

PRINT N'Showplan duration validation contract passed.';
GO
