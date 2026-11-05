USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_RunSnapshotCollectionCycle
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Stellt den schedulerneutralen SC-023-Einstieg für genau einen
               leichten Performance-Counter-Sammler und seine persistente
               Evidenz bereit.
Concurrency  : Benannte Session-Applock, Wartezeit 0; Parallelaufrufe lesen
               keine Quelle und enden als SKIPPED_CONCURRENT.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_RunSnapshotCollectionCycle]
      @SchedulerType     varchar(16)    = 'EXTERNAL'
    , @RunEvenIfNotDue   bit            = 0
    , @ResultSetArt      varchar(16)    = 'CONSOLE'
    , @ResultTablesJson  nvarchar(max)  = NULL
    , @JsonErzeugen      bit            = 0
    , @Json              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen    bit            = 1
    , @Hilfe             bit            = 0
    , @CaptureRunIdOut   bigint         = NULL OUTPUT
    , @StatusCodeOut     varchar(40)    = NULL OUTPUT
    , @IsPartialOut      bit            = NULL OUTPUT
    , @ErrorNumberOut    int            = NULL OUTPUT
    , @ErrorMessageOut   nvarchar(2048) = NULL OUTPUT
    , @CollectorCode     varchar(64) = 'PERFORMANCE_COUNTERS'
    , @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    SELECT @CaptureRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    SET @CollectorCode=UPPER(LTRIM(RTRIM(COALESCE(@CollectorCode,''))));
    IF @Hilfe=1 AND @CollectorCode<>'PERFORMANCE_COUNTERS'
    BEGIN
        PRINT N'monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.';
        PRINT N'@SchedulerType: Datentyp varchar(16). MANUAL kennzeichnet einen manuellen Aufruf, EXTERNAL einen extern geplanten Aufruf und SQL_AGENT einen Aufruf durch SQL Server Agent; alle drei nutzen denselben schedulerneutralen Einstieg ohne Sammellogik im Scheduler. Zulässige Werte ausschließlich MANUAL, EXTERNAL, SQL_AGENT. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer wird im normalen Pfad ungültig. Default: ''EXTERNAL''. Der frühe Nicht-Performance-Hilfezweig kehrt vor dieser Validierung zurück.';
        PRINT N'@RunEvenIfNotDue: Datentyp bit. 0 verlangt Fälligkeit; 1 umgeht nur das Collectorintervall, nicht Concurrency, Retention oder Größenbudget. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@ResultSetArt: Datentyp varchar(16). CONSOLE zeigt die priorisierte Lauf-/Modulstatusausgabe; RAW liefert zwei Resultsets (run, modules); TABLE schreibt beide Ergebnisse in zugeordnete lokale Temp-Tabellen; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. PERFORMANCE_COUNTERS unterstützt alle fünf Werte. WAIT_STATS und FILE_IO unterstützen CONSOLE, RAW, TABLE und NONE; JSON als Ausgabeart wird mit 51011 abgewiesen, JSON bleibt dort über @JsonErzeugen optional. Default: ''CONSOLE''.';
        PRINT N'@ResultTablesJson: Datentyp nvarchar(max). Nur bei TABLE: JSON-Objekt mit Textwerten als lokale Temp-Tabellennamen, zulässige Resultnamen run und modules, zum Beispiel N''{"run":"#MyRun","modules":"#MyModules"}''. InternalPrepareResultTables erlaubt das Mapping einer Teilmenge und prüft nicht, dass beide Namen vorkommen; fehlt später ein Ziel, erhält InternalWriteResultTable NULL und der TABLE-Aufruf schlägt mit Fehler 51010 fehl. Daher sind beide Zuordnungen für eine erfolgreiche Run-TABLE-Ausgabe erforderlich. Ziele müssen in derselben Sitzung vorhanden und lokale #Temp-Tabellen sein. Preflight verlangt eine leere lokale Zieltabelle mit genau einer Seed-Spalte; ##, mehr als 116 Zeichen, Präfix #Monitor, unbekannte/duplizierte Resultnamen, doppelte Ziele und Nicht-Textwerte sind unzulässig. Resultnamen sind case-sensitive; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft. Ein fehlendes Ziel wird erst bei der Ausgabe erkannt: Ein Capture kann bereits gespeichert und das erste Ziel bereits beschrieben sein; eine atomare Rücknahme beider Ausgaben ist nicht zugesagt. Bei TABLE ist NULL/leer ungültig; außerhalb TABLE sind NULL/leer/Leerzeichen zulässig, nichtleer ungültig. Default: NULL.';
        PRINT N'@JsonErzeugen: Datentyp bit. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt den JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Json: Datentyp nvarchar(max) OUTPUT. Mit nvarchar(max)-Variablen und OUTPUT zu binden; wird am Eintritt NULL. Bei JsonErzeugen=1 oder ResultSetArt JSON: Objekt mit meta (contractVersion 1, resultName SnapshotCollectionCycle), run als Objekt und modules als Array; NULL-Werte enthalten. Bei frühem RETURN einschließlich Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@PrintMeldungen: Datentyp bit. 1 gibt am Ende für Statuswerte außer AVAILABLE, PARTIAL und SKIPPED_NOT_DUE eine RAISERROR-Meldung severity 10 mit NOWAIT aus; 0 unterdrückt sie. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Hilfe: Datentyp bit. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs sind zuvor initialisiert. Für jeden normalisierten Collectorwert ungleich PERFORMANCE_COUNTERS liegt der frühe Hilfezweig direkt nach der Initialisierung und vor Filter-/Collector-, Transaktions-, Scheduler- und Ausgabemodusvalidierung. PERFORMANCE_COUNTERS erreicht den späteren Hilfezweig erst nach dem Datenbankfiltergate und der Temp-Tabellenanlage, aber vor Scheduler-/Ausgabemodusvalidierung. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@CaptureRunIdOut: Datentyp bigint OUTPUT. bigint-Variable mit OUTPUT; initial NULL, enthält erzeugte CaptureRun-ID, sonst NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, später tatsächlicher Status. Hilfe liefert AVAILABLE, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT; initial 0, später gemäß Ablaufstatus. Hilfe liefert 0, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT; initial NULL, Fehlernummer wenn gesetzt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. OUTPUT-Parameter nvarchar(2048), mit einer nvarchar(2048)-Variablen und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL; enthält gegebenenfalls die Fehlermeldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@CollectorCode: Datentyp varchar(64). Ein einzelner Code: PERFORMANCE_COUNTERS erfasst Performance Counter über USP_PerformanceCounters mit SampleSeconds=0; WAIT_STATS liest den vollständigen nativen Waitcache; FILE_IO liest den vollständigen nativen Datei-I/O-Cache und verwendet die drei Datenbankfilter. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer ist im normalen Ablauf ungültig. WAIT_STATS und FILE_IO verlangen @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; der Legacy-Pfad PERFORMANCE_COUNTERS hat dieses vorgeschaltete Caller-Gate nicht. Default: ''PERFORMANCE_COUNTERS''.';
        PRINT N'@DatabaseNames: Datentyp nvarchar(max). Nur FILE_IO, sonst werden wirksame Filterwerte mit 51011 abgewiesen. NULL/leer/nur Leerzeichen bedeutet keine exakte Liste. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innerhalb geklammerter Namen. Elementränder getrimmt; leere/fehlerhaft geklammerte Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten oder PARSENAME-Name über 128 Zeichen ungültig. Namen schränken Auswahl ein; Duplikate werden case-sensitive erkannt. Eine wirksame Liste ist nicht mit nicht-NULL Pattern kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung wird erst nach erfolgreicher Enabled-, Target- und Policyprüfung erreicht; ein voriger Abbruch bestätigt die Filtersyntax nicht.';
        PRINT N'@SystemdatenbankenEinbeziehen: Datentyp bit. Nur FILE_IO: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Für PERFORMANCE_COUNTERS und WAIT_STATS ist nur 0 zulässig. NULL ist für alle Collectorwerte ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ein früher Nicht-Performance-Hilfeaufruf kehrt vor dieser Prüfung zurück.';
        PRINT N'@DatabaseNamePattern: Datentyp nvarchar(4000). Nur FILE_IO; sonst werden wirksame Werte mit 51011 abgewiesen. NULL bedeutet kein Pattern; nicht-NULL wird außen getrimmt, leer oder nach Präfixentfernung ohne Inhalt (like:, regex:, regexi:) ungültig. Zulässig sind LIKE-Muster mit %, _ und [...] sowie Präfixe like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung, kein erneutes Trimmen nach Präfixentfernung. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. regex: hat Flag c, regexi: Flag i; Regexsyntax wird nicht vorab geprüft und benötigt SQL Server 2025 plus Compatibility Level mindestens 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Nicht-NULL Pattern ist nicht mit wirksamer Namensliste kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung folgt erst auf Enabled-, Target- und Policyprüfung.';
        PRINT N'Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.';
        PRINT N'Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''PERFORMANCE_COUNTERS'';';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''WAIT_STATS'';';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''FILE_IO'';';
        RETURN;
    END;
    IF (@CollectorCode<>'FILE_IO' AND
        (NULLIF(LTRIM(RTRIM(@DatabaseNames)),N'') IS NOT NULL OR @SystemdatenbankenEinbeziehen IS NULL
         OR @SystemdatenbankenEinbeziehen<>0 OR NULLIF(LTRIM(RTRIM(@DatabaseNamePattern)),N'') IS NOT NULL))
       OR (@CollectorCode='FILE_IO' AND @SystemdatenbankenEinbeziehen IS NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
          @ErrorMessageOut=N'Die drei Datenbankfilter gelten ausschließlich für FILE_IO; der Systemdatenbankparameter benötigt 0 oder 1.';
        RETURN 51011;
    END;
    IF @CollectorCode NOT IN('PERFORMANCE_COUNTERS','WAIT_STATS','FILE_IO')
       OR (@CollectorCode IN('WAIT_STATS','FILE_IO') AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0))
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der neue Waitpfad benötigt einen gültigen Collector ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))))='JSON'
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Ausgabeartwert JSON gehört zum Legacy-Collector. WAIT_STATS verwendet optionalen JSON-OUTPUT.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    CREATE TABLE [#RunSnapshotCollectionCycle_Run]
    (
          [CaptureRunId] bigint NULL
        , [TargetDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CollectorCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchedulerType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartedAtUtc] datetime2(3) NULL
        , [EndedAtUtc] datetime2(3) NULL
        , [SqlServerStartTimeUtc] datetime2(3) NULL
        , [ResetEpochId] uniqueidentifier NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [MetricSampleCount] bigint NOT NULL
        , [PayloadCount] bigint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#RunSnapshotCollectionCycle_Modules]
    (
          [ModuleStatusId] bigint NULL
        , [CaptureRunId] bigint NULL
        , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#RunSnapshotCollectionCycle_TableMap]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);

    SET @Json=NULL;
    SELECT @CaptureRunIdOut=NULL,@StatusCodeOut='AVAILABLE',@IsPartialOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.';
        PRINT N'@SchedulerType: Datentyp varchar(16). MANUAL kennzeichnet einen manuellen Aufruf, EXTERNAL einen extern geplanten Aufruf und SQL_AGENT einen Aufruf durch SQL Server Agent; alle drei nutzen denselben schedulerneutralen Einstieg ohne Sammellogik im Scheduler. Zulässige Werte ausschließlich MANUAL, EXTERNAL, SQL_AGENT. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer wird im normalen Pfad ungültig. Default: ''EXTERNAL''. Der frühe Nicht-Performance-Hilfezweig kehrt vor dieser Validierung zurück.';
        PRINT N'@RunEvenIfNotDue: Datentyp bit. 0 verlangt Fälligkeit; 1 umgeht nur das Collectorintervall, nicht Concurrency, Retention oder Größenbudget. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@ResultSetArt: Datentyp varchar(16). CONSOLE zeigt die priorisierte Lauf-/Modulstatusausgabe; RAW liefert zwei Resultsets (run, modules); TABLE schreibt beide Ergebnisse in zugeordnete lokale Temp-Tabellen; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. PERFORMANCE_COUNTERS unterstützt alle fünf Werte. WAIT_STATS und FILE_IO unterstützen CONSOLE, RAW, TABLE und NONE; JSON als Ausgabeart wird mit 51011 abgewiesen, JSON bleibt dort über @JsonErzeugen optional. Default: ''CONSOLE''.';
        PRINT N'@ResultTablesJson: Datentyp nvarchar(max). Nur bei TABLE: JSON-Objekt mit Textwerten als lokale Temp-Tabellennamen, zulässige Resultnamen run und modules, zum Beispiel N''{"run":"#MyRun","modules":"#MyModules"}''. InternalPrepareResultTables erlaubt das Mapping einer Teilmenge und prüft nicht, dass beide Namen vorkommen; fehlt später ein Ziel, erhält InternalWriteResultTable NULL und der TABLE-Aufruf schlägt mit Fehler 51010 fehl. Daher sind beide Zuordnungen für eine erfolgreiche Run-TABLE-Ausgabe erforderlich. Ziele müssen in derselben Sitzung vorhanden und lokale #Temp-Tabellen sein. Preflight verlangt eine leere lokale Zieltabelle mit genau einer Seed-Spalte; ##, mehr als 116 Zeichen, Präfix #Monitor, unbekannte/duplizierte Resultnamen, doppelte Ziele und Nicht-Textwerte sind unzulässig. Resultnamen sind case-sensitive; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft. Ein fehlendes Ziel wird erst bei der Ausgabe erkannt: Ein Capture kann bereits gespeichert und das erste Ziel bereits beschrieben sein; eine atomare Rücknahme beider Ausgaben ist nicht zugesagt. Bei TABLE ist NULL/leer ungültig; außerhalb TABLE sind NULL/leer/Leerzeichen zulässig, nichtleer ungültig. Default: NULL.';
        PRINT N'@JsonErzeugen: Datentyp bit. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt den JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Json: Datentyp nvarchar(max) OUTPUT. Mit nvarchar(max)-Variablen und OUTPUT zu binden; wird am Eintritt NULL. Bei JsonErzeugen=1 oder ResultSetArt JSON: Objekt mit meta (contractVersion 1, resultName SnapshotCollectionCycle), run als Objekt und modules als Array; NULL-Werte enthalten. Bei frühem RETURN einschließlich Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@PrintMeldungen: Datentyp bit. 1 gibt am Ende für Statuswerte außer AVAILABLE, PARTIAL und SKIPPED_NOT_DUE eine RAISERROR-Meldung severity 10 mit NOWAIT aus; 0 unterdrückt sie. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@Hilfe: Datentyp bit. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs sind zuvor initialisiert. Für jeden normalisierten Collectorwert ungleich PERFORMANCE_COUNTERS liegt der frühe Hilfezweig direkt nach der Initialisierung und vor Filter-/Collector-, Transaktions-, Scheduler- und Ausgabemodusvalidierung. PERFORMANCE_COUNTERS erreicht den späteren Hilfezweig erst nach dem Datenbankfiltergate und der Temp-Tabellenanlage, aber vor Scheduler-/Ausgabemodusvalidierung. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.';
        PRINT N'@CaptureRunIdOut: Datentyp bigint OUTPUT. bigint-Variable mit OUTPUT; initial NULL, enthält erzeugte CaptureRun-ID, sonst NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, später tatsächlicher Status. Hilfe liefert AVAILABLE, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT; initial 0, später gemäß Ablaufstatus. Hilfe liefert 0, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT; initial NULL, Fehlernummer wenn gesetzt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. OUTPUT-Parameter nvarchar(2048), mit einer nvarchar(2048)-Variablen und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL; enthält gegebenenfalls die Fehlermeldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.';
        PRINT N'@CollectorCode: Datentyp varchar(64). Ein einzelner Code: PERFORMANCE_COUNTERS erfasst Performance Counter über USP_PerformanceCounters mit SampleSeconds=0; WAIT_STATS liest den vollständigen nativen Waitcache; FILE_IO liest den vollständigen nativen Datei-I/O-Cache und verwendet die drei Datenbankfilter. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer ist im normalen Ablauf ungültig. WAIT_STATS und FILE_IO verlangen @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; der Legacy-Pfad PERFORMANCE_COUNTERS hat dieses vorgeschaltete Caller-Gate nicht. Default: ''PERFORMANCE_COUNTERS''.';
        PRINT N'@DatabaseNames: Datentyp nvarchar(max). Nur FILE_IO, sonst werden wirksame Filterwerte mit 51011 abgewiesen. NULL/leer/nur Leerzeichen bedeutet keine exakte Liste. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innerhalb geklammerter Namen. Elementränder getrimmt; leere/fehlerhaft geklammerte Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten oder PARSENAME-Name über 128 Zeichen ungültig. Namen schränken Auswahl ein; Duplikate werden case-sensitive erkannt. Eine wirksame Liste ist nicht mit nicht-NULL Pattern kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung wird erst nach erfolgreicher Enabled-, Target- und Policyprüfung erreicht; ein voriger Abbruch bestätigt die Filtersyntax nicht.';
        PRINT N'@SystemdatenbankenEinbeziehen: Datentyp bit. Nur FILE_IO: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Für PERFORMANCE_COUNTERS und WAIT_STATS ist nur 0 zulässig. NULL ist für alle Collectorwerte ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ein früher Nicht-Performance-Hilfeaufruf kehrt vor dieser Prüfung zurück.';
        PRINT N'@DatabaseNamePattern: Datentyp nvarchar(4000). Nur FILE_IO; sonst werden wirksame Werte mit 51011 abgewiesen. NULL bedeutet kein Pattern; nicht-NULL wird außen getrimmt, leer oder nach Präfixentfernung ohne Inhalt (like:, regex:, regexi:) ungültig. Zulässig sind LIKE-Muster mit %, _ und [...] sowie Präfixe like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung, kein erneutes Trimmen nach Präfixentfernung. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. regex: hat Flag c, regexi: Flag i; Regexsyntax wird nicht vorab geprüft und benötigt SQL Server 2025 plus Compatibility Level mindestens 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Nicht-NULL Pattern ist nicht mit wirksamer Namensliste kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung folgt erst auf Enabled-, Target- und Policyprüfung.';
        PRINT N'Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.';
        PRINT N'Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1;';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''PERFORMANCE_COUNTERS'';';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''WAIT_STATS'';';
        PRINT N'EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode=''FILE_IO'';';
        RETURN;
    END;

    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
            @TableStatus varchar(40),@TableMessage nvarchar(2048),
            @RunTarget sysname,@ModulesTarget sysname;
    SET @SchedulerType=UPPER(LTRIM(RTRIM(COALESCE(@SchedulerType,''))));

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','JSON','NONE')
       OR @SchedulerType NOT IN ('MANUAL','EXTERNAL','SQL_AGENT')
       OR @RunEvenIfNotDue IS NULL OR @RunEvenIfNotDue NOT IN (0,1)
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorMessageOut=N'Ungültiger Scheduler-, Ausgabe- oder Force-Parameter.';
        GOTO EmitResults;
    END;

    IF @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
             @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'run|modules',
             @MappingTable=N'#RunSnapshotCollectionCycle_TableMap',
             @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=1;
        SELECT @RunTarget=MAX(CASE WHEN [ResultName]=N'run' THEN [TargetTable] END),
               @ModulesTarget=MAX(CASE WHEN [ResultName]=N'modules' THEN [TargetTable] END)
        FROM [#RunSnapshotCollectionCycle_TableMap];
    END;

    DECLARE @TargetDatabaseName sysname,@IsEnabled bit,@DefaultSchedulerType varchar(16),
            @TargetQuoted nvarchar(258),@SourceDatabaseName sysname,
            @Sql nvarchar(max),@AppLockResult int,@AppLockHeld bit=0,
            @ShouldCollect bit=0,@PrepareStatus varchar(40),@PrepareMessage nvarchar(2048),
            @CollectorJson nvarchar(max),@CollectorStatus varchar(40),@CollectorPartial bit,
            @CollectorError int,@CollectorMessage nvarchar(2048),@MaxRows int,
            @PurgeRunId bigint,@PurgeStatus varchar(40),@BudgetExceeded bit,
            @PurgeError int,@PurgeMessage nvarchar(2048);

    IF @CollectorCode='FILE_IO'
    BEGIN
        EXEC [monitor].[InternalRunSnapshotFileIOCycle]
         @SchedulerType=@SchedulerType,@RunEvenIfNotDue=@RunEvenIfNotDue,
         @CaptureRunIdOut=@CaptureRunIdOut OUTPUT,@TargetDatabaseNameOut=@TargetDatabaseName OUTPUT,
         @StatusCodeOut=@StatusCodeOut OUTPUT,@IsPartialOut=@IsPartialOut OUTPUT,
         @ErrorNumberOut=@ErrorNumberOut OUTPUT,@ErrorMessageOut=@ErrorMessageOut OUTPUT,
         @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern;
        GOTO EmitResults;
    END;
    IF @CollectorCode='WAIT_STATS'
    BEGIN
        EXEC [monitor].[InternalRunSnapshotWaitStatsCycle]
         @SchedulerType=@SchedulerType,@RunEvenIfNotDue=@RunEvenIfNotDue,
         @CaptureRunIdOut=@CaptureRunIdOut OUTPUT,@TargetDatabaseNameOut=@TargetDatabaseName OUTPUT,
         @StatusCodeOut=@StatusCodeOut OUTPUT,@IsPartialOut=@IsPartialOut OUTPUT,
         @ErrorNumberOut=@ErrorNumberOut OUTPUT,@ErrorMessageOut=@ErrorMessageOut OUTPUT;
        GOTO EmitResults;
    END;

    SELECT @TargetDatabaseName=[TargetDatabaseName],@IsEnabled=[IsEnabled],
           @DefaultSchedulerType=[DefaultSchedulerType]
    FROM [monitor].[SnapshotTargetConfiguration]
    WHERE [ConfigurationId]=1;

    IF COALESCE(@IsEnabled,0)<>1
    BEGIN
        SELECT @StatusCodeOut='DISABLED',@IsPartialOut=1,
               @ErrorMessageOut=N'Das optionale Snapshotpaket ist nicht aktiviert.';
        GOTO EmitResults;
    END;

    SELECT @SourceDatabaseName=[name]
    FROM [master].[sys].[databases] WITH (NOLOCK)
    WHERE [database_id]=DB_ID();

    IF NOT EXISTS
    (
        SELECT 1
        FROM [master].[sys].[databases] WITH (NOLOCK)
        WHERE [name]=@TargetDatabaseName AND [state]=0 AND [is_read_only]=0
    )
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,
               @ErrorMessageOut=N'Die konfigurierte Snapshot-Datenbank ist nicht online und schreibbar.';
        GOTO EmitResults;
    END;
    SET @TargetQuoted=QUOTENAME(@TargetDatabaseName);

    EXEC @AppLockResult=[sys].[sp_getapplock]
         @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockMode='Exclusive',
         @LockOwner='Session',@LockTimeout=0,@DbPrincipal=N'public';
    IF @AppLockResult<0
    BEGIN
        SELECT @StatusCodeOut='SKIPPED_CONCURRENT',@IsPartialOut=1,
               @ErrorMessageOut=N'Ein anderer Snapshotlauf oder Purge besitzt bereits die Paket-Applock.';
        GOTO EmitResults;
    END;
    SET @AppLockHeld=1;

    BEGIN TRY
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPurgeExpiredData]
             @MaxBatches=10,@Force=0,@PurgeRunIdOut=@r OUTPUT,@StatusCodeOut=@s OUTPUT,
             @BudgetExceededOut=@b OUTPUT,@ErrorNumberOut=@e OUTPUT,@ErrorMessageOut=@m OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
             N'@r bigint OUTPUT,@s varchar(40) OUTPUT,@b bit OUTPUT,@e int OUTPUT,@m nvarchar(2048) OUTPUT',
             @r=@PurgeRunId OUTPUT,@s=@PurgeStatus OUTPUT,@b=@BudgetExceeded OUTPUT,
             @e=@PurgeError OUTPUT,@m=@PurgeMessage OUTPUT;

        SET @Sql=N'SELECT @MaxRows=[MaxRows] FROM '+@TargetQuoted+N'.[snapshot].[CollectorPolicy] WHERE [CollectorCode]=''PERFORMANCE_COUNTERS'';
EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
     @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,
     @CaptureRunIdOut=@RunId OUTPUT,@ShouldCollectOut=@Collect OUTPUT,
     @StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
             N'@Source sysname,@Scheduler varchar(16),@Force bit,@MaxRows int OUTPUT,@RunId bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT',
             @Source=@SourceDatabaseName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,
             @MaxRows=@MaxRows OUTPUT,@RunId=@CaptureRunIdOut OUTPUT,@Collect=@ShouldCollect OUTPUT,
             @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT;

        IF @ShouldCollect=1
        BEGIN
            EXEC [monitor].[USP_PerformanceCounters]
                 @SampleSeconds=0,@MaxZeilen=@MaxRows,@ResultSetArt='NONE',
                 @JsonErzeugen=1,@Json=@CollectorJson OUTPUT,@PrintMeldungen=0,
                 @StatusCodeOut=@CollectorStatus OUTPUT,@IsPartialOut=@CollectorPartial OUTPUT,
                 @ErrorNumberOut=@CollectorError OUTPUT,@ErrorMessageOut=@CollectorMessage OUTPUT;

            SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalCompletePerformanceCounterCycle]
                 @CaptureRunId=@RunId,@CollectorJson=@Json,@SourceStatusCode=@SourceStatus,
                 @SourceIsPartial=@SourcePartial,@SourceErrorNumber=@SourceError,
                 @SourceErrorMessage=@SourceMessage,@StatusCodeOut=@Status OUTPUT,
                 @IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,
                 @ErrorMessageOut=@Message OUTPUT;';
            EXEC [sys].[sp_executesql] @Sql,
                 N'@RunId bigint,@Json nvarchar(max),@SourceStatus varchar(40),@SourcePartial bit,@SourceError int,@SourceMessage nvarchar(2048),@Status varchar(40) OUTPUT,@Partial bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
                 @RunId=@CaptureRunIdOut,@Json=@CollectorJson,@SourceStatus=@CollectorStatus,
                 @SourcePartial=@CollectorPartial,@SourceError=@CollectorError,@SourceMessage=@CollectorMessage,
                 @Status=@StatusCodeOut OUTPUT,@Partial=@IsPartialOut OUTPUT,
                 @Error=@ErrorNumberOut OUTPUT,@Message=@ErrorMessageOut OUTPUT;

            IF @PurgeStatus IN ('DENIED_PERMISSION','ERROR_HANDLED') AND @StatusCodeOut='AVAILABLE'
                SELECT @StatusCodeOut='PARTIAL',@IsPartialOut=1,
                       @ErrorMessageOut=N'Die Messung wurde gespeichert; der vorgelagerte Retentionlauf war partiell.';

            SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalFinalizeCollectionCycle]
                 @CaptureRunId=@RunId,@StatusCode=@Status,@IsPartial=@Partial,
                 @ErrorNumber=@Error,@ErrorMessage=@Message;';
            EXEC [sys].[sp_executesql] @Sql,
                 N'@RunId bigint,@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048)',
                 @RunId=@CaptureRunIdOut,@Status=@StatusCodeOut,@Partial=@IsPartialOut,
                 @Error=@ErrorNumberOut,@Message=@ErrorMessageOut;
        END
        ELSE
            SELECT @StatusCodeOut=@PrepareStatus,@IsPartialOut=1,
                   @ErrorMessageOut=@PrepareMessage;

        SET @Sql=N'INSERT [#RunSnapshotCollectionCycle_Run]
([CaptureRunId],[TargetDatabaseName],[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
SELECT [CaptureRunId],@Target,[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage]
FROM '+@TargetQuoted+N'.[snapshot].[CaptureRun] WHERE [CaptureRunId]=@RunId;
INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
SELECT [ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
FROM '+@TargetQuoted+N'.[snapshot].[ModuleStatus] WHERE [CaptureRunId]=@RunId;';
        EXEC [sys].[sp_executesql] @Sql,N'@Target sysname,@RunId bigint',@Target=@TargetDatabaseName,@RunId=@CaptureRunIdOut;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        IF @CaptureRunIdOut IS NOT NULL
        BEGIN TRY
            SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalFinalizeCollectionCycle]
                 @CaptureRunId=@RunId,@StatusCode=@Status,@IsPartial=1,
                 @ErrorNumber=@Error,@ErrorMessage=@Message;';
            EXEC [sys].[sp_executesql] @Sql,
                 N'@RunId bigint,@Status varchar(40),@Error int,@Message nvarchar(2048)',
                 @RunId=@CaptureRunIdOut,@Status=@StatusCodeOut,@Error=@ErrorNumberOut,@Message=@ErrorMessageOut;
        END TRY
        BEGIN CATCH
        END CATCH;
    END CATCH;

    IF @AppLockHeld=1
    BEGIN
        EXEC [sys].[sp_releaseapplock]
             @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockOwner='Session',@DbPrincipal=N'public';
        SET @AppLockHeld=0;
    END;

EmitResults:
    IF @CollectorCode IN('WAIT_STATS','FILE_IO') AND @CaptureRunIdOut IS NULL AND NOT EXISTS(SELECT 1 FROM [#RunSnapshotCollectionCycle_Run])
        INSERT [#RunSnapshotCollectionCycle_Run]
        ([CaptureRunId],[TargetDatabaseName],[CollectorCode],[SchedulerType],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
        VALUES(NULL,@TargetDatabaseName,@CollectorCode,@SchedulerType,@StatusCodeOut,COALESCE(@IsPartialOut,1),0,0,@ErrorNumberOut,@ErrorMessageOut);
    IF @CollectorCode='PERFORMANCE_COUNTERS' AND NOT EXISTS (SELECT 1 FROM [#RunSnapshotCollectionCycle_Run])
        INSERT [#RunSnapshotCollectionCycle_Run]
        ([CaptureRunId],[TargetDatabaseName],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
        VALUES (@CaptureRunIdOut,@TargetDatabaseName,@StatusCodeOut,COALESCE(@IsPartialOut,1),0,0,@ErrorNumberOut,@ErrorMessageOut);

    IF @JsonErzeugen=1 OR @OutputMode='JSON'
    BEGIN
        DECLARE @RunJson nvarchar(max)=(SELECT * FROM [#RunSnapshotCollectionCycle_Run] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
                @ModulesJson nvarchar(max)=(SELECT * FROM [#RunSnapshotCollectionCycle_Modules] ORDER BY [ModuleStatusId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT(N'{"meta":{"contractVersion":1,"resultName":"SnapshotCollectionCycle"},"run":',COALESCE(@RunJson,N'{}'),N',"modules":',COALESCE(@ModulesJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#RunSnapshotCollectionCycle_Run];
        SELECT * FROM [#RunSnapshotCollectionCycle_Modules] ORDER BY [ModuleStatusId];
    END
    ELSE IF @OutputMode='CONSOLE'
    BEGIN
        DECLARE @RunEmptyMessage nvarchar(1000)=CASE WHEN @CollectorCode IN('WAIT_STATS','FILE_IO') AND @CaptureRunIdOut IS NOT NULL
          THEN N'Runprojektion nicht verfügbar; die Laufkennung steht im OUTPUT.' ELSE N'Kein Snapshotlauf' END;
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#RunSnapshotCollectionCycle_Run',
             @ResultLabel=N'Snapshot Collection Cycle',@EmptyMessage=@RunEmptyMessage,
             @StatusCode=@StatusCodeOut,@StatusMessage=@ErrorMessageOut;
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#RunSnapshotCollectionCycle_Modules',
             @ResultLabel=N'Snapshot Module Status',@EmptyMessage=N'Keine Modulstatuszeile',
             @StatusCode=@StatusCodeOut,@StatusMessage=@ErrorMessageOut;
    END
    ELSE IF @OutputMode='TABLE'
    BEGIN
        EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#RunSnapshotCollectionCycle_Run',@TargetTable=@RunTarget,@ThrowOnError=1;
        EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#RunSnapshotCollectionCycle_Modules',@TargetTable=@ModulesTarget,@ThrowOnError=1;
    END;

    IF @PrintMeldungen=1 AND @StatusCodeOut NOT IN ('AVAILABLE','PARTIAL','SKIPPED_NOT_DUE')
    BEGIN
        DECLARE @PrintMessage nvarchar(2048)=COALESCE(@ErrorMessageOut,CONVERT(nvarchar(2048),@StatusCodeOut));
        RAISERROR(N'USP_RunSnapshotCollectionCycle: %s',10,1,@PrintMessage) WITH NOWAIT;
    END;
END;
GO
