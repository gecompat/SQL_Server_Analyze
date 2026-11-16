USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_BackupChainAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure bewertet Backupketten und Wiederherstellbarkeitsevidenz aus msdb.
Datenquellen : msdb.dbo.backupset und msdb.dbo.restorehistory.
Methodik     : Prüft Full-/Differentialbasis, Log-LSN-Übergänge,
               Recovery-Fork-Wechsel, Prüfsummen, Schadensflags und Restorebeleg.
Grenzen      : msdb-Historie kann bereinigt oder unvollständig sein. Nur ein
               erfolgreicher Test-Restore beweist die Wiederherstellbarkeit.
Datenschutz  : Liest keine Medienpfade, Benutzernamen oder Backupinhalte.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_BackupChainAnalysis]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @HistoryDays                  int            = 35
    , @MitRestoreEvidence           bit            = 1
    , @MaxZeilen                    int            = 1000
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
    , @StatusCodeOut                varchar(40)    = NULL OUTPUT
    , @IsPartialOut                 bit            = NULL OUTPUT
    , @ErrorNumberOut               int            = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'summary',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                 THEN CONVERT(bigint, 9223372036854775807)
                                 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_BackupChainAnalysis';
        PRINT N'Analysiert Backup- und Restoremetadaten aus msdb für die ausgewählten Datenbanken.';
        PRINT N'Das Historienfenster begrenzt die sichtbare Kettenevidenz; der jüngste nicht-copy-only Full wird zusätzlich berücksichtigt.';
        PRINT N'Restorehistorie ist nur ein Metadatenbeleg; die Wiederherstellbarkeit ist durch einen erfolgreichen Test-Restore zu prüfen.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. Die optionale Liste ist eine durch Pipezeichen getrennte Folge einteiliger SQL-Namen. Der Parser behandelt | innerhalb von [...] als Namenstext, ]] als maskierte schließende Klammer und entfernt äußere Leerzeichen jedes Elements. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über 128 Zeichen sind ungültig; mehrteilige SQL-Namen, ungültige Klammern, leere Elemente und nach SQL_Latin1_General_CP1_CS_AS doppelte Namen führen ebenfalls zu INVALID_PARAMETER. NULL, eine leere Zeichenfolge und ein nur aus Leerzeichen bestehender Wert werden vor dem Listenparser wie keine Liste behandelt und wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizite Namen erzeugen DATABASE_UNAVAILABLE, ohne Opt-in ausgeschlossene Systemnamen SYSTEM_DATABASE_EXCLUDED in der Warning-Tabelle; wenn solche Warnungen vorliegen, wird der Status AVAILABLE_LIMITED. Die Liste ist mit einem nicht-NULL Pattern unvereinbar. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. Der Parameter wird als SQL-bit gebunden; numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. Nach der Bindung sind nur 0 und 1 gültig: NULL führt beim Kandidatenhelfer zu INVALID_PARAMETER. 0 lässt Systemdatenbanken aus, 1 schließt sie in die Kandidatenauswahl ein. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Das Eingabefeld ist nvarchar(4000) und nimmt höchstens 4000 UTF-16-Codeeinheiten an. NULL bedeutet Modus NONE; eine leere oder nur aus Leerzeichen bestehende Eingabe ist ungültig, und ein Inhalt, der nach einem Präfix leer bleibt, ebenfalls. Der Parser trimmt äußere Leerzeichen, erkennt LIKE:, REGEX: und REGEXI: ohne Beachtung der Großschreibung und entfernt danach das Präfix; der verbleibende Inhalt wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE wertet das Pattern mit SQL_Latin1_General_CP1_CS_AS case-sensitiv aus; exakte Datenbanknamen werden ebenfalls mit dieser Collation verglichen; REGEX nutzt Flag c und REGEXI Flag i. REGEX und REGEXI benötigen SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank. Ein nicht-NULL Pattern kann nicht zusammen mit einer wirksamen exakten Datenbankliste verwendet werden. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit=0; Default: 0. Der Parameter wird als SQL-bit gebunden: numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. NULL ist beim Kandidatenhelfer ungültig. Der Aufrufer übergibt @AnalysisClass ausdrücklich als NULL; dadurch wird kein Analyseklassen- oder High-Impact-Gate ausgelöst. Eine gebundene 1 erteilt keine zusätzliche Berechtigung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HistoryDays int=35; Default: 35. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 3650 Tagen. Die Backuphistorie wird mit dem Grenzwert DATEADD(DAY, -@HistoryDays, GETDATE()) auf backup_finish_date gefiltert; GETDATE verwendet die lokale Serverzeit. Die Prüfung auf Werte < 1 oder > 3650 steht vor der Backupabfrage, aber nach TABLE-Preflight und Hilfezweig. NULL besteht diese IF-Prüfung wegen SQL-UNKNOWN und ergibt keinen gültigen Cutoff; dann gelangen die normalen Backupsets nicht durch den Zeitvergleich, während der jüngste nicht-copy-only Full je Kandidat per separater OR-Bedingung unabhängig vom Fenster einbezogen wird. Ein zu kurzes Fenster kann weitere benötigte Full-/Diff-/Logevidenz ausschließen. Das Zeitfenster begrenzt Backupsets; die optionale Restorehistory-Abfrage wird nicht durch @HistoryDays begrenzt. msdb-Historie kann bereinigt oder unvollständig sein; ein scheinbares Gap kann deshalb auch aus nicht sichtbarer Historie resultieren. Sichtbare Metadatenkonsistenz beweist weder vorhandene/lesbare Medien noch eine erfolgreiche Wiederherstellung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitRestoreEvidence bit=1; Default: 1. Der SQL-bit-Parameter ist standardmäßig 1; nach Bindung aktiviert nur 1 die zusätzliche Auswertung von msdb.dbo.restorehistory und die Bewertung fehlender Restoreevidenz. Gebundene 0 und NULL deaktivieren beides; NULL wird nicht als ungültiger Parameter geprüft. Die Restorehistory-Abfrage ist für ausgewählte Datenbanken nicht nach @HistoryDays zeitlich eingeschränkt. Ein msdb-Restoreeintrag ist kein Nachweis eines erfolgreichen Test-Restores. Die Abfrage gruppiert nach destination_database_name und nimmt MAX(restore_date); sie belegt deshalb nur den letzten lokalen msdb-Eintrag für das Ziel, keine Zuordnung zu einem konkreten Backupset, Medienverfügbarkeit, Entschlüsselbarkeit oder erfolgreiche Wiederherstellung. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=1000; Default: 1000. Der int-Parameter akzeptiert 0 bis 2147483647; negative Werte sind ungültig. NULL und 0 werden vor der Ausgabe in das unbegrenzte bigint-Limit 9223372036854775807 überführt. Ein positives Limit entfernt nach vollständigem msdb-Scan und Kettenaggregation zusätzliche Summaryzeilen nach DatabaseId sowie Backupzeilen nach Abschlusszeit und Backupset-ID absteigend. Das Limit kürzt weder den Scan noch die vollständig berechneten Summaryzähler oder die Warning-Tabelle und setzt kein Truncation- oder Partial-Flag. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach COALESCE mit leerem Text, Trimmen und Großschreibung sind RAW, CONSOLE, TABLE und NONE zulässig. CONSOLE und TABLE werden für die Modusprüfung zunächst auf NONE normalisiert, danach aber über getrennte Adapter ausgeführt. RAW liefert vier Resultsets: Status-/Kontextzeile, Summary, Backups und Warnings. CONSOLE liefert nur Summary über InternalEmitConsoleResult; eine leere Summary ergibt dort eine erklärende Zeile, ohne separaten Status- oder Warning-Datensatz. TABLE schreibt nur das Resultset summary in die benannte lokale Zieltabelle und wirft bei einem Schreibfehler. NONE erzeugt keine fachlichen Resultsets. NULL, leer und andere Werte sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Ein nichtleerer Wert ist ausschließlich bei @ResultSetArt=TABLE zulässig; andernfalls wirft der Code vor Hilfe Fehler 51011. TABLE erwartet vor Hilfe ein gültiges JSON-Objekt mit genau dem case-sensitiven Schlüssel summary und einem JSON-String als Zieltabellennamen. Zulässig ist nur eine vorhandene lokale #Temp-Tabelle, nicht ##, nicht #Monitor*, mit höchstens 116 Zeichen. Das Ziel muss leer sein und genau eine Dummy-Seed-Spalte besitzen; der Schreibhelfer passt eine leere Zieltabelle an die native Struktur von summary an. Bei TABLE fehlt die Zuordnung, ist das JSON ungültig oder ist das Ziel nicht verfügbar, nicht leer oder anders strukturiert, schlägt der Preflight fehl. Bei Nicht-TABLE-Modi sind NULL, leerer oder nur aus Leerzeichen bestehender Wert zulässig. Resultset-Schlüssel und JSON-Stringwerte dürfen nicht doppelt vorkommen; zusätzliche Schlüssel, globale ##-Ziele und reservierte #Monitor-Präfixe sind unzulässig. Der Preflight prüft das Ziel unter anderem durch temporäres Hinzufügen und Entfernen einer Marker-Spalte. Ein ungültiges Mapping kann vor Hilfe Fehler 51011 auslösen; der spätere TABLE-Writer kann nach der Status-OUTPUT-Zuweisung Fehler 51010 werfen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. Der SQL-bit-Parameter wird vor der Ausführung konvertiert; nur der gebundene Wert 1 erzeugt JSON, während 0 und NULL überspringen. Das Dokument hat ein meta-Objekt und die Arrays summary, backups und warnings. summary und backups spiegeln das nach @MaxZeilen begrenzte Material; warnings bleiben ungekürzt. meta enthält resultName, schemaVersion, generatedAtUtc, statusCode, isPartial und historyDays und lässt NULL-Eigenschaften weg. Die drei Arrays verwenden INCLUDE_NULL_VALUES; Fehlernummer und Fehlermeldung werden separat über die Fehler-OUTPUTs beziehungsweise RAW bereitgestellt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. nvarchar(max) OUTPUT wird beim Eintritt auf NULL gesetzt. Nur wenn @JsonErzeugen=1 und der Hilfezweig nicht vorher zurückkehrt, wird ein JSON-Dokument mit meta-Objekt sowie summary-, backups- und warnings-Arrays zugewiesen. Bei fehlender JSON-Anforderung bleibt der OUTPUT-Wert NULL. Binden Sie eine Variable des deklarierten Typs mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Der SQL-bit-Parameter wird in der Procedure weder gelesen noch zur Ausgabe verwendet. Die Signatur setzt ihn auf 1; auch ein gebundenes NULL oder 0 ändert den Ausgabepfad nicht. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt zurück. Numerische Nichtnullwerte werden vor Eintritt zu bit 1 konvertiert; 0 aktiviert die Hilfe nicht. NULL bleibt NULL und aktiviert IF @Hilfe=1 ebenfalls nicht. Modusnormalisierung sowie TABLE-/ResultTablesJson-Vorprüfung liegen vor diesem Rücksprung. Der TABLE-Preflight kann die lokale Zieltabelle bereits durch temporäres Hinzufügen und Entfernen einer Marker-Spalte prüfen. Die Status-, Partial- und Fehler-OUTPUTs bleiben im Hilfezweig auf ihren Eingangs-/Bindungswerten; @Json wurde zuvor bereits auf NULL gesetzt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt am gemeinsamen Zuweisungspunkt vor JSON und Resultsets genau einen dieser acht Statuswerte: AVAILABLE, wenn ohne Kandidatenwarnungen kein abweichender Summarybefund vorliegt; CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE sind damit vereinbar. INVALID_PARAMETER bezeichnet eine ungültige Modus-, Historien-, Zeilen- oder Kandidatenauswahl. INTERNAL_ERROR bezeichnet einen Fehler bei der defensiven Kandidatentabellenprobe, ohne die Ursache ausschließlich auf ein falsches Schema festzulegen. UNAVAILABLE_FEATURE bezeichnet einen nicht unterstützten Regex-Engine-/Compatibility-Pfad. AVAILABLE_LIMITED hat bei vorhandenen Kandidatenwarnungen Vorrang. AVAILABLE_WITH_FINDING bezeichnet ohne Kandidatenwarnungen mindestens einen Summarycode außerhalb von CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE. DENIED_PERMISSION ist die Codeklassifikation des Analyse-CATCH für Fehler 229, 371 oder 916, keine unabhängige Ursachendiagnose. ERROR_HANDLED bezeichnet andere im Analyse-CATCH erfasste SQL-Fehler. @AnalysisClass=NULL überspringt die Analyseklassengates. Bei Hilfe oder frühem Preflight-THROW bleibt der gebundene Eingangswert unverändert. Vom TABLE-Writer behandelte Schreibfehler können nach der OUTPUT-Zuweisung Fehler 51010 auslösen und ändern den bereits zugewiesenen Status nicht. Binden Sie eine Variable des deklarierten Typs mit @StatusCodeOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. bit OUTPUT wird im regulären Ablauf gemeinsam mit Status vor JSON und Resultsets zugewiesen; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der interne Analyseflag wird mit 0 initialisiert; der Signatur-Default des OUTPUT-Arguments ist NULL. Die Hauptparameterprüfung für @HistoryDays, @MaxZeilen und @ResultSetArt setzt bei Fehlern 1; Kandidatenwarnungen und behandelte Analysefehler setzen ebenfalls 1. Ein Fehlerstatus des Kandidatenhelfers (INVALID_PARAMETER, UNAVAILABLE_FEATURE oder INTERNAL_ERROR) kann dagegen mit Partial=0 ankommen. Ein positives @MaxZeilen-Limit oder Ausgabeabschneiden setzt es nicht auf 1. Binden Sie eine Variable des deklarierten Typs mit @IsPartialOut=@Variable OUTPUT. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. int OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der Analyse-CATCH setzt ihn auf die abgefangene SQL-Fehlernummer; ohne solchen CATCH bleibt er NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorNumberOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. nvarchar(2048) OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Er enthält eine Validierungs-, Kandidaten- oder Analysefehlermeldung und bleibt bei erfolgreicher Auswertung NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorMessageOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HistoryDays=35, @MitRestoreEvidence=0, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @BackupChainJson nvarchar(max), @BackupChainStatus varchar(40), @BackupChainPartial bit, @BackupChainError int, @BackupChainMessage nvarchar(2048); EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@BackupChainJson OUTPUT, @StatusCodeOut=@BackupChainStatus OUTPUT, @IsPartialOut=@BackupChainPartial OUTPUT, @ErrorNumberOut=@BackupChainError OUTPUT, @ErrorMessageOut=@BackupChainMessage OUTPUT; SELECT @BackupChainStatus AS [StatusCode], @BackupChainPartial AS [IsPartial], @BackupChainError AS [ErrorNumber], @BackupChainMessage AS [ErrorMessage], @BackupChainJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #BackupChainAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"summary":"#BackupChainAnalysis_HelpExample"}''; SELECT * FROM #BackupChainAnalysis_HelpExample; DROP TABLE #BackupChainAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupChainAnalysis_HelpExample; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNamePattern=N''like:ExampleDatabase%'', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 6: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HistoryDays=7, @MitRestoreEvidence=1, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;

    CREATE TABLE [#BackupChainAnalysis_DatabaseCandidates]
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
    CREATE TABLE [#BackupChainAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#BackupChainAnalysis_Backups]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [BackupSetId] int NOT NULL
        , [BackupType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [BackupTypeDesc] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [BackupStartDate] datetime NULL
        , [BackupFinishDate] datetime NULL
        , [FirstLsn] numeric(25,0) NULL
        , [LastLsn] numeric(25,0) NULL
        , [CheckpointLsn] numeric(25,0) NULL
        , [DatabaseBackupLsn] numeric(25,0) NULL
        , [DifferentialBaseLsn] numeric(25,0) NULL
        , [FirstRecoveryForkGuid] uniqueidentifier NULL
        , [LastRecoveryForkGuid] uniqueidentifier NULL
        , [IsCopyOnly] bit NULL
        , [HasBackupChecksums] bit NULL
        , [IsDamaged] bit NULL
        , [IsEncrypted] bit NULL
        , [PreviousLogLastLsn] numeric(25,0) NULL
        , [LogGapDetected] bit NOT NULL DEFAULT (0)
    );
    CREATE TABLE [#BackupChainAnalysis_Summary]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LatestFullFinish] datetime NULL
        , [LatestMatchingDifferentialFinish] datetime NULL
        , [LatestLogFinish] datetime NULL
        , [LogBackupCountInWindow] bigint NOT NULL
        , [LogGapCountInWindow] bigint NOT NULL
        , [RecoveryForkTransitionCount] bigint NOT NULL
        , [DamagedBackupCount] bigint NOT NULL
        , [BackupWithoutChecksumCount] bigint NOT NULL
        , [LatestRestoreDate] datetime NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @HistoryDays < 1 OR @HistoryDays > 3650
       OR @MaxZeilen < 0 OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Datenbank-, Historien-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = NULL
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#BackupChainAnalysis_DatabaseCandidates',@WarningTable=N'#BackupChainAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        BEGIN TRY
            ;WITH [LatestFull] AS
            (
                SELECT [bs].[database_name], [bs].[backup_set_id] AS [BackupSetId],
                       ROW_NUMBER() OVER
                       (
                           PARTITION BY [bs].[database_name]
                           ORDER BY [bs].[backup_finish_date] DESC, [bs].[backup_set_id] DESC
                       ) AS [rn]
                FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
                JOIN [#BackupChainAnalysis_DatabaseCandidates] AS [c]
                  ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                WHERE [bs].[type] = 'D' AND [bs].[is_copy_only] = 0
            ),
            [Selected] AS
            (
                SELECT [bs].*
                FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
                JOIN [#BackupChainAnalysis_DatabaseCandidates] AS [c]
                  ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                LEFT JOIN [LatestFull] AS [f]
                  ON [f].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                 AND [f].[rn] = 1
                WHERE [bs].[type] IN ('D', 'I', 'L')
                  AND ([bs].[backup_finish_date] >= DATEADD(DAY, -@HistoryDays, GETDATE())
                       OR [bs].[backup_set_id] = [f].[BackupSetId])
            ),
            [WithPreviousLog] AS
            (
                SELECT [s].*,
                       CASE WHEN [s].[type] = 'L'
                            THEN LAG(CASE WHEN [s].[type] = 'L' THEN [s].[last_lsn] END)
                                 OVER (PARTITION BY [s].[database_name], [s].[type]
                                       ORDER BY [s].[backup_start_date], [s].[backup_set_id]) END AS [PreviousLogLastLsn]
                FROM [Selected] AS [s]
            )
            INSERT [#BackupChainAnalysis_Backups]
            (
                  [DatabaseName], [BackupSetId], [BackupType], [BackupTypeDesc]
                , [BackupStartDate], [BackupFinishDate], [FirstLsn], [LastLsn]
                , [CheckpointLsn], [DatabaseBackupLsn], [DifferentialBaseLsn]
                , [FirstRecoveryForkGuid], [LastRecoveryForkGuid]
                , [IsCopyOnly], [HasBackupChecksums], [IsDamaged], [IsEncrypted]
                , [PreviousLogLastLsn], [LogGapDetected]
            )
            SELECT
                  [database_name], [backup_set_id], [type]
                , CASE [type] WHEN 'D' THEN N'FULL' WHEN 'I' THEN N'DIFFERENTIAL' ELSE N'LOG' END
                , [backup_start_date], [backup_finish_date], [first_lsn], [last_lsn]
                , [checkpoint_lsn], [database_backup_lsn], [differential_base_lsn]
                , [first_recovery_fork_guid], [last_recovery_fork_guid]
                , [is_copy_only], [has_backup_checksums], [is_damaged]
                , CONVERT(bit, CASE WHEN [key_algorithm] IS NULL THEN 0 ELSE 1 END)
                , [PreviousLogLastLsn]
                , CONVERT(bit, CASE WHEN [type] = 'L' AND [PreviousLogLastLsn] IS NOT NULL
                                      AND [first_lsn] > [PreviousLogLastLsn] THEN 1 ELSE 0 END)
            FROM [WithPreviousLog];

            ;WITH [LatestFull] AS
            (
                SELECT [b].*, ROW_NUMBER() OVER
                       (PARTITION BY [DatabaseName] ORDER BY [BackupFinishDate] DESC, [BackupSetId] DESC) AS [rn]
                FROM [#BackupChainAnalysis_Backups] AS [b]
                WHERE [BackupType] = 'D' AND [IsCopyOnly] = 0
            ),
            [LatestMatchingDiff] AS
            (
                SELECT [d].[DatabaseName], MAX([d].[BackupFinishDate]) AS [FinishDate]
                FROM [#BackupChainAnalysis_Backups] AS [d]
                JOIN [LatestFull] AS [f]
                  ON [f].[DatabaseName] = [d].[DatabaseName] AND [f].[rn] = 1
                 AND [d].[DifferentialBaseLsn] = [f].[CheckpointLsn]
                WHERE [d].[BackupType] = 'I'
                  AND [d].[BackupFinishDate] >= [f].[BackupFinishDate]
                GROUP BY [d].[DatabaseName]
            ),
            [Forks] AS
            (
                SELECT [x].[DatabaseName],
                       SUM(CONVERT(bigint, CASE WHEN [x].[PreviousFork] IS NOT NULL
                                                AND [x].[LastRecoveryForkGuid] <> [x].[PreviousFork]
                                               THEN 1 ELSE 0 END)) AS [Transitions]
                FROM
                (
                    SELECT [b].[DatabaseName], [b].[LastRecoveryForkGuid],
                           LAG([b].[LastRecoveryForkGuid]) OVER
                           (PARTITION BY [b].[DatabaseName]
                            ORDER BY [b].[BackupStartDate], [b].[BackupSetId]) AS [PreviousFork]
                    FROM [#BackupChainAnalysis_Backups] AS [b]
                ) AS [x]
                GROUP BY [x].[DatabaseName]
            ),
            [RestoreEvidence] AS
            (
                SELECT [rh].[destination_database_name] AS [DatabaseName],
                       MAX([rh].[restore_date]) AS [LatestRestoreDate]
                FROM [msdb].[dbo].[restorehistory] AS [rh] WITH (NOLOCK)
                JOIN [#BackupChainAnalysis_DatabaseCandidates] AS [c]
                  ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [rh].[destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                WHERE @MitRestoreEvidence = 1
                GROUP BY [rh].[destination_database_name]
            ),
            [Aggregated] AS
            (
                SELECT [c].[DatabaseId], [c].[DatabaseName], [c].[RecoveryModelDesc],
                       MAX(CASE WHEN [f].[rn] = 1 THEN [f].[BackupFinishDate] END) AS [LatestFullFinish],
                       MAX([d].[FinishDate]) AS [LatestDiffFinish],
                       MAX(CASE WHEN [b].[BackupType] = 'L' THEN [b].[BackupFinishDate] END) AS [LatestLogFinish],
                       SUM(CONVERT(bigint, CASE WHEN [b].[BackupType] = 'L' THEN 1 ELSE 0 END)) AS [LogCount],
                       SUM(CONVERT(bigint, CASE WHEN [b].[LogGapDetected] = 1 THEN 1 ELSE 0 END)) AS [GapCount],
                       MAX(COALESCE([k].[Transitions], 0)) AS [ForkTransitions],
                       SUM(CONVERT(bigint, CASE WHEN [b].[IsDamaged] = 1 THEN 1 ELSE 0 END)) AS [DamagedCount],
                       SUM(CONVERT(bigint, CASE WHEN [b].[BackupSetId] IS NOT NULL
                                                AND COALESCE([b].[HasBackupChecksums], 0) = 0
                                               THEN 1 ELSE 0 END)) AS [NoChecksumCount],
                       MAX([r].[LatestRestoreDate]) AS [LatestRestoreDate]
                FROM [#BackupChainAnalysis_DatabaseCandidates] AS [c]
                LEFT JOIN [#BackupChainAnalysis_Backups] AS [b] ON [b].[DatabaseName] = [c].[DatabaseName]
                LEFT JOIN [LatestFull] AS [f] ON [f].[DatabaseName] = [c].[DatabaseName] AND [f].[rn] = 1
                LEFT JOIN [LatestMatchingDiff] AS [d] ON [d].[DatabaseName] = [c].[DatabaseName]
                LEFT JOIN [Forks] AS [k] ON [k].[DatabaseName] = [c].[DatabaseName]
                LEFT JOIN [RestoreEvidence] AS [r] ON [r].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                                                   = [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                GROUP BY [c].[DatabaseId], [c].[DatabaseName], [c].[RecoveryModelDesc]
            )
            INSERT [#BackupChainAnalysis_Summary]
            SELECT
                  [DatabaseId], [DatabaseName], [RecoveryModelDesc]
                , [LatestFullFinish], [LatestDiffFinish], [LatestLogFinish]
                , COALESCE([LogCount], 0), COALESCE([GapCount], 0), COALESCE([ForkTransitions], 0)
                , COALESCE([DamagedCount], 0), COALESCE([NoChecksumCount], 0), [LatestRestoreDate]
                , CASE WHEN [DatabaseId] = 2 THEN 'TEMPDB_NOT_APPLICABLE'
                       WHEN [LatestFullFinish] IS NULL THEN 'FULL_BACKUP_EVIDENCE_MISSING'
                       WHEN [DamagedCount] > 0 THEN 'DAMAGED_BACKUP_METADATA'
                       WHEN [GapCount] > 0 THEN 'LOG_CHAIN_GAP_IN_VISIBLE_HISTORY'
                       WHEN [RecoveryModelDesc] IN (N'FULL', N'BULK_LOGGED') AND [LatestLogFinish] IS NULL
                            THEN 'LOG_BACKUP_EVIDENCE_MISSING'
                       WHEN [NoChecksumCount] > 0 THEN 'BACKUP_WITHOUT_CHECKSUM_IN_VISIBLE_HISTORY'
                       WHEN @MitRestoreEvidence = 1 AND [LatestRestoreDate] IS NULL THEN 'RESTORE_EVIDENCE_MISSING'
                       ELSE 'CHAIN_METADATA_CONSISTENT' END
                , CASE WHEN [DatabaseId] = 2 THEN 'INFO'
                       WHEN [LatestFullFinish] IS NULL OR [DamagedCount] > 0 OR [GapCount] > 0 THEN 'HIGH'
                       WHEN ([RecoveryModelDesc] IN (N'FULL', N'BULK_LOGGED') AND [LatestLogFinish] IS NULL)
                         OR [NoChecksumCount] > 0 THEN 'MEDIUM' ELSE 'INFO' END
                , CONCAT(N'msdb-Sichtfenster ', @HistoryDays,
                         N' Tage; bereinigte Historie kann scheinbare Lücken erzeugen. Test-Restore bleibt erforderlich.')
            FROM [Aggregated];

            IF EXISTS (SELECT 1 FROM [#BackupChainAnalysis_DatabaseCandidateWarnings])
                SELECT @StatusCode = 'AVAILABLE_LIMITED', @IsPartial = 1;
            ELSE IF EXISTS
                    (SELECT 1 FROM [#BackupChainAnalysis_Summary]
                     WHERE [FindingCode] NOT IN ('CHAIN_METADATA_CONSISTENT', 'TEMPDB_NOT_APPLICABLE'))
                SET @StatusCode = 'AVAILABLE_WITH_FINDING';
        END TRY
        BEGIN CATCH
            SELECT @StatusCode = CASE WHEN ERROR_NUMBER() IN (229, 371, 916)
                                      THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                   @IsPartial = 1, @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = ERROR_MESSAGE();
        END CATCH;
    END;

    ;WITH [RankedSummary] AS
    (
        SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId]) AS [OutputOrdinal]
        FROM [#BackupChainAnalysis_Summary]
    )
    DELETE FROM [RankedSummary] WHERE [OutputOrdinal]>@Limit;
    ;WITH [RankedBackups] AS
    (
        SELECT *,ROW_NUMBER() OVER
        (
            ORDER BY [BackupFinishDate] DESC,[BackupSetId] DESC
        ) AS [OutputOrdinal]
        FROM [#BackupChainAnalysis_Backups]
    )
    DELETE FROM [RankedBackups] WHERE [OutputOrdinal]>@Limit;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'BackupChainAnalysis' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode], @IsPartial AS [isPartial],
                    @HistoryDays AS [historyDays]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @SummaryJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#BackupChainAnalysis_Summary] ORDER BY [DatabaseId]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @BackupJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#BackupChainAnalysis_Backups]
             ORDER BY [BackupFinishDate] DESC, [BackupSetId] DESC
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningJson nvarchar(max) =
            (SELECT * FROM [#BackupChainAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"summary":', COALESCE(@SummaryJson, N'[]'),
                           N',"backups":', COALESCE(@BackupJson, N'[]'),
                           N',"warnings":', COALESCE(@WarningJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_BackupChainAnalysis' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial], @HistoryDays AS [HistoryDays],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'msdb-Metadaten; Test-Restore erforderlich.' AS [Detail];
        SELECT TOP (@Limit) * FROM [#BackupChainAnalysis_Summary] ORDER BY [DatabaseId];
        SELECT TOP (@Limit) * FROM [#BackupChainAnalysis_Backups]
        ORDER BY [BackupFinishDate] DESC, [BackupSetId] DESC;
        SELECT * FROM [#BackupChainAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Backupketten' AS [Ergebnis], @Now AS [Stand_UTC], @StatusCode AS [Status],
               @HistoryDays AS [Historie_Tage], @ErrorMessage AS [Hinweis];
        SELECT TOP (@Limit) N'Wiederherstellbarkeitsevidenz' AS [Ergebnis],
               [DatabaseName] AS [Datenbank], [RecoveryModelDesc] AS [Recovery_Model],
               [LatestFullFinish] AS [Letztes_Full],
               [LatestMatchingDifferentialFinish] AS [Passendes_Differential],
               [LatestLogFinish] AS [Letztes_Log], [LogGapCountInWindow] AS [Log_Luecken],
               [RecoveryForkTransitionCount] AS [Fork_Wechsel],
               [DamagedBackupCount] AS [Beschaedigte_Backups],
               [BackupWithoutChecksumCount] AS [Ohne_Checksum],
               [LatestRestoreDate] AS [Letzter_Restorebeleg],
               [FindingCode] AS [Befund], [FindingSeverity] AS [Prioritaet], [EvidenceLimit] AS [Grenze]
        FROM [#BackupChainAnalysis_Summary]
        ORDER BY CASE [FindingSeverity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, [DatabaseId];
        SELECT N'Backupketten-Warnung' AS [Ergebnis], [RequestedName] AS [Datenbank],
               [StatusCode] AS [Status], [ErrorMessage] AS [Meldung]
        FROM [#BackupChainAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#BackupChainAnalysis_Summary'
            , @ResultLabel=N'BackupChainAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#BackupChainAnalysis_Summary'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
