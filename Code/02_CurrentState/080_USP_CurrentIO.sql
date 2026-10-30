USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentIO
Version      : 4.0.0
Stand        : 2026-07-23
Zweck        : Führt eine leichtgewichtige serverweite Datei-I/O-Analyse mit
               optionalem Delta-Sampling und expliziter
               Datenbankeinschränkung durch.
Datenbanken  : Standardmäßig alle sichtbaren, online befindlichen
               Benutzerdatenbanken; kein CURRENT-Scope und keine Vorabgrenze.
DMV-Zugriff  : sys.dm_io_virtual_file_stats(NULL,NULL) genau einmal je
               Messzeitpunkt; keine Wiederholung pro Datenbank.
Pending I/O  : Optional zwei Beobachtungen derselben aktuell ausstehenden
               Requestadresse. Scheduler-/Taskbezug ist Kontext, keine kausale
               1:1-Zuordnung. io_pending_ms_ticks ist informational/internal.
Ausgabe      : CONSOLE ein gemeinsames Evidenz-Grid; RAW und TABLE verwenden
               moduleStatus, sourceStatus, files, pendingIo und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentIO]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MinLatencyMs                   decimal(19,3)  = 0
    , @SampleSeconds                  tinyint         = 0
    , @PendingIoEinbeziehen           bit             = 1
    , @NurWiederholtPending           bit             = 0
    , @MinPendingIoMs                 bigint          = 0
    , @PhysischePfadeEinbeziehen      bit             = 0
    , @MaxZeilen                      int             = 1000
    , @ResultSetArt                   varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)   = NULL
    , @JsonErzeugen                   bit             = 0
    , @Json                           nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                 bit             = 1
    , @Hilfe                          bit             = 0
    , @ParentCurrentStateSnapshotId   uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,N''))));
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint,9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint,@MaxZeilen)
             ELSE CONVERT(bigint,0) END;
    DECLARE @CandidateLimit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint,9223372036854775807)
             WHEN @MaxZeilen BETWEEN 1 AND 2147483646
             THEN CONVERT(bigint,@MaxZeilen) + 1
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint,@MaxZeilen)
             ELSE CONVERT(bigint,0) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentIO — Datei-I/O-Sicht für sichtbare Online-Datenbanken.';
        PRINT N'Quellen: master.sys.databases/master_files, sys.dm_io_virtual_file_stats (ein Aufruf je Messpunkt), optional dm_io_pending_io_requests sowie Scheduler-/Request-/Task-/Wait-Kontext. Der Datenbankfilter beschränkt behaltene Zeilen, nicht den instanzweiten DMV-Aufruf.';
        PRINT N'Für den Aufruf gelten EXECUTE-Recht und die installierte STANDARD_CURRENT-Zugriffsrichtlinie; erforderliche DMV-Rechte hängen von SQL Server-Version und Konfiguration ab. Rechte werden nicht vergeben. Abgefangene Fehler stehen in Status/Quellstatus und können die Ausgabe partiell machen.';
        PRINT N'@DatabaseNames nvarchar(max), Default=NULL; Eingabe: bracket-aware Pipe-Liste exakter, einteiliger Datenbanknamen, z. B. N''[DbA]|[DbB]''; Namen werden case-sensitive verglichen. Ausgelassen/NULL/leer/nur Leerzeichen wählt alle sichtbaren, zugreifbaren, ONLINE befindlichen Benutzerdatenbanken; doppelte oder ungültige Namen erzeugen Auswahlfehler/Warnings, Systemdatenbanken benötigen das Opt-in. Exklusiv mit @DatabaseNamePattern. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].';
        PRINT N'@SystemdatenbankenEinbeziehen bit, Default=0; Schalter: 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren, zugreifbaren ONLINE Datenbanken zusätzlich. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER.';
        PRINT N'@DatabaseNamePattern nvarchar(4000), Default=NULL; Eingabe: genau ein nichtleeres Pattern, exklusiv mit @DatabaseNames. Kein Präfix oder like: bedeutet case-sensitive SQL-LIKE mit %, _, [...]; regex: case-sensitive regulärer Ausdruck; regexi: case-insensitive regulärer Ausdruck. Präfixerkennung ist case-insensitive, äußere Leerzeichen werden entfernt, Patterninhalt bleibt erhalten. NULL/ausgelassen deaktiviert, leer/Whitespace/Präfix ohne Pattern ist ungültig. regex/regexi benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.';
        PRINT N'Bit-Parameter werden vor Eintritt in die Procedure in bit konvertiert; numerische Werte ungleich 0 werden dabei zu 1. Die beschriebenen NULL-Prüfungen gelten für den bereits konvertierten Wert.';
        PRINT N'@HighImpactConfirmed bit, Default=0; numerischer Schalter: 0/ausgelassen bestätigt nicht, jeder numerische Wert ungleich 0 wird vor Eintritt zu 1 und bestätigt dann. NULL wird wegen ungenutztem Parameter nicht geprüft. Dieser Parameter wird von dieser Procedure nicht gelesen/weitergereicht; tatsächlicher Zugriff bleibt STANDARD_CURRENT ohne High-Impact-Bestätigungsprüfung.';
        PRINT N'@MinLatencyMs decimal(19,3), Default=0 ms; nichtnegative Mindest-Durchschnittslatenz je Datei aus kumulativen Zählern oder Sample-Deltas. Ausgelassen verwendet 0; NULL oder negativer Wert ist INVALID_PARAMETER. Bei null Lese- und Schreiboperationen ist OverallLatencyMs NULL und besteht den Filter nicht.';
        PRINT N'@SampleSeconds tinyint, Default=0 Sekunden; ganze Zahl 0..60. 0 nutzt kumulative Counter und einen Pending-Punkt; 1..60 wartet per WAITFOR DELAY zwischen zwei Dateimessungen und bildet Deltas sowie zwei Pending-Beobachtungen. Ausgelassen nutzt 0; NULL ist INVALID_PARAMETER. Laufzeit/Scheduling können Abstand verlängern; Counterreset erhält keinen eigenen Resetstatus.';
        PRINT N'@PendingIoEinbeziehen bit, Default=1; 1 liest Pending-I/O und Schedulerkontext, 0 überspringt beide Quellen und liefert leere Pending-Menge. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Quellfehler lassen Dateiwerte bestehen und können Status/IsPartial setzen.';
        PRINT N'@NurWiederholtPending bit, Default=0; 1 verlangt dieselbe Requestadresse in beiden Beobachtungen und setzt @SampleSeconds=1..60 voraus; 0 genügt Sichtbarkeit am letzten Messpunkt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Bei 0-Sample ist Wiederholung nicht nachgewiesen.';
        PRINT N'@MinPendingIoMs bigint, Default=0 ms; nichtnegative Untergrenze für dm_io_pending_io_requests.PendingDurationMs, informational/internal Enginewert. Ausgelassen ergibt 0; NULL oder negativ ist INVALID_PARAMETER. Einzelwert beweist weder Fehler noch Ursache.';
        PRINT N'@PhysischePfadeEinbeziehen bit, Default=0; 1 gibt pendingIo.PhysicalPath aus, wenn auflösbar; 0 unterdrückt dieses optionale Pfadfeld, während files.PhysicalName bleibt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER.';
        PRINT N'@MaxZeilen int, Default=1000 Zeilen; ganze Zahl 0..2147483647. NULL oder 0 ist unbegrenzt; positiv begrenzt Datei- und Pending-Kandidaten getrennt nach ihrer Sortierung (N+1-Prüfung), CONSOLE zusätzlich mit gemeinsamem TOP, Pending zuerst. Negativ ist INVALID_PARAMETER. Ausgelassen ergibt 1000; beschränkt nicht die instanzweite DMV-Erhebung.';
        PRINT N'@ResultSetArt varchar(16), Default=''CONSOLE''; nach Trim/UPPER taxativ CONSOLE (gemeinsames 10-Spalten-Evidenzgrid), RAW (moduleStatus 13, sourceStatus 10, files 19, pendingIo 20, warnings 3 Spalten), TABLE (nur angeforderte benannte Temp-Tabellenexporte), NONE (keine Resultsets). Ausgelassen ergibt CONSOLE; NULL/leer normalisiert zu '''' und ist ungültig. Andere Werte INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max), Default=NULL; nur TABLE: JSON-Objekt mit einer nichtleeren Teilmenge der exakten Keys moduleStatus (Modulstatus), sourceStatus (Quellstatus), files (Dateimessungen), pendingIo (offene E/A-Anforderungen), warnings (Warnungen); jeder Wert ist ein lokaler #Temp-Zielname als JSON-String. Ziel muss vorhanden und leer sein und genau eine Seed-Platzhalterspalte besitzen; Zuordnung wird vor semantischer Parameterprüfung validiert, ungültig wirft 51011. Bei anderem Modus nur NULL/leer, sonst 51011. Ausgelassen/NULL oder leer ist nur außerhalb TABLE zulässig; TABLE benötigt die nichtleere Zuordnung.';
        PRINT N'@JsonErzeugen bit, Default=0; 1 erzeugt zusätzlich JSON unabhängig von @ResultSetArt; 0 deaktiviert es. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. JSON enthält meta, sourceStatus, files, pendingIo, warnings, aber kein moduleStatus-Array.';
        PRINT N'@Json nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable gleichen Typs, beim Aufruf mit OUTPUT zu binden. Procedure setzt sie beim Eintritt auf NULL; bei @JsonErzeugen=1 empfängt sie das Dokument, bei 0 bleibt sie NULL. Ausgelassen ist zulässig, wenn JSON-Ausgabe nicht benötigt wird.';
        PRINT N'@PrintMeldungen bit, Default=1; 1 sendet Severity-10-Status-/Quellmeldungen, 0 unterdrückt nur Meldungen. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Status, Resultsets, Warnings und JSON bleiben davon unberührt.';
        PRINT N'@Hilfe bit, Default=0; 1 druckt Hilfe und kehrt vor Parameter-, Snapshot- und Fachquellenprüfung zurück; @Json wird zuvor auf NULL gesetzt. 0 führt Normalpfad aus. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Numerische Eingaben werden vor Eintritt in bit konvertiert, jeder Wert ungleich 0 wird 1.';
        PRINT N'@ParentCurrentStateSnapshotId uniqueidentifier, Default=NULL; NULL/ausgelassen erhebt Kontext direkt. GUID muss zur laufenden USP_CurrentOverview-Ausführung derselben Session (OwnerSessionId=@@SPID, ContractVersion=2) gehören; sonst INVALID_PARENT_SNAPSHOT. Bei gültiger ID und aktiviertem Pending stammen Kontext und Startzeit vom Parent, Datei-/Pending-DMVs bleiben live.';
        PRINT N'Modulstatus AVAILABLE bedeutet verfügbare Quellen ohne Auswahlwarnungen; AVAILABLE_LIMITED kennzeichnet Auswahl- oder Pending-Kontextlücken. INVALID_PARAMETER und INVALID_PARENT_SNAPSHOT lehnen die Fachauswertung ab; Quellfehler werden als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED ausgewiesen. Regex auf älteren Engines/Kompatibilitätsstufen liefert UNAVAILABLE_FEATURE.';
        PRINT N'NULL-Werte in Parametern, die explizit validiert werden, führen zu INVALID_PARAMETER; @HighImpactConfirmed ist die Ausnahme, weil es ungenutzt bleibt. Fehlerhafte Datenbankauswahl liefert Status/Warnings; partielle Quellfehler sind in sourceStatus und IsPartial erkennbar. Ein leeres Resultset beweist nicht, dass keine I/O-Aktivität stattfand.';
        PRINT N'Beispiel — CONSOLE im Standard-Datenbankscope:';
        PRINT N'EXEC [monitor].[USP_CurrentIO] @SampleSeconds=5, @MaxZeilen=100, @ResultSetArt=''CONSOLE'';';
        PRINT N'Beispiel — TABLE, nur files; Ziel vorab frisch anlegen, danach lesen und entfernen:';
        PRINT N'CREATE TABLE #CurrentIO_HelpExample (Placeholder int NULL);';
        PRINT N'EXEC [monitor].[USP_CurrentIO] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"files":"#CurrentIO_HelpExample"}'';';
        PRINT N'SELECT * FROM #CurrentIO_HelpExample;';
        PRINT N'DROP TABLE #CurrentIO_HelpExample;';
        PRINT N'Beispiel — JSON ohne Resultsets; @Json bleibt als OUTPUT verfügbar:';
        PRINT N'DECLARE @CurrentIO_HelpJson nvarchar(max);';
        PRINT N'EXEC [monitor].[USP_CurrentIO] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@CurrentIO_HelpJson OUTPUT;';
        PRINT N'SELECT @CurrentIO_HelpJson AS [CurrentIOJson];';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @WarningCount bigint = 0;
    DECLARE @PendingRowCount bigint = 0;
    DECLARE @PendingHasMoreRows bit = 0;
    DECLARE @FileSourceStatus varchar(40) = 'NOT_EXECUTED';
    DECLARE @FileSourceErrorNumber int = NULL;
    DECLARE @FileSourceErrorMessage nvarchar(2048) = NULL;
    DECLARE @PendingSourceStatus varchar(40) = 'NOT_REQUESTED';
    DECLARE @PendingSourceErrorNumber int = NULL;
    DECLARE @PendingSourceErrorMessage nvarchar(2048) = NULL;
    DECLARE @PendingContextStatus varchar(40) = 'NOT_REQUESTED';
    DECLARE @PendingContextErrorNumber int = NULL;
    DECLARE @PendingContextErrorMessage nvarchar(2048) = NULL;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);
    DECLARE @Delay char(8);
    DECLARE @EvidenceSnapshotId uniqueidentifier=COALESCE(@ParentCurrentStateSnapshotId,NEWID());
    DECLARE @EvidenceSnapshotStartedAtUtc datetime2(3)=@CollectionTimeUtc;

    CREATE TABLE [#CurrentIO_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );

    CREATE TABLE [#CurrentIO_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );

    CREATE TABLE [#CurrentIO_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentIO_Before]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [SampleMs] bigint NULL
        , [Reads] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [SizeOnDiskBytes] bigint NOT NULL
        , [FileHandle] varbinary(8) NULL
        , PRIMARY KEY ([DatabaseId],[FileId])
    );

    CREATE TABLE [#CurrentIO_After]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [SampleMs] bigint NULL
        , [Reads] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [SizeOnDiskBytes] bigint NOT NULL
        , [FileHandle] varbinary(8) NULL
        , PRIMARY KEY ([DatabaseId],[FileId])
    );

    CREATE TABLE [#CurrentIO_Result]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FileId] int NOT NULL
        , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SampleSeconds] int NOT NULL
        , [Reads] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [ReadLatencyMs] decimal(19,3) NULL
        , [WriteLatencyMs] decimal(19,3) NULL
        , [OverallLatencyMs] decimal(19,3) NULL
        , [ReadThroughputMbPerSecond] decimal(19,3) NULL
        , [WriteThroughputMbPerSecond] decimal(19,3) NULL
        , [SizeOnDiskMb] decimal(19,2) NULL
    );

    CREATE TABLE [#CurrentIO_PendingBefore]
    (
          [RequestAddress] varbinary(8) NOT NULL PRIMARY KEY
        , [IoType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PendingDurationMs] bigint NOT NULL
        , [IoPending] int NOT NULL
        , [SchedulerAddress] varbinary(8) NOT NULL
        , [IoHandle] varbinary(8) NULL
        , [IoOffset] bigint NOT NULL
        , [IoHandlePath] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentIO_PendingAfter]
    (
          [RequestAddress] varbinary(8) NOT NULL PRIMARY KEY
        , [IoType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PendingDurationMs] bigint NOT NULL
        , [IoPending] int NOT NULL
        , [SchedulerAddress] varbinary(8) NOT NULL
        , [IoHandle] varbinary(8) NULL
        , [IoOffset] bigint NOT NULL
        , [IoHandlePath] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentIO_SchedulerContext]
    (
          [SchedulerAddress] varbinary(8) NOT NULL PRIMARY KEY
        , [SchedulerId] int NOT NULL
        , [RequestCountOnScheduler] int NOT NULL
        , [IoWaitTaskCountOnScheduler] int NOT NULL
    );
    CREATE TABLE [#CurrentIO_SourceRequests]
    (
          [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [scheduler_id] int NULL
        , PRIMARY KEY([session_id],[request_id])
    );
    CREATE TABLE [#CurrentIO_SourceTasks]
    (
          [task_address] varbinary(8) NOT NULL PRIMARY KEY
        , [scheduler_id] int NULL
    );
    CREATE TABLE [#CurrentIO_SourceWaitingTasks]
    (
          [waiting_task_address] varbinary(8) NOT NULL
        , [wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CurrentIO_SourceSchedulers]
    (
          [scheduler_address] varbinary(8) NOT NULL PRIMARY KEY
        , [scheduler_id] int NOT NULL
    );

    CREATE TABLE [#CurrentIO_PendingResult]
    (
          [CapturedAtUtc] datetime2(3) NOT NULL
        , [RequestAddress] varbinary(8) NOT NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileId] int NULL
        , [LogicalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PhysicalPath] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IoType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PendingLayer] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PendingDurationMs] bigint NOT NULL
        , [SchedulerId] int NULL
        , [RequestCountOnScheduler] int NULL
        , [IoWaitTaskCountOnScheduler] int NULL
        , [WasPresentInFirstSample] bit NOT NULL
        , [ObservationCount] tinyint NOT NULL
        , [FirstSamplePendingMs] bigint NULL
        , [IoOffset] bigint NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CorrelationScope] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#CurrentIO_SourceStatus]
    (
          [SourceOrdinal] int NOT NULL PRIMARY KEY
        , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#CurrentIO_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [HasMoreRows] bit NOT NULL
        , [CrossDatabaseRequested] bit NOT NULL
        , [SampleSeconds] tinyint NOT NULL
        , [PendingIoRequested] bit NOT NULL
        , [PendingIoRowCount] bigint NOT NULL
        , [PendingIoHasMoreRows] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    /* TempDB-DDL bleibt außerhalb des bewussten No-Wait-Quellzugriffs. */
    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE' AND @OutputMode = 'TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson = @ResultTablesJson
            , @AllowedResultNames = N'moduleStatus|sourceStatus|files|pendingIo|warnings'
            , @MappingTable = N'#CurrentIO_ResultTableMap'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @ThrowOnError = 1;
    END;

    IF @MaxZeilen < 0
       OR @MinLatencyMs IS NULL OR @MinLatencyMs < 0
       OR @SampleSeconds IS NULL OR @SampleSeconds > 60
       OR @PendingIoEinbeziehen IS NULL OR @NurWiederholtPending IS NULL
       OR @PhysischePfadeEinbeziehen IS NULL OR @MinPendingIoMs IS NULL OR @MinPendingIoMs < 0
       OR @SystemdatenbankenEinbeziehen IS NULL OR @PrintMeldungen IS NULL
       OR (@NurWiederholtPending = 1 AND @SampleSeconds = 0)
       OR @OutputMode NOT IN ('RAW','CONSOLE','TABLE','NONE')
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR (@OutputMode <> 'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode='AVAILABLE' AND @ParentCurrentStateSnapshotId IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC [sys].[sp_executesql] N'
                DECLARE @Probe int;
                SELECT @Probe=0
                FROM [#CurrentOverview_CurrentStateSnapshot_Context]
                WHERE 1=0;';

            IF NOT EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_CurrentStateSnapshot_Context]
                WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                  AND [OwnerSessionId]=CONVERT(smallint,@@SPID)
                  AND [ContractVersion]=2
            )
                THROW 51020,N'Die Parent-Snapshot-ID gehört nicht zum aktuellen Aufruf.',1;
        END TRY
        BEGIN CATCH
            SET @StatusCode='INVALID_PARENT_SNAPSHOT';
            SET @IsPartial=1;
            SET @ErrorNumber=ERROR_NUMBER();
            SET @ErrorMessage=ERROR_MESSAGE();
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern
            , @AnalysisClass = 'STANDARD_CURRENT'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
            , @CandidateTable = N'#CurrentIO_DatabaseCandidates'
            , @WarningTable = N'#CurrentIO_DatabaseCandidateWarnings';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#CurrentIO_Before]
        (
              [DatabaseId],[FileId],[SampleMs],[Reads],[ReadStallMs]
            , [ReadBytes],[Writes],[WriteStallMs],[WriteBytes],[SizeOnDiskBytes]
            , [FileHandle]
        )
        SELECT
              [v].[database_id],[v].[file_id],[v].[sample_ms]
            , [v].[num_of_reads],[v].[io_stall_read_ms],[v].[num_of_bytes_read]
            , [v].[num_of_writes],[v].[io_stall_write_ms],[v].[num_of_bytes_written]
            , [v].[size_on_disk_bytes],[v].[file_handle]
        FROM [sys].[dm_io_virtual_file_stats](NULL,NULL) AS [v]
        INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
          ON [c].[DatabaseId] = [v].[database_id];

        SET @FileSourceStatus='AVAILABLE';

        IF @PendingIoEinbeziehen=1
        BEGIN TRY
            INSERT [#CurrentIO_PendingBefore]
            (
                  [RequestAddress],[IoType],[PendingDurationMs],[IoPending]
                , [SchedulerAddress],[IoHandle],[IoOffset],[IoHandlePath]
            )
            SELECT
                  [p].[io_completion_request_address],[p].[io_type]
                , [p].[io_pending_ms_ticks],[p].[io_pending]
                , [p].[scheduler_address],[p].[io_handle],[p].[io_offset]
                , [p].[io_handle_path]
            FROM [sys].[dm_io_pending_io_requests] AS [p] WITH (NOLOCK);
            SET @PendingSourceStatus='AVAILABLE';
        END TRY
        BEGIN CATCH
            SELECT @PendingSourceStatus=CASE
                       WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                       WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                   @PendingSourceErrorNumber=ERROR_NUMBER(),
                   @PendingSourceErrorMessage=ERROR_MESSAGE();
        END CATCH;

        IF @SampleSeconds > 0
        BEGIN
            SET @Delay = CONVERT(char(8),DATEADD(SECOND,@SampleSeconds,CONVERT(time(0),'00:00:00')),108);
            WAITFOR DELAY @Delay;

            INSERT [#CurrentIO_After]
            (
                  [DatabaseId],[FileId],[SampleMs],[Reads],[ReadStallMs]
                , [ReadBytes],[Writes],[WriteStallMs],[WriteBytes],[SizeOnDiskBytes]
                , [FileHandle]
            )
            SELECT
                  [v].[database_id],[v].[file_id],[v].[sample_ms]
                , [v].[num_of_reads],[v].[io_stall_read_ms],[v].[num_of_bytes_read]
                , [v].[num_of_writes],[v].[io_stall_write_ms],[v].[num_of_bytes_written]
                , [v].[size_on_disk_bytes],[v].[file_handle]
            FROM [sys].[dm_io_virtual_file_stats](NULL,NULL) AS [v]
            INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId] = [v].[database_id];

            IF @PendingSourceStatus='AVAILABLE'
            BEGIN TRY
                INSERT [#CurrentIO_PendingAfter]
                (
                      [RequestAddress],[IoType],[PendingDurationMs],[IoPending]
                    , [SchedulerAddress],[IoHandle],[IoOffset],[IoHandlePath]
                )
                SELECT
                      [p].[io_completion_request_address],[p].[io_type]
                    , [p].[io_pending_ms_ticks],[p].[io_pending]
                    , [p].[scheduler_address],[p].[io_handle],[p].[io_offset]
                    , [p].[io_handle_path]
                FROM [sys].[dm_io_pending_io_requests] AS [p] WITH (NOLOCK);
            END TRY
            BEGIN CATCH
                SELECT @PendingSourceStatus=CASE
                           WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                           WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                       @PendingSourceErrorNumber=ERROR_NUMBER(),
                       @PendingSourceErrorMessage=ERROR_MESSAGE();
            END CATCH;
        END
        ELSE
        BEGIN
            INSERT [#CurrentIO_After]
            SELECT * FROM [#CurrentIO_Before];

            IF @PendingSourceStatus='AVAILABLE'
                INSERT [#CurrentIO_PendingAfter]
                SELECT * FROM [#CurrentIO_PendingBefore];
        END;

        INSERT [#CurrentIO_Result]
        (
              [DatabaseId],[DatabaseName],[FileId],[LogicalName],[PhysicalName]
            , [FileTypeDesc],[SampleSeconds],[Reads],[ReadBytes],[ReadStallMs]
            , [Writes],[WriteBytes],[WriteStallMs],[ReadLatencyMs]
            , [WriteLatencyMs],[OverallLatencyMs],[ReadThroughputMbPerSecond]
            , [WriteThroughputMbPerSecond],[SizeOnDiskMb]
        )
        SELECT TOP (@CandidateLimit)
              [b].[DatabaseId]
            , [c].[DatabaseName]
            , [b].[FileId]
            , [mf].[name]
            , [mf].[physical_name]
            , [mf].[type_desc]
            , @SampleSeconds
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Reads]-[b].[Reads] ELSE [a].[Reads] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadBytes]-[b].[ReadBytes] ELSE [a].[ReadBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs]-[b].[ReadStallMs] ELSE [a].[ReadStallMs] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Writes]-[b].[Writes] ELSE [a].[Writes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteBytes]-[b].[WriteBytes] ELSE [a].[WriteBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs]-[b].[WriteStallMs] ELSE [a].[WriteStallMs] END
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs]-[b].[ReadStallMs] ELSE [a].[ReadStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Reads]-[b].[Reads] ELSE [a].[Reads] END,0))
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs]-[b].[WriteStallMs] ELSE [a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Writes]-[b].[Writes] ELSE [a].[Writes] END,0))
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0
                      THEN ([a].[ReadStallMs]-[b].[ReadStallMs])+([a].[WriteStallMs]-[b].[WriteStallMs])
                      ELSE [a].[ReadStallMs]+[a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0
                              THEN ([a].[Reads]-[b].[Reads])+([a].[Writes]-[b].[Writes])
                              ELSE [a].[Reads]+[a].[Writes] END,0)) AS [OverallLatencyMs]
            , CONVERT(decimal(19,3),CASE WHEN @SampleSeconds > 0
                     THEN ([a].[ReadBytes]-[b].[ReadBytes])/1048576.0/NULLIF(@SampleSeconds,0) END)
            , CONVERT(decimal(19,3),CASE WHEN @SampleSeconds > 0
                     THEN ([a].[WriteBytes]-[b].[WriteBytes])/1048576.0/NULLIF(@SampleSeconds,0) END)
            , CONVERT(decimal(19,2),[a].[SizeOnDiskBytes]/1048576.0)
        FROM [#CurrentIO_Before] AS [b]
        INNER JOIN [#CurrentIO_After] AS [a]
          ON [a].[DatabaseId]=[b].[DatabaseId]
         AND [a].[FileId]=[b].[FileId]
        INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
          ON [c].[DatabaseId]=[b].[DatabaseId]
        LEFT JOIN [master].[sys].[master_files] AS [mf] WITH (NOLOCK)
          ON [mf].[database_id]=[b].[DatabaseId]
         AND [mf].[file_id]=[b].[FileId]
        WHERE CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0
                      THEN ([a].[ReadStallMs]-[b].[ReadStallMs])+([a].[WriteStallMs]-[b].[WriteStallMs])
                      ELSE [a].[ReadStallMs]+[a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0
                              THEN ([a].[Reads]-[b].[Reads])+([a].[Writes]-[b].[Writes])
                              ELSE [a].[Reads]+[a].[Writes] END,0)) >= @MinLatencyMs
        ORDER BY
              [OverallLatencyMs] DESC
            , [c].[DatabaseName]
            , [b].[FileId];

        SELECT @RowCount=COUNT_BIG(*) FROM [#CurrentIO_Result];

        IF @PendingIoEinbeziehen=1 AND @PendingSourceStatus='AVAILABLE'
        BEGIN
            BEGIN TRY
                IF @ParentCurrentStateSnapshotId IS NOT NULL
                BEGIN
                    EXEC [sys].[sp_executesql] N'
                        DECLARE @Probe int;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Context] WHERE 1=0;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus] WHERE 1=0;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Requests] WHERE 1=0;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Tasks] WHERE 1=0;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_WaitingTasks] WHERE 1=0;
                        SELECT @Probe=0 FROM [#CurrentOverview_CurrentStateSnapshot_Schedulers] WHERE 1=0;';

                    IF NOT EXISTS
                    (
                        SELECT 1
                        FROM [#CurrentOverview_CurrentStateSnapshot_Context]
                        WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                          AND [OwnerSessionId]=CONVERT(smallint,@@SPID)
                          AND [ContractVersion]=2
                    )
                        THROW 51020,N'Die Parent-Snapshot-ID gehört nicht zum aktuellen Aufruf.',1;

                    INSERT [#CurrentIO_SourceRequests]
                    SELECT [session_id],[request_id],[scheduler_id]
                    FROM [#CurrentOverview_CurrentStateSnapshot_Requests]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                    INSERT [#CurrentIO_SourceTasks]
                    SELECT [task_address],[scheduler_id]
                    FROM [#CurrentOverview_CurrentStateSnapshot_Tasks]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                    INSERT [#CurrentIO_SourceWaitingTasks]
                    SELECT [waiting_task_address],[wait_type]
                    FROM [#CurrentOverview_CurrentStateSnapshot_WaitingTasks]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                    INSERT [#CurrentIO_SourceSchedulers]
                    SELECT [scheduler_address],[scheduler_id]
                    FROM [#CurrentOverview_CurrentStateSnapshot_Schedulers]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId;

                    SELECT @EvidenceSnapshotStartedAtUtc=MIN([CapturedAtUtc])
                    FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
                    WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                      AND [SourceCode] IN ('REQUESTS','TASKS','WAITING_TASKS','SCHEDULERS');

                    IF EXISTS
                    (
                        SELECT 1
                        FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
                        WHERE [SnapshotId]=@ParentCurrentStateSnapshotId
                          AND [SourceCode] IN ('REQUESTS','TASKS','WAITING_TASKS','SCHEDULERS')
                          AND ([IsPartial]=1 OR [StatusCode]<>'AVAILABLE')
                    )
                        SET @PendingContextStatus='AVAILABLE_LIMITED';
                END
                ELSE
                BEGIN
                    SET @EvidenceSnapshotStartedAtUtc=SYSUTCDATETIME();
                    INSERT [#CurrentIO_SourceRequests]
                    SELECT [session_id],[request_id],[scheduler_id]
                    FROM [sys].[dm_exec_requests] WITH (NOLOCK);

                    INSERT [#CurrentIO_SourceTasks]
                    SELECT [task_address],[scheduler_id]
                    FROM [sys].[dm_os_tasks] WITH (NOLOCK);

                    INSERT [#CurrentIO_SourceWaitingTasks]
                    SELECT [waiting_task_address],[wait_type]
                    FROM [sys].[dm_os_waiting_tasks] WITH (NOLOCK);

                    INSERT [#CurrentIO_SourceSchedulers]
                    SELECT [scheduler_address],[scheduler_id]
                    FROM [sys].[dm_os_schedulers] WITH (NOLOCK);
                END;
            END TRY
            BEGIN CATCH
                SELECT @PendingContextStatus=CASE
                           WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                           WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                           WHEN ERROR_NUMBER()=51020 THEN 'INVALID_PARENT_SNAPSHOT'
                           ELSE 'ERROR_HANDLED' END,
                       @PendingContextErrorNumber=ERROR_NUMBER(),
                       @PendingContextErrorMessage=ERROR_MESSAGE();
            END CATCH;

            BEGIN TRY
                ;WITH [RequestCounts] AS
                (
                    SELECT [r].[scheduler_id],COUNT_BIG(*) AS [RequestCount]
                    FROM [#CurrentIO_SourceRequests] AS [r]
                    WHERE [r].[scheduler_id] IS NOT NULL AND [r].[session_id]<>@@SPID
                    GROUP BY [r].[scheduler_id]
                ),
                [IoWaitCounts] AS
                (
                    SELECT [t].[scheduler_id],COUNT_BIG(*) AS [IoWaitTaskCount]
                    FROM [#CurrentIO_SourceTasks] AS [t]
                    INNER JOIN [#CurrentIO_SourceWaitingTasks] AS [w]
                      ON [w].[waiting_task_address]=[t].[task_address]
                    WHERE [w].[wait_type] LIKE N'PAGEIOLATCH[_]%'
                       OR [w].[wait_type] IN
                          (N'WRITELOG',N'IO_COMPLETION',N'ASYNC_IO_COMPLETION',N'BACKUPIO',N'ASYNC_DISKPOOL_LOCK')
                    GROUP BY [t].[scheduler_id]
                )
                INSERT [#CurrentIO_SchedulerContext]
                SELECT [s].[scheduler_address],[s].[scheduler_id],
                       TRY_CONVERT(int,COALESCE([r].[RequestCount],0)),
                       TRY_CONVERT(int,COALESCE([w].[IoWaitTaskCount],0))
                FROM [#CurrentIO_SourceSchedulers] AS [s]
                LEFT JOIN [RequestCounts] AS [r] ON [r].[scheduler_id]=[s].[scheduler_id]
                LEFT JOIN [IoWaitCounts] AS [w] ON [w].[scheduler_id]=[s].[scheduler_id];
                IF @PendingContextStatus='NOT_REQUESTED'
                    SET @PendingContextStatus='AVAILABLE';
            END TRY
            BEGIN CATCH
                SELECT @PendingContextStatus=CASE
                           WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                           WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                       @PendingContextErrorNumber=ERROR_NUMBER(),
                       @PendingContextErrorMessage=ERROR_MESSAGE();
            END CATCH;

            INSERT [#CurrentIO_PendingResult]
            (
                  [CapturedAtUtc],[RequestAddress],[DatabaseId],[DatabaseName]
                , [FileId],[LogicalName],[FileTypeDesc],[PhysicalPath],[IoType]
                , [PendingLayer],[PendingDurationMs],[SchedulerId]
                , [RequestCountOnScheduler],[IoWaitTaskCountOnScheduler]
                , [WasPresentInFirstSample],[ObservationCount],[FirstSamplePendingMs]
                , [IoOffset],[FindingCode],[CorrelationScope]
            )
            SELECT TOP(@CandidateLimit)
                  SYSUTCDATETIME(),[p].[RequestAddress],[v].[DatabaseId],[c].[DatabaseName]
                , [v].[FileId],[mf].[name],[mf].[type_desc]
                , CASE WHEN @PhysischePfadeEinbeziehen=1
                       THEN COALESCE([mf].[physical_name],[p].[IoHandlePath]) END
                , [p].[IoType]
                , CASE [p].[IoPending] WHEN 1 THEN 'PENDING_OS' ELSE 'PENDING_SQL_SERVER' END
                , [p].[PendingDurationMs],[sc].[SchedulerId]
                , [sc].[RequestCountOnScheduler],[sc].[IoWaitTaskCountOnScheduler]
                , CONVERT(bit,CASE WHEN [b].[RequestAddress] IS NULL THEN 0 ELSE 1 END)
                , CONVERT(tinyint,CASE WHEN @SampleSeconds>0 AND [b].[RequestAddress] IS NOT NULL THEN 2 ELSE 1 END)
                , [b].[PendingDurationMs],[p].[IoOffset]
                , CASE
                    WHEN @SampleSeconds>0 AND [b].[RequestAddress] IS NOT NULL THEN 'REPEATED_PENDING_IO_REVIEW'
                    ELSE 'POINT_IN_TIME_PENDING_IO' END
                , N'File handle maps the database file; scheduler request/wait counts are concurrent context and do not prove a causal request mapping.'
            FROM [#CurrentIO_PendingAfter] AS [p]
            LEFT JOIN [#CurrentIO_PendingBefore] AS [b]
              ON [b].[RequestAddress]=[p].[RequestAddress]
            INNER JOIN [#CurrentIO_After] AS [v]
              ON [v].[FileHandle]=[p].[IoHandle]
            INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId]=[v].[DatabaseId]
            LEFT JOIN [master].[sys].[master_files] AS [mf] WITH (NOLOCK)
              ON [mf].[database_id]=[v].[DatabaseId] AND [mf].[file_id]=[v].[FileId]
            LEFT JOIN [#CurrentIO_SchedulerContext] AS [sc]
              ON [sc].[SchedulerAddress]=[p].[SchedulerAddress]
            WHERE [p].[PendingDurationMs]>=@MinPendingIoMs
              AND (@NurWiederholtPending=0 OR [b].[RequestAddress] IS NOT NULL)
            ORDER BY [p].[PendingDurationMs] DESC,[c].[DatabaseName],[v].[FileId],[p].[IoOffset];

            SELECT @PendingRowCount=COUNT_BIG(*) FROM [#CurrentIO_PendingResult];
            SET @PendingHasMoreRows=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @PendingRowCount>@Limit THEN 1 ELSE 0 END);
        END;

        SELECT @WarningCount=COUNT_BIG(*) FROM [#CurrentIO_DatabaseCandidateWarnings];
        SET @HasMoreRows=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @RowCount>@Limit THEN 1 ELSE 0 END);

        IF @WarningCount > 0
        BEGIN
            SET @StatusCode = 'AVAILABLE_LIMITED';
            SET @IsPartial = 1;
        END;

        IF @PendingIoEinbeziehen=1 AND @PendingSourceStatus<>'AVAILABLE'
        BEGIN
            SET @StatusCode='AVAILABLE_LIMITED';
            SET @IsPartial=1;
        END;

        IF @PendingIoEinbeziehen=1
           AND @PendingContextStatus='INVALID_PARENT_SNAPSHOT'
        BEGIN
            SET @StatusCode='INVALID_PARENT_SNAPSHOT';
            SET @IsPartial=1;
            SET @ErrorNumber=@PendingContextErrorNumber;
            SET @ErrorMessage=@PendingContextErrorMessage;
        END
        ELSE IF @PendingIoEinbeziehen=1 AND @PendingContextStatus<>'AVAILABLE'
        BEGIN
            SET @StatusCode='AVAILABLE_LIMITED';
            SET @IsPartial=1;
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @StatusCode = CASE
            WHEN @ErrorNumber IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
            WHEN @ErrorNumber = 1222 THEN 'TIMEOUT'
            ELSE 'ERROR_HANDLED' END;
        SET @IsPartial = 1;
        SET @FileSourceStatus=@StatusCode;
        SET @FileSourceErrorNumber=@ErrorNumber;
        SET @FileSourceErrorMessage=@ErrorMessage;
    END CATCH;

    IF @Limit<9223372036854775807
    BEGIN
        ;WITH [R] AS
        (
            SELECT *,ROW_NUMBER() OVER(ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId]) AS [rn]
            FROM [#CurrentIO_Result]
        )
        DELETE FROM [R] WHERE [rn]>@Limit;

        ;WITH [R] AS
        (
            SELECT *,ROW_NUMBER() OVER(ORDER BY [PendingDurationMs] DESC,[DatabaseName],[FileId],[IoOffset]) AS [rn]
            FROM [#CurrentIO_PendingResult]
        )
        DELETE FROM [R] WHERE [rn]>@Limit;
    END;

    IF @StatusCode <> 'AVAILABLE' AND @StatusCode <> 'AVAILABLE_LIMITED'
        SET @IsPartial = 1;

    INSERT [#CurrentIO_SourceStatus]
    (
          [SourceOrdinal],[SourceName],[SourceObject],[CapturedAtUtc],[StatusCode]
        , [IsPartial],[ReturnedRowCount],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
    )
    VALUES
    (
          1,N'fileStatistics',N'sys.dm_io_virtual_file_stats',@CollectionTimeUtc
        , @FileSourceStatus,CONVERT(bit,CASE WHEN @FileSourceStatus='AVAILABLE' THEN 0 ELSE 1 END)
        , @RowCount,@FileSourceErrorNumber,@FileSourceErrorMessage
        , N'Kumulative Zähler seit Engine-Start oder Delta aus zwei Beobachtungen; Dateikatalog und DMV können sich zwischen den Beobachtungen ändern.'
    ),
    (
          2,N'pendingIo',N'sys.dm_io_pending_io_requests',@CollectionTimeUtc
        , @PendingSourceStatus,CONVERT(bit,CASE WHEN @PendingSourceStatus IN('AVAILABLE','NOT_REQUESTED') THEN 0 ELSE 1 END)
        , @PendingRowCount,@PendingSourceErrorNumber,@PendingSourceErrorMessage
        , N'Aktueller, flüchtiger Zustand. io_pending_ms_ticks ist informational/internal; ein einzelner Request beweist keinen Storagefehler.'
    ),
    (
          3,N'pendingIoContext',N'sys.dm_os_schedulers|sys.dm_exec_requests|sys.dm_os_tasks|sys.dm_os_waiting_tasks',@CollectionTimeUtc
        , @PendingContextStatus,CONVERT(bit,CASE WHEN @PendingContextStatus IN('AVAILABLE','NOT_REQUESTED') THEN 0 ELSE 1 END)
        , (SELECT COUNT_BIG(*) FROM [#CurrentIO_SchedulerContext])
        , @PendingContextErrorNumber,@PendingContextErrorMessage
        , N'Schedulerbezogene Request- und I/O-Wait-Anzahlen sind gleichzeitiger Kontext, keine kausale Zuordnung zu einer Pending-I/O-Adresse.'
    );

    INSERT [#CurrentIO_ModuleStatus]
    (
          [ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial]
        , [ReturnedRowCount],[HasMoreRows],[CrossDatabaseRequested]
        , [SampleSeconds],[PendingIoRequested],[PendingIoRowCount]
        , [PendingIoHasMoreRows],[ErrorNumber],[ErrorMessage]
    )
    VALUES
    (
          N'USP_CurrentIO',@CollectionTimeUtc,@StatusCode,@IsPartial
        , CASE WHEN @RowCount>@Limit THEN @Limit ELSE @RowCount END
        , @HasMoreRows,@CrossDatabaseRequested,COALESCE(@SampleSeconds,CONVERT(tinyint,0)),COALESCE(@PendingIoEinbeziehen,CONVERT(bit,0))
        , CASE WHEN @PendingRowCount>@Limit THEN @Limit ELSE @PendingRowCount END
        , @PendingHasMoreRows,@ErrorNumber,@ErrorMessage
    );

    IF @PrintMeldungen = 1 AND @StatusCode NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentIO [%s]: %s',@StatusCode,COALESCE(@ErrorMessage,N'Keine Detailmeldung verfügbar.'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @PrintMeldungen = 1 AND @WarningCount > 0
    BEGIN
        SET @Message = FORMATMESSAGE(N'HINWEIS USP_CurrentIO: %I64d explizit angeforderte Datenbank(en) konnten nicht verarbeitet werden.',@WarningCount);
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @PrintMeldungen=1 AND @PendingIoEinbeziehen=1 AND @PendingSourceStatus<>'AVAILABLE'
    BEGIN
        SET @Message=FORMATMESSAGE(N'HINWEIS USP_CurrentIO pendingIo [%s]: %s',@PendingSourceStatus,COALESCE(@PendingSourceErrorMessage,N'Quelle nicht verfügbar.'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @OutputMode = 'CONSOLE'
    BEGIN
        IF @RowCount > 0 OR @PendingRowCount > 0
        BEGIN
            ;WITH [ConsoleRows] AS
            (
                SELECT CONVERT(int,2) AS [SortGroup],[OverallLatencyMs] AS [SortMetric],
                       N'Datei-I/O' AS [Evidenzart],[DatabaseName] AS [Datenbank],
                       [FileId] AS [Datei-ID],[LogicalName] AS [Logischer Name],
                       [FileTypeDesc] AS [Dateityp],N'Gesamtlatenz je I/O' AS [Metrik],
                       [OverallLatencyMs] AS [Wert],N'ms' AS [Einheit],
                       CONVERT(varchar(80),CASE WHEN @SampleSeconds=0 THEN 'CUMULATIVE_SINCE_START' ELSE 'SAMPLE_DELTA' END) AS [Bewertung],
                       CONVERT(nvarchar(1000),CONCAT(N'Reads=',[Reads],N'; Writes=',[Writes],N'; SampleSeconds=',[SampleSeconds])) AS [Kontext]
                FROM [#CurrentIO_Result]
                UNION ALL
                SELECT 1,CONVERT(decimal(19,3),[PendingDurationMs]),N'Pending I/O',
                       [DatabaseName],[FileId],[LogicalName],[FileTypeDesc],N'Pending-Dauer',
                       CONVERT(decimal(19,3),[PendingDurationMs]),N'ms',[FindingCode],
                       CONVERT(nvarchar(1000),CONCAT(N'Layer=',[PendingLayer],N'; Beobachtungen=',[ObservationCount],N'; Scheduler=',COALESCE(CONVERT(varchar(20),[SchedulerId]),N'NULL')))
                FROM [#CurrentIO_PendingResult]
            )
            SELECT TOP(@Limit) [Evidenzart],[Datenbank],[Datei-ID],[Logischer Name],
                   [Dateityp],[Metrik],[Wert],[Einheit],[Bewertung],[Kontext]
            FROM [ConsoleRows]
            ORDER BY [SortGroup],[SortMetric] DESC,[Datenbank],[Datei-ID];
        END
        ELSE
        BEGIN
            SELECT
                  CASE WHEN @StatusCode IN ('AVAILABLE','AVAILABLE_LIMITED')
                       THEN N'Keine Datei-I/O-Daten entsprechen den Filtern.'
                       ELSE N'Die Datei-I/O-Analyse ist nicht verfügbar.' END AS [Ergebnis]
                , @StatusCode AS [Status]
                , @ErrorMessage AS [Hinweis];
        END;
    END
    ELSE IF @OutputMode = 'RAW'
    BEGIN
        SELECT * FROM [#CurrentIO_ModuleStatus];

        SELECT * FROM [#CurrentIO_SourceStatus] ORDER BY [SourceOrdinal];

        SELECT TOP (@Limit) *
        FROM [#CurrentIO_Result]
        ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId];

        SELECT TOP(@Limit) *
        FROM [#CurrentIO_PendingResult]
        ORDER BY [PendingDurationMs] DESC,[DatabaseName],[FileId],[IoOffset];

        SELECT [RequestedName],[StatusCode],[ErrorMessage]
        FROM [#CurrentIO_DatabaseCandidateWarnings]
        ORDER BY [RequestedName];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max)=
        (
            SELECT
                  N'CurrentIO' AS [resultName]
                , 3 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @EvidenceSnapshotStartedAtUtc AS [evidenceSnapshotStartedAtUtc]
                , @EvidenceSnapshotId AS [evidenceSnapshotId]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , CASE WHEN @RowCount>@Limit THEN @Limit ELSE @RowCount END AS [returnedRows]
                , @HasMoreRows AS [hasMoreRows]
                , @SampleSeconds AS [sampleSeconds]
                , @PendingIoEinbeziehen AS [pendingIoRequested]
                , CASE WHEN @PendingRowCount>@Limit THEN @Limit ELSE @PendingRowCount END AS [pendingIoReturnedRows]
                , @PendingHasMoreRows AS [pendingIoHasMoreRows]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @Data nvarchar(max)=
        (
            SELECT TOP (@Limit) *
            FROM [#CurrentIO_Result]
            ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max)=
        (
            SELECT [RequestedName],[StatusCode],[ErrorMessage]
            FROM [#CurrentIO_DatabaseCandidateWarnings]
            ORDER BY [RequestedName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @SourceStatusJson nvarchar(max)=
        (
            SELECT * FROM [#CurrentIO_SourceStatus] ORDER BY [SourceOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @PendingJson nvarchar(max)=
        (
            SELECT TOP(@Limit) * FROM [#CurrentIO_PendingResult]
            ORDER BY [PendingDurationMs] DESC,[DatabaseName],[FileId],[IoOffset]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"sourceStatus":',COALESCE(@SourceStatusJson,N'[]'),N',"files":',COALESCE(@Data,N'[]'),N',"pendingIo":',COALESCE(@PendingJson,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;

    IF @OutputMode = 'TABLE'
    BEGIN
        DECLARE @TargetTable sysname;

        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'moduleStatus';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_ModuleStatus'
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'sourceStatus';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_SourceStatus'
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'files';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_Result'
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'pendingIo';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_PendingResult'
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'warnings';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_DatabaseCandidateWarnings'
                , @TargetTable=@TargetTable
                , @ThrowOnError=1;
    END;
END;
GO

