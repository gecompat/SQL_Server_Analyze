USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_IntelligentQueryProcessingAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Dokumentiert IQP-Voraussetzungen, Query-Store-Feedback,
               Query-Varianten und Automatic-Tuning-Evidenz je Datenbank.
Datenquellen : sys.database_query_store_options,
               sys.database_scoped_configurations,
               sys.query_store_query_variant,
               sys.query_store_plan_feedback,
               sys.database_automatic_tuning_options und
               sys.dm_db_tuning_recommendations.
Datenschutz  : Liest weder Query-Text noch Showplan, Objekt- oder Benutzerdaten.
Grenzen      : Vorhandene oder fehlende Feedbackzeilen beweisen weder Nutzen
               noch Fehler. Verfügbarkeit wird versionsadaptiv ausgewiesen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_IntelligentQueryProcessingAnalysis]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
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

    DECLARE @OutputMode varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'signals',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_IntelligentQueryProcessingAnalysis';
        PRINT N'Liest IQP-Konfiguration und aggregierte Varianten-, Planfeedback- und Automatic-Tuning-Evidenz; niemals Query-Text oder Showplan.';
        PRINT N'CATALOG_DEEP ist immer aktiv: @HighImpactConfirmed=1 ist auch bei kleinem Scope und Limit erforderlich; Gruppenfreigabe wird separat geprüft.';
        PRINT N'Sammlung erfolgt vor @MaxZeilen. NULL/0 bedeutet unbegrenzt; Warnungen sind unbegrenzt. Ausgabeart ändert den Sammlungspfad nicht.';
        PRINT N'Die beschriebenen Parameterprüfungen gelten im normalen Analysepfad; Hilfe kehrt nach frühen Mappingprüfungen davor zurück. Ausgelassen gilt jeweils der ausdrücklich bezeichnete Default. Quellen werden je Datenbank als gemeinsamer Batch verarbeitet; frühere Einfügungen können bei einem späteren Quellenfehler als partielle Evidenz erhalten bleiben.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Eingabe: optionale bracket-aware Pipe-Liste exakter Datenbanknamen; jeder Name kann als [Name] geklammert sein. NULL, leerer String oder nur äußere U+0020-Leerzeichen bedeuten keine Listenbegrenzung und wählen zusammen mit fehlendem Pattern alle sichtbaren, online befindlichen Datenbanken entsprechend dem Systemdatenbankschalter. Nichtleere Liste und Pattern sind exklusiv; leere Elemente und doppelte Namen sind ungültig. Nicht verfügbare Namen werden Warnungen. Systemdatenbanken erfordern zusätzlich @SystemdatenbankenEinbeziehen=1. CATALOG_DEEP ist immer aktiv und braucht @HighImpactConfirmed=1, auch bei einer Datenbank und kleinem Limit. Pipe trennt nur außerhalb von [...]; ]] maskiert eine schließende Klammer. Ein gültiger Name benötigt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Eingabe: 0 schließt Systemdatenbanken aus; 1 nimmt sie in den Kandidatenscope auf. NULL ist ungültig. Gilt für Listen- und Patternauswahl; Opt-in erteilt keine CATALOG_DEEP-Bestätigung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. 1 umgeht weder Online-/Sichtbarkeitsfilter noch Namens-/Patternauswahl. Die NULL-Prüfung erfolgt bei erreichter Datenbankvorbereitung.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Eingabe: optionaler Datenbanknamenfilter, exklusiv zu jeder nichtleeren @DatabaseNames-Liste. NULL bedeutet kein Pattern; ohne Liste werden sichtbare, online befindliche Datenbanken entsprechend dem Systemdatenbankschalter gewählt. Leeres oder nur aus äußeren U+0020-Leerzeichen bestehendes Pattern ist ungültig. Standardmodus LIKE mit den üblichen Wildcards % für beliebig viele und _ für genau ein Zeichen; Präfix LIKE:, REGEX: oder REGEXI: wählt LIKE, case-sensitive Regex (Flag c) oder case-insensitive Regex (Flag i). Außenliegende Leerzeichen werden entfernt; Inhalt nach Präfix nicht erneut. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Pattern begrenzt Datenbankkandidaten, nicht Feedbackzeilen. LIKE wird mit expliziter Framework-CS-Collation verglichen; auch Zeichenklassen [...] sind möglich. Präfixerkennung ist case-insensitiv. Leerer Rest nach jedem Präfix ist ungültig; Regex-Syntax wird nicht vorab geprüft. Die Zuweisung an nvarchar(4000) erfolgt vor der Parameterprüfung.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Eingabe: 0 verweigert den stets aktivierten CATALOG_DEEP-Pfad mit Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt ihn. NULL ist ungültig. Die Bestätigung ist unabhängig von Zeilenlimit, Scopebreite und Gruppenzugehörigkeit; sie erteilt keine fehlende Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Die Statusfolge setzt voraus, dass keine frühere Parameterablehnung die Auswahl verhindert; Hilfe kehrt vorher zurück.';
        PRINT N'@MaxZeilen int; Default: 1000. Eingabe: ganzzahlig von 0 bis 2.147.483.647. Positive Werte begrenzen nach vollständiger Sammlung in RAW und JSON die Fachmengen databaseState, configuration, automaticTuning und signals jeweils getrennt mit TOP; Signale werden einmal materialisiert. NULL und 0 bedeuten unbegrenzt. Negative Werte liefern INVALID_PARAMETER, IsPartial=1 und leere Fachsammlungen. Das Limit begrenzt weder Datenbankauswahl/-cursor noch vorgelagerte Abfragen/Zählungen; Warnungen bleiben unbegrenzt. Kein HasMore-Indikator. Datenbankzustand wird nach DatabaseId, Konfiguration nach DatabaseId/ConfigurationName, Automatic Tuning nach DatabaseId/OptionName und Signale nach DatabaseId/SignalCode gewählt, jeweils aufsteigend. TABLE und aktive CONSOLE geben nur signals aus und versprechen keine physische Reihenfolge.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Eingabe: nach Trim und Großschreibung nur CONSOLE, RAW, TABLE oder NONE; NULL, leerer String und andere Werte sind ungültig. CONSOLE gibt ausschließlich Signals mit Ergebnisbeschriftung aus; leer erscheint eine verständliche Leerzeile. RAW gibt sechs Resultsets: Meta, DatabaseState, Configuration, AutomaticTuning, Signals und Errors. TABLE exportiert ausschließlich Signals. NONE erzeugt keine Resultsets. Ein nichtleeres @ResultTablesJson ist nur mit TABLE zulässig und löst sonst vor der Hilfeprüfung einen Fehler aus. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen; ein solcher Leerwert ist ungültig. Die Bindung an varchar(16) erfolgt vor der Prüfung. JSON bleibt unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Außerhalb TABLE sind ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft vor Hilfe Fehler 51011. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel signals (aggregierte IQP-Signale) erforderlich. Der Stringwert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, Nicht-Stringwerte oder ungültige Ziele scheitern im frühen ThrowOnError-Preflight vor Hilfe und Fachvalidierung. Der Writer ersetzt die Seed-Struktur durch die sechs Signalfelder. Andere IQP-Ergebnisgruppen können nicht über TABLE gemappt werden.';
        PRINT N'@JsonErzeugen bit; Default: 0. Eingabe: 1 erzeugt unabhängig von ResultSetArt das JSON; 0 deaktiviert es. NULL verhält sich wie deaktiviert und wird nicht eigens validiert. Hilfe kehrt vorher zurück. JSON enthält meta, databaseState, configuration, automaticTuning, signals und warnings; Fachsammlungen folgen ihrem Limit. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. meta enthält Modulstatus/Partialität; databaseState die Eignung/Zustände, configuration die erfassten Optionen, automaticTuning die Tuningzustände, signals die aggregierten Zähler und warnings die Quellenfehler.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Ausgabe: wird sofort auf NULL zurückgesetzt. Bei normalem Lauf wird bei @JsonErzeugen=1 das Dokument gesetzt, sonst bleibt es NULL. Eingabewert wird ignoriert. Bei Hilfe bleibt es NULL; Parameter darf weggelassen werden. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem THROW keine zugesicherte OUTPUT-Rückübertragung.';
        PRINT N'@PrintMeldungen bit; Default: 1. Eingabe: derzeit vollständig unbenutzt. 0, 1 und NULL ändern weder PRINT-, Resultset-, JSON- noch Fehlerverhalten; keine Auswirkung auf Validierung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@Hilfe bit; Default: 0. Eingabe: genau 1 gibt Hilfe per PRINT aus und kehrt vor normaler Validierung/Quellensammlung zurück; NULL oder 0 führen den normalen Pfad aus. @Json wird vorher auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Werte bleiben im Hilfepfad unverändert. Vor Hilfe kann ein nichtleeres Mapping bei Nicht-TABLE bereits einen Fehler werfen; TABLE führt zuerst den signals-Preflight aus. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT des abschließenden Modulstatus, kein Eingabefilter. Vollständige aktuelle Statusmenge: AVAILABLE (Sammlung ohne festgestellten Befund), AVAILABLE_WITH_FINDING (Sammlung mit Konfigurationsbefund), AVAILABLE_LIMITED (verfügbare, aber partielle Sammlung), DATABASE_UNAVAILABLE (kein auswertbarer Datenbankzustand), DENIED_PERMISSION (keine Zustandsmenge bei erfasstem Berechtigungsfehler), INVALID_PARAMETER (ungültiger Aufruf). Der Vorbereitungshelfer kann zusätzlich HIGH_IMPACT_CONFIRMATION_REQUIRED (fehlende Bestätigung), DENIED_GROUP (fehlende Gruppenfreigabe), UNAVAILABLE_FEATURE (nicht unterstützter Quellregex) oder INTERNAL_ERROR (interner Helfer-/Tabellenfehler) liefern. ERROR_HANDLED ist nur Quellenstatus, kein Modulstatus. Eine varchar(40)-Variable mit OUTPUT binden. Zuweisung vor JSON und fachlicher Ausgabe; bei Hilfe bleibt der Eingabewert unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT der Partialität, kein Eingabeschalter. 1 bei eigenem ungültigem Zeilenlimit/Ausgabemodus sowie erfassten Datenbank-/Quellfehlern oder Kandidatenwarnungen; 0 bei keiner festgestellten Partialität, auch eine Helfer-Gate-Ablehnung kann 0 behalten. Ein Limit allein setzt das Bit nicht. Eine bit-Variable mit OUTPUT binden. Zuweisung vor JSON und Ausgabe; bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Ausgabe: interne ErrorNumber wird im aktuellen Implementierungsstand nie gesetzt; normal daher NULL. Quellfehlernummern stehen in RAW Errors bzw. JSON warnings, nicht hier. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine int-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Ausgabe: Modulvalidierungs- oder Helfermeldung, falls gesetzt; Meldung des ersten Quellfehlers wird nicht hierher kopiert. Quellfehler stehen in RAW Errors bzw. JSON warnings. Sonst normal NULL. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine nvarchar(2048)-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.';
        PRINT N'EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @Hilfe = 1;';
        PRINT N'EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames = N''[ExampleDatabase]'', @HighImpactConfirmed = 1, @MaxZeilen = 100, @ResultSetArt = ''RAW'';';
        PRINT N'DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames = N''[ExampleDatabase]'', @HighImpactConfirmed = 1, @MaxZeilen = 100, @ResultSetArt = ''NONE'', @JsonErzeugen = 1, @Json = @JsonOut OUTPUT;
