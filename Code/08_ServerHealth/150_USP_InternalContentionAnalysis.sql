USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_InternalContentionAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure vergleicht Latch-/Spinlockzähler als Delta oder kumulative Werte und erfasst optional aktuelle Hot Pages mit Seitendetails.
Datenquellen : sys.dm_os_latch_stats, sys.dm_os_spinlock_stats,
               sys.dm_exec_requests, sys.dm_os_sys_info und optional
               sys.dm_db_page_info.
Methodik     : @SampleSeconds 1..60 liefert ein Intervalldelta, 0 positive
               kumulative Werte seit Serverstart; die gemessene Dauer steuert
               Raten. Hot Pages sind ein nachgelagerter Snapshot.
Grenzen      : Korrelation ist Evidenz, keine automatische Ursachenfeststellung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_InternalContentionAnalysis]
      @SampleSeconds     tinyint        = 5
    , @MitSpinlocks      bit            = 1
    , @MitHotPages       bit            = 1
    , @MitPageDetails    bit            = 0
    , @MaxZeilen         int            = 100
    , @ResultSetArt      varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen      bit            = 0
    , @Json              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen    bit            = 1
    , @Hilfe             bit            = 0
    , @StatusCodeOut     varchar(40)    = NULL OUTPUT
    , @IsPartialOut      bit            = NULL OUTPUT
    , @ErrorNumberOut    int            = NULL OUTPUT
    , @ErrorMessageOut   nvarchar(2048) = NULL OUTPUT
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'latches',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                 THEN CONVERT(bigint, 9223372036854775807)
                                 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_InternalContentionAnalysis';
        PRINT N'Vergleicht serverweite Latch- und optionale Spinlockzähler über ein Sample oder zeigt bei Sample 0 positive kumulative Werte seit Serverstart. Optional folgt ein Snapshot wartender PAGELATCH-/PAGEIOLATCH-Requests; Seitendetails sind ein zusätzlicher Opt-in-Pfad.';
        PRINT N'@Hilfe=1 druckt Kurzangaben und kehrt vor Sammlung zurück; ein TABLE-Mapping wird davor vorbereitet.';
        PRINT N'@SampleSeconds tinyint; Default: 5. NULL oder eine ganze Zahl 0 bis 60 Sekunden. 0 überspringt WAITFOR und zeigt positive kumulative Zähler seit Serverstart; 1–60 fordert ein Intervalldelta an. Die tatsächliche Dauer zwischen Sammelzeitpunkten wird in Sekunden gemessen und für Raten verwendet. Werte über 60 sind INVALID_PARAMETER. NULL überspringt wegen der NULL-Vergleiche die Wartezeit und liefert keine Latch-/Spinlock-Deltazeilen; Raten bleiben unbekannt. Bei positivem Sample setzt ein fallender Zähler CounterResetDetected=1 und dessen Differenz/Rate bleibt NULL; ein NULL-Zähler wird nicht als Reset markiert. Bei exakt 0 bleiben die Raten im kumulativen Modus NULL, auch wenn eine tatsächliche Dauer gemessen wurde; der Interpreter fordert für RatePerSecond ein positives angefordertes Sample.';
        PRINT N'@MitSpinlocks bit; Default: 1. NULL, 0 oder 1. Nur 1 liest sys.dm_os_spinlock_stats vor und nach dem Sample, aggregiert gleiche Namen und berechnet deren Werte. 0/NULL überspringt diese Quelle und erzeugt keine Spinlockzeilen; Latches und Hot Pages bleiben davon unabhängig.';
        PRINT N'@MitHotPages bit; Default: 1. 0 oder NULL überspringt die Requestquelle. Nur 1 nimmt nach dem Sample einen Snapshot anderer Requests mit PAGELATCH% oder PAGEIOLATCH% auf. DatabaseId stammt direkt aus request.database_id; der Name wird dazu nachgeschlagen und kann bei fehlender Auflösung NULL bleiben. Nur FileId und PageId werden über TRY_CONVERT aus WaitResource geparst und können bei nicht auflösbaren Angaben NULL bleiben. Der Snapshot ist zeitlich nicht identisch mit dem Counterdelta. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@MitPageDetails bit; Default: 0. NULL, 0 oder 1. Nur 1 ergänzt gültige Hot-Page-Zeilen über sys.dm_db_page_info im Modus LIMITED um Seitentyp, Objekt und Index. Die Kombination @MitPageDetails=1 mit @MitHotPages=0 ist INVALID_PARAMETER. Bei @MitHotPages=NULL löst die Hot-Page-Sammlung wegen ihrer Gleichheitsprüfung nicht aus und es entstehen trotz Detailwert 1 keine Details. 0/NULL lässt die optionalen Metadatenaufrufe aus.';
        PRINT N'@MaxZeilen int; Default: 100. int-Eingabe: NULL oder 0 bedeutet unbegrenzt, positive Werte bis 2147483647 begrenzen Zeilen je sortiertem Fachresultset nur in RAW und JSON. Negative Werte sind INVALID_PARAMETER. CONSOLE liefert die gesamte Latch-Fachmenge ohne dieses Ausgabelimit; TABLE schreibt ebenfalls alle Latches. Die Grenze wirkt nach Sammlung und Aggregation und begrenzt weder DMV-Snapshots noch Hot-Page-Ermittlung oder Page-Info-Aufrufe.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. NULL oder Text, der nach Trim und Umwandlung in Großbuchstaben CONSOLE, RAW, TABLE oder NONE ergibt. RAW liefert Statuskontext und drei Fachresultsets. CONSOLE wird intern zu NONE normalisiert und ruft danach den Console-Helper nur für Latches auf: bei Daten eine beschriftete Latchansicht, sonst eine verständliche Leerzeile. TABLE wird ebenfalls zu NONE normalisiert und schreibt ausschließlich Latches in die Zieltabellenzuordnung; NONE unterdrückt normale Resultsets. Die direkten CONSOLE-Resultsetzweige im Procedurekörper sind dadurch nicht erreichbar. NULL/Leertext und andere Werte sind INVALID_PARAMETER. Nichtleeres @ResultTablesJson außerhalb TABLE wirft Fehler 51011. Das TABLE-Mapping wird vor Hilfe und Parameterprüfung vorbereitet.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. NULL oder ein JSON-Objekt mit genau dem Schlüssel latches und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, etwa N''{"latches":"#InternalContentionAnalysis_HelpExample"}''. Für TABLE muss das Ziel leer sein und genau eine beliebig typisierte Seed-Spalte besitzen. NULL, nach Trim von U+0020 leere Eingabe oder fehlerhaftes Mapping scheitern am Preflight vor @Hilfe und Sammlung. Der Preflight prüft das Ziel; erst beim TABLE-Schreiben werden seine Zielspalten eingerichtet. Außerhalb TABLE sind NULL oder nach diesem Trim leere Werte zulässig, sonst wird 51011 geworfen. Globale und permanente Tabellen sowie der reservierte #Monitor-Präfix sind unzulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. NULL, 0 oder 1. Nur 1 erzeugt zusätzlich das JSON-Dokument im OUTPUT-Parameter @Json, unabhängig vom ResultSet-Modus; NULL/0 erzeugt es nicht. Das Dokument enthält meta, latches, spinlocks und hotPages. @MaxZeilen begrenzt die drei Facharrays, nicht meta.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(max), mit vorab deklarierter nvarchar(max)-Variable und OUTPUT zu übergeben. Zu Beginn wird die gebundene Variable auf NULL gesetzt; nur bei @JsonErzeugen=1 wird sie nach der Erfassung mit dem JSON-Dokument belegt. Kein Eingabefilter.';
        PRINT N'@PrintMeldungen bit; Default: 1. NULL, 0 oder 1. Der aktuelle Procedurekörper liest diesen Parameter nicht; er steuert keine PRINT-Ausgabe. Die Hilfe-PRINTs werden von @Hilfe gesteuert.';
        PRINT N'@Hilfe bit; Default: 0. NULL, 0 oder 1. Nur 1 druckt Kurzangaben zu Objekt, Sample, PageDetails, Zeilenlimit und Modi und kehrt vor Sammlung und normaler Parameterprüfung zurück. Ein TABLE-Mapping wird vor diesem Rücksprung vorbereitet.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler varchar(40)-OUTPUT-Empfang. Werte und Bedeutungen: AVAILABLE (regulär abgeschlossen ohne gesetzten Finding- oder Fehlerstatus), AVAILABLE_WITH_FINDING (Counterreset erkannt oder mindestens eine Hot-Page-Zeile), INVALID_PARAMETER (Sample über 60, negatives Zeilenlimit, ungültiger Ausgabemodus oder Seitendetails bei @MitHotPages=0), DENIED_PERMISSION (klassifizierter Berechtigungsfehler bei der Quellsammlung), ERROR_HANDLED (sonstiger abgefangener Sammlungsfehler). Zuweisung nach Erfassung und vor JSON/Resultsets. Optional zum Empfang mit @StatusCodeOut=@Empfaenger OUTPUT und einer varchar(40)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bindung bit. 1 kennzeichnet INVALID_PARAMETER, DENIED_PERMISSION oder ERROR_HANDLED; 0 kennzeichnet den regulären Ablauf einschließlich AVAILABLE_WITH_FINDING. Mit bit-Variable und OUTPUT binden. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @IsPartialOut=@Empfaenger OUTPUT und einer bit-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Bindung int mit passender Variable und OUTPUT. Enthält bei abgefangenem Sammlungsfehler die SQL-Fehlernummer; im regulären Ablauf und bei ungültigen Parametern bleibt sie NULL. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT und einer int-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(2048) mit kompatibler Variable und OUTPUT. Enthält ggf. den abgefangenen Fehlertext oder Parameterhinweis; im fehlerfreien Ablauf NULL. Bei Hilfe erfolgt keine Zuweisung. Optional zum Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT und einer nvarchar(2048)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'EXEC [monitor].[USP_InternalContentionAnalysis] @SampleSeconds=5,@MitSpinlocks=1,@MitHotPages=1,@MitPageDetails=0,@MaxZeilen=50,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @JsonOut nvarchar(max); EXEC [monitor].[USP_InternalContentionAnalysis] @SampleSeconds=5,@JsonErzeugen=1,@Json=@JsonOut OUTPUT,@ResultSetArt=''NONE''; SELECT @JsonOut AS [Json];';
        PRINT N'CREATE TABLE [#InternalContentionAnalysis_HelpExample]([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_InternalContentionAnalysis] @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"latches":"#InternalContentionAnalysis_HelpExample"}''; SELECT * FROM [#InternalContentionAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#InternalContentionAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE IF EXISTS [#InternalContentionAnalysis_HelpExample];';
        PRINT N'EXEC [monitor].[USP_InternalContentionAnalysis] @Hilfe=1;';



        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @SampleStartUtc datetime2(3) = @Now;
    DECLARE @SampleEndUtc datetime2(3) = @Now;
    DECLARE @SqlServerStartTime datetime2(3) = NULL;
    DECLARE @ActualSampleSeconds decimal(19,6) = 0;
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Delay varchar(8);

    CREATE TABLE [#InternalContentionAnalysis_LatchStart]
    (
          [LatchClass] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WaitingRequestsCount] bigint NOT NULL
        , [WaitTimeMs] bigint NOT NULL
        , [MaxWaitTimeMs] bigint NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_LatchEnd]
    (
          [LatchClass] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WaitingRequestsCount] bigint NOT NULL
        , [WaitTimeMs] bigint NOT NULL
        , [MaxWaitTimeMs] bigint NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_SpinStart]
    (
          [SpinlockName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Collisions] bigint NOT NULL
        , [Spins] bigint NOT NULL
        , [SleepTime] bigint NOT NULL
        , [Backoffs] bigint NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_SpinEnd]
    (
          [SpinlockName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Collisions] bigint NOT NULL
        , [Spins] bigint NOT NULL
        , [SleepTime] bigint NOT NULL
        , [Backoffs] bigint NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_LatchResult]
    (
          [LatchClass] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MeasurementKind] varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WaitingRequests] bigint NULL
        , [WaitTimeMs] bigint NULL
        , [MaxObservedWaitTimeMs] bigint NULL
        , [WaitsPerSecond] decimal(19,4) NULL
        , [WaitMsPerSecond] decimal(19,4) NULL
        , [CounterResetDetected] bit NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_SpinResult]
    (
          [SpinlockName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MeasurementKind] varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Collisions] bigint NULL
        , [Spins] bigint NULL
        , [SleepTime] bigint NULL
        , [Backoffs] bigint NULL
        , [CollisionsPerSecond] decimal(19,4) NULL
        , [BackoffsPerSecond] decimal(19,4) NULL
        , [CounterResetDetected] bit NOT NULL
    );
    CREATE TABLE [#InternalContentionAnalysis_HotPages]
    (
          [SessionId] smallint NOT NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [WaitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [WaitTimeMs] int NULL
        , [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileId] int NULL
        , [PageId] bigint NULL
        , [PageTypeDesc] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectId] int NULL
        , [IndexId] int NULL
    );

    IF @SampleSeconds > 60
       OR @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR (@MitPageDetails = 1 AND @MitHotPages = 0)
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Sample-, Zeilen-, Detail- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        BEGIN TRY
            SELECT @SqlServerStartTime = [sqlserver_start_time]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);

            INSERT [#InternalContentionAnalysis_LatchStart]
            SELECT [latch_class], [waiting_requests_count], [wait_time_ms], [max_wait_time_ms]
            FROM [sys].[dm_os_latch_stats] WITH (NOLOCK);

            IF @MitSpinlocks = 1
            BEGIN
                INSERT [#InternalContentionAnalysis_SpinStart]
                SELECT [name], [collisions], [spins], [sleep_time], [backoffs]
                FROM [sys].[dm_os_spinlock_stats] WITH (NOLOCK);
            END;

            SET @SampleStartUtc = SYSUTCDATETIME();
            IF @SampleSeconds > 0
            BEGIN
                SET @Delay = CONVERT(varchar(8),
                    DATEADD(SECOND,@SampleSeconds,CONVERT(datetime,'19000101')),108);
                WAITFOR DELAY @Delay;
            END;
            SET @SampleEndUtc = SYSUTCDATETIME();
            SET @ActualSampleSeconds = CONVERT
            (
                decimal(19,6),
                DATEDIFF_BIG(MICROSECOND, @SampleStartUtc, @SampleEndUtc) / 1000000.0
            );

            INSERT [#InternalContentionAnalysis_LatchEnd]
            SELECT [latch_class], [waiting_requests_count], [wait_time_ms], [max_wait_time_ms]
            FROM [sys].[dm_os_latch_stats] WITH (NOLOCK);

            IF @MitSpinlocks = 1
            BEGIN
                INSERT [#InternalContentionAnalysis_SpinEnd]
                SELECT [name], [collisions], [spins], [sleep_time], [backoffs]
                FROM [sys].[dm_os_spinlock_stats] WITH (NOLOCK);
            END;

            ;WITH [LatchStart] AS
            (
                SELECT [LatchClass],SUM([WaitingRequestsCount]) AS [WaitingRequestsCount],
                       SUM([WaitTimeMs]) AS [WaitTimeMs],MAX([MaxWaitTimeMs]) AS [MaxWaitTimeMs]
                FROM [#InternalContentionAnalysis_LatchStart] GROUP BY [LatchClass]
            ),
            [LatchEnd] AS
            (
                SELECT [LatchClass],SUM([WaitingRequestsCount]) AS [WaitingRequestsCount],
                       SUM([WaitTimeMs]) AS [WaitTimeMs],MAX([MaxWaitTimeMs]) AS [MaxWaitTimeMs]
                FROM [#InternalContentionAnalysis_LatchEnd] GROUP BY [LatchClass]
            )
            INSERT [#InternalContentionAnalysis_LatchResult]
            SELECT
                  [e].[LatchClass]
                , CASE WHEN @SampleSeconds = 0 THEN 'CUMULATIVE_SINCE_START' ELSE 'SAMPLE_DELTA' END
                , [Waiting].[CounterValue]
                , [WaitTime].[CounterValue]
                , [e].[MaxWaitTimeMs]
                , [Waiting].[RatePerSecond]
                , [WaitTime].[RatePerSecond]
                , CONVERT(bit,CASE WHEN [Waiting].[CounterResetDetected]=1
                                      OR [WaitTime].[CounterResetDetected]=1 THEN 1 ELSE 0 END)
            FROM [LatchEnd] AS [e]
            JOIN [LatchStart] AS [s] ON [s].[LatchClass] = [e].[LatchClass]
            CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
            ([s].[WaitingRequestsCount],[e].[WaitingRequestsCount],@SampleSeconds,@ActualSampleSeconds) AS [Waiting]
            CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
            ([s].[WaitTimeMs],[e].[WaitTimeMs],@SampleSeconds,@ActualSampleSeconds) AS [WaitTime]
            WHERE (@SampleSeconds = 0 AND [e].[WaitTimeMs] > 0)
               OR (@SampleSeconds > 0 AND ([e].[WaitTimeMs] <> [s].[WaitTimeMs]
                                           OR [e].[WaitingRequestsCount] <> [s].[WaitingRequestsCount]));

            IF @MitSpinlocks = 1
            BEGIN
                ;WITH [SpinStart] AS
                (
                    SELECT [SpinlockName],SUM([Collisions]) AS [Collisions],SUM([Spins]) AS [Spins],
                           SUM([SleepTime]) AS [SleepTime],SUM([Backoffs]) AS [Backoffs]
                    FROM [#InternalContentionAnalysis_SpinStart] GROUP BY [SpinlockName]
                ),
                [SpinEnd] AS
                (
                    SELECT [SpinlockName],SUM([Collisions]) AS [Collisions],SUM([Spins]) AS [Spins],
                           SUM([SleepTime]) AS [SleepTime],SUM([Backoffs]) AS [Backoffs]
                    FROM [#InternalContentionAnalysis_SpinEnd] GROUP BY [SpinlockName]
                )
                INSERT [#InternalContentionAnalysis_SpinResult]
                SELECT
                      [e].[SpinlockName]
                    , CASE WHEN @SampleSeconds = 0 THEN 'CUMULATIVE_SINCE_START' ELSE 'SAMPLE_DELTA' END
                    , [Collision].[CounterValue]
                    , [Spin].[CounterValue]
                    , [Sleep].[CounterValue]
                    , [Backoff].[CounterValue]
                    , [Collision].[RatePerSecond]
                    , [Backoff].[RatePerSecond]
                    , CONVERT(bit,CASE WHEN [Collision].[CounterResetDetected]=1
                                           OR [Spin].[CounterResetDetected]=1
                                           OR [Sleep].[CounterResetDetected]=1
                                           OR [Backoff].[CounterResetDetected]=1 THEN 1 ELSE 0 END)
                FROM [SpinEnd] AS [e]
                JOIN [SpinStart] AS [s] ON [s].[SpinlockName] = [e].[SpinlockName]
                CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
                ([s].[Collisions],[e].[Collisions],@SampleSeconds,@ActualSampleSeconds) AS [Collision]
                CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
                ([s].[Spins],[e].[Spins],@SampleSeconds,@ActualSampleSeconds) AS [Spin]
                CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
                ([s].[SleepTime],[e].[SleepTime],@SampleSeconds,@ActualSampleSeconds) AS [Sleep]
                CROSS APPLY [monitor].[TVF_InterpretContentionCounter]
                ([s].[Backoffs],[e].[Backoffs],@SampleSeconds,@ActualSampleSeconds) AS [Backoff]
                WHERE (@SampleSeconds = 0 AND [e].[Collisions] > 0)
                   OR (@SampleSeconds > 0 AND ([e].[Collisions] <> [s].[Collisions]
                                               OR [e].[Spins] <> [s].[Spins]
                                               OR [e].[SleepTime] <> [s].[SleepTime]
                                               OR [e].[Backoffs] <> [s].[Backoffs]));
            END;

            IF @MitHotPages = 1
            BEGIN
                INSERT [#InternalContentionAnalysis_HotPages]
                (
                      [SessionId], [DatabaseId], [DatabaseName], [WaitType]
                    , [WaitTimeMs], [WaitResource], [FileId], [PageId]
                )
                SELECT
                      [r].[session_id], [r].[database_id], (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = [r].[database_id])
                    , [r].[wait_type], [r].[wait_time], [r].[wait_resource]
                    , TRY_CONVERT(int, PARSENAME(REPLACE([r].[wait_resource], N':', N'.'), 2))
                    , TRY_CONVERT(bigint, PARSENAME(REPLACE([r].[wait_resource], N':', N'.'), 1))
                FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
                WHERE [r].[session_id] <> @@SPID
                  AND ([r].[wait_type] LIKE N'PAGELATCH%'
                       OR [r].[wait_type] LIKE N'PAGEIOLATCH%');

                IF @MitPageDetails = 1
                BEGIN
                    UPDATE [h]
                    SET [PageTypeDesc] = [p].[page_type_desc],
                        [ObjectId] = [p].[object_id],
                        [IndexId] = [p].[index_id]
                    FROM [#InternalContentionAnalysis_HotPages] AS [h]
                    OUTER APPLY [sys].[dm_db_page_info]
                    ([h].[DatabaseId], [h].[FileId], [h].[PageId], 'LIMITED') AS [p]
                    WHERE [h].[DatabaseId] IS NOT NULL
                      AND [h].[FileId] IS NOT NULL
                      AND [h].[PageId] IS NOT NULL;
                END;
            END;
        END TRY
        BEGIN CATCH
            SELECT @StatusCode = CASE WHEN ERROR_NUMBER() IN (229, 297, 300, 371)
                                      THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                   @IsPartial = 1, @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = ERROR_MESSAGE();
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND EXISTS
           (
               SELECT 1 FROM [#InternalContentionAnalysis_LatchResult] WHERE [CounterResetDetected] = 1
               UNION ALL
               SELECT 1 FROM [#InternalContentionAnalysis_SpinResult] WHERE [CounterResetDetected] = 1
               UNION ALL
               SELECT 1 FROM [#InternalContentionAnalysis_HotPages]
           )
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'InternalContentionAnalysis' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode], @IsPartial AS [isPartial],
                    @SampleSeconds AS [requestedSampleSeconds], @ActualSampleSeconds AS [actualSampleSeconds],
                    @SqlServerStartTime AS [sqlServerStartTime]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        DECLARE @LatchJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_LatchResult]
             ORDER BY [WaitTimeMs] DESC, [LatchClass] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SpinJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_SpinResult]
             ORDER BY [Collisions] DESC, [SpinlockName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @HotJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_HotPages]
             ORDER BY [WaitTimeMs] DESC, [SessionId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"latches":', COALESCE(@LatchJson, N'[]'),
                           N',"spinlocks":', COALESCE(@SpinJson, N'[]'),
                           N',"hotPages":', COALESCE(@HotJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_InternalContentionAnalysis' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @SampleSeconds AS [RequestedSampleSeconds], @ActualSampleSeconds AS [ActualSampleSeconds],
               @SqlServerStartTime AS [SqlServerStartTime],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Intervalldeltas bei SampleSeconds>0; sonst kumulativ seit Serverstart.' AS [Detail];
        SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_LatchResult] ORDER BY [WaitTimeMs] DESC, [LatchClass];
        SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_SpinResult] ORDER BY [Collisions] DESC, [SpinlockName];
        SELECT TOP (@Limit) * FROM [#InternalContentionAnalysis_HotPages] ORDER BY [WaitTimeMs] DESC, [SessionId];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Interne Contention' AS [Ergebnis], @Now AS [Stand_UTC], @StatusCode AS [Status],
               @SampleSeconds AS [Angeforderte_Messdauer_Sekunden],
               @ActualSampleSeconds AS [Tatsaechliche_Messdauer_Sekunden],
               CASE WHEN @SampleSeconds = 0 THEN N'Kumulativ seit Serverstart' ELSE N'Intervall-Delta' END AS [Messart],
               @ErrorMessage AS [Hinweis];
        SELECT TOP (@Limit) N'Latch' AS [Ergebnis], [LatchClass] AS [Klasse],
               [WaitingRequests] AS [Wartevorgaenge], [WaitTimeMs] AS [Wartezeit_ms],
               [WaitsPerSecond] AS [Wartevorgaenge_pro_s], [WaitMsPerSecond] AS [Wartezeit_ms_pro_s],
               [CounterResetDetected] AS [Reset_erkannt]
        FROM [#InternalContentionAnalysis_LatchResult] ORDER BY [WaitTimeMs] DESC, [LatchClass];
        SELECT TOP (@Limit) N'Spinlock' AS [Ergebnis], [SpinlockName] AS [Name],
               [Collisions], [Backoffs], [CollisionsPerSecond] AS [Kollisionen_pro_s],
               [BackoffsPerSecond] AS [Backoffs_pro_s], [CounterResetDetected] AS [Reset_erkannt]
        FROM [#InternalContentionAnalysis_SpinResult] ORDER BY [Collisions] DESC, [SpinlockName];
        SELECT TOP (@Limit) N'Hot Page' AS [Ergebnis], [SessionId] AS [Session_ID],
               [DatabaseName] AS [Datenbank], [WaitType] AS [Wait_Typ], [WaitTimeMs] AS [Wartezeit_ms],
               [FileId] AS [Datei_ID], [PageId] AS [Seiten_ID], [PageTypeDesc] AS [Seitentyp],
               [ObjectId] AS [Objekt_ID], [IndexId] AS [Index_ID]
        FROM [#InternalContentionAnalysis_HotPages] ORDER BY [WaitTimeMs] DESC, [SessionId];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#InternalContentionAnalysis_LatchResult'
            , @ResultLabel=N'InternalContentionAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#InternalContentionAnalysis_LatchResult'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
