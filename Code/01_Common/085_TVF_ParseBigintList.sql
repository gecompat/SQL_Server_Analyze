USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ParseBigintList
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Inline Table-valued Function
Zweck        : Validiert eine Pipe-Liste ganzzahliger bigint-Werte. Diese
               Funktion ist für Session-, Query-, Index- und andere numerische
               ID-Listen vorgesehen und verwendet bewusst keinen Identifier-
               Parser.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ParseBigintList]
(
    @List nvarchar(max)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          [l].[ItemOrdinal]
        , [l].[ItemText]
        , [NumberValue] = TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText])))
        , [IsValid] = CONVERT(bit,
              CASE WHEN [l].[IsValid] = 1
                     AND TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NOT NULL
                   THEN 1 ELSE 0 END)
        , [ErrorCode] = CONVERT(varchar(40),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorCode]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN 'INVALID_BIGINT' END)
        , [ErrorMessage] = CONVERT(nvarchar(4000),
              CASE WHEN [l].[IsValid] = 0 THEN [l].[ErrorMessage]
                   WHEN TRY_CONVERT(bigint, LTRIM(RTRIM([l].[ItemText]))) IS NULL
                   THEN N'Das Listenelement ist keine gültige bigint-Ganzzahl.' END)
    FROM [monitor].[TVF_ParsePipeList](@List) AS [l]
);
GO
