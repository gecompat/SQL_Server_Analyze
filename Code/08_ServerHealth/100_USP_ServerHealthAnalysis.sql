USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerHealthAnalysis
Version      : 3.0.1
Stand        : 2026-07-16
Zweck        : Orchestriert alle Server-Health-Module. RAW/CONSOLE werden an
               Child-Module weitergereicht; JSON enthält benannte Modulobjekte.
Änderungen   : 3.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert;
                         Child-Statusvariablen vor jedem Aufruf zurückgesetzt.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ServerHealthAnalysis]
      @MitCpu           bit           = 1
    , @MitNuma          bit           = 1
    , @MitMemory        bit           = 1
    , @MitTempDB        bit           = 1
    , @MitConfiguration bit           = 1
    , @MitTraceFlags    bit           = 1
    , @MitStartup       bit           = 1
    , @MitOS            bit           = 1
    , @MitSecurity      bit           = 1
    , @MaxZeilen        int           = 100
    , @ResultSetArt     varchar(16)   = 'CONSOLE'
    , @JsonErzeugen     bit           = 0
    , @Json             nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen   bit           = 1
    , @Hilfe            bit           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @ChildStatus varchar(40);
    DECLARE @ChildPartial bit;
    DECLARE @ChildErrorNumber int;
    DECLARE @ChildErrorMessage nvarchar(2048);
    DECLARE @CpuJson nvarchar(max);
    DECLARE @NumaJson nvarchar(max);
    DECLARE @MemoryJson nvarchar(max);
    DECLARE @TempDbJson nvarchar(max);
    DECLARE @ConfigurationJson nvarchar(max);
    DECLARE @TraceFlagsJson nvarchar(max);
    DECLARE @StartupJson nvarchar(max);
    DECLARE @OsJson nvarchar(max);
    DECLARE @SecurityJson nvarchar(max);

    CREATE TABLE [#ModuleStatus]
    (
          [Ordinal]      tinyint        NOT NULL
        , [ModuleName]   sysname        NOT NULL
        , [StatusCode]   varchar(40)    NOT NULL
        , [IsPartial]    bit            NOT NULL
        , [ErrorNumber]  int            NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ServerHealthAnalysis';
        PRINT N'@ResultSetArt = RAW, CONSOLE oder NONE; optional JSON mit benannten Modulobjekten.';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@MitCpu = 0 AND @MitNuma = 0 AND @MitMemory = 0 AND @MitTempDB = 0
           AND @MitConfiguration = 0 AND @MitTraceFlags = 0 AND @MitStartup = 0
           AND @MitOS = 0 AND @MitSecurity = 0)
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitCpu = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_ServerCpuTopology]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @CpuJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (1, N'USP_ServerCpuTopology', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitNuma = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_ServerNuma]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @NumaJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (2, N'USP_ServerNuma', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitMemory = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_ServerMemory]
                  @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @MemoryJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (3, N'USP_ServerMemory', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitTempDB = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_TempDBConfiguration]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @TempDbJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (4, N'USP_TempDBConfiguration', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitConfiguration = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_ServerConfiguration]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ConfigurationJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (5, N'USP_ServerConfiguration', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitTraceFlags = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_TraceFlags]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @TraceFlagsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (6, N'USP_TraceFlags', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitStartup = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_StartupParameters]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @StartupJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (7, N'USP_StartupParameters', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitOS = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_OSInformation]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @OsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (8, N'USP_OSInformation', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitSecurity = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_ServerSecurityConfiguration]
                  @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @SecurityJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY
        BEGIN CATCH
            SELECT @ChildStatus = 'ERROR_HANDLED', @ChildPartial = 1,
                   @ChildErrorNumber = ERROR_NUMBER(), @ChildErrorMessage = ERROR_MESSAGE();
        END CATCH;
        INSERT [#ModuleStatus] VALUES
        (9, N'USP_ServerSecurityConfiguration', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [#ModuleStatus]
        WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
    )
       AND @OverallStatus = 'AVAILABLE'
    BEGIN
        SET @OverallStatus = 'AVAILABLE_LIMITED';
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_ServerHealthAnalysis' AS [ModuleName]
            , @Now                       AS [CollectionTimeUtc]
            , @OverallStatus             AS [StatusCode]
            , CONVERT(bit, CASE WHEN @OverallStatus = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , (SELECT COUNT_BIG(*) FROM [#ModuleStatus]) AS [ModuleCount]
            , (SELECT COUNT_BIG(*) FROM [#ModuleStatus]
               WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')) AS [ProblemModuleCount];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#ModuleStatus] ORDER BY [Ordinal];
        END
        ELSE
        BEGIN
            SELECT
                  N'Server-Health Teilmodul' AS [Ergebnis]
                , [Ordinal]                  AS [Reihenfolge]
                , [ModuleName]               AS [Modul]
                , [StatusCode]               AS [Status]
                , [IsPartial]                AS [Partiell]
                , [ErrorMessage]             AS [Fehler]
            FROM [#ModuleStatus]
            ORDER BY [Ordinal];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max);
        DECLARE @Warnings nvarchar(max);

        SELECT @Meta =
        (
            SELECT
                  N'ServerHealthAnalysis' AS [resultName]
                , 1                       AS [schemaVersion]
                , @Now                    AS [generatedAtUtc]
                , @OverallStatus          AS [statusCode]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @Warnings =
        (
            SELECT *
            FROM [#ModuleStatus]
            WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
            ORDER BY [Ordinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@Meta, N'{}')
            , N',"cpuTopology":', COALESCE(JSON_QUERY(@CpuJson), N'null')
            , N',"numa":', COALESCE(JSON_QUERY(@NumaJson), N'null')
            , N',"memory":', COALESCE(JSON_QUERY(@MemoryJson), N'null')
            , N',"tempdb":', COALESCE(JSON_QUERY(@TempDbJson), N'null')
            , N',"configuration":', COALESCE(JSON_QUERY(@ConfigurationJson), N'null')
            , N',"traceFlags":', COALESCE(JSON_QUERY(@TraceFlagsJson), N'null')
            , N',"startupParameters":', COALESCE(JSON_QUERY(@StartupJson), N'null')
            , N',"operatingSystem":', COALESCE(JSON_QUERY(@OsJson), N'null')
            , N',"security":', COALESCE(JSON_QUERY(@SecurityJson), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
END;
GO
