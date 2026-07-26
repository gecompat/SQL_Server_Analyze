USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_FrameworkUsageFromQueryStore
Version      : 2.0.0
Stand        : 2026-07-26
Typ          : Stored Procedure
Zweck        : Ermittelt aus dem Query Store der Frameworkdatenbank, welche
               monitor-Procedures tatsächlich ausgeführt wurden und welche
               aggregierte Laufzeit-, CPU-, I/O- und Plan-Evidenz vorliegt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.database_query_store_options, sys.query_store_query,
               sys.query_store_plan, sys.query_store_runtime_stats,
               sys.objects und sys.schemas. Jede Quelle wird je Aufruf höchstens
               einmal logisch gelesen.
Abgrenzung   : Keine eigene Erfassung, keine Query-Store-Konfigurationsänderung,
               kein Flush, kein Cleanup und keine Benutzerattribution. Fehlende
               Query-Store-Zeilen beweisen nicht, dass eine Procedure nie lief.
Kosten       : LOW_TO_MEDIUM. Die Aggregation ist nach Zeitraum und Ausgabezahl
               begrenzbar; der Query Store muss dennoch die passenden Intervalle
               und Pläne auswerten.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_FrameworkUsageFromQueryStore]
      @MaxZeilen          int            = 100
    , @MinAusfuehrungen   bigint         = 1
    , @ZeitraumTage       int            = NULL
    , @LockTimeoutMs      int            = 0
    , @ResultSetArt       varchar(16)    = 'CONSOLE'
    , @ResultTablesJson   nvarchar(max)  = NULL
    , @JsonErzeugen       bit            = 0
    , @Json               nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen     bit            = 1
    , @Hilfe              bit            = 0
    , @StatusCodeOut      varchar(40)    = NULL OUTPUT
    , @IsPartialOut       bit            = NULL OUTPUT
    , @ErrorNumberOut     int            = NULL OUTPUT
    , @ErrorMessageOut    nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @CapturedAtUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleRequested bit = CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @OriginalLockTimeout int = @@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(64);
    DECLARE @Limit bigint = CASE
        WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807)
        ELSE CONVERT(bigint,@MaxZeilen)
    END;
    DECLARE @FetchLimit bigint;
    DECLARE @CutoffUtc datetimeoffset(7) = NULL;
    DECLARE @QueryStoreActualState smallint = NULL;
    DECLARE @QueryStoreActualStateDesc nvarchar(60) = NULL;
    DECLARE @QueryStoreReadonlyReason bigint = NULL;
    DECLARE @OptionsReadable bit = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @ReturnedRowCount bigint = 0;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_FrameworkUsageFromQueryStore';
        PRINT N'Liest ausschließlich vorhandene Query-Store-Evidenz der Frameworkdatenbank.';
        PRINT N'@ZeitraumTage=NULL oder 0 verwendet den gesamten sichtbaren Query-Store-Zeitraum.';
        PRINT N'@MinAusfuehrungen muss mindestens 1 sein; @MaxZeilen=NULL oder 0 bedeutet unbegrenzt.';
        PRINT N'Gewichtete Mittelwerte verwenden count_executions als Gewicht je Runtime-Stats-Intervall.';
        PRINT N'@ResultSetArt=CONSOLE|RAW|TABLE|NONE; TABLE-Namen: moduleStatus, usage, sourceStatus, warnings.';
        PRINT N'JSON wird nur mit @JsonErzeugen=1 erzeugt. Die Procedure ändert keine Query-Store-Einstellung.';
        RETURN;
    END;

    CREATE TABLE [#FrameworkUsage_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );

    CREATE TABLE [#FrameworkUsage_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [QueryStoreActualStateDesc] nvarchar(60) NULL
        , [QueryStoreReadonlyReason] bigint NULL
        , [RequestedWindowDays] int NULL
        , [MinimumExecutions] bigint NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [HasMoreRows] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    CREATE TABLE [#FrameworkUsage_UsageCandidates]
    (
          [RowOrdinal] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [ProcedureName] sysname NOT NULL
        , [ExecutionCount] bigint NOT NULL
        , [LastExecutionTime] datetimeoffset(7) NULL
        , [AvgDurationMs] decimal(19,3) NULL
        , [AvgCpuMs] decimal(19,3) NULL
        , [AvgLogicalReads] decimal(19,2) NULL
        , [AvgMemoryGrantKB] decimal(19,2) NULL
        , [PlanCount] bigint NOT NULL
        , [QueryCount] bigint NOT NULL
        , [FirstSeen] datetimeoffset(7) NULL
        , [LastSeen] datetimeoffset(7) NULL
    );

    CREATE TABLE [#FrameworkUsage_Usage]
    (
          [ProcedureName] sysname NOT NULL
        , [ExecutionCount] bigint NOT NULL
        , [LastExecutionTime] datetimeoffset(7) NULL
        , [AvgDurationMs] decimal(19,3) NULL
        , [AvgCpuMs] decimal(19,3) NULL
        , [AvgLogicalReads] decimal(19,2) NULL
        , [AvgMemoryGrantKB] decimal(19,2) NULL
        , [PlanCount] bigint NOT NULL
        , [QueryCount] bigint NOT NULL
        , [FirstSeen] datetimeoffset(7) NULL
        , [LastSeen] datetimeoffset(7) NULL
        , PRIMARY KEY ([ProcedureName])
    );

    CREATE TABLE [#FrameworkUsage_SourceStatus]
    (
          [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [SourceName] sysname NOT NULL
        , [SourceObject] nvarchar(256) NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
        , [EvidenceLimit] nvarchar(1000) NOT NULL
    );

    CREATE TABLE [#FrameworkUsage_Warnings]
    (
          [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [SourceName] sysname NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [Message] nvarchar(2048) NOT NULL
    );

    IF @MaxZeilen<0
       OR @MinAusfuehrungen IS NULL OR @MinAusfuehrungen<1
       OR @ZeitraumTage<0 OR @ZeitraumTage>365000
       OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @OutputMode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT
              @StatusCode='INVALID_PARAMETER'
            , @IsPartial=1
            , @ErrorMessage=N'Parameter ungültig. Erlaubt sind @MaxZeilen>=0 oder NULL, @MinAusfuehrungen>=1, @ZeitraumTage zwischen 0 und 365000 oder NULL, @LockTimeoutMs zwischen 0 und 60000 sowie @ResultSetArt=CONSOLE|RAW|TABLE|NONE.';

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'parameterValidation',N'procedure parameters',@CapturedAtUtc,@StatusCode,1,
            0,NULL,NULL,@ErrorMessage,N'Es wurde keine fachliche Query-Store-Quelle gelesen.'
        );
        GOTO Finalize;
    END;

    IF @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|usage|sourceStatus|warnings'
            , @MappingTable=N'#FrameworkUsage_ResultTableMap'
            , @ThrowOnError=1;
    END;

    SET @FetchLimit = CASE
        WHEN @Limit=9223372036854775807 THEN @Limit
        ELSE @Limit+1
    END;

    IF COALESCE(@ZeitraumTage,0)>0
        SET @CutoffUtc=DATEADD(DAY,-@ZeitraumTage,CONVERT(datetimeoffset(7),SYSUTCDATETIME()));

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    BEGIN TRY
        SELECT TOP(1)
              @QueryStoreActualState=TRY_CONVERT(smallint,[actual_state])
            , @QueryStoreActualStateDesc=TRY_CONVERT(nvarchar(60),[actual_state_desc])
            , @QueryStoreReadonlyReason=TRY_CONVERT(bigint,[readonly_reason])
        FROM [sys].[database_query_store_options] WITH (NOLOCK);

        SET @OptionsReadable=1;

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'queryStoreOptions',N'sys.database_query_store_options',@CapturedAtUtc,
            CASE WHEN @QueryStoreActualState IN(1,2) THEN 'AVAILABLE' ELSE 'UNAVAILABLE_FEATURE' END,
            0,1,N'Query-Store-Metadatensichtbarkeit',NULL,NULL,
            N'Der Zustand beschreibt nur die Lesbarkeit des Query Store zum Erfassungszeitpunkt.'
        );
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
            , @IsPartial=1
            , @ErrorNumber=ERROR_NUMBER()
            , @ErrorMessage=ERROR_MESSAGE();

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'queryStoreOptions',N'sys.database_query_store_options',@CapturedAtUtc,@StatusCode,1,
            0,N'Query-Store-Metadatensichtbarkeit',@ErrorNumber,@ErrorMessage,
            N'Ohne lesbaren Query-Store-Zustand wird keine Laufzeitaggregation begonnen.'
        );

        INSERT [#FrameworkUsage_Warnings]([SourceName],[StatusCode],[ErrorNumber],[Message])
        VALUES(N'queryStoreOptions',@StatusCode,@ErrorNumber,COALESCE(@ErrorMessage,N'Query-Store-Zustand nicht lesbar.'));
    END CATCH;

    IF @OptionsReadable=0
    BEGIN
        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'frameworkUsage',N'sys.query_store_query + sys.query_store_plan + sys.query_store_runtime_stats',
            @CapturedAtUtc,'NOT_EXECUTED',1,0,N'Query-Store-Lesesichtbarkeit',NULL,NULL,
            N'Der Laufzeitpfad wurde wegen der nicht lesbaren Vorabquelle nicht ausgeführt.'
        );
        GOTO Finalize;
    END;

    IF @QueryStoreActualState NOT IN(1,2)
    BEGIN
        SELECT
              @StatusCode='UNAVAILABLE_FEATURE'
            , @IsPartial=0
            , @ErrorMessage=N'Query Store ist nicht lesbar aktiv. Die Procedure ändert keine Datenbankoption.';

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'frameworkUsage',N'sys.query_store_query + sys.query_store_plan + sys.query_store_runtime_stats',
            @CapturedAtUtc,'NOT_EXECUTED',0,0,N'Query-Store-Lesesichtbarkeit',NULL,@ErrorMessage,
            N'Ein deaktivierter oder fehlerhafter Query Store besitzt keine auswertbare Laufzeitevidenz.'
        );

        INSERT [#FrameworkUsage_Warnings]([SourceName],[StatusCode],[ErrorNumber],[Message])
        VALUES(N'frameworkUsage',@StatusCode,NULL,@ErrorMessage);
        GOTO Finalize;
    END;

    BEGIN TRY
        ;WITH [FrameworkQueries] AS
        (
            SELECT
                  [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ProcedureName]
                , [q].[query_id]
            FROM [sys].[query_store_query] AS [q] WITH (NOLOCK)
            INNER JOIN [sys].[objects] AS [o] WITH (NOLOCK)
                ON [o].[object_id]=[q].[object_id]
            INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
                ON [s].[schema_id]=[o].[schema_id]
            WHERE [s].[name]=N'monitor' COLLATE SQL_Latin1_General_CP1_CS_AS
              AND [o].[type]='P'
        ),
        [Aggregated] AS
        (
            SELECT
                  [fq].[ProcedureName]
                , SUM(CONVERT(bigint,[rs].[count_executions])) AS [ExecutionCount]
                , MAX(CONVERT(datetimeoffset(7),[rs].[last_execution_time])) AS [LastExecutionTime]
                , CONVERT(decimal(19,3),
                    SUM(CONVERT(float,[rs].[avg_duration])*CONVERT(float,[rs].[count_executions]))
                    / NULLIF(SUM(CONVERT(float,[rs].[count_executions])),0.0) / 1000.0) AS [AvgDurationMs]
                , CONVERT(decimal(19,3),
                    SUM(CONVERT(float,[rs].[avg_cpu_time])*CONVERT(float,[rs].[count_executions]))
                    / NULLIF(SUM(CONVERT(float,[rs].[count_executions])),0.0) / 1000.0) AS [AvgCpuMs]
                , CONVERT(decimal(19,2),
                    SUM(CONVERT(float,[rs].[avg_logical_io_reads])*CONVERT(float,[rs].[count_executions]))
                    / NULLIF(SUM(CONVERT(float,[rs].[count_executions])),0.0)) AS [AvgLogicalReads]
                , CONVERT(decimal(19,2),
                    SUM(CONVERT(float,[rs].[avg_query_max_used_memory])*8.0*CONVERT(float,[rs].[count_executions]))
                    / NULLIF(SUM(CONVERT(float,[rs].[count_executions])),0.0)) AS [AvgMemoryGrantKB]
                , CONVERT(bigint,COUNT(DISTINCT [p].[plan_id])) AS [PlanCount]
                , CONVERT(bigint,COUNT(DISTINCT [fq].[query_id])) AS [QueryCount]
                , MIN(CONVERT(datetimeoffset(7),[rs].[first_execution_time])) AS [FirstSeen]
                , MAX(CONVERT(datetimeoffset(7),[rs].[last_execution_time])) AS [LastSeen]
            FROM [FrameworkQueries] AS [fq]
            INNER JOIN [sys].[query_store_plan] AS [p] WITH (NOLOCK)
                ON [p].[query_id]=[fq].[query_id]
            INNER JOIN [sys].[query_store_runtime_stats] AS [rs] WITH (NOLOCK)
                ON [rs].[plan_id]=[p].[plan_id]
            WHERE @CutoffUtc IS NULL
               OR [rs].[last_execution_time]>=@CutoffUtc
            GROUP BY [fq].[ProcedureName]
            HAVING SUM(CONVERT(bigint,[rs].[count_executions]))>=@MinAusfuehrungen
        )
        INSERT [#FrameworkUsage_UsageCandidates]
        (
            [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs],
            [AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount],
            [FirstSeen],[LastSeen]
        )
        SELECT TOP(@FetchLimit)
              [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs]
            , [AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount]
            , [FirstSeen],[LastSeen]
        FROM [Aggregated]
        ORDER BY [ExecutionCount] DESC,[ProcedureName];

        IF @Limit<9223372036854775807
           AND EXISTS(SELECT 1 FROM [#FrameworkUsage_UsageCandidates] WHERE [RowOrdinal]>@Limit)
            SET @HasMoreRows=1;

        INSERT [#FrameworkUsage_Usage]
        (
            [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs],
            [AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount],
            [FirstSeen],[LastSeen]
        )
        SELECT
              [ProcedureName],[ExecutionCount],[LastExecutionTime],[AvgDurationMs]
            , [AvgCpuMs],[AvgLogicalReads],[AvgMemoryGrantKB],[PlanCount],[QueryCount]
            , [FirstSeen],[LastSeen]
        FROM [#FrameworkUsage_UsageCandidates]
        WHERE [RowOrdinal]<=@Limit;

        SET @ReturnedRowCount=(SELECT COUNT_BIG(*) FROM [#FrameworkUsage_Usage]);
        SET @StatusCode=CASE WHEN @ReturnedRowCount=0 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END;

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'frameworkUsage',N'sys.query_store_query + sys.query_store_plan + sys.query_store_runtime_stats',
            @CapturedAtUtc,@StatusCode,0,@ReturnedRowCount,
            N'Query-Store-Lesesichtbarkeit',NULL,NULL,
            N'Query-Store-Retention, Capture Mode, Cleanup, Flushzeitpunkt und Metadatensichtbarkeit begrenzen die Aussage. Mittelwerte sind nach Ausführungsanzahl gewichtete Intervallaggregate.'
        );
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
            , @IsPartial=1
            , @ErrorNumber=ERROR_NUMBER()
            , @ErrorMessage=ERROR_MESSAGE();

        INSERT [#FrameworkUsage_SourceStatus]
        (
            [SourceName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],
            [ReturnedRowCount],[RequiredPermission],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
            N'frameworkUsage',N'sys.query_store_query + sys.query_store_plan + sys.query_store_runtime_stats',
            @CapturedAtUtc,@StatusCode,1,0,N'Query-Store-Lesesichtbarkeit',@ErrorNumber,@ErrorMessage,
            N'Die Laufzeitaggregation wurde kontrolliert abgebrochen; keine eigene Erfassung oder Konfigurationsänderung wurde ausgeführt.'
        );

        INSERT [#FrameworkUsage_Warnings]([SourceName],[StatusCode],[ErrorNumber],[Message])
        VALUES(N'frameworkUsage',@StatusCode,@ErrorNumber,COALESCE(@ErrorMessage,N'Query-Store-Aggregation fehlgeschlagen.'));
    END CATCH;

Finalize:
    SET @ReturnedRowCount=(SELECT COUNT_BIG(*) FROM [#FrameworkUsage_Usage]);

    IF @ErrorMessage IS NULL
       AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_EMPTY')
    BEGIN
        SELECT TOP(1)
              @ErrorNumber=COALESCE(@ErrorNumber,[ErrorNumber])
            , @ErrorMessage=[Message]
        FROM [#FrameworkUsage_Warnings]
        ORDER BY [WarningOrdinal];
    END;

    INSERT [#FrameworkUsage_ModuleStatus]
    (
        [ModuleName],[CapturedAtUtc],[StatusCode],[IsPartial],
        [QueryStoreActualStateDesc],[QueryStoreReadonlyReason],[RequestedWindowDays],
        [MinimumExecutions],[ReturnedRowCount],[HasMoreRows],[ErrorNumber],[ErrorMessage]
    )
    VALUES
    (
        N'USP_FrameworkUsageFromQueryStore',@CapturedAtUtc,@StatusCode,@IsPartial,
        @QueryStoreActualStateDesc,@QueryStoreReadonlyReason,NULLIF(@ZeitraumTage,0),
        COALESCE(@MinAusfuehrungen,0),@ReturnedRowCount,@HasMoreRows,@ErrorNumber,@ErrorMessage
    );

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=
        (
            SELECT
                  N'FrameworkUsageFromQueryStore' AS [resultName]
                , 1 AS [schemaVersion]
                , @CapturedAtUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @QueryStoreActualStateDesc AS [queryStoreActualStateDesc]
                , @QueryStoreReadonlyReason AS [queryStoreReadonlyReason]
                , NULLIF(@ZeitraumTage,0) AS [requestedWindowDays]
                , @MinAusfuehrungen AS [minimumExecutions]
                , @ReturnedRowCount AS [returnedRowCount]
                , @HasMoreRows AS [hasMoreRows]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @UsageJson nvarchar(max)=
        (
            SELECT *
            FROM [#FrameworkUsage_Usage]
            ORDER BY [ExecutionCount] DESC,[ProcedureName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @SourceStatusJson nvarchar(max)=
        (
            SELECT *
            FROM [#FrameworkUsage_SourceStatus]
            ORDER BY [SourceOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max)=
        (
            SELECT *
            FROM [#FrameworkUsage_Warnings]
            ORDER BY [WarningOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"usage":',COALESCE(@UsageJson,N'[]')
            , N',"sourceStatus":',COALESCE(@SourceStatusJson,N'[]')
            , N',"warnings":',COALESCE(@WarningsJson,N'[]')
            , N'}'
        );
    END;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @ConsoleRequested=1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#FrameworkUsage_Usage'
            , @ResultLabel=N'Framework-Nutzung aus Query Store'
            , @EmptyMessage=N'Keine sichtbare Framework-Nutzung im gewählten Query-Store-Scope';
    END
    ELSE IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#FrameworkUsage_ModuleStatus];
        SELECT * FROM [#FrameworkUsage_Usage] ORDER BY [ExecutionCount] DESC,[ProcedureName];
        SELECT * FROM [#FrameworkUsage_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#FrameworkUsage_Warnings] ORDER BY [WarningOrdinal];
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [ResultCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#FrameworkUsage_ResultTableMap]
            ORDER BY [ResultName];
        OPEN [ResultCursor];
        FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'moduleStatus' THEN N'#FrameworkUsage_ModuleStatus'
                WHEN N'usage' THEN N'#FrameworkUsage_Usage'
                WHEN N'sourceStatus' THEN N'#FrameworkUsage_SourceStatus'
                WHEN N'warnings' THEN N'#FrameworkUsage_Warnings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;
            FETCH NEXT FROM [ResultCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [ResultCursor];
        DEALLOCATE [ResultCursor];
    END;

    IF @PrintMeldungen=1
       AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_EMPTY')
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=LEFT
        (
            CONCAT(N'USP_FrameworkUsageFromQueryStore: ',@StatusCode,N'. ',
                   COALESCE(@ErrorMessage,N'Siehe sourceStatus und warnings.')),
            2048
        );
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;

    SELECT
          @StatusCodeOut=@StatusCode
        , @IsPartialOut=@IsPartial
        , @ErrorNumberOut=@ErrorNumber
        , @ErrorMessageOut=@ErrorMessage;
END;
GO