SELECT @JsonOut AS [Json];';
        PRINT N'CREATE TABLE [#IntelligentQueryProcessingAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @HighImpactConfirmed=1, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"signals":"#IntelligentQueryProcessingAnalysis_HelpExample"}'';
 SELECT * FROM [#IntelligentQueryProcessingAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
 THROW;
END CATCH;';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @Db sysname;
    DECLARE @Sql nvarchar(max);
    DECLARE @ProductMajorVersion int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_DatabaseCandidates]
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

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_DatabaseState]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CompatibilityLevel] tinyint NULL
        , [QueryStoreActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryStoreDesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryStoreReadonlyReason] bigint NULL
        , [PspEligible] bit NOT NULL
        , [OppoEligible] bit NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_Configuration]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ConfigurationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ConfigurationValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValueDefault] bit NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_AutomaticTuning]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [OptionName] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ReasonDesc] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_Signals]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SignalCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsSourceAvailable] bit NOT NULL
        , [EvidenceCount] bigint NULL
        , [Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_SignalsExport]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SignalCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsSourceAvailable] bit NOT NULL
        , [EvidenceCount] bigint NULL
        , [Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#IntelligentQueryProcessingAnalysis_Errors]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER',
               @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Datenbank-, Zeilen- oder Ausgabeparameter.';
        IF @MaxZeilen < 0 SET @Limit = 0;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = 'CATALOG_DEEP'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#IntelligentQueryProcessingAnalysis_DatabaseCandidates',@WarningTable=N'#IntelligentQueryProcessingAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE [database_cursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseName]
            FROM [#IntelligentQueryProcessingAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];

        OPEN [database_cursor];
        FETCH NEXT FROM [database_cursor] INTO @Db;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @Sql = N'USE ' + QUOTENAME(@Db) + N';
DECLARE @DatabaseId int = DB_ID();
DECLARE @DatabaseName sysname = (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());
DECLARE @CompatibilityLevel tinyint =
    (SELECT [compatibility_level] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());
DECLARE @ActualStateDesc nvarchar(60) = NULL;
DECLARE @DesiredStateDesc nvarchar(60) = NULL;
DECLARE @ReadonlyReason bigint = NULL;

SELECT TOP (1)
      @ActualStateDesc = [actual_state_desc]
    , @DesiredStateDesc = [desired_state_desc]
    , @ReadonlyReason = [readonly_reason]
FROM [sys].[database_query_store_options] WITH (NOLOCK);

INSERT [#IntelligentQueryProcessingAnalysis_DatabaseState]
(
      [DatabaseId], [DatabaseName], [CompatibilityLevel]
    , [QueryStoreActualStateDesc], [QueryStoreDesiredStateDesc]
    , [QueryStoreReadonlyReason], [PspEligible], [OppoEligible]
    , [FindingCode], [FindingSeverity], [EvidenceLimit]
)
SELECT
      @DatabaseId, @DatabaseName, @CompatibilityLevel
    , @ActualStateDesc, @DesiredStateDesc, @ReadonlyReason
    , CONVERT(bit, CASE WHEN @ProductMajorVersion >= 16 AND @CompatibilityLevel >= 160 THEN 1 ELSE 0 END)
    , CONVERT(bit, CASE WHEN @ProductMajorVersion >= 17 AND @CompatibilityLevel >= 170 THEN 1 ELSE 0 END)
    , CASE WHEN COALESCE(@ActualStateDesc, N''OFF'') COLLATE SQL_Latin1_General_CP1_CS_AS = N''OFF'' COLLATE SQL_Latin1_General_CP1_CS_AS THEN ''QUERY_STORE_OFF''
           WHEN @ActualStateDesc COLLATE SQL_Latin1_General_CP1_CS_AS = N''READ_ONLY'' COLLATE SQL_Latin1_General_CP1_CS_AS AND @DesiredStateDesc COLLATE SQL_Latin1_General_CP1_CS_AS = N''READ_WRITE'' COLLATE SQL_Latin1_General_CP1_CS_AS THEN ''QUERY_STORE_READ_ONLY''
           WHEN @CompatibilityLevel < 150 THEN ''IQP_COMPATIBILITY_BELOW_150''
           ELSE ''IQP_EVIDENCE_AVAILABLE'' END
    , CASE WHEN COALESCE(@ActualStateDesc, N''OFF'') COLLATE SQL_Latin1_General_CP1_CS_AS = N''OFF'' COLLATE SQL_Latin1_General_CP1_CS_AS THEN ''HIGH''
           WHEN @ActualStateDesc COLLATE SQL_Latin1_General_CP1_CS_AS = N''READ_ONLY'' COLLATE SQL_Latin1_General_CP1_CS_AS AND @DesiredStateDesc COLLATE SQL_Latin1_General_CP1_CS_AS = N''READ_WRITE'' COLLATE SQL_Latin1_General_CP1_CS_AS THEN ''MEDIUM''
           ELSE ''INFO'' END
    , N''Feature-Eignung folgt Version und Compatibility Level; Evidenzmengen allein bewerten keine Wirksamkeit.'';

INSERT [#IntelligentQueryProcessingAnalysis_Configuration]
(
      [DatabaseId], [DatabaseName], [ConfigurationName]
    , [ConfigurationValue], [IsValueDefault]
)
SELECT
      @DatabaseId, @DatabaseName, [name]
    , CONVERT(nvarchar(4000), [value]), [is_value_default]
FROM [sys].[database_scoped_configurations] WITH (NOLOCK)
WHERE [name] IN
(
      N''PARAMETER_SENSITIVE_PLAN_OPTIMIZATION''
    , N''OPTIONAL_PARAMETER_OPTIMIZATION''
    , N''MEMORY_GRANT_FEEDBACK_PERSISTENCE''
    , N''MEMORY_GRANT_FEEDBACK_PERCENTILE_GRANT''
    , N''DOP_FEEDBACK''
    , N''CE_FEEDBACK''
    , N''BATCH_MODE_MEMORY_GRANT_FEEDBACK''
    , N''ROW_MODE_MEMORY_GRANT_FEEDBACK''
    , N''BATCH_MODE_ADAPTIVE_JOINS''
    , N''INTERLEAVED_EXECUTION_TVF''
    , N''DEFERRED_COMPILATION_TV''
);';

                IF @ProductMajorVersion >= 16
                BEGIN
                    SET @Sql += N'
    INSERT [#IntelligentQueryProcessingAnalysis_Signals]
    SELECT @DatabaseId, @DatabaseName, ''QUERY_VARIANTS'', 1, COUNT_BIG(*),
           N''Aggregierte PSP-/OPPO-Varianten; null Zeilen sind kein Fehlerbeweis.''
    FROM [sys].[query_store_query_variant] WITH (NOLOCK);

    INSERT [#IntelligentQueryProcessingAnalysis_Signals]
    SELECT @DatabaseId, @DatabaseName, ''PLAN_FEEDBACK'', 1, COUNT_BIG(*),
           N''Aggregierte CE-, Memory-Grant-, DOP- oder LAQ-Feedbackevidenz; keine Query-Texte.''
    FROM [sys].[query_store_plan_feedback] WITH (NOLOCK);';
                END
                ELSE
                BEGIN
                    SET @Sql += N'
INSERT [#IntelligentQueryProcessingAnalysis_Signals] VALUES
(@DatabaseId, @DatabaseName, ''QUERY_VARIANTS'', 0, NULL,
 N''Katalogsicht ist vor SQL Server 2022 nicht verfügbar.''),
(@DatabaseId, @DatabaseName, ''PLAN_FEEDBACK'', 0, NULL,
 N''Katalogsicht ist vor SQL Server 2022 nicht verfügbar.'');';
                END;

                SET @Sql += N'
    INSERT [#IntelligentQueryProcessingAnalysis_AutomaticTuning]
    (
          [DatabaseId], [DatabaseName], [OptionName]
        , [DesiredStateDesc], [ActualStateDesc], [ReasonDesc]
    )
    SELECT @DatabaseId, @DatabaseName, [name], [desired_state_desc],
           [actual_state_desc], [reason_desc]
    FROM [sys].[database_automatic_tuning_options] WITH (NOLOCK);

    INSERT [#IntelligentQueryProcessingAnalysis_Signals]
    SELECT @DatabaseId, @DatabaseName, ''TUNING_RECOMMENDATIONS'', 1, COUNT_BIG(*),
           N''Anzahl aktueller Automatic-Tuning-Empfehlungen; Details und SQL-Texte werden nicht gelesen.''
    FROM [sys].[dm_db_tuning_recommendations] WITH (NOLOCK);';

                EXEC [sys].[sp_executesql]
                      @Sql
                    , N'@ProductMajorVersion int'
                    , @ProductMajorVersion = @ProductMajorVersion;
            END TRY
            BEGIN CATCH
                INSERT [#IntelligentQueryProcessingAnalysis_Errors]
                VALUES
                (
                      @Db
                    , CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371, 916)
                           THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
                    , ERROR_NUMBER()
                    , ERROR_MESSAGE()
                );
                SET @IsPartial = 1;
            END CATCH;

            FETCH NEXT FROM [database_cursor] INTO @Db;
        END;

        CLOSE [database_cursor];
        DEALLOCATE [database_cursor];

        INSERT [#IntelligentQueryProcessingAnalysis_Errors]
        SELECT [RequestedName], [StatusCode], NULL, [ErrorMessage]
        FROM [#IntelligentQueryProcessingAnalysis_DatabaseCandidateWarnings];

        IF EXISTS (SELECT 1 FROM [#IntelligentQueryProcessingAnalysis_Errors])
            SET @IsPartial = 1;

        IF NOT EXISTS (SELECT 1 FROM [#IntelligentQueryProcessingAnalysis_DatabaseState])
        BEGIN
            SELECT @StatusCode = CASE WHEN EXISTS
                   (SELECT 1 FROM [#IntelligentQueryProcessingAnalysis_Errors] WHERE [StatusCode] = 'DENIED_PERMISSION')
                   THEN 'DENIED_PERMISSION' ELSE 'DATABASE_UNAVAILABLE' END,
                   @IsPartial = 1;
        END
        ELSE IF @IsPartial = 1
            SET @StatusCode = 'AVAILABLE_LIMITED';
        ELSE IF EXISTS
                (SELECT 1 FROM [#IntelligentQueryProcessingAnalysis_DatabaseState] WHERE [FindingCode] <> 'IQP_EVIDENCE_AVAILABLE')
            SET @StatusCode = 'AVAILABLE_WITH_FINDING';
    END;

    INSERT [#IntelligentQueryProcessingAnalysis_SignalsExport]
    SELECT TOP (@Limit) *
    FROM [#IntelligentQueryProcessingAnalysis_Signals]
    ORDER BY [DatabaseId], [SignalCode];

    SELECT @StatusCodeOut = @StatusCode,
           @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber,
           @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT N'IntelligentQueryProcessingAnalysis' AS [resultName],
                   1 AS [schemaVersion], @Now AS [generatedAtUtc],
                   @StatusCode AS [statusCode], @IsPartial AS [isPartial]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
        DECLARE @StateJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_DatabaseState]
             ORDER BY [DatabaseId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @ConfigurationJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_Configuration]
             ORDER BY [DatabaseId], [ConfigurationName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @AutomaticTuningJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_AutomaticTuning]
             ORDER BY [DatabaseId], [OptionName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SignalsJson nvarchar(max) =
            (SELECT * FROM [#IntelligentQueryProcessingAnalysis_SignalsExport]
             ORDER BY [DatabaseId], [SignalCode]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#IntelligentQueryProcessingAnalysis_Errors] ORDER BY [DatabaseName]
             FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"databaseState":', COALESCE(@StateJson, N'[]')
            , N',"configuration":', COALESCE(@ConfigurationJson, N'[]')
            , N',"automaticTuning":', COALESCE(@AutomaticTuningJson, N'[]')
            , N',"signals":', COALESCE(@SignalsJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]'), N'}'
        );
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_IntelligentQueryProcessingAnalysis' AS [ModuleName],
               @Now AS [CollectionTimeUtc], @StatusCode AS [StatusCode],
               @IsPartial AS [IsPartial], @ProductMajorVersion AS [ProductMajorVersion],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Read-only; keine Query-Texte oder Showplans.' AS [Detail];
        SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_DatabaseState] ORDER BY [DatabaseId];
        SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_Configuration] ORDER BY [DatabaseId], [ConfigurationName];
        SELECT TOP (@Limit) * FROM [#IntelligentQueryProcessingAnalysis_AutomaticTuning] ORDER BY [DatabaseId], [OptionName];
        SELECT * FROM [#IntelligentQueryProcessingAnalysis_SignalsExport] ORDER BY [DatabaseId], [SignalCode];
        SELECT * FROM [#IntelligentQueryProcessingAnalysis_Errors] ORDER BY [DatabaseName];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Intelligent Query Processing' AS [Ergebnis], @Now AS [Stand_UTC],
               @StatusCode AS [Status], @IsPartial AS [Teilweise],
               (SELECT COUNT_BIG(*) FROM [#IntelligentQueryProcessingAnalysis_DatabaseState]) AS [Datenbanken],
               N'Aggregierte Evidenz ohne Query-Text oder Showplan.' AS [Hinweis];

        SELECT TOP (@Limit)
               N'IQP-Datenbankstatus' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [CompatibilityLevel] AS [Compatibility_Level],
               [QueryStoreActualStateDesc] AS [Query_Store],
               [PspEligible] AS [PSP_geeignet], [OppoEligible] AS [OPPO_geeignet],
               [FindingCode] AS [Befund], [FindingSeverity] AS [Prioritaet],
               [EvidenceLimit] AS [Grenze]
        FROM [#IntelligentQueryProcessingAnalysis_DatabaseState]
        ORDER BY [DatabaseId];

        SELECT
               N'IQP-Signal' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [SignalCode] AS [Signal], [IsSourceAvailable] AS [Quelle_verfuegbar],
               [EvidenceCount] AS [Anzahl], [Interpretation]
        FROM [#IntelligentQueryProcessingAnalysis_SignalsExport]
        ORDER BY [DatabaseId], [SignalCode];

        SELECT N'IQP-Warnung' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [StatusCode] AS [Status], [ErrorNumber] AS [Fehlernummer],
               [ErrorMessage] AS [Meldung]
        FROM [#IntelligentQueryProcessingAnalysis_Errors]
        ORDER BY [DatabaseName];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#IntelligentQueryProcessingAnalysis_SignalsExport'
            , @ResultLabel=N'IntelligentQueryProcessingAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#IntelligentQueryProcessingAnalysis_SignalsExport'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
