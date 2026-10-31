USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PerformanceCounters
Version      : 1.1.0
Stand        : 2026-07-18
Zweck        : Liest gefilterte Performance-Counter und interpretiert
               unterstützte cntr_type-Werte; unbekannte Typen bleiben Rohwerte.
Datenquellen : sys.dm_os_performance_counters, sys.dm_os_sys_info.
Grenzen      : Universelle Alarmgrenzen werden nicht behauptet. Rate-Counter
               benötigen ein Sample; Counterreset wird als solcher markiert.
Nebenwirkung : Optionales WAITFOR für 1 bis 60 Sekunden; keine Persistenz.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PerformanceCounters]
      @ObjectNames       nvarchar(max)  = NULL
    , @CounterNames      nvarchar(max)  = NULL
    , @SampleSeconds     tinyint         = 0
    , @MaxZeilen         int             = 1000
    , @ResultSetArt      varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen      bit             = 0
    , @Json              nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen    bit             = 1
    , @Hilfe             bit             = 0
    , @StatusCodeOut     varchar(40)     = NULL OUTPUT
    , @IsPartialOut      bit             = NULL OUTPUT
    , @ErrorNumberOut    int             = NULL OUTPUT
    , @ErrorMessageOut   nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'counters',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PerformanceCounters';
        PRINT N'Objekt-/Counterfilter sind bracket-aware Pipe-Listen; Wildcards werden als Literale behandelt.';
        PRINT N'SampleSeconds 0 liest zweimal unmittelbar nacheinander; 1..60 wartet zwischen Messpunkten.';
        PRINT N'Delta-, Reset- und Basisfehler erhalten eigene FindingCodes.';
        PRINT N'Unterstützte cntr_type-Werte liefern Snapshot, Rate, Prozent oder Quotient; übrige bleiben Rohwerte.';
        PRINT N'MaxZeilen begrenzt Ausgabe erst nach Messung und Interpretation.';
        PRINT N'TABLE exportiert counters; JSON kann parallel zu jeder Ausgabeart erzeugt werden.';
        PRINT N'Hilfe kehrt vor Sampling und Status-OUTPUT-Zuweisung zurück.';
        PRINT N'@ObjectNames nvarchar(max); Default: NULL. Optionaler Filter auf Objektbezeichnungen aus sys.dm_os_performance_counters. Mehrere Werte werden als bracket-aware Pipe-Liste durch monitor.TVF_ParseStringList geparst. Äußere Leerzeichen werden entfernt; Pipe-Zeichen in eckig geklammerten Werten bleiben erhalten, ]] maskiert eine schließende Klammer. Der entquotierte StringValue wird case-sensitive verglichen. NULL lässt alle Objekte zu. Leerstring, leeres Element, ungültige Klammerstruktur, leerer entquotierter Wert oder ein Segment über 4000 UTF-16-Codeeinheiten ergibt INVALID_PARAMETER. Duplikate bleiben erhalten, ändern den EXISTS-Filter aber nicht. Wildcards sind Literale.';
        PRINT N'@CounterNames nvarchar(max); Default: NULL. Optionaler Filter auf Counterbezeichnungen mit derselben bracket-aware Pipe-Syntax und denselben Parsergrenzen. NULL lässt alle Counter zu. Der direkte Vergleich ist case-sensitive; zusätzlich wird Name plus N'' base'' case-insensitive einbezogen, damit die Basiscounter für Quotienten verfügbar sind. Ungültige Listenelemente ergeben INVALID_PARAMETER. Duplikate ändern den EXISTS-Filter nicht; Wildcards werden nicht als Muster ausgewertet.';
        PRINT N'@SampleSeconds tinyint; Default: 0. Angabe in Sekunden. 0 liest zwei unmittelbar aufeinanderfolgende DMV-Stände ohne WAITFOR und erzwingt für Delta-Typen SAMPLE_REQUIRED_FOR_DELTA_METRIC. 1 bis 60 wartet zwischen den Messungen; verwendet wird die tatsächlich gemessene Dauer. Werte über 60 sind INVALID_PARAMETER; tinyint erlaubt 0 bis 255. NULL passiert die >60-Prüfung und löst kein WAITFOR aus; weil der Caller nur bei exakt 0 die Sampledauer auf 0 setzt, wird bei NULL die gemessene UTC-Dauer an die Interpretationsfunktion übergeben. Typen: 65792 RAW_SNAPSHOT; 272696320 und 272696576 RATE_PER_SECOND (Delta geteilt durch Samplesekunden); 537003264 FRACTION_DELTA_PERCENT (100 mal Zählerdelta geteilt durch Basisdelta); 1073874176 AVERAGE_DELTA_RATIO (Zählerdelta geteilt durch Basisdelta); weitere Typen RAW_UNINTERPRETED. Deltas erfordern einen nicht fallenden Zähler; Quotienten zusätzlich eine vorhandene, steigende Basis. Basiscountertypen 1073939458 und 1073939712 werden nicht als Ergebniszeilen ausgegeben. Keine Persistenz. Die gemessene Dauer beginnt vor dem Temp-Tabellenaufbau und dem ersten DMV-Lesen und endet vor dem zweiten Lesen; sie ist keine reine WAITFOR-Dauer.';
        PRINT N'@MaxZeilen int; Default: 1000. Nichtnegative int-Anzahl. Werte unter 0 ergeben INVALID_PARAMETER. Werte von 1 bis 2147483647 begrenzen RAW-/CONSOLE-Zeilen und JSON-Countereinträge; 0 und NULL werden auf die größte bigint-TOP-Grenze abgebildet. Die Begrenzung greift erst nach beiden Snapshots, Interpretation und Materialisierung und begrenzt keine Quellarbeit. TABLE exportiert die materialisierten Counter ohne dieses TOP-Limit. Sortierung nach ObjectName, CounterName und InstanceName; keine repräsentative Stichprobe.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Ausgabeart, normalisiert mit LTRIM/RTRIM und UPPER. RAW liefert Status und technische Counterzeilen; CONSOLE Status und eine beschriftete Helferansicht; TABLE schreibt das einzelne Resultset counters in ein lokales Ziel; NONE unterdrückt reguläre Resultsets. Gültig sind ausschließlich RAW, CONSOLE, TABLE und NONE; NULL oder Leertext ist ungültig. CONSOLE und TABLE werden intern als NONE verarbeitet und anschließend über separate Helfer ausgegeben. JSON ist davon unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Optionales JSON-Mapping auf das lokale #temp-Ziel des einzigen TABLE-Resultsets counters. Nur bei ResultSetArt=TABLE zulässig; ein nichtleerer, getrimmter Wert in einer anderen Ausgabeart löst Fehler 51011 vor Hilfe- und Statusverarbeitung aus. NULL, leer oder nur Leerzeichen bedeutet kein Mapping. Der TABLE-Preflight läuft vor dem Hilfezweig und kann daher auch bei Hilfe scheitern.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter: 0 unterdrückt JSON, 1 erzeugt es; NULL aktiviert den Zweig nicht. Das Objekt enthält meta, counters und warnings; warnings ist ein leeres Array, counters unterliegt MaxZeilen. JSON kann mit jeder Ausgabeart erzeugt werden.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger vom Typ nvarchar(max). Der Eingabewert wird beim Eintritt auf NULL gesetzt, auch bei Hilfe. Mit JsonErzeugen=1 wird später JSON mit meta, counters und warnings zugewiesen; andernfalls bleibt der Wert NULL. Im EXEC mit einer nvarchar(max)-Variablen und OUTPUT binden.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit-Schalter: 0 unterdrückt Meldungen; 1 sendet bei StatusCode ungleich AVAILABLE eine Severity-10-Meldung mit RAISERROR ... WITH NOWAIT. NULL aktiviert die Meldung nicht. Der Text ist ErrorMessage oder ersatzweise der Statuscode. Die Meldung steuert die Resultsets nicht.';
        PRINT N'@Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Kurzinfos und kehrt vor dem Sampling sowie vor allen vier Status-OUTPUT-Zuweisungen zurück; NULL/0 führt regulär aus. Json wird zuvor bereits auf NULL gesetzt. Ein unzulässiges nichtleeres ResultTablesJson außerhalb TABLE sowie der TABLE-Preflight werden vor dem Hilfezweig verarbeitet.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40) mit globalem Status: AVAILABLE bei erfolgreichem Pfad; INVALID_PARAMETER bei ungültigen Listen-, Sample-, Zeilen- oder Ausgabeangaben; UNAVAILABLE_OBJECT ohne Counterzeilen oder nach Ausschluss nicht auswertbarer Basiscounter; DENIED_PERMISSION bei abgefangenen Fehlernummern 229, 262, 297, 300 oder 371; sonst ERROR_HANDLED. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit: 1 bei INVALID_PARAMETER, UNAVAILABLE_OBJECT oder abgefangenem Fehler, sonst 0. Das Flag beschreibt nur den vom Modul erkannten Partialzustand und beweist keine allgemeine Vollständigkeit. Hilfe lässt den Empfänger unverändert; mit OUTPUT binden.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int mit abgefangener SQL-Fehlernummer; im normalen Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorNumberOut=@Variable OUTPUT binden.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) mit Validierungs-/Unavailable-Text oder abgefangener ERROR_MESSAGE; im regulären AVAILABLE-Pfad NULL. Hilfe weist den Wert nicht zu und lässt den Empfänger unverändert. Mit @ErrorMessageOut=@Variable OUTPUT binden.';
        PRINT N'EXEC [monitor].[USP_PerformanceCounters] @ObjectNames=N''[SQL Statistics]'',@CounterNames=N''Batch Requests/sec'',@SampleSeconds=5,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max)=NULL; EXEC [monitor].[USP_PerformanceCounters] @JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@ResultSetArt=''NONE''; SELECT @ExampleJson;';
        PRINT N'DECLARE @ExampleMap nvarchar(max)=CONCAT(N''{'',NCHAR(34),N''counters'',NCHAR(34),N'':'',NCHAR(34),N''#PerformanceCounters_HelpExample'',NCHAR(34),N''}''); CREATE TABLE #PerformanceCounters_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PerformanceCounters] @ResultSetArt=''TABLE'',@ResultTablesJson=@ExampleMap; SELECT * FROM #PerformanceCounters_HelpExample; DROP TABLE #PerformanceCounters_HelpExample; END TRY BEGIN CATCH DROP TABLE IF EXISTS #PerformanceCounters_HelpExample; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_PerformanceCounters] @Hilfe=1;';




        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @SampleStartUtc datetime2(7) = SYSUTCDATETIME();
    DECLARE @SampleEndUtc datetime2(7);
    DECLARE @SqlServerStartTime datetime2(3);
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @MonitorPrintMessage nvarchar(2048) = NULL;
    DECLARE @Delay char(8);

    CREATE TABLE [#PerformanceCounters_Before]
    (
          [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterValue] bigint NOT NULL
        , [CounterType] int NOT NULL
        , PRIMARY KEY ([ObjectName], [CounterName], [InstanceName], [CounterType])
    );

    CREATE TABLE [#PerformanceCounters_After]
    (
          [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterValue] bigint NOT NULL
        , [CounterType] int NOT NULL
        , PRIMARY KEY ([ObjectName], [CounterName], [InstanceName], [CounterType])
    );

    CREATE TABLE [#PerformanceCounters_Result]
    (
          [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,6) NULL
        , [MetricUnit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [BeforeValue] bigint NULL
        , [AfterValue] bigint NOT NULL
        , [BaseBeforeValue] bigint NULL
        , [BaseAfterValue] bigint NULL
        , [DeltaValue] bigint NULL
        , [BaseDeltaValue] bigint NULL
        , [SampleSeconds] decimal(19,6) NULL
        , [SqlServerStartTime] datetime2(3) NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @MaxZeilen < 0
       OR @SampleSeconds > 60
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@ObjectNames IS NOT NULL AND EXISTS
          (SELECT 1 FROM [monitor].[TVF_ParseStringList](@ObjectNames) WHERE [IsValid] = 0))
       OR (@CounterNames IS NOT NULL AND EXISTS
          (SELECT 1 FROM [monitor].[TVF_ParseStringList](@CounterNames) WHERE [IsValid] = 0))
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER',
               @IsPartial = 1,
               @ErrorMessage = N'Ungültige Listen-, Sample-, Zeilen- oder Ausgabeparameter.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        SELECT @SqlServerStartTime = TRY_CONVERT(datetime2(3), [sqlserver_start_time])
        FROM [sys].[dm_os_sys_info] WITH (NOLOCK);

        INSERT [#PerformanceCounters_Before]
        SELECT DISTINCT RTRIM([object_name]), RTRIM([counter_name]), RTRIM([instance_name]), [cntr_value], [cntr_type]
        FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
        WHERE
            (@ObjectNames IS NULL OR EXISTS
             (
                 SELECT 1
                 FROM [monitor].[TVF_ParseStringList](@ObjectNames) AS [o]
                 WHERE [o].[IsValid] = 1
                   AND [o].[StringValue] COLLATE SQL_Latin1_General_CP1_CS_AS
                     = [object_name] COLLATE SQL_Latin1_General_CP1_CS_AS
             ))
        AND (@CounterNames IS NULL OR EXISTS
             (
                 SELECT 1
                 FROM [monitor].[TVF_ParseStringList](@CounterNames) AS [n]
                 WHERE [n].[IsValid] = 1
                   AND [n].[StringValue] COLLATE SQL_Latin1_General_CP1_CS_AS
                     = [counter_name] COLLATE SQL_Latin1_General_CP1_CS_AS
             )
             OR EXISTS
             (
                 SELECT 1
                 FROM [monitor].[TVF_ParseStringList](@CounterNames) AS [n]
                 WHERE [n].[IsValid] = 1
                   AND CONCAT([n].[StringValue], N' base') COLLATE SQL_Latin1_General_CP1_CI_AS
                     = RTRIM([counter_name]) COLLATE SQL_Latin1_General_CP1_CI_AS
             ));

        IF NOT EXISTS (SELECT 1 FROM [#PerformanceCounters_Before])
        BEGIN
            SELECT @StatusCode = 'UNAVAILABLE_OBJECT',
                   @IsPartial = 1,
                   @ErrorMessage = N'sys.dm_os_performance_counters liefert keine aktivierten Counter.';
        END;

        IF @SampleSeconds > 0
        BEGIN
            SET @Delay = CONVERT(char(8),
                DATEADD(SECOND, @SampleSeconds, CONVERT(time(0), '00:00:00')), 108);
            WAITFOR DELAY @Delay;
        END;

        SET @SampleEndUtc = SYSUTCDATETIME();

        INSERT [#PerformanceCounters_After]
        SELECT DISTINCT RTRIM([p].[object_name]), RTRIM([p].[counter_name]), RTRIM([p].[instance_name]),
               [p].[cntr_value], [p].[cntr_type]
        FROM [sys].[dm_os_performance_counters] AS [p] WITH (NOLOCK)
        JOIN [#PerformanceCounters_Before] AS [b]
         ON [b].[ObjectName] = [p].[object_name] COLLATE SQL_Latin1_General_CP1_CS_AS
         AND [b].[CounterName] = [p].[counter_name] COLLATE SQL_Latin1_General_CP1_CS_AS
         AND [b].[InstanceName] = [p].[instance_name] COLLATE SQL_Latin1_General_CP1_CS_AS
         AND [b].[CounterType] = [p].[cntr_type];

        INSERT [#PerformanceCounters_Result]
        SELECT
              [a].[ObjectName]
            , [a].[CounterName]
            , [a].[InstanceName]
            , [a].[CounterType]
            , [i].[Interpretation]
            , [i].[MetricValue]
            , [i].[MetricUnit]
            , [b].[CounterValue]
            , [a].[CounterValue]
            , [baseBefore].[CounterValue]
            , [baseAfter].[CounterValue]
            , TRY_CONVERT(bigint, CONVERT(decimal(38,0), [a].[CounterValue])
                                 - CONVERT(decimal(38,0), [b].[CounterValue]))
            , TRY_CONVERT(bigint, CONVERT(decimal(38,0), [baseAfter].[CounterValue])
                                 - CONVERT(decimal(38,0), [baseBefore].[CounterValue]))
            , CONVERT(decimal(19,6),
                DATEDIFF_BIG(MICROSECOND, @SampleStartUtc, @SampleEndUtc) / 1000000.0)
            , @SqlServerStartTime
            , [i].[FindingCode]
        FROM [#PerformanceCounters_After] AS [a]
        JOIN [#PerformanceCounters_Before] AS [b]
         ON [b].[ObjectName] = [a].[ObjectName]
         AND [b].[CounterName] = [a].[CounterName]
         AND [b].[InstanceName] = [a].[InstanceName]
         AND [b].[CounterType] = [a].[CounterType]
        LEFT JOIN [#PerformanceCounters_Before] AS [baseBefore]
          ON [baseBefore].[ObjectName] = [a].[ObjectName]
         AND [baseBefore].[InstanceName] = [a].[InstanceName]
         AND [baseBefore].[CounterName] COLLATE SQL_Latin1_General_CP1_CI_AS =
             CONVERT(nvarchar(128), CONCAT(RTRIM([a].[CounterName]), N' base'))
             COLLATE SQL_Latin1_General_CP1_CI_AS
         AND [baseBefore].[CounterType] IN (1073939458, 1073939712)
        LEFT JOIN [#PerformanceCounters_After] AS [baseAfter]
          ON [baseAfter].[ObjectName] = [a].[ObjectName]
         AND [baseAfter].[InstanceName] = [a].[InstanceName]
         AND [baseAfter].[CounterName] COLLATE SQL_Latin1_General_CP1_CI_AS =
             CONVERT(nvarchar(128), CONCAT(RTRIM([a].[CounterName]), N' base'))
             COLLATE SQL_Latin1_General_CP1_CI_AS
         AND [baseAfter].[CounterType] IN (1073939458, 1073939712)
        CROSS APPLY [monitor].[TVF_InterpretPerformanceCounter]
        (
              [a].[CounterType]
            , [b].[CounterValue]
            , [a].[CounterValue]
            , [baseBefore].[CounterValue]
            , [baseAfter].[CounterValue]
            , CASE WHEN @SampleSeconds = 0 THEN CONVERT(decimal(19,6), 0)
                   ELSE CONVERT(decimal(19,6),
                        DATEDIFF_BIG(MICROSECOND, @SampleStartUtc, @SampleEndUtc) / 1000000.0) END
        ) AS [i]
        WHERE [a].[CounterType] NOT IN (1073939458, 1073939712);

        IF NOT EXISTS (SELECT 1 FROM [#PerformanceCounters_Result])
        BEGIN
            SELECT @StatusCode = 'UNAVAILABLE_OBJECT',
                   @IsPartial = 1,
                   @ErrorMessage = N'Es stehen keine auswertbaren Performance-Counter-Zeilen bereit.';
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCode =
                   CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371)
                        THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartial = 1,
               @ErrorNumber = ERROR_NUMBER(),
               @ErrorMessage = ERROR_MESSAGE();
    END CATCH;

    SELECT @StatusCodeOut = @StatusCode,
           @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber,
           @ErrorMessageOut = @ErrorMessage;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = COALESCE(@ErrorMessage, CONVERT(nvarchar(2048), @StatusCode));
        RAISERROR(N'USP_PerformanceCounters: %s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT CAST('1.0' AS varchar(16)) AS [ContractVersion], @Now AS [CollectionTimeUtc],
               N'monitor.USP_PerformanceCounters' AS [ModuleName],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               @SampleStartUtc AS [SampleStartUtc], @SampleEndUtc AS [SampleEndUtc],
               @SqlServerStartTime AS [SqlServerStartTime];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit) *
            FROM [#PerformanceCounters_Result]
            ORDER BY [ObjectName], [CounterName], [InstanceName];
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'Performance Counter' AS [Ergebnis]
                , [ObjectName] AS [Objekt]
                , [CounterName] AS [Counter]
                , [InstanceName] AS [Instanz]
                , [MetricValue] AS [Wert]
                , [MetricUnit] AS [Einheit]
                , [Interpretation] AS [Interpretation]
                , [CounterType] AS [Countertyp]
                , [FindingCode] AS [Bewertung]
                , [SampleSeconds] AS [Sample Sekunden]
            FROM [#PerformanceCounters_Result]
            ORDER BY [ObjectName], [CounterName], [InstanceName];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT N'PerformanceCounters' AS [resultName], 1 AS [schemaVersion],
                   @Now AS [generatedAtUtc], @StatusCode AS [statusCode],
                   @IsPartial AS [isPartial], @SampleStartUtc AS [sampleStartUtc],
                   @SampleEndUtc AS [sampleEndUtc], @SqlServerStartTime AS [sqlServerStartTime],
                   @ErrorNumber AS [errorNumber], @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @CountersJson nvarchar(max) =
        (
            SELECT TOP (@Limit) *
            FROM [#PerformanceCounters_Result]
            ORDER BY [ObjectName], [CounterName], [InstanceName]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"counters":', COALESCE(@CountersJson, N'[]')
            , N',"warnings":[]}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#PerformanceCounters_Result'
            , @ResultLabel=N'PerformanceCounters'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#PerformanceCounters_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
