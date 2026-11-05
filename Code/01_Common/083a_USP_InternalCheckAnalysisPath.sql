USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalCheckAnalysisPath
Version      : 1.1.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Prüft vor fachlichen DMV-, Cache-, Query-Store- oder
               Katalogzugriffen die einzelne Analyseklasse, erforderliche
               High-Impact-Bestätigung und den aktuell ausgewerteten
               Freigabepfad. Die Prüfung liest zuerst die Framework-Views
               VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.
Eingabe      :
  @AnalysisClass varchar(64), Default: kein Default; obligatorisch.
               Ein einzelner Katalogcode, keine Liste und kein Pattern.
               NULL und '' sind ungültig. Es erfolgt keine ausdrückliche
               Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung;
               Vergleiche folgen der Datenbankkollation, die nicht zwingend
               binär oder case-insensitive ist. Die gültigen Codes dieser
               ausgelieferten Katalogfassung 1.9.0 sind abschließend:
               STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.
               EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung.
               PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding.
               SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes.
               OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank.
               EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung.
               CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung.
               MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung.
               STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte.
               COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan.
               LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge.
               LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info.
               PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache.
               SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken.
               CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse.
               PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus.
               INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern.
               QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit.
               EXTENDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie.
               QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen.
               CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose.
               COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten.
               EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs.
               SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz.
               SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter.
               SECURITY_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter.
               SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb.
               RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse.
               HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking.
               ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication.
               DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung.
               Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte
               sind Hinweise der Katalogzeilen und werden von dieser Prüfung
               nicht erzwungen.
  @HighImpactConfirmed bit, Default: kein Default; obligatorisch.
               1 bestätigt die angeforderte High-Impact-Ausführung; 0
               bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig.
               NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt.
               Die Bestätigung ist auch bei sysadmin oder offener Policy
               erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.
  @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches
               Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE
               zurückgesetzt und bei behandeltem Ergebnis auf genau einen
               Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden),
               INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt
               oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED
               (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad
               nicht freigegeben). Eine aufrufende Variable mit passendem
               Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf
               kann der Wert verworfen werden.
  @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches
               Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt;
               bei behandeltem Fehler enthält er den zugehörigen Text, bei
               AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert
               wird ignoriert. Eine aufrufende Variable mit passendem Typ ist
               zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der
               Wert verworfen werden.
Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden.
               Ausgelassene Pflichtargumente verursachen einen Aufruffehler,
               bevor diese Procedure einen Status setzen kann.
               OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT
               übergeben werden, wenn ihr Ergebnis verworfen wird.
Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf
               die Framework-Views lösen den Datenbank-only-Fallback aus.
               Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des
               Fallbacks können fehlschlagen. Es wird keine Zusage gemacht,
               native Fehler in Statuswerte umzuwandeln.
Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der
               Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder
               den Fall ohne global aktive Policyzeilen. Eine aktive Policy
               an anderer Stelle kann eine geschützte Klasse verweigern,
               wenn der serverseitige Token nicht lesbar ist. Der Fallback
               prüft keine einzelne Gruppenmitgliedschaft und übergeht nie
               die High-Impact-Bestätigung. Global aktiv sind Policyzeilen
               mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt,
               ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit
               LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis
               ist SYSUTCDATETIME().
Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD-
               Gruppenmitgliedschaft live verifiziert. Es erfolgt keine
               fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine
               Wiederherstellung eines vorherigen Werts wird nicht zugesagt.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalCheckAnalysisPath]
      @AnalysisClass        varchar(64)
    , @HighImpactConfirmed  bit
    , @StatusCode           varchar(40)    OUTPUT
    , @ErrorMessage         nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT @StatusCode='AVAILABLE',@ErrorMessage=NULL;

    IF NULLIF(@AnalysisClass,'') IS NULL
       OR @HighImpactConfirmed IS NULL
       OR @HighImpactConfirmed NOT IN (0,1)
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Analyseklasse oder High-Impact-Bestätigung ist ungültig.';
        RETURN;
    END;

    DECLARE
          @RequiresHighImpact bit=0
        , @Allowed bit=0
        , @UsedDatabaseOnlyFallback bit=0
        , @IsSysadmin bit=CONVERT(bit,CASE WHEN IS_SRVROLEMEMBER(N'sysadmin')=1 THEN 1 ELSE 0 END);

    BEGIN TRY
        SELECT
              @RequiresHighImpact=COALESCE(MAX(CONVERT(tinyint,[c].[RequiresGroupGate])),0)
            , @Allowed=COALESCE(MAX(CONVERT(tinyint,[a].[IsAllowed])),0)
        FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
        LEFT JOIN [monitor].[VW_AnalyseAccessCurrent] AS [a]
          ON [a].[AnalysisClass]=[c].[AnalysisClass]
        WHERE [c].[AnalysisClass]=@AnalysisClass;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (229,371,916)
            THROW;

        SET @UsedDatabaseOnlyFallback=1;

        SELECT @RequiresHighImpact=COALESCE(MAX(CONVERT(tinyint,[c].[RequiresGroupGate])),0)
        FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
        WHERE [c].[AnalysisClass]=@AnalysisClass;

        SET @Allowed=CONVERT(bit,CASE
              WHEN @RequiresHighImpact=0 THEN 1
              WHEN @IsSysadmin=1 THEN 1
              WHEN NOT EXISTS
                   (
                       SELECT 1
                       FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
                       WHERE [p].[IsEnabled]=1
                         AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc]<=SYSUTCDATETIME())
                         AND ([p].[ValidToUtc] IS NULL OR [p].[ValidToUtc]>SYSUTCDATETIME())
                         AND NULLIF(LTRIM(RTRIM([p].[AnalysisClass])),N'') IS NOT NULL
                         AND NULLIF(LTRIM(RTRIM([p].[ADGroupName])),N'') IS NOT NULL
                   ) THEN 1
              ELSE 0 END);
    END CATCH;

    IF NOT EXISTS
       (
           SELECT 1
           FROM [monitor].[VW_AnalyseClassCatalog]
           WHERE [AnalysisClass]=@AnalysisClass
       )
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=CONCAT(N'Unbekannte Analyseklasse: ',@AnalysisClass,N'.');
        RETURN;
    END;

    IF @RequiresHighImpact=1 AND @HighImpactConfirmed<>1
    BEGIN
        SET @StatusCode='HIGH_IMPACT_CONFIRMATION_REQUIRED';
        SET @ErrorMessage=CONCAT(N'Der aktivierte Analysepfad ',@AnalysisClass,N' erfordert @HighImpactConfirmed=1.');
        RETURN;
    END;

    IF @Allowed<>1
    BEGIN
        SET @StatusCode='DENIED_GROUP';
        SET @ErrorMessage=CASE WHEN @UsedDatabaseOnlyFallback=1
                              THEN CONCAT(@AnalysisClass,N' ist nicht freigegeben; der serverseitige Gruppentoken war im aktuellen Datenbankkontext nicht lesbar.')
                              ELSE CONCAT(@AnalysisClass,N' ist nicht freigegeben.') END;
    END;
END;
GO
