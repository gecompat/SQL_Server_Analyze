USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ExtendedEventsAnalysis
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Orchestriert Extended-Events-Inventar und Forensik mit
               einheitlichem Ausgabe- und Namensvertrag.
Änderungen   : 2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ExtendedEventsAnalysis]
      @SourceExtendedEventSessionName nvarchar(258)  = N'system_health'
    , @ExtendedEventSessionNames       nvarchar(max)  = NULL
    , @ExtendedEventSessionNamePattern nvarchar(4000) = NULL
    , @EventNames                      nvarchar(max)  = NULL
    , @EventNamePattern                nvarchar(4000) = NULL
    , @TargetNames                     nvarchar(max)  = NULL
    , @TargetNamePattern               nvarchar(4000) = NULL
    , @Quelle                          varchar(20)    = 'AUTO'
    , @FilePath                        nvarchar(4000) = NULL
    , @VonUtc                          datetime2(7)   = NULL
    , @BisUtc                          datetime2(7)   = NULL
    , @MitSessionInventar              bit            = 1
    , @MitTargetRuntime                bit            = 0
    , @MitEvents                       bit            = 0
    , @MitDeadlocks                    bit            = 0
    , @MitBlockedProcesses             bit            = 0
    , @MaxZeilen                       int            = 100
    , @BestaetigeTargetFlush           bit            = 0
    , @HighImpactConfirmed             bit            = 0
    , @ResultSetArt                    varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                    bit            = 0
    , @Json                            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                  bit            = 1
    , @Hilfe                           bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    CREATE TABLE [#ExtendedEventsAnalysis_MonitorTableResult]
    (
          [ExecutionOrdinal] tinyint NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    SET LOCK_TIMEOUT 0;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'moduleStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Source varchar(20) = UPPER(LTRIM(RTRIM(COALESCE(@Quelle, ''))));
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @InventoryJson nvarchar(max);
    DECLARE @TargetJson nvarchar(max);
    DECLARE @EventsJson nvarchar(max);
    DECLARE @DeadlocksJson nvarchar(max);
    DECLARE @BlockedJson nvarchar(max);

    DECLARE @ModuleStatus TABLE
    (
          [ExecutionOrdinal] tinyint        NOT NULL
        , [ModuleName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [ErrorNumber]      int            NULL
        , [ErrorMessage]     nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ExtendedEventsAnalysis';
        PRINT N'@SourceExtendedEventSessionName nvarchar(258). Default ist N''system_health''. Einzelner Forensik-Quell-Sessionsname, Standard system_health. Nur an aktivierte ReadEvents-, Deadlocks- und BlockedProcesses-Children; nicht an Inventar-Children. ReadEvents und Deadlocks lehnen NULL/leeren/ungültigen/mehrteiligen Namen ab. BlockedProcesses verwendet NULL zur automatischen Auswahl und lehnt leere/ungültige explizite Namen ab.';
        PRINT N'@ExtendedEventSessionNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit ExtendedEventSessionNamePattern. Wird an Sessions- und TargetRuntime-Children geleitet.';
        PRINT N'@ExtendedEventSessionNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres LIKE-Muster, optional mit LIKE:, REGEX: oder REGEXI:; äußere Leerzeichen werden entfernt. Leeres Muster oder leerer Präfixwert ist ungültig. LIKE unterstützt % und _. Regex benötigt SQL Server 2025 mit Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit ExtendedEventSessionNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet.';
        PRINT N'@EventNames nvarchar(max). Default ist NULL. NULL deaktiviert den exakten Eventnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; leere Liste/ungültige Namen werden abgelehnt. Nicht mit EventNamePattern kombinierbar. Wird an Sessions- und ReadEvents-Children geleitet.';
        PRINT N'@EventNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster/Präfixwert ungültig. LIKE unterstützt % und _. Regex erfordert SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit EventNames kombinierbar.';
        PRINT N'@TargetNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Sonst pipe-getrennte Liste exakter einteiliger SQL-Namen; Klammerung und ]] Escape unterstützt. Leere Liste/ungültige Namen ungültig. Nicht kombinierbar mit TargetNamePattern. Wird an Sessions-/TargetRuntime-Children geleitet.';
        PRINT N'@TargetNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster oder leerer Präfixwert ungültig. LIKE verwendet % und _. Regex benötigt SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit TargetNames kombinierbar. Wird an Sessions-/TargetRuntime-Children geleitet.';
        PRINT N'@Quelle varchar(20). Default ist ''AUTO''. Getrimmt/großgeschrieben; zulässig AUTO, EVENT_FILE, RING_BUFFER. Quellwahl für Forensik-Children.';
        PRINT N'@FilePath nvarchar(4000). Default ist NULL. Optionaler XEL-Dateipfad, an aktivierte Forensik-Children geleitet; NULL überlässt Pfadauswahl dem Child. Leerverhalten childabhängig.';
        PRINT N'@VonUtc datetime2(7). Default ist NULL. Unverändert an ReadEvents, Deadlocks und BlockedProcesses geleitet. ReadEvents: NULL lässt untere inklusive Grenze aus. Deadlocks/BlockedProcesses: NULL bedeutet UTC jetzt minus 24 Stunden.';
        PRINT N'@BisUtc datetime2(7). Default ist NULL. Unverändert an die aktivierten Forensik-Children geleitet. NULL lässt die exklusive obere Grenze aus.';
        PRINT N'@MitSessionInventar bit. Default ist 1. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsSessions mit Session-, Event- und Targetfiltern sowie MaxZeilen auf; SourceExtendedEventSessionName wird nicht weitergeleitet.';
        PRINT N'@MitTargetRuntime bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsTargetRuntime mit Session- und Targetfiltern auf. Das DMV-Lesen verlangt Flushbestätigung 1 und das Deep-Analysis-Gate.';
        PRINT N'@MitEvents bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsReadEvents auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, Eventfilter, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.';
        PRINT N'@MitDeadlocks bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsDeadlocks auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.';
        PRINT N'@MitBlockedProcesses bit. Default ist 0. Eingabe als bit-Wert 0 oder 1. Andere SQL-Argumente unterliegen vor Prozedureintritt der bit-Typkonvertierung; die Procedure besitzt keine eigene Leertextnormalisierung. 0 deaktiviert das Teilmodul. NULL aktiviert es nicht und wird nicht normalisiert. Die Leerscope-Prüfung lehnt nur fünf exakte 0-Werte ab. Enthält eine sonst inaktive Auswahl NULL, kann der Parent AVAILABLE ohne Kindaufruf liefern. 1 ruft USP_ExtendedEventsBlockedProcesses auf und leitet SourceExtendedEventSessionName, Quelle, FilePath, UTC-Grenzen, MaxZeilen sowie BestaetigeTargetFlush und HighImpactConfirmed weiter.';
        PRINT N'@MaxZeilen int. Default ist 100. Negative Werte ungültig. An Children weitergeleitet; NULL oder 0 bedeutet dort unbegrenzt. Ein Zeilenlimit garantiert kein vorzeitiges oder vollständiges Überspringen des physischen XEL-Lesens. Modulstatus wird nicht gekürzt.';
        PRINT N'@BestaetigeTargetFlush bit. Default ist 0. Explizit 0 oder 1 übergeben; nicht NULL. An Children geleitet. 1 nur nach bewusster Bestätigung setzen, weil Targetzugriffe einen Flush auslösen können.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. An aktivierte Forensikchildren und TargetRuntime geleitete Policybestätigung für Deep-Analysis.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Getrimmt/großgeschrieben; zulässig RAW, CONSOLE, NONE, TABLE. TABLE schreibt moduleStatus; CONSOLE/TABLE unterdrücken Child-Resultsets intern.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Nur mit TABLE. Nichtleeres JSON-Objekt mit genau dem Schlüssel moduleStatus und dem Namen einer vorhandenen, leeren lokalen #temp-Tabelle mit genau einer NULL-zulässigen Seed-Spalte. NULL/Leerwert, fehlerhafte Zuordnung, Zusatzschlüssel, befülltes Ziel, globale/permanente Tabelle und #Monitor-Präfix werden abgelehnt.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt Parent-JSON-Hülle mit meta, inventory, targetRuntime, events, deadlocks, blockedProcesses und warnings; 0 lässt @Json NULL.';
        PRINT N'@Json nvarchar(max). Default ist NULL. OUTPUT, wird anfangs NULL gesetzt; enthält bei JsonErzeugen=1 die Parent-JSON-Hülle.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 aktiviert Child-/Parent-Warnmeldungen; 0 unterdrückt sie.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt Kurzhilfe und kehrt vor Ausführung zurück.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ExtendedEventsAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ExtendedEventsAnalysis] @ExtendedEventSessionNames=N''ExampleXeSession'', @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @xeFrom datetime2(7)=DATEADD(hour,-1,SYSUTCDATETIME()), @xeTo datetime2(7)=SYSUTCDATETIME(), @xeJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsAnalysis] @SourceExtendedEventSessionName=N''ExampleXeSession'', @Quelle=''AUTO'', @VonUtc=@xeFrom, @BisUtc=@xeTo, @MitSessionInventar=0, @MitEvents=1, @MaxZeilen=50, @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@xeJson OUTPUT; SELECT @xeJson AS JsonResult;';
        PRINT N'Beispiel 4: CREATE TABLE #ExtendedEventsAnalysis_HelpExample (Seed int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsAnalysis] @MitSessionInventar=1, @MitTargetRuntime=0, @MitEvents=0, @MitDeadlocks=0, @MitBlockedProcesses=0, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"moduleStatus":"#ExtendedEventsAnalysis_HelpExample"}''; SELECT * FROM #ExtendedEventsAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsAnalysis_HelpExample; THROW; END CATCH; DROP TABLE #ExtendedEventsAnalysis_HelpExample;';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @Source NOT IN ('AUTO', 'EVENT_FILE', 'RING_BUFFER')
       OR (@VonUtc IS NOT NULL AND @BisUtc IS NOT NULL AND @VonUtc > @BisUtc)
       OR (@MitSessionInventar = 0 AND @MitTargetRuntime = 0 AND @MitEvents = 0
           AND @MitDeadlocks = 0 AND @MitBlockedProcesses = 0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitSessionInventar = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ExtendedEventsSessions]
                  @ExtendedEventSessionNames = @ExtendedEventSessionNames
                , @ExtendedEventSessionNamePattern = @ExtendedEventSessionNamePattern
                , @EventNames = @EventNames
                , @EventNamePattern = @EventNamePattern
                , @TargetNames = @TargetNames
                , @TargetNamePattern = @TargetNamePattern
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @InventoryJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (1, N'USP_ExtendedEventsSessions', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (1, N'USP_ExtendedEventsSessions', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitTargetRuntime = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ExtendedEventsTargetRuntime]
                  @ExtendedEventSessionNames = @ExtendedEventSessionNames
                , @ExtendedEventSessionNamePattern = @ExtendedEventSessionNamePattern
                , @TargetNames = @TargetNames
                , @TargetNamePattern = @TargetNamePattern
                , @BestaetigeTargetFlush = @BestaetigeTargetFlush
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @TargetJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (2, N'USP_ExtendedEventsTargetRuntime', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (2, N'USP_ExtendedEventsTargetRuntime', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitEvents = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ExtendedEventsReadEvents]
                  @SourceExtendedEventSessionName = @SourceExtendedEventSessionName
                , @Quelle = @Source
                , @FilePath = @FilePath
                , @EventNames = @EventNames
                , @EventNamePattern = @EventNamePattern
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc
                , @MaxZeilen = @MaxZeilen
                , @BestaetigeTargetFlush = @BestaetigeTargetFlush
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @EventsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (3, N'USP_ExtendedEventsReadEvents', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (3, N'USP_ExtendedEventsReadEvents', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitDeadlocks = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ExtendedEventsDeadlocks]
                  @SourceExtendedEventSessionName = @SourceExtendedEventSessionName
                , @Quelle = @Source
                , @FilePath = @FilePath
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc
                , @MaxZeilen = @MaxZeilen
                , @BestaetigeTargetFlush = @BestaetigeTargetFlush
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @DeadlocksJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (4, N'USP_ExtendedEventsDeadlocks', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (4, N'USP_ExtendedEventsDeadlocks', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitBlockedProcesses = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_ExtendedEventsBlockedProcesses]
                  @SourceExtendedEventSessionName = @SourceExtendedEventSessionName
                , @Quelle = @Source
                , @FilePath = @FilePath
                , @VonUtc = @VonUtc
                , @BisUtc = @BisUtc
                , @MaxZeilen = @MaxZeilen
                , @BestaetigeTargetFlush = @BestaetigeTargetFlush
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @BlockedJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @ModuleStatus VALUES (5, N'USP_ExtendedEventsBlockedProcesses', 'EXECUTED', NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (5, N'USP_ExtendedEventsBlockedProcesses', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF EXISTS (SELECT 1 FROM @ModuleStatus WHERE [InvocationStatus] <> 'EXECUTED')
       AND @StatusCode = 'AVAILABLE'
    BEGIN
        SET @StatusCode = 'AVAILABLE_LIMITED';
    END;

    INSERT [#ExtendedEventsAnalysis_MonitorTableResult]
        ([ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage])
    SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage]
    FROM @ModuleStatus;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_ExtendedEventsAnalysis' AS [ModuleName]
            , @Now                         AS [CollectionTimeUtc]
            , @StatusCode                  AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , (SELECT COUNT_BIG(*) FROM [#ExtendedEventsAnalysis_MonitorTableResult]) AS [ModuleCount];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#ExtendedEventsAnalysis_MonitorTableResult] ORDER BY [ExecutionOrdinal];
        END
        ELSE
        BEGIN
            SELECT
                  N'Extended-Events Teilmodul' AS [Ergebnis]
                , [ExecutionOrdinal]           AS [Reihenfolge]
                , [ModuleName]                 AS [Modul]
                , [InvocationStatus]           AS [Status]
                , [ErrorMessage]               AS [Fehler]
            FROM [#ExtendedEventsAnalysis_MonitorTableResult]
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
                  N'ExtendedEventsAnalysis' AS [resultName]
                , 1                         AS [schemaVersion]
                , @Now                      AS [generatedAtUtc]
                , @StatusCode               AS [statusCode]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @Warnings =
        (
            SELECT *
            FROM [#ExtendedEventsAnalysis_MonitorTableResult]
            WHERE [InvocationStatus] <> 'EXECUTED'
            ORDER BY [ExecutionOrdinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@Meta, N'{}')
            , N',"inventory":', COALESCE(JSON_QUERY(@InventoryJson), N'null')
            , N',"targetRuntime":', COALESCE(JSON_QUERY(@TargetJson), N'null')
            , N',"events":', COALESCE(JSON_QUERY(@EventsJson), N'null')
            , N',"deadlocks":', COALESCE(JSON_QUERY(@DeadlocksJson), N'null')
            , N',"blockedProcesses":', COALESCE(JSON_QUERY(@BlockedJson), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExtendedEventsAnalysis_MonitorTableResult'
            , @ResultLabel=N'ExtendedEventsAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ExtendedEventsAnalysis_MonitorTableResult'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
