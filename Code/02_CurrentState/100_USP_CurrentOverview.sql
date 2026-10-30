USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentOverview
Version      : 4.1.0
Stand        : 2026-07-23
Zweck        : Orchestriert jedes aktivierte Current-State-Child genau einmal,
               übernimmt dessen expliziten Status und materialisiert Daten für
               CONSOLE, JSON und benannte TABLE-Exporte ohne erneute Systemlese.
CONSOLE      : SUMMARY ist der Default. RELEVANT und ALL ergänzen ausschließlich
               nicht leere Childdetails; Children erhalten niemals CONSOLE.
TABLE-Namen  : moduleStatus, snapshotStatus, sessions, requests, requestContext,
               statements, batches, inputBuffers, blocking, waits, transactions,
               memoryGrants, tempdbSessions, tempdbGovernance, versionStore, io, logs und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentOverview]
      @SessionIds                    nvarchar(max)  = NULL
    , @DatabaseNames                 nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen  bit            = 0
    , @DatabaseNamePattern           nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @ToolHintergrundabfragenEinbeziehen bit          = 0
    , @Detailgrad                    varchar(16)     = 'SUMMARY'
    , @MitSessions                   bit             = 1
    , @MitRequests                   bit             = 1
    , @MitBlocking                   bit             = 1
    , @BlockingObjektTiefe           varchar(16)     = 'STANDARD'
    , @MaxObjektAufloesungen         int             = 100
    , @MitWaits                      bit             = 1
    , @MitTransactions               bit             = 1
    , @MitMemoryGrants               bit             = 1
    , @MitTempDB                     bit             = 1
    , @MitIO                         bit             = 1
    , @MitLog                        bit             = 1
    , @MitSqlText                    bit             = 1
    , @GesamtenSqlTextEinbeziehen    bit             = 0
    , @InputBufferEinbeziehen        bit             = 0
    , @ModulInfoEinbeziehen          bit             = 1
    , @MaxSqlTextZeichen             int             = 4000
    , @SampleSeconds                 tinyint         = 0
    , @MaxZeilen                     int             = 500
    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 0
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,N''))));
    DECLARE @DetailMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@Detailgrad,N''))));
    DECLARE @BlockingObjectDepth varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@BlockingObjektTiefe,N''))));

    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @ErrorMessage nvarchar(2048)=NULL;

    CREATE TABLE [#CurrentOverview_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );

    IF @OutputMode='TABLE' OR NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'moduleStatus|snapshotStatus|sessions|requests|requestContext|statements|batches|inputBuffers|blocking|waits|transactions|memoryGrants|tempdbSessions|tempdbGovernance|versionStore|io|logs|warnings'
            , @MappingTable=N'#CurrentOverview_ResultTableMap'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @ThrowOnError=1;
    END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentOverview liefert eine aktuelle, sequenzielle Orchestrierung und keine atomare Gesamtaufnahme.';
        PRINT N'@Hilfe: bit; Default=0. Bei exakt 1 wird PRINT-Hilfe ausgegeben und nach einer gegebenenfalls angeforderten TABLE-Map-Vorprüfung zurückgekehrt, ohne Children oder Exporte auszuführen. 0 führt den normalen Pfad aus. Ausgelassen=0; NULL wird nicht als Hilfe erkannt und führt in den normalen Pfad, nicht zu INVALID_PARAMETER. Numerische Werte werden vor Eintritt zu bit konvertiert.';
        PRINT N'Für Hilfe ohne TABLE-Ziel verwenden Sie @ResultSetArt=''CONSOLE'', @ResultTablesJson=NULL und @Hilfe=1; TABLE benötigt vor dem Aufruf ein vorhandenes, leeres lokales #Temp-Ziel mit einer Seed-Spalte.';
        PRINT N'@SessionIds: nvarchar(max); Default=NULL. Der Parent normalisiert oder parst den Wert nicht, sondern übergibt ihn unverändert an genau sieben Children: USP_CurrentSessions, USP_CurrentRequests, USP_CurrentBlocking, USP_CurrentWaits, USP_CurrentTransactions, USP_CurrentMemoryGrants und USP_CurrentTempDB. NULL deaktiviert den ID-Filter. Eine Liste kann Pipe, Komma und Semikolon auch gemischt verwenden; Komma und Semikolon werden vor der Pipe-Zerlegung überall in Trenner umgewandelt, auch innerhalb von [...]. Pipe trennt nur außerhalb bracket-quotierter Bereiche; äußere Elementleerzeichen werden getrimmt. Jedes Element muss eine Ganzzahl sein. Leerstring ergibt EMPTY_LIST, reine Leerzeichen oder leere Elemente EMPTY_ITEM; ungültige Elemente und Bereichsverletzungen führen zu INVALID_PARAMETER. Gültige Bereiche und Duplikate unterscheiden sich je Child: Sessions, Requests, Waits und MemoryGrants akzeptieren 1..32767 und fassen Duplikate zusammen; Blocking, Transactions und TempDB akzeptieren 0..32767, lehnen Duplikate ab. Die Liste wird nicht entquotet; Klammerquotierung macht aus einem Zahlenwert keine gültige ID.';
        PRINT N'@DatabaseNames: nvarchar(max); Default=NULL. Bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen mit höchstens 128 Zeichen je Name für I/O und Log; | trennt nur außerhalb von [...], ein | in [...] ist Teil des Namens, und ]] maskiert ein inneres ]. Verglichen wird case-sensitiv; doppelte/ungültige Einträge erzeugen Auswahlfehler oder Warnings. NULL, leer, nur gewöhnliche Leerzeichen oder ausgelassen bedeutet alle sichtbaren, zugreifbaren ONLINE-Benutzerdatenbanken. Exklusiv mit @DatabaseNamePattern; explizit nicht verfügbare Namen können Auswahlwarnings erzeugen. Nur I/O und Log erhalten diesen Filter.';
        PRINT N'@DatabaseNames und @DatabaseNamePattern sind gegenseitig exklusiv; doppelte oder ungültige Listeneinträge werden abgelehnt, und explizit nicht verfügbare Namen erzeugen Auswahlwarnungen.';
        PRINT N'@SystemdatenbankenEinbeziehen: bit; Default=0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren ONLINE-Systemdatenbanken für I/O/Log. Ausgelassen ergibt 0; NULL wird als INVALID_PARAMETER abgelehnt. Numerische Eingaben werden vor Eintritt zu bit konvertiert: 0 bleibt 0, jeder numerische Nichtnullwert wird 1. Keine Wirkung auf andere Children.';
        PRINT N'@DatabaseNamePattern: nvarchar(4000); Default=NULL. Ein nichtleeres einzelnes Pattern, exklusiv mit @DatabaseNames, für I/O und Log. Kein Präfix oder like: = case-sensitives SQL-LIKE mit %, _ und []-Klassen; regex: = case-sensitive Regex; regexi: = case-insensitive Regex. Präfixerkennung ist case-insensitiv, äußere Leerzeichen werden entfernt, Musterinhalt bleibt erhalten. NULL/ausgelassen deaktiviert; leer, nur gewöhnliche Leerzeichen oder Präfix ohne Muster ist ungültig. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Andere Children verwenden das Pattern nicht.';
        PRINT N'Regexmuster in @DatabaseNamePattern benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; leere Muster sind ungültig.';
        PRINT N'@HighImpactConfirmed: bit; Default=0. 0/ausgelassen bestätigt keine angeforderten Hochwirkungswege; 1 bestätigt sie. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, jeder Nichtnullwert→1); NULL wird als INVALID_PARAMETER abgelehnt. Diese Bestätigung erteilt keine Zugriffsgruppenfreigabe: Children prüfen ihre eigenen erforderlichen Gruppenrechte und Gates; Parent reicht den Wert an Blocking, I/O und Log weiter. DEEP Blocking braucht zusätzlich LOCKS_DEEP.';
        PRINT N'@ToolHintergrundabfragenEinbeziehen: bit; Default=0. 0 blendet erkannte Toolaktivität in Sessions, Requests, Blocking-Blättern und aktuellen Waiting Tasks aus; 1 bezieht sie ein, ohne normale Blockingketten abzuschneiden. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER; numerisch 0 bleibt 0, jeder Nichtnullwert wird vor Procedure-Eintritt 1. Andere Children erhalten diesen Filter nicht.';
        PRINT N'@Detailgrad: varchar(16); Default=''SUMMARY''. Nach TRIM/UPPER exakt SUMMARY (nur Modulstatus), RELEVANT (Status plus nichtleere als relevant markierte Childdetails) oder ALL (Status plus nichtleere Resultate aller aktivierten Children mit AVAILABLE/AVAILABLE_LIMITED). Reihenfolge folgt den neun Modulen; Zeilen innerhalb der Grids sind nicht geordnet. Ausgelassen ergibt SUMMARY; NULL/leer normalisiert zu leer und ist ungültig. Keine Reduktion der Child-Erhebungsarbeit.';
        PRINT N'RELEVANT zeigt nur als relevant markierte nichtleere Childresultate; ALL zeigt nichtleere Resultate aller aktivierten Children mit Status AVAILABLE oder AVAILABLE_LIMITED.';
        PRINT N'@MitSessions: bit; Default=1. 1 ruft USP_CurrentSessions genau einmal mit TABLE auf; 0 überspringt es und setzt Modulstatus SKIPPED. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1 vor Eintritt.';
        PRINT N'@MitRequests: bit; Default=1. 1 ruft USP_CurrentRequests genau einmal mit TABLE auf; 0 überspringt das Child (SKIPPED). Aktiviertes Requests-Child kann Requestkontext, Statements, Batches und InputBuffers liefern. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitBlocking: bit; Default=1. 1 ruft USP_CurrentBlocking einmal auf; 0 überspringt Blockingketten und Ressourcenauflösung (SKIPPED). DEEP-Einstellungen wirken nur bei aktiviertem Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitWaits: bit; Default=1. 1 ruft USP_CurrentWaits auf; 0 überspringt aktuelle Waiting Tasks und Wait-Analyse. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitTransactions: bit; Default=1. 1 ruft USP_CurrentTransactions auf; 0 überspringt das Transaktions-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitMemoryGrants: bit; Default=1. 1 ruft USP_CurrentMemoryGrants auf; 0 überspringt das Memory-Grant-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitTempDB: bit; Default=1. 1 ruft USP_CurrentTempDB auf und exportiert bei TABLE sessions, tempdbGovernance und versionStore; 0 überspringt diese Quellen/Childexports. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitIO: bit; Default=1. 1 ruft USP_CurrentIO für Datei-I/O auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MitLog: bit; Default=1. 1 ruft USP_CurrentLog für Transaktionslogzustände auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'Ein numerischer Wert 0 bleibt bei der Konvertierung zu bit 0; jeder von 0 verschiedene numerische Wert wird zu 1 und NULL bleibt NULL, wird aber von der Parameterprüfung abgelehnt.';
        PRINT N'@BlockingObjektTiefe: varchar(16); Default=''STANDARD''. Nach TRIM/UPPER exakt NONE (keine Ressourcenauflösung), STANDARD (Auflösung mit begrenzter Kandidatenzahl) oder DEEP (zusätzlich Locks beteiligter Blocking-Sessions, Gate LOCKS_DEEP plus @HighImpactConfirmed=1). Ausgelassen=STANDARD; NULL/leer/andere Werte ungültig. Wird an Blocking weitergereicht; bei deaktiviertem Blocking keine Childauswirkung.';
        PRINT N'@MaxObjektAufloesungen: int; Default=100 Kandidaten. Ganze Zahl 1 bis 1000 einschließlich; begrenzt Blocking-Ressourcenkandidaten, nicht die gesamte Ausgabe. Ausgelassen=100; NULL und Werte außerhalb des Bereichs INVALID_PARAMETER. Child verwendet diesen Wert für die Objektauflösung.';
        PRINT N'@MitSqlText: bit; Default=1. 1 erlaubt unterstützenden Children SQL-Text; 0 deaktiviert ihn. Parent-Snapshot materialisiert Text nur bei mindestens einem tatsächlichen Consumer; Handles werden vor DMF-Zugriff dedupliziert/begrenzt. Requests-Child muss dafür aktiviert sein, und weitere Children können den gemeinsamen Text verbrauchen. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@GesamtenSqlTextEinbeziehen: bit; Default=0. 1 fordert bei Requests vollständigen Batch-/Modultext an; 0 fordert ihn nicht an. Separater Childschalter neben @MitSqlText und nur wirksam mit aktiviertem Requests-Child. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@InputBufferEinbeziehen: bit; Default=0. 1 fordert den Input Buffer als gezielte Requests-Quelle an; 0 nicht. Input Buffer ist kein gemeinsamer Primär-Snapshot und wird nur durch das aktivierte Requests-Child erhoben. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@ModulInfoEinbeziehen: bit; Default=1. 1 fordert Request-Modulkontext an; 0 nicht. Der gemeinsame SQL-Text-Capture berücksichtigt diesen Schalter nur bei aktiviertem Requests-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.';
        PRINT N'@MaxSqlTextZeichen: int; Default=4000 Zeichen. Nichtnegative ganze Zahl bis 2147483647; wird an die textausgebenden Children weitergereicht. Eine positive Grenze kürzt die jeweilige Textprojektion nur bei Überschreitung. NULL oder 0 hebt die durch diesen Parameter bewirkte Textbegrenzung auf; es wird dann nicht aufgrund dieses Limits gekürzt. Ausgelassen nutzt 4000. Der Parent lässt NULL passieren; negative Werte sind INVALID_PARAMETER. Das Limit ist keine Anonymisierung.';
        PRINT N'@SampleSeconds: tinyint; Default=0 Sekunden; zulässige Werte 0 bis 60. 0 deaktiviert WAITFOR-Sampling; 1 bis 60 sampelt Waits und I/O nacheinander, verlängert den Parent entsprechend und kann durch Scheduling länger dauern. Ausgelassen nutzt 0. Die Parentprüfung lässt NULL durch: Bei aktiviertem I/O wird es als INVALID_PARAMETER abgelehnt; Waits gelangt damit in den Samplingpfad mit NULL-Verzögerung und behandelt den daraus entstehenden Fehler im DeltaStatus als ERROR_HANDLED mit partieller Sicht. Bereits verfügbare Taskdaten können dabei erhalten bleiben. Werte über 60 sind INVALID_PARAMETER; die Konvertierung zu tinyint erfolgt vor Eintritt.';
        PRINT N'@MaxZeilen: int; Default=500 Zeilen je Child, nicht als Gesamtbudget. Negative Werte INVALID_PARAMETER; NULL oder 0 sind im Parent zulässig und können je Child unbegrenzt bedeuten; positive Werte werden weitergereicht und je Childstufe unterschiedlich angewandt. Ausgelassen=500. Kein globales Limit für Modulstatus oder alle Resultate zusammen.';
        PRINT N'@ResultSetArt: varchar(16); Default=''CONSOLE''. Nach TRIM/UPPER exakt CONSOLE (Modulstatusgrid plus gemäß @Detailgrad gewählte nichtleere Childgrids), RAW (Modulstatus, Snapshotstatus und Warnings; keine Childdatengrids), TABLE (nur angeforderte benannte Exporte), NONE (keine fachlichen Resultsets). Ausgelassen=CONSOLE; NULL/leer wird zu '''' und ist ungültig. Anders als der Modus entscheidet @Detailgrad über zusätzliche CONSOLE-Details.';
        PRINT N'CONSOLE und RAW geben das Modulstatus-Grid aus; RAW ergänzt Snapshotstatus und Warnings, aber keine Childdaten-Grids. TABLE exportiert angeforderte Resultnamen, NONE unterdrückt Resultsets.';
        PRINT N'@ResultTablesJson: nvarchar(max); Default=NULL. TABLE-Zuordnung als nichtleeres JSON-Objekt; die exakt case-sensitiven Key-Bedeutungen sind moduleStatus = Parent-Modulstatus, snapshotStatus = Status der Snapshotquellen, sessions = Sessionresultate, requests = Requestresultate, requestContext = Requestkontext, statements = Statementtexte, batches = Batch-/Modultexte, inputBuffers = Input-Buffer-Daten, blocking = Blockingketten, waits = aktuelle Waiting Tasks, transactions = Transaktionsresultate, memoryGrants = Memory-Grant-Resultate, tempdbSessions = TempDB-Sessionverbrauch, tempdbGovernance = TempDB-Governancewerte, versionStore = Version-Store-Werte, io = Datei-I/O-Resultate, logs = Transaktionslogzustände und warnings = Warnungen. Jeder zugehörige Wert muss ein nichtleerer JSON-String mit Name einer vorhandenen lokalen #Temp-Tabelle sein (keine ##-Temp, Name höchstens 116 Zeichen, nicht #Monitor...). Ziele müssen leer sein und genau eine Seed-Spalte haben; Resultnamen und Zieltabellen dürfen nicht doppelt vorkommen. Unbekannte Keys, ungültige JSON/Form, Typen oder Ziele schlagen im Preflight mit 51011 fehl. Für TABLE erforderlich. Außerhalb TABLE muss der Wert NULL, leer oder nach SQL-LTRIM/RTRIM nur aus gewöhnlichen Leerzeichen bestehen; eine nichtleere Map ist unzulässig. Wird bei TABLE oder nichtleerer Map vor dem Hilfezweig und vor semantischen Parentchecks validiert. Gültiges Mapping garantiert keine späteren Daten/Frische; deaktivierte Childtargets können ungeschrieben bleiben, Request-Kontext/Textziele Seed-Schema behalten.';
        PRINT N'Erlaubte TABLE-Namen sind moduleStatus, snapshotStatus, sessions, requests, requestContext, statements, batches, inputBuffers, blocking, waits, transactions, memoryGrants, tempdbSessions, tempdbGovernance, versionStore, io, logs und warnings.';
        PRINT N'TABLE-Zuordnungen werden vor dem Hilfezweig geprüft; ungültige Zuordnungen lösen Fehler 51011 aus, auch wenn @Hilfe=1 angefordert wurde.';
        PRINT N'@JsonErzeugen: bit; Default=0. 0 deaktiviert JSON; 1 baut unabhängig von @ResultSetArt ein JSON-Objekt. Ausgelassen=0; NULL und Werte außer 0/1 sind INVALID_PARAMETER. Numerische Eingaben vor Eintritt: 0→0, Nichtnull→1. Envelope: meta (resultName, schemaVersion, generatedAtUtc, statusCode, evidenceSnapshotId, isPartial, executedModules, failedModules, partialModules, toolBackgroundQueriesIncluded), moduleStatus, snapshotStatus, warnings sowie je aktiviertem Child dessen benanntes Array in Modulreihenfolge. Resultfehler können als null-Childvalue erscheinen.';
        PRINT N'@Json: nvarchar(max) OUTPUT; Default=NULL. Optionale Aufrufvariable vom Typ nvarchar(max), im EXEC mit OUTPUT zu binden. Wird bei Procedure-Eintritt immer zuerst auf NULL gesetzt; wenn @JsonErzeugen=1 wird sie mit dem JSON-Envelope befüllt, andernfalls bleibt sie NULL. Das Auslassen der Empfangsbindung verhindert das Empfangen des Werts.';
        PRINT N'meta enthält unter anderem Schemaversion, Status, Snapshot-ID, Partialität und Modulzähler; moduleStatus, snapshotStatus und warnings sind JSON-Arrays.';
        PRINT N'@PrintMeldungen: bit; Default=1. 1 aktiviert die optionalen Status-/Warnmeldungen der aktivierten Children; 0 unterdrückt diese Meldungen, ohne Resultsets oder JSON zu deaktivieren. Ausgelassen nutzt 1. Der Parent weist NULL nicht zurück: Blocking und I/O lehnen NULL als INVALID_PARAMETER ab; Sessions, Requests, Waits, Transactions, MemoryGrants, TempDB und Log unterdrücken damit die Meldungen ihrer IF-gleich-1-Pfade. Diese Folgen betreffen nur die jeweils aktivierten Childmodule. SQL Server konvertiert numerisch 0 vor Eintritt zu bit 0 und numerische Werte ungleich 0 zu bit 1.';
        PRINT N'Ungültige semantische Parameter ergeben INVALID_PARAMETER; Childfehler oder fehlende Snapshotquellen können Status AVAILABLE_LIMITED, Fehlerstatus oder PARTIAL und Warnings erzeugen.';
        PRINT N'Jedes aktivierte Child wird genau einmal sequenziell und intern mit TABLE aufgerufen; sind alle Childflags aus, läuft keines. Gemeinsame Capturequellen folgen Abhängigkeiten und sind nicht mit den Childflags identisch.';
        PRINT N'CONSOLE-Beispiel: EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @MaxZeilen=100, @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel: CREATE TABLE #CurrentOverview_HelpExample (Seed bit NULL); EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"moduleStatus":"#CurrentOverview_HelpExample"}''; SELECT * FROM #CurrentOverview_HelpExample; DROP TABLE #CurrentOverview_HelpExample;';
        PRINT N'JSON-Beispiel: DECLARE @OverviewJson nvarchar(max); EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@OverviewJson OUTPUT; SELECT @OverviewJson;';
        PRINT N'Alle Beispielwerte sind synthetisch; SUMMARY reduziert die Ausgabe, nicht die Childarbeit, und die sequenziellen Messungen belegen keinen atomaren Gesamtzustand.';
        SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
        RETURN;
    END;

    DECLARE @StartedAtUtc datetime2(3)=SYSUTCDATETIME();
    DECLARE @ExecutedModules int=0;
    DECLARE @FailedModules int=0;
    DECLARE @PartialModules int=0;
    DECLARE @Message nvarchar(2048);
    DECLARE @ChildJson nvarchar(max);
    DECLARE @ChildStartedAtUtc datetime2(3);
    DECLARE @ChildDurationMs bigint;
    DECLARE @CurrentStateSnapshotId uniqueidentifier=NULL;
    DECLARE @SnapshotConsumerId uniqueidentifier=NULL;
    DECLARE @SnapshotPartial bit=0;
    DECLARE @CaptureSessions bit=0;
    DECLARE @CaptureRequests bit=0;
    DECLARE @CaptureConnections bit=0;
    DECLARE @CaptureWaitingTasks bit=0;
    DECLARE @CaptureMemoryGrants bit=0;
    DECLARE @CaptureResourceGovernor bit=0;
    DECLARE @CaptureTasks bit=0;
    DECLARE @CaptureSchedulers bit=0;
    DECLARE @CaptureTransactions bit=0;
    DECLARE @CaptureTempDbUsage bit=0;
    DECLARE @CaptureVersionStore bit=0;
    DECLARE @CaptureSqlText bit=0;
    DECLARE @MaxSqlTextHandles int=0;

    CREATE TABLE [#CurrentOverview_ModulePayload]
    (
          [ModuleOrdinal] int NOT NULL PRIMARY KEY
        , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEnabled] bit NOT NULL
        , [IsRelevant] bit NOT NULL
        , [IsMaterialized] bit NOT NULL
        , [DurationMs] bigint NOT NULL
        , [JsonValue] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutionError] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentOverview_ModuleStatus]
    (
          [ModuleOrdinal] int NOT NULL
        , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [DurationMs] bigint NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([ModuleOrdinal])
    );

    CREATE TABLE [#CurrentOverview_Warnings]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CurrentOverview_Sessions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Requests]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_RequestContext]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Statements]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Batches]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_InputBuffers]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_RequestSnapshotStatus]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Blocking]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Waits]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Transactions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_MemoryGrants]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_TempDBSessions]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_TempDBGovernance]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_VersionStore]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_IO]([Seed] bit NULL);
    CREATE TABLE [#CurrentOverview_Logs]([Seed] bit NULL);

    CREATE TABLE [#CurrentOverview_SnapshotStatus]
    (
          [SourceOrdinal] int NOT NULL
        , [SnapshotId] uniqueidentifier NOT NULL
        , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [CompletedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [CapturedRowCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([SourceOrdinal])
    );

    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Context]
    (
          [SnapshotId] uniqueidentifier NOT NULL PRIMARY KEY
        , [OwnerSessionId] smallint NOT NULL
        , [CreatedAtUtc] datetime2(3) NOT NULL
        , [ContractVersion] smallint NOT NULL
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [SourceOrdinal] int NOT NULL
        , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [CompletedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [CapturedRowCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([SnapshotId],[SourceCode])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Sessions]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] smallint NOT NULL
        , [is_user_process] bit NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [original_login_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [host_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [program_name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [client_interface_name] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [login_time] datetime NOT NULL
        , [last_request_start_time] datetime NOT NULL
        , [last_request_end_time] datetime NULL
        , [open_transaction_count] int NOT NULL
        , [transaction_isolation_level] smallint NOT NULL
        , [cpu_time] int NOT NULL
        , [reads] bigint NOT NULL
        , [writes] bigint NOT NULL
        , [logical_reads] bigint NOT NULL
        , [memory_usage] int NOT NULL
        , [row_count] bigint NOT NULL
        , PRIMARY KEY ([SnapshotId],[session_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Requests]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [status] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [start_time] datetime NOT NULL
        , [sql_handle] varbinary(64) NULL
        , [statement_start_offset] int NULL
        , [statement_end_offset] int NULL
        , [plan_handle] varbinary(64) NULL
        , [database_id] smallint NOT NULL
        , [connection_id] uniqueidentifier NULL
        , [blocking_session_id] smallint NULL
        , [wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [wait_time] int NOT NULL
        , [last_wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [wait_resource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [open_transaction_count] int NOT NULL
        , [open_resultset_count] int NOT NULL
        , [transaction_id] bigint NOT NULL
        , [context_info] varbinary(128) NULL
        , [percent_complete] real NOT NULL
        , [estimated_completion_time] bigint NOT NULL
        , [cpu_time] int NOT NULL
        , [total_elapsed_time] int NOT NULL
        , [scheduler_id] int NULL
        , [task_address] varbinary(8) NULL
        , [reads] bigint NOT NULL
        , [writes] bigint NOT NULL
        , [logical_reads] bigint NOT NULL
        , [transaction_isolation_level] smallint NOT NULL
        , [row_count] bigint NOT NULL
        , [nest_level] int NOT NULL
        , [executing_managed_code] bit NOT NULL
        , [group_id] int NOT NULL
        , [query_hash] binary(8) NULL
        , [query_plan_hash] binary(8) NULL
        , [statement_sql_handle] varbinary(64) NULL
        , [statement_context_id] bigint NULL
        , [dop] int NOT NULL
        , [parallel_worker_count] int NULL
        , [is_resumable] bit NOT NULL
        , PRIMARY KEY ([SnapshotId],[session_id],[request_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Connections]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] int NULL
        , [connection_id] uniqueidentifier NOT NULL
        , [most_recent_sql_handle] varbinary(64) NULL
        , [client_net_address] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [net_transport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [protocol_type] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [encrypt_option] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [auth_scheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [connect_time] datetime NOT NULL
        , PRIMARY KEY ([SnapshotId],[connection_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_WaitingTasks]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [waiting_task_address] varbinary(8) NOT NULL
        , [session_id] smallint NULL
        , [exec_context_id] int NULL
        , [wait_duration_ms] bigint NOT NULL
        , [wait_type] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [resource_address] varbinary(8) NULL
        , [blocking_task_address] varbinary(8) NULL
        , [blocking_session_id] smallint NULL
        , [blocking_exec_context_id] int NULL
        , [resource_description] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_MemoryGrants]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [scheduler_id] int NULL
        , [dop] smallint NULL
        , [request_time] datetime NULL
        , [grant_time] datetime NULL
        , [wait_time_ms] bigint NULL
        , [requested_memory_kb] bigint NOT NULL
        , [required_memory_kb] bigint NULL
        , [granted_memory_kb] bigint NULL
        , [used_memory_kb] bigint NULL
        , [max_used_memory_kb] bigint NULL
        , [ideal_memory_kb] bigint NULL
        , [resource_semaphore_id] smallint NULL
        , [queue_id] smallint NULL
        , [wait_order] int NULL
        , [is_next_candidate] bit NULL
        , [is_small] bit NULL
        , [plan_handle] varbinary(64) NULL
        , [sql_handle] varbinary(64) NULL
        , [group_id] int NULL
        , [pool_id] int NULL
        , [reserved_worker_count] bigint NULL
        , [used_worker_count] bigint NULL
        , [max_used_worker_count] bigint NULL
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_ResourceSemaphores]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [pool_id] int NOT NULL
        , [resource_semaphore_id] smallint NOT NULL
        , [target_memory_kb] bigint NOT NULL
        , [max_target_memory_kb] bigint NULL
        , [total_memory_kb] bigint NOT NULL
        , [available_memory_kb] bigint NOT NULL
        , [granted_memory_kb] bigint NOT NULL
        , [used_memory_kb] bigint NOT NULL
        , [grantee_count] int NOT NULL
        , [waiter_count] int NOT NULL
        , PRIMARY KEY ([SnapshotId],[pool_id],[resource_semaphore_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_WorkloadGroups]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [group_id] int NOT NULL
        , [name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [pool_id] int NOT NULL
        , [request_max_memory_grant_percent_numeric] decimal(9,4) NULL
        , [max_request_grant_memory_kb] bigint NULL
        , [configured_group_max_tempdb_data_mb] decimal(19,2) NULL
        , [configured_group_max_tempdb_data_percent] decimal(9,4) NULL
        , [tempdb_maximum_size_mb] decimal(19,2) NULL
        , [effective_group_max_tempdb_data_mb] decimal(19,2) NULL
        , [effective_limit_source] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [is_percent_limit_effective] bit NULL
        , [tempdb_data_space_mb] decimal(19,2) NULL
        , [peak_tempdb_data_space_mb] decimal(19,2) NULL
        , [effective_limit_utilization_percent] decimal(9,2) NULL
        , [total_tempdb_data_limit_violation_count] bigint NULL
        , [has_recorded_limit_violation] bit NULL
        , [statistics_start_time] datetime NULL
        , [is_resource_governor_enabled] bit NULL
        , [reconfiguration_pending] bit NULL
        , [tempdb_governance_status_code] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [tempdb_governance_is_partial] bit NOT NULL
        , [tempdb_governance_evidence_limit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([SnapshotId],[group_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_ResourcePools]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [pool_id] int NOT NULL
        , [name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [max_memory_kb] bigint NULL
        , [target_memory_kb] bigint NULL
        , [used_memory_kb] bigint NULL
        , PRIMARY KEY ([SnapshotId],[pool_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Tasks]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [task_address] varbinary(8) NOT NULL
        , [task_state] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [session_id] smallint NULL
        , [request_id] int NULL
        , [exec_context_id] int NULL
        , [scheduler_id] int NULL
        , [worker_address] varbinary(8) NULL
        , [parent_task_address] varbinary(8) NULL
        , PRIMARY KEY ([SnapshotId],[task_address])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_Schedulers]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [scheduler_address] varbinary(8) NOT NULL
        , [scheduler_id] int NOT NULL
        , [parent_node_id] int NOT NULL
        , [status] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [is_online] bit NOT NULL
        , [is_idle] bit NOT NULL
        , [current_tasks_count] int NOT NULL
        , [runnable_tasks_count] int NOT NULL
        , [current_workers_count] int NOT NULL
        , [active_workers_count] int NOT NULL
        , [work_queue_count] bigint NOT NULL
        , [pending_disk_io_count] int NOT NULL
        , [load_factor] int NOT NULL
        , PRIMARY KEY ([SnapshotId],[scheduler_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_SessionTransactions]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] int NOT NULL
        , [transaction_id] bigint NOT NULL
        , [transaction_descriptor] binary(8) NOT NULL
        , [enlist_count] int NOT NULL
        , [is_user_transaction] bit NOT NULL
        , [is_local] bit NOT NULL
        , [is_enlisted] bit NOT NULL
        , [is_bound] bit NOT NULL
        , [open_transaction_count] int NOT NULL
        , PRIMARY KEY ([SnapshotId],[session_id],[transaction_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_ActiveTransactions]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [transaction_id] bigint NOT NULL
        , [name] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [transaction_begin_time] datetime NOT NULL
        , [transaction_type] int NOT NULL
        , [transaction_uow] uniqueidentifier NULL
        , [transaction_state] int NOT NULL
        , [transaction_status] int NOT NULL
        , PRIMARY KEY ([SnapshotId],[transaction_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_DatabaseTransactions]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [transaction_id] bigint NOT NULL
        , [database_id] int NOT NULL
        , [database_transaction_begin_time] datetime NULL
        , [database_transaction_type] int NOT NULL
        , [database_transaction_state] int NOT NULL
        , [database_transaction_log_record_count] bigint NOT NULL
        , [database_transaction_log_bytes_used] bigint NOT NULL
        , [database_transaction_log_bytes_reserved] bigint NOT NULL
        , [database_transaction_log_bytes_used_system] bigint NOT NULL
        , [database_transaction_log_bytes_reserved_system] bigint NOT NULL
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_TempDbSessionUsage]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] smallint NOT NULL
        , [user_objects_alloc_page_count] bigint NOT NULL
        , [user_objects_dealloc_page_count] bigint NOT NULL
        , [internal_objects_alloc_page_count] bigint NOT NULL
        , [internal_objects_dealloc_page_count] bigint NOT NULL
        , PRIMARY KEY ([SnapshotId],[session_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_TempDbTaskUsage]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [session_id] smallint NOT NULL
        , [request_id] int NOT NULL
        , [exec_context_id] int NOT NULL
        , [user_objects_alloc_page_count] bigint NOT NULL
        , [user_objects_dealloc_page_count] bigint NOT NULL
        , [internal_objects_alloc_page_count] bigint NOT NULL
        , [internal_objects_dealloc_page_count] bigint NOT NULL
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_VersionStoreSpaceUsage]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [database_id] int NOT NULL
        , [reserved_page_count] bigint NOT NULL
        , PRIMARY KEY ([SnapshotId],[database_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_PersistentVersionStore]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [database_id] int NOT NULL
        , [pvs_filegroup_id] smallint NULL
        , [persistent_version_store_size_kb] bigint NULL
        , [online_index_version_store_size_kb] bigint NULL
        , PRIMARY KEY ([SnapshotId],[database_id])
    );
    CREATE TABLE [#CurrentOverview_CurrentStateSnapshot_SqlText]
    (
          [SnapshotId] uniqueidentifier NOT NULL
        , [CapturedAtUtc] datetime2(3) NOT NULL
        , [SqlHandle] varbinary(64) NOT NULL
        , [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseId] int NULL
        , [ObjectId] int NULL
        , [ObjectNumber] smallint NULL
        , [IsEncrypted] bit NULL
        , [EvidenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([SnapshotId],[SqlHandle])
    );
    IF @OutputMode NOT IN ('RAW','CONSOLE','TABLE','NONE')
       OR @DetailMode NOT IN ('SUMMARY','RELEVANT','ALL')
       OR @BlockingObjectDepth NOT IN ('NONE','STANDARD','DEEP')
       OR @MaxObjektAufloesungen IS NULL OR @MaxObjektAufloesungen NOT BETWEEN 1 AND 1000
       OR @SampleSeconds > 60
       OR @MaxZeilen < 0
       OR @MaxSqlTextZeichen < 0
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR @SystemdatenbankenEinbeziehen IS NULL OR @SystemdatenbankenEinbeziehen NOT IN (0,1)
       OR @MitSessions IS NULL OR @MitSessions NOT IN (0,1)
       OR @MitRequests IS NULL OR @MitRequests NOT IN (0,1)
       OR @MitBlocking IS NULL OR @MitBlocking NOT IN (0,1)
       OR @MitWaits IS NULL OR @MitWaits NOT IN (0,1)
       OR @MitTransactions IS NULL OR @MitTransactions NOT IN (0,1)
       OR @MitMemoryGrants IS NULL OR @MitMemoryGrants NOT IN (0,1)
       OR @MitTempDB IS NULL OR @MitTempDB NOT IN (0,1)
       OR @MitIO IS NULL OR @MitIO NOT IN (0,1)
       OR @MitLog IS NULL OR @MitLog NOT IN (0,1)
       OR @MitSqlText IS NULL OR @MitSqlText NOT IN (0,1)
       OR @HighImpactConfirmed IS NULL OR @HighImpactConfirmed NOT IN (0,1)
       OR @ToolHintergrundabfragenEinbeziehen IS NULL OR @ToolHintergrundabfragenEinbeziehen NOT IN (0,1)
       OR @GesamtenSqlTextEinbeziehen IS NULL OR @GesamtenSqlTextEinbeziehen NOT IN (0,1)
       OR @InputBufferEinbeziehen IS NULL OR @InputBufferEinbeziehen NOT IN (0,1)
       OR @ModulInfoEinbeziehen IS NULL OR @ModulInfoEinbeziehen NOT IN (0,1)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode<>'AVAILABLE'
    BEGIN
        INSERT [#CurrentOverview_ModuleStatus]
        VALUES(0,N'moduleStatus',N'USP_CurrentOverview',@StatusCode,1,0,0,@ErrorMessage);
        GOTO BuildOutputs;
    END;

    SET @CaptureSessions=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1
        OR @MitWaits=1 OR @MitTransactions=1 OR @MitMemoryGrants=1 OR @MitTempDB=1 THEN 1 ELSE 0 END;
    SET @CaptureRequests=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1
        OR @MitWaits=1 OR @MitTransactions=1 OR @MitMemoryGrants=1 OR @MitIO=1 THEN 1 ELSE 0 END;
    SET @CaptureConnections=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1 THEN 1 ELSE 0 END;
    SET @CaptureWaitingTasks=CASE WHEN @MitRequests=1 OR @MitBlocking=1 OR @MitWaits=1 OR @MitIO=1 THEN 1 ELSE 0 END;
    SET @CaptureMemoryGrants=CASE WHEN @MitRequests=1 OR @MitMemoryGrants=1 THEN 1 ELSE 0 END;
    SET @CaptureResourceGovernor=CASE WHEN @MitRequests=1 OR @MitMemoryGrants=1 OR @MitTempDB=1 THEN 1 ELSE 0 END;
    SET @CaptureTasks=CASE WHEN @MitRequests=1 OR @MitIO=1 THEN 1 ELSE 0 END;
    SET @CaptureSchedulers=CASE WHEN @MitRequests=1 OR @MitIO=1 THEN 1 ELSE 0 END;
    SET @CaptureTransactions=CASE WHEN @MitRequests=1 OR @MitTransactions=1 THEN 1 ELSE 0 END;
    SET @CaptureTempDbUsage=CASE WHEN @MitRequests=1 OR @MitTempDB=1 THEN 1 ELSE 0 END;
    SET @CaptureVersionStore=CASE WHEN @MitTempDB=1 THEN 1 ELSE 0 END;
    SET @CaptureSqlText=CASE
        WHEN @MitSessions=1 AND @MitSqlText=1 THEN 1
        WHEN @MitRequests=1 AND (@MitSqlText=1 OR @GesamtenSqlTextEinbeziehen=1 OR @ModulInfoEinbeziehen=1) THEN 1
        WHEN @MitBlocking=1 AND @MitSqlText=1 THEN 1
        WHEN @MitWaits=1 AND @MitSqlText=1 THEN 1
        WHEN @MitTransactions=1 AND @MitSqlText=1 THEN 1
        WHEN @MitMemoryGrants=1 AND @MitSqlText=1 THEN 1
        ELSE 0 END;
    SET @MaxSqlTextHandles=CASE
        WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 0
        WHEN @MaxZeilen>=1073741800 THEN 2147483647
        ELSE @MaxZeilen*2+32 END;

    IF @CaptureSessions=1 OR @CaptureRequests=1 OR @CaptureWaitingTasks=1
       OR @CaptureMemoryGrants=1 OR @CaptureTasks=1 OR @CaptureTransactions=1
       OR @CaptureTempDbUsage=1
    BEGIN
        SET @CurrentStateSnapshotId=NEWID();
        BEGIN TRY
            EXEC [monitor].[InternalCaptureCurrentStateSnapshot]
                  @SnapshotId=@CurrentStateSnapshotId
                , @CaptureSessions=@CaptureSessions
                , @CaptureRequests=@CaptureRequests
                , @CaptureConnections=@CaptureConnections
                , @CaptureWaitingTasks=@CaptureWaitingTasks
                , @CaptureMemoryGrants=@CaptureMemoryGrants
                , @CaptureResourceGovernor=@CaptureResourceGovernor
                , @CaptureTasks=@CaptureTasks
                , @CaptureSchedulers=@CaptureSchedulers
                , @CaptureTransactions=@CaptureTransactions
                , @CaptureTempDbUsage=@CaptureTempDbUsage
                , @CaptureVersionStore=@CaptureVersionStore
                , @CaptureSqlText=@CaptureSqlText
                , @MaxSqlTextHandles=@MaxSqlTextHandles;

            INSERT [#CurrentOverview_SnapshotStatus]
            (
                  [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc]
                , [CompletedAtUtc],[StatusCode],[IsPartial],[CapturedRowCount]
                , [ErrorNumber],[ErrorMessage]
            )
            SELECT
                  [SourceOrdinal],@CurrentStateSnapshotId,[SourceCode],[SourceObject],[CapturedAtUtc]
                , [CompletedAtUtc],[StatusCode],[IsPartial],[CapturedRowCount]
                , [ErrorNumber],[ErrorMessage]
            FROM [#CurrentOverview_CurrentStateSnapshot_SourceStatus]
            WHERE [SnapshotId]=@CurrentStateSnapshotId;

            SET @SnapshotConsumerId=@CurrentStateSnapshotId;
        END TRY
        BEGIN CATCH
            INSERT [#CurrentOverview_SnapshotStatus]
            VALUES
            (
                  0,@CurrentStateSnapshotId,'SNAPSHOT_OWNER',N'monitor.InternalCaptureCurrentStateSnapshot'
                , @StartedAtUtc,SYSUTCDATETIME(),'ERROR_HANDLED',1,0
                , ERROR_NUMBER(),ERROR_MESSAGE()
            );
            SET @SnapshotConsumerId=NULL;
        END CATCH;
    END;

    SET @SnapshotPartial=CASE WHEN EXISTS
    (
        SELECT 1
        FROM [#CurrentOverview_SnapshotStatus]
        WHERE [IsPartial]=1 OR [StatusCode] NOT IN ('AVAILABLE')
    ) THEN 1 ELSE 0 END;

    /* Sessions */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitSessions=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentSessions]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"sessions":"#CurrentOverview_Sessions"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',1,0,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',1,0,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(10,N'sessions',N'USP_CurrentSessions',N'#CurrentOverview_Sessions',0,0,0,0,NULL,NULL);

    /* Requests */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitRequests=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentRequests]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @GesamtenSqlTextEinbeziehen=@GesamtenSqlTextEinbeziehen
                , @InputBufferEinbeziehen=@InputBufferEinbeziehen
                , @ModulInfoEinbeziehen=@ModulInfoEinbeziehen
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{
                      "requests":"#CurrentOverview_Requests",
                      "requestContext":"#CurrentOverview_RequestContext",
                      "snapshotStatus":"#CurrentOverview_RequestSnapshotStatus",
                      "statements":"#CurrentOverview_Statements",
                      "batches":"#CurrentOverview_Batches",
                      "inputBuffers":"#CurrentOverview_InputBuffers"
                  }'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;

            INSERT [#CurrentOverview_SnapshotStatus]
            (
                  [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc]
                , [CompletedAtUtc],[StatusCode],[IsPartial],[CapturedRowCount]
                , [ErrorNumber],[ErrorMessage]
            )
            SELECT
                  [r].[SourceOrdinal],[r].[SnapshotId],[r].[SourceCode],[r].[SourceObject]
                , [r].[CapturedAtUtc],[r].[CompletedAtUtc],[r].[StatusCode],[r].[IsPartial]
                , [r].[CapturedRowCount],[r].[ErrorNumber],[r].[ErrorMessage]
            FROM [#CurrentOverview_RequestSnapshotStatus] AS [r]
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [#CurrentOverview_SnapshotStatus] AS [s]
                WHERE [s].[SourceCode]=[r].[SourceCode]
            );
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(20,N'requests',N'USP_CurrentRequests',N'#CurrentOverview_Requests',0,1,0,0,NULL,NULL);

    /* Blocking */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitBlocking=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentBlocking]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @BlockingObjektTiefe=@BlockingObjectDepth
                , @MaxObjektAufloesungen=@MaxObjektAufloesungen
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"blockingChains":"#CurrentOverview_Blocking"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(30,N'blocking',N'USP_CurrentBlocking',N'#CurrentOverview_Blocking',0,1,0,0,NULL,NULL);

    /* Waits */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitWaits=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentWaits]
                  @SessionIds=@SessionIds
                , @ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @SampleSeconds=@SampleSeconds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"currentTasks":"#CurrentOverview_Waits"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(40,N'waits',N'USP_CurrentWaits',N'#CurrentOverview_Waits',0,1,0,0,NULL,NULL);

    /* Transactions */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitTransactions=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTransactions]
                  @SessionIds=@SessionIds
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"transactions":"#CurrentOverview_Transactions"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(50,N'transactions',N'USP_CurrentTransactions',N'#CurrentOverview_Transactions',0,1,0,0,NULL,NULL);

    /* Memory grants */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitMemoryGrants=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentMemoryGrants]
                  @SessionIds=@SessionIds
                , @MitSqlText=@MitSqlText
                , @MaxSqlTextZeichen=@MaxSqlTextZeichen
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"memoryGrants":"#CurrentOverview_MemoryGrants"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(60,N'memoryGrants',N'USP_CurrentMemoryGrants',N'#CurrentOverview_MemoryGrants',0,1,0,0,NULL,NULL);

    /* TempDB */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitTempDB=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentTempDB]
                  @SessionIds=@SessionIds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"sessions":"#CurrentOverview_TempDBSessions","tempdbGovernance":"#CurrentOverview_TempDBGovernance","versionStore":"#CurrentOverview_VersionStore"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(70,N'tempdbSessions',N'USP_CurrentTempDB',N'#CurrentOverview_TempDBSessions',0,1,0,0,NULL,NULL);

    /* I/O */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitIO=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentIO]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @SampleSeconds=@SampleSeconds
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"files":"#CurrentOverview_IO"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen
                , @ParentCurrentStateSnapshotId=@SnapshotConsumerId;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(80,N'io',N'USP_CurrentIO',N'#CurrentOverview_IO',0,1,0,0,NULL,NULL);

    /* Transaction log */
    SET @ChildJson=NULL;SET @ChildStartedAtUtc=SYSUTCDATETIME();
    IF @MitLog=1
    BEGIN
        SET @ExecutedModules+=1;
        BEGIN TRY
            EXEC [monitor].[USP_CurrentLog]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen=@MaxZeilen
                , @ResultSetArt='TABLE'
                , @ResultTablesJson=N'{"logs":"#CurrentOverview_Logs"}'
                , @JsonErzeugen=1
                , @Json=@ChildJson OUTPUT
                , @PrintMeldungen=@PrintMeldungen;
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',1,1,1,@ChildDurationMs,@ChildJson,NULL);
        END TRY
        BEGIN CATCH
            SET @ChildDurationMs=DATEDIFF_BIG(MILLISECOND,@ChildStartedAtUtc,SYSUTCDATETIME());
            INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',1,1,0,@ChildDurationMs,@ChildJson,ERROR_MESSAGE());
        END CATCH;
    END
    ELSE INSERT [#CurrentOverview_ModulePayload] VALUES(90,N'logs',N'USP_CurrentLog',N'#CurrentOverview_Logs',0,1,0,0,NULL,NULL);

    SET @SnapshotPartial=CASE WHEN EXISTS
    (
        SELECT 1
        FROM [#CurrentOverview_SnapshotStatus]
        WHERE [IsPartial]=1
           OR [StatusCode] NOT IN ('AVAILABLE','NOT_COLLECTED')
    ) THEN 1 ELSE 0 END;

    INSERT [#CurrentOverview_ModuleStatus]
    (
          [ModuleOrdinal],[ResultName],[ModuleName],[StatusCode],[IsPartial]
        , [ReturnedRowCount],[DurationMs],[ErrorMessage]
    )
    SELECT
          [p].[ModuleOrdinal]
        , [p].[ResultName]
        , [p].[ModuleName]
        , [x].[StatusCode]
        , CONVERT(bit,CASE
              WHEN [p].[IsEnabled]=0 THEN 0
              WHEN [x].[StatusCode]='AVAILABLE'
               AND COALESCE(JSON_VALUE([p].[JsonValue],N'$.meta.isPartial'),N'false')=N'false'
                  THEN 0
              ELSE 1 END)
        , [x].[ReturnedRows]
        , [p].[DurationMs]
        , COALESCE([p].[ExecutionError],JSON_VALUE([p].[JsonValue],N'$.warnings[0].message'))
    FROM [#CurrentOverview_ModulePayload] AS [p]
    CROSS APPLY
    (
        SELECT
              [StatusCode]=CONVERT(varchar(40),CASE
                    WHEN [p].[IsEnabled]=0 THEN 'SKIPPED'
                    WHEN [p].[ExecutionError] IS NOT NULL THEN 'ERROR_HANDLED'
                    WHEN ISJSON([p].[JsonValue])<>1 THEN 'STATUS_UNAVAILABLE'
                    WHEN JSON_VALUE([p].[JsonValue],N'$.meta.statusCode') IS NULL THEN 'STATUS_UNAVAILABLE'
                    WHEN COALESCE
                         (
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.returnedRows')),
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.currentTaskRows'))
                         ) IS NULL THEN 'STATUS_UNAVAILABLE'
                    ELSE JSON_VALUE([p].[JsonValue],N'$.meta.statusCode') END)
            , [ReturnedRows]=CONVERT(bigint,CASE
                    WHEN [p].[IsEnabled]=0 THEN 0
                    ELSE COALESCE
                         (
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.returnedRows')),
                             TRY_CONVERT(bigint,JSON_VALUE([p].[JsonValue],N'$.meta.currentTaskRows')),
                             0
                         ) END)
    ) AS [x];

    INSERT [#CurrentOverview_Warnings]([ModuleName],[StatusCode],[Message])
    SELECT [ModuleName],[StatusCode],[ErrorMessage]
    FROM [#CurrentOverview_ModuleStatus]
    WHERE [IsPartial]=1 OR [StatusCode] NOT IN ('AVAILABLE','SKIPPED');

    INSERT [#CurrentOverview_Warnings]([ModuleName],[StatusCode],[Message])
    SELECT
          N'CurrentStateSnapshot'
        , [StatusCode]
        , COALESCE([ErrorMessage],CONCAT(N'Quelle ',[SourceCode],N' wurde nur teilweise materialisiert.'))
    FROM [#CurrentOverview_SnapshotStatus]
    WHERE [IsPartial]=1 OR [StatusCode] NOT IN ('AVAILABLE','NOT_COLLECTED');

    SELECT
          @FailedModules=COALESCE(SUM(CASE WHEN [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED') THEN 1 ELSE 0 END),0)
        , @PartialModules=COALESCE(SUM(CASE WHEN [IsPartial]=1 THEN 1 ELSE 0 END),0)
    FROM [#CurrentOverview_ModuleStatus];

    SET @StatusCode=CASE
        WHEN @ExecutedModules=0 THEN 'AVAILABLE'
        WHEN @FailedModules=0 AND @PartialModules=0 AND @SnapshotPartial=0 THEN 'AVAILABLE'
        WHEN @FailedModules<@ExecutedModules OR @SnapshotPartial=1 THEN 'AVAILABLE_LIMITED'
        ELSE 'ERROR_HANDLED' END;

BuildOutputs:
    IF @PrintMeldungen=1 AND (@FailedModules>0 OR @PartialModules>0)
    BEGIN
        SET @Message=FORMATMESSAGE(N'HINWEIS USP_CurrentOverview: %d Modul(e) fehlgeschlagen, %d Modul(e) partiell; %d aktiviert.',@FailedModules,@PartialModules,@ExecutedModules);
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @OutputMode IN ('CONSOLE','RAW')
    BEGIN
        SELECT
              [ModuleName]
            , [StatusCode]
            , [IsPartial]
            , [ReturnedRowCount]
            , [DurationMs]
            , [ErrorMessage]
        FROM [#CurrentOverview_ModuleStatus]
        ORDER BY [ModuleOrdinal];
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT
              [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc],[CompletedAtUtc]
            , [StatusCode],[IsPartial],[CapturedRowCount],[ErrorNumber],[ErrorMessage]
        FROM [#CurrentOverview_SnapshotStatus]
        ORDER BY [SourceOrdinal];

        SELECT [ModuleName],[StatusCode],[Message]
        FROM [#CurrentOverview_Warnings]
        ORDER BY [ModuleName];
    END;

    IF @OutputMode='CONSOLE' AND @DetailMode IN ('RELEVANT','ALL')
    BEGIN
        DECLARE @DetailSourceTable sysname;
        DECLARE @DetailSql nvarchar(max);

        DECLARE [DetailCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [p].[SourceTable]
            FROM [#CurrentOverview_ModulePayload] AS [p]
            INNER JOIN [#CurrentOverview_ModuleStatus] AS [s]
              ON [s].[ModuleOrdinal]=[p].[ModuleOrdinal]
            WHERE [p].[IsEnabled]=1
              AND [p].[IsMaterialized]=1
              AND [s].[ReturnedRowCount]>0
              AND [s].[StatusCode] IN ('AVAILABLE','AVAILABLE_LIMITED')
              AND (@DetailMode='ALL' OR [p].[IsRelevant]=1)
            ORDER BY [p].[ModuleOrdinal];

        OPEN [DetailCursor];
        FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @DetailSql=N'SELECT * FROM '+QUOTENAME(@DetailSourceTable)+N';';
            EXEC [sys].[sp_executesql] @DetailSql;
            FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable;
        END;
        CLOSE [DetailCursor];
        DEALLOCATE [DetailCursor];
    END;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=
        (
            SELECT
                  N'CurrentOverview' AS [resultName]
                , 4 AS [schemaVersion]
                , @StartedAtUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @CurrentStateSnapshotId AS [evidenceSnapshotId]
                , CONVERT(bit,CASE WHEN @StatusCode='INVALID_PARAMETER' OR @PartialModules>0 OR @FailedModules>0 OR @SnapshotPartial=1 THEN 1 ELSE 0 END) AS [isPartial]
                , @ExecutedModules AS [executedModules]
                , @FailedModules AS [failedModules]
                , @PartialModules AS [partialModules]
                , @ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @ModuleStatusJson nvarchar(max)=
        (
            SELECT [ResultName],[ModuleName],[StatusCode],[IsPartial],[ReturnedRowCount],[DurationMs],[ErrorMessage]
            FROM [#CurrentOverview_ModuleStatus]
            ORDER BY [ModuleOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @SnapshotStatusJson nvarchar(max)=
        (
            SELECT
                  [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc],[CompletedAtUtc]
                , [StatusCode],[IsPartial],[CapturedRowCount],[ErrorNumber],[ErrorMessage]
            FROM [#CurrentOverview_SnapshotStatus]
            ORDER BY [SourceOrdinal]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max)=
        (
            SELECT [ModuleName],[StatusCode],[Message]
            FROM [#CurrentOverview_Warnings]
            ORDER BY [ModuleName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @ChildProperties nvarchar(max)=
        (
            SELECT STRING_AGG
            (
                CONVERT(nvarchar(max),CONCAT
                (
                      N'"'
                    , STRING_ESCAPE([ResultName] COLLATE SQL_Latin1_General_CP1_CS_AS,'json')
                    , N'":'
                    , CASE WHEN ISJSON([JsonValue])=1
                           THEN [JsonValue] COLLATE SQL_Latin1_General_CP1_CS_AS
                           ELSE N'null' END
                )) COLLATE SQL_Latin1_General_CP1_CS_AS,
                N','
            ) WITHIN GROUP (ORDER BY [ModuleOrdinal])
            FROM [#CurrentOverview_ModulePayload]
            WHERE [IsEnabled]=1
        );

        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@MetaJson,N'{}')
            , N',"moduleStatus":',COALESCE(@ModuleStatusJson,N'[]')
            , N',"snapshotStatus":',COALESCE(@SnapshotStatusJson,N'[]')
            , CASE WHEN NULLIF(@ChildProperties,N'') IS NULL THEN N'' ELSE N','+@ChildProperties END
            , N',"warnings":',COALESCE(@WarningsJson,N'[]'),N'}'
        );
    END;

    IF @OutputMode='TABLE'
    BEGIN
        DECLARE @ExportResultName sysname;
        DECLARE @ExportTargetTable sysname;
        DECLARE @ExportSourceTable sysname;
        DECLARE @CanExport bit;

        DECLARE [ExportCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#CurrentOverview_ResultTableMap]
            ORDER BY [ResultName];

        OPEN [ExportCursor];
        FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT
                  @ExportSourceTable=CASE
                      WHEN @ExportResultName=N'moduleStatus' THEN N'#CurrentOverview_ModuleStatus'
                      WHEN @ExportResultName=N'snapshotStatus' THEN N'#CurrentOverview_SnapshotStatus'
                      WHEN @ExportResultName=N'requestContext' THEN N'#CurrentOverview_RequestContext'
                      WHEN @ExportResultName=N'statements' THEN N'#CurrentOverview_Statements'
                      WHEN @ExportResultName=N'batches' THEN N'#CurrentOverview_Batches'
                      WHEN @ExportResultName=N'inputBuffers' THEN N'#CurrentOverview_InputBuffers'
                      WHEN @ExportResultName=N'tempdbGovernance' THEN N'#CurrentOverview_TempDBGovernance'
                      WHEN @ExportResultName=N'versionStore' THEN N'#CurrentOverview_VersionStore'
                      WHEN @ExportResultName=N'warnings' THEN N'#CurrentOverview_Warnings'
                      ELSE NULL END
                , @CanExport=CASE
                    WHEN @ExportResultName=N'tempdbGovernance' THEN @MitTempDB
                    WHEN @ExportResultName=N'versionStore' THEN @MitTempDB
                    WHEN @ExportResultName IN
                         (N'moduleStatus',N'snapshotStatus',N'requestContext',
                          N'statements',N'batches',N'inputBuffers',N'warnings')
                        THEN 1
                    ELSE 0
                  END;

            IF @ExportSourceTable IS NULL
                SELECT
                      @ExportSourceTable=[SourceTable]
                    , @CanExport=[IsMaterialized]
                FROM [#CurrentOverview_ModulePayload]
                WHERE [ResultName]=@ExportResultName;

            IF @CanExport=1
                EXEC [monitor].[InternalWriteResultTable]
                      @SourceTable=@ExportSourceTable
                    , @TargetTable=@ExportTargetTable
                    , @ThrowOnError=1;

            FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable;
        END;
        CLOSE [ExportCursor];
        DEALLOCATE [ExportCursor];
    END;

    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO

