USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ClrAnalysis
Version      : 1.0.0
Stand        : 2026-07-22
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert SQL-CLR-Konfiguration, benutzerdefinierte Assemblies,
               Module, Abhängigkeiten, Host Properties, AppDomains, geladene
               Assemblies, CLR Tasks, aktive Requests, Speicher und Counter.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.configurations, sys.databases, sys.assemblies,
               sys.assembly_modules, sys.assembly_references,
               sys.assembly_types, sys.dm_clr_properties,
               sys.dm_clr_appdomains, sys.dm_clr_loaded_assemblies,
               sys.dm_clr_tasks, sys.dm_os_tasks, sys.dm_exec_requests,
               sys.dm_exec_sessions, sys.dm_os_memory_clerks,
               sys.dm_os_performance_counters und optional
               sys.trusted_assemblies.
Datenschutz  : Liest keine Assembly-Binärinhalte, Hashes, Moduldefinitionen,
               SQL-Texte oder Pläne. Principal- und Sitzungskontext sind
               getrennte Opt-ins.
Methodik     : Jede Server-DMV wird einmal je Messpunkt materialisiert.
               Geladene Assemblies werden über AppDomain-Datenbank und
               assembly_id vorsichtig mit sichtbaren Katalogzeilen verbunden.
Grenzen      : assembly_id ist nur innerhalb einer Datenbank eindeutig. Ohne
               Binärhash ist keine exakte Zuordnung zu trusted assemblies
               möglich; die Analyse behauptet daher keinen Trustnachweis.
Kosten       : MEDIUM; Modul- und Dependency-Kataloge skalieren mit der Zahl
               sichtbarer CLR-Objekte. Sampling wartet höchstens 60 Sekunden.
