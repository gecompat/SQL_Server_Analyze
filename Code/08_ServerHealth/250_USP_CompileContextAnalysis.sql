USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CompileContextAnalysis
Version      : 1.0.0
Stand        : 2026-10-13
Zweck        : Die Procedure trennt lokale OPTIMIZED_SP_EXECUTESQL-Konfiguration von
               serverweiten Compile-Countern, Compile-Waits und Cachemetadaten.
Quellen      : Sichtbare Datenbankkataloge; Performance-Counter, Waitstatistik,
               Serverstartzeit und zwei Memory-Cache-Klassen.
Eigenlast    : Kleine Katalogabfragen; Sampling ist standardmäßig aus und
               verwendet optional genau ein WAITFOR von einer bis 60 Sekunden.
Grenzen      : Keine Queryzuordnung, Ursachenbehauptung, SQL- oder Planinhalte.
               Zwei Aufnahmen erkennen nicht jeden zwischenzeitlichen Reset.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CompileContextAnalysis]
      @DatabaseNames nvarchar(max)=NULL
    , @SystemdatenbankenEinbeziehen bit=0
    , @DatabaseNamePattern nvarchar(4000)=NULL
    , @SampleSeconds tinyint=0
    , @MaxZeilen int=2000
    , @ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson nvarchar(max)=NULL
    , @JsonErzeugen bit=0
    , @Json nvarchar(max)=NULL OUTPUT
    , @PrintMeldungen bit=1
    , @Hilfe bit=0
    , @StatusCodeOut varchar(40)=NULL OUTPUT
    , @IsPartialOut bit=NULL OUTPUT
    , @ErrorNumberOut int=NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Status varchar(40)='AVAILABLE',@Partial bit=0,@Error int=NULL,@Message nvarchar(2048)=NULL,
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),@PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @RestoreLock nvarchar(100),@CrossDatabaseRequested bit=0,@PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CompileContextAnalysis';
        PRINT N'Die Procedure erfasst sichtbare OPTIMIZED_SP_EXECUTESQL-Konfigurationen je ausgewählter Datenbank und getrennte serverweite Compile-Counter, den Compile-Wait und zwei aggregierte Cacheklassen.';
        PRINT N'Die optionale Probe verwendet zwei Aufnahmen und ein gemeinsames WAITFOR; die Datenbankauswahl ordnet serverweite Werte keiner Datenbank zu.';
        PRINT N'Die Ausgabe enthält Rohwerte, Quellenstatus und Evidenzgrenzen. Sie ordnet keine Query oder Compile-Ursache zu und ändert keine Serverkonfiguration.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, N'''' und eine nach außen getrimmte leere Zeichenfolge bedeuten keine Einschränkung; andernfalls ist eine eindeutige Pipe-Liste exakter SQL-Datenbanknamen zulässig. Es gilt die bracket-aware Namenslistenprüfung des Datenbankauswahlhelfers: äußere Segmentleerzeichen werden entfernt, Namen mit Leerzeichen oder Pipe können bracket-quotiert werden, und ]] maskiert darin eine schließende Klammer. Ungültige Elemente, doppelte gültige Namen sowie eine gleichzeitige nichtleere Namensliste und ein gesetztes Pattern führen zu INVALID_PARAMETER. Die Procedure fordert für die Auswahlklasse STANDARD_CURRENT an; der gebundene Klassenvertrag setzt dafür kein High-Impact-Gruppengate. Die Auswahl umfasst sichtbare, zugreifbare, online befindliche Datenbanken ohne Datenbank-Snapshots; fehlende oder nicht auswählbare explizite Namen werden als DATABASE_SELECTION-Warnings gemeldet. Ohne Einschränkung gibt es keinen CURRENT-Scope und kein Vorab- oder Datenbankanzahllimit.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbanken mit database_id 1 bis 4 aus; 1 lässt master, tempdb, model und msdb in die Auswahl zu. NULL wird als ungültiger Parameter behandelt. Der Schalter gewährt selbst keine Berechtigung und macht nicht zugreifbare Datenbanken nicht sichtbar. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern. Ein gesetztes Pattern wird nach dem gemeinsamen Parservertrag außen getrimmt; die Präfixe like:, regex: und regexi: wählen LIKE, case-sensitive Regex beziehungsweise case-insensitive Regex, ohne Beachtung der Präfixgroßschreibung. Ohne Präfix gilt LIKE. Nach dem Präfix darf der Inhalt nicht leer sein; ein ungültiges/leeres Pattern und die gleichzeitige Verwendung mit einer nichtleeren exakten Namensliste führen zu INVALID_PARAMETER. LIKE wird case-sensitive ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank; andernfalls meldet der Auswahlhelfer UNAVAILABLE_FEATURE. Der Regextext wird nicht vorab syntaktisch geprüft. NULL ist damit von leerem Text und einem leeren Präfix zu unterscheiden. Eine fehlerhafte Regex kann im Auswahlhelfer beim Ausführen scheitern; der umgebende CATCH dokumentiert eine partielle DATABASE_SELECTION-Quelle, während unabhängige Serverquellen weiterlaufen können.';
        PRINT N'@SampleSeconds tinyint; Default: 0. 0 liest Counter und Waits jeweils einmal als Momentaufnahme; Before-, Delta-, Rate- und Intervallwerte sind dabei NULL. 1 bis 60 führt zwei Aufnahmen aus und genau ein gemeinsames WAITFOR mit der angegebenen Anzahl Sekunden dazwischen aus. Counter und Waits erhalten getrennte, unmittelbar nach ihrer jeweiligen Aufnahme gebundene UTC-Intervalle; die tatsächliche Dauer kann von der angeforderten Wartezeit abweichen. NULL oder ein Wert über 60 ist INVALID_PARAMETER; ein negativer Wert kann im tinyint-Eingabetyp nicht dargestellt werden. Sampling bleibt serverweit und wird nicht den ausgewählten Datenbanken zugeordnet.';
        PRINT N'@MaxZeilen int; Default: 2000. 0 und NULL bedeuten keine Zeilenbegrenzung. Jeder positive int-Wert von 1 bis 2.147.483.647 begrenzt jeweils configurations, counters, waits, cache, sourceStatus und warnings nach deren Erhebung; moduleStatus bleibt eine einzelne Zeile. Die jeweiligen Gruppen werden nach ihren festen Schlüsseln sortiert und unabhängig gekürzt. Die Begrenzung reduziert weder die gelesenen Datenquellen noch die Zahl ausgewählter Datenbanken; die gemeldete RowCount zählt die materialisierten Zeilen aus configurations, counters, waits und cache vor der nachfolgenden Kürzung und nicht die ausgegebenen Zeilen. Negative Werte führen zu INVALID_PARAMETER.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Der Wert wird außen getrimmt und ohne Beachtung der Großschreibung normalisiert. Zulässig sind genau RAW (sieben fachliche Resultsets in der Reihenfolge moduleStatus, configurations, counters, waits, cache, sourceStatus, warnings), TABLE (nur die per JSON-Mapping ausgewählten Resultgruppen in lokale Temp-Tabellen schreiben), CONSOLE (eine formatierte Übersicht aus Konfigurationen, Counter-Rohwerten, Waitzeit und Cacheeinträgen sowie einer Modulstatuszeile mit Status und RowCount) und NONE (keine fachlichen Resultsets). NULL oder ein anderer Wert wird zu einem leeren beziehungsweise nicht erlaubten Modus und führt zu INVALID_PARAMETER. JSON-Erzeugung und Meldungsausgabe werden unabhängig davon gesteuert.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur mit TABLE wird die JSON-Zuordnung verarbeitet; bei einem anderen Modus führt ein nichtleerer, außen getrimmter Wert zu einer ausgelösten Ausnahme. Für TABLE ist ein gültiges, nichtleeres JSON-Objekt mit mindestens einer Zuordnung erforderlich. Erlaubte, exakt groß-/kleinschreibungsabhängige Schlüssel sind moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings; jeder Wert benennt eine vorhandene, leere lokale #Temp-Tabelle. Die Zielnamen müssen höchstens 116 Zeichen lang sein, dürfen nicht mit ## beginnen und nicht dem reservierten Präfix #Monitor entsprechen. Doppelte Schlüssel oder Ziele, unbekannte Schlüssel, NULL-/Nicht-String-Werte, fehlende oder gefüllte Ziele sowie Ziele mit mehr als einer Seed-Spalte werden vor den fachlichen Quellenzugriffen abgelehnt. Der spätere Writer ersetzt die Seed-Spalte durch das fachliche Ergebnisschema. NULL, leerer oder nur aus U+0020-Leerzeichen bestehender Wert genügt bei TABLE nicht und löst INVALID_RESULT_TABLE_MAPPING aus. moduleStatus bedeutet Modulstatus, configurations Konfigurationen, counters Counterwerte, waits Waitwerte, cache Cacheaggregate, sourceStatus Quellenstatus und warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von der ResultSetArt ein JSON-Dokument im OUTPUT-Parameter, einschließlich Metadaten und der sieben Gruppen moduleStatus, configurations, counters, waits, cache, sourceStatus und warnings. 0 erzeugt es nicht; dann bleibt @Json NULL. NULL ist INVALID_PARAMETER. Schema 1 enthält eine einzelne meta-Struktur mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage; Gruppen sind Arrays, leere Gruppen werden als [] ausgegeben und NULL-Spalten bleiben enthalten. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Zum Empfang ist eine passend typisierte lokale Variable mit OUTPUT-Bindung zu übergeben. Der Wert wird zu Beginn des Aufrufs vor dem HELP-Zweig auf NULL gesetzt. Bei aktivierter JSON-Erzeugung enthält er das Schema-1-Dokument; bei deaktivierter Erzeugung und auch bei HELP bleibt er NULL. Die Initialisierung findet vor möglichen Ausnahmen statt. Der Empfänger kann ausgelassen werden, wenn kein JSON empfangen werden soll.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 lässt bei einem nicht AVAILABLE-Gesamtstatus eine Statusmeldung mit Schweregrad 10 und WITH NOWAIT ausgeben; 0 unterdrückt diese Meldung. NULL ist INVALID_PARAMETER. Der Schalter unterdrückt weder CONSOLE-Ausgaben noch fachliche Resultsets oder die OUTPUT-Bindungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 druckt die eingebauten Hilfetexte, setzt die vier Status-/Fehler-OUTPUTs auf AVAILABLE, 0, NULL und NULL und kehrt vor Validierung, Kandidatenauswahl und Quellenzugriff zurück. @Json wurde bereits vorher auf NULL gesetzt. 0 führt den normalen Ablauf aus; NULL wird durch die IF-Prüfung wie 0 behandelt und ist kein eigener Validierungsfehler. SQL-Konvertierung nach bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Bei HELP wird AVAILABLE zugewiesen. Nach normaler Verarbeitung sind die Gesamtwerte: AVAILABLE ohne markierte Partialität, AVAILABLE_LIMITED bei tatsächlich partieller Evidenz, INVALID_PARAMETER bei ungültigen geprüften Modus-, Mengen-, Sample-, Bit- oder Auswahlparametern, INTERNAL_ERROR bei internem Kandidatenschemafehler, UNAVAILABLE_FEATURE bei fehlenden Regex-Voraussetzungen. Eine abgefangene Auswahl-Ausnahme wird als partielle DATABASE_SELECTION-Quelle erfasst; unabhängige Serverquellen können danach weiterlaufen. Nicht abgefangene Mapping-/Ausgabefehler umgehen den normalen Abschlusssatz. Die Bindung ist optional: zum Empfangen eine varchar(40)-Variable mit OUTPUT übergeben; andernfalls auslassen. HELP überschreibt einen anfänglichen NULL- oder anderen Empfängerwert mit AVAILABLE.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. HELP setzt sie auf 0. Im normalen Abschluss ist 1 gesetzt, wenn eine Quelle oder explizite Datenbankauswahl-Warnung partiell ist oder ein Counter-/Wait-Sample nicht vergleichbar ist; dann wird ein zuvor AVAILABLE-Status zu AVAILABLE_LIMITED. 0 bedeutet nur, dass diese Implementierungsbedingungen keine Partialität markiert haben, nicht dass zwischenzeitliche Resets ausgeschlossen sind. Bei ungültigen geprüften Eingaben wird 1 gesetzt. Bei nicht abgefangenen Ausnahmen wird der normale Abschluss nicht erreicht. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die erste tatsächlich gespeicherte Fehlernummer in der Quellenreihenfolge und innerhalb einer Quelle in Beobachtungsreihenfolge: Konfiguration/Datenbankauswahl, Serverstartzeit oder Counter, Waits, danach Cache. Fehlende Zeilen und Versionsfallbacks ohne ausgelöste SQL-Ausnahme liefern für sich keine Fehlernummer; ein vom Auswahlhelfer zurückgegebener Status kann dennoch eine Fehlermeldung ohne Fehlernummer hinterlassen. Bei keinem gespeicherten Fehler ist der Wert NULL; nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. HELP setzt sie auf NULL. Im normalen Abschluss enthält sie die zur ersten gespeicherten ErrorNumber gehörende SQL-Fehlermeldung in derselben Quellenreihenfolge; wenn weder eine gespeicherte SQL-Ausnahme noch eine Fehlermeldung des Auswahlhelfers vorliegt, ist der Wert NULL. Hinweise zu fehlenden Zeilen, Versionsfallbacks oder sonstigen Quellenlimits stehen in sourceStatus und warnings. Nicht abgefangene Ausnahmen umgehen den normalen Abschluss. Die Bindung ist optional: Zum Empfang eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls das Argument auslassen. Der Hilfezweig überschreibt auch anfängliche NULL- oder andere Empfängerwerte mit den beschriebenen festen Rückgaben.';
        PRINT N'EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#CompileContextAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"configurations":"#CompileContextAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_CompileContextAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#CompileContextAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CompileContextAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_CompileContextAnalysis] @Hilfe=1;';




        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
        RETURN;
    END;
    CREATE TABLE [#CompileContextAnalysis_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [RowCount] bigint NOT NULL,
        [RequiredPermission] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_configurations]
    (
        [DatabaseId] int NOT NULL,
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CompatibilityLevel] tinyint NULL,
        [ConfigurationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapabilityStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Enabled] bit NULL,
        [ValueForSecondary] int NULL,
        [IsValueDefault] bit NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_counters]
    (
        [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CounterType] int NOT NULL,
        [BeforeValue] bigint NULL,
        [AfterValue] bigint NOT NULL,
        [DeltaValue] bigint NULL,
        [RatePerSecond] decimal(38,6) NULL,
        [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SampleStartUtc] datetime2(7) NULL,
        [SampleEndUtc] datetime2(7) NOT NULL,
        [ElapsedSeconds] decimal(19,6) NULL,
        [ResetDetected] bit NOT NULL,
        [SqlServerStartTime] datetime2(3) NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_waits]
    (
        [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [BeforeWaitingTasksCount] bigint NULL,
        [AfterWaitingTasksCount] bigint NOT NULL,
        [DeltaWaitingTasksCount] bigint NULL,
        [BeforeWaitTimeMs] bigint NULL,
        [AfterWaitTimeMs] bigint NOT NULL,
        [DeltaWaitTimeMs] bigint NULL,
        [BeforeSignalWaitTimeMs] bigint NULL,
        [AfterSignalWaitTimeMs] bigint NOT NULL,
        [DeltaSignalWaitTimeMs] bigint NULL,
        [SampleStartUtc] datetime2(7) NULL,
        [SampleEndUtc] datetime2(7) NOT NULL,
        [ElapsedSeconds] decimal(19,6) NULL,
        [ResetDetected] bit NOT NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_cache]
    (
        [CacheType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EntriesCount] bigint NULL,
        [PagesKb] bigint NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_sourceStatus]
    (
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [DatabaseId] int NULL,
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [RowCount] bigint NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_warnings]
    (
        [WarningCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [DatabaseId] int NULL,
        [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CompileContextAnalysis_Map]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE);
    CREATE TABLE [#CompileContextAnalysis_Databases]
    ([DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL);
    CREATE TABLE [#CompileContextAnalysis_CandidateWarnings]
    ([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    SELECT TOP(0) *,CONVERT(int,0) [SourceRank],IDENTITY(int,1,1) [ObservationOrdinal] INTO [#CompileContextAnalysis_Observations] FROM [#CompileContextAnalysis_sourceStatus];
    CREATE TABLE [#CompileContextAnalysis_CounterRaw]
    ([Phase] tinyint NOT NULL,[ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
     [CounterType] int NOT NULL,[CounterValue] bigint NOT NULL,PRIMARY KEY([Phase],[ObjectName],[CounterName],[InstanceName],[CounterType]));
    CREATE TABLE [#CompileContextAnalysis_WaitRaw]
    ([Phase] tinyint NOT NULL,[WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WaitingTasksCount] bigint NOT NULL,[WaitTimeMs] bigint NOT NULL,[SignalWaitTimeMs] bigint NOT NULL,PRIMARY KEY([Phase],[WaitType]));
    DECLARE @ConfigLimit nvarchar(1000)=N'Lokale aktuelle Konfiguration; kein Compileursachen- oder Gesundheitsurteil.',
        @CounterLimit nvarchar(1000)=N'Serverweite kumulative Counter einschließlich Eigenaktivität. Eigene Quellenklammer; keine Datenbank- oder Queryzuordnung.',
        @WaitLimit nvarchar(1000)=N'Serverweite kumulative Compile-Waits. Ein Reset mit anschließendem Anwachsen kann zwischen zwei Aufnahmen unentdeckt bleiben.',
        @CacheLimit nvarchar(1000)=N'Aggregierte Memory-Cache-Metadaten; Einträge sind weder ausgeführte Queries noch Single-use-Pläne.',
        @CounterStart datetime2(7)=NULL,@CounterEnd datetime2(7)=NULL,@WaitStart datetime2(7)=NULL,@WaitEnd datetime2(7)=NULL,
        @ServerStartBefore datetime2(3)=NULL,@ServerStartAfter datetime2(3)=NULL,@CounterElapsed decimal(19,6)=NULL,@WaitElapsed decimal(19,6)=NULL,
        @ServerComparable bit=0,@ServerReset bit=0,@Phase tinyint=CASE WHEN @SampleSeconds>0 THEN 0 ELSE 1 END,
        @SourceKey varchar(64),@SourceObject nvarchar(256),@SourceStatus varchar(40),@SourceError int,@SourceMessage nvarchar(2048),@SourceRows bigint,@SourceTime datetime2(3);
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @Mode NOT IN('RAW','TABLE','CONSOLE','NONE') OR @SampleSeconds IS NULL OR @SampleSeconds>60 OR @MaxZeilen<0
            OR @SystemdatenbankenEinbeziehen IS NULL OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
            SELECT @Status='INVALID_PARAMETER',@Partial=1,@Message=N'Ungültiger Ausgabe-, Mengen-, Sample- oder Bitparameter.';
        IF @Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL
            THROW 51011,N'@ResultTablesJson ist ausschließlich mit TABLE zulässig.',1;
        IF @Status='AVAILABLE' AND @Mode='TABLE'
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|configurations|counters|waits|cache|sourceStatus|warnings',
                @MappingTable=N'#CompileContextAnalysis_Map',@StatusCode=@Status OUTPUT,@ErrorMessage=@Message OUTPUT,@ThrowOnError=1;
        IF @Status='AVAILABLE'
        BEGIN TRY
            EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,
                @DatabaseNamePattern=@DatabaseNamePattern,@AnalysisClass='STANDARD_CURRENT',@StatusCode=@Status OUTPUT,@ErrorMessage=@Message OUTPUT,
                @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#CompileContextAnalysis_Databases',@WarningTable=N'#CompileContextAnalysis_CandidateWarnings';
        END TRY
        BEGIN CATCH
            DELETE FROM [#CompileContextAnalysis_Databases];
            INSERT [#CompileContextAnalysis_Observations] VALUES('DATABASE_SELECTION',NULL,NULL,N'master.sys.databases',SYSUTCDATETIME(),
                CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,ERROR_NUMBER(),ERROR_MESSAGE(),N'Die Datenbankauswahl ist nicht verfügbar; serverweite Quellen bleiben unabhängig.',1);
            SELECT @Status='AVAILABLE',@Partial=1;
        END CATCH;
        SET LOCK_TIMEOUT 0;
        IF @Status='AVAILABLE'
        BEGIN
            DECLARE @DatabaseId int,@DatabaseName sysname,@CompatibilityLevel tinyint,@Found bit,@Value int,@Secondary int,@Default bit,@Capability varchar(40),@Sql nvarchar(max);
            DECLARE [CompileContextDatabases] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName],[CompatibilityLevel] FROM [#CompileContextAnalysis_Databases] ORDER BY [DatabaseName],[DatabaseId];
            OPEN [CompileContextDatabases]; FETCH NEXT FROM [CompileContextDatabases] INTO @DatabaseId,@DatabaseName,@CompatibilityLevel;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SELECT @Found=0,@Value=NULL,@Secondary=NULL,@Default=NULL,@SourceError=NULL,@SourceMessage=NULL,@SourceTime=SYSUTCDATETIME(),
                    @Capability=CASE WHEN @Major<17 THEN 'UNAVAILABLE_VERSION' ELSE 'SOURCE_UNAVAILABLE' END,@SourceStatus=CASE WHEN @Major<17 THEN 'UNAVAILABLE_VERSION' ELSE 'SOURCE_UNAVAILABLE' END;
                IF @Major>=17
                BEGIN TRY
                    SET @Sql=N'SELECT @Found=1,@Value=TRY_CONVERT(int,[value]),@Secondary=TRY_CONVERT(int,[value_for_secondary]),@Default=[is_value_default] FROM '+QUOTENAME(@DatabaseName)+N'.[sys].[database_scoped_configurations] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''OPTIMIZED_SP_EXECUTESQL'';';
                    EXEC [sys].[sp_executesql] @Sql,N'@Found bit OUTPUT,@Value int OUTPUT,@Secondary int OUTPUT,@Default bit OUTPUT',@Found=@Found OUTPUT,@Value=@Value OUTPUT,@Secondary=@Secondary OUTPUT,@Default=@Default OUTPUT;
                    IF @Found=1 SET @Capability='AVAILABLE';
                    IF @Found=1 AND @Value IN(0,1) SET @SourceStatus='AVAILABLE';
                END TRY
                BEGIN CATCH
                    SELECT @SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE(),@SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END;
                END CATCH;
                INSERT [#CompileContextAnalysis_configurations] VALUES(@DatabaseId,@DatabaseName,@CompatibilityLevel,N'OPTIMIZED_SP_EXECUTESQL',@Capability,
                    CASE WHEN @SourceStatus='AVAILABLE' THEN CONVERT(bit,@Value) END,CASE WHEN @SourceStatus='AVAILABLE' THEN @Secondary END,CASE WHEN @SourceStatus='AVAILABLE' THEN @Default END,@SourceStatus,@SourceTime,@ConfigLimit);
                INSERT [#CompileContextAnalysis_Observations] VALUES('CONFIGURATION',@DatabaseId,@DatabaseName,N'sys.database_scoped_configurations',@SourceTime,@SourceStatus,
                    CONVERT(bit,CASE WHEN @SourceStatus IN('AVAILABLE','UNAVAILABLE_VERSION') THEN 0 ELSE 1 END),CONVERT(bigint,CASE WHEN @SourceError IS NULL THEN @Found ELSE 0 END),@SourceError,@SourceMessage,@ConfigLimit,1);
                FETCH NEXT FROM [CompileContextDatabases] INTO @DatabaseId,@DatabaseName,@CompatibilityLevel;
            END;
            CLOSE [CompileContextDatabases]; DEALLOCATE [CompileContextDatabases];
            WHILE @Phase<=1
            BEGIN
                SELECT @SourceKey=CASE WHEN @Phase=0 THEN 'SERVER_START_BEFORE' ELSE 'SERVER_START_AFTER' END,@SourceStatus='AVAILABLE',@SourceError=NULL,@SourceMessage=NULL,@SourceRows=0,@SourceTime=SYSUTCDATETIME();
                BEGIN TRY
                    IF @Phase=0 SELECT @ServerStartBefore=[sqlserver_start_time] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
                    ELSE SELECT @ServerStartAfter=[sqlserver_start_time] FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
                    SET @SourceRows=@@ROWCOUNT;
                    IF @SourceRows<>1 OR (@Phase=0 AND @ServerStartBefore IS NULL) OR (@Phase=1 AND @ServerStartAfter IS NULL) SET @SourceStatus='SOURCE_UNAVAILABLE';
                END TRY
                BEGIN CATCH
                    SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,@SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE();
                END CATCH;
                INSERT [#CompileContextAnalysis_Observations] VALUES(@SourceKey,NULL,NULL,N'sys.dm_os_sys_info',@SourceTime,@SourceStatus,CONVERT(bit,CASE WHEN @SourceStatus='AVAILABLE' THEN 0 ELSE 1 END),@SourceRows,@SourceError,@SourceMessage,N'Native Serverstartzeit bindet ausschließlich die Vergleichbarkeit der getrennten Samples.',2);
                SELECT @SourceKey=CASE WHEN @Phase=0 THEN 'COUNTERS_BEFORE' ELSE 'COUNTERS_AFTER' END,@SourceStatus='AVAILABLE',@SourceError=NULL,@SourceMessage=NULL,@SourceRows=0;
                BEGIN TRY
                    INSERT [#CompileContextAnalysis_CounterRaw]
                    SELECT @Phase,[object_name],[counter_name],[instance_name],[cntr_type],[cntr_value] FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                    WHERE RTRIM([object_name]) COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'%:SQL Statistics'
                      AND [counter_name] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'Batch Requests/sec',N'SQL Compilations/sec',N'SQL Re-Compilations/sec');
                    SET @SourceRows=@@ROWCOUNT;
                    IF @SourceRows<>3 SET @SourceStatus='SOURCE_UNAVAILABLE';
                END TRY
                BEGIN CATCH
                    DELETE FROM [#CompileContextAnalysis_CounterRaw] WHERE [Phase]=@Phase;
                    SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,@SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE();
                END CATCH;
                IF @Phase=0 SET @CounterStart=SYSUTCDATETIME(); ELSE SET @CounterEnd=SYSUTCDATETIME();
                INSERT [#CompileContextAnalysis_Observations] VALUES(@SourceKey,NULL,NULL,N'sys.dm_os_performance_counters',COALESCE(@CounterEnd,@CounterStart),@SourceStatus,CONVERT(bit,CASE WHEN @SourceStatus='AVAILABLE' THEN 0 ELSE 1 END),@SourceRows,@SourceError,@SourceMessage,@CounterLimit,2);
                SELECT @SourceKey=CASE WHEN @Phase=0 THEN 'WAITS_BEFORE' ELSE 'WAITS_AFTER' END,@SourceStatus='AVAILABLE',@SourceError=NULL,@SourceMessage=NULL,@SourceRows=0;
                BEGIN TRY
                    INSERT [#CompileContextAnalysis_WaitRaw] SELECT @Phase,[wait_type],[waiting_tasks_count],[wait_time_ms],[signal_wait_time_ms] FROM [sys].[dm_os_wait_stats] WITH (NOLOCK) WHERE [wait_type] COLLATE SQL_Latin1_General_CP1_CS_AS=N'RESOURCE_SEMAPHORE_QUERY_COMPILE';
                    SET @SourceRows=@@ROWCOUNT;
                    IF @SourceRows<>1 SET @SourceStatus='SOURCE_UNAVAILABLE';
                END TRY
                BEGIN CATCH
                    DELETE FROM [#CompileContextAnalysis_WaitRaw] WHERE [Phase]=@Phase;
                    SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,@SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE();
                END CATCH;
                IF @Phase=0 SET @WaitStart=SYSUTCDATETIME(); ELSE SET @WaitEnd=SYSUTCDATETIME();
                INSERT [#CompileContextAnalysis_Observations] VALUES(@SourceKey,NULL,NULL,N'sys.dm_os_wait_stats',COALESCE(@WaitEnd,@WaitStart),@SourceStatus,CONVERT(bit,CASE WHEN @SourceStatus='AVAILABLE' THEN 0 ELSE 1 END),@SourceRows,@SourceError,@SourceMessage,@WaitLimit,3);
                IF @Phase=0
                BEGIN
                    DECLARE @Delay char(8)=CONVERT(char(8),DATEADD(second,@SampleSeconds,CONVERT(datetime2(0),'19000101')),108);
                    WAITFOR DELAY @Delay;
                END;
                SET @Phase+=1;
            END;
            SET @ServerComparable=CASE WHEN @SampleSeconds>0 AND @ServerStartBefore IS NOT NULL AND @ServerStartAfter=@ServerStartBefore THEN 1 ELSE 0 END;
            SET @ServerReset=CASE WHEN @SampleSeconds>0 AND @ServerStartBefore IS NOT NULL AND @ServerStartAfter IS NOT NULL AND @ServerStartAfter<>@ServerStartBefore THEN 1 ELSE 0 END;
            IF @SampleSeconds>0
            BEGIN
                SET @CounterElapsed=CONVERT(decimal(19,6),DATEDIFF_BIG(microsecond,@CounterStart,@CounterEnd)/1000000.0);
                SET @WaitElapsed=CONVERT(decimal(19,6),DATEDIFF_BIG(microsecond,@WaitStart,@WaitEnd)/1000000.0);
            END;
            INSERT [#CompileContextAnalysis_counters]
            SELECT [a].[ObjectName],[a].[CounterName],[a].[InstanceName],[a].[CounterType],[b].[CounterValue],[a].[CounterValue],
                CASE WHEN [v].[Comparable]=1 THEN TRY_CONVERT(bigint,CONVERT(decimal(38,0),[a].[CounterValue])-CONVERT(decimal(38,0),[b].[CounterValue])) END,
                CASE WHEN [v].[Comparable]=1 AND [a].[CounterType] IN(272696320,272696576) THEN [typed].[MetricValue] END,[typed].[Interpretation],
                @CounterStart,@CounterEnd,@CounterElapsed,[v].[ResetDetected],@ServerStartAfter,
                CASE WHEN @SampleSeconds>0 AND [v].[Comparable]=0 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,@CounterLimit
            FROM [#CompileContextAnalysis_CounterRaw] AS [a]
            LEFT JOIN [#CompileContextAnalysis_CounterRaw] AS [b] ON [b].[Phase]=0 AND [b].[ObjectName]=[a].[ObjectName] AND [b].[CounterName]=[a].[CounterName] AND [b].[InstanceName]=[a].[InstanceName] AND [b].[CounterType]=[a].[CounterType]
            CROSS APPLY(SELECT CONVERT(bit,CASE WHEN @ServerReset=1 OR [a].[CounterValue]<[b].[CounterValue] THEN 1 ELSE 0 END) [ResetDetected],
                CONVERT(bit,CASE WHEN @ServerComparable=1 AND @CounterElapsed>0 AND [b].[CounterValue] IS NOT NULL AND [a].[CounterValue]>=[b].[CounterValue] AND [a].[CounterType] IN(272696320,272696576) THEN 1 ELSE 0 END) [Comparable]) AS [v]
            CROSS APPLY [monitor].[TVF_InterpretPerformanceCounter]([a].[CounterType],CASE WHEN [v].[Comparable]=1 THEN [b].[CounterValue] END,[a].[CounterValue],NULL,NULL,CASE WHEN [v].[Comparable]=1 THEN @CounterElapsed END) AS [typed]
            WHERE [a].[Phase]=1;
            INSERT [#CompileContextAnalysis_waits]
            SELECT [a].[WaitType],[b].[WaitingTasksCount],[a].[WaitingTasksCount],CASE WHEN [v].[Comparable]=1 THEN [a].[WaitingTasksCount]-[b].[WaitingTasksCount] END,
                [b].[WaitTimeMs],[a].[WaitTimeMs],CASE WHEN [v].[Comparable]=1 THEN [a].[WaitTimeMs]-[b].[WaitTimeMs] END,
                [b].[SignalWaitTimeMs],[a].[SignalWaitTimeMs],CASE WHEN [v].[Comparable]=1 THEN [a].[SignalWaitTimeMs]-[b].[SignalWaitTimeMs] END,
                @WaitStart,@WaitEnd,@WaitElapsed,[v].[ResetDetected],CASE WHEN @SampleSeconds>0 AND [v].[Comparable]=0 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,@WaitLimit
            FROM [#CompileContextAnalysis_WaitRaw] AS [a]
            LEFT JOIN [#CompileContextAnalysis_WaitRaw] AS [b] ON [b].[Phase]=0 AND [b].[WaitType]=[a].[WaitType]
            CROSS APPLY(SELECT CONVERT(bit,CASE WHEN @ServerReset=1 OR [a].[WaitingTasksCount]<[b].[WaitingTasksCount] OR [a].[WaitTimeMs]<[b].[WaitTimeMs] OR [a].[SignalWaitTimeMs]<[b].[SignalWaitTimeMs] THEN 1 ELSE 0 END) [ResetDetected],
                CONVERT(bit,CASE WHEN @ServerComparable=1 AND @WaitElapsed>0 AND [b].[WaitType] IS NOT NULL AND [a].[WaitingTasksCount]>=[b].[WaitingTasksCount] AND [a].[WaitTimeMs]>=[b].[WaitTimeMs] AND [a].[SignalWaitTimeMs]>=[b].[SignalWaitTimeMs] THEN 1 ELSE 0 END) [Comparable]) AS [v]
            WHERE [a].[Phase]=1;
            SELECT @SourceStatus='AVAILABLE',@SourceError=NULL,@SourceMessage=NULL,@SourceRows=0,@SourceTime=SYSUTCDATETIME();
            BEGIN TRY
                INSERT [#CompileContextAnalysis_cache]
                SELECT [type] COLLATE SQL_Latin1_General_CP1_CS_AS,SUM(CONVERT(bigint,[entries_count])),SUM(CONVERT(bigint,[pages_kb])),@SourceTime,'AVAILABLE',@CacheLimit FROM [sys].[dm_os_memory_cache_counters] WITH (NOLOCK)
                WHERE [type] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'CACHESTORE_SQLCP',N'CACHESTORE_OBJCP') GROUP BY [type] COLLATE SQL_Latin1_General_CP1_CS_AS;
                SET @SourceRows=@@ROWCOUNT;
                IF @SourceRows<>2 SET @SourceStatus='SOURCE_UNAVAILABLE';
            END TRY
            BEGIN CATCH
                DELETE FROM [#CompileContextAnalysis_cache];
                SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,@SourceError=ERROR_NUMBER(),@SourceMessage=ERROR_MESSAGE();
            END CATCH;
            INSERT [#CompileContextAnalysis_Observations] VALUES('CACHE',NULL,NULL,N'sys.dm_os_memory_cache_counters',@SourceTime,@SourceStatus,CONVERT(bit,CASE WHEN @SourceStatus='AVAILABLE' THEN 0 ELSE 1 END),@SourceRows,@SourceError,@SourceMessage,@CacheLimit,4);
        END;
        INSERT [#CompileContextAnalysis_sourceStatus] SELECT [SourceKey],[DatabaseId],[DatabaseName],[SourceObject],[CapturedAtUtc],[StatusCode],[IsPartial],[RowCount],[ErrorNumber],[ErrorMessage],[EvidenceLimit] FROM [#CompileContextAnalysis_Observations] ORDER BY [SourceRank],[ObservationOrdinal];
        INSERT [#CompileContextAnalysis_warnings] SELECT 'DATABASE_SELECTION',NULL,[RequestedName],LEFT(COALESCE([ErrorMessage],N'Datenbank nicht verarbeitet.'),1000) FROM [#CompileContextAnalysis_CandidateWarnings];
        INSERT [#CompileContextAnalysis_warnings] SELECT 'SOURCE_PARTIAL',[DatabaseId],[DatabaseName],LEFT(CONCAT([SourceKey],N': ',[StatusCode],N'. ',COALESCE([ErrorMessage],[EvidenceLimit])),1000) FROM [#CompileContextAnalysis_sourceStatus] WHERE [IsPartial]=1;
        INSERT [#CompileContextAnalysis_warnings] VALUES('SERVER_SCOPE',NULL,NULL,N'Counter, Waits und Cache gelten serverweit und sind den ausgewählten Datenbanken nicht zugeordnet. Eigenaktivität ist enthalten.');
        IF @SampleSeconds>0
        BEGIN
            INSERT [#CompileContextAnalysis_warnings] VALUES('SAMPLE_SCOPE',NULL,NULL,N'Counter und Waits besitzen getrennte nach ihrer jeweiligen Aufnahme gebundene Zeitklammern. Zwei Aufnahmen schließen zwischenzeitliche Resets nicht aus.');
            IF EXISTS(SELECT 1 FROM [#CompileContextAnalysis_counters] WHERE [SourceStatus]='AVAILABLE_LIMITED') OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_waits] WHERE [SourceStatus]='AVAILABLE_LIMITED')
                INSERT [#CompileContextAnalysis_warnings] VALUES('SAMPLE_NOT_COMPARABLE',NULL,NULL,N'Mindestens ein Sample ist nicht vergleichbar; die betroffenen Deltas und Raten bleiben NULL.');
        END;
        IF EXISTS(SELECT 1 FROM [#CompileContextAnalysis_counters] WHERE [Interpretation]='RAW_UNINTERPRETED')
            INSERT [#CompileContextAnalysis_warnings] VALUES('COUNTER_TYPE_UNINTERPRETED',NULL,NULL,N'Unbekannte Countertypen bleiben Rohwerte; aus ihrem Namen wird keine Rate abgeleitet.');
        IF EXISTS(SELECT 1 FROM [#CompileContextAnalysis_sourceStatus] WHERE [IsPartial]=1) OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_CandidateWarnings])
            OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_counters] WHERE [SourceStatus]='AVAILABLE_LIMITED') OR EXISTS(SELECT 1 FROM [#CompileContextAnalysis_waits] WHERE [SourceStatus]='AVAILABLE_LIMITED') SET @Partial=1;
        SELECT TOP(1) @Error=[ErrorNumber],@Message=[ErrorMessage] FROM [#CompileContextAnalysis_Observations] WHERE [ErrorNumber] IS NOT NULL ORDER BY [SourceRank],[ObservationOrdinal];
        IF @Status='AVAILABLE' AND @Partial=1 SET @Status='AVAILABLE_LIMITED';
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseName],[DatabaseId]) [OutputOrdinal] FROM [#CompileContextAnalysis_configurations]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [ObjectName],[CounterName],[InstanceName],[CounterType]) [OutputOrdinal] FROM [#CompileContextAnalysis_counters]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [WaitType]) [OutputOrdinal] FROM [#CompileContextAnalysis_waits]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [CacheType]) [OutputOrdinal] FROM [#CompileContextAnalysis_cache]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [SourceKey],[DatabaseName],[DatabaseId]) [OutputOrdinal] FROM [#CompileContextAnalysis_sourceStatus]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        ;WITH [Bounded] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [WarningCode],[DatabaseName],[DatabaseId],[Detail]) [OutputOrdinal] FROM [#CompileContextAnalysis_warnings]) DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        DECLARE @RowCount bigint=(SELECT COUNT_BIG(*) FROM [#CompileContextAnalysis_configurations])+(SELECT COUNT_BIG(*) FROM [#CompileContextAnalysis_counters])+(SELECT COUNT_BIG(*) FROM [#CompileContextAnalysis_waits])+(SELECT COUNT_BIG(*) FROM [#CompileContextAnalysis_cache]);
        INSERT [#CompileContextAnalysis_moduleStatus] VALUES(N'USP_CompileContextAnalysis',@CapturedAtUtc,@Status,@Partial,@RowCount,
            CASE WHEN @Major>=16 THEN N'VIEW SERVER PERFORMANCE STATE; visible database configuration' ELSE N'VIEW SERVER STATE; visible database configuration' END,@Error,@Message,N'Lokale Capability und getrennte serverweite Momentaufnahmen oder Samples; keine automatische Ursachen- oder Reparaturbewertung.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'CompileContextAnalysis' [resultName],1 [schemaVersion],@CapturedAtUtc [generatedAtUtc],@Status [statusCode],@Partial [isPartial],@Error [errorNumber],@Message [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_configurations nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_configurations] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_counters nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_counters] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_waits nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_waits] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_cache nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_cache] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_sourceStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#CompileContextAnalysis_warnings] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"configurations":',COALESCE(@Json_configurations,N'[]'),N',"counters":',COALESCE(@Json_counters,N'[]'),N',"waits":',COALESCE(@Json_waits,N'[]'),N',"cache":',COALESCE(@Json_cache,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#CompileContextAnalysis_moduleStatus];
            SELECT * FROM [#CompileContextAnalysis_configurations];
            SELECT * FROM [#CompileContextAnalysis_counters];
            SELECT * FROM [#CompileContextAnalysis_waits];
            SELECT * FROM [#CompileContextAnalysis_cache];
            SELECT * FROM [#CompileContextAnalysis_sourceStatus];
            SELECT * FROM [#CompileContextAnalysis_warnings];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [CompileContextOutput] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#CompileContextAnalysis_Map] ORDER BY [ResultName];
            OPEN [CompileContextOutput]; FETCH NEXT FROM [CompileContextOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#CompileContextAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
                FETCH NEXT FROM [CompileContextOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [CompileContextOutput]; DEALLOCATE [CompileContextOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#CompileContextAnalysis_Console]([Scope] nvarchar(300) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Context] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Value] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
            INSERT [#CompileContextAnalysis_Console] SELECT CONCAT(N'DATABASE: ',[DatabaseName]),[ConfigurationName],CONVERT(nvarchar(128),[Enabled]),[SourceStatus] FROM [#CompileContextAnalysis_configurations];
            INSERT [#CompileContextAnalysis_Console] SELECT N'SERVER',[CounterName],CONVERT(nvarchar(128),[AfterValue]),[SourceStatus] FROM [#CompileContextAnalysis_counters];
            INSERT [#CompileContextAnalysis_Console] SELECT N'SERVER',[WaitType],CONVERT(nvarchar(128),[AfterWaitTimeMs]),[SourceStatus] FROM [#CompileContextAnalysis_waits];
            INSERT [#CompileContextAnalysis_Console] SELECT N'SERVER',[CacheType],CONVERT(nvarchar(128),[EntriesCount]),[SourceStatus] FROM [#CompileContextAnalysis_cache];
            INSERT [#CompileContextAnalysis_Console] VALUES(N'MODULE',N'CompileContextAnalysis',CONVERT(nvarchar(128),@RowCount),@Status);
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#CompileContextAnalysis_Console',@ResultLabel=N'Compile-Kontext: lokale Konfiguration und getrennte Serverscopes',@EmptyMessage=N'Keine sichtbare Compile-Kontextevidenz.';
        END;
        IF @PrintMeldungen=1 AND @Status<>'AVAILABLE'
        BEGIN
            DECLARE @PrintMessage nvarchar(2048)=LEFT(CONCAT(N'USP_CompileContextAnalysis: ',@Status,N'. ',COALESCE(@Message,N'Siehe sourceStatus und warnings.')),2048);
            RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON;
    END TRY
    BEGIN CATCH
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON;
        THROW;
    END CATCH;
END;
GO
