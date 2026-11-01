USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_EncryptionAnalysis
Version      : 1.0.1
Stand        : 2026-10-09
Zweck        : Die Procedure bewertet den sichtbaren Lebenszyklus von TDE, Schutzertifikaten,
               expliziter Backupverschluesselung, Always Encrypted und Ledger.
Methodik     : Read-only Metadatenanalyse mit je Quelle isolierter Fehlergrenze.
Datenschutz  : Liest keine Schluesselpfade, Thumbprints, verschluesselten Werte,
               Backupmedien, SQL-Texte, Konten oder privaten Schluessel.
Grenzen      : Metadaten und lokale Zertifikat-Backuphistorie beweisen weder den
               Besitz externer Schluesselkopien noch die Wiederherstellbarkeit.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_EncryptionAnalysis]
      @DatabaseNames                              nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen               bit            = 0
    , @DatabaseNamePattern                        nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @NurProblematisch                           bit            = 0
    , @TdeTransitionWarnMinutes                   int            = 60
    , @CertificateExpiryWarnDays                  int            = 90
    , @ExpliziteBackupverschluesselungErwartet    bit            = 0
    , @BackupLookbackDays                         int            = 35
    , @MaxZeilen                                  int            = 1000
    , @LockTimeoutMs                              int            = 0
    , @ResultSetArt                               varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                               bit            = 0
    , @Json                                       nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                             bit            = 1
    , @Hilfe                                      bit            = 0
    , @StatusCodeOut                              varchar(40)    = NULL OUTPUT
    , @IsPartialOut                               bit            = NULL OUTPUT
    , @ErrorNumberOut                             int            = NULL OUTPUT
    , @ErrorMessageOut                            nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'databases',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               WHEN @MaxZeilen>0 THEN CONVERT(bigint,@MaxZeilen)
                               ELSE CONVERT(bigint,0) END;
    DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'));
    DECLARE @StatusCode varchar(40)='AVAILABLE';
    DECLARE @IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL;
    DECLARE @ErrorMessage nvarchar(2048)=NULL;
    DECLARE @CrossDatabaseRequested bit=0;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_EncryptionAnalysis';
        PRINT N'Bewertet sichtbare TDE- und Schutzobjektzustände, explizite Verschlüsselung des letzten Full-Backups sowie aggregierte Always Encrypted- und Ledger-Metadaten je ausgewählter Datenbank.';
        PRINT N'Liest keine Schlüsselpfade, Thumbprints, verschlüsselten Werte, Backupmedien, Konten, SQL-Texte oder privaten Schlüssel. Fehlende lokale Zertifikat-Backuphistorie beweist keinen fehlenden externen Export; Metadaten beweisen weder Besitz externer Schlüsselkopien noch Wiederherstellbarkeit.';
        PRINT N'@Hilfe=1 druckt die Hilfe und kehrt vor Analyse und Diagnose-OUTPUT-Zuweisung zurück. @PrintMeldungen wird im Procedure-Body nicht verwendet.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt master, tempdb, model, msdb aus; 1 lässt sie zu und beeinflusst SYSTEM_DATABASE_EXCLUDED-Warnings. Numerisch 0→0, jeder konvertierbare numerische Wert ungleich 0→1; NULL ergibt beim Candidate-Helper INVALID_PARAMETER; ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL/ausgelassen deaktiviert Pattern. Sonst äußere U+0020-Leerzeichen werden getrimmt; LIKE mit %, _, [...] oder Präfix like:, regex:, regexi: (Präfix case-insensitive). Nach Präfix kein erneutes Trim; leer/Präfix ohne Inhalt ungültig. LIKE verwendet SQL_Latin1_General_CP1_CS_AS; regex: Flag c, regexi: Flag i. Regex benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE; Syntax wird nicht vorgeprüft. Mit wirksamer Namensliste ist jeder nicht-NULL Patternwert unzulässig; Filter nach Kandidatenermittlung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 keine Bestätigung; 1 bestätigt nur ein tatsächlich angefordertes Klassen-Gruppengate. Numerisch 0→0, jeder Wert ungleich 0→1; NULL ergibt beim Helper INVALID_PARAMETER, ausgelassen = 0. Hier wird @AnalysisClass=NULL übergeben, daher kein Gate und kein teurerer Pfad. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@NurProblematisch bit; Default: 0. 0 exportiert INFO/MEDIUM/HIGH; 1 nur MEDIUM/HIGH. Filter nach Befundbildung und unabhängig von Status, Quellenstatus und Warnings. Numerisch 0→0, jeder numerische Wert ungleich 0→1; NULL ist nicht validiert und SQL-Filter lässt dann nur MEDIUM/HIGH durch. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@TdeTransitionWarnMinutes int; Default: 60. Minuten, gültig 1–525600; Zustände 2,4,5,6 werden TDE_TRANSITION_LONG_RUNNING, wenn Scanänderung älter als UTC-Zeit minus Fenster ist. NULL wird nicht abgefangen und unterdrückt den Befund über NULL-Vergleich. Ausgelassen = 60. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@CertificateExpiryWarnDays int; Default: 90. Tage, gültig 1–36500; Ablauf vor GETDATE()+Fenster ergibt TDE_CERTIFICATE_EXPIRY_WINDOW. NULL wird nicht abgefangen und unterdrückt den Befund über NULL-Vergleich. Ausgelassen = 90. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ExpliziteBackupverschluesselungErwartet bit; Default: 0. 0 keine Erwartungswarnung; 1 MEDIUM, wenn kein jüngstes nicht-copy-only Full-Backup im Lookback sichtbar ist oder key_algorithm NULL ist. Getrennt von TDE. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unterdrückt mangels Validierung den Vergleich. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@BackupLookbackDays int; Default: 35. Tage vor GETDATE(), gültig 1–3650. Nur backupset type D, is_copy_only=0 und finish_date im Fenster; jüngstes je Datenbank. NULL ergibt NULL-Datumsgrenze/keinen Treffer ohne Parameterfehler. Ausgelassen = 35. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL oder 0 unbegrenzt; positive int-Zahl ist Maximalzeilen nach Severity HIGH, MEDIUM, INFO und DatabaseId; negativ INVALID_PARAMETER und leere Exportmenge. Limit nach Analyse und Filter, nicht für Status/Sources/Warnings. Ausgelassen = 1000. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int; Default: 0. Nichtnegative ganze Zahl in Millisekunden von 0 bis 2147483647; 0 verlangt im jeweiligen datenbanklokalen Aggregatbatch sofortige Rückgabe bei einer Sperre. Negativ ist INVALID_PARAMETER. Der Wert ist kein Gesamtzeitbudget und wird nur in diese dynamischen Aggregatbatches eingefügt; übrige direkte Quellen verwenden LOCK_TIMEOUT 0. SET-Werte im dynamischen Batch enden mit dessen Rückkehr. NULL wird nicht abgefangen und macht den verketteten Batchtext @Sql zu NULL. Daraus wird hier kein garantierter SQL-Fehler und kein bestimmter Laufzeiteffekt behauptet; die Procedure definiert für NULL keinen regulären Timeoutwert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Normalisiert mit UPPER/TRIM/COALESCE; gültig RAW, CONSOLE, TABLE, NONE. RAW vier technische Resultsets; CONSOLE ein beschriftetes Ergebnis über InternalEmitConsoleResult aus der Exportmenge; TABLE schreibt einzig databases; NONE keine Hauptsets. JSON separat über @JsonErzeugen. NULL/leer→INVALID_PARAMETER; äußere Leerzeichen und Case normalisiert. TABLE/CONSOLE intern auf NONE umgeschaltet. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei TABLE zulässig; sonst nichtleerer Wert THROW 51011. Helper preflight verlangt Mapping für exakt ein benanntes Ergebnis databases, mindestens ein Paar, string key/value, passende exakte/case-sensitive Schlüssel, keine doppelten Schlüssel oder case-insensitive doppelten Ziele/Extra-Schlüssel; Quelle muss vorhandene leere lokale #Temp-Tabelle sein, kein ##/#Monitor, Länge <=116. NULL/leerer Text scheitert am TABLE-Preflight. Vor Analyse geprüft; späterer Writer prüft Zielspalten per Namen und kann Teilwrites hinterlassen. Preflight/Writer THROW bei ThrowOnError=1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt JSON mit meta, databases, sources, warnings; Datenarrays INCLUDE_NULL_VALUES. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL wird nicht validiert und überspringt IF. Ausgelassen = 0; unabhängig von ResultSetArt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max); sofort beim Eintritt NULL, auch bei Hilfe. Bei @JsonErzeugen=1 empfängt gebundene nvarchar(max)-Variable JSON mit resultName/schemaVersion/Zeit/Status/Partial/Version, databases, sources, warnings; sonst NULL. Mit passender Variable OUTPUT binden, sonst wird Wert nicht empfangen. Hilfe lässt NULL. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@PrintMeldungen bit; Default: 1. Signatur bietet bit 0/1 (numerisch 0→0, jeder numerische Wert ungleich 0→1), NULL unvalidiert, ausgelassen = 1. Parameter wird im Body nicht gelesen und hat keine Wirkung; Hilfe wird separat von @Hilfe gesteuert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit; Default: 0. 0 Analyse; 1 druckt die Hilfetexte und RETURN vor Tabellen, Validierung, Kandidatensuche und Diagnose-OUTPUT-Zuweisungen; @Json wurde davor NULL. Numerisch 0→0/jeder numerische Wert ungleich 0→1; NULL unvalidiert und normaler Pfad. Ausgelassen = 0. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable. Alle erreichbaren Statuswerte: AVAILABLE bedeutet Abschluss ohne gesetzte Partialität und ohne HIGH-/MEDIUM-Befund; AVAILABLE_WITH_FINDING bedeutet mindestens einen HIGH-/MEDIUM-Befund bei sonst verfügbarem Ergebnis; AVAILABLE_LIMITED bedeutet partielle Quellenaufnahme oder Auswahlwarnungen; INVALID_PARAMETER bedeutet lokale oder delegierte ungültige Eingaben; INTERNAL_ERROR bedeutet, dass der Auswahlhelfer seine erwartete Kandidatentabelle nicht verwenden kann; UNAVAILABLE_FEATURE bedeutet einen mangels SQL Server 2025/Compatibility Level 170 nicht ausführbaren Regexfilter. Lokale/delegierte Eingabefehler verhindern den regulären Analysepfad. Bei erfolgreicher Vorbereitung gehen Quellenpartialität und anschließend Auswahlwarnungen einem Findingstatus vor. Weil @AnalysisClass=NULL übergeben wird, gibt es hier keine Analyseklassen-Gruppen- oder High-Impact-Freigabe. Hilfe lässt den Eingangswert dieses OUTPUTs unverändert. Reguläre Statusausgabe bestätigt keine Wiederherstellbarkeit. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit; mit passender OUTPUT-Variable binden. 1 bei partieller Quelle, Auswahlwarning oder Status außerhalb AVAILABLE/AVAILABLE_WITH_FINDING; sonst 0. Hilfe lässt unverändert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine int-Variable. Empfängt die letzte in den äußeren Quellen- oder Aggregations-CATCH-Blöcken gespeicherte native SQL-Fehlernummer; spätere solche Zuweisungen überschreiben frühere. Ohne diese Zuweisungen bleibt der reguläre Wert NULL. Lokale Parameterfehler setzen keine Nummer. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und eine Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine nvarchar(2048)-Variable. Empfängt die zuletzt in den äußeren Quellen-/Aggregations-CATCH-Blöcken gespeicherte native Fehlermeldung oder den Vorbereitungs-/Validierungstext. Lokale INVALID_PARAMETER-Prüfung setzt eine generische Nachricht, ohne Fehlernummer. Spätere tatsächliche Meldungszuweisungen überschreiben frühere. Der datenbanklokale Aggregat-CATCH setzt nur Partialität und Auswahlwarnung, ohne diesen Diagnose-OUTPUT zu füllen. Ohne gespeicherte Meldung wird regulär NULL ausgegeben. Geworfene TABLE-Vorprüfungs-/Writerfehler umgehen die normale abschließende OUTPUT-Zuweisung; Hilfe lässt den Eingangswert unverändert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'EXEC [monitor].[USP_EncryptionAnalysis] @MaxZeilen=200, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_EncryptionAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'CREATE TABLE [#EncryptionAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_EncryptionAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databases":"#EncryptionAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#EncryptionAnalysis_HelpExample]; DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#EncryptionAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_EncryptionAnalysis] @Hilfe=1;';
        RETURN;
    END;

    CREATE TABLE [#EncryptionAnalysis_DatabaseCandidates]
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
    CREATE TABLE [#EncryptionAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#EncryptionAnalysis_SourceStatus]
    (
          [SourceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#EncryptionAnalysis_Encryption]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEncrypted] bit NULL
        , [EncryptionState] int NULL
        , [EncryptionStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PercentComplete] real NULL
        , [EncryptionScanState] int NULL
        , [EncryptionScanStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EncryptionScanModifyDate] datetime NULL
        , [KeyAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KeyLength] int NULL
        , [EncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorExpiryDate] datetime NULL
        , [ProtectorPrivateKeyLastBackupDate] datetime NULL
        , [LatestFullBackupFinishDate] datetime NULL
        , [LatestFullBackupExplicitlyEncrypted] bit NULL
        , [LatestFullBackupAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LatestFullBackupEncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ColumnMasterKeyCount] bigint NULL
        , [ColumnEncryptionKeyCount] bigint NULL
        , [EncryptedColumnCount] bigint NULL
        , [LedgerTableCount] bigint NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#EncryptionAnalysis_Export]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEncrypted] bit NULL
        , [EncryptionState] int NULL
        , [EncryptionStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PercentComplete] real NULL
        , [EncryptionScanState] int NULL
        , [EncryptionScanStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EncryptionScanModifyDate] datetime NULL
        , [KeyAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [KeyLength] int NULL
        , [EncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectorExpiryDate] datetime NULL
        , [ProtectorPrivateKeyLastBackupDate] datetime NULL
        , [LatestFullBackupFinishDate] datetime NULL
        , [LatestFullBackupExplicitlyEncrypted] bit NULL
        , [LatestFullBackupAlgorithm] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LatestFullBackupEncryptorType] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ColumnMasterKeyCount] bigint NULL
        , [ColumnEncryptionKeyCount] bigint NULL
        , [EncryptedColumnCount] bigint NULL
        , [LedgerTableCount] bigint NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxZeilen<0 OR @LockTimeoutMs<0
       OR @TdeTransitionWarnMinutes<1 OR @TdeTransitionWarnMinutes>525600
       OR @CertificateExpiryWarnDays<1 OR @CertificateExpiryWarnDays>36500
       OR @BackupLookbackDays<1 OR @BackupLookbackDays>3650
       OR @OutputMode NOT IN ('RAW','CONSOLE','NONE')
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,
               @ErrorMessage=N'Ungueltiger Grenzwert, Datenbank-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass=NULL
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#EncryptionAnalysis_DatabaseCandidates',@WarningTable=N'#EncryptionAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    INSERT [#EncryptionAnalysis_Encryption]([DatabaseId],[DatabaseName],[IsEncrypted],[FindingCode],[FindingSeverity],[EvidenceLimit])
    SELECT [DatabaseId],[DatabaseName],NULL,'SOURCE_PENDING','INFO',
           N'Read-only Metadaten; Schluesselbesitz und Wiederherstellbarkeit werden nicht bewiesen.'
    FROM [#EncryptionAnalysis_DatabaseCandidates];

    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            UPDATE [e]
            SET [IsEncrypted]=[d].[is_encrypted],
                [EncryptionState]=[k].[encryption_state],
                [EncryptionStateDesc]=CASE [k].[encryption_state]
                    WHEN 0 THEN N'NO_DATABASE_KEY' WHEN 1 THEN N'UNENCRYPTED'
                    WHEN 2 THEN N'ENCRYPTION_IN_PROGRESS' WHEN 3 THEN N'ENCRYPTED'
                    WHEN 4 THEN N'KEY_CHANGE_IN_PROGRESS' WHEN 5 THEN N'DECRYPTION_IN_PROGRESS'
                    WHEN 6 THEN N'PROTECTION_CHANGE_IN_PROGRESS' END,
                [PercentComplete]=[k].[percent_complete],
                [EncryptionScanState]=[k].[encryption_scan_state],
                [EncryptionScanStateDesc]=CASE [k].[encryption_scan_state]
                    WHEN 0 THEN N'NONE' WHEN 1 THEN N'RUNNING' WHEN 2 THEN N'SUSPENDED'
                    WHEN 3 THEN N'ABORTED' WHEN 4 THEN N'COMPLETE' END,
                [EncryptionScanModifyDate]=[k].[encryption_scan_modify_date],
                [KeyAlgorithm]=[k].[key_algorithm],
                [KeyLength]=[k].[key_length],
                [EncryptorType]=[k].[encryptor_type],
                [ProtectorName]=[c].[name],
                [ProtectorExpiryDate]=[c].[expiry_date],
                [ProtectorPrivateKeyLastBackupDate]=[c].[pvt_key_last_backup_date]
            FROM [#EncryptionAnalysis_Encryption] AS [e]
            JOIN [sys].[databases] AS [d] WITH (NOLOCK) ON [d].[database_id]=[e].[DatabaseId]
            LEFT JOIN [sys].[dm_database_encryption_keys] AS [k] WITH (NOLOCK) ON [k].[database_id]=[e].[DatabaseId]
            LEFT JOIN [master].[sys].[certificates] AS [c] WITH (NOLOCK)
              ON [k].[encryptor_type] IN(N'CERTIFICATE',N'CERTIFICATE_OAEP_256') AND [c].[thumbprint]=[k].[encryptor_thumbprint];

            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'sys.dm_database_encryption_keys + master.sys.certificates','AVAILABLE',0,
             N'TDE-Zustand und sichtbare Zertifikatmetadaten gelesen; Thumbprints und Schluesselmaterial werden nicht ausgegeben.');
        END TRY
        BEGIN CATCH
            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'sys.dm_database_encryption_keys + master.sys.certificates',
             CASE WHEN ERROR_NUMBER() IN (229,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,
             N'TDE- oder Zertifikatmetadaten waren nicht vollstaendig lesbar; die uebrigen Quellen werden weiter ausgewertet.');
            SELECT @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
        END CATCH;

        BEGIN TRY
            ;WITH [LatestFull] AS
            (
                SELECT [bs].[database_name],[bs].[backup_finish_date],[bs].[key_algorithm],[bs].[encryptor_type],
                       ROW_NUMBER() OVER(PARTITION BY [bs].[database_name]
                                         ORDER BY [bs].[backup_finish_date] DESC,[bs].[backup_set_id] DESC) AS [rn]
                FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
                JOIN [#EncryptionAnalysis_DatabaseCandidates] AS [d]
                  ON [d].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                WHERE [bs].[type]='D' AND [bs].[is_copy_only]=0
                  AND [bs].[backup_finish_date]>=DATEADD(DAY,-@BackupLookbackDays,GETDATE())
            )
            UPDATE [e]
            SET [LatestFullBackupFinishDate]=[b].[backup_finish_date],
                [LatestFullBackupExplicitlyEncrypted]=CONVERT(bit,CASE WHEN [b].[key_algorithm] IS NULL THEN 0 ELSE 1 END),
                [LatestFullBackupAlgorithm]=[b].[key_algorithm],
                [LatestFullBackupEncryptorType]=[b].[encryptor_type]
            FROM [#EncryptionAnalysis_Encryption] AS [e]
            JOIN [LatestFull] AS [b]
              ON [b].[rn]=1
             AND [b].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
               = [e].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS;

            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'msdb.dbo.backupset','AVAILABLE',0,
             N'Nur Zeitpunkt und Verschluesselungsart des letzten Full-Backups im Sichtfenster; keine Medien-, Konto- oder Serverdaten.');
        END TRY
        BEGIN CATCH
            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'msdb.dbo.backupset',CASE WHEN ERROR_NUMBER() IN (229,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,
             N'Backupverschluesselungsmetadaten waren nicht lesbar; andere Quellen bleiben auswertbar.');
            SELECT @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
        END CATCH;

        BEGIN TRY
            DECLARE @DatabaseId int,@DatabaseName sysname,@Sql nvarchar(max),@LocalAggregatePartial bit=0;
            DECLARE [database_cursor] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseId],[DatabaseName] FROM [#EncryptionAnalysis_DatabaseCandidates]
                WHERE [StateDesc]=N'ONLINE' AND [DatabaseId]<>2 ORDER BY [DatabaseId];
            OPEN [database_cursor];
            FETCH NEXT FROM [database_cursor] INTO @DatabaseId,@DatabaseName;
            WHILE @@FETCH_STATUS=0
            BEGIN
                BEGIN TRY
                    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(11),@LockTimeoutMs)+N'; UPDATE [e] SET '
                        +N'[ColumnMasterKeyCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[column_master_keys] WITH (NOLOCK)),'
                        +N'[ColumnEncryptionKeyCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[column_encryption_keys] WITH (NOLOCK)),'
                        +N'[EncryptedColumnCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[columns] WITH (NOLOCK) WHERE [encryption_type] IS NOT NULL)'
                        +CASE WHEN @Major>=16 THEN
                          N',[LedgerTableCount]=(SELECT COUNT_BIG(*) FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[tables] WITH (NOLOCK) WHERE [ledger_type]<>0)'
                          ELSE N',[LedgerTableCount]=NULL' END
                        +N' FROM [#EncryptionAnalysis_Encryption] AS [e] WHERE [e].[DatabaseId]=@pDatabaseId;';
                    EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseId int',@pDatabaseId=@DatabaseId;
                END TRY
                BEGIN CATCH
                    SELECT @IsPartial=1,@LocalAggregatePartial=1;
                    IF NOT EXISTS(SELECT 1 FROM [#EncryptionAnalysis_DatabaseCandidateWarnings] WHERE [RequestedName]=@DatabaseName)
                        INSERT [#EncryptionAnalysis_DatabaseCandidateWarnings] VALUES
                        (@DatabaseName,CASE WHEN ERROR_NUMBER() IN (229,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                         N'Aggregierte Always-Encrypted- oder Ledger-Metadaten waren fuer diese Datenbank nicht lesbar.');
                END CATCH;
                FETCH NEXT FROM [database_cursor] INTO @DatabaseId,@DatabaseName;
            END;
            CLOSE [database_cursor];
            DEALLOCATE [database_cursor];

            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'sys.column_master_keys + sys.column_encryption_keys + sys.columns + sys.tables','AVAILABLE',@LocalAggregatePartial,
             CASE WHEN @Major>=16 THEN N'Nur aggregierte Objektanzahlen; keine Schluesselpfade, Signaturen, Werte oder Objektnamen.'
                  ELSE N'Nur aggregierte Always-Encrypted-Anzahlen; Ledger ist vor SQL Server 2022 nicht verfuegbar.' END);
        END TRY
        BEGIN CATCH
            IF CURSOR_STATUS('local','database_cursor')>=0 CLOSE [database_cursor];
            IF CURSOR_STATUS('local','database_cursor')>-3 DEALLOCATE [database_cursor];
            INSERT [#EncryptionAnalysis_SourceStatus] VALUES
            (N'sys.column_master_keys + sys.column_encryption_keys + sys.columns + sys.tables','ERROR_HANDLED',1,
             N'Die datenbanklokale Aggregation wurde abgefangen; TDE- und Backupquellen bleiben auswertbar.');
            SELECT @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
        END CATCH;

        UPDATE [e]
        SET [FindingCode]=CASE
                WHEN [EncryptionScanState]=3 THEN 'TDE_SCAN_ABORTED'
                WHEN [EncryptionScanState]=2 THEN 'TDE_SCAN_SUSPENDED'
                WHEN [EncryptionState] IN (2,4,5,6)
                 AND [EncryptionScanModifyDate]<DATEADD(MINUTE,-@TdeTransitionWarnMinutes,SYSUTCDATETIME())
                    THEN 'TDE_TRANSITION_LONG_RUNNING'
                WHEN [IsEncrypted]=1 AND [EncryptorType] IN(N'CERTIFICATE',N'CERTIFICATE_OAEP_256') AND [ProtectorName] IS NULL
                    THEN 'TDE_PROTECTOR_NOT_VISIBLE'
                WHEN [IsEncrypted]=1 AND [ProtectorExpiryDate]<DATEADD(DAY,@CertificateExpiryWarnDays,GETDATE())
                    THEN 'TDE_CERTIFICATE_EXPIRY_WINDOW'
                WHEN [IsEncrypted]=1 AND [EncryptorType] IN(N'CERTIFICATE',N'CERTIFICATE_OAEP_256') AND [ProtectorPrivateKeyLastBackupDate] IS NULL
                    THEN 'LOCAL_CERTIFICATE_EXPORT_EVIDENCE_MISSING'
                WHEN @ExpliziteBackupverschluesselungErwartet=1
                 AND [LatestFullBackupFinishDate] IS NULL THEN 'FULL_BACKUP_EVIDENCE_MISSING'
                WHEN @ExpliziteBackupverschluesselungErwartet=1
                 AND [LatestFullBackupExplicitlyEncrypted]=0 THEN 'EXPLICIT_BACKUP_ENCRYPTION_MISSING'
                WHEN [IsEncrypted]=1 THEN 'TDE_METADATA_CONSISTENT'
                ELSE 'DATABASE_NOT_TDE_ENCRYPTED' END,
            [FindingSeverity]=CASE
                WHEN [EncryptionScanState] IN (2,3) THEN 'HIGH'
                WHEN [EncryptionState] IN (2,4,5,6)
                 AND [EncryptionScanModifyDate]<DATEADD(MINUTE,-@TdeTransitionWarnMinutes,SYSUTCDATETIME()) THEN 'MEDIUM'
                WHEN [IsEncrypted]=1 AND [EncryptorType] IN(N'CERTIFICATE',N'CERTIFICATE_OAEP_256') AND [ProtectorName] IS NULL THEN 'MEDIUM'
                WHEN [IsEncrypted]=1 AND [ProtectorExpiryDate]<DATEADD(DAY,@CertificateExpiryWarnDays,GETDATE()) THEN 'MEDIUM'
                WHEN @ExpliziteBackupverschluesselungErwartet=1
                 AND ([LatestFullBackupFinishDate] IS NULL OR [LatestFullBackupExplicitlyEncrypted]=0) THEN 'MEDIUM'
                ELSE 'INFO' END,
            [EvidenceLimit]=CASE
                WHEN [IsEncrypted]=1 AND [EncryptorType] IN(N'CERTIFICATE',N'CERTIFICATE_OAEP_256') AND [ProtectorPrivateKeyLastBackupDate] IS NULL
                    THEN N'Kein lokaler Exportzeitpunkt sichtbar; externe Schluesselkopien koennen dennoch existieren.'
                WHEN @ExpliziteBackupverschluesselungErwartet=1
                    THEN N'TDE und explizite Backupverschluesselung sind getrennte Schutzmechanismen; ein Test-Restore bleibt erforderlich.'
                ELSE N'Read-only Metadaten; Schluesselbesitz und Wiederherstellbarkeit werden nicht bewiesen.' END
        FROM [#EncryptionAnalysis_Encryption] AS [e];

        IF EXISTS(SELECT 1 FROM [#EncryptionAnalysis_SourceStatus] WHERE [IsPartial]=1)
            SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
        ELSE IF EXISTS(SELECT 1 FROM [#EncryptionAnalysis_Encryption]
                       WHERE [FindingSeverity] IN ('HIGH','MEDIUM'))
            SET @StatusCode='AVAILABLE_WITH_FINDING';
    END;

    IF @StatusCode NOT IN('AVAILABLE','AVAILABLE_WITH_FINDING') SET @IsPartial=1;
    IF EXISTS(SELECT 1 FROM [#EncryptionAnalysis_DatabaseCandidateWarnings])
    BEGIN
        SET @IsPartial=1;
        IF @StatusCode IN('AVAILABLE','AVAILABLE_WITH_FINDING') SET @StatusCode='AVAILABLE_LIMITED';
    END;

    INSERT [#EncryptionAnalysis_Export]
    ([DatabaseId],[DatabaseName],[IsEncrypted],[EncryptionState],[EncryptionStateDesc],
     [PercentComplete],[EncryptionScanState],[EncryptionScanStateDesc],[EncryptionScanModifyDate],[KeyAlgorithm],
     [KeyLength],[EncryptorType],[ProtectorName],[ProtectorExpiryDate],[ProtectorPrivateKeyLastBackupDate],
     [LatestFullBackupFinishDate],[LatestFullBackupExplicitlyEncrypted],[LatestFullBackupAlgorithm],[LatestFullBackupEncryptorType],[ColumnMasterKeyCount],
     [ColumnEncryptionKeyCount],[EncryptedColumnCount],[LedgerTableCount],[FindingCode],[FindingSeverity],
     [EvidenceLimit])
    SELECT TOP(@Limit) [DatabaseId],[DatabaseName],[IsEncrypted],[EncryptionState],[EncryptionStateDesc],
     [PercentComplete],[EncryptionScanState],[EncryptionScanStateDesc],[EncryptionScanModifyDate],[KeyAlgorithm],
     [KeyLength],[EncryptorType],[ProtectorName],[ProtectorExpiryDate],[ProtectorPrivateKeyLastBackupDate],
     [LatestFullBackupFinishDate],[LatestFullBackupExplicitlyEncrypted],[LatestFullBackupAlgorithm],[LatestFullBackupEncryptorType],[ColumnMasterKeyCount],
     [ColumnEncryptionKeyCount],[EncryptedColumnCount],[LedgerTableCount],[FindingCode],[FindingSeverity],
     [EvidenceLimit]
    FROM [#EncryptionAnalysis_Encryption]
    WHERE @NurProblematisch=0 OR [FindingSeverity] IN('HIGH','MEDIUM')
    ORDER BY CASE [FindingSeverity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[DatabaseId];

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,
           @ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @MetaJson nvarchar(max)=(SELECT N'EncryptionAnalysis' AS [resultName],1 AS [schemaVersion],
            @Now AS [generatedAtUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@Major AS [productMajorVersion]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
        DECLARE @DataJson nvarchar(max)=(SELECT * FROM [#EncryptionAnalysis_Export]
            ORDER BY CASE [FindingSeverity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[DatabaseId]
            FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @SourceJson nvarchar(max)=(SELECT * FROM [#EncryptionAnalysis_SourceStatus] ORDER BY [SourceName]
            FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @WarningJson nvarchar(max)=(SELECT * FROM [#EncryptionAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName]
            FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"databases":',COALESCE(@DataJson,N'[]'),
                         N',"sources":',COALESCE(@SourceJson,N'[]'),N',"warnings":',COALESCE(@WarningJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT N'USP_EncryptionAnalysis' AS [ModuleName],@Now AS [CollectionTimeUtc],@StatusCode AS [StatusCode],
               @IsPartial AS [IsPartial],@Major AS [ProductMajorVersion],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage];
        SELECT * FROM [#EncryptionAnalysis_Export]
        ORDER BY CASE [FindingSeverity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[DatabaseId];
        SELECT * FROM [#EncryptionAnalysis_SourceStatus] ORDER BY [SourceName];
        SELECT * FROM [#EncryptionAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
    END
    ELSE IF @OutputMode='CONSOLE'
    BEGIN
        SELECT N'Verschluesselungsanalyse' AS [Ergebnis],@Now AS [Stand_UTC],@StatusCode AS [Status],
               @IsPartial AS [Teilweise],@ErrorMessage AS [Hinweis];
        SELECT N'Verschluesselung' AS [Ergebnis],[DatabaseName] AS [Datenbank],
               [IsEncrypted] AS [TDE_Aktiv],[EncryptionStateDesc] AS [TDE_Status],
               [EncryptionScanStateDesc] AS [Scan_Status],[PercentComplete] AS [Fortschritt_Prozent],
               [ProtectorName] AS [Schutzobjekt],[ProtectorExpiryDate] AS [Ablaufdatum],
               [LatestFullBackupFinishDate] AS [Letztes_Full],
               [LatestFullBackupExplicitlyEncrypted] AS [Full_Explizit_Verschluesselt],
               [ColumnMasterKeyCount] AS [Column_Master_Keys],[ColumnEncryptionKeyCount] AS [Column_Encryption_Keys],
               [EncryptedColumnCount] AS [Verschluesselte_Spalten],[LedgerTableCount] AS [Ledger_Tabellen],
               [FindingCode] AS [Befund],[FindingSeverity] AS [Prioritaet],[EvidenceLimit] AS [Evidenzgrenze]
        FROM [#EncryptionAnalysis_Export]
        ORDER BY CASE [FindingSeverity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[DatabaseId];
        SELECT N'Quellenstatus' AS [Ergebnis],[SourceName] AS [Quelle],[StatusCode] AS [Status],[Detail] AS [Hinweis]
        FROM [#EncryptionAnalysis_SourceStatus] ORDER BY [SourceName];
        SELECT N'Datenbankwarnung' AS [Ergebnis],[RequestedName] AS [Datenbank],[StatusCode] AS [Status],[ErrorMessage] AS [Meldung]
        FROM [#EncryptionAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#EncryptionAnalysis_Export'
            , @ResultLabel=N'EncryptionAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#EncryptionAnalysis_Export'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
