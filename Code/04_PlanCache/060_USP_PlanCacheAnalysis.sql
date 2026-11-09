USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PlanCacheAnalysis
Version      : 2.1.0
Stand        : 2026-07-19
Zweck        : Orchestriert Plan-Cache- und Showplan-Module mit einheitlichen
               Listen-, Pattern-, Limit- und Ausgabeparametern.
Änderungen   : 2.1.0 - dm_exec_query_stats bei mehreren Consumern einmalig
                         laufgebunden materialisiert und wiederverwendet.
               2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PlanCacheAnalysis]
      @MitQueryStats                    bit            = 1
    , @MitQueryHashAnalysis             bit            = 0
    , @MitPlanCacheHealth               bit            = 0
    , @MitShowplanAnalysis              bit            = 0
    , @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
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
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    CREATE TABLE [#PlanCacheAnalysis_MonitorTableResult]
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
    DECLARE @Mode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus, 'TOP'))));
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @Detail nvarchar(2000) = N'Aktivierte Phase-3-Module werden nacheinander ausgeführt.';
    DECLARE @HealthMode varchar(16) = CASE WHEN @Mode = 'VOLL' THEN 'VOLL' ELSE 'SUMMARY' END;
    DECLARE @MitDbVerteilung bit = CASE WHEN @Mode = 'VOLL' THEN 1 ELSE 0 END;
    DECLARE @ShowplanMode varchar(16) = CASE WHEN @Mode = 'VOLL' THEN 'VOLL' ELSE 'GEZIELT' END;
    DECLARE @QueryStatsSnapshotConsumerCount tinyint =
        CONVERT(tinyint, CONVERT(tinyint,COALESCE(@MitQueryStats,0))
            + CONVERT(tinyint,COALESCE(@MitQueryHashAnalysis,0))
            + CASE WHEN @MitShowplanAnalysis=1 AND @PlanHandle IS NULL THEN 1 ELSE 0 END);
    DECLARE @QueryStatsSnapshotAvailable bit = 0;
    DECLARE @QueryStatsSnapshotAllowed bit = 1;
    DECLARE @ShowplanUsesQueryStatsSnapshot bit = 0;
    DECLARE @QueryStatsJson nvarchar(max);
    DECLARE @HashJson nvarchar(max);
    DECLARE @HealthJson nvarchar(max);
    DECLARE @ShowplanJson nvarchar(max);

    DECLARE @Errors TABLE
    (
          [ExecutionOrdinal] tinyint        NOT NULL
        , [ModuleName]       sysname COLLATE SQL_Latin1_General_CP1_CS_AS        NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS    NOT NULL
        , [ErrorNumber]      int            NULL
        , [ErrorMessage]     nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#PlanCacheAnalysis_QueryStatsSnapshot]
    (
          [sql_handle] varbinary(64) NULL
        , [statement_start_offset] int NULL
        , [statement_end_offset] int NULL
        , [plan_generation_num] bigint NULL
        , [plan_handle] varbinary(64) NULL
        , [creation_time] datetime NULL
        , [last_execution_time] datetime NULL
        , [execution_count] bigint NULL
        , [total_worker_time] bigint NULL
        , [last_worker_time] bigint NULL
        , [min_worker_time] bigint NULL
        , [max_worker_time] bigint NULL
        , [total_physical_reads] bigint NULL
        , [last_physical_reads] bigint NULL
        , [total_logical_writes] bigint NULL
        , [last_logical_writes] bigint NULL
        , [total_logical_reads] bigint NULL
        , [last_logical_reads] bigint NULL
        , [total_elapsed_time] bigint NULL
        , [last_elapsed_time] bigint NULL
        , [min_elapsed_time] bigint NULL
        , [max_elapsed_time] bigint NULL
        , [query_hash] binary(8) NULL
        , [query_plan_hash] binary(8) NULL
        , [total_rows] bigint NULL
        , [last_rows] bigint NULL
        , [min_rows] bigint NULL
        , [max_rows] bigint NULL
        , [last_dop] bigint NULL
        , [min_dop] bigint NULL
        , [max_dop] bigint NULL
        , [max_grant_kb] bigint NULL
        , [last_grant_kb] bigint NULL
        , [last_used_grant_kb] bigint NULL
        , [last_ideal_grant_kb] bigint NULL
        , [total_spills] bigint NULL
        , [last_spills] bigint NULL
    );

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PlanCacheAnalysis';
        PRINT N'Die Procedure koordiniert Query Stats, Query Hash, Plan Cache Health und Showplan. Sie liefert den Modulstatus und kann die Ergebnisse der aufgerufenen Module als JSON zusammenführen.';
        PRINT N'@MitQueryStats bit. Default ist 1. 1 aktiviert QueryStats, 0 deaktiviert. TOP/100 ohne Hash ist nicht per se PLAN_CACHE_DEEP geschützt. NULL aktiviert Child nicht.';
        PRINT N'@MitQueryHashAnalysis bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert den Hash-Child, 0 deaktiviert ihn. NULL deaktiviert den Child. Bei aktiviertem Child verlangt ein fehlender QueryHash das Deep-Gate; ein einzelner Hash mit TOP <=1000 nicht.';
        PRINT N'@MitPlanCacheHealth bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert Health, 0 deaktiviert den Child. NULL deaktiviert den Child. TOP wird SUMMARY; VOLL wird VOLL mit Datenbankverteilung und Deep-Gate.';
        PRINT N'@MitShowplanAnalysis bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert Showplan, 0 deaktiviert den Child. NULL deaktiviert den Child. TOP wird GEZIELT, VOLL bleibt VOLL.';
        PRINT N'Mindestens einer der vier Modulschalter muss exakt 1 sein. 0 und NULL gelten jeweils als deaktiviert.';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger Datenbanknamen bis 128 Zeichen. | trennt außerhalb [...], ]] maskiert ]. Segmentränder getrimmt. NULL/leer/Whitespace = kein Filter. Ungültig INVALID_PARAMETER. Nicht mit wirksamem DatabaseNamePattern kombinierbar.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet den Wert vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent prüft oder normalisiert den Wert nicht und reicht ihn unverändert nur an QueryStats und Showplan weiter, jeweils wenn das Child aktiviert ist. Bei erreichtem Kandidatenhelfer schließt 0 master, tempdb, model und msdb aus; 1 lässt sie zu, sofern sie sichtbar, online und zugänglich sind und die übrigen Listen-, Pattern- und Snapshotfilter erfüllen. QueryStats ruft den Kandidatenhelfer bei Status AVAILABLE auch mit gesetztem @PlanHandle auf. Showplan ruft ihn nur bei Status AVAILABLE und @PlanHandle IS NULL auf; ein direkt übergebener Planhandle umgeht dort diesen Datenbankscopefilter. NULL wird vom Kandidatenhelfer als INVALID_PARAMETER abgelehnt, wenn er erreicht wird; frühere Fehler können Vorrang haben. Der Parent reicht diesen Schalter nicht an QueryHash oder PlanCacheHealth weiter. Er gewährt keine zusätzlichen Datenbankrechte.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL. LIKE oder Präfix like:/regex:/regexi:. Case-insensitive Präfix, außen getrimmt, Rest nicht. NULL kein Filter, leer ungültig. Nicht mit DatabaseNames kombinierbar. Regex nur SQL Server 2025 + Installations-DB Compat 170.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad, wenn dessen Policy eine Bestätigung verlangt. Berechtigungen und Grenzwerte gelten weiterhin. 0 bestätigt den Pfad nicht und NULL ist für die Pfadprüfung ungültig. Der Parent prüft PLAN_CACHE_DEEP bei mindestens zwei Snapshot-Consumern, wenn ein Queryhash fehlt, VOLL gewählt ist oder das Zeilenlimit unbegrenzt beziehungsweise größer als 1000 ist. Die aufgerufenen Module prüfen ihre eigenen Gates. Als Snapshot-Consumer zählen Query Stats, Query Hash und Showplan ohne direkten Planhandle. Verweigert das Parent-Gate den gemeinsamen Zugriff, laufen die Module nicht. Schlägt die erlaubte Materialisierung fehl, können die Module frisch lesen.';
        PRINT N'@QueryHash binary(8). Default ist NULL. Optionaler exakter Queryhashfilter für QueryStats/Hash/Showplan. Hash-Child ohne Hash braucht Deep-Gate. Einzelner Hash mit TOP/<=1000 nicht.';
        PRINT N'@QueryPlanHash binary(8). Default ist NULL. Optionaler exakter Planhashfilter für QueryStats/Showplan.';
        PRINT N'@PlanHandle varbinary(64). Default ist NULL. Optionaler Handlefilter. Showplan fügt Nicht-NULL direkt als Kandidat hinzu.';
        PRINT N'@TextPattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und es wird kein Textfilter angefordert. Der Parser trimmt zuerst äußere U+0020-Leerzeichen, erkennt like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung und entfernt ein erkanntes Präfix ohne erneutes Trimmen. Ohne bekanntes Präfix gilt der gesamte Inhalt als LIKE-Muster, auch bei einem unbekannten Präfix. NULL ergibt NONE; leere Eingabe, nur U+0020-Leerzeichen und leerer Präfixrest ergeben intern EMPTY_PATTERN und beim tatsächlich erreichten Kindmodul INVALID_PARAMETER. LIKE verwendet %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c (case-sensitive), REGEXI Flag i (case-insensitive). Der Parser prüft keine Regexsyntax; Syntaxfehler entstehen erst bei tatsächlicher REGEXP_LIKE-Ausführung. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. @TextPattern ist keine Pipe-Liste. Der PlanCache-Parent prüft das Pattern nicht und reicht es unverändert nur an QueryStats und Showplan weiter, nicht an QueryHash oder PlanCacheHealth. QueryStats wertet den Textfilter auch bei gesetztem @PlanHandle aus. Showplan prüft Form und Regexverfügbarkeit vor der Handleauswahl; ohne direkten Planhandle wendet es den Textfilter an. Mit nicht-NULL @PlanHandle wird der Handle direkt übernommen und nicht mit dem Pattern verglichen; Regexsyntax kann daher ungeprüft bleiben. Frühere Fehler oder deaktivierte Kindmodule können die Prüfung verhindern.';
        PRINT N'@Sortierung varchar(32). Default ist ''CPU_TOTAL''. Die unterstützten Ränge hängen vom aktivierten Modul ab. QueryStats, QueryHashAnalysis und ShowplanAnalysis verstehen CPU_TOTAL für gesamte CPU, ELAPSED_TOTAL für gesamte Laufzeit, READS_TOTAL für logische Reads, EXECUTIONS für Ausführungen und SPILLS_TOTAL für Spills. QueryStats und QueryHashAnalysis unterstützen zusätzlich WRITES_TOTAL für logische Writes. QueryStats und ShowplanAnalysis unterstützen GRANT_MAX für maximalen Grant und LAST_EXECUTION für die letzte Ausführung. Nur QueryStats unterstützt CPU_AVG, ELAPSED_AVG, READS_AVG und WRITES_AVG für den jeweiligen Mittelwert je Ausführung sowie ROWS_TOTAL für die Gesamtzahl der Zeilen. Nur QueryHashAnalysis unterstützt PLAN_VARIANTS für die Zahl der Planvarianten. PlanCacheHealth verwendet den Wert nicht. NULL entspricht CPU_TOTAL. Die Empfänger trimmen Leerzeichen und normalisieren die Groß- und Kleinschreibung. Leertext und nicht unterstützte Werte sind im jeweiligen Modul ungültig.';
        PRINT N'@AnalyseModus varchar(16). Default ist ''TOP''. TOP => QueryStats/Hash TOP, Health SUMMARY, Showplan GEZIELT. VOLL => QueryStats/Hash VOLL, Health VOLL+Datenbankverteilung, Showplan VOLL. Trim/Upper, NULL TOP, leer/sonst ungültig.';
        PRINT N'@MaxZeilen int. Default ist 100. Je Child weitergereicht. Positiv begrenzt, NULL/0 unbegrenzt, negativ Parent INVALID_PARAMETER ohne Children. Unbegrenzt/>1000 oder VOLL kann Deep-Gate auslösen. SUMMARY Health nutzt den Wert nicht.';
        PRINT N'@MaxAnalyseobjekte int. Default ist 20. Showplan-Kandidatenlimit. Positiv begrenzt, 0/NULL unbegrenzt, negativ Parent INVALID_PARAMETER. >20/unbegrenzt kann Deep-Gate auslösen. VOLL zusätzlich SHOWPLAN_XML_DEEP.';
        PRINT N'@MaxDurationSeconds int. Default ist 30. Ganzzahl von 1 bis 3600 Sekunden. Der Parent lehnt NULL und Zahlen außerhalb des Bereichs ab. Das Zeitbudget gilt für Showplan und wird zwischen Kandidaten geprüft. Es unterbricht keine laufende XML-Analyse.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. RAW gibt zuerst die Resultsets der aufgerufenen Module aus, gefolgt vom Parentstatus und der Modulstatusliste. CONSOLE zeigt die beschriftete Modulstatusliste. TABLE schreibt nur moduleStatus. NONE unterdrückt die fachlichen Resultsets. Die Module erhalten bei CONSOLE, TABLE und NONE intern NONE. JSON ist separat wählbar. Leerzeichen am Rand und die Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Nur TABLE: Objekt exakt mit moduleStatus und Stringziel. Ziel vorhandene leere lokale #Temp mit genau einer Seed-Spalte, <=116 Zeichen, kein ##/#Monitor. Andere Modi nur NULL/leer/Whitespace, sonst 51011. Preflight vor Hilfe-Return.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt zusätzlich @Json. 0/NULL erzeugt kein Dokument.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. bei Eintritt NULL. Bei JsonErzeugen=1 Dokument mit meta, queryStats, queryHashes, planCacheHealth, showplan, modules, warnings. Nicht verfügbare Childobjekte null. OUTPUT nvarchar(max) binden.';
        PRINT N'@PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Er reicht ihn unverändert an tatsächlich ausgeführte QueryStats-, QueryHashAnalysis-, PlanCacheHealth- und Showplan-Aufrufe weiter. 1 fordert dort jeweils die optionale Meldungseinstellung an; 0 und NULL werden ebenfalls weitergereicht. Die konkrete Wirkung folgt dem jeweiligen Childvertrag; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Der Parent erzeugt im normalen Ablauf keine eigene PRINT- oder RAISERROR-Statusmeldung; seine Hilfeausgabe ist unabhängig. Im Showplan-Child entsteht dessen optionale Severity-10-Warnung nur am erreichten Ende bei einem Status ungleich AVAILABLE; der interne Interpreter erhält fest @PrintMeldungen=0. Der Parent-Schalter steuert keine Resultsets, JSON, Modulauswahl oder Fehlerbehandlung. Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.';
        PRINT N'@Hilfe bit. Default ist 0. 1 druckt Hilfe und RETURN vor Validierung/Analyse. Vorher @Json=NULL, Monitor-Temp-DDL, Locktimeout, TABLE-Mapping-Preflight. 0/NULL regulärer Ablauf.';
        PRINT N'Hilfe anzeigen. EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;';
        PRINT N'Modulstatus als RAW lesen. EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt=''RAW'';';
        PRINT N'Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];';
        PRINT N'Modulstatus in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanCacheAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"moduleStatus":"#PlanCacheAnalysis_HelpExample"}''; SELECT * FROM #PlanCacheAnalysis_HelpExample; DROP TABLE #PlanCacheAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanCacheAnalysis_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    IF @MaxZeilen < 0
       OR @MaxAnalyseobjekte < 0

       OR @MaxDurationSeconds IS NULL
       OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @Mode NOT IN ('TOP', 'VOLL')
       OR (COALESCE(@MitQueryStats,0) = 0 AND COALESCE(@MitQueryHashAnalysis,0) = 0
           AND COALESCE(@MitPlanCacheHealth,0) = 0 AND COALESCE(@MitShowplanAnalysis,0) = 0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @Detail = N'Ungültiger Parameter oder kein Teilmodul aktiviert.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @QueryStatsSnapshotConsumerCount >= 2
       AND
       (
           @QueryHash IS NULL
           OR @Mode = 'VOLL'
           OR @MaxZeilen IS NULL
           OR @MaxZeilen = 0
           OR @MaxZeilen > 1000
       )
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass='PLAN_CACHE_DEEP'
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@Detail OUTPUT;
        SET @QueryStatsSnapshotAllowed=CONVERT(bit,CASE WHEN @StatusCode='AVAILABLE' THEN 1 ELSE 0 END);
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @QueryStatsSnapshotConsumerCount >= 2
       AND @QueryStatsSnapshotAllowed = 1
    BEGIN TRY
        INSERT [#PlanCacheAnalysis_QueryStatsSnapshot]
        SELECT
              [sql_handle], [statement_start_offset], [statement_end_offset], [plan_generation_num]
            , [plan_handle], [creation_time], [last_execution_time], [execution_count]
            , [total_worker_time], [last_worker_time], [min_worker_time], [max_worker_time]
            , [total_physical_reads], [last_physical_reads]
            , [total_logical_writes], [last_logical_writes]
            , [total_logical_reads], [last_logical_reads]
            , [total_elapsed_time], [last_elapsed_time], [min_elapsed_time], [max_elapsed_time]
            , [query_hash], [query_plan_hash]
            , [total_rows], [last_rows], [min_rows], [max_rows]
            , [last_dop], [min_dop], [max_dop]
            , [max_grant_kb], [last_grant_kb], [last_used_grant_kb], [last_ideal_grant_kb]
            , [total_spills], [last_spills]
        FROM [sys].[dm_exec_query_stats] WITH (NOLOCK)
        WHERE @QueryHash IS NULL OR [query_hash]=@QueryHash;

        SET @QueryStatsSnapshotAvailable = 1;
        SET @ShowplanUsesQueryStatsSnapshot = CASE WHEN @MitShowplanAnalysis=1 AND @PlanHandle IS NULL THEN 1 ELSE 0 END;
        SET @Detail = N'dm_exec_query_stats wurde einmalig für die aktivierten Consumer materialisiert.';
    END TRY
    BEGIN CATCH
        DELETE FROM [#PlanCacheAnalysis_QueryStatsSnapshot];
        SET @QueryStatsSnapshotAvailable = 0;
        SET @ShowplanUsesQueryStatsSnapshot = 0;
        SET @Detail = N'Der gemeinsame dm_exec_query_stats-Snapshot war nicht verfügbar; aktivierte Children lesen mit eigenem Fehlerstatus frisch.';
    END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitQueryStats = 1
    BEGIN
        BEGIN TRY
            EXEC [monitor].[USP_QueryStats]
                  @DatabaseNames = @DatabaseNames
                , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @QueryHash = @QueryHash
                , @QueryPlanHash = @QueryPlanHash
                , @PlanHandle = @PlanHandle
                , @TextPattern = @TextPattern
                , @Sortierung = @Sortierung
                , @AnalyseModus = @Mode
                , @MaxZeilen = @MaxZeilen
                , @ParentQueryStatsSnapshot = @QueryStatsSnapshotAvailable
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @QueryStatsJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (1, N'USP_QueryStats',
                CASE WHEN @QueryStatsSnapshotAvailable=1 THEN 'REUSED_PARENT_SNAPSHOT' ELSE 'EXECUTED' END, NULL, NULL);
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
                , @HighImpactConfirmed = @HighImpactConfirmed
                , @ParentQueryStatsSnapshot = @QueryStatsSnapshotAvailable
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @HashJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (2, N'USP_QueryHashAnalysis',
                CASE WHEN @QueryStatsSnapshotAvailable=1 THEN 'REUSED_PARENT_SNAPSHOT' ELSE 'EXECUTED' END, NULL, NULL);
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
                , @HighImpactConfirmed = @HighImpactConfirmed
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
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

                , @TextPattern = @TextPattern
                , @AnalyseModus = @ShowplanMode
                , @Sortierung = @Sortierung
                , @MaxAnalyseobjekte = @MaxAnalyseobjekte
                , @MaxZeilen = @MaxZeilen
                , @MaxDurationSeconds = @MaxDurationSeconds
                , @ParentQueryStatsSnapshot = @ShowplanUsesQueryStatsSnapshot
                , @ResultSetArt = @OutputMode
                , @JsonErzeugen = @JsonErzeugen
                , @Json = @ShowplanJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen;

            INSERT @Errors VALUES (4, N'USP_ShowplanAnalysis',
                CASE WHEN @ShowplanUsesQueryStatsSnapshot=1 THEN 'REUSED_PARENT_SNAPSHOT' ELSE 'EXECUTED' END, NULL, NULL);
        END TRY
        BEGIN CATCH
            INSERT @Errors VALUES (4, N'USP_ShowplanAnalysis', 'ERROR_HANDLED', ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF EXISTS (SELECT 1 FROM @Errors WHERE [InvocationStatus] NOT IN ('EXECUTED','REUSED_PARENT_SNAPSHOT'))
       AND @StatusCode = 'AVAILABLE'
    BEGIN
        SET @StatusCode = 'AVAILABLE_LIMITED';
    END;

    INSERT [#PlanCacheAnalysis_MonitorTableResult]
        ([ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage])
    SELECT [ExecutionOrdinal],[ModuleName],[InvocationStatus],[ErrorNumber],[ErrorMessage]
    FROM @Errors;

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
            SELECT * FROM [#PlanCacheAnalysis_MonitorTableResult] ORDER BY [ExecutionOrdinal];
        END
        ELSE
        BEGIN
            SELECT
                  N'Plan-Cache Teilmodul' AS [Ergebnis]
                , [ExecutionOrdinal]      AS [Reihenfolge]
                , [ModuleName]            AS [Modul]
                , [InvocationStatus]      AS [Status]
                , [ErrorMessage]          AS [Fehler]
            FROM [#PlanCacheAnalysis_MonitorTableResult]
            ORDER BY [ExecutionOrdinal];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max);
        DECLARE @Modules nvarchar(max);
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

        SELECT @Modules =
        (
            SELECT *
            FROM [#PlanCacheAnalysis_MonitorTableResult]
            ORDER BY [ExecutionOrdinal]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SELECT @Warnings =
        (
            SELECT *
            FROM [#PlanCacheAnalysis_MonitorTableResult]
            WHERE [InvocationStatus] NOT IN ('EXECUTED','REUSED_PARENT_SNAPSHOT')
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
            , N',"modules":', COALESCE(@Modules, N'[]')
            , N',"warnings":', COALESCE(@Warnings, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#PlanCacheAnalysis_MonitorTableResult'
            , @ResultLabel=N'PlanCacheAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#PlanCacheAnalysis_MonitorTableResult'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
