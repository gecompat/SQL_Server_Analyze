USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_BackupRecovery
Version      : 2.1.0
Stand        : 2026-10-10
Typ          : Stored Procedure
Zweck        : Die Procedure bewertet Backup-Aktualität und Restore-Historie je ausgewählter
               sichtbarer Datenbank.
SQL-Version  : SQL Server 2019 oder neuer.
Filter       : @DatabaseNames als bracket-aware Pipe-Liste oder alternativ
               @DatabaseNamePattern mit LIKE/regex/regexi.
Resultsets   : RAW: Modulstatus, Datenbankstatus, Backup-Aktualität,
               Backup-Historie, Kompressionsevidenz und Restore-Historie.
               CONSOLE: Backup-Aktualität. TABLE: freshness und/oder compression.
               NONE: keine Resultsets.
JSON         : meta, freshness, backups, compression, restores, warnings.
Änderungen   : 2.1.0 - Getrennte Server-, Capability- und Backupset-
                         Kompressionsevidenz.
               2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_BackupRecovery]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @FullWarnHours                  int            = 48
    , @DiffWarnHours                  int            = 24
    , @LogWarnMinutes                 int            = 30
    , @MitRestoreHistory              bit            = 1
    , @MaxZeilen                      int            = 5000
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit            = 1
    , @Hilfe                          bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @FreshnessTableTarget sysname=NULL;
    DECLARE @CompressionTableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
    BEGIN
        CREATE TABLE [#BackupRecovery_ResultTableMap]
        (
              [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
            , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
        );
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'freshness|compression'
            , @MappingTable=N'#BackupRecovery_ResultTableMap'
            , @ThrowOnError=1;
        SELECT @FreshnessTableTarget=[TargetTable]
        FROM [#BackupRecovery_ResultTableMap] WHERE [ResultName]=N'freshness';
        SELECT @CompressionTableTarget=[TargetTable]
        FROM [#BackupRecovery_ResultTableMap] WHERE [ResultName]=N'compression';
    END;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_BackupRecovery';
        PRINT N'Die Hilfe beendet die fachliche Auswertung vor Kandidaten- und Backup-/Restoreabfragen; der TABLE-Preflight für lokale Zieltabellen läuft davor.';
        PRINT N'Der normale Pfad liest sichtbare, online zugängliche Datenbankmetadaten sowie msdb-Backup-, Medien- und optional Restorehistorie. Er führt keine Sicherung, Wiederherstellung oder Agentaktion aus.';
        PRINT N'Warnschwellen klassifizieren Freshness und schneiden die gelesene Historie nicht zeitlich ab. @MaxZeilen begrenzt die vorgesehenen Ergebnismengen separat; NULL oder 0 bedeutet unbegrenzt.';
        PRINT N'@HighImpactConfirmed aktiviert für diese Procedure keinen Analysepfad. Ein Status oder eine msdb-Historyzeile belegt weder Dateiexistenz noch erfolgreiche Wiederherstellbarkeit.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL sowie nach Trim leere Eingaben wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken, standardmäßig ohne Systemdatenbanken. Andernfalls wird eine Pipe-Liste einteiliger SQL-Datenbanknamen verarbeitet; äußere Leerzeichen je Element werden entfernt. Bracket-quotierte Elemente erlauben ein wörtliches Pipe-Zeichen und maskieren eine schließende Klammer als `]]`. Jedes Element muss ein gültiger höchstens 128 Zeichen langer SQL-Name sein; leere, doppelte, fehlerhaft geklammerte, mehrteilige oder ungültige Namen führen zu `INVALID_PARAMETER`. Eine explizite Liste kann nicht zusammen mit einem Pattern verwendet werden. Die Auswahl wird nicht vorab begrenzt; Namen, die nicht im zugänglichen Kandidatenscope liegen, liefern keine Kandidaten. Gültige explizite Namen außerhalb des zugänglichen Kandidatenscopes erzeugen Warnzeilen mit DATABASE_UNAVAILABLE beziehungsweise SYSTEM_DATABASE_EXCLUDED und führen zu AVAILABLE_LIMITED mit IsPartial=1; sie werden nicht stillschweigend ignoriert. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt die vier Systemdatenbanken anhand ihrer database_id aus; 1 nimmt zugängliche, online befindliche Systemdatenbanken in denselben Kandidatenpfad auf. NULL ist ungültig und führt über die Kandidatenvalidierung zu `INVALID_PARAMETER`. Diese Procedure übergibt `@AnalysisClass = NULL`; deshalb aktiviert dieser Schalter kein High-Impact-Analyse-Gate. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern; sonst werden äußere Leerzeichen entfernt und der Wert als Pattern ausgewertet. Zulässige Präfixe sind `LIKE:`, `REGEX:` und `REGEXI:` (Präfixerkennung ohne Beachtung der Groß-/Kleinschreibung); ohne Präfix gilt LIKE. `REGEX:` verlangt case-sensitive Regex, `REGEXI:` case-insensitive Regex; `LIKE:` entfernt nur das Präfix und verwendet SQL-LIKE-Musterzeichen. Der Inhalt nach dem Präfix darf nicht leer sein. Die maximale Eingabelänge beträgt 4000 UTF-16-Codeeinheiten. Ein Pattern ist mit einer exakten Namensliste unzulässig. Jedes nicht-NULL Pattern, das nach Trim beziehungsweise Präfixentfernung leer ist, sowie die Kombination mit einer exakten Liste setzen den Status `INVALID_PARAMETER`. Für `REGEX` und `REGEXI` benötigt die Installationsinstanz SQL Server 2025 und Compatibility Level 170; andernfalls meldet der Kandidatenhelfer `UNAVAILABLE_FEATURE`. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit=0; Default: 0. 0 und 1 sind Bestätigungswerte, NULL ist ungültig und wird als `INVALID_PARAMETER` behandelt. Für diese Procedure bleibt die Bestätigung ohne Freischaltwirkung: Der Kandidatenhelfer wird mit `@AnalysisClass = NULL` aufgerufen, sodass kein Analysepfad geprüft oder aktiviert wird. Der Wert ist keine Genehmigung für Backup-, Restore- oder sonstige Änderungen. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@FullWarnHours int=48; Default: 48. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für `FULL_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen und unterdrückt damit diese Schwellenklassifikation. Die Schwelle begrenzt keine gelesene msdb-Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @FullWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DiffWarnHours int=24; Default: 24. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für den informativen Status `DIFF_OLD_INFORMATIONAL`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen. Die Schwelle begrenzt keine gelesene Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @DiffWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LogWarnMinutes int=30; Default: 30. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Minutenschwelle für `LOG_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL passiert die `< 1`-Prüfung, lässt den Altersvergleich aber wegen SQL-NULL-Semantik nicht zutreffen. Der Vergleich verwendet `DATEDIFF(MINUTE, ..., GETDATE())`; die Schwelle begrenzt keine msdb-Historie und ist kein RPO. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitRestoreHistory bit=1; Default: 1. 0 lässt die Abfrage der msdb-Restorehistorie aus; 1 liest die Restorehistorie für ausgewählte Datenbanken. NULL verhält sich in `IF @MitRestoreHistory = 1` wie nicht aktiviert. Dieser Schalter betrifft nur Restoreausgabe und entfernt weder Backup- noch Freshnessauswertung. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte führen zu `INVALID_PARAMETER`; NULL oder 0 werden in eine unbegrenzte Obergrenze umgewandelt. Positive Werte begrenzen Freshness, Backup-, Kompressions-Backupset- und Restoreausgabe jeweils separat; die kleinen serverweiten Konfigurations- und Capability-Einträge bleiben sichtbar. Die Freshnessgrenze wird nach der Bewertung angewandt. Das Limit beschränkt nicht die zuvor geprüfte Backupsetmenge für Aggregation und Freshness und ist kein gemeinsames Gesamtlimit. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach `LTRIM`/`RTRIM` und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` zulässig; NULL und andere Texte führen zu `INVALID_PARAMETER`. `CONSOLE` liefert ausschließlich eine formatierte Freshnessausgabe ohne zusätzliches Modulstatus-Resultset; bei leerer Menge wird eine verständliche Hinweiszeile ausgegeben, `RAW` liefert die technischen Resultsets, `TABLE` schreibt ausschließlich die benannten lokalen Ziele, und `NONE` unterdrückt Resultsets. Für `CONSOLE` und `TABLE` wird der interne Resultsetpfad auf NONE gestellt, bevor die jeweilige Ausgabeadapterlogik läuft. Die Auswahl ist unabhängig von JSON-OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur bei `TABLE` darf dieser Wert nicht leer sein: Er muss ein JSON-Objekt mit Stringwerten für die case-sensitiven Schlüssel `freshness` und/oder `compression` enthalten; jeder Wert bezeichnet eine vorhandene lokale `#`-Temp-Tabelle. Ziele müssen leer sein und genau eine Seed-Spalte besitzen; doppelte/unbekannte Schlüssel, doppelte Ziele, globale oder reservierte `#Monitor`-Ziele, falsche Namen/Schemas oder ein ungültiges Mapping lösen den TABLE-Preflightfehler 51011 aus. Der Preflight prüft und verändert Ziele vorübergehend durch Hinzufügen und Entfernen einer Marker-Spalte. Bei allen anderen Ausgabearten ist NULL oder ein Leer-/Whitespacewert zulässig; ein nichtleeres Mapping löst 51011 aus. Das Mapping ändert keine fachlichen Backupdaten. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 1 erzeugt das JSON-Dokument und weist es `@Json` zu; 0 oder NULL lässt es bei der anfänglichen Rücksetzung auf NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, requestedMaxRows, errorNumber und errorMessage), `freshness`, `backups`, `compression`, `restores` und `warnings`. JSON-Erzeugung ist unabhängig von der gewählten Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON-Dokument. Die Procedure setzt ihn zu Beginn immer auf NULL; ein JSON-Text wird nur bei `@JsonErzeugen = 1` zugewiesen. Inhalt und Schlüssel stehen im Vertrag von `@JsonErzeugen`; bei HELP und bei deaktivierter JSON-Erzeugung bleibt der OUTPUT-Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. 1 erlaubt die vorgesehenen Informations-/Warnmeldungen über `RAISERROR` mit Severity 10; 0 unterdrückt diese Meldungen. NULL wird durch die Prüfung `IF @PrintMeldungen = 1` ebenfalls nicht aktiviert. Der Schalter unterdrückt weder Resultsets noch JSON und ändert keinen Status. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 1 gibt den Hilfetext mit `PRINT` aus und kehrt vor Kandidatensuche, Backup-/Restoreabfragen und Ausgabeverarbeitung zurück; 0 führt den normalen Ablauf aus. NULL wird nicht als aktiviert behandelt. Die TABLE-Zielvorprüfung liegt vor dieser Verzweigung: Bei `TABLE` kann deshalb bereits vorher Mapping validiert und eine Marker-Spalte temporär hinzugefügt/entfernt werden. HELP ist kein Backup-, Restore- oder Agent-Aufruf. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_BackupRecovery] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N''[ExampleDatabase]'', @MitRestoreHistory=0, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @BackupRecoveryJson nvarchar(max); EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N''[ExampleDatabase]'', @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@BackupRecoveryJson OUTPUT; SELECT @BackupRecoveryJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #BackupFreshness_HelpExample ([Seed] int NULL); CREATE TABLE #BackupCompression_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N''[ExampleDatabase]'', @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"freshness":"#BackupFreshness_HelpExample","compression":"#BackupCompression_HelpExample"}''; SELECT * FROM #BackupFreshness_HelpExample; SELECT * FROM #BackupCompression_HelpExample; DROP TABLE #BackupCompression_HelpExample; DROP TABLE #BackupFreshness_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupCompression_HelpExample; DROP TABLE #BackupFreshness_HelpExample; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_BackupRecovery] @DatabaseNamePattern=N''like:ExampleDatabase%'', @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 6: EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N''[ExampleDatabase]'', @FullWarnHours=48, @DiffWarnHours=24, @LogWarnMinutes=30, @MitRestoreHistory=1, @MaxZeilen=100, @ResultSetArt=''RAW'';';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;

    CREATE TABLE [#BackupRecovery_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
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

    CREATE TABLE [#BackupRecovery_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#BackupRecovery_Fresh]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [LastFullFinish] datetime
        , [FullAgeMinutes] int
        , [LastDiffFinish] datetime
        , [DiffAgeMinutes] int
        , [LastLogFinish] datetime
        , [LogAgeMinutes] int
        , [LastCopyOnlyFullFinish] datetime
        , [BackupStatus] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS
    );

    CREATE TABLE [#BackupRecovery_Backups]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [BackupType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [BackupTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [BackupStartDate] datetime
        , [BackupFinishDate] datetime
        , [DurationSeconds] int
        , [BackupSizeMb] decimal(19,2)
        , [CompressedSizeMb] decimal(19,2)
        , [IsCopyOnly] bit
        , [IsSnapshot] bit
        , [HasBackupChecksums] bit
        , [IsDamaged] bit
        , [MediaPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS
    );

    CREATE TABLE [#BackupRecovery_Restores]
    (
          [DestinationDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [RestoreDate] datetime
        , [UserName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [RestoreType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS
        , [Replace] bit
        , [Recovery] bit
        , [Restart] bit
        , [SourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
        , [BackupFinishDate] datetime
    );

    CREATE TABLE [#BackupRecovery_Compression]
    (
          [EvidenceScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BackupSetId] int NULL
        , [BackupFinishDate] datetime NULL
        , [ConfigurationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ConfiguredValue] int NULL
        , [AlgorithmName] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
    );

    IF @MaxZeilen < 0

       OR @FullWarnHours < 1
       OR @DiffWarnHours < 1
       OR @LogWarnMinutes < 1
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @IsPartial = 1;
        SET @ErrorMessage = N'Ungültige Grenzwert- oder Ausgabeparameter.';
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
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#BackupRecovery_DatabaseCandidates',@WarningTable=N'#BackupRecovery_DatabaseCandidateWarnings';
    END;

    IF @StatusCode <> 'AVAILABLE'
        SET @IsPartial = 1;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
    BEGIN TRY
        INSERT [#BackupRecovery_Compression]
        (
              [EvidenceScope], [ConfigurationName], [ConfiguredValue], [AlgorithmName]
            , [SourceStatus], [ErrorNumber], [ErrorMessage], [CollectionTimeUtc]
        )
        SELECT
              'SERVER_CONFIGURATION'
            , [c].[name]
            , CONVERT(int,[c].[value_in_use])
            , CASE WHEN [c].[name]=N'backup compression default'
                   THEN CASE WHEN [c].[value_in_use]=1 THEN N'ENABLED' ELSE N'DISABLED' END
                   WHEN [c].[value_in_use]=0 THEN N'USE_BACKUP_COMPRESSION_DEFAULT'
                   WHEN [c].[value_in_use]=1 THEN N'MS_XPRESS'
                   WHEN [c].[value_in_use]=2 THEN N'QAT'
                   WHEN [c].[value_in_use]=3 THEN N'ZSTD'
                   ELSE N'UNKNOWN' END
            , 'AVAILABLE', NULL, NULL, @CollectionTimeUtc
        FROM [sys].[configurations] AS [c] WITH (NOLOCK)
        WHERE [c].[name] IN (N'backup compression default',N'backup compression algorithm')
          AND ([c].[name]<>N'backup compression algorithm' OR CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=16);

        IF NOT EXISTS
           (SELECT 1 FROM [#BackupRecovery_Compression] WHERE [ConfigurationName]=N'backup compression default')
            INSERT [#BackupRecovery_Compression]
            VALUES ('SERVER_CONFIGURATION',NULL,NULL,NULL,N'backup compression default',NULL,NULL,'ERROR_HANDLED',NULL,N'Die Konfigurationszeile ist nicht sichtbar.',@CollectionTimeUtc);
    END TRY
    BEGIN CATCH
        INSERT [#BackupRecovery_Compression]
        VALUES ('SERVER_CONFIGURATION',NULL,NULL,NULL,NULL,NULL,NULL,
                CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                ERROR_NUMBER(),ERROR_MESSAGE(),@CollectionTimeUtc);
    END CATCH;

    IF CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) < 16
    BEGIN
        INSERT [#BackupRecovery_Compression]
        VALUES ('SERVER_CONFIGURATION',NULL,NULL,NULL,N'backup compression algorithm',NULL,NULL,'UNAVAILABLE_VERSION',NULL,N'Die Option ist ab SQL Server 2022 verfügbar.',@CollectionTimeUtc);
        INSERT [#BackupRecovery_Compression]
        VALUES ('BACKUP_HISTORY',NULL,NULL,NULL,N'backupset.compression_algorithm',NULL,NULL,'UNAVAILABLE_VERSION',NULL,N'Die Historienmetadatenspalte ist ab SQL Server 2022 verfügbar.',@CollectionTimeUtc);
    END;

    INSERT [#BackupRecovery_Compression]
    VALUES
    (
          'CAPABILITY',NULL,NULL,NULL,N'ZSTD_BACKUP_COMPRESSION',NULL,N'ZSTD'
        , CASE WHEN CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17 THEN 'AVAILABLE' ELSE 'UNAVAILABLE_VERSION' END
        , NULL
        , CASE WHEN CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=17
               THEN N'ZSTD ist ab SQL Server 2025 verfügbar.'
               ELSE N'ZSTD ist vor SQL Server 2025 nicht verfügbar.' END
        , @CollectionTimeUtc
    );

    IF CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) >= 16
    BEGIN TRY
        DECLARE @CompressionSql nvarchar(max) = N'
INSERT [#BackupRecovery_Compression]
(
      [EvidenceScope], [DatabaseName], [BackupSetId], [BackupFinishDate]
    , [ConfigurationName], [ConfiguredValue], [AlgorithmName], [SourceStatus]
    , [ErrorNumber], [ErrorMessage], [CollectionTimeUtc]
)
SELECT TOP (@EffectiveMaxZeilen)
      ''BACKUP_HISTORY'', [bs].[database_name], [bs].[backup_set_id], [bs].[backup_finish_date]
    , NULL, NULL, CASE [bs].[compression_algorithm]
                    WHEN N''MS_XPRESS'' THEN N''MS_XPRESS''
                    WHEN N''QAT_DEFLATE'' THEN N''QAT''
                    WHEN N''ZSTD'' THEN N''ZSTD''
                    ELSE N''UNKNOWN'' END, ''AVAILABLE''
    , NULL, NULL, @CollectionTimeUtc
FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
JOIN [#BackupRecovery_DatabaseCandidates] AS [c]
  ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
ORDER BY [bs].[backup_finish_date] DESC, [bs].[backup_set_id] DESC;';
        EXEC [sys].[sp_executesql]
              @CompressionSql
            , N'@EffectiveMaxZeilen bigint,@CollectionTimeUtc datetime2(3)'
            , @EffectiveMaxZeilen=@EffectiveMaxZeilen, @CollectionTimeUtc=@CollectionTimeUtc;
    END TRY
    BEGIN CATCH
        INSERT [#BackupRecovery_Compression]
        VALUES ('BACKUP_HISTORY',NULL,NULL,NULL,NULL,NULL,NULL,
                CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                     WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                ERROR_NUMBER(),ERROR_MESSAGE(),@CollectionTimeUtc);
    END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        ;WITH [LastBackups] AS
        (
            SELECT
                  [bs].[database_name]
                , MAX(CASE WHEN [bs].[type] = 'D' AND [bs].[is_copy_only] = 0 THEN [bs].[backup_finish_date] END) AS [FullFinish]
                , MAX(CASE WHEN [bs].[type] = 'I' THEN [bs].[backup_finish_date] END) AS [DiffFinish]
                , MAX(CASE WHEN [bs].[type] = 'L' THEN [bs].[backup_finish_date] END) AS [LogFinish]
                , MAX(CASE WHEN [bs].[type] = 'D' AND [bs].[is_copy_only] = 1 THEN [bs].[backup_finish_date] END) AS [CopyOnlyFinish]
            FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
            JOIN [#BackupRecovery_DatabaseCandidates] AS [c]
              ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
               = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            GROUP BY [bs].[database_name]
        )
        INSERT [#BackupRecovery_Fresh]
        SELECT
              [c].[DatabaseName]
            , [c].[StateDesc]
            , [c].[RecoveryModelDesc]
            , [x].[FullFinish]
            , DATEDIFF(MINUTE, [x].[FullFinish], GETDATE())
            , [x].[DiffFinish]
            , DATEDIFF(MINUTE, [x].[DiffFinish], GETDATE())
            , [x].[LogFinish]
            , DATEDIFF(MINUTE, [x].[LogFinish], GETDATE())
            , [x].[CopyOnlyFinish]
            , CASE
                  WHEN [c].[DatabaseId] = 2 THEN 'TEMPDB_NO_BACKUP'
                  WHEN [x].[FullFinish] IS NULL THEN 'NO_FULL_BACKUP'
                  WHEN DATEDIFF(HOUR, [x].[FullFinish], GETDATE()) > @FullWarnHours THEN 'FULL_TOO_OLD'
                  WHEN [c].[RecoveryModelDesc] IN (N'FULL', N'BULK_LOGGED') AND [x].[LogFinish] IS NULL THEN 'NO_LOG_BACKUP'
                  WHEN [c].[RecoveryModelDesc] IN (N'FULL', N'BULK_LOGGED')
                   AND DATEDIFF(MINUTE, [x].[LogFinish], GETDATE()) > @LogWarnMinutes THEN 'LOG_TOO_OLD'
                  WHEN [x].[DiffFinish] IS NOT NULL
                   AND DATEDIFF(HOUR, [x].[DiffFinish], GETDATE()) > @DiffWarnHours THEN 'DIFF_OLD_INFORMATIONAL'
                  ELSE 'OK'
              END
        FROM [#BackupRecovery_DatabaseCandidates] AS [c]
        LEFT JOIN [LastBackups] AS [x]
          ON [x].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
           = [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS;

        INSERT [#BackupRecovery_Backups]
        SELECT TOP (@EffectiveMaxZeilen)
              [bs].[database_name]
            , [bs].[type]
            , CASE [bs].[type] WHEN 'D' THEN N'DATABASE' WHEN 'I' THEN N'DIFFERENTIAL'
                   WHEN 'L' THEN N'LOG' WHEN 'F' THEN N'FILE_OR_FILEGROUP'
                   WHEN 'G' THEN N'DIFF_FILE' WHEN 'P' THEN N'PARTIAL'
                   WHEN 'Q' THEN N'DIFF_PARTIAL' END
            , [bs].[backup_start_date]
            , [bs].[backup_finish_date]
            , DATEDIFF(SECOND, [bs].[backup_start_date], [bs].[backup_finish_date])
            , CONVERT(decimal(19,2), [bs].[backup_size] / 1048576.0)
            , CONVERT(decimal(19,2), [bs].[compressed_backup_size] / 1048576.0)
            , [bs].[is_copy_only]
            , CAST(NULL AS bit)
            , [bs].[has_backup_checksums]
            , [bs].[is_damaged]
            , [bmf].[physical_device_name]
        FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
        JOIN [#BackupRecovery_DatabaseCandidates] AS [c]
          ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
           = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
        LEFT JOIN [msdb].[dbo].[backupmediafamily] AS [bmf] WITH (NOLOCK)
          ON [bmf].[media_set_id] = [bs].[media_set_id]
        ORDER BY [bs].[backup_finish_date] DESC, [bs].[backup_set_id] DESC;

        IF @MitRestoreHistory = 1
        BEGIN
            INSERT [#BackupRecovery_Restores]
            SELECT TOP (@EffectiveMaxZeilen)
                  [rh].[destination_database_name]
                , [rh].[restore_date]
                , [rh].[user_name]
                , [rh].[restore_type]
                , [rh].[replace]
                , [rh].[recovery]
                , [rh].[restart]
                , [bs].[database_name]
                , [bs].[backup_finish_date]
            FROM [msdb].[dbo].[restorehistory] AS [rh] WITH (NOLOCK)
            JOIN [#BackupRecovery_DatabaseCandidates] AS [c]
              ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
               = [rh].[destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            LEFT JOIN [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
              ON [bs].[backup_set_id] = [rh].[backup_set_id]
            ORDER BY [rh].[restore_date] DESC, [rh].[restore_history_id] DESC;
        END;

        IF EXISTS (SELECT 1 FROM [#BackupRecovery_DatabaseCandidateWarnings])
        BEGIN
            SET @StatusCode = 'AVAILABLE_LIMITED';
            SET @IsPartial = 1;
        END;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'ERROR_HANDLED'
            , @IsPartial = 1
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();

        IF @PrintMeldungen = 1
            RAISERROR(N'Backup-/Restore-Historie konnte nicht vollständig gelesen werden: %s', 10, 1, @ErrorMessage) WITH NOWAIT;
    END CATCH;

    ;WITH [RankedFreshness] AS
    (
        SELECT *,ROW_NUMBER() OVER
            (ORDER BY CASE WHEN [BackupStatus]='OK' THEN 1 ELSE 0 END,[DatabaseName]) AS [OutputOrdinal]
        FROM [#BackupRecovery_Fresh]
    )
    DELETE FROM [RankedFreshness] WHERE [OutputOrdinal]>@EffectiveMaxZeilen;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_BackupRecovery' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        SELECT
              [RequestedName], [StatusCode], [ErrorMessage]
        FROM [#BackupRecovery_DatabaseCandidateWarnings]
        ORDER BY [RequestedName];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT * FROM [#BackupRecovery_Fresh] ORDER BY CASE WHEN [BackupStatus] = 'OK' THEN 1 ELSE 0 END, [DatabaseName];
            SELECT * FROM [#BackupRecovery_Backups] ORDER BY [BackupFinishDate] DESC, [DatabaseName];
            SELECT * FROM [#BackupRecovery_Compression]
            ORDER BY [EvidenceScope], [BackupFinishDate] DESC, [BackupSetId] DESC;
            SELECT * FROM [#BackupRecovery_Restores] ORDER BY [RestoreDate] DESC, [DestinationDatabaseName];
        END;
        ELSE
        BEGIN
            SELECT
                  N'Backup-Aktualität' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [RecoveryModelDesc] AS [Recovery Model]
                , [BackupStatus] AS [Bewertung]
                , [LastFullFinish] AS [Letztes Full]
                , CASE WHEN [FullAgeMinutes] IS NULL THEN NULL ELSE CONCAT([FullAgeMinutes], N' min') END AS [Full-Alter]
                , [LastDiffFinish] AS [Letztes Diff]
                , CASE WHEN [DiffAgeMinutes] IS NULL THEN NULL ELSE CONCAT([DiffAgeMinutes], N' min') END AS [Diff-Alter]
                , [LastLogFinish] AS [Letztes Log]
                , CASE WHEN [LogAgeMinutes] IS NULL THEN NULL ELSE CONCAT([LogAgeMinutes], N' min') END AS [Log-Alter]
            FROM [#BackupRecovery_Fresh]
            ORDER BY CASE WHEN [BackupStatus] = 'OK' THEN 1 ELSE 0 END, [DatabaseName];

            SELECT N'Backup-Historie' AS [Ergebnis], [x].* FROM [#BackupRecovery_Backups] AS [x] ORDER BY [BackupFinishDate] DESC, [DatabaseName];
            SELECT N'Restore-Historie' AS [Ergebnis], [x].* FROM [#BackupRecovery_Restores] AS [x] ORDER BY [RestoreDate] DESC, [DestinationDatabaseName];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'BackupRecovery' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @FreshJson nvarchar(max) =
            (SELECT * FROM [#BackupRecovery_Fresh] ORDER BY CASE WHEN [BackupStatus] = 'OK' THEN 1 ELSE 0 END, [DatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @BackupsJson nvarchar(max) =
            (SELECT * FROM [#BackupRecovery_Backups] ORDER BY [BackupFinishDate] DESC, [DatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @RestoresJson nvarchar(max) =
            (SELECT * FROM [#BackupRecovery_Restores] ORDER BY [RestoreDate] DESC, [DestinationDatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @CompressionJson nvarchar(max) =
            (SELECT * FROM [#BackupRecovery_Compression]
             ORDER BY [EvidenceScope], [BackupFinishDate] DESC, [BackupSetId] DESC
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#BackupRecovery_DatabaseCandidateWarnings] ORDER BY [RequestedName] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"freshness":', COALESCE(@FreshJson, N'[]')
            , N',"backups":', COALESCE(@BackupsJson, N'[]')
            , N',"compression":', COALESCE(@CompressionJson, N'[]')
            , N',"restores":', COALESCE(@RestoresJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#BackupRecovery_Fresh'
            , @ResultLabel=N'BackupRecovery'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        IF @FreshnessTableTarget IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable = N'#BackupRecovery_Fresh'
                , @TargetTable=@FreshnessTableTarget
                , @ThrowOnError = 1;
        IF @CompressionTableTarget IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable = N'#BackupRecovery_Compression'
                , @TargetTable=@CompressionTableTarget
                , @ThrowOnError = 1;
    END;
END;
GO
