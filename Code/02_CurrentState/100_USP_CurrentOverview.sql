USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentOverview
Version      : 2.1.0
Stand        : 2026-07-16
Zweck        : Orchestriert die Current-State-Module fehlerisoliert. Der
               gemeinsame Ausgabe- und Filtervertrag wird unverändert an alle
               kompatiblen Teilmodule weitergegeben. JSON enthält benannte
               Child-Objekte statt anonymer Resultsetnummern.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentOverview]
      @SessionIds                    nvarchar(max)  = NULL
    , @DatabaseNames                 nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen  bit            = 0
    , @DatabaseNamePattern           nvarchar(4000) = NULL
    , @MaxDatenbanken                int            = 16
    , @MitSessions                   bit            = 1
    , @MitRequests                   bit            = 1
    , @MitBlocking                   bit            = 1
    , @MitWaits                      bit            = 1
    , @MitTransactions               bit            = 1
    , @MitMemoryGrants               bit            = 1
    , @MitTempDB                     bit            = 1
    , @MitIO                         bit            = 1
    , @MitLog                        bit            = 1
    , @MitSqlText                    bit            = 1
    , @GesamtenSqlTextEinbeziehen    bit            = 0
    , @InputBufferEinbeziehen        bit            = 0
    , @ModulInfoEinbeziehen          bit            = 1
    , @MaxSqlTextZeichen             int            = 4000
    , @SampleSeconds                 tinyint         = 0
    , @MaxZeilen                     int             = 500
    , @ResultSetArt varchar(16)='CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen                  bit              = 0
    , @Json                          nvarchar(max)    = NULL OUTPUT
    , @PrintMeldungen                bit              = 1
    , @Hilfe                         bit              = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @OutputMode = 'NONE';

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentOverview';
        PRINT N'@SessionIds = exakte Pipe-Liste; @DatabaseNames: N'''' aktuelle DB, NULL alle zulässigen DBs.';
        PRINT N'@DatabaseNamePattern ist zu @DatabaseNames gegenseitig exklusiv.';
        PRINT N'@ResultSetArt = CONSOLE (Default)|RAW|TABLE|NONE; der Wert wird case-insensitiv verarbeitet.';
        PRINT N'@GesamtenSqlTextEinbeziehen, @InputBufferEinbeziehen und @ModulInfoEinbeziehen werden an USP_CurrentRequests weitergegeben.';
        PRINT N'@MaxSqlTextZeichen: positiv begrenzt die Textdarstellung; NULL/0 liefert vollständige Texte.';
        PRINT N'@JsonErzeugen=1 liefert meta sowie benannte Child-Objekte sessions, requests, blocking, waits, transactions, memoryGrants, tempdb, io und log.';
        PRINT N'Jedes Teilmodul bleibt in eigenem TRY/CATCH isoliert.';
        RETURN;
    END;

    DECLARE @StartedAtUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @ExecutedModules int = 0;
    DECLARE @FailedModules int = 0;
    DECLARE @Message nvarchar(2048);
    DECLARE @ChildJson nvarchar(max);

    CREATE TABLE [#CurrentOverview_ModuleJson]
    (
          [ModuleOrdinal] int NOT NULL PRIMARY KEY
        , [PropertyName] varchar(40) NOT NULL
        , [JsonValue] nvarchar(max) NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @SampleSeconds > 60
       OR @MaxZeilen < 0
       OR @MaxDatenbanken < 0
       OR @MaxSqlTextZeichen < 0
       OR @MitSqlText IS NULL OR @MitSqlText NOT IN (0,1)
       OR @GesamtenSqlTextEinbeziehen IS NULL OR @GesamtenSqlTextEinbeziehen NOT IN (0,1)
       OR @InputBufferEinbeziehen IS NULL OR @InputBufferEinbeziehen NOT IN (0,1)
       OR @ModulInfoEinbeziehen IS NULL OR @ModulInfoEinbeziehen NOT IN (0,1)
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @JsonErzeugen IS NULL
    BEGIN
        IF @OutputMode <> 'NONE'
        BEGIN
            SELECT
                  N'USP_CurrentOverview' AS [ModuleName]
                , @StartedAtUtc AS [CollectionTimeUtc]
                , 'INVALID_PARAMETER' AS [StatusCode]
                , CONVERT(bit, 1) AS [IsPartial]
                , 0 AS [ExecutedModules]
                , 0 AS [FailedModules]
                , N'Ungültiger Parameterwert.' AS [ErrorMessage];
        END;

        IF @JsonErzeugen = 1
        BEGIN
            SET @Json = CONCAT
            (
                N'{"meta":',
                (
                    SELECT N'CurrentOverview' AS [resultName], 1 AS [schemaVersion],
                           @StartedAtUtc AS [generatedAtUtc], 'INVALID_PARAMETER' AS [statusCode],
                           N'Ungültiger Parameterwert.' AS [errorMessage]
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
                ),
                N',"warnings":[]}'
            );
        END;
        RETURN;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentOverview' AS [ModuleName]
            , @StartedAtUtc AS [CollectionTimeUtc]
            , 'AVAILABLE' AS [StatusCode]
            , CONVERT(bit, 0) AS [IsPartial]
            , N'Die folgenden Resultsets stammen aus den aktivierten Current-State-Modulen.' AS [Detail];
    END;

    IF @MitSessions = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentSessions]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (10, 'sessions', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (10, 'sessions', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitRequests = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentRequests]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @GesamtenSqlTextEinbeziehen = @GesamtenSqlTextEinbeziehen
                , @InputBufferEinbeziehen = @InputBufferEinbeziehen
                , @ModulInfoEinbeziehen = @ModulInfoEinbeziehen
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (20, 'requests', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (20, 'requests', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitBlocking = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentBlocking]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (30, 'blocking', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (30, 'blocking', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitWaits = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentWaits]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @SampleSeconds = @SampleSeconds
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (40, 'waits', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (40, 'waits', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitTransactions = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTransactions]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (50, 'transactions', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (50, 'transactions', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitMemoryGrants = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentMemoryGrants]
                  @SessionIds = @SessionIds
                , @MitSqlText = @MitSqlText
                , @MaxSqlTextZeichen = @MaxSqlTextZeichen
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (60, 'memoryGrants', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (60, 'memoryGrants', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitTempDB = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTempDB]
                  @SessionIds = @SessionIds
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (70, 'tempdb', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (70, 'tempdb', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitIO = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentIO]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern
                , @MaxDatenbanken = @MaxDatenbanken
                , @SampleSeconds = @SampleSeconds
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (80, 'io', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (80, 'io', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @MitLog = 1
    BEGIN
        SET @ExecutedModules += 1;
        SET @ChildJson = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentLog]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern
                , @MaxDatenbanken = @MaxDatenbanken
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ChildJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;
            INSERT [#CurrentOverview_ModuleJson] VALUES (90, 'log', @ChildJson, 'AVAILABLE', NULL);
        END TRY
        BEGIN CATCH
            SET @FailedModules += 1;
            INSERT [#CurrentOverview_ModuleJson] VALUES (90, 'log', NULL, 'ERROR_HANDLED', ERROR_MESSAGE());
        END CATCH;
    END;

    IF @PrintMeldungen = 1 AND @FailedModules > 0
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentOverview: %d von %d Modulen sind fehlgeschlagen.', @FailedModules, @ExecutedModules);
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentOverview' AS [ModuleName]
            , SYSUTCDATETIME() AS [FinishedAtUtc]
            , CASE WHEN @FailedModules = 0 THEN 'AVAILABLE'
                   WHEN @FailedModules < @ExecutedModules THEN 'AVAILABLE_LIMITED'
                   ELSE 'ERROR_HANDLED' END AS [StatusCode]
            , CONVERT(bit, CASE WHEN @FailedModules > 0 THEN 1 ELSE 0 END) AS [IsPartial]
            , @ExecutedModules AS [ExecutedModules]
            , @FailedModules AS [FailedModules]
            , DATEDIFF_BIG(MILLISECOND, @StartedAtUtc, SYSUTCDATETIME()) AS [DurationMs];

        SELECT [PropertyName] AS [ModuleName], [StatusCode], [ErrorMessage]
        FROM [#CurrentOverview_ModuleJson]
        WHERE [StatusCode] <> 'AVAILABLE'
        ORDER BY [ModuleOrdinal];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max) =
        (
            SELECT
                  N'CurrentOverview' AS [resultName]
                , 1 AS [schemaVersion]
                , @StartedAtUtc AS [generatedAtUtc]
                , CASE WHEN @FailedModules = 0 THEN 'AVAILABLE'
                       WHEN @FailedModules < @ExecutedModules THEN 'AVAILABLE_LIMITED'
                       ELSE 'ERROR_HANDLED' END AS [statusCode]
                , @ExecutedModules AS [executedModules]
                , @FailedModules AS [failedModules]
                , DATEDIFF_BIG(MILLISECOND, @StartedAtUtc, SYSUTCDATETIME()) AS [durationMs]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max) =
        (
            SELECT [PropertyName] AS [moduleName], [StatusCode] AS [statusCode], [ErrorMessage] AS [errorMessage]
            FROM [#CurrentOverview_ModuleJson]
            WHERE [StatusCode] <> 'AVAILABLE'
            ORDER BY [ModuleOrdinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SELECT @Json = CONCAT
        (
              N'{"meta":', COALESCE(@Meta, N'{}')
            , N',"sessions":', COALESCE(MAX(CASE WHEN [PropertyName] = 'sessions' THEN [JsonValue] END), N'null')
            , N',"requests":', COALESCE(MAX(CASE WHEN [PropertyName] = 'requests' THEN [JsonValue] END), N'null')
            , N',"blocking":', COALESCE(MAX(CASE WHEN [PropertyName] = 'blocking' THEN [JsonValue] END), N'null')
            , N',"waits":', COALESCE(MAX(CASE WHEN [PropertyName] = 'waits' THEN [JsonValue] END), N'null')
            , N',"transactions":', COALESCE(MAX(CASE WHEN [PropertyName] = 'transactions' THEN [JsonValue] END), N'null')
            , N',"memoryGrants":', COALESCE(MAX(CASE WHEN [PropertyName] = 'memoryGrants' THEN [JsonValue] END), N'null')
            , N',"tempdb":', COALESCE(MAX(CASE WHEN [PropertyName] = 'tempdb' THEN [JsonValue] END), N'null')
            , N',"io":', COALESCE(MAX(CASE WHEN [PropertyName] = 'io' THEN [JsonValue] END), N'null')
            , N',"log":', COALESCE(MAX(CASE WHEN [PropertyName] = 'log' THEN [JsonValue] END), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        )
        FROM [#CurrentOverview_ModuleJson];
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CurrentOverview_ModuleJson'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
