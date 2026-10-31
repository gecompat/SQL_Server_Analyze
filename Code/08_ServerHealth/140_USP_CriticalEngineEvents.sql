USE [DeineDatenbank];
GO

SET QUOTED_IDENTIFIER ON;
GO

/*
===============================================================================
Objekt       : monitor.USP_CriticalEngineEvents
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Liest begrenzte kritische Ereignisse aus vorhandenen
               XEL-Dateien der benannten Extended-Events-Session und optional
               einen einmaligen sys.sp_server_diagnostics-Snapshot.
Nebenwirkung : Keine XE- oder Serveränderung. Eventfiles werden nur gelesen.
               sp_server_diagnostics läuft ausschließlich als One-Shot.
Eigenlast    : Eventfile-Lesen MEDIUM und begrenzt; XML-Transfer opt-in.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CriticalEngineEvents]
      @SourceExtendedEventSessionName nvarchar(258) = N'system_health'
    , @FilePath                        nvarchar(4000) = NULL
    , @VonUtc                          datetime2(7)   = NULL
    , @BisUtc                          datetime2(7)   = NULL
    , @MinErrorSeverity                tinyint         = 20
    , @MitSystemHealth                 bit             = 1
    , @MitServerDiagnostics            bit             = 0
    , @MitEventXml                     bit             = 0
    , @MaxZeilen                       int             = 500
    , @ResultSetArt                    varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                    bit             = 0
    , @Json                            nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                  bit             = 1
    , @Hilfe                           bit             = 0
    , @StatusCodeOut                   varchar(40)     = NULL OUTPUT
    , @IsPartialOut                    bit             = NULL OUTPUT
    , @ErrorNumberOut                  int             = NULL OUTPUT
    , @ErrorMessageOut                 nvarchar(2048)  = NULL OUTPUT
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'events',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;
    DECLARE @SessionName sysname = NULL;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CriticalEngineEvents';
        PRINT N'Die Sessionangabe muss genau einen einteiligen SQL-Namen bezeichnen; die Procedure ändert keine XE-Session.';
        PRINT N'FilePath bezeichnet serverseitige XEL-Dateien; ohne Angabe wird das konfigurierte event_file-Target verwendet. Ringbuffer werden nicht gelesen.';
        PRINT N'UTC-Untergrenze inklusiv, Obergrenze exklusiv. Das Kandidatenlimit greift vor XML-Parsing und Severityfilter.';
        PRINT N'Severity filtert error_reported; ausgewählte Fehlernummern bleiben unabhängig von der Schwelle enthalten.';
        PRINT N'Server-Diagnostics läuft einmalig; vollständiges Event-XML ist Opt-in.';
        PRINT N'RAW liefert Status, Events, Diagnostics und SourceStatus; TABLE exportiert nur events.';
        PRINT N'@SourceExtendedEventSessionName nvarchar(258); Default: N''system_health''. Ein einzelner, einteiliger SQL-Name der Extended-Events-Session. monitor.TVF_ParseSqlNameList verarbeitet bracket-aware Pipe-Listen, äußerer Whitespace wird entfernt, ]] maskiert ], aber dieser Parameter akzeptiert genau einen gültigen Listeneintrag; multipart-Namen und Namen über 128 Zeichen sind ungültig. NULL, leere Eingabe, leere/fehlerhafte Elemente oder mehr als ein gültiger Name führen zu INVALID_PARAMETER. Der Default system_health wird durch die Procedure-Signatur gesetzt. Der Name wird für die Katalogsuche des event_file-Targets verwendet; die Procedure startet oder ändert die Session nicht.';
        PRINT N'@FilePath nvarchar(4000); Default: NULL. Optionaler serverseitiger Dateipfad oder XEL-Muster. NULL oder leerer String verwendet den im Katalog für die angegebene Session konfigurierten event_file-Dateinamen; der Eingabewert wird nicht mit LTRIM/RTRIM normalisiert. Ein Suffix .xel wird durch Basisname plus *.xel ersetzt (case-insensitiv); ohne * und ohne .xel wird *.xel angefügt; vorhandenes * bleibt erhalten. Ein expliziter Pfad ersetzt den konfigurierten Pfad und muss für den SQL-Server-Dienstprozess lesbar sein. Gelesen wird mit sys.fn_xe_file_target_read_file; kein Clientpfad und kein Ringbuffer-Fallback.';
        PRINT N'@VonUtc datetime2(7); Default: NULL. datetime2(7)-Zeitpunkt in UTC als inklusiver Unterrand: Eventzeitstempel müssen >= VonUtc sein. NULL lässt die Untergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von BisUtc vor XML-Parsing angewandt.';
        PRINT N'@BisUtc datetime2(7); Default: NULL. datetime2(7)-Zeitpunkt in UTC als exklusiver Oberrand: Eventzeitstempel müssen < BisUtc sein. NULL lässt die Obergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von VonUtc vor XML-Parsing angewandt. Sind beide gesetzt, muss VonUtc strikt kleiner sein.';
        PRINT N'@MinErrorSeverity tinyint; Default: 20. Severity-Schwelle 0 bis 25; tinyint lässt keine negativen Eingaben zu, Werte >25 sind INVALID_PARAMETER. Betrifft nur error_reported und wird nach dem TOP-Kandidatenset angewandt. Fehlernummern 701, 802, 823, 824, 825, 832, 833, 8645, 8651 und 17803 passieren unabhängig von der Severity. NULL umgeht die >25-Prüfung; der Severityvergleich ergibt UNKNOWN, sodass normale error_reported-Einträge entfallen und nur die Nummernausnahmen verbleiben. Andere ausgewählte Eventnamen werden nicht nach Severity gefiltert.';
        PRINT N'@MitSystemHealth bit; Default: 1. Bit-Schalter: 1 liest das vorhandene event_file-Target der benannten Session; 0 überspringt die XEL-Quelle. Es werden ausschließlich error_reported, scheduler_monitor_non_yielding_ring_buffer_recorded, scheduler_monitor_non_yielding_iocp_ring_buffer_recorded, scheduler_monitor_stalled_dispatcher_ring_buffer_recorded, sp_server_diagnostics_component_result, memory_broker_ring_buffer_recorded, resource_monitor_ring_buffer_recorded, connectivity_ring_buffer_recorded und xml_deadlock_report berücksichtigt. NULL aktiviert die Quelle nicht und ist nicht eigenständig ungültig. Keine XE-Änderung; kein Ringbuffer-Fallback. Sind beide Quellflags explizit 0, ist die Eingabe INVALID_PARAMETER. Sind Flags NULL/0, kann der Validierungsvergleich UNKNOWN sein und beide Quellen überspringen, während der globale Status AVAILABLE bleibt.';
        PRINT N'@MitServerDiagnostics bit; Default: 0. Bit-Schalter: 1 führt sys.sp_server_diagnostics 0 einmalig ohne Repeat-Modus aus; 0 überspringt die Quelle. NULL aktiviert sie nicht und ist nicht eigenständig ungültig. Vollständige Daten können laut SourceStatus mindestens fünf Sekunden benötigen. Der Aufruf bildet einen separaten aktuellen Snapshot und ist kein XEL-Ereignis.';
        PRINT N'@MitEventXml bit; Default: 0. Bit-Schalter: 1 gibt das vollständige EventXml und Diagnostics-Data aus (einschließlich JSON); 0 oder NULL liefert diese XML-Ausgabefelder als NULL. Event-XML wird für extrahierte Felder und Filter auch ohne Opt-in gelesen und geparst; Diagnostics Data wird durch den One-Shot geliefert, aber nur mit Opt-in ausgegeben. Das Flag reduziert vollständigen XML-Transfer, nicht Parsing oder MessageText (nvarchar(4000)). MessageText/EventXml können sensible Runtimeinhalte enthalten; es gibt keine Persistenz.';
        PRINT N'@MaxZeilen int; Default: 500. Nichtnegative int-Obergrenze. Werte <0 sind INVALID_PARAMETER. Werte 1..2147483647 begrenzen mit TOP das nach Zeit/Eventnamen gefilterte XEL-Kandidatenset, bevor XML extrahiert und Severity angewandt wird. 0 und NULL nutzen die größte bigint-TOP-Grenze. Sortiert wird nach Zeitstempel absteigend, Dateiname und Dateioffset absteigend. Das begrenzt weder das physische Lesen aller passenden Rolloverdateien noch ungefilterte Diagnostics-/SourceStatus-Zeilen; viele neuere Events können ältere relevante Fehler verdrängen.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach LTRIM/RTRIM und UPPER normalisierte Ausgabeart. RAW liefert Status und drei technische Resultsets: Events, Diagnostics, SourceStatus. CONSOLE wird intern NONE und danach über InternalEmitConsoleResult ausschließlich aus der Ereignistabelle gerendert; ein Status- oder Diagnostics-Resultset sowie der im Branch vorhandene CONSOLE-Formatierungszweig werden nicht ausgegeben. Leere Ereignisse erzeugen die Helper-Hinweiszeile. TABLE wird intern NONE und schreibt nur events in das lokale Ziel. NONE unterdrückt reguläre Resultsets. Zulässig: RAW, CONSOLE, TABLE, NONE; NULL/Leertext/andere Werte ergeben INVALID_PARAMETER. JSON kann unabhängig erstellt werden.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. TABLE-Aufrufe benötigen ein gültiges JSON-Objekt mit dem Schlüssel events und dem Wert eines bereits angelegten zulässigen lokalen #Temp-Ziels. Der Single-Result-Preflight läuft vor Hilfe und validiert Zuordnung und Ziel; NULL, leerer Text, ungültiges JSON oder fehlendes events-Mapping schlagen im TABLE-Modus fehl. Außerhalb TABLE ist NULL/leer zulässig; ein nichtleerer Wert löst wegen der Caller-Prüfung Fehler 51011 aus.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit: 0 unterdrückt JSON, 1 erstellt es; NULL aktiviert den IF-Zweig nicht. JSON-Gruppen: meta, events, serverDiagnostics, sources und warnings (leeres Array). Events und Diagnostics stammen aus denselben materialisierten Tabellen wie übrige Ausgaben; der Eventkandidatensatz ist bereits durch MaxZeilen begrenzt.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), beim Eintritt auf NULL gesetzt. Mit JsonErzeugen=1 wird später das JSON-Objekt meta/events/serverDiagnostics/sources/warnings zugewiesen, sonst bleibt NULL. Hilfe kehrt nach dem Reset zurück. EXEC mit nvarchar(max)-Empfängervariable und OUTPUT binden.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit: 0 unterdrückt Meldungen, 1 sendet bei globalem Status ungleich AVAILABLE eine Severity-10-RAISERROR-Meldung WITH NOWAIT. NULL aktiviert die IF nicht. Da Quellenfehler im SourceStatus protokolliert werden, während globale ErrorMessage NULL bleiben kann, meldet dieser Pfad dann den globalen Statuscode. JSON/Resultsets bleiben unabhängig.';
        PRINT N'@Hilfe bit; Default: 0. Bit: 1 druckt Kurzinfos und kehrt vor Sessionparser, Quellenzugriff und Status-OUTPUT-Zuweisungen zurück; NULL/0 läuft regulär. @Json wurde beim Eintritt bereits auf NULL gesetzt. Ungültiges ResultTablesJson außerhalb TABLE sowie TABLE-Preflight werden vorher ausgeführt.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40) mit globalem Status: INVALID_PARAMETER bei ungültiger Session/Zeit/Severity/Quell-/Ausgabeangabe; AVAILABLE_LIMITED bei markierter Teilquelle oder SourceStatus ungleich AVAILABLE; AVAILABLE_WITH_FINDING wenn Events vorhanden und keine Teilquelle gemeldet ist; sonst AVAILABLE. Per-source Codes: UNAVAILABLE_OBJECT bei fehlendem Dateipfad; AVAILABLE bei erfolgreicher Quelle; DENIED_PERMISSION für SQL-Fehler 229/262/297/300/371; XML_UNAVAILABLE_LIMIT für 6335/6336/6337; XML_INVALID für 9400..9431; ERROR_HANDLED für sonstige Quellfehler (Diagnostics nutzt DENIED_PERMISSION oder ERROR_HANDLED). Quellenfehler bleiben im SourceStatus und setzen nicht notwendigerweise globale ErrorNumber/ErrorMessage. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit: 1 bei ungültigen Eingaben oder markierten/fehlgeschlagenen Teilquellen; sonst 0. 0 beweist nicht, dass system_health-Retention oder Eventauswahl vollständig ist. Teilquellenfehler führen global zu AVAILABLE_LIMITED. Hilfe lässt Empfänger unverändert; mit OUTPUT binden.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int für einen global gesetzten Fehler; im Quellen-CATCH werden Fehlernummern stattdessen je Quelle in SourceStatus erfasst, daher kann dieser Empfänger NULL bleiben. Hilfe weist ihn nicht zu. Mit @ErrorNumberOut=@Variable OUTPUT binden.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) für globale Validierungs-/Fehlermeldung. Fehlertexte einzelner XEL-/Diagnostics-Quellen stehen im SourceStatus und setzen diesen Wert nicht zwingend; dann bleibt er NULL. Hilfe weist ihn nicht zu. Mit @ErrorMessageOut=@Variable OUTPUT binden.';
        PRINT N'DECLARE @ExampleFromUtc datetime2(7)=DATEADD(HOUR,-24,SYSUTCDATETIME()); EXEC [monitor].[USP_CriticalEngineEvents] @VonUtc=@ExampleFromUtc,@MaxZeilen=100,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @ExampleJson nvarchar(max)=NULL; EXEC [monitor].[USP_CriticalEngineEvents] @JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@ResultSetArt=''NONE''; SELECT @ExampleJson;';
        PRINT N'DECLARE @ExampleEventsMap nvarchar(max)=CONCAT(N''{'',NCHAR(34),N''events'',NCHAR(34),N'':'',NCHAR(34),N''#CriticalEngineEvents_HelpExample'',NCHAR(34),N''}''); CREATE TABLE #CriticalEngineEvents_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_CriticalEngineEvents] @ResultSetArt=''TABLE'',@ResultTablesJson=@ExampleEventsMap; SELECT * FROM #CriticalEngineEvents_HelpExample; DROP TABLE #CriticalEngineEvents_HelpExample; END TRY BEGIN CATCH IF OBJECT_ID(N''tempdb..#CriticalEngineEvents_HelpExample'') IS NOT NULL DROP TABLE #CriticalEngineEvents_HelpExample; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_CriticalEngineEvents] @Hilfe=1;';




        RETURN;
    END;

    IF @SourceExtendedEventSessionName IS NOT NULL
       AND (SELECT COUNT_BIG(*)
            FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName)
            WHERE [IsValid] = 1) = 1
       AND NOT EXISTS
           (SELECT 1
            FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName)
            WHERE [IsValid] = 0)
        SELECT @SessionName = MIN([NameValue])
        FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName)
        WHERE [IsValid] = 1;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @MonitorPrintMessage nvarchar(2048) = NULL;
    DECLARE @ConfiguredFilePath nvarchar(4000) = NULL;
    DECLARE @ResolvedFilePath nvarchar(4000) = NULL;

    CREATE TABLE [#CriticalEngineEvents_Events]
    (
          [TimestampUtc] datetime2(7) NULL
        , [EventName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ErrorNumber] int NULL
        , [Severity] int NULL
        , [ComponentName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StateDesc] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MessageText] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EventXml] xml NULL
    );

    CREATE TABLE [#CriticalEngineEvents_Diagnostics]
    (
          [CreateTime] datetime NULL
        , [ComponentType] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ComponentName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [State] int NULL
        , [StateDesc] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Data] xml NULL
    );

    CREATE TABLE [#CriticalEngineEvents_SourceStatus]
    (
          [SourceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @SessionName IS NULL
       OR @MaxZeilen < 0
       OR @MinErrorSeverity > 25
       OR (@VonUtc IS NOT NULL AND @BisUtc IS NOT NULL AND @VonUtc >= @BisUtc)
       OR (@MitSystemHealth = 0 AND @MitServerDiagnostics = 0)
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER',
               @IsPartial = 1,
               @ErrorMessage = N'Ungültige Session-, Zeit-, Severity-, Modul-, Zeilen- oder Ausgabeparameter.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE' AND @MitSystemHealth = 1
    BEGIN
        BEGIN TRY
            SELECT @ConfiguredFilePath = MAX(CONVERT(nvarchar(4000), [f].[value]))
            FROM [sys].[server_event_sessions] AS [s] WITH (NOLOCK)
            JOIN [sys].[server_event_session_targets] AS [t] WITH (NOLOCK)
              ON [t].[event_session_id] = [s].[event_session_id]
             AND [t].[name] = N'event_file'
            LEFT JOIN [sys].[server_event_session_fields] AS [f] WITH (NOLOCK)
              ON [f].[event_session_id] = [t].[event_session_id]
             AND [f].[object_id] = [t].[target_id]
             AND [f].[name] = N'filename'
            WHERE [s].[name] = @SessionName;

            SET @ResolvedFilePath = COALESCE(NULLIF(@FilePath, N''), NULLIF(@ConfiguredFilePath, N''));

            IF @ResolvedFilePath IS NULL
            BEGIN
                SET @IsPartial = 1;
                INSERT [#CriticalEngineEvents_SourceStatus]
                VALUES
                (
                      N'system_health event_file', 'UNAVAILABLE_OBJECT', NULL, NULL
                    , N'Kein lesbarer event_file-Pfad vorhanden; es wurde kein Ringbuffer gelesen.'
                );
            END
            ELSE
            BEGIN
                IF RIGHT(LOWER(@ResolvedFilePath), 4) = N'.xel'
                    SET @ResolvedFilePath =
                        LEFT(@ResolvedFilePath, LEN(@ResolvedFilePath) - 4) + N'*.xel';
                ELSE IF CHARINDEX(N'*', @ResolvedFilePath) = 0
                    SET @ResolvedFilePath = @ResolvedFilePath + N'*.xel';

                ;WITH [RawEvents] AS
                (
                    SELECT TOP (@Limit)
                          [r].[timestamp_utc] AS [TimestampUtc]
                        , [r].[object_name] AS [EventName]
                        , CONVERT(xml, [r].[event_data]) AS [EventXml]
                    FROM [sys].[fn_xe_file_target_read_file]
                         (@ResolvedFilePath, NULL, NULL, NULL) AS [r]
                    WHERE [r].[object_name] IN
                    (
                          N'error_reported'
                        , N'scheduler_monitor_non_yielding_ring_buffer_recorded'
                        , N'scheduler_monitor_non_yielding_iocp_ring_buffer_recorded'
                        , N'scheduler_monitor_stalled_dispatcher_ring_buffer_recorded'
                        , N'sp_server_diagnostics_component_result'
                        , N'memory_broker_ring_buffer_recorded'
                        , N'resource_monitor_ring_buffer_recorded'
                        , N'connectivity_ring_buffer_recorded'
                        , N'xml_deadlock_report'
                    )
                      AND (@VonUtc IS NULL OR [r].[timestamp_utc] >= @VonUtc)
                      AND (@BisUtc IS NULL OR [r].[timestamp_utc] < @BisUtc)
                    ORDER BY [r].[timestamp_utc] DESC, [r].[file_name] DESC, [r].[file_offset] DESC
                ),
                [Parsed] AS
                (
                    SELECT
                          [TimestampUtc], [EventName], [EventXml]
                        , [EventXml].value('(event/data[@name="error_number"]/value/text())[1]', 'int') AS [ErrorNumber]
                        , [EventXml].value('(event/data[@name="severity"]/value/text())[1]', 'int') AS [Severity]
                        , [EventXml].value('(event/data[@name="component_name"]/value/text())[1]', 'sysname') AS [ComponentName]
                        , [EventXml].value('(event/data[@name="state_desc"]/value/text())[1]', 'sysname') AS [StateDesc]
                        , [EventXml].value('(event/data[@name="message"]/value/text())[1]', 'nvarchar(4000)') AS [MessageText]
                    FROM [RawEvents]
                    WHERE [EventXml] IS NOT NULL
                )
                INSERT [#CriticalEngineEvents_Events]
                SELECT
                      [TimestampUtc], [EventName], [ErrorNumber], [Severity]
                    , [ComponentName], [StateDesc], [MessageText]
                    , CASE
                          WHEN [EventName] LIKE N'scheduler_monitor_non_yielding%' THEN 'NON_YIELDING_SCHEDULER'
                          WHEN [EventName] = N'scheduler_monitor_stalled_dispatcher_ring_buffer_recorded' THEN 'STALLED_DISPATCHER'
                          WHEN [EventName] = N'error_reported' THEN 'SEVERE_ERROR_REPORTED'
                          WHEN [EventName] = N'sp_server_diagnostics_component_result'
                           AND LOWER(COALESCE([StateDesc], N'')) IN (N'warning', N'error')
                              THEN 'SERVER_DIAGNOSTICS_WARNING_OR_ERROR'
                          WHEN [EventName] IN
                               (N'memory_broker_ring_buffer_recorded', N'resource_monitor_ring_buffer_recorded')
                              THEN 'MEMORY_OR_RESOURCE_MONITOR_EVENT'
                          WHEN [EventName] = N'connectivity_ring_buffer_recorded' THEN 'CONNECTIVITY_EVENT'
                          WHEN [EventName] = N'xml_deadlock_report' THEN 'DEADLOCK_EVENT'
                          ELSE 'CRITICAL_EVENT_REVIEW'
                      END
                    , CASE WHEN @MitEventXml = 1 THEN [EventXml] END
                FROM [Parsed]
                WHERE [EventName] <> N'error_reported'
                   OR COALESCE([Severity], 0) >= @MinErrorSeverity
                   OR [ErrorNumber] IN (701, 802, 823, 824, 825, 832, 833, 8645, 8651, 17803);

                INSERT [#CriticalEngineEvents_SourceStatus]
                VALUES
                (
                      N'system_health event_file', 'AVAILABLE', NULL, NULL
                    , N'Vorhandene Eventfiles wurden begrenzt und rein lesend ausgewertet.'
                );
            END;
        END TRY
        BEGIN CATCH
            SET @IsPartial = 1;
            INSERT [#CriticalEngineEvents_SourceStatus]
            VALUES
            (
                  N'system_health event_file'
                , CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371) THEN 'DENIED_PERMISSION'
                       WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT'
                       WHEN ERROR_NUMBER() BETWEEN 9400 AND 9431 THEN 'XML_INVALID'
                       ELSE 'ERROR_HANDLED' END
                , ERROR_NUMBER(), ERROR_MESSAGE()
                , N'Das Eventfile konnte nicht ausgewertet werden; andere Quellen bleiben verfügbar.'
            );
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitServerDiagnostics = 1
    BEGIN
        BEGIN TRY
            INSERT [#CriticalEngineEvents_Diagnostics]
            EXEC [sys].[sp_server_diagnostics] 0;

            INSERT [#CriticalEngineEvents_SourceStatus]
            VALUES
            (
                  N'sp_server_diagnostics', 'AVAILABLE', NULL, NULL
                , N'One-Shot-Aufruf ohne Repeat-Modus; vollständige Daten können mindestens fünf Sekunden benötigen.'
            );
        END TRY
        BEGIN CATCH
            SET @IsPartial = 1;
            INSERT [#CriticalEngineEvents_SourceStatus]
            VALUES
            (
                  N'sp_server_diagnostics'
                , CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371)
                       THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
                , ERROR_NUMBER(), ERROR_MESSAGE()
                , N'One-Shot-Diagnose nicht verfügbar; kein Wiederholungsmodus gestartet.'
            );
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND (@IsPartial = 1 OR EXISTS
           (SELECT 1 FROM [#CriticalEngineEvents_SourceStatus] WHERE [StatusCode] <> 'AVAILABLE'))
        SET @StatusCode = 'AVAILABLE_LIMITED';
    ELSE IF @StatusCode = 'AVAILABLE'
        AND EXISTS (SELECT 1 FROM [#CriticalEngineEvents_Events])
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    SELECT @StatusCodeOut = @StatusCode,
           @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber,
           @ErrorMessageOut = @ErrorMessage;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = COALESCE(@ErrorMessage, CONVERT(nvarchar(2048), @StatusCode));
        RAISERROR(N'USP_CriticalEngineEvents: %s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT CAST('1.0' AS varchar(16)) AS [ContractVersion], @Now AS [CollectionTimeUtc],
               N'monitor.USP_CriticalEngineEvents' AS [ModuleName],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#CriticalEngineEvents_Events] ORDER BY [TimestampUtc] DESC, [EventName];
            SELECT * FROM [#CriticalEngineEvents_Diagnostics] ORDER BY [CreateTime], [ComponentName];
            SELECT * FROM [#CriticalEngineEvents_SourceStatus] ORDER BY [SourceName];
        END
        ELSE
        BEGIN
            SELECT
                  N'Kritisches Engine-Ereignis' AS [Ergebnis]
                , [TimestampUtc] AS [Zeit UTC]
                , [FindingCode] AS [Bewertung]
                , [EventName] AS [Event]
                , [ErrorNumber] AS [Fehlernummer]
                , [Severity] AS [Severity]
                , [ComponentName] AS [Komponente]
                , [StateDesc] AS [Zustand]
                , [MessageText] AS [Meldung]
                , [EventXml] AS [Event XML]
            FROM [#CriticalEngineEvents_Events]
            ORDER BY [TimestampUtc] DESC, [EventName];

            SELECT
                  N'Server Diagnostics' AS [Ergebnis]
                , [CreateTime] AS [Zeit]
                , [ComponentType] AS [Komponententyp]
                , [ComponentName] AS [Komponente]
                , [StateDesc] AS [Zustand]
                , CASE WHEN @MitEventXml = 1 THEN [Data] END AS [Daten XML]
            FROM [#CriticalEngineEvents_Diagnostics]
            ORDER BY [CreateTime], [ComponentName];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT N'CriticalEngineEvents' AS [resultName], 1 AS [schemaVersion],
                   @Now AS [generatedAtUtc], @StatusCode AS [statusCode],
                   @IsPartial AS [isPartial], @ErrorNumber AS [errorNumber],
                   @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @EventsJson nvarchar(max) =
            (SELECT * FROM [#CriticalEngineEvents_Events] ORDER BY [TimestampUtc] DESC FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @DiagnosticsJson nvarchar(max) =
            (SELECT [CreateTime], [ComponentType], [ComponentName], [State], [StateDesc],
                    CASE WHEN @MitEventXml = 1 THEN [Data] END AS [Data]
             FROM [#CriticalEngineEvents_Diagnostics] ORDER BY [CreateTime], [ComponentName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SourcesJson nvarchar(max) =
            (SELECT * FROM [#CriticalEngineEvents_SourceStatus] ORDER BY [SourceName] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"events":', COALESCE(@EventsJson, N'[]')
            , N',"serverDiagnostics":', COALESCE(@DiagnosticsJson, N'[]')
            , N',"sources":', COALESCE(@SourcesJson, N'[]')
            , N',"warnings":[]}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CriticalEngineEvents_Events'
            , @ResultLabel=N'CriticalEngineEvents'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CriticalEngineEvents_Events'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
