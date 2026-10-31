USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CheckFrameworkCapabilities
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Prüft Framework-Capabilities serverweit und je ausgewählter DB.
Datenbanken  : @DatabaseNames bracket-aware Pipe-Liste; NULL/N''=alle.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit capabilities, summary,
               warnings.
Änderungen   : 2.0.1 - SQL-Literal-Escaping für Datenbanknamen korrigiert.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CheckFrameworkCapabilities]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @AnalyseKlasse                    varchar(64)     = NULL
    , @NurNichtVerfuegbar               bit            = 0
    , @MitGruppenpruefung               bit            = 1
    , @ResultSetArt                     varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                     bit             = 0
    , @Json                              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit             = 1
    , @Hilfe                             bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'capabilities',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @Major int = TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion'));
    DECLARE @ProductVersion nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY(N'ProductVersion'));
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @OverallStatus varchar(40) = 'AVAILABLE';
    DECLARE @OverallError nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CheckFrameworkCapabilities prüft katalogisierte Framework-Capabilities serverweit und je ausgewählter Datenbank. Quellen: Featurekatalog, Servereigenschaften, Datenbankkandidaten, Access-View, Permissionfunktionen und leichte dynamische Probe-/Enablementabfragen.';
        PRINT N'Eine Katalogzeile allein ist keine Laufzeitqualifikation. Die Procedure führt die katalogisierten Probe- und Enablement-SQL-Templates aus, ruft aber nicht automatisch spätere Fachmodule auf. Die Templates sind hinsichtlich Zugriffsumfang zu prüfen.';
        PRINT N'Die Procedure vergibt keine Rechte. Probeerfolg oder Metadatenrechte belegen weder vollständige Sichtbarkeit späterer Fachdaten noch externe Gesundheit oder erfolgreiche Fachanalyse.';
        PRINT N'@DatabaseNames: nvarchar(max), Default NULL. NULL, leer oder nur äußere U+0020 bedeutet keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen: | trennt außerhalb [..], ]] maskiert darin ]; äußere U+0020 je Element werden entfernt. Elemente müssen als einzelner SQL-Name via PARSENAME erkennbar und höchstens 128 Zeichen (sysname) sein; Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Leere/fehlerhafte Elemente, ungültige Namen und Duplikate nach SQL_Latin1_General_CP1_CS_AS-Vergleich ergeben INVALID_PARAMETER. Groß-/Kleinschreibung wird unterschieden. Keine Anzahlgrenze im Helper. Nur bei einer nach dieser Normalisierung nichtleeren Liste ist ein nicht-NULL @DatabaseNamePattern unzulässig. Ausgelassen = unbeschränkte Auswahl sichtbarer, onlineer, zugänglicher Benutzerdatenbanken.';
        PRINT N'@SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ergibt INVALID_PARAMETER. Numerische Argumente konvertiert SQL Server vor Eintritt in bit: 0 bleibt 0, jeder Nichtnullwert wird 1. Ausgelassen = ausschließen.';
        PRINT N'@DatabaseNamePattern: nvarchar(4000), Default NULL. NULL bedeutet kein Pattern. Sonst äußere U+0020 mit LTRIM/RTRIM trimmen; Präfix regexi:, regex: oder like: wird ohne Beachtung der Großschreibung erkannt und entfernt, sonst LIKE. Rest nach Präfix wird nicht nochmals getrimmt. LIKE ist case-sensitiv, unterstützt %, _, [Zeichenklassen]; regex: ist case-sensitiv, regexi: case-insensitiv. Leere Eingabe oder leerer Rest ist ungültig. Jedes nicht-NULL Pattern ist mit einer nichtleeren @DatabaseNames-Liste exklusiv. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE. Ausgelassen = keine Einschränkung.';
        PRINT N'@HighImpactConfirmed: bit, Default 0. 1 übergibt die Bestätigung an den Datenbankkandidaten-Helper; 0 bestätigt nicht. NULL ergibt INVALID_PARAMETER. Numerische Werte werden vorab in bit konvertiert (Nichtnull wird 1). Diese Procedure übergibt Analyseklasse NULL an den Helper; daher wird hier kein klassenabhängiges High-Impact-Gate ausgelöst. Ausgelassen = 0.';
        PRINT N'@AnalyseKlasse: varchar(64), Default NULL. NULL oder ausgelassen wählt alle Features. Sonst Vergleich mit VW_AnalyseClassCatalog unter SQL_Latin1_General_CP1_CS_AS, ohne LTRIM/RTRIM; Groß-/Kleinschreibung zählt, SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Begrenzt Featurekombinationen vor den Probes. Zulässige Klassen mit Bedeutung:';
        PRINT N'  STANDARD_CURRENT = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O';
        PRINT N'  EXTENDED_CURRENT = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung';
        PRINT N'  PLAN_CACHE_CURRENT = begrenzte Query-Stats- und Plan-Cache-Auswertung ohne vollständiges XML-Shredding';
        PRINT N'  SHOWPLAN_TARGETED = gezielte Showplan-Extraktion/XML-Analyse für gefilterte Planhandles oder Query Hashes';
        PRINT N'  OBJECT_ANALYSIS_CURRENT = gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank';
        PRINT N'  EXTERNAL_RUNTIME_CURRENT = lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes, ohne Testausführung';
        PRINT N'  CLR_CURRENT = lesende SQL-CLR-, Host-, AppDomain-, Task-, Request- und Speicheranalyse, ohne Assemblyausführung';
        PRINT N'  MISSING_INDEX_CURRENT = flüchtige begrenzte Missing-Index-Hinweise, keine automatische DDL';
        PRINT N'  STATISTICS_TARGETED = gezielte Statistik-Eigenschaften gefilterter Objekte';
        PRINT N'  COLUMNSTORE_CURRENT = gezielte Columnstore-Rowgroups aus Katalogen, kein Segment-/Dictionary-Vollscan';
        PRINT N'  LOCKS_DEEP = detaillierte sys.dm_tran_locks-Materialisierung für relevante Sessions';
        PRINT N'  LOG_VLF_DEEP = datenbankübergreifende VLF-Auswertung via sys.dm_db_log_info';
        PRINT N'  PLAN_CACHE_DEEP = breite oder vollständige Query-Stats- und Plan-Cache-Analyse';
        PRINT N'  SHOWPLAN_XML_DEEP = XML-Analyse gecachter/aktueller Showplans mit Warnings, Spills, Objekten, Statistiken';
        PRINT N'  CATALOG_DEEP = breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse';
        PRINT N'  PHYSICAL_STATS_DEEP = explizite sys.dm_db_index_physical_stats-Auswertung in gewähltem Modus';
        PRINT N'  INDEX_OPERATIONAL_DEEP = breite kumulative Index-Operational-Stats mit Lock/Latch/I/O/Page-Splits';
        PRINT N'  QUERY_STORE_CURRENT = gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan-/Force-Auswertung, enges Zeit-/Zeilenlimit';
        PRINT N'  EXTENDED_EVENTS_CURRENT = leichte Inventarisierung von Extended-Events-Definitionen und laufenden Sessions, ohne Targetdaten/Historie';
        PRINT N'  QUERY_STORE_DEEP = breite Query-Store-Historie, Regressionen, Planwechsel und Waits';
        PRINT N'  CROSS_DATABASE_DEEP = datenbankübergreifende Inventarisierung und Diagnose';
        PRINT N'  COLUMNSTORE_DEEP = breite Columnstore-Analyse mit Rowgroups, Deleted Rows, Dictionaries und Segmenten';
        PRINT N'  EXTENDED_EVENTS_FORENSICS_DEEP = optionale Analyse vorhandener XE-Sessions/Dateien, nie Primärquelle des Standardlaufs';
        PRINT N'  SERVER_HEALTH_CURRENT = CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der Instanz';
        PRINT N'  SERVER_CONFIGURATION_CURRENT = lesende Serverkonfiguration, Trace Flags und Startup-Parameter';
        PRINT N'  SECURITY_CONFIGURATION_CURRENT = lesende sicherheits- und dienstbezogene Betriebsparameter';
        PRINT N'  SQL_AGENT_CURRENT = lesender SQL-Agent-Status, Jobs, Schedules und Historie aus msdb';
        PRINT N'  RESOURCE_GOVERNOR_CURRENT = lesende Resource-Governor-Konfiguration und Laufzeit';
        PRINT N'  HA_DR_CURRENT = begrenzte lesende AG-, Backup-, Log-Shipping-, Replication-, CDC- und Change-Tracking-Analyse';
        PRINT N'  ENTERPRISE_TOPOLOGY_DEEP = vertiefte enterpriseweite HA/DR- und Replication-Topologie/Distribution';
        PRINT N'  DATA_PLATFORM_ADAPTER_CURRENT = optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Logs mit isolierter Existenz-/Rechteprüfung';
        PRINT N'@NurNichtVerfuegbar: bit, Default 0. 0 gibt alle Capabilityzeilen aus; 1 nur IsUsable=0. NULL wirkt wegen des tatsächlichen SQL-Prädikats ebenfalls als Filter auf IsUsable=0. Evaluation und Summary bleiben vollständig; der Filter spart keine Probes. Ausgelassen = 0.';
        PRINT N'@MitGruppenpruefung: bit, Default 1. 1 prüft je Feature die Access-View; bei Deny oder Prüfungsfehler wird die Probe übersprungen. 0 oder NULL überspringt die Gruppenprüfung. Numerische Nichtnullwerte werden vorab zu bit 1 konvertiert. Ausgelassen = 1.';
        PRINT N'@ResultSetArt: varchar(16), Default ''CONSOLE''. Werte: CONSOLE übergibt Capabilities dem Console-Renderer; RAW liefert Meta, Capabilities, Summary und Warnings; TABLE exportiert ausschließlich Capabilities; NONE unterdrückt fachliche Resultsets. Äußere U+0020 werden mit LTRIM/RTRIM entfernt, danach UPPER. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE.';
        PRINT N'CONSOLE übergibt capabilities an den Console-Renderer. RAW liefert vier Resultsets: Meta, Capabilities, Summary und Warnings. TABLE schreibt ausschließlich das benannte capabilities-Resultset; NONE unterdrückt fachliche Resultsets.';
        PRINT N'@ResultTablesJson: nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "capabilities" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Ziel: vorhandene leere lokale #temp-Tabelle, kein ##, LEN höchstens 116, nicht #Monitor* (case-insensitiv), genau eine beliebig typisierte Seed-Spalte. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu und entfernt sie; daraus folgt kein bit/NULL-Zwang für die Seed-Spalte. U+0020 außen wird für Objektklammern getrimmt. Leeres/ungültiges JSON-Objekt, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen oder fehlendes/gefülltes/mehrspaltiges Ziel schlagen im Preflight fehl (THROW 51011). Außerhalb TABLE führt eine nichtleere Zuordnung zu THROW 51011.';
        PRINT N'TABLE-Preflight validiert das lokale Ziel vor der Hilfe per temporärer Metadaten-DDL und kann bei ungültigem Ziel mit Fehler abbrechen. @Json wird bereits vor dem Preflight auf NULL gesetzt. @Hilfe=1 gibt danach Hilfe aus; @PrintMeldungen unterdrückt sie nicht.';
        PRINT N'@JsonErzeugen: bit, Default 0. 1 erzeugt @Json mit meta, capabilities, summary und warnings; 0 oder NULL erzeugt keines. Ausgelassen = 0.';
        PRINT N'@Json: nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um JSON zu empfangen; ohne Erzeugung bleibt NULL. Der Eingangswert wird vor TABLE-Preflight und Hilfe auf NULL gesetzt. Ausgelassen ist möglich, dann kann kein Ergebnis empfangen werden.';
        PRINT N'@PrintMeldungen: bit, Default 1. 1 gibt Severity 10 bei Gesamtfehler oder mindestens einer nicht nutzbaren Capability aus. 0/NULL unterdrückt nur diese Meldung, nicht Resultsets oder JSON. Ausgelassen = 1.';
        PRINT N'@Hilfe: bit, Default 0. 1 gibt Hilfe aus und beendet vor Kandidatenauswahl und Capability-Probes; NULL/0 führt normal aus. @Json wird zuvor auf NULL gesetzt. TABLE-Preflight liegt vor der Hilfe und kann TempDB-Metadaten ändern oder abbrechen. @PrintMeldungen unterdrückt Hilfe nicht.';
        PRINT N'Beispiel – Hilfe: EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;';
        PRINT N'Beispiel – Standard: EXEC [monitor].[USP_CheckFrameworkCapabilities];';
        PRINT N'Beispiel – Scope und RAW: EXEC [monitor].[USP_CheckFrameworkCapabilities] @DatabaseNames=N''[ExampleDb]'', @AnalyseKlasse=''STANDARD_CURRENT'', @ResultSetArt=''RAW'';';
        PRINT N'Beispiel – JSON/NONE: DECLARE @j nvarchar(max); EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'Beispiel – TABLE-Ziel: CREATE TABLE #CheckFrameworkCapabilities_HelpExample (Seed bit NULL);';
        PRINT N'DECLARE @map nvarchar(max)=N''{"capabilities":"#CheckFrameworkCapabilities_HelpExample"}''; EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt=''TABLE'', @ResultTablesJson=@map; DROP TABLE #CheckFrameworkCapabilities_HelpExample;';
        RETURN;
    END;

    CREATE TABLE [#CheckFrameworkCapabilities_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NOT NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#CheckFrameworkCapabilities_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#CheckFrameworkCapabilities_Collected]
    (
          [FeatureOrdinal] smallint NOT NULL
        , [FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureName] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsResourceIntensive] bit NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ServerMajorVersion] int NULL
        , [ServerProductVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MinimumMajorVersion] tinyint NOT NULL
        , [VersionSupported] bit NOT NULL
        , [GroupCheckApplied] bit NOT NULL
        , [GroupAccessAllowed] bit NULL
        , [AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequiredPermissionScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PermissionCheckType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredPermission] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PermissionDisplayText] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HasRequiredPermission] bit NULL
        , [IsQueryable] bit NOT NULL
        , [IsFeatureEnabled] bit NULL
        , [IsUsable] bit NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Description] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#CheckFrameworkCapabilities_Capabilities]
    (
          [FeatureOrdinal] smallint NOT NULL
        , [FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureName] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsResourceIntensive] bit NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ServerMajorVersion] int NULL
        , [ServerProductVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MinimumMajorVersion] tinyint NOT NULL
        , [VersionSupported] bit NOT NULL
        , [GroupCheckApplied] bit NOT NULL
        , [GroupAccessAllowed] bit NULL
        , [AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequiredPermissionScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PermissionCheckType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredPermission] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PermissionDisplayText] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [HasRequiredPermission] bit NULL
        , [IsQueryable] bit NOT NULL
        , [IsFeatureEnabled] bit NULL
        , [IsUsable] bit NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Description] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @OverallError = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;
    ELSE IF @AnalyseKlasse IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [monitor].[VW_AnalyseClassCatalog] WHERE [AnalysisClass] = @AnalyseKlasse)
    BEGIN
        SET @OverallStatus = 'INVALID_PARAMETER';
        SET @OverallError = N'Unbekannte Analyseklasse.';
    END;

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = NULL
            , @StatusCode = @OverallStatus OUTPUT
            , @ErrorMessage = @OverallError OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#CheckFrameworkCapabilities_DatabaseCandidates',@WarningTable=N'#CheckFrameworkCapabilities_DatabaseCandidateWarnings';
    END;

    DECLARE @Features TABLE
    (
          [RowNo] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [FeatureOrdinal] smallint NOT NULL
        , [FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FeatureName] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsResourceIntensive] bit NOT NULL
        , [MinimumMajorVersion] tinyint NOT NULL
        , [RequiredPermissionScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PermissionCheckType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiredPermission] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PermissionDisplayText] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExpectedWithoutPermission] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProbeSqlTemplate] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EnablementSqlTemplate] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [Description] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    /* Eigene tempdb-/Tabellenvariablen-DDL bleibt außerhalb des No-Wait-Vertrags. */
    SET LOCK_TIMEOUT 0;

    IF @OverallStatus = 'AVAILABLE'
    BEGIN
        INSERT @Features
        (
              [FeatureOrdinal], [FeatureCode], [FeatureName], [ScopeType]
            , [AnalysisClass], [AnalysisLevel], [IsResourceIntensive]
            , [MinimumMajorVersion], [RequiredPermissionScope]
            , [PermissionCheckType], [RequiredPermission], [PermissionDisplayText]
            , [ExpectedWithoutPermission], [ProbeSqlTemplate]
            , [EnablementSqlTemplate], [Description], [DatabaseName]
        )
        SELECT
              [f].[FeatureOrdinal], [f].[FeatureCode], [f].[FeatureName], [f].[ScopeType]
            , [f].[AnalysisClass], [f].[AnalysisLevel], [f].[IsResourceIntensive]
            , [f].[MinimumMajorVersion]
            , CASE WHEN @Major >= 16 THEN [f].[PermissionScopeFromSql2022] ELSE [f].[PermissionScopeBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionCheckTypeFromSql2022] ELSE [f].[PermissionCheckTypeBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionNameFromSql2022] ELSE [f].[PermissionNameBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionDisplayTextFromSql2022] ELSE [f].[PermissionDisplayTextBeforeSql2022] END
            , [f].[ExpectedWithoutPermission], [f].[ProbeSqlTemplate]
            , [f].[EnablementSqlTemplate], [f].[Description], NULL
        FROM [monitor].[VW_FrameworkFeatureCatalog] AS [f]
        WHERE [f].[ScopeType] = 'SERVER'
          AND (@AnalyseKlasse IS NULL OR [f].[AnalysisClass] = @AnalyseKlasse)
        UNION ALL
        SELECT
              [f].[FeatureOrdinal], [f].[FeatureCode], [f].[FeatureName], [f].[ScopeType]
            , [f].[AnalysisClass], [f].[AnalysisLevel], [f].[IsResourceIntensive]
            , [f].[MinimumMajorVersion]
            , CASE WHEN @Major >= 16 THEN [f].[PermissionScopeFromSql2022] ELSE [f].[PermissionScopeBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionCheckTypeFromSql2022] ELSE [f].[PermissionCheckTypeBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionNameFromSql2022] ELSE [f].[PermissionNameBeforeSql2022] END
            , CASE WHEN @Major >= 16 THEN [f].[PermissionDisplayTextFromSql2022] ELSE [f].[PermissionDisplayTextBeforeSql2022] END
            , [f].[ExpectedWithoutPermission], [f].[ProbeSqlTemplate]
            , [f].[EnablementSqlTemplate], [f].[Description], [d].[DatabaseName]
        FROM [monitor].[VW_FrameworkFeatureCatalog] AS [f]
        CROSS JOIN [#CheckFrameworkCapabilities_DatabaseCandidates] AS [d]
        WHERE [f].[ScopeType] = 'DATABASE'
          AND (@AnalyseKlasse IS NULL OR [f].[AnalysisClass] = @AnalyseKlasse);
    END;

    DECLARE
          @i int = 1
        , @n int = (SELECT MAX([RowNo]) FROM @Features)
        , @FeatureOrdinal smallint
        , @FeatureCode varchar(64)
        , @FeatureName nvarchar(200)
        , @ScopeType varchar(16)
        , @Class varchar(64)
        , @Level varchar(16)
        , @Intensive bit
        , @MinVersion tinyint
        , @PermissionScope varchar(16)
        , @PermissionCheckType varchar(24)
        , @Permission sysname
        , @PermissionText nvarchar(128)
        , @Expected varchar(32)
        , @Probe nvarchar(2000)
        , @Enable nvarchar(2000)
        , @Description nvarchar(1000)
        , @DatabaseName sysname
        , @QuotedDatabaseName nvarchar(258)
        , @DatabaseLiteral nvarchar(260)
        , @GroupAllowed bit
        , @AccessReason varchar(20)
        , @HasPermission bit
        , @Queryable bit
        , @Enabled bit
        , @Usable bit
        , @Status varchar(40)
        , @ErrorNumber int
        , @ErrorMessage nvarchar(2048)
        , @Sql nvarchar(max);

    WHILE @OverallStatus = 'AVAILABLE' AND @i <= COALESCE(@n, 0)
    BEGIN
        SELECT
              @FeatureOrdinal = [FeatureOrdinal], @FeatureCode = [FeatureCode]
            , @FeatureName = [FeatureName], @ScopeType = [ScopeType]
            , @Class = [AnalysisClass], @Level = [AnalysisLevel]
            , @Intensive = [IsResourceIntensive], @MinVersion = [MinimumMajorVersion]
            , @PermissionScope = [RequiredPermissionScope]
            , @PermissionCheckType = [PermissionCheckType]
            , @Permission = [RequiredPermission], @PermissionText = [PermissionDisplayText]
            , @Expected = [ExpectedWithoutPermission], @Probe = [ProbeSqlTemplate]
            , @Enable = [EnablementSqlTemplate], @Description = [Description]
            , @DatabaseName = [DatabaseName]
        FROM @Features
        WHERE [RowNo] = @i;

        SELECT
              @QuotedDatabaseName = CASE WHEN @DatabaseName IS NULL THEN NULL ELSE QUOTENAME(@DatabaseName) END
            , @DatabaseLiteral = CASE WHEN @DatabaseName IS NULL THEN NULL ELSE REPLACE(@DatabaseName, N'''', N'''''') END
            , @GroupAllowed = 1, @AccessReason = 'OPEN', @HasPermission = NULL
            , @Queryable = 0, @Enabled = NULL, @Usable = 0
            , @Status = 'ERROR_HANDLED', @ErrorNumber = NULL, @ErrorMessage = NULL;

        IF @MitGruppenpruefung = 1
        BEGIN TRY
            SELECT @GroupAllowed = [IsAllowed], @AccessReason = [AccessReason]
            FROM [monitor].[VW_AnalyseAccessCurrent]
            WHERE [AnalysisClass] = @Class;
        END TRY
        BEGIN CATCH
            SELECT @GroupAllowed = 0, @AccessReason = 'CHECK_ERROR', @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = ERROR_MESSAGE();
        END CATCH;

        IF @Major < @MinVersion
            SELECT @Status = 'UNAVAILABLE_VERSION', @ErrorMessage = CONCAT(N'Mindest-Major-Version ', @MinVersion, N'; erkannt ', COALESCE(CONVERT(nvarchar(20), @Major), N'unbekannt'), N'.');
        ELSE IF COALESCE(@GroupAllowed, 0) = 0
            SELECT @Status = 'DENIED_GROUP', @ErrorMessage = COALESCE(@ErrorMessage, N'Analyseklasse nicht freigegeben.');
        ELSE
        BEGIN
            IF @PermissionCheckType = 'HAS_PERMS_BY_NAME' AND @Permission IS NOT NULL
            BEGIN TRY
                IF @PermissionScope = 'SERVER'
                    SELECT @HasPermission = CONVERT(bit, HAS_PERMS_BY_NAME(NULL, NULL, @Permission));
                ELSE IF @PermissionScope = 'DATABASE'
                BEGIN
                    SET @Sql = N'USE ' + @QuotedDatabaseName + N'; SELECT @x=CONVERT(bit,HAS_PERMS_BY_NAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()),N''DATABASE'',@p));';
                    EXEC [sys].[sp_executesql] @Sql, N'@p sysname,@x bit OUTPUT', @p = @Permission, @x = @HasPermission OUTPUT;
                END;
            END TRY
            BEGIN CATCH
                SELECT @HasPermission = NULL, @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = CONCAT(N'Berechtigungsprobe: ', ERROR_MESSAGE());
            END CATCH;

            BEGIN TRY
                SET @Sql = REPLACE(@Probe, N'' + N'$' + N'(DATABASE)', COALESCE(@QuotedDatabaseName, QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()))));
                EXEC [sys].[sp_executesql] @Sql;
                SET @Queryable = 1;

                IF @Enable IS NOT NULL
                BEGIN
                    SET @Sql = REPLACE(REPLACE(@Enable, N'' + N'$' + N'(DATABASE)', COALESCE(@QuotedDatabaseName, QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())))), N'' + N'$' + N'(DATABASENAME)', COALESCE(@DatabaseLiteral, REPLACE((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()), N'''', N'''''')));
                    EXEC [sys].[sp_executesql] @Sql, N'@IsEnabledOut bit OUTPUT', @IsEnabledOut = @Enabled OUTPUT;
                END;

                IF @Enabled = 0
                    SELECT @Status = 'AVAILABLE_DISABLED', @Usable = 0;
                ELSE IF @PermissionCheckType = 'PROBE_ONLY'
                    SELECT @Status = 'AVAILABLE_UNVERIFIED', @Usable = 1;
                ELSE IF @HasPermission = 0
                    SELECT @Status = CASE WHEN @Expected = 'LIMITED' THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE_UNVERIFIED' END, @Usable = 1;
                ELSE
                    SELECT @Status = 'AVAILABLE', @Usable = 1;
            END TRY
            BEGIN CATCH
                SELECT
                      @Queryable = 0, @Usable = 0
                    , @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = ERROR_MESSAGE()
                    , @Status = CASE
                        WHEN ERROR_NUMBER() IN (229,230,297,300,371,916,15151) THEN 'DENIED_PERMISSION'
                        WHEN ERROR_NUMBER() IN (911,924,927,942,976,978) THEN 'DATABASE_UNAVAILABLE'
                        WHEN ERROR_NUMBER() IN (207,208,195,2812,4121) THEN 'UNAVAILABLE_OBJECT'
                        WHEN ERROR_NUMBER() = 1222 THEN 'TIMEOUT'
                        ELSE 'ERROR_HANDLED' END;
            END CATCH;
        END;

        INSERT [#CheckFrameworkCapabilities_Collected]
        (
              [FeatureOrdinal], [FeatureCode], [FeatureName], [ScopeType]
            , [AnalysisClass], [AnalysisLevel], [IsResourceIntensive]
            , [DatabaseName], [ServerMajorVersion], [ServerProductVersion]
            , [MinimumMajorVersion], [VersionSupported], [GroupCheckApplied]
            , [GroupAccessAllowed], [AccessReason], [RequiredPermissionScope]
            , [PermissionCheckType], [RequiredPermission], [PermissionDisplayText]
            , [HasRequiredPermission], [IsQueryable], [IsFeatureEnabled]
            , [IsUsable], [StatusCode], [ErrorNumber], [ErrorMessage], [Description]
        )
        VALUES
        (
              @FeatureOrdinal, @FeatureCode, @FeatureName, @ScopeType
            , @Class, @Level, @Intensive, @DatabaseName, @Major, @ProductVersion
            , @MinVersion, CONVERT(bit, CASE WHEN @Major >= @MinVersion THEN 1 ELSE 0 END)
            , @MitGruppenpruefung, @GroupAllowed, @AccessReason, @PermissionScope
            , @PermissionCheckType, @Permission, @PermissionText, @HasPermission
            , @Queryable, @Enabled, @Usable, @Status, @ErrorNumber, @ErrorMessage
            , @Description
        );

        SET @i += 1;
    END;

    IF @OverallStatus = 'AVAILABLE'
       AND EXISTS (SELECT 1 FROM [#CheckFrameworkCapabilities_Collected] WHERE [IsUsable] = 0)
        SET @OverallStatus = 'AVAILABLE_LIMITED';

    INSERT [#CheckFrameworkCapabilities_Capabilities]
    SELECT * FROM [#CheckFrameworkCapabilities_Collected]
    WHERE @NurNichtVerfuegbar = 0 OR [IsUsable] = 0;

    IF @PrintMeldungen = 1 AND (@OverallError IS NOT NULL OR EXISTS (SELECT 1 FROM [#CheckFrameworkCapabilities_Collected] WHERE [IsUsable] = 0))
    BEGIN
        DECLARE @PrintMessage nvarchar(2048) = COALESCE(@OverallError, N'Mindestens eine Capability ist nicht vollständig nutzbar.');
        RAISERROR(N'%s', 10, 1, @PrintMessage) WITH NOWAIT;
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              CAST('2.0' AS varchar(16)) AS [ContractVersion]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , N'monitor.USP_CheckFrameworkCapabilities' AS [ModuleName]
            , @OverallStatus AS [StatusCode]
            , CONVERT(bit, CASE WHEN @OverallStatus = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , @OverallError AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT * FROM [#CheckFrameworkCapabilities_Capabilities]
            ORDER BY [FeatureOrdinal], [DatabaseName];
            SELECT [StatusCode], COUNT_BIG(*) AS [FeatureCount], SUM(CONVERT(bigint,[IsQueryable])) AS [QueryableCount], SUM(CONVERT(bigint,[IsUsable])) AS [UsableCount]
            FROM [#CheckFrameworkCapabilities_Collected] GROUP BY [StatusCode] ORDER BY [StatusCode];
            SELECT * FROM [#CheckFrameworkCapabilities_DatabaseCandidateWarnings] ORDER BY [RequestedName];
        END;
        ELSE
        BEGIN
            SELECT
                  N'Framework-Capability' AS [Ergebnis]
                , [FeatureCode] AS [Feature]
                , [DatabaseName] AS [Datenbank]
                , [StatusCode] AS [Status]
                , [IsUsable] AS [nutzbar]
                , [PermissionDisplayText] AS [Berechtigung]
                , [ErrorMessage] AS [Hinweis]
            FROM [#CheckFrameworkCapabilities_Capabilities]
            ORDER BY [FeatureOrdinal], [DatabaseName];

            SELECT N'Capability-Status' AS [Ergebnis], [StatusCode] AS [Status], COUNT_BIG(*) AS [Anzahl]
            FROM [#CheckFrameworkCapabilities_Collected] GROUP BY [StatusCode] ORDER BY [StatusCode];

            SELECT N'Datenbankwarnung' AS [Ergebnis], [RequestedName] AS [Datenbank], [StatusCode] AS [Status], [ErrorMessage] AS [Meldung]
            FROM [#CheckFrameworkCapabilities_DatabaseCandidateWarnings] ORDER BY [RequestedName];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) = (SELECT N'CheckFrameworkCapabilities' AS [resultName], 1 AS [schemaVersion], @CollectionTimeUtc AS [generatedAtUtc], @OverallStatus AS [statusCode], @OverallError AS [errorMessage] FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        DECLARE @CapabilitiesJson nvarchar(max) = (SELECT * FROM [#CheckFrameworkCapabilities_Capabilities] ORDER BY [FeatureOrdinal], [DatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SummaryJson nvarchar(max) = (SELECT [StatusCode], COUNT_BIG(*) AS [FeatureCount], SUM(CONVERT(bigint,[IsQueryable])) AS [QueryableCount], SUM(CONVERT(bigint,[IsUsable])) AS [UsableCount] FROM [#CheckFrameworkCapabilities_Collected] GROUP BY [StatusCode] ORDER BY [StatusCode] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) = (SELECT * FROM [#CheckFrameworkCapabilities_DatabaseCandidateWarnings] ORDER BY [RequestedName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson,N'{}'), N',"capabilities":', COALESCE(@CapabilitiesJson,N'[]'), N',"summary":', COALESCE(@SummaryJson,N'[]'), N',"warnings":', COALESCE(@WarningsJson,N'[]'), N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CheckFrameworkCapabilities_Capabilities'
            , @ResultLabel=N'CheckFrameworkCapabilities'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CheckFrameworkCapabilities_Capabilities'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
