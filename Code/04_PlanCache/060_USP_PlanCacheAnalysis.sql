USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PlanCacheAnalysis
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Orchestriert Plan-Cache- und Showplan-Module mit einheitlichen
               Listen-, Pattern-, Limit- und Ausgabeparametern.
Änderungen   : 2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats                    bit            = 1
    , @MitQueryHashAnalysis             bit            = 0
    , @MitPlanCacheHealth               bit            = 0
    , @MitShowplanAnalysis              bit            = 0
    , @DatabaseNames                    nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @MaxDatenbanken                   int            = 16
    , @QueryHash                        binary(8)      = NULL
    , @QueryPlanHash                    binary(8)      = NULL
    , @PlanHandle                       varbinary(64)  = NULL
    , @TextPattern                      nvarchar(4000) = NULL
    , @Sortierung                       varchar(32)    = 'CPU_TOTAL'
    , @AnalyseModus                     varchar(16)    = 'TOP'
    , @MaxZeilen                        int            = 100
    , @MaxAnalyseobjekte                int            = 20
    , @MaxDurationSeconds               int            = 30
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Mode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus, 'TOP'))));
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @Detail nvarchar(2000) = N'Aktivierte Phase-3-Module werden nacheinander ausgeführt.';
    DECLARE @HealthMode varchar(16) = CASE WHEN @Mode = 'VOLL' THEN 'VOLL' ELSE 'SUMMARY' END;
    DECLARE @MitDbVerteilung bit = CASE WHEN @Mode = 'VOLL' THEN 1 ELSE 0 END;
    DECLARE @ShowplanMode varchar(16) = CASE WHEN @Mode = 'VOLL' THEN 'VOLL' ELSE 'GEZIELT' END;
    DECLARE @QueryStatsJson nvarchar(max);
    DECLARE @HashJson nvarchar(max);
    DECLARE @HealthJson nvarchar(max);
    DECLARE @ShowplanJson nvarchar(max);

    DECLARE @Errors TABLE
    (
          [ExecutionOrdinal] tinyint        NOT NULL
        , [ModuleName]       sysname        NOT NULL
        , [InvocationStatus] varchar(40)    NOT NULL
        , [ErrorNumber]      int            NULL
        , [ErrorMessage]     nvarchar(2048) NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PlanCacheAnalysis';
        PRINT N'Datenbank- und Textfilter folgen den zentralen Listen-/Patternverträgen.';
        PRINT N'@ResultSetArt = RAW, CONSOLE, TABLE oder NONE; optional JSON über @Json OUTPUT.';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @MaxAnalyseobjekte < 0
       OR @MaxDatenbanken < 0
       OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @Mode NOT IN ('TOP', 'VOLL')
       OR (@MitQueryStats = 0 AND @MitQueryHashAnalysis = 0
           AND @MitPlanCacheHealth = 0 AND @MitShowplanAnalysis = 0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @Detail = N'Ungültiger Parameter oder kein Teilmodul aktiviert.';
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitQueryStats = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStats]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern
                , @MaxDatenbanken = @MaxDatenbanken
                , @QueryHash = @QueryHash
                , @QueryPlanHash = @QueryPlanHash
                , @PlanHandle = @PlanHandle
                , @TextPattern = @TextPattern
                , @Sortierung = @Sortierung
                , @AnalyseModus = @Mode
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @QueryStatsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (1, N'USP_QueryStats', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @Errors VALUES (1, N'USP_QueryStats', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitQueryHashAnalysis = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryHashAnalysis]
                  @QueryHash = @QueryHash
                , @Sortierung = @Sortierung
                , @AnalyseModus = @Mode
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @HashJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (2, N'USP_QueryHashAnalysis', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @Errors VALUES (2, N'USP_QueryHashAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitPlanCacheHealth = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_PlanCacheHealth]
                  @AnalyseModus = @HealthMode
                , @MitDatenbankVerteilung = @MitDbVerteilung
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @HealthJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (3, N'USP_PlanCacheHealth', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @Errors VALUES (3, N'USP_PlanCacheHealth', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitShowplanAnalysis = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ShowplanAnalysis]
                  @PlanHandle = @PlanHandle
                , @QueryHash = @QueryHash
                , @QueryPlanHash = @QueryPlanHash
                , @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern
                , @MaxDatenbanken = @MaxDatenbanken
                , @TextPattern = @TextPattern
                , @AnalyseModus = @ShowplanMode
                , @Sortierung = @Sortierung
                , @MaxAnalyseobjekte = @MaxAnalyseobjekte
                , @MaxZeilen = @MaxZeilen
                , @MaxDurationSeconds = @MaxDurationSeconds
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ShowplanJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (4, N'USP_ShowplanAnalysis', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @Errors VALUES (4, N'USP_ShowplanAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF EXISTS (SELECT 1 FROM @Errors WHERE [InvocationStatus] <> 'EXECUTED')
       AND @StatusCode = 'AVAILABLE'
    BEGIN
        SET @StatusCode = 'AVAILABLE_LIMITED';
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_PlanCacheAnalysis' AS [ModuleName]
            , @Now                    AS [CollectionTimeUtc]
            , @StatusCode             AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , @Detail                 AS [Detail];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM @Errors ORDER BY [ExecutionOrdinal];
        END
        ELSE
        BEGIN
            SELECT
                  N'Plan-Cache Teilmodul' AS [Ergebnis]
                , [ExecutionOrdinal]      AS [Reihenfolge]
                , [ModuleName]            AS [Modul]
                , [InvocationStatus]      AS [Status]
                , [ErrorMessage]          AS [Fehler]
            FROM @Errors
            ORDER BY [ExecutionOrdinal];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max);
        DECLARE @Warnings nvarchar(max);

        SELECT @Meta =
        (
            SELECT
                  N'PlanCacheAnalysis' AS [resultName]
                , 1                    AS [schemaVersion]
                , @Now                 AS [generatedAtUtc]
                , @StatusCode          AS [statusCode]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @Warnings =
        (
            SELECT *
            FROM @Errors
            WHERE [InvocationStatus] <> 'EXECUTED'
            ORDER BY [ExecutionOrdinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@Meta, N'{}')
            , N',"queryStats":', COALESCE(JSON_QUERY(@QueryStatsJson), N'null')
            , N',"queryHashes":', COALESCE(JSON_QUERY(@HashJson), N'null')
            , N',"planCacheHealth":', COALESCE(JSON_QUERY(@HealthJson), N'null')
            , N',"showplan":', COALESCE(JSON_QUERY(@ShowplanJson), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
    IF @TableResultRequested = 1
    BEGIN
        SELECT * INTO [#MonitorTableResult] FROM @Errors;
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#MonitorTableResult'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
