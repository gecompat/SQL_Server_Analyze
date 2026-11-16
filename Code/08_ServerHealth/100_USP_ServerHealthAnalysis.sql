USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerHealthAnalysis
Version      : 3.2.0
Stand        : 2026-07-19
Zweck        : Orchestriert alle Server-Health-Module. RAW reicht Child-Resultsets
               durch; CONSOLE zeigt die beschriftete Modulstatusliste.
               TABLE schreibt ausschließlich moduleStatus; NONE unterdrückt Resultsets.
               Optionales JSON enthält benannte Modulobjekte.
Änderungen   : 3.2.0 - Bereits erhobene Integritäts-, Kapazitäts- und
                         Buffer-Pool-Ergebnisse im Findings-Child wiederverwendet.
               3.1.0 - Spezialfallmodule und normalisierte Befunde als opt-in.
               3.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert;
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
    , @MitIntegritaet   bit           = 0
    , @MitKapazitaet    bit           = 0
    , @MitPerformanceCounters bit      = 0
    , @MitCriticalEvents bit           = 0
    , @MitContention    bit           = 0
    , @MitBufferPool    bit           = 0
    , @MitFindings      bit           = 0
    , @DatabaseNames    nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MaxZeilen        int           = 100
    , @ResultSetArt     varchar(16)   = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen     bit           = 0
    , @Json             nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen   bit           = 1
    , @Hilfe            bit           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'moduleStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @ChildJsonRequested bit = CASE WHEN @JsonErzeugen=1 OR @MitFindings=1 THEN 1 ELSE 0 END;
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
    DECLARE @IntegrityJson nvarchar(max);
    DECLARE @CapacityJson nvarchar(max);
    DECLARE @CountersJson nvarchar(max);
    DECLARE @CriticalEventsJson nvarchar(max);
    DECLARE @ContentionJson nvarchar(max);
    DECLARE @BufferPoolJson nvarchar(max);
    DECLARE @FindingsJson nvarchar(max);

    CREATE TABLE [#ServerHealthAnalysis_ModuleStatus]
    (
          [Ordinal]      tinyint        NOT NULL
        , [ModuleName]   sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NOT NULL
        , [StatusCode]   varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [IsPartial]    bit            NOT NULL
        , [ErrorNumber]  int            NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ServerHealthAnalysis';
        PRINT N'@MitCpu bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerCpuTopology auf. Bestandteil des mindestens-ein-Modul-Gates.';
        PRINT N'@MitNuma bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerNuma auf. Standardpfad.';
        PRINT N'@MitMemory bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerMemory auf. Standardpfad.';
        PRINT N'@MitTempDB bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_TempDBConfiguration auf. Standardpfad.';
        PRINT N'@MitConfiguration bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerConfiguration auf. Standardpfad.';
        PRINT N'@MitTraceFlags bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_TraceFlags auf. Standardpfad.';
        PRINT N'@MitStartup bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_StartupParameters auf. Standardpfad.';
        PRINT N'@MitOS bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_OSInformation auf. Standardpfad.';
        PRINT N'@MitSecurity bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerSecurityConfiguration auf. Standardpfad.';
        PRINT N'@MitIntegritaet bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DatabaseIntegrityAnalysis für ausgewählte Datenbanken auf. page details bleiben aus. High-Impact-Pfad.';
        PRINT N'@MitKapazitaet bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DatabaseCapacityAnalysis im Datenbankscope auf. High-Impact-Pfad.';
        PRINT N'@MitPerformanceCounters bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_PerformanceCounters mit SampleSeconds=0 auf. keine Warte-Samplingrunde.';
        PRINT N'@MitCriticalEvents bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_CriticalEngineEvents mit system_health an, ServerDiagnostics und EventXML aus.';
        PRINT N'@MitContention bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_InternalContentionAnalysis mit SampleSeconds=5 und PageDetails=0 auf. Sampling wartet bis zu fünf Sekunden.';
        PRINT N'@MitBufferPool bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_BufferPoolAnalysis ohne Verteilungsdetail auf. High-Impact-Pfad.';
        PRINT N'@MitFindings bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DiagnosticFindings. Parent JSON-Ergebnisse von Integrity/Capacity/BufferPool werden zur Wiederverwendung übergeben, sofern diese erzeugt wurden.';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL; bei Auslassung gilt NULL. Der Kandidatenhelfer behandelt den gesamten Listenwert NULL, leer oder nur aus U+0020-Leerzeichen bestehend als nicht angegeben; andere Whitespace-Zeichen wie Tabulatoren werden dabei nicht als Leerwert normalisiert. Das Pipe-Zeichen | trennt Elemente außerhalb von eckigen Klammern; innerhalb eines bracket-quotierten Elements maskiert ]] eine schließende Klammer. Äußere U+0020-Leerzeichen jedes Segments werden entfernt. Ein ungetrimmtes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; leere Segmente und fehlerhafte Klammerung sind ungültig. Die Namensprüfung verlangt, dass PARSENAME(Element, 1) nicht NULL und höchstens 128 Zeichen lang ist und PARSENAME(Element, 2) NULL ist. Sie prüft keine vollständige SQL-Bezeichnergrammatik und kontrolliert die Teile 3 und 4 nicht zusätzlich. Gültige doppelte Namenswerte sind unter SQL_Latin1_General_CP1_CS_AS ungültig; Namen mit abweichender Groß- und Kleinschreibung bleiben verschieden. Erst wenn der gemeinsame Kandidatenhelfer erreicht wird, führen ungültige Elemente oder Duplikate zu INVALID_PARAMETER. Die Kandidatenauswahl bleibt durch Sichtbarkeit, Onlinezustand und HAS_DBACCESS begrenzt; die Liste garantiert weder die Existenz noch den Zugriff auf einen Namen und gewährt keine zusätzlichen Rechte. Der ServerHealth-Parent reicht die unveränderte Liste an die aufgerufenen DatabaseIntegrityAnalysis-, DatabaseCapacityAnalysis- und DiagnosticFindings-Kindmodule weiter. Die Liste und ein nicht-NULL Pattern sind im erreichten Kandidatenhelfer nur dann unvereinbar, wenn nach der Normalisierung eine wirksame Namensliste vorliegt. Frühe Fehler oder nicht aufgerufene Kindmodule können die Kandidatenprüfung verhindern; der Parent garantiert keinen einheitlichen Status für Listenfehler.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weitergereicht. Bei erreichter Kandidatenprüfung weist der gemeinsame Helper NULL als INVALID_PARAMETER ab. 0 schließt Datenbanken mit database_id bis einschließlich 4 (master, tempdb, model und msdb) aus; 1 lässt sie unter den bestehenden Sichtbarkeits-, Online-, HAS_DBACCESS- und Empfängerfiltern zu. Der Schalter aktiviert kein Kindmodul und gewährt keine Rechte. Frühere Fehler oder übersprungene Kindmodule können die Prüfung verhindern; der Parent garantiert keinen einheitlichen Status.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Der ServerHealth-Parent normalisiert oder validiert das Pattern nicht und reicht es an DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weiter, wenn die jeweiligen Kindmodule aufgerufen werden. Der erreichte Kandidatenhelfer schließt ein nicht-NULL Pattern mit einer wirksamen expliziten Namensliste aus; NULL, leerer oder nur aus U+0020 bestehender Listenwert ist keine wirksame Liste. Der Kandidatenhelfer prüft Pattern und Liste nur, wenn sein Auswahl-/Parserpfad tatsächlich erreicht wird.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weitergereicht. Der gemeinsame Kandidatenhelper weist NULL als INVALID_PARAMETER ab, wenn er erreicht wird, auch bei @AnalysisClass=NULL. Integrity nutzt HA_DR_CURRENT und Capacity SERVER_HEALTH_CURRENT; beide verlangen laut Katalog keine RequiresGroupGate-Bestätigung. Findings reicht diesen Wert unter den hier festgelegten Defaults nur an seine tatsächlich aufgerufenen Integrity-, Capacity- und BackupChain-Kindmodule weiter; BackupChain verwendet @AnalysisClass=NULL. Für diese tatsächlich erreichten Klassen lösen 0 und 1 keine High-Impact-Bestätigungspflicht aus. Andere Policyfreigaben und SQL-Rechte bleiben unverändert. Der Wert aktiviert kein Kindmodul oder tiefes Modul. Frühere Fehler, übersprungene Aufrufe und wiederverwendete JSON-Ergebnisse können Prüfungen verhindern; der Parent garantiert keinen einheitlichen Status.';
        PRINT N'@MaxZeilen int. Default ist 100; bei Auslassung gilt 100. SQL Server bindet den ganzzahligen int-Wert vor Prozedureintritt; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert keinen Text. @Hilfe=1 druckt die Hilfe und kehrt vor der Prüfung zurück; sonst führt ein negativer Wert zu INVALID_PARAMETER/partial und verhindert alle Kindaufrufe. 0 und NULL passieren diesen Guard. Der unveränderte Wert wird nur an aktive direkte Aufrufe von USP_ServerMemory, USP_DatabaseIntegrityAnalysis, USP_DatabaseCapacityAnalysis, USP_PerformanceCounters, USP_CriticalEngineEvents, USP_InternalContentionAnalysis, USP_BufferPoolAnalysis und USP_DiagnosticFindings übergeben, nicht an die übrigen acht Standardmodule. Die Parent-Modulstatusliste wird nicht gekürzt. In den genannten Kindern bedeuten 0 und NULL jeweils unbegrenzt; positive Werte wirken nur auf die jeweilige lokale Auswahl oder Ausgabe. Das ist keine Gesamtgrenze für Resultsets, JSON, Scan-, Sammel- oder Zeitaufwand; Metadaten, Warnungen und andere Ergebnisse können mehr Zeilen enthalten, und Quellenarbeit kann vor einer Ausgabebegrenzung stattfinden.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. CONSOLE zeigt die beschriftete Modulstatusliste. RAW liefert die Ergebnisse der aufgerufenen Module, danach den Parentstatus und die Modulstatusliste. TABLE schreibt ausschließlich moduleStatus. NONE unterdrückt die fachlichen Resultsets. CONSOLE und TABLE reichen intern NONE an die Module weiter. JSON wird separat gesteuert. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel moduleStatus erforderlich. Der Wert benennt eine vorhandene leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Erlaubt sind maximal 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig. Die Vorprüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt das Parent-JSON in Json. 0 und NULL lassen Json auf NULL. Bei MitFindings=1 fordert der Parent zusätzlich die JSON-Ergebnisse von Integrität, Kapazität und BufferPool zur Wiederverwendung an, auch wenn kein Parent-JSON angefordert wurde.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält der Empfänger JSON mit meta, cpuTopology, numa, memory, tempdb, configuration, traceFlags, startupParameters, operatingSystem, security, databaseIntegrity, databaseCapacity, performanceCounters, criticalEngineEvents, internalContention, bufferPool, diagnosticFindings und warnings. Deaktivierte/nicht angeforderte Module erscheinen als JSON null. Mit lokaler nvarchar(max)-Variablen und OUTPUT binden.';
        PRINT N'@PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Der Wert wird unverändert an tatsächlich ausgeführte Kindaufrufe weitergereicht (16 Aufrufstellen). 1 fordert die jeweilige optionale Meldungseinstellung des Kindes an; 0 und NULL werden ebenfalls unverändert weitergereicht. Die konkrete Wirkung folgt dem Vertrag des jeweiligen Kindes; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Im normalen Ablauf verwendet der Parent den Schalter nicht für eine eigene PRINT- oder RAISERROR-Statusmeldung. Die Hilfeausgabe ist unabhängig. Der Schalter steuert im Parent keine Resultsets, JSON, Analyseflags oder Fehlerbehandlung; Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt Parameterbeschreibung und Beispiele, danach RETURN vor Erhebung und Output-Statuszuweisung. 0 oder NULL führt normalen Aufruf aus. Eintrittsreset setzt @Json dennoch auf NULL. TABLE-Preflight/Mappingprüfung erfolgt vor Hilfezweig.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2. EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3. DECLARE @HealthJson nvarchar(max)=NULL; EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@HealthJson OUTPUT; SELECT @HealthJson AS [HealthJson];';
        PRINT N'Beispiel 4. DECLARE @HealthTablesJson nvarchar(max)=N''{"moduleStatus":"#ServerHealthAnalysis_HelpExample"}''; CREATE TABLE #ServerHealthAnalysis_HelpExample([Seed] bit NULL); EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt=''TABLE'',@ResultTablesJson=@HealthTablesJson; SELECT * FROM #ServerHealthAnalysis_HelpExample; DROP TABLE #ServerHealthAnalysis_HelpExample;';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@MitCpu = 0 AND @MitNuma = 0 AND @MitMemory = 0 AND @MitTempDB = 0
           AND @MitConfiguration = 0 AND @MitTraceFlags = 0 AND @MitStartup = 0
           AND @MitOS = 0 AND @MitSecurity = 0 AND @MitIntegritaet = 0
           AND @MitKapazitaet = 0 AND @MitPerformanceCounters = 0
           AND @MitCriticalEvents = 0 AND @MitContention = 0
           AND @MitBufferPool = 0 AND @MitFindings = 0)
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
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
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES
        (9, N'USP_ServerSecurityConfiguration', COALESCE(@ChildStatus, 'ERROR_HANDLED'), COALESCE(@ChildPartial, 1), @ChildErrorNumber, @ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitIntegritaet = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MitPageDetails = 0
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = @OutputMode
                , @JsonErzeugen = @ChildJsonRequested, @Json = @IntegrityJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (10,N'USP_DatabaseIntegrityAnalysis',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitKapazitaet = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_DatabaseCapacityAnalysis]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode, @JsonErzeugen = @ChildJsonRequested
                , @Json = @CapacityJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (11,N'USP_DatabaseCapacityAnalysis',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitPerformanceCounters = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_PerformanceCounters]
                  @SampleSeconds = 0, @MaxZeilen = @MaxZeilen, @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen, @Json = @CountersJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (12,N'USP_PerformanceCounters',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitCriticalEvents = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_CriticalEngineEvents]
                  @MitSystemHealth = 1, @MitServerDiagnostics = 0, @MitEventXml = 0
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen, @Json = @CriticalEventsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (13,N'USP_CriticalEngineEvents',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitContention = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_InternalContentionAnalysis]
                  @SampleSeconds = 5, @MitPageDetails = 0, @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode, @JsonErzeugen = @JsonErzeugen
                , @Json = @ContentionJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (14,N'USP_InternalContentionAnalysis',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitBufferPool = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_BufferPoolAnalysis]
                  @MitBufferPoolVerteilung = 0, @MaxZeilen = @MaxZeilen
                , @ResultSetArt = @OutputMode, @JsonErzeugen = @ChildJsonRequested
                , @Json = @BufferPoolJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (15,N'USP_BufferPoolAnalysis',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF @OverallStatus = 'AVAILABLE' AND @MitFindings = 1
    BEGIN
        SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
        BEGIN TRY
            EXEC [monitor].[USP_DiagnosticFindings]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @ParentIntegrityJson = @IntegrityJson
                , @ParentCapacityJson = @CapacityJson
                , @ParentBufferPoolJson = @BufferPoolJson
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen, @Json = @FindingsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
        END TRY BEGIN CATCH
            SELECT @ChildStatus='ERROR_HANDLED',@ChildPartial=1,@ChildErrorNumber=ERROR_NUMBER(),@ChildErrorMessage=ERROR_MESSAGE();
        END CATCH;
        INSERT [#ServerHealthAnalysis_ModuleStatus] VALUES (16,N'USP_DiagnosticFindings',COALESCE(@ChildStatus,'ERROR_HANDLED'),COALESCE(@ChildPartial,1),@ChildErrorNumber,@ChildErrorMessage);
    END;

    IF EXISTS
    (
        SELECT 1
        FROM [#ServerHealthAnalysis_ModuleStatus]
        WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED', 'AVAILABLE_WITH_FINDING', 'NOT_APPLICABLE')
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
            , (SELECT COUNT_BIG(*) FROM [#ServerHealthAnalysis_ModuleStatus]) AS [ModuleCount]
            , (SELECT COUNT_BIG(*) FROM [#ServerHealthAnalysis_ModuleStatus]
               WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED', 'AVAILABLE_WITH_FINDING', 'NOT_APPLICABLE')) AS [ProblemModuleCount];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#ServerHealthAnalysis_ModuleStatus] ORDER BY [Ordinal];
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
            FROM [#ServerHealthAnalysis_ModuleStatus]
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
            FROM [#ServerHealthAnalysis_ModuleStatus]
            WHERE [StatusCode] NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED', 'AVAILABLE_WITH_FINDING', 'NOT_APPLICABLE')
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
            , N',"databaseIntegrity":', COALESCE(JSON_QUERY(@IntegrityJson), N'null')
            , N',"databaseCapacity":', COALESCE(JSON_QUERY(@CapacityJson), N'null')
            , N',"performanceCounters":', COALESCE(JSON_QUERY(@CountersJson), N'null')
            , N',"criticalEngineEvents":', COALESCE(JSON_QUERY(@CriticalEventsJson), N'null')
            , N',"internalContention":', COALESCE(JSON_QUERY(@ContentionJson), N'null')
            , N',"bufferPool":', COALESCE(JSON_QUERY(@BufferPoolJson), N'null')
            , N',"diagnosticFindings":', COALESCE(JSON_QUERY(@FindingsJson), N'null')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ServerHealthAnalysis_ModuleStatus'
            , @ResultLabel=N'ServerHealthAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ServerHealthAnalysis_ModuleStatus'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