Nebenwirkung : Rein lesend; aktiviert CLR nicht und lädt keine Assembly.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ClrAnalysis]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @AssemblyNames                    nvarchar(max)  = NULL
    , @AssemblyNamePattern              nvarchar(4000) = NULL
    , @SampleSeconds                    tinyint         = 0
    , @MitModulzuordnung                bit             = 1
    , @MitBerechtigungsanalyse          bit             = 0
    , @MitSitzungskontext               bit             = 0
    , @NurProblematisch                 bit             = 0
    , @MaxZeilen                        int             = 100
    , @LockTimeoutMs                    int             = 0
    , @ResultSetArt                     varchar(16)     = 'CONSOLE'
    , @ResultTablesJson                 nvarchar(max)   = NULL
    , @JsonErzeugen                     bit             = 0
    , @Json                             nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                   bit             = 1
    , @Hilfe                            bit             = 0
    , @StatusCodeOut                    varchar(40)     = NULL OUTPUT
    , @IsPartialOut                     bit             = NULL OUTPUT
    , @ErrorNumberOut                   int             = NULL OUTPUT
    , @ErrorMessageOut                  nvarchar(2048)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE [#ClrAnalysis_Findings]
    (
          [FindingOrdinal] bigint NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    SET @Json=NULL;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(100);
    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @MeasurementStartUtc datetime2(3)=NULL,@MeasurementEndUtc datetime2(3)=NULL;
    DECLARE @Major int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @HostPlatform nvarchar(60)=TRY_CONVERT(nvarchar(60),SERVERPROPERTY(N'HostPlatform'));
    DECLARE @OutputModeRequested varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @OutputMode varchar(16)=@OutputModeRequested;
    DECLARE @TableResultRequested bit=CONVERT(bit,CASE WHEN @OutputModeRequested='TABLE' THEN 1 ELSE 0 END);
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputModeRequested='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableTarget sysname=NULL;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0;
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@PrintMessage nvarchar(2048)=NULL;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                               THEN CONVERT(bigint,9223372036854775807)
                               WHEN @MaxZeilen<0 THEN CONVERT(bigint,0)
                               ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @RequiredPerformancePermission nvarchar(128)=CASE WHEN COALESCE(@Major,0)>=16 THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ClrAnalysis';
        PRINT N'Die Analyseinventur erstellt keine CLR-Assembly, aktiviert CLR nicht und führt keine CLR-Funktion aus; Installation und Betrieb von Analyze setzen weder CLR noch eine LLM-Runtime, Netzwerkverbindung oder LLM-Berechtigungen voraus.';
        PRINT N'Die Procedure erfasst ausschließlich sichtbare SQL-CLR-Konfiguration, Katalogmetadaten und aktuelle Host-/Counterevidenz; sie lädt oder führt keine Assembly aus und aktiviert CLR nicht.';
        PRINT N'@MitModulzuordnung=1 ergänzt sichtbare Module, direkte Assemblyreferenzen und CLR-Typen; Moduldefinitionen und Binärinhalte bleiben ausgeschlossen.';
        PRINT N'@MitBerechtigungsanalyse=1 fordert den getrennten CATALOG_DEEP-Pfad für Owner, EXECUTE-AS-Principal und Trust-Zeilenanzahl an; @MitSitzungskontext=1 ergänzt Login, Host und Programm aktiver Managed-Code-Requests.';
        PRINT N'@SampleSeconds=0 liest Counter-Snapshots; Werte 1 bis 60 warten auf den zweiten Countermesspunkt und interpretieren Deltas nur bei passendem Typ und gültiger Basis.';
        PRINT N'@ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE; JSON-Erzeugung ist unabhängig davon und TABLE exportiert ausschließlich findings.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL, N'''' und nur äußere Leerzeichen bedeuten keine explizite Datenbankliste. Eine nichtleere Eingabe ist eine Pipe-Liste einteiliger SQL-Datenbanknamen: | trennt außerhalb eckiger Klammern, | darin bleibt Inhalt, ]] maskiert ] und Elementränder werden getrimmt. Leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, mehrteilige oder ungültige SQL-Namen und Namen über 128 Zeichen werden abgelehnt. Duplikate bleiben parserseitig erhalten; Kandidaten werden nach CS_AS-Namen zusammengeführt. Pattern und wirksame explizite Liste sind gegenseitig ausschließend. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt Systemdatenbanken aus; 1 erlaubt ihre Aufnahme, sofern die übrige Auswahl sie erfasst. NULL ist ungültig. Das Flag vergibt weder Zugriff noch ersetzt es CLR_CURRENT-Gruppenpolicy oder High-Impact-Bestätigung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfix-Großschreibung entfernt, der Inhalt danach nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Syntax, auf Datenbanknamen CS_AS angewendet. regex: nutzt Flag c, regexi: Flag i; beide erfordern SQL Server 2025 und Compatibility Level 170 in Framework- und jeder Zieldatenbank. Leer- oder nur Leerraumwerte sowie leeres Präfixergebnis wie like: sind ungültig. Nichtleere wirksame DatabaseNames schließen das Pattern aus. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@HighImpactConfirmed bit=0; Default: 0. 0 bestätigt keinen High-Impact-Pfad; 1 ist die ausdrückliche Bestätigung, falls die wirksame Policy sie für die Analyseklasse verlangt. NULL ist ungültig. Das Bit ist keine Berechtigung und hebt Gruppenpolicy nicht auf. Basiskandidaten laufen über CLR_CURRENT; Owner-/Principal-/Trustanalyse verlangt zusätzlich CATALOG_DEEP und dessen Policy. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@AssemblyNames nvarchar(max)=NULL; Default: NULL. NULL bedeutet kein Assemblyfilter. Jede nicht-NULL-Eingabe muss eine bracket-aware Pipe-Liste gültiger einzelner SQL-Namen enthalten: | trennt außerhalb [...], ]] maskiert ], Segmentränder werden getrimmt. Exakter Leerstring, Leerraum, leere Elemente, ungültige Klammerung, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige oder mehrteilige SQL-Namen und Namen über 128 Zeichen führen zu INVALID_PARAMETER. Namen landen unverändert in einer CS_AS-Primärschlüsselspalte; ein exakt doppeltes Element kann daher beim Einfügen einen Fehler auslösen, der vom äußeren CATCH als ERROR_HANDLED gemeldet wird. Mit AssemblyNamePattern ist die Eingabe ungültig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@AssemblyNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Filter. Äußerer Leerraum wird entfernt; regexi:, regex: und like: werden ohne Beachtung der Präfixschreibung erkannt, der Rest nicht erneut getrimmt. Ohne Präfix oder mit like: gilt SQL-LIKE-Matching, CS_AS. regex: nutzt Flag c, regexi: Flag i und beide brauchen SQL Server 2025 sowie Compatibility Level 170 in Framework- und Zieldatenbank. Leerer Wert oder leeres Präfixergebnis wie like: ist ungültig; Regex-Syntax wird nicht vorgeprüft. Zusammen mit AssemblyNames unzulässig; sonst wirkt es auf benutzerdefinierte Assemblies im ausgewählten Datenbankscope. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SampleSeconds tinyint=0; Default: 0. 0 liest Counterpunkt T1; Delta-Counter liefern SAMPLE_REQUIRED_FOR_DELTA_METRIC. Ganzzahlwerte 1 bis 60 warten mit WAITFOR DELAY auf T2. Die effektive Dauer basiert auf den tatsächlichen UTC-Lesezeiten und DATEDIFF_BIG in Mikrosekunden, nicht auf der angeforderten Sollzeit. Typen 272696320 und 272696576 liefern Zählerdelta je tatsächlicher Sekunde. Typ 537003264 liefert 100 mal Zählerdelta/Basisdelta; 1073874176 liefert Zählerdelta/Basisdelta. Beide Basistypen brauchen positives Sampling sowie vorhandene, steigende Basiswerte; diese Formeln teilen nicht durch Zeit. Sinkender Counter ergibt COUNTER_RESET_DURING_SAMPLE; Basistypen zusätzlich BASE_COUNTER_MISSING, BASE_COUNTER_RESET_DURING_SAMPLE oder BASE_COUNTER_DELTA_ZERO. Bei fehlendem T2 infolge isoliertem Quellenfehler wird T1 als Gegenwert verwendet, also entsteht kein echtes Delta. Unbekannte Typen sind RAW_UNINTERPRETED. NULL und Werte über 60 sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitModulzuordnung bit=1; Default: 1. 0 überspringt sichtbare CLR-Module, direkte Assemblyreferenzen und CLR-Typen; 1 erfasst diese Katalogzeilen für Assemblies im Filter. NULL ist ungültig. Default 1 ist Umfangssteuerung, kein Security-/Berechtigungsgate. Moduldefinitionen und Assembly-Binärinhalte werden nie gelesen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitBerechtigungsanalyse bit=0; Default: 0. 0 lässt Assembly-Owner, EXECUTE-AS-Principals und Trust-Zeilenanzahl aus; 1 fordert diese Zusatzdaten an. NULL ist ungültig. Der Pfad verlangt separat CATALOG_DEEP und dessen Gruppen-/High-Impact-Policy. Trust wird nur als serverweite Zeilenanzahl gelesen; Hash, Beschreibung und Assembly-zu-Trust-Zuordnung bleiben ausgeschlossen. Das Flag aktiviert kein CLR. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MitSitzungskontext bit=0; Default: 0. 0 lässt Login, Host und Clientprogramm aktiver Managed-Code-Requests NULL; 1 ergänzt genau diese drei Kontextspalten. NULL ist ungültig. Unabhängig vom CATALOG_DEEP-Owner-/Trustpfad. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@NurProblematisch bit=0; Default: 0. 0 behält alle Findings; 1 filtert ausschließlich auf Severity=WARN. NULL ist ungültig. Der Filter wirkt auf findings in CONSOLE/RAW/TABLE und JSON-findings, nicht auf übrige Ergebnisarrays, Warnings oder Bewertung. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=100; Default: 100. NULL oder 0 bedeutet unbegrenzt; positive Werte begrenzen je Resultset nach Sortierung. Negative Werte sind INVALID_PARAMETER. Begrenzte Mengen: findings nach NurProblematisch, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies, clrTasks, activeRequests, memory und performanceCounters. Unbegrenzt bleiben configuration, databaseStatus, sourceStatus, clrProperties und warnings. Die Begrenzung erfolgt nach Materialisierung und reduziert Quellkosten nicht. Der RESULTSET_TRUNCATED-Prüfblock zählt nur findings, assemblies, assemblyModules, assemblyDependencies, appDomains, loadedAssemblies und clrTasks; er deckt eine alleinige Begrenzung von activeRequests, memory oder performanceCounters nicht ab. Bei PrintMeldungen=1 wird die Warnmeldung ausgegeben, wenn diese geprüften Mengen das Limit überschreiten. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@LockTimeoutMs int=0; Default: 0. 0 setzt LOCK_TIMEOUT 0; 1 bis 60000 setzt Sitzungszeitlimit in Millisekunden. NULL und Werte außerhalb des Bereichs sind ungültig. Das eingehende Sitzungssetting wird am Ende wiederhergestellt. Sampling-Wartezeit wird hierdurch nicht begrenzt; TABLE-Helfer haben eigene lokale DDL-/Metadatenbudgets. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach äußerem Trimmen und Umwandlung in Großbuchstaben sind exakt CONSOLE, RAW, TABLE und NONE erlaubt; NULL, leer oder sonstige Werte ergeben INVALID_PARAMETER. CONSOLE rendert findings. RAW liefert zuerst Meta und dann geordnete Konfigurations-, Status-, Findings-, Katalog-, Host-, Request-, Memory-, Counter- und Warning-Resultsets. TABLE exportiert nur findings ins vorbereitete lokale Ziel. NONE unterdrückt Resultsets. TABLE und CONSOLE schalten interne Ausgabe auf NONE. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL oder Leerraum bedeutet keine Zuordnung; TABLE benötigt ein gültiges JSON-Objekt mit dem einzigen erlaubten case-sensitiven Schlüssel findings und einem nichtleeren JSON-String als lokalem #Temp-Zielnamen. Doppelte JSON-Schlüssel, unbekannte Schlüssel, Nicht-Stringwerte, doppelte Ziele, ##-/permanente Tabellen, über 116 Zeichen oder das case-insensitive reservierte Präfix #Monitor sind ungültig; das vorhandene Ziel muss lokal und leer sein. Der Writer akzeptiert eine leere Zieltabelle mit genau einer beliebigen Seed-Spalte oder eine passende Findingsstruktur. Bei nicht-TABLE und nichtleerem Wert erfolgt THROW 51011 vor Hilfe. TABLE-Preflight kann ebenfalls vor HELP werfen; der spätere Writer läuft nach OUT-Zuweisung und RAW-/JSON-Ausgabe mit ThrowOnError=1, sodass 51010 danach auftreten kann. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 0 unterdrückt Erstellung; 1 erzeugt ein JSON-Objekt mit meta als Einzelobjekt und benannten Arrays configuration, databaseStatus, sourceStatus, findings, assemblies, assemblyModules, assemblyDependencies, clrProperties, appDomains, loadedAssemblies, clrTasks, activeRequests, memory, performanceCounters und warnings. NULL ist ungültig. JSON ist unabhängig von ResultSetArt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT wird beim Einstieg auf NULL gesetzt. Bei JsonErzeugen=0 bleibt es NULL; bei 1 enthält es meta und die benannten Arrays. SQL FOR JSON lässt NULL-Eigenschaften standardmäßig aus; leere Collections werden als [] ausgegeben. Die OUTPUT-Bindung muss zum SQL-Typvertrag passen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. 1 gibt Status- und Truncation-Hinweise als Severity-10-Meldungen aus; 0 unterdrückt sie. NULL ist ungültig. Beeinflusst weder Status-OUTPUT noch strukturierte Warnings. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 1 druckt Kurzbeschreibung und kehrt vor Analyse/Resultsets zurück; 0 fährt normal fort. NULL wird nicht als 1 behandelt und wird nicht von der Bit-NULL-Validierung erfasst. Ein unzulässiges nichtleeres ResultTablesJson kann bereits vor diesem Zweig THROW 51011 auslösen. Beim frühen Help-Return werden die abschließenden Status-OUTPUTs nicht zugewiesen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. OUTPUT für den globalen Status, getrennt von Quell- und Datenbankstatus. Mögliche globale Werte: AVAILABLE, AVAILABLE_LIMITED, AVAILABLE_WITH_FINDING, NOT_APPLICABLE, FEATURE_DISABLED, INVALID_PARAMETER, UNAVAILABLE_FEATURE, HIGH_IMPACT_CONFIRMATION_REQUIRED, DENIED_GROUP, INTERNAL_ERROR, LOCK_TIMEOUT, ERROR_HANDLED. INTERNAL_ERROR kann defensiv aus der TOP(0)-Tabellenformprobe im Kandidatenhelfer stammen; keine Ursache oder Laufzeitbeobachtung daraus ableiten. Bei Help-Return keine Zuweisung. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bit der globalen Partialität (1 bei eingeschränkter/fehlgeschlagener Auswertung, sonst 0), getrennt von Quellen-/Datenbankpartialität. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. OUTPUT für ausgewählte SQL-Fehlernummer aus globaler CATCH- oder partieller Quellenmeldung; NULL, wenn keine gesetzt wurde. Getrennt vom Statuscode. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. OUTPUT für den global ausgewählten Fehler-/Statusbeschreibungstext: kann Validierungs-, Gate- oder Quellenfehlerdetails enthalten, aus globaler CATCH oder partieller Quellenmeldung stammen, oder NULL sein. Nicht für jeden Status ist eine Fehlerursache gesetzt. Getrennt von Statuscode und strukturierten Warnungen. Bei Help-Return nicht zugewiesen. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_ClrAnalysis] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @AssemblyNames=N''[ExampleAssembly]'', @MitModulzuordnung=0, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ClrAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @Json AS [DiagnosticJson];';
        PRINT N'Beispiel 4: CREATE TABLE [#ClrAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#ClrAnalysis_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#ClrAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ClrAnalysis_HelpExample]; THROW; END CATCH;';
        PRINT N'Beispiel 5: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNamePattern=N''like:ExampleDatabase%'', @AssemblyNamePattern=N''like:ExampleAssembly%'', @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 6: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @SampleSeconds=1, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 7: EXEC [monitor].[USP_ClrAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @MitBerechtigungsanalyse=1, @HighImpactConfirmed=1, @MaxZeilen=100, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        RETURN;
    END;

    IF @OutputModeRequested NOT IN('CONSOLE','RAW','TABLE','NONE')
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE sein.';
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL
        THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1
        EXEC [monitor].[InternalPrepareSingleResultTable]
              @ResultTablesJson=@ResultTablesJson
            , @ResultName=N'findings'
            , @TargetTable=@TableTarget OUTPUT
            , @ThrowOnError=1;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @OutputMode='NONE';

    IF @StatusCode='AVAILABLE'
       AND (@SystemdatenbankenEinbeziehen IS NULL OR @HighImpactConfirmed IS NULL
            OR @MitModulzuordnung IS NULL OR @MitBerechtigungsanalyse IS NULL
            OR @MitSitzungskontext IS NULL OR @NurProblematisch IS NULL
            OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
            OR @SampleSeconds IS NULL OR @SampleSeconds>60
            OR @MaxZeilen<0
            OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000)
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungültiger Bit-, Sample-, Zeilen- oder Lock-Timeout-Parameter.';

    CREATE TABLE [#ClrAnalysis_DatabaseCandidates]
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
    CREATE TABLE [#ClrAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ClrAnalysis_AssemblyFilters]
    (
          [ItemOrdinal] int NOT NULL
        , [AssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([AssemblyName])
    );
    CREATE TABLE [#ClrAnalysis_Configuration]
    (
          [CollectedAtUtc] datetime2(3) NOT NULL
        , [ProductMajorVersion] int NULL
        , [HostPlatform] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ClrEnabledConfiguredValue] int NULL
        , [ClrEnabledValueInUse] int NULL
        , [ClrStrictSecurityConfiguredValue] int NULL
        , [ClrStrictSecurityValueInUse] int NULL
        , [LightweightPoolingConfiguredValue] int NULL
        , [LightweightPoolingValueInUse] int NULL
        , [TrustedAssemblyCount] bigint NULL
        , [TrustedAssemblyStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredPerformancePermission] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_DatabaseStatus]
    (
          [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [IsTrustworthyOn] bit NULL
        , [AssemblyCount] bigint NOT NULL
        , [HighPermissionAssemblyCount] bigint NOT NULL
        , [ModuleCount] bigint NOT NULL
        , [SourceFailureCount] int NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_SourceStatus]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [RowCount] bigint NOT NULL
        , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_Assemblies]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssemblyId] int NOT NULL
        , [AssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ClrName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PermissionSetDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsVisible] bit NULL
        , [CreateDate] datetime NULL
        , [ModifyDate] datetime NULL
        , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsLoaded] bit NOT NULL
        , [LastVisibleLoadTime] datetime NULL
        , [TrustVerificationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_AssemblyModules]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssemblyClass] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AssemblyMethod] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecuteAsPrincipal] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_AssemblyDependencies]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DependencyKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ReferencedAssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [TypeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AssemblyClass] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_Properties]
    (
          [PropertyName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PropertyValue] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_AppDomains]
    (
          [AppDomainAddress] varbinary(8) NOT NULL
        , [AppDomainId] int NULL
        , [CreationTime] datetime NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [State] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StrongRefCount] int NULL
        , [WeakRefCount] int NULL
        , [Cost] int NULL
        , [Value] int NULL
        , [TotalProcessorTimeMs] bigint NULL
        , [TotalAllocatedMemoryKb] bigint NULL
        , [SurvivedMemoryKb] bigint NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_LoadedAssemblies]
    (
          [AppDomainAddress] varbinary(8) NOT NULL
        , [AssemblyId] int NOT NULL
        , [LoadTime] datetime NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AppDomainId] int NULL
        , [AssemblyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MappingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_Tasks]
    (
          [TaskAddress] varbinary(8) NOT NULL
        , [SosTaskAddress] varbinary(8) NULL
        , [AppDomainAddress] varbinary(8) NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AppDomainId] int NULL
        , [TaskState] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AbortState] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [TaskType] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AffinityCount] int NULL
        , [ForcedYieldCount] int NULL
        , [SessionId] smallint NULL
        , [RequestId] int NULL
        , [MappingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_ActiveRequests]
    (
          [SessionId] smallint NOT NULL
        , [RequestId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BlockingSessionId] smallint NULL
        , [WaitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [WaitTimeMs] int NULL
        , [ElapsedTimeMs] int NULL
        , [CpuTimeMs] int NULL
        , [Reads] bigint NULL
        , [LogicalReads] bigint NULL
        , [Writes] bigint NULL
        , [LoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_Memory]
    (
          [MemoryClerkType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ClerkCount] bigint NOT NULL
        , [PagesKb] bigint NULL
        , [VirtualMemoryReservedKb] bigint NULL
        , [VirtualMemoryCommittedKb] bigint NULL
        , [SharedMemoryReservedKb] bigint NULL
        , [SharedMemoryCommittedKb] bigint NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_CounterSamples]
    (
          [SamplePoint] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ReadAtUtc] datetime2(3) NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [CounterValue] bigint NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_PerformanceCounters]
    (
          [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [CounterValue] bigint NOT NULL
        , [Interpretation] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricValue] decimal(38,6) NULL
        , [MetricUnit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_FindingsCollected]
    (
          [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ObjectName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL
        , [ThresholdValue] decimal(38,4) NULL
        , [Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ClrAnalysis_Warnings]
    (
          [WarningCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    BEGIN TRY
        DECLARE @AssemblyPatternMode varchar(8),@AssemblyPatternValue nvarchar(4000),@AssemblyRegexFlags varchar(8),@AssemblyPatternValid bit;
        SELECT @AssemblyPatternMode=[PatternMode],@AssemblyPatternValue=[PatternValue],
               @AssemblyRegexFlags=[RegexFlags],@AssemblyPatternValid=[IsValid]
        FROM [monitor].[TVF_ParsePattern](@AssemblyNamePattern);
        IF @StatusCode='AVAILABLE'
           AND (@AssemblyPatternValid=0 OR (@AssemblyNames IS NOT NULL AND @AssemblyNamePattern IS NOT NULL))
            SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@AssemblyNamePattern ist ungültig oder wurde zusammen mit @AssemblyNames angegeben.';
        IF @StatusCode='AVAILABLE' AND @AssemblyPatternMode IN('REGEX','REGEXI')
           AND
           (
               COALESCE(@Major,0)<17
               OR NOT EXISTS
                  (
                      SELECT 1
                      FROM [master].[sys].[databases] [d] WITH (NOLOCK)
                      WHERE [d].[database_id]=DB_ID() AND [d].[compatibility_level]>=170
                  )
           )
            SELECT @StatusCode='UNAVAILABLE_FEATURE',@IsPartial=1,@ErrorMessage=N'Regex-Pattern benötigen SQL Server 2025 und Compatibility Level 170 in der Frameworkdatenbank.';

        IF @StatusCode='AVAILABLE'
        BEGIN
            INSERT [#ClrAnalysis_AssemblyFilters]([ItemOrdinal],[AssemblyName])
            SELECT [ItemOrdinal],[NameValue]
            FROM [monitor].[TVF_ParseSqlNameList](@AssemblyNames)
            WHERE [IsValid]=1;
            IF EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@AssemblyNames) WHERE [IsValid]=0)
                SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@AssemblyNames enthält mindestens einen ungültigen SQL-Namen.';
        END;

        IF @StatusCode='AVAILABLE' AND @MitBerechtigungsanalyse=1
        BEGIN
            EXEC [monitor].[InternalCheckAnalysisPath]
                  @AnalysisClass='CATALOG_DEEP'
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@StatusCode OUTPUT
                , @ErrorMessage=@ErrorMessage OUTPUT;
            IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
        END;

        DECLARE @CrossDatabaseRequested bit=0;
        IF @StatusCode='AVAILABLE'
        BEGIN
            EXEC [monitor].[USP_PrepareDatabaseCandidates]
                  @DatabaseNames=@DatabaseNames
                , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
                , @DatabaseNamePattern=@DatabaseNamePattern
                , @HighImpactConfirmed=@HighImpactConfirmed
                , @AnalysisClass='CLR_CURRENT'
                , @StatusCode=@StatusCode OUTPUT
                , @ErrorMessage=@ErrorMessage OUTPUT
                , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
                , @CandidateTable=N'#ClrAnalysis_DatabaseCandidates'
                , @WarningTable=N'#ClrAnalysis_DatabaseCandidateWarnings';
            IF @StatusCode<>'AVAILABLE' SET @IsPartial=1;
        END;

        INSERT [#ClrAnalysis_DatabaseStatus]
        ([DatabaseId],[DatabaseName],[StatusCode],[IsPartial],[IsTrustworthyOn],[AssemblyCount],[HighPermissionAssemblyCount],[ModuleCount],[SourceFailureCount],[EvidenceLimit])
        SELECT [c].[DatabaseId],[c].[DatabaseName],'PENDING',0,[d].[is_trustworthy_on],0,0,0,0,
               N'Sichtbare Katalogmetadaten; fehlende Metadata Visibility kann Assemblies oder Module ausblenden.'
        FROM [#ClrAnalysis_DatabaseCandidates] [c]
        LEFT JOIN [sys].[databases] [d] WITH (NOLOCK) ON [d].[database_id]=[c].[DatabaseId];
        INSERT [#ClrAnalysis_DatabaseStatus]
        ([DatabaseId],[DatabaseName],[StatusCode],[IsPartial],[IsTrustworthyOn],[AssemblyCount],[HighPermissionAssemblyCount],[ModuleCount],[SourceFailureCount],[ErrorMessage],[EvidenceLimit])
        SELECT NULL,[RequestedName],[StatusCode],1,NULL,0,0,0,1,[ErrorMessage],N'Explizit angeforderte Datenbank war nicht auswertbar.'
        FROM [#ClrAnalysis_DatabaseCandidateWarnings];

        SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
        EXEC [sys].[sp_executesql] @LockTimeoutSql;

        IF @StatusCode='AVAILABLE'
        BEGIN
            INSERT [#ClrAnalysis_Configuration]
            ([CollectedAtUtc],[ProductMajorVersion],[HostPlatform],[ClrEnabledConfiguredValue],[ClrEnabledValueInUse],
             [ClrStrictSecurityConfiguredValue],[ClrStrictSecurityValueInUse],[LightweightPoolingConfiguredValue],
             [LightweightPoolingValueInUse],[TrustedAssemblyCount],[TrustedAssemblyStatus],[RequiredPerformancePermission],[EvidenceLimit])
            SELECT @Now,@Major,@HostPlatform,
                   MAX(CASE WHEN [name]=N'clr enabled' THEN TRY_CONVERT(int,[value]) END),
                   MAX(CASE WHEN [name]=N'clr enabled' THEN TRY_CONVERT(int,[value_in_use]) END),
                   MAX(CASE WHEN [name]=N'clr strict security' THEN TRY_CONVERT(int,[value]) END),
                   MAX(CASE WHEN [name]=N'clr strict security' THEN TRY_CONVERT(int,[value_in_use]) END),
                   MAX(CASE WHEN [name]=N'lightweight pooling' THEN TRY_CONVERT(int,[value]) END),
                   MAX(CASE WHEN [name]=N'lightweight pooling' THEN TRY_CONVERT(int,[value_in_use]) END),
                   NULL,CASE WHEN @MitBerechtigungsanalyse=1 THEN 'PENDING' ELSE 'NOT_REQUESTED' END,
                   @RequiredPerformancePermission,
                   N'Konfigurationswerte und Hostzustand sind getrennte Evidenz; CLR Host Properties beweisen nicht, dass Benutzer-CLR aktiviert ist.'
            FROM [sys].[configurations] WITH (NOLOCK)
            WHERE [name] IN(N'clr enabled',N'clr strict security',N'lightweight pooling');
            INSERT [#ClrAnalysis_SourceStatus]
            VALUES(NULL,'CLR_CONFIGURATION','AVAILABLE',0,1,N'VIEW SERVER STATE beziehungsweise Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Nur drei dokumentierte Konfigurationsoptionen.');

            IF @MitBerechtigungsanalyse=1
            BEGIN TRY
                DECLARE @TrustedCount bigint;
                SELECT @TrustedCount=COUNT_BIG(*) FROM [sys].[trusted_assemblies] WITH (NOLOCK);
                UPDATE [#ClrAnalysis_Configuration] SET [TrustedAssemblyCount]=@TrustedCount,[TrustedAssemblyStatus]='COUNT_AVAILABLE';
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'TRUSTED_ASSEMBLIES','AVAILABLE',0,@TrustedCount,N'VIEW SERVER STATE beziehungsweise Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Nur Zeilenanzahl; Hash und description werden nicht gelesen.');
            END TRY
            BEGIN CATCH
                UPDATE [#ClrAnalysis_Configuration] SET [TrustedAssemblyStatus]='SOURCE_UNAVAILABLE';
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'TRUSTED_ASSEMBLIES',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,N'VIEW SERVER STATE beziehungsweise Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Trust-List-Zählung isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_Properties]
                SELECT [name],[value],N'Directory- und sonstige Pfadproperties sind bewusst ausgeschlossen; Hostzustand ist kein Nachweis für clr enabled.'
                FROM [sys].[dm_clr_properties] WITH (NOLOCK)
                WHERE [name] IN(N'state',N'version');
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_PROPERTIES','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Nur state und version; Installationsverzeichnis wird nicht gelesen.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_PROPERTIES',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'CLR Host Properties isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_AppDomains]
                SELECT [a].[appdomain_address],[a].[appdomain_id],[a].[creation_time],[a].[db_id],[d].[name],[a].[state],
                       [a].[strong_refcount],[a].[weak_refcount],[a].[cost],[a].[value],[a].[total_processor_time_ms],
                       [a].[total_allocated_memory_kb],[a].[survived_memory_kb],
                       N'AppDomain-Momentaufnahme; creation_time ist wegen Caching nicht der Zeitpunkt einer konkreten CLR-Ausführung.'
                FROM [sys].[dm_clr_appdomains] [a] WITH (NOLOCK)
                LEFT JOIN [sys].[databases] [d] WITH (NOLOCK) ON [d].[database_id]=[a].[db_id]
                WHERE EXISTS(SELECT 1 FROM [#ClrAnalysis_DatabaseCandidates] [c] WHERE [c].[DatabaseId]=[a].[db_id]);
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_APPDOMAINS','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'AppDomain-Name und User-ID werden nicht ausgegeben.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_APPDOMAINS',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'AppDomainquelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_LoadedAssemblies]
                SELECT [l].[appdomain_address],[l].[assembly_id],[l].[load_time],
                       [a].[DatabaseId],[a].[DatabaseName],[a].[AppDomainId],NULL,'CATALOG_PENDING',
                       N'assembly_id wird nur zusammen mit der über AppDomain ermittelten Datenbank korreliert.'
                FROM [sys].[dm_clr_loaded_assemblies] [l] WITH (NOLOCK)
                JOIN [#ClrAnalysis_AppDomains] [a] ON [a].[AppDomainAddress]=[l].[appdomain_address];
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_LOADED_ASSEMBLIES','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Server-DMV; Datenbankkontext wird ausschließlich über AppDomain korreliert.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_LOADED_ASSEMBLIES',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Loaded-Assembly-Quelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_Tasks]
                SELECT [t].[task_address],[t].[sos_task_address],[t].[appdomain_address],
                       [a].[DatabaseName],[a].[AppDomainId],[t].[state],[t].[abort_state],[t].[type],
                       [t].[affinity_count],[t].[forced_yield_count],[ot].[session_id],[ot].[request_id],
                       CASE WHEN [ot].[task_address] IS NULL THEN 'REQUEST_UNMAPPED' ELSE 'REQUEST_MAPPED' END,
                       N'Best-effort-Korrelation von sos_task_address zu sys.dm_os_tasks.task_address; ein CLR Task ist keine Aufrufhistorie.'
                FROM [sys].[dm_clr_tasks] [t] WITH (NOLOCK)
                LEFT JOIN [#ClrAnalysis_AppDomains] [a] ON [a].[AppDomainAddress]=[t].[appdomain_address]
                LEFT JOIN [sys].[dm_os_tasks] [ot] WITH (NOLOCK) ON [ot].[task_address]=[t].[sos_task_address]
                WHERE [a].[AppDomainAddress] IS NOT NULL;
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_TASKS','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Adressen dienen nur der Laufzeitkorrelation; keine SQL-Texte oder Pläne.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_TASKS',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'CLR-Task-Quelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_ActiveRequests]
                SELECT [r].[session_id],[r].[request_id],[d].[name],[r].[status],[r].[command],[r].[blocking_session_id],
                       [r].[wait_type],[r].[wait_time],[r].[total_elapsed_time],[r].[cpu_time],[r].[reads],[r].[logical_reads],[r].[writes],
                       CASE WHEN @MitSitzungskontext=1 THEN [s].[login_name] END,
                       CASE WHEN @MitSitzungskontext=1 THEN [s].[host_name] END,
                       CASE WHEN @MitSitzungskontext=1 THEN [s].[program_name] END,
                       N'Aktive Request-Momentaufnahme; executing_managed_code ist keine Historie und beweist keine bestimmte Assemblymethode.'
                FROM [sys].[dm_exec_requests] [r] WITH (NOLOCK)
                LEFT JOIN [sys].[dm_exec_sessions] [s] WITH (NOLOCK) ON [s].[session_id]=[r].[session_id]
                LEFT JOIN [sys].[databases] [d] WITH (NOLOCK) ON [d].[database_id]=[r].[database_id]
                WHERE [r].[executing_managed_code]=1
                  AND EXISTS(SELECT 1 FROM [#ClrAnalysis_DatabaseCandidates] [c] WHERE [c].[DatabaseId]=[r].[database_id]);
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'MANAGED_CODE_REQUESTS','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Kein Batchtext, SQL-Text oder Plan.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'MANAGED_CODE_REQUESTS',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Managed-Code-Requestquelle isoliert fehlgeschlagen.');
            END CATCH;

            BEGIN TRY
                INSERT [#ClrAnalysis_Memory]
                SELECT [type],COUNT_BIG(*),SUM(CONVERT(bigint,[pages_kb])),SUM(CONVERT(bigint,[virtual_memory_reserved_kb])),
                       SUM(CONVERT(bigint,[virtual_memory_committed_kb])),SUM(CONVERT(bigint,[shared_memory_reserved_kb])),
                       SUM(CONVERT(bigint,[shared_memory_committed_kb])),
                       N'Aktuelle Memory-Clerk-Aggregation; hohe Werte werden ohne Workloadbaseline nicht pauschal als Fehler klassifiziert.'
                FROM [sys].[dm_os_memory_clerks] WITH (NOLOCK)
                WHERE [type] IN(N'MEMORYCLERK_SQLCLR',N'MEMORYCLERK_SQLCLRASSEMBLY')
                GROUP BY [type];
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_MEMORY_CLERKS','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Nur aggregierte CLR-Clerks; keine Speicheradressen.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_MEMORY_CLERKS',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Memory-Clerk-Quelle isoliert fehlgeschlagen.');
            END CATCH;

            SET @MeasurementStartUtc=SYSUTCDATETIME();
            BEGIN TRY
                INSERT [#ClrAnalysis_CounterSamples]
                SELECT 'T1',SYSUTCDATETIME(),[counter_name],[instance_name],[cntr_type],[cntr_value]
                FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                WHERE [object_name] LIKE N'%:CLR%';
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_COUNTERS_T1','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Originale SQL-Server-Counterwerte; cntr_type steuert die Interpretation.');
            END TRY
            BEGIN CATCH
                INSERT [#ClrAnalysis_SourceStatus]
                VALUES(NULL,'CLR_COUNTERS_T1',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'CLR-Counterquelle isoliert fehlgeschlagen.');
            END CATCH;

            IF @SampleSeconds>0
            BEGIN
                DECLARE @Delay char(8)=CONVERT(char(8),DATEADD(SECOND,@SampleSeconds,CONVERT(datetime,'19000101',112)),108);
                WAITFOR DELAY @Delay;
                BEGIN TRY
                    INSERT [#ClrAnalysis_CounterSamples]
                    SELECT 'T2',SYSUTCDATETIME(),[counter_name],[instance_name],[cntr_type],[cntr_value]
                    FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                    WHERE [object_name] LIKE N'%:CLR%';
                    INSERT [#ClrAnalysis_SourceStatus]
                    VALUES(NULL,'CLR_COUNTERS_T2','AVAILABLE',0,@@ROWCOUNT,@RequiredPerformancePermission,SYSUTCDATETIME(),NULL,NULL,N'Zweiter Messpunkt desselben Samplefensters.');
                END TRY
                BEGIN CATCH
                    INSERT [#ClrAnalysis_SourceStatus]
                    VALUES(NULL,'CLR_COUNTERS_T2',CASE WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,@RequiredPerformancePermission,SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Zweiter CLR-Countermesspunkt isoliert fehlgeschlagen.');
                END CATCH;
            END;
            SET @MeasurementEndUtc=SYSUTCDATETIME();
        END;

        DECLARE @AssemblyPredicate nvarchar(max)=
            N' AND (NOT EXISTS(SELECT 1 FROM [#ClrAnalysis_AssemblyFilters]) OR EXISTS(SELECT 1 FROM [#ClrAnalysis_AssemblyFilters] [f] WHERE [f].[AssemblyName]=[a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS))';
        IF @AssemblyPatternMode='LIKE'
            SET @AssemblyPredicate+=N' AND [a].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @pPattern COLLATE SQL_Latin1_General_CP1_CS_AS';
        IF @AssemblyPatternMode IN('REGEX','REGEXI')
            SET @AssemblyPredicate+=N' AND REGEXP_LIKE([a].[name],@pPattern,@pRegexFlags)';

        DECLARE @Db sysname,@DbId int,@CompatibilityLevel int,@Sql nvarchar(max),@Rows bigint;
        IF @StatusCode='AVAILABLE'
        BEGIN
            DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseName],[DatabaseId],[CompatibilityLevel]
                FROM [#ClrAnalysis_DatabaseCandidates]
                ORDER BY COALESCE([RequestedOrdinal],[DatabaseId]),[DatabaseId];
            OPEN [DatabaseCursor]; FETCH NEXT FROM [DatabaseCursor] INTO @Db,@DbId,@CompatibilityLevel;
            WHILE @@FETCH_STATUS=0
            BEGIN
                IF @AssemblyPatternMode IN('REGEX','REGEXI') AND COALESCE(@CompatibilityLevel,0)<170
                BEGIN
                    UPDATE [#ClrAnalysis_DatabaseStatus]
                    SET [StatusCode]='UNAVAILABLE_FEATURE',[IsPartial]=1,[SourceFailureCount]=[SourceFailureCount]+1,
                        [ErrorMessage]=N'Regex-Pattern benötigen Compatibility Level 170.'
                    WHERE [DatabaseName]=@Db;
                    INSERT [#ClrAnalysis_SourceStatus]
                    VALUES(@Db,'FILTER_CONTRACT','UNAVAILABLE_FEATURE',1,0,N'Compatibility Level 170',SYSUTCDATETIME(),NULL,N'Regex-Pattern nicht ausführbar.',N'Keine CLR-Katalogquelle wurde für diese Datenbank gelesen.');
                    FETCH NEXT FROM [DatabaseCursor] INTO @Db,@DbId,@CompatibilityLevel;
                    CONTINUE;
                END;

                BEGIN TRY
                    SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ClrAnalysis_Assemblies]
([DatabaseId],[DatabaseName],[AssemblyId],[AssemblyName],[ClrName],[PermissionSetDesc],[IsVisible],[CreateDate],[ModifyDate],[OwnerName],[IsLoaded],[LastVisibleLoadTime],[TrustVerificationStatus],[EvidenceLimit])
SELECT @pDatabaseId,@pDatabaseName,[a].[assembly_id],[a].[name],[a].[clr_name],[a].[permission_set_desc],[a].[is_visible],[a].[create_date],[a].[modify_date],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       0,NULL,''NOT_EVALUATED_BINARY_EXCLUDED'',
       N''Benutzerdefinierte Assemblymetadaten; sys.assembly_files.content und Hashwerte sind ausgeschlossen.''
FROM [sys].[assemblies] [a] WITH (NOLOCK) '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[a].[principal_id] ' ELSE N'' END
 + N'WHERE [a].[is_user_defined]=1 '+@AssemblyPredicate+N'; SET @pRows=@@ROWCOUNT;';
                    SET @Rows=0;
                    EXEC [sys].[sp_executesql] @Sql,
                         N'@pDatabaseId int,@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                         @pDatabaseId=@DbId,@pDatabaseName=@Db,@pPattern=@AssemblyPatternValue,@pRegexFlags=@AssemblyRegexFlags,@pRows=@Rows OUTPUT;
                    INSERT [#ClrAnalysis_SourceStatus]
                    VALUES(@Db,'CLR_ASSEMBLIES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Keine Binärinhalte oder Hashes.');
                END TRY
                BEGIN CATCH
                    INSERT [#ClrAnalysis_SourceStatus]
                    VALUES(@Db,'CLR_ASSEMBLIES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Assemblykatalog isoliert fehlgeschlagen.');
                END CATCH;

                IF @MitModulzuordnung=1
                BEGIN
                    BEGIN TRY
                        SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ClrAnalysis_AssemblyModules]
([DatabaseName],[SchemaName],[ObjectName],[ObjectType],[ObjectTypeDesc],[AssemblyName],[AssemblyClass],[AssemblyMethod],[ExecuteAsPrincipal],[EvidenceLimit])
SELECT @pDatabaseName,[s].[name],[o].[name],[o].[type],[o].[type_desc],[a].[name],[am].[assembly_class],[am].[assembly_method],'
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'[dp].[name]' ELSE N'CONVERT(sysname,NULL)' END + N',
       N''Objekt- und Implementierungsmetadaten ohne Moduldefinition oder SQL-Text.''
FROM [sys].[assembly_modules] [am] WITH (NOLOCK)
JOIN [sys].[objects] [o] WITH (NOLOCK) ON [o].[object_id]=[am].[object_id]
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
JOIN [sys].[assemblies] [a] WITH (NOLOCK) ON [a].[assembly_id]=[am].[assembly_id] '
 + CASE WHEN @MitBerechtigungsanalyse=1 THEN N'LEFT JOIN [sys].[database_principals] [dp] WITH (NOLOCK) ON [dp].[principal_id]=[am].[execute_as_principal_id] ' ELSE N'' END
 + N'WHERE [a].[is_user_defined]=1 '+@AssemblyPredicate+N'; SET @pRows=@@ROWCOUNT;';
                        SET @Rows=0;
                        EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                             @pDatabaseName=@Db,@pPattern=@AssemblyPatternValue,@pRegexFlags=@AssemblyRegexFlags,@pRows=@Rows OUTPUT;
                        INSERT [#ClrAnalysis_SourceStatus]
                        VALUES(@Db,'CLR_ASSEMBLY_MODULES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Keine Moduldefinitionen.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#ClrAnalysis_SourceStatus]
                        VALUES(@Db,'CLR_ASSEMBLY_MODULES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Modulkatalog isoliert fehlgeschlagen.');
                    END CATCH;

                    BEGIN TRY
                        SET @Sql=N'USE '+QUOTENAME(@Db)+N';
INSERT [#ClrAnalysis_AssemblyDependencies]
([DatabaseName],[DependencyKind],[AssemblyName],[ReferencedAssemblyName],[SchemaName],[TypeName],[AssemblyClass],[EvidenceLimit])
SELECT @pDatabaseName,''ASSEMBLY_REFERENCE'',[a].[name],[ra].[name],NULL,NULL,NULL,
       N''Direkte Assemblyreferenz; rekursive oder binäre Abhängigkeiten werden nicht aufgelöst.''
FROM [sys].[assembly_references] [ar] WITH (NOLOCK)
JOIN [sys].[assemblies] [a] WITH (NOLOCK) ON [a].[assembly_id]=[ar].[assembly_id]
JOIN [sys].[assemblies] [ra] WITH (NOLOCK) ON [ra].[assembly_id]=[ar].[referenced_assembly_id]
WHERE [a].[is_user_defined]=1 '+@AssemblyPredicate+N'
UNION ALL
SELECT @pDatabaseName,''ASSEMBLY_TYPE'',[a].[name],NULL,[s].[name],[at].[name],[at].[assembly_class],
       N''Sichtbarer CLR-Typ; assembly_qualified_name und Binärinhalt sind ausgeschlossen.''
FROM [sys].[assembly_types] [at] WITH (NOLOCK)
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[at].[schema_id]
JOIN [sys].[assemblies] [a] WITH (NOLOCK) ON [a].[assembly_id]=[at].[assembly_id]
WHERE [a].[is_user_defined]=1 '+@AssemblyPredicate+N'; SET @pRows=@@ROWCOUNT;';
                        SET @Rows=0;
                        EXEC [sys].[sp_executesql] @Sql,N'@pDatabaseName sysname,@pPattern nvarchar(4000),@pRegexFlags varchar(8),@pRows bigint OUTPUT',
                             @pDatabaseName=@Db,@pPattern=@AssemblyPatternValue,@pRegexFlags=@AssemblyRegexFlags,@pRows=@Rows OUTPUT;
                        INSERT [#ClrAnalysis_SourceStatus]
                        VALUES(@Db,'CLR_ASSEMBLY_DEPENDENCIES','AVAILABLE',0,@Rows,N'Metadatensichtbarkeit',SYSUTCDATETIME(),NULL,NULL,N'Direkte Referenzen und CLR-Typen; keine Binaryanalyse.');
                    END TRY
                    BEGIN CATCH
                        INSERT [#ClrAnalysis_SourceStatus]
                        VALUES(@Db,'CLR_ASSEMBLY_DEPENDENCIES',CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' WHEN ERROR_NUMBER() IN(229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,1,0,N'Metadatensichtbarkeit',SYSUTCDATETIME(),ERROR_NUMBER(),ERROR_MESSAGE(),N'Dependency-Katalog isoliert fehlgeschlagen.');
                    END CATCH;
                END;

                UPDATE [ds]
                SET [AssemblyCount]=(SELECT COUNT_BIG(*) FROM [#ClrAnalysis_Assemblies] [a] WHERE [a].[DatabaseName]=[ds].[DatabaseName]),
                    [HighPermissionAssemblyCount]=(SELECT COUNT_BIG(*) FROM [#ClrAnalysis_Assemblies] [a] WHERE [a].[DatabaseName]=[ds].[DatabaseName] AND [a].[PermissionSetDesc] IN(N'EXTERNAL_ACCESS',N'UNSAFE_ACCESS')),
                    [ModuleCount]=(SELECT COUNT_BIG(*) FROM [#ClrAnalysis_AssemblyModules] [m] WHERE [m].[DatabaseName]=[ds].[DatabaseName])
                FROM [#ClrAnalysis_DatabaseStatus] [ds] WHERE [ds].[DatabaseName]=@Db;

                FETCH NEXT FROM [DatabaseCursor] INTO @Db,@DbId,@CompatibilityLevel;
            END;
            CLOSE [DatabaseCursor]; DEALLOCATE [DatabaseCursor];
        END;

        UPDATE [l]
        SET [AssemblyName]=[a].[AssemblyName],[MappingStatus]='CATALOG_MAPPED'
        FROM [#ClrAnalysis_LoadedAssemblies] [l]
        JOIN [#ClrAnalysis_Assemblies] [a] ON [a].[DatabaseId]=[l].[DatabaseId] AND [a].[AssemblyId]=[l].[AssemblyId];
        UPDATE [a]
        SET [IsLoaded]=1,[LastVisibleLoadTime]=[x].[LoadTime]
        FROM [#ClrAnalysis_Assemblies] [a]
        CROSS APPLY
        (
            SELECT MAX([l].[LoadTime]) AS [LoadTime]
            FROM [#ClrAnalysis_LoadedAssemblies] [l]
            WHERE [l].[DatabaseId]=[a].[DatabaseId] AND [l].[AssemblyId]=[a].[AssemblyId]
        ) [x]
        WHERE [x].[LoadTime] IS NOT NULL;

        INSERT [#ClrAnalysis_PerformanceCounters]
        SELECT [a].[CounterName],[a].[InstanceName],[a].[CounterType],COALESCE([b].[CounterValue],[a].[CounterValue]),
               [i].[Interpretation],[i].[MetricValue],[i].[MetricUnit],[i].[FindingCode],
               N'Counterinterpretation basiert auf cntr_type; CLR Execution ist kumulative Laufzeit und keine per-Request-Zuordnung.'
        FROM [#ClrAnalysis_CounterSamples] [a]
        LEFT JOIN [#ClrAnalysis_CounterSamples] [b]
          ON [b].[SamplePoint]='T2' AND [b].[CounterName]=[a].[CounterName]
         AND [b].[InstanceName]=[a].[InstanceName] AND [b].[CounterType]=[a].[CounterType]
        CROSS APPLY [monitor].[TVF_InterpretPerformanceCounter]
        (
              [a].[CounterType],[a].[CounterValue],COALESCE([b].[CounterValue],[a].[CounterValue])
            , NULL,NULL
            , CONVERT(decimal(19,6),CASE WHEN @SampleSeconds>0 THEN DATEDIFF_BIG(MICROSECOND,[a].[ReadAtUtc],[b].[ReadAtUtc])/1000000.0 ELSE 0 END)
        ) [i]
        WHERE [a].[SamplePoint]='T1';

        INSERT [#ClrAnalysis_FindingsCollected]
        ([DatabaseName],[ObjectType],[ObjectName],[Severity],[Confidence],[FindingCode],[MetricName],[MetricValue],[ThresholdValue],[Evidence],[EvidenceLimit],[RecommendedNextCheck])
        SELECT NULL,'SERVER_CONFIGURATION',NULL,'WARN','HIGH','CLR_STRICT_SECURITY_DISABLED',
               'ClrStrictSecurityValueInUse',[ClrStrictSecurityValueInUse],1,
               N'clr strict security ist deaktiviert.',
               N'Der Befund bewertet die dokumentierte Sicherheitsoption; er beweist keine konkrete Ausnutzbarkeit einer Assembly.',
               N'Assemblysignierung, trusted assemblies, Permission Sets und dokumentierte Migrationsgründe prüfen.'
        FROM [#ClrAnalysis_Configuration]
        WHERE COALESCE([ClrStrictSecurityValueInUse],0)=0;

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT NULL,'SERVER_CONFIGURATION',NULL,'WARN','HIGH','CLR_LIGHTWEIGHT_POOLING_CONFLICT',
               'LightweightPoolingValueInUse',[LightweightPoolingValueInUse],0,
               N'clr enabled und lightweight pooling sind gleichzeitig aktiv.',
               N'SQL CLR wird nach Herstellerdokumentation unter lightweight pooling nicht unterstützt.',
               N'Eine der beiden Optionen nach Change-Control deaktivieren; dieses Analysemodul ändert keine Konfiguration.'
        FROM [#ClrAnalysis_Configuration]
        WHERE [ClrEnabledValueInUse]=1 AND [LightweightPoolingValueInUse]=1;

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [a].[DatabaseName],'ASSEMBLY',[a].[AssemblyName],'WARN','HIGH','USER_ASSEMBLY_WHILE_CLR_DISABLED',
               'ClrEnabledValueInUse',[c].[ClrEnabledValueInUse],1,
               N'Eine benutzerdefinierte Assembly ist sichtbar, während clr enabled nicht aktiv ist.',
               N'Die Katalogzeile beweist keine aktuell geladene oder ausgeführte Assembly.',
               N'Prüfen, ob die Assembly noch benötigt wird oder CLR beabsichtigt deaktiviert ist.'
        FROM [#ClrAnalysis_Assemblies] [a]
        CROSS JOIN [#ClrAnalysis_Configuration] [c]
        WHERE COALESCE([c].[ClrEnabledValueInUse],0)=0;

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [DatabaseName],'ASSEMBLY',[AssemblyName],'WARN','HIGH','UNSUPPORTED_CLR_PERMISSION_SET_ON_LINUX',
               'PermissionSet',CASE [PermissionSetDesc] WHEN N'EXTERNAL_ACCESS' THEN 2 WHEN N'UNSAFE_ACCESS' THEN 3 END,1,
               CONCAT(N'Die Assembly verwendet ',[PermissionSetDesc],N' auf SQL Server unter Linux.'),
               N'EXTERNAL_ACCESS und UNSAFE sind für SQL CLR unter Linux nicht unterstützt; die Analyse lädt die Assembly nicht.',
               N'Zielplattform, Permission Set und externe Abhängigkeiten vor Deployment oder Failover prüfen.'
        FROM [#ClrAnalysis_Assemblies]
        WHERE UPPER(COALESCE(@HostPlatform,N''))='LINUX' AND [PermissionSetDesc] IN(N'EXTERNAL_ACCESS',N'UNSAFE_ACCESS');

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [a].[DatabaseName],'ASSEMBLY',[a].[AssemblyName],'WARN','HIGH','TRUSTWORTHY_DATABASE_WITH_HIGH_PERMISSION_ASSEMBLY',
               'IsTrustworthyOn',[ds].[IsTrustworthyOn],0,
               CONCAT(N'Die Datenbank ist TRUSTWORTHY ON und enthält eine Assembly mit Permission Set ',[a].[PermissionSetDesc],N'.'),
               N'Der Befund beweist keine Privilege Escalation; Owner-, Signatur- und Trustkontext sind separat zu prüfen.',
               N'Datenbankowner, Signaturen, trusted assemblies und erforderlichen Permission Set prüfen.'
        FROM [#ClrAnalysis_Assemblies] [a]
        JOIN [#ClrAnalysis_DatabaseStatus] [ds] ON [ds].[DatabaseName]=[a].[DatabaseName]
        WHERE [ds].[IsTrustworthyOn]=1 AND [a].[PermissionSetDesc] IN(N'EXTERNAL_ACCESS',N'UNSAFE_ACCESS');

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [DatabaseName],'ASSEMBLY',[AssemblyName],'INFO','HIGH','ASSEMBLY_TRUST_MAPPING_NOT_VERIFIED',
               NULL,NULL,NULL,
               N'Die exakte Zuordnung dieser Assembly zur serverweiten Trust List wurde nicht geprüft.',
               N'Ein belastbarer Abgleich benötigt den SHA2_512-Hash des Assembly-Binärinhalts; dieser Privacy- und Kostenpfad ist ausgeschlossen.',
               N'Bei Security-Review den Hashabgleich kontrolliert außerhalb des Standardpfads durchführen.'
        FROM [#ClrAnalysis_Assemblies]
        WHERE [PermissionSetDesc] IN(N'EXTERNAL_ACCESS',N'UNSAFE_ACCESS');

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT NULL,'CLR_HOST',N'state','WARN','HIGH','CLR_HOST_INITIALIZATION_FAILED',
               NULL,NULL,NULL,
               CONCAT(N'Der CLR Host meldet den Zustand ',[PropertyValue],N'.'),
               N'sys.dm_clr_properties beschreibt den Hostzustand, nicht die Aktivierung von Benutzer-CLR.',
               N'SQL Server Errorlog, Memory Pressure und Hostinitialisierung prüfen.'
        FROM [#ClrAnalysis_Properties]
        WHERE [PropertyName]=N'state' AND [PropertyValue] LIKE N'%permanently failed%';

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [DatabaseName],'ACTIVE_REQUEST',CONCAT(CONVERT(nvarchar(20),[SessionId]),N':',CONVERT(nvarchar(20),[RequestId])),
               'WARN','HIGH','ACTIVE_MANAGED_CODE_REQUEST_BLOCKED','BlockingSessionId',[BlockingSessionId],0,
               CONCAT(N'Der aktive Managed-Code-Request ist durch Session ',CONVERT(nvarchar(20),[BlockingSessionId]),N' geblockt.'),
               N'Momentaufnahme; executing_managed_code identifiziert keine bestimmte Assemblymethode.',
               N'USP_CurrentBlocking für die vollständige Blockerkette ausführen.'
        FROM [#ClrAnalysis_ActiveRequests]
        WHERE COALESCE([BlockingSessionId],0)>0;

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [DatabaseName],'CLR_TASK',CONVERT(nvarchar(34),[TaskAddress],1),'INFO','MEDIUM','CLR_TASK_REQUEST_UNMAPPED',
               'ForcedYieldCount',[ForcedYieldCount],NULL,
               N'Ein aktueller CLR Task konnte nicht zu einem sichtbaren sys.dm_os_tasks-Request gemappt werden.',
               N'Task- und Requestlebenszeiten können zwischen den DMV-Lesezeitpunkten wechseln; fehlende Zuordnung ist kein Fehlerbeweis.',
               N'Bei wiederholtem Auftreten CLR Tasks, AppDomainzustand und aktuelle Requests gemeinsam erfassen.'
        FROM [#ClrAnalysis_Tasks]
        WHERE [MappingStatus]='REQUEST_UNMAPPED';

        INSERT [#ClrAnalysis_FindingsCollected]
        SELECT [DatabaseName],'LOADED_ASSEMBLY',CONVERT(nvarchar(20),[AssemblyId]),'INFO','LOW','LOADED_ASSEMBLY_CATALOG_UNMAPPED',
               NULL,NULL,NULL,
               N'Eine geladene Assembly-DMV-Zeile konnte keiner sichtbaren benutzerdefinierten Assembly im AppDomain-Datenbankkontext zugeordnet werden.',
               N'Systemassembly, Metadatensichtbarkeit, Filter oder zwischenzeitlicher Unload können die Zuordnung verhindern.',
               N'Filter und Metadatenrechte prüfen; keine globale Zuordnung nur über assembly_id vornehmen.'
        FROM [#ClrAnalysis_LoadedAssemblies]
        WHERE [MappingStatus]<>'CATALOG_MAPPED';

        INSERT [#ClrAnalysis_Warnings]
        VALUES('ASSEMBLY_TRUST_HASH_EXCLUDED',N'Die Analyse liest weder sys.assembly_files.content noch Trusted-Assembly-Hashes und kann deshalb keinen Assembly-zu-Trust-List-Nachweis erzeugen.',N'Die Anzahl trusted assemblies ist bei Opt-in nur serverweite Kontextevidenz.');
        IF UPPER(COALESCE(@HostPlatform,N''))='LINUX'
            INSERT [#ClrAnalysis_Warnings]
            VALUES('LINUX_CLR_PLATFORM_LIMIT',N'SQL CLR unter Linux unterstützt nur SAFE Assemblies; Assembly-Builds müssen weiterhin auf .NET Framework basieren.',N'Die Analyse führt keinen Lade- oder Ausführungstest durch.');

        UPDATE [ds]
        SET [SourceFailureCount]=(SELECT COUNT(*) FROM [#ClrAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1),
            [IsPartial]=CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [#ClrAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1) THEN 1 ELSE 0 END),
            [StatusCode]=CASE WHEN EXISTS(SELECT 1 FROM [#ClrAnalysis_SourceStatus] [ss] WHERE [ss].[DatabaseName]=[ds].[DatabaseName] AND [ss].[IsPartial]=1) THEN 'AVAILABLE_LIMITED'
                              WHEN [AssemblyCount]=0 THEN 'NOT_APPLICABLE_VISIBLE_SCOPE' ELSE 'AVAILABLE' END
        FROM [#ClrAnalysis_DatabaseStatus] [ds]
        WHERE [StatusCode]='PENDING';

        IF @StatusCode='AVAILABLE'
        BEGIN
            IF EXISTS(SELECT 1 FROM [#ClrAnalysis_SourceStatus] WHERE [IsPartial]=1)
               OR EXISTS(SELECT 1 FROM [#ClrAnalysis_DatabaseStatus] WHERE [IsPartial]=1)
               OR EXISTS(SELECT 1 FROM [#ClrAnalysis_DatabaseCandidateWarnings])
                SELECT @StatusCode='AVAILABLE_LIMITED',@IsPartial=1;
            ELSE IF EXISTS(SELECT 1 FROM [#ClrAnalysis_FindingsCollected] WHERE [Severity]='WARN')
                SET @StatusCode='AVAILABLE_WITH_FINDING';
            ELSE IF EXISTS(SELECT 1 FROM [#ClrAnalysis_Configuration] WHERE COALESCE([ClrEnabledValueInUse],0)=0)
                 AND NOT EXISTS(SELECT 1 FROM [#ClrAnalysis_Assemblies])
                SET @StatusCode='NOT_APPLICABLE';
            ELSE IF EXISTS(SELECT 1 FROM [#ClrAnalysis_Configuration] WHERE COALESCE([ClrEnabledValueInUse],0)=0)
                SET @StatusCode='FEATURE_DISABLED';
        END;

        SELECT @ErrorNumber=COALESCE(@ErrorNumber,MIN([ErrorNumber])),@ErrorMessage=COALESCE(@ErrorMessage,MIN([ErrorMessage]))
        FROM [#ClrAnalysis_SourceStatus] WHERE [IsPartial]=1;

        IF @MaxZeilen>0 AND
           (
               (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_FindingsCollected] WHERE @NurProblematisch=0 OR [Severity]='WARN')>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_Assemblies])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_AssemblyModules])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_AssemblyDependencies])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_AppDomains])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_LoadedAssemblies])>@Limit
            OR (SELECT COUNT_BIG(*) FROM [#ClrAnalysis_Tasks])>@Limit
           )
        BEGIN
            INSERT [#ClrAnalysis_Warnings]
            VALUES('RESULTSET_TRUNCATED',N'Mindestens ein fachliches Resultset enthält mehr Zeilen als @MaxZeilen und wird erst nach globaler Sortierung begrenzt.',N'@MaxZeilen=0 liefert alle materialisierten Zeilen.');
            IF @PrintMeldungen=1 RAISERROR(N'RESULTSET_TRUNCATED: Verwenden Sie @MaxZeilen=0 oder einen höheren Wert für die vollständige Ausgabe.',10,1) WITH NOWAIT;
        END;

        INSERT [#ClrAnalysis_Findings]
        SELECT TOP(@Limit) *
        FROM [#ClrAnalysis_FindingsCollected]
        WHERE @NurProblematisch=0 OR [Severity]='WARN'
        ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];

        IF @JsonErzeugen=1
        BEGIN
            SELECT @Json=(
                SELECT
                    JSON_QUERY((SELECT N'USP_ClrAnalysis' AS [module],@Now AS [collectedAtUtc],@MeasurementStartUtc AS [measurementStartUtc],@MeasurementEndUtc AS [measurementEndUtc],@StatusCode AS [statusCode],@IsPartial AS [isPartial],@ErrorNumber AS [errorNumber],@ErrorMessage AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS [meta],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_Configuration] FOR JSON PATH),N'[]')) AS [configuration],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_DatabaseStatus] ORDER BY [DatabaseName] FOR JSON PATH),N'[]')) AS [databaseStatus],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode],[ReadAtUtc] FOR JSON PATH),N'[]')) AS [sourceStatus],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal] FOR JSON PATH),N'[]')) AS [findings],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_Assemblies] ORDER BY [DatabaseName],[AssemblyName] FOR JSON PATH),N'[]')) AS [assemblies],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_AssemblyModules] ORDER BY [DatabaseName],[SchemaName],[ObjectName] FOR JSON PATH),N'[]')) AS [assemblyModules],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_AssemblyDependencies] ORDER BY [DatabaseName],[AssemblyName],[DependencyKind] FOR JSON PATH),N'[]')) AS [assemblyDependencies],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_Properties] ORDER BY [PropertyName] FOR JSON PATH),N'[]')) AS [clrProperties],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_AppDomains] ORDER BY [TotalProcessorTimeMs] DESC,[DatabaseName],[AppDomainId] FOR JSON PATH),N'[]')) AS [appDomains],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_LoadedAssemblies] ORDER BY [LoadTime] DESC,[DatabaseName],[AssemblyName] FOR JSON PATH),N'[]')) AS [loadedAssemblies],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_Tasks] ORDER BY [ForcedYieldCount] DESC,[DatabaseName] FOR JSON PATH),N'[]')) AS [clrTasks],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_ActiveRequests] ORDER BY [WaitTimeMs] DESC,[SessionId],[RequestId] FOR JSON PATH),N'[]')) AS [activeRequests],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_Memory] ORDER BY [PagesKb] DESC,[MemoryClerkType] FOR JSON PATH),N'[]')) AS [memory],
                    JSON_QUERY(COALESCE((SELECT TOP(@Limit) * FROM [#ClrAnalysis_PerformanceCounters] ORDER BY [CounterName],[InstanceName] FOR JSON PATH),N'[]')) AS [performanceCounters],
                    JSON_QUERY(COALESCE((SELECT * FROM [#ClrAnalysis_Warnings] ORDER BY [WarningCode] FOR JSON PATH),N'[]')) AS [warnings]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
        END;

        IF @OutputMode='RAW'
        BEGIN
            SELECT N'USP_ClrAnalysis' AS [Module],@Now AS [CollectedAtUtc],@MeasurementStartUtc AS [MeasurementStartUtc],@MeasurementEndUtc AS [MeasurementEndUtc],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage],N'Read-only SQL-CLR-Evidenz; keine Assembly-Binaries, Hashes, Moduldefinitionen, SQL-Texte, Pläne oder Testausführung.' AS [EvidenceLimit];
            SELECT * FROM [#ClrAnalysis_Configuration];
            SELECT * FROM [#ClrAnalysis_DatabaseStatus] ORDER BY [DatabaseName];
            SELECT * FROM [#ClrAnalysis_SourceStatus] ORDER BY [DatabaseName],[SourceCode],[ReadAtUtc];
            SELECT * FROM [#ClrAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'WARN' THEN 1 ELSE 2 END,[FindingOrdinal];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_Assemblies] ORDER BY [DatabaseName],[AssemblyName];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_AssemblyModules] ORDER BY [DatabaseName],[SchemaName],[ObjectName];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_AssemblyDependencies] ORDER BY [DatabaseName],[AssemblyName],[DependencyKind];
            SELECT * FROM [#ClrAnalysis_Properties] ORDER BY [PropertyName];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_AppDomains] ORDER BY [TotalProcessorTimeMs] DESC,[DatabaseName],[AppDomainId];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_LoadedAssemblies] ORDER BY [LoadTime] DESC,[DatabaseName],[AssemblyName];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_Tasks] ORDER BY [ForcedYieldCount] DESC,[DatabaseName];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_ActiveRequests] ORDER BY [WaitTimeMs] DESC,[SessionId],[RequestId];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_Memory] ORDER BY [PagesKb] DESC,[MemoryClerkType];
            SELECT TOP(@Limit) * FROM [#ClrAnalysis_PerformanceCounters] ORDER BY [CounterName],[InstanceName];
            SELECT * FROM [#ClrAnalysis_Warnings] ORDER BY [WarningCode];
        END;
    END TRY
    BEGIN CATCH
        SELECT @StatusCode=CASE WHEN ERROR_NUMBER()=1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END,
               @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
    END CATCH;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','NOT_APPLICABLE')
    BEGIN
        SET @PrintMessage=LEFT(CONCAT(N'USP_ClrAnalysis: ',@StatusCode,N'. ',COALESCE(@ErrorMessage,N'Siehe strukturierte Quellenstatus.')),2048);
        RAISERROR(N'%s',10,1,@PrintMessage) WITH NOWAIT;
    END;
    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ClrAnalysis_Findings'
            , @ResultLabel=N'ClrAnalysis'
            , @EmptyMessage=N'Keine SQL-CLR-Findings im gewählten Scope';
    IF @TableResultRequested=1
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable=N'#ClrAnalysis_Findings'
            , @TargetTable=@TableTarget
            , @ThrowOnError=1;
END;
GO
