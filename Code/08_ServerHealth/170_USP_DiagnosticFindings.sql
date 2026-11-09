USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DiagnosticFindings
Version      : 1.2.1
Stand        : 2026-10-20
Zweck        : Aggregiert normalisierte Befunde aus den zuvor implementierten
               Spezialfallmodulen über deren JSON-Ausgabeverträge.
Abhängigkeit : DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis,
               BufferPoolAnalysis, BackupChainAnalysis,
               AvailabilityDeepAnalysis, AgentMonitoringAnalysis sowie opt-in
               SchemaDesignAnalysis, StatisticsDistributionAnalysis,
               IntelligentQueryProcessingAnalysis und InternalContentionAnalysis.
Methodik     : Kindmodule laufen mit @ResultSetArt=NONE. Innerhalb eines
               Orchestratoraufrufs können kontextgleiche Parent-Ergebnisse
               wiederverwendet werden; sonst werden Quellen frisch gelesen.
               Der Aggregator liest nur definierte JSON-Felder und übernimmt
               keine freien SQL-, Mail-, Plan-, Pfad- oder Meldungstexte.
Grenzen      : Priorität ist Triage, keine automatische Ursachenfeststellung.
               Kein READPAST; unvollständige Child-Evidenz bleibt sichtbar.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DiagnosticFindings]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MitIntegritaet               bit            = 1
    , @MitKapazitaet                bit            = 1
    , @MitSpeicher                  bit            = 1
    , @MitBackupketten              bit            = 1
    , @MitAvailability              bit            = 1
    , @MitAgentMonitoring           bit            = 1
    , @MitSchemaDesign              bit            = 0
    , @MitStatistikverteilung       bit            = 0
    , @MitIQP                       bit            = 0
    , @MitContention                bit            = 0
    , @ContentionSampleSeconds      tinyint         = 5
    , @ContentionMinWaitMs          bigint          = 1000
    , @ParentIntegrityJson          nvarchar(max)   = NULL
    , @ParentCapacityJson           nvarchar(max)   = NULL
    , @ParentBufferPoolJson         nvarchar(max)   = NULL
    , @NurAbPrioritaet              varchar(16)     = 'INFO'
    , @MaxZeilen                    int             = 1000
    , @ResultSetArt                 varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit             = 0
    , @Json                         nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen               bit             = 1
    , @Hilfe                        bit             = 0
    , @StatusCodeOut                varchar(40)     = NULL OUTPUT
    , @IsPartialOut                 bit             = NULL OUTPUT
    , @ErrorNumberOut               int             = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048)  = NULL OUTPUT
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'findings',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @MinimumSeverity varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@NurAbPrioritaet, ''))));
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                 THEN CONVERT(bigint, 9223372036854775807)
                                 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_DiagnosticFindings';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL; bei Auslassung gilt NULL. Der Kandidatenhelfer behandelt den gesamten Listenwert NULL, leer oder nur aus U+0020-Leerzeichen bestehend als nicht angegeben; andere Whitespace-Zeichen wie Tabulatoren werden dabei nicht als Leerwert normalisiert. Das Pipe-Zeichen | trennt Elemente außerhalb von eckigen Klammern; innerhalb eines bracket-quotierten Elements maskiert ]] eine schließende Klammer. Äußere U+0020-Leerzeichen jedes Segments werden entfernt. Ein ungetrimmtes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; leere Segmente und fehlerhafte Klammerung sind ungültig. Die Namensprüfung verlangt, dass PARSENAME(Element, 1) nicht NULL und höchstens 128 Zeichen lang ist und PARSENAME(Element, 2) NULL ist. Sie prüft keine vollständige SQL-Bezeichnergrammatik und kontrolliert die Teile 3 und 4 nicht zusätzlich. Gültige doppelte Namenswerte sind unter SQL_Latin1_General_CP1_CS_AS ungültig; Namen mit abweichender Groß- und Kleinschreibung bleiben verschieden. Erst wenn der gemeinsame Kandidatenhelfer erreicht wird, führen ungültige Elemente oder Duplikate zu INVALID_PARAMETER. Die Kandidatenauswahl bleibt durch Sichtbarkeit, Onlinezustand und HAS_DBACCESS begrenzt; die Liste garantiert weder die Existenz noch den Zugriff auf einen Namen und gewährt keine zusätzlichen Rechte. Der DiagnosticFindings-Parent reicht die unveränderte Liste an tatsächlich aufgerufene DatabaseIntegrityAnalysis-, DatabaseCapacityAnalysis-, BackupChainAnalysis-, SchemaDesignAnalysis-, StatisticsDistributionAnalysis- und IntelligentQueryProcessingAnalysis-Kindmodule weiter. Die Liste und ein nicht-NULL Pattern sind im erreichten Kandidatenhelfer nur dann unvereinbar, wenn nach der Normalisierung eine wirksame Namensliste vorliegt. ParentIntegrityJson- und ParentCapacityJson-Wiederverwendung überspringt den jeweiligen Kindmodulaufruf; übernommenes JSON wird durch die Liste nicht nachträglich gefiltert. Frühe Fehler oder nicht aufgerufene Kindmodule können die Kandidatenprüfung verhindern; der Parent garantiert keinen einheitlichen Status für Listenfehler.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weitergereicht, nicht an BufferPool, Availability, AgentMonitoring oder Contention. Bei erreichter Kandidatenprüfung weist der gemeinsame Helper NULL als INVALID_PARAMETER ab. 0 schließt Datenbanken mit database_id bis einschließlich 4 (master, tempdb, model und msdb) aus; 1 lässt sie unter den bestehenden Sichtbarkeits-, Online-, HAS_DBACCESS- und Empfängerfiltern zu. Der Schalter aktiviert kein Kindmodul und gewährt keine Rechte. Bei Wiederverwendung von ParentIntegrityJson oder ParentCapacityJson entfallen die jeweiligen Kindmodulaufrufe; dieser Schalter filtert übernommenes JSON nicht nachträglich. Frühere Fehler oder übersprungene Aufrufe können die Prüfung verhindern; der Parent garantiert keinen einheitlichen Status.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Der DiagnosticFindings-Parent normalisiert oder validiert das Pattern nicht und reicht es bei tatsächlichem Aufruf des jeweiligen Kindmoduls an DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weiter. Ein nicht-NULL Pattern ist im erreichten Kandidatenhelfer mit einer wirksamen expliziten Namensliste unzulässig; NULL, leerer oder nur aus U+0020 bestehender Listenwert ist keine wirksame Liste. ParentIntegrityJson- und ParentCapacityJson-Wiederverwendung überspringt den jeweiligen Kindmodulaufruf; das Pattern filtert übernommenes JSON nicht nachträglich. Frühe Fehler und übersprungene Aufrufe können die jeweilige Parserprüfung verhindern.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weitergereicht, nicht an BufferPool, Availability, AgentMonitoring oder Contention. Der gemeinsame Kandidatenhelper weist NULL als INVALID_PARAMETER ab, wenn er erreicht wird, auch bei @AnalysisClass=NULL. Integrity nutzt HA_DR_CURRENT und Capacity SERVER_HEALTH_CURRENT; laut Katalog verlangen beide keine RequiresGroupGate-Bestätigung. BackupChainAnalysis verwendet @AnalysisClass=NULL, sodass 0 oder 1 dort keine Klassenbestätigung auslösen. SchemaDesignAnalysis und IntelligentQueryProcessingAnalysis prüfen CATALOG_DEEP. StatisticsDistributionAnalysis prüft CATALOG_DEEP vor USP_Statistics; Findings ruft es im Modus VOLL auf, in dem USP_Statistics zunächst STATISTICS_TARGETED und danach ebenfalls CATALOG_DEEP prüft. Bei erreichtem CATALOG_DEEP-Gate führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED vor der Gruppenprüfung, NULL zu INVALID_PARAMETER und 1 bestätigt nur diese Anforderung. Aktuelle Policyfreigabe und SQL-Rechte gelten weiter. Der Wert aktiviert kein Kindmodul. Bei Wiederverwendung von ParentIntegrityJson oder ParentCapacityJson entfallen die jeweiligen Kindmodulaufrufe; dieser Schalter prüft oder verändert übernommenes JSON nicht nachträglich. Frühere Fehler oder übersprungene Aufrufe können Prüfungen verhindern; der Parent garantiert keinen einheitlichen Status.';
        PRINT N'@MitIntegritaet bit. Default ist 1. 1 aktiviert DatabaseIntegrityAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitKapazitaet bit. Default ist 1. 1 aktiviert DatabaseCapacityAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitSpeicher bit. Default ist 1. 1 aktiviert BufferPoolAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitBackupketten bit. Default ist 1. 1 aktiviert BackupChainAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitAvailability bit. Default ist 1. 1 aktiviert AvailabilityDeepAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitAgentMonitoring bit. Default ist 1. 1 aktiviert AgentMonitoringAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitSchemaDesign bit. Default ist 0. 1 aktiviert SchemaDesignAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitStatistikverteilung bit. Default ist 0. 1 aktiviert StatisticsDistributionAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitIQP bit. Default ist 0. 1 aktiviert IntelligentQueryProcessingAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@MitContention bit. Default ist 0. 1 aktiviert InternalContentionAnalysis. 0 oder NULL lässt diesen Aufruf aus.';
        PRINT N'@ContentionSampleSeconds tinyint. Default ist 5. Sekunden für das aktivierte Contention-Modul. 1 bis 60 fordert ein Intervalldelta an. 0 überspringt WAITFOR und liefert positive kumulative Zähler seit Serverstart. Werte über 60 sind ungültig. NULL überspringt die Wartezeit und liefert keine Latch- oder Spinlock-Deltazeilen. Raten bleiben unbekannt.';
        PRINT N'@ContentionMinWaitMs bigint. Default ist 1000. Nichtnegative Mindestwartezeit in Millisekunden für Latch-Findings aus der Contention-Auswertung. Ein Wert ab der Grenze erfüllt den Vergleich. Bei NULL entstehen aus diesem Vergleich keine Latch-Findings. Negative Werte sind ungültig.';
        PRINT N'@ParentIntegrityJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von DatabaseIntegrityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseIntegrityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.';
        PRINT N'@ParentCapacityJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von DatabaseCapacityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseCapacityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.';
        PRINT N'@ParentBufferPoolJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von BufferPoolAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=BufferPoolAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.';
        PRINT N'@NurAbPrioritaet varchar(16). Default ist ''INFO''. INFO umfasst alle Prioritätsstufen. LOW lässt INFO aus. MEDIUM umfasst MEDIUM und HIGH. HIGH lässt nur HIGH zu. Die Filterung erfolgt nach der Erhebung. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.';
        PRINT N'@MaxZeilen int. Default ist 1000. Eine positive ganze Zahl begrenzt die finale Findingmenge nach Prioritätsfilterung und wird an die Empfänger weitergereicht. NULL oder 0 hebt die Grenze auf. Negative Werte sind ungültig. Die Grenze begrenzt den gesamten Quellenaufwand nicht.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. CONSOLE zeigt beschriftete Findings. RAW liefert technische Ergebnis- und Statusmengen. TABLE schreibt ausschließlich findings. NONE unterdrückt die fachlichen Resultsets. Die Empfänger laufen mit NONE. JSON ist separat wählbar. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel findings erforderlich. Der Wert benennt eine vorhandene leere lokale #Temp-Tabelle mit einer Seed-Spalte. Erlaubt sind maximal 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. Wird beim Eintritt auf NULL gesetzt und bei aktivierter JSON-Erzeugung gefüllt. Binden Sie eine nvarchar(max)-Variable mit OUTPUT.';
        PRINT N'@PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Der Wert wird unverändert an tatsächlich ausgeführte Kindaufrufe weitergereicht (10 Aufrufstellen). 1 fordert die jeweilige optionale Meldungseinstellung des Kindes an; 0 und NULL werden ebenfalls unverändert weitergereicht. Die konkrete Wirkung folgt dem Vertrag des jeweiligen Kindes; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Im normalen Ablauf verwendet der Parent den Schalter nicht für eine eigene PRINT- oder RAISERROR-Statusmeldung. Die Parameterhilfe ist unabhängig. Bei Wiederverwendung von ParentIntegrityJson, ParentCapacityJson oder ParentBufferPoolJson wird der jeweilige Kindaufruf übersprungen; der Schalter wird auf diese übernommenen Inhalte nicht erneut angewandt. Er steuert im Parent keine Resultsets, JSON, Analyseflags oder Fehlerbehandlung; Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.';
        PRINT N'@Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Vorprüfung und beendet vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT. Default ist NULL. Empfängt den Laufstatus. Binden Sie eine varchar(40)-Variable mit OUTPUT.';
        PRINT N'@IsPartialOut bit OUTPUT. Default ist NULL. Empfängt das Partialitätsflag für die erreichbare Evidenz. Binden Sie eine bit-Variable mit OUTPUT.';
        PRINT N'@ErrorNumberOut int OUTPUT. Default ist NULL. Empfängt eine erfasste Fehlernummer oder NULL. Binden Sie eine int-Variable mit OUTPUT.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Empfängt eine erfasste Fehlermeldung oder NULL. Binden Sie eine nvarchar(2048)-Variable mit OUTPUT.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_DiagnosticFindings] @Hilfe=1;';
        PRINT N'Beispiel 2. EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];';
        PRINT N'Beispiel 4. CREATE TABLE #DiagnosticFindings_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#DiagnosticFindings_HelpExample"}''; SELECT * FROM #DiagnosticFindings_HelpExample; DROP TABLE #DiagnosticFindings_HelpExample; END TRY BEGIN CATCH DROP TABLE #DiagnosticFindings_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CurrentCompatibilityLevel int =
        (SELECT [compatibility_level] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());

    DECLARE @IntegrityJson nvarchar(max) = @ParentIntegrityJson;
    DECLARE @CapacityJson nvarchar(max) = @ParentCapacityJson;
    DECLARE @MemoryJson nvarchar(max) = @ParentBufferPoolJson;
    DECLARE @BackupJson nvarchar(max) = NULL;
    DECLARE @AvailabilityJson nvarchar(max) = NULL;
    DECLARE @AgentJson nvarchar(max) = NULL;
    DECLARE @SchemaJson nvarchar(max) = NULL;
    DECLARE @StatisticsDistributionJson nvarchar(max) = NULL;
    DECLARE @IqpJson nvarchar(max) = NULL;
    DECLARE @ContentionJson nvarchar(max) = NULL;
    DECLARE @ChildStatus varchar(40);
    DECLARE @ChildPartial bit;
    DECLARE @ChildErrorNumber int;
    DECLARE @ChildErrorMessage nvarchar(2048);

    DECLARE @ModuleStatus TABLE
    (
          [ExecutionOrdinal] tinyint NOT NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsPartial] bit NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    -- Nur die eigene Temp-Anlage erhält bei NOWAIT bis zu 1000 ms.
    DECLARE @OwnDdlEntryLock int=@@LOCK_TIMEOUT;
    BEGIN TRY
        IF @OwnDdlEntryLock=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#DiagnosticFindings_Findings]
        (
              [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL
            , [SourceModule] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [Category] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [ScopeType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [ScopeName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
            , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [EvidenceMetric] decimal(38,4) NULL
            , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
    END TRY
    BEGIN CATCH
        IF @OwnDdlEntryLock=0 SET LOCK_TIMEOUT 0;
        THROW;
    END CATCH;
    IF @OwnDdlEntryLock=0 SET LOCK_TIMEOUT 0;

    IF @MaxZeilen < 0 OR @ContentionSampleSeconds > 60
       OR @ContentionMinWaitMs < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @MinimumSeverity NOT IN ('INFO', 'LOW', 'MEDIUM', 'HIGH')
       OR (@ParentIntegrityJson IS NOT NULL AND ISJSON(@ParentIntegrityJson)<>1)
       OR (@ParentCapacityJson IS NOT NULL AND ISJSON(@ParentCapacityJson)<>1)
       OR (@ParentBufferPoolJson IS NOT NULL AND ISJSON(@ParentBufferPoolJson)<>1)
       OR (@MitIntegritaet = 0 AND @MitKapazitaet = 0 AND @MitSpeicher = 0
           AND @MitBackupketten = 0 AND @MitAvailability = 0 AND @MitAgentMonitoring = 0
           AND @MitSchemaDesign = 0 AND @MitStatistikverteilung = 0
           AND @MitIQP = 0 AND @MitContention = 0)
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Modul-, Datenbank-, Sample-, Prioritäts-, Zeilen- oder Ausgabeparameter.';
    END
    ELSE IF (@ParentIntegrityJson IS NOT NULL
             AND (COALESCE(JSON_VALUE(@ParentIntegrityJson,'$.meta.resultName'),'')<>'DatabaseIntegrityAnalysis'
                  OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@ParentIntegrityJson,'$.meta.schemaVersion')),0)<>1))
         OR (@ParentCapacityJson IS NOT NULL
             AND (COALESCE(JSON_VALUE(@ParentCapacityJson,'$.meta.resultName'),'')<>'DatabaseCapacityAnalysis'
                  OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@ParentCapacityJson,'$.meta.schemaVersion')),0)<>1))
         OR (@ParentBufferPoolJson IS NOT NULL
             AND (COALESCE(JSON_VALUE(@ParentBufferPoolJson,'$.meta.resultName'),'')<>'BufferPoolAnalysis'
                  OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@ParentBufferPoolJson,'$.meta.schemaVersion')),0)<>1))
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ein Parent-Ergebnis entspricht nicht dem erwarteten JSON-Vertrag.';
    END
    ELSE IF @CurrentCompatibilityLevel < 130
    BEGIN
        SELECT @StatusCode = 'UNAVAILABLE_FEATURE', @IsPartial = 1,
               @ErrorMessage = N'Die Befundaggregation benötigt Compatibility Level 130 oder höher für OPENJSON.';
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitIntegritaet = 1
    BEGIN
        IF @ParentIntegrityJson IS NOT NULL
        BEGIN
            SELECT @ChildStatus=JSON_VALUE(@IntegrityJson,'$.meta.statusCode'),
                   @ChildPartial=CASE JSON_VALUE(@IntegrityJson,'$.meta.isPartial')
                                      WHEN 'true' THEN 1 WHEN 'false' THEN 0
                                      ELSE COALESCE(TRY_CONVERT(bit,JSON_VALUE(@IntegrityJson,'$.meta.isPartial')),1) END,
                   @ChildErrorNumber=TRY_CONVERT(int,JSON_VALUE(@IntegrityJson,'$.meta.errorNumber')),
                   @ChildErrorMessage=JSON_VALUE(@IntegrityJson,'$.meta.errorMessage');
            INSERT @ModuleStatus VALUES (1,N'USP_DatabaseIntegrityAnalysis','REUSED_PARENT_RESULT',@ChildStatus,@ChildPartial,@ChildErrorNumber,@ChildErrorMessage);
        END
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
                EXEC [monitor].[USP_DatabaseIntegrityAnalysis]
                      @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                    , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                    , @MitPageDetails = 0, @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE'
                    , @JsonErzeugen = 1, @Json = @IntegrityJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                    , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                    , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
                INSERT @ModuleStatus VALUES (1, N'USP_DatabaseIntegrityAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
            END TRY
            BEGIN CATCH
                INSERT @ModuleStatus VALUES (1, N'USP_DatabaseIntegrityAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
            END CATCH;
        END;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitKapazitaet = 1
    BEGIN
        IF @ParentCapacityJson IS NOT NULL
        BEGIN
            SELECT @ChildStatus=JSON_VALUE(@CapacityJson,'$.meta.statusCode'),
                   @ChildPartial=CASE JSON_VALUE(@CapacityJson,'$.meta.isPartial')
                                      WHEN 'true' THEN 1 WHEN 'false' THEN 0
                                      ELSE COALESCE(TRY_CONVERT(bit,JSON_VALUE(@CapacityJson,'$.meta.isPartial')),1) END,
                   @ChildErrorNumber=TRY_CONVERT(int,JSON_VALUE(@CapacityJson,'$.meta.errorNumber')),
                   @ChildErrorMessage=JSON_VALUE(@CapacityJson,'$.meta.errorMessage');
            INSERT @ModuleStatus VALUES (2,N'USP_DatabaseCapacityAnalysis','REUSED_PARENT_RESULT',@ChildStatus,@ChildPartial,@ChildErrorNumber,@ChildErrorMessage);
        END
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
                EXEC [monitor].[USP_DatabaseCapacityAnalysis]
                      @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                    , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                    , @NurProblematisch = 0, @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE'
                    , @JsonErzeugen = 1, @Json = @CapacityJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                    , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                    , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
                INSERT @ModuleStatus VALUES (2, N'USP_DatabaseCapacityAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
            END TRY
            BEGIN CATCH
                INSERT @ModuleStatus VALUES (2, N'USP_DatabaseCapacityAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
            END CATCH;
        END;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitSpeicher = 1
    BEGIN
        IF @ParentBufferPoolJson IS NOT NULL
        BEGIN
            SELECT @ChildStatus=JSON_VALUE(@MemoryJson,'$.meta.statusCode'),
                   @ChildPartial=CASE JSON_VALUE(@MemoryJson,'$.meta.isPartial')
                                      WHEN 'true' THEN 1 WHEN 'false' THEN 0
                                      ELSE COALESCE(TRY_CONVERT(bit,JSON_VALUE(@MemoryJson,'$.meta.isPartial')),1) END,
                   @ChildErrorNumber=TRY_CONVERT(int,JSON_VALUE(@MemoryJson,'$.meta.errorNumber')),
                   @ChildErrorMessage=JSON_VALUE(@MemoryJson,'$.meta.errorMessage');
            INSERT @ModuleStatus VALUES (3,N'USP_BufferPoolAnalysis','REUSED_PARENT_RESULT',@ChildStatus,@ChildPartial,@ChildErrorNumber,@ChildErrorMessage);
        END
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
                EXEC [monitor].[USP_BufferPoolAnalysis]
                      @MitMemoryClerks = 0, @MitBufferPoolVerteilung = 0, @MaxZeilen = @MaxZeilen
                    , @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @MemoryJson OUTPUT
                    , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                    , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                    , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
                INSERT @ModuleStatus VALUES (3, N'USP_BufferPoolAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
            END TRY
            BEGIN CATCH
                INSERT @ModuleStatus VALUES (3, N'USP_BufferPoolAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
            END CATCH;
        END;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitBackupketten = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_BackupChainAnalysis]
                  @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @BackupJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (4, N'USP_BackupChainAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (4, N'USP_BackupChainAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitAvailability = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_AvailabilityDeepAnalysis]
                  @MitClusterNetzwerken = 0, @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE'
                , @JsonErzeugen = 1, @Json = @AvailabilityJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (5, N'USP_AvailabilityDeepAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (5, N'USP_AvailabilityDeepAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitAgentMonitoring = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_AgentMonitoringAnalysis]
                  @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @AgentJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (6, N'USP_AgentMonitoringAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (6, N'USP_AgentMonitoringAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitSchemaDesign = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_SchemaDesignAnalysis]
                  @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @SchemaJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (7, N'USP_SchemaDesignAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (7, N'USP_SchemaDesignAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitStatistikverteilung = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_StatisticsDistributionAnalysis]
                  @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed, @AnalyseModus = 'VOLL'
                , @MaxZeilen = @MaxZeilen
                , @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @StatisticsDistributionJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (8, N'USP_StatisticsDistributionAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (8, N'USP_StatisticsDistributionAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitIQP = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
                  @DatabaseNames = @DatabaseNames, @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed
                , @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @IqpJson OUTPUT
                , @PrintMeldungen = @PrintMeldungen, @StatusCodeOut = @ChildStatus OUTPUT
                , @IsPartialOut = @ChildPartial OUTPUT, @ErrorNumberOut = @ChildErrorNumber OUTPUT
                , @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (9, N'USP_IntelligentQueryProcessingAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (9, N'USP_IntelligentQueryProcessingAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitContention = 1
    BEGIN
        BEGIN TRY
            SELECT @ChildStatus = NULL, @ChildPartial = NULL, @ChildErrorNumber = NULL, @ChildErrorMessage = NULL;
            EXEC [monitor].[USP_InternalContentionAnalysis]
                  @SampleSeconds = @ContentionSampleSeconds, @MitSpinlocks = 1, @MitHotPages = 1
                , @MitPageDetails = 0, @MaxZeilen = @MaxZeilen, @ResultSetArt = 'NONE'
                , @JsonErzeugen = 1, @Json = @ContentionJson OUTPUT, @PrintMeldungen = @PrintMeldungen
                , @StatusCodeOut = @ChildStatus OUTPUT, @IsPartialOut = @ChildPartial OUTPUT
                , @ErrorNumberOut = @ChildErrorNumber OUTPUT, @ErrorMessageOut = @ChildErrorMessage OUTPUT;
            INSERT @ModuleStatus VALUES (10, N'USP_InternalContentionAnalysis', 'EXECUTED', @ChildStatus, @ChildPartial, @ChildErrorNumber, @ChildErrorMessage);
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (10, N'USP_InternalContentionAnalysis', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE @ParseSql nvarchar(max) = N'
INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_DatabaseIntegrityAnalysis'', ''INTEGRITY'',
       CASE WHEN [FindingCode] IN (''SUSPECT_PAGES_PRESENT'',''DAMAGED_BACKUP_METADATA'',''HADR_PAGE_REPAIR_PENDING'') THEN ''HIGH''
            WHEN [FindingCode] IN (''CHECKDB_EVIDENCE_MISSING'',''CHECKDB_EVIDENCE_OLD'') THEN ''MEDIUM'' ELSE ''LOW'' END,
       ''HIGH'', N''DATABASE'', [DatabaseName], [FindingCode],
       CONVERT(decimal(38,4), CASE WHEN [SuspectPageCount] > 0 THEN [SuspectPageCount]
                                  WHEN [DamagedBackupCount] > 0 THEN [DamagedBackupCount]
                                  ELSE [CheckdbAgeHours] END),
       CONCAT(N''Suspect pages='', [SuspectPageCount], N''; damaged backups='', [DamagedBackupCount],
              N''; CHECKDB age hours='', COALESCE(CONVERT(nvarchar(40), [CheckdbAgeHours]), N''NULL''), N''.''),
       [EvidenceLimit], N''CHECKDB-/Backup-/Seitenreparaturevidenz kontrolliert verifizieren.''
FROM OPENJSON(COALESCE(@Integrity, N''{}''), ''$.integrity'') WITH
([DatabaseName] sysname, [FindingCode] varchar(80), [SuspectPageCount] bigint,
 [DamagedBackupCount] bigint, [CheckdbAgeHours] bigint, [EvidenceLimit] nvarchar(1000))
WHERE [FindingCode] <> ''NO_INDICATOR_FOUND'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_DatabaseCapacityAnalysis'', ''CAPACITY'',
       CASE WHEN [FindingCode] IN (''FILE_MAX_SIZE_REACHED'',''NEXT_GROWTH_EXCEEDS_VOLUME_FREE'') THEN ''HIGH'' ELSE ''MEDIUM'' END,
       ''HIGH'', N''DATABASE_FILE'', CONCAT([DatabaseName], N''/'', [LogicalFileName]), [FindingCode],
       CONVERT(decimal(38,4), [VolumeFreePercent]),
       CONCAT(N''file free MB='', [FreeInFileMb], N''; volume free MB='', [VolumeAvailableMb],
              N''; next growth MB='', COALESCE(CONVERT(nvarchar(40), [NextGrowthMb]), N''NULL''), N''.''),
       [EvidenceLimit], N''Datei-, Volume- und Growth-Konfiguration gemeinsam prüfen; ohne Historie keine Zeit-bis-voll-Prognose.''
FROM OPENJSON(COALESCE(@Capacity, N''{}''), ''$.capacity'') WITH
([DatabaseName] sysname, [LogicalFileName] sysname, [FreeInFileMb] decimal(19,2),
 [VolumeAvailableMb] decimal(19,2), [VolumeFreePercent] decimal(9,2), [NextGrowthMb] decimal(19,2),
 [FindingCode] varchar(80), [EvidenceLimit] nvarchar(1000))
WHERE [FindingCode] <> ''NO_CAPACITY_INDICATOR'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_BufferPoolAnalysis'', ''MEMORY'', [FindingSeverity], ''HIGH'', N''INSTANCE'', NULL,
       [FindingCode], CONVERT(decimal(38,4), [AvailablePhysicalMemoryPercent]),
       CONCAT(N''OS available percent='', [AvailablePhysicalMemoryPercent],
              N''; process physical low='', [ProcessPhysicalMemoryLow],
              N''; process virtual low='', [ProcessVirtualMemoryLow], N''.''),
       [EvidenceLimit], N''Mit Verlauf, Resource Semaphores, anderen Prozessen und OS-Grenzen korrelieren.''
FROM OPENJSON(COALESCE(@Memory, N''{}''), ''$.memory'') WITH
([FindingCode] varchar(80), [FindingSeverity] varchar(16), [AvailablePhysicalMemoryPercent] decimal(9,2),
 [ProcessPhysicalMemoryLow] bit, [ProcessVirtualMemoryLow] bit, [EvidenceLimit] nvarchar(1000))
WHERE [FindingCode] <> ''NO_MEMORY_PRESSURE_FLAG'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_BufferPoolAnalysis'', ''MEMORY_GRANTS'', ''HIGH'', ''HIGH'', N''RESOURCE_SEMAPHORE'',
       CONCAT(N''pool='', [PoolId], N''; semaphore='', [ResourceSemaphoreId]), ''MEMORY_GRANT_WAITERS_PRESENT'',
       CONVERT(decimal(38,4), [WaiterCount]),
       CONCAT(N''waiters='', [WaiterCount], N''; available KB='', [AvailableMemoryKb], N''; granted KB='', [GrantedMemoryKb], N''.''),
       N''Momentaufnahme; kurzzeitige Wartende sind nicht automatisch ein dauerhaftes Kapazitätsproblem.'',
       N''Memory-Grant-Verlauf, Workload und Resource-Governor-Pool korrelieren.''
FROM OPENJSON(COALESCE(@Memory, N''{}''), ''$.resourceSemaphores'') WITH
([PoolId] int, [ResourceSemaphoreId] int, [AvailableMemoryKb] bigint, [GrantedMemoryKb] bigint, [WaiterCount] int)
WHERE [WaiterCount] > 0;

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_BackupChainAnalysis'', ''RECOVERABILITY'', [FindingSeverity], ''MEDIUM'', N''DATABASE'', [DatabaseName],
       [FindingCode], CONVERT(decimal(38,4), [LogGapCountInWindow]),
       CONCAT(N''log gaps='', [LogGapCountInWindow], N''; damaged='', [DamagedBackupCount],
              N''; without checksum='', [BackupWithoutChecksumCount], N''.''),
       [EvidenceLimit], N''Backuphistorie und Medien prüfen; Wiederherstellbarkeit durch kontrollierten Test-Restore belegen.''
FROM OPENJSON(COALESCE(@Backup, N''{}''), ''$.summary'') WITH
([DatabaseName] sysname, [FindingCode] varchar(100), [FindingSeverity] varchar(16),
 [LogGapCountInWindow] bigint, [DamagedBackupCount] bigint, [BackupWithoutChecksumCount] bigint,
 [EvidenceLimit] nvarchar(1000))
WHERE [FindingCode] NOT IN (''CHAIN_METADATA_CONSISTENT'',''TEMPDB_NOT_APPLICABLE'');

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AvailabilityDeepAnalysis'', ''AVAILABILITY'', [FindingSeverity], ''HIGH'', N''AG_DATABASE'',
       CONCAT([AvailabilityGroupName], N''/'', [DatabaseName]), [FindingCode],
       CONVERT(decimal(38,4), COALESCE([SecondaryLagSeconds], [LogSendQueueSizeKb], [RedoQueueSizeKb])),
       CONCAT(N''log send queue KB='', [LogSendQueueSizeKb], N''; redo queue KB='', [RedoQueueSizeKb],
              N''; lag seconds='', [SecondaryLagSeconds], N''; suspended='', [IsSuspended], N''.''),
       N''Momentaufnahme; Queuegröße und Lag benötigen Verlauf und Rate.'',
       N''Replikazustand, Datenbewegung, Netzwerk und Clusterereignisse korrelieren.''
FROM OPENJSON(COALESCE(@Availability, N''{}''), ''$.databases'') WITH
([AvailabilityGroupName] sysname, [DatabaseName] sysname, [FindingCode] varchar(100),
 [FindingSeverity] varchar(16), [SecondaryLagSeconds] bigint, [LogSendQueueSizeKb] bigint,
 [RedoQueueSizeKb] bigint, [IsSuspended] bit)
WHERE [FindingCode] <> ''DATABASE_STATE_ACCEPTABLE'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AvailabilityDeepAnalysis'', ''AVAILABILITY'',
       CASE WHEN [FindingCode] = ''QUORUM_STATE_NOT_VISIBLE'' THEN ''HIGH'' ELSE ''MEDIUM'' END,
       ''MEDIUM'', N''CLUSTER'', NULL, [FindingCode], NULL,
       CONCAT(N''quorum state='', COALESCE([QuorumStateDesc], N''NOT_VISIBLE''), N''.''),
       N''Cluster-DMV-Evidenz kann auf Linux- oder Read-Scale-Ausprägungen interne beziehungsweise nicht anwendbare Werte zeigen.'',
       N''Clusterquorum und Plattformzustand außerhalb der SQL-Instanz verifizieren.''
FROM OPENJSON(COALESCE(@Availability, N''{}''), ''$.cluster'') WITH
([QuorumStateDesc] nvarchar(60), [FindingCode] varchar(80))
WHERE [FindingCode] <> ''QUORUM_STATE_NORMAL'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AvailabilityDeepAnalysis'', ''AVAILABILITY'', ''HIGH'', ''HIGH'', N''AG_REPLICA'',
       CONCAT([AvailabilityGroupName], N''/'', [ReplicaServerName]), [FindingCode], NULL,
       CONCAT(N''role='', COALESCE([RoleDesc], N''NULL''), N''; connection='', COALESCE([ConnectedStateDesc], N''NULL''),
              N''; health='', COALESCE([SynchronizationHealthDesc], N''NULL''), N''.''),
       N''Momentaufnahme; Remote-Replikazustände können vom lokalen Sichtpunkt unvollständig sein.'',
       N''Endpoint, Netzwerk, Replikarolle und Clusterereignisse korrelieren.''
FROM OPENJSON(COALESCE(@Availability, N''{}''), ''$.replicas'') WITH
([AvailabilityGroupName] sysname, [ReplicaServerName] nvarchar(256), [RoleDesc] nvarchar(60),
 [ConnectedStateDesc] nvarchar(60), [SynchronizationHealthDesc] nvarchar(60), [FindingCode] varchar(80))
WHERE [FindingCode] <> ''REPLICA_STATE_ACCEPTABLE'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AvailabilityDeepAnalysis'', ''AVAILABILITY'', ''HIGH'', ''HIGH'', N''DATABASE'',
       [DatabaseName], [FindingCode], CONVERT(decimal(38,4), [PageStatus]),
       CONCAT(N''page repair status='', COALESCE(CONVERT(nvarchar(20), [PageStatus]), N''NULL''),
              N''; error type='', COALESCE(CONVERT(nvarchar(20), [ErrorType]), N''NULL''), N''.''),
       N''Automatische Seitenreparatur ist Einzelevidenz und ersetzt keine Integritätsprüfung.'',
       N''Seitenreparatur-, suspect_pages-, CHECKDB- und Backup-Evidenz gemeinsam prüfen.''
FROM OPENJSON(COALESCE(@Availability, N''{}''), ''$.pageRepair'') WITH
([DatabaseName] sysname, [ErrorType] int, [PageStatus] int, [FindingCode] varchar(80))
WHERE [FindingCode] <> ''PAGE_REPAIR_SUCCEEDED'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AvailabilityDeepAnalysis'', ''AVAILABILITY'', ''HIGH'', ''MEDIUM'', N''DATABASE'',
       [DatabaseName], ''PHYSICAL_SEEDING_FAILURE'', CONVERT(decimal(38,4), [FailureCode]),
       CONCAT(N''seeding state='', COALESCE([CurrentStateDesc], N''NULL''),
              N''; failure code='', [FailureCode], N''.''),
       N''Die DMV zeigt nur aktuell aufbewahrte Seeding-Evidenz.'',
       N''Seedingstatus, Endpoint, Berechtigungen, Speicher und Netzwerk prüfen.''
FROM OPENJSON(COALESCE(@Availability, N''{}''), ''$.seeding'') WITH
([DatabaseName] sysname, [CurrentStateDesc] nvarchar(60), [FailureCode] int)
WHERE COALESCE([FailureCode], 0) <> 0;

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_AgentMonitoringAnalysis'', ''MONITORING'', [Severity], ''MEDIUM'', [ScopeType], [ScopeName],
       [FindingCode], CONVERT(decimal(38,4), [MetricValue]), [Evidence], [EvidenceLimit],
       N''SQL-Agent-Konfiguration mit externem Monitoring und Betriebsprozess abgleichen.''
FROM OPENJSON(COALESCE(@Agent, N''{}''), ''$.findings'') WITH
([Severity] varchar(16), [ScopeType] nvarchar(60), [ScopeName] nvarchar(256), [FindingCode] varchar(100),
 [MetricValue] bigint, [Evidence] nvarchar(1000), [EvidenceLimit] nvarchar(1000));

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_SchemaDesignAnalysis'', ''SCHEMA_DESIGN'', [Severity], ''HIGH'', [ObjectType],
       CONCAT([DatabaseName], N''/'', COALESCE([SchemaName] + N''.'', N''''), [ObjectName]),
       [FindingCode], [MetricValue], [Evidence], [EvidenceLimit],
       N''Workload, Abhängigkeiten und Änderungsrisiko vor DDL separat verifizieren.''
FROM OPENJSON(COALESCE(@Schema, N''{}''), ''$.findings'') WITH
([DatabaseName] sysname, [Severity] varchar(16), [ObjectType] nvarchar(60), [SchemaName] sysname,
 [ObjectName] sysname, [FindingCode] varchar(100), [MetricValue] decimal(38,4),
 [Evidence] nvarchar(1000), [EvidenceLimit] nvarchar(1000));

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_StatisticsDistributionAnalysis'', ''STATISTICS_DISTRIBUTION'', [Severity], [Confidence], N''STATISTICS'',
       CONCAT([DatabaseName],N''/'',[SchemaName],N''.'',[ObjectName],N''/'',[StatisticsName]),
       [FindingCode],[MetricValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck]
FROM OPENJSON(COALESCE(@StatisticsDistribution, N''{}''), ''$.findings'') WITH
([DatabaseName] sysname, [SchemaName] sysname, [ObjectName] sysname, [StatisticsName] sysname,
 [Severity] varchar(16), [Confidence] varchar(16), [FindingCode] varchar(120),
 [MetricValue] decimal(38,4), [Evidence] nvarchar(1000), [EvidenceLimit] nvarchar(1000),
 [RecommendedNextCheck] nvarchar(1000));

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_IntelligentQueryProcessingAnalysis'', ''IQP'', [FindingSeverity], ''HIGH'', N''DATABASE'',
       [DatabaseName], [FindingCode], CONVERT(decimal(38,4), [CompatibilityLevel]),
       CONCAT(N''compatibility level='', [CompatibilityLevel], N''; query store='', [QueryStoreActualStateDesc], N''.''),
       [EvidenceLimit], N''Query-Store-Zustand und beabsichtigtes Compatibility Level prüfen.''
FROM OPENJSON(COALESCE(@Iqp, N''{}''), ''$.databaseState'') WITH
([DatabaseName] sysname, [CompatibilityLevel] int, [QueryStoreActualStateDesc] nvarchar(60),
 [FindingCode] varchar(80), [FindingSeverity] varchar(16), [EvidenceLimit] nvarchar(1000))
WHERE [FindingCode] <> ''IQP_EVIDENCE_AVAILABLE'';

INSERT [#DiagnosticFindings_Findings] ([SourceModule],[Category],[Severity],[Confidence],[ScopeType],[ScopeName],[FindingCode],[EvidenceMetric],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
SELECT N''USP_InternalContentionAnalysis'', ''INTERNAL_CONTENTION'', ''MEDIUM'', ''MEDIUM'', N''LATCH'',
       [LatchClass], ''LATCH_WAIT_DELTA_REVIEW'', CONVERT(decimal(38,4), [WaitTimeMs]),
       CONCAT(N''wait time ms='', [WaitTimeMs], N''; waiting requests='', [WaitingRequests], N''; measurement='', [MeasurementKind], N''.''),
       N''Latchklasse und kurzes Intervall sind noch keine Ursachenfeststellung.'',
       N''Messung wiederholen und mit Workload, Waits und Hot Pages korrelieren.''
FROM OPENJSON(COALESCE(@Contention, N''{}''), ''$.latches'') WITH
([LatchClass] nvarchar(120), [MeasurementKind] varchar(30), [WaitingRequests] bigint, [WaitTimeMs] bigint)
WHERE [WaitTimeMs] >= @ContentionMinWaitMs;';

        BEGIN TRY
            EXEC [sys].[sp_executesql]
                  @ParseSql
                , N'@Integrity nvarchar(max), @Capacity nvarchar(max), @Memory nvarchar(max),
                    @Backup nvarchar(max), @Availability nvarchar(max), @Agent nvarchar(max),
                    @Schema nvarchar(max), @StatisticsDistribution nvarchar(max), @Iqp nvarchar(max), @Contention nvarchar(max),
                    @ContentionMinWaitMs bigint'
                , @Integrity = @IntegrityJson, @Capacity = @CapacityJson, @Memory = @MemoryJson
                , @Backup = @BackupJson, @Availability = @AvailabilityJson, @Agent = @AgentJson
                , @Schema = @SchemaJson, @StatisticsDistribution = @StatisticsDistributionJson
                , @Iqp = @IqpJson, @Contention = @ContentionJson
                , @ContentionMinWaitMs = @ContentionMinWaitMs;
        END TRY
        BEGIN CATCH
            INSERT @ModuleStatus VALUES (11, N'JSON_EVIDENCE_AGGREGATION', 'ERROR_HANDLED', NULL, 1, ERROR_NUMBER(), ERROR_MESSAGE());
        END CATCH;

        IF EXISTS
        (
            SELECT 1 FROM @ModuleStatus
            WHERE [InvocationStatus] NOT IN ('EXECUTED','REUSED_PARENT_RESULT')
               OR COALESCE([IsPartial], 0) = 1
               OR [EvidenceStatus] IN ('DENIED_PERMISSION','ERROR_HANDLED','DATABASE_UNAVAILABLE','UNAVAILABLE_FEATURE')
        )
        BEGIN
            SELECT @StatusCode = 'AVAILABLE_LIMITED', @IsPartial = 1;
            SELECT TOP (1) @ErrorNumber = [ErrorNumber], @ErrorMessage = [ErrorMessage]
            FROM @ModuleStatus
            WHERE [InvocationStatus] NOT IN ('EXECUTED','REUSED_PARENT_RESULT') OR COALESCE([IsPartial], 0) = 1
            ORDER BY [ExecutionOrdinal];
        END
        ELSE IF EXISTS (SELECT 1 FROM [#DiagnosticFindings_Findings])
            SET @StatusCode = 'AVAILABLE_WITH_FINDING';
    END;

    DECLARE @TotalFindingCount bigint = (SELECT COUNT_BIG(*) FROM [#DiagnosticFindings_Findings]);
    DECLARE @PriorityFindingCount bigint =
    (
        SELECT COUNT_BIG(*) FROM [#DiagnosticFindings_Findings]
        WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
              >= CASE @MinimumSeverity WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
    );
    DELETE FROM [#DiagnosticFindings_Findings]
    WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
          < CASE @MinimumSeverity WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END;
    ;WITH [RankedFindings] AS
    (
        SELECT *, ROW_NUMBER() OVER
        (
            ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
                     [FindingOrdinal]
        ) AS [OutputOrdinal]
        FROM [#DiagnosticFindings_Findings]
    )
    DELETE FROM [RankedFindings] WHERE [OutputOrdinal] > @Limit;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'DiagnosticFindings' AS [resultName], 1 AS [schemaVersion], @Now AS [generatedAtUtc],
                    @StatusCode AS [statusCode], @IsPartial AS [isPartial], @MinimumSeverity AS [minimumSeverity],
                    @TotalFindingCount AS [totalFindingCount],
                    @PriorityFindingCount
                    AS [returnedFindingCount]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @FindingsJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#DiagnosticFindings_Findings]
             WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
                   >= CASE @MinimumSeverity WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
             ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
                      [FindingOrdinal] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @ModulesJson nvarchar(max) =
            (SELECT * FROM @ModuleStatus ORDER BY [ExecutionOrdinal] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"findings":', COALESCE(@FindingsJson, N'[]'),
                           N',"modules":', COALESCE(@ModulesJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_DiagnosticFindings' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @TotalFindingCount AS [FindingCount],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Normalisierte Triage über Kindmodul-Evidenz; keine automatische Ursachenfeststellung.' AS [Detail];
        SELECT TOP (@Limit) * FROM [#DiagnosticFindings_Findings]
        WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
              >= CASE @MinimumSeverity WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
                 [FindingOrdinal];
        SELECT * FROM @ModuleStatus ORDER BY [ExecutionOrdinal];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Diagnostische Befunde' AS [Ergebnis], @Now AS [Stand_UTC], @StatusCode AS [Status],
               @MinimumSeverity AS [Mindestprioritaet], @TotalFindingCount AS [Befunde_gesamt],
               @ErrorMessage AS [Hinweis];
        SELECT TOP (@Limit) N'Diagnostischer Befund' AS [Ergebnis], [Severity] AS [Prioritaet],
               [Confidence] AS [Konfidenz], [Category] AS [Kategorie], [ScopeType] AS [Bereichstyp],
               [ScopeName] AS [Bereich], [FindingCode] AS [Befund], [EvidenceMetric] AS [Messwert],
               [Evidence] AS [Evidenz], [EvidenceLimit] AS [Grenze], [RecommendedNextCheck] AS [Naechste_Pruefung]
        FROM [#DiagnosticFindings_Findings]
        WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
              >= CASE @MinimumSeverity WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 2 ELSE 1 END
        ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
                 [FindingOrdinal];
        SELECT N'Befund-Quellmodul' AS [Ergebnis], [ExecutionOrdinal] AS [Reihenfolge],
               [ModuleName] AS [Modul], [InvocationStatus] AS [Aufrufstatus],
               [EvidenceStatus] AS [Evidenzstatus], [IsPartial] AS [Teilweise], [ErrorMessage] AS [Fehler]
        FROM @ModuleStatus ORDER BY [ExecutionOrdinal];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#DiagnosticFindings_Findings'
            , @ResultLabel=N'DiagnosticFindings'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#DiagnosticFindings_Findings'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
